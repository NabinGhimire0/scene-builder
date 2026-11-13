class_name ExportManager
extends Node
## Renders the cinematic to video, frame by frame.
##
## For every frame it seeks the timeline (so animation, camera cuts and lighting
## are exact), points an off-screen render camera through the live shot, waits for
## Godot to draw the frame, then stores the image. Because each frame is waited
## for, nothing is ever dropped regardless of how heavy the scene is.
##
## Formats:
##  • MP4 (H.264)  – frames are encoded with FFmpeg (if installed / located).
##  • AVI (MJPEG)  – written directly by [AviMjpegWriter]; works everywhere.
##  • PNG sequence – one lossless image per frame, for editing software.

signal started(preview: Texture2D)
signal progress(frame: int, total: int, eta_seconds: float)
signal phase_changed(text: String)
signal finished(success: bool, message: String, output_path: String)
signal settings_changed

enum Format { MP4, AVI, PNG }

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
	Vector2i(1080, 1920), Vector2i(1080, 1080)]
const RESOLUTION_NAMES: PackedStringArray = [
	"HD 720p (1280×720)", "Full HD 1080p (1920×1080)", "QHD 1440p (2560×1440)", "4K UHD (3840×2160)",
	"Vertical 1080×1920 (shorts/reels)", "Square 1080×1080"]
const FPS_OPTIONS: PackedInt32Array = [24, 25, 30, 60]
const FORMAT_NAMES: PackedStringArray = ["MP4 video (H.264, needs FFmpeg)", "AVI video (Motion-JPEG, built in)", "PNG image sequence"]
const TEMP_DIR := "user://render_tmp"

@export var director: CinematicDirector
@export var timeline: TimelineController
@export var placement: PlacementController
@export var environment: EnvironmentController
@export var titles: TitleTrack
@export var audio: AudioTrack
@export var blender_export: BlenderExport

var settings := {
	"resolution": 1,
	"fps": 30,
	"format": Format.AVI,
	"quality": 0.9,
	"render_quality": RenderQuality.Level.CINEMATIC,
	"output_dir": "",
	"file_name": "my_film",
	"ffmpeg_path": "ffmpeg",
}
var is_exporting := false

var _cancel_requested := false
var _ffmpeg_cache := {}


func _ready() -> void:
	var movies := OS.get_system_dir(OS.SYSTEM_DIR_MOVIES)
	settings["output_dir"] = movies if not movies.is_empty() else OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	_sync_dependents()


# --- Settings ----------------------------------------------------------------------

func resolution() -> Vector2i:
	return RESOLUTIONS[clampi(int(settings["resolution"]), 0, RESOLUTIONS.size() - 1)]


func fps() -> int:
	return int(settings["fps"])


func frame_count() -> int:
	return maxi(1, int(round(timeline.duration() * fps())))


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_sync_dependents()
	settings_changed.emit()


func to_dict() -> Dictionary:
	return settings.duplicate()


func load_dict(data: Dictionary) -> void:
	for key in settings:
		if data.has(key):
			settings[key] = data[key]
	settings["resolution"] = clampi(int(settings["resolution"]), 0, RESOLUTIONS.size() - 1)
	settings["fps"] = int(settings["fps"]) if FPS_OPTIONS.has(int(settings["fps"])) else 30
	settings["format"] = clampi(int(settings["format"]), 0, Format.size() - 1)
	settings["quality"] = clampf(float(settings["quality"]), 0.3, 1.0)
	settings["render_quality"] = clampi(int(settings["render_quality"]), 0, 2)
	_sync_dependents()
	settings_changed.emit()


## True if FFmpeg can be run from [param path] (cached per path).
func ffmpeg_available(path: String = "") -> bool:
	if path.is_empty():
		path = str(settings["ffmpeg_path"])
	if path.is_empty():
		return false
	if not _ffmpeg_cache.has(path):
		var output: Array = []
		_ffmpeg_cache[path] = OS.execute(path, PackedStringArray(["-version"]), output, true) == 0
	return _ffmpeg_cache[path]


## Problems that would stop an export, as readable sentences (empty = ready).
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if director.cameras().is_empty():
		problems.append("Add at least one camera (toolbar: Add Camera). The film is rendered through your cameras.")
	if str(settings["output_dir"]).is_empty():
		problems.append("Choose an output folder.")
	if int(settings["format"]) == Format.MP4 and not ffmpeg_available():
		problems.append("FFmpeg wasn't found. Install it, browse to ffmpeg.exe, or choose the AVI format (no install needed).")
	return problems


func output_path() -> String:
	var folder := str(settings["output_dir"])
	var base := str(settings["file_name"]).strip_edges().validate_filename()
	if base.is_empty():
		base = "my_film"
	match int(settings["format"]):
		Format.MP4:
			return folder.path_join(base + ".mp4")
		Format.AVI:
			return folder.path_join(base + ".avi")
	return folder.path_join(base + "_frames")


func cancel() -> void:
	if is_exporting:
		_cancel_requested = true


# --- Export ------------------------------------------------------------------------

func export_video() -> void:
	if is_exporting:
		return
	var problems := validate()
	if not problems.is_empty():
		finished.emit(false, problems[0], "")
		return
	var folder := str(settings["output_dir"])
	if DirAccess.make_dir_recursive_absolute(folder) != OK and not DirAccess.dir_exists_absolute(folder):
		finished.emit(false, "Can't create the output folder %s." % folder, "")
		return

	var format := int(settings["format"])
	var out_path := _unique_path(output_path(), format == Format.PNG)
	var frames_dir := ""
	match format:
		Format.PNG:
			frames_dir = out_path
		Format.MP4:
			frames_dir = ProjectSettings.globalize_path(TEMP_DIR)
			_remove_dir(frames_dir)
	if not frames_dir.is_empty() and DirAccess.make_dir_recursive_absolute(frames_dir) != OK:
		finished.emit(false, "Can't create the folder %s." % frames_dir, "")
		return

	var size := resolution()
	var frame_rate := fps()
	var total := frame_count()
	var quality := float(settings["quality"])
	var avi: AviMjpegWriter = null
	if format == Format.AVI:
		avi = AviMjpegWriter.new()
		var err := avi.open(out_path, size.x, size.y, frame_rate)
		if err != OK:
			finished.emit(false, "Can't write %s (%s)." % [out_path, error_string(err)], "")
			return

	# --- Prepare the scene for clean output.
	is_exporting = true
	_cancel_requested = false
	var restore_time := timeline.current_time
	if timeline.is_playing():
		timeline.pause()
	if placement and placement.is_placing():
		placement.cancel_placement()
	EventBus.render_mode_changed.emit(true)
	var editor_viewport := director.shot_camera.get_viewport() as SubViewport
	var editor_update_mode: SubViewport.UpdateMode = SubViewport.UPDATE_WHEN_VISIBLE
	if editor_viewport:
		editor_update_mode = editor_viewport.render_target_update_mode
	if editor_viewport:
		editor_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var render_level := int(settings["render_quality"])
	if environment:
		environment.set_quality_override(render_level)
	var viewport := SubViewport.new()
	viewport.name = "RenderViewport"
	viewport.size = size
	RenderQuality.apply_viewport(viewport, render_level)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var render_camera := Camera3D.new()
	render_camera.cull_mask = Layers.FINAL_RENDER_MASK
	viewport.add_child(render_camera)
	if titles:
		viewport.add_child(titles.create_overlay())
	if audio:
		audio.stop_all()
	add_child(viewport)
	render_camera.current = true
	SketchCharacter.render_camera = render_camera
	started.emit(viewport.get_texture())

	var aspect := float(size.x) / float(size.y)
	var previous_aspect := director.render_aspect
	director.render_aspect = aspect
	# Warm-up: let global illumination, volumetric fog and TAA settle on the
	# first shot before recording, so the film doesn't start with a flicker.
	var warmup := RenderQuality.WARMUP_FRAMES[render_level]
	if warmup > 0:
		phase_changed.emit("Preparing lighting…")
		timeline.apply_time_for_render(0.0)
		var first_shot := director.current_camera()
		for _w in warmup:
			if first_shot:
				director.apply_shot(render_camera, first_shot, aspect)
			await RenderingServer.frame_post_draw
	phase_changed.emit("Rendering frames…")
	var start_ms := Time.get_ticks_msec()
	var success := true
	var message := ""
	var rendered := 0

	for i in total:
		if _cancel_requested:
			success = false
			message = "Export cancelled."
			break
		timeline.apply_time_for_render(float(i) / frame_rate)
		var shot := director.current_camera()
		if shot:
			director.apply_shot(render_camera, shot, aspect)
		get_tree().call_group(&"sketch_faces", &"aim_face_now")
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		if image == null or image.is_empty():
			success = false
			message = "The renderer returned an empty frame (%d)." % (i + 1)
			break
		var err := OK
		match format:
			Format.AVI:
				err = avi.add_frame(image.save_jpg_to_buffer(quality))
			_:
				err = image.save_png(frames_dir.path_join("frame_%05d.png" % (i + 1)))
		if err != OK:
			success = false
			message = "Couldn't write frame %d (%s). Is the disk full?" % [i + 1, error_string(err)]
			break
		rendered = i + 1
		var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
		progress.emit(rendered, total, elapsed / rendered * (total - rendered))

	# --- Finish the file.
	if avi:
		var close_err := avi.close()
		if success and close_err != OK:
			success = false
			message = "Couldn't finish %s (%s)." % [out_path.get_file(), error_string(close_err)]
	if success and format == Format.MP4:
		phase_changed.emit("Encoding MP4 with FFmpeg…")
		var code: int = await _encode_mp4(frames_dir, out_path, frame_rate, quality)
		if code != 0:
			success = false
			message = "FFmpeg failed (exit code %d). The frames were rendered fine; try the AVI format." % code
		elif audio and not audio.clips.is_empty():
			phase_changed.emit("Adding sound…")
			var audio_code: int = await _mix_audio(out_path)
			if audio_code != 0:
				message = "The video was saved without sound: FFmpeg couldn't mix the audio (exit code %d)." % audio_code
	if format == Format.MP4:
		_remove_dir(frames_dir)
	if not success and format == Format.AVI and rendered == 0:
		DirAccess.remove_absolute(out_path)

	# --- Restore the editor.
	SketchCharacter.render_camera = null
	viewport.queue_free()
	if environment:
		environment.clear_quality_override()
	director.render_aspect = previous_aspect
	if editor_viewport:
		editor_viewport.render_target_update_mode = editor_update_mode
	EventBus.render_mode_changed.emit(false)
	timeline.set_time(restore_time)
	is_exporting = false

	if success:
		var seconds := (Time.get_ticks_msec() - start_ms) / 1000.0
		var audio_note := message
		message = "Exported %d frames (%.1f s of film) in %.0f s → %s" % [total, timeline.duration(), seconds, out_path.get_file()]
		var credits_file := _write_credits(out_path, format == Format.PNG)
		if not credits_file.is_empty():
			message += " (model credits in %s)" % credits_file.get_file()
		if not audio_note.is_empty():
			message += ". " + audio_note
		elif audio and not audio.clips.is_empty() and format != Format.MP4:
			message += ". Sound is only added to MP4 exports."
		finished.emit(true, message, out_path)
	else:
		finished.emit(false, message, out_path if format == Format.PNG and rendered > 0 else "")


## Writes a credits file listing downloaded models used in the film (needed for
## CC-BY models). Returns its path, or "" if no downloaded models are used.
func _write_credits(out_path: String, is_folder: bool) -> String:
	if placement == null or placement.placed_props_root == null:
		return ""
	var paths: Array = []
	for child in placement.placed_props_root.get_children():
		paths.append(str(child.get_meta(PropUtils.META_SCENE_PATH, "")))
	var lines := OnlineLibrary.credits_for_paths(paths)
	if lines.is_empty():
		return ""
	var credits_path := out_path.path_join("credits.txt") if is_folder else out_path.get_basename() + "_credits.txt"
	var file := FileAccess.open(credits_path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string("3D models used in this film\n\n" + "\n".join(lines) + "\n")
	return credits_path


func _encode_mp4(frames_dir: String, out_path: String, frame_rate: int, quality: float) -> int:
	# quality 1.0 → CRF 14 (near lossless), 0.3 → CRF 30.
	var crf := int(round(lerpf(30.0, 14.0, inverse_lerp(0.3, 1.0, quality))))
	var args := PackedStringArray([
		"-y", "-hide_banner", "-loglevel", "error",
		"-framerate", str(frame_rate),
		"-i", frames_dir.path_join("frame_%05d.png"),
		"-c:v", "libx264", "-preset", "medium", "-crf", str(crf),
		"-pix_fmt", "yuv420p", "-movflags", "+faststart",
		out_path])
	var thread := Thread.new()
	thread.start(_run_process.bind(str(settings["ffmpeg_path"]), args))
	while thread.is_alive():
		await get_tree().process_frame
	return thread.wait_to_finish()


## Mixes every audio clip (at its start time and volume) into the MP4.
func _mix_audio(video_path: String) -> int:
	var silent := video_path.get_basename() + "_silent.mp4"
	DirAccess.rename_absolute(video_path, silent)
	var args := PackedStringArray(["-y", "-hide_banner", "-loglevel", "error", "-i", silent])
	var filters := PackedStringArray()
	var labels := ""
	var n := 0
	for clip in audio.clips:
		args.append_array(["-i", ProjectSettings.globalize_path(str(clip["path"]))])
		n += 1
		var ms := roundi(float(clip["start"]) * 1000.0)
		var voice := AudioTrack.voice_filter(str(clip.get("voice", "Normal")))
		filters.append("[%d:a]%sadelay=%d|%d,volume=%sdB[a%d]" % [n, voice + "," if not voice.is_empty() else "", ms, ms, String.num(float(clip["volume_db"]), 2), n])
		labels += "[a%d]" % n
	if n == 1:
		filters.append("[a1]apad[aout]")
	else:
		filters.append("%samix=inputs=%d:duration=longest:normalize=0,apad[aout]" % [labels, n])
	args.append_array(["-filter_complex", ";".join(filters), "-map", "0:v", "-map", "[aout]",
		"-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", video_path])
	var thread := Thread.new()
	thread.start(_run_process.bind(str(settings["ffmpeg_path"]), args))
	while thread.is_alive():
		await get_tree().process_frame
	var code: int = thread.wait_to_finish()
	if code == 0:
		DirAccess.remove_absolute(silent)
	else:
		DirAccess.remove_absolute(video_path)
		DirAccess.rename_absolute(silent, video_path)
	return code


func _run_process(path: String, args: PackedStringArray) -> int:
	var output: Array = []
	return OS.execute(path, args, output, true)


func _sync_dependents() -> void:
	var size := resolution()
	if director:
		director.render_aspect = float(size.x) / float(size.y)
	if timeline:
		timeline.frame_rate = float(fps())


static func _unique_path(path: String, is_dir: bool) -> String:
	var exists := DirAccess.dir_exists_absolute(path) if is_dir else FileAccess.file_exists(path)
	if not exists:
		return path
	var ext := "" if is_dir else "." + path.get_extension()
	var stem := path if is_dir else path.get_basename()
	var n := 2
	while true:
		var candidate := "%s_%d%s" % [stem, n, ext]
		var taken := DirAccess.dir_exists_absolute(candidate) if is_dir else FileAccess.file_exists(candidate)
		if not taken:
			return candidate
		n += 1
	return path


static func _remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(path)

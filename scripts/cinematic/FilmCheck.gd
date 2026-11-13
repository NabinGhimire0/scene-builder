class_name FilmCheck
extends RefCounted
## "Check film": looks at every shot before a long export and lists what would
## spoil it - pictures that are too dark or burnt out, faces lost in shadow,
## heads cut off by the frame, the camera inside someone, and words placed over
## a bright part of the picture. Each finding has a time, so the editor can jump
## straight to it. Renders small frames (fast), never touches the saved project.

const SIZE := Vector2i(480, 270)
## Styles drawn without a box behind them (they need a calm, darker area).
const OPEN_TEXT: PackedStringArray = ["Cinematic", "Hero", "Whisper"]

var _exporter: ExportManager
var _found: Array = []
var _seen := {}


## Returns [{ "t", "level" ("problem" or "tip"), "text" }] sorted by time.
## [param on_progress] is called with (done, total).
func run(exporter: ExportManager, on_progress: Callable = Callable()) -> Array:
	_exporter = exporter
	_found.clear()
	_seen.clear()
	var timeline := exporter.timeline
	var director := exporter.director
	var length := timeline.duration()
	var times := _sample_times(timeline, length)
	var restore_time := timeline.current_time
	if timeline.is_playing():
		timeline.pause()
	EventBus.render_mode_changed.emit(true)
	# The editor's own view pauses meanwhile (faster).
	var editor_viewport: SubViewport = null
	if director.shot_camera:
		editor_viewport = director.shot_camera.get_viewport() as SubViewport
	var editor_mode := SubViewport.UPDATE_WHEN_VISIBLE
	if editor_viewport:
		editor_mode = editor_viewport.render_target_update_mode
		editor_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var level := int(exporter.settings.get("render_quality", RenderQuality.Level.HIGH))
	if exporter.environment:
		exporter.environment.set_quality_override(level)
	var viewport := SubViewport.new()
	viewport.size = SIZE
	RenderQuality.apply_viewport(viewport, level)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.cull_mask = Layers.FINAL_RENDER_MASK
	viewport.add_child(cam)
	exporter.add_child(viewport)
	cam.current = true
	SketchCharacter.render_camera = cam
	var aspect := float(SIZE.x) / float(SIZE.y)
	var previous_aspect := director.render_aspect
	director.render_aspect = aspect
	var first := true
	for i in times.size():
		var t: float = times[i]
		# After a jump, fog, shadows and anti-aliasing need a few frames to settle.
		var settle := RenderQuality.WARMUP_FRAMES[level] + 2 if first else 3
		first = false
		var shot: CinematicCamera = null
		for k in settle:
			timeline.apply_time_for_render(t)
			shot = director.current_camera()
			if shot:
				director.apply_shot(cam, shot, aspect)
			exporter.get_tree().call_group(&"sketch_faces", &"aim_face_now")
			await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		if image != null and not image.is_empty():
			_inspect(t, length, image, cam, shot)
		if on_progress.is_valid():
			on_progress.call(i + 1, times.size())
	SketchCharacter.render_camera = null
	viewport.queue_free()
	if exporter.environment:
		exporter.environment.clear_quality_override()
	director.render_aspect = previous_aspect
	if editor_viewport:
		editor_viewport.render_target_update_mode = editor_mode
	EventBus.render_mode_changed.emit(false)
	timeline.set_time(restore_time)
	_found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	return _found


## A plain-text report (for the command line and the AI film maker).
static func describe(found: Array) -> String:
	if found.is_empty():
		return "Film check: no problems found."
	var lines := PackedStringArray()
	for f in found:
		var t := float(f["t"])
		lines.append("%d:%04.1f  %s  %s" % [int(t) / 60, fmod(t, 60.0), "PROBLEM" if f["level"] == "problem" else "tip", f["text"]])
	return "Film check:\n" + "\n".join(lines)


# --- Where to look ---------------------------------------------------------------

func _sample_times(timeline: TimelineController, length: float) -> Array:
	var cuts: Array = timeline.store.cuts
	var marks: Array = []
	if cuts.is_empty():
		marks = [0.0, length]
	else:
		for cut in cuts:
			marks.append(float(cut["t"]))
		if float(marks[0]) > 0.05:
			marks.push_front(0.0)
		marks.append(length)
	var times: Array = []
	for i in marks.size() - 1:
		var a := float(marks[i])
		var b := float(marks[i + 1])
		if b - a < 0.3:
			continue
		times.append(a + minf(0.6, (b - a) * 0.3))
		if b - a > 2.5:
			times.append((a + b) * 0.5)
		if b - a > 7.0:
			times.append(b - 0.6)
	# Every on-screen text, in the middle of its time.
	if _exporter.titles:
		for item in _exporter.titles.items:
			if OPEN_TEXT.has(str(item.get("style", ""))):
				times.append(float(item["start"]) + float(item["length"]) * 0.5)
	times.sort()
	var out: Array = []
	for t in times:
		if t >= length - 0.05:
			continue
		if out.is_empty() or float(t) - float(out[out.size() - 1]) > 0.35:
			out.append(t)
	# Long films: keep it quick (evenly thinned).
	while out.size() > 160:
		var thinned: Array = []
		for i in out.size():
			if i % 2 == 0:
				thinned.append(out[i])
		out = thinned
	return out


# --- What to look for ------------------------------------------------------------

func _inspect(t: float, length: float, image: Image, cam: Camera3D, shot: CinematicCamera) -> void:
	var small := image.duplicate() as Image
	small.resize(96, 54, Image.INTERPOLATE_BILINEAR)
	var w := small.get_width()
	var h := small.get_height()
	# Letterbox bars are black on purpose: leave them out.
	var bars := _letterbox_at(t)
	var top := 0
	var bottom := h
	if bars:
		var bar := int(round((h - w / 2.39) * 0.5))
		top = bar
		bottom = h - bar
	var total := 0.0
	var count := 0
	var clipped := 0
	for y in range(top, bottom):
		for x in w:
			var l := _lum(small.get_pixel(x, y))
			total += l
			count += 1
			if l > 0.95:
				clipped += 1
	var mean := total / maxf(float(count), 1.0)
	var label: String = str(shot.name) if shot else "the view"
	var fading := t > length - 4.0 or t < 1.0   # deliberate fade in / out
	# Flashes (lightning, a white-out between scenes) and fades to black are on purpose.
	if _exporter.environment:
		var exposure := float(_exporter.environment.exposure)
		if exposure > 2.0 or exposure < 0.35:
			fading = true
	if not fading:
		if mean < 0.05:
			_add(t, "problem", "%s is almost black. Brighten it (LIGHT: exposure 1.3) or add a light." % label, "dark" + label)
		elif mean < 0.1:
			_add(t, "tip", "%s is very dark; on a phone it will look black. Try LIGHT: exposure 1.2." % label, "dark" + label)
		if float(clipped) / maxf(float(count), 1.0) > 0.35:
			_add(t, "problem", "%s is burnt out (a third of the picture is pure white). Lower the exposure or the glow, or turn the camera away from the sun." % label, "bright" + label)
	_check_people(t, image, cam, bars, mean, fading)
	_check_words(t, small, bars)


func _check_people(t: float, image: Image, cam: Camera3D, bars: bool, picture_mean: float, fading: bool) -> void:
	var root := _exporter.timeline.placed_props_root
	if root == null:
		return
	var size := Vector2(image.get_width(), image.get_height())
	var top_edge := 0.0
	var bottom_edge := size.y
	if bars:
		var bar := maxf((size.y - size.x / 2.39) * 0.5, 0.0)
		top_edge = bar
		bottom_edge = size.y - bar
	for child in root.get_children():
		if not child is CharacterBase:
			continue
		var person := child as CharacterBase
		if not person.is_visible_in_tree() or person.global_basis.get_scale().y < 0.05:
			continue
		var display := _exporter.timeline.display_name(person)
		var feet := person.global_position
		var head := person.joint_position("Head")
		if head == Vector3.INF:
			head = feet + Vector3.UP * 1.6 * person.global_basis.get_scale().y
		var small_one := head.y - feet.y < 1.0   # animals and children: no face or head-room checks
		var eye := cam.global_position
		# The camera inside the person.
		var flat := Vector2(eye.x - feet.x, eye.z - feet.z).length()
		if flat < 0.3 and eye.y > feet.y - 0.1 and eye.y < head.y + 0.15:
			_add(t, "problem", "The camera is inside %s. Move the shot back a little." % display, "inside" + display)
			continue
		if cam.is_position_behind(head) or eye.distance_to(head) > 14.0:
			continue
		var hp := cam.unproject_position(head)
		var fp := cam.unproject_position(feet + Vector3.UP * 0.9)
		var body_on := fp.x > size.x * 0.12 and fp.x < size.x * 0.88 and fp.y > top_edge and fp.y < bottom_edge
		# Head above the frame while the body is in the middle of it.
		if small_one:
			continue
		if body_on and hp.y < top_edge - size.y * 0.02 and hp.x > 0.0 and hp.x < size.x and eye.distance_to(head) < 6.0:
			_add(t, "tip", "%s's head is cut off at the top of the frame. Tilt the shot up or step back." % display, "head" + display)
			continue
		# Face lost in darkness (while the picture itself is fine).
		if not fading and hp.x > 4 and hp.x < size.x - 4 and hp.y > top_edge + 4 and hp.y < bottom_edge - 4 and eye.distance_to(head) < 7.0 and picture_mean > 0.08:
			var face := 0.0
			var n := 0
			var r := clampi(int(size.y * 0.02), 2, 8)
			for dy in range(-r, r + 1, 2):
				for dx in range(-r, r + 1, 2):
					var px := clampi(int(hp.x) + dx, 0, int(size.x) - 1)
					var py := clampi(int(hp.y) + dy, 0, int(size.y) - 1)
					face += _lum(image.get_pixel(px, py))
					n += 1
			face /= maxf(float(n), 1.0)
			if face < 0.045:
				_add(t, "tip", "%s's face is in deep shadow. Turn them towards the light, add a lamp, or light the shot from the other side." % display, "face" + display)


func _check_words(t: float, small: Image, bars: bool) -> void:
	if _exporter.titles == null:
		return
	for entry in _exporter.titles.visible_at(t):
		var item: Dictionary = entry[0] if entry is Array else entry
		var style := str(item.get("style", ""))
		if not OPEN_TEXT.has(style):
			continue
		var w := small.get_width()
		var h := small.get_height()
		var total := 0.0
		var n := 0
		for y in range(int(h * 0.4), int(h * 0.6)):
			for x in range(int(w * 0.22), int(w * 0.78)):
				total += _lum(small.get_pixel(x, y))
				n += 1
		var mean := total / maxf(float(n), 1.0)
		if mean > 0.62:
			var words := str(item.get("text", "")).replace("\n", " ").left(30)
			_add(t, "tip", "The words \"%s\" sit on a very bright area. Move them to a darker moment, or lower the glow." % words, "words" + words)


func _letterbox_at(t: float) -> bool:
	if _exporter.titles == null:
		return false
	for item in _exporter.titles.items:
		if str(item.get("style", "")) == "Letterbox" and t >= float(item["start"]) and t <= float(item["start"]) + float(item["length"]):
			return true
	return false


## One finding per problem and shot (not one per sample).
func _add(t: float, level: String, text: String, key: String) -> void:
	if _seen.has(key):
		return
	_seen[key] = true
	_found.append({"t": snappedf(t, 0.1), "level": level, "text": text})


static func _lum(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722

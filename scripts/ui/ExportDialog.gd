class_name ExportDialog
extends ConfirmationDialog
## "Export Video" window: settings → progress (live preview, ETA, cancel) →
## result (open folder / play the file).

enum State { SETUP, RENDERING, DONE }

var exporter: ExportManager
var timeline: TimelineController

var _state := State.SETUP
var _settings_box: VBoxContainer
var _progress_box: VBoxContainer
var _resolution: OptionButton
var _fps: OptionButton
var _format: OptionButton
var _quality: SliderRow
var _look: OptionButton
var _folder: LineEdit
var _file_name: LineEdit
var _ffmpeg_row: HBoxContainer
var _ffmpeg_path: LineEdit
var _ffmpeg_status: Label
var _summary: Label
var _problems: Label
var _preview: TextureRect
var _progress: ProgressBar
var _progress_label: Label
var _result_path := ""
var _folder_dialog: FileDialog
var _ffmpeg_dialog: FileDialog
var _updating := false
var _mode := 0   # 0 direct export, 1 render in Blender
var _start_button: Button
var _blender_box: VBoxContainer
var _blender_path: LineEdit
var _blender_dialog: FileDialog
var _samples: OptionButton
var _auto_render: CheckBox
var _blender_pid := -1
var _check_button: Button
var _check_results: RichTextLabel
var _checking := false
var _blender_frame := 0


func setup(export_manager: ExportManager, timeline_controller: TimelineController) -> void:
	exporter = export_manager
	timeline = timeline_controller
	title = "Export Video"
	min_size = Vector2i(560, 520)
	dialog_hide_on_ok = false
	exclusive = true
	transient = true
	_build()
	confirmed.connect(_on_primary_pressed)
	canceled.connect(_on_cancel_pressed)
	exporter.started.connect(_on_export_started)
	exporter.progress.connect(_on_export_progress)
	exporter.phase_changed.connect(func(text: String) -> void: _progress_label.text = text)
	exporter.finished.connect(_on_export_finished)
	exporter.settings_changed.connect(_refresh)


func open() -> void:
	_set_state(State.SETUP)
	_refresh()
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	popup_centered(Vector2i(mini(700, screen.x - 40), mini(680, screen.y - 80)))


# --- Layout --------------------------------------------------------------------

func _build() -> void:
	# Scrollable content so the window always fits the screen and its buttons stay visible.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(600, 380)
	add_child(scroll)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 8)
	root.add_child(_settings_box)
	_build_mode_choice()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	_settings_box.add_child(grid)

	_resolution = OptionButton.new()
	for item in ExportManager.RESOLUTION_NAMES:
		_resolution.add_item(item)
	_resolution.item_selected.connect(func(i: int) -> void: _change_setting("resolution", i))
	_row(grid, "Resolution", _resolution)

	_fps = OptionButton.new()
	for value in ExportManager.FPS_OPTIONS:
		_fps.add_item("%d fps" % value)
	_fps.item_selected.connect(func(i: int) -> void: _change_setting("fps", ExportManager.FPS_OPTIONS[i]))
	_row(grid, "Frame rate", _fps)

	_format = OptionButton.new()
	for item in ExportManager.FORMAT_NAMES:
		_format.add_item(item)
	_format.item_selected.connect(func(i: int) -> void: _change_setting("format", i))
	_row(grid, "Format", _format)

	_quality = SliderRow.new()
	_quality.setup("", 0.3, 1.0, 0.01, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_quality.value_edited.connect(func(v: float) -> void: _change_setting("quality", v))
	_row(grid, "Quality", _quality)

	_look = OptionButton.new()
	for i in RenderQuality.NAMES.size():
		_look.add_item(RenderQuality.NAMES[i])
		_look.set_item_tooltip(i, RenderQuality.HINTS[i])
	_look.item_selected.connect(func(i: int) -> void: _change_setting("render_quality", i))
	_row(grid, "Lighting", _look)

	var folder_row := HBoxContainer.new()
	_folder = LineEdit.new()
	_folder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_folder.text_changed.connect(func(t: String) -> void: _change_setting("output_dir", t))
	folder_row.add_child(_folder)
	var browse := Button.new()
	browse.text = "Browse…"
	browse.pressed.connect(func() -> void: _folder_dialog.popup_centered_ratio(0.6))
	folder_row.add_child(browse)
	_row(grid, "Save to folder", folder_row)

	_file_name = LineEdit.new()
	_file_name.text_changed.connect(func(t: String) -> void: _change_setting("file_name", t))
	_row(grid, "File name", _file_name)

	_ffmpeg_row = HBoxContainer.new()
	_ffmpeg_path = LineEdit.new()
	_ffmpeg_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ffmpeg_path.placeholder_text = "ffmpeg"
	_ffmpeg_path.text_submitted.connect(func(t: String) -> void: _change_setting("ffmpeg_path", t))
	_ffmpeg_path.focus_exited.connect(func() -> void: _change_setting("ffmpeg_path", _ffmpeg_path.text))
	_ffmpeg_row.add_child(_ffmpeg_path)
	var find := Button.new()
	find.text = "Locate…"
	find.pressed.connect(func() -> void: _ffmpeg_dialog.popup_centered_ratio(0.6))
	_ffmpeg_row.add_child(find)
	_row(grid, "FFmpeg", _ffmpeg_row)

	_ffmpeg_status = Label.new()
	_ffmpeg_status.theme_type_variation = &"DimLabel"
	_ffmpeg_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_settings_box.add_child(_ffmpeg_status)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_settings_box.add_child(_summary)
	_problems = Label.new()
	_problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems.add_theme_color_override("font_color", Color(1, 0.55, 0.45))
	_settings_box.add_child(_problems)
	_check_button = Button.new()
	_check_button.text = "Check film first"
	_check_button.tooltip_text = "Looks at every shot in a minute or two and lists what would spoil the video:\ntoo dark or burnt-out shots, faces in deep shadow, heads cut off by the frame,\nthe camera inside someone, and words over a bright area. Click a time to jump there."
	_check_button.pressed.connect(_on_check_pressed)
	_settings_box.add_child(_check_button)
	_check_results = RichTextLabel.new()
	_check_results.bbcode_enabled = true
	_check_results.fit_content = true
	_check_results.scroll_active = false
	_check_results.visible = false
	_check_results.meta_clicked.connect(_on_check_link)
	_settings_box.add_child(_check_results)
	_start_button = Button.new()
	_start_button.text = "Start Export"
	_start_button.custom_minimum_size = Vector2(0, 40)
	_start_button.pressed.connect(_on_primary_pressed)
	_settings_box.add_child(_start_button)

	_progress_box = VBoxContainer.new()
	_progress_box.add_theme_constant_override("separation", 8)
	_progress_box.visible = false
	root.add_child(_progress_box)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(512, 288)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_progress_box.add_child(_preview)
	_progress = ProgressBar.new()
	_progress.min_value = 0
	_progress.max_value = 1
	_progress_box.add_child(_progress)
	_progress_label = Label.new()
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress_box.add_child(_progress_label)

	_folder_dialog = FileDialog.new()
	_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_folder_dialog.title = "Choose output folder"
	_folder_dialog.dir_selected.connect(func(dir: String) -> void: _change_setting("output_dir", dir))
	_use_native(_folder_dialog)
	add_child(_folder_dialog)

	_ffmpeg_dialog = FileDialog.new()
	_ffmpeg_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_ffmpeg_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_ffmpeg_dialog.title = "Locate ffmpeg (ffmpeg.exe on Windows)"
	_ffmpeg_dialog.file_selected.connect(func(path: String) -> void: _change_setting("ffmpeg_path", path))
	_use_native(_ffmpeg_dialog)
	add_child(_ffmpeg_dialog)


func _on_check_pressed() -> void:
	if _checking or exporter.is_exporting:
		return
	_checking = true
	_check_button.disabled = true
	_start_button.disabled = true
	_check_results.visible = true
	_check_results.text = "Checking the film…"
	var check := FilmCheck.new()
	var found: Array = await check.run(exporter, func(done: int, total: int) -> void:
		_check_results.text = "Checking the film… shot %d of %d" % [done, total])
	_checking = false
	_check_button.disabled = false
	_start_button.disabled = false
	if found.is_empty():
		_check_results.text = "[color=#8fd18f]✓ No problems found. Ready to export.[/color]"
		return
	var problems := 0
	var lines := PackedStringArray()
	for f in found:
		var t := float(f["t"])
		var bad: bool = f["level"] == "problem"
		if bad:
			problems += 1
		lines.append("[url=%s]%d:%04.1f[/url]  [color=%s]%s[/color] %s" % [t, int(t) / 60, fmod(t, 60.0),
			"#ff8a70" if bad else "#f0c060", "Problem:" if bad else "Tip:", str(f["text"]).replace("[", "(").replace("]", ")")])
	var head := "%d problem%s and %d tip%s. Click a time to jump there (the window closes); you can still export as it is.\n" % [
		problems, "" if problems == 1 else "s", found.size() - problems, "" if found.size() - problems == 1 else "s"]
	_check_results.text = head + "\n".join(lines)


func _on_check_link(meta: Variant) -> void:
	timeline.set_time(float(str(meta)))
	hide()


static func _use_native(dialog: FileDialog) -> void:
	if "use_native_dialog" in dialog:
		dialog.set("use_native_dialog", true)


static func _row(grid: GridContainer, text: String, control: Control) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"DimLabel"
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


# --- Settings ------------------------------------------------------------------

func _change_setting(key: String, value: Variant) -> void:
	if _updating:
		return
	exporter.set_setting(key, value)


func _refresh() -> void:
	_updating = true
	var s := exporter.settings
	_resolution.select(int(s["resolution"]))
	_fps.select(maxi(ExportManager.FPS_OPTIONS.find(int(s["fps"])), 0))
	_format.select(int(s["format"]))
	_quality.set_value(float(s["quality"]))
	_look.select(int(s.get("render_quality", RenderQuality.Level.CINEMATIC)))
	if not _folder.has_focus():
		_folder.text = str(s["output_dir"])
	if not _file_name.has_focus():
		_file_name.text = str(s["file_name"])
	if not _ffmpeg_path.has_focus():
		_ffmpeg_path.text = str(s["ffmpeg_path"])
	_updating = false

	var format := int(s["format"])
	_ffmpeg_row.get_parent().get_child(_ffmpeg_row.get_index() - 1).visible = format == ExportManager.Format.MP4
	_ffmpeg_row.visible = format == ExportManager.Format.MP4
	_ffmpeg_status.visible = format == ExportManager.Format.MP4
	if format == ExportManager.Format.MP4:
		_ffmpeg_status.text = "FFmpeg found — MP4 export ready." if exporter.ffmpeg_available() \
			else "FFmpeg not found. Download it from ffmpeg.org and press Locate…, or pick AVI (works without FFmpeg)."
	_quality.set_editable(format != ExportManager.Format.PNG)

	var res := exporter.resolution()
	_summary.text = "%.1f s at %d fps = %d frames, %d×%d.\nSaves to: %s" % [
		timeline.duration(), exporter.fps(), exporter.frame_count(), res.x, res.y, exporter.output_path()]
	var problems := exporter.validate()
	if _mode == 1:
		problems = PackedStringArray()
		_summary.text = "%.1f s at %d fps = %d frames, %d×%d, rendered by Blender (Cycles, %s samples).\nSaves to: %s" % [
			timeline.duration(), exporter.fps(), exporter.frame_count(), res.x, res.y,
			_samples.get_item_text(_samples.selected), str(exporter.settings["output_dir"])]
	for control in [_format, _quality, _look, _ffmpeg_row, _ffmpeg_status]:
		_set_row_visible(control, _mode == 0 and (control != _ffmpeg_row and control != _ffmpeg_status or int(exporter.settings["format"]) == ExportManager.Format.MP4))
	_blender_box.visible = _mode == 1
	_problems.text = "\n".join(problems)
	get_ok_button().disabled = not problems.is_empty() and _state == State.SETUP
	if _start_button:
		_start_button.disabled = get_ok_button().disabled


# --- Flow ----------------------------------------------------------------------

func _set_state(state: State) -> void:
	_state = state
	_settings_box.visible = state == State.SETUP
	_progress_box.visible = state != State.SETUP
	match state:
		State.SETUP:
			ok_button_text = "Start Export" if _mode == 0 else ("Render in Blender" if _auto_render.button_pressed else "Create Blender Files")
			if _start_button:
				_start_button.text = "▶  " + ok_button_text
			get_cancel_button().text = "Close"
			get_ok_button().disabled = false
			get_ok_button().visible = true
		State.RENDERING:
			ok_button_text = "Rendering…"
			get_ok_button().disabled = true
			get_cancel_button().text = "Cancel Export"
		State.DONE:
			ok_button_text = "Open Folder" if not _result_path.is_empty() else "Back"
			get_ok_button().disabled = false
			get_cancel_button().text = "Close"


func _on_primary_pressed() -> void:
	match _state:
		State.SETUP:
			if _mode == 1:
				_start_blender_render()
				return
			if not exporter.validate().is_empty():
				_refresh()
				return
			_progress.value = 0
			_progress_label.text = "Preparing…"
			_set_state(State.RENDERING)
			exporter.export_video()
		State.DONE:
			if _result_path.is_empty():
				_set_state(State.SETUP)
				_refresh()
			else:
				var folder := _result_path if DirAccess.dir_exists_absolute(_result_path) else _result_path.get_base_dir()
				OS.shell_open(folder)


func _on_cancel_pressed() -> void:
	if _state == State.RENDERING:
		if _blender_pid > 0:
			OS.kill(_blender_pid)
		else:
			exporter.cancel()


func _on_export_started(preview: Texture2D) -> void:
	_preview.texture = preview


func _on_export_progress(frame: int, total: int, eta: float) -> void:
	_progress.max_value = total
	_progress.value = frame
	_progress_label.text = "Frame %d of %d · about %s left" % [frame, total, _format_duration(eta)]


func _on_export_finished(success: bool, message: String, path: String) -> void:
	_result_path = path if success or not path.is_empty() else ""
	_preview.texture = null
	_progress_label.text = message
	if success:
		_progress.value = _progress.max_value
		EventBus.info(message)
	else:
		EventBus.error(message)
	if _state == State.SETUP:
		# Validation failed before rendering started.
		_refresh()
		_problems.text = message
		return
	_set_state(State.DONE)
	if not visible:
		return


static func _format_duration(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%d:%02d" % [s / 60, s % 60] if s >= 60 else "%d s" % s


# --- Blender mode ---------------------------------------------------------------

func _build_mode_choice() -> void:
	var label := Label.new()
	label.text = "MAKE THE VIDEO WITH"
	label.theme_type_variation = &"SectionHeader"
	_settings_box.add_child(label)
	var row := HBoxContainer.new()
	var group := ButtonGroup.new()
	for i in 2:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "Direct export (fast)" if i == 0 else "Render in Blender (best quality)"
		button.tooltip_text = "Scene Builder renders the video itself, in about real time" if i == 0 \
			else "Blender's Cycles path tracer: film-quality light, reflections and glass. Much slower (minutes per second of film)."
		button.button_pressed = i == 0
		button.toggled.connect(func(on: bool) -> void: _on_mode(i, on))
		row.add_child(button)
	_settings_box.add_child(row)

	_blender_box = VBoxContainer.new()
	_blender_box.add_theme_constant_override("separation", 6)
	_blender_box.visible = false
	_settings_box.add_child(_blender_box)
	var path_row := HBoxContainer.new()
	var path_label := Label.new()
	path_label.text = "Blender"
	path_label.theme_type_variation = &"DimLabel"
	path_row.add_child(path_label)
	_blender_path = LineEdit.new()
	_blender_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blender_path.placeholder_text = "Path to blender / blender.exe"
	_blender_path.text = _saved_blender_path()
	path_row.add_child(_blender_path)
	var locate := Button.new()
	locate.text = "Locate…"
	locate.pressed.connect(func() -> void: _blender_dialog.popup_centered_ratio(0.6))
	path_row.add_child(locate)
	_blender_box.add_child(path_row)
	_blender_dialog = FileDialog.new()
	_blender_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_blender_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_blender_dialog.file_selected.connect(func(path: String) -> void: _blender_path.text = path)
	add_child(_blender_dialog)
	var samples_row := HBoxContainer.new()
	var samples_label := Label.new()
	samples_label.text = "Quality"
	samples_label.theme_type_variation = &"DimLabel"
	samples_row.add_child(samples_label)
	_samples = OptionButton.new()
	for item in ["64 (draft)", "128 (good)", "256 (high)", "512 (best, slow)"]:
		_samples.add_item(item)
	_samples.select(1)
	_samples.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_samples.item_selected.connect(func(_i: int) -> void: _refresh())
	samples_row.add_child(_samples)
	_blender_box.add_child(samples_row)
	_auto_render = CheckBox.new()
	_auto_render.text = "Render the video now (otherwise only prepare the Blender files)"
	_auto_render.button_pressed = true
	_auto_render.toggled.connect(func(_on: bool) -> void: _set_state(_state))
	_blender_box.add_child(_auto_render)
	var note := Label.new()
	note.theme_type_variation = &"DimLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "Uses the resolution and frame rate below. Fire/smoke/weather particles and imported characters' body animation stay in Scene Builder only."
	_blender_box.add_child(note)


func _on_mode(index: int, on: bool) -> void:
	if not on:
		return
	_mode = index
	_set_state(State.SETUP)
	_refresh()


static func _set_row_visible(control: Control, show: bool) -> void:
	if control == null:
		return
	control.visible = show
	var parent := control.get_parent()
	if parent is GridContainer and control.get_index() > 0:
		parent.get_child(control.get_index() - 1).visible = show


func _saved_blender_path() -> String:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	return str(config.get_value("avatar", "blender_path", ""))


func _start_blender_render() -> void:
	var folder_parent := str(exporter.settings["output_dir"])
	if folder_parent.is_empty() or not DirAccess.dir_exists_absolute(folder_parent):
		_problems.text = "Choose a folder to save to."
		return
	var blender := _blender_path.text.strip_edges()
	if _auto_render.button_pressed and (blender.is_empty() or not FileAccess.file_exists(blender)):
		_problems.text = "Blender wasn't found: install Blender 4.x and press Locate… (or untick \"Render the video now\")."
		return
	if not blender.is_empty():
		var config := ConfigFile.new()
		config.load("user://settings.cfg")
		config.set_value("avatar", "blender_path", blender)
		config.save("user://settings.cfg")
	var base := str(exporter.settings["file_name"]).strip_edges().validate_filename()
	var folder := exporter.blender_export.export_scene(folder_parent, base if not base.is_empty() else "film")
	if folder.is_empty():
		return
	if not _auto_render.button_pressed:
		_result_path = folder
		_set_state(State.DONE)
		_progress_label.text = "Blender files saved in %s. Open README.txt there to render." % folder
		return
	_set_state(State.RENDERING)
	_progress.max_value = exporter.frame_count()
	_progress.value = 0
	_progress_label.text = "Starting Blender…"
	var samples: String = ["64", "128", "256", "512"][_samples.selected]
	var args := PackedStringArray(["-b", "-P", folder.path_join("render_in_blender.py"), "--", "--render", "--samples", samples])
	var process := OS.execute_with_pipe(blender, args)
	if process.is_empty():
		_on_export_finished(false, "Couldn't start Blender.", "")
		return
	_blender_pid = int(process["pid"])
	_blender_frame = 0
	var reader := Thread.new()
	reader.start(_read_blender_output.bind(process["stdio"]))
	var start_ms := Time.get_ticks_msec()
	while OS.is_process_running(_blender_pid):
		_progress.value = _blender_frame
		if _blender_frame > 0:
			var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
			_progress_label.text = "Blender: frame %d of %d · about %s left" % [_blender_frame, exporter.frame_count(),
				_format_duration(elapsed / _blender_frame * (exporter.frame_count() - _blender_frame))]
		await get_tree().process_frame
	reader.wait_to_finish()
	_blender_pid = -1
	var video_folder := folder.path_join("render")
	if DirAccess.dir_exists_absolute(video_folder) and not DirAccess.get_files_at(video_folder).is_empty():
		_on_export_finished(true, "Blender finished rendering → %s" % video_folder, video_folder)
	else:
		_on_export_finished(false, "Blender stopped before finishing (see its messages by running render_in_blender.py in Blender). The scene files are in %s." % folder, folder)


## Reads Blender's console output ("Fra:12 …") to show progress.
func _read_blender_output(pipe: FileAccess) -> void:
	while pipe.is_open() and pipe.get_error() == OK:
		var line := pipe.get_line()
		if line.begins_with("Fra:"):
			_blender_frame = maxi(_blender_frame, line.substr(4).get_slice(" ", 0).to_int())


func _on_export_blender() -> void:
	var base := str(exporter.settings["file_name"]).strip_edges().validate_filename()
	var folder := exporter.blender_export.export_scene(str(exporter.settings["output_dir"]), base if not base.is_empty() else "film")
	if not folder.is_empty():
		_summary.text = "Blender export saved to:\n%s\nOpen README.txt there for the two-step render." % folder
		OS.shell_open(folder)

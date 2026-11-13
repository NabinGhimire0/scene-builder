extends CanvasLayer
## Application shell: toolbar, keyboard shortcuts, file dialogs, status bar,
## window title. Wires UI widgets to the editor systems; holds no scene logic.

const APP_NAME := "Scene Builder"
const IDLE_HINT := "Drag an asset into the scene · Click an object to select · Right-drag orbit · Middle-drag pan · Wheel zoom"
const SELECTED_HINT := "%s selected · Drag to move · Del delete · Ctrl+D duplicate · F frame · Esc deselect"
const PLACING_HINT := "Placing %s · Click to place · R rotate (Shift+R back) · Esc to stop"
const STATUS_SECONDS := 5.0
const ERROR_COLOR := Color(1.0, 0.5, 0.45)
const CAMERA_VIEW_HINT := "Camera View · %s · this is what the export looks like · Tab returns to Editor View"
const MIN_WINDOW_SIZE := Vector2i(1200, 720)

@export var placement: PlacementController
@export var selection: SelectionManager
@export var history: EditorHistory
@export var document: SceneDocument
@export var editor_camera: EditorCamera
@export var ground_mesh: MeshInstance3D
@export var director: CinematicDirector
@export var timeline: TimelineController
@export var exporter: ExportManager
@export var timeline_panel: Control
@export var tools: WorldTools
@export var templates: TemplateBuilder
@export var script_director: ScriptDirector

var _new_menu: MenuButton
var _tutorial: TutorialOverlay

var _status_serial := 0
var _pending_confirm := Callable()
var _save_dialog: FileDialog
var _open_dialog: FileDialog
var _confirm_dialog: ConfirmationDialog
var _export_dialog: ExportDialog
var _script_dialog: ScriptDialog
var _script_button: Button

@onready var _status: Label = %StatusLabel
@onready var _prop_count: Label = %PropCountLabel
@onready var _file_label: Label = %FileLabel
@onready var _hint: Label = %ViewportHint
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _undo_button: Button = %UndoButton
@onready var _redo_button: Button = %RedoButton
@onready var _clear_button: Button = %ClearButton
@onready var _grid_toggle: CheckButton = %GridSnapToggle
@onready var _grid_step: SpinBox = %GridStepSpin
@onready var _camera_speed: HSlider = %CameraSpeedSlider
@onready var _camera_speed_label: Label = %CameraSpeedValue
@onready var _smooth_toggle: CheckBox = %SmoothCameraToggle
@onready var _add_camera_button: Button = %AddCameraButton
@onready var _play_cinematic_button: Button = %PlayCinematicButton
@onready var _export_button: Button = %ExportVideoButton


func _ready() -> void:
	if placement == null or selection == null or history == null or document == null:
		push_error("MainUI: placement, selection, history and document must be assigned.")
		return
	get_window().min_size = MIN_WINDOW_SIZE
	get_tree().set_auto_accept_quit(false)
	_create_dialogs()
	_add_templates_menu()
	_add_script_button()
	_add_tutorial()
	_add_pages()

	_save_button.pressed.connect(save)
	_load_button.pressed.connect(open)
	_undo_button.pressed.connect(history.undo)
	_redo_button.pressed.connect(history.redo)
	_clear_button.pressed.connect(_on_clear_pressed)
	_grid_toggle.toggled.connect(func(_on: bool) -> void: _push_grid())
	_grid_step.value_changed.connect(func(_v: float) -> void: _push_grid())
	_camera_speed.value_changed.connect(_on_camera_speed_changed)
	_smooth_toggle.toggled.connect(_on_smooth_toggled)
	_add_camera_button.pressed.connect(_on_add_camera)
	_play_cinematic_button.pressed.connect(_on_play_cinematic)
	_export_button.pressed.connect(open_export)
	director.view_mode_changed.connect(func(_m: int) -> void: _update_hint())
	timeline.playing_changed.connect(_on_playing_changed)

	EventBus.status_message.connect(_show_status)
	EventBus.placement_started.connect(func(_p: Dictionary) -> void: _update_hint())
	EventBus.placement_ended.connect(_update_hint)
	EventBus.selection_changed.connect(func(_n: Node3D) -> void: _update_hint())
	EventBus.history_changed.connect(_on_history_changed)
	EventBus.document_changed.connect(_update_title)

	_push_grid()
	_on_camera_speed_changed(_camera_speed.value)
	if editor_camera:
		_smooth_toggle.button_pressed = editor_camera.smooth_enabled
	_on_history_changed()
	_update_hint()
	_update_title()


# --- Shortcuts -------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if not (key.ctrl_pressed or key.meta_pressed):
		if not key.alt_pressed:
			_handle_plain_key(key)
		return
	var handled := true
	match key.keycode:
		KEY_Z:
			if key.shift_pressed:
				history.redo()
			else:
				history.undo()
		KEY_Y:
			history.redo()
		KEY_S:
			if key.shift_pressed:
				save_as()
			else:
				save()
		KEY_O:
			open()
		KEY_N:
			new_scene()
		KEY_E:
			open_export()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


## Shortcuts without modifiers (they never fire while typing in a text field,
## because focused fields consume those keys first).
func _handle_plain_key(key: InputEventKey) -> void:
	if tools and tools.is_active():
		if tools.handle_key(key):
			get_viewport().set_input_as_handled()
			return
		if key.keycode == KEY_ESCAPE:
			tools.cancel()
			get_viewport().set_input_as_handled()
			return
	var handled := true
	match key.keycode:
		KEY_SPACE:
			timeline.toggle_play()
		KEY_HOME:
			timeline.set_time(0.0)
		KEY_END:
			if selection.has_selection():
				handled = false  # SelectionManager: drop to ground
			else:
				timeline.set_time(timeline.duration())
		KEY_COMMA:
			timeline.step_frames(-1)
		KEY_PERIOD:
			timeline.step_frames(1)
		KEY_I:
			timeline.add_keyframe(selection.selected if selection.has_selection() else null)
		KEY_TAB:
			director.toggle_view_mode()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if exporter != null and exporter.is_exporting:
			EventBus.info("A video export is running. Cancel it in the export window before quitting.")
		elif document != null and document.is_dirty():
			_ask("Quit Scene Builder?", "You have unsaved changes. Quit without saving?", "Quit without saving",
				func() -> void: get_tree().quit())
		else:
			get_tree().quit()


# --- File commands ----------------------------------------------------------------

func save() -> void:
	if document.current_path.is_empty():
		save_as()
	else:
		document.save_to(document.current_path)


func save_as() -> void:
	_cancel_modes()
	_save_dialog.current_file = document.display_name() if not document.current_path.is_empty() else "my_scene.json"
	_save_dialog.popup_centered_ratio(0.6)


func open() -> void:
	_cancel_modes()
	_guard_unsaved("Open another scene?", func() -> void: _open_dialog.popup_centered_ratio(0.6))


func new_scene() -> void:
	_cancel_modes()
	_guard_unsaved("Start a new scene?", document.new_scene)


func _on_clear_pressed() -> void:
	_cancel_modes()
	var count := document.object_count()
	if count == 0:
		EventBus.info("The scene is already empty.")
		return
	_ask("Clear scene?", "Remove all %d objects and cameras, and their keyframes?\nYou can undo this with Ctrl+Z." % count,
		"Clear", document.clear_all_undoable)


func _add_templates_menu() -> void:
	if templates == null:
		return
	var menu := MenuButton.new()
	menu.text = "New"
	menu.flat = false
	menu.tooltip_text = "Start a blank world (Ctrl+N) or a ready-made template scene"
	var names := TemplateBuilder.TEMPLATES.keys()
	for i in names.size():
		menu.get_popup().add_item(str(names[i]), i)
		var index := menu.get_popup().get_item_index(i)
		menu.get_popup().set_item_tooltip(index, str(TemplateBuilder.TEMPLATES[names[i]]))
		if i == 0:
			menu.get_popup().add_separator("Templates")
	menu.get_popup().id_pressed.connect(_on_template_chosen)
	var bar := _save_button.get_parent()
	bar.add_child(menu)
	bar.move_child(menu, _save_button.get_index())
	_new_menu = menu


func _add_script_button() -> void:
	if script_director == null:
		return
	_script_dialog = ScriptDialog.new()
	_script_dialog.director = script_director
	_script_dialog.timeline = timeline
	_script_dialog.guard = _guard_unsaved
	add_child(_script_dialog)
	_script_button = Button.new()
	_script_button.text = "Script"
	_script_button.tooltip_text = "Build a whole film from a script: write one, paste one from an AI chat, or open a film package"
	_script_button.pressed.connect(open_script)
	var bar := _save_button.get_parent()
	bar.add_child(_script_button)
	bar.move_child(_script_button, _save_button.get_index())


# --- Pages: Scene / Characters / Music & Voice -------------------------------------

var _page_buttons: Dictionary = {}
var _pages: Dictionary = {}
var _page := "scene"
var _character_studio: CharacterStudio


func _add_pages() -> void:
	var layout := get_node_or_null("Layout") as Control
	var workspace := get_node_or_null("Layout/Workspace") as Control
	if layout == null or workspace == null:
		return
	var bar := _save_button.get_parent()
	var group := ButtonGroup.new()
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	var at := 1
	for entry in [["scene", "Scene", "Build and film your scene"],
			["characters", "Characters", "Make your own people and animals: realistic, animated-film, cartoon, sketch"],
			["music", "Music & Voice", "Import music, record your voice and change it (man, woman, child, robot…)"]]:
		var b := Button.new()
		b.text = entry[1]
		b.tooltip_text = entry[2]
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = &"PageTab"
		b.pressed.connect(show_page.bind(entry[0]))
		tabs.add_child(b)
		_page_buttons[entry[0]] = b
	bar.add_child(tabs)
	bar.move_child(tabs, at)
	var sep := VSeparator.new()
	bar.add_child(sep)
	bar.move_child(sep, at + 1)
	(_page_buttons["scene"] as Button).button_pressed = true

	_character_studio = CharacterStudio.new()
	_character_studio.visible = false
	layout.add_child(_character_studio)
	layout.move_child(_character_studio, workspace.get_index() + 1)
	_character_studio.place_requested.connect(_place_from_studio)
	_character_studio.library_changed.connect(_refresh_assets)
	_pages["characters"] = _character_studio

	var music := MusicStudio.new()
	music.visible = false
	music.film_audio = _find_audio_track()
	layout.add_child(music)
	layout.move_child(music, workspace.get_index() + 2)
	music.timeline = timeline
	music.history = history
	_pages["music"] = music


func show_page(page: String) -> void:
	if page == _page:
		return
	_cancel_modes()
	_page = page
	var scene_on := page == "scene"
	for path in ["Layout/Workspace", "Layout/TimelinePanel"]:
		var node := get_node_or_null(path) as Control
		if node:
			node.visible = scene_on
	if page == "music" and timeline:
		(_pages["music"] as MusicStudio).show_playhead(timeline.current_time)
	for key in _pages:
		var p: Control = _pages[key]
		p.visible = key == page
		if p.has_method("set_active"):
			p.call("set_active", key == page)
	for name in ["GridSnapToggle", "GridStepSpin", "AddCameraButton", "Sep4", "PlayCinematicButton"]:
		var n := _save_button.get_parent().get_node_or_null(name) as Control
		if n:
			n.visible = scene_on
	if _page_buttons.has(page):
		(_page_buttons[page] as Button).button_pressed = true
	if timeline and timeline.has_method("pause") and not scene_on:
		timeline.call("pause")


## Opens the Characters page with [param path] (a .character file) loaded.
func edit_character(path: String) -> void:
	show_page("characters")
	_character_studio.open_character(path)


func _place_from_studio(prop: Dictionary) -> void:
	_refresh_assets()
	show_page("scene")
	placement.begin_placement(prop)


func _refresh_assets() -> void:
	var panel := get_node_or_null("Layout/Workspace/AssetLibraryPanel")
	if panel and panel.has_method("refresh"):
		panel.call("refresh")


func _find_audio_track() -> AudioTrack:
	return get_node_or_null("../AudioTrack") as AudioTrack


func open_script() -> void:
	_cancel_modes()
	_script_dialog.open()


func _add_tutorial() -> void:
	var help := Button.new()
	help.text = "Help"
	help.tooltip_text = "Take the guided tour again"
	var bar := _save_button.get_parent()
	bar.add_child(help)
	_tutorial = TutorialOverlay.new()
	add_child(_tutorial)
	_tutorial.steps = [
		["Welcome to Scene Builder!", "Build 3D worlds, put characters in them, and film them like a movie, all without coding. This short tour shows where everything is. (You can reopen it any time with Help.)", null],
		["Start a world", "New gives you a Blank World or a ready-made template: classroom, hospital, living room, city, nature, comedy club, news studio and more. Templates come with people, lights and a camera move already set up.", _new_menu],
		["Films from a script", "Script builds a whole film from a written script: locations, actors, movement, dialogue with lip sync, camera shots, music and titles. Press Copy AI Instructions, ask Claude or ChatGPT for a script of your story, paste it back and press Build Film. Try the Example first.", _script_button],
		["Assets", "Everything you can put in your world: buildings, rooms, furniture, people, nature, water, effects, lights. Drag one into the view (or click it, then click in the view). Online downloads free models; Avatars opens the Avatar Studio for realistic people.", get_node_or_null("Layout/Workspace/AssetLibraryPanel")],
		["The 3D view", "Right-drag to look around, middle-drag to pan, wheel to zoom, W A S D to fly. Click an object to select it, drag it to move it. Tab switches to Camera View: exactly what your film will show.", get_node_or_null("Layout/Workspace/ViewportArea")],
		["The Inspector", "Object: change the selected thing (size, colour, actions, lip sync…). Scene: time of day, sky, weather, ground. World: sculpt hills, paint ground and plants, draw walking paths. Film: titles, subtitles, music and sound.", get_node_or_null("Layout/Workspace/InspectorPanel")],
		["Cameras", "Frame a shot in the view, then Add Camera. Select a camera to set its lens, blur, handheld shake and ready-made moves (dolly, orbit, crane…).", _add_camera_button],
		["The timeline", "Move the playhead, change something, press Add Keyframe (or turn on Auto-Key): the timeline animates between keyframes. Cut to Camera switches shots. Space plays.", get_node_or_null("Layout/TimelinePanel")],
		["Watch your film", "Play Cinematic plays the whole film through your cameras, just like the final video.", _play_cinematic_button],
		["Make the video", "Export Video renders an MP4 (with your music and titles), an AVI or images, at up to 4K. You can also send the scene to Blender for a Cycles render.", _export_button],
		["Save often", "Save keeps everything: objects, terrain, plants, weather, cameras, animation, titles and sound. Ctrl+Z undoes almost anything. Tip: open New → My First Film: The Lantern to see a finished short film made with these tools.", _save_button],
	]
	help.pressed.connect(_tutorial.start)
	if TutorialOverlay.should_show():
		_tutorial.start.call_deferred()


func _on_template_chosen(id: int) -> void:
	var template_name := str(TemplateBuilder.TEMPLATES.keys()[id])
	_guard_unsaved("Start from a template", templates.build.bind(template_name))


func _guard_unsaved(title: String, then: Callable) -> void:
	if document.is_dirty():
		_ask(title, "You have unsaved changes in %s. Continue and discard them?" % document.display_name(),
			"Discard changes", then)
	else:
		then.call()


func _cancel_modes() -> void:
	if placement.is_placing():
		placement.cancel_placement()
	if tools:
		tools.cancel()
	if timeline.is_playing():
		timeline.pause()


func open_export() -> void:
	_cancel_modes()
	_export_dialog.open()


func _on_add_camera() -> void:
	_cancel_modes()
	if director.view_mode == CinematicDirector.ViewMode.CAMERA:
		director.set_view_mode(CinematicDirector.ViewMode.EDITOR)
	selection.select(director.create_camera_from_view())


func _on_play_cinematic() -> void:
	if timeline.is_playing():
		timeline.pause()
	else:
		if placement.is_placing():
			placement.cancel_placement()
		timeline.play_cinematic()


func _on_playing_changed(playing: bool) -> void:
	_play_cinematic_button.text = "Pause" if playing else "Play Cinematic"


# --- Dialogs ----------------------------------------------------------------------

func _create_dialogs() -> void:
	var default_dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	_save_dialog = _make_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Save Scene", default_dir)
	_save_dialog.file_selected.connect(func(path: String) -> void: document.save_to(path))
	_open_dialog = _make_file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "Open Scene", default_dir)
	_open_dialog.file_selected.connect(func(path: String) -> void: document.open_from(path))

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.dialog_autowrap = true
	_confirm_dialog.min_size = Vector2i(420, 140)
	_confirm_dialog.confirmed.connect(_on_confirmed)
	_confirm_dialog.canceled.connect(func() -> void: _pending_confirm = Callable())
	add_child(_confirm_dialog)

	_export_dialog = ExportDialog.new()
	add_child(_export_dialog)
	_export_dialog.setup(exporter, timeline)


func _make_file_dialog(mode: FileDialog.FileMode, title: String, dir: String) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.title = title
	dialog.filters = PackedStringArray(["*.%s ; Scene Builder scenes" % SceneSerializer.FILE_EXTENSION])
	dialog.min_size = Vector2i(720, 460)
	if not dir.is_empty():
		dialog.current_dir = dir
	if "use_native_dialog" in dialog:
		dialog.set("use_native_dialog", true)  # OS file picker where available (Godot 4.3+)
	add_child(dialog)
	return dialog


func _ask(title: String, text: String, ok_text: String, on_confirm: Callable) -> void:
	_pending_confirm = on_confirm
	_confirm_dialog.title = title
	_confirm_dialog.dialog_text = text
	_confirm_dialog.ok_button_text = ok_text
	_confirm_dialog.popup_centered()


func _on_confirmed() -> void:
	var action := _pending_confirm
	_pending_confirm = Callable()
	if action.is_valid():
		action.call()


# --- Toolbar state ------------------------------------------------------------------

func _push_grid() -> void:
	placement.set_grid_snap(_grid_toggle.button_pressed, _grid_step.value)
	_grid_step.editable = _grid_toggle.button_pressed
	if ground_mesh and ground_mesh.material_override is ShaderMaterial:
		(ground_mesh.material_override as ShaderMaterial).set_shader_parameter("cell_size", _grid_step.value)


func _on_camera_speed_changed(value: float) -> void:
	if editor_camera:
		editor_camera.speed = value
	_camera_speed_label.text = "%.2f×" % value


func _on_smooth_toggled(on: bool) -> void:
	if editor_camera:
		editor_camera.smooth_enabled = on


func _on_history_changed() -> void:
	_undo_button.disabled = not history.can_undo()
	_redo_button.disabled = not history.can_redo()
	_undo_button.tooltip_text = "Undo %s (Ctrl+Z)" % history.undo_label() if history.can_undo() else "Nothing to undo"
	_redo_button.tooltip_text = "Redo %s (Ctrl+Y)" % history.redo_label() if history.can_redo() else "Nothing to redo"
	var props := placement.get_placed_count()
	var cams := director.cameras().size()
	_prop_count.text = "%d object%s · %d camera%s" % [props, "" if props == 1 else "s", cams, "" if cams == 1 else "s"]
	_clear_button.disabled = props + cams == 0
	_update_title()


func _update_title() -> void:
	var dirty := document.is_dirty()
	_file_label.text = "%s%s" % [document.display_name(), "  •  unsaved" if dirty else ""]
	get_window().title = "%s%s — %s %s" % [document.display_name(), "*" if dirty else "", APP_NAME, ScriptDirector.app_version()]


func _update_hint() -> void:
	if director.view_mode == CinematicDirector.ViewMode.CAMERA:
		var cam := director.current_camera()
		_hint.text = CAMERA_VIEW_HINT % (cam.name if cam else "no camera")
	elif placement.is_placing():
		_hint.text = PLACING_HINT % placement.active_prop().get("display_name", "object")
	elif selection.has_selection():
		_hint.text = SELECTED_HINT % selection.selected.name
	else:
		_hint.text = IDLE_HINT


func _show_status(text: String, is_error: bool) -> void:
	_status_serial += 1
	var serial := _status_serial
	_status.text = text
	if is_error:
		_status.add_theme_color_override("font_color", ERROR_COLOR)
	else:
		_status.remove_theme_color_override("font_color")
	await get_tree().create_timer(STATUS_SECONDS if not is_error else STATUS_SECONDS * 2.0).timeout
	if serial == _status_serial:
		_status.text = ""

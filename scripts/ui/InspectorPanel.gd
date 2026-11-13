extends PanelContainer
## Right-hand Inspector with two tabs:
##  • Object – name, transform, and (for cameras) lens & depth of field, plus
##             keyframe and object actions for the selection.
##  • Scene  – lighting, time of day, sky, fog and ground ([EnvironmentPanel]).
## Every edit goes through EditorHistory, so it can be undone and auto-keyed.

@export var selection: SelectionManager
@export var history: EditorHistory
@export var timeline: TimelineController
@export var director: CinematicDirector
@export var environment: EnvironmentController
@export var grid_overlay: GeometryInstance3D
@export var online: OnlineLibrary
@export var tools: WorldTools
@export var titles: TitleTrack
@export var audio: AudioTrack
@export var pose_tool: PoseTool

var _node: Node3D
var _updating := false

var _tabs: TabContainer
var _empty_view: VBoxContainer
var _object_view: VBoxContainer
var _name_edit: LineEdit
var _asset_label: Label
var _position: Vector3Field
var _rotation: Vector3Field
var _scale: Vector3Field
var _uniform_scale: CheckBox
var _lens_box: VBoxContainer
var _fov: SliderRow
var _dof: CheckBox
var _focus: SliderRow
var _blur: SliderRow
var _keys_label: Label
var _prop_only: Array[Control] = []
var _character_box: VBoxContainer
var _action_option: OptionButton
var _action_info: Label
var _face_check: CheckBox
var _sketch_box: VBoxContainer
var _figure_option: OptionButton
var _expression_option: OptionButton
var _sketch_height_row: SliderRow
var _sketch_colors := {}
var _appearance_box: VBoxContainer
var _body_option: OptionButton
var _hair_option: OptionButton
var _bottom_option: OptionButton
var _height_row: SliderRow
var _build_row: SliderRow
var _color_buttons: Dictionary = {}   # property -> ColorPickerButton
var _actions_for: Object = null
var _picker: PolyHavenPicker
var _surface_box: VBoxContainer
var _surface_label: Label
var _surface_tile: SliderRow
var _settings: PropSettingsSection
var _lip_clip: OptionButton
var _pose_joint: OptionButton
var _pose_rows: Array[SliderRow] = []
var _lip_info: Label
var _lip_record: Button
var _lip_play: Button
var _lip_meter: ProgressBar
var _lip_paths: PackedStringArray = []   # clip path per item of _lip_clip
var _pose_toggle: Button
var _shake: SliderRow
var _move_option: OptionButton
var _move_seconds: SliderRow
var _move_amount: SliderRow

@onready var _root: VBoxContainer = %InspectorRoot


func _ready() -> void:
	_build()
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.history_changed.connect(_refresh)
	EventBus.transform_edited.connect(_on_transform_edited)
	timeline.time_changed.connect(_on_time_changed)
	timeline.keys_changed.connect(_refresh_keys)
	_on_selection_changed(null)


# --- Layout --------------------------------------------------------------------

func _build() -> void:
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(_tabs)

	var object_page := _scroll_page("Object")
	var scene_page := _scroll_page("Scene")

	_empty_view = VBoxContainer.new()
	_empty_view.add_theme_constant_override("separation", 8)
	object_page.add_child(_empty_view)
	_empty_view.add_child(_label("Nothing selected", &"PanelTitle"))
	_empty_view.add_child(_label("Click an object or camera in the viewport to edit it. Lighting and sky are on the Scene tab.", &"DimLabel", true))
	_empty_view.add_child(_section("Making a film"))
	_empty_view.add_child(_label(
		"1. Build the set: drag assets into the view.\n"
		+ "2. Frame a shot, then press Add Camera.\n"
		+ "3. Move the playhead, move things, press Add Keyframe (or turn on Auto-Key).\n"
		+ "4. Use Cut to Camera for multiple angles.\n"
		+ "5. Play Cinematic, then Export Video.", &"DimLabel", true))
	_empty_view.add_child(_section("Shortcuts"))
	_empty_view.add_child(_label(
		"Space play/pause · Home go to start\n, / . step one frame\nI add keyframe · Tab editor/camera view\n"
		+ "R rotate while placing · Esc cancel/deselect\nDelete · Ctrl+D duplicate · F frame\n"
		+ "Ctrl+Z / Ctrl+Y undo/redo · Ctrl+S save\n"
		+ "Right-drag orbit · Middle-drag pan · Wheel zoom\nW A S D / Q E fly · Shift faster", &"DimLabel", true))

	_object_view = VBoxContainer.new()
	_object_view.add_theme_constant_override("separation", 8)
	object_page.add_child(_object_view)

	_object_view.add_child(_section("Object"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Name"
	_name_edit.tooltip_text = "Name (press Enter to apply)"
	_name_edit.text_submitted.connect(func(_t: String) -> void: _commit_name())
	_name_edit.focus_exited.connect(_commit_name)
	_object_view.add_child(_name_edit)
	_asset_label = _label("", &"DimLabel", true)
	_object_view.add_child(_asset_label)

	_object_view.add_child(_section("Transform"))
	_position = Vector3Field.new()
	_position.setup("Position", 0.001, 0.1, " m")
	_position.component_changed.connect(_on_component_changed.bind("position"))
	_object_view.add_child(_position)
	_rotation = Vector3Field.new()
	_rotation.setup("Rotation", 0.1, 5.0, "°")
	_rotation.component_changed.connect(_on_component_changed.bind("rotation_degrees"))
	_object_view.add_child(_rotation)
	_scale = Vector3Field.new()
	_scale.setup("Scale", 0.001, 0.1, "", 0.001)
	_scale.component_changed.connect(_on_component_changed.bind("scale"))
	_object_view.add_child(_scale)
	_uniform_scale = CheckBox.new()
	_uniform_scale.text = "Uniform scale"
	_uniform_scale.tooltip_text = "Scale all three axes together"
	_uniform_scale.button_pressed = true
	_uniform_scale.focus_mode = Control.FOCUS_NONE
	_object_view.add_child(_uniform_scale)
	_prop_only.append_array([_scale, _uniform_scale])

	_build_lens_section()
	_settings = PropSettingsSection.new()
	_settings.setup(history)
	_object_view.add_child(_settings)
	_build_character_section()
	_build_surface_section()

	_object_view.add_child(_section("Animation"))
	var key_button := Button.new()
	key_button.text = "Add Keyframe at Playhead"
	key_button.tooltip_text = "Record this object's current position, rotation, scale (and lens) at the playhead (I)"
	key_button.focus_mode = Control.FOCUS_NONE
	key_button.pressed.connect(func() -> void: timeline.add_keyframe(_node))
	_object_view.add_child(key_button)
	_keys_label = _label("", &"DimLabel", true)
	_object_view.add_child(_keys_label)

	_object_view.add_child(_section("Actions"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_object_view.add_child(grid)
	_add_action(grid, "Reset Rotation", "Set rotation to 0, 0, 0", selection.reset_rotation_selected)
	_prop_only.append(_add_action(grid, "Reset Scale", "Set scale to 1, 1, 1", selection.reset_scale_selected))
	_prop_only.append(_add_action(grid, "Drop to Ground", "Rest the object on the surface below it (End)", selection.drop_selected_to_ground))
	_add_action(grid, "Frame", "Point the editor view at it (F)", selection.focus_selected)
	_add_action(grid, "Duplicate", "Copy it (Ctrl+D)", selection.duplicate_selected)
	_add_action(grid, "Delete", "Remove it (Delete)", selection.delete_selected)

	if online:
		_picker = PolyHavenPicker.new()
		add_child(_picker)
		_picker.setup(online)
		_picker.chosen.connect(_on_surface_picked)
		_picker.visibility_changed.connect(_on_picker_visibility)
	var env_panel := EnvironmentPanel.new()
	env_panel.setup(environment, history, timeline, grid_overlay, _picker)
	scene_page.add_child(env_panel)
	if tools:
		var world_page := _scroll_page("World")
		var world_panel := WorldToolsPanel.new()
		world_panel.setup(tools, history)
		world_page.add_child(world_panel)
	if titles and audio:
		var film_page := _scroll_page("Film")
		var film_panel := FilmPanel.new()
		film_panel.setup(titles, audio, timeline, history)
		film_page.add_child(film_panel)


func _build_lens_section() -> void:
	_lens_box = VBoxContainer.new()
	_lens_box.add_theme_constant_override("separation", 8)
	_object_view.add_child(_lens_box)
	_lens_box.add_child(_section("Camera lens"))
	_fov = SliderRow.new()
	_fov.setup("Field of view", 10.0, 120.0, 0.5, _format_fov, "Wide angle (high) ↔ telephoto (low)")
	_fov.value_edited.connect(_on_lens_edited.bind("fov"))
	_lens_box.add_child(_fov)
	_dof = CheckBox.new()
	_dof.text = "Depth of field (background/foreground blur)"
	_dof.focus_mode = Control.FOCUS_NONE
	_dof.toggled.connect(func(on: bool) -> void: _on_lens_edited(on, "dof_enabled"))
	_lens_box.add_child(_dof)
	_focus = SliderRow.new()
	_focus.setup("Focus distance", 0.2, 100.0, 0.05, func(v: float) -> String: return "%.2f m" % v,
		"Objects at this distance stay sharp")
	_focus.value_edited.connect(_on_lens_edited.bind("focus_distance"))
	_lens_box.add_child(_focus)
	_blur = SliderRow.new()
	_blur.setup("Blur strength", 0.0, 1.0, 0.01, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_blur.value_edited.connect(_on_lens_edited.bind("aperture"))
	_lens_box.add_child(_blur)
	_shake = SliderRow.new()
	_shake.setup("Handheld shake", 0.0, 1.0, 0.01, func(v: float) -> String: return "off" if v <= 0.0 else "%d%%" % roundi(v * 100.0),
		"Gentle hand-held camera wobble (can be keyed with the lens)")
	_shake.value_edited.connect(_on_lens_edited.bind("shake"))
	_lens_box.add_child(_shake)

	_lens_box.add_child(_section("Camera move"))
	_move_option = OptionButton.new()
	_move_option.focus_mode = Control.FOCUS_NONE
	for move in TimelineController.CAMERA_MOVES:
		_move_option.add_item(move)
	_lens_box.add_child(_move_option)
	_move_seconds = SliderRow.new()
	_move_seconds.setup("Duration", 0.5, 20.0, 0.1, func(v: float) -> String: return "%.1f s" % v)
	_move_seconds.set_value(4.0)
	_lens_box.add_child(_move_seconds)
	_move_amount = SliderRow.new()
	_move_amount.setup("Amount", 0.5, 10.0, 0.1, func(v: float) -> String: return "%.1f" % v,
		"Metres for dollies/cranes; ×10° for pans, ×5° for tilts, ×20° for orbits")
	_move_amount.set_value(3.0)
	_lens_box.add_child(_move_amount)
	var move_button := Button.new()
	move_button.text = "Add Move at Playhead"
	move_button.focus_mode = Control.FOCUS_NONE
	move_button.tooltip_text = "Keys a smooth camera move starting at the playhead"
	move_button.pressed.connect(_on_add_camera_move)
	_lens_box.add_child(move_button)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_lens_box.add_child(grid)
	_add_action(grid, "Look Through", "Preview the film through this camera (Tab toggles)",
		func() -> void: director.look_through(_node as CinematicCamera))
	_add_action(grid, "Align to View", "Move this camera to where the editor view is looking from",
		func() -> void: director.align_camera_to_view(_node as CinematicCamera))
	_add_action(grid, "Cut to Camera", "From the playhead on, the film shows this camera",
		func() -> void: timeline.add_cut(_node as CinematicCamera))
	_add_action(grid, "Focus on Target", "Set focus distance to the editor view's orbit point",
		_focus_on_orbit_target)


func _build_character_section() -> void:
	_character_box = VBoxContainer.new()
	_character_box.add_theme_constant_override("separation", 8)
	_object_view.add_child(_character_box)
	_character_box.add_child(_section("Character action"))
	_action_option = OptionButton.new()
	_action_option.focus_mode = Control.FOCUS_NONE
	_action_option.item_selected.connect(func(_i: int) -> void: _update_action_tooltip())
	_character_box.add_child(_action_option)
	var set_action := Button.new()
	set_action.text = "Start This Action at Playhead"
	set_action.focus_mode = Control.FOCUS_NONE
	set_action.tooltip_text = "From the playhead on, the character does this action (blends smoothly from the previous one)"
	set_action.pressed.connect(_on_set_action)
	_character_box.add_child(set_action)
	_action_info = _label("", &"DimLabel", true)
	_character_box.add_child(_action_info)
	_face_check = CheckBox.new()
	_face_check.text = "Turn to face walking direction"
	_face_check.focus_mode = Control.FOCUS_NONE
	_face_check.toggled.connect(func(on: bool) -> void: _set_character_property("face_movement", on, "Character"))
	_character_box.add_child(_face_check)

	_character_box.add_child(_section("Lip sync"))
	_character_box.add_child(_label("Make the mouth follow a voice: record a line here (it starts at the playhead), or pick a clip from the Film tab and press Sync. A character can lip-sync to several clips.", &"DimLabel", true))
	_lip_record = Button.new()
	_lip_record.text = "● Record Line for This Character"
	_lip_record.focus_mode = Control.FOCUS_NONE
	_lip_record.tooltip_text = "Record from your microphone at the playhead; press again to stop. The mouth is synced to it automatically."
	_lip_record.pressed.connect(_on_lip_record)
	_character_box.add_child(_lip_record)
	_lip_meter = ProgressBar.new()
	_lip_meter.max_value = 1.0
	_lip_meter.show_percentage = false
	_lip_meter.custom_minimum_size = Vector2(0, 10)
	_lip_meter.tooltip_text = "Microphone level: it should jump when you speak"
	_lip_meter.visible = false
	_character_box.add_child(_lip_meter)
	var clip_row := HBoxContainer.new()
	_lip_clip = OptionButton.new()
	_lip_clip.focus_mode = Control.FOCUS_NONE
	_lip_clip.tooltip_text = "Sound clips from the Film tab"
	_lip_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lip_clip.clip_text = true
	clip_row.add_child(_lip_clip)
	_lip_play = Button.new()
	_lip_play.text = "▶"
	_lip_play.focus_mode = Control.FOCUS_NONE
	_lip_play.custom_minimum_size = Vector2(32, 0)
	_lip_play.tooltip_text = "Listen to this clip"
	_lip_play.pressed.connect(_on_lip_play)
	clip_row.add_child(_lip_play)
	_character_box.add_child(clip_row)
	var lip_grid := GridContainer.new()
	lip_grid.columns = 2
	lip_grid.add_theme_constant_override("h_separation", 6)
	lip_grid.add_theme_constant_override("v_separation", 6)
	_character_box.add_child(lip_grid)
	_add_action(lip_grid, "Sync Mouth to Clip", "The mouth opens and closes with the voice in this clip (at the clip's start time); earlier syncs are kept", _on_lip_sync)
	_add_action(lip_grid, "Watch Line", "Play the film from just before this clip to see the lip sync", _on_lip_watch)
	_add_action(lip_grid, "Remove Lip Sync", "The mouth no longer follows any clip (the Talk action still moves it)",
		func() -> void: _set_character_property("lipsync", {}, "Lip sync"))
	_lip_info = _label("", &"DimLabel", true)
	_character_box.add_child(_lip_info)
	if audio:
		audio.recording_changed.connect(_on_lip_recording_changed)
		audio.recorded.connect(_on_lip_recorded)
		audio.preview_changed.connect(func(index: int) -> void: _lip_play.text = "■" if index >= 0 and index == _selected_clip() else "▶")

	_character_box.add_child(_section("Pose by hand"))
	_pose_toggle = Button.new()
	_pose_toggle.text = "✋ Pose in the 3D View  (P)"
	_pose_toggle.toggle_mode = true
	_pose_toggle.focus_mode = Control.FOCUS_NONE
	_pose_toggle.tooltip_text = "Show dots on the joints: drag a dot to point that limb at the mouse, Shift-drag to twist it. Each drag sets a pose key at the playhead."
	_pose_toggle.toggled.connect(_on_pose_toggled)
	_character_box.add_child(_pose_toggle)
	if pose_tool:
		pose_tool.active_changed.connect(func(on: bool) -> void: _pose_toggle.set_pressed_no_signal(on))
		pose_tool.joint_picked.connect(_on_pose_joint_picked)
		pose_tool.pose_changed.connect(_refresh_pose)
	_character_box.add_child(_label("Drag the dots in the 3D view, or pick a joint here and use the sliders. Each change sets a pose key at the playhead (diamond on the timeline); set poses at different times and the character moves between them. Poses add on top of any action, or use the \"Pose only\" action for full control.", &"DimLabel", true))
	_pose_joint = OptionButton.new()
	_pose_joint.focus_mode = Control.FOCUS_NONE
	for joint in CharacterBase.POSE_JOINTS:
		_pose_joint.add_item(joint)
	_pose_joint.item_selected.connect(_on_pose_joint_selected)
	_character_box.add_child(_pose_joint)
	if pose_tool:
		_pose_joint.select(maxi(Array(CharacterBase.POSE_JOINTS).find(pose_tool.joint), 0))
	for axis in 3:
		var row := SliderRow.new()
		row.setup(["Bend (forward/back)", "Turn (left/right)", "Tilt (side to side)"][axis], -180.0, 180.0, 1.0,
			func(v: float) -> String: return "%d°" % roundi(v))
		row.value_edited.connect(_on_pose_edited.bind(axis))
		_character_box.add_child(row)
		_pose_rows.append(row)
	var pose_buttons := GridContainer.new()
	pose_buttons.columns = 2
	_character_box.add_child(pose_buttons)
	_add_action(pose_buttons, "Reset Joint", "Back to 0° for this joint at the playhead", func() -> void: _set_joint(Vector3.ZERO))
	_add_action(pose_buttons, "Clear All Poses", "Remove every hand pose key of this character", func() -> void: timeline.clear_pose(_node as CharacterBase))

	_appearance_box = VBoxContainer.new()
	_appearance_box.add_theme_constant_override("separation", 8)
	_character_box.add_child(_appearance_box)
	_appearance_box.add_child(_section("Appearance"))
	_body_option = _option_row(_appearance_box, "Body", HumanCharacter.BODY_TYPES, _on_body_selected)
	_height_row = SliderRow.new()
	_height_row.setup("Height", 0.8, 2.2, 0.01, func(v: float) -> String: return "%.2f m" % v)
	_height_row.value_edited.connect(func(v: float) -> void: _set_character_property("height", v, "Appearance"))
	_appearance_box.add_child(_height_row)
	_build_row = SliderRow.new()
	_build_row.setup("Build", 0.7, 1.3, 0.01, func(v: float) -> String: return "slim" if v < 0.85 else ("broad" if v > 1.15 else "average"))
	_build_row.value_edited.connect(func(v: float) -> void: _set_character_property("build", v, "Appearance"))
	_appearance_box.add_child(_build_row)
	_hair_option = _option_row(_appearance_box, "Hair", HumanCharacter.HAIR_STYLES,
		func(i: int) -> void: _set_character_property("hair_style", HumanCharacter.HAIR_STYLES[i], "Appearance"))
	_bottom_option = _option_row(_appearance_box, "Legwear", HumanCharacter.BOTTOM_STYLES,
		func(i: int) -> void: _set_character_property("bottom_style", HumanCharacter.BOTTOM_STYLES[i], "Appearance"))
	var colors := GridContainer.new()
	colors.columns = 2
	colors.add_theme_constant_override("h_separation", 8)
	colors.add_theme_constant_override("v_separation", 6)
	_appearance_box.add_child(colors)
	for pair in [["skin_color", "Skin"], ["hair_color", "Hair"], ["top_color", "Top"], ["bottom_color", "Legwear"], ["shoe_color", "Shoes"]]:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := _label(pair[1], &"DimLabel")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := ColorPickerButton.new()
		button.custom_minimum_size = Vector2(44, 24)
		button.edit_alpha = false
		button.focus_mode = Control.FOCUS_NONE
		button.color_changed.connect(_on_character_color.bind(pair[0]))
		row.add_child(button)
		colors.add_child(row)
		_color_buttons[pair[0]] = button

	# Flat sketch characters: figure, face, colours and height.
	_sketch_box = VBoxContainer.new()
	_sketch_box.add_theme_constant_override("separation", 8)
	_character_box.add_child(_sketch_box)
	_sketch_box.add_child(_section("Sketch figure"))
	_figure_option = _option_row(_sketch_box, "Figure", SketchCharacter.FIGURES,
		func(i: int) -> void: _set_character_property("figure", SketchCharacter.FIGURES[i], "Figure"))
	_expression_option = _option_row(_sketch_box, "Face", SketchCharacter.EXPRESSIONS,
		func(i: int) -> void: _set_character_property("expression", SketchCharacter.EXPRESSIONS[i], "Face"))
	_expression_option.tooltip_text = "The resting expression. In a script: \"Mina looks sad\", \"Mina smiles\"…"
	_sketch_height_row = SliderRow.new()
	_sketch_height_row.setup("Height", 0.8, 2.2, 0.01, func(v: float) -> String: return "%.2f m" % v)
	_sketch_height_row.value_edited.connect(func(v: float) -> void: _set_character_property("height", v, "Appearance"))
	_sketch_box.add_child(_sketch_height_row)
	var sketch_colors := GridContainer.new()
	sketch_colors.columns = 2
	sketch_colors.add_theme_constant_override("h_separation", 8)
	_sketch_box.add_child(sketch_colors)
	for pair in [["body_color", "Body"], ["line_color", "Face lines"], ["glow_color", "Glow"]]:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := _label(pair[1], &"DimLabel")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := ColorPickerButton.new()
		button.custom_minimum_size = Vector2(44, 24)
		button.edit_alpha = false
		button.focus_mode = Control.FOCUS_NONE
		button.color_changed.connect(_on_character_color.bind(pair[0]))
		row.add_child(button)
		sketch_colors.add_child(row)
		_sketch_colors[pair[0]] = button


func _build_surface_section() -> void:
	_surface_box = VBoxContainer.new()
	_surface_box.add_theme_constant_override("separation", 8)
	_object_view.add_child(_surface_box)
	_surface_box.add_child(_section("Surface material"))
	var row := HBoxContainer.new()
	var choose := Button.new()
	choose.text = "Apply Texture…"
	choose.focus_mode = Control.FOCUS_NONE
	choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choose.tooltip_text = "Cover this object with a real photo-scanned material (wood, stone, metal, fabric…)"
	choose.pressed.connect(_on_choose_surface)
	row.add_child(choose)
	var reset := Button.new()
	reset.text = "Original"
	reset.focus_mode = Control.FOCUS_NONE
	reset.tooltip_text = "Restore the object's own materials"
	reset.pressed.connect(func() -> void: _set_surface({}))
	row.add_child(reset)
	_surface_box.add_child(row)
	_surface_label = _label("", &"DimLabel", true)
	_surface_box.add_child(_surface_label)
	_surface_tile = SliderRow.new()
	_surface_tile.setup("Texture size", 0.1, 10.0, 0.05, func(v: float) -> String: return "%.2f m" % v)
	_surface_tile.value_edited.connect(_on_surface_tile)
	_surface_box.add_child(_surface_tile)


var _surface_picking := false


func _on_choose_surface() -> void:
	if _picker:
		_surface_picking = true
		_picker.open_for("textures")


func _on_picker_visibility() -> void:
	if _picker and not _picker.visible:
		_surface_picking = false


func _on_surface_picked(path: String, id: String, title: String) -> void:
	if not _surface_picking:
		return
	_surface_picking = false
	var tile := float(PropUtils.surface_of(_node).get("tile", 1.0))
	_set_surface({"texture": path, "id": id, "title": title, "tile": tile})


func _on_surface_tile(value: float) -> void:
	if _updating or not is_instance_valid(_node):
		return
	var surface := PropUtils.surface_of(_node).duplicate()
	if surface.is_empty():
		return
	surface["tile"] = value
	_set_surface(surface, true)


## Undoable change of the selected prop's surface texture.
func _set_surface(surface: Dictionary, merge: bool = false) -> void:
	if not is_instance_valid(_node) or not PropUtils.is_prop(_node):
		return
	var before := {"node": _node, "surface": PropUtils.surface_of(_node)}
	var after := {"node": _node, "surface": surface}
	history.record_snapshot("Surface %s" % _node.name, _apply_surface_state, before, after, merge)
	_refresh()


func _apply_surface_state(state: Dictionary) -> void:
	var node: Node3D = state.get("node")
	if is_instance_valid(node):
		PropUtils.apply_surface(node, state.get("surface", {}))


func _option_row(parent: Control, title: String, items: PackedStringArray, on_select: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	var label := _label(title, &"DimLabel")
	label.custom_minimum_size.x = 70
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.focus_mode = Control.FOCUS_NONE
	for item in items:
		option.add_item(item)
	option.item_selected.connect(on_select)
	row.add_child(option)
	parent.add_child(row)
	return option


func _scroll_page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 6)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	return box


static func _label(text: String, variation: StringName, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func _section(title: String) -> Label:
	var label := _label(title, &"SectionHeader")
	label.uppercase = true
	return label


static func _format_fov(v: float) -> String:
	return "%d° · %d mm" % [roundi(v), roundi(12.0 / tan(deg_to_rad(v) * 0.5))]


func _add_action(grid: GridContainer, text: String, tip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	grid.add_child(button)
	return button


# --- State ---------------------------------------------------------------------

func _on_selection_changed(node: Node3D) -> void:
	_node = node
	if node != null:
		_tabs.current_tab = 0
	_refresh()


func _on_transform_edited(node: Node3D) -> void:
	if node == _node:
		_refresh()


func _on_time_changed(_t: float) -> void:
	# Animated objects move while scrubbing/playing; keep the numbers live.
	if is_instance_valid(_node) and timeline.store.has_keys(str(_node.get_meta(PropUtils.META_UID, ""))):
		_refresh()
	else:
		_refresh_keys()
		if is_instance_valid(_node) and _node is CharacterBase:
			_updating = true
			_refresh_character()
			_updating = false


func _refresh() -> void:
	var has_node := is_instance_valid(_node) and _node.is_inside_tree()
	_empty_view.visible = not has_node
	_object_view.visible = has_node
	if not has_node:
		return
	var cam := _node as CinematicCamera
	_updating = true
	if not _name_edit.has_focus():
		_name_edit.text = str(_node.name)
	if cam:
		_asset_label.text = "Virtual camera · %s" % ("live shot" if director.current_camera() == cam else "standby")
	else:
		var path := str(_node.get_meta(PropUtils.META_SCENE_PATH, ""))
		_asset_label.text = "%s · %s" % [
			str(_node.get_meta(PropUtils.META_PROP_ID, "")).capitalize(), PropCatalog.category_for_path(path)]
	_position.set_value(_node.position)
	_rotation.set_value(_node.rotation_degrees)
	_scale.set_value(_node.scale)
	for control in _prop_only:
		control.visible = cam == null
	_lens_box.visible = cam != null
	_refresh_character()
	_refresh_surface()
	_settings.show_for(_node)
	if cam:
		_fov.set_value(cam.fov)
		_dof.set_pressed_no_signal(cam.dof_enabled)
		_focus.set_value(cam.focus_distance)
		_blur.set_value(cam.aperture)
		_focus.set_editable(cam.dof_enabled)
		_blur.set_editable(cam.dof_enabled)
		_shake.set_value(cam.shake)
	_updating = false
	_refresh_keys()


func _refresh_surface() -> void:
	var show := is_instance_valid(_node) and PropUtils.is_prop(_node) and not _node is CharacterBase \
		and not _node is ProceduralProp and _picker != null
	_surface_box.visible = show
	if not show:
		return
	var surface := PropUtils.surface_of(_node)
	_surface_label.text = "Using: %s" % surface.get("title", str(surface.get("id", "")).capitalize()) if not surface.is_empty() else "Using the model's own materials."
	_surface_tile.visible = not surface.is_empty()
	_surface_tile.set_value(float(surface.get("tile", 1.0)))


func _refresh_character() -> void:
	var character := _node as CharacterBase
	_character_box.visible = character != null
	if character == null:
		return
	if _actions_for != character:
		_actions_for = character
		_action_option.clear()
		for action in character.action_names():
			_action_option.add_item(action)
	var current := timeline.character_action_at(character, timeline.current_time)
	for i in _action_option.item_count:
		if _action_option.get_item_text(i) == current and not _action_option.has_focus():
			_action_option.select(i)
	_update_action_tooltip()
	_action_info.text = "At %.2f s: %s" % [timeline.current_time, current]
	_face_check.set_pressed_no_signal(character.face_movement)
	_refresh_lip_sync(character)
	_refresh_pose()
	var sketch := character as SketchCharacter
	_sketch_box.visible = sketch != null
	if sketch:
		_figure_option.select(maxi(SketchCharacter.FIGURES.find(sketch.figure), 0))
		_expression_option.select(maxi(SketchCharacter.EXPRESSIONS.find(sketch.expression), 0))
		_sketch_height_row.set_value(sketch.height)
		for property in _sketch_colors:
			(_sketch_colors[property] as ColorPickerButton).color = sketch.get(property)
	var human := character as HumanCharacter if sketch == null else null
	_appearance_box.visible = human != null
	if human:
		_body_option.select(maxi(HumanCharacter.BODY_TYPES.find(human.body_type), 0))
		_hair_option.select(maxi(HumanCharacter.HAIR_STYLES.find(human.hair_style), 0))
		_bottom_option.select(maxi(HumanCharacter.BOTTOM_STYLES.find(human.bottom_style), 0))
		_height_row.set_value(human.height)
		_build_row.set_value(human.build)
		for property in _color_buttons:
			(_color_buttons[property] as ColorPickerButton).color = human.get(property)


func _refresh_pose() -> void:
	var character := _node as CharacterBase
	if character == null or _pose_rows.is_empty():
		return
	var pose := character.with_preview(timeline.pose_at(character, timeline.current_time))
	if pose_tool:
		pose.merge(pose_tool.dragged_angles(), true)
	var value: Vector3 = pose.get(_pose_joint.get_item_text(_pose_joint.selected), Vector3.ZERO)
	for axis in 3:
		_pose_rows[axis].set_value(value[axis])


func _on_pose_edited(v: float, axis: int) -> void:
	var character := _node as CharacterBase
	if _updating or character == null:
		return
	var value := Vector3(_pose_rows[0].get_value(), _pose_rows[1].get_value(), _pose_rows[2].get_value())
	value[axis] = v
	_set_joint(value)


func _set_joint(value: Vector3) -> void:
	var character := _node as CharacterBase
	if character:
		timeline.set_pose_joint(character, _pose_joint.get_item_text(_pose_joint.selected), value)
		_refresh_pose()


func _refresh_lip_sync(character: CharacterBase) -> void:
	if _lip_clip.has_focus():
		return
	var keep := _lip_paths[_lip_clip.selected] if _lip_clip.selected >= 0 and _lip_clip.selected < _lip_paths.size() else ""
	_lip_clip.clear()
	_lip_paths = PackedStringArray()
	if audio:
		for clip in audio.clips:
			_lip_clip.add_item("%s (at %.1f s)" % [clip["name"], float(clip["start"])])
			_lip_paths.append(str(clip["path"]))
	if _lip_clip.item_count == 0:
		_lip_clip.add_item("No clips yet: record a line, or add one in the Film tab")
		_lip_clip.disabled = true
		_lip_play.disabled = true
	else:
		_lip_clip.disabled = false
		_lip_play.disabled = false
		var index := _lip_paths.find(keep) if not keep.is_empty() else -1
		if index < 0:
			index = maxi(audio.clip_near(timeline.current_time), 0)
		_lip_clip.select(index)
	if character.lipsync.is_empty():
		_lip_info.text = "No lip sync yet (the Talk action moves the mouth)."
	else:
		_lip_info.text = "Mouth follows: %s" % character.lipsync.get("clip", "")


## The clip chosen in the Lip sync menu (index into audio.clips), or -1.
func _selected_clip() -> int:
	if audio == null or _lip_clip.disabled or _lip_clip.selected < 0 or _lip_clip.selected >= audio.clips.size():
		return -1
	return _lip_clip.selected


func _on_lip_sync() -> void:
	var character := _node as CharacterBase
	var index := _selected_clip()
	if character == null or index < 0:
		return
	_sync_mouth(character, index)


## Adds clip [param index] to the character's lip sync (undoable).
func _sync_mouth(character: CharacterBase, index: int) -> void:
	var clip: Dictionary = audio.clips[index]
	EventBus.info("Analysing %s…" % clip["name"])
	var env := audio.mouth_envelope(clip)
	if env.is_empty():
		return
	var after := CharacterBase.merge_lipsync(character.lipsync, str(clip["name"]), float(clip["start"]), env)
	history.set_property(character, "lipsync", character.lipsync, after, "Lip sync %s" % character.name)
	EventBus.info("%s now lip-syncs to %s (%.1f s). Tip: press Watch Line to see it; the Talk action adds head and hand gestures." % [character.name, clip["name"], env.size() / 30.0])


func _on_lip_play() -> void:
	var index := _selected_clip()
	if index < 0:
		return
	if audio.previewing() == index:
		audio.stop_preview()
	else:
		audio.preview(index)


func _on_lip_watch() -> void:
	var index := _selected_clip()
	if index < 0:
		return
	audio.stop_preview()
	timeline.set_time(maxf(float(audio.clips[index]["start"]) - 0.5, 0.0))
	timeline.play()


func _on_lip_record() -> void:
	var character := _node as CharacterBase
	if audio == null:
		return
	if audio.is_recording():
		audio.finish_recording(history)
		return
	if character == null:
		return
	audio.record_start = timeline.current_time
	audio.record_for = str(character.name)
	audio.record_target = character
	if audio.start_recording():
		EventBus.info("Recording %s's line… speak now, then press Stop." % character.name)


func _on_lip_recording_changed(active: bool) -> void:
	_lip_record.text = "■ Stop and Sync Mouth" if active else "● Record Line for This Character"
	_lip_meter.visible = active
	set_process(active)


func _process(_delta: float) -> void:
	if audio == null or not audio.is_recording():
		set_process(false)
		return
	_lip_meter.value = lerpf(_lip_meter.value, audio.input_level(), 0.5)


func _on_lip_recorded(index: int) -> void:
	var target := audio.record_target
	audio.record_target = null
	if target is CharacterBase and is_instance_valid(target) and (target as Node).is_inside_tree():
		_sync_mouth(target as CharacterBase, index)


func _on_pose_toggled(on: bool) -> void:
	if pose_tool:
		pose_tool.set_active(on)


func _on_pose_joint_selected(index: int) -> void:
	if pose_tool:
		pose_tool.set_joint(_pose_joint.get_item_text(index))
	_refresh_pose()


func _on_pose_joint_picked(joint: String) -> void:
	var index := Array(CharacterBase.POSE_JOINTS).find(joint)
	if index >= 0:
		_pose_joint.select(index)
	_refresh_pose()


func _update_action_tooltip() -> void:
	var character := _node as CharacterBase
	if character and _action_option.selected >= 0:
		_action_option.tooltip_text = character.action_hint(_action_option.get_item_text(_action_option.selected))


func _on_set_action() -> void:
	var character := _node as CharacterBase
	if character and _action_option.selected >= 0:
		timeline.set_character_action(character, _action_option.get_item_text(_action_option.selected))


func _set_character_property(property: String, value: Variant, label: String) -> void:
	if _updating or not is_instance_valid(_node) or not _node is CharacterBase:
		return
	if _node.get(property) == value:
		return
	history.set_property(_node, property, _node.get(property), value, "%s %s" % [label, _node.name])


func _on_character_color(color: Color, property: String) -> void:
	_set_character_property(property, color, "Appearance")


func _on_body_selected(index: int) -> void:
	var human := _node as HumanCharacter
	if _updating or human == null:
		return
	var body := HumanCharacter.BODY_TYPES[index]
	var to: Dictionary = HumanCharacter.PRESETS.get(body, {}).duplicate()
	to["body_type"] = body
	var from := {}
	for key in to:
		from[key] = human.get(key)
	history.set_properties(human, from, to, "Body type %s" % human.name)


func _refresh_keys() -> void:
	if not is_instance_valid(_node) or _keys_label == null:
		return
	var times := timeline.store.key_times(str(_node.get_meta(PropUtils.META_UID, "")))
	if times.is_empty():
		_keys_label.text = "Not animated yet. Move the playhead, change something, then add a keyframe."
		return
	var at_playhead := false
	for t in times:
		if absf(t - timeline.current_time) < 0.5 / timeline.frame_rate:
			at_playhead = true
	_keys_label.text = "%d keyframe%s%s" % [times.size(), "" if times.size() == 1 else "s",
		" · one is at the playhead" if at_playhead else ""]


func _on_component_changed(axis: int, value: float, property: String) -> void:
	if _updating or not is_instance_valid(_node):
		return
	var current: Vector3 = _node.get(property)
	var next := current
	next[axis] = value
	if property == "scale" and _uniform_scale.button_pressed and absf(current[axis]) > 1e-6:
		next = current * (value / current[axis])
	if next.is_equal_approx(current):
		return
	# Let Node3D compose the new transform, then record it as one undoable step.
	var before := _node.transform
	_node.set(property, next)
	var after := _node.transform
	_node.transform = before
	var labels := {"position": "Move", "rotation_degrees": "Rotate", "scale": "Scale"}
	history.set_transform(_node, before, after, labels[property])


func _on_lens_edited(value: Variant, property: String) -> void:
	var cam := _node as CinematicCamera
	if _updating or cam == null:
		return
	history.set_property(cam, property, cam.get(property), value, "Lens %s" % cam.name, TimelineController.CH_LENS)
	if property == "dof_enabled":
		_focus.set_editable(bool(value))
		_blur.set_editable(bool(value))


func _on_add_camera_move() -> void:
	var cam := _node as CinematicCamera
	if cam:
		timeline.add_camera_move(cam, _move_option.get_item_text(_move_option.selected), _move_seconds.get_value(), _move_amount.get_value())


func _focus_on_orbit_target() -> void:
	var cam := _node as CinematicCamera
	if cam == null or director.editor_camera == null:
		return
	var distance := cam.global_position.distance_to(director.editor_camera.target)
	history.set_property(cam, "focus_distance", cam.focus_distance, distance, "Lens %s" % cam.name, TimelineController.CH_LENS)
	if not cam.dof_enabled:
		EventBus.info("Focus set to %.2f m. Turn on Depth of field to see the blur." % distance)


func _commit_name() -> void:
	if _updating or not is_instance_valid(_node):
		return
	var wanted := _name_edit.text.strip_edges()
	if wanted.is_empty():
		_name_edit.text = str(_node.name)
		return
	history.rename(_node, wanted)
	_name_edit.text = str(_node.name)

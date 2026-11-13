class_name AvatarStudio
extends AcceptDialog
## Avatar Studio: preview and customise your characters.
##  • Preview: a turntable view (drag to turn, wheel to zoom) with lighting.
##  • Body:  shape a realistic human (age, height, weight, ethnicity, hair,
##           clothes…) and build/rebuild it with Blender + MPFB2.
##  • Look:  instant changes: height, colour of every material (skin, hair,
##           each piece of clothing), show/hide parts. Saved with the avatar
##           and applied to every copy in your scenes.
##  • Animation: play any action (incl. imported Mixamo packs) on the preview.

signal built(path: String)

const SCRIPT_SOURCE := "res://tools/blender/build_avatar.py"
## Helper scripts the builder imports (copied next to it before each build).
const HELPER_SOURCES: PackedStringArray = ["res://tools/blender/face_tools.py"]
const POINTS_SOURCE := "res://tools/blender/face_points.py"
## Where "Find Points Automatically" keeps MediaPipe and its face model.
const POINTS_LIBRARY := "user://tools/face_points_lib/"
const LIST_SOURCE := "res://tools/blender/list_assets.py"
const CATALOG_FILE := "user://tools/mpfb_assets.json"
const WORK_DIR := "user://tools/"
const SETTINGS_FILE := "user://settings.cfg"
const NEW_AVATAR := "＋ New avatar"
const HAIR := {"Short": "short02", "Short curly": "short04", "Bob": "bob02", "Long": "long01",
	"Ponytail": "ponytail01", "Braid": "braid01", "Afro": "afro01", "None (bald)": ""}
const OUTFITS := {
	"Casual": [["casualsuit"], ["shoes"]],
	"Business suit": [["suit"], ["shoes"]],
	"Dress": [["dress"], ["shoes"]],
	"Sporty": [["tshirt"], ["shorts"], ["shoes"]],
	"Underwear only": [],
}
const SKINS := {"Auto (from ethnicity)": [], "Light": ["light"], "Medium": ["middleage"], "Dark": ["african"], "Asian": ["asian"]}
const SLIDERS := [
	["gender", "Female ↔ Male", 0.0, 1.0, 0.5], ["age_years", "Age (years)", 1.0, 90.0, 28.0],
	["height", "Height", 0.0, 1.0, 0.5], ["weight", "Weight", 0.0, 1.0, 0.5], ["muscle", "Muscle", 0.0, 1.0, 0.5],
	["proportions", "Proportions (average ↔ idealised)", 0.0, 1.0, 0.5],
	["african", "African", 0.0, 1.0, 0.33], ["asian", "Asian", 0.0, 1.0, 0.33], ["caucasian", "Caucasian", 0.0, 1.0, 0.34],
]
const PREVIEW_MODES := {"Standing": 0.0, "Walking": 1.4, "Running": 3.6}

var _picker: OptionButton
var _paths: PackedStringArray = []
var _current_path := ""

# Preview
var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _character: Node3D
var _motion: CharacterMotion
var _time := 0.0
var _yaw := 0.6
var _pitch := -0.12
var _distance := 3.2
var _target := Vector3(0, 0.95, 0)
var _auto_turn: CheckBox
var _dragging := false

# Body tab
var _name: LineEdit
var _sliders: Dictionary = {}
var _hair: OptionButton
var _outfit: OptionButton
var _skin: OptionButton
var _rig: OptionButton
var _wardrobe: CheckBox
var _catalog: Dictionary = {}
var _clothes_list: ItemList
var _hair_list: ItemList
var _hair_list_label: Label
var _catalog_info: Label
var _scan_button: Button
var _photo: PhotoMarker
var _photo_path := ""
var _photo_hint: Label
var _photo_strength: SliderRow
var _photo_dialog: FileDialog
var _side: PhotoMarker
var _side_path := ""
var _side_hint: Label
var _side_dialog: FileDialog
var _auto_button: Button
var _face_fit: CheckBox
var _talking_face: CheckBox
var _even_light: CheckBox
var _blender: LineEdit
var _log: TextEdit
var _build_button: Button
var _locate: FileDialog
var _thread: Thread

# Look tab
var _look_box: VBoxContainer
var _height_row: SliderRow
var _look: Dictionary = {}
var _fit_row: SliderRow
var _pending_wardrobe: Array = []

# Animation tab
var _actions: ItemList
var _mode: OptionButton
var _speed_row: SliderRow
var _action := MotionLibrary.AUTO
var _rig_info: Label


func _ready() -> void:
	title = "Avatar Studio"
	ok_button_text = "Close"
	min_size = Vector2i(900, 560)
	# Never grow past the screen: content scrolls instead.
	wrap_controls = false
	var root := HSplitContainer.new()
	add_child(root)
	root.add_child(_build_preview_side())
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(420, 0)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	tabs.add_child(_scroll("Body", _build_body_tab()))
	tabs.add_child(_scroll("Look", _build_look_tab()))
	tabs.add_child(_scroll("Animation", _build_animation_tab()))
	about_to_popup.connect(_refresh_list)
	_load_catalog()


## Opens sized to fit the screen.
func open() -> void:
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	popup_centered(Vector2i(mini(1240, screen.x - 40), mini(780, screen.y - 60)))


func _process(delta: float) -> void:
	if not visible or _character == null:
		return
	_time += delta * (_speed_row.get_value() if _speed_row else 1.0)
	if _auto_turn and _auto_turn.button_pressed and not _dragging:
		_yaw += delta * 0.35
	_update_camera()
	if _character is CharacterBase and _motion:
		(_character as CharacterBase).evaluate(_time, _motion)


# --- Preview -------------------------------------------------------------------

func _build_preview_side() -> Control:
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	_picker = OptionButton.new()
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.item_selected.connect(_on_pick)
	row.add_child(_label("Character"))
	row.add_child(_picker)
	var delete := Button.new()
	delete.text = "Delete"
	delete.tooltip_text = "Delete this avatar from your library (scenes that use it will show it missing)."
	delete.pressed.connect(_on_delete_avatar)
	row.add_child(delete)
	side.add_child(row)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(360, 360)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.gui_input.connect(_on_preview_input)
	side.add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(_viewport)
	_stage = Node3D.new()
	_viewport.add_child(_stage)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_stage.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 35, 0)
	key.light_energy = 1.3
	key.shadow_enabled = true
	_stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.75, 0.82, 1.0)
	_stage.add_child(rim)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 1.6
	floor_mesh.bottom_radius = 1.6
	floor_mesh.height = 0.04
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.3, 0.31, 0.34)
	floor_material.roughness = 0.7
	floor_mesh.material = floor_material
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.position.y = -0.02
	_stage.add_child(floor_node)
	_camera = Camera3D.new()
	_camera.fov = 35.0
	_stage.add_child(_camera)
	_update_camera()

	var controls := HBoxContainer.new()
	_auto_turn = CheckBox.new()
	_auto_turn.text = "Turntable"
	_auto_turn.button_pressed = true
	controls.add_child(_auto_turn)
	var reset := Button.new()
	reset.text = "Reset View"
	reset.pressed.connect(_frame_character)
	controls.add_child(reset)
	controls.add_child(_label("Drag to turn · wheel to zoom · right-drag up/down to move the view"))
	side.add_child(controls)
	return side


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_distance = maxf(_distance * 0.9, 0.4)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_distance = minf(_distance * 1.1, 12.0)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_target.y = clampf(_target.y + motion.relative.y * 0.005, 0.1, 2.2)
		else:
			_yaw -= motion.relative.x * 0.01
			_pitch = clampf(_pitch - motion.relative.y * 0.006, -1.2, 0.6)


func _update_camera() -> void:
	if _camera == null:
		return
	var offset := Vector3(sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	_camera.look_at_from_position(_target + offset, _target, Vector3.UP)


func _frame_character() -> void:
	if _character == null:
		return
	var box := PropUtils.compute_local_aabb(_character)
	var height := maxf(box.size.y, 0.3)
	_target = Vector3(0, box.position.y + height * 0.55, 0)
	_distance = height * 1.9
	_pitch = -0.12
	_yaw = 0.6


func _refresh_list() -> void:
	_paths.clear()
	_picker.clear()
	var dir := DirAccess.open(RuntimeModelLoader.CHARACTERS_DIR)
	if dir:
		for file_name in dir.get_files():
			if RuntimeModelLoader.EXTENSIONS.has(file_name.get_extension().to_lower()):
				_paths.append(RuntimeModelLoader.CHARACTERS_DIR + file_name)
	for path in _paths:
		_picker.add_item(path.get_file().get_basename())
	_picker.add_item(NEW_AVATAR)
	var index := _paths.find(_current_path)
	if index < 0:
		index = 0 if not _paths.is_empty() else _paths.size()
	_picker.select(index)
	_on_pick(index)


func _on_pick(index: int) -> void:
	if index >= _paths.size():
		_current_path = ""
		_show_character("")
		_name.text = "Avatar"
		return
	_current_path = _paths[index]
	_name.text = _current_path.get_file().get_basename()
	_load_body_settings(_current_path)
	_show_character(_current_path)


func _show_character(path: String) -> void:
	if _character:
		_character.queue_free()
		_character = null
	_look = {}
	if not path.is_empty():
		_character = PropUtils.instantiate_as_node3d(PropUtils.load_prop_scene(path))
	if _character:
		_stage.add_child(_character)
		if _character is CharacterBase:
			(_character as CharacterBase).face_movement = false
		if _character is ImportedCharacter:
			_look = (_character as ImportedCharacter).current_look()
		_frame_character()
	_rebuild_look_tab()
	_rebuild_actions()


# --- Body tab (Blender + MPFB2) ------------------------------------------------

func _build_body_tab() -> VBoxContainer:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.add_child(_label("Shape a realistic human and build it with Blender + the free MPFB2 (MakeHuman) add-on. Pick an existing avatar on the left to change it and Rebuild.", true))
	_name = LineEdit.new()
	_name.placeholder_text = "Character name"
	root.add_child(_row("Name", _name))
	root.add_child(_heading("Body"))
	for entry in SLIDERS:
		if entry[0] == "african":
			root.add_child(_heading("Ethnicity mix"))
		var row := SliderRow.new()
		var big: bool = entry[3] > 2.0
		row.setup(entry[1], entry[2], entry[3], 1.0 if big else 0.01,
			func(v: float) -> String: return "%d" % roundi(v) if big else "%d%%" % roundi(v * 100.0))
		row.set_value(entry[4])
		root.add_child(row)
		_sliders[entry[0]] = row
	root.add_child(_heading("Look"))
	_skin = _options(root, "Skin", SKINS.keys())
	_hair = _options(root, "Hair", HAIR.keys())
	_outfit = _options(root, "Clothes", OUTFITS.keys())
	_scan_button = Button.new()
	_scan_button.text = "Find Installed Assets (all hair, clothes, skins)"
	_scan_button.tooltip_text = "Lists every hairstyle, clothing item and skin installed in MPFB2 (system assets and any extra packs)"
	_scan_button.pressed.connect(_scan_assets)
	root.add_child(_scan_button)
	_catalog_info = _label("Only a few quick choices are shown. Press Find Installed Assets to list everything you have installed in MPFB2.", true)
	root.add_child(_catalog_info)
	_clothes_list = ItemList.new()
	_clothes_list.select_mode = ItemList.SELECT_MULTI
	_clothes_list.custom_minimum_size = Vector2(0, 260)
	_picture_grid(_clothes_list)
	_clothes_list.visible = false
	_clothes_list.tooltip_text = "Ctrl/Shift-click to pick several. All picked items are built in; show/hide each one in the Look tab."
	root.add_child(_clothes_list)
	_hair_list_label = _label("Extra hairstyles to include (switch them in the Look tab):", true)
	_hair_list_label.visible = false
	root.add_child(_hair_list_label)
	_hair_list = ItemList.new()
	_hair_list.select_mode = ItemList.SELECT_MULTI
	_hair_list.custom_minimum_size = Vector2(0, 200)
	_picture_grid(_hair_list)
	_hair_list.visible = false
	root.add_child(_hair_list)
	_rig = _options(root, "Skeleton", ["Game engine (best for Mixamo)", "Default (detailed)"])
	_wardrobe = CheckBox.new()
	_wardrobe.text = "Include wardrobe (all outfits and hairstyles)"
	_wardrobe.tooltip_text = "Builds every outfit and hairstyle into the avatar so you can switch them instantly in the Look tab (bigger file)"
	_wardrobe.button_pressed = true
	root.add_child(_wardrobe)

	root.add_child(_heading("Face from a photo (optional)"))
	root.add_child(_label("Gives the avatar a real person's face: the head is reshaped to match the photo (eyes, nose, mouth, jaw, chin) and the photo is painted on. 1) Choose a front photo. 2) Press Find Points Automatically, or click the eyes and the mouth. 3) Drag any dot that isn't exactly on its spot.", true))
	var photo_row := HBoxContainer.new()
	var choose_photo := Button.new()
	choose_photo.text = "Choose Photo…"
	choose_photo.pressed.connect(func() -> void: _photo_dialog.popup_centered_ratio(0.6))
	photo_row.add_child(choose_photo)
	_auto_button = Button.new()
	_auto_button.text = "Find Points Automatically"
	_auto_button.tooltip_text = "Finds all 18 face points with Google's MediaPipe (run through Blender). The first time it downloads MediaPipe and its face model, so it needs the internet once."
	_auto_button.pressed.connect(_on_find_points)
	photo_row.add_child(_auto_button)
	root.add_child(photo_row)
	var photo_row2 := HBoxContainer.new()
	for item in [["Mark Again", func() -> void: _photo.start_over()], ["Fit View", func() -> void: _photo.reset_view()], ["No Photo", _clear_photo]]:
		var b := Button.new()
		b.text = item[0]
		b.pressed.connect(item[1])
		photo_row2.add_child(b)
	root.add_child(photo_row2)
	_photo = PhotoMarker.new()
	_photo.changed.connect(func() -> void: _photo_hint.text = _photo.hint())
	root.add_child(_photo)
	_photo_hint = _label("", true)
	root.add_child(_photo_hint)
	_photo_strength = SliderRow.new()
	_photo_strength.setup("Photo strength", 0.2, 1.0, 0.01, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_photo_strength.set_value(0.9)
	root.add_child(_photo_strength)
	_face_fit = CheckBox.new()
	_face_fit.text = "Shape the head to match the photo"
	_face_fit.tooltip_text = "Moves the eyes, nose, mouth, jaw, cheeks and chin of the 3D head to where they are in the photo (needs all the points)."
	_face_fit.button_pressed = true
	root.add_child(_face_fit)
	_even_light = CheckBox.new()
	_even_light.text = "Even out the photo's lighting"
	_even_light.tooltip_text = "Softens shadows and bright spots from the photo, so the face looks right under the film's own lights."
	_even_light.button_pressed = true
	root.add_child(_even_light)

	root.add_child(_heading("Side photo (optional)"))
	root.add_child(_label("A photo of the same person in profile (either side) improves the nose, lips and chin, and paints the sides of the face. Click the 5 points it asks for.", true))
	var side_row := HBoxContainer.new()
	var choose_side := Button.new()
	choose_side.text = "Choose Side Photo…"
	choose_side.pressed.connect(func() -> void: _side_dialog.popup_centered_ratio(0.6))
	side_row.add_child(choose_side)
	for item in [["Mark Again", func() -> void: _side.start_over()], ["No Side Photo", _clear_side]]:
		var b := Button.new()
		b.text = item[0]
		b.pressed.connect(item[1])
		side_row.add_child(b)
	root.add_child(side_row)
	_side = PhotoMarker.new()
	_side.mode = PhotoMarker.Mode.SIDE
	_side.custom_minimum_size = Vector2(300, 260)
	_side.changed.connect(func() -> void: _side_hint.text = _side.hint())
	root.add_child(_side)
	_side_hint = _label("", true)
	root.add_child(_side_hint)

	root.add_child(_heading("Face animation"))
	_talking_face = CheckBox.new()
	_talking_face.text = "Talking face (mouth opens for lip sync, eyes blink)"
	_talking_face.tooltip_text = "Adds jawOpen, eyeBlink and mouthSmile shapes to the face, so lip sync and blinking work in your films."
	_talking_face.button_pressed = true
	root.add_child(_talking_face)
	_photo_dialog = _image_dialog(_on_photo_chosen)
	_side_dialog = _image_dialog(_on_side_chosen)
	_photo_hint.text = _photo.hint()
	_side_hint.text = _side.hint()
	root.add_child(_label("Eyes, eyebrows and eyelashes are added automatically. Hair/clothes come from MPFB's asset pack.", true))
	root.add_child(_heading("Blender"))
	_blender = LineEdit.new()
	_blender.placeholder_text = "Path to blender / blender.exe"
	_blender.text = _load_blender_path()
	var blender_row := _row("Blender", _blender)
	var locate_button := Button.new()
	locate_button.text = "Locate…"
	locate_button.pressed.connect(func() -> void: _locate.popup_centered_ratio(0.6))
	blender_row.add_child(locate_button)
	root.add_child(blender_row)
	_locate = FileDialog.new()
	_locate.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_locate.access = FileDialog.ACCESS_FILESYSTEM
	_locate.title = "Find the Blender program"
	_locate.file_selected.connect(func(path: String) -> void: _blender.text = path)
	add_child(_locate)
	_build_button = Button.new()
	_build_button.text = "Build / Rebuild Character"
	_build_button.pressed.connect(_on_build)
	root.add_child(_build_button)
	_log = TextEdit.new()
	_log.editable = false
	_log.custom_minimum_size = Vector2(0, 140)
	_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	root.add_child(_log)
	return root


func _image_dialog(on_chosen: Callable) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Photos"])
	dialog.file_selected.connect(on_chosen)
	add_child(dialog)
	return dialog


## Keeps a copy with the avatars so the photo is still there next time.
static func _keep_photo(path: String) -> String:
	DirAccess.make_dir_recursive_absolute(RuntimeModelLoader.CHARACTERS_DIR + "photos/")
	var copy := RuntimeModelLoader.CHARACTERS_DIR + "photos/" + path.get_file().validate_filename()
	if ProjectSettings.globalize_path(copy) != path:
		DirAccess.copy_absolute(path, ProjectSettings.globalize_path(copy))
	return copy


func _on_photo_chosen(path: String) -> void:
	var copy := _keep_photo(path)
	if _photo.set_photo(copy):
		_photo_path = copy
	else:
		_photo_hint.text = "That picture couldn't be opened."


func _on_side_chosen(path: String) -> void:
	var copy := _keep_photo(path)
	if _side.set_photo(copy):
		_side_path = copy
	else:
		_side_hint.text = "That picture couldn't be opened."


func _clear_photo() -> void:
	_photo_path = ""
	_photo.clear()


func _clear_side() -> void:
	_side_path = ""
	_side.clear()


## Finds the 18 front points with MediaPipe (run by Blender's Python, so
## nothing else needs installing), then lets the user correct them.
func _on_find_points() -> void:
	if _photo_path.is_empty():
		_photo_hint.text = "Choose a front photo first."
		return
	if _thread and _thread.is_alive():
		return
	var blender := _blender.text.strip_edges()
	if blender.is_empty() or not FileAccess.file_exists(blender):
		_photo_hint.text = "Automatic points use Blender: set the Blender program below first (Locate…)."
		return
	_save_blender_path(blender)
	DirAccess.make_dir_recursive_absolute(POINTS_LIBRARY)
	var script_path := WORK_DIR + "face_points.py"
	_write(script_path, FileAccess.get_file_as_string(POINTS_SOURCE))
	var out_path := WORK_DIR + "face_points.json"
	if FileAccess.file_exists(out_path):
		DirAccess.remove_absolute(out_path)
	var args := PackedStringArray(["-b", "--python", ProjectSettings.globalize_path(script_path), "--",
		ProjectSettings.globalize_path(_photo_path), ProjectSettings.globalize_path(out_path), ProjectSettings.globalize_path(POINTS_LIBRARY)])
	_auto_button.disabled = true
	_auto_button.text = "Finding points…"
	_photo_hint.text = "Looking for the face… (the first time this downloads MediaPipe, about 100 MB, and can take a few minutes)"
	_thread = Thread.new()
	_thread.start(_run.bind(blender, args))
	while _thread.is_alive():
		await get_tree().process_frame
	var output_text: String = _thread.wait_to_finish()
	_auto_button.disabled = false
	_auto_button.text = "Find Points Automatically"
	var answer: Variant = JSON.parse_string(FileAccess.get_file_as_string(out_path)) if FileAccess.file_exists(out_path) else null
	if answer is Dictionary and (answer as Dictionary).get("points") is Dictionary:
		_photo.set_points(answer["points"])
		_photo_hint.text = "Found the face. Check each dot and drag any that are off (zoom with the mouse wheel)."
	elif answer is Dictionary and answer.has("error"):
		_photo_hint.text = str(answer["error"])
	else:
		_photo_hint.text = "Automatic points didn't work. Click the eyes and the mouth instead.\n" + output_text.strip_edges().right(400)


func _on_build() -> void:
	if _thread and _thread.is_alive():
		return
	var blender := _blender.text.strip_edges()
	if blender.is_empty() or not FileAccess.file_exists(blender):
		_log.text = "Blender wasn't found. Install Blender 4.x and MPFB2, then press Locate… and pick the Blender program."
		return
	_save_blender_path(blender)
	var avatar_name := _name.text.strip_edges().validate_filename()
	if avatar_name.is_empty():
		avatar_name = "Avatar"
	DirAccess.make_dir_recursive_absolute(WORK_DIR)
	DirAccess.make_dir_recursive_absolute(RuntimeModelLoader.CHARACTERS_DIR)
	var source := FileAccess.get_file_as_string(SCRIPT_SOURCE)
	if source.is_empty():
		_log.text = "The builder script is missing from the app (tools/blender/build_avatar.py)."
		return
	var script_path := WORK_DIR + "build_avatar.py"
	_write(script_path, source)
	for helper in HELPER_SOURCES:
		_write(WORK_DIR + helper.get_file(), FileAccess.get_file_as_string(helper))
	var settings_path := WORK_DIR + "avatar_settings.json"
	_write(settings_path, JSON.stringify(_settings(), "\t"))
	var output := RuntimeModelLoader.CHARACTERS_DIR + avatar_name + ".glb"
	_write(output.get_basename() + ".avatar.json", JSON.stringify(_body_state(), "\t"))
	if _character:
		_character.queue_free()
		_character = null
	if FileAccess.file_exists(output):
		DirAccess.remove_absolute(output)
	RuntimeModelLoader.forget(output)
	var args := PackedStringArray(["-b", "--python", ProjectSettings.globalize_path(script_path), "--",
		ProjectSettings.globalize_path(settings_path), ProjectSettings.globalize_path(output)])
	_log.text = "Building %s in Blender… (can take a minute)\n" % avatar_name
	_build_button.disabled = true
	_thread = Thread.new()
	_thread.start(_run.bind(blender, args))
	while _thread.is_alive():
		await get_tree().process_frame
	var output_text: String = _thread.wait_to_finish()
	_build_button.disabled = false
	_log.text += _useful_lines(output_text)
	if FileAccess.file_exists(output):
		_log.text += "\nDone! %s is in Assets → My Characters. (Copies already in a scene update after reopening it.)" % avatar_name
		if _wardrobe.button_pressed:
			_pending_wardrobe = [_outfit.get_item_text(_outfit.selected) if _catalog.is_empty() else "", _hair.get_item_text(_hair.selected)]
		EventBus.info("Built %s with Blender + MPFB2." % avatar_name)
		_current_path = output
		built.emit(output)
		_refresh_list()
	else:
		_log.text += "\nNo character was produced. Check the messages above (is MPFB2 installed and enabled?)."


func _run(blender: String, args: PackedStringArray) -> String:
	var output: Array = []
	OS.execute(blender, args, output, true)
	return "\n".join(PackedStringArray(output))


func _body_state() -> Dictionary:
	var values := {}
	for key in _sliders:
		values[key] = (_sliders[key] as SliderRow).get_value()
	return {"sliders": values, "skin": _skin.get_item_text(_skin.selected), "hair": _hair.get_item_text(_hair.selected),
		"outfit": _outfit.get_item_text(_outfit.selected), "rig": _rig.selected,
		"wardrobe": _wardrobe.button_pressed, "photo": _photo_path, "photo_points": _photo.all_points(),
		"side_photo": _side_path, "side_points": _side.points.duplicate(), "face_fit": _face_fit.button_pressed,
		"talking_face": _talking_face.button_pressed, "even_light": _even_light.button_pressed,
		"clothes_items": _selected_names(_clothes_list), "extra_hair": _selected_names(_hair_list),
		"photo_strength": _photo_strength.get_value()}


func _load_body_settings(model_path: String) -> void:
	var path := model_path.get_basename() + ".avatar.json"
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return
	var values: Dictionary = data.get("sliders", {})
	for key in values:
		if _sliders.has(key):
			(_sliders[key] as SliderRow).set_value(float(values[key]))
	_select_text(_skin, str(data.get("skin", "")))
	_select_text(_hair, str(data.get("hair", "")))
	_select_text(_outfit, str(data.get("outfit", "")))
	_rig.select(clampi(int(data.get("rig", 0)), 0, _rig.item_count - 1))
	_wardrobe.button_pressed = bool(data.get("wardrobe", true))
	_select_names(_clothes_list, data.get("clothes_items", []))
	_select_names(_hair_list, data.get("extra_hair", []))
	_photo_strength.set_value(float(data.get("photo_strength", 0.9)))
	_face_fit.button_pressed = bool(data.get("face_fit", true))
	_talking_face.button_pressed = bool(data.get("talking_face", true))
	_even_light.button_pressed = bool(data.get("even_light", true))
	var photo := str(data.get("photo", ""))
	if not photo.is_empty() and FileAccess.file_exists(photo) and _photo.set_photo(photo):
		_photo_path = photo
		var saved_points: Variant = data.get("photo_points")
		if saved_points is Dictionary:
			_photo.set_points(saved_points)
	else:
		_clear_photo()
	var side := str(data.get("side_photo", ""))
	if not side.is_empty() and FileAccess.file_exists(side) and _side.set_photo(side):
		_side_path = side
		var saved_side: Variant = data.get("side_points")
		if saved_side is Dictionary:
			_side.set_points(saved_side)
	else:
		_clear_side()


func _settings() -> Dictionary:
	var african := _value("african")
	var asian := _value("asian")
	var caucasian := _value("caucasian")
	var total := maxf(african + asian + caucasian, 0.001)
	var years := _value("age_years")
	var age := 0.0
	if years <= 11.0:
		age = (years - 1.0) / 10.0 * 0.1875
	elif years <= 25.0:
		age = 0.1875 + (years - 11.0) / 14.0 * 0.3125
	else:
		age = 0.5 + (years - 25.0) / 65.0 * 0.5
	var skin_keywords: Array = SKINS.get(_skin.get_item_text(_skin.selected), [])
	if skin_keywords.is_empty():
		var young := "young" if years < 40.0 else ("middleage" if years < 60.0 else "old")
		var sex := "female" if _value("gender") < 0.5 else "male"
		var ethnicity := "caucasian"
		if african >= asian and african >= caucasian:
			ethnicity = "african"
		elif asian >= caucasian:
			ethnicity = "asian"
		skin_keywords = [young, ethnicity, sex]
	return {
		"gender": _value("gender"), "age": clampf(age, 0.0, 1.0), "height": _value("height"),
		"weight": _value("weight"), "muscle": _value("muscle"), "proportions": _value("proportions"),
		"race": {"african": african / total, "asian": asian / total, "caucasian": caucasian / total},
		"skin_keywords": skin_keywords,
		"hair": HAIR.get(_hair.get_item_text(_hair.selected), ""),
		"clothes": OUTFITS.get(_outfit.get_item_text(_outfit.selected), []),
		"rig": "game_engine" if _rig.selected == 0 else "default",
		"eyebrows": true, "eyelashes": true,
		"wardrobe": _wardrobe_settings() if _wardrobe.button_pressed else {},
		"face_photo": ProjectSettings.globalize_path(_photo_path) if _photo.is_complete() else "",
		"face_points": _photo.all_points() if _photo.is_complete() else {},
		"face_strength": _photo_strength.get_value(),
		"face_side_photo": ProjectSettings.globalize_path(_side_path) if _photo.is_complete() and _side.is_complete() else "",
		"face_side_points": _side.points.duplicate() if _photo.is_complete() and _side.is_complete() else {},
		"face_fit": _face_fit.button_pressed,
		"face_even_light": _even_light.button_pressed,
		"talking_face": _talking_face.button_pressed,
	}.merged(_catalog_settings(), true)


## Exact files picked from the installed-assets lists (overrides the quick choices).
func _catalog_settings() -> Dictionary:
	if _catalog.is_empty():
		return {}
	var out := {"clothes_paths": _selected_paths(_clothes_list), "keep_body": _wardrobe.button_pressed, "wardrobe": {}}
	if _skin.selected > 0:
		out["skin_path"] = _path_of("skins", _skin.get_item_text(_skin.selected))
	out["hair_path"] = _path_of("hair", _hair.get_item_text(_hair.selected)) if _hair.selected > 0 else ""
	out["extra_hair_paths"] = _selected_paths(_hair_list) if _wardrobe.button_pressed else []
	return out


func _path_of(kind: String, item_name: String) -> String:
	for entry in _catalog.get(kind, []):
		if str(entry["name"]) == item_name:
			return str(entry["path"])
	return ""


func _selected_paths(list: ItemList) -> Array:
	var out: Array = []
	for i in list.get_selected_items():
		out.append(str(list.get_item_metadata(i)))
	return out


func _selected_names(list: ItemList) -> Array:
	var out: Array = []
	for i in list.get_selected_items():
		out.append(list.get_item_text(i))
	return out


func _select_names(list: ItemList, names: Array) -> void:
	list.deselect_all()
	for i in list.item_count:
		if names.has(list.get_item_text(i)):
			list.select(i, false)


## Runs Blender once to list every installed MPFB2 asset, then fills the lists.
func _scan_assets() -> void:
	var blender := _blender.text.strip_edges()
	if blender.is_empty() or not FileAccess.file_exists(blender):
		_catalog_info.text = "Set the Blender path below first (Locate…)."
		return
	DirAccess.make_dir_recursive_absolute(WORK_DIR)
	_write(WORK_DIR + "build_avatar.py", FileAccess.get_file_as_string(SCRIPT_SOURCE))
	_write(WORK_DIR + "list_assets.py", FileAccess.get_file_as_string(LIST_SOURCE))
	_scan_button.disabled = true
	_catalog_info.text = "Asking Blender for the installed assets…"
	var args := PackedStringArray(["-b", "--python", ProjectSettings.globalize_path(WORK_DIR + "list_assets.py"), "--",
		ProjectSettings.globalize_path(CATALOG_FILE)])
	var thread := Thread.new()
	thread.start(_run.bind(blender, args))
	while thread.is_alive():
		await get_tree().process_frame
	var output: String = thread.wait_to_finish()
	_scan_button.disabled = false
	_load_catalog()
	if _catalog.is_empty():
		_catalog_info.text = "Couldn't list the assets:\n" + _useful_lines(output)


func _load_catalog() -> void:
	if not FileAccess.file_exists(CATALOG_FILE):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_FILE))
	if not data is Dictionary:
		return
	_catalog = data
	var hair: Array = _catalog.get("hair", [])
	var clothes: Array = _catalog.get("clothes", [])
	var skins: Array = _catalog.get("skins", [])
	_skin.clear()
	_skin.add_item("Auto (from ethnicity)")
	for entry in skins:
		_skin.add_item(str(entry["name"]))
	_hair.clear()
	_hair.add_item("None (bald)")
	for entry in hair:
		_hair.add_item(str(entry["name"]))
	_clothes_list.clear()
	_hair_list.clear()
	for entry in clothes:
		_clothes_list.add_item(str(entry["name"]), _thumb(str(entry.get("thumb", ""))))
		_clothes_list.set_item_metadata(_clothes_list.item_count - 1, str(entry["path"]))
	for entry in hair:
		_hair_list.add_item(str(entry["name"]), _thumb(str(entry.get("thumb", ""))))
		_hair_list.set_item_metadata(_hair_list.item_count - 1, str(entry["path"]))
	_outfit.get_parent().visible = false
	_clothes_list.visible = true
	_hair_list.visible = true
	_hair_list_label.visible = true
	_catalog_info.text = "%d hairstyles, %d clothing items and %d skins installed. Pick clothes below (Ctrl/Shift-click for several). More: install extra MakeHuman asset packs in MPFB, then Find Installed Assets again." % [hair.size(), clothes.size(), skins.size()]


func _wardrobe_settings() -> Dictionary:
	var hair := {}
	for key in HAIR:
		if not str(HAIR[key]).is_empty():
			hair[key] = HAIR[key]
	var outfits := {}
	for key in OUTFITS:
		if not (OUTFITS[key] as Array).is_empty():
			outfits[key] = OUTFITS[key]
	return {"hair": hair, "outfits": outfits}


func _value(key: String) -> float:
	return (_sliders[key] as SliderRow).get_value()


# --- Look tab (instant) --------------------------------------------------------

func _build_look_tab() -> VBoxContainer:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.add_child(_label("Instant changes, saved with this avatar and used by every copy in your scenes.", true))
	_height_row = SliderRow.new()
	_height_row.setup("Height", 0.5, 1.5, 0.01, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_height_row.set_value(1.0)
	_height_row.value_edited.connect(func(v: float) -> void: _set_look("height", v))
	root.add_child(_height_row)
	_fit_row = SliderRow.new()
	_fit_row.setup("Clothes fit (stops skin showing through)", 0.0, 3.0, 0.05, func(v: float) -> String: return "%.1f cm" % v)
	_fit_row.set_value(0.5)
	_fit_row.value_edited.connect(func(v: float) -> void: _set_look("clothes_fit", v / 100.0))
	root.add_child(_fit_row)
	var reset := Button.new()
	reset.text = "Reset Look"
	reset.pressed.connect(func() -> void: _save_look({}))
	root.add_child(reset)
	_look_box = VBoxContainer.new()
	_look_box.add_theme_constant_override("separation", 6)
	root.add_child(_look_box)
	return root


func _rebuild_look_tab() -> void:
	for child in _look_box.get_children():
		child.queue_free()
	var character := _character as ImportedCharacter
	if character == null:
		_look_box.add_child(_label("Pick or build a character to customise it.", true))
		return
	_height_row.set_value(float(_look.get("height", 1.0)))
	_fit_row.set_value(float(_look.get("clothes_fit", 0.005)) * 100.0)
	if not _pending_wardrobe.is_empty():
		var chosen: Array = _pending_wardrobe
		_pending_wardrobe = []
		_wear(character, "Outfit-", str(chosen[0]))
		_wear(character, "Hair-", str(chosen[1]))
		return
	for prefix in ["Outfit-", "Hair-"]:
		var groups := _groups(character, prefix)
		if groups.is_empty():
			continue
		var option := OptionButton.new()
		option.add_item("None")
		var current := 0
		var hidden_now: Array = _look.get("hidden", [])
		for group_name in groups:
			option.add_item(group_name)
			var parts_in: Array = groups[group_name]
			if not parts_in.is_empty() and not hidden_now.has(parts_in[0]):
				current = option.item_count - 1
		option.select(current)
		option.item_selected.connect(func(i: int) -> void: _wear(character, prefix, option.get_item_text(i)))
		_look_box.add_child(_row("Outfit" if prefix == "Outfit-" else "Hairstyle", option))
	_wardrobe_section(character)
	var tints: Dictionary = _look.get("tints", {})
	var hidden: Array = _look.get("hidden", [])
	for part in character.parts():
		if (part["node"] as Node).has_meta("sb_wardrobe"):
			continue
		var show := Button.new()
		show.toggle_mode = true
		show.text = _pretty_part(str(part["name"]))
		show.tooltip_text = "Click to show or hide this part"
		show.icon = _thumb_for_part(str(part["name"]))
		show.expand_icon = false
		show.add_theme_constant_override("icon_max_width", 64)
		show.alignment = HORIZONTAL_ALIGNMENT_LEFT
		show.clip_text = true
		show.custom_minimum_size = Vector2(0, 72 if show.icon else 32)
		show.button_pressed = not hidden.has(part["name"])
		show.modulate.a = 1.0 if show.button_pressed else 0.45
		show.toggled.connect(_on_part_toggled.bind(str(part["name"])))
		show.toggled.connect(func(on: bool) -> void: show.modulate.a = 1.0 if on else 0.45)
		_look_box.add_child(show)
		for surface in part["surfaces"]:
			var picker := ColorPickerButton.new()
			picker.custom_minimum_size = Vector2(70, 26)
			picker.edit_alpha = false
			var key := str(surface["key"])
			var tint: Variant = tints.get(key)
			picker.color = Color(float(tint[0]), float(tint[1]), float(tint[2])) if tint is Array else (surface["color"] as Color)
			picker.color_changed.connect(_on_tint.bind(key))
			_look_box.add_child(_row(str(surface["label"]), picker))


## Clothes, shoes and hair imported from Avaturn (and others): tick to wear them.
func _wardrobe_section(_character: ImportedCharacter) -> void:
	_look_box.add_child(_label("Clothes from Avaturn, Ready Player Me, Mixamo… (tick to wear; they replace this avatar's own clothes of the same kind). Tip: avatars built with Outfit \"Underwear only\" (or the wardrobe option) have the whole body, so shorter imported clothes never show a gap.", true))
	var worn: Array = _look.get("wardrobe", [])
	var items := WardrobeItem.list_items()
	if items.is_empty():
		_look_box.add_child(_label("None imported yet.", true))
	for entry in items:
		var cb := CheckBox.new()
		cb.text = "%s  (%s)" % [entry["name"], entry["slot"]]
		cb.button_pressed = worn.has(entry["path"])
		cb.toggled.connect(func(on: bool) -> void:
			var list: Array = (_look.get("wardrobe", []) as Array).duplicate()
			list.erase(entry["path"])
			if on:
				list.append(entry["path"])
			_set_look("wardrobe", list)
			_rebuild_look_tab())
		_look_box.add_child(cb)
	var row := HBoxContainer.new()
	var imp := Button.new()
	imp.text = "Import clothes from a character…"
	imp.tooltip_text = "Pick a .glb exported from Avaturn (or Ready Player Me, Mixamo, MakeHuman). Its clothes, shoes and hair are kept for all your characters."
	imp.pressed.connect(_on_import_wardrobe)
	row.add_child(imp)
	var del := Button.new()
	del.text = "Delete unticked imports"
	del.tooltip_text = "Removes imported pieces that this avatar isn't wearing from your wardrobe."
	del.pressed.connect(_on_delete_wardrobe)
	row.add_child(del)
	_look_box.add_child(row)
	_look_box.add_child(HSeparator.new())


func _on_import_wardrobe() -> void:
	var d := FileDialog.new()
	d.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.filters = PackedStringArray(["*.glb, *.gltf, *.fbx ; Character with clothes"])
	d.file_selected.connect(func(path: String) -> void:
		d.queue_free()
		EventBus.info("Taking the clothes off %s…" % path.get_file())
		await get_tree().process_frame
		var r := WardrobeItem.import_from(path, {})
		if not str(r.get("error", "")).is_empty():
			EventBus.error(str(r["error"]))
			return
		var list: Array = (_look.get("wardrobe", []) as Array).duplicate()
		for it in r.get("items", []):
			if not list.has(it["path"]):
				list.append(it["path"])
		_set_look("wardrobe", list)
		_rebuild_look_tab()
		EventBus.info("Imported %d piece(s) and put them on this avatar." % (r.get("items", []) as Array).size()))
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered_ratio(0.7)


func _on_delete_wardrobe() -> void:
	var worn: Array = _look.get("wardrobe", [])
	var n := 0
	for entry in WardrobeItem.list_items():
		if worn.has(entry["path"]):
			continue
		WardrobeItem.delete_item(str(entry["path"]))
		n += 1
	EventBus.info("Deleted %d imported piece(s)." % n)
	_rebuild_look_tab()


func _on_delete_avatar() -> void:
	if _current_path.is_empty():
		return
	var path := _current_path
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "Delete the avatar \"%s\"?\nScenes that use it will show it missing. This can't be undone." % path.get_file().get_basename()
	confirm.confirmed.connect(func() -> void:
		if _character:
			_character.queue_free()
			_character = null
		for p in [path, ImportedCharacter.look_path(path), path.get_basename() + ".blend", path.get_basename() + ".json"]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
		RuntimeModelLoader.forget(path)
		_current_path = ""
		_refresh_list()
		built.emit("")
		EventBus.info("Deleted %s." % path.get_file().get_basename())
		confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	add_child(confirm)
	confirm.popup_centered()


## Wardrobe groups: { "Casual": [part names…] } for parts named "<prefix><group>-…".
func _groups(character: ImportedCharacter, prefix: String) -> Dictionary:
	var out := {}
	for part in character.parts():
		var part_name := str(part["name"])
		if not part_name.begins_with(prefix):
			continue
		var rest := part_name.trim_prefix(prefix)
		var group_name := (rest.get_slice("--", 0) if rest.contains("--") else rest.get_slice("-", 0)).replace("_", " ")
		if not out.has(group_name):
			out[group_name] = []
		(out[group_name] as Array).append(part_name)
	return out


## Shows one wardrobe group (or none) and hides the others of that kind.
func _wear(character: ImportedCharacter, prefix: String, group_name: String) -> void:
	var hidden: Array = _look.get("hidden", []).duplicate()
	var groups := _groups(character, prefix)
	for key in groups:
		for part_name in groups[key]:
			hidden.erase(part_name)
			if str(key).replace("_", " ") != group_name.replace("_", " "):
				hidden.append(part_name)
	_set_look("hidden", hidden)
	_rebuild_look_tab()


## Shows a list as a grid of pictures with names underneath.
static func _picture_grid(list: ItemList) -> void:
	list.icon_mode = ItemList.ICON_MODE_TOP
	list.max_columns = 0
	list.same_column_width = true
	list.fixed_column_width = 104
	list.fixed_icon_size = Vector2i(88, 88)
	list.max_text_lines = 2


var _thumbs: Dictionary = {}


## A thumbnail picture from MPFB's .thumb (PNG) files, cached.
func _thumb(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	if _thumbs.has(path):
		return _thumbs[path]
	var bytes := FileAccess.get_file_as_bytes(path)
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK and image.load_jpg_from_buffer(bytes) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	_thumbs[path] = texture
	return texture


## The catalog picture for a built part ("Clothes-jeans01--…" → jeans01).
func _thumb_for_part(part_name: String) -> Texture2D:
	var item := _pretty_part(part_name).replace(" ", "_")
	for kind in ["clothes", "hair"]:
		for entry in _catalog.get(kind, []):
			var entry_name := str(entry["name"])
			if entry_name == item or entry_name == item.replace("_", " ") or part_name.to_lower().contains(entry_name.to_lower()):
				return _thumb(str(entry.get("thumb", "")))
	return null


static func _pretty_part(part_name: String) -> String:
	for prefix in ["Clothes-", "Outfit-", "Hair-"]:
		if part_name.begins_with(prefix):
			var rest := part_name.trim_prefix(prefix)
			return (rest.get_slice("--", 0) if rest.contains("--") else rest.get_slice("-", 0)).replace("_", " ")
	return part_name


func _on_part_toggled(on: bool, part_name: String) -> void:
	var hidden: Array = _look.get("hidden", []).duplicate()
	hidden.erase(part_name)
	if not on:
		hidden.append(part_name)
	_set_look("hidden", hidden)


func _on_tint(color: Color, key: String) -> void:
	var tints: Dictionary = _look.get("tints", {}).duplicate()
	tints[key] = [color.r, color.g, color.b]
	_set_look("tints", tints)


func _set_look(key: String, value: Variant) -> void:
	var look := _look.duplicate(true)
	look[key] = value
	_save_look(look)


func _save_look(look: Dictionary) -> void:
	var character := _character as ImportedCharacter
	if character == null or _current_path.is_empty():
		return
	_look = look
	character.apply_look(look)
	ImportedCharacter.save_look(_current_path, look)
	get_tree().call_group(&"imported_characters", &"reload_look")
	if look.is_empty():
		_rebuild_look_tab()


# --- Animation tab ---------------------------------------------------------------

func _build_animation_tab() -> VBoxContainer:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.add_child(_label("Click an action to play it on the preview. Add more with Import → Import animation pack (Mixamo .fbx).", true))
	_mode = OptionButton.new()
	for key in PREVIEW_MODES:
		_mode.add_item(key)
	_mode.item_selected.connect(func(_i: int) -> void: _rebuild_motion())
	root.add_child(_row("Auto preview", _mode))
	_speed_row = SliderRow.new()
	_speed_row.setup("Playback speed", 0.1, 2.0, 0.05, func(v: float) -> String: return "%.2f×" % v)
	_speed_row.set_value(1.0)
	root.add_child(_speed_row)
	_actions = ItemList.new()
	_actions.custom_minimum_size = Vector2(0, 420)
	_actions.item_selected.connect(_on_action_selected)
	root.add_child(_actions)
	root.add_child(_heading("Rig check"))
	_rig_info = _label("", true)
	root.add_child(_rig_info)
	return root


func _rebuild_actions() -> void:
	_actions.clear()
	_action = MotionLibrary.AUTO
	var character := _character as CharacterBase
	if character:
		for action in character.action_names():
			_actions.add_item(action)
			_actions.set_item_tooltip(_actions.item_count - 1, character.action_hint(action))
		if _actions.item_count > 0:
			_actions.select(0)
	_rebuild_motion()
	_update_rig_info()


func _update_rig_info() -> void:
	var character := _character as ImportedCharacter
	if character == null:
		_rig_info.text = ""
		return
	var report := character.rig_report()
	var loose: PackedStringArray = report["loose"]
	var text := "Skeletons: %d" % int(report["skeletons"])
	if int(report["followers"]) > 0:
		text += " (the extra ones copy the body's pose, so clothes and hair follow)"
	if loose.is_empty():
		text += "\nAll parts are attached to the skeleton and move with the body."
	else:
		text += "\nNot attached to the skeleton, so they won't move: %s.\nRebuild this avatar (Body tab) with the latest version of the app to fix it." % ", ".join(loose)
	_rig_info.text = text


func _on_action_selected(index: int) -> void:
	_action = _actions.get_item_text(index)
	_time = 0.0
	_rebuild_motion()


## A motion that plays the chosen action; for "Auto" it fakes walking or
## running on the spot so idle/walk/run blending can be previewed.
func _rebuild_motion() -> void:
	_motion = CharacterMotion.stationary()
	_motion.actions = [{"t": 0.0, "action": _action}]
	var speed: float = PREVIEW_MODES.values()[maxi(_mode.selected, 0)] if _mode else 0.0
	if _action == MotionLibrary.AUTO and speed > 0.0:
		# Build the tables locally, then assign (packed arrays are copied on access).
		var samples := int(CharacterMotion.SAMPLE_RATE * 600.0)
		var distance := PackedFloat32Array()
		var speeds := PackedFloat32Array()
		var heading := PackedFloat32Array()
		distance.resize(samples)
		speeds.resize(samples)
		heading.resize(samples)
		speeds.fill(speed)
		heading.fill(0.0)
		for i in samples:
			distance[i] = speed * float(i) / CharacterMotion.SAMPLE_RATE
		_motion.distance = distance
		_motion.speed = speeds
		_motion.heading = heading


# --- Helpers -------------------------------------------------------------------

static func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()


static func _select_text(option: OptionButton, text: String) -> void:
	for i in option.item_count:
		if option.get_item_text(i) == text:
			option.select(i)


static func _useful_lines(text: String) -> String:
	var out := PackedStringArray()
	for line in text.split("\n"):
		if line.contains("[avatar]") or line.contains("Error") or line.contains("ERROR"):
			out.append(line.replace("[avatar] ", ""))
	return "\n".join(out)


func _load_blender_path() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		var saved := str(config.get_value("avatar", "blender_path", ""))
		if not saved.is_empty():
			return saved
	for candidate in _blender_candidates():
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


func _save_blender_path(path: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE)
	config.set_value("avatar", "blender_path", path)
	config.save(SETTINGS_FILE)


static func _blender_candidates() -> PackedStringArray:
	var out := PackedStringArray()
	match OS.get_name():
		"Windows":
			var base := "C:/Program Files/Blender Foundation/"
			var dir := DirAccess.open(base)
			if dir:
				var versions := dir.get_directories()
				versions.reverse()
				for version in versions:
					out.append(base + version + "/blender.exe")
		"macOS":
			out.append("/Applications/Blender.app/Contents/MacOS/Blender")
		_:
			out.append_array(["/usr/bin/blender", "/usr/local/bin/blender", "/snap/bin/blender"])
	return out


func _options(parent: Control, label: String, items: Array) -> OptionButton:
	var option := OptionButton.new()
	for item in items:
		option.add_item(str(item))
	parent.add_child(_row(label, option))
	return option


static func _scroll(tab_name: String, content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


static func _row(label: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var text := _label(label)
	text.custom_minimum_size = Vector2(110, 0)
	text.clip_text = true
	row.add_child(text)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


static func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.uppercase = true
	label.theme_type_variation = &"SectionHeader"
	return label


static func _label(text: String, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"DimLabel"
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

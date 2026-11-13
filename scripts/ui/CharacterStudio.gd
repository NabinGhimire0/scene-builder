class_name CharacterStudio
extends PanelContainer
## The Characters tab: make your own people and animals.
##  • Kinds: Realistic, Animated film (Pixar-like), Cartoon, Sketch, Animal.
##  • Start from a ready-made character, then change anything: body, face, skin,
##    hair, clothes (including clothes imported from Avaturn), colours.
##  • Live preview with a turntable, actions and expressions.
##  • Save to "My Characters" (shows in the Assets panel) or place straight into the scene.

signal place_requested(prop: Dictionary)
signal library_changed

const KIND_INFO := {
	"realistic": ["Realistic", "Real-looking people: skin, eyes, hair and fabric like a modern film or game."],
	"pixar": ["Animated film", "Big eyes, soft shapes and bright colours, like an animated feature film."],
	"cartoon": ["Cartoon", "Simple drawn cartoon people with big faces and many expressions."],
	"sketch": ["Sketch", "Pencil-sketch people, shadows and silhouettes for storybook films."],
	"animal": ["Animal", "Dogs, cats, cows, goats, horses, tigers, birds and more."],
}
const SKIN_TONES := ["#f4d7c4", "#eac0a2", "#d9a582", "#c68b62", "#b07650", "#8d5a3b", "#6b4029", "#4a2c1d"]
const HAIR_COLOURS := ["#0f0c0a", "#2b1d14", "#4a301c", "#7a4e2a", "#a87a4a", "#d8b77a", "#8f2f1d", "#9a9a9a", "#e8e6e1"]
const EYE_COLOURS := ["#3a2412", "#5a3a1c", "#2f5d8a", "#5a7a4a", "#6b6b6b"]
const CLOTH_COLOURS := ["#f2f2f0", "#1c1c1f", "#2c3b5a", "#7a1f24", "#2f5a3a", "#d6a43a", "#b85a2a", "#6a4a8a", "#c7c2b4", "#5a4632"]
const BODY_SLIDERS := ["shoulders", "chest", "hips", "belly", "neck"]
const FACE_LABELS := {"face_width": "Face width", "face_length": "Face length", "jaw": "Jaw", "chin": "Chin",
	"cheekbones": "Cheekbones", "cheeks": "Cheeks", "nose_size": "Nose size", "nose_width": "Nose width",
	"nose_length": "Nose length", "nose_bridge": "Nose bridge", "eye_size": "Eye size", "eye_spacing": "Eye spacing",
	"lips": "Lips", "mouth_width": "Mouth width", "ears": "Ears", "brow_height": "Brow height"}
const NICE := {"tshirt": "T-shirt", "longsleeve": "Long-sleeve top", "shirt": "Shirt", "hoodie": "Hoodie", "sweater": "Sweater",
	"jacket": "Jacket", "raincoat": "Raincoat", "kurta": "Kurta", "tanktop": "Tank top", "trousers": "Trousers", "jeans": "Jeans",
	"shorts": "Shorts", "longshorts": "Knee shorts", "leggings": "Leggings", "skirt": "Skirt", "shoes": "Shoes",
	"sneakers": "Sneakers", "boots": "Boots", "none": "None", "short": "Short", "kid": "Kid's cut", "receding": "Receding",
	"buzz": "Buzz cut", "bob": "Bob", "long": "Long", "ponytail": "Ponytail", "pigtails": "Pigtails", "bun": "Bun",
	"bald": "Bald", "stubble": "Stubble", "full": "Full beard"}

var _kind := "realistic"
var _spec: Dictionary = {}
var _path := ""  # the .character file being edited ("" = new)

var _kind_buttons: Dictionary = {}
var _presets: ItemList
var _mine: ItemList
var _mine_paths: PackedStringArray = []
var _name_edit: LineEdit
var _settings: VBoxContainer
var _tabs: TabContainer
var _busy: Label
var _rebuild_timer: Timer
var _action_pick: OptionButton
var _expr_pick: OptionButton
var _turn: CheckBox

# Preview
var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _character: Node3D
var _motion: CharacterMotion
var _time := 0.0
var _yaw := 0.5
var _pitch := -0.08
var _distance := 3.2
var _target := Vector3(0, 0.95, 0)
var _dragging := false
var _active := false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_build_left())
	root.add_child(_build_centre())
	root.add_child(_build_right())
	_rebuild_timer = Timer.new()
	_rebuild_timer.one_shot = true
	_rebuild_timer.wait_time = 0.35
	_rebuild_timer.timeout.connect(_rebuild_preview)
	add_child(_rebuild_timer)
	_motion = CharacterMotion.stationary()
	_select_kind("realistic", true)
	refresh_mine()


## Called when the tab is shown or hidden (the preview only renders while shown).
func set_active(on: bool) -> void:
	_active = on
	if _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if on:
		refresh_mine()


## Open a saved character for editing.
func open_character(path: String) -> void:
	var spec := CharacterFactory.load_file(path)
	if spec.is_empty():
		EventBus.error("Couldn't read %s." % path.get_file())
		return
	_path = path
	_spec = spec
	_kind = str(spec.get("kind", "realistic"))
	_name_edit.text = str(spec.get("name", path.get_file().get_basename().capitalize()))
	_mark_kind()
	_fill_presets()
	_build_settings()
	_rebuild_preview()


# ------------------------------------------------------------------ layout

func _build_left() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 0)
	var margin := _margin(10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	box.add_child(_heading("Make a character"))
	for kind in CharacterFactory.KINDS:
		var b := Button.new()
		b.text = KIND_INFO[kind][0]
		b.tooltip_text = KIND_INFO[kind][1]
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_select_kind.bind(kind, false))
		box.add_child(b)
		_kind_buttons[kind] = b
	box.add_child(HSeparator.new())
	box.add_child(_dim("Start from"))
	_presets = ItemList.new()
	_presets.custom_minimum_size = Vector2(0, 170)
	_presets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_presets.item_activated.connect(_on_preset)
	_presets.item_clicked.connect(func(i: int, _p: Vector2, _b: int) -> void: _on_preset(i))
	box.add_child(_presets)
	box.add_child(HSeparator.new())
	box.add_child(_dim("My characters"))
	_mine = ItemList.new()
	_mine.custom_minimum_size = Vector2(0, 150)
	_mine.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mine.item_clicked.connect(func(i: int, _p: Vector2, _b: int) -> void: open_character(_mine_paths[i]))
	box.add_child(_mine)
	var row := HBoxContainer.new()
	var dup := Button.new()
	dup.text = "Copy"
	dup.tooltip_text = "Make a copy of the character you're editing (then change it)."
	dup.pressed.connect(_on_copy)
	row.add_child(dup)
	var del := Button.new()
	del.text = "Delete"
	del.tooltip_text = "Delete the selected character from My characters."
	del.pressed.connect(_on_delete)
	row.add_child(del)
	box.add_child(row)
	return panel


func _build_centre() -> Control:
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 0)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var bar_margin := _margin(6)
	bar_margin.add_child(bar)
	side.add_child(bar_margin)
	bar.add_child(_dim("Action"))
	_action_pick = OptionButton.new()
	_action_pick.custom_minimum_size = Vector2(140, 0)
	_action_pick.item_selected.connect(func(_i: int) -> void: _apply_preview_motion())
	bar.add_child(_action_pick)
	bar.add_child(_dim("Face"))
	_expr_pick = OptionButton.new()
	for e in SketchCharacter.EXPRESSIONS:
		_expr_pick.add_item(str(e))
	_expr_pick.item_selected.connect(func(_i: int) -> void: _apply_preview_motion())
	bar.add_child(_expr_pick)
	_turn = CheckBox.new()
	_turn.text = "Turntable"
	_turn.button_pressed = true
	bar.add_child(_turn)
	for view in [["Full", "full"], ["Face", "face"], ["Side", "side"]]:
		var b := Button.new()
		b.text = view[0]
		b.pressed.connect(_frame.bind(view[1]))
		bar.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_busy = Label.new()
	_busy.theme_type_variation = &"DimLabel"
	bar.add_child(_busy)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.gui_input.connect(_on_preview_input)
	side.add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	container.add_child(_viewport)
	_stage = Node3D.new()
	_viewport.add_child(_stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.63, 0.7)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.25
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_stage.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.5
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 12.0
	_stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -120, 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.82, 0.87, 1.0)
	_stage.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 175, 0)
	rim.light_energy = 0.7
	rim.light_color = Color(1.0, 0.92, 0.82)
	_stage.add_child(rim)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 2.2
	floor_mesh.bottom_radius = 2.2
	floor_mesh.height = 0.04
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.36, 0.37, 0.4)
	floor_material.roughness = 0.75
	floor_mesh.material = floor_material
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.position.y = -0.02
	_stage.add_child(floor_node)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	_stage.add_child(_camera)
	var hint := _dim("Drag to turn · wheel to zoom · right-drag up/down to move the view")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(hint)
	return side


func _build_right() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	var margin := _margin(10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var name_row := HBoxContainer.new()
	name_row.add_child(_dim("Name"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "e.g. Grandfather Ram"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)
	box.add_child(name_row)
	_settings = VBoxContainer.new()
	_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_settings)
	var buttons := HBoxContainer.new()
	var rnd := Button.new()
	rnd.text = "Surprise me"
	rnd.tooltip_text = "Make a random character of this kind."
	rnd.pressed.connect(_on_random)
	buttons.add_child(rnd)
	var save := Button.new()
	save.text = "Save"
	save.tooltip_text = "Save to My characters (also listed in the Assets panel)."
	save.pressed.connect(func() -> void: _save())
	buttons.add_child(save)
	var place := Button.new()
	place.text = "Put in scene"
	place.theme_type_variation = &"AccentButton"
	place.tooltip_text = "Save, go back to the scene and click where the character should stand."
	place.pressed.connect(_on_place)
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(place)
	box.add_child(buttons)
	return panel


# ------------------------------------------------------------------ kinds & presets

func _select_kind(kind: String, quiet: bool) -> void:
	_kind = kind
	_path = ""
	_mark_kind()
	_fill_presets()
	var presets := _preset_list()
	_spec = (presets[0][1] as Dictionary).duplicate(true)
	_spec["kind"] = kind
	_name_edit.text = ""
	_build_settings()
	if not quiet or is_inside_tree():
		_rebuild_preview()


func _mark_kind() -> void:
	for k in _kind_buttons:
		(_kind_buttons[k] as Button).button_pressed = (k == _kind)


func _fill_presets() -> void:
	_presets.clear()
	for p in _preset_list():
		_presets.add_item(str(p[0]))


func _on_preset(index: int) -> void:
	var list := _preset_list()
	if index < 0 or index >= list.size():
		return
	_spec = (list[index][1] as Dictionary).duplicate(true)
	_spec["kind"] = _kind
	_path = ""
	_name_edit.text = ""
	_build_settings()
	_rebuild_preview()


func _preset_list() -> Array:
	match _kind:
		"realistic", "pixar":
			return _human_presets(_kind == "pixar")
		"cartoon", "sketch":
			return _sketch_presets(_kind)
		"animal":
			var out: Array = []
			for s in AnimalBuilder.SPECIES:
				out.append([AnimalBuilder.label(s), {"species": s}])
			return out
	return [["Default", {}]]


static func _outfit(top: String, top_c: String, bottom: String, bottom_c: String, shoes := "shoes", shoe_c := "#3a2618") -> Dictionary:
	return {"top": {"style": top, "color": top_c}, "bottom": {"style": bottom, "color": bottom_c}, "shoes": {"style": shoes, "color": shoe_c}}


static func _human_presets(pixar: bool) -> Array:
	var list := [
		["Young man", {"gender": 1.0, "age": 26, "weight": 0.5, "muscle": 0.55, "height": 0.6, "race": {"asian": 0.7, "caucasian": 0.3}, "face_seed": 101,
			"skin": "#c08c6a", "eyes": "#3a2412", "hair": {"style": "short", "color": "#120e0b"}, "beard": {"style": "stubble"},
			"outfit": _outfit("shirt", "#dfe3ea", "jeans", "#2c3b5a")}],
		["Young woman", {"gender": 0.0, "age": 24, "weight": 0.45, "muscle": 0.45, "height": 0.45, "race": {"asian": 0.75, "caucasian": 0.25}, "face_seed": 202,
			"skin": "#d6a684", "eyes": "#3a2412", "hair": {"style": "long", "color": "#140f0c"},
			"outfit": _outfit("kurta", "#b23a48", "leggings", "#e8e1d4", "shoes", "#5a3a2a")}],
		["Boy", {"gender": 1.0, "age": 9, "weight": 0.45, "muscle": 0.5, "height": 0.5, "race": {"asian": 0.8, "caucasian": 0.2}, "face_seed": 303,
			"skin": "#c99572", "hair": {"style": "kid", "color": "#16110d"}, "outfit": _outfit("tshirt", "#2f6fb0", "shorts", "#3b3b40", "sneakers", "#e8e8e8")}],
		["Girl", {"gender": 0.0, "age": 7, "weight": 0.45, "muscle": 0.45, "height": 0.5, "race": {"asian": 0.8, "caucasian": 0.2}, "face_seed": 404,
			"skin": "#d1a07d", "hair": {"style": "pigtails", "color": "#16110d"}, "outfit": _outfit("tshirt", "#e3a3b8", "skirt", "#4a5a8a", "sneakers", "#f0f0f0")}],
		["Teenager", {"gender": 1.0, "age": 15, "weight": 0.45, "muscle": 0.5, "height": 0.5, "race": {"asian": 0.6, "caucasian": 0.4}, "face_seed": 505,
			"skin": "#c4916d", "hair": {"style": "short", "color": "#1b140f"}, "outfit": _outfit("hoodie", "#3a4a3a", "jeans", "#2b3550", "sneakers", "#f2f2f2")}],
		["Grandfather", {"gender": 1.0, "age": 72, "weight": 0.45, "muscle": 0.35, "height": 0.45, "race": {"asian": 0.8, "caucasian": 0.2}, "face_seed": 606,
			"skin": "#b8835e", "hair": {"style": "receding", "color": "#c9c6c0"}, "beard": {"style": "short", "color": "#d6d3cc"},
			"outfit": _outfit("kurta", "#e8e2d2", "trousers", "#e2dccb", "shoes", "#4a3626")}],
		["Grandmother", {"gender": 0.0, "age": 68, "weight": 0.55, "muscle": 0.35, "height": 0.35, "race": {"asian": 0.85, "caucasian": 0.15}, "face_seed": 707,
			"skin": "#c18e6a", "hair": {"style": "bun", "color": "#b8b4ad"}, "outfit": _outfit("sweater", "#7a2a35", "skirt", "#3a2f45", "shoes", "#2a2220")}],
		["Office worker", {"gender": 1.0, "age": 38, "weight": 0.55, "muscle": 0.45, "height": 0.55, "race": {"asian": 0.5, "caucasian": 0.5}, "face_seed": 808,
			"skin": "#c8987a", "hair": {"style": "short", "color": "#2a1d14"}, "outfit": _outfit("shirt", "#a9c3e0", "trousers", "#2d2f36")}],
		["Farmer", {"gender": 1.0, "age": 45, "weight": 0.4, "muscle": 0.65, "height": 0.45, "race": {"asian": 0.9, "caucasian": 0.1}, "face_seed": 909,
			"skin": "#a8714c", "hair": {"style": "short", "color": "#1a1410"}, "beard": {"style": "stubble"},
			"outfit": _outfit("kurta", "#d9d0b8", "trousers", "#6a5a44", "boots", "#3a2a1a")}],
		["Student", {"gender": 0.0, "age": 19, "weight": 0.42, "muscle": 0.45, "height": 0.5, "race": {"asian": 0.6, "caucasian": 0.4}, "face_seed": 1010,
			"skin": "#d8ad8c", "hair": {"style": "ponytail", "color": "#2a1b12"}, "outfit": _outfit("longsleeve", "#f0ece0", "jeans", "#3a4a6a", "sneakers", "#ffffff")}],
		["Athlete", {"gender": 1.0, "age": 27, "weight": 0.4, "muscle": 0.85, "height": 0.7, "race": {"african": 0.8, "caucasian": 0.2}, "face_seed": 1111,
			"skin": "#6b4029", "hair": {"style": "buzz", "color": "#0c0a09"}, "outfit": _outfit("tanktop", "#d23a2a", "shorts", "#1c1c20", "sneakers", "#f0f0f0")}],
	]
	if pixar:
		for p in list:
			(p[1] as Dictionary)["stylize"] = 1.0
	return list


static func _sketch_presets(kind: String) -> Array:
	var out := [
		["Man", {"props": {"body_type": "Man", "hair": "Short", "shirt_color": "#5a7a9a", "shirt_color_alpha": 0.0}}],
		["Woman", {"props": {"body_type": "Woman", "hair": "Long"}}],
		["Child", {"props": {"body_type": "Child", "hair": "Curl"}}],
		["Elder", {"props": {"body_type": "Elder", "hair": "None"}}],
	]
	if kind == "sketch":
		out.append(["Shadow figure", {"props": {"figure": "Shadow", "body_type": "Man"}}])
	else:
		out.append(["Girl with bun", {"props": {"body_type": "Child", "hair": "Bun", "shirt_color": "#e07a9a", "shirt_color_alpha": 1.0}}])
	return out


# ------------------------------------------------------------------ settings panel

func _build_settings() -> void:
	for c in _settings.get_children():
		c.queue_free()
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings.add_child(_tabs)
	match _kind:
		"realistic", "pixar":
			_human_settings()
		"cartoon", "sketch":
			_sketch_settings()
		"animal":
			_animal_settings()


func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	return box


func _human_settings() -> void:
	var body := _tab("Body")
	_slider(body, "Female ↔ Male", "gender", 0.0, 1.0, 0.01, 0.5)
	_slider(body, "Age (years)", "age", 1.0, 90.0, 1.0, 25.0, func(v: float) -> String: return "%d" % int(v))
	_slider(body, "Height", "height", 0.0, 1.0, 0.01, 0.5)
	_slider(body, "Weight", "weight", 0.0, 1.0, 0.01, 0.5)
	_slider(body, "Muscle", "muscle", 0.0, 1.0, 0.01, 0.5)
	body.add_child(_dim("Family background (mix)"))
	_slider(body, "African", "race/african", 0.0, 1.0, 0.01, 0.0)
	_slider(body, "Asian", "race/asian", 0.0, 1.0, 0.01, 0.5)
	_slider(body, "European", "race/caucasian", 0.0, 1.0, 0.01, 0.5)
	body.add_child(_dim("Body shape"))
	for key in BODY_SLIDERS:
		_slider(body, str(key).capitalize(), "body/" + key, -1.0, 1.0, 0.02, 0.0)

	var face := _tab("Face")
	var seed_row := HBoxContainer.new()
	var new_face := Button.new()
	new_face.text = "New face"
	new_face.tooltip_text = "A different face with the same body, skin and clothes."
	new_face.pressed.connect(func() -> void:
		_spec["face_seed"] = randi() % 100000
		_changed())
	seed_row.add_child(new_face)
	var plain := Button.new()
	plain.text = "Reset face"
	plain.pressed.connect(func() -> void:
		_spec.erase("face")
		_build_settings()
		_changed())
	seed_row.add_child(plain)
	face.add_child(seed_row)
	_slider(face, "How unique the face is", "face_variety", 0.0, 1.0, 0.01, 0.35)
	for key in FACE_LABELS:
		_slider(face, FACE_LABELS[key], "face/" + key, -1.0, 1.0, 0.02, 0.0)

	var skin := _tab("Skin")
	_colour(skin, "Skin", "skin", "#c99572", SKIN_TONES)
	_colour(skin, "Eyes", "eyes", "#3a2412", EYE_COLOURS)
	_colour(skin, "Lips", "lips", "#b56a62", ["#b56a62", "#9a5048", "#c7787a", "#a8304a", "#7a3a3a"])
	_colour(skin, "Eyebrows", "brows", "#1a1310", HAIR_COLOURS)
	_slider(skin, "Freckles", "freckles", 0.0, 1.0, 0.01, 0.0)
	_slider(skin, "Rosy cheeks", "blush", 0.0, 1.0, 0.01, 0.25)
	_slider(skin, "Make-up", "makeup", 0.0, 1.0, 0.01, 0.0)
	_colour(skin, "Make-up colour", "makeup_color", "#3a2a33", ["#3a2a33", "#5a2a4a", "#2a3a5a", "#6a4a2a"])
	_slider(skin, "Wrinkles (−1 = by age)", "wrinkles", -1.0, 1.0, 0.02, -1.0)
	_check(skin, "Eyelashes", "lashes", false)

	var hair := _tab("Hair")
	_choice(hair, "Hair style", "hair/style", HumanBuilder.HAIR, "short")
	_colour(hair, "Hair colour", "hair/color", "#1a1310", HAIR_COLOURS)
	_slider(hair, "Length (long styles)", "hair/length", 0.05, 0.6, 0.01, 0.34)
	_slider(hair, "Volume", "hair/volume", 0.4, 1.8, 0.02, 1.0)
	_slider(hair, "Shine", "hair/gloss", 0.0, 1.0, 0.01, 0.3)
	_colour(hair, "Hair tie", "hair/tie", "#d8263a", ["#d8263a", "#2a5ad8", "#f0c020", "#202020", "#f0f0f0"])
	_choice(hair, "Beard", "beard/style", HumanBuilder.BEARDS, "none")
	_colour(hair, "Beard colour", "beard/color", "#1a1310", HAIR_COLOURS)

	var clothes := _tab("Clothes")
	_garment(clothes, "Top", "top", HumanBuilder.TOPS)
	_garment(clothes, "Bottom", "bottom", HumanBuilder.BOTTOMS)
	_garment(clothes, "Shoes", "shoes", HumanBuilder.SHOES)
	clothes.add_child(HSeparator.new())
	clothes.add_child(_heading("Imported clothes"))
	clothes.add_child(_wrap("Clothes taken from an Avaturn (or other) character. They are fitted to this body and replace the matching built-in piece."))
	_wardrobe_list(clothes)

	var style := _tab("Style")
	_slider(style, "Animated-film look", "stylize", 0.0, 1.0, 0.01, 1.0 if _kind == "pixar" else 0.0)
	_slider(style, "Head size", "head_scale", 0.85, 1.35, 0.01, 1.0)
	_slider(style, "Eye size", "eye_scale", 0.85, 1.5, 0.01, 1.0)
	style.add_child(_wrap("Tip: the Animated film kind starts with the film look on. Turn it down for a semi-realistic look."))


func _garment(parent: Control, title: String, slot: String, styles: Array) -> void:
	parent.add_child(_heading(title))
	var base := "outfit/%s/" % slot
	_choice(parent, "Style", base + "style", styles, "none")
	_colour(parent, "Colour", base + "color", "#777777", CLOTH_COLOURS)
	if slot != "shoes":
		var fabrics := ["auto"] + HumanBuilder.FABRICS
		_choice(parent, "Fabric", base + "fabric", fabrics, "auto")
		_slider(parent, "Loose ↔ tight", base + "loose", 0.6, 1.6, 0.02, 1.0)
	if slot == "bottom":
		_slider(parent, "Length", base + "length", 0.5, 1.2, 0.02, 1.0)
	if slot == "shoes":
		_colour(parent, "Sole", base + "sole", "#2a2a2a", ["#2a2a2a", "#f0f0f0", "#6a4a2a"])


func _wardrobe_list(parent: Control) -> void:
	var items := WardrobeItem.list_items()
	var worn: Array = ((_spec.get("outfit", {}) as Dictionary).get("extra", []) as Array)
	if items.is_empty():
		parent.add_child(_dim("None yet."))
	for entry in items:
		var cb := CheckBox.new()
		cb.text = "%s  (%s)" % [entry["name"], entry["slot"]]
		cb.button_pressed = worn.has(entry["path"])
		cb.toggled.connect(func(on: bool) -> void:
			var outfit: Dictionary = _spec.get("outfit", {})
			var extra: Array = outfit.get("extra", [])
			extra.erase(entry["path"])
			if on:
				extra.append(entry["path"])
			outfit["extra"] = extra
			_spec["outfit"] = outfit
			_changed())
		parent.add_child(cb)
	var row := HBoxContainer.new()
	var imp := Button.new()
	imp.text = "Import clothes from a character…"
	imp.tooltip_text = "Pick a .glb from Avaturn (or Ready Player Me, Mixamo…). Its clothes are taken off and saved for your characters."
	imp.pressed.connect(_on_import_clothes)
	row.add_child(imp)
	var del := Button.new()
	del.text = "Delete unticked"
	del.tooltip_text = "Remove imported pieces this character isn't wearing from your wardrobe."
	del.pressed.connect(func() -> void:
		var worn_now: Array = ((_spec.get("outfit", {}) as Dictionary).get("extra", []) as Array)
		for entry in WardrobeItem.list_items():
			if not worn_now.has(entry["path"]):
				WardrobeItem.delete_item(str(entry["path"]))
		_build_settings())
	row.add_child(del)
	parent.add_child(row)


func _sketch_settings() -> void:
	var look := _tab("Look")
	_choice(look, "Body", "props/body_type", ["Man", "Woman", "Child", "Elder"], "Man")
	if _kind == "sketch":
		_choice(look, "Drawing", "props/figure", ["Person", "Shadow"], "Person")
	_slider(look, "Height (m)", "props/height", 0.8, 2.1, 0.01, 1.7)
	_slider(look, "Build", "props/build", 0.7, 1.3, 0.01, 1.0)
	_choice(look, "Face", "props/expression", SketchCharacter.EXPRESSIONS, "Neutral")
	_choice(look, "Hair", "props/hair", ["Curl", "Long", "Bob", "Bun", "Short", "Spiky", "Ponytail", "None"], "Curl")
	_check(look, "Fuzzy outline", "props/fuzzy", false)
	var colours := _tab("Colours")
	_colour(colours, "Body / paper", "props/body_color", "#dbe0e6", ["#dbe0e6", "#f4e6cc", "#f2d0b6", "#c68b62", "#8d5a3b", "#ffffff", "#2a2a2e"])
	_colour(colours, "Lines", "props/line_color", "#28282e", ["#28282e", "#3a2a1a", "#1a2a4a", "#6a1a1a"])
	_colour(colours, "Hair", "props/hair_color", "#33210f", HAIR_COLOURS)
	_colour(colours, "Glow (shadow figure)", "props/glow_color", "#ffbf66", ["#ffbf66", "#66c8ff", "#ff6680", "#a0ff80"])
	colours.add_child(_heading("Clothes"))
	_slider(colours, "Shirt colour strength", "props/shirt_color_alpha", 0.0, 1.0, 0.05, 0.0)
	_colour(colours, "Shirt", "props/shirt_color", "#666b75", CLOTH_COLOURS)
	_check(colours, "Long sleeves", "props/long_sleeves", false)
	_slider(colours, "Trousers colour strength", "props/pants_color_alpha", 0.0, 1.0, 0.05, 0.0)
	_colour(colours, "Trousers", "props/pants_color", "#4d546b", CLOTH_COLOURS)
	_slider(colours, "Cap colour strength (0 = no cap)", "props/cap_color_alpha", 0.0, 1.0, 0.05, 0.0)
	_colour(colours, "Cap", "props/cap_color", "#f2bf33", CLOTH_COLOURS)


func _animal_settings() -> void:
	var tab := _tab("Animal")
	_choice(tab, "Animal", "species", AnimalBuilder.SPECIES, "dog", func(s: String) -> String: return AnimalBuilder.label(s))
	var species := str(_spec.get("species", "dog"))
	var info := AnimalBuilder.info(species)
	_slider(tab, "Size", "size", 0.5, 1.6, 0.01, 1.0)
	_slider(tab, "Chubby", "chubby", -1.0, 1.0, 0.02, 0.0)
	_slider(tab, "Age (baby ↔ adult)", "age", 0.3, 1.0, 0.01, 1.0)
	_colour(tab, "Main colour", "color", str(info.get("color", "#8a6a4a")), info.get("colors", []))
	_colour(tab, "Second colour", "color2", str(info.get("color2", "#f0e6d8")), info.get("colors", []))
	_choice(tab, "Pattern", "pattern", AnimalBuilder.patterns_for(species), str(info.get("pattern", "plain")))
	if bool(info.get("fur", true)):
		_slider(tab, "Fur", "fur", 0.0, 1.0, 0.01, float(info.get("fur_amount", 0.5)))
	_colour(tab, "Eyes", "eyes", str(info.get("eyes", "#3a2410")), ["#3a2410", "#c8a030", "#5a8a3a", "#4a6a9a", "#101010"])
	if info.has("extra"):
		for extra in info["extra"]:
			_check(tab, str(extra[1]), str(extra[0]), bool(extra[2]))


# ------------------------------------------------------------------ control helpers

func _get_value(path: String, fallback: Variant) -> Variant:
	var parts := path.split("/")
	var d: Variant = _spec
	for i in parts.size():
		if not (d is Dictionary) or not (d as Dictionary).has(parts[i]):
			return fallback
		d = (d as Dictionary)[parts[i]]
	return d


func _set_value(path: String, value: Variant) -> void:
	var parts := path.split("/")
	var d: Dictionary = _spec
	for i in parts.size() - 1:
		if not (d.get(parts[i]) is Dictionary):
			d[parts[i]] = {}
		d = d[parts[i]]
	if value == null:
		d.erase(parts[parts.size() - 1])
	else:
		d[parts[parts.size() - 1]] = value
	_changed()


func _slider(parent: Control, title: String, path: String, lo: float, hi: float, step: float, fallback: float, fmt: Callable = Callable()) -> void:
	var row := SliderRow.new()
	parent.add_child(row)
	row.setup(title, lo, hi, step, fmt)
	row.set_value(float(_get_value(path, fallback)))
	row.value_edited.connect(func(v: float) -> void: _set_value(path, v))


func _check(parent: Control, title: String, path: String, fallback: bool) -> void:
	var cb := CheckBox.new()
	cb.text = title
	cb.button_pressed = bool(_get_value(path, fallback))
	cb.toggled.connect(func(on: bool) -> void: _set_value(path, on))
	parent.add_child(cb)


func _choice(parent: Control, title: String, path: String, items: Array, fallback: String, nice: Callable = Callable()) -> void:
	var row := HBoxContainer.new()
	var label := _dim(title)
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	var pick := OptionButton.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current := str(_get_value(path, fallback))
	for i in items.size():
		var item := str(items[i])
		pick.add_item(nice.call(item) if nice.is_valid() else str(NICE.get(item, item.capitalize())))
		if item == current:
			pick.select(i)
	pick.item_selected.connect(func(i: int) -> void:
		var v := str(items[i])
		_set_value(path, null if v == "auto" else v)
		if path == "species":
			_spec = {"kind": "animal", "species": v}
			_build_settings())
	row.add_child(pick)
	parent.add_child(row)


func _colour(parent: Control, title: String, path: String, fallback: String, swatches: Array = []) -> void:
	var row := HBoxContainer.new()
	var label := _dim(title)
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(44, 24)
	picker.edit_alpha = false
	picker.color = HumanBuilder.colour(_get_value(path, fallback), Color(fallback))
	picker.color_changed.connect(func(c: Color) -> void: _set_value(path, "#" + c.to_html(false)))
	row.add_child(picker)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 2)
	for s in swatches:
		var b := Button.new()
		b.custom_minimum_size = Vector2(18, 18)
		b.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(str(s))
		sb.set_corner_radius_all(3)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.pressed.connect(func() -> void:
			picker.color = Color(str(s))
			_set_value(path, str(s)))
		flow.add_child(b)
	row.add_child(flow)
	parent.add_child(row)


func _margin(px: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	return m


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	return l


func _dim(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"DimLabel"
	return l


func _wrap(text: String) -> Label:
	var l := _dim(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 0)
	return l


# ------------------------------------------------------------------ preview

func _changed() -> void:
	_busy.text = "Updating…"
	_rebuild_timer.start()


func _rebuild_preview() -> void:
	if _stage == null:
		return
	var t0 := Time.get_ticks_msec()
	var spec := _spec.duplicate(true)
	spec["kind"] = _kind
	var made := CharacterFactory.make(spec)
	if is_instance_valid(_character):
		_character.queue_free()
	_character = made
	if made == null:
		_busy.text = "Couldn't build this character."
		return
	_stage.add_child(made)
	if made.has_method("ensure_built"):
		made.call("ensure_built")
	_fill_actions()
	_apply_preview_motion()
	var first := _target == Vector3(0, 0.95, 0)
	if first or not _same_size():
		_frame("full")
	_busy.text = "Ready (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0)


var _last_height := 0.0

func _same_size() -> bool:
	var h := PropUtils.world_aabb(_character).size.y
	var same := absf(h - _last_height) < 0.08
	_last_height = h
	return same


func _fill_actions() -> void:
	var current := _action_pick.get_item_text(_action_pick.selected) if _action_pick.item_count > 0 and _action_pick.selected >= 0 else "Idle"
	_action_pick.clear()
	var names := PackedStringArray()
	if _character is CharacterBase:
		names = (_character as CharacterBase).action_names()
	var keep := 0
	var i := 0
	for n in names:
		if n == MotionLibrary.AUTO:
			continue
		_action_pick.add_item(n)
		if n == current:
			keep = i
		i += 1
	if _action_pick.item_count > 0:
		_action_pick.select(keep)


func _apply_preview_motion() -> void:
	_motion = CharacterMotion.stationary()
	if _action_pick.item_count > 0:
		_motion.actions = [{"t": 0.0, "action": _action_pick.get_item_text(_action_pick.selected)}]
	if _expr_pick.selected > 0:
		_motion.poses = [{"t": 0.0, "pose": {"face": Vector3(_expr_pick.selected, 0, 0)}}]
	_time = 0.0


func _process(delta: float) -> void:
	if not _active or not is_visible_in_tree():
		return
	_time += delta
	if _turn.button_pressed and not _dragging:
		_yaw += delta * 0.35
	if is_instance_valid(_character) and _character is CharacterBase:
		(_character as CharacterBase).evaluate(_time, _motion)
	_update_camera()


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_distance = maxf(_distance * 0.9, 0.25)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_distance = minf(_distance * 1.1, 14.0)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_target.y = clampf(_target.y + motion.relative.y * 0.004, 0.05, 3.0)
		else:
			_yaw -= motion.relative.x * 0.01
			_pitch = clampf(_pitch - motion.relative.y * 0.006, -1.2, 0.6)


func _update_camera() -> void:
	var offset := Vector3(sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	_camera.look_at_from_position(_target + offset, _target, Vector3.UP)


func _frame(view: String) -> void:
	if not is_instance_valid(_character):
		return
	var box := PropUtils.world_aabb(_character)
	var h := maxf(box.size.y, 0.2)
	var w := maxf(box.size.x, box.size.z)
	_last_height = h
	match view:
		"face":
			if _kind == "animal":
				_target = Vector3(0, box.position.y + h * 0.75, box.end.z - w * 0.2)
				_distance = maxf(h, w) * 0.8
			else:
				_target = Vector3(0, box.position.y + h * 0.93, 0)
				_distance = 0.75 * h / 1.7
			_yaw = 0.0
			_pitch = -0.02
			_turn.button_pressed = false
		"side":
			_target = Vector3(0, box.position.y + h * 0.5, 0)
			_distance = maxf(h, w) * 2.1
			_yaw = PI * 0.5
			_pitch = -0.08
			_turn.button_pressed = false
		_:
			_target = Vector3(0, box.position.y + h * 0.52, 0)
			_distance = maxf(h, w) * 2.0
			_pitch = -0.08
	_update_camera()


# ------------------------------------------------------------------ saving & library

func refresh_mine() -> void:
	if _mine == null:
		return
	_mine.clear()
	_mine_paths.clear()
	var dir := DirAccess.open(RuntimeModelLoader.CHARACTERS_DIR)
	if dir == null:
		return
	var files := Array(dir.get_files())
	files.sort()
	for f in files:
		if not CharacterFactory.is_character_file(f):
			continue
		var path: String = RuntimeModelLoader.CHARACTERS_DIR + f
		var spec := CharacterFactory.load_file(path)
		var kind := str(spec.get("kind", "realistic"))
		_mine.add_item("%s  ·  %s" % [spec.get("name", f.get_basename()), KIND_INFO.get(kind, ["?"])[0]])
		_mine_paths.append(path)
		if path == _path:
			_mine.select(_mine.item_count - 1)


func _save() -> String:
	var title := _name_edit.text.strip_edges()
	if title.is_empty():
		title = _default_name()
		_name_edit.text = title
	var path := _path
	if path.is_empty() or CharacterFactory.display_name(path) != title:
		path = CharacterFactory.path_for(title)
		var n := 2
		while FileAccess.file_exists(path) and path != _path:
			path = CharacterFactory.path_for("%s %d" % [title, n])
			n += 1
	var spec := _spec.duplicate(true)
	spec["kind"] = _kind
	spec["name"] = title
	spec["version"] = 1
	var err := CharacterFactory.save_file(path, spec)
	if err != OK:
		EventBus.error("Couldn't save the character (%s)." % error_string(err))
		return ""
	_path = path
	RuntimeModelLoader.forget(path)
	refresh_mine()
	library_changed.emit()
	EventBus.info("Saved \"%s\" to My characters." % title)
	return path


func _default_name() -> String:
	match _kind:
		"animal":
			return AnimalBuilder.label(str(_spec.get("species", "dog")))
		"cartoon", "sketch":
			return "%s %s" % [KIND_INFO[_kind][0], str(_get_value("props/body_type", "Person"))]
	var g := float(_spec.get("gender", 0.5))
	var age := float(_spec.get("age", 25))
	var who := ("Boy" if g >= 0.5 else "Girl") if age < 13 else (("Man" if g >= 0.5 else "Woman") if age < 60 else ("Old man" if g >= 0.5 else "Old woman"))
	return "%s %s" % ["Film" if _kind == "pixar" else "Real", who]


func _on_place() -> void:
	var path := _save()
	if path.is_empty():
		return
	place_requested.emit({"prop_id": path.get_file().get_basename(), "scene_path": path,
		"display_name": CharacterFactory.display_name(path), "category": PropCatalog.MY_CHARACTERS_CATEGORY})


func _on_copy() -> void:
	_path = ""
	_name_edit.text = (_name_edit.text if not _name_edit.text.is_empty() else _default_name()) + " copy"
	_save()


func _on_delete() -> void:
	var sel := _mine.get_selected_items()
	if sel.is_empty():
		EventBus.info("Pick a character in My characters first.")
		return
	var path := _mine_paths[sel[0]]
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "Delete \"%s\"? Scenes that use it will show it missing." % CharacterFactory.display_name(path)
	confirm.confirmed.connect(func() -> void:
		DirAccess.remove_absolute(path)
		RuntimeModelLoader.forget(path)
		if path == _path:
			_path = ""
		refresh_mine()
		library_changed.emit()
		confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	add_child(confirm)
	confirm.popup_centered()


func _on_random() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match _kind:
		"realistic", "pixar":
			var list := _human_presets(_kind == "pixar")
			_spec = (list[rng.randi() % list.size()][1] as Dictionary).duplicate(true)
			_spec["face_seed"] = rng.randi() % 100000
			_spec["skin"] = SKIN_TONES[rng.randi() % SKIN_TONES.size()]
			_spec["height"] = rng.randf_range(0.2, 0.8)
			_spec["weight"] = rng.randf_range(0.3, 0.7)
			var outfit: Dictionary = _spec.get("outfit", {})
			for slot in ["top", "bottom"]:
				if outfit.has(slot):
					(outfit[slot] as Dictionary)["color"] = CLOTH_COLOURS[rng.randi() % CLOTH_COLOURS.size()]
		"cartoon", "sketch":
			var list := _sketch_presets(_kind)
			_spec = (list[rng.randi() % list.size()][1] as Dictionary).duplicate(true)
			var props: Dictionary = _spec["props"]
			props["hair"] = ["Curl", "Long", "Bob", "Bun", "Short", "Spiky", "Ponytail"][rng.randi() % 7]
			props["shirt_color"] = CLOTH_COLOURS[rng.randi() % CLOTH_COLOURS.size()]
			props["shirt_color_alpha"] = 1.0
			props["expression"] = SketchCharacter.EXPRESSIONS[rng.randi() % SketchCharacter.EXPRESSIONS.size()]
		"animal":
			var s: String = AnimalBuilder.SPECIES[rng.randi() % AnimalBuilder.SPECIES.size()]
			var info := AnimalBuilder.info(s)
			var colors: Array = info.get("colors", [])
			_spec = {"species": s, "size": rng.randf_range(0.85, 1.15)}
			if not colors.is_empty():
				_spec["color"] = colors[rng.randi() % colors.size()]
			var pats := AnimalBuilder.patterns_for(s)
			_spec["pattern"] = pats[rng.randi() % pats.size()]
	_spec["kind"] = _kind
	_path = ""
	_name_edit.text = ""
	_build_settings()
	_rebuild_preview()


# ------------------------------------------------------------------ imported clothes

func _on_import_clothes() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.glb, *.gltf, *.fbx ; Character with clothes (Avaturn, Ready Player Me, Mixamo…)"])
	dialog.title = "Choose a character with clothes"
	dialog.file_selected.connect(func(p: String) -> void:
		dialog.queue_free()
		_import_clothes(p))
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _import_clothes(path: String) -> void:
	_busy.text = "Taking the clothes off…"
	await get_tree().process_frame
	var result := WardrobeItem.import_from(path, _spec)
	if not str(result.get("error", "")).is_empty():
		EventBus.error(str(result["error"]))
		_busy.text = ""
		return
	var saved: Array = result.get("items", [])
	EventBus.info("Imported %d piece(s) of clothing: %s" % [saved.size(), ", ".join(saved.map(func(e: Dictionary) -> String: return str(e["name"])))])
	# Wear them right away (replacing the built-in piece of the same slot).
	var outfit: Dictionary = _spec.get("outfit", {})
	var extra: Array = outfit.get("extra", [])
	for e in saved:
		if not extra.has(e["path"]):
			extra.append(e["path"])
	outfit["extra"] = extra
	_spec["outfit"] = outfit
	_build_settings()
	_tabs.current_tab = 4 if _tabs.get_tab_count() > 4 else 0
	_rebuild_preview()

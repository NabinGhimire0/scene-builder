class_name Room
extends ProceduralProp
## A room you can film in: floor, walls, ceiling, windows and a doorway, any
## size. The wall facing the camera can be left out (like a film set).

const FLOORS: PackedStringArray = ["Wood planks", "Tiles", "Carpet", "Concrete", "Plain"]
const FLOOR_SHADER := preload("res://assets/materials/room_floor.gdshader")
const WALL := 0.15

@export var width := 8.0:
	set(v):
		width = clampf(v, 2.0, 40.0)
		_changed(true)
@export var depth := 7.0:
	set(v):
		depth = clampf(v, 2.0, 40.0)
		_changed(true)
@export var height := 3.0:
	set(v):
		height = clampf(v, 2.2, 12.0)
		_changed(true)
@export var floor_style := "Wood planks":
	set(v):
		floor_style = v if FLOORS.has(v) else "Wood planks"
		_changed()
@export var floor_color := Color(0.55, 0.38, 0.22):
	set(v):
		floor_color = v
		_changed()
@export var wall_color := Color(0.88, 0.86, 0.8):
	set(v):
		wall_color = v
		_changed()
@export var lower_wall_color := Color(0.88, 0.86, 0.8):
	set(v):
		lower_wall_color = v
		_changed()
@export var windows := 2:
	set(v):
		windows = clampi(v, 0, 8)
		_changed(true)
@export var doorway := true:
	set(v):
		doorway = v
		_changed(true)
@export var ceiling := true:
	set(v):
		ceiling = v
		_changed(true)
@export var front_wall := false:
	set(v):
		front_wall = v
		_changed(true)

var _parts: Array[Node] = []
var _floor_material: ShaderMaterial
var _wall_material: ShaderMaterial
var _lower_material: ShaderMaterial


func inspector_title() -> String:
	return "Room"


func inspector_fields() -> Array:
	return [
		{"type": "float", "property": "width", "label": "Width", "min": 2.0, "max": 40.0, "step": 0.1, "suffix": " m"},
		{"type": "float", "property": "depth", "label": "Depth", "min": 2.0, "max": 40.0, "step": 0.1, "suffix": " m"},
		{"type": "float", "property": "height", "label": "Ceiling height", "min": 2.2, "max": 12.0, "step": 0.1, "suffix": " m"},
		{"type": "option", "property": "floor_style", "label": "Floor", "items": FLOORS},
		{"type": "color", "property": "floor_color", "label": "Floor colour"},
		{"type": "color", "property": "wall_color", "label": "Wall colour"},
		{"type": "color", "property": "lower_wall_color", "label": "Lower wall colour", "hint": "Paint the bottom metre a different colour (like a dado)"},
		{"type": "int", "property": "windows", "label": "Windows (left wall)", "min": 0, "max": 8, "step": 1, "suffix": ""},
		{"type": "bool", "property": "doorway", "label": "Doorway (right wall)"},
		{"type": "bool", "property": "ceiling", "label": "Ceiling"},
		{"type": "bool", "property": "front_wall", "label": "Front wall", "hint": "Off = open side for the camera, like a film set"},
	]


func _build() -> void:
	_floor_material = _material(0)
	_wall_material = _material(4)
	_lower_material = _material(4)
	_rebuild()


func _settings_changed(geometry: bool) -> void:
	if geometry:
		_rebuild()
	else:
		_update()


func _material(pattern: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FLOOR_SHADER
	material.set_shader_parameter("pattern", pattern)
	return material


func _update() -> void:
	_floor_material.set_shader_parameter("pattern", FLOORS.find(floor_style))
	_floor_material.set_shader_parameter("color_a", floor_color)
	_floor_material.set_shader_parameter("color_b", floor_color.darkened(0.18))
	_wall_material.set_shader_parameter("color_a", wall_color)
	_lower_material.set_shader_parameter("color_a", lower_wall_color)


func _rebuild() -> void:
	for part in _parts:
		part.queue_free()
	_parts.clear()
	var hw := width * 0.5
	var hd := depth * 0.5
	# Top at +2.5 cm: just above the outdoor ground plane (1.2 cm), so grass never shows through.
	_box("Floor", Vector3(0, -0.025, 0), Vector3(width + WALL * 2.0, 0.1, depth + WALL * 2.0), _floor_material)
	if ceiling:
		_box("Ceiling", Vector3(0, height + 0.05, 0), Vector3(width + WALL * 2.0, 0.1, depth + WALL * 2.0), _wall_material)
	# Back wall (-Z) full; front wall (+Z) optional.
	_wall_along_x("Back", -hd - WALL * 0.5, [])
	if front_wall:
		_wall_along_x("Front", hd + WALL * 0.5, [])
	# Left wall (-X) with windows, right wall (+X) with a doorway.
	var openings: Array = []
	for i in windows:
		var centre := lerpf(-hd, hd, (float(i) + 0.5) / float(windows))
		openings.append([centre, 1.4, 0.9, 2.2])
	_wall_along_z("Left", -hw - WALL * 0.5, openings, true)
	_wall_along_z("Right", hw + WALL * 0.5, [[hd * 0.5, 1.0, 0.0, 2.1]] if doorway else [], false)
	_update()


## A wall running along Z at x, with [centre z, width, bottom, top] openings.
func _wall_along_z(label: String, x: float, openings: Array, glass: bool) -> void:
	var hd := depth * 0.5
	var cursor := -hd
	openings.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for opening in openings:
		var start := float(opening[0]) - float(opening[1]) * 0.5
		var end := float(opening[0]) + float(opening[1]) * 0.5
		_wall_piece("%sWall" % label, Vector3(x, 0, (cursor + start) * 0.5), Vector3(WALL, height, start - cursor), 0.0)
		var bottom := float(opening[2])
		var top := float(opening[3])
		if bottom > 0.0:
			_wall_piece("%sSill" % label, Vector3(x, 0, opening[0]), Vector3(WALL, bottom, opening[1]), 0.0)
		_box("%sHeader" % label, Vector3(x, (top + height) * 0.5, opening[0]), Vector3(WALL, height - top, opening[1]), _wall_material)
		if glass:
			var pane := _box("%sGlass" % label, Vector3(x, (bottom + top) * 0.5, opening[0]), Vector3(0.02, top - bottom, opening[1]), _glass())
			pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cursor = end
	_wall_piece("%sWall" % label, Vector3(x, 0, (cursor + hd) * 0.5), Vector3(WALL, height, hd - cursor), 0.0)


func _wall_along_x(label: String, z: float, _openings: Array) -> void:
	_wall_piece("%sWall" % label, Vector3(0, 0, z), Vector3(width + WALL * 2.0, height, WALL), 0.0)


## A wall segment from the floor up, with the lower metre in its own colour.
func _wall_piece(label: String, at: Vector3, size: Vector3, _unused: float) -> void:
	if size.x <= 0.01 or size.z <= 0.01 or size.y <= 0.01:
		return
	var lower := minf(1.0, size.y)
	_box(label + "Lower", Vector3(at.x, lower * 0.5, at.z), Vector3(size.x, lower, size.z), _lower_material)
	if size.y > lower:
		_box(label + "Upper", Vector3(at.x, lower + (size.y - lower) * 0.5, at.z), Vector3(size.x, size.y - lower, size.z), _wall_material)


func _box(label: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance, true)
	_parts.append(instance)
	if material != null and not (material is StandardMaterial3D and (material as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED):
		var body := StaticBody3D.new()
		body.collision_layer = Layers.PROPS
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		instance.add_child(body)
	return instance


static func _glass() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.82, 0.9, 0.18)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.03
	material.metallic = 0.2
	return material

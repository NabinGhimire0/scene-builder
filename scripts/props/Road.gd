class_name Road
extends ProceduralProp
## A straight road with lane markings, kerbs and pavements; optional zebra
## crossing. Gets wet and shiny in the rain.

const SHADER := preload("res://assets/materials/road.gdshader")

@export var length := 40.0:
	set(v):
		length = clampf(v, 4.0, 400.0)
		_changed(true)
@export var lanes := 2:
	set(v):
		lanes = clampi(v, 1, 6)
		_changed(true)
@export var pavement := 3.0:
	set(v):
		pavement = clampf(v, 0.0, 10.0)
		_changed(true)
@export var crossing := true:
	set(v):
		crossing = v
		_changed()

var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _collision: CollisionShape3D


func inspector_title() -> String:
	return "Road"


func inspector_fields() -> Array:
	return [
		{"type": "float", "property": "length", "label": "Length", "min": 4.0, "max": 400.0, "step": 1.0, "suffix": " m"},
		{"type": "int", "property": "lanes", "label": "Lanes", "min": 1, "max": 6, "step": 1, "suffix": ""},
		{"type": "float", "property": "pavement", "label": "Pavement width", "min": 0.0, "max": 10.0, "step": 0.1, "suffix": " m"},
		{"type": "bool", "property": "crossing", "label": "Zebra crossing in the middle"},
	]


func road_width() -> float:
	return 3.5 * float(lanes)


func _build() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_mesh = MeshInstance3D.new()
	_mesh.name = "Surface"
	_mesh.material_override = _material
	_mesh.position.y = 0.03
	add_child(_mesh)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.PROPS
	body.collision_mask = 0
	_collision = CollisionShape3D.new()
	body.add_child(_collision)
	add_child(body)
	_settings_changed(true)


func _settings_changed(geometry: bool) -> void:
	var total := road_width() + pavement * 2.0
	if geometry:
		_mesh.mesh = WaterStyle.grid_mesh(WaterStyle.spaced(-total * 0.5, total * 0.5, 2), WaterStyle.spaced(-length * 0.5, length * 0.5, 2))
		var shape := BoxShape3D.new()
		shape.size = Vector3(total, 0.06, length)
		_collision.shape = shape
		_collision.position = Vector3(0, 0.0, 0)
	_material.set_shader_parameter("road_width", road_width())
	_material.set_shader_parameter("pavement", pavement)
	_material.set_shader_parameter("lanes", lanes)
	_material.set_shader_parameter("crossing_at", 0.0 if crossing else -99999.0)

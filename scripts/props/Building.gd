class_name Building
extends ProceduralProp
## A city building of any size: windows on every side (lit at night), a roof
## edge and a ground-floor entrance band.

const SHADER := preload("res://assets/materials/facade.gdshader")
const STYLES := {
	"Glass tower": {"wall": Color(0.32, 0.36, 0.4), "glass": Color(0.1, 0.16, 0.22), "ratio": 0.92, "window": 1.5},
	"Office": {"wall": Color(0.62, 0.62, 0.6), "glass": Color(0.12, 0.17, 0.22), "ratio": 0.7, "window": 1.6},
	"Apartment": {"wall": Color(0.78, 0.7, 0.58), "glass": Color(0.15, 0.18, 0.2), "ratio": 0.45, "window": 2.4},
	"Brick": {"wall": Color(0.5, 0.26, 0.2), "glass": Color(0.12, 0.14, 0.16), "ratio": 0.4, "window": 2.2},
	"Concrete": {"wall": Color(0.5, 0.5, 0.49), "glass": Color(0.1, 0.12, 0.14), "ratio": 0.55, "window": 2.0},
}
const FLOOR_HEIGHT := 3.2

@export var style := "Office":
	set(v):
		style = v if STYLES.has(v) else "Office"
		_changed()
@export var floors := 8:
	set(v):
		floors = clampi(v, 1, 80)
		_changed(true)
@export var width := 16.0:
	set(v):
		width = clampf(v, 4.0, 80.0)
		_changed(true)
@export var depth := 14.0:
	set(v):
		depth = clampf(v, 4.0, 80.0)
		_changed(true)
@export var variation := 0:
	set(v):
		variation = v
		_changed()

var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _collision: CollisionShape3D


func inspector_title() -> String:
	return "Building"


func inspector_fields() -> Array:
	return [
		{"type": "option", "property": "style", "label": "Style", "items": PackedStringArray(STYLES.keys())},
		{"type": "int", "property": "floors", "label": "Floors", "min": 1, "max": 80, "step": 1, "suffix": ""},
		{"type": "float", "property": "width", "label": "Width", "min": 4.0, "max": 80.0, "step": 0.5, "suffix": " m"},
		{"type": "float", "property": "depth", "label": "Depth", "min": 4.0, "max": 80.0, "step": 0.5, "suffix": " m"},
		{"type": "int", "property": "variation", "label": "Lit windows pattern", "min": 0, "max": 99, "step": 1, "suffix": ""},
	]


func _build() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_mesh = MeshInstance3D.new()
	_mesh.name = "Facade"
	_mesh.material_override = _material
	add_child(_mesh)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.PROPS
	body.collision_mask = 0
	_collision = CollisionShape3D.new()
	body.add_child(_collision)
	add_child(body)
	_settings_changed(true)


func _settings_changed(geometry: bool) -> void:
	var height := float(floors) * FLOOR_HEIGHT
	if geometry:
		_mesh.mesh = _box_mesh(Vector3(width, height, depth))
		var shape := BoxShape3D.new()
		shape.size = Vector3(width, height, depth)
		_collision.shape = shape
		_collision.position = Vector3(0, height * 0.5, 0)
	var s: Dictionary = STYLES[style]
	_material.set_shader_parameter("wall_color", s["wall"])
	_material.set_shader_parameter("glass_color", s["glass"])
	_material.set_shader_parameter("glass_ratio", s["ratio"])
	_material.set_shader_parameter("window_width", s["window"])
	_material.set_shader_parameter("floor_height", FLOOR_HEIGHT)
	_material.set_shader_parameter("seed", float(variation) * 3.17)


## A box whose side faces have UVs in metres (x along the face, y up), so the
## window grid keeps its real size on any building.
static func _box_mesh(size: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var h := size.y
	var faces := [
		[Vector3(-hx, 0, hz), Vector3(hx, 0, hz), Vector3(0, 0, 1), size.x],
		[Vector3(hx, 0, hz), Vector3(hx, 0, -hz), Vector3(1, 0, 0), size.z],
		[Vector3(hx, 0, -hz), Vector3(-hx, 0, -hz), Vector3(0, 0, -1), size.x],
		[Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz), Vector3(-1, 0, 0), size.z],
	]
	for face in faces:
		var a: Vector3 = face[0]
		var b: Vector3 = face[1]
		var n: Vector3 = face[2]
		var w: float = face[3]
		var corners := [[a, Vector2(0, 0)], [b, Vector2(w, 0)], [b + Vector3(0, h, 0), Vector2(w, h)],
			[a, Vector2(0, 0)], [b + Vector3(0, h, 0), Vector2(w, h)], [a + Vector3(0, h, 0), Vector2(0, h)]]
		for corner in corners:
			st.set_normal(n)
			st.set_uv(corner[1])
			st.add_vertex(corner[0])
	# Flat roof.
	var roof := [Vector3(-hx, h, -hz), Vector3(hx, h, -hz), Vector3(hx, h, hz), Vector3(-hx, h, -hz), Vector3(hx, h, hz), Vector3(-hx, h, hz)]
	for p in roof:
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(-1, -1))
		st.add_vertex(p)
	return st.commit()

class_name WaterFeature
extends ProceduralProp
## Common base of ponds/lakes ([WaterBody]), rivers ([River]) and the sea
## ([Coast]): the water surface, its wet bank and a collider so it can be
## selected (and boats or other objects can be put on the water).
##
## Subclasses describe their shape: [method _shape_id], [method _size_metres],
## [method _water_mesh], [method _bank_mesh] and optionally the flow speed.

@export var look := "Clear lake":
	set(v):
		look = v
		_changed()
@export var shallow_color := Color(0.32, 0.58, 0.55):
	set(v):
		shallow_color = v
		_changed()
@export var deep_color := Color(0.03, 0.13, 0.17):
	set(v):
		deep_color = v
		_changed()
## Metres you can see into the water.
@export var clarity := 2.5:
	set(v):
		clarity = clampf(v, 0.1, 12.0)
		_changed()
@export var depth := 3.0:
	set(v):
		depth = clampf(v, 0.2, 60.0)
		_changed()
@export var wave_height := 0.03:
	set(v):
		wave_height = clampf(v, 0.0, 3.0)
		_changed()
@export var wave_length := 3.0:
	set(v):
		wave_length = clampf(v, 0.5, 80.0)
		_changed()
@export var wave_speed := 1.0:
	set(v):
		wave_speed = clampf(v, 0.0, 4.0)
		_changed()
@export var ripple_size := 1.0:
	set(v):
		ripple_size = clampf(v, 0.1, 6.0)
		_changed()
@export var ripple_strength := 0.6:
	set(v):
		ripple_strength = clampf(v, 0.0, 2.0)
		_changed()
@export var foam := 0.5:
	set(v):
		foam = clampf(v, 0.0, 1.0)
		_changed()
@export var show_bank := true:
	set(v):
		show_bank = v
		_changed()
@export var bank_width := 1.5:
	set(v):
		bank_width = clampf(v, 0.2, 40.0)
		_changed(true)
@export var shore := "Mud":
	set(v):
		shore = v
		_changed()
@export var bank_wet := Color(0.16, 0.12, 0.08):
	set(v):
		bank_wet = v
		_changed()
@export var bank_dry := Color(0.36, 0.3, 0.21):
	set(v):
		bank_dry = v
		_changed()
@export var bank_bed := Color(0.28, 0.24, 0.17):
	set(v):
		bank_bed = v
		_changed()
@export var variation := 0:
	set(v):
		variation = v
		_changed()
## Depth from the real ground under the water (after carving into terrain)
## instead of the depth estimated from the shape.
@export var real_depth := false:
	set(v):
		real_depth = v
		_changed()

var _water: MeshInstance3D
var _bank: MeshInstance3D
var _body: StaticBody3D
var _collision: CollisionShape3D
var _water_material: ShaderMaterial
var _bank_material: ShaderMaterial


# --- Subclass interface -------------------------------------------------------

## 0 natural, 1 round, 2 rectangle, 3 river, 4 coast (see water_common.gdshaderinc).
func _shape_id() -> int:
	return 0


func _size_metres() -> Vector2:
	return Vector2(10.0, 10.0)


func _water_mesh() -> ArrayMesh:
	return null


func _bank_mesh() -> ArrayMesh:
	return null


func _flow_speed() -> float:
	return 0.0


func _shore_waves() -> float:
	return 0.0


## Metres from the edge to full depth.
func _shelf() -> float:
	var s := _size_metres()
	return clampf(minf(s.x, s.y) * 0.18, 0.4, 25.0)


## Box collider instead of the exact surface (for very large water).
func _simple_collider() -> bool:
	return false


## Area covered by the box collider (when [method _simple_collider]).
func _collider_box(water_mesh: ArrayMesh) -> AABB:
	return water_mesh.get_aabb()


func _shape_fields() -> Array:
	return []


# --- Settings -----------------------------------------------------------------

func inspector_title() -> String:
	return "Water"


func inspector_fields() -> Array:
	var fields: Array = _shape_fields()
	fields.append_array([
		{"type": "action", "label": "Carve Into Terrain", "method": "carve_into_terrain",
			"hint": "Dig the bed and shore into the terrain to fit this water (undoable). Do this after placing and sizing it."},
		{"type": "bool", "property": "real_depth", "label": "Use real ground depth",
			"hint": "On after carving: depth, shore foam and colour come from the actual ground"},
		{"type": "header", "label": "Water look"},
		{"type": "preset", "property": "look", "label": "Look", "presets": WaterStyle.LOOKS,
			"hint": "Ready-made colours and clearness; fine-tune them below"},
		{"type": "color", "property": "shallow_color", "label": "Shallow colour"},
		{"type": "color", "property": "deep_color", "label": "Deep colour"},
		{"type": "float", "property": "clarity", "label": "Clearness", "min": 0.1, "max": 12.0, "step": 0.05, "suffix": " m",
			"hint": "How far you can see into the water"},
		{"type": "float", "property": "depth", "label": "Depth", "min": 0.2, "max": 60.0, "step": 0.1, "suffix": " m"},
		{"type": "header", "label": "Movement"},
		{"type": "float", "property": "wave_height", "label": "Wave height", "min": 0.0, "max": 3.0, "step": 0.01, "suffix": " m"},
		{"type": "float", "property": "wave_length", "label": "Wave length", "min": 0.5, "max": 80.0, "step": 0.1, "suffix": " m"},
		{"type": "float", "property": "wave_speed", "label": "Wave speed", "min": 0.0, "max": 4.0, "step": 0.05, "suffix": "×"},
		{"type": "float", "property": "ripple_size", "label": "Ripple size", "min": 0.1, "max": 6.0, "step": 0.05, "suffix": "×"},
		{"type": "float", "property": "ripple_strength", "label": "Ripple strength", "min": 0.0, "max": 2.0, "step": 0.05, "suffix": "×"},
		{"type": "float", "property": "foam", "label": "Foam", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": ""},
		{"type": "header", "label": "Bank"},
		{"type": "bool", "property": "show_bank", "label": "Show wet bank / bed"},
		{"type": "preset", "property": "shore", "label": "Bank type", "presets": WaterStyle.SHORES},
		{"type": "float", "property": "bank_width", "label": "Bank width", "min": 0.2, "max": 40.0, "step": 0.1, "suffix": " m"},
		{"type": "color", "property": "bank_wet", "label": "Wet edge"},
		{"type": "color", "property": "bank_dry", "label": "Dry edge"},
		{"type": "color", "property": "bank_bed", "label": "Water bed"},
	])
	return fields


# --- Shape queries & terrain ---------------------------------------------------

## Metres to the water's edge at a local (x, z) point; positive inside.
## Same maths as water_common.gdshaderinc.
func edge_at_local(p: Vector2) -> float:
	return water_edge(p, _shape_id(), _size_metres(), float(variation) * 1.731)


## Water depth at [param edge] metres from the shore (shape-based estimate).
func depth_profile(edge: float) -> float:
	return depth * (1.0 - exp(-maxf(edge, 0.0) / maxf(_shelf(), 0.05)))


static func water_edge(p: Vector2, kind: int, dims: Vector2, variant: float) -> float:
	if kind == 2:
		var d := dims * 0.5 - p.abs()
		return minf(d.x, d.y)
	if kind == 3:
		var half_width := dims.x * 0.5
		var along := minf(p.y, dims.y - p.y)
		if along < half_width:
			return half_width - Vector2(p.x, half_width - along).length()
		return half_width - absf(p.x)
	if kind == 4:
		var wobble := sin(p.x * 0.031 + variant) * 4.0 + sin(p.x * 0.077 + variant * 2.3) * 1.6 + sin(p.x * 0.19 + variant * 3.1) * 0.5
		return p.y - wobble
	var radii := Vector2(maxf(dims.x * 0.5, 0.05), maxf(dims.y * 0.5, 0.05))
	var r := (p / radii).length()
	var bound := 1.0
	if kind == 0:
		var a := atan2(p.y, p.x)
		bound = (1.0 + 0.10 * sin(3.0 * a + variant) + 0.06 * sin(5.0 * a + variant * 2.1) + 0.035 * sin(8.0 * a + variant * 4.3)) / 1.2
	return (bound - r) * minf(radii.x, radii.y)


## Inspector button: digs the terrain to fit this water, as one undoable step.
func carve_into_terrain(history: EditorHistory) -> void:
	var terrain := get_tree().get_first_node_in_group(&"terrain") as Terrain
	if terrain == null:
		EventBus.error("No terrain in this scene.")
		return
	var before := {"terrain": terrain.snapshot(), "real_depth": real_depth}
	terrain.carve_for(self)
	var after := {"terrain": terrain.snapshot(), "real_depth": true}
	history.record_snapshot("Carve %s into terrain" % name, _apply_carve_state.bind(terrain), before, after)
	EventBus.info("Carved %s into the terrain. Sculpt or Smooth the banks to taste." % name)


func _apply_carve_state(state: Dictionary, terrain: Terrain) -> void:
	if is_instance_valid(terrain):
		terrain.restore(state["terrain"])
	real_depth = bool(state["real_depth"])


# --- Building -----------------------------------------------------------------

func _build() -> void:
	_water_material = WaterStyle.new_water_material()
	_bank_material = WaterStyle.new_bank_material()
	_bank = MeshInstance3D.new()
	_bank.name = "Bank"
	_bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bank.material_override = _bank_material
	add_child(_bank)
	_water = MeshInstance3D.new()
	_water.name = "Water"
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.material_override = _water_material
	add_child(_water)
	_body = StaticBody3D.new()
	_body.name = "WaterCollider"
	_body.collision_layer = Layers.PROPS
	_body.collision_mask = 0
	_collision = CollisionShape3D.new()
	_body.add_child(_collision)
	add_child(_body)
	_rebuild_geometry()
	_update_material()


func _settings_changed(geometry: bool) -> void:
	if geometry:
		_rebuild_geometry()
	_update_material()


func _rebuild_geometry() -> void:
	var water_mesh := _water_mesh()
	_water.mesh = water_mesh
	_bank.mesh = _bank_mesh()
	if water_mesh == null:
		_collision.shape = null
		return
	if _simple_collider():
		var box := _collider_box(water_mesh)
		var shape := BoxShape3D.new()
		shape.size = Vector3(maxf(box.size.x, 0.1), 0.1, maxf(box.size.z, 0.1))
		_collision.shape = shape
		_collision.position = Vector3(box.get_center().x, -0.05, box.get_center().z)
	else:
		_collision.shape = water_mesh.create_trimesh_shape()
		_collision.position = Vector3.ZERO


func _update_material() -> void:
	if _water_material == null:
		return
	var size := _size_metres()
	var seed_value := float(variation) * 1.731
	for material in [_water_material, _bank_material]:
		material.set_shader_parameter("shape", _shape_id())
		material.set_shader_parameter("size_m", size)
		material.set_shader_parameter("seed", seed_value)
	_water_material.set_shader_parameter("shallow_color", shallow_color)
	_water_material.set_shader_parameter("deep_color", deep_color)
	_water_material.set_shader_parameter("clarity", clarity)
	_water_material.set_shader_parameter("depth_m", depth)
	_water_material.set_shader_parameter("shelf", _shelf())
	_water_material.set_shader_parameter("wave_height", wave_height)
	_water_material.set_shader_parameter("wave_length", wave_length)
	_water_material.set_shader_parameter("wave_speed", wave_speed)
	_water_material.set_shader_parameter("ripple_size", ripple_size)
	_water_material.set_shader_parameter("ripple_strength", ripple_strength)
	_water_material.set_shader_parameter("flow_speed", _flow_speed())
	_water_material.set_shader_parameter("flowing", _shape_id() == 3)
	_water_material.set_shader_parameter("foam_amount", foam)
	_water_material.set_shader_parameter("shore_waves", _shore_waves())
	_water_material.set_shader_parameter("wind_dir", Vector2(0.8, 0.6))
	_bank_material.set_shader_parameter("bank_width", bank_width)
	_bank_material.set_shader_parameter("wet_color", bank_wet)
	_bank_material.set_shader_parameter("dry_color", bank_dry)
	_bank_material.set_shader_parameter("bed_color", bank_bed)
	_bank.visible = show_bank
	_water_material.set_shader_parameter("use_scene_depth", real_depth)
	_water_material.set_shader_parameter("view_bias", 0.9985 if real_depth else 0.996)
	_bank_material.set_shader_parameter("carved", real_depth)
	_water.position.y = 0.02
	_body.position.y = 0.02 + wave_height * 0.75

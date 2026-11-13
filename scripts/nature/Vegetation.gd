class_name Vegetation
extends Node3D
## Painted plants: grass, flowers, bushes, trees and rocks, thousands at a time.
## Each kind is one MultiMesh (fast to draw); plants sway in the global wind,
## settle onto the terrain, and are saved with the project. Undo per stroke.

const SHADER := preload("res://assets/materials/foliage.gdshader")
const KINDS: PackedStringArray = ["Grass", "Tall grass", "Flowers", "Bushes", "Broadleaf trees", "Pine trees", "Rocks"]
## Per kind: plants per m² at full strength, min spacing (m), scale range,
## wind sway, stiffness, shadows, fade-out distance (0 = never).
const SETTINGS := {
	"Grass": {"density": 14.0, "spacing": 0.0, "scale": Vector2(0.7, 1.3), "sway": 1.0, "stiffness": 1.6, "shadow": false, "range": 70.0},
	"Tall grass": {"density": 6.0, "spacing": 0.0, "scale": Vector2(0.8, 1.25), "sway": 1.2, "stiffness": 1.5, "shadow": false, "range": 90.0},
	"Flowers": {"density": 4.0, "spacing": 0.0, "scale": Vector2(0.8, 1.3), "sway": 1.0, "stiffness": 1.6, "shadow": false, "range": 70.0},
	"Bushes": {"density": 0.35, "spacing": 1.4, "scale": Vector2(0.7, 1.5), "sway": 0.35, "stiffness": 2.0, "shadow": true, "range": 0.0},
	"Broadleaf trees": {"density": 0.05, "spacing": 5.0, "scale": Vector2(0.75, 1.35), "sway": 0.3, "stiffness": 3.0, "shadow": true, "range": 0.0},
	"Pine trees": {"density": 0.06, "spacing": 4.0, "scale": Vector2(0.7, 1.4), "sway": 0.25, "stiffness": 3.0, "shadow": true, "range": 0.0},
	"Rocks": {"density": 0.4, "spacing": 0.8, "scale": Vector2(0.4, 2.2), "sway": 0.0, "stiffness": 1.0, "shadow": true, "range": 0.0},
}
const FLOWER_COLORS: Array[Color] = [
	Color(0.85, 0.15, 0.15), Color(0.95, 0.8, 0.15), Color(0.95, 0.95, 0.95), Color(0.6, 0.3, 0.8), Color(0.95, 0.5, 0.15), Color(0.9, 0.45, 0.65)]
const STRIDE := 6   # x, y, z, rotation, scale, variant

## Plant data per kind: PackedFloat32Array of STRIDE floats per plant.
var plants: Dictionary = {}

signal kinds_changed

const MODEL_PREFIX := "model:"

var _instances: Dictionary = {}   # kind -> MultiMeshInstance3D
var _custom: Dictionary = {}      # kind -> { "title", "settings" } for model brushes
var _dirty: Dictionary = {}       # kind -> true
var _rng := RandomNumberGenerator.new()
var _terrain: Terrain


func _ready() -> void:
	add_to_group(&"vegetation")
	_rng.randomize()
	for kind in KINDS:
		plants[kind] = PackedFloat32Array()
		var settings: Dictionary = SETTINGS[kind]
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("sway", settings["sway"])
		material.set_shader_parameter("stiffness", settings["stiffness"])
		material.set_shader_parameter("plant_height", PlantMeshes.height_of(kind))
		material.set_shader_parameter("translucency", {"Rocks": 0.0, "Grass": 0.16, "Tall grass": 0.2, "Flowers": 0.06}.get(kind, 0.3))
		material.set_shader_parameter("bury_in_snow", {"Grass": 0.92, "Tall grass": 0.7, "Flowers": 0.95, "Bushes": 0.5}.get(kind, 0.0))
		material.set_shader_parameter("roughness_value", 0.95 if kind == "Rocks" else 0.8)
		material.set_shader_parameter("stone", 1.0 if kind == "Rocks" else 0.0)
		material.set_shader_parameter("autumn_response", {"Pine trees": 0.12, "Rocks": 0.0, "Flowers": 0.5, "Grass": 0.75, "Tall grass": 0.85}.get(kind, 1.0))
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = PlantMeshes.build(kind)
		var instance := MultiMeshInstance3D.new()
		instance.name = kind.to_pascal_case()
		instance.multimesh = multimesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if settings["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var fade_at := float(settings["range"])
		if fade_at > 0.0:
			instance.visibility_range_end = fade_at
			instance.visibility_range_end_margin = fade_at * 0.15
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(instance)
		_instances[kind] = instance
	_terrain = get_tree().get_first_node_in_group(&"terrain") as Terrain
	if _terrain:
		_terrain.stroke_finished.connect(resettle)


func _process(_delta: float) -> void:
	if _dirty.is_empty():
		return
	for kind in _dirty.keys():
		_rebuild(kind)
	_dirty.clear()


func count(kind: String = "") -> int:
	if not kind.is_empty():
		return (plants[kind] as PackedFloat32Array).size() / STRIDE
	var total := 0
	for k in plants.keys():
		total += (plants[k] as PackedFloat32Array).size() / STRIDE
	return total


# --- Model brushes ---------------------------------------------------------------

## Lets any library model (e.g. a Poly Haven plant or rock) be painted like
## the built-in plants. Returns its kind key ("model:<path>"), or "".
func add_model_kind(path: String) -> String:
	var key := MODEL_PREFIX + path
	if plants.has(key):
		return key
	var scene := PropUtils.load_prop_scene(path)
	if scene == null:
		return ""
	var root := scene.instantiate()
	var mesh := ArrayMesh.new()
	if root is Node3D:
		_merge_meshes(root as Node3D, root as Node3D, mesh)
	root.free()
	if mesh.get_surface_count() == 0:
		EventBus.error("%s has no meshes to paint with." % path.get_file())
		return ""
	var box := mesh.get_aabb()
	var footprint := maxf(box.size.x * box.size.z, 0.01)
	var settings := {"density": clampf(0.5 / footprint, 0.01, 40.0), "spacing": maxf(box.size.x, box.size.z) * 0.6,
		"scale": Vector2(0.8, 1.2), "shadow": box.size.y > 0.6, "range": 0.0 if box.size.y > 1.5 else 90.0}
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	var instance := MultiMeshInstance3D.new()
	instance.name = "Model_%d" % _custom.size()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if settings["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if float(settings["range"]) > 0.0:
		instance.visibility_range_end = settings["range"]
		instance.visibility_range_end_margin = 12.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(instance)
	_instances[key] = instance
	_custom[key] = {"title": path.get_file().get_basename().capitalize(), "settings": settings}
	plants[key] = PackedFloat32Array()
	kinds_changed.emit()
	return key


## Display name for a kind (built-in name, or the model's name).
func title_of(kind: String) -> String:
	return str(_custom[kind]["title"]) if _custom.has(kind) else kind


func model_kinds() -> PackedStringArray:
	return PackedStringArray(_custom.keys())


## The mesh used for a kind (for exporting).
func mesh_for(kind: String) -> Mesh:
	var instance: MultiMeshInstance3D = _instances.get(kind)
	return instance.multimesh.mesh if instance else null


func is_model_kind(kind: String) -> bool:
	return _custom.has(kind)


func _settings_for(kind: String) -> Dictionary:
	return _custom[kind]["settings"] if _custom.has(kind) else SETTINGS[kind]


func _merge_meshes(node: Node3D, root: Node3D, into: ArrayMesh) -> void:
	for child in node.get_children():
		if child is Node3D:
			_merge_meshes(child as Node3D, root, into)
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.skin != null:
		return
	var xform := Transform3D.IDENTITY
	var current: Node = mesh_instance
	while current != null and current != root:
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	for i in mesh_instance.mesh.get_surface_count():
		var st := SurfaceTool.new()
		st.append_from(mesh_instance.mesh, i, xform)
		st.commit(into)
		var material: Material = mesh_instance.get_surface_override_material(i)
		if material == null:
			material = mesh_instance.mesh.surface_get_material(i)
		if mesh_instance.material_override:
			material = mesh_instance.material_override
		into.surface_set_material(into.get_surface_count() - 1, material)


# --- Painting ------------------------------------------------------------------

## Adds plants of [param kind] inside a circle. [param strength] 0..1,
## [param delta] seconds since the last dab.
func paint(kind: String, centre: Vector3, radius: float, strength: float, delta: float) -> void:
	var settings: Dictionary = _settings_for(kind)
	var area := PI * radius * radius
	var wanted := float(settings["density"]) * area * strength * delta * 0.6
	var n := int(wanted) + (1 if _rng.randf() < fmod(wanted, 1.0) else 0)
	if n <= 0:
		return
	var data: PackedFloat32Array = plants[kind]
	var spacing := float(settings["spacing"])
	var scale_range: Vector2 = settings["scale"]
	for i in n:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * radius
		var x := centre.x + cos(a) * r
		var z := centre.z + sin(a) * r
		if spacing > 0.0 and _too_close(data, x, z, spacing):
			continue
		var variant := float(_rng.randi_range(0, FLOWER_COLORS.size() - 1)) + _rng.randf() * 0.5
		data.append_array([x, _ground_y(x, z), z, _rng.randf() * TAU, _rng.randf_range(scale_range.x, scale_range.y), variant])
	plants[kind] = data
	_dirty[kind] = true


## Scatters [param amount] plants of [param kind] in a circle (templates).
## [param accept] (optional) gets (x, z, ground height) and returns false to skip a spot.
func scatter(kind: String, centre: Vector2, radius: float, amount: int, accept: Callable = Callable()) -> void:
	var data: PackedFloat32Array = plants[kind]
	var settings: Dictionary = _settings_for(kind)
	var spacing := float(settings["spacing"])
	var scale_range: Vector2 = settings["scale"]
	for i in amount:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * radius
		var x := centre.x + cos(a) * r
		var z := centre.y + sin(a) * r
		var y := _ground_y(x, z)
		if accept.is_valid() and not bool(accept.call(x, z, y)):
			continue
		if spacing > 0.0 and _too_close(data, x, z, spacing):
			continue
		var variant := float(_rng.randi_range(0, FLOWER_COLORS.size() - 1)) + _rng.randf() * 0.5
		data.append_array([x, y, z, _rng.randf() * TAU, _rng.randf_range(scale_range.x, scale_range.y), variant])
	plants[kind] = data
	_dirty[kind] = true


## Removes plants inside a circle ([param kind] empty = every kind).
func erase(kind: String, centre: Vector3, radius: float, strength: float) -> void:
	var r2 := radius * radius
	for k in plants.keys():
		if not kind.is_empty() and k != kind:
			continue
		var data: PackedFloat32Array = plants[k]
		var kept := PackedFloat32Array()
		var removed := false
		for i in range(0, data.size(), STRIDE):
			var dx := data[i] - centre.x
			var dz := data[i + 2] - centre.z
			if dx * dx + dz * dz < r2 and _rng.randf() < clampf(strength * 0.6, 0.05, 1.0):
				removed = true
				continue
			kept.append_array(data.slice(i, i + STRIDE))
		if removed:
			plants[k] = kept
			_dirty[k] = true


## Puts plants back on the ground after the terrain changed in [param area].
func resettle(area: Rect2) -> void:
	var grown := area.grow(1.0)
	for k in plants.keys():
		var data: PackedFloat32Array = plants[k]
		var changed := false
		for i in range(0, data.size(), STRIDE):
			if grown.has_point(Vector2(data[i], data[i + 2])):
				data[i + 1] = _ground_y(data[i], data[i + 2])
				changed = true
		if changed:
			plants[k] = data
			_dirty[k] = true


func snapshot() -> Dictionary:
	var out := {}
	for k in plants.keys():
		out[k] = (plants[k] as PackedFloat32Array).duplicate()
	return out


func restore(state: Dictionary) -> void:
	for k in plants.keys():
		plants[k] = (state.get(k, PackedFloat32Array()) as PackedFloat32Array).duplicate()
		_dirty[k] = true


# --- Save / load ---------------------------------------------------------------

func to_dict() -> Dictionary:
	var out := {}
	for k in plants.keys():
		var data: PackedFloat32Array = plants[k]
		if not data.is_empty():
			out[k] = {"count": data.size(), "data": Marshalls.raw_to_base64(data.to_byte_array().compress(FileAccess.COMPRESSION_ZSTD))}
	return out


func load_dict(data: Dictionary) -> void:
	for key in data:
		var kind := str(key)
		if kind.begins_with(MODEL_PREFIX) and not plants.has(kind):
			var model_path := kind.trim_prefix(MODEL_PREFIX)
			if FileAccess.file_exists(model_path) or ResourceLoader.exists(model_path):
				add_model_kind(model_path)
	for k in plants.keys():
		var entry: Variant = data.get(k)
		var values := PackedFloat32Array()
		if entry is Dictionary:
			var floats := int(entry.get("count", 0))
			var raw := Marshalls.base64_to_raw(str(entry.get("data", ""))).decompress(floats * 4, FileAccess.COMPRESSION_ZSTD)
			if raw.size() == floats * 4:
				values = raw.to_float32_array()
		plants[k] = values
		_dirty[k] = true


func clear() -> void:
	load_dict({})


# --- Internals -----------------------------------------------------------------

func _ground_y(x: float, z: float) -> float:
	return _terrain.height_at(x, z) if _terrain else 0.0


func _too_close(data: PackedFloat32Array, x: float, z: float, spacing: float) -> bool:
	var s2 := spacing * spacing
	for i in range(0, data.size(), STRIDE):
		var dx := data[i] - x
		var dz := data[i + 2] - z
		if dx * dx + dz * dz < s2:
			return true
	return false


func _rebuild(kind: String) -> void:
	var data: PackedFloat32Array = plants[kind]
	var n := data.size() / STRIDE
	var multimesh := (_instances[kind] as MultiMeshInstance3D).multimesh
	multimesh.instance_count = 0
	multimesh.instance_count = n
	if n == 0:
		return
	var buffer := PackedFloat32Array()
	buffer.resize(n * 16)
	var flowers := kind == "Flowers"
	for p in n:
		var i: int = p * STRIDE
		var angle := data[i + 3]
		var s := data[i + 4]
		var c := cos(angle) * s
		var sn := sin(angle) * s
		var b: int = p * 16
		# Basis rows (x, y, z) followed by origin, as MultiMesh expects.
		buffer[b] = c
		buffer[b + 1] = 0.0
		buffer[b + 2] = sn
		buffer[b + 3] = data[i]
		buffer[b + 4] = 0.0
		buffer[b + 5] = s
		buffer[b + 6] = 0.0
		buffer[b + 7] = data[i + 1]
		buffer[b + 8] = -sn
		buffer[b + 9] = 0.0
		buffer[b + 10] = c
		buffer[b + 11] = data[i + 2]
		var variant := data[i + 5]
		var head: Color = FLOWER_COLORS[int(variant) % FLOWER_COLORS.size()] if flowers else Color.WHITE
		buffer[b + 12] = head.r
		buffer[b + 13] = head.g
		buffer[b + 14] = head.b
		buffer[b + 15] = 0.85 + fmod(variant, 1.0) * 0.5
	multimesh.buffer = buffer

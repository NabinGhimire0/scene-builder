class_name Terrain
extends Node3D
## Sculptable, paintable ground: a 256 m square in the middle of the world
## (1 m detail), surrounded by the flat ground plane.
##
## Heights and painted layers live in two arrays; brushes edit them, the shader
## displays them, and a height-map collider keeps placement, characters and
## "drop to ground" on the surface. Undo works per brush stroke.

signal stroke_finished(area: Rect2)

enum Tool { RAISE, LOWER, SMOOTH, FLATTEN, PAINT }

const SHADER := preload("res://assets/materials/terrain.gdshader")
const SIZE := 256.0
const RES := 257
const HALF := SIZE * 0.5
const SPACING := SIZE / float(RES - 1)
const MIN_HEIGHT := -60.0
const MAX_HEIGHT := 120.0
## Painted layers (index 0 erases back to the ground style).
const LAYERS: PackedStringArray = ["Ground style", "Dirt", "Rock", "Sand", "Snow"]

## The flat ground outside; its collider gets a hole where the terrain is.
@export var ground_body: StaticBody3D
@export var ground_mesh: MeshInstance3D

var heights := PackedFloat32Array()
var splat := PackedByteArray()

var _height_image: Image
var _height_texture: ImageTexture
var _splat_image: Image
var _splat_texture: ImageTexture
var _material: ShaderMaterial
var _mesh: MeshInstance3D
var _shape: HeightMapShape3D
var _textures_dirty := false
var _collision_dirty := false
var _stroke_area := Rect2()


func _ready() -> void:
	add_to_group(&"terrain")
	heights.resize(RES * RES)
	heights.fill(0.0)
	splat.resize(RES * RES * 4)
	splat.fill(0)
	_height_image = Image.create_from_data(RES, RES, false, Image.FORMAT_RF, heights.to_byte_array())
	_height_texture = ImageTexture.create_from_image(_height_image)
	_splat_image = Image.create_from_data(RES, RES, false, Image.FORMAT_RGBA8, splat)
	_splat_texture = ImageTexture.create_from_image(_splat_image)

	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("heightmap", _height_texture)
	_material.set_shader_parameter("splatmap", _splat_texture)
	_material.set_shader_parameter("terrain_size", SIZE)
	_material.set_shader_parameter("texel", 1.0 / float(RES - 1))

	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	plane.subdivide_width = RES - 2
	plane.subdivide_depth = RES - 2
	_mesh = MeshInstance3D.new()
	_mesh.name = "TerrainMesh"
	_mesh.mesh = plane
	_mesh.material_override = _material
	_mesh.custom_aabb = AABB(Vector3(-HALF, MIN_HEIGHT, -HALF), Vector3(SIZE, MAX_HEIGHT - MIN_HEIGHT, SIZE))
	add_child(_mesh)

	var body := StaticBody3D.new()
	body.name = "TerrainCollider"
	body.collision_layer = Layers.GROUND
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	_shape = HeightMapShape3D.new()
	_shape.map_width = RES
	_shape.map_depth = RES
	_shape.map_data = heights
	collision.shape = _shape
	body.add_child(collision)
	add_child(body)
	_cut_ground_hole()


func _process(_delta: float) -> void:
	if _textures_dirty:
		_textures_dirty = false
		_height_image.set_data(RES, RES, false, Image.FORMAT_RF, heights.to_byte_array())
		_height_texture.update(_height_image)
		_splat_image.set_data(RES, RES, false, Image.FORMAT_RGBA8, splat)
		_splat_texture.update(_splat_image)


## The outside ground keeps its look but loses its collider under the terrain
## (so you can dig below zero), and sits a hair lower so they never flicker.
func _cut_ground_hole() -> void:
	if ground_mesh:
		ground_mesh.position.y = -0.03
		# The flat ground must not be drawn over the terrain: it would hide every lake,
		# river and hollow dug below zero. It becomes a square ring around the terrain.
		ground_mesh.mesh = _ground_ring(1000.0, HALF - 2.0)
	if ground_body == null:
		return
	for child in ground_body.get_children():
		if child is CollisionShape3D:
			child.queue_free()
	var outer := 1000.0
	var band := outer - HALF
	var boxes := [
		[Vector3(0, -0.5, HALF + band * 0.5), Vector3(outer * 2.0, 1.0, band)],
		[Vector3(0, -0.5, -HALF - band * 0.5), Vector3(outer * 2.0, 1.0, band)],
		[Vector3(HALF + band * 0.5, -0.5, 0), Vector3(band, 1.0, SIZE)],
		[Vector3(-HALF - band * 0.5, -0.5, 0), Vector3(band, 1.0, SIZE)],
	]
	for pair in boxes:
		var shape := BoxShape3D.new()
		shape.size = pair[1]
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = pair[0]
		ground_body.add_child(collision)


## A flat square ring (outer half-size, inner half-size), UVs like a 2 km PlaneMesh.
static func _ground_ring(outer: float, inner: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var quads := [
		[Vector2(-outer, -outer), Vector2(outer, -inner)],
		[Vector2(-outer, inner), Vector2(outer, outer)],
		[Vector2(-outer, -inner), Vector2(-inner, inner)],
		[Vector2(inner, -inner), Vector2(outer, inner)],
	]
	for q in quads:
		var a: Vector2 = q[0]
		var b: Vector2 = q[1]
		var corners := [Vector2(a.x, a.y), Vector2(b.x, a.y), Vector2(b.x, b.y), Vector2(a.x, b.y)]
		for i in [0, 1, 2, 0, 2, 3]:
			var c: Vector2 = corners[i]
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2((c.x + outer) / (outer * 2.0), (c.y + outer) / (outer * 2.0)))
			st.add_vertex(Vector3(c.x, 0.0, c.y))
	var mesh := st.commit()
	return mesh


# --- Queries -------------------------------------------------------------------

static func contains(x: float, z: float) -> bool:
	return absf(x) <= HALF and absf(z) <= HALF


## Ground height at world [param x], [param z] (0 outside the terrain).
func height_at(x: float, z: float) -> float:
	if not contains(x, z):
		return 0.0
	var fx := clampf((x + HALF) / SPACING, 0.0, RES - 1.001)
	var fz := clampf((z + HALF) / SPACING, 0.0, RES - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * RES + ix
	var top := lerpf(heights[i], heights[i + 1], tx)
	var bottom := lerpf(heights[i + RES], heights[i + RES + 1], tx)
	return lerpf(top, bottom, tz)


func is_modified() -> bool:
	for h in heights:
		if h != 0.0:
			return true
	for b in splat:
		if b != 0:
			return true
	return false


# --- Brushes -------------------------------------------------------------------

func snapshot() -> Dictionary:
	return {"heights": heights.duplicate(), "splat": splat.duplicate()}


func restore(state: Dictionary) -> void:
	heights = (state["heights"] as PackedFloat32Array).duplicate()
	splat = (state["splat"] as PackedByteArray).duplicate()
	_refresh_all()


func begin_stroke() -> void:
	_stroke_area = Rect2()


## Applies one brush dab. [param strength] 0..1, [param delta] seconds since the
## last dab, [param target] the height for Flatten, [param layer] the painted
## layer (0 = back to the ground style).
func apply_brush(tool: int, centre: Vector3, radius: float, strength: float, delta: float, target: float = 0.0, layer: int = 1) -> void:
	var cx := (centre.x + HALF) / SPACING
	var cz := (centre.z + HALF) / SPACING
	var r := maxf(radius / SPACING, 0.5)
	var x0 := maxi(0, floori(cx - r))
	var x1 := mini(RES - 1, ceili(cx + r))
	var z0 := maxi(0, floori(cz - r))
	var z1 := mini(RES - 1, ceili(cz + r))
	if x0 > x1 or z0 > z1:
		return
	var rate := strength * delta
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x - cx, z - cz).length() / r
			if d >= 1.0:
				continue
			var w := (0.5 + 0.5 * cos(PI * d)) * rate * _edge_fade(x, z)
			if w <= 0.0:
				continue
			var i: int = z * RES + x
			match tool:
				Tool.RAISE:
					heights[i] = minf(heights[i] + w * 6.0, MAX_HEIGHT)
				Tool.LOWER:
					heights[i] = maxf(heights[i] - w * 6.0, MIN_HEIGHT)
				Tool.SMOOTH:
					heights[i] = lerpf(heights[i], _neighbour_average(x, z), clampf(w * 8.0, 0.0, 1.0))
				Tool.FLATTEN:
					heights[i] = lerpf(heights[i], target, clampf(w * 6.0, 0.0, 1.0))
				Tool.PAINT:
					_paint(i, layer, clampf(w * 5.0, 0.0, 1.0))
	var area := Rect2(x0 * SPACING - HALF, z0 * SPACING - HALF, (x1 - x0) * SPACING, (z1 - z0) * SPACING)
	_stroke_area = area if _stroke_area.size == Vector2.ZERO else _stroke_area.merge(area)
	_textures_dirty = true
	if tool != Tool.PAINT:
		_collision_dirty = true


## Finishes a stroke: updates the collider and tells plants to re-settle.
func end_stroke() -> void:
	if _collision_dirty:
		_collision_dirty = false
		_shape.map_data = heights
	if _stroke_area.size != Vector2.ZERO:
		stroke_finished.emit(_stroke_area)


## Lowers/raises the terrain to fit a water feature: the bed follows its depth
## and the shore meets the water surface exactly.
func carve_for(water: WaterFeature) -> void:
	var box := PropUtils.world_aabb(water).grow(water.bank_width * 1.5)
	var surface := water.global_position.y + 0.02
	var x0 := maxi(0, floori((box.position.x + HALF) / SPACING))
	var x1 := mini(RES - 1, ceili((box.end.x + HALF) / SPACING))
	var z0 := maxi(0, floori((box.position.z + HALF) / SPACING))
	var z1 := mini(RES - 1, ceili((box.end.z + HALF) / SPACING))
	var bank := maxf(water.bank_width * 1.5, 1.0)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var world := Vector3(x * SPACING - HALF, surface, z * SPACING - HALF)
			var local := water.to_local(world)
			var edge := water.edge_at_local(Vector2(local.x, local.z))
			if edge < -bank:
				continue
			var fade := _edge_fade(x, z)
			if fade <= 0.0:
				continue
			var i: int = z * RES + x
			var target := 0.0
			if edge > 0.0:
				target = minf(heights[i], surface - 0.08 - water.depth_profile(edge))
			else:
				target = lerpf(surface - 0.05, heights[i], smoothstep(0.0, bank, -edge))
			heights[i] = lerpf(heights[i], target, fade)
	_refresh_all()
	stroke_finished.emit(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))


# --- Save / load ---------------------------------------------------------------

func to_dict() -> Dictionary:
	if not is_modified():
		return {}
	return {
		"size": SIZE,
		"res": RES,
		"heights": Marshalls.raw_to_base64(heights.to_byte_array().compress(FileAccess.COMPRESSION_ZSTD)),
		"splat": Marshalls.raw_to_base64(splat.compress(FileAccess.COMPRESSION_ZSTD)),
	}


func load_dict(data: Dictionary) -> void:
	heights.fill(0.0)
	splat.fill(0)
	if int(data.get("res", 0)) == RES:
		var h := Marshalls.base64_to_raw(str(data.get("heights", ""))).decompress(RES * RES * 4, FileAccess.COMPRESSION_ZSTD)
		if h.size() == RES * RES * 4:
			heights = h.to_float32_array()
		var s := Marshalls.base64_to_raw(str(data.get("splat", ""))).decompress(RES * RES * 4, FileAccess.COMPRESSION_ZSTD)
		if s.size() == RES * RES * 4:
			splat = s
	_refresh_all()


func clear() -> void:
	load_dict({})


# --- Ground style (from the Scene tab) ----------------------------------------

func set_base_preset(colors: Array, roughness: float, bump: float, specular: float, speckle: float, scale_value: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("use_base_texture", false)
	_material.set_shader_parameter("color_a", colors[0])
	_material.set_shader_parameter("color_b", colors[1])
	_material.set_shader_parameter("color_c", colors[2])
	_material.set_shader_parameter("roughness_value", roughness)
	_material.set_shader_parameter("bump", bump)
	_material.set_shader_parameter("specular_value", specular)
	_material.set_shader_parameter("speckle", speckle)
	_material.set_shader_parameter("scale", scale_value)


func set_base_texture(texture: Texture2D, tile: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("use_base_texture", texture != null)
	_material.set_shader_parameter("base_texture", texture)
	_material.set_shader_parameter("base_tile", tile)


# --- Internals -----------------------------------------------------------------

func _refresh_all() -> void:
	_textures_dirty = true
	if _shape:
		_shape.map_data = heights


## Keeps the outer 6 m flat so the terrain always meets the outside ground.
static func _edge_fade(x: int, z: int) -> float:
	var border := mini(mini(x, z), mini(RES - 1 - x, RES - 1 - z)) * SPACING
	return clampf((border - 1.0) / 6.0, 0.0, 1.0)


func _neighbour_average(x: int, z: int) -> float:
	var total := 0.0
	var count := 0
	for oz in range(-1, 2):
		for ox in range(-1, 2):
			var nx: int = x + ox
			var nz: int = z + oz
			if nx >= 0 and nz >= 0 and nx < RES and nz < RES:
				total += heights[nz * RES + nx]
				count += 1
	return total / float(count)


func _paint(i: int, layer: int, amount: float) -> void:
	var channel := layer - 1
	for c in 4:
		var index: int = i * 4 + c
		var v := float(splat[index])
		if c == channel:
			v += (255.0 - v) * amount
		else:
			v -= v * amount
		splat[index] = clampi(roundi(v), 0, 255)

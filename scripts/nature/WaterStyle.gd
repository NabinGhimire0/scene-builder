class_name WaterStyle
extends RefCounted
## Shared water resources: shaders, noise textures, colour looks and the mesh
## builders used by [WaterFeature] subclasses.

const WATER_SHADER := preload("res://assets/materials/water.gdshader")
const BANK_SHADER := preload("res://assets/materials/water_bank.gdshader")

## Water looks: colours seen in shallow and deep water, and how far you can see in.
const LOOKS := {
	"Clear lake": {"shallow_color": Color(0.32, 0.58, 0.55), "deep_color": Color(0.03, 0.13, 0.17), "clarity": 2.5},
	"Tropical": {"shallow_color": Color(0.36, 0.86, 0.8), "deep_color": Color(0.02, 0.25, 0.42), "clarity": 6.0},
	"Mountain lake": {"shallow_color": Color(0.3, 0.64, 0.62), "deep_color": Color(0.02, 0.17, 0.24), "clarity": 4.0},
	"Murky pond": {"shallow_color": Color(0.34, 0.37, 0.2), "deep_color": Color(0.06, 0.09, 0.05), "clarity": 0.6},
	"Muddy river": {"shallow_color": Color(0.52, 0.43, 0.28), "deep_color": Color(0.18, 0.14, 0.08), "clarity": 0.45},
	"Deep sea": {"shallow_color": Color(0.22, 0.62, 0.64), "deep_color": Color(0.01, 0.06, 0.13), "clarity": 3.5},
}
## Bank / shore looks: wet edge, dry outer edge, bed under the water.
const SHORES := {
	"Mud": {"bank_wet": Color(0.16, 0.12, 0.08), "bank_dry": Color(0.36, 0.3, 0.21), "bank_bed": Color(0.28, 0.24, 0.17)},
	"Sand": {"bank_wet": Color(0.55, 0.47, 0.34), "bank_dry": Color(0.84, 0.76, 0.6), "bank_bed": Color(0.7, 0.62, 0.46)},
	"Pebbles": {"bank_wet": Color(0.26, 0.25, 0.23), "bank_dry": Color(0.52, 0.5, 0.46), "bank_bed": Color(0.4, 0.38, 0.34)},
	"Grassy": {"bank_wet": Color(0.15, 0.15, 0.08), "bank_dry": Color(0.25, 0.32, 0.13), "bank_bed": Color(0.26, 0.25, 0.15)},
}

static var _ripple_a: NoiseTexture2D
static var _ripple_b: NoiseTexture2D
static var _foam: NoiseTexture2D


static func ripple_a() -> Texture2D:
	if _ripple_a == null:
		_ripple_a = _noise(1, 0.008, true, 9.0)
	return _ripple_a


static func ripple_b() -> Texture2D:
	if _ripple_b == null:
		_ripple_b = _noise(7, 0.02, true, 5.0)
	return _ripple_b


static func foam() -> Texture2D:
	if _foam == null:
		_foam = _noise(13, 0.018, false, 0.0)
	return _foam


static func new_water_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("ripple_a", ripple_a())
	material.set_shader_parameter("ripple_b", ripple_b())
	material.set_shader_parameter("foam_tex", foam())
	return material


static func new_bank_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BANK_SHADER
	material.set_shader_parameter("noise_tex", foam())
	return material


## A flat grid through the given x and z coordinates. UV = local metres,
## normal up, tangent +X.
static func grid_mesh(xs: PackedFloat32Array, zs: PackedFloat32Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	for z in zs:
		for x in xs:
			verts.append(Vector3(x, 0.0, z))
			normals.append(Vector3.UP)
			tangents.append_array([1.0, 0.0, 0.0, 1.0])
			uvs.append(Vector2(x, z))
	return _indexed(verts, normals, tangents, uvs, xs.size(), zs.size())


## Evenly spaced coordinates from [param from] to [param to].
static func spaced(from: float, to: float, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	count = maxi(count, 2)
	for i in count:
		out.append(lerpf(from, to, float(i) / float(count - 1)))
	return out


## Coordinates that are dense near [param focus] and spread out further away
## (for the sea: detailed waves near the shore, cheap far away).
static func focused(from: float, to: float, focus: float, count: int, power: float = 2.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	count = maxi(count, 3)
	for i in count:
		var u := lerpf(-1.0, 1.0, float(i) / float(count - 1))
		var reach := (to - focus) if u >= 0.0 else (focus - from)
		out.append(focus + signf(u) * pow(absf(u), power) * reach)
	return out


## A ribbon along a centre line. [param centres] and [param directions] are per
## sample; [param offsets] are the metres across (negative = left). UV = (metres
## across, metres along); the tangent points downstream.
static func ribbon_mesh(centres: PackedVector3Array, directions: PackedVector3Array, distances: PackedFloat32Array, offsets: PackedFloat32Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	for i in centres.size():
		var dir := directions[i]
		var side := Vector3(dir.z, 0.0, -dir.x)
		for offset in offsets:
			verts.append(centres[i] + side * offset)
			normals.append(Vector3.UP)
			tangents.append_array([dir.x, dir.y, dir.z, 1.0])
			uvs.append(Vector2(offset, distances[i]))
	return _indexed(verts, normals, tangents, uvs, offsets.size(), centres.size())


static func _indexed(verts: PackedVector3Array, normals: PackedVector3Array, tangents: PackedFloat32Array, uvs: PackedVector2Array, columns: int, rows: int) -> ArrayMesh:
	var indices := PackedInt32Array()
	for r in rows - 1:
		for c in columns - 1:
			var a: int = r * columns + c
			var b := a + 1
			var d := a + columns
			var e := d + 1
			indices.append_array([a, b, d, b, e, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _noise(noise_seed: int, frequency: float, normal_map: bool, bump: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	if normal_map:
		texture.as_normal_map = true
		texture.bump_strength = bump
	return texture

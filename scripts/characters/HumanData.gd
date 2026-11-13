class_name HumanData
extends RefCounted
## Reads the realistic-human data (res://assets/humans/data/, made from MakeHuman's
## CC0 data by tools/humans/prepare.py) once and keeps it for every build.
## Coordinates are MakeHuman's: decimetres, Y up, the body faces +Z.

const DIR := "res://assets/humans/data/"

static var loaded := false
static var verts := PackedVector3Array()
static var uvs := PackedVector2Array()
static var face_v := PackedInt32Array()      # 4 per face (-1 = triangle)
static var face_t := PackedInt32Array()
static var face_g := PackedByteArray()        # group index (face_groups)
static var face_groups: Array = []
static var groups: Dictionary = {}           # joint / eye group -> PackedInt32Array
static var body_faces := PackedInt32Array()  # faces of the skin, in MakeHuman order
static var bones: Array = []                 # [{name, parent, joint}]
static var w_bones := PackedByteArray()
static var w_weights := PackedByteArray()
static var templates: Dictionary = {}        # name -> {ia, ib, t, counts, faces, uvs, extras..., hide}
static var eyes: Dictionary = {}
static var _target_index: Dictionary = {}
static var _target_bytes := PackedByteArray()
static var _target_cache: Dictionary = {}
static var _target_scale := 0.0001
static var _edges: Dictionary = {}


static func ensure() -> bool:
	if loaded:
		return true
	var info: Variant = _json(DIR + "base.json")
	if info == null:
		push_error("HumanData: missing %sbase.json" % DIR)
		return false
	var bytes := FileAccess.get_file_as_bytes(DIR + "base.bin")
	var arrays: Dictionary = info["arrays"]
	verts = _vec3(_f32(bytes, arrays["verts"]))
	var uv_f := _f32(bytes, arrays["uvs"])
	uvs.resize(uv_f.size() / 2)
	for i in uvs.size():
		uvs[i] = Vector2(uv_f[i * 2], 1.0 - uv_f[i * 2 + 1])
	face_v = _i32(bytes, arrays["face_v"])
	face_t = _i32(bytes, arrays["face_t"])
	face_g = _u8(bytes, arrays["face_g"])
	face_groups = info["face_groups"]
	var gv := _i32(bytes, arrays["group_verts"])
	for g in info["groups"]:
		var r: Array = info["groups"][g]
		groups[g] = gv.slice(int(r[0]), int(r[0]) + int(r[1]))
	for f in face_g.size():
		if face_g[f] == 0:
			body_faces.append(f)
	var t_info: Variant = _json(DIR + "targets.json")
	_target_index = t_info["targets"]
	_target_scale = float(t_info.get("scale", 0.0001))
	_target_bytes = FileAccess.get_file_as_bytes(DIR + "targets.bin")
	bones = (_json(DIR + "rig.json") as Dictionary)["bones"]
	var wb := FileAccess.get_file_as_bytes(DIR + "weights.bin")
	var n := verts.size() * 4
	w_bones = wb.slice(0, n)
	w_weights = wb.slice(n, n * 2)
	var tpl: Dictionary = _json(DIR + "templates.json")
	var tb := FileAccess.get_file_as_bytes(DIR + "templates.bin")
	var tarr: Dictionary = tpl["arrays"]
	for name in tpl["templates"]:
		var meta: Dictionary = tpl["templates"][name]
		var t := {"ia": _i32(tb, tarr[name + ".ia"]), "ib": _i32(tb, tarr[name + ".ib"]), "t": _f32(tb, tarr[name + ".t"]),
			"counts": _u8(tb, tarr[name + ".counts"]), "faces": _i32(tb, tarr[name + ".faces"]), "uvs": _f32(tb, tarr[name + ".uvs"])}
		for extra in meta["extra"]:
			t[extra] = _f32(tb, tarr[name + "." + extra])
		if meta["hide"]:
			t["hide"] = _i32(tb, tarr[name + ".hide"])
		templates[name] = t
	eyes = _json(DIR + "eyes.json")
	loaded = true
	return true


## Vertex indices and offsets (decimetres) of a shape target, or empty arrays.
static func target(name: String) -> Array:
	if _target_cache.has(name):
		return _target_cache[name]
	var out: Array = [PackedInt32Array(), PackedVector3Array()]
	if _target_index.has(name):
		var r: Array = _target_index[name]
		var off_i := int(r[0])
		var count := int(r[1])
		var off_d := int(r[2])
		var sc := float(r[3]) if r.size() > 3 else _target_scale
		var idx := PackedInt32Array()
		var d := PackedVector3Array()
		idx.resize(count)
		d.resize(count)
		for k in count:
			idx[k] = _target_bytes.decode_u16(off_i + k * 2)
			var o := off_d + k * 6
			d[k] = Vector3(_target_bytes.decode_s16(o), _target_bytes.decode_s16(o + 2), _target_bytes.decode_s16(o + 4)) * sc
		out = [idx, d]
	_target_cache[name] = out
	return out


static func has_target(name: String) -> bool:
	return _target_index.has(name)


static func target_names() -> Array:
	return _target_index.keys()


## Edges of a template mesh (for smoothing) and which vertices are on its rim.
static func template_edges(name: String) -> Array:
	if _edges.has(name):
		return _edges[name]
	var t: Dictionary = templates[name]
	var counts: PackedByteArray = t["counts"]
	var faces: PackedInt32Array = t["faces"]
	var seen := {}
	var pos := 0
	for c in counts:
		for k in c:
			var a := faces[pos + k]
			var b := faces[pos + (k + 1) % c]
			var key := mini(a, b) * 100000 + maxi(a, b)
			seen[key] = int(seen.get(key, 0)) + 1
		pos += c
	var edges := PackedInt32Array()
	var rim := PackedByteArray()
	rim.resize((t["ia"] as PackedInt32Array).size())
	for key in seen:
		var a := int(key) / 100000
		var b := int(key) % 100000
		edges.append(a)
		edges.append(b)
		if int(seen[key]) == 1:
			rim[a] = 1
			rim[b] = 1
	_edges[name] = [edges, rim]
	return _edges[name]


static func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func _f32(bytes: PackedByteArray, r: Array) -> PackedFloat32Array:
	return bytes.slice(int(r[0]), int(r[0]) + int(r[1]) * 4).to_float32_array()


static func _i32(bytes: PackedByteArray, r: Array) -> PackedInt32Array:
	return bytes.slice(int(r[0]), int(r[0]) + int(r[1]) * 4).to_int32_array()


static func _u8(bytes: PackedByteArray, r: Array) -> PackedByteArray:
	return bytes.slice(int(r[0]), int(r[0]) + int(r[1]))


static func _vec3(f: PackedFloat32Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(f.size() / 3)
	for i in out.size():
		out[i] = Vector3(f[i * 3], f[i * 3 + 1], f[i * 3 + 2])
	return out

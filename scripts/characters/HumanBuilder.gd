class_name HumanBuilder
extends RefCounted
## Builds a realistic (or animated-film style) person from a description, inside
## the app: MakeHuman body shapes (CC0) + Scene Builder's skin, eyes, hair,
## clothes and shoes, on the game_engine rig, animated with motion capture.
##
## Spec (all optional):
##   type "realistic"|"pixar", gender 0..1, age (years), weight/muscle/height 0..1,
##   race {african, asian, caucasian}, face_seed, face {slider: -1..1}, body {slider: -1..1},
##   skin "#hex", lips, brows, eyes, freckles, blush, makeup, wrinkles (-1 = by age),
##   hair {style, color}, beard {style, color},
##   outfit {top {style, color, fabric}, bottom {...}, shoes {...}, extra [wardrobe paths]},
##   stylize 0..1, head_scale, eye_scale (animated-film look)

const TEX := "res://assets/humans/tex/"
const SHADERS := "res://assets/humans/shaders/"
const MOTIONS := "res://assets/humans/motions.glb"

const TOPS := ["none", "tshirt", "longsleeve", "shirt", "hoodie", "sweater", "jacket", "raincoat", "kurta", "tanktop"]
const BOTTOMS := ["none", "trousers", "jeans", "shorts", "longshorts", "leggings", "skirt"]
const SHOES := ["none", "shoes", "sneakers", "boots"]
const HAIR := ["short", "kid", "receding", "buzz", "bob", "long", "ponytail", "pigtails", "bun", "bald"]
const BEARDS := ["none", "stubble", "short", "full"]
const FABRICS := ["cotton", "denim", "knit", "wool", "rain", "silk", "leather"]
const DEFAULT_FABRIC := {"tshirt": "cotton", "longsleeve": "cotton", "shirt": "cotton", "hoodie": "knit", "sweater": "knit",
	"jacket": "denim", "raincoat": "rain", "kurta": "silk", "tanktop": "cotton", "trousers": "cotton", "jeans": "denim",
	"shorts": "cotton", "longshorts": "denim", "leggings": "cotton", "skirt": "cotton", "shoes": "leather", "sneakers": "leather", "boots": "leather"}
const FABRIC_LOOK := {"cotton": [0.88, 0.0], "denim": [0.9, 0.0], "knit": [0.92, 0.1], "wool": [0.95, 0.15],
	"rain": [0.32, 0.0], "silk": [0.42, 0.6], "leather": [0.5, 0.0]}

## Creator sliders -> [decrease target, increase target] (both sides for l-/r- pairs).
const FACE_SLIDERS := {
	"face_width": ["head/head-scale-horiz-decr", "head/head-scale-horiz-incr"],
	"face_length": ["head/head-scale-vert-decr", "head/head-scale-vert-incr"],
	"jaw": ["chin/chin-width-decr", "chin/chin-width-incr"],
	"chin": ["chin/chin-prominent-decr", "chin/chin-prominent-incr"],
	"cheekbones": ["cheek/%s-cheek-bones-decr", "cheek/%s-cheek-bones-incr"],
	"cheeks": ["cheek/%s-cheek-volume-decr", "cheek/%s-cheek-volume-incr"],
	"nose_size": ["nose/nose-volume-decr", "nose/nose-volume-incr"],
	"nose_width": ["nose/nose-scale-horiz-decr", "nose/nose-scale-horiz-incr"],
	"nose_length": ["nose/nose-scale-vert-decr", "nose/nose-scale-vert-incr"],
	"nose_bridge": ["nose/nose-hump-decr", "nose/nose-hump-incr"],
	"eye_size": ["eyes/%s-eye-scale-decr", "eyes/%s-eye-scale-incr"],
	"eye_spacing": ["eyes/%s-eye-trans-in", "eyes/%s-eye-trans-out"],
	"lips": ["mouth/mouth-upperlip-volume-decr", "mouth/mouth-upperlip-volume-incr", "mouth/mouth-lowerlip-volume-decr", "mouth/mouth-lowerlip-volume-incr"],
	"mouth_width": ["mouth/mouth-scale-horiz-decr", "mouth/mouth-scale-horiz-incr"],
	"ears": ["ears/%s-ear-scale-decr", "ears/%s-ear-scale-incr"],
	"brow_height": ["eyebrows/eyebrows-trans-down", "eyebrows/eyebrows-trans-up"],
	"shoulders": ["torso/torso-vshape-decr", "torso/torso-vshape-incr"],
	"chest": ["torso/torso-scale-depth-decr", "torso/torso-scale-depth-incr"],
	"hips": ["hip/hip-scale-horiz-decr", "hip/hip-scale-horiz-incr"],
	"belly": ["stomach/stomach-pregnant-decr", "stomach/stomach-pregnant-incr"],
	"neck": ["neck/neck-scale-horiz-decr", "neck/neck-scale-horiz-incr"],
}
const FACE_GROUPS := ["nose", "chin", "mouth", "eyes", "cheek", "forehead", "head", "ears", "eyebrows", "neck"]
const EXPRESSIONS := {
	"blink": [["eye-left-closure", 1.0], ["eye-right-closure", 1.0]],
	"jawOpen": [["mouth-open", 0.8]],
	"smile": [["mouth-corner-puller", 0.8], ["mouth-elevation", 0.25], ["eye-left-slit", 0.25], ["eye-right-slit", 0.25]],
	"frown": [["mouth-depression", 0.7], ["eyebrows-left-inner-up", 0.6], ["eyebrows-right-inner-up", 0.6]],
	"angry": [["eyebrows-left-down", 0.8], ["eyebrows-right-down", 0.8], ["mouth-compression", 0.4]],
	"surprise": [["eyebrows-left-up", 0.8], ["eyebrows-right-up", 0.8], ["eye-left-opened-up", 0.6], ["eye-right-opened-up", 0.6], ["mouth-open", 0.35]],
}
## Hair caps: template and where the scalp line sits (texture units, 0.5 = normal).
const CAPS := {"short": ["hair_short", 0.5], "kid": ["hair_kid", 0.44], "receding": ["hair_receding", 0.69],
	"buzz": ["hair_short", 0.5], "bob": ["hair_long", 0.47], "long": ["hair_long", 0.47], "ponytail": ["hair_long", 0.47],
	"pigtails": ["hair_kid", 0.44], "bun": ["hair_long", 0.47]}

static var _cache: Dictionary = {}
static var _motion: Dictionary = {}
static var _textures: Dictionary = {}
static var _shaders: Dictionary = {}


## A built person (cached by spec; each call returns a fresh copy that shares meshes).
static func build(spec: Dictionary) -> Node3D:
	var key := JSON.stringify(spec).md5_text()
	if _cache.has(key):
		var copy := (_cache[key] as Node3D).duplicate()
		copy.set_meta("human_motion", true)
		copy.set_meta("human_spec", spec)
		return copy
	var model := _build(spec)
	if model == null:
		return null
	_cache[key] = model
	var out := model.duplicate()
	out.set_meta("human_motion", true)
	out.set_meta("human_spec", spec)
	return out


static func forget(spec: Dictionary) -> void:
	_cache.erase(JSON.stringify(spec).md5_text())


static func load_spec(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


# ------------------------------------------------------------------ body shape

static func _num(spec: Dictionary, key: String, fallback: float) -> float:
	return float(spec.get(key, fallback))


static func _three(v: float) -> Dictionary:
	var lo := maxf(0.0, 1.0 - v * 2.0)
	var hi := maxf(0.0, v * 2.0 - 1.0)
	return {"min": lo, "average": 1.0 - lo - hi, "max": hi}


## MakeHuman's age slider for an age in years. MakeHuman's own scale makes young
## children very small; this table gives real-world heights (7 years ~1.2 m).
const AGE_TABLE := [[1.0, 0.0], [3.0, 0.07], [5.0, 0.13], [7.0, 0.165], [9.0, 0.1875], [11.0, 0.235],
	[14.0, 0.33], [18.0, 0.43], [25.0, 0.5], [90.0, 1.0]]

static func _age_value(years: float) -> float:
	for i in range(1, AGE_TABLE.size()):
		var a: Array = AGE_TABLE[i - 1]
		var b: Array = AGE_TABLE[i]
		if years <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), clampf((years - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0))
	return 1.0


static func _age_weights(a: float) -> Dictionary:
	if a < 0.5:
		var baby := maxf(0.0, 1.0 - a * 5.333)
		var young := maxf(0.0, (a - 0.1875) * 3.2)
		var child := maxf(0.0, minf(1.0, 5.333 * a) - young)
		return {"baby": baby, "child": child, "young": young, "old": 0.0}
	var old := maxf(0.0, a * 2.0 - 1.0)
	return {"baby": 0.0, "child": 0.0, "young": 1.0 - old, "old": old}


static func race_of(spec: Dictionary) -> Dictionary:
	var r: Dictionary = spec.get("race", {"african": 0.0, "asian": 0.5, "caucasian": 0.5})
	var total := 0.0
	for k in ["african", "asian", "caucasian"]:
		total += float(r.get(k, 0.0))
	if total <= 0.0:
		return {"african": 0.0, "asian": 0.5, "caucasian": 0.5}
	return {"african": float(r.get("african", 0.0)) / total, "asian": float(r.get("asian", 0.0)) / total, "caucasian": float(r.get("caucasian", 0.0)) / total}


static func _macro_targets(spec: Dictionary) -> Array:
	var g := _num(spec, "gender", 0.5)
	var gw := {"female": 1.0 - g, "male": g}
	var aw := _age_weights(_age_value(_num(spec, "age", 25.0)))
	var mus := _three(_num(spec, "muscle", 0.5))
	var wei := _three(_num(spec, "weight", 0.5))
	var race := race_of(spec)
	var out: Array = []
	for gk in gw:
		for ak in aw:
			var base_w: float = gw[gk] * aw[ak]
			if base_w <= 0.0:
				continue
			for rk in race:
				if race[rk] > 0.0:
					out.append(["macro/%s-%s-%s" % [rk, gk, ak], base_w * race[rk]])
			for mk in mus:
				for wk in wei:
					var w: float = base_w * mus[mk] * wei[wk]
					if w > 0.0:
						out.append(["macro/universal-%s-%s-%smuscle-%sweight" % [gk, ak, mk, wk], w])
	return out


static func _face_targets(spec: Dictionary) -> Array:
	var out: Array = []
	var sliders: Dictionary = spec.get("face", {})
	var body: Dictionary = spec.get("body", {})
	for dict in [sliders, body]:
		for key in dict:
			if not FACE_SLIDERS.has(key):
				continue
			var v := clampf(float(dict[key]), -1.0, 1.0)
			if absf(v) < 0.001:
				continue
			var pair: Array = FACE_SLIDERS[key]
			for i in range(0, pair.size(), 2):
				var name: String = pair[i + 1] if v > 0.0 else pair[i]
				if name.contains("%s"):
					out.append([name % "l", absf(v)])
					out.append([name % "r", absf(v)])
				else:
					out.append([name, absf(v)])
	if spec.has("face_seed"):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(spec["face_seed"])
		var amount := float(spec.get("face_variety", 0.35))
		var pool: Dictionary = {}
		for name in HumanData.target_names():
			var folder := str(name).get_slice("/", 0)
			if not FACE_GROUPS.has(folder):
				continue
			var file := str(name).get_slice("/", 1)
			var words := ["incr", "decr", "in", "out", "up", "down"]
			var ok := false
			for w in words:
				if file.ends_with("-" + w):
					ok = true
			if not ok:
				continue
			var stem := file.substr(2) if (file.begins_with("l-") or file.begins_with("r-")) else file
			var pkey := folder + "/" + stem
			if not pool.has(pkey):
				pool[pkey] = []
			(pool[pkey] as Array).append(name)
		var keys := pool.keys()
		keys.sort()
		for i in mini(14, keys.size()):
			var pick: int = rng.randi_range(0, keys.size() - 1)
			var w := rng.randf_range(0.15, 1.0) * amount
			for name in pool[keys[pick]]:
				out.append([name, w])
			keys.remove_at(pick)
	return out


static func _morph(spec: Dictionary) -> PackedVector3Array:
	var v := HumanData.verts.duplicate()
	for pair in _macro_targets(spec) + _face_targets(spec):
		var t: Array = HumanData.target(str(pair[0]))
		var idx: PackedInt32Array = t[0]
		var d: PackedVector3Array = t[1]
		var w: float = pair[1]
		for k in idx.size():
			v[idx[k]] += d[k] * w
	return v


static func _group_mean(v: PackedVector3Array, group: String) -> Vector3:
	var idx: PackedInt32Array = HumanData.groups.get(group, PackedInt32Array())
	var s := Vector3.ZERO
	for i in idx:
		s += v[i]
	return s / maxf(idx.size(), 1)


## Animated-film proportions: a bigger head, bigger eyes (around fixed pivots).
static func _stylize_shape(v: PackedVector3Array, spec: Dictionary) -> void:
	var head_scale := float(spec.get("head_scale", 1.0))
	var eye_scale := float(spec.get("eye_scale", 1.0))
	if absf(head_scale - 1.0) < 0.001 and absf(eye_scale - 1.0) < 0.001:
		return
	var neck := _group_mean(v, "joint-neck")
	var head_bone := _bone_index("head")
	var neck_bone := _bone_index("neck_01")
	var el := _group_mean(v, "helper-l-eye")
	var er := _group_mean(v, "helper-r-eye")
	for i in v.size():
		var wh := _weight(i, head_bone) + _weight(i, neck_bone) * 0.45
		var p := v[i]
		if wh > 0.0 and absf(head_scale - 1.0) > 0.001:
			p = neck + (p - neck) * (1.0 + (head_scale - 1.0) * wh)
		if absf(eye_scale - 1.0) > 0.001:
			for e in [el, er]:
				var d: float = (v[i] - e).length()
				var w: float = clampf(1.0 - d / 0.42, 0.0, 1.0)
				w = w * w * (3.0 - 2.0 * w)
				if w > 0.0:
					var pe: Vector3 = neck + (e - neck) * (1.0 + (head_scale - 1.0))
					p += (p - pe) * (eye_scale - 1.0) * w
		v[i] = p


static func _bone_index(name: String) -> int:
	for i in HumanData.bones.size():
		if HumanData.bones[i]["name"] == name:
			return i
	return -1


static func _weight(vertex: int, bone: int) -> float:
	for k in 4:
		if HumanData.w_bones[vertex * 4 + k] == bone:
			return HumanData.w_weights[vertex * 4 + k] / 255.0
	return 0.0


# ------------------------------------------------------------------ build

## The body of [param spec] before any meshes: positions (V, metres), normals,
## skeleton and skin, which garments it wears and which skin they hide.
static func prepare(spec: Dictionary) -> Dictionary:
	if not HumanData.ensure():
		return {}
	var motion := motion_pack()
	if motion.is_empty():
		push_error("HumanBuilder: motion data missing")
		return {}
	var vobj := _morph(spec)
	_stylize_shape(vobj, spec)
	var hscale := lerpf(0.92, 1.08, _num(spec, "height", 0.5))
	var V := PackedVector3Array()
	V.resize(vobj.size())
	for i in V.size():
		V[i] = vobj[i] * 0.1 * hscale
	var body_faces := HumanData.body_faces
	var N := _normals(V, body_faces)
	var outfit: Dictionary = spec.get("outfit", {})

	# garments decide which skin is hidden; imported clothes replace the built-in piece of their slot
	var hidden := {}
	var garment_list: Array = []
	var taken := {}
	var extras: Array = []
	for path in outfit.get("extra", []):
		var info := WardrobeItem.load_item(str(path))
		if info.is_empty():
			continue
		extras.append(info)
		for slot in WardrobeItem.slots_of(info):
			taken[slot] = true
		for f in (info.get("hide", PackedInt32Array()) as PackedInt32Array):
			hidden[f] = true
	for slot in ["top", "bottom", "shoes"]:
		if taken.has(slot):
			continue
		var item: Dictionary = outfit.get(slot, {})
		var style := str(item.get("style", "none"))
		if style == "none" or style == "":
			continue
		var tname: String = ("shoes_" if slot == "shoes" else slot + "_") + style
		if not HumanData.templates.has(tname):
			continue
		garment_list.append([slot, style, tname, item])
		var tpl: Dictionary = HumanData.templates[tname]
		if tpl.has("hide"):
			for f in tpl["hide"]:
				hidden[f] = true

	# shoes and the ground
	var ground := INF
	for f in body_faces:
		for k in 4:
			var vi := HumanData.face_v[f * 4 + k]
			if vi >= 0:
				ground = minf(ground, V[vi].y)
	var shoe_parts: Array = []
	for g in garment_list:
		if g[0] == "shoes":
			var part := _shoes(V, g[2])
			shoe_parts.append([part, g[3], g[1]])
			for p in (part["pos"] as PackedVector3Array):
				ground = minf(ground, p.y)
	var lift := Vector3(0, -ground, 0)
	for i in V.size():
		V[i] += lift

	# skeleton
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	var joints := {}
	for b in HumanData.bones:
		joints[b["name"]] = _group_mean(V, str(b["joint"]))
	var ref: Dictionary = motion["skeleton"]
	var globals := {}
	for name in ref["order"]:
		var idx := skeleton.add_bone(name)
		var parent: String = ref["parent"][name]
		if parent != "":
			skeleton.set_bone_parent(idx, skeleton.find_bone(parent))
		var basis: Basis = ref["basis"][name]
		var origin: Vector3 = joints.get(name, Vector3.ZERO)
		var global := Transform3D(basis, origin)
		globals[name] = global
		var local := global if parent == "" else (globals[parent] as Transform3D).affine_inverse() * global
		skeleton.set_bone_rest(idx, local)
	skeleton.reset_bone_poses()
	var bone_map := PackedInt32Array()
	for b in HumanData.bones:
		bone_map.append(skeleton.find_bone(str(b["name"])))
	var skin := Skin.new()
	for i in skeleton.get_bone_count():
		skin.add_named_bind(skeleton.get_bone_name(i), skeleton.get_bone_global_rest(i).affine_inverse())

	var root := Node3D.new()
	root.name = "Model"
	root.add_child(skeleton)
	var ctx := {"V": V, "N": N, "spec": spec, "skeleton": skeleton, "skin": skin, "bone_map": bone_map,
		"stylize": _num(spec, "stylize", 1.0 if spec.get("type", "") == "pixar" else 0.0), "hscale": hscale,
		"root": root, "hidden": hidden, "garments": garment_list, "shoe_parts": shoe_parts, "extras": extras, "taken": taken,
		"vobj": vobj, "lift": lift}
	return ctx



static func _build(spec: Dictionary) -> Node3D:
	var ctx := prepare(spec)
	if ctx.is_empty():
		return null
	var root: Node3D = ctx["root"]
	var hidden: Dictionary = ctx["hidden"]
	var garment_list: Array = ctx["garments"]
	var shoe_parts: Array = ctx["shoe_parts"]
	var skeleton: Skeleton3D = ctx["skeleton"]
	var outfit: Dictionary = spec.get("outfit", {})
	_body(ctx, hidden)
	_eyes(ctx, ctx["vobj"], ctx["lift"])
	for g in garment_list:
		if g[0] != "shoes":
			_garment(ctx, g[0], g[1], g[2], g[3])
	for s in shoe_parts:
		_shoe_mesh(ctx, s[0], s[1], s[2])
	if not (ctx["taken"] as Dictionary).has("hair"):
		_hair(ctx)
	_beard(ctx)
	for info in ctx["extras"]:
		var mi := WardrobeItem.fit(info, ctx)
		if mi:
			skeleton.add_child(mi)
			mi.skeleton = NodePath("..")
	for child in skeleton.get_children():
		child.owner = root
	skeleton.owner = root
	return root


static func _normals(V: PackedVector3Array, faces: PackedInt32Array) -> PackedVector3Array:
	var N := PackedVector3Array()
	N.resize(V.size())
	for f in faces:
		var a := HumanData.face_v[f * 4]
		var b := HumanData.face_v[f * 4 + 1]
		var c := HumanData.face_v[f * 4 + 2]
		var d := HumanData.face_v[f * 4 + 3]
		var n: Vector3
		if d >= 0:
			n = (V[c] - V[a]).cross(V[d] - V[b])
		else:
			n = (V[b] - V[a]).cross(V[c] - V[a])
		N[a] += n
		N[b] += n
		N[c] += n
		if d >= 0:
			N[d] += n
	for i in N.size():
		N[i] = N[i].normalized() if N[i].length_squared() > 0.0 else Vector3.UP
	return N


# ------------------------------------------------------------------ mesh helpers

## A skinned mesh from per-corner data. corners: [[vertex key, position, normal, uv, bones(4), weights(4)]].
class Builder:
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var uv := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var index := PackedInt32Array()
	var keys := {}
	var shapes: Dictionary = {}      # name -> PackedVector3Array (absolute positions, filled later)
	var source := PackedInt32Array() # base vertex per output vertex (-1 = none)

	func vertex(key: Variant, p: Vector3, n: Vector3, t: Vector2, b: PackedInt32Array, w: PackedFloat32Array, base_vertex := -1) -> int:
		if keys.has(key):
			return keys[key]
		var i := pos.size()
		keys[key] = i
		pos.append(p)
		nor.append(n)
		uv.append(t)
		bones.append_array(b)
		weights.append_array(w)
		source.append(base_vertex)
		return i

	## Godot treats clockwise triangles as front faces: our quads are counter-clockwise.
	func face(ids: Array) -> void:
		for k in range(1, ids.size() - 1):
			index.append(ids[0])
			index.append(ids[k + 1])
			index.append(ids[k])

	func tangents() -> PackedFloat32Array:
		var tan := PackedVector3Array()
		var bit := PackedVector3Array()
		tan.resize(pos.size())
		bit.resize(pos.size())
		for k in range(0, index.size(), 3):
			var i0 := index[k]
			var i1 := index[k + 1]
			var i2 := index[k + 2]
			var e1 := pos[i1] - pos[i0]
			var e2 := pos[i2] - pos[i0]
			var d1 := uv[i1] - uv[i0]
			var d2 := uv[i2] - uv[i0]
			var r := d1.x * d2.y - d2.x * d1.y
			if absf(r) < 1e-12:
				continue
			r = 1.0 / r
			var t := (e1 * d2.y - e2 * d1.y) * r
			var bt := (e2 * d1.x - e1 * d2.x) * r
			for i in [i0, i1, i2]:
				tan[i] += t
				bit[i] += bt
		var out := PackedFloat32Array()
		out.resize(pos.size() * 4)
		for i in pos.size():
			var n := nor[i]
			var t := tan[i] - n * n.dot(tan[i])
			if t.length_squared() < 1e-12:
				t = n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT)
			t = t.normalized()
			var w := -1.0 if n.cross(t).dot(bit[i]) < 0.0 else 1.0
			out[i * 4] = t.x
			out[i * 4 + 1] = t.y
			out[i * 4 + 2] = t.z
			out[i * 4 + 3] = w
		return out

	func arrays() -> Array:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = pos
		a[Mesh.ARRAY_NORMAL] = nor
		a[Mesh.ARRAY_TANGENT] = tangents()
		a[Mesh.ARRAY_TEX_UV] = uv
		a[Mesh.ARRAY_BONES] = bones
		a[Mesh.ARRAY_WEIGHTS] = weights
		a[Mesh.ARRAY_INDEX] = index
		return a


static func _base_skin(vertex: int, bone_map: PackedInt32Array) -> Array:
	var b := PackedInt32Array()
	var w := PackedFloat32Array()
	for k in 4:
		b.append(maxi(bone_map[HumanData.w_bones[vertex * 4 + k]], 0))
		w.append(HumanData.w_weights[vertex * 4 + k] / 255.0)
	return [b, w]


static func _mix_skin(a: int, b: int, t: float, bone_map: PackedInt32Array) -> Array:
	if t <= 0.0001 or a == b:
		return _base_skin(a, bone_map)
	var acc := {}
	for k in 4:
		var ba := bone_map[HumanData.w_bones[a * 4 + k]]
		var bb := bone_map[HumanData.w_bones[b * 4 + k]]
		acc[ba] = float(acc.get(ba, 0.0)) + HumanData.w_weights[a * 4 + k] / 255.0 * (1.0 - t)
		acc[bb] = float(acc.get(bb, 0.0)) + HumanData.w_weights[b * 4 + k] / 255.0 * t
	var pairs: Array = []
	for k in acc:
		pairs.append([k, acc[k]])
	pairs.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) > float(y[1]))
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var total := 0.0
	for i in 4:
		if i < pairs.size():
			bones.append(maxi(int(pairs[i][0]), 0))
			weights.append(float(pairs[i][1]))
			total += float(pairs[i][1])
		else:
			bones.append(0)
			weights.append(0.0)
	for i in 4:
		weights[i] /= maxf(total, 1e-6)
	return [bones, weights]


static func _single_bone(bone: int) -> Array:
	return [PackedInt32Array([bone, 0, 0, 0]), PackedFloat32Array([1.0, 0.0, 0.0, 0.0])]


static func _add_mesh(ctx: Dictionary, name: String, surfaces: Array, shape_names := []) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for s in shape_names:
		mesh.add_blend_shape(s)
	for surface in surfaces:
		var b: Builder = surface[0]
		if b.index.is_empty():
			continue
		var blends: Array = []
		var base_arrays := b.arrays()
		# Godot's relative blend shapes take offsets from the base mesh.
		var zero_n := PackedVector3Array()
		zero_n.resize(b.pos.size())
		var zero_t := PackedFloat32Array()
		zero_t.resize(b.pos.size() * 4)
		for s in shape_names:
			var shape: PackedVector3Array = b.shapes.get(s, b.pos)
			var delta := PackedVector3Array()
			delta.resize(b.pos.size())
			for i in delta.size():
				delta[i] = shape[i] - b.pos[i]
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = delta
			arr[Mesh.ARRAY_NORMAL] = zero_n
			arr[Mesh.ARRAY_TANGENT] = zero_t
			blends.append(arr)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, base_arrays, blends)
		mesh.surface_set_material(mesh.get_surface_count() - 1, surface[1])
		if surface.size() > 2:
			mesh.surface_set_name(mesh.get_surface_count() - 1, surface[2])
	if mesh.get_surface_count() == 0:
		return null
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.skin = ctx["skin"]
	(ctx["skeleton"] as Skeleton3D).add_child(mi)
	mi.skeleton = NodePath("..")
	return mi


static func _tex(file: String) -> Texture2D:
	if not _textures.has(file):
		_textures[file] = load(TEX + file)
	return _textures[file]


static func _shader(file: String) -> Shader:
	if not _shaders.has(file):
		_shaders[file] = load(SHADERS + file)
	return _shaders[file]


static func colour(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and (value as Array).size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]))
	if value is String and str(value).length() > 0:
		var s := str(value)
		if s.begins_with("#") or s.is_valid_html_color():
			return Color.html(s)
		var named := Color.from_string(s, Color(-1, -1, -1))
		if named.r >= 0.0:
			return named
	return fallback


# ------------------------------------------------------------------ parts

static func skin_tone(spec: Dictionary) -> Color:
	if spec.has("skin"):
		return colour(spec["skin"], Color(0.78, 0.58, 0.46))
	var r := race_of(spec)
	var c: Color = Color(0.42, 0.27, 0.19) * r["african"] + Color(0.80, 0.62, 0.50) * r["asian"] + Color(0.88, 0.70, 0.60) * r["caucasian"]
	return Color(c.r, c.g, c.b)


static func _skin_material(ctx: Dictionary) -> ShaderMaterial:
	var spec: Dictionary = ctx["spec"]
	var m := ShaderMaterial.new()
	m.shader = _shader("skin.gdshader")
	m.set_shader_parameter("skin_a", _tex("skin_a.png"))
	m.set_shader_parameter("skin_b", _tex("skin_b.png"))
	m.set_shader_parameter("skin_c", _tex("skin_c.png"))
	m.set_shader_parameter("wrinkles_n", _tex("skin_wrinkles_n.png"))
	m.set_shader_parameter("pores_n", _tex("pores_n.png"))
	var tone := skin_tone(spec)
	m.set_shader_parameter("tone", tone)
	var hair: Dictionary = spec.get("hair", {})
	var hair_col := colour(hair.get("color", "#1a1310"), Color(0.08, 0.06, 0.05))
	m.set_shader_parameter("hair_color", hair_col)
	m.set_shader_parameter("brow_color", colour(spec.get("brows", ""), hair_col.darkened(0.1)))
	var gender := _num(spec, "gender", 0.5)
	var default_lips := tone * Color(0.92, 0.66, 0.66)
	m.set_shader_parameter("lip_color", colour(spec.get("lips", ""), Color(default_lips.r, default_lips.g, default_lips.b)))
	m.set_shader_parameter("lip_strength", float(spec.get("lip_strength", 0.85 - 0.3 * gender)))
	var beard: Dictionary = spec.get("beard", {})
	var beard_style := str(beard.get("style", "none"))
	m.set_shader_parameter("stubble", {"none": 0.0, "stubble": 0.7, "short": 0.9, "full": 1.0}.get(beard_style, 0.0) * (1.0 if spec.get("type", "") != "pixar" else 0.3))
	m.set_shader_parameter("freckles", float(spec.get("freckles", 0.0)))
	m.set_shader_parameter("blush", float(spec.get("blush", 0.25 + (0.15 if _num(spec, "age", 25) < 14 else 0.0))))
	var age := _num(spec, "age", 25.0)
	var auto_wrinkles := clampf((age - 32.0) / 40.0, 0.0, 1.0) * 1.2 + 0.03
	m.set_shader_parameter("wrinkles", float(spec.get("wrinkles", auto_wrinkles)) if float(spec.get("wrinkles", -1.0)) >= 0.0 else auto_wrinkles)
	m.set_shader_parameter("makeup", float(spec.get("makeup", 0.0)))
	m.set_shader_parameter("makeup_color", colour(spec.get("makeup_color", "#3a2a33"), Color(0.23, 0.16, 0.2)))
	var style := str(hair.get("style", "short"))
	var cap: Array = CAPS.get(style, ["", 0.5])
	m.set_shader_parameter("scalp", 0.0 if style == "bald" or style == "" else (0.55 if style == "buzz" else 0.9))
	m.set_shader_parameter("scalp_edge", float(cap[1]))
	m.set_shader_parameter("stylize", float(ctx["stylize"]))
	m.set_shader_parameter("pores", 0.6 if age >= 14 else 0.35)
	return m


## Gives avatars made from the MakeHuman body (Avatar Studio / MPFB, the 1.22
## people) Scene Builder's skin: their own colours with pores, fine wrinkles,
## glossy lips and light scattering under the skin. Returns how many were changed.
static func upgrade_skin(model: Node) -> int:
	var count := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if not (mat is BaseMaterial3D):
				continue
			var name := (mat.resource_name + " " + String(mi.name)).to_lower()
			if not (name.contains("body") or name.contains("skin")) or name.contains("eye") or name.contains("cloth"):
				continue
			var bm := mat as BaseMaterial3D
			var m := ShaderMaterial.new()
			m.resource_name = mat.resource_name
			m.shader = _shader("skin.gdshader")
			m.set_shader_parameter("skin_a", _tex("skin_a.png"))
			m.set_shader_parameter("skin_b", _tex("skin_b.png"))
			m.set_shader_parameter("skin_c", _tex("skin_c.png"))
			m.set_shader_parameter("wrinkles_n", _tex("skin_wrinkles_n.png"))
			m.set_shader_parameter("pores_n", _tex("pores_n.png"))
			m.set_shader_parameter("use_albedo", 1.0 if bm.albedo_texture else 0.0)
			if bm.albedo_texture:
				m.set_shader_parameter("albedo_tex", bm.albedo_texture)
				m.set_shader_parameter("tone", Color(bm.albedo_color.r, bm.albedo_color.g, bm.albedo_color.b))
			else:
				m.set_shader_parameter("tone", bm.albedo_color)
			m.set_shader_parameter("lip_strength", 0.0)
			m.set_shader_parameter("brow_strength", 0.0)
			m.set_shader_parameter("blush", 0.0)
			m.set_shader_parameter("wrinkles", 0.3)
			m.set_meta("sb_skin", true)
			mi.set_surface_override_material(i, m)
			count += 1
	return count


static func _body(ctx: Dictionary, hidden: Dictionary) -> void:
	var V: PackedVector3Array = ctx["V"]
	var N: PackedVector3Array = ctx["N"]
	var bone_map: PackedInt32Array = ctx["bone_map"]
	var groups := HumanData.face_groups
	var surfaces := {"skin": Builder.new(), "teeth": Builder.new(), "tongue": Builder.new(), "lashes": Builder.new()}
	var lash_box := {}
	for f in HumanData.face_v.size() / 4:
		var g: String = groups[HumanData.face_g[f]]
		if g.begins_with("helper-") and g.contains("eyelashes"):
			for k in 4:
				var ti := HumanData.face_t[f * 4 + k]
				if ti < 0:
					continue
				var box: Rect2 = lash_box.get(g, Rect2(HumanData.uvs[ti], Vector2.ZERO))
				lash_box[g] = box.expand(HumanData.uvs[ti])
	var skin_faces := 0
	for f in HumanData.face_v.size() / 4:
		var g: String = groups[HumanData.face_g[f]]
		var target := ""
		if g == "body":
			if hidden.has(skin_faces):
				skin_faces += 1
				continue
			skin_faces += 1
			target = "skin"
		elif g.ends_with("teeth"):
			target = "teeth"
		elif g == "helper-tongue":
			target = "tongue"
		elif g.contains("eyelashes") and bool((ctx["spec"] as Dictionary).get("lashes", false)):
			target = "lashes"
		else:
			continue
		var b: Builder = surfaces[target]
		var ids: Array = []
		for k in 4:
			var vi := HumanData.face_v[f * 4 + k]
			if vi < 0:
				continue
			var ti := HumanData.face_t[f * 4 + k]
			var t := HumanData.uvs[maxi(ti, 0)]
			if target == "lashes":
				var box: Rect2 = lash_box[g]
				t = Vector2((t.x - box.position.x) / maxf(box.size.x, 1e-6), (t.y - box.position.y) / maxf(box.size.y, 1e-6))
			var sk := _base_skin(vi, bone_map)
			ids.append(b.vertex(vi * 100000 + maxi(ti, 0), V[vi], N[vi], t, sk[0], sk[1], vi))
		b.face(ids)
	# lash normals point out of the face
	# expressions
	var shape_names: Array = EXPRESSIONS.keys()
	var race := race_of(ctx["spec"])
	var scale := 0.1 * float(ctx["hscale"])
	for s in shape_names:
		var delta := {}
		for unit in EXPRESSIONS[s]:
			for rk in race:
				if race[rk] <= 0.0:
					continue
				var t: Array = HumanData.target("expr/%s/%s" % [rk, unit[0]])
				var idx: PackedInt32Array = t[0]
				var d: PackedVector3Array = t[1]
				var w: float = float(unit[1]) * race[rk]
				for k in idx.size():
					delta[idx[k]] = (delta.get(idx[k], Vector3.ZERO) as Vector3) + d[k] * w * scale
		for key in surfaces:
			var b: Builder = surfaces[key]
			var p := b.pos.duplicate()
			for i in p.size():
				var src := b.source[i]
				if src >= 0 and delta.has(src):
					p[i] += delta[src]
			b.shapes[s] = p
	var skin_mat := _skin_material(ctx)
	var teeth := StandardMaterial3D.new()
	teeth.albedo_color = Color(0.86, 0.83, 0.76)
	teeth.roughness = 0.25
	var tongue := StandardMaterial3D.new()
	tongue.albedo_color = Color(0.62, 0.28, 0.28)
	tongue.roughness = 0.4
	var lashes := StandardMaterial3D.new()
	lashes.albedo_color = Color(0.03, 0.025, 0.02)
	lashes.albedo_texture = _tex("lashes.png")
	lashes.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	lashes.alpha_scissor_threshold = 0.35
	lashes.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(ctx, "Body", [[surfaces["skin"], skin_mat, "skin"], [surfaces["teeth"], teeth, "teeth"],
		[surfaces["tongue"], tongue, "tongue"], [surfaces["lashes"], lashes, "eyelashes"]], shape_names)


static func _eyes(ctx: Dictionary, vobj: PackedVector3Array, lift: Vector3) -> void:
	var e: Dictionary = HumanData.eyes
	var sc: Dictionary = e["scales"]
	var sv := Vector3.ONE
	var axes := {"x": 0, "y": 1, "z": 2}
	for axis in axes:
		var s: Array = sc[axis]
		var a: Vector3 = vobj[int(s[0])]
		var b: Vector3 = vobj[int(s[1])]
		sv[axes[axis]] = absf(a[axes[axis]] - b[axes[axis]]) / float(s[2])
	var scale := 0.1 * float(ctx["hscale"])
	var refs: Array = e["refs"]
	var pts := PackedVector3Array()
	for r in refs:
		var vi: Array = r[0]
		var w: Array = r[1]
		var off: Array = r[2]
		var p: Vector3 = vobj[int(vi[0])] * float(w[0]) + vobj[int(vi[1])] * float(w[1]) + vobj[int(vi[2])] * float(w[2])
		p += Vector3(float(off[0]) * sv.x, float(off[1]) * sv.y, float(off[2]) * sv.z)
		pts.append(p * scale + lift)
	var uvl: Array = e["uvs"]
	var b := Builder.new()
	var head := (ctx["skeleton"] as Skeleton3D).find_bone("head")
	var sk := _single_bone(head)
	var faces: Array = e["faces"]
	var fuv: Array = e["fuv"]
	# normals: away from each eyeball's centre
	var centre_l := Vector3.ZERO
	var centre_r := Vector3.ZERO
	var nl := 0
	var nr := 0
	for p in pts:
		if p.x > 0.0:
			centre_l += p
			nl += 1
		else:
			centre_r += p
			nr += 1
	centre_l /= maxf(nl, 1)
	centre_r /= maxf(nr, 1)
	for fi in faces.size():
		var f: Array = faces[fi]
		var ids: Array = []
		for k in f.size():
			var vi := int(f[k])
			var ti := int(fuv[fi][k])
			var p := pts[vi]
			var c := centre_l if p.x > 0.0 else centre_r
			var uvv: Array = uvl[ti]
			ids.append(b.vertex(vi * 100000 + ti, p, (p - c).normalized(), Vector2(float(uvv[0]), 1.0 - float(uvv[1])), sk[0], sk[1]))
		b.face(ids)
	var m := ShaderMaterial.new()
	m.shader = _shader("eye.gdshader")
	m.set_shader_parameter("eye", _tex("eye.png"))
	m.set_shader_parameter("iris", colour(ctx["spec"].get("eyes", "#4a2c14"), Color(0.29, 0.17, 0.08)))
	m.set_shader_parameter("stylize", float(ctx["stylize"]))
	_add_mesh(ctx, "Eyes", [[b, m, "eyes"]])


static func cloth_material(item: Dictionary, style: String, stylize: float) -> ShaderMaterial:
	var fabric := str(item.get("fabric", DEFAULT_FABRIC.get(style, "cotton")))
	if not FABRICS.has(fabric):
		fabric = "cotton"
	var look: Array = FABRIC_LOOK[fabric]
	var m := ShaderMaterial.new()
	m.shader = _shader("cloth.gdshader")
	m.set_shader_parameter("fabric", _tex("fab_%s.png" % fabric))
	m.set_shader_parameter("folds_n", _tex("folds_n.png"))
	m.set_shader_parameter("folds_ao", _tex("folds_ao.png"))
	m.set_shader_parameter("color", colour(item.get("color", "#777777"), Color(0.47, 0.47, 0.47)))
	m.set_shader_parameter("roughness", float(item.get("rough", look[0])))
	m.set_shader_parameter("sheen", float(look[1]))
	m.set_shader_parameter("stylize", stylize)
	m.set_shader_parameter("fold_depth", 0.0 if style == "skirt" else (0.6 if style == "leggings" else 1.0))
	m.set_shader_parameter("fabric_scale", 4.0 if style == "skirt" else 30.0)
	return m


static func _garment(ctx: Dictionary, slot: String, style: String, tname: String, item: Dictionary) -> void:
	var V: PackedVector3Array = ctx["V"]
	var N: PackedVector3Array = ctx["N"]
	var bone_map: PackedInt32Array = ctx["bone_map"]
	var t: Dictionary = HumanData.templates[tname]
	var ia: PackedInt32Array = t["ia"]
	var ib: PackedInt32Array = t["ib"]
	var tt: PackedFloat32Array = t["t"]
	var n := ia.size()
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	pos.resize(n)
	nor.resize(n)
	for i in n:
		pos[i] = V[ia[i]].lerp(V[ib[i]], tt[i])
		nor[i] = N[ia[i]].lerp(N[ib[i]], tt[i]).normalized()
	var offset: PackedFloat32Array = t.get("offset", PackedFloat32Array())
	var loose := float(item.get("loose", 1.0)) * float(ctx["hscale"])
	if style == "skirt":
		# MakeHuman's skirt helper is a shell already; widen it a little and flare the hem
		var minz := INF
		var maxz := -INF
		for p in pos:
			minz = minf(minz, p.y)
			maxz = maxf(maxz, p.y)
		var length := float(item.get("length", 1.0))
		for i in n:
			var down := clampf((maxz - pos[i].y) / maxf(maxz - minz, 0.01), 0.0, 1.0)
			var radial := Vector3(nor[i].x, 0, nor[i].z)
			pos[i] += radial * (0.006 + 0.03 * down * down)
			if length < 1.0 and down > length:
				pos[i].y = maxz - (maxz - minz) * length - (down - length) * 0.02
	else:
		var raw := pos.duplicate()
		var iterations := int(item.get("smooth", 14 if slot == "top" else 8))
		if iterations > 0:
			var er: Array = HumanData.template_edges(tname)
			var edges: PackedInt32Array = er[0]
			var rim: PackedByteArray = er[1]
			for _it in iterations:
				var acc := PackedVector3Array()
				acc.resize(n)
				var cnt := PackedInt32Array()
				cnt.resize(n)
				for k in range(0, edges.size(), 2):
					var a := edges[k]
					var b := edges[k + 1]
					acc[a] += pos[b]
					acc[b] += pos[a]
					cnt[a] += 1
					cnt[b] += 1
				for i in n:
					if rim[i] == 0 and cnt[i] > 0:
						pos[i] = pos[i] * 0.4 + acc[i] / cnt[i] * 0.6
		for i in n:
			var under := (pos[i] - raw[i]).dot(nor[i])
			if under < 0.0:
				pos[i] -= nor[i] * under
			pos[i] += nor[i] * (offset[i] if i < offset.size() else 0.006) * loose
	var b := Builder.new()
	var counts: PackedByteArray = t["counts"]
	var faces: PackedInt32Array = t["faces"]
	var uvs: PackedFloat32Array = t["uvs"]
	var p0 := 0
	var skirt_c := Vector3.ZERO
	if style == "skirt":
		for p in pos:
			skirt_c += p
		skirt_c /= maxf(n, 1)
	for c in counts:
		var ids: Array = []
		for k in c:
			var vi := faces[p0 + k]
			var uv := Vector2(uvs[(p0 + k) * 2], 1.0 - uvs[(p0 + k) * 2 + 1])
			if style == "skirt":
				var rel := pos[vi] - skirt_c
				uv = Vector2(atan2(rel.x, rel.z) / TAU + 0.5, -pos[vi].y)
			var sk := _mix_skin(ia[vi], ib[vi], tt[vi], bone_map)
			ids.append(b.vertex(vi * 1000 + roundi(uv.x * 997) * 7 + roundi(uv.y * 991) * 13, pos[vi], nor[vi], uv, sk[0], sk[1]))
		b.face(ids)
		p0 += c
	var mat := cloth_material(item, style, float(ctx["stylize"]))
	var names := {"top": "Shirt", "bottom": "Trousers"}
	_add_mesh(ctx, names.get(slot, slot.capitalize()), [[b, mat, style]])


static func _shoes(V: PackedVector3Array, tname: String) -> Dictionary:
	var t: Dictionary = HumanData.templates[tname]
	var ia: PackedInt32Array = t["ia"]
	var rel: PackedFloat32Array = t["rel"]
	var pos := PackedVector3Array()
	pos.resize(ia.size())
	for i in ia.size():
		pos[i] = V[ia[i]] + Vector3(rel[i * 3], rel[i * 3 + 1], rel[i * 3 + 2]) * 0.1
	return {"pos": pos, "tname": tname}


static func _shoe_mesh(ctx: Dictionary, part: Dictionary, item: Dictionary, style: String) -> void:
	var t: Dictionary = HumanData.templates[part["tname"]]
	var ia: PackedInt32Array = t["ia"]
	var pos: PackedVector3Array = part["pos"]
	var lift := Vector3(0, 0, 0)
	var V: PackedVector3Array = ctx["V"]
	# positions were made before the lift: redo from the lifted body
	pos = _shoes(V, part["tname"])["pos"]
	var counts: PackedByteArray = t["counts"]
	var faces: PackedInt32Array = t["faces"]
	var sole: PackedFloat32Array = t["sole"]
	var bone_map: PackedInt32Array = ctx["bone_map"]
	# per-side centres to orient faces outward
	var cl := Vector3.ZERO
	var cr := Vector3.ZERO
	var nl := 0
	var nr := 0
	for p in pos:
		if p.x > 0.0:
			cl += p
			nl += 1
		else:
			cr += p
			nr += 1
	cl /= maxf(nl, 1)
	cr /= maxf(nr, 1)
	var normals := PackedVector3Array()
	normals.resize(pos.size())
	var face_list: Array = []
	var p0 := 0
	for fi in counts.size():
		var c := counts[fi]
		var f: Array = []
		for k in c:
			f.append(faces[p0 + k])
		p0 += c
		var a := pos[f[0]]
		var n := (pos[f[1]] - a).cross(pos[f[2]] - a)
		var centre := Vector3.ZERO
		for vi in f:
			centre += pos[vi]
		centre /= f.size()
		var mid := cl if centre.x > 0.0 else cr
		if n.dot(centre - mid) < 0.0:
			f.reverse()
			n = -n
		for vi in f:
			normals[vi] += n
		face_list.append([f, sole[fi] > 0.5])
	var upper := Builder.new()
	var bottom := Builder.new()
	for entry in face_list:
		var f: Array = entry[0]
		var b: Builder = bottom if entry[1] else upper
		var ids: Array = []
		for vi in f:
			var sk := _base_skin(ia[vi], bone_map)
			var p := pos[vi]
			ids.append(b.vertex(vi, p, normals[vi].normalized(), Vector2(p.x * 6.0, p.y * 6.0 + p.z * 6.0), sk[0], sk[1]))
		# Builder.face expects counter-clockwise (outward) order
		b.face(ids)
	var m := cloth_material({"color": item.get("color", "#3b2a1e"), "fabric": item.get("fabric", "leather"), "rough": item.get("rough", 0.45)}, style, float(ctx["stylize"]))
	m.set_shader_parameter("fold_depth", 0.0)
	m.set_shader_parameter("fabric_scale", 3.0)
	var sole_default := "#f2f2ee" if style == "sneakers" else "#1c1a18"
	var sm := cloth_material({"color": item.get("sole", sole_default), "fabric": "rain", "rough": 0.8}, style, float(ctx["stylize"]))
	sm.set_shader_parameter("fold_depth", 0.0)
	_add_mesh(ctx, "Shoes", [[upper, m, "shoe"], [bottom, sm, "sole"]])


static func _hair_material(ctx: Dictionary, mode: int, layer: float, threshold: float, edge: float) -> ShaderMaterial:
	var spec: Dictionary = ctx["spec"]
	var hair: Dictionary = spec.get("hair", {})
	var m := ShaderMaterial.new()
	m.shader = _shader("hair.gdshader")
	m.set_shader_parameter("strands", _tex("hair_cards.png" if mode == 2 else "hair.png"))
	var col := colour(hair.get("color", "#1a1310"), Color(0.08, 0.06, 0.05))
	if mode == 1:
		col = colour((spec.get("beard", {}) as Dictionary).get("color", hair.get("color", "#1a1310")), col)
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("layer", layer)
	m.set_shader_parameter("threshold", threshold)
	m.set_shader_parameter("edge", edge)
	m.set_shader_parameter("gloss", float(hair.get("gloss", 0.3)))
	m.set_shader_parameter("stylize", float(ctx["stylize"]))
	return m


static func _shell(ctx: Dictionary, tname: String, offsets: Array, mats: Array, name: String) -> void:
	var V: PackedVector3Array = ctx["V"]
	var N: PackedVector3Array = ctx["N"]
	var bone_map: PackedInt32Array = ctx["bone_map"]
	var t: Dictionary = HumanData.templates[tname]
	var ia: PackedInt32Array = t["ia"]
	var ib: PackedInt32Array = t["ib"]
	var tt: PackedFloat32Array = t["t"]
	var hv: PackedFloat32Array = t.get("h", PackedFloat32Array())
	var counts: PackedByteArray = t["counts"]
	var faces: PackedInt32Array = t["faces"]
	var uvs: PackedFloat32Array = t["uvs"]
	var surfaces: Array = []
	var s := float(ctx["hscale"])
	for L in offsets.size():
		var b := Builder.new()
		var p0 := 0
		for c in counts:
			var ids: Array = []
			for k in c:
				var vi := faces[p0 + k]
				var base_p := V[ia[vi]].lerp(V[ib[vi]], tt[vi])
				var n := N[ia[vi]].lerp(N[ib[vi]], tt[vi]).normalized()
				var taper := clampf((hv[vi] if vi < hv.size() else 0.03) / 0.035, 0.0, 1.0)
				taper = taper * taper * (3.0 - 2.0 * taper)
				var off: Array = offsets[L]
				var d := (float(off[0]) + float(off[1]) * taper) * s
				var uv := Vector2(uvs[(p0 + k) * 2], 1.0 - uvs[(p0 + k) * 2 + 1])
				var sk := _mix_skin(ia[vi], ib[vi], tt[vi], bone_map)
				ids.append(b.vertex(vi * 1000 + roundi(uv.x * 997) * 7 + roundi(uv.y * 991) * 13, base_p + n * d, n, uv, sk[0], sk[1]))
			b.face(ids)
			p0 += c
		surfaces.append([b, mats[L], "layer%d" % L])
	_add_mesh(ctx, name, surfaces)


static func _hair(ctx: Dictionary) -> void:
	var spec: Dictionary = ctx["spec"]
	var hair: Dictionary = spec.get("hair", {})
	var style := str(hair.get("style", "short"))
	if style == "bald" or not CAPS.has(style):
		return
	var cap: Array = CAPS[style]
	var edge := float(cap[1])
	var cards := CARD_STYLES.has(style) and float(ctx["stylize"]) < 0.7
	# The scalp under the hair (and the whole hair for buzz cuts and the film look).
	var layers := 1 if style == "buzz" else (2 if cards else 6)
	var vol := float(hair.get("volume", 1.0)) * (0.35 if style == "buzz" else (1.5 if style in ["bob", "long", "ponytail", "bun", "pigtails"] else 1.0))
	var offsets: Array = []
	var mats: Array = []
	for L in layers:
		offsets.append([0.0012 + 0.0012 * L, (0.0018 * L * vol) if L > 0 else 0.0008])
		mats.append(_hair_material(ctx, 0, float(L), 0.26 + 0.09 * L, edge))
	_shell(ctx, cap[0], offsets, mats, "Hair")
	if cards:
		_card_hair(ctx, style)
	if style in ["ponytail", "pigtails", "bun"]:
		_tails(ctx, style)
	elif not cards and style in ["bob", "long"]:
		_card_hair(ctx, style)


static func _beard(ctx: Dictionary) -> void:
	var spec: Dictionary = ctx["spec"]
	var style := str((spec.get("beard", {}) as Dictionary).get("style", "none"))
	if not style in ["short", "full"]:
		return
	var offsets: Array = []
	var mats: Array = []
	var layers := 2 if style == "short" else 4
	for L in layers:
		offsets.append([0.001 + 0.0018 * L * (1.0 if style == "short" else 1.8), 0.0])
		mats.append(_hair_material(ctx, 1, float(L), 0.25 + 0.12 * L, 0.5))
	_shell(ctx, "beard", offsets, mats, "Beard")


## Head centre, radius and a table of how far the head reaches in every
## direction at every height (for laying hair on it).
static func _head_info(ctx: Dictionary) -> Dictionary:
	if ctx.has("head_info"):
		return ctx["head_info"]
	var V: PackedVector3Array = ctx["V"]
	var sk: Skeleton3D = ctx["skeleton"]
	var head := sk.find_bone("head")
	var neck := sk.find_bone("neck_01")
	var bm: PackedInt32Array = ctx["bone_map"]
	var pts := PackedVector3Array()
	var top := -INF
	for f in HumanData.body_faces:
		for k in 4:
			var vi := HumanData.face_v[f * 4 + k]
			if vi < 0:
				continue
			var b0 := bm[HumanData.w_bones[vi * 4]]
			if (b0 == head or b0 == neck) and HumanData.w_weights[vi * 4] > 150:
				pts.append(V[vi])
				top = maxf(top, V[vi].y)
	var c := Vector3.ZERO
	var n := 0
	for p in pts:
		if p.y > top - 0.12:
			c += p
			n += 1
	c /= maxf(n, 1)
	var r := 0.0
	var table := {}
	for p in pts:
		var d := Vector2(p.x - c.x, p.z - c.z)
		if p.y > c.y:
			r = maxf(r, d.length())
		var key := Vector2i(posmod(roundi(atan2(d.x, d.y) / TAU * 48.0), 48), roundi((p.y - c.y) / 0.006))
		table[key] = maxf(float(table.get(key, 0.0)), d.length())
	var info := {"center": c, "radius": r, "top": top, "points": pts, "table": table}
	ctx["head_info"] = info
	return info


## How far the head (or neck) reaches from its centre axis in direction [param d] at height y.
static func _head_reach(info: Dictionary, d: Vector3, y: float) -> float:
	var c: Vector3 = info["center"]
	var table: Dictionary = info["table"]
	var a := posmod(roundi(atan2(d.x, d.z) / TAU * 48.0), 48)
	var h := roundi((y - c.y) / 0.006)
	var best := 0.0
	for dh in [0, 1, -1, 2, -2]:
		for da in [0, 1, -1]:
			var key := Vector2i(posmod(a + da, 48), h + dh)
			if table.has(key):
				best = maxf(best, float(table[key]))
		if best > 0.0:
			return best
	return 0.0


## Body cross-section at a height: half width (x) and half depth (z) of the torso.
static func _torso_section(ctx: Dictionary, y: float) -> Vector4:
	var V: PackedVector3Array = ctx["V"]
	var sk: Skeleton3D = ctx["skeleton"]
	var spine := sk.get_bone_global_rest(sk.find_bone("spine_03")).origin
	var hx := 0.0
	var front := 0.0
	var back := 0.0
	var bm: PackedInt32Array = ctx["bone_map"]
	for f in HumanData.body_faces:
		var vi := HumanData.face_v[f * 4]
		var p := V[vi]
		if absf(p.y - y) > 0.02:
			continue
		var bone := sk.get_bone_name(bm[HumanData.w_bones[vi * 4]])
		if bone.begins_with("upperarm") or bone.begins_with("lowerarm") or bone.begins_with("hand"):
			continue
		hx = maxf(hx, absf(p.x - spine.x))
		front = maxf(front, p.z - spine.z)
		back = maxf(back, spine.z - p.z)
	return Vector4(hx, front, back, spine.z)


## Hair styles made of hair cards (strips with strands and see-through tips),
## laid like real hair: each strand starts on the scalp, follows the head away
## from the parting, then falls under gravity over the head, neck, shoulders and back.
const CARD_STYLES := {
	# length (m), gravity, follow (m along the scalp before falling), width (m), count, lift
	"short": [0.065, 0.05, 0.08, 0.016, 520, 0.006],
	"receding": [0.055, 0.05, 0.08, 0.016, 420, 0.005],
	"kid": [0.075, 0.09, 0.06, 0.016, 520, 0.007],
	"bob": [0.17, 0.45, 0.02, 0.02, 620, 0.004],
	"long": [0.38, 0.32, 0.03, 0.022, 760, 0.005],
	"ponytail": [0.11, 0.0, 1.0, 0.016, 480, 0.004],
	"pigtails": [0.11, 0.0, 1.0, 0.016, 480, 0.004],
	"bun": [0.11, 0.0, 1.0, 0.016, 480, 0.004],
}


## The head as an ellipsoid (centre, radii; front and back depth differ) for laying hair.
static func _head_shape(ctx: Dictionary) -> Dictionary:
	if ctx.has("head_shape"):
		return ctx["head_shape"]
	var info := _head_info(ctx)
	var c: Vector3 = info["center"]
	var top: float = info["top"]
	var rx := 0.0
	var front := 0.0
	var back := 0.0
	for p in (info["points"] as PackedVector3Array):
		if p.y > c.y + 0.03:
			rx = maxf(rx, absf(p.x - c.x))
		if p.y > c.y - 0.01:
			back = maxf(back, c.z - p.z)
		if p.y > c.y + 0.02:
			front = maxf(front, p.z - c.z)
	var V: PackedVector3Array = ctx["V"]
	var eye := _group_mean(V, "helper-l-eye")
	var shape := {"c": c, "rx": rx, "ry": top - c.y, "ry_low": maxf(c.y - (eye.y - 0.075), 0.05), "rf": front, "rb": back,
		"eye_y": eye.y, "front_z": eye.z}
	# How far the head reaches (in ellipsoid units) in every direction from its centre.
	var table := {}
	for p in (info["points"] as PackedVector3Array):
		var key := _dir_key(shape, p)
		table[key] = maxf(float(table.get(key, 0.0)), _head_k(shape, p))
	var filled := {}
	for la in range(0, 19):
		for lo in range(0, 36):
			var best := 0.0
			for r in [0, 1, 2]:
				for dla in range(-r, r + 1):
					for dlo in range(-r, r + 1):
						best = maxf(best, float(table.get(Vector2i(clampi(la + dla, 0, 18), posmod(lo + dlo, 36)), 0.0)))
				if best > 0.0:
					break
			filled[Vector2i(la, lo)] = best
	shape["dirs"] = filled
	ctx["head_shape"] = shape
	return shape


static func _dir_key(hs: Dictionary, p: Vector3) -> Vector2i:
	var c: Vector3 = hs["c"]
	var d := p - c
	var n := Vector3(d.x / float(hs["rx"]), d.y / float(hs["ry"] if d.y > 0.0 else hs["ry_low"]), d.z / float(hs["rf"] if d.z > 0.0 else hs["rb"])).normalized()
	var la := clampi(roundi(acos(clampf(n.y, -1.0, 1.0)) / PI * 18.0), 0, 18)
	var lo := posmod(roundi(atan2(n.x, n.z) / TAU * 36.0), 36)
	return Vector2i(la, lo)


## The head's surface level (ellipsoid units) in the direction of [param p].
static func _head_level(hs: Dictionary, p: Vector3) -> float:
	return float((hs["dirs"] as Dictionary).get(_dir_key(hs, p), 1.0))


static func _head_k(hs: Dictionary, p: Vector3) -> float:
	var c: Vector3 = hs["c"]
	var d := p - c
	var ry: float = hs["ry"] if d.y > 0.0 else hs["ry_low"]
	var rz: float = hs["rf"] if d.z > 0.0 else hs["rb"]
	return sqrt(pow(d.x / float(hs["rx"]), 2) + pow(d.y / ry, 2) + pow(d.z / rz, 2))


static func _card_hair(ctx: Dictionary, style: String) -> void:
	var spec: Dictionary = ctx["spec"]
	var hair: Dictionary = spec.get("hair", {})
	var cfg: Array = CARD_STYLES[style]
	var cap: Array = CAPS[style]
	var t: Dictionary = HumanData.templates[cap[0]]
	var V: PackedVector3Array = ctx["V"]
	var N: PackedVector3Array = ctx["N"]
	var hs := _head_shape(ctx)
	var info := _head_info(ctx)
	var c: Vector3 = hs["c"]
	var sk: Skeleton3D = ctx["skeleton"]
	var head := sk.find_bone("head")
	var neck := sk.find_bone("neck_01")
	var spine := sk.find_bone("spine_03")
	var neck_y := sk.get_bone_global_rest(neck).origin.y
	var chin_y := float(hs["eye_y"]) - 0.1
	var brow_y := float(hs["eye_y"]) + 0.022
	var s := float(ctx["hscale"])
	var vol := float(hair.get("volume", 1.0))
	var length := float(hair.get("length", cfg[0])) if style in ["bob", "long"] else float(cfg[0]) * s
	var gravity := float(cfg[1])
	var follow := float(cfg[2])
	var width := float(cfg[3]) * s
	var count := int(cfg[4])
	var lift_base := float(cfg[5]) * vol
	var part_x := c.x + float(hair.get("part", 0.0)) * float(hs["rx"]) * 0.5
	var crown := c + Vector3(0, float(hs["ry"]) * 0.82, -float(hs["rb"]) * 0.42)
	var tie := Vector3.INF
	if style == "ponytail":
		tie = c + Vector3(0, float(hs["ry"]) * 0.35, -float(hs["rb"]) * 1.0)
	elif style == "bun":
		tie = c + Vector3(0, float(hs["ry"]) * 0.45, -float(hs["rb"]) * 1.0)
	var fringe := style == "kid" or bool(hair.get("fringe", style == "bob"))
	var cut_y := (chin_y - 0.01) if style == "bob" else -INF
	var snap := not style in ["bob", "long"]

	# --- roots: random points on the hair cap (inside the hairline)
	var ia: PackedInt32Array = t["ia"]
	var ib: PackedInt32Array = t["ib"]
	var tt: PackedFloat32Array = t["t"]
	var hv: PackedFloat32Array = t.get("h", PackedFloat32Array())
	var counts: PackedByteArray = t["counts"]
	var faces: PackedInt32Array = t["faces"]
	var tri: Array = []
	var areas := PackedFloat32Array()
	var total_area := 0.0
	var pos0 := 0
	var edge_h := (float(cap[1]) - 0.5) / 8.0
	for cnt in counts:
		var ids: Array = []
		for k in cnt:
			ids.append(faces[pos0 + k])
		pos0 += cnt
		for k in range(1, ids.size() - 1):
			var a: int = ids[0]
			var b: int = ids[k]
			var d: int = ids[k + 1]
			var hmin := minf(hv[a], minf(hv[b], hv[d])) if hv.size() > 0 else 1.0
			if hmin < edge_h + 0.002:
				continue
			var pa := V[ia[a]].lerp(V[ib[a]], tt[a])
			var pb := V[ia[b]].lerp(V[ib[b]], tt[b])
			var pd := V[ia[d]].lerp(V[ib[d]], tt[d])
			var area := (pb - pa).cross(pd - pa).length() * 0.5
			total_area += area
			tri.append([a, b, d])
			areas.append(total_area)
	if tri.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("face_seed", 7)) * 31 + 5
	var sections := {}
	var inner := Builder.new()
	var outer := Builder.new()
	var vid := 0
	var seg := 0.0075 * s
	for i in count:
		var pick := rng.randf() * total_area
		var lo := 0
		var hi := areas.size() - 1
		while lo < hi:
			var mid := (lo + hi) / 2
			if areas[mid] < pick:
				lo = mid + 1
			else:
				hi = mid
		var f: Array = tri[lo]
		var r1 := rng.randf()
		var r2 := rng.randf()
		if r1 + r2 > 1.0:
			r1 = 1.0 - r1
			r2 = 1.0 - r2
		var w0 := 1.0 - r1 - r2
		var root := Vector3.ZERO
		var nrm := Vector3.ZERO
		var k3 := 0
		for vi in f:
			var wk := w0 if k3 == 0 else (r1 if k3 == 1 else r2)
			root += V[ia[vi]].lerp(V[ib[vi]], tt[vi]) * wk
			nrm += N[ia[vi]].lerp(N[ib[vi]], tt[vi]) * wk
			k3 += 1
		nrm = nrm.normalized()
		var layer_out := rng.randf() < 0.55
		var lift := lift_base * (rng.randf_range(0.2, 0.7) if not layer_out else rng.randf_range(0.7, 1.4))
		# --- which way it grows
		var rel := root - c
		var frontness := clampf(rel.z / maxf(float(hs["rf"]), 0.01), -1.0, 1.0)
		var dir := Vector3.ZERO
		var my_len := length * rng.randf_range(0.88, 1.06)
		var my_follow := follow
		var stop_y := cut_y
		if tie != Vector3.INF:
			dir = (tie - root)
			my_len = maxf(dir.length() * 1.05, 0.02)
		elif fringe and frontness > 0.45 and root.y > c.y:
			dir = Vector3(sign(root.x - part_x) * 0.25, -0.2, 1.0)
			stop_y = brow_y + rng.randf_range(-0.004, 0.006)
			my_follow = 0.025
		elif style in ["short", "receding", "kid"] and root.y < float(hs["eye_y"]) + 0.02 and root.z < c.z:
			# the nape: short and straight down
			dir = Vector3(0, -1, -0.15)
			my_len *= 0.45
			stop_y = chin_y + 0.015
		elif style in ["short", "receding"]:
			if root.z > crown.z:
				dir = Vector3(sign(root.x - part_x) * 0.5, 0.15, -1.0) if frontness > 0.2 else Vector3(sign(root.x - part_x) * 0.7, -0.1, -0.7)
			else:
				dir = (root - crown).normalized() + Vector3(0, -0.4, -0.2)
		elif style == "kid":
			dir = (root - crown).normalized() + Vector3(0, -0.3, 0)
		else:
			if root.z > crown.z:
				dir = Vector3(sign(root.x - part_x) + 0.0001, -0.1, -0.35 + 0.25 * frontness)
			else:
				dir = (root - crown).normalized() + Vector3(0, -0.6, -0.2)
		dir = (dir - nrm * nrm.dot(dir)).normalized()
		if dir.length_squared() < 0.5:
			dir = Vector3.DOWN
		# --- grow the strand
		var pts := PackedVector3Array([root + nrm * minf(lift, 0.002)])
		var outs := PackedVector3Array([nrm])
		var p := pts[0]
		var travelled := 0.0
		var steps := int(ceil(my_len / seg))
		for step in steps:
			var g := gravity * maxf(smoothstep(my_follow * 0.5, my_follow * 1.5, travelled), 0.25)
			dir = (dir + Vector3.DOWN * g).normalized()
			var q := p + dir * seg
			var out := Vector3.ZERO
			# head: stay just above the scalp (short styles lie on it)
			if q.y > neck_y + 0.01:
				var k := _head_k(hs, q)
				var want := maxf(_head_level(hs, q), 0.5) + (lift + travelled * 0.02 * vol) / float(hs["rx"])
				var hug := snap or (q.y > c.y - 0.01 and travelled < 0.14)
				if k < want or (hug and k > want):
					q = c + (q - c) * (want / maxf(k, 0.01))
					out = (q - c).normalized()
			# neck, shoulders, back and chest
			if q.y < neck_y + 0.03:
				var key := snappedf(q.y, 0.015)
				if not sections.has(key):
					sections[key] = _torso_section(ctx, key)
				var sec: Vector4 = sections[key]
				var m := 0.006 + lift * 0.6 + travelled * 0.012
				var ex := maxf(sec.x, 0.03) + m
				var dz := q.z - sec.w
				var ez := (maxf(sec.y, 0.03) if dz > 0.0 else maxf(sec.z, 0.03)) + m
				var kk := sqrt(pow((q.x - c.x) / ex, 2) + pow(dz / ez, 2))
				if kk < 1.0:
					var ang := atan2(dz / ez, (q.x - c.x) / ex)
					q = Vector3(c.x + cos(ang) * ex, q.y, sec.w + sin(ang) * ez)
					out = Vector3((q.x - c.x) / (ex * ex), 0, dz / (ez * ez)).normalized()
			if out == Vector3.ZERO:
				out = (q - Vector3(c.x, minf(q.y, c.y), c.z)).normalized()
			dir = (q - p).normalized()
			travelled += p.distance_to(q)
			p = q
			pts.append(p)
			outs.append(out)
			if p.y < stop_y or (tie != Vector3.INF and p.distance_to(tie) < 0.012):
				break
		if pts.size() < 3:
			continue
		# --- the card
		var b: Builder = outer if layer_out else inner
		var u0 := float(rng.randi() % 4) * 0.25
		var wmul := rng.randf_range(0.75, 1.3)
		var n_pts := pts.size()
		var ids_a: Array = []
		var ids_b: Array = []
		for j in n_pts:
			var tj := float(j) / float(n_pts - 1)
			var along := (pts[mini(j + 1, n_pts - 1)] - pts[maxi(j - 1, 0)]).normalized()
			var side := along.cross(outs[j]).normalized()
			if side.length_squared() < 0.5:
				side = Vector3.RIGHT
			var nn := side.cross(along).normalized()
			var wj := width * wmul * (1.0 - 0.45 * tj) * (0.55 + 0.45 * smoothstep(0.0, 0.08, tj))
			var hw := smoothstep(chin_y + 0.01, neck_y - 0.05, pts[j].y)
			var bones := PackedInt32Array([head, spine, neck, 0])
			var weights := PackedFloat32Array([1.0 - hw, hw * 0.75, hw * 0.25, 0.0])
			var vv := tj if style in ["bob", "long"] else lerpf(0.0, 0.85, tj) * minf(1.0, travelled / 0.08)
			ids_a.append(b.vertex(vid, pts[j] - side * wj, nn, Vector2(u0 + 0.01, vv), bones, weights))
			ids_b.append(b.vertex(vid + 1, pts[j] + side * wj, nn, Vector2(u0 + 0.24, vv), bones, weights))
			vid += 2
		for j in n_pts - 1:
			b.face([ids_a[j], ids_b[j], ids_b[j + 1], ids_a[j + 1]])
	var m_in := _hair_material(ctx, 2, 0.0, 0.0, 0.5)
	m_in.set_shader_parameter("shade", 0.62)
	var m_out := _hair_material(ctx, 2, 1.0, 0.0, 0.5)
	_add_mesh(ctx, "HairCards", [[inner, m_in, "cards_inner"], [outer, m_out, "cards"]])


static func _tails(ctx: Dictionary, style: String) -> void:
	var info := _head_info(ctx)
	var c: Vector3 = info["center"]
	var R: float = info["radius"]
	var sk: Skeleton3D = ctx["skeleton"]
	var head := sk.find_bone("head")
	var hair: Dictionary = ctx["spec"].get("hair", {})
	var anchors: Array = []
	if style == "ponytail":
		anchors.append([c + Vector3(0, R * 0.35, -R * 1.02), Vector3(0, 0, -1)])
	elif style == "pigtails":
		for sx in [1.0, -1.0]:
			var d := Vector3(sx * sin(deg_to_rad(125.0)), 0, cos(deg_to_rad(125.0)))
			anchors.append([c + d * R * 1.02, d])
	var b := Builder.new()
	var tie := Builder.new()
	var skin := _single_bone(head)
	var length := float(hair.get("length", 0.2 if style == "ponytail" else 0.15))
	if style == "bun":
		var ctr := c + Vector3(0, R * 0.45, -R * 1.05)
		var rad := Vector3(0.042, 0.038, 0.036) * float(hair.get("bun_size", 1.0))
		var nu := 24
		var nv := 12
		var grid: Array = []
		for j in nv + 1:
			var row: Array = []
			var th := PI * j / nv
			for i in nu + 1:
				var ph := TAU * i / nu
				var dir := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				row.append(b.vertex("bun%d_%d" % [i, j], ctr + dir * rad, dir, Vector2(float(i) / nu, float(j) / nv), skin[0], skin[1]))
			grid.append(row)
		for j in nv:
			for i in nu:
				b.face([grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1]])
	for n in anchors.size():
		var A: Vector3 = anchors[n][0]
		var out: Vector3 = anchors[n][1]
		var p1 := A + out * 0.05
		var p2 := A + out * 0.045 - Vector3(0, length, 0)
		var nr := 12
		var ns := 14
		var rings: Array = []
		for k in ns + 1:
			var t := float(k) / ns
			var p := A * (1 - t) * (1 - t) + p1 * 2.0 * (1 - t) * t + p2 * t * t
			var dp := ((p1 - A) * 2.0 * (1 - t) + (p2 - p1) * 2.0 * t).normalized()
			var a1 := dp.cross(Vector3.RIGHT if absf(dp.x) < 0.9 else Vector3.UP).normalized()
			var a2 := dp.cross(a1)
			var r := (0.020 * pow(1.0 - t, 0.7) + 0.004) if t > 0.08 else 0.012 + 0.08 * t
			var ring: Array = []
			for j in nr + 1:
				var ang := TAU * j / nr
				var dir := a1 * cos(ang) + a2 * sin(ang) * 0.8
				var target: Builder = tie if k == 1 else b
				ring.append([target, target.vertex("t%d_%d_%d" % [n, k, j], p + dir * r, dir.normalized(), Vector2(float(j) / nr, t), skin[0], skin[1])])
			rings.append(ring)
		for k in ns:
			for j in nr:
				var target: Builder = tie if k == 1 else b
				var ids: Array = []
				for pair in [[k, j], [k + 1, j], [k + 1, j + 1], [k, j + 1]]:
					var entry: Array = rings[pair[0]][pair[1]]
					if entry[0] == target:
						ids.append(entry[1])
					else:
						var src: Builder = entry[0]
						var vi: int = entry[1]
						ids.append(target.vertex("x%d_%d_%d" % [n, pair[0], pair[1]], src.pos[vi], src.nor[vi], src.uv[vi], skin[0], skin[1]))
				target.face(ids)
	var m := _hair_material(ctx, 2, 0.0, 0.0, 0.5)
	m.set_shader_parameter("mode", 3)
	var tie_m := StandardMaterial3D.new()
	tie_m.albedo_color = colour(hair.get("tie", "#d8263a"), Color(0.85, 0.15, 0.2))
	tie_m.roughness = 0.5
	_add_mesh(ctx, "HairTail", [[b, m, "tail"], [tie, tie_m, "hairtie"]])


# ------------------------------------------------------------------ motion

## The motion-capture clips (+ the rig they were made on), shared by every person.
static func motion_pack() -> Dictionary:
	if not _motion.is_empty():
		return _motion
	var scene := load(MOTIONS) as PackedScene
	if scene == null:
		return {}
	var root := scene.instantiate()
	var clips := {}
	for player in root.find_children("*", "AnimationPlayer", true, false):
		var ap := player as AnimationPlayer
		for clip_name in ap.get_animation_list():
			var clip := ap.get_animation(clip_name)
			if clip and clip.get_track_count() > 0:
				clips[str(clip_name)] = clip
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		root.free()
		return {}
	var sk := skeletons[0] as Skeleton3D
	var frame := ImportedCharacter.model_rotation(sk, root)
	var order: Array = []
	var parent := {}
	var basis := {}
	var rests := {}
	var hips_y := 1.0
	for bone in sk.get_bone_count():
		var name := sk.get_bone_name(bone)
		order.append(name)
		var p := sk.get_bone_parent(bone)
		parent[name] = sk.get_bone_name(p) if p >= 0 else ""
		basis[name] = Basis(frame) * sk.get_bone_global_rest(bone).basis
		var own := frame * sk.get_bone_global_rest(bone).basis.get_rotation_quaternion()
		var up := frame * (sk.get_bone_global_rest(p).basis.get_rotation_quaternion() if p >= 0 else Quaternion.IDENTITY)
		var canon := ImportedCharacter.canonical_bone(name)
		rests[canon] = [own, up]
		if canon == "hips":
			hips_y = maxf(absf(sk.get_bone_global_rest(bone).origin.y), 0.01)
	var dirs := ImportedCharacter.bone_directions(sk, root)
	root.free()
	_motion = {"clips": clips, "rests": rests, "dirs": dirs, "hips_y": hips_y,
		"skeleton": {"order": order, "parent": parent, "basis": basis}}
	return _motion

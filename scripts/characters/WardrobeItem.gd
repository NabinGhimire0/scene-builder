class_name WardrobeItem
extends RefCounted
## Clothes (and hair) taken from characters made elsewhere — Avaturn, Ready Player
## Me, Mixamo, MakeHuman/MPFB — and fitted to Scene Builder's own people.
##
## Import: every piece is moved from the source skeleton onto ours bone by bone
## (so it follows our proportions), pushed just outside our skin, then stored
## tied to the body: each vertex remembers the nearest body vertex and its offset
## in that vertex's frame. All Scene Builder people share one body layout, so the
## piece then fits any of them (child, adult, heavy, thin) and moves with them.
##
## Stored in user://library/wardrobe/<id>/: item.json, data.bin and textures.

const DIR := "user://library/wardrobe/"
const MARGIN := 0.004            # how far cloth stays outside the skin (m)
const BODY_WORDS: PackedStringArray = ["body", "base", "skin", "head", "teeth", "tongue", "mouth", "eye", "lash", "brow", "low-poly", "lowpoly", "proxy"]
const HAIR_WORDS: PackedStringArray = ["hair", "beard", "moustache", "mustache"]
const SHOE_WORDS: PackedStringArray = ["shoe", "foot", "feet", "boot", "sneaker", "sandal"]

static var _cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


# ------------------------------------------------------------------ library

## Saved pieces: [{path, name, slot}].
static func list_items() -> Array:
	var out: Array = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	var dirs := Array(dir.get_directories())
	dirs.sort()
	for d in dirs:
		var path: String = DIR + d + "/item.json"
		if not FileAccess.file_exists(path):
			continue
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if meta is Dictionary:
			out.append({"path": path, "name": str(meta.get("name", d)), "slot": str(meta.get("slot", "top"))})
	return out


## The slots a piece fills (an outfit fills top and bottom).
static func slots_of(info: Dictionary) -> Array:
	var slot := str(info.get("slot", "top"))
	if slot == "outfit":
		return ["top", "bottom"]
	return [slot]


## A saved piece: {name, slot, attach, nbr, offset, uv, bones, weights, index, hide, material}.
static func load_item(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return {}
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (meta is Dictionary):
		return {}
	var bytes := FileAccess.get_file_as_bytes(path.get_base_dir() + "/data.bin")
	var info: Dictionary = (meta as Dictionary).duplicate()
	var arrays: Dictionary = meta.get("arrays", {})
	for key in arrays:
		var r: Array = arrays[key]
		var chunk := bytes.slice(int(r[0]), int(r[0]) + int(r[1]))
		info[key] = chunk.to_float32_array() if str(r[2]) == "f" else chunk.to_int32_array()
	info["dir"] = path.get_base_dir()
	_cache[path] = info
	return info


static func forget(path: String) -> void:
	_cache.erase(path)


## Removes a saved piece (its folder) from the wardrobe.
static func delete_item(path: String) -> void:
	forget(path)
	var dir := path.get_base_dir()
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(dir + "/" + f)
	DirAccess.remove_absolute(dir)


# ------------------------------------------------------------------ fitting

## A skinned mesh of [param info] on the body in [param ctx] (see [method HumanBuilder.prepare]).
static func fit(info: Dictionary, ctx: Dictionary) -> MeshInstance3D:
	var V: PackedVector3Array = ctx["V"]
	var N: PackedVector3Array = ctx["N"]
	var attach: PackedInt32Array = info.get("attach", PackedInt32Array())
	var nbr: PackedInt32Array = info.get("nbr", PackedInt32Array())
	var off: PackedFloat32Array = info.get("offset", PackedFloat32Array())
	var uvf: PackedFloat32Array = info.get("uv", PackedFloat32Array())
	var bones: PackedInt32Array = info.get("bones", PackedInt32Array())
	var weights: PackedFloat32Array = info.get("weights", PackedFloat32Array())
	var index: PackedInt32Array = info.get("index", PackedInt32Array())
	var n := attach.size()
	if n == 0 or index.is_empty():
		return null
	var pos := PackedVector3Array()
	pos.resize(n)
	for k in n:
		var i := attach[k]
		var nn := N[i]
		if nn.length_squared() < 0.5:
			nn = Vector3.UP
		var t := V[nbr[k]] - V[i]
		t = (t - nn * nn.dot(t)).normalized()
		if t.length_squared() < 0.5:
			t = nn.cross(Vector3.RIGHT if absf(nn.x) < 0.9 else Vector3.UP).normalized()
		var b := nn.cross(t)
		pos[k] = V[i] + t * off[k * 3] + nn * off[k * 3 + 1] + b * off[k * 3 + 2]
	var nor := PackedVector3Array()
	nor.resize(n)
	for f in range(0, index.size(), 3):
		var a := index[f]
		var b2 := index[f + 1]
		var c := index[f + 2]
		var fn := (pos[b2] - pos[a]).cross(pos[c] - pos[a])
		nor[a] += fn
		nor[b2] += fn
		nor[c] += fn
	for k in n:
		nor[k] = nor[k].normalized() if nor[k].length_squared() > 0.0 else Vector3.UP
	var uv := PackedVector2Array()
	uv.resize(n)
	for k in n:
		uv[k] = Vector2(uvf[k * 2], uvf[k * 2 + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nor
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = weights
	arr[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, _material(info))
	mesh.surface_set_name(0, ("shirt" if str(info.get("slot", "")) in ["top", "outfit"] else ("trousers" if str(info.get("slot", "")) == "bottom" else ("shoes" if str(info.get("slot", "")) == "shoes" else "hair"))))
	var mi := MeshInstance3D.new()
	mi.name = "Wardrobe_" + str(info.get("name", "item")).validate_node_name()
	mi.mesh = mesh
	mi.skin = ctx["skin"]
	return mi


static func _material(info: Dictionary) -> Material:
	var m := StandardMaterial3D.new()
	var mat: Dictionary = info.get("material", {})
	m.albedo_color = Color.html(str(mat.get("color", "#ffffff")))
	m.roughness = float(mat.get("roughness", 0.85))
	m.metallic = float(mat.get("metallic", 0.0))
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dir := str(info.get("dir", ""))
	var albedo := _texture(dir + "/" + str(mat.get("albedo", ""))) if mat.has("albedo") else null
	if albedo:
		m.albedo_texture = albedo
	if mat.has("normal"):
		var nt := _texture(dir + "/" + str(mat["normal"]))
		if nt:
			m.normal_enabled = true
			m.normal_texture = nt
	if mat.has("orm"):
		var orm := _texture(dir + "/" + str(mat["orm"]))
		if orm:
			m.roughness_texture = orm
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	# cloth isn't metal (glTF exports often say metallic 1 with a map that's
	# mostly black; leaving it on makes clothes look like shiny plastic)
	m.metallic = 0.0
	m.metallic_specular = 0.35
	if bool(mat.get("alpha", false)) and str(info.get("slot", "")) == "hair":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
	return m


static func _texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex


# ------------------------------------------------------------------ importing

## Takes the clothes (and hair) off a character file and saves them for our people.
## [param spec] is the person they are fitted on first (any of ours works).
## Result: {"items": [{path, name, slot}], "error": ""}.
static func import_from(path: String, spec: Dictionary = {}) -> Dictionary:
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if path.get_extension().to_lower() == "fbx" and ClassDB.class_exists("FBXDocument"):
		doc = ClassDB.instantiate("FBXDocument")
		state = ClassDB.instantiate("FBXState")
	if doc.append_from_file(path, state) != OK:
		return {"error": "Couldn't read %s (use a .glb, .gltf or .fbx file)." % path.get_file()}
	var scene := doc.generate_scene(state)
	if scene == null:
		return {"error": "%s has no character in it." % path.get_file()}
	var body_spec := spec.duplicate(true)
	body_spec["outfit"] = {}
	var ctx := HumanBuilder.prepare(body_spec)
	if ctx.is_empty():
		scene.free()
		return {"error": "Scene Builder's body data is missing."}
	var result := _import_scene(scene, ctx, path)
	scene.free()
	return result


static func _global(node: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != null:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _import_scene(scene: Node, ctx: Dictionary, source: String) -> Dictionary:
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var pieces: Array = []
	for mi in meshes:
		var inst := mi as MeshInstance3D
		if inst.mesh == null:
			continue
		var name := String(inst.name).to_lower() + " " + String(inst.mesh.resource_name).to_lower()
		var is_body := false
		for w in BODY_WORDS:
			if name.contains(w):
				is_body = true
		var is_hair := false
		for w in HAIR_WORDS:
			if name.contains(w) and not name.contains("eyebrow"):
				is_hair = true
		if is_body and not is_hair:
			continue
		pieces.append([inst, is_hair])
	if pieces.is_empty():
		return {"error": "No clothes found in %s (only a body)." % source.get_file()}
	# our skeleton, by common bone name
	var sk: Skeleton3D = ctx["skeleton"]
	var ours := {}
	for i in sk.get_bone_count():
		ours[ImportedCharacter.canonical_bone(sk.get_bone_name(i))] = i
	var V: PackedVector3Array = ctx["V"]
	var N: PackedVector3Array = ctx["N"]
	var grid := _body_grid(V)
	var out: Array = []
	var base := source.get_file().get_basename().validate_filename().to_lower()
	for entry in pieces:
		var inst: MeshInstance3D = entry[0]
		var item := _convert(inst, entry[1], ctx, ours, grid)
		if item.is_empty():
			continue
		var id := ("%s_%s" % [base, String(inst.name).validate_filename().to_lower()]).left(60)
		item["source"] = source.get_file().get_basename()
		item["ref_spec"] = (ctx["spec"] as Dictionary).duplicate(true)
		var saved := _save(id, item, inst)
		if not saved.is_empty():
			out.append(saved)
	if out.is_empty():
		return {"error": "Couldn't fit the clothes from %s (the character needs a skeleton)." % source.get_file()}
	return {"items": out, "error": ""}


## Moves one piece onto our body; returns its arrays or {}.
static func _convert(inst: MeshInstance3D, is_hair: bool, ctx: Dictionary, ours: Dictionary, grid: Dictionary) -> Dictionary:
	var skin := inst.skin
	var src_sk: Skeleton3D = null
	if inst.has_node(inst.skeleton):
		src_sk = inst.get_node(inst.skeleton) as Skeleton3D
	if src_sk == null:
		var p := inst.get_parent()
		while p != null and src_sk == null:
			if p is Skeleton3D:
				src_sk = p
			p = p.get_parent()
	if src_sk == null or skin == null:
		return {}
	var sk_global := _global(src_sk)
	var our_sk: Skeleton3D = ctx["skeleton"]
	# bind index -> source bone
	var bind_bone := PackedInt32Array()
	for b in skin.get_bind_count():
		var bi := skin.get_bind_bone(b)
		if bi < 0:
			bi = src_sk.find_bone(skin.get_bind_name(b))
		bind_bone.append(bi)
	# per source bone: the transform onto our bone (rotation + stretch), and our bone index
	var maps := {}
	var height_src := _height(src_sk, sk_global)
	var height_our := _height(our_sk, Transform3D.IDENTITY)
	var ratio := height_our / maxf(height_src, 0.01)
	for b in src_sk.get_bone_count():
		maps[b] = _bone_map(src_sk, sk_global, b, our_sk, ours, ratio)
	var arrays := inst.mesh.surface_get_arrays(0)
	var sv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var sb: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var sw: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var suv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var sidx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if sidx.is_empty():
		for i in sv.size():
			sidx.append(i)
	var n := sv.size()
	var per := sb.size() / maxi(n, 1)
	var pos := PackedVector3Array()
	pos.resize(n)
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(n * 4)
	weights.resize(n * 4)
	for k in n:
		# the vertex in the source rest pose (model space)
		var p := Vector3.ZERO
		var q := Vector3.ZERO
		var wsum := 0.0
		var ob := {}
		for j in per:
			var w := sw[k * per + j]
			if w <= 0.0:
				continue
			var bind := sb[k * per + j]
			var bone := bind_bone[bind] if bind < bind_bone.size() else -1
			if bone < 0:
				continue
			var rest_v := sk_global * (src_sk.get_bone_global_rest(bone) * skin.get_bind_pose(bind)) * sv[k]
			p += rest_v * w
			var m: Array = maps[bone]
			q += _apply_map(m, rest_v) * w
			wsum += w
			ob[int(m[0])] = float(ob.get(int(m[0]), 0.0)) + w
		if wsum <= 0.0:
			q = sk_global * sv[k] * ratio
		else:
			q /= wsum
		pos[k] = q
		var sorted := ob.keys()
		sorted.sort_custom(func(a: int, b: int) -> bool: return float(ob[a]) > float(ob[b]))
		var total := 0.0
		for j in mini(sorted.size(), 4):
			total += float(ob[sorted[j]])
		for j in 4:
			if j < sorted.size():
				bones[k * 4 + j] = int(sorted[j])
				weights[k * 4 + j] = float(ob[sorted[j]]) / maxf(total, 0.0001)
			else:
				bones[k * 4 + j] = 0
				weights[k * 4 + j] = 0.0
	# push the cloth just outside our skin, then smooth the push so it stays even
	var V: PackedVector3Array = ctx["V"]
	var N: PackedVector3Array = ctx["N"]
	var near := PackedInt32Array()
	near.resize(n)
	for k in n:
		near[k] = _nearest(grid, V, pos[k])
	# coarse cloth needs more room: flat triangles cut through a curved body
	var edge_sum := 0.0
	for f in range(0, mini(sidx.size(), 3000), 3):
		edge_sum += pos[sidx[f]].distance_to(pos[sidx[f + 1]])
	var avg_edge := edge_sum / maxf(mini(sidx.size(), 3000) / 3.0, 1.0)
	var margin := clampf(avg_edge * 0.18, MARGIN * 1.5, 0.014) * (1.6 if is_hair else 1.0)
	var push := PackedFloat32Array()
	push.resize(n)
	for k in n:
		var i := near[k]
		if i < 0:
			continue
		var h := (pos[k] - V[i]).dot(N[i])
		push[k] = maxf(margin - h, 0.0)
	var pushes := PackedVector3Array()
	pushes.resize(n)
	for k in n:
		if near[k] >= 0:
			pushes[k] = N[near[k]] * push[k]
	var moved := layer_safe(pos, pushes)
	for k in n:
		pos[k] += moved[k]
	# cloth close to the skin moves exactly like the skin under it (the source rig's
	# weights only for loose parts like skirts and hoods)
	var bone_map: PackedInt32Array = ctx["bone_map"]
	for k in n:
		var i := _nearest(grid, V, pos[k])
		if i < 0:
			continue
		var dist := pos[k].distance_to(V[i])
		var w_body := 1.0 - smoothstep(0.025, 0.06, dist)
		if w_body <= 0.0:
			continue
		var mix := {}
		for j in 4:
			var wv := float(weights[k * 4 + j]) * (1.0 - w_body)
			if wv > 0.0:
				mix[bones[k * 4 + j]] = float(mix.get(bones[k * 4 + j], 0.0)) + wv
			var bw := HumanData.w_weights[i * 4 + j] / 255.0 * w_body
			if bw > 0.0:
				var bb := bone_map[HumanData.w_bones[i * 4 + j]]
				mix[bb] = float(mix.get(bb, 0.0)) + bw
		var keys := mix.keys()
		keys.sort_custom(func(a: int, b: int) -> bool: return float(mix[a]) > float(mix[b]))
		var tot := 0.0
		for j in mini(keys.size(), 4):
			tot += float(mix[keys[j]])
		for j in 4:
			bones[k * 4 + j] = int(keys[j]) if j < keys.size() else 0
			weights[k * 4 + j] = float(mix[keys[j]]) / maxf(tot, 0.0001) if j < keys.size() else 0.0
	# tie every vertex to the body
	var attach := PackedInt32Array()
	var nbr := PackedInt32Array()
	var off := PackedFloat32Array()
	attach.resize(n)
	nbr.resize(n)
	off.resize(n * 3)
	var first_nbr := _body_neighbour(V.size())
	for k in n:
		var i := _nearest(grid, V, pos[k])
		if i < 0:
			i = 0
		var j := int(first_nbr[i])
		var nn := N[i] if N[i].length_squared() > 0.5 else Vector3.UP
		var t := V[j] - V[i]
		t = (t - nn * nn.dot(t)).normalized()
		if t.length_squared() < 0.5:
			t = nn.cross(Vector3.RIGHT if absf(nn.x) < 0.9 else Vector3.UP).normalized()
		var b := nn.cross(t)
		var d := pos[k] - V[i]
		attach[k] = i
		nbr[k] = j
		off[k * 3] = d.dot(t)
		off[k * 3 + 1] = d.dot(nn)
		off[k * 3 + 2] = d.dot(b)
	var uv := PackedFloat32Array()
	uv.resize(n * 2)
	for k in mini(n, suv.size()):
		uv[k * 2] = suv[k].x
		uv[k * 2 + 1] = suv[k].y
	# Godot's index order is clockwise already (same as the source mesh)
	var slot := "hair" if is_hair else _slot(pos, our_sk)
	# see-through pieces sitting on the head are hair, whatever their name
	var src_mat := inst.get_active_material(0)
	if slot in ["top", "outfit"] and src_mat is BaseMaterial3D and (src_mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		var head_y := our_sk.get_bone_global_rest(our_sk.find_bone("head")).origin.y
		var top := -INF
		for p2 in pos:
			top = maxf(top, p2.y)
		if top > head_y + 0.08:
			slot = "hair"
	var neck_y := our_sk.get_bone_global_rest(our_sk.find_bone("neck_01")).origin.y + 0.02
	var hide := _covered_faces(V, N, pos, sidx, neck_y) if slot != "hair" else PackedInt32Array()
	return {"attach": attach, "nbr": nbr, "offset": off, "uv": uv, "bones": bones, "weights": weights,
		"index": sidx, "hide": hide, "slot": slot}


static func _height(sk: Skeleton3D, g: Transform3D) -> float:
	var head := -1
	var low := INF
	for i in sk.get_bone_count():
		var c := ImportedCharacter.canonical_bone(sk.get_bone_name(i))
		var y := (g * sk.get_bone_global_rest(i).origin).y
		if c == "head":
			head = i
		if c in ["leftfoot", "rightfoot", "lefttoebase", "righttoebase"]:
			low = minf(low, y)
	if head < 0 or low == INF:
		return 1.0
	return (g * sk.get_bone_global_rest(head).origin).y - low


## [our bone, source head, source axis, length ratio, rotation, our head, side ratio]
static func _bone_map(src: Skeleton3D, g: Transform3D, b: int, our: Skeleton3D, ours: Dictionary, ratio: float) -> Array:
	var bone := b
	var canon := ImportedCharacter.canonical_bone(src.get_bone_name(bone))
	while not ours.has(canon) and src.get_bone_parent(bone) >= 0:
		bone = src.get_bone_parent(bone)
		canon = ImportedCharacter.canonical_bone(src.get_bone_name(bone))
	if not ours.has(canon):
		var root_o := our.get_bone_global_rest(0).origin
		var root_s := g * src.get_bone_global_rest(0).origin
		return [0, root_s, Vector3.UP, ratio, Basis.IDENTITY, root_o, ratio]
	var oi: int = ours[canon]
	var hs := g * src.get_bone_global_rest(bone).origin
	var ho := our.get_bone_global_rest(oi).origin
	var child := str(ImportedCharacter.ALIGN_CHAIN.get(canon, ""))
	var ts := Vector3.INF
	var to := Vector3.INF
	if child != "" and ours.has(child):
		for c in src.get_bone_count():
			if ImportedCharacter.canonical_bone(src.get_bone_name(c)) == child:
				ts = g * src.get_bone_global_rest(c).origin
				break
		to = our.get_bone_global_rest(ours[child]).origin
	if ts == Vector3.INF or (ts - hs).length() < 0.001:
		return [oi, hs, Vector3.UP, ratio, Basis.IDENTITY, ho, ratio]
	var ds := (ts - hs)
	var do := (to - ho)
	var axis := ds.normalized()
	var rot := Basis(Quaternion(axis, do.normalized()))
	return [oi, hs, axis, do.length() / ds.length(), rot, ho, ratio]


static func _apply_map(m: Array, v: Vector3) -> Vector3:
	var hs: Vector3 = m[1]
	var axis: Vector3 = m[2]
	var k := float(m[3])
	var rot: Basis = m[4]
	var ho: Vector3 = m[5]
	var side := float(m[6])
	var d := v - hs
	var a := d.dot(axis)
	var perp := d - axis * a
	return ho + rot * (axis * a * k + perp * side)


static func _body_grid(V: PackedVector3Array) -> Dictionary:
	var grid := {}
	var seen := {}
	for f in HumanData.body_faces:
		for k in 4:
			var vi := HumanData.face_v[f * 4 + k]
			if vi < 0 or seen.has(vi):
				continue
			seen[vi] = true
			var key := Vector3i((V[vi] / 0.04).floor())
			var cell: PackedInt32Array = grid.get(key, PackedInt32Array())
			cell.append(vi)
			grid[key] = cell  # packed arrays are copied: store it back
	return grid


static func _nearest(grid: Dictionary, V: PackedVector3Array, p: Vector3) -> int:
	var c := Vector3i((p / 0.04).floor())
	var best := -1
	var bd := INF
	for r in [1, 2, 4]:
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				for z in range(-r, r + 1):
					if r > 1 and absi(x) < r and absi(y) < r and absi(z) < r:
						continue
					var key := c + Vector3i(x, y, z)
					if not grid.has(key):
						continue
					for vi in (grid[key] as PackedInt32Array):
						var d := V[vi].distance_squared_to(p)
						if d < bd:
							bd = d
							best = vi
		if best >= 0:
			return best
	return best


static func _neighbours(index: PackedInt32Array, n: int) -> Array:
	var nb: Array = []
	nb.resize(n)
	for i in n:
		nb[i] = []
	for f in range(0, index.size(), 3):
		for e in [[0, 1], [1, 2], [2, 0]]:
			var a := index[f + int(e[0])]
			var b := index[f + int(e[1])]
			(nb[a] as Array).append(b)
			(nb[b] as Array).append(a)
	return nb


static var _first_nbr := PackedInt32Array()

static func _body_neighbour(count: int) -> PackedInt32Array:
	if _first_nbr.size() == count:
		return _first_nbr
	_first_nbr.resize(count)
	for i in count:
		_first_nbr[i] = i
	for f in HumanData.body_faces:
		var a := HumanData.face_v[f * 4]
		var b := HumanData.face_v[f * 4 + 1]
		var c := HumanData.face_v[f * 4 + 2]
		if _first_nbr[a] == a:
			_first_nbr[a] = b
		if _first_nbr[b] == b:
			_first_nbr[b] = c
		if _first_nbr[c] == c:
			_first_nbr[c] = a
	return _first_nbr


## Body faces (positions in HumanData.body_faces) the cloth covers closely.
static func _covered_faces(V: PackedVector3Array, N: PackedVector3Array, verts: PackedVector3Array, index: PackedInt32Array, top_y := INF) -> PackedInt32Array:
	# points every ~1.5 cm over the cloth's triangles (cloth meshes can be coarse)
	var cloth := PackedVector3Array()
	for f in range(0, index.size(), 3):
		var a := verts[index[f]]
		var b := verts[index[f + 1]]
		var c := verts[index[f + 2]]
		var m := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
		var steps := clampi(int(ceil(m / 0.015)), 1, 12)
		for i in steps + 1:
			for j in steps + 1 - i:
				var u := float(i) / steps
				var v := float(j) / steps
				cloth.append(a + (b - a) * u + (c - a) * v)
	var cg := {}
	for k in cloth.size():
		var key := Vector3i((cloth[k] / 0.03).floor())
		var cell: PackedInt32Array = cg.get(key, PackedInt32Array())
		cell.append(k)
		cg[key] = cell
	var out := PackedInt32Array()
	var bf := HumanData.body_faces
	for fi in bf.size():
		var f := bf[fi]
		var c := Vector3.ZERO
		var cnt := 0
		for k in 4:
			var vi := HumanData.face_v[f * 4 + k]
			if vi >= 0:
				c += V[vi]
				cnt += 1
		c /= maxf(cnt, 1)
		if c.y > top_y:
			continue  # never hide the face or the head
		var nn := N[HumanData.face_v[f * 4]]
		var key := Vector3i((c / 0.03).floor())
		var covered := false
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					var kk := key + Vector3i(x, y, z)
					if not cg.has(kk) or covered:
						continue
					for ci in (cg[kk] as PackedInt32Array):
						var d := cloth[ci] - c
						if d.length() < 0.04 and d.dot(nn) > maxf(-0.003, d.length() * 0.35 - 0.004):
							covered = true
							break
		if covered:
			out.append(fi)
	return out


static func _slot(pos: PackedVector3Array, sk: Skeleton3D) -> String:
	var neck := sk.get_bone_global_rest(sk.find_bone("neck_01")).origin.y
	var chest := sk.get_bone_global_rest(sk.find_bone("spine_03")).origin.y
	var knee := sk.get_bone_global_rest(sk.find_bone("calf_l")).origin.y
	var low := INF
	var high := -INF
	for p in pos:
		low = minf(low, p.y)
		high = maxf(high, p.y)
	if high < knee * 0.45:
		return "shoes"
	if low > neck - 0.02:
		return "hair"
	if low < knee and high > chest:
		return "outfit"
	if high > chest - 0.02:
		return "top"
	return "bottom"


## "avaturn_look_0" -> "Outfit", "Clothes-x_harvey_pskirt01--human..." -> "Harvey Pskirt".
static func nice_name(raw: String, slot: String) -> String:
	var low := raw.to_lower()
	if slot == "hair":
		return "Hat" if low.contains("hat") or low.contains("cap") else "Hair"
	for pair in [["look", "Outfit"], ["outfit", "Outfit"], ["shoe", "Shoes"], ["boot", "Boots"], ["hair", "Hair"],
			["skirt", "Skirt"], ["dress", "Dress"], ["hood", "Hood"], ["jacket", "Jacket"], ["coat", "Coat"], ["shirt", "Shirt"],
			["tunic", "Tunic"], ["pants", "Trousers"], ["trouser", "Trousers"], ["jeans", "Jeans"], ["short", "Shorts"],
			["sweater", "Sweater"], ["hoodie", "Hoodie"], ["top", "Top"], ["bottom", "Bottoms"], ["glasses", "Glasses"], ["hat", "Hat"]]:
		if low.contains(pair[0]):
			return pair[1]
	return {"top": "Top", "bottom": "Bottoms", "outfit": "Outfit", "shoes": "Shoes", "hair": "Hair"}.get(slot, "Clothes")


static func _save(id: String, item: Dictionary, inst: MeshInstance3D) -> Dictionary:
	var dir := DIR + id
	DirAccess.make_dir_recursive_absolute(dir)
	var bytes := PackedByteArray()
	var arrays := {}
	for key in ["attach", "nbr", "offset", "uv", "bones", "weights", "index", "hide"]:
		var v: Variant = item[key]
		var chunk: PackedByteArray = (v as PackedFloat32Array).to_byte_array() if v is PackedFloat32Array else (v as PackedInt32Array).to_byte_array()
		arrays[key] = [bytes.size(), chunk.size(), "f" if v is PackedFloat32Array else "i"]
		bytes.append_array(chunk)
	var f := FileAccess.open(dir + "/data.bin", FileAccess.WRITE)
	if f == null:
		return {}
	f.store_buffer(bytes)
	f.close()
	var mat := {}
	var src := inst.get_active_material(0)
	if src is BaseMaterial3D:
		var bm := src as BaseMaterial3D
		mat["color"] = "#" + bm.albedo_color.to_html(false)
		mat["roughness"] = bm.roughness
		mat["metallic"] = bm.metallic
		mat["alpha"] = bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		for pair in [["albedo", bm.albedo_texture], ["normal", bm.normal_texture if bm.normal_enabled else null],
				["orm", bm.roughness_texture]]:
			var tex := pair[1] as Texture2D
			if tex == null:
				continue
			var img := tex.get_image()
			if img == null:
				continue
			if img.is_compressed():
				img.decompress()
			if img.get_width() > 2048:
				img.resize(2048, int(2048.0 * img.get_height() / img.get_width()))
			var file: String = str(pair[0]) + ".png"
			img.save_png(dir + "/" + file)
			mat[pair[0]] = file
	var title := nice_name(String(inst.name) + " " + String(inst.mesh.resource_name), str(item["slot"]))
	title = "%s (%s)" % [title, str(item.get("source", ""))] if str(item.get("source", "")) != "" else title
	var meta := {"name": title, "slot": item["slot"], "material": mat, "arrays": arrays, "version": 1,
		"ref_spec": item.get("ref_spec", {})}
	var mf := FileAccess.open(dir + "/item.json", FileAccess.WRITE)
	mf.store_string(JSON.stringify(meta, "\t"))
	mf.close()
	forget(dir + "/item.json")
	return {"path": dir + "/item.json", "name": title, "slot": item["slot"]}


# ------------------------------------------------------------------ other characters (Avatar Studio)

static var _ref_ctx: Dictionary = {}

## Dresses an imported character (e.g. an Avatar Studio / Blender avatar) in saved
## pieces: each is carried from Scene Builder's reference body onto this
## character's skeleton bone by bone, pushed out of its skin and given its skin
## weights; the skin under the clothes is cut away. Returns {"nodes", "slots"}.
static func dress_avatar(model: Node3D, paths: Array) -> Dictionary:
	var out := {"nodes": [], "slots": {}}
	var sk := _main_skeleton(model)
	if sk == null or paths.is_empty():
		return out
	var body := _body_instance(model, sk)
	if body == null:
		return out
	var bdata := _rest_mesh(body, sk)
	var bpos: PackedVector3Array = bdata["pos"]
	var bnor: PackedVector3Array = bdata["nor"]
	var grid := _grid_of(bpos, 0.04)
	var targets := {}
	for i in sk.get_bone_count():
		targets[ImportedCharacter.canonical_bone(sk.get_bone_name(i))] = i
	var skin := Skin.new()
	for i in sk.get_bone_count():
		skin.add_bind(i, sk.get_bone_global_rest(i).affine_inverse())
	var neck := -1
	for i in sk.get_bone_count():
		if ImportedCharacter.canonical_bone(sk.get_bone_name(i)) == "neck":
			neck = i
	var top_y := sk.get_bone_global_rest(neck).origin.y + 0.02 if neck >= 0 else INF
	var covered := PackedByteArray()
	covered.resize(bdata["tri_count"])
	for path in paths:
		var info := load_item(str(path))
		if info.is_empty():
			continue
		var key := JSON.stringify(info.get("ref_spec", {}))
		if not _ref_ctx.has(key):
			var spec: Dictionary = (info.get("ref_spec", {}) as Dictionary).duplicate(true)
			spec["outfit"] = {}
			_ref_ctx[key] = HumanBuilder.prepare(spec)
		var ctx: Dictionary = _ref_ctx[key]
		if ctx.is_empty():
			continue
		var ref_mi := fit(info, ctx)
		if ref_mi == null:
			continue
		var arr := ref_mi.mesh.surface_get_arrays(0)
		var mat := ref_mi.mesh.surface_get_material(0)
		ref_mi.free()
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var ob: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ow: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		# our reference skeleton -> this character's skeleton
		var our_sk: Skeleton3D = ctx["skeleton"]
		var ratio := _height(sk, Transform3D.IDENTITY) / maxf(_height(our_sk, Transform3D.IDENTITY), 0.01)
		var maps := {}
		for b in our_sk.get_bone_count():
			maps[b] = _bone_map(our_sk, Transform3D.IDENTITY, b, sk, targets, ratio)
		var n := pos.size()
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		bones.resize(n * 4)
		weights.resize(n * 4)
		for k in n:
			var q := Vector3.ZERO
			var ws := 0.0
			var mix := {}
			for j in 4:
				var w := ow[k * 4 + j]
				if w <= 0.0:
					continue
				var m: Array = maps[ob[k * 4 + j]]
				q += _apply_map(m, pos[k]) * w
				ws += w
				mix[int(m[0])] = float(mix.get(int(m[0]), 0.0)) + w
			pos[k] = q / ws if ws > 0.0 else pos[k] * ratio
			_put_weights(bones, weights, k, mix)
		# out of the skin, with this body's weights where the cloth is close to it
		var edge := 0.0
		for f in range(0, mini(idx.size(), 3000), 3):
			edge += pos[idx[f]].distance_to(pos[idx[f + 1]])
		var margin := clampf(edge / maxf(mini(idx.size(), 3000) / 3.0, 1.0) * 0.18, 0.006, 0.014)
		var hair := str(info.get("slot", "")) == "hair"
		var pushes := PackedVector3Array()
		pushes.resize(n)
		for k in n:
			var i := _nearest_in(grid, bpos, pos[k], 0.04)
			if i < 0:
				continue
			var h := (pos[k] - bpos[i]).dot(bnor[i])
			if h < margin * (1.6 if hair else 1.0):
				pushes[k] = bnor[i] * (margin * (1.6 if hair else 1.0) - h)
		var moved := layer_safe(pos, pushes)
		for k in n:
			pos[k] += moved[k]
		for k in n:
			var i := _nearest_in(grid, bpos, pos[k], 0.04)
			if i < 0:
				continue
			var close := 1.0 - smoothstep(0.025, 0.06, pos[k].distance_to(bpos[i]))
			if close > 0.0:
				var mix := {}
				for j in 4:
					var w := weights[k * 4 + j] * (1.0 - close)
					if w > 0.0:
						mix[bones[k * 4 + j]] = float(mix.get(bones[k * 4 + j], 0.0)) + w
					var bw: float = (bdata["w"] as PackedFloat32Array)[i * 4 + j] * close
					if bw > 0.0:
						var bb: int = (bdata["b"] as PackedInt32Array)[i * 4 + j]
						mix[bb] = float(mix.get(bb, 0.0)) + bw
				_put_weights(bones, weights, k, mix)
		var nor := PackedVector3Array()
		nor.resize(n)
		for f in range(0, idx.size(), 3):
			var fn := (pos[idx[f + 1]] - pos[idx[f]]).cross(pos[idx[f + 2]] - pos[idx[f]])
			for j in 3:
				nor[idx[f + j]] += fn
		for k in n:
			nor[k] = nor[k].normalized() if nor[k].length_squared() > 0.0 else Vector3.UP
		arr[Mesh.ARRAY_VERTEX] = pos
		arr[Mesh.ARRAY_NORMAL] = nor
		arr[Mesh.ARRAY_BONES] = bones
		arr[Mesh.ARRAY_WEIGHTS] = weights
		arr[Mesh.ARRAY_TANGENT] = null
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.name = "Wardrobe_" + str(info.get("name", "item")).validate_node_name()
		mi.mesh = mesh
		mi.skin = skin
		mi.set_meta("sb_wardrobe", true)
		sk.add_child(mi)
		mi.skeleton = NodePath("..")
		(out["nodes"] as Array).append(mi)
		for slot in slots_of(info):
			(out["slots"] as Dictionary)[slot] = true
		if not hair:
			_mark_covered(bdata, covered, pos, idx, top_y, 0.016 if str(info.get("slot", "")) == "shoes" else 0.04)
	# cut the skin away under the clothes
	if covered.count(1) > 0:
		body.set_meta("sb_body_mesh", body.mesh)
		body.mesh = _cut_mesh(body.mesh as ArrayMesh, bdata, covered)
	return out


## Undoes [method dress_avatar].
static func undress_avatar(model: Node3D) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta("sb_wardrobe"):
			mi.get_parent().remove_child(mi)
			mi.queue_free()
		elif mi.has_meta("sb_body_mesh"):
			(mi as MeshInstance3D).mesh = mi.get_meta("sb_body_mesh")
			mi.remove_meta("sb_body_mesh")


## Pushes cloth out of the body without pulling its layers apart: every point
## nearby (a shirt and the waistcoat over it) moves by the same, strongest push
## of its neighbourhood, smoothed - so a top layer always stays on top.
static func layer_safe(pos: PackedVector3Array, pushes: PackedVector3Array, radius := 0.03) -> PackedVector3Array:
	var n := pos.size()
	var grid := _grid_of(pos, radius)
	var strongest := PackedVector3Array()
	strongest.resize(n)
	for k in n:
		var c := Vector3i((pos[k] / radius).floor())
		var best := pushes[k]
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					var key := c + Vector3i(x, y, z)
					if not grid.has(key):
						continue
					for j in (grid[key] as PackedInt32Array):
						if pushes[j].length_squared() > best.length_squared() and pos[j].distance_squared_to(pos[k]) < radius * radius:
							best = pushes[j]
		strongest[k] = best
	var out := PackedVector3Array()
	out.resize(n)
	for k in n:
		var c := Vector3i((pos[k] / radius).floor())
		var sum := Vector3.ZERO
		var cnt := 0
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					var key := c + Vector3i(x, y, z)
					if not grid.has(key):
						continue
					for j in (grid[key] as PackedInt32Array):
						if pos[j].distance_squared_to(pos[k]) < radius * radius:
							sum += strongest[j]
							cnt += 1
		var avg := sum / maxf(cnt, 1)
		# never less than this point's own push
		out[k] = avg if avg.length() >= pushes[k].length() else pushes[k]
	return out


static func _put_weights(bones: PackedInt32Array, weights: PackedFloat32Array, k: int, mix: Dictionary) -> void:
	var keys := mix.keys()
	keys.sort_custom(func(a: int, b: int) -> bool: return float(mix[a]) > float(mix[b]))
	var tot := 0.0
	for j in mini(keys.size(), 4):
		tot += float(mix[keys[j]])
	for j in 4:
		bones[k * 4 + j] = int(keys[j]) if j < keys.size() else 0
		weights[k * 4 + j] = float(mix[keys[j]]) / maxf(tot, 0.0001) if j < keys.size() else 0.0


static func _main_skeleton(model: Node) -> Skeleton3D:
	var best: Skeleton3D = null
	for s in model.find_children("*", "Skeleton3D", true, false):
		if best == null or (s as Skeleton3D).get_bone_count() > best.get_bone_count():
			best = s
	return best


static func _body_instance(model: Node, sk: Skeleton3D) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var most := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.has_meta("sb_wardrobe") or mi.mesh == null or mi.skin == null:
			continue
		var m: Mesh = mi.get_meta("sb_body_mesh") if mi.has_meta("sb_body_mesh") else mi.mesh
		var name := String(mi.name).to_lower() + " " + (mi.get_active_material(0).resource_name.to_lower() if mi.get_active_material(0) else "")
		var score: int = m.surface_get_array_len(0)
		if name.contains("body") or name.contains("base") or name.contains("skin"):
			score *= 4
		if score > most:
			most = score
			best = mi
	return best


## Rest-pose positions, normals and weights (skeleton bone indices) of a skinned mesh, all surfaces.
static func _rest_mesh(mi: MeshInstance3D, sk: Skeleton3D) -> Dictionary:
	var mesh: Mesh = mi.get_meta("sb_body_mesh") if mi.has_meta("sb_body_mesh") else mi.mesh
	var skin := mi.skin
	var bind_bone := PackedInt32Array()
	for b in skin.get_bind_count():
		var bi := skin.get_bind_bone(b)
		if bi < 0:
			bi = sk.find_bone(skin.get_bind_name(b))
		bind_bone.append(bi)
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var tris := 0
	var surfaces: Array = []
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nv: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var sb: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var sw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		var per := sb.size() / maxi(v.size(), 1)
		var base := pos.size()
		for k in v.size():
			var p := Vector3.ZERO
			var q := Vector3.ZERO
			var ws := 0.0
			var mix := {}
			for j in per:
				var w := sw[k * per + j]
				if w <= 0.0:
					continue
				var bind := sb[k * per + j]
				var bone := bind_bone[bind] if bind < bind_bone.size() else -1
				if bone < 0:
					continue
				var t := sk.get_bone_global_rest(bone) * skin.get_bind_pose(bind)
				p += (t * v[k]) * w
				if k < nv.size():
					q += (t.basis * nv[k]) * w
				ws += w
				mix[bone] = float(mix.get(bone, 0.0)) + w
			pos.append(p / ws if ws > 0.0 else v[k])
			nor.append(q.normalized() if q.length_squared() > 0.0 else Vector3.UP)
			bones.resize(bones.size() + 4)
			weights.resize(weights.size() + 4)
			_put_weights(bones, weights, base + k, mix)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			for k in v.size():
				idx.append(k)
		surfaces.append({"base": base, "index": idx, "first_tri": tris})
		tris += idx.size() / 3
	return {"pos": pos, "nor": nor, "b": bones, "w": weights, "surfaces": surfaces, "tri_count": tris}


static func _grid_of(points: PackedVector3Array, cell_size: float) -> Dictionary:
	var grid := {}
	for i in points.size():
		var key := Vector3i((points[i] / cell_size).floor())
		var cell: PackedInt32Array = grid.get(key, PackedInt32Array())
		cell.append(i)
		grid[key] = cell
	return grid


static func _nearest_in(grid: Dictionary, pts: PackedVector3Array, p: Vector3, cell_size: float) -> int:
	var c := Vector3i((p / cell_size).floor())
	var best := -1
	var bd := INF
	for r in [1, 2, 4]:
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				for z in range(-r, r + 1):
					if r > 1 and absi(x) < r and absi(y) < r and absi(z) < r:
						continue
					var key := c + Vector3i(x, y, z)
					if not grid.has(key):
						continue
					for vi in (grid[key] as PackedInt32Array):
						var d := pts[vi].distance_squared_to(p)
						if d < bd:
							bd = d
							best = vi
		if best >= 0:
			return best
	return best


## Marks the body triangles a piece of cloth lies over.
static func _mark_covered(bdata: Dictionary, covered: PackedByteArray, verts: PackedVector3Array, index: PackedInt32Array, top_y: float, reach := 0.04) -> void:
	var cloth := PackedVector3Array()
	for f in range(0, index.size(), 3):
		var a := verts[index[f]]
		var b := verts[index[f + 1]]
		var c := verts[index[f + 2]]
		var m := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
		var steps := clampi(int(ceil(m / 0.015)), 1, 12)
		for i in steps + 1:
			for j in steps + 1 - i:
				cloth.append(a + (b - a) * (float(i) / steps) + (c - a) * (float(j) / steps))
	var cg := _grid_of(cloth, 0.03)
	var pos: PackedVector3Array = bdata["pos"]
	var nor: PackedVector3Array = bdata["nor"]
	for surf in bdata["surfaces"]:
		var base: int = surf["base"]
		var idx: PackedInt32Array = surf["index"]
		var t0: int = surf["first_tri"]
		for f in range(0, idx.size(), 3):
			var ti := t0 + f / 3
			if covered[ti] == 1:
				continue
			var a := base + idx[f]
			var c := (pos[a] + pos[base + idx[f + 1]] + pos[base + idx[f + 2]]) / 3.0
			if c.y > top_y:
				continue
			var nn := nor[a]
			var key := Vector3i((c / 0.03).floor())
			var hit := false
			for x in range(-1, 2):
				for y in range(-1, 2):
					for z in range(-1, 2):
						if hit:
							break
						var kk := key + Vector3i(x, y, z)
						if not cg.has(kk):
							continue
						for ci in (cg[kk] as PackedInt32Array):
							var d := cloth[ci] - c
							if d.length() < reach and d.dot(nn) > maxf(-0.003, d.length() * 0.35 - 0.004):
								hit = true
								break
			if hit:
				covered[ti] = 1


## A copy of the body mesh without the covered triangles (blend shapes kept).
static func _cut_mesh(src: ArrayMesh, bdata: Dictionary, covered: PackedByteArray) -> ArrayMesh:
	var out := ArrayMesh.new()
	out.blend_shape_mode = src.blend_shape_mode
	for b in src.get_blend_shape_count():
		out.add_blend_shape(src.get_blend_shape_name(b))
	var surfaces: Array = bdata["surfaces"]
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var blends := src.surface_get_blend_shape_arrays(s)
		var surf: Dictionary = surfaces[s]
		var idx: PackedInt32Array = surf["index"]
		var t0: int = surf["first_tri"]
		var keep := PackedInt32Array()
		for f in range(0, idx.size(), 3):
			if covered[t0 + f / 3] == 0:
				keep.append(idx[f])
				keep.append(idx[f + 1])
				keep.append(idx[f + 2])
		if keep.is_empty():
			keep = PackedInt32Array([0, 0, 0])
		arr[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arr, blends)
		out.surface_set_material(s, src.surface_get_material(s))
		out.surface_set_name(s, src.surface_get_name(s))
	return out

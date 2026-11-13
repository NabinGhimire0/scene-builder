class_name PlantMeshes
extends RefCounted
## Builds the plant meshes used by [Vegetation] in code (no asset files).
## Vertex colour = the plant's colour; vertex alpha 1 marks flower heads.

const STEM := Color(0.2, 0.36, 0.1, 0.0)


static func build(kind: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	match kind:
		"Grass":
			for i in 11:
				_blade(st, rng, 0.25, 0.5, 0.025, Color(0.15, 0.27, 0.08, 0.0), Color(0.38, 0.48, 0.19, 0.0))
		"Tall grass":
			for i in 14:
				_blade(st, rng, 0.7, 1.2, 0.03, Color(0.2, 0.3, 0.1, 0.0), Color(0.62, 0.6, 0.3, 0.0))
		"Flowers":
			for i in 5:
				var top := _blade(st, rng, 0.3, 0.55, 0.012, STEM, STEM.lightened(0.2))
				_flower_head(st, top, rng.randf_range(0.04, 0.07))
			for i in 5:
				_blade(st, rng, 0.15, 0.3, 0.02, Color(0.15, 0.3, 0.08, 0.0), Color(0.3, 0.45, 0.15, 0.0))
		"Bushes":
			for i in 7:
				var c := Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(0.35, 0.8), rng.randf_range(-0.45, 0.45))
				_blob(st, rng, c, rng.randf_range(0.35, 0.55), Color(0.13, 0.27, 0.08, 0.0), 0.25)
		"Broadleaf trees":
			_trunk(st, Vector3.ZERO, 3.6, 0.24, 0.13, Color(0.27, 0.2, 0.14, 0.0))
			# A few limbs reaching out, each carrying clumps of leaves.
			var ends: Array[Vector3] = [Vector3(0, 5.4, 0)]
			for i in 4:
				var a := TAU * float(i) / 4.0 + rng.randf_range(-0.4, 0.4)
				var from := Vector3(0, rng.randf_range(2.6, 3.4), 0)
				var to := from + Vector3(cos(a) * 1.5, rng.randf_range(1.1, 1.7), sin(a) * 1.5)
				_limb(st, from, to, 0.1, 0.05, Color(0.27, 0.2, 0.14, 0.0))
				ends.append(to)
			for i in 12:
				var base: Vector3 = ends[i % ends.size()]
				var c := base + Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.2, 0.8), rng.randf_range(-0.7, 0.7))
				var tint := Color(0.13, 0.29, 0.08, 0.0).lerp(Color(0.24, 0.36, 0.1, 0.0), rng.randf() * 0.7)
				_blob(st, rng, c, rng.randf_range(0.85, 1.35), tint, 0.32)
		"Pine trees":
			_trunk(st, Vector3.ZERO, 8.2, 0.22, 0.05, Color(0.25, 0.17, 0.11, 0.0))
			var tiers := 9
			for i in tiers:
				var k := float(i) / float(tiers - 1)
				var y := 1.3 + k * 6.0 + rng.randf_range(-0.1, 0.1)
				var radius := lerpf(2.0, 0.45, k) * rng.randf_range(0.88, 1.1)
				_pine_tier(st, rng, y, radius, lerpf(1.25, 0.9, k), i)
		"Rocks":
			_boulder(st, rng, Vector3(0, 0.12, 0), 0.45, Vector3(1.25, 0.7, 1.0))
			_boulder(st, rng, Vector3(0.52, 0.02, 0.22), 0.17, Vector3(1.1, 0.75, 1.0))
	st.generate_normals()
	return st.commit()


## One layer of a pine: a star of drooping branch tips around the trunk, darker
## inside and lighter (fresh needles) at the tips, with a dark underside.
static func _pine_tier(st: SurfaceTool, rng: RandomNumberGenerator, y: float, radius: float, height: float, index: int) -> void:
	var tips := 14
	var turn := rng.randf() * TAU
	var deep := Color(0.05, 0.14, 0.07, 0.0)
	var fresh := Color(0.12, 0.27, 0.12, 0.0).lerp(Color(0.16, 0.3, 0.1, 0.0), rng.randf())
	var top := Vector3(0, y + height, 0)
	var under := Vector3(0, y + height * 0.25, 0)
	var ring: Array[Vector3] = []
	for k in tips:
		var a := turn + TAU * float(k) / float(tips)
		var r := radius * (1.0 if k % 2 == 0 else 0.7) * rng.randf_range(0.85, 1.12)
		var droop := 0.28 * r + rng.randf_range(-0.08, 0.08)
		ring.append(Vector3(cos(a) * r, y - droop, sin(a) * r))
	for k in tips:
		var a := ring[k]
		var b := ring[(k + 1) % tips]
		st.set_color(deep)
		st.add_vertex(top)
		st.set_color(fresh if k % 2 == 0 else fresh.darkened(0.15))
		st.add_vertex(a)
		st.set_color(fresh if k % 2 == 1 else fresh.darkened(0.15))
		st.add_vertex(b)
		# underside
		st.set_color(deep.darkened(0.35))
		st.add_vertex(under)
		st.set_color(deep)
		st.add_vertex(b)
		st.set_color(deep)
		st.add_vertex(a)


## A weathered boulder: a twice-subdivided icosahedron pushed in and out by
## layered noise, sitting flat on the ground; crevices are darker (vertex colour).
static func _boulder(st: SurfaceTool, rng: RandomNumberGenerator, centre: Vector3, radius: float, stretch: Vector3) -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in verts.size():
		verts[i] = verts[i].normalized()
	var faces: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for level in 2:
		var cache := {}
		var next: Array = []
		for f in faces:
			var m: Array[int] = []
			for e in 3:
				var a: int = f[e]
				var b: int = f[(e + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if not cache.has(key):
					verts.append(((verts[a] + verts[b]) * 0.5).normalized())
					cache[key] = verts.size() - 1
				m.append(int(cache[key]))
			next.append([f[0], m[0], m[2]])
			next.append([f[1], m[1], m[0]])
			next.append([f[2], m[2], m[1]])
			next.append([m[0], m[1], m[2]])
		faces = next
	var o := Vector3(rng.randf() * 50.0, rng.randf() * 50.0, rng.randf() * 50.0)
	var shaped: Array[Vector3] = []
	var shade: Array[float] = []
	for v in verts:
		var n := _noise3(v * 1.3 + o) * 0.3 + _noise3(v * 3.1 + o) * 0.12 + _noise3(v * 7.0 + o) * 0.045
		# A couple of flat, cut faces make it read as stone rather than a blob.
		var r := 1.0 + n
		for plane in [Vector3(0.6, 0.3, 0.74), Vector3(-0.7, 0.5, -0.3), Vector3(0.1, 1.0, -0.2)]:
			var cut := v.dot((plane as Vector3).normalized())
			if cut > 0.6:
				r = minf(r, 0.6 / maxf(cut, 0.01) + 0.04)
		var p := v * r
		p.y = maxf(p.y, -0.32)   # rests flat on the ground
		shaped.append(centre + p * radius * stretch)
		shade.append(clampf(0.75 + n * 2.0, 0.45, 1.15))
	for f in faces:
		for e in 3:
			var i: int = f[2 - e]
			var s: float = shade[i] * (0.7 + 0.3 * clampf((verts[i].y + 0.4) / 1.2, 0.0, 1.0))
			st.set_color(Color(s, s, s, 0.0))
			st.add_vertex(shaped[i])


## Smooth value noise in -1..1 (cheap; only used while building meshes).
static func _noise3(p: Vector3) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector3(3, 3, 3) - f * 2.0)
	var n := 0.0
	var corners := [[0, 0, 0], [1, 0, 0], [0, 1, 0], [1, 1, 0], [0, 0, 1], [1, 0, 1], [0, 1, 1], [1, 1, 1]]
	for c in corners:
		var w := (f.x if c[0] == 1 else 1.0 - f.x) * (f.y if c[1] == 1 else 1.0 - f.y) * (f.z if c[2] == 1 else 1.0 - f.z)
		var h := sin((i.x + c[0]) * 127.1 + (i.y + c[1]) * 311.7 + (i.z + c[2]) * 74.7) * 43758.5453
		n += w * (h - floor(h))
	return n * 2.0 - 1.0


static func _limb(st: SurfaceTool, from: Vector3, to: Vector3, r0: float, r1: float, color: Color) -> void:
	var axis := (to - from).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP).normalized()
	var other := axis.cross(side)
	var sides := 6
	for s in sides:
		var a0 := TAU * float(s) / float(sides)
		var a1 := TAU * float(s + 1) / float(sides)
		var d0 := side * cos(a0) + other * sin(a0)
		var d1 := side * cos(a1) + other * sin(a1)
		_quad(st, from + d0 * r0, from + d1 * r0, to + d1 * r1, to + d0 * r1, color.darkened(0.15), color)


## Height used by the wind shader for each plant type (metres).
static func height_of(kind: String) -> float:
	match kind:
		"Grass": return 0.45
		"Tall grass": return 1.1
		"Flowers": return 0.5
		"Bushes": return 1.2
		"Broadleaf trees": return 6.5
		"Pine trees": return 8.0
	return 1.0


static func _blade(st: SurfaceTool, rng: RandomNumberGenerator, min_h: float, max_h: float, width: float, base: Color, tip: Color) -> Vector3:
	var h := rng.randf_range(min_h, max_h)
	var angle := rng.randf() * TAU
	var lean := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.05, 0.35) * h
	var root := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
	var side := Vector3(-sin(angle), 0, cos(angle)) * width
	var segments := 3
	var prev_l := root - side
	var prev_r := root + side
	var point := root
	for s in range(1, segments + 1):
		var t := float(s) / float(segments)
		point = root + Vector3(0, h * t, 0) + lean * t * t
		var w := 1.0 - t * 0.92
		var l := point - side * w
		var r := point + side * w
		var c0 := base.lerp(tip, float(s - 1) / float(segments))
		var c1 := base.lerp(tip, t)
		_quad(st, prev_l, prev_r, r, l, c0, c1)
		prev_l = l
		prev_r = r
	return point


static func _flower_head(st: SurfaceTool, at: Vector3, size: float) -> void:
	var head := Color(1, 1, 1, 1)
	var centre := at + Vector3(0, 0.01, 0)
	for i in 5:
		var a0 := TAU * float(i) / 5.0
		var a1 := a0 + TAU / 10.0
		var a2 := a0 - TAU / 10.0
		var tip := centre + Vector3(cos(a0), 0.25, sin(a0)) * size
		var p1 := centre + Vector3(cos(a1), 0.1, sin(a1)) * size * 0.45
		var p2 := centre + Vector3(cos(a2), 0.1, sin(a2)) * size * 0.45
		_tri(st, centre, p1, tip, head)
		_tri(st, centre, tip, p2, head)


static func _blob(st: SurfaceTool, rng: RandomNumberGenerator, centre: Vector3, radius: float, color: Color, lumpiness: float, stretch: Vector3 = Vector3.ONE) -> void:
	var rings := 6
	var sides := 9
	var points: Array[PackedVector3Array] = []
	var seed_offset := rng.randf() * 100.0
	for ring in rings + 1:
		var v := float(ring) / float(rings)
		var phi := v * PI
		var row := PackedVector3Array()
		for side in sides:
			var theta := TAU * float(side) / float(sides)
			var dir := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var bumpy := 1.0 + lumpiness * (sin(theta * 3.0 + seed_offset) * cos(phi * 2.0 + seed_offset) * 0.6 + rng.randf_range(-0.4, 0.4))
			row.append(centre + dir * radius * bumpy * stretch)
		points.append(row)
	for ring in rings:
		var shade := color.lightened(0.15 * (1.0 - float(ring) / float(rings)))
		for side in sides:
			var next: int = (side + 1) % sides
			_quad(st, points[ring + 1][side], points[ring + 1][next], points[ring][next], points[ring][side], shade, shade)


static func _trunk(st: SurfaceTool, base: Vector3, height: float, r0: float, r1: float, color: Color) -> void:
	var sides := 8
	for side in sides:
		var a0 := TAU * float(side) / float(sides)
		var a1 := TAU * float(side + 1) / float(sides)
		var b0 := base + Vector3(cos(a0), 0, sin(a0)) * r0
		var b1 := base + Vector3(cos(a1), 0, sin(a1)) * r0
		var t0 := base + Vector3(cos(a0) * r1, height, sin(a0) * r1)
		var t1 := base + Vector3(cos(a1) * r1, height, sin(a1) * r1)
		_quad(st, b0, b1, t1, t0, color.darkened(0.2), color)


static func _cone(st: SurfaceTool, rng: RandomNumberGenerator, y: float, radius: float, height: float, color: Color) -> void:
	var sides := 10
	var tip := Vector3(0, y + height, 0)
	for side in sides:
		var a0 := TAU * float(side) / float(sides)
		var a1 := TAU * float(side + 1) / float(sides)
		var j0 := 1.0 + rng.randf_range(-0.15, 0.15)
		var b0 := Vector3(cos(a0) * radius * j0, y - 0.15, sin(a0) * radius * j0)
		var b1 := Vector3(cos(a1) * radius, y + rng.randf_range(-0.1, 0.1), sin(a1) * radius)
		_tri(st, b0, b1, tip, color)
		_tri(st, b1, b0, Vector3(0, y + 0.1, 0), color.darkened(0.3))


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, low: Color, high: Color) -> void:
	_vertex(st, a, low)
	_vertex(st, b, low)
	_vertex(st, c, high)
	_vertex(st, a, low)
	_vertex(st, c, high)
	_vertex(st, d, high)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_vertex(st, a, color)
	_vertex(st, b, color)
	_vertex(st, c, color)


static func _vertex(st: SurfaceTool, p: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(p)

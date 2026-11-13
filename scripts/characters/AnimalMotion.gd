class_name AnimalMotion
extends RefCounted
## Motions for the animals, generated for each species' own body: walk and run
## (feet planted on the ground with leg IK), idle, sit, lie down, eat, look around,
## plus pecking and flapping for birds. Made once per species as Animation clips
## and played by [ImportedCharacter] like any imported animation.

const FPS := 30.0

## Per species: [walk period s, walk stride (in heights), run period, run stride, run speed (heights/s),
##  step height, run style (0 trot, 1 gallop, 2 hop), can sit]
const GAIT := {
	"default": [0.9, 1.25, 0.5, 2.6, 4.5, 0.12, 0, true],
	"cat": [0.85, 1.3, 0.42, 2.8, 5.0, 0.14, 1, true],
	"dog": [0.8, 1.3, 0.45, 2.8, 4.5, 0.13, 1, true],
	"fox": [0.8, 1.3, 0.45, 2.8, 4.5, 0.13, 1, true],
	"wolf": [0.8, 1.3, 0.45, 2.9, 4.5, 0.13, 1, true],
	"tiger": [1.0, 1.25, 0.5, 2.6, 3.5, 0.12, 1, true],
	"lion": [1.0, 1.25, 0.5, 2.6, 3.5, 0.12, 1, true],
	"bear": [1.1, 1.0, 0.55, 2.0, 2.8, 0.1, 1, true],
	"monkey": [0.8, 1.1, 0.45, 2.2, 3.5, 0.12, 1, true],
	"rabbit": [0.7, 0.8, 0.42, 2.6, 5.0, 0.15, 2, true],
	"horse": [1.1, 1.1, 0.62, 2.3, 3.0, 0.1, 1, false],
	"donkey": [1.0, 1.0, 0.6, 2.0, 2.6, 0.1, 0, false],
	"cow": [1.2, 1.0, 0.7, 1.8, 2.0, 0.08, 0, false],
	"buffalo": [1.25, 1.0, 0.7, 1.8, 2.0, 0.08, 0, false],
	"yak": [1.2, 1.0, 0.7, 1.8, 2.0, 0.08, 0, false],
	"goat": [0.85, 1.1, 0.5, 2.2, 3.5, 0.12, 0, false],
	"sheep": [0.85, 1.1, 0.5, 2.2, 3.5, 0.12, 0, false],
	"deer": [0.95, 1.2, 0.55, 2.8, 4.0, 0.12, 1, false],
	"pig": [0.75, 1.0, 0.45, 2.0, 3.5, 0.1, 0, false],
	"elephant": [1.5, 0.9, 0.9, 1.4, 1.2, 0.08, 0, false],
}
const BIRDS := ["chicken", "duck", "bird"]

static var _cache: Dictionary = {}


static func gait(species: String) -> Array:
	return GAIT.get(species, GAIT["default"])


## Adds an AnimationPlayer with this species' clips to [param model] and records
## its walking stride (meta "animal_gait": walk stride, run stride, run speed in metres).
static func add_clips(model: Node3D, species: String) -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var sk := skeletons[0] as Skeleton3D
	var path := str(model.get_path_to(sk))
	var rig := Rig.new(sk, model)
	var g := gait(species)
	var H := rig.height
	model.set_meta("animal_gait", Vector3(float(g[1]) * H, float(g[3]) * H, float(g[4]) * H))
	var key := species + ":" + path
	var lib: AnimationLibrary
	if _cache.has(key):
		lib = _cache[key]
	else:
		lib = AnimationLibrary.new()
		var clips := _make_clips(rig, species, path)
		for n in clips:
			lib.add_animation(n, clips[n])
		_cache[key] = lib
	var player := AnimationPlayer.new()
	player.name = "AnimalMotions"
	model.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", lib)


static func _make_clips(rig: Rig, species: String, path: String) -> Dictionary:
	var g := gait(species)
	var H := rig.height
	var s := sqrt(H / 0.55)
	var out := {}
	if species in BIRDS:
		out["Idle"] = _clip(rig, path, 3.0, func(t: float) -> Dictionary: return rig.bird_pose("idle", t / 3.0))
		out["Walk"] = _clip(rig, path, 0.6, func(t: float) -> Dictionary: return rig.bird_pose("walk", t / 0.6))
		out["Run"] = _clip(rig, path, 0.36, func(t: float) -> Dictionary: return rig.bird_pose("run", t / 0.36))
		out["Peck"] = _clip(rig, path, 1.6, func(t: float) -> Dictionary: return rig.bird_pose("peck", t / 1.6))
		out["Look Around"] = _clip(rig, path, 4.0, func(t: float) -> Dictionary: return rig.bird_pose("look", t / 4.0))
		out["Sit"] = _clip(rig, path, 3.0, func(t: float) -> Dictionary: return rig.bird_pose("sit", t / 3.0))
		if rig.has("wing_l"):
			out["Flap Wings"] = _clip(rig, path, 0.8, func(t: float) -> Dictionary: return rig.bird_pose("flap", t / 0.8))
		return out
	var wt := float(g[0]) * s
	var rt := float(g[2]) * s
	out["Idle"] = _clip(rig, path, 4.0, func(t: float) -> Dictionary: return rig.quad_pose("idle", t / 4.0, g))
	out["Walk"] = _clip(rig, path, wt, func(t: float) -> Dictionary: return rig.quad_pose("walk", t / wt, g))
	out["Run"] = _clip(rig, path, rt, func(t: float) -> Dictionary: return rig.quad_pose("run", t / rt, g))
	out["Eat"] = _clip(rig, path, 3.0, func(t: float) -> Dictionary: return rig.quad_pose("eat", t / 3.0, g))
	out["Look Around"] = _clip(rig, path, 5.0, func(t: float) -> Dictionary: return rig.quad_pose("look", t / 5.0, g))
	out["Lie Down"] = _clip(rig, path, 4.0, func(t: float) -> Dictionary: return rig.quad_pose("lie", t / 4.0, g))
	if bool(g[7]):
		out["Sit"] = _clip(rig, path, 4.0, func(t: float) -> Dictionary: return rig.quad_pose("sit", t / 4.0, g))
	return out


## Samples [param pose_fn] (t -> {bone: Quaternion, "_root": Vector3}) into a looping clip.
static func _clip(rig: Rig, path: String, length: float, pose_fn: Callable) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR
	var frames := maxi(int(round(length * FPS)), 2)
	var tracks := {}
	var root_track := -1
	for f in frames + 1:
		var t := length * float(f) / float(frames)
		var pose: Dictionary = pose_fn.call(fmod(t, length) if f < frames else 0.0)
		for bone in pose:
			if bone == "_root":
				if root_track < 0:
					root_track = anim.add_track(Animation.TYPE_POSITION_3D)
					anim.track_set_path(root_track, NodePath(path + ":" + rig.root_name))
				anim.position_track_insert_key(root_track, t, pose[bone])
				continue
			if not tracks.has(bone):
				var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
				anim.track_set_path(tr, NodePath(path + ":" + str(bone)))
				tracks[bone] = tr
			anim.rotation_track_insert_key(tracks[bone], t, pose[bone])
	return anim


static func _wave(x: float) -> float:
	return sin(x * TAU)


## The skeleton's rest pose, forward kinematics and leg IK.
class Rig:
	var sk: Skeleton3D
	var idx := {}
	var parent := {}
	var rest := {}          # name -> Transform3D (model-space rest)
	var order: Array = []
	var root_name := ""
	var height := 0.5
	var muzzle := Vector3.ZERO   # nose tip relative to the head bone (rest)
	var Q := {}
	var P := {}
	var root_off := Vector3.ZERO

	func _init(skeleton: Skeleton3D, model: Node3D) -> void:
		sk = skeleton
		for i in sk.get_bone_count():
			var n := sk.get_bone_name(i)
			idx[n] = i
			rest[n] = sk.get_bone_global_rest(i)
			var p := sk.get_bone_parent(i)
			parent[n] = sk.get_bone_name(p) if p >= 0 else ""
			if p < 0:
				root_name = n
		var todo: Array = [root_name]
		while not todo.is_empty():
			var n: String = todo.pop_front()
			order.append(n)
			for c in sk.get_bone_children(idx[n]):
				todo.append(sk.get_bone_name(c))
		# height (withers / back) and the nose tip, from the body mesh
		var top := 0.0
		var front := Vector3(0, 0, -INF)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh
			if m == null or not String(mi.name).to_lower().begins_with("body"):
				continue
			var arr := m.surface_get_arrays(0)
			for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				top = maxf(top, v.y)
				if v.z > front.z:
					front = v
		if has("chest"):
			height = maxf((rest["chest"] as Transform3D).origin.y * 1.08, 0.1)
		else:
			height = maxf(top * 0.8, 0.1)
		if has("head") and front.z > -INF:
			muzzle = front - (rest["head"] as Transform3D).origin

	func has(n: String) -> bool:
		return idx.has(n)

	func reset() -> void:
		Q.clear()
		P.clear()
		root_off = Vector3.ZERO

	## A bone's turn (model axes); bones not turned follow their parent.
	func q(n: String) -> Quaternion:
		if Q.has(n):
			return Q[n]
		var par: String = parent.get(n, "")
		return q(par) if par != "" else Quaternion.IDENTITY

	func rest_pos(n: String) -> Vector3:
		return (rest[n] as Transform3D).origin

	## Model-space position of a bone's origin in the current pose.
	func pos(n: String) -> Vector3:
		if P.has(n):
			return P[n]
		var par: String = parent[n]
		var p: Vector3
		if par == "":
			p = rest_pos(n) + root_off
		else:
			p = pos(par) + q(par) * (rest_pos(n) - rest_pos(par))
		P[n] = p
		return p

	## The rest direction from a bone to its (first) child.
	func rest_dir(n: String, child: String) -> Vector3:
		return (rest_pos(child) - rest_pos(n)).normalized()

	## Turn bone n (and everything after it) by r about model axes, on top of its parent.
	func turn(n: String, r: Quaternion) -> void:
		if not has(n):
			return
		var par: String = parent[n]
		Q[n] = r * q(par) if par != "" else r
		P.clear()

	## Point bone n (whose child is c) along world direction d, following its parent's twist.
	func aim(n: String, c: String, d: Vector3) -> void:
		var par: String = parent[n]
		var base := q(par) if par != "" else Quaternion.IDENTITY
		var cur := base * rest_dir(n, c)
		Q[n] = Quaternion(cur.normalized(), d.normalized()) * base
		P.clear()

	## Local pose rotations for the skeleton.
	func output() -> Dictionary:
		var out := {}
		for n in order:
			var par: String = parent[n]
			var g := q(n) * (rest[n] as Transform3D).basis.get_rotation_quaternion()
			if par == "":
				out[n] = g
			else:
				var pg := q(par) * (rest[par] as Transform3D).basis.get_rotation_quaternion()
				out[n] = (pg.inverse() * g).normalized()
		out["_root"] = (rest[root_name] as Transform3D).origin + root_off
		# the root's position is relative to its (absent) parent: model space
		var rl := sk.get_bone_rest(idx[root_name]).origin
		out["_root"] = rl + root_off
		return out

	## Two-bone leg IK: bones a (upper) and b (lower) reach `target` with the joint
	## bending towards `hint` (model space). Lengths come from the rest pose.
	func two_bone(a: String, b: String, c: String, target: Vector3, hint: Vector3) -> void:
		var A := pos(a)
		var l1 := rest_pos(b).distance_to(rest_pos(a))
		var l2 := rest_pos(c).distance_to(rest_pos(b))
		var d := target - A
		var dist := clampf(d.length(), absf(l1 - l2) + 0.001, (l1 + l2) * 0.999)
		var dn := d.normalized()
		var x := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
		var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
		var perp := hint - dn * hint.dot(dn)
		if perp.length_squared() < 1e-8:
			perp = Vector3.FORWARD
		perp = perp.normalized()
		var knee := A + dn * x + perp * h
		aim(a, b, knee - A)
		aim(b, c, A + dn * dist - knee)

	## A leg: upper, lower, meta, foot, toe-end bones; paw goes to `paw` with the
	## lower leg tilted by `meta_tilt` (radians, + = toes forward) and toes by `toe_tilt`.
	func leg(chain: Array, paw: Vector3, meta_tilt: float, toe_tilt: float, bend: Vector3) -> void:
		var up: String = chain[0]
		var lo: String = chain[1]
		var meta: String = chain[2]
		var foot: String = chain[3]
		if not (has(up) and has(lo) and has(meta) and has(foot)):
			return
		var meta_len := rest_pos(foot).distance_to(rest_pos(meta))
		var mdir := Quaternion(Vector3.RIGHT, -meta_tilt) * rest_dir(meta, foot)
		var hock := paw - mdir * meta_len
		two_bone(up, lo, meta, hock, bend)
		aim(meta, foot, paw - pos(meta))
		var fdir_rest := Vector3(0, 0, 1)
		if chain.size() > 4 and has(chain[4]):
			fdir_rest = rest_dir(foot, chain[4])
		var fd := Quaternion(Vector3.RIGHT, toe_tilt) * fdir_rest
		if chain.size() > 4 and has(chain[4]):
			aim(foot, chain[4], fd)
		else:
			Q[foot] = Quaternion(Vector3.RIGHT, toe_tilt)
			P.clear()

	func rest_paw(n: String) -> Vector3:
		return rest_pos(n)

	# ------------------------------------------------------------------ quadrupeds

	func quad_pose(kind: String, ph: float, g: Array) -> Dictionary:
		reset()
		var H := height
		var legs := {
			"lh": ["thigh_l", "shin_l", "hmeta_l", "hfoot_l", "", 0.0],
			"rh": ["thigh_r", "shin_r", "hmeta_r", "hfoot_r", "", 0.5],
			"lf": ["upperarm_l", "forearm_l", "fmeta_l", "ffoot_l", "", 0.25],
			"rf": ["upperarm_r", "forearm_r", "fmeta_r", "ffoot_r", "", 0.75],
		}
		var stride := 0.0
		var duty := 0.65
		var lift := float(g[5]) * H
		var pitch := 0.0
		var bob := 0.0
		var roll := 0.0
		var head_pitch := 0.0
		var head_yaw := 0.0
		var neck_pitch := 0.0
		var tail_yaw := 0.0
		var tail_pitch := 0.0
		var spine_flex := 0.0
		var phases := {"lh": 0.0, "lf": 0.25, "rh": 0.5, "rf": 0.75}
		match kind:
			"walk":
				stride = float(g[1]) * H
				duty = 0.62
				bob = -0.012 * H * (0.5 + 0.5 * cos(ph * TAU * 2.0))
				roll = 0.03 * sin(ph * TAU)
				head_pitch = 0.05 * sin(ph * TAU * 2.0 + 0.6)
				tail_yaw = 0.18 * sin(ph * TAU)
			"run":
				stride = float(g[3]) * H
				var style := int(g[6])
				if style == 0:   # trot: diagonal pairs
					phases = {"lh": 0.0, "rf": 0.0, "rh": 0.5, "lf": 0.5}
					duty = 0.42
					bob = 0.03 * H * sin(ph * TAU * 2.0)
				elif style == 1:  # gallop
					phases = {"lh": 0.0, "rh": 0.1, "lf": 0.5, "rf": 0.6}
					duty = 0.33
					bob = 0.05 * H * sin(ph * TAU + 0.6)
					pitch = 0.09 * sin(ph * TAU + 1.2)
					spine_flex = 0.16 * sin(ph * TAU + 0.3)
				else:              # hop: hind together, front together
					phases = {"lh": 0.0, "rh": 0.0, "lf": 0.35, "rf": 0.38}
					duty = 0.3
					bob = 0.12 * H * maxf(0.0, sin(ph * TAU + 0.4))
					pitch = 0.15 * sin(ph * TAU + 1.0)
				lift = lift * 1.6
				head_pitch = 0.08 * sin(ph * TAU * 2.0)
				tail_pitch = -0.2
				tail_yaw = 0.1 * sin(ph * TAU)
			"idle":
				bob = 0.004 * H * sin(ph * TAU * 3.0)
				head_yaw = 0.25 * sin(ph * TAU) * smoothstep(0.1, 0.3, fposmod(ph, 0.5))
				head_pitch = -0.05 + 0.04 * sin(ph * TAU * 2.0)
				tail_yaw = 0.25 * sin(ph * TAU * 4.0)
			"look":
				head_yaw = 0.7 * sin(ph * TAU)
				head_pitch = -0.08
				neck_pitch = -0.1
				tail_yaw = 0.15 * sin(ph * TAU * 2.0)
			"eat":
				neck_pitch = 1.0
				head_pitch = 0.5 + 0.06 * sin(ph * TAU * 6.0)
				head_yaw = 0.15 * sin(ph * TAU)
				tail_yaw = 0.2 * sin(ph * TAU * 3.0)
			"sit", "lie":
				pass
		# body
		if kind == "sit":
			return _sit(ph)
		if kind == "lie":
			return _lie(ph)
		root_off = Vector3(0, bob, 0)
		turn(root_name, Quaternion(Vector3.RIGHT, pitch) * Quaternion(Vector3.FORWARD, roll))
		turn("spine1", Quaternion(Vector3.RIGHT, -spine_flex * 0.5))
		turn("spine2", Quaternion(Vector3.RIGHT, -spine_flex * 0.5))
		turn("chest", Quaternion(Vector3.RIGHT, spine_flex * 0.3 - pitch * 0.5))
		_neck_head(neck_pitch, head_pitch, head_yaw, kind == "eat")
		_tail(tail_yaw, tail_pitch, ph)
		# legs
		for k in legs:
			var L: Array = legs[k]
			var hind: bool = str(k).ends_with("h")
			var paw_rest := rest_pos(L[3])
			var p := fposmod(ph - float(phases[k]), 1.0)
			var target := paw_rest
			var meta_tilt := 0.0
			var toe := 0.0
			if stride > 0.0:
				if p < duty:
					var u := p / duty
					target.z += stride * (0.5 - u)
					toe = 0.0
					meta_tilt = 0.0
				else:
					var u := (p - duty) / (1.0 - duty)
					var e := u * u * (3.0 - 2.0 * u)
					target.z += stride * (-0.5 + e)
					target.y += lift * sin(u * PI)
					meta_tilt = (0.5 if hind else -1.1) * sin(u * PI)
					toe = 0.6 * sin(u * PI)
			var bend := Vector3(0, 0, 1) if hind else Vector3(0, 0, -1)
			leg([L[0], L[1], L[2], L[3], L[3].replace("foot", "toe")], target, meta_tilt, toe, bend)
		return output()

	func _neck_head(neck_pitch: float, head_pitch: float, head_yaw: float, to_ground: bool) -> void:
		if to_ground and has("head"):
			# lower the neck until the nose reaches the ground; tip the body forward if the neck is too short
			var body := 0.0
			var best := 1.15
			for attempt in 6:
				var lo := 0.0
				var hi := 1.15
				for i in 14:
					var mid := (lo + hi) * 0.5
					_apply_neck(mid, 0.45, head_yaw)
					var nose := pos("head") + q("head") * muzzle
					if nose.y > height * 0.04:
						lo = mid
					else:
						hi = mid
				best = (lo + hi) * 0.5
				if best < 1.12 or attempt == 5:
					break
				body += 0.06
				turn(root_name, Quaternion(Vector3.RIGHT, body))
				turn("chest", Quaternion(Vector3.RIGHT, body * 0.4))
			_apply_neck(best, head_pitch * 0.4 + 0.3, head_yaw)
			return
		_apply_neck(neck_pitch, head_pitch, head_yaw)

	func _apply_neck(neck_pitch: float, head_pitch: float, head_yaw: float) -> void:
		turn("neck1", Quaternion(Vector3.RIGHT, neck_pitch * 0.55) * Quaternion(Vector3.UP, head_yaw * 0.3))
		turn("neck2", Quaternion(Vector3.RIGHT, neck_pitch * 0.45) * Quaternion(Vector3.UP, head_yaw * 0.35))
		turn("head", Quaternion(Vector3.UP, head_yaw * 0.35) * Quaternion(Vector3.RIGHT, head_pitch))
		for side in ["l", "r"]:
			turn("ear_" + side, Quaternion.IDENTITY)

	func _tail(yaw: float, pitch: float, ph: float) -> void:
		for i in range(1, 8):
			var n := "tail%d" % i
			if not has(n):
				break
			var w := sin(ph * TAU * 2.0 - float(i) * 0.5)
			turn(n, Quaternion(Vector3.UP, yaw * (0.4 + 0.25 * i) * (0.6 + 0.4 * w)) * Quaternion(Vector3.RIGHT, -pitch * 0.25))

	func _plant_all(front_fwd: float, hind_fwd: float, hind_out: float, hind_meta := 0.0, front_meta := 0.0) -> void:
		for k in [["thigh_l", "shin_l", "hmeta_l", "hfoot_l", "htoe_l", true, 1.0], ["thigh_r", "shin_r", "hmeta_r", "hfoot_r", "htoe_r", true, -1.0],
				["upperarm_l", "forearm_l", "fmeta_l", "ffoot_l", "ftoe_l", false, 1.0], ["upperarm_r", "forearm_r", "fmeta_r", "ffoot_r", "ftoe_r", false, -1.0]]:
			var hind: bool = k[5]
			var paw := rest_pos(k[3])
			paw.z += hind_fwd if hind else front_fwd
			if hind:
				paw.x += hind_out * float(k[6])
			var bend := Vector3(0, 0, 1) if hind else Vector3(0, 0, -1)
			leg([k[0], k[1], k[2], k[3], k[4]], paw, hind_meta if hind else front_meta, 0.0, bend)

	## Sitting on the haunches, front legs straight.
	func _sit(ph: float) -> Dictionary:
		var H := height
		var rest_root := rest_pos(root_name)
		var shoulder := "upperarm_l"
		var sh_rest := rest_pos(shoulder)
		var drop := rest_root.y * 0.62
		var lo := -1.2
		var hi := 0.0
		for i in 16:
			var mid := (lo + hi) * 0.5
			reset()
			root_off = Vector3(0, -drop, -0.05 * H)
			turn(root_name, Quaternion(Vector3.RIGHT, mid))
			if pos(shoulder).y > sh_rest.y * 1.02:
				lo = mid
			else:
				hi = mid
		var pitch := (lo + hi) * 0.5
		reset()
		root_off = Vector3(0, -drop, -0.05 * H)
		turn(root_name, Quaternion(Vector3.RIGHT, pitch))
		turn("chest", Quaternion(Vector3.RIGHT, -pitch * 0.15))
		_apply_neck(-pitch * 0.6, -pitch * 0.35 + 0.03 * sin(ph * TAU), 0.25 * sin(ph * TAU) * smoothstep(0.2, 0.4, fposmod(ph, 0.5)))
		_tail(0.15 * sin(ph * TAU * 2.0), 0.6, ph)
		_plant_all(0.02 * H, 0.2 * H, 0.04 * H, 1.3, 0.0)
		return output()

	## Lying down like a sphinx: front legs forward, hind legs folded beside the body.
	func _lie(ph: float) -> Dictionary:
		var H := height
		var rest_root := rest_pos(root_name)
		reset()
		var chest_y := rest_pos("upperarm_l").y if has("upperarm_l") else rest_root.y
		root_off = Vector3(0, -rest_root.y * 0.66, 0)
		var breathe := 0.004 * H * sin(ph * TAU * 3.0)
		root_off.y += breathe
		turn(root_name, Quaternion(Vector3.RIGHT, 0.03) * Quaternion(Vector3.FORWARD, 0.05))
		turn("chest", Quaternion(Vector3.RIGHT, -0.05))
		_apply_neck(-0.25, 0.1 + 0.03 * sin(ph * TAU), 0.3 * sin(ph * TAU) * smoothstep(0.25, 0.4, fposmod(ph, 0.5)))
		_tail(0.08 * sin(ph * TAU * 2.0), 0.5, ph)
		_plant_all(0.3 * H, 0.3 * H, 0.1 * H, 1.35, 1.2)
		return output()

	# ------------------------------------------------------------------ birds

	func bird_pose(kind: String, ph: float) -> Dictionary:
		reset()
		var H := height
		var stride := 0.0
		var lift := 0.08 * H
		var bob := 0.0
		var neck := 0.0
		var head := 0.0
		var yaw := 0.0
		var wing := 0.0
		var duty := 0.6
		match kind:
			"walk":
				stride = 0.45 * H
				bob = 0.02 * H * cos(ph * TAU * 2.0)
				neck = 0.15 * sin(ph * TAU * 2.0)
				yaw = 0.0
			"run":
				stride = 0.9 * H
				duty = 0.4
				bob = 0.04 * H * cos(ph * TAU * 2.0)
				neck = 0.25 * sin(ph * TAU * 2.0)
				wing = 0.3
			"idle":
				head = 0.2 * sin(ph * TAU * 2.0) * smoothstep(0.1, 0.2, fposmod(ph, 0.5))
				yaw = 0.4 * sin(ph * TAU)
			"look":
				yaw = 0.9 * sin(ph * TAU)
				head = 0.2 * sin(ph * TAU * 3.0)
			"peck":
				var pk := smoothstep(0.0, 0.15, fposmod(ph, 0.5)) * (1.0 - smoothstep(0.2, 0.35, fposmod(ph, 0.5)))
				neck = 1.1 * pk
				head = 0.6 * pk
			"sit":
				bob = -0.25 * H
				head = 0.05 * sin(ph * TAU)
				yaw = 0.3 * sin(ph * TAU)
			"flap":
				wing = 1.0
				bob = 0.01 * H * sin(ph * TAU)
		root_off = Vector3(0, bob, 0)
		turn("neck1", Quaternion(Vector3.RIGHT, neck * 0.6) * Quaternion(Vector3.UP, yaw * 0.4))
		turn("neck2", Quaternion(Vector3.RIGHT, neck * 0.4) * Quaternion(Vector3.UP, yaw * 0.3))
		turn("head", Quaternion(Vector3.UP, yaw * 0.3) * Quaternion(Vector3.RIGHT, head))
		if wing > 0.0:
			var a := (sin(ph * TAU * (4.0 if kind == "flap" else 2.0)) * 0.8 + 0.3) * wing
			turn("wing_l", Quaternion(Vector3.FORWARD, -a))
			turn("wing_r", Quaternion(Vector3.FORWARD, a))
		for side in [["l", 0.0], ["r", 0.5]]:
			var foot: String = "foot_" + str(side[0])
			if not has(foot):
				continue
			var paw := rest_pos(foot)
			var toe := 0.0
			if stride > 0.0:
				var p := fposmod(ph - float(side[1]), 1.0)
				if p < duty:
					paw.z += stride * (0.5 - p / duty)
				else:
					var u := (p - duty) / (1.0 - duty)
					paw.z += stride * (-0.5 + u * u * (3.0 - 2.0 * u))
					paw.y += lift * sin(u * PI)
					toe = 0.8 * sin(u * PI)
			if kind == "sit":
				paw = rest_pos(foot)
			leg(["thigh_" + side[0], "shin_" + side[0], "tarsus_" + side[0], foot, "toe_" + side[0]], paw, 0.0, toe, Vector3(0, 0, 1))
		return output()

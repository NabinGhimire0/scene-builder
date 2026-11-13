class_name CharacterMotion
extends RefCounted
## Everything a character needs to pose itself at any timeline time:
##  • its action keys (Idle, Walk, Wave…), and
##  • a pre-sampled table of how far / fast / which way it travels, taken from
##    the compiled timeline animation, so walk cycles match the movement exactly.
## Built by [TimelineController] whenever the animation is rebuilt.

const SAMPLE_RATE := 30.0
const MOVING_SPEED := 0.15  # m/s; slower than this counts as standing still

## Sorted Array of { "t": float, "action": String }.
var actions: Array = []
## Hand-made pose keys: [{ "t", "pose": { joint: [x, y, z] degrees } }], by time.
var poses: Array = []
var distance := PackedFloat32Array()
var speed := PackedFloat32Array()
## Travel direction (yaw, radians) per sample; NAN until it first moves.
var heading := PackedFloat32Array()


static func stationary() -> CharacterMotion:
	return CharacterMotion.new()


## Samples [param position_track] of [param animation] (or -1 for none).
## [param face_keys] ([{ "t", "yaw" (degrees) }], by time) turn a standing
## character to face a direction from that time until it next moves.
static func build(animation: Animation, position_track: int, duration: float, action_keys: Array, face_keys: Array = []) -> CharacterMotion:
	var motion := CharacterMotion.new()
	motion.actions = action_keys
	if (animation == null or position_track < 0) and face_keys.is_empty():
		return motion
	var count := int(ceil(duration * SAMPLE_RATE)) + 1
	var points: Array[Vector3] = []
	for i in count:
		var value: Variant = Vector3.ZERO
		if animation != null and position_track >= 0:
			value = animation.value_track_interpolate(position_track, minf(i / SAMPLE_RATE, duration))
		points.append(value if value is Vector3 else Vector3.ZERO)
	var next_face := 0
	motion.distance.resize(count)
	motion.speed.resize(count)
	motion.heading.resize(count)
	var travelled := 0.0
	var last_heading := NAN
	for i in count:
		if i > 0:
			var step := points[i] - points[i - 1]
			travelled += Vector2(step.x, step.z).length()
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, count - 1)]
		var span := float(mini(i + 1, count - 1) - maxi(i - 1, 0)) / SAMPLE_RATE
		var flat := Vector2(b.x - a.x, b.z - a.z)
		var v := flat.length() / span if span > 0.0 else 0.0
		while next_face < face_keys.size() and float(face_keys[next_face]["t"]) <= float(i) / SAMPLE_RATE + 0.0001:
			last_heading = deg_to_rad(float(face_keys[next_face]["yaw"]))
			next_face += 1
		if v > MOVING_SPEED:
			last_heading = atan2(flat.x, flat.y)
		motion.distance[i] = travelled
		motion.speed[i] = v
		motion.heading[i] = last_heading
	return motion


func distance_at(t: float) -> float:
	return _sample(distance, t)


func speed_at(t: float) -> float:
	return _sample(speed, t)


## World yaw the character is travelling toward (NAN if it hasn't moved yet).
func heading_at(t: float) -> float:
	if heading.is_empty():
		return NAN
	return heading[clampi(int(round(t * SAMPLE_RATE)), 0, heading.size() - 1)]


## Which action is playing at [param t]:
## { "action", "start", "previous", "previous_start" } (previous may be "").
## The hand-made pose at [param t]: joint -> Vector3 degrees, smoothly
## interpolated between pose keys (held before the first / after the last).
func pose_at(t: float) -> Dictionary:
	if poses.is_empty():
		return {}
	var before: Dictionary = poses[0]
	var after: Dictionary = poses[poses.size() - 1]
	for key in poses:
		if float(key["t"]) <= t:
			before = key
		else:
			after = key
			break
	var span := float(after["t"]) - float(before["t"])
	var w := 0.0 if span <= 0.0001 else smoothstep(0.0, 1.0, (t - float(before["t"])) / span)
	if t <= float(before["t"]):
		w = 0.0
	var a: Dictionary = before["pose"]
	var b: Dictionary = after["pose"]
	var out := {}
	for joint in a.keys() + b.keys():
		var va: Vector3 = _vec(a.get(joint, [0, 0, 0]))
		var vb: Vector3 = _vec(b.get(joint, [0, 0, 0]))
		out[joint] = va.lerp(vb, w)
	return out


static func _vec(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO


func action_state(t: float) -> Dictionary:
	var current := MotionLibrary.AUTO
	var start := 0.0
	var previous := ""
	var previous_start := 0.0
	var implicit := true  # the default "Auto" before the first key
	for key in actions:
		var key_time := float(key["t"])
		if key_time > t + 0.0001:
			break
		if implicit and key_time < 0.0001:
			previous = ""  # a key at 0 s replaces the default, no blend
		else:
			previous = current
			previous_start = start
		current = str(key["action"])
		start = key_time
		implicit = false
	return {"action": current, "start": start, "previous": previous, "previous_start": previous_start}


func _sample(values: PackedFloat32Array, t: float) -> float:
	if values.is_empty():
		return 0.0
	var x := clampf(t * SAMPLE_RATE, 0.0, values.size() - 1.0)
	var i := int(floor(x))
	var j := mini(i + 1, values.size() - 1)
	return lerpf(values[i], values[j], x - i)

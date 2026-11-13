class_name CharacterBase
extends Node3D
## Shared behaviour of animated characters (built-in [HumanCharacter] and
## user-imported [ImportedCharacter]).
##
## The timeline calls [method evaluate] with the current time and the
## character's [CharacterMotion]; the character then poses itself. It is a pure
## function of time, so scrubbing, playback and export always agree.

## Turn the body to face where the character is walking.
@export var face_movement := true:
	set(value):
		face_movement = value
		if not face_movement and _body:
			_body.rotation.y = 0.0

## Lip sync from an audio clip: { "clip": name, "start": seconds, "fps": 30,
## "env": mouth openness 0..1 per frame }. Empty = none.
var lipsync: Dictionary = {}
## Joint rotations shown while a joint is being dragged in the 3D view (joint ->
## degrees); they replace the keyed pose of those joints until the drag ends.
var pose_preview: Dictionary = {}

var _body: Node3D


## Builds visuals/colliders now (called before the node is measured or placed).
func ensure_built() -> void:
	pass


## Joints that can be posed by hand (Inspector → Pose), in display order.
const POSE_JOINTS: PackedStringArray = [
	"Head", "Neck", "Chest", "Spine", "Hips",
	"Left shoulder", "Left elbow", "Left wrist", "Right shoulder", "Right elbow", "Right wrist",
	"Left hip", "Left knee", "Left ankle", "Right hip", "Right knee", "Right ankle"]
const POSE_ONLY := "Pose only"


## Adds hand-made joint rotations (degrees) on top of the current pose.
func apply_manual_pose(_pose: Dictionary) -> void:
	pass


# --- Posing in the 3D view (see PoseTool) ---------------------------------------

## Joint names used by film scripts ("shoulder_r") → the names the pose tools use.
const SCRIPT_JOINTS := {
	"hips": "Hips", "spine": "Spine", "chest": "Chest", "neck": "Neck", "head": "Head",
	"shoulder_l": "Left shoulder", "elbow_l": "Left elbow", "wrist_l": "Left wrist",
	"shoulder_r": "Right shoulder", "elbow_r": "Right elbow", "wrist_r": "Right wrist",
	"hip_l": "Left hip", "knee_l": "Left knee", "ankle_l": "Left ankle",
	"hip_r": "Right hip", "knee_r": "Right knee", "ankle_r": "Right ankle"}


## The keyed hand pose (with script joint names translated) and any drag preview on top.
func with_preview(pose: Dictionary) -> Dictionary:
	var named := pose
	for key in pose:
		if SCRIPT_JOINTS.has(key):
			named = {}
			for k in pose:
				named[SCRIPT_JOINTS.get(k, k)] = pose[k]
			break
	if pose_preview.is_empty():
		return named
	var out := named.duplicate()
	for joint in pose_preview:
		out[joint] = pose_preview[joint]
	return out


## World position of a pose joint, or [code]Vector3.INF[/code] if this character
## doesn't have it.
## How far above its feet (the node's origin) this character's hips are in a still
## pose such as "Sit" or "Lie Down", in metres at its current size; -1 if unknown.
## Used to put people *on* a seat or a bed instead of into it.
func pose_hip_height(_pose: String) -> float:
	return -1.0


func joint_position(_joint: String) -> Vector3:
	return Vector3.INF


## World point that [param joint] points at (the next joint along the limb),
## used to aim the limb at the mouse.
func joint_tip(_joint: String) -> Vector3:
	return Vector3.INF


## Captures what a drag of [param joint] needs; [param manual] is the joint's
## current hand rotation (degrees). Empty if the joint can't be dragged.
func pose_drag_begin(_joint: String, _manual: Vector3) -> Dictionary:
	return {}


## The joint's new hand rotation (degrees) after turning it by [param world_turn]
## (a rotation in world space, relative to the pose when the drag began).
func pose_drag_euler(state: Dictionary, _world_turn: Quaternion) -> Vector3:
	return state.get("manual", Vector3.ZERO)


## Keeps each angle within ±180° of [param near] so drags never jump a full turn.
static func unwrap_degrees(value: Vector3, near: Vector3) -> Vector3:
	var out := value
	for axis in 3:
		out[axis] = near[axis] + wrapf(value[axis] - near[axis], -180.0, 180.0)
		if absf(out[axis]) > 180.0:
			out[axis] = wrapf(out[axis], -180.0, 180.0)   # same rotation; a clamp would bend the limb
	return out


## Adds a clip's mouth movement to a lip sync, keeping what was already there
## (a character can lip-sync to several clips). Overlaps keep the wider mouth.
static func merge_lipsync(current: Dictionary, clip_name: String, start: float, env: PackedFloat32Array, fps: float = 30.0) -> Dictionary:
	if current.is_empty() or (current.get("env", PackedFloat32Array()) as PackedFloat32Array).is_empty():
		return {"clip": clip_name, "start": start, "fps": fps, "env": env}
	var old_env: PackedFloat32Array = current["env"]
	var old_start := float(current.get("start", 0.0))
	var old_fps := float(current.get("fps", 30.0))
	var begin := minf(old_start, start)
	var end := maxf(old_start + old_env.size() / old_fps, start + env.size() / fps)
	var merged := PackedFloat32Array()
	merged.resize(int(ceil((end - begin) * fps)) + 1)
	for i in merged.size():
		var t := begin + float(i) / fps
		var a := 0.0
		var x := (t - old_start) * old_fps
		if x >= 0.0 and x < old_env.size():
			a = old_env[int(x)]
		var b := 0.0
		var y := (t - start) * fps
		if y >= 0.0 and y < env.size():
			b = env[int(y)]
		merged[i] = maxf(a, b)
	var names := str(current.get("clip", ""))
	if not names.split(", ").has(clip_name):
		names = clip_name if names.is_empty() else names + ", " + clip_name
	return {"clip": names, "start": begin, "fps": fps, "env": merged}


## Actions the user can pick for this character. The first is always "Auto".
func action_names() -> PackedStringArray:
	return PackedStringArray([MotionLibrary.AUTO])


func action_hint(action: String) -> String:
	return MotionLibrary.ACTION_HINTS.get(action, "")


## Poses the character for timeline time [param t].
func evaluate(t: float, motion: CharacterMotion) -> void:
	_apply_facing(t, motion)


## Height scale relative to the 1.75 m reference (affects stride length).
func size_factor() -> float:
	return 1.0


## Extra per-object state saved in project files and copied on duplicate.
func get_custom_state() -> Dictionary:
	var state := {"face_movement": face_movement}
	if not lipsync.is_empty():
		var env: PackedFloat32Array = lipsync.get("env", PackedFloat32Array())
		var rounded: Array = []
		for v in env:
			rounded.append(snappedf(v, 0.01))
		state["lipsync"] = {"clip": lipsync.get("clip", ""), "start": lipsync.get("start", 0.0), "fps": lipsync.get("fps", 30.0), "env": rounded}
	return state


func set_custom_state(state: Dictionary) -> void:
	if state.has("face_movement"):
		face_movement = bool(state["face_movement"])
	var sync: Variant = state.get("lipsync")
	if sync is Dictionary and (sync as Dictionary).get("env") is Array:
		lipsync = {"clip": str(sync.get("clip", "")), "start": float(sync.get("start", 0.0)),
			"fps": float(sync.get("fps", 30.0)), "env": PackedFloat32Array(sync["env"])}
	else:
		lipsync = {}


## Mouth openness 0..1 from lip sync at time [param t], or -1 without lip sync.
func lipsync_at(t: float) -> float:
	if lipsync.is_empty():
		return -1.0
	var env: PackedFloat32Array = lipsync["env"]
	var x := (t - float(lipsync["start"])) * float(lipsync["fps"])
	if x < 0.0 or x >= env.size() - 1:
		return 0.0
	var i := int(x)
	return lerpf(env[i], env[i + 1], x - float(i))


func _apply_facing(t: float, motion: CharacterMotion) -> void:
	if _body == null or not face_movement or not is_inside_tree():
		return
	var heading := motion.heading_at(t)
	if is_nan(heading):
		_body.rotation.y = 0.0
		return
	_body.rotation.y = wrapf(heading - global_rotation.y, -PI, PI)


## Shared "Auto" logic: idle / walk / run weights from travel speed.
## Returns [idle_weight_unused, walk_weight, run_weight, walk_phase, run_phase].
func _locomotion(t: float, motion: CharacterMotion) -> Dictionary:
	var k := maxf(size_factor(), 0.1)
	var v := motion.speed_at(t) / k
	var d := motion.distance_at(t) / k
	return {
		"moving": v > CharacterMotion.MOVING_SPEED * 0.5,
		"walk": smoothstep(0.05, 0.5, v),
		"run": smoothstep(2.4, 3.4, v),
		"walk_phase": d / MotionLibrary.WALK_STRIDE,
		"run_phase": d / MotionLibrary.RUN_STRIDE,
	}

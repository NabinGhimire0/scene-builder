class_name HumanCharacter
extends CharacterBase
## A customisable, fully animated stylised human built from simple shapes.
##
## Everything is generated in code: a joint hierarchy (hips → spine → chest →
## neck → head, arms, legs) with body parts attached, coloured from the
## appearance settings. [MotionLibrary] provides the motions; the timeline picks
## the action and drives the walk cycle from the character's movement.
##
## All appearance settings are plain properties, so they can be edited (and
## undone) from the Inspector and are saved with the project.

const BODY_TYPES: PackedStringArray = ["Man", "Woman", "Child", "Elder"]
const HAIR_STYLES: PackedStringArray = ["Short", "Long", "Bun", "Ponytail", "Bald"]
const BOTTOM_STYLES: PackedStringArray = ["Trousers", "Shorts", "Skirt"]
const OUTFITS: PackedStringArray = ["Casual", "Sweater", "Coat"]
const HATS: PackedStringArray = ["None", "Beanie"]
const REFERENCE_HEIGHT := 1.75
const APPEARANCE: PackedStringArray = [
	"body_type", "height", "build", "skin_color", "hair_color", "hair_style",
	"top_color", "bottom_color", "bottom_style", "shoe_color",
	"outfit", "coat_color", "scarf_color", "hat", "glasses"]
## Values applied when the body type is changed in the Inspector.
const PRESETS := {
	"Man": {"height": 1.78, "build": 1.0, "hair_style": "Short", "bottom_style": "Trousers"},
	"Woman": {"height": 1.66, "build": 0.9, "hair_style": "Long", "bottom_style": "Skirt"},
	"Child": {"height": 1.2, "build": 0.9, "hair_style": "Short", "bottom_style": "Shorts"},
	"Elder": {"height": 1.7, "build": 1.0, "hair_style": "Short", "bottom_style": "Trousers",
		"hair_color": Color(0.8, 0.8, 0.78)},
}
const PROPORTIONS := {
	"Man": {"shoulder": 0.2, "hip": 0.1, "chest": Vector3(1.22, 1.0, 0.78), "pelvis": Vector3(1.0, 1.0, 1.0), "head": 1.0, "posture": 0.0},
	"Woman": {"shoulder": 0.175, "hip": 0.105, "chest": Vector3(1.08, 1.0, 0.82), "pelvis": Vector3(1.15, 1.0, 1.05), "head": 0.97, "posture": 0.0},
	"Child": {"shoulder": 0.175, "hip": 0.095, "chest": Vector3(1.1, 1.0, 0.85), "pelvis": Vector3(1.0, 1.0, 1.0), "head": 1.32, "posture": 0.0},
	"Elder": {"shoulder": 0.195, "hip": 0.1, "chest": Vector3(1.2, 1.0, 0.84), "pelvis": Vector3(1.0, 1.0, 1.0), "head": 1.0, "posture": 1.0},
}
const EYE_COLOR := Color(0.08, 0.07, 0.07)
const MOUTH_COLOR := Color(0.55, 0.25, 0.23)

@export_enum("Man", "Woman", "Child", "Elder") var body_type: String = "Man":
	set(v):
		body_type = v if PROPORTIONS.has(v) else "Man"
		_mark_dirty()
@export_range(0.8, 2.2, 0.01) var height := 1.78:
	set(v):
		height = clampf(v, 0.8, 2.2)
		_mark_dirty()
## Body width: 0.7 slim … 1.3 broad.
@export_range(0.7, 1.3, 0.01) var build := 1.0:
	set(v):
		build = clampf(v, 0.7, 1.3)
		_mark_dirty()
@export var skin_color := Color(0.87, 0.67, 0.53):
	set(v):
		skin_color = v
		_mark_dirty()
@export var hair_color := Color(0.2, 0.13, 0.08):
	set(v):
		hair_color = v
		_mark_dirty()
@export_enum("Short", "Long", "Bun", "Ponytail", "Bald") var hair_style: String = "Short":
	set(v):
		hair_style = v
		_mark_dirty()
@export var top_color := Color(0.75, 0.25, 0.2):
	set(v):
		top_color = v
		_mark_dirty()
@export var bottom_color := Color(0.2, 0.25, 0.36):
	set(v):
		bottom_color = v
		_mark_dirty()
@export_enum("Trousers", "Shorts", "Skirt") var bottom_style: String = "Trousers":
	set(v):
		bottom_style = v
		_mark_dirty()
@export var shoe_color := Color(0.12, 0.11, 0.11):
	set(v):
		shoe_color = v
		_mark_dirty()
## Casual: short sleeves. Sweater: long sleeves in the top colour. Coat: a long coat
## (coat_color) over the top.
@export_enum("Casual", "Sweater", "Coat") var outfit: String = "Casual":
	set(v):
		outfit = v if v in OUTFITS else "Casual"
		_mark_dirty()
@export var coat_color := Color(0.36, 0.27, 0.2):
	set(v):
		coat_color = v
		_mark_dirty()
## A scarf in this colour; fully transparent (alpha 0) means no scarf.
@export var scarf_color := Color(0.7, 0.15, 0.15, 0.0):
	set(v):
		scarf_color = v
		_mark_dirty()
@export_enum("None", "Beanie") var hat: String = "None":
	set(v):
		hat = v if v in HATS else "None"
		_mark_dirty()
@export var glasses := false:
	set(v):
		glasses = v
		_mark_dirty()

var _joints: Dictionary = {}       # name -> Node3D
var _eyes: Array = []
var _mouth: MeshInstance3D
var _hips_rest := Vector3.ZERO
var _built := false
var _dirty := true
var _posture := 0.0


func _ready() -> void:
	ensure_built()


func ensure_built() -> void:
	if _built and not _dirty:
		return
	_rebuild()


func size_factor() -> float:
	return height / REFERENCE_HEIGHT


func action_names() -> PackedStringArray:
	return MotionLibrary.ACTIONS


func get_custom_state() -> Dictionary:
	var state := super.get_custom_state()
	for property in APPEARANCE:
		var value: Variant = get(property)
		state[property] = [value.r, value.g, value.b, value.a] if value is Color else value
	return state


func set_custom_state(state: Dictionary) -> void:
	super.set_custom_state(state)
	for property in APPEARANCE:
		if not state.has(property):
			continue
		var value: Variant = state[property]
		if get(property) is Color:
			if value is Array and value.size() >= 3:
				set(property, Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]) if value.size() > 3 else 1.0))
		elif get(property) is float:
			set(property, float(value))
		elif get(property) is bool:
			set(property, bool(value))
		else:
			set(property, str(value))


func evaluate(t: float, motion: CharacterMotion) -> void:
	ensure_built()
	var state := motion.action_state(t)
	var since := t - float(state["start"])
	var pose := _pose_for(str(state["action"]), since, t, motion)
	var previous := str(state["previous"])
	if not previous.is_empty() and since < MotionLibrary.BLEND_TIME:
		var before := _pose_for(previous, t - float(state["previous_start"]), t, motion)
		pose = MotionLibrary.blend(before, pose, smoothstep(0.0, MotionLibrary.BLEND_TIME, since))
	apply_pose(pose)
	apply_manual_pose(with_preview(motion.pose_at(t)))
	_apply_facing(t, motion)
	_animate_face(t, str(state["action"]), since)


const _JOINT_NAMES := {
	"Head": "head", "Neck": "neck", "Chest": "chest", "Spine": "spine", "Hips": "hips",
	"Left shoulder": "shoulder_l", "Left elbow": "elbow_l", "Left wrist": "wrist_l",
	"Right shoulder": "shoulder_r", "Right elbow": "elbow_r", "Right wrist": "wrist_r",
	"Left hip": "hip_l", "Left knee": "knee_l", "Left ankle": "ankle_l",
	"Right hip": "hip_r", "Right knee": "knee_r", "Right ankle": "ankle_r"}


func apply_manual_pose(pose: Dictionary) -> void:
	for joint in pose:
		var node: Node3D = _joints.get(_JOINT_NAMES.get(joint, ""))
		if node:
			node.rotation_degrees += pose[joint] as Vector3


## Where each joint points (the next joint), or a point in the joint's own space.
const _JOINT_TIPS := {
	"Hips": "chest", "Spine": "chest", "Chest": "neck", "Neck": "head", "Head": Vector3(0, 0.24, 0.02),
	"Left shoulder": "elbow_l", "Left elbow": "wrist_l", "Left wrist": Vector3(0, -0.12, 0),
	"Right shoulder": "elbow_r", "Right elbow": "wrist_r", "Right wrist": Vector3(0, -0.12, 0),
	"Left hip": "knee_l", "Left knee": "ankle_l", "Left ankle": Vector3(0, -0.06, 0.14),
	"Right hip": "knee_r", "Right knee": "ankle_r", "Right ankle": Vector3(0, -0.06, 0.14)}


func pose_hip_height(pose_name: String) -> float:
	ensure_built()
	# The hips' drop in each still pose (MotionLibrary.sit / lie_down / kneel "offset").
	var drop := {"Sit": -0.43, "Lie Down": -0.8, "Kneel": -0.42}
	if not drop.has(pose_name):
		return -1.0
	var body_scale := _body.scale.y if _body else 1.0
	var body_y := _body.position.y if _body else 0.0
	# Not including this node's own scale (the caller knows the real size).
	return body_y + (_hips_rest.y + float(drop[pose_name])) * body_scale


func joint_position(joint: String) -> Vector3:
	ensure_built()
	var node: Node3D = _joints.get(_JOINT_NAMES.get(joint, ""))
	return node.global_position if node and node.is_inside_tree() else Vector3.INF


func joint_tip(joint: String) -> Vector3:
	var node: Node3D = _joints.get(_JOINT_NAMES.get(joint, ""))
	if node == null or not node.is_inside_tree():
		return Vector3.INF
	var tip: Variant = _JOINT_TIPS.get(joint)
	if tip is Vector3:
		return node.global_transform * (tip as Vector3)
	var child: Node3D = _joints.get(str(tip))
	return child.global_position if child else Vector3.INF


func pose_drag_begin(joint: String, manual: Vector3) -> Dictionary:
	var node: Node3D = _joints.get(_JOINT_NAMES.get(joint, ""))
	if node == null or not node.is_inside_tree():
		return {}
	var parent := node.get_parent() as Node3D
	return {"manual": manual, "local": node.basis.get_rotation_quaternion(),
		"parent": parent.global_basis.orthonormalized().get_rotation_quaternion() if parent else Quaternion.IDENTITY,
		"action": node.rotation_degrees - manual}


## The joint's local rotation is the action's angles plus the hand angles, so the
## new hand angles are the turned local rotation minus the action's angles.
func pose_drag_euler(state: Dictionary, world_turn: Quaternion) -> Vector3:
	if state.is_empty():
		return Vector3.ZERO
	var parent: Quaternion = state["parent"]
	var turned: Quaternion = parent.inverse() * world_turn * parent * (state["local"] as Quaternion)
	var euler := turned.get_euler()
	var degrees := Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)) - (state["action"] as Vector3)
	return unwrap_degrees(degrees, state["manual"])


## Blinks every few seconds and moves the lips while talking.
func _animate_face(t: float, action: String, since: float) -> void:
	var seed_value := float(hash(name) % 97)
	var cycle := fposmod(t + seed_value * 0.37, 3.7 + fposmod(seed_value, 1.3))
	var closed := 1.0 - smoothstep(0.0, 0.06, absf(cycle - 0.08))
	for eye in _eyes:
		if is_instance_valid(eye):
			(eye as Node3D).scale.y = lerpf(1.0, 0.12, closed)
	if is_instance_valid(_mouth):
		var open := 0.0
		var synced := lipsync_at(t)
		if synced >= 0.0:
			open = synced
		elif action == "Talk" or action == "Phone call":
			open = clampf(0.5 + 0.5 * sin(since * 13.0) * sin(since * 4.1 + 0.7), 0.0, 1.0)
		_mouth.scale.y = 1.0 + open * 2.8


func apply_pose(pose: Dictionary) -> void:
	for joint_name in _joints:
		var joint: Node3D = _joints[joint_name]
		var rotation_deg: Vector3 = pose.get(joint_name, Vector3.ZERO)
		if _posture > 0.0 and joint_name in ["spine", "chest", "neck"]:
			rotation_deg.x += 7.0 * _posture
		joint.rotation_degrees = rotation_deg
	if _joints.has("hips"):
		(_joints["hips"] as Node3D).position = _hips_rest + (pose.get("offset", Vector3.ZERO) as Vector3)


func _pose_for(action: String, local_time: float, t: float, motion: CharacterMotion) -> Dictionary:
	var loco := _locomotion(t, motion)
	match action:
		MotionLibrary.AUTO:
			var p := MotionLibrary.idle(t)
			if float(loco["walk"]) > 0.0:
				p = MotionLibrary.blend(p, MotionLibrary.walk(loco["walk_phase"]), loco["walk"])
			if float(loco["run"]) > 0.0:
				p = MotionLibrary.blend(p, MotionLibrary.run(loco["run_phase"]), loco["run"])
			return p
		"Walk":
			return MotionLibrary.walk(loco["walk_phase"] if loco["moving"] else local_time * MotionLibrary.WALK_CADENCE)
		"Run":
			return MotionLibrary.run(loco["run_phase"] if loco["moving"] else local_time * MotionLibrary.RUN_CADENCE)
	return MotionLibrary.pose(action, local_time)


func _mark_dirty() -> void:
	_dirty = true
	if _built and is_inside_tree():
		_rebuild()


# --- Construction ----------------------------------------------------------------

func _rebuild() -> void:
	if _body:
		remove_child(_body)
		_body.free()
	_joints.clear()
	var p: Dictionary = PROPORTIONS[body_type]
	_posture = float(p["posture"])
	var w := build
	var woman := body_type == "Woman"
	var skin := _skin_material(skin_color)
	var hair := _material(hair_color, 0.55)
	var top := _material(top_color, 0.85)
	var bottom := _material(bottom_color, 0.85)
	var shoe := _material(shoe_color, 0.45)
	var lips := _material(skin_color.lerp(MOUTH_COLOR, 0.55), 0.5)
	var coat := _material(coat_color, 0.9)
	var long_sleeves := outfit != "Casual"
	var sleeve := coat if outfit == "Coat" else top
	var legs_skin := bottom_style != "Trousers"

	_body = Node3D.new()
	_body.name = "Body"
	_body.scale = Vector3.ONE * size_factor()
	add_child(_body)

	# Torso: smooth turned shapes, flattened front to back.
	var hips := _joint("hips", _body, Vector3(0, 0.93, 0))
	_hips_rest = hips.position
	var pelvis: Vector3 = p["pelvis"]
	_part(hips, _lathe([Vector2(0.075, -0.13), Vector2(0.12, -0.1), Vector2(0.148, -0.04), Vector2(0.152, 0.02),
		Vector2(0.14, 0.08), Vector2(0.128, 0.13)]), Vector3.ZERO, bottom, Vector3(1.05 * w * pelvis.x, 1.0, 0.74 * w * pelvis.z))
	var spine := _joint("spine", hips, Vector3(0, 0.1, 0))
	var waist := 0.118 if woman else 0.126
	_part(spine, _lathe([Vector2(0.13, -0.02), Vector2(waist, 0.06), Vector2(waist + 0.004, 0.14), Vector2(0.136, 0.23)]),
		Vector3.ZERO, top, Vector3(1.1 * w, 1.0, 0.74 * w))
	var chest := _joint("chest", spine, Vector3(0, 0.2, 0))
	var chest_scale: Vector3 = p["chest"]
	_part(chest, _lathe([Vector2(0.134, -0.03), Vector2(0.15, 0.06), Vector2(0.158, 0.14), Vector2(0.148, 0.2),
		Vector2(0.12, 0.245), Vector2(0.065, 0.275), Vector2(0.05, 0.285)]), Vector3.ZERO, top,
		Vector3(chest_scale.x * w * 0.98, 1.0, chest_scale.z * w * 0.92))
	# A collar line at the neck.
	_part(chest, _lathe([Vector2(0.062, 0.255), Vector2(0.066, 0.275), Vector2(0.058, 0.29)], 20), Vector3.ZERO, top)
	if bottom_style == "Skirt":
		_part(hips, _lathe([Vector2(0.15, 0.03), Vector2(0.17, -0.1), Vector2(0.22, -0.3), Vector2(0.25, -0.42)], 28),
			Vector3.ZERO, bottom, Vector3(w * pelvis.x, 1.0, 0.85 * w))
	if outfit == "Coat":
		_part(chest, _lathe([Vector2(0.145, -0.04), Vector2(0.162, 0.06), Vector2(0.17, 0.14), Vector2(0.16, 0.2),
			Vector2(0.13, 0.245), Vector2(0.08, 0.275)]), Vector3.ZERO, coat, Vector3(chest_scale.x * w, 1.0, chest_scale.z * w * 0.98))
		_part(spine, _lathe([Vector2(0.146, -0.03), Vector2(0.14, 0.08), Vector2(0.146, 0.23)]), Vector3.ZERO, coat,
			Vector3(1.12 * w, 1.0, 0.8 * w))
		_part(hips, _lathe([Vector2(0.15, 0.13), Vector2(0.166, 0.0), Vector2(0.18, -0.15), Vector2(0.2, -0.36)], 28),
			Vector3.ZERO, coat, Vector3(1.05 * w * pelvis.x, 1.0, 0.82 * w))
		# Lapels and buttons down the front.
		for i in 4:
			_part(chest if i < 2 else spine, _sphere(0.009), Vector3(0, 0.15 - (i % 2) * 0.09, 0.128 * w * chest_scale.z) if i < 2
				else Vector3(0, 0.16 - (i % 2) * 0.09, 0.108 * w), _material(coat_color.darkened(0.45), 0.4))
		_part(chest, _lathe([Vector2(0.075, 0.24), Vector2(0.085, 0.27), Vector2(0.078, 0.31)], 20), Vector3.ZERO, coat)
	if scarf_color.a > 0.05:
		var scarf := _material(Color(scarf_color.r, scarf_color.g, scarf_color.b), 0.95)
		_part(chest, _lathe([Vector2(0.07, 0.24), Vector2(0.09, 0.26), Vector2(0.092, 0.3), Vector2(0.075, 0.33)], 20),
			Vector3.ZERO, scarf, Vector3(1.1, 1.0, 1.05))
		_part(chest, _capsule(0.03, 0.24), Vector3(0.035, 0.15, 0.12 * w), scarf, Vector3(1.2, 1.0, 0.45), Vector3(0, 0, 6))

	# Head.
	var neck := _joint("neck", chest, Vector3(0, 0.24, 0))
	_part(neck, _lathe([Vector2(0.056, -0.01), Vector2(0.05, 0.06), Vector2(0.048, 0.13)], 18), Vector3.ZERO, skin)
	var head := _joint("head", neck, Vector3(0, 0.09, 0))
	var face := Node3D.new()
	face.name = "Face"
	face.scale = Vector3.ONE * float(p["head"])
	head.add_child(face)
	_part(face, _lathe([Vector2(0.0, -0.015), Vector2(0.03, -0.012), Vector2(0.058, 0.005), Vector2(0.078, 0.035),
		Vector2(0.09, 0.075), Vector2(0.097, 0.12), Vector2(0.099, 0.155), Vector2(0.094, 0.19), Vector2(0.078, 0.22),
		Vector2(0.048, 0.24), Vector2(0.0, 0.25)], 28), Vector3.ZERO, skin, Vector3(0.9, 1.0, 1.04))
	# Eyes: white, iris, and a tiny highlight; eyelids are the blink (scale).
	var white := _material(Color(0.95, 0.94, 0.92), 0.25)
	var iris := _material(EYE_COLOR, 0.15)
	var shine := StandardMaterial3D.new()
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shine.albedo_color = Color(1, 1, 1)
	_eyes = []
	for side in [1.0, -1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(0.035 * side, 0.118, 0.082)
		face.add_child(eye)
		_part(eye, _sphere(0.017), Vector3.ZERO, white, Vector3(1.0, 0.85, 0.6))
		_part(eye, _sphere(0.0105), Vector3(0, -0.0005, 0.0075), iris, Vector3(1.0, 1.0, 0.5))
		_part(eye, _sphere(0.0028), Vector3(0.004, 0.0045, 0.0125), shine)
		# Upper lid crease in skin, so the eye sits in the face.
		_part(face, _sphere(0.019), Vector3(0.035 * side, 0.124, 0.078), skin, Vector3(1.05, 0.45, 0.6))
		_eyes.append(eye)
		# Eyebrow: a soft arc.
		_part(face, _capsule(0.006, 0.042), Vector3(0.037 * side, 0.146, 0.092), hair, Vector3(1, 1, 0.7), Vector3(0, 0, 90 - 10 * side))
		# Ear.
		_part(face, _sphere(0.022), Vector3(0.087 * side, 0.115, 0.0), skin, Vector3(0.45, 1.0, 0.75))
		# Cheek: a hint of warmth.
		_part(face, _sphere(0.02), Vector3(0.05 * side, 0.085, 0.07), _material(skin_color.lerp(Color(0.9, 0.45, 0.42), 0.1), 0.6), Vector3(1, 0.7, 0.4))
	# Nose: bridge and tip.
	_part(face, _capsule(0.011, 0.05), Vector3(0, 0.1, 0.095), skin, Vector3(1, 1, 0.9), Vector3(-14, 0, 0))
	_part(face, _sphere(0.015), Vector3(0, 0.08, 0.104), skin, Vector3(1.05, 0.85, 0.9))
	# Mouth: lips that open (scale) when talking.
	var mouth_mesh := SphereMesh.new()
	mouth_mesh.radius = 0.021
	mouth_mesh.height = 0.009
	mouth_mesh.radial_segments = 16
	mouth_mesh.rings = 6
	_mouth = _part(face, mouth_mesh, Vector3(0, 0.05, 0.088), lips, Vector3(1, 1, 0.55))
	if glasses:
		var frame := _material(Color(0.12, 0.1, 0.09), 0.3)
		for side in [1.0, -1.0]:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.019
			ring.outer_radius = 0.023
			ring.rings = 20
			ring.ring_segments = 6
			_part(face, ring, Vector3(0.036 * side, 0.118, 0.1), frame, Vector3.ONE, Vector3(90, 0, 0))
			_part(face, _box(Vector3(0.003, 0.003, 0.085)), Vector3(0.062 * side, 0.122, 0.058), frame, Vector3.ONE, Vector3(0, 12 * side, 0))
		_part(face, _box(Vector3(0.018, 0.004, 0.004)), Vector3(0, 0.122, 0.104), frame)
	_build_hair(face, hair)

	# Arms: tapered, with long or short sleeves, and simple hands with a thumb.
	for side in [1.0, -1.0]:
		var suffix := "_l" if side > 0.0 else "_r"
		var shoulder := _joint("shoulder" + suffix, chest, Vector3(float(p["shoulder"]) * w * side, 0.19, 0))
		var outer := coat if outfit == "Coat" else top
		_part(shoulder, _sphere(0.054 * w), Vector3(-0.008 * side, -0.01, 0), outer, Vector3(1.0, 0.95, 0.95))
		# Trapezius: a smooth slope from the neck to the shoulder, so there's no ball joint.
		_part(chest, _capsule(0.05 * w, float(p["shoulder"]) * w + 0.03), Vector3(float(p["shoulder"]) * w * side * 0.5, 0.2, -0.005),
			outer, Vector3(1.0, 1.0, 0.8), Vector3(0, 0, 90 - 12 * side))
		_part(shoulder, _lathe([Vector2(0.06, 0.0), Vector2(0.056, -0.1), Vector2(0.047, -0.27), Vector2(0.044, -0.3)], 16),
			Vector3.ZERO, sleeve if outfit == "Coat" else top, Vector3(w, 1.0, w))
		var elbow := _joint("elbow" + suffix, shoulder, Vector3(0, -0.29, 0))
		if long_sleeves:
			_part(elbow, _lathe([Vector2(0.047, 0.02), Vector2(0.046, -0.08), Vector2(0.04, -0.21), Vector2(0.042, -0.235)], 16),
				Vector3.ZERO, sleeve, Vector3(w, 1.0, w))
			_part(elbow, _lathe([Vector2(0.03, -0.2), Vector2(0.028, -0.26)], 12), Vector3.ZERO, skin)
		else:
			_part(elbow, _lathe([Vector2(0.044, 0.02), Vector2(0.042, -0.07), Vector2(0.032, -0.24)], 16), Vector3.ZERO, skin, Vector3(w, 1.0, w))
		var wrist := _joint("wrist" + suffix, elbow, Vector3(0, -0.25, 0))
		_part(wrist, _sphere(0.04), Vector3(0, -0.05, 0.003), skin, Vector3(0.75, 1.2, 0.45))
		_part(wrist, _capsule(0.012, 0.045), Vector3(0.022 * side, -0.035, 0.018), skin, Vector3.ONE, Vector3(-20, 0, -25 * side))

	# Legs: shaped thighs and calves; rounded shoes.
	for side in [1.0, -1.0]:
		var suffix := "_l" if side > 0.0 else "_r"
		var hip := _joint("hip" + suffix, hips, Vector3(float(p["hip"]) * w * side, -0.04, 0))
		var thigh := skin if bottom_style == "Skirt" else bottom
		_part(hip, _lathe([Vector2(0.084, 0.03), Vector2(0.08, -0.12), Vector2(0.066, -0.33), Vector2(0.056, -0.44)], 16), Vector3.ZERO, thigh, Vector3(w, 1.0, w))
		if bottom_style == "Shorts":
			_part(hip, _lathe([Vector2(0.09, 0.03), Vector2(0.088, -0.1), Vector2(0.08, -0.22)], 16), Vector3.ZERO, bottom, Vector3(w, 1.0, w))
		var knee := _joint("knee" + suffix, hip, Vector3(0, -0.43, 0))
		_part(knee, _lathe([Vector2(0.056, 0.02), Vector2(0.06, -0.09), Vector2(0.046, -0.3), Vector2(0.04, -0.39)], 16),
			Vector3.ZERO, skin if legs_skin else bottom, Vector3(w, 1.0, w))
		var ankle := _joint("ankle" + suffix, knee, Vector3(0, -0.39, 0))
		_part(ankle, _capsule(0.05, 0.25), Vector3(0, -0.04, 0.05), shoe, Vector3(0.95 * w, 0.62, 1.0), Vector3(90, 0, 0))
		_part(ankle, _box(Vector3(0.1 * w, 0.018, 0.25)), Vector3(0, -0.068, 0.05), _material(shoe_color.lightened(0.35), 0.7))

	# Clickable / stackable collider (on the Props layer).
	var collider := StaticBody3D.new()
	collider.name = "Collider"
	collider.collision_layer = Layers.PROPS
	collider.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26 * w
	capsule.height = 1.78
	shape.shape = capsule
	shape.position = Vector3(0, 0.89, 0)
	collider.add_child(shape)
	_body.add_child(collider)

	_built = true
	_dirty = false
	apply_pose(MotionLibrary.idle(0.0))


func _build_hair(face: Node3D, hair: Material) -> void:
	if hat == "Beanie":
		var knit := _material(Color(scarf_color.r, scarf_color.g, scarf_color.b) if scarf_color.a > 0.05 else top_color.darkened(0.2), 0.95)
		_part(face, _lathe([Vector2(0.106, 0.13), Vector2(0.108, 0.17), Vector2(0.1, 0.21), Vector2(0.075, 0.245), Vector2(0.0, 0.262)], 24),
			Vector3.ZERO, knit, Vector3(0.95, 1.0, 1.08))
		_part(face, _lathe([Vector2(0.11, 0.125), Vector2(0.112, 0.15)], 24), Vector3.ZERO, knit, Vector3(0.96, 1.0, 1.09))
		if hair_style == "Bald":
			return
	if hair_style == "Bald":
		# A little hair around the back and the sides.
		_part(face, _lathe([Vector2(0.095, 0.09), Vector2(0.1, 0.13), Vector2(0.097, 0.155)], 24), Vector3(0, 0, -0.008), hair, Vector3(0.93, 1.0, 1.02))
		return
	if hat != "Beanie":
		# A cap of hair following the head, a little fuller at the top and back.
		_part(face, _lathe([Vector2(0.097, 0.125), Vector2(0.104, 0.155), Vector2(0.1, 0.19), Vector2(0.085, 0.222),
			Vector2(0.055, 0.245), Vector2(0.0, 0.258)], 28), Vector3(0, 0, -0.006), hair, Vector3(0.95, 1.0, 1.08))
		# Fringe.
		_part(face, _sphere(0.06), Vector3(0.012, 0.19, 0.06), hair, Vector3(1.25, 0.42, 0.7), Vector3(0, 0, -8))
	# Back of the head.
	_part(face, _sphere(0.098), Vector3(0, 0.13, -0.022), hair, Vector3(0.95, 1.0, 0.92))
	match hair_style:
		"Long":
			_part(face, _lathe([Vector2(0.098, 0.15), Vector2(0.104, 0.06), Vector2(0.1, -0.05), Vector2(0.085, -0.18), Vector2(0.05, -0.21)], 24),
				Vector3(0, 0, -0.03), hair, Vector3(1.05, 1.0, 0.62))
		"Bun":
			_part(face, _sphere(0.05), Vector3(0, 0.205, -0.085), hair)
		"Ponytail":
			_part(face, _sphere(0.038), Vector3(0, 0.155, -0.105), hair)
			_part(face, _lathe([Vector2(0.032, 0.0), Vector2(0.036, -0.1), Vector2(0.02, -0.22), Vector2(0.0, -0.24)], 14),
				Vector3(0, 0.15, -0.125), hair, Vector3.ONE, Vector3(-14, 0, 0))


func _joint(joint_name: String, parent: Node3D, position_: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = joint_name.to_pascal_case()
	joint.position = position_
	parent.add_child(joint)
	_joints[joint_name] = joint
	return joint


func _part(parent: Node3D, mesh: Mesh, position_: Vector3, material: Material, scale_: Vector3 = Vector3.ONE, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = position_
	part.scale = scale_
	part.rotation_degrees = rotation_deg
	parent.add_child(part)
	return part


## Skin: soft, with a little warm light at the edges (like light through skin).
static func _skin_material(color: Color) -> StandardMaterial3D:
	var material := _material(color, 0.55)
	material.rim_enabled = true
	material.rim = 0.25
	material.rim_tint = 0.6
	return material


## A smooth turned shape: [param profile] is (radius, height) points from bottom to
## top; the ends are closed. Shared between characters (cached by profile).
static var _lathe_cache := {}


static func _lathe(profile: Array, segments: int = 22) -> ArrayMesh:
	var key := str(profile) + str(segments)
	if _lathe_cache.has(key):
		return _lathe_cache[key]
	var points: Array = profile.duplicate()
	var first: Vector2 = points[0]
	var last: Vector2 = points[points.size() - 1]
	if first.x > 0.001:
		points.push_front(Vector2(0.0, first.y))
	if last.x > 0.001:
		points.push_back(Vector2(0.0, last.y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		for k in segments:
			var t0 := TAU * float(k) / float(segments)
			var t1 := TAU * float(k + 1) / float(segments)
			var a0 := Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x)
			var a1 := Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x)
			var b0 := Vector3(cos(t0) * b.x, b.y, sin(t0) * b.x)
			var b1 := Vector3(cos(t1) * b.x, b.y, sin(t1) * b.x)
			# Clockwise seen from outside (Godot's front faces).
			st.add_vertex(a0)
			st.add_vertex(b1)
			st.add_vertex(b0)
			st.add_vertex(a0)
			st.add_vertex(a1)
			st.add_vertex(b1)
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	_lathe_cache[key] = mesh
	return mesh


static func _material(color: Color, roughness: float = 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


static func _capsule(radius: float, total_height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(total_height, radius * 2.0)
	mesh.radial_segments = 16
	mesh.rings = 6
	return mesh


static func _sphere(radius: float, hemisphere: bool = false) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * (1.0 if hemisphere else 2.0)
	mesh.is_hemisphere = hemisphere
	mesh.radial_segments = 20
	mesh.rings = 10
	return mesh


static func _cylinder(top_radius: float, bottom_radius: float, length: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = length
	mesh.radial_segments = 16
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

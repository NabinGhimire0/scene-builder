class_name PoseTool
extends Node3D
## Pose characters directly in the 3D view.
##
## When it's on and a character is selected, every pose joint shows as a dot
## with lines along the limbs (editor-only, never in the film). Press on a dot
## and drag: the limb turns to point at the mouse. Hold Shift while dragging to
## twist the joint around its own axis instead. Each drag sets a pose key at the
## playhead, exactly like the Pose sliders in the Inspector (which stay in sync).
##
## Mouse input is fed in by the viewport area, in SubViewport pixel coordinates.

signal active_changed(on: bool)
signal joint_picked(joint: String)
## Emitted while dragging and when a drag ends, so the Inspector sliders follow.
signal pose_changed

const PICK_RADIUS_PX := 16.0
const TWIST_DEGREES_PER_PX := 0.6
const CENTRE_JOINTS: PackedStringArray = ["Head", "Neck", "Chest", "Spine", "Hips"]

@export var camera: Camera3D
@export var selection: SelectionManager
@export var timeline: TimelineController

var active := false
## The joint the Inspector's Pose section edits; a click on a dot changes it.
var joint := "Right shoulder"

var _dots: Dictionary = {}   # joint -> MeshInstance3D
var _lines: MeshInstance3D
var _line_mesh: ImmediateMesh
var _materials: Dictionary = {}   # "left" / "right" / "centre" / "picked" / "hover" / "line" -> material
var _hover := ""
var _dragging := false
var _drag_joint := ""
var _drag_character: CharacterBase = null
var _drag_state: Dictionary = {}
var _drag_press := Vector2.ZERO
var _drag_origin := Vector3.ZERO
var _drag_tip := Vector3.ZERO
var _drag_plane := Plane()
var _drag_euler := Vector3.ZERO
var _drag_moved := false


func _ready() -> void:
	for key in ["left", "right", "centre", "picked", "hover"]:
		var color: Color = {"left": Color(0.35, 0.7, 1.0), "right": Color(1.0, 0.55, 0.25), "centre": Color(1.0, 0.85, 0.3),
			"picked": Color(1, 1, 1), "hover": Color(0.6, 1.0, 0.6)}[key]
		_materials[key] = _material(color)
	_materials["line"] = _material(Color(1, 1, 1, 0.55))
	var sphere := SphereMesh.new()
	sphere.radius = 0.028
	sphere.height = 0.056
	sphere.radial_segments = 16
	sphere.rings = 8
	for name_ in CharacterBase.POSE_JOINTS:
		var dot := MeshInstance3D.new()
		dot.mesh = sphere
		dot.layers = Layers.EDITOR_ONLY_VISUAL
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.visible = false
		add_child(dot)
		_dots[name_] = dot
	_line_mesh = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.mesh = _line_mesh
	_lines.layers = Layers.EDITOR_ONLY_VISUAL
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lines.material_override = _materials["line"]
	add_child(_lines)
	EventBus.selection_changed.connect(func(_node: Variant) -> void: _cancel_drag())


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.no_depth_test = true
	m.render_priority = 10
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	if not on:
		_cancel_drag()
	_update_visuals()
	active_changed.emit(active)
	if on and character() == null:
		EventBus.info("Pose mode: select a character, then drag the dots on its joints (Shift-drag twists).")


func toggle() -> void:
	set_active(not active)


func set_joint(joint_name: String) -> void:
	if CharacterBase.POSE_JOINTS.has(joint_name):
		joint = joint_name
		_update_visuals()


## The selected character, if posing applies to it right now.
func character() -> CharacterBase:
	if selection == null or not selection.has_selection():
		return null
	return selection.selected as CharacterBase


func is_dragging() -> bool:
	return _dragging


func _process(_delta: float) -> void:
	_update_visuals()


func _update_visuals() -> void:
	var c := character() if active else null
	var show := c != null and is_inside_tree() and not (timeline and timeline.is_playing())
	_line_mesh.clear_surfaces()
	for name_ in _dots:
		(_dots[name_] as MeshInstance3D).visible = false
	if not show:
		return
	var size := clampf(c.size_factor(), 0.4, 2.5)
	var drawn := false
	for name_ in CharacterBase.POSE_JOINTS:
		var at := c.joint_position(name_)
		if not at.is_finite():
			continue
		var dot: MeshInstance3D = _dots[name_]
		dot.global_position = at
		var picked: bool = name_ == (_drag_joint if _dragging else joint)
		var scale_ := size * (1.45 if picked else (1.2 if name_ == _hover else 1.0))
		dot.scale = Vector3.ONE * scale_
		dot.material_override = _materials["picked" if picked else ("hover" if name_ == _hover else _side(name_))]
		dot.visible = true
		var tip := c.joint_tip(name_)
		if tip.is_finite():
			if not drawn:
				_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
				drawn = true
			_line_mesh.surface_add_vertex(at)
			_line_mesh.surface_add_vertex(tip)
	if drawn:
		_line_mesh.surface_end()


static func _side(joint_name: String) -> String:
	if joint_name.begins_with("Left"):
		return "left"
	if joint_name.begins_with("Right"):
		return "right"
	return "centre"


## The joint dot nearest to [param screen_pos] (within the pick radius), or "".
func joint_at(screen_pos: Vector2) -> String:
	var c := character() if active else null
	if c == null or camera == null:
		return ""
	var best := ""
	var best_distance := PICK_RADIUS_PX
	var best_depth := INF
	for name_ in CharacterBase.POSE_JOINTS:
		var at := c.joint_position(name_)
		if not at.is_finite() or camera.is_position_behind(at):
			continue
		var distance := camera.unproject_position(at).distance_to(screen_pos)
		var depth := camera.global_position.distance_to(at)
		# Prefer the closest dot on screen; on a near tie, the one nearer the camera.
		if distance < best_distance - 2.0 or (absf(distance - best_distance) <= 2.0 and depth < best_depth):
			best = name_
			best_distance = distance
			best_depth = depth
	return best


# --- Mouse (from ViewportArea) ---------------------------------------------------

## Returns true if the press landed on a joint dot (the tool takes the drag).
func pointer_pressed(screen_pos: Vector2) -> bool:
	var hit := joint_at(screen_pos)
	if hit.is_empty():
		return false
	var c := character()
	joint = hit
	joint_picked.emit(hit)
	var keyed: Dictionary = timeline.pose_at(c, timeline.current_time)
	var manual: Vector3 = keyed.get(hit, Vector3.ZERO)
	for key in keyed:
		if CharacterBase.SCRIPT_JOINTS.get(key, "") == hit:
			manual = keyed[key]
	_drag_state = c.pose_drag_begin(hit, manual)
	if _drag_state.is_empty():
		return true
	_dragging = true
	_drag_character = c
	_drag_joint = hit
	_drag_press = screen_pos
	_drag_origin = c.joint_position(hit)
	_drag_tip = c.joint_tip(hit)
	_drag_euler = manual
	_drag_moved = false
	# The tip follows the mouse on a plane facing the camera, through the tip.
	_drag_plane = Plane(-camera.global_basis.z, _drag_tip)
	if timeline.is_playing():
		timeline.pause()
	return true


func pointer_moved(screen_pos: Vector2, twist: bool) -> void:
	if not _dragging:
		_hover = joint_at(screen_pos)
		return
	var c := _drag_character
	if c == null or not is_instance_valid(c):
		_cancel_drag()
		return
	var turn := Quaternion.IDENTITY
	var along := _drag_tip - _drag_origin
	if along.length() < 0.001:
		return
	if twist:
		var angle := deg_to_rad((screen_pos.x - _drag_press.x) * TWIST_DEGREES_PER_PX)
		turn = Quaternion(along.normalized(), angle)
	else:
		var hit: Variant = _drag_plane.intersects_ray(camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos))
		if hit == null:
			return
		var wanted: Vector3 = (hit as Vector3) - _drag_origin
		if wanted.length() < 0.01:
			return
		var from := along.normalized()
		var to := wanted.normalized()
		if from.dot(to) < -0.9999:
			return
		turn = Quaternion(from, to)
	_drag_euler = c.pose_drag_euler(_drag_state, turn)
	_drag_moved = true
	# Show it straight away; the pose key is written once, when the drag ends
	# (writing keys rebuilds the timeline, which is slow in long films).
	c.pose_preview = {_drag_joint: _drag_euler}
	timeline.refresh_character(c)
	pose_changed.emit()


func pointer_released(_screen_pos: Vector2) -> void:
	var c := _drag_character if _dragging else null
	if c and is_instance_valid(c):
		c.pose_preview = {}
		if _dragging and _drag_moved:
			timeline.set_pose_joint(c, _drag_joint, _drag_euler.snapped(Vector3.ONE * 0.1))
		timeline.refresh_character(c)
	_dragging = false
	_drag_character = null
	_drag_state = {}
	pose_changed.emit()


## The joint's angles while it's being dragged (for the Inspector sliders).
func dragged_angles() -> Dictionary:
	return {_drag_joint: _drag_euler} if _dragging and _drag_moved else {}


func _cancel_drag() -> void:
	var c := _drag_character
	if c and is_instance_valid(c) and not c.pose_preview.is_empty():
		c.pose_preview = {}
		timeline.refresh_character(c)
	_drag_character = null
	_dragging = false
	_drag_state = {}
	_hover = ""

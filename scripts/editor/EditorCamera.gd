class_name EditorCamera
extends Camera3D
## Smooth orbit / pan / zoom navigation camera.
##
## Mouse: right-drag orbit · middle-drag pan · wheel zoom (trackpad pinch/scroll too).
## Keyboard (while the cursor is over the 3D view): W/A/S/D move, Q/E down/up,
## Shift = faster.
##
## Input arrives via [method handle_input] from the viewport area, so clicks on UI
## panels never reach the camera. All motion changes "goal" values; the visible
## camera eases toward them each frame when [member smooth_enabled] is on.

signal moved

@export var target := Vector3.ZERO
@export_range(0.5, 500.0) var distance := 18.0
@export var yaw_deg := 35.0
@export_range(-89.0, 89.0) var pitch_deg := -32.0

@export_group("Limits")
@export var min_distance := 0.75
@export var max_distance := 300.0
@export_range(-89.0, 0.0) var min_pitch_deg := -89.0
@export_range(0.0, 89.0) var max_pitch_deg := 89.0

@export_group("Feel")
## Master multiplier for orbit, pan, zoom and keyboard movement.
@export_range(0.1, 5.0, 0.05) var speed := 1.0
@export var orbit_sensitivity := 0.25
@export var zoom_factor := 1.15
@export var keyboard_speed := 9.0
@export var smooth_enabled := true
## Higher = snappier. Only used when smooth_enabled.
@export_range(1.0, 40.0) var smoothing := 14.0

## Set by the viewport while the cursor is over the 3D view.
var keyboard_enabled := false

var _cur_target := Vector3.ZERO
var _cur_distance := 18.0
var _cur_yaw := 35.0
var _cur_pitch := -32.0
var _orbiting := false
var _panning := false


func _ready() -> void:
	_snap_to_goal()
	_apply(true)


func _process(delta: float) -> void:
	_keyboard_move(delta)
	if smooth_enabled:
		var w := 1.0 - exp(-smoothing * delta)
		_cur_target = _cur_target.lerp(target, w)
		_cur_distance = lerpf(_cur_distance, distance, w)
		_cur_yaw = lerpf(_cur_yaw, yaw_deg, w)
		_cur_pitch = lerpf(_cur_pitch, pitch_deg, w)
	else:
		_snap_to_goal()
	_apply(false)


## Returns true when the event was used for navigation.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				_orbiting = mb.pressed
				return true
			MOUSE_BUTTON_MIDDLE:
				_panning = mb.pressed
				return true
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					var steps := mb.factor if mb.factor > 0.0 else 1.0  # trackpads send fractions
					var direction := -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
					zoom(pow(zoom_factor, direction * steps * speed))
				return true
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _orbiting:
			orbit(motion.relative)
			return true
		if _panning:
			pan(motion.relative)
			return true
	elif event is InputEventMagnifyGesture:
		zoom(1.0 / maxf((event as InputEventMagnifyGesture).factor, 0.01))
		return true
	elif event is InputEventPanGesture:
		zoom(pow(zoom_factor, (event as InputEventPanGesture).delta.y * speed))
		return true
	return false


## Stops any drag in progress (e.g. when the mouse button is released elsewhere).
func release_drags() -> void:
	_orbiting = false
	_panning = false


func is_dragging() -> bool:
	return _orbiting or _panning


func orbit(pixels: Vector2) -> void:
	yaw_deg -= pixels.x * orbit_sensitivity * speed
	pitch_deg = clampf(pitch_deg - pixels.y * orbit_sensitivity * speed, min_pitch_deg, max_pitch_deg)


func pan(pixels: Vector2) -> void:
	var view_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var world_per_pixel := 2.0 * _cur_distance * tan(deg_to_rad(fov * 0.5)) / view_height
	var b := global_transform.basis
	target += (-b.x * pixels.x + b.y * pixels.y) * world_per_pixel * speed


func zoom(factor: float) -> void:
	distance = clampf(distance * factor, min_distance, max_distance)


## Re-centres on [param point] keeping the current angle and distance.
func focus_on(point: Vector3) -> void:
	target = point


## Re-centres and backs off so [param box] fills the view nicely.
func frame_aabb(box: AABB) -> void:
	target = box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.25)
	distance = clampf(radius / sin(deg_to_rad(fov * 0.5)) * 1.25, min_distance, max_distance)


func get_state() -> Dictionary:
	return {
		"target": [target.x, target.y, target.z],
		"distance": distance, "yaw_deg": yaw_deg, "pitch_deg": pitch_deg,
	}


func set_state(state: Dictionary, instant: bool = true) -> void:
	var t: Variant = state.get("target")
	if t is Array and t.size() >= 3:
		target = Vector3(float(t[0]), float(t[1]), float(t[2]))
	distance = clampf(float(state.get("distance", distance)), min_distance, max_distance)
	yaw_deg = float(state.get("yaw_deg", yaw_deg))
	pitch_deg = clampf(float(state.get("pitch_deg", pitch_deg)), min_pitch_deg, max_pitch_deg)
	if instant:
		_snap_to_goal()
		_apply(true)


func _keyboard_move(delta: float) -> void:
	if not keyboard_enabled:
		return
	var focus := get_tree().root.gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META) or Input.is_key_pressed(KEY_ALT):
		return
	var input := Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if input == Vector3.ZERO:
		return
	var heading := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var move := heading * Vector3(input.x, 0.0, input.z)
	move.y = input.y
	var boost := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var scale_by_zoom := clampf(distance / 18.0, 0.25, 6.0)
	target += move.normalized() * keyboard_speed * speed * boost * scale_by_zoom * delta


func _snap_to_goal() -> void:
	_cur_target = target
	_cur_distance = distance
	_cur_yaw = yaw_deg
	_cur_pitch = pitch_deg


func _apply(force: bool) -> void:
	var rot := Basis.from_euler(Vector3(deg_to_rad(_cur_pitch), deg_to_rad(_cur_yaw), 0.0))
	var xform := Transform3D(rot, _cur_target + rot.z * _cur_distance)
	if force or not xform.is_equal_approx(global_transform):
		global_transform = xform
		moved.emit()

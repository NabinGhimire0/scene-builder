class_name PlacementController
extends Node3D
## Raycast-driven prop placement.
##
## Shows a see-through "ghost" of the chosen prop under the cursor, resting it on
## whatever surface the ray hits (ground or other props), optionally snapped to a
## grid. Left-click (or a drop from the asset library) places the real prop
## through [EditorHistory], so every placement is undoable.
##
## Two ways in:
##  • Click mode – [method begin_placement], then click repeatedly; Esc finishes.
##  • Drag mode  – [method preview_drag] / [method drop_prop] from the viewport
##                 drop zone; one prop per drop (hold Shift on drop to keep placing).
##
## Screen positions are in the 3D SubViewport's pixel space.

enum Mode { IDLE, PLACING }

const VALID_TINT := Color(0.35, 1.0, 0.55, 0.28)
const INVALID_TINT := Color(1.0, 0.3, 0.3, 0.35)

@export var camera: Camera3D
@export var placed_props_root: Node3D
@export var preview_root: Node3D
@export var history: EditorHistory

@export_group("Snapping")
@export var grid_snap_enabled := true
@export_range(0.05, 10.0, 0.05) var grid_step := 1.0
@export_range(1.0, 180.0, 1.0) var rotation_step_deg := 45.0
## Tilt props to match the surface normal (off = always upright).
@export var align_to_surface := false
## Steeper surfaces are rejected (ghost turns red) unless aligning to surface.
@export_range(0.0, 90.0, 1.0) var max_surface_slope_deg := 50.0
@export var ray_length := 2000.0

var mode: Mode = Mode.IDLE

var _active_prop: Dictionary = {}
var _ghost: Node3D
var _ghost_base_basis := Basis.IDENTITY
var _ghost_bottom := 0.0
var _ghost_tint: StandardMaterial3D
var _yaw_deg := 0.0
var _pointer := Vector2.ZERO
var _pointer_inside := false
var _target_valid := false
var _target_transform := Transform3D.IDENTITY
var _drag_session := false


func _ready() -> void:
	_ghost_tint = StandardMaterial3D.new()
	_ghost_tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_tint.albedo_color = VALID_TINT
	if camera == null or placed_props_root == null or preview_root == null or history == null:
		push_error("PlacementController: camera, placed_props_root, preview_root and history must all be assigned.")


# --- Public API --------------------------------------------------------------

func is_placing() -> bool:
	return mode == Mode.PLACING


func active_prop() -> Dictionary:
	return _active_prop


func has_valid_target() -> bool:
	return _target_valid


func get_placed_count() -> int:
	return placed_props_root.get_child_count() if placed_props_root else 0


## Enters placement mode for [param prop] (a PropCatalog descriptor).
func begin_placement(prop: Dictionary) -> bool:
	var path := str(prop.get("scene_path", ""))
	var display := str(prop.get("display_name", path.get_file()))
	if preview_root == null:
		return false
	var scene := PropUtils.load_prop_scene(path)
	if scene == null:
		EventBus.error("Couldn't load \"%s\": the file is missing or isn't a valid scene (%s)." % [display, path])
		return false
	var ghost := PropUtils.instantiate_as_node3d(scene)
	if ghost == null:
		EventBus.error("\"%s\" can't be instantiated." % display)
		return false

	_clear_ghost()
	_ghost_base_basis = ghost.transform.basis
	_ghost_bottom = PropUtils.bottom_offset(ghost, _ghost_base_basis)
	PropUtils.make_ghost(ghost, _ghost_tint)
	ghost.visible = false
	preview_root.add_child(ghost)
	_ghost = ghost

	_active_prop = prop.duplicate()
	mode = Mode.PLACING
	EventBus.placement_started.emit(_active_prop)
	_update_target()
	return true


func cancel_placement() -> void:
	if mode == Mode.IDLE:
		return
	_clear_ghost()
	_active_prop = {}
	_target_valid = false
	_drag_session = false
	mode = Mode.IDLE
	EventBus.placement_ended.emit()


## Feed the cursor position and whether it is over the 3D view.
func update_pointer(screen_pos: Vector2, inside: bool) -> void:
	_pointer = screen_pos
	_pointer_inside = inside
	_update_target()


func set_pointer_inside(inside: bool) -> void:
	_pointer_inside = inside
	_update_target()


## Re-evaluates the ghost (e.g. after the camera moved without the mouse moving).
func refresh_preview() -> void:
	if mode == Mode.PLACING:
		_update_target()


## Places the active prop at the current target. Returns the new node or null.
func place_current(select_it: bool = false) -> Node3D:
	if mode != Mode.PLACING:
		return null
	_update_target()
	if not _target_valid:
		if _ghost != null and _ghost.visible:
			EventBus.info("Can't place here: that surface is too steep.")
		return null

	var path := str(_active_prop.get("scene_path", ""))
	var prop_node := PropUtils.create_prop(path, str(_active_prop.get("prop_id", "")))
	if prop_node == null:
		EventBus.error("Couldn't create \"%s\" (%s)." % [_active_prop.get("display_name", "?"), path])
		cancel_placement()
		return null

	prop_node.transform = _target_transform  # PlacedProps sits at the origin
	history.add_prop(prop_node, "Place %s" % _active_prop.get("display_name", prop_node.name))
	EventBus.prop_placed.emit(prop_node, select_it)
	var p := _target_transform.origin
	EventBus.info("Placed %s at (%.2f, %.2f, %.2f)." % [_active_prop.get("display_name", prop_node.name), p.x, p.y, p.z])
	return prop_node


func rotate_step(direction: int) -> void:
	_yaw_deg = wrapf(_yaw_deg + rotation_step_deg * direction, 0.0, 360.0)
	_update_target()
	EventBus.info("Rotation: %d°" % roundi(_yaw_deg))


func set_grid_snap(enabled: bool, step: float) -> void:
	grid_snap_enabled = enabled
	grid_step = maxf(step, 0.01)
	_update_target()
	EventBus.grid_snap_changed.emit(grid_snap_enabled, grid_step)


# --- Drag & drop (called by the viewport drop zone) ---------------------------

func preview_drag(prop: Dictionary, screen_pos: Vector2) -> bool:
	var same_prop: bool = _active_prop.get("scene_path", "") == prop.get("scene_path", "")
	if not (_drag_session and same_prop and is_placing()):
		if not begin_placement(prop):
			return false
		_drag_session = true
	update_pointer(screen_pos, true)
	return _target_valid


func drop_prop(prop: Dictionary, screen_pos: Vector2) -> Node3D:
	preview_drag(prop, screen_pos)
	var keep_placing := Input.is_key_pressed(KEY_SHIFT)
	var placed := place_current(not keep_placing)
	if _drag_session:
		_drag_session = false
		if not keep_placing:
			cancel_placement()
	return placed


## Called when a drag ends anywhere (including outside the 3D view).
func end_drag_session() -> void:
	if _drag_session:
		_drag_session = false
		cancel_placement()


# --- Raycasting (also used by selection) ----------------------------------------

## Ray from the camera through [param screen_pos]. Returns the physics hit or {}.
func raycast(screen_pos: Vector2, mask: int = Layers.PLACEMENT_MASK, exclude: Array[RID] = []) -> Dictionary:
	if camera == null or not camera.is_inside_tree():
		return {}
	var origin := camera.project_ray_origin(screen_pos)
	return intersect(origin, origin + camera.project_ray_normal(screen_pos) * ray_length, exclude, mask)


func intersect(from: Vector3, to: Vector3, exclude: Array[RID] = [], mask: int = Layers.PLACEMENT_MASK) -> Dictionary:
	var world: World3D = camera.get_world_3d() if camera else get_world_3d()
	if world == null:
		return {}
	var space := world.direct_space_state
	if space == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	query.collide_with_areas = false
	return space.intersect_ray(query)


## Surface under [param screen_pos] as { position, normal }, grid-snapped when
## enabled, or {} if there is none. Falls back to the y=0 plane past the ground.
func find_surface(screen_pos: Vector2, exclude: Array[RID] = []) -> Dictionary:
	if camera == null or not camera.is_inside_tree():
		return {}
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var result := {}
	var hit := intersect(origin, origin + direction * ray_length, exclude)
	if hit.is_empty():
		var on_plane: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
		if on_plane == null:
			return {}
		result = {"position": on_plane, "normal": Vector3.UP}
	else:
		result = {"position": hit["position"], "normal": hit["normal"]}

	if grid_snap_enabled and grid_step > 0.0:
		var raw: Vector3 = result["position"]
		var snapped_pos := Vector3(snappedf(raw.x, grid_step), raw.y, snappedf(raw.z, grid_step))
		# Re-probe straight down at the snapped spot so stacking stays correct
		# when snapping moves us on/off the top of another prop.
		var top := Vector3(snapped_pos.x, raw.y + 0.5, snapped_pos.z)
		var down := intersect(top, top + Vector3.DOWN * ray_length, exclude)
		if down.is_empty():
			result["position"] = snapped_pos
		else:
			result["position"] = down["position"]
			result["normal"] = down["normal"]
	return result


# --- Input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_placing():
		return
	if key.ctrl_pressed or key.meta_pressed:
		return
	match key.keycode:
		KEY_R:
			rotate_step(-1 if key.shift_pressed else 1)
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			cancel_placement()
			EventBus.info("Placement cancelled.")
			get_viewport().set_input_as_handled()


# --- Internals ----------------------------------------------------------------

func _update_target() -> void:
	_target_valid = false
	if _ghost == null:
		return
	if not _pointer_inside:
		_ghost.visible = false
		return
	var surface := find_surface(_pointer)
	if surface.is_empty():
		_ghost.visible = false
		return

	var pos: Vector3 = surface["position"]
	var normal: Vector3 = surface["normal"]
	var target_basis := Basis(Vector3.UP, deg_to_rad(_yaw_deg)) * _ghost_base_basis
	if align_to_surface:
		var axis := Vector3.UP.cross(normal)
		if axis.length_squared() > 1e-6:
			target_basis = Basis(axis.normalized(), Vector3.UP.angle_to(normal)) * target_basis
		pos += normal * _ghost_bottom
	else:
		pos.y += _ghost_bottom

	var slope_ok := align_to_surface or Vector3.UP.angle_to(normal) <= deg_to_rad(max_surface_slope_deg)
	_target_transform = Transform3D(target_basis, pos)
	_ghost.global_transform = _target_transform
	_ghost.visible = true
	_target_valid = slope_ok
	_ghost_tint.albedo_color = VALID_TINT if slope_ok else INVALID_TINT


func _clear_ghost() -> void:
	if is_instance_valid(_ghost):
		if _ghost.get_parent():
			_ghost.get_parent().remove_child(_ghost)
		_ghost.queue_free()
	_ghost = null

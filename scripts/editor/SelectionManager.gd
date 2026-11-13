class_name SelectionManager
extends Node3D
## Click-to-select, drag-to-move, and object commands (delete, duplicate,
## focus, drop to ground) for placed props and virtual cameras.
##
## Mouse input is fed in by the viewport area (on_press / on_motion / on_release),
## using SubViewport pixel coordinates.

const DRAG_THRESHOLD_PX := 5.0

@export var camera: Camera3D
@export var placed_props_root: Node3D
@export var history: EditorHistory
@export var placement: PlacementController
@export var cameras_root: Node3D
@export var director: CinematicDirector

var selected: Node3D = null

var _highlight: SelectionHighlight
var _press_pos := Vector2.ZERO
var _press_on_selected := false
var _dragging := false
var _drag_start := Transform3D.IDENTITY
var _drag_bottom := 0.0
var _drag_exclude: Array[RID] = []


func _ready() -> void:
	_highlight = SelectionHighlight.new()
	_highlight.name = "SelectionHighlight"
	add_child(_highlight)
	EventBus.prop_placed.connect(_on_prop_placed)
	EventBus.history_changed.connect(_on_history_changed)
	EventBus.render_mode_changed.connect(func(rendering: bool) -> void: _update_suppression(rendering))
	if director:
		director.view_mode_changed.connect(func(_mode: int) -> void: _update_suppression(false))


func _update_suppression(rendering: bool) -> void:
	var camera_view := director != null and director.view_mode == CinematicDirector.ViewMode.CAMERA
	_highlight.set_suppressed(rendering or camera_view)


# --- Selection ----------------------------------------------------------------

func select(node: Node3D) -> void:
	if node != null and (not is_instance_valid(node) or not node.is_inside_tree()):
		node = null
	if node == selected:
		return
	if is_instance_valid(selected) and selected.tree_exiting.is_connected(_on_selected_exiting):
		selected.tree_exiting.disconnect(_on_selected_exiting)
	selected = node
	if selected != null:
		selected.tree_exiting.connect(_on_selected_exiting)
	_highlight.set_target(selected)
	EventBus.selection_changed.emit(selected)


func clear_selection() -> void:
	select(null)


func has_selection() -> bool:
	return is_instance_valid(selected) and selected.is_inside_tree()


## Returns the placed prop under [param screen_pos], or null.
func pick(screen_pos: Vector2) -> Node3D:
	if placement == null:
		return null
	var hit := placement.raycast(screen_pos, Layers.SELECTABLE)
	if hit.is_empty():
		return null
	var collider: Node = hit["collider"]
	var root := PropUtils.find_prop_root(collider, placed_props_root)
	if PropUtils.is_prop(root):
		return root
	if cameras_root:
		var cam := PropUtils.find_prop_root(collider, cameras_root)
		if cam is CinematicCamera:
			return cam
	return null


func selected_camera() -> CinematicCamera:
	return selected as CinematicCamera if has_selection() else null


# --- Mouse interaction (from ViewportArea) -------------------------------------

func on_press(screen_pos: Vector2) -> void:
	_press_pos = screen_pos
	var node := pick(screen_pos)
	select(node)
	_press_on_selected = node != null
	_dragging = false


func on_motion(screen_pos: Vector2) -> void:
	if not _press_on_selected or not has_selection():
		return
	if not _dragging:
		if screen_pos.distance_to(_press_pos) < DRAG_THRESHOLD_PX:
			return
		_begin_drag()
	_update_drag(screen_pos)


func on_release(_screen_pos: Vector2) -> void:
	if _dragging:
		_end_drag()
	_press_on_selected = false


func is_dragging() -> bool:
	return _dragging


func _begin_drag() -> void:
	_dragging = true
	_drag_start = selected.transform
	_drag_bottom = PropUtils.bottom_offset(selected, selected.transform.basis)
	_drag_exclude = PropUtils.collision_rids(selected)


func _update_drag(screen_pos: Vector2) -> void:
	if selected is CinematicCamera:
		# Cameras float: slide them on a horizontal plane at their own height.
		var origin := camera.project_ray_origin(screen_pos)
		var hit_point: Variant = Plane(Vector3.UP, _drag_start.origin.y).intersects_ray(
			origin, camera.project_ray_normal(screen_pos))
		if hit_point != null:
			var p: Vector3 = hit_point
			if placement.grid_snap_enabled and placement.grid_step > 0.0:
				p.x = snappedf(p.x, placement.grid_step)
				p.z = snappedf(p.z, placement.grid_step)
			selected.position = p
			EventBus.transform_edited.emit(selected)
		return
	var surface := placement.find_surface(screen_pos, _drag_exclude)
	if surface.is_empty():
		return
	var pos: Vector3 = surface["position"]
	pos.y += _drag_bottom
	selected.position = pos
	EventBus.transform_edited.emit(selected)


func _end_drag() -> void:
	_dragging = false
	if has_selection():
		history.set_transform(selected, _drag_start, selected.transform, "Move")


func _cancel_drag() -> void:
	if _dragging and has_selection():
		selected.transform = _drag_start
		EventBus.transform_edited.emit(selected)
	_dragging = false
	_press_on_selected = false


# --- Commands -----------------------------------------------------------------

func delete_selected() -> void:
	if not has_selection():
		return
	var nodes: Array[Node3D] = [selected]
	history.remove_props(nodes)


func duplicate_selected() -> void:
	if not has_selection():
		return
	if selected is CinematicCamera:
		if director:
			select(director.duplicate_camera(selected as CinematicCamera))
		return
	var path := str(selected.get_meta(PropUtils.META_SCENE_PATH, ""))
	var copy := PropUtils.create_prop(path, str(selected.get_meta(PropUtils.META_PROP_ID, "")))
	if copy == null:
		EventBus.error("Couldn't duplicate %s: its asset is missing (%s)." % [selected.name, path])
		return
	# Place the copy just beside the original (whole grid steps when snapping).
	var offset := maxf(PropUtils.world_aabb(selected).size.x, 0.5) + 0.25
	if placement and placement.grid_snap_enabled and placement.grid_step > 0.0:
		offset = ceilf(offset / placement.grid_step) * placement.grid_step
	var xform := selected.transform
	xform.origin += Vector3(offset, 0.0, 0.0)
	copy.transform = xform
	if selected.has_method(&"get_custom_state") and copy.has_method(&"set_custom_state"):
		copy.call(&"set_custom_state", selected.call(&"get_custom_state"))
	history.add_prop(copy, "Duplicate %s" % selected.name)
	select(copy)


func focus_selected() -> void:
	if not has_selection() or camera == null:
		return
	if camera is EditorCamera:
		(camera as EditorCamera).frame_aabb(PropUtils.world_aabb(selected))


## Lowers (or raises) the selected prop so it rests on whatever is below it.
func drop_selected_to_ground() -> void:
	if not has_selection():
		return
	if selected is CinematicCamera:
		EventBus.info("Cameras float freely; use Position Y in the Inspector to set their height.")
		return
	var bottom := PropUtils.bottom_offset(selected, selected.transform.basis)
	var base := selected.position - Vector3(0.0, bottom, 0.0)
	var from := base + Vector3.UP * 0.05
	var hit := placement.intersect(from, from + Vector3.DOWN * placement.ray_length, PropUtils.collision_rids(selected))
	var ground_y := 0.0
	if not hit.is_empty():
		ground_y = (hit["position"] as Vector3).y
	var xform := selected.transform
	xform.origin.y = ground_y + bottom
	history.set_transform(selected, selected.transform, xform, "Drop")


func reset_rotation_selected() -> void:
	if has_selection():
		var xform := Transform3D(Basis.from_scale(selected.scale), selected.position)
		history.set_transform(selected, selected.transform, xform, "Reset Rotation")


func reset_scale_selected() -> void:
	if has_selection():
		var xform := Transform3D(Basis.from_euler(selected.rotation), selected.position)
		history.set_transform(selected, selected.transform, xform, "Reset Scale")


# --- Input & events -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var ctrl := key.ctrl_pressed or key.meta_pressed
	match key.keycode:
		KEY_ESCAPE:
			if _dragging:
				_cancel_drag()
				_accept()
			elif has_selection() and not (placement and placement.is_placing()):
				clear_selection()
				_accept()
		KEY_DELETE, KEY_BACKSPACE:
			if has_selection():
				delete_selected()
				_accept()
		KEY_D:
			if ctrl and has_selection():
				duplicate_selected()
				_accept()
		KEY_F:
			if not ctrl and has_selection():
				focus_selected()
				_accept()
		KEY_END:
			if has_selection():
				drop_selected_to_ground()
				_accept()


func _accept() -> void:
	get_viewport().set_input_as_handled()


func _on_prop_placed(node: Node3D, select_it: bool) -> void:
	if select_it:
		select(node)


func _on_history_changed() -> void:
	# Undo/redo may have moved the selection; keep the highlight in sync.
	if has_selection():
		_highlight.set_target(selected)
	elif selected != null:
		clear_selection()


func _on_selected_exiting() -> void:
	_cancel_drag()
	clear_selection()

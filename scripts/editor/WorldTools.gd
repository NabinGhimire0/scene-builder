class_name WorldTools
extends Node3D
## Brush tools that work by clicking and dragging in the viewport: sculpt and
## paint the terrain, paint and erase plants, and draw a walking path for the
## selected character. Each stroke (or path) is one undo step.

signal tool_changed(tool: String)
signal path_changed(points: int)

const SCULPT := ["Raise", "Lower", "Smooth", "Flatten"]
const CURSOR_COLOR := Color(1.0, 0.85, 0.3, 0.9)
const PATH_COLOR := Color(0.35, 0.85, 1.0, 0.95)

@export var terrain: Terrain
@export var vegetation: Vegetation
@export var placement: PlacementController
@export var selection: SelectionManager
@export var history: EditorHistory
@export var timeline: TimelineController

## "" (off), "Raise", "Lower", "Smooth", "Flatten", "Paint", "Plants", "Erase plants", "Path".
var tool := ""
var brush_size := 6.0
var strength := 0.5
var paint_layer := 1
var plant_kind := "Grass"
var erase_kind := ""
var path_speed := 1.4

var _pressed := false
var _pointer := Vector2.ZERO
var _hit := Vector3.ZERO
var _has_hit := false
var _flatten_height := 0.0
var _before: Dictionary = {}
var _path: Array = []
var _path_target: Node3D
var _cursor: MeshInstance3D
var _cursor_mesh: ImmediateMesh


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.vertex_color_use_as_albedo = true
	material.render_priority = 10
	_cursor_mesh = ImmediateMesh.new()
	_cursor = MeshInstance3D.new()
	_cursor.name = "BrushCursor"
	_cursor.mesh = _cursor_mesh
	_cursor.material_override = material
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.layers = Layers.EDITOR_ONLY_VISUAL
	add_child(_cursor)
	EventBus.selection_changed.connect(_on_selection_changed)


func is_active() -> bool:
	return not tool.is_empty()


func set_tool(new_tool: String) -> void:
	if new_tool == tool:
		return
	if tool == "Path":
		_path.clear()
	if _pressed:
		_finish_stroke()
	tool = new_tool
	if tool == "Path":
		_path_target = selection.selected if selection else null
		if _path_target == null or _path_target is CinematicCamera:
			EventBus.error("Select a character (or any object) first, then draw its path.")
			tool = ""
		else:
			EventBus.info("Click points on the ground for %s's path. Enter = finish, Backspace = undo point, Esc = cancel." % _path_target.name)
	elif tool != "" and placement and placement.is_placing():
		placement.cancel_placement()
	_redraw()
	tool_changed.emit(tool)


func cancel() -> void:
	set_tool("")


# --- Input from the viewport ---------------------------------------------------

func pointer_pressed(pos: Vector2) -> void:
	_pointer = pos
	_update_hit()
	if not _has_hit:
		return
	if tool == "Path":
		_path.append(_hit)
		path_changed.emit(_path.size())
		_redraw()
		return
	_pressed = true
	_flatten_height = _hit.y
	if tool in ["Plants", "Erase plants"]:
		_before = vegetation.snapshot()
	else:
		_before = terrain.snapshot()
		terrain.begin_stroke()
	_apply(1.0 / 30.0)


func pointer_released(_pos: Vector2) -> void:
	if _pressed:
		_finish_stroke()


func pointer_moved(pos: Vector2) -> void:
	_pointer = pos
	_update_hit()
	_redraw()


## Enter finishes a path, Backspace removes the last point.
func handle_key(key: InputEventKey) -> bool:
	if tool != "Path" or not key.pressed:
		return false
	if key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		finish_path()
		return true
	if key.keycode == KEY_BACKSPACE and not _path.is_empty():
		_path.pop_back()
		path_changed.emit(_path.size())
		_redraw()
		return true
	return false


func finish_path() -> void:
	if _path.size() < 2:
		EventBus.info("Click at least two points for a path.")
		return
	if is_instance_valid(_path_target):
		var points := [_path_target.global_position]
		points.append_array(_path)
		timeline.add_path_keys(_path_target, points, path_speed)
	_path.clear()
	set_tool("")


func _process(delta: float) -> void:
	if _pressed:
		_update_hit()
		if _has_hit:
			_apply(delta)
		_redraw()
	elif tool == "Path":
		_redraw()


# --- Internals -----------------------------------------------------------------

func _apply(delta: float) -> void:
	match tool:
		"Raise", "Lower", "Smooth", "Flatten":
			terrain.apply_brush(SCULPT.find(tool), _hit, brush_size, strength, delta, _flatten_height)
		"Paint":
			terrain.apply_brush(Terrain.Tool.PAINT, _hit, brush_size, strength, delta, 0.0, paint_layer)
		"Plants":
			vegetation.paint(plant_kind, _hit, brush_size, strength, delta * 3.0)
		"Erase plants":
			vegetation.erase(erase_kind, _hit, brush_size, strength)


func _finish_stroke() -> void:
	_pressed = false
	if tool in ["Plants", "Erase plants"]:
		var after := vegetation.snapshot()
		history.record_snapshot("%s brush" % tool, vegetation.restore, _before, after)
		EventBus.info("%d plants in the scene." % vegetation.count())
	else:
		terrain.end_stroke()
		history.record_snapshot("Terrain: %s" % tool, _restore_terrain, _before, terrain.snapshot())
	_before = {}


func _restore_terrain(state: Dictionary) -> void:
	terrain.restore(state)
	terrain.end_stroke()
	if vegetation:
		vegetation.resettle(Rect2(-Terrain.HALF, -Terrain.HALF, Terrain.SIZE, Terrain.SIZE))


func _update_hit() -> void:
	var mask := Layers.PLACEMENT_MASK if tool == "Path" else Layers.GROUND
	var exclude: Array[RID] = []
	if tool == "Path" and is_instance_valid(_path_target):
		exclude = PropUtils.collision_rids(_path_target)
	var hit := placement.raycast(_pointer, mask, exclude)
	_has_hit = not hit.is_empty()
	if _has_hit:
		_hit = hit["position"]


func _on_selection_changed(node: Node3D) -> void:
	if tool == "Path" and node != _path_target:
		_path.clear()
		set_tool("")


func _redraw() -> void:
	_cursor_mesh.clear_surfaces()
	if tool.is_empty():
		return
	if tool == "Path":
		_draw_path()
		return
	if not _has_hit:
		return
	_cursor_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var segments := 64
	for i in segments + 1:
		var a := TAU * float(i) / float(segments)
		var p := _hit + Vector3(cos(a), 0, sin(a)) * brush_size
		p.y = (terrain.height_at(p.x, p.z) if terrain and Terrain.contains(p.x, p.z) else 0.0) + 0.08
		_cursor_mesh.surface_set_color(CURSOR_COLOR)
		_cursor_mesh.surface_add_vertex(p)
	_cursor_mesh.surface_end()


func _draw_path() -> void:
	var points: Array = []
	if is_instance_valid(_path_target):
		points.append(_path_target.global_position)
	points.append_array(_path)
	if _has_hit:
		points.append(_hit)
	if points.size() < 2:
		return
	_cursor_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in points:
		_cursor_mesh.surface_set_color(PATH_COLOR)
		_cursor_mesh.surface_add_vertex((p as Vector3) + Vector3(0, 0.1, 0))
	_cursor_mesh.surface_end()
	_cursor_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for p in _path:
		var c: Vector3 = p + Vector3(0, 0.1, 0)
		for axis in [Vector3(0.25, 0, 0), Vector3(0, 0, 0.25), Vector3(0, 0.25, 0)]:
			_cursor_mesh.surface_set_color(PATH_COLOR)
			_cursor_mesh.surface_add_vertex(c - axis)
			_cursor_mesh.surface_set_color(PATH_COLOR)
			_cursor_mesh.surface_add_vertex(c + axis)
	_cursor_mesh.surface_end()

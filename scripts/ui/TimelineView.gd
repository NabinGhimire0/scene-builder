class_name TimelineView
extends Control
## Custom-drawn timeline: time ruler, playhead, and one row per animated thing
## (camera cuts, lighting, cameras, objects) with diamond keyframes.
##
## Mouse: click/drag the ruler or empty space to scrub · click a key to select it
## and jump there · drag a key to retime it · right-click a key to delete it ·
## click a row name to select that object. Delete removes the selected key.

const NAME_WIDTH := 150.0
const RULER_HEIGHT := 22.0
const ROW_HEIGHT := 24.0
const KEY_RADIUS := 6.0
const PAD_RIGHT := 14.0

const BG := Color(0.075, 0.08, 0.094)
const ROW_ALT := Color(1, 1, 1, 0.025)
const ROW_SELECTED := Color(0.29, 0.56, 0.86, 0.12)
const RULER_BG := Color(0.1, 0.106, 0.122)
const TICK := Color(1, 1, 1, 0.18)
const TICK_TEXT := Color(0.6, 0.63, 0.68)
const NAME_TEXT := Color(0.82, 0.84, 0.88)
const PLAYHEAD := Color(1.0, 0.33, 0.3)
const KEY_COLORS := {
	"cuts": Color(0.78, 0.52, 1.0),
	"lighting": Color(1.0, 0.8, 0.3),
	"camera": Color(1.0, 0.45, 0.4),
	"object": Color(0.42, 0.7, 1.0),
}
const KEY_SELECTED := Color(1, 1, 1)
const ACTION_TEXT := Color(0.75, 0.95, 0.7)

var timeline: TimelineController
var selection: SelectionManager

var _rows: Array = []
var _selected_key := {}      # { "kind", "uid", "t" }
var _drag_mode := ""         # "", "scrub", "key"
var _drag_key := {}
var _drag_time := 0.0
var _press_pos := Vector2.ZERO


func setup(timeline_controller: TimelineController, selection_manager: SelectionManager) -> void:
	timeline = timeline_controller
	selection = selection_manager
	focus_mode = Control.FOCUS_CLICK
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	timeline.time_changed.connect(func(_t: float) -> void: queue_redraw())
	timeline.keys_changed.connect(refresh)
	EventBus.selection_changed.connect(func(_n: Node3D) -> void: refresh())
	EventBus.history_changed.connect(refresh)
	resized.connect(queue_redraw)
	refresh()


func refresh() -> void:
	_rows = timeline.rows(selection.selected if selection.has_selection() else null)
	custom_minimum_size.y = RULER_HEIGHT + ROW_HEIGHT * _rows.size() + 4.0
	queue_redraw()


func selected_key() -> Dictionary:
	return _selected_key


func delete_selected_key() -> bool:
	if _selected_key.is_empty():
		return false
	if _selected_key["kind"] == "cuts":
		timeline.delete_cut(_selected_key["t"])
	else:
		timeline.delete_keys_at(_selected_key["uid"], _selected_key["t"])
	_selected_key = {}
	return true


# --- Geometry -------------------------------------------------------------------

func _track_width() -> float:
	return maxf(size.x - NAME_WIDTH - PAD_RIGHT, 10.0)


func _time_to_x(t: float) -> float:
	return NAME_WIDTH + t / maxf(timeline.duration(), 0.001) * _track_width()


func _x_to_time(x: float) -> float:
	return clampf((x - NAME_WIDTH) / _track_width() * timeline.duration(), 0.0, timeline.duration())


func _row_y(index: int) -> float:
	return RULER_HEIGHT + index * ROW_HEIGHT


func _key_at(pos: Vector2) -> Dictionary:
	if pos.x < NAME_WIDTH - KEY_RADIUS or pos.y < RULER_HEIGHT:
		return {}
	var index := int((pos.y - RULER_HEIGHT) / ROW_HEIGHT)
	if index < 0 or index >= _rows.size():
		return {}
	var row: Dictionary = _rows[index]
	var best := {}
	var best_dx := KEY_RADIUS + 3.0
	for t in row["times"]:
		var dx := absf(_time_to_x(t) - pos.x)
		if dx <= best_dx:
			best_dx = dx
			best = {"kind": row["kind"], "uid": row["uid"], "t": t}
	return best


# --- Input -----------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				grab_focus()
				_on_left_press(mb.position)
			else:
				_on_left_release()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var key := _key_at(mb.position)
			if not key.is_empty():
				_selected_key = key
				delete_selected_key()
			accept_event()
	elif event is InputEventMouseMotion and not _drag_mode.is_empty():
		var x := (event as InputEventMouseMotion).position.x
		if _drag_mode == "scrub":
			timeline.set_time(_x_to_time(x))
		elif _drag_mode == "key":
			_drag_time = timeline.snap_time(_x_to_time(x))
			queue_redraw()
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode in [KEY_DELETE, KEY_BACKSPACE] and delete_selected_key():
			accept_event()


func _on_left_press(pos: Vector2) -> void:
	_press_pos = pos
	# Click a row name → select that object.
	if pos.x < NAME_WIDTH and pos.y >= RULER_HEIGHT:
		var index := int((pos.y - RULER_HEIGHT) / ROW_HEIGHT)
		if index >= 0 and index < _rows.size():
			var node: Variant = _rows[index]["node"]
			if node is Node3D:
				selection.select(node)
		return
	var key := _key_at(pos)
	if not key.is_empty():
		_selected_key = key
		_drag_key = key
		_drag_time = key["t"]
		_drag_mode = "key"
		timeline.set_time(key["t"])
		queue_redraw()
		return
	_selected_key = {}
	_drag_mode = "scrub"
	if timeline.is_playing():
		timeline.pause()
	timeline.set_time(_x_to_time(pos.x))


func _on_left_release() -> void:
	if _drag_mode == "key" and not _drag_key.is_empty():
		var from_t: float = _drag_key["t"]
		if absf(_drag_time - from_t) > KeyframeStore.EPSILON:
			if _drag_key["kind"] == "cuts":
				timeline.move_cut(from_t, _drag_time)
			else:
				timeline.move_keys(_drag_key["uid"], from_t, _drag_time)
			_selected_key = _drag_key.duplicate()
			_selected_key["t"] = timeline.snap_time(_drag_time)
			timeline.set_time(_selected_key["t"])
	_drag_mode = ""
	_drag_key = {}
	queue_redraw()


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	var font := get_theme_default_font()
	var font_size := 12
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	draw_rect(Rect2(0, 0, size.x, RULER_HEIGHT), RULER_BG)
	_draw_ruler(font, font_size)

	var selected_node: Node = selection.selected if selection.has_selection() else null
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var y := _row_y(i)
		if i % 2 == 1:
			draw_rect(Rect2(0, y, size.x, ROW_HEIGHT), ROW_ALT)
		if row["node"] != null and row["node"] == selected_node:
			draw_rect(Rect2(0, y, size.x, ROW_HEIGHT), ROW_SELECTED)
		var label: String = row["label"]
		draw_string(font, Vector2(10, y + ROW_HEIGHT * 0.5 + font_size * 0.35), label,
			HORIZONTAL_ALIGNMENT_LEFT, NAME_WIDTH - 16, font_size, NAME_TEXT)
		var color: Color = KEY_COLORS.get(row["kind"], KEY_COLORS["object"])
		var cy := y + ROW_HEIGHT * 0.5
		var times: PackedFloat32Array = row["times"]
		if row["kind"] == "cuts":
			_draw_cut_spans(times, y, font, font_size)
		for t in times:
			var shown_t := t
			var is_dragged := _drag_mode == "key" and _same_key(_drag_key, row, t)
			if is_dragged:
				shown_t = _drag_time
			var selected := not _selected_key.is_empty() and _same_key(_selected_key, row, t)
			_draw_key(Vector2(_time_to_x(shown_t), cy), KEY_SELECTED if (selected or is_dragged) else color)
		for label_entry in row.get("labels", []):
			var lx := _time_to_x(float(label_entry[0]))
			draw_string(font, Vector2(lx + KEY_RADIUS + 3, cy + font_size * 0.35), str(label_entry[1]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, ACTION_TEXT)
		if times.is_empty() and row["kind"] != "cuts":
			draw_string(font, Vector2(NAME_WIDTH + 8, cy + font_size * 0.35), "no keyframes",
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, Color(1, 1, 1, 0.25))

	draw_line(Vector2(NAME_WIDTH, 0), Vector2(NAME_WIDTH, size.y), Color(1, 1, 1, 0.08))
	var px := _time_to_x(timeline.current_time)
	draw_line(Vector2(px, 0), Vector2(px, size.y), PLAYHEAD, 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(px - 6, 0), Vector2(px + 6, 0), Vector2(px + 6, 8), Vector2(px, 14), Vector2(px - 6, 8)]), PLAYHEAD)


func _draw_ruler(font: Font, font_size: int) -> void:
	var duration := timeline.duration()
	var pixels_per_second := _track_width() / maxf(duration, 0.001)
	var step := 1.0
	for candidate in [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0]:
		step = candidate
		if pixels_per_second * candidate >= 48.0:
			break
	var t := 0.0
	while t <= duration + 0.0001:
		var x := _time_to_x(t)
		draw_line(Vector2(x, RULER_HEIGHT - 7), Vector2(x, RULER_HEIGHT), TICK, 1.0)
		draw_line(Vector2(x, RULER_HEIGHT), Vector2(x, size.y), Color(1, 1, 1, 0.035), 1.0)
		var text := ("%ds" % int(t)) if is_equal_approx(t, round(t)) else (String.num(t, 2) + "s")
		draw_string(font, Vector2(x + 3, RULER_HEIGHT - 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, TICK_TEXT)
		t += step
	var time_text := "%.2f / %.2f s" % [timeline.current_time, duration]
	draw_string(font, Vector2(10, RULER_HEIGHT - 7), time_text, HORIZONTAL_ALIGNMENT_LEFT, NAME_WIDTH - 12, font_size, PLAYHEAD)


func _draw_cut_spans(times: PackedFloat32Array, y: float, font: Font, font_size: int) -> void:
	var cuts := timeline.store.cuts
	for i in cuts.size():
		var start := float(cuts[i]["t"])
		var end := float(cuts[i + 1]["t"]) if i + 1 < cuts.size() else timeline.duration()
		var x0 := _time_to_x(start)
		var x1 := _time_to_x(end)
		var shade := Color(0.78, 0.52, 1.0, 0.16 if i % 2 == 0 else 0.1)
		draw_rect(Rect2(x0, y + 4, maxf(x1 - x0, 1.0), ROW_HEIGHT - 8), shade)
		var cam_name := timeline.camera_name(str(cuts[i]["camera"]))
		draw_string(font, Vector2(x0 + KEY_RADIUS + 4, y + ROW_HEIGHT * 0.5 + font_size * 0.35), cam_name,
			HORIZONTAL_ALIGNMENT_LEFT, maxf(x1 - x0 - KEY_RADIUS - 8, 1.0), font_size - 1, Color(0.9, 0.85, 1.0))
	if times.is_empty():
		draw_string(font, Vector2(NAME_WIDTH + 8, y + ROW_HEIGHT * 0.5 + font_size * 0.35),
			"select a camera, then Cut to Camera", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, Color(1, 1, 1, 0.25))


func _draw_key(center: Vector2, color: Color) -> void:
	var r := KEY_RADIUS
	var diamond := PackedVector2Array([
		center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])
	draw_colored_polygon(diamond, color)
	diamond.append(diamond[0])
	draw_polyline(diamond, Color(0, 0, 0, 0.6), 1.0)


static func _same_key(key: Dictionary, row: Dictionary, t: float) -> bool:
	return key.get("kind") == row["kind"] and key.get("uid") == row["uid"] \
		and absf(float(key.get("t", -1.0)) - t) < KeyframeStore.EPSILON

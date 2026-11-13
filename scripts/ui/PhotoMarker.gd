class_name PhotoMarker
extends Control
## Shows a face photo and the face points marked on it. Points are stored as
## 0..1 coordinates of the picture (from the top-left).
##
## Front photo (18 points): click the centre of each eye and the middle of the
## mouth; the other points are then placed for you, and you drag any dot that
## isn't exactly on its spot. "Find Points Automatically" (Avatar Studio) can
## place them all instead.
## Side photo (5 points): click them one by one, then drag to adjust.
##
## Mouse wheel zooms, right- or middle-drag moves the picture, hovering a dot
## shows its name and where it goes on the little face diagram.

signal changed

enum Mode { FRONT, SIDE }

const FRONT_KEYS: PackedStringArray = ["brow_l", "brow_r", "eye_l_out", "eye_l_in", "eye_r_in", "eye_r_out",
	"nose_tip", "nose_l", "nose_r", "mouth_l", "mouth_r", "lip_top", "lip_bottom", "chin", "jaw_l", "jaw_r", "cheek_l", "cheek_r"]
const SIDE_KEYS: PackedStringArray = ["side_eye", "side_nose", "side_mouth", "side_chin", "side_ear"]
## The three quick clicks on a front photo (also what older versions stored).
const QUICK_KEYS: PackedStringArray = ["left_eye", "right_eye", "mouth"]

const NAMES := {
	"left_eye": "centre of the eye on the LEFT of the picture",
	"right_eye": "centre of the eye on the RIGHT of the picture",
	"mouth": "middle of the mouth (where the lips meet)",
	"brow_l": "middle of the left eyebrow", "brow_r": "middle of the right eyebrow",
	"eye_l_out": "outer corner of the left eye", "eye_l_in": "inner corner of the left eye",
	"eye_r_in": "inner corner of the right eye", "eye_r_out": "outer corner of the right eye",
	"nose_tip": "tip of the nose", "nose_l": "left side of the nostrils", "nose_r": "right side of the nostrils",
	"mouth_l": "left corner of the mouth", "mouth_r": "right corner of the mouth",
	"lip_top": "top edge of the upper lip (middle)", "lip_bottom": "bottom edge of the lower lip (middle)",
	"chin": "bottom of the chin", "jaw_l": "left edge of the face at mouth height",
	"jaw_r": "right edge of the face at mouth height", "cheek_l": "left edge of the face at eye height",
	"cheek_r": "right edge of the face at eye height",
	"side_eye": "outer corner of the eye", "side_nose": "tip of the nose", "side_mouth": "corner of the mouth",
	"side_chin": "bottom of the chin", "side_ear": "middle of the ear hole",
}

## An average face, in eye-spacing units from the point between the eyes
## (x to the picture's right, y down). Places the points after the quick clicks.
const TEMPLATE := {
	"brow_l": Vector2(-0.5, -0.28), "brow_r": Vector2(0.5, -0.28),
	"eye_l_out": Vector2(-0.73, 0.0), "eye_l_in": Vector2(-0.27, 0.0),
	"eye_r_in": Vector2(0.27, 0.0), "eye_r_out": Vector2(0.73, 0.0),
	"nose_tip": Vector2(0.0, 0.49), "nose_l": Vector2(-0.25, 0.53), "nose_r": Vector2(0.25, 0.53),
	"mouth_l": Vector2(-0.4, 0.92), "mouth_r": Vector2(0.4, 0.92),
	"lip_top": Vector2(0.0, 0.84), "lip_bottom": Vector2(0.0, 1.11), "chin": Vector2(0.0, 1.72),
	"jaw_l": Vector2(-1.07, 0.92), "jaw_r": Vector2(1.07, 0.92),
	"cheek_l": Vector2(-1.09, 0.03), "cheek_r": Vector2(1.09, 0.03),
}
const TEMPLATE_MOUTH_Y := 0.92
## A profile facing right, for the side diagram (eye at 0,0; chin at 0,1).
const SIDE_TEMPLATE := {
	"side_eye": Vector2(0.0, 0.0), "side_nose": Vector2(0.33, 0.3), "side_mouth": Vector2(0.17, 0.54),
	"side_chin": Vector2(0.07, 1.0), "side_ear": Vector2(-0.93, 0.3),
}

const DOT_RADIUS := 5.0
const GRAB_RADIUS := 12.0

var mode := Mode.FRONT
var texture: Texture2D
var points: Dictionary = {}
var _quick: Dictionary = {}   # the three quick clicks while they're being made
var _zoom := 1.0
var _pan := Vector2.ZERO      # offset of the picture centre, in control pixels
var _hover := ""
var _drag := ""
var _panning := false


func _ready() -> void:
	custom_minimum_size = Vector2(300, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func keys() -> PackedStringArray:
	return SIDE_KEYS if mode == Mode.SIDE else FRONT_KEYS


func set_photo(path: String) -> bool:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return false
	texture = ImageTexture.create_from_image(image)
	start_over()
	reset_view()
	return true


func clear() -> void:
	texture = null
	start_over()


## Forgets the marks so they can be clicked again.
func start_over() -> void:
	points.clear()
	_quick.clear()
	_drag = ""
	queue_redraw()
	changed.emit()


func reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	queue_redraw()


func is_complete() -> bool:
	if texture == null:
		return false
	for key in keys():
		if not points.has(key):
			return false
	return true


## Sets every point at once (from the saved settings or automatic detection).
## Older saved settings with only the eyes and mouth are expanded.
func set_points(new_points: Dictionary) -> void:
	points.clear()
	_quick.clear()
	for key in keys():
		if new_points.get(key) is Array and (new_points[key] as Array).size() == 2:
			points[key] = [float(new_points[key][0]), float(new_points[key][1])]
	if mode == Mode.FRONT and points.size() < FRONT_KEYS.size():
		var all_quick := true
		for key in QUICK_KEYS:
			all_quick = all_quick and new_points.get(key) is Array
		points.clear()
		if all_quick:
			for key in QUICK_KEYS:
				_quick[key] = Vector2(float(new_points[key][0]), float(new_points[key][1]))
			_place_from_quick()
	queue_redraw()
	changed.emit()


## Everything to save / send to the builder. On a front photo this also keeps
## the eyes and mouth in the old form (used when only those are known).
func all_points() -> Dictionary:
	var out := points.duplicate(true)
	if mode == Mode.FRONT and is_complete():
		var l := (_uv("eye_l_out") + _uv("eye_l_in")) * 0.5
		var r := (_uv("eye_r_out") + _uv("eye_r_in")) * 0.5
		var m := (_uv("mouth_l") + _uv("mouth_r")) * 0.5
		out["left_eye"] = [l.x, l.y]
		out["right_eye"] = [r.x, r.y]
		out["mouth"] = [m.x, m.y]
	return out


func hint() -> String:
	if texture == null:
		if mode == Mode.SIDE:
			return "Optional: a side photo (the person in profile) improves the nose, lips and chin, and the sides of the face."
		return "Choose a clear, front-facing photo: good even light, looking straight at the camera, neutral expression, no glasses."
	var next := _next_click()
	if not next.is_empty():
		var step := (QUICK_KEYS.find(next) if mode == Mode.FRONT else SIDE_KEYS.find(next)) + 1
		var total := QUICK_KEYS.size() if mode == Mode.FRONT else SIDE_KEYS.size()
		return "Step %d of %d: click the %s." % [step, total, NAMES[next]]
	return "Now drag any dot that isn't exactly on its spot (hover a dot to see what it marks). Mouse wheel zooms, right-drag moves the picture."


## The next point to click, or "" when every point is placed.
func _next_click() -> String:
	if texture == null:
		return ""
	if mode == Mode.FRONT:
		if is_complete():
			return ""
		for key in QUICK_KEYS:
			if not _quick.has(key):
				return key
		return ""
	for key in SIDE_KEYS:
		if not points.has(key):
			return key
	return ""


## Places all 18 front points from the eyes and mouth, using the average face.
func _place_from_quick() -> void:
	var size_px := texture.get_size() if texture else Vector2.ONE
	var l: Vector2 = _quick["left_eye"] * size_px
	var r: Vector2 = _quick["right_eye"] * size_px
	var m: Vector2 = _quick["mouth"] * size_px
	var mid := (l + r) * 0.5
	var across := r - l
	var spacing := maxf(across.length(), 1.0)
	var x_axis := across / spacing
	var y_axis := Vector2(-x_axis.y, x_axis.x)
	# Stretch up/down so the mouth lands where it was clicked (faces differ in length).
	var stretch := clampf((m - mid).dot(y_axis) / spacing / TEMPLATE_MOUTH_Y, 0.7, 1.5)
	for key in TEMPLATE:
		var t: Vector2 = TEMPLATE[key]
		var at := mid + x_axis * t.x * spacing + y_axis * t.y * spacing * stretch
		var uv := at / size_px
		points[key] = [clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0)]
	_quick.clear()


func _uv(key: String) -> Vector2:
	var p: Array = points[key]
	return Vector2(float(p[0]), float(p[1]))


func _image_rect() -> Rect2:
	if texture == null:
		return Rect2()
	var tex_size := texture.get_size()
	var scale_factor := minf(size.x / tex_size.x, size.y / tex_size.y) * _zoom
	var shown := tex_size * scale_factor
	return Rect2(size * 0.5 + _pan - shown * 0.5, shown)


func _to_screen(uv: Vector2) -> Vector2:
	var rect := _image_rect()
	return rect.position + uv * rect.size


func _point_at(pos: Vector2) -> String:
	var best := ""
	var best_distance := GRAB_RADIUS
	for key in points:
		var d := _to_screen(_uv(key)).distance_to(pos)
		if d < best_distance:
			best = key
			best_distance = d
	return best


func _gui_input(event: InputEvent) -> void:
	if texture == null:
		return
	var mb := event as InputEventMouseButton
	if mb:
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var before := _image_rect()
			var uv := (mb.position - before.position) / before.size
			_zoom = clampf(_zoom * (1.2 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 1.0, 8.0)
			# Keep the spot under the mouse where it is.
			var after := _image_rect()
			_pan += mb.position - (after.position + uv * after.size)
			if _zoom == 1.0:
				_pan = Vector2.ZERO
			queue_redraw()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(mb.position)
			else:
				if not _drag.is_empty():
					_drag = ""
					changed.emit()
				queue_redraw()
			accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm:
		if _panning:
			_pan += mm.relative
			queue_redraw()
		elif not _drag.is_empty():
			var rect := _image_rect()
			var uv := ((mm.position - rect.position) / rect.size).clamp(Vector2.ZERO, Vector2.ONE)
			points[_drag] = [uv.x, uv.y]
			queue_redraw()
		else:
			var hover := _point_at(mm.position)
			if hover != _hover:
				_hover = hover
				queue_redraw()


func _press(pos: Vector2) -> void:
	var grab := _point_at(pos)
	if not grab.is_empty():
		_drag = grab
		_hover = grab
		queue_redraw()
		return
	var next := _next_click()
	var rect := _image_rect()
	if next.is_empty() or not rect.has_point(pos):
		return
	var uv := (pos - rect.position) / rect.size
	if mode == Mode.FRONT:
		_quick[next] = uv
		if _quick.size() == QUICK_KEYS.size():
			_place_from_quick()
	else:
		points[next] = [uv.x, uv.y]
	queue_redraw()
	changed.emit()


static func _color(key: String) -> Color:
	if key.contains("brow"):
		return Color(1.0, 0.85, 0.3)
	if key.contains("eye"):
		return Color(0.3, 0.8, 1.0)
	if key.contains("nose"):
		return Color(0.4, 1.0, 0.5)
	if key.contains("mouth") or key.contains("lip"):
		return Color(1.0, 0.45, 0.4)
	if key.contains("ear"):
		return Color(0.8, 0.6, 1.0)
	return Color(1.0, 0.6, 1.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.12))
	if texture == null:
		return
	draw_texture_rect(texture, _image_rect(), false)
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	# Face outline between the dots helps spot a misplaced one.
	if mode == Mode.FRONT and is_complete():
		for chain in [["cheek_l", "jaw_l", "chin", "jaw_r", "cheek_r"], ["eye_l_out", "eye_l_in"], ["eye_r_in", "eye_r_out"],
				["nose_l", "nose_tip", "nose_r"], ["mouth_l", "lip_top", "mouth_r", "lip_bottom", "mouth_l"]]:
			for i in range(chain.size() - 1):
				draw_line(_to_screen(_uv(chain[i])), _to_screen(_uv(chain[i + 1])), Color(1, 1, 1, 0.35), 1.0, true)
	for key in _quick:
		var at := _to_screen(_quick[key])
		draw_circle(at, DOT_RADIUS, Color(1, 1, 1))
		draw_arc(at, DOT_RADIUS + 2.0, 0.0, TAU, 20, Color.BLACK, 2.0)
	for key in points:
		var at := _to_screen(_uv(key))
		var active: bool = key == _hover or key == _drag
		draw_circle(at, DOT_RADIUS * (1.4 if active else 1.0), Color.WHITE if active else _color(key))
		draw_arc(at, DOT_RADIUS * (1.4 if active else 1.0) + 1.5, 0.0, TAU, 20, Color.BLACK, 1.5)
	var named := _drag if not _drag.is_empty() else _hover
	if named.is_empty():
		named = _next_click()
	if not named.is_empty():
		var text: String = NAMES.get(named, named)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_rect(Rect2(Vector2(6, size.y - font_size - 14), Vector2(width + 12, font_size + 8)), Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(12, size.y - 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	_draw_diagram(named)


## A small face in the corner with [param key] highlighted, so it's clear which spot is meant.
func _draw_diagram(key: String) -> void:
	var box := Rect2(Vector2(size.x - 92, 6), Vector2(86, 96))
	draw_rect(box, Color(0, 0, 0, 0.65))
	var place := {}
	if mode == Mode.FRONT:
		var centre := box.position + Vector2(43, 30)
		var s := 24.0
		for name_ in TEMPLATE:
			place[name_] = centre + (TEMPLATE[name_] as Vector2) * s
		place["left_eye"] = centre + Vector2(-0.5, 0.0) * s
		place["right_eye"] = centre + Vector2(0.5, 0.0) * s
		place["mouth"] = centre + Vector2(0.0, TEMPLATE_MOUTH_Y) * s
		var outline := PackedVector2Array()
		for i in 25:
			var a := PI * float(i) / 24.0
			outline.append(centre + Vector2(cos(a) * 1.1, 0.0 + sin(a) * 1.75) * s)
		draw_polyline(outline, Color(1, 1, 1, 0.5), 1.0, true)
		draw_arc(centre, 1.1 * s, PI, TAU, 16, Color(1, 1, 1, 0.5), 1.0, true)
		for side in [-1.0, 1.0]:
			draw_line(centre + Vector2(side * 0.75, -0.3) * s, centre + Vector2(side * 0.25, -0.32) * s, Color(1, 1, 1, 0.6), 1.5)
			draw_arc(centre + Vector2(side * 0.5, 0.0) * s, 0.22 * s, 0.0, TAU, 12, Color(1, 1, 1, 0.6), 1.0)
		draw_line(centre + Vector2(0.0, 0.1) * s, centre + Vector2(0.0, 0.49) * s, Color(1, 1, 1, 0.5), 1.0)
		draw_line(centre + Vector2(-0.25, 0.53) * s, centre + Vector2(0.25, 0.53) * s, Color(1, 1, 1, 0.5), 1.0)
		draw_line(centre + Vector2(-0.4, 0.92) * s, centre + Vector2(0.4, 0.92) * s, Color(1, 1, 1, 0.6), 1.5)
	else:
		var eye := box.position + Vector2(58, 22)
		var s := 46.0
		for name_ in SIDE_TEMPLATE:
			place[name_] = eye + (SIDE_TEMPLATE[name_] as Vector2) * s
		var profile := PackedVector2Array([eye + Vector2(-0.1, -0.4) * s, eye + Vector2(0.12, -0.1) * s, eye + Vector2(0.33, 0.3) * s,
			eye + Vector2(0.2, 0.38) * s, eye + Vector2(0.22, 0.5) * s, eye + Vector2(0.17, 0.56) * s, eye + Vector2(0.2, 0.7) * s,
			eye + Vector2(0.07, 1.0) * s, eye + Vector2(-0.5, 0.95) * s])
		draw_polyline(profile, Color(1, 1, 1, 0.5), 1.0, true)
		draw_arc(eye + Vector2(-0.93, 0.3) * s, 0.12 * s, 0.0, TAU, 12, Color(1, 1, 1, 0.5), 1.0)
	for name_ in place:
		if name_ == key:
			continue
		if (mode == Mode.FRONT) == (not str(name_).begins_with("side")) and not QUICK_KEYS.has(name_):
			draw_circle(place[name_], 1.5, Color(1, 1, 1, 0.5))
	if place.has(key):
		draw_circle(place[key], 4.0, _color(key) if not QUICK_KEYS.has(key) else Color.WHITE)
		draw_arc(place[key], 5.5, 0.0, TAU, 16, Color.BLACK, 1.5)

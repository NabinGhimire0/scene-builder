class_name LetterboxOverlay
extends Control
## Camera View overlay: black bars outside the export frame, rule-of-thirds
## guides, and a label with the live camera, lens and timecode.

@export var director: CinematicDirector
@export var timeline: TimelineController

const BAR_COLOR := Color(0.0, 0.0, 0.0, 0.92)
const GUIDE_COLOR := Color(1.0, 1.0, 1.0, 0.12)
const FRAME_COLOR := Color(1.0, 1.0, 1.0, 0.35)

var active := false:
	set(value):
		active = value
		visible = value
		queue_redraw()
var show_guides := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = active
	resized.connect(queue_redraw)


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


## The film frame inside this control, in local coordinates.
func frame_rect() -> Rect2:
	var aspect := director.render_aspect if director else 16.0 / 9.0
	var view := size
	if view.x / maxf(view.y, 1.0) > aspect:
		var w := view.y * aspect
		return Rect2((view.x - w) * 0.5, 0.0, w, view.y)
	var h := view.x / aspect
	return Rect2(0.0, (view.y - h) * 0.5, view.x, h)


func _draw() -> void:
	if not active:
		return
	var frame := frame_rect()
	draw_rect(Rect2(0, 0, size.x, frame.position.y), BAR_COLOR)
	draw_rect(Rect2(0, frame.end.y, size.x, size.y - frame.end.y), BAR_COLOR)
	draw_rect(Rect2(0, frame.position.y, frame.position.x, frame.size.y), BAR_COLOR)
	draw_rect(Rect2(frame.end.x, frame.position.y, size.x - frame.end.x, frame.size.y), BAR_COLOR)
	draw_rect(frame, FRAME_COLOR, false, 1.0)
	if show_guides:
		for i in range(1, 3):
			var x := frame.position.x + frame.size.x * i / 3.0
			var y := frame.position.y + frame.size.y * i / 3.0
			draw_line(Vector2(x, frame.position.y), Vector2(x, frame.end.y), GUIDE_COLOR, 1.0)
			draw_line(Vector2(frame.position.x, y), Vector2(frame.end.x, y), GUIDE_COLOR, 1.0)

	var cam: CinematicCamera = director.current_camera() if director else null
	if cam == null:
		return
	var font := get_theme_default_font()
	var font_size := 13
	var text := "%s   %.0f mm   %s" % [cam.name, cam.focal_length_mm(), "DoF" if cam.dof_enabled else ""]
	var time_text: String = "%.2f s" % timeline.current_time if timeline else ""
	var pos := frame.position + Vector2(10, frame.size.y - 12)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.7))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 0.55, 0.5))
	var time_pos := Vector2(frame.end.x - 10 - font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, pos.y)
	draw_string_outline(font, time_pos, time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.7))
	draw_string(font, time_pos, time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.85))

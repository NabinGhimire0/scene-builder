class_name TutorialOverlay
extends Control
## First-run guided tour: dims the window, highlights one part of the screen
## at a time and explains it. Shown automatically the first time; reopen it
## any time from the Help button.

const SETTINGS_FILE := "user://settings.cfg"

## Each step: [title, text, target control or null].
var steps: Array = []
var _index := 0
var _panel: PanelContainer
var _title: Label
var _text: Label
var _counter: Label
var _back: Button
var _next: Button


static func should_show() -> bool:
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE)
	return not bool(config.get_value("app", "tutorial_done", false))


static func mark_done() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE)
	config.set_value("app", "tutorial_done", true)
	config.save(SETTINGS_FILE)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(380, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_counter = Label.new()
	_counter.theme_type_variation = &"DimLabel"
	box.add_child(_counter)
	_title = Label.new()
	_title.theme_type_variation = &"PanelTitle"
	box.add_child(_title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(360, 0)
	box.add_child(_text)
	var buttons := HBoxContainer.new()
	var skip := Button.new()
	skip.text = "Skip tour"
	skip.pressed.connect(finish)
	buttons.add_child(skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	_back = Button.new()
	_back.text = "Back"
	_back.pressed.connect(func() -> void: _show(_index - 1))
	buttons.add_child(_back)
	_next = Button.new()
	_next.text = "Next"
	_next.pressed.connect(func() -> void: _show(_index + 1))
	buttons.add_child(_next)
	box.add_child(buttons)


func start() -> void:
	visible = true
	move_to_front()
	_show(0)


func finish() -> void:
	visible = false
	mark_done()


func _show(index: int) -> void:
	if index >= steps.size():
		finish()
		return
	_index = clampi(index, 0, steps.size() - 1)
	var step: Array = steps[_index]
	_title.text = str(step[0])
	_text.text = str(step[1])
	_counter.text = "Step %d of %d" % [_index + 1, steps.size()]
	_back.disabled = _index == 0
	_next.text = "Finish" if _index == steps.size() - 1 else "Next"
	_place_panel.call_deferred()
	queue_redraw()


func _target_rect() -> Rect2:
	var step: Array = steps[_index]
	var target: Control = step[2]
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return Rect2()
	return target.get_global_rect().grow(6.0)


func _place_panel() -> void:
	var area := get_viewport_rect().size
	var rect := _target_rect()
	var panel_size := _panel.get_combined_minimum_size()
	var at := (area - panel_size) * 0.5
	if rect.size != Vector2.ZERO:
		# Beside the highlighted area, on whichever side has room.
		if rect.end.x + panel_size.x + 20.0 < area.x:
			at = Vector2(rect.end.x + 16.0, rect.position.y)
		elif rect.position.x - panel_size.x - 20.0 > 0.0:
			at = Vector2(rect.position.x - panel_size.x - 16.0, rect.position.y)
		elif rect.end.y + panel_size.y + 20.0 < area.y:
			at = Vector2(rect.position.x, rect.end.y + 16.0)
		else:
			at = Vector2(rect.position.x, rect.position.y - panel_size.y - 16.0)
	at = at.clamp(Vector2(12, 12), area - panel_size - Vector2(12, 12))
	_panel.position = at
	_panel.size = panel_size


func _draw() -> void:
	var area := get_viewport_rect().size
	var shade := Color(0, 0, 0, 0.62)
	var rect := _target_rect()
	if rect.size == Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, area), shade)
		return
	draw_rect(Rect2(0, 0, area.x, rect.position.y), shade)
	draw_rect(Rect2(0, rect.end.y, area.x, area.y - rect.end.y), shade)
	draw_rect(Rect2(0, rect.position.y, rect.position.x, rect.size.y), shade)
	draw_rect(Rect2(rect.end.x, rect.position.y, area.x - rect.end.x, rect.size.y), shade)
	draw_rect(rect, Color(1.0, 0.62, 0.15), false, 3.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_place_panel.call_deferred()
		queue_redraw()

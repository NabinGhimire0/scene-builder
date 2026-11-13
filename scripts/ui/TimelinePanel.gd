extends PanelContainer
## Bottom timeline panel: transport (start, play/pause, stop, frame step),
## duration, keyframe tools, Auto-Key, interpolation, and the track view.

@export var timeline: TimelineController
@export var selection: SelectionManager
@export var director: CinematicDirector
@export var environment: EnvironmentController

var _play_button: Button
var _time_label: Label
var _duration: SpinBox
var _auto_key: CheckButton
var _interpolation: OptionButton
var _cut_button: Button
var _view: TimelineView
var _updating := false

@onready var _root: VBoxContainer = %TimelineRoot


func _ready() -> void:
	_build()
	timeline.time_changed.connect(_on_time_changed)
	timeline.playing_changed.connect(_on_playing_changed)
	timeline.keys_changed.connect(_refresh_settings)
	EventBus.selection_changed.connect(func(_n: Node3D) -> void: _update_buttons())
	_refresh_settings()
	_on_time_changed(timeline.current_time)
	_update_buttons()


func _build() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	_root.add_child(bar)

	var title := Label.new()
	title.text = "TIMELINE"
	title.theme_type_variation = &"SectionHeader"
	bar.add_child(title)

	_add_button(bar, "|<", "Go to start (Home)", func() -> void: timeline.set_time(0.0))
	_add_button(bar, "<", "Previous frame (,)", func() -> void: timeline.step_frames(-1))
	_play_button = _add_button(bar, "Play", "Play / pause (Space)", timeline.toggle_play)
	_play_button.custom_minimum_size.x = 64
	_add_button(bar, ">", "Next frame (.)", func() -> void: timeline.step_frames(1))
	_add_button(bar, "Stop", "Stop and return to start", timeline.stop)

	_time_label = Label.new()
	_time_label.custom_minimum_size.x = 120
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_time_label)

	var duration_label := Label.new()
	duration_label.text = "Length"
	duration_label.theme_type_variation = &"DimLabel"
	bar.add_child(duration_label)
	_duration = SpinBox.new()
	_duration.min_value = TimelineController.MIN_DURATION
	_duration.max_value = TimelineController.MAX_DURATION
	_duration.step = 0.5
	_duration.suffix = "s"
	_duration.tooltip_text = "Film length in seconds"
	_duration.value_changed.connect(_on_duration_changed)
	bar.add_child(_duration)

	bar.add_child(VSeparator.new())
	_add_button(bar, "Add Keyframe", "Record the selected object at the playhead (I)",
		func() -> void: timeline.add_keyframe(selection.selected if selection.has_selection() else null))
	_add_button(bar, "Key Lighting", "Record the lighting at the playhead",
		func() -> void: timeline.add_keyframe(environment))
	_cut_button = _add_button(bar, "Cut to Camera", "From the playhead, show the selected camera",
		func() -> void: timeline.add_cut(selection.selected_camera()))
	_add_button(bar, "Delete Key", "Delete the selected keyframe (or right-click a key)", _delete_key)

	_auto_key = CheckButton.new()
	_auto_key.text = "Auto-Key"
	_auto_key.focus_mode = Control.FOCUS_NONE
	_auto_key.tooltip_text = "When on, every change you make is recorded as a keyframe at the playhead"
	_auto_key.toggled.connect(_on_auto_key_toggled)
	bar.add_child(_auto_key)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	_interpolation = OptionButton.new()
	for item in TimelineController.INTERPOLATION_NAMES:
		_interpolation.add_item(item)
	_interpolation.focus_mode = Control.FOCUS_NONE
	_interpolation.tooltip_text = "How motion flows between keyframes:\nSmooth – eases in and out of every key\nLinear – constant speed\nFlowing – one continuous curve through all keys"
	_interpolation.item_selected.connect(_on_interpolation_selected)
	bar.add_child(_interpolation)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	_view = TimelineView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_view)
	_view.setup(timeline, selection)


func _add_button(parent: Control, text: String, tip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _on_time_changed(t: float) -> void:
	_time_label.text = "%s / %s" % [_timecode(t), _timecode(timeline.duration())]


func _timecode(seconds: float) -> String:
	var frames := int(round(seconds * timeline.frame_rate))
	var fps := int(timeline.frame_rate)
	var whole := frames / fps
	return "%02d:%02d:%02d" % [whole / 60, whole % 60, frames % fps]


func _on_playing_changed(playing: bool) -> void:
	_play_button.text = "Pause" if playing else "Play"


func _on_duration_changed(value: float) -> void:
	if not _updating:
		timeline.set_duration(value)


func _on_interpolation_selected(index: int) -> void:
	if not _updating:
		timeline.set_interpolation(index)


func _on_auto_key_toggled(on: bool) -> void:
	timeline.auto_key = on
	_auto_key.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if on else Color(0.86, 0.88, 0.91))
	_auto_key.add_theme_color_override("font_pressed_color", Color(1, 0.45, 0.4) if on else Color(0.86, 0.88, 0.91))
	EventBus.info("Auto-Key on: changes are recorded at the playhead." if on else "Auto-Key off.")


func _delete_key() -> void:
	if not _view.delete_selected_key():
		EventBus.info("Click a keyframe diamond to select it first (or right-click it to delete).")


func _refresh_settings() -> void:
	_updating = true
	_duration.value = timeline.duration()
	_interpolation.select(timeline.interpolation())
	if _auto_key.button_pressed != timeline.auto_key:
		_auto_key.set_pressed_no_signal(timeline.auto_key)
	_updating = false
	_on_time_changed(timeline.current_time)


func _update_buttons() -> void:
	_cut_button.disabled = selection.selected_camera() == null


## Called by MainUI's shortcut handler.
func delete_selected_key() -> bool:
	return _view.delete_selected_key()

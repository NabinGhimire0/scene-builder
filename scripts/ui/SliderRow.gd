class_name SliderRow
extends VBoxContainer
## A labelled slider with a live value read-out, used by the inspector.
## [signal value_edited] fires only for user changes, not for [method set_value].

signal value_edited(value: float)

var _slider: HSlider
var _value_label: Label
var _formatter := Callable()
var _updating := false


## [param formatter] turns the value into display text (default: 2 decimals).
func setup(title: String, min_value: float, max_value: float, step: float, formatter: Callable = Callable(), tooltip: String = "") -> void:
	add_theme_constant_override("separation", 2)
	_formatter = formatter
	var header := HBoxContainer.new()
	add_child(header)
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"DimLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	_value_label = Label.new()
	_value_label.theme_type_variation = &"DimLabel"
	header.add_child(_value_label)
	_slider = HSlider.new()
	_slider.min_value = min_value
	_slider.max_value = max_value
	_slider.step = step
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.tooltip_text = tooltip
	_slider.value_changed.connect(_on_value_changed)
	add_child(_slider)
	_update_label(_slider.value)


func set_value(value: float) -> void:
	_updating = true
	_slider.value = value
	_updating = false
	_update_label(value)


func get_value() -> float:
	return _slider.value


func set_editable(editable: bool) -> void:
	_slider.editable = editable
	modulate.a = 1.0 if editable else 0.5


func _on_value_changed(value: float) -> void:
	_update_label(value)
	if not _updating:
		value_edited.emit(value)


func _update_label(value: float) -> void:
	_value_label.text = _formatter.call(value) if _formatter.is_valid() else "%.2f" % value

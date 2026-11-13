class_name Vector3Field
extends VBoxContainer
## A labelled X / Y / Z number editor used by the inspector.
## Emits [signal component_changed] with just the edited axis, so values the
## spin boxes had to round for display are never written back to the object.

signal component_changed(axis: int, value: float)

const AXIS_NAMES: PackedStringArray = ["X", "Y", "Z"]
const AXIS_COLORS: Array[Color] = [Color(0.95, 0.42, 0.42), Color(0.5, 0.86, 0.45), Color(0.45, 0.62, 1.0)]

var _spins: Array[SpinBox] = []
var _updating := false


## [param arrow_step] is how much one arrow click changes the value.
func setup(title: String, step: float, arrow_step: float, suffix: String = "", min_value: float = -1.0e6) -> void:
	add_theme_constant_override("separation", 3)
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"DimLabel"
	add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for i in 3:
		var spin := SpinBox.new()
		spin.prefix = AXIS_NAMES[i]
		spin.suffix = suffix
		spin.min_value = min_value
		spin.max_value = 1.0e6
		spin.step = step
		spin.custom_arrow_step = arrow_step
		spin.allow_greater = true
		spin.allow_lesser = min_value <= -1.0e6
		spin.select_all_on_focus = true
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.custom_minimum_size = Vector2(64, 0)
		spin.get_line_edit().add_theme_color_override("font_color", AXIS_COLORS[i].lerp(Color.WHITE, 0.45))
		spin.value_changed.connect(_on_spin_changed.bind(i))
		row.add_child(spin)
		_spins.append(spin)


func set_value(value: Vector3) -> void:
	_updating = true
	for i in 3:
		_spins[i].value = value[i]
	_updating = false


func get_value() -> Vector3:
	return Vector3(_spins[0].value, _spins[1].value, _spins[2].value)


func set_editable(editable: bool) -> void:
	for spin in _spins:
		spin.editable = editable


func _on_spin_changed(value: float, axis: int) -> void:
	if not _updating:
		component_changed.emit(axis, value)

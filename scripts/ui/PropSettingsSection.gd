class_name PropSettingsSection
extends VBoxContainer
## Inspector section for objects that describe their own settings
## ([method ProceduralProp.inspector_fields]): sliders, colours, menus and
## ready-made looks. Every change is undoable and merges while dragging.

var history: EditorHistory

var _target: Node
var _fields: Array = []
var _controls: Dictionary = {}   # property -> control
var _updating := false


func setup(editor_history: EditorHistory) -> void:
	history = editor_history
	add_theme_constant_override("separation", 8)
	visible = false


## Shows the settings of [param node] (hides the section if it has none).
func show_for(node: Node) -> void:
	var fields: Array = []
	if is_instance_valid(node) and node.has_method(&"inspector_fields"):
		fields = node.call(&"inspector_fields")
	visible = not fields.is_empty()
	if node != _target or fields.size() != _fields.size():
		_target = node
		_fields = fields
		_rebuild()
	refresh()


func refresh() -> void:
	if not visible or not is_instance_valid(_target):
		return
	_updating = true
	for field in _fields:
		var property := str(field.get("property", ""))
		var control: Control = _controls.get(property)
		if control == null:
			continue
		var value: Variant = _target.get(property)
		match str(field["type"]):
			"float", "int":
				(control as SliderRow).set_value(float(value))
			"color":
				(control as ColorPickerButton).color = value
			"bool":
				(control as CheckBox).set_pressed_no_signal(bool(value))
			"option":
				var option := control as OptionButton
				option.select(maxi((field["items"] as PackedStringArray).find(str(value)), 0))
			"preset":
				var preset := control as OptionButton
				var names: Array = (field["presets"] as Dictionary).keys()
				preset.select(names.find(str(value)))
			"text":
				var edit := control as LineEdit
				if not edit.has_focus():
					edit.text = str(value).replace("\n", " | ")
	_updating = false


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_controls.clear()
	if _fields.is_empty():
		return
	var title := str(_target.call(&"inspector_title")) if _target.has_method(&"inspector_title") else "Settings"
	add_child(_heading(title))
	for field in _fields:
		_add_field(field)


func _add_field(field: Dictionary) -> void:
	var property := str(field.get("property", ""))
	var label := str(field.get("label", property.capitalize()))
	var hint := str(field.get("hint", ""))
	var control: Control = null
	match str(field["type"]):
		"header":
			add_child(_heading(label, true))
		"note":
			add_child(_dim(label))
		"action":
			var button := Button.new()
			button.text = label
			button.tooltip_text = hint
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(_on_action.bind(str(field.get("method", ""))))
			add_child(button)
		"float", "int":
			var row := SliderRow.new()
			var suffix := str(field.get("suffix", ""))
			var is_int := str(field["type"]) == "int"
			row.setup(label, float(field.get("min", 0.0)), float(field.get("max", 1.0)), float(field.get("step", 0.01)),
				_formatter(suffix, is_int), hint)
			row.value_edited.connect(_on_number.bind(property, is_int, label))
			control = row
		"color":
			var color_row := HBoxContainer.new()
			var name_label := _dim(label)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			color_row.add_child(name_label)
			var picker := ColorPickerButton.new()
			picker.custom_minimum_size = Vector2(64, 26)
			picker.edit_alpha = false
			picker.focus_mode = Control.FOCUS_NONE
			picker.tooltip_text = hint
			picker.color_changed.connect(_on_value.bind(property, label))
			color_row.add_child(picker)
			add_child(color_row)
			_controls[property] = picker
		"text":
			add_child(_dim(label))
			var edit := LineEdit.new()
			edit.tooltip_text = hint if not hint.is_empty() else "Use | between lines"
			edit.text_submitted.connect(func(t: String) -> void: _on_value(t, property, label))
			edit.focus_exited.connect(func() -> void:
				if is_instance_valid(_target) and str(_target.get(property)).replace("\n", " | ") != edit.text:
					_on_value(edit.text, property, label))
			control = edit
		"bool":
			var check := CheckBox.new()
			check.text = label
			check.tooltip_text = hint
			check.focus_mode = Control.FOCUS_NONE
			check.toggled.connect(_on_value.bind(property, label))
			control = check
		"option":
			var option := _option_row(label, field["items"] as PackedStringArray, hint)
			option.item_selected.connect(_on_option.bind(field["items"], property, label))
			_controls[property] = option
		"preset":
			var names := PackedStringArray()
			for key in (field["presets"] as Dictionary).keys():
				names.append(str(key))
			var preset := _option_row(label, names, hint)
			preset.item_selected.connect(_on_preset.bind(field, label))
			_controls[property] = preset
	if control:
		add_child(control)
		_controls[property] = control


func _option_row(label: String, items: PackedStringArray, hint: String) -> OptionButton:
	var row := HBoxContainer.new()
	var name_label := _dim(label)
	name_label.custom_minimum_size = Vector2(96, 0)
	row.add_child(name_label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.focus_mode = Control.FOCUS_NONE
	option.tooltip_text = hint
	option.fit_to_longest_item = false
	for item in items:
		option.add_item(item)
	row.add_child(option)
	add_child(row)
	return option


func _on_action(method: String) -> void:
	if is_instance_valid(_target) and _target.has_method(method):
		_target.call(method, history)
		refresh()


func _on_number(value: float, property: String, is_int: bool, label: String) -> void:
	if is_int:
		_commit({property: roundi(value)}, label)
	else:
		_commit({property: value}, label)


func _on_value(value: Variant, property: String, label: String) -> void:
	_commit({property: value}, label)


func _on_option(index: int, items: PackedStringArray, property: String, label: String) -> void:
	_commit({property: items[index]}, label)


## A ready-made look: sets its name plus every value it contains, as one step.
func _on_preset(index: int, field: Dictionary, label: String) -> void:
	var presets: Dictionary = field["presets"]
	var key: Variant = presets.keys()[index]
	var to: Dictionary = (presets[key] as Dictionary).duplicate()
	to[str(field["property"])] = str(key)
	_commit(to, label)
	refresh()


func _commit(to: Dictionary, label: String) -> void:
	if _updating or not is_instance_valid(_target) or history == null:
		return
	var from := {}
	for key in to:
		from[key] = _target.get(key)
	history.set_properties(_target, from, to, "%s %s" % [label, _target.name])


static func _formatter(suffix: String, is_int: bool) -> Callable:
	if is_int:
		return func(v: float) -> String: return "%d%s" % [roundi(v), suffix]
	return func(v: float) -> String: return String.num(v, 2) + suffix


static func _heading(text: String, minor: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.uppercase = true
	label.theme_type_variation = &"DimLabel" if minor else &"SectionHeader"
	return label


static func _dim(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"DimLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

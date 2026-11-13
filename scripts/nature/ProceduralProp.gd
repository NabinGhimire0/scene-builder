class_name ProceduralProp
extends Node3D
## Base for objects generated in code (water, terrain features…).
##
## Subclasses list their settings in [method inspector_fields]; the Inspector
## builds sliders, colour pickers and menus from that list, every edit is
## undoable, and the values are saved with the project and copied on duplicate.
##
## Field dictionaries:
##   { "type": "float"|"int", "property", "label", "min", "max", "step", "suffix", "hint" }
##   { "type": "color"|"bool", "property", "label", "hint" }
##   { "type": "option", "property", "label", "items": PackedStringArray, "hint" }
##   { "type": "preset", "property", "label", "presets": { name: { property: value } }, "hint" }
##   { "type": "header", "label" } and { "type": "note", "label" }

var _built := false


## Builds geometry now (called before the object is measured or placed).
func ensure_built() -> void:
	if not _built:
		_built = true
		_build()


func _ready() -> void:
	ensure_built()


func inspector_title() -> String:
	return "Settings"


func inspector_fields() -> Array:
	return []


func get_custom_state() -> Dictionary:
	var state := {}
	for field in inspector_fields():
		var property := str(field.get("property", ""))
		if property.is_empty():
			continue
		var value: Variant = get(property)
		state[property] = [value.r, value.g, value.b] if value is Color else value
	return state


func set_custom_state(state: Dictionary) -> void:
	for field in inspector_fields():
		var property := str(field.get("property", ""))
		if property.is_empty() or not state.has(property):
			continue
		var value: Variant = state[property]
		var current: Variant = get(property)
		if current is Color:
			if value is Array and value.size() >= 3:
				set(property, Color(float(value[0]), float(value[1]), float(value[2])))
		elif current is bool:
			set(property, bool(value))
		elif current is int:
			set(property, int(value))
		elif current is float:
			set(property, float(value))
		else:
			set(property, str(value))


## Override: create child nodes from the current settings.
func _build() -> void:
	pass


## Override: refresh after a setting changed (only called once built).
func _settings_changed(_geometry: bool) -> void:
	pass


## Property setters call this.
func _changed(geometry: bool = false) -> void:
	if _built:
		_settings_changed(geometry)

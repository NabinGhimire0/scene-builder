class_name WaterBody
extends WaterFeature
## Still water: a pond, lake or pool, in a natural, round or rectangular shape.

const SHAPES: PackedStringArray = ["Natural", "Round", "Rectangle"]

@export_enum("Natural", "Round", "Rectangle") var outline := "Natural":
	set(v):
		outline = v if SHAPES.has(v) else "Natural"
		_changed(true)
@export var width := 10.0:
	set(v):
		width = clampf(v, 1.0, 400.0)
		_changed(true)
@export var length := 8.0:
	set(v):
		length = clampf(v, 1.0, 400.0)
		_changed(true)


func inspector_title() -> String:
	return "Pond / lake"


func _shape_fields() -> Array:
	return [
		{"type": "option", "property": "outline", "label": "Shape", "items": SHAPES},
		{"type": "float", "property": "width", "label": "Width", "min": 1.0, "max": 400.0, "step": 0.1, "suffix": " m"},
		{"type": "float", "property": "length", "label": "Length", "min": 1.0, "max": 400.0, "step": 0.1, "suffix": " m"},
		{"type": "int", "property": "variation", "label": "Shape variation", "min": 0, "max": 99, "step": 1, "suffix": "",
			"hint": "Try other natural outlines"},
	]


func _shape_id() -> int:
	return SHAPES.find(outline)


func _size_metres() -> Vector2:
	return Vector2(width, length)


func _water_mesh() -> ArrayMesh:
	# Tessellated so small waves can move the surface; ~0.5 m cells, capped.
	var nx := clampi(int(width / 0.5), 8, 160)
	var nz := clampi(int(length / 0.5), 8, 160)
	return WaterStyle.grid_mesh(
		WaterStyle.spaced(-width * 0.5, width * 0.5, nx + 1),
		WaterStyle.spaced(-length * 0.5, length * 0.5, nz + 1))


func _bank_mesh() -> ArrayMesh:
	var margin := bank_width * 1.3
	return WaterStyle.grid_mesh(
		WaterStyle.spaced(-width * 0.5 - margin, width * 0.5 + margin, 2),
		WaterStyle.spaced(-length * 0.5 - margin, length * 0.5 + margin, 2))

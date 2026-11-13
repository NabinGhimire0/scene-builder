class_name Coast
extends WaterFeature
## The sea meeting the land: a beach along the line where you drop it, with the
## sea stretching away to the horizon (local +Z), rolling waves and lines of
## foam breaking onto the sand.

@export var shore_length := 1600.0:
	set(v):
		shore_length = clampf(v, 50.0, 4000.0)
		_changed(true)
@export var sea_reach := 900.0:
	set(v):
		sea_reach = clampf(v, 40.0, 4000.0)
		_changed(true)
@export var breakers := 0.8:
	set(v):
		breakers = clampf(v, 0.0, 1.0)
		_changed()
@export var shelf_width := 40.0:
	set(v):
		shelf_width = clampf(v, 2.0, 300.0)
		_changed()


func inspector_title() -> String:
	return "Sea & beach"


func _shape_fields() -> Array:
	return [
		{"type": "note", "label": "The beach runs along where you placed it; the sea stretches away in front. Rotate it (R while placing) to face the sea where you want."},
		{"type": "float", "property": "breakers", "label": "Breaking waves", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": "",
			"hint": "Lines of foam rolling onto the beach"},
		{"type": "float", "property": "shelf_width", "label": "Shallow water width", "min": 2.0, "max": 300.0, "step": 1.0, "suffix": " m",
			"hint": "How far out the water stays shallow and turquoise"},
		{"type": "float", "property": "shore_length", "label": "Beach length", "min": 50.0, "max": 4000.0, "step": 10.0, "suffix": " m"},
		{"type": "float", "property": "sea_reach", "label": "Sea size", "min": 40.0, "max": 4000.0, "step": 10.0, "suffix": " m"},
		{"type": "int", "property": "variation", "label": "Coastline variation", "min": 0, "max": 99, "step": 1, "suffix": ""},
	]


func _shape_id() -> int:
	return 4


func _size_metres() -> Vector2:
	return Vector2(shore_length, sea_reach)


func _shelf() -> float:
	return shelf_width


func _shore_waves() -> float:
	return breakers


func _simple_collider() -> bool:
	return true


func _collider_box(_water_mesh: ArrayMesh) -> AABB:
	# Starts a little out to sea, so things can still be put on the beach.
	return AABB(Vector3(-shore_length * 0.5, 0.0, 8.0), Vector3(shore_length, 0.0, maxf(sea_reach - 8.0, 1.0)))


func _water_mesh() -> ArrayMesh:
	# Dense near the beach and the middle, coarse towards the horizon.
	return WaterStyle.grid_mesh(
		WaterStyle.focused(-shore_length * 0.5, shore_length * 0.5, 0.0, 201, 2.2),
		WaterStyle.focused(-12.0, sea_reach, 0.0, 161, 2.2))


func _bank_mesh() -> ArrayMesh:
	var land := bank_width * 1.3 + 7.0
	return WaterStyle.grid_mesh(
		WaterStyle.spaced(-shore_length * 0.5, shore_length * 0.5, 2),
		WaterStyle.spaced(-land, 20.0, 2))

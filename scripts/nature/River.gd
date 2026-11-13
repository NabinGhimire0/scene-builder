class_name River
extends WaterFeature
## Flowing water along a winding path: a river or a stream. The water flows
## along the river's length (towards the end marked by the arrow when you rotate
## it: local +Z). Its ripples and foam follow every bend.

@export var width := 6.0:
	set(v):
		width = clampf(v, 0.3, 120.0)
		_changed(true)
@export var length := 60.0:
	set(v):
		length = clampf(v, 4.0, 1500.0)
		_changed(true)
## How many S-bends along the length.
@export var bends := 2.0:
	set(v):
		bends = clampf(v, 0.0, 12.0)
		_changed(true)
## 0 straight … 1 strongly winding.
@export var winding := 0.5:
	set(v):
		winding = clampf(v, 0.0, 1.0)
		_changed(true)
## Metres per second.
@export var flow := 1.2:
	set(v):
		flow = clampf(v, 0.0, 8.0)
		_changed()
@export var reverse_flow := false:
	set(v):
		reverse_flow = v
		_changed()


var _centres := PackedVector3Array()
var _distances := PackedFloat32Array()


func inspector_title() -> String:
	return "River"


func _shape_fields() -> Array:
	return [
		{"type": "float", "property": "width", "label": "Width", "min": 0.3, "max": 120.0, "step": 0.1, "suffix": " m"},
		{"type": "float", "property": "length", "label": "Length", "min": 4.0, "max": 1500.0, "step": 1.0, "suffix": " m"},
		{"type": "float", "property": "bends", "label": "Bends", "min": 0.0, "max": 12.0, "step": 0.1, "suffix": ""},
		{"type": "float", "property": "winding", "label": "Winding", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": "",
			"hint": "0 = straight canal, 1 = strongly winding"},
		{"type": "int", "property": "variation", "label": "Path variation", "min": 0, "max": 99, "step": 1, "suffix": ""},
		{"type": "float", "property": "flow", "label": "Flow speed", "min": 0.0, "max": 8.0, "step": 0.05, "suffix": " m/s",
			"hint": "Fast water gets white rapids"},
		{"type": "bool", "property": "reverse_flow", "label": "Flow the other way"},
	]


func _shape_id() -> int:
	return 3


func _size_metres() -> Vector2:
	return Vector2(width, length)


func _shelf() -> float:
	return clampf(width * 0.25, 0.15, 12.0)


func _flow_speed() -> float:
	return -flow if reverse_flow else flow


func _water_mesh() -> ArrayMesh:
	var across := clampi(int(width / 0.75) + 2, 3, 24)
	return _ribbon(0.0, WaterStyle.spaced(-width * 0.5, width * 0.5, across))


func _bank_mesh() -> ArrayMesh:
	var reach := width * 0.5 + bank_width * 1.3
	return _ribbon(bank_width * 1.3, WaterStyle.spaced(-reach, reach, 4))


## Samples the centre line from -[param extend] to length + [param extend]
## metres and builds a ribbon with the given cross-section [param offsets].
func _ribbon(extend: float, offsets: PackedFloat32Array) -> ArrayMesh:
	var half_reach := absf(offsets[0])
	var k := TAU * bends / length
	var amplitude := winding * length * 0.12
	if k > 0.0:
		# Keep bends wider than the river so the inside of a bend never folds.
		amplitude = minf(amplitude, 0.8 / (k * k * maxf(half_reach, 0.1)))
	var phase := float(variation) * 1.37
	var steps := clampi(int((length + extend * 2.0) / 0.6), 16, 2000)
	var centres := PackedVector3Array()
	var directions := PackedVector3Array()
	var distances := PackedFloat32Array()
	for i in steps + 1:
		var s := lerpf(-extend, length + extend, float(i) / float(steps))
		var z := s - length * 0.5
		var x := amplitude * sin(k * s + phase) - amplitude * sin(k * length * 0.5 + phase)
		var dx := amplitude * k * cos(k * s + phase)
		centres.append(Vector3(x, 0.0, z))
		directions.append(Vector3(dx, 0.0, 1.0).normalized())
		distances.append(s)
	# Use the true distance along the curve so ripples don't stretch in bends.
	var travelled := -extend
	for i in range(1, centres.size()):
		travelled += centres[i].distance_to(centres[i - 1])
		distances[i] = travelled
	var scale_fix := (length + extend * 2.0) / maxf(travelled + extend, 0.001)
	for i in distances.size():
		distances[i] = -extend + (distances[i] + extend) * scale_fix
	if extend == 0.0:
		_centres = centres
		_distances = distances
	return WaterStyle.ribbon_mesh(centres, directions, distances, offsets)


## Edge distance for a winding river: measured from the nearest point of the
## centre line (searched near the matching length position for speed).
func edge_at_local(p: Vector2) -> float:
	var count := _centres.size()
	if count < 2:
		return super.edge_at_local(p)
	var guess := clampi(roundi((p.y + length * 0.5) / length * float(count - 1)), 0, count - 1)
	var reach := clampi(int(winding * length * 0.25 / maxf(length / float(count), 0.01)) + 8, 8, count)
	var best := -1
	var best_d := INF
	for i in range(maxi(0, guess - reach), mini(count, guess + reach + 1)):
		var c := _centres[i]
		var d := Vector2(c.x - p.x, c.z - p.y).length_squared()
		if d < best_d:
			best_d = d
			best = i
	var along := _distances[best]
	if p.y < _centres[0].z:
		along -= _centres[0].z - p.y
	elif p.y > _centres[count - 1].z:
		along += p.y - _centres[count - 1].z
	return water_edge(Vector2(sqrt(best_d), along), 3, _size_metres(), 0.0)

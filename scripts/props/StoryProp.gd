class_name StoryProp
extends ProceduralProp
## Furniture and set pieces for the short-film look (Scene Builder 1.27): soft,
## slightly simplified everyday things in gentle colours - kitchens, cafés, a
## barbershop, a bedroom, an apartment hallway, a rooftop, a bus stop and a car.
## Everything is built in code (no files), sits on the floor at its origin and
## faces +Z (a chair's seat looks towards +Z, a wall piece's front is +Z).

const KINDS := {
	# home
	"Kitchen counter": {"color": Color(0.62, 0.74, 0.7), "accent": Color(0.93, 0.9, 0.84), "width": 2.6},
	"Fridge": {"color": Color(0.93, 0.9, 0.82), "accent": Color(0.5, 0.52, 0.55)},
	"Dining table": {"color": Color(0.62, 0.45, 0.3), "accent": Color(0.95, 0.94, 0.9)},
	"Dining chair": {"color": Color(0.6, 0.44, 0.3)},
	"Pendant lamp": {"color": Color(0.85, 0.68, 0.45), "accent": Color(1.0, 0.82, 0.58)},
	"Wall clock": {"color": Color(0.96, 0.95, 0.92), "accent": Color(0.15, 0.15, 0.17)},
	"Window": {"color": Color(0.16, 0.2, 0.32), "accent": Color(0.93, 0.92, 0.88), "width": 1.3},
	"Picture frame": {"color": Color(0.85, 0.6, 0.45), "accent": Color(0.25, 0.22, 0.2)},
	"Potted plant": {"color": Color(0.32, 0.5, 0.32), "accent": Color(0.85, 0.55, 0.42)},
	"Door": {"color": Color(0.72, 0.52, 0.38), "accent": Color(0.93, 0.92, 0.88)},
	"Wall shelf": {"color": Color(0.6, 0.45, 0.32), "accent": Color(0.8, 0.5, 0.4), "width": 1.2},
	"Rug": {"color": Color(0.72, 0.42, 0.36), "accent": Color(0.93, 0.85, 0.7), "width": 2.4},
	"Couch": {"color": Color(0.38, 0.46, 0.58), "accent": Color(0.9, 0.82, 0.62), "width": 2.0},
	"Bed": {"color": Color(0.52, 0.6, 0.72), "accent": Color(0.95, 0.94, 0.9)},
	"Desk": {"color": Color(0.7, 0.55, 0.4), "accent": Color(0.25, 0.26, 0.3)},
	"Wardrobe": {"color": Color(0.82, 0.75, 0.64), "accent": Color(0.4, 0.33, 0.27)},
	"Bedside table": {"color": Color(0.7, 0.55, 0.4), "accent": Color(1.0, 0.85, 0.6)},
	"Poster": {"color": Color(0.95, 0.66, 0.4), "accent": Color(0.28, 0.4, 0.6)},
	# café
	"Cafe counter": {"color": Color(0.48, 0.34, 0.24), "accent": Color(0.92, 0.9, 0.86), "width": 3.2},
	"Menu board": {"color": Color(0.16, 0.18, 0.17), "accent": Color(0.95, 0.94, 0.88), "label": "MENU\nMilk tea    60\nCoffee       90\nMomo        150\nCake          80"},
	"Cafe table": {"color": Color(0.9, 0.88, 0.84), "accent": Color(0.22, 0.22, 0.24)},
	"Cafe chair": {"color": Color(0.3, 0.42, 0.38)},
	"Bar stool": {"color": Color(0.85, 0.55, 0.35), "accent": Color(0.25, 0.25, 0.27)},
	# barbershop
	"Barber chair": {"color": Color(0.62, 0.2, 0.18), "accent": Color(0.78, 0.78, 0.8)},
	"Barber mirror": {"color": Color(0.7, 0.8, 0.86), "accent": Color(0.55, 0.42, 0.3)},
	"Waiting chairs": {"color": Color(0.85, 0.78, 0.62), "accent": Color(0.3, 0.3, 0.32)},
	"Photo wall": {"color": Color(0.72, 0.58, 0.42), "accent": Color(0.97, 0.96, 0.94), "width": 2.2},
	"Barber pole": {"color": Color(0.85, 0.18, 0.18), "accent": Color(0.2, 0.32, 0.7)},
	# hallway
	"Apartment door": {"color": Color(0.55, 0.4, 0.3), "accent": Color(0.85, 0.75, 0.45), "label": "12"},
	"Elevator": {"color": Color(0.7, 0.72, 0.74), "accent": Color(1.0, 0.65, 0.25), "label": "5"},
	"Wall lamp": {"color": Color(0.95, 0.88, 0.75), "accent": Color(1.0, 0.82, 0.58)},
	"Notice board": {"color": Color(0.72, 0.58, 0.42), "accent": Color(0.95, 0.94, 0.9), "label": "ROOFTOP\nSUNDAY 6 PM"},
	# rooftop
	"Roof deck": {"color": Color(0.46, 0.43, 0.42), "accent": Color(0.36, 0.34, 0.34), "width": 16.0},
	"Parapet": {"color": Color(0.62, 0.5, 0.45), "accent": Color(0.75, 0.7, 0.66), "width": 6.0},
	"Water tower": {"color": Color(0.5, 0.36, 0.28), "accent": Color(0.3, 0.3, 0.32)},
	"String lights": {"color": Color(0.2, 0.2, 0.22), "accent": Color(1.0, 0.86, 0.6), "width": 8.0},
	"Picnic table": {"color": Color(0.62, 0.48, 0.34)},
	"Planter": {"color": Color(0.55, 0.42, 0.32), "accent": Color(0.34, 0.52, 0.3), "width": 1.4},
	"Roof door": {"color": Color(0.6, 0.48, 0.42), "accent": Color(0.4, 0.42, 0.45)},
	"Skyline": {"color": Color(0.32, 0.3, 0.36), "accent": Color(1.0, 0.8, 0.5), "width": 60.0},
	# street
	"Bus shelter": {"color": Color(0.25, 0.27, 0.3), "accent": Color(0.7, 0.8, 0.86)},
	"Shelter bench": {"color": Color(0.45, 0.47, 0.5)},
	"Bus sign": {"color": Color(0.12, 0.12, 0.14), "accent": Color(1.0, 0.7, 0.2), "label": "NEXT BUS\n14 MIN"},
	"Shop front": {"color": Color(0.6, 0.36, 0.28), "accent": Color(0.25, 0.45, 0.42), "label": "BAKERY", "width": 6.0},
	"Pavement": {"color": Color(0.62, 0.62, 0.6), "accent": Color(0.3, 0.3, 0.32), "width": 30.0},
	# car
	"Car body": {"color": Color(0.3, 0.38, 0.55), "accent": Color(0.2, 0.2, 0.22)},
	"Car seat": {"color": Color(0.3, 0.3, 0.33)},
}

## Changing the object resets its colours, width and words to that object's own.
@export var kind := "Dining chair":
	set(v):
		kind = v if KINDS.has(v) else "Dining chair"
		var d: Dictionary = KINDS[kind]
		color = Color(d.get("color", Color.WHITE))
		accent = Color(d.get("accent", Color.WHITE))
		width = float(d.get("width", 1.0))
		label = str(d.get("label", ""))
		_changed(true)
@export var color := Color(0.6, 0.44, 0.3):
	set(v):
		color = Color(v.r, v.g, v.b, 1.0)
		_changed(true)
@export var accent := Color(1, 1, 1):
	set(v):
		accent = Color(v.r, v.g, v.b, 1.0)
		_changed(true)
## Width (counters, shelves, walls, lights, backdrops).
@export var width := 1.0:
	set(v):
		width = clampf(v, 0.1, 200.0)
		_changed(true)
## Words on signs, boards and door plates ("|" or a new line between lines).
@export var label := "":
	set(v):
		label = v
		_changed(true)
## Lights in this piece are on.
@export var lit := true:
	set(v):
		lit = v
		_changed(true)

var _parts: Array[Node] = []
var _mats := {}


func inspector_title() -> String:
	return kind


func inspector_fields() -> Array:
	return [
		{"type": "option", "property": "kind", "label": "Object", "items": PackedStringArray(KINDS.keys())},
		{"type": "color", "property": "color", "label": "Colour"},
		{"type": "color", "property": "accent", "label": "Second colour"},
		{"type": "float", "property": "width", "label": "Width", "min": 0.1, "max": 200.0, "step": 0.1, "suffix": " m"},
		{"type": "text", "property": "label", "label": "Words (signs, boards, door numbers)"},
		{"type": "bool", "property": "lit", "label": "Lights on"},
	]


## Height of the solid part a camera can't be inside (counters and tables: their top;
## what stands on them - a coffee machine, a lamp - doesn't count).
func solid_height() -> float:
	match kind:
		"Cafe counter":
			return 1.07
		"Dining table", "Cafe table", "Picnic table":
			return 0.78
		"Desk":
			return 0.76
		"Bedside table":
			return 0.5
	return 99.0


func get_custom_state() -> Dictionary:
	return {"kind": kind, "color": [color.r, color.g, color.b, color.a], "accent": [accent.r, accent.g, accent.b, accent.a],
		"width": width, "label": label, "lit": lit}


func set_custom_state(state: Dictionary) -> void:
	if state.has("kind"):
		kind = str(state["kind"])
	for key in ["color", "accent"]:
		var c: Variant = state.get(key)
		if c is Array and (c as Array).size() >= 3:
			set(key, Color(float(c[0]), float(c[1]), float(c[2])))
	if state.has("width"):
		width = float(state["width"])
	if state.has("label"):
		label = str(state["label"])
	if state.has("lit"):
		lit = bool(state["lit"])


func _build() -> void:
	_rebuild()


func _settings_changed(_geometry: bool) -> void:
	_rebuild()


# --- helpers ----------------------------------------------------------------------

func _main() -> Color:
	return color


func _second() -> Color:
	return accent


func _w() -> float:
	return width


func _text() -> String:
	return label.replace("|", "\n")


func _mat(c: Color, rough: float = 0.82, glow: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var key := "%s/%.2f/%.2f/%.2f" % [c.to_html(), rough, glow, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if c.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


func _add(mesh: Mesh, at: Vector3, material: Material, rot: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.rotation_degrees = rot
	mi.material_override = material
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_parts.append(mi)
	return mi


func _box(size: Vector3, at: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, rough: float = 0.82) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(mesh, at, _mat(c, rough), rot)


func _cyl(top: float, bottom: float, h: float, at: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, sides: int = 20) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = h
	mesh.radial_segments = sides
	mesh.rings = 1
	return _add(mesh, at, _mat(c), rot)


func _ball(r: float, at: Vector3, c: Color, scale_: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mi := _add(mesh, at, _mat(c))
	mi.scale = scale_
	return mi


func _glow(size: Vector3, at: Vector3, c: Color, energy: float = 2.0, sphere: bool = false) -> MeshInstance3D:
	var mesh: Mesh
	if sphere:
		var s := SphereMesh.new()
		s.radius = size.x
		s.height = size.x * 2.0
		mesh = s
	else:
		var b := BoxMesh.new()
		b.size = size
		mesh = b
	return _add(mesh, at, _mat(c, 0.5, energy if lit else 0.0), Vector3.ZERO, false)


func _light(at: Vector3, c: Color, energy: float, reach: float, shadows: bool = false) -> void:
	if not lit:
		return
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = c
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.shadow_enabled = shadows
	light.light_specular = 0.3
	add_child(light)
	_parts.append(light)


func _words(text: String, at: Vector3, size: float, c: Color, rot: Vector3 = Vector3.ZERO, glow: bool = false) -> void:
	if text.is_empty():
		return
	var l := Label3D.new()
	l.text = text
	l.position = at
	l.rotation_degrees = rot
	l.pixel_size = size / 64.0
	l.font_size = 64
	l.modulate = c
	l.outline_size = 0
	l.shaded = not glow
	l.double_sided = false
	l.font = load("res://assets/fonts/PatrickHand-Regular.ttf")
	add_child(l)
	_parts.append(l)


func _legs(w: float, d: float, h: float, r: float, c: Color, inset: float = 0.04) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_cyl(r, r, h, Vector3(sx * (w * 0.5 - inset), h * 0.5, sz * (d * 0.5 - inset)), c, Vector3.ZERO, 8)


# --- build ----------------------------------------------------------------------

func _rebuild() -> void:
	for part in _parts:
		part.queue_free()
	_parts.clear()
	_mats.clear()
	var m := _main()
	var a := _second()
	var w := _w()
	match kind:
		"Kitchen counter":
			_kitchen_counter(m, a, w)
		"Fridge":
			_box(Vector3(0.72, 1.85, 0.68), Vector3(0, 0.925, 0), m, Vector3.ZERO, 0.45)
			_box(Vector3(0.7, 0.012, 0.01), Vector3(0, 1.22, 0.345), m.darkened(0.25))
			for y in [0.85, 1.55]:
				_box(Vector3(0.03, 0.35, 0.04), Vector3(0.28, y, 0.36), a, Vector3.ZERO, 0.3)
			var dots := [Color(0.9, 0.35, 0.3), Color(0.3, 0.6, 0.85), Color(0.95, 0.8, 0.3)]
			for i in 3:
				_box(Vector3(0.06, 0.06, 0.01), Vector3(-0.2 + i * 0.12, 1.5 - i * 0.07, 0.346), dots[i])
			_box(Vector3(0.14, 0.18, 0.004), Vector3(-0.05, 1.32, 0.346), Color(0.98, 0.95, 0.7), Vector3(0, 0, 4))
		"Dining table":
			_box(Vector3(1.4, 0.05, 0.85), Vector3(0, 0.745, 0), m)
			_legs(1.4, 0.85, 0.72, 0.03, m.darkened(0.15), 0.08)
			for x in [-0.35, 0.35]:
				_cyl(0.12, 0.12, 0.015, Vector3(x, 0.78, 0.18), a)
			_cyl(0.05, 0.06, 0.18, Vector3(0, 0.86, -0.15), Color(0.5, 0.65, 0.75))
			_ball(0.07, Vector3(0, 0.98, -0.15), Color(0.95, 0.75, 0.3))
		"Dining chair":
			_chair(m, 0.44, 0.45)
		"Pendant lamp":
			_cyl(0.006, 0.006, 0.9, Vector3(0, 2.35, 0), Color(0.15, 0.15, 0.15), Vector3.ZERO, 6)
			_cyl(0.07, 0.26, 0.22, Vector3(0, 1.8, 0), m)
			_glow(Vector3(0.07, 0, 0), Vector3(0, 1.72, 0), a, 4.0, true)
			_light(Vector3(0, 1.6, 0), a, 1.6, 6.0, true)
		"Wall clock":
			_cyl(0.17, 0.17, 0.04, Vector3(0, 2.05, 0.02), m, Vector3(90, 0, 0), 28)
			_cyl(0.18, 0.18, 0.03, Vector3(0, 2.05, 0.0), a, Vector3(90, 0, 0), 28)
			_box(Vector3(0.012, 0.11, 0.01), Vector3(0, 2.1, 0.05), a, Vector3(0, 0, -30))
			_box(Vector3(0.01, 0.14, 0.01), Vector3(0.03, 2.05, 0.05), a, Vector3(0, 0, 70))
		"Window":
			_window(m, a, w)
		"Picture frame":
			_box(Vector3(0.62, 0.48, 0.03), Vector3(0, 1.6, 0.015), a)
			_box(Vector3(0.54, 0.4, 0.01), Vector3(0, 1.6, 0.032), m.lightened(0.3))
			_ball(0.08, Vector3(0.12, 1.66, 0.04), m, Vector3(1, 1, 0.1))
			_box(Vector3(0.4, 0.12, 0.01), Vector3(-0.04, 1.48, 0.038), m.darkened(0.25), Vector3(0, 0, 8))
		"Potted plant":
			_cyl(0.16, 0.12, 0.3, Vector3(0, 0.15, 0), a)
			for i in 9:
				var ang := TAU * float(i) / 9.0
				var leaf := _ball(0.13, Vector3(cos(ang) * 0.14, 0.45 + float(i % 3) * 0.12, sin(ang) * 0.14), m.lightened(0.1 * float(i % 2)), Vector3(0.55, 1.4, 0.3))
				leaf.rotation_degrees = Vector3(0, -rad_to_deg(ang), 25)
		"Door":
			_box(Vector3(1.0, 2.15, 0.08), Vector3(0, 1.075, 0), a)
			_box(Vector3(0.86, 2.05, 0.05), Vector3(0, 1.025, 0.03), m)
			for y in [0.55, 1.45]:
				_box(Vector3(0.62, 0.6, 0.01), Vector3(0, y, 0.058), m.darkened(0.08))
			_ball(0.035, Vector3(0.33, 1.0, 0.08), Color(0.85, 0.72, 0.4))
		"Wall shelf":
			_box(Vector3(w, 0.03, 0.24), Vector3(0, 1.55, 0.12), m)
			var jar_colors := [a, Color(0.95, 0.85, 0.5), Color(0.5, 0.7, 0.6), Color(0.9, 0.9, 0.86)]
			var x := -w * 0.5 + 0.12
			var k := 0
			while x < w * 0.5 - 0.1:
				var tall := 0.12 + float(k % 3) * 0.05
				_cyl(0.045, 0.045, tall, Vector3(x, 1.565 + tall * 0.5, 0.12), jar_colors[k % 4])
				x += 0.14
				k += 1
		"Rug":
			_box(Vector3(w, 0.012, w * 0.65), Vector3(0, 0.006, 0), m, Vector3.ZERO, 1.0)
			_box(Vector3(w * 0.8, 0.014, w * 0.65 * 0.75), Vector3(0, 0.007, 0), a, Vector3.ZERO, 1.0)
			_box(Vector3(w * 0.62, 0.016, w * 0.65 * 0.55), Vector3(0, 0.008, 0), m.darkened(0.12), Vector3.ZERO, 1.0)
		"Couch":
			_box(Vector3(w, 0.42, 0.85), Vector3(0, 0.21, 0), m)
			_box(Vector3(w, 0.5, 0.2), Vector3(0, 0.6, -0.33), m)
			for sx in [-1.0, 1.0]:
				_box(Vector3(0.16, 0.6, 0.85), Vector3(sx * (w * 0.5 - 0.08), 0.3, 0), m.darkened(0.08))
			_box(Vector3(0.4, 0.32, 0.12), Vector3(-w * 0.3, 0.6, -0.18), a, Vector3(-12, 8, 0))
		"Bed":
			_box(Vector3(1.5, 0.3, 2.1), Vector3(0, 0.15, 0), Color(0.6, 0.46, 0.34))
			_box(Vector3(1.45, 0.2, 2.0), Vector3(0, 0.4, 0), a)
			_box(Vector3(1.5, 0.08, 1.35), Vector3(0, 0.53, 0.33), m)
			_box(Vector3(1.55, 0.85, 0.08), Vector3(0, 0.55, -1.06), Color(0.6, 0.46, 0.34))
			for sx in [-0.35, 0.35]:
				_box(Vector3(0.6, 0.14, 0.38), Vector3(sx, 0.57, -0.75), a.darkened(0.04))
		"Desk":
			_box(Vector3(1.3, 0.04, 0.65), Vector3(0, 0.74, 0), m)
			_box(Vector3(0.42, 0.7, 0.6), Vector3(0.42, 0.37, 0), m.darkened(0.08))
			_legs(1.3, 0.65, 0.72, 0.022, m.darkened(0.2), 0.05)
			# laptop
			_box(Vector3(0.36, 0.015, 0.25), Vector3(-0.15, 0.77, 0.06), a)
			var screen := _box(Vector3(0.36, 0.24, 0.012), Vector3(-0.15, 0.89, -0.07), a, Vector3(-12, 0, 0))
			screen.name = "Screen"
			_glow(Vector3(0.32, 0.2, 0.004), Vector3(-0.15, 0.89, -0.062), Color(0.62, 0.8, 1.0), 1.8).rotation_degrees = Vector3(-12, 0, 0)
			# lamp and mug
			_cyl(0.06, 0.07, 0.02, Vector3(0.45, 0.77, -0.15), Color(0.2, 0.2, 0.22))
			_cyl(0.012, 0.012, 0.35, Vector3(0.45, 0.94, -0.15), Color(0.2, 0.2, 0.22))
			_cyl(0.05, 0.1, 0.12, Vector3(0.45, 1.13, -0.1), Color(0.95, 0.8, 0.5), Vector3(25, 0, 0))
			_light(Vector3(0.45, 1.0, 0.0), Color(1.0, 0.82, 0.58), 0.5, 2.2)
			_cyl(0.035, 0.035, 0.09, Vector3(0.22, 0.805, 0.15), Color(0.9, 0.45, 0.35))
		"Wardrobe":
			_box(Vector3(1.2, 2.0, 0.6), Vector3(0, 1.0, 0), m)
			_box(Vector3(0.012, 1.9, 0.01), Vector3(0, 1.0, 0.305), m.darkened(0.25))
			for sx in [-0.06, 0.06]:
				_box(Vector3(0.025, 0.25, 0.03), Vector3(sx, 1.05, 0.32), a)
		"Bedside table":
			_box(Vector3(0.45, 0.5, 0.4), Vector3(0, 0.25, 0), m)
			_box(Vector3(0.38, 0.012, 0.01), Vector3(0, 0.3, 0.205), m.darkened(0.25))
			_cyl(0.05, 0.07, 0.25, Vector3(0, 0.62, 0), Color(0.85, 0.82, 0.78))
			_cyl(0.09, 0.14, 0.18, Vector3(0, 0.82, 0), a)
			_light(Vector3(0, 0.8, 0.1), a, 0.6, 2.5)
		"Poster":
			_box(Vector3(0.55, 0.78, 0.01), Vector3(0, 1.6, 0.005), m)
			_ball(0.14, Vector3(0, 1.72, 0.012), Color(0.98, 0.92, 0.75), Vector3(1, 1, 0.05))
			_box(Vector3(0.45, 0.25, 0.006), Vector3(0, 1.38, 0.012), a)
		"Cafe counter":
			_cafe_counter(m, a, w)
		"Menu board":
			_box(Vector3(1.5, 0.95, 0.04), Vector3(0, 2.0, 0.02), Color(0.45, 0.32, 0.22))
			_box(Vector3(1.4, 0.85, 0.02), Vector3(0, 2.0, 0.045), m, Vector3.ZERO, 0.95)
			_words(_text(), Vector3(0, 2.0, 0.06), 0.085, a)
		"Cafe table":
			_cyl(0.36, 0.36, 0.035, Vector3(0, 0.74, 0), m, Vector3.ZERO, 28)
			_cyl(0.025, 0.025, 0.72, Vector3(0, 0.37, 0), a, Vector3.ZERO, 8)
			_cyl(0.22, 0.24, 0.03, Vector3(0, 0.015, 0), a)
			_cyl(0.045, 0.04, 0.08, Vector3(0.12, 0.8, 0.06), Color(0.96, 0.95, 0.92))
		"Cafe chair":
			_cyl(0.21, 0.21, 0.04, Vector3(0, 0.45, 0), m, Vector3.ZERO, 20)
			_legs(0.34, 0.34, 0.44, 0.012, Color(0.2, 0.2, 0.22), 0.0)
			_box(Vector3(0.36, 0.3, 0.025), Vector3(0, 0.68, -0.18), m, Vector3(-8, 0, 0))
		"Bar stool":
			_cyl(0.19, 0.19, 0.06, Vector3(0, 0.72, 0), m)
			_legs(0.3, 0.3, 0.7, 0.014, a, 0.0)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.17
			ring.outer_radius = 0.185
			_add(ring, Vector3(0, 0.28, 0), _mat(a))
		"Barber chair":
			_barber_chair(m, a)
		"Barber mirror":
			_box(Vector3(1.05, 1.15, 0.05), Vector3(0, 1.6, 0.025), a)
			var glass := _box(Vector3(0.95, 1.05, 0.01), Vector3(0, 1.6, 0.055), m, Vector3.ZERO, 0.06)
			glass.material_override = _mat(m, 0.06, 0.15, 0.3)
			_box(Vector3(1.1, 0.04, 0.3), Vector3(0, 0.95, 0.15), a)
			var bottles := [Color(0.3, 0.55, 0.75), Color(0.9, 0.45, 0.3), Color(0.95, 0.9, 0.8), Color(0.35, 0.6, 0.4)]
			for i in 4:
				_cyl(0.035, 0.04, 0.14 + 0.03 * float(i % 2), Vector3(-0.38 + i * 0.12, 1.04, 0.16), bottles[i])
			_cyl(0.05, 0.05, 0.08, Vector3(0.3, 1.01, 0.14), Color(0.92, 0.92, 0.9))
		"Waiting chairs":
			_box(Vector3(1.6, 0.07, 0.48), Vector3(0, 0.44, 0), m)
			_box(Vector3(1.6, 0.42, 0.06), Vector3(0, 0.7, -0.22), m, Vector3(-6, 0, 0))
			for x in [-0.53, 0.0, 0.53]:
				_box(Vector3(0.012, 0.42, 0.06), Vector3(x + 0.265 if x < 0.5 else x - 0.265, 0.7, -0.19), m.darkened(0.2))
			for x in [-0.75, 0.75]:
				_box(Vector3(0.04, 0.42, 0.42), Vector3(x, 0.21, 0), a)
		"Photo wall":
			_photo_wall(m, a, w)
		"Barber pole":
			_cyl(0.08, 0.08, 0.06, Vector3(0, 1.3, 0.1), Color(0.8, 0.8, 0.82))
			for i in 10:
				_cyl(0.065, 0.065, 0.06, Vector3(0, 1.36 + i * 0.06, 0.1), [m, Color(0.97, 0.97, 0.95), a][i % 3])
			_cyl(0.08, 0.08, 0.06, Vector3(0, 1.98, 0.1), Color(0.8, 0.8, 0.82))
		"Apartment door":
			_box(Vector3(1.05, 2.2, 0.06), Vector3(0, 1.1, 0), Color(0.88, 0.86, 0.8))
			_box(Vector3(0.92, 2.08, 0.05), Vector3(0, 1.04, 0.03), m)
			_ball(0.035, Vector3(0.35, 1.0, 0.08), a)
			_box(Vector3(0.2, 0.12, 0.01), Vector3(0, 1.7, 0.06), a)
			_words(_text(), Vector3(0, 1.7, 0.067), 0.09, Color(0.15, 0.13, 0.1))
			_box(Vector3(0.75, 0.012, 0.45), Vector3(0, 0.006, 0.3), Color(0.55, 0.38, 0.28), Vector3.ZERO, 1.0)
		"Elevator":
			_box(Vector3(1.5, 2.45, 0.08), Vector3(0, 1.225, 0), Color(0.55, 0.52, 0.5))
			for sx in [-1.0, 1.0]:
				var door := _box(Vector3(0.58, 2.1, 0.04), Vector3(sx * 0.295, 1.05, 0.05), m, Vector3.ZERO, 0.25)
				door.material_override = _mat(m, 0.25, 0.0, 0.6)
			_box(Vector3(0.36, 0.16, 0.02), Vector3(0, 2.28, 0.05), Color(0.1, 0.1, 0.12))
			_words("▲ " + _text(), Vector3(0, 2.28, 0.062), 0.1, a, Vector3.ZERO, true)
			_box(Vector3(0.1, 0.22, 0.02), Vector3(0.95, 1.2, 0.05), Color(0.6, 0.6, 0.62))
			_glow(Vector3(0.035, 0, 0), Vector3(0.95, 1.25, 0.065), a, 3.0, true)
		"Wall lamp":
			_box(Vector3(0.12, 0.2, 0.04), Vector3(0, 1.9, 0.02), Color(0.3, 0.3, 0.32))
			_cyl(0.08, 0.06, 0.18, Vector3(0, 1.95, 0.12), m)
			_light(Vector3(0, 1.95, 0.45), a, 0.4, 4.0)
		"Notice board":
			_box(Vector3(1.0, 0.7, 0.03), Vector3(0, 1.5, 0.015), m, Vector3.ZERO, 1.0)
			var papers := [Color(0.98, 0.98, 0.96), Color(1.0, 0.93, 0.6), Color(0.85, 0.92, 1.0), Color(1.0, 0.82, 0.82)]
			for i in 4:
				_box(Vector3(0.2, 0.26, 0.004), Vector3(-0.32 + i * 0.21, 1.42 + float(i % 2) * 0.1, 0.034), papers[i], Vector3(0, 0, -4 + 3 * i))
			_box(Vector3(0.38, 0.22, 0.004), Vector3(0.22, 1.66, 0.036), a)
			_words(_text(), Vector3(0.22, 1.66, 0.04), 0.045, Color(0.85, 0.3, 0.25))
		"Roof deck":
			_box(Vector3(w, 0.06, w), Vector3(0, 0.03, 0), m, Vector3.ZERO, 0.95)
			var line := -w * 0.5
			while line < w * 0.5:
				_box(Vector3(0.03, 0.004, w), Vector3(line, 0.062, 0), a)
				line += 1.8
		"Parapet":
			_box(Vector3(w, 1.0, 0.3), Vector3(0, 0.5, 0), m)
			_box(Vector3(w + 0.1, 0.08, 0.4), Vector3(0, 1.04, 0), a)
		"Water tower":
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					_cyl(0.05, 0.05, 2.4, Vector3(sx * 0.7, 1.2, sz * 0.7), a, Vector3.ZERO, 8)
			_cyl(1.0, 1.0, 1.8, Vector3(0, 3.3, 0), m, Vector3.ZERO, 24)
			for y in [2.7, 3.3, 3.9]:
				_cyl(1.02, 1.02, 0.05, Vector3(0, y, 0), a, Vector3.ZERO, 24)
			_cyl(0.05, 1.08, 0.6, Vector3(0, 4.5, 0), m.darkened(0.2), Vector3.ZERO, 24)
		"String lights":
			_string_lights(m, a, w)
		"Picnic table":
			_box(Vector3(1.6, 0.06, 0.8), Vector3(0, 0.74, 0), m)
			_legs(1.6, 0.8, 0.72, 0.035, m.darkened(0.2), 0.15)
			for sz in [-1.0, 1.0]:
				_box(Vector3(1.6, 0.05, 0.28), Vector3(0, 0.44, sz * 0.62), m)
				_legs(1.4, 0.2, 0.42, 0.025, m.darkened(0.2), 0.0)
		"Planter":
			_box(Vector3(w, 0.45, 0.5), Vector3(0, 0.225, 0), m)
			var n := int(w / 0.25)
			for i in n:
				_ball(0.16, Vector3(-w * 0.5 + 0.15 + i * 0.25, 0.55 + float(i % 2) * 0.06, 0.0), a.lightened(0.08 * float(i % 3)), Vector3(1, 1.2, 1))
		"Roof door":
			_box(Vector3(2.0, 2.6, 2.0), Vector3(0, 1.3, -1.0), m)
			_box(Vector3(2.2, 0.12, 2.2), Vector3(0, 2.66, -1.0), m.darkened(0.2))
			_box(Vector3(0.9, 2.05, 0.04), Vector3(0, 1.025, 0.01), a)
			_ball(0.035, Vector3(0.32, 1.0, 0.05), Color(0.8, 0.7, 0.4))
			_box(Vector3(0.12, 0.12, 0.08), Vector3(0, 2.35, 0.03), Color(0.3, 0.3, 0.3))
			_glow(Vector3(0.06, 0, 0), Vector3(0, 2.33, 0.08), Color(1.0, 0.85, 0.6), 3.0, true)
			_light(Vector3(0, 2.2, 0.6), Color(1.0, 0.85, 0.6), 0.8, 4.0)
		"Skyline":
			_skyline(m, a, w)
		"Bus shelter":
			for sx in [-1.0, 1.0]:
				_box(Vector3(0.08, 2.4, 0.08), Vector3(sx * 1.4, 1.2, -0.5), m)
				_box(Vector3(0.08, 2.4, 0.08), Vector3(sx * 1.4, 1.2, 0.5), m)
			_box(Vector3(3.0, 0.08, 1.4), Vector3(0, 2.44, 0), m)
			var glass := _box(Vector3(2.8, 1.9, 0.02), Vector3(0, 1.2, -0.52), Color(a.r, a.g, a.b, 0.35), Vector3.ZERO, 0.05)
			glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_box(Vector3(0.9, 1.4, 0.03), Vector3(1.3, 1.3, -0.48), Color(0.95, 0.92, 0.85))
			_glow(Vector3(0.8, 1.3, 0.01), Vector3(1.3, 1.3, -0.46), Color(0.95, 0.75, 0.5), 0.6)
		"Shelter bench":
			_box(Vector3(1.8, 0.06, 0.4), Vector3(0, 0.45, 0), m, Vector3.ZERO, 0.4)
			for sx in [-0.75, 0.75]:
				_box(Vector3(0.05, 0.42, 0.35), Vector3(sx, 0.21, 0), Color(0.25, 0.27, 0.3))
		"Bus sign":
			_cyl(0.035, 0.035, 2.6, Vector3(0, 1.3, 0), Color(0.3, 0.32, 0.35), Vector3.ZERO, 8)
			_box(Vector3(0.72, 0.38, 0.06), Vector3(0, 2.35, 0.03), m)
			_words(_text(), Vector3(0, 2.35, 0.065), 0.08, a, Vector3.ZERO, true)
		"Shop front":
			_shop_front(m, a, w)
		"Pavement":
			_box(Vector3(w, 0.15, 4.0), Vector3(0, 0.075, 0), m, Vector3.ZERO, 0.9)
			var x := -w * 0.5
			while x < w * 0.5:
				_box(Vector3(0.01, 0.002, 4.0), Vector3(x, 0.151, 0), m.darkened(0.15))
				x += 1.2
			_box(Vector3(w, 0.16, 0.25), Vector3(0, 0.08, 2.1), m.lightened(0.1))
			_box(Vector3(w, 0.02, 9.0), Vector3(0, 0.01, 6.7), a, Vector3.ZERO, 0.7)
			x = -w * 0.5
			while x < w * 0.5:
				_box(Vector3(1.5, 0.003, 0.12), Vector3(x + 0.75, 0.022, 6.7), Color(0.92, 0.9, 0.82))
				x += 3.5
		"Car body":
			_car_body(m, a)
		"Car seat":
			_box(Vector3(0.5, 0.14, 0.5), Vector3(0, 0.38, 0), m)
			_box(Vector3(0.5, 0.65, 0.12), Vector3(0, 0.75, -0.26), m, Vector3(-10, 0, 0))
			_box(Vector3(0.28, 0.18, 0.1), Vector3(0, 1.17, -0.33), m, Vector3(-10, 0, 0))
			_box(Vector3(0.4, 0.31, 0.4), Vector3(0, 0.155, 0), m.darkened(0.3))


func _chair(c: Color, size: float, seat: float) -> void:
	_box(Vector3(size, 0.045, size), Vector3(0, seat, 0), c)
	_legs(size, size, seat, 0.018, c.darkened(0.15), 0.03)
	_box(Vector3(size, 0.42, 0.035), Vector3(0, seat + 0.24, -size * 0.5 + 0.02), c, Vector3(-6, 0, 0))


func _kitchen_counter(m: Color, a: Color, w: float) -> void:
	_box(Vector3(w, 0.86, 0.6), Vector3(0, 0.43, 0), m)
	_box(Vector3(w + 0.04, 0.04, 0.64), Vector3(0, 0.88, 0.01), a, Vector3.ZERO, 0.4)
	_box(Vector3(w, 0.1, 0.55), Vector3(0, 0.05, 0.02), m.darkened(0.3))
	var doors := maxi(2, int(w / 0.55))
	for i in range(1, doors):
		_box(Vector3(0.01, 0.7, 0.01), Vector3(-w * 0.5 + w * float(i) / float(doors), 0.48, 0.302), m.darkened(0.25))
	for i in doors:
		_box(Vector3(0.12, 0.02, 0.03), Vector3(-w * 0.5 + w * (float(i) + 0.5) / float(doors), 0.78, 0.31), Color(0.85, 0.82, 0.75), Vector3.ZERO, 0.3)
	# tiles, upper cabinets
	_box(Vector3(w, 0.55, 0.02), Vector3(0, 1.18, -0.29), Color(0.95, 0.94, 0.9))
	for x in range(int(w / 0.15)):
		_box(Vector3(0.004, 0.55, 0.004), Vector3(-w * 0.5 + float(x) * 0.15, 1.18, -0.278), Color(0.8, 0.8, 0.78))
	_box(Vector3(w, 0.62, 0.34), Vector3(0, 1.78, -0.13), m.lightened(0.05))
	for i in range(1, doors):
		_box(Vector3(0.01, 0.58, 0.01), Vector3(-w * 0.5 + w * float(i) / float(doors), 1.78, 0.045), m.darkened(0.2))
	# sink and tap
	_box(Vector3(0.5, 0.02, 0.38), Vector3(w * 0.22, 0.9, 0.02), Color(0.7, 0.72, 0.75), Vector3.ZERO, 0.2)
	_cyl(0.015, 0.015, 0.28, Vector3(w * 0.22, 1.04, -0.2), Color(0.75, 0.76, 0.78))
	_cyl(0.012, 0.012, 0.16, Vector3(w * 0.22, 1.17, -0.13), Color(0.75, 0.76, 0.78), Vector3(90, 0, 0))
	# hob and hood
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_cyl(0.07, 0.07, 0.008, Vector3(-w * 0.25 + sx * 0.12, 0.905, 0.02 + sz * 0.12), Color(0.12, 0.12, 0.13))
	_box(Vector3(0.6, 0.55, 0.01), Vector3(-w * 0.25, 0.45, 0.305), Color(0.18, 0.18, 0.2), Vector3.ZERO, 0.3)
	_box(Vector3(0.65, 0.3, 0.45), Vector3(-w * 0.25, 1.52, -0.08), Color(0.78, 0.78, 0.8), Vector3.ZERO, 0.4)
	# things on the counter
	_cyl(0.08, 0.1, 0.2, Vector3(-w * 0.25 + 0.12, 1.0, 0.02), Color(0.85, 0.3, 0.25))
	for i in 3:
		_cyl(0.05, 0.05, 0.14 + 0.03 * i, Vector3(w * 0.42 - i * 0.12, 0.97 + 0.015 * i, -0.15), [Color(0.95, 0.85, 0.55), Color(0.6, 0.75, 0.55), Color(0.9, 0.6, 0.45)][i])
	_cyl(0.07, 0.09, 0.22, Vector3(-w * 0.45 + 0.12, 1.01, -0.1), Color(0.85, 0.62, 0.45))
	for k in 5:
		_ball(0.07, Vector3(-w * 0.45 + 0.12 + cos(k) * 0.05, 1.18 + k * 0.03, -0.1 + sin(k) * 0.05), Color(0.32, 0.55, 0.32), Vector3(0.6, 1.3, 0.4))


func _window(sky: Color, frame: Color, w: float) -> void:
	var h := 1.3
	var y := 1.55
	_box(Vector3(w + 0.12, 0.08, 0.12), Vector3(0, y - h * 0.5 - 0.04, 0.03), frame)
	_box(Vector3(w + 0.12, 0.06, 0.08), Vector3(0, y + h * 0.5 + 0.03, 0.0), frame)
	for sx in [-1.0, 0.0, 1.0]:
		_box(Vector3(0.05, h, 0.08), Vector3(sx * w * 0.5, y, 0.0), frame)
	_box(Vector3(w, 0.04, 0.06), Vector3(0, y, 0.0), frame)
	# the view: sky and a few distant buildings with lit windows
	var view := _box(Vector3(w + 2.0, h + 1.0, 0.02), Vector3(0, y, -1.2), sky)
	view.material_override = _mat(sky, 1.0, 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var x := -w * 0.5 - 0.6
	while x < w * 0.5 + 0.6:
		var bw := rng.randf_range(0.4, 0.8)
		var bh := rng.randf_range(0.5, 1.2)
		_box(Vector3(bw, bh, 0.02), Vector3(x + bw * 0.5, y - h * 0.5 + bh * 0.5 - 0.2, -1.1), sky.darkened(0.4))
		for i in 4:
			if rng.randf() < 0.5:
				_glow(Vector3(0.06, 0.08, 0.005), Vector3(x + rng.randf_range(0.1, bw - 0.1), y - h * 0.5 - 0.2 + rng.randf_range(0.15, bh - 0.1), -1.085), Color(1.0, 0.82, 0.5), 1.5)
		x += bw + 0.05
	var glass := _box(Vector3(w, h, 0.01), Vector3(0, y, 0.01), Color(0.8, 0.9, 1.0, 0.12), Vector3.ZERO, 0.05)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _cafe_counter(m: Color, a: Color, w: float) -> void:
	_box(Vector3(w, 1.02, 0.7), Vector3(0, 0.51, 0), m)
	var x := -w * 0.5 + 0.08
	while x < w * 0.5:
		_box(Vector3(0.06, 0.9, 0.01), Vector3(x, 0.5, 0.352), m.lightened(0.12))
		x += 0.16
	_box(Vector3(w + 0.06, 0.05, 0.78), Vector3(0, 1.045, 0.0), a, Vector3.ZERO, 0.4)
	# cake display
	var case_x := -w * 0.3
	var glass := _box(Vector3(0.9, 0.42, 0.5), Vector3(case_x, 1.28, 0.05), Color(0.85, 0.92, 0.95, 0.25), Vector3.ZERO, 0.05)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cakes := [Color(0.95, 0.8, 0.85), Color(0.55, 0.35, 0.25), Color(0.98, 0.9, 0.6), Color(0.85, 0.5, 0.45)]
	for i in 4:
		_cyl(0.07, 0.07, 0.08, Vector3(case_x - 0.3 + i * 0.2, 1.11, 0.05), cakes[i])
	_light(Vector3(case_x, 1.35, 0.3), Color(1.0, 0.85, 0.65), 0.4, 1.5)
	# coffee machine
	var cx := w * 0.25
	_box(Vector3(0.62, 0.45, 0.45), Vector3(cx, 1.3, -0.1), Color(0.75, 0.76, 0.78), Vector3.ZERO, 0.25)
	_box(Vector3(0.62, 0.06, 0.45), Vector3(cx, 1.55, -0.1), Color(0.25, 0.25, 0.27))
	for sx in [-0.14, 0.14]:
		_cyl(0.03, 0.03, 0.08, Vector3(cx + sx, 1.18, 0.15), Color(0.2, 0.2, 0.22))
		_cyl(0.035, 0.03, 0.06, Vector3(cx + sx, 1.1, 0.16), Color(0.96, 0.96, 0.94))
	for i in 3:
		_cyl(0.04, 0.035, 0.07, Vector3(cx - 0.05 + i * 0.05, 1.62 + i * 0.0, -0.1), Color(0.96, 0.96, 0.94))
	# register
	_box(Vector3(0.3, 0.12, 0.25), Vector3(w * 0.45, 1.13, 0.0), Color(0.2, 0.2, 0.22))
	_box(Vector3(0.24, 0.16, 0.02), Vector3(w * 0.45, 1.27, -0.05), Color(0.2, 0.2, 0.22), Vector3(-15, 0, 0))
	_glow(Vector3(0.2, 0.12, 0.004), Vector3(w * 0.45, 1.27, -0.038), Color(0.6, 0.85, 0.7), 1.2).rotation_degrees = Vector3(-15, 0, 0)


func _barber_chair(m: Color, a: Color) -> void:
	_cyl(0.28, 0.3, 0.05, Vector3(0, 0.025, 0), a)
	_cyl(0.07, 0.07, 0.36, Vector3(0, 0.2, 0), a, Vector3.ZERO, 12)
	_box(Vector3(0.56, 0.14, 0.55), Vector3(0, 0.45, 0.0), m)
	_box(Vector3(0.56, 0.72, 0.13), Vector3(0, 0.86, -0.27), m, Vector3(-12, 0, 0))
	_box(Vector3(0.3, 0.16, 0.12), Vector3(0, 1.3, -0.36), m, Vector3(-12, 0, 0))
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.08, 0.06, 0.5), Vector3(sx * 0.32, 0.68, 0.02), m.darkened(0.15))
		_box(Vector3(0.03, 0.2, 0.03), Vector3(sx * 0.32, 0.56, 0.2), a)
	_box(Vector3(0.4, 0.03, 0.2), Vector3(0, 0.12, 0.45), a, Vector3(10, 0, 0))


func _photo_wall(board: Color, card: Color, w: float) -> void:
	_box(Vector3(w, 1.05, 0.03), Vector3(0, 1.6, 0.015), board, Vector3.ZERO, 1.0)
	var cols := int(w / 0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var shirts := [Color(0.85, 0.4, 0.35), Color(0.35, 0.55, 0.8), Color(0.55, 0.7, 0.45), Color(0.9, 0.75, 0.35), Color(0.6, 0.45, 0.7)]
	var backs := [Color(0.95, 0.88, 0.75), Color(0.8, 0.88, 0.95), Color(0.95, 0.85, 0.85), Color(0.86, 0.93, 0.84)]
	for row in 3:
		for col in cols:
			var x := -w * 0.5 + 0.15 + col * (w - 0.3) / float(maxi(cols - 1, 1))
			var y := 1.92 - row * 0.32
			var tilt := rng.randf_range(-6.0, 6.0)
			var holder := Node3D.new()
			holder.position = Vector3(x, y, 0.035)
			holder.rotation_degrees = Vector3(0, 0, tilt)
			add_child(holder)
			_parts.append(holder)
			var pieces := [
				[Vector3(0.2, 0.26, 0.004), Vector3(0, 0, 0), card],
				[Vector3(0.17, 0.18, 0.004), Vector3(0, 0.025, 0.003), backs[(row + col) % 4]],
			]
			for p in pieces:
				var mesh := BoxMesh.new()
				mesh.size = p[0]
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				mi.position = p[1]
				mi.material_override = _mat(p[2])
				holder.add_child(mi)
			var head := SphereMesh.new()
			head.radius = 0.04
			head.height = 0.08
			var hm := MeshInstance3D.new()
			hm.mesh = head
			hm.position = Vector3(0, 0.05, 0.008)
			hm.scale = Vector3(1, 1, 0.15)
			hm.material_override = _mat(Color(0.05, 0.05, 0.06))
			holder.add_child(hm)
			var body := BoxMesh.new()
			body.size = Vector3(0.12, 0.06, 0.004)
			var bm := MeshInstance3D.new()
			bm.mesh = body
			bm.position = Vector3(0, -0.02, 0.008)
			bm.material_override = _mat(shirts[(row * 3 + col) % 5])
			holder.add_child(bm)
			# a red pin
			var pin := SphereMesh.new()
			pin.radius = 0.012
			pin.height = 0.024
			var pm := MeshInstance3D.new()
			pm.mesh = pin
			pm.position = Vector3(0, 0.12, 0.01)
			pm.material_override = _mat(Color(0.85, 0.2, 0.2))
			holder.add_child(pm)


func _string_lights(pole: Color, bulb: Color, w: float) -> void:
	for sx in [-1.0, 1.0]:
		_cyl(0.035, 0.035, 2.8, Vector3(sx * w * 0.5, 1.4, 0), pole, Vector3.ZERO, 8)
	var n := int(w / 0.5)
	var prev := Vector3(-w * 0.5, 2.75, 0)
	for i in range(1, n + 1):
		var f := float(i) / float(n)
		var p := Vector3(lerpf(-w * 0.5, w * 0.5, f), 2.75 - sin(f * PI) * 0.45, 0)
		var mid := (prev + p) * 0.5
		var seg := _cyl(0.004, 0.004, prev.distance_to(p), mid, pole, Vector3.ZERO, 4)
		var axis := (p - prev).normalized()
		var side := axis.cross(Vector3.FORWARD).normalized()
		seg.basis = Basis(side, axis, side.cross(axis))
		if i < n:
			_glow(Vector3(0.04, 0, 0), p - Vector3(0, 0.05, 0), bulb, 4.0, true)
		prev = p
	_light(Vector3(-w * 0.25, 2.3, 0.3), bulb, 1.0, 6.0)
	_light(Vector3(w * 0.25, 2.3, 0.3), bulb, 1.0, 6.0)


func _skyline(m: Color, windows: Color, w: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) + 3
	var x := -w * 0.5
	while x < w * 0.5:
		var bw := rng.randf_range(3.0, 7.0)
		var bh := rng.randf_range(6.0, 22.0)
		var depth := rng.randf_range(0.0, 6.0)
		var shade := m.darkened(rng.randf_range(0.0, 0.25))
		_box(Vector3(bw, bh, 3.0), Vector3(x + bw * 0.5, bh * 0.5 - 6.0, -depth), shade)
		var floors := int(bh / 1.6)
		for f in floors:
			for k in int(bw / 1.2):
				if rng.randf() < 0.28:
					_glow(Vector3(0.5, 0.6, 0.02), Vector3(x + 0.6 + k * 1.2, -6.0 + 1.0 + f * 1.6, -depth + 1.52), windows, 1.6)
		if rng.randf() < 0.3:
			var tank := _cyl(0.7, 0.7, 1.2, Vector3(x + bw * 0.5, bh - 6.0 + 1.0, -depth), shade.darkened(0.2))
			tank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		x += bw + rng.randf_range(0.2, 1.5)


func _shop_front(brick: Color, trim: Color, w: float) -> void:
	_box(Vector3(w, 4.5, 0.3), Vector3(0, 2.25, -0.15), brick, Vector3.ZERO, 0.95)
	# brick courses
	var y := 0.2
	while y < 4.5:
		_box(Vector3(w, 0.012, 0.005), Vector3(0, y, 0.003), brick.darkened(0.2))
		y += 0.22
	# window with a warm lit inside
	var ww := w * 0.45
	_box(Vector3(ww + 0.12, 1.9, 0.08), Vector3(-w * 0.12, 1.55, 0.02), trim)
	var inside := _box(Vector3(ww, 1.75, 0.02), Vector3(-w * 0.12, 1.55, 0.04), Color(1.0, 0.82, 0.55))
	inside.material_override = _mat(Color(1.0, 0.82, 0.55), 1.0, 0.9 if lit else 0.05)
	for i in 3:
		_box(Vector3(0.5, 0.12, 0.04), Vector3(-w * 0.12 - ww * 0.3 + i * ww * 0.3, 0.95, 0.07), Color(0.85, 0.6, 0.35))
		_ball(0.08, Vector3(-w * 0.12 - ww * 0.3 + i * ww * 0.3, 1.08, 0.08), Color(0.9, 0.7, 0.4), Vector3(1.4, 0.8, 1))
	_light(Vector3(-w * 0.12, 1.6, 1.0), Color(1.0, 0.8, 0.55), 1.2, 5.0)
	# door
	_box(Vector3(1.0, 2.25, 0.08), Vector3(w * 0.3, 1.125, 0.02), trim)
	_box(Vector3(0.6, 1.0, 0.01), Vector3(w * 0.3, 1.45, 0.065), Color(0.9, 0.8, 0.6, 0.6))
	# awning
	var stripes := int(w / 0.5)
	for i in stripes:
		_box(Vector3(w / float(stripes), 0.04, 1.1), Vector3(-w * 0.5 + (float(i) + 0.5) * w / float(stripes), 2.85, 0.5), trim if i % 2 == 0 else Color(0.95, 0.94, 0.9), Vector3(18, 0, 0))
	# sign
	_box(Vector3(w * 0.5, 0.45, 0.06), Vector3(0, 3.5, 0.03), trim.darkened(0.3))
	_words(_text(), Vector3(0, 3.5, 0.07), 0.3, Color(0.98, 0.92, 0.75), Vector3.ZERO, true)


func _car_body(paint: Color, trim: Color) -> void:
	# A roomy, slightly boxy car (sized for the story people, who have big heads):
	# floor at 0.12 m, roof at 1.87 m. Seats go in separately (Car seat) at y 0.12.
	var floor_y := 0.12
	var roof := floor_y + 1.75
	_box(Vector3(1.8, 0.08, 4.4), Vector3(0, floor_y - 0.04, 0), Color(0.2, 0.2, 0.22))
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.08, 0.78, 2.5), Vector3(sx * 0.88, floor_y + 0.39, -0.1), paint)
		_box(Vector3(0.05, 0.05, 2.5), Vector3(sx * 0.85, floor_y + 0.78, -0.1), trim)
		for z in [1.4, -1.6]:
			_cyl(0.34, 0.34, 0.22, Vector3(sx * 0.82, 0.34, z), Color(0.1, 0.1, 0.11), Vector3(0, 0, 90))
			_cyl(0.18, 0.18, 0.23, Vector3(sx * 0.82, 0.34, z), Color(0.7, 0.7, 0.72), Vector3(0, 0, 90))
	# bonnet and boot
	_box(Vector3(1.8, 0.62, 1.15), Vector3(0, floor_y + 0.31, 1.65), paint)
	_box(Vector3(1.8, 0.7, 0.9), Vector3(0, floor_y + 0.35, -1.8), paint)
	for sx in [-1.0, 1.0]:
		_glow(Vector3(0.3, 0.12, 0.02), Vector3(sx * 0.6, floor_y + 0.45, 2.23), Color(1.0, 0.95, 0.8), 1.0)
		_glow(Vector3(0.26, 0.12, 0.02), Vector3(sx * 0.62, floor_y + 0.5, -2.26), Color(0.9, 0.15, 0.1), 1.2)
	# roof, pillars, windscreen
	_box(Vector3(1.66, 0.07, 1.9), Vector3(0, roof, -0.25), paint)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.07, 1.12, 0.07), Vector3(sx * 0.8, floor_y + 1.28, 0.95), paint, Vector3(-30, 0, 0))
		_box(Vector3(0.07, 0.95, 0.07), Vector3(sx * 0.82, floor_y + 1.3, -1.18), paint)
	var glass := _box(Vector3(1.55, 1.08, 0.01), Vector3(0, floor_y + 1.28, 0.97), Color(0.8, 0.88, 0.95, 0.1), Vector3(-30, 0, 0), 0.05)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# dashboard, wheel, mirror
	_box(Vector3(1.62, 0.28, 0.42), Vector3(0, floor_y + 0.72, 0.9), Color(0.18, 0.18, 0.2))
	_glow(Vector3(0.18, 0.06, 0.01), Vector3(-0.4, floor_y + 0.8, 0.685), Color(0.5, 0.8, 1.0), 1.0)
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.15
	wheel.outer_radius = 0.18
	_add(wheel, Vector3(-0.4, floor_y + 0.95, 0.56), _mat(Color(0.12, 0.12, 0.13)), Vector3(60, 0, 0))
	_cyl(0.02, 0.02, 0.35, Vector3(-0.4, floor_y + 0.88, 0.7), Color(0.12, 0.12, 0.13), Vector3(60, 0, 0), 6)
	_box(Vector3(0.24, 0.07, 0.02), Vector3(0, roof - 0.16, 0.62), Color(0.15, 0.15, 0.16))
	_box(Vector3(0.05, 0.07, 0.005), Vector3(0.04, roof - 0.3, 0.62), Color(0.3, 0.75, 0.4))
	# a soft roof light, so faces in the car are never lost in shadow
	_light(Vector3(0, roof - 0.25, -0.2), Color(1.0, 0.92, 0.82), 0.35, 2.4)
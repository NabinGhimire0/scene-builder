class_name AnimalBuilder
extends RefCounted
## Animals for the Character Studio. Each species is a rigged body made by
## tools/animals/make_animals.py (res://assets/animals/<species>.glb); here it
## gets its colours, coat pattern and fur, and walk / run / sit / lie down / eat
## motions that are generated for its legs, spine, neck and tail.

const DIR := "res://assets/animals/"
const SHADER := "res://assets/animals/animal.gdshader"
const FUR_SHADER := "res://assets/animals/fur.gdshader"
const FUR_LAYERS := 10

const SPECIES := ["dog", "cat", "cow", "buffalo", "goat", "sheep", "horse", "donkey", "yak", "deer", "pig",
	"elephant", "tiger", "lion", "bear", "monkey", "rabbit", "fox", "wolf", "chicken", "duck", "bird"]
const PATTERNS := ["plain", "two-tone", "spots", "patches", "stripes", "points", "dapple"]

## color/color2: coat; colors: swatches; pattern: default; fur_amount: shell length (0 = smooth).
const INFO := {
	"dog": {"label": "Dog", "color": "#a8713c", "color2": "#f1e3cc", "pattern": "two-tone", "fur_amount": 0.45,
		"colors": ["#a8713c", "#2a2420", "#e8dcc4", "#6b4a2e", "#c9a26b", "#8a8a8a"]},
	"cat": {"label": "Cat", "color": "#b8875a", "color2": "#f4ece0", "pattern": "stripes", "fur_amount": 0.45, "eyes": "#b8a030",
		"colors": ["#b8875a", "#3a3a3c", "#e8e2d6", "#d2884a", "#8a8a8e", "#2a2420"]},
	"cow": {"label": "Cow", "color": "#f2efe8", "color2": "#2a2522", "pattern": "patches", "fur_amount": 0.15,
		"colors": ["#f2efe8", "#7a4a2a", "#2a2522", "#b88a5a", "#d8c8a8"], "extra": [["horns", "Horns", true]]},
	"buffalo": {"label": "Water buffalo", "color": "#2e2b2a", "color2": "#4a4542", "pattern": "plain", "fur_amount": 0.08,
		"colors": ["#2e2b2a", "#4a4542", "#5a4a3e"], "extra": [["horns", "Horns", true]]},
	"goat": {"label": "Goat", "color": "#e8e2d6", "color2": "#3a2a20", "pattern": "plain", "fur_amount": 0.4,
		"colors": ["#e8e2d6", "#3a2a20", "#8a5a34", "#2a2624", "#c8a880"], "extra": [["horns", "Horns", true], ["beard", "Beard", true]]},
	"sheep": {"label": "Sheep", "color": "#ece6d8", "color2": "#2a2624", "pattern": "points", "fur_amount": 1.0,
		"colors": ["#ece6d8", "#d8ccb4", "#3a3430", "#8a7a68"], "extra": [["horns", "Horns", false]]},
	"horse": {"label": "Horse", "color": "#7a4a28", "color2": "#1e1a18", "pattern": "points", "fur_amount": 0.1,
		"colors": ["#7a4a28", "#2a2220", "#e8e4dc", "#b88a54", "#8a8480", "#5a3a22"]},
	"donkey": {"label": "Donkey", "color": "#8a8278", "color2": "#e8e2d8", "pattern": "two-tone", "fur_amount": 0.25,
		"colors": ["#8a8278", "#5a4a3e", "#3a3430"]},
	"yak": {"label": "Yak", "color": "#2a2420", "color2": "#e8e2d8", "pattern": "plain", "fur_amount": 1.0,
		"colors": ["#2a2420", "#5a4434", "#e8e2d8"], "extra": [["horns", "Horns", true]]},
	"deer": {"label": "Deer", "color": "#a0683a", "color2": "#f2e8d8", "pattern": "two-tone", "fur_amount": 0.15,
		"colors": ["#a0683a", "#8a5a34", "#b88a5a"], "extra": [["antlers", "Antlers", true]]},
	"pig": {"label": "Pig", "color": "#f0b8a8", "color2": "#2a2624", "pattern": "plain", "fur_amount": 0.04, "fur": false,
		"colors": ["#f0b8a8", "#e8c8b8", "#2a2624", "#8a5a44"]},
	"elephant": {"label": "Elephant", "color": "#7e7a76", "color2": "#8e8a86", "pattern": "plain", "fur_amount": 0.0, "fur": false,
		"colors": ["#7e7a76", "#6a6460", "#8a7a70"], "extra": [["tusks", "Tusks", true]]},
	"tiger": {"label": "Tiger", "color": "#d27a2a", "color2": "#f4ece0", "pattern": "stripes", "fur_amount": 0.3, "eyes": "#c8a030",
		"colors": ["#d27a2a", "#e89a4a", "#f2ece4"]},
	"lion": {"label": "Lion", "color": "#c8964e", "color2": "#f0e0c4", "pattern": "two-tone", "fur_amount": 0.3, "eyes": "#c8a030",
		"colors": ["#c8964e", "#b8864a", "#e0b878"], "extra": [["mane", "Mane", true]]},
	"bear": {"label": "Bear", "color": "#3a2618", "color2": "#5a4030", "pattern": "plain", "fur_amount": 0.8,
		"colors": ["#3a2618", "#1a1614", "#6a4a30", "#f2efe8"]},
	"monkey": {"label": "Monkey", "color": "#7a6a5a", "color2": "#e0b8a0", "pattern": "two-tone", "fur_amount": 0.5,
		"colors": ["#7a6a5a", "#5a4a3a", "#9a8a6a", "#3a2e26"]},
	"rabbit": {"label": "Rabbit", "color": "#b8a088", "color2": "#f4f0ea", "pattern": "two-tone", "fur_amount": 0.7,
		"colors": ["#b8a088", "#f4f0ea", "#5a4a3e", "#3a3634", "#e8dcc8"]},
	"fox": {"label": "Fox", "color": "#c8642a", "color2": "#f4ece2", "pattern": "points", "fur_amount": 0.6, "eyes": "#b88a20",
		"colors": ["#c8642a", "#b8a898", "#3a3634"]},
	"wolf": {"label": "Wolf", "color": "#7a7470", "color2": "#e8e2da", "pattern": "two-tone", "fur_amount": 0.7, "eyes": "#b8a040",
		"colors": ["#7a7470", "#4a4440", "#e8e4de", "#8a6a4a"]},
	"chicken": {"label": "Chicken", "color": "#f4efe6", "color2": "#c8402a", "pattern": "plain", "fur_amount": 0.45,
		"colors": ["#f4efe6", "#a85a2a", "#2a2624", "#d8a060"]},
	"duck": {"label": "Duck", "color": "#f4f2ee", "color2": "#e89a2a", "pattern": "plain", "fur_amount": 0.35,
		"colors": ["#f4f2ee", "#8a6a4a", "#3a5a3a"]},
	"bird": {"label": "Bird", "color": "#8a6a4a", "color2": "#e8dcc8", "pattern": "two-tone", "fur_amount": 0.35,
		"colors": ["#8a6a4a", "#3a6ac8", "#d83a2a", "#f0c020", "#2a2a2a", "#4a8a3a"]},
}

static var _shader_cache: Dictionary = {}
static var _clip_cache: Dictionary = {}


static func label(species: String) -> String:
	return str((INFO.get(species, {}) as Dictionary).get("label", species.capitalize()))


static func info(species: String) -> Dictionary:
	return INFO.get(species, {})


static func patterns_for(species: String) -> Array:
	if species in ["chicken", "duck", "bird"]:
		return ["plain", "two-tone", "spots"]
	return PATTERNS


static func has_species(species: String) -> bool:
	return ResourceLoader.exists(DIR + species + ".glb")


## A new animal character for [param spec] (null if the species is missing).
static func make(spec: Dictionary, source_path := "") -> Node3D:
	var model := make_model(spec)
	if model == null:
		return null
	var ch := ImportedCharacter.new()
	ch.source_path = source_path
	ch.name = label(str(spec.get("species", "dog"))).to_pascal_case()
	ch.add_child(model)
	return ch


## Just the animal's model (skeleton, meshes, motions), for an [ImportedCharacter].
static func make_model(spec: Dictionary) -> Node3D:
	var species := str(spec.get("species", "dog"))
	var path := DIR + species + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("AnimalBuilder: no model for %s" % species)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	model.set_meta("animal", species)
	_dress(model, spec, species)
	AnimalMotion.add_clips(model, species)
	var age := clampf(float(spec.get("age", 1.0)), 0.3, 1.0)
	var s := clampf(float(spec.get("size", 1.0)), 0.3, 2.0) * lerpf(0.42, 1.0, age)
	model.scale = Vector3.ONE * s
	model.name = "Model"
	return model


## Colours of horns, hooves, tusks, beaks, combs (the coat comes from the spec).
static func _part_colour(mat_name: String, species: String, spec: Dictionary) -> Color:
	if mat_name.contains("hoof") or mat_name.contains("claw"):
		return Color(0.1, 0.085, 0.075)
	if mat_name.contains("tusk"):
		return Color(0.88, 0.84, 0.74)
	if mat_name.contains("antler"):
		return Color(0.45, 0.36, 0.27)
	if mat_name.contains("horn"):
		return {"buffalo": Color(0.16, 0.14, 0.13), "goat": Color(0.3, 0.27, 0.24), "yak": Color(0.22, 0.2, 0.18),
			"sheep": Color(0.62, 0.56, 0.46)}.get(species, Color(0.72, 0.66, 0.56))
	if mat_name.contains("beak") or mat_name.contains("feet"):
		return HumanBuilder.colour(spec.get("beak_color", ""), Color(0.9, 0.62, 0.16) if species != "bird" else Color(0.25, 0.2, 0.15))
	if mat_name.contains("comb"):
		return Color(0.78, 0.08, 0.06)
	return Color(0.5, 0.5, 0.5)


static func _shader(path: String) -> Shader:
	if not _shader_cache.has(path):
		_shader_cache[path] = load(path)
	return _shader_cache[path]


static func _dress(model: Node3D, spec: Dictionary, species: String) -> void:
	var inf := info(species)
	var c1 := HumanBuilder.colour(spec.get("color", inf.get("color", "#8a6a4a")), Color(0.5, 0.4, 0.3))
	var c2 := HumanBuilder.colour(spec.get("color2", inf.get("color2", "#f0e6d8")), Color(0.9, 0.85, 0.8))
	var pattern := PATTERNS.find(str(spec.get("pattern", inf.get("pattern", "plain"))))
	var fur := float(spec.get("fur", inf.get("fur_amount", 0.4))) if bool(inf.get("fur", true)) else 0.0
	var eyes := HumanBuilder.colour(spec.get("eyes", inf.get("eyes", "#3a2410")), Color(0.23, 0.14, 0.06))
	var chubby := float(spec.get("chubby", 0.0))
	var seed_value := float(hash(str(spec.get("name", species))) % 1000) * 0.137
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		var name := String(inst.name).to_lower()
		# Optional parts (horns, antlers, mane...) are separate meshes named after them.
		var optional := false
		for extra in inf.get("extra", []):
			if name.contains(str(extra[0])):
				optional = true
				inst.visible = bool(spec.get(str(extra[0]), extra[2]))
		if optional and not inst.visible:
			continue
		if inst.mesh == null:
			continue
		for k in inst.mesh.get_blend_shape_count():
			if str(inst.mesh.get_blend_shape_name(k)) == "chubby":
				inst.set_blend_shape_value(k, chubby)
		for surf in inst.mesh.get_surface_count():
			var old := inst.mesh.surface_get_material(surf)
			var mat_name := (old.resource_name if old else "").to_lower()
			var m := ShaderMaterial.new()
			m.shader = _shader(SHADER)
			var part := 0  # 0 coat, 1 horn/hoof, 2 nose/skin, 3 eye, 4 beak/legs (bird), 5 comb
			for pair in [["horn", 1], ["hoof", 1], ["claw", 1], ["tusk", 1], ["antler", 1], ["nose", 2], ["skin", 2],
					["eye", 3], ["beak", 4], ["feet", 4], ["comb", 5]]:
				if mat_name.contains(pair[0]):
					part = pair[1]
			m.set_shader_parameter("part", part)
			m.set_shader_parameter("color", c1)
			m.set_shader_parameter("color2", c2)
			m.set_shader_parameter("pattern", pattern)
			m.set_shader_parameter("seed", seed_value)
			m.set_shader_parameter("eye_color", eyes)
			m.set_shader_parameter("base", _part_colour(mat_name, species, spec))
			if part == 0 and fur > 0.01:
				var prev: Material = m
				for layer in range(1, FUR_LAYERS + 1):
					var f := ShaderMaterial.new()
					f.shader = _shader(FUR_SHADER)
					f.render_priority = layer
					for key in ["color", "color2", "pattern", "seed"]:
						f.set_shader_parameter(key, m.get_shader_parameter(key))
					f.set_shader_parameter("layer", float(layer) / FUR_LAYERS)
					f.set_shader_parameter("fur_length", 0.004 + 0.05 * fur)
					f.set_shader_parameter("density", lerpf(420.0, 160.0, fur))
					prev.next_pass = f
					prev = f
			inst.set_surface_override_material(surf, m)

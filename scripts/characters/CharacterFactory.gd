class_name CharacterFactory
extends RefCounted
## Characters made in the Character Studio are small description files
## (user://library/characters/<name>.character, JSON). This turns one into a
## character node: realistic / animated-film people ([HumanBuilder]), sketch and
## cartoon people ([SketchCharacter]) and animals ([AnimalBuilder]).

const EXTENSION := "character"
const KINDS: PackedStringArray = ["realistic", "pixar", "cartoon", "sketch", "animal"]
const SKETCH_SCENE := "res://assets/props/characters/sketch_person.tscn"
## SketchCharacter settings a description may set.
const SKETCH_PROPS: PackedStringArray = ["figure", "body_color", "line_color", "glow_color", "expression", "hair",
	"hair_color", "body_type", "shirt_color", "pants_color", "long_sleeves", "cap_color", "shoe_color", "fuzzy", "height", "build"]


static func is_character_file(path: String) -> bool:
	return path.get_extension().to_lower() == EXTENSION


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func save_file(path: String, spec: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(spec, "\t"))
	return OK


static func path_for(display_name: String) -> String:
	return RuntimeModelLoader.CHARACTERS_DIR + display_name.strip_edges().validate_filename().replace(" ", "_").to_lower() + "." + EXTENSION


static func display_name(path: String) -> String:
	var spec := load_file(path)
	return str(spec.get("name", path.get_file().get_basename().capitalize()))


## A new character node for [param spec] (null if the kind is unknown).
static func make(spec: Dictionary, source_path := "") -> Node3D:
	var kind := str(spec.get("kind", "realistic"))
	match kind:
		"realistic", "pixar":
			var human := spec.duplicate(true)
			human["type"] = kind
			var model := HumanBuilder.build(human)
			if model == null:
				return null
			var ch := ImportedCharacter.new()
			ch.source_path = source_path
			ch.add_child(model)
			return ch
		"sketch", "cartoon":
			var packed := load(SKETCH_SCENE) as PackedScene
			var node := packed.instantiate() as Node3D
			apply_sketch(node, spec)
			return node
		"animal":
			return AnimalBuilder.make(spec, source_path)
	return null


static func apply_sketch(node: Node, spec: Dictionary) -> void:
	var props: Dictionary = spec.get("props", {})
	if str(spec.get("kind", "")) == "cartoon":
		node.set("figure", "Cartoon")
	for key in props:
		if not SKETCH_PROPS.has(key):
			continue
		var value: Variant = props[key]
		var current: Variant = node.get(key)
		if current is Color:
			value = HumanBuilder.colour(value, current)
			if value is Color and (key in ["shirt_color", "pants_color", "cap_color"]):
				var c: Color = value
				value = Color(c.r, c.g, c.b, float(props.get(key + "_alpha", 1.0)))
		elif current is float:
			value = float(value)
		elif current is bool:
			value = bool(value)
		elif current is String:
			value = str(value)
		node.set(key, value)

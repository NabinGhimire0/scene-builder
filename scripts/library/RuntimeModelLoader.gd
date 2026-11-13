class_name RuntimeModelLoader
extends RefCounted
## Loads .glb / .gltf files from disk while the app is running (downloaded or
## imported models live in user://, which Godot never imports), and turns them
## into PackedScenes so they can be placed any number of times like built-in
## assets. Models in the characters folder are wrapped in [ImportedCharacter].

const LIBRARY_DIR := "user://library/"
const CHARACTERS_DIR := "user://library/characters/"
const IMPORTED_DIR := "user://library/imported/"
const ONLINE_DIR := "user://library/online/"
const EXTENSIONS: PackedStringArray = ["glb", "gltf", "fbx"]

static var _cache: Dictionary = {}
static var _materials: Dictionary = {}


static func is_runtime_path(path: String) -> bool:
	return path.begins_with("user://")


static func load_scene(path: String) -> PackedScene:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return null
	# Characters made in the Character Studio (a description, built on load).
	if CharacterFactory.is_character_file(path):
		var made := CharacterFactory.make(CharacterFactory.load_file(path), path)
		if made == null:
			return null
		made.name = CharacterFactory.display_name(path).to_pascal_case().validate_node_name()
		_own_recursive(made, made)
		var packed_char := PackedScene.new()
		if packed_char.pack(made) != OK:
			made.free()
			return null
		made.free()
		_cache[path] = packed_char
		return packed_char
	if not EXTENSIONS.has(path.get_extension().to_lower()):
		return null
	var root := read_file(path)
	if root == null:
		return null
	var top: Node = root
	if path.begins_with(CHARACTERS_DIR):
		var wrapper := ImportedCharacter.new()
		wrapper.source_path = path
		wrapper.name = path.get_file().get_basename().to_pascal_case().validate_node_name()
		wrapper.add_child(root)
		top = wrapper
	_own_recursive(top, top)
	var packed := PackedScene.new()
	var err := packed.pack(top)
	top.free()
	if err != OK:
		push_warning("RuntimeModelLoader: couldn't pack %s (%s)" % [path, error_string(err)])
		return null
	_cache[path] = packed
	return packed


## Reads a .glb/.gltf/.fbx file into a new node tree (caller frees it), or null.
## FBX (e.g. Mixamo downloads) needs Godot 4.3+, which can read FBX at runtime.
static func read_file(path: String) -> Node:
	var fbx := path.get_extension().to_lower() == "fbx"
	if fbx and not ClassDB.class_exists(&"FBXDocument"):
		push_warning("RuntimeModelLoader: this Godot version can't read FBX at runtime; use Godot 4.3+ or convert to .glb.")
		return null
	var document: GLTFDocument = ClassDB.instantiate(&"FBXDocument") if fbx else GLTFDocument.new()
	var state: GLTFState = ClassDB.instantiate(&"FBXState") if fbx else GLTFState.new()
	var err := document.append_from_file(path, state)
	if err != OK:
		push_warning("RuntimeModelLoader: couldn't read %s (%s)" % [path, error_string(err)])
		return null
	var root := document.generate_scene(state)
	if root:
		_convert_importer_meshes(root)
	if fbx and root is Node3D:
		_fix_centimetres(root as Node3D)
	if root:
		tame_lights(root)
	return root


## Some files (e.g. Mixamo FBX characters with several bind poses) come out with
## import-time mesh nodes that never draw. Turn them into normal meshes.
static func _convert_importer_meshes(root: Node) -> void:
	for node in root.find_children("*", "ImporterMeshInstance3D", true, false):
		var source := node as ImporterMeshInstance3D
		if source.mesh == null:
			continue
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = source.name
		mesh_instance.mesh = source.mesh.get_mesh()
		mesh_instance.skin = source.skin
		mesh_instance.transform = source.transform
		mesh_instance.visible = source.visible
		var parent := source.get_parent()
		var index := source.get_index()
		parent.remove_child(source)
		parent.add_child(mesh_instance)
		parent.move_child(mesh_instance, index)
		mesh_instance.skeleton = source.skeleton_path
		for child in source.get_children():
			source.remove_child(child)
			mesh_instance.add_child(child)
		source.free()


## Lights inside imported models: Blender and other tools use physical units
## (watts, candela), which arrive in Godot hundreds of times too bright and with
## an unlimited range. Bring them to sensible, practical-light levels.
static func tame_lights(root: Node) -> void:
	for node in root.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light is DirectionalLight3D:
			light.visible = false  # a model shouldn't bring its own sun
			continue
		if light.light_energy > 6.0:
			light.light_energy = clampf(2.0 + log(light.light_energy) * 0.15, 1.0, 3.0)
		if light is OmniLight3D:
			var omni := light as OmniLight3D
			if omni.omni_range > 40.0 or omni.omni_range <= 0.0:
				omni.omni_range = 8.0
			omni.omni_attenuation = 1.4
		elif light is SpotLight3D:
			var spot := light as SpotLight3D
			if spot.spot_range > 60.0 or spot.spot_range <= 0.0:
				spot.spot_range = 15.0
		light.shadow_enabled = false


## Some FBX files (Mixamo) are in centimetres: a 180 m tall person is really 1.8 m.
static func _fix_centimetres(root: Node3D) -> void:
	var box := PropUtils.compute_local_aabb(root)
	if box.size.y > 30.0:
		root.scale *= 0.01


## The first material of a .gltf/.glb file (Poly Haven textures come as a glTF
## material with all PBR maps wired up: colour, normal, roughness, AO…).
static func load_material(path: String) -> Material:
	if _materials.has(path):
		return _materials[path]
	if not FileAccess.file_exists(path):
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	for material in state.get_materials():
		if material != null:
			_materials[path] = material
			return material
	return null


static func forget(path: String) -> void:
	_cache.erase(path)
	_materials.erase(path)


static func _own_recursive(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_own_recursive(child, owner_node)

class_name PropUtils
extends RefCounted
## Stateless helpers for loading, creating, measuring and preparing props.

const META_PROP_ID := &"prop_id"
const META_SCENE_PATH := &"scene_path"
## Stable id that keyframes and save files use to refer to an object.
const META_UID := &"uid"
## Photo texture applied to a prop: { "texture": path, "id": Poly Haven id, "tile": metres }.
const META_SURFACE := &"surface"
const FALLBACK_AABB := AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)
const GHOST_TRANSPARENCY := 0.4

static var _scene_cache: Dictionary = {}


## Loads (and caches) a prop scene. Returns null, never crashes, for bad paths.
static func load_prop_scene(path: String) -> PackedScene:
	if path.is_empty():
		return null
	if RuntimeModelLoader.is_runtime_path(path):
		return RuntimeModelLoader.load_scene(path)  # downloaded / imported model
	if _scene_cache.has(path):
		return _scene_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var scene := ResourceLoader.load(path) as PackedScene
	if scene != null:
		_scene_cache[path] = scene
	return scene


## Instantiates [param scene] and guarantees a Node3D root (wrapping if needed).
static func instantiate_as_node3d(scene: PackedScene) -> Node3D:
	if scene == null or not scene.can_instantiate():
		return null
	var node := scene.instantiate()
	if node == null:
		return null
	if node.has_method(&"ensure_built"):
		node.call(&"ensure_built")  # procedural assets (e.g. characters) build now
	if node is Node3D:
		return node as Node3D
	var wrapper := Node3D.new()
	wrapper.name = node.name
	wrapper.add_child(node)
	return wrapper


## Creates a ready-to-place prop: instanced, collider on the Props layer, tagged
## with its id and source path. Not yet in the tree. Returns null on failure.
static func create_prop(scene_path: String, prop_id: String = "") -> Node3D:
	var node := instantiate_as_node3d(load_prop_scene(scene_path))
	if node == null:
		return null
	if prop_id.is_empty():
		prop_id = scene_path.get_file().get_basename().to_snake_case()
	node.name = prop_id.to_pascal_case()
	prepare_placed(node, compute_local_aabb(node))
	node.set_meta(META_PROP_ID, prop_id)
	node.set_meta(META_SCENE_PATH, scene_path)
	node.set_meta(META_UID, new_uid())
	return node


## A copy of [param base] with triplanar projection, repeating every [param tile]
## metres. World projection suits the ground; object projection (the default for
## props) keeps the texture glued to an object while it moves.
static func world_projected(base: Material, tile: float, in_world: bool = true) -> Material:
	var material := base.duplicate() as Material
	var standard := material as BaseMaterial3D
	if standard:
		standard.uv1_triplanar = true
		standard.uv1_world_triplanar = in_world
		standard.uv1_triplanar_sharpness = 4.0
		standard.uv1_scale = Vector3.ONE / maxf(tile, 0.01)
		standard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


## Applies (or with an empty [param surface], removes) a photo texture on every
## mesh of a prop, and remembers it for saving.
static func apply_surface(node: Node3D, surface: Dictionary) -> void:
	if not is_instance_valid(node):
		return
	var material: Material = null
	if surface.is_empty():
		node.remove_meta(META_SURFACE)
	else:
		node.set_meta(META_SURFACE, surface.duplicate())
		var base := RuntimeModelLoader.load_material(str(surface.get("texture", "")))
		if base:
			material = world_projected(base, float(surface.get("tile", 1.0)), false)
	for child in descendants(node, true):
		var geo := child as GeometryInstance3D
		if geo and geo.layers != Layers.EDITOR_ONLY_VISUAL:
			geo.material_override = material


static func surface_of(node: Node) -> Dictionary:
	return node.get_meta(META_SURFACE, {}) if node and node.has_meta(META_SURFACE) else {}


static func is_prop(node: Node) -> bool:
	return node != null and node.has_meta(META_SCENE_PATH)


static func new_uid() -> String:
	return "%08x%08x" % [randi(), randi()]


## Returns the node's uid, assigning one if it has none yet.
static func uid_of(node: Node) -> String:
	if not node.has_meta(META_UID):
		node.set_meta(META_UID, new_uid())
	return str(node.get_meta(META_UID))


## Puts every mesh under [param root] on the editor-only visual layer, so it is
## never seen through cinematic cameras or in exported video.
static func set_editor_only(root: Node) -> void:
	for node in descendants(root, true):
		if node is VisualInstance3D:
			(node as VisualInstance3D).layers = Layers.EDITOR_ONLY_VISUAL


## Root plus every descendant (including nodes without an owner).
static func descendants(root: Node, include_root: bool = true) -> Array[Node]:
	var nodes: Array[Node] = []
	if include_root:
		nodes.append(root)
	nodes.append_array(root.find_children("*", "", true, false))
	return nodes


## Bounding box of all visible geometry in [param root]'s local space (the root's
## own transform is excluded). Works before the node enters the tree.
static func compute_local_aabb(root: Node3D) -> AABB:
	var merged := AABB()
	var found := false
	for node in descendants(root, true):
		var geo := node as GeometryInstance3D
		if geo == null or not geo.visible:
			continue
		var box := geo.get_aabb()
		if box.size.length_squared() <= 0.0:
			continue
		box = _transform_to_root(geo, root) * box
		merged = box if not found else merged.merge(box)
		found = true
	return merged if found else FALLBACK_AABB


## World-space bounds of a prop that is in the tree.
static func world_aabb(root: Node3D) -> AABB:
	return root.global_transform * compute_local_aabb(root)


## How far above a surface the prop's pivot must sit so its base touches it,
## for a given orientation/scale [param basis].
static func bottom_offset(root: Node3D, basis: Basis) -> float:
	var box := Transform3D(basis, Vector3.ZERO) * compute_local_aabb(root)
	return -box.position.y


static func collision_rids(root: Node) -> Array[RID]:
	var rids: Array[RID] = []
	for node in descendants(root, true):
		if node is CollisionObject3D:
			rids.append((node as CollisionObject3D).get_rid())
	return rids


static func _transform_to_root(node: Node3D, root: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform


## Turns an instance into a non-interactive, see-through placement ghost.
static func make_ghost(root: Node3D, tint: Material) -> void:
	root.process_mode = Node.PROCESS_MODE_DISABLED
	for node in descendants(root, true):
		if node is CollisionObject3D:
			var body := node as CollisionObject3D
			body.collision_layer = 0
			body.collision_mask = 0
			body.input_ray_pickable = false
		elif node is CollisionShape3D:
			(node as CollisionShape3D).disabled = true
		if node is GeometryInstance3D:
			var geo := node as GeometryInstance3D
			geo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			geo.transparency = GHOST_TRANSPARENCY
			geo.material_overlay = tint
			geo.layers = Layers.EDITOR_ONLY_VISUAL
		elif node is Light3D:
			(node as Light3D).visible = false


## Puts every collider on the Props layer; props without any collider get a box
## collider from their bounds so they can be picked and stacked on.
static func prepare_placed(root: Node3D, local_aabb: AABB) -> void:
	var has_collider := false
	for node in descendants(root, true):
		if node is CollisionObject3D:
			(node as CollisionObject3D).collision_layer = Layers.PROPS
			has_collider = true
	if has_collider:
		return
	var body := StaticBody3D.new()
	body.name = "AutoCollider"
	body.collision_layer = Layers.PROPS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(
		maxf(local_aabb.size.x, 0.05),
		maxf(local_aabb.size.y, 0.05),
		maxf(local_aabb.size.z, 0.05))
	shape.shape = box
	shape.position = local_aabb.get_center()
	body.add_child(shape)
	root.add_child(body)


## Walks up from a hit collider to the prop root sitting directly under [param container].
static func find_prop_root(node: Node, container: Node) -> Node3D:
	var current := node
	while current != null and current.get_parent() != container:
		current = current.get_parent()
	return current as Node3D

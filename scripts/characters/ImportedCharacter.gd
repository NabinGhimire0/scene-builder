class_name ImportedCharacter
extends CharacterBase
## Wraps a user-imported rigged character (.glb / .gltf with a Skeleton3D and
## animation clips, e.g. a Mixamo character exported from Blender).
##
## The model's own clips become this character's actions. Clips are sampled
## directly from their Animation resources at the exact timeline time and
## blended in code, so playback and export stay frame-accurate. Horizontal root
## motion is removed ("in place"), because the timeline moves the character.
##
## "Auto" picks clips whose names contain idle / walk / run (or jog, sprint).

const IDLE_WORDS: PackedStringArray = ["idle", "stand", "breath"]
const WALK_WORDS: PackedStringArray = ["walk"]
const RUN_WORDS: PackedStringArray = ["run", "jog", "sprint"]
## Extra animation clips shared by every imported character (e.g. Mixamo
## downloads); bones are matched by name, so they suit the same kind of rig.
const ANIMATIONS_DIR := "user://library/animations/"
const GENERIC_CLIP_NAMES: PackedStringArray = ["mixamo.com", "take 001", "take001", "animation", "default", "armature|mixamo.com|layer0"]
const BLINK_WORDS: PackedStringArray = ["blink", "eyesclosed", "eye_close", "eyeclose"]
const MOUTH_WORDS: PackedStringArray = ["jawopen", "mouthopen", "mouth_open", "viseme_aa", "aa"]

const BONE_ALIASES := {
	"pelvis": "hips", "spine01": "spine", "spine02": "spine1", "spine03": "spine2", "neck01": "neck",
	"chest": "spine1", "upperchest": "spine2",
	"claviclel": "leftshoulder", "upperarml": "leftarm", "lowerarml": "leftforearm", "handl": "lefthand",
	"clavicler": "rightshoulder", "upperarmr": "rightarm", "lowerarmr": "rightforearm", "handr": "righthand",
	"thighl": "leftupleg", "calfl": "leftleg", "footl": "leftfoot", "balll": "lefttoebase",
	"thighr": "rightupleg", "calfr": "rightleg", "footr": "rightfoot", "ballr": "righttoebase",
	"leftupperarm": "leftarm", "leftlowerarm": "leftforearm", "rightupperarm": "rightarm", "rightlowerarm": "rightforearm",
	"leftupperleg": "leftupleg", "leftlowerleg": "leftleg", "rightupperleg": "rightupleg", "rightlowerleg": "rightleg",
	"lefttoes": "lefttoebase", "righttoes": "righttoebase",
}

## Bone → the child it points at. Rigs differ in their rest pose (Mixamo uses a
## T-pose, MakeHuman/MPFB avatars an A-pose); these bones are lined up with the
## pack's rest pose before its motion is copied, so arms and legs end up where
## the animation means them to be.
const ALIGN_CHAIN := {
	"leftshoulder": "leftarm", "leftarm": "leftforearm", "leftforearm": "lefthand", "lefthand": "lefthandmiddle1",
	"rightshoulder": "rightarm", "rightarm": "rightforearm", "rightforearm": "righthand", "righthand": "righthandmiddle1",
	"leftupleg": "leftleg", "leftleg": "leftfoot", "leftfoot": "lefttoebase",
	"rightupleg": "rightleg", "rightleg": "rightfoot", "rightfoot": "righttoebase",
	"spine": "spine1", "spine1": "spine2", "spine2": "neck", "neck": "head",
}
const FINGERS: PackedStringArray = ["thumb", "index", "middle", "ring", "pinky"]

static var _pack_cache: Dictionary = {}   # file path -> { "clips", "rests", "dirs", "hips_y" }

## The .glb/.fbx this character was loaded from (its Avatar Studio look is
## stored next to it as <name>.look.json).
@export var source_path := ""

var _model: Node3D
var _worn: Array = []
var _wardrobe_slots: Dictionary = {}
var _look: Dictionary = {}
var _model_base_scale := Vector3.ONE
var _player: AnimationPlayer
var _clips: Dictionary = {}        # clip name -> Animation
var _bindings: Dictionary = {}     # clip name -> Array of binding Dictionaries
var _pack_clips: Dictionary = {}   # clip name -> pack info for clips from animation packs
var _skeleton: Skeleton3D
var _bone_lookup: Dictionary = {}  # simplified bone name -> bone index
## Extra skeletons (the importer may give clothes/hair/eyes their own copy of
## the rig): [[skeleton, PackedInt32Array main bones, PackedInt32Array own bones]].
var _followers: Array = []
var _jaw := -1
var _jaw_rest := Quaternion.IDENTITY
## A realistic-person description (res:// or user:// JSON) to build the model from.
## A built-in animal (see [AnimalBuilder]), made when first used.
@export var animal := ""
@export_file("*.json") var human_spec := ""
var _face_shapes: Array = []       # [mesh, blend index, "blink"/"mouth"]
## Expression blend shapes ("smile", "frown", "angry", "surprise", "blink", "jawopen"):
## name -> Array of [mesh, blend index]. Scene Builder's realistic people have them.
var _expr_shapes: Dictionary = {}
var _expr_now: Dictionary = {}     # eased shape weights
var _expr_last_t := -1.0

## Expression (SketchCharacter.EXPRESSIONS) -> blend shape weights.
const EXPRESSION_SHAPES := {
	"Neutral": {}, "Happy": {"smile": 0.85}, "Laughing": {"smile": 1.0, "jawopen": 0.3}, "Proud": {"smile": 0.55},
	"Smirk": {"smile": 0.4}, "Hopeful": {"smile": 0.35, "frown": 0.25}, "Sad": {"frown": 0.85},
	"Crying": {"frown": 1.0, "blink": 0.4}, "Ashamed": {"frown": 0.55, "blink": 0.3}, "Worried": {"frown": 0.6},
	"Scared": {"surprise": 0.75, "frown": 0.35}, "Shocked": {"surprise": 1.0}, "Angry": {"angry": 0.9},
	"Determined": {"angry": 0.45}, "Tired": {"blink": 0.45}, "Asleep": {"blink": 1.0},
}
var _built := false


func _ready() -> void:
	ensure_built()


func ensure_built() -> void:
	if _built:
		return
	_built = true
	add_to_group(&"imported_characters")
	# Scene Builder's own people are built from a description when first used.
	if not animal.is_empty() and get_child_count() == 0:
		var beast := AnimalBuilder.make_model({"species": animal})
		if beast:
			add_child(beast)
	if not human_spec.is_empty() and get_child_count() == 0:
		var model := HumanBuilder.build(HumanBuilder.load_spec(human_spec))
		if model:
			add_child(model)
	for child in get_children():
		if child is Node3D and _model == null:
			_model = child
	_body = _model
	if _model == null:
		return
	# avatars on the MakeHuman body (Avatar Studio, the 1.22 people) get the realistic skin
	if not _model.has_meta("human_motion") and not _model.has_meta("animal") and _uses_makehuman_body(_model):
		HumanBuilder.upgrade_skin(_model)
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_player = players[0]
		# The timeline drives the pose; the player must never play by itself.
		_player.stop()
		if "active" in _player:
			_player.set("active", false)
		for clip_name in _player.get_animation_list():
			var clip := _player.get_animation(clip_name)
			if clip != null and clip.get_track_count() > 0:
				_clips[str(clip_name)] = clip
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		skeletons.sort_custom(func(a: Node, b: Node) -> bool: return (a as Skeleton3D).get_bone_count() > (b as Skeleton3D).get_bone_count())
		_skeleton = skeletons[0]
		for bone in _skeleton.get_bone_count():
			_bone_lookup[canonical_bone(_skeleton.get_bone_name(bone))] = bone
		_jaw = int(_bone_lookup.get("jaw", -1))
		if _jaw >= 0:
			_jaw_rest = _skeleton.get_bone_rest(_jaw).basis.get_rotation_quaternion()
		for k in range(1, skeletons.size()):
			var follower := skeletons[k] as Skeleton3D
			var from := PackedInt32Array()
			var to := PackedInt32Array()
			for bone in follower.get_bone_count():
				var main_bone := _skeleton.find_bone(follower.get_bone_name(bone))
				if main_bone >= 0:
					from.append(main_bone)
					to.append(bone)
			if not to.is_empty():
				_followers.append([follower, from, to])
		# Scene Builder's own people share one motion-capture library, fitted
		# to each body through the rig it was recorded on.
		if _model.has_meta("human_motion"):
			var human := HumanBuilder.motion_pack()
			for clip_name in human.get("clips", {}):
				_clips[clip_name] = human["clips"][clip_name]
				_pack_clips[clip_name] = {"clip": human["clips"][clip_name], "rests": human["rests"], "dirs": human["dirs"], "hips_y": human["hips_y"]}
		var packs := animation_packs() if not _model.has_meta("animal") else {}
		for clip_name in packs:
			if not _clips.has(clip_name):
				_clips[clip_name] = packs[clip_name]["clip"]
				_pack_clips[clip_name] = packs[clip_name]
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if instance.mesh == null:
			continue
		for i in instance.mesh.get_blend_shape_count():
			var shape_name := str(instance.mesh.get_blend_shape_name(i)).to_lower().replace(" ", "")
			for word in BLINK_WORDS:
				if shape_name.contains(word):
					_face_shapes.append([instance, i, "blink"])
			for word in MOUTH_WORDS:
				if shape_name == word or (word.length() > 2 and shape_name.contains(word)):
					_face_shapes.append([instance, i, "mouth"])
			if shape_name in ["smile", "frown", "angry", "surprise", "blink", "jawopen"]:
				if not _expr_shapes.has(shape_name):
					_expr_shapes[shape_name] = []
				(_expr_shapes[shape_name] as Array).append([instance, i])
	_model_base_scale = _model.scale
	if has_expressions():
		_add_fill_light()
	if not source_path.is_empty():
		apply_look(load_look(source_path))


static func _uses_makehuman_body(model: Node) -> bool:
	if model.scene_file_path.begins_with("res://assets/people/"):
		return true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var mat := mi.get_active_material(0)
		var n := ((mat.resource_name if mat else "") + " " + String(mi.name)).to_lower()
		if n.contains("human.body") or (String(mi.name).to_lower() == "base" and mi.mesh.get_surface_count() == 1) or n.contains("_skin"):
			if mi.mesh.surface_get_array_len(0) > 10000:
				return true
	return false


## "mixamorig:LeftArm", "mixamorig_LeftArm", "DEF-left_arm" → "leftarm".
static func simple_bone_name(bone_name: String) -> String:
	var n := bone_name.to_lower()
	for prefix in ["mixamorig:", "mixamorig_", "mixamorig", "def-", "def_", "armature_", "bip01_", "bip01 "]:
		if n.begins_with(prefix):
			n = n.substr(prefix.length())
	return n.replace("_", "").replace("-", "").replace(" ", "").replace(".", "")


## A common name for a bone across rig styles (Mixamo, Unreal/MPFB game engine,
## Godot humanoid), so animation packs find the matching bone.
static func canonical_bone(bone_name: String) -> String:
	var n := simple_bone_name(bone_name)
	if BONE_ALIASES.has(n):
		return BONE_ALIASES[n]
	var finger := RegEx.create_from_string("^(thumb|index|middle|ring|pinky)0?([1-3])(l|r)$").search(n)
	if finger:
		var side := "left" if finger.get_string(3) == "l" else "right"
		return "%shand%s%s" % [side, finger.get_string(1), finger.get_string(2)]
	return n


## Every clip in the animation packs folder, named after its file when the
## clip itself has a generic name (Mixamo downloads are all "mixamo.com").
## Result: title -> { "clip": Animation, "rests": {bone: [global, parent global]}, "hips_y" }.
static func animation_packs() -> Dictionary:
	var out := {}
	var dir := DirAccess.open(ANIMATIONS_DIR)
	if dir == null:
		return out
	for file_name in dir.get_files():
		if not RuntimeModelLoader.EXTENSIONS.has(file_name.get_extension().to_lower()):
			continue
		var path := ANIMATIONS_DIR + file_name
		if not _pack_cache.has(path):
			_pack_cache[path] = _read_pack(path)
		var pack: Dictionary = _pack_cache[path]
		var clips: Dictionary = pack.get("clips", {})
		for clip_name in clips:
			var title := file_name.get_basename().capitalize()
			if clips.size() > 1 and not GENERIC_CLIP_NAMES.has(str(clip_name).to_lower()):
				title = str(clip_name)
			out[title] = {"clip": clips[clip_name], "rests": pack.get("rests", {}), "dirs": pack.get("dirs", {}), "hips_y": pack.get("hips_y", 1.0)}
	return out


static func _read_pack(path: String) -> Dictionary:
	var clips := {}
	var rests := {}
	var hips_y := 1.0
	var root := RuntimeModelLoader.read_file(path)
	if root == null:
		return {}
	for player in root.find_children("*", "AnimationPlayer", true, false):
		var anim_player := player as AnimationPlayer
		for clip_name in anim_player.get_animation_list():
			var clip := anim_player.get_animation(clip_name)
			if clip and _moves_bones(clip):
				clips[str(clip_name)] = clip.duplicate(true)
	var dirs := {}
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		skeletons.sort_custom(func(a: Node, b: Node) -> bool: return (a as Skeleton3D).get_bone_count() > (b as Skeleton3D).get_bone_count())
		var skeleton := skeletons[0] as Skeleton3D
		var frame := model_rotation(skeleton, root)
		for bone in skeleton.get_bone_count():
			var parent := skeleton.get_bone_parent(bone)
			var own := frame * skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion()
			var up := frame * (skeleton.get_bone_global_rest(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY)
			var canon := canonical_bone(skeleton.get_bone_name(bone))
			rests[canon] = [own, up]
			if canon == "hips":
				hips_y = maxf(absf(skeleton.get_bone_global_rest(bone).origin.y), 0.01)
		dirs = bone_directions(skeleton, root)
	root.free()
	return {"clips": clips, "rests": rests, "dirs": dirs, "hips_y": hips_y}


## True if [param clip] turns or moves bones (a body animation). Clips that only
## morph a mesh (e.g. a baked "frame_0001…" shape sequence) can't be put on a character.
static func _moves_bones(clip: Animation) -> bool:
	for i in clip.get_track_count():
		var kind := clip.track_get_type(i)
		if kind == Animation.TYPE_ROTATION_3D or kind == Animation.TYPE_POSITION_3D:
			return true
	return false


## Rotation of a skeleton inside its model (FBX files often turn the armature).
static func model_rotation(skeleton: Skeleton3D, root: Node) -> Quaternion:
	var q := Quaternion.IDENTITY
	var node: Node = skeleton
	while node != null and node != root:
		if node is Node3D:
			q = (node as Node3D).transform.basis.orthonormalized().get_rotation_quaternion() * q
		node = node.get_parent()
	return q


## Direction (in model space) each [constant ALIGN_CHAIN] bone points in its rest pose.
static func bone_directions(skeleton: Skeleton3D, root: Node) -> Dictionary:
	var frame := model_rotation(skeleton, root)
	var by_canon := {}
	for bone in skeleton.get_bone_count():
		var canon := canonical_bone(skeleton.get_bone_name(bone))
		if not by_canon.has(canon):
			by_canon[canon] = bone
	# [bone, from, to]: the bone points from one joint to the other.
	var pairs: Array = []
	for canon in ALIGN_CHAIN:
		pairs.append([canon, canon, ALIGN_CHAIN[canon]])
	for side in ["left", "right"]:
		for finger in FINGERS:
			var joint := "%shand%s" % [side, finger]
			pairs.append([joint + "1", joint + "1", joint + "2"])
			pairs.append([joint + "2", joint + "2", joint + "3"])
			pairs.append([joint + "3", joint + "2", joint + "3"])  # tip: same way as the joint before
	var out := {}
	for pair in pairs:
		if not (by_canon.has(pair[1]) and by_canon.has(pair[2])):
			continue
		var from := skeleton.get_bone_global_rest(int(by_canon[pair[1]])).origin
		var to := skeleton.get_bone_global_rest(int(by_canon[pair[2]])).origin
		var dir := frame * (to - from)
		if dir.length() > 0.0001:
			out[pair[0]] = dir.normalized()
	return out


static func forget_packs() -> void:
	_pack_cache.clear()


# --- Look (Avatar Studio) --------------------------------------------------------

static func look_path(model_path: String) -> String:
	return model_path.get_basename() + ".look.json"


## Saved look of a model: { "height": 1.0, "tints": {key: [r,g,b]}, "hidden": [names] }.
static func load_look(model_path: String) -> Dictionary:
	var path := look_path(model_path)
	if model_path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


static func save_look(model_path: String, look: Dictionary) -> void:
	var file := FileAccess.open(look_path(model_path), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(look, "\t"))
		file.close()


## Every mesh part with its material slots: [{ "node", "name", "surfaces": [{ "key", "label", "color" }] }].
func parts() -> Array:
	ensure_built()
	var out: Array = []
	if _model == null:
		return out
	for found in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var surfaces: Array = []
		for i in mesh_instance.mesh.get_surface_count():
			var any_material := mesh_instance.mesh.surface_get_material(i)
			var material := any_material as BaseMaterial3D
			var label := any_material.resource_name if any_material and not any_material.resource_name.is_empty() else ""
			if label.is_empty() and mesh_instance.mesh is ArrayMesh:
				label = str((mesh_instance.mesh as ArrayMesh).surface_get_name(i))
			if label.is_empty():
				label = "Material %d" % (i + 1)
			var col := Color.WHITE
			if material:
				col = material.albedo_color
			elif any_material is ShaderMaterial:
				col = _shader_colour(any_material as ShaderMaterial)
			surfaces.append({"key": "%s/%d" % [mesh_instance.name, i], "label": label, "color": col})
		out.append({"node": mesh_instance, "name": str(mesh_instance.name), "surfaces": surfaces})
	return out


## Applies a look (tints multiply the original colours/textures; hidden parts
## disappear; height scales the whole character).
func apply_look(look: Dictionary) -> void:
	ensure_built()
	_look = look.duplicate(true)
	if _model == null:
		return
	var height := clampf(float(look.get("height", 1.0)), 0.5, 1.5)
	_model.scale = _model_base_scale * height
	# Clothes imported from Avaturn & co. (Avatar Studio avatars; Scene Builder's own
	# people get theirs when they are built)
	var worn: Array = look.get("wardrobe", [])
	if not _model.has_meta("human_motion") and not _model.has_meta("animal"):
		if worn != _worn:
			WardrobeItem.undress_avatar(_model)
			_wardrobe_slots = {}
			if not worn.is_empty():
				_wardrobe_slots = WardrobeItem.dress_avatar(_model, worn)["slots"]
			_worn = worn.duplicate()
	var tints: Dictionary = look.get("tints", {})
	var hidden: Array = look.get("hidden", [])
	# Clothes are pushed out a few millimetres so the skin underneath never
	# pokes through (MPFB normally cuts the body away under clothes, which
	# a wardrobe build can't do).
	var fit := clampf(float(look.get("clothes_fit", 0.005)), 0.0, 0.03)
	var all_parts := parts()
	var body: MeshInstance3D = null
	var most := -1
	for part in all_parts:
		var candidate: MeshInstance3D = part["node"]
		var count := candidate.mesh.get_faces().size()
		if count > most:
			most = count
			body = candidate
	for part in all_parts:
		var mesh_instance: MeshInstance3D = part["node"]
		mesh_instance.visible = not hidden.has(part["name"]) and not _covered_by_wardrobe(mesh_instance, body)
		var clothing := mesh_instance != body and is_clothing(str(part["name"]))
		for i in mesh_instance.mesh.get_surface_count():
			var key := "%s/%d" % [mesh_instance.name, i]
			var current := mesh_instance.get_surface_override_material(i)
			if current and current.has_meta("sb_skin"):
				# Scene Builder's skin on an avatar: a tint changes its tone
				if tints.has(key):
					var tt: Array = tints[key]
					(current as ShaderMaterial).set_shader_parameter("tone", Color(float(tt[0]), float(tt[1]), float(tt[2])))
				continue
			var shader_original := mesh_instance.mesh.surface_get_material(i) as ShaderMaterial
			if shader_original:
				# Scene Builder's own people: colours are shader settings.
				if tints.has(key):
					var shader_copy := shader_original.duplicate() as ShaderMaterial
					var t: Array = tints[key]
					_set_shader_colour(shader_copy, Color(float(t[0]), float(t[1]), float(t[2])))
					mesh_instance.set_surface_override_material(i, shader_copy)
				else:
					mesh_instance.set_surface_override_material(i, null)
				continue
			var original := mesh_instance.mesh.surface_get_material(i) as BaseMaterial3D
			if original and (tints.has(key) or (clothing and fit > 0.0)):
				var copy := original.duplicate() as BaseMaterial3D
				if tints.has(key):
					var tint: Array = tints[key]
					copy.albedo_color = Color(float(tint[0]), float(tint[1]), float(tint[2]), original.albedo_color.a)
					if copy.emission_enabled:
						copy.emission = copy.albedo_color
				if clothing and fit > 0.0:
					copy.grow = true
					copy.grow_amount = fit
				mesh_instance.set_surface_override_material(i, copy)
			else:
				mesh_instance.set_surface_override_material(i, null)


## The avatar's own clothes / hair / shoes hidden by imported pieces of the same kind.
func _covered_by_wardrobe(mi: MeshInstance3D, body: MeshInstance3D) -> bool:
	if _wardrobe_slots.is_empty() or mi == body or mi.has_meta("sb_wardrobe"):
		return false
	var n := String(mi.name).to_lower()
	for w in ["eye", "brow", "lash", "teeth", "tongue", "mouth"]:
		if n.contains(w):
			return false
	var is_hair := n.contains("hair") or n.contains("beard") or n.begins_with("hair-")
	var is_shoe := false
	for w in WardrobeItem.SHOE_WORDS:
		if n.contains(w):
			is_shoe = true
	if is_hair:
		return _wardrobe_slots.has("hair")
	if is_shoe:
		return _wardrobe_slots.has("shoes")
	return _wardrobe_slots.has("top") or _wardrobe_slots.has("bottom")


## True for clothing pieces (not the body, eyes, brows, lashes, teeth, tongue, mouth or hair).
## Recolours the parts named like [param part] ("shirt", "trousers", "shoes", "hair")
## - for Scene Builder's realistic people, whose clothes and hair textures are
## neutral so a tint becomes their colour. Returns how many parts changed.
func tint_parts(part: String, colour: Color) -> int:
	ensure_built()
	if _model and _model.has_meta("animal"):
		return _tint_animal(part, colour)
	var words: Dictionary = {
		"shirt": ["shirt"], "top": ["shirt"], "hoodie": ["shirt"], "sweater": ["shirt"], "jumper": ["shirt"],
		"coat": ["shirt"], "raincoat": ["shirt"], "kurta": ["shirt"], "jacket": ["shirt"], "tshirt": ["shirt"], "t-shirt": ["shirt"],
		"pants": ["trousers"], "trousers": ["trousers"], "jeans": ["trousers"], "shorts": ["trousers"], "skirt": ["trousers"],
		"shoes": ["shoe_", "shoes"], "boots": ["shoe_", "shoes"], "trainers": ["shoe_", "shoes"], "sneakers": ["shoe_", "shoes"],
		"hair": ["hair"], "beard": ["beard"], "skin": ["body"], "eyes": ["eyes"],
	}
	var wanted: Array = words.get(part.to_lower(), [])
	if wanted.is_empty():
		return 0
	var look := current_look()
	var tints: Dictionary = look.get("tints", {})
	var changed := 0
	for p in parts():
		var lower := str(p["name"]).to_lower()
		var hit := false
		for w in wanted:
			if lower.begins_with(str(w)):
				hit = true
		if not hit:
			continue
		for surface in p["surfaces"]:
			# The sole and the hair tie keep their own colours.
			var label := str(surface["label"]).to_lower()
			if label.begins_with("sole") or label.begins_with("hairtie"):
				continue
			if part.to_lower() == "skin" and label != "skin":
				continue
			var c := colour
			var mi: MeshInstance3D = p["node"]
			var is_shader := mi.mesh.surface_get_material(int(str(surface["key"]).get_slice("/", 1))) is ShaderMaterial
			if part.to_lower() == "hair" and not is_shader:
				c = Color(minf(c.r * 1.3, 1.0), minf(c.g * 1.3, 1.0), minf(c.b * 1.3, 1.0))
			tints[surface["key"]] = [c.r, c.g, c.b]
			changed += 1
	if changed > 0:
		look["tints"] = tints
		if not look.has("clothes_fit"):
			look["clothes_fit"] = 0.0
		apply_look(look)
	return changed


## The main colour setting of one of Scene Builder's shader materials.
static func _shader_colour(m: ShaderMaterial) -> Color:
	for p in ["color", "tone", "iris"]:
		var v: Variant = m.get_shader_parameter(p)
		if v is Color:
			return v
		if v is Vector3:
			return Color((v as Vector3).x, (v as Vector3).y, (v as Vector3).z)
	return Color.WHITE


static func _set_shader_colour(m: ShaderMaterial, c: Color) -> void:
	for p in ["color", "tone", "iris"]:
		if m.get_shader_parameter(p) != null:
			m.set_shader_parameter(p, c)
			return


static func is_clothing(part_name: String) -> bool:
	var n := part_name.to_lower()
	if n.begins_with("clothes-") or n.begins_with("outfit-"):
		return true
	for word in ["body", "human", "eye", "brow", "lash", "teeth", "tooth", "tongue", "mouth", "hair", "skin", "base"]:
		if n.contains(word):
			return false
	return true


func current_look() -> Dictionary:
	return _look.duplicate(true)


## Re-reads the saved look (after Avatar Studio saved changes).
func reload_look() -> void:
	apply_look(load_look(source_path))


func size_factor() -> float:
	return clampf(float(_look.get("height", 1.0)), 0.5, 1.5)


## How the model is rigged (shown in Avatar Studio):
## { "skeletons": int, "followers": int, "loose": names of parts not attached to any skeleton }.
func rig_report() -> Dictionary:
	ensure_built()
	var loose := PackedStringArray()
	if _model:
		for found in _model.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := found as MeshInstance3D
			if mesh_instance.skin == null and not (mesh_instance.get_parent() is BoneAttachment3D):
				loose.append(str(mesh_instance.name))
	return {"skeletons": 1 + _followers.size() if _skeleton else 0, "followers": _followers.size(), "loose": loose}


## Copies the main skeleton's pose onto the extra skeletons, bone by bone.
func _sync_followers() -> void:
	if _skeleton == null:
		return
	for entry in _followers:
		var follower: Skeleton3D = entry[0]
		if not is_instance_valid(follower):
			continue
		var from: PackedInt32Array = entry[1]
		var to: PackedInt32Array = entry[2]
		for i in to.size():
			follower.set_bone_pose_rotation(to[i], _skeleton.get_bone_pose_rotation(from[i]))
			follower.set_bone_pose_position(to[i], _skeleton.get_bone_pose_position(from[i]))
			follower.set_bone_pose_scale(to[i], _skeleton.get_bone_pose_scale(from[i]))


const _BONE_FOR_JOINT := {
	"Head": "head", "Neck": "neck", "Chest": "spine2", "Spine": "spine", "Hips": "hips",
	"Left shoulder": "leftarm", "Left elbow": "leftforearm", "Left wrist": "lefthand",
	"Right shoulder": "rightarm", "Right elbow": "rightforearm", "Right wrist": "righthand",
	"Left hip": "leftupleg", "Left knee": "leftleg", "Left ankle": "leftfoot",
	"Right hip": "rightupleg", "Right knee": "rightleg", "Right ankle": "rightfoot"}


func apply_manual_pose(pose: Dictionary) -> void:
	if _skeleton == null:
		return
	for joint in pose:
		var bone: int = _bone_lookup.get(_BONE_FOR_JOINT.get(joint, ""), -1)
		if bone < 0:
			continue
		var euler: Vector3 = pose[joint]
		var extra := Quaternion.from_euler(Vector3(deg_to_rad(euler.x), deg_to_rad(euler.y), deg_to_rad(euler.z)))
		_skeleton.set_bone_pose_rotation(bone, _skeleton.get_bone_pose_rotation(bone) * extra)


## Where each joint points (the next bone); "" = carry on in the bone's direction.
const _TIP_FOR_JOINT := {
	"Head": "", "Neck": "head", "Chest": "neck", "Spine": "spine2", "Hips": "spine2",
	"Left shoulder": "leftforearm", "Left elbow": "lefthand", "Left wrist": "lefthandmiddle1",
	"Right shoulder": "rightforearm", "Right elbow": "righthand", "Right wrist": "righthandmiddle1",
	"Left hip": "leftleg", "Left knee": "leftfoot", "Left ankle": "lefttoebase",
	"Right hip": "rightleg", "Right knee": "rightfoot", "Right ankle": "righttoebase"}


func _joint_bone(joint: String) -> int:
	ensure_built()
	if _skeleton == null:
		return -1
	return int(_bone_lookup.get(_BONE_FOR_JOINT.get(joint, ""), -1))


## How high the hips' contact point sits above this character's feet in a
## still pose ("Sit", "Lie Down", "Kneel"), measured from the model's own clip
## so realistic people sit on a cushion rather than sinking into it.
## Not including this node's own scale (the caller knows the real size).
func pose_hip_height(pose_name: String) -> float:
	ensure_built()
	if _skeleton == null:
		return -1.0
	var hips := int(_bone_lookup.get("hips", -1))
	if hips < 0:
		return -1.0
	var words := {"Sit": ["sit"], "Lie Down": ["lie", "lying", "sleep"], "Kneel": ["kneel"]}
	if not words.has(pose_name):
		return -1.0
	var clip := pose_name if _clips.has(pose_name) else _find_clip(PackedStringArray(words[pose_name]))
	if clip.is_empty():
		return -1.0
	var length := _clip_length(clip)
	# The skeleton's place inside this character (its parents' transforms).
	var into_root := Transform3D.IDENTITY
	var node: Node = _skeleton
	while node != null and node != self:
		if node is Node3D:
			into_root = (node as Node3D).transform * into_root
		node = node.get_parent()
	var lowest := INF
	for f in [0.5, 0.75, 0.95]:
		_skeleton.reset_bone_poses()
		_apply(_sample(clip, length * f))
		var hip_y := (into_root * _skeleton.get_bone_global_pose(hips).origin).y
		lowest = minf(lowest, hip_y)
	_skeleton.reset_bone_poses()
	if not is_finite(lowest) or lowest <= 0.0:
		return -1.0
	# The hips joint is inside the pelvis: the body under it is ~9 cm thick
	# when sitting (lying on the back, the caller adds its own thickness).
	var under := 0.09 if pose_name == "Sit" else 0.0
	return maxf(lowest - under, 0.05)


func _bone_world(bone: int) -> Vector3:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin


func joint_position(joint: String) -> Vector3:
	var bone := _joint_bone(joint)
	return _bone_world(bone) if bone >= 0 and _skeleton.is_inside_tree() else Vector3.INF


func joint_tip(joint: String) -> Vector3:
	var bone := _joint_bone(joint)
	if bone < 0 or not _skeleton.is_inside_tree():
		return Vector3.INF
	var here := _bone_world(bone)
	var child := int(_bone_lookup.get(_TIP_FOR_JOINT.get(joint, ""), -1))
	if child >= 0:
		return _bone_world(child)
	# No next bone (head, or a hand without fingers): carry on in the direction
	# the bone pointed at rest, turned with the bone (so the tip follows it).
	var parent := _skeleton.get_bone_parent(bone)
	var rest := _skeleton.get_bone_global_rest(bone)
	var rest_along := (rest.origin - _skeleton.get_bone_global_rest(parent).origin) if parent >= 0 else Vector3.UP * 0.1
	var local_dir := rest.basis.inverse() * rest_along
	var world_dir := _skeleton.global_basis * (_skeleton.get_bone_global_pose(bone).basis * local_dir)
	return here + world_dir.normalized() * maxf((_skeleton.global_basis * rest_along).length() * 0.8, 0.08)


func pose_drag_begin(joint: String, manual: Vector3) -> Dictionary:
	var bone := _joint_bone(joint)
	if bone < 0:
		return {}
	var world := _skeleton.global_basis.orthonormalized().get_rotation_quaternion() * _skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	return {"manual": manual, "world": world,
		"extra": Quaternion.from_euler(Vector3(deg_to_rad(manual.x), deg_to_rad(manual.y), deg_to_rad(manual.z)))}


## The bone's rotation is (action rotation · hand rotation), so turning the bone
## by W in world space changes the hand rotation to extra · W⁻¹·turn·W (W = the
## bone's world rotation when the drag began).
func pose_drag_euler(state: Dictionary, world_turn: Quaternion) -> Vector3:
	if state.is_empty():
		return Vector3.ZERO
	var world: Quaternion = state["world"]
	var extra: Quaternion = (state["extra"] as Quaternion) * world.inverse() * world_turn * world
	var euler := extra.normalized().get_euler()
	return unwrap_degrees(Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)), state["manual"])


func has_animations() -> bool:
	ensure_built()
	return not _clips.is_empty()


func action_names() -> PackedStringArray:
	ensure_built()
	var names := PackedStringArray([MotionLibrary.AUTO, POSE_ONLY])
	var sorted := _clips.keys()
	sorted.sort()
	for clip_name in sorted:
		names.append(clip_name)
	return names


## Animals walk and run with their own stride (set by [AnimalMotion]).
func _locomotion(t: float, motion: CharacterMotion) -> Dictionary:
	if _model == null or not _model.has_meta("animal_gait"):
		return super._locomotion(t, motion)
	var gv: Vector3 = _model.get_meta("animal_gait")
	gv *= absf(_model.scale.x)
	var v := motion.speed_at(t)
	var d := motion.distance_at(t)
	return {
		"moving": v > CharacterMotion.MOVING_SPEED * 0.5,
		"walk": smoothstep(0.03, 0.3, v),
		"run": smoothstep(gv.z * 0.55, gv.z * 0.85, v),
		"walk_phase": d / maxf(gv.x, 0.05),
		"run_phase": d / maxf(gv.y, 0.05),
	}


func action_hint(action: String) -> String:
	if action == MotionLibrary.AUTO:
		return "Plays the idle, walk or run clip to match how fast the character moves"
	return "Clip from the imported model"


func evaluate(t: float, motion: CharacterMotion) -> void:
	ensure_built()
	if _clips.is_empty():
		# No animations at all: still apply hand poses, lip sync and facing.
		if _skeleton:
			_skeleton.reset_bone_poses()
		apply_manual_pose(with_preview(motion.pose_at(t)))
		_sync_followers()
		_apply_facing(t, motion)
		_animate_face(t, POSE_ONLY, 0.0, motion)
		return
	var state := motion.action_state(t)
	var since := t - float(state["start"])
	var pose := _pose_for(str(state["action"]), since, t, motion)
	var previous := str(state["previous"])
	if not previous.is_empty() and since < MotionLibrary.BLEND_TIME:
		var before := _pose_for(previous, t - float(state["previous_start"]), t, motion)
		pose = _blend(before, pose, smoothstep(0.0, MotionLibrary.BLEND_TIME, since))
	# Start from the rest pose every time: bones no clip moves would otherwise
	# keep the previous frame's hand rotation and add the new one on top.
	if _skeleton:
		_skeleton.reset_bone_poses()
	_apply(pose)
	if pose.is_empty():
		_relax_arms()   # no idle clip: don't stand in a T-pose
	apply_manual_pose(with_preview(motion.pose_at(t)))
	_sync_followers()
	_apply_facing(t, motion)
	_animate_face(t, str(state["action"]), since, motion)


## Realistic people get a little self-light (like a film's fill light), so faces
## never sink into black in dim, foggy or night scenes.
func _add_fill_light() -> void:
	for found in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var original := mesh_instance.mesh.surface_get_material(i) as StandardMaterial3D
			if original == null or original.emission_enabled:
				continue
			var copy := original.duplicate() as StandardMaterial3D
			copy.emission_enabled = true
			copy.emission = original.albedo_color
			copy.emission_texture = original.albedo_texture
			copy.emission_energy_multiplier = 0.025
			mesh_instance.mesh.surface_set_material(i, copy)


## True if this model can show expressions (smile, frown...) with blend shapes.
func has_expressions() -> bool:
	ensure_built()
	return _expr_shapes.has("smile") or _expr_shapes.has("frown")


## Shape weights for the expression keyed at [param t] ("face" in the pose keys),
## eased in over a fraction of a second while playing.
func _expression_weights(t: float, motion: CharacterMotion) -> Dictionary:
	var target: Dictionary = {}
	if motion != null:
		var keyed: Dictionary = motion.pose_at(t)
		if keyed.has("face"):
			var index := clampi(roundi((keyed["face"] as Vector3).x), 0, SketchCharacter.EXPRESSIONS.size() - 1)
			target = EXPRESSION_SHAPES.get(SketchCharacter.EXPRESSIONS[index], {})
	var step := t - _expr_last_t
	_expr_last_t = t
	var ease := 1.0 if step <= 0.0 or step > 0.25 else clampf(step / 0.25, 0.0, 1.0)
	var out := {}
	for key in _expr_shapes:
		var now := float(_expr_now.get(key, 0.0))
		now = lerpf(now, float(target.get(key, 0.0)), ease)
		_expr_now[key] = now
		out[key] = now
	return out


## Blinks and moves the mouth (while a talking action plays) using the model's
## blend shapes, when it has them (e.g. "eyeBlink", "jawOpen", "viseme_aa").
func _animate_face(t: float, action: String, since: float, motion: CharacterMotion = null) -> void:
	var expr := _expression_weights(t, motion) if not _expr_shapes.is_empty() else {}
	for key in expr:
		if key == "blink" or key == "jawopen":
			continue
		for entry in _expr_shapes[key]:
			if is_instance_valid(entry[0]):
				(entry[0] as MeshInstance3D).set_blend_shape_value(entry[1], float(expr[key]))
	var synced := lipsync_at(t)
	var has_mouth_shape := false
	for entry in _face_shapes:
		if entry[2] == "mouth":
			has_mouth_shape = true
	# A mouth blend shape already opens the jaw; turning the jaw bone as well would open it twice.
	if _jaw >= 0 and _skeleton and not has_mouth_shape:
		var jaw_open := synced if synced >= 0.0 else 0.0
		_skeleton.set_bone_pose_rotation(_jaw, _jaw_rest * Quaternion(Vector3.RIGHT, jaw_open * 0.32))
	if _face_shapes.is_empty():
		return
	var seed_value := float(hash(name) % 97)
	var cycle := fposmod(t + seed_value * 0.37, 3.7 + fposmod(seed_value, 1.3))
	var blink := 1.0 - smoothstep(0.0, 0.07, absf(cycle - 0.08))
	var lower := action.to_lower()
	var talking := lower.contains("talk") or lower.contains("speak") or lower.contains("phone")
	var mouth := clampf(0.5 + 0.5 * sin(since * 13.0) * sin(since * 4.1 + 0.7), 0.0, 1.0) * 0.7 if talking else 0.0
	if synced >= 0.0:
		mouth = synced
	blink = maxf(blink, float(expr.get("blink", 0.0)))
	mouth = maxf(mouth, float(expr.get("jawopen", 0.0)))
	for entry in _face_shapes:
		var instance: MeshInstance3D = entry[0]
		if is_instance_valid(instance):
			instance.set_blend_shape_value(entry[1], blink if entry[2] == "blink" else mouth)


## Animals: "colour" / "coat" / "fur" sets the coat, "second colour" / "belly" / "markings" the second colour.
func _tint_animal(part: String, colour: Color) -> int:
	var key := part.to_lower()
	var param := ""
	if key in ["colour", "color", "coat", "fur", "body"]:
		param = "color"
	elif key in ["belly", "markings", "spots", "stripes", "second", "colour2", "color2"]:
		param = "color2"
	elif key in ["eyes", "eye"]:
		param = "eye_color"
	if param.is_empty():
		return 0
	var n := 0
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		for i in inst.get_surface_override_material_count():
			var m := inst.get_surface_override_material(i)
			while m is ShaderMaterial:
				var sm := m as ShaderMaterial
				if param in ["color", "color2"] and int(sm.get_shader_parameter("part") if sm.get_shader_parameter("part") != null else 0) != 0:
					break
				sm.set_shader_parameter(param, colour)
				n += 1
				m = sm.next_pass
	return n


## Lowers the arms from a T- or A-pose to hang at the sides (used when the
## character stands still and has no idle animation).
func _relax_arms() -> void:
	if _skeleton == null:
		return
	var hips := int(_bone_lookup.get("hips", -1))
	var up := (_skeleton.global_basis.inverse() * Vector3.UP).normalized()
	for side in ["left", "right"]:
		var arm := int(_bone_lookup.get(side + "arm", -1))
		var fore := int(_bone_lookup.get(side + "forearm", -1))
		var hand := int(_bone_lookup.get(side + "hand", -1))
		if arm < 0 or fore < 0:
			continue
		var a := _skeleton.get_bone_global_pose(arm)
		var along := (_skeleton.get_bone_global_pose(fore).origin - a.origin).normalized()
		var outward := a.origin - (_skeleton.get_bone_global_pose(hips).origin if hips >= 0 else Vector3.ZERO)
		outward -= up * outward.dot(up)
		outward = outward.normalized() if outward.length() > 0.0001 else Vector3.ZERO
		var wanted := (-up + outward * 0.12).normalized()
		if along.dot(wanted) > 0.98:
			continue   # already hanging down
		var turn := Quaternion(along, wanted)
		var parent := _skeleton.get_bone_parent(arm)
		var parent_rot := _skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
		_skeleton.set_bone_pose_rotation(arm, (parent_rot.inverse() * turn * a.basis.get_rotation_quaternion()).normalized())
		# A slight, natural bend at the elbow, towards the front of the body.
		if hand >= 0:
			var f := _skeleton.get_bone_global_pose(fore)
			var fore_dir := (_skeleton.get_bone_global_pose(hand).origin - f.origin).normalized()
			var front := (_skeleton.global_basis.inverse() * (global_basis * Vector3.FORWARD * -1.0)).normalized()
			if _body:
				front = (_skeleton.global_basis.inverse() * (_body.global_basis.z)).normalized()
			var bent := (fore_dir + front * 0.15).normalized()
			var bend := Quaternion(fore_dir, bent)
			var fore_parent := _skeleton.get_bone_global_pose(arm).basis.get_rotation_quaternion()
			_skeleton.set_bone_pose_rotation(fore, (fore_parent.inverse() * bend * f.basis.get_rotation_quaternion()).normalized())


# --- Posing ----------------------------------------------------------------------

func _pose_for(action: String, local_time: float, t: float, motion: CharacterMotion) -> Dictionary:
	if action == MotionLibrary.AUTO:
		var loco := _locomotion(t, motion)
		var idle_clip := _find_clip(IDLE_WORDS)
		var walk_clip := _find_clip(WALK_WORDS)
		var run_clip := _find_clip(RUN_WORDS)
		var pose := _sample(idle_clip, t) if not idle_clip.is_empty() else {}
		if not walk_clip.is_empty() and float(loco["walk"]) > 0.0:
			var walk := _sample(walk_clip, float(loco["walk_phase"]) * _clip_length(walk_clip))
			pose = walk if pose.is_empty() else _blend(pose, walk, loco["walk"])
		if not run_clip.is_empty() and float(loco["run"]) > 0.0:
			var run := _sample(run_clip, float(loco["run_phase"]) * _clip_length(run_clip))
			pose = run if pose.is_empty() else _blend(pose, run, loco["run"])
		return pose
	if not _clips.has(action):
		return {}
	return _sample(action, local_time)


## The plainest clip whose name has one of [param words]: "Walking" before
## "Strut Walking"; clips that go backwards are never used for Auto.
func _find_clip(words: PackedStringArray) -> String:
	var best := ""
	for clip_name in _clips:
		var lower := str(clip_name).to_lower()
		if lower.contains("backward") or lower.contains("reverse"):
			continue
		for word in words:
			if lower.contains(word) and (best.is_empty() or lower.length() < best.length()):
				best = clip_name
	return best


func _clip_length(clip_name: String) -> float:
	var clip: Animation = _clips.get(clip_name)
	return clip.length if clip else 1.0


## Samples every transform track of a clip at [param time] (looping).
## Result: key -> { "target", "bone", "kind", "value" }.
func _sample(clip_name: String, time: float) -> Dictionary:
	var clip: Animation = _clips.get(clip_name)
	if clip == null:
		return {}
	var local := fposmod(time, clip.length) if clip.length > 0.0 else 0.0
	var pose := {}
	for binding in _bindings_for(clip_name):
		var track: int = binding["track"]
		var kind := int(binding["kind"])
		var value: Variant = null
		if kind == Animation.TYPE_ROTATION_3D:
			if binding.has("fixed"):
				pose[binding["key"]] = {"target": binding["target"], "bone": binding["bone"], "kind": kind, "value": binding["fixed"]}
				continue
			var q: Quaternion = clip.rotation_track_interpolate(track, local)
			if binding.has("pre"):
				q = (binding["pre"] as Quaternion) * q * (binding["post"] as Quaternion)
			value = q
		elif kind == Animation.TYPE_POSITION_3D:
			var p: Vector3 = clip.position_track_interpolate(track, local)
			if binding.has("relative_from"):
				var rest_pos: Vector3 = binding["rest"]
				var start: Vector3 = binding["relative_from"]
				p = Vector3(rest_pos.x, rest_pos.y + (p.y - start.y) * float(binding.get("height_scale", 1.0)), rest_pos.z)
			elif binding["strip_root"]:
				var rest: Vector3 = binding["rest"]
				p = Vector3(rest.x, p.y, rest.z)
			value = p
		else:
			value = clip.scale_track_interpolate(track, local)
		pose[binding["key"]] = {"target": binding["target"], "bone": binding["bone"], "kind": binding["kind"], "value": value}
	return pose


func _bindings_for(clip_name: String) -> Array:
	if _bindings.has(clip_name):
		return _bindings[clip_name]
	var list: Array = []
	var clip: Animation = _clips[clip_name]
	if _pack_clips.has(clip_name):
		_bindings[clip_name] = _pack_bindings(clip, _pack_clips[clip_name])
		return _bindings[clip_name]
	var root: Node = _player.get_node_or_null(_player.root_node) if _player else null
	if root != null:
		for track in clip.get_track_count():
			var kind := int(clip.track_get_type(track))
			if not (kind in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D]):
				continue
			var path := clip.track_get_path(track)
			var target := root.get_node_or_null(NodePath(path.get_concatenated_names()))
			if target == null:
				continue
			var bone := -1
			var strip_root := false
			var rest := Vector3.ZERO
			if target is Skeleton3D and path.get_subname_count() > 0:
				var skeleton := target as Skeleton3D
				bone = skeleton.find_bone(path.get_concatenated_subnames())
				if bone < 0:
					continue
				strip_root = kind == Animation.TYPE_POSITION_3D and skeleton.get_bone_parent(bone) == -1
				rest = skeleton.get_bone_rest(bone).origin
			elif not target is Node3D:
				continue
			list.append({"track": track, "kind": kind, "target": target, "bone": bone,
				"strip_root": strip_root, "rest": rest, "key": "%d:%d:%d" % [target.get_instance_id(), bone, kind]})
	_bindings[clip_name] = list
	return list


## Bindings for a clip from an animation pack: bones are matched by name
## (across rig styles) and rotations are retargeted through both rest poses:
## local = inv(parent rest) · source parent rest · source local · inv(source rest) · rest.
## The root bone keeps only its up/down motion (sitting, jumping), scaled to
## this character's hip height.
func _pack_bindings(clip: Animation, pack: Dictionary) -> Array:
	var list: Array = []
	if _skeleton == null:
		return list
	var rests: Dictionary = pack.get("rests", {})
	var source_dirs: Dictionary = pack.get("dirs", {})
	var frame := model_rotation(_skeleton, _model)
	var own_dirs := bone_directions(_skeleton, _model)
	var hips_scale := 1.0
	var rotated := {}
	for track in clip.get_track_count():
		var kind := int(clip.track_get_type(track))
		if not (kind in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D]):
			continue
		var path := clip.track_get_path(track)
		if path.get_subname_count() == 0:
			continue
		var canon := canonical_bone(path.get_concatenated_subnames())
		var bone: int = _bone_lookup.get(canon, -1)
		if bone < 0:
			continue
		var is_root := canon == "hips" or _skeleton.get_bone_parent(bone) == -1
		if kind == Animation.TYPE_POSITION_3D and not is_root:
			continue
		var binding := {"track": track, "kind": kind, "target": _skeleton, "bone": bone,
			"strip_root": false, "rest": _skeleton.get_bone_rest(bone).origin,
			"key": "%d:%d:%d" % [_skeleton.get_instance_id(), bone, kind]}
		if kind == Animation.TYPE_ROTATION_3D and rests.has(canon):
			var aligned := _aligned_rests(bone, own_dirs, source_dirs, frame)
			var source: Array = rests[canon]
			binding["pre"] = (aligned[1] as Quaternion).inverse() * (source[1] as Quaternion)
			binding["post"] = (source[0] as Quaternion).inverse() * (aligned[0] as Quaternion)
			rotated[bone] = true
		if kind == Animation.TYPE_POSITION_3D and clip.track_get_key_count(track) > 0:
			hips_scale = absf(_skeleton.get_bone_global_rest(bone).origin.y) / float(pack.get("hips_y", 1.0))
			binding["relative_from"] = clip.track_get_key_value(track, 0)
			binding["height_scale"] = clampf(hips_scale, 0.1, 10.0)
		list.append(binding)
	# Bones the clip never moves (exporters drop still tracks) still hold the
	# pack's rest pose, so lined-up limbs don't fall back to this rig's own pose.
	for bone in _skeleton.get_bone_count():
		var canon := canonical_bone(_skeleton.get_bone_name(bone))
		if rotated.has(bone) or not rests.has(canon) or int(_bone_lookup.get(canon, -1)) != bone:
			continue
		var aligned := _aligned_rests(bone, own_dirs, source_dirs, frame)
		var fixed := (aligned[1] as Quaternion).inverse() * (aligned[0] as Quaternion)
		if fixed.angle_to(_skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()) < 0.001:
			continue
		list.append({"track": -1, "kind": Animation.TYPE_ROTATION_3D, "target": _skeleton, "bone": bone,
			"fixed": fixed, "key": "%d:%d:%d" % [_skeleton.get_instance_id(), bone, Animation.TYPE_ROTATION_3D]})
	return list


## [bone's rest, its parent's rest] in model space, with this rig's limbs turned
## to match the pack's rest pose (e.g. A-pose arms raised to a T-pose).
func _aligned_rests(bone: int, own_dirs: Dictionary, source_dirs: Dictionary, frame: Quaternion) -> Array:
	var parent := _skeleton.get_bone_parent(bone)
	var canon := canonical_bone(_skeleton.get_bone_name(bone))
	var parent_canon := canonical_bone(_skeleton.get_bone_name(parent)) if parent >= 0 else ""
	var own := _align(canon, own_dirs, source_dirs) * frame * _skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion()
	var up := _align(parent_canon, own_dirs, source_dirs) * frame * (_skeleton.get_bone_global_rest(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY)
	return [own, up]


## The turn that points this rig's bone the way the pack's rest pose points it.
static func _align(canon: String, own_dirs: Dictionary, source_dirs: Dictionary) -> Quaternion:
	if not (own_dirs.has(canon) and source_dirs.has(canon)):
		return Quaternion.IDENTITY
	var from: Vector3 = own_dirs[canon]
	var to: Vector3 = source_dirs[canon]
	if from.dot(to) > 0.99999:
		return Quaternion.IDENTITY
	if from.dot(to) < -0.9999:
		return Quaternion(from.cross(Vector3.UP if absf(from.y) < 0.9 else Vector3.RIGHT).normalized(), PI)
	return Quaternion(from, to)


static func _blend(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	if a.is_empty():
		return b
	if b.is_empty():
		return a
	var out := a.duplicate()
	for key in b:
		var to: Dictionary = b[key]
		if not a.has(key):
			out[key] = to
			continue
		var from: Dictionary = a[key]
		var mixed := to.duplicate()
		if int(to["kind"]) == Animation.TYPE_ROTATION_3D:
			mixed["value"] = (from["value"] as Quaternion).slerp(to["value"], weight)
		else:
			mixed["value"] = (from["value"] as Vector3).lerp(to["value"], weight)
		out[key] = mixed
	return out


func _apply(pose: Dictionary) -> void:
	for key in pose:
		var entry: Dictionary = pose[key]
		var target: Object = entry["target"]
		if not is_instance_valid(target):
			continue
		var bone: int = entry["bone"]
		var kind: int = entry["kind"]
		if bone >= 0:
			var skeleton := target as Skeleton3D
			match kind:
				Animation.TYPE_ROTATION_3D:
					skeleton.set_bone_pose_rotation(bone, entry["value"])
				Animation.TYPE_POSITION_3D:
					skeleton.set_bone_pose_position(bone, entry["value"])
				Animation.TYPE_SCALE_3D:
					skeleton.set_bone_pose_scale(bone, entry["value"])
		else:
			var node := target as Node3D
			match kind:
				Animation.TYPE_ROTATION_3D:
					node.quaternion = entry["value"]
				Animation.TYPE_POSITION_3D:
					node.position = entry["value"]
				Animation.TYPE_SCALE_3D:
					node.scale = entry["value"]

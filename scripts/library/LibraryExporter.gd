class_name LibraryExporter
extends Node
## "Export My Library": one .zip that tells an AI (or another person) everything
## this Scene Builder has, so it can write film packages that use the user's own
## characters and props.
##
## The zip holds:
##   library.json          every character, prop, animation pack and sound, with
##                         sizes, actions, face abilities and the name to use in a script
##   AI_INSTRUCTIONS.md    the script language for this exact app version (incl. the library)
##   README_FOR_AI.md      what this export is and how to write a package that uses it
##   thumbnails/…          a picture of every character and prop
##   contact_sheets/…      pages of pictures with names, to see the whole library at a glance
##   characters/ models/ animations/   (only with "include files") the model files,
##                         with their textures shrunk so the zip stays small
##
## Add it to the scene tree, then: var report = await exporter.export_library(path, include_files)

signal progress(text: String)

const FORMAT := "scene-builder-library"
const FORMAT_VERSION := 1
const THUMB_SIZE := 256
const SHEET_COLUMNS := 5
const SHEET_ROWS := 4
const MAX_TEXTURE := 1024

var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _thumbs: Dictionary = {}   # zip path -> Image


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(THUMB_SIZE, THUMB_SIZE)
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.34, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.78)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	key.light_energy = 1.3
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, -140.0, 0.0)
	fill.light_energy = 0.45
	_viewport.add_child(fill)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	_camera.current = true
	_stage = Node3D.new()
	_viewport.add_child(_stage)


## Everything in the user's library, without writing anything (also used by tests).
## Returns { "characters": [...], "props": [...], "animation_packs": [...], "sounds": [...] }.
static func gather() -> Dictionary:
	var characters: Array = []
	var props: Array = []
	var used := {}
	for item in PropCatalog.scan():
		var category := str(item["category"])
		var path := str(item["scene_path"])
		if category == PropCatalog.MY_CHARACTERS_CATEGORY:
			characters.append({"name": _unique(str(item["display_name"]), used), "path": path, "category": category})
		elif category == PropCatalog.IMPORTED_CATEGORY or category == PropCatalog.DOWNLOADED_CATEGORY:
			props.append({"name": _unique(str(item["display_name"]), used), "path": path, "category": category,
				"credit": str(item.get("credit", ""))})
	var packs: Array = []
	var dir := DirAccess.open(ImportedCharacter.ANIMATIONS_DIR)
	if dir:
		for file_name in dir.get_files():
			if not RuntimeModelLoader.EXTENSIONS.has(file_name.get_extension().to_lower()):
				continue
			var path := ImportedCharacter.ANIMATIONS_DIR + file_name
			var clips: Dictionary = ImportedCharacter._read_pack(path).get("clips", {})
			var titles: Array = []
			for clip_name in clips:
				var title := file_name.get_basename().capitalize()
				if clips.size() > 1 and not ImportedCharacter.GENERIC_CLIP_NAMES.has(str(clip_name).to_lower()):
					title = str(clip_name)
				titles.append(title)
			packs.append({"file": file_name, "path": path, "actions": titles})
	var sounds: Array = []
	var audio := DirAccess.open(AudioTrack.AUDIO_DIR)
	if audio:
		for file_name in audio.get_files():
			# Copies made while building films get hashed names (e.g. 3f9c…e1.wav): not useful to list.
			var hashed := RegEx.create_from_string("^[0-9a-f]{12,}$").search(file_name.get_basename()) != null
			if AudioTrack.EXTENSIONS.has(file_name.get_extension().to_lower()) and not hashed:
				sounds.append({"file": file_name})
	return {"characters": characters, "props": props, "animation_packs": packs, "sounds": sounds}


static func _unique(name: String, used: Dictionary) -> String:
	var out := name
	var n := 2
	while used.has(out.to_lower()):
		out = "%s %d" % [name, n]
		n += 1
	used[out.to_lower()] = true
	return out


## Writes the export to [param zip_path]. Returns { "ok", "error", "path", "bytes",
## "characters", "props", "packs", "sounds", "files" }.
func export_library(zip_path: String, include_files: bool) -> Dictionary:
	var library := gather()
	# Written under a temporary name and renamed at the very end, so a half-finished
	# export is never mistaken for a finished one.
	var partial := zip_path + ".part"
	var packer := ZIPPacker.new()
	if packer.open(partial) != OK:
		return {"ok": false, "error": "Couldn't create %s." % zip_path}
	_thumbs.clear()
	var manifest := {
		"format": FORMAT, "format_version": FORMAT_VERSION,
		"app": "Scene Builder", "app_version": ScriptDirector.app_version(),
		"exported": Time.get_datetime_string_from_system(false, true),
		"includes_files": include_files,
		"how_to_use": "In a film script: CAST line 'Name = my character \"<name>\"' and SET line 'id = my prop \"<name>\" at <place>'. See README_FOR_AI.md.",
		"characters": [], "props": [], "animation_packs": [], "sounds": [],
	}
	var files := 0
	var total: int = (library["characters"] as Array).size() + (library["props"] as Array).size()
	var done := 0
	for item in library["characters"]:
		done += 1
		progress.emit("Looking at %s (%d of %d)…" % [item["name"], done, total])
		var info := await _describe(item, true)
		if include_files:
			info["file"] = _add_model(packer, item["path"], "characters/")
			if not str(info["file"]).is_empty():
				files += 1
				var look := ImportedCharacter.look_path(item["path"])
				if FileAccess.file_exists(look):
					_add_bytes(packer, "characters/" + look.get_file(), FileAccess.get_file_as_bytes(look))
		(manifest["characters"] as Array).append(info)
	for item in library["props"]:
		done += 1
		progress.emit("Looking at %s (%d of %d)…" % [item["name"], done, total])
		var info := await _describe(item, false)
		if include_files:
			info["file"] = _add_model(packer, item["path"], "models/")
			if not str(info["file"]).is_empty():
				files += 1
		(manifest["props"] as Array).append(info)
	for pack in library["animation_packs"]:
		var entry := {"file": pack["file"], "actions": pack["actions"]}
		if (pack["actions"] as Array).is_empty():
			entry["note"] = "Not a body animation (it doesn't move a skeleton), so characters can't use it."
		if include_files and not (pack["actions"] as Array).is_empty():
			progress.emit("Adding animation pack %s…" % pack["file"])
			entry["file"] = _add_model(packer, pack["path"], "animations/", true)
			if not str(entry["file"]).is_empty():
				files += 1
		(manifest["animation_packs"] as Array).append(entry)
	manifest["sounds"] = library["sounds"]
	progress.emit("Making contact sheets…")
	var sheets := await _contact_sheets(packer, manifest)
	manifest["contact_sheets"] = sheets
	_add_text(packer, "library.json", JSON.stringify(manifest, "\t"))
	_add_text(packer, "AI_INSTRUCTIONS.md", AIInstructions.generate())
	_add_text(packer, "README_FOR_AI.md", readme(manifest))
	packer.close()
	if FileAccess.file_exists(zip_path):
		DirAccess.remove_absolute(zip_path)
	if DirAccess.rename_absolute(partial, zip_path) != OK:
		return {"ok": false, "error": "Couldn't finish %s (is it open in another program?)." % zip_path.get_file()}
	var size := 0
	var finished := FileAccess.open(zip_path, FileAccess.READ)
	if finished:
		size = finished.get_length()
		finished.close()
	return {"ok": true, "error": "", "path": zip_path, "bytes": size, "characters": library["characters"].size(),
		"props": library["props"].size(), "packs": library["animation_packs"].size(), "sounds": library["sounds"].size(), "files": files}


## Size, actions, face abilities and a picture of one library item.
func _describe(item: Dictionary, character: bool) -> Dictionary:
	var info := {"name": item["name"],
		"script": ("my character \"%s\"" if character else "my prop \"%s\"") % item["name"],
		"source": _source_of(item)}
	if not str(item.get("credit", "")).is_empty():
		info["credit"] = item["credit"]
	info["file_mb"] = snappedf(FileAccess.get_file_as_bytes(item["path"]).size() / 1048576.0, 0.01) if FileAccess.file_exists(item["path"]) else 0.0
	var node := PropUtils.create_prop(item["path"])
	if node == null:
		info["error"] = "couldn't be loaded"
		return info
	_stage.add_child(node)
	if node is ImportedCharacter:
		var person := node as ImportedCharacter
		person.ensure_built()
		person.face_movement = false
		var actions := PackedStringArray()
		for action in person.action_names():
			if action != CharacterBase.POSE_ONLY:
				actions.append(action)
		info["actions"] = actions
		info["has_own_animations"] = person.has_animations()
		var blink := false
		var mouth := false
		for entry in person._face_shapes:
			blink = blink or entry[2] == "blink"
			mouth = mouth or entry[2] == "mouth"
		info["lip_sync"] = mouth or person._jaw >= 0
		info["blinks"] = blink
		var rig := person.rig_report()
		if not rig.is_empty():
			info["skeleton"] = rig
	var box := PropUtils.world_aabb(node)
	info["size_m"] = [snappedf(box.size.x, 0.01), snappedf(box.size.y, 0.01), snappedf(box.size.z, 0.01)]
	if character:
		info["height_m"] = snappedf(box.size.y, 0.01)
	info["triangles"] = _triangles(node)
	var image := await _render(node, box, character)
	if image:
		var thumb := "thumbnails/%s/%s.png" % ["characters" if character else "props", _file_name(str(item["name"]))]
		info["thumbnail"] = thumb
		_thumbs[thumb] = image
	node.queue_free()
	await get_tree().process_frame
	return info


static func _source_of(item: Dictionary) -> String:
	var path := str(item["path"])
	if str(item["category"]) == PropCatalog.DOWNLOADED_CATEGORY:
		return "downloaded (Poly Haven / Poly Pizza)"
	if path.begins_with(RuntimeModelLoader.CHARACTERS_DIR) and FileAccess.file_exists(path.get_basename() + ".avatar.json"):
		return "Avatar Studio"
	return "imported"


static func _triangles(root: Node) -> int:
	var count := 0
	for node in PropUtils.descendants(root):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance and mesh_instance.mesh:
			for i in mesh_instance.mesh.get_surface_count():
				var arrays := mesh_instance.mesh.surface_get_arrays(i)
				var indices: Variant = arrays[Mesh.ARRAY_INDEX]
				if indices is PackedInt32Array and not (indices as PackedInt32Array).is_empty():
					count += (indices as PackedInt32Array).size() / 3
				else:
					var verts: Variant = arrays[Mesh.ARRAY_VERTEX]
					if verts is PackedVector3Array:
						count += (verts as PackedVector3Array).size() / 3
	return count


func _render(node: Node3D, box: AABB, character: bool) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var centre := box.get_center()
	# People are framed by their height (a T-pose's arm span would make them tiny).
	var radius := maxf(box.size.y * 0.55 if character else box.size.length() * 0.5, 0.05)
	var distance := radius / sin(deg_to_rad(_camera.fov * 0.5)) * 1.05
	var direction := Vector3(0.35, 0.18 if character else 0.45, 1.0).normalized()
	_camera.look_at_from_position(centre + direction * distance, centre)
	_camera.near = maxf(distance * 0.01, 0.01)
	_camera.far = distance * 4.0 + 10.0
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	return image


## Copies a model into the zip as one .glb with its pictures shrunk: .gltf files
## are packed with their textures, .fbx files are converted. With [param animation]
## only the skeleton and motion are kept (Mixamo "with skin" downloads carry a
## whole character in every animation). Returns its zip path.
func _add_model(packer: ZIPPacker, path: String, folder: String, animation: bool = false) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var extension := path.get_extension().to_lower()
	var base := folder + path.get_file().get_basename().validate_filename()
	var bytes := PackedByteArray()
	if animation or extension == "fbx":
		bytes = _converted_glb(path, animation)
	elif extension == "gltf":
		bytes = GlbSlimmer.gltf_to_glb(path)
	elif extension == "glb":
		bytes = FileAccess.get_file_as_bytes(path)
	if not bytes.is_empty():
		_add_bytes(packer, base + ".glb", GlbSlimmer.slim_bytes(bytes, MAX_TEXTURE))
		return base + ".glb"
	if extension == "gltf":
		return ""   # can't be used without its other files
	_add_bytes(packer, folder + path.get_file().validate_filename(), FileAccess.get_file_as_bytes(path))
	return folder + path.get_file().validate_filename()


## A model re-saved as .glb by Godot (for .fbx files and animation packs), or empty.
func _converted_glb(path: String, animation: bool) -> PackedByteArray:
	var root := RuntimeModelLoader.read_file(path)
	if root == null:
		return PackedByteArray()
	_stage.add_child(root)
	if animation:
		# Keep the smallest skinned mesh (so the skeleton is saved as a skin), plain grey.
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		var keep: MeshInstance3D = null
		for found in meshes:
			var mesh_instance := found as MeshInstance3D
			if mesh_instance.skin and mesh_instance.mesh and (keep == null or mesh_instance.mesh.get_faces().size() < keep.mesh.get_faces().size()):
				keep = mesh_instance
		for found in meshes:
			if found != keep:
				found.get_parent().remove_child(found)
				found.free()
		if keep:
			var plain := StandardMaterial3D.new()
			for i in keep.mesh.get_surface_count():
				keep.mesh.surface_set_material(i, plain)
			keep.material_override = null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var out := PackedByteArray()
	if document.append_from_scene(root, state) == OK:
		out = document.generate_buffer(state)
	root.queue_free()
	return out


static func _add_bytes(packer: ZIPPacker, name: String, bytes: PackedByteArray) -> void:
	packer.start_file(name)
	packer.write_file(bytes)
	packer.close_file()


static func _add_text(packer: ZIPPacker, name: String, text: String) -> void:
	_add_bytes(packer, name, text.to_utf8_buffer())


static func _file_name(name: String) -> String:
	return name.to_snake_case().validate_filename()


## Writes the pictures, plus pages showing many of them with their names.
func _contact_sheets(packer: ZIPPacker, manifest: Dictionary) -> Array:
	for thumb in _thumbs:
		_add_bytes(packer, thumb, (_thumbs[thumb] as Image).save_png_to_buffer())
	var entries: Array = []
	for group in [["characters", "My character"], ["props", "My prop"]]:
		for info in manifest[group[0]]:
			if _thumbs.has(str(info.get("thumbnail", ""))):
				var size: Array = info.get("size_m", [0, 0, 0])
				var label := "%s\n%s · %s m" % [info["name"], group[1], "%.2f × %.2f × %.2f" % [float(size[0]), float(size[1]), float(size[2])]]
				entries.append([_thumbs[info["thumbnail"]], label])
	var sheets: Array = []
	if entries.is_empty():
		return sheets
	var per_page := SHEET_COLUMNS * SHEET_ROWS
	var page := 0
	while page * per_page < entries.size():
		var image := await _sheet(entries.slice(page * per_page, (page + 1) * per_page))
		if image:
			var name := "contact_sheets/library_%d.png" % (page + 1)
			_add_bytes(packer, name, image.save_png_to_buffer())
			sheets.append(name)
		page += 1
	return sheets


func _sheet(entries: Array) -> Image:
	var cell := Vector2i(THUMB_SIZE, THUMB_SIZE + 44)
	var rows := ceili(entries.size() / float(SHEET_COLUMNS))
	var canvas := SubViewport.new()
	canvas.size = Vector2i(cell.x * SHEET_COLUMNS, cell.y * rows)
	canvas.transparent_bg = false
	canvas.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(canvas)
	var back := ColorRect.new()
	back.color = Color(0.12, 0.12, 0.14)
	back.size = Vector2(canvas.size)
	canvas.add_child(back)
	for i in entries.size():
		var at := Vector2((i % SHEET_COLUMNS) * cell.x, (i / SHEET_COLUMNS) * cell.y)
		var picture := TextureRect.new()
		picture.texture = ImageTexture.create_from_image(entries[i][0])
		picture.position = at
		picture.size = Vector2(THUMB_SIZE, THUMB_SIZE)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		canvas.add_child(picture)
		var label := Label.new()
		label.text = entries[i][1]
		label.position = at + Vector2(6, THUMB_SIZE + 2)
		label.size = Vector2(THUMB_SIZE - 12, 40)
		label.add_theme_font_size_override("font_size", 13)
		label.clip_text = true
		canvas.add_child(label)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := canvas.get_texture().get_image()
	canvas.queue_free()
	return image


## What an AI should know about this export.
static func readme(manifest: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("# Scene Builder library export")
	lines.append("")
	lines.append("This zip describes everything the user has in **Scene Builder %s**: their own characters (avatars, imported people), their own props, animation packs and sounds. Use it to write a **film package** that stars the user's characters in sets made from the user's props." % manifest.get("app_version", "?"))
	lines.append("")
	lines.append("## Files")
	lines.append("- `library.json`: every item with the exact name to use in a script, its size in metres, triangle count, and for characters: height, actions, whether it can lip-sync and blink.")
	lines.append("- `AI_INSTRUCTIONS.md`: the complete film-script language of this app version, including every built-in location, object, character and action. Follow it exactly.")
	lines.append("- `contact_sheets/*.png`: pictures of every item with its name and size. Look at these to know what things look like.")
	lines.append("- `thumbnails/`: one picture per item.")
	if bool(manifest.get("includes_files", false)):
		lines.append("- `characters/`, `models/`, `animations/`: the model files themselves (textures shrunk to %d px). Use them to build and test the film in Scene Builder before delivering it." % MAX_TEXTURE)
	else:
		lines.append("- Model files are NOT included (list-only export). The user's Scene Builder already has them.")
	lines.append("")
	lines.append("## Using the user's things in a script")
	lines.append("```")
	lines.append("REQUIRES: Scene Builder %s" % manifest.get("app_version", "1.8"))
	lines.append("CAST:")
	var example_character := "Nabin"
	if not (manifest.get("characters", []) as Array).is_empty():
		example_character = str((manifest["characters"] as Array)[0]["name"])
	var example_prop := "Wooden Table"
	if not (manifest.get("props", []) as Array).is_empty():
		example_prop = str((manifest["props"] as Array)[0]["name"])
	lines.append("Hero = my character \"%s\", voice male" % example_character)
	lines.append("SET:")
	lines.append("table = my prop \"%s\" near sofa, facing door" % example_prop)
	lines.append("```")
	lines.append("- `my character \"<name>\"` and `my prop \"<name>\"` use the user's own items by the names in library.json (spelling and case don't need to be exact, but use the listed names).")
	lines.append("- Mix freely with built-in locations, objects and people from AI_INSTRUCTIONS.md.")
	lines.append("- `scale 0.8` after a prop name resizes it (`my prop \"Chair\" scale 0.8 at window`). Check `size_m` so things fit (a door is about 0.9 × 2.1 m, a table top about 0.75 m high).")
	lines.append("- The user's characters walk, run, sit, turn, talk (with subtitles) and can be posed with pose lines, but gestures like waves/claps/dances only play if one of their listed `actions` provides them (e.g. a Mixamo pack called \"Waving\": use \"Name does Waving\"). Other gestures are skipped. Characters with `lip_sync: true` move their mouth when they talk; with `blinks: true` they blink.")
	lines.append("- If the package must work on another computer, put the model files in the package (`characters/<file>.glb`, `models/<file>.glb`); Scene Builder uses the library copy when it has one, otherwise the package's.")
	lines.append("- Anything the library doesn't have can still come from the package's own `models/` (e.g. made with a Blender script), as described in AI_INSTRUCTIONS.md.")
	return "\n".join(lines)

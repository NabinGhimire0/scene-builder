class_name PropCatalog
extends RefCounted
## Discovers placeable props on disk. Pure data, no UI.
##
## Scans [constant PROPS_DIR] recursively for .tscn/.scn/.glb/.gltf files. The
## first folder level is the category (assets/props/nature/... → "Nature").
## Handles exported builds, where files appear as "name.tscn.remap".
## Also lists the user's library in user://library/: models downloaded from the
## online stores ("Downloaded"), imported models ("Imported") and imported rigged
## characters ("My Characters").

const PROPS_DIR := "res://assets/props/"
const SCENE_EXTENSIONS: PackedStringArray = ["tscn", "scn", "glb", "gltf"]
const CATEGORY_ORDER: PackedStringArray = ["Characters", "My Characters", "Buildings", "Interior", "Story", "Hospital", "Stage", "City", "Lights", "Nature", "Water", "Effects", "Furniture", "Vehicles", "Decorations", "Downloaded", "Imported"]
const DOWNLOADED_CATEGORY := "Downloaded"
const IMPORTED_CATEGORY := "Imported"
const MY_CHARACTERS_CATEGORY := "My Characters"
const DEFAULT_CATEGORY := "Misc"


## Returns prop descriptors sorted by category then name:
## { prop_id, scene_path, display_name, category }
static func scan(dir_path: String = PROPS_DIR) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var seen := {}
	_scan_dir(dir_path, "", results, seen)
	if dir_path == PROPS_DIR:
		_scan_user_library(results, seen)
	results.sort_custom(_compare)
	return results


static func _scan_user_library(results: Array[Dictionary], seen: Dictionary) -> void:
	var online := OnlineLibrary.entries()
	for key in online:
		var entry: Dictionary = online[key]
		var path := str(entry.get("file", ""))
		if str(entry.get("kind", "model")) != "model":
			continue  # skies and textures aren't placeable objects
		if path.is_empty() or seen.has(path) or not FileAccess.file_exists(path):
			continue
		seen[path] = true
		results.append({
			"prop_id": ("%s_%s" % [entry.get("provider", ""), entry.get("id", "")]).to_snake_case(),
			"scene_path": path,
			"display_name": str(entry.get("title", path.get_file().get_basename())),
			"category": DOWNLOADED_CATEGORY,
			"thumbnail": str(entry.get("thumbnail_file", "")),
			"credit": OnlineLibrary.credit_line(entry),
		})
	for pair in [[RuntimeModelLoader.IMPORTED_DIR, IMPORTED_CATEGORY], [RuntimeModelLoader.CHARACTERS_DIR, MY_CHARACTERS_CATEGORY]]:
		var dir := DirAccess.open(pair[0])
		if dir == null:
			continue
		for file_name in dir.get_files():
			var made := CharacterFactory.is_character_file(file_name)
			if not made and not RuntimeModelLoader.EXTENSIONS.has(file_name.get_extension().to_lower()):
				continue
			var path := str(pair[0]) + file_name
			if seen.has(path):
				continue
			seen[path] = true
			var base := file_name.get_basename()
			results.append({
				"prop_id": base.to_snake_case(),
				"scene_path": path,
				"display_name": CharacterFactory.display_name(path) if made else base.capitalize(),
				"category": pair[1],
			})


## Categories present in [param props], in display order.
static func categories_of(props: Array[Dictionary]) -> PackedStringArray:
	var out := PackedStringArray()
	for prop in props:
		var category := str(prop["category"])
		if not out.has(category):
			out.append(category)
	return out


static func category_for_path(scene_path: String) -> String:
	if scene_path.begins_with(RuntimeModelLoader.CHARACTERS_DIR):
		return MY_CHARACTERS_CATEGORY
	if scene_path.begins_with(RuntimeModelLoader.IMPORTED_DIR):
		return IMPORTED_CATEGORY
	if scene_path.begins_with(RuntimeModelLoader.ONLINE_DIR):
		return DOWNLOADED_CATEGORY
	if not scene_path.begins_with(PROPS_DIR):
		return DEFAULT_CATEGORY
	var parts := scene_path.trim_prefix(PROPS_DIR).split("/")
	return parts[0].capitalize() if parts.size() > 1 else DEFAULT_CATEGORY


## True if [param scene_path] points inside the built-in props or the user's
## library. Saved project files may only reference these, never arbitrary files.
static func is_library_path(scene_path: String) -> bool:
	if scene_path.contains(".."):
		return false
	var clean := scene_path.simplify_path()
	return clean.begins_with(PROPS_DIR) or clean.begins_with(RuntimeModelLoader.LIBRARY_DIR)


static func _scan_dir(dir_path: String, category: String, results: Array[Dictionary], seen: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("PropCatalog: can't open '%s' (error %d)." % [dir_path, DirAccess.get_open_error()])
		return
	for file_name in dir.get_files():
		var clean := file_name.trim_suffix(".remap").trim_suffix(".import")
		if not SCENE_EXTENSIONS.has(clean.get_extension().to_lower()):
			continue
		var path := dir_path.path_join(clean)
		if seen.has(path) or not ResourceLoader.exists(path):
			continue
		seen[path] = true
		var base := clean.get_basename()
		results.append({
			"prop_id": base.to_snake_case(),
			"scene_path": path,
			"display_name": base.capitalize(),
			"category": category if not category.is_empty() else DEFAULT_CATEGORY,
		})
	for sub in dir.get_directories():
		if sub.begins_with(".") or sub.begins_with("_"):
			continue
		var sub_category := category if not category.is_empty() else sub.capitalize()
		_scan_dir(dir_path.path_join(sub), sub_category, results, seen)


static func _category_rank(category: String) -> int:
	var index := CATEGORY_ORDER.find(category)
	return index if index >= 0 else CATEGORY_ORDER.size()


static func _compare(a: Dictionary, b: Dictionary) -> bool:
	var ca := str(a["category"])
	var cb := str(b["category"])
	if ca != cb:
		var ra := _category_rank(ca)
		var rb := _category_rank(cb)
		return ra < rb if ra != rb else ca < cb
	return str(a["display_name"]) < str(b["display_name"])

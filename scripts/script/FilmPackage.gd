class_name FilmPackage
extends RefCounted
## Opens a film package: a folder (or .zip) with a script plus the files it
## uses, e.g.
##   my_film/
##     film.script          (or any .script / .film / .txt / .json)
##     models/   characters/   animations/   audio/
## A plain script file works too; files it names are looked up next to it.

const PACKAGES_DIR := "user://packages/"
const SCRIPT_EXTENSIONS: PackedStringArray = ["script", "film", "txt", "json", "md"]
const SKIP_NAMES: PackedStringArray = ["report.txt", "readme.txt", "readme.md", "license.txt", "credits.txt", "notes.txt"]


## Returns { "dir": package folder, "script": script file path, "text": script, "error": "" }.
static func open(path: String) -> Dictionary:
	if DirAccess.dir_exists_absolute(path):
		return _from_folder(path)
	if not FileAccess.file_exists(path):
		return {"error": "Not found: %s" % path}
	if path.get_extension().to_lower() == "zip":
		var folder := _extract(path)
		if folder.is_empty():
			return {"error": "Couldn't open the .zip file %s." % path.get_file()}
		return _from_folder(folder)
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return {"error": "%s is empty." % path.get_file()}
	return {"dir": path.get_base_dir(), "script": path, "text": text, "error": ""}


static func _from_folder(folder: String) -> Dictionary:
	var script := find_script(folder)
	if script.is_empty():
		# A zip often holds one top folder.
		var dir := DirAccess.open(folder)
		if dir:
			var subs := dir.get_directories()
			if subs.size() == 1:
				return _from_folder(folder.path_join(subs[0]))
		return {"error": "No script found in %s (expected film.script, or a .script / .txt / .json file)." % folder.get_file()}
	return {"dir": folder, "script": script, "text": FileAccess.get_file_as_string(script), "error": ""}


static func find_script(folder: String) -> String:
	var dir := DirAccess.open(folder)
	if dir == null:
		return ""
	var files := dir.get_files()
	for preferred in ["film.script", "film.txt", "script.txt", "film.json", "script.json"]:
		if files.has(preferred):
			return folder.path_join(preferred)
	for extension in SCRIPT_EXTENSIONS:
		for file_name in files:
			if file_name.get_extension().to_lower() == extension and not SKIP_NAMES.has(file_name.to_lower()):
				return folder.path_join(file_name)
	return ""


static func _extract(zip_path: String) -> String:
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		return ""
	var target := PACKAGES_DIR + zip_path.get_file().get_basename().validate_filename() + "/"
	_remove_tree(target)
	DirAccess.make_dir_recursive_absolute(target)
	for inner in reader.get_files():
		var clean := inner.replace("\\", "/")
		if clean.contains("..") or clean.begins_with("/") or clean.contains(":"):
			continue  # never write outside the package folder
		if clean.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(target + clean)
			continue
		DirAccess.make_dir_recursive_absolute((target + clean).get_base_dir())
		var file := FileAccess.open(target + clean, FileAccess.WRITE)
		if file:
			file.store_buffer(reader.read_file(inner))
			file.close()
	reader.close()
	return target.trim_suffix("/")


static func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)

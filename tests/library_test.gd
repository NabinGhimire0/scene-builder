extends Node
## Export My Library: list-only and full exports, slimmed models still work.
## godot res://tests/LibraryTest.tscn -- <out dir>


func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var ok := true
	var library := LibraryExporter.gather()
	print("LIB: characters ", library["characters"].map(func(c: Dictionary) -> String: return c["name"]),
		" props ", library["props"].map(func(c: Dictionary) -> String: return c["name"]),
		" packs ", library["animation_packs"], " sounds ", library["sounds"].size())
	ok = ok and library["characters"].size() == 3 and library["props"].size() == 3
	var exporter := LibraryExporter.new()
	add_child(exporter)
	for full in [false, true]:
		var path := out.path_join("library_full.zip" if full else "library_list.zip")
		var started := Time.get_ticks_msec()
		var result: Dictionary = await exporter.export_library(path, full)
		print("LIB: export full=%s %s in %d ms" % [full, JSON.stringify(result), Time.get_ticks_msec() - started])
		ok = ok and bool(result["ok"])
		var reader := ZIPReader.new()
		reader.open(path)
		var names := reader.get_files()
		print("LIB: files ", names)
		var manifest: Dictionary = JSON.parse_string(reader.read_file("library.json").get_string_from_utf8())
		var instructions := reader.read_file("AI_INSTRUCTIONS.md").get_string_from_utf8()
		ok = ok and instructions.contains("\"Nabin Avatar\"") and instructions.contains("my character \"<name>\"") and instructions.contains("my prop \"<name>\"")
		for character in manifest["characters"]:
			print("LIB:  char ", character["name"], " h=", character.get("height_m"), " lips=", character.get("lip_sync"), " blink=", character.get("blinks"), " actions=", character.get("actions"), " tris=", character.get("triangles"), " thumb=", character.get("thumbnail", "-"), " file=", character.get("file", "-"))
		for prop in manifest["props"]:
			print("LIB:  prop ", prop["name"], " size=", prop.get("size_m"), " thumb=", prop.get("thumbnail", "-"))
		ok = ok and names.has("README_FOR_AI.md") and not (manifest["contact_sheets"] as Array).is_empty()
		for sheet in manifest["contact_sheets"]:
			var image := Image.new()
			image.load_png_from_buffer(reader.read_file(sheet))
			image.save_png(out.path_join(("full_" if full else "list_") + str(sheet).get_file()))
		if full:
			# The slimmed avatar must still load with its face shapes.
			var avatar_file := ""
			for character in manifest["characters"]:
				if character["name"] == "Nabin Avatar":
					avatar_file = character.get("file", "")
			ok = ok and not avatar_file.is_empty()
			var temp := out.path_join("slim_check.glb")
			var f := FileAccess.open(temp, FileAccess.WRITE)
			f.store_buffer(reader.read_file(avatar_file))
			f.close()
			var original := FileAccess.get_file_as_bytes(RuntimeModelLoader.CHARACTERS_DIR + "Nabin_Avatar.glb").size()
			print("LIB: avatar %d -> %d bytes" % [original, FileAccess.get_file_as_bytes(temp).size()])
			var root := RuntimeModelLoader.read_file(temp)
			var shapes := 0
			for mesh in root.find_children("*", "MeshInstance3D", true, false):
				shapes += (mesh as MeshInstance3D).mesh.get_blend_shape_count()
			print("LIB: slimmed avatar blend shapes ", shapes, " skeleton ", root.find_children("*", "Skeleton3D", true, false).size())
			ok = ok and shapes >= 4 and root.find_children("*", "Skeleton3D", true, false).size() == 1
			root.free()
		reader.close()
	print("LIB: ", "OK" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)

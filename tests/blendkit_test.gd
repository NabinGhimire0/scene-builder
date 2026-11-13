extends SceneTree
## BlendKit store test against a local stand-in server.
## godot --headless -s res://tests/blendkit_test.gd -- <server_url> <fake_blender>

var _fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _meshes(path: String) -> int:
	var scene := RuntimeModelLoader.load_scene(path)
	if scene == null:
		return -1
	var node := scene.instantiate()
	var n := node.find_children("*", "MeshInstance3D", true, false).size()
	node.free()
	return n


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var server: String = args[0]
	var blender: String = args[1]
	OnlineLibrary.set_setting("blendkit_server", server)
	OnlineLibrary.set_setting("blendkit_key", "")
	OnlineLibrary.set_setting("blendkit_free_only", true)
	OnlineLibrary.set_setting("blender_path", "/nonexistent/blender")
	var online := OnlineLibrary.new()
	root.add_child(online)

	var url := OnlineLibrary.blendkit_search_url("https://www.blendkit.com", "red chair", true)
	print(url)
	check(url == "https://www.blendkit.com/api/v1/search/?query=red+chair+asset_type:model+is_free:true+order:_score&dict_parameters=1&page_size=24", "search URL like the add-on's")

	var got: Array = []
	online.search_completed.connect(func(r: Array, more: bool, e: String) -> void: got.append([r, more, e]))
	online.search(OnlineLibrary.Provider.BLENDKIT, "chair")
	while got.is_empty():
		await process_frame
	var results: Array = got[0][0]
	check(got[0][2] == "", "free search: no error (%s)" % got[0][2])
	check(results.size() == 2, "free search: 2 free models")
	var stool: Dictionary = results[0]
	var lamp: Dictionary = results[1]
	check(stool["title"] == "Wooden Stool" and stool["license"] == "CC0" and stool["author"] == "Test Author 1", "result fields")
	check(not stool["needs_blender"] and lamp["needs_blender"], "glTF vs .blend-only detected")

	# Paid search with a key.
	OnlineLibrary.set_setting("blendkit_key", "TESTKEY")
	OnlineLibrary.set_setting("blendkit_free_only", false)
	got.clear()
	online.search(OnlineLibrary.Provider.BLENDKIT, "")
	while got.is_empty():
		await process_frame
	check((got[0][0] as Array).size() == 3, "with key, all models")
	var sofa: Dictionary = got[0][0][2]
	check(not sofa["can_download"], "plan-only model flagged")

	# Downloads.
	var out: Dictionary = await online.download_asset(stool)
	check(out["error"] == "" and str(out["path"]).ends_with(".glb"), "glTF zip downloaded + unzipped (%s)" % out["error"])
	check(_meshes(out["path"]) == 5, "stool loads with 5 meshes (got %d)" % _meshes(out["path"]))

	out = await online.download_asset(lamp)
	check(out["error"].contains("needs Blender") or out["error"].contains("Blender"), "no Blender: clear message (%s)" % out["error"])

	OnlineLibrary.set_setting("blender_path", blender)
	out = await online.download_asset(lamp)
	check(out["error"] == "", "lamp converted by Blender (%s)" % out["error"])
	check(_meshes(out["path"]) == 2, "lamp loads: 2 meshes, no camera (got %d)" % _meshes(str(out["path"])))

	out = await online.download_asset(sofa)
	check(not out["error"].is_empty(), "plan-only refused: %s" % out["error"])

	# Shared projects re-download by id.
	OnlineLibrary.entries().erase(OnlineLibrary.key_for("blendkit", "base-1"))
	var again: String = await online.ensure_downloaded("blendkit", "base-1")
	check(again.ends_with(".glb") and _meshes(again) == 5, "ensure_downloaded by id")
	var entry := OnlineLibrary.entry_for_path(again)
	check(OnlineLibrary.credit_line(entry).contains("Test Author 1"), "credit line: " + OnlineLibrary.credit_line(entry))
	check(not entry.has("files"), "file links not stored in the index")

	print("BLENDKIT TEST: %s" % ("ALL PASSED" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

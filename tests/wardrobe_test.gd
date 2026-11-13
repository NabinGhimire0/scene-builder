extends SceneTree
## godot -s res://tests/wardrobe_test.gd -- <character.glb> <spec.json> <out spec.json>
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var spec := HumanBuilder.load_spec(args[1])
	var t0 := Time.get_ticks_msec()
	var r := WardrobeItem.import_from(args[0], spec)
	print("import ", Time.get_ticks_msec() - t0, " ms: ", r)
	var outfit: Dictionary = spec.get("outfit", {})
	var extra: Array = []
	for it in r.get("items", []):
		extra.append(it["path"])
	outfit["extra"] = extra
	spec["outfit"] = outfit
	var f := FileAccess.open(args[2], FileAccess.WRITE)
	f.store_string(JSON.stringify(spec))
	quit()

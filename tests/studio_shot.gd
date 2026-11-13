extends Node
## Screenshots of the Characters / Music pages.
## godot res://tests/StudioShot.tscn -- <out.png> <page> [kind] [preset index] [tab]

func _ready() -> void:
	TutorialOverlay.mark_done()
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var page := args[1] if args.size() > 1 else "characters"
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 6:
		await get_tree().process_frame
	var ui := app.get_node("UI")
	ui.call("show_page", page)
	if page == "characters":
		var studio: CharacterStudio = ui.get("_character_studio")
		if args.size() > 2:
			studio.call("_select_kind", args[2], false)
		if args.size() > 3:
			studio.call("_on_preset", int(args[3]))
		if args.size() > 4:
			(studio.get("_tabs") as TabContainer).current_tab = int(args[4])
	if page == "avatar":
		ui.call("show_page", "scene")
		var lib := app.find_child("AssetLibraryPanel", true, false)
		lib.call("open_avatar_studio")
		await get_tree().process_frame
		var av: AvatarStudio = lib.get("_avatar_studio")
		var paths: PackedStringArray = av.get("_paths")
		var i := paths.find("user://library/characters/avatar_test.glb")
		av.call("_on_pick", maxi(i, 0))
		(av.find_children("*", "TabContainer", true, false)[0] as TabContainer).current_tab = 1
		await get_tree().process_frame
		var items: Array = []
		for it in WardrobeItem.list_items():
			if str(it["path"]).contains("model_avaturn"):
				items.append(it["path"])
		av.call("_set_look", "wardrobe", items)
		av.call("_rebuild_look_tab")
	if page == "music":
		var music: MusicStudio = ui.get("_pages")["music"]
		var paths: PackedStringArray = music.get("_paths")
		if not paths.is_empty():
			music.call("_open", paths[0])
			if args.size() > 2:
				music.call("_choose_preset", args[2])
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()

extends Node
## Online tab on BlendKit, against a stand-in server; screenshots.
## godot res://tests/OnlineUITest.tscn -- <out dir>


func _ready() -> void:
	TutorialOverlay.mark_done()
	var out := OS.get_cmdline_user_args()[0]
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 8:
		await get_tree().process_frame
	var library: Node = null
	for node in app.find_children("*", "Control", true, false):
		if "_online_panel" in node:
			library = node
	library._online_tab.button_pressed = true
	library._show_tab(true)
	var panel: OnlineLibraryPanel = library._online_panel
	panel._provider.select(2)
	panel._on_provider_changed()
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("online_blendkit.png"))
	var card: OnlineCard = panel._grid.get_child(1)
	card._on_pressed()
	for i in 600:
		await get_tree().process_frame
		if not card.scene_path.is_empty():
			break
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("online_done.png"))
	print("ONLINEUI: %s cards, lamp=%s" % [panel._grid.get_child_count(), card.scene_path])
	get_tree().quit()

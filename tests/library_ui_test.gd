extends Node
## Script window → Export My Library: the choice dialog, then an export; screenshots.
## godot res://tests/LibraryUITest.tscn -- <out dir>


func _ready() -> void:
	TutorialOverlay.mark_done()
	var out := OS.get_cmdline_user_args()[0]
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 8:
		await get_tree().process_frame
	var dialog: ScriptDialog = app.find_child("*ScriptDialog*", true, false) as ScriptDialog
	if dialog == null:
		for node in app.find_children("*", "Window", true, false):
			if node is ScriptDialog:
				dialog = node
	dialog.open()
	await get_tree().process_frame
	dialog._on_export_library()
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("ui_choice.png"))
	dialog._library_choice.hide()
	dialog._library_full.button_pressed = false
	await dialog._export_library_to(out.path_join("ui_export.zip"))
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("ui_done.png"))
	print("LIBUI: ", dialog._report.get_parsed_text())
	print("LIBUI: ", "OK" if FileAccess.file_exists(out.path_join("ui_export.zip")) else "FAILED")
	get_tree().quit()

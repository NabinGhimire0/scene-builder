extends Node
## Opens the Script window and saves a screenshot, plus the AI instructions text.

func _ready() -> void:
	TutorialOverlay.mark_done()
	var out := OS.get_cmdline_user_args()[0]
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 6:
		await get_tree().process_frame
	var text := AIInstructions.generate("A 40-second film about two friends at a rainy bus stop.")
	var file := FileAccess.open(out.path_join("instructions.txt"), FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("UI: instructions ", text.length(), " chars")
	app.get_node("UI").call("open_script")
	for i in 10:
		await get_tree().process_frame
	get_tree().root.get_texture().get_image().save_png(out.path_join("script_window.png"))
	print("UI: saved")
	get_tree().quit()

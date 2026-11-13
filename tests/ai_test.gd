extends Node
## AI panel against a (mock) Ollama: godot res://tests/AITest.tscn -- out.png
func _ready() -> void:
	TutorialOverlay.mark_done()
	var out := OS.get_cmdline_user_args()[0]
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 6:
		await get_tree().process_frame
	var ui := app.get_node("UI")
	ui.call("open_script")
	var dlg: ScriptDialog = ui.get("_script_dialog")
	var panel: AIFilmPanel = dlg.find_children("*", "AIFilmPanel", true, false)[0]
	(dlg.get("_story") as TextEdit).text = "A grandfather and his granddaughter release a lantern by the lake at dusk."
	var t0 := Time.get_ticks_msec()
	while (panel.get("_model_pick") as OptionButton).item_count == 0 and Time.get_ticks_msec() - t0 < 10000:
		await get_tree().process_frame
	print("AITEST models ", (panel.get("_model_pick") as OptionButton).item_count, " chosen ", panel.client.model, " status ", (panel.get("_status") as Label).text)
	(panel.get("_auto_build") as CheckBox).button_pressed = false
	panel.call("_on_write_go")
	t0 = Time.get_ticks_msec()
	while str(panel.get("_job")) != "" and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	print("AITEST rounds ", panel.get("_round"), " status ", (panel.get("_status") as Label).text)
	print("AITEST script starts ", dlg.script_text().substr(0, 80).replace("\n", " | "))
	panel.call("_on_youtube")
	t0 = Time.get_ticks_msec()
	while str(panel.get("_job")) != "" and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	print("AITEST youtube ", (panel.get("_result_text") as TextEdit).text.substr(0, 60))
	(panel.get("_result_window") as Window).hide()
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()

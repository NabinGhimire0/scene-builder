extends Node
## Builds a film and runs the Film Check on it (what the "Check film" button does).
## godot res://tests/FilmCheck.tscn -- <package or film.script> [quality 0-2]

func _ready() -> void:
	TutorialOverlay.mark_done()
	var args := OS.get_cmdline_user_args()
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 5:
		await get_tree().process_frame
	var director: ScriptDirector = app.find_child("ScriptDirector", true, false)
	var package := FilmPackage.open(args[0])
	director.build_from_text(str(package["text"]), str(package["dir"]))
	var exporter: ExportManager = app.find_child("CinematicExportManager", true, false)
	if args.size() > 1:
		exporter.settings["render_quality"] = int(args[1])
	var started := Time.get_ticks_msec()
	var check := FilmCheck.new()
	var found: Array = await check.run(exporter, func(done: int, total: int) -> void:
		if done % 20 == 0 or done == total:
			print("CHECK: %d/%d" % [done, total]))
	print(FilmCheck.describe(found))
	print("CHECK: done in %.0f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	get_tree().quit()

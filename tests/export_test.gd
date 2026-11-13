extends Node
## Builds a film from a script/package and exports it with the app's own exporter.
## godot res://tests/ExportTest.tscn -- <package> <output folder> <file name> [render quality 0-2] [resolution index]

func _ready() -> void:
	TutorialOverlay.mark_done()
	var args := OS.get_cmdline_user_args()
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 5:
		await get_tree().process_frame
	var director: ScriptDirector = app.find_child("ScriptDirector", true, false)
	var package := FilmPackage.open(args[0])
	var report := director.build_from_text(str(package["text"]), str(package["dir"]))
	print("EXPORT: built %.1f s" % float(report["length"]))
	var exporter: ExportManager = app.find_child("CinematicExportManager", true, false)
	exporter.set_setting("resolution", int(args[4]) if args.size() > 4 else 0)
	exporter.set_setting("fps", 24)
	exporter.set_setting("format", ExportManager.Format.MP4)
	exporter.set_setting("quality", 0.8)
	exporter.set_setting("render_quality", int(args[3]) if args.size() > 3 else RenderQuality.Level.PREVIEW)
	exporter.set_setting("output_dir", args[1])
	exporter.set_setting("file_name", args[2])
	exporter.progress.connect(_on_progress)
	exporter.export_video()
	var result: Array = await exporter.finished
	print("EXPORT: done ", result)
	get_tree().quit()


func _on_progress(frame: int, total: int, _eta: float) -> void:
	if frame % 240 == 0:
		print("EXPORT: frame %d / %d" % [frame, total])

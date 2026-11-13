extends Node

func _ready() -> void:
	TutorialOverlay.mark_done()
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 5:
		await get_tree().process_frame
	var director: ScriptDirector = app.find_child("ScriptDirector", true, false)
	print("VOICE engine: ", SpeechMaker.engine())
	var package := FilmPackage.open(OS.get_cmdline_user_args()[0])
	var started := Time.get_ticks_msec()
	var report := director.build_from_text(str(package["text"]), str(package["dir"]))
	print("VOICE built in %d ms, length %.1f, warnings %s" % [Time.get_ticks_msec() - started, float(report["length"]), str(report["warnings"])])
	for clip in director.builder.audio.clips:
		print("VOICE clip %s at %.2f len %.2f" % [str(clip["name"]), float(clip["start"]), director.builder.audio.clip_length(clip)])
	for child in director.builder.placed_props_root.get_children():
		if child is CharacterBase and not (child as CharacterBase).lipsync.is_empty():
			var env: PackedFloat32Array = (child as CharacterBase).lipsync["env"]
			var mx := 0.0
			for v in env:
				mx = maxf(mx, v)
			print("VOICE lipsync %s start %.2f frames %d max %.2f" % [child.name, float((child as CharacterBase).lipsync["start"]), env.size(), mx])
	get_tree().quit()

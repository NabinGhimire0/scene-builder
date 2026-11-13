extends Node
## Prints a camera's transform keys: godot res://tests/CamKeys.tscn -- <script> "<camera name part>"

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
	var tl := director.builder.timeline
	for cam in director.builder.director.cameras():
		if not str(cam.name).contains(args[1]):
			continue
		var id := KeyframeStore.channel_id(cam.uid(), TimelineController.CH_TRANSFORM)
		for key in tl.store.channels.get(id, []):
			print("KEY %s t=%.2f %s %s" % [cam.name, float(key["t"]), str(key["v"].get("position")), str(key["v"].get("quaternion"))])
	get_tree().quit()

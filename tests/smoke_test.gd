extends Node
## Headless smoke test: launch the app, build every template, scrub the timeline.
## Run: godot --headless --script res://tests/smoke_test.gd

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TutorialOverlay.mark_done()
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 5:
		await get_tree().process_frame
	var builder: TemplateBuilder = app.find_child("TemplateBuilder", true, false)
	var timeline: TimelineController = builder.timeline
	print("SMOKE: app started, templates: ", TemplateBuilder.TEMPLATES.size())
	for name in TemplateBuilder.TEMPLATES.keys():
		print("SMOKE: building ", name)
		builder.build(str(name))
		for i in 3:
			await get_tree().process_frame
		var length := timeline.duration()
		var steps := 6
		for s in steps + 1:
			timeline.set_time(length * float(s) / float(steps))
			await get_tree().process_frame
		print("SMOKE: ok ", name, "  duration=", length, "  keys=", timeline.store.tracks.size() if "tracks" in timeline.store else -1)
	print("SMOKE: done")
	get_tree().quit()

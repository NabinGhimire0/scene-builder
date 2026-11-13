extends Node
## Builds a film from a script and (when a renderer is available) saves frames
## seen through the film's cameras.
## godot res://tests/ScriptTest.tscn -- <script path> <frames dir> [times…]

var frames_dir := ""


func _ready() -> void:
	TutorialOverlay.mark_done()
	var args := OS.get_cmdline_user_args()
	var script_path := args[0] if args.size() > 0 else "res://assets/scripts/the_promise.script"
	frames_dir = args[1] if args.size() > 1 else ""
	var times: Array[float] = []
	for i in range(2, args.size()):
		times.append(args[i].to_float())
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 5:
		await get_tree().process_frame
	var director: ScriptDirector = app.find_child("ScriptDirector", true, false)
	var package := FilmPackage.open(script_path)
	if not str(package.get("error", "")).is_empty():
		print("TEST: ", package["error"])
		get_tree().quit(1)
		return
	var started := Time.get_ticks_msec()
	var report := director.build_from_text(str(package["text"]), str(package["dir"]))
	print("TEST: built in %d ms" % (Time.get_ticks_msec() - started))
	print("TEST: report ", JSON.stringify(report, "  "))
	var timeline: TimelineController = director.builder.timeline
	print("TEST: duration %.1f, cuts %d, channels %d, cameras %d" % [timeline.duration(), timeline.store.cuts.size(),
		timeline.store.channels.size(), director.builder.director.cameras().size()])
	if director.builder.audio:
		for clip in director.builder.audio.clips:
			print("TEST: audio %.2f %s" % [float(clip["start"]), str(clip.get("name", ""))])
	for cut in timeline.store.cuts:
		var cam := director.builder.director.find_camera(str(cut["camera"]))
		print("TEST: cut %.2f -> %s  at %s looking %s" % [float(cut["t"]), cam.name if cam else "?",
			str(cam.global_position.snapped(Vector3.ONE * 0.01)) if cam else "", str((-cam.global_basis.z).snapped(Vector3.ONE * 0.01)) if cam else ""])
	for child in director.builder.placed_props_root.get_children():
		if child is CharacterBase:
			print("TEST: %s at %s" % [child.name, str((child as Node3D).global_position.snapped(Vector3.ONE * 0.01))])
	if frames_dir.is_empty():
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(frames_dir)
	var viewport := app.get_node("UI/Layout/Workspace/ViewportArea/ViewportContainer/SubViewport") as SubViewport
	director.builder.director.set_view_mode(CinematicDirector.ViewMode.CAMERA)
	if times.is_empty():
		for cut in timeline.store.cuts:
			times.append(float(cut["t"]) + 1.0)
	for t in times:
		timeline.set_time(t)
		for i in 8:
			await get_tree().process_frame
		for child in director.builder.placed_props_root.get_children():
			if child is Node3D and str(child.name).to_lower() in ["plane", "frog", "tiffin", "papers", "bell", "plane2", "arjun", "sheru", "guru"]:
				print("TEST: t=%.1f %s at %s visible scale %.2f" % [t, child.name, str((child as Node3D).global_position.snapped(Vector3.ONE * 0.01)), (child as Node3D).scale.x])
		var image := viewport.get_texture().get_image()
		var path := frames_dir.path_join("frame_%05.1f.png" % t)
		image.save_png(path)
		print("TEST: saved ", path)
	get_tree().quit()

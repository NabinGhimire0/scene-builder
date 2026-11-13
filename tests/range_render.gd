extends Node
## Renders frames [first, last) of a film exactly like the exporter does, into a folder
## (frame_00001.png = frame 0). For long films on slow machines: render in parts.
## godot res://tests/RangeRender.tscn -- <package> <folder> <first> <last> [quality 0-2] [w] [h] [fps]

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
	var folder := args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	# "<first> <last>", or a list of single frames: "24,72,120 -"
	var picks: Array = []
	if args[2].contains(","):
		for part in args[2].split(","):
			picks.append(int(part))
	var first := int(picks[0]) if not picks.is_empty() else int(args[2])
	var last := int(picks[picks.size() - 1]) + 1 if not picks.is_empty() else int(args[3])
	var level := int(args[4]) if args.size() > 4 else RenderQuality.Level.HIGH
	var size := Vector2i(int(args[5]), int(args[6])) if args.size() > 6 else Vector2i(1280, 720)
	var frame_rate := float(args[7]) if args.size() > 7 else 24.0
	var exporter: ExportManager = app.find_child("CinematicExportManager", true, false)
	var timeline: TimelineController = director.builder.timeline
	var cine: CinematicDirector = director.builder.director
	last = mini(last, int(round(timeline.duration() * frame_rate)))
	EventBus.render_mode_changed.emit(true)
	var env := exporter.environment
	if env:
		env.set_quality_override(level)
	var viewport := SubViewport.new()
	viewport.size = size
	RenderQuality.apply_viewport(viewport, level)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.cull_mask = Layers.FINAL_RENDER_MASK
	viewport.add_child(cam)
	if exporter.titles and not OS.has_environment("SB_NO_TITLES"):
		viewport.add_child(exporter.titles.create_overlay())
	add_child(viewport)
	cam.current = true
	SketchCharacter.render_camera = cam
	var aspect := float(size.x) / float(size.y)
	cine.render_aspect = aspect
	# warm up on the first frame of the range
	timeline.apply_time_for_render(float(first) / frame_rate)
	for w in RenderQuality.WARMUP_FRAMES[level] + 4:
		var s := cine.current_camera()
		if s:
			cine.apply_shot(cam, s, aspect)
		await RenderingServer.frame_post_draw
	var started := Time.get_ticks_msec()
	for i in range(first, last):
		if not picks.is_empty() and not picks.has(i):
			continue
		if not picks.is_empty():
			# a jump: let the frame settle like the warm-up
			for w in 3:
				timeline.apply_time_for_render(float(i) / frame_rate)
				var settle := cine.current_camera()
				if settle:
					cine.apply_shot(cam, settle, aspect)
				get_tree().call_group(&"sketch_faces", &"aim_face_now")
				await RenderingServer.frame_post_draw
		timeline.apply_time_for_render(float(i) / frame_rate)
		var shot := cine.current_camera()
		if shot:
			cine.apply_shot(cam, shot, aspect)
		get_tree().call_group(&"sketch_faces", &"aim_face_now")
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(folder.path_join("frame_%05d.png" % (i + 1)))
		if (i - first) % 120 == 0:
			print("RANGE: frame %d (%.2f s/frame)" % [i, (Time.get_ticks_msec() - started) / 1000.0 / float(i - first + 1)])
	print("RANGE: done %d-%d" % [first, last])
	get_tree().quit()

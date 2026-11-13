extends Node
## Looks at people from the side and from the front at given moments, to check how they
## sit, lie and face each other.
## godot res://tests/SideView.tscn -- <script> <folder> "t:Name,t:Name,..." [w] [h]
## Writes <folder>/<i>_<name>_side.png and _front.png, and prints where each body part is.

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
	var size := Vector2i(int(args[3]), int(args[4])) if args.size() > 4 else Vector2i(480, 360)
	var exporter: ExportManager = app.find_child("CinematicExportManager", true, false)
	EventBus.render_mode_changed.emit(true)
	var viewport := SubViewport.new()
	viewport.size = size
	RenderQuality.apply_viewport(viewport, RenderQuality.Level.PREVIEW)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.cull_mask = Layers.FINAL_RENDER_MASK
	cam.fov = 40.0
	viewport.add_child(cam)
	add_child(viewport)
	cam.current = true
	SketchCharacter.render_camera = cam
	var timeline: TimelineController = director.builder.timeline
	var index := 0
	for item in args[2].split(","):
		var parts := item.split(":")
		var t := float(parts[0])
		var who := parts[1]
		timeline.apply_time_for_render(t)
		var person: CharacterBase = null
		for child in director.builder.placed_props_root.get_children():
			if child is CharacterBase and timeline.display_name(child) == who:
				person = child
		if person == null:
			print("SIDE missing ", who)
			continue
		await get_tree().process_frame
		var body: Node3D = person.get("_body")
		var facing := body.global_basis.z
		facing.y = 0.0
		facing = facing.normalized()
		var side := Vector3(facing.z, 0, -facing.x)
		var hips := person.joint_position("Hips")
		if hips == Vector3.INF:
			hips = person.global_position + Vector3.UP * 0.6
		var head := person.joint_position("Head")
		print("SIDE %s t=%.2f %s root=%s hips=%s head=%s facing=%s" % [index, t, who, person.global_position, hips, head, facing])
		var views := {"side": hips + side * 2.2 + Vector3.UP * 0.25, "front": hips + (facing * 1.7 + side * 1.2) + Vector3.UP * 0.5}
		for view in views:
			cam.global_position = views[view]
			cam.look_at(hips + Vector3.UP * 0.1, Vector3.UP)
			for k in 4:
				timeline.apply_time_for_render(t)
				get_tree().call_group(&"sketch_faces", &"aim_face_now")
				await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png("%s/%02d_%s_%s.png" % [folder, index, who.replace(" ", "_"), view])
		index += 1
	get_tree().quit()

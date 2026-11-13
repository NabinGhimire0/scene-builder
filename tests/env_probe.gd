extends Node
## Prints the lighting at given times of a film: godot res://tests/EnvProbe.tscn -- <script> "t1,t2"

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
	var env := director.builder.environment
	var tl := director.builder.timeline
	var id := KeyframeStore.channel_id(tl.uid_for(env), TimelineController.CH_LIGHTING)
	for part in args[1].split(","):
		director.builder.timeline.apply_time_for_render(float(part))
		await get_tree().process_frame
		for child in director.builder.placed_props_root.get_children():
			if child is CharacterBase:
				var body: Node3D = (child as CharacterBase).get("_body")
				if body:
					print("WHO t=%s %s at %s faces %s vis %s scale %s" % [part, child.name, (child as Node3D).global_position, body.global_basis.z, (child as Node3D).is_visible_in_tree(), (child as Node3D).scale])
		var cam := director.builder.director.current_camera()
		if cam:
			print("CAM t=%s %s at %s fwd %s" % [part, cam.name, cam.global_position, -cam.global_basis.z])
		print("ENV t=%s time=%.2f sun=%.2f amb=%.2f exp=%.2f fog=%.3f mist=%.2f" % [part, env.time_of_day, env.sun_intensity, env.ambient_energy, env.exposure, env.fog_density, env.mist])
	get_tree().quit()

extends SceneTree
## godot -s res://tests/animal_test.gd -- out.png dog[,cat...] [action] [time] [side|front|three|top]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var list := args[1].split(",")
	var action := args[2] if args.size() > 2 else "Idle"
	var t := float(args[3]) if args.size() > 3 else 1.0
	var view := args[4] if args.size() > 4 else "three"
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.56, 0.62)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.64, 0.7)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.ssao_enabled = true
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.45, 0.48, 0.4)
	floor.material_override = fm
	root.add_child(floor)
	var x := 0.0
	var box := AABB()
	var first := true
	var jobs: Array = []
	for entry in list:
		for a in action.split(","):
			jobs.append([entry, a])
	for job in jobs:
		var entry: String = job[0]
		var act: String = job[1]
		var parts := entry.split(":")
		var spec := {"kind": "animal", "species": parts[0]}
		if parts.size() > 1:
			spec["pattern"] = parts[1]
		var t0 := Time.get_ticks_msec()
		var ch := AnimalBuilder.make(spec)
		if ch == null:
			print("no ", parts[0])
			continue
		root.add_child(ch)
		if jobs.size() > 1:
			ch.rotation.y = PI * 0.5
		var motion := CharacterMotion.stationary()
		motion.actions = [{"t": 0.0, "action": act}]
		(ch as ImportedCharacter).evaluate(t, motion)
		var b := PropUtils.world_aabb(ch)
		var span := maxf(b.size.x, b.size.z) * 1.15
		ch.position.x = x + span * 0.5
		x += span
		b = AABB(Vector3(ch.position.x - span * 0.5, 0, -b.size.z * 0.5), Vector3(span, b.size.y, b.size.z))
		box = b if first else box.merge(b)
		first = false
		print("%s built in %d ms, size %s, actions %s" % [parts[0], Time.get_ticks_msec() - t0, b.size, (ch as ImportedCharacter).action_names()])
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 30
	var c := box.get_center()
	var r := box.size.length() * 0.5
	var dirs := {"side": Vector3(1, 0.15, 0), "front": Vector3(0, 0.15, 1), "three": Vector3(0.8, 0.35, 0.9), "top": Vector3(0.1, 1, 0.3), "back": Vector3(-0.4, 0.3, -1)}
	var dv: Vector3 = (dirs.get(view, dirs["three"]) as Vector3).normalized()
	if jobs.size() > 1:
		dv = Vector3(0, 0.25, 1).normalized() if view == "three" else dv
	var dist := r * 3.6
	if jobs.size() > 1:
		var vs := Vector2(DisplayServer.window_get_size())
		var aspect := vs.x / vs.y
		print("viewport ", vs)
		dist = maxf(box.size.x * 0.5 / (tan(deg_to_rad(15.0)) * aspect) * 1.05, box.size.y * 2.2)
	cam.look_at_from_position(c + dv * dist, c)
	for i in 40:
		await process_frame
	get_root().get_texture().get_image().save_png(out)
	quit()

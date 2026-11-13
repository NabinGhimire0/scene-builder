extends SceneTree
## godot -s res://tests/human_test.gd -- out.png spec1.json[,spec2.json...] [action] [time] [closeup]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var specs := args[1].split(",")
	var action := args[2] if args.size() > 2 else "Idle"
	var t := float(args[3]) if args.size() > 3 else 1.0
	var close := args.size() > 4 and args[4] == "close"
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.36, 0.4, 0.46)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.68)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.ssao_enabled = true
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 35, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -130, 0)
	fill.light_energy = 0.5
	fill.light_color = Color(0.8, 0.85, 1.0)
	root.add_child(fill)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.5, 0.48, 0.45)
	floor.material_override = fm
	root.add_child(floor)
	var x := -(specs.size() - 1) * 0.35
	var tallest := 0.0
	for path in specs:
		if path.ends_with(".tscn") or path.ends_with(".glb"):
			var inst: Node3D = null
			if path.ends_with(".tscn"):
				inst = (load(path) as PackedScene).instantiate()
			else:
				var doc := GLTFDocument.new()
				var st := GLTFState.new()
				doc.append_from_file(path, st)
				inst = ImportedCharacter.new()
				inst.add_child(doc.generate_scene(st))
			root.add_child(inst)
			inst.position = Vector3(x, 0, 0)
			x += 0.7
			if inst is ImportedCharacter:
				var mo := CharacterMotion.stationary()
				mo.actions = [{"t": 0.0, "action": action}]
				(inst as ImportedCharacter).evaluate(t, mo)
			tallest = maxf(tallest, PropUtils.world_aabb(inst).size.y)
			continue
		var spec := HumanBuilder.load_spec(path)
		var t0 := Time.get_ticks_msec()
		var model := HumanBuilder.build(spec)
		print("built %s in %d ms" % [path.get_file(), Time.get_ticks_msec() - t0])
		var raw := args.size() > 5 and args[5] != ""
		var ch: Node3D = Node3D.new() if raw else ImportedCharacter.new()
		ch.add_child(model)
		root.add_child(ch)
		if raw:
			for mi in model.find_children("*", "MeshInstance3D", true, false):
				for k in (mi as MeshInstance3D).mesh.get_blend_shape_count():
					if (mi as MeshInstance3D).mesh.get_blend_shape_name(k) == args[5]:
						(mi as MeshInstance3D).set_blend_shape_value(k, 1.0)
		ch.position = Vector3(x, 0, 0)
		x += 0.7
		if ch is ImportedCharacter:
			var motion := CharacterMotion.stationary()
			motion.actions = [{"t": 0.0, "action": action}]
			(ch as ImportedCharacter).evaluate(t, motion)
		tallest = maxf(tallest, PropUtils.world_aabb(ch).size.y)
		print("height %.2f" % PropUtils.world_aabb(ch).size.y)
	var cam := Camera3D.new()
	root.add_child(cam)
	if args.size() > 4 and args[4] == "eye":
		cam.fov = 12
		cam.look_at_from_position(Vector3(0.05, tallest - 0.12, 0.6), Vector3(0.0, tallest - 0.135, 0.1))
	elif args.size() > 4 and args[4] in ["back", "side", "front3"]:
		var dirs := {"back": Vector3(0.0, 0, -1), "side": Vector3(1, 0, 0.05), "front3": Vector3(0.6, 0, 1)}
		cam.fov = 30
		var dv: Vector3 = (dirs[args[4]] as Vector3).normalized()
		var cx := (specs.size() - 1) * 0.35 - (specs.size() - 1) * 0.35
		var dist := 1.3 + specs.size() * 0.45
		cam.look_at_from_position(Vector3(cx, tallest - 0.2, 0) + dv * dist, Vector3(cx, tallest - 0.25, 0))
	elif close:
		cam.fov = 30
		cam.position = Vector3(0.25, tallest - 0.1, 0.75)
		cam.look_at_from_position(cam.position, Vector3(0, tallest - 0.12, 0))
	else:
		var w := specs.size() * 0.7
		cam.fov = 35
		var dist := maxf(tallest * 1.9, w * 1.6)
		cam.look_at_from_position(Vector3(0.6, tallest * 0.6, dist), Vector3(0, tallest * 0.5, 0))
	for i in 40:
		await process_frame
	get_root().get_texture().get_image().save_png(out)
	quit()

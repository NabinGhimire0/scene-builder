extends SceneTree
## godot -s res://tests/avatar_wardrobe_test.gd -- out.png avatar.glb[,avatar2.glb] [action] [time]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.4, 0.45, 0.52)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.68)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	root.add_child(sun)
	var items: Array = []
	for it in WardrobeItem.list_items():
		if str(it["path"]).contains("model_avaturn"):
			items.append(it["path"])
	print("items ", items)
	var x := 0.0
	var list := args[1].split(",")
	for i in list.size() * 2:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		doc.append_from_file(list[i / 2], st)
		var ch := ImportedCharacter.new()
		ch.add_child(doc.generate_scene(st))
		root.add_child(ch)
		ch.position.x = x
		x += 0.75
		var t0 := Time.get_ticks_msec()
		if i % 2 == 1:
			ch.apply_look({"wardrobe": items})
		print("dressed in ", Time.get_ticks_msec() - t0, " ms")
		var mo := CharacterMotion.stationary()
		mo.actions = [{"t": 0.0, "action": args[2] if args.size() > 2 else "Idle"}]
		ch.evaluate(float(args[3]) if args.size() > 3 else 1.0, mo)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 30
	var cx := (x - 0.75) * 0.5
	cam.look_at_from_position(Vector3(cx + 0.4, 1.2, 1.8 + x * 1.1), Vector3(cx, 1.0, 0))
	for i in 30:
		await process_frame
	get_root().get_texture().get_image().save_png(args[0])
	quit()

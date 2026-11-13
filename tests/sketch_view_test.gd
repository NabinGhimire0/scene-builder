extends SceneTree
## godot -s res://tests/sketch_view_test.gd -- out_prefix
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.4, 0.48)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var specs := [["Cartoon", "Woman", "Ponytail"], ["Cartoon", "Man", "Short"], ["Person", "Man", "Short"], ["Person", "Woman", "Long"], ["Person", "Child", "Spiky"], ["Person", "Woman", "Bob"]]
	var x := 0.0
	var chars: Array = []
	for sp in specs:
		var c: SketchCharacter = (load("res://assets/props/characters/sketch_person.tscn") as PackedScene).instantiate()
		c.figure = sp[0]
		c.body_type = sp[1]
		c.hair = sp[2]
		c.shirt_color = Color(0.2, 0.3, 0.6, 1.0)
		root.add_child(c)
		c.position.x = x
		x += 0.8
		chars.append(c)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 35
	var cx := (x - 0.8) * 0.5
	for view in [["front", Vector3(cx, 1.4, 5.0)], ["side", Vector3(cx + 7.0, 1.4, 0.3)], ["three", Vector3(cx + 4.0, 1.6, 3.5)]]:
		cam.look_at_from_position(view[1], Vector3(cx, 1.1, 0))
		for i in 15:
			var m := CharacterMotion.stationary()
			for c in chars:
				(c as CharacterBase).evaluate(0.5, m)
			await process_frame
		get_root().get_texture().get_image().save_png(out + "_" + str(view[0]) + ".png")
	quit()

extends Node3D
## Talking-face check: an avatar from Avatar Studio (face from photo) must have
## its jawOpen / eyeBlink shapes found and driven by lip sync and blinking.
## godot res://tests/FaceTest.tscn -- <avatar.glb>


func _ready() -> void:
	var file := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(RuntimeModelLoader.CHARACTERS_DIR)
	var path := RuntimeModelLoader.CHARACTERS_DIR + "face_test_avatar.glb"
	DirAccess.copy_absolute(file, ProjectSettings.globalize_path(path))
	var avatar := RuntimeModelLoader.load_scene(path).instantiate() as ImportedCharacter
	add_child(avatar)
	avatar.ensure_built()
	var kinds := {}
	for entry in avatar._face_shapes:
		kinds[entry[2]] = int(kinds.get(entry[2], 0)) + 1
	print("FACE: shapes ", kinds, " jaw bone ", avatar._jaw)
	var ok := int(kinds.get("mouth", 0)) >= 1 and int(kinds.get("blink", 0)) >= 2
	var env := PackedFloat32Array()
	for i in 60:
		env.append(1.0 if i % 20 < 10 else 0.0)
	avatar.lipsync = {"clip": "test", "start": 0.0, "fps": 30.0, "env": env}
	var motion := CharacterMotion.new()
	var open_at := -1.0
	var closed_at := -1.0
	var blinked := false
	for f in 240:
		var t := f / 30.0
		avatar.evaluate(t, motion)
		for entry in avatar._face_shapes:
			var v: float = (entry[0] as MeshInstance3D).get_blend_shape_value(entry[1])
			if entry[2] == "mouth":
				if t > 0.1 and t < 0.3:
					open_at = v
				if t > 0.4 and t < 0.6:
					closed_at = v
			elif v > 0.9:
				blinked = true
	print("FACE: mouth open ", open_at, " closed ", closed_at, " blinked ", blinked)
	ok = ok and open_at > 0.9 and closed_at < 0.1 and blinked
	print("FACE: ", "OK" if ok else "FAILED")
	if OS.get_cmdline_user_args().size() > 1:
		# Close-ups: mouth open (lip sync) and eyes shut (blink).
		var head := avatar.joint_position("Head")
		var cam := Camera3D.new()
		add_child(cam)
		cam.fov = float(OS.get_environment("FACE_FOV")) if OS.has_environment("FACE_FOV") else 22.0
		var aim := float(OS.get_environment("FACE_AIM")) if OS.has_environment("FACE_AIM") else 0.07
		cam.look_at_from_position(head + Vector3(0, aim + 0.01, 0.75), head + Vector3(0, aim, 0))
		var sun := DirectionalLight3D.new()
		add_child(sun)
		sun.rotation_degrees = Vector3(-30, 20, 0)
		var world := WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color(0.5, 0.55, 0.6)
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color.WHITE
		world.environment.ambient_light_energy = 0.5
		add_child(world)
		if OS.has_environment("FACE_HIDE_BODY"):
			for mesh in avatar.find_children("*", "MeshInstance3D", true, false):
				if not str(mesh.name).contains("Mouth"):
					(mesh as MeshInstance3D).visible = false
				else:
					print("FACE: bag mesh ", mesh.name, " surfaces ", (mesh as MeshInstance3D).mesh.get_surface_count(), " verts ", (mesh as MeshInstance3D).mesh.surface_get_array_len(0))
		for shot in [["open", 0.2, "mouth"], ["shut", 0.5, "blink"]]:
			avatar.evaluate(shot[1], motion)
			for entry in avatar._face_shapes:
				(entry[0] as MeshInstance3D).set_blend_shape_value(entry[1], 1.0 if entry[2] == shot[2] else 0.0)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[1] + "_" + shot[0] + ".png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	get_tree().quit(0 if ok else 1)

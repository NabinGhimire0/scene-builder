extends Node3D
## Renders an avatar with several hand poses side by side (front view).
## godot res://tests/PoseProbe.tscn -- <library character file name> <out.png> <json list of poses>


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var poses: Array = JSON.parse_string(args[2])
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-35, 25, 0)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.45, 0.5, 0.56)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.5
	add_child(world)
	var i := 0
	for pose in poses:
		var c := RuntimeModelLoader.load_scene(RuntimeModelLoader.CHARACTERS_DIR + args[0]).instantiate() as ImportedCharacter
		add_child(c)
		c.position = Vector3(i * 1.6, 0, 0)
		c.ensure_built()
		var motion := CharacterMotion.new()
		var dict := {}
		for joint in pose:
			var v: Array = pose[joint]
			dict[joint] = Vector3(v[0], v[1], v[2])
		c._skeleton.reset_bone_poses()
		c._relax_arms()
		c.apply_manual_pose(dict)
		i += 1
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 30
	var mid := (poses.size() - 1) * 0.8
	cam.look_at_from_position(Vector3(mid + 2.5, 1.4, 1.2 + poses.size() * 1.05), Vector3(mid, 1.1, 0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[1])
	get_tree().quit()

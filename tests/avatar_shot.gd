extends Node3D
## Renders an avatar (with its .look.json) full body and face.
## godot res://tests/AvatarShot.tscn -- <avatar.glb> <out prefix>


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var path := RuntimeModelLoader.CHARACTERS_DIR + "shot_" + args[0].get_file()
	DirAccess.make_dir_recursive_absolute(RuntimeModelLoader.CHARACTERS_DIR)
	DirAccess.copy_absolute(args[0], ProjectSettings.globalize_path(path))
	var look := args[0].get_basename() + ".look.json"
	if FileAccess.file_exists(look):
		DirAccess.copy_absolute(look, ProjectSettings.globalize_path(ImportedCharacter.look_path(path)))
	var avatar := RuntimeModelLoader.load_scene(path).instantiate() as ImportedCharacter
	add_child(avatar)
	avatar.ensure_built()
	avatar.evaluate(0.5, CharacterMotion.new())
	var box := PropUtils.world_aabb(avatar)
	print("SHOT: size ", box.size, " actions ", avatar.action_names(), " shapes ", avatar._face_shapes.size(), " parts ", avatar.parts().map(func(p: Dictionary) -> String: return "%s%s" % [p["name"], "" if (p["node"] as Node3D).visible else " (hidden)"]))
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
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(world)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 30
	var h := box.size.y
	cam.look_at_from_position(Vector3(0.6, h * 0.55, h * 2.1), Vector3(0, h * 0.5, 0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[1] + "_body.png")
	var head := avatar.joint_position("Head")
	cam.fov = 18
	cam.look_at_from_position(head + Vector3(0.05, 0.1, 0.8), head + Vector3(0, 0.08, 0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[1] + "_face.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ImportedCharacter.look_path(path)))
	get_tree().quit()

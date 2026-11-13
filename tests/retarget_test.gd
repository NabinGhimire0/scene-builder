extends Node3D
## Retargeting check: plays an animation pack on an imported avatar (right) next
## to the pack's own model playing the same clip natively (left).
## godot res://tests/RetargetTest.tscn -- <avatar.glb> <pack.glb> <frames dir> [times…]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var avatar_file := args[0]
	var pack_file := args[1]
	var frames_dir := args[2]
	var times: Array[float] = []
	for i in range(3, args.size()):
		times.append(args[i].to_float())
	if times.is_empty():
		times = [0.5, 2.3, 4.0, 4.6]
	DirAccess.make_dir_recursive_absolute(RuntimeModelLoader.CHARACTERS_DIR)
	DirAccess.make_dir_recursive_absolute(ImportedCharacter.ANIMATIONS_DIR)
	var avatar_path := RuntimeModelLoader.CHARACTERS_DIR + "retarget_avatar.glb"
	DirAccess.copy_absolute(avatar_file, ProjectSettings.globalize_path(avatar_path))
	var anim_dir := DirAccess.open(ImportedCharacter.ANIMATIONS_DIR)
	for f in anim_dir.get_files():
		anim_dir.remove(f)
	DirAccess.copy_absolute(pack_file, ProjectSettings.globalize_path(ImportedCharacter.ANIMATIONS_DIR + "test_pack.glb"))
	ImportedCharacter.forget_packs()

	var avatar := RuntimeModelLoader.load_scene(avatar_path).instantiate() as ImportedCharacter
	add_child(avatar)
	avatar.position = Vector3(0.6, 0, 0)
	avatar.ensure_built()
	var reference := RuntimeModelLoader.read_file(pack_file) as Node3D
	add_child(reference)
	reference.position = Vector3(-0.6, 0, 0)
	var player := reference.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var clip_name := str(player.get_animation_list()[0])
	player.play(clip_name)
	player.pause()
	var pack_title := ""
	for title in avatar._pack_clips:
		pack_title = title
	print("RETARGET: clips ", avatar._clips.keys(), " pack ", pack_title)
	var pack: Dictionary = avatar._pack_clips[pack_title]
	print("RETARGET: source dirs ", pack.get("dirs", {}).size(), " own dirs ", ImportedCharacter.bone_directions(avatar._skeleton, avatar._model).size())
	for b in avatar._bindings_for(pack_title):
		if int(b["bone"]) == avatar._bone_lookup.get("leftarm", -2):
			print("RETARGET: leftarm binding ", b.get("pre"), " ", b.get("post"))

	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.0, 4.2)
	cam.fov = 40
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-40, 30, 0)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.7)
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	DirAccess.make_dir_recursive_absolute(frames_dir)
	for t in times:
		player.seek(t, true)
		var pose: Dictionary = avatar._sample(pack_title, t)
		avatar._skeleton.reset_bone_poses()
		avatar._apply(pose)
		for i in 4:
			await get_tree().process_frame
		var ref_skel := reference.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var dirs_t := ImportedCharacter.bone_directions(avatar._skeleton, avatar._model)
		var rests_s: Dictionary = pack["rests"]
		for canon in ["hips", "spine2", "leftshoulder", "leftarm", "leftforearm", "rightshoulder", "rightarm"]:
			var bt: int = avatar._bone_lookup[canon]
			var bs := -1
			for i in ref_skel.get_bone_count():
				if ImportedCharacter.canonical_bone(ref_skel.get_bone_name(i)) == canon:
					bs = i
			var sg := ref_skel.get_bone_global_pose(bs).basis.get_rotation_quaternion()
			var expected := sg * (rests_s[canon][0] as Quaternion).inverse() * ImportedCharacter._align(canon, dirs_t, pack["dirs"]) * avatar._skeleton.get_bone_global_rest(bt).basis.get_rotation_quaternion()
			var actual := avatar._skeleton.get_bone_global_pose(bt).basis.get_rotation_quaternion()
			print("RETARGET: %s angle err %.1f deg" % [canon, rad_to_deg(expected.angle_to(actual))])
		for pair in [["leftarm", "leftforearm"], ["leftforearm", "lefthand"], ["rightarm", "rightforearm"], ["leftupleg", "leftleg"], ["leftshoulder", "leftarm"]]:
			print("RETARGET: t=%.1f %s ref %s avatar %s" % [t, pair[0], _dir(ref_skel, pair[0], pair[1]), _dir(avatar._skeleton, pair[0], pair[1])])
		var img := get_viewport().get_texture().get_image()
		img.save_png(frames_dir.path_join("rt_%04.1f.png" % t))
	get_tree().quit()


func _dir(skel: Skeleton3D, a: String, b: String) -> Vector3:
	var ia := -1
	var ib := -1
	for i in skel.get_bone_count():
		var c := ImportedCharacter.canonical_bone(skel.get_bone_name(i))
		if c == a and ia < 0:
			ia = i
		if c == b and ib < 0:
			ib = i
	var d := skel.global_basis * (skel.get_bone_global_pose(ib).origin - skel.get_bone_global_pose(ia).origin)
	return d.normalized().snapped(Vector3.ONE * 0.01)

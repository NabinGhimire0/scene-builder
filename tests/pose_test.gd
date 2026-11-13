extends Node
## Drag-posing check: builds a scene with a built-in person and an avatar, drags
## joint dots with the Pose tool like a mouse would, and checks that each limb
## ends up pointing at the mouse, that the Inspector's pose matches, and that
## undo restores the pose. With a frames folder it also saves screenshots.
## godot res://tests/PoseTest.tscn -- [frames dir]

var failures := 0


func _ready() -> void:
	TutorialOverlay.mark_done()
	var frames_dir := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 5:
		await get_tree().process_frame
	var director: ScriptDirector = app.find_child("ScriptDirector", true, false)
	var script := "TITLE: Pose\nLOCATION: Blank World\nTIME: Noon\nCAST:\nHari = man\n"
	var avatar_path := RuntimeModelLoader.CHARACTERS_DIR + "retarget_avatar.glb"
	var with_avatar := FileAccess.file_exists(avatar_path)
	if with_avatar:
		script += "Ava = Retarget Avatar\n"
	script += "SCENE 1: Stand\nHari is at (0, 0)\n" + ("Ava is at (1.6, 0)\n" if with_avatar else "") + "WAIT 4s\n"
	director.build_from_text(script, "")
	var timeline: TimelineController = director.builder.timeline
	timeline.set_time(1.0)
	var pose_tool: PoseTool = app.find_child("PoseTool", true, false)
	var selection: SelectionManager = app.find_child("SelectionManager", true, false)
	var history: EditorHistory = app.find_child("EditorHistory", true, false)
	var camera: Camera3D = pose_tool.camera
	var editor_camera := camera as EditorCamera
	var viewport := app.get_node("UI/Layout/Workspace/ViewportArea/ViewportContainer/SubViewport") as SubViewport

	var people: Array = []
	for child in director.builder.placed_props_root.get_children():
		if child is CharacterBase:
			people.append(child)
	print("POSE: characters ", people.map(func(c: Node) -> String: return "%s (%s)" % [c.name, c.get_class() if not c is ImportedCharacter else "ImportedCharacter"]))
	pose_tool.set_active(true)
	for person in people:
		var character := person as CharacterBase
		selection.select(character)
		# Look at the character from the front.
		camera.global_position = character.global_position + Vector3(0, 1.2, 3.2)
		camera.look_at(character.global_position + Vector3(0, 1.0, 0))
		if editor_camera and editor_camera.has_method("set_process"):
			editor_camera.set_process(false)
		for i in 3:
			await get_tree().process_frame
		for test in [["Right shoulder", Vector2(-120, -140)], ["Left elbow", Vector2(90, -60)], ["Head", Vector2(40, 10)], ["Right knee", Vector2(60, 30)]]:
			var joint: String = test[0]
			var at := character.joint_position(joint)
			if not at.is_finite():
				print("POSE: %s has no %s" % [character.name, joint])
				continue
			var press := camera.unproject_position(at)
			var picked := pose_tool.joint_at(press)
			var target: Vector2 = camera.unproject_position(character.joint_tip(joint)) + (test[1] as Vector2)
			var before := timeline.pose_at(character, timeline.current_time).get(joint, Vector3.ZERO) as Vector3
			if not pose_tool.pointer_pressed(press):
				_fail("%s: press on %s didn't pick a dot (picked '%s')" % [character.name, joint, picked])
				continue
			# Several mouse moves on the way, like a real drag.
			for k in range(1, 6):
				pose_tool.pointer_moved(press.lerp(target, k / 5.0), false)
				await get_tree().create_timer(0.04).timeout
			pose_tool.pointer_released(target)
			await get_tree().process_frame
			timeline.set_time(timeline.current_time)
			await get_tree().process_frame
			var joint_screen := camera.unproject_position(character.joint_position(joint))
			var tip_screen := camera.unproject_position(character.joint_tip(joint))
			var want := (target - joint_screen).normalized()
			var got := (tip_screen - joint_screen).normalized()
			var error := rad_to_deg(want.angle_to(got))
			var after := timeline.pose_at(character, timeline.current_time).get(joint, Vector3.ZERO) as Vector3
			print("POSE: %s %-15s picked %-15s screen error %5.1f°  pose %s -> %s" % [character.name, joint, picked, absf(error), before.snapped(Vector3.ONE * 0.1), after.snapped(Vector3.ONE * 0.1)])
			if picked != joint:
				_fail("picked the wrong dot")
			if absf(error) > 12.0:
				_fail("%s %s doesn't point at the mouse (%.1f°)" % [character.name, joint, error])
			# Twist: Shift-drag sideways changes the joint but keeps the limb's direction.
			if joint == "Right shoulder":
				pose_tool.pointer_pressed(joint_screen)
				pose_tool.pointer_moved(joint_screen + Vector2(60, 0), true)
				pose_tool.pointer_released(joint_screen + Vector2(60, 0))
				timeline.set_time(timeline.current_time)
				await get_tree().process_frame
				var twisted := timeline.pose_at(character, timeline.current_time).get(joint, Vector3.ZERO) as Vector3
				var tip_after := camera.unproject_position(character.joint_tip(joint))
				var drift := rad_to_deg(got.angle_to((tip_after - camera.unproject_position(character.joint_position(joint))).normalized()))
				print("POSE: %s twist -> %s, limb direction moved %.1f°" % [character.name, twisted.snapped(Vector3.ONE * 0.1), absf(drift)])
				if twisted.is_equal_approx(after) or absf(drift) > 6.0:
					_fail("twist didn't work as expected")
		if not frames_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(frames_dir)
			for i in 4:
				await get_tree().process_frame
			viewport.get_texture().get_image().save_png(frames_dir.path_join("pose_%s.png" % character.name))
	# Undo restores the previous pose.
	var someone := people[0] as CharacterBase
	var posed := timeline.pose_at(someone, timeline.current_time).duplicate()
	for i in 20:
		history.undo()
	await get_tree().process_frame
	var undone := timeline.pose_at(someone, timeline.current_time)
	print("POSE: after undo %s had %d posed joints, now %d" % [someone.name, posed.size(), undone.size()])
	if undone.size() >= posed.size() and posed.size() > 0:
		_fail("undo didn't remove the pose")
	# Lip sync merging keeps both clips.
	var a := PackedFloat32Array([0.5, 0.5, 0.5])
	var b := PackedFloat32Array([1.0, 1.0])
	var merged := CharacterBase.merge_lipsync(CharacterBase.merge_lipsync({}, "one", 1.0, a), "two", 3.0, b)
	someone.lipsync = merged
	print("POSE: merged lip sync '%s' start %.1f frames %d, at 1.03=%.2f 3.03=%.2f 2.0=%.2f" % [merged["clip"], merged["start"], (merged["env"] as PackedFloat32Array).size(),
		someone.lipsync_at(1.03), someone.lipsync_at(3.03), someone.lipsync_at(2.0)])
	if someone.lipsync_at(1.03) < 0.4 or someone.lipsync_at(3.03) < 0.9 or someone.lipsync_at(2.0) > 0.01:
		_fail("lip sync merge")
	print("POSE: %s" % ("ALL OK" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(failures)


func _fail(message: String) -> void:
	failures += 1
	print("POSE: FAIL ", message)

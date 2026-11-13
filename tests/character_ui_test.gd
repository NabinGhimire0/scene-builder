extends Node
## Screenshot of the Inspector's character sections (lip sync, pose) with pose
## mode on and a voice clip loaded; also previews the clip.
## godot res://tests/CharacterUITest.tscn -- <out dir> <some .wav>

func _ready() -> void:
	TutorialOverlay.mark_done()
	var out := OS.get_cmdline_user_args()[0]
	var wav := OS.get_cmdline_user_args()[1]
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 6:
		await get_tree().process_frame
	var director: ScriptDirector = app.find_child("ScriptDirector", true, false)
	director.build_from_text("TITLE: UI\nLOCATION: Living Room\nCAST:\nBabu = man, top mustard\nSCENE 1: S\nBabu is at center\nWAIT 6s\n", "")
	var audio: AudioTrack = director.builder.audio
	var history: EditorHistory = app.find_child("EditorHistory", true, false)
	var clip := audio.import_file(wav, 1.0)
	clip["name"] = "Babu line 1"
	var after := audio.to_list()
	after.append(clip)
	history.record_snapshot("Add", audio.load_list, audio.to_list(), after)
	var babu: CharacterBase
	for c in director.builder.placed_props_root.get_children():
		if c is CharacterBase:
			babu = c
	var selection: SelectionManager = app.find_child("SelectionManager", true, false)
	selection.select(babu)
	var pose_tool: PoseTool = app.find_child("PoseTool", true, false)
	pose_tool.set_active(true)
	var cam := pose_tool.camera
	cam.global_position = babu.global_position + Vector3(1.2, 1.4, 2.6)
	cam.look_at(babu.global_position + Vector3(0, 1.0, 0))
	audio.preview(0)
	print("UI: previewing clip ", audio.previewing(), " playing=", audio._preview_player.playing)
	for i in 10:
		await get_tree().process_frame
	var inspector := app.find_child("InspectorPanel", true, false)
	var lip_record: Button = inspector.get("_lip_record")
	var scroll := inspector.find_children("*", "ScrollContainer", true, false)
	if not scroll.is_empty() and lip_record:
		(scroll[0] as ScrollContainer).ensure_control_visible(lip_record)
		for i in 4:
			await get_tree().process_frame
		(scroll[0] as ScrollContainer).scroll_vertical = int(lip_record.global_position.y - (scroll[0] as ScrollContainer).global_position.y + (scroll[0] as ScrollContainer).scroll_vertical - 60)
	for i in 6:
		await get_tree().process_frame
	get_tree().root.get_texture().get_image().save_png(out.path_join("character_ui.png"))
	# Film tab
	var tabs := inspector.find_children("*", "TabContainer", true, false)
	if not tabs.is_empty():
		var tc := tabs[0] as TabContainer
		for i in tc.get_tab_count():
			if tc.get_tab_title(i).to_lower().contains("film"):
				tc.current_tab = i
	for i in 6:
		await get_tree().process_frame
	get_tree().root.get_texture().get_image().save_png(out.path_join("film_tab.png"))
	# A finished recording for Babu syncs his mouth; a second one is added to it.
	audio.record_target = babu
	audio.recorded.emit(0)
	await get_tree().process_frame
	var clip2 := audio.import_file(OS.get_cmdline_user_args()[1], 4.0)
	clip2["name"] = "Babu line 2"
	var after2 := audio.to_list()
	after2.append(clip2)
	history.record_snapshot("Add", audio.load_list, audio.to_list(), after2)
	audio.record_target = babu
	audio.recorded.emit(1)
	await get_tree().process_frame
	print("UI: lip sync follows '%s' from %.1f s, mouth at 1.5 s = %.2f, at 4.5 s = %.2f, at 3.9 s = %.2f" % [babu.lipsync.get("clip", ""), float(babu.lipsync.get("start", -1)), babu.lipsync_at(1.5), babu.lipsync_at(4.5), babu.lipsync_at(3.95)])
	history.undo()
	print("UI: after undo follows '%s'" % babu.lipsync.get("clip", ""))
	print("UI: saved")
	get_tree().quit()

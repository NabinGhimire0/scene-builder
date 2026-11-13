extends Control
## Guided face points: three clicks place all 18 front points; automatic points
## load; old 3-point settings are expanded; side photo takes 5 clicks; and the
## Avatar Studio sends the new face settings to the builder.
## godot res://tests/PhotoMarkerTest.tscn -- <front photo> <auto points json> <shot.png>


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var ok := true
	var marker := PhotoMarker.new()
	marker.position = Vector2(10, 10)
	marker.size = Vector2(420, 520)
	add_child(marker)
	await get_tree().process_frame
	ok = ok and marker.set_photo(args[0])
	print("PHOTO: hint ", marker.hint())
	var rect := marker._image_rect()
	for uv in [Vector2(0.389, 0.466), Vector2(0.62, 0.466), Vector2(0.5, 0.64)]:
		marker._press(rect.position + uv * rect.size)
	print("PHOTO: after 3 clicks complete=", marker.is_complete(), " points=", marker.points.size())
	ok = ok and marker.is_complete() and marker.points.size() == 18
	var chin: Array = marker.points["chin"]
	print("PHOTO: chin at ", chin)
	ok = ok and float(chin[1]) > 0.72 and float(chin[1]) < 0.85
	# Drag a point.
	var before: Array = marker.points["nose_tip"]
	var at := marker._to_screen(Vector2(float(before[0]), float(before[1])))
	marker._press(at)
	var mm := InputEventMouseMotion.new()
	mm.position = at + Vector2(10, 5)
	marker._gui_input(mm)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	marker._gui_input(up)
	print("PHOTO: dragged nose ", before, " -> ", marker.points["nose_tip"])
	ok = ok and float(marker.points["nose_tip"][0]) > float(before[0])
	# Old settings (eyes + mouth only) are expanded.
	marker.set_points({"left_eye": [0.389, 0.466], "right_eye": [0.62, 0.466], "mouth": [0.5, 0.64]})
	ok = ok and marker.is_complete()
	var all := marker.all_points()
	ok = ok and all.has("left_eye") and all.size() == 21
	# Automatic points.
	var auto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	marker.set_points(auto["points"])
	print("PHOTO: auto complete=", marker.is_complete())
	ok = ok and marker.is_complete()
	marker._hover = "mouth_l"
	marker.queue_redraw()
	# Side photo.
	var side := PhotoMarker.new()
	side.mode = PhotoMarker.Mode.SIDE
	side.position = Vector2(440, 10)
	side.size = Vector2(300, 300)
	add_child(side)
	await get_tree().process_frame
	side.set_photo(args[0])
	var srect := side._image_rect()
	for i in 5:
		side._press(srect.position + Vector2(0.2 + i * 0.12, 0.5) * srect.size)
	print("PHOTO: side complete=", side.is_complete())
	ok = ok and side.is_complete() and side.hint().begins_with("Now drag")
	# Avatar Studio settings.
	var studio := AvatarStudio.new()
	add_child(studio)
	await get_tree().process_frame
	studio._on_photo_chosen(args[0])
	studio._photo.set_points(auto["points"])
	studio._on_side_chosen(args[0])
	studio._side.set_points({"side_eye": [0.7, 0.46], "side_nose": [0.8, 0.55], "side_mouth": [0.77, 0.63], "side_chin": [0.75, 0.77], "side_ear": [0.45, 0.55]})
	var settings: Dictionary = studio._settings()
	print("PHOTO: settings points ", (settings["face_points"] as Dictionary).size(), " side ", (settings["face_side_points"] as Dictionary).size(),
		" fit ", settings["face_fit"], " talking ", settings["talking_face"])
	ok = ok and (settings["face_points"] as Dictionary).size() == 21 and (settings["face_side_points"] as Dictionary).size() == 5
	ok = ok and not str(settings["face_side_photo"]).is_empty() and settings["talking_face"] == true
	var state: Dictionary = studio._body_state()
	ok = ok and (state["side_points"] as Dictionary).size() == 5
	studio.queue_free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[2])
	print("PHOTO: ", "OK" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)

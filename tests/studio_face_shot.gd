extends Node
## Screenshot of Avatar Studio's face-from-photo section with points placed.
## godot res://tests/StudioFaceShot.tscn -- <front photo> <auto points json> <shot.png>


func _ready() -> void:
	TutorialOverlay.mark_done()
	var args := OS.get_cmdline_user_args()
	var studio := AvatarStudio.new()
	get_tree().root.add_child.call_deferred(studio)
	await get_tree().process_frame
	await get_tree().process_frame
	studio.popup_centered(Vector2i(1180, 860))
	await get_tree().process_frame
	studio._on_photo_chosen(args[0])
	studio._photo.set_points(JSON.parse_string(FileAccess.get_file_as_string(args[1]))["points"])
	studio._photo._hover = "nose_l"
	studio._photo_hint.text = studio._photo.hint()
	for i in 5:
		await get_tree().process_frame
	var scroll := studio._photo.get_parent().get_parent() as ScrollContainer
	if scroll:
		scroll.scroll_vertical = int(studio._photo.position.y - 160)
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	studio.get_viewport().get_texture().get_image().save_png(args[2])
	get_tree().quit()

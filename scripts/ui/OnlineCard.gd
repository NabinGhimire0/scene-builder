class_name OnlineCard
extends Button
## One online search result. Click to download; once downloaded, click to
## place (like a library card) or drag it into the scene.

var result: Dictionary = {}
var online: OnlineLibrary
var placement: PlacementController
var scene_path := ""


func setup(search_result: Dictionary, online_library: OnlineLibrary, placement_controller: PlacementController) -> void:
	result = search_result
	online = online_library
	placement = placement_controller
	theme_type_variation = &"AssetCard"
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = AssetCard.CARD_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	clip_text = true
	add_theme_constant_override("icon_max_width", AssetCard.ICON_WIDTH)
	scene_path = OnlineLibrary.downloaded_path(str(result["provider"]), str(result["id"]))
	_update_text()
	pressed.connect(_on_pressed)
	online.request_thumbnail(str(result.get("thumbnail", "")), set_thumbnail)


func set_thumbnail(texture: Texture2D) -> void:
	icon = texture


func show_progress(fraction: float) -> void:
	text = "%d%%" % roundi(clampf(fraction, 0.0, 1.0) * 100.0)


func download_finished(path: String, error: String) -> void:
	scene_path = path
	disabled = false
	_update_text()
	if not error.is_empty():
		tooltip_text = "Download failed: %s\nClick to try again." % error


func _update_text() -> void:
	var title := str(result.get("title", "Model"))
	var licence := str(result.get("license", ""))
	text = title if not scene_path.is_empty() else "+ " + title
	var note := ""
	if scene_path.is_empty() and bool(result.get("needs_blender", false)):
		note = "\nNeeds Blender: BlendKit only has a .blend file, which your Blender converts (takes a little longer)."
		text = "+ " + title + " (Blender)"
	if scene_path.is_empty() and not bool(result.get("can_download", true)):
		note += "\nNot included in your BlendKit plan."
		text = "(plan) " + title
	tooltip_text = "%s\nby %s · %s\n%s%s" % [
		title, result.get("author", "unknown"), licence,
		"Downloaded: click to place, or drag into the scene." if not scene_path.is_empty() else "Click to download.", note]


func descriptor() -> Dictionary:
	return {
		"prop_id": ("%s_%s" % [result.get("provider", ""), result.get("id", "")]).to_snake_case(),
		"scene_path": scene_path,
		"display_name": str(result.get("title", "Model")),
		"category": PropCatalog.DOWNLOADED_CATEGORY,
	}


func _on_pressed() -> void:
	if scene_path.is_empty():
		if online.is_downloading(str(result["provider"]), str(result["id"])):
			return
		disabled = true
		text = "0%"
		online.download(result)
	elif placement:
		placement.begin_placement(descriptor())


func _get_drag_data(_at_position: Vector2) -> Variant:
	if scene_path.is_empty():
		return null
	var preview := Label.new()
	preview.text = "  " + str(result.get("title", "Model"))
	set_drag_preview(preview)
	var data := descriptor()
	data["type"] = "prop"
	return data

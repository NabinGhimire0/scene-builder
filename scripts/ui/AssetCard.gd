class_name AssetCard
extends Button
## One asset tile in the library: thumbnail + name.
## Click to start click-placement (click again to stop), or drag into the scene.

signal prop_toggled(card: AssetCard, prop: Dictionary, on: bool)
## Right-click on one of your own items (characters, avatars, imports).
signal delete_requested(prop: Dictionary)

const CARD_SIZE := Vector2(104, 116)
const ICON_WIDTH := 76

var prop: Dictionary = {}


func setup(prop_data: Dictionary) -> void:
	prop = prop_data
	text = str(prop_data.get("display_name", "Prop"))
	tooltip_text = "%s · %s\nClick to place several, or drag into the scene to place one." % [
		text, prop_data.get("category", PropCatalog.DEFAULT_CATEGORY)]
	if prop_data.has("credit"):
		tooltip_text += "\n" + str(prop_data["credit"])
	if str(prop_data.get("scene_path", "")).begins_with("user://library/"):
		tooltip_text += "\nRight-click to delete it."
	theme_type_variation = &"AssetCard"
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	clip_text = true
	add_theme_constant_override("icon_max_width", ICON_WIDTH)
	toggled.connect(_on_toggled)


func set_thumbnail(texture: Texture2D) -> void:
	icon = texture


func matches(query: String, category: String) -> bool:
	if not category.is_empty() and str(prop.get("category", "")) != category:
		return false
	if query.is_empty():
		return true
	return str(prop.get("display_name", "")).to_lower().contains(query) \
		or str(prop.get("category", "")).to_lower().contains(query)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and str(prop.get("scene_path", "")).begins_with("user://library/"):
		accept_event()
		var menu := PopupMenu.new()
		menu.add_item("Delete \"%s\"…" % text, 0)
		menu.id_pressed.connect(func(_id: int) -> void: delete_requested.emit(prop))
		menu.popup_hide.connect(menu.queue_free)
		add_child(menu)
		menu.popup(Rect2i(Vector2i(get_screen_position() + mb.position), Vector2i.ZERO))


func _on_toggled(on: bool) -> void:
	prop_toggled.emit(self, prop, on)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if prop.is_empty():
		return null
	set_drag_preview(_make_drag_preview())
	var data := prop.duplicate()
	data["type"] = "prop"
	return data


func _make_drag_preview() -> Control:
	# Offset down-right of the cursor so it doesn't hide the 3D ghost.
	var holder := Control.new()
	var row := HBoxContainer.new()
	row.position = Vector2(18, 18)
	row.modulate = Color(1, 1, 1, 0.85)
	holder.add_child(row)
	if icon:
		var thumb := TextureRect.new()
		thumb.texture = icon
		thumb.custom_minimum_size = Vector2(40, 40)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(thumb)
	var label := Label.new()
	label.text = text
	row.add_child(label)
	return holder

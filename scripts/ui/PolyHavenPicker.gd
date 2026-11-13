class_name PolyHavenPicker
extends AcceptDialog
## Browse-and-download window for Poly Haven photo skies (HDRIs) and PBR
## textures. Click a picture: it downloads (if needed) and is applied.

signal chosen(path: String, id: String, title: String)

const CARD_SIZE := Vector2(156, 128)

var online: OnlineLibrary
var catalog_type := "textures"

var _query: LineEdit
var _status: Label
var _grid: GridContainer
var _more: Button
var _page := 0
var _cards: Dictionary = {}     # key -> Button
var _results: Dictionary = {}   # key -> result
var _busy := false


func setup(online_library: OnlineLibrary) -> void:
	online = online_library
	ok_button_text = "Close"
	min_size = Vector2i(760, 560)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var row := HBoxContainer.new()
	_query = LineEdit.new()
	_query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_query.clear_button_enabled = true
	_query.text_submitted.connect(func(_t: String) -> void: _search(0))
	row.add_child(_query)
	var go := Button.new()
	go.text = "Search"
	go.pressed.connect(func() -> void: _search(0))
	row.add_child(go)
	root.add_child(row)

	_status = Label.new()
	_status.theme_type_variation = &"DimLabel"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(700, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	list.add_child(_grid)
	scroll.resized.connect(func() -> void: _grid.columns = maxi(1, floori((scroll.size.x - 12.0) / (CARD_SIZE.x + 8.0))))
	_more = Button.new()
	_more.text = "Load more"
	_more.visible = false
	_more.pressed.connect(func() -> void: _search(_page + 1))
	list.add_child(_more)

	var footer := Label.new()
	footer.theme_type_variation = &"DimLabel"
	footer.text = "Powered by Poly Haven — free CC0 photo skies and textures, no credit required."
	root.add_child(footer)
	online.download_progress.connect(_on_progress)


## Opens the window for "hdris" (photo skies) or "textures".
func open_for(kind_plural: String) -> void:
	catalog_type = kind_plural
	title = "Choose a photo sky (HDRI)" if kind_plural == "hdris" else "Choose a texture"
	_query.placeholder_text = "e.g. sunset, forest, studio, overcast" if kind_plural == "hdris" else "e.g. grass, cobblestone, wood, brick, concrete"
	popup_centered()
	_search(0)


func _search(page: int) -> void:
	if _busy:
		return
	_busy = true
	_page = page
	if page == 0:
		for child in _grid.get_children():
			child.queue_free()
		_cards.clear()
		_results.clear()
	_more.visible = false
	_status.text = "Searching Poly Haven…"
	var response: Dictionary = await online.query_polyhaven(catalog_type, _query.text, page)
	_busy = false
	if not str(response.get("error", "")).is_empty():
		_status.text = str(response["error"])
		return
	for result in response.get("results", []):
		_add_card(result)
	_more.visible = bool(response.get("has_more", false))
	if _cards.is_empty():
		_status.text = "No results — try another word."
	else:
		_status.text = "%d results. Click one to use it (it downloads the first time)." % _cards.size()


func _add_card(result: Dictionary) -> void:
	var key := OnlineLibrary.result_key(result)
	var card := Button.new()
	card.theme_type_variation = &"AssetCard"
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.clip_text = true
	card.add_theme_constant_override("icon_max_width", int(CARD_SIZE.x) - 16)
	card.text = str(result.get("title", "?"))
	card.tooltip_text = "%s\n%s" % [result.get("title", ""), "Downloaded" if not _downloaded_path(result).is_empty() else "Click to download and use"]
	card.pressed.connect(_on_card_pressed.bind(key))
	_grid.add_child(card)
	_cards[key] = card
	_results[key] = result
	online.request_thumbnail(str(result.get("thumbnail", "")), _set_card_icon.bind(card))


func _set_card_icon(texture: Texture2D, card: Button) -> void:
	if is_instance_valid(card):
		card.icon = texture


func _downloaded_path(result: Dictionary) -> String:
	return OnlineLibrary.downloaded_path(str(result["provider"]), str(result["id"]), str(result.get("kind", "model")))


func _on_card_pressed(key: String) -> void:
	var result: Dictionary = _results.get(key, {})
	if result.is_empty():
		return
	var path := _downloaded_path(result)
	if path.is_empty():
		var card: Button = _cards[key]
		card.disabled = true
		card.text = "Downloading…"
		var outcome: Dictionary = await online.download_asset(result)
		if not is_instance_valid(card):
			return
		card.disabled = false
		card.text = str(result.get("title", "?"))
		path = str(outcome["path"])
		if path.is_empty():
			_status.text = str(outcome["error"])
			return
	chosen.emit(path, str(result["id"]), str(result.get("title", "")))
	hide()


func _on_progress(key: String, fraction: float) -> void:
	var card: Button = _cards.get(key)
	if card and card.disabled:
		card.text = "Downloading %d%%" % roundi(clampf(fraction, 0.0, 1.0) * 100.0)

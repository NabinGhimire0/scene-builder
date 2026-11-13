class_name OnlineLibraryPanel
extends VBoxContainer
## "Online" tab of the asset browser: search Poly Haven / Poly Pizza / BlendKit, download
## with one click, then click or drag the card to place the model.

var online: OnlineLibrary
var placement: PlacementController

var _provider: OptionButton
var _key_row: HBoxContainer
var _key_edit: LineEdit
var _bk_box: VBoxContainer
var _bk_key: LineEdit
var _bk_free: CheckBox
var _blender_label: Label
var _blender_dialog: FileDialog
var _query: LineEdit
var _status: Label
var _grid: GridContainer
var _more: Button
var _footer: Label
var _cards: Dictionary = {}     # store key -> OnlineCard
var _page := 0
var _activated := false
var _busy := false


func setup(online_library: OnlineLibrary, placement_controller: PlacementController) -> void:
	online = online_library
	placement = placement_controller
	add_theme_constant_override("separation", 6)

	_provider = OptionButton.new()
	_provider.add_item("Poly Haven · realistic, CC0, no account")
	_provider.add_item("Poly Pizza · low-poly, free API key")
	_provider.add_item("BlendKit · huge library, free models need no account")
	_provider.focus_mode = Control.FOCUS_NONE
	_provider.item_selected.connect(func(_i: int) -> void: _on_provider_changed())
	add_child(_provider)

	_key_row = HBoxContainer.new()
	_key_edit = LineEdit.new()
	_key_edit.placeholder_text = "Paste Poly Pizza API key"
	_key_edit.secret = true
	_key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_edit.text = str(OnlineLibrary.get_setting("polypizza_key", ""))
	_key_edit.text_submitted.connect(func(_t: String) -> void: _save_key())
	_key_row.add_child(_key_edit)
	var save := Button.new()
	save.text = "Save"
	save.pressed.connect(_save_key)
	_key_row.add_child(save)
	var get_key := LinkButton.new()
	get_key.text = "Get a free key"
	get_key.pressed.connect(func() -> void: OS.shell_open(OnlineLibrary.POLYPIZZA_KEY_URL))
	add_child(_key_row)
	add_child(get_key)
	get_key.visible = false
	_key_row.set_meta(&"link", get_key)

	_build_blendkit_box()

	var search_row := HBoxContainer.new()
	_query = LineEdit.new()
	_query.placeholder_text = "Search online (e.g. chair, tree, car)"
	_query.clear_button_enabled = true
	_query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_query.text_submitted.connect(func(_t: String) -> void: _search(0))
	search_row.add_child(_query)
	var go := Button.new()
	go.text = "Search"
	go.pressed.connect(func() -> void: _search(0))
	search_row.add_child(go)
	add_child(search_row)

	_status = Label.new()
	_status.theme_type_variation = &"DimLabel"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	list.add_child(_grid)
	scroll.resized.connect(func() -> void: _grid.columns = maxi(1, floori((scroll.size.x - 12.0) / 104.0)))
	_more = Button.new()
	_more.text = "Load more"
	_more.visible = false
	_more.pressed.connect(func() -> void: _search(_page + 1))
	list.add_child(_more)

	_footer = Label.new()
	_footer.theme_type_variation = &"DimLabel"
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_footer)

	online.search_completed.connect(_on_search_completed)
	online.download_progress.connect(_on_download_progress)
	online.download_completed.connect(_on_download_completed)
	_on_provider_changed()


## Called when the tab is shown; loads popular models the first time.
func activate() -> void:
	if not _activated:
		_activated = true
		_search(0)


func _build_blendkit_box() -> void:
	_bk_box = VBoxContainer.new()
	_bk_box.add_theme_constant_override("separation", 4)
	add_child(_bk_box)
	var key_row := HBoxContainer.new()
	_bk_key = LineEdit.new()
	_bk_key.placeholder_text = "BlendKit API key (optional, for your plan)"
	_bk_key.secret = true
	_bk_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bk_key.text = OnlineLibrary.blendkit_key()
	_bk_key.text_submitted.connect(func(_t: String) -> void: _save_bk_key())
	key_row.add_child(_bk_key)
	var save := Button.new()
	save.text = "Save"
	save.pressed.connect(_save_bk_key)
	key_row.add_child(save)
	_bk_box.add_child(key_row)
	_bk_free = CheckBox.new()
	_bk_free.text = "Free models only"
	_bk_free.button_pressed = bool(OnlineLibrary.get_setting("blendkit_free_only", true))
	_bk_free.toggled.connect(func(on: bool) -> void:
		OnlineLibrary.set_setting("blendkit_free_only", on)
		_search(0))
	_bk_box.add_child(_bk_free)
	var blender_row := HBoxContainer.new()
	_blender_label = Label.new()
	_blender_label.theme_type_variation = &"DimLabel"
	_blender_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blender_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blender_row.add_child(_blender_label)
	var locate := Button.new()
	locate.text = "Blender…"
	locate.tooltip_text = "Choose blender.exe. Only needed for models that BlendKit offers as .blend files."
	locate.pressed.connect(func() -> void: _blender_dialog.popup_centered_ratio(0.6))
	blender_row.add_child(locate)
	_bk_box.add_child(blender_row)
	_blender_dialog = FileDialog.new()
	_blender_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_blender_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_blender_dialog.title = "Find Blender (blender.exe)"
	_blender_dialog.file_selected.connect(func(path: String) -> void:
		OnlineLibrary.set_setting("blender_path", path)
		_update_blender_label())
	add_child(_blender_dialog)
	_update_blender_label()


func _update_blender_label() -> void:
	var path := OnlineLibrary.blender_path()
	if path.is_empty():
		_blender_label.text = "Blender: not found. Models marked (Blender) can't be converted yet."
	else:
		_blender_label.text = "Blender: %s" % path.get_file() if path.get_file() != "blender.exe" else "Blender: %s" % path.get_base_dir().get_file()
		_blender_label.tooltip_text = path


func _save_bk_key() -> void:
	OnlineLibrary.set_setting("blendkit_key", _bk_key.text.strip_edges())
	EventBus.info("BlendKit API key saved." if not _bk_key.text.strip_edges().is_empty() else "BlendKit key removed: showing free models.")
	_search(0)


func _provider_id() -> int:
	match _provider.selected:
		1: return OnlineLibrary.Provider.POLY_PIZZA
		2: return OnlineLibrary.Provider.BLENDKIT
	return OnlineLibrary.Provider.POLY_HAVEN


func _on_provider_changed() -> void:
	var pizza := _provider_id() == OnlineLibrary.Provider.POLY_PIZZA
	var blendkit := _provider_id() == OnlineLibrary.Provider.BLENDKIT
	_key_row.visible = pizza
	(_key_row.get_meta(&"link") as Control).visible = pizza
	_bk_box.visible = blendkit
	if blendkit:
		_update_blender_label()
		_footer.text = "Models from BlendKit (blendkit.com). Free models are Royalty Free or CC0 — fine for YouTube; authors are listed in the credits file of every export. Models marked (Blender) are converted by your own Blender, in the background."
	elif pizza:
		_footer.text = "Poly Pizza models are CC0 or CC-BY. CC-BY authors are credited automatically in a credits file next to every exported video. Check Poly Pizza's terms for commercial API use."
	else:
		_footer.text = "Powered by Poly Haven — free CC0 models, no credit required."
	if _activated:
		_search(0)


func _save_key() -> void:
	OnlineLibrary.set_setting("polypizza_key", _key_edit.text.strip_edges())
	EventBus.info("Poly Pizza API key saved.")
	if _provider_id() == OnlineLibrary.Provider.POLY_PIZZA:
		_search(0)


func _search(page: int) -> void:
	_page = page
	if page == 0:
		for child in _grid.get_children():
			child.queue_free()
		_cards.clear()
	_busy = true
	_more.visible = false
	_status.text = "Searching %s…" % OnlineLibrary.PROVIDER_NAMES[_provider_id()]
	online.search(_provider_id(), _query.text, page)


func _on_search_completed(results: Array, has_more: bool, error: String) -> void:
	_busy = false
	if not error.is_empty():
		_status.text = error
		return
	for result in results:
		var card := OnlineCard.new()
		card.setup(result, online, placement)
		_grid.add_child(card)
		_cards[OnlineLibrary.key_for(str(result["provider"]), str(result["id"]))] = card
	_more.visible = has_more
	if _cards.is_empty():
		_status.text = "No results. Try another word (English names work best)."
	else:
		_status.text = "%d results. Click a card to download it, then click or drag it to place." % _cards.size()
		if _provider_id() == OnlineLibrary.Provider.BLENDKIT and OnlineLibrary.blender_path().is_empty():
			_status.text += " Cards marked (Blender) need Blender installed."


func _on_download_progress(key: String, fraction: float) -> void:
	var card: OnlineCard = _cards.get(key)
	if card:
		card.show_progress(fraction)


func _on_download_completed(key: String, path: String, error: String) -> void:
	var card: OnlineCard = _cards.get(key)
	if card:
		card.download_finished(path, error)
	if error.is_empty():
		EventBus.info("Downloaded — it's also in Library → Downloaded. Click the card (or drag it) to place it.")
	else:
		EventBus.error(error)

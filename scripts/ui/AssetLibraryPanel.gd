extends PanelContainer
## Left-hand asset browser with two tabs:
##  • Library – built-in assets plus downloaded / imported ones, grouped by
##    category, with search and a category filter (columns adapt to width).
##  • Online  – search and download from Poly Haven and Poly Pizza.
## The Import menu adds the user's own .glb models and rigged characters.

@export var placement: PlacementController
@export var online: OnlineLibrary

const MIN_CARD_WIDTH := 104.0

var _cards: Array[AssetCard] = []
var _sections: Dictionary = {}   # category -> { "header": Label, "grid": GridContainer }
var _categories := PackedStringArray()
var _thumbnails: ThumbnailRenderer
var _library_tab: Button
var _online_tab: Button
var _online_panel: OnlineLibraryPanel
var _library_controls: Array[Control] = []
var _import_dialog: FileDialog
var _import_as_character := false
var _import_animation := false
var _avatar_studio: AvatarStudio

@onready var _list: VBoxContainer = %AssetList
@onready var _scroll: ScrollContainer = %AssetScroll
@onready var _search: LineEdit = %AssetSearch
@onready var _category_filter: OptionButton = %CategoryFilter
@onready var _empty_label: Label = %EmptyLabel
@onready var _rescan_button: Button = %RescanButton


func _ready() -> void:
	_thumbnails = ThumbnailRenderer.new()
	_thumbnails.name = "ThumbnailRenderer"
	add_child(_thumbnails)
	_search.text_changed.connect(func(_t: String) -> void: _apply_filter())
	_category_filter.item_selected.connect(func(_i: int) -> void: _apply_filter())
	_rescan_button.pressed.connect(refresh)
	_scroll.resized.connect(_update_columns)
	EventBus.placement_started.connect(_on_placement_started)
	EventBus.placement_ended.connect(_on_placement_ended)
	_build_tabs_and_import()
	if online:
		online.library_changed.connect(refresh)
	refresh.call_deferred()  # after the status bar is listening


func _build_tabs_and_import() -> void:
	var vbox := _search.get_parent() as VBoxContainer
	var header := _rescan_button.get_parent() as HBoxContainer
	var title := header.get_child(0) as Label
	if title:
		title.text = "Assets"

	var import_menu := MenuButton.new()
	import_menu.text = "Import"
	import_menu.flat = false
	import_menu.tooltip_text = "Add your own .glb models or rigged characters"
	import_menu.get_popup().add_item("Import model (.glb / .fbx)…", 0)
	import_menu.get_popup().add_item("Import rigged character (.glb / .fbx, e.g. Mixamo)…", 1)
	import_menu.get_popup().add_item("Import animation pack (.fbx from Mixamo, or .glb)…", 2)
	import_menu.get_popup().add_item("Avatar Studio (build, preview & customise avatars)…", 3)
	import_menu.get_popup().id_pressed.connect(_on_import_chosen)
	header.add_child(import_menu)
	var studio_button := Button.new()
	studio_button.text = "Avatars"
	studio_button.tooltip_text = "Avatar Studio: build realistic people, preview them, change colours and clothes, try animations"
	studio_button.pressed.connect(open_avatar_studio)
	header.add_child(studio_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	_library_tab = _tab_button("Library", "Your assets", group)
	_online_tab = _tab_button("Online", "Free models from Poly Haven, Poly Pizza and BlendKit", group)
	_library_tab.button_pressed = true
	tabs.add_child(_library_tab)
	tabs.add_child(_online_tab)
	vbox.add_child(tabs)
	vbox.move_child(tabs, header.get_index() + 1)
	_library_tab.pressed.connect(_show_tab.bind(false))
	_online_tab.pressed.connect(_show_tab.bind(true))

	_library_controls = [_search, _category_filter, _empty_label, _scroll]
	_online_panel = OnlineLibraryPanel.new()
	_online_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_online_panel.visible = false
	vbox.add_child(_online_panel)
	_online_panel.setup(online, placement)

	_import_dialog = FileDialog.new()
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_dialog.filters = PackedStringArray(["*.glb, *.fbx ; 3D models (glTF binary, FBX / Mixamo)"])
	_import_dialog.file_selected.connect(_on_import_file)
	if "use_native_dialog" in _import_dialog:
		_import_dialog.set("use_native_dialog", true)
	add_child(_import_dialog)


static func _tab_button(text: String, tip: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _show_tab(show_online: bool) -> void:
	for control in _library_controls:
		control.visible = not show_online
	if not show_online:
		_apply_filter()  # restores the empty-label state
	_online_panel.visible = show_online
	if show_online:
		_online_panel.activate()


func _on_import_chosen(id: int) -> void:
	if id == 3:
		open_avatar_studio()
		return
	_import_as_character = id == 1
	_import_animation = id == 2
	_import_dialog.title = "Import rigged character (.glb)" if _import_as_character else "Import model (.glb)"
	if _import_animation:
		_import_dialog.title = "Import animation pack (.glb)"
	_import_dialog.popup_centered_ratio(0.6)


func _on_import_file(path: String) -> void:
	if _import_animation:
		_import_animation_pack(path)
		return
	var result := OnlineLibrary.import_file(path, _import_as_character)
	if not str(result["error"]).is_empty():
		EventBus.error(str(result["error"]))
		return
	refresh()
	_library_tab.button_pressed = true
	_show_tab(false)
	var warning := str(result.get("warning", ""))
	if warning.is_empty():
		EventBus.info("Imported %s into \"%s\"." % [path.get_file(),
			PropCatalog.MY_CHARACTERS_CATEGORY if _import_as_character else PropCatalog.IMPORTED_CATEGORY])
	else:
		EventBus.error(warning)


func refresh() -> void:
	if placement and placement.is_placing():
		placement.cancel_placement()
	for child in _list.get_children():
		child.queue_free()
	_cards.clear()
	_sections.clear()

	var props := PropCatalog.scan()
	_categories = PropCatalog.categories_of(props)
	_rebuild_category_filter()
	for category in _categories:
		_add_section(category)
	for prop in props:
		var card := AssetCard.new()
		card.setup(prop)
		card.prop_toggled.connect(_on_card_toggled)
		card.delete_requested.connect(_on_delete_requested)
		(_sections[prop["category"]]["grid"] as GridContainer).add_child(card)
		_cards.append(card)
		var thumb_file := str(prop.get("thumbnail", ""))
		var stored: Image = Image.load_from_file(thumb_file) if not thumb_file.is_empty() and FileAccess.file_exists(thumb_file) else null
		if stored:
			card.set_thumbnail(ImageTexture.create_from_image(stored))
		else:
			_thumbnails.request(prop["scene_path"], card.set_thumbnail)

	_update_columns()
	_apply_filter()
	if props.is_empty():
		EventBus.error("No assets found in %s" % PropCatalog.PROPS_DIR)
	else:
		EventBus.info("Asset library: %d objects in %d categories." % [props.size(), _categories.size()])


func _add_section(category: String) -> void:
	var header := Label.new()
	header.theme_type_variation = &"SectionHeader"
	header.uppercase = true
	_list.add_child(header)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_list.add_child(grid)
	_sections[category] = {"header": header, "grid": grid}


func _rebuild_category_filter() -> void:
	var previous := _selected_category()
	_category_filter.clear()
	_category_filter.add_item("All categories")
	for category in _categories:
		_category_filter.add_item(category)
	var index := _categories.find(previous)
	_category_filter.select(index + 1 if index >= 0 else 0)


func _selected_category() -> String:
	var index := _category_filter.selected
	return _category_filter.get_item_text(index) if index > 0 else ""


func _apply_filter() -> void:
	var query := _search.text.strip_edges().to_lower()
	var category := _selected_category()
	var counts: Dictionary = {}
	var total := 0
	for card in _cards:
		card.visible = card.matches(query, category)
		if card.visible:
			var c := str(card.prop["category"])
			counts[c] = int(counts.get(c, 0)) + 1
			total += 1
	for c in _sections:
		var section: Dictionary = _sections[c]
		var n := int(counts.get(c, 0))
		(section["header"] as Label).text = "%s  ·  %d" % [c, n]
		(section["header"] as Label).visible = n > 0
		(section["grid"] as GridContainer).visible = n > 0
	_empty_label.visible = total == 0
	if _cards.is_empty():
		_empty_label.text = "No assets found. Add .tscn or .glb files to assets/props/<category>/ and press Rescan."
	else:
		_empty_label.text = "No assets match your search."


func _update_columns() -> void:
	var width := _scroll.size.x - 12.0  # leave room for the scrollbar
	var columns := maxi(1, floori(width / MIN_CARD_WIDTH))
	for c in _sections:
		(_sections[c]["grid"] as GridContainer).columns = columns


func _on_card_toggled(card: AssetCard, prop: Dictionary, on: bool) -> void:
	if placement == null:
		return
	if on:
		if not placement.begin_placement(prop):
			card.set_pressed_no_signal(false)
	elif placement.is_placing() and placement.active_prop().get("scene_path") == prop.get("scene_path"):
		placement.cancel_placement()


func _on_placement_started(prop: Dictionary) -> void:
	for card in _cards:
		card.set_pressed_no_signal(card.prop.get("scene_path") == prop.get("scene_path"))


func _on_placement_ended() -> void:
	for card in _cards:
		card.set_pressed_no_signal(false)


## Animation packs become extra actions for every imported character with a
## matching rig (bones are matched by name).
func _import_animation_pack(path: String) -> void:
	if not ["glb", "fbx"].has(path.get_extension().to_lower()):
		EventBus.error("Animation packs must be .fbx (Mixamo) or .glb files.")
		return
	DirAccess.make_dir_recursive_absolute(ImportedCharacter.ANIMATIONS_DIR)
	var target := ImportedCharacter.ANIMATIONS_DIR + path.get_file().validate_filename()
	if DirAccess.copy_absolute(path, target) != OK:
		EventBus.error("Couldn't copy %s." % path.get_file())
		return
	ImportedCharacter.forget_packs()
	var clips := ImportedCharacter.animation_packs()
	EventBus.info("Animation pack added (%d actions available). Characters placed from now on (or after reopening the project) can use it." % clips.size())


func open_avatar_studio() -> void:
	if _avatar_studio == null:
		_avatar_studio = AvatarStudio.new()
		add_child(_avatar_studio)
		_avatar_studio.built.connect(func(_path: String) -> void: refresh())
	_avatar_studio.open()



## Deletes one of the user's own items (a character, an avatar, an import) after asking.
func _on_delete_requested(prop: Dictionary) -> void:
	var path := str(prop.get("scene_path", ""))
	if not path.begins_with("user://library/"):
		return
	var confirm := ConfirmationDialog.new()
	confirm.title = "Delete"
	confirm.dialog_text = "Delete \"%s\" from your library?\nScenes that use it will show it missing. This can't be undone." % str(prop.get("display_name", path.get_file()))
	confirm.confirmed.connect(func() -> void:
		for p in [path, ImportedCharacter.look_path(path), path.get_basename() + ".blend", path.get_basename() + ".json"]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
		RuntimeModelLoader.forget(path)
		EventBus.info("Deleted %s." % str(prop.get("display_name", path.get_file())))
		refresh()
		confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	add_child(confirm)
	confirm.popup_centered()

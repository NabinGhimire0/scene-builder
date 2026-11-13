class_name WorldToolsPanel
extends VBoxContainer
## Inspector "World" tab: terrain sculpting and painting, plant painting and
## character walking paths. Pick a tool, then click-drag in the viewport.

const SPEEDS := {"Walk": 1.4, "Stroll": 0.9, "Jog": 2.6, "Run": 3.8, "Sprint": 6.0}

var tools: WorldTools
var history: EditorHistory

var _buttons: Dictionary = {}   # tool -> Button
var _layer: OptionButton
var _plant: OptionButton
var _only_kind: CheckBox
var _speed: OptionButton
var _model_list: ItemList
var _model_paths: PackedStringArray = []
var _status: Label
var _group := ButtonGroup.new()


func setup(world_tools: WorldTools, editor_history: EditorHistory) -> void:
	tools = world_tools
	history = editor_history
	add_theme_constant_override("separation", 8)
	_group.allow_unpress = true

	add_child(_section("Brush"))
	add_child(_dim("Pick a tool, then click and drag on the ground. Right-drag still orbits the view. Esc stops the tool."))
	var size_row := SliderRow.new()
	size_row.setup("Brush size", 0.5, 40.0, 0.1, func(v: float) -> String: return "%.1f m" % v)
	size_row.set_value(tools.brush_size)
	size_row.value_edited.connect(func(v: float) -> void: tools.brush_size = v)
	add_child(size_row)
	var strength_row := SliderRow.new()
	strength_row.setup("Strength", 0.05, 1.0, 0.01, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	strength_row.set_value(tools.strength)
	strength_row.value_edited.connect(func(v: float) -> void: tools.strength = v)
	add_child(strength_row)

	add_child(_section("Shape the land"))
	var sculpt := _grid()
	_tool_button(sculpt, "Raise", "Raise", "Build hills and mountains")
	_tool_button(sculpt, "Lower", "Lower", "Dig valleys, riverbeds and lake basins")
	_tool_button(sculpt, "Smooth", "Smooth", "Soften bumps and sharp edges")
	_tool_button(sculpt, "Flatten", "Flatten", "Level the ground to the height where you start the stroke")

	add_child(_section("Paint the ground"))
	_layer = OptionButton.new()
	_layer.focus_mode = Control.FOCUS_NONE
	for item in Terrain.LAYERS:
		_layer.add_item(item)
	_layer.select(1)
	_layer.item_selected.connect(func(i: int) -> void: tools.paint_layer = i)
	add_child(_labelled("Layer", _layer))
	var paint := _grid()
	_tool_button(paint, "Paint", "Paint Layer", "Paint the chosen layer (\"Ground style\" erases paint). Steep slopes turn to rock by themselves.")

	add_child(_section("Plants & rocks"))
	_plant = OptionButton.new()
	_plant.focus_mode = Control.FOCUS_NONE
	_plant.item_selected.connect(_on_plant_selected)
	add_child(_labelled("Kind", _plant))
	_refresh_kinds()
	tools.vegetation.kinds_changed.connect(func() -> void: _refresh_kinds(tools.plant_kind))
	var add_model := Button.new()
	add_model.text = "Paint With a Model…"
	add_model.focus_mode = Control.FOCUS_NONE
	add_model.tooltip_text = "Use any downloaded, imported or built-in model (realistic plants, rocks, flowers from Poly Haven…) as a brush"
	add_model.pressed.connect(_open_model_list)
	add_child(add_model)
	_model_list = ItemList.new()
	_model_list.custom_minimum_size = Vector2(0, 180)
	_model_list.visible = false
	_model_list.item_activated.connect(_on_model_chosen)
	_model_list.item_clicked.connect(func(index: int, _pos: Vector2, _button: int) -> void: _on_model_chosen(index))
	add_child(_model_list)
	var plants := _grid()
	_tool_button(plants, "Plants", "Paint Plants", "Scatter the chosen plants; they sway in the wind (Scene tab → Weather)")
	_tool_button(plants, "Erase plants", "Erase", "Remove plants under the brush")
	_only_kind = CheckBox.new()
	_only_kind.text = "Erase only the chosen kind"
	_only_kind.focus_mode = Control.FOCUS_NONE
	_only_kind.toggled.connect(func(_on: bool) -> void: _sync_erase_kind())
	add_child(_only_kind)
	var clear_plants := Button.new()
	clear_plants.text = "Remove All Plants"
	clear_plants.focus_mode = Control.FOCUS_NONE
	clear_plants.pressed.connect(_on_clear_plants)
	add_child(clear_plants)

	add_child(_section("Character path"))
	add_child(_dim("Select a character, press Draw Path, click points on the ground, then Enter (or double-click). It walks or runs there from the playhead, following hills."))
	_speed = OptionButton.new()
	_speed.focus_mode = Control.FOCUS_NONE
	for key in SPEEDS:
		_speed.add_item("%s (%.1f m/s)" % [key, SPEEDS[key]])
	_speed.item_selected.connect(func(i: int) -> void: tools.path_speed = float(SPEEDS.values()[i]))
	add_child(_labelled("Speed", _speed))
	var path_grid := _grid()
	_tool_button(path_grid, "Path", "Draw Path", "Draw a walking path for the selected character or object")
	var finish := Button.new()
	finish.text = "Finish Path"
	finish.focus_mode = Control.FOCUS_NONE
	finish.pressed.connect(tools.finish_path)
	path_grid.add_child(finish)

	add_child(_section("Terrain"))
	var reset := Button.new()
	reset.text = "Flatten Whole Terrain"
	reset.focus_mode = Control.FOCUS_NONE
	reset.tooltip_text = "Reset all sculpting and painting (undoable)"
	reset.pressed.connect(_on_reset_terrain)
	add_child(reset)

	_status = _dim("")
	add_child(_status)
	tools.tool_changed.connect(_on_tool_changed)
	tools.path_changed.connect(func(n: int) -> void: _status.text = "Path: %d point%s. Enter to finish." % [n, "" if n == 1 else "s"])


func _tool_button(parent: Control, tool: String, text: String, tip: String) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.toggle_mode = true
	button.button_group = _group
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggled.connect(_on_tool_toggled.bind(tool))
	parent.add_child(button)
	_buttons[tool] = button


func _on_tool_toggled(on: bool, tool: String) -> void:
	if on:
		tools.set_tool(tool)
	elif tools.tool == tool:
		tools.set_tool("")


func _on_tool_changed(tool: String) -> void:
	for key in _buttons:
		(_buttons[key] as Button).set_pressed_no_signal(key == tool)
	_status.text = "" if tool.is_empty() else "Tool: %s — drag in the viewport. Esc to stop." % tool
	if tool == "Path":
		_status.text = "Click points on the ground. Enter or double-click to finish."


func _on_plant_selected(index: int) -> void:
	tools.plant_kind = str(_plant.get_item_metadata(index))
	_sync_erase_kind()


func _refresh_kinds(select: String = "") -> void:
	_plant.clear()
	var kinds: Array = Array(Vegetation.KINDS)
	kinds.append_array(Array(tools.vegetation.model_kinds()))
	for kind in kinds:
		_plant.add_item(tools.vegetation.title_of(kind))
		_plant.set_item_metadata(_plant.item_count - 1, kind)
		if kind == select:
			_plant.select(_plant.item_count - 1)
	_on_plant_selected(_plant.selected)


func _open_model_list() -> void:
	_model_list.clear()
	_model_paths.clear()
	for prop in PropCatalog.scan():
		if str(prop["category"]) in ["Characters", "My Characters"]:
			continue
		_model_list.add_item("%s  (%s)" % [prop["display_name"], prop["category"]])
		_model_paths.append(str(prop["scene_path"]))
	_model_list.visible = not _model_list.visible


func _on_model_chosen(index: int) -> void:
	var kind := tools.vegetation.add_model_kind(_model_paths[index])
	_model_list.visible = false
	if kind.is_empty():
		return
	_refresh_kinds(kind)
	EventBus.info("You can now paint with %s (no wind sway for models)." % tools.vegetation.title_of(kind))


func _sync_erase_kind() -> void:
	# Called while the panel is still being built (before the checkbox exists).
	tools.erase_kind = tools.plant_kind if _only_kind != null and _only_kind.button_pressed else ""


func _on_clear_plants() -> void:
	var before := tools.vegetation.snapshot()
	tools.vegetation.clear()
	history.record_snapshot("Remove all plants", tools.vegetation.restore, before, tools.vegetation.snapshot())


func _on_reset_terrain() -> void:
	var terrain := tools.terrain
	var before := terrain.snapshot()
	terrain.clear()
	terrain.end_stroke()
	history.record_snapshot("Flatten terrain", _restore_terrain, before, terrain.snapshot())


func _restore_terrain(state: Dictionary) -> void:
	tools.terrain.restore(state)
	tools.vegetation.resettle(Rect2(-Terrain.HALF, -Terrain.HALF, Terrain.SIZE, Terrain.SIZE))


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	return grid


static func _section(title: String) -> Label:
	var label := Label.new()
	label.text = title
	label.uppercase = true
	label.theme_type_variation = &"SectionHeader"
	return label


static func _dim(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"DimLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func _labelled(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := _dim(text)
	label.custom_minimum_size = Vector2(70, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

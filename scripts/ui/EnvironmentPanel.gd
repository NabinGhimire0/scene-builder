class_name EnvironmentPanel
extends VBoxContainer
## Inspector "Scene" tab: render quality, time of day & sun, sky (realistic,
## custom colours or photo HDRI with clouds), atmosphere, and ground.
## Every change is undoable; lighting values are auto-keyed on the timeline.

var environment: EnvironmentController
var history: EditorHistory
var timeline: TimelineController
var placement_grid_overlay: GeometryInstance3D
var picker: PolyHavenPicker

var _rows: Dictionary = {}           # property -> SliderRow
var _quality: OptionButton
var _quality_hint: Label
var _sky_mode: OptionButton
var _look: OptionButton
var _custom_box: VBoxContainer
var _photo_box: VBoxContainer
var _cloud_box: VBoxContainer
var _photo_label: Label
var _top_color: ColorPickerButton
var _horizon_color: ColorPickerButton
var _ground_style: OptionButton
var _ground_plain_box: Control
var _ground_photo_box: VBoxContainer
var _ground_label: Label
var _ground_color: ColorPickerButton
var _grid_toggle: CheckBox
var _keys_label: Label
var _picking := ""                   # "hdri" or "ground" while the picker is open
var _updating := false


func setup(env: EnvironmentController, edit_history: EditorHistory, timeline_controller: TimelineController, grid_overlay: GeometryInstance3D, poly_haven_picker: PolyHavenPicker) -> void:
	environment = env
	history = edit_history
	timeline = timeline_controller
	placement_grid_overlay = grid_overlay
	picker = poly_haven_picker
	add_theme_constant_override("separation", 8)
	_build()
	environment.changed.connect(_refresh)
	timeline.keys_changed.connect(_refresh_keys)
	timeline.time_changed.connect(func(_t: float) -> void: _refresh_keys())
	if picker:
		picker.chosen.connect(_on_picked)
		picker.visibility_changed.connect(_on_picker_visibility)
	_refresh()


func _build() -> void:
	add_child(_section("Render quality"))
	_quality = OptionButton.new()
	for item in RenderQuality.NAMES:
		_quality.add_item(item)
	_quality.focus_mode = Control.FOCUS_NONE
	_quality.item_selected.connect(_on_quality_selected)
	add_child(_quality)
	_quality_hint = _dim("")
	add_child(_quality_hint)

	add_child(_section("Style"))
	_look = OptionButton.new()
	for item in EnvironmentController.LOOKS:
		_look.add_item(item)
	_look.focus_mode = Control.FOCUS_NONE
	_look.tooltip_text = "Realistic 3D, or Flat sketch: a black void, flat colours and drawn outlines, like a 2D animation"
	_look.item_selected.connect(func(i: int) -> void:
		if not _updating:
			history.set_property(environment, "look", environment.look, EnvironmentController.LOOKS[i], "Style"))
	add_child(_look)

	add_child(_section("Quick looks"))
	var presets := GridContainer.new()
	presets.columns = 3
	presets.add_theme_constant_override("h_separation", 6)
	presets.add_theme_constant_override("v_separation", 6)
	add_child(presets)
	for preset_name in EnvironmentController.PRESETS:
		var button := Button.new()
		button.text = preset_name
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "Apply the %s lighting look" % preset_name
		button.pressed.connect(_apply_preset.bind(preset_name))
		presets.add_child(button)

	add_child(_section("Sun & time of day"))
	_add_slider(self, "time_of_day", "Time of day", 0.0, 24.0, 0.05,
		func(v: float) -> String: return EnvironmentController.format_time(v),
		"Moves the sun across the sky; below the horizon it becomes moonlight")
	_add_slider(self, "sun_azimuth", "Sun direction", 0.0, 360.0, 1.0,
		func(v: float) -> String: return "%d°" % roundi(v), "Compass direction the sun shines from at noon")
	_add_slider(self, "sun_intensity", "Light intensity", 0.0, 3.0, 0.01)
	_add_slider(self, "shadow_strength", "Shadow strength", 0.0, 1.0, 0.01, _percent)

	add_child(_section("Sky"))
	_sky_mode = OptionButton.new()
	for item in EnvironmentController.SKY_MODE_NAMES:
		_sky_mode.add_item(item)
	_sky_mode.focus_mode = Control.FOCUS_NONE
	_sky_mode.item_selected.connect(_on_sky_mode_selected)
	add_child(_sky_mode)

	_custom_box = VBoxContainer.new()
	add_child(_custom_box)
	var colors := HBoxContainer.new()
	colors.add_theme_constant_override("separation", 6)
	_custom_box.add_child(colors)
	_top_color = _color_button("Sky top colour")
	_top_color.color_changed.connect(_on_color_changed.bind("sky_top_color"))
	colors.add_child(_labelled("Top", _top_color))
	_horizon_color = _color_button("Sky horizon colour (also tints the fog)")
	_horizon_color.color_changed.connect(_on_color_changed.bind("sky_horizon_color"))
	colors.add_child(_labelled("Horizon", _horizon_color))

	_cloud_box = VBoxContainer.new()
	add_child(_cloud_box)
	_add_slider(_cloud_box, "cloud_cover", "Clouds", 0.0, 1.0, 0.01,
		func(v: float) -> String: return "clear" if v < 0.03 else ("overcast" if v > 0.9 else "%d%%" % roundi(v * 100.0)),
		"Cloud cover. Heavy clouds also soften the sunlight and shadows.")
	_add_slider(_cloud_box, "cloud_speed", "Cloud drift", 0.0, 5.0, 0.05,
		func(v: float) -> String: return "still" if v < 0.01 else "%.1f×" % v)

	_photo_box = VBoxContainer.new()
	_photo_box.add_theme_constant_override("separation", 6)
	add_child(_photo_box)
	var pick_sky := Button.new()
	pick_sky.text = "Choose Photo Sky…"
	pick_sky.focus_mode = Control.FOCUS_NONE
	pick_sky.tooltip_text = "Browse real HDRI skies from Poly Haven. They also light the scene realistically."
	pick_sky.pressed.connect(_open_picker.bind("hdri"))
	_photo_box.add_child(pick_sky)
	_photo_label = _dim("")
	_photo_box.add_child(_photo_label)
	_add_slider(_photo_box, "hdri_rotation", "Sky rotation", 0.0, 360.0, 1.0,
		func(v: float) -> String: return "%d°" % roundi(v), "Turn the photo sky (tip: line its sun up with Sun direction)")
	_add_slider(_photo_box, "hdri_energy", "Sky brightness", 0.0, 3.0, 0.01)

	add_child(_section("Atmosphere"))
	_add_slider(self, "fog_density", "Fog / haze", 0.0, 0.08, 0.0005,
		func(v: float) -> String: return "off" if v <= 0.0001 else "%.1f" % (v * 1000.0),
		"At High/Cinematic quality the fog is volumetric, with light shafts from the sun")
	_add_slider(self, "ambient_energy", "Ambient light", 0.0, 2.0, 0.01)
	_add_slider(self, "exposure", "Exposure", 0.3, 2.5, 0.01)

	add_child(_section("Film look"))
	_add_slider(self, "bloom", "Glow (bloom)", 0.0, 1.0, 0.01,
		func(v: float) -> String: return "off" if v <= 0.001 else "%d%%" % roundi(v * 100.0),
		"A soft glow around bright lights, sparks and the sky - the 'movie trailer' look")
	_add_slider(self, "contrast", "Contrast", 0.5, 2.0, 0.01)
	_add_slider(self, "saturation", "Colour strength", 0.0, 2.0, 0.01)

	add_child(_section("Weather"))
	var weather_grid := GridContainer.new()
	weather_grid.columns = 3
	weather_grid.add_theme_constant_override("h_separation", 4)
	weather_grid.add_theme_constant_override("v_separation", 4)
	add_child(weather_grid)
	for preset_name in EnvironmentController.WEATHER_PRESETS:
		var weather_button := Button.new()
		weather_button.text = preset_name
		weather_button.focus_mode = Control.FOCUS_NONE
		weather_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weather_button.pressed.connect(_set_many.bind(EnvironmentController.WEATHER_PRESETS[preset_name], "Weather: %s" % preset_name))
		weather_grid.add_child(weather_button)
	_add_slider(self, "wind", "Wind", 0.0, 1.0, 0.01, _percent, "Sways grass and trees, drifts rain, snow and leaves")
	_add_slider(self, "wind_direction", "Wind direction", 0.0, 360.0, 1.0,
		func(v: float) -> String: return "%d°" % roundi(v))
	_add_slider(self, "rain", "Rain", 0.0, 1.0, 0.01, _percent, "Falling rain; the ground gets wet and shiny")
	_add_slider(self, "snow", "Snowfall", 0.0, 1.0, 0.01, _percent)
	_add_slider(self, "snow_cover", "Snow on the ground", 0.0, 1.0, 0.01, _percent, "Snow settles on flat ground, plants and rocks")
	_add_slider(self, "mist", "Mist", 0.0, 1.0, 0.01, _percent, "Low-lying mist (volumetric at High/Cinematic quality)")
	_add_slider(self, "leaves", "Falling leaves", 0.0, 1.0, 0.01, _percent)
	_add_slider(self, "autumn", "Autumn colours", 0.0, 1.0, 0.01, _percent, "Trees turn gold and red, grass dries (pines stay green)")
	add_child(_dim("All weather can be animated: set it, then Key Lighting at Playhead."))

	add_child(_section("Ground"))
	_ground_style = OptionButton.new()
	for item in EnvironmentController.GROUND_STYLES:
		_ground_style.add_item(item)
	_ground_style.focus_mode = Control.FOCUS_NONE
	_ground_style.item_selected.connect(_on_ground_style_selected)
	add_child(_ground_style)
	_ground_color = _color_button("Ground colour")
	_ground_color.color_changed.connect(_on_color_changed.bind("ground_color"))
	_ground_plain_box = _labelled("Ground colour", _ground_color)
	add_child(_ground_plain_box)
	_ground_photo_box = VBoxContainer.new()
	_ground_photo_box.add_theme_constant_override("separation", 6)
	add_child(_ground_photo_box)
	var pick_ground := Button.new()
	pick_ground.text = "Choose Ground Texture…"
	pick_ground.focus_mode = Control.FOCUS_NONE
	pick_ground.tooltip_text = "Real photo-scanned materials from Poly Haven (grass, mud, cobblestone, rock…)"
	pick_ground.pressed.connect(_open_picker.bind("ground"))
	_ground_photo_box.add_child(pick_ground)
	_ground_label = _dim("")
	_ground_photo_box.add_child(_ground_label)
	_add_slider(_ground_photo_box, "ground_tile", "Texture size", 0.5, 20.0, 0.1,
		func(v: float) -> String: return "%.1f m" % v, "How many metres one repeat of the texture covers")
	_grid_toggle = CheckBox.new()
	_grid_toggle.text = "Show grid in editor view"
	_grid_toggle.button_pressed = true
	_grid_toggle.focus_mode = Control.FOCUS_NONE
	_grid_toggle.tooltip_text = "The grid never appears in Camera View or exported video"
	_grid_toggle.toggled.connect(_on_grid_toggled)
	add_child(_grid_toggle)

	add_child(_section("Animation"))
	var key_button := Button.new()
	key_button.text = "Key Lighting at Playhead"
	key_button.focus_mode = Control.FOCUS_NONE
	key_button.tooltip_text = "Record all lighting values at the current time (animate sunsets, clouds, fog…)"
	key_button.pressed.connect(func() -> void: timeline.add_keyframe(environment))
	add_child(key_button)
	_keys_label = _dim("")
	add_child(_keys_label)


func _add_slider(parent: Control, property: String, title: String, min_value: float, max_value: float, step: float, formatter: Callable = Callable(), tooltip: String = "") -> void:
	var row := SliderRow.new()
	row.setup(title, min_value, max_value, step, formatter, tooltip)
	row.value_edited.connect(_on_slider_edited.bind(property))
	parent.add_child(row)
	_rows[property] = row


static func _percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


static func _section(title: String) -> Label:
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"SectionHeader"
	label.uppercase = true
	return label


static func _dim(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"DimLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func _color_button(tip: String) -> ColorPickerButton:
	var button := ColorPickerButton.new()
	button.custom_minimum_size = Vector2(56, 26)
	button.edit_alpha = false
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	return button


static func _labelled(text: String, control: Control) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"DimLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(label)
	box.add_child(control)
	return box


# --- Edits ----------------------------------------------------------------------

func _channel_for(property: String) -> String:
	return TimelineController.CH_LIGHTING if property in EnvironmentController.ANIMATED else ""


func _on_slider_edited(value: float, property: String) -> void:
	if _updating:
		return
	history.set_property(environment, property, environment.get(property), value, "Lighting", _channel_for(property))


func _on_color_changed(color: Color, property: String) -> void:
	if _updating:
		return
	history.set_property(environment, property, environment.get(property), color, "Lighting", _channel_for(property))


func _on_quality_selected(index: int) -> void:
	if _updating:
		return
	history.set_property(environment, "render_quality", environment.render_quality, index, "Render quality")
	EventBus.info("Render quality: %s." % RenderQuality.NAMES[index])


func _on_grid_toggled(on: bool) -> void:
	if placement_grid_overlay:
		placement_grid_overlay.visible = on


func _on_sky_mode_selected(index: int) -> void:
	if _updating:
		return
	if index == EnvironmentController.SkyMode.PHOTO and environment.hdri_path.is_empty():
		_refresh()  # keep the old mode until a photo sky is chosen
		_open_picker("hdri")
		return
	var to := {"sky_mode": index}
	if index == EnvironmentController.SkyMode.CUSTOM:
		# Start custom colours from what the sky shows right now.
		var colors := environment.current_sky_colors()
		to["sky_top_color"] = colors[0]
		to["sky_horizon_color"] = colors[1]
	_set_many(to, "Sky")


func _on_ground_style_selected(index: int) -> void:
	if _updating:
		return
	var style := EnvironmentController.GROUND_STYLES[index]
	if style == "Photo texture" and environment.ground_texture.is_empty():
		_refresh()
		_open_picker("ground")
		return
	_set_many({"ground_style": style}, "Ground")


func _open_picker(target: String) -> void:
	if picker == null:
		EventBus.error("The online library isn't available.")
		return
	_picking = target
	picker.open_for("hdris" if target == "hdri" else "textures")


func _on_picker_visibility() -> void:
	if picker and not picker.visible:
		_picking = ""


func _on_picked(path: String, id: String, title: String) -> void:
	match _picking:
		"hdri":
			_set_many({"sky_mode": EnvironmentController.SkyMode.PHOTO, "hdri_path": path, "hdri_id": id}, "Photo sky")
			EventBus.info("Photo sky: %s. Use Sky rotation to line it up." % title)
		"ground":
			_set_many({"ground_style": "Photo texture", "ground_texture": path, "ground_texture_id": id}, "Ground texture")
			EventBus.info("Ground texture: %s." % title)
	_picking = ""


func _set_many(to: Dictionary, label: String) -> void:
	var from := {}
	for key in to:
		from[key] = environment.get(key)
	history.set_properties(environment, from, to, label)


func _apply_preset(preset_name: String) -> void:
	var to: Dictionary = EnvironmentController.PRESETS[preset_name].duplicate()
	var from := {}
	for key in to:
		from[key] = environment.get(key)
	history.set_properties(environment, from, to, "Lighting preset: %s" % preset_name, TimelineController.CH_LIGHTING)
	EventBus.info("Lighting preset: %s." % preset_name)


# --- Refresh --------------------------------------------------------------------

func _refresh() -> void:
	_updating = true
	for property in _rows:
		(_rows[property] as SliderRow).set_value(float(environment.get(property)))
	_quality.select(environment.render_quality)
	_look.select(maxi(EnvironmentController.LOOKS.find(environment.look), 0))
	_quality_hint.text = RenderQuality.HINTS[environment.render_quality] + " Exports use the quality chosen in Export Video."
	var mode := environment.sky_mode
	_sky_mode.select(mode)
	_custom_box.visible = mode == EnvironmentController.SkyMode.CUSTOM
	_cloud_box.visible = mode != EnvironmentController.SkyMode.PHOTO
	_photo_box.visible = mode == EnvironmentController.SkyMode.PHOTO
	_photo_label.text = "Current: %s" % _asset_title(environment.hdri_path, environment.hdri_id)
	_top_color.color = environment.sky_top_color
	_horizon_color.color = environment.sky_horizon_color
	var style_index := EnvironmentController.GROUND_STYLES.find(environment.ground_style)
	_ground_style.select(maxi(style_index, 0))
	_ground_plain_box.visible = environment.ground_style == "Plain colour"
	_ground_photo_box.visible = environment.ground_style == "Photo texture"
	_ground_label.text = "Current: %s" % _asset_title(environment.ground_texture, environment.ground_texture_id)
	_ground_color.color = environment.ground_color
	_updating = false
	_refresh_keys()


static func _asset_title(path: String, id: String) -> String:
	if path.is_empty():
		return "none chosen"
	return id.replace("_", " ").capitalize() if not id.is_empty() else path.get_file().get_basename()


func _refresh_keys() -> void:
	var times := timeline.store.key_times(TimelineController.ENV_UID)
	if times.is_empty():
		_keys_label.text = "Lighting isn't animated. Press the button above (or turn on Auto-Key) to animate it over time."
	else:
		_keys_label.text = "Lighting has %d keyframe%s on the timeline." % [times.size(), "" if times.size() == 1 else "s"]

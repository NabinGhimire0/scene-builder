class_name FilmPanel
extends VBoxContainer
## Inspector "Film" tab: titles/subtitles and sound clips on the timeline.
## Every change is undoable.

var titles: TitleTrack
var audio: AudioTrack
var timeline: TimelineController
var history: EditorHistory

var _title_list: VBoxContainer
var _audio_list: VBoxContainer
var _file_dialog: FileDialog
var _editing := false
var _record_button: Button
var _record_meter: ProgressBar
var _record_label: Label
var _play_buttons: Array[Button] = []


func setup(title_track: TitleTrack, audio_track: AudioTrack, timeline_controller: TimelineController, editor_history: EditorHistory) -> void:
	titles = title_track
	audio = audio_track
	timeline = timeline_controller
	history = editor_history
	add_theme_constant_override("separation", 8)

	add_child(_section("Titles & subtitles"))
	add_child(_dim("Text shown in the film from its start time, fading in and out. Use a new line for two-line subtitles."))
	_title_list = VBoxContainer.new()
	_title_list.add_theme_constant_override("separation", 10)
	add_child(_title_list)
	var add_title := Button.new()
	add_title.text = "Add Text at Playhead"
	add_title.focus_mode = Control.FOCUS_NONE
	add_title.pressed.connect(_on_add_title)
	add_child(add_title)

	add_child(_section("Music & sound"))
	add_child(_dim("Add .ogg, .mp3 or .wav files. They play with the timeline and are mixed into MP4 exports."))
	_audio_list = VBoxContainer.new()
	_audio_list.add_theme_constant_override("separation", 10)
	add_child(_audio_list)
	var add_sound := Button.new()
	add_sound.text = "Add Sound at Playhead…"
	add_sound.focus_mode = Control.FOCUS_NONE
	add_sound.pressed.connect(_on_add_sound)
	add_child(add_sound)
	_record_button = Button.new()
	_record_button.text = "● Record Voice at Playhead"
	_record_button.focus_mode = Control.FOCUS_NONE
	_record_button.tooltip_text = "Record dialogue from your microphone; press again to stop. It is added as a clip where you started."
	_record_button.pressed.connect(_on_record)
	add_child(_record_button)
	_record_label = _dim("")
	_record_label.visible = false
	add_child(_record_label)
	_record_meter = ProgressBar.new()
	_record_meter.max_value = 1.0
	_record_meter.show_percentage = false
	_record_meter.custom_minimum_size = Vector2(0, 10)
	_record_meter.tooltip_text = "Microphone level: it should jump when you speak"
	_record_meter.visible = false
	add_child(_record_meter)
	add_child(_dim("Each clip has a Voice changer (deeper, child, robot, phone, echo…). Use Lip sync on a character to make its mouth follow a voice clip."))

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.ogg, *.mp3, *.wav ; Sound files"])
	_file_dialog.title = "Choose a sound or music file"
	_file_dialog.file_selected.connect(_on_sound_chosen)
	add_child(_file_dialog)

	titles.changed.connect(_rebuild_titles)
	audio.changed.connect(_rebuild_audio)
	audio.recording_changed.connect(_on_recording_changed)
	audio.preview_changed.connect(_on_preview_changed)
	_rebuild_titles()
	_rebuild_audio()


# --- Titles --------------------------------------------------------------------

func _on_add_title() -> void:
	var after := titles.to_list()
	after.append({"text": "Your text here", "start": snappedf(timeline.current_time, 0.01), "length": 3.0, "style": "Subtitle"})
	_commit_titles(after, "Add text")


func _commit_titles(after: Array, label: String, merge: bool = false) -> void:
	history.record_snapshot(label, titles.load_list, titles.to_list(), after, merge)


func _edit_title(index: int, key: String, value: Variant, merge: bool = true) -> void:
	var after := titles.to_list()
	if index >= after.size() or after[index][key] == value:
		return
	after[index][key] = value
	_editing = true
	_commit_titles(after, "Edit text %d %s" % [index + 1, key], merge)
	_editing = false


func _rebuild_titles() -> void:
	if _editing:
		return
	for child in _title_list.get_children():
		child.queue_free()
	for i in titles.items.size():
		var item: Dictionary = titles.items[i]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		var text := TextEdit.new()
		text.text = str(item["text"])
		text.custom_minimum_size = Vector2(0, 54)
		text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		text.focus_exited.connect(func() -> void: _edit_title(i, "text", text.text, false))
		box.add_child(text)
		var row := HBoxContainer.new()
		var style := OptionButton.new()
		style.focus_mode = Control.FOCUS_NONE
		for s in TitleTrack.STYLES:
			style.add_item(s)
		style.select(maxi(TitleTrack.STYLES.find(str(item["style"])), 0))
		style.item_selected.connect(func(k: int) -> void: _edit_title(i, "style", TitleTrack.STYLES[k], false))
		style.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(style)
		var remove := Button.new()
		remove.text = "Delete"
		remove.focus_mode = Control.FOCUS_NONE
		remove.pressed.connect(_remove_title.bind(i))
		row.add_child(remove)
		box.add_child(row)
		box.add_child(_number_row("Start", float(item["start"]), 0.0, 600.0, " s", func(v: float) -> void: _edit_title(i, "start", v)))
		box.add_child(_number_row("Length", float(item["length"]), 0.2, 120.0, " s", func(v: float) -> void: _edit_title(i, "length", v)))
		_title_list.add_child(box)
		_title_list.add_child(HSeparator.new())


func _remove_title(index: int) -> void:
	var after := titles.to_list()
	after.remove_at(index)
	_commit_titles(after, "Delete text")


# --- Audio ---------------------------------------------------------------------

func _on_add_sound() -> void:
	_file_dialog.popup_centered_ratio(0.6)


func _on_sound_chosen(path: String) -> void:
	var clip := audio.import_file(path, timeline.current_time)
	if clip.is_empty():
		return
	var after := audio.to_list()
	after.append(clip)
	history.record_snapshot("Add sound %s" % clip["name"], audio.load_list, audio.to_list(), after)
	EventBus.info("Added %s (%.1f s) at %.2f s." % [clip["name"], audio.clip_length(clip), clip["start"]])


func _on_record() -> void:
	if audio.is_recording():
		audio.finish_recording(history)
	else:
		audio.record_start = timeline.current_time
		audio.record_for = ""
		audio.record_target = null
		if audio.start_recording():
			EventBus.info("Recording… speak now, then press Stop Recording.")


func _on_recording_changed(active: bool) -> void:
	_record_button.text = "■ Stop Recording" if active else "● Record Voice at Playhead"
	_record_meter.visible = active
	_record_label.visible = active
	set_process(active)


func _process(_delta: float) -> void:
	if not audio.is_recording():
		set_process(false)
		return
	_record_meter.value = lerpf(_record_meter.value, audio.input_level(), 0.5)
	var who := (" for %s" % audio.record_for) if not audio.record_for.is_empty() else ""
	_record_label.text = "Recording%s… %.1f s (the bar should move when you speak)" % [who, audio.recording_seconds()]


func _toggle_preview(index: int) -> void:
	if audio.previewing() == index:
		audio.stop_preview()
	else:
		audio.preview(index)


func _on_preview_changed(index: int) -> void:
	for i in _play_buttons.size():
		if is_instance_valid(_play_buttons[i]):
			_play_buttons[i].text = "■" if i == index else "▶"
			_play_buttons[i].tooltip_text = "Stop" if i == index else "Listen to this clip on its own (with its voice effect)"


func _edit_clip(index: int, key: String, value: Variant) -> void:
	var after := audio.to_list()
	if index >= after.size() or after[index].get(key) == value:
		return
	after[index][key] = value
	_editing = true
	history.record_snapshot("Edit sound %d %s" % [index + 1, key], audio.load_list, audio.to_list(), after, true)
	_editing = false


func _remove_clip(index: int) -> void:
	var after := audio.to_list()
	after.remove_at(index)
	history.record_snapshot("Delete sound", audio.load_list, audio.to_list(), after)


func _rebuild_audio() -> void:
	if _editing:
		return
	for child in _audio_list.get_children():
		child.queue_free()
	_play_buttons.clear()
	for i in audio.clips.size():
		var clip: Dictionary = audio.clips[i]
		var box := VBoxContainer.new()
		var row := HBoxContainer.new()
		var play := Button.new()
		play.text = "■" if audio.previewing() == i else "▶"
		play.focus_mode = Control.FOCUS_NONE
		play.custom_minimum_size = Vector2(32, 0)
		play.tooltip_text = "Listen to this clip on its own (with its voice effect)"
		play.pressed.connect(_toggle_preview.bind(i))
		row.add_child(play)
		_play_buttons.append(play)
		var name_label := _dim("%s · %.1f s" % [clip["name"], audio.clip_length(clip)])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var remove := Button.new()
		remove.text = "Delete"
		remove.focus_mode = Control.FOCUS_NONE
		remove.pressed.connect(_remove_clip.bind(i))
		row.add_child(remove)
		box.add_child(row)
		box.add_child(_number_row("Start", float(clip["start"]), 0.0, 600.0, " s", func(v: float) -> void: _edit_clip(i, "start", v)))
		var voice := OptionButton.new()
		voice.focus_mode = Control.FOCUS_NONE
		var voices: Array = AudioTrack.VOICES.keys()
		for v in voices:
			voice.add_item(str(v))
		voice.select(maxi(voices.find(str(clip.get("voice", "Normal"))), 0))
		voice.item_selected.connect(func(k: int) -> void: _edit_clip(i, "voice", str(voices[k])))
		var voice_row := HBoxContainer.new()
		var voice_label := _dim("Voice")
		voice_label.custom_minimum_size = Vector2(60, 0)
		voice_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		voice_row.add_child(voice_label)
		voice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		voice_row.add_child(voice)
		box.add_child(voice_row)
		var volume := SliderRow.new()
		volume.setup("Volume", -40.0, 12.0, 0.5, func(v: float) -> String: return "%+.1f dB" % v)
		volume.set_value(float(clip["volume_db"]))
		volume.value_edited.connect(func(v: float) -> void: _edit_clip(i, "volume_db", v))
		box.add_child(volume)
		_audio_list.add_child(box)
		_audio_list.add_child(HSeparator.new())


# --- Helpers -------------------------------------------------------------------

func _number_row(title: String, value: float, min_value: float, max_value: float, suffix: String, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := _dim(title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 0.01
	spin.suffix = suffix.strip_edges()
	spin.value = value
	spin.custom_minimum_size = Vector2(110, 0)
	spin.value_changed.connect(on_change)
	row.add_child(spin)
	return row


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

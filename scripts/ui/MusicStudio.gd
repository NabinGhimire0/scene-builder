class_name MusicStudio
extends PanelContainer
## The Music & Voice tab.
##  • My sounds: every music file and recording in the library (import more).
##  • Record: your microphone, with a level meter and a 3-2-1 count-in.
##  • Edit: see the waveform, trim the start and end, fade in / out, volume.
##  • Voice changer: turn a recording into a man, woman, girl, boy, old person,
##    giant, monster, chipmunk, robot, alien, whisper, radio, cave… or set the
##    pitch and voice size yourself. Saved as a new sound.
##  • Add to film: puts the sound on the film's audio track at the playhead.

var film_audio: AudioTrack
var timeline: TimelineController
var history: EditorHistory

const MUSIC_EXT: PackedStringArray = ["ogg", "mp3", "wav"]

var _active := false
var _list: ItemList
var _filter: OptionButton
var _paths: PackedStringArray = []
var _current := ""
var _samples := PackedFloat32Array()   # mono, VoiceChanger.RATE (for the waveform and edits)
var _wave: WaveView
var _title: Label
var _info: Label
var _play_btn: Button
var _player: AudioStreamPlayer
var _gain: SliderRow
var _fade_in: SliderRow
var _fade_out: SliderRow
var _rec_btn: Button
var _rec_time: Label
var _meter: ProgressBar
var _countdown: CheckBox
var _count_left := 0.0
var _voice_label: Label
var _pitch: SliderRow
var _size: SliderRow
var _echo: SliderRow
var _progress: ProgressBar
var _busy := false
var _thread: Thread
var _result := PackedFloat32Array()
var _result_preset := ""
var _preset := ""
var _median := 0.0
var _preset_buttons: Dictionary = {}
var _start_spin: SpinBox


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_player = AudioStreamPlayer.new()
	add_child(_player)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_build_library())
	root.add_child(_build_centre())
	root.add_child(_build_voice())
	refresh()


func set_active(on: bool) -> void:
	_active = on
	if on:
		refresh()
	else:
		_player.stop()
		if film_audio and film_audio.is_recording():
			_stop_recording()


# ------------------------------------------------------------------ layout

func _build_library() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(270, 0)
	var m := _margin(10)
	panel.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	m.add_child(box)
	box.add_child(_heading("My sounds"))
	_filter = OptionButton.new()
	for f in ["All sounds", "Music", "My recordings", "Changed voices", "Edited sounds"]:
		_filter.add_item(f)
	_filter.item_selected.connect(func(_i: int) -> void: refresh())
	box.add_child(_filter)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i: int) -> void: _open(_paths[i]))
	box.add_child(_list)
	var row := HBoxContainer.new()
	var imp := Button.new()
	imp.text = "Import music…"
	imp.tooltip_text = "Add .mp3, .ogg or .wav files (music, sound effects, voices)."
	imp.pressed.connect(_on_import)
	imp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(imp)
	var del := Button.new()
	del.text = "Delete"
	del.pressed.connect(_on_delete)
	row.add_child(del)
	box.add_child(row)
	box.add_child(_wrap("Free music: YouTube Audio Library, Pixabay Music, Free Music Archive. Check each track's licence."))
	return panel


func _build_centre() -> Control:
	var m := _margin(12)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	m.add_child(box)
	# --- recorder
	var rec := _card(box, "Record your voice")
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 10)
	_rec_btn = Button.new()
	_rec_btn.text = "●  Record"
	_rec_btn.custom_minimum_size = Vector2(130, 40)
	_rec_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.42))
	_rec_btn.pressed.connect(_on_record)
	rrow.add_child(_rec_btn)
	var mcol := VBoxContainer.new()
	mcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rec_time = _dim("Press Record and speak. Press Stop when you finish.")
	mcol.add_child(_rec_time)
	_meter = ProgressBar.new()
	_meter.show_percentage = false
	_meter.max_value = 1.0
	_meter.custom_minimum_size = Vector2(0, 12)
	mcol.add_child(_meter)
	rrow.add_child(mcol)
	_countdown = CheckBox.new()
	_countdown.text = "3-2-1 count-in"
	_countdown.button_pressed = true
	rrow.add_child(_countdown)
	rec.add_child(rrow)
	var drow := HBoxContainer.new()
	drow.add_child(_dim("Microphone"))
	var mic := OptionButton.new()
	mic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var devices := AudioServer.get_input_device_list()
	for d in devices:
		mic.add_item(d)
		if d == AudioServer.input_device:
			mic.select(mic.item_count - 1)
	mic.item_selected.connect(func(i: int) -> void: AudioServer.input_device = mic.get_item_text(i))
	mic.tooltip_text = "Which microphone to record from."
	drow.add_child(mic)
	rec.add_child(drow)
	# --- the selected sound
	var ed := _card(box, "")
	_title = _heading("Pick a sound on the left")
	ed.add_child(_title)
	_info = _dim("")
	ed.add_child(_info)
	_wave = WaveView.new()
	_wave.custom_minimum_size = Vector2(0, 170)
	_wave.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wave.seek_requested.connect(_seek)
	_wave.trim_changed.connect(func() -> void: _update_info())
	ed.add_child(_wave)
	var trow := HBoxContainer.new()
	_play_btn = Button.new()
	_play_btn.text = "▶  Play"
	_play_btn.custom_minimum_size = Vector2(100, 0)
	_play_btn.pressed.connect(_on_play)
	trow.add_child(_play_btn)
	var stop := Button.new()
	stop.text = "■  Stop"
	stop.pressed.connect(func() -> void:
		_player.stop()
		_play_btn.text = "▶  Play")
	trow.add_child(stop)
	var hint := _dim("Drag the white handles to trim · click the wave to jump")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trow.add_child(hint)
	ed.add_child(trow)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	_gain = SliderRow.new()
	_gain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_gain)
	_gain.setup("Volume", -18.0, 12.0, 0.5, func(v: float) -> String: return "%+.1f dB" % v)
	_gain.set_value(0.0)
	_fade_in = SliderRow.new()
	_fade_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_fade_in)
	_fade_in.setup("Fade in", 0.0, 10.0, 0.1, func(v: float) -> String: return "%.1f s" % v)
	_fade_out = SliderRow.new()
	_fade_out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_fade_out)
	_fade_out.setup("Fade out", 0.0, 10.0, 0.1, func(v: float) -> String: return "%.1f s" % v)
	for r in [_gain, _fade_in, _fade_out]:
		(r as SliderRow).value_edited.connect(func(_v: float) -> void: _wave.set_fades(_fade_in.get_value(), _fade_out.get_value(), _gain.get_value()))
	ed.add_child(grid)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 8)
	var save_edit := Button.new()
	save_edit.text = "Save edit as new sound"
	save_edit.tooltip_text = "Keeps the original; saves the trimmed / faded / louder version next to it."
	save_edit.pressed.connect(_on_save_edit)
	arow.add_child(save_edit)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arow.add_child(spacer)
	arow.add_child(_dim("Start at"))
	_start_spin = SpinBox.new()
	_start_spin.min_value = 0.0
	_start_spin.max_value = 36000.0
	_start_spin.step = 0.1
	_start_spin.suffix = "s"
	_start_spin.custom_minimum_size = Vector2(110, 0)
	_start_spin.tooltip_text = "Where the sound starts in the film (the timeline's playhead when you open this tab)."
	arow.add_child(_start_spin)
	var add := Button.new()
	add.text = "Add to film"
	add.custom_minimum_size = Vector2(130, 0)
	add.tooltip_text = "Put this sound on the film's audio track (Film tab in the scene)."
	add.pressed.connect(_on_add_to_film)
	arow.add_child(add)
	ed.add_child(arow)
	return m


func _build_voice() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	var m := _margin(10)
	panel.add_child(m)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	box.add_child(_heading("Change the voice"))
	_voice_label = _wrap("Pick a recording (or any voice), then a new voice. The original is kept.")
	box.add_child(_voice_label)
	var flow := GridContainer.new()
	flow.columns = 2
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for preset in VoiceChanger.PRESETS:
		var b := Button.new()
		b.text = preset
		b.toggle_mode = true
		b.tooltip_text = str(VoiceChanger.PRESETS[preset].get("about", ""))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_choose_preset.bind(preset))
		flow.add_child(b)
		_preset_buttons[preset] = b
	box.add_child(flow)
	box.add_child(HSeparator.new())
	box.add_child(_dim("Fine-tune (or make your own)"))
	_pitch = SliderRow.new()
	box.add_child(_pitch)
	_pitch.setup("Pitch", -12.0, 12.0, 0.5, func(v: float) -> String: return "%+.1f semitones" % v)
	_size = SliderRow.new()
	box.add_child(_size)
	_size.setup("Voice size (small ↔ big)", -5.0, 5.0, 0.1, func(v: float) -> String: return "%+.1f" % v)
	_echo = SliderRow.new()
	box.add_child(_echo)
	_echo.setup("Echo", 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % int(v * 100))
	for r in [_pitch, _size, _echo]:
		(r as SliderRow).value_edited.connect(func(_v: float) -> void: _mark_custom())
	var row := HBoxContainer.new()
	var preview := Button.new()
	preview.text = "▶  Listen"
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.pressed.connect(_on_preview_voice)
	row.add_child(preview)
	var save := Button.new()
	save.text = "Save new voice"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(_on_save_voice)
	row.add_child(save)
	box.add_child(row)
	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.visible = false
	box.add_child(_progress)
	box.add_child(_wrap("Tip: record each character's lines separately, change each to its voice, then add them to the film where the character speaks. Lip sync uses the changed voice too."))
	return panel


# ------------------------------------------------------------------ library

func refresh() -> void:
	if _list == null:
		return
	_list.clear()
	_paths.clear()
	var dir := DirAccess.open(AudioTrack.AUDIO_DIR)
	if dir == null:
		_update_info()
		return
	var files := Array(dir.get_files())
	files.sort_custom(func(a: String, b: String) -> bool: return FileAccess.get_modified_time(AudioTrack.AUDIO_DIR + a) > FileAccess.get_modified_time(AudioTrack.AUDIO_DIR + b))
	for f in files:
		if not MUSIC_EXT.has(str(f).get_extension().to_lower()):
			continue
		var kind := _kind_of(f)
		var want := _filter.selected
		if want == 1 and kind != "music" or want == 2 and kind != "recording" or want == 3 and kind != "voice" or want == 4 and kind != "edit":
			continue
		var icon: String = {"music": "♪", "recording": "●", "voice": "◆", "edit": "✂"}.get(kind, "♪")
		_list.add_item("%s  %s" % [icon, str(f).get_basename().replace("_", " ")])
		_paths.append(AudioTrack.AUDIO_DIR + f)
		if AudioTrack.AUDIO_DIR + f == _current:
			_list.select(_list.item_count - 1)


static func _kind_of(file: String) -> String:
	var f := file.to_lower()
	if f.begins_with("voice_"):
		return "recording"
	if f.contains("(") and f.contains(" voice)"):
		return "voice"
	if f.contains("(edit"):
		return "edit"
	return "music"


func _on_import() -> void:
	var d := FileDialog.new()
	d.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.filters = PackedStringArray(["*.mp3, *.ogg, *.wav ; Music and sounds"])
	d.title = "Import music or sounds"
	d.files_selected.connect(func(paths: PackedStringArray) -> void:
		d.queue_free()
		DirAccess.make_dir_recursive_absolute(AudioTrack.AUDIO_DIR)
		var last := ""
		for p in paths:
			var target := AudioTrack.AUDIO_DIR + p.get_file().validate_filename()
			if DirAccess.copy_absolute(p, target) == OK:
				last = target
		refresh()
		if not last.is_empty():
			_open(last)
			EventBus.info("Imported %d sound(s)." % paths.size()))
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered_ratio(0.7)


func _on_delete() -> void:
	if _current.is_empty():
		return
	var used := false
	if film_audio:
		for c in film_audio.clips:
			if str(c.get("path", "")) == _current:
				used = true
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "Delete \"%s\"?%s" % [_current.get_file(), "\nIt is used in the film: those clips will be removed when you next open the scene." if used else ""]
	confirm.confirmed.connect(func() -> void:
		_player.stop()
		DirAccess.remove_absolute(_current)
		_current = ""
		_samples = PackedFloat32Array()
		_wave.set_samples(_samples, 0)
		_title.text = "Pick a sound on the left"
		refresh()
		confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	add_child(confirm)
	confirm.popup_centered()


func _open(path: String) -> void:
	_player.stop()
	_play_btn.text = "▶  Play"
	_current = path
	_title.text = path.get_file().get_basename().replace("_", " ")
	_result = PackedFloat32Array()
	var ffmpeg := str(film_audio.exporter.settings["ffmpeg_path"]) if film_audio and film_audio.exporter else "ffmpeg"
	var data := VoiceChanger.read(path, ffmpeg)
	_samples = data.get("samples", PackedFloat32Array())
	_wave.set_samples(_samples, VoiceChanger.RATE)
	_gain.set_value(0.0)
	_fade_in.set_value(0.0)
	_fade_out.set_value(0.0)
	_wave.set_fades(0.0, 0.0, 0.0)
	_median = 0.0
	_voice_label.text = "Pick a new voice for \"%s\". The original is kept." % _title.text
	if not _samples.is_empty() and _samples.size() < VoiceChanger.RATE * 120:
		var info := VoiceChanger.analyse(_samples)
		_median = float(info["median"])
		if _median > 0.0:
			_voice_label.text = "This voice: about %d Hz (sounds like %s). Pick a new voice:" % [int(_median), "a man" if _median < 165.0 else ("a woman" if _median < 255.0 else "a child")]
	_update_info()


func _update_info() -> void:
	if _current.is_empty():
		_info.text = ""
		return
	var stream := film_audio.load_stream(_current) if film_audio else null
	var length := stream.get_length() if stream else float(_samples.size()) / VoiceChanger.RATE
	var tr := _wave.trim()
	_info.text = "%s · %s%s" % [_time(length), _current.get_extension().to_upper(),
		("  ·  keeping %s – %s" % [_time(tr.x * length), _time(tr.y * length)]) if (tr.x > 0.0 or tr.y < 1.0) else ""]
	if _samples.is_empty():
		_info.text += "  ·  (waveform and editing need FFmpeg for .%s — set it in Export Video, or use .wav)" % _current.get_extension()


static func _time(s: float) -> String:
	return "%d:%04.1f" % [int(s) / 60, fmod(s, 60.0)]


# ------------------------------------------------------------------ playback

func _on_play() -> void:
	if _current.is_empty():
		return
	if _player.playing:
		_player.stream_paused = not _player.stream_paused
		_play_btn.text = "▶  Play" if _player.stream_paused else "❚❚  Pause"
		return
	var stream := film_audio.load_stream(_current) if film_audio else null
	if stream == null:
		return
	_player.stream = stream
	_player.volume_db = _gain.get_value()
	var tr := _wave.trim()
	_player.play(tr.x * stream.get_length())
	_play_btn.text = "❚❚  Pause"


func _seek(fraction: float) -> void:
	if _player.stream == null or _current.is_empty():
		return
	_player.play(fraction * _player.stream.get_length())
	_play_btn.text = "❚❚  Pause"


func _play_samples(x: PackedFloat32Array) -> void:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = VoiceChanger.RATE
	var data := PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		data.encode_s16(i * 2, int(clampf(x[i], -1.0, 1.0) * 32767.0))
	wav.data = data
	_player.stream = wav
	_player.volume_db = 0.0
	_player.play()
	_play_btn.text = "❚❚  Pause"


func _process(delta: float) -> void:
	if not _active:
		return
	if _player.playing and _player.stream:
		var len := _player.stream.get_length()
		_wave.set_playhead(_player.get_playback_position() / maxf(len, 0.01) if _player.stream != null else -1.0)
		var tr := _wave.trim()
		if tr.y < 1.0 and _player.get_playback_position() / maxf(len, 0.01) > tr.y and _result.is_empty():
			_player.stop()
			_play_btn.text = "▶  Play"
	elif not _player.playing:
		_wave.set_playhead(-1.0)
		if _play_btn.text != "▶  Play" and not _player.stream_paused:
			_play_btn.text = "▶  Play"
	if _count_left > 0.0:
		_count_left -= delta
		_rec_time.text = "Get ready… %d" % int(ceil(_count_left))
		if _count_left <= 0.0:
			_begin_recording()
	if film_audio and film_audio.is_recording():
		_meter.value = film_audio.input_level()
		_rec_time.text = "Recording… %s   (press Stop when you finish)" % _time(film_audio.recording_seconds())
		_heard = maxf(_heard, _meter.value)
		if film_audio.recording_seconds() > 2.5 and _heard < 0.02:
			_rec_time.text = "No sound is coming from the microphone. Check the Microphone list above, and Windows Settings → Privacy & security → Microphone → let desktop apps use it."
	else:
		_meter.value = lerpf(_meter.value, 0.0, 0.2)
	if _busy and _thread and not _thread.is_alive():
		_thread.wait_to_finish()
		_thread = null
		_busy = false
		_progress.visible = false
		_voice_done()


# ------------------------------------------------------------------ recording

func _on_record() -> void:
	if film_audio == null:
		return
	if film_audio.is_recording() or _count_left > 0.0:
		_count_left = 0.0
		_stop_recording()
		return
	_player.stop()
	_rec_btn.text = "■  Stop"
	if _countdown.button_pressed:
		_count_left = 3.0
	else:
		_begin_recording()


var _heard := 0.0

func _begin_recording() -> void:
	_heard = 0.0
	if not film_audio.start_recording():
		_rec_btn.text = "●  Record"
		EventBus.error("Couldn't start the microphone.")


func _stop_recording() -> void:
	_rec_btn.text = "●  Record"
	_rec_time.text = "Press Record and speak. Press Stop when you finish."
	if not film_audio.is_recording():
		return
	var path := film_audio.stop_recording()
	if path.is_empty():
		return
	refresh()
	_open(path)
	EventBus.info("Recorded %s. Listen, change the voice or add it to the film." % _time(float(_samples.size()) / VoiceChanger.RATE))


# ------------------------------------------------------------------ voice changer

func _choose_preset(preset: String) -> void:
	_preset = preset
	for k in _preset_buttons:
		(_preset_buttons[k] as Button).button_pressed = k == preset
	var p := VoiceChanger.settings_for(preset, _median)
	_pitch.set_value(clampf(12.0 * log(float(p.get("pitch", 1.0))) / log(2.0), -12.0, 12.0))
	_size.set_value(clampf((float(p.get("formant", 1.0)) - 1.0) * 10.0, -5.0, 5.0))
	_echo.set_value(float(p.get("reverb", 0.0)))
	_result = PackedFloat32Array()
	_on_preview_voice()


func _mark_custom() -> void:
	_result = PackedFloat32Array()


func _voice_settings() -> Dictionary:
	var s := VoiceChanger.settings_for(_preset, _median) if not _preset.is_empty() else {}
	s["pitch"] = pow(2.0, _pitch.get_value() / 12.0)
	s["formant"] = 1.0 + _size.get_value() / 10.0
	s["reverb"] = _echo.get_value()
	s.erase("semitones")
	return s


func _on_preview_voice() -> void:
	if _samples.is_empty():
		EventBus.info("Pick or record a voice first.")
		return
	if not _result.is_empty():
		_play_samples(_result)
		return
	_run_changer(true)


func _on_save_voice() -> void:
	if _samples.is_empty():
		EventBus.info("Pick or record a voice first.")
		return
	if _result.is_empty():
		_run_changer(false)
		return
	_save_result()


var _play_when_done := true

func _run_changer(play: bool) -> void:
	if _busy:
		return
	_busy = true
	_play_when_done = play
	_progress.visible = true
	_progress.value = 0.05
	var x := _trimmed(_samples)
	var settings := _voice_settings()
	_thread = Thread.new()
	_thread.start(func() -> void:
		var y := VoiceChanger.process(x, VoiceChanger.RATE, settings, func(v: float) -> void: _progress.set_deferred("value", v))
		_result = y)


func _voice_done() -> void:
	if _result.is_empty():
		return
	if _play_when_done:
		_play_samples(_result)
	else:
		_save_result()


func _save_result() -> void:
	var name := "%s (%s voice).wav" % [_current.get_file().get_basename(), _preset if not _preset.is_empty() else "custom"]
	var path := AudioTrack.AUDIO_DIR + name.validate_filename()
	if VoiceChanger.write(path, _result) != OK:
		EventBus.error("Couldn't save the new voice.")
		return
	if film_audio:
		film_audio._streams.erase(path)
	EventBus.info("Saved \"%s\". Add it to the film from the middle panel." % name.get_basename())
	refresh()
	_open(path)


# ------------------------------------------------------------------ edits

func _trimmed(x: PackedFloat32Array) -> PackedFloat32Array:
	var tr := _wave.trim()
	var a := int(tr.x * x.size())
	var b := int(tr.y * x.size())
	return x.slice(a, maxi(b, a + 1))


func _on_save_edit() -> void:
	if _samples.is_empty():
		EventBus.info("This sound can't be edited (needs FFmpeg for .%s)." % _current.get_extension())
		return
	var y := _trimmed(_samples)
	var g := db_to_linear(_gain.get_value())
	var fi := int(_fade_in.get_value() * VoiceChanger.RATE)
	var fo := int(_fade_out.get_value() * VoiceChanger.RATE)
	for i in y.size():
		var v := y[i] * g
		if fi > 0 and i < fi:
			v *= float(i) / fi
		if fo > 0 and i > y.size() - fo:
			v *= float(y.size() - i) / fo
		y[i] = clampf(v, -1.0, 1.0)
	var path := AudioTrack.AUDIO_DIR + ("%s (edit).wav" % _current.get_file().get_basename()).validate_filename()
	if VoiceChanger.write(path, y) == OK:
		EventBus.info("Saved the edited sound.")
		refresh()
		_open(path)


func _on_add_to_film() -> void:
	if _current.is_empty() or film_audio == null:
		return
	var clip := film_audio.import_file(_current, _start_spin.value)
	if clip.is_empty():
		return
	clip["volume_db"] = _gain.get_value()
	var before := film_audio.to_list()
	var after := before.duplicate(true)
	after.append(clip)
	if history:
		history.record_snapshot("Add sound", film_audio.load_list, before, after)
	else:
		film_audio.load_list(after)
	EventBus.info("Added \"%s\" to the film at %.1f s. See it in the Scene tab → Film → Music and sound." % [clip["name"], _start_spin.value])


func show_playhead(t: float) -> void:
	if _start_spin:
		_start_spin.value = t


# ------------------------------------------------------------------ helpers

func _card(parent: Control, title: String) -> VBoxContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	var m := _margin(10)
	p.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	m.add_child(box)
	if not title.is_empty():
		box.add_child(_heading(title))
	if parent is VBoxContainer and title.is_empty():
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return box


func _margin(px: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	return m


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	return l


func _dim(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"DimLabel"
	return l


func _wrap(text: String) -> Label:
	var l := _dim(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 0)
	return l


## A waveform with trim handles, fades and a playhead.
class WaveView:
	extends Control
	signal seek_requested(fraction: float)
	signal trim_changed

	var peaks := PackedFloat32Array()
	var length := 0.0
	var trim_a := 0.0
	var trim_b := 1.0
	var playhead := -1.0
	var fade_in := 0.0
	var fade_out := 0.0
	var gain_db := 0.0
	var _drag := -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_samples(x: PackedFloat32Array, rate: int) -> void:
		peaks = PackedFloat32Array()
		length = float(x.size()) / maxf(rate, 1)
		var cols := 1200
		if not x.is_empty():
			var per := maxi(1, x.size() / cols)
			for c in range(0, x.size(), per):
				var m := 0.0
				for i in range(c, mini(c + per, x.size()), maxi(1, per / 64)):
					m = maxf(m, absf(x[i]))
				peaks.append(m)
		trim_a = 0.0
		trim_b = 1.0
		queue_redraw()

	func set_fades(fi: float, fo: float, g: float) -> void:
		fade_in = fi
		fade_out = fo
		gain_db = g
		queue_redraw()

	func set_playhead(f: float) -> void:
		if absf(f - playhead) > 0.0005:
			playhead = f
			queue_redraw()

	func trim() -> Vector2:
		return Vector2(trim_a, trim_b)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.1, 0.11, 0.13))
		var mid := size.y * 0.5
		if peaks.is_empty():
			draw_string(get_theme_default_font(), Vector2(12, mid), "No waveform", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.6, 0.65))
			return
		var g := db_to_linear(gain_db)
		var n := peaks.size()
		for i in n:
			var x := size.x * i / n
			var f := float(i) / n
			var t := f * length
			var env := 1.0
			var kept_len := (trim_b - trim_a) * length
			var local := t - trim_a * length
			if fade_in > 0.0 and local < fade_in:
				env *= clampf(local / fade_in, 0.0, 1.0)
			if fade_out > 0.0 and local > kept_len - fade_out:
				env *= clampf((kept_len - local) / fade_out, 0.0, 1.0)
			var h := clampf(peaks[i] * g * env, 0.0, 1.0) * mid * 0.95
			var inside := f >= trim_a and f <= trim_b
			var col := Color(0.35, 0.72, 0.95) if inside else Color(0.3, 0.33, 0.38)
			draw_line(Vector2(x, mid - h), Vector2(x, mid + h), col, maxf(size.x / n, 1.0))
		for f in [trim_a, trim_b]:
			var x: float = size.x * float(f)
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color.WHITE, 2.0)
			draw_rect(Rect2(x - 5, 0, 10, 14), Color.WHITE)
		if playhead >= 0.0:
			var x := size.x * playhead
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1.0, 0.8, 0.3), 2.0)

	func _gui_input(event: InputEvent) -> void:
		if peaks.is_empty():
			return
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := event as InputEventMouseButton
			var f := clampf(mb.position.x / maxf(size.x, 1.0), 0.0, 1.0)
			if mb.pressed:
				if absf(f - trim_a) * size.x < 10.0:
					_drag = 0
				elif absf(f - trim_b) * size.x < 10.0:
					_drag = 1
				else:
					_drag = -1
					seek_requested.emit(f)
			else:
				if _drag >= 0:
					trim_changed.emit()
				_drag = -1
		elif event is InputEventMouseMotion and _drag >= 0:
			var f := clampf((event as InputEventMouseMotion).position.x / maxf(size.x, 1.0), 0.0, 1.0)
			if _drag == 0:
				trim_a = minf(f, trim_b - 0.01)
			else:
				trim_b = maxf(f, trim_a + 0.01)
			queue_redraw()

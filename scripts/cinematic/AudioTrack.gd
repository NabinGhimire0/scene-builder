class_name AudioTrack
extends Node
## Music and sound effects on the timeline. Each clip starts at a time with a
## volume; clips play in sync while the timeline plays and are mixed into the
## exported MP4 (needs FFmpeg).

signal changed
## Recording started or stopped (both the Film tab and the character Lip sync
## section show it).
signal recording_changed(active: bool)
## A clip preview started (its index) or stopped (-1).
signal preview_changed(index: int)
## A recording was added as clip [param index] (see [member record_target]).
signal recorded(index: int)

const AUDIO_DIR := "user://library/audio/"
const EXTENSIONS: PackedStringArray = ["ogg", "mp3", "wav"]
## Voice changer presets: pitch factor, phone/radio band, echo amount, robot.
const VOICES := {
	"Normal": {},
	"Deeper": {"pitch": 0.82},
	"Very deep / giant": {"pitch": 0.66, "echo": 0.15},
	"Monster": {"pitch": 0.6, "echo": 0.3, "robot": true},
	"Higher": {"pitch": 1.2},
	"Child / cartoon": {"pitch": 1.42},
	"Chipmunk": {"pitch": 1.8},
	"Robot": {"robot": true},
	"Phone / radio": {"phone": true},
	"Old radio": {"phone": true, "pitch": 0.97, "echo": 0.08},
	"Big hall echo": {"echo": 0.45},
	"Ghost": {"pitch": 0.9, "echo": 0.55},
}

@export var timeline: TimelineController
## For its FFmpeg path (lip sync decodes .mp3/.ogg with FFmpeg).
@export var exporter: ExportManager

## Each: { "path", "name", "start", "volume_db" }.
var clips: Array = []

var _players: Array = []   # AudioStreamPlayer per clip (same order)
var _streams: Dictionary = {}   # path -> AudioStream
var _bus_voices: Dictionary = {}   # clip index -> voice preset on its bus


func _ready() -> void:
	timeline.playing_changed.connect(_on_playing_changed)
	timeline.time_changed.connect(_on_time_changed)
	_preview_player = AudioStreamPlayer.new()
	_preview_player.finished.connect(stop_preview)
	add_child(_preview_player)


# --- Preview (hear one clip on its own) -------------------------------------------

var _preview_player: AudioStreamPlayer
var _preview_index := -1


## Plays clip [param index] on its own, with its volume and voice effect.
func preview(index: int) -> void:
	stop_preview()
	if index < 0 or index >= clips.size():
		return
	if timeline.is_playing():
		timeline.pause()
	var clip: Dictionary = clips[index]
	var stream := load_stream(str(clip["path"]))
	if stream == null:
		EventBus.error("Couldn't read %s." % clip["name"])
		return
	_preview_player.stream = stream
	_preview_player.volume_db = float(clip["volume_db"])
	_preview_player.bus = _voice_bus(index, str(clip.get("voice", "Normal")))
	_preview_player.play()
	_preview_index = index
	preview_changed.emit(index)


func stop_preview() -> void:
	if _preview_player and _preview_player.playing:
		_preview_player.stop()
	if _preview_index != -1:
		_preview_index = -1
		preview_changed.emit(-1)


func previewing() -> int:
	return _preview_index


## The clip that is playing (or starts next) at time [param t], for picking a
## sensible default clip. -1 if there are none.
func clip_near(t: float) -> int:
	var best := -1
	var best_distance := INF
	for i in clips.size():
		var start := float(clips[i]["start"])
		var end := start + clip_length(clips[i])
		var distance := 0.0 if (t >= start and t <= end) else minf(absf(t - start), absf(t - end))
		if distance < best_distance:
			best = i
			best_distance = distance
	return best


func _process(_delta: float) -> void:
	if not timeline.is_playing():
		return
	var t := timeline.current_time
	for i in clips.size():
		var clip: Dictionary = clips[i]
		var player: AudioStreamPlayer = _player(i)
		if player == null:
			continue
		var offset := t - float(clip["start"])
		var length := player.stream.get_length() if player.stream else 0.0
		if offset >= 0.0 and offset < length and not player.playing:
			player.play(offset)


## Copies a sound file into the library and adds it at [param start]. Returns
## the new clip or {} with an error shown.
func import_file(source: String, start: float) -> Dictionary:
	if not EXTENSIONS.has(source.get_extension().to_lower()):
		EventBus.error("Use an .ogg, .mp3 or .wav file.")
		return {}
	DirAccess.make_dir_recursive_absolute(AUDIO_DIR)
	var target := AUDIO_DIR + source.get_file().validate_filename()
	if source != target and DirAccess.copy_absolute(source, target) != OK:
		EventBus.error("Couldn't copy %s." % source.get_file())
		return {}
	if load_stream(target) == null:
		EventBus.error("Couldn't read %s (unsupported format?)." % source.get_file())
		return {}
	return {"path": target, "name": source.get_file().get_basename(), "start": maxf(start, 0.0), "volume_db": 0.0}


func clip_length(clip: Dictionary) -> float:
	var stream := load_stream(str(clip["path"]))
	return stream.get_length() if stream else 0.0


func load_stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	if not FileAccess.file_exists(path):
		return null
	var stream: AudioStream = null
	match path.get_extension().to_lower():
		"ogg":
			stream = AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			var mp3 := AudioStreamMP3.new()
			mp3.data = FileAccess.get_file_as_bytes(path)
			stream = mp3
		"wav":
			stream = _load_wav(path)
	if stream:
		_streams[path] = stream
	return stream


func stop_all() -> void:
	for player in _players:
		if player:
			(player as AudioStreamPlayer).stop()


func to_list() -> Array:
	return clips.duplicate(true)


func load_list(value: Variant) -> void:
	stop_all()
	stop_preview()
	for player in _players:
		if player:
			(player as AudioStreamPlayer).queue_free()
	_players.clear()
	clips.clear()
	if value is Array:
		for entry in value:
			if entry is Dictionary and FileAccess.file_exists(str(entry.get("path", ""))):
				clips.append({
					"path": str(entry["path"]),
					"name": str(entry.get("name", str(entry["path"]).get_file())),
					"start": maxf(float(entry.get("start", 0.0)), 0.0),
					"volume_db": clampf(float(entry.get("volume_db", 0.0)), -40.0, 12.0),
					"voice": str(entry.get("voice", "Normal")),
				})
	changed.emit()


func clear() -> void:
	load_list([])


func _player(i: int) -> AudioStreamPlayer:
	while _players.size() <= i:
		_players.append(null)
	var clip: Dictionary = clips[i]
	var player: AudioStreamPlayer = _players[i]
	if player == null:
		player = AudioStreamPlayer.new()
		add_child(player)
		_players[i] = player
	player.stream = load_stream(str(clip["path"]))
	player.volume_db = float(clip["volume_db"])
	player.bus = _voice_bus(i, str(clip.get("voice", "Normal")))
	return player if player.stream else null


## One audio bus per clip carrying its voice effect (preview only; exports use
## the matching FFmpeg filters, see [method voice_filter]).
func _voice_bus(i: int, voice: String) -> StringName:
	if voice == "Normal" or not VOICES.has(voice):
		return &"Master"
	var bus_name := "SBVoice%d" % i
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")
	if _bus_voices.get(i, "") != voice:
		_bus_voices[i] = voice
		while AudioServer.get_bus_effect_count(index) > 0:
			AudioServer.remove_bus_effect(index, 0)
		var v: Dictionary = VOICES[voice]
		if v.has("pitch"):
			var shift := AudioEffectPitchShift.new()
			shift.pitch_scale = float(v["pitch"])
			AudioServer.add_bus_effect(index, shift)
		if v.get("phone", false):
			var high := AudioEffectHighPassFilter.new()
			high.cutoff_hz = 320.0
			AudioServer.add_bus_effect(index, high)
			var low := AudioEffectLowPassFilter.new()
			low.cutoff_hz = 3200.0
			AudioServer.add_bus_effect(index, low)
		if v.get("robot", false):
			var chorus := AudioEffectChorus.new()
			chorus.wet = 0.7
			AudioServer.add_bus_effect(index, chorus)
			var crush := AudioEffectDistortion.new()
			crush.mode = AudioEffectDistortion.MODE_LOFI
			crush.drive = 0.3
			AudioServer.add_bus_effect(index, crush)
		if float(v.get("echo", 0.0)) > 0.0:
			var delay := AudioEffectDelay.new()
			delay.tap1_delay_ms = 180.0
			delay.tap1_level_db = linear_to_db(float(v["echo"]))
			delay.tap2_delay_ms = 360.0
			delay.tap2_level_db = linear_to_db(float(v["echo"]) * 0.5)
			delay.feedback_active = true
			delay.feedback_level_db = linear_to_db(float(v["echo"]) * 0.4)
			AudioServer.add_bus_effect(index, delay)
	return StringName(bus_name)


## FFmpeg audio filters for a clip's voice (used when mixing the MP4).
static func voice_filter(voice: String) -> String:
	var v: Dictionary = VOICES.get(voice, {})
	var parts := PackedStringArray()
	if v.has("pitch"):
		var p := float(v["pitch"])
		parts.append("aresample=48000,asetrate=%d,aresample=48000,atempo=%s" % [roundi(48000.0 * p), String.num(1.0 / p, 4)])
	if v.get("phone", false):
		parts.append("highpass=f=320,lowpass=f=3200")
	if v.get("robot", false):
		parts.append("afftfilt=real='hypot(re,im)*sin(0)':imag='hypot(re,im)*cos(0)':win_size=512:overlap=0.75")
	if float(v.get("echo", 0.0)) > 0.0:
		var e := float(v["echo"])
		parts.append("aecho=0.8:%s:180|360:%s|%s" % [String.num(0.9, 2), String.num(e, 2), String.num(e * 0.5, 2)])
	return ",".join(parts)


# --- Recording (dialogue from the microphone) ---------------------------------

var _record_player: AudioStreamPlayer
var _record_effect: AudioEffectRecord
var _record_meter: AudioEffectSpectrumAnalyzer
var _record_bus := -1
var _record_started_ms := 0
## Where the recording goes on the timeline, and who it's for ("" = nobody).
var record_start := 0.0
var record_for := ""
## The character a recording is for (its mouth is synced to it), or null.
var record_target: Node = null


func is_recording() -> bool:
	return _record_effect != null and _record_effect.is_recording_active()


## Starts recording from the default microphone.
func start_recording() -> bool:
	stop_preview()
	var index := AudioServer.get_bus_index(&"SBRecord")
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, &"SBRecord")
		# Don't play the microphone back (no echo / feedback). The bus must NOT be
		# muted: a muted bus skips its effects, so the recorder only got silence.
		# Its volume (applied after the effects) is turned right down instead.
		AudioServer.set_bus_volume_db(index, -80.0)
		_record_meter = AudioEffectSpectrumAnalyzer.new()
		AudioServer.add_bus_effect(index, _record_meter)
		_record_effect = AudioEffectRecord.new()
		AudioServer.add_bus_effect(index, _record_effect)
	AudioServer.set_bus_mute(index, false)
	_record_bus = index
	if _record_player == null:
		_record_player = AudioStreamPlayer.new()
		_record_player.stream = AudioStreamMicrophone.new()
		_record_player.bus = &"SBRecord"
		add_child(_record_player)
	_record_player.play()
	_record_effect.set_recording_active(true)
	_record_started_ms = Time.get_ticks_msec()
	recording_changed.emit(true)
	return true


## Seconds recorded so far.
func recording_seconds() -> float:
	return (Time.get_ticks_msec() - _record_started_ms) / 1000.0 if is_recording() else 0.0


## Microphone loudness right now, 0 (silence) … 1 (loud), for a level meter.
func input_level() -> float:
	if not is_recording() or _record_bus < 0:
		return 0.0
	var analyser := AudioServer.get_bus_effect_instance(_record_bus, 0) as AudioEffectSpectrumAnalyzerInstance
	if analyser == null:
		return 0.0
	var magnitude := analyser.get_magnitude_for_frequency_range(80.0, 8000.0)
	var db := linear_to_db(maxf(maxf(magnitude.x, magnitude.y), 0.000001))
	return clampf((db + 60.0) / 50.0, 0.0, 1.0)


## Stops recording and saves a .wav in the library; returns its path or "".
func stop_recording() -> String:
	if not is_recording():
		return ""
	_record_effect.set_recording_active(false)
	_record_player.stop()
	recording_changed.emit(false)
	var recording := _record_effect.get_recording()
	if recording == null or recording.data.is_empty():
		EventBus.error("Nothing was recorded. Check the microphone (and its permission for this app).")
		return ""
	if _peak(recording) < 0.01:
		EventBus.error("The recording is silent. Check that a microphone is plugged in, chosen as the default input, and that apps may use it (Windows: Settings → Privacy & security → Microphone).")
	DirAccess.make_dir_recursive_absolute(AUDIO_DIR)
	var path := AUDIO_DIR + "voice_%s.wav" % Time.get_datetime_string_from_system().replace(":", "-")
	if recording.save_to_wav(path) != OK:
		EventBus.error("Couldn't save the recording.")
		return ""
	return path


## Loudest sample of a recording (0..1), to warn about silent takes.
static func _peak(wav: AudioStreamWAV) -> float:
	var data := wav.data
	var peak := 0
	if wav.format == AudioStreamWAV.FORMAT_16_BITS:
		for i in range(0, data.size() - 1, 2 * 16):  # every 16th sample is plenty
			peak = maxi(peak, absi(data.decode_s16(i)))
		return peak / 32768.0
	if wav.format == AudioStreamWAV.FORMAT_8_BITS:
		for i in range(0, data.size(), 16):
			peak = maxi(peak, absi(data.decode_s8(i)))
		return peak / 128.0
	return 1.0


## Stops recording and adds the take as a clip at [member record_start]
## (undoable through [param history]). Returns the new clip's index or -1.
func finish_recording(history: EditorHistory) -> int:
	var path := stop_recording()
	if path.is_empty():
		return -1
	var clip := import_file(path, record_start)
	if clip.is_empty():
		return -1
	var who := record_for
	clip["name"] = ("%s line %s" % [who, Time.get_time_string_from_system()]) if not who.is_empty() else "Voice %s" % Time.get_time_string_from_system()
	var after := to_list()
	after.append(clip)
	history.record_snapshot("Record voice", load_list, to_list(), after)
	EventBus.info("Recorded %.1f s at %.2f s. Press ▶ to listen." % [clip_length(clip), record_start])
	recorded.emit(clips.size() - 1)
	return clips.size() - 1


func _on_playing_changed(playing: bool) -> void:
	if playing:
		stop_preview()
	if not playing:
		stop_all()


func _on_time_changed(_t: float) -> void:
	if not timeline.is_playing():
		stop_all()


## Mouth openness (0..1) at 30 frames per second for lip sync, from the
## loudness of [param clip]. .wav is read directly; .mp3/.ogg are decoded with
## FFmpeg. Returns an empty array (with an error shown) if it can't be read.
func mouth_envelope(clip: Dictionary) -> PackedFloat32Array:
	var path := str(clip["path"])
	var wav_path := path
	if path.get_extension().to_lower() != "wav":
		var ffmpeg := str(exporter.settings["ffmpeg_path"]) if exporter else "ffmpeg"
		DirAccess.make_dir_recursive_absolute("user://tools/")
		wav_path = "user://tools/lipsync.wav"
		var output: Array = []
		var code := OS.execute(ffmpeg, PackedStringArray(["-y", "-loglevel", "error", "-i", ProjectSettings.globalize_path(path),
			"-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", ProjectSettings.globalize_path(wav_path)]), output, true)
		if code != 0:
			EventBus.error("Lip sync needs FFmpeg to read .%s files (set it in Export Video), or use a .wav file." % path.get_extension())
			return PackedFloat32Array()
	var wav := _load_wav(wav_path)
	if wav == null or wav.format != AudioStreamWAV.FORMAT_16_BITS:
		EventBus.error("Couldn't read the sound for lip sync (use 16-bit .wav, .mp3 or .ogg).")
		return PackedFloat32Array()
	var data := wav.data
	var channels := 2 if wav.stereo else 1
	var frame_samples := maxi(1, int(wav.mix_rate / 30.0))
	var total := data.size() / (2 * channels)
	var levels := PackedFloat32Array()
	var peak := 0.0001
	for start in range(0, total, frame_samples):
		var sum := 0.0
		var n := 0
		for s in range(start, mini(start + frame_samples, total)):
			var value := data.decode_s16(s * 2 * channels) / 32768.0
			sum += value * value
			n += 1
		var rms := sqrt(sum / maxf(float(n), 1.0))
		levels.append(rms)
		peak = maxf(peak, rms)
	# Loudness → mouth: gate quiet noise, compress, then smooth (fast open, slower close).
	var env := PackedFloat32Array()
	env.resize(levels.size())
	var current := 0.0
	for i in levels.size():
		var db := 20.0 * log(maxf(levels[i] / peak, 0.00001)) / log(10.0)
		var target := clampf((db + 32.0) / 28.0, 0.0, 1.0)
		current = lerpf(current, target, 0.7 if target > current else 0.35)
		env[i] = current
	return env


## Minimal PCM .wav reader (8/16-bit), for Godot versions without
## AudioStreamWAV.load_from_file.
static func _load_wav(path: String) -> AudioStreamWAV:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var pos := 12
	var channels := 1
	var rate := 44100
	var bits := 16
	while pos + 8 <= bytes.size():
		var id := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size := bytes.decode_u32(pos + 4)
		if id == "fmt ":
			if bytes.decode_u16(pos + 8) != 1:
				return null  # compressed .wav
			channels = bytes.decode_u16(pos + 10)
			rate = bytes.decode_u32(pos + 12)
			bits = bytes.decode_u16(pos + 22)
		elif id == "data":
			var wav := AudioStreamWAV.new()
			wav.mix_rate = rate
			wav.stereo = channels == 2
			wav.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
			var data := bytes.slice(pos + 8, pos + 8 + size)
			if bits == 8:
				for i in data.size():
					data[i] = (data[i] + 128) % 256  # unsigned → signed
			wav.data = data
			return wav
		pos += 8 + size + (size % 2)
	return null

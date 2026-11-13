class_name SpeechMaker
extends RefCounted
## Automatic voices: turns a line of dialogue into a .wav file using the speech
## voices already on the computer, with no downloads:
##   • Windows: the built-in voices (Microsoft David, Zira…) via PowerShell
##   • macOS:   the "say" command (Samantha, Daniel…)
##   • Linux:   espeak-ng (or espeak)
##   • Piper:   higher quality neural voices, anywhere, if you set it up in
##              user://settings.cfg  [voices] piper_path="…" piper_model="….onnx"
## Results are cached, so building a film again is instant.

const CACHE_DIR := "user://library/audio/voices/"
const SETTINGS_FILE := "user://settings.cfg"

## Voice description from a CAST setting ("voice female", "voice child", "voice deep",
## "voice elder", "voice Microsoft Zira") or from the character's body type.
static func voice_for(setting: String, body: String) -> Dictionary:
	var v := {"gender": "male", "age": "adult", "pitch": 0, "rate": 0, "name": ""}
	match body.to_lower():
		"woman":
			v["gender"] = "female"
		"child":
			v["gender"] = "female"
			v["age"] = "child"
		"elder":
			v["age"] = "senior"
	var words := setting.to_lower().split(" ", false)
	var named: PackedStringArray = []
	for word in words:
		match word:
			"male", "man", "boy":
				v["gender"] = "male"
			"female", "woman", "girl":
				v["gender"] = "female"
			"child", "kid", "young":
				v["age"] = "child" if word != "young" else "young"
			"elder", "old", "senior":
				v["age"] = "senior"
			"deep", "low":
				v["pitch"] = int(v["pitch"]) - 20
			"high", "bright":
				v["pitch"] = int(v["pitch"]) + 20
			"slow":
				v["rate"] = int(v["rate"]) - 20
			"fast", "quick":
				v["rate"] = int(v["rate"]) + 20
			_:
				named.append(word)
	if not named.is_empty():
		v["name"] = " ".join(named)
	match str(v["age"]):
		"child":
			v["pitch"] = int(v["pitch"]) + 30
			v["rate"] = int(v["rate"]) + 5
		"senior":
			v["pitch"] = int(v["pitch"]) - 12
			v["rate"] = int(v["rate"]) - 15
	return v


## Which engine this computer can use ("" if none).
static func engine() -> String:
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE)
	var piper := str(config.get_value("voices", "piper_path", ""))
	if not piper.is_empty() and not str(config.get_value("voices", "piper_model", "")).is_empty():
		return "piper"
	match OS.get_name():
		"Windows":
			return "windows"
		"macOS":
			return "macos"
	for program in ["espeak-ng", "espeak"]:
		if _has_program(program):
			return program
	return ""


static func engine_title() -> String:
	match engine():
		"windows":
			return "Windows voices"
		"macos":
			return "macOS voices"
		"piper":
			return "Piper voices"
		"espeak-ng", "espeak":
			return "eSpeak voices"
	return ""


## Speaks [param text] into a cached .wav; returns its path or "" on failure.
static func speak(text: String, voice: Dictionary) -> String:
	var clean := text.strip_edges()
	if clean.is_empty():
		return ""
	var which := engine()
	if which.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var key := ("%s|%s|%s" % [which, JSON.stringify(voice), clean]).sha1_text().left(16)
	var out := CACHE_DIR + key + ".wav"
	if FileAccess.file_exists(out) and FileAccess.get_file_as_bytes(out).size() > 1000:
		return out
	var ok := false
	match which:
		"windows":
			ok = _windows(clean, voice, out)
		"macos":
			ok = _macos(clean, voice, out)
		"piper":
			ok = _piper(clean, voice, out)
		_:
			ok = _espeak(which, clean, voice, out)
	return out if ok and FileAccess.file_exists(out) else ""


# --- Engines ----------------------------------------------------------------------------

static func _windows(text: String, voice: Dictionary, out: String) -> bool:
	var script := CACHE_DIR + "speak.ps1"
	var ssml := "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'><prosody pitch='%+d%%' rate='%+d%%'>%s</prosody></speak>" % [
		int(voice["pitch"]), int(voice["rate"]), text.xml_escape()]
	var gender := "Female" if str(voice["gender"]) == "female" else "Male"
	var age: String = {"child": "Child", "senior": "Senior", "young": "Teen"}.get(str(voice["age"]), "Adult")
	var lines: PackedStringArray = [
		"Add-Type -AssemblyName System.Speech",
		"$s = New-Object System.Speech.Synthesis.SpeechSynthesizer",
		"$name = '%s'" % str(voice["name"]).replace("'", ""),
		"$picked = $false",
		"if ($name -ne '') { foreach ($v in $s.GetInstalledVoices()) { if ($v.VoiceInfo.Name -like ('*' + $name + '*')) { $s.SelectVoice($v.VoiceInfo.Name); $picked = $true; break } } }",
		"if (-not $picked) { $s.SelectVoiceByHints([System.Speech.Synthesis.VoiceGender]::%s, [System.Speech.Synthesis.VoiceAge]::%s) }" % [gender, age],
		"$s.SetOutputToWaveFile('%s')" % ProjectSettings.globalize_path(out).replace("'", "''"),
		"$s.SpeakSsml(@'\n%s\n'@)" % ssml,
		"$s.Dispose()",
	]
	var file := FileAccess.open(script, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("\n".join(lines))
	file.close()
	var output: Array = []
	var code := OS.execute("powershell", PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ProjectSettings.globalize_path(script)]), output, true)
	return code == 0


static func _macos(text: String, voice: Dictionary, out: String) -> bool:
	var name := str(voice["name"])
	if name.is_empty():
		name = str({"female": "Samantha", "male": "Daniel"}.get(str(voice["gender"]), "Samantha"))
		if str(voice["age"]) == "senior" and str(voice["gender"]) == "male":
			name = "Daniel"
	var rate := 175 + int(voice["rate"])
	var aiff := ProjectSettings.globalize_path(out).get_basename() + ".aiff"
	var output: Array = []
	var code := OS.execute("say", PackedStringArray(["-v", name, "-r", str(rate), "-o", aiff, text]), output, true)
	if code != 0:
		code = OS.execute("say", PackedStringArray(["-r", str(rate), "-o", aiff, text]), output, true)
	if code != 0:
		return false
	code = OS.execute("afconvert", PackedStringArray(["-f", "WAVE", "-d", "LEI16@22050", aiff, ProjectSettings.globalize_path(out)]), output, true)
	DirAccess.remove_absolute(aiff)
	return code == 0


static func _espeak(program: String, text: String, voice: Dictionary, out: String) -> bool:
	var variant := "f3" if str(voice["gender"]) == "female" else "m3"
	if str(voice["age"]) == "child":
		variant = "f5"
	elif str(voice["age"]) == "senior":
		variant = "m7" if str(voice["gender"]) == "male" else "f2"
	var pitch := clampi(50 + int(voice["pitch"]), 0, 99)
	var speed := clampi(160 + int(voice["rate"]) * 2, 80, 300)
	var output: Array = []
	var code := OS.execute(program, PackedStringArray(["-v", "en-us+" + variant, "-s", str(speed), "-p", str(pitch),
		"-w", ProjectSettings.globalize_path(out), text]), output, true)
	return code == 0


static func _piper(text: String, _voice: Dictionary, out: String) -> bool:
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE)
	var input := CACHE_DIR + "line.txt"
	var file := FileAccess.open(input, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var output: Array = []
	# Piper reads the text from stdin; go through the shell to redirect it.
	var command := "\"%s\" --model \"%s\" --output_file \"%s\" < \"%s\"" % [str(config.get_value("voices", "piper_path")),
		str(config.get_value("voices", "piper_model")), ProjectSettings.globalize_path(out), ProjectSettings.globalize_path(input)]
	var code := -1
	if OS.get_name() == "Windows":
		code = OS.execute("cmd", PackedStringArray(["/C", command]), output, true)
	else:
		code = OS.execute("sh", PackedStringArray(["-c", command]), output, true)
	return code == 0


static func _has_program(program: String) -> bool:
	var output: Array = []
	if OS.get_name() == "Windows":
		return OS.execute("where", PackedStringArray([program]), output, true) == 0
	return OS.execute("sh", PackedStringArray(["-c", "command -v " + program]), output, true) == 0

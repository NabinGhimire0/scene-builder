extends SceneTree
## godot -s res://tests/voice_change_test.gd -- in.wav out_dir
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src := VoiceChanger.read(args[0])
	var x: PackedFloat32Array = src["samples"]
	var info := VoiceChanger.analyse(x)
	print("source %.1f s, median f0 %.0f Hz, male %s" % [x.size() / 22050.0, info["median"], info["male"]])
	for preset in ["Woman", "Man", "Girl", "Old man", "Giant", "Chipmunk", "Robot", "Whisper", "Radio", "Cave", "Monster", "Alien"]:
		var t0 := Time.get_ticks_msec()
		var s := VoiceChanger.settings_for(preset, float(info["median"]))
		var y := VoiceChanger.process(x, 22050, s)
		var ms := Time.get_ticks_msec() - t0
		var a := VoiceChanger.analyse(y) if preset in ["Woman", "Man", "Girl", "Giant", "Robot"] else {"median": 0.0}
		VoiceChanger.write(args[1] + "/" + preset.replace(" ", "_") + ".wav", y)
		var rms := 0.0
		for v in y:
			rms += v * v
		print("%-9s %5d ms  pitch x%.2f formant x%.2f -> median %.0f Hz  rms %.3f  len %.1f s" % [preset, ms, float(s.get("pitch", 1.0)), float(s.get("formant", 1.0)), a["median"], sqrt(rms / y.size()), y.size() / 22050.0])
	quit()

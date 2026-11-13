extends Node
## Builds a film, then prints the ground height at points: -- <script> "x,z;x,z;…"

func _ready() -> void:
	TutorialOverlay.mark_done()
	var args := OS.get_cmdline_user_args()
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 5:
		await get_tree().process_frame
	var director: ScriptDirector = app.find_child("ScriptDirector", true, false)
	var package := FilmPackage.open(args[0])
	director.build_from_text(str(package["text"]), str(package["dir"]))
	for pair in args[1].split(";"):
		var xz := pair.split(",")
		var x := float(xz[0])
		var z := float(xz[1])
		print("GROUND %6.1f %6.1f -> %.2f" % [x, z, director._ground(x, z)])
	if args.size() > 2:
		var timeline: TimelineController = director.builder.timeline
		for ts in args[2].split(","):
			timeline.set_time(float(ts))
			for i in 2:
				await get_tree().process_frame
			for who in ["Arjun", "Sheru", "Guru", "aura", "Aura", "EnergyAura"]:
				var n := app.find_child(who, true, false) as Node3D
				if n:
					print("POS t=%s %s %s scale %s vis %s" % [ts, who, str(n.global_position.snapped(Vector3.ONE * 0.1)), str(n.scale), n.is_visible_in_tree()])
	get_tree().quit()


## Also: -- <script> "<points>" "t1,t2,…" prints where Arjun/Sheru/Guru are at those times.
func _notification(what: int) -> void:
	pass

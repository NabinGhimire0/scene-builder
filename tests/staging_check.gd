extends Node
## Checks a film's staging without rendering: people who talk to each other but face
## elsewhere, and people standing inside furniture.
## godot --headless res://tests/StagingCheck.tscn -- <script>

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
	var things: Dictionary = director.get("_things")
	var events: Array = director.get("_events")
	var props: Array = []
	var seen := {}
	for key in things:
		var thing: Dictionary = things[key]
		if seen.has(thing):
			continue
		seen[thing] = true
		if thing.get("kind") == "prop" and thing.get("node") is Node3D:
			var box := PropUtils.world_aabb(thing["node"] as Node3D)
			var name := str(thing.get("kind_name", thing.get("display", "")))
			if box.size.y > 0.35 and box.size.y < 2.6 and box.position.y < 0.3 and maxf(box.size.x, box.size.z) < 4.0 and not name.contains("rug") and not name.contains("Rug") and not name.contains("door") and not name.contains("Door"):
				props.append([name, box])
	var problems := 0
	var reported := {}
	for event in events:
		if str(event.get("kind")) != "line":
			continue
		var t := float(event["t"]) + 0.9
		var who: Dictionary = director.call("_thing", str(event["who"]))
		if who.is_empty() or who.get("kind") != "character" or bool(who.get("hidden", false)):
			continue
		var here: Vector3 = director.call("_pos_at", who, t)
		var sitting: bool = director.call("_sitting_at", who, t) or director.call("_lying_at", who, t)
		# Inside furniture (standing people only).
		if not sitting:
			for entry in props:
				var box: AABB = entry[1]
				var shrunk := box.grow(-0.12)
				if here.x > shrunk.position.x and here.x < shrunk.end.x and here.z > shrunk.position.z and here.z < shrunk.end.z and here.y < box.end.y - 0.2:
					var key := "%s-in-%s-%d" % [event["who"], entry[0], int(t / 5.0)]
					if not reported.has(key):
						reported[key] = true
						problems += 1
						print("STAGE %.1f INSIDE %s stands inside %s at %s box %s" % [t, event["who"], entry[0], here, box])
		var to := str(event.get("to", ""))
		if to.is_empty():
			continue
		var other: Dictionary = director.call("_thing", to)
		if other.is_empty() or other.get("kind") != "character":
			continue
		var there: Vector3 = director.call("_pos_at", other, t)
		if here.distance_to(there) > 6.0:
			continue
		for pair in [[who, here, there, str(event["who"])], [other, there, here, to]]:
			var person: Dictionary = pair[0]
			if director.call("_sitting_at", person, t) or director.call("_lying_at", person, t):
				continue
			var want: float = director.call("_yaw_towards", pair[1], pair[2])
			var have: float = director.call("_yaw_at", person, t + 0.6)
			var off := absf(wrapf(want - have, -180.0, 180.0))
			if off > 45.0:
				var key := "%s-%d" % [pair[3], int(t / 3.0)]
				if not reported.has(key):
					reported[key] = true
					problems += 1
					print("STAGE %.1f FACING %s faces %d deg away from %s" % [t, pair[3], int(off), to if pair[3] != to else str(event["who"])])
	print("STAGE total %d" % problems)
	get_tree().quit()

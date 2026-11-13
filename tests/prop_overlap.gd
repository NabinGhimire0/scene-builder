extends Node
## Lists solid furniture that overlaps other furniture in every set a film builds.

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
	var list: Array = []
	var seen := {}
	for key in things:
		var thing: Dictionary = things[key]
		if seen.has(thing) or thing.get("kind") != "prop" or not (thing.get("node") is Node3D):
			continue
		seen[thing] = true
		var box := PropUtils.world_aabb(thing["node"] as Node3D)
		if box.size.y < 0.3 or maxf(box.size.x, box.size.z) > 4.0 or box.position.y > 0.3:
			continue
		list.append([str(thing.get("display", key)), box])
	for i in list.size():
		for j in range(i + 1, list.size()):
			var a: AABB = list[i][1]
			var b: AABB = list[j][1]
			var ox := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
			var oz := minf(a.end.z, b.end.z) - maxf(a.position.z, b.position.z)
			if ox > 0.08 and oz > 0.08:
				print("OVERLAP %s <-> %s  %.2f x %.2f  at (%.1f, %.1f)" % [list[i][0], list[j][0], ox, oz, a.get_center().x, a.get_center().z])
	get_tree().quit()

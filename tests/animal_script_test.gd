extends Node
func _ready() -> void:
	TutorialOverlay.mark_done()
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 6:
		await get_tree().process_frame
	var director: ScriptDirector = app.find_child("ScriptDirector", true, false)
	var text := "REQUIRES: Scene Builder 1.24\nTITLE: Farm\nLOCATION: Golden Valley\nCAST:\nMira = woman casual\nMoti = cow, colour brown\nKali = goat, colour black\nSheru = dog\nSCENE 1: Morning\nMira is at center\nMoti is near Mira\nKali is near Moti\nSheru is near Mira\nSheru runs to Moti\nKali eats\nMoti lies down\nMira: \"Good morning, Moti!\"\nWAIT 2s\n"
	var r := director.build_from_text(text, "")
	print("ANIMALSCRIPT length ", r.get("length"), " counts ", r.get("counts"), " warnings ", r.get("warnings"), " missing ", r.get("missing"), " subs ", r.get("subs"))
	get_tree().quit()

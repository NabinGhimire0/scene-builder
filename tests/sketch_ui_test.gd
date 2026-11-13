extends Node
## Flat sketch editing: Style switch round-trip (flatten / unflatten), and a
## screenshot of the Inspector with a sketch character selected.
## godot res://tests/SketchUITest.tscn -- <out dir>

func _ready() -> void:
	TutorialOverlay.mark_done()
	var out := OS.get_cmdline_user_args()[0]
	var app: Node = load("res://scenes/MainApp.tscn").instantiate()
	get_tree().root.add_child.call_deferred(app)
	for i in 6:
		await get_tree().process_frame
	var director: ScriptDirector = app.find_child("ScriptDirector", true, false)
	director.build_from_text("TITLE: UI\nLOCATION: Living Room\nCAST:\nMina = sketch person\nSCENE 1: S\nMina is at center\nWAIT 6s\n", "")
	var env: EnvironmentController = director.builder.environment
	var sofa: Node3D
	var mina: SketchCharacter
	for c in director.builder.placed_props_root.get_children():
		if c is SketchCharacter:
			mina = c
		elif sofa == null and str(c.name).to_lower().contains("sofa"):
			sofa = c
	var mesh := sofa.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var before := mesh.get_surface_override_material(0)
	env.look = SketchLook.LOOK
	var flat := mesh.get_surface_override_material(0) as StandardMaterial3D
	print("SKETCHUI: flattened ", flat != null and flat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED)
	env.look = "Realistic"
	print("SKETCHUI: restored ", mesh.get_surface_override_material(0) == before, " meta gone ", not mesh.has_meta(SketchLook.META))
	env.look = SketchLook.LOOK
	var selection: SelectionManager = app.find_child("SelectionManager", true, false)
	selection.select(mina)
	for i in 10:
		await get_tree().process_frame
	var inspector := app.find_child("InspectorPanel", true, false)
	print("SKETCHUI: sketch box visible ", (inspector.get("_sketch_box") as Control).is_visible_in_tree(),
		" human box visible ", (inspector.get("_appearance_box") as Control).visible)
	var box := inspector.get("_sketch_box") as Control
	for s in inspector.find_children("*", "ScrollContainer", true, false):
		(s as ScrollContainer).ensure_control_visible(box)
	for i in 6:
		await get_tree().process_frame
	get_tree().root.get_texture().get_image().save_png(out.path_join("sketch_inspector.png"))
	print("SKETCHUI: saved")
	get_tree().quit()

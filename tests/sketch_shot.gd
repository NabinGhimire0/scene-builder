extends Node3D
## Renders the sketch characters with every expression, in the Flat sketch look.
## godot res://tests/SketchShot.tscn -- <out prefix>


func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = SketchLook.BACKGROUND
	env.environment.glow_enabled = true
	add_child(env)
	add_child(SketchLook.make_outline())
	var floor_line := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(40, 0.012, 0.012)
	floor_line.mesh = box
	floor_line.material_override = SketchCharacter._flat(Color(0.5, 0.48, 0.46))
	add_child(floor_line)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 16
	# 1) line-up of expressions
	var x := 0.0
	var people: Array = []
	for e in SketchCharacter.EXPRESSIONS:
		var p := (load("res://assets/props/characters/sketch_person.tscn") as PackedScene).instantiate() as SketchCharacter
		add_child(p)
		p.position = Vector3(x, 0, 0)
		p.expression = e
		people.append(p)
		x += 0.75
	var shadow := (load("res://assets/props/characters/sketch_shadow.tscn") as PackedScene).instantiate() as SketchCharacter
	add_child(shadow)
	shadow.position = Vector3(x + 0.4, 0, 0)
	var motion := CharacterMotion.new()
	for c in people + [shadow]:
		(c as SketchCharacter).evaluate(0.5, motion)
	var mid := (x + 0.4) * 0.5
	cam.look_at_from_position(Vector3(mid, 1.0, 30), Vector3(mid, 1.0, 0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "_lineup.png")
	# 2) faces close
	cam.fov = 6
	cam.look_at_from_position(Vector3(1.5, 1.45, 30), Vector3(1.5, 1.45, 0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "_faces.png")
	# 3) a scene: person sitting (side), shadow behind, facing right
	for c in people:
		(c as Node3D).visible = false
	var hero := people[1] as SketchCharacter
	hero.visible = true
	hero.position = Vector3(0, 0, 0)
	hero.rotation_degrees.y = 90
	hero.apply_pose(MotionLibrary.pose("Sit", 1.0))
	hero._aim_face()
	shadow.position = Vector3(-1.0, 0, -0.3)
	shadow.rotation_degrees.y = 90
	shadow.apply_pose(MotionLibrary.pose("Idle", 0.5))
	shadow._aim_face()
	cam.fov = 14
	cam.look_at_from_position(Vector3(-0.3, 1.0, 12), Vector3(-0.3, 0.95, 0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "_scene.png")
	get_tree().quit()

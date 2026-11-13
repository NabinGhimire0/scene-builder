class_name SketchCharacter
extends HumanCharacter
## A character for the Flat sketch look: a soft, rounded figure with a drawn
## face (expressions), or a dark "shadow" figure with a glowing face and halo.
##
## It uses the same joints as the built-in people, so every action, gesture,
## pose, walk and sit works. The face always looks towards the flat camera
## (like a drawing) and leans the way the character faces.

const FIGURES: PackedStringArray = ["Person", "Shadow", "Cartoon", "Story"]
const EXPRESSIONS: PackedStringArray = ["Neutral", "Tired", "Sad", "Ashamed", "Scared", "Angry", "Determined", "Happy", "Smirk", "Shocked",
	"Crying", "Asleep", "Proud", "Hopeful", "Worried", "Laughing"]
const HAIRS: PackedStringArray = ["Curl", "Long", "Bob", "Bun", "Short", "Spiky", "Ponytail", "Curly", "Braids", "None"]
const STORY_HATS: PackedStringArray = ["None", "Cap", "Bandana", "Sun hat", "Beanie", "Hard hat", "Chef hat"]
const PERSON_DEFAULTS := {"body_color": Color(0.86, 0.88, 0.9), "line_color": Color(0.16, 0.16, 0.18), "glow_color": Color(1.0, 0.75, 0.4)}
## Story: the silhouette people of short animated films - a black figure with white
## eyes and coloured clothes, outlined by a thin light rim.
const GLOW_SHADER := preload("res://assets/materials/story_glow.gdshader")
const STORY_DEFAULTS := {"body_color": Color(0.035, 0.035, 0.04), "line_color": Color(0.93, 0.92, 0.9), "glow_color": Color(1.0, 0.25, 0.15), "hair_color": Color(0.035, 0.035, 0.04)}
const SHADOW_DEFAULTS := {"body_color": Color(0.02, 0.02, 0.025), "line_color": Color(0.55, 0.3, 0.95), "glow_color": Color(0.62, 0.32, 1.0)}

## Person: the round sketch figure. Shadow: a dark figure with a glowing face.
## Cartoon: a bright cartoon character - big head, big eyes, clothes and shoes.
## Story: a black silhouette person with white eyes, coloured clothes and a light rim.
@export_enum("Person", "Shadow", "Cartoon", "Story") var figure: String = "Person":
	set(v):
		figure = v if FIGURES.has(v) else "Person"
		_mark_dirty()
@export var body_color := Color(0.86, 0.88, 0.9):
	set(v):
		body_color = v
		_mark_dirty()
## Colour of the face lines (Person) or the glowing face (Shadow).
@export var line_color := Color(0.16, 0.16, 0.18):
	set(v):
		line_color = v
		_mark_dirty()
## The halo around a Shadow (and the colour of its whispers); for Story people the
## colour of their emotion glow (see glow_amount).
@export var glow_color := Color(1.0, 0.75, 0.4):
	set(v):
		glow_color = v
		if figure == "Story" and _built:
			_update_glow()
		else:
			_mark_dirty()
## Story: how strongly the emotion glow shows around the figure (0 = none). Animatable.
@export_range(0.0, 1.0, 0.01) var glow_amount := 0.0:
	set(v):
		glow_amount = clampf(v, 0.0, 1.0)
		_update_glow()
## Story: the thin light rim around the silhouette (alpha 0 = none).
@export var outline_color := Color(0.96, 0.94, 0.88, 1.0):
	set(v):
		outline_color = v
		_mark_dirty()
## Story: a hat or head wrap.
@export_enum("None", "Cap", "Bandana", "Sun hat", "Beanie", "Hard hat", "Chef hat") var story_hat: String = "None":
	set(v):
		story_hat = v if STORY_HATS.has(v) else "None"
		_mark_dirty()
@export var hat_color := Color(0.85, 0.2, 0.2):
	set(v):
		hat_color = v
		_mark_dirty()
## Story: an apron over the clothes (alpha 0 = none).
@export var apron_color := Color(0.3, 0.3, 0.32, 0.0):
	set(v):
		apron_color = v
		_mark_dirty()
## Story: small extra colour - hair tie, hat band, lanyard strap (alpha 0 = default).
@export var accent_color := Color(0.95, 0.6, 0.5, 0.0):
	set(v):
		accent_color = v
		_mark_dirty()
@export var lanyard := false:
	set(v):
		lanyard = v
		_mark_dirty()
@export var headphones := false:
	set(v):
		headphones = v
		_mark_dirty()
## Story: a skirt instead of trousers (in pants_color).
@export var skirt := false:
	set(v):
		skirt = v
		_mark_dirty()
## The face when no expression is keyed.
@export_enum("Neutral", "Tired", "Sad", "Ashamed", "Scared", "Angry", "Determined", "Happy", "Smirk", "Shocked",
	"Crying", "Asleep", "Proud", "Hopeful", "Worried", "Laughing") var expression: String = "Neutral":
	set(v):
		expression = v if EXPRESSIONS.has(v) else "Neutral"
		_show_expression(EXPRESSIONS.find(expression), 0.0)

## Person: the hair (drawn in hair_color). Curl is the little curl on top.
@export_enum("Curl", "Long", "Bob", "Bun", "Short", "Spiky", "Ponytail", "Curly", "Braids", "None") var hair: String = "Curl":
	set(v):
		hair = v if HAIRS.has(v) else "Curl"
		_mark_dirty()
## Person: a top (a hoodie or jumper) over the body and arms; alpha 0 = none.
@export var shirt_color := Color(0.4, 0.42, 0.46, 0.0):
	set(v):
		shirt_color = v
		_mark_dirty()
## Person: trousers over the hips and legs (alpha 0 = a plain darker shade when a top is set).
@export var pants_color := Color(0.3, 0.33, 0.42, 0.0):
	set(v):
		pants_color = v
		_mark_dirty()
## Cartoon: long sleeves (a hoodie or jumper) instead of a T-shirt.
@export var long_sleeves := false:
	set(v):
		long_sleeves = v
		_mark_dirty()
## Cartoon: a cap worn backwards (alpha 0 = none). Shoes use shoe_color.
@export var cap_color := Color(0.95, 0.75, 0.2, 0.0):
	set(v):
		cap_color = v
		_mark_dirty()
## Shadow: a scribbled, furry edge that boils (moves) like a hand-drawn scribble.
@export var fuzzy := false:
	set(v):
		fuzzy = v
		_mark_dirty()

var _face_root: Node3D
var _fur: Array = []               # [MeshInstance3D, base rotation (Vector3), seed]
var _params: Dictionary = {}       # the face as drawn now (eases towards the expression)
var _last_t := -1000.0
var _ease := 1.0
var _face_parts: Dictionary = {}   # name -> MeshInstance3D
var _shown_expression := -1
var _face_lean := 0.0
var _line_material: StandardMaterial3D
var _face_y := 0.15
var _face_scale := 1.0             # cartoon heads are bigger: the face is drawn bigger too
var _glow_nodes: Array = []        # Story: [MeshInstance3D, base alpha] of the emotion glow
var _glow_material: Array = []     # the two glow materials (inner, outer)


func _init() -> void:
	body_type = "Man"
	height = 1.55
	add_to_group(&"sketch_faces")


func get_custom_state() -> Dictionary:
	var state := super.get_custom_state()
	state["figure"] = figure
	for key in ["body_color", "line_color", "glow_color"]:
		var c: Color = get(key)
		state[key] = [c.r, c.g, c.b]
	state["expression"] = expression
	state["hair"] = hair
	state["shirt_color"] = [shirt_color.r, shirt_color.g, shirt_color.b, shirt_color.a]
	state["pants_color"] = [pants_color.r, pants_color.g, pants_color.b, pants_color.a]
	state["cap_color"] = [cap_color.r, cap_color.g, cap_color.b, cap_color.a]
	state["long_sleeves"] = long_sleeves
	state["fuzzy"] = fuzzy
	if figure == "Story":
		for key in ["outline_color", "hat_color", "apron_color", "accent_color"]:
			var c4: Color = get(key)
			state[key] = [c4.r, c4.g, c4.b, c4.a]
		state["story_hat"] = story_hat
		state["glasses"] = glasses
		state["lanyard"] = lanyard
		state["headphones"] = headphones
		state["skirt"] = skirt
	return state


func set_custom_state(state: Dictionary) -> void:
	if state.has("figure"):
		figure = str(state["figure"])
	for key in ["body_color", "line_color", "glow_color"]:
		var v: Variant = state.get(key)
		if v is Array and (v as Array).size() >= 3:
			set(key, Color(float(v[0]), float(v[1]), float(v[2])))
	if state.has("expression"):
		expression = str(state["expression"])
	if state.has("hair"):
		hair = str(state["hair"])
	var shirt: Variant = state.get("shirt_color")
	if shirt is Array and (shirt as Array).size() >= 4:
		shirt_color = Color(float(shirt[0]), float(shirt[1]), float(shirt[2]), float(shirt[3]))
	var pants: Variant = state.get("pants_color")
	if pants is Array and (pants as Array).size() >= 4:
		pants_color = Color(float(pants[0]), float(pants[1]), float(pants[2]), float(pants[3]))
	for key in ["cap_color"]:
		var c4: Variant = state.get(key)
		if c4 is Array and (c4 as Array).size() >= 4:
			set(key, Color(float(c4[0]), float(c4[1]), float(c4[2]), float(c4[3])))
	if state.has("long_sleeves"):
		long_sleeves = bool(state["long_sleeves"])
	if state.has("fuzzy"):
		fuzzy = bool(state["fuzzy"])
	for key in ["outline_color", "hat_color", "apron_color", "accent_color"]:
		var c5: Variant = state.get(key)
		if c5 is Array and (c5 as Array).size() >= 4:
			set(key, Color(float(c5[0]), float(c5[1]), float(c5[2]), float(c5[3])))
	for key in ["glasses", "lanyard", "headphones", "skirt"]:
		if state.has(key):
			set(key, bool(state[key]))
	if state.has("story_hat"):
		story_hat = str(state["story_hat"])
	super.set_custom_state(state)


## Sets the look of a figure type and its default colours.
func use_figure(kind: String) -> void:
	figure = kind
	var defaults: Dictionary = SHADOW_DEFAULTS if kind == "Shadow" else (STORY_DEFAULTS if kind == "Story" else PERSON_DEFAULTS)
	for key in defaults:
		set(key, defaults[key])
	if kind == "Shadow":
		height = 1.9
		expression = "Smirk"


func evaluate(t: float, motion: CharacterMotion) -> void:
	super.evaluate(t, motion)
	# Keyed expressions travel with the hand pose (key "Face": index in x).
	var keyed: Dictionary = motion.pose_at(t)
	var index := EXPRESSIONS.find(expression)
	if keyed.has("face"):
		index = clampi(roundi((keyed["face"] as Vector3).x), 0, EXPRESSIONS.size() - 1)
	var open := lipsync_at(t)
	if open < 0.0:
		var state := motion.action_state(t)
		var since := t - float(state["start"])
		open = clampf(0.5 + 0.5 * sin(since * 13.0) * sin(since * 4.1 + 0.7), 0.0, 1.0) * 0.8 if str(state["action"]) == "Talk" else 0.0
	var seed_value := float(hash(name) % 97)
	var cycle := fposmod(t + seed_value * 0.37, 3.9 + fposmod(seed_value, 1.3))
	var blink := cycle < 0.13 and figure != "Shadow" and EXPRESSIONS[index] != "Asleep"
	# Ease the face towards the new expression while playing; jump when scrubbing.
	var step := t - _last_t
	_last_t = t
	_ease = 1.0 if step <= 0.0 or step > 0.25 else clampf(step / 0.16, 0.0, 1.0)
	_show_expression(index, open, blink)
	_aim_face()
	_boil(t)


## The keyed "face" entry is not a joint.
func apply_manual_pose(pose: Dictionary) -> void:
	var joints := pose.duplicate()
	joints.erase("face")
	joints.erase("Face")
	super.apply_manual_pose(joints)


# --- Construction ------------------------------------------------------------------

func _rebuild() -> void:
	if _body:
		remove_child(_body)
		_body.free()
	_joints.clear()
	_face_parts.clear()
	_face_scale = 1.0
	_params = {}
	_shown_expression = -1
	_posture = 0.0
	var shadow := figure == "Shadow"
	var w := build * (0.85 if shadow else 1.0)
	var fill := _flat(body_color)
	var top := fill if shadow or shirt_color.a < 0.05 else _flat(Color(shirt_color.r, shirt_color.g, shirt_color.b))
	# Dressed people get trousers and shoes too (jeans unless a colour is given).
	var dressed := not shadow and (shirt_color.a >= 0.05 or pants_color.a >= 0.05)
	var bottom := fill
	var shoes := fill
	if dressed:
		bottom = _flat(Color(pants_color.r, pants_color.g, pants_color.b) if pants_color.a >= 0.05 else Color(0.3, 0.36, 0.5))
		shoes = _flat(Color(0.22, 0.2, 0.2))
	_line_material = _flat(line_color * (1.6 if shadow else 1.0))
	_fur = []

	_body = Node3D.new()
	_body.name = "Body"
	_body.scale = Vector3.ONE * size_factor()
	add_child(_body)
	if figure == "Cartoon":
		_build_cartoon(fill, top, bottom)
		_finish_build(w)
		return
	if figure == "Story":
		_build_story(fill)
		_finish_build(w)
		_add_story_shell()
		return

	# Torso: one soft, slightly pear-shaped body (a drawing has no clothes lines).
	var hips := _joint("hips", _body, Vector3(0, 0.9, 0))
	_hips_rest = hips.position
	var round_body := 1.0 if shadow else 1.18
	_part(hips, _sphere(0.18), Vector3(0, 0.0, 0), bottom, Vector3(1.08 * w * round_body, 0.95, 1.0 * w * round_body))
	var spine := _joint("spine", hips, Vector3(0, 0.1, 0))
	_part(spine, _capsule(0.17, 0.38), Vector3(0, 0.07, 0), top, Vector3(1.04 * w * round_body, 1.0, 0.98 * w * round_body))
	var chest := _joint("chest", spine, Vector3(0, 0.2, 0))
	_part(chest, _capsule(0.155, 0.3), Vector3(0, 0.05, 0), top, Vector3(1.0 * w * (1.0 + (round_body - 1.0) * 0.6), 1.0, 0.92 * w * (1.0 + (round_body - 1.0) * 0.6)))

	# Head: a big round head on a short neck.
	var neck := _joint("neck", chest, Vector3(0, 0.2, 0))
	_part(neck, _cylinder(0.06, 0.07, 0.1), Vector3(0, 0.02, 0), fill)
	var head := _joint("head", neck, Vector3(0, 0.06, 0))
	var head_radius := 0.19 if not shadow else 0.15
	_part(head, _sphere(head_radius), Vector3(0, head_radius * 0.95, 0), fill, Vector3(1.0, 0.98, 0.95))
	if shadow:
		# Two small pointed tips on the head.
		for side in [-1.0, 1.0]:
			var tip := _part(head, _cylinder(0.0, 0.045, 0.12), Vector3(side * 0.075, head_radius * 1.85, 0), fill)
			tip.rotation_degrees = Vector3(0, 0, -side * 18.0)
	else:
		_build_hair_sketch(head, head_radius, fill)
	_face_root = Node3D.new()
	_face_root.name = "Face"
	_face_y = head_radius * 0.95
	_face_root.position = Vector3(0, _face_y, 0)
	head.add_child(_face_root)
	_build_face(head_radius, shadow)

	# Arms: thin, rounded, no hands to speak of (mitten ends).
	var shoulder_w := 0.17 * w
	for side in [1.0, -1.0]:
		var suffix := "_l" if side > 0.0 else "_r"
		var shoulder := _joint("shoulder" + suffix, chest, Vector3(shoulder_w * side, 0.15, 0))
		_part(shoulder, _capsule(0.048 * w, 0.32), Vector3(0, -0.13, 0), top)
		var elbow := _joint("elbow" + suffix, shoulder, Vector3(0, -0.28, 0))
		_part(elbow, _capsule(0.045 * w, 0.28), Vector3(0, -0.12, 0), top)
		var wrist := _joint("wrist" + suffix, elbow, Vector3(0, -0.25, 0))
		_part(wrist, _sphere(0.06 * w), Vector3(0, -0.045, 0.0), fill, Vector3(0.9, 1.15, 0.8))

	# Legs: short and soft, rounded feet.
	for side in [1.0, -1.0]:
		var suffix := "_l" if side > 0.0 else "_r"
		var hip := _joint("hip" + suffix, hips, Vector3(0.085 * w * side, -0.05, 0))
		_part(hip, _capsule(0.07 * w, 0.46), Vector3(0, -0.2, 0), bottom)
		var knee := _joint("knee" + suffix, hip, Vector3(0, -0.42, 0))
		_part(knee, _capsule(0.062 * w, 0.42), Vector3(0, -0.19, 0), bottom)
		var ankle := _joint("ankle" + suffix, knee, Vector3(0, -0.38, 0))
		_part(ankle, _sphere(0.07 * w), Vector3(0, -0.035, 0.04), shoes, Vector3(1.0, 0.6, 1.5))

	if shadow:
		_add_halo()
		if fuzzy:
			_add_fur(fill)
	_finish_build(w)


func _finish_build(w: float) -> void:
	var collider := StaticBody3D.new()
	collider.name = "Collider"
	collider.collision_layer = Layers.PROPS
	collider.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26 * w
	capsule.height = 1.75
	shape.shape = capsule
	shape.position = Vector3(0, 0.88, 0)
	collider.add_child(shape)
	_body.add_child(collider)

	_built = true
	_dirty = false
	_eyes = []
	_mouth = null
	apply_pose(MotionLibrary.idle(0.0))
	_show_expression(EXPRESSIONS.find(expression), 0.0)


## Cartoon head radius: children get bigger heads than grown-ups (cartoon proportions).
func _cartoon_head() -> float:
	return lerpf(0.3, 0.215, clampf((height - 1.0) / 0.75, 0.0, 1.0))


func size_factor() -> float:
	if figure == "Story":
		return height / (1.46 + _story_head() * 1.95)
	if figure == "Cartoon":
		# The whole figure (feet to the top of the head) is [member height] tall.
		return height / (1.42 + _cartoon_head() * 1.9)
	return super.size_factor()


## The cartoon figure: same joints as the sketch person (every action works), with
## cartoon proportions - a big head with ears and a nose, a T-shirt or hoodie, hands,
## jeans and chunky trainers.
func _build_cartoon(skin: Material, top: Material, bottom: Material) -> void:
	var w := build
	var dressed := shirt_color.a >= 0.05 or pants_color.a >= 0.05
	var shoe := _flat(shoe_color.lightened(0.12))
	var sole := _flat(Color(0.96, 0.96, 0.94))
	var shirt := top if dressed else _flat(Color(0.45, 0.7, 0.9))
	var trousers := bottom if dressed else _flat(Color(0.3, 0.42, 0.62))
	var hips := _joint("hips", _body, Vector3(0, 0.9, 0))
	_hips_rest = hips.position
	_part(hips, _sphere(0.155), Vector3(0, 0.0, 0), trousers, Vector3(1.06 * w, 0.9, 0.95 * w))
	var spine := _joint("spine", hips, Vector3(0, 0.1, 0))
	_part(spine, _capsule(0.145, 0.36), Vector3(0, 0.06, 0), shirt, Vector3(1.04 * w, 1.0, 0.92 * w))
	var chest := _joint("chest", spine, Vector3(0, 0.2, 0))
	_part(chest, _capsule(0.16, 0.3), Vector3(0, 0.05, 0), shirt, Vector3(1.1 * w, 1.0, 0.9 * w))
	var neck := _joint("neck", chest, Vector3(0, 0.16, 0))
	_part(neck, _cylinder(0.05, 0.055, 0.1), Vector3(0, 0.0, 0), skin)
	var head := _joint("head", neck, Vector3(0, 0.06, 0))
	var r := _cartoon_head()
	_part(head, _sphere(r), Vector3(0, r * 0.95, 0), skin, Vector3(1.0, 0.97, 0.9))
	# Ears and a small nose.
	for side in [-1.0, 1.0]:
		_part(head, _sphere(r * 0.2), Vector3(side * r * 0.97, r * 0.88, -r * 0.05), skin, Vector3(0.55, 1.0, 0.8))
	_build_hair_cartoon(head, r)
	if cap_color.a >= 0.05:
		_build_cap(head, r)
	_face_root = Node3D.new()
	_face_root.name = "Face"
	_face_y = r * 0.95
	_face_root.position = Vector3(0, _face_y, 0)
	_face_scale = r / 0.19
	_face_root.scale = Vector3.ONE * _face_scale
	head.add_child(_face_root)
	_build_face(r, false)
	# Arms: a sleeve (short for a T-shirt), skin below, round hands.
	var shoulder_w := 0.165 * w
	for side in [1.0, -1.0]:
		var suffix := "_l" if side > 0.0 else "_r"
		var shoulder := _joint("shoulder" + suffix, chest, Vector3(shoulder_w * side, 0.15, 0))
		if long_sleeves:
			_part(shoulder, _capsule(0.05 * w, 0.32), Vector3(0, -0.13, 0), shirt)
		else:
			_part(shoulder, _capsule(0.056 * w, 0.2), Vector3(0, -0.05, 0), shirt)
			_part(shoulder, _capsule(0.044 * w, 0.3), Vector3(0, -0.15, 0), skin)
		var elbow := _joint("elbow" + suffix, shoulder, Vector3(0, -0.28, 0))
		_part(elbow, _capsule((0.05 if long_sleeves else 0.042) * w, 0.27), Vector3(0, -0.12, 0), shirt if long_sleeves else skin)
		var wrist := _joint("wrist" + suffix, elbow, Vector3(0, -0.25, 0))
		_part(wrist, _sphere(0.058 * w), Vector3(0, -0.04, 0.0), skin, Vector3(0.95, 1.1, 0.85))
	# Legs: jeans and chunky trainers with white soles.
	for side in [1.0, -1.0]:
		var suffix := "_l" if side > 0.0 else "_r"
		var hip := _joint("hip" + suffix, hips, Vector3(0.08 * w * side, -0.05, 0))
		_part(hip, _capsule(0.072 * w, 0.46), Vector3(0, -0.2, 0), trousers)
		var knee := _joint("knee" + suffix, hip, Vector3(0, -0.42, 0))
		_part(knee, _capsule(0.066 * w, 0.42), Vector3(0, -0.19, 0), trousers)
		var ankle := _joint("ankle" + suffix, knee, Vector3(0, -0.38, 0))
		_part(ankle, _sphere(0.075), Vector3(0, -0.02, 0.06), shoe, Vector3(1.0, 0.75, 1.7))
		_part(ankle, _sphere(0.077), Vector3(0, -0.06, 0.065), sole, Vector3(1.02, 0.22, 1.75))


## Story head radius: children have bigger heads for their size.
func _story_head() -> float:
	return lerpf(0.235, 0.2, clampf((height - 1.1) / 0.6, 0.0, 1.0))


## The story figure (the silhouette people of short animated films): a black body
## and head with coloured clothes - a top (short or long sleeves), trousers or a
## skirt, shoes - and extras: apron, hat, glasses, lanyard, headphones.
func _build_story(fill: Material) -> void:
	var w := build
	var shirt := _flat(Color(shirt_color.r, shirt_color.g, shirt_color.b)) if shirt_color.a >= 0.05 else _flat(Color(0.55, 0.62, 0.7))
	var trousers := _flat(Color(pants_color.r, pants_color.g, pants_color.b)) if pants_color.a >= 0.05 else _flat(Color(0.2, 0.22, 0.28))
	var shoe := _flat(shoe_color)
	var accent := Color(accent_color.r, accent_color.g, accent_color.b) if accent_color.a >= 0.05 else Color(0.95, 0.62, 0.52)
	var hips := _joint("hips", _body, Vector3(0, 0.9, 0))
	_hips_rest = hips.position
	if skirt:
		_part(hips, _cylinder(0.13 * w, 0.25 * w, 0.44), Vector3(0, -0.15, 0), trousers, Vector3(1.0, 1.0, 0.85))
	else:
		_part(hips, _sphere(0.15), Vector3(0, 0.0, 0), trousers, Vector3(1.05 * w, 0.85, 0.88 * w))
	var spine := _joint("spine", hips, Vector3(0, 0.1, 0))
	_part(spine, _capsule(0.148, 0.36), Vector3(0, 0.06, 0), shirt, Vector3(1.05 * w, 1.0, 0.84 * w))
	var chest := _joint("chest", spine, Vector3(0, 0.2, 0))
	_part(chest, _capsule(0.155, 0.3), Vector3(0, 0.05, 0), shirt, Vector3(1.1 * w, 1.0, 0.84 * w))
	var neck := _joint("neck", chest, Vector3(0, 0.17, 0))
	_part(neck, _cylinder(0.04, 0.045, 0.12), Vector3(0, 0.0, 0), fill)
	var head := _joint("head", neck, Vector3(0, 0.06, 0))
	var r := _story_head()
	_part(head, _sphere(r), Vector3(0, r * 0.95, 0), fill, Vector3(1.0, 1.02, 0.94))
	var covered := story_hat in ["Cap", "Bandana", "Beanie", "Hard hat", "Chef hat"]
	if not (covered and hair in ["Spiky", "Curl", "Curly", "Short"]):
		match hair:
			"Curly":
				_build_curly(head, r)
			"Braids":
				_build_braids(head, r, accent)
			"Spiky":
				_build_hair_sketch(head, r, fill)
			_:
				_build_story_hair(head, r, accent)
		if hair == "Bun" and not covered:
			var band := _part(head, _cylinder(r * 0.33, r * 0.33, r * 0.14), Vector3(0, r * 1.77, -r * 0.38), _flat(accent))
			band.rotation_degrees = Vector3(-18, 0, 0)
	_build_story_hat(head, r, accent)
	_face_root = Node3D.new()
	_face_root.name = "Face"
	_face_y = r * 0.95
	_face_root.position = Vector3(0, _face_y, 0)
	_face_scale = r / 0.19
	_face_root.scale = Vector3.ONE * _face_scale
	head.add_child(_face_root)
	_build_face(r, false)
	if glasses:
		var frame := _flat(Color(0.95, 0.78, 0.45))
		for side in [-1.0, 1.0]:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.034
			ring.outer_radius = 0.041
			ring.rings = 20
			ring.ring_segments = 6
			var lens_z := (_face_parts["sclera_l"] as Node3D).position.z + 0.014
			var lens := _part(_face_root, ring, Vector3(side * 0.06, 0.015, lens_z), frame, Vector3.ONE, Vector3(90, 0, 0))
			lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_face_parts["glasses_" + ("l" if side < 0.0 else "r")] = lens
		var bridge := _part(_face_root, _capsule(0.004, 0.03), Vector3(0, 0.022, (_face_parts["sclera_l"] as Node3D).position.z + 0.014), frame, Vector3.ONE, Vector3(0, 0, 90))
		_face_parts["glasses_bridge"] = bridge
	# Arms: short sleeves show thin black arms; long sleeves go to the wrist.
	var shoulder_w := 0.165 * w
	for side in [1.0, -1.0]:
		var suffix := "_l" if side > 0.0 else "_r"
		var shoulder := _joint("shoulder" + suffix, chest, Vector3(shoulder_w * side, 0.15, 0))
		if long_sleeves:
			_part(shoulder, _capsule(0.047 * w, 0.32), Vector3(0, -0.13, 0), shirt)
		else:
			_part(shoulder, _capsule(0.047 * w, 0.17), Vector3(0, -0.045, 0), shirt)
			_part(shoulder, _capsule(0.032, 0.3), Vector3(0, -0.15, 0), fill)
		var elbow := _joint("elbow" + suffix, shoulder, Vector3(0, -0.28, 0))
		_part(elbow, _capsule(0.044 * w if long_sleeves else 0.03, 0.27), Vector3(0, -0.12, 0), shirt if long_sleeves else fill)
		var wrist := _joint("wrist" + suffix, elbow, Vector3(0, -0.25, 0))
		_part(wrist, _sphere(0.046), Vector3(0, -0.035, 0.0), fill, Vector3(0.9, 1.2, 0.8))
	# Legs: thin, in trousers (or bare black under a skirt), small coloured shoes.
	for side in [1.0, -1.0]:
		var suffix := "_l" if side > 0.0 else "_r"
		var hip := _joint("hip" + suffix, hips, Vector3(0.075 * w * side, -0.05, 0))
		if skirt:
			_part(hip, _capsule(0.034, 0.46), Vector3(0, -0.2, 0), fill)
		else:
			_part(hip, _capsule(0.058 * w, 0.46), Vector3(0, -0.2, 0), trousers)
		var knee := _joint("knee" + suffix, hip, Vector3(0, -0.42, 0))
		_part(knee, _capsule(0.032 if skirt else 0.05 * w, 0.42), Vector3(0, -0.19, 0), fill if skirt else trousers)
		var ankle := _joint("ankle" + suffix, knee, Vector3(0, -0.38, 0))
		_part(ankle, _sphere(0.062), Vector3(0, -0.025, 0.045), shoe, Vector3(1.0, 0.62, 1.65))
	if apron_color.a >= 0.05:
		var apron := _flat(Color(apron_color.r, apron_color.g, apron_color.b))
		_part(chest, _box(Vector3(0.24 * w, 0.24, 0.012)), Vector3(0, 0.05, 0.133 * w), apron)
		_part(spine, _box(Vector3(0.28 * w, 0.24, 0.012)), Vector3(0, 0.06, 0.128 * w), apron)
		_part(hips, _box(Vector3(0.32 * w, 0.42, 0.012)), Vector3(0, -0.16, 0.14 * w), apron, Vector3.ONE, Vector3(-6, 0, 0))
		_part(chest, _box(Vector3(0.2 * w, 0.03, 0.012)), Vector3(0, 0.185, 0.128 * w), apron)
	if lanyard:
		var strap_mat := _flat(accent if accent_color.a >= 0.05 else Color(0.3, 0.45, 0.85))
		for side in [-1.0, 1.0]:
			var cord := _part(chest, _capsule(0.006, 0.24), Vector3(side * 0.045, 0.09, 0.14 * w), strap_mat)
			cord.rotation_degrees = Vector3(0, 0, side * 14.0)
		_part(chest, _box(Vector3(0.05, 0.07, 0.008)), Vector3(0, -0.06, 0.15 * w), _flat(Color(0.95, 0.95, 0.93)))
	if headphones:
		var phones := _flat(Color(0.9, 0.9, 0.88))
		var band := TorusMesh.new()
		band.inner_radius = 0.075
		band.outer_radius = 0.095
		_part(neck, band, Vector3(0, -0.02, 0.0), phones, Vector3(1.15, 1.0, 1.0), Vector3(20, 0, 0))
		for side in [-1.0, 1.0]:
			_part(neck, _sphere(0.04), Vector3(side * 0.1, -0.03, 0.05), phones, Vector3(0.6, 1.0, 1.0))


## Simple silhouette hair (no fringe blobs): a cap of hair over the top and back, and
## the length - long, bob, bun or ponytail - behind.
func _build_story_hair(head: Node3D, r: float, accent: Color) -> void:
	if hair == "None":
		return
	var tone := _flat(hair_color)
	if hair == "Curl":
		var curl := _part(head, _capsule(0.022, 0.11), Vector3(0.02, r * 1.95, 0.0), tone)
		curl.rotation_degrees = Vector3(0, 0, -35)
		return
	_part(head, _sphere(r * 1.05), Vector3(0, r * 1.12, -r * 0.16), tone, Vector3(1.03, 0.8, 0.98))
	match hair:
		"Long":
			_part(head, _capsule(r * 0.85, r * 2.9), Vector3(0, r * 0.35, -r * 0.45), tone, Vector3(1.06, 1.0, 0.55))
		"Bob":
			_part(head, _capsule(r * 0.95, r * 1.9), Vector3(0, r * 0.75, -r * 0.3), tone, Vector3(1.1, 1.0, 0.7))
		"Bun":
			_part(head, _sphere(r * 0.42), Vector3(0, r * 1.98, -r * 0.42), tone)
		"Ponytail":
			var tail := _part(head, _capsule(r * 0.26, r * 1.5), Vector3(0, r * 0.95, -r * 1.05), tone, Vector3(1.0, 1.0, 0.8))
			tail.rotation_degrees = Vector3(-30, 0, 0)
			_part(head, _sphere(r * 0.14), Vector3(0, r * 1.42, -r * 0.92), _flat(accent))


## A head of tight curls: lots of small balls over the top and back.
func _build_curly(head: Node3D, r: float) -> void:
	var tone := _flat(hair_color)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) + 5
	for i in 26:
		var a := rng.randf() * TAU
		var up := rng.randf_range(0.15, 1.0)
		var dir := Vector3(cos(a) * sqrt(1.0 - up * up), up, sin(a) * sqrt(1.0 - up * up))
		if dir.z > 0.35 and dir.y < 0.75:
			dir.z *= 0.4   # keep the face clear
		_part(head, _sphere(r * rng.randf_range(0.26, 0.34)), Vector3(0, r * 0.98, -r * 0.08) + dir * r * 1.0, tone)


## Braids: a smooth cap and a few braids falling behind the shoulders.
func _build_braids(head: Node3D, r: float, accent: Color) -> void:
	var tone := _flat(hair_color)
	_part(head, _sphere(r * 1.07), CAP_POS * r, tone, CAP_SCALE)
	var bead := _flat(accent)
	for k in 6:
		var a := lerpf(-1.1, 1.1, float(k) / 5.0)
		var braid := _part(head, _capsule(r * 0.09, r * 2.2), Vector3(sin(a) * r * 0.7, r * 0.2, -r * 0.55 - cos(a) * r * 0.25), tone)
		braid.rotation_degrees = Vector3(12, 0, rad_to_deg(a) * 0.12)
		if k % 2 == 0:
			_part(head, _sphere(r * 0.1), Vector3(sin(a) * r * 0.72, -r * 0.85, -r * 0.5 - cos(a) * r * 0.25), bead)


## Hats for story people (in hat_color).
func _build_story_hat(head: Node3D, r: float, accent: Color) -> void:
	if story_hat == "None":
		return
	var cloth := _flat(hat_color)
	match story_hat:
		"Cap":
			# Sits on the crown, above the brows (it used to come down over the eyes).
			_part(head, _sphere(r * 1.05), Vector3(0, r * 1.62, -r * 0.06), cloth, Vector3(1.03, 0.62, 1.03))
			var brim := _part(head, _cylinder(r * 0.6, r * 0.6, 0.022), Vector3(0, r * 1.5, r * 0.88), cloth, Vector3(1.0, 1.0, 1.15))
			brim.rotation_degrees = Vector3(8, 0, 0)
			_part(head, _sphere(r * 0.1), Vector3(0, r * 2.27, -r * 0.06), cloth)
		"Bandana":
			_part(head, _sphere(r * 1.07), Vector3(0, r * 1.34, -r * 0.25), cloth, Vector3(1.03, 0.62, 1.0))
			_part(head, _sphere(r * 0.2), Vector3(0, r * 1.05, -r * 1.12), cloth)
			for side in [-1.0, 1.0]:
				var tail := _part(head, _capsule(r * 0.08, r * 0.7), Vector3(side * r * 0.14, r * 0.78, -r * 1.12), cloth)
				tail.rotation_degrees = Vector3(-15, 0, side * 20.0)
			# a scatter of light dots (the paisley print)
			var dot := _flat(Color(0.97, 0.95, 0.9))
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 14:
				var a := rng.randf_range(-2.4, 2.4)
				var up := rng.randf_range(0.35, 0.95)
				var d := Vector3(sin(a) * sqrt(1.0 - up * up), up, cos(a) * sqrt(1.0 - up * up))
				var at := Vector3(0, r * 1.34, -r * 0.25) + Vector3(d.x * 1.03, d.y * 0.62, d.z) * r * 1.07
				if at.y < r * 1.3 and d.z > 0.3:
					continue   # not on the forehead
				_part(head, _sphere(r * 0.032), at, dot, Vector3(1.0, 0.6, 1.0))
		"Sun hat":
			var band := _flat(accent if accent_color.a >= 0.05 else Color(0.2, 0.45, 0.42))
			_part(head, _cylinder(r * 0.78, r * 0.88, r * 0.55), Vector3(0, r * 1.78, -r * 0.05), cloth)
			_part(head, _cylinder(r * 0.89, r * 0.9, r * 0.18), Vector3(0, r * 1.6, -r * 0.05), band)
			_part(head, _cylinder(r * 1.85, r * 1.85, 0.014), Vector3(0, r * 1.52, -r * 0.05), cloth)
		"Beanie":
			_part(head, _sphere(r * 1.06), Vector3(0, r * 1.2, -r * 0.05), cloth, Vector3(1.02, 0.84, 1.02))
			_part(head, _cylinder(r * 1.04, r * 1.06, r * 0.28), Vector3(0, r * 1.08, -r * 0.05), _flat(hat_color.darkened(0.15)))
			_part(head, _sphere(r * 0.2), Vector3(0, r * 2.05, -r * 0.05), cloth)
		"Hard hat":
			_part(head, _sphere(r * 1.1, true), Vector3(0, r * 1.18, 0), cloth, Vector3(1.0, 0.8, 1.05))
			_part(head, _cylinder(r * 1.12, r * 1.12, 0.02), Vector3(0, r * 1.2, r * 0.08), cloth, Vector3(1.0, 1.0, 1.15))
		"Chef hat":
			var white := _flat(Color(0.97, 0.97, 0.95))
			_part(head, _cylinder(r * 0.95, r * 0.95, r * 0.5), Vector3(0, r * 1.75, -r * 0.05), white)
			_part(head, _sphere(r * 1.05), Vector3(0, r * 2.35, -r * 0.05), white, Vector3(1.05, 0.7, 1.05))


## Story people: a thin light rim around the whole silhouette (a hull drawn just
## behind each part), and the emotion glow (two soft, see-through hulls).
func _add_story_shell() -> void:
	_glow_nodes = []
	var parts: Array = []
	for node in PropUtils.descendants(_body):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or _face_parts.values().has(mesh_instance) or _face_root.is_ancestor_of(mesh_instance):
			continue
		parts.append(mesh_instance)
	if outline_color.a >= 0.02:
		var rim := StandardMaterial3D.new()
		rim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rim.cull_mode = BaseMaterial3D.CULL_FRONT
		rim.grow = true
		rim.grow_amount = 0.007
		rim.albedo_color = Color(outline_color.r, outline_color.g, outline_color.b)
		for part in parts:
			var hull := MeshInstance3D.new()
			hull.name = "Rim"
			hull.mesh = (part as MeshInstance3D).mesh
			hull.material_override = rim
			hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(part as Node3D).add_child(hull)
	_glow_material = []
	for layer in [[0.02, 0.5], [0.055, 0.2]]:
		var glow := ShaderMaterial.new()
		glow.shader = GLOW_SHADER
		glow.set_shader_parameter("grow", float(layer[0]))
		glow.set_meta(&"base_alpha", float(layer[1]))
		_glow_material.append(glow)
		for part in parts:
			var hull := MeshInstance3D.new()
			hull.name = "Glow"
			hull.mesh = (part as MeshInstance3D).mesh
			hull.material_override = glow
			hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(part as Node3D).add_child(hull)
			_glow_nodes.append(hull)
	_update_glow()


func _update_glow() -> void:
	var on := glow_amount > 0.01
	for material in _glow_material:
		var m := material as ShaderMaterial
		var a := float(m.get_meta(&"base_alpha", 0.5)) * glow_amount
		m.set_shader_parameter("glow_color", Color(glow_color.r, glow_color.g, glow_color.b, a))
	for node in _glow_nodes:
		if is_instance_valid(node):
			(node as Node3D).visible = on


## A cap worn backwards, in cap_color. Its dome sits back on the head, so the
## head itself hides the part that would cover the eyes.
func _build_cap(head: Node3D, r: float) -> void:
	var cap := _flat(Color(cap_color.r, cap_color.g, cap_color.b))
	_part(head, _sphere(r * 1.04), Vector3(0, r * 1.33, -r * 0.2), cap, Vector3(1.05, 0.7, 1.0))
	var brim := _part(head, _cylinder(r * 0.62, r * 0.62, 0.025), Vector3(0, r * 1.42, -r * 1.05), cap, Vector3(1.0, 1.0, 1.25))
	brim.rotation_degrees = Vector3(-12, 0, 0)
	_part(head, _sphere(r * 0.1), Vector3(0, r * 2.03, -r * 0.2), cap)


## Cartoon hair: a mass that sits back on the big head (the face stays clear) and a
## fringe in front over the forehead, plus each style's own shape.
func _build_hair_cartoon(head: Node3D, r: float) -> void:
	if hair == "None":
		return
	var tone := _flat(hair_color)
	var back := Vector3(0, r * 1.12, -r * 0.14)
	if cap_color.a < 0.05 or hair in ["Long", "Bob", "Ponytail", "Bun"]:
		_part(head, _sphere(r * 1.04), back, tone, Vector3(1.04, 0.84, 0.94))
	match hair:
		"Spiky":
			for k in 7:
				var a := -1.0 + k * 0.333
				var spike := _part(head, _cylinder(0.0, r * 0.2, r * 0.48), Vector3(sin(a) * r * 0.7, r * 1.72 + cos(a) * r * 0.16, -r * 0.05 + cos(a) * r * 0.2), tone)
				spike.rotation_degrees = Vector3(-10.0, 0, -rad_to_deg(a) * 0.85)
			for k in 3:
				var tip := _part(head, _cylinder(0.0, r * 0.16, r * 0.32), Vector3((float(k) - 1.0) * r * 0.32, r * 1.5, r * 0.62), tone)
				tip.rotation_degrees = Vector3(200.0, 0, (float(k) - 1.0) * 25.0)
		"Curl":
			var curl := _part(head, _capsule(r * 0.12, r * 0.55), Vector3(r * 0.1, r * 1.98, 0.0), tone)
			curl.rotation_degrees = Vector3(0, 0, -35)
		"Long":
			_part(head, _capsule(r * 0.95, r * 3.0), Vector3(0, r * 0.45, -r * 0.42), tone, Vector3(1.12, 1.0, 0.55))
		"Bob":
			_part(head, _sphere(r * 1.05), Vector3(0, r * 0.95, -r * 0.3), tone, Vector3(1.1, 0.92, 0.7))
		"Bun":
			_part(head, _sphere(r * 0.42), Vector3(0, r * 2.0, -r * 0.4), tone)
		"Ponytail":
			var tail := _part(head, _capsule(r * 0.28, r * 1.6), Vector3(0, r * 0.95, -r * 1.12), tone, Vector3(1.0, 1.0, 0.8))
			tail.rotation_degrees = Vector3(-28, 0, 0)
			_part(head, _sphere(r * 0.15), Vector3(0, r * 1.45, -r * 1.0), _flat(Color(0.95, 0.35, 0.45)))
	if hair != "Curl" and hair != "Spiky" and cap_color.a < 0.05:
		# The fringe: a soft sweep across the top of the forehead.
		var fringe := _part(head, _capsule(r * 0.24, r * 1.35), Vector3(r * 0.12, r * 1.63, r * 0.6), tone, Vector3(1.0, 1.0, 0.55))
		fringe.rotation_degrees = Vector3(-20, 0, 78)
		var fringe2 := _part(head, _capsule(r * 0.18, r * 0.8), Vector3(-r * 0.45, r * 1.55, r * 0.55), tone, Vector3(1.0, 1.0, 0.55))
		fringe2.rotation_degrees = Vector3(-20, 0, 60)


## The hair cap sits up and back on the head, so the hairline is on the forehead
## and never covers the eyes (whatever angle the camera sees the head from).
const CAP_POS := Vector3(0, 1.2, -0.22)
const CAP_SCALE := Vector3(1.04, 0.76, 0.95)

## Hair for a sketch person, in hair_color (drawn as soft shapes behind the face).
func _build_hair_sketch(head: Node3D, r: float, fill: Material) -> void:
	var tone := _flat(hair_color)
	match hair:
		"None":
			return
		"Curl":
			var curl := _part(head, _capsule(0.022, 0.11), Vector3(0.02, r * 1.95, 0.0), fill)
			curl.rotation_degrees = Vector3(0, 0, -35)
			var curl2 := _part(head, _capsule(0.02, 0.07), Vector3(0.06, r * 1.95 + 0.019, 0.0), fill)
			curl2.rotation_degrees = Vector3(0, 0, 50)
		"Spiky":
			_part(head, _sphere(r * 1.07), CAP_POS * r, tone, CAP_SCALE)
			for k in 6:
				var a := -0.9 + k * 0.36
				var spike := _part(head, _cylinder(0.0, r * 0.22, r * 0.5), Vector3(sin(a) * r * 0.62, r * 1.62 + cos(a) * r * 0.12, r * 0.12 - absf(a) * r * 0.1), tone)
				spike.rotation_degrees = Vector3(-18.0, 0, -rad_to_deg(a) * 0.9)
			var fringe_sp := _part(head, _capsule(r * 0.2, r * 1.2), Vector3(r * 0.1, r * 1.6, r * 0.62), tone, Vector3(1.0, 1.0, 0.55))
			fringe_sp.rotation_degrees = Vector3(0, 0, 75)
		"Ponytail":
			_part(head, _sphere(r * 1.07), CAP_POS * r, tone, CAP_SCALE)
			var fringe_p := _part(head, _capsule(r * 0.3, r * 1.4), Vector3(-r * 0.2, r * 1.55, r * 0.55), tone, Vector3(1.0, 1.0, 0.5))
			fringe_p.rotation_degrees = Vector3(0, 0, -72)
			var tail := _part(head, _capsule(r * 0.28, r * 1.5), Vector3(0, r * 0.95, -r * 1.05), tone, Vector3(1.0, 1.0, 0.8))
			tail.rotation_degrees = Vector3(-30, 0, 0)
			_part(head, _sphere(r * 0.14), Vector3(0, r * 1.42, -r * 0.92), _flat(Color(0.9, 0.3, 0.4)))
		"Short":
			_part(head, _sphere(r * 1.07), CAP_POS * r, tone, CAP_SCALE)
			# A short fringe across the forehead, a little to one side.
			var fringe_s := _part(head, _capsule(r * 0.2, r * 1.3), Vector3(r * 0.12, r * 1.62, r * 0.62), tone, Vector3(1.0, 1.0, 0.55))
			fringe_s.rotation_degrees = Vector3(0, 0, 78)
		"Long", "Bob", "Bun":
			# A cap of hair over the top and back, a fringe, and the length behind.
			_part(head, _sphere(r * 1.07), CAP_POS * r, tone, CAP_SCALE)
			var fringe := _part(head, _capsule(r * 0.32, r * 1.5), Vector3(r * 0.25, r * 1.55, r * 0.55), tone, Vector3(1.0, 1.0, 0.5))
			fringe.rotation_degrees = Vector3(0, 0, 70)
			if hair == "Long":
				_part(head, _capsule(r * 0.88, r * 3.0), Vector3(0, r * 0.35, -r * 0.42), tone, Vector3(1.08, 1.0, 0.55))
			elif hair == "Bob":
				_part(head, _capsule(r * 0.95, r * 2.0), Vector3(0, r * 0.75, -r * 0.3), tone, Vector3(1.12, 1.0, 0.7))
			else:
				_part(head, _sphere(r * 0.42), Vector3(0, r * 2.05, -r * 0.35), tone)


## A shadow's scribbled fur: short dark strokes all over the body, pointing outwards.
## They "boil" (shift a little, a few times a second) like a hand-drawn scribble.
func _add_fur(fill: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) + 11
	var parts: Array = []
	for node in PropUtils.descendants(_body):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance and not _face_parts.values().has(mesh_instance) and not str(mesh_instance.name).begins_with("Halo"):
			parts.append(mesh_instance)
	for part in parts:
		var holder := (part as Node3D).get_parent() as Node3D
		var aabb := (part as MeshInstance3D).get_aabb()
		var centre := (part as Node3D).position + aabb.get_center() * (part as Node3D).scale
		var size := aabb.size * (part as Node3D).scale
		var count := int(clampf((size.x + size.y) * 70.0, 6.0, 40.0))
		for i in count:
			var a := rng.randf() * TAU
			var y := rng.randf_range(-0.5, 0.5) * size.y
			var out := Vector3(cos(a) * size.x * 0.5, y, sin(a) * size.z * 0.5)
			var stroke := MeshInstance3D.new()
			stroke.mesh = _capsule(0.012, rng.randf_range(0.07, 0.15))
			stroke.material_override = fill
			stroke.position = centre + out * 0.9
			var base := Vector3(rng.randf_range(-70, 70), rng.randf_range(0, 360), rad_to_deg(-a) + rng.randf_range(60, 120))
			stroke.rotation_degrees = base
			stroke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(stroke)
			_fur.append([stroke, base, rng.randf() * 100.0])


func _boil(t: float) -> void:
	if _fur.is_empty():
		return
	var frame := floorf(t * 8.0)    # eight drawings a second, like hand animation
	for entry in _fur:
		var stroke := entry[0] as MeshInstance3D
		if not is_instance_valid(stroke):
			continue
		var s := float(entry[2]) + frame * 1.7
		stroke.rotation_degrees = (entry[1] as Vector3) + Vector3(sin(s) * 14.0, 0, cos(s * 1.3) * 14.0)


## Face parts: lines and dots that the expressions move around.
func _build_face(r: float, shadow: bool) -> void:
	var line := _line_material
	var z := r * 0.93
	for side in ["l", "r"]:
		_face_parts["pupil_" + side] = _part(_face_root, _sphere(0.018), Vector3.ZERO, line, Vector3(1.0, 1.15, 0.4))
		_face_parts["lid_" + side] = _part(_face_root, _capsule(0.007, 0.07), Vector3.ZERO, line, Vector3.ONE, Vector3(0, 0, 90))
		_face_parts["brow_" + side] = _part(_face_root, _capsule(0.007, 0.065), Vector3.ZERO, line, Vector3.ONE, Vector3(0, 0, 90))
		_face_parts["arc_" + side + "1"] = _part(_face_root, _capsule(0.007, 0.04), Vector3.ZERO, line)
		_face_parts["arc_" + side + "2"] = _part(_face_root, _capsule(0.007, 0.04), Vector3.ZERO, line)
	for i in 4:
		_face_parts["mouth_%d" % i] = _part(_face_root, _capsule(0.007, 0.034), Vector3.ZERO, line, Vector3.ONE, Vector3(0, 0, 90))
	_face_parts["mouth_open"] = _part(_face_root, _sphere(0.025), Vector3.ZERO, line, Vector3(1.0, 1.0, 0.3))
	if not shadow:
		var blush := StandardMaterial3D.new()
		blush.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		blush.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		blush.albedo_color = Color(1.0, 0.45, 0.45, 0.45)
		var tear := _flat(Color(0.45, 0.7, 1.0))
		for side in ["l", "r"]:
			_face_parts["cheek_" + side] = _part(_face_root, _sphere(0.026), Vector3.ZERO, blush, Vector3(1.3, 0.75, 0.2))
			_face_parts["tear_" + side] = _part(_face_root, _sphere(0.011), Vector3.ZERO, tear, Vector3(1.0, 1.7, 0.4))
	var layers := {}
	if figure == "Story":
		# White eyes (no pupils) that black lids cut into; light lines for brows and mouth.
		# Unshaded: the eyes stay white in any light (as drawn), like the films.
		var white := _plain(Color(0.98, 0.98, 0.96))
		var lid_fill := _plain(body_color)
		var brow_mat := _plain(line_color.darkened(0.35))
		var story_line := _plain(line_color)
		for key in _face_parts:
			(_face_parts[key] as MeshInstance3D).material_override = story_line
		for side in ["l", "r"]:
			_face_parts["sclera_" + side] = _part(_face_root, _sphere(0.03), Vector3.ZERO, white, Vector3(0.82, 1.22, 0.3))
			_face_parts["eyelid_" + side] = _part(_face_root, _sphere(0.034), Vector3.ZERO, lid_fill, Vector3(1.1, 1.0, 0.3))
			(_face_parts["pupil_" + side] as MeshInstance3D).visible = false
			(_face_parts["brow_" + side] as MeshInstance3D).material_override = brow_mat
			layers["sclera_" + side] = 0.0
			layers["eyelid_" + side] = 0.01
			layers["lid_" + side] = 0.016
			layers["brow_" + side] = 0.01
			layers["arc_" + side + "1"] = 0.012
			layers["arc_" + side + "2"] = 0.012
		_face_parts["mouth_open"].material_override = _plain(Color(0.86, 0.84, 0.82))
		for side in ["l", "r"]:
			if _face_parts.has("tear_" + side):
				(_face_parts["tear_" + side] as MeshInstance3D).material_override = _plain(Color(0.6, 0.82, 1.0))
		for key in _face_parts:
			if str(key).begins_with("lid_") or str(key).begins_with("arc_") or (str(key).begins_with("mouth_") and key != "mouth_open"):
				(_face_parts[key] as MeshInstance3D).scale = Vector3(1.3, 1.0, 1.3)
		z = 0.19 * (1.04 if lit else 1.28)
	elif figure == "Cartoon":
		# Big cartoon eyes: whites, dark pupils with a shine, skin-coloured lids;
		# a red mouth with teeth and a tongue; a little nose.
		var white := _flat(Color(0.99, 0.99, 0.98))
		var skin := _flat(body_color)
		var iris := _flat(Color(0.16, 0.1, 0.07))
		for side in ["l", "r"]:
			_face_parts["sclera_" + side] = _part(_face_root, _sphere(0.039), Vector3.ZERO, white, Vector3(0.88, 1.2, 0.3))
			_face_parts["hl_" + side] = _part(_face_root, _sphere(0.0065), Vector3.ZERO, white, Vector3(1.0, 1.0, 0.4))
			_face_parts["eyelid_" + side] = _part(_face_root, _sphere(0.04), Vector3.ZERO, skin, Vector3(1.0, 1.2, 0.3))
			(_face_parts["pupil_" + side] as MeshInstance3D).material_override = iris
			(_face_parts["pupil_" + side] as MeshInstance3D).mesh = _sphere(0.023)
			layers["sclera_" + side] = 0.0
			layers["pupil_" + side] = 0.008
			layers["hl_" + side] = 0.016
			layers["eyelid_" + side] = 0.02
			layers["lid_" + side] = 0.026
			layers["brow_" + side] = 0.01
			layers["arc_" + side + "1"] = 0.012
			layers["arc_" + side + "2"] = 0.012
		_face_parts["mouth_open"].material_override = _flat(Color(0.48, 0.12, 0.14))
		_face_parts["teeth"] = _part(_face_root, _capsule(0.008, 0.05), Vector3.ZERO, white, Vector3(1.0, 1.0, 0.4), Vector3(0, 0, 90))
		_face_parts["tongue"] = _part(_face_root, _sphere(0.016), Vector3.ZERO, _flat(Color(0.93, 0.45, 0.48)), Vector3(1.3, 0.7, 0.3))
		_face_parts["nose"] = _part(_face_root, _sphere(0.016), Vector3(0, -0.028, 0), _flat(body_color.darkened(0.08)), Vector3(1.1, 0.85, 0.6))
		# A skin-coloured face under the features: when the head turns three-quarters
		# away, the face still reads (the hair doesn't cover it), like a drawn cartoon.
		_face_parts["plate"] = _part(_face_root, _sphere(0.1), Vector3(0, -0.022, 0), skin, Vector3(1.3, 1.05, 0.2))
		layers["plate"] = -0.03
		layers["mouth_open"] = 0.004
		layers["teeth"] = 0.01
		layers["tongue"] = 0.01
		layers["nose"] = 0.006
		# Thicker lines than the sketch face.
		for key in _face_parts:
			if str(key).begins_with("brow_") or str(key).begins_with("lid_") or str(key).begins_with("arc_") or str(key).begins_with("mouth_") and key != "mouth_open":
				(_face_parts[key] as MeshInstance3D).scale = Vector3(1.55, 1.0, 1.55)
		# The face sits in front of the hair even when the head turns side-on (the
		# camera always sees the drawn face, like a cartoon).
		z = 0.19 * (1.06 if lit else 1.28)
	for key in _face_parts:
		(_face_parts[key] as MeshInstance3D).position.z = z + float(layers.get(key, 0.0))
		(_face_parts[key] as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A soft halo around a shadow figure: the body drawn again a little bigger and
## see-through in the glow colour, twice.
func _add_halo() -> void:
	var glow := glow_color
	for layer in [[0.04, 0.45], [0.11, 0.16]]:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(glow.r, glow.g, glow.b, float(layer[1]))
		material.cull_mode = BaseMaterial3D.CULL_FRONT
		material.grow = true
		material.grow_amount = float(layer[0])
		material.no_depth_test = false
		material.render_priority = -1
		for node in PropUtils.descendants(_body):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance == null or _face_parts.values().has(mesh_instance) or str(mesh_instance.name).begins_with("Halo"):
				continue
			var halo := MeshInstance3D.new()
			halo.name = "Halo"
			halo.mesh = mesh_instance.mesh
			halo.material_override = material
			halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh_instance.add_child(halo)


## In the Realistic look (1.21) drawn and cartoon people are lit like the world around
## them (soft, slightly glossy, with a rim of light), and their faces sit on the front
## of the head and turn towards the camera like an actor cheating to the lens.
static var lit := true
## The camera a video is being rendered with (set by the exporter): faces turn to it.
## Without it, faces turn to the camera of the view they're shown in.
static var render_camera: Camera3D = null


## Turns the face to the camera now (the exporter calls this after placing its camera
## for a frame, so faces never lag a frame behind a cut).
func aim_face_now() -> void:
	_aim_face()


static func _plain(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if lit:
		material.roughness = 0.62
		material.metallic_specular = 0.35
		material.rim_enabled = true
		material.rim = 0.35
		material.rim_tint = 0.4
		# A soft fill light of their own, so a face is never lost in shadow.
		material.emission_enabled = true
		material.emission = color * 0.3
	else:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


# --- Face ----------------------------------------------------------------------

## The face looks towards the camera side (+Z) and leans towards where the
## character faces, like a drawn face on a turned head.
func _aim_face() -> void:
	if _face_root == null or not _face_root.is_inside_tree() or _body == null:
		return
	var head := _face_root.get_parent() as Node3D
	var body_rot := _body.global_basis.orthonormalized()
	var head_rot := head.global_basis.orthonormalized()
	var lean := clampf(body_rot.z.x, -1.0, 1.0)
	_face_lean = lean
	# Nod and tilt with the head (relative to the body), but always face the camera side.
	var relative := (body_rot.inverse() * head_rot).get_euler()
	var desired := Basis.from_euler(Vector3(relative.x * 0.7, lean * (0.12 if figure == "Cartoon" else 0.25), relative.z * 0.7))
	var camera: Camera3D = null
	if lit:
		camera = render_camera if is_instance_valid(render_camera) else get_viewport().get_camera_3d()
	if camera != null:
		# Lit 3D: the face is on the front of the head, turned part of the way to the camera.
		var forward := Vector2(body_rot.z.x, body_rot.z.z)
		var to_camera := Vector2(camera.global_position.x - head.global_position.x, camera.global_position.z - head.global_position.z)
		if forward.length() > 0.01 and to_camera.length() > 0.01:
			var body_yaw := atan2(forward.x, forward.y)
			var diff := wrapf(atan2(to_camera.x, to_camera.y) - body_yaw, -PI, PI)
			var yaw := body_yaw + clampf(diff, -1.2, 1.2) * 0.72
			desired = Basis(Vector3.UP, yaw) * Basis.from_euler(Vector3(relative.x * 0.7, 0.0, relative.z * 0.7))
			# (story people: no face on the back of the head)
			_face_root.visible = absf(diff) < (1.75 if figure == "Story" else 2.05)
		_face_root.basis = (head_rot.inverse() * desired) * Basis.from_scale(Vector3.ONE * _face_scale)
		var offset := desired * Vector3(0, 0, 0)
		_face_root.position = Vector3(0, _face_y, 0) + head_rot.inverse() * offset
		return
	if figure == "Cartoon":
		# Seen from behind, a cartoon person shows the back of their head.
		_face_root.visible = body_rot.z.z > -0.8
	_face_root.basis = (head_rot.inverse() * desired) * Basis.from_scale(Vector3.ONE * _face_scale)
	_face_root.position = Vector3(0, _face_y, 0) + head_rot.inverse() * Vector3(lean * 0.03, 0, 0)


## The face shapes of each expression (numbers the drawing eases between).
static func _expression_params(e: String) -> Dictionary:
	var eye_y := 0.015
	var p := {"pupil_y": eye_y, "pupil_scale": 1.0, "pupil": 1.0, "lid": 0.0, "lid_y": eye_y + 0.012, "lid_tilt": 0.0,
		"arcs": 0.0, "arcs_down": 0.0, "brow_y": eye_y + 0.055, "brow_tilt": 0.0, "mouth_curve": 0.0, "mouth_y": -0.075,
		"mouth_width": 0.07, "mouth_open": 0.0, "smirk": 0.0, "cheeks": 0.0, "tears": 0.0, "look_x": 0.0, "grin": 0.0}
	match e:
		"Tired":
			p.merge({"lid": 1.0, "lid_y": eye_y + 0.006, "pupil_y": eye_y - 0.006, "brow_y": eye_y + 0.045, "mouth_width": 0.05}, true)
		"Sad":
			p.merge({"brow_tilt": 18.0, "mouth_curve": -0.018, "pupil_y": eye_y - 0.004}, true)
		"Ashamed":
			p.merge({"brow_tilt": 22.0, "lid": 1.0, "lid_y": eye_y + 0.004, "pupil_y": eye_y - 0.012, "mouth_curve": -0.01, "mouth_width": 0.04, "look_x": -0.008}, true)
		"Scared":
			p.merge({"brow_tilt": 15.0, "brow_y": eye_y + 0.07, "pupil_scale": 0.7, "mouth_open": 0.6}, true)
		"Shocked":
			p.merge({"brow_y": eye_y + 0.08, "pupil_scale": 0.65, "mouth_open": 1.0}, true)
		"Angry":
			p.merge({"brow_tilt": -22.0, "brow_y": eye_y + 0.04, "mouth_curve": -0.014}, true)
		"Determined":
			p.merge({"brow_tilt": -12.0, "brow_y": eye_y + 0.045, "lid": 1.0, "lid_y": eye_y + 0.014, "lid_tilt": -8.0, "mouth_width": 0.06}, true)
		"Happy":
			p.merge({"arcs": 1.0, "pupil": 0.0, "mouth_curve": 0.022, "brow_y": eye_y + 0.06, "cheeks": 1.0}, true)
		"Smirk":
			p.merge({"lid": 1.0, "lid_y": eye_y + 0.004, "lid_tilt": 6.0, "pupil_y": eye_y - 0.004, "smirk": 0.02, "mouth_curve": 0.012, "brow_tilt": -8.0}, true)
		"Crying":
			p.merge({"brow_tilt": 24.0, "lid": 1.0, "lid_y": eye_y + 0.005, "pupil_y": eye_y - 0.008, "mouth_curve": -0.024,
				"mouth_width": 0.06, "tears": 1.0, "cheeks": 0.6}, true)
		"Asleep":
			p.merge({"pupil": 0.0, "arcs_down": 1.0, "brow_y": eye_y + 0.045, "mouth_width": 0.035, "mouth_curve": 0.004}, true)
		"Proud":
			p.merge({"arcs": 1.0, "pupil": 0.0, "mouth_curve": 0.016, "smirk": 0.008, "brow_y": eye_y + 0.058, "brow_tilt": -4.0, "cheeks": 0.7}, true)
		"Hopeful":
			p.merge({"brow_tilt": 10.0, "brow_y": eye_y + 0.066, "pupil_y": eye_y + 0.006, "pupil_scale": 1.1, "mouth_curve": 0.01, "mouth_width": 0.05, "cheeks": 0.4}, true)
		"Worried":
			p.merge({"brow_tilt": 20.0, "brow_y": eye_y + 0.062, "pupil_scale": 0.85, "mouth_curve": -0.008, "mouth_width": 0.045, "look_x": 0.01}, true)
		"Laughing":
			p.merge({"arcs": 1.0, "pupil": 0.0, "mouth_open": 0.7, "mouth_curve": 0.012, "mouth_width": 0.085, "grin": 1.0, "brow_y": eye_y + 0.066, "cheeks": 1.0}, true)
	return p


## Places eyes, brows and mouth for expression [param index]; [param open] (0..1)
## opens the mouth for talking / lip sync. While playing, the face eases from
## the last expression to the new one (brows rise, the mouth curves) instead of
## jumping.
func _show_expression(index: int, open: float, blink: bool = false) -> void:
	if _face_parts.is_empty():
		return
	var e: String = EXPRESSIONS[clampi(index, 0, EXPRESSIONS.size() - 1)]
	var target := _expression_params(e)
	if figure == "Cartoon":
		# Cartoon faces act bigger: a happy face is a big open grin.
		match e:
			"Happy":
				target.merge({"mouth_open": 0.55, "grin": 0.85, "mouth_width": 0.09, "mouth_curve": 0.016, "cheeks": 0.5}, true)
			"Proud":
				target.merge({"mouth_open": 0.35, "grin": 0.7, "mouth_width": 0.08}, true)
			"Shocked", "Scared":
				target.merge({"mouth_open": 0.85}, true)
	if open > 0.05:
		target["mouth_open"] = maxf(float(target["mouth_open"]), open)
	if _params.is_empty() or _ease >= 0.999:
		_params = target.duplicate()
	else:
		for k in target:
			_params[k] = lerpf(float(_params.get(k, target[k])), float(target[k]), _ease)
	var p := _params
	var eye_x := 0.06
	var eye_y := 0.015
	var pupil_show := float(p["pupil"]) > 0.5
	var lid_show := float(p["lid"]) > 0.5
	var lid_y := float(p["lid_y"])
	var lid_tilt := float(p["lid_tilt"])
	var arcs := float(p["arcs"]) > 0.5
	var arcs_down := float(p["arcs_down"]) > 0.5
	if blink and not arcs and not arcs_down:
		pupil_show = false
		lid_show = true
		lid_y = eye_y
		lid_tilt = 0.0
	var brow_tilt := float(p["brow_tilt"])
	for s in [-1.0, 1.0]:
		var side := "l" if s < 0.0 else "r"
		var pupil_node: MeshInstance3D = _face_parts["pupil_" + side]
		pupil_node.visible = pupil_show
		pupil_node.position.x = s * eye_x + float(p["look_x"])
		pupil_node.position.y = float(p["pupil_y"])
		pupil_node.scale = Vector3(1.0, 1.15, 0.4) * float(p["pupil_scale"])
		var lid_node: MeshInstance3D = _face_parts["lid_" + side]
		lid_node.visible = lid_show
		lid_node.position.x = s * eye_x
		lid_node.position.y = lid_y
		lid_node.rotation_degrees = Vector3(0, 0, 90.0 + s * lid_tilt)
		var brow: MeshInstance3D = _face_parts["brow_" + side]
		brow.position.x = s * (eye_x + 0.004)
		brow.position.y = float(p["brow_y"])
		# The inner end is towards the middle: tilting "inner up" rotates opposite per side.
		brow.rotation_degrees = Vector3(0, 0, 90.0 - s * brow_tilt)
		var a1: MeshInstance3D = _face_parts["arc_" + side + "1"]
		var a2: MeshInstance3D = _face_parts["arc_" + side + "2"]
		a1.visible = arcs or arcs_down
		a2.visible = arcs or arcs_down
		a1.position = Vector3(s * eye_x - 0.013, eye_y, a1.position.z)
		a2.position = Vector3(s * eye_x + 0.013, eye_y, a2.position.z)
		var turn := -55.0 if arcs else 55.0      # ^ for happy, v for closed sleepy eyes
		a1.rotation_degrees = Vector3(0, 0, turn)
		a2.rotation_degrees = Vector3(0, 0, -turn)
		if _face_parts.has("cheek_" + side):
			var cheek: MeshInstance3D = _face_parts["cheek_" + side]
			cheek.visible = float(p["cheeks"]) > 0.05
			cheek.position = Vector3(s * (eye_x + 0.025), eye_y - 0.035, cheek.position.z)
			cheek.scale = Vector3(1.3, 0.75, 0.2) * clampf(float(p["cheeks"]), 0.0, 1.0)
			var tear: MeshInstance3D = _face_parts["tear_" + side]
			tear.visible = float(p["tears"]) > 0.5
			# Tears roll down the cheek (time comes from the blink clock).
			var fall := fposmod(_last_t * 0.9 + (0.0 if s < 0.0 else 0.45), 1.0)
			tear.position = Vector3(s * (eye_x + 0.006), eye_y - 0.02 - fall * 0.05, tear.position.z)
			tear.scale = Vector3(1.0, 1.7, 0.4) * (1.0 - fall * 0.5)
	# Mouth: four short segments along a curve, or an open oval.
	var mouth_open := float(p["mouth_open"])
	var mouth_y := float(p["mouth_y"])
	var mouth_width := float(p["mouth_width"])
	var mouth_curve := float(p["mouth_curve"])
	var smirk := float(p["smirk"])
	var open_node: MeshInstance3D = _face_parts["mouth_open"]
	open_node.visible = mouth_open > 0.05
	# A laugh is a wide "D": the open mouth hangs under a smiling top lip.
	var grin := float(p.get("grin", 0.0))
	open_node.position = Vector3(0, mouth_y - 0.004 - grin * 0.012, open_node.position.z)
	open_node.scale = Vector3(0.8 + mouth_open * 0.2 + grin * 0.75, (0.35 + mouth_open * 0.9) * (1.0 - grin * 0.25), 0.3)
	for i in 4:
		var seg: MeshInstance3D = _face_parts["mouth_%d" % i]
		seg.visible = mouth_open <= 0.05 or grin > 0.5
		var f := (float(i) + 0.5) / 4.0 * 2.0 - 1.0        # -0.75 .. 0.75
		var x := f * mouth_width * 0.5
		var y := mouth_y + mouth_curve * (f * f) + smirk * maxf(f, 0.0)
		var slope := mouth_curve * 2.0 * f / maxf(mouth_width * 0.5, 0.001) + (smirk / maxf(mouth_width * 0.5, 0.001) if f > 0.0 else 0.0)
		seg.position = Vector3(x, y, seg.position.z)
		seg.rotation_degrees = Vector3(0, 0, 90.0 + rad_to_deg(atan(slope * 0.5)))
		(seg.mesh as CapsuleMesh).height = maxf(mouth_width / 4.0 + 0.012, 0.014)
	if figure == "Story":
		_show_story_eyes(p, eye_x, eye_y, pupil_show, lid_show, lid_y, lid_tilt)
	if figure == "Cartoon":
		_show_cartoon_eyes(p, eye_x, eye_y, pupil_show, lid_show, lid_y, lid_tilt)
		var open_h := 0.025 * (0.35 + mouth_open * 0.9) * (1.0 - grin * 0.25)
		var open_w := 0.025 * (0.8 + mouth_open * 0.2 + grin * 0.75)
		var teeth: MeshInstance3D = _face_parts["teeth"]
		teeth.visible = open_node.visible and (mouth_open > 0.3 or grin > 0.5)
		teeth.position = Vector3(0, open_node.position.y + open_h * 0.62, teeth.position.z)
		teeth.scale = Vector3(1.0, open_w / 0.03, 0.4)
		var tongue: MeshInstance3D = _face_parts["tongue"]
		tongue.visible = open_node.visible and mouth_open > 0.25
		tongue.position = Vector3(open_w * 0.15, open_node.position.y - open_h * 0.5, tongue.position.z)
		tongue.scale = Vector3(1.3 * open_w / 0.03, 0.7, 0.3)


## Story eyes: white ovals that look around a little; a black lid cuts the top
## off for tired, sad or ashamed eyes; closed eyes are light lines.
func _show_story_eyes(p: Dictionary, eye_x: float, eye_y: float, pupil_show: bool, lid_show: bool, lid_y: float, lid_tilt: float) -> void:
	var size := sqrt(clampf(float(p["pupil_scale"]), 0.5, 1.4))
	for s in [-1.0, 1.0]:
		var side := "l" if s < 0.0 else "r"
		var sclera: MeshInstance3D = _face_parts["sclera_" + side]
		var eyelid: MeshInstance3D = _face_parts["eyelid_" + side]
		var lid: MeshInstance3D = _face_parts["lid_" + side]
		(_face_parts["pupil_" + side] as MeshInstance3D).visible = false
		sclera.visible = pupil_show
		sclera.position = Vector3(s * eye_x + float(p["look_x"]) * 0.7, eye_y + (float(p["pupil_y"]) - eye_y) * 0.7, sclera.position.z)
		sclera.scale = Vector3(0.82, 1.22, 0.3) * size
		var half_closed := pupil_show and lid_show
		eyelid.visible = half_closed
		eyelid.position = Vector3(s * eye_x, lid_y + 0.03, eyelid.position.z)
		eyelid.rotation_degrees = Vector3(0, 0, s * lid_tilt)
		lid.visible = lid_show and not pupil_show
		if not pupil_show:
			lid.position.y = eye_y - 0.004
		if _face_parts.has("cheek_" + side):
			(_face_parts["cheek_" + side] as Node3D).visible = false


## Cartoon eyes: whites and pupils (with a shine) when open; a skin lid comes down
## for tired, ashamed or smirking eyes; closed eyes are the drawn arcs or lid line.
func _show_cartoon_eyes(p: Dictionary, eye_x: float, eye_y: float, pupil_show: bool, lid_show: bool, lid_y: float, lid_tilt: float) -> void:
	for s in [-1.0, 1.0]:
		var side := "l" if s < 0.0 else "r"
		var sclera: MeshInstance3D = _face_parts["sclera_" + side]
		var pupil: MeshInstance3D = _face_parts["pupil_" + side]
		var shine: MeshInstance3D = _face_parts["hl_" + side]
		var eyelid: MeshInstance3D = _face_parts["eyelid_" + side]
		var lid: MeshInstance3D = _face_parts["lid_" + side]
		sclera.visible = pupil_show
		sclera.position = Vector3(s * eye_x, eye_y, sclera.position.z)
		# Pupils move further inside the bigger eye.
		pupil.position.x = s * eye_x + float(p["look_x"]) * 1.4
		pupil.position.y = eye_y + (float(p["pupil_y"]) - eye_y) * 1.6 - 0.002
		shine.visible = pupil_show
		shine.position = Vector3(pupil.position.x + 0.007, pupil.position.y + 0.009, shine.position.z)
		var half_closed := pupil_show and lid_show
		eyelid.visible = half_closed
		eyelid.position = Vector3(s * eye_x, lid_y + 0.046, eyelid.position.z)
		eyelid.rotation_degrees = Vector3(0, 0, s * lid_tilt)
		if half_closed:
			lid.position.y = lid_y
		elif lid_show:
			lid.position.y = eye_y - 0.004


## Sketch figures blink with a lid line and talk with an open mouth (see evaluate).
func _animate_face(_t: float, _action: String, _since: float) -> void:
	pass

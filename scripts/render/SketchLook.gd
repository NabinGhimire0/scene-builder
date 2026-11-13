class_name SketchLook
extends RefCounted
## The flat looks: flat colours without shading and a drawn outline around every
## object. "Flat sketch" has a black void behind and soft glows; "Paper" is ink on
## warm paper, with a faint paper grain over the whole picture. See
## EnvironmentController (look) and the Sketch Stage location.

const LOOK := "Flat sketch"
const PAPER := "Paper"
const CARTOON := "Cartoon"
const SKETCHBOOK := "Sketchbook"
const LOOKS: PackedStringArray = [LOOK, PAPER, CARTOON, SKETCHBOOK]
## Colours of each flat look: background, outline, text drawn over the film,
## vignette tint, and the paper grain strength.
const PALETTES := {
	"Flat sketch": {"background": Color(0.035, 0.035, 0.04), "line": Color(0.62, 0.6, 0.57), "thickness": 1.6,
		"text": Color(0.92, 0.9, 0.86), "text_outline": Color(0, 0, 0), "vignette": Color(0, 0, 0, 0.8), "grain": 0.0, "dark": true},
	"Paper": {"background": Color(0.93, 0.89, 0.79), "line": Color(0.16, 0.14, 0.13), "thickness": 2.0,
		"text": Color(0.14, 0.12, 0.11), "text_outline": Color(0.97, 0.95, 0.89), "vignette": Color(0.42, 0.3, 0.17, 0.42), "grain": 1.0, "dark": false},
	# Bright cartoon: blue sky and green grass outdoors (see CartoonWorld), coloured
	# walls indoors, vivid colours and a bold dark outline.
	"Cartoon": {"background": Color(0.36, 0.66, 0.88), "line": Color(0.12, 0.09, 0.1), "thickness": 2.6,
		"text": Color(1, 1, 1), "text_outline": Color(0.08, 0.06, 0.1), "vignette": Color(0.05, 0.05, 0.12, 0.08), "grain": 0.0, "dark": false, "cartoon": true},
	# Sketchbook: graphite pencil on white drawing paper, soft watercolour washes, and
	# lines that "boil" (wobble a little, a few times a second) like hand-drawn frames.
	"Sketchbook": {"background": Color(0.975, 0.965, 0.94), "line": Color(0.11, 0.1, 0.13), "thickness": 2.5,
		"text": Color(0.14, 0.12, 0.11), "text_outline": Color(0.97, 0.95, 0.89), "vignette": Color(0.38, 0.32, 0.26, 0.14), "grain": 0.9, "dark": false, "boil": 1.0},
}
const OUTLINE_SHADER := preload("res://assets/materials/sketch_outline.gdshader")
const BACKGROUND := Color(0.035, 0.035, 0.04)
const LINE := Color(0.62, 0.6, 0.57)
const META := &"sketch_flat"


## A quad that draws the outlines over the whole screen, for whichever camera renders.
static func palette(look: String) -> Dictionary:
	return PALETTES.get(look, PALETTES[LOOK])


static func make_outline(color: Color = LINE) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	quad.name = "SketchOutline"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1, 1)
	mesh.flip_faces = true
	quad.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("line_color", color)
	material.set_shader_parameter("depth_minus_one_to_one", RenderingServer.get_rendering_device() == null)
	material.render_priority = 100
	quad.material_override = material
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.layers = 1
	return quad


## Sets the outline quad's colours for [param look].
static func style_outline(quad: MeshInstance3D, look: String) -> void:
	var material := quad.material_override as ShaderMaterial
	if material == null:
		return
	var colors := palette(look)
	material.set_shader_parameter("line_color", colors["line"])
	material.set_shader_parameter("thickness", colors["thickness"])
	material.set_shader_parameter("paper", colors["grain"])
	material.set_shader_parameter("boil", float(colors.get("boil", 0.0)))


## Flat, unshaded colours for every object under [param root] (sketch characters
## and glows draw themselves). Colours are kept, slightly muted.
static func flatten(root: Node, vivid: bool = false, pastel: bool = false) -> void:
	# The sketch props are already coloured for this look; others get muted
	# (except in the bright Cartoon look, where everything keeps its colour).
	var path := str(root.get_meta(PropUtils.META_SCENE_PATH, ""))
	var drawn := vivid or path.begins_with("res://assets/props/sketch/")
	for node in PropUtils.descendants(root):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.has_meta(META):
			continue
		if _inside_sketch_character(mesh_instance, root):
			continue
		var originals: Array = []
		for i in mesh_instance.mesh.get_surface_count():
			originals.append(mesh_instance.get_surface_override_material(i))
		mesh_instance.set_meta(META, {"override": mesh_instance.material_override, "surfaces": originals,
			"shadow": mesh_instance.cast_shadow})
		for i in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_surface_override_material(i)
			if source == null:
				source = mesh_instance.mesh.surface_get_material(i)
			if mesh_instance.material_override:
				source = mesh_instance.material_override
			var base := source as BaseMaterial3D
			if base and base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				continue
			var flat := StandardMaterial3D.new()
			flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var color := Color(0.5, 0.5, 0.5)
			if base:
				color = base.albedo_color
				flat.albedo_texture = base.albedo_texture
				if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					flat.transparency = base.transparency
				if base.emission_enabled:
					color = base.emission * maxf(base.emission_energy_multiplier, 1.0)
			flat.albedo_color = wash(color) if pastel else (color if drawn else muted(color))
			# Ground washes ("groundwash…" meshes): no depth, so the pencil line doesn't
			# scribble along the far edge or at grazing angles; things on them keep theirs.
			if str(mesh_instance.name).to_lower().begins_with("groundwash"):
				flat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				flat.render_priority = -1
			mesh_instance.set_surface_override_material(i, flat)
		mesh_instance.material_override = null
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Undoes [method flatten]: the original materials come back (Realistic look).
static func unflatten(root: Node) -> void:
	for node in PropUtils.descendants(root):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or not mesh_instance.has_meta(META):
			continue
		var saved: Variant = mesh_instance.get_meta(META)
		mesh_instance.remove_meta(META)
		if not saved is Dictionary:
			continue
		var surfaces: Array = saved.get("surfaces", [])
		for i in mini(surfaces.size(), mesh_instance.mesh.get_surface_count() if mesh_instance.mesh else 0):
			mesh_instance.set_surface_override_material(i, surfaces[i])
		mesh_instance.material_override = saved.get("override")
		mesh_instance.cast_shadow = int(saved.get("shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_ON))


## A watercolour wash: lighter and a little softer, like paint on white paper.
static func wash(color: Color) -> Color:
	var c := color
	var grey := c.get_luminance()
	c = Color(lerpf(c.r, grey, 0.1), lerpf(c.g, grey, 0.1), lerpf(c.b, grey, 0.1), c.a)
	return Color(lerpf(c.r, 1.0, 0.1), lerpf(c.g, 0.99, 0.1), lerpf(c.b, 0.96, 0.1), c.a)


## A drawn colour: a little darker and less saturated, like ink-and-wash.
static func muted(color: Color) -> Color:
	var c := color
	var grey := c.get_luminance()
	c = Color(lerpf(c.r, grey, 0.25), lerpf(c.g, grey, 0.25), lerpf(c.b, grey, 0.25), c.a)
	return Color(c.r * 0.72, c.g * 0.72, c.b * 0.72, c.a)


static func _inside_sketch_character(node: Node, stop: Node) -> bool:
	var n := node
	while n and n != stop.get_parent():
		if n is SketchCharacter or n is GlowSpot:
			return true
		n = n.get_parent()
	return false

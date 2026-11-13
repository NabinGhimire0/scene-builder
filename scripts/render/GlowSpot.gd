class_name GlowSpot
extends Node3D
## A soft pool of light for the Flat sketch look (a lamp's glow, a phone's glow
## on a face, a red aura): a round, fading disc that always faces the camera.

@export var glow_color := Color(1.0, 0.72, 0.38):
	set(v):
		glow_color = v
		_refresh()
## Diameter in metres.
@export_range(0.2, 12.0, 0.05) var glow_size := 2.2:
	set(v):
		glow_size = v
		_refresh()
@export_range(0.0, 2.0, 0.01) var strength := 0.55:
	set(v):
		strength = v
		_refresh()

var _quad: MeshInstance3D
static var _texture: GradientTexture2D


func _ready() -> void:
	_refresh()


func get_custom_state() -> Dictionary:
	return {"glow_color": [glow_color.r, glow_color.g, glow_color.b], "glow_size": glow_size, "strength": strength}


func set_custom_state(state: Dictionary) -> void:
	var c: Variant = state.get("glow_color")
	if c is Array and (c as Array).size() >= 3:
		glow_color = Color(float(c[0]), float(c[1]), float(c[2]))
	glow_size = float(state.get("glow_size", glow_size))
	strength = float(state.get("strength", strength))


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _quad == null:
		_quad = MeshInstance3D.new()
		_quad.name = "Glow"
		_quad.mesh = QuadMesh.new()
		_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_quad)
	(_quad.mesh as QuadMesh).size = Vector2(glow_size, glow_size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.albedo_texture = _gradient()
	material.albedo_color = Color(glow_color.r * strength, glow_color.g * strength, glow_color.b * strength, 1.0)
	material.render_priority = 50
	_quad.material_override = material


static func _gradient() -> GradientTexture2D:
	if _texture:
		return _texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.35, Color(1, 1, 1, 0.45))
	gradient.add_point(0.7, Color(1, 1, 1, 0.08))
	_texture = GradientTexture2D.new()
	_texture.gradient = gradient
	_texture.fill = GradientTexture2D.FILL_RADIAL
	_texture.fill_from = Vector2(0.5, 0.5)
	_texture.fill_to = Vector2(1.0, 0.5)
	_texture.width = 256
	_texture.height = 256
	return _texture

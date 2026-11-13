class_name LightProp
extends ProceduralProp
## A placeable light for interiors, stages and night scenes: a bulb (glows in
## all directions), a spotlight (a cone; rotate the object to aim it) or a
## soft panel. The fitting is visible; the light can be animated by keying the
## object (move it) or changed here.

const TYPES: PackedStringArray = ["Ceiling lamp", "Spotlight", "Soft panel", "Bare bulb"]

@export var kind := "Ceiling lamp":
	set(v):
		kind = v if TYPES.has(v) else "Ceiling lamp"
		_changed(true)
@export var color := Color(1.0, 0.86, 0.68):
	set(v):
		color = v
		_changed()
@export var brightness := 1.0:
	set(v):
		brightness = clampf(v, 0.0, 16.0)
		_changed()
@export var reach := 8.0:
	set(v):
		reach = clampf(v, 1.0, 60.0)
		_changed()
@export var beam := 30.0:
	set(v):
		beam = clampf(v, 5.0, 80.0)
		_changed()
@export var shadows := true:
	set(v):
		shadows = v
		_changed()

var _light: Light3D
var _parts: Array[Node] = []


func inspector_title() -> String:
	return "Light"


func inspector_fields() -> Array:
	return [
		{"type": "option", "property": "kind", "label": "Type", "items": TYPES},
		{"type": "color", "property": "color", "label": "Colour"},
		{"type": "float", "property": "brightness", "label": "Brightness", "min": 0.0, "max": 16.0, "step": 0.05, "suffix": "×"},
		{"type": "float", "property": "reach", "label": "Reach", "min": 1.0, "max": 60.0, "step": 0.5, "suffix": " m"},
		{"type": "float", "property": "beam", "label": "Spot beam angle", "min": 5.0, "max": 80.0, "step": 1.0, "suffix": "°"},
		{"type": "bool", "property": "shadows", "label": "Casts shadows"},
	]


func _build() -> void:
	_rebuild()


func _settings_changed(geometry: bool) -> void:
	if geometry:
		_rebuild()
	else:
		_update()


func _rebuild() -> void:
	for part in _parts:
		part.queue_free()
	_parts.clear()
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1, 1, 1)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.15, 0.15, 0.16)
	metal.metallic = 0.7
	metal.roughness = 0.35
	match kind:
		"Spotlight":
			var spot := SpotLight3D.new()
			_light = spot
			_part(_cylinder(0.14, 0.1, 0.3), metal, Vector3(0, 0, 0.0), Vector3(90, 0, 0))
			_part(_cylinder(0.12, 0.12, 0.02), glow, Vector3(0, 0, -0.16), Vector3(90, 0, 0))
			_part(_cylinder(0.02, 0.02, 0.5), metal, Vector3(0, 0.25, 0.0), Vector3.ZERO)
		"Soft panel":
			_light = OmniLight3D.new()
			var panel := BoxMesh.new()
			panel.size = Vector3(0.9, 0.6, 0.04)
			_part(panel, glow, Vector3(0, 0, 0), Vector3.ZERO)
		"Bare bulb":
			_light = OmniLight3D.new()
			var bulb := SphereMesh.new()
			bulb.radius = 0.06
			bulb.height = 0.12
			_part(bulb, glow, Vector3.ZERO, Vector3.ZERO)
			_part(_cylinder(0.005, 0.005, 0.6), metal, Vector3(0, 0.33, 0), Vector3.ZERO)
		_:
			_light = OmniLight3D.new()
			_part(_cylinder(0.25, 0.08, 0.18), metal, Vector3(0, 0.0, 0), Vector3.ZERO)
			var bulb := SphereMesh.new()
			bulb.radius = 0.09
			bulb.height = 0.18
			_part(bulb, glow, Vector3(0, -0.08, 0), Vector3.ZERO)
	_light.name = "Light"
	add_child(_light)
	_parts.append(_light)
	_glow_material = glow
	_update()


var _glow_material: StandardMaterial3D


func _update() -> void:
	if _light == null:
		return
	_light.light_color = color
	_light.light_energy = brightness * (2.5 if _light is SpotLight3D else 1.0)
	_light.shadow_enabled = shadows
	if _light is OmniLight3D:
		(_light as OmniLight3D).omni_range = reach
		(_light as OmniLight3D).omni_attenuation = 1.2
	elif _light is SpotLight3D:
		var spot := _light as SpotLight3D
		spot.spot_range = reach
		spot.spot_angle = beam
		spot.spot_angle_attenuation = 0.8
	if _glow_material:
		_glow_material.albedo_color = color.lightened(0.3) * clampf(brightness, 0.2, 1.5)


func _part(mesh: Mesh, material: Material, at: Vector3, rotation_deg: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation_degrees = rotation_deg
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_parts.append(instance)


static func _cylinder(top: float, bottom: float, h: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = h
	return mesh

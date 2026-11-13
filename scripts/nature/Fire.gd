class_name Fire
extends EffectProp
## A campfire, torch or brazier: flickering flames, rising smoke and a warm
## flickering light that lights the scene and casts shadows.

const STYLES: PackedStringArray = ["Campfire", "Torch", "Brazier", "Flames only"]

@export_enum("Campfire", "Torch", "Brazier", "Flames only") var style := "Campfire":
	set(v):
		style = v if STYLES.has(v) else "Campfire"
		_changed(true)
@export var fire_size := 1.0:
	set(v):
		fire_size = clampf(v, 0.1, 6.0)
		_changed(true)
@export var brightness := 1.0:
	set(v):
		brightness = clampf(v, 0.0, 4.0)
		_changed()
@export var smoke := 0.6:
	set(v):
		smoke = clampf(v, 0.0, 1.0)
		_changed()
@export var light_color := Color(1.0, 0.6, 0.28):
	set(v):
		light_color = v
		_changed()

var _flames: MultiMeshInstance3D
var _smoke: MultiMeshInstance3D
var _light: OmniLight3D
var _parts: Array[Node] = []
var _base_height := 0.0


func inspector_title() -> String:
	return "Fire"


func inspector_fields() -> Array:
	return [
		{"type": "option", "property": "style", "label": "Type", "items": STYLES},
		{"type": "float", "property": "fire_size", "label": "Size", "min": 0.1, "max": 6.0, "step": 0.05, "suffix": " m"},
		{"type": "float", "property": "brightness", "label": "Brightness", "min": 0.0, "max": 4.0, "step": 0.05, "suffix": "×",
			"hint": "Flame glow and the light it casts (0 = unlit)"},
		{"type": "float", "property": "smoke", "label": "Smoke", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": ""},
		{"type": "color", "property": "light_color", "label": "Light colour"},
	]


func _build() -> void:
	_light = OmniLight3D.new()
	_light.name = "FireLight"
	_light.shadow_enabled = true
	_light.light_size = 0.2
	add_child(_light)
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
	var s := fire_size
	match style:
		"Campfire":
			for i in 5:
				var log_mesh := CylinderMesh.new()
				log_mesh.top_radius = 0.07 * s
				log_mesh.bottom_radius = 0.08 * s
				log_mesh.height = 0.8 * s
				var a := TAU * float(i) / 5.0
				var xf := Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, deg_to_rad(68.0)), Vector3(cos(a) * 0.12 * s, 0.1 * s, sin(a) * 0.12 * s))
				_parts.append(_solid("Log%d" % i, log_mesh, Color(0.25, 0.16, 0.1), xf))
			for i in 8:
				var stone := SphereMesh.new()
				stone.radius = 0.11 * s
				stone.height = 0.14 * s
				var a := TAU * float(i) / 8.0
				_parts.append(_solid("Stone%d" % i, stone, Color(0.4, 0.39, 0.37), Transform3D(Basis(), Vector3(cos(a) * 0.45 * s, 0.05 * s, sin(a) * 0.45 * s))))
			_base_height = 0.12 * s
		"Torch":
			var pole := CylinderMesh.new()
			pole.top_radius = 0.035
			pole.bottom_radius = 0.045
			pole.height = 1.6
			_parts.append(_solid("Pole", pole, Color(0.3, 0.2, 0.12), Transform3D(Basis(), Vector3(0, 0.8, 0))))
			var cup := CylinderMesh.new()
			cup.top_radius = 0.09
			cup.bottom_radius = 0.05
			cup.height = 0.16
			_parts.append(_solid("Cup", cup, Color(0.15, 0.14, 0.13), Transform3D(Basis(), Vector3(0, 1.66, 0)), 0.5))
			_base_height = 1.72
		"Brazier":
			var bowl := CylinderMesh.new()
			bowl.top_radius = 0.45 * s
			bowl.bottom_radius = 0.25 * s
			bowl.height = 0.35 * s
			_parts.append(_solid("Bowl", bowl, Color(0.16, 0.15, 0.14), Transform3D(Basis(), Vector3(0, 0.75 * s, 0)), 0.45))
			var stand := CylinderMesh.new()
			stand.top_radius = 0.06 * s
			stand.bottom_radius = 0.2 * s
			stand.height = 0.6 * s
			_parts.append(_solid("Stand", stand, Color(0.16, 0.15, 0.14), Transform3D(Basis(), Vector3(0, 0.3 * s, 0)), 0.45))
			_base_height = 0.88 * s
		_:
			_base_height = 0.0
	var flame_size := fire_size * (0.35 if style == "Torch" else 1.0)
	_flames = _particles("Flames", FIRE_SHADER, 48, AABB(Vector3(-1, 0, -1) * flame_size, Vector3(2, 2.5, 2) * flame_size))
	_flames.position.y = _base_height
	_smoke = _particles("Smoke", SMOKE_SHADER, 36, AABB(Vector3(-2, 0, -2) * flame_size, Vector3(4, 7, 4) * flame_size))
	_smoke.position.y = _base_height + flame_size * 0.6
	_parts.append(_flames)
	_parts.append(_smoke)
	_param(_flames, "fire_size", flame_size)
	_param(_flames, "spread", 0.35 if style != "Torch" else 0.25)
	_param(_smoke, "rise", 5.0 * flame_size)
	_param(_smoke, "thickness", 0.8 * flame_size)
	_param(_smoke, "spread", 0.3 * flame_size)
	_param(_smoke, "smoke_color", Color(0.3, 0.3, 0.32))
	_light.position = Vector3(0, _base_height + flame_size * 0.5, 0)
	_light.omni_range = 7.0 * maxf(flame_size, 0.5) + 2.0
	_update()


func _update() -> void:
	_param(_flames, "intensity", brightness)
	_param(_smoke, "amount", smoke)
	_param(_smoke, "opacity", 0.35)
	_smoke.visible = smoke > 0.0
	_light.light_color = light_color
	_light.visible = brightness > 0.0


func _process(_delta: float) -> void:
	if _light == null or not _light.visible:
		return
	var t := SceneClock.now
	var flicker := 0.78 + 0.12 * sin(t * 13.0) + 0.07 * sin(t * 23.7 + 1.3) + 0.05 * sin(t * 7.3 + 2.1)
	var flame_size := fire_size * (0.35 if style == "Torch" else 1.0)
	_light.light_energy = brightness * flicker * clampf(flame_size, 0.4, 3.0) * 1.6

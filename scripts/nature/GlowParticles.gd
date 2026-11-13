class_name GlowParticles
extends EffectProp
## Glowing "VFX" particles: embers, golden dust, fireflies, a power-up aura around
## a person, light rays and spark bursts. Shader-driven from scene time, so every
## export is identical. Looks best with the film's Glow (bloom) turned up.

const SHADER := preload("res://assets/materials/spark_fx.gdshader")
const KINDS := {
	"Embers": {"mode": 0, "a": Color(1.0, 0.42, 0.08), "b": Color(1.0, 0.75, 0.3), "rate": 0.22, "spread": 3.0, "height": 5.0, "size": 0.05, "stretch": 0.0, "intensity": 3.0, "count": 160},
	"Golden dust": {"mode": 1, "a": Color(1.0, 0.8, 0.45), "b": Color(1.0, 0.95, 0.75), "rate": 0.1, "spread": 7.0, "height": 3.5, "size": 0.025, "stretch": 0.0, "intensity": 2.2, "count": 260},
	"Fireflies": {"mode": 1, "a": Color(0.75, 1.0, 0.35), "b": Color(1.0, 0.9, 0.4), "rate": 0.1, "spread": 9.0, "height": 2.5, "size": 0.05, "stretch": 0.0, "intensity": 3.5, "count": 90, "blink": 1.0},
	"Energy aura": {"mode": 2, "a": Color(1.0, 0.7, 0.25), "b": Color(0.55, 0.85, 1.0), "rate": 0.7, "spread": 0.7, "height": 2.4, "size": 0.035, "stretch": 6.0, "intensity": 4.0, "count": 140},
	"Blue aura": {"mode": 2, "a": Color(0.3, 0.7, 1.0), "b": Color(0.7, 0.95, 1.0), "rate": 0.8, "spread": 0.7, "height": 2.4, "size": 0.035, "stretch": 6.0, "intensity": 4.0, "count": 140},
	"Light rays": {"mode": 3, "a": Color(1.0, 0.85, 0.6), "b": Color(1.0, 0.95, 0.85), "rate": 0.1, "spread": 6.0, "height": 14.0, "size": 1.2, "stretch": 0.0, "intensity": 0.18, "count": 14, "lean": 0.35},
	"Spark burst": {"mode": 4, "a": Color(1.0, 0.6, 0.15), "b": Color(1.0, 0.95, 0.6), "rate": 0.45, "spread": 3.0, "height": 2.0, "size": 0.04, "stretch": 5.0, "intensity": 4.0, "count": 180},
	"Snow sparkle": {"mode": 1, "a": Color(0.8, 0.9, 1.0), "b": Color(1.0, 1.0, 1.0), "rate": 0.1, "spread": 8.0, "height": 4.0, "size": 0.02, "stretch": 0.0, "intensity": 2.5, "count": 220, "blink": 0.6},
}

@export var kind := "Embers":
	set(v):
		kind = v if KINDS.has(v) else "Embers"
		_changed()
## Size of the area the particles fill (×).
@export var spread := 1.0:
	set(v):
		spread = clampf(v, 0.1, 10.0)
		_changed()
@export var height := 1.0:
	set(v):
		height = clampf(v, 0.1, 10.0)
		_changed()
@export var amount := 1.0:
	set(v):
		amount = clampf(v, 0.0, 1.0)
		_changed()
@export var brightness := 1.0:
	set(v):
		brightness = clampf(v, 0.0, 5.0)
		_changed()

var _sparks: MultiMeshInstance3D


func inspector_title() -> String:
	return "Glow particles (VFX)"


func inspector_fields() -> Array:
	return [
		{"type": "option", "property": "kind", "label": "Type", "items": PackedStringArray(KINDS.keys())},
		{"type": "float", "property": "spread", "label": "Area", "min": 0.1, "max": 10.0, "step": 0.05, "suffix": "×"},
		{"type": "float", "property": "height", "label": "Height", "min": 0.1, "max": 10.0, "step": 0.05, "suffix": "×"},
		{"type": "float", "property": "amount", "label": "Amount", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": ""},
		{"type": "float", "property": "brightness", "label": "Brightness", "min": 0.0, "max": 5.0, "step": 0.05, "suffix": "×"},
	]


func _build() -> void:
	_sparks = _particles("Sparks", SHADER, 260, AABB(Vector3(-40, -2, -40), Vector3(80, 60, 80)))
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	marker.mesh = sphere
	marker.layers = Layers.EDITOR_ONLY_VISUAL
	add_child(marker)
	_settings_changed(false)


func _settings_changed(_geometry: bool) -> void:
	if _sparks == null:
		return
	var k: Dictionary = KINDS[kind]
	_sparks.multimesh.visible_instance_count = mini(int(k["count"]), _sparks.multimesh.instance_count)
	_param(_sparks, "mode", int(k["mode"]))
	_param(_sparks, "color_a", k["a"])
	_param(_sparks, "color_b", k["b"])
	_param(_sparks, "rate", float(k["rate"]))
	_param(_sparks, "spread", float(k["spread"]) * spread)
	_param(_sparks, "height", float(k["height"]) * height)
	_param(_sparks, "size", float(k["size"]) * sqrt(spread))
	_param(_sparks, "stretch", float(k["stretch"]))
	_param(_sparks, "intensity", float(k["intensity"]) * brightness)
	_param(_sparks, "amount", amount)
	_param(_sparks, "blink", float(k.get("blink", 0.0)))
	_param(_sparks, "lean", float(k.get("lean", 0.0)))

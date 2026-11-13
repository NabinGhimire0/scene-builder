class_name SmokeColumn
extends EffectProp
## Smoke, steam or low ground mist rising from a point (chimneys, vents, fog
## machines). Bends with the wind.

const KINDS := {
	"Smoke": {"smoke_color": Color(0.32, 0.32, 0.34), "rise": 8.0, "thickness": 1.2, "rate": 0.12, "opacity": 0.4, "sink": 0.0},
	"Black smoke": {"smoke_color": Color(0.08, 0.08, 0.09), "rise": 12.0, "thickness": 2.0, "rate": 0.1, "opacity": 0.55, "sink": 0.0},
	"Steam": {"smoke_color": Color(0.9, 0.92, 0.95), "rise": 3.0, "thickness": 0.8, "rate": 0.3, "opacity": 0.3, "sink": 0.0},
	"Ground mist": {"smoke_color": Color(0.85, 0.87, 0.9), "rise": 0.6, "thickness": 3.5, "rate": 0.05, "opacity": 0.22, "sink": 0.8},
}

@export var kind := "Smoke":
	set(v):
		kind = v if KINDS.has(v) else "Smoke"
		_changed()
@export var height := 1.0:
	set(v):
		height = clampf(v, 0.2, 5.0)
		_changed()
@export var thickness := 1.0:
	set(v):
		thickness = clampf(v, 0.2, 5.0)
		_changed()
@export var amount := 1.0:
	set(v):
		amount = clampf(v, 0.0, 1.0)
		_changed()

var _puffs: MultiMeshInstance3D


func inspector_title() -> String:
	return "Smoke & mist"


func inspector_fields() -> Array:
	return [
		{"type": "option", "property": "kind", "label": "Type", "items": PackedStringArray(KINDS.keys())},
		{"type": "float", "property": "height", "label": "Height", "min": 0.2, "max": 5.0, "step": 0.05, "suffix": "×"},
		{"type": "float", "property": "thickness", "label": "Thickness", "min": 0.2, "max": 5.0, "step": 0.05, "suffix": "×"},
		{"type": "float", "property": "amount", "label": "Amount", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": ""},
	]


func _build() -> void:
	_puffs = _particles("Puffs", SMOKE_SHADER, 60, AABB(Vector3(-6, 0, -6), Vector3(12, 30, 12)))
	# A small marker so it can be selected in the editor (never in the film).
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	marker.mesh = sphere
	marker.layers = Layers.EDITOR_ONLY_VISUAL
	add_child(marker)
	_settings_changed(false)


func _settings_changed(_geometry: bool) -> void:
	var k: Dictionary = KINDS[kind]
	_param(_puffs, "smoke_color", k["smoke_color"])
	_param(_puffs, "rise", float(k["rise"]) * height)
	_param(_puffs, "thickness", float(k["thickness"]) * thickness)
	_param(_puffs, "rate", k["rate"])
	_param(_puffs, "opacity", k["opacity"])
	_param(_puffs, "sink", k["sink"])
	_param(_puffs, "spread", 0.4 * thickness * (4.0 if kind == "Ground mist" else 1.0))
	_param(_puffs, "amount", amount)

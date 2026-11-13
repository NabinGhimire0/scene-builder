class_name Waterfall
extends EffectProp
## A waterfall: a rushing sheet of water over a rock cliff, a foaming pool at
## the bottom and drifting spray.

const SHADER := preload("res://assets/materials/waterfall.gdshader")

@export var height := 8.0:
	set(v):
		height = clampf(v, 1.0, 60.0)
		_changed(true)
@export var width := 4.0:
	set(v):
		width = clampf(v, 0.5, 40.0)
		_changed(true)
@export var flow := 4.0:
	set(v):
		flow = clampf(v, 0.5, 12.0)
		_changed()
@export var foam := 0.7:
	set(v):
		foam = clampf(v, 0.0, 1.0)
		_changed()
@export var spray := 0.7:
	set(v):
		spray = clampf(v, 0.0, 1.0)
		_changed()
@export var show_cliff := true:
	set(v):
		show_cliff = v
		_changed(true)

var _parts: Array[Node] = []
var _sheet: MeshInstance3D
var _mist: MultiMeshInstance3D
var _pool: WaterBody


func inspector_title() -> String:
	return "Waterfall"


func inspector_fields() -> Array:
	return [
		{"type": "float", "property": "height", "label": "Height", "min": 1.0, "max": 60.0, "step": 0.1, "suffix": " m"},
		{"type": "float", "property": "width", "label": "Width", "min": 0.5, "max": 40.0, "step": 0.1, "suffix": " m"},
		{"type": "float", "property": "flow", "label": "Flow speed", "min": 0.5, "max": 12.0, "step": 0.1, "suffix": " m/s"},
		{"type": "float", "property": "foam", "label": "White water", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": ""},
		{"type": "float", "property": "spray", "label": "Spray & mist", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": ""},
		{"type": "bool", "property": "show_cliff", "label": "Rock cliff behind",
			"hint": "Turn off when the waterfall pours over your own terrain or model"},
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
	# The sheet curves out over the lip, then falls straight down to the pool.
	var xs := WaterStyle.spaced(-width * 0.5, width * 0.5, maxi(2, int(width) + 2))
	var rows := maxi(8, int(height * 2.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rows:
		for c in xs.size() - 1:
			for corner in [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]]:
				var u: float = float(c + corner[0]) / float(xs.size() - 1)
				var v: float = float(r + corner[1]) / float(rows)
				var drop := v * height
				var out := 0.6 * sqrt(clampf(v * 4.0, 0.0, 1.0)) + 0.15 * v
				st.set_uv(Vector2(u, drop))
				st.add_vertex(Vector3(lerpf(-width * 0.5, width * 0.5, u), height - drop, out))
	st.generate_normals()
	var material := ShaderMaterial.new()
	material.shader = SHADER
	_sheet = MeshInstance3D.new()
	_sheet.name = "Sheet"
	_sheet.mesh = st.commit()
	_sheet.material_override = material
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sheet)
	_parts.append(_sheet)

	if show_cliff:
		var cliff := MeshInstance3D.new()
		cliff.name = "Cliff"
		cliff.mesh = PlantMeshes.build("Rocks")
		cliff.transform = Transform3D(Basis.from_scale(Vector3(width * 1.6 + 2.0, height * 2.6, 3.0)), Vector3(0, -0.4, -1.2))
		var rock := StandardMaterial3D.new()
		rock.vertex_color_use_as_albedo = true
		rock.albedo_color = Color(0.44, 0.42, 0.38)   # vertex colour = crevice shading
		rock.roughness = 0.9
		cliff.material_override = rock
		add_child(cliff)
		_parts.append(cliff)

	_pool = WaterBody.new()
	_pool.name = "Pool"
	_pool.outline = "Natural"
	_pool.width = width * 2.2 + 2.0
	_pool.length = width * 1.6 + 2.0
	_pool.depth = 1.5
	_pool.foam = 0.9
	_pool.ripple_strength = 1.4
	_pool.ripple_size = 0.5
	_pool.wave_height = 0.0
	_pool.shore = "Pebbles"
	_pool.bank_wet = Color(0.26, 0.25, 0.23)
	_pool.bank_dry = Color(0.52, 0.5, 0.46)
	_pool.bank_bed = Color(0.4, 0.38, 0.34)
	_pool.bank_width = 1.0
	_pool.position = Vector3(0, 0, 0.9 + width * 0.5)
	add_child(_pool)
	_parts.append(_pool)

	_mist = _particles("Spray", SMOKE_SHADER, 40, AABB(Vector3(-width - 3, 0, -3), Vector3(width * 2 + 6, height + 4, width * 2 + 8)))
	_mist.position = Vector3(0, 0.1, 0.9)
	_param(_mist, "smoke_color", Color(0.9, 0.93, 0.96))
	_param(_mist, "rise", 2.5 + height * 0.15)
	_param(_mist, "rate", 0.35)
	_param(_mist, "spread", width * 0.4)
	_param(_mist, "thickness", 0.8 + width * 0.12)
	_parts.append(_mist)
	_update()


func _update() -> void:
	var material := _sheet.material_override as ShaderMaterial
	material.set_shader_parameter("flow_speed", flow)
	material.set_shader_parameter("sheet_width", width)
	material.set_shader_parameter("sheet_height", height)
	material.set_shader_parameter("foam", foam)
	_param(_mist, "amount", spray)
	_param(_mist, "opacity", 0.28)
	_mist.visible = spray > 0.0

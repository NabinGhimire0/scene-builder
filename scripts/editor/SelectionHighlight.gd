class_name SelectionHighlight
extends Node3D
## Visual indicator for the selected object: an orange outline on its meshes plus
## corner brackets around its bounds (drawn on top, so they show through walls).

const OUTLINE_SHADER := preload("res://assets/materials/selection_outline.gdshader")
const COLOR := Color(1.0, 0.62, 0.15)
const PADDING := 0.04

var _target: Node3D
var _outline: ShaderMaterial
var _brackets: MeshInstance3D
var _touched: Array[GeometryInstance3D] = []
var _suppressed := false


func _ready() -> void:
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE_SHADER
	_outline.set_shader_parameter("outline_color", COLOR)

	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.no_depth_test = true
	line_mat.albedo_color = Color(COLOR, 0.9)
	line_mat.render_priority = 10

	_brackets = MeshInstance3D.new()
	_brackets.name = "Brackets"
	_brackets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_brackets.material_override = line_mat
	_brackets.layers = Layers.EDITOR_ONLY_VISUAL
	add_child(_brackets)
	visible = false


## Hides the outline and brackets (camera previews, video export) while keeping
## the target, so they come back when unsuppressed.
func set_suppressed(suppressed: bool) -> void:
	if suppressed == _suppressed:
		return
	_suppressed = suppressed
	set_target(_target)


func set_target(node: Node3D) -> void:
	_restore_overlays()
	_target = node if is_instance_valid(node) else null
	if _target == null or _suppressed:
		visible = false
		return
	_brackets.mesh = _build_brackets(PropUtils.compute_local_aabb(_target).grow(PADDING))
	for n in PropUtils.descendants(_target, true):
		var geo := n as GeometryInstance3D
		if geo != null and geo.material_overlay == null:
			geo.material_overlay = _outline
			_touched.append(geo)
	visible = true
	_sync()


func _process(_delta: float) -> void:
	if visible:
		_sync()


func _exit_tree() -> void:
	_restore_overlays()


func _sync() -> void:
	if is_instance_valid(_target) and _target.is_inside_tree():
		global_transform = _target.global_transform
	else:
		visible = false


func _restore_overlays() -> void:
	for geo in _touched:
		if is_instance_valid(geo) and geo.material_overlay == _outline:
			geo.material_overlay = null
	_touched.clear()


static func _build_brackets(box: AABB) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var size := box.size
	var arm := size * 0.22
	for i in 2:
		for j in 2:
			for k in 2:
				var corner := box.position + Vector3(size.x * i, size.y * j, size.z * k)
				var inward := Vector3(1.0 - 2.0 * i, 1.0 - 2.0 * j, 1.0 - 2.0 * k)
				for axis in 3:
					var step := Vector3.ZERO
					step[axis] = inward[axis] * arm[axis]
					mesh.surface_add_vertex(corner)
					mesh.surface_add_vertex(corner + step)
	mesh.surface_end()
	return mesh

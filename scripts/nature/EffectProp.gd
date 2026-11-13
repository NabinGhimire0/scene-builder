class_name EffectProp
extends ProceduralProp
## Shared helpers for effect objects (fire, smoke, waterfall): particle layers
## drawn by shaders from scene time, so they look identical in every export.

const FIRE_SHADER := preload("res://assets/materials/fire_fx.gdshader")
const SMOKE_SHADER := preload("res://assets/materials/smoke_fx.gdshader")


## A MultiMesh of [param count] camera-facing quads using [param shader].
## [param bounds] is used for visibility culling and selection.
func _particles(layer_name: String, shader: Shader, count: int, bounds: AABB) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = count
	for i in count:
		multimesh.set_instance_transform(i, Transform3D.IDENTITY)
	var material := ShaderMaterial.new()
	material.shader = shader
	var instance := MultiMeshInstance3D.new()
	instance.name = layer_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = bounds
	add_child(instance)
	return instance


static func _param(instance: GeometryInstance3D, key: String, value: Variant) -> void:
	if instance and instance.material_override:
		(instance.material_override as ShaderMaterial).set_shader_parameter(key, value)


## A simple solid mesh part (logs, poles…) from a primitive.
func _solid(part_name: String, mesh: PrimitiveMesh, color: Color, xf: Transform3D, roughness: float = 0.9) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.transform = xf
	add_child(instance)
	return instance

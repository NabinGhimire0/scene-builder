class_name WeatherEffects
extends Node3D
## Rain, snow and falling leaves around the camera. Amounts and wind come from
## global shader parameters set by [EnvironmentController], so all of this is
## controlled (and animated) from the Scene tab.

const RAIN_SHADER := preload("res://assets/materials/weather_rain.gdshader")
const FLAKES_SHADER := preload("res://assets/materials/weather_flakes.gdshader")


func _ready() -> void:
	_add_layer("Rain", RAIN_SHADER, 9000, -1)
	_add_layer("Snow", FLAKES_SHADER, 6000, 0)
	_add_layer("Leaves", FLAKES_SHADER, 700, 1)


func _add_layer(layer_name: String, shader: Shader, count: int, mode: int) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = count
	var material := ShaderMaterial.new()
	material.shader = shader
	if mode >= 0:
		material.set_shader_parameter("mode", mode)
	var instance := MultiMeshInstance3D.new()
	instance.name = layer_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Particles are placed by the shader around the camera: never cull them.
	instance.custom_aabb = AABB(Vector3(-100000, -100000, -100000), Vector3(200000, 200000, 200000))
	add_child(instance)

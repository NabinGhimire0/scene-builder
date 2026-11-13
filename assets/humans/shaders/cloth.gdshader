// Scene Builder clothes: a tileable fabric (normal + brightness) x colour, with folds.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D fabric : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D folds_n : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D folds_ao : hint_default_white, filter_linear_mipmap;
uniform vec3 color : source_color = vec3(0.5);
uniform float fabric_scale = 30.0;
uniform float fabric_depth = 0.4;
uniform float fold_depth = 1.0;
uniform float roughness = 0.85;
uniform float sheen = 0.0;
uniform float fill = 0.025;
uniform float stylize = 0.0;

void fragment() {
	vec4 f = texture(fabric, UV * fabric_scale);
	float ao = mix(1.0, texture(folds_ao, UV).r, 0.35 * fold_depth);
	vec3 col = color * mix(f.a, 1.0, stylize * 0.7) * ao;
	ALBEDO = col;
	ROUGHNESS = roughness;
	SPECULAR = 0.3 + sheen * 0.3;
	vec3 n1 = f.xyz * 2.0 - 1.0;
	vec3 n2 = texture(folds_n, UV).xyz * 2.0 - 1.0;
	n1.xy *= fabric_depth * (1.0 - stylize * 0.7);
	n2.xy *= fold_depth * 0.45;
	NORMAL_MAP = normalize(vec3(n1.xy + n2.xy, n1.z * n2.z)) * 0.5 + 0.5;
	RIM = sheen * 0.5 + stylize * 0.15;
	RIM_TINT = 0.6;
	EMISSION = col * fill;
}

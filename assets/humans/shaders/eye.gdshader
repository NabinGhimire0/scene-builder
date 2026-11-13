// Scene Builder eyes: neutral eye texture with an iris mask, wet clearcoat.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D eye : source_color, filter_linear_mipmap;
uniform vec3 iris : source_color = vec3(0.3, 0.17, 0.08);
uniform float fill = 0.03;
uniform float stylize = 0.0;

void fragment() {
	vec4 e = texture(eye, UV);
	float lum = dot(e.rgb, vec3(0.333));
	vec3 col = mix(e.rgb, iris * (0.5 + lum * 1.6), e.a);
	col = mix(col, mix(col, vec3(0.96), 1.0 - e.a), stylize * 0.4);
	ALBEDO = col;
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.02;
	EMISSION = col * fill;
}

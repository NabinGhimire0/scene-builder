// Scene Builder hair shells / beard / cards: strand pattern with alpha scissor.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;

uniform sampler2D strands : hint_default_white, filter_linear_mipmap;
uniform vec3 color : source_color = vec3(0.08, 0.06, 0.05);
uniform int mode = 0;               // 0 scalp shell, 1 beard, 2 cards
uniform float layer = 0.0;          // 0 = base layer
uniform float threshold = 0.4;
uniform float edge = 0.5;           // scalp line (0.5 + h * 8)
uniform float density = 1.0;
uniform float gloss = 0.3;
uniform float fill = 0.025;
uniform float stylize = 0.0;
uniform float shade = 1.0;          // cards: inner layers are darker

void fragment() {
	vec4 s = texture(strands, UV);
	float v = mix(s.r * 0.75 + s.g * 0.35, s.g, stylize * 0.6);
	float a = 1.0;
	if (mode == 0) {
		float h = s.b;
		if (layer < 0.5) {
			a = smoothstep(edge - 0.02, edge + 0.08, h);
		} else {
			a = smoothstep(threshold, threshold + 0.12, v) * smoothstep(edge + 0.03 * layer, edge + 0.15 + 0.05 * layer, h);
		}
	} else if (mode == 1) {
		a = s.a * density * smoothstep(threshold, threshold + 0.15, s.r);
	} else if (mode == 2) {
		a = s.a;
	}
	vec3 col = color * (0.55 + 0.6 * s.r + 0.25 * s.g) + vec3(0.012);
	if (mode == 2) {
		col = color * (0.62 + 0.5 * s.r + 0.2 * (s.g - 0.5)) + vec3(0.01);
		col *= shade * mix(0.55, 1.0, smoothstep(0.0, 0.3, UV.y));
		ANISOTROPY_FLOW = vec2(0.0, 1.0);
		ALPHA_ANTIALIASING_EDGE = 0.25;
	}
	ALBEDO = col;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.72 - gloss * 0.2;
	SPECULAR = 0.12 + gloss * 0.15;
	ANISOTROPY = 0.55;
	RIM = 0.2;
	RIM_TINT = 0.6;
	EMISSION = col * fill;
}

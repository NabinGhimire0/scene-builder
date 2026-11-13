// Scene Builder realistic skin: neutral detail layers + per-person colours.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D skin_a : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_b : hint_default_black, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_c : hint_default_black, filter_linear_mipmap_anisotropic;
uniform sampler2D wrinkles_n : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D pores_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec3 tone : source_color = vec3(0.78, 0.58, 0.46);
uniform vec3 brow_color : source_color = vec3(0.1, 0.07, 0.05);
uniform vec3 lip_color : source_color = vec3(0.7, 0.4, 0.38);
uniform vec3 hair_color : source_color = vec3(0.08, 0.06, 0.05);
uniform vec3 makeup_color : source_color = vec3(0.25, 0.18, 0.2);
uniform float lip_strength = 0.75;
uniform float brow_strength = 0.92;
uniform float stubble = 0.0;
uniform float freckles = 0.0;
uniform float blush = 0.25;
uniform float wrinkles = 0.15;
uniform float pores = 0.6;
uniform float makeup = 0.0;
uniform float scalp = 0.0;          // hair colour painted under a hair cap
uniform float scalp_edge = 0.5;
uniform float stylize = 0.0;        // 0 realistic .. 1 animated-film look
uniform float fill = 0.025;         // a little self-light (film fill light)
uniform float pore_scale = 38.0;
uniform float subsurface = 0.35;
uniform float richness = 1.0;       // colour depth: 1 = natural (less washed-out under film light)
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform float use_albedo = 0.0;    // 1: the character's own skin texture (MPFB / imported avatars)

void fragment() {
	vec4 a = texture(skin_a, UV);
	vec4 b = texture(skin_b, UV);
	vec4 c = texture(skin_c, UV);
	float detail = 1.0 - stylize;
	vec3 col = tone * (1.0 + (a.r - 0.5) * 0.4 * detail);
	float red = clamp(a.g * 0.4 * (0.6 + 0.4 * detail) + c.a * blush, 0.0, 1.0);
	col = mix(col, col * vec3(1.06, 0.74, 0.70), red);
	col *= 1.0 - a.b * 0.16 * (0.5 + 0.5 * detail);
	col = mix(col, lip_color, a.a * lip_strength);
	float brow_mask = smoothstep(0.42, 0.85, b.r);
	float strokes = 0.72 + 0.28 * fract(sin(dot(floor(UV * vec2(4000.0, 900.0)), vec2(12.9898, 78.233))) * 43758.5453);
	col = mix(col, brow_color, clamp(brow_mask * mix(strokes, 1.0, stylize) * brow_strength * 1.1, 0.0, 1.0));
	float stub = b.g * stubble * (0.55 + 0.45 * fract(sin(dot(floor(UV * 2048.0), vec2(12.9898, 78.233))) * 43758.5453));
	col = mix(col, hair_color * 0.8 + vec3(0.03), clamp(stub * 0.55, 0.0, 1.0));
	col = mix(col, hair_color, smoothstep(scalp_edge - 0.03, scalp_edge + 0.05, b.b) * scalp);
	col = mix(col, min(tone * 1.1 + vec3(0.07), vec3(1.0)), b.a * 0.6);
	col *= 1.0 - c.r * freckles * 0.35;
	col = mix(col, vec3(0.42, 0.14, 0.14), c.g);
	col = mix(col, makeup_color, c.b * makeup);
	if (use_albedo > 0.5) {
		// an avatar's own painted skin, tinted by tone, with Scene Builder's pores, wrinkles and SSS
		col = texture(albedo_tex, UV).rgb * tone;
	}
	{
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(lum), col, 1.0 + 0.18 * richness) * (1.0 - 0.07 * richness);
	}
	if (stylize > 0.0) {
		float l = dot(col, vec3(0.333));
		col = mix(col, mix(vec3(l), col, 1.25), stylize * 0.6);
	}
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.52, 0.36, a.a), 0.6, stylize * 0.5);
	SPECULAR = 0.34;
	SSS_STRENGTH = subsurface * (1.0 + stylize * 0.6) * (1.0 - brow_mask);
	vec3 n1 = texture(wrinkles_n, UV).xyz * 2.0 - 1.0;
	vec3 n2 = texture(pores_n, UV * pore_scale).xyz * 2.0 - 1.0;
	n1.xy *= wrinkles * detail * 0.4;
	n2.xy *= pores * detail;
	vec3 n = normalize(vec3(n1.xy + n2.xy, n1.z * n2.z));
	NORMAL_MAP = n * 0.5 + 0.5;
	RIM = 0.25 * stylize;
	RIM_TINT = 0.5;
	EMISSION = col * fill;
}

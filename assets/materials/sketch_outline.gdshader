// Flat looks (Flat sketch, Paper): draws a line wherever the depth jumps (the outline of every
// object against what's behind it), like a hand-drawn outline. Used on a quad
// that covers the whole screen (see SketchLook.gd).
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, blend_mix, skip_vertex_transform, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 line_color : source_color = vec4(0.62, 0.6, 0.57, 1.0);
uniform float thickness = 1.6;
uniform float threshold = 0.035;
// Paper look: a faint grain and blotches over the whole picture (0 = off).
uniform float paper = 0.0;
// The Compatibility renderer stores depth as -1..1 (set from SketchLook.gd).
uniform bool depth_minus_one_to_one = false;
// Sketchbook: the pencil lines wobble a little, 8 times a second, like drawn frames.
uniform float boil = 0.0;
global uniform float scene_time;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float linear_depth(vec2 uv, float depth, mat4 inv_projection, bool minus_one_to_one) {
	vec3 ndc = minus_one_to_one ? vec3(uv, depth) * 2.0 - 1.0 : vec3(uv * 2.0 - 1.0, depth);
	vec4 view = inv_projection * vec4(ndc, 1.0);
	return -view.z / view.w;
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	vec2 suv = SCREEN_UV;
	float pressure = 1.0;
	if (boil > 0.0) {
		float frame = floor(scene_time * 8.0);
		vec2 cell = floor(SCREEN_UV * VIEWPORT_SIZE / 18.0);
		vec2 wobble = vec2(smooth_noise(cell * 0.35 + frame * 7.3), smooth_noise(cell * 0.35 + frame * 3.1 + 19.0)) - 0.5;
		suv += wobble * boil * 2.4 / VIEWPORT_SIZE;
		px *= 0.8 + 0.45 * smooth_noise(SCREEN_UV * VIEWPORT_SIZE / 40.0 + frame);
		pressure = 0.7 + 0.3 * hash(floor(SCREEN_UV * VIEWPORT_SIZE / 3.0));
	}
	float c = linear_depth(suv, texture(depth_texture, suv).r, INV_PROJECTION_MATRIX, depth_minus_one_to_one);
	float edge = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 uv = suv + vec2(cos(a), sin(a)) * px;
		float d = linear_depth(uv, texture(depth_texture, uv).r, INV_PROJECTION_MATRIX, depth_minus_one_to_one);
		edge = max(edge, step(threshold * min(c, d), abs(d - c)));
	}
	float grain = 0.0;
	if (paper > 0.0) {
		vec2 p = SCREEN_UV * VIEWPORT_SIZE;
		float fine = hash(floor(p * 0.75));
		float fibre = hash(floor(vec2(p.x * 0.08, p.y * 1.5)));
		float blotch = smooth_noise(SCREEN_UV * 6.0) * 0.6 + smooth_noise(SCREEN_UV * 17.0) * 0.4;
		grain = paper * (0.035 * fine + 0.02 * fibre + 0.06 * blotch);
	}
	vec3 paper_ink = vec3(0.45, 0.33, 0.2);
	ALBEDO = mix(paper_ink, line_color.rgb, edge);
	ALPHA = max(edge * line_color.a * pressure, grain);
}

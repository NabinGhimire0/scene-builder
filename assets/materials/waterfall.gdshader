shader_type spatial;
// A falling sheet of water: streaks rush downwards (UV.y is metres from the
// top), white water at the lip and the bottom, see-through gaps between.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley;

global uniform float scene_time;

uniform vec4 water_color : source_color = vec4(0.62, 0.74, 0.78, 1.0);
uniform float flow_speed = 4.0;
uniform float sheet_width = 4.0;
uniform float sheet_height = 8.0;
uniform float foam = 0.7;

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), u.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float x = UV.x * sheet_width;
	float y = UV.y;
	float t = scene_time * flow_speed;
	float streaks = vnoise(vec2(x * 3.0, (y - t) * 0.25)) * 0.6 + vnoise(vec2(x * 7.0 + 3.0, (y - t * 1.3) * 0.5)) * 0.4;
	float sides = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	float white = smoothstep(0.55, 0.85, streaks) * foam;
	white = max(white, smoothstep(sheet_height - 1.2, sheet_height, y) * foam);
	white = max(white, (1.0 - smoothstep(0.0, 0.6, y)) * 0.4 * foam);
	ALBEDO = mix(water_color.rgb, vec3(0.95), white);
	ROUGHNESS = mix(0.1, 0.6, white);
	SPECULAR = 0.5;
	ALPHA = clamp((0.45 + streaks * 0.5 + white) * sides, 0.0, 0.97);
}

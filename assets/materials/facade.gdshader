shader_type spatial;
// City building facade: a grid of windows (UV = metres) with frames, glass
// that reflects the sky, and windows that light up at night.
render_mode diffuse_burley;

global uniform float night;

uniform vec4 wall_color : source_color = vec4(0.55, 0.55, 0.57, 1.0);
uniform vec4 glass_color : source_color = vec4(0.12, 0.17, 0.22, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.82, 0.55, 1.0);
uniform float floor_height = 3.2;
uniform float window_width = 1.6;
uniform float glass_ratio = 0.7;
uniform float seed = 0.0;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 cell = vec2(UV.x / window_width, UV.y / floor_height);
	vec2 f = fract(cell);
	vec2 id = floor(cell);
	float margin = (1.0 - glass_ratio) * 0.5;
	float is_glass = step(margin, f.x) * step(f.x, 1.0 - margin) * step(0.25, f.y) * step(f.y, 0.88);
	float lit = step(0.55, h2(id + seed)) * night;
	vec3 col = mix(wall_color.rgb * (0.9 + 0.1 * h2(id * 0.3)), glass_color.rgb, is_glass);
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.05, is_glass);
	METALLIC = 0.4 * is_glass;
	EMISSION = light_color.rgb * lit * is_glass * (0.6 + 0.8 * h2(id + 3.1));
}

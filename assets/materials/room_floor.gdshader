shader_type spatial;
// Floors and walls for rooms: wood planks, tiles, carpet, concrete or plain
// paint, projected in world metres so any box size looks right.
render_mode diffuse_burley;

uniform int pattern = 0; // 0 planks, 1 tiles, 2 carpet, 3 concrete, 4 plain
uniform vec4 color_a : source_color = vec4(0.55, 0.38, 0.22, 1.0);
uniform vec4 color_b : source_color = vec4(0.45, 0.3, 0.17, 1.0);
uniform float tile = 0.6;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), u.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), u.x), u.y);
}

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 p = n.y > 0.5 ? world_pos.xz : (n.x > 0.5 ? world_pos.zy : world_pos.xy);
	vec3 col = color_a.rgb;
	float rough = 0.6;
	if (pattern == 0) {
		vec2 q = vec2(p.x / 0.18, p.y / 1.2);
		q.y += h2(vec2(floor(q.x), 0.0)) * 3.0;
		vec2 cell = floor(q);
		float seam = step(0.96, fract(q.x)) + step(0.985, fract(q.y));
		float grain = vnoise(vec2(q.x * 3.0, q.y * 40.0) + cell * 7.0);
		col = mix(color_a.rgb, color_b.rgb, h2(cell) * 0.7 + grain * 0.3) * (1.0 - seam * 0.5);
		rough = 0.45;
	} else if (pattern == 1) {
		vec2 q = p / tile;
		float grout = max(step(0.95, fract(q.x)), step(0.95, fract(q.y)));
		col = mix(mix(color_a.rgb, color_a.rgb * 0.92, h2(floor(q))), color_b.rgb, grout);
		rough = mix(0.25, 0.9, grout);
	} else if (pattern == 2) {
		col = mix(color_a.rgb, color_b.rgb, vnoise(p * 60.0) * 0.6 + vnoise(p * 3.0) * 0.4);
		rough = 1.0;
	} else if (pattern == 3) {
		col = mix(color_a.rgb, color_b.rgb, vnoise(p * 1.5) * 0.6 + vnoise(p * 12.0) * 0.4);
		rough = 0.85;
	} else {
		col = color_a.rgb * (0.97 + 0.03 * vnoise(p * 20.0));
		rough = 0.9;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}

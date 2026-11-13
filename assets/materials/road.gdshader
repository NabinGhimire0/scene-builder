shader_type spatial;
// Asphalt road (UV.x = metres across from the centre, UV.y = metres along)
// with lane markings, kerbs, pavements and an optional zebra crossing.
render_mode diffuse_burley;

global uniform float wetness;

uniform float road_width = 7.0;
uniform float pavement = 2.5;
uniform int lanes = 2;
uniform float crossing_at = -1.0;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float half_road = road_width * 0.5;
	vec3 asphalt = vec3(0.13, 0.13, 0.14) * (0.85 + 0.3 * h2(floor(UV * 25.0)));
	vec3 col = asphalt;
	float rough = 0.85;
	if (abs(x) > half_road) {
		vec2 slab = vec2((abs(x) - half_road) / 1.0, y / 1.0);
		float joint = max(step(0.97, fract(slab.x)), step(0.97, fract(slab.y)));
		col = vec3(0.55, 0.54, 0.52) * (0.9 + 0.1 * h2(floor(slab))) * (1.0 - joint * 0.25);
		if (abs(x) < half_road + 0.18) col = vec3(0.7);
		rough = 0.9;
	} else {
		float lane_w = road_width / float(max(lanes, 1));
		float edge = step(half_road - 0.25, abs(x)) * step(abs(x), half_road - 0.12);
		float centre = 0.0;
		for (int i = 1; i < 8; i++) {
			if (i >= lanes) break;
			float lx = -half_road + lane_w * float(i);
			float dashed = step(0.5, fract(y / 6.0));
			float solid = (lanes == 2 || i * 2 == lanes) ? 1.0 : dashed;
			centre = max(centre, step(abs(x - lx), 0.07) * solid);
		}
		float zebra = 0.0;
		if (crossing_at >= 0.0 && abs(y - crossing_at) < 2.0) {
			zebra = step(0.5, fract(x / 1.0));
		}
		col = mix(col, vec3(0.9), max(max(edge, centre), zebra));
	}
	col *= 1.0 - wetness * 0.35;
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.12, wetness * 0.8);
}

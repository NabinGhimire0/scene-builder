shader_type spatial;
// The wet bank or beach around a body of water, and the bed seen through
// shallow water. Shares the water's shape, so the shoreline always matches;
// the outer edge is ragged so it blends into the ground.
render_mode cull_disabled, diffuse_burley, skip_vertex_transform;

#include "res://assets/materials/water_common.gdshaderinc"

uniform int shape = 0;
uniform vec2 size_m = vec2(10.0, 10.0);
uniform float seed = 0.0;
uniform float bank_width = 1.5;
uniform vec4 wet_color : source_color = vec4(0.17, 0.13, 0.09, 1.0);
uniform vec4 dry_color : source_color = vec4(0.38, 0.32, 0.23, 1.0);
uniform vec4 bed_color : source_color = vec4(0.3, 0.26, 0.19, 1.0);
uniform float view_bias = 0.998;
uniform bool carved = false;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

varying vec2 local_p;

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// Pebbles: x = gap between stones (0 at a crack), y = a random value per stone.
vec2 pebbles(vec2 p) {
	vec2 cell = floor(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cell + vec2(float(i), float(j));
			vec2 h = hash2(c);
			float d = length(c + 0.15 + 0.7 * h - p);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = h.x;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(d2 - d1, id);
}
varying vec3 world_pos;

void vertex() {
	local_p = UV;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_pos = wp;
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz * view_bias;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mat3(MODEL_MATRIX) * NORMAL), 0.0)).xyz);
}

void fragment() {
	float edge = water_edge(local_p, shape, size_m, seed);
	float n1 = texture(noise_tex, world_pos.xz * 0.15).r;
	float n2 = texture(noise_tex, world_pos.xz * 0.9 + vec2(0.5)).r;
	float rag = bank_width * (0.55 + 0.6 * n1);
	if (edge < -rag || (carved && edge > 0.0)) {
		discard;
	}
	float outward = clamp(-edge / max(rag, 0.01), 0.0, 1.0);
	vec3 col = mix(wet_color.rgb, dry_color.rgb, smoothstep(0.0, 1.0, outward));
	float rough = mix(0.3, 0.95, smoothstep(0.0, 0.7, outward));
	if (edge > 0.0) {
		col = mix(wet_color.rgb, bed_color.rgb, smoothstep(0.0, 1.5, edge));
		rough = 0.6;
	}
	// Grey (stony) banks are made of pebbles: stones of different shades with dark gaps.
	float grey = smoothstep(0.12, 0.04, max(max(dry_color.r, dry_color.g), dry_color.b) - min(min(dry_color.r, dry_color.g), dry_color.b));
	if (grey > 0.0) {
		vec2 big = pebbles(world_pos.xz * 3.2);
		vec2 small = pebbles(world_pos.xz * 9.0 + 3.0);
		float stone = mix(0.55, 1.2, big.y) * mix(0.8, 1.1, small.y);
		float gap = smoothstep(0.0, 0.12, big.x) * mix(1.0, smoothstep(0.0, 0.1, small.x), 0.5);
		vec3 tint = mix(vec3(1.05, 0.98, 0.9), vec3(0.92, 0.95, 1.0), fract(big.y * 7.0));
		vec3 stony = col * stone * tint * mix(0.35, 1.0, gap);
		col = mix(col, stony, grey);
		rough = mix(rough, rough * mix(0.7, 1.0, gap), grey);
	}
	ALBEDO = col * (0.8 + 0.4 * n2);
	ROUGHNESS = rough;
	SPECULAR = 0.4;
}

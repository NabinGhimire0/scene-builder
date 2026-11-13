shader_type spatial;
// Sculptable terrain. Heights come from a heightmap texture (moved in the vertex
// shader); a splat map holds painted layers (r dirt, g rock, b sand, a snow).
// The base layer is the Scene tab's ground style, drawn with exactly the same
// pattern as the ground outside the terrain so the border is invisible.
// Steep slopes turn to rock automatically; rain makes everything wet and dark,
// snow cover settles on flat ground.
render_mode diffuse_burley;

global uniform float wetness;
global uniform float snow_cover;
global uniform float autumn;

uniform sampler2D heightmap : filter_linear, repeat_disable;
uniform sampler2D splatmap : filter_linear, repeat_disable;
uniform float terrain_size = 256.0;
uniform float texel = 0.00390625;

uniform vec4 color_a : source_color = vec4(0.17, 0.29, 0.09, 1.0);
uniform vec4 color_b : source_color = vec4(0.27, 0.36, 0.12, 1.0);
uniform vec4 color_c : source_color = vec4(0.3, 0.25, 0.15, 1.0);
uniform float scale = 1.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
uniform float bump : hint_range(0.0, 3.0) = 1.0;
uniform float specular_value : hint_range(0.0, 1.0) = 0.25;
uniform float speckle : hint_range(0.0, 1.0) = 0.45;
uniform bool use_base_texture = false;
uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float base_tile = 3.0;

uniform vec4 dirt_color : source_color = vec4(0.33, 0.24, 0.16, 1.0);
uniform vec4 rock_color : source_color = vec4(0.42, 0.41, 0.39, 1.0);
uniform vec4 sand_color : source_color = vec4(0.78, 0.69, 0.51, 1.0);
uniform vec4 snow_color : source_color = vec4(0.93, 0.95, 0.98, 1.0);
uniform float slope_rock = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec2 tuv;

float hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p = p * 2.07 + vec2(31.7, 12.3);
		amplitude *= 0.5;
	}
	return value;
}

float height_at(vec2 p) {
	return fbm(p * scale * 3.0) * 0.6 + noise(p * scale * 18.0) * 0.4;
}

float terrain_h(vec2 uv) {
	return textureLod(heightmap, uv, 0.0).r;
}

void vertex() {
	vec2 uv = VERTEX.xz / terrain_size + 0.5;
	tuv = uv;
	VERTEX.y += terrain_h(uv);
	float hl = terrain_h(uv - vec2(texel, 0.0));
	float hr = terrain_h(uv + vec2(texel, 0.0));
	float hd = terrain_h(uv - vec2(0.0, texel));
	float hu = terrain_h(uv + vec2(0.0, texel));
	NORMAL = normalize(vec3(hl - hr, 2.0 * terrain_size * texel, hd - hu));
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	// Base layer: identical to realistic_ground.gdshader.
	float large = fbm(p * scale * 0.05);
	float mid = fbm(p * scale * 0.4 + 7.0);
	float fine = noise(p * scale * 9.0 + 13.0);
	vec3 col = mix(color_a.rgb, color_b.rgb, smoothstep(0.3, 0.7, large));
	col = mix(col, color_c.rgb, smoothstep(0.55, 0.85, mid) * 0.7);
	// Autumn: the grass dries to straw and fallen-leaf browns.
	col = mix(col, mix(vec3(0.46, 0.33, 0.13), vec3(0.42, 0.2, 0.08), smoothstep(0.4, 0.8, mid)) * (0.85 + 0.3 * large), autumn * 0.85);
	col *= 1.0 - speckle * 0.5 + speckle * fine;
	if (use_base_texture) {
		col = texture(base_texture, p / max(base_tile, 0.05)).rgb;
	}
	float rough = clamp(roughness_value - fine * 0.12, 0.0, 1.0);

	vec4 s = texture(splatmap, tuv);
	float n1 = noise(p * 1.7);
	float n2 = fbm(p * 0.6 + 3.0);
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float rock_w = max(s.g, smoothstep(0.32, 0.5, slope + (n2 - 0.5) * 0.15) * slope_rock);
	float snow_w = max(s.a, snow_cover * smoothstep(0.35, 0.15, slope) * smoothstep(0.25, 0.55, snow_cover + n2 * 0.4));

	vec3 dirt = dirt_color.rgb * (0.8 + 0.4 * n1);
	// Rock faces: noise laid out across the slope (not stretched down it), with
	// horizontal strata, cracks and a few warmer, iron-stained bands.
	vec2 along = vec2(-world_normal.z, world_normal.x);
	along = length(along) > 0.001 ? normalize(along) : vec2(1.0, 0.0);
	vec2 face = vec2(dot(p, along), world_pos.y);
	float strata = noise(vec2(face.x * 0.35, face.y * 3.2));
	float cracks = fbm(face * 1.4 + 11.0);
	float stain = smoothstep(0.55, 0.8, noise(vec2(face.x * 0.15, face.y * 0.9) + 4.0));
	vec3 rock = rock_color.rgb * (0.55 + 0.45 * strata + 0.35 * cracks) * (0.85 + 0.3 * fine);
	rock = mix(rock, rock * vec3(1.12, 0.92, 0.72), stain * 0.6);
	vec3 sand = sand_color.rgb * (0.9 + 0.2 * fine);
	col = mix(col, dirt, smoothstep(0.0, 1.0, s.r));
	rough = mix(rough, 0.95, s.r);
	col = mix(col, sand, smoothstep(0.0, 1.0, s.b));
	rough = mix(rough, 0.97, s.b);
	col = mix(col, rock, smoothstep(0.0, 1.0, rock_w));
	rough = mix(rough, 0.82, rock_w);

	float wet = wetness * (1.0 - snow_w);
	col *= 1.0 - wet * 0.38;
	rough = mix(rough, 0.18, wet * 0.75);
	col = mix(col, snow_color.rgb * (0.95 + 0.05 * fine), smoothstep(0.0, 1.0, snow_w));
	rough = mix(rough, 0.6, snow_w);

	// Fine surface relief (same as the outside ground).
	float e = 0.03;
	float hx = height_at(p + vec2(e, 0.0)) - height_at(p - vec2(e, 0.0));
	float hz = height_at(p + vec2(0.0, e)) - height_at(p - vec2(0.0, e));
	float relief = bump * (1.0 + rock_w) * 0.25 / e;
	vec3 n = normalize(world_normal + vec3(-hx * relief, 0.0, -hz * relief));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = mix(specular_value, 0.5, wet);
}

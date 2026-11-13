shader_type spatial;
// Procedural PBR ground: three colour layers mixed by world-space noise at
// several scales, with a matching bump normal and roughness variation, so large
// areas never look tiled. Presets (grass, dirt, sand, snow, rock, asphalt) are
// set by EnvironmentController.
render_mode diffuse_burley;

global uniform float wetness;
global uniform float snow_cover;
global uniform float autumn;

uniform vec4 color_a : source_color = vec4(0.22, 0.33, 0.12, 1.0);
uniform vec4 color_b : source_color = vec4(0.32, 0.38, 0.16, 1.0);
uniform vec4 color_c : source_color = vec4(0.33, 0.27, 0.18, 1.0);
uniform float scale = 1.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
uniform float bump : hint_range(0.0, 3.0) = 1.0;
uniform float specular_value : hint_range(0.0, 1.0) = 0.25;
uniform float speckle : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_pos;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float large = fbm(p * scale * 0.05);
	float mid = fbm(p * scale * 0.4 + 7.0);
	float fine = noise(p * scale * 9.0 + 13.0);

	vec3 col = mix(color_a.rgb, color_b.rgb, smoothstep(0.3, 0.7, large));
	col = mix(col, color_c.rgb, smoothstep(0.55, 0.85, mid) * 0.7);
	// Autumn: the grass dries to straw and fallen-leaf browns.
	col = mix(col, mix(vec3(0.46, 0.33, 0.13), vec3(0.42, 0.2, 0.08), smoothstep(0.4, 0.8, mid)) * (0.85 + 0.3 * large), autumn * 0.85);
	col *= 1.0 - speckle * 0.5 + speckle * fine;

	float e = 0.03;
	float hx = height_at(p + vec2(e, 0.0)) - height_at(p - vec2(e, 0.0));
	float hz = height_at(p + vec2(0.0, e)) - height_at(p - vec2(0.0, e));
	vec3 world_normal = normalize(vec3(-hx * bump * 0.25 / e, 1.0, -hz * bump * 0.25 / e));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	// Rain and snow (same as terrain.gdshader, so both match at the border).
	float rough = clamp(roughness_value - fine * 0.12, 0.0, 1.0);
	float n2 = fbm(p * 0.6 + 3.0);
	float snow_w = snow_cover * smoothstep(0.25, 0.55, snow_cover + n2 * 0.4);
	float wet = wetness * (1.0 - snow_w);
	col *= 1.0 - wet * 0.38;
	rough = mix(rough, 0.18, wet * 0.75);
	col = mix(col, vec3(0.93, 0.95, 0.98) * (0.95 + 0.05 * fine), smoothstep(0.0, 1.0, snow_w));
	rough = mix(rough, 0.6, snow_w);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = mix(specular_value, 0.5, wet);
}

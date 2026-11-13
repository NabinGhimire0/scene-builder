shader_type spatial;
// Painted plants (MultiMesh). They bend with the global wind (stronger towards
// the top), flutter, get wet in the rain and catch snow on top. Vertex alpha 1
// marks flower heads, which take their colour from the instance.
render_mode cull_disabled, diffuse_burley;

global uniform float scene_time;
global uniform float wind_strength;
global uniform vec2 wind_direction;
global uniform float wetness;
global uniform float snow_cover;
global uniform float autumn;

uniform float sway = 1.0;
uniform float plant_height = 1.0;
uniform float stiffness = 2.0;
uniform float translucency = 0.35;
uniform float roughness_value = 0.8;
// How much this kind of plant turns in autumn (pines hardly, broadleaf trees fully).
uniform float autumn_response = 1.0;
// Low plants sink under the snow (0 = stay, 1 = fully buried at full snow cover).
uniform float bury_in_snow = 0.0;
// Rocks: stone colour from world-space noise, moss and lichen on top (no wind).
uniform float stone = 0.0;

varying vec3 base_color;
varying float up_facing;
varying float leaf_seed;
varying vec3 world_pos;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = clamp(VERTEX.y / max(plant_height, 0.01), 0.0, 1.5);
	float bend = pow(h, stiffness);
	float phase = dot(origin.xz, vec2(0.21, 0.17));
	float gust = 0.65 + 0.35 * sin(scene_time * 0.6 + origin.x * 0.04 + origin.z * 0.03);
	float w = wind_strength * gust * sway;
	float flutter = sin(scene_time * 2.3 + phase) * 0.22 + sin(scene_time * 5.1 + phase * 2.0) * 0.07;
	vec3 push = vec3(wind_direction.x, 0.0, wind_direction.y) * (w * 0.7 + flutter * (0.3 + w)) * bend * plant_height * 0.3;
	push.y = -length(push.xz) * 0.35 * bend;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * push;
	VERTEX.y *= 1.0 - clamp(snow_cover * 1.15, 0.0, 1.0) * bury_in_snow;
	base_color = COLOR.a > 0.5 ? INSTANCE_CUSTOM.rgb : COLOR.rgb * INSTANCE_CUSTOM.a;
	up_facing = clamp((mat3(MODEL_MATRIX) * NORMAL).y, 0.0, 1.0);
	leaf_seed = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = base_color;
	float rough = roughness_value;
	// Autumn: greens turn gold, orange and red (each plant a little different).
	float green = clamp((col.g - max(col.r, col.b)) * 6.0, 0.0, 1.0);
	float turn = autumn * autumn_response * green;
	if (turn > 0.0) {
		vec3 gold = vec3(0.95, 0.62, 0.16);
		vec3 rust = vec3(0.78, 0.26, 0.09);
		vec3 fall_col = mix(gold, rust, leaf_seed) * (0.45 + 0.8 * dot(col, vec3(0.3, 0.59, 0.11)));
		col = mix(col, fall_col, turn);
	}
	if (stone > 0.5) {
		// Weathered stone: warm grey with darker grain, pale lichen and moss on top.
		float n1 = vnoise(world_pos * 2.2);
		float n2 = vnoise(world_pos * 9.0);
		float grain = n1 * 0.65 + n2 * 0.35;
		vec3 rock_a = vec3(0.2, 0.185, 0.165);
		vec3 rock_b = vec3(0.4, 0.37, 0.32);
		vec3 rock = mix(rock_a, rock_b, smoothstep(0.25, 0.85, grain)) * (0.9 + 0.2 * leaf_seed);
		rock *= base_color.r;   // crevices (vertex colour) are darker
		float lichen = smoothstep(0.72, 0.8, vnoise(world_pos * 5.0 + 17.0));
		rock = mix(rock, vec3(0.62, 0.6, 0.5), lichen * 0.45);
		float moss = smoothstep(0.55, 0.9, up_facing) * smoothstep(0.35, 0.65, vnoise(world_pos * 1.6 + 5.0));
		rock = mix(rock, vec3(0.16, 0.22, 0.08), moss * 0.75 * (1.0 - autumn * 0.4));
		col = rock;
		SPECULAR = 0.2;
		// Stone sits in the open: without this the blue sky light turns shaded rocks blue.
		AO = 0.45 + 0.25 * base_color.r;
		AO_LIGHT_AFFECT = 0.0;
	}
	col *= 1.0 - wetness * 0.3;
	rough = mix(rough, 0.3, wetness * 0.6);
	float snow = snow_cover * smoothstep(0.3, 0.8, up_facing);
	col = mix(col, vec3(0.92, 0.94, 0.97), snow);
	ALBEDO = col;
	ROUGHNESS = rough;
	BACKLIGHT = col * translucency * (1.0 - snow);
}

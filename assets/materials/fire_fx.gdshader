shader_type spatial;
// Flames: each MultiMesh instance is one flame tongue that rises, shrinks and
// cools from yellow-white to red. Additive and unshaded, so it glows. Driven
// by scene_time, so it flickers identically in previews and exported video.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

global uniform float scene_time;
global uniform float wind_strength;
global uniform vec2 wind_direction;

uniform float fire_size = 1.0;
uniform float rate = 1.7;
uniform float intensity = 1.0;
uniform float spread = 0.3;

varying float age;
varying float seed;

float h1(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

void vertex() {
	float f = float(INSTANCE_ID);
	seed = h1(f);
	age = fract(scene_time * rate * (0.7 + 0.6 * h1(f + 1.0)) + h1(f + 2.0));
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec2 r = vec2(h1(f + 3.0) - 0.5, h1(f + 4.0) - 0.5) * spread * fire_size * (1.0 - age * 0.6);
	vec3 wind = vec3(wind_direction.x, 0.0, wind_direction.y) * wind_strength * age * age * 0.5 * fire_size;
	vec3 centre = origin + vec3(r.x, age * fire_size * (0.8 + 0.5 * h1(f + 5.0)), r.y) + wind;
	float size = fire_size * 0.32 * (1.0 - age * 0.7) * (0.6 + 0.6 * h1(f + 6.0));
	vec3 c = (VIEW_MATRIX * vec4(centre, 1.0)).xyz;
	VERTEX = c + vec3(VERTEX.x * size, VERTEX.y * size * 1.7, 0.0);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float wobble = sin(q.y * 6.0 + scene_time * 9.0 + seed * 20.0) * 0.12;
	float d = length(vec2(q.x + wobble * (1.0 - UV.y), q.y * 0.8));
	float shape = 1.0 - smoothstep(0.15, 1.0, d);
	vec3 hot = vec3(1.0, 0.86, 0.55);
	vec3 mid = vec3(1.0, 0.45, 0.08);
	vec3 cool = vec3(0.55, 0.1, 0.02);
	vec3 col = mix(hot, mid, smoothstep(0.0, 0.45, age));
	col = mix(col, cool, smoothstep(0.45, 1.0, age));
	float fade = smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.55, 1.0, age));
	ALBEDO = col * intensity * 2.2;
	ALPHA = shape * fade;
}

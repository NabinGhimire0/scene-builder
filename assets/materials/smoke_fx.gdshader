shader_type spatial;
// Smoke, steam and mist puffs: each instance rises, grows and fades; the wind
// bends the column. Lit by the scene, deterministic with scene_time.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

global uniform float scene_time;
global uniform float wind_strength;
global uniform vec2 wind_direction;

uniform vec4 smoke_color : source_color = vec4(0.45, 0.45, 0.47, 1.0);
uniform float rise = 4.0;
uniform float rate = 0.15;
uniform float thickness = 1.0;
uniform float spread = 0.3;
uniform float amount = 1.0;
uniform float opacity = 0.4;
uniform float sink = 0.0;

varying float age;
varying float seed;

float h1(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = h1(dot(i, vec2(1.0, 57.0)));
	float b = h1(dot(i + vec2(1.0, 0.0), vec2(1.0, 57.0)));
	float c = h1(dot(i + vec2(0.0, 1.0), vec2(1.0, 57.0)));
	float d = h1(dot(i + vec2(1.0, 1.0), vec2(1.0, 57.0)));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	float f = float(INSTANCE_ID);
	seed = h1(f);
	age = fract(scene_time * rate * (0.8 + 0.4 * h1(f + 1.0)) + h1(f + 2.0));
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec2 r = vec2(h1(f + 3.0) - 0.5, h1(f + 4.0) - 0.5) * spread * (0.5 + age * 2.0);
	vec3 wind = vec3(wind_direction.x, 0.0, wind_direction.y) * wind_strength * age * age * rise * 0.8;
	float up = age * rise * (1.0 - sink) - age * sink * 0.3;
	vec3 centre = origin + vec3(r.x, up, r.y) + wind;
	float visible = step(h1(f + 7.0), amount);
	float size = mix(0.25, 1.6, sqrt(age)) * thickness * (0.7 + 0.6 * h1(f + 6.0)) * visible;
	vec3 c = (VIEW_MATRIX * vec4(centre, 1.0)).xyz;
	float spin = seed * 6.28 + age * 1.5;
	vec2 corner = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * VERTEX.xy;
	VERTEX = c + vec3(corner * size, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float n = vnoise(UV * 4.0 + seed * 10.0) * 0.6 + vnoise(UV * 9.0 - seed * 7.0) * 0.4;
	float shape = (1.0 - smoothstep(0.2, 1.0, length(q))) * (0.55 + 0.45 * n);
	float fade = smoothstep(0.0, 0.15, age) * (1.0 - smoothstep(0.5, 1.0, age));
	ALBEDO = smoke_color.rgb * (0.85 + 0.3 * n);
	ALPHA = shape * fade * opacity;
	BACKLIGHT = smoke_color.rgb * 0.4;
	ROUGHNESS = 1.0;
}

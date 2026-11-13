shader_type spatial;
// Glowing VFX particles: embers, golden dust, fireflies, an energy aura, light
// rays and bursts. Each instance is a camera-facing quad placed from scene_time,
// so every export looks the same. Bright colours bloom when the film's glow is on.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform, fog_disabled;

global uniform float scene_time;
global uniform float wind_strength;
global uniform vec2 wind_direction;

uniform vec4 color_a : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform int mode = 0;          // 0 rise, 1 float, 2 aura, 3 rays, 4 burst
uniform float rate = 0.3;
uniform float spread = 2.0;
uniform float height = 4.0;
uniform float size = 0.05;
uniform float stretch = 0.0;
uniform float intensity = 2.0;
uniform float amount = 1.0;
uniform float blink = 0.0;
uniform float lean = 0.0;

varying float fade;
varying float seed;

float h1(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

void vertex() {
	float f = float(INSTANCE_ID);
	seed = h1(f);
	float t = scene_time;
	float age = fract(t * rate * (0.7 + 0.6 * h1(f + 1.0)) + h1(f + 2.0));
	vec3 origin = MODEL_MATRIX[3].xyz;
	// "disappears" shrinks the object to nothing: hide every particle then.
	float sc = length(MODEL_MATRIX[1].xyz);
	vec3 p = origin;
	vec3 vel = vec3(0.0, 1.0, 0.0);
	float s = size * (0.6 + 0.8 * h1(f + 6.0));
	float long_side = s * max(stretch, 1.0);
	fade = 1.0;
	vec3 wind = vec3(wind_direction.x, 0.0, wind_direction.y) * wind_strength;
	if (mode == 0) {
		// embers: rise, swirl and fade
		vec2 b = vec2(h1(f + 3.0) - 0.5, h1(f + 4.0) - 0.5) * spread;
		float sw = age * 6.0 + seed * 20.0;
		p += vec3(b.x + sin(sw) * 0.35 * age, age * height, b.y + cos(sw * 0.8) * 0.35 * age) + wind * age * height * 0.4;
		fade = smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.55, 1.0, age));
		fade *= 0.6 + 0.4 * sin(t * 13.0 + seed * 50.0);
	} else if (mode == 1) {
		// floating dust / fireflies: drift slowly in a box
		p += vec3((h1(f + 3.0) - 0.5) * spread, h1(f + 5.0) * height, (h1(f + 4.0) - 0.5) * spread);
		p += vec3(sin(t * 0.31 + seed * 30.0), sin(t * 0.43 + seed * 17.0) * 0.5, cos(t * 0.37 + seed * 11.0)) * 0.5;
		p += wind * sin(t * 0.2 + seed * 9.0) * 0.4;
		fade = 0.55 + 0.45 * sin(t * 1.3 + seed * 40.0);
		if (blink > 0.0) {
			fade = mix(fade, pow(max(sin(t * 2.1 + seed * 60.0), 0.0), 6.0), blink);
		}
		vel = vec3(0.0);
	} else if (mode == 2) {
		// energy aura: streaks spiral up around a column
		float ang = seed * 6.2832 + age * 2.2 * (h1(f + 8.0) > 0.5 ? 1.0 : -1.0);
		float r = spread * (0.55 + 0.45 * h1(f + 3.0)) * (1.0 - age * 0.35);
		p += vec3(cos(ang) * r, age * height, sin(ang) * r);
		fade = sin(age * 3.14159);
		fade *= fade;
	} else if (mode == 3) {
		// light rays: tall soft beams that breathe
		p += vec3((h1(f + 3.0) - 0.5) * spread, height * 0.5, (h1(f + 4.0) - 0.5) * spread);
		long_side = height;
		s = size * (0.5 + h1(f + 6.0));
		fade = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (0.25 + 0.3 * seed) + seed * 30.0));
		vel = normalize(vec3(lean, 1.0, lean * 0.4));
	} else {
		// burst: sparks fly out from the centre, slow down and fall
		vec3 d = normalize(vec3(h1(f + 3.0) - 0.5, h1(f + 5.0) * 0.8 + 0.05, h1(f + 4.0) - 0.5));
		float k = 1.0 - pow(1.0 - age, 3.0);
		p += d * spread * k + vec3(0.0, height * 0.25 - age * age * height * 0.25, 0.0);
		vel = d * (1.0 - age) + vec3(0.0, -age, 0.0);
		fade = (1.0 - age) * (1.0 - age);
	}
	float visible = step(h1(f + 7.0), amount) * step(0.05, sc);
	p = origin + (p - origin) * sc;
	vec3 c = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	vec2 corner;
	vec3 v = (VIEW_MATRIX * vec4(vel, 0.0)).xyz;
	if ((stretch > 0.0 || mode == 3) && length(v.xy) > 0.001) {
		vec2 along = normalize(v.xy);
		vec2 side = vec2(-along.y, along.x);
		corner = side * VERTEX.x * s + along * VERTEX.y * long_side;
	} else {
		corner = VERTEX.xy * s;
	}
	VERTEX = c + vec3(corner * visible * sc, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float shape;
	if (mode == 3) {
		shape = pow(1.0 - abs(q.x), 2.5) * (1.0 - smoothstep(0.3, 1.0, abs(q.y)));
	} else {
		float d = dot(q, q);
		shape = exp(-d * 5.0) + exp(-d * 40.0) * 0.8;
	}
	vec3 col = mix(color_a.rgb, color_b.rgb, seed);
	ALBEDO = col * intensity;
	ALPHA = clamp(shape * fade, 0.0, 1.0);
}

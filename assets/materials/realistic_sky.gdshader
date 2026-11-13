shader_type sky;
// Physically-inspired sky: horizon gradient, sun disc with glow, drifting
// volumetric-looking clouds lit by the sun, and stars at night.
// Colours come from EnvironmentController (time of day / custom colours).
// Cloud motion uses cloud_shift (set from timeline time), never TIME, so
// playback and exported video always match.
render_mode use_debanding;

uniform vec3 top_color : source_color = vec3(0.26, 0.46, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.68, 0.76, 0.86);
uniform vec3 ground_color : source_color = vec3(0.2, 0.2, 0.2);
uniform float sky_energy = 1.0;
uniform float sun_size = 0.02;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.35;
uniform float cloud_shift = 0.0;
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform float stars : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
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
	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 col;
	if (h >= 0.0) {
		float blend = pow(1.0 - h, 4.0);
		col = mix(top_color, horizon_color, blend);
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}

	float cloud_amount = 0.0;
	if (h > 0.0 && cloud_cover > 0.001) {
		vec2 uv = dir.xz / (h + 0.15) * 0.5 + vec2(cloud_shift, cloud_shift * 0.35);
		float n = fbm(uv * 1.4);
		float detail = fbm(uv * 4.0 + 3.0);
		float shape = n * 0.8 + detail * 0.2;
		cloud_amount = smoothstep(1.0 - cloud_cover * 0.85 - 0.15, 1.0 - cloud_cover * 0.85 + 0.12, shape);
		cloud_amount *= smoothstep(0.0, 0.18, h);
		float thickness = clamp((shape - (1.0 - cloud_cover)) * 2.5, 0.0, 1.0);
		vec3 sunlit = LIGHT0_ENABLED ? LIGHT0_COLOR * clamp(LIGHT0_ENERGY, 0.0, 1.6) : vec3(0.1);
		vec3 shade = mix(horizon_color * 0.55, horizon_color * 0.25 + vec3(0.04), thickness);
		vec3 cloud_col = mix(vec3(0.9) * (0.35 + 0.65 * daylight), shade, thickness * 0.65) + sunlit * 0.18 * (1.0 - thickness);
		col = mix(col, cloud_col, cloud_amount * 0.95);
	}

	if (LIGHT0_ENABLED && h > -0.05) {
		float d = clamp(dot(dir, LIGHT0_DIRECTION), -1.0, 1.0);
		float angle = acos(d);
		float disc = 1.0 - smoothstep(sun_size * 0.7, sun_size, angle);
		float glow = pow(max(d, 0.0), 180.0) * 0.6 + pow(max(d, 0.0), 6.0) * 0.12;
		col += LIGHT0_COLOR * LIGHT0_ENERGY * (disc * 30.0 * (1.0 - cloud_amount) + glow * (1.0 - cloud_amount * 0.6));
	}

	if (stars > 0.001 && h > 0.0) {
		vec2 cell = floor(vec2(atan(dir.x, dir.z) * 220.0, h * 330.0));
		float s = hash(cell);
		float twinkle = step(0.9975, s) * (0.6 + 0.4 * hash(cell + 3.7));
		col += vec3(twinkle) * stars * (1.0 - cloud_amount) * smoothstep(0.0, 0.2, h);
	}

	COLOR = col * sky_energy;
}

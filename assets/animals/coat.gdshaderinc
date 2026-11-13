// Shared coat colouring for animal bodies and their fur shells.
// pcoord: (forward, up, side) / height (from UV, UV2); masks: R second colour, G points, B fur.

float a_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float a_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(a_hash(i + vec3(0, 0, 0)), a_hash(i + vec3(1, 0, 0)), f.x),
				   mix(a_hash(i + vec3(0, 1, 0)), a_hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(a_hash(i + vec3(0, 0, 1)), a_hash(i + vec3(1, 0, 1)), f.x),
				   mix(a_hash(i + vec3(0, 1, 1)), a_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float a_fbm(vec3 p) {
	return a_noise(p) * 0.55 + a_noise(p * 2.03 + 7.1) * 0.3 + a_noise(p * 4.1 + 3.3) * 0.15;
}

// Distance to the nearest random point (spots).
float a_cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d = 9.0;
	for (int z = -1; z <= 1; z++)
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 r = o + vec3(a_hash(i + o), a_hash(i + o + 13.7), a_hash(i + o + 29.1)) - f;
		d = min(d, length(r));
	}
	return d;
}

vec3 coat_colour(vec3 pc, vec3 m, vec3 c1, vec3 c2, int pattern, float seed) {
	vec3 p = pc + vec3(seed, seed * 0.37, 0.0);
	vec3 q = vec3(pc.x, pc.y, abs(pc.z)) + vec3(seed);  // mirrored left/right for symmetric markings
	vec3 c = c1;
	if (pattern == 1) {            // two-tone: lighter belly, chest, muzzle
		c = mix(c1, c2, smoothstep(0.25, 0.6, m.r));
	} else if (pattern == 2) {     // spots
		float s = a_cells(p * 9.0 + a_noise(p * 14.0) * 0.4);
		c = mix(c2, c1, smoothstep(0.28, 0.36, s));
	} else if (pattern == 3) {     // patches (cows, dogs)
		float n = a_fbm(p * 3.2) + a_noise(p * 11.0) * 0.12;
		c = mix(c1, c2, smoothstep(0.52, 0.56, n));
	} else if (pattern == 4) {     // stripes (tigers, tabby cats)
		float warp = a_fbm(q * vec3(2.0, 3.0, 2.0)) * 1.4;
		float band = sin((q.x * 38.0 + q.y * 8.0 + warp * 7.0));
		float thick = mix(0.9, 0.62, a_noise(q * 5.0));
		float stripe = smoothstep(thick, thick + 0.08, band) * (1.0 - smoothstep(0.3, 0.7, m.r)) * (1.0 - m.g * 0.3);
		c = mix(c1, c2, smoothstep(0.3, 0.65, m.r));
		c = mix(c, c1 * 0.12, stripe);
	} else if (pattern == 5) {     // points: darker legs, ears, face, tail
		c = mix(c1, c2, smoothstep(0.2, 0.75, m.g));
	} else if (pattern == 6) {     // dapples
		float s = a_cells(q * 7.0);
		c = mix(c1 * 0.78, c1 * 1.12, smoothstep(0.2, 0.5, s));
		c = mix(c, c2, smoothstep(0.4, 0.9, m.g));
	}
	// natural countershading and a little unevenness
	c *= mix(0.92, 1.06, smoothstep(0.0, 0.6, m.r)) * (0.9 + 0.2 * a_noise(p * 18.0));
	return c;
}

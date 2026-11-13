// Scene Builder animals: coat colours, pattern and the body's other parts.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://assets/animals/coat.gdshaderinc"

uniform int part = 0;          // 0 coat, 1 horn/hoof, 2 nose/skin, 3 eye, 4 beak/feet, 5 comb
uniform vec3 color : source_color = vec3(0.55, 0.4, 0.28);
uniform vec3 color2 : source_color = vec3(0.92, 0.88, 0.82);
uniform int pattern = 0;
uniform float seed = 0.0;
uniform vec3 eye_color : source_color = vec3(0.23, 0.14, 0.06);
uniform vec3 base : source_color = vec3(0.5);

varying vec3 pcoord;
varying vec3 masks;

void vertex() {
	pcoord = vec3(UV.x, UV.y, UV2.x);
	masks = COLOR.rgb;
}

void fragment() {
	vec3 c;
	float rough = 0.85;
	float spec = 0.3;
	if (part == 0) {
		c = coat_colour(pcoord, masks, color, color2, pattern, seed);
		c *= 0.82;  // the body under the fur is a little darker
	} else if (part == 1) {
		float g = a_noise(vec3(UV * vec2(6.0, 40.0), 0.0));
		c = base * (0.8 + 0.35 * g) * mix(1.0, 0.75, smoothstep(0.6, 1.0, UV.y));
		rough = 0.45;
		spec = 0.4;
	} else if (part == 2) {
		c = mix(vec3(0.05, 0.045, 0.045), color * 0.4, 0.15) * (0.8 + 0.4 * a_noise(pcoord * 300.0));
		rough = 0.38;
		spec = 0.5;
	} else if (part == 3) {
		float d = length(UV - vec2(0.5)) * 2.0;
		c = mix(eye_color * (0.7 + 0.5 * smoothstep(0.3, 0.75, d)), vec3(0.02), smoothstep(0.44, 0.38, d));
		c = mix(c, vec3(0.05, 0.035, 0.03), smoothstep(0.8, 0.92, d));
		rough = 0.05;
		spec = 0.8;
		CLEARCOAT = 1.0;
		CLEARCOAT_ROUGHNESS = 0.03;
	} else if (part == 4) {
		c = base * (0.85 + 0.25 * a_noise(pcoord * 80.0));
		rough = 0.55;
	} else {
		c = base * (0.85 + 0.3 * a_noise(pcoord * 60.0));
		rough = 0.6;
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
}

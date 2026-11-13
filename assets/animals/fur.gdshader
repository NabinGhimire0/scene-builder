// Fur shells for animals: each layer is the body pushed out along its normal,
// with only the strands that reach that high drawn.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
#include "res://assets/animals/coat.gdshaderinc"

uniform vec3 color : source_color = vec3(0.55, 0.4, 0.28);
uniform vec3 color2 : source_color = vec3(0.92, 0.88, 0.82);
uniform int pattern = 0;
uniform float seed = 0.0;
uniform float layer = 0.5;          // 0 skin .. 1 tips
uniform float fur_length = 0.02;    // metres
uniform float density = 260.0;      // strands per height unit
uniform vec3 comb = vec3(0.0, -0.45, -0.9);

varying vec3 pcoord;
varying vec3 masks;

void vertex() {
	pcoord = vec3(UV.x, UV.y, UV2.x);
	masks = COLOR.rgb;
	float len = fur_length * masks.b;
	VERTEX += (NORMAL * layer + normalize(comb) * layer * layer * 0.55) * len;
}

void fragment() {
	vec3 cell = floor(pcoord * density);
	vec3 f = fract(pcoord * density) - 0.5;
	float h = a_hash(cell + seed);
	float r = length(f) * 2.0;
	float strand = step(r, (1.0 - layer * 0.85)) * step(layer, h * 1.15);
	if (masks.b < 0.03) {
		strand = 0.0;
	}
	vec3 c = coat_colour(pcoord, masks, color, color2, pattern, seed);
	c *= mix(0.55, 1.08, layer) * (0.9 + 0.2 * h);
	ALBEDO = c;
	ALPHA = strand;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	BACKLIGHT = c * 0.25;
}

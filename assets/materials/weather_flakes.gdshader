shader_type spatial;
// Snowflakes (mode 0) and falling, tumbling leaves (mode 1). Lit by the scene,
// so they darken at night.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

#include "res://assets/materials/weather_common.gdshaderinc"

global uniform float snow_amount;
global uniform float leaves_amount;

uniform int mode = 0;
uniform float box = 30.0;
uniform float height = 18.0;

varying float fade;
varying vec3 leaf_color;

void vertex() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float f = float(INSTANCE_ID);
	bool leaf = mode == 1;
	vec3 centre = weather_position(INSTANCE_ID, cam, box, height, leaf ? 1.4 : 1.1, leaf ? 3.0 : 2.0);
	float sway = scene_time * (0.6 + whash(f + 9.0)) + f;
	centre.x += sin(sway) * (leaf ? 0.6 : 0.3);
	centre.z += cos(sway * 0.8) * (leaf ? 0.6 : 0.3);
	float amount = leaf ? leaves_amount : snow_amount;
	float visible = step(whash(f + 71.0), amount) * step(0.0001, amount);
	float size = leaf ? 0.07 + 0.05 * whash(f + 2.0) : 0.018 + 0.02 * whash(f + 2.0);
	vec3 c = (VIEW_MATRIX * vec4(centre, 1.0)).xyz;
	vec2 corner = VERTEX.xy;
	if (leaf) {
		float spin = scene_time * (1.5 + 2.0 * whash(f + 4.0)) + f;
		corner = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * corner;
		corner.y *= 0.4 + 0.6 * abs(sin(spin * 0.7));
	}
	VERTEX = (c + vec3(corner * size * 2.0, 0.0)) * visible;
	NORMAL = vec3(0.0, 0.0, 1.0);
	float d = length(centre.xz - cam.xz) / (box * 0.5);
	fade = (1.0 - smoothstep(0.6, 1.0, d)) * visible;
	float hue = whash(f + 13.0);
	leaf_color = mix(mix(vec3(0.55, 0.18, 0.05), vec3(0.75, 0.45, 0.08), hue), vec3(0.45, 0.42, 0.12), step(0.8, hue));
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	if (mode == 1) {
		float shape = 1.0 - smoothstep(0.75, 1.0, length(q * vec2(1.0, 1.7)));
		ALBEDO = leaf_color;
		ALPHA = shape * fade;
		BACKLIGHT = leaf_color * 0.5;
	} else {
		ALBEDO = vec3(0.95);
		ALPHA = (1.0 - smoothstep(0.2, 1.0, length(q))) * 0.9 * fade;
	}
	ROUGHNESS = 0.9;
}

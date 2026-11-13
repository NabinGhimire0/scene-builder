shader_type spatial;
// The Cartoon look's ground and indoor floor: like cartoon_world, but they write no depth,
// so the screen-space outline doesn't draw lines across the grass at grazing angles.
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never;

uniform int part = 0;               // 0 = sky, 1 = ground, 2 = flat colour
uniform vec4 top_color : source_color = vec4(0.36, 0.66, 0.88, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.78, 0.9, 0.95, 1.0);
uniform vec4 near_color : source_color = vec4(0.52, 0.78, 0.32, 1.0);
uniform vec4 far_color : source_color = vec4(0.62, 0.8, 0.52, 1.0);
uniform float sky_height = 30.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c;
	if (part == 0) {
		float k = smoothstep(-2.0, sky_height, world.y);
		c = mix(horizon_color.rgb, top_color.rgb, k);
	} else if (part == 1) {
		float k = smoothstep(-1.0, -140.0, world.z);
		c = mix(near_color.rgb, far_color.rgb, k);
		// Soft mown stripes in the near grass, like a drawn lawn.
		float stripe = step(0.5, fract(world.z * 0.25)) * (1.0 - k);
		c *= 1.0 - 0.045 * stripe;
	} else {
		c = near_color.rgb;
	}
	ALBEDO = c;
}

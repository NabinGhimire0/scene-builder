shader_type spatial;
// Editor-only grid drawn as a transparent overlay just above the ground.
// It lives on the editor-only visual layer, so it never shows in Camera View
// or exported video. cell_size follows the snap step.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.13);
uniform vec4 major_line_color : source_color = vec4(1.0, 1.0, 1.0, 0.26);
uniform vec4 x_axis_color : source_color = vec4(0.95, 0.35, 0.35, 0.8);
uniform vec4 z_axis_color : source_color = vec4(0.35, 0.55, 1.0, 0.8);
uniform float cell_size = 1.0;
uniform int major_every = 10;
uniform float fade_distance = 90.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(vec2 p, float size) {
	vec2 coord = p / size;
	vec2 width = fwidth(coord);
	vec2 g = abs(fract(coord - 0.5) - 0.5) / max(width, vec2(1e-5));
	return 1.0 - min(min(g.x, g.y), 1.0);
}

float axis_line(float v) {
	return 1.0 - min(abs(v) / max(fwidth(v) * 1.5, 1e-5), 1.0);
}

void fragment() {
	float minor = grid_line(world_pos.xz, cell_size);
	float major = grid_line(world_pos.xz, cell_size * float(max(major_every, 1)));
	vec4 col = vec4(line_color.rgb, line_color.a * minor);
	col = mix(col, major_line_color, major * major_line_color.a);
	col = mix(col, x_axis_color, axis_line(world_pos.z));
	col = mix(col, z_axis_color, axis_line(world_pos.x));
	float dist = length(world_pos.xz - CAMERA_POSITION_WORLD.xz);
	ALBEDO = col.rgb;
	ALPHA = col.a * (1.0 - smoothstep(fade_distance * 0.6, fade_distance, dist));
}

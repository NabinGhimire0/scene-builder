shader_type spatial;
// Inverted-hull outline drawn as a material overlay on the selected object.
// The shell is pushed out along the normal in screen space, so the outline
// keeps a constant pixel width at any zoom level.
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 outline_color : source_color = vec4(1.0, 0.62, 0.15, 1.0);
uniform float outline_width_px = 2.5;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	float len = length(dir);
	if (len > 0.0001) {
		clip.xy += (dir / len) * outline_width_px * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}

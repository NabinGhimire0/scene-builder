shader_type spatial;
// The emotion glow around a story person (anger red, calm blue...): the body
// grown outwards and pushed back behind it, so it only shows around the
// silhouette, never over the person's own clothes.
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled, skip_vertex_transform, fog_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.25, 0.15, 0.5);
uniform float grow = 0.02;
uniform float push = 0.35;

void vertex() {
	vec3 p = (MODELVIEW_MATRIX * vec4(VERTEX + NORMAL * grow, 1.0)).xyz;
	// Back along the line of sight: same size on screen, but behind the body.
	p += normalize(p) * push;
	VERTEX = p;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	ALBEDO = glow_color.rgb;
	ALPHA = glow_color.a;
}

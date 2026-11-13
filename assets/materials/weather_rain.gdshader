shader_type spatial;
// Falling rain streaks (slanted by the wind).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform, fog_disabled;

#include "res://assets/materials/weather_common.gdshaderinc"

global uniform float rain_amount;

uniform float box = 36.0;
uniform float height = 22.0;
uniform vec4 tint : source_color = vec4(0.75, 0.8, 0.88, 1.0);

varying float fade;

void vertex() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float f = float(INSTANCE_ID);
	vec3 centre = weather_position(INSTANCE_ID, cam, box, height, 9.0, 3.5);
	float visible = step(whash(f + 71.0), rain_amount) * step(0.0001, rain_amount);
	vec3 slant = normalize(vec3(-wind_direction.x * wind_strength * 0.45, 1.0, -wind_direction.y * wind_strength * 0.45));
	vec3 c = (VIEW_MATRIX * vec4(centre, 1.0)).xyz;
	vec3 up = (VIEW_MATRIX * vec4(slant, 0.0)).xyz;
	vec3 side = normalize(cross(up, vec3(0.0, 0.0, 1.0)));
	VERTEX = c + side * VERTEX.x * 0.012 + up * VERTEX.y * (0.5 + 0.3 * whash(f + 3.0));
	VERTEX *= visible;
	float d = length(centre.xz - cam.xz) / (box * 0.5);
	fade = (1.0 - smoothstep(0.6, 1.0, d)) * visible;
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = smoothstep(0.0, 0.4, UV.y) * smoothstep(1.0, 0.6, UV.y);
	ALBEDO = tint.rgb;
	ALPHA = across * along * 0.32 * fade;
}

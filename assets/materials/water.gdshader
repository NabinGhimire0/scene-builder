shader_type spatial;
// Realistic water for ponds, lakes, rivers and the sea.
//  • Waves: a sum of travelling waves moved in the vertex shader.
//  • Ripples: two scrolling normal maps (along the river for flowing water).
//  • Colour: light is absorbed with depth, so shallow water shows the bed and
//    deep water turns dark; the scene behind is refracted.
//  • Foam: at the shore, on wave crests, in fast river water and in breaking
//    lines that roll onto a beach.
// Everything moves with the global scene_time (timeline time while playing or
// exporting), so the exported video matches the preview.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, skip_vertex_transform;

#include "res://assets/materials/water_common.gdshaderinc"

global uniform float scene_time;

uniform vec4 shallow_color : source_color = vec4(0.32, 0.58, 0.55, 1.0);
uniform vec4 deep_color : source_color = vec4(0.03, 0.13, 0.17, 1.0);
uniform float clarity = 2.5;
uniform float depth_m = 3.0;
uniform float shelf = 2.0;
uniform int shape = 0;
uniform vec2 size_m = vec2(10.0, 10.0);
uniform float seed = 0.0;
uniform float wave_height = 0.03;
uniform float wave_length = 3.0;
uniform float wave_speed = 1.0;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float ripple_size = 1.0;
uniform float ripple_strength = 0.6;
uniform float flow_speed = 0.0;
uniform bool flowing = false;
uniform float foam_amount = 0.5;
uniform float shore_waves = 0.0;
uniform float refraction = 0.05;
uniform float view_bias = 0.996;
uniform bool use_scene_depth = false;
uniform sampler2D ripple_a : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ripple_b : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foam_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 world_tangent;
varying vec2 local_p;
varying float crest;

void vertex() {
	local_p = UV;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
	world_tangent = normalize(mat3(MODEL_MATRIX) * TANGENT);
	crest = 0.0;
	if (wave_height > 0.0001) {
		float damp = clamp(water_edge(UV, shape, size_m, seed) / max(wave_length, 0.5), 0.0, 1.0);
		vec2 base = normalize(wind_dir + vec2(0.0001));
		float h = 0.0;
		vec2 slope = vec2(0.0);
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			float ang = (fi - 1.5) * 0.45;
			vec2 d = vec2(base.x * cos(ang) - base.y * sin(ang), base.x * sin(ang) + base.y * cos(ang));
			float len = max(wave_length * (1.6 - fi * 0.3), 0.2);
			float k = 6.2831853 / len;
			float omega = sqrt(9.81 * k) * wave_speed;
			float amp = wave_height * (1.0 - fi * 0.18) * 0.5;
			float ph = k * dot(d, wp.xz) - omega * scene_time + fi * 1.7 + seed;
			h += amp * sin(ph);
			slope += amp * k * cos(ph) * d;
		}
		h *= damp;
		slope *= damp;
		// Lifted by the wave height (less near the shore) so troughs stay above the ground.
		wp.y += h + wave_height * 0.75 * damp;
		crest = h / max(wave_height, 0.0001);
		wn = normalize(vec3(-slope.x, 1.0, -slope.y));
	}
	world_pos = wp;
	world_normal = wn;
	// Drawn a hair closer to the camera so it never flickers against the ground.
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz * view_bias;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}

void fragment() {
	float edge = water_edge(local_p, shape, size_m, seed);
	if (edge < -0.02) {
		discard;
	}
	float t = scene_time;
	vec3 wn = normalize(world_normal);
	vec3 across = world_tangent - wn * dot(world_tangent, wn);
	across = length(across) > 0.001 ? normalize(across) : vec3(1.0, 0.0, 0.0);
	vec3 along = cross(across, wn);

	// Ripples.
	vec2 p;
	vec2 ra;
	vec2 rb;
	float rs = max(ripple_size, 0.05);
	if (flowing) {
		p = local_p;
		ra = vec2(p.x * 0.7, p.y * 0.45 - t * flow_speed * 0.9) / (2.5 * rs);
		rb = vec2(p.x * 0.9 + 0.37, p.y * 0.7 - t * flow_speed * 1.25) / (1.1 * rs);
	} else {
		p = world_pos.xz;
		vec2 w = normalize(wind_dir + vec2(0.0001));
		ra = p / (3.2 * rs) + w * t * 0.035 * wave_speed;
		rb = p.yx / (1.3 * rs) - w.yx * t * 0.05 * wave_speed + vec2(0.31, 0.17);
	}
	vec3 na = texture(ripple_a, ra).xyz * 2.0 - 1.0;
	vec3 nb = texture(ripple_b, rb).xyz * 2.0 - 1.0;
	vec2 bump = (na.xy + nb.xy) * ripple_strength * 0.5;
	vec3 n = normalize(wn + across * bump.x + along * bump.y);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// Depth of water under this point: from the shape (flat ground), or the
	// real distance to what's behind the surface.
	float depth = depth_m * (1.0 - exp(-max(edge, 0.0) / max(shelf, 0.05)));
	float surface_z = -VERTEX.z;
	if (use_scene_depth) {
		float d = texture(depth_texture, SCREEN_UV).r;
		vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
		depth = max(-sv.z / sv.w - surface_z, 0.0);
	}

	// Refraction (ignoring anything in front of the water).
	vec2 ruv = SCREEN_UV + bump * refraction * clamp(depth, 0.0, 1.0);
	float rd = texture(depth_texture, ruv).r;
	vec4 rv = INV_PROJECTION_MATRIX * vec4(ruv * 2.0 - 1.0, rd, 1.0);
	if (-rv.z / rv.w < surface_z) {
		ruv = SCREEN_UV;
	}
	float through = exp(-depth / max(clarity, 0.05));
	vec3 behind = textureLod(screen_texture, ruv, clamp(depth / max(clarity, 0.05), 0.0, 3.0)).rgb;
	vec3 body = mix(deep_color.rgb, shallow_color.rgb, through);
	vec3 transmitted = behind * mix(shallow_color.rgb, vec3(1.0), through * 0.6) * through;

	// Foam.
	float f1 = texture(foam_tex, p * 0.35 + vec2(t * 0.02, 0.0)).r;
	float f2 = texture(foam_tex, p * 0.9 - vec2(0.0, t * 0.03)).r;
	float pattern = f1 * 0.6 + f2 * 0.4;
	float foam = 0.0;
	float shore = 1.0 - smoothstep(0.0, 0.25 + foam_amount * 0.6, edge);
	foam = max(foam, shore * smoothstep(0.35, 0.65, pattern + shore * 0.3));
	foam = max(foam, smoothstep(0.45, 0.8, crest) * smoothstep(0.4, 0.7, pattern));
	if (flowing) {
		float streak = texture(foam_tex, vec2(p.x * 0.7, p.y * 0.12 - t * flow_speed * 0.12)).r;
		float rapid = clamp(abs(flow_speed) / 4.0, 0.0, 1.0);
		foam = max(foam, smoothstep(0.78 - rapid * 0.25, 0.95, streak) * (0.25 + rapid));
	}
	if (shore_waves > 0.0) {
		float band = sin(edge * 0.9 + t * 1.6 + pattern * 3.0);
		float lines = smoothstep(0.86, 0.98, band) * (1.0 - smoothstep(4.0, 22.0, edge));
		foam = max(foam, lines * smoothstep(0.3, 0.6, pattern) * shore_waves);
	}
	foam = clamp(foam * clamp(foam_amount * 1.6, 0.0, 1.0), 0.0, 1.0);

	ALBEDO = mix(body * (1.0 - through), vec3(0.92), foam);
	EMISSION = transmitted * (1.0 - foam);
	ROUGHNESS = mix(0.02, 0.55, foam);
	SPECULAR = 0.5;
	METALLIC = 0.0;
	ALPHA = smoothstep(-0.02, 0.12, edge);
}

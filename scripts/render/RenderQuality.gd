class_name RenderQuality
extends RefCounted
## Render quality presets.
##
##  • Preview   – fast editing on modest laptops.
##  • High      – global illumination (SDFGI), ambient occlusion, screen-space
##                reflections, bloom, volumetric fog, 4-split sun shadows.
##  • Cinematic – everything in High plus indirect-light AO (SSIL), soft
##                contact-hardening sun shadows, bigger shadow maps, TAA.
##                Video export uses this by default.

enum Level { PREVIEW, HIGH, CINEMATIC }

const NAMES: PackedStringArray = ["Preview (fastest)", "High", "Cinematic (best, slower)"]
const HINTS: PackedStringArray = [
	"Fast: basic lighting. Best for building scenes on slower computers.",
	"Realistic lighting: bounce light (GI), ambient occlusion, reflections, bloom, light shafts in fog.",
	"Highest quality: adds softer shadows, indirect-light occlusion and temporal anti-aliasing. Heavy on the GPU.",
]
## Frames rendered before the first exported frame so GI, fog and TAA settle.
const WARMUP_FRAMES: PackedInt32Array = [2, 24, 48]


static func apply_environment(env: Environment, level: int) -> void:
	if env == null:
		return
	var high := level >= Level.HIGH
	var cinematic := level >= Level.CINEMATIC
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0

	env.ssao_enabled = high
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.8
	env.ssao_detail = 0.6

	env.ssil_enabled = cinematic
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8

	env.ssr_enabled = high
	env.ssr_max_steps = 96 if cinematic else 48
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0

	env.sdfgi_enabled = high
	env.sdfgi_use_occlusion = cinematic
	env.sdfgi_bounce_feedback = 0.5
	env.sdfgi_cascades = 6 if cinematic else 4
	env.sdfgi_min_cell_size = 0.15 if cinematic else 0.25
	env.sdfgi_energy = 1.0

	env.glow_enabled = high
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT


static func apply_viewport(viewport: Viewport, level: int) -> void:
	if viewport == null:
		return
	viewport.msaa_3d = Viewport.MSAA_2X if level == Level.PREVIEW else Viewport.MSAA_4X
	viewport.use_taa = level >= Level.CINEMATIC
	viewport.use_debanding = level >= Level.HIGH
	viewport.mesh_lod_threshold = 2.0 if level == Level.PREVIEW else 0.5
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED


static func apply_sun(sun: DirectionalLight3D, level: int) -> void:
	if sun == null:
		return
	var high := level >= Level.HIGH
	var cinematic := level >= Level.CINEMATIC
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 200.0 if high else 120.0
	sun.light_angular_distance = 0.6 if cinematic else 0.0
	sun.shadow_blur = 1.2 if high else 1.0
	sun.light_volumetric_fog_energy = 1.0
	RenderingServer.directional_shadow_atlas_set_size(8192 if cinematic else 4096, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH if cinematic else RenderingServer.SHADOW_QUALITY_SOFT_LOW)

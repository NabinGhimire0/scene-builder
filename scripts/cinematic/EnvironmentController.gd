class_name EnvironmentController
extends Node
## Lighting, sky, atmosphere, ground and render quality.
##
## Every value is a plain property with a setter that updates the scene at once,
## so the timeline can animate them (a sunset, clouds rolling in, fog lifting)
## and video export renders them frame-accurately.
##
##  • Sky: a realistic shader sky (sun, glow, drifting clouds, stars at night)
##    coloured by the time of day, custom colours, or a real photo sky (HDRI).
##  • Ground: procedural PBR styles (grass, dirt, sand, snow, rock, asphalt…),
##    a plain colour, or a downloaded photo texture.
##  • Fog: volumetric (with light shafts) at High/Cinematic quality.
##  • Render quality: see [RenderQuality].

signal changed

enum SkyMode { AUTOMATIC, CUSTOM, PHOTO }

const SKY_SHADER := preload("res://assets/materials/realistic_sky.gdshader")
const GROUND_SHADER := preload("res://assets/materials/realistic_ground.gdshader")

const DEFAULTS := {
	"time_of_day": 14.0,
	"sun_azimuth": 200.0,
	"sun_intensity": 1.0,
	"shadow_strength": 0.85,
	"sky_mode": SkyMode.AUTOMATIC,
	"sky_top_color": Color(0.3, 0.47, 0.74),
	"sky_horizon_color": Color(0.66, 0.72, 0.8),
	"cloud_cover": 0.35,
	"cloud_speed": 1.0,
	"hdri_path": "",
	"hdri_id": "",
	"hdri_rotation": 0.0,
	"hdri_energy": 1.0,
	"fog_density": 0.0,
	"ambient_energy": 1.0,
	"exposure": 1.0,
	"ground_style": "Grass",
	"ground_color": Color(0.33, 0.4, 0.27),
	"ground_texture": "",
	"ground_texture_id": "",
	"ground_tile": 3.0,
	"render_quality": RenderQuality.Level.HIGH,
	"wind": 0.3,
	"wind_direction": 40.0,
	"rain": 0.0,
	"snow": 0.0,
	"mist": 0.0,
	"leaves": 0.0,
	"snow_cover": 0.0,
	"autumn": 0.0,
	"flat_background": Color(0, 0, 0, 0),
	"flat_sky": Color(0, 0, 0, 0),
	"look": "Realistic",
	"bloom": 0.0,
	"contrast": 1.0,
	"saturation": 1.0,
}
const LOOKS: PackedStringArray = ["Realistic", "Flat sketch", "Paper", "Cartoon", "Sketchbook"]
## Properties the timeline keyframes on the "lighting" channel.
const ANIMATED: PackedStringArray = [
	"time_of_day", "sun_azimuth", "sun_intensity", "shadow_strength",
	"sky_top_color", "sky_horizon_color", "cloud_cover", "hdri_rotation", "hdri_energy",
	"fog_density", "ambient_energy", "exposure", "ground_color",
	"wind", "wind_direction", "rain", "snow", "mist", "leaves", "snow_cover", "autumn", "flat_background", "flat_sky",
	"bloom", "contrast", "saturation",
]
const WEATHER_PRESETS := {
	"Clear": {"wind": 0.2, "rain": 0.0, "snow": 0.0, "mist": 0.0, "leaves": 0.0, "snow_cover": 0.0},
	"Breezy": {"wind": 0.6, "rain": 0.0, "snow": 0.0, "mist": 0.0, "leaves": 0.3, "snow_cover": 0.0},
	"Rain": {"wind": 0.5, "rain": 0.7, "snow": 0.0, "mist": 0.25, "leaves": 0.0, "snow_cover": 0.0, "cloud_cover": 0.95, "sun_intensity": 0.45},
	"Storm": {"wind": 1.0, "rain": 1.0, "snow": 0.0, "mist": 0.4, "leaves": 0.5, "snow_cover": 0.0, "cloud_cover": 1.0, "sun_intensity": 0.3},
	"Snowfall": {"wind": 0.25, "rain": 0.0, "snow": 0.7, "mist": 0.3, "leaves": 0.0, "snow_cover": 0.8, "cloud_cover": 0.9, "sun_intensity": 0.6},
	"Misty morning": {"wind": 0.1, "rain": 0.0, "snow": 0.0, "mist": 0.7, "leaves": 0.0, "snow_cover": 0.0, "time_of_day": 7.0},
	"Autumn": {"wind": 0.55, "rain": 0.0, "snow": 0.0, "mist": 0.1, "leaves": 0.8, "snow_cover": 0.0, "autumn": 0.9},
}
const PRESETS := {
	"Morning": {"time_of_day": 7.5, "sun_intensity": 0.9, "fog_density": 0.012, "exposure": 1.05, "cloud_cover": 0.3},
	"Noon": {"time_of_day": 12.5, "sun_intensity": 1.1, "fog_density": 0.0, "exposure": 1.0, "cloud_cover": 0.25},
	"Sunset": {"time_of_day": 18.2, "sun_intensity": 1.0, "fog_density": 0.006, "exposure": 1.15, "cloud_cover": 0.45},
	"Night": {"time_of_day": 23.0, "sun_intensity": 1.0, "fog_density": 0.004, "exposure": 1.4, "cloud_cover": 0.15},
	"Overcast": {"time_of_day": 13.0, "sun_intensity": 0.55, "fog_density": 0.01, "exposure": 1.1, "cloud_cover": 0.95},
}
const SKY_MODE_NAMES: PackedStringArray = ["Realistic sky (follows time of day)", "Custom sky colours", "Photo sky (HDRI)"]
const GROUND_STYLES: PackedStringArray = ["Grass", "Dry grass", "Dirt", "Sand", "Snow", "Rock", "Asphalt", "Plain colour", "Photo texture"]
const GROUND_PRESETS := {
	"Grass": [Color(0.17, 0.29, 0.09), Color(0.27, 0.36, 0.12), Color(0.3, 0.25, 0.15), 0.92, 1.0, 0.25, 0.45, 1.0],
	"Dry grass": [Color(0.42, 0.39, 0.19), Color(0.52, 0.46, 0.26), Color(0.35, 0.29, 0.19), 0.94, 1.0, 0.22, 0.45, 1.0],
	"Dirt": [Color(0.3, 0.22, 0.15), Color(0.38, 0.29, 0.2), Color(0.24, 0.19, 0.13), 0.95, 1.4, 0.2, 0.4, 1.0],
	"Sand": [Color(0.74, 0.64, 0.46), Color(0.8, 0.71, 0.53), Color(0.66, 0.56, 0.4), 0.96, 0.6, 0.2, 0.25, 1.2],
	"Snow": [Color(0.88, 0.9, 0.95), Color(0.95, 0.96, 0.99), Color(0.8, 0.85, 0.92), 0.55, 0.5, 0.55, 0.12, 0.8],
	"Rock": [Color(0.38, 0.37, 0.35), Color(0.49, 0.48, 0.45), Color(0.3, 0.29, 0.28), 0.85, 2.0, 0.3, 0.5, 1.4],
	"Asphalt": [Color(0.12, 0.12, 0.13), Color(0.16, 0.16, 0.17), Color(0.09, 0.09, 0.1), 0.8, 0.4, 0.35, 0.7, 2.5],
}

const TOP_DAY := Color(0.24, 0.45, 0.8)
const TOP_SUNSET := Color(0.3, 0.33, 0.56)
const TOP_NIGHT := Color(0.012, 0.018, 0.05)
const HORIZON_DAY := Color(0.68, 0.77, 0.88)
const HORIZON_SUNSET := Color(0.98, 0.57, 0.34)
const HORIZON_NIGHT := Color(0.04, 0.05, 0.1)
const SUN_WARM := Color(1.0, 0.52, 0.28)
const SUN_WHITE := Color(1.0, 0.96, 0.9)
const MOON_COLOR := Color(0.62, 0.72, 1.0)

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var ground_mesh: MeshInstance3D
## The editor's 3D SubViewport (render quality applies to it).
@export var editor_viewport: SubViewport
@export var terrain: Terrain

## Hour of the day, 0–24 (12 = noon, 18 ≈ sunset).
var time_of_day: float = DEFAULTS["time_of_day"]:
	set(v):
		time_of_day = clampf(v, 0.0, 24.0)
		_apply()
## Compass direction (degrees) the sun shines from at noon.
var sun_azimuth: float = DEFAULTS["sun_azimuth"]:
	set(v):
		sun_azimuth = v
		_apply()
var sun_intensity: float = DEFAULTS["sun_intensity"]:
	set(v):
		sun_intensity = maxf(v, 0.0)
		_apply()
var shadow_strength: float = DEFAULTS["shadow_strength"]:
	set(v):
		shadow_strength = clampf(v, 0.0, 1.0)
		_apply()
var sky_mode: int = DEFAULTS["sky_mode"]:
	set(v):
		sky_mode = clampi(int(v), 0, 2)
		_apply_sky_type()
		_apply()
var sky_top_color: Color = DEFAULTS["sky_top_color"]:
	set(v):
		sky_top_color = v
		_apply()
var sky_horizon_color: Color = DEFAULTS["sky_horizon_color"]:
	set(v):
		sky_horizon_color = v
		_apply()
## 0 = clear sky, 1 = fully overcast.
var cloud_cover: float = DEFAULTS["cloud_cover"]:
	set(v):
		cloud_cover = clampf(v, 0.0, 1.0)
		_apply()
## How fast clouds drift (follows the timeline, so exports match previews).
var wind: float = DEFAULTS["wind"]:
	set(v):
		wind = clampf(v, 0.0, 1.0)
		_apply_weather()
var wind_direction: float = DEFAULTS["wind_direction"]:
	set(v):
		wind_direction = wrapf(v, 0.0, 360.0)
		_apply_weather()
var rain: float = DEFAULTS["rain"]:
	set(v):
		rain = clampf(v, 0.0, 1.0)
		_apply_weather()
var snow: float = DEFAULTS["snow"]:
	set(v):
		snow = clampf(v, 0.0, 1.0)
		_apply_weather()
var mist: float = DEFAULTS["mist"]:
	set(v):
		mist = clampf(v, 0.0, 1.0)
		_apply()
var leaves: float = DEFAULTS["leaves"]:
	set(v):
		leaves = clampf(v, 0.0, 1.0)
		_apply_weather()
var snow_cover: float = DEFAULTS["snow_cover"]:
	set(v):
		snow_cover = clampf(v, 0.0, 1.0)
		_apply_weather()
## Flat looks: the colour of the page behind everything (alpha 0 = the look's own).
## Keyable, so a film can move from a warm morning to a blue night.
var flat_background: Color = DEFAULTS["flat_background"]:
	set(v):
		flat_background = v
		if is_flat() and world_environment and world_environment.environment:
			world_environment.environment.background_color = flat_palette()["background"]
		_update_cartoon_world()
## Cartoon look outdoors: the sky colour (alpha 0 = a bright day). A dark sky is night.
var flat_sky: Color = DEFAULTS["flat_sky"]:
	set(v):
		flat_sky = v
		if is_flat() and world_environment and world_environment.environment:
			world_environment.environment.background_color = flat_palette()["background"]
		_update_cartoon_world()

## Autumn colours: 0 = green, 1 = golden trees and dry grass (pines stay green).
var autumn: float = DEFAULTS["autumn"]:
	set(v):
		autumn = clampf(v, 0.0, 1.0)
		_apply_weather()
var cloud_speed: float = DEFAULTS["cloud_speed"]:
	set(v):
		cloud_speed = clampf(v, 0.0, 10.0)
		_update_cloud_shift()
var hdri_path: String = DEFAULTS["hdri_path"]:
	set(v):
		hdri_path = v
		_apply_sky_type()
		_apply()
## Poly Haven id of the HDRI (used to re-download it on another computer).
var hdri_id: String = DEFAULTS["hdri_id"]
var hdri_rotation: float = DEFAULTS["hdri_rotation"]:
	set(v):
		hdri_rotation = v
		_apply()
var hdri_energy: float = DEFAULTS["hdri_energy"]:
	set(v):
		hdri_energy = clampf(v, 0.0, 8.0)
		_apply()
var fog_density: float = DEFAULTS["fog_density"]:
	set(v):
		fog_density = clampf(v, 0.0, 0.2)
		_apply()
var ambient_energy: float = DEFAULTS["ambient_energy"]:
	set(v):
		ambient_energy = maxf(v, 0.0)
		_apply()
var exposure: float = DEFAULTS["exposure"]:
	set(v):
		exposure = clampf(v, 0.05, 8.0)
		_apply()
var ground_style: String = DEFAULTS["ground_style"]:
	set(v):
		ground_style = v if v in GROUND_STYLES else "Grass"
		_apply_ground()
var ground_color: Color = DEFAULTS["ground_color"]:
	set(v):
		ground_color = v
		_apply_ground_color()
var ground_texture: String = DEFAULTS["ground_texture"]:
	set(v):
		ground_texture = v
		_apply_ground()
## Poly Haven id of the ground texture (for re-downloading).
var ground_texture_id: String = DEFAULTS["ground_texture_id"]
## Size in metres of one repeat of the photo texture.
var ground_tile: float = DEFAULTS["ground_tile"]:
	set(v):
		ground_tile = clampf(v, 0.25, 50.0)
		_apply_ground()
## "Realistic" or "Flat sketch" (black void, flat colours, drawn outlines; see SketchLook).
var look: String = DEFAULTS["look"]:
	set(v):
		look = v if v in LOOKS else "Realistic"
		SketchCharacter.lit = look == "Realistic"
		_apply_look()
## Film-look grading: a soft glow around bright things (0 = off … 1 = dreamy),
## contrast and colour strength (1 = as rendered).
var bloom: float = DEFAULTS["bloom"]:
	set(v):
		bloom = clampf(v, 0.0, 1.0)
		_apply()
var contrast: float = DEFAULTS["contrast"]:
	set(v):
		contrast = clampf(v, 0.5, 2.0)
		_apply()
var saturation: float = DEFAULTS["saturation"]:
	set(v):
		saturation = clampf(v, 0.0, 2.0)
		_apply()
var render_quality: int = DEFAULTS["render_quality"]:
	set(v):
		render_quality = clampi(int(v), 0, 2)
		_apply_quality()
		_apply()

var _changed_queued := false
var _quality_override := -1
var _timeline_time := 0.0
var _sky_shader_material: ShaderMaterial
var _panorama_material: PanoramaSkyMaterial
var _ground_shader_material: ShaderMaterial
var _ground_plain_material: StandardMaterial3D
var _hdri_cache: Dictionary = {}
var _texture_cache: Dictionary = {}
## Water, wind and weather move with "scene time": the timeline time while
## playing or exporting (so the video matches), plus a free-running clock while
## you edit so the world still looks alive.
var _idle_clock := 0.0
var _timeline_moving := 0
var _rendering := false


func _ready() -> void:
	_sky_shader_material = ShaderMaterial.new()
	_sky_shader_material.shader = SKY_SHADER
	_panorama_material = PanoramaSkyMaterial.new()
	_ground_shader_material = ShaderMaterial.new()
	_ground_shader_material.shader = GROUND_SHADER
	_ground_plain_material = StandardMaterial3D.new()
	_ground_plain_material.roughness = 0.95
	_apply_quality()
	_apply_sky_type()
	_apply_ground()
	_apply()
	EventBus.render_mode_changed.connect(_on_render_mode_changed)
	add_to_group(&"environment_controller")
	EventBus.prop_placed.connect(_on_prop_placed)
	_apply_weather()
	_apply_look()
	if world_environment:
		var weather := WeatherEffects.new()
		weather.name = "WeatherEffects"
		world_environment.get_parent().add_child.call_deferred(weather)


func is_flat() -> bool:
	return look in SketchLook.LOOKS


## Bloom, contrast and colour strength (the realistic look only).
func _apply_grade(env: Environment) -> void:
	if is_flat():
		env.adjustment_enabled = false
		return
	var high := effective_quality() >= RenderQuality.Level.HIGH
	if bloom > 0.001:
		env.glow_enabled = true
		env.glow_intensity = 0.7 + bloom * 0.9
		env.glow_strength = 1.0 + bloom * 0.2
		env.glow_bloom = 0.03 + bloom * 0.12
		env.glow_hdr_threshold = lerpf(1.1, 0.75, bloom)
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	else:
		env.glow_enabled = high
		env.glow_intensity = 0.7
		env.glow_strength = 1.0
		env.glow_bloom = 0.04
		env.glow_hdr_threshold = 1.1
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = absf(contrast - 1.0) > 0.001 or absf(saturation - 1.0) > 0.001
	env.adjustment_contrast = contrast
	env.adjustment_saturation = saturation
	env.adjustment_brightness = 1.0


## Soft glows for the dark flat look; none on paper (the light page would bloom).
## Called after render quality too, which sets its own glow.
func _apply_flat_glow() -> void:
	if not is_flat() or world_environment == null or world_environment.environment == null:
		return
	var env := world_environment.environment
	env.glow_enabled = bool(flat_palette()["dark"])
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.85


## The colours of the current flat look (background, outline, text…).
func flat_palette() -> Dictionary:
	var colors := SketchLook.palette(look).duplicate()
	if look == SketchLook.CARTOON:
		# Outdoors the page is the sky; indoors (a paper colour is set) it's the wall.
		var sky := cartoon_sky_colors()[0] as Color
		colors["background"] = sky if flat_background.a <= 0.05 else Color(flat_background.r, flat_background.g, flat_background.b)
		return colors
	if flat_background.a > 0.05:
		var bg := Color(flat_background.r, flat_background.g, flat_background.b)
		colors["background"] = bg
		# Text and lines stay readable on a dark page.
		var dark_page := bg.get_luminance() < 0.35
		if dark_page != bool(colors["dark"]):
			colors["text"] = Color(0.93, 0.91, 0.87) if dark_page else Color(0.14, 0.12, 0.11)
			colors["text_outline"] = Color(0, 0, 0) if dark_page else Color(0.97, 0.95, 0.89)
	return colors


## Switches between the realistic world and the Flat sketch look.
func _apply_look() -> void:
	if not is_inside_tree() or world_environment == null or world_environment.environment == null:
		return
	var flat := is_flat()
	var env := world_environment.environment
	if terrain:
		terrain.visible = not flat
	if ground_mesh:
		ground_mesh.visible = not flat
	if sun:
		sun.visible = not flat
	var holder := world_environment.get_parent()
	var outline := holder.get_node_or_null("SketchOutline")
	if flat:
		var colors := flat_palette()
		env.background_mode = Environment.BG_COLOR
		env.background_color = colors["background"]
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color.WHITE
		_apply_flat_glow()
		if outline == null:
			outline = SketchLook.make_outline()
			holder.add_child(outline)
		SketchLook.style_outline(outline as MeshInstance3D, look)
		if look == SketchLook.CARTOON:
			_ensure_cartoon_world()
		else:
			_remove_cartoon_world()
	else:
		_remove_cartoon_world()
		env.glow_enabled = false
		if outline:
			outline.queue_free()
		_apply_sky_type()
	_restyle_props(flat)
	_apply()
	changed.emit()


## Draws every placed object flat (or gives back its real materials).
func _restyle_props(flat: bool) -> void:
	for root in get_tree().get_nodes_in_group(&"placed_props_root"):
		for child in (root as Node).get_children():
			if child is SketchCharacter or child is GlowSpot:
				continue
			if flat:
				SketchLook.flatten(child, look == SketchLook.CARTOON, look == SketchLook.SKETCHBOOK)
			else:
				SketchLook.unflatten(child)


func _on_prop_placed(node: Node3D, _select_it: bool) -> void:
	if is_flat() and node and not node is SketchCharacter and not node is GlowSpot:
		SketchLook.flatten(node, look == SketchLook.CARTOON, look == SketchLook.SKETCHBOOK)


## Pushes wind, rain, snow and falling leaves to every shader that uses them.
func _apply_weather() -> void:
	var angle := deg_to_rad(wind_direction)
	RenderingServer.global_shader_parameter_set(&"wind_strength", wind)
	RenderingServer.global_shader_parameter_set(&"wind_direction", Vector2(sin(angle), cos(angle)))
	RenderingServer.global_shader_parameter_set(&"rain_amount", rain)
	RenderingServer.global_shader_parameter_set(&"snow_amount", snow)
	RenderingServer.global_shader_parameter_set(&"leaves_amount", leaves)
	RenderingServer.global_shader_parameter_set(&"wetness", clampf(rain * 1.4, 0.0, 1.0))
	RenderingServer.global_shader_parameter_set(&"snow_cover", snow_cover)
	RenderingServer.global_shader_parameter_set(&"autumn", autumn)
	_apply()


func _process(delta: float) -> void:
	if not _rendering:
		if _timeline_moving > 0:
			_timeline_moving -= 1
		else:
			_idle_clock += delta
	_push_scene_time()


func scene_time() -> float:
	return _timeline_time + _idle_clock


func _push_scene_time() -> void:
	SceneClock.now = scene_time()
	_drift_clouds()
	RenderingServer.global_shader_parameter_set(&"scene_time", SceneClock.now)


func _on_render_mode_changed(rendering: bool) -> void:
	_rendering = rendering


# --- Cartoon world ----------------------------------------------------------------

const CARTOON_SHADER := preload("res://assets/materials/cartoon_world.gdshader")
const CARTOON_GROUND_SHADER := preload("res://assets/materials/cartoon_ground.gdshader")
var _cartoon: Node3D
var _cartoon_clouds: Array = []     # [Node3D, base x]


## [top, horizon] of the Cartoon sky: a bright day unless flat_sky is set.
func cartoon_sky_colors() -> Array:
	if flat_sky.a > 0.05:
		var top := Color(flat_sky.r, flat_sky.g, flat_sky.b)
		return [top, top.lerp(Color(1.0, 0.92, 0.85), 0.28)]
	return [Color(0.36, 0.66, 0.88), Color(0.8, 0.92, 0.96)]


func _cartoon_material(part: int, ground: bool = false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CARTOON_GROUND_SHADER if ground else CARTOON_SHADER
	material.render_priority = -10 if ground else 0
	material.set_shader_parameter("part", part)
	return material


func _ensure_cartoon_world() -> void:
	if _cartoon and is_instance_valid(_cartoon):
		_update_cartoon_world()
		return
	var holder := world_environment.get_parent()
	_cartoon = Node3D.new()
	_cartoon.name = "CartoonWorld"
	holder.add_child(_cartoon)
	# The sky: a huge backdrop far behind the stage.
	var sky := MeshInstance3D.new()
	sky.name = "Sky"
	var quad := QuadMesh.new()
	quad.size = Vector2(3000, 1400)
	sky.mesh = quad
	sky.position = Vector3(40, 0, -320)     # reaches far below the horizon (no edge under the grass)
	sky.material_override = _cartoon_material(0)
	_cartoon.add_child(sky)
	# The ground: grass outdoors, a floor indoors (same plane, recoloured).
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 400)
	ground.mesh = plane
	ground.position = Vector3(40, -0.002, -100)
	ground.material_override = _cartoon_material(1, true)
	_cartoon.add_child(ground)
	var floor := MeshInstance3D.new()
	floor.name = "Floor"
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(3000, 60)
	floor.mesh = floor_plane
	floor.position = Vector3(40, -0.001, 28.4)     # from z -1.6 forwards
	floor.material_override = _cartoon_material(2, true)
	_cartoon.add_child(floor)
	# Two bands of rolling hills.
	for band in [[-150.0, 9.0, 0], [-95.0, 5.0, 1]]:
		var hills := MeshInstance3D.new()
		hills.name = "Hills%d" % int(band[2])
		hills.mesh = _hill_mesh(float(band[1]), int(band[2]))
		hills.position = Vector3(0, -0.01, float(band[0]))
		hills.material_override = _cartoon_material(2)
		_cartoon.add_child(hills)
	# Fluffy clouds.
	_cartoon_clouds = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color(1, 1, 1)
	for i in 22:
		var cloud := Node3D.new()
		cloud.name = "Cloud%d" % i
		var size := rng.randf_range(2.2, 4.2)
		for k in 5:
			var puff := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			var r := size * (0.55 if k == 2 else rng.randf_range(0.32, 0.45))
			sphere.radius = r
			sphere.height = r * 2.0
			puff.mesh = sphere
			puff.material_override = white
			puff.position = Vector3((float(k) - 2.0) * size * 0.42, (0.25 if k == 2 else rng.randf_range(-0.1, 0.12)) * size, 0)
			puff.scale = Vector3(1.0, 0.82, 0.25)
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud.add_child(puff)
		var x := rng.randf_range(-80, 170)
		cloud.position = Vector3(x, rng.randf_range(9.0, 17.0), rng.randf_range(-135, -115))
		_cartoon.add_child(cloud)
		_cartoon_clouds.append([cloud, x])
	_update_cartoon_world()


func _hill_mesh(height_m: float, seed_value: int) -> ArrayMesh:
	var points := PackedVector3Array()
	var x := -600.0
	while x <= 800.0:
		var h := height_m * (0.55 + 0.25 * sin(x * 0.031 + float(seed_value) * 2.0) + 0.2 * sin(x * 0.083 + float(seed_value)))
		points.append(Vector3(x, h, 0))
		x += 3.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		# The hills reach far down, so their bottom edge never shows under the grass.
		st.add_vertex(Vector3(a.x, -400, 0))
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(Vector3(a.x, -400, 0))
		st.add_vertex(b)
		st.add_vertex(Vector3(b.x, -400, 0))
	return st.commit()


func _remove_cartoon_world() -> void:
	if _cartoon and is_instance_valid(_cartoon):
		_cartoon.queue_free()
	_cartoon = null
	_cartoon_clouds = []
	_show_floor_line(true)


## Outdoors (no paper colour): sky, hills, clouds and grass. Indoors: the paper
## colour is the wall and a floor comes forward from it.
func _update_cartoon_world() -> void:
	if _cartoon == null or not is_instance_valid(_cartoon):
		return
	var indoor := flat_background.a > 0.05
	var sky: Array = cartoon_sky_colors()
	var top: Color = sky[0]
	var horizon: Color = sky[1]
	var night := clampf(1.0 - top.get_luminance() * 1.7, 0.0, 0.7)
	for name in ["Sky", "Ground", "Hills0", "Hills1"]:
		(_cartoon.get_node(name) as Node3D).visible = not indoor
	for entry in _cartoon_clouds:
		(entry[0] as Node3D).visible = not indoor
	(_cartoon.get_node("Floor") as Node3D).visible = indoor
	var sky_material := (_cartoon.get_node("Sky") as MeshInstance3D).material_override as ShaderMaterial
	sky_material.set_shader_parameter("top_color", top)
	sky_material.set_shader_parameter("horizon_color", horizon)
	var ground_material := (_cartoon.get_node("Ground") as MeshInstance3D).material_override as ShaderMaterial
	ground_material.set_shader_parameter("near_color", Color(0.5, 0.78, 0.3).darkened(night))
	ground_material.set_shader_parameter("far_color", Color(0.58, 0.8, 0.5).lerp(horizon, 0.25).darkened(night))
	((_cartoon.get_node("Hills0") as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("near_color", Color(0.6, 0.8, 0.56).lerp(horizon, 0.35).darkened(night))
	((_cartoon.get_node("Hills1") as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("near_color", Color(0.42, 0.7, 0.36).lerp(horizon, 0.12).darkened(night))
	for entry in _cartoon_clouds:
		for puff in (entry[0] as Node3D).get_children():
			((puff as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1).darkened(night * 0.8)
	if indoor:
		var wall := Color(flat_background.r, flat_background.g, flat_background.b)
		var floor_color := wall.darkened(0.22).lerp(Color(0.66, 0.48, 0.34).darkened(clampf(0.45 - wall.get_luminance(), 0.0, 0.45)), 0.45)
		((_cartoon.get_node("Floor") as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("near_color", floor_color)
	_show_floor_line(false)


func _show_floor_line(show: bool) -> void:
	for root in get_tree().get_nodes_in_group(&"placed_props_root"):
		var line := (root as Node).get_node_or_null("SketchFloorLine") as Node3D
		if line:
			line.visible = show


## Clouds drift slowly (from the film's clock, so renders are repeatable).
func _drift_clouds() -> void:
	if _cartoon_clouds.is_empty():
		return
	var t := scene_time()
	for entry in _cartoon_clouds:
		var cloud := entry[0] as Node3D
		cloud.position.x = float(entry[1]) + fposmod(t * 0.35, 250.0) - (250.0 if float(entry[1]) + fposmod(t * 0.35, 250.0) > 170.0 else 0.0)


# --- Public API -------------------------------------------------------------------

## Current values of the animated properties (for keyframes).
func capture() -> Dictionary:
	var out := {}
	for property in ANIMATED:
		out[property] = get(property)
	return out


func values() -> Dictionary:
	var out := {}
	for key in DEFAULTS:
		out[key] = get(key)
	return out


func reset_defaults() -> void:
	for key in DEFAULTS:
		set(key, DEFAULTS[key])
	hdri_id = ""
	ground_texture_id = ""


## The sky colours shown right now (used when switching to custom colours).
func current_sky_colors() -> Array[Color]:
	var colors := _sky_colors()
	return [colors[0], colors[1]]


func effective_quality() -> int:
	return _quality_override if _quality_override >= 0 else render_quality


## Temporarily renders at [param level] (video export), without changing the setting.
func set_quality_override(level: int) -> void:
	_quality_override = level
	_apply_quality()
	_apply()


func clear_quality_override() -> void:
	_quality_override = -1
	_apply_quality()
	_apply()


## Called by the timeline after every seek: drives cloud drift deterministically.
func set_timeline_time(t: float) -> void:
	if not is_equal_approx(t, _timeline_time):
		_timeline_moving = 2
	_timeline_time = t
	_update_cloud_shift()
	_push_scene_time()


## Downloadable assets this scene uses that are missing on this computer.
func missing_assets() -> Array:
	var out: Array = []
	if not hdri_id.is_empty() and (hdri_path.is_empty() or not FileAccess.file_exists(hdri_path)):
		out.append({"kind": "hdri", "id": hdri_id})
	if not ground_texture_id.is_empty() and (ground_texture.is_empty() or not FileAccess.file_exists(ground_texture)):
		out.append({"kind": "texture", "id": ground_texture_id})
	return out


func relink_asset(kind: String, path: String) -> void:
	if kind == "hdri":
		hdri_path = path
	elif kind == "texture":
		ground_texture = path


## Sun elevation in degrees for an hour: 0 at 6:00/18:00, 75 at noon, -75 at midnight.
static func sun_elevation(hour: float) -> float:
	return 75.0 * sin((hour - 6.0) / 12.0 * PI)


static func format_time(hour: float) -> String:
	var total_minutes := int(round(hour * 60.0)) % (24 * 60)
	return "%02d:%02d" % [total_minutes / 60, total_minutes % 60]


func to_dict() -> Dictionary:
	var out := {}
	var current := values()
	for key in current:
		var v: Variant = current[key]
		out[key] = [v.r, v.g, v.b] if v is Color else v
	out["hdri_id"] = hdri_id
	out["ground_texture_id"] = ground_texture_id
	return out


func load_dict(data: Dictionary) -> void:
	reset_defaults()
	hdri_id = str(data.get("hdri_id", ""))
	ground_texture_id = str(data.get("ground_texture_id", ""))
	for key in DEFAULTS:
		if not data.has(key):
			continue
		var v: Variant = data[key]
		var default_value: Variant = DEFAULTS[key]
		if default_value is Color:
			if v is Array and v.size() >= 3:
				set(key, Color(float(v[0]), float(v[1]), float(v[2])))
		elif default_value is int:
			set(key, int(v))
		elif default_value is String:
			set(key, str(v))
		else:
			set(key, float(v))
	_resolve_downloaded_paths()


## A project opened on another computer (or after a re-download) may point at
## a file that lives elsewhere now; find the local copy of the same asset.
func _resolve_downloaded_paths() -> void:
	if not hdri_id.is_empty() and not FileAccess.file_exists(hdri_path):
		var local := OnlineLibrary.downloaded_path("polyhaven", hdri_id, "hdri")
		if not local.is_empty():
			relink_asset("hdri", local)
	if not ground_texture_id.is_empty() and not FileAccess.file_exists(ground_texture):
		var local_texture := OnlineLibrary.downloaded_path("polyhaven", ground_texture_id, "texture")
		if not local_texture.is_empty():
			relink_asset("texture", local_texture)


# --- Scene update ----------------------------------------------------------------

func _sky_colors() -> Array[Color]:
	if sky_mode == SkyMode.CUSTOM:
		return [sky_top_color, sky_horizon_color]
	var elevation := sun_elevation(time_of_day)
	var day := smoothstep(-6.0, 6.0, elevation)
	var golden := 1.0 - smoothstep(0.0, 20.0, absf(elevation))
	var top := TOP_NIGHT.lerp(TOP_DAY, day).lerp(TOP_SUNSET, golden * 0.6)
	var horizon := HORIZON_NIGHT.lerp(HORIZON_DAY, day).lerp(HORIZON_SUNSET, golden * 0.85)
	# Clouds grey the sky.
	var grey := Color(0.55, 0.58, 0.62) * lerpf(0.15, 1.0, day)
	return [top.lerp(grey, cloud_cover * 0.75), horizon.lerp(grey, cloud_cover * 0.5)]


func _apply() -> void:
	if not is_inside_tree() or sun == null or world_environment == null:
		return
	var elevation := sun_elevation(time_of_day)
	var day := smoothstep(-6.0, 6.0, elevation)       # 0 = night, 1 = day
	var azimuth := sun_azimuth + (time_of_day - 12.0) * 12.0     # the sun travels east → west
	var overcast := lerpf(1.0, 0.45, smoothstep(0.5, 1.0, cloud_cover))

	# One light: the sun by day, the moon by night. It switches below the horizon
	# where both energies are ~0, so there is no visible jump.
	if elevation >= -5.0:
		sun.rotation_degrees = Vector3(-maxf(elevation, 1.0), azimuth, 0.0)
		sun.light_color = SUN_WARM.lerp(SUN_WHITE, smoothstep(2.0, 30.0, elevation))
		sun.light_energy = sun_intensity * smoothstep(-5.0, 8.0, elevation) * 1.2 * overcast
	else:
		sun.rotation_degrees = Vector3(-40.0, azimuth + 180.0, 0.0)
		sun.light_color = MOON_COLOR
		sun.light_energy = sun_intensity * 0.22 * smoothstep(-5.0, -14.0, elevation) * overcast
	sun.shadow_enabled = sun.light_energy > 0.002
	sun.shadow_opacity = shadow_strength * lerpf(1.0, 0.55, smoothstep(0.6, 1.0, cloud_cover))

	var colors := _sky_colors()
	var top: Color = colors[0]
	var horizon: Color = colors[1]
	if _sky_shader_material:
		_sky_shader_material.set_shader_parameter("top_color", top)
		_sky_shader_material.set_shader_parameter("horizon_color", horizon)
		_sky_shader_material.set_shader_parameter("ground_color", horizon.darkened(0.75))
		_sky_shader_material.set_shader_parameter("cloud_cover", cloud_cover)
		_sky_shader_material.set_shader_parameter("daylight", day)
		_sky_shader_material.set_shader_parameter("stars", 1.0 - day)
	RenderingServer.global_shader_parameter_set(&"night", clampf(1.0 - day * 1.6, 0.0, 1.0))
	if _panorama_material:
		_panorama_material.energy_multiplier = hdri_energy

	var env := world_environment.environment
	if env:
		var photo := sky_mode == SkyMode.PHOTO and _panorama_material and _panorama_material.panorama != null
		env.sky_rotation = Vector3(0.0, deg_to_rad(hdri_rotation), 0.0) if photo else Vector3.ZERO
		env.ambient_light_energy = ambient_energy * (1.0 if photo else lerpf(0.3, 1.0, day))
		env.tonemap_exposure = exposure
		_apply_grade(env)
		var volumetric := effective_quality() >= RenderQuality.Level.HIGH
		var fog := minf(fog_density + mist * mist * 0.05 + rain * 0.006 + snow * 0.008, 0.2)
		var fog_on := fog > 0.0001
		env.volumetric_fog_enabled = fog_on and volumetric
		env.volumetric_fog_density = fog * 0.8
		env.volumetric_fog_albedo = horizon.lerp(Color.WHITE, 0.4)
		env.volumetric_fog_anisotropy = 0.6
		env.volumetric_fog_length = 96.0
		env.fog_enabled = fog_on
		env.fog_density = fog * (0.3 if volumetric else 1.0)
		env.fog_light_color = horizon.lerp(Color.WHITE, 0.15 + mist * 0.4)
		env.fog_sky_affect = 0.4
		if is_flat():
			env.fog_enabled = false
			env.volumetric_fog_enabled = false
			env.tonemap_exposure = 1.0
			env.ambient_light_energy = 1.0

	if not _changed_queued:
		_changed_queued = true
		_emit_changed.call_deferred()


func _apply_sky_type() -> void:
	if world_environment == null or world_environment.environment == null or _sky_shader_material == null:
		return
	if is_flat():
		return   # the flat looks keep their plain background
	var env := world_environment.environment
	if env.sky == null:
		env.sky = Sky.new()
	var texture: Texture2D = _load_hdri(hdri_path) if sky_mode == SkyMode.PHOTO else null
	if texture:
		_panorama_material.panorama = texture
		env.sky.sky_material = _panorama_material
	else:
		_panorama_material.panorama = null
		env.sky.sky_material = _sky_shader_material
		if sky_mode == SkyMode.PHOTO and not hdri_path.is_empty():
			EventBus.error("The photo sky file couldn't be loaded; showing the realistic sky instead.")
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY


func _apply_ground() -> void:
	if ground_mesh == null or _ground_shader_material == null:
		return
	match ground_style:
		"Plain colour":
			ground_mesh.material_override = _ground_plain_material
			_apply_ground_color()
		"Photo texture":
			var material := _textured_material(ground_texture, ground_tile)
			ground_mesh.material_override = material if material else _ground_shader_material
			if material == null:
				_set_ground_preset("Grass")
		_:
			_set_ground_preset(ground_style)
			ground_mesh.material_override = _ground_shader_material
	_sync_terrain_ground()
	changed.emit()


## The sculptable terrain uses the same ground style as the flat ground around it.
func _sync_terrain_ground() -> void:
	if terrain == null:
		return
	match ground_style:
		"Plain colour":
			terrain.set_base_preset([ground_color, ground_color, ground_color], 0.95, 0.0, 0.25, 0.0, 1.0)
		"Photo texture":
			var material := ground_mesh.material_override as BaseMaterial3D
			if material and material.albedo_texture:
				terrain.set_base_texture(material.albedo_texture, ground_tile)
			else:
				_sync_terrain_preset("Grass")
		_:
			_sync_terrain_preset(ground_style)


func _sync_terrain_preset(style: String) -> void:
	var p: Array = GROUND_PRESETS.get(style, GROUND_PRESETS["Grass"])
	terrain.set_base_preset([p[0], p[1], p[2]], p[3], p[4], p[5], p[6], p[7])


func _set_ground_preset(style: String) -> void:
	var preset: Array = GROUND_PRESETS.get(style, GROUND_PRESETS["Grass"])
	_ground_shader_material.set_shader_parameter("color_a", preset[0])
	_ground_shader_material.set_shader_parameter("color_b", preset[1])
	_ground_shader_material.set_shader_parameter("color_c", preset[2])
	_ground_shader_material.set_shader_parameter("roughness_value", preset[3])
	_ground_shader_material.set_shader_parameter("bump", preset[4])
	_ground_shader_material.set_shader_parameter("specular_value", preset[5])
	_ground_shader_material.set_shader_parameter("speckle", preset[6])
	_ground_shader_material.set_shader_parameter("scale", preset[7])


func _apply_ground_color() -> void:
	if _ground_plain_material:
		_ground_plain_material.albedo_color = ground_color
	if terrain and ground_style == "Plain colour":
		terrain.set_base_preset([ground_color, ground_color, ground_color], 0.95, 0.0, 0.25, 0.0, 1.0)


## A photo-texture material (from a downloaded Poly Haven texture), projected in
## world space so it never stretches, repeating every [param tile] metres.
func _textured_material(path: String, tile: float) -> Material:
	if path.is_empty():
		return null
	var base: Material = _texture_cache.get(path)
	if base == null:
		base = RuntimeModelLoader.load_material(path)
		if base == null:
			return null
		_texture_cache[path] = base
	return PropUtils.world_projected(base, tile)


func _load_hdri(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	if _hdri_cache.has(path):
		return _hdri_cache[path]
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	_hdri_cache[path] = texture
	return texture


func _apply_quality() -> void:
	if not is_inside_tree():
		return
	var level := effective_quality()
	if world_environment and world_environment.environment:
		RenderQuality.apply_environment(world_environment.environment, level)
		_apply_flat_glow()
	RenderQuality.apply_sun(sun, level)
	if editor_viewport:
		RenderQuality.apply_viewport(editor_viewport, level)


func _update_cloud_shift() -> void:
	if _sky_shader_material:
		_sky_shader_material.set_shader_parameter("cloud_shift", _timeline_time * cloud_speed * 0.012)


func _emit_changed() -> void:
	_changed_queued = false
	changed.emit()

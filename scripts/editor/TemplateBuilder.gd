class_name TemplateBuilder
extends Node
## Ready-made starting scenes: shaped and painted terrain, water, plants,
## buildings, characters walking, lighting, weather and a camera move.
## Everything is ordinary scene content, so it can be edited and saved.

const BLANK := "Blank World"
const FIRST_FILM := "My First Film: The Lantern"
const THEME_MUSIC := "res://assets/audio/the_lantern_theme.ogg"
const TEMPLATES := {
	BLANK: "An empty, flat world with default daylight: start from scratch",
	FIRST_FILM: "A finished 42-second short film: six shots, music, titles, dialogue and a sunset turning to dusk",
	"Forest Lake": "Morning mist over a lake in a pine forest, a cabin and a campfire",
	"Seaside Village": "Huts on a sandy beach at sunset, waves rolling in, villagers walking",
	"Mountain River": "A river and waterfall in a rocky valley with snowy peaks",
	"Rainy Night Street": "A wet street at night with lamps, cars and people walking in the rain",
	"Rain Street": "A quiet city street on a rainy night: low brick and apartment buildings with lit windows, lamp posts, parked cars, an empty pavement",
	"Classroom": "A school classroom: teacher at the blackboard, pupils at their desks",
	"Hospital Ward": "A bright hospital ward with beds, a doctor and a nurse",
	"Living Room": "A cosy home interior in the evening: sofa, TV, lamps and a family",
	"Big City": "Downtown at dusk: towers with lit windows, roads, traffic and people",
	"Golden Valley": "Cinematic nature at golden hour: rolling hills, a river, trees and drifting mist",
	"Stand-up Comedy": "A comedy club: brick wall, spotlight, mic stand, a comedian and an audience",
	"News Studio": "A TV news studio: anchor desk, video wall, studio lights and a headline",
	"Sketch Stage": "Flat sketch look: a black void and a drawn floor line, filmed from the side like a 2D cartoon",
	# Short-film sets (1.27): furnished everyday places for story people.
	"Kitchen": "A warm home kitchen in the evening: cabinets, stove, fridge, a dining table under a hanging lamp",
	"Bedroom": "A small bedroom at night: bed, desk with a laptop, wardrobe, window, warm lamps",
	"Cafe": "A cosy café: counter with a coffee machine and cakes, menu board, small tables, hanging lamps",
	"Barbershop": "A neighbourhood barbershop: two barber chairs, a wall of customer photos, a waiting bench",
	"Apartment Hallway": "An apartment corridor: numbered doors, wall lamps, a notice board and an elevator",
	"Rooftop": "A city rooftop at sunset: parapet, water tower, string lights, picnic table, the skyline",
	"Bus Stop": "A street corner bus stop in the late afternoon: shelter, bench, bus sign, a bakery and a pharmacy",
	"Car": "Inside a parked car on a city street: two front seats, dashboard and windscreen",
}

@export var document: SceneDocument
@export var terrain: Terrain
@export var vegetation: Vegetation
@export var environment: EnvironmentController
@export var director: CinematicDirector
@export var timeline: TimelineController
@export var placed_props_root: Node3D
@export var history: EditorHistory
@export var editor_camera: EditorCamera
@export var titles: TitleTrack
@export var audio: AudioTrack

var _rng := RandomNumberGenerator.new()
## While building an extra set (see [method build_set]): ignore the terrain.
var _flat := false
## The lighting a template asked for (read by [method build_set]: the timeline may put
## the film's own lighting back while the set is built).
var _env_requested := {}

## Templates that need the terrain (only one of these per world).
const TERRAIN_TEMPLATES: PackedStringArray = ["Forest Lake", "Seaside Village", "Mountain River", "Golden Valley", "My First Film: The Lantern"]



func _ready() -> void:
	if placed_props_root:
		placed_props_root.add_to_group(&"placed_props_root")

func build(template: String) -> void:
	document.new_scene()
	if template == BLANK:
		timeline.set_time(0.0)
		history.clear_history()
		EventBus.info("Blank world ready. Drag assets in, or use the World tab to shape the land.")
		return
	_rng.seed = hash(template)
	_run_template(template)
	terrain.end_stroke()
	vegetation.resettle(Rect2(-Terrain.HALF, -Terrain.HALF, Terrain.SIZE, Terrain.SIZE))
	timeline.set_time(0.0)
	history.clear_history()
	EventBus.info("Template \"%s\" ready: edit anything, then Save. Press Space or Play Cinematic to watch." % template)


## Builds a flat template's set (rooms, studios, streets) into the current world
## at [param offset], without touching the terrain, timeline, titles, sound or
## lighting. Returns { "nodes": the new objects, "env": the lighting it wanted }.
func build_set(template: String, offset: Vector3) -> Dictionary:
	if TERRAIN_TEMPLATES.has(template) or template == BLANK:
		return {"nodes": [], "env": {}}
	var env_before := environment.values()
	var store_before := timeline.store.snapshot()
	var titles_before: Array = titles.to_list() if titles else []
	var audio_before: Array = audio.to_list() if audio else []
	var existing := {}
	for root in [placed_props_root, director.cameras_root]:
		for child in (root as Node).get_children():
			existing[child] = true
	_rng.seed = hash(template)
	_flat = true
	_env_requested = {}
	_run_template(template)
	_flat = false
	var env_wanted := env_before.duplicate()
	env_wanted.merge(_env_requested, true)
	for key in env_before:
		environment.set(key, env_before[key])
	timeline.store.restore(store_before)
	if titles:
		titles.load_list(titles_before)
	if audio:
		audio.load_list(audio_before)
	var nodes: Array = []
	for root in [placed_props_root, director.cameras_root]:
		for child in (root as Node).get_children():
			if existing.has(child):
				continue
			if child is CinematicCamera or child is CharacterBase or str(child.name).to_lower().begins_with("dog"):
				(root as Node).remove_child(child)
				child.queue_free()
				continue
			(child as Node3D).position += offset
			nodes.append(child)
	return {"nodes": nodes, "env": env_wanted}


func _run_template(template: String) -> void:
	match template:
		"Forest Lake":
			_forest_lake()
		"Seaside Village":
			_seaside_village()
		"Mountain River":
			_mountain_river()
		"Rainy Night Street":
			_rainy_street()
		"Rain Street":
			_rain_street()
		FIRST_FILM:
			_first_film()
		"Classroom":
			_classroom()
		"Hospital Ward":
			_hospital()
		"Living Room":
			_living_room()
		"Big City":
			_big_city()
		"Golden Valley":
			_golden_valley()
		"Stand-up Comedy":
			_comedy()
		"Kitchen":
			_kitchen()
		"Bedroom":
			_bedroom()
		"Cafe":
			_cafe()
		"Barbershop":
			_barbershop()
		"Apartment Hallway":
			_hallway()
		"Rooftop":
			_rooftop()
		"Bus Stop":
			_bus_stop()
		"Car":
			_car()
		"News Studio":
			_news_studio()
		"Sketch Stage":
			_sketch_stage()


# --- Templates -----------------------------------------------------------------

func _forest_lake() -> void:
	_set_env({"time_of_day": 7.6, "sun_azimuth": 120.0, "mist": 0.45, "wind": 0.25, "cloud_cover": 0.35, "ground_style": "Grass", "fog_density": 0.006})
	_shape_terrain(_forest_height)
	var lake := _place("res://assets/props/water/lake.tscn", Vector3(-10, 0, 0), 15.0) as WaterBody
	if lake:
		lake.width = 46.0
		lake.length = 34.0
		terrain.carve_for(lake)
		lake.real_depth = true
	vegetation.scatter("Pine trees", Vector2(-10, 0), 110.0, 700, _away_from(Vector2(-10, 0), 30.0))
	vegetation.scatter("Broadleaf trees", Vector2(-10, 0), 90.0, 120, _away_from(Vector2(-10, 0), 30.0))
	vegetation.scatter("Grass", Vector2(30, 10), 30.0, 5000, _away_from(Vector2(-10, 0), 26.0))
	vegetation.scatter("Flowers", Vector2(28, 8), 20.0, 600, _away_from(Vector2(-10, 0), 26.0))
	vegetation.scatter("Rocks", Vector2(-10, 0), 40.0, 90, _ring(Vector2(-10, 0), 22.0, 30.0))
	vegetation.scatter("Bushes", Vector2(25, 0), 35.0, 120, _away_from(Vector2(-10, 0), 27.0))
	_place("res://assets/props/buildings/hut.tscn", Vector3(30, 0, 8), 200.0)
	_place("res://assets/props/effects/campfire.tscn", Vector3(24, 0, 2), 0.0)
	_place("res://assets/props/effects/ground_mist.tscn", Vector3(-10, 0, 0), 0.0)
	var man := _place("res://assets/props/characters/man.tscn", Vector3(34, 0, 14), 200.0)
	timeline.set_duration(14.0)
	_walk(man, [Vector3(34, 0, 14), Vector3(28, 0, 6), Vector3(24, 0, 4)], 1.3)
	_camera(Vector3(40, 6, 26), Vector3(10, 2, 2), 42.0, "Orbit left", 12.0, 2.0)


func _seaside_village() -> void:
	_set_env({"time_of_day": 18.0, "sun_azimuth": 250.0, "wind": 0.55, "cloud_cover": 0.4, "ground_style": "Sand", "fog_density": 0.004})
	_shape_terrain(_seaside_height)
	_place("res://assets/props/water/sea_and_beach.tscn", Vector3(0, 0, 18), 0.0)
	for i in 5:
		var x := -36.0 + float(i) * 17.0 + _rng.randf_range(-3.0, 3.0)
		_place("res://assets/props/buildings/hut.tscn", Vector3(x, 0, -22 + _rng.randf_range(-4.0, 4.0)), _rng.randf_range(160.0, 200.0))
	_place("res://assets/props/buildings/fence.tscn", Vector3(-8, 0, -12), 0.0)
	_place("res://assets/props/vehicles/cart.tscn", Vector3(10, 0, -10), 30.0)
	_place("res://assets/props/decorations/barrel.tscn", Vector3(12, 0, -12), 0.0)
	_place("res://assets/props/effects/torch.tscn", Vector3(-2, 0, -14), 0.0)
	_place("res://assets/props/effects/torch.tscn", Vector3(6, 0, -14), 0.0)
	vegetation.scatter("Broadleaf trees", Vector2(0, -45), 70.0, 90, func(_x: float, z: float, _y: float) -> bool: return z < -30.0)
	vegetation.scatter("Tall grass", Vector2(0, -35), 60.0, 2500, func(_x: float, z: float, _y: float) -> bool: return z < -18.0)
	vegetation.scatter("Rocks", Vector2(0, 0), 60.0, 40, func(_x: float, z: float, _y: float) -> bool: return z > -6.0 and z < 6.0)
	timeline.set_duration(12.0)
	var woman := _place("res://assets/props/characters/woman_casual.tscn", Vector3(-20, 0, -8), 90.0)
	_walk(woman, [Vector3(-20, 0, -8), Vector3(-5, 0, -2), Vector3(10, 0, -4)], 1.2)
	var child := _place("res://assets/props/characters/child.tscn", Vector3(-24, 0, -4), 90.0)
	_walk(child, [Vector3(-24, 0, -4), Vector3(-8, 0, 2), Vector3(4, 0, 0)], 2.6)
	_place("res://assets/props/characters/dog.tscn", Vector3(-3, 0, -6), 45.0)
	_camera(Vector3(-30, 3, 10), Vector3(0, 1.5, -6), 45.0, "Truck right", 11.0, 14.0)


func _mountain_river() -> void:
	_set_env({"time_of_day": 12.5, "sun_azimuth": 190.0, "wind": 0.4, "cloud_cover": 0.5, "ground_style": "Grass", "snow_cover": 0.0})
	_shape_terrain(_mountain_height)
	var river := _place("res://assets/props/water/rapids.tscn", Vector3(0, 0, 0), 0.0) as River
	if river:
		river.length = 250.0
		river.width = 9.0
		river.winding = 0.15
		river.bends = 1.0
		river.flow = 3.2
		terrain.carve_for(river)
		river.real_depth = true
	# Snow on the high peaks, rock on the walls.
	var state := terrain.snapshot()
	var heights: PackedFloat32Array = state["heights"]
	var splat: PackedByteArray = state["splat"]
	for i in Terrain.RES * Terrain.RES:
		if heights[i] > 26.0:
			splat[i * 4 + 3] = clampi(roundi((heights[i] - 26.0) * 40.0), 0, 255)
	state["splat"] = splat
	terrain.restore(state)
	_place("res://assets/props/effects/waterfall.tscn", Vector3(-26, 0, -40), 60.0)
	vegetation.scatter("Pine trees", Vector2(0, 0), 125.0, 900, func(_x: float, _z: float, y: float) -> bool: return y > 1.0 and y < 24.0)
	vegetation.scatter("Rocks", Vector2(0, 0), 60.0, 160, func(x: float, z: float, _y: float) -> bool: return absf(x - sin(z * 0.03) * 8.0) < 16.0)
	vegetation.scatter("Grass", Vector2(0, 30), 25.0, 3500, func(x: float, z: float, _y: float) -> bool: return absf(x - sin(z * 0.03) * 8.0) > 8.0)
	timeline.set_duration(10.0)
	_camera(Vector3(14, 5, 50), Vector3(0, 1, 0), 50.0, "Crane up", 10.0, 9.0)


func _rainy_street() -> void:
	_set_env({"time_of_day": 22.5, "sun_azimuth": 200.0, "rain": 0.75, "wind": 0.45, "mist": 0.25, "cloud_cover": 1.0, "ground_style": "Asphalt", "exposure": 1.6})
	for i in 6:
		var z := -30.0 + float(i) * 12.0
		_place("res://assets/props/decorations/lamp_post.tscn", Vector3(-6, 0, z), 90.0)
		_place("res://assets/props/decorations/lamp_post.tscn", Vector3(6, 0, z + 6.0), -90.0)
		_place("res://assets/props/buildings/stone_wall.tscn", Vector3(-11, 0, z), 90.0)
		_place("res://assets/props/buildings/stone_wall.tscn", Vector3(11, 0, z), 90.0)
	_place("res://assets/props/vehicles/car.tscn", Vector3(-3, 0, -8), 0.0)
	_place("res://assets/props/vehicles/van.tscn", Vector3(3, 0, 10), 180.0)
	_place("res://assets/props/effects/steam.tscn", Vector3(2, 0, -2), 0.0)
	timeline.set_duration(12.0)
	var man := _place("res://assets/props/characters/man_suit.tscn", Vector3(-4.5, 0, -28), 0.0)
	_walk(man, [Vector3(-4.5, 0, -28), Vector3(-4.5, 0, 20)], 1.5)
	var woman := _place("res://assets/props/characters/woman.tscn", Vector3(4.5, 0, 24), 180.0)
	_walk(woman, [Vector3(4.5, 0, 24), Vector3(4.5, 0, -24)], 1.4)
	_camera(Vector3(0, 1.6, 30), Vector3(0, 1.4, 0), 40.0, "Dolly in", 12.0, 12.0)


## A quiet neighbourhood street in the rain (1.12): made for films, so it is empty
## (no actors) and leaves the right pavement at x 6-9 free for a scene.
func _rain_street() -> void:
	_set_env({"time_of_day": 21.6, "sun_azimuth": 200.0, "rain": 0.7, "wind": 0.35, "mist": 0.35, "cloud_cover": 1.0,
		"ground_style": "Asphalt", "exposure": 0.78, "ambient_energy": 0.12, "sun_intensity": 0.2, "fog_density": 0.03, "snow": 0.0, "leaves": 0.0})
	var road := _put("res://assets/props/city/road.tscn", Vector3.ZERO, 0.0) as Road
	if road:
		road.length = 180.0
		road.lanes = 2
		road.pavement = 4.5
		road.crossing = false
	var styles := ["res://assets/props/city/brick_building.tscn", "res://assets/props/city/apartment_block.tscn"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for side in [-1.0, 1.0]:
		for i in 9:
			var z := -80.0 + float(i) * 19.0 + (6.0 if side > 0 else 0.0)
			var building := _put(styles[rng.randi_range(0, 1)], Vector3(side * 14.3, 0, z), 0.0) as Building
			if building:
				building.floors = rng.randi_range(3, 6)
				building.width = 14.0
				building.depth = 18.6
				building.variation = rng.randi_range(0, 99)
	for z in [-63.0, -45.0, -27.0, -9.0, 9.0, 27.0, 45.0, 63.0]:
		_put("res://assets/props/decorations/lamp_post.tscn", Vector3(-8.0, 0, z + 9.0), 90.0)
		_put("res://assets/props/decorations/lamp_post.tscn", Vector3(8.0, 0, z), -90.0)
	_put("res://assets/props/city/traffic_light.tscn", Vector3(-7.6, 0, -52), 0.0)
	_put("res://assets/props/city/traffic_light.tscn", Vector3(7.6, 0, -52), 180.0)
	for p in [Vector3(-4.6, 0, -14), Vector3(-4.6, 0, 16), Vector3(-4.6, 0, 34), Vector3(4.6, 0, -30), Vector3(4.6, 0, 26)]:
		_put("res://assets/props/vehicles/car.tscn", p, 0.0 if rng.randf() < 0.5 else 180.0)
	_put("res://assets/props/city/trash_bin.tscn", Vector3(8.6, 0, 12), 0.0)
	_put("res://assets/props/effects/steam.tscn", Vector3(-1.5, 0, -20), 0.0)
	timeline.set_duration(10.0)
	_camera(Vector3(2.0, 1.7, 30), Vector3(0.5, 2.0, -10), 45.0, "Dolly in", 10.0, 6.0)


# --- "The Lantern": a complete short film ---------------------------------------

func _first_film() -> void:
	timeline.set_duration(42.0)
	_set_env({"time_of_day": 18.0, "sun_azimuth": 245.0, "mist": 0.3, "wind": 0.3, "leaves": 0.15, "cloud_cover": 0.4,
		"ground_style": "Grass", "exposure": 1.15, "fog_density": 0.004})
	_shape_terrain(_film_height)
	var lake := _place("res://assets/props/water/lake.tscn", Vector3(-10, 0, 0), 20.0) as WaterBody
	if lake:
		lake.width = 40.0
		lake.length = 30.0
		lake.wave_height = 0.03
		terrain.carve_for(lake)
		lake.real_depth = true
	vegetation.scatter("Pine trees", Vector2(-10, 0), 115.0, 650, func(x: float, z: float, _y: float) -> bool: return Vector2(x + 10.0, z).length() > 28.0 and not _near_path(x, z))
	vegetation.scatter("Broadleaf trees", Vector2(10, 10), 70.0, 90, func(x: float, z: float, _y: float) -> bool: return Vector2(x + 10.0, z).length() > 26.0 and not _near_path(x, z))
	vegetation.scatter("Grass", Vector2(24, 14), 26.0, 6000, func(x: float, z: float, _y: float) -> bool: return Vector2(x + 10.0, z).length() > 21.0 and not _near_path(x, z))
	vegetation.scatter("Flowers", Vector2(26, 16), 18.0, 900, func(x: float, z: float, _y: float) -> bool: return Vector2(x + 10.0, z).length() > 22.0 and not _near_path(x, z))
	vegetation.scatter("Rocks", Vector2(-10, 0), 26.0, 60, _ring(Vector2(-10, 0), 19.0, 24.0))

	_place("res://assets/props/effects/campfire.tscn", Vector3(15.5, 0, 4.0), 0.0)
	var bench := _place("res://assets/props/furniture/bench.tscn", Vector3(18.0, 0, 5.6), -120.0)
	var elder := _place("res://assets/props/characters/elder.tscn", Vector3(18.0, 0.0, 5.6), -120.0)
	_act_at(elder, "Sit", 0.0)
	if bench == null and elder:
		elder.position.y = terrain.height_at(18.0, 5.6)
	_place("res://assets/props/effects/ground_mist.tscn", Vector3(-10, 0, 0), 0.0)

	# The girl walks down from the hill to the fire, waves, and they talk.
	var girl := _place("res://assets/props/characters/woman_casual.tscn", Vector3(32, 0, 24), 220.0)
	if girl:
		var path: Array = []
		for p in [Vector3(32, 0, 24), Vector3(26, 0, 17), Vector3(20.5, 0, 9.0)]:
			path.append(Vector3(p.x, terrain.height_at(p.x, p.z), p.z))
		timeline.set_time(5.0, false)
		timeline.add_path_keys(girl, path, 1.25)
	_act_at(girl, "Wave", 20.0)
	_act_at(girl, "Talk", 24.4)
	_act_at(girl, "Auto", 27.8)
	_act_at(elder, "Sit", 28.0)
	_speak(elder, 21.0, 3.0)
	_speak(girl, 24.5, 3.0)
	_speak(elder, 28.0, 3.6)

	timeline.set_duration(42.0)
	# The sun sets while they talk: key the light at the start and the end.
	timeline.set_time(0.0, false)
	timeline.add_keyframe(environment)
	environment.set("time_of_day", 19.25)
	environment.set("mist", 0.5)
	environment.set("exposure", 1.35)
	timeline.set_time(42.0, false)
	timeline.add_keyframe(environment)

	# Six shots, cut together.
	_shot(Vector3(-46, 24, 46), Vector3(-6, 0, 0), 50.0, 0.0, 7.0, "Crane down", 9.0, true)
	_shot(Vector3(37, 1.6, 12), Vector3(27, 1.3, 18), 42.0, 7.0, 8.0, "Pan left", 3.0)
	_shot(Vector3(25, 2.2, 14.5), Vector3(16, 1.0, 5), 38.0, 15.0, 6.0, "Dolly in", 3.0)
	_shot(Vector3(13.5, 1.3, 10.5), Vector3(19, 1.0, 6.5), 35.0, 21.0, 7.0, "Zoom in", 1.0, false, true)
	_shot(Vector3(21.2, 1.25, 3.2), Vector3(18, 1.05, 5.6), 30.0, 28.0, 6.0, "Dolly in", 0.5, false, true)
	_shot(Vector3(32, 7, -16), Vector3(8, 1, 2), 45.0, 34.0, 8.0, "Orbit left", 1.2)

	if titles:
		titles.load_list([
			{"text": "THE LANTERN", "start": 1.2, "length": 4.6, "style": "Title"},
			{"text": "A Scene Builder film", "start": 8.0, "length": 4.0, "style": "Lower third"},
			{"text": "You came back… I kept the fire burning.", "start": 21.0, "length": 3.2, "style": "Subtitle"},
			{"text": "Grandfather said you would still be here.", "start": 24.5, "length": 3.2, "style": "Subtitle"},
			{"text": "Every lantern finds its way home.", "start": 28.0, "length": 3.8, "style": "Subtitle"},
			{"text": "THE END", "start": 38.0, "length": 4.0, "style": "Title"},
		])
	_add_music(THEME_MUSIC, -4.0)
	timeline.set_time(0.0)


func _film_height(x: float, z: float) -> float:
	var from_lake := Vector2(x + 10.0, z).length()
	return _hills(x, z, 0.015, 10.0) * smoothstep(24.0, 75.0, from_lake) - smoothstep(30.0, 18.0, from_lake) * 0.3


## True near the girl's walking path (kept clear of trees and tall plants).
func _near_path(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	return Geometry2D.get_closest_point_to_segment(p, Vector2(32, 24), Vector2(26, 17)).distance_to(p) < 2.5 \
		or Geometry2D.get_closest_point_to_segment(p, Vector2(26, 17), Vector2(18, 5)).distance_to(p) < 3.5


## A camera with a move, cut to at [param start].
func _shot(from: Vector3, look_at_point: Vector3, fov: float, start: float, seconds: float, move: String, amount: float, first: bool = false, depth_of_field: bool = false) -> void:
	var ground := terrain.height_at(from.x, from.z) if Terrain.contains(from.x, from.z) else 0.0
	var eye := Vector3(from.x, maxf(from.y + ground, ground + 0.8), from.z)
	var target := Vector3(look_at_point.x, look_at_point.y + (terrain.height_at(look_at_point.x, look_at_point.z) if Terrain.contains(look_at_point.x, look_at_point.z) else 0.0), look_at_point.z)
	var euler := Transform3D(Basis(), eye).looking_at(target, Vector3.UP).basis.get_euler()
	director.restore_cameras([{"position": [eye.x, eye.y, eye.z],
		"rotation_degrees": [rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)],
		"fov": fov, "focus_distance": eye.distance_to(target), "dof_enabled": depth_of_field, "aperture": 0.45}])
	var cams := director.cameras()
	var cam: CinematicCamera = cams[cams.size() - 1]
	if first:
		director.set_default_camera(cam)
	timeline.set_time(start, false)
	timeline.add_camera_move(cam, move, seconds, amount)
	timeline.set_time(start, false)
	timeline.add_cut(cam)


func _act_at(node: Node3D, action: String, t: float) -> void:
	if node is CharacterBase:
		timeline.set_time(t, false)
		timeline.set_character_action(node as CharacterBase, action)


## Moves a character's mouth as if speaking for [param seconds] (no audio needed).
func _speak(node: Node3D, start: float, seconds: float) -> void:
	var character := node as CharacterBase
	if character == null:
		return
	var env := PackedFloat32Array()
	var frames := int(seconds * 30.0)
	for i in frames:
		var t := float(i) / 30.0
		var syllable := maxf(0.0, sin(t * 11.0 + sin(t * 3.1) * 2.0))
		var phrase := smoothstep(0.0, 0.15, t) * smoothstep(seconds, seconds - 0.25, t) * (0.6 + 0.4 * sin(t * 1.7))
		env.append(clampf(syllable * phrase, 0.0, 1.0))
	var existing: Dictionary = character.lipsync
	if not existing.is_empty():
		# Append to earlier lines: rebuild one envelope from the first start.
		var first_start := float(existing["start"])
		var merged: PackedFloat32Array = existing["env"]
		var offset := int((start - first_start) * 30.0)
		if offset >= 0:
			while merged.size() < offset + env.size():
				merged.append(0.0)
			for i in env.size():
				merged[offset + i] = env[i]
			character.lipsync = {"clip": "(dialogue)", "start": first_start, "fps": 30.0, "env": merged}
			return
	character.lipsync = {"clip": "(dialogue)", "start": start, "fps": 30.0, "env": env}


func _add_music(path: String, volume_db: float) -> void:
	if audio == null:
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(AudioTrack.AUDIO_DIR)
	var target := AudioTrack.AUDIO_DIR + path.get_file()
	var file := FileAccess.open(target, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var clip := audio.import_file(target, 0.0)
	if not clip.is_empty():
		clip["volume_db"] = volume_db
		clip["name"] = "The Lantern (theme)"
		audio.load_list([clip])


func _indoor_env(time: float, exposure: float) -> void:
	_set_env({"time_of_day": time, "ambient_energy": 1.3, "exposure": exposure, "fog_density": 0.0, "wind": 0.0, "rain": 0.0, "mist": 0.0, "ground_style": "Grass"})


func _classroom() -> void:
	_indoor_env(10.5, 1.25)
	_put("res://assets/props/buildings/classroom_room.tscn", Vector3.ZERO, 0.0)
	_put("res://assets/props/interior/blackboard.tscn", Vector3(0, 0, -4.4), 0.0)
	_put("res://assets/props/interior/teacher_desk.tscn", Vector3(-2.6, 0, -2.9), 0.0)
	_put("res://assets/props/furniture/bookshelf.tscn", Vector3(4.6, 0, -3.6), -90.0)
	for x in [-3.0, -1.0, 1.0, 3.0]:
		for z in [-0.6, 1.4, 3.4]:
			_put("res://assets/props/interior/school_desk.tscn", Vector3(x, 0, z), 0.0)
			_put("res://assets/props/furniture/chair.tscn", Vector3(x, 0, z + 0.6), 180.0)
			if _rng.randf() < 0.75:
				var pupil := _put("res://assets/props/characters/child.tscn", Vector3(x, 0, z + 0.6), 180.0)
				_act(pupil, "Sit")
	for p in [Vector3(-2.5, 3.0, -2), Vector3(2.5, 3.0, -2), Vector3(-2.5, 3.0, 2.5), Vector3(2.5, 3.0, 2.5)]:
		_put("res://assets/props/lights/soft_panel.tscn", p, 0.0, Vector3(p.x, 0, p.z + 0.01))
	var teacher := _put("res://assets/props/characters/woman.tscn", Vector3(0.8, 0, -3.6), 0.0)
	_act(teacher, "Talk")
	timeline.set_duration(10.0)
	_camera(Vector3(3.6, 2.2, 4.3), Vector3(0, 1.3, -2.5), 50.0, "Dolly in", 10.0, 1.5)


func _hospital() -> void:
	_indoor_env(11.0, 1.2)
	_put("res://assets/props/buildings/hospital_room.tscn", Vector3.ZERO, 0.0)
	for i in 3:
		var x := -2.8 + float(i) * 2.8
		_put("res://assets/props/hospital/hospital_bed.tscn", Vector3(x, 0, -2.6), 0.0)
		_put("res://assets/props/hospital/iv_stand.tscn", Vector3(x + 0.8, 0, -3.2), 0.0)
	_put("res://assets/props/hospital/medical_screen.tscn", Vector3(-1.4, 0, -1.4), 90.0)
	_put("res://assets/props/hospital/medical_cabinet.tscn", Vector3(4.2, 0, 0.5), -90.0)
	_put("res://assets/props/hospital/waiting_chairs.tscn", Vector3(0, 0, 3.4), 180.0)
	var patient := _put("res://assets/props/characters/elder.tscn", Vector3(0, 0.25, -2.4), 0.0)
	_act(patient, "Sit")
	var doctor := _put("res://assets/props/characters/man_suit.tscn", Vector3(0.9, 0, -1.2), 200.0)
	_act(doctor, "Talk")
	var nurse := _put("res://assets/props/characters/woman_casual.tscn", Vector3(3.5, 0, 2.5), -90.0)
	_walk(nurse, [Vector3(3.5, 0, 2.5), Vector3(1.0, 0, 0.6), Vector3(-2.0, 0, -0.6)], 1.2)
	for p in [Vector3(-2.5, 2.9, -1.5), Vector3(2.5, 2.9, -1.5), Vector3(0, 2.9, 2)]:
		_put("res://assets/props/lights/soft_panel.tscn", p, 0.0, Vector3(p.x, 0, p.z + 0.01))
	timeline.set_duration(10.0)
	_camera(Vector3(-3.6, 1.8, 3.4), Vector3(0.5, 1.1, -2), 45.0, "Truck right", 10.0, 2.5)


func _living_room() -> void:
	_indoor_env(19.3, 1.4)
	_put("res://assets/props/buildings/living_room.tscn", Vector3.ZERO, 0.0)
	_put("res://assets/props/interior/rug.tscn", Vector3(0, 0, 0.4), 0.0)
	_put("res://assets/props/interior/tv.tscn", Vector3(0, 0, -3.1), 0.0)
	_put("res://assets/props/interior/sofa.tscn", Vector3(0, 0, 2.0), 180.0)
	_put("res://assets/props/interior/armchair.tscn", Vector3(-2.4, 0, 0.6), 110.0)
	_put("res://assets/props/interior/coffee_table.tscn", Vector3(0, 0, 0.5), 0.0)
	_put("res://assets/props/furniture/bookshelf.tscn", Vector3(3.6, 0, -2.0), -90.0)
	_put("res://assets/props/decorations/flower_pot.tscn", Vector3(-3.4, 0, -3.0), 0.0)
	_put("res://assets/props/lights/ceiling_lamp.tscn", Vector3(0, 2.6, 0.5), 0.0)
	_put("res://assets/props/lights/bare_bulb.tscn", Vector3(-3.2, 2.0, 2.8), 0.0)
	var dad := _put("res://assets/props/characters/man.tscn", Vector3(-0.5, 0.05, 2.0), 180.0)
	_act(dad, "Sit")
	var child := _put("res://assets/props/characters/child.tscn", Vector3(0.6, 0.05, 2.0), 180.0)
	_act(child, "Sit")
	var mum := _put("res://assets/props/characters/woman_casual.tscn", Vector3(3.2, 0, 2.8), -90.0)
	_walk(mum, [Vector3(3.2, 0, 2.8), Vector3(1.6, 0, 1.0)], 1.0)
	timeline.set_duration(8.0)
	_camera(Vector3(2.8, 1.6, -2.2), Vector3(0, 1.0, 1.6), 48.0, "Pan left", 8.0, 1.2)


# --- Short-film sets (1.27) --------------------------------------------------------

func _story(piece: String, at: Vector3, yaw: float, settings: Dictionary = {}) -> Node3D:
	var node := _put("res://assets/props/story/%s.tscn" % piece, at, yaw)
	if node:
		for key in settings:
			node.set(key, settings[key])
	return node


func _story_room(w: float, d: float, h: float, wall: Color, lower: Color, floor_style: String, floor_color: Color, doorway: bool = true) -> void:
	var room := _put("res://assets/props/buildings/room.tscn", Vector3.ZERO, 0.0) as Room
	if room:
		room.width = w
		room.depth = d
		room.height = h
		room.wall_color = wall
		room.lower_wall_color = lower
		room.floor_style = floor_style
		room.floor_color = floor_color
		room.windows = 0
		room.doorway = doorway


func _kitchen() -> void:
	_indoor_env(19.6, 1.3)
	_story_room(6.0, 5.0, 2.8, Color(0.94, 0.86, 0.72), Color(0.78, 0.6, 0.46), "Tiles", Color(0.86, 0.8, 0.7))
	_story("kitchen_cabinets", Vector3(-0.9, 0, -2.2), 0.0, {"width": 2.8})
	_story("retro_fridge", Vector3(1.25, 0, -2.15), 0.0)
	_story("wall_clock", Vector3(2.15, 0, -2.48), 0.0)
	_story("window", Vector3(-2.97, 0, 0.3), 90.0, {"color": Color(0.14, 0.18, 0.32)})
	_story("floor_rug", Vector3(0.3, 0, 0.75), 0.0, {"width": 2.6})
	_story("dining_table", Vector3(0.3, 0, 0.7), 0.0)
	_story("dining_chair", Vector3(0.3, 0, 0.12), 0.0)
	_story("dining_chair", Vector3(-0.68, 0, 0.7), 90.0)
	_story("dining_chair", Vector3(1.28, 0, 0.7), -90.0)
	_story("pendant_lamp", Vector3(0.3, 0, 0.7), 0.0)
	_story("picture_frame", Vector3(2.97, 0, -1.0), -90.0, {"color": Color(0.55, 0.7, 0.8)})
	_story("potted_plant", Vector3(-2.6, 0, -1.4), 0.0)
	_story("wall_shelf", Vector3(-2.97, 0, -1.5), 90.0, {"width": 1.0})
	_put("res://assets/props/lights/ceiling_lamp.tscn", Vector3(-0.9, 2.65, -1.4), 0.0)
	timeline.set_duration(6.0)
	_camera(Vector3(2.4, 1.6, 2.3), Vector3(-0.4, 1.0, -1.2), 50.0, "Dolly in", 6.0, 0.6)


func _bedroom() -> void:
	_indoor_env(21.5, 1.25)
	_story_room(4.6, 4.6, 2.7, Color(0.56, 0.63, 0.74), Color(0.42, 0.48, 0.58), "Wood planks", Color(0.55, 0.4, 0.28))
	_story("cosy_bed", Vector3(-1.0, 0, -1.15), 0.0)
	_story("bedside_table", Vector3(0.1, 0, -2.0), 0.0)
	_story("desk", Vector3(1.45, 0, -1.95), 0.0)
	_story("desk_chair", Vector3(1.3, 0, -1.3), 180.0)
	_story("wardrobe", Vector3(1.98, 0, 0.5), -90.0)
	_story("window", Vector3(-2.27, 0, 0.7), 90.0, {"width": 1.1, "color": Color(0.1, 0.13, 0.26)})
	_story("poster", Vector3(0.7, 0, -2.28), 0.0)
	_story("floor_rug", Vector3(0.1, 0, 0.5), 0.0, {"width": 1.8, "color": Color(0.85, 0.75, 0.55)})
	_story("potted_plant", Vector3(-1.95, 0, 1.8), 0.0)
	var lamp := _put("res://assets/props/lights/ceiling_lamp.tscn", Vector3(0, 2.55, 0.2), 0.0) as LightProp
	if lamp:
		lamp.brightness = 0.5
	timeline.set_duration(6.0)
	_camera(Vector3(1.6, 1.5, 2.1), Vector3(-0.4, 0.8, -1.2), 52.0, "Dolly in", 6.0, 0.5)


func _cafe() -> void:
	_indoor_env(17.5, 1.3)
	_story_room(9.0, 7.0, 3.0, Color(0.94, 0.89, 0.78), Color(0.52, 0.38, 0.27), "Wood planks", Color(0.47, 0.33, 0.22))
	_story("cafe_counter", Vector3(1.0, 0, -2.4), 0.0, {"width": 3.4})
	_story("menu_board", Vector3(1.0, 0, -3.48), 0.0)
	_story("wall_shelf", Vector3(-2.4, 0, -3.48), 0.0, {"width": 1.6})
	_story("picture_frame", Vector3(-2.4, 0, -3.48), 0.0, {"color": Color(0.85, 0.55, 0.4)})
	for x in [0.0, 2.0]:
		_story("pendant_lamp", Vector3(x, 0.2, -2.4), 0.0)
	for table in [Vector3(-2.6, 0, -0.2), Vector3(-0.7, 0, 1.3), Vector3(1.8, 0, 1.0)]:
		_story("cafe_table", table, 0.0)
		_story("cafe_chair", table + Vector3(-0.58, 0, 0), 90.0)
		_story("cafe_chair", table + Vector3(0.58, 0, 0), -90.0)
	for lamp_at in [Vector3(-2.0, 2.85, 0.6), Vector3(1.0, 2.85, 1.2)]:
		var ceiling := _put("res://assets/props/lights/ceiling_lamp.tscn", lamp_at, 0.0) as LightProp
		if ceiling:
			ceiling.brightness = 0.7
	for z in [-1.4, 1.6]:
		_story("window", Vector3(-4.47, 0, z), 90.0, {"width": 1.7, "color": Color(0.45, 0.55, 0.7)})
	_story("potted_plant", Vector3(-4.0, 0, -3.0), 0.0)
	_story("potted_plant", Vector3(4.0, 0, -3.0), 0.0)
	_story("picture_frame", Vector3(4.47, 0, -1.6), -90.0)
	timeline.set_duration(6.0)
	_camera(Vector3(-2.5, 1.7, 3.2), Vector3(1.0, 1.1, -2.2), 50.0, "Truck right", 6.0, 1.0)


func _barbershop() -> void:
	_indoor_env(11.0, 1.3)
	_story_room(8.0, 6.0, 3.0, Color(0.74, 0.84, 0.85), Color(0.42, 0.55, 0.6), "Tiles", Color(0.9, 0.88, 0.82))
	_story("photo_wall", Vector3(-0.1, 0, -2.98), 0.0, {"width": 2.6})
	_story("barber_chair", Vector3(-1.3, 0, -1.1), 0.0)
	_story("barber_chair", Vector3(1.1, 0, -1.1), 0.0)
	_story("barber_mirror", Vector3(-3.98, 0, -0.9), 90.0)
	_story("barber_mirror", Vector3(-3.98, 0, 0.6), 90.0)
	_story("waiting_bench", Vector3(3.7, 0, 0.2), -90.0)
	_story("wall_shelf", Vector3(2.4, 0, -2.98), 0.0, {"width": 1.4, "accent": Color(0.3, 0.55, 0.75)})
	_story("wall_clock", Vector3(2.4, 0, -2.99), 0.0)
	_story("barber_pole", Vector3(3.98, 0, -2.2), -90.0)
	_story("potted_plant", Vector3(-3.5, 0, -2.5), 0.0)
	for x in [-1.3, 1.1]:
		_story("pendant_lamp", Vector3(x, 0.2, -1.1), 0.0, {"color": Color(0.3, 0.32, 0.34)})
	timeline.set_duration(6.0)
	_camera(Vector3(0.0, 1.5, 3.0), Vector3(-0.1, 1.2, -1.5), 50.0, "Dolly in", 6.0, 0.6)


func _hallway() -> void:
	_indoor_env(20.0, 1.25)
	_story_room(12.0, 3.0, 2.7, Color(0.88, 0.83, 0.72), Color(0.46, 0.36, 0.3), "Carpet", Color(0.55, 0.28, 0.25), false)
	var numbers := ["10", "11", "12"]
	var xs := [-4.2, -1.2, 1.8]
	for i in 3:
		_story("apartment_door", Vector3(xs[i], 0, -1.47), 0.0, {"label": numbers[i], "color": [Color(0.55, 0.4, 0.3), Color(0.35, 0.45, 0.55), Color(0.55, 0.4, 0.3)][i]})
	_story("elevator", Vector3(4.6, 0, -1.46), 0.0)
	_story("notice_board", Vector3(3.05, 0, -1.48), 0.0)
	for x in [-5.6, -2.7, 0.3, 3.1]:
		_story("wall_lamp", Vector3(x, 0, -1.48), 0.0)
	_story("potted_plant", Vector3(-5.6, 0, -1.0), 0.0)
	timeline.set_duration(6.0)
	_camera(Vector3(-2.0, 1.6, 1.4), Vector3(2.5, 1.2, -1.2), 55.0, "Truck right", 6.0, 1.2)


func _rooftop() -> void:
	_set_env({"time_of_day": 17.3, "sun_azimuth": 250.0, "cloud_cover": 0.35, "mist": 0.08, "wind": 0.15, "rain": 0.0, "snow": 0.0, "leaves": 0.0,
		"ground_style": "Asphalt", "exposure": 1.1, "fog_density": 0.004, "ambient_energy": 1.0, "sun_intensity": 1.0})
	_story("roof_deck", Vector3(0, 0, 0), 0.0, {"width": 16.0})
	_story("parapet", Vector3(0, 0, -7.9), 0.0, {"width": 16.0})
	_story("parapet", Vector3(-7.9, 0, 0), 90.0, {"width": 16.0})
	_story("parapet", Vector3(7.9, 0, 0), -90.0, {"width": 16.0})
	_story("water_tower", Vector3(-5.2, 0, -5.3), 0.0)
	_story("roof_door", Vector3(5.0, 0, -4.2), 0.0)
	_story("string_lights", Vector3(-0.5, 0, -2.0), 0.0, {"width": 9.0})
	_story("picnic_table", Vector3(-1.5, 0, 0.5), 0.0)
	_story("planter", Vector3(7.3, 0, 1.5), -90.0, {"width": 2.4})
	_story("planter", Vector3(-7.3, 0, 2.5), 90.0, {"width": 2.0})
	_story("skyline", Vector3(0, 0, -34), 0.0, {"width": 110.0})
	_story("skyline", Vector3(-40, 0, 0), 90.0, {"width": 80.0})
	_story("skyline", Vector3(40, 0, 0), -90.0, {"width": 80.0})
	timeline.set_duration(6.0)
	_camera(Vector3(2.5, 1.7, 6.0), Vector3(-1.0, 1.4, -6.0), 50.0, "Crane up", 6.0, 0.8)


func _street_corner(time: float) -> void:
	_set_env({"time_of_day": time, "sun_azimuth": 240.0, "cloud_cover": 0.55, "mist": 0.06, "wind": 0.2, "rain": 0.0, "snow": 0.0, "leaves": 0.0,
		"ground_style": "Asphalt", "exposure": 1.1, "fog_density": 0.004, "ambient_energy": 1.0, "sun_intensity": 1.0})
	var road := _put("res://assets/props/city/road.tscn", Vector3.ZERO, 0.0) as Road
	if road:
		road.length = 120.0
		road.lanes = 2
		road.pavement = 4.5
		road.crossing = false
	_story("shop_front", Vector3(8.3, 0, -3.0), -90.0, {"label": "BAKERY", "width": 7.0})
	_story("shop_front", Vector3(8.3, 0, 5.0), -90.0, {"label": "PHARMACY", "width": 7.0, "color": Color(0.82, 0.78, 0.7), "accent": Color(0.25, 0.5, 0.35)})
	_story("shop_front", Vector3(-8.3, 0, 1.0), 90.0, {"label": "BOOKS", "width": 8.0, "color": Color(0.45, 0.4, 0.5), "accent": Color(0.6, 0.3, 0.3)})
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for side in [-1.0, 1.0]:
		for z in [-30.0, -14.0, 18.0, 34.0]:
			var building := _put("res://assets/props/city/brick_building.tscn" if rng.randf() < 0.5 else "res://assets/props/city/apartment_block.tscn", Vector3(side * 14.3, 0, z), 0.0) as Building
			if building:
				building.floors = rng.randi_range(3, 5)
				building.width = 12.0
				building.depth = 12.0
				building.variation = rng.randi_range(0, 99)
		var behind := _put("res://assets/props/city/apartment_block.tscn", Vector3(side * 15.0, 0, 1.0), 0.0) as Building
		if behind:
			behind.floors = 5
			behind.width = 12.0
			behind.depth = 13.0
	for z in [-16.0, 14.0]:
		_put("res://assets/props/decorations/lamp_post.tscn", Vector3(7.8, 0, z), -90.0)
		_put("res://assets/props/decorations/lamp_post.tscn", Vector3(-7.8, 0, z + 8.0), 90.0)
	_put("res://assets/props/city/trash_bin.tscn", Vector3(4.2, 0, 3.0), 0.0)
	_story("potted_plant", Vector3(7.7, 0, -0.8), 0.0)


func _bus_stop() -> void:
	_street_corner(16.3)
	_story("bus_shelter", Vector3(6.4, 0, 0.6), -90.0)
	_story("shelter_bench", Vector3(6.75, 0, 0.6), -90.0)
	_story("bus_sign", Vector3(4.2, 0, -1.6), -90.0)
	timeline.set_duration(6.0)
	_camera(Vector3(0.5, 1.5, 3.5), Vector3(6.5, 1.2, 0.4), 50.0, "Dolly in", 6.0, 0.8)


func _car() -> void:
	_street_corner(15.6)
	_story("car_body", Vector3(1.8, 0, 0.0), 0.0)
	var driver := _story("car_seat", Vector3(1.4, 0.12, -0.1), 0.0)
	if driver:
		driver.name = "DriverSeat"
	var passenger := _story("car_seat", Vector3(2.2, 0.12, -0.1), 0.0)
	if passenger:
		passenger.name = "PassengerSeat"
	timeline.set_duration(6.0)
	_camera(Vector3(1.8, 1.6, 3.6), Vector3(1.8, 1.35, -0.2), 40.0, "Dolly in", 6.0, 0.4)


func _big_city() -> void:
	_set_env({"time_of_day": 18.6, "sun_azimuth": 230.0, "ground_style": "Asphalt", "fog_density": 0.006, "exposure": 1.2, "cloud_cover": 0.3})
	var main_road := _put("res://assets/props/city/road.tscn", Vector3.ZERO, 0.0) as Road
	if main_road:
		main_road.length = 220.0
		main_road.lanes = 4
	var cross := _put("res://assets/props/city/road.tscn", Vector3(0, 0.005, 0), 90.0) as Road
	if cross:
		cross.length = 160.0
		cross.crossing = false
	var styles := ["res://assets/props/city/glass_tower.tscn", "res://assets/props/city/office_building.tscn",
		"res://assets/props/city/apartment_block.tscn", "res://assets/props/city/brick_building.tscn"]
	for side in [-1.0, 1.0]:
		for i in 6:
			var z := -95.0 + float(i) * 34.0
			if absf(z) < 14.0:
				continue
			var building := _put(styles[_rng.randi_range(0, 3)], Vector3(side * 24.0, 0, z), 0.0) as Building
			if building:
				building.floors = _rng.randi_range(5, 32)
				building.variation = _rng.randi_range(0, 99)
	for z in [-60.0, -36.0, -20.0, 20.0, 36.0, 60.0]:
		_put("res://assets/props/decorations/lamp_post.tscn", Vector3(-8.6, 0, z), 90.0)
		_put("res://assets/props/decorations/lamp_post.tscn", Vector3(8.6, 0, z), -90.0)
	for p in [Vector3(-8.6, 0, -9), Vector3(8.6, 0, 9)]:
		_put("res://assets/props/city/traffic_light.tscn", p, 0.0 if p.x < 0 else 180.0)
	_put("res://assets/props/city/bus_stop.tscn", Vector3(9.6, 0, 26), -90.0)
	_put("res://assets/props/city/trash_bin.tscn", Vector3(-9.4, 0, 30), 0.0)
	var bus := _put("res://assets/props/vehicles/bus.tscn", Vector3(5.2, 0, -80), 0.0)
	_walk(bus, [Vector3(5.2, 0, -80), Vector3(5.2, 0, 60)], 9.0)
	var car := _put("res://assets/props/vehicles/car.tscn", Vector3(-5.2, 0, 70), 180.0)
	_walk(car, [Vector3(-5.2, 0, 70), Vector3(-5.2, 0, -70)], 12.0)
	var walker := _put("res://assets/props/characters/man_suit.tscn", Vector3(-10, 0, -30), 0.0)
	_walk(walker, [Vector3(-10, 0, -30), Vector3(-10, 0, 20)], 1.5)
	var walker2 := _put("res://assets/props/characters/woman.tscn", Vector3(10, 0, 30), 180.0)
	_walk(walker2, [Vector3(10, 0, 30), Vector3(10, 0, -20)], 1.3)
	timeline.set_duration(14.0)
	_camera(Vector3(-4, 2, 40), Vector3(0, 6, -20), 55.0, "Crane up", 14.0, 18.0)


func _golden_valley() -> void:
	_set_env({"time_of_day": 18.3, "sun_azimuth": 260.0, "mist": 0.35, "wind": 0.35, "cloud_cover": 0.45, "ground_style": "Dry grass", "leaves": 0.2, "exposure": 1.15})
	_shape_terrain(_valley_height)
	var river := _place("res://assets/props/water/river.tscn", Vector3(0, 0, 0), 15.0) as River
	if river:
		river.length = 240.0
		river.width = 7.0
		river.winding = 0.45
		river.bends = 2.5
		terrain.carve_for(river)
		river.real_depth = true
	vegetation.scatter("Broadleaf trees", Vector2(0, 0), 120.0, 260, func(x: float, _z: float, y: float) -> bool: return absf(x) > 12.0 and y < 16.0)
	vegetation.scatter("Tall grass", Vector2(0, 0), 60.0, 6000, func(x: float, _z: float, _y: float) -> bool: return absf(x) > 6.0)
	vegetation.scatter("Flowers", Vector2(-20, 20), 30.0, 1500, func(x: float, _z: float, _y: float) -> bool: return absf(x) > 7.0)
	vegetation.scatter("Rocks", Vector2(0, 0), 40.0, 80, func(x: float, _z: float, _y: float) -> bool: return absf(x) < 14.0)
	var walker := _place("res://assets/props/characters/woman_casual.tscn", Vector3(-18, 0, 30), 160.0)
	_walk(walker, [Vector3(-18, 0, 30), Vector3(-14, 0, 10), Vector3(-12, 0, -5)], 1.1)
	timeline.set_duration(15.0)
	_camera(Vector3(-30, 9, 45), Vector3(0, 2, 0), 40.0, "Orbit right", 15.0, 1.5)


func _valley_height(x: float, z: float) -> float:
	var valley := absf(x)
	return smoothstep(6.0, 110.0, valley) * 22.0 + _hills(x, z, 0.012, 7.0) * smoothstep(5.0, 25.0, valley)


func _comedy() -> void:
	_indoor_env(21.5, 1.0)
	environment.set("ambient_energy", 0.25)
	_put("res://assets/props/buildings/studio_room.tscn", Vector3.ZERO, 0.0)
	_put("res://assets/props/stage/stage_platform.tscn", Vector3(0, 0, -2.6), 0.0)
	_put("res://assets/props/stage/brick_backdrop.tscn", Vector3(0, 0, -4.8), 0.0)
	_put("res://assets/props/stage/mic_stand.tscn", Vector3(0.4, 0.6, -1.4), 0.0)
	_put("res://assets/props/stage/bar_stool.tscn", Vector3(-1.0, 0.6, -2.2), 0.0)
	var comedian := _put("res://assets/props/characters/man.tscn", Vector3(0, 0.6, -1.9), 0.0)
	_act(comedian, "Talk")
	_put("res://assets/props/lights/spotlight.tscn", Vector3(0, 4.6, 2.5), 0.0, Vector3(0, 1.4, -1.9))
	_put("res://assets/props/lights/spotlight.tscn", Vector3(-3.5, 4.6, 1.5), 0.0, Vector3(0, 1.4, -2.2))
	for x in [-4.5, 0.0, 4.5]:
		_put("res://assets/props/lights/bare_bulb.tscn", Vector3(x, 4.2, 3.5), 0.0)
	for row in 2:
		for i in 5:
			var p := Vector3(-3.0 + float(i) * 1.5, 0, 2.0 + float(row) * 1.6)
			_put("res://assets/props/furniture/chair.tscn", p, 180.0)
			if _rng.randf() < 0.8:
				var fan := _put(["res://assets/props/characters/man.tscn", "res://assets/props/characters/woman.tscn", "res://assets/props/characters/woman_casual.tscn", "res://assets/props/characters/elder.tscn"][_rng.randi_range(0, 3)], p, 180.0)
				_act(fan, "Sit" if _rng.randf() < 0.7 else "Clap")
	if titles:
		titles.load_list([{"text": "LIVE AT THE COMEDY CLUB", "start": 0.5, "length": 3.5, "style": "Caption (top)"}])
	timeline.set_duration(12.0)
	_camera(Vector3(2.5, 1.6, 4.8), Vector3(0, 1.6, -1.9), 38.0, "Dolly in", 12.0, 3.0)


func _news_studio() -> void:
	_indoor_env(12.0, 1.1)
	environment.set("ambient_energy", 0.6)
	_put("res://assets/props/buildings/studio_room.tscn", Vector3.ZERO, 0.0)
	_put("res://assets/props/stage/video_wall.tscn", Vector3(0, 0, -4.6), 0.0)
	_put("res://assets/props/stage/news_desk.tscn", Vector3(0, 0, -1.6), 0.0)
	_put("res://assets/props/interior/office_chair.tscn", Vector3(-0.5, 0, -2.4), 0.0)
	var anchor := _put("res://assets/props/characters/woman.tscn", Vector3(-0.5, 0, -2.2), 0.0)
	_act(anchor, "Talk")
	var guest := _put("res://assets/props/characters/man_suit.tscn", Vector3(0.9, 0, -2.2), -10.0)
	_act(guest, "Think")
	for p in [Vector3(-3, 4.2, 2.5), Vector3(3, 4.2, 2.5), Vector3(0, 4.4, 1)]:
		_put("res://assets/props/lights/soft_panel.tscn", p, 0.0, Vector3(0, 1.4, -2.2))
	_put("res://assets/props/lights/spotlight.tscn", Vector3(0, 4.5, -4.0), 0.0, Vector3(0, 1.5, -2.2))
	if titles:
		titles.load_list([
			{"text": "BREAKING NEWS\nScene Builder makes films easy", "start": 1.0, "length": 5.0, "style": "Lower third"},
		])
	timeline.set_duration(10.0)
	_camera(Vector3(0, 1.5, 3.8), Vector3(0, 1.3, -2.2), 35.0, "Zoom in", 10.0, 1.5)


# --- Helpers -------------------------------------------------------------------

## Places a prop at an exact position (indoor props sit on floors, not terrain),
## optionally turned to look at [param target] (lights).
func _put(path: String, at: Vector3, yaw_degrees: float, target: Variant = null) -> Node3D:
	var node := PropUtils.create_prop(path)
	if node == null:
		return null
	node.position = at
	node.rotation_degrees.y = yaw_degrees
	placed_props_root.add_child(node, true)
	if target is Vector3:
		var aim: Vector3 = target
		if not aim.is_equal_approx(node.global_position):
			node.look_at(aim, Vector3.UP if absf((aim - node.global_position).normalized().y) < 0.99 else Vector3.FORWARD)
	return node


func _act(node: Node3D, action: String) -> void:
	if _flat:
		return   # an extra set for a scripted film: its people and timing aren't used
	if node is CharacterBase:
		timeline.set_time(0.0, false)
		timeline.set_character_action(node as CharacterBase, action)

func _sketch_stage() -> void:
	_set_env({"look": SketchLook.LOOK, "time_of_day": 21.0, "rain": 0.0, "snow": 0.0, "mist": 0.0, "wind": 0.0, "leaves": 0.0})
	_place("res://assets/props/sketch/sketch_floor_line.tscn", Vector3(10, 0, 0), 0.0)
	var person := _place("res://assets/props/characters/sketch_person.tscn", Vector3(-1.2, 0, 0), 90.0)
	if person is SketchCharacter:
		(person as SketchCharacter).expression = "Tired"
	_place("res://assets/props/characters/sketch_shadow.tscn", Vector3(-2.6, 0, -0.4), 90.0)
	_place("res://assets/props/sketch/sketch_desk.glb", Vector3(0.4, 0, -0.2), 0.0)
	_place("res://assets/props/sketch/sketch_desk_lamp.glb", Vector3(0.0, 0.78, -0.25), 0.0)
	_place("res://assets/props/sketch/sketch_warm_glow.tscn", Vector3(0.2, 0.9, -0.3), 0.0)
	timeline.set_duration(8.0)
	_camera(Vector3(-0.4, 1.0, 22), Vector3(-0.4, 1.0, 0), 14.0, "Dolly in", 8.0, 1.5)
	for child in placed_props_root.get_children():
		if child is Node3D and not child is SketchCharacter:
			SketchLook.flatten(child)


func _set_env(values: Dictionary) -> void:
	for key in values:
		environment.set(key, values[key])
		_env_requested[key] = values[key]


func _forest_height(x: float, z: float) -> float:
	var hills := _hills(x, z, 0.018, 9.0)
	var bowl := smoothstep(70.0, 25.0, Vector2(x + 10.0, z).length())
	return hills * smoothstep(20.0, 70.0, Vector2(x + 10.0, z).length()) - bowl * 0.4


func _seaside_height(x: float, z: float) -> float:
	return maxf(0.0, -z - 20.0) * 0.05 + _hills(x, z, 0.02, 2.0) * smoothstep(-20.0, -60.0, z)


func _mountain_height(x: float, z: float) -> float:
	var valley := absf(x - sin(z * 0.03) * 8.0)
	var walls := smoothstep(10.0, 90.0, valley) * 38.0
	return walls + _hills(x, z, 0.03, 6.0) * smoothstep(8.0, 30.0, valley) - smoothstep(9.0, 3.0, valley) * 1.5


func _hills(x: float, z: float, frequency: float, height: float) -> float:
	return (sin(x * frequency * 6.28) * cos(z * frequency * 5.1) * 0.5 + sin((x + z) * frequency * 2.7) * 0.5 + 1.0) * 0.5 * height


func _shape_terrain(height_fn: Callable) -> void:
	var state := terrain.snapshot()
	var heights: PackedFloat32Array = state["heights"]
	for z in Terrain.RES:
		for x in Terrain.RES:
			var wx := float(x) * Terrain.SPACING - Terrain.HALF
			var wz := float(z) * Terrain.SPACING - Terrain.HALF
			var border := minf(minf(float(x), float(z)), minf(float(Terrain.RES - 1 - x), float(Terrain.RES - 1 - z))) * Terrain.SPACING
			var fade := clampf((border - 1.0) / 12.0, 0.0, 1.0)
			var h: float = height_fn.call(wx, wz)
			heights[z * Terrain.RES + x] = h * fade
	state["heights"] = heights
	terrain.restore(state)


func _place(path: String, at: Vector3, yaw_degrees: float) -> Node3D:
	var node := PropUtils.create_prop(path)
	if node == null:
		return null
	node.position = Vector3(at.x, terrain.height_at(at.x, at.z) if Terrain.contains(at.x, at.z) and not _flat else at.y, at.z)
	node.rotation_degrees.y = yaw_degrees
	placed_props_root.add_child(node, true)
	return node


func _walk(node: Node3D, points: Array, speed: float) -> void:
	if node == null or _flat:
		return
	var grounded: Array = []
	for p in points:
		var v: Vector3 = p
		grounded.append(Vector3(v.x, terrain.height_at(v.x, v.z), v.z))
	timeline.set_time(0.0, false)
	timeline.add_path_keys(node, grounded, speed)


func _camera(position: Vector3, target: Vector3, fov: float, move: String, seconds: float, amount: float) -> void:
	if _flat:
		# Building an extra set: no camera (and no timeline change, which would put the
		# lighting back to the film's own before the set's lighting is read).
		return
	var ground := terrain.height_at(position.x, position.z) if Terrain.contains(position.x, position.z) else 0.0
	var from := Vector3(position.x, maxf(position.y, ground + 1.5), position.z)
	var look := Transform3D(Basis(), from).looking_at(target, Vector3.UP)
	var euler := look.basis.get_euler()
	director.restore_cameras([{"position": [from.x, from.y, from.z],
		"rotation_degrees": [rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)],
		"fov": fov, "focus_distance": from.distance_to(target), "dof_enabled": false}])
	var cams := director.cameras()
	if cams.is_empty():
		return
	var cam: CinematicCamera = cams[cams.size() - 1]
	director.set_default_camera(cam)
	timeline.set_time(0.0, false)
	timeline.add_camera_move(cam, move, seconds, amount)


func _away_from(centre: Vector2, distance: float) -> Callable:
	return func(x: float, z: float, _y: float) -> bool: return Vector2(x, z).distance_to(centre) > distance


func _ring(centre: Vector2, inner: float, outer: float) -> Callable:
	return func(x: float, z: float, _y: float) -> bool: return Vector2(x, z).distance_to(centre) > inner and Vector2(x, z).distance_to(centre) < outer

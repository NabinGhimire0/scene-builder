class_name ScriptDirector
extends Node
## Builds a whole film from a script ([FilmScript]): the location, set dressing,
## cast, every movement, gesture, line of dialogue (subtitles + lip sync), light
## and weather changes, music, titles and the camera shots with their cuts.
##
## Scripts describe places with words ("walks to the campfire", "close-up on
## Mira"); this class works out the positions, timing and camera framing.
## Everything it creates is ordinary scene content, editable afterwards.

const LOCATIONS := {
	"Sketch Stage": {"template": "Sketch Stage", "indoor": false, "flat": true,
		"about": "Flat sketch look: a black void with one drawn floor line, seen from the side like a 2D animation. Stage everything along the line (x = left/right, metres); use sketch people, the shadow and sketch props.",
		"overview": [0.0, 1.8, 30.0, 0.0, 1.8, 0.0, 14.0],
		"marks": {"center": [0, 0, 0, 0], "left": [-3, 0, 0, 90], "right": [3, 0, 0, -90], "far left": [-7, 0, 0, 90], "far right": [7, 0, 0, -90],
			"room 2": [16, 0, 0, 0], "room 3": [32, 0, 0, 0]}},
	"Blank World": {"template": "Blank World", "indoor": false,
		"about": "An empty, flat grassy world. Add everything with SET.",
		"overview": [10.0, 5.0, 16.0, 0.0, 1.0, 0.0, 45.0],
		"marks": {"center": [0, 0, 0, 0], "north": [0, 0, -15, 180], "south": [0, 0, 15, 0], "east": [15, 0, 0, -90], "west": [-15, 0, 0, 90]}},
	"Lakeside Campfire": {"template": "My First Film: The Lantern", "indoor": false,
		"about": "Golden-hour lake in a pine forest; a campfire and a bench on the grassy shore, a hill path coming down to it.",
		"overview": [-22.0, 9.0, 30.0, 12.0, 1.0, 6.0, 45.0],
		"env": {"time_of_day": 18.0, "mist": 0.3, "exposure": 1.15},
		"marks": {"lake": [-10, 0, 0, 0], "shore": [9.5, 0, 1.5, -90], "hill": [32, 0, 24, 220], "path": [26, 0, 17, 220], "clearing": [20.5, 0, 9, 220], "center": [17, 0, 6, 0]}},
	"Forest Lake": {"template": "Forest Lake", "indoor": false,
		"about": "Misty morning lake in a pine forest, a wooden hut and a campfire on a meadow.",
		"overview": [40.0, 6.0, 26.0, 10.0, 2.0, 2.0, 42.0],
		"marks": {"lake": [-10, 0, 0, 0], "shore": [15, 0, 1, -90], "meadow": [30, 0, 14, 200], "forest edge": [12, 0, 24, 180], "center": [24, 0, 6, 0]}},
	"Seaside Village": {"template": "Seaside Village", "indoor": false,
		"about": "Sandy beach at sunset with waves, a row of huts, a cart, barrels and torches.",
		"overview": [-30.0, 3.0, 10.0, 0.0, 1.5, -6.0, 45.0],
		"marks": {"beach": [0, 0, 4, 0], "shoreline": [0, 0, 11, 0], "village": [0, 0, -16, 180], "sea": [0, 0, 30, 0], "center": [0, 0, -4, 0]}},
	"Mountain River": {"template": "Mountain River", "indoor": false,
		"about": "Rocky valley with a fast river, a waterfall and snowy peaks.",
		"overview": [14.0, 5.0, 50.0, 0.0, 1.0, 0.0, 50.0],
		"marks": {"riverbank": [10, 0, 10, -90], "far bank": [-6, 0, 10, 90], "waterfall": [-26, 0, -40, 0], "valley trail": [15, 0, 40, 180], "center": [10, 0, 14, 0]}},
	"Rainy Night Street": {"template": "Rainy Night Street", "indoor": false,
		"about": "A wet city street at night in the rain, lamp posts, walls, a parked car and a van.",
		"overview": [0.0, 1.6, 30.0, 0.0, 1.4, 0.0, 40.0],
		"marks": {"street": [0, 0, 0, 0], "left sidewalk": [-4.5, 0, 0, 0], "right sidewalk": [4.5, 0, 0, 180], "street end": [0, 0, -28, 0], "street start": [0, 0, 24, 180], "center": [0, 0, 0, 0]}},
	"Rain Street": {"template": "Rain Street", "indoor": false,
		"about": "A quiet city street on a rainy night: low brick and apartment buildings with lit windows on both sides, lamp posts, parked cars, a two-lane road (x -3.5..3.5) and wide pavements (x 3.5..8). The right pavement around (6, 0) is free for your scene; add a bus stop or shop with SET.",
		"overview": [-2.0, 1.7, 26.0, 4.0, 1.8, -6.0, 45.0],
		"marks": {"right pavement": [6.5, 0, 0, -90], "left pavement": [-6.5, 0, 0, 90], "road": [0, 0, 0, 0], "street end": [0, 0, -60, 0], "street start": [0, 0, 50, 180], "center": [6.5, 0, 0, -90]}},
	"Classroom": {"template": "Classroom", "indoor": true, "bounds": [-5.0, 5.0, -4.5, 4.5, 3.2],
		"about": "School classroom: blackboard, teacher's desk, 12 pupil desks with chairs, bookshelf.",
		"overview": [3.6, 2.2, 4.3, 0.0, 1.3, -2.5, 50.0],
		"marks": {"front": [0, 0, -3.3, 0], "back": [0, 0, 4.0, 180], "aisle": [0, 0, 1.4, 180], "center": [0, 0, 1.0, 0]}},
	"Hospital Ward": {"template": "Hospital Ward", "indoor": true, "bounds": [-4.5, 4.5, -4.0, 4.0, 3.0],
		"about": "Bright hospital ward: 3 beds with IV stands, a screen, a cabinet and waiting chairs.",
		"overview": [-3.6, 1.8, 3.4, 0.5, 1.1, -2.0, 45.0],
		"marks": {"bedside": [0.9, 0, -1.2, 200], "waiting area": [0, 0, 2.6, 180], "center": [0, 0, 0.6, 0]}},
	"Living Room": {"template": "Living Room", "indoor": true, "bounds": [-4.0, 4.0, -3.5, 3.5, 2.8],
		"about": "Cosy evening living room: sofa, armchair, coffee table, TV, rug, bookshelf, lamps.",
		"overview": [2.8, 1.6, -2.2, 0.0, 1.0, 1.6, 48.0],
		"marks": {"center": [0, 0, 0.3, 0], "doorway": [3.4, 0, 1.75, -90], "hallway": [5.4, 0, 1.75, -90], "by the tv": [1.2, 0, -2.4, 180],
			"window": [-3.4, 0, 0.5, 90]}},
	# Short-film sets (1.27): furnished everyday places for story people (STYLE: short film).
	"Kitchen": {"template": "Kitchen", "indoor": true, "bounds": [-3.0, 3.0, -2.5, 2.5, 2.8],
		"about": "Warm home kitchen at evening: cabinets with a stove and sink along the back wall, a fridge, a window on the left, a dining table with 3 dining chairs under a hanging lamp in the middle.",
		"overview": [2.4, 1.6, 2.3, -0.4, 1.0, -1.2, 50.0],
		"marks": {"stove": [-1.6, 0, -1.5, 0], "sink": [-0.3, 0, -1.5, 0], "fridge": [1.25, 0, -1.45, 0], "table": [0.3, 0, 1.45, 180],
			"by the window": [-2.4, 0, 0.3, -90], "doorway": [2.6, 0, 1.25, -90], "center": [0.3, 0, -0.4, 0]}},
	"Bedroom": {"template": "Bedroom", "indoor": true, "bounds": [-2.3, 2.3, -2.3, 2.3, 2.7],
		"about": "Small bedroom at night: a cosy bed on the left, bedside table with a lamp, a desk with a laptop and desk chair on the right, wardrobe, window on the left wall.",
		"overview": [1.6, 1.5, 2.1, -0.4, 0.8, -1.2, 52.0],
		"marks": {"bedside": [-0.05, 0, -0.9, 90], "by the window": [-1.7, 0, 0.7, -90], "doorway": [1.9, 0, 1.15, -90], "center": [0.2, 0, 0.4, 0]}},
	"Cafe": {"template": "Cafe", "indoor": true, "bounds": [-4.5, 4.5, -3.5, 3.5, 3.0],
		"about": "Cosy café: a long cafe counter at the back (staff stand at 'till', customers at 'counter') with a coffee machine, cake display and register, a menu board, 3 small round cafe tables with 2 cafe chairs each, windows on the left.",
		"overview": [-2.5, 1.7, 3.2, 1.0, 1.1, -2.2, 50.0],
		"marks": {"counter": [1.0, 0, -1.75, 180], "till": [1.0, 0, -3.05, 0], "window table": [-2.6, 0, 0.5, 0],
			"entrance": [3.9, 0, 1.75, -90], "center": [0.0, 0, 0.4, 0]}},
	"Barbershop": {"template": "Barbershop", "indoor": true, "bounds": [-4.0, 4.0, -3.0, 3.0, 3.0],
		"about": "Neighbourhood barbershop: two barber chairs facing the front (the barber stands at 'first station' or 'second station' behind them), a wall of customer photos behind them, mirrors on the left wall, a waiting bench on the right.",
		"overview": [0.0, 1.5, 3.0, -0.1, 1.2, -1.5, 50.0],
		"marks": {"first station": [-1.95, 0, -1.6, 52], "second station": [0.45, 0, -1.6, 52],
			"mirror": [-3.3, 0, -0.2, -90], "waiting area": [2.9, 0, 0.2, -90], "doorway": [3.6, 0, 1.5, -90], "center": [0.0, 0, 0.6, 0]}},
	"Apartment Hallway": {"template": "Apartment Hallway", "indoor": true, "bounds": [-6.0, 6.0, -1.5, 1.5, 2.7],
		"about": "Apartment corridor: doors 10, 11 and 12 along the back wall, an elevator at the right end, a notice board, wall lamps.",
		"overview": [-2.0, 1.6, 1.4, 2.5, 1.2, -1.2, 55.0],
		"marks": {"door 10": [-4.2, 0, -0.8, 180], "door 11": [-1.2, 0, -0.8, 180], "door 12": [1.8, 0, -0.8, 180], "elevator": [4.6, 0, -0.75, 180],
			"corridor end": [-5.4, 0, 0.2, 90], "center": [0.0, 0, 0.2, 0]}},
	"Rooftop": {"template": "Rooftop", "indoor": false, "camera_bounds": [-7.4, 7.4, -7.4, 7.6, 9.0],
		"about": "City rooftop at sunset: a parapet wall around it with the skyline beyond, a water tower, a little roof door hut, string lights, a picnic table, planters.",
		"overview": [2.5, 1.7, 6.0, -1.0, 1.4, -6.0, 50.0],
		"marks": {"view": [0.0, 0, -7.2, 180], "edge": [3.5, 0, -7.2, 180], "center": [0.0, 0, 0.5, 0]}},
	"Bus Stop": {"template": "Bus Stop", "indoor": false, "camera_bounds": [-8.0, 8.0, -14.0, 14.0, 9.0],
		"about": "Street corner in the late afternoon: a bus shelter with a shelter bench and a bus sign on the right pavement (x 4..8), a bakery and a pharmacy behind it, a bookshop across the two-lane road (x -3.5..3.5).",
		"overview": [0.5, 1.5, 3.5, 6.5, 1.2, 0.4, 50.0],
		"marks": {"bus stop": [5.5, 0, 0.6, -90], "kerb": [4.2, 0, 0.6, -90], "bakery": [7.6, 0, -3.0, 90], "pharmacy": [7.6, 0, 5.0, 90],
			"road": [0.0, 0, 0.6, 0], "street end": [6.0, 0, -18.0, 0], "street start": [6.0, 0, 16.0, 180], "center": [5.5, 0, 0.6, -90]}},
	"Car": {"template": "Car", "indoor": false,
		"about": "Inside a parked car on a city street: a driver seat (right side) and a passenger seat, dashboard and windscreen; shops on both pavements.",
		"overview": [1.8, 1.6, 3.6, 1.8, 1.35, -0.2, 40.0],
		"marks": {"outside the car": [4.2, 0, 0.0, -90], "pavement": [6.0, 0, 0.0, -90], "center": [1.8, 0, 0.0, 0]}},
	"Big City": {"template": "Big City", "indoor": false,
		"about": "Downtown at dusk: towers, a crossroads, traffic lights, a bus stop, lamp posts.",
		"overview": [-4.0, 2.0, 40.0, 0.0, 6.0, -20.0, 55.0],
		"marks": {"crossing": [0, 0, 0, 0], "left sidewalk": [-10, 0, 0, 0], "right sidewalk": [10, 0, 0, 180], "north street": [-10, 0, -60, 0], "south street": [10, 0, 60, 180], "center": [-10, 0, 10, 0]}},
	"Golden Valley": {"template": "Golden Valley", "indoor": false,
		"about": "Golden-hour valley with a winding river, flower meadows, trees and soft mist.",
		"overview": [-30.0, 9.0, 45.0, 0.0, 2.0, 0.0, 40.0],
		"marks": {"meadow": [-18, 0, 30, 160], "flowers": [-20, 0, 20, 160], "hillside": [-35, 0, 0, 90], "center": [-16, 0, 18, 0]}},
	"Comedy Club": {"template": "Stand-up Comedy", "indoor": true, "bounds": [-7.0, 7.0, -5.0, 5.0, 5.0],
		"about": "Comedy club: stage with brick wall, mic stand, bar stool, spotlights and rows of audience chairs.",
		"overview": [2.5, 1.6, 4.8, 0.0, 1.6, -1.9, 38.0],
		"marks": {"stage": [0, 0.6, -1.9, 0], "stage left": [-1.8, 0.6, -2.0, 0], "audience": [0, 0, 2.8, 180], "center": [0, 0, 1.0, 0]}},
	"News Studio": {"template": "News Studio", "indoor": true, "bounds": [-7.0, 7.0, -5.0, 5.0, 5.0],
		"about": "TV news studio: anchor desk, video wall, studio lights.",
		"overview": [0.0, 1.5, 3.8, 0.0, 1.3, -2.2, 35.0],
		"marks": {"anchor seat": [-0.5, 0, -2.2, 0], "guest seat": [0.9, 0, -2.2, -10], "studio floor": [0, 0, 1.0, 180], "center": [0, 0, 0.5, 0]}},
}

const CHARACTER_WORDS := {
	"girl": "woman casual", "young woman": "woman casual", "teen": "woman casual", "daughter": "woman casual",
	"woman": "woman", "lady": "woman", "mother": "woman", "mum": "woman", "mom": "woman", "teacher": "woman", "nurse": "woman casual",
	"boy": "child", "kid": "child", "child": "child", "pupil": "child", "student": "child", "son": "child",
	"old man": "elder", "grandfather": "elder", "grandpa": "elder", "old woman": "elder", "grandmother": "elder", "elder": "elder",
	"man": "man", "guy": "man", "father": "man", "dad": "man", "comedian": "man",
	"businessman": "man suit", "doctor": "man suit", "anchor": "man suit", "suit": "man suit", "boss": "man suit",
	"dog": "dog", "puppy": "dog",
	# Animals (1.23): rigged, furry, with walk / run / sit / lie down / eat.
	"cat": "cat", "kitten": "cat", "cow": "cow", "calf": "cow", "bull": "cow", "buffalo": "water buffalo",
	"goat": "goat", "sheep": "sheep", "lamb": "sheep", "horse": "horse", "pony": "horse", "donkey": "donkey",
	"yak": "yak", "deer": "deer", "pig": "pig", "piglet": "pig", "elephant": "elephant", "tiger": "tiger",
	"lion": "lion", "bear": "bear", "monkey": "monkey", "rabbit": "rabbit", "bunny": "rabbit", "fox": "fox",
	"wolf": "wolf", "chicken": "chicken", "hen": "chicken", "rooster": "chicken", "duck": "duck",
	"bird": "sparrow", "sparrow": "sparrow",
	"shadow": "sketch shadow", "temptation": "sketch shadow", "inner voice": "sketch shadow", "demon": "sketch shadow",
	"cartoon": "sketch person", "toon": "sketch person", "cartoon person": "sketch person", "cartoon character": "sketch person",
	"cartoon girl": "sketch person", "cartoon boy": "sketch person", "cartoon man": "sketch person", "cartoon woman": "sketch person",
	"sketch": "sketch person", "person": "sketch person", "stick figure": "sketch person", "drawn person": "sketch person",
	# Realistic people (1.22): motion-captured, game-quality humans.
	# Story people (1.27): black silhouettes with white eyes and coloured clothes.
	"silhouette man": "story man", "silhouette woman": "story woman", "silhouette boy": "story boy", "silhouette girl": "story girl",
	"silhouette child": "story child", "silhouette old man": "story old man", "silhouette old woman": "story old woman",
	"story grandfather": "story old man", "story grandmother": "story old woman", "story grandpa": "story old man", "story grandma": "story old woman",
	"story kid": "story child", "story elder": "story old man", "story teen": "story girl", "story lady": "story woman", "story guy": "story man",
	"story mother": "story woman", "story father": "story man", "story son": "story boy", "story daughter": "story girl",
	"realistic man": "realistic arjun", "realistic woman": "realistic maya", "realistic boy": "realistic tenzin",
	"realistic girl": "realistic mila", "realistic child": "realistic tenzin", "realistic kid": "realistic mila",
	"realistic old man": "realistic hari", "realistic grandfather": "realistic hari", "realistic grandpa": "realistic hari",
	"realistic old woman": "realistic kamala", "realistic grandmother": "realistic kamala", "realistic grandma": "realistic kamala",
	"real man": "realistic arjun", "real woman": "realistic maya", "real boy": "realistic tenzin", "real girl": "realistic mila",
}
const PROP_WORDS := {
	"fire": "campfire", "bonfire": "campfire", "couch": "sofa", "desk": "school desk", "board": "blackboard",
	"chalkboard": "blackboard", "television": "tv", "lamp": "lamp post", "streetlight": "lamp post", "street light": "lamp post",
	"house": "hut", "cabin": "hut", "stool": "bar stool", "microphone": "mic stand", "mic": "mic stand",
	"tree": "oak tree", "pine": "pine tree", "stone": "rock", "boulder": "rock", "box": "crate", "cupboard": "medical cabinet",
	"seat": "chair", "table": "table", "screen": "medical screen", "curtain": "stage curtain", "stage": "stage platform",
	"truck": "van", "automobile": "car", "wagon": "cart", "sign": "signpost", "torchlight": "torch",
}
const SEATS := {"chair": 0.0, "bench": 0.0, "sofa": 0.05, "armchair": 0.05, "stool": 0.25, "bed": 0.25, "office chair": 0.0, "waiting chairs": 0.0,
	"couch": 0.04, "seat": 0.0, "barber chair": 0.06}
const GESTURES := {
	"waves": "Wave", "wave": "Wave", "talks": "Talk", "chats": "Talk", "speaks": "Talk", "explains": "Talk",
	"claps": "Clap", "applauds": "Clap", "cheers": "Cheer", "celebrates": "Cheer",
	"thinks": "Think", "ponders": "Think", "wonders": "Think", "looks around": "Look Around", "searches": "Look Around",
	"dances": "Dance", "jumps": "Jump", "hops": "Jump", "idles": "Idle", "waits": "Idle", "rests": "Idle", "stands still": "Idle",
	"freezes": "Pose only", "whistles": "Look Around", "panics": "Look Around", "celebrate": "Cheer",
}
const GESTURE_SECONDS := {"Wave": 2.5, "Talk": 3.0, "Point": 2.5, "Clap": 3.0, "Cheer": 3.0, "Think": 3.0,
	"Look Around": 3.5, "Dance": 5.0, "Jump": 1.6, "Idle": 2.0, "Pose only": 1.5}
const POSE_GESTURES: PackedStringArray = ["gasps", "facepalms", "scratches head", "sleeps", "wakes up", "laughs", "giggles", "nods", "shakes head", "bows", "shrugs", "raises hand", "raises a hand", "raises his hand", "raises her hand"]
const JOINT_WORDS := {
	"right shoulder": "shoulder_r", "left shoulder": "shoulder_l", "right arm": "shoulder_r", "left arm": "shoulder_l",
	"right elbow": "elbow_r", "left elbow": "elbow_l", "right wrist": "wrist_r", "left wrist": "wrist_l", "right hand": "wrist_r", "left hand": "wrist_l",
	"right hip": "hip_r", "left hip": "hip_l", "right leg": "hip_r", "left leg": "hip_l", "right knee": "knee_r", "left knee": "knee_l",
	"right ankle": "ankle_r", "left ankle": "ankle_l", "right foot": "ankle_r", "left foot": "ankle_l",
}
const ENV_WORDS := {"time": "time_of_day", "hour": "time_of_day", "clouds": "cloud_cover", "cloud": "cloud_cover", "fog": "fog_density",
	"sun": "sun_intensity", "ambient": "ambient_energy", "azimuth": "sun_azimuth", "ground": "ground_style", "light": "ambient_energy"}
const SHOT_SIZES := {
	# kind: [distance, camera height (rel), target height (rel), fov, depth of field]
	"extreme close-up": [0.75, 0.02, 0.0, 24.0, true],
	"close-up": [1.35, 0.03, 0.0, 30.0, true],
	"medium": [2.5, -0.1, -0.3, 36.0, false],
	"full": [5.0, 0.0, 0.0, 40.0, false],
	"wide": [9.0, 0.0, 0.0, 45.0, false],
	"low angle": [2.4, 0.0, 0.0, 40.0, false],
	"high angle": [3.2, 2.0, -0.2, 40.0, false],
	"aerial": [22.0, 0.0, 0.0, 50.0, false],
}
const FRAME := 1.0 / 30.0
const TALL_PLANTS: PackedStringArray = ["Pine trees", "Broadleaf trees", "Bushes", "Tall grass"]

@export var builder: TemplateBuilder
## Automatic voices for dialogue: -1 = as the script says (VOICES: auto), 0 = off, 1 = on.
var speak_dialogue := -1

var _location: Dictionary = {}
var _location_name := ""
## True from a LOCATION line until the first SHOT after it: people sitting down there
## are simply seated when the new scene opens (the last shot is still on screen).
var _awaiting_first_shot := false
## Every location of the film: [{ name, data, offset, suffix, env }]; the first is the main world,
## the others are sets built on the "backlot", far beyond the terrain.
var _sets: Array = []
var _set_index := 0
var _offset := Vector3.ZERO
## The Flat sketch look is on (Sketch Stage, or STYLE: Flat sketch).
var _flat := false
var _suffix := ""
var _scene_set: Dictionary = {}   # scene index -> set index at its start
var _package_dir := ""
var _things: Dictionary = {}        # normalised name -> thing Dictionary
var _names: Array = []              # [normalised name, thing] longest first
var _titles: Array = []
var _clips: Array = []
var _shots: Array = []              # { t, spec, scene, auto }
var _events: Array = []             # { t, dur, kind, who, to, scene }
var _env_later: Array = []          # header "A -> B" changes keyed at the end
var _report: Dictionary = {}
var _catalog: Array[Dictionary] = []
var _end := 0.0
var _subtitles := true
## Dialogue as words floating next to the speaker (the short-film look), not subtitles.
var _floating := false
## STYLE: short film - the look of animated short films: soft graded colour, a
## blurred background behind people, a vignette, dialogue floating by the speaker.
var _story_style := false
var _speech_colors := {}
const SPEECH_PALETTE: Array[Color] = [Color(0.97, 0.96, 0.93), Color(1.0, 0.84, 0.45), Color(0.62, 0.86, 1.0), Color(1.0, 0.66, 0.74),
	Color(0.66, 0.95, 0.72), Color(1.0, 0.68, 0.42), Color(0.82, 0.72, 1.0)]
var _camera_mode := "auto"
var _shot_count := 0
var _last_speaker := ""
var _rng := RandomNumberGenerator.new()
var _voices_on := false
var _voice_warned := false


# --- Public ---------------------------------------------------------------------

## The running Scene Builder version, e.g. "1.5".
## The REQUIRES line of the film being built ("" if none): newer timing rules only
## apply to films written for them, so older films keep their music in sync.
var _written_for := ""


## True if the film says it was written for [param version] or newer (or says nothing).
func _written_for_at_least(version: String) -> bool:
	if _written_for.is_empty():
		return true
	var found := RegEx.create_from_string("(\\d+(?:\\.\\d+)*)").search(_written_for)
	if found == null:
		return true
	var have := found.get_string(1).split(".")
	var want := version.split(".")
	for i in maxi(want.size(), have.size()):
		var w := int(want[i]) if i < want.size() else 0
		var h := int(have[i]) if i < have.size() else 0
		if w != h:
			return h > w
	return true


static func app_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "1.0"))


## True if [param required] ("Scene Builder 1.4", "1.4", "v1.4.2") is newer than this app.
static func needs_newer_app(required: String) -> bool:
	var found := RegEx.create_from_string("(\\d+(?:\\.\\d+)*)").search(required)
	if found == null:
		return false
	var want := found.get_string(1).split(".")
	var have := app_version().split(".")
	for i in maxi(want.size(), have.size()):
		var w := int(want[i]) if i < want.size() else 0
		var h := int(have[i]) if i < have.size() else 0
		if w != h:
			return w > h
	return false


static func location_names() -> PackedStringArray:
	return PackedStringArray(LOCATIONS.keys())


## Parses and builds [param text]; files named in the script are looked up in
## [param package_dir] first. Returns the report (see [method _new_report]).
func build_from_text(text: String, package_dir: String = "") -> Dictionary:
	var model := FilmScript.parse(text)
	return build(model, package_dir)


func build(model: Dictionary, package_dir: String = "") -> Dictionary:
	_reset_state()
	_package_dir = package_dir
	for message in model.get("errors", []):
		_warn(str(message))
	var header: Dictionary = model.get("header", {})
	_written_for = str(header.get("requires", ""))
	if header.has("requires") and needs_newer_app(str(header["requires"])):
		_warn("This film was written for %s, and this is Scene Builder %s. Some lines may be skipped or look different: please update Scene Builder." % [str(header["requires"]).strip_edges(), app_version()])
		_report["outdated"] = true
	_rng.seed = hash(str(header.get("title", "film")))
	_subtitles = str(header.get("subtitles", "on")).to_lower() != "off"
	var dialogue_style := (str(header.get("dialogue", header.get("speech", ""))) + " " + str(header.get("subtitles", ""))).to_lower()
	_floating = dialogue_style.contains("float") or dialogue_style.contains("near") or dialogue_style.contains("beside") or dialogue_style.contains("bubble")
	_speech_colors = {}
	_camera_mode = "manual" if str(header.get("camera", "auto")).to_lower().begins_with("manual") else "auto"
	var voices_header := str(header.get("voices", "off")).to_lower()
	_voices_on = voices_header.begins_with("auto") or voices_header.begins_with("on") or voices_header.begins_with("yes")
	if speak_dialogue >= 0:
		_voices_on = speak_dialogue == 1
	_voice_warned = false

	_import_animation_packs()
	_build_location(str(header.get("location", "Blank World")))
	var style := _norm(str(header.get("style", header.get("look", ""))))
	if style.contains("sketchbook") or style.contains("pencil") or style.contains("storybook") or style.contains("watercolo"):
		builder.environment.look = SketchLook.SKETCHBOOK
	elif style.contains("cartoon") or style.contains("toon") or style.contains("bright"):
		builder.environment.look = SketchLook.CARTOON
	elif style.contains("paper") or style.contains("ink"):
		builder.environment.look = SketchLook.PAPER
	elif style.contains("flat") or style.contains("sketch") or style.contains("2d"):
		builder.environment.look = SketchLook.LOOK
	_story_style = style.contains("short film") or style == "story" or style.contains("silhouette") or style.contains("animated short")
	if _story_style:
		_floating = not str(header.get("dialogue", header.get("speech", ""))).to_lower().begins_with("sub")
		builder.environment.set("bloom", 0.18)
		builder.environment.set("contrast", 0.94)
		builder.environment.set("saturation", 0.86)
	_flat = builder.environment.is_flat()
	var timeline := builder.timeline
	timeline.store.duration = TimelineController.MAX_DURATION
	_apply_header_environment(header)
	_sets = [{"name": _location_name, "data": _location, "offset": Vector3.ZERO, "suffix": "", "env": builder.environment.capture()}]
	_use_set(0)
	_register_location_marks()
	for entry in model.get("set", []):
		_add_set_piece(str(entry["text"]))
	for entry in model.get("cast", []):
		_add_cast(str(entry["name"]), str(entry["spec"]))
	if str(header.get("music", "")).strip_edges() != "":
		for part in str(header["music"]).split(";"):
			_add_sound(part, 0.0, true)

	var t := 0.0
	var scene_index := 0
	for scene in model.get("scenes", []):
		var scene_start := t
		_scene_set[scene_index] = _set_index
		var lines: Array = scene.get("lines", [])
		var has_shots := false
		for entry in lines:
			var line_text := str(entry["text"])
			var upper := line_text.to_upper()
			if upper.begins_with("SHOT") or upper.begins_with("CAMERA") or upper.begins_with("CUT TO"):
				has_shots = true
		for entry in lines:
			var result := _run_line(str(entry["text"]), t, scene_index, int(entry.get("line", 0)))
			if result.has("at"):
				t = float(result["at"])
			elif not bool(result.get("parallel", false)):
				t += float(result.get("dur", 0.0))
		t = maxf(t, _busy_end_after(scene_start))
		if not has_shots and _camera_mode == "auto":
			_auto_coverage(scene_index, scene_start, t)
		elif _camera_mode == "auto":
			_fill_long_shots(scene_index, scene_start, t)
		(_report["scenes"] as Array).append("%s (%.1f–%.1f s)" % [str(scene.get("name", "Scene")), scene_start, t])
		scene_index += 1

	_end = maxf(_end, t)
	for item in _titles:
		if not item.get("open", false):
			_end = maxf(_end, float(item["start"]) + float(item["length"]))
	var min_length := float(str(header.get("length", "0")).to_float())
	var length := clampf(maxf(_end + 1.5, min_length), 3.0, TimelineController.MAX_DURATION)
	if _story_style:
		_titles.push_front({"text": "", "start": 0.0, "length": length, "style": "Vignette", "strength": 0.5})
	for item in _titles:
		if item.get("open", false) and str(item.get("style", "")) == "Letterbox":
			item["length"] = maxf(length - float(item["start"]), 0.1)
	_finish(length)
	_report["length"] = length
	return _report


# --- Location -------------------------------------------------------------------

func _build_location(requested: String) -> void:
	var name := _best_key(requested, LOCATIONS.keys())
	if name.is_empty():
		name = "Blank World"
		_sub("Location \"%s\"" % requested, "Blank World (not one of the built-in locations)")
	elif _norm(name) != _norm(requested):
		_sub("Location \"%s\"" % requested, name)
	_location_name = name
	_location = LOCATIONS[name]
	builder.build(str(_location["template"]))
	# Keep the world, remove the template's own actors, cameras and timing.
	for root in [builder.placed_props_root, builder.director.cameras_root]:
		for child in (root as Node).get_children():
			if child is CharacterBase or child is CinematicCamera or str(child.name).to_lower().begins_with("dog"):
				(root as Node).remove_child(child)
				child.queue_free()
			elif bool(_location.get("flat", false)) and not str(child.get_meta(PropUtils.META_SCENE_PATH, "")).ends_with("floor_line.tscn"):
				# The Sketch Stage's example desk and lamp: a scripted film brings its own.
				(root as Node).remove_child(child)
				child.queue_free()
	builder.timeline.store.clear(false)
	builder.director.default_camera_uid = ""
	_apply_env_values(_location.get("env", {}))
	if builder.titles:
		builder.titles.clear()
	if builder.audio:
		builder.audio.clear()
	for child in builder.placed_props_root.get_children():
		if child is Room:
			(child as Room).front_wall = true  # cameras can look every way in a scripted film
	_info("Location: %s" % name)


func _use_set(index: int) -> void:
	_set_index = clampi(index, 0, maxi(_sets.size() - 1, 0))
	if _sets.is_empty():
		return
	var entry: Dictionary = _sets[_set_index]
	_location = entry["data"]
	_location_name = str(entry["name"])
	_offset = entry["offset"]
	_suffix = str(entry["suffix"])


## The location's establishing view, moved to where its set stands.
func _overview() -> Array:
	var o: Array = _location["overview"]
	return [float(o[0]) + _offset.x, o[1], float(o[2]) + _offset.z, float(o[3]) + _offset.x, o[4], float(o[5]) + _offset.z, o[6]]


## "LOCATION: Classroom" inside a scene: cut to another location.
func _switch_location(requested: String, t: float, scene: int) -> void:
	var name := _best_key(requested, LOCATIONS.keys())
	if name.is_empty():
		_warn("LOCATION \"%s\" isn't one of the locations; staying in %s." % [requested.strip_edges(), _location_name])
		return
	_awaiting_first_shot = true
	# Hold the light as it is up to the cut, so the scene before doesn't fade into the
	# next location's time of day and weather.
	_flush_env_later(t)
	_env_key(maxf(t - FRAME * 2.0, 0.0))
	for i in _sets.size():
		if str((_sets[i] as Dictionary)["name"]) == name:
			if i != _set_index:
				_use_set(i)
				_env_change(t, (_sets[i] as Dictionary)["env"], 0.0)
			_scene_set[scene] = _set_index
			return
	var data: Dictionary = LOCATIONS[name]
	var template := str(data["template"])
	if TemplateBuilder.TERRAIN_TEMPLATES.has(template) or template == TemplateBuilder.BLANK:
		_warn("Only one nature location fits in a film (it needs the whole terrain): \"%s\" was skipped, the scene stays in %s. Indoor sets, studios and streets can be combined freely." % [name, _location_name])
		return
	var offset := Vector3(450.0 + 300.0 * float(_sets.size() - 1), 0.0, 0.0)
	var built := builder.build_set(template, offset)
	for node in built["nodes"]:
		if node is Room:
			(node as Room).front_wall = true
	var env := {}
	var wanted: Dictionary = built["env"]
	for key in EnvironmentController.ANIMATED:
		if wanted.has(key):
			env[key] = wanted[key]
	_sets.append({"name": name, "data": data, "offset": offset, "suffix": " zzset%d" % _sets.size(), "env": env})
	_use_set(_sets.size() - 1)
	_register_location_marks(built["nodes"])
	_env_change(t, env, 0.0)
	_scene_set[scene] = _set_index
	_info("Location: %s (built on the backlot)" % name)


func _indoor() -> bool:
	return bool(_location.get("indoor", false))


func _ground(x: float, z: float) -> float:
	if _indoor():
		return 0.0
	return builder.terrain.height_at(x, z) if Terrain.contains(x, z) else 0.0


var _water_cache: Array = []


## Height of the water surface (river, lake, pond, sea) at (x, z), or NAN if there's none.
func _water_y(x: float, z: float) -> float:
	var best := NAN
	# Every water surface in the world (each location keeps its own props root).
	var stale := _water_cache.is_empty()
	for cached in _water_cache:
		if not is_instance_valid(cached):
			stale = true
	if stale:
		_water_cache.clear()
		for any in PropUtils.descendants(builder.get_tree().root):
			if any is WaterFeature:
				_water_cache.append(any)
	for child in _water_cache:
		if child is WaterFeature and (child as Node3D).is_visible_in_tree():
			var feature := child as WaterFeature
			var local := feature.to_local(Vector3(x, feature.global_position.y, z))
			if feature.edge_at_local(Vector2(local.x, local.z)) > 0.0:
				var y := feature.global_position.y + 0.02 + feature.wave_height * 0.75
				if is_nan(best) or y > best:
					best = y
	return best


func _on_ground(p: Vector3) -> Vector3:
	return p if _indoor() else Vector3(p.x, _ground(p.x, p.z), p.z)


func _register_location_marks(nodes: Array = []) -> void:
	var marks: Dictionary = _location.get("marks", {})
	for key in marks:
		var v: Array = marks[key]
		_add_thing(str(key) + _suffix, {"kind": "mark", "pos": _on_ground(Vector3(v[0], v[1], v[2]) + _offset), "yaw": float(v[3]), "radius": 0.0, "display": str(key)})
	# Every object in the location is a mark too: "campfire", "chair 3"…
	var counts := {}
	var children: Array = nodes if not nodes.is_empty() else builder.placed_props_root.get_children()
	for child in children:
		if not child is Node3D or child is CharacterBase:
			continue
		var base := _norm(str(child.name).to_snake_case().replace("_", " ")).rstrip("0123456789 ")
		if base.is_empty() or base == "ground mist":
			continue
		counts[base] = int(counts.get(base, 0)) + 1
		var label := base if int(counts[base]) == 1 else "%s %d" % [base, counts[base]]
		var thing := _prop_thing(child as Node3D, base)
		thing["display"] = label
		_add_thing(label + _suffix, thing)
		if int(counts[base]) == 1:
			_alias("%s 1" % base + _suffix, thing)


func _prop_thing(node: Node3D, kind_name: String) -> Dictionary:
	var box := PropUtils.world_aabb(node)
	var seat := -1.0
	for word in SEATS:
		if kind_name.contains(str(word)):
			seat = float(SEATS[word])
	return {"kind": "prop", "node": node, "pos": node.global_position, "yaw": node.rotation_degrees.y, "kind_name": kind_name,
		"radius": clampf(maxf(box.size.x, box.size.z) * 0.5, 0.2, 6.0), "height": box.size.y, "seat": seat,
		"depth": clampf(minf(box.size.x, box.size.z) * 0.5, 0.1, 6.0),
		"track": [], "faces": [], "sits": [], "hidden": false, "placed": true, "keys": false, "busy": 0.0,
		"afloat": node.has_meta(&"afloat")}


# --- Header: light, weather, music ----------------------------------------------------

func _apply_header_environment(header: Dictionary) -> void:
	var env := builder.environment
	if header.has("time"):
		var parts := str(header["time"]).replace("→", "->").split("->")
		_apply_env_values(_time_values(parts[0]))
		if parts.size() > 1:
			_env_later.append(_time_values(parts[1]))
	if header.has("weather"):
		var parts := str(header["weather"]).replace("→", "->").split("->")
		_apply_env_values(_weather_values(parts[0]))
		if parts.size() > 1:
			_env_later.append(_weather_values(parts[1]))
	for key in ["sky", "light"]:
		if header.has(key):
			_apply_env_values(_pairs(str(header[key])))
	if not _env_later.is_empty():
		_env_key(0.0)
	env.set("render_quality", env.get("render_quality"))


func _apply_env_values(values: Dictionary) -> void:
	for key in values:
		builder.environment.set(key, values[key])


func _time_values(text: String) -> Dictionary:
	var clean := text.strip_edges()
	var preset := _best_key(clean, EnvironmentController.PRESETS.keys())
	if not preset.is_empty() and not clean.is_valid_float() and not clean.contains(":"):
		return (EnvironmentController.PRESETS[preset] as Dictionary).duplicate()
	if clean.contains(":"):
		var hm := clean.split(":")
		return {"time_of_day": clampf(hm[0].to_float() + hm[1].to_float() / 60.0, 0.0, 24.0)}
	if clean.is_valid_float():
		return {"time_of_day": clampf(clean.to_float(), 0.0, 24.0)}
	_warn("TIME \"%s\": use an hour like 18.5 or 18:30, or Morning, Noon, Sunset, Night, Overcast." % clean)
	return {}


func _weather_values(text: String) -> Dictionary:
	var clean := text.strip_edges()
	var preset := _best_key(clean, EnvironmentController.WEATHER_PRESETS.keys())
	if not preset.is_empty() and not clean.contains(" 0") and not clean.contains(" 1"):
		return (EnvironmentController.WEATHER_PRESETS[preset] as Dictionary).duplicate()
	return _pairs(clean)


## "mist 0.4, wind 0.2, ground sand" -> { "mist": 0.4, "wind": 0.2, "ground_style": "Sand" }
func _pairs(text: String) -> Dictionary:
	var out := {}
	for part in text.replace("=", " ").split(","):
		var words := part.strip_edges().split(" ", false)
		if words.size() < 2:
			continue
		var key := str(words[0]).to_lower()
		key = str(ENV_WORDS.get(key, key))
		var value := " ".join(words.slice(1))
		if key in ["paper", "background", "backdrop", "page", "wall"] and _norm(value) in ["none", "off", "outdoor", "outdoors", "sky", "clear"]:
			out["flat_background"] = Color(0, 0, 0, 0)
		elif key == "sky":
			var skc := _color(value)
			if _norm(value) in ["day", "none", "default", "blue"]:
				out["flat_sky"] = Color(0, 0, 0, 0)
			elif skc.r >= 0.0:
				out["flat_sky"] = Color(skc.r, skc.g, skc.b, 1.0)
		elif key in ["paper", "background", "backdrop", "page", "wall"]:
			var c := _color(value)
			if c.r >= 0.0:
				out["flat_background"] = Color(c.r, c.g, c.b, 1.0)
			else:
				_warn("\"%s\" isn't a colour (try paper #e9dcc3)." % value)
		elif key in ["photo", "photo_sky", "hdri"]:
			# 1.28: "LIGHT: photo sky kloppenheim_06" - a real photo sky: a file in
			# the package (hdris/), or a Poly Haven HDRI downloaded on this computer.
			var id := value.trim_prefix("sky ").strip_edges().trim_prefix("\"").trim_suffix("\"")
			if _norm(id) in ["off", "none", "no"]:
				out["sky_mode"] = EnvironmentController.SkyMode.AUTOMATIC
				continue
			var file := ""
			for candidate in [id, "hdris/" + id, "hdris/" + id + ".hdr", "hdris/" + id + ".exr", id + ".hdr", id + ".exr"]:
				file = _package_file(candidate)
				if not file.is_empty():
					break
			var hdri_key := id.get_file().get_basename()
			for size in ["_1k", "_2k", "_4k"]:
				hdri_key = hdri_key.trim_suffix(size)
			if file.is_empty():
				file = OnlineLibrary.downloaded_path("polyhaven", hdri_key, "hdri")
			if file.is_empty():
				_missing("photo sky \"%s\" (download it in Library → Online, or put it in the package's hdris/ folder)" % id)
				continue
			out["hdri_path"] = file
			out["hdri_id"] = hdri_key
			out["sky_mode"] = EnvironmentController.SkyMode.PHOTO
		elif key in ["ground_photo", "ground_texture"]:
			# 1.28: "LIGHT: ground_photo aerial_grass_rock" - a Poly Haven ground texture
			# downloaded on this computer, or a .glb/.gltf in the package's textures/.
			var tex := value.strip_edges().trim_prefix("\"").trim_suffix("\"")
			var tex_key := tex.get_file().get_basename()
			for size in ["_1k", "_2k", "_4k"]:
				tex_key = tex_key.trim_suffix(size)
			var tex_file := ""
			for candidate in [tex, "textures/" + tex, "textures/" + tex + ".glb", "textures/" + tex + ".gltf"]:
				tex_file = _package_file(candidate)
				if not tex_file.is_empty():
					break
			if tex_file.is_empty():
				tex_file = OnlineLibrary.downloaded_path("polyhaven", tex_key, "texture")
			if tex_file.is_empty():
				_missing("ground texture \"%s\" (download it in Scene → Ground, or put it in the package's textures/ folder)" % tex)
				continue
			out["ground_texture"] = tex_file
			out["ground_texture_id"] = tex_key
			out["ground_style"] = "Photo texture"
		elif key == "ground_style":
			var style := _best_key(value, Array(EnvironmentController.GROUND_STYLES))
			if not style.is_empty():
				out[key] = style
		elif EnvironmentController.DEFAULTS.has(key) and value.is_valid_float():
			out[key] = value.to_float()
		else:
			_warn("Unknown light/weather setting \"%s\"." % part.strip_edges())
	return out


## A header "A -> B" change runs until the first scene-level light change (or the end).
func _flush_env_later(t: float) -> void:
	if _env_later.is_empty():
		return
	for values in _env_later:
		_apply_env_values(values)
	_env_later.clear()
	_env_key(t)


func _env_key(t: float) -> void:
	var timeline := builder.timeline
	timeline.store.set_key(timeline.uid_for(builder.environment), TimelineController.CH_LIGHTING,
		_snap(maxf(t, 0.0)), builder.environment.capture(), false)


func _env_change(t: float, values: Dictionary, over: float) -> void:
	if values.is_empty():
		return
	_flush_env_later(t)
	_env_key(t if over > 0.0 else maxf(t - FRAME, 0.0))
	_apply_env_values(values)
	var end := t + maxf(over, 0.0)
	_env_key(end)
	# Keys after this one were made by earlier lines ("TIME: 19 over 60s"): from here on
	# the settings this line changed keep their new values there too.
	var timeline := builder.timeline
	var now := builder.environment.capture()
	var id := KeyframeStore.channel_id(timeline.uid_for(builder.environment), TimelineController.CH_LIGHTING)
	for key in timeline.store.channels.get(id, []):
		if float(key["t"]) > end + 0.001:
			for property in values:
				if now.has(property):
					(key["v"] as Dictionary)[property] = now[property]
	_end = maxf(_end, t + over)


# --- Set dressing and cast -----------------------------------------------------------------

## "bench1 = bench near the campfire, facing the lake"  or  "a bench near the campfire"
func _add_set_piece(text: String) -> void:
	var id := ""
	var rest := text
	var eq := text.find("=")
	if eq < 0 and text.find(":") > 0:
		eq = text.find(":")
	if eq > 0:
		id = text.substr(0, eq).strip_edges()
		rest = text.substr(eq + 1).strip_edges()
	var facing := ""
	var lower := _mask_quotes(rest.to_lower())
	var f := lower.find(", facing ")
	if f < 0:
		f = lower.find(" facing ")
	if f >= 0:
		facing = rest.substr(f).strip_edges().trim_prefix(",").strip_edges().substr(7).strip_edges()
		rest = rest.substr(0, f)
		lower = _mask_quotes(rest.to_lower())
	# ", afloat": rides on the water (a paper boat, a duck, a raft) and rocks gently when it moves.
	var afloat := false
	var afloat_match := RegEx.create_from_string("(?i),?\\s+(afloat|floating|on the water)\\b").search(rest)
	if afloat_match:
		afloat = true
		rest = (rest.substr(0, afloat_match.get_start()) + rest.substr(afloat_match.get_end())).strip_edges()
		lower = _mask_quotes(rest.to_lower())
	# ", up 12": hangs in the air that many metres up (planes, birds, a globe in space).
	var lift := 0.0
	var up_match := RegEx.create_from_string("(?i),?\\s+up\\s+(-?[\\d.]+)\\s*m?\\b").search(rest)
	if up_match:
		lift = up_match.get_string(1).to_float()
		rest = (rest.substr(0, up_match.get_start()) + rest.substr(up_match.get_end())).strip_edges()
		lower = _mask_quotes(rest.to_lower())
	var place := ""
	for joiner in [" at ", " near ", " next to ", " beside ", " in front of ", " behind ", " left of ", " right of ", " on ", " between "]:
		var cut := lower.find(joiner)
		if cut > 0:
			place = rest.substr(cut).strip_edges()
			rest = rest.substr(0, cut)
			break
	var model := rest.strip_edges()
	var scale := 1.0
	var scale_at := _mask_quotes(model.to_lower()).find(" scale ")
	if scale_at > 0:
		scale = clampf(model.substr(scale_at + 7).to_float(), 0.05, 50.0)
		model = model.substr(0, scale_at).strip_edges()
	var kind_name := _norm(model)
	if not _my_item_name(model).is_empty():
		kind_name = _norm(_my_item_name(model))
	if id.is_empty():
		id = kind_name
	var path := _resolve_model(model, false)
	if path.is_empty():
		return
	var node := PropUtils.create_prop(path)
	if node == null:
		_missing("model \"%s\" (could not be loaded)" % model)
		return
	node.name = id.validate_node_name()
	builder.placed_props_root.add_child(node, true)
	node.scale = Vector3.ONE * scale
	var spot := _place_of(place if not place.is_empty() else "center", {})
	var pos: Vector3 = spot["pos"]
	node.global_position = pos
	if not place.to_lower().begins_with("on ") and lift == 0.0:
		pos = _onto_furniture(node, pos)
		node.global_position = pos
	if lift != 0.0:
		pos.y += lift
		node.global_position = pos
	if afloat:
		node.set_meta(&"afloat", true)
		var water := _water_y(pos.x, pos.z)
		if not is_nan(water):
			pos.y = water
			node.global_position = pos
	if not facing.is_empty():
		var target := _place_of(facing, {})
		node.rotation_degrees.y = _yaw_towards(pos, target["pos"])
	elif not is_nan(float(spot.get("yaw", NAN))):
		node.rotation_degrees.y = float(spot["yaw"])
	var thing := _prop_thing(node, kind_name)
	_add_thing(id, thing)
	_report_count("props")


## A small object (a mug, a lamp, a laptop) placed "at" a spot over a desk or table
## goes on top of it instead of on the floor underneath.
func _onto_furniture(node: Node3D, pos: Vector3) -> Vector3:
	var box := PropUtils.world_aabb(node)
	if box.size.y > 0.75 or maxf(box.size.x, box.size.z) > 0.9:
		return pos
	var best := pos
	for key in _things:
		var other: Dictionary = _things[key]
		if other.get("kind") != "prop" or not (other.get("node") is Node3D) or is_same(other["node"], node):
			continue
		var b := PropUtils.world_aabb(other["node"] as Node3D)
		# Tables and desks: knee to chest high, with a top big enough to hold things.
		if b.size.y < 0.4 or b.size.y > 1.25 or b.size.x * b.size.z < 0.3:
			continue
		if pos.x >= b.position.x + 0.03 and pos.x <= b.end.x - 0.03 and pos.z >= b.position.z - 0.05 and pos.z <= b.end.z + 0.05:
			best = Vector3(pos.x, maxf(best.y, b.end.y), pos.z)
	return best


func _add_cast(name: String, spec: String) -> void:
	var parts := spec.split(",")
	var model := str(parts[0]).strip_edges()
	var path := _resolve_model(model, true)
	if path.is_empty():
		path = "res://assets/props/characters/man.tscn"
		_sub("%s (\"%s\")" % [name, model], "Man (placeholder)")
	var sketch_height := 0.0
	if _flat and path.begins_with("res://assets/props/characters/") and not path.contains("sketch") and not path.contains("story") and not path.contains("dog"):
		sketch_height = {"child.tscn": 1.15, "elder.tscn": 1.48, "woman.tscn": 1.5, "woman_casual.tscn": 1.5}.get(path.get_file(), 1.56)
		path = "res://assets/props/characters/sketch_person.tscn"
	SketchCharacter.lit = builder.environment.look == "Realistic"
	var node := PropUtils.create_prop(path)
	if node is SketchCharacter and sketch_height > 0.0:
		(node as SketchCharacter).height = sketch_height
	# In the Cartoon look every drawn person is a cartoon character.
	if node is SketchCharacter and (node as SketchCharacter).figure == "Person" and (builder.environment.look in [SketchLook.CARTOON, SketchLook.SKETCHBOOK] or _norm(model).contains("cartoon") or _norm(model).contains("toon")):
		(node as SketchCharacter).figure = "Cartoon"
	if node == null:
		_missing("character \"%s\" for %s" % [model, name])
		return
	node.name = name.validate_node_name()
	builder.placed_props_root.add_child(node, true)
	var index := 0
	for key in _things:
		if str((_things[key] as Dictionary).get("kind")) == "character":
			index += 1
	var centre := _place_of("center", {})
	var start := _on_ground((centre["pos"] as Vector3) + Vector3(1.4 * float(index) - 1.4, 0, 2.0))
	node.global_position = start
	node.rotation_degrees.y = 0.0
	var voice_setting := ""
	for i in range(1, parts.size()):
		var part := str(parts[i]).strip_edges()
		if part.to_lower().begins_with("voice"):
			voice_setting = part.substr(5).strip_edges()
			continue
		_apply_look(node, name, part)
	if node is SketchCharacter and (node as SketchCharacter).figure != "Shadow" and builder.environment.look == SketchLook.SKETCHBOOK:
		# Sketchbook: skin, hair and clothes are soft watercolour washes.
		var sketch := node as SketchCharacter
		for key in ["body_color", "shirt_color", "pants_color", "hair_color", "shoe_color", "cap_color"]:
			var c: Color = sketch.get(key)
			sketch.set(key, SketchLook.wash(c))
	var body := str(node.get("body_type")) if node is HumanCharacter else ""
	if body.is_empty() and voice_setting.is_empty() and index % 2 == 1:
		voice_setting = "female"
	var height := 1.75
	if node is CharacterBase:
		height = 1.75 * (node as CharacterBase).size_factor()
		if node is ImportedCharacter:
			height = maxf(PropUtils.world_aabb(node).size.y, 0.5)
	else:
		height = maxf(PropUtils.world_aabb(node).size.y, 0.3)
	_add_thing(name, {"kind": "character" if node is CharacterBase else "actor", "node": node, "pos": start, "yaw": 0.0,
		"radius": 0.35, "height": height, "seat": -1.0, "track": [], "faces": [], "sits": [], "sitting": false,
		"busy": 0.0, "pose": {}, "lips": [], "placed": false, "hidden": false, "display": name, "keys": false,
		"voice": SpeechMaker.voice_for(voice_setting, body)})
	_report_count("characters")


## Realistic people (and other imported characters): "shirt red", "trousers #333",
## "shoes white", "hair brown", "height 1.2" (a scale; or metres when above 1.5).
func _apply_imported_look(node: ImportedCharacter, who: String, setting: String) -> void:
	var words := setting.strip_edges().split(" ", false)
	if words.size() < 2:
		_warn("%s: \"%s\" - realistic people take: shirt <colour>, trousers <colour>, shoes <colour>, hair <colour>, height <n>." % [who, setting])
		return
	var key := str(words[0]).to_lower()
	var value := " ".join(words.slice(1))
	if key in ["height", "size", "scale"]:
		var h := value.to_float()
		if h > 0.0:
			var current := maxf(PropUtils.world_aabb(node).size.y, 0.3)
			var factor := h / current if h > 1.5 or h > current * 1.4 else h
			var look := node.current_look()
			look["height"] = clampf(factor, 0.5, 1.5)
			if not look.has("clothes_fit"):
				look["clothes_fit"] = 0.0
			node.apply_look(look)
		return
	var c := _color(value)
	if c.r < 0.0:
		_warn("%s: \"%s\" isn't a colour name (try red, navy, #8b4513)." % [who, value])
		return
	if node.tint_parts(key, c) == 0:
		_warn("%s: no \"%s\" to colour (realistic people have shirt, trousers, shoes and hair)." % [who, key])


## "top red", "hair long", "height 1.6", "skin #c68e64"
func _apply_look(node: Node3D, who: String, setting: String) -> void:
	if node is SketchCharacter:
		_apply_sketch_look(node as SketchCharacter, who, setting)
		return
	if node is ImportedCharacter:
		_apply_imported_look(node as ImportedCharacter, who, setting)
		return
	if not node is HumanCharacter:
		return
	# Clothes and accessories (Scene Builder 1.11): coat [colour], sweater [colour],
	# scarf <colour>, beanie (knitted in the scarf colour, or a darker top colour), glasses.
	var single := setting.strip_edges().to_lower()
	match single:
		"glasses":
			node.set("glasses", true)
			return
		"sweater", "jumper":
			node.set("outfit", "Sweater")
			return
		"beanie", "hat", "woolly hat":
			node.set("hat", "Beanie")
			return
		"coat":
			node.set("outfit", "Coat")
			return
	var words := setting.split(" ", false)
	if words.size() < 2:
		return
	var key := str(words[0]).to_lower()
	var value := " ".join(words.slice(1))
	if key in ["beanie", "hat"]:
		node.set("hat", "Beanie")
		return
	if key in ["coat", "scarf", "sweater", "jumper"]:
		var c := _color(value)
		if c.r < 0.0:
			_warn("%s: \"%s\" isn't a colour name (try red, navy, #8b4513)." % [who, value])
			return
		match key:
			"coat":
				node.set("outfit", "Coat")
				node.set("coat_color", c)
			"scarf":
				node.set("scarf_color", Color(c.r, c.g, c.b, 1.0))
			_:
				node.set("outfit", "Sweater")
				node.set("top_color", c)
		return
	var names := {"top": "top_color", "shirt": "top_color", "jacket": "top_color", "bottom": "bottom_color", "trousers": "bottom_color",
		"pants": "bottom_color", "skirt": "bottom_color", "shoes": "shoe_color", "skin": "skin_color", "hair": "hair_color",
		"height": "height", "build": "build", "body": "body_type", "hairstyle": "hair_style", "clothes": "bottom_style"}
	var property := str(names.get(key, ""))
	if property.is_empty():
		_warn("%s: unknown look setting \"%s\"." % [who, setting])
		return
	if key == "hair" and HumanCharacter.HAIR_STYLES.has(value.capitalize()):
		property = "hair_style"
	if key == "clothes" or ((key == "skirt" or key == "trousers" or key == "pants") and _color(value).r < 0.0):
		property = "bottom_style"
		if key != "clothes":
			value = key
	if property.ends_with("_color"):
		var color := _color(value)
		if color.r < 0.0:
			_warn("%s: \"%s\" isn't a colour name (try red, navy, #8b4513)." % [who, value])
			return
		node.set(property, color)
	elif property == "height" or property == "build":
		node.set(property, value.to_float())
	else:
		node.set(property, value.capitalize())


## "color pale yellow", "glow red", "lines #333", "face tired", "height 1.4", "build 1.2"
func _apply_sketch_look(node: SketchCharacter, who: String, setting: String) -> void:
	if node.figure == "Story" and _apply_story_look(node, setting):
		return
	var words := setting.split(" ", false)
	if words.size() < 2:
		if setting.strip_edges().to_lower() in ["fuzzy", "scribble", "scribbled", "furry"]:
			node.fuzzy = true
		return
	var key := str(words[0]).to_lower()
	var value := " ".join(words.slice(1))
	match key:
		"color", "colour", "body", "skin":
			var c := _color(value)
			if c.r >= 0.0:
				node.body_color = c
				return
		"glow", "aura":
			var c := _color(value)
			if c.r >= 0.0:
				node.glow_color = c
				node.line_color = c
				return
		"lines", "line", "eyes", "face color", "outline":
			var c := _color(value)
			if c.r >= 0.0:
				node.line_color = c
				return
		"face", "expression", "mood":
			var e := _best_key(value, Array(SketchCharacter.EXPRESSIONS))
			if not e.is_empty():
				node.expression = e
				return
		"height":
			node.height = clampf(value.to_float(), 0.8, 2.2)
			return
		"build":
			node.build = clampf(value.to_float(), 0.7, 1.3)
			return
		"hair":
			var style := _best_key(value, Array(SketchCharacter.HAIRS))
			if not style.is_empty() and _norm(value) == _norm(style):
				node.hair = style
				return
			var hc := _color(value)
			if hc.r >= 0.0:
				node.hair_color = hc
				if node.hair == "Curl":
					node.hair = "Short"
				return
		"shirt", "hoodie", "jumper", "sweater", "clothes", "tshirt", "t-shirt", "top":
			var sc := _color(value)
			if sc.r >= 0.0:
				node.shirt_color = Color(sc.r, sc.g, sc.b, 1.0)
				node.long_sleeves = key in ["hoodie", "jumper", "sweater"]
				return
		"cap", "hat":
			var cc := _color(value)
			if cc.r >= 0.0:
				node.cap_color = Color(cc.r, cc.g, cc.b, 1.0)
				return
		"shoes", "trainers", "sneakers":
			var shc := _color(value)
			if shc.r >= 0.0:
				node.shoe_color = shc
				return
		"pants", "trousers", "jeans", "skirt", "shorts":
			var pc := _color(value)
			if pc.r >= 0.0:
				node.pants_color = Color(pc.r, pc.g, pc.b, 1.0)
				return
	if setting.strip_edges().to_lower() in ["fuzzy", "scribble", "scribbled", "furry"]:
		node.fuzzy = true
		return
	_warn("%s: unknown look setting \"%s\" (sketch characters: color, glow, lines, face, hair, hoodie, fuzzy, height, build)." % [who, setting])


## Story people (1.27): "top teal", "long sleeves", "apron red", "bandana red", "cap orange",
## "sun hat cream", "beanie grey", "hard hat yellow", "chef hat", "glasses", "lanyard",
## "headphones", "skirt pink", "bun peach" (the hair tie), "outline none", "glow red".
func _apply_story_look(node: SketchCharacter, setting: String) -> bool:
	var clean := _norm(setting)
	match clean:
		"glasses", "spectacles":
			node.glasses = true
			return true
		"lanyard", "id card", "badge":
			node.lanyard = true
			return true
		"headphones":
			node.headphones = true
			return true
		"long sleeves":
			node.long_sleeves = true
			return true
		"chef hat":
			node.story_hat = "Chef hat"
			return true
		"no outline", "outline none":
			node.outline_color = Color(0, 0, 0, 0)
			return true
		"skirt":
			node.skirt = true
			return true
	for hat_word in [["sun hat", "Sun hat"], ["straw hat", "Sun hat"], ["hard hat", "Hard hat"], ["helmet", "Hard hat"], ["bandana", "Bandana"],
			["head scarf", "Bandana"], ["headscarf", "Bandana"], ["cap", "Cap"], ["beanie", "Beanie"], ["woolly hat", "Beanie"], ["hat", "Sun hat"]]:
		var word := str(hat_word[0])
		if clean == word or clean.begins_with(word + " "):
			node.story_hat = str(hat_word[1])
			var rest := clean.substr(word.length()).strip_edges()
			if not rest.is_empty():
				var c := _color(rest)
				if c.r >= 0.0:
					node.hat_color = c
			elif hat_word[1] == "Hard hat":
				node.hat_color = Color(0.98, 0.8, 0.15)
			elif hat_word[1] == "Sun hat":
				node.hat_color = Color(0.93, 0.88, 0.74)
			return true
	var words := clean.split(" ", false)
	if words.size() < 2:
		return false
	var key := str(words[0])
	var value := " ".join(words.slice(1))
	var c2 := _color(value)
	match key:
		"apron":
			if c2.r >= 0.0:
				node.apron_color = Color(c2.r, c2.g, c2.b, 1.0)
				return true
		"skirt", "dress":
			if c2.r >= 0.0:
				node.skirt = true
				node.pants_color = Color(c2.r, c2.g, c2.b, 1.0)
				return true
		"bun", "tie", "scrunchie", "band", "accent", "strap", "beads":
			if c2.r >= 0.0:
				node.accent_color = Color(c2.r, c2.g, c2.b, 1.0)
				if key == "bun":
					node.hair = "Bun"
				return true
		"outline", "rim":
			if c2.r >= 0.0:
				node.outline_color = Color(c2.r, c2.g, c2.b, 1.0)
				return true
		"glow", "aura", "emotion":
			if c2.r >= 0.0:
				node.glow_color = c2   # the colour of "Mira glows" (the eyes stay white)
				return true
		"lines", "eyes":
			if c2.r >= 0.0:
				node.line_color = c2
				return true
		"words", "speech", "text", "dialogue":
			if c2.r >= 0.0:
				node.set_meta(&"speech_color", c2)
				return true
		"sleeves":
			node.long_sleeves = value.begins_with("long")
			return true
		"long":
			if value.begins_with("sleeve"):
				node.long_sleeves = true
				return true
	return false


static func _color(text: String) -> Color:
	var clean := text.strip_edges().to_lower().replace("grey", "gray")
	var aliases := {"brown": "#6b4423", "dark brown": "#3d2817", "light brown": "#a67b5b", "navy": "navy blue", "dark blue": "dark blue", "sky": "sky blue", "cream": "#f3e5c0", "mustard": "#d8a31a",
		"rust": "#b7410e", "burgundy": "#800020", "denim": "#3b5b92", "charcoal": "#36454f", "khaki": "khaki", "olive": "olive",
		"sage": "#9caf88", "peach": "#f6b89a", "mint": "#a8d8b9", "terracotta": "#c76b4a", "dusty blue": "#7a96b5", "dusty pink": "#d8a0a8",
		"blush": "#f0b7b0", "mauve": "#b38fa8", "ochre": "#cc8e2f", "forest": "#3c5a3a", "sand": "#d8c49a", "slate": "#5c6b7a", "wine": "#6e2232",
		"butter": "#f2dd8c", "mustard yellow": "#d8a31a", "rose": "#e07a8a", "bottle green": "#1f5a3a", "brick": "#a4483a", "denim blue": "#3b5b92",
		"off white": "#efece4", "warm grey": "#8a837a", "warm gray": "#8a837a", "light grey": "#c8c8c8", "light gray": "#c8c8c8", "dark grey": "#3a3a3e", "dark gray": "#3a3a3e",
		"skin": "#e0ac8a", "fair": "#f1c8a8", "tan": "#c68e64", "brown skin": "#8d5a3b", "dark skin": "#5a3825", "blonde": "#d9b26b", "ginger": "#b5562a"}
	clean = str(aliases.get(clean, clean))
	return Color.from_string(clean.replace(" ", ""), Color(-1, 0, 0))


## A model for [param spec]: a package file (.glb/.fbx), the user's own item
## (my character "Name" / my prop "Name"), a library model, or a close match
## (reported). Returns "" if nothing fits.
func _resolve_model(spec: String, character: bool) -> String:
	var mine := _my_item_name(spec)
	if not mine.is_empty():
		return _resolve_mine(mine, character)
	var clean := spec.strip_edges().trim_prefix("\"").trim_suffix("\"")
	var extension := clean.get_extension().to_lower()
	if RuntimeModelLoader.EXTENSIONS.has(extension):
		var source := _package_file(clean)
		if source.is_empty():
			_missing("file \"%s\" (not in the package)" % clean)
			return ""
		return _import_file(source, character)
	if _catalog.is_empty():
		_catalog = PropCatalog.scan()
	var wanted := _norm(clean)
	if _flat and not character:
		# In the Flat sketch look, "desk" means the drawn desk.
		var best_sketch := ""
		var best_score := 0.0
		for prop in _catalog:
			if str(prop["category"]) != "Sketch":
				continue
			var plain := _norm(str(prop["display_name"])).trim_prefix("sketch ").strip_edges()
			var score := 1.0 if plain == wanted.trim_prefix("sketch ").strip_edges() else _similarity(wanted.trim_prefix("sketch ").strip_edges(), plain)
			if score > best_score:
				best_score = score
				best_sketch = str(prop["scene_path"])
		if best_score >= 0.6:
			return best_sketch
	var words: Dictionary = CHARACTER_WORDS if character else PROP_WORDS
	var candidates: Array = []
	for prop in _catalog:
		var category := str(prop["category"])
		var is_char := category == "Characters" or category == "Animals" or category == PropCatalog.MY_CHARACTERS_CATEGORY
		if is_char != character:
			continue
		candidates.append(prop)
	for prop in candidates:
		if _norm(str(prop["display_name"])) == wanted or _norm(str(prop["prop_id"]).replace("_", " ")) == wanted:
			return str(prop["scene_path"])
	if words.has(wanted):
		var alias := str(words[wanted])
		for prop in candidates:
			if _norm(str(prop["display_name"])) == alias:
				return str(prop["scene_path"])
	var best_score := 0.0
	var best: Dictionary = {}
	for prop in candidates:
		var score := _similarity(wanted, _norm(str(prop["display_name"])))
		if score > best_score:
			best_score = score
			best = prop
	for word in words:
		if wanted.contains(str(word)) and _similarity(str(word), wanted) > best_score:
			for prop in candidates:
				if _norm(str(prop["display_name"])) == str(words[word]):
					best_score = _similarity(str(word), wanted)
					best = prop
	if best_score >= 0.5 and not best.is_empty():
		_sub("\"%s\"" % clean, str(best["display_name"]))
		return str(best["scene_path"])
	_missing("%s \"%s\"" % ["character" if character else "model", clean])
	return ""


## The name in 'my character "Name"', 'my prop "Name"' or 'my "Name"', else "".
static func _my_item_name(spec: String) -> String:
	var text := spec.strip_edges()
	var lower := text.to_lower()
	if not lower.begins_with("my "):
		return ""
	for prefix in ["my character", "my avatar", "my prop", "my object", "my model", "my"]:
		if lower.begins_with(prefix + " ") or lower.begins_with(prefix + "\""):
			var name := text.substr(prefix.length()).strip_edges()
			if name.begins_with("\"") or name.begins_with("“"):
				name = name.substr(1)
				var close := name.find("\"")
				if close < 0:
					close = name.find("”")
				if close >= 0:
					name = name.substr(0, close)
			return name.strip_edges()
	return ""


## Hides quoted text ("Lamp on Stand") from keyword searches, keeping positions.
static func _mask_quotes(text: String) -> String:
	var out := ""
	var inside := false
	for i in text.length():
		var c := text[i]
		if c == "\"" or c == "“" or c == "”":
			inside = not inside if c == "\"" else c == "“"
			out += c
		else:
			out += "_" if inside and c == " " else c
	return out


## The user's own character or prop by name: from this computer's library first,
## otherwise a file of that name in the package (characters/, models/).
func _resolve_mine(name: String, character: bool) -> String:
	var wanted := _norm(name)
	if _catalog.is_empty():
		_catalog = PropCatalog.scan()
	var mine: Array = []
	for prop in _catalog:
		var category := str(prop["category"])
		var ok := category == PropCatalog.MY_CHARACTERS_CATEGORY if character else \
			(category == PropCatalog.IMPORTED_CATEGORY or category == PropCatalog.DOWNLOADED_CATEGORY)
		if ok:
			mine.append(prop)
	for prop in mine:
		var path := str(prop["scene_path"])
		if _norm(str(prop["display_name"])) == wanted or _norm(path.get_file().get_basename()) == wanted:
			return path
	# The package may carry the file (made for another computer).
	if not _package_dir.is_empty():
		for sub in (["characters", "models"] if character else ["models", "characters"]):
			var dir := DirAccess.open(_package_dir.path_join(sub))
			if dir == null:
				continue
			for file_name in dir.get_files():
				if RuntimeModelLoader.EXTENSIONS.has(file_name.get_extension().to_lower()) and _norm(file_name.get_basename()) == wanted:
					return _import_file(_package_dir.path_join(sub).path_join(file_name), character)
	var best_score := 0.0
	var best: Dictionary = {}
	for prop in mine:
		var score := maxf(_similarity(wanted, _norm(str(prop["display_name"]))), _similarity(wanted, _norm(str(prop["scene_path"]).get_file().get_basename())))
		if score > best_score:
			best_score = score
			best = prop
	if best_score >= 0.6 and not best.is_empty():
		_sub("your %s \"%s\"" % ["character" if character else "prop", name], str(best["display_name"]))
		return str(best["scene_path"])
	_missing("your %s \"%s\" (not in %s on this computer, and not in the package)" % [
		"character" if character else "prop", name, "My Characters" if character else "your imported or downloaded models"])
	return ""


## Copies the package's animations/*.glb|fbx into the animation library.
func _import_animation_packs() -> void:
	if _package_dir.is_empty():
		return
	var folder := _package_dir.path_join("animations")
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	var added := 0
	DirAccess.make_dir_recursive_absolute(ImportedCharacter.ANIMATIONS_DIR)
	for file_name in dir.get_files():
		if not ["glb", "fbx"].has(file_name.get_extension().to_lower()):
			continue
		var dest := ImportedCharacter.ANIMATIONS_DIR + file_name.validate_filename()
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(folder.path_join(file_name)), ProjectSettings.globalize_path(dest)) == OK:
			added += 1
			(_report["imported"] as Array).append(file_name)
	if added > 0:
		ImportedCharacter.forget_packs()
		_info("Added %d animation pack%s from the package." % [added, "" if added == 1 else "s"])


func _package_file(relative: String) -> String:
	var options: Array = []
	if not _package_dir.is_empty():
		options.append(_package_dir.path_join(relative))
		for sub in ["models", "characters", "animations", "audio", "music", "voices", "sounds"]:
			options.append(_package_dir.path_join(sub).path_join(relative.get_file()))
	options.append(relative)
	for path in options:
		if FileAccess.file_exists(str(path)):
			return str(path)
	return ""


func _import_file(source: String, character: bool) -> String:
	var folder := RuntimeModelLoader.CHARACTERS_DIR if character else RuntimeModelLoader.IMPORTED_DIR
	DirAccess.make_dir_recursive_absolute(folder)
	var dest := folder + source.get_file().validate_filename()
	if ProjectSettings.globalize_path(dest) != ProjectSettings.globalize_path(source):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(dest)) != OK:
			_missing("file \"%s\" (couldn't copy it)" % source.get_file())
			return ""
		var look_source := ImportedCharacter.look_path(source)
		if FileAccess.file_exists(look_source):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(look_source), ProjectSettings.globalize_path(ImportedCharacter.look_path(dest)))
	RuntimeModelLoader.forget(dest)
	(_report["imported"] as Array).append(source.get_file())
	return dest


# --- Things and places -----------------------------------------------------------------

func _add_thing(name: String, thing: Dictionary) -> void:
	var key := _norm(name)
	if key.is_empty():
		return
	thing["display"] = thing.get("display", name)
	# Its real size, taken now: while a film builds, the timeline is applied again at
	# other moments, and someone who appears later is shrunk to nothing at those times.
	var node := thing.get("node") as Node3D
	if node and not thing.has("rest_scale"):
		thing["rest_scale"] = node.scale if node.scale.length() > 0.05 else Vector3.ONE
	_things[key] = thing
	_rebuild_names()


func _alias(name: String, thing: Dictionary) -> void:
	var key := _norm(name)
	if not key.is_empty() and not _things.has(key):
		_things[key] = thing
		_rebuild_names()


func _rebuild_names() -> void:
	_names.clear()
	for key in _things:
		_names.append([str(key), _things[key]])
	_names.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]).length() > str(b[0]).length())


func _thing(name: String) -> Dictionary:
	var key := _norm(name)
	if not _suffix.is_empty():
		for variant in [key + _suffix, key.trim_suffix("s") + _suffix]:
			if _things.has(variant):
				return _things[variant]
	if _things.has(key):
		return _things[key]
	if key.ends_with("s") and _things.has(key.trim_suffix("s")):
		return _things[key.trim_suffix("s")]
	var best := _best_key(key, _things.keys())
	return _things[best] if not best.is_empty() else {}


## Resolves a place description to { pos, yaw (NAN if none), thing }.
## [param who] is the character going there (used to approach from its side).
func _place_of(text: String, who: Dictionary, t: float = 0.0) -> Dictionary:
	var clean := _norm(text)
	for prefix in ["to ", "at ", "on top of ", "on ", "in ", "into ", "onto ", "towards ", "toward ", "by ", "from "]:
		if clean.begins_with(prefix) and not clean.begins_with("in front of"):
			clean = clean.substr(prefix.length())
			break
	var number_pattern := RegEx.create_from_string("^\\(?\\s*(-?[\\d.]+)\\s*[, ]\\s*(-?[\\d.]+)\\s*\\)?$")
	var numbers := number_pattern.search(text.strip_edges())
	if numbers == null:
		numbers = number_pattern.search(clean)
	if numbers:
		# Coordinates are in the current location's own metres (sets built on the backlot are offset).
		return {"pos": _on_ground(Vector3(numbers.get_string(1).to_float(), 0, numbers.get_string(2).to_float()) + _offset), "yaw": NAN, "thing": {}}
	var distance := -1.0
	var metres := RegEx.create_from_string("^([\\d.]+)\\s*(m|metres|meters|meter|metre)?\\s+").search(clean)
	if metres:
		distance = metres.get_string(1).to_float()
		clean = clean.substr(metres.get_end())
	if clean.begins_with("between "):
		var pair := clean.substr(8).split(" and ")
		if pair.size() == 2:
			var a := _place_of(pair[0], {}, t)
			var b := _place_of(pair[1], {}, t)
			return {"pos": _on_ground(((a["pos"] as Vector3) + (b["pos"] as Vector3)) * 0.5), "yaw": NAN, "thing": {}}
	var relation := ""
	for word in ["in front of ", "next to ", "beside ", "near ", "behind ", "left of ", "right of ", "away from ", "far from ", "from "]:
		if clean.begins_with(word):
			relation = word.strip_edges()
			clean = clean.substr(word.length())
			break
	var target := _thing(clean)
	if target.is_empty():
		if not clean.is_empty() and clean != "center":
			_warn("Place \"%s\" not found; used the centre of %s." % [text.strip_edges(), _location_name])
		target = _thing("center")
		if target.is_empty():
			return {"pos": _on_ground(Vector3.ZERO), "yaw": NAN, "thing": {}}
	var base := _pos_at(target, t)
	var yaw := float(target.get("yaw", 0.0))
	if target.get("kind") == "character" or target.get("kind") == "actor":
		yaw = _yaw_at(target, t)
	var front := _dir(yaw)
	var left := Vector3(front.z, 0, -front.x)
	var gap := float(target.get("radius", 0.0)) + 0.8
	if target.get("kind") == "prop":
		gap = float(target.get("radius", 0.0)) * 0.8 + 0.35  # walk right up to objects
	var out := base
	match relation:
		"in front of":
			out = base + front * (distance if distance > 0.0 else gap + 0.4)
		"behind":
			out = base - front * (distance if distance > 0.0 else gap)
		"left of":
			out = base + left * (distance if distance > 0.0 else gap)
		"right of":
			out = base - left * (distance if distance > 0.0 else gap)
		"away from", "far from":
			out = base + _away_dir(base, who, t) * (distance if distance > 0.0 else 12.0)
		"next to", "beside", "near", "from":
			out = base + _away_dir(base, who, t) * (distance if distance > 0.0 else gap)
		_:
			if distance > 0.0:
				out = base + _away_dir(base, who, t) * distance
	if relation.is_empty() and target.get("kind") != "mark" and not who.is_empty():
		# Walking "to" an object or person stops just short of it (in front of seats).
		if float(target.get("seat", -1.0)) >= 0.0:
			out = base + front * (float(target.get("depth", 0.4)) + 0.45)
		else:
			out = base + _away_dir(base, who, t) * gap
	var result_yaw := NAN if relation != "" or target.get("kind") != "mark" else yaw
	var final := out if _indoor() else _on_ground(out)
	var lowered := text.strip_edges().to_lower()
	if (lowered.begins_with("on ") or lowered.begins_with("onto ") or lowered.begins_with("on top of ")) and relation.is_empty() \
			and target.get("node") is Node3D and target.get("kind") == "prop":
		final = Vector3(base.x, PropUtils.world_aabb(target["node"] as Node3D).end.y, base.z)
	return {"pos": final, "yaw": result_yaw, "thing": target, "relation": relation}


func _away_dir(base: Vector3, who: Dictionary, t: float) -> Vector3:
	var from := Vector3.ZERO
	if not who.is_empty():
		from = _pos_at(who, t)
	else:
		var overview: Array = _overview()
		from = Vector3(overview[0], 0, overview[2])
	var d := Vector3(from.x - base.x, 0, from.z - base.z)
	if d.length() < 0.05:
		d = Vector3(0, 0, 1)
	return d.normalized()


static func _dir(yaw_degrees: float) -> Vector3:
	var r := deg_to_rad(yaw_degrees)
	return Vector3(sin(r), 0, cos(r))


static func _yaw_towards(from: Vector3, to: Vector3) -> float:
	var d := to - from
	if Vector2(d.x, d.z).length() < 0.01:
		return 0.0
	return rad_to_deg(atan2(d.x, d.z))


# --- Character state over time ---------------------------------------------------------------

func _pos_at(thing: Dictionary, t: float) -> Vector3:
	for span in thing.get("carry", []):
		var c: Dictionary = span
		if t >= float(c["start"]) and t < float(c["end"]):
			return _hand_pos(c["carrier"], thing, t, str(c["mode"]))
	var track: Array = thing.get("track", [])
	if track.is_empty():
		var node := thing.get("node") as Node3D
		return node.global_position if node and thing.get("kind") == "prop" else thing["pos"]
	# Keys sit on frame times: compare on that grid, and with several keys at the
	# same moment (a cut or teleport) the last one written wins.
	var at := snappedf(t, FRAME)
	var previous: Array = track[0]
	if at < float(previous[0]) - 0.001:
		return previous[1]
	for entry in track:
		var e: Array = entry
		if float(e[0]) <= at + 0.001:
			previous = e
			continue
		var span := float(e[0]) - float(previous[0])
		var w := 0.0 if span <= 0.0001 else clampf((t - float(previous[0])) / span, 0.0, 1.0)
		return (previous[1] as Vector3).lerp(e[1], w)
	return previous[1]


func _yaw_at(thing: Dictionary, t: float) -> float:
	var yaw := float(thing.get("yaw", 0.0))
	var faces: Array = thing.get("faces", [])
	for entry in faces:
		var e: Array = entry
		if float(e[0]) <= t + 0.001:
			yaw = float(e[1])
	return yaw


## True for a bed (sitting on one means its side edge, not the middle).
func _is_bed(seat: Dictionary) -> bool:
	var kind_name := str(seat.get("kind_name", seat.get("display", ""))).to_lower()
	return kind_name.contains("bed") and not kind_name.contains("bedside")


## The top of a seat's cushion (or a bed's mattress) under [param point]: the highest
## part of the prop there that is lower than a backrest. -1 when there is none.
func _seat_top(seat: Dictionary, point: Vector3, highest := 0.8) -> float:
	var node := seat.get("node") as Node3D
	if node == null:
		return -1.0
	var base := node.global_position.y
	var best := -1.0
	for found in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		if mesh.mesh == null or not mesh.visible:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		if point.x < box.position.x - 0.03 or point.x > box.end.x + 0.03 or point.z < box.position.z - 0.03 or point.z > box.end.z + 0.03:
			continue
		var top := box.end.y - base
		if top > 0.1 and top < highest and top > best:
			best = top
	if best <= 0.0 and _written_for_at_least("1.28"):
		# One mesh for the whole seat and back (a downloaded bench): the highest
		# surface right under the person, from the mesh's own triangles.
		for found in node.find_children("*", "MeshInstance3D", true, false):
			var mesh := found as MeshInstance3D
			if mesh.mesh == null or not mesh.visible:
				continue
			var xf := mesh.global_transform
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
					continue
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
				for k in range(0, index.size() - 2, 3):
					var a := xf * verts[index[k]]
					var b := xf * verts[index[k + 1]]
					var c := xf * verts[index[k + 2]]
					var normal := (b - a).cross(c - a)
					if normal.length() < 1e-8 or absf(normal.normalized().y) < 0.75:
						continue  # backs and sides: only flat, sit-on surfaces
					var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(point.x, base + highest, point.z), Vector3.DOWN, a, b, c)
					if hit == null:
						continue
					var h: Vector3 = hit
					var top := h.y - base
					if top > 0.1 and top < highest and top > best:
						best = top
	return base + best if best > 0.0 else -1.0


## Lifts or lowers [param into] so that this person's hips rest on the seat's real
## surface in [param pose] ("Sit" or "Lie Down"), whatever their size.
func _onto_seat(thing: Dictionary, seat: Dictionary, into: Vector3, pose: String) -> Vector3:
	var person := thing.get("node") as CharacterBase
	if person == null:
		return into
	var hip := person.pose_hip_height(pose)
	if hip < 0.0:
		return into
	var size: Vector3 = thing.get("rest_scale", Vector3.ONE)
	hip *= size.y
	var top := _seat_top(seat, Vector3(into.x, 0, into.z), 0.95 if pose == "Lie Down" else 0.8)
	if top < 0.0:
		return into
	# Hips sit a little above the surface: the body's own thickness.
	var thickness := 0.025 if pose == "Sit" else 0.1 * size.y
	return Vector3(into.x, maxf(top + thickness - hip, top - 0.6 if pose == "Sit" else top - 1.0), into.z)


## The closest visible person to [param thing] within [param reach] metres (same place).
func _nearest_person(thing: Dictionary, t: float, reach: float) -> Dictionary:
	var here := _pos_at(thing, t)
	var best: Dictionary = {}
	var best_d := reach
	for key in _things:
		var other: Dictionary = _things[key]
		if is_same(other, thing) or other.get("kind") != "character" or bool(other.get("hidden", false)) or not bool(other.get("placed", false)):
			continue
		var d := _pos_at(other, t).distance_to(here)
		if d < best_d:
			best_d = d
			best = other
	return best


func _sitting_at(thing: Dictionary, t: float) -> bool:
	for span in thing.get("sits", []):
		var s: Array = span
		if t >= float(s[0]) and t < float(s[1]):
			return true
	return false


## How much [param thing] has grown ("grows to 2") at [param t]; 1 = its own size.
func _grown_at(thing: Dictionary, t: float) -> float:
	var size := 1.0
	for g in thing.get("growth", []):
		var span: Array = g
		if t >= float(span[1]):
			size = float(span[3])
		elif t >= float(span[0]):
			size = lerpf(float(span[2]), float(span[3]), smoothstep(float(span[0]), float(span[1]), t))
	return size


## Lying down or kneeling at [param t] (talking then doesn't stand them up).
func _lying_at(thing: Dictionary, t: float) -> bool:
	for span in thing.get("postures", []):
		var s: Array = span
		if t >= float(s[0]) and t < float(s[1]):
			return true
	return false


func _uid(thing: Dictionary) -> String:
	return PropUtils.uid_of(thing["node"] as Node)


func _key(thing: Dictionary, t: float, pos: Vector3, rotation: Variant = null, glide: bool = false) -> void:
	if bool(thing.get("afloat", false)):
		var water := _water_y(pos.x, pos.z)
		if not is_nan(water):
			pos.y = water
	var node := thing["node"] as Node3D
	var parent := node.get_parent() as Node3D
	var local := parent.to_local(pos) if parent else pos
	var quat: Quaternion = node.quaternion
	if thing.get("kind") != "character" and not (thing.get("faces", []) as Array).is_empty():
		quat = Quaternion(Vector3.UP, deg_to_rad(_yaw_at(thing, t)))  # keep the way it currently faces
	if rotation is Quaternion:
		quat = rotation
	var scale: Vector3 = Vector3.ONE * 0.001 if bool(thing.get("hidden", false)) else (thing["scale"] as Vector3 if thing.has("scale") else thing.get("rest_scale", node.scale) as Vector3)
	builder.timeline.store.set_key(_uid(thing), TimelineController.CH_TRANSFORM, _snap(t),
		{"position": local, "quaternion": quat, "scale": scale}, false, glide)
	var track: Array = thing["track"]
	var when := _snap(t)
	var replaced := false
	for entry in track:
		if absf(float((entry as Array)[0]) - when) < 0.001:
			(entry as Array)[1] = pos  # same frame: the newest key wins, as in the timeline
			replaced = true
			break
	if not replaced:
		track.append([when, pos])
		track.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	thing["pos"] = pos
	thing["keys"] = true
	_end = maxf(_end, t)


func _face(thing: Dictionary, t: float, yaw: float) -> void:
	if thing.get("kind") != "character":
		# Animals and objects turn their whole node (keyed rotation).
		var node := thing.get("node") as Node3D
		if node == null:
			return
		var turn := Quaternion(Vector3.UP, deg_to_rad(yaw))
		if not bool(thing.get("keys", false)) and t <= 0.05:
			node.quaternion = turn
		else:
			_key(thing, maxf(t, 0.0), _pos_at(thing, t), turn)
		(thing["faces"] as Array).append([_snap(t), yaw])
		(thing["faces"] as Array).sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		thing["yaw"] = yaw
		return
	builder.timeline.store.set_key(_uid(thing), TimelineController.CH_FACE, _snap(t), {"yaw": wrapf(yaw, -180.0, 180.0)}, false)
	(thing["faces"] as Array).append([_snap(t), yaw])
	(thing["faces"] as Array).sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	thing["yaw"] = yaw


func _action(thing: Dictionary, t: float, action: String) -> void:
	if thing.get("kind") != "character":
		return
	builder.timeline.store.set_key(_uid(thing), TimelineController.CH_ACTION, _snap(t), {"action": action}, false)


func _base_action(thing: Dictionary) -> String:
	if bool(thing.get("sitting", false)):
		return "Sit"
	return str(thing.get("posture", MotionLibrary.AUTO))


func _posture_at(thing: Dictionary, t: float) -> String:
	for span in thing.get("postures", []):
		var s: Array = span
		if t >= float(s[0]) and t < float(s[1]):
			return str(s[2])
	return ""


## Puts [param thing] at [param pos] at time [param t] (instantly).
func _put(thing: Dictionary, t: float, pos: Vector3, yaw: float) -> void:
	var first := not bool(thing.get("placed", false)) and not bool(thing.get("keys", false))
	thing["placed"] = true
	if first:
		(thing["node"] as Node3D).global_position = pos
		thing["pos"] = pos
		_key(thing, 0.0, pos)
		if not is_nan(yaw):
			_face(thing, 0.0, yaw)
		return
	var old := _pos_at(thing, t)
	var held := false
	if _written_for_at_least("1.28"):
		# Already held a frame before (appearing right here: that key keeps them hidden).
		for entry in thing["track"]:
			if absf(float((entry as Array)[0]) - _snap(t - FRAME)) < 0.001:
				held = true
	if held:
		_key(thing, t, pos)
	elif _written_for_at_least("1.28") and t - FRAME > 0.0:
		# Hold the last place actually keyed until the move (not a point part-way to a
		# later key: people slid between locations across a whole scene).
		var last_before: Variant = null
		for entry in thing["track"]:
			if float((entry as Array)[0]) < _snap(t) - 0.001:
				last_before = entry
		if last_before != null and ((last_before as Array)[1] as Vector3).distance_to(pos) > 0.01:
			old = (last_before as Array)[1]
			_key(thing, t - FRAME, old)
	if old.distance_to(pos) > 0.01:
		if t - FRAME > 0.0 and not held:
			_key(thing, t - FRAME, old)
		_key(thing, t, pos)
		if t <= FRAME * 2.0:
			# Moved before the film really starts (e.g. set dressing for a later
			# location): move the object itself too, so "on bed" finds its new top.
			(thing["node"] as Node3D).global_position = pos
	if old.distance_to(pos) > 1.5 and thing.get("kind") == "character":
		# Placed somewhere else: whatever they were sitting, kneeling or lying on stays behind.
		if bool(thing.get("sitting", false)):
			thing["sitting"] = false
			_end_sit(thing, t)
		thing.erase("seat_front")
		if thing.has("posture"):
			thing.erase("posture")
			for span in thing.get("postures", []):
				if float((span as Array)[1]) == INF:
					(span as Array)[1] = t
		_action(thing, t, MotionLibrary.AUTO)
	if not is_nan(yaw):
		_face(thing, t + FRAME * 3.0, yaw)


## A walking path from [param from] to [param to] that goes round furniture standing in
## the way (pupils walked straight through school desks). Ends with [param to].
func _route(from: Vector3, to: Vector3) -> Array:
	var path: Array = [from, to]
	var boxes := _solid_props()
	for round in 4:
		var fixed := false
		for i in path.size() - 1:
			var a: Vector3 = path[i]
			var b: Vector3 = path[i + 1]
			for found in boxes:
				var box: AABB = found
				if not _crosses_box(a, b, box, 0.2):
					continue
				var best := Vector3.INF
				var best_len := INF
				var r := box.grow(0.4)
				for corner in [Vector3(r.position.x, 0, r.position.z), Vector3(r.end.x, 0, r.position.z), Vector3(r.position.x, 0, r.end.z), Vector3(r.end.x, 0, r.end.z)]:
					var c := _on_ground(Vector3((corner as Vector3).x, a.y, (corner as Vector3).z))
					if _crosses_box(a, c, box, 0.2) or _crosses_box(c, b, box, 0.2) or _out_of_furniture(c).distance_to(c) > 0.01:
						continue
					if _location.has("bounds"):
						var bounds: Array = _location["bounds"]
						var local := c - _offset
						if local.x < float(bounds[0]) + 0.2 or local.x > float(bounds[1]) - 0.2 or local.z < float(bounds[2]) + 0.2 or local.z > float(bounds[3]) - 0.2:
							continue
					var length := a.distance_to(c) + c.distance_to(b)
					if length < best_len:
						best_len = length
						best = c
				if best != Vector3.INF:
					path.insert(i + 1, best)
					fixed = true
					break
			if fixed:
				break
		if not fixed:
			break
	path.remove_at(0)
	return path


## Whether the floor path a-b runs through [param box] (grown by [param margin]); not
## when either end is already inside it (getting up from a chair, walking to a seat).
func _crosses_box(a: Vector3, b: Vector3, box: AABB, margin: float) -> bool:
	var r := box.grow(margin)
	var flat := AABB(Vector3(r.position.x, -1.0, r.position.z), Vector3(r.size.x, 2.0, r.size.z))
	var a0 := Vector3(a.x, 0, a.z)
	var b0 := Vector3(b.x, 0, b.z)
	if flat.has_point(a0) or flat.has_point(b0) or a0.distance_to(b0) < 0.05:
		return false
	return flat.intersects_segment(a0, b0) != null


func _walk(thing: Dictionary, t: float, points: Array, speed: float) -> float:
	var start := _pos_at(thing, t)
	if not bool(thing.get("placed", false)):
		thing["placed"] = true
		_warn("%s walks before being placed; add a line like \"%s is at <place>\" first." % [thing["display"], thing["display"]])
	# Coming from another location (a set far away on the backlot): arrive straight away
	# instead of walking hundreds of metres.
	if not points.is_empty() and Vector2(start.x - (points[0] as Vector3).x, start.z - (points[0] as Vector3).z).length() > 40.0:
		var last: Vector3 = points[points.size() - 1]
		var before_last: Vector3 = points[points.size() - 2] if points.size() > 1 else start
		var arrive_yaw := _yaw_towards(before_last, last) if points.size() > 1 else float(thing.get("yaw", 0.0))
		_put(thing, t, last, arrive_yaw)
		thing["busy"] = t
		return 0.0
	_key(thing, t, start)
	var is_character: bool = thing.get("kind") == "character"
	if is_character and _written_for_at_least("1.28") and not points.is_empty():
		# Around desks and tables, not through them.
		var routed: Array = []
		var leg_from := start
		for point in points:
			routed.append_array(_route(leg_from, point as Vector3))
			leg_from = point
		points = routed
	var time := t
	var from := start
	for point in points:
		var to: Vector3 = point
		var span := Vector2(to.x - from.x, to.z - from.z).length()
		if span < 0.05:
			continue
		var heading := _yaw_towards(from, to)
		var rotation: Variant = null if is_character else Quaternion(Vector3.UP, deg_to_rad(heading))
		(thing["faces"] as Array).append([_snap(time), heading])
		thing["yaw"] = heading
		var steps := maxi(1, ceili(span / 1.0))
		# Objects in the air (planes, a floating globe) keep their height and travel at
		# an even speed; things on the ground follow it.
		var afloat := bool(thing.get("afloat", false))
		var flying := not is_character and not afloat and from.y > _ground(from.x, from.z) + 0.5
		if flying:
			to.y = from.y
		for step in range(1, steps + 1):
			var f := float(step) / float(steps)
			var p := from.lerp(to, f)
			if not _indoor() and not flying and not afloat:
				p.y = _ground(p.x, p.z)
			var turn: Variant = rotation
			if afloat and rotation is Quaternion:
				# Rocks on the water: a little roll and a wandering heading, every metre.
				var phase := float(step) + float(thing.get("rock", 0.0))
				turn = (rotation as Quaternion) * Quaternion(Vector3.UP, deg_to_rad(sin(phase * 1.7) * 9.0)) \
					* Quaternion(Vector3.FORWARD, deg_to_rad(sin(phase * 2.3) * 6.0))
			_key(thing, time + span * f / maxf(speed, 0.05), p, turn, not is_character and step < steps - 1)
		if afloat:
			thing["rock"] = float(thing.get("rock", 0.0)) + float(steps)
		time += span / maxf(speed, 0.05)
		from = to
	thing["busy"] = time
	return time - t


# --- Lines -------------------------------------------------------------------------

func _run_line(raw: String, t: float, scene: int, number: int) -> Dictionary:
	var text := raw.strip_edges()
	var parallel := false
	if text.ends_with("&"):
		parallel = true
		text = text.trim_suffix("&").strip_edges()
	for opener in ["meanwhile", "at the same time", "simultaneously"]:
		if text.to_lower().begins_with(str(opener)):
			parallel = true
			text = text.substr(str(opener).length()).strip_edges().trim_prefix(",").strip_edges()
	var result := _dispatch(text, t, scene)
	if result.has("error"):
		_warn("Line %d \"%s\": %s" % [number, raw.strip_edges().left(60), result["error"]])
		return {"dur": 0.0}
	if parallel:
		result["parallel"] = true
	return result


func _dispatch(text: String, t: float, scene: int) -> Dictionary:
	var upper := text.to_upper()
	var keyword := ""
	var rest := text
	var colon := text.find(":")
	if colon > 0:
		keyword = upper.substr(0, colon).strip_edges()
		rest = text.substr(colon + 1).strip_edges()
	match keyword:
		"SHOT", "CAMERA", "CUT TO", "CUT":
			_shots.append({"t": t, "spec": rest, "scene": scene, "auto": false, "set": _set_index})
			_awaiting_first_shot = false
			return {"dur": 0.0}
		"TITLE", "CAPTION", "LOWER THIRD", "SUBTITLE", "TEXT", "CARD", "HERO TITLE", "BIG TITLE", "CINEMATIC", "TRAILER TEXT", "LETTERBOX", "BARS",\
				"QUOTE", "QUOTE CARD", "EPIGRAPH", "TIME CARD", "TIMECARD", "CHAPTER":
			return _title_line(keyword, rest, t)
		"WAIT", "PAUSE", "BEAT", "HOLD":
			return {"dur": _seconds(rest, 1.5)}
		"COUNTER", "DAY COUNTER":
			return _counter_line(rest, t)
		"PHONE", "PHONE SCREEN", "SCREEN":
			return _phone_line(rest, t)
		"NOTE", "STICKY NOTE", "LIST":
			return _note_line(rest, t)
		"CALENDAR":
			return _calendar_line(rest, t)
		"WORDS", "VOICES IN HEAD", "THOUGHTS":
			return _words_line(rest, t)
		"POST", "PHOTO", "INSTA":
			return _post_line(rest, t)
		"NUMBER", "STAT", "STATISTIC", "FIGURE":
			return _number_line(rest, t)
		"SPLIT", "SPLIT SCREEN", "SPLITSCREEN":
			return _split_line(rest, t)
		"AT", "TIME AT":
			return {"at": _seconds(rest, t)}
		"MUSIC", "SOUND", "SFX", "AUDIO":
			_add_sound(rest, t, keyword == "MUSIC")
			return {"dur": 0.0}
		"LIGHT", "SKY", "ENV", "ENVIRONMENT":
			var over := _over(rest)
			_env_change(t, _pairs(_strip_over(rest)), over)
			return {"dur": 0.0}
		"LOCATION", "LOCATION CHANGE", "PLACE":
			_switch_location(rest, t, scene)
			return {"dur": 0.0}
		"TIME", "TIME OF DAY":
			_env_change(t, _time_values(_strip_over(rest)), _over(rest))
			return {"dur": 0.0}
		"WEATHER":
			_env_change(t, _weather_values(_strip_over(rest)), _over(rest))
			return {"dur": 0.0}
	for word in ["SHOT ", "CAMERA ", "CUT TO "]:
		if upper.begins_with(word) and colon < 0:
			_shots.append({"t": t, "spec": text.substr(word.length()).strip_edges(), "scene": scene, "auto": false, "set": _set_index})
			_awaiting_first_shot = false
			return {"dur": 0.0}
	for word in ["TITLE ", "CAPTION ", "SUBTITLE "]:
		if upper.begins_with(word) and colon < 0:
			return _title_line(word.strip_edges(), text.substr(word.length()), t)
	if upper.begins_with("WAIT ") or upper.begins_with("PAUSE "):
		return {"dur": _seconds(text.substr(text.find(" ")), 1.5)}
	if upper.begins_with("AT ") and _seconds(text.substr(3), -1.0) >= 0.0:
		return {"at": _seconds(text.substr(3), 0.0)}
	# Dialogue: Name: "line"   /   Name (waves, to Elder): line
	if colon > 0:
		var who_part := text.substr(0, colon).strip_edges()
		var direction := ""
		var open := who_part.find("(")
		if open > 0:
			direction = who_part.substr(open + 1).trim_suffix(")").strip_edges()
			who_part = who_part.substr(0, open).strip_edges()
		var mode := "say"
		for pair in [[" whispers", "whisper"], [" whisper", "whisper"], [" thinks", "think"], [" says", "say"], [" shouts", "say"]]:
			if who_part.to_lower().ends_with(str(pair[0])):
				mode = str(pair[1])
				who_part = who_part.substr(0, who_part.length() - str(pair[0]).length()).strip_edges()
				break
		var speaker := _thing(who_part) if _norm(who_part).length() > 0 else {}
		if not speaker.is_empty() and (speaker.get("kind") == "character" or speaker.get("kind") == "actor") and _norm(who_part) == _norm(str(speaker["display"])):
			return _dialogue(speaker, direction, rest, t, scene, mode)
	# Actions: Name <verb …>
	var lower := _norm(text)
	for pair in _names:
		var key := str(pair[0])
		var thing: Dictionary = pair[1]
		if thing.get("kind") == "mark":
			continue
		if lower == key or lower.begins_with(key + " "):
			return _action_line(thing, lower.substr(key.length()).strip_edges(), text, t, scene)
	return {"error": "didn't understand this line (it should start with a cast name, SHOT:, TITLE:, WAIT…)"}


## COUNTER: "DAYS CLEAN: 3"   (stays in the corner until the next COUNTER line)   /   COUNTER: off
## COUNTER: "SPENT SINCE YOU PRESSED PLAY: ${n}" rate 91546 since 0
## A live counter: {n} counts up by "rate" per second of film time from "since" (seconds
## or m:ss; default: the film's start).
func _counter_line(rest: String, t: float) -> Dictionary:
	_close_counter(t)
	var live := {}
	var rate_match := RegEx.create_from_string("(?i)\\brate\\s+([\\d.,]+)").search(_mask_quotes(rest))
	if rate_match:
		live["rate"] = rate_match.get_string(1).replace(",", "").to_float()
		live["since"] = 0.0
		var since_match := RegEx.create_from_string("(?i)\\bsince\\s+([\\d:.]+)").search(_mask_quotes(rest))
		if since_match:
			live["since"] = _seconds(since_match.get_string(1), 0.0)
		var quoted := RegEx.create_from_string("\"([^\"]*)\"").search(rest)
		rest = quoted.get_string(1) if quoted else rest.substr(0, rate_match.get_start())
	var text := rest.strip_edges().trim_prefix("\"").trim_suffix("\"").strip_edges()
	if text.to_lower() in ["off", "none", "hide", "end", ""]:
		return {"dur": 0.0}
	var item := {"text": text, "start": t, "length": 900.0, "style": "Counter", "open": true}
	if not live.is_empty():
		item["live"] = live
	_titles.append(item)
	return {"dur": 0.0}


func _close_counter(t: float) -> void:
	for item in _titles:
		if item.get("open", false) and str(item.get("style", "")) == "Counter":
			item["length"] = maxf(t - float(item["start"]), 0.2)
			item.erase("open")


## PHONE: feed "App name" at 1:41 for 4s
## PHONE: message "Mom" "Did you eat?" for 3s
## PHONE: dialog "Delete this app?" "Cancel" "Delete" for 4s, taps Delete
## PHONE: cracked for 3s        PHONE: cracked, shadow face for 3s
## PHONE: home for 2s           PHONE: notification "Exam tomorrow!" for 3s
## A phone moment fills the screen (a close-up of the phone) and takes its time.
func _phone_line(rest: String, t: float) -> Dictionary:
	var seconds := 3.0
	var found := RegEx.create_from_string("(?i)\\bfor\\s+([\\d.]+)\\s*(s|sec|secs|seconds)?\\b").search(rest)
	if found:
		seconds = found.get_string(1).to_float()
		rest = (rest.substr(0, found.get_start()) + rest.substr(found.get_end())).strip_edges()
	var quoted: Array = []
	for m in RegEx.create_from_string("\"([^\"]*)\"").search_all(rest):
		quoted.append(m.get_string(1))
	var bare := RegEx.create_from_string("\"[^\"]*\"").sub(rest, "", true).to_lower()
	var mode := "home"
	for word in ["feed", "message", "dialog", "dialogue", "popup", "cracked", "crack", "notification", "home", "call", "lock", "off"]:
		if bare.contains(word):
			mode = {"dialogue": "dialog", "popup": "dialog", "crack": "cracked", "lock": "home"}.get(word, word)
			break
	if mode == "off":
		return {"dur": 0.0}
	var clock := ""
	var clock_match := RegEx.create_from_string("\\b(\\d{1,2}:\\d{2})\\b").search(bare)
	if clock_match:
		clock = clock_match.get_string(1)
	var tap := ""
	var tap_match := RegEx.create_from_string("\\btaps\\s+(\\w+)").search(bare)
	if tap_match:
		tap = tap_match.get_string(1)
	var face := bare.contains("shadow") or bare.contains("face")
	_titles.append({"text": "\n".join(PackedStringArray(quoted)), "start": t, "length": seconds, "style": "Phone",
		"phone": {"mode": mode, "texts": quoted, "clock": clock, "tap": tap, "face": face}})
	_end = maxf(_end, t + seconds)
	return {"dur": seconds}


## NOTE: "Learn guitar" | "Every day:" | "- 2 hours" | "- scales" for 4s, strike 3 4, add "Today: 5 minutes"
## A full-screen close-up of a sticky note. "strike" crosses lines out with a pen (one
## after another, during the shot); "add" writes new lines at the bottom.
func _note_line(rest: String, t: float) -> Dictionary:
	var seconds := _for_seconds(rest, 4.0)
	rest = _strip_for(rest)
	var lower := rest.to_lower()
	var adds: Array = []
	var add_at := lower.find(", add ")
	if add_at < 0:
		add_at = lower.find(" add ")
	var body := rest
	if add_at >= 0:
		for m in RegEx.create_from_string("\"([^\"]*)\"").search_all(rest.substr(add_at)):
			adds.append(m.get_string(1))
		body = rest.substr(0, add_at)
	var lines: Array = []
	for m in RegEx.create_from_string("\"([^\"]*)\"").search_all(body):
		lines.append(m.get_string(1))
	var strike: Array = []
	var strike_match := RegEx.create_from_string("(?i)strikes?\\s+([\\d ,\\-and]+)").search(body)
	if strike_match:
		strike = _number_list(strike_match.get_string(1))
	_titles.append({"text": " / ".join(PackedStringArray(lines)), "start": t, "length": seconds, "style": "Note",
		"note": {"lines": lines, "strike": strike, "add": adds}})
	_end = maxf(_end, t + seconds)
	return {"dur": seconds}


## CALENDAR: "March" start 4, done 4-17, missed 1-3 for 4s
## A month on the wall: "start N" circles the start day, "done A-B" draws a red circle
## and a tick on each day (one after another during the shot), "missed" crosses days out.
func _calendar_line(rest: String, t: float) -> Dictionary:
	var seconds := _for_seconds(rest, 4.0)
	rest = _strip_for(rest)
	var month := "October"
	var q := RegEx.create_from_string("\"([^\"]*)\"").search(rest)
	if q:
		month = q.get_string(1)
	var lower := rest.to_lower()
	var data := {"month": month, "start": 0, "done": [], "missed": [], "first": 3}
	var m := RegEx.create_from_string("start (\\d+)").search(lower)
	if m:
		data["start"] = m.get_string(1).to_int()
	m = RegEx.create_from_string("done ([\\d ,\\-and]+)").search(lower)
	if m:
		data["done"] = _number_list(m.get_string(1))
	m = RegEx.create_from_string("missed ([\\d ,\\-and]+)").search(lower)
	if m:
		data["missed"] = _number_list(m.get_string(1))
	m = RegEx.create_from_string("first day (\\w+)").search(lower)
	if m:
		var days := ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
		data["first"] = maxi(0, days.find(m.get_string(1).left(3)))
	_titles.append({"text": month, "start": t, "length": seconds, "style": "Calendar", "calendar": data})
	_end = maxf(_end, t + seconds)
	return {"dur": seconds}


## WORDS: Later "lazy" "again?" "why bother" "tomorrow" for 4s
## Many handwritten words at once, drifting around a character (the noise in your head).
## Each speaker's colour for floating dialogue: "words yellow" in the cast line, else the next
## colour of the palette (first speaker white, then warm yellow, light blue, pink...).
func _speech_color(speaker: Dictionary) -> Color:
	var node: Node = speaker.get("node")
	if node and node.has_meta(&"speech_color"):
		return node.get_meta(&"speech_color")
	var key := str(speaker.get("display", ""))
	if not _speech_colors.has(key):
		_speech_colors[key] = SPEECH_PALETTE[_speech_colors.size() % SPEECH_PALETTE.size()]
	return _speech_colors[key]


func _words_line(rest: String, t: float) -> Dictionary:
	var seconds := _for_seconds(rest, 4.0)
	rest = _strip_for(rest)
	var words: Array = []
	for m in RegEx.create_from_string("\"([^\"]*)\"").search_all(rest):
		words.append(m.get_string(1))
	# "color #e8a33d" (or "warm" / "cold") picks the colour of the words.
	var own_color := Color(-1, 0, 0)
	var color_match := RegEx.create_from_string("(?i)\\b(?:colou?r)\\s+(#?[0-9a-z]+)").search(RegEx.create_from_string("\"[^\"]*\"").sub(rest, "", true))
	if color_match:
		own_color = _color(color_match.get_string(1))
		rest = rest.replace(color_match.get_string(0), "")
	var who_text := RegEx.create_from_string("\"[^\"]*\"").sub(rest, "", true).strip_edges()
	var who := _thing(who_text) if not who_text.is_empty() else {}
	var color := Color(0.75, 0.75, 0.8)
	var node: Node = who.get("node")
	if node is SketchCharacter and (node as SketchCharacter).figure == "Shadow":
		color = (node as SketchCharacter).glow_color.lerp(Color.WHITE, 0.2)
	if own_color.r >= 0.0:
		color = own_color
	_titles.append({"text": " ".join(PackedStringArray(words)), "start": t, "length": seconds, "style": "Words",
		"anchor": _uid(who) if not who.is_empty() else "", "color": [color.r, color.g, color.b], "words": words})
	return {"dur": 0.0}


## POST: "@maya.wanders" "Paradise again." 2341 likes for 4s
## The moment frozen as a social post: a camera flash, a white card framing the shot
## (name on top, likes counting up and the caption below) and the rest of the frame
## dimmed. The scene keeps playing inside the frame ("&" lets people act during it).
func _post_line(rest: String, t: float) -> Dictionary:
	var seconds := _for_seconds(rest, 4.0)
	rest = _strip_for(rest)
	var texts: Array = []
	for m in RegEx.create_from_string("\"([^\"]*)\"").search_all(rest):
		texts.append(m.get_string(1))
	var likes := 0
	var likes_match := RegEx.create_from_string("(?i)([\\d,]+)\\s*likes?").search(rest)
	if likes_match:
		likes = likes_match.get_string(1).replace(",", "").to_int()
	var data := {"user": str(texts[0]) if texts.size() > 0 else "@me", "caption": str(texts[1]) if texts.size() > 1 else "", "likes": likes,
		"flash": not rest.to_lower().contains("no flash")}
	_titles.append({"text": str(data["caption"]), "start": t, "length": seconds, "style": "Post", "post": data})
	_end = maxf(_end, t + seconds)
	return {"dur": seconds}



## NUMBER: 2887000000000 prefix "$" "World military spending, 2025" "Source: SIPRI, April 2026" for 7s
## A big statistic counting up from 0 (or "from N") in the middle of the frame, with a
## label under it and a small source line. "dim" darkens the scene behind it, "paper"
## shows it on a plain page, "suffix people" adds a word after the number,
## "short" writes 2.9 trillion instead of every digit. The scene keeps playing.
func _number_line(rest: String, t: float) -> Dictionary:
	var seconds := _for_seconds(rest, 6.0)
	rest = _strip_for(rest)
	var texts: Array = []
	for m in RegEx.create_from_string("\"([^\"]*)\"").search_all(rest):
		texts.append(m.get_string(1))
	var bare := RegEx.create_from_string("\"[^\"]*\"").sub(rest, "", true)
	var lower := bare.to_lower()
	var data := {"value": 0.0, "from": 0.0, "prefix": "", "suffix": "", "decimals": 0,
		"label": "", "source": "", "backdrop": "box", "short": lower.contains("short")}
	var prefix_match := RegEx.create_from_string("(?i)prefix\\s+\"([^\"]*)\"").search(rest)
	var suffix_match := RegEx.create_from_string("(?i)suffix\\s+\"([^\"]*)\"").search(rest)
	var plain: Array = []
	for text in texts:
		if prefix_match and text == prefix_match.get_string(1):
			data["prefix"] = text
		elif suffix_match and text == suffix_match.get_string(1):
			data["suffix"] = text
		else:
			plain.append(text)
	data["label"] = str(plain[0]) if plain.size() > 0 else ""
	data["source"] = str(plain[1]) if plain.size() > 1 else ""
	bare = RegEx.create_from_string("(?i)\\b(prefix|suffix)\\b").sub(bare, "", true)
	var from_match := RegEx.create_from_string("(?i)\\bfrom\\s+([\\d,.]+)").search(bare)
	if from_match:
		data["from"] = from_match.get_string(1).replace(",", "").to_float()
		bare = bare.substr(0, from_match.get_start()) + bare.substr(from_match.get_end())
	var value_match := RegEx.create_from_string("(-?[\\d][\\d,]*(\\.\\d+)?)").search(bare)
	if value_match == null:
		return {"error": "NUMBER needs a number, e.g. NUMBER: 645000000 \"people facing hunger\""}
	data["value"] = value_match.get_string(1).replace(",", "").to_float()
	data["decimals"] = value_match.get_string(2).length() - 1 if not value_match.get_string(2).is_empty() else 0
	if lower.contains("dim"):
		data["backdrop"] = "dim"
	elif lower.contains("paper") or lower.contains("page") or lower.contains("blank"):
		data["backdrop"] = "paper"
	_titles.append({"text": str(data["label"]), "start": t, "length": seconds, "style": "Number", "number": data})
	_end = maxf(_end, t + seconds)
	return {"dur": 0.0}


## SPLIT: "MILITARY" from (x, y, z) to (x, y, z) | "HUMAN NEEDS" from (x, y, z) to (x, y, z) for 8s
## Two live camera views side by side (a divider between them, a label on top of each).
## "from" is where the camera stands, "to" what it looks at (location metres, y up).
## Each view pushes in slowly ("push 0.1" = 10 % closer over the time; "push 0" = still).
## The scene keeps playing in both halves; "&" lets the next lines run during it.
func _split_line(rest: String, t: float) -> Dictionary:
	var seconds := _for_seconds(rest, 7.0)
	rest = _strip_for(rest)
	var push := 0.08
	var push_match := RegEx.create_from_string("(?i)\\bpush\\s+([\\d.]+)").search(rest)
	if push_match:
		push = push_match.get_string(1).to_float()
		rest = rest.substr(0, push_match.get_start()) + rest.substr(push_match.get_end())
	var fov := 50.0
	var fov_match := RegEx.create_from_string("(?i)\\bfov\\s+([\\d.]+)").search(rest)
	if fov_match:
		fov = clampf(fov_match.get_string(1).to_float(), 10.0, 100.0)
		rest = rest.substr(0, fov_match.get_start()) + rest.substr(fov_match.get_end())
	var point := "\\(\\s*(-?[\\d.]+)\\s*,\\s*(-?[\\d.]+)\\s*,\\s*(-?[\\d.]+)\\s*\\)"
	var half_pattern := RegEx.create_from_string("(?i)(?:\"([^\"]*)\")?\\s*from\\s*" + point + "\\s*(?:to|looking at|at)\\s*" + point)
	var halves: Array = []
	for part in rest.split("|"):
		var m := half_pattern.search(part)
		if m == null:
			return {"error": "each half needs: \"Label\" from (x, y, z) to (x, y, z)"}
		var eye := Vector3(m.get_string(2).to_float(), m.get_string(3).to_float(), m.get_string(4).to_float()) + _offset
		var target := Vector3(m.get_string(5).to_float(), m.get_string(6).to_float(), m.get_string(7).to_float()) + _offset
		halves.append({"label": m.get_string(1), "eye": [eye.x, eye.y, eye.z], "target": [target.x, target.y, target.z]})
	if halves.size() != 2:
		return {"error": "SPLIT needs two halves separated by |"}
	_titles.append({"text": "%s | %s" % [halves[0]["label"], halves[1]["label"]], "start": t, "length": seconds,
		"style": "Split", "split": {"halves": halves, "push": push, "fov": fov}})
	_end = maxf(_end, t + seconds)
	return {"dur": 0.0}


func _for_seconds(rest: String, fallback: float) -> float:
	var found := RegEx.create_from_string("(?i)\\bfor\\s+([\\d.]+)\\s*(s|sec|secs|seconds)?\\b").search(rest)
	return found.get_string(1).to_float() if found else fallback


func _strip_for(rest: String) -> String:
	var found := RegEx.create_from_string("(?i)\\bfor\\s+([\\d.]+)\\s*(s|sec|secs|seconds)?\\b").search(rest)
	if found:
		return (rest.substr(0, found.get_start()) + rest.substr(found.get_end())).strip_edges()
	return rest


## "1-3, 5 and 7" -> [1, 2, 3, 5, 7]
static func _number_list(text: String) -> Array:
	var out: Array = []
	for part in text.replace(" and ", ",").replace(" ", ",").split(",", false):
		if part.contains("-"):
			var ab := part.split("-", false)
			if ab.size() == 2:
				for n in range(ab[0].to_int(), ab[1].to_int() + 1):
					out.append(n)
		elif part.is_valid_int():
			out.append(part.to_int())
	return out


func _title_line(keyword: String, rest: String, t: float) -> Dictionary:
	var style := "Title"
	match keyword:
		"CAPTION":
			style = "Caption (top)"
		"LOWER THIRD":
			style = "Lower third"
		"SUBTITLE":
			style = "Subtitle"
		"HERO TITLE", "BIG TITLE":
			style = "Hero"
		"QUOTE", "QUOTE CARD", "EPIGRAPH":
			style = "Quote"
		"TIME CARD", "TIMECARD", "CHAPTER":
			style = "Timecard"
		"CINEMATIC", "TRAILER TEXT":
			style = "Cinematic"
		"LETTERBOX", "BARS":
			style = "Letterbox"
			if not rest.to_lower().contains("for "):
				# "LETTERBOX: on" - bars for the rest of the film
				_titles.append({"text": "", "start": t, "length": 36000.0, "style": style, "open": true})
				return {"dur": 0.0}
			rest = rest.to_lower().replace("on ", "")
	var seconds := 3.5
	var found := RegEx.create_from_string("(?i)\\bfor\\s+([\\d.]+)\\s*(s|sec|secs|seconds)?\\b").search(rest)
	if found:
		seconds = found.get_string(1).to_float()
		rest = (rest.substr(0, found.get_start()) + rest.substr(found.get_end())).strip_edges()
	var text := rest.strip_edges().trim_prefix("\"").trim_suffix("\"").replace("\" | \"", "\n").replace(" | ", "\n").replace("|", "\n")
	if style == "Letterbox":
		text = ""
	_titles.append({"text": text, "start": t, "length": seconds, "style": style})
	return {"dur": 0.0}


func _dialogue(speaker: Dictionary, direction: String, rest: String, t: float, scene: int, mode: String = "say") -> Dictionary:
	var audio_file := ""
	var voice := "Normal"
	var volume := 0.0
	var brackets := RegEx.create_from_string("\\[([^\\]]*)\\]")
	for found in brackets.search_all(rest):
		var inner := found.get_string(1).strip_edges()
		var cut := inner.find(":")
		var key := inner.substr(0, cut).strip_edges().to_lower() if cut > 0 else "audio"
		var value := inner.substr(cut + 1).strip_edges() if cut > 0 else inner
		match key:
			"audio", "file", "voice file", "sound":
				audio_file = value
			"voice", "effect":
				voice = _best_key(value, AudioTrack.VOICES.keys())
				if voice.is_empty():
					_warn("Unknown voice \"%s\" (use one of: %s)." % [value, ", ".join(PackedStringArray(AudioTrack.VOICES.keys()))])
					voice = "Normal"
			"volume":
				volume = value.to_float()
	var line := brackets.sub(rest, "", true).strip_edges()
	line = line.trim_prefix("\"").trim_suffix("\"").trim_prefix("“").trim_suffix("”").strip_edges()
	var words := line.split(" ", false).size()
	var seconds := clampf(float(words) / 2.6 + 0.6, 1.4, 20.0)
	var envelope := PackedFloat32Array()
	if audio_file.is_empty() and _voices_on and not line.is_empty() and speaker.has("voice"):
		audio_file = SpeechMaker.speak(line, speaker["voice"])
		if audio_file.is_empty() and not _voice_warned:
			_voice_warned = true
			_warn("Automatic voices aren't available on this computer (no speech engine found), so lines are shown as subtitles only.")
	if not audio_file.is_empty():
		var clip := _add_sound("%s, volume %s, voice %s" % [audio_file, volume, voice], t, false)
		if not clip.is_empty() and audio_file.begins_with(SpeechMaker.CACHE_DIR):
			clip["name"] = "%s: %s" % [speaker["display"], line.left(36)]
		if not clip.is_empty():
			var length := builder.audio.clip_length(clip)
			if length > 0.1:
				seconds = length
			envelope = builder.audio.mouth_envelope(clip)
	if envelope.is_empty():
		envelope = _speech_envelope(seconds)
	if mode != "think":
		(speaker["lips"] as Array).append([t, envelope])
	if mode == "whisper" or mode == "think":
		# Floating words next to the speaker (in the glow colour for a shadow).
		var color := Color(0.92, 0.9, 0.86)
		var node: Node = speaker.get("node")
		if node is SketchCharacter and (node as SketchCharacter).figure == "Shadow":
			color = (node as SketchCharacter).glow_color.lerp(Color.WHITE, 0.15)
		elif mode == "whisper":
			color = Color(1.0, 0.42, 0.32)
		_titles.append({"text": line, "start": t, "length": seconds + 0.6, "style": "Whisper",
			"anchor": _uid(speaker), "color": [color.r, color.g, color.b], "think": mode == "think"})
		if mode == "think" or not speaker.get("node") is CharacterBase:
			_end = maxf(_end, t + seconds)
			return {"dur": seconds + 0.3}
	elif _floating and not line.is_empty() and speaker.get("node") is Node3D:
		# Words next to the speaker's head, in the speaker's own colour.
		var sc := _speech_color(speaker)
		_titles.append({"text": line, "start": t, "length": seconds + 0.5, "style": "Speech",
			"anchor": _uid(speaker), "color": [sc.r, sc.g, sc.b]})
	elif _subtitles and not line.is_empty():
		_titles.append({"text": line, "start": t, "length": seconds + 0.1, "style": "Subtitle"})
	# Direction: (to Elder), (waves), (sitting)…
	var listener: Dictionary = {}
	var gesture := ""
	for part in direction.split(","):
		var p := _norm(part)
		if p.is_empty():
			continue
		if p.begins_with("to "):
			listener = _thing(p.substr(3))
		elif p.begins_with("at "):
			listener = _thing(p.substr(3))
		else:
			for word in GESTURES:
				if p.begins_with(str(word)) or p == str(word).trim_suffix("s"):
					gesture = str(GESTURES[word])
			if p.begins_with("point"):
				gesture = "Point"
			for word in POSE_GESTURES:
				if p.begins_with(str(word)):
					_pose_gesture(speaker, str(word), t, -1.0)
	if listener.is_empty() and mode != "think" and _written_for_at_least("1.28"):
		# Talking to someone by name ("Hari Kaka. You gave me my first haircut.").
		var said := " " + line.to_lower().replace(".", " ").replace(",", " ").replace("!", " ").replace("?", " ") + " "
		var first_at := 1 << 30
		for key in _things:
			var named: Dictionary = _things[key]
			if named.get("kind") != "character" or is_same(named, speaker) or bool(named.get("hidden", false)):
				continue
			var who_name := str(named.get("display", "")).to_lower().replace(".", "")
			var at := said.find(" " + who_name + " ")
			# Only when called by name: at the start ("Hari Kaka. You...") or at the end ("..., Dai?").
			var calling := at == 0 or said.strip_edges().ends_with(" " + who_name) and line.to_lower().contains(", " + who_name)
			if calling and at >= 0 and at < first_at and _pos_at(named, t).distance_to(_pos_at(speaker, t)) < 8.0:
				first_at = at
				listener = named
	if listener.is_empty() and mode != "think" and _written_for_at_least("1.28") and _last_speaker == str(speaker["display"]):
		# Still talking to the same person as in their last line.
		var before: Dictionary = _thing(str(speaker.get("talking_to", ""))) if speaker.has("talking_to") else {}
		if not before.is_empty() and not bool(before.get("hidden", false)) and _pos_at(before, t).distance_to(_pos_at(speaker, t)) < 8.0:
			listener = before
	if listener.is_empty() and not _last_speaker.is_empty() and _last_speaker != str(speaker["display"]):
		var previous := _thing(_last_speaker)
		if not previous.is_empty() and not bool(previous.get("hidden", false)) and _pos_at(previous, t).distance_to(_pos_at(speaker, t)) < 8.0:
			listener = previous
	if listener.is_empty() and mode != "think" and _written_for_at_least("1.28"):
		# Nobody answered yet (the first line of a scene): talk to whoever is nearest.
		listener = _nearest_person(speaker, maxf(t, float(speaker.get("busy", 0.0))), 4.5)
	if mode != "think":
		_last_speaker = str(speaker["display"])
		if not listener.is_empty():
			speaker["talking_to"] = str(listener.get("display", ""))  # a name: two people talking to each other would make a loop
	var free := t >= float(speaker.get("busy", 0.0)) - 0.05 and not _sitting_at(speaker, t) and not _lying_at(speaker, t)
	if not listener.is_empty() and not is_same(listener, speaker) and mode != "think":
		if _sitting_at(speaker, t) and speaker.get("kind") == "character":
			_look_with_head(speaker, t, _yaw_towards(_pos_at(speaker, t), _pos_at(listener, t)))
		var standing := not _sitting_at(speaker, t) and not _lying_at(speaker, t)
		if standing and _written_for_at_least("1.28"):
			# Still walking: turn to them as soon as they arrive.
			var when := t if float(speaker.get("busy", 0.0)) < t - 0.3 else maxf(t, float(speaker.get("busy", 0.0)) + 0.25)
			var yaw := _yaw_towards(_pos_at(speaker, when), _pos_at(listener, when))
			if absf(wrapf(yaw - _yaw_at(speaker, when), -180.0, 180.0)) > 15.0:
				_face(speaker, when, yaw)
		elif free:
			var yaw := _yaw_towards(_pos_at(speaker, t), _pos_at(listener, t))
			if absf(wrapf(yaw - _yaw_at(speaker, t), -180.0, 180.0)) > 15.0:
				_face(speaker, t, yaw)
		var listener_standing: bool = listener.get("kind") == "character" and not _sitting_at(listener, t) and not _lying_at(listener, t)
		if listener_standing:
			var when := t + 0.2
			if _written_for_at_least("1.28"):
				if float(listener.get("busy", 0.0)) >= t - 0.3:
					when = maxf(when, float(listener.get("busy", 0.0)) + 0.25)
			elif t < float(listener.get("busy", 0.0)) - 0.05:
				when = -1.0
			if when >= 0.0:
				var back := _yaw_towards(_pos_at(listener, when), _pos_at(speaker, when))
				if absf(wrapf(back - _yaw_at(listener, when), -180.0, 180.0)) > 15.0:
					_face(listener, when, back)
		elif listener.get("kind") == "character" and _sitting_at(listener, t) and _written_for_at_least("1.28"):
			_look_with_head(listener, t + 0.2, _yaw_towards(_pos_at(listener, t), _pos_at(speaker, t)))
	if free and speaker.get("kind") == "character":
		_action(speaker, t, gesture if not gesture.is_empty() else "Talk")
		_action(speaker, t + seconds, _base_action(speaker))
	_events.append({"t": t, "dur": seconds, "kind": "line", "who": str(speaker["display"]),
		"to": str(listener.get("display", "")) if not listener.is_empty() else "", "scene": scene})
	_end = maxf(_end, t + seconds)
	return {"dur": seconds + 0.3}


func _action_line(thing: Dictionary, rest: String, original: String, t: float, scene: int) -> Dictionary:
	var name := str(thing["display"])
	var t0 := t
	for pair in [["is sitting", "sits"], ["is seated", "sits"], ["sits down on", "sits on"], ["sits down at", "sits at"],
			["is standing", "stands"], ["is walking", "walks"], ["is running", "runs"], ["gets up", "stands up"],
			["is waving", "waves"], ["is talking", "talks"], ["is dancing", "dances"], ["is waiting", "waits"]]:
		if rest.begins_with(str(pair[0])):
			rest = str(pair[1]) + rest.substr(str(pair[0]).length())
	var seconds := -1.0
	var found := RegEx.create_from_string("\\bfor ([\\d.]+)\\s*(s|sec|secs|second|seconds)?\\b").search(rest)
	if found:
		seconds = found.get_string(1).to_float()
		rest = (rest.substr(0, found.get_start()) + rest.substr(found.get_end())).strip_edges()
	var speed_scale := 1.0
	for word in ["slowly", "quickly", "briskly", "fast", "calmly", "carefully"]:
		if rest.contains(str(word)):
			speed_scale = 0.7 if word in ["slowly", "calmly", "carefully"] else 1.35
			rest = rest.replace(str(word), "").replace("  ", " ").strip_edges()
	var given_speed := -1.0
	var speed_match := RegEx.create_from_string("\\bat ([\\d.]+)\\s*(m s|ms|m/s|mps|metres per second)").search(rest)
	if speed_match:
		given_speed = speed_match.get_string(1).to_float()
		rest = (rest.substr(0, speed_match.get_start()) + rest.substr(speed_match.get_end())).strip_edges()
	var facing := ""
	var facing_at := rest.find(" facing ")
	if facing_at >= 0:
		facing = rest.substr(facing_at + 8).strip_edges()
		rest = rest.substr(0, facing_at).strip_edges()
	var verb := rest.split(" ", false)[0] if not rest.is_empty() else ""
	var after := rest.substr(verb.length()).strip_edges()
	var is_character: bool = thing.get("kind") == "character"
	if thing.get("node") is SketchCharacter or (thing.get("node") is ImportedCharacter and (thing.get("node") as ImportedCharacter).has_expressions()):
		var mood := ""
		var faces := {"smiles": "Happy", "grins": "Happy", "frowns": "Sad", "smirks": "Smirk", "panics": "Scared", "gasps": "Shocked",
			"cries": "Crying", "sobs": "Crying", "beams": "Proud", "worries": "Worried"}
		if faces.has(verb) and after.is_empty():
			mood = str(faces[verb])
		elif verb == "laughs" and after.is_empty():
			_set_face(thing, t, "Laughing")
		elif verb in ["sleeps", "dozes"]:
			_set_face(thing, t, "Asleep")
		elif verb == "wakes":
			_set_face(thing, t, "Tired")
		elif verb in ["looks", "feels", "becomes", "gets", "seems"] and not after.is_empty() and not after.begins_with("at ") \
				and not after.begins_with("around") and not after.begins_with("to "):
			mood = _best_key(after.split(" ", false)[0], Array(SketchCharacter.EXPRESSIONS))
		if not mood.is_empty():
			_set_face(thing, t, mood)
			# Realistic people also act it out (their own motion-capture clips).
			if thing.get("node") is ImportedCharacter and verb in ["cries", "sobs"] and (thing["node"] as ImportedCharacter).action_names().has("Cry"):
				return _gesture(thing, t, "Cry", seconds, scene)
			if verb == "gasps" or verb == "panics":
				pass   # the gesture still plays below
			else:
				return {"dur": 0.0 if seconds < 0.0 else seconds}

	# Emotion glow (story people): "Rohan glows red", "Rohan glows softly blue over 2s",
	# "Rohan's glow fades" / "Rohan stops glowing" / "Rohan calms down".
	var glow_node := thing.get("node") as SketchCharacter
	if glow_node != null and glow_node.figure == "Story":
		var glow_off := (verb == "stops" and after.begins_with("glow")) or (verb in ["calms", "cools"] and (after.is_empty() or after.begins_with("down"))) \
				or rest.begins_with("glow fades") or rest.begins_with("'s glow fades")
		if verb in ["glows", "burns", "boils", "seethes", "shines"] or glow_off:
			var over_g := RegEx.create_from_string("over ([\\d.]+)").search(after)
			var over_s := over_g.get_string(1).to_float() if over_g else (1.2 if glow_off else 0.8)
			var amount := 0.0
			var color: Color = thing.get("glow_color", glow_node.glow_color)
			if not glow_off:
				amount = 0.45 if after.contains("soft") or after.contains("faint") or after.contains("slight") else (1.0 if after.contains("bright") or after.contains("strong") or verb in ["burns", "boils", "seethes"] else 0.8)
				for word in ["red", "orange", "blue", "gold", "yellow", "green", "purple", "white", "pink", "cyan", "teal"]:
					if (" " + after + " ").contains(" " + str(word) + " "):
						color = _color(str(word))
				if verb in ["burns", "boils", "seethes"] and not after.contains("blue"):
					color = Color(1.0, 0.22, 0.1) if not thing.has("glow_color") or (thing["glow_color"] as Color).b > 0.5 else color
			var before := float(thing.get("glow", 0.0))
			var before_color: Color = thing.get("glow_color", color)
			var uid := _uid(thing)
			builder.timeline.store.set_key(uid, "glow", _snap(t), {"glow_amount": before, "glow_color": before_color if before > 0.01 else color}, false)
			builder.timeline.store.set_key(uid, "glow", _snap(t + over_s), {"glow_amount": amount, "glow_color": color}, false)
			thing["glow"] = amount
			thing["glow_color"] = color
			return {"dur": 0.0 if seconds < 0.0 else seconds}

	# Growing and shrinking: "Later shrinks to 0.5 over 3s", "Later grows to 1.6".
	if verb in ["grows", "shrinks", "scales", "swells"] and (after.begins_with("to ") or after.begins_with("back")):
		var size_match := RegEx.create_from_string("to ([\\d.]+)").search(after)
		var target_scale := 1.0 if after.begins_with("back") else (size_match.get_string(1).to_float() if size_match else 1.0)
		target_scale = clampf(target_scale, 0.05, 6.0)
		var over_match := RegEx.create_from_string("over ([\\d.]+)").search(after)
		var over := over_match.get_string(1).to_float() if over_match else 1.0
		var node := thing["node"] as Node3D
		if not thing.has("base_scale"):
			thing["base_scale"] = thing.get("rest_scale", node.scale)
		var from_scale: Vector3 = thing["scale"] if thing.has("scale") else node.scale
		var to_scale: Vector3 = (thing["base_scale"] as Vector3) * target_scale
		thing["scale"] = from_scale
		_key(thing, t, _pos_at(thing, t))
		var steps := maxi(1, int(over / 0.25))
		for i in range(1, steps + 1):
			var f := smoothstep(0.0, 1.0, float(i) / float(steps))
			thing["scale"] = from_scale.lerp(to_scale, f)
			_key(thing, t + over * float(i) / float(steps), _pos_at(thing, t + over * float(i) / float(steps)))
		thing["scale"] = to_scale
		if not thing.has("growth"):
			thing["growth"] = []
		(thing["growth"] as Array).append([t, t + over, from_scale.y / maxf((thing["base_scale"] as Vector3).y, 0.001), target_scale])
		return {"dur": 0.0 if seconds < 0.0 else seconds}

	# Movement.
	var walk_verbs := {"walks": 1.35, "walk": 1.35, "goes": 1.35, "go": 1.35, "heads": 1.35, "moves": 1.35, "steps": 1.0,
		"strolls": 0.9, "wanders": 0.9, "limps": 0.7, "returns": 1.35, "comes": 1.35, "approaches": 1.2, "crosses": 1.35,
		"runs": 3.8, "run": 3.8, "jogs": 2.6, "sprints": 6.0, "rushes": 3.8, "hurries": 2.6, "dashes": 4.5,
		"drives": 10.0, "rides": 5.0, "rolls": 6.0, "flies": 8.0, "sails": 3.0, "leaves": 1.35, "exits": 1.35,
		"sneaks": 0.6, "tiptoes": 0.5, "creeps": 0.55, "marches": 1.6, "waddles": 0.8, "storms": 2.2, "shuffles": 0.6,
		"trots": 2.0, "scurries": 2.4, "slides": 1.0, "backs": 0.8, "follows": 1.35}
	if walk_verbs.has(verb) and (after.begins_with("to ") or after.begins_with("towards ") or after.begins_with("toward ")
			or after.begins_with("into ") or after.begins_with("back to ") or after.begins_with("over to ") or after.begins_with("up to ")
			or after.begins_with("across to ") or after.begins_with("away") or verb == "approaches" or verb == "crosses" or after.begins_with("past ")):
		if bool(thing.get("sitting", false)):
			thing["sitting"] = false
			_end_sit(thing, t)
			_action(thing, t, MotionLibrary.AUTO)
			if thing.has("seat_front"):
				_key(thing, t, _pos_at(thing, t))
				_key(thing, t + 0.8, thing["seat_front"])
				thing.erase("seat_front")
			t += 1.0
		var target_text := after
		for prefix in ["back to ", "over to ", "up to ", "across to ", "to ", "towards ", "toward ", "into ", "past "]:
			if target_text.begins_with(prefix):
				target_text = target_text.substr(prefix.length())
				break
		var stops: Array = []
		var via_at := target_text.find(" via ")
		var final_text := target_text
		if via_at >= 0:
			final_text = target_text.substr(0, via_at)
			for part in target_text.substr(via_at + 5).replace(" and ", ",").split(","):
				if not part.strip_edges().is_empty():
					stops.append(_place_of(part, thing, t)["pos"])
		if final_text.begins_with("away"):
			final_text = "away from " + final_text.trim_prefix("away").trim_prefix(" from").strip_edges()
		var destination := _place_of(final_text, thing, t)
		var end_pos := _avoid_others(thing, destination["pos"] as Vector3, t)
		stops.append(end_pos)
		var speed := (given_speed if given_speed > 0.0 else float(walk_verbs[verb]) * speed_scale)
		if is_character:
			_action(thing, t, MotionLibrary.AUTO)
		var travel := _walk(thing, t, stops, speed)
		var arrive := t + travel
		var target_thing: Dictionary = destination.get("thing", {})
		if not facing.is_empty():
			_face(thing, arrive + FRAME * 3.0, _yaw_towards(end_pos, _place_of(facing, {}, arrive)["pos"]))
		elif not is_nan(float(destination.get("yaw", NAN))):
			_face(thing, arrive + FRAME * 3.0, float(destination["yaw"]))
		elif not target_thing.is_empty() and target_thing.get("kind") != "mark":
			_face(thing, arrive + FRAME * 3.0, _yaw_towards(end_pos, _pos_at(target_thing, arrive)))
		if _written_for_at_least("1.28"):
			# Busy until that last turn too, so a turn or hug after this waits for it.
			thing["busy"] = maxf(float(thing.get("busy", 0.0)), arrive + FRAME * 4.0)
		if verb == "leaves" or verb == "exits":
			thing["hidden"] = true
			_key(thing, arrive + FRAME, end_pos)
		_events.append({"t": t, "dur": travel, "kind": "move", "who": name, "scene": scene})
		return {"dur": arrive - t0}

	# Appear / disappear / placement.
	if verb in ["enters", "appears", "arrives", "is", "stands", "waits", "starts", "begins", "stays", "remains"] and \
			not (verb == "stands" and (after.is_empty() or after.begins_with("up"))) and not (verb == "waits" and after.is_empty()):
		var place_text := after
		for prefix in ["at ", "in ", "from ", "by "]:
			if place_text.begins_with(prefix):
				place_text = place_text.substr(prefix.length())
		var stay := place_text.is_empty() and bool(thing.get("placed", false))
		if place_text.is_empty():
			place_text = "center"
		var spot := {"pos": _pos_at(thing, t), "yaw": NAN, "thing": {}} if stay else _place_of(after if after.begins_with("near") or after.begins_with("next") or after.begins_with("beside") or after.begins_with("in front") or after.begins_with("behind") or after.begins_with("left") or after.begins_with("right") or after.begins_with("between") else place_text, {}, t)
		var at_thing: Dictionary = spot.get("thing", {})
		if is_character and not stay and _written_for_at_least("1.28") and str(spot.get("relation", "")).is_empty() \
				and at_thing.get("kind") == "prop" and float(at_thing.get("seat", -1.0)) < 0.0 and at_thing.get("node") is Node3D:
			# "Shyam appears at roof door": in front of it, not inside it.
			var box := PropUtils.world_aabb(at_thing["node"] as Node3D)
			if box.size.y > 0.35 and box.position.y < 0.3 + _offset.y:
				var front := _dir(float(at_thing.get("yaw", 0.0)))
				var reach := absf(front.x) * box.size.x * 0.5 + absf(front.z) * box.size.z * 0.5 + 0.35
				spot["pos"] = _on_ground((spot["pos"] as Vector3) + front * reach)
				if is_nan(float(spot.get("yaw", NAN))):
					var out_of_it := str(at_thing.get("kind_name", "")).to_lower().contains("door")
					spot["yaw"] = float(at_thing.get("yaw", 0.0)) + (0.0 if out_of_it else 180.0)
		var pos := _avoid_others(thing, spot["pos"] as Vector3, t)
		var yaw := float(spot.get("yaw", NAN))
		if not facing.is_empty():
			yaw = _yaw_towards(pos, _place_of(facing, {}, t)["pos"])
		var appearing := verb in ["enters", "appears", "arrives"]
		# Showing up somewhere else ends sitting, lying or kneeling from before.
		if not stay and is_character and bool(thing.get("placed", false)) and (bool(thing.get("sitting", false)) or not _posture_at(thing, t).is_empty()):
			if bool(thing.get("sitting", false)):
				thing["sitting"] = false
				_end_sit(thing, t)
				thing.erase("seat_front")
			for span in thing.get("postures", []):
				if float((span as Array)[1]) == INF:
					(span as Array)[1] = t
			thing.erase("posture")
			_action(thing, t, MotionLibrary.AUTO)
		if appearing:
			thing["appeared_at"] = t
		if appearing and t > 0.05 and not bool(thing.get("placed", false)):
			thing["hidden"] = true
			_put(thing, 0.0, pos, yaw)
			_key(thing, t - FRAME, pos)
			thing["hidden"] = false
			_key(thing, t, pos)
			if not is_nan(yaw):
				_face(thing, t, yaw)
		elif appearing and bool(thing.get("hidden", false)):
			# (Not when it vanished on this very frame: that key holds it, still visible, where it was.)
			if absf(float(thing.get("hidden_at", -1.0)) - t) > FRAME * 0.5:
				_key(thing, t - FRAME, _pos_at(thing, t))
			thing["hidden"] = false
			_key(thing, t, pos)
			if not is_nan(yaw):
				_face(thing, t, yaw)
		else:
			_put(thing, t, pos, yaw)
		if is_nan(yaw) and is_character and not spot.get("thing", {}).is_empty() and (spot["thing"] as Dictionary).get("kind") != "mark":
			_face(thing, t + FRAME * 3.0, _yaw_towards(pos, _pos_at(spot["thing"], t)))
		return {"dur": 0.0}
	if verb in ["disappears", "vanishes", "leaves", "exits"] and not after.begins_with("to"):
		if not _carrying(thing).is_empty():
			_end_carry(thing, t)  # whoever held it lets go
		# Hold it, still visible, where it is - unless it was put here on this very frame
		# ("Mina is at door 11" then "Mina disappears"): that move already holds the old
		# place a frame earlier, and overwriting it made people slide in from far away.
		var moved_now := false
		for entry in thing["track"]:
			if absf(float((entry as Array)[0]) - _snap(t)) < 0.001 and t > FRAME:
				moved_now = true
		if not moved_now:
			_key(thing, maxf(t - FRAME, 0.0), _pos_at(thing, t))
		thing["hidden"] = true
		thing["hidden_at"] = t
		_key(thing, t, _pos_at(thing, t))
		return {"dur": 0.0}

	# Someone who disappeared and is then told to sit, lie down or walk is plainly back
	# ("Aarav disappears" ... "Aarav sits on dining chair" used to leave an empty chair).
	if is_character and bool(thing.get("hidden", false)) and _written_for_at_least("1.28") \
			and verb in ["sits", "lies", "walks", "runs", "hurries", "rushes", "kneels", "hugs", "dances", "stands"]:
		var here := _pos_at(thing, t)
		if absf(float(thing.get("hidden_at", -1.0)) - t) > FRAME * 0.5:
			_key(thing, t - FRAME, here)
		thing["hidden"] = false
		thing["appeared_at"] = t
		_key(thing, t, here)

	# Rising / sinking objects: "lantern rises 25m over 14s toward lake".
	if not is_character and verb in ["rises", "floats", "ascends", "lifts", "drifts", "flies", "sinks", "descends", "lowers", "falls", "drops"] \
			and not after.begins_with("to ") and not after.begins_with("into "):
		return _rise(thing, verb, after, t, seconds, scene)

	if not is_character:
		if verb in ["spins", "revolves", "turns slowly"] or (verb in ["turns", "rotates"] and RegEx.create_from_string("^(-?[\\d.]+)\\s*(°|deg|degrees)?(\\s|$)").search(after) != null):
			return _spin(thing, after, t, seconds, scene)
		if verb in ["turns", "faces", "rotates"]:
			var target := _place_of(after.trim_prefix("to ").trim_prefix("towards "), {}, t)
			var node := thing["node"] as Node3D
			var new_yaw := _yaw_towards(_pos_at(thing, t), target["pos"])
			_key(thing, t, _pos_at(thing, t), Quaternion(Vector3.UP, deg_to_rad(_yaw_at(thing, t))) if not (thing["faces"] as Array).is_empty() else node.quaternion)
			_face(thing, t + 0.8, new_yaw)
			return {"dur": 0.8}
		return {"error": "%s is an object: it can only move (\"%s moves to …\"), turn, appear or disappear." % [name, name]}

	# Sitting and standing.
	if verb in ["sits", "sit", "settles"]:
		var seat_text := after.trim_prefix("down").strip_edges()
		for prefix in ["on ", "at ", "in ", "onto "]:
			if seat_text.begins_with(prefix):
				seat_text = seat_text.substr(prefix.length())
		var duration := 1.2
		# "sits on bench, left" / "on the right side of the bench": which end (as seen
		# by the person sitting).
		var side := 0.0
		for pair in [[", far left", 2.0], [" far left", 2.0], [", far right", -2.0], [" far right", -2.0],
				[", left side", 1.0], [" left side", 1.0], [", left", 1.0], [" left", 1.0],
				[", right side", -1.0], [" right side", -1.0], [", right", -1.0], [" right", -1.0]]:
			if seat_text.ends_with(str(pair[0])):
				side = float(pair[1])
				seat_text = seat_text.trim_suffix(str(pair[0])).strip_edges()
				break
		if not seat_text.is_empty():
			var seat := _thing(seat_text)
			if seat.is_empty():
				return {"error": "can't find \"%s\" to sit on" % seat_text}
			var seat_pos := _pos_at(seat, t)
			var seat_yaw := float(seat.get("yaw", 0.0))
			var lift := maxf(float(seat.get("seat", 0.0)), 0.0)
			var into := seat_pos + Vector3(0, lift, 0)
			var seat_left := Vector3(_dir(seat_yaw).z, 0, -_dir(seat_yaw).x)
			var sit_yaw := seat_yaw
			var on_bed := _is_bed(seat)
			if on_bed:
				# On the side of a bed, feet on the floor - not in the middle of the mattress.
				var bed_box := PropUtils.world_aabb(seat["node"] as Node3D) if seat.get("node") is Node3D else AABB(seat_pos, Vector3.ONE)
				var half := absf(seat_left.x) * bed_box.size.x * 0.5 + absf(seat_left.z) * bed_box.size.z * 0.5
				var toward := _pos_at(thing, t) if bool(thing.get("placed", false)) else _offset
				var sign := 1.0 if (toward - seat_pos).dot(seat_left) >= 0.0 else -1.0
				if _written_for_at_least("1.28") and side == 0.0:
					# Whichever side has floor to put their feet on (not the wall side), and
					# the side they come from when both do.
					var here_now := _pos_at(thing, t)
					if not bool(thing.get("placed", false)) or here_now.distance_to(seat_pos) > 30.0:
						here_now = _offset
					var best_sign := sign
					var best_room := -INF
					for s in [1.0, -1.0]:
						var feet := seat_pos + seat_left * float(s) * (half + 0.55)
						var room := 1.0 if _out_of_furniture(feet).distance_to(feet) < 0.01 else 0.0
						if _location.has("bounds"):
							var b: Array = _location["bounds"]
							var local := feet - _offset
							room += minf(minf(local.x - float(b[0]), float(b[1]) - local.x), minf(local.z - float(b[2]), float(b[3]) - local.z))
						room -= 0.001 * here_now.distance_to(feet)
						if room > best_room:
							best_room = room
							best_sign = float(s)
					sign = best_sign
				if side != 0.0:
					sign = signf(side)
				into = seat_pos + seat_left * sign * maxf(half - 0.24, 0.1) + _dir(seat_yaw) * 0.15
				sit_yaw = rad_to_deg(atan2(seat_left.x * sign, seat_left.z * sign))
			elif absf(side) > 1.5:
				into += seat_left * signf(side) * clampf(float(seat.get("radius", 0.8)) * 0.62, 0.4, 1.2)
			elif side != 0.0:
				into += seat_left * side * minf(0.4, float(seat.get("radius", 0.8)) * 0.45)
			for key in _things:
				var other: Dictionary = _things[key]
				if is_same(other, thing) or other.get("kind") != "character" or not _sitting_at(other, t) or bool(other.get("hidden", false)):
					continue
				var there := _pos_at(other, t)
				var along := _dir(sit_yaw) if on_bed else seat_left
				if Vector2(there.x - into.x, there.z - into.z).length() < 0.45:
					into += along.cross(Vector3.UP).normalized() * 0.6 if on_bed else seat_left * (0.6 if Vector2(there.x - (into + seat_left * 0.6).x, there.z - (into + seat_left * 0.6).z).length() > 0.45 else -0.6)
			into = _onto_seat(thing, seat, into, "Sit")
			var here := _pos_at(thing, t)
			if not bool(thing.get("placed", false)):
				_put(thing, 0.0, into, sit_yaw)
				if _written_for_at_least("1.28") and t > FRAME:
					_face(thing, t, sit_yaw)  # (anything said before sitting down may have turned them)
				duration = 0.0
			elif _awaiting_first_shot and _written_for_at_least("1.28"):
				# A new scene opening on someone seated: no walk across the room in the
				# last shot of the scene before.
				_put(thing, t, into, sit_yaw)
				_face(thing, t, sit_yaw)
				duration = 0.0
			elif here.distance_to(into) > 1.2:
				var front := _on_ground(into + _dir(sit_yaw) * 0.55) if on_bed else _on_ground(seat_pos + _dir(seat_yaw) * (float(seat.get("depth", 0.4)) + 0.45))
				_action(thing, t, MotionLibrary.AUTO)
				var travel := _walk(thing, t, [front], 1.3 * speed_scale)
				t += travel
				duration += travel
				_key(thing, t + 0.5, into)
				_face(thing, t + 0.5 + FRAME * 3.0, sit_yaw)
				t += 0.5
				thing["busy"] = t
			elif absf(float(thing.get("appeared_at", -99.0)) - t) < FRAME * 0.5 and _written_for_at_least("1.20"):
				# Appeared right here on this frame: already seated when the shot shows them.
				_key(thing, t, into)
				_face(thing, t, sit_yaw)
				duration = 0.0
			else:
				_key(thing, t, here)
				_key(thing, t + 0.5, into)
				_face(thing, t + 0.5 + FRAME * 3.0, sit_yaw)
				t += 0.5
			thing["seat_front"] = _on_ground(into + _dir(sit_yaw) * 0.45) if on_bed else _on_ground(seat_pos + _dir(seat_yaw) * (float(seat.get("depth", 0.4)) + 0.4))
			if not on_bed and _written_for_at_least("1.28"):
				# A chair pushed in at a table or desk: get up beside it, not into the table.
				var front_spot: Vector3 = thing["seat_front"]
				if _out_of_furniture(front_spot).distance_to(front_spot) > 0.01:
					var beside := _out_of_furniture(_on_ground(seat_pos + seat_left * 0.6 - _dir(seat_yaw) * 0.1))
					var other_side := _out_of_furniture(_on_ground(seat_pos - seat_left * 0.6 - _dir(seat_yaw) * 0.1))
					thing["seat_front"] = beside if beside.distance_to(seat_pos) <= other_side.distance_to(seat_pos) else other_side
		_action(thing, t, "Sit")
		thing["sitting"] = true
		(thing["sits"] as Array).append([t, INF])
		_events.append({"t": t, "dur": 1.2, "kind": "gesture", "who": name, "scene": scene})
		return {"dur": duration}
	if verb in ["stands", "gets", "rises"] and (after.is_empty() or after.begins_with("up")):
		if thing.has("posture"):
			thing.erase("posture")
			for span in thing.get("postures", []):
				if float((span as Array)[1]) == INF:
					(span as Array)[1] = t
		if bool(thing.get("sitting", false)):
			thing["sitting"] = false
			_end_sit(thing, t)
			if thing.has("seat_front"):
				# Step forward out of the seat while getting up.
				var here := _pos_at(thing, t)
				_key(thing, t, here)
				_key(thing, t + 0.8, thing["seat_front"])
				_face(thing, t + 0.8 + FRAME * 3.0, _yaw_at(thing, t))
				thing.erase("seat_front")
		_action(thing, t, MotionLibrary.AUTO)
		return {"dur": 1.2}

	# Playing an instrument: "Asha plays guitar for 4s" (picks it up if she isn't holding it).
	if verb in ["plays", "strums"] and not after.is_empty():
		var instrument_text := _strip_for(after).trim_prefix("the ").trim_prefix("her ").trim_prefix("his ").strip_edges()
		if _thing(instrument_text).get("kind") == "prop":
			return _play_line(thing, instrument_text, _for_seconds(after, 3.0), t, scene)

	# Carrying things.
	var raising_hand := verb == "raises" and after.trim_prefix("a ").trim_prefix("his ").trim_prefix("her ").trim_prefix("their ") in ["hand", "hands", "arm", "arms", "both hands"]
	if not raising_hand and verb in ["picks", "pick", "takes", "grabs", "carries", "raises", "lifts", "collects", "puts", "sets", "places", "drops",
			"lets", "releases", "frees", "gives", "hands", "passes", "offers"] \
			or (verb == "holds" and not after.is_empty() and _thing(after.trim_prefix("up ").trim_suffix(" high").trim_suffix(" up")).get("kind") == "prop"):
		return _carry_line(thing, verb, after, t, scene)

	# Kneeling and lying down.
	if verb in ["kneels", "kneel", "lies", "lie", "lays"]:
		var lying := verb != "kneels" and verb != "kneel"
		var where := after.trim_prefix("down").strip_edges()
		for prefix in ["on ", "at ", "in ", "beside ", "by "]:
			if where.begins_with(prefix):
				where = where.substr(prefix.length())
				break
		var duration := 1.2
		if not where.is_empty():
			var spot := _thing(where)
			if spot.is_empty():
				return {"error": "can't find \"%s\"" % where}
			var into := _pos_at(spot, t)
			var yaw := float(spot.get("yaw", 0.0))
			if lying and spot.get("node") is Node3D and spot.get("kind") == "prop":
				# Along the bed, head on the pillow, back on the mattress (not floating above it).
				into.y = PropUtils.world_aabb(spot["node"] as Node3D).end.y - 0.08
				into = _onto_seat(thing, spot, into, "Lie Down")
			elif not lying:
				into = _on_ground(into + _dir(yaw) * (float(spot.get("depth", 0.3)) + 0.5))
				yaw += 180.0
			if not bool(thing.get("placed", false)):
				_put(thing, 0.0, into, yaw)
			else:
				_key(thing, t, _pos_at(thing, t))
				_key(thing, t + 0.8, into)
				_face(thing, t + 0.8 + FRAME * 3.0, yaw)
				t += 0.8
				duration += 0.8
		var posture := "Lie Down" if lying else "Kneel"
		_action(thing, t, posture)
		thing["posture"] = posture
		if not thing.has("postures"):
			thing["postures"] = []
		(thing["postures"] as Array).append([t, INF, posture])
		_events.append({"t": t, "dur": 1.5, "kind": "gesture", "who": name, "scene": scene})
		return {"dur": duration}

	# Hugging someone.
	if verb in ["hugs", "hug", "embraces"]:
		var other := _thing(after.trim_prefix("with ").strip_edges())
		if other.is_empty() or other.get("kind") != "character":
			return {"error": "hug whom? e.g. \"%s hugs Ram\"" % name}
		var start := t
		if _written_for_at_least("1.28"):
			# Finish walking first (a hug straight after "walks to ..." used to start mid-walk).
			t = maxf(t, float(thing.get("busy", 0.0)))
		var here := _pos_at(thing, t)
		var there := _pos_at(other, t)
		if Vector2(there.x - here.x, there.z - here.z).length() > 0.7:
			var meet := there + Vector3(here.x - there.x, 0, here.z - there.z).normalized() * 0.45
			if _written_for_at_least("1.28"):
				meet = _out_of_furniture(meet)
			_action(thing, t, MotionLibrary.AUTO)
			t += _walk(thing, t, [_on_ground(meet)], 1.2)
		_face(thing, t, _yaw_towards(_pos_at(thing, t), there))
		_face(other, t, _yaw_towards(there, _pos_at(thing, t)))
		var length := seconds if seconds > 0.0 else 3.5
		for who in [thing, other]:
			_action(who, t, "Hug")
			_action(who, t + length, _base_action(who))
		_events.append({"t": t, "dur": length, "kind": "line", "who": name, "to": str(other["display"]), "scene": scene})
		_end = maxf(_end, t + length)
		return {"dur": t + length - start}

	# Turning to face something.
	if verb in ["turns", "faces", "looks", "glances", "stares", "watches"] and not after.begins_with("around"):
		var target_text := after
		for prefix in ["around to ", "back to ", "to face ", "to ", "at ", "towards ", "toward ", "away from "]:
			if target_text.begins_with(prefix):
				target_text = target_text.substr(prefix.length())
				break
		if target_text.is_empty():
			return {"error": "turn to whom? e.g. \"%s turns to the lake\"" % name}
		var target := _place_of(target_text, {}, t)
		var yaw := _yaw_towards(_pos_at(thing, t), target["pos"])
		if after.contains("away from"):
			yaw += 180.0
		if _sitting_at(thing, t):
			_look_with_head(thing, t, yaw)
		elif _written_for_at_least("1.28") and float(thing.get("busy", 0.0)) > t + 0.05:
			# Still walking there: turn once they arrive (the walk would undo it).
			var arrive := float(thing.get("busy", 0.0)) + 0.25
			var target_then := _place_of(target_text, {}, arrive)
			var yaw_then := _yaw_towards(_pos_at(thing, arrive), target_then["pos"])
			if after.contains("away from"):
				yaw_then += 180.0
			_face(thing, arrive, yaw_then)
		else:
			_face(thing, t, yaw)
		return {"dur": seconds if seconds > 0.0 else 0.8}

	# Pointing.
	if verb in ["points", "point", "gestures"]:
		var target_text := after.trim_prefix("at ").trim_prefix("to ").trim_prefix("towards ").strip_edges()
		if not target_text.is_empty() and not _sitting_at(thing, t):
			_face(thing, t, _yaw_towards(_pos_at(thing, t), _place_of(target_text, {}, t)["pos"]))
		return _gesture(thing, t, "Point", seconds, scene)

	# Hand-made poses.
	if verb in ["poses", "pose", "holds"] or rest.begins_with("relaxes") or rest.begins_with("resets pose"):
		var raw := original.to_lower()
		var at := -1
		for word in ["poses", "pose", "holds", "relaxes", "resets"]:
			at = raw.find(str(word))
			if at >= 0:
				break
		return _pose_line(thing, raw.substr(maxi(at, 0)), t, seconds)
	for word in POSE_GESTURES:
		if rest.begins_with(str(word)):
			return _pose_gesture(thing, str(word), t, seconds)
	if _sitting_at(thing, t) and rest.begins_with("wave"):
		return _pose_gesture(thing, "seated wave", t, seconds)

	# Named actions: built-in gestures, then the character's own (animation packs).
	for word in GESTURES:
		if rest.begins_with(str(word)):
			return _gesture(thing, t, str(GESTURES[word]), seconds, scene)
	var wanted := rest
	for prefix in ["does ", "plays ", "performs ", "starts ", "begins "]:
		if wanted.begins_with(prefix):
			wanted = wanted.substr(prefix.length())
	var names := (thing["node"] as CharacterBase).action_names()
	var match_name := _best_key(wanted, Array(names))
	if not match_name.is_empty():
		return _gesture(thing, t, match_name, seconds, scene)
	return {"error": "\"%s\" isn't an action %s can do (actions: %s)" % [rest, name, ", ".join(names)]}


## Moves an object up (or down) with a gentle sway, like a sky lantern or a
## balloon: "rises 25m over 14s toward lake", "floats up 10m", "sinks 2m over 3s".
func _rise(thing: Dictionary, verb: String, after: String, t: float, seconds: float, scene: int) -> Dictionary:
	var down := verb in ["sinks", "descends", "lowers", "falls", "drops"]
	var text := after.trim_prefix("up").trim_prefix("down").strip_edges()
	var height := 10.0
	var metres := RegEx.create_from_string("([\\d.]+)\\s*(m|metres|meters|meter|metre)?\\b").search(text)
	if metres:
		height = clampf(metres.get_string(1).to_float(), 0.05, 400.0)
	var duration := seconds
	if duration <= 0.0:
		var over := RegEx.create_from_string("\\bover ([\\d.]+)").search(text)
		duration = over.get_string(1).to_float() if over else (0.8 if verb in ["falls", "drops"] else height / 1.8)
	duration = maxf(duration, 0.2)
	var start := _pos_at(thing, t)
	var drift := Vector3.ZERO
	var toward := text.find("toward")
	if toward >= 0:
		var target_text := text.substr(toward).trim_prefix("towards").trim_prefix("toward").strip_edges()
		var target: Vector3 = _place_of(target_text, {}, t)["pos"]
		var flat := Vector3(target.x - start.x, 0, target.z - start.z)
		var steady_climb := text.contains("steady") or text.contains("straight")
		drift = flat.normalized() * (flat.length() if steady_climb else minf(flat.length(), height * 0.8)) if flat.length() > 0.01 else Vector3.ZERO
	elif not down:
		# Carried a little by the wind.
		var wind := float(builder.environment.get("wind"))
		drift = _dir(float(builder.environment.get("wind_direction"))) * height * 0.15 * clampf(wind * 2.0, 0.2, 1.5)
	var side := Vector3(-drift.z, 0, drift.x).normalized() if drift.length() > 0.01 else Vector3(1, 0, 0)
	# "steady" / "straight": no sway (a plane climbing, a lift).
	var swaying := not (verb in ["falls", "drops"]) and not text.contains("steady") and not text.contains("straight")
	var spin := float(hash(str(thing["display"])) % 100) / 100.0 * TAU
	var base_yaw := _yaw_at(thing, t)
	_key(thing, t, start)
	var steps := maxi(2, int(duration / 0.5))
	for i in range(1, steps + 1):
		var f := float(i) / float(steps)
		var lift: float = (f * f if verb in ["falls", "drops"] else (f * f * (3.0 - 2.0 * f) if down else pow(f, 1.25))) * height
		var p := start + drift * f + Vector3(0, -lift if down else lift, 0)
		if swaying:
			p += side * sin(f * PI * 3.0 + spin) * minf(height * 0.03, 0.6)
		var yaw := base_yaw + (sin(f * PI * 2.0 + spin) * 25.0 if swaying else 0.0)
		_key(thing, t + duration * f, p, Quaternion(Vector3.UP, deg_to_rad(yaw)), not swaying and i < steps - 1)
	(thing["faces"] as Array).append([_snap(t + duration), base_yaw])
	thing["busy"] = t + duration
	_events.append({"t": t, "dur": duration, "kind": "move", "who": str(thing["display"]), "scene": scene})
	return {"dur": duration}

## Progress 0..1 at time fraction [param f] with speed ramping up over the first and
## down over the last [param ramp] of the time, constant in between.
static func _trapezoid(f: float, ramp: float) -> float:
	var v := 1.0 / (1.0 - ramp)  # top speed so the area is 1
	if f < ramp:
		return 0.5 * v * f * f / ramp
	if f > 1.0 - ramp:
		var g := 1.0 - f
		return 1.0 - 0.5 * v * g * g / ramp
	return 0.5 * v * ramp + v * (f - ramp)


## "globe spins 90 over 20s" / "fan spins 720 over 4s" / "globe spins -45": turns an object
## around its upright axis by that many degrees (default 360), smoothly and evenly.
func _spin(thing: Dictionary, after: String, t: float, seconds: float, scene: int) -> Dictionary:
	var degrees := 360.0
	var amount := RegEx.create_from_string("^(-?[\\d.]+)").search(after.strip_edges())
	if amount:
		degrees = amount.get_string(1).to_float()
	var duration := seconds
	if duration <= 0.0:
		var over := RegEx.create_from_string("\\bover ([\\d.]+)").search(after)
		duration = over.get_string(1).to_float() if over else absf(degrees) / 30.0
	duration = maxf(duration, 0.2)
	var start := _pos_at(thing, t)
	var base_yaw := _yaw_at(thing, t)
	var steps := maxi(2, int(maxf(duration / 0.5, absf(degrees) / 20.0)))
	_key(thing, t, start, Quaternion(Vector3.UP, deg_to_rad(base_yaw)), true)
	for i in range(1, steps + 1):
		var f := float(i) / float(steps)
		# Even speed, with a gentle start and stop (a trapezoid speed curve).
		_key(thing, t + duration * f, start, Quaternion(Vector3.UP, deg_to_rad(base_yaw + degrees * _trapezoid(f, 0.12))), true)
	(thing["faces"] as Array).append([_snap(t + duration), base_yaw + degrees])
	thing["yaw"] = base_yaw + degrees
	thing["busy"] = t + duration
	_events.append({"t": t, "dur": duration, "kind": "move", "who": str(thing["display"]), "scene": scene})
	return {"dur": duration}



func _gesture(thing: Dictionary, t: float, action: String, seconds: float, scene: int) -> Dictionary:
	var length := seconds if seconds > 0.0 else float(GESTURE_SECONDS.get(action, 3.0))
	if _sitting_at(thing, t) and action in ["Wave", "Point", "Jump", "Dance", "Cheer"]:
		if action == "Wave" or action == "Point":
			return _pose_gesture(thing, "seated wave" if action == "Wave" else "seated point", t, seconds)
		_warn("%s is sitting, so \"%s\" was skipped (add \"%s stands up\" first)." % [thing["display"], action, thing["display"]])
		return {"dur": 0.0}
	var names := (thing["node"] as CharacterBase).action_names()
	if not names.has(action):
		var close := _best_key(action, Array(names))
		if close.is_empty():
			_warn("%s has no \"%s\" action; skipped." % [thing["display"], action])
			return {"dur": 0.0}
		action = close
	_action(thing, t, action)
	_action(thing, t + length, _base_action(thing))
	_events.append({"t": t, "dur": length, "kind": "gesture", "who": str(thing["display"]), "scene": scene})
	_end = maxf(_end, t + length)
	return {"dur": length}


## Seated characters turn only their head (up to 70° each way).
func _look_with_head(thing: Dictionary, t: float, yaw: float) -> void:
	var delta := clampf(wrapf(yaw - _yaw_at(thing, t), -180.0, 180.0), -70.0, 70.0)
	var before: Dictionary = (thing["pose"] as Dictionary).duplicate()
	var after := before.duplicate()
	var head: Vector3 = before.get("head", Vector3.ZERO)
	after["head"] = Vector3(head.x, delta, head.z)
	_pose_key(thing, t, before)
	_pose_key(thing, t + 0.6, after)
	thing["pose"] = after


func _end_sit(thing: Dictionary, t: float) -> void:
	for span in thing["sits"]:
		var s: Array = span
		if float(s[1]) == INF:
			s[1] = t


## Keeps two characters from standing in exactly the same spot.
func _avoid_others(thing: Dictionary, pos: Vector3, t: float) -> Vector3:
	var out := pos
	# Effects (an aura, sparks, mist) are meant to sit right on someone.
	if thing.get("node") is GlowParticles or thing.get("node") is EffectProp:
		return out
	for key in _things:
		var other: Dictionary = _things[key]
		if is_same(other, thing) or (other.get("kind") != "character" and other.get("kind") != "actor") or bool(other.get("hidden", false)):
			continue
		var there := _pos_at(other, t + 3.0)
		if Vector2(there.x - out.x, there.z - out.z).length() < 0.6:
			var side := Vector3(0.75, 0, 0).rotated(Vector3.UP, deg_to_rad(_yaw_at(other, t)))
			out = _on_ground(out + side)
	if (thing.get("kind") == "character" or thing.get("kind") == "actor") and _written_for_at_least("1.28"):
		out = _out_of_furniture(out)
	return out


## Furniture a person can't stand in: [name, footprint AABB] for every solid prop that
## stands on the floor (tables, counters, beds, sofas, chairs, cabinets...).
func _solid_props() -> Array:
	var out: Array = []
	var seen := {}
	for key in _things:
		var thing: Dictionary = _things[key]
		if thing.get("kind") != "prop" or seen.has(thing) or not (thing.get("node") is Node3D):
			continue
		seen[thing] = true
		if not thing.has("box"):
			thing["box"] = PropUtils.world_aabb(thing["node"] as Node3D)
		var box: AABB = thing["box"]
		var kind_name := str(thing.get("kind_name", "")).to_lower()
		if box.size.y < 0.35 or box.size.y > 2.6 or box.position.y > 0.3 + _offset.y or maxf(box.size.x, box.size.z) > 4.0:
			continue
		if kind_name.contains("rug") or kind_name.contains("door") or kind_name.contains("window") or kind_name.contains("lamp") or kind_name.contains("light"):
			continue
		out.append(box)
	return out


## Moves a standing spot out of any furniture it falls inside, to the nearest clear
## floor beside it (people were ending up inside tables and counters).
func _out_of_furniture(pos: Vector3, skip: AABB = AABB()) -> Vector3:
	var out := pos
	var boxes := _solid_props()
	for round in 3:
		var moved := false
		for found in boxes:
			var box: AABB = found
			if box.is_equal_approx(skip):
				continue
			var grown := box.grow(0.18)
			if out.x <= grown.position.x or out.x >= grown.end.x or out.z <= grown.position.z or out.z >= grown.end.z:
				continue
			var exits := [Vector3(grown.position.x - 0.02, out.y, out.z), Vector3(grown.end.x + 0.02, out.y, out.z),
				Vector3(out.x, out.y, grown.position.z - 0.02), Vector3(out.x, out.y, grown.end.z + 0.02)]
			exits.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(out) < b.distance_to(out))
			out = exits[0]
			moved = true
		if not moved:
			break
	return out if out.distance_to(pos) < 2.5 else pos


func _busy_end_after(start: float) -> float:
	var end := start
	for key in _things:
		var thing: Dictionary = _things[key]
		end = maxf(end, float(thing.get("busy", 0.0)))
		if thing.get("kind") == "character" or thing.get("kind") == "actor":
			var track: Array = thing.get("track", [])
			if not track.is_empty():
				end = maxf(end, float((track[track.size() - 1] as Array)[0]))  # e.g. settling into a seat
	return end


# --- Carrying ------------------------------------------------------------------------

const CARRY_POSE := {"shoulder_l": Vector3(-55, 0, -12), "elbow_l": Vector3(-70, 0, 0), "shoulder_r": Vector3(-55, 0, 12), "elbow_r": Vector3(-70, 0, 0)}
## Holding an umbrella: the right arm forward and up, the hand at shoulder height.
const UMBRELLA_POSE := {"shoulder_r": Vector3(-62, 0, 4), "elbow_r": Vector3(-58, 0, 0)}
## Playing a guitar: the left hand out along the neck, the right arm across the body.
## A selfie: the right arm reaching forward and up.
const SELFIE_POSE := {"shoulder_r": Vector3(-120, 0, -8), "elbow_r": Vector3(-12, 0, 0)}
const GUITAR_TILT := 28.0   # degrees the neck rises above level
const GUITAR_POSE := {"shoulder_l": Vector3(-15, 0, 58), "elbow_l": Vector3(-8, 0, 0), "shoulder_r": Vector3(10, 0, 20), "elbow_r": Vector3(-35, 0, 0)}
const HIGH_POSE := {"shoulder_l": Vector3(-165, 0, 12), "elbow_l": Vector3(-12, 0, 0), "shoulder_r": Vector3(-165, 0, -12), "elbow_r": Vector3(-12, 0, 0)}


## Where a carried object is: in front of the chest, or held up above the head.
func _hand_pos(carrier: Dictionary, item: Dictionary, t: float, mode: String) -> Vector3:
	var feet := _pos_at(carrier, t)
	var h := float(carrier.get("height", 1.75))
	var front := _dir(_yaw_at(carrier, t))
	var size := float(item.get("height", 0.3))
	if mode == "high":
		return feet + Vector3(0, h * 1.02, 0) + front * 0.1
	if mode == "selfie":
		var right := front.cross(Vector3.UP)
		return feet + Vector3(0, h * (0.62 if _sitting_at(carrier, t) else 0.86), 0) + front * 0.42 + right * 0.12
	if mode == "guitar":
		# The model's origin is the bottom of its body, the neck pointing up its local y:
		# held, the body sits at the belly and the neck rises towards the left hand.
		var body := feet + Vector3(0, h * (0.36 if _sitting_at(carrier, t) else 0.5), 0) + front * 0.16
		var neck := (Vector3.UP.cross(front) * cos(deg_to_rad(GUITAR_TILT)) + Vector3.UP * sin(deg_to_rad(GUITAR_TILT))).normalized()
		return body - neck * 0.2
	if mode == "umbrella":
		# The umbrella's origin is its grip: in the right hand, a little in front.
		var right := front.cross(Vector3.UP)
		var grip := feet + Vector3(0, h * (0.43 if _sitting_at(carrier, t) else 0.6), 0) + front * 0.24 + right * 0.16
		var span := _carrying(item)
		var over: Dictionary = span.get("over", {}) if not span.is_empty() else {}
		if not over.is_empty():
			# Held out over someone else: most of the way towards them.
			var there := _pos_at(over, t)
			grip = grip.lerp(Vector3(there.x, grip.y, there.z), 0.38)
		return grip
	var chest := h * (0.42 if _sitting_at(carrier, t) else 0.6)
	return feet + Vector3(0, chest - size * 0.45, 0) + front * (0.3 + float(item.get("depth", 0.15)) * 0.6)


func _carrying(item: Dictionary) -> Dictionary:
	for span in item.get("carry", []):
		if float((span as Dictionary)["end"]) == INF:
			return span
	return {}


func _start_carry(carrier: Dictionary, item: Dictionary, t: float, mode: String, over: Dictionary = {}) -> void:
	var open := _carrying(item)
	if not open.is_empty():
		_end_carry(item, t)
	if not item.has("carry"):
		item["carry"] = []
	_key(item, t, _pos_at(item, t))  # (not a frame earlier: that frame may hold its "hidden" key)
	(item["carry"] as Array).append({"carrier": carrier, "start": t + 0.4, "end": INF, "mode": mode, "over": over})
	var pose: Dictionary = carrier["pose"]
	_pose_key(carrier, t, pose)
	var holding := (HIGH_POSE if mode == "high" else (UMBRELLA_POSE if mode == "umbrella" else (GUITAR_POSE if mode == "guitar" else (SELFIE_POSE if mode == "selfie" else CARRY_POSE)))).duplicate()
	var merged := pose.duplicate()
	for joint in holding:
		merged[joint] = holding[joint]
	_pose_key(carrier, t + 0.4, merged)
	carrier["pose_before_carry"] = pose
	carrier["pose"] = merged


## Ends the open carry of [param item] at [param t], keying its path while carried.
func _end_carry(item: Dictionary, t: float) -> void:
	var span := _carrying(item)
	if span.is_empty():
		return
	var start := float(span["start"])
	var k := start
	while k < t:
		_key_carried(item, k)
		k += 0.2
	_key_carried(item, t)
	span["end"] = t + 0.001
	var carrier: Dictionary = span["carrier"]
	var before: Dictionary = carrier.get("pose_before_carry", {})
	_pose_key(carrier, t, carrier["pose"])
	_pose_key(carrier, t + 0.4, before)
	carrier["pose"] = before


func _key_carried(item: Dictionary, k: float) -> void:
	var span := _carrying(item)
	var carrier: Dictionary = span["carrier"] if not span.is_empty() else {}
	var p := _pos_at(item, k)
	var yaw := _yaw_at(carrier, k) if not carrier.is_empty() else _yaw_at(item, k)
	var turn := Quaternion(Vector3.UP, deg_to_rad(yaw))
	if not span.is_empty() and str(span["mode"]) == "selfie":
		turn = Quaternion(Vector3.UP, deg_to_rad(yaw + 180.0))
	if not span.is_empty() and str(span["mode"]) == "guitar":
		# Across the body, the neck rising towards the player's left hand.
		turn = turn * Quaternion(Vector3.BACK, deg_to_rad(GUITAR_TILT - 90.0))
	_key(item, k, p, turn)


## "Asha plays guitar for 4s": holds the guitar across her body and strums.
## She keeps holding it afterwards ("puts down guitar" when she's done).
func _play_line(thing: Dictionary, text: String, seconds: float, t: float, scene: int) -> Dictionary:
	var item := _thing(text)
	var start := t
	var open := _carrying(item)
	if open.is_empty() or not is_same(open["carrier"], thing) or str(open["mode"]) != "guitar":
		if not open.is_empty():
			_end_carry(item, t)
		var here := _pos_at(thing, t)
		var there := _pos_at(item, t)
		if open.is_empty() and Vector2(there.x - here.x, there.z - here.z).length() > 1.0:
			_action(thing, t, MotionLibrary.AUTO)
			var stop := there + Vector3(here.x - there.x, 0, here.z - there.z).normalized() * (float(item.get("radius", 0.3)) + 0.4)
			t += _walk(thing, t, [_on_ground(stop)], 1.3)
		_start_carry(thing, item, t, "guitar")
		t += 0.5
	# Strumming: the right forearm swings down and up, four strokes a second.
	var base: Dictionary = (thing["pose"] as Dictionary).duplicate()
	var k := t
	var stroke := 0
	while k < t + seconds:
		var pose := base.duplicate()
		var down := stroke % 2 == 0
		pose["elbow_r"] = Vector3(-22 if down else -48, 0, 0)
		pose["shoulder_r"] = Vector3(14 if down else 6, 0, 20)
		_pose_key(thing, k, pose)
		k += 0.25 if stroke % 4 != 3 else 0.3
		stroke += 1
	_pose_key(thing, t + seconds, base)
	thing["pose"] = base
	_events.append({"t": start, "dur": t + seconds - start, "kind": "gesture", "who": str(thing["display"]), "scene": scene})
	return {"dur": t + seconds - start}


## "picks up lantern", "holds lantern high", "puts down lantern on table",
## "gives lantern to Ram", "lets go of lantern".
func _carry_line(thing: Dictionary, verb: String, after: String, t: float, scene: int) -> Dictionary:
	var name := str(thing["display"])
	var text := after
	for prefix in ["up ", "down ", "go of ", "out "]:
		if text.begins_with(prefix):
			text = text.substr(prefix.length())
	var to := ""
	var over_text := ""
	var over_cut := text.find(" over ")
	if over_cut > 0:
		over_text = text.substr(over_cut + 6).strip_edges()
		text = text.substr(0, over_cut).strip_edges()
	for joiner in [" to ", " on ", " onto ", " at ", " in "]:
		var cut := text.find(joiner)
		if cut > 0:
			to = text.substr(cut + 1).strip_edges()
			text = text.substr(0, cut).strip_edges()
			break
	var high := text.ends_with(" high") or text.ends_with(" up") or after.begins_with("up ") and verb in ["holds", "raises", "lifts"] or verb == "raises"
	text = text.trim_suffix(" high").trim_suffix(" up").strip_edges()
	var item := _thing(text)
	if item.is_empty() or item.get("kind") != "prop":
		return {"error": "%s can only carry objects from the SET (\"%s\" isn't one)" % [name, text]}
	var start := t
	# Umbrellas are held up in one hand (and can be held out over someone: "holds umbrella over Mira").
	var node_name := (str((item["node"] as Node).name) + " " + str((item["node"] as Node).get_meta(PropUtils.META_SCENE_PATH, ""))).to_lower() if item.get("node") is Node else ""
	var umbrella := text.to_lower().contains("umbrella") or node_name.contains("umbrella")
	var over: Dictionary = {}
	if not over_text.is_empty():
		over = _thing(over_text)
		if over.is_empty() or over.get("kind") != "character":
			return {"error": "hold it over whom? e.g. \"%s holds umbrella over Mira\"" % name}
	var hold_mode := "umbrella" if umbrella else ("high" if high else "hold")
	# A phone held up is a selfie: one arm out in front and up, the screen facing her.
	if high and (text.to_lower().contains("phone") or node_name.contains("phone")):
		hold_mode = "selfie"
	if verb in ["picks", "pick", "takes", "grabs", "carries", "holds", "raises", "lifts", "collects"]:
		var open := _carrying(item)
		if open.is_empty() or not is_same(open["carrier"], thing):
			var here := _pos_at(thing, t)
			var there := _pos_at(item, t)
			if Vector2(there.x - here.x, there.z - here.z).length() > 1.0 and open.is_empty():
				_action(thing, t, MotionLibrary.AUTO)
				var stop := there + Vector3(here.x - there.x, 0, here.z - there.z).normalized() * (float(item.get("radius", 0.3)) + 0.4)
				t += _walk(thing, t, [_on_ground(stop)], 1.3)
			_face(thing, t, _yaw_towards(_pos_at(thing, t), there))
			_start_carry(thing, item, t, hold_mode, over)
		else:
			# Already holding it: switch between chest and high (or over someone).
			_end_carry(item, t)
			_start_carry(thing, item, t, hold_mode, over)
		_events.append({"t": start, "dur": t - start + 0.6, "kind": "gesture", "who": name, "scene": scene})
		return {"dur": t - start + 0.6}
	var open := _carrying(item)
	if open.is_empty() or not is_same(open["carrier"], thing):
		return {"error": "%s isn't holding %s" % [name, text]}
	if verb in ["gives", "hands", "passes", "offers"]:
		var other := _thing(to)
		if other.is_empty() or other.get("kind") != "character":
			return {"error": "give it to whom? e.g. \"%s gives %s to Ram\"" % [name, text]}
		var here := _pos_at(thing, t)
		var there := _pos_at(other, t)
		if Vector2(there.x - here.x, there.z - here.z).length() > 1.1:
			var stop := there + Vector3(here.x - there.x, 0, here.z - there.z).normalized() * 0.8
			t += _walk(thing, t, [_on_ground(stop)], 1.3)
		_face(thing, t, _yaw_towards(_pos_at(thing, t), there))
		_face(other, t, _yaw_towards(there, _pos_at(thing, t)))
		_end_carry(item, t + 0.6)
		_start_carry(other, item, t + 0.6, "umbrella" if umbrella else "hold")
		return {"dur": t - start + 1.2}
	# Putting it down, or letting go where it is.
	var letting_go := verb in ["lets", "releases", "frees"]
	var drop := _pos_at(item, t)
	if not letting_go:
		if to.begins_with("at "):
			# "puts down guitar at (0.5, -0.6)": back in its corner (walking over if it's far).
			var spot: Vector3 = _place_of(to.substr(3), thing, t)["pos"]
			var here := _pos_at(thing, t)
			if Vector2(spot.x - here.x, spot.z - here.z).length() > 1.3:
				var stop := spot + Vector3(here.x - spot.x, 0, here.z - spot.z).normalized() * 0.7
				t += _walk(thing, t, [_on_ground(stop)], 1.3)
			_face(thing, t, _yaw_towards(_pos_at(thing, t), spot))
			drop = Vector3(spot.x, here.y, spot.z)
			if item.get("node") is Node3D:
				# Over a desk or table: on top of it.
				var lifted := _onto_furniture(item["node"] as Node3D, Vector3(spot.x, 0.0, spot.z))
				if lifted.y > 0.01:
					drop = lifted
		elif not to.is_empty():
			var surface := _thing(to)
			if surface.is_empty():
				return {"error": "can't find \"%s\" to put it on" % to}
			var base := _pos_at(surface, t)
			var top := base.y
			if surface.get("node") is Node3D and surface.get("kind") == "prop":
				top = PropUtils.world_aabb(surface["node"] as Node3D).end.y
			var here := _pos_at(thing, t)
			if Vector2(base.x - here.x, base.z - here.z).length() > 1.2:
				var stop := base + Vector3(here.x - base.x, 0, here.z - base.z).normalized() * (float(surface.get("radius", 0.4)) * 0.8 + 0.45)
				t += _walk(thing, t, [_on_ground(stop)], 1.3)
			drop = Vector3(base.x, top, base.z)
		else:
			var feet := _pos_at(thing, t)
			drop = _on_ground(feet + _dir(_yaw_at(thing, t)) * 0.55) if not _indoor() else feet + _dir(_yaw_at(thing, t)) * 0.55
	_end_carry(item, t + 0.4)
	_key(item, t + 0.8, drop, Quaternion.IDENTITY if to.begins_with("at ") else Quaternion(Vector3.UP, deg_to_rad(_yaw_at(thing, t))))
	return {"dur": t - start + 0.9}


# --- Poses ---------------------------------------------------------------------------

## Changes a sketch character's expression at [param t] (kept with the hand pose keys).
func _set_face(thing: Dictionary, t: float, mood: String) -> void:
	var current: Dictionary = (thing["pose"] as Dictionary).duplicate()
	if t > FRAME:
		_pose_key(thing, t - FRAME, current)
	current["face"] = Vector3(SketchCharacter.EXPRESSIONS.find(mood), 0, 0)
	_pose_key(thing, t, current)
	thing["pose"] = current


func _pose_key(thing: Dictionary, t: float, pose: Dictionary) -> void:
	var stored := {}
	for joint in pose:
		var v: Vector3 = pose[joint]
		stored[joint] = [v.x, v.y, v.z]
	builder.timeline.store.set_key(_uid(thing), TimelineController.CH_POSE, _snap(t), {"pose": stored}, false)
	_end = maxf(_end, t)


## "poses right shoulder -90 0 0, right elbow -40 0 0 over 1s"   /   "relaxes over 1s"
func _pose_line(thing: Dictionary, rest: String, t: float, seconds: float) -> Dictionary:
	var over := 0.6
	var over_match := RegEx.create_from_string("\\bover ([\\d.]+)\\s*(s|sec|secs|second|seconds)?\\b").search(rest)
	if over_match:
		over = maxf(over_match.get_string(1).to_float(), FRAME)
		rest = (rest.substr(0, over_match.get_start()) + rest.substr(over_match.get_end())).strip_edges()
	var current: Dictionary = (thing["pose"] as Dictionary).duplicate()
	_pose_key(thing, t, current)
	var target := current.duplicate()
	if rest.begins_with("relaxes") or rest.begins_with("resets"):
		target = {}
		if current.has("face"):
			target["face"] = current["face"]   # the expression stays
	else:
		var body := rest
		for prefix in ["poses ", "pose ", "holds "]:
			body = body.trim_prefix(prefix)
		for part in body.split(","):
			var words := part.strip_edges().replace("(", " ").replace(")", " ").split(" ", false)
			if words.size() < 2:
				continue
			var numbers: Array[float] = []
			var name_words: PackedStringArray = []
			for w in words:
				if str(w).is_valid_float():
					numbers.append(str(w).to_float())
				else:
					name_words.append(str(w))
			var joint := " ".join(name_words).replace(" ", "_")
			joint = str(JOINT_WORDS.get(" ".join(name_words), joint))
			if not MotionLibrary.JOINTS.has(joint):
				_warn("%s: unknown joint \"%s\" (joints: %s)." % [thing["display"], " ".join(name_words), ", ".join(MotionLibrary.JOINTS)])
				continue
			while numbers.size() < 3:
				numbers.append(0.0)
			target[joint] = Vector3(numbers[0], numbers[1], numbers[2])
	_pose_key(thing, t + over, target)
	thing["pose"] = target
	return {"dur": over + maxf(seconds, 0.0)}


func _pose_gesture(thing: Dictionary, gesture: String, t: float, seconds: float) -> Dictionary:
	var base: Dictionary = thing["pose"]
	var keys: Array = []   # [time offset, { joint: Vector3 delta }]
	match gesture:
		"gasps":
			var gasp := {"head": Vector3(-14, 0, 0), "chest": Vector3(-6, 0, 0), "shoulder_l": Vector3(-40, 0, 20), "shoulder_r": Vector3(-40, 0, -20),
				"elbow_l": Vector3(-110, 0, 0), "elbow_r": Vector3(-110, 0, 0)}
			keys = [[0.0, {}], [0.2, gasp], [1.3, gasp], [1.8, {}]]
		"facepalms":
			var palm := {"shoulder_r": Vector3(-95, 0, 22), "elbow_r": Vector3(-135, 0, 0), "head": Vector3(22, 0, 0), "neck": Vector3(8, 0, 0)}
			keys = [[0.0, {}], [0.45, palm], [2.0, palm], [2.5, {}]]
		"scratches head":
			var scratch := {"shoulder_r": Vector3(-150, 0, -30), "elbow_r": Vector3(-120, 0, 0), "head": Vector3(6, 0, -10)}
			keys = [[0.0, {}], [0.5, scratch]]
			for i in 4:
				keys.append([0.7 + float(i) * 0.25, {"shoulder_r": Vector3(-150 if i % 2 == 0 else -140, 0, -30), "elbow_r": Vector3(-120, 0, 0), "head": Vector3(6, 0, -10)}])
			keys.append([2.0, scratch])
			keys.append([2.4, {}])
		"sleeps":
			var nap := {"head": Vector3(32, 0, 12), "neck": Vector3(12, 0, 0), "chest": Vector3(4, 0, 0)}
			keys = [[0.0, {}], [1.5, nap]]
			thing["pose"] = _merge_pose(base, nap)
		"wakes up":
			# From the sleeping pose (or whatever it was) back to neutral, with a startled jolt.
			keys = [[0.0, base.duplicate()], [0.25, {"head": Vector3(-12, 0, 0), "shoulder_l": Vector3(0, 0, 25), "shoulder_r": Vector3(0, 0, -25)}], [0.9, {}]]
			base = {}
			thing["pose"] = {}
		"laughs", "giggles":
			keys = [[0.0, {}]]
			for i in 6:
				var up := i % 2 == 0
				keys.append([0.2 + float(i) * 0.22, {"head": Vector3(-14 if up else -6, 0, 0), "chest": Vector3(-5 if up else 2, 0, 0),
					"shoulder_l": Vector3(0, 0, 6 if up else 2), "shoulder_r": Vector3(0, 0, -6 if up else -2)}])
			keys.append([1.8, {}])
		"nods":
			keys = [[0.0, {}], [0.25, {"head": Vector3(18, 0, 0)}], [0.5, {"head": Vector3(2, 0, 0)}], [0.75, {"head": Vector3(16, 0, 0)}], [1.1, {}]]
		"shakes head":
			keys = [[0.0, {}], [0.25, {"head": Vector3(0, 25, 0)}], [0.55, {"head": Vector3(0, -25, 0)}], [0.85, {"head": Vector3(0, 20, 0)}], [1.2, {}]]
		"bows":
			var bow := {"spine": Vector3(25, 0, 0), "chest": Vector3(20, 0, 0), "head": Vector3(10, 0, 0)}
			keys = [[0.0, {}], [0.7, bow], [1.4, bow], [2.1, {}]]
		"shrugs":
			var shrug := {"shoulder_l": Vector3(0, 0, 12), "shoulder_r": Vector3(0, 0, -12), "elbow_l": Vector3(-70, 0, 0), "elbow_r": Vector3(-70, 0, 0), "head": Vector3(0, 0, 8)}
			keys = [[0.0, {}], [0.4, shrug], [1.1, shrug], [1.6, {}]]
		"seated point":
			var aim := {"shoulder_r": Vector3(-80, 0, 0), "elbow_r": Vector3(-5, 0, 0)}
			keys = [[0.0, {}], [0.5, aim], [2.0, aim], [2.5, {}]]
		"seated wave":
			keys = [[0.0, {}]]
			var up := {"shoulder_r": Vector3(-150, 0, -15), "elbow_r": Vector3(-25, 0, 0)}
			keys.append([0.5, up])
			for i in 4:
				keys.append([0.8 + float(i) * 0.3, {"shoulder_r": Vector3(-150, 0, -15), "elbow_r": Vector3(-25 if i % 2 == 0 else -55, 0, 0)}])
			keys.append([2.2, up])
			keys.append([2.7, {}])
		_:
			var raise := {"shoulder_r": Vector3(-165, 0, 0), "elbow_r": Vector3(-10, 0, 0)}
			keys = [[0.0, {}], [0.6, raise], [1.8, raise], [2.4, {}]]
	var scale := 1.0
	var natural := float((keys[keys.size() - 1] as Array)[0])
	if seconds > 0.0 and natural > 0.0:
		scale = seconds / natural
	for entry in keys:
		var e: Array = entry
		var pose := base.duplicate()
		var delta: Dictionary = e[1]
		for joint in delta:
			var add: Vector3 = delta[joint]
			pose[joint] = (base.get(joint, Vector3.ZERO) as Vector3) + add
		_pose_key(thing, t + float(e[0]) * scale, pose)
	return {"dur": natural * scale}


static func _merge_pose(base: Dictionary, delta: Dictionary) -> Dictionary:
	var out := base.duplicate()
	for joint in delta:
		out[joint] = (base.get(joint, Vector3.ZERO) as Vector3) + (delta[joint] as Vector3)
	return out


static func _speech_envelope(seconds: float) -> PackedFloat32Array:
	var env := PackedFloat32Array()
	var frames := int(seconds * 30.0)
	for i in frames:
		var t := float(i) / 30.0
		var syllable := maxf(0.0, sin(t * 11.0 + sin(t * 3.1) * 2.0))
		var phrase := smoothstep(0.0, 0.15, t) * smoothstep(seconds, seconds - 0.25, t) * (0.6 + 0.4 * sin(t * 1.7))
		env.append(clampf(syllable * phrase, 0.0, 1.0))
	return env


# --- Sound -------------------------------------------------------------------------------

## "audio/theme.ogg, volume -6, voice Deeper"  (MUSIC or SOUND). Returns the clip.
func _add_sound(spec: String, t: float, music: bool) -> Dictionary:
	if builder.audio == null:
		return {}
	var parts := spec.split(",")
	var file := str(parts[0]).strip_edges().trim_prefix("\"").trim_suffix("\"")
	if file.is_empty():
		return {}
	var volume := -6.0 if music else 0.0
	var voice := "Normal"
	for i in range(1, parts.size()):
		var words := str(parts[i]).strip_edges().split(" ", false)
		if words.size() < 2:
			continue
		match str(words[0]).to_lower():
			"volume", "vol":
				volume = str(words[1]).to_float()
			"voice", "effect":
				var v := _best_key(" ".join(words.slice(1)), AudioTrack.VOICES.keys())
				voice = v if not v.is_empty() else "Normal"
			"at", "start":
				t = _seconds(str(words[1]), t)
	var source := _audio_source(file)
	if source.is_empty():
		_missing("sound \"%s\"" % file)
		return {}
	var clip := builder.audio.import_file(source, t)
	if clip.is_empty():
		_missing("sound \"%s\" (couldn't read it)" % file)
		return {}
	clip["volume_db"] = volume
	clip["voice"] = voice
	if file.to_lower().contains("theme") or source == TemplateBuilder.THEME_MUSIC:
		clip["name"] = "The Lantern (theme)" if source == TemplateBuilder.THEME_MUSIC else clip["name"]
	_clips.append(clip)
	_end = maxf(_end, t + (0.0 if music else builder.audio.clip_length(clip)))
	return clip


func _audio_source(file: String) -> String:
	var lower := file.to_lower()
	if lower in ["theme", "lantern theme", "the lantern theme", "built-in theme", "the lantern"]:
		return TemplateBuilder.THEME_MUSIC
	var found := _package_file(file)
	if not found.is_empty():
		return found
	for folder in [AudioTrack.AUDIO_DIR, "res://assets/audio/"]:
		var path := str(folder).path_join(file.get_file())
		if FileAccess.file_exists(path):
			return path
		for extension in AudioTrack.EXTENSIONS:
			var with_ext := str(folder).path_join(file.get_file() + "." + extension)
			if FileAccess.file_exists(with_ext):
				return with_ext
	return ""


# --- Cameras -------------------------------------------------------------------------------

## Where a script holds one shot for more than 9 s while things happen, adds
## automatic coverage inside that stretch.
func _fill_long_shots(scene: int, start: float, end: float) -> void:
	var explicit: Array = []
	for shot in _shots:
		if int(shot["scene"]) == scene and not bool(shot["auto"]):
			explicit.append(shot)
	explicit.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	var first := end if explicit.is_empty() else float((explicit[0] as Dictionary)["t"])
	if first - start > 4.0:
		# The scene starts on the previous scene's last shot: give it its own coverage.
		_auto_coverage(scene, start, first)
	for i in explicit.size():
		var from := float((explicit[i] as Dictionary)["t"])
		var to := end if i == explicit.size() - 1 else float((explicit[i + 1] as Dictionary)["t"])
		if to - from > 9.0:
			_auto_coverage(scene, from + 3.0, to, false, _norm(str((explicit[i] as Dictionary)["spec"])))


func _auto_coverage(scene: int, start: float, end: float, opener_shot: bool = true, running_spec: String = "") -> void:
	var events: Array = []
	for event in _events:
		if int(event["scene"]) != scene:
			continue
		var at := float(event["t"])
		if at >= start - 0.01 and at < end:
			events.append(event)
		elif not opener_shot and str(event["kind"]) == "move" and at < start and at + float(event["dur"]) > start + 3.0:
			# A walk already under way when the gap begins.
			var ongoing: Dictionary = event.duplicate()
			ongoing["t"] = start
			ongoing["dur"] = at + float(event["dur"]) - start
			events.append(ongoing)
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	var people: PackedStringArray = []
	for event in events:
		if not people.has(str(event["who"])):
			people.append(str(event["who"]))
	var opener := "establishing, crane down" if scene == 0 else ("wide on %s, dolly in" % " and ".join(people) if not people.is_empty() else "establishing")
	var opening_index := _shots.size()
	if opener_shot:
		_shots.append({"t": start, "spec": opener, "scene": scene, "auto": true})
	var last_cut := start if opener_shot else start - 10.0
	var count := 0
	for event in events:
		var t := float(event["t"])
		if t > end - 1.6:
			break
		var replaces_opener := opener_shot and count == 0 and t - start < 1.6 and scene > 0
		if t - last_cut < 1.6 and not replaces_opener:
			continue
		var who := str(event["who"])
		var spec := ""
		match str(event["kind"]):
			"line":
				var to := str(event.get("to", ""))
				if not to.is_empty():
					match count % 3:
						0:
							spec = "two-shot %s and %s" % [who, to]
						1:
							spec = "over-shoulder %s to %s" % [to, who]
						_:
							spec = "close-up on %s, dolly in" % who
				else:
					spec = "medium on %s" % who if count % 2 == 0 else "close-up on %s, dolly in" % who
			"move":
				if float(event["dur"]) < 2.5:
					continue
				spec = "follow %s" % who if float(event["dur"]) >= 4.0 else "full on %s, pan left" % who
			"gesture":
				spec = "medium on %s" % who
		if spec.is_empty() or _norm(spec) == running_spec:
			continue
		if replaces_opener:
			_shots[opening_index] = {"t": start, "spec": spec, "scene": scene, "auto": true}
		else:
			_shots.append({"t": t, "spec": spec, "scene": scene, "auto": true})
		last_cut = t
		count += 1


func _make_shots(length: float) -> void:
	_shots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	if _shots.is_empty() or float((_shots[0] as Dictionary)["t"]) > 0.05:
		_shots.insert(0, {"t": 0.0, "spec": "establishing", "scene": 0, "auto": true})
	for i in _shots.size():
		var shot: Dictionary = _shots[i]
		var t := float(shot["t"])
		var until := length if i == _shots.size() - 1 else float((_shots[i + 1] as Dictionary)["t"])
		if until - t < 0.2:
			continue
		_use_set(int(shot.get("set", _scene_set.get(int(shot.get("scene", 0)), 0))))
		var cam := _shot_camera(str(shot["spec"]), t, until - t, i)
		if cam == null:
			continue
		if i == 0:
			builder.director.set_default_camera(cam)
		builder.timeline.store.set_cut(_snap(t), cam.uid(), false)
		_shot_count += 1


func _shot_camera(spec: String, t: float, seconds: float, index: int) -> CinematicCamera:
	var lower := _norm(spec)
	var subjects: Array = []
	var positions: Array = []
	for pair in _names:
		var key := str(pair[0])
		var thing: Dictionary = pair[1]
		if thing.get("kind") == "mark" and not lower.contains(" at " + key) and not lower.ends_with(" " + key):
			continue
		var at := (" " + lower + " ").find(" " + key + " ")
		if at >= 0 and not subjects.has(thing):
			var overlap := false
			for p in positions:
				if at >= int(p[0]) and at < int(p[1]):
					overlap = true
			if overlap:
				continue
			positions.append([at, at + key.length()])
			subjects.append([at, thing])
	subjects.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var who: Array = []
	for s in subjects:
		who.append(s[1])
	var move := ""
	for name in TimelineController.CAMERA_MOVES:
		if lower.contains(str(name).to_lower()):
			move = str(name)
	var synonyms := {"push in": "Dolly in", "slow push": "Dolly in", "pull back": "Dolly out", "pull out": "Dolly out",
		"orbit": "Orbit left", "circle": "Orbit left", "rise": "Crane up", "rising": "Crane up", "descend": "Crane down",
		"zoom": "Zoom in", "pan": "Pan left", "track": "Truck right"}
	if move.is_empty():
		for word in synonyms:
			if lower.contains(str(word)):
				move = str(synonyms[word])
				break
	if lower.contains("static") or lower.contains("locked"):
		move = ""
	var placed := RegEx.create_from_string("(?i)camera at\\s*\\(\\s*(-?[\\d.]+)\\s*,\\s*(-?[\\d.]+)\\s*,\\s*(-?[\\d.]+)\\s*\\)").search(spec)
	if placed:
		# A hand-placed camera wins in every look (also on the Sketch Stage).
		return _placed_shot(spec, lower, placed, who, move, t, seconds, index)
	if _flat:
		return _flat_shot(lower, spec, who, move, t, seconds, index)
	var side := 22.0 if index % 2 == 0 else -22.0
	if lower.contains("from left") or lower.contains("from the left"):
		side = 60.0
	elif lower.contains("from right") or lower.contains("from the right"):
		side = -60.0
	elif lower.contains("from behind") or lower.contains("from the back"):
		side = 180.0
	elif lower.contains("from front") or lower.contains("from the front"):
		side = 0.0
	elif lower.contains("from the side") or lower.contains("from side"):
		side = 90.0
	var dof := lower.contains("dof") or lower.contains("depth of field") or lower.contains("blur")
	var handheld := lower.contains("handheld") or lower.contains("shaky")

	var eye := Vector3.ZERO
	var target := Vector3.ZERO
	var fov := 40.0
	var label := spec.left(40)
	var follow: Dictionary = {}
	if lower.begins_with("follow") or lower.begins_with("tracking") or lower.contains(" follows"):
		if who.is_empty():
			return null
		follow = who[0]
		var a := _pos_at(follow, t)
		var b := _pos_at(follow, t + seconds)
		var m := Vector3(b.x - a.x, 0, b.z - a.z)
		if m.length() < 1.0:
			m = _dir(_yaw_at(follow, t))
		m = m.normalized()
		follow["_dir"] = m
		follow["_side"] = Vector3(-m.z, 0, m.x) * (1.0 if index % 2 == 0 else -1.0)
		var f := _follow_frame(follow, t)
		eye = f[0]
		target = f[1]
		fov = 40.0
	elif (lower.contains("over shoulder") or lower.contains("over the shoulder") or lower.begins_with("ots")) and who.size() >= 2:
		var ha := _head(who[0], t)
		var hb := _head(who[1], t)
		var d := Vector3(hb.x - ha.x, 0, hb.z - ha.z).normalized()
		var right := Vector3(-d.z, 0, d.x)
		eye = ha - d * 0.9 + right * 0.42 + Vector3(0, 0.08, 0)
		target = hb
		fov = 32.0
		dof = true
	elif lower.begins_with("pov") and who.size() >= 2:
		var ha := _head(who[0], t)
		var hb := _head(who[1], t)
		eye = ha + (hb - ha).normalized() * 0.15
		target = hb
		fov = 50.0
	elif (lower.contains("two shot") or lower.contains("2 shot")) and who.size() >= 2:
		var ha := _head(who[0], t)
		var hb := _head(who[1], t)
		var mid := (ha + hb) * 0.5
		var axis := Vector3(hb.x - ha.x, 0, hb.z - ha.z)
		var n := Vector3.UP.cross(axis).normalized()
		if n.length() < 0.5:
			n = Vector3(0, 0, 1)
		var facing := _dir(_yaw_at(who[0], t)) + _dir(_yaw_at(who[1], t))
		if facing.dot(n) < -0.05:
			n = -n
		elif absf(facing.dot(n)) <= 0.05 and index % 2 == 1:
			n = -n
		var flat_facing := Vector3(facing.x, 0, facing.z)
		if flat_facing.length() > 0.5:
			n = (n + flat_facing.normalized() * 0.9).normalized()  # lean towards their faces
		if absf(side) >= 179.0:
			n = -n  # "from behind": see what they see
		var dist := maxf(3.0, axis.length() * 1.2 + 2.0)
		eye = mid + n * dist + Vector3(0, 0.1, 0)
		if _sitting_at(who[0], t) or _sitting_at(who[1], t):
			# Seated people: film from standing height, looking slightly down over the furniture.
			dist = maxf(2.4, axis.length() * 1.1 + 1.6)
			eye = mid + n * dist + Vector3(0, 0.75, 0)
		var flipped := mid - n * dist + Vector3(0, eye.y - mid.y, 0)
		if _view_blocked(eye, mid, who, t) and not _view_blocked(flipped, mid, who, t):
			eye = flipped
		elif _indoor():
			# Indoors, film from the side of the pair with more room behind the camera.
			var room_here: float = (_fit_camera(eye, mid, 40.0)[0] as Vector3).distance_to(mid)
			var room_there: float = (_fit_camera(flipped, mid, 40.0)[0] as Vector3).distance_to(mid)
			if room_here < dist * 0.75 and room_there > room_here + 0.5 and not _view_blocked(flipped, mid, who, t):
				eye = flipped
		target = mid - Vector3(0, 0.15, 0)
		fov = 40.0
	elif lower.begins_with("establishing") or lower.begins_with("overview") or (who.is_empty() and (lower.begins_with("wide") or lower.is_empty() or lower.begins_with("aerial"))):
		var o: Array = _overview()
		eye = Vector3(o[0], o[1], o[2])
		target = Vector3(o[3], o[4], o[5])
		if not _indoor():
			eye.y += _ground(eye.x, eye.z)
			target.y += _ground(target.x, target.z)
		if lower.begins_with("aerial"):
			var centre := _cast_centre(t)
			var away := Vector3(eye.x - centre.x, 0, eye.z - centre.z).normalized()
			target = centre + Vector3(0, 1.0, 0)
			eye = centre + away * 16.0 + Vector3(0, 13.0, 0)
			fov = 50.0
		fov = float(o[6])
		if move.is_empty() and not lower.contains("static") and not _indoor():
			move = "Dolly in"
	else:
		if who.is_empty():
			_warn("SHOT \"%s\": no character or object named; used the establishing shot." % spec)
			return _shot_camera("establishing", t, seconds, index)
		var size := "medium"
		for key in ["extreme close-up", "close-up", "medium", "full", "wide", "low angle", "high angle", "aerial"]:
			var words := _norm(str(key))
			if lower.contains(words) or (key == "close-up" and lower.contains("closeup")) or (key == "extreme close-up" and lower.contains("ecu")) \
					or (key == "close-up" and lower.begins_with("cu ")) or (key == "medium" and lower.begins_with("ms ")) or (key == "wide" and lower.contains("long shot")):
				size = key
				break
		var setting: Array = SHOT_SIZES[size]
		if who.size() > 1 and (size == "wide" or size == "full" or size == "medium"):
			# Group shot.
			var centre := Vector3.ZERO
			var facing := Vector3.ZERO
			for w in who:
				centre += _pos_at(w, t)
				facing += _dir(_yaw_at(w, t))
			centre /= float(who.size())
			var radius := 0.0
			for w in who:
				radius = maxf(radius, _pos_at(w, t).distance_to(centre))
			if facing.length() < 0.3:
				var o: Array = _overview()
				facing = Vector3(o[0] - centre.x, 0, o[2] - centre.z)
			facing = -facing.normalized() if absf(side) >= 179.0 else facing.normalized().rotated(Vector3.UP, deg_to_rad(side * 0.5))
			var dist := maxf(float(setting[0]) * 0.7, radius * 2.6 + 3.0)
			eye = centre + facing * dist + Vector3(0, 1.7 + dist * 0.12, 0)
			target = centre + Vector3(0, 1.1, 0)
			fov = float(setting[3])
		else:
			var subject: Dictionary = who[0]
			var feet := _pos_at(subject, t)
			var head := _head(subject, t)
			var facing_at := t + 1.0
			if _written_for_at_least("1.28") and subject.get("kind") == "character" and seconds > 2.0:
				# Getting up (or sitting down) right after the cut: frame where they end up.
				var later := t + minf(2.2, seconds * 0.7)
				var moved := _pos_at(subject, later).distance_to(feet)
				if moved > 0.4 and moved < 2.0 and (absf(_head(subject, later).y - head.y) > 0.15 or _sitting_at(subject, t - 0.1) != _sitting_at(subject, later)):
					feet = _pos_at(subject, later)
					head = _head(subject, later)
					facing_at = minf(later + 1.0, t + seconds * 0.6)
			# Look a moment ahead: if the subject turns right after the cut, film the way it ends up facing.
			var d := _dir(_yaw_at(subject, facing_at) + _clear_side(subject, t, side, float(setting[0])))
			var dist := float(setting[0])
			if subject.get("kind") == "prop":
				dist = maxf(dist, float(subject.get("radius", 0.5)) * 3.0)
			match size:
				"full":
					eye = feet + d * dist + Vector3(0, 1.5, 0)
					target = feet + Vector3(0, (head.y - feet.y) * 0.55, 0)
				"wide":
					eye = feet + d * dist + Vector3(0, 2.2, 0)
					target = feet + Vector3(0, 1.0, 0)
				"low angle":
					eye = feet + d * dist + Vector3(0, 0.45, 0)
					target = head
				"aerial":
					eye = feet + d * dist + Vector3(0, 16, 0)
					target = feet
				_:
					eye = head + d * dist + Vector3(0, float(setting[1]), 0)
					target = head + Vector3(0, float(setting[2]), 0)
			fov = float(setting[3])
			dof = dof or bool(setting[4]) or (_story_style and size != "wide" and size != "aerial")
	if follow.is_empty() and not lower.begins_with("establishing") and not lower.begins_with("overview") and not lower.begins_with("pov") \
			and not lower.contains("over shoulder") and not lower.contains("over the shoulder"):
		eye = _unblock(eye, target, who, t)
	var fitted := _fit_camera(eye, target, fov)
	eye = fitted[0]
	fov = fitted[1]
	if follow.is_empty() and (_indoor() or _location.has("camera_bounds")) and _written_for_at_least("1.28") and not lower.begins_with("camera") and not lower.begins_with("overview") \
			and not lower.begins_with("pov") and not lower.contains("shoulder"):
		# (Shots are planned after the scene, so "hidden" may be about a later moment.)
		var people: Array = who.filter(func(w: Dictionary) -> bool: return w.get("kind") == "character")
		# Judged a moment in too, once people who were sitting down have settled.
		var settled := t + clampf(seconds * 0.5, 0.0, 1.5)
		if (people.size() >= 2 or (people.size() == 1 and lower.contains("wide"))) and not (_all_in_view(eye, target, fov, people, t) and _all_in_view(eye, target, fov, people, settled)):
			var better := _group_camera(eye, target, fov, people, settled)
			if better.is_empty() and _location.has("overview") and lower.contains("wide"):
				# Nothing sees them all: the room's own wide view, turned toward them.
				var o: Array = _overview()
				var group := _group_head(people, settled)
				better = [Vector3(float(o[0]), float(o[1]), float(o[2])), Vector3(float(o[3]), float(o[4]), float(o[5])).lerp(group, 0.6), float(o[6]) + 6.0]
			if not better.is_empty():
				eye = better[0]
				target = better[1]
				fov = better[2]
		elif people.size() >= 2 and not lower.contains("behind") and _faces_score(eye, people, settled) < -0.35 * float(people.size()):
			# Everyone with their back to the camera (filmed from behind a bench).
			var turned := _group_camera(eye, target, fov, people, settled)
			if not turned.is_empty() and _faces_score(turned[0], people, settled) > _faces_score(eye, people, settled) + 0.5:
				eye = turned[0]
				target = turned[1]
				fov = turned[2]
	_clear_view(eye, target, fov)
	var basis := Transform3D(Basis(), eye).looking_at(target, Vector3.UP).basis
	var euler := basis.get_euler()
	builder.director.restore_cameras([{"position": [eye.x, eye.y, eye.z],
		"rotation_degrees": [rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)],
		"fov": fov, "focus_distance": eye.distance_to(target), "dof_enabled": dof, "aperture": (0.62 if _story_style else 0.45) if dof else 0.35,
		"shake": 0.35 if handheld else 0.0}])
	var cams := builder.director.cameras()
	var cam: CinematicCamera = cams[cams.size() - 1]
	cam.name = ("Shot %d %s" % [index + 1, label.capitalize()]).validate_node_name().left(48)
	cam.shake = 0.35 if handheld else 0.0
	# A subject that walks off during the shot: keep the same framing, moving with them.
	var tracked: Dictionary = {}
	if follow.is_empty() and who.size() == 1 and not lower.begins_with("establishing") and not lower.begins_with("pov"):
		# (Group shots stay put: a wide shot already holds everyone.)
		var first: Dictionary = who[0]
		if _pos_at(first, t).distance_to(_pos_at(first, t + seconds)) > 1.2:
			tracked = first
	if not tracked.is_empty():
		var uid := cam.uid()
		# Follow the group (everyone named), not just the first person, and never aim
		# outside the room.
		var anchor0 := _group_head(who, t)
		var offset := eye - anchor0
		var aim := target - anchor0
		var k := 0.0
		# Never closer than this: a camera pushed against a wall while someone walks
		# towards it used to end up inside them. Then it stays put and pans instead.
		var closest := maxf(1.1, offset.length() * 0.45)
		var last_good := eye
		while k <= seconds + 0.001:
			var head := _group_head(who, t + k)
			var look := _inside_room(head + aim)
			var p: Vector3 = _fit_camera(head + offset, look, fov)[0]
			if _written_for_at_least("1.28") and p.distance_to(head) < closest:
				look = head
				p = last_good
			else:
				last_good = p
			var q := Transform3D(Basis(), p).looking_at(look, Vector3.UP).basis.get_rotation_quaternion()
			builder.timeline.store.set_key(uid, TimelineController.CH_TRANSFORM, _snap(t + k), {"position": p, "quaternion": q, "scale": Vector3.ONE}, false)
			k += 0.4
		builder.timeline.store.set_key(uid, TimelineController.CH_LENS, _snap(t), cam.lens_state(), false)
	elif not follow.is_empty():
		var uid := cam.uid()
		var step := 0.5
		var k := 0.0
		while k <= seconds + 0.001:
			var f := _follow_frame(follow, t + k)
			var p: Vector3 = _fit_camera(f[0], f[1], fov)[0]
			_clear_view(p, f[1])
			var q := Transform3D(Basis(), p).looking_at(f[1], Vector3.UP).basis.get_rotation_quaternion()
			builder.timeline.store.set_key(uid, TimelineController.CH_TRANSFORM, _snap(t + k), {"position": p, "quaternion": q, "scale": Vector3.ONE}, false)
			k += step
		builder.timeline.store.set_key(uid, TimelineController.CH_LENS, _snap(t), cam.lens_state(), false)
	elif not move.is_empty():
		var dist := eye.distance_to(target)
		var amount := 1.0
		match move:
			"Dolly in", "Dolly out":
				amount = clampf(dist * 0.18, 0.15, 5.0)
			"Truck left", "Truck right":
				amount = clampf(dist * 0.25, 0.3, 8.0)
			"Crane up", "Crane down":
				amount = clampf(dist * 0.2, 0.5, 12.0)
			"Pan left", "Pan right":
				amount = 1.2
			"Tilt up", "Tilt down":
				amount = 1.0
			"Orbit left", "Orbit right":
				amount = 0.8
			"Zoom in", "Zoom out":
				amount = 0.8
		var amount_match := RegEx.create_from_string("\\b(amount|by) ([\\d.]+)").search(lower)
		if amount_match:
			amount = amount_match.get_string(2).to_float()
		if move == "Crane down":
			cam.position += Vector3.UP * amount
			cam.position.y = maxf(cam.position.y, eye.y)
			cam.look_at(target, Vector3.UP)
		builder.timeline.set_time(_snap(t), false)
		builder.timeline.add_camera_move(cam, move, seconds, amount)
		_keep_move_above_ground(cam)
	return cam


## "SHOT: camera at (x, y, z) looking at Mira, fov 30, dolly in" - a hand-placed camera
## (metres in the current location). It looks at a cast member, an object, or a point
## "(x, y, z)"; without "looking at" it looks at the first name in the line.
func _placed_shot(spec: String, lower: String, placed: RegExMatch, who: Array, move: String, t: float, seconds: float, index: int) -> CinematicCamera:
	var eye := Vector3(placed.get_string(1).to_float(), placed.get_string(2).to_float(), placed.get_string(3).to_float()) + _offset
	var target := eye + Vector3(0, 0, -1)
	var look := RegEx.create_from_string("(?i)looking at\\s*\\(\\s*(-?[\\d.]+)\\s*,\\s*(-?[\\d.]+)\\s*,\\s*(-?[\\d.]+)\\s*\\)").search(spec)
	if look:
		target = Vector3(look.get_string(1).to_float(), look.get_string(2).to_float(), look.get_string(3).to_float()) + _offset
	elif not who.is_empty():
		var first: Dictionary = who[0]
		target = _head(first, t) if first.get("kind") == "character" else _pos_at(first, t) + Vector3(0, minf(float(first.get("height", 1.0)) * 0.5, 1.5), 0)
	var fov := 40.0
	var fov_match := RegEx.create_from_string("\\bfov ([\\d.]+)").search(lower)
	if fov_match:
		fov = clampf(fov_match.get_string(1).to_float(), 5.0, 120.0)
	var dof := lower.contains("dof") or lower.contains("depth of field") or lower.contains("blur")
	if _story_style and not lower.contains("sharp") and not lower.contains("no blur") and (not who.is_empty() or look != null):
		dof = true   # the short-film look: soft background behind people
	if not _indoor():
		# Never under the ground or the water, and no tree right in front of the lens.
		var low := _lowest_eye(eye)
		if eye.y < low - 0.05:
			_warn("SHOT %d: the camera was below the ground there, so it was raised to %.1f m." % [index + 1, low - _offset.y])
			eye.y = low
		if eye.y - _ground(eye.x, eye.z) < 3.0:
			_clear_view(eye, target, fov)  # high cameras look over the trees anyway
	var basis := Transform3D(Basis(), eye).looking_at(target, Vector3.UP).basis
	var euler := basis.get_euler()
	builder.director.restore_cameras([{"position": [eye.x, eye.y, eye.z],
		"rotation_degrees": [rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)],
		"fov": fov, "focus_distance": eye.distance_to(target), "dof_enabled": dof, "aperture": (0.62 if _story_style else 0.45) if dof else 0.35,
		"shake": 0.35 if lower.contains("handheld") else 0.0}])
	var cams := builder.director.cameras()
	var cam: CinematicCamera = cams[cams.size() - 1]
	cam.name = ("Shot %d Camera" % (index + 1)).validate_node_name()
	if not move.is_empty():
		var dist := eye.distance_to(target)
		var amount := clampf(dist * 0.15, 0.15, 4.0)
		if move.begins_with("Pan") or move.begins_with("Tilt") or move.begins_with("Orbit") or move.begins_with("Zoom"):
			amount = 0.6
		var amount_match := RegEx.create_from_string("\\b(amount|by) ([\\d.]+)").search(lower)
		if amount_match:
			amount = amount_match.get_string(2).to_float()
		builder.timeline.set_time(_snap(t), false)
		builder.timeline.add_camera_move(cam, move, seconds, amount)
		_keep_move_above_ground(cam)
	return cam


## Flat sketch look: every shot is a side-on view with a long lens (it reads as a
## drawing), sized by the shot type and following anyone who moves.
const FLAT_FOV := 14.0
const FLAT_SIZES := {"extreme close-up": 0.5, "close-up": 0.95, "medium": 1.7, "full": 2.6, "wide": 4.2, "establishing": 6.5}


func _flat_shot(lower: String, spec: String, who: Array, move: String, t: float, seconds: float, index: int) -> CinematicCamera:
	var size := "full" if not who.is_empty() else "establishing"
	for key in ["extreme close-up", "close-up", "medium", "full", "wide", "establishing", "overview", "aerial", "two shot", "two-shot", "over shoulder", "pov"]:
		if lower.contains(_norm(str(key))) or (key == "close-up" and lower.contains("closeup")):
			size = str({"overview": "establishing", "aerial": "establishing", "two shot": "medium", "two-shot": "medium",
				"over shoulder": "medium", "pov": "medium"}.get(key, key))
			break
	var frame_h: float = FLAT_SIZES[size]
	var follow: Dictionary = {}
	if (lower.begins_with("follow") or lower.begins_with("tracking")) and not who.is_empty():
		follow = who[0]
		frame_h = maxf(frame_h, FLAT_SIZES["full"])
	var aspect := 16.0 / 9.0
	var frame_at := func(k: float) -> Array:
		var min_x := INF
		var max_x := -INF
		var head_y := 0.0
		var z := 0.0
		var top := 0.0
		for w in who:
			var p := _pos_at(w, t + k)
			min_x = minf(min_x, p.x)
			max_x = maxf(max_x, p.x)
			var head := _head(w, t + k)
			# A grown or shrunk character ("Someday grows to 2"): frame its real size.
			var grown := _grown_at(w, t + k)
			head_y = maxf(head_y, p.y + (head.y - p.y) * (1.0 if w.get("kind") == "character" and _written_for_at_least("1.28") else grown))
			top = maxf(top, float(w.get("height", 1.0)) * grown + p.y)
			z += p.z
		var h := frame_h
		var cx := 0.0
		if who.is_empty():
			var o: Array = _overview()
			cx = float(o[3])
			z = float(o[5])
		else:
			cx = (min_x + max_x) * 0.5
			z /= float(who.size())
			h = maxf(h, (max_x - min_x + (2.4 if who.size() > 1 else 1.4)) / aspect)
			if size == "wide" or size == "establishing" or size == "full":
				h = maxf(h, top * 1.35)
		var cy := h * 0.42
		if size == "close-up" or size == "extreme close-up":
			cy = head_y - 0.02
		elif size == "medium":
			cy = maxf(head_y - h * 0.22, h * 0.42)
		if lower.contains("low angle"):
			cy -= h * 0.08
		elif lower.contains("high angle"):
			cy += h * 0.08
		var distance := h * 0.5 / tan(deg_to_rad(FLAT_FOV * 0.5))
		var target := Vector3(cx, cy, z)
		var eye := Vector3(cx, cy, z + distance)
		if lower.contains("low angle"):
			eye.y -= h * 0.35
		elif lower.contains("high angle"):
			eye.y += h * 0.35
		return [eye, target]
	var first: Array = frame_at.call(0.0)
	var eye: Vector3 = first[0]
	var target: Vector3 = first[1]
	var basis := Transform3D(Basis(), eye).looking_at(target, Vector3.UP).basis
	var euler := basis.get_euler()
	builder.director.restore_cameras([{"position": [eye.x, eye.y, eye.z],
		"rotation_degrees": [rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)],
		"fov": FLAT_FOV, "focus_distance": eye.distance_to(target), "dof_enabled": false, "aperture": 0.35,
		"shake": 0.35 if lower.contains("handheld") or lower.contains("shaky") else 0.0}])
	var cams := builder.director.cameras()
	var cam: CinematicCamera = cams[cams.size() - 1]
	cam.name = ("Shot %d %s" % [index + 1, spec.left(40).capitalize()]).validate_node_name().left(48)
	var moving := not follow.is_empty()
	if not moving and not who.is_empty():
		for w in who:
			if _pos_at(w, t).distance_to(_pos_at(w, t + seconds)) > 0.6:
				moving = true
	if moving:
		# Slide sideways with the action, like a drawn pan.
		var uid := cam.uid()
		var k := 0.0
		while k <= seconds + 0.001:
			var f: Array = frame_at.call(k)
			var q := Transform3D(Basis(), f[0]).looking_at(f[1], Vector3.UP).basis.get_rotation_quaternion()
			builder.timeline.store.set_key(uid, TimelineController.CH_TRANSFORM, _snap(t + k), {"position": f[0], "quaternion": q, "scale": Vector3.ONE}, false)
			k += 0.4
		builder.timeline.store.set_key(uid, TimelineController.CH_LENS, _snap(t), cam.lens_state(), false)
	elif not move.is_empty():
		# Orbits would show the drawing is 3D: slide instead.
		var flat_move: String = {"Orbit left": "Truck left", "Orbit right": "Truck right"}.get(move, move)
		var dist := eye.distance_to(target)
		var amount := 1.0
		match flat_move:
			"Dolly in", "Dolly out":
				amount = clampf(dist * 0.15, 0.2, 6.0)
			"Truck left", "Truck right":
				amount = clampf(target.y * 0.6, 0.2, 3.0)
			"Crane up", "Crane down":
				amount = clampf(target.y * 0.3, 0.1, 2.0)
			"Pan left", "Pan right", "Tilt up", "Tilt down":
				amount = 0.6
			"Zoom in", "Zoom out":
				amount = 0.6
		builder.timeline.set_time(_snap(t), false)
		builder.timeline.add_camera_move(cam, flat_move, seconds, amount)
	elif seconds > 1.5 and not lower.contains("static") and not lower.contains("locked"):
		# A drawing that never moves feels dead: a slow, gentle push in (about 4%).
		builder.timeline.set_time(_snap(t), false)
		builder.timeline.add_camera_move(cam, "Dolly in", seconds, eye.distance_to(target) * 0.04)
	return cam


## The first camera angle (around [param side]) with no other character between
## the camera and [param subject].
func _clear_side(subject: Dictionary, t: float, side: float, distance: float) -> float:
	var head := _head(subject, t)
	var newer := _written_for_at_least("1.28")
	# (The shot itself films the way they face a moment after the cut.)
	var yaw := _yaw_at(subject, t + 1.0) if newer else _yaw_at(subject, t)
	var roomiest := side
	var most_room := -1.0
	for angle in [side, -side, side * 2.0, -side * 2.0, 0.0, side * 3.0, -side * 3.0, 80.0, -80.0, 110.0, -110.0]:
		if not newer and absf(float(angle)) > 100.0:
			continue
		var eye := head + _dir(yaw + float(angle)) * distance
		if newer:
			# Facing a wall or a parapet: the camera squeezed back into them sees nothing.
			var fitted: Vector3 = _fit_camera(eye, head, 40.0)[0]
			var room := Vector2(fitted.x - head.x, fitted.z - head.z).length()
			if room > most_room and not _blocked(eye, head, subject, t):
				most_room = room
				roomiest = float(angle)
			if room < minf(distance * 0.6, 0.55):
				continue
		if not _blocked(eye, head, subject, t):
			return float(angle)
	return roomiest if newer and most_room > 0.0 else side


func _blocked(eye: Vector3, target: Vector3, subject: Dictionary, t: float) -> bool:
	for key in _things:
		var other: Dictionary = _things[key]
		if is_same(other, subject) or other.get("node") == null:
			continue
		var kind := str(other.get("kind"))
		if kind != "character" and kind != "actor" and kind != "prop":
			continue
		if kind == "prop" and (_prop_top(other) < 0.5 or float(other.get("radius", 0.0)) > 2.5):
			continue  # low things and whole rooms/buildings don't count
		if kind == "prop" and _pos_at(other, t).distance_to(_pos_at(subject, t)) < 0.9 and _using_seat(subject, t, other):
			continue  # the chair or bench the subject is using
		if kind == "prop" and _hangs(other):
			continue  # hanging lamps and wall pieces are above people
		var centre := _pos_at(other, t) + Vector3(0, minf(float(other.get("height", 1.6)), 3.0) * 0.6, 0)
		if kind != "prop" and _written_for_at_least("1.28") and not bool(other.get("hidden", false)):
			# A camera inside someone's head sees only the inside of their head.
			var feet := _pos_at(other, t)
			if Vector2(eye.x - feet.x, eye.z - feet.z).length() < 0.45 and eye.y < _head(other, t).y + 0.35:
				return true
		var closest := Geometry3D.get_closest_point_to_segment(centre, eye, target)
		if closest.distance_to(target) < 0.35:
			continue
		var reach := 0.45 if kind != "prop" else clampf(float(other.get("radius", 0.5)), 0.3, 1.5)
		if closest.distance_to(centre) < reach:
			return true
	return false


## Swings the camera around (or up) until nothing stands between it and its subjects.
func _unblock(eye: Vector3, target: Vector3, subjects: Array, t: float) -> Vector3:
	# Indoors a camera behind a wall is pulled in close; if that leaves it squeezed
	# against the wall (a person facing a desk or a door), film from the side instead.
	var want := eye.distance_to(target)
	var fitted: Vector3 = _fit_camera(eye, target, 40.0)[0]
	var cramped := _indoor() and fitted.distance_to(target) < want * 0.6
	if not cramped and not _view_blocked(fitted, target, subjects, t):
		return eye
	var offset := eye - target
	var fallback := Vector3.INF
	for lift in [0.0, 0.7, 1.4]:
		for angle in [25.0, -25.0, 50.0, -50.0, 80.0, -80.0, 115.0, -115.0]:
			var candidate := target + offset.rotated(Vector3.UP, deg_to_rad(float(angle))) + Vector3(0, float(lift), 0)
			candidate = _fit_camera(candidate, target, 40.0)[0]
			if _view_blocked(candidate, target, subjects, t):
				continue
			if not _indoor() or candidate.distance_to(target) >= want * 0.7:
				return candidate
			if fallback == Vector3.INF:
				fallback = candidate
	return fallback if fallback != Vector3.INF else eye


func _view_blocked(eye: Vector3, target: Vector3, subjects: Array, t: float) -> bool:
	# A camera inside furniture (a desk, a counter, a door) sees nothing.
	for key in _things:
		var piece: Dictionary = _things[key]
		if piece.get("kind") != "prop" or not piece.get("node") is Node3D or float(piece.get("radius", 0.0)) > 2.5:
			continue
		var near_subject := false
		for subject in subjects:
			if is_same(subject, piece):
				near_subject = true
		if near_subject:
			continue
		var box := PropUtils.world_aabb(piece["node"] as Node3D)
		# Around it (not above it: a camera looking over a table or counter is fine).
		var solid_top := box.end.y
		if (piece["node"] as Node).has_method(&"solid_height"):
			solid_top = minf(solid_top, (piece["node"] as Node3D).global_position.y + float((piece["node"] as Node).call(&"solid_height")))
		box = AABB(box.position - Vector3(0.1, 0.0, 0.1), Vector3(box.size.x + 0.2, solid_top - box.position.y + 0.02, box.size.z + 0.2))
		if box.size.y > 0.3 and box.has_point(eye):
			return true
	for key in _things:
		var other: Dictionary = _things[key]
		var skip := false
		for subject in subjects:
			if is_same(subject, other):
				skip = true
		if skip or other.get("node") == null:
			continue
		var kind := str(other.get("kind"))
		if kind == "mark":
			continue
		if kind == "prop" and (float(other.get("height", 0.0)) < 0.5 or float(other.get("radius", 0.0)) > 2.5):
			continue
		var near_subject := false
		for subject in subjects:
			if kind == "prop" and _pos_at(other, t).distance_to(_pos_at(subject, t)) < 0.9 and _using_seat(subject, t, other):
				near_subject = true
		if near_subject:
			continue
		if kind == "prop" and _hangs(other):
			continue
		var base := _pos_at(other, t)
		if kind != "prop" and _written_for_at_least("1.28") and not bool(other.get("hidden", false)):
			if Vector2(eye.x - base.x, eye.z - base.z).length() < 0.45 and eye.y < _head(other, t).y + 0.35:
				return true
		var top := base + Vector3(0, minf(float(other.get("height", 1.6)), 3.0), 0)
		var reach := 0.45 if kind != "prop" else clampf(float(other.get("radius", 0.5)) * 0.8, 0.25, 1.2)
		for k in 4:
			var probe := base.lerp(top, (float(k) + 0.5) / 4.0)
			var closest := Geometry3D.get_closest_point_to_segment(probe, eye, target)
			if closest.distance_to(target) < 0.4 or closest.distance_to(eye) < 0.15:
				continue
			if closest.distance_to(probe) < reach:
				return true
	return false


## True when everyone in [param people] is inside the picture and not hidden behind
## furniture (a two-person shot squeezed against a wall used to lose one of them).
func _all_in_view(eye: Vector3, target: Vector3, fov: float, people: Array, t: float) -> bool:
	var forward := (target - eye).normalized()
	if absf(forward.y) > 0.98:
		return true
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward)
	var tan_v := tan(deg_to_rad(fov) * 0.5)
	var tan_h := tan_v * 16.0 / 9.0
	for person in people:
		var head := _head(person, t)
		var body := _pos_at(person, t).lerp(head, 0.5)
		for point in [head, body]:
			var v: Vector3 = point - eye
			var depth := v.dot(forward)
			if depth < 0.4:
				return false
			if absf(v.dot(right) / depth) > tan_h * 0.9 or absf(v.dot(up) / depth) > tan_v * 0.95:
				return false
		if _view_blocked(eye, head, people, t):
			return false
		# One of the group in front of another's face (filming over a shoulder hides it).
		for other in people:
			if is_same(other, person):
				continue
			var other_head := _head(other, t)
			if other_head.distance_to(eye) + 0.2 >= head.distance_to(eye):
				continue
			var near := Geometry3D.get_closest_point_to_segment(other_head, eye, head)
			if near.distance_to(other_head) < 0.34:
				return false
		# Furniture between the camera and their face (a wardrobe beside a door).
		var stop := head + (eye - head).normalized() * 0.3
		for found in _solid_props():
			var box: AABB = (found as AABB).grow(-0.03)
			if box.has_point(eye) or box.has_point(_pos_at(person, t) + Vector3(0, 0.5, 0)):
				continue
			if box.intersects_segment(eye, stop) != null:
				return false
	return true


## Another camera for a group that the planned one can't see whole: around the group at
## the same distance, then a step back, then the room's overview. [] if none works.
func _group_camera(eye: Vector3, target: Vector3, fov: float, people: Array, t: float) -> Array:
	var offset := eye - target
	var flat := Vector3(offset.x, 0, offset.z)
	if flat.length() < 0.5:
		flat = Vector3(0, 0, 1.5)
	if _written_for_at_least("1.28") and flat.length() < 2.2:
		flat = flat.normalized() * 2.2  # (the planned camera may have been squeezed against a wall)
	for grow in [1.0, 1.35, 1.7]:
		# Of the angles that see everyone, the one that sees the most faces (not backs).
		var best: Array = []
		var best_score := -INF
		for angle in [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 130.0, -130.0, 180.0]:
			var candidate := target + flat.rotated(Vector3.UP, deg_to_rad(float(angle))) * float(grow) + Vector3(0, offset.y + 0.2 * (float(grow) - 1.0), 0)
			var fitted := _fit_camera(candidate, target, maxf(fov, 40.0))
			if _all_in_view(fitted[0], target, fitted[1], people, t) and not _view_blocked(fitted[0], target, people, t):
				var score := -absf(float(angle)) * 0.002  # a little preference for the planned angle
				for person in people:
					var to_cam := (fitted[0] as Vector3) - _pos_at(person, t)
					to_cam.y = 0.0
					score += _dir(_yaw_at(person, t)).dot(to_cam.normalized())
				if score > best_score:
					best_score = score
					best = [fitted[0], target, fitted[1]]
		if not best.is_empty():
			return best
	if _location.has("overview"):
		var o: Array = _overview()
		var view_eye := Vector3(float(o[0]), float(o[1]), float(o[2]))
		var view_target := Vector3(float(o[3]), float(o[4]), float(o[5]))
		var group := _group_head(people, t)
		view_target = view_target.lerp(group, 0.6)
		if _all_in_view(view_eye, view_target, float(o[6]) + 6.0, people, t):
			return [view_eye, view_target, float(o[6]) + 6.0]
	return []


## How high a prop reaches above the floor: its own height before 1.28, the top of
## it from 1.28 (a lamp standing on a table is not a low thing).
func _prop_top(thing: Dictionary) -> float:
	var own := float(thing.get("height", 0.0))
	if not _written_for_at_least("1.28") or not (thing.get("node") is Node3D):
		return own
	if not thing.has("top"):
		thing["top"] = PropUtils.world_aabb(thing["node"] as Node3D).end.y - _offset.y
	return maxf(own, float(thing["top"]))


## How much a group faces the camera at [param eye]: +1 each facing it, -1 each with
## their back to it.
func _faces_score(eye: Vector3, people: Array, t: float) -> float:
	var score := 0.0
	for person in people:
		var to_cam := eye - _pos_at(person, t)
		to_cam.y = 0.0
		if to_cam.length() > 0.01:
			score += _dir(_yaw_at(person, t)).dot(to_cam.normalized())
	return score


## Whether a nearby chair or bed is theirs to ignore: someone standing behind a
## barber chair is hidden by it, someone sitting in it is not.
func _using_seat(subject: Dictionary, t: float, piece: Dictionary = {}) -> bool:
	if subject.get("kind") != "character" or not _written_for_at_least("1.28"):
		return true
	if not piece.is_empty() and float(piece.get("seat", -1.0)) < 0.0 and not _is_bed(piece) and _prop_top(piece) < 1.4:
		return false  # the table in front of them still hides them
	return _sitting_at(subject, t) or _lying_at(subject, t)


## True for things that hang above head height (pendant lamps, wall clocks, shelves).
func _hangs(thing: Dictionary) -> bool:
	var node := thing.get("node") as Node3D
	if node == null:
		return false
	if not thing.has("bottom"):
		thing["bottom"] = PropUtils.world_aabb(node).position.y - node.global_position.y
	return float(thing["bottom"]) > 1.2


## The middle of everyone's heads (characters; objects count by their middle).
func _group_head(who: Array, t: float) -> Vector3:
	var sum := Vector3.ZERO
	for w in who:
		sum += _head(w, t)
	return sum / float(maxi(who.size(), 1))


## Indoors: [param p] moved inside the room's walls (a point to look at).
func _inside_room(p: Vector3) -> Vector3:
	if not _indoor():
		return p
	var raw: Array = _location.get("bounds", [-50.0, 50.0, -50.0, 50.0, 10.0])
	return Vector3(clampf(p.x, float(raw[0]) + _offset.x + 0.2, float(raw[1]) + _offset.x - 0.2), clampf(p.y, 0.2, float(raw[4]) - 0.2),
		clampf(p.z, float(raw[2]) + _offset.z + 0.2, float(raw[3]) + _offset.z - 0.2))


func _cast_centre(t: float) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for key in _things:
		var thing: Dictionary = _things[key]
		if thing.get("kind") == "character" or thing.get("kind") == "actor":
			sum += _pos_at(thing, t)
			n += 1
	if n == 0:
		var centre := _thing("center")
		return _pos_at(centre, t) if not centre.is_empty() else Vector3.ZERO
	return sum / float(n)


func _follow_frame(thing: Dictionary, t: float) -> Array:
	var p := _pos_at(thing, t)
	var m: Vector3 = thing["_dir"]
	var side: Vector3 = thing["_side"]
	var eye := p + side * 4.2 - m * 1.6 + Vector3(0, 1.6, 0)
	var target := p + Vector3(0, 1.15, 0) + m * 1.0
	return [eye, target]


func _head(thing: Dictionary, t: float) -> Vector3:
	var feet := _pos_at(thing, t)
	var h := float(thing.get("height", 1.75))
	if thing.get("kind") == "character" and _written_for_at_least("1.28"):
		h *= _grown_at(thing, t)  # "Bibek grows to 1.25": the camera finds the grown-up head
	if thing.get("kind") == "prop":
		return feet + Vector3(0, h * 0.6, 0)
	if thing.get("kind") == "actor":
		return feet + Vector3(0, h * 0.9, 0) + _dir(_yaw_at(thing, t)) * 0.4
	if _sitting_at(thing, t):
		return feet + Vector3(0, h * 0.68, 0)
	match _posture_at(thing, t):
		"Kneel":
			return feet + Vector3(0, h * 0.66, 0)
		"Lie Down":
			return feet + Vector3(0, 0.2, 0) - _dir(_yaw_at(thing, t)) * 0.75
	return feet + Vector3(0, h * 0.93, 0)


## Keeps the camera above ground (outdoors) or inside the room (indoors); when
## it has to move closer, the lens widens to keep the same framing.
func _fit_camera(eye: Vector3, target: Vector3, fov: float) -> Array:
	var out := eye
	# Indoors the walls, on a rooftop its edge (cameras out over the street saw nothing).
	if _indoor() or (_location.has("camera_bounds") and _written_for_at_least("1.28")):
		var raw: Array = _location.get("bounds", [-50.0, 50.0, -50.0, 50.0, 10.0]) if _indoor() else _location["camera_bounds"]
		var b: Array = [float(raw[0]) + _offset.x, float(raw[1]) + _offset.x, float(raw[2]) + _offset.z, float(raw[3]) + _offset.z, raw[4]]
		var margin := 0.35
		var lo := Vector3(float(b[0]) + margin, 0.3, float(b[2]) + margin)
		var hi := Vector3(float(b[1]) - margin, float(b[4]) - margin, float(b[3]) - margin)
		if not (out.x >= lo.x and out.x <= hi.x and out.z >= lo.z and out.z <= hi.z and out.y >= lo.y and out.y <= hi.y):
			var ray := out - target
			var k := 1.0
			for axis in 3:
				if absf(ray[axis]) < 0.0001:
					continue
				var limit := hi[axis] if ray[axis] > 0.0 else lo[axis]
				var room := (limit - target[axis]) / ray[axis]
				k = minf(k, clampf(room, 0.05, 1.0))
			var before := ray.length()
			out = target + ray * k
			var after := maxf(out.distance_to(target), 0.2)
			fov = clampf(rad_to_deg(2.0 * atan(tan(deg_to_rad(fov) * 0.5) * before / after)), fov, 80.0)
	else:
		out.y = maxf(out.y, _lowest_eye(out))
	return [out, fov]


## The lowest a camera may go outdoors at [param p]: above the ground and the water.
func _lowest_eye(p: Vector3) -> float:
	var low := _ground(p.x, p.z) + 0.35
	var water := _water_y(p.x, p.z)
	if not is_nan(water):
		low = maxf(low, water + 0.25)
	return low


## A camera move (dolly, truck, crane...) runs in straight lines between its keys:
## over a hill or a river bank the middle could dip underground. Adds keys that
## lift the camera over the ground wherever that would happen.
func _keep_move_above_ground(cam: CinematicCamera) -> void:
	if _indoor() or cam == null:
		return
	var store := builder.timeline.store
	var id := KeyframeStore.channel_id(cam.uid(), TimelineController.CH_TRANSFORM)
	var keys: Array = store.channels.get(id, [])
	if keys.size() < 2:
		return
	var extra: Array = []
	for i in keys.size() - 1:
		var a: Dictionary = keys[i]
		var b: Dictionary = keys[i + 1]
		var pa: Vector3 = a["v"].get("position", Vector3.ZERO)
		var pb: Vector3 = b["v"].get("position", Vector3.ZERO)
		var qa: Quaternion = a["v"].get("quaternion", Quaternion.IDENTITY)
		var qb: Quaternion = b["v"].get("quaternion", Quaternion.IDENTITY)
		var steps := clampi(int(pa.distance_to(pb) / 0.4), 2, 40)
		for s in range(1, steps):
			var w := float(s) / float(steps)
			var p := pa.lerp(pb, w)
			var low := _lowest_eye(p)
			if p.y < low - 0.02:
				extra.append([lerpf(float(a["t"]), float(b["t"]), w), Vector3(p.x, low + 0.1, p.z), qa.slerp(qb, w)])
	var last := -1.0
	for e in extra:
		var t := _snap(float(e[0]))
		if t - last < 0.15:
			continue  # one key every few frames is enough
		last = t
		store.set_key(cam.uid(), TimelineController.CH_TRANSFORM, t, {"position": e[1], "quaternion": e[2], "scale": Vector3.ONE}, false)


## Removes trees and bushes that would block the camera's view: right around
## the camera, along the line to the subject, and inside the near part of the frame.
func _clear_view(eye: Vector3, target: Vector3, fov: float = 45.0) -> void:
	if _indoor() or builder.vegetation == null:
		return
	builder.vegetation.erase("", eye, 1.4, 2.0)
	var forward := Vector3(target.x - eye.x, 0, target.z - eye.z)
	if forward.length() > 0.01:
		forward = forward.normalized()
		var across := Vector3(-forward.z, 0, forward.x)
		var reach := minf(12.0, eye.distance_to(target) - 1.5)
		var half := tan(deg_to_rad(fov) * 0.5) * 1.8  # 16:9 frame, a little extra
		var d := 1.5
		while d <= reach:
			var width := half * d
			var x := -width
			while x <= width:
				var p := eye + forward * d + across * x
				for kind in TALL_PLANTS:
					builder.vegetation.erase(kind, p, 1.2, 2.0)
				x += 1.6
			d += 1.6
	var span := eye.distance_to(target)
	if span > 60.0:
		return
	var steps := int(span / 2.0)
	for i in range(1, steps):
		var p := eye.lerp(target, float(i) / float(steps))
		if p.distance_to(target) < 1.5:
			break
		for kind in TALL_PLANTS:
			builder.vegetation.erase(kind, p, 1.1, 2.0)


# --- Finish --------------------------------------------------------------------------

func _finish(length: float) -> void:
	var timeline := builder.timeline
	# Header "A -> B" light/weather changes run across the whole film.
	_flush_env_later(length)
	# One lip-sync envelope per character from all its lines.
	for key in _things:
		var thing: Dictionary = _things[key]
		var lips: Array = thing.get("lips", [])
		if lips.is_empty() or not thing.get("node") is CharacterBase:
			continue
		var first := INF
		for entry in lips:
			first = minf(first, float((entry as Array)[0]))
		var merged := PackedFloat32Array()
		for entry in lips:
			var e: Array = entry
			var env: PackedFloat32Array = e[1]
			var offset := int(round((float(e[0]) - first) * 30.0))
			if merged.size() < offset + env.size():
				merged.resize(offset + env.size())
			for i in env.size():
				merged[offset + i] = maxf(merged[offset + i], env[i])
		(thing["node"] as CharacterBase).lipsync = {"clip": "(script dialogue)", "start": first, "fps": 30.0, "env": merged}
	for key in _things:
		var item: Dictionary = _things[key]
		if not _carrying(item).is_empty():
			_end_carry(item, length)
	_make_shots(length)
	_close_counter(length)
	if _flat:
		for child in builder.placed_props_root.get_children():
			if child is Node3D and not child is SketchCharacter:
				SketchLook.flatten(child, builder.environment.look == SketchLook.CARTOON, builder.environment.look == SketchLook.SKETCHBOOK)
	timeline.store.duration = clampf(snappedf(length, 0.1), TimelineController.MIN_DURATION, TimelineController.MAX_DURATION)
	if builder.titles:
		builder.titles.load_list(_titles)
	if builder.audio:
		builder.audio.load_list(_clips)
	timeline.store.changed.emit()
	timeline.set_time(0.0)
	builder.history.clear_history()
	_info("%d shot%s, %d title%s, %d sound%s, %.1f s." % [_shot_count, "" if _shot_count == 1 else "s",
		_titles.size(), "" if _titles.size() == 1 else "s", _clips.size(), "" if _clips.size() == 1 else "s", length])
	_report["shots"] = _shot_count


# --- Helpers -------------------------------------------------------------------------

func _reset_state() -> void:
	_things.clear()
	_names.clear()
	_sets.clear()
	_scene_set.clear()
	_set_index = 0
	_offset = Vector3.ZERO
	_suffix = ""
	_titles.clear()
	_clips.clear()
	_shots.clear()
	_events.clear()
	_env_later.clear()
	_catalog.clear()
	_end = 0.0
	_shot_count = 0
	_last_speaker = ""
	_report = {"info": [], "subs": [], "missing": [], "warnings": [], "scenes": [], "imported": [],
		"counts": {"characters": 0, "props": 0}, "length": 0.0, "shots": 0}


func _info(text: String) -> void:
	(_report["info"] as Array).append(text)


func _warn(text: String) -> void:
	(_report["warnings"] as Array).append(text)


func _sub(what: String, used: String) -> void:
	(_report["subs"] as Array).append("%s → %s" % [what, used])


func _missing(what: String) -> void:
	if not (_report["missing"] as Array).has(what):
		(_report["missing"] as Array).append(what)


func _report_count(key: String) -> void:
	var counts: Dictionary = _report["counts"]
	counts[key] = int(counts.get(key, 0)) + 1


func _snap(t: float) -> float:
	return builder.timeline.snap_time(maxf(t, 0.0))


static func _seconds(text: String, fallback: float) -> float:
	var found := RegEx.create_from_string("(-?[\\d.]+)").search(text)
	return found.get_string(1).to_float() if found else fallback


static func _over(text: String) -> float:
	var found := RegEx.create_from_string("(?i)\\bover\\s+([\\d.]+)").search(text)
	return found.get_string(1).to_float() if found else 0.0


static func _strip_over(text: String) -> String:
	return RegEx.create_from_string("(?i)\\s*\\bover\\s+[\\d.]+\\s*(s|sec|secs|seconds)?\\b").sub(text, "", true).strip_edges()


## Lower-case words only, without "the/a/an".
static func _norm(text: String) -> String:
	var lower := text.to_lower().replace("_", " ").replace("’", "'")
	var out := ""
	for i in lower.length():
		var c := lower[i]
		var keep := (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == " " or c == "."
		if c == "-" and i + 1 < lower.length() and lower[i + 1] >= "0" and lower[i + 1] <= "9" and (i == 0 or lower[i - 1] == " " or lower[i - 1] == "("):
			keep = true
		out += c if keep else " "
	var words := out.split(" ", false)
	var kept: PackedStringArray = []
	for w in words:
		if w != "the" and w != "a" and w != "an" and w != "his" and w != "her" and w != "their":
			kept.append(w)
	return " ".join(kept).strip_edges()


static func _similarity(a: String, b: String) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0
	if a == b:
		return 1.0
	if b.contains(a) or a.contains(b):
		return 0.8
	var wa := a.split(" ", false)
	var wb := b.split(" ", false)
	var shared := 0
	for w in wa:
		var single := str(w).trim_suffix("s")
		for v in wb:
			if str(v).trim_suffix("s") == single:
				shared += 1
				break
	return float(shared) / float(maxi(wa.size(), wb.size()))


## The key of [param keys] that best matches [param text] ("" if none is close).
static func _best_key(text: String, keys: Array) -> String:
	var wanted := _norm(text)
	var best := ""
	var best_score := 0.0
	for key in keys:
		var k := _norm(str(key))
		var score := _similarity(wanted, k)
		if score > best_score:
			best_score = score
			best = str(key)
	return best if best_score >= 0.5 else ""

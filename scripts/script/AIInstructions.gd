class_name AIInstructions
extends RefCounted
## Writes the instructions to paste into an AI chat (Claude, ChatGPT…) so it can
## write a film script for Scene Builder. Everything the app has installed right
## now is listed, so the AI only uses names that exist.


static func generate(story: String = "") -> String:
	var lines: PackedStringArray = []
	lines.append("You are writing a film script for Scene Builder, a 3D movie-making app. Scene Builder reads the script and builds the whole film automatically: location, characters, movement, dialogue with lip sync and subtitles, camera shots, titles, music.")
	lines.append("")
	lines.append("Reply with ONLY the script inside one code block. Follow the format exactly and use ONLY the names listed below (locations, places, objects, characters, actions). If the story needs something that isn't listed, choose the closest listed thing and add a comment line starting with # saying what you would ideally want.")
	lines.append("")
	lines.append("## FORMAT")
	lines.append("```")
	lines.append("REQUIRES: Scene Builder %s        # always copy this line exactly" % ScriptDirector.app_version())
	lines.append("TITLE: The Lantern")
	lines.append("LOCATION: Lakeside Campfire")
	lines.append("TIME: 18.0 -> 19.3          # hour of day; \"A -> B\" changes it over the whole film. Or a preset name.")
	lines.append("WEATHER: Clear               # a weather preset, or settings like: mist 0.4, wind 0.3")
	lines.append("MUSIC: theme, volume -6      # optional")
	lines.append("VOICES: auto                 # optional: speak every line with automatic voices")
	lines.append("STYLE: flat                  # optional: the Flat sketch look (black void, see FLAT SKETCH STYLE); STYLE: paper = the same drawn style as ink on warm paper; leave out for realistic 3D")
	lines.append("")
	lines.append("CAST:")
	lines.append("Mira = woman casual, top teal, hair black")
	lines.append("Elder = elder")
	lines.append("")
	lines.append("SET:")
	lines.append("lantern = crate near bench, facing campfire      # id = object at/near/in front of/behind/left of/right of <place>")
	lines.append("")
	lines.append("SCENE 1: Arrival")
	lines.append("Elder sits on bench")
	lines.append("Mira is at hill")
	lines.append("SHOT: establishing, crane down")
	lines.append("Mira walks to campfire")
	lines.append("SHOT: close-up on Elder")
	lines.append("Elder: \"You came back.\"")
	lines.append("Mira (waves): \"I kept my promise.\"")
	lines.append("TITLE: THE END for 4s")
	lines.append("```")
	lines.append("")
	lines.append("## HOW TIMING WORKS")
	lines.append("- Lines run one after another. Each line waits until the previous one is finished (walks take as long as the walk; dialogue as long as the sentence).")
	lines.append("- End a line with \" &\" to make the NEXT line start at the same moment (e.g. two people walking together).")
	lines.append("- WAIT 2s pauses. AT 12s jumps to an exact time. Add \"for 4s\" to make an action last 4 seconds.")
	lines.append("- SHOT, TITLE, MUSIC, SOUND, TIME, WEATHER and LIGHT lines take no time; they happen at that moment.")
	lines.append("")
	lines.append("## CHARACTER LINES (start with a cast name)")
	lines.append("- Place: \"Mira is at hill\", \"Mira stands near campfire, facing lake\", \"Mira enters at path\" (invisible until then), \"Mira disappears\".")
	lines.append("- Move: walks / strolls / sneaks / tiptoes / marches / storms / runs / jogs / sprints / trots / goes to <place> [via <place>, <place>] [slowly|quickly]. \"leaves to <place>\" walks there and vanishes.")
	lines.append("- Umbrellas: any object with \"umbrella\" in its name is held up in one hand (\"Dev holds umbrella\") and can be held over someone (\"Dev holds umbrella over Mira\"; they can walk together). \"sits on bench, far left / far right\" leaves space between two strangers.")
	lines.append("- Two on one bench: \"Harold sits on bench, right\" and \"Margaret sits on bench, left\" (sides as seen by the person sitting).")
	lines.append("- Sit / stand: \"Elder sits on bench\", \"Elder stands up\". Sitting characters can still talk, nod, wave and point.")
	lines.append("- Carry: \"Mira picks up lantern\" (walks to it if needed), she carries it while walking, \"Mira holds lantern high\", \"Mira puts down lantern on table\" (or just \"puts down lantern\"), \"Mira gives lantern to Ram\", \"Mira lets go of lantern\" (it stays where it was, e.g. before it rises).")
	lines.append("- Kneel / lie / hug: \"Mira kneels\", \"Mira kneels at grave\", \"Ram lies down on bed\" (or on the ground), \"Mira hugs Ram\" (walks up and hugs, ~3.5 s). \"stands up\" ends sitting, kneeling or lying.")
	lines.append("- Turn: \"Mira turns to Elder\", \"Mira looks at lake\". Point: \"Mira points at hill\".")
	lines.append("- Gestures: waves, talks, claps, cheers, laughs, thinks, looks around, whistles, dances, jumps, waits, freezes, nods, shakes head, bows, shrugs, raises hand, gasps, facepalms, scratches head, sleeps, wakes up.")
	lines.append("- Dialogue: Name: \"text\"   or   Name (to Elder, waves): \"text\". The speaker turns to the listener, talks with lip sync, and a subtitle appears.")
	lines.append("  Optional recorded voice: Mira: \"Hello\" [audio: voices/mira_01.wav] [voice: Higher]")
	lines.append("- Hand animation (advanced): \"Mira poses right shoulder -90 0 0, right elbow -40 0 0 over 1s\", then \"Mira relaxes over 1s\".")
	lines.append("  Angles in degrees (x y z). Arms hang down at 0; x -90 lifts the arm forward, -170 straight up. Elbow x -90 bends it. Head x +20 nods down, y +30 turns left.")
	lines.append("- Objects can appear, disappear, move and turn too: \"momo disappears\", \"steamer appears on coffee table\", \"car drives to street end\". They can rise or sink too: \"lantern rises 25m over 14s toward lake\", \"balloon floats up 10m\", \"rock sinks 2m over 3s\".")
	lines.append("- Places can be: a place name, an object, a character, \"on <object>\" (on top of it), \"near/next to/in front of/behind/left of/right of <place>\", \"2m left of <place>\", \"between <a> and <b>\", or coordinates \"(12, -4)\".")
	lines.append("")
	lines.append("## CAMERA (SHOT: …)")
	lines.append("A SHOT cuts to a new camera and lasts until the next SHOT. Framing is automatic. Format: SHOT: <type> [on <names>], [move], [from left|right|behind|front], [handheld]")
	lines.append("- Types: establishing, wide, full, medium, close-up, extreme close-up, low angle, high angle, aerial, two-shot <A> and <B>, over-shoulder <A> to <B> (behind A, looking at B), pov <A> to <B>, follow <A> (tracks a walking character).")
	lines.append("- Moves: " + ", ".join(TimelineController.CAMERA_MOVES) + ", static.")
	lines.append("- Hand-placed camera (precise cinematography): SHOT: camera at (x, y, z) looking at Mira, fov 30, dolly in   (or looking at (x, y, z)). x/z are the location's metres, y is height. Use it when automatic framing hits walls or vehicles. Prefer the automatic shots (close-up on Mira, wide shot, two shot Mira and Ravi): they frame people, avoid obstacles and stay above the ground by themselves. A hand-placed camera below the ground is raised automatically.")
	lines.append("- If a scene has NO shot lines, Scene Builder films it automatically (establishing shot, two-shots, over-shoulders, close-ups, follow shots). Good for beginners; write your own SHOTs for more control.")
	lines.append("")
	lines.append("## TITLES, SOUND, LIGHT")
	lines.append("- TITLE: \"text\" for 4s (big centred) · CAPTION: (top) · LOWER THIRD: (bottom-left name card) · SUBTITLE: · use | for a line break.")
	lines.append("- Trailer / motivational look: LETTERBOX: on (wide black bars) · CINEMATIC: \"text\" for 4s (glowing trailer text, no box) · HERO TITLE: \"RISE\" for 6s (huge spaced title).")
	lines.append("- MUSIC: <file>, volume -6 · SOUND: <file>, volume -3, voice <effect>. \"theme\" = the built-in calm theme.")
	lines.append("- TIME: 19.5 over 10s · WEATHER: Rain over 5s · LIGHT: mist 0.6, fog 0.01, exposure 1.3 over 8s")
	lines.append("- Settings for LIGHT/WEATHER: time, sun_azimuth, sun (intensity), clouds, fog, ambient, exposure, wind, wind_direction, rain, snow, mist, leaves, snow_cover, autumn (0–1 unless noted), bloom (glow 0–1), contrast (1 = normal), saturation (colour strength, 1 = normal). autumn turns trees gold and red and dries the grass; snow_cover buries the grass under snow. Seasons: WEATHER: Autumn / Snowfall, or e.g. WEATHER: autumn 0.95, leaves 0.7.")
	lines.append("- VFX objects (place in SET, show with \"aura appears\", hide with \"aura disappears\", move with \"aura is at (x, z)\"): energy aura, blue aura (power-up around a person), spark burst, embers, golden dust, fireflies, light rays, snow sparkle. They glow brightest with LIGHT: bloom 0.6.")
	lines.append("")
	lines.append("## SHORT FILM STYLE (1.27+: silhouette people in soft 3D sets, like quiet emotional YouTube animated shorts)")
	lines.append("- Header: STYLE: short film, VOICES: off, CAMERA: manual, and a furnished set: LOCATION: Kitchen, Bedroom, Cafe, Barbershop, Apartment Hallway, Rooftop, Bus Stop or Car (combine as many as you like, one per scene). Soft graded colour, a blurred background behind people, a vignette.")
	lines.append("- Characters: story man, story woman, story boy, story girl, story child, story old man, story old woman (black silhouettes with white eyes, coloured clothes and a thin light outline). Settings: top <colour>, long sleeves, trousers <colour>, skirt <colour>, apron <colour>, cap / bandana / beanie / sun hat / hard hat / chef hat (+ colour), glasses, lanyard, headphones, hair short | long | bob | bun | ponytail | curly | braids | spiky | none, hair <colour> (white for old people), bun <colour> (the hair tie), height, build, words <colour> (their dialogue colour), glow <colour> (their emotion colour). Example: Mira = story woman, top sage, apron terracotta, bun peach, lanyard, words #ffd27a")
	lines.append("- Dialogue is WORDS ON SCREEN, floating beside whoever speaks (no voices): keep lines short (under 12 words). Thoughts: Mira (thinks): \"...\". Self-doubt swirling round someone: WORDS: Mira \"too late\" \"no talent\" color #9fb6d8 for 5s, then WAIT 5s (WORDS takes no time by itself).")
	lines.append("- Emotion glow: \"Rohan glows red\", \"Rohan glows softly blue over 2s\", \"Rohan burns red\" (anger flaring), \"Rohan calms down over 3s\" / \"Rohan stops glowing\".")
	lines.append("- Cards: QUOTE: \"Most people do not listen\" | \"with the intent to understand.\" for 6s (white serif lines on black, one after another - open and close the film with one; add WAIT 6s) · TIME CARD: \"A few weeks later\" for 3s (small letters in the top-right corner, no WAIT needed).")
	lines.append("- Pace like the best shorts: a new SHOT every 3-6 seconds, mostly close-ups and medium shots, a wide shot to open each scene, WAIT 1-2s on emotional beats, PHONE / NOTE / CALENDAR inserts for screens, a small turning point, a quiet ending, then HERO TITLE: \"TITLE\" for 4s.")
	lines.append("- In the Car: \"Dad sits on driver seat\", \"Tara sits on passenger seat\"; film through the windscreen with SHOT: camera at (1.8, 1.5, 3.4) looking at (1.8, 1.2, -0.2), fov 40, and close-ups from the dashboard: camera at (1.6, 1.3, 0.45) looking at (2.2, 1.16, -0.1), fov 45 (passenger) or camera at (2.0, 1.34, 0.45) looking at (1.4, 1.24, -0.1), fov 45 (driver).")
	lines.append("")
	lines.append("## SKETCHBOOK STYLE (1.18+: hand-drawn picture book)")
	lines.append("- Header: LOCATION: Sketch Stage and STYLE: sketchbook. Boiling pencil outlines on cream paper, soft watercolour colours; characters are cartoon people (settings as in CARTOON STYLE) with faces always visible. \"LIGHT: paper #e8f1ea\" sets the page colour of a scene (pale for day, deep blue for night). Best for gentle, emotional stories.")
	lines.append("## CARTOON STYLE (1.17+: bright 2D cartoon, the most eye-catching look)")
	lines.append("- Header: LOCATION: Sketch Stage and STYLE: cartoon. Outdoors: blue sky, drifting clouds, hills and green grass. \"LIGHT: paper #ffe2b8\" turns a scene indoors (that colour is the wall, with a floor); \"LIGHT: paper none\" goes back outdoors; \"LIGHT: sky #2c3150\" makes an evening or night sky.")
	lines.append("- Characters: \"cartoon person\" (big head, big eyes with a shine, ears, nose, open smiles with teeth). Settings: color <skin>, height (1.05 = a 6-year-old, 1.35 = 11, 1.6-1.8 adults), hair spiky | short | long | bob | bun | ponytail | curl | none, hair <colour>, tshirt <colour> (short sleeves) or hoodie <colour> (long sleeves), jeans <colour>, shoes <colour>, cap <colour> (worn backwards). Example: Leo = cartoon person, color #f2c29b, height 1.15, hair spiky, hair #5a3418, tshirt #9ad13a, jeans #4f86b8, cap #f7c531. Every face, gesture, whisper, NOTE/CALENDAR/WORDS/POST/PHONE insert and shadow from the sketch styles works here too.")
	lines.append("")
	lines.append("## FLAT SKETCH STYLE (2D-looking animation: black void, one floor line, side view)")
	lines.append("- Two looks: STYLE: flat (a black void, glowing shadows: moody, night-time) and STYLE: paper (ink outlines on warm paper with a faint grain: bright, daytime, comedy). Everything below works in both.")
	lines.append("- Use it with the header lines LOCATION: Sketch Stage and STYLE: flat (or paper). Every shot becomes a flat side view (x = left/right along the floor line, in metres); objects and people are drawn flat with outlines.")
	lines.append("- Characters: \"sketch person\" (a round cream figure with a simple drawn face) and \"shadow\" (a black figure with a coloured glow and a glowing face: temptation, fear, a bad habit, the inner voice). Settings: color <colour>, glow <colour>, lines <colour>, face <expression>, height <metres>, build 0.7–1.3. Example: Later = shadow, glow #9a55ff, face smirk. Built-in people become sketch people in this style.")
	lines.append("- Faces: \"Mina looks tired\" (or feels/becomes/gets/seems), \"Mina smiles\", \"Later smirks\", \"Mina frowns\", \"Mina gasps\", \"Mina panics\". Expressions: " + ", ".join(SketchCharacter.EXPRESSIONS).to_lower() + ".")
	lines.append("- Whispers: \"Later whispers: Just one more video.\" shows handwritten glowing words next to the speaker's head (no subtitle). \"Mina thinks: Not tonight.\" shows quiet white words. Normal dialogue still works.")
	lines.append("- COUNTER: \"DAYS CLEAN: 3\" puts a counter in the top-right corner until the next COUNTER line (COUNTER: off hides it).")
	lines.append("- PHONE: full-screen phone close-ups (take their time, like WAIT): PHONE: home at 1:41 for 2s · PHONE: notification \"App\" \"Message text\" for 3s · PHONE: message \"Mom\" \"Did you eat?\" \"Yes\" for 4s · PHONE: feed \"Clips\" at 11:04 for 3s (endless scrolling) · PHONE: dialog \"Delete Clips?\" \"Cancel\" \"Delete\" for 3.5s, taps Delete · PHONE: call \"Dad\" for 3s · PHONE: cracked for 2s · PHONE: cracked, shadow face for 2.5s.")
	lines.append("- Sketch looks (1.13+): hair long | bob | bun | short | curl | none, hair <colour>, hoodie <colour> (or shirt/sweater), fuzzy (a furry scribbled shadow). Example: Mira = sketch person, hair long, hair #3a2418, hoodie mustard. Faces also: crying, asleep, proud, hopeful, worried, laughing; verbs: cries, beams, worries, laughs, sleeps, wakes up. Faces ease from one to the next.")
	lines.append("- Growing and shrinking (1.13+): \"Someday grows to 2.3 over 1s\", \"Someday shrinks to 0.5 over 2s\", \"Someday shrinks back\" (a habit or fear that gets bigger or smaller). Take no time; shots frame the new size.")
	lines.append("- Paper colour per scene (1.13+): \"LIGHT: paper #2e3550\" (or \"... over 2s\") changes the page colour with the mood; text turns light on dark pages.")
	lines.append("- Close-up inserts (1.13+, take their time like WAIT): NOTE: \"THIS YEAR\" \"Learn guitar\" \"Run 5k\" strike 1, add \"Play ONE song\" for 5s (a sticky note; the first line is the heading, strike numbers count the lines under it, struck one by one, added lines written in red) · CALENDAR: \"March\" start 4, done 4-17, missed 1-3, first day wed for 5s (ticks appear day by day) · WORDS: Mira \"too late\" \"no talent\" \"why bother\" for 4s (self-doubt words drifting around her head; takes no time, add WAIT).")
	lines.append("- Instruments (1.13+): \"Mira plays guitar for 4s\" holds an object from the SET across the body and strums (picks it up first if needed; works sitting). Set her face before the plays line. \"puts down guitar at (0.5, -0.55)\" puts it back in its corner.")
	lines.append("- Posts (1.14+): POST: \"@maya.wanders\" \"Paradise again.\" 2341 likes for 4s freezes the moment as a social post (a flash, a white frame around the live shot, likes counting up, the caption). Takes its time like WAIT. Pair it with a selfie: \"Maya holds phone high\" (any object named phone) raises it at arm's length. Invent app and user names.")
	lines.append("- Documentary tools (1.20+, any look): NUMBER: 2887000000000 prefix \"$\" \"was spent on militaries in 2025\" \"Source: SIPRI, April 2026\" for 7s shows a big statistic counting up in the middle, with a label and a small source line (\"dim\" darkens the picture behind it, \"paper\" puts it on a plain page, suffix \"people\" adds a word). Takes no time; add a WAIT. Always give the source and the year of real figures.")
	lines.append("- SPLIT: \"MILITARY\" from (x, y, z) to (x, y, z) | \"PEOPLE\" from (x, y, z) to (x, y, z) for 7s shows two live camera views side by side (camera position, then what it looks at; each pushes in slowly) with a label on each half; it dissolves back to the current shot at the end. Takes no time; add a WAIT.")
	lines.append("- Live counter: COUNTER: \"SPENT SINCE YOU PRESSED PLAY: ${n}\" rate 91546 counts up by that amount per second of film. Objects can hang in the air (SET: jet = models/jet.glb at (0, -10), up 20; it keeps its height when it \"flies to\" somewhere), spin (\"globe spins 90 over 30s\") and climb straight (\"rocket rises steady 150m over 10s\").")
	lines.append("- 1.21+: \"cartoon person\" characters (settings as in CARTOON STYLE) also work in the 3D locations, lit like the world, with faces that turn to the camera. Floating things: SET: boat = models/boat.glb at (x, z), afloat, facing (x, z) rides on the water (put \"afloat\" before \"facing\") and rocks as it \"sails to\" somewhere.")
	lines.append("- 1.22+: REALISTIC PEOPLE (game-quality humans with real motion capture): realistic man (Arjun), realistic woman (Maya), realistic boy (Tenzin), realistic girl (Mila), realistic grandfather (Hari), realistic grandmother (Kamala), realistic David, realistic Amara. Settings: shirt <colour>, trousers <colour>, shoes <colour>, hair <colour>, height <scale>. They walk, run, sit, kneel, wave, talk, cheer, laugh, cry, jump, dance, pick things up, and show faces (looks happy/sad/angry/shocked...). Extra actions: \"does Sad Walk\", \"does Phone\", \"does Happy\", \"does Sad\", \"does Cry\".")
	lines.append("- Clothes for sketch people (1.14+): pants <colour> (or jeans/trousers/skirt); anyone with a hoodie/shirt gets jeans and shoes by default. A sketch person who appears somewhere new stops sitting/lying automatically.")
	lines.append("- Placement (1.15+): small objects (mug, laptop, desk lamp, cake...) placed \"at\" a spot over a desk or table go on top of it; \"puts down cake at (x, z)\" does the same. Vehicles in a package should be built nose-first so \"bus drives to (x, z)\" shows their side; place them \"facing\" the way they'll drive. In the flat look WEATHER: rain 0.6 works, and \"SHOT: follow Mina\" tracks a walk past the street.")
	lines.append("- WORDS colour (1.16+): WORDS: Mira \"you can do it\" \"I'm proud of you\" color #e8a33d for 4s sets the colour of the swirling words (warm for kind words, cold blue-grey for harsh ones).")
	lines.append("- Sketch objects (Sketch category): desk, chair, sofa, bed, desk lamp, floor lamp, books, open book, bookshelf, door, window, mirror, laptop, phone, mug, bin, plant, wall clock, tv, bottle; and lights: warm glow, screen glow, cool glow, red glow, violet glow (a soft pool of light). Sketch Stage places: center, left, right, far left, far right, room 2 (x 16), room 3 (x 32).")
	lines.append("- Tips: few words, slow pacing, lots of WAIT; full and medium shots side-on; close-ups for faces; keep everyone within about 6 m for two-shots.")
	lines.append("")
	lines.append("## LOCATIONS and their named places")
	lines.append("Set the first location in the header. To move to another one, start a scene with a line \"LOCATION: Classroom\" (switch back the same way). A film can combine ONE nature location (Lakeside Campfire, Forest Lake, Seaside Village, Mountain River, Golden Valley) with any number of the others (rooms, studios, streets). Characters must be placed again after a location change (\"Mira enters at doorway\").")
	for name in ScriptDirector.LOCATIONS:
		var info: Dictionary = ScriptDirector.LOCATIONS[name]
		var marks: PackedStringArray = []
		for mark in (info["marks"] as Dictionary):
			marks.append(str(mark))
		lines.append("- %s%s: %s Places: %s." % [name, " (indoor)" if bool(info.get("indoor", false)) else "", info["about"], ", ".join(marks)])
	lines.append("Every object already in a location is also a place, by its name (\"campfire\", \"bench\", \"sofa\", \"chair 3\", \"hut 2\"…).")
	lines.append("")
	lines.append("## TIME AND WEATHER PRESETS")
	lines.append("- TIME presets: " + ", ".join(PackedStringArray(EnvironmentController.PRESETS.keys())))
	lines.append("- WEATHER presets: " + ", ".join(PackedStringArray(EnvironmentController.WEATHER_PRESETS.keys())))
	lines.append("")
	var catalog := PropCatalog.scan()
	var characters: PackedStringArray = []
	var animals: PackedStringArray = []
	var avatars: PackedStringArray = []
	var by_category := {}
	for prop in catalog:
		var category := str(prop["category"])
		var title := str(prop["display_name"]).to_lower()
		if category == "Characters":
			characters.append(title)
		elif category == "Animals":
			animals.append(title)
		elif category == PropCatalog.MY_CHARACTERS_CATEGORY:
			avatars.append(str(prop["display_name"]))
		else:
			var list: PackedStringArray = by_category.get(category, PackedStringArray())
			list.append(title)
			by_category[category] = list  # packed arrays are copied: store it back
	lines.append("## CHARACTERS (CAST: Name = <model>, settings…)")
	lines.append("- Built-in people: " + ", ".join(characters) + ".")
	lines.append("- Animals: dog, " + ", ".join(animals) + ". They walk, run and turn; actions: Idle, Walk, Run, Sit (dogs, cats, tigers, lions, bears, monkeys, rabbits), Lie Down, Eat, Look Around; birds: Peck, Flap Wings. Settings: colour <colour>.")
	lines.append("  Built-in people can be customised: top <colour>, bottom <colour>, shoes <colour>, skin <colour or #hex>, hair <colour>, hair " + "/".join(HumanCharacter.HAIR_STYLES).to_lower() + ", clothes " + "/".join(HumanCharacter.BOTTOM_STYLES).to_lower() + ", height <metres>, build 0.7–1.3, body man/woman/child/elder.")
	lines.append("  Clothes and accessories: sweater <colour> (long sleeves), coat <colour> (a long coat over the top), scarf <colour>, beanie (knitted, in the scarf colour), glasses.")
	lines.append("  Example: Mira = woman casual, top teal, bottom navy, hair long, height 1.62, scarf #8e3b46")
	lines.append("  Example: Harold = elder, coat #4a3a2c, scarf #8e3b46, beanie, glasses, hair bald, hair white")
	lines.append("  Automatic voice per character (with VOICES: auto): add \"voice female\", \"voice male\", \"voice child\", \"voice elder\", \"voice deep\", \"voice high\", \"voice slow\" (they combine). Default follows the body type.")
	if not avatars.is_empty():
		var quoted: PackedStringArray = []
		for avatar in avatars:
			quoted.append("\"%s\"" % avatar)
		lines.append("- The user's OWN characters (realistic avatars; prefer them for realistic films). Use: Name = my character \"<name>\", voice male. Available: " + ", ".join(quoted) + ".")
	lines.append("- Built-in people's actions: " + ", ".join(MotionLibrary.ACTIONS) + ".")
	var packs := ImportedCharacter.animation_packs().keys()
	if not packs.is_empty():
		var titles: PackedStringArray = []
		for pack in packs:
			titles.append(str(pack))
		lines.append("- Extra animations for avatars (use \"Name does <animation>\"): " + ", ".join(titles) + ".")
	lines.append("")
	lines.append("## OBJECTS (for SET:)")
	var own: PackedStringArray = []
	for category in by_category:
		if category == PropCatalog.IMPORTED_CATEGORY or category == PropCatalog.DOWNLOADED_CATEGORY:
			for title in by_category[category]:
				own.append("\"%s\"" % title)
			continue
		lines.append("- %s: %s" % [category, ", ".join(by_category[category])])
	if not own.is_empty():
		lines.append("- The user's OWN props (imported or downloaded, usually realistic). Use: id = my prop \"<name>\" near <place>. Available: " + ", ".join(own) + ".")
	lines.append("")
	lines.append("## VOICE EFFECTS for recorded dialogue: " + ", ".join(PackedStringArray(AudioTrack.VOICES.keys())))
	var sounds := _audio_files()
	if not sounds.is_empty():
		lines.append("## SOUND FILES already in the library: " + ", ".join(sounds))
	lines.append("")
	lines.append("## TIPS FOR A GOOD FILM")
	lines.append("- Place every character before they move (\"Mira is at hill\"). Keep characters within about 40 m of each other outdoors.")
	lines.append("- Vary shots: establishing → medium → close-ups in dialogue → a wide or aerial ending. 3–8 seconds per shot feels cinematic.")
	lines.append("- Keep dialogue lines short (under 15 words). Put a WAIT 1s between emotional beats.")
	lines.append("- One action per line. Use \" &\" for things happening together.")
	lines.append("- Use TIME/LIGHT changes for mood (sunset to night, mist rising), and a TITLE at the start and THE END at the finish.")
	if not story.strip_edges().is_empty():
		lines.append("")
		lines.append("## THE STORY TO FILM")
		lines.append(story.strip_edges())
	else:
		lines.append("")
		lines.append("## THE STORY TO FILM")
		lines.append("(Write your story idea here, e.g. \"A 40-second film: a boy loses his kite in the city and an old man helps him find it.\")")
	return "\n".join(lines)


static func _audio_files() -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(AudioTrack.AUDIO_DIR)
	if dir:
		for file_name in dir.get_files():
			if AudioTrack.EXTENSIONS.has(file_name.get_extension().to_lower()):
				out.append(file_name)
	return out

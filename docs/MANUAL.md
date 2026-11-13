# Scene Builder 1.28 — User Guide

Back to the [README](../README.md) · [Changelog](../CHANGELOG.md)

## Contents
1. [Install and run](#1-install-and-run)
2. [Three ways to make a film](#2-three-ways-to-make-a-film)
3. [The window](#3-the-window)
4. [Films from a script](#4-films-from-a-script)
5. [Film packages](#5-film-packages)
6. [Building a set by hand](#6-building-a-set-by-hand)
7. [The world: terrain, plants, water, weather, effects, sky](#7-the-world-terrain-plants-water-weather-effects-sky)
8. [Characters](#8-characters)
9. [Cameras](#9-cameras)
10. [Timeline and animation](#10-timeline-and-animation)
11. [Titles, music, sound and voices](#11-titles-music-sound-and-voices)
12. [Exporting your film](#12-exporting-your-film)
13. [Saving, files and folders](#13-saving-files-and-folders)
14. [Keyboard and mouse](#14-keyboard-and-mouse)
15. [Included films and examples](#15-included-films-and-examples)
16. [Optional helper programs](#16-optional-helper-programs)
17. [Troubleshooting and known limits](#17-troubleshooting-and-known-limits)
18. [For developers](#18-for-developers)

---

## 1. Install and run

### The ready-made app (recommended)
- **Windows:** unzip `SceneBuilder-1.28-Windows.zip` and double-click `SceneBuilder.exe`.
  Windows SmartScreen may say "unknown publisher" the first time: choose *More info → Run anyway*.
- **Linux:** run `SceneBuilder.x86_64` (make it executable with `chmod +x` if needed).
- The window title shows the version (`Scene Builder 1.28`).
- Needs a graphics card that runs Vulkan (Godot's Forward+ renderer). Any GPU from the last ~8 years.

### From the source code
1. Install **Godot 4.3 or newer** (standard build, no .NET).
2. Godot → **Import** → choose `scene-builder/project.godot` → **Import & Edit**.
3. Press **F5** (Run Project).

### First run
A short **guided tour** highlights each part of the window. Reopen it any time with **Help**.

---

## 2. Three ways to make a film

| Way | Best for | Start with |
|---|---|---|
| **From a template** | Learning, quick results | **New → Templates** (e.g. *My First Film: The Lantern*), press **Play Cinematic** |
| **From a script** | Whole stories in minutes, AI-written films | top bar **Script** → write / paste / open a package → **Build Film** → **Watch** |
| **By hand** | Full control of every object, key and shot | **New → Blank World**, drag in assets, add cameras, key the timeline |

All three end in the same place: an ordinary scene you can change by hand, save, and export as a video.

---

## 3. The window

- **Top bar** — New, Open, Save, Undo/Redo, **Script**, **Play Cinematic**,
  **Export Video**, Help.
- **Asset Library (left)** — every placeable thing in categories (Characters, Buildings, Nature,
  Furniture, Interior, Hospital, Stage, City, Lights, Vehicles, Decorations, Water, Effects, Imported,
  My Characters), plus the **Online** tab (Poly Haven, Poly Pizza, BlendKit) and **Import**.
- **3D view (centre)** — build here. **Tab** switches between the editor view and **Camera View**
  (what the film will show, with letterbox bars).
- **Inspector (right)** — tabs for the selected **Object** (position, rotation, scale, settings,
  surface texture), **Character**, **Camera**, **Scene** (time of day, sky, ground, fog, exposure,
  weather, render quality), **World** (terrain, plants, paths) and **Film** (titles, music, voices).
- **Timeline (bottom)** — playhead, keyframes per object, action labels, camera cuts, length, play
  controls, Auto-Key, motion style.

---

## 4. Films from a script

Top bar → **Script**. A screenplay becomes a complete film: location, set dressing, characters and
their looks, every walk, gesture and line of dialogue (with lip sync, subtitles and spoken voices),
light and weather changes, music, sound effects, titles, and the camera shots with their cuts.

### 4.1 The Script window
- **Open…** — a script file, a film package `.zip`, or a package folder.
- **Paste** — paste a script from an AI chat (code-block fences are removed for you).
- **Example** — loads *The Promise*, a 58-second sample film.
- **Save Script…** — save what's in the editor.
- **Copy AI Instructions** — type your story idea in the box first. The copied text tells an AI the
  format and lists *everything installed in your Scene Builder right now* (locations and their places,
  objects, people, your avatars, animation packs, voices, sounds). Paste it into Claude, ChatGPT or
  another AI, then paste its script back.
- **Export My Library…** — saves one .zip about *your* things: every character in My Characters,
  every imported or downloaded prop, animation packs and sounds, with exact script names, sizes,
  actions, whether a character can lip-sync and blink, a picture of each and contact sheets.
  - *List only* (recommended, small): enough for an AI to write a film around your things.
  - *Include files*: adds the model files (textures shrunk to 1024 px, nothing else changed), so an AI
    that can run Scene Builder can build and test the film before giving it to you.
  Attach it to Claude together with FILM_PACKAGE_PROMPT.md and your story idea. Face photos are never included.
- **Speak dialogue** — tick to have every line spoken by the computer's voices (also `VOICES: on`).
- **Build Film** — builds the film. The **report** lists what was built, anything replaced with a
  close match, anything missing, and any line it didn't understand (with the line number). Your draft
  is kept between sessions.
- **Watch** — plays the built film from the start in Camera View.

Building replaces the current scene (you're asked first if it has unsaved changes). Afterwards everything
is normal scene content: move a camera, retime a key, fix a title, then Save.

For writing complete packages with an AI — props, music and all — use **FILM_PACKAGE_PROMPT.md**
(see [section 5](#5-film-packages)).

### 4.2 The format in one look
```
REQUIRES: Scene Builder 1.5.1
TITLE: The Promise
LOCATION: Lakeside Campfire          # a built-in location
TIME: 18.0 -> 19.0                   # hour, or Morning/Noon/Sunset/Night/Overcast; "A -> B" sweeps it
WEATHER: mist 0.3, wind 0.25         # or a preset: Clear, Breezy, Rain, Storm, Snowfall, Misty morning, Autumn
MUSIC: theme, volume -5
VOICES: on

CAST:
Mira = woman casual, top teal, bottom navy, hair ponytail, height 1.64, voice female young
Grandpa = elder, top brown, voice deep slow

SET:
lamp = torch right of bench, facing campfire

SCENE 1: The way home
Grandpa sits on bench
Mira is at hill
SHOT: establishing, crane down
TITLE: THE PROMISE for 4s
Mira walks to clearing via path
SHOT: medium on Grandpa, from left, dolly in
Grandpa: "I knew you would come back before dark."
Mira (waves): "I promised, didn't I?"
```

Your own things (Scene Builder 1.8+): `Hero = my character "Nabin Avatar", voice male` in CAST and
`lamp = my prop "Brass Lamp" on side table` in SET use items from My Characters and your imported or
downloaded models. If the package includes the file (`characters/Nabin_Avatar.glb`), it works on other
computers too.

### 4.3 Everything a script can do
**Header** — `REQUIRES`, `TITLE`, `LOCATION`, `TIME` (`A -> B` to sweep), `WEATHER`, `LIGHT`,
`MUSIC`, `VOICES: on|off`, `SUBTITLES: on|off`, `CAMERA: auto|manual`, `STYLE: flat` (Flat sketch look) or `STYLE: paper` (Paper look).

**Timing** — lines run one after another (a walk lasts as long as the walk, a line of dialogue as long
as the sentence). End a line with `&` to start the next one at the same moment. `WAIT 2s`, `AT 12s`,
and `for 4s` on any action. SHOT/TITLE/MUSIC/SOUND/TIME/WEATHER/LIGHT lines take no time.

**Cast** — built-in people (man, woman, woman casual, child, elder, man suit, dog; also words like
teacher, boy, student, grandfather, doctor), your avatars, or a package's rigged `.glb`/`.fbx`.
Looks: `top / bottom / shoes / skin / hair <colour or #hex>`, `hair short|long|bun|ponytail|bald`,
`clothes trousers|shorts|skirt`, `height <m>`, `build 0.7–1.4`, `body man|woman|child|elder`.
Voices: `voice male|female|boy|girl|child|elder|young`, `deep|high|slow|fast`, or a voice by name.

**Set** — `id = <object or models/file.glb> [scale N] at|near|on|in front of|behind|left of|right of <place>[, facing <place>]`.

**Characters** —
- place: `is at`, `stands near … facing …`, `enters at` (invisible until then), `disappears`;
- move: `walks / strolls / sneaks / tiptoes / creeps / marches / storms / trots / jogs / runs / dashes /
  sprints to … [via …] [slowly|quickly]`, `leaves to …`;
- `sits on …`, `stands up`, `kneels [at …]`, `lies down [on …]`, `hugs …`;
- `turns to / looks at …`, `points at …`;
- gestures: waves, talks, claps, cheers, laughs, giggles, thinks, looks around, whistles, dances, jumps,
  waits, freezes, nods, shakes head, bows, shrugs, gasps, facepalms, scratches head, sleeps, wakes up;
  `does <animation pack name>`;
- carrying: `picks up …`, `holds … high`, `puts down … [on …]`, `gives … to …`, `lets go of …`;
- hand and body animation: `poses right shoulder -90 0 0, right elbow -40 0 0 over 1s`, `relaxes over 1s`.

  Seated people turn their head instead of their body and can talk, nod, wave and point.

**Dialogue** — `Name: "text"` or `Name (to Other, nods): "text"`. The speaker turns to the listener,
talks with lip sync, a subtitle appears, and the line is spoken if voices are on. Recorded lines:
`Name: "text" [audio: audio/line01.wav] [voice: Robot]` — the mouth follows the recording.

**Objects** — `appears [on|at|near …]`, `disappears`, move (`car drives to street end`,
`plane flies to on teacher desk`, `frog scurries to (x, z)`), turn, and rise or sink with a gentle sway
(`lantern rises 25m over 14s toward lake`, `rock sinks 2m over 3s`, `vase falls 1m`). Lights inside an
object switch off while it is hidden.

**Places** — the location's named places, any object in it (`campfire`, `chair 3`, `school desk 8`),
a SET object, a character, `near / in front of / behind / left of / right of X`, `2m left of X`,
`between X and Y`, `on X`, or coordinates `(12, -4)`.

**Camera** — `SHOT: <type> [on names], [move], [from left|right|behind], [handheld]`.
Types: establishing, wide, full, medium, close-up, extreme close-up, low angle, high angle, aerial,
`two-shot A and B`, `over-shoulder A to B`, `pov A to B`, `follow A`. Moves: dolly in/out, truck
left/right, crane up/down, pan left/right, tilt up/down, orbit left/right, zoom in/out, static.
Framing is automatic: cameras look ahead at where people will be, track people who move, avoid standing
behind other people or furniture, stay inside rooms, and clear trees out of the view. Scenes without
SHOT lines are filmed automatically (establishing or wide opener, two-shots, over-the-shoulders and
close-ups for dialogue, follow shots for walks); gaps longer than 9 s between your own shots are filled
the same way (`CAMERA: manual` turns this off).

**Text** — `TITLE:` (big, centred), `CAPTION:` (top), `LOWER THIRD:` (name card), `SUBTITLE:`,
each `"text" for 4s`; `|` makes a new line.

**Sound** — `MUSIC: music/file.ogg, volume -8`, `SOUND: sfx/file.wav, volume -3, voice Robot`;
`theme` is the built-in music. A MUSIC line adds a track (it doesn't stop the one already playing),
so cut each music file to the length of its section.

**Light** — `TIME: 19.5 over 6s`, `WEATHER: Rain over 5s`,
`LIGHT: mist 0.6, fog 0.01, exposure 1.3 over 8s` (time, sun_azimuth, sun, clouds, fog, ambient,
exposure, wind, wind_direction, rain, snow, mist, leaves, snow_cover).

**Several locations** — start a scene with `LOCATION: Classroom` to cut there, and back the same way.
One nature location combines with any number of rooms, studios and streets; each keeps its own lighting.
Place the characters again after a switch.

**Version** — `REQUIRES: Scene Builder 1.5.1` makes older versions warn you instead of silently
skipping lines.

**JSON** works too: `{ "title", "location", "time", "weather", "music", "cast": {"Mira": "woman casual"},
"set": ["…"], "scenes": [ {"name": "…", "lines": ["…"]} ] }`.

**Flat sketch extras (1.9)** — with `LOCATION: Sketch Stage` and `STYLE: flat`: cast `sketch person`
and `shadow` (settings `color`, `glow`, `lines`, `face`, `height`, `build`); faces with
`Mina looks tired|sad|ashamed|scared|angry|determined|happy|shocked`, `smiles`, `frowns`, `smirks`,
`gasps`, `panics`; floating words with `Later whispers: …` / `Mina thinks: …`; `COUNTER: "DAYS CLEAN: 3"`
(top-right until the next COUNTER, `COUNTER: off`); full-screen phone moments
`PHONE: home | notification "App" "Text" | message "Mom" "Hi" "Hi!" | feed "Clips" | dialog "Delete?" "Cancel" "Delete" … taps Delete | call "Dad" | cracked[, shadow face]`
with `at 1:41` for the clock and `for 3s` for the length. See `examples/just_one_more.zip`.

### 4.4 Locations
| Location | Places |
|---|---|
| Blank World | center, north, south, east, west |
| Lakeside Campfire | lake, shore, hill, path, clearing, center |
| Forest Lake | lake, shore, meadow, forest edge, center |
| Seaside Village | beach, shoreline, village, sea, center |
| Mountain River | riverbank, far bank, waterfall, valley trail, center |
| Rainy Night Street | street, left/right sidewalk, street end, street start, center |
| Big City | crossing, left/right sidewalk, north street, south street, center |
| Golden Valley | meadow, flowers, hillside, center |
| Classroom (indoor) | front, back, aisle, center — 12 numbered desks and chairs, door in the right wall |
| Hospital Ward (indoor) | bedside, waiting area, center |
| Living Room (indoor) | center, doorway, hallway, by the tv, window |
| Comedy Club (indoor) | stage, stage left, audience, center |
| News Studio (indoor) | anchor seat, guest seat, studio floor, center |

Exact indoor layouts (desk numbers, door positions, walking aisles) are in **FILM_PACKAGE_PROMPT.md**.

### 4.5 Automatic voices
With **Speak dialogue** ticked (or `VOICES: on`), every line without a recording is spoken by your
computer's own voices: Windows' built-in voices, macOS `say`, eSpeak on Linux, or **Piper** neural voices
if you add `[voices] piper_path=…` and `piper_model=…` to `settings.cfg`. Voices follow the body type
and the CAST `voice …` setting. Lip sync follows the spoken audio, the voice changer still applies, and
voices are cached so rebuilding is instant.

---

## 5. Film packages

A **film package** is a folder or `.zip` holding a script and the files it uses:
```
my_film/
  film.script          (or any .script / .txt / .json)
  README.txt           what it is and how to watch it
  models/              .glb / .fbx objects        → SET:  lamp = models/paper_lantern.glb near bench
  characters/          rigged .glb / .fbx people  → CAST: Hero = characters/hero.glb
  animations/          Mixamo .fbx / .glb packs   → added to your animation library
  music/  sfx/  audio/ .ogg / .wav / .mp3 music, effects and recorded dialogue
  tools/               (optional) the scripts that made the models and sounds
```
**Script → Open…** the package (or its folder) and press **Build Film**. Its files are copied into your
library, so saved projects keep working without the package.

**Make packages with any AI:** give it **FILM_PACKAGE_PROMPT.md** with your story idea at the bottom.
It explains the format, every location, object, gesture and camera option, the rules that keep a film
clean, how to make props in Blender and original music in Python, and includes a complete sample package
(*Chiya Break*).

---

## 6. Building a set by hand

### Placing things
- Drag a card from the Asset Library into the 3D view. A see-through ghost follows the cursor and rests
  on the ground or on other objects. **R** rotates it 45°, **Shift+R** the other way.
- Click a card to place several in a row; **Esc** stops. Hold **Shift** on drop to keep placing.
- Click an object to select it (orange outline); drag to move; edit position, rotation and scale in
  **Inspector → Object**. **Delete**, **Ctrl+D** duplicate, **F** frame it, **End** drop to the ground.

### Built-in assets
- **Characters:** man, woman, woman casual, child, elder, man in suit — customisable and animated; dog.
- **Buildings:** hut, fence, stone wall, watch tower, and rooms (*Room, Classroom, Hospital, Living,
  Studio room*): floor style (wood, tiles, carpet, concrete), wall and lower-wall colours, windows,
  doorway, ceiling, optional front wall, any size.
- **Interior / Hospital / Stage:** desks, blackboard, whiteboard, sofa, armchair, TV, bed, kitchen
  counter, fridge, rug, office chair; hospital bed, IV stand, screen, cabinet, waiting chairs, reception;
  stage platform, mic stand, bar stool, brick backdrop, curtain, news desk, video wall.
- **City:** glass tower, office, apartment and brick buildings (any number of floors; windows light up
  at night), roads (lanes, pavements, zebra crossing; shiny when wet), traffic lights, bus stop, bins.
- **Lights:** ceiling lamp, spotlight (rotate to aim), soft panel, bare bulb — colour, brightness, reach,
  beam and shadows. Essential indoors.
- **Nature, Furniture, Vehicles, Decorations:** trees, bushes, rocks, bench, chair, table, bookshelf,
  car, van, bus, cart, barrel, crate, flower pot, lamp post, signpost.
- **Water** and **Effects:** see [section 7](#7-the-world-terrain-plants-water-weather-effects-sky).

### Online models (Asset Library → Online)
- **Poly Haven** — realistic CC0 models, no account needed.
- **Poly Pizza** — 10,000+ low-poly models (CC0 / CC-BY). Needs a free API key from poly.pizza
  (*Settings → API*), pasted in the Online tab.
- **BlendKit** (formerly BlenderKit, the asset library inside Blender) — free models need no
  account; tick off *Free models only* and paste your BlendKit API key to see your plan's models.
  Models BlendKit offers as glTF load straight away. Models that only come as a .blend file are
  marked **(Blender)**: Scene Builder runs your own Blender in the background to convert them
  (Blender 3.6 or newer; found automatically in *C:\Program Files\Blender Foundation*, or set it
  with **Blender…**). Complex Blender materials are simplified to their colours and textures.
  Licences are BlendKit Royalty Free or CC0; authors go into the credits file.
- Click a card to download it, then click or drag it to place. Downloads live in **Library → Downloaded**
  and work offline. Every export writes `<film>_credits.txt` listing the downloaded models used.
  Projects re-download online models when opened on another computer.

### Your own files (Asset Library → Import)
- **Import model** (.glb / .gltf / .fbx) → *Imported* category.
- **Import rigged character** → *My Characters* (see [section 8](#8-characters)).
- **Import animation pack** → actions for every imported character.
- Lights inside imported models are brought to sensible levels (Blender's watts would otherwise arrive
  hundreds of times too bright), get a practical range, and switch off while their object is hidden.
- **Surface textures:** select any object → *Surface → Choose Texture…* to cover it with a Poly Haven
  material (brick, wood, concrete…), then set the tile size.

---

## 7. The world: terrain, plants, water, weather, effects, sky

### Templates (New → Templates)
Forest Lake, Seaside Village, Mountain River, Rainy Night Street, Classroom, Hospital Ward, Living Room,
Big City, Golden Valley, Stand-up Comedy, News Studio, and **My First Film: The Lantern**. Each is a
finished scene with people and a camera move already keyed — press Play Cinematic, then change anything.
**Blank World** (Ctrl+N) starts an empty flat world.

### World tab (Inspector → World)
Pick a tool, then click-drag on the ground (right-drag still orbits; Esc stops the tool). Every stroke
is one undo step and is saved with the project.
- **Shape the land:** Raise, Lower, Smooth, Flatten. The terrain is a 256 m square in the middle of the
  world; flat ground continues around it.
- **Paint the ground:** Dirt, Rock, Sand, Snow, or the Scene tab's ground style to erase. Steep slopes
  turn to rock automatically.
- **Plants & rocks:** paint or erase grass, tall grass, flowers, bushes, broadleaf and pine trees and
  rocks, thousands at a time. They sway in the wind and follow the land when you sculpt.
- **Paint With a Model…:** use any downloaded, imported or built-in model as a brush (forests of real
  Poly Haven trees, fields of rocks).
- **Character path:** select a character → *Draw Path* → click points → Enter. It walks, jogs or runs
  there from the playhead, following the hills. Works for any object (cars drive the path facing forward).

### Water (Asset Library → Water)
Pond, Round Pond, Lake, River, Stream, Rapids, Sea And Beach. Select one for the **Water** section:
ready-made looks (clear lake, tropical, mountain lake, murky pond, muddy river, deep sea); colours,
clearness, depth; waves, ripples and foam; river width, length, bends and flow; breaking sea waves; bank
type (mud, sand, pebbles, grass). **Carve Into Terrain** digs the land to fit the water for true
shorelines. Water moves identically in playback and every export. Objects can float on it.

### Weather (Scene tab → Weather)
Presets — Clear, Breezy, Rain, Storm, Snowfall, Misty morning, Autumn — and sliders for wind, wind
direction, rain, snowfall, snow on the ground, mist and falling leaves. Rain makes the ground dark and
shiny; snow settles on ground, plants and rocks; wind bends plants, rain, snow, smoke and flames.
All of it can be keyed on the timeline.

### Effects (Asset Library → Effects)
Campfire, Torch, Brazier (flames, smoke and flickering shadow-casting light), Chimney Smoke, Steam,
Ground Mist, and Waterfall (water over a rock cliff, foaming pool, spray). Each has its own settings.

### Light, sky and look (Scene tab)
- **Time of day** with Morning / Noon / Sunset / Night / Overcast presets; sun direction and strength,
  fog, ambient light, exposure.
- **Sky:** *Automatic* follows the time of day; *Custom* colours; drifting clouds (amount, speed);
  **Photo sky** downloads a real 360° HDRI from Poly Haven that lights the scene (rotate, brightness).
- **Ground:** grass, dry grass, dirt, sand, snow, rock, asphalt (procedural, never visibly tiled), a
  plain colour, or a Poly Haven photo texture.
- **Render quality:** *Preview* (fast), *High* (global illumination, reflections, soft shadows, fog),
  *Cinematic* (everything at the top setting). Export has its own setting, so you can build in Preview.

---

## 8. Characters

### The Characters page (new in 1.23)
Top bar → **Characters**. Left: the kind (Realistic, Animated film, Cartoon, Sketch, Animal), ready-made
starting points and *My characters*. Middle: the preview (drag to turn, wheel to zoom; Action and Face
lists; Full / Face / Side views). Right: every setting, in tabs (Body, Face, Skin, Hair, Clothes, Style for
people; Animal for animals). **Surprise me** makes a random one. **Save** / **Put in scene**.
Clothes tab → *Import clothes from a character…*: a .glb / .gltf / .fbx from Avaturn, Ready Player Me,
Mixamo or MakeHuman. Its clothes (and hair) are saved in your wardrobe and listed with tick boxes.

### Built-in people
Select one → **Inspector → Character**: body type (man, woman, child, elder), height, build, hair style
and colour, skin, top, bottom and shoe colours, trousers/shorts/skirt.
- **Actions:** Auto (walks or runs to match how fast they move, idles when still), Idle, Walk, Run,
  Wave, Talk, Point, Clap, Cheer, Think, Look Around, Sit, Kneel, Lie Down, Hug, Dance, Jump, Pose only.
  Choose one and press **Start This Action at Playhead**; actions blend smoothly and show as green labels
  on the timeline.
- **Faces:** they blink, and move their lips when talking or lip-synced.

### Pose by hand
Two ways, which work together (both set the same pose keys at the playhead, shown as diamonds on the
timeline; set poses at different times and the character moves smoothly between them):

**Drag in the 3D view.** Select a character and press **P** (or *Inspector → Pose by hand → ✋ Pose in the
3D View*). Dots appear on the joints (blue = left side, orange = right, yellow = head and body) with
lines along the limbs.
- **Drag a dot:** that limb turns to point at the mouse (drag the shoulder to swing the whole arm, the
  elbow to bend the forearm, the head to look somewhere).
- **Shift-drag a dot:** twist the joint around its own axis (turn a hand or a foot).
- The picked joint turns white and is chosen in the Inspector, so you can fine-tune it with the sliders.
- Each drag is one undo step. Press **P** again to leave pose mode. Dots never appear in Camera View
  or in the exported film.

**Sliders.** Pick a joint (head, neck, chest, spine, hips, shoulders, elbows, wrists, hips, knees,
ankles) and bend, turn or tilt it. *Reset Joint* and *Clear All Poses* undo hand posing.

Poses add on top of any action (turn the head while walking), or choose the **Pose only** action to
animate completely by hand. Works on built-in people and on avatars/imported characters.

### Lip sync (Inspector → Lip sync, with a character selected)
- **● Record Line for This Character** — put the playhead where the line starts, press it, speak, press
  **■ Stop and Sync Mouth**. The recording is added as a clip at the playhead and the mouth follows it.
  A level bar shows your microphone is working.
- **From an existing clip** — pick any clip from the Film tab in the menu (▶ listens to it) and press
  **Sync Mouth to Clip**.
- A character can lip-sync to **several clips**: each sync is added to the earlier ones.
- **Watch Line** plays the film from just before the chosen clip so you can check it.
  **Remove Lip Sync** clears it (the Talk action still moves the mouth).
- Works for built-in people, models with face blend shapes (`jawOpen`, `viseme_aa`…) and avatars with
  a jaw bone. .wav works directly; .mp3/.ogg need FFmpeg. Script films lip-sync automatically.
- Tip: also start the **Talk** action for head and hand gestures while speaking.

### Avatar Studio (Asset Library → Avatars button)
Realistic, rigged humans built with Blender and the free **MPFB2** (MakeHuman) add-on.
- **Body tab:** sex, age, height, weight, muscle, proportions, ethnicity mix, skin, hair, clothes and
  **skeleton** (*Game engine — best for Mixamo* (default) or *Default — detailed*), then **Build**.
  Blender runs in the background and the avatar appears in *My Characters*. Settings are remembered per
  avatar, so you can tweak and Rebuild.
- **Find Installed Assets** lists every hairstyle, clothing item and skin installed in MPFB2; pick
  several clothes and hairstyles. With **Include wardrobe**, every outfit and hairstyle is built in and
  can be switched instantly later.
- **Face from a photo:**
  1. **Choose Photo…** — a clear, front-facing photo: even light, looking straight at the camera,
     neutral expression, no glasses, hair off the face if possible. Bigger is better (at least ~600 px
     across the face).
  2. **Find Points Automatically** (needs Blender set below; the first time it downloads MediaPipe and
     its face model, ~100 MB, so be online once). Or click the centre of the left eye, the right eye and
     the middle of the mouth — the other points are placed from an average face.
  3. Check the 18 dots and **drag** any that are off. Hover a dot to see its name (and where it is on the
     little face diagram); **mouse wheel** zooms, **right-drag** moves the picture, **Fit View** resets,
     **Mark Again** starts over.
  4. Optional **side photo** of the same person in profile (either side): click the 5 points it asks for
     (eye corner, nose tip, mouth corner, bottom of the chin, ear hole).
  5. **Build / Rebuild Character.**
  Options: **Photo strength** (how much of the photo vs. the avatar's own skin), **Shape the head to
  match the photo** (on by default), **Even out the photo's lighting** (on by default) and **Talking
  face** (mouth and blink shapes for lip sync; on by default). The photo and points are remembered with
  the avatar, so you can adjust and rebuild. Avatars made with older versions keep their 3 marks; open
  them, check the dots that now appear, and rebuild for the new face.
- **Look tab:** instant height, colour of every material (skin, hair, each clothing piece), show/hide
  parts, Outfit and Hairstyle menus. Saved with the avatar and used by every copy in your scenes.
- **Animation tab:** play any action, including Mixamo packs, or preview Auto walking/running on a
  turntable (drag to turn, wheel to zoom).
- One-time setup: install Blender 4.x or newer and MPFB2 (Blender Extensions, or
  static.makehumancommunity.org/mpfb.html); for hair, clothes and skins also MPFB's system asset pack.
  More choices: install more MakeHuman asset packs in MPFB, then press *Find Installed Assets* again.

### Mixamo and animation packs
1. **Characters:** on mixamo.com pick or upload a character → Download → **FBX Binary, With Skin** →
   Asset Library → Import → *Import rigged character*.
2. **Animations:** pick clips (Walking, Running, Talking, Sitting…; tick **In Place** for walks and runs)
   → Download → **FBX Binary, Without Skin, 30 fps** → Import → *Import animation pack*. The file name
   becomes the action name ("Walking.fbx" → "Walking"). Centimetre-sized files are scaled to metres.
3. Every imported character and avatar gets every pack as an action; *Auto* uses clips named
   idle / walk / run. In scripts: `Hero does Salsa Dancing`.

Packs are matched bone by bone across rig styles (Mixamo, Unreal/MPFB "game engine", Godot humanoid) and
**retargeted through both rest poses**. Since 1.5.1, arms, legs, spine and fingers are first lined up
with the pack's own rest pose, so Mixamo clips (T-pose) play correctly on Avatar Studio avatars (A-pose):
arms no longer sink into the body and raised arms go all the way up. Use the *Game engine* skeleton for
avatars that will use Mixamo clips.

---

## 9. Cameras

- Frame a view (right-drag orbit, middle-drag pan, wheel zoom, **W A S D / Q E** fly) and press
  **Add Camera**. **Tab** looks through the live camera with letterbox bars — exactly what the export shows.
- Select a camera: **field of view**, **depth of field**, **focus distance**, **blur strength**,
  *Look Through*, *Align to View*, *Cut to Camera*, *Focus on Target*.
- **Camera moves:** Dolly in/out, Truck left/right, Crane up/down, Pan, Tilt, Orbit left/right,
  Zoom in/out — with duration and amount, keyed from the playhead.
- **Handheld shake:** a natural hand-held wobble (keyable).
- **Cuts:** select a camera, put the playhead where its shot starts, press **Cut to Camera**. The
  *Camera cuts* row on the timeline shows which camera is live when.

---

## 10. Timeline and animation

- Set the film **Length**. Select something, put the playhead at a time, press **Add Keyframe** (**I**).
  Move it at another time and key again — it travels between the keys.
- **Auto-Key:** every change is keyed at the playhead automatically (objects, camera lens, lighting).
- **Key Lighting at Playhead:** animate time of day, fog, weather, sky (e.g. sunset to night).
- Channels: transform, lens, lighting, character actions, poses, facing; camera cuts.
- Drag diamonds to retime; right-click a diamond to delete. Motion style: *Smooth* (ease in/out),
  *Linear* or *Flowing* (spline).
- **Play Cinematic** plays the whole film through your cuts. **Space** play/pause, **Home/End**,
  **, / .** step one frame. Playback, scrubbing and export are frame-accurate and identical.

---

## 11. Titles, music, sound and voices (Inspector → Film)

- **Text:** titles, subtitles, lower thirds and top captions, each with start and length, fading in and
  out. Shown in the viewport and burned into the exported video.
- **Music & sound:** add .ogg / .mp3 / .wav at the playhead, set start and volume. They play with the
  timeline and are mixed into MP4 exports. `theme` is the built-in score.
- **▶ Listen** to any clip on its own (with its volume and voice effect); press **■** to stop.
- **Record Voice:** record dialogue from your microphone at the playhead (press again to stop). While
  recording, a level bar moves with your voice; if a recording comes out silent you're told how to check
  the microphone. To record a line *for a character* with lip sync, use the character's Lip sync section.
- **Voice changer** on every clip: Deeper, Very deep / giant, Monster, Higher, Child / cartoon, Chipmunk,
  Robot, Phone / radio, Old radio, Big hall echo, Ghost. Heard while playing; MP4 export uses FFmpeg's
  matching filters.
- **Automatic voices** for script films: see [4.5](#45-automatic-voices).

---

## 12. Exporting your film

**Export Video** (Ctrl+E) → choose resolution (720p to 4K, vertical 9:16, square), frame rate
(24/25/30/60), format, quality, lighting quality, folder and file name → **Start Export**. A live preview
shows progress and time left; **Open Folder** when done. Every frame is rendered and waited for, so no
frames are ever dropped; editor visuals (grid, gizmos, outlines) never appear.

| Format | Needs | Notes |
|---|---|---|
| **MP4 (H.264)** | FFmpeg | Small and universal; includes music, sound, voices and voice effects. |
| **AVI (Motion-JPEG)** | nothing | Written by the app itself. Large files, silent. |
| **PNG sequence** | nothing | One lossless image per frame for editing/compositing. Silent. |

**Render in Blender (best quality):** choose it at the top of the export window. Scene Builder prepares
the scene and, if *Render the video now* is ticked, runs Blender in the background with Cycles
(64–512 samples) and shows its progress; the video lands in the `render` folder.

**Export for Blender:** writes `scene.glb`, `animation.json` (every frame of every object, joint and
camera, cuts, the sun), the photo sky and `render_in_blender.py`. In Blender run the script, then
Render → Render Animation. Not transferred: fire/smoke/weather particles and the bone animation of
imported skinned characters (their movement is kept).

---

## 13. Saving, files and folders

- **Save** (Ctrl+S), **Save As** (Ctrl+Shift+S), **Open** (Ctrl+O), **New** (Ctrl+N). A project is one
  human-readable `.json` with the set, cameras, lighting, terrain, plants, keyframes, cuts, titles, audio
  and export settings. **Undo/Redo** (Ctrl+Z / Ctrl+Y) covers every edit, including keyframes.
- Projects remember online models, photo skies and textures and download them again on another computer.
- **Your library** (downloads, imports, avatars, animation packs, audio, cached voices, opened film
  packages, settings) lives in the app's user folder:
  - Windows: `%APPDATA%\Godot\app_userdata\Scene Builder\`
  - Linux: `~/.local/share/godot/app_userdata/Scene Builder/`
  - macOS: `~/Library/Application Support/Godot/app_userdata/Scene Builder/`

  Inside: `library/` (characters, animations, imported, online, audio, voices), `packages/`,
  `settings.cfg`.
- **settings.cfg** keeps your FFmpeg and Blender paths, Poly Pizza key, optional Piper voice
  (`[voices] piper_path`, `piper_model`) and whether you've seen the tour.

---

## 14. Keyboard and mouse

| Action | Input |
|---|---|
| Place one asset / keep placing | Drag a card into the view / hold **Shift** on drop |
| Place several | Click a card, then click in the view; **Esc** stops |
| Rotate placement preview | **R** / **Shift+R** |
| Select / move / deselect | Click / drag / **Esc** |
| Delete / Duplicate / Frame / Drop to ground | **Delete** / **Ctrl+D** / **F** / **End** |
| Editor ⇄ Camera View | **Tab** |
| Play / pause · start · end | **Space** · **Home** · **End** (nothing selected) |
| Step one frame | **,** and **.** |
| Add keyframe for selection | **I** |
| Pose mode (drag a character's joints) · twist | **P** · **Shift**-drag a joint dot |
| Undo / Redo | **Ctrl+Z** / **Ctrl+Y** |
| Save / Save As / Open / New / Export | **Ctrl+S** / **Ctrl+Shift+S** / **Ctrl+O** / **Ctrl+N** / **Ctrl+E** |
| Orbit / Pan / Zoom | Right-drag / Middle-drag / Wheel (trackpad pinch and scroll) |
| Fly | **W A S D**, **Q E** down/up, **Shift** faster (cursor over the view) |

---

## 15. Included films and examples

| Film | Where | What it shows |
|---|---|---|
| **The Lantern** (42 s) | New → Templates → My First Film | Hand-made cinematic: aerial crane, follow, dolly, DoF close-ups, sunset to dusk, original score |
| **The Promise** (58 s) | Script → Example | The script format at its simplest |
| **Night Walk** (36 s) | `examples/night_walk.zip` | A package with a Blender-made glowing paper lantern in the rain |
| **The Last Momo** (~3 min) | `examples/the_last_momo.zip` | Family comedy: sneaking, a dance-off, props that vanish |
| **The Lantern Part Two** (~3¾ min) | `examples/the_lantern_part_two.zip` | Emotional sequel: carrying, kneeling, hugs, rising sky lanterns, two locations |
| **The Surprise Test** (5:47) | `examples/the_surprise_test.zip` | Classroom comedy: 9 characters, 97 shots, flying paper plane, a frog chase, 6 music cues |
| **Chiya Break** (58 s) | `examples/chiya_break.zip` | The sample package from FILM_PACKAGE_PROMPT.md |
| **The Wish** (43 s) | `Films/the_wish.zip` | A short cinematic with no dialogue |
| **The Climb** (~2:30) | `Films/the_climb.zip` | Discipline story: river, storm, mountain, an unseen inner voice |
| **Just One More** (~1:27) | `examples/just_one_more.zip` | Flat sketch style: a glowing shadow whispers, phone close-ups, a day counter |
| **Rain** (~3:50) | `examples/rain.zip` | Realistic 3D: a bus stop, a stranger and an umbrella, night after night |
| **Four Seasons on One Bench** (~3:00) | `examples/four_seasons.zip` | Realistic 3D: one bench through summer, autumn, winter and spring |
| **Bad Influence** (~2:40) | `examples/bad_influence.zip` | Paper look comedy: a little temptation shadow fails at his first job |

In the Windows download, the packages are in the `Films` folder next to `SceneBuilder.exe`.

---

## 16. Optional helper programs

| Program | For | Get it |
|---|---|---|
| **FFmpeg** | MP4 export with sound; .mp3/.ogg lip sync | Windows: `winget install ffmpeg` (or ffmpeg.org), then press *Locate…* in Export if needed |
| **Blender 4.x+** | Avatar Studio, Render in Blender, Export for Blender | blender.org |
| **MPFB2** (Blender add-on) | Building realistic avatars | Blender Extensions / static.makehumancommunity.org/mpfb.html |
| **Piper** | Natural neural voices for script films | github.com/rhasspy/piper, then set `piper_path` / `piper_model` in settings.cfg |

Everything else is built in. Without the helpers you can still build, animate, play, and export AVI/PNG.

---

## 17. Troubleshooting and known limits

- **The film looks too dark/bright:** Scene tab → Exposure, or `LIGHT: exposure 1.2` in a script.
- **A script line was skipped:** the Build report names the line and why. Common fixes: put
  `raises hand` inside dialogue brackets (`Bunty (raises hand): "Miss!"`), stand a seated character up
  before cheering or dancing, use only names declared in CAST/SET.
- **A shot looks at the wrong place indoors:** don't write `from front` (it can be read as the place named
  "front"); use no direction, `from left`, `from right` or `from behind`. For people behind desks, prefer
  medium and close-up shots over two-shots.
- **Music overlaps between scenes:** a MUSIC line doesn't stop the previous track; make each music file
  as long as its section.
- **MP4 export is silent or fails:** install FFmpeg or point *Locate…* to `ffmpeg.exe`.
- **No voices in script films:** tick *Speak dialogue*; on Linux install `espeak-ng`; on Windows check
  that a voice is installed (Settings → Time & Language → Speech).
- **I can't hear my recording / the level bar doesn't move:** check the microphone is the default input
  and that apps may use it (Windows: Settings → Privacy & security → Microphone), then press ▶ on the clip.
- **Mixamo clips look wrong on an avatar:** rebuild the avatar with the *Game engine* skeleton; make sure
  the pack was downloaded *Without Skin*.
- **Avatar build fails:** check Blender's path and that MPFB2 is installed and enabled; the build log
  shows which step failed (MPFB's API can change between versions).
- **Find Points Automatically fails:** it needs the internet the first time (to install MediaPipe and
  download its face model) and a clearly visible, front-facing face. You can always click the eyes and
  mouth and drag the dots by hand instead — the result is the same.
- **Face from a photo doesn't look like the person:** check every dot is exactly on its spot (zoom in),
  use a sharper, evenly lit, straight-on photo, and add a side photo. The likeness comes from a
  MakeHuman head, so it is a close resemblance, not a scan; hair comes from the chosen hairstyle, not
  the photo.
- Built-in people and plants are stylised (generated in code). For realism use Avatar Studio avatars,
  Poly Haven / Poly Pizza models and Mixamo animations.
- Walking characters don't route around furniture; give them waypoints through open floor.

---

## 18. For developers

### Build the standalone app
1. Godot: *Editor → Manage Export Templates → Download and Install* (once).
2. *Project → Export…* → **Windows Desktop** (or Linux / macOS) → *Export Project*. The presets include
   the Blender scripts and example script; results go to `build/`. From the command line:
   `godot --headless --export-release "Windows Desktop" build/windows/SceneBuilder.exe`.
3. Ship `SceneBuilder.exe` (with the `Films` folder of packages if you like). FFmpeg and Blender stay
   optional, user-installed tools. The version lives in `project.godot` (`application/config/version`).

### Tests (`tests/`, left out of exported builds)
- `godot --headless res://tests/SmokeTest.tscn` — builds and plays every template.
- `godot --headless res://tests/ScriptTest.tscn -- <script, folder or .zip> [frames folder] [times…]` —
  builds a film and prints the report, shots and cuts; with a frames folder and a display (or
  `xvfb-run … --rendering-driver opengl3`) it saves what each camera sees.
- `godot --headless res://tests/VoiceTest.tscn -- <package>` — builds with automatic voices, lists clips.
- `godot --headless res://tests/ExportTest.tscn -- <package> <out folder> <name>` — exports an MP4.
- `godot res://tests/RetargetTest.tscn -- <avatar.glb> <pack.glb> <frames dir>` — plays an animation pack
  on an avatar next to the pack's own model and prints per-bone angle errors.
- `godot res://tests/PoseTest.tscn -- [frames dir]` — drags joint dots on a built-in person and an
  avatar like a mouse would and checks each limb points at the mouse, twisting, undo and lip-sync merging.
- `godot res://tests/CharacterUITest.tscn -- <out dir> <a .wav>` — screenshots of the character and Film
  panels; checks clip preview and recording-to-lip-sync.
- `godot res://tests/UITest.tscn` — screenshot of the main window.

### Project structure
```
project.godot                 App settings, version, EventBus autoload
export_presets.cfg            Windows / Linux / macOS builds
scenes/MainApp.tscn           The whole app (world, systems, UI)
assets/props/<category>/      Built-in assets (.tscn)
assets/materials/             Shaders: terrain, foliage, water, weather, fire, smoke, waterfall, grid, outline
assets/scripts/               The Promise (example script)
examples/                     Example film packages
tools/blender/                build_avatar.py (MPFB2), render_in_blender.py (Cycles)
tests/                        Headless tests
scripts/
  core/        EventBus · Layers · SceneClock · SceneSerializer (JSON save files)
  editor/      EditorCamera · EditorHistory (undo + auto-key) · SelectionManager · SelectionHighlight ·
               PoseTool (drag joints in the 3D view) ·
               SceneDocument · TemplateBuilder (templates and script sets) · WorldTools (brushes, paths)
  placement/   PlacementController (ghost placement) · PropCatalog · PropUtils
  cinematic/   CinematicCamera · CinematicDirector · EnvironmentController · KeyframeStore ·
               TimelineController · TitleTrack/TitleOverlay · AudioTrack · ExportManager ·
               AviMjpegWriter · BlenderExport
  script/      FilmScript (reads text/JSON) · ScriptDirector (builds the film: places, movement,
               dialogue, carrying, automatic camera) · FilmPackage (folders/.zip) · AIInstructions
               (the in-app prompt, generated from the installed library) · SpeechMaker (voices)
  characters/  CharacterBase · HumanCharacter · MotionLibrary · CharacterMotion · ImportedCharacter
               (rigged models, animation packs, rest-pose-aligned retargeting)
  nature/      Terrain · Vegetation/PlantMeshes · WeatherEffects · Water (Body, River, Coast, Style) ·
               Effects (Fire, SmokeColumn, Waterfall) · ProceduralProp
  props/       Room · Building · Road · LightProp
  library/     OnlineLibrary (Poly Haven, Poly Pizza, BlendKit, imports, credits) · RuntimeModelLoader
  render/      RenderQuality
  ui/          MainUI · AssetLibraryPanel · OnlineLibraryPanel · InspectorPanel · EnvironmentPanel ·
               WorldToolsPanel · FilmPanel · TimelinePanel/TimelineView · ExportDialog · ScriptDialog ·
               AvatarStudio · TutorialOverlay · and widgets
```

### How it fits together
- The 3D world lives at the scene root; the editor camera renders it inside a SubViewport sized to the
  centre area, so panels never cover the image and UI clicks never reach the world.
- **Camera View** swaps in a shot camera that copies the live virtual camera each frame at the export
  aspect ratio; the exporter uses the same logic off-screen at the export resolution.
- **Timeline:** keyframes are stored per object and channel in `KeyframeStore`, compiled into an
  AnimationPlayer animation plus a discrete camera-cut track. Playback, scrubbing and export all run
  through it.
- **Characters** pose themselves after every seek from their action keys plus a table of how far and
  fast they travel, so walk cycles match movement exactly in playback and export.
- **Script films:** `FilmScript` parses the text; `ScriptDirector` builds the location, resolves places,
  writes every key (transform, action, pose, face, lens, lighting), titles, audio and voices, then plans
  and frames the shots.
- **Undo:** every change goes through `EditorHistory` (Godot UndoRedo); with Auto-Key the keyframe write
  is part of the same undo step. Systems talk through the `EventBus` autoload.

### Save file
Human-readable JSON (`"format": "scene-builder"`): props with stable ids, cameras, lighting, terrain and
plants, timeline keyframes and cuts, titles, audio, export settings and the editor view. Older versions
still open.

---

*Scene Builder 1.28 — all built-in assets, music and example films are original. Downloaded models keep
their own licences (see the credits file written with every export). Mixamo's terms let you use its
characters and animations in your films but not redistribute the files, so none are bundled.*

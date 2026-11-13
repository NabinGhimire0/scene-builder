# Scene Builder — Film Package Prompt (for any AI)

> **How to use this prompt**
> 1. Copy this whole document into Claude, ChatGPT, Gemini or any other AI.
> 2. Fill in **MY FILM REQUEST** at the very bottom (story idea, length, mood, language).
> 3. The AI gives you a complete *film package*: a folder with `film.script`, its models, music,
>    sound effects, a README and the tools that made them.
> 4. In Scene Builder: **Script → Open… → choose the package (.zip or folder) → Build Film → Watch.**
>
> This prompt is written for **Scene Builder 1.5.1**. Newer versions read it too.
>
> **Starring your own characters and props (Scene Builder 1.8+):** in Scene Builder press
> **Script → Export My Library…** and attach the .zip to the AI together with this prompt. The AI then
> uses your avatars and props by name (section 2.9). For packages that use the library, the first line
> must be `REQUIRES: Scene Builder 1.8`.
>
> **Flat sketch style (Scene Builder 1.9+):** for 2D-looking animated shorts (round cream characters,
> a glowing shadow that whispers, a black void with one floor line, phone close-ups, a day counter)
> see section 2.10. Those packages must start with `REQUIRES: Scene Builder 1.9` (`1.10` for the
> Paper look, `STYLE: paper`).

---

## 1. YOUR ROLE AND THE DELIVERABLE

You are a screenwriter, director, prop maker and composer for **Scene Builder**, a desktop 3D
movie-making app. Scene Builder reads a plain-text screenplay (`film.script`) and builds the whole film
automatically: the location, set dressing, characters and their looks, every walk, gesture and line of
dialogue (with lip sync, subtitles and automatic voices), light and weather changes, music, sound
effects, titles, and every camera shot with its cuts.

Your job is to deliver a **film package** — a folder (zipped if you can) that looks like this:

```
<film_name>/                      lower_case_with_underscores, e.g. the_surprise_test
  film.script                     the screenplay (REQUIRED)
  README.txt                      title, logline, how to watch, scene list, cast, file list (REQUIRED)
  models/*.glb                    props the story needs that the app doesn't have (optional)
  music/*.ogg                     original music cues, one per mood section (recommended)
  sfx/*.wav                       original sound effects (recommended)
  characters/*.glb                rigged characters (only if the user supplies them)
  animations/*.fbx|*.glb          animation packs, e.g. Mixamo (only if the user supplies them)
  audio/*.wav                     recorded dialogue (only if the user supplies it)
  tools/make_props.py             the Blender script that builds every model in models/
  tools/make_audio.py             the Python script that composes every file in music/ and sfx/
```

**If you can run code** (you have a sandbox, Python, Blender or `pip install bpy`, numpy, scipy, ffmpeg):
write the tools, run them, check the outputs, and hand over the finished `.zip`.

**If you cannot run code**: write every text file in full, each in its own code block headed by its path
(`film.script`, `README.txt`, `tools/make_props.py`, `tools/make_audio.py`), and finish with the exact
commands the user runs to create the binary files:

```
blender --background --python tools/make_props.py -- models      # or: pip install bpy  then  python tools/make_props.py -- models
python tools/make_audio.py .                                     # needs: pip install numpy scipy, and ffmpeg
```

Never invent download links, never use copyrighted music, sounds, characters or logos, and never use real
people. Everything in the package must be original and free to use.

---

## 2. THE SCRIPT FORMAT

A script has a **header**, a **CAST** section, an optional **SET** section, and **SCENE** sections.
Lines starting with `#` are comments. One instruction per line.

### 2.1 Header
```
REQUIRES: Scene Builder 1.5.1       # ALWAYS the first line, copied exactly
TITLE: The Surprise Test
LOCATION: Classroom                 # one of the locations in section 4
TIME: 9.8                           # hour of day (0–24), or "18.0 -> 19.3" to sweep it over the whole film,
                                    # or a preset: Morning, Noon, Sunset, Night, Overcast
WEATHER: Clear                      # preset (Clear, Breezy, Rain, Storm, Snowfall, Misty morning, Autumn)
                                    # or settings: "mist 0.4, wind 0.3"
LIGHT: exposure 1.2, mist 0.2       # optional fine-tuning (see 2.8)
MUSIC: music/morning.ogg, volume -14   # music that starts at 0 s (optional)
VOICES: on                          # speak every line with the computer's voices (recommended)
SUBTITLES: on                       # default on; "off" hides dialogue subtitles
CAMERA: auto                        # default; "manual" stops the app adding shots in long gaps
```

### 2.2 CAST
```
CAST:
Name = <model>, <setting>, <setting>, …
```
- **Name**: ONE word, capitalised, unique (`Bunty`, `Sharma`, `Principal`). It is used at the start of
  every line for that character.
- **Model** words (built-in people):

| Word(s) you write | Body you get |
|---|---|
| `man`, `guy`, `father`, `dad`, `comedian` | man |
| `woman`, `lady`, `mother`, `mum`, `mom`, `teacher` | woman |
| `woman casual`, `girl`, `young woman`, `teen`, `daughter`, `nurse` | young woman (adult size!) |
| `child`, `boy`, `kid`, `pupil`, `student`, `son` | child |
| `elder`, `old man`, `old woman`, `grandfather`, `grandmother`, `grandpa` | elder |
| `suit`, `man suit`, `businessman`, `doctor`, `anchor`, `boss` | man in a suit |
| `dog`, `puppy` | dog (moves and turns, no gestures) |

  ⚠ `girl` gives an **adult-sized** young woman. For a schoolgirl write
  `student, clothes skirt, hair ponytail, voice girl`.
- A `.glb`/`.fbx` path from the package (`characters/hero.glb`) uses a rigged character the user supplied.
- Clothes (Scene Builder 1.11+): `sweater <colour>`, `coat <colour>`, `scarf <colour>`, `beanie`,
  `glasses`. Seasons: `WEATHER: Autumn` (gold trees, dry grass) or `autumn 0.9`; `snow_cover 0.9`
  buries the grass. Two people on one bench: `sits on bench, left` / `sits on bench, right`
  (`far left` / `far right` for strangers).
- Scene Builder 1.12+: `LOCATION: Rain Street` (rainy city night); umbrellas (`Dev holds umbrella
  over Mira`); hand-placed cameras `SHOT: camera at (x, y, z) looking at Mira, fov 30, dolly in`.
- `my character "<name>"` uses one of the user's OWN characters from their library export (section 2.9).
- **Look settings** (built-in people):
  - `top <colour>`, `bottom <colour>`, `shoes <colour>`, `skin <colour>`, `hair <colour>`
  - `hair short | long | bun | ponytail | bald`
  - `clothes trousers | shorts | skirt`
  - `height <metres>` (e.g. `height 1.25`), `build 0.7–1.4` (1.4 = chubby), `body man | woman | child | elder`
  - Colours: plain names (red, navy, white, khaki, mustard, teal, charcoal, cream, olive, burgundy, rust,
    denim, dark brown, light brown, grey…) or hex `#7b1e2e`. ⚠ Some web names look different from what you
    expect (`maroon` renders pink) — use hex for exact colours.
- **Voice settings** (used with `VOICES: on`): `voice male | female | boy | girl | child | elder | young`,
  plus `deep | low | high | bright | slow | fast` — they combine: `voice boy fast`, `voice male deep slow`.
  The default voice follows the body. A specific installed voice by name also works (`voice Zira`).

Example:
```
CAST:
Sharma = teacher, top #7b1e2e, bottom cream, hair bun, hair black, voice female
Bunty = boy, top white, bottom navy, hair black, voice boy fast
Golu = boy, top white, bottom navy, build 1.4, voice boy deep slow
Pinky = student, top white, clothes skirt, bottom navy, hair ponytail, voice girl high
Principal = suit, top charcoal, bottom charcoal, hair grey, voice male deep slow
```

### 2.3 SET (objects)
```
SET:
<id> = <object or file> [scale N] <placement>[, facing <place>]
```
- `<id>`: ONE lower-case word, unique (`plane`, `tiffin`, `paper4`). Lines refer to it by this id.
- Object: a built-in object name (section 5), a package file `models/frog.glb`, or one of the user's
  own props: `my prop "<name>"` (section 2.9).
- Placement: `at <place>`, `near <place>`, `on <object>` (on top of it), `in front of`, `behind`,
  `left of`, `right of`, `2m left of <place>`, `between <a> and <b>`, or coordinates `at (x, z)`.
- Examples:
```
SET:
book = models/book.glb on school desk 4
tiffin = models/tiffin.glb on school desk 8
papers = models/test_papers.glb at (5.6, 2.25)
lamp = torch right of bench, facing campfire
crate = crate scale 1.5 near hut
```
- Every SET object exists from the first frame. To bring one in later, hide it at the very start of
  scene 1 (`plane disappears &`) and show it when needed (`plane appears on school desk 5`).

### 2.4 SCENE lines and timing
```
SCENE 1: Monday morning
```
- **Lines run one after another.** Each line waits until the previous one has finished: a walk lasts as
  long as the walk, a dialogue line as long as the sentence, a gesture about 1.5–3 s.
- **`&` at the end of a line makes the NEXT line start at the same moment** (people moving together,
  a reaction during a line, several objects hidden at once). Chain it: `A &`, `B &`, `C`.
- `WAIT 2s` pauses. `AT 12s` jumps to an exact time. `for 4s` on an action sets its length
  (`Golu dances for 6s`, `Bunty thinks for 2s`, `Sharma freezes for 1.5s`).
- `SHOT`, `TITLE`, `CAPTION`, `LOWER THIRD`, `SUBTITLE`, `MUSIC`, `SOUND`, `TIME`, `WEATHER`, `LIGHT`
  take **no time**: they happen at that moment. Follow a caption with `WAIT` if the audience must read it.
- A new `LOCATION: <name>` line at the start of a scene cuts to another location (section 4.3).

### 2.5 Character lines (start with a cast name)
**Placing**
- `Mira is at hill` · `Mira stands near campfire, facing lake` · `Mira is at (2.6, -0.6)`
- `Mira enters at doorway` — she is invisible until this moment, then appears there.
- `Mira disappears` — hide (characters who arrive later: `Mira disappears` at the start of scene 1, then
  `Mira enters at …`).

**Moving** — `<verb> to <place> [via <place>, <place>] [slowly | quickly]`
- Verbs and speeds: `walks` / `goes` / `heads` / `moves` / `returns` / `comes` / `crosses` / `approaches`
  (1.35 m/s), `steps` (1.0), `strolls` / `wanders` (0.9), `limps` (0.7), `sneaks` (0.6), `tiptoes` (0.5),
  `creeps` (0.55), `shuffles` (0.6), `waddles` (0.8), `marches` (1.6), `storms` (2.2), `trots` (2.0),
  `jogs` / `hurries` (2.6), `runs` / `rushes` (3.8), `dashes` (4.5), `sprints` (6.0), `follows` (1.35).
  Objects can also `drives` (10), `rides` (5), `rolls` (6), `flies` (8), `sails` (3), `scurries` (2.4).
- `leaves to <place>` / `exits to <place>` — walks there and vanishes.
- People walk in straight lines and **do not avoid furniture**. Indoors, route them through open floor
  with separate move lines and coordinates (`Bunty runs to (4.3, 2.65)` then `Bunty runs to (0, 2.65)`).
  ⚠ Don't put coordinates inside a `via` list (the comma inside "(x, z)" splits the list); use separate lines.

**Sitting, kneeling, lying, hugging**
- `Elder sits on bench` (walks there first) · `Pinky sits on chair 4` · `Elder stands up`
- `Mira kneels` · `Mira kneels at grave` · `Ram lies down on bed` (or sofa, or the ground) ·
  `Mira hugs Ram` (~3.5 s) · `stands up` ends sitting, kneeling or lying.
- Seated characters can talk, nod, wave, point, turn their head — but full-body gestures (cheers,
  dances, jumps, claps) are **skipped while sitting**: write `Pinky stands up` first.

**Turning and pointing**
- `Bunty turns to Sharma` · `Golu looks at tiffin` · `Babu points at window` · `Bunty looks at (5.0, 2.25)`

**Gestures** (add `for Ns` to change the length)
- `waves`, `talks`, `claps`, `cheers`, `laughs`, `giggles`, `thinks`, `looks around`, `whistles`,
  `dances`, `jumps`, `waits`, `freezes`, `nods`, `shakes head`, `bows`, `shrugs`, `gasps`, `facepalms`,
  `scratches head`, `sleeps`, `wakes up`, `panics`, `celebrates`.
- ⚠ **`raises hand` only works inside a dialogue direction**: `Bunty (raises hand): "Miss!"`.
  On its own line (`Bunty raises hand`) it is misread as picking up an object called "hand".
- `<Name> does <animation>` plays an animation pack clip (only for imported characters/avatars).

**Carrying objects** (SET objects only)
- `Mira picks up lantern` (walks to it first if it's more than 1 m away) — she carries it while walking.
- `Mira holds lantern high` (raised over her head — a small object ends up **on her head**, which is funny
  on purpose) · `Mira puts down lantern on table` · `Mira puts down lantern` (at her feet) ·
  `Mira gives lantern to Ram` · `Mira lets go of lantern` (it stays exactly where it is, e.g. before it rises).

**Hand and body animation (advanced)**
- `Sharma poses right shoulder -150 0 0, right elbow -40 0 0 over 0.6s` (writing on the board), later
  `Sharma relaxes over 0.3s`.
- Joints: head, neck, chest, spine, hips, left/right shoulder (arm), elbow, wrist (hand), hip (leg),
  knee, ankle (foot). Angles in degrees x y z. Arms hang at 0; shoulder x −90 lifts the arm forward,
  −170 straight up; elbow x −90 bends it; head x +20 nods down, y +30 turns left.

**Dialogue**
- `Name: "text"` or `Name (to Other, nods): "text"` — the speaker turns to the listener, talks with lip
  sync, a subtitle appears, and with `VOICES: on` the line is spoken aloud.
- Directions in brackets: `to <Name>` plus at most one gesture (`waves`, `points`, `nods`, `shakes head`,
  `shrugs`, `raises hand`, …). Nothing else goes in the brackets (no acting notes like "whispering").
- Use plain double quotes around the line; inside it use single quotes `'like this'`.
- Recorded dialogue (if supplied): `Mira: "Hello" [audio: audio/mira_01.wav] [voice: Higher]`.
- **Simultaneous chorus**: several lines joined with `&` are spoken together:
  `Pinky: "Good morning Miss!" &` / `Rita: "Good morning Miss!" &` / `Sonu: "Good morning Miss!"`.

### 2.6 Object lines (start with a SET id)
- `momo disappears` · `steamer appears on coffee table` · `frog appears near Bunty`
- Move: `car drives to street end` · `plane flies to on teacher desk` (lands on top of it) ·
  `frog scurries to (-3.2, -1.6)` · objects keep their height when the target is `on <object>`.
- Rise / sink with a gentle sway: `lantern rises 25m over 14s toward lake` · `balloon floats up 10m` ·
  `rock sinks 2m over 3s` · `vase falls 1m`. Add `&` to keep the story going while it floats.
- Turn: `cart turns to hut`.
- A hidden object can still be used as a place.

### 2.7 Places
A place can be: a named place of the location (section 4), any object in the location by name
(`campfire`, `sofa`, `chair 3`, `school desk 8`, `hut 2`), a SET id, a character,
`near / next to / beside / in front of / behind / left of / right of <place>`, `2m left of <place>`,
`between <a> and <b>`, `on <object>`, or coordinates `(x, z)` in metres.
Numbered objects: the first one is `chair` (also `chair 1`), then `chair 2`, `chair 3`… in the order the
location built them (section 4 lists the important ones).

### 2.8 Camera, titles, sound, light
**SHOT** — `SHOT: <type> [on <names>], [move], [from left | right | behind], [handheld]`
- Types: `establishing`, `wide`, `full`, `medium`, `close-up`, `extreme close-up`, `low angle`,
  `high angle`, `aerial`, `two-shot A and B`, `over-shoulder A to B`, `pov A to B`, `follow A`.
  Several subjects: `wide on Bunty and Golu and Pinky`.
- Moves: `dolly in`, `dolly out`, `truck left`, `truck right`, `crane up`, `crane down`, `pan left`,
  `pan right`, `tilt up`, `tilt down`, `orbit left`, `orbit right`, `zoom in`, `zoom out`, `static`.
- A SHOT lasts until the next SHOT. Framing is automatic; cameras avoid standing behind people or
  furniture, stay inside rooms, and clear trees out of the way.
- Scenes with no SHOT lines are filmed automatically; gaps of more than 9 s get extra shots.

**Text** — `TITLE: "THE END" for 5s` (big, centred) · `CAPTION: "Meanwhile…" for 3s` (top) ·
`LOWER THIRD: "BUNTY | Has never done homework." for 5s` (name card, bottom left) ·
`SUBTITLE: "…" for 3s`. `|` makes a new line. Keep each line under ~55 characters (longer text runs off
the screen) — split with `|`.

**Sound** — `MUSIC: music/chase.ogg, volume -8` · `SOUND: sfx/ribbit.wav, volume -4` ·
`SOUND: sfx/door.wav, volume -6, voice Big hall echo` · `MUSIC: theme` (built-in calm theme).
Voice effects: Normal, Deeper, Very deep / giant, Monster, Higher, Child / cartoon, Chipmunk, Robot,
Phone / radio, Old radio, Big hall echo, Ghost.

**Light** — `TIME: 19.5 over 10s` · `WEATHER: Rain over 5s` ·
`LIGHT: mist 0.6, fog 0.01, exposure 1.3 over 8s`. Settings: time, sun_azimuth, sun (intensity), clouds,
fog, ambient, exposure, wind, wind_direction, rain, snow, mist, leaves, snow_cover (0–1 unless noted).
Realistic world (1.28): `LIGHT: photo sky <file or Poly Haven id>, ground_photo <id>, hdri_rotation <deg>`
- the package carries `hdris/<name>.hdr` and `textures/<name>.glb`, or the user downloaded them.

---

### 2.9 The user's own characters and props (library export, Scene Builder 1.8+)
If the user attached a **library export** (`my_scene_builder_library.zip`), read it first:
- `library.json` lists every character and prop with the **exact name** to use, size in metres
  (`size_m` = width × height × depth), and for characters: `height_m`, `actions`, `lip_sync`, `blinks`.
- `contact_sheets/*.png` and `thumbnails/` show what everything looks like. **Look at them** before
  choosing what goes where.
- `AI_INSTRUCTIONS.md` is the script language of the user's exact app version, including every
  built-in location, object and person they have.

Use the user's things like this:
```
REQUIRES: Scene Builder 1.8
CAST:
Nabin = my character "Nabin Avatar", voice male
SET:
lamp = my prop "Brass Lamp" on side table, facing sofa
chair = my prop "Wooden Chair" scale 0.9 near window
```
- Names come from `library.json` (case and small spelling differences are forgiven).
- Combine freely with built-in locations, objects and people. Prefer the user's things when the
  story calls for them: that is why they shared their library.
- Check sizes: a prop meant to sit on a table should be under ~0.6 m; scale with `scale N` if needed.
- The user's characters walk, run, sit, turn and talk with subtitles (and move their mouth if
  `lip_sync` is true), and can be posed with `poses` lines. Gestures (waves, claps, dances…) only play
  if a listed action provides them, e.g. a Mixamo pack "Waving": `Nabin does Waving`. Otherwise the
  gesture is skipped, so don't build a comic beat on a gesture the character can't do.
- If the export **includes files** (`characters/`, `models/`, `animations/` folders), you can build
  and test the film yourself before delivering (section 9). Copy only the files your film uses into
  the package (`characters/Nabin_Avatar.glb`, `models/Brass_Lamp.glb`) so it also works on another
  computer; Scene Builder uses the user's own copy when it has one.

### 2.10 Flat sketch style (2D-looking animation, Scene Builder 1.9+)
A look for short motivational / inner-struggle animations: a black void, one drawn floor line,
everything seen from the side, flat colours with outlines, a cream "sketch person" and a black
"shadow" with a coloured glow that whispers to them. Use it only when the user asks for this kind
of film (or for a 2D / cartoon / sketch look).
```
REQUIRES: Scene Builder 1.9
TITLE: Just One More
LOCATION: Sketch Stage          # the black void; places: center, left, right, far left, far right,
                                # room 2 (x 16), room 3 (x 32)
STYLE: flat                     # turns on the look (also works with other locations, but use Sketch Stage)
                                # STYLE: paper = the same drawn style as ink on warm paper (Scene Builder 1.10+):
                                # bright and daytime, good for comedy; flat = black void, moody
VOICES: off                     # these films usually tell the story with music and written whispers

CAST:
Mina = sketch person, color cream
Later = shadow, glow #9a55ff, face smirk

SET:
desk = desk at (0.75, 0)        # x = left/right along the floor line, second number = depth (0 = on the line,
chair = chair at (0, 0)         #     negative = further back, e.g. a window on the wall at -0.9)
lamp = desk lamp at (1.15, 0)
window = window at (2.1, -0.9)
warm = warm glow at (0.95, 0.3) # a soft pool of light: warm/screen/cool/red/violet glow
```
- **Characters:** `sketch person` and `shadow` (also `inner voice`, `temptation`, `demon` → shadow).
  Settings: `color <colour>` (body), `glow <colour>` (shadow halo and face), `lines <colour>` (face
  lines), `face <expression>` (resting face), `height <m>`, `build 0.7–1.3`. Built-in people
  (man, woman…) are turned into sketch people in this style.
- **Expressions** (the face is the acting in this style, change it often): neutral, tired, sad,
  ashamed, scared, angry, determined, happy, smirk, shocked. Lines: `Mina looks tired` (also
  feels / becomes / gets / seems), `Mina smiles`, `Later smirks`, `Mina frowns`, `Mina gasps`,
  `Mina panics`. They take no time; add `WAIT 1s` to let a face land.
- **Whispers:** `Later whispers: Just one more video.` shows handwritten, glowing words next to the
  speaker's head (in the shadow's glow colour) and lasts as long as reading it takes. `Mina thinks:
  Not tonight.` shows quiet white words. Normal `Mina: "Hello"` dialogue still works with subtitles.
- **COUNTER:** `COUNTER: "DAYS CLEAN: 3"` puts a counter in the top-right corner until the next
  COUNTER line; `COUNTER: off` hides it. Takes no time.
- **PHONE:** a full-screen close-up of a phone screen. It takes its time like WAIT:
  `PHONE: home at 1:41 for 2s` · `PHONE: notification "App" "Message text" at 7:41 for 3s` ·
  `PHONE: message "Mom" "Did you eat?" "Yes" for 4s` (bubbles appear one by one) ·
  `PHONE: feed "Clips" at 11:04 for 3s` (endless scrolling thumbnails) ·
  `PHONE: dialog "Delete Clips?" "Cancel" "Delete" for 3.5s, taps Delete` ·
  `PHONE: call "Dad" for 3s` · `PHONE: cracked for 2s` · `PHONE: cracked, shadow face for 2.5s`.
  `at h:mm` sets the clock. Never invent another app's name or logo: make one up ("Clips").
- **New in 1.13** (write `REQUIRES: Scene Builder 1.13`):
  - Sketch looks: `hair long | bob | bun | short | curl | none`, `hair <colour>`, `hoodie <colour>`
    (or `shirt` / `sweater`), and `fuzzy` for a furry, scribbled shadow that "boils" like hand-drawn
    animation: `Someday = shadow, glow #ffb347, face smirk, height 1.5, fuzzy`.
  - More faces: crying, asleep, proud, hopeful, worried, laughing (`Mira cries`, `Mira beams`,
    `Mira worries`, `Mira laughs`, `Mira sleeps`, `Mira wakes up`). Faces now ease into each other.
  - `Someday grows to 2.3 over 1s` / `shrinks to 0.5 over 2s` / `shrinks back`: the habit or fear
    gets bigger or smaller. Shots frame the new size.
  - `LIGHT: paper #2e3550` (optionally `over 2s`): the page colour follows the mood (night blue,
    dusk purple, peach…). Whispers glow on dark pages.
  - Inserts that take their time like WAIT:
    `NOTE: "THIS YEAR" "Learn guitar" "Run 5k" strike 1, add "Play ONE song" for 5s` (sticky note;
    first line = heading, strike numbers count the lines under it) ·
    `CALENDAR: "March" start 4, done 4-17, missed 1-3, first day wed for 5s` (ticks appear one by one) ·
    `WORDS: Mira "too late" "no talent" "why bother" for 4s` (self-doubt drifting round her head;
    takes no time, add a WAIT).
  - `Mira plays guitar for 4s` (any SET object, held across the body and strummed, sitting or
    standing; set the face BEFORE this line) and `Mira puts down guitar at (0.5, -0.55)`.
  - See the sample package **Someday** (in Films/).
- **New in 1.22** (write `REQUIRES: Scene Builder 1.22`): realistic people with motion capture. CAST:
  `Mila = realistic girl` (also realistic man, woman, boy, grandfather, grandmother, David, Amara), with
  optional `shirt <colour>, trousers <colour>, shoes <colour>, hair <colour>, height <scale>`. Use the usual
  verbs (walks, runs, sits, kneels, waves, talks, cheers, laughs, cries, jumps, dances, picks up, looks happy...)
  and `does Sad Walk`, `does Phone`, `does Happy`, `does Sad`. Prefer them for any film that should look real.
- **New in 1.21** (write `REQUIRES: Scene Builder 1.21`): `cartoon person` characters in the 3D locations
  (lit, faces turn to the camera), `afloat` objects that ride rivers and lakes (`at (x, z), afloat, facing (x, z)`).
  - See the sample package **The Paper Boat** (in Films/).
- **New in 1.20 - documentary tools** (write `REQUIRES: Scene Builder 1.20`): `NUMBER:` statistic cards
  (always with a source and year), `SPLIT:` two live views side by side, live `COUNTER: "...${n}" rate N`,
  objects `up N` in the air, `spins`, `rises steady`. Name big ground meshes `groundwash...` in your
  Blender scripts so the pencil line doesn't scribble along their far edge.
  - See the sample package **A World That Can Afford War, But Not Humanity** (in Films/).
- **New in 1.18 - the Sketchbook look** (write `REQUIRES: Scene Builder 1.18`, `STYLE: sketchbook`):
  a hand-drawn picture book: boiling pencil outlines, cream paper with grain, soft watercolour
  colours. Characters are cartoon people (same settings as the Cartoon look below) with the
  face always in front of the hair. Scenes work like Paper: `LIGHT: paper <colour>` sets the
  page colour (pale washes for day, deep blue/purple for night). Good for emotional,
  storybook films; use Cartoon for bright, upbeat ones.
  - See the sample package **Two Voices (Sketchbook)** (in Films/).
- **New in 1.17 - the Cartoon look** (write `REQUIRES: Scene Builder 1.17`, `STYLE: cartoon`):
  bright 2D cartoon on the Sketch Stage. It's the most eye-catching style: use it unless the
  user asks for paper or flat sketch.
  - Outdoors by default: blue sky, drifting clouds, hills and grass. `LIGHT: paper #ffe2b8`
    makes the scene an interior (the colour is the wall, a floor comes forward from it);
    `LIGHT: paper none` goes back outside; `LIGHT: sky #2c3150` is an evening/night sky.
  - `cartoon person` (every `sketch person` becomes one in this look): a big head with big
    eyes, a shine in the pupils, ears, a nose, eyebrows, a mouth that opens into a toothy grin;
    clothes: `tshirt <colour>` (short sleeves) or `hoodie <colour>` (long sleeves),
    `jeans <colour>`, `shoes <colour>`, `cap <colour>` (backwards), hair `spiky | short | long |
    bob | bun | ponytail | curl | none` + `hair <colour>`. Height sets the age: 1.05 ≈ 6,
    1.35 ≈ 11, 1.6-1.8 adults (children get bigger heads automatically).
  - Faces act bigger here: `looks happy` is a big open grin, `shocked` has tiny pupils and an
    open mouth. A face always turns towards the camera; someone walking straight away shows the
    back of their head.
  - Text is readable in every look now: subtitles and captions sit on a dark rounded box,
    whispers and thoughts have a thick dark edge, counters are dark pills.
  - Package props: bright, saturated colours (they are NOT muted in this look); trees, bushes,
    fences and houses in simple rounded shapes look best. Outdoor props can stand anywhere on
    the grass; interiors need nothing behind z -1.6 (that's the wall).
  - See the sample package **Two Voices (Cartoon)** (in Films/).
- **New in 1.16** (write `REQUIRES: Scene Builder 1.16`):
  - `WORDS: Riya "clumsy" "not now" "stop crying" color #6f7f9c for 4s` - the swirling words
    take any colour (cold for harsh words, warm for kind ones).
  - Two inner voices work well as two shadows: a cold, `fuzzy` one (`glow #8fa3c8`) and a warm
    one (`color #f2c45a, glow #ffd27a, lines #6b4a1a, face happy`), each growing a little with
    every word (`Critic grows to 0.7 over 1s`).
  - Ages: play one person at several ages with separate cast members (Riya6, Riya11, Riya16,
    Riya) - same colours and hair, different heights - and swap them with disappears/appears.
  - Two houses side by side (x 0 and x 24) with mirrored furniture make "same moment, two
    homes" stories easy; give each its own page colour (`LIGHT: paper #d3d6df` / `#f6dcc0`).
  - See the sample package **Two Voices** (in Films/).
- **New in 1.15** (write `REQUIRES: Scene Builder 1.15`):
  - Props land where they belong: a small object placed `at` a spot over a desk or table
    (mug, laptop, desk lamp, cake, books) sits ON it, and `puts down cake at (x, z)` puts it on
    the table there. Still: check every SET coordinate against the furniture you place.
  - `raises hand` always plays the gesture (it no longer tries to carry an object called "hand").
  - Package vehicles: build them nose to -Y in Blender and place them `facing` the way they
    will drive, so `bus drives to (90, -2.6)` shows their side. Run the road BEHIND the
    pavement (z about -2.6) so it never hides the actors.
  - Flat-look tips that work well: `WEATHER: rain 0.6 over 2s` on a night page; `SHOT: follow
    Mina` while she walks to the next place, with shops, trees and lamps along the back so
    the tracking shot passes real places; hide objects nobody is using (`phone disappears`).
  - See the sample package **Pass It On** (in Films/).
- **New in 1.14** (write `REQUIRES: Scene Builder 1.14`):
  - `POST: "@maya.wanders" "Paradise again. Never going home." 2341 likes for 4s`: the moment
    frozen as a social post - a camera flash, a white frame around the live shot, the name on
    top, likes counting up and the caption below. Takes its time like WAIT. Invent names.
  - Selfies: `Maya holds phone high` (any SET object with "phone" in its name) holds it out at
    arm's length. Use it right before a POST.
  - `pants <colour>` (or `jeans` / `trousers`): sketch people with a top now wear jeans and shoes.
  - `SHOT: camera at (x, y, z) looking at (x, y, z), fov 22` now also works on the Sketch Stage
    (e.g. tilt up to an empty wall for the end card).
  - Someone who appears somewhere new is no longer still sitting or lying from before.
  - See the sample package **Highlight Reel** (in Films/).
- **Sketch objects:** desk, chair, sofa, bed, desk lamp, floor lamp, books, open book, bookshelf,
  door, window, mirror, laptop, phone, mug, bin, plant, wall clock, tv, bottle, and the lights warm
  glow, screen glow, cool glow, red glow, violet glow. They are already drawn for this look; other
  built-in objects are shown flat and muted.
- **Shots:** every shot is a flat side view. `full on A and B` and `medium on A` are the workhorses,
  `close-up on A` for faces, `wide` / `establishing` for the room and title cards. `from left`,
  `crane down`, `dolly in` still work. Keep two people within ~6 m for a two-shot.
- **Pacing:** few words, many `WAIT`s, one idea per shot. A typical film: night → temptation
  (whispers, phone feed) → the low point (ashamed face, a bad result) → the decision (dialog,
  determined face) → day counter climbing while the shadow keeps whispering → a quiet ending card.
- See the sample package **Just One More** (in Films/) for a complete film in this style.

## 3. RULES THAT MAKE OR BREAK A FILM (learned from real builds)

**Music**
1. A `MUSIC:` line **adds** a track; it never stops or fades the track already playing. So every music
   file must be exactly as long as its section, with a fade-out at its end, and the next cue starts where
   the previous one ends. (Don't write `volume -40 over 2s` to "fade" — it just adds a silent copy.)
2. Plan the cue windows from your timing estimate (rule 13), make each cue ~5–10 % shorter than its
   window, and put the music lengths at the bottom of `tools/make_audio.py` so the user can adjust them.
3. A finale cue should end on a big chord timed to land on `TITLE: THE END`.
4. Music volume −6 to −16 under dialogue; sound effects −2 to −8.

**Camera**
5. **Never write `from front`.** It can be read as the place named "front" (Classroom, Comedy Club…), and
   the camera ends up at the back of the room. Leave the direction out (shots frame faces by default)
   or use `from left`, `from right`, `from behind`.
6. **People seated behind desks or tables:** use `medium on X` and `close-up on X`, cutting between
   single shots. `two-shot` and `over-shoulder` of seated people across desks get blocked by furniture.
7. **Small props** (a cup, a frog, a paper plane): a close-up on the prop itself is often hidden behind
   furniture. Show it with `close-up on <the character holding or facing it>` or `high angle on <character>`.
   A close-up on a prop works when it stands on a table top or on the open floor.
8. **Entrances:** put the SHOT on a character entering through a door *after* their first move line, once
   they're inside — a low angle on someone still in the doorway can place the camera inside the wall.
9. Change shots every 3–8 s: establishing → medium → close-ups in dialogue → reaction shots → wide.
   For comedy, cut to an `extreme close-up … zoom in` with a `SOUND: sfx/dun.wav` for reactions, and use
   `handheld` for panic.

**Characters and staging**
10. Place everyone at the start of scene 1 (sit them down, `is at`, or `disappears` for later arrivals).
    Hide all later props in the same first block with `&`.
11. Indoor entrances and exits go through the room's doorway (section 4), using coordinates just outside it.
12. Stand people up before full-body gestures; sit them back down when the scene calms down.

**Timing and length**
13. Estimate the length while writing: a dialogue line ≈ (words ÷ 2.6) + 0.6 s; a gesture 1.5–3 s; a walk
    = distance ÷ speed; sitting down or standing up ≈ 1.2 s; titles/captions take no time unless you add
    `WAIT`. Real voices can shift dialogue timing by ±10 %.
14. Hit the requested length within ±10 %. Long films come out long because of walks, sequential
    reactions and pauses. Tighten with `&` (reactions during the next line), faster verbs (`runs`,
    `storms`), and fewer, punchier lines. Rough guide: ~25–30 dialogue lines per minute of comedy.
15. Keep dialogue lines short (under ~15 words). One idea per line.

**Format**
16. Cast names and SET ids are single words. Use only names, places, objects and verbs from this document
    or from your package's own files.
17. Unknown words never crash the build — the app reports them — but every reported line is something the
    audience won't see. Aim for **zero warnings**.
18. If the story needs something that doesn't exist, make it as a prop in `tools/make_props.py`, or choose
    the closest built-in thing and add a `#` comment saying what you would ideally want.

---

## 4. LOCATIONS

### 4.1 Overview
| Location | Kind | What's there | Named places |
|---|---|---|---|
| Blank World | outdoor | empty flat grass; build everything with SET | center, north, south, east, west |
| Lakeside Campfire | outdoor | golden-hour lake in pines, campfire, bench, hill path | lake, shore, hill, path, clearing, center |
| Forest Lake | outdoor | misty morning lake, wooden hut, campfire on a meadow | lake, shore, meadow, forest edge, center |
| Seaside Village | outdoor | sunset beach, waves, row of huts, cart, barrels, torches | beach, shoreline, village, sea, center |
| Mountain River | outdoor | rocky valley, fast river, waterfall, snowy peaks | riverbank, far bank, waterfall, valley trail, center |
| Rainy Night Street | outdoor | wet street at night, lamp posts, walls, a car and a van | street, left sidewalk, right sidewalk, street end, street start, center |
| Big City | outdoor | downtown at dusk, towers, crossroads, traffic lights, bus stop | crossing, left sidewalk, right sidewalk, north street, south street, center |
| Golden Valley | outdoor | golden-hour valley, winding river, flower meadows, mist | meadow, flowers, hillside, center |
| Classroom | indoor | blackboard, teacher's desk, 12 pupil desks with chairs, bookshelf | front, back, aisle, center |
| Hospital Ward | indoor | 3 beds with IV stands, a screen, a cabinet, waiting chairs | bedside, waiting area, center |
| Living Room | indoor | sofa, armchair, coffee table, TV, rug, bookshelf, lamps | center, doorway, hallway, by the tv, window |
| Comedy Club | indoor | stage with brick wall, mic stand, bar stool, spotlights, 2 rows of chairs | stage, stage left, audience, center |
| News Studio | indoor | anchor desk, video wall, studio lights | anchor seat, guest seat, studio floor, center |

The location's own people are removed: only your CAST appears. Indoor rooms get all four walls.
Coordinates are metres; x is left/right, z is towards the camera of the establishing shot.

### 4.2 Indoor layouts (exact)
**Classroom** — room 10 × 9 m (x −5…5, z −4.5…4.5), ceiling 3.2 m. Blackboard at the back wall (0, −4.4);
`front` (0, −3.3) is where the teacher stands, facing the class. `teacher desk` at (−2.6, −2.9).
`bookshelf` at (4.6, −3.6). **Doorway** in the right wall at z = 2.25 → enter/leave at **(5.6, 2.25)**.
12 desks with chairs, pupils facing the board. Chair *n* sits behind `school desk n`:

| | x = −3 | x = −1 | x = 1 | x = 3 |
|---|---|---|---|---|
| front row (chairs z = 0, desks z = −0.6) | chair 1 | chair 4 | chair 7 | chair 10 |
| middle row (chairs z = 2.0, desks z = 1.4) | chair 2 | chair 5 | chair 8 | chair 11 |
| back row (chairs z = 4.0, desks z = 3.4) | chair 3 | chair 6 | chair 9 | chair 12 |

Open floor for walking: centre aisle x = 0 (`aisle` = (0, 1.4)); right aisle x = 4.3; corridor between
front chairs and middle desks z = 0.7; corridor between middle chairs and back desks z = 2.65; the front
area z −1.2…−4. Route example door → front: `(4.3, 2.25)` → `(4.3, −1.6)` → `front`.

**Living Room** — room 8 × 7 m (x −4…4, z −3.5…3.5). `sofa` (0, 2.0) facing the `tv` (0, −3.1);
`coffee table` (0, 0.5) on the `rug`; `armchair` (−2.4, 0.6); `bookshelf` (3.6, −2.0); `flower pot`
(−3.4, −3.0). **Doorway** in the right wall: `doorway` (3.4, 1.75), `hallway` just outside (5.4, 1.75).
`by the tv` (1.2, −2.4), `window` (−3.4, 0.5). Two people fit on the sofa; one on the armchair.

**Hospital Ward** — room 9 × 8 m (x −4.5…4.5, z −4…4). Three `hospital bed`s at x −2.8, 0, 2.8, z −2.6,
each with an `iv stand`; `medical screen` (−1.4, −1.4); `medical cabinet` (4.2, 0.5); `waiting chairs`
(0, 3.4). **Doorway** in the right wall at z = 2.0 → enter at (5.1, 2.0). `bedside` (0.9, −1.2).

**Comedy Club** — room 14 × 10 m, no doorway (people `enter at` a place). `stage` (0, 0.6 m high, −1.9)
with `brick backdrop`, `mic stand` (0.4, −1.4), `bar stool` (−1.0, −2.2). Audience: 2 rows × 5 chairs at
x −3, −1.5, 0, 1.5, 3, z 2.0 and 3.6 (`chair` … `chair 10`, row by row). `audience` (0, 2.8).

**News Studio** — room 14 × 10 m, no doorway. `news desk` (0, −1.6), `office chair` at the `anchor seat`
(−0.5, −2.2), `guest seat` (0.9, −2.2), `video wall` behind (0, −4.6), `studio floor` (0, 1.0).

### 4.3 Several locations in one film
Start a scene with `LOCATION: <name>` to cut there, and back the same way. A film can combine **one**
nature location (Lakeside Campfire, Forest Lake, Seaside Village, Mountain River, Golden Valley) with any
number of rooms, studios and streets. Each location keeps its own lighting. **Place the characters again
after every switch** (`Mira enters at doorway`).

---

## 5. BUILT-IN OBJECTS (for SET and as places)
- **Buildings:** classroom room, fence, hospital room, hut, living room, room, stone wall, studio room, watch tower
- **Interior:** armchair, bed, blackboard, coffee table, fridge, kitchen counter, office chair, rug, school desk, sofa, teacher desk, tv, whiteboard
- **Hospital:** hospital bed, iv stand, medical cabinet, medical screen, reception desk, waiting chairs
- **Stage:** bar stool, brick backdrop, mic stand, news desk, stage curtain, stage platform, video wall
- **City:** apartment block, brick building, bus stop, glass tower, office building, road, traffic light, trash bin
- **Lights:** bare bulb, ceiling lamp, soft panel, spotlight
- **Nature:** bush, oak tree, pine tree, rock
- **Water:** lake, pond, rapids, river, round pond, sea and beach, stream
- **Effects:** brazier, campfire, chimney smoke, ground mist, steam, torch, waterfall
- **Furniture:** bench, bookshelf, chair, table
- **Vehicles:** bus, car, cart, van
- **Decorations:** barrel, crate, flower pot, lamp post, signpost

Aliases: desk → school desk, board/chalkboard → blackboard, couch → sofa, television → tv, fire/bonfire →
campfire, seat → chair, stool → bar stool, microphone/mic → mic stand, box → crate, tree → oak tree,
stone/boulder → rock, cupboard → medical cabinet, curtain → stage curtain, stage → stage platform.

Built-in people's actions (for reference): Auto, Idle, Walk, Run, Wave, Talk, Point, Clap, Cheer, Think,
Look Around, Sit, Kneel, Lie Down, Hug, Dance, Jump, Pose only.

---

## 6. MAKING THE PROPS (tools/make_props.py)

Write one Blender Python script that builds **every** model in `models/` and exports each as `.glb`.
- Runs headless: `blender --background --python tools/make_props.py -- models`
  (or `pip install bpy` and `python tools/make_props.py -- models`). Read the output folder from the
  argument after `--`.
- In a script, `import bpy` **before** `import bmesh` or `import addon_utils`.
- Start each prop from an empty scene (`bpy.ops.wm.read_factory_settings(use_empty=True)`).
- **Real size in metres.** Small story props may be 20–50 % larger than life so they read on camera.
- **Origin at the bottom centre** (the base at z = 0), so `on <table>` sets it neatly on top.
- Build with primitives + modifiers (solidify, bevel), Principled BSDF materials (base colour, roughness,
  metallic; alpha + `blend_method = "BLEND"` for glass). No image textures needed; bright, readable colours.
- Join each prop into one mesh, apply transforms, export:
  `bpy.ops.export_scene.gltf(filepath=..., export_format="GLB", export_apply=True)`.
- If you add a mesh with shape keys, remove them before applying modifiers.
- Lights inside a `.glb` are tamed automatically; for a glowing prop prefer an emissive material.
- Keep each file under ~5 MB. Make a "before/after" pair as two files when a prop changes
  (e.g. `lantern.glb` and `lantern_lit.glb`, swapped with disappears/appears).

## 7. MAKING THE MUSIC AND SOUND (tools/make_audio.py)

Write one Python script (numpy + scipy; ffmpeg for `.ogg`) that **synthesises** everything from scratch —
no samples, no recordings, nothing copyrighted.
- Music → `music/<cue>.ogg` (libvorbis q5). One cue per section; lengths from your timing plan (rule 2);
  fade-out at the end of each; the finale's last chord lands on THE END.
- Effects → `sfx/<name>.wav` (16-bit, 44.1 kHz), normalised to about −1.5 dBFS peak.
- Useful building blocks: plucked strings (Karplus–Strong or decaying saws), glockenspiel and xylophone
  (inharmonic sines), bass, kick/snare/hat (filtered noise), woodblock ticks, brass (filtered saw with
  vibrato), flute (sine + breath noise), strings (detuned saws with slow attack), a madal-style drum
  (pitch-dropping sine), formant "voices" (pulse train through 3 band-passes) for crowd laughs and "aww".
- Comedy staples: dun-dun-DUUN sting, boing, whoosh, slide whistle, sad trombone, record scratch, snore,
  ding (correct!), tick-tock, footsteps, door creak, crowd laugh.
- Match each cue to the scene's mood: bright morning, sneaky pizzicato, game-show thinking, tense ticking,
  frantic chase, funky chaos, warm emotional strings, happy folk finale.

## 8. README.txt
Title and length · one-paragraph logline · HOW TO WATCH (Script → Open… → <name>.zip → Build Film →
Watch; Export Video → MP4 needs FFmpeg) · the scene list · the cast · WHAT'S INSIDE (every file with one
line each) · layout notes (who sits where, doors) · MAKE IT YOURS (change colours, swap in avatars,
record real voices with `[audio: …]`, re-run the tools with new music lengths).

## 9. BEFORE YOU HAND IT OVER — CHECKLIST
- [ ] First line is `REQUIRES: Scene Builder 1.5.1`; header has TITLE, LOCATION, TIME, VOICES: on.
- [ ] Every cast name and SET id is one word and is used exactly as declared.
- [ ] Every file the script mentions exists in the package with that exact path.
- [ ] Every `my character "…"` / `my prop "…"` name is in the user's library.json, and the
      REQUIRES line says 1.8 or newer.
- [ ] Everyone is placed or hidden at the start; later props are hidden with `&` in the first block.
- [ ] No `from front`; no `raises hand` on its own line; no gestures while seated without standing up.
- [ ] Indoor walks go through open floor; entrances use the doorway.
- [ ] Captions/titles that must be read have a `WAIT`; long text is split with `|`.
- [ ] Music cues fit their windows and end with a fade; the length estimate is within ±10 % of the request.
- [ ] Every scene has a clear comic or emotional beat, and the ending pays off something set up earlier.
- [ ] README.txt describes everything; tools/ re-create every model and sound.
- [ ] If you can run Scene Builder headless, build it and fix every warning:
      `godot --headless res://tests/ScriptTest.tscn -- <package folder or .zip>` prints the report.

---

## 10. SAMPLE PACKAGE: "Chiya Break" (≈58 s, Living Room)

A complete, tested package. Copy its shape; your film will be longer and richer.

```
chiya_break/
  film.script
  README.txt
  models/biscuit_jar.glb      (from tools/make_props.py)
  models/chiya_cup.glb        (from tools/make_props.py)
  music/theme.ogg             (from tools/make_audio.py, 56 s)
  sfx/crunch.wav  sfx/slurp.wav  sfx/dun.wav
  tools/make_props.py
  tools/make_audio.py
```

### film.script
```
# CHIYA BREAK - a one-minute Scene Builder sample film package
# Script -> Open... -> chiya_break.zip -> Build Film -> Watch

REQUIRES: Scene Builder 1.5.1
TITLE: Chiya Break
LOCATION: Living Room
TIME: 16.5
VOICES: on
MUSIC: music/theme.ogg, volume -14

CAST:
Aama = mother, top #8a2b4a, bottom #3b2a5a, hair bun, hair black, voice female
Babu = father, top mustard, bottom brown, hair black, build 1.15, voice male deep
Sanu = boy, top red, bottom blue, hair black, voice boy fast

SET:
jar = models/biscuit_jar.glb on coffee table
cup = models/chiya_cup.glb on coffee table

SCENE 1: The jar
cup disappears &
Aama disappears &
Babu sits on sofa &
Sanu is near bookshelf, facing coffee table
SHOT: establishing, dolly in
TITLE: CHIYA BREAK for 3.5s
WAIT 3.5s
SHOT: close-up on jar, zoom in
CAPTION: "Four o'clock. Chiya time." for 3s
WAIT 3s
SHOT: medium on Sanu
Sanu looks at jar
Sanu: "Twelve biscuits. Nobody counts biscuits."
Sanu tiptoes to coffee table
SOUND: sfx/crunch.wav, volume -4
Sanu laughs
SHOT: medium on Babu, dolly in
Babu turns to Sanu
Babu (to Sanu): "Sanu. I count biscuits."

SCENE 2: Caught
Aama enters at doorway
cup appears on coffee table
SHOT: full on Aama, from left
Aama (to Babu): "Chiya is ready! And the biscuits are for the guests."
Aama looks at jar
SOUND: sfx/dun.wav, volume -4
SHOT: close-up on Aama
Aama gasps
Aama: "Who ate the biscuits?"
SHOT: medium on Sanu
Sanu (points): "Babu did!"
SHOT: close-up on Babu, handheld
Babu (to Sanu): "I was sitting here the whole time!"
Aama (to Babu): "Then why are there crumbs on your shirt?"
Babu facepalms
SHOT: medium on Sanu
Sanu whistles for 2s

SCENE 3: Chiya
SHOT: medium on Aama
Aama sits on armchair
Aama: "Fine. No biscuits for anyone."
SOUND: sfx/slurp.wav, volume -4
WAIT 1s
Aama: "...More chiya for me."
SHOT: wide on Aama and Babu and Sanu, orbit left
Babu laughs &
Sanu laughs
TITLE: THE END for 4s
WAIT 4s
```

### README.txt
```
CHIYA BREAK - a one-minute sample film package for Scene Builder 1.5.1
=====================================================================

Four o'clock, chiya time. There are twelve biscuits in the jar, and Sanu
thinks nobody counts biscuits. Babu does. Then Aama walks in.

This is the small sample package that goes with FILM_PACKAGE_PROMPT.md: it
shows every part of a package in its simplest form.

HOW TO WATCH
Script -> Open... -> chiya_break.zip -> Build Film -> Watch.

WHAT'S INSIDE
film.script             the screenplay (3 scenes, 3 characters, 12 shots, ~58 s)
models/biscuit_jar.glb  glass biscuit jar with a red lid   (made by tools/make_props.py)
models/chiya_cup.glb    a glass of chiya on a steel saucer (made by tools/make_props.py)
music/theme.ogg         sneaky tea-time tune, 56 s          (made by tools/make_audio.py)
sfx/crunch.wav, sfx/slurp.wav, sfx/dun.wav                  (made by tools/make_audio.py)
tools/make_props.py     Blender (bpy) script that builds the models
tools/make_audio.py     numpy/scipy script that composes the music and effects

Re-make the files:  blender --background --python tools/make_props.py -- models
                    python tools/make_audio.py . 56
All files are original and free to use.
```

### tools/make_props.py
```python
"""Props for "Chiya Break", built with Blender's Python (bpy) and exported as .glb.
Run:  blender --background --python make_props.py -- <models folder>
(or with the bpy pip module:  python make_props.py -- <models folder>)

Rules every prop follows: real size in metres, origin at the bottom centre
(it rests on whatever it is placed "on"), Principled materials, one joined mesh.
"""
import math
import os
import sys

import bpy

OUT = sys.argv[sys.argv.index("--") + 1]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, rough=0.5, metal=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    return m


def add(obj_op, mat, smooth=True, **kwargs):
    obj_op(**kwargs)
    obj = bpy.context.object
    obj.data.materials.append(mat)
    if smooth:
        bpy.ops.object.shade_smooth()
    return obj


def solidify(obj, thickness):
    mod = obj.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = thickness
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="Solid")


def join_and_export(name, filename):
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    bpy.ops.object.join()
    bpy.context.object.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    path = os.path.join(OUT, filename)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True)
    print("EXPORTED", path)


def chiya_cup():
    """A glass of milky Nepali tea on a small steel saucer (a little larger than life so it reads on camera)."""
    steel = material("Steel", (0.8, 0.8, 0.82), rough=0.2, metal=1.0)
    glass = material("Glass", (0.9, 0.95, 1.0), rough=0.05, alpha=0.35)
    tea = material("Tea", (0.62, 0.4, 0.22), rough=0.15)
    add(bpy.ops.mesh.primitive_cylinder_add, steel, vertices=48, radius=0.075, depth=0.008, location=(0, 0, 0.004))
    cup = add(bpy.ops.mesh.primitive_cone_add, glass, vertices=48, radius1=0.04, radius2=0.05, depth=0.11,
              location=(0, 0, 0.063), end_fill_type="NOTHING")
    solidify(cup, 0.003)
    add(bpy.ops.mesh.primitive_cylinder_add, tea, vertices=48, radius=0.046, depth=0.085, location=(0, 0, 0.052))


def biscuit_jar():
    """A glass jar with a red lid, half full of round biscuits."""
    glass = material("JarGlass", (0.85, 0.92, 0.95), rough=0.05, alpha=0.3)
    lid = material("Lid", (0.75, 0.12, 0.1), rough=0.4)
    biscuit = material("Biscuit", (0.82, 0.6, 0.3), rough=0.7)
    jar = add(bpy.ops.mesh.primitive_cylinder_add, glass, vertices=48, radius=0.09, depth=0.2, location=(0, 0, 0.1),
              end_fill_type="NGON")
    solidify(jar, 0.004)
    add(bpy.ops.mesh.primitive_cylinder_add, lid, vertices=48, radius=0.095, depth=0.03, location=(0, 0, 0.215))
    add(bpy.ops.mesh.primitive_uv_sphere_add, lid, radius=0.02, location=(0, 0, 0.235))
    for i in range(14):
        a = i * 2.4
        r = 0.045 if i % 2 else 0.02
        b = add(bpy.ops.mesh.primitive_cylinder_add, biscuit, vertices=24, radius=0.032, depth=0.012,
                location=(r * math.cos(a), r * math.sin(a), 0.012 + i * 0.008))
        b.rotation_euler = (0.5 * math.sin(i), 0.5 * math.cos(i * 1.3), 0)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, build in [("chiya_cup", chiya_cup), ("biscuit_jar", biscuit_jar)]:
        reset()
        build()
        join_and_export(name.replace("_", " ").title(), name + ".glb")


main()
```

### tools/make_audio.py
```python
"""Original music and sound effects for "Chiya Break", synthesised with numpy/scipy
(no samples, no recordings). Needs: numpy, scipy, ffmpeg (for .ogg).
Run:  python make_audio.py <film folder> [music seconds]
"""
import os
import subprocess
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

RATE = 44100
RNG = np.random.default_rng(3)


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def band(x, lo, hi):
    return sosfilt(butter(2, [lo, hi], "band", fs=RATE, output="sos"), x)


def low(x, f):
    return sosfilt(butter(2, f, "low", fs=RATE, output="sos"), x)


def env(n, attack=0.005, release=0.1):
    e = np.ones(n)
    a, r = max(1, int(attack * RATE)), max(1, int(release * RATE))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def place(track, sound, at):
    i = int(at * RATE)
    end = min(len(track), i + len(sound))
    if 0 <= i < len(track):
        track[i:end] += sound[: end - i]


def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    return 440.0 * 2 ** ((names[name[0]] + (int(name[-1]) - 4) * 12) / 12)


def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = x / (np.max(np.abs(x)) or 1) * 0.85
    wavfile.write(path, RATE, (x * 32767).astype(np.int16))


def write_ogg(path, x):
    tmp = path[:-4] + ".tmp.wav"
    write_wav(tmp, x)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", path], check=True)
    os.remove(tmp)


def pluck(freq, seconds=0.4):
    t = t_axis(seconds)
    x = sum(np.sin(2 * np.pi * freq * k * t) / k for k in range(1, 8))
    return low(x * np.exp(-t * 8), 3000) * env(len(t), 0.002, 0.05)


def bass(freq, seconds):
    t = t_axis(seconds)
    return np.sin(2 * np.pi * freq * t) * np.exp(-t * 3) * env(len(t), 0.004, 0.05)


def tick(high):
    t = t_axis(0.1)
    return np.sin(2 * np.pi * (1100 if high else 800) * t) * np.exp(-t * 45)


def theme(seconds):
    """Light, sneaky tea-time tune: pizzicato over a walking bass, 100 bpm, fades at the end."""
    beat = 60 / 100
    track = np.zeros(int((seconds + 1) * RATE))
    walk = ["C3", "E3", "G3", "A3", "F3", "A3", "G3", "B3"]
    tune = ["E5", "G5", "A5", "G5", "E5", "D5", "C5", "D5"]
    t, i = 0.0, 0
    while t < seconds:
        place(track, bass(note(walk[i % 8]), beat) * 0.6, t)
        place(track, tick(i % 2 == 0) * 0.3, t)
        if (i // 8) % 2 == 1:
            place(track, pluck(note(tune[i % 8])) * 0.4, t + beat * 0.5)
        t += beat
        i += 1
    track = track[: int(seconds * RATE)]
    fade = int(2.0 * RATE)
    track[-fade:] *= np.linspace(1, 0, fade)
    return track


def slurp():
    t = t_axis(0.9)
    noise = RNG.standard_normal(len(t))
    out = np.zeros_like(t)
    for i in range(0, len(t), 1024):
        c = 600 + 1800 * (i / len(t))
        out[i:i + 1024] = band(noise[i:i + 1024], c * 0.8, c * 1.3)
    return out * (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 7 * t))) * env(len(t), 0.05, 0.2)


def crunch():
    out = np.zeros(int(0.8 * RATE))
    for k in range(7):
        t = t_axis(0.06)
        place(out, band(RNG.standard_normal(len(t)), 900, 7000) * np.exp(-t * 60), k * 0.1 + RNG.uniform(0, 0.03))
    return out


def dun():
    out = np.zeros(int(2.6 * RATE))
    for at, length in [(0.0, 0.3), (0.4, 0.3), (0.85, 1.6)]:
        t = t_axis(length)
        hit = sum(sum(np.sin(2 * np.pi * note(n) * k * t) / k for k in range(1, 9)) for n in ["D3", "F3", "A3"])
        place(out, low(hit, 2000) * env(len(t), 0.02, 0.2) * 0.3, at)
    return out


def main():
    folder = sys.argv[1]
    seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 40.0
    write_ogg(os.path.join(folder, "music", "theme.ogg"), theme(seconds))
    for name, fn in [("slurp", slurp), ("crunch", crunch), ("dun", dun)]:
        write_wav(os.path.join(folder, "sfx", name + ".wav"), fn())
    print("AUDIO OK")


main()
```

---

## 11. ADVANCED EXAMPLE: excerpts from "The Surprise Test" (5:47 classroom comedy, 97 shots)

These scenes show comedy timing, reactions with `&`, seated staging, props that appear, fly and hide,
lower-third character intros, chorus lines and a callback.

```
# EXCERPT ONLY: not a complete script (other cast, set lines and scenes are left out)
CAST:
Sharma = teacher, top #7b1e2e, bottom cream, hair bun, hair black, voice female
Bunty = boy, top white, bottom navy, hair black, voice boy fast
Golu = boy, top white, bottom navy, hair black, build 1.4, voice boy deep slow
Pinky = student, top white, clothes skirt, bottom navy, hair ponytail, hair black, voice girl high

SET:
tiffin = models/tiffin.glb on school desk 8
plane = models/paper_plane.glb on school desk 5
frog = models/frog.glb on school desk 5

SCENE 1: Monday morning
plane disappears &
frog disappears &
Sharma disappears &
Bunty disappears &
Pinky sits on chair 4 &
Golu sits on chair 8
Golu sleeps &
SHOT: establishing, dolly in
TITLE: THE SURPRISE TEST for 4s
WAIT 4s
SHOT: close-up on Golu, dolly in
CAPTION: "Sunflower Boarding School. Class 6. Monday, 9:59 AM." for 3.5s
SOUND: sfx/snore.wav, volume -6
WAIT 3s
SOUND: sfx/run.wav, volume -4
Bunty enters at (5.6, 2.25)
SHOT: follow Bunty
Bunty runs to (4.3, 2.65)
Bunty runs to (0, 2.65)
Bunty sits on chair 5
SHOT: medium on Bunty, dolly in
LOWER THIRD: "BUNTY | Has never done homework. Has an excuse every time." for 5s
Bunty (to Golu): "Made it! GOLU! WAKE UP!"

SCENE 3: Surprise!
SHOT: close-up on Sharma, dolly in
Sharma: "A... SURPRISE... TEST!"
SOUND: sfx/dun.wav, volume -2
SHOT: extreme close-up on Bunty, zoom in
Bunty gasps
WAIT 1s
SHOT: medium on Pinky
Pinky stands up
SOUND: sfx/ding.wav, volume -6
Pinky cheers for 2s &
Pinky: "YES! Finally!"
SHOT: medium on Bunty
Bunty (raises hand): "Miss! I cannot take the test. My dog ate my homework."
SHOT: medium on Sharma
Sharma (to Bunty): "Bunty. You do not have a dog."
SHOT: close-up on Bunty, dolly in
WAIT 0.8s
Bunty (to Sharma): "...He ate that too."
SOUND: sfx/laugh.wav, volume -6
Pinky shakes head &
Golu laughs

SCENE 5: Air mail
SHOT: medium on Sharma, from left
Sharma walks to blackboard &
Sharma: "Now copy the formula from the board. Quietly."
Sharma poses right shoulder -150 0 0, right elbow -40 0 0 over 0.6s
SOUND: sfx/fold.wav, volume -4
plane appears on school desk 5
SHOT: medium on Bunty
Bunty picks up plane
Bunty holds plane high
Bunty lets go of plane
SOUND: sfx/whoosh.wav, volume -4
SHOT: high angle on plane, from right
plane flies to on teacher desk
WAIT 0.6s
Sharma relaxes over 0.3s
SHOT: medium on Sharma, dolly in
Sharma turns to teacher desk
Sharma picks up plane
SHOT: extreme close-up on Bunty, zoom in
Bunty gasps
SHOT: medium on Sharma, from right
Sharma: "Dear Golu. Answers: B. C. A. And... ask Pinky."

SCENE 8 (excerpt): The tiffin
SHOT: medium on Golu
Golu looks at tiffin
SOUND: sfx/stomach.wav, volume -4
Golu: "Just one bite. Nobody will know."
SHOT: close-up on tiffin, zoom in
SOUND: sfx/clink.wav, volume -4
WAIT 0.6s
frog appears on tiffin
SOUND: sfx/ribbit.wav, volume -2
WAIT 0.8s
SHOT: close-up on Golu, dolly in
Golu gasps
Golu: "MY MOMO HAS EYES!"
MUSIC: music/chase.ogg, volume -8
SHOT: wide on Golu and Sharma, from right
frog scurries to teacher desk

SCENE 10 (excerpt): the callback
Sharma (to Principal): "Sir... my dog ate my homework."
SHOT: medium on Bunty
Bunty (to Sharma): "Miss. You do not have a dog."
SHOT: close-up on Sharma
WAIT 0.8s
Sharma: "...He ate that too."
SOUND: sfx/laugh.wav, volume -4
```

Music plan used for this film (each file cut to its window, fading out):
`morning.ogg` 0:00–0:36 · `quiz.ogg` 1:37–1:58 · `chaos.ogg` 2:58–3:27 · `test.ogg` 3:51–4:14 ·
`chase.ogg` 4:17–4:37 · `finale.ogg` 5:25–5:42 (last chord on THE END).

---

## 12. MY FILM REQUEST

Replace everything in this box, then send the whole prompt.

```
Story idea:      <e.g. A village wedding where the groom's goat eats the wedding cake>
Genre / mood:    <comedy / emotional / thriller / kids / romance …>
Length:          <e.g. about 3 minutes>
Location(s):     <a location from section 4, or "you choose">
Characters:      <names, ages, looks, personalities — or "you choose">
Language:        <dialogue language, e.g. English, simple Nepali in Roman letters, Hindi>
Audience:        <kids / family / adults>
Must include:    <jokes, props, a twist, a song moment …>
Package name:    <folder name, e.g. the_goat_wedding>
My files:        <characters/animations/voices I'm supplying, or "none">
```

Deliver the complete package following sections 1–9. Reply with the files (or the .zip) only, plus a
short note of the estimated length and the music plan.

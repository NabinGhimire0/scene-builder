class_name MotionLibrary
extends RefCounted
## Procedural motion clips for the built-in [HumanCharacter].
##
## A pose is a Dictionary: joint name -> Vector3 rotation in degrees (local to
## the joint), plus "offset" -> Vector3 hips offset in metres (reference height
## 1.75 m; the character's scale is applied on top).
##
## Conventions (character faces +Z, its left side is +X):
##  • Limbs hanging down: −X swings forward, +X swings back.
##  • Upright segments (spine, chest, neck, head): +X leans/nods forward.
##  • Left arm/leg outward: +Z. Right arm/leg outward: −Z.
##  • Head/torso +Y turns to the character's left.
##  • Knee +X bends (shin goes back). Elbow −X bends (forearm comes forward).
##
## Every clip is a pure function of time (or walk phase), so playback, scrubbing
## and video export always produce exactly the same pose.

const AUTO := "Auto"
const ACTIONS: PackedStringArray = [
	"Auto", "Idle", "Walk", "Run", "Wave", "Talk", "Point", "Clap", "Cheer",
	"Think", "Look Around", "Sit", "Kneel", "Lie Down", "Hug", "Dance", "Jump", "Pose only"]
const ACTION_HINTS := {
	"Auto": "Stands idle, walks or runs automatically to match how fast you move the character",
	"Idle": "Standing, breathing, small weight shifts",
	"Walk": "Walk cycle (walks in place if the character isn't moving)",
	"Run": "Run cycle (runs in place if the character isn't moving)",
	"Wave": "Waves the right hand",
	"Talk": "Talking with head and hand gestures",
	"Point": "Points forward with the right arm",
	"Clap": "Claps hands",
	"Cheer": "Both arms up, bouncing",
	"Think": "Hand on chin, thinking",
	"Look Around": "Looks left and right",
	"Sit": "Sits down (place on a chair or bench)",
	"Kneel": "Kneels on the right knee",
	"Lie Down": "Lies on the back (place on a bed, sofa or the ground)",
	"Hug": "Arms around someone in front (stand two characters face to face, ~0.45 m apart)",
	"Dance": "A simple groove",
	"Jump": "Jumps on the spot",
	"Pose only": "Stands perfectly still in the pose you set by hand (Inspector → Pose)",
}

## Metres travelled per full walk / run cycle at the reference height.
const WALK_STRIDE := 1.4
const RUN_STRIDE := 2.7
## Cycles per second when walking / running in place.
const WALK_CADENCE := 0.95
const RUN_CADENCE := 1.45
## Seconds to blend from one action into the next.
const BLEND_TIME := 0.4

const JOINTS: PackedStringArray = [
	"hips", "spine", "chest", "neck", "head",
	"shoulder_l", "elbow_l", "wrist_l", "shoulder_r", "elbow_r", "wrist_r",
	"hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r"]


static func pose(action: String, t: float) -> Dictionary:
	match action:
		"Walk":
			return walk(t * WALK_CADENCE)
		"Run":
			return run(t * RUN_CADENCE)
		"Wave":
			return wave(t)
		"Talk":
			return talk(t)
		"Point":
			return point(t)
		"Clap":
			return clap(t)
		"Cheer":
			return cheer(t)
		"Think":
			return think(t)
		"Look Around":
			return look_around(t)
		"Sit":
			return sit(t)
		"Kneel":
			return kneel(t)
		"Lie Down":
			return lie_down(t)
		"Hug":
			return hug(t)
		"Dance":
			return dance(t)
		"Jump":
			return jump(t)
		"Pose only":
			return {}
	return idle(t)


## Blends two poses; [param weight] 0 = a, 1 = b.
static func blend(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	if weight <= 0.0:
		return a
	if weight >= 1.0:
		return b
	var out := {}
	for key in a:
		out[key] = (a[key] as Vector3).lerp(b.get(key, Vector3.ZERO), weight)
	for key in b:
		if not out.has(key):
			out[key] = Vector3.ZERO.lerp(b[key], weight)
	return out


# --- Clips ----------------------------------------------------------------------

static func idle(t: float) -> Dictionary:
	var breath := sin(TAU * t / 4.2)
	var shift := sin(TAU * t / 7.0)
	var look := sin(TAU * t / 9.0 + 1.3)
	return {
		"offset": Vector3(0.012 * shift, -0.004 + 0.003 * breath, 0.0),
		"hips": Vector3(0.0, 2.0 * shift, -1.5 * shift),
		"spine": Vector3(1.0 + 0.6 * breath, 0.0, 1.0 * shift),
		"chest": Vector3(1.2 * breath, -2.0 * shift, 0.5 * shift),
		"head": Vector3(-2.0 + 1.5 * sin(TAU * t / 5.3), 8.0 * look, -1.5 * shift),
		"shoulder_l": Vector3(2.0 + 1.5 * breath, 0.0, 7.0),
		"elbow_l": Vector3(-10.0, 0.0, 0.0),
		"shoulder_r": Vector3(2.0 + 1.5 * breath, 0.0, -7.0),
		"elbow_r": Vector3(-10.0, 0.0, 0.0),
		"hip_l": Vector3(0.0, 0.0, 2.0 + 1.5 * shift),
		"knee_l": Vector3(3.0 + 3.0 * maxf(shift, 0.0), 0.0, 0.0),
		"ankle_l": Vector3(-2.0 * maxf(shift, 0.0), 0.0, -1.5 * shift),
		"hip_r": Vector3(0.0, 0.0, -2.0 + 1.5 * shift),
		"knee_r": Vector3(3.0 + 3.0 * maxf(-shift, 0.0), 0.0, 0.0),
		"ankle_r": Vector3(-2.0 * maxf(-shift, 0.0), 0.0, -1.5 * shift),
	}


## [param phase] counts walk cycles (1.0 = one left step + one right step).
static func walk(phase: float) -> Dictionary:
	var w := TAU * phase
	var s := sin(w)
	var c := cos(w)
	var knee_l := 6.0 + 50.0 * pow(maxf(c, 0.0), 1.5)
	var knee_r := 6.0 + 50.0 * pow(maxf(-c, 0.0), 1.5)
	var hip_l := -24.0 * s
	var hip_r := 24.0 * s
	return {
		"offset": Vector3(0.0, -0.02 + 0.02 * cos(2.0 * w), 0.0),
		"hips": Vector3(0.0, -6.0 * s, 2.0 * s),
		"spine": Vector3(4.0, 3.0 * s, 0.0),
		"chest": Vector3(2.0, 4.0 * s, -1.0 * s),
		"head": Vector3(-3.0, -3.0 * s, 0.0),
		"shoulder_l": Vector3(22.0 * s, 0.0, 6.0),
		"elbow_l": Vector3(-14.0 - 14.0 * maxf(-s, 0.0), 0.0, 0.0),
		"shoulder_r": Vector3(-22.0 * s, 0.0, -6.0),
		"elbow_r": Vector3(-14.0 - 14.0 * maxf(s, 0.0), 0.0, 0.0),
		"hip_l": Vector3(hip_l, 0.0, 1.0),
		"knee_l": Vector3(knee_l, 0.0, 0.0),
		"ankle_l": Vector3(clampf(-(hip_l + knee_l) * 0.6, -25.0, 25.0), 0.0, 0.0),
		"hip_r": Vector3(hip_r, 0.0, -1.0),
		"knee_r": Vector3(knee_r, 0.0, 0.0),
		"ankle_r": Vector3(clampf(-(hip_r + knee_r) * 0.6, -25.0, 25.0), 0.0, 0.0),
	}


static func run(phase: float) -> Dictionary:
	var w := TAU * phase
	var s := sin(w)
	var c := cos(w)
	var knee_l := 18.0 + 85.0 * pow(maxf(c, 0.0), 1.2)
	var knee_r := 18.0 + 85.0 * pow(maxf(-c, 0.0), 1.2)
	var hip_l := -40.0 * s - 8.0
	var hip_r := 40.0 * s - 8.0
	return {
		"offset": Vector3(0.0, -0.05 + 0.05 * absf(cos(w)), 0.0),
		"hips": Vector3(0.0, -9.0 * s, 2.0 * s),
		"spine": Vector3(10.0, 5.0 * s, 0.0),
		"chest": Vector3(4.0, 7.0 * s, 0.0),
		"head": Vector3(-8.0, -5.0 * s, 0.0),
		"shoulder_l": Vector3(42.0 * s, 0.0, 8.0),
		"elbow_l": Vector3(-85.0, 0.0, 0.0),
		"shoulder_r": Vector3(-42.0 * s, 0.0, -8.0),
		"elbow_r": Vector3(-85.0, 0.0, 0.0),
		"hip_l": Vector3(hip_l, 0.0, 1.0),
		"knee_l": Vector3(knee_l, 0.0, 0.0),
		"ankle_l": Vector3(clampf(-(hip_l + knee_l) * 0.5, -30.0, 30.0), 0.0, 0.0),
		"hip_r": Vector3(hip_r, 0.0, -1.0),
		"knee_r": Vector3(knee_r, 0.0, 0.0),
		"ankle_r": Vector3(clampf(-(hip_r + knee_r) * 0.5, -30.0, 30.0), 0.0, 0.0),
	}


static func wave(t: float) -> Dictionary:
	var p := idle(t)
	p["shoulder_r"] = Vector3(-10.0, 0.0, -150.0)
	p["elbow_r"] = Vector3(0.0, 0.0, -15.0 - 28.0 * sin(TAU * t * 1.6))
	p["head"] = Vector3(-4.0, -10.0, 3.0)
	p["chest"] = Vector3(0.0, -4.0, 3.0)
	return p


static func talk(t: float) -> Dictionary:
	var p := idle(t)
	p["head"] = Vector3(3.0 * sin(TAU * t * 1.3) + 2.0 * sin(TAU * t * 3.1), 7.0 * sin(TAU * t * 0.6), 2.0 * sin(TAU * t * 0.8))
	p["shoulder_l"] = Vector3(-18.0 + 6.0 * sin(TAU * t * 0.9), 0.0, 10.0)
	p["elbow_l"] = Vector3(-65.0 + 12.0 * sin(TAU * t * 1.1), 0.0, 0.0)
	p["shoulder_r"] = Vector3(-14.0 + 7.0 * sin(TAU * t * 0.7 + 1.0), 0.0, -10.0)
	p["elbow_r"] = Vector3(-60.0 + 14.0 * sin(TAU * t * 1.3 + 2.0), 0.0, 0.0)
	p["wrist_l"] = Vector3(0.0, 0.0, 10.0 * sin(TAU * t * 1.1))
	p["wrist_r"] = Vector3(0.0, 0.0, -10.0 * sin(TAU * t * 0.9))
	return p


static func point(t: float) -> Dictionary:
	var p := idle(t)
	p["shoulder_r"] = Vector3(-82.0, 0.0, -10.0)
	p["elbow_r"] = Vector3(-6.0, 0.0, 0.0)
	p["chest"] = Vector3(0.0, -8.0, 0.0)
	p["head"] = Vector3(-2.0, -6.0, 0.0)
	return p


static func clap(t: float) -> Dictionary:
	var p := idle(t)
	var open := 0.5 + 0.5 * sin(TAU * t * 2.5)
	p["shoulder_l"] = Vector3(-42.0, 0.0, 6.0 + 16.0 * open)
	p["shoulder_r"] = Vector3(-42.0, 0.0, -6.0 - 16.0 * open)
	p["elbow_l"] = Vector3(-72.0, 0.0, 0.0)
	p["elbow_r"] = Vector3(-72.0, 0.0, 0.0)
	p["head"] = Vector3(4.0, 0.0, 0.0)
	return p


static func cheer(t: float) -> Dictionary:
	var p := idle(t)
	var bounce := absf(sin(TAU * t * 1.5))
	p["offset"] = Vector3(0.0, -0.03 + 0.04 * bounce, 0.0)
	p["shoulder_l"] = Vector3(-10.0, 0.0, 155.0 + 8.0 * sin(TAU * t * 1.5))
	p["shoulder_r"] = Vector3(-10.0, 0.0, -155.0 - 8.0 * sin(TAU * t * 1.5))
	p["elbow_l"] = Vector3(0.0, 0.0, 10.0)
	p["elbow_r"] = Vector3(0.0, 0.0, -10.0)
	p["head"] = Vector3(-12.0, 0.0, 0.0)
	p["knee_l"] = Vector3(8.0 + 12.0 * (1.0 - bounce), 0.0, 0.0)
	p["knee_r"] = Vector3(8.0 + 12.0 * (1.0 - bounce), 0.0, 0.0)
	p["hip_l"] = Vector3(-5.0 * (1.0 - bounce), 0.0, 3.0)
	p["hip_r"] = Vector3(-5.0 * (1.0 - bounce), 0.0, -3.0)
	return p


static func think(t: float) -> Dictionary:
	var p := idle(t)
	p["shoulder_r"] = Vector3(-38.0, 0.0, -14.0)
	p["elbow_r"] = Vector3(-132.0, 0.0, 0.0)
	p["wrist_r"] = Vector3(-20.0, 0.0, 0.0)
	p["shoulder_l"] = Vector3(-22.0, 0.0, -6.0)
	p["elbow_l"] = Vector3(-95.0, 25.0, 0.0)
	p["head"] = Vector3(8.0, 6.0 * sin(TAU * t / 6.0), 6.0)
	return p


static func look_around(t: float) -> Dictionary:
	var p := idle(t)
	var turn := sin(TAU * t / 5.0)
	p["head"] = Vector3(-3.0, 55.0 * turn, 0.0)
	p["chest"] = Vector3(0.0, 15.0 * turn, 0.0)
	p["neck"] = Vector3(0.0, 10.0 * turn, 0.0)
	return p


static func sit(t: float) -> Dictionary:
	var breath := sin(TAU * t / 4.2)
	return {
		"offset": Vector3(0.0, -0.43, -0.04),
		"spine": Vector3(-6.0 + 0.6 * breath, 0.0, 0.0),
		"chest": Vector3(2.0 + 1.2 * breath, 0.0, 0.0),
		"head": Vector3(2.0, 6.0 * sin(TAU * t / 8.0), 0.0),
		"shoulder_l": Vector3(-28.0, 0.0, 8.0),
		"elbow_l": Vector3(-52.0, 0.0, 0.0),
		"shoulder_r": Vector3(-28.0, 0.0, -8.0),
		"elbow_r": Vector3(-52.0, 0.0, 0.0),
		"hip_l": Vector3(-88.0, 0.0, 5.0),
		"knee_l": Vector3(88.0, 0.0, 0.0),
		"ankle_l": Vector3(0.0, 0.0, 0.0),
		"hip_r": Vector3(-88.0, 0.0, -5.0),
		"knee_r": Vector3(88.0, 0.0, 0.0),
		"ankle_r": Vector3(0.0, 0.0, 0.0),
	}


static func kneel(t: float) -> Dictionary:
	var breath := sin(TAU * t / 4.0)
	return {
		"offset": Vector3(0.0, -0.42, -0.05),
		"spine": Vector3(6.0 + 0.6 * breath, 0.0, 0.0),
		"chest": Vector3(2.0 + breath, 0.0, 0.0),
		"head": Vector3(4.0, 0.0, 0.0),
		"shoulder_l": Vector3(-40.0, 0.0, 6.0),
		"elbow_l": Vector3(-45.0, 0.0, 0.0),
		"shoulder_r": Vector3(-20.0, 0.0, -6.0),
		"elbow_r": Vector3(-35.0, 0.0, 0.0),
		"hip_l": Vector3(-88.0, 0.0, 4.0),
		"knee_l": Vector3(88.0, 0.0, 0.0),
		"ankle_l": Vector3(0.0, 0.0, 0.0),
		"hip_r": Vector3(2.0, 0.0, -3.0),
		"knee_r": Vector3(92.0, 0.0, 0.0),
		"ankle_r": Vector3(-40.0, 0.0, 0.0),
	}


## Lying on the back: the whole body tips back from the hips (legs towards +Z).
static func lie_down(t: float) -> Dictionary:
	var breath := sin(TAU * t / 4.5)
	return {
		"offset": Vector3(0.0, -0.8, -0.35),
		"hips": Vector3(-90.0, 0.0, 0.0),
		"spine": Vector3(-1.0 * breath, 0.0, 0.0),
		"chest": Vector3(-1.5 * breath, 0.0, 0.0),
		"neck": Vector3(10.0, 0.0, 0.0),
		"head": Vector3(8.0, 0.0, 0.0),
		"shoulder_l": Vector3(-6.0, 0.0, 10.0),
		"elbow_l": Vector3(-20.0, 0.0, 0.0),
		"shoulder_r": Vector3(-6.0, 0.0, -10.0),
		"elbow_r": Vector3(-20.0, 0.0, 0.0),
		"hip_l": Vector3(-4.0, 0.0, 3.0),
		"knee_l": Vector3(6.0, 0.0, 0.0),
		"hip_r": Vector3(-4.0, 0.0, -3.0),
		"knee_r": Vector3(6.0, 0.0, 0.0),
	}


static func hug(t: float) -> Dictionary:
	var squeeze := 0.5 + 0.5 * sin(TAU * t / 2.6)
	var pose := idle(t)
	pose["chest"] = Vector3(6.0, 0.0, 0.0)
	pose["spine"] = Vector3(4.0, 0.0, 0.0)
	pose["head"] = Vector3(8.0, 18.0, 6.0)
	pose["shoulder_l"] = Vector3(-78.0, 0.0, -18.0 - 6.0 * squeeze)
	pose["elbow_l"] = Vector3(-55.0 - 8.0 * squeeze, 0.0, 0.0)
	pose["wrist_l"] = Vector3(0.0, 0.0, -10.0)
	pose["shoulder_r"] = Vector3(-78.0, 0.0, 18.0 + 6.0 * squeeze)
	pose["elbow_r"] = Vector3(-55.0 - 8.0 * squeeze, 0.0, 0.0)
	pose["wrist_r"] = Vector3(0.0, 0.0, 10.0)
	return pose


static func dance(t: float) -> Dictionary:
	var beat := t * 1.83  # ~110 bpm
	var b := sin(TAU * beat)
	var sway := sin(TAU * beat * 0.5)
	var bend := 15.0 + 15.0 * absf(b)
	return {
		"offset": Vector3(0.06 * sway, -0.05 + 0.04 * absf(b), 0.0),
		"hips": Vector3(0.0, 10.0 * sway, 8.0 * sway),
		"spine": Vector3(4.0, -6.0 * sway, -5.0 * sway),
		"chest": Vector3(2.0, -6.0 * sway, -4.0 * sway),
		"head": Vector3(6.0 * b, 5.0 * sway, 0.0),
		"shoulder_l": Vector3(-30.0 * sway, 0.0, 40.0 + 30.0 * b),
		"elbow_l": Vector3(-60.0, 0.0, 0.0),
		"shoulder_r": Vector3(30.0 * sway, 0.0, -40.0 + 30.0 * b),
		"elbow_r": Vector3(-60.0, 0.0, 0.0),
		"hip_l": Vector3(-bend * 0.6, 0.0, 4.0),
		"knee_l": Vector3(bend, 0.0, 0.0),
		"ankle_l": Vector3(-bend * 0.4, 0.0, 0.0),
		"hip_r": Vector3(-bend * 0.6, 0.0, -4.0),
		"knee_r": Vector3(bend, 0.0, 0.0),
		"ankle_r": Vector3(-bend * 0.4, 0.0, 0.0),
	}


static func jump(t: float) -> Dictionary:
	var period := 1.4
	var u := fposmod(t, period) / period
	var crouch := smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.2, 0.3, u)) \
		+ smoothstep(0.52, 0.6, u) * (1.0 - smoothstep(0.65, 0.9, u))
	var air := sin(PI * (u - 0.25) / 0.3) if u > 0.25 and u < 0.55 else 0.0
	return {
		"offset": Vector3(0.0, -0.22 * crouch + 0.45 * air, 0.0),
		"spine": Vector3(20.0 * crouch, 0.0, 0.0),
		"head": Vector3(-8.0 * crouch, 0.0, 0.0),
		"shoulder_l": Vector3(40.0 * crouch - 120.0 * air, 0.0, 10.0),
		"elbow_l": Vector3(-20.0, 0.0, 0.0),
		"shoulder_r": Vector3(40.0 * crouch - 120.0 * air, 0.0, -10.0),
		"elbow_r": Vector3(-20.0, 0.0, 0.0),
		"hip_l": Vector3(-45.0 * crouch - 10.0 * air, 0.0, 3.0),
		"knee_l": Vector3(90.0 * crouch + 20.0 * air, 0.0, 0.0),
		"ankle_l": Vector3(-40.0 * crouch + 20.0 * air, 0.0, 0.0),
		"hip_r": Vector3(-45.0 * crouch - 10.0 * air, 0.0, -3.0),
		"knee_r": Vector3(90.0 * crouch + 20.0 * air, 0.0, 0.0),
		"ankle_r": Vector3(-40.0 * crouch + 20.0 * air, 0.0, 0.0),
	}

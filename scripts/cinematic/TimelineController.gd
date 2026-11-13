class_name TimelineController
extends Node
## The cinematic timeline.
##
## Keyframes live in a [KeyframeStore]. Whenever they change, the store is
## compiled into the "cinematic/main" Animation of the AnimationPlayer: one value
## track per animated property (position / rotation / scale of objects, lens of
## cameras, lighting of the environment) plus a discrete camera-cut track that
## drives [member CinematicDirector.active_shot_uid]. Playback, scrubbing and
## video export all go through that AnimationPlayer.
##
## Auto-Key: while on, any edit to an object's transform, a camera's lens or the
## lighting writes a keyframe at the playhead, in the same undo step as the edit.
##
## Characters additionally have an "action" channel (Idle, Walk, Wave…). It is not
## compiled into the AnimationPlayer: after every seek each character poses itself
## from its action keys and a [CharacterMotion] table sampled from the compiled
## position track, so walk cycles match the movement exactly.

signal time_changed(time: float)
signal playing_changed(playing: bool)
signal keys_changed

enum Interpolation { SMOOTH, LINEAR, FLOWING }

const INTERPOLATION_NAMES: PackedStringArray = ["Smooth motion", "Linear motion", "Flowing motion"]
const LIBRARY := &"cinematic"
const MAIN := &"main"
const ANIM_NAME := &"cinematic/main"
const CH_TRANSFORM := "transform"
const CH_LENS := "lens"
const CH_LIGHTING := "lighting"
const CH_ACTION := "action"
const CH_POSE := "pose"
const CH_FACE := "face"
const ENV_UID := "environment"
const MIN_DURATION := 1.0
const MAX_DURATION := 600.0
const WARN_INTERVAL_MS := 4000

@export var director: CinematicDirector
@export var environment: EnvironmentController
@export var history: EditorHistory
@export var placed_props_root: Node3D
@export var cameras_root: Node3D

var store := KeyframeStore.new()
var current_time := 0.0
var auto_key := false
## Keys snap to this frame grid; kept in sync with the export frame rate.
var frame_rate := 30.0

var _dirty := true
var _playing := false
var _cinematic_play := false
var _view_before_play := 0
var _last_warn_ms := -WARN_INTERVAL_MS
var _motions: Dictionary = {}   # character uid -> CharacterMotion
var _pose_queued := false

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	animation_player.root_node = NodePath("../..")
	if not animation_player.has_animation_library(LIBRARY):
		var library := AnimationLibrary.new()
		var animation := Animation.new()
		animation.length = store.duration
		library.add_animation(MAIN, animation)
		animation_player.add_animation_library(LIBRARY, library)
	animation_player.animation_finished.connect(_on_animation_finished)
	store.changed.connect(_on_store_changed)
	EventBus.history_changed.connect(_mark_dirty)
	EventBus.history_changed.connect(_queue_character_pose)
	if history:
		history.keyframe_hook = _keyframe_hook


func _process(_delta: float) -> void:
	if _playing and animation_player.is_playing():
		current_time = animation_player.current_animation_position
		_apply_characters(current_time)
		time_changed.emit(current_time)


# --- Properties ----------------------------------------------------------------

func duration() -> float:
	return store.duration


func set_duration(seconds: float) -> void:
	seconds = clampf(snappedf(seconds, 0.1), MIN_DURATION, MAX_DURATION)
	if is_equal_approx(seconds, store.duration):
		return
	var before := store.snapshot()
	store.duration = seconds
	_commit("Set duration to %.1f s" % seconds, before, true)
	if current_time > seconds:
		set_time(seconds)


func interpolation() -> int:
	return store.interpolation


func set_interpolation(mode: int) -> void:
	if mode == store.interpolation:
		return
	var before := store.snapshot()
	store.interpolation = mode
	_commit("Interpolation: %s" % INTERPOLATION_NAMES[mode], before)


func is_playing() -> bool:
	return _playing


func snap_time(t: float) -> float:
	return clampf(round(t * frame_rate) / frame_rate, 0.0, store.duration)


# --- Transport ------------------------------------------------------------------

func play() -> void:
	if _playing:
		return
	_ensure_built()
	if current_time >= store.duration - 0.001:
		current_time = 0.0
	animation_player.play(ANIM_NAME)
	animation_player.seek(current_time, true)
	_playing = true
	playing_changed.emit(true)


## Plays the whole film from the start through the camera cuts.
func play_cinematic() -> void:
	if _playing:
		pause()
	_cinematic_play = true
	_view_before_play = director.view_mode
	if not director.cameras().is_empty():
		director.set_view_mode(CinematicDirector.ViewMode.CAMERA)
	else:
		EventBus.info("No cameras yet: playing in the editor view. Add a camera to preview the film.")
	current_time = 0.0
	play()


func pause() -> void:
	if not _playing:
		return
	current_time = animation_player.current_animation_position
	animation_player.pause()
	_playing = false
	playing_changed.emit(false)
	_end_cinematic()


func toggle_play() -> void:
	if _playing:
		pause()
	else:
		play()


func stop() -> void:
	if _playing:
		animation_player.pause()
		_playing = false
		playing_changed.emit(false)
		_end_cinematic()
	set_time(0.0)


func set_time(t: float, apply: bool = true) -> void:
	current_time = clampf(t, 0.0, store.duration)
	if _playing:
		animation_player.seek(current_time, true)
		_apply_characters(current_time)
	elif apply:
		_apply_current()
	time_changed.emit(current_time)


func step_frames(frames: int) -> void:
	if _playing:
		pause()
	set_time(snap_time(current_time) + frames / frame_rate)


## Applies the animation at [param t] for the video exporter (no UI signals).
func apply_time_for_render(t: float) -> void:
	current_time = t
	_ensure_built()
	animation_player.assigned_animation = ANIM_NAME
	animation_player.seek(t, true)
	_apply_characters(t)


func _apply_current() -> void:
	_ensure_built()
	animation_player.assigned_animation = ANIM_NAME
	animation_player.seek(current_time, true)
	_apply_characters(current_time)


func _on_animation_finished(_anim_name: StringName) -> void:
	_playing = false
	current_time = store.duration
	time_changed.emit(current_time)
	playing_changed.emit(false)
	_end_cinematic()


func _end_cinematic() -> void:
	if _cinematic_play:
		_cinematic_play = false
		director.set_view_mode(_view_before_play)


# --- Keyframes ------------------------------------------------------------------

func uid_for(target: Object) -> String:
	if target == environment:
		return ENV_UID
	return PropUtils.uid_of(target as Node)


func display_name(target: Object) -> String:
	return "Lighting" if target == environment else str((target as Node).name)


func channels_for(target: Object) -> PackedStringArray:
	if target == environment:
		return PackedStringArray([CH_LIGHTING])
	if target is CinematicCamera:
		return PackedStringArray([CH_TRANSFORM, CH_LENS])
	return PackedStringArray([CH_TRANSFORM])


func capture(target: Object, channel: String) -> Dictionary:
	match channel:
		CH_TRANSFORM:
			var node := target as Node3D
			return {"position": node.position, "quaternion": node.quaternion, "scale": node.scale}
		CH_LENS:
			return (target as CinematicCamera).lens_state()
		CH_LIGHTING:
			return environment.capture()
	return {}


## Records every channel of [param target] at the playhead (undoable).
func add_keyframe(target: Object) -> void:
	if target == null:
		EventBus.info("Select an object or camera first (or use Key Lighting).")
		return
	if _playing:
		pause()
	var uid := uid_for(target)
	var t := snap_time(current_time)
	var before := store.snapshot()
	for channel in channels_for(target):
		store.set_key(uid, channel, t, capture(target, channel), false)
	_commit("Keyframe %s at %.2f s" % [display_name(target), t], before)
	EventBus.info("Keyframe added: %s at %.2f s." % [display_name(target), t])


## Keys [param target] moving along [param points] (world positions on the
## ground) at [param speed] m/s, starting at the playhead. Characters walk or
## run automatically from the speed; other objects turn to face the way.
func add_path_keys(target: Node3D, points: Array, speed: float) -> void:
	if target == null or points.size() < 2:
		return
	if _playing:
		pause()
	var uid := uid_for(target)
	var before := store.snapshot()
	var start := snap_time(current_time)
	var terrain := get_tree().get_first_node_in_group(&"terrain") as Terrain
	var base := capture(target, CH_TRANSFORM)
	var faces := not target is CharacterBase
	var travelled := 0.0
	var end_time := start
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var span := a.distance_to(b)
		var steps := maxi(1, ceili(span / 1.0))
		for step in range(0 if i == 0 else 1, steps + 1):
			var f := float(step) / float(steps)
			var p := a.lerp(b, f)
			if terrain and Terrain.contains(p.x, p.z) and absf(a.y - terrain.height_at(a.x, a.z)) < 0.05 and absf(b.y - terrain.height_at(b.x, b.z)) < 0.05:
				p.y = terrain.height_at(p.x, p.z)
			var values := base.duplicate()
			var parent := target.get_parent() as Node3D
			values["position"] = parent.to_local(p) if parent else p
			if faces and span > 0.01:
				var dir := (b - a).normalized()
				values["quaternion"] = Quaternion(Vector3.UP, atan2(dir.x, dir.z))
			end_time = start + (travelled + span * f) / maxf(speed, 0.05)
			store.set_key(uid, CH_TRANSFORM, snap_time(end_time), values, false)
		travelled += span
	if end_time + 0.5 > duration():
		set_duration(minf(end_time + 1.0, MAX_DURATION))
	_commit("Path for %s" % display_name(target), before)
	EventBus.info("%s now %s along the path: %.1f m in %.1f s." % [
		display_name(target), "runs" if speed > 2.5 else "walks", travelled, end_time - start])


## Ready-made camera moves, keyed from the playhead for [param seconds].
const CAMERA_MOVES: PackedStringArray = [
	"Dolly in", "Dolly out", "Truck left", "Truck right", "Crane up", "Crane down",
	"Pan left", "Pan right", "Tilt up", "Tilt down", "Orbit left", "Orbit right", "Zoom in", "Zoom out"]


func add_camera_move(cam: CinematicCamera, move: String, seconds: float, amount: float) -> void:
	if cam == null:
		return
	if _playing:
		pause()
	var uid := uid_for(cam)
	var before := store.snapshot()
	var t0 := snap_time(current_time)
	var t1 := snap_time(t0 + maxf(seconds, 0.2))
	var start_xf := cam.transform
	var basis := start_xf.basis.orthonormalized()
	var forward := -basis.z
	var right := basis.x
	var lens := cam.lens_state()
	var key_xf := func(time: float, xf: Transform3D) -> void:
		store.set_key(uid, CH_TRANSFORM, time, {"position": xf.origin, "quaternion": xf.basis.get_rotation_quaternion(), "scale": cam.scale}, false)
	key_xf.call(t0, start_xf)
	store.set_key(uid, CH_LENS, t0, lens, false)
	var end_xf := start_xf
	match move:
		"Dolly in":
			end_xf.origin += forward * amount
		"Dolly out":
			end_xf.origin -= forward * amount
		"Truck left":
			end_xf.origin -= right * amount
		"Truck right":
			end_xf.origin += right * amount
		"Crane up":
			end_xf.origin += Vector3.UP * amount
		"Crane down":
			end_xf.origin -= Vector3.UP * amount
		"Pan left", "Pan right":
			var yaw := deg_to_rad(amount * 10.0) * (1.0 if move == "Pan left" else -1.0)
			end_xf.basis = Basis(Vector3.UP, yaw) * basis
		"Tilt up", "Tilt down":
			var pitch := deg_to_rad(amount * 5.0) * (1.0 if move == "Tilt up" else -1.0)
			end_xf.basis = basis * Basis(Vector3.RIGHT, pitch)
		"Orbit left", "Orbit right":
			var pivot := start_xf.origin + forward * cam.focus_distance
			var total := deg_to_rad(amount * 20.0) * (1.0 if move == "Orbit left" else -1.0)
			for k in range(1, 7):
				var turn := Basis(Vector3.UP, total * float(k) / 6.0)
				var xf := Transform3D(turn * basis, pivot + turn * (start_xf.origin - pivot))
				key_xf.call(snap_time(lerpf(t0, t1, float(k) / 6.0)), xf)
			end_xf = Transform3D()
		"Zoom in", "Zoom out":
			var end_lens := lens.duplicate()
			end_lens["fov"] = clampf(cam.fov * (1.0 - 0.12 * amount if move == "Zoom in" else 1.0 + 0.15 * amount), 5.0, 140.0)
			store.set_key(uid, CH_LENS, t1, end_lens, false)
	if end_xf != Transform3D():
		key_xf.call(t1, end_xf)
	if t1 + 0.5 > duration():
		set_duration(minf(t1 + 1.0, MAX_DURATION))
	_commit("%s on %s" % [move, display_name(cam)], before)
	EventBus.info("%s added from %.2f s to %.2f s." % [move, t0, t1])


## Makes [param character] start [param action] at the playhead (undoable).
func set_character_action(character: CharacterBase, action: String) -> void:
	if character == null:
		return
	if _playing:
		pause()
	var t := snap_time(current_time)
	var before := store.snapshot()
	store.set_key(uid_for(character), CH_ACTION, t, {"action": action}, false)
	_commit("%s: %s at %.2f s" % [character.name, action, t], before)
	EventBus.info("%s will %s from %.2f s." % [character.name, action.to_lower() if action != MotionLibrary.AUTO else "move automatically", t])


## The action [param character] is doing at the playhead.
func character_action_at(character: CharacterBase, t: float) -> String:
	var motion: CharacterMotion = _motions.get(str(character.get_meta(PropUtils.META_UID, "")))
	if motion == null:
		motion = CharacterMotion.new()
		motion.actions = _action_keys(str(character.get_meta(PropUtils.META_UID, "")))
	return str(motion.action_state(t)["action"])


func delete_keys_at(uid: String, t: float) -> void:
	var before := store.snapshot()
	if store.remove_keys_at(uid, t, false) > 0:
		_commit("Delete keyframe at %.2f s" % t, before)


func move_keys(uid: String, from_t: float, to_t: float) -> void:
	to_t = snap_time(to_t)
	if absf(from_t - to_t) < KeyframeStore.EPSILON:
		return
	var before := store.snapshot()
	store.move_keys(uid, from_t, to_t, false)
	_commit("Move keyframe to %.2f s" % to_t, before)


## Cuts to [param camera] at the playhead (undoable).
func add_cut(camera: CinematicCamera) -> void:
	if camera == null:
		EventBus.info("Select a camera (or add one) to cut to it.")
		return
	var t := snap_time(current_time)
	var before := store.snapshot()
	store.set_cut(t, camera.uid(), false)
	_commit("Cut to %s at %.2f s" % [camera.name, t], before)
	EventBus.info("Camera cut: %s from %.2f s." % [camera.name, t])


func delete_cut(t: float) -> void:
	var before := store.snapshot()
	if store.remove_cut(t, false):
		_commit("Delete camera cut", before)


func move_cut(from_t: float, to_t: float) -> void:
	to_t = snap_time(to_t)
	if absf(from_t - to_t) < KeyframeStore.EPSILON:
		return
	var before := store.snapshot()
	store.move_cut(from_t, to_t, false)
	_commit("Move camera cut", before)


## Rows for the timeline view: camera cuts, lighting, then every object that has
## keyframes (plus [param selected], so it can be keyed).
func rows(selected: Node) -> Array:
	var out: Array = []
	out.append({"kind": "cuts", "label": "Camera cuts", "uid": "", "times": store.cut_times(), "node": null})
	out.append({"kind": "lighting", "label": "Lighting", "uid": ENV_UID, "times": store.key_times(ENV_UID), "node": environment})
	for root in [cameras_root, placed_props_root]:
		if root == null:
			continue
		for child in root.get_children():
			var uid := str(child.get_meta(PropUtils.META_UID, ""))
			var times := store.key_times(uid) if not uid.is_empty() else PackedFloat32Array()
			if not times.is_empty() or child == selected:
				var labels: Array = []
				for key in _action_keys(uid):
					labels.append([float(key["t"]), str(key["action"])])
				out.append({"kind": "camera" if child is CinematicCamera else "object",
					"label": str(child.name), "uid": uid, "times": times, "node": child, "labels": labels})
	return out


func camera_name(uid: String) -> String:
	var cam := director.find_camera(uid)
	return str(cam.name) if cam else "(deleted)"


# --- Scene lifecycle ------------------------------------------------------------

func reset() -> void:
	if _playing:
		animation_player.pause()
		_playing = false
		playing_changed.emit(false)
	_cinematic_play = false
	auto_key = false
	store.clear()
	current_time = 0.0
	time_changed.emit(current_time)


func to_dict() -> Dictionary:
	var valid := {ENV_UID: true}
	for root in [cameras_root, placed_props_root]:
		for child in root.get_children():
			if child.has_meta(PropUtils.META_UID):
				valid[str(child.get_meta(PropUtils.META_UID))] = true
	return store.to_json(valid)


func load_dict(data: Dictionary) -> void:
	store.load_json(data)
	current_time = 0.0
	set_time(0.0)


## Snapshot for undo actions that also clear the timeline (e.g. Clear Scene).
func clear_keys_snapshot() -> Dictionary:
	var empty := store.snapshot()
	empty["channels"] = {}
	empty["cuts"] = []
	return empty


func restore_store(state: Dictionary) -> void:
	store.restore(state)


# --- Internals ------------------------------------------------------------------

func _commit(label: String, before: Dictionary, merge: bool = false) -> void:
	history.record_snapshot(label, restore_store, before, store.snapshot(), merge)


## Called by EditorHistory inside an edit's undo step.
func _keyframe_hook(target: Object, channel: String, overrides: Dictionary) -> Array:
	if target == null or not (target == environment or target is Node3D):
		return []
	var uid := uid_for(target)
	if not auto_key:
		if store.has_channel(uid, channel) and Time.get_ticks_msec() - _last_warn_ms > WARN_INTERVAL_MS:
			_last_warn_ms = Time.get_ticks_msec()
			EventBus.info("%s is animated: this change lasts until you scrub. Press Add Keyframe (or turn on Auto-Key) to keep it at %.2f s." % [display_name(target), current_time])
		return []
	var before := store.snapshot()
	var values := capture(target, channel)
	values.merge(overrides, true)
	store.set_key(uid, channel, snap_time(current_time), values, false)
	var after := store.snapshot()
	store.restore(before, false)
	return [restore_store, before, after]


func _mark_dirty() -> void:
	_dirty = true


func _on_store_changed() -> void:
	_dirty = true
	if animation_player and not _playing:
		_apply_current()
	keys_changed.emit()


func _ensure_built() -> void:
	if _dirty:
		_rebuild()


func _rebuild() -> void:
	var animation := animation_player.get_animation(ANIM_NAME)
	if animation == null:
		return
	animation.clear()
	animation.length = store.duration
	animation.loop_mode = Animation.LOOP_NONE
	var root := animation_player.get_node(animation_player.root_node)

	for id in store.channels:
		var parts := KeyframeStore.split_id(id)
		if parts.size() > 1 and (parts[1] == CH_ACTION or parts[1] == CH_POSE or parts[1] == CH_FACE):
			continue  # actions and hand poses drive characters directly (see _apply_characters)
		var target := _resolve(parts[0])
		var keys: Array = store.channels[id]
		if target == null or keys.is_empty():
			continue
		var base := str(root.get_path_to(target))
		var first: Dictionary = keys[0]["v"]
		for property in first:
			var continuous := _is_continuous(first[property])
			var track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(track, NodePath("%s:%s" % [base, property]))
			animation.value_track_set_update_mode(track,
				Animation.UPDATE_CONTINUOUS if continuous else Animation.UPDATE_DISCRETE)
			var spline := continuous and store.interpolation == Interpolation.FLOWING
			animation.track_set_interpolation_type(track,
				Animation.INTERPOLATION_CUBIC if spline else Animation.INTERPOLATION_LINEAR)
			var transition := -2.0 if continuous and store.interpolation == Interpolation.SMOOTH else 1.0
			for key in keys:
				var values: Dictionary = key["v"]
				if values.has(property):
					animation.track_insert_key(track, float(key["t"]), values[property], 1.0 if key.get("g", false) else transition)

	if store.cuts.is_empty():
		director.active_shot_uid = ""
	else:
		var cut_track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(cut_track, NodePath("%s:active_shot_uid" % root.get_path_to(director)))
		animation.value_track_set_update_mode(cut_track, Animation.UPDATE_DISCRETE)
		for cut in store.cuts:
			animation.track_insert_key(cut_track, float(cut["t"]), str(cut["camera"]))

	_dirty = false
	if animation_player.has_method(&"clear_caches"):
		animation_player.call(&"clear_caches")
	_build_character_motion(animation, root)


func _build_character_motion(animation: Animation, root: Node) -> void:
	_motions.clear()
	if placed_props_root == null:
		return
	for child in placed_props_root.get_children():
		if not child is CharacterBase:
			continue
		var uid := PropUtils.uid_of(child)
		var path := NodePath("%s:position" % root.get_path_to(child))
		var track := animation.find_track(path, Animation.TYPE_VALUE)
		_motions[uid] = CharacterMotion.build(animation, track, store.duration, _action_keys(uid), _face_keys(uid))
		(_motions[uid] as CharacterMotion).poses = _pose_keys(uid)


func _pose_keys(uid: String) -> Array:
	var keys: Array = []
	for key in store.channels.get(KeyframeStore.channel_id(uid, CH_POSE), []):
		keys.append({"t": float(key["t"]), "pose": key["v"].get("pose", {})})
	return keys


## The hand-made pose of [param character] at time [param t] (joint -> degrees).
func pose_at(character: CharacterBase, t: float) -> Dictionary:
	var motion: CharacterMotion = _motions.get(uid_for(character))
	if motion == null:
		motion = CharacterMotion.stationary()
		motion.poses = _pose_keys(uid_for(character))
	return motion.pose_at(t)


## Sets one joint's hand rotation at the playhead (creates/updates a pose key).
func set_pose_joint(character: CharacterBase, joint: String, degrees: Vector3) -> void:
	if character == null:
		return
	if _playing:
		pause()
	var t := snap_time(current_time)
	var before := store.snapshot()
	var pose := pose_at(character, t)
	var stored := {}
	for key in pose:
		var v: Vector3 = pose[key]
		stored[CharacterBase.SCRIPT_JOINTS.get(key, key)] = [v.x, v.y, v.z]
	stored[joint] = [degrees.x, degrees.y, degrees.z]
	store.set_key(uid_for(character), CH_POSE, t, {"pose": stored}, false)
	_commit("Pose %s %s" % [character.name, joint], before, true)


func clear_pose(character: CharacterBase) -> void:
	if character == null:
		return
	var before := store.snapshot()
	store.channels.erase(KeyframeStore.channel_id(uid_for(character), CH_POSE))
	store.changed.emit()
	_commit("Clear pose of %s" % character.name, before)


## Turns [param character] to face [param yaw_degrees] (world, 0 = +Z) at the
## playhead; it keeps facing that way until it next walks somewhere.
func set_facing(character: CharacterBase, yaw_degrees: float) -> void:
	if character == null:
		return
	if _playing:
		pause()
	var before := store.snapshot()
	store.set_key(uid_for(character), CH_FACE, snap_time(current_time), {"yaw": wrapf(yaw_degrees, -180.0, 180.0)}, false)
	_commit("%s turns" % character.name, before)


func _face_keys(uid: String) -> Array:
	var keys: Array = []
	for key in store.channels.get(KeyframeStore.channel_id(uid, CH_FACE), []):
		keys.append({"t": float(key["t"]), "yaw": float(key["v"].get("yaw", 0.0))})
	return keys


func _action_keys(uid: String) -> Array:
	var keys: Array = []
	for key in store.channels.get(KeyframeStore.channel_id(uid, CH_ACTION), []):
		keys.append({"t": float(key["t"]), "action": str(key["v"].get("action", MotionLibrary.AUTO))})
	return keys


## Poses every character (and drifts the clouds) for time [param t].
func _apply_characters(t: float) -> void:
	if environment:
		environment.set_timeline_time(t)
	if placed_props_root == null:
		return
	for child in placed_props_root.get_children():
		if child is CharacterBase:
			var uid := str(child.get_meta(PropUtils.META_UID, ""))
			var motion: CharacterMotion = _motions.get(uid)
			if motion == null:
				motion = CharacterMotion.new()
				motion.actions = _action_keys(uid)
			(child as CharacterBase).evaluate(t, motion)
		elif child is Node3D:
			_sync_prop_lights(child as Node3D)


## Poses one character again at the playhead (used for live previews such as
## dragging a joint, without rebuilding the timeline).
func refresh_character(character: CharacterBase) -> void:
	if character == null or not is_instance_valid(character):
		return
	var uid := uid_for(character)
	var motion: CharacterMotion = _motions.get(uid)
	if motion == null:
		motion = CharacterMotion.new()
		motion.actions = _action_keys(uid)
		motion.poses = _pose_keys(uid)
	character.evaluate(current_time, motion)


## Lights inside an object go out while it's hidden (shrunk to nothing).
func _sync_prop_lights(prop: Node3D) -> void:
	if not prop.has_meta(&"_lights"):
		var found: Array = []
		for light in prop.find_children("*", "Light3D", true, false):
			if not light is DirectionalLight3D:
				found.append(light)
		prop.set_meta(&"_lights", found)
	var lights: Array = prop.get_meta(&"_lights")
	if lights.is_empty():
		return
	if not is_instance_valid(lights[0]) or not prop.is_ancestor_of(lights[0]):
		prop.remove_meta(&"_lights")  # copied from another object: look again
		_sync_prop_lights(prop)
		return
	var shown := prop.scale.x > 0.01
	for light in lights:
		if is_instance_valid(light):
			(light as Light3D).visible = shown


## After edits (e.g. a new character placed), re-pose characters once, without
## re-seeking the animation (which would undo un-keyed edits).
func _queue_character_pose() -> void:
	if not _pose_queued:
		_pose_queued = true
		_pose_characters_deferred.call_deferred()


func _pose_characters_deferred() -> void:
	_pose_queued = false
	if not _playing:
		if _dirty:
			_rebuild_motion_only()
		_apply_characters(current_time)


## Refreshes motion tables (and the compiled animation they sample) without seeking.
func _rebuild_motion_only() -> void:
	_rebuild()


func _resolve(uid: String) -> Node:
	if uid == ENV_UID:
		return environment
	for root in [placed_props_root, cameras_root]:
		if root == null:
			continue
		for child in root.get_children():
			if child.get_meta(PropUtils.META_UID, "") == uid:
				return child
	return null


static func _is_continuous(value: Variant) -> bool:
	return typeof(value) in [TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_QUATERNION, TYPE_COLOR]

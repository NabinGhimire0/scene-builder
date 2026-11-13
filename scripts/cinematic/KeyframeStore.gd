class_name KeyframeStore
extends RefCounted
## The timeline's data: keyframes per object channel, camera cuts, duration and
## interpolation. Pure data; [TimelineController] turns it into an Animation.
##
## channels: "<uid>/<channel>" -> Array of { "t": seconds, "v": { property: value } }
## cuts:     Array of { "t": seconds, "camera": camera uid }
## Both arrays are kept sorted by time.

signal changed

const EPSILON := 1.0 / 240.0

var duration := 10.0
var interpolation := 0
var channels: Dictionary = {}
var cuts: Array = []


static func channel_id(uid: String, channel: String) -> String:
	return "%s/%s" % [uid, channel]


static func split_id(id: String) -> PackedStringArray:
	return id.split("/", true, 1)


# --- Keyframes -------------------------------------------------------------------

## [param glide] keys are reached at an even speed (no easing into them): spins, drifts.
func set_key(uid: String, channel: String, time: float, values: Dictionary, notify: bool = true, glide: bool = false) -> void:
	var id := channel_id(uid, channel)
	var keys: Array = channels.get(id, [])
	var replaced := false
	for key in keys:
		if absf(float(key["t"]) - time) < EPSILON:
			key["v"] = values.duplicate()
			if glide:
				key["g"] = true
			else:
				key.erase("g")
			replaced = true
			break
	if not replaced:
		var entry := {"t": time, "v": values.duplicate()}
		if glide:
			entry["g"] = true
		keys.append(entry)
		keys.sort_custom(_by_time)
	channels[id] = keys
	_notify(notify)


## Removes every channel's key of [param uid] at [param time]. Returns how many.
func remove_keys_at(uid: String, time: float, notify: bool = true) -> int:
	var removed := 0
	for id in channels.keys():
		if split_id(id)[0] != uid:
			continue
		var keys: Array = channels[id]
		for i in range(keys.size() - 1, -1, -1):
			if absf(float(keys[i]["t"]) - time) < EPSILON:
				keys.remove_at(i)
				removed += 1
		if keys.is_empty():
			channels.erase(id)
	_notify(notify and removed > 0)
	return removed


## Moves every channel's key of [param uid] from one time to another.
func move_keys(uid: String, from_time: float, to_time: float, notify: bool = true) -> void:
	for id in channels.keys():
		if split_id(id)[0] != uid:
			continue
		var keys: Array = channels[id]
		var moving: Dictionary = {}
		for key in keys:
			if absf(float(key["t"]) - from_time) < EPSILON:
				moving = key
				break
		if moving.is_empty():
			continue
		for i in range(keys.size() - 1, -1, -1):
			if not is_same(keys[i], moving) and absf(float(keys[i]["t"]) - to_time) < EPSILON:
				keys.remove_at(i)  # the moved key replaces one already there
		moving["t"] = to_time
		keys.sort_custom(_by_time)
	_notify(notify)


func remove_object(uid: String, notify: bool = true) -> void:
	for id in channels.keys():
		if split_id(id)[0] == uid:
			channels.erase(id)
	_notify(notify)


func has_channel(uid: String, channel: String) -> bool:
	return channels.has(channel_id(uid, channel))


func has_keys(uid: String) -> bool:
	for id in channels:
		if split_id(id)[0] == uid:
			return true
	return false


## Distinct key times of [param uid] across its channels, sorted.
func key_times(uid: String) -> PackedFloat32Array:
	var times: Array = []
	for id in channels:
		if split_id(id)[0] != uid:
			continue
		for key in channels[id]:
			var t := float(key["t"])
			var seen := false
			for existing in times:
				if absf(existing - t) < EPSILON:
					seen = true
					break
			if not seen:
				times.append(t)
	times.sort()
	return PackedFloat32Array(times)


func key_count() -> int:
	var n := 0
	for id in channels:
		n += (channels[id] as Array).size()
	return n


# --- Camera cuts -------------------------------------------------------------------

func set_cut(time: float, camera_uid: String, notify: bool = true) -> void:
	for cut in cuts:
		if absf(float(cut["t"]) - time) < EPSILON:
			cut["camera"] = camera_uid
			_notify(notify)
			return
	cuts.append({"t": time, "camera": camera_uid})
	cuts.sort_custom(_by_time)
	_notify(notify)


func remove_cut(time: float, notify: bool = true) -> bool:
	for i in range(cuts.size() - 1, -1, -1):
		if absf(float(cuts[i]["t"]) - time) < EPSILON:
			cuts.remove_at(i)
			_notify(notify)
			return true
	return false


func move_cut(from_time: float, to_time: float, notify: bool = true) -> void:
	var moving: Dictionary = {}
	for cut in cuts:
		if absf(float(cut["t"]) - from_time) < EPSILON:
			moving = cut
	if moving.is_empty():
		return
	for i in range(cuts.size() - 1, -1, -1):
		if not is_same(cuts[i], moving) and absf(float(cuts[i]["t"]) - to_time) < EPSILON:
			cuts.remove_at(i)
	moving["t"] = to_time
	cuts.sort_custom(_by_time)
	_notify(notify)


func cut_times() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for cut in cuts:
		out.append(float(cut["t"]))
	return out


func camera_at(time: float) -> String:
	var uid := ""
	for cut in cuts:
		if float(cut["t"]) <= time + EPSILON:
			uid = str(cut["camera"])
	if uid.is_empty() and not cuts.is_empty():
		uid = str(cuts[0]["camera"])
	return uid


# --- Snapshots (undo) & persistence ------------------------------------------------

func snapshot() -> Dictionary:
	return {
		"duration": duration,
		"interpolation": interpolation,
		"channels": channels.duplicate(true),
		"cuts": cuts.duplicate(true),
	}


func restore(state: Dictionary, notify: bool = true) -> void:
	duration = float(state.get("duration", duration))
	interpolation = int(state.get("interpolation", interpolation))
	channels = (state.get("channels", {}) as Dictionary).duplicate(true)
	cuts = (state.get("cuts", []) as Array).duplicate(true)
	_notify(notify)


func clear(notify: bool = true) -> void:
	duration = 10.0
	interpolation = 0
	channels = {}
	cuts = []
	_notify(notify)


## JSON-friendly copy. Only objects whose uid is in [param valid_uids] are kept.
func to_json(valid_uids: Dictionary) -> Dictionary:
	var out_channels := {}
	for id in channels:
		if not valid_uids.has(split_id(id)[0]):
			continue
		var keys: Array = []
		for key in channels[id]:
			var values := {}
			for property in key["v"]:
				values[property] = encode_value(key["v"][property])
			var saved := {"t": snappedf(float(key["t"]), 0.0001), "v": values}
			if key.get("g", false):
				saved["g"] = 1
			keys.append(saved)
		out_channels[id] = keys
	var out_cuts: Array = []
	for cut in cuts:
		if valid_uids.has(str(cut["camera"])):
			out_cuts.append({"t": snappedf(float(cut["t"]), 0.0001), "camera": str(cut["camera"])})
	return {"duration": duration, "interpolation": interpolation, "channels": out_channels, "cuts": out_cuts}


func load_json(data: Dictionary) -> void:
	duration = clampf(float(data.get("duration", 10.0)), 1.0, 600.0)
	interpolation = clampi(int(data.get("interpolation", 0)), 0, 2)
	channels = {}
	var saved_channels: Variant = data.get("channels", {})
	if saved_channels is Dictionary:
		for id in saved_channels:
			var keys: Array = []
			var saved_keys: Variant = saved_channels[id]
			if not saved_keys is Array:
				continue
			for key in saved_keys:
				if not key is Dictionary or not key.get("v") is Dictionary:
					continue
				var values := {}
				for property in key["v"]:
					values[property] = decode_value(key["v"][property])
				var entry := {"t": float(key.get("t", 0.0)), "v": values}
				if key.get("g", 0):
					entry["g"] = true
				keys.append(entry)
			keys.sort_custom(_by_time)
			if not keys.is_empty():
				channels[str(id)] = keys
	cuts = []
	var saved_cuts: Variant = data.get("cuts", [])
	if saved_cuts is Array:
		for cut in saved_cuts:
			if cut is Dictionary and cut.has("camera"):
				cuts.append({"t": float(cut.get("t", 0.0)), "camera": str(cut["camera"])})
		cuts.sort_custom(_by_time)
	_notify(true)


static func encode_value(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR3:
			return {"v3": [v.x, v.y, v.z]}
		TYPE_QUATERNION:
			return {"q": [v.x, v.y, v.z, v.w]}
		TYPE_COLOR:
			return {"c": [v.r, v.g, v.b, v.a]}
	return v


static func decode_value(v: Variant) -> Variant:
	if v is Dictionary:
		if v.has("v3") and v["v3"] is Array and v["v3"].size() == 3:
			var a: Array = v["v3"]
			return Vector3(float(a[0]), float(a[1]), float(a[2]))
		if v.has("q") and v["q"] is Array and v["q"].size() == 4:
			var a: Array = v["q"]
			return Quaternion(float(a[0]), float(a[1]), float(a[2]), float(a[3])).normalized()
		if v.has("c") and v["c"] is Array and v["c"].size() == 4:
			var a: Array = v["c"]
			return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return v


static func _by_time(a: Dictionary, b: Dictionary) -> bool:
	return float(a["t"]) < float(b["t"])


func _notify(notify: bool) -> void:
	if notify:
		changed.emit()

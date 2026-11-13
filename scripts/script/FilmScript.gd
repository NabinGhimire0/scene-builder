class_name FilmScript
extends RefCounted
## Reads a film script (readable screenplay text, or JSON) into a plain model:
##
##   { "header": { "title": "…", "location": "…", "time": "…", … },
##     "cast":   [ { "name": "Mira", "spec": "woman casual, top red", "line": 7 } ],
##     "set":    [ { "text": "bench1 = bench near campfire", "line": 12 } ],
##     "scenes": [ { "name": "Arrival", "lines": [ { "text": "Mira walks to bench1", "line": 15 } ] } ],
##     "errors": [ "…" ] }
##
## The lines themselves are interpreted by [ScriptDirector].

const HEADER_KEYS: PackedStringArray = ["title", "location", "time", "weather", "music", "length",
	"sky", "light", "camera", "subtitles", "author", "note", "fps", "aspect", "requires", "voices", "style", "look", "dialogue", "speech"]
const CAST_HEADERS: PackedStringArray = ["cast", "characters", "actors"]
const SET_HEADERS: PackedStringArray = ["set", "props", "objects", "set dressing"]


static func parse(text: String) -> Dictionary:
	var stripped := text.strip_edges()
	if stripped.begins_with("{"):
		return parse_json(stripped)
	var model := {"header": {}, "cast": [], "set": [], "scenes": [], "errors": []}
	var section := "header"
	var scene: Dictionary = {}
	var number := 0
	for raw in text.split("\n"):
		number += 1
		var line := _clean(raw)
		if line.is_empty():
			continue
		var upper := line.to_upper()
		var head := upper.trim_suffix(":").strip_edges()
		if CAST_HEADERS.has(head.to_lower()):
			section = "cast"
			continue
		if SET_HEADERS.has(head.to_lower()):
			section = "set"
			continue
		if upper.begins_with("SCENE") or upper.begins_with("INT.") or upper.begins_with("EXT."):
			section = "scene"
			scene = {"name": _scene_name(line, (model["scenes"] as Array).size() + 1), "lines": []}
			(model["scenes"] as Array).append(scene)
			continue
		match section:
			"header":
				var pair := _key_value(line)
				if not pair.is_empty() and HEADER_KEYS.has(str(pair[0]).to_lower()):
					(model["header"] as Dictionary)[str(pair[0]).to_lower()] = str(pair[1])
				else:
					# No SCENE heading yet: start an implicit first scene.
					section = "scene"
					scene = {"name": "Scene 1", "lines": [{"text": line, "line": number}]}
					(model["scenes"] as Array).append(scene)
			"cast":
				var pair := _key_value(line, true)
				if pair.is_empty():
					(model["errors"] as Array).append("Line %d: a cast line looks like \"Mira = woman casual\"." % number)
				else:
					(model["cast"] as Array).append({"name": str(pair[0]), "spec": str(pair[1]), "line": number})
			"set":
				(model["set"] as Array).append({"text": line, "line": number})
			"scene":
				(scene["lines"] as Array).append({"text": line, "line": number})
	if (model["scenes"] as Array).is_empty():
		(model["errors"] as Array).append("The script has no scenes (start one with a line like \"SCENE 1: Arrival\").")
	return model


## JSON form: the same content as the text form, e.g.
## { "title": "…", "location": "Forest Lake", "cast": { "Mira": "woman casual" },
##   "set": ["bench1 = bench near campfire"], "scenes": [ { "name": "…", "lines": ["…"] } ] }
static func parse_json(text: String) -> Dictionary:
	var model := {"header": {}, "cast": [], "set": [], "scenes": [], "errors": []}
	var json := JSON.new()
	if json.parse(text) != OK:
		(model["errors"] as Array).append("JSON error on line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return model
	if not json.data is Dictionary:
		(model["errors"] as Array).append("The JSON script must be an object { … }.")
		return model
	var data: Dictionary = json.data
	for key in data:
		var name := str(key).to_lower()
		if HEADER_KEYS.has(name):
			(model["header"] as Dictionary)[name] = str(data[key])
	var cast: Variant = data.get("cast", data.get("characters", {}))
	if cast is Dictionary:
		for name in cast:
			(model["cast"] as Array).append({"name": str(name), "spec": str(cast[name]), "line": 0})
	elif cast is Array:
		for entry in cast:
			if entry is Dictionary:
				var spec := str(entry.get("model", entry.get("spec", "")))
				(model["cast"] as Array).append({"name": str(entry.get("name", "")), "spec": spec, "line": 0})
			else:
				var pair := _key_value(str(entry), true)
				if not pair.is_empty():
					(model["cast"] as Array).append({"name": str(pair[0]), "spec": str(pair[1]), "line": 0})
	var props: Variant = data.get("set", data.get("props", []))
	if props is Array:
		for entry in props:
			(model["set"] as Array).append({"text": str(entry), "line": 0})
	var scenes: Variant = data.get("scenes", [])
	if scenes is Array:
		var index := 0
		for entry in scenes:
			index += 1
			if entry is Dictionary:
				var lines: Array = []
				var source: Variant = entry.get("lines", [])
				if source is Array:
					for item in source:
						var line := _clean(str(item))
						if not line.is_empty():
							lines.append({"text": line, "line": 0})
				(model["scenes"] as Array).append({"name": str(entry.get("name", "Scene %d" % index)), "lines": lines})
	if (model["scenes"] as Array).is_empty():
		(model["errors"] as Array).append("The JSON script has no \"scenes\".")
	return model


## Strips comments, bullets and numbering.
static func _clean(raw: String) -> String:
	var line := raw.strip_edges()
	if line.begins_with("#") or line.begins_with("//") or line.begins_with("```"):
		return ""
	for bullet in ["- ", "* ", "• "]:
		if line.begins_with(bullet):
			line = line.substr(bullet.length()).strip_edges()
	var regex := RegEx.create_from_string("^\\d+[.)]\\s+")
	var found := regex.search(line)
	if found and not line.to_upper().begins_with("SCENE"):
		line = line.substr(found.get_end()).strip_edges()
	return line


## "Key: value" or (with [param allow_equals]) "Key = value" -> [key, value].
static func _key_value(line: String, allow_equals: bool = false) -> Array:
	var cut := -1
	if allow_equals:
		cut = line.find("=")
	if cut < 0:
		cut = line.find(":")
	if cut <= 0:
		return []
	var key := line.substr(0, cut).strip_edges()
	var value := line.substr(cut + 1).strip_edges()
	if key.is_empty() or value.is_empty():
		return []
	return [key, value]


static func _scene_name(line: String, number: int) -> String:
	var rest := line.substr(5).strip_edges() if line.to_upper().begins_with("SCENE") else line
	rest = rest.lstrip("0123456789").strip_edges().lstrip(":-–—.").strip_edges()
	return rest if not rest.is_empty() else "Scene %d" % number

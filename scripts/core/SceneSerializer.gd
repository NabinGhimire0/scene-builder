class_name SceneSerializer
extends RefCounted
## Converts the built scene to/from human-readable JSON.
##
## File layout (version 1):
## {
##   "format": "scene-builder", "version": 1, "saved_at": "...",
##   "layout": { "props": [ { "name", "prop_id", "scene_path",
##                            "position": [x,y,z], "rotation_degrees": [x,y,z], "scale": [x,y,z] } ] },
##   "editor_camera": { ... }
## }
## Version 2 adds "uid" per prop plus (written by SceneDocument): "cameras",
## "director", "environment", "timeline" (keyframes + camera cuts) and "render".
## Version 1 files still open.

const FORMAT := "scene-builder"
const VERSION := 2
const FILE_EXTENSION := "json"


static func serialize(props_root: Node3D, camera_state: Dictionary = {}) -> Dictionary:
	var props: Array = []
	for child in props_root.get_children():
		var node := child as Node3D
		if node == null or not PropUtils.is_prop(node):
			continue
		props.append({
			"name": str(node.name),
			"uid": PropUtils.uid_of(node),
			"prop_id": str(node.get_meta(PropUtils.META_PROP_ID, "")),
			"scene_path": str(node.get_meta(PropUtils.META_SCENE_PATH)),
			"position": _vec_to_array(node.position),
			"rotation_degrees": _vec_to_array(node.rotation_degrees),
			"scale": _vec_to_array(node.scale),
		})
		var entry: Dictionary = props[props.size() - 1]
		if node.has_method(&"get_custom_state"):
			entry["state"] = node.call(&"get_custom_state")
		var surface := PropUtils.surface_of(node)
		if not surface.is_empty():
			entry["surface"] = surface
		var online := OnlineLibrary.entry_for_path(entry["scene_path"])
		if not online.is_empty():
			entry["source"] = {"provider": online.get("provider", ""), "id": online.get("id", "")}
	var data := {
		"format": FORMAT,
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"layout": {"props": props},
	}
	if not camera_state.is_empty():
		data["editor_camera"] = camera_state
	return data


static func write_json(path: String, data: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t", false))
	file.close()
	return OK


## Returns the parsed document, or { "error": "message" }.
static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "File not found: %s" % path}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {"error": "File is empty or unreadable: %s" % path.get_file()}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"error": "Invalid JSON in %s (line %d): %s" % [
			path.get_file(), json.get_error_line(), json.get_error_message()]}
	var data: Variant = json.data
	if not data is Dictionary or data.get("format", "") != FORMAT:
		return {"error": "%s is not a Scene Builder file." % path.get_file()}
	if int(data.get("version", 0)) > VERSION:
		return {"error": "%s was saved by a newer version of Scene Builder." % path.get_file()}
	return data


## Instantiates every prop in [param data] under [param props_root].
## Returns { "placed": int, "skipped": PackedStringArray,
##           "missing_sources": Array of { provider, id } (re-downloadable) }.
static func instantiate_props(data: Dictionary, props_root: Node3D) -> Dictionary:
	var placed := 0
	var skipped := PackedStringArray()
	var missing_sources: Array = []
	var layout: Variant = data.get("layout", {})
	var entries: Variant = layout.get("props", []) if layout is Dictionary else []
	if not entries is Array:
		entries = []
	for entry in entries:
		if not entry is Dictionary:
			continue
		var path := str(entry.get("scene_path", ""))
		if not PropCatalog.is_library_path(path):
			skipped.append(path if not path.is_empty() else "(missing path)")
			continue
		var node := PropUtils.create_prop(path, str(entry.get("prop_id", "")))
		if node == null:
			skipped.append(path)
			var source: Variant = entry.get("source")
			if source is Dictionary and source.has("provider") and source.has("id"):
				missing_sources.append({"provider": str(source["provider"]), "id": str(source["id"])})
			continue
		var state: Variant = entry.get("state")
		if state is Dictionary and node.has_method(&"set_custom_state"):
			node.call(&"set_custom_state", state)
		var surface: Variant = entry.get("surface")
		if surface is Dictionary and not surface.is_empty():
			var texture := str(surface.get("texture", ""))
			if PropCatalog.is_library_path(texture):
				var surface_id := str(surface.get("id", ""))
				if not FileAccess.file_exists(texture) and not surface_id.is_empty():
					var local := OnlineLibrary.downloaded_path("polyhaven", surface_id, "texture")
					if local.is_empty():
						missing_sources.append({"provider": "polyhaven", "id": surface_id, "kind": "texture"})
					else:
						surface = surface.duplicate()
						surface["texture"] = local
						PropUtils.apply_surface(node, surface)
				else:
					PropUtils.apply_surface(node, surface)
		var saved_uid := str(entry.get("uid", ""))
		if not saved_uid.is_empty():
			node.set_meta(PropUtils.META_UID, saved_uid)
		var saved_name := str(entry.get("name", "")).validate_node_name()
		if not saved_name.is_empty():
			node.name = saved_name
		node.position = _array_to_vec(entry.get("position"), Vector3.ZERO)
		node.rotation_degrees = _array_to_vec(entry.get("rotation_degrees"), Vector3.ZERO)
		node.scale = _array_to_vec(entry.get("scale"), Vector3.ONE)
		props_root.add_child(node, true)
		placed += 1
	return {"placed": placed, "skipped": skipped, "missing_sources": missing_sources}


static func _vec_to_array(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]


static func _array_to_vec(value: Variant, fallback: Vector3) -> Vector3:
	if not value is Array or value.size() < 3:
		return fallback
	var out := Vector3(float(value[0]), float(value[1]), float(value[2]))
	if not out.is_finite():
		return fallback
	return out

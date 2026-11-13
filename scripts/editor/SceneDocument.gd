class_name SceneDocument
extends Node
## The open project file: current path, saved/unsaved state, save / open / new,
## and clearing the scene. Dialogs live in the UI; this node does the work.
##
## A saved file holds the whole film: the set (props), cameras, lighting,
## timeline keyframes and camera cuts, and export settings.

@export var placed_props_root: Node3D
@export var cameras_root: Node3D
@export var history: EditorHistory
@export var selection: SelectionManager
@export var editor_camera: EditorCamera
@export var director: CinematicDirector
@export var timeline: TimelineController
@export var environment: EnvironmentController
@export var exporter: ExportManager
@export var online: OnlineLibrary
@export var terrain: Terrain
@export var vegetation: Vegetation
@export var titles: TitleTrack
@export var audio: AudioTrack

var current_path := ""
var _redownloading := false


func display_name() -> String:
	return current_path.get_file() if not current_path.is_empty() else "Untitled"


func is_dirty() -> bool:
	return history != null and history.is_dirty()


func object_count() -> int:
	return placed_props_root.get_child_count() + director.cameras().size()


func save_to(path: String) -> bool:
	if path.get_extension().to_lower() != SceneSerializer.FILE_EXTENSION:
		path += "." + SceneSerializer.FILE_EXTENSION
	var camera_state: Dictionary = editor_camera.get_state() if editor_camera else {}
	var data := SceneSerializer.serialize(placed_props_root, camera_state)
	var cameras: Array = []
	for cam in director.cameras():
		cameras.append(cam.to_dict())
	data["cameras"] = cameras
	data["director"] = director.to_dict()
	data["environment"] = environment.to_dict()
	data["timeline"] = timeline.to_dict()
	data["render"] = exporter.to_dict()
	if terrain:
		data["terrain"] = terrain.to_dict()
	if vegetation:
		data["vegetation"] = vegetation.to_dict()
	if titles:
		data["titles"] = titles.to_list()
	if audio:
		data["audio"] = audio.to_list()
	var err := SceneSerializer.write_json(path, data)
	if err != OK:
		EventBus.error("Couldn't save %s: %s." % [path.get_file(), error_string(err)])
		return false
	current_path = path
	history.mark_saved()
	var count: int = (data["layout"]["props"] as Array).size()
	EventBus.info("Saved %s (%d object%s, %d camera%s, %d keyframes)." % [
		path.get_file(), count, "" if count == 1 else "s", cameras.size(), "" if cameras.size() == 1 else "s",
		timeline.store.key_count()])
	return true


func open_from(path: String) -> bool:
	var data := SceneSerializer.read_json(path)
	if data.has("error"):
		EventBus.error(str(data["error"]))
		return false
	_reset_scene()
	var report := SceneSerializer.instantiate_props(data, placed_props_root)
	var saved_cameras: Variant = data.get("cameras", [])
	var camera_count := director.restore_cameras(saved_cameras if saved_cameras is Array else [])
	director.load_dict(_dict(data.get("director")))
	environment.load_dict(_dict(data.get("environment")))
	exporter.load_dict(_dict(data.get("render")))
	timeline.load_dict(_dict(data.get("timeline")))
	if terrain:
		terrain.load_dict(_dict(data.get("terrain")))
	if vegetation:
		vegetation.load_dict(_dict(data.get("vegetation")))
	if titles:
		titles.load_list(data.get("titles", []))
	if audio:
		audio.load_list(data.get("audio", []))
	var camera_state := _dict(data.get("editor_camera"))
	if editor_camera and not camera_state.is_empty():
		editor_camera.set_state(camera_state)
	current_path = path
	history.clear_history()

	var skipped: PackedStringArray = report["skipped"]
	var missing: Array = report.get("missing_sources", [])
	for asset in environment.missing_assets():
		missing.append({"provider": "polyhaven", "id": asset["id"], "kind": asset["kind"]})
	if not missing.is_empty() and online != null and not _redownloading:
		_redownload_and_reopen(path, missing)
		return true
	if skipped.is_empty():
		EventBus.info("Opened %s (%d objects, %d cameras)." % [path.get_file(), report["placed"], camera_count])
	else:
		EventBus.error("Opened %s: %d objects, %d skipped (missing or invalid assets: %s)." % [
			path.get_file(), report["placed"], skipped.size(), ", ".join(_short_names(skipped))])
	return true


## Downloads online models the project uses but this computer doesn't have yet,
## then opens the project again.
func _redownload_and_reopen(path: String, sources: Array) -> void:
	_redownloading = true
	EventBus.info("This project uses %d online model%s that aren't on this computer yet — downloading…" % [
		sources.size(), "" if sources.size() == 1 else "s"])
	var failed := 0
	for source in sources:
		var got: String = await online.ensure_downloaded(str(source["provider"]), str(source["id"]), str(source.get("kind", "model")))
		if got.is_empty():
			failed += 1
	open_from(path)
	_redownloading = false
	if failed > 0:
		EventBus.error("%d online model%s couldn't be downloaded (offline, or a Poly Pizza key is needed)." % [
			failed, "" if failed == 1 else "s"])


func new_scene() -> void:
	_reset_scene()
	current_path = ""
	history.clear_history()
	EventBus.info("New scene.")


## Removes all objects, cameras and keyframes as one undoable step.
func clear_all_undoable() -> void:
	var nodes: Array[Node3D] = []
	for root in [placed_props_root, cameras_root]:
		for child in root.get_children():
			if child is Node3D:
				nodes.append(child)
	var before := timeline.store.snapshot()
	var after := timeline.clear_keys_snapshot()
	history.remove_props(nodes, "Clear Scene", timeline.restore_store.bind(after), timeline.restore_store.bind(before))
	EventBus.info("Scene cleared. Ctrl+Z brings everything back.")


func _reset_scene() -> void:
	if selection:
		selection.clear_selection()
	timeline.reset()
	director.reset()
	environment.reset_defaults()
	if terrain:
		terrain.clear()
	if vegetation:
		vegetation.clear()
	if titles:
		titles.clear()
	if audio:
		audio.clear()
	for root in [placed_props_root, cameras_root]:
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _short_names(paths: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for i in mini(paths.size(), 3):
		out.append(paths[i].get_file())
	if paths.size() > 3:
		out.append("…")
	return out

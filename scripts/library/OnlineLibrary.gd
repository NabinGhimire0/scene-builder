class_name OnlineLibrary
extends Node
## Online asset stores, built into the app (models, plus Poly Haven photo skies
## (HDRIs) and PBR textures):
##  • Poly Haven  – free CC0 models, no account or key needed.
##  • Poly Pizza  – 10,000+ free low-poly models (CC0 / CC-BY); needs a free API key.
##  • BlendKit    – the asset library of the Blender add-on (formerly BlenderKit).
##                  Free models work without an account; an API key unlocks the
##                  user's plan. Models with a glTF version load directly; .blend-only
##                  models are converted to .glb by the user's own Blender, in the
##                  background (tools/blender/blend_to_glb.py).
##
## Search results, thumbnails and downloads use HTTPRequest. Downloaded models are
## stored under user://library/online/ with an index (source, author, licence),
## so they work offline, appear in the Asset Library, are credited on export,
## and can be re-downloaded automatically when a shared project needs them.
## Also handles importing the user's own .glb models and rigged characters.

signal search_completed(results: Array, has_more: bool, error: String)
signal download_progress(key: String, fraction: float)
signal download_completed(key: String, scene_path: String, error: String)
signal library_changed

enum Provider { POLY_HAVEN, POLY_PIZZA, BLENDKIT }

const PROVIDER_NAMES: PackedStringArray = ["Poly Haven", "Poly Pizza", "BlendKit"]
const PROVIDER_IDS: PackedStringArray = ["polyhaven", "polypizza", "blendkit"]
const USER_AGENT := "SceneBuilder/1.19 (Godot Engine desktop app)"
const INDEX_PATH := "user://library/index.json"
const SETTINGS_PATH := "user://settings.cfg"
const PAGE_SIZE := 24
const MAX_PARALLEL_THUMBNAILS := 4
const POLYHAVEN_API := "https://api.polyhaven.com"
const POLYHAVEN_THUMB := "https://cdn.polyhaven.com/asset_img/thumbs/%s.png?width=256&height=256"
const POLYPIZZA_API := "https://api.poly.pizza/v1"
const POLYPIZZA_KEY_URL := "https://poly.pizza/settings/api"
const BLENDKIT_SERVER := "https://www.blendkit.com"
const BLENDKIT_CONVERTER := "res://tools/blender/blend_to_glb.py"
## File types BlendKit offers, best first: ready-made glTF needs no Blender.
const BLENDKIT_GLTF_TYPES: PackedStringArray = ["gltf_godot", "gltf"]
const BLENDKIT_BLEND_TYPES: PackedStringArray = ["resolution_1K", "resolution_0_5K", "resolution_2K", "blend"]

static var _index: Dictionary = {}
static var _index_loaded := false

var _polyhaven_catalogs: Dictionary = {}   # "models"/"hdris"/"textures" -> catalog
var _polypizza_cursor := ""
var _blendkit_next := ""
var _scene_uuid := ""
var _search_serial := 0
var _downloading: Dictionary = {}
var _thumb_textures: Dictionary = {}   # url -> Texture2D
var _thumb_images: Dictionary = {}     # url -> Image
var _thumb_queue: Array = []
var _thumb_active := 0


# --- Settings ----------------------------------------------------------------------

static func get_setting(key: String, default_value: Variant = "") -> Variant:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return default_value
	return config.get_value("online", key, default_value)


static func set_setting(key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("online", key, value)
	config.save(SETTINGS_PATH)


static func blendkit_server() -> String:
	var custom := OS.get_environment("SCENEBUILDER_BLENDKIT_SERVER")
	if custom.is_empty():
		custom = str(get_setting("blendkit_server", ""))
	return (custom if not custom.is_empty() else BLENDKIT_SERVER).trim_suffix("/")


static func blendkit_key() -> String:
	return str(get_setting("blendkit_key", "")).strip_edges()


## The Blender executable: the saved path (shared with "Render in Blender"),
## otherwise the usual install places. "" if none was found.
static func blender_path() -> String:
	var saved := str(get_setting("blender_path", ""))
	if saved.is_empty():
		var config := ConfigFile.new()
		config.load(SETTINGS_PATH)
		saved = str(config.get_value("avatar", "blender_path", ""))
	if not saved.is_empty() and FileAccess.file_exists(saved):
		return saved
	return find_blender()


static func find_blender() -> String:
	var candidates := PackedStringArray()
	match OS.get_name():
		"Windows":
			for root in [OS.get_environment("ProgramFiles"), OS.get_environment("ProgramFiles(x86)"), "C:/Program Files", OS.get_environment("LOCALAPPDATA") + "/Programs"]:
				if str(root).is_empty():
					continue
				var foundation := str(root).replace("\\", "/").path_join("Blender Foundation")
				if DirAccess.dir_exists_absolute(foundation):
					var versions := Array(DirAccess.get_directories_at(foundation))
					versions.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) > 0)
					for version in versions:
						candidates.append(foundation.path_join(version).path_join("blender.exe"))
			candidates.append("C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe")
		"macOS":
			candidates.append("/Applications/Blender.app/Contents/MacOS/Blender")
			candidates.append(OS.get_environment("HOME") + "/Applications/Blender.app/Contents/MacOS/Blender")
		_:
			candidates.append_array(["/usr/bin/blender", "/usr/local/bin/blender", "/snap/bin/blender",
				OS.get_environment("HOME") + "/blender/blender", "/opt/blender/blender"])
	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


static func has_polypizza_key() -> bool:
	return not str(get_setting("polypizza_key", "")).strip_edges().is_empty()


# --- Downloaded-asset index ----------------------------------------------------------

static func entries() -> Dictionary:
	if not _index_loaded:
		_index_loaded = true
		_index = {}
		if FileAccess.file_exists(INDEX_PATH):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
			if data is Dictionary:
				_index = data
	return _index


## Index key. Models keep the short form; skies and textures include their kind.
static func key_for(provider: String, id: String, kind: String = "model") -> String:
	return "%s:%s" % [provider, id] if kind == "model" else "%s:%s:%s" % [provider, kind, id]


static func entry_for_path(scene_path: String) -> Dictionary:
	for key in entries():
		var entry: Dictionary = _index[key]
		if str(entry.get("file", "")) == scene_path:
			return entry
	return {}


static func downloaded_path(provider: String, id: String, kind: String = "model") -> String:
	var entry: Dictionary = entries().get(key_for(provider, id, kind), {})
	var path := str(entry.get("file", ""))
	return path if not path.is_empty() and FileAccess.file_exists(path) else ""


static func credit_line(entry: Dictionary) -> String:
	var line := "\"%s\"" % entry.get("title", entry.get("id", "?"))
	var author := str(entry.get("author", ""))
	if not author.is_empty():
		line += " by %s" % author
	line += " — %s" % entry.get("license", "unknown licence")
	var source := str(entry.get("source_url", ""))
	if not source.is_empty():
		line += " — %s" % source
	return line


## Credit lines for the downloaded models among [param scene_paths].
static func credits_for_paths(scene_paths: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	var seen := {}
	for path in scene_paths:
		var entry := entry_for_path(str(path))
		if entry.is_empty() or seen.has(entry.get("file")):
			continue
		seen[entry.get("file")] = true
		lines.append(credit_line(entry))
	return lines


static func _save_index() -> void:
	DirAccess.make_dir_recursive_absolute(RuntimeModelLoader.LIBRARY_DIR)
	var file := FileAccess.open(INDEX_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_index, "\t"))


# --- Search --------------------------------------------------------------------------

## Searches [param provider]; [param page] 0 starts a new search, >0 loads more.
## Emits [signal search_completed].
func search(provider: int, query: String, page: int = 0) -> void:
	_search_serial += 1
	var serial := _search_serial
	var response: Dictionary
	if provider == Provider.POLY_PIZZA:
		response = await _search_polypizza(query, page)
	elif provider == Provider.BLENDKIT:
		response = await _search_blendkit(query, page)
	else:
		response = await _search_polyhaven(query, page)
	if serial != _search_serial:
		return  # a newer search replaced this one
	search_completed.emit(response.get("results", []), bool(response.get("has_more", false)), str(response.get("error", "")))


func _search_polyhaven(query: String, page: int) -> Dictionary:
	return await query_polyhaven("models", query, page)


## Searches Poly Haven [param catalog_type] ("models", "hdris" or "textures").
## Awaitable; returns { "results", "has_more", "error" }.
func query_polyhaven(catalog_type: String, query: String, page: int = 0) -> Dictionary:
	var kind := {"models": "model", "hdris": "hdri", "textures": "texture"}.get(catalog_type, "model") as String
	if not _polyhaven_catalogs.has(catalog_type):
		var reply: Dictionary = await _http_get(POLYHAVEN_API + "/assets?type=" + catalog_type)
		if not reply["ok"]:
			return {"error": "Couldn't reach Poly Haven: %s" % reply["error"]}
		var data: Variant = JSON.parse_string((reply["body"] as PackedByteArray).get_string_from_utf8())
		if not data is Dictionary:
			return {"error": "Poly Haven sent an unexpected reply."}
		_polyhaven_catalogs[catalog_type] = data
	var catalog: Dictionary = _polyhaven_catalogs[catalog_type]
	var words := query.strip_edges().to_lower().split(" ", false)
	var matches: Array = []
	for id in catalog:
		var asset: Variant = catalog[id]
		if not asset is Dictionary:
			continue
		var haystack := "%s %s %s %s" % [
			asset.get("name", ""), " ".join(PackedStringArray(asset.get("tags", []))),
			" ".join(PackedStringArray(asset.get("categories", []))), asset.get("category", "")]
		haystack = haystack.to_lower()
		var ok := true
		for word in words:
			if not haystack.contains(word):
				ok = false
				break
		if ok:
			matches.append(_polyhaven_result(str(id), asset, kind))
	matches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["popularity"]) > int(b["popularity"]))
	var start := page * PAGE_SIZE
	var slice := matches.slice(start, start + PAGE_SIZE)
	return {"results": slice, "has_more": matches.size() > start + PAGE_SIZE}


func _polyhaven_result(id: String, asset: Dictionary, kind: String = "model") -> Dictionary:
	var authors: Variant = asset.get("authors", {})
	var thumb := str(asset.get("thumbnail_url", ""))
	return {
		"provider": "polyhaven",
		"kind": kind,
		"id": id,
		"title": str(asset.get("name", id)),
		"author": ", ".join(PackedStringArray((authors as Dictionary).keys())) if authors is Dictionary else "",
		"author_url": "",
		"license": "CC0",
		"thumbnail": thumb if not thumb.is_empty() else POLYHAVEN_THUMB % id,
		"source_url": "https://polyhaven.com/a/%s" % id,
		"category": str(asset.get("category", "")),
		"popularity": int(asset.get("download_count", 0)),
	}


func _search_polypizza(query: String, page: int) -> Dictionary:
	var api_key := str(get_setting("polypizza_key", "")).strip_edges()
	if api_key.is_empty():
		return {"error": "Poly Pizza needs a free API key. Create an account at poly.pizza, copy your key, and paste it above."}
	if page == 0:
		_polypizza_cursor = ""
	var q := query.strip_edges()
	var url := POLYPIZZA_API + ("/search/" + q.uri_encode() if not q.is_empty() else "/popular")
	url += "?limit=%d" % PAGE_SIZE
	if page > 0 and not _polypizza_cursor.is_empty():
		url += "&cursor=" + _polypizza_cursor.uri_encode()
	var reply: Dictionary = await _http_get(url, PackedStringArray(["X-Auth-Token: " + api_key]))
	if not reply["ok"]:
		if int(reply.get("code", 0)) == 401:
			return {"error": "Poly Pizza didn't accept the API key. Check it at poly.pizza/settings/api."}
		if int(reply.get("code", 0)) == 429:
			return {"error": "Poly Pizza says too many requests; wait a moment and try again."}
		if int(reply.get("code", 0)) == 404:
			# Poly Pizza answers 404 when a search finds nothing, and its
			# "popular" list isn't always available: show a default search instead.
			if q.is_empty():
				return await _search_polypizza("house", page)
			return {"results": [], "has_more": false}
		if int(reply.get("code", 0)) == 403:
			return {"error": "Poly Pizza refused the request (403). Check that your API key is active at poly.pizza/settings/api."}
		return {"error": "Couldn't reach Poly Pizza: %s" % reply["error"]}
	var data: Variant = JSON.parse_string((reply["body"] as PackedByteArray).get_string_from_utf8())
	if not data is Dictionary:
		return {"error": "Poly Pizza sent an unexpected reply."}
	var cursor: Variant = data.get("cursor")
	_polypizza_cursor = str(cursor) if cursor != null else ""
	var results: Array = []
	var items: Variant = data.get("results", [])
	if items is Array:
		for item in items:
			if item is Dictionary:
				results.append(_polypizza_result(item))
	return {"results": results, "has_more": not _polypizza_cursor.is_empty()}


func _polypizza_result(item: Dictionary) -> Dictionary:
	var creator: Variant = item.get("Creator", {})
	var tags: Variant = item.get("Tags", [])
	var id := str(item.get("ID", ""))
	return {
		"provider": "polypizza",
		"id": id,
		"title": str(item.get("Title", id)),
		"author": str(creator.get("Username", "")) if creator is Dictionary else "",
		"author_url": str(creator.get("PURL", "")) if creator is Dictionary else "",
		"license": str(item.get("Licence", item.get("License", "CC-BY 4.0"))),
		"thumbnail": str(item.get("Thumbnail", "")),
		"download": str(item.get("Download", "")),
		"source_url": "https://poly.pizza/m/%s" % id,
		"category": str(tags[0]) if tags is Array and not tags.is_empty() else "",
		"popularity": 0,
	}


# --- Thumbnails ------------------------------------------------------------------------

func request_thumbnail(url: String, callback: Callable) -> void:
	if url.is_empty():
		return
	if _thumb_textures.has(url):
		callback.call(_thumb_textures[url])
		return
	_thumb_queue.append([url, callback])
	_pump_thumbnails()


func _pump_thumbnails() -> void:
	while _thumb_active < MAX_PARALLEL_THUMBNAILS and not _thumb_queue.is_empty():
		var job: Array = _thumb_queue.pop_front()
		var callback: Callable = job[1]
		if not callback.is_valid():
			continue
		_thumb_active += 1
		_fetch_thumbnail(job[0], callback)


func _fetch_thumbnail(url: String, callback: Callable) -> void:
	var reply: Dictionary = await _http_get(url)
	_thumb_active -= 1
	if reply["ok"]:
		var image := image_from_bytes(reply["body"])
		if image:
			image.resize(160, int(160.0 * image.get_height() / maxf(image.get_width(), 1.0)), Image.INTERPOLATE_LANCZOS)
			var texture := ImageTexture.create_from_image(image)
			_thumb_images[url] = image
			_thumb_textures[url] = texture
			if callback.is_valid():
				callback.call(texture)
	_pump_thumbnails()


static func image_from_bytes(bytes: PackedByteArray) -> Image:
	if bytes.size() < 12:
		return null
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes[1] == 0x50:
		err = image.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = image.load_jpg_from_buffer(bytes)
	elif bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = image.load_webp_from_buffer(bytes)
	return image if err == OK and not image.is_empty() else null


# --- Downloads ------------------------------------------------------------------------

func is_downloading(provider: String, id: String, kind: String = "model") -> bool:
	return _downloading.has(key_for(provider, id, kind))


static func result_key(result: Dictionary) -> String:
	return key_for(str(result.get("provider")), str(result.get("id")), str(result.get("kind", "model")))


## Downloads a search result; emits [signal download_completed].
func download(result: Dictionary) -> void:
	var outcome: Dictionary = await _download(result)
	download_completed.emit(result_key(result), outcome["path"], outcome["error"])


## Awaitable download: returns { "path", "error" } (also emits the signals).
func download_asset(result: Dictionary) -> Dictionary:
	var outcome: Dictionary = await _download(result)
	download_completed.emit(result_key(result), outcome["path"], outcome["error"])
	return outcome


## Makes sure the asset is on disk (downloading it if needed). Returns its path or "".
func ensure_downloaded(provider: String, id: String, kind: String = "model") -> String:
	var existing := downloaded_path(provider, id, kind)
	if not existing.is_empty():
		return existing
	var result := {"provider": provider, "kind": kind, "id": id, "title": id, "license": "CC0" if provider == "polyhaven" else ""}
	if provider == "polyhaven":
		var info: Dictionary = await _http_get(POLYHAVEN_API + "/info/" + id.uri_encode())
		if info["ok"]:
			var data: Variant = JSON.parse_string((info["body"] as PackedByteArray).get_string_from_utf8())
			if data is Dictionary:
				result = _polyhaven_result(id, data, kind)
	elif provider == "polypizza":
		var model: Dictionary = await _polypizza_model(id)
		if model.is_empty():
			return ""
		result = model
	elif provider == "blendkit":
		var asset: Dictionary = await _blendkit_asset(id)
		if asset.is_empty():
			return ""
		result = asset
	var outcome: Dictionary = await _download(result)
	return outcome["path"]


func _polypizza_model(id: String) -> Dictionary:
	var api_key := str(get_setting("polypizza_key", "")).strip_edges()
	if api_key.is_empty():
		return {}
	var reply: Dictionary = await _http_get(POLYPIZZA_API + "/model/" + id.uri_encode(), PackedStringArray(["X-Auth-Token: " + api_key]))
	if not reply["ok"]:
		return {}
	var data: Variant = JSON.parse_string((reply["body"] as PackedByteArray).get_string_from_utf8())
	return _polypizza_result(data) if data is Dictionary else {}


func _download(result: Dictionary) -> Dictionary:
	var provider := str(result.get("provider", ""))
	var id := str(result.get("id", ""))
	var kind := str(result.get("kind", "model"))
	var key := key_for(provider, id, kind)
	var existing := downloaded_path(provider, id, kind)
	if not existing.is_empty():
		return {"path": existing, "error": ""}
	if id.is_empty() or id.contains("/") or id.contains(".."):
		return {"path": "", "error": "Invalid asset id."}
	if _downloading.has(key):
		while _downloading.has(key):
			await get_tree().process_frame
		var path_after := downloaded_path(provider, id, kind)
		return {"path": path_after, "error": "" if not path_after.is_empty() else "Download failed."}
	_downloading[key] = true
	download_progress.emit(key, 0.0)
	var outcome: Dictionary
	if provider == "polyhaven" and kind == "hdri":
		outcome = await _download_polyhaven_hdri(result, key)
	elif provider == "polyhaven":
		outcome = await _download_polyhaven(result, key)
	elif provider == "polypizza":
		outcome = await _download_polypizza(result, key)
	elif provider == "blendkit":
		outcome = await _download_blendkit(result, key)
	else:
		outcome = {"path": "", "error": "Unknown store."}
	if not str(outcome["path"]).is_empty():
		var path := str(outcome["path"])
		RuntimeModelLoader.forget(path)
		var readable := false
		match kind:
			"hdri":
				var image := Image.load_from_file(path)
				readable = image != null and not image.is_empty()
			"texture":
				readable = RuntimeModelLoader.load_material(path) != null
			_:
				readable = RuntimeModelLoader.load_scene(path) != null
		if not readable:
			outcome = {"path": "", "error": "The downloaded file couldn't be opened."}
		else:
			var entry := result.duplicate()
			entry.erase("download")
			entry.erase("popularity")
			entry.erase("files")
			entry.erase("can_download")
			entry["file"] = path
			entry["downloaded_at"] = Time.get_datetime_string_from_system(true)
			var image: Image = _thumb_images.get(str(result.get("thumbnail", "")))
			if image:
				var thumb_path := path.get_basename() + ".thumbnail.png"
				if image.save_png(thumb_path) == OK:
					entry["thumbnail_file"] = thumb_path
			entries()[key] = entry
			_save_index()
			library_changed.emit()
	_downloading.erase(key)
	return outcome


func _download_polyhaven(result: Dictionary, key: String) -> Dictionary:
	var id := str(result["id"])
	var reply: Dictionary = await _http_get(POLYHAVEN_API + "/files/" + id.uri_encode())
	if not reply["ok"]:
		return {"path": "", "error": "Couldn't get the file list from Poly Haven: %s" % reply["error"]}
	var data: Variant = JSON.parse_string((reply["body"] as PackedByteArray).get_string_from_utf8())
	if not data is Dictionary or not data.get("gltf") is Dictionary:
		return {"path": "", "error": "This Poly Haven asset has no glTF version."}
	var formats: Dictionary = data["gltf"]
	if formats.is_empty():
		return {"path": "", "error": "This Poly Haven asset has no glTF files."}
	# Models: smallest texture set (usually 1k) — quick, fine on screen.
	# Textures: 2k, so close-ups of the ground stay sharp.
	var kind := str(result.get("kind", "model"))
	var chosen: Variant = formats[_pick_resolution(formats.keys(), "2k" if kind == "texture" else "")]
	var main: Dictionary = chosen.get("gltf", {}) if chosen is Dictionary else {}
	var main_url := str(main.get("url", ""))
	if main_url.is_empty():
		return {"path": "", "error": "Poly Haven didn't provide a download link."}

	var folder := RuntimeModelLoader.ONLINE_DIR + ("textures/%s/" % id if kind == "texture" else "polyhaven/%s/" % id)
	DirAccess.make_dir_recursive_absolute(folder)
	var jobs: Array = []
	var includes: Variant = main.get("include", {})
	if includes is Dictionary:
		for relative in includes:
			var rel := str(relative).simplify_path()
			if rel.begins_with("/") or rel.contains("..") or rel.contains(":"):
				continue
			jobs.append([str(includes[relative].get("url", "")), folder.path_join(rel)])
	var main_path := folder.path_join(main_url.get_file().split("?")[0])
	jobs.append([main_url, main_path])

	for i in jobs.size():
		var job: Array = jobs[i]
		if str(job[0]).is_empty():
			continue
		DirAccess.make_dir_recursive_absolute(str(job[1]).get_base_dir())
		var file_reply: Dictionary = await _http_get(job[0], PackedStringArray(), job[1], key, float(i) / jobs.size(), 1.0 / jobs.size())
		if not file_reply["ok"]:
			return {"path": "", "error": "Download failed (%s): %s" % [str(job[1]).get_file(), file_reply["error"]]}
	return {"path": main_path, "error": ""}


## Downloads a photo sky as Radiance .hdr (2k by default), which Godot can load
## at runtime.
func _download_polyhaven_hdri(result: Dictionary, key: String) -> Dictionary:
	var id := str(result["id"])
	var reply: Dictionary = await _http_get(POLYHAVEN_API + "/files/" + id.uri_encode())
	if not reply["ok"]:
		return {"path": "", "error": "Couldn't get the file list from Poly Haven: %s" % reply["error"]}
	var data: Variant = JSON.parse_string((reply["body"] as PackedByteArray).get_string_from_utf8())
	if not data is Dictionary or not data.get("hdri") is Dictionary:
		return {"path": "", "error": "This Poly Haven sky has no HDRI files."}
	var resolutions: Dictionary = data["hdri"]
	if resolutions.is_empty():
		return {"path": "", "error": "This Poly Haven sky has no HDRI files."}
	var resolution: Variant = _pick_resolution(resolutions.keys(), "2k")
	var formats: Variant = resolutions[resolution]
	var file_info: Variant = formats.get("hdr") if formats is Dictionary else null
	if not file_info is Dictionary:
		return {"path": "", "error": "Only an EXR version is available for this sky; please choose another one."}
	var url := str(file_info.get("url", ""))
	if url.is_empty():
		return {"path": "", "error": "Poly Haven didn't provide a download link."}
	var folder := RuntimeModelLoader.ONLINE_DIR + "hdris/"
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder + "%s_%s.hdr" % [id.validate_filename(), str(resolution).validate_filename()]
	var file_reply: Dictionary = await _http_get(url, PackedStringArray(), path, key)
	if not file_reply["ok"]:
		return {"path": "", "error": "Download failed: %s" % file_reply["error"]}
	return {"path": path, "error": ""}


## Picks [param preferred] if available, otherwise the smallest resolution
## ("1k" < "2k" < "4k"…).
static func _pick_resolution(keys: Array, preferred: String) -> Variant:
	if not preferred.is_empty() and keys.has(preferred):
		return preferred
	var sorted := keys.duplicate()
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a).to_int() < str(b).to_int())
	return sorted[0]


func _download_polypizza(result: Dictionary, key: String) -> Dictionary:
	var url := str(result.get("download", ""))
	if url.is_empty():
		var model: Dictionary = await _polypizza_model(str(result["id"]))
		url = str(model.get("download", ""))
	if url.is_empty():
		return {"path": "", "error": "Poly Pizza didn't provide a download link (is your API key set?)."}
	var folder := RuntimeModelLoader.ONLINE_DIR + "polypizza/"
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder + "%s.glb" % str(result["id"]).validate_filename()
	var reply: Dictionary = await _http_get(url, PackedStringArray(), path, key)
	if not reply["ok"]:
		return {"path": "", "error": "Download failed: %s" % reply["error"]}
	return {"path": path, "error": ""}


# --- BlendKit ----------------------------------------------------------------------------
# Same public API the official Blender add-on uses (www.blendkit.com/api/v1):
# /search/ for results, then each file's downloadUrl returns a signed link.

func _blendkit_headers() -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json",
		"Platform-Version: Godot %s" % Engine.get_version_info().get("string", "4"),
		"Addon-Version: SceneBuilder-%s" % ProjectSettings.get_setting("application/config/version", "1"),
		"Origin-Name: Scene Builder"])
	var api_key := blendkit_key()
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
	return headers


static func blendkit_search_url(server: String, query: String, free_only: bool, page_size: int = PAGE_SIZE) -> String:
	var request := "?query=" + query.strip_edges().uri_encode().replace("%20", "+")
	request += "+asset_type:model"
	if free_only:
		request += "+is_free:true"
	request += "+order:" + ("_score" if not query.strip_edges().is_empty() else "-score")
	request += "&dict_parameters=1&page_size=%d" % page_size
	return server + "/api/v1/search/" + request


func _search_blendkit(query: String, page: int) -> Dictionary:
	var url := ""
	if page > 0 and not _blendkit_next.is_empty():
		url = _blendkit_next
	else:
		url = blendkit_search_url(blendkit_server(), query, blendkit_key().is_empty() or bool(get_setting("blendkit_free_only", true)))
	var reply: Dictionary = await _http_get(url, _blendkit_headers())
	if not reply["ok"]:
		if int(reply.get("code", 0)) == 401 or int(reply.get("code", 0)) == 403:
			return {"error": "BlendKit didn't accept the API key. Clear it to use free models, or copy it again from your BlendKit profile."}
		if int(reply.get("code", 0)) == 429:
			return {"error": "BlendKit says too many requests; wait a moment and try again."}
		return {"error": "Couldn't reach BlendKit: %s" % reply["error"]}
	var data: Variant = JSON.parse_string((reply["body"] as PackedByteArray).get_string_from_utf8())
	if not data is Dictionary:
		return {"error": "BlendKit sent an unexpected reply."}
	var next: Variant = data.get("next")
	_blendkit_next = str(next) if next is String else ""
	var results: Array = []
	var items: Variant = data.get("results", [])
	if items is Array:
		for item in items:
			if item is Dictionary and str(item.get("assetType", "model")) == "model":
				results.append(blendkit_result(item))
	return {"results": results, "has_more": not _blendkit_next.is_empty()}


## Turns one BlendKit search result into the app's result dictionary.
static func blendkit_result(item: Dictionary) -> Dictionary:
	var author: Variant = item.get("author", {})
	var author_name := ""
	if author is Dictionary:
		author_name = str(author.get("fullName", "")).strip_edges()
		if author_name.is_empty():
			author_name = ("%s %s" % [author.get("firstName", ""), author.get("lastName", "")]).strip_edges()
	var files: Array = []
	var types := PackedStringArray()
	var raw_files: Variant = item.get("files", [])
	if raw_files is Array:
		for f in raw_files:
			if f is Dictionary and not str(f.get("downloadUrl", "")).is_empty():
				files.append({"fileType": str(f.get("fileType", "")), "downloadUrl": str(f.get("downloadUrl", "")), "size": int(f.get("fileUploadSize", 0))})
				types.append(str(f.get("fileType", "")))
	var has_gltf := false
	for t in BLENDKIT_GLTF_TYPES:
		if types.has(t):
			has_gltf = true
	var licence := str(item.get("license", ""))
	var thumb := str(item.get("thumbnailMiddleUrl", ""))
	if thumb.is_empty():
		thumb = str(item.get("thumbnailSmallUrl", ""))
	var id := str(item.get("assetBaseId", item.get("id", "")))
	var title := str(item.get("displayName", ""))
	if title.is_empty():
		title = str(item.get("name", id))
	var can_download: Variant = item.get("canDownload", true)
	return {
		"provider": "blendkit",
		"id": id,
		"title": title,
		"author": author_name,
		"author_url": str(author.get("aboutMeUrl", "")) if author is Dictionary else "",
		"license": "CC0" if licence == "cc_zero" else "BlendKit Royalty Free",
		"thumbnail": thumb,
		"source_url": "%s/asset-gallery-detail/%s/" % [BLENDKIT_SERVER, str(item.get("id", id))],
		"category": str(item.get("category", "")),
		"popularity": 0,
		"free": bool(item.get("isFree", false)),
		"can_download": can_download if can_download is bool else true,
		"needs_blender": not has_gltf,
		"files": files,
	}


func _blendkit_asset(id: String) -> Dictionary:
	var url := blendkit_search_url(blendkit_server(), "", false, 1).replace("?query=+asset_type", "?query=asset_base_id:%s+asset_type" % id.uri_encode())
	var reply: Dictionary = await _http_get(url, _blendkit_headers())
	if not reply["ok"]:
		return {}
	var data: Variant = JSON.parse_string((reply["body"] as PackedByteArray).get_string_from_utf8())
	if not data is Dictionary or not data.get("results") is Array or (data["results"] as Array).is_empty():
		return {}
	return blendkit_result(data["results"][0])


## Picks the file to download: glTF first (no Blender needed), else the
## smallest-texture .blend. Returns the file dictionary or {}.
static func blendkit_pick_file(files: Array, allow_blend: bool) -> Dictionary:
	var order := Array(BLENDKIT_GLTF_TYPES)
	if allow_blend:
		order.append_array(Array(BLENDKIT_BLEND_TYPES))
	for wanted in order:
		for f in files:
			if f is Dictionary and str(f.get("fileType", "")) == wanted:
				return f
	return {}


func _download_blendkit(result: Dictionary, key: String) -> Dictionary:
	if not bool(result.get("can_download", true)):
		return {"path": "", "error": "This BlendKit model isn't free. Paste the API key of a BlendKit plan that includes it, or pick a free one."}
	var files: Array = result.get("files", [])
	if files.is_empty():
		var fresh := await _blendkit_asset(str(result["id"]))
		files = fresh.get("files", [])
	var blender := blender_path()
	var file := blendkit_pick_file(files, true)
	if file.is_empty():
		return {"path": "", "error": "BlendKit has no downloadable file for this model."}
	var is_blend := not BLENDKIT_GLTF_TYPES.has(str(file.get("fileType", "")))
	if is_blend and blender.is_empty():
		return {"path": "", "error": "This model is only available as a .blend file, so Scene Builder needs Blender to convert it. Install Blender (free, blender.org) or set its path with \"Blender…\" above, then try again."}
	if _scene_uuid.is_empty():
		_scene_uuid = _make_uuid()
	# 1) Ask for a signed link.
	var sep := "&" if str(file["downloadUrl"]).contains("?") else "?"
	var meta: Dictionary = await _http_get(str(file["downloadUrl"]) + sep + "scene_uuid=" + _scene_uuid, _blendkit_headers())
	if not meta["ok"]:
		if int(meta.get("code", 0)) in [401, 402, 403]:
			return {"path": "", "error": "BlendKit says this model needs an account or plan (%d). Paste your BlendKit API key above, or pick a free model." % meta["code"]}
		return {"path": "", "error": "Couldn't get the download link from BlendKit: %s" % meta["error"]}
	var urls := blendkit_parse_links((meta["body"] as PackedByteArray).get_string_from_utf8())
	if urls.is_empty():
		return {"path": "", "error": "BlendKit didn't provide a download link."}
	# 2) Download the file.
	var folder := RuntimeModelLoader.ONLINE_DIR + "blendkit/%s/" % str(result["id"]).validate_filename()
	DirAccess.make_dir_recursive_absolute(folder)
	var file_name := urls[0].get_file().split("?")[0].uri_decode().validate_filename()
	if file_name.is_empty() or file_name.get_extension().is_empty():
		file_name = "asset." + ("blend" if is_blend else "glb")
	var path := folder + file_name
	var got: Dictionary = {}
	for url in urls:
		got = await _http_get(url, PackedStringArray(), path, key, 0.0, 0.85 if is_blend else 1.0)
		if got["ok"]:
			break
	if not got["ok"]:
		return {"path": "", "error": "Download failed: %s" % got["error"]}
	# 3) Unzip archives.
	if path.get_extension().to_lower() == "zip":
		var unzip_error := extract_zip(path, folder)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if not unzip_error.is_empty():
			return {"path": "", "error": unzip_error}
		path = find_model_file(folder)
		if path.is_empty():
			return {"path": "", "error": "The BlendKit download didn't contain a model file."}
	# 4) Convert .blend with the user's Blender.
	if path.get_extension().to_lower() == "blend":
		if blender.is_empty():
			return {"path": "", "error": "This model came as a .blend file; install Blender (blender.org) so Scene Builder can convert it."}
		download_progress.emit(key, 0.9)
		var converted: Dictionary = await convert_blend(blender, path, folder + str(result["id"]).validate_filename() + ".glb")
		if not str(converted["error"]).is_empty():
			return {"path": "", "error": converted["error"]}
		path = converted["path"]
	return {"path": path, "error": ""}


## The links in a download-metadata reply ({"filePath": …} or {"filePaths": [{"url": …}]}).
static func blendkit_parse_links(body: String) -> PackedStringArray:
	var urls := PackedStringArray()
	var data: Variant = JSON.parse_string(body)
	if not data is Dictionary:
		return urls
	var paths: Variant = data.get("filePaths", [])
	if paths is Array:
		for entry in paths:
			if entry is Dictionary:
				var u := str(entry.get("url", ""))
				if (u.begins_with("https://") or u.begins_with("http://")) and not urls.has(u):
					urls.append(u)
	var single := str(data.get("filePath", ""))
	if (single.begins_with("https://") or single.begins_with("http://")) and not urls.has(single):
		urls.append(single)
	return urls


## Extracts [param zip_path] into [param folder] (no paths outside it). "" or an error.
static func extract_zip(zip_path: String, folder: String) -> String:
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		return "The downloaded archive couldn't be opened."
	for name in reader.get_files():
		var rel := name.simplify_path()
		if rel.ends_with("/") or rel.is_empty():
			continue
		if rel.begins_with("/") or rel.contains("..") or rel.contains(":"):
			continue
		var dest := folder.path_join(rel)
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		var out := FileAccess.open(dest, FileAccess.WRITE)
		if out == null:
			reader.close()
			return "Couldn't save %s." % rel
		out.store_buffer(reader.read_file(name))
		out.close()
	reader.close()
	return ""


## First .glb, then .gltf, .fbx or .blend file in [param folder] (searching subfolders).
static func find_model_file(folder: String) -> String:
	for ext in ["glb", "gltf", "fbx", "blend"]:
		var found := _find_ext(folder, ext, 0)
		if not found.is_empty():
			return found
	return ""


static func _find_ext(folder: String, ext: String, depth: int) -> String:
	for f in DirAccess.get_files_at(folder):
		if f.get_extension().to_lower() == ext:
			return folder.path_join(f)
	if depth < 3:
		for d in DirAccess.get_directories_at(folder):
			var found := _find_ext(folder.path_join(d), ext, depth + 1)
			if not found.is_empty():
				return found
	return ""


## Runs Blender in the background to turn [param blend_path] into a .glb.
## Awaitable; returns { "path", "error" }. The UI keeps running meanwhile.
func convert_blend(blender: String, blend_path: String, glb_path: String) -> Dictionary:
	var script_path := RuntimeModelLoader.ONLINE_DIR + "blend_to_glb.py"
	DirAccess.make_dir_recursive_absolute(RuntimeModelLoader.ONLINE_DIR)
	var script := FileAccess.open(script_path, FileAccess.WRITE)
	if script == null:
		return {"path": "", "error": "Couldn't write the Blender converter script."}
	script.store_string(FileAccess.get_file_as_string(BLENDKIT_CONVERTER))
	script.close()
	var args := PackedStringArray(["-b", ProjectSettings.globalize_path(blend_path), "--factory-startup",
		"-P", ProjectSettings.globalize_path(script_path), "--", ProjectSettings.globalize_path(glb_path)])
	var job := {"output": [], "code": -1, "done": false}
	var thread := Thread.new()
	thread.start(func() -> void:
		var output: Array = []
		job["code"] = OS.execute(blender, args, output, true)
		job["output"] = output
		job["done"] = true)
	var started := Time.get_ticks_msec()
	while not job["done"]:
		await get_tree().process_frame
		if Time.get_ticks_msec() - started > 600000:
			break
	if not job["done"]:
		return {"path": "", "error": "Blender took more than 10 minutes to convert this model."}
	thread.wait_to_finish()
	var text := "\n".join(PackedStringArray(job["output"]))
	for line in text.split("\n"):
		if line.begins_with("SB_RESULT error"):
			return {"path": "", "error": "Blender couldn't convert this model: %s" % line.substr(16)}
	if not FileAccess.file_exists(glb_path):
		return {"path": "", "error": "Blender couldn't convert this model (exit code %d). Is the Blender path right, and is it Blender 3.6 or newer?" % job["code"]}
	return {"path": glb_path, "error": ""}


static func _make_uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]


# --- Importing the user's own files ---------------------------------------------------------

## Copies a .glb into the library. Returns { "path", "error", "warning" }.
static func import_file(source: String, as_character: bool) -> Dictionary:
	var extension := source.get_extension().to_lower()
	if extension != "glb" and extension != "fbx":
		return {"path": "", "error": "Please choose a .glb or .fbx file (e.g. a Mixamo download, or Blender: File → Export → glTF Binary)."}
	if not FileAccess.file_exists(source):
		return {"path": "", "error": "File not found: %s" % source}
	var folder := RuntimeModelLoader.CHARACTERS_DIR if as_character else RuntimeModelLoader.IMPORTED_DIR
	DirAccess.make_dir_recursive_absolute(folder)
	var base := source.get_file().get_basename().validate_filename()
	var dest := folder + base + "." + extension
	var n := 2
	while FileAccess.file_exists(dest):
		dest = folder + "%s_%d.%s" % [base, n, extension]
		n += 1
	var err := DirAccess.copy_absolute(source, ProjectSettings.globalize_path(dest))
	if err != OK:
		return {"path": "", "error": "Couldn't copy the file (%s)." % error_string(err)}
	var scene := RuntimeModelLoader.load_scene(dest)
	if scene == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dest))
		return {"path": "", "error": "That file couldn't be read as a 3D model."}
	var warning := ""
	if as_character:
		var instance := scene.instantiate()
		if instance is ImportedCharacter and not (instance as ImportedCharacter).has_animations():
			warning = "No animation clips were found in this file, so the character can be posed and moved but won't play motions. Export it with its animations included."
		instance.free()
	return {"path": dest, "error": "", "warning": warning}


# --- HTTP ---------------------------------------------------------------------------

## GET [param url]. With [param to_file] the body is streamed to disk.
## Returns { "ok", "code", "body", "error" }.
func _http_get(url: String, headers: PackedStringArray = PackedStringArray(), to_file: String = "", progress_key: String = "", progress_base: float = 0.0, progress_span: float = 1.0) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 90.0
	request.use_threads = true
	if not to_file.is_empty():
		request.download_file = to_file
	add_child(request)
	var all_headers := PackedStringArray(["User-Agent: " + USER_AGENT])
	all_headers.append_array(headers)
	var reply := {}
	request.request_completed.connect(_store_reply.bind(reply))
	var err := request.request(url, all_headers)
	if err != OK:
		request.queue_free()
		return {"ok": false, "code": 0, "error": "couldn't start the request (%s)" % error_string(err)}
	while not reply.has("result"):
		if not progress_key.is_empty():
			var total := request.get_body_size()
			if total > 0:
				download_progress.emit(progress_key, progress_base + progress_span * float(request.get_downloaded_bytes()) / total)
		await get_tree().process_frame
	request.queue_free()
	var result := int(reply["result"])
	var code := int(reply["code"])
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": code, "error": _result_text(result)}
	if code >= 400:
		if not to_file.is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(to_file))
		return {"ok": false, "code": code, "error": "the server replied %d" % code}
	return {"ok": true, "code": code, "body": reply["body"], "error": ""}


func _store_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, reply: Dictionary) -> void:
	reply["result"] = result
	reply["code"] = code
	reply["body"] = body


static func _result_text(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR:
			return "no internet connection (or the site is unreachable)"
		HTTPRequest.RESULT_TIMEOUT:
			return "the connection timed out"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "a secure-connection (TLS) error"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN, HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "couldn't save the file to disk"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "the file is too large"
	return "network error %d" % result

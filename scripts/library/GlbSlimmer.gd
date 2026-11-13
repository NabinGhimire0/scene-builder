class_name GlbSlimmer
extends RefCounted
## Makes a .glb smaller by shrinking its embedded pictures (textures) to at most
## [code]max_size[/code] pixels and re-encoding them. Nothing else in the file is
## touched: meshes, skeletons, animations and face shapes stay exactly as they
## were, so the slimmed copy behaves identically, just with softer textures.

const MAGIC := 0x46546C67   # "glTF"
const CHUNK_JSON := 0x4E4F534A
const CHUNK_BIN := 0x004E4942


## Writes a slimmed copy of [param source] to [param dest]. Returns
## { "ok": bool, "before": bytes, "after": bytes, "images": shrunk count, "error": "" }.
## If the file can't be slimmed safely it is copied unchanged (ok stays true).
static func slim(source: String, dest: String, max_size: int = 1024) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(source)
	var out := {"ok": true, "before": bytes.size(), "after": bytes.size(), "images": 0, "error": ""}
	var result := _slim_bytes(bytes, max_size)
	var data: PackedByteArray = result.get("bytes", bytes)
	out["images"] = int(result.get("images", 0))
	out["error"] = str(result.get("error", ""))
	var file := FileAccess.open(dest, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "before": bytes.size(), "after": 0, "images": 0, "error": "Can't write %s" % dest}
	file.store_buffer(data)
	file.close()
	out["after"] = data.size()
	return out


static func _slim_bytes(bytes: PackedByteArray, max_size: int) -> Dictionary:
	if bytes.size() < 20 or bytes.decode_u32(0) != MAGIC or bytes.decode_u32(4) != 2:
		return {"error": "not a glTF 2 binary"}
	var json_length := bytes.decode_u32(12)
	if bytes.decode_u32(16) != CHUNK_JSON:
		return {"error": "no JSON chunk"}
	var json_text := bytes.slice(20, 20 + json_length).get_string_from_utf8()
	var bin_start := 20 + json_length
	if bytes.size() < bin_start + 8 or bytes.decode_u32(bin_start + 4) != CHUNK_BIN:
		return {"error": "no binary chunk"}
	var bin_length := bytes.decode_u32(bin_start)
	var bin := bytes.slice(bin_start + 8, bin_start + 8 + bin_length)
	var gltf: Variant = JSON.parse_string(json_text)
	if not gltf is Dictionary:
		return {"error": "unreadable JSON"}
	var doc: Dictionary = gltf
	var views: Array = doc.get("bufferViews", [])
	var images: Array = doc.get("images", [])
	if images.is_empty() or (doc.get("buffers", []) as Array).size() != 1:
		return {"error": "nothing to shrink"}
	for view in views:
		if int((view as Dictionary).get("buffer", 0)) != 0:
			return {"error": "several buffers"}
	# New bytes for the views that hold pictures.
	var replaced := {}
	var shrunk := 0
	for image in images:
		var info: Dictionary = image
		if not info.has("bufferView"):
			continue
		var index := int(info["bufferView"])
		if replaced.has(index) or index < 0 or index >= views.size():
			continue
		var view: Dictionary = views[index]
		var start := int(view.get("byteOffset", 0))
		var old := bin.slice(start, start + int(view["byteLength"]))
		var mime := str(info.get("mimeType", ""))
		var smaller := _shrink(old, mime, max_size)
		if smaller.is_empty():
			continue
		replaced[index] = smaller
		info["mimeType"] = smaller["mime"]
		shrunk += 1
	if shrunk == 0:
		return {"error": "pictures already small"}
	# Lay the binary chunk out again, keeping every view 4-byte aligned.
	var new_bin := PackedByteArray()
	for i in views.size():
		var view: Dictionary = views[i]
		while new_bin.size() % 4 != 0:
			new_bin.append(0)
		var chunk: PackedByteArray
		if replaced.has(i):
			chunk = (replaced[i] as Dictionary)["bytes"]
		else:
			var start := int(view.get("byteOffset", 0))
			chunk = bin.slice(start, start + int(view["byteLength"]))
		view["byteOffset"] = new_bin.size()
		view["byteLength"] = chunk.size()
		new_bin.append_array(chunk)
	while new_bin.size() % 4 != 0:
		new_bin.append(0)
	((doc["buffers"] as Array)[0] as Dictionary)["byteLength"] = new_bin.size()
	return {"bytes": write_glb(doc, new_bin), "images": shrunk}


## A .glb file from a glTF JSON document and its single binary buffer.
static func write_glb(doc: Dictionary, bin: PackedByteArray) -> PackedByteArray:
	var json_bytes := to_json(doc).to_utf8_buffer()
	while json_bytes.size() % 4 != 0:
		json_bytes.append(0x20)
	var padded := bin.duplicate()
	while padded.size() % 4 != 0:
		padded.append(0)
	var out := PackedByteArray()
	out.resize(12)
	out.encode_u32(0, MAGIC)
	out.encode_u32(4, 2)
	var header := PackedByteArray()
	header.resize(8)
	header.encode_u32(0, json_bytes.size())
	header.encode_u32(4, CHUNK_JSON)
	out.append_array(header)
	out.append_array(json_bytes)
	header.encode_u32(0, padded.size())
	header.encode_u32(4, CHUNK_BIN)
	out.append_array(header)
	out.append_array(padded)
	out.encode_u32(8, out.size())
	return out


## Packs a .gltf and the files next to it (buffers, textures) into one .glb.
## Returns the .glb bytes, or empty if a file it needs is missing.
static func gltf_to_glb(path: String) -> PackedByteArray:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return PackedByteArray()
	var doc: Dictionary = parsed
	var folder := path.get_base_dir()
	var bin := PackedByteArray()
	var starts: Array = []
	for buffer in doc.get("buffers", []):
		var info: Dictionary = buffer
		while bin.size() % 4 != 0:
			bin.append(0)
		starts.append(bin.size())
		var uri := str(info.get("uri", ""))
		if uri.is_empty() or uri.begins_with("data:"):
			return PackedByteArray()   # rare; not worth handling
		var file := folder.path_join(uri.uri_decode())
		if not FileAccess.file_exists(file):
			return PackedByteArray()
		bin.append_array(FileAccess.get_file_as_bytes(file))
	var views: Array = doc.get("bufferViews", [])
	for view in views:
		var info: Dictionary = view
		info["byteOffset"] = int(info.get("byteOffset", 0)) + int(starts[int(info.get("buffer", 0))])
		info["buffer"] = 0
	for image in doc.get("images", []):
		var info: Dictionary = image
		var uri := str(info.get("uri", ""))
		if uri.is_empty():
			continue
		var file := folder.path_join(uri.uri_decode())
		if not FileAccess.file_exists(file):
			return PackedByteArray()
		while bin.size() % 4 != 0:
			bin.append(0)
		var bytes := FileAccess.get_file_as_bytes(file)
		views.append({"buffer": 0, "byteOffset": bin.size(), "byteLength": bytes.size()})
		bin.append_array(bytes)
		info.erase("uri")
		info["bufferView"] = views.size() - 1
		var extension := uri.get_extension().to_lower()
		info["mimeType"] = "image/png" if extension == "png" else ("image/webp" if extension == "webp" else "image/jpeg")
	doc["bufferViews"] = views
	doc["buffers"] = [{"byteLength": bin.size()}]
	return write_glb(doc, bin)


## Slims .glb bytes in memory (same as [method slim]); returns them unchanged if
## nothing could be shrunk.
static func slim_bytes(bytes: PackedByteArray, max_size: int = 1024) -> PackedByteArray:
	var result := _slim_bytes(bytes, max_size)
	return result.get("bytes", bytes)


## A smaller encoding of one picture, or {} if it's already small enough.
static func _shrink(data: PackedByteArray, mime: String, max_size: int) -> Dictionary:
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if mime == "image/jpeg":
		err = image.load_jpg_from_buffer(data)
	elif mime == "image/png":
		err = image.load_png_from_buffer(data)
	elif mime == "image/webp":
		err = image.load_webp_from_buffer(data)
	if err != OK or image.is_empty():
		return {}
	var biggest := maxi(image.get_width(), image.get_height())
	if biggest > max_size:
		var k := float(max_size) / float(biggest)
		image.resize(maxi(1, roundi(image.get_width() * k)), maxi(1, roundi(image.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	var has_alpha := image.detect_alpha() != Image.ALPHA_NONE
	var encoded: PackedByteArray
	var new_mime := mime
	if has_alpha:
		encoded = image.save_png_to_buffer()
		new_mime = "image/png"
	else:
		if image.get_format() != Image.FORMAT_RGB8:
			image.convert(Image.FORMAT_RGB8)
		encoded = image.save_jpg_to_buffer(0.88)
		new_mime = "image/jpeg"
	if encoded.is_empty() or encoded.size() >= data.size():
		return {}
	return {"bytes": encoded, "mime": new_mime}


## JSON with whole numbers written as integers (glTF readers expect 3, not 3.0).
static func to_json(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var parts := PackedStringArray()
			for key in value:
				parts.append(JSON.stringify(str(key)) + ":" + to_json(value[key]))
			return "{" + ",".join(parts) + "}"
		TYPE_ARRAY:
			var parts := PackedStringArray()
			for item in value:
				parts.append(to_json(item))
			return "[" + ",".join(parts) + "]"
		TYPE_FLOAT:
			var f: float = value
			if is_finite(f) and f == floorf(f) and absf(f) < 1e15:
				return str(int(f))
			return String.num(f, 9) if is_finite(f) else "0"
		TYPE_INT:
			return str(value)
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_NIL:
			return "null"
		_:
			return JSON.stringify(str(value))

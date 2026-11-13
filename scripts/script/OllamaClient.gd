class_name OllamaClient
extends Node
## Talks to Ollama (a free AI that runs on this computer, https://ollama.com):
## lists the installed models and streams chat replies, word by word.
## Settings live in user://settings.cfg [ollama] host, model, context.

signal models_listed(models: PackedStringArray, error: String)
signal token(text: String)
signal finished(text: String, error: String)

const SETTINGS_FILE := "user://settings.cfg"
const DEFAULT_HOST := "http://127.0.0.1:11434"
const DEFAULT_CONTEXT := 16384
## Good models for a 6–8 GB graphics card, best first.
const SUGGESTED := ["qwen2.5:7b", "qwen3:8b", "llama3.1:8b", "gemma2:9b", "mistral:7b"]

var host := DEFAULT_HOST
var model := ""
var context := DEFAULT_CONTEXT
var temperature := 0.6

var _http: HTTPClient
var _state := ""            # "", "tags", "chat"
var _body := ""
var _buffer := PackedByteArray()
var _reply := ""
var _status := 0
var _started_ms := 0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	host = str(cfg.get_value("ollama", "host", DEFAULT_HOST))
	model = str(cfg.get_value("ollama", "model", ""))
	context = int(cfg.get_value("ollama", "context", DEFAULT_CONTEXT))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("ollama", "host", host)
	cfg.set_value("ollama", "model", model)
	cfg.set_value("ollama", "context", context)
	cfg.save(SETTINGS_FILE)


func is_busy() -> bool:
	return not _state.is_empty()


func seconds() -> float:
	return (Time.get_ticks_msec() - _started_ms) / 1000.0 if is_busy() else 0.0


## Asks Ollama which models are installed ([signal models_listed]).
func list_models() -> void:
	_start("tags", HTTPClient.METHOD_GET, "/api/tags", "")


## Sends a chat; the reply arrives through [signal token] and [signal finished].
func chat(messages: Array, options: Dictionary = {}) -> void:
	var opts := {"num_ctx": context, "temperature": temperature}
	for k in options:
		opts[k] = options[k]
	var body := JSON.stringify({"model": model, "messages": messages, "stream": true, "options": opts})
	_start("chat", HTTPClient.METHOD_POST, "/api/chat", body)


func cancel() -> void:
	if _http:
		_http.close()
	var was := _state
	_state = ""
	if was == "chat":
		finished.emit(_reply, "Stopped.")


func _start(kind: String, method: int, path: String, body: String) -> void:
	if is_busy():
		cancel()
	_http = HTTPClient.new()
	var url := host.strip_edges().trim_suffix("/")
	var tls := url.begins_with("https://")
	url = url.trim_prefix("http://").trim_prefix("https://")
	var port := 443 if tls else 80
	if url.contains(":"):
		port = int(url.get_slice(":", 1))
		url = url.get_slice(":", 0)
	var err := _http.connect_to_host(url, port, TLSOptions.client() if tls else null)
	if err != OK:
		_fail(kind, "Couldn't reach Ollama at %s." % host)
		return
	_state = kind
	_body = body
	_buffer = PackedByteArray()
	_reply = ""
	_status = 0
	_started_ms = Time.get_ticks_msec()
	set_meta("method", method)
	set_meta("path", path)
	set_meta("requested", false)


func _fail(kind: String, message: String) -> void:
	_state = ""
	if _http:
		_http.close()
	var hint := message + " Is Ollama running? Start it from the Start menu (or run \"ollama serve\"), then press Refresh."
	if kind == "tags":
		models_listed.emit(PackedStringArray(), hint)
	else:
		finished.emit(_reply, hint)


func _process(_delta: float) -> void:
	if _state.is_empty() or _http == null:
		return
	_http.poll()
	match _http.get_status():
		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_REQUESTING:
			if Time.get_ticks_msec() - _started_ms > 8000 and not bool(get_meta("requested")):
				_fail(_state, "Ollama didn't answer at %s." % host)
		HTTPClient.STATUS_CONNECTED:
			if not bool(get_meta("requested")):
				set_meta("requested", true)
				var headers := PackedStringArray(["Content-Type: application/json"])
				var err := _http.request(int(get_meta("method")), str(get_meta("path")), headers, _body)
				if err != OK:
					_fail(_state, "Couldn't send the request to Ollama.")
			else:
				# back to "connected" after a request: the whole response has arrived
				if _status == 0 and _http.has_response():
					_status = _http.get_response_code()
				_finish()
		HTTPClient.STATUS_BODY:
			_status = _http.get_response_code()
			var chunk := _http.read_response_body_chunk()
			if not chunk.is_empty():
				_buffer.append_array(chunk)
				if _state == "chat" and _status == 200:
					_drain_lines()
		HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			_fail(_state, "Couldn't connect to Ollama at %s." % host)
		HTTPClient.STATUS_DISCONNECTED:
			_finish()


## Streamed chat: one JSON object per line.
func _drain_lines() -> void:
	while true:
		var nl := -1
		for i in _buffer.size():
			if _buffer[i] == 10:
				nl = i
				break
		if nl < 0:
			return
		var line := _buffer.slice(0, nl).get_string_from_utf8()
		_buffer = _buffer.slice(nl + 1)
		var data: Variant = JSON.parse_string(line)
		if data is Dictionary:
			if (data as Dictionary).has("error"):
				var e := str(data["error"])
				_state = ""
				_http.close()
				finished.emit(_reply, "Ollama: " + e)
				return
			var piece := str(((data as Dictionary).get("message", {}) as Dictionary).get("content", ""))
			if not piece.is_empty():
				_reply += piece
				token.emit(piece)
			if bool(data.get("done", false)):
				_state = ""
				_http.close()
				finished.emit(_strip_thinking(_reply), "")
				return


func _finish() -> void:
	var kind := _state
	if kind.is_empty():
		return
	_state = ""
	var text := _buffer.get_string_from_utf8()
	if _status != 200:
		var msg := text
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary and (parsed as Dictionary).has("error"):
			msg = str(parsed["error"])
		if msg.contains("not found") and kind == "chat":
			msg += ". Install it first: open Command Prompt and run  ollama pull %s" % model
		if kind == "tags":
			models_listed.emit(PackedStringArray(), "Ollama answered with an error (%d): %s" % [_status, msg])
		else:
			finished.emit(_reply, "Ollama answered with an error (%d): %s" % [_status, msg])
		return
	if kind == "tags":
		var parsed: Variant = JSON.parse_string(text)
		var names := PackedStringArray()
		if parsed is Dictionary:
			for m in (parsed as Dictionary).get("models", []):
				names.append(str(m.get("name", "")))
		models_listed.emit(names, "" if not names.is_empty() else "Ollama is running but has no models yet. Open Command Prompt and run:  ollama pull qwen2.5:7b")
	else:
		_drain_lines()
		if not _state.is_empty() or _reply.is_empty():
			return
		finished.emit(_strip_thinking(_reply), "")


## Some models (qwen3, deepseek-r1) think out loud between <think> tags first.
static func _strip_thinking(text: String) -> String:
	var a := text.find("<think>")
	var b := text.find("</think>")
	if a >= 0 and b > a:
		return (text.substr(0, a) + text.substr(b + 8)).strip_edges()
	return text


## The script inside a reply (models usually wrap it in a ``` block).
static func extract_script(text: String) -> String:
	var t := _strip_thinking(text)
	var fence := t.find("```")
	if fence >= 0:
		var start := t.find("\n", fence)
		var end := t.find("```", start)
		if start >= 0 and end > start:
			return t.substr(start + 1, end - start - 1).strip_edges()
		if start >= 0:
			return t.substr(start + 1).strip_edges()
	return t.strip_edges()

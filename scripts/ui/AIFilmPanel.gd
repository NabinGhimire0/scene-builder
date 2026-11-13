class_name AIFilmPanel
extends VBoxContainer
## "Make it with AI" in the Script window, using Ollama on this computer:
##  • Write the film: story idea → script → Scene Builder checks it → the AI fixes
##    what didn't work (up to 3 rounds) → the film is built.
##  • Change it: "make the ending longer", "add rain"… rewrites the current script.
##  • Better cameras & music, YouTube title / description / tags, split into episodes.

signal script_ready(text: String)

const MAX_FIX_ROUNDS := 3
const LANGUAGES := {"English": "", "Hindi": "Write all dialogue in Hindi, in Roman letters (Hinglish spelling, e.g. \"Main ghar ja raha hoon\"), not Devanagari.",
	"Nepali": "Write all dialogue in Nepali, in Roman letters (e.g. \"Ma ghar jaadai chhu\"), not Devanagari.",
	"Hindi + English mix": "Write dialogue in casual Hinglish (Hindi and English mixed, Roman letters)."}

var dialog: ScriptDialog
var director: ScriptDirector
var client: OllamaClient

var _status: Label
var _model_pick: OptionButton
var _length: OptionButton
var _language: OptionButton
var _auto_build: CheckBox
var _change: LineEdit
var _buttons: Array = []
var _stop: Button
var _host: LineEdit
var _context: SpinBox

var _job := ""                 # write, change, fix, cameras, youtube, episodes
var _round := 0
var _messages: Array = []
var _streamed := 0
var _result_window: AcceptDialog
var _result_text: TextEdit


func _ready() -> void:
	add_theme_constant_override("separation", 5)
	client = OllamaClient.new()
	add_child(client)
	client.models_listed.connect(_on_models)
	client.token.connect(_on_token)
	client.finished.connect(_on_finished)

	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "Make it with AI (Ollama, on this computer)"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var settings := Button.new()
	settings.text = "⚙"
	settings.tooltip_text = "Ollama address and memory (context) size"
	settings.pressed.connect(_show_settings)
	head.add_child(settings)
	add_child(head)

	var mrow := HBoxContainer.new()
	_model_pick = OptionButton.new()
	_model_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_pick.tooltip_text = "Which installed model writes. For a 6–8 GB graphics card: qwen2.5:7b (best), qwen3:8b or llama3.1:8b."
	_model_pick.item_selected.connect(func(i: int) -> void:
		client.model = _model_pick.get_item_text(i)
		client.save_settings())
	mrow.add_child(_model_pick)
	var refresh := Button.new()
	refresh.text = "Refresh"
	refresh.tooltip_text = "Look for Ollama and its models again"
	refresh.pressed.connect(func() -> void:
		_status.text = "Looking for Ollama…"
		client.list_models())
	mrow.add_child(refresh)
	add_child(mrow)

	var orow := HBoxContainer.new()
	_length = OptionButton.new()
	for l in ["About 1 minute", "About 2 minutes", "About 3 minutes", "About 5 minutes"]:
		_length.add_item(l)
	_length.select(1)
	_length.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orow.add_child(_length)
	_language = OptionButton.new()
	for l in LANGUAGES:
		_language.add_item(l)
	_language.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_language.tooltip_text = "Language of the dialogue"
	orow.add_child(_language)
	add_child(orow)

	var write := _button("✨ Write the film from my idea", "Writes a script from the Story idea above, checks it, fixes problems and builds the film.", _on_write)
	write.custom_minimum_size = Vector2(0, 32)
	add_child(write)
	_auto_build = CheckBox.new()
	_auto_build.text = "Build the film when the script is ready"
	_auto_build.button_pressed = true
	add_child(_auto_build)

	var crow := HBoxContainer.new()
	_change = LineEdit.new()
	_change.placeholder_text = "Change it: e.g. make the ending sadder, add rain"
	_change.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_change.text_submitted.connect(func(_t: String) -> void: _on_change())
	crow.add_child(_change)
	crow.add_child(_button("Change", "Rewrites the script in the editor the way you ask.", _on_change))
	add_child(crow)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_child(_button("Better cameras", "Adds camera shots (close-ups, wide shots, moves) and music to the current script.", _on_cameras))
	grid.add_child(_button("YouTube text", "Title, description and tags for the current film.", _on_youtube))
	grid.add_child(_button("Episodes", "Splits the story idea into a series of short episodes.", _on_episodes))
	grid.add_child(_button("Check picture & fix", "Builds the film, looks at every shot (too dark, burnt out, faces in shadow, heads cut off, words on bright areas) and lets the AI fix the script.", _on_picture))
	for c in grid.get_children():
		(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(grid)

	var srow := HBoxContainer.new()
	_status = Label.new()
	_status.theme_type_variation = &"DimLabel"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.custom_minimum_size = Vector2(200, 0)
	_status.text = "Looking for Ollama…"
	srow.add_child(_status)
	_stop = Button.new()
	_stop.text = "Stop"
	_stop.visible = false
	_stop.pressed.connect(func() -> void:
		client.cancel()
		_job = ""
		_set_busy(false)
		_status.text = "Stopped.")
	srow.add_child(_stop)
	add_child(srow)
	client.list_models.call_deferred()


func _button(text: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(action)
	_buttons.append(b)
	return b


func _process(_delta: float) -> void:
	if client and client.is_busy() and not _job.is_empty():
		var what: String = {"write": "Writing the script", "change": "Changing the script", "fix": "Fixing problems (round %d)" % _round,
			"cameras": "Adding cameras and music", "youtube": "Writing YouTube text", "episodes": "Planning episodes"}.get(_job, "Working")
		_status.text = "%s… %d s · %d words so far" % [what, int(client.seconds()), _streamed]


func _set_busy(on: bool) -> void:
	for b in _buttons:
		(b as Button).disabled = on
	_stop.visible = on


# ------------------------------------------------------------------ models

func _on_models(models: PackedStringArray, error: String) -> void:
	_model_pick.clear()
	if not error.is_empty():
		_status.text = error
		return
	var chosen := -1
	for m in models:
		_model_pick.add_item(m)
		if m == client.model:
			chosen = _model_pick.item_count - 1
	if chosen < 0:
		# the best suggested model that is installed, else the first
		for s in OllamaClient.SUGGESTED:
			for i in _model_pick.item_count:
				if chosen < 0 and _model_pick.get_item_text(i).begins_with(s):
					chosen = i
		chosen = maxi(chosen, 0)
		client.model = _model_pick.get_item_text(chosen)
		client.save_settings()
	_model_pick.select(chosen)
	_status.text = "Ready: %d model%s found. Type a story idea above, then Write." % [models.size(), "" if models.size() == 1 else "s"]


func _ready_to_run() -> bool:
	if client.is_busy():
		return false
	if client.model.is_empty() or _model_pick.item_count == 0:
		_status.text = "No model chosen. Start Ollama, install a model (Command Prompt:  ollama pull qwen2.5:7b), then press Refresh."
		client.list_models()
		return false
	return true


# ------------------------------------------------------------------ jobs

func _rules() -> String:
	var minutes: int = [1, 2, 3, 5][_length.selected]
	var lang: String = LANGUAGES[_language.get_item_text(_language.selected)]
	var extra := PackedStringArray([
		"",
		"## IMPORTANT (read twice)",
		"- The film should last about %d minute%s: about %d scenes, each with 8–20 lines (movement, dialogue, SHOT lines)." % [minutes, "" if minutes == 1 else "s", clampi(minutes * 2, 2, 8)],
		"- Use ONLY locations, places, objects, characters and actions listed above, spelled exactly as listed.",
		"- Every CAST line is: Name = <a listed character>. Every character must be placed (\"Name is at <place>\") before moving.",
		"- Dialogue lines look exactly like:  Name: \"words\"   (one sentence or two, short).",
		"- Start with the REQUIRES line and TITLE. Reply with ONLY the script in one ``` code block, no explanation.",
	])
	if not lang.is_empty():
		extra.append("- " + lang)
	return "\n".join(extra)


func _on_write() -> void:
	if not _ready_to_run():
		return
	dialog.confirm_then(_on_write_go)


func _on_write_go() -> void:
	var idea := dialog.story_text().strip_edges()
	if idea.is_empty():
		_status.text = "Type your story idea in the Story idea box first (who, where, what happens)."
		return
	_round = 0
	_messages = [
		{"role": "system", "content": "You are a film writer for Scene Builder. You write scripts in its exact script format."},
		{"role": "user", "content": AIInstructions.generate(idea) + "\n" + _rules()},
	]
	_run("write")


func _on_change() -> void:
	if not _ready_to_run():
		return
	dialog.confirm_then(_on_change_go)


func _on_change_go() -> void:
	var ask := _change.text.strip_edges()
	if ask.is_empty():
		_status.text = "Type what to change (e.g. \"add rain and a sad ending\")."
		return
	var current := dialog.script_text()
	if current.strip_edges().is_empty():
		_status.text = "There is no script to change yet."
		return
	_round = 0
	_messages = [
		{"role": "system", "content": "You are a film writer for Scene Builder. You write scripts in its exact script format."},
		{"role": "user", "content": AIInstructions.generate("") + "\n" + _rules() + "\n\n## THE CURRENT SCRIPT\n```\n" + current + "\n```\n\n## CHANGE REQUESTED\n" + ask + "\n\nReply with the WHOLE changed script in one code block."},
	]
	_run("change")


func _on_cameras() -> void:
	if not _ready_to_run():
		return
	dialog.confirm_then(_on_cameras_go)


func _on_cameras_go() -> void:
	var current := dialog.script_text()
	if current.strip_edges().is_empty():
		_status.text = "There is no script yet."
		return
	_round = 0
	_messages = [
		{"role": "system", "content": "You are a film director for Scene Builder. You write scripts in its exact script format."},
		{"role": "user", "content": AIInstructions.generate("") + "\n\n## THE CURRENT SCRIPT\n```\n" + current + "\n```\n\n## TASK\nKeep the story, characters and dialogue exactly. Improve the filmmaking: add SHOT lines (establishing shot at the start of each scene, close-ups for emotional lines, over-the-shoulder in conversations, a wide or aerial ending), MUSIC / SOUND lines that suit the mood (only from the sound files listed, if any), TIME / LIGHT / WEATHER changes for mood, and WAIT 1s between emotional beats. Reply with the WHOLE script in one code block."},
	]
	_run("cameras")


func _on_picture() -> void:
	if not _ready_to_run():
		return
	var current := dialog.script_text()
	if current.strip_edges().is_empty():
		_status.text = "There is no script yet."
		return
	var exporter := get_tree().root.find_child("CinematicExportManager", true, false) as ExportManager
	if exporter == null or exporter.is_exporting:
		_status.text = "The film can't be checked while a video is exporting."
		return
	dialog.build_now_from_ai()
	_set_busy(true)
	_job_started = Time.get_ticks_msec()
	_status.text = "Looking at every shot…"
	var found: Array = await FilmCheck.new().run(exporter, func(done: int, total: int) -> void:
		_status.text = "Looking at every shot… %d of %d" % [done, total])
	if found.is_empty():
		_set_busy(false)
		_status.text = "The picture looks good: no dark, burnt-out or badly framed shots found."
		return
	var list := PackedStringArray()
	for f in found:
		var t := float(f["t"])
		list.append("- at %d:%04.1f: %s" % [int(t) / 60, fmod(t, 60.0), str(f["text"])])
	_round = 0
	_messages = [
		{"role": "system", "content": "You are a film director for Scene Builder. You write scripts in its exact script format."},
		{"role": "user", "content": AIInstructions.generate("") + "\n\n## THE CURRENT SCRIPT\n```\n" + current + "\n```\n\n## WHAT THE FINISHED PICTURE LOOKS LIKE\nScene Builder built this script and looked at every shot. It found:\n" + "\n".join(list) \
			+ "\n\n## TASK\nFix these in the script. Dark shots: raise LIGHT: exposure (1.2 to 1.5) or set an earlier TIME. Burnt-out shots: lower exposure or bloom, or point the SHOT away from the sun. Faces in shadow: turn the person or film them from the other side. Cut-off heads: use a wider SHOT. Words on bright areas: move the CINEMATIC line to a darker moment. Keep the story, characters and dialogue. Reply with the WHOLE script in one code block."},
	]
	_run("picture")


func _on_youtube() -> void:
	if not _ready_to_run():
		return
	var current := dialog.script_text()
	if current.strip_edges().is_empty():
		_status.text = "There is no script yet."
		return
	var lang := _language.get_item_text(_language.selected)
	_messages = [
		{"role": "system", "content": "You write YouTube titles, descriptions and tags that are honest, warm and clickable without being clickbait."},
		{"role": "user", "content": "Here is the script of a short animated film:\n```\n" + current + "\n```\nWrite, for YouTube (audience language: %s):\nTITLE: (under 70 characters)\n3 OTHER TITLE IDEAS:\nDESCRIPTION: (3 short paragraphs: the story without spoilers, what viewers will feel, a call to subscribe)\nTAGS: (15 comma-separated tags)\nHASHTAGS: (5)\nTHUMBNAIL IDEA: (one sentence)" % lang},
	]
	_run("youtube")


func _on_episodes() -> void:
	if not _ready_to_run():
		return
	var idea := dialog.story_text().strip_edges()
	if idea.is_empty():
		idea = dialog.script_text().strip_edges()
	if idea.is_empty():
		_status.text = "Type the big story in the Story idea box first."
		return
	_messages = [
		{"role": "system", "content": "You plan short animated web series."},
		{"role": "user", "content": "Split this story into 5 to 8 short episodes (1–3 minutes each) for a YouTube series. For each episode give: EPISODE n: title, then a 2–3 sentence story idea that could be typed into a film maker on its own (who, where, what happens, how it ends with a hook for the next one). Keep the same characters throughout.\n\nSTORY:\n" + idea},
	]
	_run("episodes")


var _job_started := 0

func _run(job: String) -> void:
	_job_started = Time.get_ticks_msec()
	_job = job
	_streamed = 0
	_set_busy(true)
	client.chat(_messages)


func _on_token(piece: String) -> void:
	_streamed += piece.split(" ", false).size()


func _on_finished(text: String, error: String) -> void:
	var job := _job
	if job.is_empty():
		return
	if not error.is_empty():
		_job = ""
		_set_busy(false)
		_status.text = error
		return
	match job:
		"youtube", "episodes":
			_job = ""
			_set_busy(false)
			_show_result("YouTube text" if job == "youtube" else "Episodes", OllamaClient._strip_thinking(text))
			_status.text = "Done in %d s." % int((Time.get_ticks_msec() - _job_started) / 1000.0)
		_:
			var script := OllamaClient.extract_script(text)
			_messages.append({"role": "assistant", "content": "```\n" + script + "\n```"})
			dialog.set_script_text(script)
			_check(script)


## Builds the script quietly to see what Scene Builder couldn't understand; asks the AI to fix it.
func _check(script: String) -> void:
	if not script.to_upper().contains("SCENE") and not script.contains(":"):
		_ask_fix(["The reply was not a Scene Builder script. Write the script in the exact format, in one code block."])
		return
	var report := dialog.quiet_check(script)
	var problems: Array = []
	for m in report.get("missing", []):
		problems.append("Missing (not in Scene Builder): %s — use a listed one instead." % str(m))
	for sub in report.get("subs", []):
		if str(sub).to_lower().contains("placeholder"):
			problems.append("Not found, a placeholder was used: %s — use a listed one instead." % str(sub))
	for w in report.get("warnings", []):
		var line := str(w)
		if line.contains("needs a newer") or line.contains("written for"):
			continue
		problems.append(line)
	var counts: Dictionary = report.get("counts", {})
	if int(counts.get("characters", 0)) == 0:
		problems.append("No characters were created: the CAST section needs lines like  Mira = woman casual  (names from the CHARACTERS list).")
	if float(report.get("length", 0.0)) < 15.0:
		problems.append("The film is only %.0f seconds long: write more scenes, movement and dialogue." % float(report.get("length", 0.0)))
	if problems.is_empty() or _round >= MAX_FIX_ROUNDS:
		_done(report, problems)
		return
	_ask_fix(problems)


func _ask_fix(problems: Array) -> void:
	_round += 1
	var list := PackedStringArray()
	for i in mini(problems.size(), 20):
		list.append("- " + str(problems[i]))
	_messages.append({"role": "user", "content": "Scene Builder built your script but found these problems:\n" + "\n".join(list) + "\n\nFix ALL of them. Use only the names listed in the instructions. Keep the story. Reply with the WHOLE corrected script in one code block."})
	_job = "fix"
	_streamed = 0
	client.chat(_messages)


func _done(report: Dictionary, problems: Array) -> void:
	_job = ""
	_set_busy(false)
	var note := "Script ready in %d s (%.0f s film" % [int((Time.get_ticks_msec() - _job_started) / 1000.0), float(report.get("length", 0.0))]
	note += ", checked and fixed %d time%s)." % [_round, "" if _round == 1 else "s"] if _round > 0 else ")."
	if not problems.is_empty():
		note += " %d small problem%s left — see the build report." % [problems.size(), "" if problems.size() == 1 else "s"]
	_status.text = note
	script_ready.emit(dialog.script_text())
	if _auto_build.button_pressed:
		dialog.build_now_from_ai()


func _show_result(title: String, text: String) -> void:
	if _result_window == null:
		_result_window = AcceptDialog.new()
		_result_window.min_size = Vector2i(640, 480)
		_result_text = TextEdit.new()
		_result_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		_result_window.add_child(_result_text)
		_result_window.add_button("Copy all", true, "copy")
		_result_window.custom_action.connect(func(a: StringName) -> void:
			if a == &"copy":
				DisplayServer.clipboard_set(_result_text.text)
				EventBus.info("Copied."))
		_result_window.ok_button_text = "Close"
		add_child(_result_window)
	_result_window.title = title
	_result_text.text = text
	_result_window.popup_centered(Vector2i(700, 520))


func _show_settings() -> void:
	var d := AcceptDialog.new()
	d.title = "Ollama settings"
	var box := VBoxContainer.new()
	d.add_child(box)
	var l1 := Label.new()
	l1.text = "Ollama address (normally http://127.0.0.1:11434)"
	box.add_child(l1)
	_host = LineEdit.new()
	_host.text = client.host
	box.add_child(_host)
	var l2 := Label.new()
	l2.text = "Memory for the AI (context, tokens). 16384 suits 6 GB graphics cards; lower it if Ollama runs out of memory."
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.custom_minimum_size = Vector2(420, 0)
	box.add_child(l2)
	_context = SpinBox.new()
	_context.min_value = 4096
	_context.max_value = 65536
	_context.step = 1024
	_context.value = client.context
	box.add_child(_context)
	d.confirmed.connect(func() -> void:
		client.host = _host.text.strip_edges() if not _host.text.strip_edges().is_empty() else OllamaClient.DEFAULT_HOST
		client.context = int(_context.value)
		client.save_settings()
		client.list_models()
		d.queue_free())
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered(Vector2i(480, 220))

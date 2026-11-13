class_name ScriptDialog
extends Window
## "Script" window: write, paste or open a film script (or a whole film
## package), build the film from it in one click, and copy the instructions an
## AI needs to write such scripts.

const DRAFT_FILE := "user://script_draft.script"
const EXAMPLE_FILE := "res://assets/scripts/the_promise.script"
const KEYWORDS: PackedStringArray = ["TITLE", "LOCATION", "TIME", "WEATHER", "MUSIC", "LENGTH", "SKY", "LIGHT", "CAMERA",
	"SUBTITLES", "CAST", "SET", "SCENE", "SHOT", "CAPTION", "LOWER THIRD", "SUBTITLE", "WAIT", "PAUSE", "AT", "SOUND", "CUT TO"]

var director: ScriptDirector
var timeline: TimelineController
## Callable(title: String, then: Callable): asks before discarding unsaved work.
var guard: Callable

var _editor: CodeEdit
var _story: TextEdit
var _report: RichTextLabel
var _package_label: Label
var _watch: Button
var _speak: CheckBox
var _open_dialog: FileDialog
var _folder_dialog: FileDialog
var _save_dialog: FileDialog
var _package_dir := ""
var _library_choice: ConfirmationDialog
var _library_full: CheckBox
var _library_dialog: FileDialog
var _exporting := false


func _ready() -> void:
	title = "Film Script"
	min_size = Vector2i(760, 480)
	wrap_controls = false
	transient = true
	visible = false
	close_requested.connect(hide)
	_build()


func open() -> void:
	if _editor.text.strip_edges().is_empty():
		var draft := FileAccess.get_file_as_string(DRAFT_FILE)
		_editor.text = draft if not draft.strip_edges().is_empty() else FileAccess.get_file_as_string(EXAMPLE_FILE)
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	popup_centered(Vector2i(mini(1180, screen.x - 40), mini(760, screen.y - 80)))


# --- Layout ------------------------------------------------------------------------

func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	root.add_child(bar)
	var open_menu := MenuButton.new()
	open_menu.text = "Open…"
	open_menu.flat = false
	open_menu.tooltip_text = "Open a script file, a film package (.zip) or a package folder"
	open_menu.get_popup().add_item("Script or package (.script, .txt, .json, .zip)…", 0)
	open_menu.get_popup().add_item("Package folder…", 1)
	open_menu.get_popup().id_pressed.connect(_on_open_menu)
	bar.add_child(open_menu)
	bar.add_child(_button("Paste", "Replace the script with what's on the clipboard (e.g. copied from an AI chat)", _on_paste))
	bar.add_child(_button("Example", "Load the example film script", _on_example))
	bar.add_child(_button("Save Script…", "Save this script to a file", func() -> void: _save_dialog.popup_centered_ratio(0.6)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	bar.add_child(_button("Export My Library…", "Save one .zip describing your own characters, props, animations and sounds (with pictures), to give to an AI so it can make films with YOUR things", _on_export_library))
	bar.add_child(_button("Copy AI Instructions", "Copy instructions (with everything installed in Scene Builder) to paste into Claude or ChatGPT, followed by your story idea", _on_copy_instructions))

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	_editor = CodeEdit.new()
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor.custom_minimum_size = Vector2(420, 200)
	_editor.gutters_draw_line_numbers = true
	_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_editor.placeholder_text = "Write or paste a film script here, or press Example.\n\nTITLE: …\nLOCATION: Forest Lake\nCAST:\nMira = woman casual\nSCENE 1: …\nMira walks to campfire\nMira: \"Hello!\""
	_editor.syntax_highlighter = _highlighter()
	split.add_child(_editor)

	var side_box := VBoxContainer.new()
	side_box.custom_minimum_size = Vector2(300, 0)
	side_box.add_theme_constant_override("separation", 6)
	split.add_child(side_box)
	var story_label := Label.new()
	story_label.text = "Story idea (added to the AI instructions)"
	story_label.theme_type_variation = &"DimLabel"
	side_box.add_child(story_label)
	_story = TextEdit.new()
	_story.custom_minimum_size = Vector2(0, 90)
	_story.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_story.placeholder_text = "e.g. A 45-second film: two friends meet at a rainy bus stop at night and share an umbrella."
	side_box.add_child(_story)
	var ai := AIFilmPanel.new()
	ai.dialog = self
	ai.director = director
	side_box.add_child(ai)
	side_box.add_child(HSeparator.new())
	var report_label := Label.new()
	report_label.text = "Build report"
	report_label.theme_type_variation = &"DimLabel"
	side_box.add_child(report_label)
	_report = RichTextLabel.new()
	_report.bbcode_enabled = true
	_report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_report.selection_enabled = true
	_report.text = "[color=#a0a0a0]How it works:\n1. Press Copy AI Instructions, paste them into an AI chat with your story idea.\n2. Copy the AI's script, press Paste here.\n3. Press Build Film, then Watch.\n\nOr open a film package (.zip or folder) that includes its own models, characters, animations and audio.[/color]"
	side_box.add_child(_report)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	_package_label = Label.new()
	_package_label.theme_type_variation = &"DimLabel"
	_package_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_package_label.clip_text = true
	bottom.add_child(_package_label)
	_update_package_label()
	_speak = CheckBox.new()
	var voices := SpeechMaker.engine_title()
	_speak.text = "Speak dialogue" if not voices.is_empty() else "Speak dialogue (no voices found)"
	_speak.disabled = voices.is_empty()
	_speak.tooltip_text = ("Give every line without a recording an automatic voice (%s). Characters get fitting voices; set one in CAST with e.g. \"voice female\", \"voice child\", \"voice deep\"." % voices) if not voices.is_empty() \
		else "No speech engine found on this computer (Windows and macOS have one built in; on Linux install espeak-ng)."
	bottom.add_child(_speak)
	var build := _button("▶ Build Film", "Build the whole film from this script (replaces the current scene)", _on_build)
	build.custom_minimum_size = Vector2(150, 34)
	bottom.add_child(build)
	_watch = _button("Watch", "Play the film through its cameras", _on_watch)
	_watch.disabled = true
	bottom.add_child(_watch)

	_open_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "Open Script or Film Package",
		["*.script, *.film, *.txt, *.json ; Film scripts", "*.zip ; Film packages"])
	_open_dialog.file_selected.connect(_on_open)
	_folder_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_DIR, "Open Film Package Folder", [])
	_folder_dialog.dir_selected.connect(_on_open)
	_save_dialog = _file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Save Script", ["*.script ; Film scripts"])
	_save_dialog.file_selected.connect(_on_save)


func _highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = Color(0.7, 0.85, 1.0)
	h.symbol_color = Color(0.75, 0.75, 0.75)
	h.function_color = Color(0.9, 0.9, 0.9)
	h.member_variable_color = Color(0.9, 0.9, 0.9)
	for word in KEYWORDS:
		for part in word.split(" "):
			h.add_keyword_color(part, Color(1.0, 0.62, 0.15))
	h.add_color_region("\"", "\"", Color(0.6, 0.9, 0.6))
	h.add_color_region("#", "", Color(0.5, 0.5, 0.5), true)
	h.add_color_region("[", "]", Color(0.75, 0.65, 1.0))
	return h


func _button(text: String, tip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.pressed.connect(action)
	return button


func _build_library_export() -> void:
	_library_choice = ConfirmationDialog.new()
	_library_choice.title = "Export My Library"
	_library_choice.ok_button_text = "Choose Where to Save…"
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	var about := Label.new()
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(520, 0)
	about.text = "Makes one .zip that describes your own characters, props, animation packs and sounds, with a picture of each and the exact names to use in a film script. Give it to Claude (or another AI) together with your story idea, and it can write a film package starring your characters in sets made of your props."
	box.add_child(about)
	var list_only := CheckBox.new()
	list_only.text = "List only (small, recommended): names, sizes, actions and pictures"
	list_only.button_pressed = true
	box.add_child(list_only)
	_library_full = CheckBox.new()
	_library_full.text = "Include files: also the 3D models (textures shrunk), so the AI can build and test the film itself"
	box.add_child(_library_full)
	var group := ButtonGroup.new()
	list_only.button_group = group
	_library_full.button_group = group
	var note := Label.new()
	note.theme_type_variation = &"DimLabel"
	note.text = "Photos used for avatar faces are never included."
	box.add_child(note)
	_library_choice.add_child(box)
	_library_choice.confirmed.connect(func() -> void:
		_library_dialog.current_file = "my_scene_builder_library%s.zip" % ("_full" if _library_full.button_pressed else "")
		_library_dialog.popup_centered_ratio(0.6))
	add_child(_library_choice)
	_library_dialog = _file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Save the library export", ["*.zip ; Zip file"])
	_library_dialog.file_selected.connect(_export_library_to)


func _on_export_library() -> void:
	if _exporting:
		return
	if _library_choice == null:
		_build_library_export()
	_library_choice.popup_centered(Vector2i(560, 0))
	_library_choice.size = Vector2i(560, 0)
	_library_choice.reset_size()


func _export_library_to(path: String) -> void:
	if not path.get_extension().to_lower() == "zip":
		path += ".zip"
	_exporting = true
	var exporter := LibraryExporter.new()
	add_child(exporter)
	exporter.progress.connect(func(text: String) -> void: _report.text = "[color=#a0a0a0]%s[/color]" % text)
	var result: Dictionary = await exporter.export_library(path, _library_full.button_pressed)
	exporter.queue_free()
	_exporting = false
	if not bool(result.get("ok", false)):
		_report.text = "[color=#ff8a80]%s[/color]" % str(result.get("error", "Export failed."))
		return
	var size_mb := float(result["bytes"]) / 1048576.0
	_report.text = ("[color=#8fd18f]Library exported:[/color] %s (%.1f MB)\n%d characters, %d props, %d animation packs, %d sounds%s.\n\n"
		+ "Give this .zip to Claude with your story idea, e.g. \"Make a 2-minute comedy film package with my characters and props.\" "
		+ "The package it makes uses your things by name: [code]my character \"…\"[/code], [code]my prop \"…\"[/code].") % [
		path.get_file(), size_mb, result["characters"], result["props"], result["packs"], result["sounds"],
		", model files included" if _library_full.button_pressed else ""]
	if size_mb > 30.0:
		_report.text += "\n[color=#ffcc80]It's large; if it's too big to upload, export \"List only\" instead.[/color]"


func _file_dialog(mode: FileDialog.FileMode, dialog_title: String, filters: Array) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.title = dialog_title
	dialog.filters = PackedStringArray(filters)
	dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if "use_native_dialog" in dialog:
		dialog.set("use_native_dialog", true)
	add_child(dialog)
	return dialog


# --- Actions -----------------------------------------------------------------------

func _on_open_menu(id: int) -> void:
	if id == 0:
		_open_dialog.popup_centered_ratio(0.6)
	else:
		_folder_dialog.popup_centered_ratio(0.6)


# --- For the AI panel ----------------------------------------------------------------

func story_text() -> String:
	return _story.text


func script_text() -> String:
	return _editor.text


func set_script_text(text: String) -> void:
	_editor.text = text
	_package_dir = ""
	_update_package_label()


## Builds [param text] without voices, to see what Scene Builder understood.
func quiet_check(text: String) -> Dictionary:
	director.speak_dialogue = -1
	var report := director.build_from_text(text, _package_dir)
	_show_report(report)
	_watch.disabled = false
	return report


## The final build after the AI has finished (voices as chosen below).
func build_now_from_ai() -> void:
	_build_now()


## Asks before the AI replaces the current scene (if it has unsaved work).
func confirm_then(then: Callable) -> void:
	if guard.is_valid():
		guard.call("The AI will build a new film and replace the current scene. Continue?", then)
	else:
		then.call()


func _on_example() -> void:
	_editor.text = FileAccess.get_file_as_string(EXAMPLE_FILE)
	_package_dir = ""
	_update_package_label()


func _on_paste() -> void:
	var text := DisplayServer.clipboard_get()
	if text.strip_edges().is_empty():
		EventBus.info("The clipboard is empty. Copy the script from the AI chat first.")
		return
	# AI replies often wrap the script in a ``` code block.
	var fence := text.find("```")
	if fence >= 0:
		var start := text.find("\n", fence)
		var end := text.find("```", start)
		if start >= 0 and end > start:
			text = text.substr(start + 1, end - start - 1)
	_editor.text = text.strip_edges()
	_package_dir = ""
	_update_package_label()


func _on_copy_instructions() -> void:
	DisplayServer.clipboard_set(AIInstructions.generate(_story.text))
	_report.text = "[color=#8fd18f]AI instructions copied.[/color]\nPaste them into Claude or ChatGPT (they include your story idea, if you typed one). When the AI replies with a script, copy it and press [b]Paste[/b], then [b]Build Film[/b]."


func _on_open(path: String) -> void:
	var package := FilmPackage.open(path)
	if not str(package.get("error", "")).is_empty():
		_report.text = "[color=#ff8a80]%s[/color]" % str(package["error"])
		return
	_editor.text = str(package["text"])
	_package_dir = str(package["dir"])
	_update_package_label()
	_report.text = "Opened [b]%s[/b]. Press Build Film." % str(package["script"]).get_file()


func _on_save(path: String) -> void:
	if path.get_extension().is_empty():
		path += ".script"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		EventBus.error("Couldn't save %s." % path.get_file())
		return
	file.store_string(_editor.text)
	file.close()
	EventBus.info("Script saved: %s" % path.get_file())


func _on_build() -> void:
	if _editor.text.strip_edges().is_empty():
		_report.text = "[color=#ff8a80]The script is empty.[/color]"
		return
	if guard.is_valid():
		guard.call("Build the film from this script?", _build_now)
	else:
		_build_now()


func _build_now() -> void:
	var draft := FileAccess.open(DRAFT_FILE, FileAccess.WRITE)
	if draft:
		draft.store_string(_editor.text)
		draft.close()
	director.speak_dialogue = 1 if _speak.button_pressed else -1
	if _speak.button_pressed:
		EventBus.info("Recording automatic voices… (the first build takes a little longer)")
	var report := director.build_from_text(_editor.text, _package_dir)
	_show_report(report)
	_watch.disabled = false
	EventBus.info("Film built from the script: %.1f s. Press Watch or Play Cinematic." % float(report.get("length", 0.0)))


func _on_watch() -> void:
	hide()
	if timeline:
		timeline.set_time(0.0)
		timeline.play_cinematic()


func _show_report(report: Dictionary) -> void:
	var out: PackedStringArray = []
	var counts: Dictionary = report.get("counts", {})
	if bool(report.get("outdated", false)):
		out.append("[b][color=#ff8a80]⚠ This film needs a newer Scene Builder (see Notes).[/color][/b]")
	out.append("[b]Film ready: %.1f seconds[/b]" % float(report.get("length", 0.0)))
	out.append("✅ %d character%s · %d set piece%s · %d shot%s" % [int(counts.get("characters", 0)), "" if int(counts.get("characters", 0)) == 1 else "s",
		int(counts.get("props", 0)), "" if int(counts.get("props", 0)) == 1 else "s", int(report.get("shots", 0)), "" if int(report.get("shots", 0)) == 1 else "s"])
	for line in report.get("info", []):
		out.append("• " + str(line))
	if not (report.get("scenes", []) as Array).is_empty():
		out.append("\n[b]Scenes[/b]")
		for line in report["scenes"]:
			out.append("• " + str(line))
	if not (report.get("imported", []) as Array).is_empty():
		out.append("\n[b]⬇️ From the package[/b]")
		out.append(", ".join(PackedStringArray(report["imported"])))
	if not (report.get("subs", []) as Array).is_empty():
		out.append("\n[b][color=#ffd27f]🔧 Replaced with the closest match[/color][/b]")
		for line in report["subs"]:
			out.append("• " + str(line))
	if not (report.get("missing", []) as Array).is_empty():
		out.append("\n[b][color=#ff8a80]📋 Missing: get these, then build again[/color][/b]")
		for line in report["missing"]:
			out.append("• " + str(line))
		out.append("[color=#a0a0a0]Import models with Assets → Import, download them from Online, or put them in the package folder.[/color]")
	if not (report.get("warnings", []) as Array).is_empty():
		out.append("\n[b][color=#ffd27f]⚠️ Notes[/color][/b]")
		for line in report["warnings"]:
			out.append("• " + str(line))
	out.append("\n[color=#a0a0a0]Everything is normal scene content now: tweak cameras, keys and titles, then Save. Building again replaces it.[/color]")
	_report.text = "\n".join(out)


func _update_package_label() -> void:
	_package_label.text = "Package: %s" % _package_dir if not _package_dir.is_empty() else "No package: files are looked up in your library"

class_name TitleOverlay
extends Control
## Draws the [TitleTrack] text over a viewport, inside the film frame: titles,
## captions, lower thirds, subtitles, and the Flat sketch extras: whispers that
## float next to a character, a counter in the corner, and phone close-ups.

const HAND_FONT := preload("res://assets/fonts/PatrickHand-Regular.ttf")
const COMIC_FONT := preload("res://assets/fonts/ComicNeue-Bold.ttf")
const SERIF_FONT := preload("res://assets/fonts/EBGaramond-Regular.ttf")

var track: TitleTrack
var _environment: EnvironmentController
var _pal: Dictionary = {}     # colours of the current flat look (empty when realistic)
static var _vignette: GradientTexture2D
static var _glow: GradientTexture2D
var _split_views: Array = []   # [{ "viewport": SubViewport, "camera": Camera3D }] for SPLIT lines


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	_update_split()
	queue_redraw()


## The film's frame inside this control (letterboxed to the film's aspect).
func _film_frame() -> Rect2:
	var area := get_viewport_rect().size
	var aspect := track.film_aspect() if track else 16.0 / 9.0
	if area.x / maxf(area.y, 1.0) > aspect:
		var w := area.y * aspect
		return Rect2((area.x - w) * 0.5, 0.0, w, area.y)
	var h := area.x / aspect
	return Rect2(0.0, (area.y - h) * 0.5, area.x, h)


func _flat() -> bool:
	if _environment == null or not is_instance_valid(_environment):
		_environment = get_tree().get_first_node_in_group(&"environment_controller") as EnvironmentController
	return _environment != null and _environment.is_flat()


func _draw() -> void:
	if track == null:
		return
	var area := get_viewport_rect().size
	var aspect := track.film_aspect()
	var frame := Rect2(Vector2.ZERO, area)
	if area.x / maxf(area.y, 1.0) > aspect:
		var w := area.y * aspect
		frame = Rect2((area.x - w) * 0.5, 0.0, w, area.y)
	else:
		var h := area.x / aspect
		frame = Rect2(0.0, (area.y - h) * 0.5, area.x, h)
	var flat := _flat()
	_pal = _environment.flat_palette() if flat else {}
	if flat:
		draw_texture_rect(_vignette_texture(), frame, false, _pal["vignette"])
	var shown := track.visible_at(track.current_time())
	_speech_spots.clear()
	if shown.is_empty():
		return
	var font: Font = COMIC_FONT if flat else ThemeDB.fallback_font
	# Phones first (they fill the frame), then everything else on top.
	var full_screen := ["Vignette", "Quote", "Letterbox", "Split", "Phone", "Note", "Calendar"]
	shown.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]["style"]) in full_screen and not str(b[0]["style"]) in full_screen)
	var splitting := false
	for pair in shown:
		if str(pair[0]["style"]) == "Split":
			splitting = true
	for pair in shown:
		var item: Dictionary = pair[0]
		var alpha: float = pair[1]
		if splitting and str(item["style"]) == "Counter":
			continue  # the split's labels sit where the counter is
		match str(item["style"]):
			"Whisper":
				_draw_whisper(frame, item, alpha)
			"Counter":
				var counter_text := str(item["text"])
				if item.has("live"):
					var live: Dictionary = item["live"]
					var since := float(live.get("since", 0.0))
					var amount := maxf(track.current_time() - since, 0.0) * float(live.get("rate", 0.0))
					counter_text = counter_text.replace("{n}", format_number(amount, 0))
				_draw_counter(frame, counter_text, alpha)
			"Phone":
				_draw_phone(frame, item, alpha)
			"Note":
				_draw_note(frame, item, alpha)
			"Calendar":
				_draw_calendar(frame, item, alpha)
			"Words":
				_draw_words(frame, item, alpha)
			"Post":
				_draw_post(frame, item, alpha)
			"Number":
				_draw_number(frame, item, alpha)
			"Split":
				_draw_split(frame, item, alpha)
			"Letterbox":
				_draw_letterbox(frame, alpha)
			"Hero", "Cinematic":
				_draw_cinematic(font, frame, item, alpha)
			"Speech":
				_draw_speech(frame, item, alpha)
			"Vignette":
				draw_texture_rect(_vignette_texture(), frame, false, Color(0.0, 0.0, 0.01, float(item.get("strength", 0.55)) * alpha))
			"Quote":
				_draw_quote(frame, item, alpha)
			"Timecard":
				_draw_timecard(frame, item, alpha)
			_:
				_draw_item(font, frame, str(item["text"]), str(item["style"]), alpha)


## Wide-screen black bars (2.39:1), the classic movie-trailer frame.
func _draw_letterbox(frame: Rect2, alpha: float) -> void:
	var bar := maxf((frame.size.y - frame.size.x / 2.39) * 0.5, 0.0)
	if bar <= 0.5:
		return
	var c := Color(0, 0, 0, alpha)
	draw_rect(Rect2(frame.position, Vector2(frame.size.x, bar)), c)
	draw_rect(Rect2(frame.position + Vector2(0, frame.size.y - bar), Vector2(frame.size.x, bar)), c)


## Trailer text: no box, widely spaced letters with a warm glow that slowly grows.
## "Hero" is the big one-word title, "Cinematic" the lines between.
func _draw_cinematic(font: Font, frame: Rect2, item: Dictionary, alpha: float) -> void:
	var hero := str(item["style"]) == "Hero"
	var length := maxf(float(item.get("length", 1.0)), 0.01)
	var p := clampf((track.current_time() - float(item.get("start", 0.0))) / length, 0.0, 1.0)
	var h := frame.size.y
	var font_size := int(h * (0.15 if hero else 0.062) * (1.0 + (0.08 if hero else 0.035) * p))
	var text := str(item["text"])
	if hero:
		var spaced := PackedStringArray()
		for line in text.split("\n"):
			var letters := PackedStringArray()
			for i in line.length():
				letters.append(line[i])
			spaced.append("\u2009".join(letters))
		text = "\n".join(spaced)
	var lines := wrap_lines(font, text, font_size, frame.size.x * 0.86)
	var line_height := font_size * 1.3
	var y := frame.position.y + h * 0.5 - line_height * (lines.size() - 1) * 0.5 + font_size * 0.35
	# A soft, wide shadow behind the words (no visible box): keeps them readable on
	# bright skies, light rays and sparks, and is barely noticeable on dark shots.
	var widest := 0.0
	for line in lines:
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var radii := Vector2(widest * 0.62 + font_size * 1.6, line_height * lines.size() * 0.5 + font_size * 0.9)
	_soft_scrim(frame.get_center(), radii, (0.3 if hero else 0.36) * alpha)
	var glow := Color(1.0, 0.72, 0.38)
	for line in lines:
		var pos := Vector2(frame.position.x, y)
		# a soft dark halo keeps it readable on bright skies and sparks, then a warm glow
		for r in [font_size / 2, font_size / 3, font_size / 5]:
			draw_string_outline(font, pos, line, HORIZONTAL_ALIGNMENT_CENTER, frame.size.x, font_size, maxi(2, int(r)), Color(0.0, 0.0, 0.02, 0.13 * alpha))
		draw_string_outline(font, pos, line, HORIZONTAL_ALIGNMENT_CENTER, frame.size.x, font_size, maxi(2, font_size / 9), Color(glow.r, glow.g, glow.b, 0.22 * alpha))
		draw_string_outline(font, pos, line, HORIZONTAL_ALIGNMENT_CENTER, frame.size.x, font_size, maxi(2, font_size / 18), Color(0.05, 0.03, 0.02, 0.75 * alpha))
		draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_CENTER, frame.size.x, font_size, Color(1.0, 0.97, 0.92, alpha))
		y += line_height


## A dark elliptical shadow fading out to nothing at its edge.
func _soft_scrim(centre: Vector2, radii: Vector2, strength: float) -> void:
	if strength <= 0.001:
		return
	var steps := 40
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	for i in steps + 1:
		var a := TAU * float(i) / float(steps)
		var d := Vector2(cos(a), sin(a))
		inner.append(centre + d * radii * 0.55)
		outer.append(centre + d * radii)
	var dark := Color(0.0, 0.0, 0.02, strength)
	var clear := Color(0.0, 0.0, 0.02, 0.0)
	# solid core, then a fading ring
	var core := PackedVector2Array(inner)
	core.remove_at(core.size() - 1)
	draw_colored_polygon(core, dark)
	for i in steps:
		draw_polygon(PackedVector2Array([inner[i], outer[i], outer[i + 1], inner[i + 1]]),
			PackedColorArray([dark, clear, clear, dark]))


func _draw_item(font: Font, frame: Rect2, text: String, style: String, alpha: float) -> void:
	var h := frame.size.y
	var font_size := int(h * (0.075 if style == "Title" else (0.042 if style == "Caption (top)" else 0.05)))
	var line_height := font_size * 1.25
	# Always readable, on any picture: white letters with a dark edge, on a soft dark box.
	var white := Color(1, 1, 1, alpha)
	var outline := Color(0.03, 0.03, 0.05, 0.95 * alpha)
	var width := frame.size.x * 0.9
	# Long lines wrap (never run off the frame), and the box grows to fit.
	var limit := frame.size.x * (0.8 if style == "Title" else 0.84)
	var lines := wrap_lines(font, text, font_size, limit)
	if style != "Lower third":
		var widest := 0.0
		for line in lines:
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		widest = minf(widest, width)
		var block_h := line_height * lines.size()
		var top := 0.0
		match style:
			"Title":
				top = frame.position.y + h * 0.5 - block_h * 0.5
			"Caption (top)":
				top = frame.position.y + h * 0.1 + font_size - font_size * 0.95
			_:
				top = frame.position.y + h * 0.9 - line_height * (lines.size() - 1) - font_size * 0.95
		var pad := font_size * 0.5
		var box := Rect2(frame.get_center().x - widest * 0.5 - pad, top - pad * 0.45, widest + pad * 2.0, block_h + pad * 0.7)
		_round_box(box, Color(0.02, 0.02, 0.04, (0.42 if style == "Title" else 0.55) * alpha), font_size * 0.45)
	var y := 0.0
	match style:
		"Title":
			y = frame.position.y + h * 0.5 - line_height * (lines.size() - 1) * 0.5 + font_size * 0.35
		"Caption (top)":
			y = frame.position.y + h * 0.1 + font_size
		"Lower third":
			var bar_h := line_height * lines.size() + font_size * 0.6
			var bar := Rect2(frame.position.x + frame.size.x * 0.05, frame.position.y + h * 0.78 - bar_h * 0.5, frame.size.x * 0.45, bar_h)
			draw_rect(bar, Color(0.05, 0.06, 0.08, 0.65 * alpha))
			draw_rect(Rect2(bar.position, Vector2(font_size * 0.18, bar.size.y)), Color(1.0, 0.62, 0.15, alpha))
			y = bar.position.y + font_size * 0.3 + font_size
			for line in lines:
				draw_string_outline(font, Vector2(bar.position.x + font_size * 0.6, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(2, font_size / 10), outline)
				draw_string(font, Vector2(bar.position.x + font_size * 0.6, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, white)
				y += line_height
			return
		_:
			y = frame.position.y + h * 0.9 - line_height * (lines.size() - 1)
	for line in lines:
		var pos := Vector2(frame.position.x + frame.size.x * 0.05, y)
		draw_string_outline(font, pos, line, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, maxi(3, font_size / 6), outline)
		draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, white)
		y += line_height


## [param text] broken into lines no wider than [param limit] (its own line breaks kept),
## balanced so a two-line subtitle doesn't leave one word alone on the second line.
static func wrap_lines(font: Font, text: String, font_size: int, limit: float) -> PackedStringArray:
	var out := PackedStringArray()
	for paragraph in text.split("\n"):
		if font.get_string_size(paragraph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= limit:
			out.append(paragraph)
			continue
		var words := paragraph.split(" ", false)
		var total := font.get_string_size(paragraph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var rows := int(ceil(total / limit))
		var target := minf(limit, total / float(rows) * 1.08)
		var line := ""
		for word in words:
			var test := word if line.is_empty() else line + " " + word
			if not line.is_empty() and font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > target:
				out.append(line)
				line = word
			else:
				line = test
		if not line.is_empty():
			out.append(line)
	return out


# --- Flat sketch extras --------------------------------------------------------

## Handwritten words next to the speaker's head, softly glowing in their colour.
func _draw_whisper(frame: Rect2, item: Dictionary, alpha: float) -> void:
	var c: Array = item.get("color", [1.0, 0.4, 0.3])
	var color := Color(float(c[0]), float(c[1]), float(c[2]), alpha)
	var font_size := int(frame.size.y * 0.068)
	var text := str(item["text"])
	var width := HAND_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(frame.position.x + frame.size.x * 0.5 - width * 0.5, frame.position.y + frame.size.y * 0.2)
	var node := track.anchor_node(str(item.get("anchor", "")))
	var camera := get_viewport().get_camera_3d()
	if node and camera and node.is_inside_tree():
		var head := node.global_position + Vector3(0, 1.6, 0)
		var radius := 0.25
		if node is CharacterBase:
			var joint := (node as CharacterBase).joint_position("Head")
			radius = 0.25 * (node as CharacterBase).size_factor()
			if joint.is_finite():
				head = joint
		if not camera.is_position_behind(head):
			var centre := camera.unproject_position(head)
			var top := camera.unproject_position(head + Vector3(0, radius * 1.65, 0))
			var head_px := absf(centre.y - top.y)
			if top.y - font_size * 0.6 > frame.position.y + font_size * 1.2:
				# Room above the head: float there.
				at = Vector2(centre.x - width * 0.5, top.y - font_size * 0.6)
			else:
				# A close-up: put the words beside the head, on the emptier side.
				var right := centre.x < frame.get_center().x
				at.y = centre.y - head_px * 0.4
				at.x = centre.x + head_px * 1.1 if right else centre.x - head_px * 1.1 - width
	at.x = clampf(at.x, frame.position.x + font_size * 0.4, frame.end.x - width - font_size * 0.4)
	at.y = clampf(at.y, frame.position.y + font_size * 1.2, frame.end.y - font_size * 0.6)
	if bool(item.get("think", false)):
		# Thoughts: white words.
		color = Color(1, 1, 1, alpha)
	else:
		# Whispers keep their colour, bright enough to read.
		var bright := Color(color.r, color.g, color.b)
		if bright.get_luminance() < 0.55:
			bright = bright.lerp(Color.WHITE, 0.35)
		color = Color(bright.r, bright.g, bright.b, alpha)
		# A glow of the colour around the words.
		draw_string_outline(HAND_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(10, font_size / 2), Color(color.r, color.g, color.b, 0.18 * alpha))
	# A soft dark card behind the words, so they read on pale paper too.
	var pad := font_size * 0.4
	_round_box(Rect2(at.x - pad, at.y - font_size * 0.9, width + pad * 2.0, font_size * 1.25), Color(0.03, 0.03, 0.05, 0.42 * alpha), font_size * 0.5)
	# A thick dark edge: readable on light paper, sky, grass or night.
	draw_string_outline(HAND_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(5, font_size / 5), Color(0.04, 0.03, 0.06, 0.92 * alpha))
	draw_string(HAND_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


var _speech_spots: Array[Rect2] = []


## Dialogue as handwritten words floating next to the speaker (no box), in the
## speaker's colour with a dark edge: above the head when there's room, else beside it.
func _draw_speech(frame: Rect2, item: Dictionary, alpha: float) -> void:
	var c: Array = item.get("color", [1.0, 1.0, 1.0])
	var color := Color(float(c[0]), float(c[1]), float(c[2]), alpha)
	var h := frame.size.y
	var font_size := int(h * 0.05)
	var lines := wrap_lines(HAND_FONT, str(item["text"]), font_size, frame.size.x * 0.36)
	var widest := 0.0
	for line in lines:
		widest = maxf(widest, HAND_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var line_h := font_size * 1.08
	var block_h := line_h * lines.size()
	# Default: upper middle of the frame.
	var at := Vector2(frame.get_center().x - widest * 0.5, frame.position.y + h * 0.16)
	var node := track.anchor_node(str(item.get("anchor", "")))
	var camera := get_viewport().get_camera_3d()
	if node and camera and node.is_inside_tree():
		var head := node.global_position + Vector3(0, 1.6, 0)
		var radius := 0.22
		if node is CharacterBase:
			var joint := (node as CharacterBase).joint_position("Head")
			radius = 0.24 * (node as CharacterBase).size_factor()
			if joint.is_finite():
				head = joint
		if not camera.is_position_behind(head):
			var centre := camera.unproject_position(head + Vector3(0, radius * 0.6, 0))
			var top := camera.unproject_position(head + Vector3(0, radius * 1.9, 0))
			var head_px := maxf(absf(centre.y - top.y), 8.0)
			var right_side := centre.x < frame.get_center().x
			if top.y - block_h - font_size * 0.3 > frame.position.y + h * 0.06 and head_px < h * 0.16:
				# Room above the head (wide and medium shots): just above it, a little to the side.
				at = Vector2(centre.x - widest * 0.5 + (head_px * 0.6 if right_side else -head_px * 0.6), top.y - block_h + line_h * 0.5)
			else:
				# Close-ups: beside the head, on the emptier side.
				at.y = centre.y - block_h * 0.5 - head_px * 0.4
				at.x = centre.x + head_px * 1.15 if right_side else centre.x - head_px * 1.15 - widest
	at.x = clampf(at.x, frame.position.x + font_size * 0.6, frame.end.x - widest - font_size * 0.6)
	at.y = clampf(at.y, frame.position.y + font_size * 1.3, frame.end.y - block_h - font_size * 0.2)
	# Two lines on screen at once (one fading out as the reply comes in): never on top of each other.
	var spot := Rect2(at.x, at.y - font_size, widest, block_h)
	for i in 4:
		var clash := false
		for other in _speech_spots:
			if other.grow(font_size * 0.2).intersects(spot):
				clash = true
				var below := other.end.y + font_size * 1.2
				at.y = below if below + block_h < frame.end.y - font_size * 0.2 else other.position.y - block_h - font_size * 0.2 + font_size
				spot = Rect2(at.x, at.y - font_size, widest, block_h)
		if not clash:
			break
	_speech_spots.append(spot)
	var edge := Color(0.03, 0.03, 0.05, 0.9 * alpha)
	var y := at.y
	for line in lines:
		var lw := HAND_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x := at.x + (widest - lw) * 0.5
		draw_string_outline(HAND_FONT, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(8, font_size / 3), Color(0.0, 0.0, 0.02, 0.25 * alpha))
		draw_string_outline(HAND_FONT, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(3, font_size / 8), edge)
		draw_string(HAND_FONT, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		y += line_h


## A quote on black, like the first page of a book: serif lines that fade in one by one.
func _draw_quote(frame: Rect2, item: Dictionary, alpha: float) -> void:
	draw_rect(frame, Color(0.0, 0.0, 0.0, alpha))
	var h := frame.size.y
	var font_size := int(h * 0.05)
	var text := str(item["text"])
	var paragraphs := text.split("\n")
	var lines: Array = []
	for i in paragraphs.size():
		for line in wrap_lines(SERIF_FONT, paragraphs[i], font_size, frame.size.x * 0.66):
			lines.append([line, i])
	var length := maxf(float(item.get("length", 4.0)), 0.5)
	var local := track.current_time() - float(item.get("start", 0.0))
	var line_h := font_size * 1.45
	var y := frame.position.y + h * 0.5 - line_h * (lines.size() - 1) * 0.5 + font_size * 0.3
	var count := maxi(paragraphs.size(), 1)
	for entry in lines:
		var part := int(entry[1])
		# Each paragraph fades in after the one before.
		var appear := length * 0.42 * float(part) / float(count)
		var a := clampf((local - appear) / 0.8, 0.0, 1.0) * alpha
		var shade := 0.94 if part == 0 else 0.72
		var is_attribution := str(entry[0]).begins_with("-") or str(entry[0]).begins_with("—")
		var size := int(font_size * (0.72 if is_attribution else 1.0))
		draw_string(SERIF_FONT, Vector2(frame.position.x, y), str(entry[0]), HORIZONTAL_ALIGNMENT_CENTER, frame.size.x, size, Color(shade, shade * 0.98, shade * 0.95, a))
		y += line_h


## A small time card in the top-right corner: "THAT NIGHT", "A FEW WEEKS LATER".
func _draw_timecard(frame: Rect2, item: Dictionary, alpha: float) -> void:
	var h := frame.size.y
	var font_size := int(h * 0.034)
	var letters := PackedStringArray()
	var text := str(item["text"]).to_upper()
	for i in text.length():
		letters.append(text[i])
	var spaced := "\u2009".join(letters)
	var w := SERIF_FONT.get_string_size(spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(frame.end.x - w - frame.size.x * 0.04, frame.position.y + h * 0.085)
	draw_string_outline(SERIF_FONT, at, spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(6, font_size / 3), Color(0, 0, 0, 0.3 * alpha))
	draw_string(SERIF_FONT, at, spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.95, 0.93, 0.88, 0.92 * alpha))


## "DAYS CLEAN: 3" in the top-right corner.
func _draw_counter(frame: Rect2, text: String, alpha: float) -> void:
	var font_size := int(frame.size.y * 0.045)
	var width := COMIC_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(frame.end.x - width - frame.size.x * 0.05, frame.position.y + frame.size.y * 0.1)
	# A dark pill with white letters: readable over anything.
	var pad := font_size * 0.45
	_round_box(Rect2(at.x - pad, at.y - font_size * 0.95, width + pad * 2.0, font_size * 1.35), Color(0.02, 0.02, 0.04, 0.55 * alpha), font_size * 0.6)
	draw_string_outline(COMIC_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(2, font_size / 9), Color(0, 0, 0, 0.8 * alpha))
	draw_string(COMIC_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, alpha))


## A close-up of a phone screen filling the frame.
func _draw_phone(frame: Rect2, item: Dictionary, alpha: float) -> void:
	var data: Dictionary = item.get("phone", {})
	var mode := str(data.get("mode", "home"))
	var texts: Array = data.get("texts", [])
	var local := track.current_time() - float(item["start"])
	var length := float(item["length"])
	var h := frame.size.y
	# Background: dark, with a warm glow behind the phone.
	draw_rect(frame, Color(0.03, 0.03, 0.035, alpha))
	var glow_color := Color(1.0, 0.55, 0.22) if mode != "cracked" else Color(0.9, 0.2, 0.15)
	if mode == "cracked" and not bool(data.get("face", false)):
		glow_color = Color(0.4, 0.4, 0.45)
	var glow_size := Vector2(h * 1.3, h * 1.3)
	draw_texture_rect(_glow_texture(), Rect2(frame.get_center() - glow_size * 0.5, glow_size), false, Color(glow_color.r, glow_color.g, glow_color.b, 0.32 * alpha))
	# The phone.
	var ph := h * 0.86
	var pw := ph * 0.48
	var phone := Rect2(frame.get_center() - Vector2(pw, ph) * 0.5, Vector2(pw, ph))
	var body := StyleBoxFlat.new()
	body.bg_color = Color(0.07, 0.07, 0.08, alpha)
	body.set_corner_radius_all(int(pw * 0.14))
	body.set_border_width_all(maxi(2, int(pw * 0.018)))
	body.border_color = Color(0.5, 0.49, 0.5, alpha)
	draw_style_box(body, phone)
	var screen := phone.grow(-pw * 0.035)
	var fs := int(pw * 0.065)
	var text_color := Color(0.92, 0.91, 0.88, alpha)
	var dim := Color(0.55, 0.55, 0.58, alpha)
	# Status bar.
	var clock := str(data.get("clock", ""))
	if clock.is_empty():
		clock = "1:41"
	if mode != "cracked":
		draw_string(COMIC_FONT, screen.position + Vector2(pw * 0.1, fs * 1.6), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
		var battery := Rect2(screen.end.x - pw * 0.18, screen.position.y + fs * 0.75, pw * 0.08, fs * 0.6)
		draw_rect(battery, dim, false, 1.5)
		draw_rect(Rect2(battery.position + Vector2(2, 2), Vector2(battery.size.x * 0.25, battery.size.y - 4)), Color(0.9, 0.3, 0.25, alpha))
	var notch := Rect2(phone.get_center().x - pw * 0.13, screen.position.y + fs * 0.5, pw * 0.26, fs * 0.9)
	var notch_box := StyleBoxFlat.new()
	notch_box.bg_color = Color(0.02, 0.02, 0.02, alpha)
	notch_box.set_corner_radius_all(int(fs * 0.45))
	draw_style_box(notch_box, notch)
	var content := Rect2(screen.position + Vector2(pw * 0.06, fs * 2.6), Vector2(screen.size.x - pw * 0.12, screen.size.y - fs * 3.2))
	match mode:
		"home":
			draw_string(COMIC_FONT, Vector2(screen.position.x, screen.position.y + screen.size.y * 0.3), clock, HORIZONTAL_ALIGNMENT_CENTER, screen.size.x, fs * 4, text_color)
			if not texts.is_empty():
				draw_string(COMIC_FONT, Vector2(screen.position.x, screen.position.y + screen.size.y * 0.38), str(texts[0]), HORIZONTAL_ALIGNMENT_CENTER, screen.size.x, fs, dim)
		"notification":
			draw_string(COMIC_FONT, Vector2(screen.position.x, screen.position.y + screen.size.y * 0.25), clock, HORIZONTAL_ALIGNMENT_CENTER, screen.size.x, fs * 3, text_color)
			var slide := clampf(local / 0.35, 0.0, 1.0)
			var banner := Rect2(content.position + Vector2(0, content.size.y * 0.3 - (1.0 - slide) * fs * 3.0), Vector2(content.size.x, fs * 4.2))
			_round_box(banner, Color(0.2, 0.2, 0.22, 0.95 * alpha), fs * 0.6)
			draw_string(COMIC_FONT, banner.position + Vector2(fs * 0.6, fs * 1.6), str(texts[0]) if texts.size() > 0 else "Notification", HORIZONTAL_ALIGNMENT_LEFT, banner.size.x - fs, int(fs * 1.15), text_color)
			if texts.size() > 1:
				draw_string(COMIC_FONT, banner.position + Vector2(fs * 0.6, fs * 3.2), str(texts[1]), HORIZONTAL_ALIGNMENT_LEFT, banner.size.x - fs, int(fs * 1.05), Color(0.78, 0.78, 0.8, alpha))
		"message":
			draw_string(COMIC_FONT, content.position + Vector2(0, fs * 1.2), str(texts[0]) if texts.size() > 0 else "Message", HORIZONTAL_ALIGNMENT_CENTER, content.size.x, fs, text_color)
			draw_line(content.position + Vector2(0, fs * 2.0), content.position + Vector2(content.size.x, fs * 2.0), dim, 1.0)
			var y := content.position.y + fs * 3.2
			for i in range(1, texts.size()):
				if local < 0.5 + (i - 1) * 1.0:
					break
				var mine := i % 2 == 0
				var words := str(texts[i])
				# Long messages wrap onto several lines inside a taller bubble.
				var max_w := content.size.x * 0.8 - fs * 1.2
				var lines: Array[String] = []
				var line := ""
				for word in words.split(" ", false):
					var trial := word if line.is_empty() else line + " " + word
					if not line.is_empty() and COMIC_FONT.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
						lines.append(line)
						line = word
					else:
						line = trial
				if not line.is_empty():
					lines.append(line)
				var widest := 0.0
				for l in lines:
					widest = maxf(widest, COMIC_FONT.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
				var tw := minf(widest + fs * 1.2, content.size.x * 0.8)
				var bh := fs * (0.65 + 1.25 * lines.size())
				var bubble := Rect2(Vector2(content.end.x - tw if mine else content.position.x, y), Vector2(tw, bh))
				_round_box(bubble, Color(0.28, 0.45, 0.8, alpha) if mine else Color(0.22, 0.22, 0.25, alpha), fs * 0.8)
				for li in lines.size():
					draw_string(COMIC_FONT, bubble.position + Vector2(fs * 0.6, fs * (1.3 + 1.25 * li)), lines[li], HORIZONTAL_ALIGNMENT_LEFT, tw - fs, fs, text_color)
				y += bh + fs * 0.6
		"call":
			draw_string(COMIC_FONT, Vector2(screen.position.x, screen.position.y + screen.size.y * 0.3), str(texts[0]) if texts.size() > 0 else "Unknown", HORIZONTAL_ALIGNMENT_CENTER, screen.size.x, int(fs * 1.8), text_color)
			draw_string(COMIC_FONT, Vector2(screen.position.x, screen.position.y + screen.size.y * 0.36), "incoming call", HORIZONTAL_ALIGNMENT_CENTER, screen.size.x, fs, dim)
			var r := fs * 1.6
			draw_circle(Vector2(screen.position.x + screen.size.x * 0.28, screen.end.y - fs * 4), r, Color(0.85, 0.25, 0.22, alpha))
			draw_circle(Vector2(screen.position.x + screen.size.x * 0.72, screen.end.y - fs * 4), r * (1.0 + 0.08 * sin(local * 8.0)), Color(0.25, 0.75, 0.35, alpha))
		"feed", "dialog":
			_draw_feed(content, texts if mode == "feed" else [], fs, local, alpha * (0.45 if mode == "dialog" else 1.0))
			if mode == "dialog":
				var box := Rect2(content.position + Vector2(content.size.x * 0.06, content.size.y * 0.32), Vector2(content.size.x * 0.88, fs * 6.0))
				_round_box(box, Color(0.17, 0.17, 0.19, alpha), fs * 0.8)
				draw_string(COMIC_FONT, box.position + Vector2(0, fs * 1.9), str(texts[0]) if texts.size() > 0 else "Are you sure?", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, int(fs * 1.05), text_color)
				var mid_y := box.position.y + fs * 3.6
				draw_line(Vector2(box.position.x, mid_y), Vector2(box.end.x, mid_y), Color(0.35, 0.35, 0.38, alpha), 1.0)
				draw_line(Vector2(box.get_center().x, mid_y), Vector2(box.get_center().x, box.end.y), Color(0.35, 0.35, 0.38, alpha), 1.0)
				var left := str(texts[1]) if texts.size() > 1 else "Cancel"
				var right := str(texts[2]) if texts.size() > 2 else "OK"
				var tap := str(data.get("tap", "")).to_lower()
				var tapped := not tap.is_empty() and local > length * 0.55
				for k in 2:
					var label := left if k == 0 else right
					var cell := Rect2(Vector2(box.position.x + k * box.size.x * 0.5, mid_y), Vector2(box.size.x * 0.5, box.end.y - mid_y))
					if tapped and label.to_lower() == tap:
						_round_box(cell.grow(-fs * 0.2), Color(1, 1, 1, 0.12 * alpha), fs * 0.5)
					draw_string(COMIC_FONT, cell.position + Vector2(0, cell.size.y * 0.62), label, HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, fs,
						Color(1.0, 0.45, 0.35, alpha) if k == 1 else Color(0.8, 0.8, 0.82, alpha))
		"cracked":
			if bool(data.get("face", false)):
				_draw_shadow_face(screen, alpha)
			_draw_cracks(screen, alpha)


## The page behind a close-up insert: the film's paper colour, a little darker.
func _insert_backdrop(frame: Rect2, alpha: float) -> void:
	var bg := Color(0.82, 0.76, 0.66)
	if not _pal.is_empty():
		bg = (_pal["background"] as Color).darkened(0.08)
	draw_rect(frame, Color(bg.r, bg.g, bg.b, alpha))
	draw_texture_rect(_vignette_texture(), frame, false, Color(0.2, 0.14, 0.08, 0.35 * alpha))


func _ink() -> Color:
	return Color(0.13, 0.12, 0.16)


## A sticky note, close up: handwritten lines, struck out one by one, new lines added.
func _draw_note(frame: Rect2, item: Dictionary, alpha: float) -> void:
	var data: Dictionary = item.get("note", {})
	var lines: Array = data.get("lines", [])
	var strike: Array = data.get("strike", [])
	var adds: Array = data.get("add", [])
	var local := track.current_time() - float(item["start"])
	var length := maxf(float(item["length"]), 0.5)
	_insert_backdrop(frame, alpha)
	var h := frame.size.y
	var size := Vector2(h * 0.66, h * 0.8)
	var centre := frame.get_center()
	draw_set_transform(centre, deg_to_rad(-2.5), Vector2.ONE)
	var note := Rect2(-size * 0.5, size)
	draw_rect(Rect2(note.position + Vector2(h * 0.012, h * 0.016), note.size), Color(0, 0, 0, 0.18 * alpha))
	draw_rect(note, Color(1.0, 0.86, 0.38, alpha))
	draw_rect(Rect2(note.position, Vector2(size.x, size.y * 0.09)), Color(0.96, 0.8, 0.3, alpha))
	draw_circle(Vector2(0, note.position.y + size.y * 0.045), h * 0.014, Color(0.85, 0.2, 0.2, alpha))
	var fs := int(h * 0.058)
	var x := note.position.x + size.x * 0.1
	var y := note.position.y + size.y * 0.2
	var step := fs * 1.25
	var ink := _ink()
	var pen := Color(0.85, 0.12, 0.1, alpha)
	for i in lines.size():
		var text := str(lines[i])
		var size_now := int(fs * (1.25 if i == 0 else 1.0))
		draw_string(HAND_FONT, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.82, size_now, Color(ink.r, ink.g, ink.b, alpha))
		# The first line is the heading; strike numbers count the lines under it.
		var order := strike.find(i) if i > 0 else -1
		if order >= 0:
			# Each strike is drawn in turn across the first two thirds of the shot.
			var begin := length * (0.15 + 0.5 * float(order) / maxf(strike.size(), 1.0))
			var progress := clampf((local - begin) / 0.45, 0.0, 1.0)
			if progress > 0.0:
				var w := minf(HAND_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now).x, size.x * 0.82)
				var y_line := y - size_now * 0.3
				draw_line(Vector2(x - fs * 0.1, y_line + fs * 0.05), Vector2(x - fs * 0.1 + (w + fs * 0.2) * progress, y_line - fs * 0.05), pen, maxf(2.0, h * 0.005), true)
		y += step * (1.2 if i == 0 else 1.0)
	y += step * 0.3
	for i in adds.size():
		var begin := length * (0.68 + 0.1 * float(i))
		var progress := clampf((local - begin) / 0.9, 0.0, 1.0)
		if progress <= 0.0:
			continue
		var text := str(adds[i])
		var shown := text.left(int(ceil(text.length() * progress)))
		draw_string(HAND_FONT, Vector2(x, y), shown, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.82, fs, pen)
		y += step
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A wall calendar, close up: the start day circled, done days ticked one by one.
func _draw_calendar(frame: Rect2, item: Dictionary, alpha: float) -> void:
	var data: Dictionary = item.get("calendar", {})
	var local := track.current_time() - float(item["start"])
	var length := maxf(float(item["length"]), 0.5)
	_insert_backdrop(frame, alpha)
	var h := frame.size.y
	var sheet := Rect2(frame.get_center() - Vector2(h * 0.62, h * 0.43), Vector2(h * 1.24, h * 0.86))
	draw_rect(Rect2(sheet.position + Vector2(h * 0.012, h * 0.016), sheet.size), Color(0, 0, 0, 0.18 * alpha))
	draw_rect(sheet, Color(0.97, 0.96, 0.93, alpha))
	var head := Rect2(sheet.position, Vector2(sheet.size.x, sheet.size.y * 0.16))
	draw_rect(head, Color(0.86, 0.36, 0.28, alpha))
	var fs := int(h * 0.055)
	draw_string(HAND_FONT, head.position + Vector2(0, head.size.y * 0.72), str(data.get("month", "")), HORIZONTAL_ALIGNMENT_CENTER, head.size.x, int(fs * 1.3), Color(1, 1, 1, alpha))
	var days := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
	var grid := Rect2(sheet.position + Vector2(sheet.size.x * 0.03, head.size.y + sheet.size.y * 0.09), Vector2(sheet.size.x * 0.94, sheet.size.y * 0.7))
	var cell := Vector2(grid.size.x / 7.0, grid.size.y / 5.0)
	var ink := _ink()
	for d in 7:
		draw_string(COMIC_FONT, Vector2(grid.position.x + d * cell.x, grid.position.y - cell.y * 0.15), days[d], HORIZONTAL_ALIGNMENT_CENTER, cell.x, int(fs * 0.55), Color(0.5, 0.48, 0.45, alpha))
	var first := int(data.get("first", 3))
	var done: Array = data.get("done", [])
	var missed: Array = data.get("missed", [])
	var start_day := int(data.get("start", 0))
	var pen := Color(0.86, 0.15, 0.12, alpha)
	for day in range(1, 32):
		var slot := day - 1 + first
		var row := slot / 7
		if row > 4:
			row = 4
		var col := slot % 7
		var r := Rect2(grid.position + Vector2(col * cell.x, row * cell.y), cell)
		draw_rect(r, Color(0.78, 0.76, 0.72, alpha), false, 1.0)
		draw_string(COMIC_FONT, r.position + Vector2(cell.x * 0.08, cell.y * 0.3), str(day), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.45), Color(ink.r, ink.g, ink.b, 0.8 * alpha))
		var c := r.get_center() + Vector2(0, cell.y * 0.08)
		var radius := minf(cell.x, cell.y) * 0.36
		if day == start_day:
			draw_string(HAND_FONT, r.position + Vector2(0, cell.y * 0.3), "START", HORIZONTAL_ALIGNMENT_RIGHT, cell.x - cell.x * 0.06, int(fs * 0.42), Color(0.15, 0.3, 0.75, alpha))
		if missed.has(day):
			var k := radius * 0.6
			draw_line(c - Vector2(k, k), c + Vector2(k, k), Color(0.45, 0.45, 0.5, 0.8 * alpha), 2.0, true)
			draw_line(c + Vector2(-k, k), c + Vector2(k, -k), Color(0.45, 0.45, 0.5, 0.8 * alpha), 2.0, true)
		var order := done.find(day)
		if order >= 0:
			var begin := length * 0.1 + (length * 0.75) * float(order) / maxf(done.size(), 1.0)
			var progress := clampf((local - begin) / 0.35, 0.0, 1.0)
			if progress > 0.0:
				draw_arc(c, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, pen, maxf(2.0, h * 0.005), true)
				if progress >= 1.0:
					var tick := PackedVector2Array([c + Vector2(-radius * 0.45, 0), c + Vector2(-radius * 0.1, radius * 0.35), c + Vector2(radius * 0.5, -radius * 0.45)])
					draw_polyline(tick, pen, maxf(2.0, h * 0.005), true)


## A social post framing the live shot: the flash, a white card, likes counting up.
func _draw_post(frame: Rect2, item: Dictionary, alpha: float) -> void:
	var data: Dictionary = item.get("post", {})
	var local := track.current_time() - float(item["start"])
	var length := maxf(float(item["length"]), 0.5)
	var h := frame.size.y
	var side := h * 0.6
	var bar := h * 0.075
	var card := Rect2(frame.get_center() - Vector2(side * 0.5 + h * 0.02, side * 0.5 + bar * 0.9), Vector2(side + h * 0.04, side + bar * 2.7))
	var photo := Rect2(Vector2(card.position.x + h * 0.02, card.position.y + bar), Vector2(side, side))
	# Everything outside the photo dimmed.
	var dim := Color(0.05, 0.05, 0.07, 0.62 * alpha)
	draw_rect(Rect2(frame.position, Vector2(frame.size.x, photo.position.y - frame.position.y)), dim)
	draw_rect(Rect2(Vector2(frame.position.x, photo.end.y), Vector2(frame.size.x, frame.end.y - photo.end.y)), dim)
	draw_rect(Rect2(Vector2(frame.position.x, photo.position.y), Vector2(photo.position.x - frame.position.x, side)), dim)
	draw_rect(Rect2(Vector2(photo.end.x, photo.position.y), Vector2(frame.end.x - photo.end.x, side)), dim)
	# The white card around it (drawn as four strips, so the photo stays live).
	var white := Color(0.98, 0.98, 0.97, alpha)
	draw_rect(Rect2(card.position, Vector2(card.size.x, bar)), white)
	draw_rect(Rect2(Vector2(card.position.x, photo.end.y), Vector2(card.size.x, card.end.y - photo.end.y)), white)
	draw_rect(Rect2(card.position, Vector2(photo.position.x - card.position.x, card.size.y)), white)
	draw_rect(Rect2(Vector2(photo.end.x, card.position.y), Vector2(card.end.x - photo.end.x, card.size.y)), white)
	var ink := Color(0.12, 0.12, 0.14, alpha)
	var fs := int(h * 0.028)
	# Top: a round avatar and the name.
	var av := Vector2(card.position.x + bar * 0.6, card.position.y + bar * 0.5)
	draw_circle(av, bar * 0.3, Color(0.95, 0.55, 0.4, alpha))
	draw_arc(av, bar * 0.36, 0, TAU, 32, Color(0.9, 0.35, 0.55, alpha), 2.0, true)
	draw_string(COMIC_FONT, Vector2(av.x + bar * 0.55, av.y + fs * 0.35), str(data.get("user", "")), HORIZONTAL_ALIGNMENT_LEFT, side * 0.8, fs, ink)
	draw_string(COMIC_FONT, Vector2(card.end.x - bar * 0.8, av.y + fs * 0.3), "...", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	# Bottom: the heart, the likes counting up, the caption.
	var target := int(data.get("likes", 0))
	var grow := clampf((local - 0.4) / maxf(length * 0.55, 0.3), 0.0, 1.0)
	var shown := int(round(target * (1.0 - pow(1.0 - grow, 3.0))))
	var heart := Vector2(card.position.x + bar * 0.6, photo.end.y + bar * 0.55)
	var pop := 1.0 + 0.25 * clampf(1.0 - absf(local - 0.6) / 0.25, 0.0, 1.0)
	_draw_heart(heart, bar * 0.22 * pop, Color(0.92, 0.2, 0.3, alpha) if local > 0.4 else Color(0.2, 0.2, 0.22, alpha))
	draw_string(COMIC_FONT, Vector2(heart.x + bar * 0.45, heart.y + fs * 0.35), "%s likes" % _thousands(shown), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	var user_bold := str(data.get("user", "")).trim_prefix("@")
	draw_string(COMIC_FONT, Vector2(card.position.x + bar * 0.35, photo.end.y + bar * 1.45), user_bold + "  " + str(data.get("caption", "")), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - bar * 0.7, int(fs * 0.95), ink)
	# The flash.
	if bool(data.get("flash", true)) and local < 0.35:
		draw_rect(frame, Color(1, 1, 1, (1.0 - local / 0.35) * 0.9))



# --- NUMBER: a big statistic counting up --------------------------------------------------

static func format_number(value: float, decimals: int) -> String:
	var negative := value < 0.0
	value = absf(value)
	var whole := int(floor(value + (0.0 if decimals > 0 else 0.5)))
	var text := _thousands(whole)
	if decimals > 0:
		var frac := int(round((value - floor(value)) * pow(10.0, decimals)))
		if frac >= int(pow(10.0, decimals)):
			frac = 0
			text = _thousands(whole + 1)
		text += "." + str(frac).pad_zeros(decimals)
	return ("-" if negative else "") + text


func _draw_number(frame: Rect2, item: Dictionary, alpha: float) -> void:
	var data: Dictionary = item.get("number", {})
	var local := track.current_time() - float(item["start"])
	var length := maxf(float(item["length"]), 0.5)
	var h := frame.size.y
	var font: Font = COMIC_FONT
	var grow := clampf((local - 0.25) / maxf(minf(length * 0.55, 3.2), 0.3), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - grow, 3.0)
	var from := float(data.get("from", 0.0))
	var value := from + (float(data.get("value", 0.0)) - from) * eased
	var text := str(data.get("prefix", "")) + format_number(value, int(data.get("decimals", 0)))
	if not str(data.get("suffix", "")).is_empty():
		text += " " + str(data["suffix"])
	var label := str(data.get("label", ""))
	var source := str(data.get("source", ""))
	var backdrop := str(data.get("backdrop", "box"))
	var big := int(h * 0.13)
	# Shrink to fit (measured with the final value, so the size doesn't jump).
	var final_text := str(data.get("prefix", "")) + format_number(float(data.get("value", 0.0)), int(data.get("decimals", 0)))
	if not str(data.get("suffix", "")).is_empty():
		final_text += " " + str(data["suffix"])
	while big > 20 and font.get_string_size(final_text, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x > frame.size.x * 0.86:
		big -= 2
	var mid := int(h * 0.046)
	var small := int(h * 0.03)
	# Long labels and sources wrap; everything fits inside the frame.
	var label_lines := wrap_lines(font, label, mid, frame.size.x * 0.8) if not label.is_empty() else PackedStringArray()
	var source_lines := wrap_lines(font, source, small, frame.size.x * 0.8) if not source.is_empty() else PackedStringArray()
	var on_paper := backdrop == "paper"
	var ink := (_ink() if on_paper and not _pal.is_empty() else Color(0.12, 0.11, 0.1)) if on_paper else Color(1, 1, 1)
	ink.a = alpha
	var accent := Color(0.98, 0.83, 0.42, alpha) if not on_paper else Color(0.7, 0.18, 0.12, alpha)
	var center := frame.get_center() + Vector2(0, -h * 0.03)
	var block_h := big * 1.05 + mid * 1.25 * label_lines.size() + (mid * 0.35 if not label_lines.is_empty() else 0.0) \
		+ small * 1.3 * source_lines.size() + (small * 0.7 if not source_lines.is_empty() else 0.0)
	var top := center.y - block_h * 0.5
	match backdrop:
		"dim":
			draw_rect(frame, Color(0.04, 0.04, 0.06, 0.68 * alpha))
		"paper":
			var page: Color = _pal.get("background", Color(0.97, 0.96, 0.93)) if not _pal.is_empty() else Color(0.97, 0.96, 0.93)
			page.a = alpha
			draw_rect(frame, page)
		_:
			var widest := font.get_string_size(final_text, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
			for line in label_lines:
				widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, mid).x)
			for line in source_lines:
				widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x)
			var pad := h * 0.045
			_round_box(Rect2(center.x - widest * 0.5 - pad, top - pad * 0.7, widest + pad * 2.0, block_h + pad * 1.4),
				Color(0.05, 0.05, 0.07, 0.72 * alpha), h * 0.03)
	var y := top + big * 0.82
	var width := font.get_string_size(final_text, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var x := center.x - width * 0.5
	if not on_paper:
		draw_string_outline(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, int(big * 0.12), Color(0.03, 0.03, 0.05, 0.85 * alpha))
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, accent if grow >= 1.0 else ink)
	y += big * 0.32
	var label_alpha := clampf((local - 0.6) / 0.5, 0.0, 1.0) * alpha
	for line in label_lines:
		y += mid * 1.25
		var lw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, mid).x
		if not on_paper:
			draw_string_outline(font, Vector2(center.x - lw * 0.5, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, mid, int(mid * 0.18), Color(0.03, 0.03, 0.05, 0.85 * label_alpha))
		draw_string(font, Vector2(center.x - lw * 0.5, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, mid, Color(ink.r, ink.g, ink.b, label_alpha))
	var source_alpha := clampf((local - 1.0) / 0.5, 0.0, 1.0) * alpha * 0.9
	if not source_lines.is_empty():
		y += small * 0.5
	for line in source_lines:
		y += small * 1.3
		var sw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
		draw_string(font, Vector2(center.x - sw * 0.5, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(ink.r, ink.g, ink.b, source_alpha))

# --- SPLIT: two live camera views side by side --------------------------------------------

func _split_item() -> Dictionary:
	if track == null:
		return {}
	for pair in track.visible_at(track.current_time()):
		if str(pair[0]["style"]) == "Split":
			return pair[0]
	return {}


## Places the two split-screen cameras before this frame renders.
func _update_split() -> void:
	var item := _split_item()
	if item.is_empty():
		for view in _split_views:
			(view["viewport"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var world := _split_world()
	if world == null:
		return
	var data: Dictionary = item["split"]
	var frame := _film_frame()
	var gap := maxf(4.0, frame.size.y * 0.006)
	var half := Vector2i(int((frame.size.x - gap) * 0.5), int(frame.size.y))
	var local := track.current_time() - float(item["start"])
	var f := clampf(local / maxf(float(item["length"]), 0.1), 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	var halves: Array = data["halves"]
	while _split_views.size() < halves.size():
		var viewport := SubViewport.new()
		viewport.name = "SplitView%d" % _split_views.size()
		viewport.own_world_3d = false
		viewport.msaa_3d = get_viewport().msaa_3d
		viewport.handle_input_locally = false
		var camera := Camera3D.new()
		camera.current = true
		camera.near = 0.05
		camera.far = 4000.0
		viewport.add_child(camera)
		add_child(viewport)
		_split_views.append({"viewport": viewport, "camera": camera})
	for i in halves.size():
		var view: Dictionary = _split_views[i]
		var viewport := view["viewport"] as SubViewport
		var camera := view["camera"] as Camera3D
		viewport.world_3d = world
		viewport.size = half
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var main_camera := get_viewport().get_camera_3d()
		if main_camera:
			camera.cull_mask = main_camera.cull_mask
			camera.environment = main_camera.environment
			camera.attributes = main_camera.attributes
		camera.fov = float(data.get("fov", 50.0))
		var e: Array = halves[i]["eye"]
		var g: Array = halves[i]["target"]
		var eye := Vector3(float(e[0]), float(e[1]), float(e[2]))
		var target := Vector3(float(g[0]), float(g[1]), float(g[2]))
		eye = eye.lerp(target, float(data.get("push", 0.08)) * f)
		if eye.distance_to(target) > 0.01:
			var up := Vector3.UP if absf((target - eye).normalized().y) < 0.98 else Vector3.FORWARD
			camera.global_transform = Transform3D(Basis.looking_at(target - eye, up), eye)


func _split_world() -> World3D:
	# The world this overlay's viewport shows (the editor view or the export viewport).
	return get_viewport().find_world_3d()


func _draw_split(frame: Rect2, item: Dictionary, alpha: float) -> void:
	var data: Dictionary = item["split"]
	var halves: Array = data["halves"]
	if _split_views.size() < halves.size():
		return
	var local := track.current_time() - float(item["start"])
	var length := float(item["length"])
	# Slides in from both sides, and dissolves into the full picture at the end.
	var enter := clampf(local / 0.6, 0.0, 1.0)
	enter = 1.0 - pow(1.0 - enter, 3.0)
	var leave := clampf((length - local) / 1.4, 0.0, 1.0)
	var shown := leave
	var h := frame.size.y
	var gap := maxf(4.0, h * 0.006)
	var half_w := (frame.size.x - gap) * 0.5
	draw_rect(frame, Color(0.04, 0.04, 0.05, shown))
	for i in halves.size():
		var texture := (_split_views[i]["viewport"] as SubViewport).get_texture()
		var x := frame.position.x + (0.0 if i == 0 else half_w + gap)
		var slide := (1.0 - enter) * half_w * (-0.25 if i == 0 else 0.25)
		var rect := Rect2(Vector2(x + slide, frame.position.y), Vector2(half_w, h))
		draw_texture_rect(texture, rect, false, Color(1, 1, 1, shown * enter))
		var label := str(halves[i].get("label", ""))
		if not label.is_empty():
			var fs := int(h * 0.036)
			var font: Font = COMIC_FONT
			var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var pill := Rect2(Vector2(rect.get_center().x - size.x * 0.5 - fs * 0.7, frame.position.y + h * 0.05), Vector2(size.x + fs * 1.4, fs * 1.6))
			_round_box(pill, Color(0.04, 0.04, 0.06, 0.78 * shown * enter), fs * 0.8)
			draw_string(font, Vector2(pill.position.x + fs * 0.7, pill.position.y + fs * 1.15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, shown * enter))
	# The divider.
	var line_x := frame.position.x + half_w + gap * 0.5
	draw_line(Vector2(line_x, frame.position.y), Vector2(line_x, frame.end.y), Color(0.97, 0.96, 0.92, shown * enter), gap)


func _draw_heart(c: Vector2, r: float, color: Color) -> void:
	draw_circle(c + Vector2(-r * 0.5, -r * 0.2), r * 0.55, color)
	draw_circle(c + Vector2(r * 0.5, -r * 0.2), r * 0.55, color)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.02, 0.0), c + Vector2(r * 1.02, 0.0), c + Vector2(0, r * 1.1)]), color)


static func _thousands(n: int) -> String:
	var digits := str(n)
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return digits + out


## The noise in someone's head: words drifting around them, fading in and out.
func _draw_words(frame: Rect2, item: Dictionary, alpha: float) -> void:
	var words: Array = item.get("words", [])
	if words.is_empty():
		return
	var c: Array = item.get("color", [0.8, 0.8, 0.85])
	var color := Color(float(c[0]), float(c[1]), float(c[2]))
	# (The words keep their own colour; a contrasting edge makes them readable.)
	var centre := frame.get_center()
	var node := track.anchor_node(str(item.get("anchor", "")))
	var camera := get_viewport().get_camera_3d()
	if node and camera and node.is_inside_tree():
		var head := node.global_position + Vector3(0, 1.2, 0)
		if node is CharacterBase:
			var joint := (node as CharacterBase).joint_position("Head")
			if joint.is_finite():
				head = joint
		if not camera.is_position_behind(head):
			centre = camera.unproject_position(head)
	var local := track.current_time() - float(item["start"])
	var length := maxf(float(item["length"]), 0.5)
	var h := frame.size.y
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(item["text"]))
	for i in words.size():
		var angle := rng.randf() * TAU
		var dist := h * rng.randf_range(0.14, 0.36)
		var appear := length * 0.6 * float(i) / float(words.size())
		var a := clampf((local - appear) / 0.4, 0.0, 1.0) * alpha
		if a <= 0.0:
			continue
		var drift := Vector2(cos(angle), sin(angle) * 0.6) * (local - appear) * h * 0.012
		var at := centre + Vector2(cos(angle) * dist * 1.3, sin(angle) * dist * 0.8) + drift
		var fs := int(h * rng.randf_range(0.05, 0.08))
		var text := str(words[i])
		var w := HAND_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		at.x = clampf(at.x - w * 0.5, frame.position.x + 4.0, frame.end.x - w - 4.0)
		at.y = clampf(at.y, frame.position.y + fs, frame.end.y - 4.0)
		draw_string_outline(HAND_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, fs / 4), Color(color.r, color.g, color.b, 0.15 * a))
		var edge := Color(0.04, 0.03, 0.06) if color.get_luminance() > 0.45 else Color(1, 1, 1)
		draw_string_outline(HAND_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, fs / 5), Color(edge.r, edge.g, edge.b, 0.85 * a))
		draw_string(HAND_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(color.r, color.g, color.b, a))


func _draw_feed(content: Rect2, texts: Array, fs: int, local: float, alpha: float) -> void:
	var text_color := Color(0.92, 0.91, 0.88, alpha)
	var app := str(texts[0]) if texts.size() > 0 else "Feed"
	draw_string(COMIC_FONT, content.position + Vector2(0, fs * 1.4), app, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 1.4), text_color)
	var tabs_y := content.position.y + fs * 2.3
	for i in 4:
		var tab := Rect2(content.position.x + i * content.size.x * 0.25, tabs_y, content.size.x * 0.22, fs * 0.9)
		_round_box(tab, Color(1.0, 0.55, 0.15, alpha) if i == 0 else Color(0.2, 0.2, 0.22, alpha), fs * 0.45)
	# Thumbnails scroll up slowly, forever.
	var top := tabs_y + fs * 1.6
	var cell_w := content.size.x * 0.48
	var cell_h := cell_w * 0.62
	var row_h := cell_h + fs * 2.2
	var scroll := fmod(local * row_h * 0.45, row_h * 2.0)
	var times := ["15:20", "9:48", "18:02", "7:15", "12:41", "8:07", "24:16", "6:52"]
	for row in range(-1, 7):
		var y := top + row * row_h - scroll
		if y > content.end.y or y + row_h < top:
			continue
		for col in 2:
			var cell := Rect2(content.position.x + col * content.size.x * 0.52, y, cell_w, cell_h)
			if cell.position.y < top - cell_h * 0.2:
				continue
			_round_box(cell, Color(0.2, 0.2, 0.22, alpha), fs * 0.3)
			var label := str(times[(row * 2 + col + 16) % times.size()])
			draw_string(COMIC_FONT, cell.end - Vector2(fs * 2.4, fs * 0.4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.7), Color(0.85, 0.85, 0.85, alpha))
			draw_rect(Rect2(cell.position + Vector2(0, cell_h + fs * 0.5), Vector2(cell_w * 0.8, fs * 0.35)), Color(0.25, 0.25, 0.28, alpha))
			draw_rect(Rect2(cell.position + Vector2(0, cell_h + fs * 1.1), Vector2(cell_w * 0.5, fs * 0.3)), Color(0.22, 0.22, 0.24, alpha))


func _draw_cracks(screen: Rect2, alpha: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var origin := screen.position + screen.size * Vector2(0.62, 0.3)
	var color := Color(0.9, 0.9, 0.92, alpha)
	for i in 9:
		var angle := float(i) / 9.0 * TAU + rng.randf_range(-0.3, 0.3)
		var p := origin
		var length := screen.size.y * rng.randf_range(0.25, 0.7)
		var steps := 5
		for k in steps:
			angle += rng.randf_range(-0.35, 0.35)
			var q := p + Vector2(cos(angle), sin(angle)) * length / steps
			q = q.clamp(screen.position, screen.end)
			draw_line(p, q, color, 1.6, true)
			if rng.randf() < 0.3:
				var branch := angle + rng.randf_range(0.6, 1.2) * (1 if rng.randf() < 0.5 else -1)
				draw_line(q, (q + Vector2(cos(branch), sin(branch)) * length * 0.15).clamp(screen.position, screen.end), color, 1.0, true)
			p = q


## The shadow's face, glowing inside a dark screen (for "PHONE: cracked, shadow face").
func _draw_shadow_face(screen: Rect2, alpha: float) -> void:
	var c := screen.get_center() + Vector2(0, screen.size.y * 0.12)
	var w := screen.size.x
	var glow := Color(0.62, 0.32, 1.0)
	var aura := Vector2(w * 1.1, w * 1.4)
	draw_texture_rect(_glow_texture(), Rect2(c - aura * 0.5, aura), false, Color(glow.r, glow.g, glow.b, 0.5 * alpha))
	draw_circle(c + Vector2(0, -w * 0.18), w * 0.28, Color(0.0, 0.0, 0.0, alpha))
	draw_rect(Rect2(c + Vector2(-w * 0.2, -w * 0.12), Vector2(w * 0.4, screen.end.y - c.y + w * 0.12)), Color(0, 0, 0, alpha))
	var line := Color(0.8, 0.6, 1.0, alpha)
	for s in [-1.0, 1.0]:
		draw_line(c + Vector2(s * w * 0.05, -w * 0.22), c + Vector2(s * w * 0.15, -w * 0.2), line, 3.0, true)
	var mouth := PackedVector2Array()
	for i in 9:
		var f := float(i) / 8.0 * 2.0 - 1.0
		mouth.append(c + Vector2(f * w * 0.1, -w * 0.1 + (1.0 - f * f) * w * 0.035 + maxf(f, 0.0) * -w * 0.02))
	draw_polyline(mouth, line, 3.0, true)


func _round_box(rect: Rect2, color: Color, radius: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	draw_style_box(box, rect)


static func _vignette_texture() -> GradientTexture2D:
	if _vignette:
		return _vignette
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 1))
	gradient.add_point(0.55, Color(1, 1, 1, 0.0))
	_vignette = GradientTexture2D.new()
	_vignette.gradient = gradient
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.05, 1.05)
	_vignette.width = 256
	_vignette.height = 256
	return _vignette


static func _glow_texture() -> GradientTexture2D:
	if _glow:
		return _glow
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.4, Color(1, 1, 1, 0.35))
	_glow = GradientTexture2D.new()
	_glow.gradient = gradient
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 256
	_glow.height = 256
	return _glow

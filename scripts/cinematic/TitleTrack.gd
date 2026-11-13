class_name TitleTrack
extends Node
## Text in the film: titles, subtitles, lower thirds and captions, each shown
## from a start time for a length, fading in and out. Drawn by [TitleOverlay]
## in the editor viewport and burned into exported video.

signal changed

const STYLES: PackedStringArray = ["Title", "Subtitle", "Lower third", "Caption (top)", "Whisper", "Counter", "Phone", "Note", "Calendar", "Words", "Post", "Hero", "Cinematic", "Letterbox", "Speech", "Quote", "Timecard", "Vignette"]
const FADE := 0.4

@export var timeline: TimelineController
@export var director: CinematicDirector
## Viewport showing the scene in the editor (gets an overlay).
@export var editor_viewport: SubViewport

## Each: { "text", "start", "length", "style" }.
var items: Array = []


func _ready() -> void:
	if editor_viewport:
		editor_viewport.add_child.call_deferred(create_overlay())


func create_overlay() -> TitleOverlay:
	var overlay := TitleOverlay.new()
	overlay.track = self
	return overlay


## Items visible at [param t] with their opacity: [[item, alpha], …].
func visible_at(t: float) -> Array:
	var out: Array = []
	for item in items:
		var start := float(item["start"])
		var end := start + float(item["length"])
		if t < start or t > end:
			continue
		var alpha := minf(clampf((t - start) / FADE, 0.0, 1.0), clampf((end - t) / FADE, 0.0, 1.0))
		out.append([item, alpha])
	return out


## The node a Whisper floats next to (by its timeline id), or null.
func anchor_node(uid: String) -> Node3D:
	if timeline == null or uid.is_empty():
		return null
	return timeline._resolve(uid) as Node3D


func current_time() -> float:
	return timeline.current_time if timeline else 0.0


func film_aspect() -> float:
	return director.render_aspect if director else 16.0 / 9.0


func to_list() -> Array:
	return items.duplicate(true)


func load_list(value: Variant) -> void:
	items.clear()
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				var item := {
					"text": str(entry.get("text", "")),
					"start": maxf(float(entry.get("start", 0.0)), 0.0),
					"length": clampf(float(entry.get("length", 3.0)), 0.2, 3600.0),
					"style": str(entry.get("style", "Subtitle")),
				}
				# Extra settings of the Flat sketch styles (Whisper, Counter, Phone).
				for key in ["anchor", "color", "think", "phone", "note", "calendar", "words", "post", "number", "split", "live"]:
					if entry.has(key):
						item[key] = entry[key]
				items.append(item)
	changed.emit()


func clear() -> void:
	load_list([])

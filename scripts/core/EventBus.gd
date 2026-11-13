extends Node
## Global signal hub (autoload "EventBus").
##
## Systems emit and listen here instead of holding references to each other,
## which keeps placement, selection, cinematic and UI code decoupled.

## A short message for the status bar. [param is_error] tints it red.
signal status_message(text: String, is_error: bool)

## Placement mode started for [param prop] (keys: prop_id, scene_path, display_name, category).
signal placement_started(prop: Dictionary)
## Placement mode ended (finished, cancelled, or a single drag-drop completed).
signal placement_ended
## A prop was placed by the user. [param select_it] is true for single drag-drops.
signal prop_placed(node: Node3D, select_it: bool)

## The selected object changed. [param node] is null when nothing is selected.
signal selection_changed(node: Node3D)
## A transform changed outside the undo history (e.g. live while dragging).
signal transform_edited(node: Node3D)

## Any undoable change, undo, redo, or history reset happened.
signal history_changed
## Current file path or saved/unsaved state changed.
signal document_changed

signal grid_snap_changed(enabled: bool, step: float)

## True while a video export is rendering (editor overlays must hide).
signal render_mode_changed(rendering: bool)


func info(text: String) -> void:
	status_message.emit(text, false)


func error(text: String) -> void:
	push_warning(text)
	status_message.emit(text, true)

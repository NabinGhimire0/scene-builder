class_name EditorHistory
extends Node
## Undo/redo for every scene edit, built on Godot's UndoRedo.
##
## Node lifetime: objects removed by an action are kept alive (outside the tree)
## while that action can still be undone, and freed by UndoRedo once the action
## falls out of history — via add_do_reference / add_undo_reference.
##
## Auto-key: when [member keyframe_hook] is set (by the timeline), transform and
## property edits ask it for keyframe changes and fold them into the same undo
## step, so one Ctrl+Z reverts both the edit and its keyframe.

@export var placed_props_root: Node3D
@export_range(10, 1000) var max_steps := 300

## func(target: Object, channel: String, overrides: Dictionary) -> Array
## Returns [] or [apply: Callable, before, after] for the keyframe store.
var keyframe_hook := Callable()

var _undo_redo := UndoRedo.new()
var _saved_version := 0


func _ready() -> void:
	_undo_redo.max_steps = max_steps
	_undo_redo.version_changed.connect(_on_version_changed)
	_saved_version = _undo_redo.get_version()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_undo_redo):
		_undo_redo.clear_history(false)
		_undo_redo.free()


# --- Object actions -----------------------------------------------------------

## Adds an already-positioned object (not yet in the tree) under [param parent]
## (default: the props container) as an undoable action.
func add_prop(node: Node3D, action_name: String = "", parent: Node = null) -> void:
	var target_parent := parent if parent != null else placed_props_root
	var label := action_name if not action_name.is_empty() else "Place %s" % node.name
	_undo_redo.create_action(label)
	_undo_redo.add_do_method(_attach.bind(node, target_parent))
	_undo_redo.add_undo_method(_detach.bind(node))
	_undo_redo.add_do_reference(node)
	_undo_redo.commit_action()


## Removes objects (props or cameras) in one undo step. [param extra_do] /
## [param extra_undo] run alongside (e.g. clearing keyframes with the objects).
func remove_props(nodes: Array[Node3D], action_name: String = "", extra_do: Callable = Callable(), extra_undo: Callable = Callable()) -> void:
	var valid: Array[Node3D] = []
	for node in nodes:
		if is_instance_valid(node) and node.get_parent() != null:
			valid.append(node)
	if valid.is_empty() and not extra_do.is_valid():
		return
	var label := action_name
	if label.is_empty():
		label = "Delete %s" % valid[0].name if valid.size() == 1 else "Delete %d objects" % valid.size()
	_undo_redo.create_action(label)
	# Undo operations run in reverse order of registration, so registering
	# extra_undo first makes it run after the objects are back in the scene.
	if extra_undo.is_valid():
		_undo_redo.add_undo_method(extra_undo)
	for node in valid:
		_undo_redo.add_do_method(_detach.bind(node))
		_undo_redo.add_undo_method(_attach.bind(node, node.get_parent()))
		_undo_redo.add_undo_reference(node)
	if extra_do.is_valid():
		_undo_redo.add_do_method(extra_do)
	_undo_redo.commit_action()


## Records a transform change. Repeated edits with the same [param field] on the
## same node within ~0.8 s merge into one undo step (e.g. holding a spin arrow).
func set_transform(node: Node3D, from: Transform3D, to: Transform3D, field: String = "Transform") -> void:
	if not is_instance_valid(node) or from.is_equal_approx(to):
		return
	_undo_redo.create_action("%s %s" % [field, node.name], UndoRedo.MERGE_ENDS)
	_undo_redo.add_do_property(node, &"transform", to)
	_undo_redo.add_undo_property(node, &"transform", from)
	_add_keyframe_ops(node, "transform", {
		"position": to.origin,
		"quaternion": to.basis.get_rotation_quaternion(),
		"scale": to.basis.get_scale(),
	})
	_undo_redo.commit_action()


## Sets several properties on [param target] as one (mergeable) undo step.
## [param channel] names the keyframe channel the properties belong to.
func set_properties(target: Object, from: Dictionary, to: Dictionary, label: String, channel: String = "") -> void:
	if not is_instance_valid(target) or to.is_empty():
		return
	var changed := false
	for key in to:
		if from.get(key) != to[key]:
			changed = true
	if not changed:
		return
	_undo_redo.create_action(label, UndoRedo.MERGE_ENDS)
	for key in to:
		_undo_redo.add_do_property(target, key, to[key])
		_undo_redo.add_undo_property(target, key, from.get(key, to[key]))
	if not channel.is_empty():
		_add_keyframe_ops(target, channel, to)
	_undo_redo.commit_action()


func set_property(target: Object, property: StringName, from: Variant, to: Variant, label: String, channel: String = "") -> void:
	set_properties(target, {property: from}, {property: to}, label, channel)


func rename(node: Node3D, new_name: String) -> void:
	var clean := new_name.strip_edges().validate_node_name()
	if not is_instance_valid(node) or clean.is_empty() or clean == str(node.name):
		return
	_undo_redo.create_action("Rename %s" % node.name)
	_undo_redo.add_do_property(node, &"name", clean)
	_undo_redo.add_undo_property(node, &"name", node.name)
	_undo_redo.commit_action()


## Generic state change: [param apply] is called with [param after] to do and
## with [param before] to undo (used for keyframe edits).
func record_snapshot(label: String, apply: Callable, before: Variant, after: Variant, merge: bool = false) -> void:
	_undo_redo.create_action(label, UndoRedo.MERGE_ENDS if merge else UndoRedo.MERGE_DISABLE)
	_undo_redo.add_do_method(apply.bind(after))
	_undo_redo.add_undo_method(apply.bind(before))
	_undo_redo.commit_action()


# --- Undo / redo ---------------------------------------------------------------

func undo() -> bool:
	if not _undo_redo.has_undo():
		EventBus.info("Nothing to undo.")
		return false
	var label := _undo_redo.get_current_action_name()
	_undo_redo.undo()
	EventBus.info("Undo: %s" % label)
	return true


func redo() -> bool:
	if not _undo_redo.has_redo():
		EventBus.info("Nothing to redo.")
		return false
	_undo_redo.redo()
	EventBus.info("Redo: %s" % _undo_redo.get_current_action_name())
	return true


func can_undo() -> bool:
	return _undo_redo.has_undo()


func can_redo() -> bool:
	return _undo_redo.has_redo()


func undo_label() -> String:
	return _undo_redo.get_current_action_name() if can_undo() else ""


func redo_label() -> String:
	return _undo_redo.get_action_name(_undo_redo.get_current_action() + 1) if can_redo() else ""


## Forgets all history (after loading or starting a new scene).
func clear_history() -> void:
	_undo_redo.clear_history()
	mark_saved()
	EventBus.history_changed.emit()


func mark_saved() -> void:
	_saved_version = _undo_redo.get_version()
	EventBus.document_changed.emit()


func is_dirty() -> bool:
	return _undo_redo.get_version() != _saved_version


# --- Internals ----------------------------------------------------------------

func _add_keyframe_ops(target: Object, channel: String, overrides: Dictionary) -> void:
	if not keyframe_hook.is_valid():
		return
	var result: Array = keyframe_hook.call(target, channel, overrides)
	if result.size() == 3:
		var apply: Callable = result[0]
		_undo_redo.add_do_method(apply.bind(result[2]))
		_undo_redo.add_undo_method(apply.bind(result[1]))


func _attach(node: Node3D, parent: Node) -> void:
	if is_instance_valid(node) and node.get_parent() == null and is_instance_valid(parent):
		parent.add_child(node, true)


func _detach(node: Node3D) -> void:
	if is_instance_valid(node) and node.get_parent() != null:
		node.get_parent().remove_child(node)


func _on_version_changed() -> void:
	EventBus.history_changed.emit()
	EventBus.document_changed.emit()

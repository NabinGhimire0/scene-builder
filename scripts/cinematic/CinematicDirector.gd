class_name CinematicDirector
extends Node
## Manages virtual cameras and which one is "live".
##
## The live shot is, in order: the camera chosen by the timeline's camera-cut
## track at the current time ([member active_shot_uid], animated), else the
## default camera, else the first camera.
##
## In Camera View the 3D viewport shows the live shot through [member shot_camera]
## (a Camera3D inside the viewport that mirrors the virtual camera), framed to
## the export aspect ratio so what you see is what gets rendered.

signal view_mode_changed(mode: int)
signal cameras_changed

enum ViewMode { EDITOR, CAMERA }

@export var cameras_root: Node3D
@export var editor_camera: EditorCamera
@export var shot_camera: Camera3D
@export var history: EditorHistory

var view_mode: ViewMode = ViewMode.EDITOR
## Camera used when no camera cut applies.
var default_camera_uid := ""
## Animated by the timeline's camera-cut track (discrete String track).
var active_shot_uid := ""
## Width / height of the export resolution; previews are framed to it.
var render_aspect := 16.0 / 9.0

var _camera_count := 0


func _ready() -> void:
	if shot_camera:
		shot_camera.cull_mask = Layers.FINAL_RENDER_MASK
		shot_camera.current = false
	EventBus.history_changed.connect(_on_history_changed)


func _process(_delta: float) -> void:
	var live := current_camera()
	for cam in cameras():
		cam.set_live(cam == live)
	if view_mode == ViewMode.CAMERA:
		if live == null:
			set_view_mode(ViewMode.EDITOR)
			return
		var view_size := shot_camera.get_viewport().get_visible_rect().size
		apply_shot(shot_camera, live, view_size.x / maxf(view_size.y, 1.0))


# --- Cameras -------------------------------------------------------------------

func cameras() -> Array[CinematicCamera]:
	var out: Array[CinematicCamera] = []
	if cameras_root:
		for child in cameras_root.get_children():
			if child is CinematicCamera:
				out.append(child)
	return out


func find_camera(uid: String) -> CinematicCamera:
	if uid.is_empty():
		return null
	for cam in cameras():
		if cam.get_meta(PropUtils.META_UID, "") == uid:
			return cam
	return null


func current_camera() -> CinematicCamera:
	var cam := find_camera(active_shot_uid)
	if cam == null:
		cam = find_camera(default_camera_uid)
	if cam == null:
		var all := cameras()
		if not all.is_empty():
			cam = all[0]
	return cam


## Creates a camera exactly where the editor view is looking from (undoable).
func create_camera_from_view() -> CinematicCamera:
	var cam := CinematicCamera.new()
	cam.name = _next_camera_name()
	cam.set_meta(PropUtils.META_UID, PropUtils.new_uid())
	cam.transform = editor_camera.global_transform.orthonormalized()
	cam.fov = editor_camera.fov
	cam.focus_distance = editor_camera.distance
	history.add_prop(cam, "Add %s" % cam.name, cameras_root)
	if find_camera(default_camera_uid) == null:
		default_camera_uid = cam.uid()
	EventBus.info("Added %s from the current view. Use Camera View to look through it." % cam.name)
	return cam


func duplicate_camera(source: CinematicCamera) -> CinematicCamera:
	var cam := CinematicCamera.new()
	cam.name = _next_camera_name()
	cam.set_meta(PropUtils.META_UID, PropUtils.new_uid())
	cam.transform = source.transform.translated(source.transform.basis.x.normalized() * 1.0)
	cam.fov = source.fov
	cam.dof_enabled = source.dof_enabled
	cam.focus_distance = source.focus_distance
	cam.aperture = source.aperture
	history.add_prop(cam, "Duplicate %s" % source.name, cameras_root)
	return cam


## Moves [param cam] to the editor view (undoable).
func align_camera_to_view(cam: CinematicCamera) -> void:
	if cam == null:
		return
	history.set_transform(cam, cam.transform, editor_camera.global_transform.orthonormalized(), "Align")
	EventBus.info("%s now matches the editor view." % cam.name)


func set_default_camera(cam: CinematicCamera) -> void:
	if cam:
		default_camera_uid = cam.uid()
		EventBus.info("%s is the default camera (used where there are no camera cuts)." % cam.name)


## Shows the live shot through [param cam] (makes it the default camera first).
func look_through(cam: CinematicCamera) -> void:
	if cam:
		default_camera_uid = cam.uid()
	set_view_mode(ViewMode.CAMERA)


# --- View mode -----------------------------------------------------------------

func set_view_mode(mode: ViewMode) -> void:
	if mode == ViewMode.CAMERA and current_camera() == null:
		EventBus.info("Add a camera first (toolbar: Add Camera) to use Camera View.")
		mode = ViewMode.EDITOR
	if shot_camera and editor_camera:
		shot_camera.current = mode == ViewMode.CAMERA
		editor_camera.current = mode == ViewMode.EDITOR
	var changed := mode != view_mode
	view_mode = mode
	if changed:
		view_mode_changed.emit(view_mode)


func toggle_view_mode() -> void:
	set_view_mode(ViewMode.EDITOR if view_mode == ViewMode.CAMERA else ViewMode.CAMERA)


## Points [param target] through [param cam], keeping the framing identical to
## the export aspect whatever the shape of the viewport ([param view_aspect]).
func apply_shot(target: Camera3D, cam: CinematicCamera, view_aspect: float) -> void:
	cam.apply_to(target)
	if view_aspect < render_aspect:
		# Narrower than the film frame: lock the horizontal angle instead.
		target.keep_aspect = Camera3D.KEEP_WIDTH
		var half_v := deg_to_rad(cam.fov) * 0.5
		target.fov = clampf(rad_to_deg(2.0 * atan(tan(half_v) * render_aspect)), 1.0, 175.0)
	else:
		target.keep_aspect = Camera3D.KEEP_HEIGHT


# --- Scene lifecycle -----------------------------------------------------------

func reset() -> void:
	set_view_mode(ViewMode.EDITOR)
	default_camera_uid = ""
	active_shot_uid = ""


func to_dict() -> Dictionary:
	return {"default_camera": default_camera_uid}


func load_dict(data: Dictionary) -> void:
	default_camera_uid = str(data.get("default_camera", ""))


## Recreates saved cameras directly (no undo history).
func restore_cameras(entries: Array) -> int:
	var count := 0
	for entry in entries:
		if entry is Dictionary:
			var cam := CinematicCamera.new()
			cam.name = _next_camera_name()
			cam.load_dict(entry)
			cameras_root.add_child(cam, true)
			count += 1
	return count


func _next_camera_name() -> String:
	var used := {}
	for cam in cameras():
		used[str(cam.name)] = true
	var i := 1
	while used.has("Camera%d" % i):
		i += 1
	return "Camera%d" % i


func _on_history_changed() -> void:
	var count := cameras().size()
	if count != _camera_count:
		_camera_count = count
		cameras_changed.emit()

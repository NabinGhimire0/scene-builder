class_name ViewportArea
extends Control
## The 3D view between the side panels.
##
## Contains a SubViewportContainer that renders the shared 3D world, so the image
## fits exactly inside this rectangle. This control is the only input surface for
## the 3D scene: it routes mouse input to the camera, placement and selection
## systems, and accepts assets dropped from the library. UI panels sit outside
## it, so their clicks never reach the world.
##
## Editor View: full editing. Camera View: a framed, letterboxed preview through
## the live cinematic camera (what the export will look like); editing clicks
## are disabled there so what you click always matches what you see.
##
## The container stretches its SubViewport to this control 1:1, so local mouse
## positions equal SubViewport pixel coordinates.

@export var placement: PlacementController
@export var selection: SelectionManager
@export var editor_camera: EditorCamera
@export var director: CinematicDirector
@export var tools: WorldTools
@export var pose_tool: PoseTool

var _hovered := false
var _last_hint_ms := -10000

@onready var _editor_view_button: Button = %EditorViewButton
@onready var _camera_view_button: Button = %CameraViewButton
@onready var _letterbox: LetterboxOverlay = %Letterbox


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	if editor_camera:
		editor_camera.moved.connect(_on_camera_moved)
	var group := ButtonGroup.new()
	_editor_view_button.button_group = group
	_camera_view_button.button_group = group
	_editor_view_button.pressed.connect(func() -> void: director.set_view_mode(CinematicDirector.ViewMode.EDITOR))
	_camera_view_button.pressed.connect(func() -> void: director.set_view_mode(CinematicDirector.ViewMode.CAMERA))
	director.view_mode_changed.connect(_on_view_mode_changed)
	_on_view_mode_changed(director.view_mode)


func is_camera_view() -> bool:
	return director != null and director.view_mode == CinematicDirector.ViewMode.CAMERA


func _gui_input(event: InputEvent) -> void:
	# Tab would otherwise move keyboard focus; here it toggles Editor/Camera View.
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_TAB:
		director.toggle_view_mode()
		accept_event()
		return
	# P: pose mode (drag a character's joints).
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_P \
			and not (event as InputEventKey).ctrl_pressed and pose_tool and not is_camera_view():
		pose_tool.toggle()
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			grab_focus()  # pull keyboard focus off text fields so shortcuts work
		if is_camera_view():
			if mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
				_camera_view_hint()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and tools and tools.is_active():
			if mb.pressed:
				if mb.double_click and tools.tool == "Path":
					tools.finish_path()
				else:
					tools.pointer_pressed(mb.position)
			else:
				tools.pointer_released(mb.position)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and pose_tool and pose_tool.active:
			if mb.pressed and not (placement and placement.is_placing()) and pose_tool.pointer_pressed(mb.position):
				accept_event()
				return
			if not mb.pressed and pose_tool.is_dragging():
				pose_tool.pointer_released(mb.position)
				accept_event()
				return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_button(mb)
			accept_event()
			return
	elif event is InputEventMouseMotion:
		if is_camera_view():
			return
		var motion := event as InputEventMouseMotion
		if pose_tool and pose_tool.active:
			pose_tool.pointer_moved(motion.position, motion.shift_pressed)
			if pose_tool.is_dragging():
				accept_event()
				return
		if tools and tools.is_active():
			tools.pointer_moved(motion.position)
		elif placement:
			placement.update_pointer(motion.position, true)
		if selection and not (placement and placement.is_placing()) and not (tools and tools.is_active()):
			selection.on_motion(motion.position)

	if not is_camera_view() and editor_camera and editor_camera.handle_input(event):
		accept_event()


func _handle_left_button(mb: InputEventMouseButton) -> void:
	if placement and placement.is_placing():
		if mb.pressed:
			placement.update_pointer(mb.position, true)
			placement.place_current()
		return
	if selection == null:
		return
	if mb.pressed:
		selection.on_press(mb.position)
	else:
		selection.on_release(mb.position)


func _camera_view_hint() -> void:
	if Time.get_ticks_msec() - _last_hint_ms > 3000:
		_last_hint_ms = Time.get_ticks_msec()
		EventBus.info("Camera View is a preview of the film. Switch to Editor View (Tab) to edit or move around.")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_END:
			if placement:
				placement.end_drag_session()
		NOTIFICATION_FOCUS_EXIT:
			if editor_camera:
				editor_camera.release_drags()


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	if editor_camera:
		editor_camera.keyboard_enabled = hovered and not is_camera_view()
	if not hovered and placement:
		placement.set_pointer_inside(false)


func _on_camera_moved() -> void:
	if placement:
		placement.refresh_preview()


func _on_view_mode_changed(mode: int) -> void:
	var camera_view := mode == CinematicDirector.ViewMode.CAMERA
	_editor_view_button.set_pressed_no_signal(not camera_view)
	_camera_view_button.set_pressed_no_signal(camera_view)
	_letterbox.active = camera_view
	if camera_view:
		if placement and placement.is_placing():
			placement.cancel_placement()
		if editor_camera:
			editor_camera.release_drags()
			editor_camera.keyboard_enabled = false
	elif editor_camera:
		editor_camera.keyboard_enabled = _hovered


# --- Drop target ---------------------------------------------------------------

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if placement == null or is_camera_view() or not _is_prop_payload(data):
		return false
	return placement.preview_drag(data, at_position)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if placement and _is_prop_payload(data):
		placement.drop_prop(data, at_position)
		grab_focus()


static func _is_prop_payload(data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == "prop" and data.has("scene_path")

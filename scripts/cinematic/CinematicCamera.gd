class_name CinematicCamera
extends Node3D
## A virtual film camera placed in the world.
##
## It holds the shot (transform + lens settings) and draws an editor-only gizmo:
## a small camera body and its view frustum, red when it is the live shot.
## It is deliberately not a Camera3D: rendering is done by a preview / render
## camera that copies this one via [method apply_to], so placing cameras in the
## world never changes what the main window renders.

const BODY_COLOR := Color(0.18, 0.2, 0.24)
const IDLE_COLOR := Color(0.45, 0.75, 1.0)
const LIVE_COLOR := Color(1.0, 0.36, 0.3)
const FRUSTUM_DEPTH := 1.4
const GIZMO_ASPECT := 16.0 / 9.0

## Vertical field of view in degrees.
@export_range(5.0, 140.0, 0.1) var fov := 50.0:
	set(value):
		fov = clampf(value, 5.0, 140.0)
		_rebuild_frustum()
## Depth-of-field blur on/off.
@export var dof_enabled := false
## Distance (m) that stays sharp when depth of field is on.
@export_range(0.1, 1000.0, 0.01) var focus_distance := 8.0:
	set(value):
		focus_distance = clampf(value, 0.1, 1000.0)
## Blur strength, 0 (subtle) to 1 (strong).
@export_range(0.0, 1.0, 0.01) var aperture := 0.35:
	set(value):
		aperture = clampf(value, 0.0, 1.0)

## Handheld camera shake, 0 = rock steady (animatable with the lens).
@export_range(0.0, 1.0, 0.01) var shake := 0.0

var _frustum: MeshInstance3D
var _line_material: StandardMaterial3D
var _live := false


func _ready() -> void:
	_build_gizmo()


func uid() -> String:
	return PropUtils.uid_of(self)


## 35 mm-equivalent focal length for the current field of view.
func focal_length_mm() -> float:
	return 12.0 / tan(deg_to_rad(fov) * 0.5)


func set_live(live: bool) -> void:
	if live == _live:
		return
	_live = live
	if _line_material:
		_line_material.albedo_color = LIVE_COLOR if live else IDLE_COLOR


## Copies this shot (transform, field of view, depth of field) onto [param cam].
func apply_to(cam: Camera3D) -> void:
	cam.global_transform = global_transform.orthonormalized()
	if shake > 0.0:
		# Smooth, deterministic "handheld" wobble from layered sines of scene time.
		var t := SceneClock.now
		var seed_value := float(hash(uid()) % 1000)
		var yaw := (sin(t * 1.3 + seed_value) * 0.6 + sin(t * 2.9 + seed_value * 1.7) * 0.3 + sin(t * 7.1) * 0.1) * shake * 0.02
		var pitch := (sin(t * 1.1 + seed_value * 0.5) * 0.6 + sin(t * 3.3 + seed_value) * 0.3 + sin(t * 6.7) * 0.1) * shake * 0.015
		var roll := sin(t * 0.9 + seed_value * 2.3) * shake * 0.008
		cam.global_transform.basis = cam.global_transform.basis * Basis.from_euler(Vector3(pitch, yaw, roll))
	cam.fov = fov
	cam.near = 0.05
	cam.far = 2000.0
	var attrs := cam.attributes as CameraAttributesPractical
	if attrs == null:
		attrs = CameraAttributesPractical.new()
		cam.attributes = attrs
	var sharp_half_depth := maxf(focus_distance * 0.12, 0.05)
	attrs.dof_blur_far_enabled = dof_enabled
	attrs.dof_blur_far_distance = focus_distance + sharp_half_depth
	attrs.dof_blur_far_transition = maxf(focus_distance * 0.8, 0.5)
	attrs.dof_blur_near_enabled = dof_enabled
	attrs.dof_blur_near_distance = maxf(focus_distance - sharp_half_depth, 0.05)
	attrs.dof_blur_near_transition = maxf(minf(focus_distance * 0.4, attrs.dof_blur_near_distance), 0.01)
	attrs.dof_blur_amount = lerpf(0.02, 0.3, aperture)


func lens_state() -> Dictionary:
	return {"fov": fov, "dof_enabled": dof_enabled, "focus_distance": focus_distance, "aperture": aperture, "shake": shake}


func to_dict() -> Dictionary:
	var data := lens_state()
	data["uid"] = uid()
	data["name"] = str(name)
	data["position"] = [position.x, position.y, position.z]
	data["rotation_degrees"] = [rotation_degrees.x, rotation_degrees.y, rotation_degrees.z]
	return data


func load_dict(data: Dictionary) -> void:
	var saved_uid := str(data.get("uid", ""))
	set_meta(PropUtils.META_UID, saved_uid if not saved_uid.is_empty() else PropUtils.new_uid())
	var saved_name := str(data.get("name", "")).validate_node_name()
	if not saved_name.is_empty():
		name = saved_name
	position = _vec(data.get("position"), Vector3(0, 2, 8))
	rotation_degrees = _vec(data.get("rotation_degrees"), Vector3.ZERO)
	fov = float(data.get("fov", fov))
	dof_enabled = bool(data.get("dof_enabled", dof_enabled))
	focus_distance = float(data.get("focus_distance", focus_distance))
	aperture = float(data.get("aperture", aperture))
	shake = float(data.get("shake", shake))


static func _vec(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array and value.size() >= 3:
		var v := Vector3(float(value[0]), float(value[1]), float(value[2]))
		if v.is_finite():
			return v
	return fallback


# --- Gizmo ---------------------------------------------------------------------

func _build_gizmo() -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = BODY_COLOR
	body_material.roughness = 0.6

	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = LIVE_COLOR if _live else IDLE_COLOR

	var body := MeshInstance3D.new()
	body.name = "GizmoBody"
	var box := BoxMesh.new()
	box.size = Vector3(0.32, 0.26, 0.42)
	box.material = body_material
	body.mesh = box
	body.position = Vector3(0, 0, 0.16)

	var lens := MeshInstance3D.new()
	lens.name = "GizmoLens"
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.09
	barrel.bottom_radius = 0.12
	barrel.height = 0.16
	barrel.material = body_material
	lens.mesh = barrel
	lens.rotation_degrees = Vector3(90, 0, 0)
	lens.position = Vector3(0, 0, -0.12)

	_frustum = MeshInstance3D.new()
	_frustum.name = "GizmoFrustum"
	_frustum.material_override = _line_material

	var parts: Array[MeshInstance3D] = [body, lens, _frustum]
	for part in parts:
		part.layers = Layers.EDITOR_ONLY_VISUAL
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(part)
	_rebuild_frustum()

	# Clickable handle on the gizmo physics layer (never a placement surface).
	var handle := StaticBody3D.new()
	handle.name = "GizmoHandle"
	handle.collision_layer = Layers.GIZMOS
	handle.collision_mask = 0
	var shape := CollisionShape3D.new()
	var handle_box := BoxShape3D.new()
	handle_box.size = Vector3(0.5, 0.42, 0.7)
	shape.shape = handle_box
	shape.position = Vector3(0, 0, 0.05)
	handle.add_child(shape)
	add_child(handle)


func _rebuild_frustum() -> void:
	if _frustum == null:
		return
	var h := tan(deg_to_rad(fov) * 0.5) * FRUSTUM_DEPTH
	var w := h * GIZMO_ASPECT
	var z := -FRUSTUM_DEPTH
	var corners := [Vector3(-w, -h, z), Vector3(w, -h, z), Vector3(w, h, z), Vector3(-w, h, z)]
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 4:
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(corners[i])
		mesh.surface_add_vertex(corners[i])
		mesh.surface_add_vertex(corners[(i + 1) % 4])
	# "Up" marker above the frame.
	var a := Vector3(-w * 0.3, h * 1.08, z)
	var b := Vector3(w * 0.3, h * 1.08, z)
	var c := Vector3(0, h * 1.4, z)
	for pair in [[a, b], [b, c], [c, a]]:
		mesh.surface_add_vertex(pair[0])
		mesh.surface_add_vertex(pair[1])
	mesh.surface_end()
	_frustum.mesh = mesh

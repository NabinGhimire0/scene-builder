class_name ThumbnailRenderer
extends Node
## Renders small preview images of prop scenes in an off-screen SubViewport.
##
## Lookup order per prop: a same-name image next to the scene (crate.png for
## crate.tscn) → cached render in user://thumbnails → fresh render (then cached).
## Renders are queued and done one per frame so the UI never stalls.

const SIZE := 128
const CACHE_DIR := "user://thumbnails/"
const SIDECAR_EXTENSIONS: PackedStringArray = ["png", "webp", "jpg"]

var _queue: Array = []
var _busy := false
var _viewport: SubViewport
var _camera: Camera3D
var _stage: Node3D


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.7)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	_viewport.add_child(light)

	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	_camera.current = true

	_stage = Node3D.new()
	_viewport.add_child(_stage)
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)


## Calls [param callback] with a Texture2D once a thumbnail is available.
func request(scene_path: String, callback: Callable) -> void:
	var ready_made := _load_sidecar(scene_path)
	if ready_made == null:
		ready_made = _load_cached(scene_path)
	if ready_made != null:
		callback.call(ready_made)
		return
	_queue.append([scene_path, callback])
	if not _busy:
		_process_queue()


func _process_queue() -> void:
	_busy = true
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		var callback: Callable = job[1]
		if not callback.is_valid():
			continue
		var texture: Texture2D = await _render(job[0])
		if texture != null and callback.is_valid():
			callback.call(texture)
	_busy = false


func _render(scene_path: String) -> Texture2D:
	var instance := PropUtils.instantiate_as_node3d(PropUtils.load_prop_scene(scene_path))
	if instance == null:
		return null
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	_stage.add_child(instance)

	var bounds := instance.transform * PropUtils.compute_local_aabb(instance)
	var center := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 0.05)
	var dist := radius / sin(deg_to_rad(_camera.fov * 0.5)) * 1.05
	var view_dir := Vector3(1.0, 0.75, 1.25).normalized()
	_camera.near = maxf(0.01, dist - radius * 2.0)
	_camera.far = dist + radius * 4.0
	_camera.look_at_from_position(center + view_dir * dist, center, Vector3.UP)

	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()

	_stage.remove_child(instance)
	instance.queue_free()
	if image == null or image.is_empty():
		return null
	image.save_png(_cache_path(scene_path))
	return ImageTexture.create_from_image(image)


func _load_sidecar(scene_path: String) -> Texture2D:
	for ext in SIDECAR_EXTENSIONS:
		var path := scene_path.get_basename() + "." + ext
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				return tex
	return null


func _load_cached(scene_path: String) -> Texture2D:
	var path := _cache_path(scene_path)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _cache_path(scene_path: String) -> String:
	# Include the file's modified time so edited props get re-rendered.
	var stamp := str(FileAccess.get_modified_time(scene_path))
	return CACHE_DIR + (scene_path + stamp).md5_text() + ".png"

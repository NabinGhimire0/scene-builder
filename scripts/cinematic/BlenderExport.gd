class_name BlenderExport
extends Node
## "Export for Blender": writes the scene (scene.glb), every frame of animation
## (animation.json: objects, character joints, cameras with lens and cuts, the
## sun) and render_in_blender.py, which rebuilds the film in Blender with
## realistic materials and renders it with Cycles.
##
## Not transferred: shader-only effects (fire, smoke, weather particles) and the
## bone animation of imported skinned characters (their movement is kept).

const SCRIPT_SOURCE := "res://tools/blender/render_in_blender.py"
const MAX_SMALL_PLANTS := 6000

@export var placed_props_root: Node3D
@export var cameras_root: Node3D
@export var terrain: Terrain
@export var vegetation: Vegetation
@export var timeline: TimelineController
@export var director: CinematicDirector
@export var environment: EnvironmentController
@export var exporter: ExportManager


## Exports into a new folder inside [param parent_folder]. Returns the folder
## path, or "" (with an error shown).
func export_scene(parent_folder: String, base_name: String) -> String:
	if timeline.is_playing():
		timeline.pause()
	var folder := parent_folder.path_join(base_name + "_blender")
	var n := 2
	while DirAccess.dir_exists_absolute(folder):
		folder = parent_folder.path_join("%s_blender_%d" % [base_name, n])
		n += 1
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		EventBus.error("Couldn't create %s." % folder)
		return ""
	var restore_time := timeline.current_time
	var root := _build_export_root()
	var animation := _sample_animation()
	timeline.set_time(restore_time)

	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_scene(root, state)
	if err == OK:
		err = document.write_to_filesystem(state, folder.path_join("scene.glb"))
	root.free()
	if err != OK:
		EventBus.error("Couldn't write scene.glb (%s)." % error_string(err))
		return ""
	var json := FileAccess.open(folder.path_join("animation.json"), FileAccess.WRITE)
	json.store_string(JSON.stringify(animation))
	json.close()
	var script_file := FileAccess.open(folder.path_join("render_in_blender.py"), FileAccess.WRITE)
	script_file.store_string(FileAccess.get_file_as_string(SCRIPT_SOURCE))
	script_file.close()
	if not environment.hdri_path.is_empty() and FileAccess.file_exists(environment.hdri_path):
		DirAccess.copy_absolute(environment.hdri_path, folder.path_join("sky.hdr"))
	var readme := FileAccess.open(folder.path_join("README.txt"), FileAccess.WRITE)
	readme.store_string("Render this film in Blender (Cycles):\n\n"
		+ "1. Open Blender 4.x.\n2. Scripting tab > Open > render_in_blender.py > Run Script.\n"
		+ "   It builds the scene, saves film.blend here and sets up the render.\n"
		+ "3. Render > Render Animation (Ctrl+F12). The video is saved in the 'render' folder.\n\n"
		+ "Or in a terminal:  blender -b -P render_in_blender.py -- --render\n")
	readme.close()
	EventBus.info("Exported for Blender to %s (open README.txt there)." % folder)
	return folder


# --- Scene ---------------------------------------------------------------------

func _build_export_root() -> Node3D:
	var root := Node3D.new()
	root.name = "SceneBuilderExport"
	for child in placed_props_root.get_children():
		var prop := child as Node3D
		if prop == null or not PropUtils.is_prop(prop):
			continue
		var copy := prop.duplicate() as Node3D
		copy.set_script(null)
		copy.name = PropUtils.uid_of(prop)
		copy.transform = prop.global_transform
		_prepare_copy(copy, prop)
		root.add_child(copy)
	for cam in director.cameras():
		var camera := Camera3D.new()
		camera.name = cam.uid()
		camera.transform = cam.global_transform
		camera.fov = cam.fov
		root.add_child(camera)
	if terrain:
		root.add_child(_terrain_mesh())
	if vegetation:
		_add_plants(root)
	return root


## Strips editor-only and shader-only parts and names joints so the per-frame
## animation can find them.
func _prepare_copy(copy: Node3D, original: Node3D) -> void:
	var uid := copy.name
	for node in PropUtils.descendants(copy, false):
		if is_instance_valid(node) and node is CollisionObject3D:
			node.free()
	for node in PropUtils.descendants(copy, false):
		if not is_instance_valid(node):
			continue
		node.set_script(null)
		var geo := node as GeometryInstance3D
		if geo and (geo.layers == Layers.EDITOR_ONLY_VISUAL or geo is MultiMeshInstance3D):
			geo.free()
			continue
		if geo and geo.material_override is ShaderMaterial:
			var material := _fallback_material(geo.material_override as ShaderMaterial, original)
			if material == null:
				geo.free()
				continue
			geo.material_override = material
	if original is HumanCharacter:
		for joint in PropUtils.descendants(copy, false):
			if joint is Node3D and not joint is MeshInstance3D:
				joint.name = "%s__%s" % [uid, joint.name]


## Standard materials Blender understands, named so the Blender script can
## upgrade them (glass-like water, wet banks…).
func _fallback_material(shader_material: ShaderMaterial, owner_prop: Node3D) -> Material:
	var path := shader_material.shader.resource_path if shader_material.shader else ""
	var material := StandardMaterial3D.new()
	if path.ends_with("water.gdshader"):
		var water := owner_prop as WaterFeature
		material.resource_name = "SB_Water"
		material.albedo_color = Color(water.shallow_color if water else Color(0.3, 0.55, 0.55), 0.6)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.05
		return material
	if path.ends_with("water_bank.gdshader"):
		var bank := owner_prop as WaterFeature
		material.resource_name = "SB_Bank"
		material.albedo_color = bank.bank_wet if bank else Color(0.2, 0.16, 0.1)
		material.roughness = 0.4
		return material
	if path.ends_with("waterfall.gdshader"):
		material.resource_name = "SB_Water"
		material.albedo_color = Color(0.75, 0.85, 0.9, 0.7)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		return material
	return null


func _terrain_mesh() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 2   # 2 m resolution keeps the file small
	var res := Terrain.RES
	var colors := environment.GROUND_PRESETS.get(environment.ground_style, environment.GROUND_PRESETS["Grass"]) as Array
	var base: Color = colors[1] if colors.size() > 1 else Color(0.3, 0.35, 0.2)
	if environment.ground_style == "Plain colour":
		base = environment.ground_color
	var layer_colors: Array[Color] = [Color(0.33, 0.24, 0.16), Color(0.42, 0.41, 0.39), Color(0.78, 0.69, 0.51), Color(0.93, 0.95, 0.98)]
	var count := (res - 1) / step + 1
	for zi in count:
		for xi in count:
			var x: int = mini(xi * step, res - 1)
			var z: int = mini(zi * step, res - 1)
			var i: int = z * res + x
			var color := base
			for c in 4:
				color = color.lerp(layer_colors[c], float(terrain.splat[i * 4 + c]) / 255.0)
			st.set_color(color)
			st.set_uv(Vector2(float(x) / (res - 1), float(z) / (res - 1)))
			st.add_vertex(Vector3(x * Terrain.SPACING - Terrain.HALF, terrain.heights[i], z * Terrain.SPACING - Terrain.HALF))
	for zi in count - 1:
		for xi in count - 1:
			var a: int = zi * count + xi
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + count)
			st.add_index(a + 1)
			st.add_index(a + count + 1)
			st.add_index(a + count)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "SB_Terrain"
	mesh.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.resource_name = "SB_Ground"
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	mesh.material_override = material
	return mesh


func _add_plants(root: Node3D) -> void:
	for kind in vegetation.plants.keys():
		var data: PackedFloat32Array = vegetation.plants[kind]
		var count := data.size() / Vegetation.STRIDE
		if count == 0 or (kind in ["Grass", "Tall grass", "Flowers"] and count > MAX_SMALL_PLANTS):
			continue
		var group := Node3D.new()
		group.name = "SB_Plants_" + vegetation.title_of(kind).to_pascal_case().validate_node_name()
		var custom := vegetation.is_model_kind(kind)
		var mesh: Mesh = vegetation.mesh_for(kind) if custom else PlantMeshes.build(kind)
		var material := StandardMaterial3D.new()
		material.resource_name = "SB_Plant"
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if kind == "Rocks":
			material.albedo_color = Color(0.44, 0.42, 0.38)   # rock vertex colour is only shading
		for p in count:
			var i: int = p * Vegetation.STRIDE
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			if not custom:
				instance.material_override = material
			instance.transform = Transform3D(Basis(Vector3.UP, data[i + 3]).scaled(Vector3.ONE * data[i + 4]), Vector3(data[i], data[i + 1], data[i + 2]))
			group.add_child(instance)
		root.add_child(group)


# --- Animation -----------------------------------------------------------------

func _sample_animation() -> Dictionary:
	var fps := exporter.fps()
	var frames := maxi(1, ceili(timeline.duration() * fps))
	var res := exporter.resolution()
	var objects := {}
	var cams := {}
	var sun_frames: Array = []
	var active: Array = []
	for f in frames:
		var t := float(f) / float(fps)
		timeline.apply_time_for_render(t)
		for child in placed_props_root.get_children():
			var prop := child as Node3D
			if prop == null or not PropUtils.is_prop(prop):
				continue
			var uid := PropUtils.uid_of(prop)
			_record(objects, uid, prop.global_transform)
			if prop is HumanCharacter:
				for joint in PropUtils.descendants(prop, false):
					if joint is Node3D and not joint is MeshInstance3D:
						_record(objects, "%s__%s" % [uid, joint.name], (joint as Node3D).transform)
		for cam in director.cameras():
			var entry: Array = cams.get(cam.uid(), [])
			var xf := cam.global_transform.orthonormalized()
			var q := xf.basis.get_rotation_quaternion()
			entry.append([xf.origin.x, xf.origin.y, xf.origin.z, q.w, q.x, q.y, q.z, cam.fov, cam.focus_distance, cam.aperture if cam.dof_enabled else 0.0])
			cams[cam.uid()] = entry
		var shot := director.current_camera()
		active.append(shot.uid() if shot else "")
		var sun := environment.sun
		if sun:
			var d := -sun.global_transform.basis.z
			sun_frames.append([d.x, d.y, d.z, sun.light_energy, sun.light_color.r, sun.light_color.g, sun.light_color.b])
	var colors := environment.current_sky_colors()
	return {
		"fps": fps, "frames": frames, "resolution": [res.x, res.y],
		"objects": objects, "cameras": cams, "active_camera": active, "sun": sun_frames,
		"sky": {"top": [colors[0].r, colors[0].g, colors[0].b], "horizon": [colors[1].r, colors[1].g, colors[1].b],
			"hdri": "sky.hdr" if not environment.hdri_path.is_empty() else "", "hdri_rotation": environment.hdri_rotation,
			"exposure": environment.exposure, "fog": environment.fog_density + environment.mist * 0.05},
	}


static func _record(objects: Dictionary, key: String, xf: Transform3D) -> void:
	var entry: Array = objects.get(key, [])
	var q := xf.basis.get_rotation_quaternion()
	var s := xf.basis.get_scale()
	entry.append([snappedf(xf.origin.x, 0.0001), snappedf(xf.origin.y, 0.0001), snappedf(xf.origin.z, 0.0001),
		snappedf(q.w, 0.00001), snappedf(q.x, 0.00001), snappedf(q.y, 0.00001), snappedf(q.z, 0.00001),
		snappedf(s.x, 0.0001), snappedf(s.y, 0.0001), snappedf(s.z, 0.0001)])
	objects[key] = entry

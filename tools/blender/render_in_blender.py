"""Scene Builder - rebuild an exported film in Blender and render it with Cycles.

Put this file next to scene.glb and animation.json (Scene Builder does), then:
  * In Blender: Scripting tab > Open > this file > Run Script, or
  * In a terminal:  blender -b -P render_in_blender.py -- --render

It imports the scene, keys every object, character joint and camera for every
frame, switches cameras at the film's cuts, recreates the sun and sky, gives
water, wet banks, ground and plants realistic materials, sets up Cycles and
saves film.blend. With --render it renders straight to render/film.mp4.
"""

import json
import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

CAMERA_FIX = Quaternion((1.0, 0.0, 0.0), math.radians(90.0))

HERE = os.path.dirname(os.path.abspath(bpy.context.space_data.text.filepath if bpy.context.space_data and getattr(bpy.context.space_data, "text", None) else __file__))


def log(message):
    print("[scene-builder] " + str(message), flush=True)


def to_blender_location(x, y, z):
    # glTF / Godot (Y up) -> Blender (Z up)
    return (x, -z, y)


def to_blender_quaternion(w, x, y, z):
    return (w, x, -z, y)


def to_blender_scale(x, y, z):
    return (x, z, y)


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


def find_objects():
    by_name = {}
    for obj in bpy.data.objects:
        by_name.setdefault(obj.name, obj)
        base = obj.name.rsplit(".", 1)[0] if obj.name[-4:-3] == "." and obj.name[-3:].isdigit() else obj.name
        by_name.setdefault(base, obj)
    return by_name


def key_objects(data, objects):
    keyed = 0
    for name, frames in data["objects"].items():
        obj = objects.get(name)
        if obj is None:
            continue
        # glTF import may parent nodes under the exported root; we keyed world
        # transforms for props, local ones for character joints.
        obj.rotation_mode = "QUATERNION"
        static = all(f == frames[0] for f in frames)
        for index, f in enumerate(frames):
            if static and index > 0:
                break
            obj.location = to_blender_location(f[0], f[1], f[2])
            obj.rotation_quaternion = to_blender_quaternion(f[3], f[4], f[5], f[6])
            obj.scale = to_blender_scale(f[7], f[8], f[9])
            if not static:
                obj.keyframe_insert("location", frame=index + 1)
                obj.keyframe_insert("rotation_quaternion", frame=index + 1)
                obj.keyframe_insert("scale", frame=index + 1)
        keyed += 1
    log("Animated %d objects." % keyed)


def key_cameras(data, objects, scene):
    cameras = {}
    for uid, frames in data["cameras"].items():
        obj = objects.get(uid)
        if obj is None or obj.type != "CAMERA":
            cam_data = bpy.data.cameras.new(uid)
            obj = bpy.data.objects.new(uid, cam_data)
            scene.collection.objects.link(obj)
        if obj.parent is not None:
            matrix = obj.matrix_world.copy()
            obj.parent = None
            obj.matrix_world = matrix
        cameras[uid] = obj
        obj.rotation_mode = "QUATERNION"
        cam = obj.data
        cam.sensor_fit = "VERTICAL"
        for index, f in enumerate(frames):
            frame = index + 1
            obj.location = to_blender_location(f[0], f[1], f[2])
            # Cameras need a quarter turn about X on top of the axis change so
            # they keep looking where they looked in Scene Builder.
            obj.rotation_quaternion = Quaternion(to_blender_quaternion(f[3], f[4], f[5], f[6])) @ CAMERA_FIX
            obj.keyframe_insert("location", frame=frame)
            obj.keyframe_insert("rotation_quaternion", frame=frame)
            cam.angle_y = math.radians(f[7])
            cam.keyframe_insert("lens", frame=frame)
            cam.dof.use_dof = f[9] > 0.0
            cam.dof.focus_distance = max(f[8], 0.1)
            cam.dof.aperture_fstop = 16.0 - 14.6 * min(max(f[9], 0.0), 1.0)
            cam.dof.keyframe_insert("focus_distance", frame=frame)
            cam.dof.keyframe_insert("aperture_fstop", frame=frame)
    previous = None
    for index, uid in enumerate(data["active_camera"]):
        if uid and uid != previous and uid in cameras:
            marker = scene.timeline_markers.new("cut_%d" % (index + 1), frame=index + 1)
            marker.camera = cameras[uid]
            if previous is None:
                scene.camera = cameras[uid]
            previous = uid
    if scene.camera is None and cameras:
        scene.camera = next(iter(cameras.values()))
    log("Set up %d cameras." % len(cameras))


def build_sun(data, scene):
    light = bpy.data.lights.new("Sun", "SUN")
    light.angle = math.radians(0.6)
    sun = bpy.data.objects.new("Sun", light)
    scene.collection.objects.link(sun)
    sun.rotation_mode = "QUATERNION"
    for index, f in enumerate(data["sun"]):
        direction = to_blender_location(f[0], f[1], f[2])
        # Point the light's -Z along the sun direction.
        quat = Vector(direction).to_track_quat("-Z", "Y")
        sun.rotation_quaternion = quat
        sun.keyframe_insert("rotation_quaternion", frame=index + 1)
        light.energy = f[3] * 3.5
        light.color = (f[4], f[5], f[6])
        light.keyframe_insert("energy", frame=index + 1)
        light.keyframe_insert("color", frame=index + 1)


def build_world(data, scene):
    world = bpy.data.worlds.new("SceneBuilderSky")
    scene.world = world
    world.use_nodes = True
    nodes = world.node_tree.nodes
    links = world.node_tree.links
    background = nodes.get("Background")
    sky = data.get("sky", {})
    hdri = os.path.join(HERE, sky.get("hdri", "")) if sky.get("hdri") else ""
    if hdri and os.path.exists(hdri):
        env = nodes.new("ShaderNodeTexEnvironment")
        env.image = bpy.data.images.load(hdri)
        mapping = nodes.new("ShaderNodeMapping")
        coords = nodes.new("ShaderNodeTexCoord")
        mapping.inputs["Rotation"].default_value[2] = math.radians(sky.get("hdri_rotation", 0.0))
        links.new(coords.outputs["Generated"], mapping.inputs["Vector"])
        links.new(mapping.outputs["Vector"], env.inputs["Vector"])
        links.new(env.outputs["Color"], background.inputs["Color"])
    else:
        sky_node = nodes.new("ShaderNodeTexSky")
        try:
            sky_node.sky_type = "NISHITA"
        except TypeError:
            pass
        links.new(sky_node.outputs["Color"], background.inputs["Color"])
        background.inputs["Strength"].default_value = 0.35
    fog = sky.get("fog", 0.0)
    if fog > 0.0005:
        volume = nodes.new("ShaderNodeVolumePrincipled")
        volume.inputs["Density"].default_value = fog * 0.25
        links.new(volume.outputs["Volume"], nodes.get("World Output").inputs["Volume"])


def principled(material):
    material.use_nodes = True
    for node in material.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            return node
    return None


def set_input(node, names, value):
    for name in names:
        if name in node.inputs:
            node.inputs[name].default_value = value
            return


def upgrade_materials():
    for material in bpy.data.materials:
        name = material.name
        bsdf = principled(material) if name.startswith("SB_") else None
        if bsdf is None:
            continue
        if name.startswith("SB_Water"):
            set_input(bsdf, ["Transmission Weight", "Transmission"], 1.0)
            set_input(bsdf, ["Roughness"], 0.02)
            set_input(bsdf, ["IOR"], 1.333)
            set_input(bsdf, ["Alpha"], 1.0)
        elif name.startswith("SB_Bank"):
            set_input(bsdf, ["Roughness"], 0.35)
        elif name.startswith("SB_Ground"):
            set_input(bsdf, ["Roughness"], 0.95)
        elif name.startswith("SB_Plant"):
            set_input(bsdf, ["Subsurface Weight", "Subsurface"], 0.15)
            set_input(bsdf, ["Roughness"], 0.7)


def setup_render(data, scene, output_dir):
    scene.render.engine = "CYCLES"
    try:
        samples = 128
        if "--samples" in sys.argv:
            samples = int(sys.argv[sys.argv.index("--samples") + 1])
        scene.cycles.samples = samples
        scene.cycles.use_denoising = True
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for device_type in ("OPTIX", "CUDA", "HIP", "METAL", "ONEAPI"):
            try:
                prefs.compute_device_type = device_type
                prefs.get_devices()
                if any(d.type == device_type for d in prefs.devices):
                    for d in prefs.devices:
                        d.use = True
                    scene.cycles.device = "GPU"
                    break
            except Exception:  # noqa: BLE001
                continue
    except Exception:  # noqa: BLE001
        pass
    scene.render.fps = int(data["fps"])
    scene.frame_start = 1
    scene.frame_end = int(data["frames"])
    scene.render.resolution_x = int(data["resolution"][0])
    scene.render.resolution_y = int(data["resolution"][1])
    scene.render.resolution_percentage = 100
    scene.view_settings.exposure = math.log2(max(data.get("sky", {}).get("exposure", 1.0), 0.01))
    os.makedirs(output_dir, exist_ok=True)
    scene.render.filepath = os.path.join(output_dir, "film")
    try:
        scene.render.image_settings.file_format = "FFMPEG"
        scene.render.ffmpeg.format = "MPEG4"
        scene.render.ffmpeg.codec = "H264"
        scene.render.ffmpeg.constant_rate_factor = "HIGH"
    except Exception:  # noqa: BLE001
        scene.render.image_settings.file_format = "PNG"
        scene.render.filepath = os.path.join(output_dir, "frame_")


def main():
    with open(os.path.join(HERE, "animation.json"), "r", encoding="utf-8") as handle:
        data = json.load(handle)
    scene = bpy.context.scene
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=os.path.join(HERE, "scene.glb"))
    objects = find_objects()
    # Props were exported with world transforms directly under the export root.
    root = objects.get("SceneBuilderExport")
    if root is not None:
        root.location = (0, 0, 0)
        root.rotation_mode = "QUATERNION"
        root.rotation_quaternion = (1, 0, 0, 0)
        root.scale = (1, 1, 1)
    key_objects(data, objects)
    key_cameras(data, objects, scene)
    build_sun(data, scene)
    build_world(data, scene)
    upgrade_materials()
    setup_render(data, scene, os.path.join(HERE, "render"))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "film.blend"))
    log("Saved film.blend. Render > Render Animation to make the video.")
    if "--render" in sys.argv:
        bpy.ops.render.render(animation=True)
        log("Rendered to " + os.path.join(HERE, "render"))


main()

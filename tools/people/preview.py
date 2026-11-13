"""Quick Cycles previews of a built person (full body + face)."""
import math, os
import bpy
import numpy as np
from PIL import Image


def _cam(name, loc, target, lens):
    cam = bpy.data.cameras.new(name)
    cam.lens = lens
    ob = bpy.data.objects.new(name, cam)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    d = np.array(target) - np.array(loc)
    yaw = math.atan2(d[0], d[1])
    pitch = math.atan2(d[2], math.hypot(d[0], d[1]))
    ob.rotation_euler = (math.pi / 2 + pitch, 0, -yaw)
    return ob


def setup(sc, res=(420, 640), samples=24):
    sc.render.engine = "CYCLES"
    sc.cycles.samples = samples
    sc.cycles.device = "CPU"
    sc.render.resolution_x, sc.render.resolution_y = res
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.55, 0.6, 0.68, 1)
    bg.inputs[1].default_value = 0.6
    sc.world = world
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.0
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(50), 0, math.radians(-35))
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new("Fill", "AREA")
    fill.energy = 120
    fill.size = 2
    fo = bpy.data.objects.new("Fill", fill)
    fo.location = (2.0, -2.5, 1.6)
    fo.rotation_euler = (math.radians(60), 0, math.radians(40))
    sc.collection.objects.link(fo)
    me = bpy.data.meshes.new("Floor")
    me.from_pydata([(-5, -5, 0), (5, -5, 0), (5, 5, 0), (-5, 5, 0)], [], [(0, 1, 2, 3)])
    fl = bpy.data.objects.new("Floor", me)
    sc.collection.objects.link(fl)


def render(arm, path, spec, frames=None, action=None):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.cycles.device = "CPU"
    try:
        sc.cycles.use_denoising = True
    except Exception:
        pass
    sc.render.resolution_x = 420
    sc.render.resolution_y = 640
    sc.render.film_transparent = False
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.55, 0.6, 0.68, 1)
    bg.inputs[1].default_value = 0.6
    sc.world = world
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.0
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(50), 0, math.radians(-35))
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new("Fill", "AREA")
    fill.energy = 120
    fill.size = 2
    fo = bpy.data.objects.new("Fill", fill)
    fo.location = (2.0, -2.5, 1.6)
    fo.rotation_euler = (math.radians(60), 0, math.radians(40))
    sc.collection.objects.link(fo)
    # floor
    me = bpy.data.meshes.new("Floor")
    me.from_pydata([(-5, -5, 0), (5, -5, 0), (5, 5, 0), (-5, 5, 0)], [], [(0, 1, 2, 3)])
    fl = bpy.data.objects.new("Floor", me)
    sc.collection.objects.link(fl)
    fm = bpy.data.materials.new("FloorM")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.35, 0.33, 0.3, 1)
    me.materials.append(fm)

    hmax = max((ob.matrix_world @ v.co).z for ob in sc.objects if ob.type == "MESH" and ob.name == "Body" for v in ob.data.vertices)
    head_z = hmax - 0.11 * hmax / 1.7
    shots = []
    if action is not None:
        arm.animation_data.action = bpy.data.actions[action]
    frames = frames or [1]
    for i, fr in enumerate(frames):
        sc.frame_set(fr)
        for j, (loc, tgt, lens) in enumerate([
                ((0.9 * hmax / 1.7, -3.4 * hmax / 1.7, hmax * 0.55), (0, 0, hmax * 0.5), 50),
                ((0.25 * hmax / 1.7, -0.75 * hmax / 1.7, head_z + 0.02), (0, 0, head_z - 0.01), 85)]):
            cam = _cam("C%d%d" % (i, j), loc, tgt, lens)
            sc.camera = cam
            out = path + ".%d_%d.png" % (i, j)
            sc.render.filepath = out
            bpy.ops.render.render(write_still=True)
            shots.append(out)
    ims = [Image.open(s) for s in shots]
    W = sum(im.width for im in ims)
    canvas = Image.new("RGB", (W, ims[0].height))
    x = 0
    for im in ims:
        canvas.paste(im, (x, 0))
        x += im.width
    canvas.save(path)
    for s in shots:
        os.remove(s)
    # remove preview things so they are not exported
    for ob in [o for o in sc.objects if o.type in ("CAMERA", "LIGHT") or o.name == "Floor"]:
        bpy.data.objects.remove(ob)

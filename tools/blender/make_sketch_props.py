"""Builds the Flat sketch props (assets/props/sketch/*.glb) with Blender.
Run from the project folder:  blender -b --python tools/blender/make_sketch_props.py
Simple rounded shapes in muted colours; Scene Builder draws them flat with an
outline. Sizes in metres, origin at the bottom centre, front facing the camera.
"""
import math
import os

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "props", "sketch")


_materials = {}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


def mat(name, color, emit=0.0):
    key = (name, color, emit)
    if key in _materials:
        return _materials[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = 0.9
    if emit:
        b.inputs["Emission Color"].default_value = (*color, 1)
        b.inputs["Emission Strength"].default_value = emit
    _materials[key] = m
    return m


def box(size, loc, material, bevel=0.012, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        mod = o.modifiers.new("b", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        bpy.ops.object.modifier_apply(modifier="b")
    o.data.materials.append(material)
    return o


def cyl(r, depth, loc, material, rot=(0, 0, 0), verts=24, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    o.data.materials.append(material)
    return o


def ball(r, loc, material, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=24, ring_count=12)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material)
    return o


def export(name):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB")
    print("built", name)


WOOD = (0.36, 0.3, 0.26)
DARK = (0.24, 0.23, 0.25)
GREY = (0.42, 0.41, 0.43)
CLOTH = (0.3, 0.28, 0.33)
LIGHT = (1.0, 0.82, 0.55)
SCREEN = (0.75, 0.85, 1.0)


def desk():
    reset()
    wood = mat("wood", WOOD)
    box((1.4, 0.65, 0.05), (0, 0, 0.75), wood)
    for x in (-0.65, 0.65):
        for y in (-0.28, 0.28):
            box((0.04, 0.04, 0.73), (x, y, 0.365), mat("leg", DARK), 0.004)
    export("sketch_desk")


def chair():
    reset()
    m = mat("chair", GREY)
    box((0.44, 0.44, 0.04), (0, 0, 0.46), m)
    box((0.44, 0.04, 0.5), (0, 0.2, 0.73), m)
    for x in (-0.19, 0.19):
        for y in (-0.19, 0.19):
            box((0.03, 0.03, 0.45), (x, y, 0.225), mat("leg", DARK), 0.003)
    export("sketch_chair")


def sofa():
    reset()
    m = mat("cloth", CLOTH)
    box((1.9, 0.8, 0.22), (0, 0, 0.32), m, 0.05)          # seat
    box((1.9, 0.22, 0.6), (0, 0.29, 0.6), m, 0.06)        # back
    for x in (-0.88, 0.88):
        box((0.2, 0.8, 0.5), (x, 0, 0.38), m, 0.07)       # arms
    for x in (-0.85, 0.85):
        cyl(0.025, 0.12, (x, 0, 0.06), mat("leg", DARK), verts=12)
    export("sketch_sofa")


def bed():
    reset()
    frame = mat("frame", WOOD)
    box((2.0, 1.0, 0.25), (0, 0, 0.3), frame)
    box((0.08, 1.0, 0.75), (-1.0, 0, 0.375), frame)       # headboard
    box((1.9, 0.95, 0.14), (0.02, 0, 0.49), mat("sheet", (0.38, 0.4, 0.47)), 0.04)
    box((0.42, 0.7, 0.12), (-0.72, 0, 0.6), mat("pillow", (0.62, 0.62, 0.6)), 0.05)
    box((1.15, 0.98, 0.08), (0.38, 0, 0.58), mat("blanket", (0.3, 0.33, 0.42)), 0.03)
    export("sketch_bed")


def desk_lamp():
    reset()
    m = mat("lamp", GREY)
    cyl(0.09, 0.03, (0, 0, 0.015), m)
    box((0.02, 0.02, 0.34), (0.02, 0, 0.18), m, 0.004, rot=(0, math.radians(-12), 0))
    box((0.02, 0.02, 0.24), (0.1, 0, 0.38), m, 0.004, rot=(0, math.radians(50), 0))
    cyl(0.1, 0.16, (0.2, 0, 0.42), m, rot=(0, math.radians(120), 0), r2=0.04)
    ball(0.035, (0.24, 0, 0.38), mat("bulb", LIGHT, 4.0))
    export("sketch_desk_lamp")


def floor_lamp():
    reset()
    m = mat("lamp", GREY)
    cyl(0.15, 0.03, (0, 0, 0.015), m)
    cyl(0.015, 1.5, (0, 0, 0.76), m, verts=12)
    cyl(0.22, 0.28, (0, 0, 1.55), mat("shade", (0.55, 0.5, 0.42)), r2=0.13)
    ball(0.05, (0, 0, 1.45), mat("bulb", LIGHT, 4.0))
    export("sketch_floor_lamp")


def books():
    reset()
    for i, (color, w) in enumerate([((0.4, 0.42, 0.22), 0.3), ((0.22, 0.3, 0.45), 0.28), ((0.48, 0.18, 0.16), 0.31)]):
        box((w, 0.21, 0.06), (0, 0, 0.03 + i * 0.062), mat("book%d" % i, color), 0.012)
    export("sketch_books")


def open_book():
    reset()
    page = mat("page", (0.85, 0.84, 0.8))
    box((0.22, 0.3, 0.012), (-0.115, 0, 0.012), page, 0.004, rot=(0, math.radians(4), 0))
    box((0.22, 0.3, 0.012), (0.115, 0, 0.012), page, 0.004, rot=(0, math.radians(-4), 0))
    export("sketch_open_book")


def bookshelf():
    reset()
    wood = mat("wood", WOOD)
    box((0.9, 0.3, 0.04), (0, 0, 0.02), wood, 0.004)
    for z in (0.5, 1.0, 1.5):
        box((0.9, 0.3, 0.03), (0, 0, z), wood, 0.004)
    for x in (-0.44, 0.44):
        box((0.03, 0.3, 1.8), (x, 0, 0.9), wood, 0.004)
    colors = [(0.4, 0.42, 0.22), (0.22, 0.3, 0.45), (0.48, 0.18, 0.16), (0.5, 0.45, 0.3), (0.3, 0.3, 0.35)]
    for shelf, z in enumerate((0.04, 0.53, 1.02)):
        x = -0.38
        k = shelf
        while x < 0.35:
            w = 0.05 + (k % 3) * 0.015
            h = 0.3 + (k % 4) * 0.04
            box((w, 0.22, h), (x + w / 2, 0, z + h / 2), mat("b%d" % (k % 5), colors[k % 5]), 0.004)
            x += w + 0.01
            k += 1
    box((0.9, 0.02, 1.8), (0, 0.15, 0.9), mat("back", (0.2, 0.19, 0.2)), 0)
    export("sketch_bookshelf")


def door():
    reset()
    box((0.9, 0.06, 2.05), (0, 0, 1.025), mat("door", (0.33, 0.28, 0.25)))
    box((1.0, 0.08, 0.05), (0, 0, 2.08), mat("frame", DARK), 0.005)
    for x in (-0.48, 0.48):
        box((0.05, 0.08, 2.1), (x, 0, 1.05), mat("frame", DARK), 0.005)
    ball(0.03, (0.33, -0.05, 1.0), mat("knob", (0.7, 0.62, 0.4)))
    export("sketch_door")


def window():
    reset()
    box((1.1, 0.04, 1.2), (0, 0.02, 1.5), mat("night", (0.07, 0.09, 0.16)), 0)
    frame = mat("frame", GREY)
    for z in (0.9, 1.5, 2.1):
        box((1.16, 0.06, 0.05), (0, 0, z), frame, 0.005)
    for x in (-0.56, 0, 0.56):
        box((0.05, 0.06, 1.25), (x, 0, 1.5), frame, 0.005)
    ball(0.09, (0.3, -0.01, 1.85), mat("moon", (0.95, 0.92, 0.8), 2.0), (1, 0.2, 1))
    export("sketch_window")


def mirror():
    reset()
    frame = mat("frame", DARK)
    box((0.62, 0.06, 1.6), (0, 0, 0.98), frame, 0.02)
    box((0.52, 0.02, 1.48), (0, -0.03, 0.98), mat("glass", (0.42, 0.47, 0.52)), 0)
    box((0.5, 0.3, 0.05), (0, 0.1, 0.025), frame, 0.01)
    export("sketch_mirror")


def laptop():
    reset()
    body = mat("laptop", (0.3, 0.3, 0.33))
    box((0.34, 0.24, 0.018), (0, 0, 0.009), body, 0.004)
    box((0.34, 0.015, 0.23), (0, 0.12, 0.125), body, 0.004, rot=(math.radians(-12), 0, 0))
    box((0.31, 0.004, 0.2), (0, 0.108, 0.125), mat("screen", SCREEN, 3.0), 0, rot=(math.radians(-12), 0, 0))
    export("sketch_laptop")


def phone():
    reset()
    box((0.075, 0.012, 0.155), (0, 0, 0.0775), mat("phone", (0.12, 0.12, 0.14)), 0.006)
    box((0.066, 0.004, 0.14), (0, -0.007, 0.0775), mat("screen", (1.0, 0.72, 0.45), 3.0), 0)
    export("sketch_phone")


def mug():
    reset()
    m = mat("mug", (0.6, 0.55, 0.5))
    cyl(0.045, 0.1, (0, 0, 0.05), m)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.03, minor_radius=0.008, location=(0.055, 0, 0.055), rotation=(math.pi / 2, 0, 0))
    bpy.context.object.data.materials.append(m)
    export("sketch_mug")


def bin_():
    reset()
    cyl(0.17, 0.4, (0, 0, 0.2), mat("bin", GREY), r2=0.2)
    export("sketch_bin")


def plant():
    reset()
    cyl(0.14, 0.28, (0, 0, 0.14), mat("pot", (0.45, 0.3, 0.24)), r2=0.17)
    leaf = mat("leaf", (0.24, 0.38, 0.25))
    for i in range(7):
        a = i / 7 * math.tau
        ball(0.11, (math.cos(a) * 0.1, math.sin(a) * 0.05, 0.42 + (i % 3) * 0.08), leaf, (0.6, 0.6, 1.3))
    export("sketch_plant")


def wall_clock():
    reset()
    # Hangs on the wall: the clock face is about 2.1 m up.
    cyl(0.18, 0.04, (0, 0, 2.1), mat("rim", DARK), rot=(math.pi / 2, 0, 0), verts=32)
    cyl(0.16, 0.02, (0, -0.02, 2.1), mat("face", (0.82, 0.8, 0.75)), rot=(math.pi / 2, 0, 0), verts=32)
    hand = mat("hand", (0.1, 0.1, 0.1))
    box((0.012, 0.01, 0.12), (0, -0.035, 2.15), hand, 0)
    box((0.09, 0.01, 0.012), (0.045, -0.035, 2.1), hand, 0)
    export("sketch_wall_clock")


def tv():
    reset()
    box((1.2, 0.06, 0.7), (0, 0, 0.75), mat("tv", (0.1, 0.1, 0.12)), 0.01)
    box((1.12, 0.01, 0.62), (0, -0.032, 0.75), mat("screen", (0.15, 0.17, 0.2)), 0)
    box((0.3, 0.2, 0.02), (0, 0, 0.01), mat("stand", DARK), 0.005)
    box((0.05, 0.04, 0.4), (0, 0, 0.2), mat("stand", DARK), 0.004)
    export("sketch_tv")


def bottle():
    reset()
    m = mat("bottle", (0.3, 0.45, 0.36))
    cyl(0.04, 0.2, (0, 0, 0.1), m)
    cyl(0.04, 0.06, (0, 0, 0.23), m, r2=0.015)
    cyl(0.016, 0.04, (0, 0, 0.28), mat("cap", DARK))
    export("sketch_bottle")


for build in (desk, chair, sofa, bed, desk_lamp, floor_lamp, books, open_book, bookshelf, door, window, mirror,
              laptop, phone, mug, bin_, plant, wall_clock, tv, bottle):
    build()

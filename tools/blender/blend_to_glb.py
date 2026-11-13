"""Scene Builder: converts a downloaded .blend asset (e.g. from BlendKit) to .glb.

Run by the app in the background:
    blender -b asset.blend --factory-startup -P blend_to_glb.py -- out.glb

Exports every visible mesh/curve/text object of the file (modifiers applied,
textures embedded). Materials keep their base colours/textures; complex
shader nodes are simplified by Blender's glTF exporter.
Prints "SB_RESULT ok <path>" or "SB_RESULT error <message>".
"""
import os
import sys

import bpy


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not argv:
        print("SB_RESULT error no output path given")
        return
    out = os.path.abspath(argv[0])
    os.makedirs(os.path.dirname(out), exist_ok=True)

    # Find textures that sit next to the .blend (unpacked resolutions).
    try:
        bpy.ops.file.find_missing_files(directory=os.path.dirname(bpy.data.filepath))
    except Exception:
        pass

    scene = bpy.context.scene
    keep = {"MESH", "CURVE", "SURFACE", "META", "FONT", "EMPTY"}
    # Assets often sit in a collection that isn't linked to the scene.
    linked = set(scene.collection.all_objects)
    for coll in bpy.data.collections:
        if coll.users and not any(o in linked for o in coll.all_objects):
            try:
                scene.collection.children.link(coll)
            except RuntimeError:
                pass
    for obj in bpy.data.objects:
        if obj.type in keep and obj.name not in scene.collection.all_objects:
            try:
                scene.collection.objects.link(obj)
            except RuntimeError:
                pass

    for layer_coll in bpy.context.view_layer.layer_collection.children:
        layer_coll.exclude = False
    meshes = 0
    for obj in scene.objects:
        if obj.type in {"MESH", "CURVE", "SURFACE", "META", "FONT"}:
            obj.hide_set(False)
            obj.hide_viewport = False
            meshes += 1
        elif obj.type in {"CAMERA", "LIGHT"}:
            obj.hide_set(True)
    if meshes == 0:
        print("SB_RESULT error the file has no 3D objects to export")
        return

    kwargs = dict(
        filepath=out,
        export_format="GLB",
        use_visible=True,
        export_apply=True,
        export_cameras=False,
        export_lights=False,
        export_yup=True,
    )
    try:
        bpy.ops.export_scene.gltf(**kwargs)
    except TypeError:
        kwargs.pop("use_visible", None)
        bpy.ops.export_scene.gltf(**kwargs)
    if os.path.exists(out) and os.path.getsize(out) > 0:
        print("SB_RESULT ok " + out)
    else:
        print("SB_RESULT error Blender didn't write the file")


try:
    main()
except Exception as exc:  # report, never hang
    print("SB_RESULT error %s" % exc)

"""Scene Builder - Avatar Builder (runs inside Blender with the MPFB2 add-on).

Builds a realistic, rigged human with MPFB2 (MakeHuman for Blender) from a
settings file written by Scene Builder, and exports it as a .glb that Scene
Builder imports into "My Characters".

Run by Scene Builder, or by hand:
    blender -b --python build_avatar.py -- settings.json output.glb

Requirements: Blender 4.x with MPFB2 enabled (Edit > Preferences > Add-ons /
Extensions), and preferably the MakeHuman "system assets" pack installed from
MPFB's Apply Assets panel (skins, hair, eyebrows, clothes). Without the asset
pack you still get a correctly shaped, rigged body with the default skin.

MPFB2's Python services are used where available; every optional step is
wrapped so one missing asset never stops the build.
"""

import importlib
import json
import os
import sys
import traceback

import bpy
import addon_utils

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import face_tools
except Exception:  # noqa: BLE001 - numpy missing in a very old Blender
    face_tools = None
    traceback.print_exc()


def log(message):
    print("[avatar] " + str(message), flush=True)


def find_mpfb():
    """Enable MPFB2 (legacy add-on or Blender 4.2+ extension); return its package name."""
    candidates = []
    for module in addon_utils.modules():
        name = module.__name__
        if name == "mpfb" or name.endswith(".mpfb"):
            candidates.append(name)
    for name in candidates:
        # MPFB needs its preferences, which only exist when it's enabled as a
        # normal (default) add-on; try without changing the user's setup first.
        for default_set in (False, True):
            try:
                addon_utils.enable(name, default_set=default_set, persistent=False)
                importlib.import_module(name + ".services.humanservice")
                return name
            except Exception:  # noqa: BLE001 - try again / the next candidate
                if default_set:
                    traceback.print_exc()
                for module in [m for m in sys.modules if m.startswith(name + ".services")]:
                    del sys.modules[module]
    return None


def service(package, module, cls):
    return getattr(importlib.import_module("%s.services.%s" % (package, module)), cls)


def asset_roots(package):
    """Folders where MPFB keeps its own and user-installed assets."""
    roots = []
    try:
        location = service(package, "locationservice", "LocationService")
        for getter in ("get_user_data", "get_mpfb_data", "get_second_root"):
            try:
                path = getattr(location, getter)()
                if path and os.path.isdir(path):
                    roots.append(path)
            except Exception:  # noqa: BLE001
                pass
    except Exception:  # noqa: BLE001
        pass
    module = importlib.import_module(package)
    data = os.path.join(os.path.dirname(module.__file__), "data")
    if os.path.isdir(data):
        roots.append(data)
    return roots


def find_asset(roots, folder, extension, keywords, exclude=()):
    """First file under <root>/<folder> whose name contains every keyword."""
    best = None
    for root in roots:
        base = os.path.join(root, folder)
        if not os.path.isdir(base):
            continue
        for directory, _dirs, files in os.walk(base):
            for file_name in sorted(files):
                lower = file_name.lower()
                if not lower.endswith(extension):
                    continue
                if any(word in lower for word in exclude):
                    continue
                if all(word in lower for word in keywords):
                    return os.path.join(directory, file_name)
                if best is None and keywords and keywords[0] in lower:
                    best = os.path.join(directory, file_name)
    return best


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


def create_body(package, settings):
    human = service(package, "humanservice", "HumanService")
    race = settings.get("race", {})
    macro = {
        "gender": settings.get("gender", 0.5),
        "age": settings.get("age", 0.5),
        "muscle": settings.get("muscle", 0.5),
        "weight": settings.get("weight", 0.5),
        "height": settings.get("height", 0.5),
        "proportions": settings.get("proportions", 0.5),
        "cupsize": 0.5,
        "firmness": 0.5,
        "race": {
            "african": race.get("african", 0.33),
            "asian": race.get("asian", 0.33),
            "caucasian": race.get("caucasian", 0.34),
        },
    }
    try:
        return human.create_human(macro_detail_dict=macro)
    except TypeError:
        basemesh = human.create_human()
        try:
            props = importlib.import_module(package + ".entities.objectproperties").HumanObjectProperties
            for key in ("gender", "age", "muscle", "weight", "height", "proportions"):
                props.set_value(key, macro[key], entity_reference=basemesh)
            for key, value in macro["race"].items():
                props.set_value(key, value, entity_reference=basemesh)
            target = service(package, "targetservice", "TargetService")
            target.reapply_macro_details(basemesh)
        except Exception:  # noqa: BLE001
            log("Could not set body shape: " + traceback.format_exc())
        return basemesh


def add_rig(package, basemesh, rig):
    human = service(package, "humanservice", "HumanService")
    try:
        human.add_builtin_rig(basemesh, rig, import_weights=True)
    except TypeError:
        human.add_builtin_rig(basemesh, rig)


def add_proxy_file(package, basemesh, path, asset_type, prefix=""):
    """Adds one specific .mhclo file (from Avatar Studio's asset list)."""
    if not path or not os.path.exists(path):
        log("Missing asset file: %s" % path)
        return False
    human = service(package, "humanservice", "HumanService")
    with renamed_new_objects(prefix):
        try:
            human.add_mhclo_asset(path, basemesh, asset_type=asset_type, subdiv_levels=0, material_type="MAKESKIN")
        except TypeError:
            human.add_mhclo_asset(path, basemesh, asset_type=asset_type)
        except Exception:  # noqa: BLE001
            log("Could not add %s: %s" % (path, traceback.format_exc()))
            return False
    log("%s: %s" % (asset_type, os.path.basename(path)))
    return True


def set_skin(package, basemesh, roots, settings):
    human = service(package, "humanservice", "HumanService")
    keywords = settings.get("skin_keywords", [])
    path = settings.get("skin_path") or None
    if path and not os.path.exists(path):
        path = None
    if path is None:
        path = find_asset(roots, "skins", ".mhmat", keywords) if keywords else None
    if path is None:
        path = find_asset(roots, "skins", ".mhmat", ["default"])
    if path is None:
        log("No skin files found; keeping MPFB's default skin.")
        return
    for skin_type in ("GAMEENGINE", "MAKESKIN"):
        try:
            human.set_character_skin(path, basemesh, skin_type=skin_type)
            log("Skin: " + os.path.basename(path))
            return
        except Exception:  # noqa: BLE001
            continue
    log("Could not apply skin " + path)


def add_proxy(package, basemesh, roots, folder, asset_type, keywords, exclude=()):
    human = service(package, "humanservice", "HumanService")
    path = find_asset(roots, folder, ".mhclo", keywords, exclude)
    if path is None:
        log("No %s matching %s (install MPFB's system assets for more)." % (folder, keywords))
        return False
    try:
        human.add_mhclo_asset(path, basemesh, asset_type=asset_type, subdiv_levels=0, material_type="MAKESKIN")
        log("%s: %s" % (asset_type, os.path.basename(path)))
        return True
    except TypeError:
        try:
            human.add_mhclo_asset(path, basemesh, asset_type=asset_type)
            log("%s: %s" % (asset_type, os.path.basename(path)))
            return True
        except Exception:  # noqa: BLE001
            log("Could not add %s: %s" % (path, traceback.format_exc()))
    except Exception:  # noqa: BLE001
        log("Could not add %s: %s" % (path, traceback.format_exc()))
    return False


def find_rig(basemesh=None):
    """The body's skeleton: the armature the body is parented to or deformed by."""
    if basemesh is not None:
        if basemesh.parent is not None and basemesh.parent.type == "ARMATURE":
            return basemesh.parent
        for modifier in basemesh.modifiers:
            if modifier.type == "ARMATURE" and modifier.object is not None:
                return modifier.object
    for obj in bpy.data.objects:
        if obj.type == "ARMATURE":
            return obj
    return None


def is_bound(obj, rig):
    """True when obj is deformed by rig AND has weights for its bones."""
    if not any(m.type == "ARMATURE" and m.object == rig for m in obj.modifiers):
        return False
    bone_names = {bone.name for bone in rig.data.bones}
    groups = [g for g in obj.vertex_groups if g.name in bone_names]
    if not groups:
        return False
    indices = {g.index for g in groups}
    for vertex in obj.data.vertices[: min(len(obj.data.vertices), 200)]:
        for element in vertex.groups:
            if element.group in indices and element.weight > 0.0:
                return True
    return False


def bind_loose_meshes(basemesh):
    """Safety net: any mesh (clothes, hair, eyes…) that isn't driven by the
    skeleton gets the body's skin weights copied over and an armature
    modifier, so it moves with the character."""
    rig = find_rig(basemesh)
    if rig is None:
        log("WARNING: no skeleton was created; the character can't be animated.")
        return
    for obj in list(bpy.data.objects):
        if obj.type != "MESH" or obj == basemesh:
            continue
        # One skeleton for everything: drop armature modifiers pointing at other rigs.
        for modifier in list(obj.modifiers):
            if modifier.type == "ARMATURE" and modifier.object != rig:
                obj.modifiers.remove(modifier)
        if is_bound(obj, rig):
            log("%s already moves with the skeleton." % obj.name)
            continue
        for modifier in list(obj.modifiers):
            if modifier.type == "ARMATURE":
                obj.modifiers.remove(modifier)
        try:
            matrix = obj.matrix_world.copy()
            obj.parent = rig
            obj.matrix_world = matrix
            transfer = obj.modifiers.new("SB_Weights", "DATA_TRANSFER")
            transfer.object = basemesh
            transfer.use_vert_data = True
            transfer.data_types_verts = {"VGROUP_WEIGHTS"}
            transfer.vert_mapping = "POLYINTERP_NEAREST"
            transfer.layers_vgroup_select_src = "ALL"
            transfer.layers_vgroup_select_dst = "NAME"
            with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
                bpy.ops.object.datalayout_transfer(modifier=transfer.name)
                bpy.ops.object.modifier_apply(modifier=transfer.name)
            armature = obj.modifiers.new("Armature", "ARMATURE")
            armature.object = rig
            log("Bound %s to the skeleton." % obj.name)
        except Exception:  # noqa: BLE001
            log("Could not bind %s: %s" % (obj.name, traceback.format_exc()))


class renamed_new_objects:
    """Prefixes the names of objects created inside the with-block."""

    def __init__(self, prefix):
        self.prefix = prefix.replace(" ", "_")
        self.before = set()

    def __enter__(self):
        self.before = {obj.name for obj in bpy.data.objects}
        return self

    def __exit__(self, *_args):
        for obj in bpy.data.objects:
            if obj.name not in self.before and obj.type == "MESH":
                obj.name = self.prefix + obj.name
        return False


def _base_color_node(material):
    """(nodes, links, principled, image node feeding Base Color or None)."""
    if material is None or not material.use_nodes:
        return None, None, None, None
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return nodes, links, None, None
    socket = bsdf.inputs.get("Base Color")
    image_node = None
    stack = [link.from_node for link in socket.links] if socket else []
    while stack:
        node = stack.pop()
        if node.type == "TEX_IMAGE" and node.image is not None:
            image_node = node
            break
        for inp in node.inputs:
            stack.extend(link.from_node for link in inp.links)
    return nodes, links, bsdf, image_node


def apply_face_photo(basemesh, settings, out_dir):
    """Paints a front photo onto the face of the skin texture.

    The user marked the two eyes and the mouth on the photo; the same points on
    the avatar (eyes from the eye mesh, mouth estimated from eye spacing) give an
    exact 2D mapping. Every skin-texture triangle on the front of the head is
    filled from the photo, feathered into the rest of the skin."""
    photo_path = settings.get("face_photo", "")
    points = settings.get("face_points", {})
    if not photo_path or not os.path.exists(photo_path) or len(points) < 3:
        return
    try:
        import numpy as np
    except ImportError:
        log("Face photo skipped: numpy is not available in this Blender.")
        return
    strength = float(settings.get("face_strength", 0.85))
    material = basemesh.active_material or (basemesh.material_slots[0].material if basemesh.material_slots else None)
    nodes, links, bsdf, image_node = _base_color_node(material)
    if bsdf is None:
        log("Face photo skipped: the skin material has no Principled BSDF.")
        return
    if image_node is None:
        base = bsdf.inputs["Base Color"].default_value
        img = bpy.data.images.new("SB_SkinBase", 2048, 2048)
        img.pixels.foreach_set(np.tile(np.array(base, dtype=np.float32), 2048 * 2048))
        image_node = nodes.new("ShaderNodeTexImage")
        image_node.image = img
        links.new(image_node.outputs["Color"], bsdf.inputs["Base Color"])
    base_img = image_node.image
    width, height = base_img.size
    base = np.empty(width * height * 4, dtype=np.float32)
    base_img.pixels.foreach_get(base)
    base = base.reshape(height, width, 4)

    photo_img = bpy.data.images.load(photo_path)
    pw, ph = photo_img.size
    photo = np.empty(pw * ph * 4, dtype=np.float32)
    photo_img.pixels.foreach_get(photo)
    photo = photo.reshape(ph, pw, 4)
    if photo_img.colorspace_settings.name != base_img.colorspace_settings.name:
        pass  # both are normally sRGB; Blender stores them the same way

    # 3D landmarks (front view: x to the side, z up; the avatar faces -Y).
    eyes = next((o for o in bpy.data.objects if o.type == "MESH" and "eye" in o.name.lower()
                 and "brow" not in o.name.lower() and "lash" not in o.name.lower()), None)
    if eyes is None:
        log("Face photo skipped: no eye mesh found.")
        return
    coords = np.array([tuple(eyes.matrix_world @ v.co) for v in eyes.data.vertices])
    left = coords[coords[:, 0] < 0].mean(axis=0)   # picture-left eye
    right = coords[coords[:, 0] >= 0].mean(axis=0)
    mid = (left + right) / 2.0
    spacing = float(np.linalg.norm(right - left))
    mouth = mid + np.array([0.0, 0.0, -1.1 * spacing])
    src = np.array([[left[0], left[2], 1.0], [right[0], right[2], 1.0], [mouth[0], mouth[2], 1.0]])
    uv_targets = []
    for key in ("left_eye", "right_eye", "mouth"):
        u, v = points[key]
        uv_targets.append([u * pw, (1.0 - v) * ph])   # Blender images start at the bottom row
    mapping = np.linalg.solve(src, np.array(uv_targets))   # (x, z, 1) -> photo pixel

    # Soft ellipse around the face in photo pixels.
    face_centre = np.array(uv_targets).mean(axis=0) + (np.array(uv_targets[2]) - np.array(uv_targets[:2]).mean(axis=0)) * -0.15
    photo_spacing = float(np.linalg.norm(np.array(uv_targets[1]) - np.array(uv_targets[0])))
    radii = np.array([1.25, 1.75]) * photo_spacing

    mesh = basemesh.data
    uv_layer = mesh.uv_layers[0].data
    mesh.calc_loop_triangles()
    world = basemesh.matrix_world
    normal_matrix = world.to_3x3()
    out = base.copy()
    weight = np.zeros((height, width), dtype=np.float32)
    head_top = mid[2] + 2.4 * spacing
    chin = mid[2] - 2.2 * spacing
    painted = 0
    for tri in mesh.loop_triangles:
        verts = [world @ mesh.vertices[i].co for i in tri.vertices]
        centre_z = sum(v.z for v in verts) / 3.0
        centre_x = sum(v.x for v in verts) / 3.0
        if not (chin < centre_z < head_top) or abs(centre_x - mid[0]) > 1.9 * spacing:
            continue
        if (normal_matrix @ tri.normal).y > -0.25:   # only the front of the head
            continue
        skin = np.array([[uv_layer[l].uv[0] * width, uv_layer[l].uv[1] * height] for l in tri.loops])
        pix = np.array([mapping.T @ np.array([v.x, v.z, 1.0]) for v in verts])
        x0, y0 = np.floor(skin.min(axis=0)).astype(int)
        x1, y1 = np.ceil(skin.max(axis=0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, width - 1), min(y1, height - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        (ax, ay), (bx, by), (cx, cy) = skin
        det = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(det) < 1e-9:
            continue
        w1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / det
        w2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / det
        w3 = 1.0 - w1 - w2
        inside = (w1 >= -0.01) & (w2 >= -0.01) & (w3 >= -0.01)
        if not inside.any():
            continue
        px = w1 * pix[0, 0] + w2 * pix[1, 0] + w3 * pix[2, 0]
        py = w1 * pix[0, 1] + w2 * pix[1, 1] + w3 * pix[2, 1]
        ex = (px - face_centre[0]) / radii[0]
        ey = (py - face_centre[1]) / radii[1]
        fade = np.clip((1.0 - np.sqrt(ex * ex + ey * ey)) / 0.35, 0.0, 1.0)
        fade = fade * fade * (3.0 - 2.0 * fade)
        valid = inside & (px >= 0) & (px < pw - 1) & (py >= 0) & (py < ph - 1) & (fade > 0)
        if not valid.any():
            continue
        ys, xs = np.nonzero(valid)
        colours = photo[py[valid].astype(int), px[valid].astype(int), :3]
        target_y = ys + y0
        target_x = xs + x0
        out[target_y, target_x, :3] = colours
        weight[target_y, target_x] = np.maximum(weight[target_y, target_x], fade[valid])
        painted += int(valid.sum())
    if painted == 0:
        log("Face photo: nothing was painted (check the eye and mouth marks).")
        return
    # Bring the photo's overall skin tone halfway towards the body's so the
    # edges blend, then mix it in with the feathered mask.
    mask = weight > 0.5
    if mask.any():
        ratio = np.clip(base[mask, :3].mean(axis=0) / np.maximum(out[mask, :3].mean(axis=0), 1e-4), 0.6, 1.6)
        out[..., :3] *= 1.0 + (ratio - 1.0) * 0.5
    blend = (weight * strength)[..., None]
    result = base.copy()
    result[..., :3] = base[..., :3] * (1.0 - blend) + out[..., :3] * blend
    new_img = bpy.data.images.new("SB_FaceSkin", width, height)
    new_img.pixels.foreach_set(result.astype(np.float32).ravel())
    path = os.path.join(out_dir, "face_skin_%d.png" % abs(hash(photo_path)) )
    new_img.filepath_raw = path
    new_img.file_format = "PNG"
    new_img.save()
    image_node.image = new_img
    log("Face photo applied (%d texture pixels)." % painted)


def mpfb_data(package):
    return os.path.join(os.path.dirname(importlib.import_module(package).__file__), "data")


def expression_units_dir(package, settings):
    """MakeHuman's expression units for the body's main ethnicity."""
    race = settings.get("race", {})
    main = max(("african", "asian", "caucasian"), key=lambda k: float(race.get(k, 0.33)))
    units = os.path.join(mpfb_data(package), "targets", "expression", "units")
    for name in (main, "caucasian", "african", "asian"):
        if os.path.isdir(os.path.join(units, name)):
            return os.path.join(units, name)
    return ""


def target_loader(package):
    try:
        ts = service(package, "targetservice", "TargetService")
    except Exception:  # noqa: BLE001
        return None
    return lambda obj, path, weight, name: ts.load_target(obj, path, weight=weight, name=name)


def new_face_marks(settings, key):
    """The detailed face marks (18 front / 5 side points), or {}."""
    points = settings.get(key, {})
    if not isinstance(points, dict) or face_tools is None:
        return {}
    wanted = face_tools.FRONT_POINTS if key == "face_points" else face_tools.SIDE_POINTS
    return {k: v for k, v in points.items() if k in wanted and isinstance(v, (list, tuple)) and len(v) == 2}


def image_size(path):
    try:
        img = bpy.data.images.load(path, check_existing=False)
        size = tuple(img.size)
        bpy.data.images.remove(img)
        return size
    except Exception:  # noqa: BLE001
        return (1, 1)


def export(output, basemesh=None):
    # Put every mesh directly under the skeleton so the exported file has a
    # single rig that drives the body, clothes, hair and eyes together.
    rig = find_rig(basemesh)
    if rig is not None:
        for obj in bpy.data.objects:
            if obj.type == "MESH" and obj.parent != rig:
                matrix = obj.matrix_world.copy()
                obj.parent = rig
                obj.matrix_world = matrix
        for obj in list(bpy.data.objects):
            if obj.type == "ARMATURE" and obj != rig:
                bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.data.objects:
        if obj.type in {"MESH", "ARMATURE"}:
            obj.select_set(True)
    os.makedirs(os.path.dirname(output), exist_ok=True)
    kwargs = dict(filepath=output, export_format="GLB", use_selection=True, export_skins=True,
                  export_morph=True, export_animations=False, export_yup=True)
    # With face shape keys, nothing else may be applied (applying modifiers drops keys).
    has_keys = any(obj.type == "MESH" and obj.data.shape_keys for obj in bpy.data.objects)
    try:
        bpy.ops.export_scene.gltf(export_apply=not has_keys, **kwargs)
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 2:
        log("Usage: blender -b --python build_avatar.py -- settings.json output.glb")
        sys.exit(2)
    with open(argv[0], "r", encoding="utf-8") as handle:
        settings = json.load(handle)
    output = argv[1]

    package = find_mpfb()
    if package is None:
        log("ERROR: MPFB2 is not installed or not enabled in this Blender.")
        log("Install it from https://static.makehumancommunity.org/mpfb.html (or Blender's Extensions), enable it, and try again.")
        sys.exit(3)
    log("Using MPFB2 package: " + package)
    clear_scene()
    basemesh = create_body(package, settings)
    roots = asset_roots(package)
    log("Asset folders: " + ", ".join(roots))
    set_skin(package, basemesh, roots, settings)
    # Face from a photo, step 1: reshape the head so its features line up with the
    # marks on the photo(s). Done before the skeleton, eyes, brows and hair are
    # fitted, so they all follow the new shape.
    front_marks = new_face_marks(settings, "face_points")
    side_marks = new_face_marks(settings, "face_side_points")
    photo = settings.get("face_photo", "")
    side_photo = settings.get("face_side_photo", "")
    units_dir = expression_units_dir(package, settings)
    targets_dir = os.path.join(mpfb_data(package), "targets")
    loader = target_loader(package)
    landmarks = {}
    if face_tools is not None and (len(front_marks) >= 8 or settings.get("talking_face", True)):
        try:
            landmarks = face_tools.find_landmarks(basemesh, units_dir)
        except Exception:  # noqa: BLE001
            log("Face landmarks: " + traceback.format_exc())
    if landmarks and len(front_marks) >= 8 and photo and os.path.exists(photo) and settings.get("face_fit", True):
        try:
            face_tools.fit_face(basemesh, targets_dir, landmarks, front_marks,
                                side_marks if side_photo and os.path.exists(side_photo) else None,
                                image_size(photo), image_size(side_photo) if side_photo else (1, 1),
                                strength=float(settings.get("face_fit_strength", 1.0)), log=log, loader=loader)
        except Exception:  # noqa: BLE001
            log("Face fit failed: " + traceback.format_exc())
    # The skeleton must exist BEFORE clothes/hair are added: MPFB only binds
    # proxies to the rig (armature modifier + weights) when there is one.
    add_rig(package, basemesh, settings.get("rig", "game_engine"))
    add_proxy(package, basemesh, roots, "eyes", "Eyes", ["low-poly"]) or add_proxy(package, basemesh, roots, "eyes", "Eyes", [])
    if settings.get("eyebrows", True):
        add_proxy(package, basemesh, roots, "eyebrows", "Eyebrows", ["eyebrow001"]) or add_proxy(package, basemesh, roots, "eyebrows", "Eyebrows", [])
    if settings.get("eyelashes", True):
        add_proxy(package, basemesh, roots, "eyelashes", "Eyelashes", [])
    wardrobe = settings.get("wardrobe", {})
    if "clothes_paths" in settings:
        # Exact items picked in Avatar Studio's lists. Each piece is named
        # "Clothes-<item>-…" (shown/hidden one by one in the Look tab); with
        # extra hairstyles every hair is "Hair-<style>-…" so it can be switched.
        hair_paths = [settings.get("hair_path", "")] + list(settings.get("extra_hair_paths", []))
        hair_paths = [p for i, p in enumerate(hair_paths) if p and p not in hair_paths[:i]]
        for path in hair_paths:
            name = os.path.splitext(os.path.basename(path))[0]
            add_proxy_file(package, basemesh, path, "Hair", "Hair-%s--" % name if len(hair_paths) > 1 else "")
        for path in settings.get("clothes_paths", []):
            name = os.path.splitext(os.path.basename(path))[0]
            add_proxy_file(package, basemesh, path, "Clothes", "Clothes-%s--" % name)
        if settings.get("keep_body", False):
            for modifier in list(basemesh.modifiers):
                if modifier.type == "MASK" and "helper" not in modifier.name.lower():
                    basemesh.modifiers.remove(modifier)
    elif wardrobe:
        # Every outfit and hairstyle is added and named "Outfit-<name>-…" /
        # "Hair-<name>-…", so Scene Builder can switch them instantly.
        for style, keyword in wardrobe.get("hair", {}).items():
            if keyword:
                with renamed_new_objects("Hair-%s--" % style):
                    add_proxy(package, basemesh, roots, "hair", "Hair", [keyword])
        for outfit, pieces in wardrobe.get("outfits", {}).items():
            with renamed_new_objects("Outfit-%s--" % outfit):
                for keywords in pieces:
                    add_proxy(package, basemesh, roots, "clothes", "Clothes", keywords)
        # Clothes normally hide the body underneath; with several outfits that
        # would leave holes, so keep the whole body.
        for modifier in list(basemesh.modifiers):
            if modifier.type == "MASK" and "helper" not in modifier.name.lower():
                basemesh.modifiers.remove(modifier)
    else:
        hair = settings.get("hair", "")
        if hair:
            add_proxy(package, basemesh, roots, "hair", "Hair", [hair])
        for keywords in settings.get("clothes", []):
            add_proxy(package, basemesh, roots, "clothes", "Clothes", keywords)
    # Step 2: talking and blinking (shape keys Scene Builder animates).
    expression_keys = []
    if landmarks and settings.get("talking_face", True):
        try:
            expression_keys = face_tools.add_expressions(basemesh, units_dir, targets_dir, log=log, loader=loader)
        except Exception:  # noqa: BLE001
            log("Talking face failed: " + traceback.format_exc())
        try:
            face_tools.add_mouth_inside(basemesh, landmarks, log=log)
        except Exception:  # noqa: BLE001
            log("Mouth inside failed: " + traceback.format_exc())
    # Step 3: paint the photo(s) onto the skin.
    if landmarks and len(front_marks) >= 8 and photo and os.path.exists(photo):
        try:
            face_tools.paint_face(basemesh, landmarks, photo, front_marks,
                                  side_photo if side_photo and os.path.exists(side_photo) else None, side_marks,
                                  strength=float(settings.get("face_strength", 0.9)), out_dir=os.path.dirname(output),
                                  log=log, even_light=settings.get("face_even_light", True))
        except Exception:  # noqa: BLE001
            log("Face painting failed: " + traceback.format_exc())
    else:
        apply_face_photo(basemesh, settings, os.path.dirname(output))   # older 3-point marks
        if expression_keys:
            try:
                face_tools.darken_mouth_only(basemesh, landmarks)
            except Exception:  # noqa: BLE001
                log("Mouth colour: " + traceback.format_exc())
    bind_loose_meshes(basemesh)
    if face_tools is not None:
        # Fold the body shape into the mesh and keep only the expression keys.
        for obj in bpy.data.objects:
            if obj.type == "MESH" and obj.data.shape_keys:
                face_tools.bake_shape_keys(obj, set(expression_keys))
        if expression_keys:
            face_tools.apply_masks_keep_keys(basemesh)
    export(output, basemesh)
    if os.path.exists(output):
        log("DONE " + output)
    else:
        log("ERROR: export failed.")
        sys.exit(4)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:  # noqa: BLE001
        log("ERROR: " + traceback.format_exc())
        sys.exit(1)

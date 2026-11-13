"""Scene Builder - face tools for Avatar Studio (run inside Blender by build_avatar.py).

* find_landmarks():    18 front + 5 profile points on the MakeHuman base mesh, found
                       from what MakeHuman's own expression shapes move, so they are
                       exact on any body.
* fit_face():          sets MakeHuman's face sliders (head shape, jaw, chin, cheeks,
                       eyes, nose, mouth, brows) so those points line up with the points
                       marked on a front photo (and, optionally, a side photo).
* paint_face():        warps the photo onto the skin texture through every point (thin-
                       plate spline), evens out harsh lighting, matches the body's skin
                       tone, and fills the sides of the face from a side photo.
* add_expressions():   jawOpen / eyeBlinkLeft / eyeBlinkRight / mouthSmile shape keys
                       (from MakeHuman's expression units), copied to eyebrows and
                       eyelashes, so avatars lip-sync and blink in Scene Builder.
"""
import gzip
import os

import bpy
import numpy as np

# Front-photo points (picture left/right = the person's right/left in a
# non-mirrored photo; the avatar faces -Y, so picture left = -X).
FRONT_POINTS = ["brow_l", "brow_r", "eye_l_out", "eye_l_in", "eye_r_in", "eye_r_out", "nose_tip", "nose_l", "nose_r",
                "mouth_l", "mouth_r", "lip_top", "lip_bottom", "chin", "jaw_l", "jaw_r", "cheek_l", "cheek_r"]
# Side-photo points (profile).
SIDE_POINTS = ["side_eye", "side_nose", "side_mouth", "side_chin", "side_ear"]


def mesh_positions(obj):
    """World positions of every vertex with the current shape key mix."""
    me = obj.data
    co = np.empty(len(me.vertices) * 3, dtype=np.float64)
    if me.shape_keys:
        keys = me.shape_keys.key_blocks
        basis = np.empty_like(co)
        keys[0].data.foreach_get("co", basis)
        co[:] = basis
        for key in keys[1:]:
            if key.value == 0.0 or key.mute:
                continue
            data = np.empty_like(co)
            key.data.foreach_get("co", data)
            co += (data - basis) * key.value
    else:
        me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    m = np.array(obj.matrix_world)
    return co @ m[:3, :3].T + m[:3, 3]


def group_mask(obj, name, threshold=0.5):
    me = obj.data
    mask = np.zeros(len(me.vertices), dtype=bool)
    group = obj.vertex_groups.get(name)
    if group is None:
        return mask
    gi = group.index
    for v in me.vertices:
        for g in v.groups:
            if g.group == gi and g.weight > threshold:
                mask[v.index] = True
                break
    return mask


def target_motion(path, count):
    """How far each vertex moves in a MakeHuman .target(.gz) file."""
    motion = np.zeros(count)
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt") as handle:
        for line in handle:
            parts = line.split()
            if len(parts) == 4 and parts[0].isdigit():
                i = int(parts[0])
                if i < count:
                    motion[i] = np.linalg.norm([float(parts[1]), float(parts[2]), float(parts[3])])
    return motion


def find_landmarks_by_expressions(obj, units_dir):
    """Landmarks from what MakeHuman's expression units move: puckering moves
    the lips, flaring the nostril wings, raising the brows the brows, closing an
    eye the eyelid from corner to corner. Exact on any body shape."""
    co = mesh_positions(obj)
    n = len(co)
    body = group_mask(obj, "body")

    def region(name, share):
        m = target_motion(os.path.join(units_dir, name + ".target.gz"), n)
        m[~body] = 0.0
        return np.nonzero(m > m.max() * share)[0], m

    out = {}
    # Pushing the lips forward moves exactly the red of the lips.
    lips, _ = region("mouth-protusion", 0.6)
    lp = co[lips]
    out["mouth_l"] = int(lips[np.argmin(lp[:, 0])])
    out["mouth_r"] = int(lips[np.argmax(lp[:, 0])])
    mid = np.abs(lp[:, 0]) < 0.004
    out["lip_top"] = int(lips[mid][np.argmax(lp[mid, 2])])
    out["lip_bottom"] = int(lips[mid][np.argmin(lp[mid, 2])])
    for picture, side in (("l", "right"), ("r", "left")):
        wing, _ = region("nose-%s-dilatation" % side, 0.5)
        w = co[wing]
        out["nose_%s" % picture] = int(wing[np.argmax(np.abs(w[:, 0]))])
        brow, motion = region("eyebrows-%s-up" % side, 0.6)
        b = co[brow]
        centre = b.mean(axis=0)
        out["brow_%s" % picture] = int(brow[np.argmin(np.linalg.norm(b[:, [0, 2]] - centre[[0, 2]], axis=1))])
        lid, _ = region("eye-%s-closure" % side, 0.12)
        e = co[lid]
        outward = -1.0 if picture == "l" else 1.0
        out["eye_%s_out" % picture] = int(lid[np.argmax(e[:, 0] * outward)])
        out["eye_%s_in" % picture] = int(lid[np.argmin(e[:, 0] * outward)])
    return out


def find_landmarks(obj, units_dir=None):
    """{point name: vertex index} for FRONT_POINTS and SIDE_POINTS (side = the
    avatar's right side, x < 0, matching a profile photo)."""
    co = mesh_positions(obj)
    body = group_mask(obj, "body")
    idx = np.nonzero(body)[0]
    p = co[idx]
    out = {}

    def pick(cond, score):
        sel = np.nonzero(cond)[0]
        if len(sel) == 0:
            return None
        return int(idx[sel[np.argmin(score[sel])]])

    eyes = {}
    for side, name in (("l", "helper-l-eye"), ("r", "helper-r-eye")):
        e = co[group_mask(obj, name)]
        centre = e.mean(axis=0)
        radius = np.linalg.norm(e - centre, axis=1).mean()
        eyes[side] = (centre, radius)
    # helper-l-eye is the person's left (+X) = picture right.
    (cl, rl), (cr, rr) = eyes["l"], eyes["r"]
    for picture, (centre, radius) in (("l", (cr, rr)), ("r", (cl, rl))):
        d = np.linalg.norm(p - centre, axis=1)
        rim = (d < radius * 1.35) & (p[:, 1] < centre[1]) & (np.abs(p[:, 2] - centre[2]) < radius * 0.6)
        outward = np.sign(centre[0])
        out["eye_%s_out" % picture] = pick(rim, -p[:, 0] * outward)
        out["eye_%s_in" % picture] = pick(rim, p[:, 0] * outward)
        brow_z = centre[2] + radius * 2.2
        out["brow_%s" % picture] = pick((np.abs(p[:, 2] - brow_z) < 0.004) & (np.abs(p[:, 0] - centre[0]) < 0.006) & (p[:, 1] < centre[1]), p[:, 1])
    eye_z = (cl[2] + cr[2]) / 2.0
    spacing = abs(cl[0] - cr[0])
    mid = np.abs(p[:, 0]) < 0.0025
    teeth = co[group_mask(obj, "helper-upper-teeth")].mean(axis=0)
    # Nose tip: the front-most point of the midline between the eyes and the teeth.
    out["nose_tip"] = pick(mid & (p[:, 2] < eye_z - 0.01) & (p[:, 2] > teeth[2] + 0.005), p[:, 1])
    tip = co[out["nose_tip"]]
    wing = (p[:, 2] < tip[2] + 0.004) & (p[:, 2] > tip[2] - 0.02) & (p[:, 1] < tip[1] + 0.03)
    out["nose_l"] = pick(wing & (p[:, 0] < 0), p[:, 0])
    out["nose_r"] = pick(wing & (p[:, 0] > 0), -p[:, 0])
    # Lips along the midline: the upper lip and lower lip stick out; the mouth
    # line is the dent between them, just in front of the teeth.
    lips = mid & (p[:, 2] < tip[2] - 0.012) & (p[:, 2] > teeth[2] - 0.035) & (p[:, 1] < teeth[1] - 0.004)
    ls = np.nonzero(lips)[0]
    order = ls[np.argsort(-p[ls, 2])]
    zs, ys = p[order, 2], p[order, 1]
    # Upper lip = front-most point above the teeth line, lower lip = front-most below.
    upper = order[zs > teeth[2] - 0.004]
    lower = order[zs <= teeth[2] - 0.004]
    up = upper[np.argmin(p[upper, 1])]
    lo = lower[np.argmin(p[lower, 1])]
    between = order[(zs < p[up, 2]) & (zs > p[lo, 2])]
    mouth_z = p[between[np.argmax(p[between, 1])], 2] if len(between) else (p[up, 2] + p[lo, 2]) / 2
    # Top of the upper lip / bottom of the lower lip: where the lip meets skin
    # (the midline profile turns back the most above/below the lips).
    above = order[(zs > p[up, 2]) & (zs < tip[2] - 0.006)]
    out["lip_top"] = int(idx[above[np.argmax(p[above, 1])]]) if len(above) else int(idx[up])
    below = order[(zs < p[lo, 2]) & (zs > p[lo, 2] - 0.02)]
    out["lip_bottom"] = int(idx[below[np.argmax(p[below, 1])]]) if len(below) else int(idx[lo])
    line = (np.abs(p[:, 2] - mouth_z) < 0.005) & (p[:, 1] < teeth[1] + 0.006)
    out["mouth_l"] = pick(line & (p[:, 0] < 0) & (np.abs(p[:, 0]) < spacing * 0.75), p[:, 0])
    out["mouth_r"] = pick(line & (p[:, 0] > 0) & (np.abs(p[:, 0]) < spacing * 0.75), -p[:, 0])
    # Chin: lowest midline point that is still at the front of the face.
    jaw_front = mid & (p[:, 2] < mouth_z - 0.03) & (p[:, 2] > mouth_z - 0.07)
    front_y = p[jaw_front, 1].min()
    out["chin"] = pick(mid & (p[:, 2] < mouth_z - 0.02) & (p[:, 2] > mouth_z - 0.1) & (p[:, 1] < front_y + 0.02), p[:, 2])
    # Face outline in a front view, excluding the ears (further back).
    head_front = p[:, 1] < tip[1] + 0.085
    out["jaw_l"] = pick((np.abs(p[:, 2] - mouth_z) < 0.005) & head_front & (p[:, 0] < 0), p[:, 0])
    out["jaw_r"] = pick((np.abs(p[:, 2] - mouth_z) < 0.005) & head_front & (p[:, 0] > 0), -p[:, 0])
    cheek_band = (np.abs(p[:, 2] - (eye_z - 0.012)) < 0.005) & (p[:, 1] < tip[1] + 0.07)
    out["cheek_l"] = pick(cheek_band & (p[:, 0] < 0), p[:, 0])
    out["cheek_r"] = pick(cheek_band & (p[:, 0] > 0), -p[:, 0])
    # Side (the avatar's right, x < 0): eye outer corner, nose tip, mouth corner, chin, ear.
    out["side_eye"] = out["eye_l_out"]
    out["side_nose"] = out["nose_tip"]
    out["side_mouth"] = out["mouth_l"]
    out["side_chin"] = out["chin"]
    ear = (p[:, 0] < -spacing * 0.9) & (p[:, 2] < eye_z) & (p[:, 2] > tip[2] - 0.01) & (p[:, 1] > tip[1] + 0.09) & (p[:, 1] < tip[1] + 0.2)
    out["side_ear"] = pick(ear, p[:, 0])
    if units_dir and os.path.isdir(units_dir):
        out.update(find_landmarks_by_expressions(obj, units_dir))
        out["side_eye"] = out["eye_l_out"]
        out["side_mouth"] = out["mouth_l"]
    return out


# --- Fitting the head shape to a photo --------------------------------------------------

# Face sliders the fit may use: (variable name, [target files moved together]).
# Left/right pairs move together (faces are fitted symmetrically).
def _pair(folder, stem, a, b):
    return [("%s-%s" % (stem, a), ["%s/%s-%s" % (folder, stem, a)]), ("%s-%s" % (stem, b), ["%s/%s-%s" % (folder, stem, b)])]


def _lr_pair(folder, stem, a, b):
    return [("%s-%s" % (stem, s), ["%s/l-%s-%s" % (folder, stem, s), "%s/r-%s-%s" % (folder, stem, s)]) for s in (a, b)]


FIT_VARIABLES = (
    _pair("head", "head-scale-horiz", "incr", "decr") + _pair("head", "head-scale-vert", "incr", "decr")
    + [("head-%s" % s, ["head/head-%s" % s]) for s in ("oval", "round", "square", "triangular", "invertedtriangular", "diamond", "rectangular")]
    + _pair("chin", "chin-width", "incr", "decr") + _pair("chin", "chin-height", "incr", "decr")
    + _pair("chin", "chin-bones", "incr", "decr") + _pair("chin", "chin-prominent", "incr", "decr")
    + _lr_pair("cheek", "cheek-bones", "incr", "decr") + _lr_pair("cheek", "cheek-trans", "up", "down")
    + _lr_pair("eyes", "eye-trans", "in", "out") + _lr_pair("eyes", "eye-trans", "up", "down") + _lr_pair("eyes", "eye-scale", "incr", "decr")
    + _pair("eyebrows", "eyebrows-trans", "up", "down")
    + _pair("nose", "nose-scale-horiz", "incr", "decr") + _pair("nose", "nose-scale-vert", "incr", "decr")
    + _pair("nose", "nose-trans", "up", "down") + _pair("nose", "nose-nostrils-width", "incr", "decr")
    + _pair("nose", "nose-trans", "forward", "backward") + _pair("nose", "nose-scale-depth", "incr", "decr")
    + _pair("mouth", "mouth-scale-horiz", "incr", "decr") + _pair("mouth", "mouth-trans", "up", "down")
    + _pair("mouth", "mouth-upperlip-height", "incr", "decr") + _pair("mouth", "mouth-lowerlip-height", "incr", "decr")
    + _pair("mouth", "mouth-trans", "forward", "backward")
)
# Outline points are less exact (hair, beard, shadows), so they count less.
POINT_WEIGHTS = {"jaw_l": 0.6, "jaw_r": 0.6, "cheek_l": 0.6, "cheek_r": 0.6, "chin": 0.8, "brow_l": 0.7, "brow_r": 0.7,
                 "side_ear": 0.5, "side_chin": 0.8}


def _normalise_front(points):
    """Points (name -> (x, up)) moved so the eyes' midpoint is the origin, the eyes
    are level, and the distance between the eye centres is 1."""
    a = (np.array(points["eye_l_out"]) + np.array(points["eye_l_in"])) / 2.0
    b = (np.array(points["eye_r_in"]) + np.array(points["eye_r_out"])) / 2.0
    d = b - a
    scale = np.linalg.norm(d)
    c, s = d / scale
    rot = np.array([[c, s], [-s, c]])
    origin = (a + b) / 2.0
    return {k: rot @ ((np.array(v) - origin) / scale) for k, v in points.items()}


def _normalise_side(points):
    """Profile points (name -> (forward, up)): eye corner at the origin, eye-to-chin length 1, the eye-chin line pointing straight down."""
    eye = np.array(points["side_eye"])
    chin = np.array(points["side_chin"])
    d = chin - eye
    scale = np.linalg.norm(d)
    angle = np.arctan2(d[0], -d[1])   # rotate so eye->chin points to (0, -1)
    c, s = np.cos(angle), np.sin(angle)
    rot = np.array([[c, -s], [s, c]])
    return {k: rot @ ((np.array(v) - eye) / scale) for k, v in points.items()}


def photo_points(front, side, front_size, side_size):
    """Photo marks (u, v from the top-left, 0..1) -> pixel points with y up.
    Side points get a "forward" axis that follows the way the face looks."""
    fw, fh = front_size
    f = {k: (float(v[0]) * fw, -float(v[1]) * fh) for k, v in front.items()} if front else {}
    s = {}
    if side and "side_nose" in side and "side_ear" in side:
        sw, sh = side_size
        facing = 1.0 if side["side_nose"][0] > side["side_ear"][0] else -1.0
        s = {k: (facing * float(v[0]) * sw, -float(v[1]) * sh) for k, v in side.items()}
    return f, s


def _mesh_front(co, lm):
    return {k: (co[i][0], co[i][2]) for k, i in lm.items() if not k.startswith("side") and i is not None}


def _mesh_side(co, lm):
    # The avatar looks towards -Y: forward = -y.
    return {k: (-co[i][1], co[i][2]) for k, i in lm.items() if k.startswith("side") and i is not None}


def _residuals(co, lm, front_n, side_n):
    out = []
    weights = []
    if front_n:
        mesh_n = _normalise_front(_mesh_front(co, lm))
        for k in sorted(front_n):
            if k in mesh_n:
                out.extend(front_n[k] - mesh_n[k])
                weights.extend([POINT_WEIGHTS.get(k, 1.0)] * 2)
    if side_n:
        mesh_s = _normalise_side(_mesh_side(co, lm))
        for k in sorted(side_n):
            if k in mesh_s and k not in ("side_eye", "side_chin"):
                out.extend(side_n[k] - mesh_s[k])
                weights.extend([POINT_WEIGHTS.get(k, 1.0)] * 2)
    return np.array(out), np.array(weights)


def fit_face(obj, targets_dir, lm, front, side=None, front_size=(1, 1), side_size=(1, 1), strength=1.0, log=print, loader=None):
    """Sets face sliders so the avatar's landmarks match the photo marks.
    Returns {slider: weight} (also applied as shape keys on obj)."""
    f, s = photo_points(front, side, front_size, side_size)
    needed = ["eye_l_out", "eye_l_in", "eye_r_in", "eye_r_out"]
    if not all(k in f for k in needed):
        log("Face fit skipped: mark both eyes' corners first.")
        return {}
    front_n = _normalise_front(f)
    side_n = _normalise_side(s) if s and "side_eye" in s and "side_chin" in s else {}
    base = mesh_positions(obj)
    m = np.array(obj.matrix_world)[:3, :3]
    scale = _offset_scale(obj, targets_dir, loader)
    rows = np.array(sorted(set(i for i in lm.values() if i is not None)))
    # Each variable's displacement of the landmark vertices (world space).
    deltas = []
    names = []
    for name, files in FIT_VARIABLES:
        total = np.zeros((len(rows), 3))
        ok = True
        for rel in files:
            path = os.path.join(targets_dir, rel + ".target.gz")
            if not os.path.exists(path):
                ok = False
                break
            motion = _target_offsets(path, len(base)) * scale
            total += motion[rows] @ m.T
        if ok:
            deltas.append(total)
            names.append(name)
    if not names:
        log("Face fit skipped: MakeHuman's face targets weren't found.")
        return {}
    index = {v: i for i, v in enumerate(rows)}

    def landmarks_at(w):
        co = {}
        moved = base[rows] + np.tensordot(w, np.array(deltas), axes=1)
        for k, i in lm.items():
            if i is not None:
                co[i] = moved[index[i]]
        return co

    w = np.zeros(len(names))
    r0, pw = _residuals(landmarks_at(w), lm, front_n, side_n)
    start = float(np.sqrt(np.mean((r0 * pw) ** 2)))
    ridge = 0.004
    for _ in range(8):
        r, pw = _residuals(landmarks_at(w), lm, front_n, side_n)
        jac = np.zeros((len(r), len(names)))
        for k in range(len(names)):
            step = np.zeros(len(names))
            step[k] = 0.25
            rk, _ = _residuals(landmarks_at(w + step), lm, front_n, side_n)
            jac[:, k] = (r - rk) / 0.25
        a = jac * pw[:, None]
        b = r * pw
        lhs = a.T @ a + ridge * np.eye(len(names))
        rhs = a.T @ b - ridge * w
        free = np.ones(len(names), dtype=bool)
        dw = np.zeros(len(names))
        for _ in range(6):   # bounded least squares: fix variables pushed past 0 or 1
            sub = np.linalg.solve(lhs[np.ix_(free, free)], rhs[free] - lhs[np.ix_(free, ~free)] @ dw[~free])
            dw[free] = sub
            new = w + dw
            out_low = free & (new < 0.0)
            out_high = free & (new > 1.0)
            if not (out_low.any() or out_high.any()):
                break
            dw[out_low] = -w[out_low]
            dw[out_high] = 1.0 - w[out_high]
            free &= ~(out_low | out_high)
        # Keep the step only if it improves the match (halve it otherwise).
        current = float(np.sum((r * pw) ** 2)) + ridge * float(np.sum(w * w))
        for _ in range(6):
            trial = np.clip(w + dw, 0.0, 1.0)
            rt, pwt = _residuals(landmarks_at(trial), lm, front_n, side_n)
            if float(np.sum((rt * pwt) ** 2)) + ridge * float(np.sum(trial * trial)) <= current:
                w = trial
                break
            dw *= 0.5
    w *= float(np.clip(strength, 0.0, 1.0))
    r, pw = _residuals(landmarks_at(w), lm, front_n, side_n)
    end = float(np.sqrt(np.mean((r * pw) ** 2)))
    result = {}
    target_service = None
    for name, files in FIT_VARIABLES:
        if name not in names:
            continue
        value = float(w[names.index(name)])
        if value < 0.02:
            continue
        result[name] = value
        for rel in files:
            path = os.path.join(targets_dir, rel + ".target.gz")
            key = _add_target_key(obj, path, "sbfit-" + os.path.basename(rel), value, scale)
            if key is None:
                log("Could not add face target " + rel)
    log("Face fit: %d sliders, mismatch %.3f -> %.3f (eye-spacing units)." % (len(result), start, end))
    return result


def _target_offsets(path, count):
    """Per-vertex offsets of a MakeHuman target, in the mesh's own (Blender) axes."""
    offsets = np.zeros((count, 3))
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt") as handle:
        for line in handle:
            parts = line.split()
            if len(parts) == 4 and parts[0].isdigit():
                i = int(parts[0])
                if i < count:
                    x, y, z = float(parts[1]), float(parts[2]), float(parts[3])
                    offsets[i] = (x, -z, y)   # MakeHuman is Y-up/Z-forward; Blender Z-up/-Y-forward
    return offsets


_SCALE_CACHE = {}


def _offset_scale(obj, targets_dir, loader=None):
    """How MakeHuman target file units map to this mesh's units (MPFB may scale
    the base mesh): measured once by comparing a target with MPFB's own loader,
    or from the mesh size when MPFB isn't available."""
    if obj.name in _SCALE_CACHE:
        return _SCALE_CACHE[obj.name]
    path = os.path.join(targets_dir, "nose", "nose-trans-forward.target.gz")
    scale = None
    if loader is not None and os.path.exists(path):
        try:
            before = mesh_positions(obj)
            key = loader(obj, path, 1.0, "sb-scale-check")
            after = mesh_positions(obj)
            obj.shape_key_remove(key)
            raw = _target_offsets(path, len(before)) @ np.array(obj.matrix_world)[:3, :3].T
            moved = after - before
            mask = np.linalg.norm(raw, axis=1) > 1e-6
            scale = float(np.sum(moved[mask] * raw[mask]) / np.sum(raw[mask] * raw[mask]))
        except Exception:  # noqa: BLE001
            scale = None
    if scale is None:
        # MakeHuman's base mesh is ~16.7 units tall in its own files.
        local = np.empty(len(obj.data.vertices) * 3)
        obj.data.vertices.foreach_get("co", local)
        height = np.ptp(local.reshape(-1, 3)[:, 2])
        scale = height / 16.7 if height > 0 else 1.0
    _SCALE_CACHE[obj.name] = scale
    return scale


def _add_target_key(obj, path, name, value, scale=1.0):
    """Adds a target as a shape key with the given value."""
    if obj.data.shape_keys is None:
        obj.shape_key_add(name="Basis", from_mix=False)
    key = obj.shape_key_add(name=name, from_mix=False)
    basis = np.empty(len(obj.data.vertices) * 3)
    obj.data.shape_keys.key_blocks[0].data.foreach_get("co", basis)
    co = basis.reshape(-1, 3) + _target_offsets(path, len(obj.data.vertices)) * scale
    key.data.foreach_set("co", co.ravel())
    key.value = value
    return key


# --- Painting the photo onto the skin ---------------------------------------------------

class ThinPlate:
    """Smooth 2D warp that passes exactly through every pair of points."""

    def __init__(self, src, dst, smooth=1e-4):
        self.src = np.asarray(src, dtype=np.float64)
        dst = np.asarray(dst, dtype=np.float64)
        n = len(self.src)
        k = self._kernel(self.src, self.src) + smooth * np.eye(n)
        p = np.hstack([np.ones((n, 1)), self.src])
        a = np.zeros((n + 3, n + 3))
        a[:n, :n] = k
        a[:n, n:] = p
        a[n:, :n] = p.T
        b = np.zeros((n + 3, 2))
        b[:n] = dst
        self.coef = np.linalg.solve(a, b)

    @staticmethod
    def _kernel(a, b):
        d2 = np.sum((a[:, None, :] - b[None, :, :]) ** 2, axis=2)
        with np.errstate(divide="ignore", invalid="ignore"):
            k = 0.5 * d2 * np.log(d2)
        k[d2 == 0] = 0.0
        return k

    def __call__(self, pts):
        pts = np.asarray(pts, dtype=np.float64)
        n = len(self.src)
        k = self._kernel(pts, self.src)
        return k @ self.coef[:n] + self.coef[n] + pts @ self.coef[n + 1:]


def _box_blur(img, radius):
    """Fast blur (three box passes) of an H x W (x C) array."""
    r = max(1, int(radius))
    out = img.astype(np.float64)
    for _ in range(3):
        for axis in (0, 1):
            c = np.cumsum(np.pad(out, [(r + 1, r) if a == axis else (0, 0) for a in range(out.ndim)], mode="edge"), axis=axis)
            hi = np.take(c, np.arange(2 * r + 1, c.shape[axis]), axis=axis)
            lo = np.take(c, np.arange(0, c.shape[axis] - 2 * r - 1), axis=axis)
            out = (hi - lo) / (2 * r + 1)
    return out


def _load_pixels(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)   # row 0 = bottom of the picture


def _even_lighting(photo, spacing_px, amount=0.45):
    """Softens big shadows and bright spots across the face (one side darker than
    the other) without touching features: divides by a brightness blurred over
    more than the eye spacing, partly."""
    lum = photo[..., :3] @ np.array([0.3, 0.59, 0.11])
    blur = _box_blur(lum, spacing_px * 1.1)
    centre = np.median(blur[blur > np.percentile(blur, 20)])
    gain = np.clip((centre / np.maximum(blur, 1e-3)) ** amount, 0.75, 1.35)
    out = photo.copy()
    out[..., :3] = np.clip(photo[..., :3] * gain[..., None], 0.0, 1.0)
    return out


def _smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def paint_face(obj, lm, front_path, front_marks, side_path=None, side_marks=None, strength=0.9, out_dir="", log=print,
               even_light=True):
    """Paints the photo(s) onto the skin texture of obj. Returns the new image or None."""
    nodes, links, bsdf, image_node = _base_color_nodes(obj)
    tone_from_photo = bsdf is None
    if bsdf is None:
        # No usable skin material (e.g. MakeHuman's skin pack isn't installed):
        # make one, coloured like the person's cheeks in the photo.
        tone = _photo_skin_tone(front_path, front_marks)
        material = bpy.data.materials.new("SB_Skin")
        material.use_nodes = True
        bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*tone, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.55
        if obj.material_slots:
            for slot in obj.material_slots:
                slot.material = material
        else:
            obj.data.materials.append(material)
        nodes, links, bsdf, image_node = _base_color_nodes(obj)
        log("Made a skin material from the photo's skin tone.")
    if image_node is None:
        base_colour = bsdf.inputs["Base Color"].default_value
        img = bpy.data.images.new("SB_SkinBase", 2048, 2048)
        img.pixels.foreach_set(np.tile(np.array(base_colour, dtype=np.float32), 2048 * 2048))
        image_node = nodes.new("ShaderNodeTexImage")
        image_node.image = img
        links.new(image_node.outputs["Color"], bsdf.inputs["Base Color"])
    base_img = image_node.image
    width, height = base_img.size
    base = np.empty(width * height * 4, dtype=np.float32)
    base_img.pixels.foreach_get(base)
    base = base.reshape(height, width, 4)

    co = mesh_positions(obj)
    front = _load_pixels(front_path)
    fh, fw = front.shape[:2]
    names = [k for k in FRONT_POINTS if k in front_marks and lm.get(k) is not None]
    src = np.array([[co[lm[k]][0], co[lm[k]][2]] for k in names])
    dst = np.array([[float(front_marks[k][0]) * fw, (1.0 - float(front_marks[k][1])) * fh] for k in names])
    eye_mesh = np.linalg.norm(src[names.index("eye_r_out")] - src[names.index("eye_l_out")]) if "eye_l_out" in names and "eye_r_out" in names else 0.09
    eye_px = np.linalg.norm(dst[names.index("eye_r_out")] - dst[names.index("eye_l_out")]) if "eye_l_out" in names and "eye_r_out" in names else fw * 0.3
    # Anchor the warp beyond the marks (forehead and temples) so it doesn't swing wildly outside them.
    centre_mesh = src.mean(axis=0)
    centre_px = dst.mean(axis=0)
    affine = np.linalg.lstsq(np.hstack([src, np.ones((len(src), 1))]), dst, rcond=None)[0]
    extra = []
    for ang in np.linspace(0, 2 * np.pi, 12, endpoint=False):
        p = centre_mesh + np.array([np.cos(ang), np.sin(ang)]) * eye_mesh * 1.6
        extra.append(p)
    extra = np.array(extra)
    warp = ThinPlate(np.vstack([src, extra]) / eye_mesh, np.vstack([dst, np.hstack([extra, np.ones((len(extra), 1))]) @ affine]) / eye_px)
    if even_light:
        front = _even_lighting(front, eye_px)

    side = None
    if side_path and side_marks and all(k in side_marks for k in ("side_eye", "side_nose", "side_chin")):
        side = _load_pixels(side_path)
        sh, sw = side.shape[:2]
        s_names = [k for k in SIDE_POINTS if k in side_marks and lm.get(k) is not None]
        s_src = np.array([[-co[lm[k]][1], co[lm[k]][2]] for k in s_names])
        s_dst = np.array([[float(side_marks[k][0]) * sw, (1.0 - float(side_marks[k][1])) * sh] for k in s_names])
        s_scale_mesh = np.linalg.norm(s_src[s_names.index("side_eye")] - s_src[s_names.index("side_chin")])
        s_scale_px = np.linalg.norm(s_dst[s_names.index("side_eye")] - s_dst[s_names.index("side_chin")])
        side_warp = ThinPlate(s_src / s_scale_mesh, s_dst / s_scale_px, smooth=1e-3)
        if even_light:
            side = _even_lighting(side, s_scale_px * 0.5)
        ear_z = co[lm["side_ear"]][2] if lm.get("side_ear") is not None else centre_mesh[1]

    # Which part of the head to paint.
    brow_z = max(co[lm["brow_l"]][2], co[lm["brow_r"]][2])
    chin_z = co[lm["chin"]][2]
    top_z = brow_z + eye_mesh * 0.9
    low_z = chin_z - eye_mesh * 0.25
    half_w = max(abs(co[lm["cheek_l"]][0]), abs(co[lm["cheek_r"]][0])) * 1.05

    mesh = obj.data
    uv = mesh.uv_layers.active.data
    mesh.calc_loop_triangles()
    nm = np.array(obj.matrix_world)[:3, :3]
    colour = np.zeros((height, width, 3), dtype=np.float32)
    weight = np.zeros((height, width), dtype=np.float32)
    body = group_mask(obj, "body")
    # Smooth vertex normals of the fitted shape, so the fades follow the surface
    # smoothly instead of stepping triangle by triangle (which leaves shards).
    tris = np.array([t.vertices[:] for t in mesh.loop_triangles], dtype=np.int64)
    fn = np.cross(co[tris[:, 1]] - co[tris[:, 0]], co[tris[:, 2]] - co[tris[:, 0]])
    vnorm = np.zeros_like(co)
    for k in range(3):
        np.add.at(vnorm, tris[:, k], fn)
    vnorm /= np.maximum(np.linalg.norm(vnorm, axis=1, keepdims=True), 1e-12)
    painted = 0
    for tri in mesh.loop_triangles:
        vi = list(tri.vertices)
        if not all(body[i] for i in vi):
            continue
        p3 = co[vi]
        cz = p3[:, 2].mean()
        if cz < low_z - 0.02 or cz > top_z + 0.03 or abs(p3[:, 0].mean()) > half_w * 1.4:
            continue
        normal = np.cross(p3[1] - p3[0], p3[2] - p3[0])
        ln = np.linalg.norm(normal)
        if ln == 0:
            continue
        normal /= ln
        facing_front = -normal[1]
        if facing_front < -0.2:
            continue
        skin = np.array([[uv[l].uv[0] * width, uv[l].uv[1] * height] for l in tri.loops])
        x0, y0 = np.floor(skin.min(axis=0)).astype(int)
        x1, y1 = np.ceil(skin.max(axis=0)).astype(int)
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, width - 1), min(y1, height - 1)
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
        ys, xs = np.nonzero(inside)
        bw = np.stack([w1[inside], w2[inside], w3[inside]], axis=1)
        pos = bw @ p3
        nrm = bw @ vnorm[vi]
        nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12)
        facing_px = -nrm[:, 1]
        # Front photo: strongest where the face looks at the camera; fades at the
        # edges of the face and towards the hairline and under the chin.
        fp = warp(pos[:, [0, 2]] / eye_mesh) * eye_px
        fade = _smoothstep(0.15, 0.7, facing_px) * _smoothstep(top_z + 0.01, top_z - eye_mesh * 0.7, pos[:, 2]) \
            * _smoothstep(low_z - 0.015, low_z + eye_mesh * 0.45, pos[:, 2]) * _smoothstep(half_w * 1.02, half_w * 0.7, np.abs(pos[:, 0]))
        ok = (fp[:, 0] >= 0) & (fp[:, 0] < fw - 1) & (fp[:, 1] >= 0) & (fp[:, 1] < fh - 1) & (fade > 0.001)
        c = np.zeros((len(pos), 3), dtype=np.float32)
        wt = np.zeros(len(pos), dtype=np.float32)
        if ok.any():
            c[ok] = front[fp[ok, 1].astype(int), fp[ok, 0].astype(int), :3] * fade[ok, None]
            wt[ok] = fade[ok]
        if side is not None:
            sp = side_warp(np.stack([-pos[:, 1], pos[:, 2]], axis=1) / s_scale_mesh) * s_scale_px
            sfade = _smoothstep(0.15, 0.55, np.abs(nrm[:, 0])) * (1.0 - _smoothstep(0.25, 0.65, facing_px)) \
                * _smoothstep(top_z + 0.01, top_z - eye_mesh * 0.5, pos[:, 2]) * _smoothstep(low_z - 0.01, low_z + eye_mesh * 0.2, pos[:, 2]) \
                * _smoothstep(-co[lm["side_ear"]][1] - 0.005, -co[lm["side_ear"]][1] - eye_mesh * 0.6, -pos[:, 1]) if lm.get("side_ear") is not None else 0
            sok = (sp[:, 0] >= 0) & (sp[:, 0] < sw - 1) & (sp[:, 1] >= 0) & (sp[:, 1] < sh - 1) & (sfade > 0.001)
            if np.any(sok):
                c[sok] += side[sp[sok, 1].astype(int), sp[sok, 0].astype(int), :3] * sfade[sok, None]
                wt[sok] += sfade[sok]
        good = wt > 0.001
        if not good.any():
            continue
        ty, tx = ys[good] + y0, xs[good] + x0
        keep = wt[good] > weight[ty, tx]
        colour[ty[keep], tx[keep]] = c[good][keep] / wt[good][keep, None]
        weight[ty[keep], tx[keep]] = np.minimum(wt[good][keep], 1.0)
        painted += int(keep.sum())
    if painted == 0:
        log("Face photo: nothing was painted (check the marks).")
        return None
    _darken_mouth(obj, lm, co, colour, weight, width, height)
    # Match the photo's skin tone to the body where they meet, so there is no seam.
    # Compare typical skin (the median, so beard, hair and shadows don't count) and
    # correct only gently, mostly towards the edges; never brighten past white.
    band = (weight > 0.08) & (weight < 0.6)
    if not tone_from_photo and band.sum() > 50:
        ratio = np.clip(np.median(base[band, :3], axis=0) / np.maximum(np.median(colour[band], axis=0), 1e-4), 0.8, 1.25)
        edge = (1.0 - np.clip(weight, 0.0, 1.0))[..., None]
        corr = 1.0 + (ratio[None, None, :] - 1.0) * (0.3 + 0.7 * edge)
        corrected = colour * corr
        # Soft limit instead of clipping: compress values approaching white.
        colour = np.where(corrected > 0.85, 0.85 + (1.0 - 0.85) * np.tanh((corrected - 0.85) / 0.15), corrected)
        colour = np.clip(colour, 0.0, 1.0)
    blend = (np.minimum(weight, 1.0) * float(np.clip(strength, 0.0, 1.0)))[..., None]
    blend[weight > 1.0] = 1.0
    result = base.copy()
    result[..., :3] = base[..., :3] * (1.0 - blend) + colour * blend
    new_img = bpy.data.images.new("SB_FaceSkin", width, height)
    new_img.pixels.foreach_set(result.astype(np.float32).ravel())
    if out_dir:
        path = os.path.join(out_dir, "face_skin_%d.png" % abs(hash(front_path)))
        new_img.filepath_raw = path
        new_img.file_format = "PNG"
        new_img.save()
    image_node.image = new_img
    log("Face photo painted (%d texture pixels%s)." % (painted, ", with side photo" if side is not None else ""))
    return new_img


MOUTH_INSIDE = (0.16, 0.05, 0.05)
LIP_INSIDE = (0.45, 0.2, 0.19)


def _mouth_triangles(obj, lm, co):
    """Loop triangles of the inside of the mouth: behind the lips and hidden by
    the face when seen from the front (a ray towards the camera hits the face)."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    mesh = obj.data
    mesh.calc_loop_triangles()
    body = group_mask(obj, "body")
    left, right = co[lm["mouth_l"]], co[lm["mouth_r"]]
    top, bottom = co[lm["lip_top"]], co[lm["lip_bottom"]]
    lips_y = min(top[1], bottom[1])
    half = abs(right[0] - left[0]) * 0.5
    tris = [t for t in mesh.loop_triangles if all(body[i] for i in t.vertices)]
    tree = BVHTree.FromPolygons([Vector(p) for p in co], [list(t.vertices) for t in tris], all_triangles=True)
    out = []
    reach = 0.06
    for tri in tris:
        c = co[list(tri.vertices)].mean(axis=0)
        if not (abs(c[0]) < half * 1.1 and bottom[2] - 0.045 < c[2] < top[2] + 0.012 and lips_y + 0.001 < c[1] < lips_y + 0.09):
            continue
        # Inside the mouth = hidden behind the lips from the front...
        at = Vector(c)
        if tree.ray_cast(at + Vector((0, -0.0015, 0)), Vector((0, -1, 0)), 0.12)[0] is None:
            continue
        # ...right between the lips: the inner side of the lips (seen when it opens),
        if abs(c[0]) < half * 1.05 and bottom[2] - 0.012 < c[2] < top[2] + 0.006 and c[1] < lips_y + 0.02:
            out.append((tri, LIP_INSIDE))
            continue
        # ...or deeper, with the face both above it (upper lip, palate) and below it
        # (lower lip, jaw). Skin under the chin is hidden from the front too, but has
        # nothing below it.
        if tree.ray_cast(at + Vector((0, 0, 0.0015)), Vector((0, 0, 1)), reach)[0] is None:
            continue
        if tree.ray_cast(at + Vector((0, 0, -0.0015)), Vector((0, 0, -1)), reach)[0] is None:
            continue
        out.append((tri, MOUTH_INSIDE))
    return out


def _rasterize(skin, width, height):
    """Texture pixels (ys, xs) inside a UV triangle given in pixels."""
    x0, y0 = np.floor(skin.min(axis=0)).astype(int)
    x1, y1 = np.ceil(skin.max(axis=0)).astype(int)
    x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, width - 1), min(y1, height - 1)
    if x1 < x0 or y1 < y0:
        return None
    gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    (ax, ay), (bx, by), (cx, cy) = skin
    det = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(det) < 1e-9:
        return None
    w1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / det
    w2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / det
    inside = (w1 >= -0.02) & (w2 >= -0.02) & (1.0 - w1 - w2 >= -0.02)
    ys, xs = np.nonzero(inside)
    return ys + y0, xs + x0


def _darken_mouth(obj, lm, co, colour, weight, width, height):
    """Paints the inside of the mouth dark, so an open mouth looks like a mouth."""
    uv = obj.data.uv_layers.active.data
    for tri, shade in _mouth_triangles(obj, lm, co):
        skin = np.array([[uv[l].uv[0] * width, uv[l].uv[1] * height] for l in tri.loops])
        hit = _rasterize(skin, width, height)
        if hit is None:
            continue
        ys, xs = hit
        colour[ys, xs] = shade
        weight[ys, xs] = 1.0001   # painted fully, kept out of the tone match


def add_mouth_inside(obj, lm, log=print):
    """A dark shape inside the mouth, behind the lips. The base mesh is open at
    the back of the mouth, so an open mouth would otherwise show the inside of
    the head. Hidden while the mouth is closed; follows the jaw via the copied
    expression keys (add_expressions) and the skeleton (bind_loose_meshes)."""
    co = mesh_positions(obj)
    left, right = co[lm["mouth_l"]], co[lm["mouth_r"]]
    top, bottom = co[lm["lip_top"]], co[lm["lip_bottom"]]
    lips_y = min(top[1], bottom[1])
    half = abs(right[0] - left[0]) * 0.5
    lip_height = abs(top[2] - bottom[2])
    depth = max(half * 1.1, 0.02)
    centre = ((left[0] + right[0]) * 0.5, lips_y + lip_height * 0.6 + depth, (left[2] + right[2]) * 0.5 - lip_height * 0.1)
    mesh = bpy.data.meshes.new("SB_MouthInside")
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0)
    for v in bm.verts:
        v.co.x = centre[0] + v.co.x * half * 0.95
        v.co.y = centre[1] + v.co.y * depth
        v.co.z = centre[2] + v.co.z * lip_height * 1.1
    for face in bm.faces:
        face.smooth = True
    bm.to_mesh(mesh)
    bm.free()
    bag = bpy.data.objects.new("SB_MouthInside", mesh)
    bpy.context.scene.collection.objects.link(bag)
    material = bpy.data.materials.new("SB_MouthInside")
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (MOUTH_INSIDE[0] * 0.6, MOUTH_INSIDE[1] * 0.6, MOUTH_INSIDE[2] * 0.6, 1.0)
        bsdf.inputs["Roughness"].default_value = 1.0
    material.diffuse_color = (MOUTH_INSIDE[0] * 0.6, MOUTH_INSIDE[1] * 0.6, MOUTH_INSIDE[2] * 0.6, 1.0)
    mesh.materials.append(material)
    # Open with the jaw: the bottom follows the lower lip, the top the upper lip,
    # smoothly in between (so the shape never tears).
    keys = obj.data.shape_keys.key_blocks if obj.data.shape_keys else {}
    if "jawOpen" in keys:
        m = np.array(obj.matrix_world)[:3, :3]
        basis = keys[0].data
        def moved(index):
            return (np.array(keys["jawOpen"].data[index].co) - np.array(basis[index].co)) @ m.T
        d_top, d_bottom = moved(lm["lip_top"]), moved(lm["lip_bottom"])
        verts = np.array([v.co[:] for v in mesh.vertices])
        z0, z1 = verts[:, 2].max(), verts[:, 2].min()
        t = np.clip((z0 - verts[:, 2]) / max(z0 - z1, 1e-6), 0.0, 1.0)
        t = t * t * (3.0 - 2.0 * t)
        bag.shape_key_add(name="Basis", from_mix=False)
        key = bag.shape_key_add(name="jawOpen", from_mix=False)
        key.data.foreach_set("co", (verts + d_top[None, :] * (1.0 - t[:, None]) + d_bottom[None, :] * t[:, None]).ravel())
        key.value = 0.0
    log("Added the inside of the mouth.")
    return bag


def darken_mouth_only(obj, lm):
    """For avatars without a face photo: darken the inside of the mouth on the skin texture."""
    nodes, links, bsdf, image_node = _base_color_nodes(obj)
    if image_node is None:
        return
    img = image_node.image
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    colour = px[..., :3].copy()
    weight = np.zeros((h, w), dtype=np.float32)
    _darken_mouth(obj, lm, mesh_positions(obj), colour, weight, w, h)
    if weight.max() <= 0:
        return
    painted = weight > 1.0
    px[painted, :3] = colour[painted]
    new_img = bpy.data.images.new(img.name + "_mouth", w, h)
    new_img.pixels.foreach_set(px.ravel())
    image_node.image = new_img


def _photo_skin_tone(path, marks):
    """Average colour of the cheeks (between the eye corners and the nose wings) in linear RGB."""
    try:
        px = _load_pixels(path)
        h, w = px.shape[:2]
        samples = []
        for eye, nose in (("eye_l_out", "nose_l"), ("eye_r_out", "nose_r")):
            if eye in marks and nose in marks:
                u = (float(marks[eye][0]) + float(marks[nose][0])) / 2.0
                v = (float(marks[eye][1]) * 0.35 + float(marks[nose][1]) * 0.65)
                x, y = int(u * w), int((1.0 - v) * h)
                r = max(2, int(w * 0.012))
                samples.append(px[max(y - r, 0):y + r, max(x - r, 0):x + r, :3].reshape(-1, 3))
        if samples:
            return tuple(float(c) for c in np.median(np.vstack(samples), axis=0))
    except Exception:  # noqa: BLE001
        pass
    return (0.6, 0.42, 0.33)


def _base_color_nodes(obj):
    material = obj.active_material or (obj.material_slots[0].material if obj.material_slots else None)
    if material is None or not material.use_nodes:
        return None, None, None, None
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return nodes, links, None, None
    socket = bsdf.inputs.get("Base Color")
    stack = [link.from_node for link in socket.links] if socket else []
    while stack:
        node = stack.pop()
        if node.type == "TEX_IMAGE" and node.image is not None:
            return nodes, links, bsdf, node
        for inp in node.inputs:
            stack.extend(link.from_node for link in inp.links)
    return nodes, links, bsdf, None


# --- Talking and blinking ---------------------------------------------------------------

# Shape key name (what Scene Builder looks for) -> MakeHuman expression unit, strength.
# MakeHuman's full "mouth-open" is a yawn; talking needs a bit over half of it.
EXPRESSIONS = {"jawOpen": ("mouth-open", 0.6), "eyeBlinkLeft": ("eye-left-closure", 1.0),
               "eyeBlinkRight": ("eye-right-closure", 1.0), "mouthSmile": ("mouth-corner-puller", 1.0)}


def add_expressions(obj, units_dir, targets_dir, log=print, loader=None):
    """Adds the expression shape keys to the body and copies them to eyebrows and
    eyelashes (which must follow the eyelids and face)."""
    if not os.path.isdir(units_dir):
        log("Talking face skipped: MakeHuman's expression units weren't found.")
        return []
    scale = _offset_scale(obj, targets_dir, loader)
    added = []
    for key_name, (unit, amount) in EXPRESSIONS.items():
        path = os.path.join(units_dir, unit + ".target.gz")
        if not os.path.exists(path):
            continue
        _add_target_key(obj, path, key_name, 0.0, scale * amount)
        added.append(key_name)
    if not added:
        return []
    # Followers: meshes fitted on the face (eyebrows, eyelashes, beards…).
    try:
        from mathutils.kdtree import KDTree
    except ImportError:
        KDTree = None
    world = mesh_positions_basis(obj)
    keys = obj.data.shape_keys.key_blocks
    basis = np.empty(len(obj.data.vertices) * 3)
    keys[0].data.foreach_get("co", basis)
    basis = basis.reshape(-1, 3)
    m = np.array(obj.matrix_world)[:3, :3]
    deltas = {}
    for name in added:
        d = np.empty(len(obj.data.vertices) * 3)
        keys[name].data.foreach_get("co", d)
        deltas[name] = (d.reshape(-1, 3) - basis) @ m.T   # world-space motion
    body = group_mask(obj, "body")
    moving = np.nonzero(body & (np.max([np.linalg.norm(v, axis=1) for v in deltas.values()], axis=0) > 0))[0]
    if KDTree is None or len(moving) == 0:
        return added
    tree = KDTree(len(moving))
    for j, i in enumerate(moving):
        tree.insert(world[i], j)
    tree.balance()
    for other in bpy.data.objects:
        if other.type != "MESH" or other == obj:
            continue
        lower = other.name.lower()
        if not any(word in lower for word in ("brow", "lash", "beard", "mustache", "moustache")):
            continue
        ow = np.array(other.matrix_world)
        inv = np.linalg.inv(ow[:3, :3])
        verts = np.empty(len(other.data.vertices) * 3)
        other.data.vertices.foreach_get("co", verts)
        verts = verts.reshape(-1, 3)
        world_v = verts @ ow[:3, :3].T + ow[:3, 3]
        nearest = []
        for p in world_v:
            hits = tree.find_n(p, 3)
            nearest.append([(moving[h[1]], max(h[2], 1e-5)) for h in hits])
        if other.data.shape_keys is None:
            other.shape_key_add(name="Basis", from_mix=False)
        for name in added:
            motion = np.zeros_like(verts)
            for vi, near in enumerate(nearest):
                total = sum(1.0 / d for _, d in near)
                motion[vi] = sum(deltas[name][i] / d for i, d in near) / total
            key = other.shape_key_add(name=name, from_mix=False)
            key.data.foreach_set("co", (verts + motion @ inv.T).ravel())
            key.value = 0.0
        log("Expressions copied to %s." % other.name)
    log("Talking face: %s." % ", ".join(added))
    return added


def mesh_positions_basis(obj):
    """World positions with the current mix (same as mesh_positions)."""
    return mesh_positions(obj)


def bake_shape_keys(obj, keep):
    """Folds every shape key except those in [param keep] into the mesh, so only
    the expression keys are exported (as morph targets)."""
    if obj.data.shape_keys is None:
        return
    keys = obj.data.shape_keys.key_blocks
    n = len(obj.data.vertices)
    basis = np.empty(n * 3)
    keys[0].data.foreach_get("co", basis)
    mix = basis.copy()
    kept = {}
    for key in keys[1:]:
        data = np.empty(n * 3)
        key.data.foreach_get("co", data)
        if key.name in keep:
            kept[key.name] = data - basis
        elif not key.mute and key.value != 0.0:
            mix += (data - basis) * key.value
    obj.shape_key_clear()
    obj.data.vertices.foreach_set("co", mix)
    obj.data.update()
    if kept:
        obj.shape_key_add(name="Basis", from_mix=False)
        for name, delta in kept.items():
            key = obj.shape_key_add(name=name, from_mix=False)
            key.data.foreach_set("co", mix + delta)
            key.value = 0.0


def apply_masks_keep_keys(obj):
    """Removes the vertices hidden by Mask modifiers (MPFB hides helper geometry
    and skin under clothes that way) while keeping shape keys, then removes the
    Mask modifiers - so the exporter has nothing to apply and keeps the keys."""
    import bmesh
    masks = [m for m in obj.modifiers if m.type == "MASK" and m.vertex_group]
    if not masks:
        return
    n = len(obj.data.vertices)
    hide = np.zeros(n, dtype=bool)
    for m in masks:
        keep = group_mask(obj, m.vertex_group, threshold=getattr(m, "threshold", 0.0))
        if m.invert_vertex_group:
            keep = ~keep
        hide |= ~keep
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(hide)[0]], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    for m in masks:
        obj.modifiers.remove(m)

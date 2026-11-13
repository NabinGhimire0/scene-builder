"""Scene Builder animals: rigged, smooth bodies made from metaball volumes.

    python make_animals.py <out dir> [species ...]

Each species is described by its joints (forward f, up u, side s in metres; the
animal faces -Y in Blender = +Z in Godot) and body volumes. The body is a voxel-
remeshed metaball surface with automatic bone weights; ears, eyes, horns, antlers,
tusks, manes and beaks are separate skinned meshes. Vertex colours carry masks for
the in-app coat shader: R = second colour (belly, chest, muzzle), G = "points"
(darker ears, lower legs, muzzle, tail tip), B = fur length (0 = none).
UV0 = (f, u) / height and UV1 = (s, 0) / height give the shader 3-D pattern coords.
"""
import math, sys, os
import bpy, bmesh
from mathutils import Vector, Quaternion, Matrix
import numpy as np

K = 0.5749          # metaball surface radius / element radius (stiffness 2, threshold 0.6)


def P(f, u, s=0.0):
    return Vector((s, -f, u))


def FUS(v):
    return (-v.y, v.z, v.x)


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ----------------------------------------------------------------------------- design

class Design:
    def __init__(self, name, height):
        self.name = name
        self.H = height
        self.joints = {}       # name -> Vector (blender)
        self.bones = []        # (name, head joint, tail joint, parent)
        self.blobs = []        # ("ell", centre, (af, au, as), rot) | ("cap", a, b, r)
        self.parts = []        # (object name, builder fn, bone weights fn, material)
        self.masks = None      # fn(f, u, s) -> (r, g, b)
        self.mat_rules = []    # (material, fn(centre f,u,s) -> bool)
        self.fur_len = 0.5
        self.deferred = []    # fn(bvh of the body) -> parts placed on its surface
        self.ear_mask = (0.25, 0.75, 0.7)
        self.part_masks = {}
        self.colours = {}     # material -> rgb (horns, hooves, beak...)
        self.extra_meshes = []  # (kind, metaball blobs, bone or None for automatic weights)

    def j(self, name, f, u, s=0.0):
        self.joints[name] = P(f, u, s)
        return self.joints[name]

    def bone(self, name, head, tail, parent=None):
        self.bones.append((name, head, tail, parent))

    def ell(self, c, axes, pitch=0.0, yaw=0.0):
        self.blobs.append(("ell", c, axes, pitch, yaw))

    def cap(self, a, b, r, r2=None):
        # tapered capsules are made of a few shorter ones
        if r2 is None or abs(r2 - r) < 1e-4:
            self.blobs.append(("cap", a, b, r))
            return
        n = max(2, int(abs(r - r2) / (0.15 * min(r, r2)) + 1))
        n = min(n, 6)
        for i in range(n):
            t0, t1 = i / n, (i + 1) / n
            self.blobs.append(("cap", lerp(a, b, t0), lerp(a, b, t1), lerp(r, r2, (t0 + t1) / 2)))


def mirror(name, s):
    return name + ("_l" if s > 0 else "_r")


# ----------------------------------------------------------------------------- quadrupeds

QUAD_DEFAULT = dict(
    H=0.55,                      # height at the withers (m); everything else is in units of H
    L=0.85,                      # shoulder joint to hip joint
    # body volumes: (centre f, centre u, semi-axis f, u, s); f measured from the middle of the body
    chest=(0.26, 0.71, 0.24, 0.17, 0.14), belly=(0.0, 0.73, 0.3, 0.125, 0.13), haunch=(-0.32, 0.77, 0.18, 0.15, 0.13),
    back_r=0.1, withers=0.95, croup=0.88, hump=0.0,
    hip=(0.0, 0.8), hip_s=0.1, shoulder=(0.0, 0.68), sh_s=0.11,
    # leg joints: (f relative to the hip / shoulder joint, u)
    hind=[(0.1, 0.5), (-0.1, 0.27), (-0.08, 0.04)], fore=[(-0.05, 0.52), (0.0, 0.14), (0.01, 0.04)],
    toe=0.08, thigh_r=(0.12, 0.07), shin_r=(0.055, 0.04), meta_r=0.032, arm_r=(0.1, 0.065), fore_r=(0.05, 0.038),
    paw_r=0.045, hoof=False,
    neck=(0.32, 0.82), neck_len=0.32, neck_angle=48, neck_r=(0.13, 0.095),
    head_angle=-14, head=(0.13, 0.11, 0.1), snout_len=0.15, snout_r=(0.08, 0.055), snout_drop=0.01, jowl=0.0,
    ear=dict(kind="dog", len=0.24, w=0.17, up=-55, out=60, back=15, droop=0.25, twist=80, side=0.9, set=0.35),
    eye=dict(r=0.02, f=0.55, u=0.32, s=0.62),
    tail=dict(len=0.5, r=(0.05, 0.022), up=5, curl=-45, n=5, bushy=0.0),
    belly_mask=True, fur=0.5, horns=None, antlers=0.0, tusks=0.0, mane=None, beard=0.0, trunk=0.0, tuft=0.0,
    plantigrade=False, points_face=0.0, socks=0.0,
)


def quad(name, **kw):
    p = dict(QUAD_DEFAULT)
    for k, v in kw.items():
        if isinstance(v, dict) and isinstance(p.get(k), dict):
            d = dict(p[k])
            d.update(v)
            p[k] = d
        else:
            p[k] = v
    H = p["H"]
    L = p["L"] * H
    d = Design(name, H)
    d.params = p
    d.fur_len = p["fur"]
    hf, sf = -L / 2, L / 2
    hip_f, hip_u = hf + p["hip"][0] * H, p["hip"][1] * H
    sh_f, sh_u = sf + p["shoulder"][0] * H, p["shoulder"][1] * H
    # spine
    pel = d.j("pelvis", hip_f + 0.02 * H, p["croup"] * H - 0.06 * H)
    ch = d.j("chest", sf - 0.12 * H, p["withers"] * H - 0.12 * H)
    d.j("spine1", lerp(-pel.y, -ch.y, 0.33), lerp(pel.z, ch.z, 0.33))
    d.j("spine2", lerp(-pel.y, -ch.y, 0.66), lerp(pel.z, ch.z, 0.66))
    # neck and head
    na = math.radians(p["neck_angle"])
    nl = p["neck_len"] * H
    n0 = d.j("neck0", p["neck"][0] * H, p["neck"][1] * H)
    d.j("neck1", n0.y * -1 + math.cos(na) * nl * 0.5, n0.z + math.sin(na) * nl * 0.5)
    hd = d.j("head", -n0.y + math.cos(na) * nl, n0.z + math.sin(na) * nl)
    ha = math.radians(p["head_angle"])
    hdir = Vector((0, -math.cos(ha), math.sin(ha)))
    hup = Vector((0, -math.sin(ha), math.cos(ha))) * -1
    hup = Vector((0, math.sin(ha), math.cos(ha)))
    hx = [a * H for a in p["head"]]
    skull = hd + hdir * hx[0] * 0.35 + hup * hx[1] * 0.15
    d.joints["skull"] = skull
    snout_tip = skull + hdir * (hx[0] * 0.6 + p["snout_len"] * H) - hup * p["snout_drop"] * H
    d.joints["snout"] = snout_tip
    d.joints["muzzle"] = snout_tip
    d.joints["head_end"] = skull + hdir * hx[0] * 0.9
    # tail
    tp = p["tail"]
    d.j("tail0", hf - 0.12 * H, p["croup"] * H - 0.05 * H)
    # legs
    for s in (1, -1):
        hipj = d.j(mirror("hip", s), hip_f, hip_u, s * p["hip_s"] * H)
        for (df, u), nm in zip(p["hind"], ["knee", "hock", "hpaw"]):
            d.j(mirror(nm, s), hip_f + df * H, u * H, s * p["hip_s"] * H * (1.05 if nm == "knee" else 0.92))
        d.j(mirror("htoe", s), -d.joints[mirror("hpaw", s)].y + p["toe"] * H, 0.0, s * p["hip_s"] * H * 0.92)
        d.j(mirror("shoulder", s), sh_f, sh_u, s * p["sh_s"] * H)
        d.j(mirror("scap", s), sh_f - 0.12 * H, p["withers"] * H - 0.05 * H, s * p["sh_s"] * H * 0.6)
        for (df, u), nm in zip(p["fore"], ["elbow", "wrist", "fpaw"]):
            d.j(mirror(nm, s), sh_f + df * H, u * H, s * p["sh_s"] * H * 0.9)
        d.j(mirror("ftoe", s), -d.joints[mirror("fpaw", s)].y + p["toe"] * H, 0.0, s * p["sh_s"] * H * 0.9)

    J = d.joints
    d.bone("pelvis", "pelvis", "spine1")
    d.bone("spine1", "spine1", "spine2", "pelvis")
    d.bone("spine2", "spine2", "chest", "spine1")
    d.bone("chest", "chest", "neck0", "spine2")
    d.bone("neck1", "neck0", "neck1", "chest")
    d.bone("neck2", "neck1", "head", "neck1")
    d.bone("head", "head", "head_end", "neck2")
    for s in (1, -1):
        m = lambda n: mirror(n, s)
        d.bone(m("thigh"), m("hip"), m("knee"), "pelvis")
        d.bone(m("shin"), m("knee"), m("hock"), m("thigh"))
        d.bone(m("hmeta"), m("hock"), m("hpaw"), m("shin"))
        d.bone(m("hfoot"), m("hpaw"), m("htoe"), m("hmeta"))
        d.bone(m("scapula"), m("scap"), m("shoulder"), "chest")
        d.bone(m("upperarm"), m("shoulder"), m("elbow"), m("scapula"))
        d.bone(m("forearm"), m("elbow"), m("wrist"), m("upperarm"))
        d.bone(m("fmeta"), m("wrist"), m("fpaw"), m("forearm"))
        d.bone(m("ffoot"), m("fpaw"), m("ftoe"), m("fmeta"))
    n = tp["n"]
    tl = tp["len"] * H
    ang = math.radians(tp["up"])
    curl = math.radians(tp["curl"]) / max(n - 1, 1)
    prev = J["tail0"]
    seg = tl / n
    pts = [prev]
    for i in range(n):
        nxt = prev + Vector((0, math.cos(ang), math.sin(ang))) * seg
        d.joints["tail%d" % (i + 1)] = nxt
        d.bone("tail%d" % (i + 1), "tail%d" % i, "tail%d" % (i + 1), "pelvis" if i == 0 else "tail%d" % i)
        pts.append(nxt)
        prev = nxt
        ang += curl
    d.tail_pts = pts

    # ---- volumes
    for key in ("chest", "belly", "haunch"):
        cf, cu, af, au, as_ = p[key]
        d.ell(P(cf * H, cu * H), (af * H, au * H, as_ * H))
    d.cap(pel + Vector((0, 0.04 * H, 0.0)), ch + Vector((0, 0, 0.02 * H)), p["back_r"] * H)
    if p["hump"] > 0:
        d.ell(P(sf - 0.15 * H, p["withers"] * H), (0.2 * H, p["hump"] * H, 0.12 * H))
    d.cap(n0, hd, p["neck_r"][0] * H, p["neck_r"][1] * H)
    if p["jowl"] > 0:   # dewlap (cows)
        d.ell(lerp(n0, hd, 0.35) + Vector((0, -0.04 * H, -p["neck_r"][0] * H * 0.8)), (0.18 * H, p["jowl"] * H, 0.05 * H))
    d.ell(skull, hx, pitch=-ha)
    sr = p["snout_r"]
    d.cap(skull + hdir * hx[0] * 0.3 - hup * hx[1] * 0.25, snout_tip, sr[0] * H, sr[1] * H)
    if p["trunk"] > 0:
        # elephant trunk: a hanging, tapering chain from the snout
        n_t = 6
        prev_n = "head"
        prev_p = snout_tip
        tl_ = p["trunk"] * H
        ang = -0.35
        for i in range(n_t):
            ang -= 0.22
            nxt = prev_p + Vector((0, -math.cos(ang) * 0.35, math.sin(ang))).normalized() * (tl_ / n_t)
            nm = "trunk%d" % (i + 1)
            d.joints[nm] = prev_p.copy()
            d.joints[nm + "_end"] = nxt
            d.bone(nm, nm, nm + "_end", prev_n)
            d.cap(prev_p, nxt, lerp(sr[1], sr[1] * 0.45, i / n_t) * H, lerp(sr[1], sr[1] * 0.45, (i + 1) / n_t) * H)
            prev_n = nm
            prev_p = nxt
        d.joints["muzzle"] = prev_p
    for s in (1, -1):
        m = lambda n: J[mirror(n, s)]
        d.cap(m("hip") + Vector((0, 0, 0.04 * H)), m("knee"), p["thigh_r"][0] * H, p["thigh_r"][1] * H)
        d.cap(m("knee"), m("hock"), p["shin_r"][0] * H, p["shin_r"][1] * H)
        d.cap(m("hock"), m("hpaw"), p["meta_r"] * H, p["meta_r"] * H * 0.9)
        d.cap(m("hpaw"), lerp(m("hpaw"), m("htoe"), 0.75) + Vector((0, 0, p["paw_r"] * H * 0.2)), p["paw_r"] * H, p["paw_r"] * H * 0.8)
        d.cap(m("scap"), m("shoulder"), p["arm_r"][0] * H * 0.8, p["arm_r"][0] * H)
        d.cap(m("shoulder"), m("elbow"), p["arm_r"][0] * H, p["arm_r"][1] * H)
        d.cap(m("elbow"), m("wrist"), p["fore_r"][0] * H, p["fore_r"][1] * H)
        d.cap(m("wrist"), m("fpaw"), p["meta_r"] * H, p["meta_r"] * H * 0.9)
        d.cap(m("fpaw"), lerp(m("fpaw"), m("ftoe"), 0.75) + Vector((0, 0, p["paw_r"] * H * 0.2)), p["paw_r"] * H, p["paw_r"] * H * 0.8)
    tr = tp["r"]
    for i in range(len(pts) - 1):
        d.cap(pts[i], pts[i + 1], lerp(tr[0], tr[1], i / max(len(pts) - 2, 1)) * H, lerp(tr[0], tr[1], (i + 1) / max(len(pts) - 2, 1)) * H)
    if tp["bushy"] > 0:
        d.ell(lerp(pts[1], pts[-1], 0.55), (tl * 0.4, tp["bushy"] * H, tp["bushy"] * H), pitch=-math.radians(tp["up"]))

    # ---- masks (r: second colour, g: points, b: fur length)
    snout = J["muzzle"]
    belly_u = p["chest"][1] * H
    leg_top = p["fore"][0][1] * H
    def masks(v, n):
        f, u, s = FUS(v)
        under = smooth(0.0, -0.7, n.z) * smooth(belly_u + 0.05 * H, belly_u - 0.15 * H, u) * smooth(L * 0.75, L * 0.5, abs(f))
        inner = smooth(0.2, 0.8, -math.copysign(1.0, s) * n.x) * smooth(leg_top + 0.1 * H, leg_top - 0.05 * H, u)
        chest_patch = smooth(0.1, 0.7, -n.y) * smooth(sf - 0.05 * H, sf + 0.15 * H, f) * smooth(0.12 * H, 0.04 * H, abs(s)) * smooth(p["neck"][1] * H + 0.15 * H, belly_u, u) * smooth(leg_top - 0.02 * H, leg_top + 0.08 * H, u)
        socks = smooth(0.13 * H, 0.06 * H, u)
        muzzle = smooth(p["snout_len"] * H * 1.1, p["snout_len"] * H * 0.5, (v - snout).length) * smooth(0.4, -0.5, n.z)
        r = max(under, chest_patch, muzzle, socks * p["socks"]) if p["belly_mask"] else muzzle * 0.5
        legs = smooth(leg_top * 0.7, leg_top * 0.35, u) * smooth(0.3 * H, 0.6 * H, abs(f) + 0.0) * 0 + smooth(leg_top * 0.75, leg_top * 0.4, u)
        tip = smooth(p["snout_len"] * H * 0.6, 0.0, (v - snout).length)
        tailtip = smooth(tl * 0.35, tl * 0.05, (v - pts[-1]).length)
        g = max(legs, tip, tailtip * 0.8, smooth(hx[0] * 1.9, hx[0] * 1.2, (v - skull).length) * p["points_face"])
        b = 1.0
        b *= 1.0 - smooth(p["snout_len"] * H * 0.55, p["snout_len"] * H * 0.15, (v - snout).length)
        b *= 0.4 + 0.6 * smooth(0.05 * H, 0.3 * H, u)
        if p["hoof"]:
            b *= smooth(0.05 * H, 0.09 * H, u)
        face = smooth(hx[0] * 2.0, hx[0] * 0.8, (v - skull).length)
        b *= 1.0 - 0.45 * face
        return r, g, b
    d.masks = masks
    hoof_h = 0.07 * H
    if p["hoof"]:
        d.mat_rules.append(("hoof", lambda v: v.z < hoof_h))
    nose_r = sr[1] * H * 0.85
    d.mat_rules.append(("nose", lambda v: (v - snout).length < nose_r and (v - snout).dot(hdir) > -nose_r * 0.2))
    ep = p["eye"]
    def eyes(bvh):
        out = []
        for s in (1, -1):
            aim = (hdir * ep["f"] + hup * ep["u"] + Vector((s * ep["s"], 0, 0))).normalized()
            hit = surface(bvh, skull, aim, hx[0] * 3)
            look = (aim + hdir * 0.8).normalized()
            c = hit - aim * ep["r"] * H * 0.45
            out.append(("eye", eye_mesh(c, ep["r"] * H, look), "head", "eye"))
        return out
    d.deferred.append(eyes)
    ear = p["ear"]
    if ear["kind"] != "none":
        def ears(bvh):
            out = []
            for s in (1, -1):
                aim = (hup * 1.0 + Vector((s * ear.get("side", 0.8), 0, 0)) - hdir * ear.get("set", 0.3)).normalized()
                base = surface(bvh, skull, aim, hx[0] * 3) - aim * 0.01 * H
                mesh, tip = ear_mesh(ear, base, s, H)
                nm = mirror("ear", s)
                out.append(("ear", mesh, nm, "coat", base, tip))
            return out
        d.deferred.append(ears)
        for s in (1, -1):
            nm = mirror("ear", s)
            d.bone(nm, nm + "_base", nm + "_tip", "head")
            d.joints[nm + "_base"] = skull + hup * hx[1] + Vector((s * hx[2] * 0.6, 0, 0))
            d.joints[nm + "_tip"] = d.joints[nm + "_base"] + Vector((s * 0.05 * H, 0, 0.05 * H))
    # ---- horns, antlers, tusks, mane, beard
    hp = p["horns"]
    if hp:
        def horns(bvh):
            out = []
            for s in (1, -1):
                aim = (hup * hp.get("up", 1.0) + Vector((s * hp.get("side", 0.7), 0, 0)) - hdir * hp.get("set", 0.2)).normalized()
                base = surface(bvh, skull, aim, hx[0] * 3) - aim * hp["r0"] * H * 0.6
                dirs = [Vector((s * v[2], -v[0], v[1])).normalized() for v in hp["dirs"]]
                out.append(("horns", horn_mesh(base, dirs, hp["len"] * H, hp["r0"] * H, hp["r1"] * H), "head", "horn"))
            return out
        d.deferred.append(horns)
    if p["antlers"] > 0:
        a = p["antlers"] * H
        def antlers(bvh):
            out = []
            for s in (1, -1):
                aim = (hup + Vector((s * 0.55, 0, 0)) - hdir * 0.3).normalized()
                base = surface(bvh, skull, aim, hx[0] * 3) - aim * 0.01 * H
                beam = [Vector((s * 0.35, 0.25, 0.9)), Vector((s * 0.5, 0.45, 0.75)), Vector((s * 0.2, 0.1, 1.0))]
                v, f, uv = horn_mesh(base, [x.normalized() for x in beam], a, 0.022 * H, 0.008 * H, sides=8, segs=8)
                # tines branch off the beam
                for t_at, t_dir, t_len in ((0.25, Vector((s * 0.1, -0.9, 0.5)), 0.32), (0.55, Vector((s * 0.2, -0.5, 0.85)), 0.3), (0.8, Vector((s * 0.6, 0.2, 0.8)), 0.25)):
                    k = int(t_at * 8)
                    root = sum((Vector(v[k * 8 + j]) for j in range(8)), Vector()) / 8
                    tv, tf, tuv = horn_mesh(root, [t_dir.normalized(), (t_dir + Vector((0, 0, 0.5))).normalized()], a * t_len, 0.012 * H, 0.004 * H, sides=6, segs=5)
                    off = len(v)
                    v = v + tv
                    f = f + [tuple(i + off for i in face) for face in tf]
                    uv = uv + tuv
                out.append(("antlers", (v, f, uv), "head", "antler"))
            return out
        d.deferred.append(antlers)
    if p["tusks"] > 0:
        def tusks(bvh):
            out = []
            for s in (1, -1):
                aim = (hdir * 0.8 - hup * 0.6 + Vector((s * 0.45, 0, 0))).normalized()
                base = surface(bvh, d.joints["snout"] - hdir * sr[0] * H, aim, sr[0] * H * 3) - aim * 0.02 * H
                dirs = [(hdir * 0.4 - hup * 0.9 + Vector((s * 0.15, 0, 0))).normalized(), (hdir * 1.0 - hup * 0.1).normalized(), (hdir * 0.6 + hup * 0.8).normalized()]
                out.append(("tusks", horn_mesh(base, dirs, p["tusks"] * H, 0.035 * H, 0.012 * H), "head", "tusk"))
            return out
        d.deferred.append(tusks)
    if p["mane"]:
        mk = p["mane"]
        if mk == "lion":
            mb = [("ell", skull - hdir * hx[0] * 0.55 - hup * hx[1] * 0.2, (hx[0] * 1.15, hx[1] * 1.7, hx[2] * 1.7), -ha, 0.0),
                  ("ell", lerp(n0, hd, 0.4) + Vector((0, 0, 0.02 * H)), (0.2 * H, 0.22 * H, 0.17 * H), -na, 0.0)]
        else:  # horse: a crest along the top of the neck
            mb = []
            for i in range(6):
                t = i / 5
                c = lerp(n0, hd, t) + Vector((0, 0.0, p["neck_r"][0] * H * lerp(0.95, 0.75, t)))
                mb.append(("ell", c, (0.06 * H, 0.06 * H, 0.025 * H), 0.0, 0.0))
        d.extra_meshes.append(("mane", mb, None))
        d.part_masks["mane"] = (0.0, 0.7, 1.0)
    if p["beard"] > 0:
        c = d.joints["snout"] - hdir * p["snout_len"] * H * 0.5 - hup * hx[1] * 0.7
        d.extra_meshes.append(("beard", [("ell", c, (0.03 * H, p["beard"] * H, 0.022 * H), 0.0, 0.0)], "head"))
        d.part_masks["beard"] = (0.0, 0.8, 1.0)
    if p["tuft"] > 0:
        d.ell(pts[-1], (p["tuft"] * H * 0.6, p["tuft"] * H, p["tuft"] * H * 0.6))
    return d


# ----------------------------------------------------------------------------- small meshes

def ring_tube(path, radii, sides=10, flat=1.0, up=Vector((0, 0, 1))):
    """Vertices/faces of a tube along path (Vectors) with radii; flat squashes one axis."""
    verts, faces = [], []
    n = len(path)
    for i, pt in enumerate(path):
        a = path[min(i + 1, n - 1)] - path[max(i - 1, 0)]
        a.normalize()
        x = a.cross(up)
        if x.length < 1e-4:
            x = a.cross(Vector((1, 0, 0)))
        x.normalize()
        y = x.cross(a).normalized()
        for k in range(sides):
            t = 2 * math.pi * k / sides
            verts.append(pt + (x * math.cos(t) + y * math.sin(t) * flat) * radii[i])
    for i in range(n - 1):
        for k in range(sides):
            a0 = i * sides + k
            a1 = i * sides + (k + 1) % sides
            faces.append((a0, a1, a1 + sides, a0 + sides))
    # caps
    verts.append(path[0])
    verts.append(path[-1])
    c0, c1 = len(verts) - 2, len(verts) - 1
    for k in range(sides):
        faces.append((c0, (k + 1) % sides, k))
        faces.append((c1, (n - 1) * sides + k, (n - 1) * sides + (k + 1) % sides))
    return verts, faces


def eye_mesh(c, r, look):
    verts, faces = [], []
    nu, nv = 16, 10
    # local frame: z = look
    z = look.normalized()
    x = Vector((0, 0, 1)).cross(z).normalized()
    y = z.cross(x)
    uvs = []
    for j in range(nv + 1):
        th = math.pi * j / nv
        for i in range(nu):
            ph = 2 * math.pi * i / nu
            lp = Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))
            verts.append(c + (x * lp.x + y * lp.y + z * lp.z) * r)
            uvs.append((lp.x * 0.5 + 0.5, lp.y * 0.5 + 0.5) if lp.z > 0 else (0.0, 0.0))
    for j in range(nv):
        for i in range(nu):
            a = j * nu + i
            b = j * nu + (i + 1) % nu
            faces.append((a, a + nu, b + nu, b))
    return verts, faces, uvs


def ear_mesh(ear, base, s, H):
    """A leaf-shaped flap (with thickness) from the base: kinds dog, cat, cow, horse, rabbit, pig, elephant, round."""
    L = ear["len"] * H
    W = ear["w"] * H
    up = math.radians(ear["up"])
    out = math.radians(ear["out"])
    back = math.radians(ear["back"])
    droop = ear.get("droop", 0.0)
    # direction of the ear: start pointing up, tilt outwards and backwards
    d = Vector((math.cos(up) * math.sin(out) * s, math.sin(back) * math.cos(up) + 0.0, math.sin(up)))
    d = Vector((s * math.cos(up), math.sin(back), math.sin(up)))
    d.normalize()
    side = Vector((0, -1, 0)).cross(d)
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    tw = math.radians(ear.get("twist", 0.0)) * s
    side = (side * math.cos(tw) + d.cross(side) * math.sin(tw)).normalized()
    normal = d.cross(side).normalized()
    if normal.y > 0 and abs(tw) < 0.5:
        normal = -normal
    n = 7
    rows = []
    shape = {"dog": lambda t: math.sin(math.pi * min(t * 1.1, 1.0)) ** 0.7,
             "cat": lambda t: (1.0 - t) ** 0.9,
             "rabbit": lambda t: math.sin(math.pi * min(t * 1.05, 1.0)) ** 0.5 * 0.9,
             "cow": lambda t: math.sin(math.pi * min(t * 1.1, 1.0)) ** 0.6,
             "horse": lambda t: (1.0 - t) ** 0.7 * min(1.0, t * 4 + 0.5),
             "pig": lambda t: (1.0 - t) ** 0.8,
             "round": lambda t: math.sin(math.pi * min(t, 1.0)) ** 0.5,
             "elephant": lambda t: math.sin(math.pi * min(t, 1.0)) ** 0.45}[ear["kind"]]
    verts, faces = [], []
    th = max(0.012 * H, 0.003)
    for i in range(n + 1):
        t = i / n
        # droop: bend the ear down along its length
        bend = droop * t * t
        dd = (d * math.cos(bend * 1.6) + Vector((0, 0, -1)) * math.sin(bend * 1.6) + normal * 0.0).normalized()
        if i == 0:
            centre = base.copy()
        else:
            centre = prev_c + dd * (L / n)
        prev_c = centre
        w = W * 0.5 * shape(t)
        cup = 0.25 * w
        row = []
        for k, a in enumerate((-1.0, -0.5, 0.0, 0.5, 1.0)):
            depth = cup * (1 - a * a)
            p = centre + side * (a * w) - normal * depth
            row.append(len(verts))
            verts.append(p + normal * th * 0.5)
            verts.append(p - normal * th * 0.5)
        rows.append(row)
    for i in range(n):
        for k in range(4):
            a, b = rows[i][k], rows[i][k + 1]
            c, e = rows[i + 1][k + 1], rows[i + 1][k]
            faces.append((a, b, c, e))                 # front
            faces.append((a + 1, e + 1, c + 1, b + 1)) # back
        for k in (0, 4):
            a, e = rows[i][k], rows[i + 1][k]
            faces.append((a, e, e + 1, a + 1) if k == 0 else (a, a + 1, e + 1, e))
    tip = prev_c
    return (verts, faces, None), tip


def horn_mesh(root, dirs, length, r0, r1, sides=10, segs=10, H=1.0):
    """A curved, tapering horn: dirs = list of direction vectors it turns through."""
    path = [root]
    radii = [r0]
    p = root.copy()
    for i in range(segs):
        t = (i + 1) / segs
        k = t * (len(dirs) - 1)
        a = int(min(k, len(dirs) - 2))
        dv = dirs[a].lerp(dirs[a + 1], k - a).normalized()
        p = p + dv * (length / segs)
        path.append(p.copy())
        radii.append(lerp(r0, r1, t ** 0.8))
    v, f = ring_tube(path, radii, sides)
    uvs = [((k % sides) / sides, (k // sides) / segs) for k in range(len(path) * sides)] + [(0.0, 0.0), (0.0, 1.0)]
    return v, f, uvs


# ----------------------------------------------------------------------------- build

def surface(bvh, origin, direction, reach):
    """The outermost body surface point from origin along direction."""
    start = origin + direction * reach
    hit = bvh.ray_cast(start, -direction, reach * 1.5)
    if hit[0] is None:
        return origin + direction * reach * 0.3
    return hit[0]


def metaball_mesh(d, faces=14000, name="Body"):
    mb = bpy.data.metaballs.new(d.name + "_mb")
    mb.resolution = d.H * 0.012
    mb.threshold = 0.6
    ob = bpy.data.objects.new(d.name + "_mb", mb)
    bpy.context.scene.collection.objects.link(ob)
    for b in d.blobs:
        e = mb.elements.new()
        e.stiffness = 2.0
        if b[0] == "ell":
            _, c, ax, pitch, yaw = b
            e.type = "ELLIPSOID"
            e.co = c
            e.radius = 1.0 / K
            e.size_x, e.size_y, e.size_z = ax[2], ax[0], ax[1]
            e.rotation = Quaternion((1, 0, 0), pitch)
        else:
            _, a, bb, r = b
            e.type = "CAPSULE"
            e.co = (a + bb) / 2
            e.radius = r / K
            e.size_x = max((bb - a).length / 2, 1e-4)
            dvec = (bb - a).normalized()
            e.rotation = Vector((1, 0, 0)).rotation_difference(dvec)
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.scene.objects:
        o.select_set(o == ob)
    bpy.ops.object.convert(target="MESH")
    body = bpy.context.view_layer.objects.active
    body.name = name
    body.data.name = name
    # even topology, then soften
    area = sum(p.area for p in body.data.polygons)
    m = body.modifiers.new("remesh", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = math.sqrt(area / float(faces))
    m.adaptivity = 0.0
    bpy.ops.object.modifier_apply(modifier="remesh")
    m = body.modifiers.new("smooth", "SMOOTH")
    m.factor = 0.5
    m.iterations = 4
    bpy.ops.object.modifier_apply(modifier="smooth")
    for poly in body.data.polygons:
        poly.use_smooth = True
    return body


def mesh_object(name, data):
    verts, faces, uvs = data
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for poly in me.polygons:
        poly.use_smooth = True
    if uvs:
        uvl = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for li in poly.loop_indices:
                uvl.data[li].uv = uvs[me.loops[li].vertex_index]
    return ob


MAT_COLOURS = {}


def make_material(name, colour=None):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = False
    c = colour or MAT_COLOURS.get(name)
    if c:
        m.diffuse_color = (c[0], c[1], c[2], 1.0)
    return m


def armature(d):
    arm = bpy.data.armatures.new("Armature")
    ob = bpy.data.objects.new("Armature", arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.scene.objects:
        o.select_set(o == ob)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    for name, h, t, parent in d.bones:
        b = arm.edit_bones.new(name)
        b.head = d.joints[h]
        b.tail = d.joints[t]
        if (b.tail - b.head).length < 1e-4:
            b.tail = b.head + Vector((0, 0, 0.01))
        b.roll = 0.0
        eb[name] = b
    for name, h, t, parent in d.bones:
        if parent:
            eb[name].parent = eb[parent]
            eb[name].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def set_attrs(ob, d, kind):
    """UVs (pattern coordinates), vertex-colour masks and materials."""
    me = ob.data
    H = d.H
    while len(me.uv_layers) < 2:
        me.uv_layers.new(name="UV%d" % len(me.uv_layers))
    uv0, uv1 = me.uv_layers[0], me.uv_layers[1]
    col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    me.calc_loop_triangles()
    normals = [v.normal.copy() for v in me.vertices]
    vm = []
    for v in me.vertices:
        if kind == "body":
            vm.append(d.masks(v.co, normals[v.index]))
        elif kind == "ear":
            vm.append(d.ear_mask)
        elif kind in ("mane", "beard", "wings", "tailfan", "wool"):
            vm.append(d.part_masks.get(kind, (0.0, 0.5, 1.0)))
        else:
            vm.append((0.0, 0.0, 0.0))
    keep_uv0 = kind in ("eye", "horns", "antlers", "tusks", "beak", "comb")
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            co = me.vertices[vi].co
            f, u, s = FUS(co)
            if not keep_uv0:
                uv0.data[li].uv = (f / H, u / H)
            uv1.data[li].uv = (s / H, 0.0)
            r, g, b = vm[vi]
            col.data[li].color = (r, g, b, 1.0)
    # materials
    if kind == "body":
        names = ["coat"] + [r[0] for r in d.mat_rules]
        for n in names:
            me.materials.append(make_material(n))
        for poly in me.polygons:
            c = poly.center
            for i, (n, rule) in enumerate(d.mat_rules):
                if rule(c):
                    poly.material_index = i + 1
    else:
        me.materials.append(make_material("coat" if kind in ("ear", "mane", "beard", "wings", "tailfan", "wool") else kind))


def skin_rigid(ob, arm_ob, bone):
    vg = ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm_ob
    m = ob.modifiers.new("Armature", "ARMATURE")
    m.object = arm_ob


def skin_auto(ob, arm_ob):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    ob.select_set(True)
    arm_ob.select_set(True)
    bpy.context.view_layer.objects.active = arm_ob
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    # every vertex needs a bone: fall back to the nearest bone
    groups = {g.index: g.name for g in ob.vertex_groups}
    bones = arm_ob.data.bones
    empty = [v.index for v in ob.data.vertices if not any(g.weight > 1e-4 for g in v.groups)]
    if empty:
        print("  %d vertices without weights, using nearest bone" % len(empty))
        for vi in empty:
            co = ob.data.vertices[vi].co
            best, bd = None, 1e9
            for b in bones:
                a, c = b.head_local, b.tail_local
                ab = c - a
                t = max(0.0, min(1.0, (co - a).dot(ab) / max(ab.length_squared, 1e-9)))
                dist = (a + ab * t - co).length
                if dist < bd:
                    bd, best = dist, b.name
            vg = ob.vertex_groups.get(best) or ob.vertex_groups.new(name=best)
            vg.add([vi], 1.0, "REPLACE")


def chubby_key(ob, d):
    if ob.data.shape_keys is None:
        ob.shape_key_add(name="Basis")
    sk = ob.shape_key_add(name="chubby")
    H = d.H
    p = getattr(d, "params", {})
    sh_u = p.get("sh_u", 0.7) * H
    for v in ob.data.vertices:
        f, u, s = FUS(v.co)
        w = smooth(0.3 * sh_u, 0.75 * sh_u, u) * smooth(H * 0.9, H * 0.4, abs(f))
        sk.data[v.index].co = v.co + v.normal * w * H * 0.045


def build(d, out_dir):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MAT_COLOURS.clear()
    MAT_COLOURS.update({"hoof": (0.09, 0.075, 0.065), "horn": (0.55, 0.5, 0.42), "tusk": (0.86, 0.82, 0.7),
                        "antler": (0.42, 0.33, 0.24), "beak": (0.86, 0.6, 0.15), "feet": (0.86, 0.6, 0.15),
                        "comb": (0.75, 0.07, 0.05), "claw": (0.12, 0.1, 0.09)})
    MAT_COLOURS.update(d.colours)
    body = metaball_mesh(d)
    for g in getattr(d, "pre_parts", []):
        pass
    from mathutils.bvhtree import BVHTree
    bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    for fn in d.deferred:
        for part in fn(bvh):
            if len(part) > 4:
                kind, mesh, bone, mat, base, tip = part
                d.joints[bone + "_base"] = base
                d.joints[bone + "_tip"] = tip
                part = (kind, mesh, bone, mat)
            d.parts.append(part)
    arm_ob = armature(d)
    for kind, blobs, bone in d.extra_meshes:
        sub = Design(kind, d.H)
        sub.blobs = blobs
        ob = metaball_mesh(sub, faces=3000, name=kind.capitalize())
        set_attrs(ob, d, kind)
        if bone is None:
            skin_auto(ob, arm_ob)
        else:
            skin_rigid(ob, arm_ob, bone)
    set_attrs(body, d, "body")
    chubby_key(body, d)
    skin_auto(body, arm_ob)
    for i, (kind, data, bone, mat) in enumerate(d.parts):
        ob = mesh_object("%s%d" % (kind.capitalize(), i), data)
        set_attrs(ob, d, kind)
        if mat not in ("coat",):
            ob.data.materials.clear()
            ob.data.materials.append(make_material(mat))
        if bone is None:
            skin_auto(ob, arm_ob)
        else:
            skin_rigid(ob, arm_ob, bone)
    path = os.path.join(out_dir, d.name + ".glb")
    for o in bpy.context.scene.objects:
        o.select_set(True)
    kw = dict(filepath=path, export_format="GLB", export_skins=True, export_yup=True, export_apply=False,
              export_morph=True, export_animations=False)
    for extra in (dict(export_vertex_color="ACTIVE", export_morph_normal=False), dict(export_colors=True), {}):
        try:
            bpy.ops.export_scene.gltf(**kw, **extra)
            break
        except TypeError as e:
            print("  exporter:", e)
    print("wrote", path, len(body.data.vertices), "verts")


# ----------------------------------------------------------------------------- species

# ----------------------------------------------------------------------------- birds

def bird(name, H=0.4, body=(0.2, 0.15, 0.14), body_u=0.62, body_pitch=-15, neck=(0.18, 55), neck_r=(0.07, 0.05),
         head_r=0.07, beak=(0.08, 0.025, -10), leg_len=0.5, leg_r=0.025, tail=(0.25, 40), comb=False, wattle=False,
         wing=(0.42, 0.2), webbed=False, fur=0.35, eye_r=0.017):
    """Birds: an egg-shaped body, neck chain, head with a beak, thin legs with toes, wings and a tail fan.
    H = height of the back; sizes are in units of H."""
    d = Design(name, H)
    d.params = dict(sh_u=body_u)
    d.fur_len = fur
    bu = body_u * H
    bp = math.radians(body_pitch)
    pel = d.j("pelvis", -0.05 * H, bu)
    ch = d.j("chest", 0.12 * H, bu + 0.03 * H)
    nl = neck[0] * H
    na = math.radians(neck[1])
    n0 = d.j("neck0", 0.2 * H, bu + 0.08 * H)
    d.j("neck1", 0.2 * H + math.cos(na) * nl * 0.5, bu + 0.08 * H + math.sin(na) * nl * 0.5)
    hd = d.j("head", 0.2 * H + math.cos(na) * nl, bu + 0.08 * H + math.sin(na) * nl)
    hc = hd + Vector((0, -head_r * H * 0.35, head_r * H * 0.4))
    d.joints["skull"] = hc
    d.joints["head_end"] = hc + Vector((0, -head_r * H, 0))
    bl, br, bang = beak
    bdir = Vector((0, -math.cos(math.radians(bang)), math.sin(math.radians(bang))))
    tip = hc + bdir * (head_r * H * 0.85 + bl * H)
    d.joints["snout"] = tip
    d.joints["muzzle"] = tip
    d.bone("pelvis", "pelvis", "chest")
    d.bone("chest", "chest", "neck0", "pelvis")
    d.bone("neck1", "neck0", "neck1", "chest")
    d.bone("neck2", "neck1", "head", "neck1")
    d.bone("head", "head", "head_end", "neck2")
    # legs: thigh (in the body) - shin (drumstick) - tarsus - foot
    ll = leg_len * H
    for s in (1, -1):
        m = lambda n: mirror(n, s)
        hip = d.j(m("hip"), -0.02 * H, bu - 0.05 * H, s * 0.07 * H)
        knee = d.j(m("knee"), 0.05 * H, bu - body[1] * H * 0.55, s * 0.08 * H)
        ankle = d.j(m("ankle"), -0.03 * H, ll * 0.6, s * 0.075 * H)
        foot = d.j(m("foot"), -0.01 * H, 0.03 * H, s * 0.075 * H)
        d.j(m("toe"), 0.12 * H, 0.012 * H, s * 0.075 * H)
        d.bone(m("thigh"), m("hip"), m("knee"), "pelvis")
        d.bone(m("shin"), m("knee"), m("ankle"), m("thigh"))
        d.bone(m("tarsus"), m("ankle"), m("foot"), m("shin"))
        d.bone(m("foot"), m("foot"), m("toe"), m("tarsus"))
        d.cap(knee, ankle, 0.05 * H, 0.03 * H)
        d.cap(ankle, foot, leg_r * H, leg_r * H)
        for ang in (-28, 0, 28, 180):
            a = math.radians(ang)
            tl = 0.13 * H if ang != 180 else 0.06 * H
            toe_end = foot + Vector((s * math.sin(a) * tl, -math.cos(a) * tl, -0.02 * H))
            d.cap(foot, toe_end, leg_r * H * 0.7, leg_r * H * 0.45)
        if webbed:
            d.ell(foot + Vector((0, -0.07 * H, -0.02 * H)), (0.07 * H, 0.008 * H, 0.06 * H))
        # wings: bones from the shoulder back along the body
        sh = d.j(m("wingroot"), 0.1 * H, bu + 0.06 * H, s * body[2] * H * 0.75)
        el = d.j(m("wingmid"), -0.08 * H, bu + 0.08 * H, s * body[2] * H * 0.95)
        we = d.j(m("wingtip"), -wing[0] * H * 0.75, bu + 0.06 * H, s * body[2] * H * 0.9)
        d.bone(m("wing"), m("wingroot"), m("wingmid"), "chest")
        d.bone(m("wing2"), m("wingmid"), m("wingtip"), m("wing"))
    # tail
    t0 = d.j("tail0", -body[0] * H * 0.75, bu + 0.02 * H)
    ta = math.radians(tail[1])
    t1 = d.j("tail1", -body[0] * H * 0.75 - math.cos(ta) * tail[0] * H, bu + 0.02 * H + math.sin(ta) * tail[0] * H)
    d.bone("tail1", "tail0", "tail1", "pelvis")
    # body volumes
    d.ell(P(0.02 * H, bu), (body[0] * H, body[1] * H, body[2] * H), pitch=-bp)
    d.ell(P(0.1 * H, bu + 0.02 * H), (body[0] * H * 0.6, body[1] * H * 0.95, body[2] * H * 0.95), pitch=-bp)
    d.cap(n0 - Vector((0, -0.02 * H, 0.03 * H)), hd, neck_r[0] * H, neck_r[1] * H)
    d.ell(hc, (head_r * H, head_r * H * 0.95, head_r * H * 0.9))
    # parts: beak, eyes, wings, tail fan, comb
    beak_v, beak_f, beak_uv = horn_mesh(hc + bdir * head_r * H * 0.55, [bdir, (bdir + Vector((0, 0, -0.25))).normalized()], bl * H + head_r * H * 0.3, br * H, br * H * 0.15, sides=10, segs=6)
    if webbed:  # duck bill: flatten
        beak_v = [Vector((v.x * 1.6, v.y, hc.z + (v.z - hc.z) * 0.45 - 0.004 * H)) for v in beak_v]
    d.parts.append(("beak", (beak_v, beak_f, beak_uv), "head", "beak"))
    def eyes(bvh):
        out = []
        for s in (1, -1):
            aim = Vector((s * 0.85, -0.45, 0.25)).normalized()
            hit = surface(bvh, hc, aim, head_r * H * 3)
            out.append(("eye", eye_mesh(hit - aim * eye_r * H * 0.4, eye_r * H, aim), "head", "eye"))
        return out
    d.deferred.append(eyes)
    for s in (1, -1):
        m = lambda n: mirror(n, s)
        J = d.joints
        root, mid, wt = J[m("wingroot")], J[m("wingmid")], J[m("wingtip")]
        # a feathered wing folded along the body: a flat, slightly curved plate
        verts, faces = [], []
        rows = 8
        for i in range(rows + 1):
            t = i / rows
            c = lerp(lerp(root, mid, min(t * 2, 1.0)), wt, max(t * 2 - 1, 0.0))
            w = wing[1] * H * 0.8 * (0.55 + 0.45 * math.sin(math.pi * min(t * 1.2, 1.0))) * (1.0 - 0.6 * t * t)
            top = c + Vector((s * 0.012 * H, 0, 0.02 * H))
            bot = c + Vector((s * 0.03 * H * (1 - t), 0, -w))
            for k in range(4):
                q = lerp(top, bot, k / 3) + Vector((s * 0.02 * H * math.sin(math.pi * k / 3), 0, 0))
                verts.append(q + Vector((s * 0.004 * H, 0, 0)))
                verts.append(q - Vector((s * 0.004 * H, 0, 0)))
        for i in range(rows):
            for k in range(3):
                a0 = (i * 4 + k) * 2
                b0 = ((i + 1) * 4 + k) * 2
                faces.append((a0, a0 + 2, b0 + 2, b0))
                faces.append((a0 + 1, b0 + 1, b0 + 3, a0 + 3))
        d.parts.append(("wings", (verts, faces, None), m("wing2"), "coat"))
    # tail fan
    verts, faces = [], []
    base_c = J["tail0"]
    tip_c = J["tail1"]
    for i in range(7):
        t = i / 6
        c = lerp(base_c, tip_c, t)
        w = 0.04 * H + tail[0] * H * 0.3 * t
        for k in range(5):
            x = (k / 4 - 0.5) * 2 * w
            q = c + Vector((x, 0, -abs(x) * 0.15))
            verts.append(q + Vector((0, 0, 0.004 * H)))
            verts.append(q - Vector((0, 0, 0.004 * H)))
    for i in range(6):
        for k in range(4):
            a0 = (i * 5 + k) * 2
            b0 = ((i + 1) * 5 + k) * 2
            faces.append((a0, b0, b0 + 2, a0 + 2))
            faces.append((a0 + 1, a0 + 3, b0 + 3, b0 + 1))
    d.parts.append(("tailfan", (verts, faces, None), "tail1", "coat"))
    if comb:
        cv, cf, cuv = [], [], []
        for k in range(5):
            cc = hc + Vector((0, -head_r * H * (0.5 - k * 0.25), head_r * H * 0.85))
            v, f, uv = horn_mesh(cc, [Vector((0, 0, 1)), Vector((0, 0.2, 1)).normalized()], (0.06 - 0.008 * abs(k - 2)) * H, 0.018 * H, 0.01 * H, sides=6, segs=3)
            off = len(cv)
            cv += [Vector((x.x * 0.4 + cc.x * 0.6, x.y, x.z)) for x in v]
            cf += [tuple(i + off for i in face) for face in f]
            cuv += uv
        d.parts.append(("comb", (cv, cf, cuv), "head", "comb"))
    if wattle:
        v, f, uv = horn_mesh(tip - bdir * bl * H * 0.9 + Vector((0, 0, -0.01 * H)), [Vector((0, 0, -1)), Vector((0, 0.2, -1)).normalized()], 0.06 * H, 0.02 * H, 0.016 * H, sides=8, segs=4)
        d.parts.append(("comb", ([Vector((x.x * 0.5, x.y, x.z)) for x in v], f, uv), "head", "comb"))
    def masks(v, n):
        f, u, s_ = FUS(v)
        r = smooth(0.0, -0.6, n.z) * smooth(bu + 0.05 * H, bu - 0.1 * H, u)
        g = smooth(0.25 * H, 0.15 * H, u)
        b = smooth(0.2 * H, 0.32 * H, u)
        return r, g, b
    d.masks = masks
    d.mat_rules.append(("feet", lambda v: v.z < ll * 0.56))
    d.part_masks.update({"wings": (0.0, 0.3, 0.55), "tailfan": (0.0, 0.5, 0.4)})
    return d


# ----------------------------------------------------------------------------- species

CAT_EAR = dict(kind="cat", len=0.24, w=0.22, up=75, back=10, droop=0.0, twist=0, side=0.75, set=0.15)
HOOF = dict(hoof=True, paw_r=0.03, toe=0.03)

SPECIES = {
    "dog": lambda: quad("dog", socks=0.9),
    "cat": lambda: quad("cat", H=0.26, L=0.95, chest=(0.25, 0.68, 0.24, 0.17, 0.14), belly=(0.0, 0.7, 0.3, 0.15, 0.14),
        haunch=(-0.33, 0.73, 0.2, 0.17, 0.15), neck=(0.3, 0.8), neck_len=0.14, neck_angle=30, neck_r=(0.13, 0.12),
        head=(0.16, 0.15, 0.15), head_angle=-5, snout_len=0.04, snout_r=(0.08, 0.06), ear=CAT_EAR,
        eye=dict(r=0.04, f=0.62, u=0.22, s=0.55), tail=dict(len=1.0, r=(0.06, 0.045), up=-35, curl=60, n=6, bushy=0.0),
        thigh_r=(0.13, 0.07), arm_r=(0.1, 0.065), fore_r=(0.05, 0.04), fur=0.5),
    "fox": lambda: quad("fox", H=0.4, L=0.95, snout_len=0.22, snout_r=(0.075, 0.035), head=(0.13, 0.1, 0.1),
        ear=dict(CAT_EAR, len=0.28, w=0.2), tail=dict(len=0.85, r=(0.06, 0.04), up=-20, curl=-10, n=5, bushy=0.11),
        thigh_r=(0.11, 0.065), shin_r=(0.045, 0.035), fore_r=(0.04, 0.032), fur=0.65),
    "wolf": lambda: quad("wolf", H=0.8, L=0.95, snout_len=0.2, snout_r=(0.07, 0.045), head=(0.13, 0.1, 0.1),
        ear=dict(CAT_EAR, len=0.17, w=0.13), tail=dict(len=0.6, r=(0.06, 0.04), up=-55, curl=-5, n=5, bushy=0.08), fur=0.75),
    "tiger": lambda: quad("tiger", H=0.95, L=1.05, chest=(0.26, 0.66, 0.26, 0.2, 0.16), belly=(0.0, 0.68, 0.32, 0.15, 0.15),
        haunch=(-0.34, 0.72, 0.2, 0.18, 0.15), neck_len=0.22, neck_angle=35, neck_r=(0.15, 0.13),
        head=(0.17, 0.15, 0.15), head_angle=-8, snout_len=0.09, snout_r=(0.11, 0.08), snout_drop=0.02,
        ear=dict(kind="round", len=0.1, w=0.1, up=70, back=20, side=0.8, set=0.3), eye=dict(r=0.03, f=0.6, u=0.25, s=0.55),
        tail=dict(len=0.95, r=(0.06, 0.04), up=-50, curl=55, n=6), thigh_r=(0.14, 0.09), shin_r=(0.07, 0.055),
        arm_r=(0.13, 0.09), fore_r=(0.075, 0.06), meta_r=0.05, paw_r=0.06, fur=0.3),
    "lion": lambda: quad("lion", H=1.05, L=1.0, chest=(0.26, 0.66, 0.26, 0.2, 0.16), belly=(0.0, 0.68, 0.32, 0.15, 0.15),
        haunch=(-0.34, 0.72, 0.2, 0.18, 0.15), neck_len=0.22, neck_angle=35, neck_r=(0.15, 0.13),
        head=(0.17, 0.15, 0.15), head_angle=-8, snout_len=0.1, snout_r=(0.11, 0.08), snout_drop=0.02,
        ear=dict(kind="round", len=0.08, w=0.09, up=70, back=20, side=0.8, set=0.3), eye=dict(r=0.028, f=0.6, u=0.25, s=0.55),
        tail=dict(len=0.85, r=(0.05, 0.035), up=-60, curl=40, n=6), tuft=0.05, mane="lion",
        thigh_r=(0.14, 0.09), shin_r=(0.07, 0.055), arm_r=(0.13, 0.09), fore_r=(0.075, 0.06), meta_r=0.05, paw_r=0.06, fur=0.3),
    "bear": lambda: quad("bear", H=1.0, L=0.9, chest=(0.24, 0.62, 0.28, 0.24, 0.2), belly=(0.0, 0.62, 0.32, 0.22, 0.2),
        haunch=(-0.32, 0.68, 0.22, 0.22, 0.19), withers=1.0, croup=0.92, hip=(0.0, 0.7), shoulder=(0.0, 0.6),
        hind=[(0.12, 0.42), (-0.06, 0.12), (0.0, 0.04)], fore=[(-0.04, 0.4), (0.02, 0.1), (0.03, 0.04)], toe=0.16,
        neck_len=0.2, neck_angle=20, neck_r=(0.18, 0.15), head=(0.17, 0.15, 0.15), snout_len=0.13, snout_r=(0.09, 0.06),
        ear=dict(kind="round", len=0.08, w=0.09, up=70, back=10, side=0.8, set=0.2), eye=dict(r=0.018, f=0.7, u=0.3, s=0.5),
        tail=dict(len=0.08, r=(0.05, 0.04), up=-30, curl=0, n=2), thigh_r=(0.17, 0.12), shin_r=(0.1, 0.08), meta_r=0.07,
        arm_r=(0.16, 0.12), fore_r=(0.1, 0.085), paw_r=0.075, fur=0.85, belly_mask=False),
    "monkey": lambda: quad("monkey", H=0.45, L=0.85, chest=(0.22, 0.72, 0.22, 0.16, 0.15), belly=(0.0, 0.72, 0.26, 0.13, 0.13),
        haunch=(-0.3, 0.76, 0.17, 0.15, 0.14), hip=(0.0, 0.8), shoulder=(0.0, 0.72),
        hind=[(0.12, 0.5), (-0.08, 0.15), (0.02, 0.04)], fore=[(-0.06, 0.48), (0.02, 0.1), (0.03, 0.04)], toe=0.14,
        neck_len=0.18, neck_angle=40, neck_r=(0.1, 0.09), head=(0.15, 0.15, 0.14), head_angle=0, snout_len=0.04, snout_r=(0.09, 0.07),
        ear=dict(kind="round", len=0.07, w=0.08, up=10, back=0, twist=80, side=1.0, set=0.0),
        eye=dict(r=0.03, f=0.7, u=0.2, s=0.42), tail=dict(len=1.1, r=(0.04, 0.03), up=20, curl=-60, n=6),
        thigh_r=(0.1, 0.065), shin_r=(0.055, 0.045), arm_r=(0.08, 0.06), fore_r=(0.05, 0.042), meta_r=0.04, paw_r=0.045, fur=0.5),
    "rabbit": lambda: quad("rabbit", H=0.22, L=0.75, chest=(0.22, 0.7, 0.24, 0.22, 0.2), belly=(0.0, 0.72, 0.3, 0.22, 0.22),
        haunch=(-0.3, 0.8, 0.26, 0.28, 0.24), withers=1.0, croup=1.12, hip=(0.0, 0.75), shoulder=(0.0, 0.6),
        hind=[(0.18, 0.5), (-0.12, 0.18), (-0.06, 0.04)], fore=[(-0.02, 0.4), (0.03, 0.1), (0.04, 0.04)], toe=0.3,
        neck_len=0.15, neck_angle=50, neck_r=(0.15, 0.13), head=(0.2, 0.17, 0.16), head_angle=-15, snout_len=0.08, snout_r=(0.11, 0.08),
        ear=dict(kind="rabbit", len=0.5, w=0.2, up=80, back=25, droop=0.1, side=0.4, set=0.15),
        eye=dict(r=0.05, f=0.5, u=0.3, s=0.7), tail=dict(len=0.15, r=(0.08, 0.08), up=40, curl=0, n=2, bushy=0.12),
        thigh_r=(0.2, 0.12), shin_r=(0.08, 0.06), meta_r=0.05, arm_r=(0.1, 0.07), fore_r=(0.06, 0.05), paw_r=0.06, fur=0.75),
    "cow": lambda: quad("cow", H=1.4, L=1.05, chest=(0.26, 0.64, 0.26, 0.22, 0.17), belly=(0.0, 0.6, 0.34, 0.22, 0.2),
        haunch=(-0.34, 0.75, 0.2, 0.18, 0.16), withers=0.98, croup=0.98, hip=(0.0, 0.85), shoulder=(0.0, 0.68),
        hind=[(0.08, 0.52), (-0.1, 0.3), (-0.05, 0.05)], fore=[(-0.05, 0.47), (0.0, 0.2), (0.01, 0.05)],
        neck=(0.34, 0.78), neck_len=0.26, neck_angle=15, neck_r=(0.15, 0.11), jowl=0.09,
        head=(0.14, 0.11, 0.1), head_angle=-55, snout_len=0.2, snout_r=(0.09, 0.08), snout_drop=0.0,
        ear=dict(kind="cow", len=0.14, w=0.09, up=-5, back=10, droop=0.1, twist=60, side=1.0, set=0.15),
        eye=dict(r=0.022, f=0.4, u=0.2, s=0.75), tail=dict(len=0.75, r=(0.035, 0.018), up=-82, curl=0, n=5), tuft=0.04,
        horns=dict(len=0.12, r0=0.03, r1=0.008, up=0.6, side=1.0, set=0.2, dirs=[(0.1, 0.1, 1.0), (0.3, 0.6, 0.4)]),
        thigh_r=(0.13, 0.07), shin_r=(0.055, 0.04), meta_r=0.03, arm_r=(0.11, 0.07), fore_r=(0.05, 0.04), fur=0.15, **HOOF),
    "buffalo": lambda: quad("buffalo", H=1.4, L=1.05, chest=(0.26, 0.64, 0.27, 0.23, 0.19), belly=(0.0, 0.6, 0.35, 0.24, 0.22),
        haunch=(-0.34, 0.75, 0.2, 0.19, 0.17), withers=1.0, croup=0.95, hip=(0.0, 0.83), shoulder=(0.0, 0.66),
        hind=[(0.08, 0.5), (-0.1, 0.28), (-0.05, 0.05)], fore=[(-0.05, 0.45), (0.0, 0.18), (0.01, 0.05)],
        neck=(0.34, 0.8), neck_len=0.22, neck_angle=5, neck_r=(0.17, 0.13),
        head=(0.14, 0.11, 0.11), head_angle=-35, snout_len=0.17, snout_r=(0.09, 0.08),
        ear=dict(kind="cow", len=0.13, w=0.08, up=-15, back=10, droop=0.1, twist=60, side=1.0, set=0.25),
        eye=dict(r=0.02, f=0.4, u=0.2, s=0.75), tail=dict(len=0.6, r=(0.035, 0.018), up=-82, curl=0, n=5), tuft=0.03,
        horns=dict(len=0.55, r0=0.06, r1=0.01, up=0.3, side=1.0, set=0.1, dirs=[(-0.1, 0.0, 1.0), (-0.5, 0.2, 0.6), (-0.6, 0.6, -0.4)]),
        thigh_r=(0.14, 0.08), shin_r=(0.06, 0.045), meta_r=0.035, arm_r=(0.12, 0.08), fore_r=(0.055, 0.045), fur=0.08, belly_mask=False, **HOOF),
    "yak": lambda: quad("yak", H=1.3, L=1.0, chest=(0.26, 0.64, 0.27, 0.23, 0.2), belly=(0.0, 0.58, 0.35, 0.25, 0.22),
        haunch=(-0.34, 0.72, 0.2, 0.19, 0.17), withers=1.05, croup=0.9, hump=0.12, hip=(0.0, 0.8), shoulder=(0.0, 0.64),
        hind=[(0.08, 0.48), (-0.1, 0.26), (-0.05, 0.05)], fore=[(-0.05, 0.43), (0.0, 0.17), (0.01, 0.05)],
        neck=(0.34, 0.72), neck_len=0.2, neck_angle=0, neck_r=(0.18, 0.14),
        head=(0.14, 0.12, 0.11), head_angle=-50, snout_len=0.13, snout_r=(0.085, 0.075),
        ear=dict(kind="cow", len=0.1, w=0.06, up=-10, back=10, droop=0.1, twist=60, side=1.0, set=0.25),
        eye=dict(r=0.02, f=0.4, u=0.2, s=0.75), tail=dict(len=0.6, r=(0.05, 0.05), up=-75, curl=0, n=5), tuft=0.07,
        horns=dict(len=0.35, r0=0.045, r1=0.008, up=0.5, side=1.0, set=0.15, dirs=[(0.0, 0.1, 1.0), (0.2, 0.9, 0.3), (0.0, 0.8, -0.4)]),
        thigh_r=(0.14, 0.08), shin_r=(0.065, 0.05), meta_r=0.04, arm_r=(0.12, 0.08), fore_r=(0.06, 0.05), fur=1.0, belly_mask=False, **HOOF),
    "goat": lambda: quad("goat", H=0.7, L=0.95, chest=(0.25, 0.68, 0.24, 0.18, 0.14), belly=(0.0, 0.66, 0.3, 0.17, 0.16),
        haunch=(-0.33, 0.74, 0.18, 0.15, 0.13), withers=0.97, croup=0.98, hip=(0.0, 0.84),
        hind=[(0.08, 0.52), (-0.1, 0.3), (-0.05, 0.05)], fore=[(-0.05, 0.48), (0.0, 0.2), (0.01, 0.05)],
        neck=(0.33, 0.8), neck_len=0.3, neck_angle=50, neck_r=(0.1, 0.075),
        head=(0.12, 0.1, 0.09), head_angle=-45, snout_len=0.16, snout_r=(0.07, 0.05),
        ear=dict(kind="cow", len=0.17, w=0.08, up=-20, back=20, droop=0.3, twist=60, side=1.0, set=0.2),
        eye=dict(r=0.024, f=0.35, u=0.3, s=0.75), tail=dict(len=0.15, r=(0.04, 0.03), up=50, curl=0, n=2),
        horns=dict(len=0.22, r0=0.03, r1=0.006, up=1.0, side=0.5, set=0.4, dirs=[(-0.2, 1.0, 0.1), (-0.8, 0.5, 0.15), (-0.9, -0.3, 0.2)]),
        beard=0.09, thigh_r=(0.11, 0.06), shin_r=(0.045, 0.035), meta_r=0.028, arm_r=(0.09, 0.06), fore_r=(0.045, 0.035), fur=0.45, belly_mask=False, **HOOF),
    "sheep": lambda: quad("sheep", H=0.72, L=0.95, chest=(0.25, 0.66, 0.28, 0.23, 0.2), belly=(0.0, 0.66, 0.34, 0.23, 0.22),
        haunch=(-0.33, 0.72, 0.24, 0.22, 0.2), withers=1.02, croup=1.0, hip=(0.0, 0.8),
        hind=[(0.08, 0.48), (-0.1, 0.28), (-0.05, 0.05)], fore=[(-0.05, 0.44), (0.0, 0.2), (0.01, 0.05)],
        neck=(0.34, 0.8), neck_len=0.22, neck_angle=35, neck_r=(0.15, 0.1),
        head=(0.12, 0.1, 0.09), head_angle=-45, snout_len=0.13, snout_r=(0.07, 0.05),
        ear=dict(kind="cow", len=0.13, w=0.07, up=-10, back=10, droop=0.2, twist=60, side=1.0, set=0.25),
        eye=dict(r=0.022, f=0.35, u=0.3, s=0.75), tail=dict(len=0.2, r=(0.06, 0.05), up=-70, curl=0, n=2), points_face=1.0,
        horns=dict(len=0.28, r0=0.04, r1=0.01, up=0.7, side=0.8, set=0.3, dirs=[(-0.3, 1.0, 0.4), (-0.6, -0.2, 0.8), (0.6, -0.6, 0.3), (0.8, 0.2, 0.1)]),
        thigh_r=(0.1, 0.05), shin_r=(0.04, 0.03), meta_r=0.025, arm_r=(0.08, 0.05), fore_r=(0.04, 0.03), fur=1.0, belly_mask=False, **HOOF),
    "horse": lambda: quad("horse", H=1.55, L=0.95, chest=(0.26, 0.66, 0.24, 0.19, 0.14), belly=(0.0, 0.67, 0.32, 0.16, 0.15),
        haunch=(-0.33, 0.76, 0.2, 0.17, 0.15), withers=1.0, croup=0.98, hip=(0.0, 0.85), shoulder=(0.0, 0.68),
        hind=[(0.08, 0.55), (-0.12, 0.33), (-0.04, 0.05)], fore=[(-0.05, 0.5), (0.0, 0.25), (0.02, 0.05)],
        neck=(0.3, 0.86), neck_len=0.45, neck_angle=50, neck_r=(0.13, 0.08), mane="horse",
        head=(0.12, 0.09, 0.075), head_angle=-62, snout_len=0.3, snout_r=(0.07, 0.065),
        ear=dict(kind="horse", len=0.1, w=0.05, up=80, back=10, side=0.5, set=0.2),
        eye=dict(r=0.02, f=0.4, u=0.25, s=0.8), tail=dict(len=0.6, r=(0.05, 0.06), up=-70, curl=0, n=5, bushy=0.05),
        thigh_r=(0.12, 0.06), shin_r=(0.05, 0.035), meta_r=0.025, arm_r=(0.1, 0.06), fore_r=(0.045, 0.035), fur=0.1, belly_mask=False, **HOOF),
    "donkey": lambda: quad("donkey", H=1.15, L=0.95, chest=(0.26, 0.66, 0.24, 0.19, 0.15), belly=(0.0, 0.66, 0.32, 0.17, 0.16),
        haunch=(-0.33, 0.76, 0.2, 0.17, 0.15), withers=1.0, croup=1.0, hip=(0.0, 0.85),
        hind=[(0.08, 0.53), (-0.12, 0.31), (-0.04, 0.05)], fore=[(-0.05, 0.48), (0.0, 0.23), (0.02, 0.05)],
        neck=(0.3, 0.84), neck_len=0.4, neck_angle=40, neck_r=(0.13, 0.09), mane="horse",
        head=(0.14, 0.1, 0.09), head_angle=-55, snout_len=0.28, snout_r=(0.08, 0.075),
        ear=dict(kind="rabbit", len=0.24, w=0.09, up=75, back=20, side=0.5, set=0.2),
        eye=dict(r=0.02, f=0.4, u=0.25, s=0.8), tail=dict(len=0.5, r=(0.035, 0.02), up=-80, curl=0, n=5), tuft=0.04,
        thigh_r=(0.12, 0.06), shin_r=(0.05, 0.035), meta_r=0.025, arm_r=(0.1, 0.06), fore_r=(0.045, 0.035), fur=0.25, **HOOF),
    "deer": lambda: quad("deer", H=1.0, L=0.9, chest=(0.25, 0.68, 0.22, 0.17, 0.13), belly=(0.0, 0.69, 0.28, 0.14, 0.13),
        haunch=(-0.32, 0.77, 0.18, 0.15, 0.13), withers=0.98, croup=1.0, hip=(0.0, 0.87), shoulder=(0.0, 0.7),
        hind=[(0.08, 0.56), (-0.12, 0.33), (-0.04, 0.05)], fore=[(-0.05, 0.52), (0.0, 0.25), (0.02, 0.05)],
        neck=(0.3, 0.84), neck_len=0.42, neck_angle=58, neck_r=(0.1, 0.07),
        head=(0.12, 0.09, 0.08), head_angle=-45, snout_len=0.17, snout_r=(0.06, 0.045),
        ear=dict(kind="cat", len=0.17, w=0.1, up=40, back=10, side=1.0, set=0.3), antlers=0.45,
        eye=dict(r=0.025, f=0.4, u=0.3, s=0.8), tail=dict(len=0.12, r=(0.04, 0.03), up=40, curl=0, n=2),
        thigh_r=(0.11, 0.055), shin_r=(0.045, 0.03), meta_r=0.022, arm_r=(0.09, 0.055), fore_r=(0.04, 0.03), fur=0.15, **HOOF),
    "pig": lambda: quad("pig", H=0.8, L=1.05, chest=(0.25, 0.6, 0.28, 0.26, 0.22), belly=(0.0, 0.58, 0.36, 0.26, 0.24),
        haunch=(-0.34, 0.66, 0.24, 0.25, 0.22), withers=1.0, croup=1.0, hip=(0.0, 0.62), shoulder=(0.0, 0.52),
        hind=[(0.06, 0.36), (-0.06, 0.18), (-0.02, 0.05)], fore=[(-0.03, 0.34), (0.0, 0.14), (0.01, 0.05)],
        neck=(0.38, 0.68), neck_len=0.12, neck_angle=10, neck_r=(0.22, 0.2),
        head=(0.18, 0.16, 0.15), head_angle=-15, snout_len=0.16, snout_r=(0.11, 0.075),
        ear=dict(kind="pig", len=0.15, w=0.13, up=50, back=-30, droop=0.6, side=0.8, set=0.1),
        eye=dict(r=0.016, f=0.55, u=0.35, s=0.65), tail=dict(len=0.2, r=(0.02, 0.012), up=30, curl=300, n=6),
        thigh_r=(0.12, 0.07), shin_r=(0.06, 0.045), meta_r=0.035, arm_r=(0.11, 0.07), fore_r=(0.055, 0.045), fur=0.04, belly_mask=False, **HOOF),
    "elephant": lambda: quad("elephant", H=2.7, L=0.85, chest=(0.22, 0.62, 0.25, 0.25, 0.2), belly=(0.0, 0.6, 0.32, 0.26, 0.22),
        haunch=(-0.3, 0.7, 0.2, 0.22, 0.19), withers=1.02, croup=0.95, hip=(0.0, 0.66), shoulder=(0.0, 0.62),
        hind=[(0.03, 0.38), (0.0, 0.12), (0.0, 0.04)], fore=[(0.0, 0.38), (0.0, 0.12), (0.0, 0.04)],
        neck=(0.3, 0.75), neck_len=0.12, neck_angle=20, neck_r=(0.2, 0.19),
        head=(0.17, 0.18, 0.15), head_angle=-20, snout_len=0.04, snout_r=(0.08, 0.075), trunk=0.6, tusks=0.3,
        ear=dict(kind="elephant", len=0.42, w=0.36, up=-55, back=20, droop=0.1, twist=80, side=1.0, set=0.4),
        eye=dict(r=0.012, f=0.6, u=0.0, s=0.85), tail=dict(len=0.4, r=(0.025, 0.012), up=-80, curl=0, n=4), tuft=0.02,
        thigh_r=(0.13, 0.1), shin_r=(0.095, 0.09), meta_r=0.085, arm_r=(0.12, 0.1), fore_r=(0.095, 0.09),
        fur=0.0, belly_mask=False, **dict(HOOF, paw_r=0.09)),
    "chicken": lambda: bird("chicken", H=0.42, body=(0.24, 0.19, 0.16), body_u=0.6, neck=(0.2, 70), head_r=0.08,
        beak=(0.08, 0.04, -15), leg_len=0.42, comb=True, wattle=True, tail=(0.2, 55), fur=0.45),
    "duck": lambda: bird("duck", H=0.36, body=(0.28, 0.17, 0.17), body_u=0.55, body_pitch=-5, neck=(0.25, 70), head_r=0.08,
        beak=(0.14, 0.06, -5), leg_len=0.3, webbed=True, tail=(0.12, 20), fur=0.35),
    "bird": lambda: bird("bird", H=0.12, body=(0.26, 0.2, 0.18), body_u=0.62, body_pitch=-25, neck=(0.12, 70), head_r=0.13,
        beak=(0.08, 0.035, -5), leg_len=0.4, tail=(0.45, 25), fur=0.3, eye_r=0.03),
}

if __name__ == "__main__":
    out = sys.argv[1]
    names = sys.argv[2:] or list(SPECIES)
    os.makedirs(out, exist_ok=True)
    for n in names:
        print("building", n)
        build(SPECIES[n](), out)

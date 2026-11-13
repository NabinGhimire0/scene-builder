"""Hair: layered shells over the scalp (with strand textures), plus a bob curtain or a bun."""
import math, os
import numpy as np
import bpy
from PIL import Image
import texgen as T


def _head_center(P):
    V = P.vb
    head = P.W[:, P.bidx["head"]] > 0.85
    body = np.zeros(len(V), bool)
    body[P.base.groups["body"]] = True
    mid, _, _ = P.head_frame()
    sel = head & body & (V[:, 2] > mid[2] - 0.02)
    c = V[sel].mean(axis=0)
    return c, V[sel]


def _strands(phi, th, seed, density=1.0):
    q = np.stack([phi * 160 * density, th * 6.0, np.full_like(phi, seed * 3.1)], axis=1)
    fine = T.noise3(q, 1.0, seed)
    q2 = np.stack([phi * 30, th * 2.0, np.full_like(phi, seed)], axis=1)
    clump = T.noise3(q2, 1.0, seed + 5)
    return fine, clump


def _colour(base, fine, clump, th, gloss=0.25):
    base = np.ones(3) / 1.3      # neutral: the material colour (hair colour x 1.3) tints it
    c = base[None, :] * (0.62 + 0.45 * fine[:, None] + 0.18 * clump[:, None])
    # a soft sheen band
    band = np.exp(-((th - 0.55) / 0.12) ** 2) * gloss
    return np.clip(c + band[:, None] * (0.25 + base[None, :]) * fine[:, None], 0, 1)


def build(P, arm, tex_dir, make_object, new_material, skin_object):
    import build as B
    spec = P.spec
    hair = spec["hair"]
    style = hair.get("style", "short")
    base_col = np.array(hair.get("color", [0.08, 0.06, 0.05]))
    tint = tuple(np.minimum(base_col * 1.3, 1.0))
    V = P.vb
    c, headpts = _head_center(P)
    head_i = P.bidx["head"]
    Wh = np.zeros((1, len(P.bones)), np.float32)
    Wh[0, head_i] = 1
    vol = hair.get("volume", 1.0) * (1.6 if style in ("bob", "bun", "long") else 1.0)

    # ---------- cap shells (body UV space)
    h = P.hairline(V)
    vspec, faces, uvs = B.clip_mesh(P.body_faces, [[tuple(P.base.uvs[t]) for t in fu] for fu in P.body_fuv], h + 0.002)
    ia = np.array([v[1] for v in vspec])
    ib = np.array([v[2] if v[0] == "e" else v[1] for v in vspec])
    tt = np.array([v[3] if v[0] == "e" else 0.0 for v in vspec])[:, None]
    pos = V[ia] * (1 - tt) + V[ib] * tt
    nor = P.normals[ia] * (1 - tt) + P.normals[ib] * tt
    nor /= np.linalg.norm(nor, axis=1)[:, None]
    hv = h[ia] * (1 - tt[:, 0]) + h[ib] * tt[:, 0]
    taper = T.smoothstep(0.0, 0.035, hv)

    # texture: rasterize cap polygons with position + hairline value
    size = 1024
    tuv, attr = [], []
    for f, uv in zip(faces, uvs):
        for k in range(1, len(f) - 1):
            ids = (0, k, k + 1)
            tuv.append([uv[i] for i in ids])
            attr.append([list(pos[f[i]]) + [hv[f[i]]] for i in ids])
    img, mask = T.rasterize(np.array(tuv), np.array(attr, np.float64), size)
    img = T.dilate(img, mask)
    Pp = img[..., :3].reshape(-1, 3).astype(np.float64)
    Hh = img[..., 3].reshape(-1)
    rel = Pp - c
    phi = np.arctan2(rel[:, 0], -rel[:, 1])
    th = np.arccos(np.clip(rel[:, 2] / np.maximum(np.linalg.norm(rel, axis=1), 1e-6), -1, 1)) / math.pi
    layers = hair.get("layers", 3)
    mats = []
    images = []
    for L in range(layers + 1):
        fine, clump = _strands(phi, th, 3 + L)
        col = _colour(base_col, fine, clump, th, hair.get("gloss", 0.25))
        if L == 0:
            alpha = np.clip(T.smoothstep(-0.002, 0.01, Hh) * 1.2, 0, 1)
        else:
            thr = 0.30 + 0.16 * L
            alpha = T.smoothstep(thr, thr + 0.12, fine * 0.75 + clump * 0.35) * T.smoothstep(0.004 * L, 0.02 + 0.006 * L, Hh)
        rgba = np.concatenate([col, alpha[:, None]], axis=1).reshape(size, size, 4)
        path = os.path.join(tex_dir, "hair%d.png" % L)
        Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA").save(path)
        bimg = bpy.data.images.load(path)
        bimg.name = spec.get("name", "person") + "_hair%d" % L
        m = new_material("Hair%d" % L, color=tint, image=bimg, rough=0.55, alpha_clip=True)
        m.use_backface_culling = False
        mats.append(m)
    for L in range(layers + 1):
        d = (0.0025 + 0.0045 * L * vol) * (0.35 + 0.65 * taper) + 0.0015
        Vc = pos + nor * d[:, None]
        ob = make_object("Hair" if L == 0 else "Hair%d" % L, Vc, faces, uvs, [mats[L]])
        Wc = P.W[ia] * (1 - tt) + P.W[ib] * tt
        skin_object(ob, arm, range(len(Vc)), Wc, P.bones)

    if style == "bob":
        _curtain(P, arm, c, headpts, hair, base_col, tex_dir, make_object, new_material, skin_object, Wh, vol)
    if style in ("ponytail", "pigtails"):
        _ponytail(P, arm, c, headpts, hair, base_col, tex_dir, make_object, new_material, skin_object, Wh, style)
    if style == "bun":
        _bun(P, arm, c, headpts, hair, base_col, tex_dir, make_object, new_material, skin_object, Wh)


def _radius_at(headpts, c, ang, z, band=0.02):
    rel = headpts - c
    a = np.arctan2(rel[:, 0], -rel[:, 1])
    sel = (np.abs(np.angle(np.exp(1j * (a - ang)))) < 0.25) & (np.abs(headpts[:, 2] - z) < band)
    if not sel.any():
        return 0.09
    return np.hypot(rel[sel, 0], rel[sel, 1]).max()


def _curtain(P, arm, c, headpts, hair, base_col, tex_dir, make_object, new_material, skin_object, Wh, vol):
    length = hair.get("length", 0.13)
    a0 = math.radians(hair.get("front_angle", 62))
    nu, nv = 56, 10
    mid, _, _ = P.head_frame()
    verts, uvs_v = [], []
    angs = np.linspace(a0, 2 * math.pi - a0, nu)
    for a in angs:
        aa = a if a <= math.pi else a - 2 * math.pi
        # where the cap's hairline is in this direction
        top_z = c[2] + 0.02
        r_top = _radius_at(headpts, c, aa, top_z) + 0.006 + 0.012 * vol
        r_max = max(_radius_at(headpts, c, aa, z) for z in np.linspace(mid[2] - 0.06, top_z, 6)) + 0.010 + 0.010 * vol
        for j in range(nv + 1):
            t = j / nv
            z = top_z - t * (length + (top_z - mid[2]))
            r = r_top + (r_max - r_top) * T.smoothstep(0.0, 0.35, t) + 0.012 * t * t
            x = c[0] + math.sin(aa) * r
            y = c[1] - math.cos(aa) * r
            verts.append((x, y, z))
            uvs_v.append(((a - a0) / (2 * math.pi - 2 * a0), 1 - t))
    verts = np.array(verts)
    faces, fuv = [], []
    for i in range(nu - 1):
        for j in range(nv):
            q = [i * (nv + 1) + j, (i + 1) * (nv + 1) + j, (i + 1) * (nv + 1) + j + 1, i * (nv + 1) + j + 1]
            faces.append(q)
            fuv.append([uvs_v[k] for k in q])
    # strand texture along v
    S = 512
    u, v = np.meshgrid(np.linspace(0, 1, S), np.linspace(1, 0, S))
    u, v = u.reshape(-1), v.reshape(-1)
    for L, (inset, thr) in enumerate(((-0.005, None), (0.0, 0.45), (0.005, 0.6))):
        fine, clump = _strands(u * 9.0, 1 - v, 20 + L)
        col = _colour(base_col, fine, clump, 0.3 + (1 - v) * 0.5, hair.get("gloss", 0.25))
        tip = 1 - v
        cut = 0.9 + 0.1 * T.noise3(np.stack([u * 400, u * 3, np.zeros_like(u)], 1), 1.0, 40 + L)
        alpha = T.smoothstep(cut, cut - 0.06, tip)
        if thr is not None:
            alpha *= T.smoothstep(thr, thr + 0.12, fine * 0.75 + clump * 0.35)
        rgba = np.concatenate([col, alpha[:, None]], axis=1).reshape(S, S, 4)
        path = os.path.join(tex_dir, "bob%d.png" % L)
        Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA").save(path)
        bimg = bpy.data.images.load(path)
        m = new_material("Bob%d" % L, color=tuple(np.minimum(base_col * 1.3, 1.0)), image=bimg, rough=0.55, alpha_clip=True)
        m.use_backface_culling = False
        rel = verts - c
        rel[:, 2] = 0
        out = rel / np.maximum(np.linalg.norm(rel, axis=1), 1e-6)[:, None]
        ob = make_object("HairBob%d" % L, verts + out * inset, faces, fuv, [m])
        skin_object(ob, arm, [0] * len(verts), Wh, P.bones)


def _bun(P, arm, c, headpts, hair, base_col, tex_dir, make_object, new_material, skin_object, Wh):
    rb = _radius_at(headpts, c, math.pi, c[2] + 0.02)
    ctr = c + np.array([0, rb + 0.02, 0.035])
    rad = np.array([0.042, 0.036, 0.038]) * hair.get("bun_size", 1.0)
    nu, nv = 24, 12
    verts, uvl = [], []
    for j in range(nv + 1):
        th = math.pi * j / nv
        for i in range(nu + 1):
            ph = 2 * math.pi * i / nu
            verts.append(ctr + rad * np.array([math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)]))
            uvl.append((i / nu, 1 - j / nv))
    faces, fuv = [], []
    for j in range(nv):
        for i in range(nu):
            q = [j * (nu + 1) + i, j * (nu + 1) + i + 1, (j + 1) * (nu + 1) + i + 1, (j + 1) * (nu + 1) + i]
            faces.append(q[::-1])
            fuv.append([uvl[k] for k in q[::-1]])
    S = 256
    u, v = np.meshgrid(np.linspace(0, 1, S), np.linspace(1, 0, S))
    u, v = u.reshape(-1), v.reshape(-1)
    fine, clump = _strands(u * 6 + v * 3, v, 31)
    col = _colour(base_col, fine, clump, v, hair.get("gloss", 0.25))
    path = os.path.join(tex_dir, "bun.jpg")
    Image.fromarray((col.reshape(S, S, 3) * 255).astype(np.uint8), "RGB").save(path)
    m = new_material("Bun", color=tuple(np.minimum(base_col * 1.3, 1.0)), image=bpy.data.images.load(path), rough=0.55)
    ob = make_object("HairBun", np.array(verts), faces, fuv, [m], recalc=True)
    skin_object(ob, arm, [0] * len(verts), Wh, P.bones)


def _ponytail(P, arm, c, headpts, hair, base_col, tex_dir, make_object, new_material, skin_object, Wh, style):
    length = hair.get("length", 0.20)
    S = 256
    u, v = np.meshgrid(np.linspace(0, 1, S), np.linspace(1, 0, S))
    u, v = u.reshape(-1), v.reshape(-1)
    fine, clump = _strands(u * 5, 1 - v, 51)
    col = _colour(base_col, fine, clump, 0.3 + (1 - v) * 0.4, hair.get("gloss", 0.25))
    path = os.path.join(tex_dir, "tail.jpg")
    Image.fromarray((col.reshape(S, S, 3) * 255).astype(np.uint8), "RGB").save(path)
    m = new_material("Ponytail", color=tuple(np.minimum(base_col * 1.3, 1.0)), image=bpy.data.images.load(path), rough=0.55)
    tie = new_material("HairTie", color=tuple(hair.get("tie", [0.85, 0.15, 0.2])), rough=0.5)
    anchors = []
    if style == "ponytail":
        rb = _radius_at(headpts, c, math.pi, c[2] + 0.03)
        anchors.append((c + np.array([0, rb + 0.004, 0.03]), np.array([0, 1.0, 0])))
    else:
        for sx in (1, -1):
            ang = sx * math.radians(125)
            r = _radius_at(headpts, c, ang, c[2] + 0.0)
            d = np.array([math.sin(ang), -math.cos(ang), 0])
            anchors.append((c + d * (r + 0.004) + np.array([0, 0, 0.0]), d))
    for n, (A, out) in enumerate(anchors):
        p1 = A + out * 0.05
        p2 = A + out * 0.045 - np.array([0, 0, length])
        rings, nr, ns = [], 12, 14
        verts, uvl = [], []
        for k in range(ns + 1):
            t = k / ns
            p = (1 - t) ** 2 * A + 2 * (1 - t) * t * p1 + t * t * p2
            dp = 2 * (1 - t) * (p1 - A) + 2 * t * (p2 - p1)
            dp /= np.linalg.norm(dp)
            a1 = np.cross(dp, [1.0, 0, 0])
            if np.linalg.norm(a1) < 1e-3:
                a1 = np.cross(dp, [0, 1.0, 0])
            a1 /= np.linalg.norm(a1)
            a2 = np.cross(dp, a1)
            r = 0.020 * (1 - t) ** 0.7 + 0.004 if t > 0.08 else 0.012 + 0.08 * t
            for j in range(nr + 1):
                ang = 2 * math.pi * j / nr
                verts.append(p + (a1 * math.cos(ang) + a2 * math.sin(ang) * 0.8) * r)
                uvl.append((j / nr, 1 - t))
        faces, fuv, fm = [], [], []
        for k in range(ns):
            for j in range(nr):
                q = [k * (nr + 1) + j, k * (nr + 1) + j + 1, (k + 1) * (nr + 1) + j + 1, (k + 1) * (nr + 1) + j]
                faces.append(q)
                fuv.append([uvl[i] for i in q])
                fm.append(1 if k == 1 else 0)
        ob = make_object("HairTail%d" % n, np.array(verts), faces, fuv, [m, tie], fm, recalc=True)
        skin_object(ob, arm, [0] * len(verts), Wh, P.bones)

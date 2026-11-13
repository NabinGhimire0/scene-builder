"""Builds one realistic person (MakeHuman CC0 data + CMU motion capture) and exports a GLB.

Usage: blender-python -I build.py <spec.json> <out.glb> [preview.png]
"""
import sys, os, json, math
CODE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, CODE)
import numpy as np
import bpy
from PIL import Image
import mhcore as M
import bvhret as R
import texgen as T
import clips as CL

FPS = 30.0


# ---------------------------------------------------------------- geometry helpers

def tris_of(faces):
    out = []
    for fi, f in enumerate(faces):
        for k in range(1, len(f) - 1):
            out.append((fi, 0, k, k + 1))
    return out


def vertex_normals(V, faces):
    N = np.zeros_like(V)
    for f in faces:
        p = V[f]
        if len(f) == 4:
            n = np.cross(p[2] - p[0], p[3] - p[1])
        else:
            n = np.cross(p[1] - p[0], p[2] - p[0])
        N[f] += n
    l = np.linalg.norm(N, axis=1)
    l[l == 0] = 1
    return N / l[:, None]


def smooth_values(vals, faces, n, iters=2):
    """Average a per-vertex value with its neighbours (over faces)."""
    vals = vals.astype(float).copy()
    for _ in range(iters):
        acc = np.zeros_like(vals)
        cnt = np.zeros(n)
        for f in faces:
            m = vals[f].mean(axis=0)
            acc[f] += m
            cnt[f] += 1
        ok = cnt > 0
        vals[ok] = acc[ok] / cnt[ok] if vals.ndim == 1 else acc[ok] / cnt[ok][:, None]
    return vals


# ---------------------------------------------------------------- the person

class Person:
    def __init__(self, spec):
        self.spec = spec
        self.base = M.BaseMesh()
        self.vobj = M.morph(self.base, spec)
        self.vb = M.to_blender(self.vobj)
        self.rig, wjson = M.load_rig("game_engine")
        self.bones = list(self.rig.keys())
        self.bidx = {b: i for i, b in enumerate(self.bones)}
        nv = len(self.vb)
        W = np.zeros((nv, len(self.bones)), np.float32)
        for b, lst in wjson.items():
            if b in self.bidx:
                for vi, w in lst:
                    W[vi, self.bidx[b]] += w
        s = W.sum(axis=1)
        s[s == 0] = 1
        self.W = W / s[:, None]
        self.joints = M.joint_positions(self.base, self.vobj, self.rig)
        self.body_faces = [self.base.faces[i] for i in self.base.faces_of("body")]
        self.body_fuv = [self.base.fuv[i] for i in self.base.faces_of("body")]
        self.normals = vertex_normals(self.vb, self.body_faces)
        self.eye_c = {s: self.vb[self.base.groups["helper-%s-eye" % s]].mean(axis=0) for s in ("l", "r")}

    def jh(self, b):
        return self.joints[b][0]

    def wsum(self, names):
        return self.W[:, [self.bidx[n] for n in names if n in self.bidx]].sum(axis=1)

    # ------------------------------------------------------------ clothes regions
    def fields(self):
        """Per base vertex, for each garment: signed distance-like value (>0 = covered)."""
        o = self.spec.get("outfit", {})
        top = o.get("top", {}).get("style", "tshirt")
        bottom = o.get("bottom", {}).get("style", "trousers")
        shoes = o.get("shoes", {}).get("style", "shoes")
        V = self.vb
        fingers = ["thumb", "index", "middle", "ring", "pinky"]
        arm = {s: self.wsum(["upperarm_" + s, "lowerarm_" + s, "hand_" + s] + ["%s_0%d_%s" % (f, k, s) for f in fingers for k in (1, 2, 3)]) for s in "lr"}
        leg = {s: self.wsum(["thigh_" + s, "calf_" + s, "foot_" + s, "ball_" + s]) for s in "lr"}

        def chain_t(p, a, b, c):
            ab = b - a
            t = np.dot(p - a, ab) / np.dot(ab, ab)
            bc = c - b
            t2 = 1 + np.dot(p - b, bc) / np.dot(bc, bc)
            return np.where(t > 1, t2, t)

        armt = {s: chain_t(V, self.jh("upperarm_" + s), self.jh("lowerarm_" + s), self.jh("hand_" + s)) for s in "lr"}
        legt = {s: chain_t(V, self.jh("thigh_" + s), self.jh("calf_" + s), self.jh("foot_" + s)) for s in "lr"}
        self.armt, self.legt = armt, legt
        a = np.maximum(arm["l"], arm["r"])
        at = np.where(arm["l"] >= arm["r"], armt["l"], armt["r"])
        lt = np.where(leg["l"] >= leg["r"], legt["l"], legt["r"])
        L_arm = np.linalg.norm(self.jh("lowerarm_l") - self.jh("upperarm_l")) + np.linalg.norm(self.jh("hand_l") - self.jh("lowerarm_l"))
        L_leg = np.linalg.norm(self.jh("calf_l") - self.jh("thigh_l")) + np.linalg.norm(self.jh("foot_l") - self.jh("calf_l"))
        neck = self.jh("neck_01")
        pel = self.jh("pelvis")
        sp1 = self.jh("spine_01")
        hipz = self.jh("thigh_l")[2]
        ankle = self.jh("foot_l")[2]
        waist_z = pel[2] + (sp1[2] - pel[2]) * 0.55
        armx = np.where(a > 0.5, -1.0, 1.0)
        out = {}
        if "top" in o:
            sleeve = {"tshirt": 0.42, "shortsleeve": 0.42, "longsleeve": 1.93, "hoodie": 1.93, "raincoat": 1.95,
                      "kurta": 1.75, "sweater": 1.93, "shirt": 1.93}.get(top, 0.45)
            sleeve = o["top"].get("sleeve", sleeve)
            front = np.clip((neck[1] - V[:, 1]) / 0.07, 0, 1)
            d0, d1 = (0.004, 0.012) if top in ("hoodie", "sweater", "raincoat") else (0.012, 0.03)
            neck_s = (neck[2] - d0 - d1 * front) - V[:, 2]
            sleeve_s = np.where(a > 0.5, (sleeve - at) * L_arm / 2, 1.0)
            low = o["top"].get("length", {"raincoat": 0.06, "kurta": 0.12}.get(top, -0.07))
            hem_z = hipz - low * L_leg / 2 if low > 0 else waist_z + low
            hem_s = np.where(a > 0.5, 1.0, V[:, 2] - hem_z)
            out["top"] = np.minimum(np.minimum(neck_s, sleeve_s), hem_s)
        shoe_top = ankle + {"boots": 0.12, "sandals": -0.02}.get(shoes, 0.035)
        self.shoe_top = shoe_top
        if "bottom" in o:
            waist_s = np.minimum(waist_z - V[:, 2], armx)
            pant = {"shorts": 0.62, "longshorts": 0.85}.get(bottom)
            if pant is not None:
                hem = (pant - lt) * L_leg / 2
            else:
                hem = V[:, 2] - (shoe_top - (0.03 if shoes == "boots" else 0.012))
            out["bottom"] = np.minimum(waist_s, hem)
        if "shoes" in o:
            out["shoes"] = np.minimum(shoe_top - V[:, 2], armx)
        return out

    # ------------------------------------------------------------ skin texture
    def paint_skin(self, size=2048):
        sp = self.spec
        base = self.base
        uv = base.uvs
        tri = tris_of(self.body_faces)
        F = self.body_faces
        FU = self.body_fuv
        tuv = np.array([[uv[FU[fi][a]], uv[FU[fi][b]], uv[FU[fi][c]]] for fi, a, b, c in tri])
        pos = np.array([[self.vb[F[fi][a]], self.vb[F[fi][b]], self.vb[F[fi][c]]] for fi, a, b, c in tri])
        nor = np.array([[self.normals[F[fi][a]], self.normals[F[fi][b]], self.normals[F[fi][c]]] for fi, a, b, c in tri])
        img, mask = T.rasterize(tuv, np.concatenate([pos, nor], axis=2), size)
        img = T.dilate(img, mask)
        P = img[..., :3].reshape(-1, 3).astype(np.float64)
        Nn = img[..., 3:6].reshape(-1, 3)

        def m(name):
            im = Image.open(M.MPFB + "/textures/mpfb_%s.jpg" % name).convert("L").resize((size, size), Image.BILINEAR)
            return np.asarray(im, np.float32).reshape(-1) / 255.0

        tone = np.array(sp.get("skin", [0.80, 0.60, 0.48]))
        red = np.array([0.80, 0.38, 0.34]) * (0.6 + 0.4 * tone.mean() / 0.7)
        col = np.tile(tone, (len(P), 1))
        n1 = T.fbm(P, 9.0, 4, 1)
        n2 = T.noise3(P, 140.0, 7)
        n3 = T.noise3(P, 420.0, 9)
        col *= (0.93 + 0.12 * n1)[:, None]
        col *= (0.985 + 0.03 * n2 + 0.02 * n3)[:, None]
        blot = T.fbm(P, 22.0, 3, 5)
        redness = 0.10 * T.smoothstep(0.45, 0.8, blot)

        el, er = self.eye_c["l"], self.eye_c["r"]
        mid = (el + er) / 2
        eye_dx = abs(el[0] - er[0]) / 2
        head = self.jh("head")
        face_front = (P[:, 1] < mid[1] + 0.03) & (P[:, 2] > head[2] - 0.05)
        kid = sp.get("age", 25) < 14
        for e in (el, er):
            s = np.sign(e[0])
            ck = e + np.array([s * 0.010, -0.010, -0.036])
            d = np.linalg.norm(P - ck, axis=1)
            redness += (0.30 if kid else 0.16) * np.exp(-(d / 0.022) ** 2) * face_front
            # a little shade under the eyes
            ue = e + np.array([0, -0.004, -0.016])
            d2 = np.linalg.norm((P - ue) * np.array([0.8, 1, 1.6]), axis=1)
            col *= (1 - 0.06 * np.exp(-(d2 / 0.012) ** 2))[:, None]
        # nose tip
        hv = np.where((np.abs(self.vb[:, 0]) < 0.004) & (self.vb[:, 2] < mid[2]) & (self.vb[:, 2] > mid[2] - 0.06))[0]
        hv = [i for i in hv if self.W[i, self.bidx["head"]] > 0.5]
        if hv:
            nose = self.vb[hv[np.argmin(self.vb[hv, 1])]]
            d = np.linalg.norm(P - nose, axis=1)
            redness += 0.18 * np.exp(-(d / 0.016) ** 2)
        # ears
        hb = np.where(self.W[:, self.bidx["head"]] > 0.8)[0]
        hb = np.intersect1d(hb, base.groups["body"])
        for sgn in (1, -1):
            ear_pt = self.vb[hb[np.argmax(self.vb[hb, 0] * sgn)]]
            d = np.linalg.norm(P - ear_pt, axis=1)
            redness += 0.16 * np.exp(-(d / 0.028) ** 2)
        # knuckles / finger tips / elbows / knees
        for b, rad, amt in (("index_02_l", 0.03, 0.10), ("index_02_r", 0.03, 0.10), ("calf_l", 0.05, 0.08), ("calf_r", 0.05, 0.08),
                            ("lowerarm_l", 0.04, 0.06), ("lowerarm_r", 0.04, 0.06)):
            d = np.linalg.norm(P - self.jh(b), axis=1)
            redness += amt * np.exp(-(d / rad) ** 2)
        col = col * (1 - redness[:, None]) + red * redness[:, None] * (tone.mean() / 0.62)

        lips = m("lips")
        lip_col = np.array(sp.get("lips", tone * np.array([0.92, 0.66, 0.66])))
        ls_ = sp.get("lip_strength", 0.85 - 0.3 * sp.get("gender", 0.0))
        col = col * (1 - lips[:, None] * ls_) + lip_col * lips[:, None] * ls_
        lids = m("eyelids")
        col *= (1 - 0.07 * lids)[:, None]
        mouth = m("inside-mouth")
        col = col * (1 - mouth[:, None]) + np.array([0.45, 0.16, 0.16]) * mouth[:, None]
        nails = m("fingernails")
        col = col * (1 - 0.6 * nails[:, None]) + np.minimum(tone * np.array([1.08, 0.98, 0.98]) + 0.08, 1) * 0.6 * nails[:, None]
        toen = m("toenails")
        col = col * (1 - 0.5 * toen[:, None]) + (tone + 0.08) * 0.5 * toen[:, None]

        # eyebrows
        brow = np.array(sp.get("brows", [0.10, 0.07, 0.05]))
        bthick = sp.get("brow_thickness", 1.0)
        dens_all = np.zeros(len(P))
        for e in (el, er):
            s = np.sign(e[0])
            u = (P[:, 0] - e[0]) * s
            v = P[:, 2] - e[2]
            front = P[:, 1] < e[1] + 0.006
            k = (u - 0.003) / 0.021
            vc = 0.0155 + 0.005 * (1 - k * k)
            th = (0.0024 + 0.0024 * T.smoothstep(0.026, -0.012, u)) * bthick
            band = T.smoothstep(th, th * 0.45, np.abs(v - vc + 0.0008 * (u < 0)))
            ends = T.smoothstep(-0.016, -0.011, u) * T.smoothstep(0.029, 0.021, u)
            q = np.stack([u * 30, (v - 0.35 * u * np.sign(u)) * 700, P[:, 1] * 30], axis=1)
            strands = 0.45 + 0.55 * T.noise3(q, 1.0, 11)
            dens_all = np.maximum(dens_all, band * ends * strands * front)
        dens_all = np.clip(dens_all * 1.15, 0, 0.92)
        col = col * (1 - dens_all[:, None]) + brow * dens_all[:, None]

        # stubble
        st = sp.get("stubble", 0.0)
        if st > 0:
            jaw = head + np.array([0, -0.05, -0.06])
            dj = (P - jaw) * np.array([1.0, 1.0, 1.6])
            region = T.smoothstep(0.085, 0.06, np.linalg.norm(dj, axis=1)) * T.smoothstep(head[1] + 0.02, head[1] - 0.01, P[:, 1])
            region = region * T.smoothstep(mid[2] - 0.025, mid[2] - 0.045, P[:, 2]) * (1 - np.clip(lips * 3, 0, 1))
            sn = T.noise3(P, 900, 13)
            col = col * (1 - (st * 0.35 * region * sn)[:, None]) + np.array([0.18, 0.16, 0.15]) * (st * 0.35 * region * sn)[:, None]

        # scalp under the hair
        hair = sp.get("hair", {})
        if hair and hair.get("style", "none") not in ("none", "bald"):
            hm = self.hair_mask(P)
            hc = np.array(hair.get("color", [0.08, 0.06, 0.05]))
            col = col * (1 - hm[:, None] * 0.9) + hc * 0.9 * hm[:, None]
        rgb = T.to_srgb8(col).reshape(size, size, 3)
        return Image.fromarray(rgb, "RGB")

    # ------------------------------------------------------------ hair
    def head_frame(self):
        el, er = self.eye_c["l"], self.eye_c["r"]
        mid = (el + er) / 2
        head = self.jh("head")
        top = self.joints["head"][1]
        return mid, head, top

    def hairline(self, P):
        """>0 where a point is above the hairline (on the scalp)."""
        mid, head, top = self.head_frame()
        c = np.array([mid[0], mid[1] + 0.07, mid[2] + 0.005])
        rel = P - c
        # angle around the head from the front (0) to the back (pi)
        ang = np.arctan2(np.abs(rel[:, 0]), -rel[:, 1])
        front_line = mid[2] + 0.052 * self.spec.get("hair", {}).get("hairline", 1.0)
        side_line = mid[2] + 0.02
        back_line = mid[2] - 0.075
        # blend lines by angle: front (0) -> temple (~1.1) -> above ear (1.6) -> back (pi)
        a = ang
        line = np.where(a < 1.0, front_line + (front_line - 0.012 - front_line) * (a / 1.0),
               np.where(a < 1.75, (front_line - 0.012) + (side_line - (front_line - 0.012)) * ((a - 1.0) / 0.75),
                        side_line + (back_line - side_line) * T.smoothstep(1.75, 2.6, a)))
        # free the ears
        ear = (np.abs(rel[:, 0]) > 0.05) & (a > 1.3) & (a < 2.3)
        line = np.where(ear, np.maximum(line, mid[2] + 0.018), line)
        return P[:, 2] - line

    def hair_mask(self, P):
        h = self.hairline(P)
        headw = self.W[:, self.bidx["head"]]
        return T.smoothstep(-0.004, 0.006, h) * (P[:, 2] > self.jh("neck_01")[2] + 0.02)


# ---------------------------------------------------------------- Blender assembly

def new_material(name, color=None, image=None, rough=0.6, metal=0.0, alpha_clip=False, spec=0.5):
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    if color is not None:
        lin = [c ** 2.2 for c in color]          # colours are given in sRGB
        bsdf.inputs["Base Color"].default_value = lin + [1.0]
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if image is not None:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        if color is not None:
            # neutral texture x colour (exported as glTF baseColorFactor, so it can be re-tinted)
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0
            mix.inputs[7].default_value = [c ** 2.2 for c in color] + [1.0]
            nt.links.new(tex.outputs["Color"], mix.inputs[6])
            nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        else:
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha_clip:
            nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    mat.use_backface_culling = not alpha_clip
    if alpha_clip:
        try:
            mat.surface_render_method = "DITHERED"
        except Exception:
            pass
        try:
            mat.blend_method = "CLIP"
        except Exception:
            pass
    return mat


def make_object(name, verts, faces, uvs=None, mats=None, face_mat=None, recalc=False):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    me.update()
    if uvs is not None:
        layer = me.uv_layers.new(name="UVMap")
        flat = np.array([c for f in uvs for c in f], np.float32).reshape(-1)
        layer.data.foreach_set("uv", flat)
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    if mats:
        for m in mats:
            me.materials.append(m)
        if face_mat is not None:
            me.polygons.foreach_set("material_index", list(face_mat))
    if recalc:
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def skin_object(ob, arm, base_ids, W, bones, extra=None):
    """base_ids: for each vertex of ob, the base-mesh vertex whose weights it copies."""
    groups = {b: ob.vertex_groups.new(name=b) for b in bones}
    for i, bi in enumerate(base_ids):
        w = W[bi]
        top = np.argsort(-w)[:4]
        tw = w[top]
        if tw.sum() <= 0:
            continue
        tw = tw / tw.sum()
        for b, x in zip(top, tw):
            if x > 0.001:
                groups[bones[b]].add([i], float(x), "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


def build(spec, out_glb, preview=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    P = Person(spec)
    base = P.base
    V = P.vb.copy()
    outfit = spec.get("outfit", {})
    fields = P.fields()

    # --- clothes geometry: the body surface each garment covers, cut smoothly
    # along its edges and pushed out a little
    garments = {}
    offs = {"top": 0.009, "bottom": 0.0055, "shoes": 0.0075}
    nv = len(V)
    for g in ("bottom", "top"):
        if g not in fields:
            continue
        info = outfit.get(g, {})
        off = np.full(nv, offs[g] * info.get("loose", 1.0))
        if g == "bottom":
            cw = np.maximum(P.wsum(["calf_l"]), P.wsum(["calf_r"]))
            lt = np.where(P.wsum(["calf_l"]) > P.wsum(["calf_r"]), P.legt["l"], P.legt["r"])
            off = off + 0.010 * info.get("flare", 1.0) * np.clip(cw, 0, 1) * np.clip((lt - 1.0) / 0.8, 0, 1)
        if g == "top":
            armw = np.maximum(P.wsum(["lowerarm_l"]), P.wsum(["lowerarm_r"]))
            off = off + 0.005 * np.clip(armw, 0, 1)
            if info.get("style") in ("raincoat", "hoodie", "sweater"):
                off = off + 0.007
        vspec, gfaces, guvs = clip_mesh(P.body_faces, [[tuple(base.uvs[t]) for t in fu] for fu in P.body_fuv], fields[g])
        if not gfaces:
            continue
        ia = np.array([v[1] for v in vspec])
        ib = np.array([v[2] if v[0] == "e" else v[1] for v in vspec])
        tt = np.array([v[3] if v[0] == "e" else 0.0 for v in vspec])[:, None]
        pos = V[ia] * (1 - tt) + V[ib] * tt
        raw = pos.copy()
        pos = relax(pos, gfaces, info.get("smooth", 14 if g == "top" else 8))
        # smoothing pulls cloth inward over shoulders and hips: never below the skin
        nr = P.normals[ia] * (1 - tt) + P.normals[ib] * tt
        nr /= np.linalg.norm(nr, axis=1)[:, None]
        under = np.einsum("ij,ij->i", pos - raw, nr)
        pos = pos + nr * np.maximum(0.0, -under)[:, None]
        nor = P.normals[ia] * (1 - tt) + P.normals[ib] * tt
        nor /= np.linalg.norm(nor, axis=1)[:, None]
        o = off[ia] * (1 - tt[:, 0]) + off[ib] * tt[:, 0]
        Wg = P.W[ia] * (1 - tt) + P.W[ib] * tt
        garments[g] = {"pos": pos, "nor": nor, "off": o, "W": Wg, "faces": gfaces, "uvs": guvs}
    ground = V[base.groups["body"], 2].min()
    shoe_parts = []
    if "shoes" in outfit:
        import shoes as SH
        for sd in "lr":
            sv, sf, sw, sole, gz = SH.build_shoe(P, sd, outfit["shoes"].get("style", "shoes"), P.shoe_top)
            shoe_parts.append((sd, sv, sf, sw, sole))
            ground = min(ground, gz)
    for sp_ in shoe_parts:
        sp_[1][:, 2] -= ground
    V[:, 2] -= ground
    for gd in garments.values():
        gd["pos"][:, 2] -= ground
    for b in P.joints:
        P.joints[b] = [P.joints[b][0] - np.array([0, 0, ground]), P.joints[b][1] - np.array([0, 0, ground])]
    P.vb = V
    for k in P.eye_c:
        P.eye_c[k] = P.eye_c[k] - np.array([0, 0, ground])

    # --- armature
    arm_data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    order = []
    seen = set()

    def visit(b):
        if b in seen:
            return
        p = P.rig[b]["parent"]
        if p:
            visit(p)
        seen.add(b)
        order.append(b)
    for b in P.rig:
        visit(b)
    for b in order:
        info = P.rig[b]
        eb = arm_data.edit_bones.new(b)
        h, t = P.joints[b]
        if np.linalg.norm(t - h) < 1e-4:
            t = h + np.array([0, 0, 0.01])
        eb.head = tuple(h)
        eb.tail = tuple(t)
        eb.roll = info.get("roll", 0.0)
        if info["parent"]:
            eb.parent = arm_data.edit_bones[info["parent"]]
        eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")

    # --- textures
    tex_dir = os.path.join(os.path.dirname(out_glb), "_tex_" + spec.get("name", "person"))
    os.makedirs(tex_dir, exist_ok=True)
    skin_img = P.paint_skin(spec.get("tex_size", 2048))
    skin_path = os.path.join(tex_dir, "skin.jpg")
    skin_img.save(skin_path, quality=92)
    skin_bimg = bpy.data.images.load(skin_path)
    skin_bimg.name = spec.get("name", "person") + "_skin"

    # --- body (skin faces not hidden under clothes) + mouth/eyelash helpers
    cover = np.max(np.stack([fields[g] for g in garments]), axis=0) if garments else np.full(nv, -1.0)
    covered = cover > 0.012
    body_keep = [i for i, f in enumerate(P.body_faces) if not covered[f].all()]
    mats = [new_material("Skin", image=skin_bimg, rough=0.52),
            new_material("Teeth", color=(0.86, 0.83, 0.76), rough=0.25),
            new_material("Tongue", color=(0.62, 0.26, 0.26), rough=0.4),
            new_material("Eyelashes", color=tuple(np.array(spec.get("brows", [0.08, 0.06, 0.05])) * 0.6), rough=0.8)]
    faces, fuv_list, fmat = [], [], []
    for i in body_keep:
        faces.append(P.body_faces[i])
        fuv_list.append([tuple(base.uvs[t]) for t in P.body_fuv[i]])
        fmat.append(0)
    for grp, mi in (("helper-upper-teeth", 1), ("helper-lower-teeth", 1), ("helper-tongue", 2),
                    ):
        for fi in base.faces_of(grp):
            faces.append(base.faces[fi])
            fuv_list.append([(0.0, 0.0)] * len(base.faces[fi]))
            fmat.append(mi)
    used = sorted({v for f in faces for v in f})
    remap = {v: i for i, v in enumerate(used)}
    body = make_object("Body", V[used], [[remap[v] for v in f] for f in faces], fuv_list, mats, fmat)
    skin_object(body, arm, used, P.W, P.bones)
    # face shapes
    body.shape_key_add(name="Basis")
    used_arr = np.array(used)

    def add_shape(name, units):
        d = np.zeros((len(used), 3))
        for unit, w in units:
            dd = M.expression_delta(spec, unit)
            for vi, delta in dd.items():
                if vi in remap:
                    d[remap[vi]] += w * np.array([delta[0] * 0.1, -delta[2] * 0.1, delta[1] * 0.1])
        if not d.any():
            return
        sk = body.shape_key_add(name=name, from_mix=False)
        co = V[used] + d
        sk.data.foreach_set("co", co.reshape(-1).astype(np.float32))
        sk.value = 0.0
    add_shape("blink", [("eye-left-closure", 1.0), ("eye-right-closure", 1.0)])
    add_shape("jawOpen", [("mouth-open", 0.8)])
    add_shape("smile", [("mouth-corner-puller", 0.8), ("mouth-elevation", 0.25), ("eye-left-slit", 0.25), ("eye-right-slit", 0.25)])
    add_shape("frown", [("mouth-depression", 0.7), ("eyebrows-left-inner-up", 0.6), ("eyebrows-right-inner-up", 0.6)])
    add_shape("angry", [("eyebrows-left-down", 0.8), ("eyebrows-right-down", 0.8), ("mouth-compression", 0.4)])
    add_shape("surprise", [("eyebrows-left-up", 0.8), ("eyebrows-right-up", 0.8), ("eye-left-opened-up", 0.6), ("eye-right-opened-up", 0.6), ("mouth-open", 0.35)])

    # --- clothes
    cloth_img = paint_clothes(garments, outfit, spec.get("tex_size", 2048) // 2)
    cloth_path = os.path.join(tex_dir, "clothes.jpg")
    cloth_img.save(cloth_path, quality=90)
    cloth_bimg = bpy.data.images.load(cloth_path)
    cloth_bimg.name = spec.get("name", "person") + "_clothes"
    names = {"top": "Shirt", "bottom": "Trousers", "shoes": "Shoes"}
    for g, gd in garments.items():
        info = outfit.get(g, {})
        Vg = gd["pos"] + gd["nor"] * gd["off"][:, None]
        gc = np.minimum(np.array(info.get("color", [0.5, 0.5, 0.5])) * 1.12, 1.0)
        mat = new_material(names[g], color=tuple(gc), image=cloth_bimg, rough=info.get("rough", {"shoes": 0.45}.get(g, 0.85)))
        ob = make_object(names[g], Vg, gd["faces"], gd["uvs"], [mat])
        skin_object(ob, arm, range(len(Vg)), gd["W"], P.bones)
        sol = ob.modifiers.new("Solidify", "SOLIDIFY")
        sol.thickness = 0.0035
        sol.offset = -1.0
        sol.use_rim = True
        ob.modifiers.move(ob.modifiers.find("Solidify"), 0)
        bpy.context.view_layer.objects.active = ob
        with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob]):
            bpy.ops.object.modifier_apply(modifier="Solidify")

    for sd, sv, sf, sw, sole in shoe_parts:
        info = outfit["shoes"]
        um = new_material("Shoe", color=tuple(info.get("color", [0.3, 0.2, 0.15])), rough=info.get("rough", 0.5))
        sm = new_material("Sole", color=tuple(info.get("sole", [0.12, 0.11, 0.1])), rough=0.8)
        ob = make_object("Shoe_" + sd, sv, sf, None, [um, sm], [1 if i in sole else 0 for i in range(len(sf))], recalc=True)
        skin_object(ob, arm, range(len(sv)), sw, P.bones)

    # --- eyes
    refs, scales = M.load_mhclo(M.MH + "/eyes/high-poly/high-poly.mhclo")
    ev = M.to_blender(M.fit_proxy(refs, scales, P.vobj))
    ev[:, 2] -= ground
    _, euv, efaces, efuv = M.load_simple_obj(M.MH + "/eyes/high-poly/high-poly.obj")
    # drop the clear cornea shell (it maps to the white dot in the corner of the texture)
    keep = [k for k, fu in enumerate(efuv) if not all(euv[t][0] > 0.8 and euv[t][1] < 0.2 for t in fu)]
    efaces = [efaces[k] for k in keep]
    efuv = [efuv[k] for k in keep]
    eye_img = eye_texture(spec, tex_dir)
    emat = new_material("Eyes", image=eye_img, rough=0.08)
    eyes = make_object("Eyes", ev, efaces, [[tuple(euv[t]) for t in f] for f in efuv], [emat])
    head_i = P.bidx["head"]
    Wh = np.zeros((1, len(P.bones)), np.float32)
    Wh[0, head_i] = 1
    skin_object(eyes, arm, [0] * len(ev), Wh, P.bones)

    # --- hair
    if spec.get("hair", {}).get("style", "none") not in ("none", "bald"):
        build_hair(P, arm, tex_dir)

    # --- animations
    rest = rest_data(arm)
    acts = []
    for clip in spec.get("clips", ["Idle", "Walk"]):
        data = CL.make(clip, P, rest, FPS)
        if data is None:
            continue
        acts.append(key_action(arm, clip, data, rest))
    if acts:
        arm.animation_data.action = acts[0]

    export(out_glb)
    bpy.ops.wm.save_as_mainfile(filepath=out_glb[:-4] + ".blend")
    if preview:
        render_preview(arm, preview, spec)
    return P


def rest_data(arm):
    out = {}
    for b in arm.data.bones:
        m = np.array(b.matrix_local)
        out[b.name] = {"R": m[:3, :3].copy(), "head": m[:3, 3].copy(), "parent": b.parent.name if b.parent else "",
                       "tail": np.array(b.tail_local)}
    return out


def key_action(arm, name, data, rest):
    if arm.animation_data is None:
        arm.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    nfr = data["frames"]
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for f in range(nfr):
        for bname, q in data["rot"].items():
            pb = arm.pose.bones[bname]
            if q.ndim == 1:
                if f not in (0, nfr - 1):
                    continue
                pb.rotation_quaternion = tuple(q)
            else:
                pb.rotation_quaternion = tuple(q[f])
            pb.keyframe_insert("rotation_quaternion", frame=f + 1)
        if "loc" in data:
            pb = arm.pose.bones["pelvis"]
            pb.location = tuple(data["loc"][f])
            pb.keyframe_insert("location", frame=f + 1)
    return act


def export(path):
    for ob in bpy.context.scene.objects:
        ob.select_set(True)
    kw = dict(filepath=path, export_format="GLB", export_animation_mode="ACTIONS", export_morph=True,
              export_skins=True, export_yup=True, export_image_format="AUTO", export_apply=False)
    try:
        bpy.ops.export_scene.gltf(**kw, export_morph_normal=False, export_force_sampling=True)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)


# ---------------------------------------------------------------- clothes painting

FABRIC_DEFAULT = {"top": "cotton", "bottom": "denim", "shoes": "leather"}


def relax(pos, faces, iters):
    """Laplacian smoothing that keeps the open rim in place (smooths toes into a shoe)."""
    n = len(pos)
    edges = {}
    for f in faces:
        for k in range(len(f)):
            a, b = f[k], f[(k + 1) % len(f)]
            key = (min(a, b), max(a, b))
            edges[key] = edges.get(key, 0) + 1
    rim = np.zeros(n, bool)
    for (a, b), c in edges.items():
        if c == 1:
            rim[a] = rim[b] = True
    E = np.array(list(edges.keys()))
    p = pos.copy()
    for _ in range(iters):
        acc = np.zeros_like(p)
        cnt = np.zeros(n)
        np.add.at(acc, E[:, 0], p[E[:, 1]])
        np.add.at(acc, E[:, 1], p[E[:, 0]])
        np.add.at(cnt, E[:, 0], 1)
        np.add.at(cnt, E[:, 1], 1)
        newp = acc / np.maximum(cnt, 1)[:, None]
        p = np.where(rim[:, None], p, p * 0.4 + newp * 0.6)
    # keep the sole flat on the ground
    low = pos[:, 2].min()
    p[:, 2] = np.maximum(p[:, 2], low)
    return p


def clip_mesh(faces, fuvs, s):
    """Keeps the part of each face where s >= 0, cutting faces that cross s = 0.
    Returns vertex specs ('v', i) / ('e', i, j, t), faces and per-corner uvs."""
    vspec, vmap, ecache = [], {}, {}
    out_f, out_uv = [], []

    def vert(i):
        if i not in vmap:
            vmap[i] = len(vspec)
            vspec.append(("v", i))
        return vmap[i]

    def cut(i, j):
        key = (min(i, j), max(i, j))
        if key not in ecache:
            a, b = key
            t = s[a] / (s[a] - s[b])
            ecache[key] = len(vspec)
            vspec.append(("e", a, b, float(t)))
        return ecache[key]

    for f, uv in zip(faces, fuvs):
        inside = [s[v] >= 0 for v in f]
        if not any(inside):
            continue
        if all(inside):
            out_f.append([vert(v) for v in f])
            out_uv.append(list(uv))
            continue
        poly, puv = [], []
        n = len(f)
        for k in range(n):
            a, b = f[k], f[(k + 1) % n]
            ua, ub = np.array(uv[k]), np.array(uv[(k + 1) % n])
            if inside[k]:
                poly.append(vert(a))
                puv.append(tuple(ua))
            if inside[k] != inside[(k + 1) % n]:
                t = s[a] / (s[a] - s[b])
                poly.append(cut(a, b))
                puv.append(tuple(ua * (1 - t) + ub * t))
        if len(poly) >= 3:
            out_f.append(poly)
            out_uv.append(puv)
    return vspec, out_f, out_uv


def paint_clothes(garments, outfit, size):
    tuv, attr = [], []
    gid = {"top": 1, "bottom": 2, "shoes": 3}
    for g in ("bottom", "shoes", "top"):
        if g not in garments:
            continue
        gd = garments[g]
        for f, uv in zip(gd["faces"], gd["uvs"]):
            for k in range(1, len(f) - 1):
                ids = (0, k, k + 1)
                tuv.append([uv[i] for i in ids])
                attr.append([list(gd["pos"][f[i]]) + [gid[g]] + list(gd["nor"][f[i]]) for i in ids])
    img, mask = T.rasterize(np.array(tuv), np.array(attr, np.float64), size)
    img = T.dilate(img, mask)
    Pp = img[..., :3].reshape(-1, 3).astype(np.float64)
    G = np.round(img[..., 3].reshape(-1)).astype(int)
    col = np.zeros((len(Pp), 3))
    for g, i in gid.items():
        sel = G == i
        if not sel.any():
            continue
        info = outfit.get(g, {})
        c = np.array(info.get("color", [0.5, 0.5, 0.5]))
        fab = info.get("fabric", FABRIC_DEFAULT[g])
        p = Pp[sel]
        base_n = T.fbm(p, 12.0, 3, 3 + i)
        if fab == "denim":
            tw = np.sin((p[:, 0] * 0.7 + p[:, 2]) * 2200.0) * 0.5 + 0.5
            fine = T.noise3(p, 600.0, 21)
            fade = T.fbm(p, 6.0, 2, 8)
            cc = c * (0.88 + 0.10 * tw[:, None] + 0.06 * fine[:, None]) + (0.10 * T.smoothstep(0.55, 0.8, fade))[:, None]
        elif fab == "knit":
            rib = np.sin(np.arctan2(p[:, 0], p[:, 1]) * 260.0) * 0.5 + 0.5
            cc = c * (0.86 + 0.14 * rib[:, None]) * (0.95 + 0.08 * base_n[:, None])
        elif fab == "rain":
            cc = c * (0.96 + 0.06 * base_n[:, None])
        elif fab == "leather":
            cc = c * (0.85 + 0.2 * T.noise3(p, 300.0, 5)[:, None]) * (0.95 + 0.08 * base_n[:, None])
            sole = p[:, 2] < 0.022
            cc[sole] = np.array(info.get("sole", [0.12, 0.11, 0.10]))
        else:
            fine = T.noise3(p, 500.0, 31)
            cc = c * (0.92 + 0.10 * base_n[:, None] + 0.04 * fine[:, None])
        if g == "shoes" and fab != "leather":
            sole = p[:, 2] < 0.02
            cc[sole] = np.array(info.get("sole", [0.92, 0.92, 0.9]))
        # stored neutral (pattern only): the material colour gives the garment its colour
        col[sel] = np.clip(cc / np.maximum(c, 0.03) / 1.12, 0, 1)
    rgb = T.to_srgb8(col).reshape(size, size, 3)
    return Image.fromarray(rgb, "RGB")


def eye_texture(spec, tex_dir):
    im = Image.open(M.MH + "/eyes/materials/brown_eye.png").convert("RGBA")
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb = a[..., :3]
    iris = np.array(spec.get("iris", [0.30, 0.17, 0.08]))
    # recolour the saturated (iris) parts
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    lum = rgb.mean(axis=2, keepdims=True)
    w = T.smoothstep(0.12, 0.3, sat)[..., None]
    rgb = rgb * (1 - w) + (lum / 0.2) * iris * w
    out = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")
    path = os.path.join(tex_dir, "eyes.jpg")
    out.save(path, quality=92)
    img = bpy.data.images.load(path)
    img.name = spec.get("name", "person") + "_eyes"
    return img


# ---------------------------------------------------------------- hair

def build_hair(P, arm, tex_dir):
    import hair as H
    H.build(P, arm, tex_dir, make_object, new_material, skin_object)


def render_preview(arm, path, spec):
    import preview as PV
    PV.render(arm, path, spec)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    spec = json.load(open(argv[0]))
    build(spec, os.path.abspath(argv[1]), argv[2] if len(argv) > 2 else None)

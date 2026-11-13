"""MakeHuman data reading and body morphing (my own code; reads the CC0 data files only).

Coordinates returned are Blender-style: metres, Z up, the body faces -Y.
"""
import gzip, json, os, random
import numpy as np

SCR = "/tmp/claude-0/-home-claude/d7e10532-dcfa-5c3c-817d-92a6a10cb8ae/scratchpad"
MPFB = SCR + "/mpfb2/src/mpfb/data"
MH = SCR + "/mhrepo/makehuman/data"


def to_blender(v):
    v = np.asarray(v, dtype=np.float64)
    return np.stack([v[..., 0] * 0.1, -v[..., 2] * 0.1, v[..., 1] * 0.1], axis=-1)


class BaseMesh:
    def __init__(self):
        verts, uvs, faces, fuv, fgroup = [], [], [], [], []
        groups = {}
        group = ""
        with open(MPFB + "/3dobjs/base.obj") as f:
            for line in f:
                if line.startswith("v "):
                    verts.append([float(x) for x in line.split()[1:4]])
                elif line.startswith("vt "):
                    uvs.append([float(x) for x in line.split()[1:3]])
                elif line.startswith("g "):
                    group = line.split()[1].strip()
                elif line.startswith("f "):
                    vi, ti = [], []
                    for tok in line.split()[1:]:
                        parts = tok.split("/")
                        vi.append(int(parts[0]) - 1)
                        ti.append(int(parts[1]) - 1 if len(parts) > 1 and parts[1] else -1)
                    faces.append(vi)
                    fuv.append(ti)
                    fgroup.append(group)
                    groups.setdefault(group, set()).update(vi)
        self.verts = np.array(verts)          # obj coordinates (decimetres, Y up)
        self.uvs = np.array(uvs)
        self.faces = faces
        self.fuv = fuv
        self.fgroup = fgroup
        self.groups = {k: np.array(sorted(v)) for k, v in groups.items()}

    def faces_of(self, prefix):
        return [i for i, g in enumerate(self.fgroup) if g == prefix or (prefix.endswith("*") and g.startswith(prefix[:-1]))]


_target_cache = {}


def load_target(path):
    if path in _target_cache:
        return _target_cache[path]
    idx, d = [], []
    if os.path.exists(path):
        with gzip.open(path, "rt") as f:
            for line in f:
                if not line.strip() or line.startswith("#"):
                    continue
                p = line.split()
                idx.append(int(p[0]))
                d.append([float(p[1]), float(p[2]), float(p[3])])
    res = (np.array(idx, dtype=np.int64), np.array(d).reshape(-1, 3))
    _target_cache[path] = res
    return res


def _three(v):
    """min / average / max weights for a 0..1 slider (0.5 = average)."""
    lo = max(0.0, 1.0 - v * 2.0)
    hi = max(0.0, v * 2.0 - 1.0)
    return {"min": lo, "average": 1.0 - lo - hi, "max": hi}


def age_weights(a):
    if a < 0.5:
        baby = max(0.0, 1.0 - a * 5.333)
        young = max(0.0, (a - 0.1875) * 3.2)
        child = max(0.0, min(1.0, 5.333 * a) - young)
        return {"baby": baby, "child": child, "young": young, "old": 0.0}
    old = max(0.0, a * 2.0 - 1.0)
    return {"baby": 0.0, "child": 0.0, "young": 1.0 - old, "old": old}


def age_value(years):
    """MakeHuman age slider for an age in years (1 .. 90)."""
    if years < 11:
        return max(0.0, (years - 1) / 10.0 * 0.1875)
    if years < 25:
        return 0.1875 + (years - 11) / 14.0 * 0.3125
    return min(1.0, 0.5 + (years - 25) / 65.0 * 0.5)


def macro_list(spec):
    g = spec.get("gender", 0.0)       # 0 female .. 1 male
    a = age_value(spec.get("age", 25))
    mus = _three(spec.get("muscle", 0.5))
    wei = _three(spec.get("weight", 0.5))
    h = spec.get("height", 0.5)
    pr = spec.get("proportions", 0.5)
    race = spec.get("race", {"african": 0.0, "asian": 0.5, "caucasian": 0.5})
    gw = {"female": 1.0 - g, "male": g}
    aw = age_weights(a)
    md = MPFB + "/targets/macrodetails/"
    out = []
    for gk, gv in gw.items():
        for ak, av in aw.items():
            if gv * av <= 0:
                continue
            for rk, rv in race.items():
                if rv > 0:
                    out.append((md + "%s-%s-%s.target.gz" % (rk, gk, ak), rv * gv * av))
            for mk, mv in mus.items():
                for wk, wv in wei.items():
                    w = gv * av * mv * wv
                    if w <= 0:
                        continue
                    name = "%s-%s-%smuscle-%sweight" % (gk, ak, mk, wk)
                    out.append((md + "universal-" + name + ".target.gz", w))
                    if h != 0.5:
                        hk = "maxheight" if h > 0.5 else "minheight"
                        out.append((md + "height/" + name + "-" + hk + ".target.gz", w * abs(h - 0.5) * 2))
                    if pr != 0.5:
                        pk = "idealproportions" if pr > 0.5 else "uncommonproportions"
                        out.append((md + "proportions/" + name + "-" + pk + ".target.gz", w * abs(pr - 0.5) * 2))
    return out


FACE_GROUPS = ["nose", "chin", "mouth", "eyes", "cheek", "forehead", "head", "ears", "eyebrows", "neck"]


def face_variety(seed, amount=0.35, count=14):
    """A random set of small face changes so every person looks different."""
    rnd = random.Random(seed)
    pool = []
    for grp in FACE_GROUPS:
        d = MPFB + "/targets/" + grp
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if fn.endswith(".target.gz") and ("incr" in fn or "decr" in fn or "in." in fn or "out." in fn or "up." in fn or "down." in fn):
                pool.append(d + "/" + fn)
    # one change per left/right pair, applied to both sides alike
    keyed = {}
    for p in pool:
        fn = os.path.basename(p)
        key = fn[2:] if fn[:2] in ("l-", "r-") else fn
        keyed.setdefault(os.path.dirname(p) + "/" + key, []).append(p)
    keys = sorted(keyed)
    picks = rnd.sample(keys, min(count, len(keys)))
    out = []
    for k in picks:
        w = rnd.uniform(0.15, 1.0) * amount
        for p in keyed[k]:
            out.append((p, w))
    return out


def morph(base, spec):
    v = base.verts.copy()
    targets = macro_list(spec) + [(MPFB + "/targets/" + k, w) for k, w in spec.get("targets", {}).items()]
    if spec.get("seed") is not None:
        targets += face_variety(spec["seed"], spec.get("variety", 0.35))
    for path, w in targets:
        idx, d = load_target(path)
        if len(idx):
            v[idx] += w * d
    return v


def expression_delta(spec, unit):
    """Offsets (obj units) for an expression unit, blended by the person's race mix."""
    race = spec.get("race", {"african": 0.0, "asian": 0.5, "caucasian": 0.5})
    out = {}
    for rk, rv in race.items():
        if rv <= 0:
            continue
        idx, d = load_target(MPFB + "/targets/expression/units/%s/%s.target.gz" % (rk, unit))
        for i, dd in zip(idx, d):
            out[i] = out.get(i, 0) + rv * dd
    return out


def load_rig(name="game_engine"):
    with open(MPFB + "/rigs/standard/rig.%s.json" % name) as f:
        rig = json.load(f)
    with open(MPFB + "/rigs/standard/weights.%s.json" % name) as f:
        weights = json.load(f)["weights"]
    return rig, weights


def joint_positions(base, verts_obj, rig):
    """Bone head/tail positions (Blender coordinates) from the morphed mesh."""
    vb = to_blender(verts_obj)
    out = {}
    for bone, info in rig.items():
        ends = []
        for key in ("head", "tail"):
            e = info[key]
            if e["strategy"] == "CUBE" and e.get("cube_name") in base.groups:
                p = vb[base.groups[e["cube_name"]]].mean(axis=0)
            elif e["strategy"] == "MEAN":
                p = vb[e["vertex_indices"]].mean(axis=0)
            elif e["strategy"] == "VERTEX":
                p = vb[e["vertex_index"]]
            else:
                p = np.array(e["default_position"])
            ends.append(p)
        out[bone] = ends
    return out


def load_mhclo(path):
    """MakeHuman proxy fitting: per proxy vertex (3 base verts, 3 weights, offset)."""
    refs, scales = [], {}
    in_verts = False
    with open(path) as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            p = s.split()
            if p[0] in ("x_scale", "y_scale", "z_scale"):
                scales[p[0][0]] = (int(p[1]), int(p[2]), float(p[3]))
            elif p[0] == "verts":
                in_verts = True
            elif in_verts and len(p) == 9:
                refs.append(([int(x) for x in p[:3]], [float(x) for x in p[3:6]], [float(x) for x in p[6:9]]))
            elif in_verts and len(p) == 1:
                refs.append(([int(p[0])] * 3, [1.0, 0, 0], [0.0, 0, 0]))
            elif in_verts and p[0] in ("delete_verts", "material", "obj_file"):
                in_verts = False
    return refs, scales


def fit_proxy(refs, scales, verts_obj):
    sc = []
    for axis, k in (("x", 0), ("y", 1), ("z", 2)):
        a, b, dist = scales[axis]
        sc.append(abs(verts_obj[a][k] - verts_obj[b][k]) / dist)
    sc = np.array(sc)
    out = np.zeros((len(refs), 3))
    for i, (vi, w, off) in enumerate(refs):
        out[i] = w[0] * verts_obj[vi[0]] + w[1] * verts_obj[vi[1]] + w[2] * verts_obj[vi[2]] + np.array(off) * sc
    return out


def load_simple_obj(path):
    verts, uvs, faces, fuv = [], [], [], []
    with open(path) as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:4]])
            elif line.startswith("vt "):
                uvs.append([float(x) for x in line.split()[1:3]])
            elif line.startswith("f "):
                vi, ti = [], []
                for tok in line.split()[1:]:
                    parts = tok.split("/")
                    vi.append(int(parts[0]) - 1)
                    ti.append(int(parts[1]) - 1 if len(parts) > 1 and parts[1] else 0)
                faces.append(vi)
                fuv.append(ti)
    return np.array(verts), np.array(uvs), faces, fuv

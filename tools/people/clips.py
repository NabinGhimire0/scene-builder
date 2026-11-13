"""The motion clips every person gets, retargeted from CMU motion capture."""
import math
import numpy as np
import bvhret as R
import mhcore as M

CMU = M.SCR + "/cmu/data/"

# mode: cycle = in-place step loop; loop = looping (ends matched); once = plays through
CATALOG = {
    "Idle": dict(file="18/18_08", mode="loop", t0=2.6, t1=10.0, min_len=4.0, max_len=7.2),
    "Walk": dict(file="7/07_01", mode="cycle"),
    "Run": dict(file="9/09_02", mode="cycle", min_len=0.45, max_len=0.9),
    "Sad Walk": dict(file="91/91_13", mode="cycle", t0=4.5, t1=11.0),
    "Talk": dict(file="19/19_08", mode="loop", t0=0.8, t1=9.6, min_len=4.0, max_len=8.5),
    "Wave": dict(file="111/111_37", mode="loop", t0=0.3, t1=2.5, min_len=1.0, max_len=2.1),
    "Cheer": dict(file="13/13_26", mode="loop", t0=0.4, t1=2.4, min_len=1.0, max_len=1.9),
    "Laugh": dict(file="79/79_70", mode="loop", t0=0.6, t1=6.3, min_len=3.0, max_len=5.6),
    "Happy": dict(file="80/80_43", mode="loop", t0=0.7, t1=7.3, min_len=3.0, max_len=6.4),
    "Sad": dict(file="79/79_71", mode="loop", t0=0.5, t1=8.6, min_len=3.0, max_len=7.9),
    "Cry": dict(file="79/79_72", mode="loop", t0=0.4, t1=7.4, min_len=3.0, max_len=6.9),
    "Phone": dict(file="79/79_36", mode="loop", t0=1.8, t1=3.2, min_len=0.6, max_len=1.3),
    "Pick Up": dict(file="111/111_17", mode="once", t0=0.8, t1=3.8),
    "Sit": dict(file="113/113_15", mode="loop", t0=2.6, t1=4.7, min_len=1.2, max_len=2.0),
    "Kneel": dict(file="23/23_03", mode="loop", t0=1.5, t1=4.0, min_len=1.0, max_len=2.4),
    "Dance": dict(file="15/15_12", mode="loop", t0=50.0, t1=62.0, min_len=3.0, max_len=8.0),
    "Jump": dict(file="13/13_39", mode="loop", t0=0.25, t1=2.85, min_len=2.0, max_len=2.55),
}

_bvh = {}
DAMP = {"neck_01": 0.6, "head": 0.6}


def load(name):
    if name not in _bvh:
        _bvh[name] = R.BVH(CMU + "%03d/%s.bvh" % (int(name.split("/")[0]), name.split("/")[1]))
    return _bvh[name]


def qmul(a, b):
    w1, x1, y1, z1 = a
    w2, x2, y2, z2 = b
    return np.array([w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2, w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
                     w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2, w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2])


def qinv(q):
    return np.array([q[0], -q[1], -q[2], -q[3]])


FINGER_CURL = {"thumb": (8, 10, 8), "index": (14, 18, 10), "middle": (18, 22, 12), "ring": (22, 26, 14), "pinky": (26, 30, 16)}


def finger_basis(rest, b):
    finger, k, s = b.split("_")
    ang = math.radians(FINGER_CURL[finger][int(k) - 1] * 0.6)
    Rt = rest[b]["R"]
    side = 1.0 if s == "l" else -1.0
    hand = rest["hand_" + s]
    across = rest["index_01_" + s]["head"] - rest["pinky_01_" + s]["head"]
    n = np.cross(across, hand["R"][:, 1])
    if np.dot(n, [-side, 0, -1]) < 0:
        n = -n
    best = None
    for axis in ([1, 0, 0], [0, 0, 1]):
        for sg in (1, -1):
            Rl = R.axis_angle(axis, sg * ang)
            moved = Rt @ (Rl @ np.array([0, 1.0, 0])) - Rt[:, 1]
            score = np.dot(moved, n)
            if best is None or score > best[0]:
                best = (score, Rl)
    return best[1]


def make(clip, P, rest, fps):
    spec = CATALOG.get(clip)
    if spec is None:
        return None
    bvh = load(spec["file"])
    G, Pp, times = bvh.solve(fps, spec.get("t0", 0.0), spec.get("t1"))
    hips = bvh.index["Hips"]
    mode = spec["mode"]
    if mode == "cycle":
        s, e, _ = R.find_cycle(G, Pp, bvh, fps)
        G, Pp = G[s:e + 1], Pp[s:e + 1]
    elif mode == "loop":
        s, e, _ = R.find_cycle(G, Pp, bvh, fps, spec.get("min_len", 3.0), spec.get("max_len", 8.0), start=spec.get("start"))
        G, Pp = G[s:e + 1], Pp[s:e + 1]
    F = len(G)
    # face -Y, start at the origin
    if mode == "cycle":
        tr = Pp[-1, hips] - Pp[0, hips]
        yaw = math.atan2(tr[0], -tr[1])
    else:
        n = min(F, int(fps * 0.5))
        fw = np.mean([G[f, hips] @ np.array([0, -1.0, 0]) for f in range(n)], axis=0)
        yaw = math.atan2(fw[0], -fw[1])
    Ry = R.yaw_matrix(-yaw)
    G = np.einsum("ij,fkjl->fkil", Ry, G)
    start = Pp[0, hips] * np.array([1, 1, 0])
    Pp = np.einsum("ij,fkj->fki", Ry, Pp - start)
    if mode in ("cycle", "loop"):
        drift = Pp[-1, hips, :2] - Pp[0, hips, :2]
        lin = np.linspace(0, 1, F)[:, None, None]
        Pp[:, :, :2] -= lin * drift[None, None, :]
    # scale and ground
    off = bvh.offset
    src_leg = np.linalg.norm(off[bvh.index["LeftLeg"]]) + np.linalg.norm(off[bvh.index["LeftFoot"]])
    tl = np.linalg.norm(rest["calf_l"]["head"] - rest["thigh_l"]["head"]) + np.linalg.norm(rest["foot_l"]["head"] - rest["calf_l"]["head"])
    k = tl / src_leg
    g_s = min(Pp[:, bvh.index["LeftFoot"], 2].min(), Pp[:, bvh.index["RightFoot"], 2].min())
    ankle = (rest["foot_l"]["head"][2] + rest["foot_r"]["head"][2]) / 2
    pel = rest["pelvis"]
    H = np.zeros((F, 3))
    H[:, 0] = Pp[:, hips, 0] * k + pel["head"][0]
    H[:, 1] = Pp[:, hips, 1] * k + pel["head"][1]
    H[:, 2] = ankle + (Pp[:, hips, 2] - g_s) * k
    loc = np.einsum("ij,fj->fi", pel["R"].T, H - pel["head"])

    # rotations
    order = []
    seen = set()

    def visit(b):
        if b in seen:
            return
        if rest[b]["parent"]:
            visit(rest[b]["parent"])
        seen.add(b)
        order.append(b)
    for b in rest:
        visit(b)
    # Arms hang a little away from the body: MakeHuman shoulders are narrower than
    # the capture actors', so copying directions alone puts the hands on the belly.
    ang = math.radians(P.spec.get("arm_out", 9.0))
    abd = {}
    for sd, sx in (("l", 1.0), ("r", -1.0)):
        mats = np.zeros((F, 3, 3))
        for f in range(F):
            Gh = G[f, hips]
            fwd = Gh @ np.array([0, -1.0, 0])
            fwd[2] = 0
            fwd /= max(np.linalg.norm(fwd), 1e-6)
            side = Gh @ np.array([sx, 0, 0])
            m = R.axis_angle(fwd, ang)
            if np.dot(m @ np.array([0, 0, -1.0]), side) < 0:
                m = R.axis_angle(fwd, -ang)
            mats[f] = m
        abd[sd] = mats
    W = {}
    rot = {}
    for b in order:
        Rt = rest[b]["R"]
        p = rest[b]["parent"]
        if b in R.MAP:
            src, dsrc = R.MAP[b]
            A = np.eye(3)
            if dsrc is not None:
                d = bvh.rest_dir(dsrc)
                if d is not None:
                    A = R.rot_between(Rt[:, 1], d)
            W[b] = np.einsum("fij,jk->fik", G[:, bvh.index[src]], A @ Rt)
            sd = b.split("_")[-1]
            if b.split("_")[0] in ("upperarm", "lowerarm", "hand") and sd in ("l", "r"):
                W[b] = np.einsum("fij,fjk->fik", abd[sd], W[b])
            if p:
                Rp = rest[p]["R"]
                basis = np.einsum("ij,fkj,fkl->fil", Rt.T @ Rp, W[p], W[b])
            else:
                basis = np.einsum("ij,fjk->fik", Rt.T, W[b])
            rot[b] = R.mat_to_quat(basis)
            if b in DAMP:
                ident = np.array([1.0, 0, 0, 0])
                rot[b] = np.array([R.slerp(ident, q, DAMP[b]) for q in rot[b]])
                # keep the children consistent with the softened pose
                Rp = rest[p]["R"]
                W[b] = np.einsum("fij,jk,fkl->fil", W[p], Rp.T @ Rt, np.array([R.quat_to_mat(q) for q in rot[b]]))
        else:
            if b.split("_")[0] in FINGER_CURL:
                Bl = finger_basis(rest, b)
            else:
                Bl = np.eye(3)
            if p and p in W:
                Rp = rest[p]["R"]
                W[b] = np.einsum("fij,jk->fik", W[p], Rp.T @ Rt @ Bl)
            else:
                W[b] = np.tile(Rt @ Bl, (F, 1, 1))
            rot[b] = R.mat_to_quat(Bl)
    if mode in ("cycle", "loop"):
        for b, q in rot.items():
            if q.ndim != 2:
                continue
            fix = qmul(qinv(q[-1]), q[0])
            if fix[0] < 0:
                fix = -fix
            ident = np.array([1.0, 0, 0, 0])
            for i in range(F):
                q[i] = qmul(q[i], R.slerp(ident, fix, i / (F - 1)))
        loc += np.linspace(0, 1, F)[:, None] * (loc[0] - loc[-1])[None, :]
    return {"frames": F, "rot": rot, "loc": loc}

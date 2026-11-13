"""BVH reading and retargeting onto the game_engine rig (my own code, numpy only)."""
import math
import numpy as np

C = np.array([[1.0, 0, 0], [0, 0, -1.0], [0, 1.0, 0]])   # BVH (Y up, +Z front) -> Blender (Z up, -Y front)


def _rot(axis, deg):
    a = np.radians(deg)
    c, s = np.cos(a), np.sin(a)
    n = len(a)
    m = np.zeros((n, 3, 3))
    if axis == "X":
        m[:, 0, 0] = 1; m[:, 1, 1] = c; m[:, 1, 2] = -s; m[:, 2, 1] = s; m[:, 2, 2] = c
    elif axis == "Y":
        m[:, 1, 1] = 1; m[:, 0, 0] = c; m[:, 0, 2] = s; m[:, 2, 0] = -s; m[:, 2, 2] = c
    else:
        m[:, 2, 2] = 1; m[:, 0, 0] = c; m[:, 0, 1] = -s; m[:, 1, 0] = s; m[:, 1, 1] = c
    return m


class BVH:
    def __init__(self, path):
        self.names, self.parent, self.offset, self.channels, self.end = [], [], [], [], {}
        toks = open(path).read().split()
        i = 0
        stack = []
        last = -1
        col = 0
        self.chan_col = []
        while toks[i] != "MOTION":
            t = toks[i]
            if t in ("ROOT", "JOINT"):
                self.names.append(toks[i + 1])
                self.parent.append(stack[-1] if stack else -1)
                last = len(self.names) - 1
                i += 2
            elif t == "End":
                # End Site { OFFSET x y z }
                self.end[stack[-1]] = [float(x) for x in toks[i + 4:i + 7]]
                i += 8
                continue
            elif t == "{":
                stack.append(last)
                i += 1
            elif t == "}":
                stack.pop()
                i += 1
            elif t == "OFFSET":
                self.offset.append([float(x) for x in toks[i + 1:i + 4]])
                i += 4
            elif t == "CHANNELS":
                n = int(toks[i + 1])
                self.channels.append(toks[i + 2:i + 2 + n])
                self.chan_col.append(col)
                col += n
                i += 2 + n
            else:
                i += 1
        i += 1
        nframes = int(toks[i + 1])
        self.dt = float(toks[i + 4])
        vals = np.array(toks[i + 5:i + 5 + nframes * col], dtype=np.float64)
        self.frames = vals.reshape(nframes, col)
        self.offset = np.array(self.offset)
        self.index = {n: k for k, n in enumerate(self.names)}

    def children(self, j):
        return [k for k, p in enumerate(self.parent) if p == j]

    def rest_dir(self, name):
        """Direction (Blender coords) from this joint to its child at the zero pose."""
        j = self.index[name]
        kids = self.children(j)
        if j in self.end:
            off = np.array(self.end[j])
        elif kids:
            good = [k for k in kids if np.linalg.norm(self.offset[k]) > 1e-6]
            pref = [k for k in good if "Neck" in self.names[k] or "Spine" in self.names[k] or "Head" in self.names[k]]
            if not good:
                return None
            off = self.offset[(pref or good)[0]]
        else:
            return None
        d = C @ off
        n = np.linalg.norm(d)
        return d / n if n > 1e-9 else None

    def solve(self, fps=30.0, t0=0.0, t1=None):
        """Global rotations (F, J, 3, 3) and joint positions (F, J, 3), Blender coords, resampled."""
        total = (len(self.frames) - 1) * self.dt
        t1 = total if t1 is None else min(t1, total)
        times = np.arange(t0, t1 + 1e-6, 1.0 / fps)
        src = np.clip(np.round(times / self.dt).astype(int), 0, len(self.frames) - 1)
        fr = self.frames[src]
        F, J = len(fr), len(self.names)
        G = np.zeros((F, J, 3, 3))
        P = np.zeros((F, J, 3))
        for j in range(J):
            ch = self.channels[j]
            c0 = self.chan_col[j]
            R = np.tile(np.eye(3), (F, 1, 1))
            pos = np.zeros((F, 3))
            for k, name in enumerate(ch):
                v = fr[:, c0 + k]
                if name.endswith("rotation"):
                    R = R @ _rot(name[0], v)
                else:
                    pos[:, "XYZ".index(name[0])] = v
            p = self.parent[j]
            if p < 0:
                G[:, j] = R
                P[:, j] = pos + self.offset[j]
            else:
                G[:, j] = G[:, p] @ R
                P[:, j] = P[:, p] + np.einsum("fij,j->fi", G[:, p], self.offset[j])
        Gb = np.einsum("ij,fkjl,ml->fkim", C, G, C)
        Pb = np.einsum("ij,fkj->fki", C, P)
        return Gb, Pb, times - t0


# target bone -> (source joint giving the rotation, source joint whose direction the bone lines up with)
MAP = {
    "pelvis": ("Hips", None),
    "spine_01": ("LowerBack", "LowerBack"),
    "spine_02": ("Spine", "Spine"),
    "spine_03": ("Spine1", "Spine1"),
    "neck_01": ("Neck1", "Neck1"),
    "head": ("Head", "Head"),
}
for S, s in (("Left", "l"), ("Right", "r")):
    MAP.update({
        "upperarm_" + s: (S + "Arm", S + "Arm"),
        "lowerarm_" + s: (S + "ForeArm", S + "ForeArm"),
        "thigh_" + s: (S + "UpLeg", S + "UpLeg"),
        "calf_" + s: (S + "Leg", S + "Leg"),
        "foot_" + s: (S + "Foot", S + "Foot"),
        "ball_" + s: (S + "ToeBase", S + "ToeBase"),
    })


def rot_between(a, b):
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if c < -0.999999:
        axis = np.cross(a, [1, 0, 0])
        if np.linalg.norm(axis) < 1e-6:
            axis = np.cross(a, [0, 1, 0])
        axis /= np.linalg.norm(axis)
        return axis_angle(axis, math.pi)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1.0 / (1.0 + c))


def axis_angle(axis, ang):
    axis = np.asarray(axis, float)
    axis = axis / np.linalg.norm(axis)
    x, y, z = axis
    c, s = math.cos(ang), math.sin(ang)
    t = 1 - c
    return np.array([[t * x * x + c, t * x * y - s * z, t * x * z + s * y],
                     [t * x * y + s * z, t * y * y + c, t * y * z - s * x],
                     [t * x * z - s * y, t * y * z + s * x, t * z * z + c]])


def yaw_matrix(ang):
    return axis_angle([0, 0, 1], ang)


def mat_to_quat(m):
    """(…,3,3) -> (…,4) w,x,y,z"""
    m = np.asarray(m)
    shp = m.shape[:-2]
    m = m.reshape(-1, 3, 3)
    q = np.zeros((len(m), 4))
    for i, r in enumerate(m):
        tr = r[0, 0] + r[1, 1] + r[2, 2]
        if tr > 0:
            s = math.sqrt(tr + 1.0) * 2
            q[i] = [0.25 * s, (r[2, 1] - r[1, 2]) / s, (r[0, 2] - r[2, 0]) / s, (r[1, 0] - r[0, 1]) / s]
        elif r[0, 0] > r[1, 1] and r[0, 0] > r[2, 2]:
            s = math.sqrt(1.0 + r[0, 0] - r[1, 1] - r[2, 2]) * 2
            q[i] = [(r[2, 1] - r[1, 2]) / s, 0.25 * s, (r[0, 1] + r[1, 0]) / s, (r[0, 2] + r[2, 0]) / s]
        elif r[1, 1] > r[2, 2]:
            s = math.sqrt(1.0 + r[1, 1] - r[0, 0] - r[2, 2]) * 2
            q[i] = [(r[0, 2] - r[2, 0]) / s, (r[0, 1] + r[1, 0]) / s, 0.25 * s, (r[1, 2] + r[2, 1]) / s]
        else:
            s = math.sqrt(1.0 + r[2, 2] - r[0, 0] - r[1, 1]) * 2
            q[i] = [(r[1, 0] - r[0, 1]) / s, (r[0, 2] + r[2, 0]) / s, (r[1, 2] + r[2, 1]) / s, 0.25 * s]
    # keep a continuous sign
    for i in range(1, len(q)):
        if np.dot(q[i], q[i - 1]) < 0:
            q[i] = -q[i]
    return q.reshape(shp + (4,))


def quat_to_mat(q):
    w, x, y, z = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def slerp(a, b, t):
    d = float(np.dot(a, b))
    if d < 0:
        b = -b
        d = -d
    if d > 0.9995:
        r = a + t * (b - a)
        return r / np.linalg.norm(r)
    th = math.acos(d)
    return (math.sin((1 - t) * th) * a + math.sin(t * th) * b) / math.sin(th)


def facing_yaw(G_hips):
    """Yaw (radians about Z) of where the hips face; 0 = facing -Y."""
    f = G_hips @ np.array([0, -1.0, 0])
    return math.atan2(f[0], -f[1])   # rotate by -yaw to face -Y


def pose_distance(Ga, Gb, joints):
    d = 0.0
    for j in joints:
        r = Ga[j].T @ Gb[j]
        d += math.acos(max(-1.0, min(1.0, (np.trace(r) - 1) / 2)))
    return d


def find_cycle(G, P, bvh, fps, min_len=0.8, max_len=1.7, start=None):
    """Best (s, e) so the pose at e matches the pose at s (one full step cycle)."""
    names = ["LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg", "LeftArm", "RightArm", "LeftFoot", "RightFoot"]
    js = [bvh.index[n] for n in names]
    F = len(G)
    best = None
    starts = [start] if start is not None else range(int(F * 0.2), int(F * 0.55), 2)
    for s in starts:
        # compare in the hips' own frame so turning doesn't matter
        Hs = G[s, bvh.index["Hips"]].T
        for e in range(s + int(min_len * fps), min(F, s + int(max_len * fps))):
            He = G[e, bvh.index["Hips"]].T
            d = 0.0
            for j in js:
                a = Hs @ G[s, j]
                b = He @ G[e, j]
                r = a.T @ b
                d += math.acos(max(-1.0, min(1.0, (np.trace(r) - 1) / 2)))
            if best is None or d < best[0]:
                best = (d, s, e)
    return best[1], best[2], best[0]

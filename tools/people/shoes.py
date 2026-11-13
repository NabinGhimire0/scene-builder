"""Procedural shoes lofted around each foot (clean shape, no toes showing)."""
import math
import numpy as np


def build_shoe(P, side, style, top_z):
    V = P.vb
    body = np.zeros(len(V), bool)
    body[P.base.groups["body"]] = True
    fw = P.wsum(["foot_" + side, "ball_" + side])
    lw = P.wsum(["calf_" + side])
    ankle = P.jh("foot_" + side)
    sel = body & ((fw > 0.3) | ((lw > 0.3) & (V[:, 2] < ankle[2] + 0.02))) & (V[:, 2] < ankle[2] + 0.03)
    F = V[sel]
    ymin, ymax = F[:, 1].min(), F[:, 1].max()     # toe (front, -y) .. heel (+y)
    ground = F[:, 2].min()
    L = ymax - ymin
    M, N = 18, 20
    rings = []
    for k in range(M + 1):
        s = k / M                                   # 0 heel .. 1 toe
        y = ymax - s * L
        band = F[np.abs(F[:, 1] - y) < L / M * 0.9]
        if len(band) < 3:
            band = F[np.argsort(np.abs(F[:, 1] - y))[:12]]
        x0, x1 = band[:, 0].min(), band[:, 0].max()
        ztop = band[:, 2].max()
        xc = (x0 + x1) / 2
        hw = (x1 - x0) / 2 + 0.006
        # round the heel and toe ends
        end = min(s, 1 - s)
        shrink = 1.0 if end > 0.12 else math.sqrt(max(end / 0.12, 0.0)) * 0.75 + 0.25
        ht = min(ztop + 0.010, top_z) if s > 0.45 else max(top_z, min(ztop + 0.01, top_z))
        if s > 0.45:
            ht = ground + (ht - ground) * (0.75 + 0.25 * shrink)
        zb = ground - 0.012                          # sole thickness
        zc = (zb + ht) / 2
        hh = (ht - zb) / 2
        ring = []
        for j in range(N):
            a = 2 * math.pi * j / N
            ca, sa = math.cos(a), math.sin(a)
            ex = 2.6                                   # superellipse: boxy but soft
            xr = np.sign(ca) * abs(ca) ** (2 / ex)
            zr = np.sign(sa) * abs(sa) ** (2 / ex)
            ring.append((xc + xr * hw * shrink, y, zc + zr * hh * (1.0 if zr > 0 else 1.0)))
        ring = np.array(ring)
        ring[:, 2] = np.maximum(ring[:, 2], zb)
        if k in (0, M):
            ring[:, 0] = xc + (ring[:, 0] - xc) * 0.5
            ring[:, 2] = zb + (ring[:, 2] - zb) * 0.85
        rings.append(ring)
    verts = np.concatenate(rings)
    faces, uvs = [], []
    for k in range(M):
        for j in range(N):
            a, b = k * N + j, k * N + (j + 1) % N
            c, d = (k + 1) * N + (j + 1) % N, (k + 1) * N + j
            faces.append([a, d, c, b])
    # caps
    hc = len(verts)
    verts = np.vstack([verts, rings[0].mean(axis=0), rings[-1].mean(axis=0)])
    for j in range(N):
        faces.append([hc, j, (j + 1) % N])
        faces.append([hc + 1, M * N + (j + 1) % N, M * N + j])
    # weights: copy from the nearest foot vertex
    idx = np.where(sel)[0]
    W = np.zeros((len(verts), P.W.shape[1]), np.float32)
    for i, v in enumerate(verts):
        n = idx[np.argmin(np.linalg.norm(V[idx] - v, axis=1))]
        W[i] = P.W[n]
    sole = [i for i, f in enumerate(faces) if verts[f][:, 2].mean() < ground - 0.002]
    return verts, faces, W, set(sole), ground - 0.012

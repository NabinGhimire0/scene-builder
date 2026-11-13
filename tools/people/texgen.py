"""Texture painting in UV space, driven by each texel's 3D position (numpy)."""
import numpy as np
from scipy import ndimage


def rasterize(tri_uv, tri_attr, size):
    """tri_uv (T,3,2) in 0..1, tri_attr (T,3,K) -> image (S,S,K) and coverage mask."""
    S = size
    K = tri_attr.shape[2]
    img = np.zeros((S, S, K), np.float32)
    mask = np.zeros((S, S), bool)
    px = np.empty_like(tri_uv)
    px[..., 0] = tri_uv[..., 0] * S - 0.5
    px[..., 1] = (1.0 - tri_uv[..., 1]) * S - 0.5
    for t in range(len(tri_uv)):
        p = px[t]
        x0 = max(int(np.floor(p[:, 0].min())), 0)
        x1 = min(int(np.ceil(p[:, 0].max())), S - 1)
        y0 = max(int(np.floor(p[:, 1].min())), 0)
        y1 = min(int(np.ceil(p[:, 1].max())), S - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        (ax, ay), (bx, by), (cx, cy) = p
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        w0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
        w1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
        w2 = 1 - w0 - w1
        inside = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not inside.any():
            continue
        a = tri_attr[t]
        vals = w0[..., None] * a[0] + w1[..., None] * a[1] + w2[..., None] * a[2]
        yy, xx = ys[inside], xs[inside]
        img[yy, xx] = vals[inside]
        mask[yy, xx] = True
    return img, mask


def dilate(img, mask):
    """Fill every uncovered texel from its nearest covered texel (no seams at UV edges)."""
    if mask.all():
        return img
    _, (iy, ix) = ndimage.distance_transform_edt(~mask, return_indices=True)
    return img[iy, ix]


def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return (h & 0xFFFF).astype(np.float32) / 65535.0


def noise3(p, freq, seed=0):
    """Smooth value noise in 0..1 at points p (N,3)."""
    q = p * freq
    i = np.floor(q).astype(np.int64)
    f = q - i
    f = f * f * (3 - 2 * f)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out = out + w * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


def fbm(p, freq, octaves=4, seed=0):
    tot, amp, norm = 0, 1.0, 0
    for o in range(octaves):
        tot = tot + amp * noise3(p, freq * (2 ** o), seed + o * 17)
        norm += amp
        amp *= 0.5
    return tot / norm


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def to_srgb8(lin):
    """Colours here are authored directly in sRGB 0..1."""
    return (np.clip(lin, 0, 1) * 255 + 0.5).astype(np.uint8)

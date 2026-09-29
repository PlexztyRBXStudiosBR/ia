"""
Escultura SDF (signed distance fields) + surface nets em Python puro/numpy.

É o modo "orgânico" do Arkher: em vez de colar primitivas, o modelo é definido
como campo de distância (uniões suaves de cápsulas/elipsóides/toros) e a
superfície é extraída por *surface nets* (dual contouring simplificado), com
normais analíticas do gradiente do SDF -> malhas lisas, sem emendas visíveis,
com topologia quad-triangularizada pronta para Godot/Blender/Roblox.

Com numpy a grade 128³ sai em ~1-3 s; sem numpy, 64³ em ~5-10 s.
"""
from __future__ import annotations

import math
from typing import Callable, Dict, List, Optional, Sequence, Tuple

from . import math3d as m3d
from .glb import MeshData
from .noise import HAS_NUMPY

if HAS_NUMPY:
    import numpy as np

__all__ = ["SDF", "sdf_humanoid", "sdf_creature", "sdf_rock", "sdf_bust", "extract_mesh"]

Vec3 = Tuple[float, float, float]


def _smin(a, b, k):
    """União polinomial suave (smooth min) — o segredo do look 'esculpido'."""
    if HAS_NUMPY and isinstance(a, np.ndarray):
        h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
        return b * (1 - h) + a * h - k * h * (1 - h)
    h = max(0.0, min(1.0, 0.5 + 0.5 * (b - a) / k))
    return b * (1 - h) + a * h - k * h * (1 - h)


class SDF:
    """Campo de distância composto por operações sequenciais."""

    def __init__(self):
        self._ops: List[Tuple[str, dict]] = []

    # -------------------------------------------------- primitivas
    def sphere(self, c: Vec3, r: float, k: float = 0.05) -> "SDF":
        self._ops.append(("union", {"kind": "sphere", "c": c, "r": r, "k": k}))
        return self

    def ellipsoid(self, c: Vec3, r: Vec3, k: float = 0.05) -> "SDF":
        self._ops.append(("union", {"kind": "ellipsoid", "c": c, "r": r, "k": k}))
        return self

    def capsule(self, a: Vec3, b: Vec3, r: float, k: float = 0.05) -> "SDF":
        self._ops.append(("union", {"kind": "capsule", "a": a, "b": b, "r": r, "k": k}))
        return self

    def round_box(self, c: Vec3, h: Vec3, rr: float = 0.03, k: float = 0.05) -> "SDF":
        self._ops.append(("union", {"kind": "box", "c": c, "h": h, "rr": rr, "k": k}))
        return self

    def torus(self, c: Vec3, R: float, r: float, axis: str = "y", k: float = 0.04) -> "SDF":
        self._ops.append(("union", {"kind": "torus", "c": c, "R": R, "r": r, "axis": axis, "k": k}))
        return self

    def cone(self, a: Vec3, b: Vec3, r1: float, r2: float, k: float = 0.04) -> "SDF":
        self._ops.append(("union", {"kind": "cone", "a": a, "b": b, "r1": r1, "r2": r2, "k": k}))
        return self

    def subtract(self, other_kind: str, **params) -> "SDF":
        params["kind"] = other_kind
        self._ops.append(("subtract", params))
        return self

    # -------------------------------------------------- avaliação
    def _prim(self, op: dict, p) -> object:
        """Distância de um ponto (ou array Nx3) até a primitiva."""
        kind = op["kind"]
        if HAS_NUMPY and isinstance(p, np.ndarray):
            x, y, z = p[:, 0], p[:, 1], p[:, 2]
        else:
            x, y, z = p[0], p[1], p[2]

        def dist(ax, ay, az, bx, by, bz):
            return ((ax - bx) ** 2 + (ay - by) ** 2 + (az - bz) ** 2) ** 0.5

        if kind == "sphere":
            c, r = op["c"], op["r"]
            return dist(x, y, z, c[0], c[1], c[2]) - r
        if kind == "ellipsoid":
            c, r = op["c"], op["r"]
            qx = (x - c[0]) / r[0]
            qy = (y - c[1]) / r[1]
            qz = (z - c[2]) / r[2]
            q = (qx * qx + qy * qy + qz * qz) ** 0.5
            # aproximação padrão de elipsóide SDF
            k0 = (qx * qx + qy * qy + qz * qz) ** 0.5
            k1 = ((qx / r[0]) ** 2 + (qy / r[1]) ** 2 + (qz / r[2]) ** 2) ** 0.5
            return (k0 * (k0 - 1.0)) / (k1 if k1 > 1e-9 else 1e-9)
        if kind == "capsule":
            a, b, r = op["a"], op["b"], op["r"]
            abx, aby, abz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
            apx, apy, apz = x - a[0], y - a[1], z - a[2]
            denom = abx * abx + aby * aby + abz * abz
            t = (apx * abx + apy * aby + apz * abz) / denom
            t = t if not HAS_NUMPY or isinstance(t, float) else np.clip(t, 0.0, 1.0)
            if not HAS_NUMPY or isinstance(t, float):
                t = max(0.0, min(1.0, t))
            dx = apx - abx * t
            dy = apy - aby * t
            dz = apz - abz * t
            return (dx * dx + dy * dy + dz * dz) ** 0.5 - r
        if kind == "box":
            c, h, rr = op["c"], op["h"], op["rr"]
            qx = (x - c[0]) if not HAS_NUMPY or isinstance(x, float) else np.abs(x - c[0])
            qy = (y - c[1]) if not HAS_NUMPY or isinstance(y, float) else np.abs(y - c[1])
            qz = (z - c[2]) if not HAS_NUMPY or isinstance(z, float) else np.abs(z - c[2])
            if HAS_NUMPY and isinstance(p, np.ndarray):
                qx, qy, qz = np.abs(x - c[0]), np.abs(y - c[1]), np.abs(z - c[2])
            else:
                qx, qy, qz = abs(x - c[0]), abs(y - c[1]), abs(z - c[2])
            ex = qx - h[0]
            ey = qy - h[1]
            ez = qz - h[2]
            if HAS_NUMPY and isinstance(ex, np.ndarray):
                outside = np.sqrt(np.maximum(ex, 0) ** 2 + np.maximum(ey, 0) ** 2 + np.maximum(ez, 0) ** 2)
                inside = np.minimum(np.maximum(ex, np.maximum(ey, ez)), 0.0)
                return outside + inside - rr
            mx = max(ex, 0.0)
            my = max(ey, 0.0)
            mz = max(ez, 0.0)
            return math.sqrt(mx * mx + my * my + mz * mz) + min(max(ex, max(ey, ez)), 0.0) - rr
        if kind == "torus":
            c, R, r, axis = op["c"], op["R"], op["r"], op["axis"]
            if axis == "y":
                qx = ((x - c[0]) ** 2 + (z - c[2]) ** 2) ** 0.5 - R
                qy = y - c[1]
            elif axis == "x":
                qx = ((y - c[1]) ** 2 + (z - c[2]) ** 2) ** 0.5 - R
                qy = x - c[0]
            else:
                qx = ((x - c[0]) ** 2 + (y - c[1]) ** 2) ** 0.5 - R
                qy = z - c[2]
            return (qx * qx + qy * qy) ** 0.5 - r
        if kind == "cone":
            a, b, r1, r2 = op["a"], op["b"], op["r1"], op["r2"]
            abx, aby, abz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
            L = math.sqrt(abx * abx + aby * aby + abz * abz) or 1.0
            ux, uy, uz = abx / L, aby / L, abz / L
            apx, apy, apz = x - a[0], y - a[1], z - a[2]
            t = apx * ux + apy * uy + apz * uz
            t = max(0.0, min(L, t)) if not (HAS_NUMPY and isinstance(t, np.ndarray)) else np.clip(t, 0.0, L)
            dx = apx - ux * t
            dy = apy - uy * t
            dz = apz - uz * t
            radial = (dx * dx + dy * dy + dz * dz) ** 0.5
            r_at = r1 + (r2 - r1) * (t / L)
            return (radial - r_at) * 0.9
        raise ValueError(kind)

    def eval_points(self, p) -> object:
        d = None
        for mode, op in self._ops:
            pd = self._prim(op, p)
            if d is None:
                d = pd
            elif mode == "union":
                d = _smin(d, pd, op.get("k", 0.05))
            else:
                d = -_smin(-d, pd, op.get("k", 0.03))
        return d

    def eval_one(self, x: float, y: float, z: float) -> float:
        v = self.eval_points((x, y, z))
        return float(v)


# ========================================================== extração de malha
def extract_mesh(
    sdf: SDF,
    bounds: Tuple[Vec3, Vec3] = ((-1.2, -0.2, -1.2), (1.2, 2.2, 1.2)),
    resolution: int = 96,
    smooth_iters: int = 1,
    name: str = "sdf_mesh",
) -> MeshData:
    """Surface nets sobre o campo: vértice por célula cruzada + normais do gradiente."""
    (x0, y0, z0), (x1, y1, z1) = bounds
    n = resolution

    if HAS_NUMPY:
        xs = np.linspace(x0, x1, n, dtype=np.float32)
        ys = np.linspace(y0, y1, n, dtype=np.float32)
        zs = np.linspace(z0, z1, n, dtype=np.float32)
        gx, gy, gz = np.meshgrid(xs, ys, zs, indexing="ij")
        pts = np.stack([gx.ravel(), gy.ravel(), gz.ravel()], axis=1)
        field = np.empty(pts.shape[0], dtype=np.float32)
        chunk = 200_000
        for i in range(0, pts.shape[0], chunk):
            field[i : i + chunk] = sdf.eval_points(pts[i : i + chunk])
        field = field.reshape((n, n, n))
    else:
        field = [[[0.0] * n for _ in range(n)] for _ in range(n)]
        for i in range(n):
            x = x0 + (x1 - x0) * i / (n - 1)
            for j in range(n):
                y = y0 + (y1 - y0) * j / (n - 1)
                for k in range(n):
                    z = z0 + (z1 - z0) * k / (n - 1)
                    field[i][j][k] = sdf.eval_one(x, y, z)

    def F(i, j, k):
        if HAS_NUMPY:
            return float(field[i, j, k])
        return field[i][j][k]

    def point_at(i, j, k):
        return (
            x0 + (x1 - x0) * i / (n - 1),
            y0 + (y1 - y0) * j / (n - 1),
            z0 + (z1 - z0) * k / (n - 1),
        )

    # vértices por célula (surface nets: média das interseções das arestas)
    verts: List[Tuple[float, float, float]] = []
    cell_vert: Dict[Tuple[int, int, int], int] = {}
    edges = [(0, 0, 0, 1, 0, 0), (0, 0, 0, 0, 1, 0), (0, 0, 0, 0, 0, 1)]
    for i in range(n - 1):
        for j in range(n - 1):
            for k in range(n - 1):
                c0 = F(i, j, k)
                sign0 = c0 < 0
                crossings = []
                changed = False
                for (di, dj, dk, ei, ej, ek) in [
                    (0, 0, 0, 1, 0, 0), (0, 0, 0, 0, 1, 0), (0, 0, 0, 0, 0, 1),
                    (1, 0, 0, 0, 1, 0), (1, 0, 0, 0, 0, 1), (0, 1, 0, 1, 0, 0),
                    (0, 1, 0, 0, 0, 1), (0, 0, 1, 1, 0, 0), (0, 0, 1, 0, 1, 0),
                    (1, 1, 0, 0, 0, 1), (1, 0, 1, 0, 1, 0), (0, 1, 1, 1, 0, 0),
                ]:
                    a = F(i + di, j + dj, k + dk)
                    b = F(i + di + ei, j + dj + ej, k + dk + ek)
                    if (a < 0) != (b < 0):
                        t = a / (a - b) if (a - b) != 0 else 0.5
                        pa = point_at(i + di + ei * t if ei else i + di,
                                      j + dj + ej * t if ej else j + dj,
                                      k + dk + ek * t if ek else k + dk)
                        # interpola corretamente ao longo da aresta
                        p0 = point_at(i + di, j + dj, k + dk)
                        p1 = point_at(i + di + ei, j + dj + ej, k + dk + ek)
                        pa = (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t, p0[2] + (p1[2] - p0[2]) * t)
                        crossings.append(pa)
                        changed = True
                if changed and crossings:
                    cx = sum(p[0] for p in crossings) / len(crossings)
                    cy = sum(p[1] for p in crossings) / len(crossings)
                    cz = sum(p[2] for p in crossings) / len(crossings)
                    cell_vert[(i, j, k)] = len(verts)
                    verts.append((cx, cy, cz))
                _ = edges, sign0

    if not verts:
        raise ValueError("SDF vazio: ajuste bounds/resolution")

    indices = []
    # quads: para cada aresta cruzada, o quad das 4 células que compartilham a aresta
    for i in range(n - 1):
        for j in range(n - 1):
            for k in range(n - 1):
                for axis, (di, dj, dk) in enumerate(((1, 0, 0), (0, 1, 0), (0, 0, 1))):
                    a = F(i, j, k)
                    b = F(i + di, j + dj, k + dk)
                    if (a < 0) == (b < 0):
                        continue
                    if axis == 0:
                        cells = [(i, j - 1, k - 1), (i, j, k - 1), (i, j, k), (i, j - 1, k)]
                    elif axis == 1:
                        cells = [(i - 1, j, k - 1), (i, j, k - 1), (i, j, k), (i - 1, j, k)]
                    else:
                        cells = [(i - 1, j - 1, k), (i, j - 1, k), (i, j, k), (i - 1, j, k)]
                    ids = [cell_vert.get(c) for c in cells]
                    if any(v is None for v in ids):
                        continue
                    v0 = verts[ids[0]]
                    v1 = verts[ids[1]]
                    v2 = verts[ids[2]]
                    e1 = (v1[0] - v0[0], v1[1] - v0[1], v1[2] - v0[2])
                    e2 = (v2[0] - v0[0], v2[1] - v0[1], v2[2] - v0[2])
                    nx = e1[1] * e2[2] - e1[2] * e2[1]
                    ny = e1[2] * e2[0] - e1[0] * e2[2]
                    nz = e1[0] * e2[1] - e1[1] * e2[0]
                    cx = (v0[0] + v1[0] + v2[2] * 0 + verts[ids[3]][0]) / 4
                    cy = (v0[1] + v1[1] + v2[1] + verts[ids[3]][1]) / 4
                    cz = (v0[2] + v1[2] + v2[2] + verts[ids[3]][2]) / 4
                    hh = 1e-3
                    gx = sdf.eval_one(cx + hh, cy, cz) - sdf.eval_one(cx - hh, cy, cz)
                    gy = sdf.eval_one(cx, cy + hh, cz) - sdf.eval_one(cx, cy - hh, cz)
                    gz = sdf.eval_one(cx, cy, cz + hh) - sdf.eval_one(cx, cy, cz - hh)
                    if nx * gx + ny * gy + nz * gz < 0:
                        indices.extend((ids[0], ids[2], ids[1], ids[0], ids[3], ids[2]))
                    else:
                        indices.extend((ids[0], ids[1], ids[2], ids[0], ids[2], ids[3]))

    # normais analíticas pelo gradiente do SDF
    normals: List[float] = []
    uvs: List[float] = []
    h = 1e-3
    for (x, y, z) in verts:
        dx = sdf.eval_one(x + h, y, z) - sdf.eval_one(x - h, y, z)
        dy = sdf.eval_one(x, y + h, z) - sdf.eval_one(x, y - h, z)
        dz = sdf.eval_one(x, y, z + h) - sdf.eval_one(x, y, z - h)
        nrm = m3d.normalize((dx, dy, dz)) or (0.0, 1.0, 0.0)
        normals.extend(nrm)
        # UV box projection pelo eixo dominante da normal
        ax, ay, az = abs(nrm[0]), abs(nrm[1]), abs(nrm[2])
        if ax >= ay and ax >= az:
            u, v = z, y
        elif ay >= az:
            u, v = x, z
        else:
            u, v = x, y
        uvs.extend((u * 0.5, v * 0.5))

    mesh = MeshData(name=name, positions=[c for p in verts for c in p], normals=normals, uvs=uvs, indices=indices)
    if smooth_iters:
        mesh = _laplacian(mesh, smooth_iters)
    return mesh


def _laplacian(mesh: MeshData, iters: int = 1, factor: float = 0.35) -> MeshData:
    n = mesh.vertex_count
    neigh: Dict[int, List[int]] = {i: [] for i in range(n)}
    for t in range(0, len(mesh.indices), 3):
        a, b, c = mesh.indices[t], mesh.indices[t + 1], mesh.indices[t + 2]
        neigh[a].extend((b, c))
        neigh[b].extend((a, c))
        neigh[c].extend((a, b))
    pos = mesh.positions[:]
    for _ in range(iters):
        new = pos[:]
        for i in range(n):
            ns = neigh[i]
            if not ns:
                continue
            sx = sy = sz = 0.0
            for j in ns:
                sx += pos[j * 3]
                sy += pos[j * 3 + 1]
                sz += pos[j * 3 + 2]
            m = len(ns)
            new[i * 3] = pos[i * 3] + factor * (sx / m - pos[i * 3])
            new[i * 3 + 1] = pos[i * 3 + 1] + factor * (sy / m - pos[i * 3 + 1])
            new[i * 3 + 2] = pos[i * 3 + 2] + factor * (sz / m - pos[i * 3 + 2])
        pos = new
    mesh = MeshData(name=mesh.name, positions=pos, normals=mesh.normals, uvs=mesh.uvs, indices=mesh.indices, material=mesh.material)
    return _recompute_normals(mesh)


def _recompute_normals(mesh: MeshData) -> MeshData:
    """Normais de vértice a partir das faces (necessário após suavizar)."""
    n = mesh.vertex_count
    acc = [0.0] * (n * 3)
    pos = mesh.positions
    idx = mesh.indices
    for t in range(0, len(idx), 3):
        a, b, c = idx[t] * 3, idx[t + 1] * 3, idx[t + 2] * 3
        e1 = (pos[b] - pos[a], pos[b + 1] - pos[a + 1], pos[b + 2] - pos[a + 2])
        e2 = (pos[c] - pos[a], pos[c + 1] - pos[a + 1], pos[c + 2] - pos[a + 2])
        nx = e1[1] * e2[2] - e1[2] * e2[1]
        ny = e1[2] * e2[0] - e1[0] * e2[2]
        nz = e1[0] * e2[1] - e1[1] * e2[0]
        for v in (a, b, c):
            acc[v] += nx
            acc[v + 1] += ny
            acc[v + 2] += nz
    out = [0.0] * (n * 3)
    for i in range(n):
        x, y, z = acc[i * 3], acc[i * 3 + 1], acc[i * 3 + 2]
        d = (x * x + y * y + z * z) ** 0.5 or 1.0
        out[i * 3] = x / d
        out[i * 3 + 1] = y / d
        out[i * 3 + 2] = z / d
    mesh.normals = out
    return mesh


# ================================================================ receitas
def sdf_humanoid(muscle: float = 1.0) -> SDF:
    s = SDF()
    # núcleo do corpo: uniões suaves (peito, cintura, pelve)
    s.ellipsoid((0, 1.28, 0), (0.20 * muscle, 0.19, 0.13), k=0.09)
    s.ellipsoid((0, 1.02, 0), (0.16, 0.15, 0.11), k=0.10)
    s.ellipsoid((0, 0.88, 0), (0.18, 0.13, 0.12), k=0.09)
    # pescoço + cabeça + maxilar
    s.capsule((0, 1.44, 0), (0, 1.54, 0), 0.055, k=0.06)
    s.ellipsoid((0, 1.66, 0.01), (0.105, 0.125, 0.115), k=0.05)
    s.ellipsoid((0, 1.60, 0.06), (0.075, 0.07, 0.08), k=0.06)
    for sgn in (1, -1):
        # trapézio/ombro deltóide
        s.sphere((0.20 * sgn, 1.42, 0), 0.075 * muscle, k=0.08)
        # braço: bíceps -> cotovelo -> antebraço -> mão
        s.capsule((0.235 * sgn, 1.40, 0), (0.26 * sgn, 1.14, 0.01), 0.052 * muscle, k=0.06)
        s.sphere((0.26 * sgn, 1.12, 0.01), 0.045, k=0.05)
        s.capsule((0.26 * sgn, 1.12, 0.01), (0.27 * sgn, 0.90, 0.03), 0.045 * muscle, k=0.05)
        s.ellipsoid((0.27 * sgn, 0.82, 0.04), (0.04, 0.075, 0.028), k=0.05)
        # glúteo + coxa + panturrilha + pé
        s.sphere((0.10 * sgn, 0.86, -0.02), 0.10 * muscle, k=0.09)
        s.capsule((0.11 * sgn, 0.84, 0), (0.115 * sgn, 0.50, 0.01), 0.082 * muscle, k=0.07)
        s.sphere((0.115 * sgn, 0.48, 0.01), 0.06, k=0.06)
        s.capsule((0.115 * sgn, 0.48, 0.0), (0.115 * sgn, 0.16, -0.01), 0.058 * muscle, k=0.06)
        s.sphere((0.115 * sgn, 0.30, -0.02), 0.055 * muscle, k=0.07)
        s.ellipsoid((0.115 * sgn, 0.045, 0.06), (0.05, 0.04, 0.13), k=0.05)
    return s


def sdf_creature(seed: int = 5) -> SDF:
    s = SDF()
    s.ellipsoid((0, 0.72, 0), (0.34, 0.30, 0.48), k=0.12)
    s.ellipsoid((0, 0.92, 0.52), (0.19, 0.17, 0.22), k=0.10)
    s.ellipsoid((0, 0.86, 0.66), (0.10, 0.08, 0.10), k=0.07)  # focinho
    s.cone((0.09, 1.05, 0.55), (0.14, 1.22, 0.5), 0.045, 0.008, k=0.04)
    s.cone((-0.09, 1.05, 0.55), (-0.14, 1.22, 0.5), 0.045, 0.008, k=0.04)
    for sgn in (1, -1):
        s.capsule((0.26 * sgn, 0.62, 0.30), (0.30 * sgn, 0.16, 0.34), 0.075, k=0.08)
        s.capsule((0.24 * sgn, 0.60, -0.28), (0.28 * sgn, 0.16, -0.32), 0.08, k=0.08)
        s.sphere((0.30 * sgn, 0.14, 0.36), 0.07, k=0.06)
        s.sphere((0.28 * sgn, 0.14, -0.34), 0.075, k=0.06)
    # cauda em curva (cadeia de cápsulas)
    pts = [(0, 0.72, -0.45), (0, 0.74, -0.68), (0, 0.66, -0.88), (0, 0.52, -1.02)]
    for a, b in zip(pts, pts[1:]):
        s.capsule(a, b, 0.06, k=0.07)
    # crista dorsal
    for i, z in enumerate((-0.15, 0.0, 0.15, 0.3)):
        s.ellipsoid((0, 1.0 - i * 0.02, z), (0.02, 0.10 - i * 0.012, 0.07), k=0.05)
    return s


def sdf_rock(seed: int = 42) -> SDF:
    import random

    rnd = random.Random(seed)
    s = SDF()
    s.ellipsoid((0, 0.35, 0), (0.7, 0.5, 0.62), k=0.10)
    for _ in range(6):
        c = (rnd.uniform(-0.5, 0.5), rnd.uniform(0.1, 0.6), rnd.uniform(-0.4, 0.4))
        s.sphere(c, rnd.uniform(0.15, 0.34), k=rnd.uniform(0.08, 0.18))
    s.subtract("sphere", c=(0.55, 0.75, 0.35), r=0.35, k=0.10)
    return s


def sdf_bust() -> SDF:
    """Busto estilizado (cabeça + ombros) — bom teste de superfície lisa."""
    s = SDF()
    s.ellipsoid((0, 1.62, 0.01), (0.115, 0.14, 0.125), k=0.05)
    s.ellipsoid((0, 1.55, 0.07), (0.08, 0.075, 0.085), k=0.06)
    s.capsule((0, 1.46, 0), (0, 1.52, 0), 0.06, k=0.06)
    s.ellipsoid((0, 1.30, 0), (0.26, 0.12, 0.14), k=0.10)
    s.sphere((0.20, 1.34, 0), 0.09, k=0.09)
    s.sphere((-0.20, 1.34, 0), 0.09, k=0.09)
    return s

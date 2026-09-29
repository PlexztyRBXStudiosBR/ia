"""
Ruído procedural determinístico (value noise, fBm, Worley) -- Python puro ou numpy.

Todas as funções recebem `size` (lado do mapa quadrado) e devolvem um
`array.array('f')` plano com valores em 0..1, pronto para virar PNG.

Com numpy instalado o fBm 4k/8k/16k é gerado em segundos; sem numpy o mesmo
código roda em Python puro (mais lento, mas funciona em qualquer máquina).
"""
from __future__ import annotations

import math
import random
from array import array
from typing import List, Optional, Sequence, Tuple

try:
    import numpy as np

    HAS_NUMPY = True
except Exception:  # pragma: no cover
    np = None
    HAS_NUMPY = False

__all__ = [
    "fbm", "ridged", "worley", "billow", "smoothstep", "clamp01", "to_bytes",
    "height_to_normal", "HAS_NUMPY",
]


def clamp01(x: float) -> float:
    return 0.0 if x < 0.0 else (1.0 if x > 1.0 else x)


def smoothstep(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)


def to_bytes(values: Sequence[float], lo: float = 0.0, hi: float = 1.0) -> bytearray:
    span = (hi - lo) or 1.0
    out = bytearray(len(values))
    for i, v in enumerate(values):
        t = (v - lo) / span
        out[i] = 0 if t <= 0 else (255 if t >= 1 else int(t * 255.0 + 0.5))
    return out


# ============================================================ numpy path
def _np_lattice(size: int, grid: int, seed: int, tile: bool):
    rng = np.random.default_rng(seed & 0xFFFFFFFF)
    if tile:
        g = rng.random((grid, grid), dtype=np.float32)
        g = np.concatenate([g, g[:1]], axis=0)
        g = np.concatenate([g, g[:, :1]], axis=1)
    else:
        g = rng.random((grid + 1, grid + 1), dtype=np.float32)
    y = np.linspace(0.0, grid, size, endpoint=False, dtype=np.float32)
    x = np.linspace(0.0, grid, size, endpoint=False, dtype=np.float32)
    X, Y = np.meshgrid(x, y)
    x0 = np.floor(X).astype(np.int32)
    y0 = np.floor(Y).astype(np.int32)
    fx = smoothstep_np(X - x0)
    fy = smoothstep_np(Y - y0)
    x1, y1 = x0 + 1, y0 + 1
    if tile:
        x1 = np.where(x1 >= grid, x1 - grid, x1)
        y1 = np.where(y1 >= grid, y1 - grid, y1)
    v00 = g[y0, x0]
    v10 = g[y0, x1]
    v01 = g[y1, x0]
    v11 = g[y1, x1]
    top = v00 + (v10 - v00) * fx
    bot = v01 + (v11 - v01) * fx
    return (top + (bot - top) * fy).astype(np.float32)


def smoothstep_np(t):
    return t * t * (3.0 - 2.0 * t)


def _np_fbm(size, seed, octaves, lacunarity, gain, tile, ridged=False, warp=0.0):
    total = np.zeros((size, size), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    grid = 4
    ox = oy = 0.0
    for o in range(octaves):
        if warp:
            w = _np_lattice(size, grid, seed + o * 977 + 13, tile)
            n = _np_lattice(size, grid, seed + o * 977, tile)
            shift = (w - 0.5) * warp
            n = n + shift  # domain warp simples
        else:
            n = _np_lattice(size, grid, seed + o * 977, tile)
        if ridged:
            n = 1.0 - np.abs(n * 2.0 - 1.0)
            n = n * n
        total += n * amp
        norm += amp
        amp *= gain
        grid = min(int(grid * lacunarity), max(size // 2, 8))
        if tile is False:
            ox += 0.5
            oy += 0.5
    return total / max(norm, 1e-6)


def _np_worley(size: int, seed: int, cells: int, tile: bool, jitter: float = 1.0):
    rng = np.random.default_rng(seed & 0xFFFFFFFF)
    pts = []
    for cy in range(cells):
        for cx in range(cells):
            px = (cx + rng.random() * jitter + (1 - jitter) * 0.5) / cells
            py = (cy + rng.random() * jitter + (1 - jitter) * 0.5) / cells
            pts.append((px, py))
    ys = (np.arange(size, dtype=np.float32) + 0.5) / size
    xs = (np.arange(size, dtype=np.float32) + 0.5) / size
    X, Y = np.meshgrid(xs, ys)
    f1 = np.full((size, size), 1e9, dtype=np.float32)
    f2 = np.full((size, size), 1e9, dtype=np.float32)
    for (px, py) in pts:
        for dx in ((0,) if tile else (0,)):
            d = np.sqrt((X - px - dx) ** 2 + (Y - py) ** 2)
            if tile:
                for sh in (-1.0, 1.0):
                    d = np.minimum(d, np.sqrt((X - px - sh) ** 2 + (Y - py) ** 2))
                    d = np.minimum(d, np.sqrt((X - px) ** 2 + (Y - py - sh) ** 2))
                    d = np.minimum(d, np.sqrt((X - px - sh) ** 2 + (Y - py - sh) ** 2))
            f2 = np.minimum(f2, np.maximum(f1, d))
            f1 = np.minimum(f1, d)
    return f1, f2


# ========================================================= pure python path
def _py_lattice(size: int, grid: int, seed: int, tile: bool) -> array:
    rnd = random.Random(seed & 0xFFFFFFFF)
    g = [[rnd.random() for _ in range(grid + 1)] for _ in range(grid + 1)]
    if tile:
        for y in range(grid + 1):
            g[y][grid] = g[y][0]
        for x in range(grid + 1):
            g[grid][x] = g[0][x]
    out = array("f", bytes(4 * size * size))
    step = grid / size
    for py in range(size):
        fy = py * step
        y0 = int(fy)
        ty = smoothstep(fy - y0)
        y1 = y0 + 1
        row = py * size
        for px in range(size):
            fx = px * step
            x0 = int(fx)
            tx = smoothstep(fx - x0)
            x1 = x0 + 1
            v00 = g[y0][x0]
            v10 = g[y0][x1]
            v01 = g[y1][x0]
            v11 = g[y1][x1]
            top = v00 + (v10 - v00) * tx
            bot = v01 + (v11 - v01) * tx
            out[row + px] = top + (bot - top) * ty
    return out


def _py_fbm(size, seed, octaves, lacunarity, gain, tile, ridged=False, warp=0.0):
    total = array("f", bytes(4 * size * size))
    amp = 1.0
    norm = 0.0
    grid = 4
    n_pix = size * size
    for o in range(octaves):
        n = _py_lattice(size, grid, seed + o * 977, tile)
        if ridged:
            for i in range(n_pix):
                v = 1.0 - abs(n[i] * 2.0 - 1.0)
                total[i] += v * v * amp
        else:
            for i in range(n_pix):
                total[i] += n[i] * amp
        norm += amp
        amp *= gain
        grid = min(int(grid * lacunarity), max(size // 2, 8))
    inv = 1.0 / max(norm, 1e-6)
    for i in range(n_pix):
        total[i] *= inv
    return total


def _py_worley(size: int, seed: int, cells: int, tile: bool, jitter: float = 1.0):
    """Worley em Python puro com busca apenas nas células vizinhas (3x3)."""
    rnd = random.Random(seed & 0xFFFFFFFF)
    # pontos organizados por célula (todas as células existem, mesmo vazias)
    buckets: dict = {(cy, cx): [] for cy in range(cells) for cx in range(cells)}
    for cy in range(cells):
        for cx in range(cells):
            px = (cx + jitter * rnd.random() + (1 - jitter) * 0.5) / cells
            py = (cy + jitter * rnd.random() + (1 - jitter) * 0.5) / cells
            buckets.setdefault((cy, cx), []).append((px, py))
            if tile:  # réplicas para wrap sem costura
                for (oy, ox) in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
                    key = (cy + oy, cx + ox)
                    if 0 <= key[0] < cells and 0 <= key[1] < cells:
                        buckets[key].append((px + ox / cells, py + oy / cells))

    f1 = array("f", bytes(4 * size * size))
    f2 = array("f", bytes(4 * size * size))
    inv = 1.0 / size
    cell_px = size / cells
    for py in range(size):
        y = (py + 0.5) * inv
        cy = int(y * cells)
        row = py * size
        for px in range(size):
            x = (px + 0.5) * inv
            cx = int(x * cells)
            d1 = 1e9
            d2 = 1e9
            for oy in (-1, 0, 1):
                for ox in (-1, 0, 1):
                    for (qx, qy) in buckets.get((cy + oy, cx + ox), ()):
                        dx = x - qx
                        dy = y - qy
                        d = math.sqrt(dx * dx + dy * dy)
                        if d < d1:
                            d2 = d1
                            d1 = d
                        elif d < d2:
                            d2 = d
            f1[row + px] = d1
            f2[row + px] = d2
    return f1, f2


# ============================================================== API pública
def fbm(
    size: int,
    seed: int = 1337,
    octaves: int = 6,
    lacunarity: float = 2.0,
    gain: float = 0.5,
    tile: bool = True,
) -> array:
    if HAS_NUMPY:
        a = _np_fbm(size, seed, octaves, lacunarity, gain, tile)
        return array("f", a.astype("<f4").tobytes())
    return _py_fbm(size, seed, octaves, lacunarity, gain, tile)


def ridged(size: int, seed: int = 1337, octaves: int = 5, tile: bool = True) -> array:
    if HAS_NUMPY:
        a = _np_fbm(size, seed, octaves, 2.0, 0.5, tile, ridged=True)
        return array("f", a.astype("<f4").tobytes())
    return _py_fbm(size, seed, octaves, 2.0, 0.5, tile, ridged=True)


def billow(size: int, seed: int = 1337, octaves: int = 5, tile: bool = True) -> array:
    """'Billow' = |fbm*2-1| invertido -- bom para nuvens/pedra/nuvem de fumaça."""
    base = fbm(size, seed, octaves, 2.0, 0.55, tile)
    out = array("f", bytes(4 * len(base)))
    for i, v in enumerate(base):
        out[i] = 1.0 - abs(v * 2.0 - 1.0)
    return out


def worley(size: int, seed: int = 99, cells: int = 8, tile: bool = True) -> Tuple[array, array]:
    if HAS_NUMPY:
        f1, f2 = _np_worley(size, seed, cells, tile)
        return (
            array("f", f1.astype("<f4").tobytes()),
            array("f", f2.astype("<f4").tobytes()),
        )
    return _py_worley(size, seed, cells, tile)


def height_to_normal(height: Sequence[float], size: int, strength: float = 2.0) -> Tuple[array, array, array]:
    """Converte mapa de altura em normal map tangent-space (OpenGL, +Y verde)."""
    r = array("B", bytes(size * size))
    g = array("B", bytes(size * size))
    b = array("B", bytes(size * size))
    inv = 1.0 / (size or 1)
    for y in range(size):
        ym = (y - 1) % size
        yp = (y + 1) % size
        row = y * size
        for x in range(size):
            xm = (x - 1) % size
            xp = (x + 1) % size
            dx = (height[row + xp] - height[row + xm]) * strength
            dy = (height[yp * size + x] - height[ym * size + x]) * strength
            nx, ny, nz = -dx, -dy, 1.0
            n = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
            r[row + x] = int((nx / n * 0.5 + 0.5) * 255.0)
            g[row + x] = int((ny / n * 0.5 + 0.5) * 255.0)
            b[row + x] = int((nz / n * 0.5 + 0.5) * 255.0)
    return r, g, b


def height_to_normal_np(height, size: int, strength: float = 2.0):
    """Versão numpy de height_to_normal; height = np.ndarray (size,size)."""
    if not HAS_NUMPY:
        return None
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    n = np.sqrt(dx * dx + dy * dy + 1.0)
    r = ((-dx / n) * 0.5 + 0.5) * 255.0
    g = ((-dy / n) * 0.5 + 0.5) * 255.0
    b = ((1.0 / n) * 0.5 + 0.5) * 255.0
    return (
        np.clip(r, 0, 255).astype(np.uint8).ravel(),
        np.clip(g, 0, 255).astype(np.uint8).ravel(),
        np.clip(b, 0, 255).astype(np.uint8).ravel(),
    )


def height_to_normal_rgb(
    height: Sequence[float], size: int, strength: float = 2.0
) -> Tuple[array, array, array]:
    """Igual a height_to_normal, mas devolve 3 arrays 'B' prontos para PNG."""
    r = array("B", bytes(size * size))
    g = array("B", bytes(size * size))
    b = array("B", bytes(size * size))
    for y in range(size):
        ym = (y - 1) % size
        yp = (y + 1) % size
        row = y * size
        prow = yp * size
        mrow = ym * size
        for x in range(size):
            xm = (x - 1) % size
            xp = (x + 1) % size
            dx = (height[row + xp] - height[row + xm]) * strength
            dy = (height[prow + x] - height[mrow + x]) * strength
            nz = 1.0
            n = math.sqrt(dx * dx + dy * dy + 1.0)
            r[row + x] = int((-dx / n * 0.5 + 0.5) * 255.0 + 0.5)
            g[row + x] = int((-dy / n * 0.5 + 0.5) * 255.0 + 0.5)
            b[row + x] = int((nz / n * 0.5 + 0.5) * 255.0 + 0.5)
    return r, g, b

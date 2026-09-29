"""
Geração de mapas PBR procedurais (albedo, normal, roughness, metallic, AO, height).

Materiais: pedra, tijolo, metal, aço escovado, ouro, madeira, couro, tecido,
grama, terra, areia, gelo, mármore, lava, concreto, asfalto, carne/pele,
cristal/energia e genérico.

Resoluções reais: 512, 1k, 2k, 4k, 8k, 16k (16k = 268 MP, ~1 GB de RAM por mapa
em Python puro -- o servidor avisa o custo antes de gerar).

Os mapas são seamless (tileáveis) por padrão: o ruído é gerado com wrap nas
duas bordas, então dá pra usar em terreno infinito sem costura.
"""
from __future__ import annotations

import math
import random
from array import array
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence, Tuple

from . import noise
from .noise import HAS_NUMPY
from .pnglib import encode_rgb, encode_gray

__all__ = ["MATERIALS", "generate_pbr_set", "PbrSet", "RESOLUTIONS", "resolution_px"]

RESOLUTIONS: Dict[str, int] = {
    "512": 512,
    "1k": 1024,
    "2k": 2048,
    "4k": 4096,
    "8k": 8192,
    "16k": 16384,
}


def resolution_px(res: str) -> int:
    return RESOLUTIONS.get(str(res).lower(), 1024)


@dataclass
class PbrMap:
    channel: str
    width: int
    height: int
    png: bytes
    color_space: str = "sRGB"  # ou "linear"


@dataclass
class PbrSet:
    material: str
    resolution: str
    size: int
    maps: List[PbrMap] = field(default_factory=list)
    material_def: Dict[str, object] = field(default_factory=dict)
    stats: Dict[str, object] = field(default_factory=dict)

    def map(self, channel: str) -> Optional[PbrMap]:
        for m in self.maps:
            if m.channel == channel:
                return m
        return None


# ------------------------------------------------------------------ receitas
# base_color: (r, g, b) 0..1 ; roughness / metallic: 0..1
MATERIALS: Dict[str, Dict[str, object]] = {
    "stone": {
        "label": "Pedra", "base": (0.44, 0.43, 0.42), "rough": 0.86, "metal": 0.0,
        "height_scale": 1.0, "octaves": 7, "worley": 10, "grain": 0.10,
        "pattern": "mottled", "ao_strength": 0.55, "contrast": 2.1,
    },
    "brick": {
        "label": "Tijolo", "base": (0.55, 0.27, 0.20), "rough": 0.82, "metal": 0.0,
        "height_scale": 1.1, "pattern": "brick", "rows": 8, "cols": 4,
        "mortar": (0.72, 0.70, 0.66), "ao_strength": 0.85,
    },
    "metal": {
        "label": "Metal gasto", "base": (0.62, 0.63, 0.66), "rough": 0.34, "metal": 1.0,
        "height_scale": 0.5, "pattern": "scratched", "ao_strength": 0.25,
        "rust": 0.22,
    },
    "steel_brushed": {
        "label": "Aço escovado", "base": (0.72, 0.73, 0.75), "rough": 0.22, "metal": 1.0,
        "height_scale": 0.25, "pattern": "brushed", "ao_strength": 0.10,
    },
    "gold": {
        "label": "Ouro polido", "base": (1.0, 0.78, 0.34), "rough": 0.16, "metal": 1.0,
        "height_scale": 0.15, "pattern": "smooth", "ao_strength": 0.10,
    },
    "wood": {
        "label": "Madeira", "base": (0.47, 0.31, 0.18), "rough": 0.68, "metal": 0.0,
        "height_scale": 0.55, "pattern": "wood", "rings": 26, "ao_strength": 0.40,
    },
    "leather": {
        "label": "Couro", "base": (0.33, 0.20, 0.13), "rough": 0.62, "metal": 0.0,
        "height_scale": 0.7, "pattern": "cells", "cells": 26, "ao_strength": 0.6,
    },
    "fabric": {
        "label": "Tecido", "base": (0.42, 0.30, 0.30), "rough": 0.92, "metal": 0.0,
        "height_scale": 0.4, "pattern": "weave", "weave": 96, "ao_strength": 0.5,
    },
    "grass": {
        "label": "Grama", "base": (0.24, 0.42, 0.16), "rough": 0.88, "metal": 0.0,
        "height_scale": 0.85, "pattern": "blades", "blades": 5200, "ao_strength": 0.6,
    },
    "dirt": {
        "label": "Terra", "base": (0.34, 0.25, 0.17), "rough": 0.95, "metal": 0.0,
        "height_scale": 1.0, "pattern": "mottled", "octaves": 8, "worley": 14,
        "grain": 0.18, "ao_strength": 0.6, "contrast": 1.9,
    },
    "sand": {
        "label": "Areia", "base": (0.82, 0.74, 0.58), "rough": 0.9, "metal": 0.0,
        "height_scale": 0.35, "pattern": "ripples", "ripples": 26, "grain": 0.14,
        "ao_strength": 0.35,
    },
    "ice": {
        "label": "Gelo", "base": (0.72, 0.86, 0.95), "rough": 0.08, "metal": 0.0,
        "height_scale": 0.5, "pattern": "cracked", "cracks": 16, "ao_strength": 0.3,
        "transmission": 0.6,
    },
    "marble": {
        "label": "Mármore", "base": (0.90, 0.89, 0.87), "rough": 0.18, "metal": 0.0,
        "height_scale": 0.2, "pattern": "veins", "vein_color": (0.35, 0.36, 0.40),
        "ao_strength": 0.15,
    },
    "lava": {
        "label": "Lava / magma", "base": (0.16, 0.09, 0.08), "rough": 0.75, "metal": 0.0,
        "height_scale": 0.9, "pattern": "cracks", "cracks": 12,
        "emissive": (1.0, 0.32, 0.05), "emissive_mask": "cracks", "ao_strength": 0.4,
    },
    "concrete": {
        "label": "Concreto", "base": (0.62, 0.62, 0.61), "rough": 0.9, "metal": 0.0,
        "height_scale": 0.45, "pattern": "mottled", "octaves": 6, "grain": 0.16,
        "ao_strength": 0.4, "contrast": 1.6,
    },
    "asphalt": {
        "label": "Asfalto", "base": (0.16, 0.16, 0.17), "rough": 0.82, "metal": 0.0,
        "height_scale": 0.6, "pattern": "cells", "cells": 60, "grain": 0.2,
        "ao_strength": 0.55,
    },
    "skin": {
        "label": "Pele / carne", "base": (0.76, 0.57, 0.47), "rough": 0.55, "metal": 0.0,
        "height_scale": 0.25, "pattern": "cells", "cells": 90, "ao_strength": 0.3,
        "subsurface": 0.5,
    },
    "crystal": {
        "label": "Cristal / energia", "base": (0.35, 0.62, 0.95), "rough": 0.1, "metal": 0.2,
        "height_scale": 0.7, "pattern": "cells", "cells": 18,
        "emissive": (0.25, 0.6, 1.0), "emissive_mask": "cells", "ao_strength": 0.2,
    },
    "generic": {
        "label": "Genérico", "base": (0.6, 0.6, 0.62), "rough": 0.6, "metal": 0.1,
        "height_scale": 0.5, "pattern": "mottled", "octaves": 6, "ao_strength": 0.35,
    },
}


# ------------------------------------------------------------------- helpers
def _clamp(v: float) -> float:
    return 0.0 if v < 0.0 else (1.0 if v > 1.0 else v)


def _lin_to_srgb(c: float) -> float:
    c = _clamp(c)
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1.0 / 2.4)) - 0.055


def _new(size: int, fill: float = 0.0) -> array:
    a = array("f", bytes(4 * size * size))
    if fill:
        for i in range(size * size):
            a[i] = fill
    return a


def _mix3(a: Sequence[float], b: Sequence[float], t: float) -> Tuple[float, float, float]:
    return (a[0] * (1 - t) + b[0] * t, a[1] * (1 - t) + b[1] * t, a[2] * (1 - t) + b[2] * t)


def _pattern_height(recipe: Dict[str, object], size: int, seed: int, tile: bool) -> Tuple[array, array]:
    """Devolve (height 0..1, mask_extra 0..1) conforme o padrão do material."""
    pattern = str(recipe.get("pattern", "mottled"))
    octaves = int(recipe.get("octaves", 6))
    n = size * size

    if pattern == "mottled":
        h = noise.fbm(size, seed, octaves, 2.0, 0.52, tile)
        cells = int(recipe.get("worley", 0) or 0)
        if cells:
            f1, f2 = noise.worley(size, seed + 31, cells, tile)
            grain = float(recipe.get("grain", 0.0) or 0.0)
            rnd = random.Random(seed + 7)
            out = _new(size)
            for i in range(n):
                g = rnd.random() * grain if grain else 0.0
                pore = 1.0 - min(f1[i] * cells * 2.2, 1.0)
                crack = 1.0 - min((f2[i] - f1[i]) * cells * 3.0, 1.0)
                out[i] = _clamp(h[i] * 0.62 + pore * 0.22 + crack * 0.16 + g)
            return out, out
        return h, h

    if pattern == "brick":
        return _brick(recipe, size, seed, tile)

    if pattern == "wood":
        return _wood(recipe, size, seed, tile)

    if pattern == "brushed":
        return _brushed(size, seed, tile)

    if pattern == "scratched":
        return _scratched(size, seed, tile)

    if pattern == "cells":
        cells = int(recipe.get("cells", 24))
        f1, f2 = noise.worley(size, seed + 5, cells, tile)
        out = _new(size)
        mask = _new(size)
        for i in range(n):
            d = min(f1[i] * float(cells) * 0.35, 1.0)
            out[i] = _clamp(0.25 + d * 0.75)
            edge = 1.0 - min(f1[i] * float(cells) * 1.4, 1.0)
            mask[i] = edge
        return out, mask

    if pattern == "weave":
        return _weave(int(recipe.get("weave", 64)), size)

    if pattern == "blades":
        return _grass(recipe, size, seed, tile)

    if pattern == "ripples":
        return _ripples(int(recipe.get("ripples", 20)), size, seed, tile, float(recipe.get("grain", 0.1)))

    if pattern == "cracked":
        return _cracked(int(recipe.get("cracks", 14)), size, seed, tile)

    if pattern == "veins":
        return _veins(size, seed, tile)

    # smooth
    h = noise.fbm(size, seed, 3, 2.0, 0.5, tile)
    return h, h


def _brick(recipe, size, seed, tile):
    rows = int(recipe.get("rows", 8))
    cols = int(recipe.get("cols", 4))
    mortar_w = max(2, size // 160)
    rnd = random.Random(seed)
    tint = [[rnd.uniform(-0.13, 0.13) for _ in range(cols)] for _ in range(rows)]
    h = _new(size, 0.75)
    mask = _new(size, 0.0)
    grain = noise.fbm(size, seed + 3, 5, 2.0, 0.5, tile)
    rh = size / rows
    cw = size / cols
    for y in range(size):
        r = int(y / rh) % rows
        offset = 0.5 if (r % 2) else 0.0
        for x in range(size):
            xx = (x / cw + offset)
            c = int(xx) % cols
            fx = xx - math.floor(xx)
            fy = (y / rh) - math.floor(y / rh)
            edge_x = min(fx * cw, (1 - fx) * cw)
            edge_y = min(fy * rh, (1 - fy) * rh)
            d = min(edge_x, edge_y)
            i = y * size + x
            if d < mortar_w:
                h[i] = 0.28 + grain[i] * 0.12
                mask[i] = 1.0  # rejunte
            else:
                h[i] = 0.72 + grain[i] * 0.34 + tint[r][c]
                mask[i] = 0.0
    return h, mask


def _wood(recipe, size, seed, tile):
    rings = int(recipe.get("rings", 24))
    warp = noise.fbm(size, seed + 17, 4, 2.0, 0.5, tile)
    h = _new(size)
    grain = noise.fbm(size, seed + 91, 6, 2.4, 0.5, tile)
    for y in range(size):
        v = y / size
        for x in range(size):
            u = x / size
            i = y * size + x
            w = warp[i] * 0.18
            t = (u + w) * rings
            ring = abs((t - math.floor(t)) - 0.5) * 2.0
            ring = ring ** 0.6
            h[i] = _clamp(0.35 + ring * 0.45 + grain[i] * 0.2)
    return h, h


def _brushed(size, seed, tile):
    rnd = random.Random(seed)
    h = _new(size, 0.5)
    streaks = _new(size, 0.5)
    rows_vals = [rnd.gauss(0.5, 0.12) for _ in range(size)]
    fine = noise.fbm(size, seed + 71, 4, 2.0, 0.5, tile)
    for y in range(size):
        base = rows_vals[y]
        for x in range(size):
            i = y * size + x
            h[i] = _clamp(base * 0.6 + 0.2 + fine[i] * 0.25)
            streaks[i] = _clamp(0.5 + (base - 0.5) * 1.6)
    return h, streaks


def _scratched(size, seed, tile):
    rnd = random.Random(seed)
    base = noise.fbm(size, seed + 13, 5, 2.0, 0.5, tile)
    h = _new(size)
    rust_mask = _new(size, 0.0)
    for i in range(size * size):
        h[i] = 0.55 + (base[i] - 0.5) * 0.35
    # arranhões: linhas finas aleatórias
    for _ in range(max(20, size // 6)):
        x0 = rnd.randrange(size)
        y0 = rnd.randrange(size)
        ang = rnd.uniform(0, math.pi)
        length = rnd.randint(size // 12, size // 2)
        dx, dy = math.cos(ang), math.sin(ang)
        depth = rnd.uniform(-0.35, -0.12)
        for s in range(length):
            x = int(x0 + dx * s) % size
            y = int(y0 + dy * s) % size
            i = y * size + x
            h[i] = _clamp(h[i] + depth)
            if s % 3 == 0:
                rust_mask[i] = min(1.0, rust_mask[i] + 0.25)
    # corrosão nas bordas
    cells = 12
    f1, _ = noise.worley(size, seed + 77, cells, tile)
    for i in range(size * size):
        edge = 1.0 - min(f1[i] * cells * 0.5, 1.0)
        rust_mask[i] = _clamp(rust_mask[i] * 0.6 + edge * 0.5)
    return h, rust_mask


def _weave(count, size):
    h = _new(size)
    mask = _new(size)
    step = max(1, size // max(1, count))
    for y in range(size):
        for x in range(size):
            i = y * size + x
            cx = (x // step) % 2
            cy = (y // step) % 2
            fx = (x % step) / step
            fy = (y % step) / step
            bump = math.sin(fx * math.pi) * math.sin(fy * math.pi)
            if (cx + cy) % 2 == 0:
                h[i] = 0.35 + bump * 0.55
            else:
                h[i] = 0.30 + (1 - bump) * 0.4
            mask[i] = bump
    return h, mask


def _grass(recipe, size, seed, tile):
    rnd = random.Random(seed)
    base = noise.fbm(size, seed + 5, 6, 2.0, 0.5, tile)
    h = _new(size)
    mask = _new(size)
    for i in range(size * size):
        h[i] = 0.25 + base[i] * 0.4
    blades = int(recipe.get("blades", 4000))
    for _ in range(blades):
        x0 = rnd.randrange(size)
        y0 = rnd.randrange(size)
        length = rnd.randint(max(3, size // 220), max(6, size // 40))
        bend = rnd.uniform(-0.6, 0.6)
        for s in range(length):
            x = int(x0 + bend * s) % size
            y = (y0 - s) % size
            i = y * size + x
            t = s / length
            val = _clamp(0.55 + (1 - t) * 0.45)
            h[i] = max(h[i], val)
            mask[i] = max(mask[i], 1.0 - t)
    return h, mask


def _ripples(count, size, seed, tile, grain_amt):
    h = _new(size)
    grain = noise.fbm(size, seed + 29, 5, 2.0, 0.5, tile)
    rnd = random.Random(seed)
    for y in range(size):
        v = y / size
        for x in range(size):
            u = x / size
            i = y * size + x
            wave = math.sin((u * count + grain[i] * 1.4) * math.pi * 2) * 0.5 + 0.5
            h[i] = _clamp(0.35 + wave * 0.45 + (rnd.random() - 0.5) * grain_amt * 0.4 + grain[i] * 0.15)
    return h, h


def _cracked(count, size, seed, tile):
    f1, f2 = noise.worley(size, seed + 61, count, tile)
    h = _new(size)
    mask = _new(size)
    rough = noise.fbm(size, seed + 3, 6, 2.0, 0.5, tile)
    for i in range(size * size):
        edge = (f2[i] - f1[i]) * float(count) * 1.6
        edge = min(edge, 1.0)
        h[i] = _clamp(0.30 + edge * 0.65 + (rough[i] - 0.5) * 0.18)
        mask[i] = 1.0 - edge  # 1 nas rachaduras
    return h, mask


def _veins(size, seed, tile):
    ridged = noise.ridged(size, seed + 43, 5, tile)
    soft = noise.fbm(size, seed + 11, 6, 2.0, 0.5, tile)
    h = _new(size)
    mask = _new(size)
    for i in range(size * size):
        v = ridged[i] ** 3.0
        mask[i] = v
        h[i] = _clamp(0.72 - v * 0.35 + (soft[i] - 0.5) * 0.08)
    return h, mask


# ------------------------------------------------------------- geração do set
def _np_pattern_height(recipe, size, seed, tile):
    """Caminho numpy: devolve (height, extra) como arrays float32."""
    import numpy as _np

    pattern = str(recipe.get("pattern", "mottled"))
    octaves = int(recipe.get("octaves", 6))

    def _f(octs=octaves, s=seed, lac=2.0, gain=0.52):
        return noise._np_fbm(size, s, octs, lac, gain, tile).astype(_np.float32)

    def _wor(cells, s=seed + 31):
        f1, f2 = noise._np_worley(size, s, cells, tile)
        return f1.astype(_np.float32), f2.astype(_np.float32)

    if pattern == "mottled":
        h = _f()
        cells = int(recipe.get("worley", 0) or 0)
        if cells:
            f1, f2 = _wor(cells)
            g = _np.random.default_rng(seed + 7).random((size, size), dtype=_np.float32)
            grain = float(recipe.get("grain", 0.0) or 0.0)
            pore = 1.0 - _np.minimum(f1 * cells * 2.2, 1.0)
            crack = 1.0 - _np.minimum((f2 - f1) * cells * 3.0, 1.0)
            out = _np.clip(h * 0.62 + pore * 0.22 + crack * 0.16 + g * grain, 0, 1)
            return out, out
        return h, h

    if pattern == "cells":
        cells = int(recipe.get("cells", 24))
        f1, _ = _wor(cells, seed + 5)
        d = _np.minimum(f1 * cells * 0.35, 1.0)
        return _np.clip(0.25 + d * 0.75, 0, 1), 1.0 - _np.minimum(f1 * cells * 1.4, 1.0)

    if pattern == "cracked":
        cells = int(recipe.get("cracks", 14))
        f1, f2 = _wor(cells, seed + 61)
        rough = _f(6, seed + 3)
        edge = _np.minimum((f2 - f1) * cells * 1.6, 1.0)
        h = _np.clip(0.30 + edge * 0.65 + (rough - 0.5) * 0.18, 0, 1)
        return h, 1.0 - edge

    if pattern == "veins":
        r = noise._np_fbm(size, seed + 43, 5, 2.0, 0.5, tile, ridged=True).astype(_np.float32)
        soft = _f(6, seed + 11)
        v = r ** 3.0
        return _np.clip(0.72 - v * 0.35 + (soft - 0.5) * 0.08, 0, 1), v

    if pattern == "wood":
        rings = int(recipe.get("rings", 24))
        warp = _f(4, seed + 17)
        grain = _f(6, seed + 91, 2.4, 0.5)
        y, x = _np.mgrid[0:size, 0:size].astype(_np.float32)
        u = x / size
        t = (u + warp * 0.18) * rings
        ring = _np.abs((t - _np.floor(t)) - 0.5) * 2.0
        ring = ring ** 0.6
        h = _np.clip(0.35 + ring * 0.45 + grain * 0.2, 0, 1)
        return h, h

    if pattern == "brushed":
        rnd = _np.random.default_rng(seed)
        rows = rnd.normal(0.5, 0.12, size).astype(_np.float32)[:, None]
        fine = _f(4, seed + 71)
        h = _np.clip(rows * 0.6 + 0.2 + fine * 0.25, 0, 1)
        streaks = _np.clip(0.5 + (rows - 0.5) * 1.6, 0, 1) * _np.ones((1, size), dtype=_np.float32)
        return h, streaks

    if pattern == "ripples":
        count = int(recipe.get("ripples", 20))
        grain_amt = float(recipe.get("grain", 0.1))
        g = _f(5, seed + 29)
        y, x = _np.mgrid[0:size, 0:size].astype(_np.float32)
        u = x / size
        wave = _np.sin((u * count + g * 1.4) * _np.pi * 2) * 0.5 + 0.5
        rnd = _np.random.default_rng(seed + 5).random((size, size), dtype=_np.float32)
        h = _np.clip(0.35 + wave * 0.45 + (rnd - 0.5) * grain_amt * 0.4 + g * 0.15, 0, 1)
        return h, h

    if pattern == "weave":
        count = int(recipe.get("weave", 64))
        step = max(1, size // max(1, count))
        y, x = _np.mgrid[0:size, 0:size].astype(_np.int32)
        cx = (x // step) % 2
        cy = (y // step) % 2
        fx = ((x % step) / step).astype(_np.float32)
        fy = ((y % step) / step).astype(_np.float32)
        bump = _np.sin(fx * _np.pi) * _np.sin(fy * _np.pi)
        parity = (cx + cy) % 2 == 0
        h = _np.where(parity, 0.35 + bump * 0.55, 0.30 + (1 - bump) * 0.4).astype(_np.float32)
        return h, bump

    if pattern == "blades":
        base = _f(6, seed + 5)
        h = 0.25 + base * 0.4
        mask = _np.zeros((size, size), dtype=_np.float32)
        rnd = random.Random(seed)
        blades = int(recipe.get("blades", 4000))
        for _ in range(blades):
            x0 = rnd.randrange(size)
            y0 = rnd.randrange(size)
            length = rnd.randint(max(3, size // 220), max(6, size // 40))
            bend = rnd.uniform(-0.6, 0.6)
            xs, ys, vs, ms = [], [], [], []
            for s in range(length):
                t = s / length
                xs.append((int(x0 + bend * s)) % size)
                ys.append((y0 - s) % size)
                vs.append(_clamp(0.55 + (1 - t) * 0.45))
                ms.append(1.0 - t)
            h[ys, xs] = _np.maximum(h[ys, xs], _np.array(vs, dtype=_np.float32))
            mask[ys, xs] = _np.maximum(mask[ys, xs], _np.array(ms, dtype=_np.float32))
        return _np.clip(h, 0, 1), mask

    if pattern == "brick":
        rows = int(recipe.get("rows", 8))
        cols = int(recipe.get("cols", 4))
        mortar_w = max(2, size // 160)
        rnd = _np.random.default_rng(seed)
        grain = _f(5, seed + 3)
        y, x = _np.mgrid[0:size, 0:size].astype(_np.float32)
        rh = size / rows
        cw = size / cols
        r_idx = (y // rh).astype(_np.int32) % rows
        offset = _np.where(r_idx % 2 == 1, 0.5, 0.0)
        xx = x / cw + offset
        c_idx = _np.floor(xx).astype(_np.int32) % cols
        fx = xx - _np.floor(xx)
        fy = y / rh - _np.floor(y / rh)
        edge_x = _np.minimum(fx * cw, (1 - fx) * cw)
        edge_y = _np.minimum(fy * rh, (1 - fy) * rh)
        d = _np.minimum(edge_x, edge_y)
        is_mortar = d < mortar_w
        tint = rnd.uniform(-0.13, 0.13, (rows, cols)).astype(_np.float32)
        h = _np.where(is_mortar, 0.28 + grain * 0.12, 0.72 + grain * 0.34 + tint[r_idx, c_idx])
        return _np.clip(h, 0, 1).astype(_np.float32), is_mortar.astype(_np.float32)

    if pattern == "scratched":
        base = _f(5, seed + 13)
        h = 0.55 + (base - 0.5) * 0.35
        rust_mask = _np.zeros((size, size), dtype=_np.float32)
        rnd = random.Random(seed)
        for _ in range(max(20, size // 6)):
            x0 = rnd.randrange(size)
            y0 = rnd.randrange(size)
            ang = rnd.uniform(0, math.pi)
            length = rnd.randint(size // 12, size // 2)
            dx, dy = math.cos(ang), math.sin(ang)
            depth = rnd.uniform(-0.35, -0.12)
            s = _np.arange(length, dtype=_np.float32)
            xs = ((x0 + dx * s).astype(_np.int32)) % size
            ys = ((y0 + dy * s).astype(_np.int32)) % size
            h[ys, xs] = _np.clip(h[ys, xs] + depth, 0, 1)
            sub = (s % 3 == 0)
            rust_mask[ys[sub], xs[sub]] = _np.minimum(1.0, rust_mask[ys[sub], xs[sub]] + 0.25)
        f1, _ = _wor(12, seed + 77)
        edge = 1.0 - _np.minimum(f1 * 12 * 0.5, 1.0)
        rust_mask = _np.clip(rust_mask * 0.6 + edge * 0.5, 0, 1)
        return _np.clip(h, 0, 1).astype(_np.float32), rust_mask

    # smooth
    h = _f(3)
    return h, h


def _np_srgb(c):
    import numpy as _np
    c = _np.clip(c, 0.0, 1.0)
    return _np.where(c <= 0.0031308, 12.92 * c, 1.055 * _np.power(_np.maximum(c, 1e-6), 1.0 / 2.4) - 0.055)


def _np_normal(height, strength=2.5):
    import numpy as _np
    dx = (_np.roll(height, -1, axis=1) - _np.roll(height, 1, axis=1)) * strength
    dy = (_np.roll(height, -1, axis=0) - _np.roll(height, 1, axis=0)) * strength
    nz = _np.ones_like(dx)
    n = _np.sqrt(dx * dx + dy * dy + nz * nz)
    r = (-dx / n) * 0.5 + 0.5
    g = (-dy / n) * 0.5 + 0.5
    b = (nz / n) * 0.5 + 0.5
    return _np.stack([r, g, b], axis=2)


def generate_pbr_set(
    material: str = "stone",
    resolution: str = "2k",
    seed: int = 1337,
    tile: bool = True,
    channels: Optional[Sequence[str]] = None,
    tint: Optional[Tuple[float, float, float]] = None,
    max_size: int = 16384,
) -> PbrSet:
    """Gera o conjunto completo de mapas PBR de um material procedural."""
    import time

    t0 = time.time()
    recipe = dict(MATERIALS.get(material) or MATERIALS["generic"])
    size = min(resolution_px(resolution), max_size)

    base_color = tuple(tint) if tint else tuple(recipe.get("base", (0.6, 0.6, 0.62)))
    rough_base = float(recipe.get("rough", 0.7))
    metal_base = float(recipe.get("metal", 0.0))
    ao_strength = float(recipe.get("ao_strength", 0.4))
    hs = float(recipe.get("height_scale", 0.6))
    rust = float(recipe.get("rust", 0.0) or 0.0)
    pattern = str(recipe.get("pattern", "mottled"))
    mortar = recipe.get("mortar")
    emit = recipe.get("emissive")
    emit_kind = str(recipe.get("emissive_mask", ""))

    if HAS_NUMPY:
        pngs = _generate_numpy(
            recipe, size, seed, tile, pattern, base_color, rough_base, metal_base,
            ao_strength, hs, rust, mortar, emit, emit_kind,
        )
    else:
        pngs = _generate_pure(
            recipe, size, seed, tile, pattern, base_color, rough_base, metal_base,
            ao_strength, hs, rust, mortar, emit, emit_kind,
        )

    wanted = [c.lower() for c in (channels or ["albedo", "normal", "roughness", "metallic", "ao", "height"])]
    canon = {"basecolor": "albedo", "ambientocclusion": "ao", "displacement": "height"}
    spaces = {"albedo": "sRGB", "emissive": "sRGB", "normal": "linear",
              "roughness": "linear", "metallic": "linear", "ao": "linear", "height": "linear"}

    pbr = PbrSet(material=material, resolution=f"{size}px", size=size)
    for ch in wanted:
        key = canon.get(ch, ch)
        if key not in pngs or pngs[key] is None:
            continue
        png = pngs[key]
        if isinstance(png, tuple):  # (dados, modo)
            data, mode = png
            png = encode_rgb(data, size, size) if mode == "rgb" else encode_gray(data, size, size)
        pbr.maps.append(PbrMap(channel=key, width=size, height=size, png=png, color_space=spaces.get(key, "linear")))

    pbr.material_def = {
        "name": f"{recipe.get('label', material).replace(' ', '_')}_ArkherPBR",
        "albedo_tint": [round(float(v), 4) for v in base_color],
        "metallic": metal_base,
        "roughness": rough_base,
        "normal_scale": 1.0,
        "emissive": list(emit) if emit else None,
        "subsurface": recipe.get("subsurface"),
        "tileable": bool(tile),
        "seed": seed,
        "pattern": pattern,
    }
    pbr.stats = {
        "size": size,
        "megapixels": round(size * size / 1_000_000, 2),
        "maps": [m.channel for m in pbr.maps],
        "bytes": sum(len(m.png) for m in pbr.maps),
        "pattern": pattern,
        "engine_numpy": HAS_NUMPY,
        "seconds": round(time.time() - t0, 2),
    }
    return pbr


def _np_fine_noise(size: int, seed: int, tile: bool):
    """Ruído de alta frequência + grão por pixel (detalhe microscópico)."""
    import numpy as _np
    grid = max(8, size // 8)
    fine = noise._np_lattice(size, grid, seed + 555, tile).astype(_np.float32)
    micro = _np.random.default_rng(seed + 66).random((size, size), dtype=_np.float32)
    return _np.clip(fine * 0.6 + micro * 0.4, 0.0, 1.0)


def _generate_numpy(recipe, size, seed, tile, pattern, base_color, rough_base, metal_base,
                    ao_strength, hs, rust, mortar, emit, emit_kind):
    import numpy as _np

    import numpy as _np
    h, extra = _np_pattern_height(recipe, size, seed, tile)
    h = h.astype(_np.float32)
    extra = extra.astype(_np.float32)
    contrast = float(recipe.get("contrast", 1.7))
    if pattern != "brick":
        h = _np.clip(0.5 + (h - 0.5) * contrast, 0.0, 1.0)

    fine = _np_fine_noise(size, seed, tile)
    shade = (0.58 + h * 0.72) * (0.88 + fine * 0.24)
    r = _np.full_like(h, base_color[0]) * shade
    g = _np.full_like(h, base_color[1]) * shade
    b = _np.full_like(h, base_color[2]) * shade

    if pattern == "brick" and mortar is not None:
        m = extra > 0.5
        r = _np.where(m, mortar[0] * shade, r)
        g = _np.where(m, mortar[1] * shade, g)
        b = _np.where(m, mortar[2] * shade, b)
    if pattern == "veins":
        vc = recipe.get("vein_color", (0.3, 0.3, 0.33))
        t = extra
        r = r * (1 - t) + vc[0] * t
        g = g * (1 - t) + vc[1] * t
        b = b * (1 - t) + vc[2] * t

    rough = _np.clip(rough_base + (0.5 - h) * 0.30, 0, 1)
    metal = _np.full_like(h, metal_base)
    if rust > 0:
        t = extra * rust
        r = r * (1 - t) + 0.45 * t
        g = g * (1 - t) + 0.24 * t
        b = b * (1 - t) + 0.13 * t
        rough = _np.clip(rough + extra * rust * 0.8, 0, 1)
        metal = metal_base * (1.0 - _np.minimum(extra * rust * 2.2, 1.0))

    ao = _np.clip(1.0 - (1.0 - h) * ao_strength, 0, 1)
    if pattern == "brick":
        ao = _np.where(extra > 0.5, ao * 0.85, ao)

    height_map = _np.clip(h * hs + (1 - hs) * 0.5, 0, 1)
    normal = _np_normal(height_map)

    def _u8rgb(arr):
        return (_np.clip(arr, 0, 1) * 255.0 + 0.5).astype(_np.uint8).tobytes()

    out = {
        "albedo": (_u8rgb(_np.stack([_np_srgb(r), _np_srgb(g), _np_srgb(b)], axis=2)), "rgb"),
        "normal": encode_rgb(_u8rgb(normal), size, size),
        "roughness": ((_np.clip(rough, 0, 1) * 255 + 0.5).astype(_np.uint8).tobytes(), "gray"),
        "metallic": ((_np.clip(metal, 0, 1) * 255 + 0.5).astype(_np.uint8).tobytes(), "gray"),
        "ao": ((_np.clip(ao, 0, 1) * 255 + 0.5).astype(_np.uint8).tobytes(), "gray"),
        "height": ((_np.clip(height_map, 0, 1) * 255 + 0.5).astype(_np.uint8).tobytes(), "gray"),
    }
    if emit:
        m = extra if emit_kind == "cracks" else (1.0 - extra)
        m = _np.clip(m, 0, 1)
        out["emissive"] = (
            _u8rgb(_np.stack([_np_srgb(emit[0] * m), _np_srgb(emit[1] * m), _np_srgb(emit[2] * m)], axis=2)),
            "rgb",
        )
    return out


def _py_fine_noise(size: int, seed: int, tile: bool):
    grid = max(8, size // 8)
    fine = noise._py_lattice(size, grid, seed + 555, tile)
    rnd = random.Random(seed + 66)
    out = array("f", bytes(4 * size * size))
    for i in range(size * size):
        out[i] = fine[i] * 0.6 + rnd.random() * 0.4
    return out


def _generate_pure(recipe, size, seed, tile, pattern, base_color, rough_base, metal_base,
                   ao_strength, hs, rust, mortar, emit, emit_kind):
    height, extra = _pattern_height(recipe, size, seed, tile)
    contrast = float(recipe.get("contrast", 1.7))
    if pattern != "brick":
        for i in range(len(height)):
            height[i] = _clamp(0.5 + (height[i] - 0.5) * contrast)
    fine = _py_fine_noise(size, seed, tile)
    n = size * size
    albedo = bytearray(n * 3)
    rough = bytearray(n)
    metal = bytearray(n)
    ao = bytearray(n)
    hgt_f = array("f", bytes(4 * n))
    emit_buf = bytearray(n * 3) if emit else None

    br, bg, bb = base_color
    for i in range(n):
        h = height[i]
        ex = extra[i]
        shade = (0.58 + h * 0.72) * (0.88 + fine[i] * 0.24)
        r, g, b = br * shade, bg * shade, bb * shade
        if pattern == "brick" and mortar is not None and ex > 0.5:
            r, g, b = mortar[0] * shade, mortar[1] * shade, mortar[2] * shade
        elif pattern == "veins":
            vc = recipe.get("vein_color", (0.3, 0.3, 0.33))
            r = r * (1 - ex) + vc[0] * ex
            g = g * (1 - ex) + vc[1] * ex
            b = b * (1 - ex) + vc[2] * ex
        rr = _clamp(rough_base + (0.5 - h) * 0.30)
        mm = metal_base
        if rust > 0.0:
            t = ex * rust
            r = r * (1 - t) + 0.45 * t
            g = g * (1 - t) + 0.24 * t
            b = b * (1 - t) + 0.13 * t
            rr = _clamp(rr + ex * rust * 0.8)
            mm = metal_base * (1.0 - min(ex * rust * 2.2, 1.0))
        a = _clamp(1.0 - (1.0 - h) * ao_strength)
        if pattern == "brick" and ex > 0.5:
            a = _clamp(a * 0.85)
        hf = _clamp(h * hs + (1 - hs) * 0.5)
        hgt_f[i] = hf
        j = i * 3
        albedo[j] = int(_lin_to_srgb(r) * 255.0 + 0.5)
        albedo[j + 1] = int(_lin_to_srgb(g) * 255.0 + 0.5)
        albedo[j + 2] = int(_lin_to_srgb(b) * 255.0 + 0.5)
        rough[i] = int(rr * 255.0 + 0.5)
        metal[i] = int(mm * 255.0 + 0.5)
        ao[i] = int(a * 255.0 + 0.5)
        if emit_buf is not None:
            m = _clamp(ex if emit_kind == "cracks" else 1.0 - ex)
            emit_buf[j] = int(_lin_to_srgb(emit[0] * m) * 255.0 + 0.5)
            emit_buf[j + 1] = int(_lin_to_srgb(emit[1] * m) * 255.0 + 0.5)
            emit_buf[j + 2] = int(_lin_to_srgb(emit[2] * m) * 255.0 + 0.5)

    nr, ng, nb = noise.height_to_normal_rgb(hgt_f, size, strength=2.5)
    normal = bytearray(n * 3)
    normal[0::3] = bytes(nr)
    normal[1::3] = bytes(ng)
    normal[2::3] = bytes(nb)

    out = {
        "albedo": (bytes(albedo), "rgb"),
        "normal": encode_rgb(bytes(normal), size, size),
        "roughness": (bytes(rough), "gray"),
        "metallic": (bytes(metal), "gray"),
        "ao": (bytes(ao), "gray"),
        "height": (bytes(bytearray(int(_clamp(v) * 255 + 0.5) for v in hgt_f)), "gray"),
    }
    if emit_buf is not None:
        out["emissive"] = (bytes(emit_buf), "rgb")
    return out

"""
Geração de malhas 3D em Python puro (sem Blender, sem trimesh, sem numpy).

Cada primitiva devolve `MeshData` com POSITION + NORMAL + TEXCOORD_0 + índices,
pronta para o writer .glb. Também monta modelos compostos (herói, criatura,
árvore, pedra, espada, casa, terreno) e gera LODs por decimação de vértices.

Todas as malhas são authorizadas em Y-up (padrão glTF) e em metros.
"""
from __future__ import annotations

import math
import random
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Tuple

from . import math3d as m3d
from .glb import Material, MeshData

__all__ = [
    "Part", "merge_parts", "plane", "box", "uv_sphere", "cylinder", "cone",
    "capsule", "torus", "terrain", "make_model", "generate_lods", "MODEL_TYPES",
]


@dataclass
class Part:
    positions: List[float]
    normals: List[float]
    uvs: List[float]
    indices: List[int]
    name: str = "part"


def _xform_positions(positions: Sequence[float], matrix: Sequence[float]) -> List[float]:
    out: List[float] = []
    for i in range(0, len(positions), 3):
        p = m3d.transform_point(matrix, (positions[i], positions[i + 1], positions[i + 2]))
        out.extend(p)
    return out


def _xform_normals(normals: Sequence[float], matrix: Sequence[float]) -> List[float]:
    rot = [matrix[0], matrix[1], matrix[2], matrix[4], matrix[5], matrix[6], matrix[8], matrix[9], matrix[10]]
    out: List[float] = []
    for i in range(0, len(normals), 3):
        x, y, z = normals[i], normals[i + 1], normals[i + 2]
        nx = rot[0] * x + rot[3] * y + rot[6] * z
        ny = rot[1] * x + rot[4] * y + rot[7] * z
        nz = rot[2] * x + rot[5] * y + rot[8] * z
        n = m3d.normalize((nx, ny, nz))
        out.extend(n)
    return out


def merge_parts(parts: Sequence[Part], name: str = "model") -> MeshData:
    positions: List[float] = []
    normals: List[float] = []
    uvs: List[float] = []
    indices: List[int] = []
    offset = 0
    for p in parts:
        positions.extend(p.positions)
        normals.extend(p.normals)
        uvs.extend(p.uvs)
        indices.extend(i + offset for i in p.indices)
        offset += len(p.positions) // 3
    return MeshData(name=name, positions=positions, normals=normals, uvs=uvs, indices=indices)


def _part_from(
    verts: Sequence[Tuple[float, float, float]],
    faces: Sequence[Sequence[int]],
    uvs: Optional[Sequence[Tuple[float, float]]] = None,
    smooth: bool = False,
    matrix: Optional[Sequence[float]] = None,
    name: str = "part",
) -> Part:
    """Constrói uma Part calculando normais (flat ou smooth)."""
    positions: List[float] = []
    normals: List[float] = []
    uv_list: List[float] = []
    indices: List[int] = []

    if smooth:
        positions = [c for v in verts for c in v]
        nacc = [[0.0, 0.0, 0.0] for _ in verts]
        for f in faces:
            for k in range(1, len(f) - 1):
                a, b, c = f[0], f[k], f[k + 1]
                va, vb, vc = verts[a], verts[b], verts[c]
                fn = m3d.cross(m3d.sub(vb, va), m3d.sub(vc, va))
                for idx in (a, b, c):
                    nacc[idx][0] += fn[0]
                    nacc[idx][1] += fn[1]
                    nacc[idx][2] += fn[2]
        normals = [c for n in nacc for c in (m3d.normalize(n) or (0.0, 1.0, 0.0))]
        if uvs is None:
            uv_list = _spherical_uvs(verts)
        else:
            uv_list = [c for uv in uvs for c in uv]
        for f in faces:
            for k in range(1, len(f) - 1):
                indices.extend((f[0], f[k], f[k + 1]))
    else:
        # um vértice por face-corner -> normal flat
        if uvs is None:
            uvs = _spherical_uvs(verts)
        for f in faces:
            for k in range(1, len(f) - 1):
                tri = (f[0], f[k], f[k + 1])
                va, vb, vc = verts[tri[0]], verts[tri[1]], verts[tri[2]]
                fn = m3d.normalize(m3d.cross(m3d.sub(vb, va), m3d.sub(vc, va)))
                base = len(positions) // 3
                for t in tri:
                    positions.extend(verts[t])
                    normals.extend(fn)
                    uv_list.extend(uvs[t])
                indices.extend((base, base + 1, base + 2))

    if matrix is not None:
        positions = _xform_positions(positions, matrix)
        normals = _xform_normals(normals, matrix)

    return Part(positions, normals, uv_list, indices, name)


def _spherical_uvs(verts: Sequence[Tuple[float, float, float]]) -> List[Tuple[float, float]]:
    out = []
    for (x, y, z) in verts:
        n = math.sqrt(x * x + y * y + z * z) or 1.0
        u = 0.5 + math.atan2(z, x) / (2.0 * math.pi)
        v = 0.5 - math.asin(max(-1.0, min(1.0, y / n))) / math.pi
        out.append((u, v))
    return out


# =============================================================== primitivas
def plane(size: float = 10.0, segments: int = 1, matrix=None, name: str = "plane") -> Part:
    h = size * 0.5
    verts: List[Tuple[float, float, float]] = []
    uvs: List[Tuple[float, float]] = []
    for j in range(segments + 1):
        for i in range(segments + 1):
            u = i / segments
            v = j / segments
            verts.append((-h + u * size, 0.0, -h + v * size))
            uvs.append((u, v))
    faces = []
    for j in range(segments):
        for i in range(segments):
            a = j * (segments + 1) + i
            b = a + 1
            c = a + segments + 1
            d = c + 1
            faces.append((a, c, b))
            faces.append((b, c, d))
    return _part_from(verts, faces, uvs, smooth=True, matrix=matrix, name=name)


def box(
    w: float = 1.0, h: float = 1.0, d: float = 1.0,
    center: Tuple[float, float, float] = (0.0, 0.0, 0.0),
    matrix=None, name: str = "box",
) -> Part:
    x0, y0, z0 = center[0] - w / 2, center[1] - h / 2, center[2] - d / 2
    x1, y1, z1 = x0 + w, y0 + h, z0 + d
    verts = [
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),  # -Z
        (x1, y0, z1), (x0, y0, z1), (x0, y1, z1), (x1, y1, z1),  # +Z
        (x0, y0, z1), (x1, y0, z1), (x1, y0, z0), (x0, y0, z0),  # -Y
        (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1),  # +Y
        (x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1),  # +X
        (x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0),  # -X
    ]
    uvs = [(0, 0), (1, 0), (1, 1), (0, 1)] * 6
    faces = []
    for f in range(6):
        b = f * 4
        faces.append((b, b + 1, b + 2))
        faces.append((b, b + 2, b + 3))
    return _part_from(verts, faces, uvs, smooth=False, matrix=matrix, name=name)


def uv_sphere(
    radius: float = 0.5, rings: int = 18, sectors: int = 28,
    center: Tuple[float, float, float] = (0.0, 0.0, 0.0),
    matrix=None, name: str = "sphere", squash: Tuple[float, float, float] = (1.0, 1.0, 1.0),
) -> Part:
    verts: List[Tuple[float, float, float]] = []
    uvs: List[Tuple[float, float]] = []
    for r in range(rings + 1):
        phi = math.pi * r / rings
        for s in range(sectors + 1):
            theta = 2.0 * math.pi * s / sectors
            x = math.sin(phi) * math.cos(theta)
            y = math.cos(phi)
            z = math.sin(phi) * math.sin(theta)
            verts.append((center[0] + x * radius * squash[0], center[1] + y * radius * squash[1], center[2] + z * radius * squash[2]))
            uvs.append((s / sectors, 1.0 - r / rings))
    faces = []
    for r in range(rings):
        for s in range(sectors):
            a = r * (sectors + 1) + s
            b = a + sectors + 1
            if r != 0:
                faces.append((a, b, a + 1))
            if r != rings - 1:
                faces.append((a + 1, b, b + 1))
    return _part_from(verts, faces, uvs, smooth=True, matrix=matrix, name=name)


def cylinder(
    radius: float = 0.5, height: float = 1.0, sectors: int = 24,
    center: Tuple[float, float, float] = (0.0, 0.0, 0.0),
    caps: bool = True, matrix=None, name: str = "cylinder",
    radius_top: Optional[float] = None,
) -> Part:
    rt = radius if radius_top is None else radius_top
    verts: List[Tuple[float, float, float]] = []
    uvs: List[Tuple[float, float]] = []
    faces: List[Tuple[int, ...]] = []
    hy = height / 2.0
    cx, cy, cz = center
    for i in range(sectors + 1):
        theta = 2.0 * math.pi * i / sectors
        c, s = math.cos(theta), math.sin(theta)
        u = i / sectors
        verts.append((cx + radius * c, cy - hy, cz + radius * s)); uvs.append((u, 0.0))
        verts.append((cx + rt * c, cy + hy, cz + rt * s)); uvs.append((u, 1.0))
    for i in range(sectors):
        a = i * 2
        faces.append((a, a + 2, a + 3))
        faces.append((a, a + 3, a + 1))
    if caps:
        for (yy, rr, up) in ((-hy, radius, False), (hy, rt, True)):
            base = len(verts)
            verts.append((cx, cy + yy, cz)); uvs.append((0.5, 0.5))
            for i in range(sectors):
                theta = 2.0 * math.pi * i / sectors
                verts.append((cx + rr * math.cos(theta), cy + yy, cz + rr * math.sin(theta)))
                uvs.append((0.5 + 0.5 * math.cos(theta), 0.5 + 0.5 * math.sin(theta)))
            for i in range(sectors):
                p = base + 1 + i
                q = base + 1 + ((i + 1) % sectors)
                faces.append((base, q, p) if up else (base, p, q))
    return _part_from(verts, faces, uvs, smooth=False, matrix=matrix, name=name)


def cone(radius: float = 0.5, height: float = 1.0, sectors: int = 20,
         center: Tuple[float, float, float] = (0, 0, 0), matrix=None, name: str = "cone") -> Part:
    return cylinder(radius, height, sectors, center, caps=True, matrix=matrix, name=name, radius_top=0.0)


def capsule(radius: float = 0.25, height: float = 1.0, rings: int = 8, sectors: int = 20,
            center: Tuple[float, float, float] = (0, 0, 0), matrix=None, name: str = "capsule") -> Part:
    cyl_h = max(0.0, height - 2 * radius)
    parts = [
        cylinder(radius, cyl_h, sectors, (center[0], center[1], center[2]), caps=False, name=name + "_c"),
        uv_sphere(radius, rings, sectors, (center[0], center[1] + cyl_h / 2, center[2]), name=name + "_t"),
        uv_sphere(radius, rings, sectors, (center[0], center[1] - cyl_h / 2, center[2]), name=name + "_b"),
    ]
    m = merge_parts(parts, name)
    if matrix is not None:
        m.positions = _xform_positions(m.positions, matrix)
        m.normals = _xform_normals(m.normals, matrix)
    return Part(m.positions, m.normals, m.uvs, m.indices, name)


def torus(radius: float = 0.5, tube: float = 0.16, rings: int = 20, sectors: int = 28,
          matrix=None, name: str = "torus") -> Part:
    verts: List[Tuple[float, float, float]] = []
    uvs: List[Tuple[float, float]] = []
    for i in range(rings + 1):
        u = 2 * math.pi * i / rings
        for j in range(sectors + 1):
            v = 2 * math.pi * j / sectors
            x = (radius + tube * math.cos(v)) * math.cos(u)
            y = tube * math.sin(v)
            z = (radius + tube * math.cos(v)) * math.sin(u)
            verts.append((x, y, z))
            uvs.append((i / rings, j / sectors))
    faces = []
    for i in range(rings):
        for j in range(sectors):
            a = i * (sectors + 1) + j
            b = a + sectors + 1
            faces.append((a, b, a + 1))
            faces.append((a + 1, b, b + 1))
    return _part_from(verts, faces, uvs, smooth=True, matrix=matrix, name=name)


def terrain(size: float = 40.0, segments: int = 48, amplitude: float = 3.0,
            seed: int = 7, matrix=None, name: str = "terrain") -> Part:
    part = plane(size, segments, name=name)
    rnd = random.Random(seed)
    grid = [[rnd.random() for _ in range(9)] for _ in range(9)]
    positions = part.positions
    for i in range(0, len(positions), 3):
        x = positions[i] / size + 0.5
        z = positions[i + 2] / size + 0.5
        positions[i + 1] = _sample_grid(grid, x, z) * amplitude
    # recalcula normais
    return _recompute_normals(part, name)


def _sample_grid(grid: List[List[float]], u: float, v: float) -> float:
    n = len(grid) - 1
    total = 0.0
    amp = 1.0
    norm = 0.0
    for oct_ in range(3):
        scale = 2 ** oct_
        x = min(max(u * n * scale, 0.0), n)
        y = min(max(v * n * scale, 0.0), n)
        xi, yi = int(x), int(y)
        xi2 = min(xi + 1, n)
        yi2 = min(yi + 1, n)
        fx = x - xi
        fy = y - yi
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        v00 = grid[yi][xi] % 1.0
        v10 = grid[yi][xi2] % 1.0
        v01 = grid[yi2][xi] % 1.0
        v11 = grid[yi2][xi2] % 1.0
        top = v00 + (v10 - v00) * fx
        bot = v01 + (v11 - v01) * fx
        total += (top + (bot - top) * fy) * amp
        norm += amp
        amp *= 0.5
    return (total / norm) * 2.0 - 1.0


def _recompute_normals(part: Part, name: str = "part") -> Part:
    n_verts = len(part.positions) // 3
    acc = [[0.0, 0.0, 0.0] for _ in range(n_verts)]
    idx = part.indices
    for t in range(0, len(idx), 3):
        a, b, c = idx[t], idx[t + 1], idx[t + 2]
        pa = part.positions[a * 3 : a * 3 + 3]
        pb = part.positions[b * 3 : b * 3 + 3]
        pc = part.positions[c * 3 : c * 3 + 3]
        fn = m3d.cross(m3d.sub(tuple(pb), tuple(pa)), m3d.sub(tuple(pc), tuple(pa)))  # type: ignore[arg-type]
        for v in (a, b, c):
            acc[v][0] += fn[0]
            acc[v][1] += fn[1]
            acc[v][2] += fn[2]
    normals: List[float] = []
    for n in acc:
        normals.extend(m3d.normalize(n) or (0.0, 1.0, 0.0))
    return Part(part.positions, normals, part.uvs, part.indices, name)


# ================================================== modelos compostos
def _humanoid(detail: int = 2, seed: int = 11) -> List[Part]:
    d = max(1, detail)
    rings, sectors = 8 + d * 4, 12 + d * 6
    parts: List[Part] = []
    T = m3d.translation
    parts.append(uv_sphere(0.115, rings, sectors, (0, 1.62, 0), name="head", squash=(0.92, 1.12, 0.98)))
    parts.append(cylinder(0.055, 0.1, sectors, (0, 1.5, 0), name="neck"))
    # torso: caixa levemente afunilada + peitoral
    parts.append(box(0.42, 0.34, 0.24, (0, 1.28, 0), name="chest"))
    parts.append(box(0.36, 0.26, 0.22, (0, 0.99, 0), name="abdomen"))
    parts.append(box(0.40, 0.16, 0.23, (0, 0.86, 0), name="hips"))
    for s in (1, -1):
        # ombro + braço + antebraço + mão
        parts.append(uv_sphere(0.075, rings // 2, sectors // 2, (0.245 * s, 1.42, 0), name=f"shoulder_{s}"))
        parts.append(capsule(0.055, 0.30, rings // 2, sectors // 2, (0.27 * s, 1.24, 0), name=f"upperarm_{s}"))
        parts.append(capsule(0.048, 0.28, rings // 2, sectors // 2, (0.27 * s, 0.95, 0), name=f"forearm_{s}"))
        parts.append(box(0.07, 0.11, 0.045, (0.27 * s, 0.78, 0), name=f"hand_{s}"))
        # perna + pé
        parts.append(capsule(0.085, 0.44, rings // 2, sectors // 2, (0.115 * s, 0.60, 0), name=f"thigh_{s}"))
        parts.append(capsule(0.065, 0.42, rings // 2, sectors // 2, (0.115 * s, 0.22, 0), name=f"calf_{s}"))
        parts.append(box(0.10, 0.07, 0.26, (0.115 * s, 0.035, 0.05), name=f"foot_{s}"))
    return parts


def _creature(detail: int = 2, seed: int = 5) -> List[Part]:
    rings, sectors = 8 + detail * 3, 12 + detail * 5
    parts = [
        uv_sphere(0.42, rings, sectors, (0, 0.75, 0), name="body", squash=(1.0, 0.85, 1.35)),
        uv_sphere(0.24, rings, sectors, (0, 0.95, 0.62), name="head", squash=(1.0, 0.95, 1.1)),
        cone(0.07, 0.22, 10, (0.1, 1.12, 0.6), name="horn_l"),
        cone(0.07, 0.22, 10, (-0.1, 1.12, 0.6), name="horn_r"),
    ]
    for s in (1, -1):
        parts.append(capsule(0.09, 0.5, 6, 12, (0.32 * s, 0.45, 0.25), name=f"leg_front_{s}"))
        parts.append(capsule(0.09, 0.5, 6, 12, (0.3 * s, 0.45, -0.3), name=f"leg_back_{s}"))
    parts.append(capsule(0.05, 0.7, 6, 10, (0, 0.85, -0.72), name="tail"))
    return parts


def _tree(detail: int = 2, seed: int = 3) -> List[Part]:
    parts = [
        cylinder(0.16, 2.2, 10 + detail * 4, (0, 1.1, 0), name="trunk", radius_top=0.11),
        uv_sphere(0.95, 10 + detail * 4, 14 + detail * 5, (0, 2.6, 0), name="foliage_a", squash=(1.0, 0.85, 1.0)),
        uv_sphere(0.62, 8 + detail * 3, 12 + detail * 4, (0.5, 2.35, 0.2), name="foliage_b"),
        uv_sphere(0.55, 8 + detail * 3, 12 + detail * 4, (-0.45, 2.45, -0.25), name="foliage_c"),
    ]
    return parts


def _rock(detail: int = 2, seed: int = 42) -> List[Part]:
    rnd = random.Random(seed)
    part = uv_sphere(0.8, 10 + detail * 6, 14 + detail * 8, (0, 0.35, 0), name="rock")
    positions = part.positions
    for i in range(0, len(positions), 3):
        x, y, z = positions[i], positions[i + 1], positions[i + 2]
        n = rnd.uniform(0.82, 1.18)
        positions[i] = x * n
        positions[i + 1] = 0.35 + (y - 0.35) * rnd.uniform(0.7, 1.15)
        positions[i + 2] = z * n
    return [_recompute_normals(part, "rock")]


def _sword(detail: int = 2, seed: int = 1) -> List[Part]:
    return [
        box(0.05, 0.012, 0.95, (0, 0, 0.55), name="blade"),
        box(0.028, 0.012, 0.12, (0, 0.012, 1.02), name="tip"),
        box(0.26, 0.03, 0.05, (0, 0, 0.06), name="guard"),
        cylinder(0.022, 0.24, 12, (0, 0, -0.08), matrix=m3d.rotation_x(math.pi / 2), name="grip"),
        uv_sphere(0.035, 8, 12, (0, 0, -0.22), name="pommel"),
    ]


def _house(detail: int = 2, seed: int = 1) -> List[Part]:
    parts = [
        box(4.0, 2.6, 3.2, (0, 1.3, 0), name="walls"),
        box(4.2, 0.15, 3.4, (0, 0.075, 0), name="foundation"),
        cone(2.9, 1.4, 4, (0, 3.3, 0), matrix=m3d.rotation_y(math.pi / 4), name="roof"),
        box(0.9, 1.8, 0.08, (0, 0.9, 1.62), name="door"),
        box(0.7, 0.7, 0.06, (1.3, 1.6, 1.62), name="window_r"),
        box(0.7, 0.7, 0.06, (-1.3, 1.6, 1.62), name="window_l"),
        cylinder(0.28, 1.1, 12, (1.2, 3.1, -0.8), name="chimney"),
    ]
    return parts


def _prop(detail: int = 2, seed: int = 8) -> List[Part]:
    """Prop genérico: barril/caixa estilizado."""
    return [
        cylinder(0.35, 0.9, 14 + detail * 4, (0, 0.45, 0), name="barrel"),
        torus(0.36, 0.035, 8, 20, matrix=m3d.translation(0, 0.68, 0), name="ring_top"),
        torus(0.36, 0.035, 8, 20, matrix=m3d.translation(0, 0.22, 0), name="ring_bottom"),
    ]


MODEL_TYPES: Dict[str, Dict[str, object]] = {
    "hero": {"builder": _humanoid, "label": "Personagem / Herói", "tris": "6k - 40k"},
    "humanoid": {"builder": _humanoid, "label": "Humanóide", "tris": "6k - 40k"},
    "creature": {"builder": _creature, "label": "Criatura / Inimigo", "tris": "4k - 25k"},
    "npc": {"builder": _humanoid, "label": "NPC", "tris": "4k - 20k"},
    "tree": {"builder": _tree, "label": "Árvore / Vegetação", "tris": "1k - 8k"},
    "rock": {"builder": _rock, "label": "Pedra / Rocha", "tris": "1k - 12k"},
    "sword": {"builder": _sword, "label": "Arma / Espada", "tris": "300 - 2k"},
    "weapon": {"builder": _sword, "label": "Arma", "tris": "300 - 2k"},
    "house": {"builder": _house, "label": "Casa / Construção", "tris": "500 - 3k"},
    "building": {"builder": _house, "label": "Construção", "tris": "500 - 3k"},
    "prop": {"builder": _prop, "label": "Prop (barril, caixa...)", "tris": "500 - 5k"},
    "environment": {"builder": lambda detail=2, seed=1: [terrain(24.0, 24 + detail * 12, 2.0, seed)], "label": "Terreno / Ambiente", "tris": "1k - 20k"},
    "terrain": {"builder": lambda detail=2, seed=1: [terrain(24.0, 24 + detail * 12, 2.0, seed)], "label": "Terreno", "tris": "1k - 20k"},
    "sphere": {"builder": lambda detail=2, seed=1: [uv_sphere(0.6, 12 + detail * 8, 18 + detail * 10, (0, 0.6, 0))], "label": "Esfera", "tris": "500 - 8k"},
    "cube": {"builder": lambda detail=2, seed=1: [box(1, 1, 1, (0, 0.5, 0))], "label": "Cubo", "tris": "12"},
}


def make_model(
    model_type: str = "prop",
    name: str = "modelo",
    detail: int = 2,
    seed: int = 1337,
    material: Optional[Material] = None,
) -> MeshData:
    info = MODEL_TYPES.get(model_type) or MODEL_TYPES["prop"]
    parts: List[Part] = list(info["builder"](detail=detail, seed=seed))  # type: ignore[arg-type]
    mesh = merge_parts(parts, name)
    mesh.material = material
    return mesh


def generate_lods(mesh: MeshData, levels: int = 3) -> List[MeshData]:
    """
    LODs reais por decimação: agrupa vértices próximos (grid) e remapeia índices.
    level 0 = original, level n = malha reduzida.
    """
    lods = [mesh]
    for level in range(1, levels + 1):
        factor = 1.0 / (2.0 ** level)
        lods.append(_decimate(mesh, factor, f"{mesh.name}_LOD{level}"))
    return lods


def _decimate(mesh: MeshData, keep: float, name: str) -> MeshData:
    n = mesh.vertex_count
    if n < 24:
        return mesh
    # tamanho da célula do grid proporcional ao bbox
    xs = mesh.positions[0::3]
    ys = mesh.positions[1::3]
    zs = mesh.positions[2::3]
    ext = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)) or 1.0
    cells = max(2, int(round((n * keep) ** (1.0 / 3.0) * 2.0)))
    cell = ext / cells

    buckets: Dict[Tuple[int, int, int], List[int]] = {}
    for i in range(n):
        key = (
            int(math.floor(xs[i] / cell)),
            int(math.floor(ys[i] / cell)),
            int(math.floor(zs[i] / cell)),
        )
        buckets.setdefault(key, []).append(i)

    remap: Dict[int, int] = {}
    positions: List[float] = []
    normals: List[float] = []
    uvs: List[float] = []
    for key, verts in buckets.items():
        new_index = len(positions) // 3
        acc = [0.0, 0.0, 0.0]
        accn = [0.0, 0.0, 0.0]
        accu = [0.0, 0.0]
        for v in verts:
            remap[v] = new_index
            acc[0] += mesh.positions[v * 3]
            acc[1] += mesh.positions[v * 3 + 1]
            acc[2] += mesh.positions[v * 3 + 2]
            accn[0] += mesh.normals[v * 3]
            accn[1] += mesh.normals[v * 3 + 1]
            accn[2] += mesh.normals[v * 3 + 2]
            accu[0] += mesh.uvs[v * 2]
            accu[1] += mesh.uvs[v * 2 + 1]
        k = len(verts)
        positions.extend([acc[0] / k, acc[1] / k, acc[2] / k])
        nn = m3d.normalize((accn[0] / k, accn[1] / k, accn[2] / k)) or (0.0, 1.0, 0.0)
        normals.extend(nn)
        uvs.extend([accu[0] / k, accu[1] / k])

    indices: List[int] = []
    for t in range(0, len(mesh.indices), 3):
        a = remap[mesh.indices[t]]
        b = remap[mesh.indices[t + 1]]
        c = remap[mesh.indices[t + 2]]
        if a != b and b != c and a != c:
            indices.extend((a, b, c))

    return MeshData(name=name, positions=positions, normals=normals, uvs=uvs, indices=indices, material=mesh.material)

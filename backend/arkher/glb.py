"""
Writer glTF 2.0 binário (.glb) em Python puro.

Gera arquivos .glb REAIS e válidos, com:
  * malhas indexadas (POSITION / NORMAL / TEXCOORD_0)
  * materiais metallic-roughness PBR (baseColor, metallic, roughness, emissive,
    normal map, AO, doubleSided)
  * textura PNG embutida no próprio GLB (o modelo já abre colorido no Godot/Blender)
  * skinning (JOINTS_0 / WEIGHTS_0 + inverseBindMatrices)
  * animações (samplers de translation / rotation / scale com interpolação LINEAR)

Validado contra a estrutura do glTF 2.0 (chunks JSON + BIN com padding de 4 bytes).
"""
from __future__ import annotations

import json
import struct
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Sequence, Tuple

from . import math3d as m3d

__all__ = ["GlbBuilder", "MeshData", "Material", "Bone", "AnimationTrack", "Animation"]

GLB_MAGIC = 0x46546C67  # 'glTF'
GLB_VERSION = 2
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942


def _pad4(b: bytes | bytearray, fill: int = 0x20) -> bytes:
    pad = (-len(b)) % 4
    return bytes(b) + bytes([fill]) * pad


@dataclass
class Material:
    name: str = "ArkherPBR"
    base_color: Tuple[float, float, float, float] = (0.8, 0.8, 0.82, 1.0)
    metallic: float = 0.0
    roughness: float = 0.7
    emissive: Tuple[float, float, float] = (0.0, 0.0, 0.0)
    double_sided: bool = False
    normal_scale: float = 1.0
    alpha_mode: str = "OPAQUE"
    alpha_cutoff: float = 0.5


@dataclass
class MeshData:
    """Uma malha: posições, normais, UVs e índices (todos planos)."""

    name: str
    positions: List[float]
    normals: List[float]
    uvs: List[float]
    indices: List[int]
    joints: Optional[List[int]] = None    # 4 por vértice
    weights: Optional[List[float]] = None  # 4 por vértice
    material: Optional[Material] = None

    @property
    def vertex_count(self) -> int:
        return len(self.positions) // 3

    @property
    def triangle_count(self) -> int:
        return len(self.indices) // 3


@dataclass
class Bone:
    name: str
    translation: Tuple[float, float, float] = (0.0, 0.0, 0.0)
    rotation: Tuple[float, float, float, float] = (0.0, 0.0, 0.0, 1.0)
    parent: int = -1  # índice na lista de ossos


@dataclass
class AnimationTrack:
    bone: int
    times: List[float]
    translations: Optional[List[Tuple[float, float, float]]] = None
    rotations: Optional[List[Tuple[float, float, float, float]]] = None
    scales: Optional[List[Tuple[float, float, float]]] = None


@dataclass
class Animation:
    name: str
    tracks: List[AnimationTrack] = field(default_factory=list)

    @property
    def duration(self) -> float:
        d = 0.0
        for t in self.tracks:
            if t.times:
                d = max(d, max(t.times))
        return d


class GlbBuilder:
    def __init__(self, generator: str = "Arkher AI 1.0"):
        self.generator = generator
        self._bin = bytearray()
        self._buffer_views: List[Dict[str, Any]] = []
        self._accessors: List[Dict[str, Any]] = []
        self._meshes: List[Dict[str, Any]] = []
        self._nodes: List[Dict[str, Any]] = []
        self._materials: List[Dict[str, Any]] = []
        self._material_cache: Dict[str, int] = {}
        self._skins: List[Dict[str, Any]] = []
        self._animations: List[Dict[str, Any]] = []
        self._images: List[Dict[str, Any]] = []
        self._textures: List[Dict[str, Any]] = []
        self.stats: Dict[str, Any] = {"vertices": 0, "triangles": 0, "meshes": 0}

    # ---------------------------------------------------------------- buffer
    def _add_buffer_view(self, data: bytes, target: Optional[int] = None) -> int:
        # alinhamento de 4 bytes
        while len(self._bin) % 4 != 0:
            self._bin.append(0)
        offset = len(self._bin)
        self._bin.extend(data)
        bv: Dict[str, Any] = {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
        if target is not None:
            bv["target"] = target
        self._buffer_views.append(bv)
        return len(self._buffer_views) - 1

    def _add_accessor(
        self,
        bv: int,
        component_type: int,
        count: int,
        accessor_type: str,
        min_vals: Optional[Sequence[float]] = None,
        max_vals: Optional[Sequence[float]] = None,
        normalized: bool = False,
        byte_offset: int = 0,
    ) -> int:
        acc: Dict[str, Any] = {
            "bufferView": bv,
            "componentType": component_type,
            "count": count,
            "type": accessor_type,
        }
        if byte_offset:
            acc["byteOffset"] = byte_offset
        if normalized:
            acc["normalized"] = True
        if min_vals is not None:
            acc["min"] = [float(v) for v in min_vals]
        if max_vals is not None:
            acc["max"] = [float(v) for v in max_vals]
        self._accessors.append(acc)
        return len(self._accessors) - 1

    # -------------------------------------------------------------- texturas
    def add_png_image(self, png_bytes: bytes, name: str = "tex") -> int:
        """Adiciona um PNG embutido e retorna o índice da textura glTF."""
        bv = self._add_buffer_view(png_bytes)
        self._buffer_views[bv].pop("target", None)
        self._images.append({"bufferView": bv, "mimeType": "image/png", "name": name})
        self._textures.append({"source": len(self._images) - 1})
        return len(self._textures) - 1

    # ------------------------------------------------------------- materiais
    def add_material(
        self,
        material: Material,
        base_color_texture: Optional[int] = None,
        normal_texture: Optional[int] = None,
    ) -> int:
        key = json.dumps(
            [material.__dict__, base_color_texture, normal_texture], sort_keys=True, default=str
        )
        if key in self._material_cache:
            return self._material_cache[key]

        pbr: Dict[str, Any] = {
            "baseColorFactor": list(material.base_color),
            "metallicFactor": material.metallic,
            "roughnessFactor": material.roughness,
        }
        if base_color_texture is not None:
            pbr["baseColorTexture"] = {"index": base_color_texture, "texCoord": 0}
        mat: Dict[str, Any] = {
            "name": material.name,
            "pbrMetallicRoughness": pbr,
            "doubleSided": material.double_sided,
            "alphaMode": material.alpha_mode,
        }
        if material.alpha_mode == "MASK":
            mat["alphaCutoff"] = material.alpha_cutoff
        if any(v > 0 for v in material.emissive):
            mat["emissiveFactor"] = list(material.emissive)
        if normal_texture is not None:
            mat["normalTexture"] = {
                "index": normal_texture,
                "texCoord": 0,
                "scale": material.normal_scale,
            }
        self._materials.append(mat)
        idx = len(self._materials) - 1
        self._material_cache[key] = idx
        return idx

    # ---------------------------------------------------------------- malhas
    @staticmethod
    def _bounds(values: Sequence[float], ncomp: int) -> Tuple[List[float], List[float]]:
        count = len(values) // ncomp
        mins = [float("inf")] * ncomp
        maxs = [float("-inf")] * ncomp
        for i in range(count):
            base = i * ncomp
            for c in range(ncomp):
                v = float(values[base + c])
                if v < mins[c]:
                    mins[c] = v
                if v > maxs[c]:
                    maxs[c] = v
        if count == 0:
            return [0.0] * ncomp, [0.0] * ncomp
        return mins, maxs

    def add_mesh(self, mesh: MeshData, material_index: Optional[int] = None) -> int:
        n = mesh.vertex_count
        if n == 0:
            raise ValueError(f"malha '{mesh.name}' sem vértices")

        pos_data = struct.pack(f"<{len(mesh.positions)}f", *mesh.positions)
        nrm_data = struct.pack(f"<{len(mesh.normals)}f", *mesh.normals)
        uv_data = struct.pack(f"<{len(mesh.uvs)}f", *mesh.uvs)

        pos_min, pos_max = self._bounds(mesh.positions, 3)
        a_pos = self._add_accessor(self._add_buffer_view(pos_data, 34962), 5126, n, "VEC3", pos_min, pos_max)
        a_nrm = self._add_accessor(self._add_buffer_view(nrm_data, 34962), 5126, n, "VEC3")
        a_uv = self._add_accessor(self._add_buffer_view(uv_data, 34962), 5126, n, "VEC2")

        attributes: Dict[str, int] = {
            "POSITION": a_pos,
            "NORMAL": a_nrm,
            "TEXCOORD_0": a_uv,
        }

        if mesh.joints and mesh.weights:
            j_data = struct.pack(f"<{len(mesh.joints)}H", *mesh.joints)
            w_data = struct.pack(f"<{len(mesh.weights)}f", *mesh.weights)
            attributes["JOINTS_0"] = self._add_accessor(
                self._add_buffer_view(j_data, 34962), 5123, n, "VEC4"
            )
            attributes["WEIGHTS_0"] = self._add_accessor(
                self._add_buffer_view(w_data, 34962), 5126, n, "VEC4", normalized=True
            )

        use_u16 = n <= 65535
        idx_flat = mesh.indices
        if use_u16:
            idx_data = struct.pack(f"<{len(idx_flat)}H", *idx_flat)
            comp_type = 5123
        else:
            idx_data = struct.pack(f"<{len(idx_flat)}I", *idx_flat)
            comp_type = 5125
        a_idx = self._add_accessor(
            self._add_buffer_view(idx_data, 34963), comp_type, len(idx_flat), "SCALAR"
        )

        primitive: Dict[str, Any] = {"attributes": attributes, "indices": a_idx, "mode": 4}
        if material_index is not None:
            primitive["material"] = material_index

        self._meshes.append({"name": mesh.name, "primitives": [primitive]})
        self.stats["vertices"] += n
        self.stats["triangles"] += mesh.triangle_count
        self.stats["meshes"] += 1
        return len(self._meshes) - 1

    # ----------------------------------------------------------------- nós
    def add_node(
        self,
        name: str,
        mesh: Optional[int] = None,
        skin: Optional[int] = None,
        translation: Optional[Sequence[float]] = None,
        rotation: Optional[Sequence[float]] = None,
        scale_m: Optional[Sequence[float]] = None,
        children: Optional[Sequence[int]] = None,
        matrix: Optional[Sequence[float]] = None,
    ) -> int:
        node: Dict[str, Any] = {"name": name}
        if mesh is not None:
            node["mesh"] = mesh
        if skin is not None:
            node["skin"] = skin
        if matrix is not None:
            node["matrix"] = [float(v) for v in matrix]
        else:
            if translation is not None:
                node["translation"] = [float(v) for v in translation]
            if rotation is not None:
                node["rotation"] = [float(v) for v in rotation]
            if scale_m is not None:
                node["scale"] = [float(v) for v in scale_m]
        if children:
            node["children"] = list(children)
        self._nodes.append(node)
        return len(self._nodes) - 1

    # --------------------------------------------------------------- skin
    def add_skin(self, name: str, bones: Sequence[Bone], root_node: int = 0) -> int:
        mats: List[float] = []
        world = [m3d.identity()] * len(bones)
        for i, b in enumerate(bones):
            local = m3d.mat4_from_trs(b.translation, b.rotation, (1.0, 1.0, 1.0))
            world[i] = local if b.parent < 0 else m3d.multiply(world[b.parent], local)
        for w in world:
            mats.extend(m3d.invert_rigid(w))
        data = struct.pack(f"<{len(mats)}f", *mats)
        acc = self._add_accessor(self._add_buffer_view(data), 5126, len(bones), "MAT4")
        self._skins.append(
            {
                "name": name,
                "inverseBindMatrices": acc,
                "joints": list(range(root_node, root_node + len(bones))),
            }
        )
        return len(self._skins) - 1

    # ----------------------------------------------------------- animações
    def add_animation(self, anim: Animation) -> int:
        samplers: List[Dict[str, Any]] = []
        channels: List[Dict[str, Any]] = []
        for track in anim.tracks:
            times = [float(t) for t in track.times]
            in_data = struct.pack(f"<{len(times)}f", *times)
            a_in = self._add_accessor(
                self._add_buffer_view(in_data), 5126, len(times), "SCALAR",
                [min(times)], [max(times)],
            )
            for path, values in (
                ("translation", track.translations),
                ("rotation", track.rotations),
                ("scale", track.scales),
            ):
                if not values:
                    continue
                ncomp = len(values[0])
                flat = [float(v) for tup in values for v in tup]
                out_data = struct.pack(f"<{len(flat)}f", *flat)
                a_out = self._add_accessor(
                    self._add_buffer_view(out_data), 5126, len(values),
                    "VEC4" if ncomp == 4 else "VEC3",
                )
                samplers.append({"input": a_in, "output": a_out, "interpolation": "LINEAR"})
                channels.append(
                    {"sampler": len(samplers) - 1, "target": {"node": track.bone, "path": path}}
                )
        self._animations.append({"name": anim.name, "samplers": samplers, "channels": channels})
        return len(self._animations) - 1

    # ---------------------------------------------------------------- build
    def build(
        self,
        scene_name: str = "ArkherScene",
        root_nodes: Optional[Sequence[int]] = None,
        asset_name: str = "Arkher AI asset",
    ) -> bytes:
        gltf: Dict[str, Any] = {
            "asset": {
                "version": "2.0",
                "generator": self.generator,
                "copyright": "Gerado por Arkher AI",
            },
            "scene": 0,
            "scenes": [{"name": scene_name, "nodes": list(root_nodes or range(len(self._nodes))) }],
            "nodes": self._nodes,
            "meshes": self._meshes,
            "materials": self._materials,
            "bufferViews": self._buffer_views,
            "accessors": self._accessors,
        }
        if self._images:
            gltf["images"] = self._images
        if self._textures:
            gltf["textures"] = self._textures
        if self._skins:
            gltf["skins"] = self._skins
        if self._animations:
            gltf["animations"] = self._animations

        bin_bytes = _pad4(self._bin, 0x00)
        gltf["buffers"] = [{"byteLength": len(bin_bytes)}]

        json_bytes = _pad4(
            json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8"), 0x20
        )

        total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
        out = bytearray()
        out += struct.pack("<III", GLB_MAGIC, GLB_VERSION, total)
        out += struct.pack("<II", len(json_bytes), CHUNK_JSON)
        out += json_bytes
        out += struct.pack("<II", len(bin_bytes), CHUNK_BIN)
        out += bin_bytes
        return bytes(out)

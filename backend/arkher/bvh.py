"""
Importação de motion capture REAL (arquivos .bvh) + retarget para o rig Arkher.

Fluxo:
  1. parse_bvh()  -- lê HIERARCHY (juntas, offsets, canais) e MOTION (frames)
  2. _fk_one()    -- forward kinematics: posição/rotação mundial de cada junta
  3. retarget()   -- redireciona o movimento para o rig Arkher de 22 ossos:
                     * Hips: translação + orientação (base coluna/quadril)
                     * Spine/Spine1/Chest: arco interpolado quadril -> peito
                     * Neck/Head: alinhamento com o topo da cabeça (End Site)
                     * Braços e pernas: IK analítico de 2 ossos com polo real
                       (cotovelo/joelho do mo-cap) — contato de pé preservado
                     * Pés/mãos: alinhamento com a direção dos dedos
  4. smooth_animation() -- passa-baixa por slerp (acabamento 'mo-cap limpo')

O resultado é um glb.Animation compatível com build_rigged_glb / export Godot /
export Roblox: dados de mo-cap de verdade, não keyframes inventados.

BVH suportado (padrão CMU/Mixamo/AccuRIG/Blender):
  HIERARCHY / ROOT <nome> { OFFSET x y z CHANNELS n ... [JOINT|End Site] ... }
  MOTION / Frames: N / Frame Time: dt / linhas de valores separados por espaço.
Euler composto na ordem em que os canais aparecem (ex.: Zrotation Xrotation Yrotation).
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence, Tuple

from . import math3d as m3d
from .animation import (BONE_DEFS, bone_world_positions, build_humanoid_skeleton,
                        smooth_animation)
from .glb import Animation, AnimationTrack

__all__ = ["parse_bvh", "retarget", "smooth_animation", "BVHData", "BVHJoint", "map_joints"]

Vec3 = Tuple[float, float, float]
Quat = Tuple[float, float, float, float]
IDENT: Quat = (0.0, 0.0, 0.0, 1.0)
UP = (0.0, 1.0, 0.0)
DOWN = (0.0, -1.0, 0.0)


# ------------------------------------------------------------------ utilidades
def _vs(v: Vec3, s: float) -> Vec3:
    return (v[0] * s, v[1] * s, v[2] * s)


def quat_conj(q: Quat) -> Quat:
    return (-q[0], -q[1], -q[2], q[3])


def quat_rotate(q: Quat, v: Vec3) -> Vec3:
    """Rotaciona um vetor por um quatérnion (v' = q v q*)."""
    x, y, z, w = q
    vx, vy, vz = v
    tx = 2.0 * (y * vz - z * vy)
    ty = 2.0 * (z * vx - x * vz)
    tz = 2.0 * (x * vy - y * vx)
    return (
        vx + w * tx + (y * tz - z * ty),
        vy + w * ty + (z * tx - x * tz),
        vz + w * tz + (x * ty - y * tx),
    )


def quat_between(a: Vec3, b: Vec3) -> Quat:
    """Quatérnion mínimo que leva a (unitário) até b (unitário)."""
    an = m3d.normalize(a)
    bn = m3d.normalize(b)
    d = max(-1.0, min(1.0, m3d.dot(an, bn)))
    if d > 0.999999:
        return IDENT
    if d < -0.999999:
        axis = m3d.cross(an, (1.0, 0.0, 0.0))
        if m3d.length(axis) < 1e-4:
            axis = m3d.cross(an, (0.0, 0.0, 1.0))
        return m3d.quat_from_axis_angle(m3d.normalize(axis), math.pi)
    axis = m3d.cross(an, bn)
    return m3d.quat_normalize((axis[0], axis[1], axis[2], 1.0 + d))


def quat_from_basis(x: Vec3, y: Vec3, z: Vec3) -> Quat:
    """Matriz de rotação com colunas (x,y,z) -> quatérnion (método de Shepperd)."""
    m00, m01, m02 = x[0], y[0], z[0]
    m10, m11, m12 = x[1], y[1], z[1]
    m20, m21, m22 = x[2], y[2], z[2]
    tr = m00 + m11 + m22
    if tr > 0.0:
        s = math.sqrt(tr + 1.0) * 2.0
        w = 0.25 * s
        xq = (m21 - m12) / s
        yq = (m02 - m20) / s
        zq = (m10 - m01) / s
    elif m00 > m11 and m00 > m22:
        s = math.sqrt(1.0 + m00 - m11 - m22) * 2.0
        w = (m21 - m12) / s
        xq = 0.25 * s
        yq = (m01 + m10) / s
        zq = (m02 + m20) / s
    elif m11 > m22:
        s = math.sqrt(1.0 + m11 - m00 - m22) * 2.0
        w = (m02 - m20) / s
        xq = (m01 + m10) / s
        yq = 0.25 * s
        zq = (m12 + m21) / s
    else:
        s = math.sqrt(1.0 + m22 - m00 - m11) * 2.0
        w = (m10 - m01) / s
        xq = (m02 + m20) / s
        yq = (m12 + m21) / s
        zq = 0.25 * s
    return m3d.quat_normalize((xq, yq, zq, w))


def _frame_from_dir(y_dir: Vec3, side_ref: Optional[Vec3], fwd_ref: Optional[Vec3]) -> Quat:
    """Base ortonormal: y = direção dada; x/z derivados de uma referência lateral ou frontal."""
    y_dir = m3d.normalize(y_dir)
    ref = side_ref if side_ref is not None else fwd_ref
    if ref is None:
        ref = (1.0, 0.0, 0.0)
    proj = m3d.sub(ref, _vs(y_dir, m3d.dot(ref, y_dir)))
    if m3d.length(proj) < 1e-6:
        proj = m3d.sub((0.0, 0.0, 1.0), _vs(y_dir, y_dir[2]))
        if m3d.length(proj) < 1e-6:
            proj = (1.0, 0.0, 0.0)
    if side_ref is not None:
        x_dir = m3d.normalize(proj)          # lado esquerdo do personagem
        z_dir = m3d.cross(x_dir, y_dir)      # frente
    else:
        z_dir = m3d.normalize(proj)          # frente
        x_dir = m3d.cross(y_dir, z_dir)
    return quat_from_basis(x_dir, y_dir, z_dir)


def _axis_quat(axis: str, deg: float) -> Quat:
    r = math.radians(deg) * 0.5
    c, s = math.cos(r), math.sin(r)
    if axis == "x":
        return (s, 0.0, 0.0, c)
    if axis == "y":
        return (0.0, s, 0.0, c)
    return (0.0, 0.0, s, c)


# ---------------------------------------------------------------------- parser
@dataclass
class BVHJoint:
    name: str
    parent: int = -1
    offset: Vec3 = (0.0, 0.0, 0.0)
    channels: List[str] = field(default_factory=list)  # "xpos","ypos","zpos","xrot","yrot","zrot"
    is_end_site: bool = False


@dataclass
class BVHData:
    joints: List[BVHJoint]
    frames: List[List[float]]
    frame_time: float
    name_by_index: Dict[str, int] = field(default_factory=dict)

    @property
    def frame_count(self) -> int:
        return len(self.frames)

    @property
    def duration(self) -> float:
        return self.frame_count * self.frame_time

    @property
    def channel_count(self) -> int:
        return sum(len(j.channels) for j in self.joints)


_CHAN_MAP = {
    "xposition": "xpos", "yposition": "ypos", "zposition": "zpos",
    "xrotation": "xrot", "yrotation": "yrot", "zrotation": "zrot",
}


def parse_bvh(text: str) -> BVHData:
    """Parser tolerante: tabs, maiúsculas mistas, 'Frames : N', nomes duplicados."""
    tokens: List[str] = []
    for line in text.replace("\r", "\n").split("\n"):
        tokens.extend(line.split())
    if not tokens:
        raise ValueError("arquivo BVH vazio")
    pos = 0

    def peek() -> Optional[str]:
        return tokens[pos] if pos < len(tokens) else None

    def take() -> str:
        nonlocal pos
        if pos >= len(tokens):
            raise ValueError("BVH truncado")
        t = tokens[pos]
        pos += 1
        return t

    def expect(value: str) -> None:
        t = take()
        if t.lower().rstrip(":") != value.lower().rstrip(":"):
            raise ValueError(f"BVH inválido: esperado '{value}', encontrado '{t}'")

    joints: List[BVHJoint] = []
    index_by_name: Dict[str, int] = {}

    def parse_joint(parent: int, end_site: bool) -> int:
        if end_site:
            name = f"__endsite_{parent}"
        else:
            name = take()
            base, k = name, 2
            while name in index_by_name:
                name = f"{base}_{k}"
                k += 1
        j = BVHJoint(name=name, parent=parent, is_end_site=end_site)
        idx = len(joints)
        joints.append(j)
        index_by_name[name] = idx
        expect("{")
        while True:
            kw = peek()
            if kw is None:
                raise ValueError("BVH truncado dentro de joint")
            low = kw.lower()
            if low == "}":
                take()
                break
            if low == "offset":
                take()
                j.offset = (float(take()), float(take()), float(take()))
            elif low == "channels":
                take()
                n = int(take())
                j.channels = [_CHAN_MAP.get(take().lower(), "zrot") for _ in range(n)]
            elif low == "joint":
                take()
                parse_joint(idx, end_site=False)
            elif low == "end":
                take()
                expect("site")
                parse_joint(idx, end_site=True)
            else:
                raise ValueError(f"BVH: palavra-chave desconhecida '{kw}'")
        return idx

    expect("hierarchy")
    if take().lower() != "root":
        raise ValueError("BVH: esperado ROOT na hierarquia")
    parse_joint(-1, end_site=False)

    expect("motion")
    frames_count = 0
    frame_time = 1.0 / 30.0
    while True:
        kw = peek()
        if kw is None:
            break
        low = kw.lower().rstrip(":")
        if low == "frames":
            take()
            nxt = take()
            if nxt.rstrip(":").isdigit() is False and not nxt.replace(".", "").isdigit():
                nxt = take()  # 'Frames : 120' -> pulou o ':'
            frames_count = int(float(nxt.rstrip(":")))
        elif low == "frame":
            take()
            nxt = take().lower()
            if nxt.rstrip(":") != "time":
                nxt = take()
            frame_time = float(take())
        else:
            break

    total_ch = sum(len(j.channels) for j in joints)
    if total_ch == 0:
        raise ValueError("BVH sem canais de movimento")
    frames: List[List[float]] = []
    while pos < len(tokens):
        vals: List[float] = []
        while pos < len(tokens) and len(vals) < total_ch:
            try:
                vals.append(float(take()))
            except ValueError:
                pass
        if len(vals) == total_ch:
            frames.append(vals)
        else:
            break
    if not frames:
        raise ValueError("BVH sem frames de movimento (MOTION)")
    if frames_count and len(frames) > frames_count:
        frames = frames[:frames_count]
    return BVHData(joints=joints, frames=frames, frame_time=frame_time or 1.0 / 30.0,
                   name_by_index=index_by_name)


# --------------------------------------------------------------------------- FK
def _fk_one(data: BVHData, values: Sequence[float]) -> Dict[str, Tuple[Vec3, Quat]]:
    """Um frame: posição mundial e rotação mundial de cada junta (inclui End Sites)."""
    out: Dict[str, Tuple[Vec3, Quat]] = {}
    cursor = 0
    world_q: List[Quat] = [IDENT] * len(data.joints)
    world_p: List[Vec3] = [(0.0, 0.0, 0.0)] * len(data.joints)
    for i, j in enumerate(data.joints):
        px, py, pz = j.offset
        q = IDENT
        for ch in j.channels:
            v = values[cursor]
            cursor += 1
            if ch == "xpos":
                px += v
            elif ch == "ypos":
                py += v
            elif ch == "zpos":
                pz += v
            elif ch == "xrot":
                q = m3d.quat_multiply(q, _axis_quat("x", v))
            elif ch == "yrot":
                q = m3d.quat_multiply(q, _axis_quat("y", v))
            else:
                q = m3d.quat_multiply(q, _axis_quat("z", v))
        if j.parent < 0:
            world_p[i] = (px, py, pz)
            world_q[i] = q
        else:
            pp, pq = world_p[j.parent], world_q[j.parent]
            off = quat_rotate(pq, (px, py, pz))
            world_p[i] = (pp[0] + off[0], pp[1] + off[1], pp[2] + off[2])
            world_q[i] = m3d.quat_multiply(pq, q)
        out[j.name] = (world_p[i], world_q[i])
    return out


# ------------------------------------------------------------- mapeamento nomes
def _side(name: str) -> int:
    """0 = centro, +1 = esquerda do personagem, -1 = direita."""
    low = name.lower().replace(":", "_").replace("-", "_")
    if "left" in low:
        return 1
    if "right" in low:
        return -1
    for sep in ("_l", ".l"):
        if low.endswith(sep):
            return 1
    for sep in ("_r", ".r"):
        if low.endswith(sep):
            return -1
    if low.startswith("l_") or low.startswith("l."):
        return 1
    if low.startswith("r_") or low.startswith("r."):
        return -1
    return 0


def _depth(data: BVHData, i: int) -> int:
    d = 0
    while data.joints[i].parent >= 0:
        i = data.joints[i].parent
        d += 1
    return d


def _find_joint(data: BVHData, keywords: Sequence[str], side: int = 0,
                exclude: Sequence[str] = ()) -> Optional[str]:
    cands: List[Tuple[int, int, str]] = []
    for i, j in enumerate(data.joints):
        if j.is_end_site:
            continue
        low = j.name.lower().replace(":", "_").replace("mixamorig", "").replace("-", "_")
        if any(x in low for x in exclude):
            continue
        if all(k in low for k in keywords) and _side(j.name) == side:
            cands.append((_depth(data, i), len(low), j.name))
    if not cands:
        return None
    cands.sort()
    return cands[0][2]


def _child_non_end(data: BVHData, name: str) -> Optional[str]:
    idx = data.name_by_index.get(name)
    if idx is None:
        return None
    for j in data.joints:
        if j.parent == idx and not j.is_end_site:
            return j.name
    return None


def _end_site_after(data: BVHData, joint_name: Optional[str]) -> Optional[str]:
    if not joint_name:
        return None
    idx = data.name_by_index.get(joint_name)
    if idx is None:
        return None
    for j in data.joints:
        if j.parent == idx and j.is_end_site:
            return j.name
    return None


@dataclass
class RigMap:
    hips: str
    spine: Optional[str] = None
    chest: Optional[str] = None
    neck: Optional[str] = None
    head: Optional[str] = None
    head_top: Optional[str] = None
    shoulder_l: Optional[str] = None
    elbow_l: Optional[str] = None
    wrist_l: Optional[str] = None
    hand_end_l: Optional[str] = None
    shoulder_r: Optional[str] = None
    elbow_r: Optional[str] = None
    wrist_r: Optional[str] = None
    hand_end_r: Optional[str] = None
    hip_l: Optional[str] = None
    knee_l: Optional[str] = None
    ankle_l: Optional[str] = None
    toe_end_l: Optional[str] = None
    hip_r: Optional[str] = None
    knee_r: Optional[str] = None
    ankle_r: Optional[str] = None
    toe_end_r: Optional[str] = None

    def mapped(self) -> Dict[str, str]:
        return {k: v for k, v in self.__dict__.items() if v}


def map_joints(data: BVHData) -> RigMap:
    """Descobre as juntas do BVH que correspondem ao rig Arkher (heurística de nomes)."""
    hips = (_find_joint(data, ("hips",)) or _find_joint(data, ("hip",))
            or _find_joint(data, ("pelvis",)) or _find_joint(data, ("root",))
            or data.joints[0].name)
    m = RigMap(hips=hips)
    m.neck = _find_joint(data, ("neck",))
    m.head = _find_joint(data, ("head",), exclude=("headtop", "head_end"))
    m.head_top = _end_site_after(data, m.head)

    # cadeia da coluna (spine/spine1/spine2/chest/upperback), ordenada por profundidade
    chain: List[Tuple[int, str]] = []
    for i, j in enumerate(data.joints):
        if j.is_end_site:
            continue
        low = j.name.lower().replace(":", "_")
        if any(k in low for k in ("spine", "chest", "upperback", "thorax")):
            chain.append((_depth(data, i), j.name))
    chain.sort()
    if chain:
        m.spine = chain[0][1]
        if len(chain) > 1:
            m.chest = chain[-1][1]
    # pescoço como fallback de topo da coluna
    if m.chest is None and m.neck:
        m.chest = m.neck

    # braços
    for side, sh, el, wr, he in (
        (1, "shoulder_l", "elbow_l", "wrist_l", "hand_end_l"),
        (-1, "shoulder_r", "elbow_r", "wrist_r", "hand_end_r"),
    ):
        sh_name = (_find_joint(data, ("arm",), side=side, exclude=("fore", "lower", "hand", "twist"))
                   or _find_joint(data, ("shoulder",), side=side, exclude=("end", "twist"))
                   or _find_joint(data, ("collar",), side=side))
        el_name = (_find_joint(data, ("forearm",), side=side)
                   or _find_joint(data, ("lowerarm",), side=side)
                   or _find_joint(data, ("elbow",), side=side)
                   or (_child_non_end(data, sh_name) if sh_name else None))
        wr_name = (_find_joint(data, ("hand",), side=side, exclude=("twist", "thumb", "index", "middle", "ring", "pinky"))
                   or _find_joint(data, ("wrist",), side=side)
                   or (_child_non_end(data, el_name) if el_name else None))
        setattr(m, sh, sh_name)
        setattr(m, el, el_name)
        setattr(m, wr, wr_name)
        setattr(m, he, _end_site_after(data, wr_name))

    # pernas
    for side, hp, kn, an, te in (
        (1, "hip_l", "knee_l", "ankle_l", "toe_end_l"),
        (-1, "hip_r", "knee_r", "ankle_r", "toe_end_r"),
    ):
        hp_name = (_find_joint(data, ("upleg",), side=side)
                   or _find_joint(data, ("upperleg",), side=side)
                   or _find_joint(data, ("thigh",), side=side)
                   or _find_joint(data, ("hip",), side=side, exclude=("hips",))
                   or _find_joint(data, ("leg",), side=side, exclude=("lower",)))
        kn_name = (_find_joint(data, ("leg",), side=side, exclude=("up",))
                   or _find_joint(data, ("shin",), side=side)
                   or _find_joint(data, ("knee",), side=side)
                   or _find_joint(data, ("calf",), side=side)
                   or (_child_non_end(data, hp_name) if hp_name else None))
        an_name = (_find_joint(data, ("foot",), side=side, exclude=("toe",))
                   or _find_joint(data, ("ankle",), side=side)
                   or (_child_non_end(data, kn_name) if kn_name else None))
        toe = (_find_joint(data, ("toe",), side=side)
               or _find_joint(data, ("ball",), side=side)
               or (_child_non_end(data, an_name) if an_name else None))
        setattr(m, hp, hp_name)
        setattr(m, kn, kn_name)
        setattr(m, an, an_name)
        setattr(m, te, _end_site_after(data, toe) or _end_site_after(data, an_name))
    return m


# --------------------------------------------------------------------- retarget
def _bone_index(name: str) -> int:
    for i, (n, _, _) in enumerate(BONE_DEFS):
        if n == name:
            return i
    raise KeyError(name)


def _two_bone_ik(root_pos: Vec3, target: Vec3, l1: float, l2: float,
                 pole_hint: Optional[Vec3]) -> Tuple[Quat, Quat]:
    """
    IK analítico de 2 ossos no espaço mundial; em repouso os ossos apontam para -Y.
    Retorna (q_world_osso1, q_world_osso2).
    """
    v = m3d.sub(target, root_pos)
    dist = m3d.length(v)
    dist = max(abs(l1 - l2) + 1e-4, min(l1 + l2 - 1e-4, dist if dist > 1e-6 else 1e-4))
    vhat = _vs(v, 1.0 / max(1e-6, m3d.length(v)))
    cos_a = (dist * dist + l1 * l1 - l2 * l2) / (2.0 * dist * l1)
    a = math.acos(max(-1.0, min(1.0, cos_a)))
    q_align = quat_between(DOWN, vhat)
    mid_dir0 = quat_rotate(q_align, DOWN)
    axis = None
    if pole_hint is not None:
        axis = m3d.cross(m3d.sub(pole_hint, root_pos), v)
        if m3d.length(axis) < 1e-6:
            axis = None
    if axis is None:
        axis = m3d.cross(DOWN, vhat)
        if m3d.length(axis) < 1e-6:
            axis = (1.0, 0.0, 0.0)
    axis = m3d.normalize(axis)
    q_pos = m3d.quat_from_axis_angle(axis, a)
    q_neg = m3d.quat_from_axis_angle(axis, -a)
    if pole_hint is not None:
        pole_dir = m3d.normalize(m3d.sub(pole_hint, root_pos))
        if m3d.dot(quat_rotate(q_neg, mid_dir0), pole_dir) > m3d.dot(quat_rotate(q_pos, mid_dir0), pole_dir):
            q_bend = q_neg
        else:
            q_bend = q_pos
    else:
        # sem polo: dobra 'para frente' (+Z) — joelho à frente, cotovelo atrás fica a cargo do sinal
        q_bend = q_pos if quat_rotate(q_pos, mid_dir0)[2] >= quat_rotate(q_neg, mid_dir0)[2] else q_neg
    q1 = m3d.quat_normalize(m3d.quat_multiply(q_bend, q_align))
    dir1 = quat_rotate(q1, DOWN)
    mid = m3d.add(root_pos, _vs(dir1, l1))
    dir2 = m3d.normalize(m3d.sub(target, mid))
    q2 = m3d.quat_normalize(m3d.quat_multiply(quat_between(dir1, dir2), q1))
    return q1, q2


ARM_L1, ARM_L2 = 0.28, 0.26   # UpperArm->LowerArm, LowerArm->Hand (BONE_DEFS)
LEG_L1, LEG_L2 = 0.42, 0.40   # UpperLeg->LowerLeg, LowerLeg->Foot


def retarget(data: BVHData, name: str = "mocap", fps: int = 30,
             max_frames: int = 900, smooth: float = 0.35) -> Tuple[Animation, Dict[str, object]]:
    """Retargeta um BVH para o rig Arkher de 22 ossos. Retorna (Animation, info)."""
    rmap = map_joints(data)
    n_frames = data.frame_count
    if n_frames == 0:
        raise ValueError("BVH sem frames")

    step = max(1, math.ceil(n_frames / max_frames))
    src_fps = 1.0 / max(1e-6, data.frame_time)
    if src_fps > fps * 1.15:
        step = max(step, max(1, math.ceil(src_fps / fps - 0.05)))
    frame_ids = list(range(0, n_frames, step))
    out_fps = src_fps / step
    times = [i / out_fps for i in range(len(frame_ids))]

    # escala: altura do BVH em repouso -> altura do rig Arkher (~1.74 m)
    rest = _fk_one(data, [0.0] * data.channel_count)
    ys = [p[1] for (p, _) in rest.values()]
    bvh_height = max(ys) - min(ys)
    scale = 1.74 / bvh_height if bvh_height > 1e-6 else 1.0

    bones = build_humanoid_skeleton()
    bind = bone_world_positions(bones)
    hips_rest = bind[0]
    chest_bind = bind[_bone_index("Chest")]
    B = {bn: _bone_index(bn) for bn, _, _ in BONE_DEFS}

    rot_tracks: Dict[int, List[Quat]] = {i: [] for i in range(len(BONE_DEFS))}
    hips_trans: List[Vec3] = []

    def gp(fk: Dict[str, Tuple[Vec3, Quat]], jname: Optional[str]) -> Optional[Vec3]:
        if not jname:
            return None
        item = fk.get(jname)
        if item is None:
            return None
        return _vs(item[0], scale)

    for fi in frame_ids:
        fk = _fk_one(data, data.frames[fi])
        hips_p = gp(fk, rmap.hips) or (0.0, 1.0, 0.0)
        spine_p = gp(fk, rmap.spine)
        chest_p = gp(fk, rmap.chest)
        neck_p = gp(fk, rmap.neck)
        head_p = gp(fk, rmap.head)
        head_top = gp(fk, rmap.head_top)
        hip_l = gp(fk, rmap.hip_l)
        hip_r = gp(fk, rmap.hip_r)
        sh_l = gp(fk, rmap.shoulder_l)
        sh_r = gp(fk, rmap.shoulder_r)

        # ---- Hips -----------------------------------------------------------
        hips_trans.append((hips_p[0] - hips_rest[0], hips_p[1] - hips_rest[1], hips_p[2] - hips_rest[2]))
        top_ref = chest_p or spine_p or neck_p
        y_hips = m3d.sub(top_ref, hips_p) if top_ref else (0.0, 0.3, 0.0)
        side_ref = m3d.sub(hip_l, hip_r) if (hip_l and hip_r) else (
            m3d.sub(sh_l, sh_r) if (sh_l and sh_r) else (1.0, 0.0, 0.0))
        q_hips = _frame_from_dir(y_hips, side_ref, None)
        rot_tracks[B["Hips"]].append(q_hips)

        # ---- coluna: arco hips -> peito --------------------------------------
        chest_target = neck_p or chest_p or spine_p
        if chest_target is None:
            chest_target = m3d.add(hips_p, _vs(m3d.normalize(y_hips), 0.4))
        y_chest = m3d.sub(chest_target, hips_p)
        side_ref2 = m3d.sub(sh_l, sh_r) if (sh_l and sh_r) else side_ref
        q_chest = _frame_from_dir(y_chest, side_ref2, None)
        q_w1 = m3d.quat_slerp(q_hips, q_chest, 0.34)
        q_w2 = m3d.quat_slerp(q_hips, q_chest, 0.70)
        rot_tracks[B["Spine"]].append(m3d.quat_multiply(quat_conj(q_hips), q_w1))
        rot_tracks[B["Spine1"]].append(m3d.quat_multiply(quat_conj(q_w1), q_w2))
        rot_tracks[B["Chest"]].append(m3d.quat_multiply(quat_conj(q_w2), q_chest))
        rot_tracks[B["Shoulder_L"]].append(IDENT)
        rot_tracks[B["Shoulder_R"]].append(IDENT)

        # ---- Neck/Head --------------------------------------------------------
        if head_top and head_p:
            head_dir = m3d.sub(head_top, head_p)
        elif head_p and neck_p:
            head_dir = m3d.sub(head_p, neck_p)
        elif head_p:
            head_dir = m3d.sub(head_p, chest_target)
        else:
            head_dir = y_chest
        fwd_chest = quat_rotate(q_chest, (0.0, 0.0, 1.0))
        q_head = _frame_from_dir(head_dir, None, fwd_chest)
        q_neck = m3d.quat_slerp(q_chest, q_head, 0.5)
        rot_tracks[B["Neck"]].append(m3d.quat_multiply(quat_conj(q_chest), q_neck))
        rot_tracks[B["Head"]].append(m3d.quat_multiply(quat_conj(q_neck), q_head))

        # ---- braços: IK 2 ossos (ombro -> pulso, polo = cotovelo do mocap) ----
        for side, sh_p, el_name, wr_name, he_name, n_up, n_lo, n_hand in (
            (1, sh_l, rmap.elbow_l, rmap.wrist_l, rmap.hand_end_l, "UpperArm_L", "LowerArm_L", "Hand_L"),
            (-1, sh_r, rmap.elbow_r, rmap.wrist_r, rmap.hand_end_r, "UpperArm_R", "LowerArm_R", "Hand_R"),
        ):
            wr_p = gp(fk, wr_name)
            if sh_p is None or wr_p is None:
                rot_tracks[B[n_up]].append(IDENT)
                rot_tracks[B[n_lo]].append(IDENT)
                rot_tracks[B[n_hand]].append(IDENT)
                continue
            el_p = gp(fk, el_name)
            root_pos = sh_p
            if m3d.length(m3d.sub(root_pos, chest_target)) > 0.45:
                # posição do mocap implausível -> deriva do peito posado
                root_bind = bind[B[n_up]]
                root_pos = m3d.add(chest_target, quat_rotate(q_chest, m3d.sub(root_bind, chest_bind)))
            d = m3d.sub(wr_p, root_pos)
            reach = min(m3d.length(d), (ARM_L1 + ARM_L2) * 0.999)
            target = m3d.add(root_pos, _vs(m3d.normalize(d), max(0.02, reach)))
            q1, q2 = _two_bone_ik(root_pos, target, ARM_L1, ARM_L2, el_p)
            rot_tracks[B[n_up]].append(m3d.quat_multiply(quat_conj(q_chest), q1))
            rot_tracks[B[n_lo]].append(m3d.quat_multiply(quat_conj(q1), q2))
            he_p = gp(fk, he_name)
            if he_p:
                cur = quat_rotate(q2, DOWN)
                q_delta = quat_between(cur, m3d.normalize(m3d.sub(he_p, wr_p)))
                q_hand_w = m3d.quat_multiply(q_delta, q2)
                rot_tracks[B[n_hand]].append(m3d.quat_multiply(quat_conj(q2), q_hand_w))
            else:
                rot_tracks[B[n_hand]].append(IDENT)

        # ---- pernas: IK 2 ossos (quadril -> tornozelo, polo = joelho) ---------
        for hp_p, kn_name, an_name, te_name, n_up, n_lo, n_foot, n_toes in (
            (hip_l, rmap.knee_l, rmap.ankle_l, rmap.toe_end_l, "UpperLeg_L", "LowerLeg_L", "Foot_L", "Toes_L"),
            (hip_r, rmap.knee_r, rmap.ankle_r, rmap.toe_end_r, "UpperLeg_R", "LowerLeg_R", "Foot_R", "Toes_R"),
        ):
            an_p = gp(fk, an_name)
            if an_p is None:
                rot_tracks[B[n_up]].append(IDENT)
                rot_tracks[B[n_lo]].append(IDENT)
                rot_tracks[B[n_foot]].append(IDENT)
                rot_tracks[B[n_toes]].append(IDENT)
                continue
            kn_p = gp(fk, kn_name)
            if hp_p is not None and m3d.length(m3d.sub(hp_p, hips_p)) < 0.4:
                root_pos = hp_p
            else:
                root_bind = bind[B[n_up]]
                root_pos = m3d.add(hips_p, quat_rotate(q_hips, m3d.sub(root_bind, hips_rest)))
            d = m3d.sub(an_p, root_pos)
            reach = min(m3d.length(d), (LEG_L1 + LEG_L2) * 0.999)
            target = m3d.add(root_pos, _vs(m3d.normalize(d), max(0.02, reach)))
            q1, q2 = _two_bone_ik(root_pos, target, LEG_L1, LEG_L2, kn_p)
            rot_tracks[B[n_up]].append(m3d.quat_multiply(quat_conj(q_hips), q1))
            rot_tracks[B[n_lo]].append(m3d.quat_multiply(quat_conj(q1), q2))
            te_p = gp(fk, te_name)
            if te_p:
                rest_foot = m3d.normalize((0.0, -0.04, 0.10))  # Foot -> Toes no bind
                cur = quat_rotate(q2, rest_foot)
                q_delta = quat_between(cur, m3d.normalize(m3d.sub(te_p, an_p)))
                q_foot_w = m3d.quat_multiply(q_delta, q2)
                rot_tracks[B[n_foot]].append(m3d.quat_multiply(quat_conj(q2), q_foot_w))
            else:
                rot_tracks[B[n_foot]].append(IDENT)
            rot_tracks[B[n_toes]].append(IDENT)

    tracks: List[AnimationTrack] = []
    for bi in range(len(BONE_DEFS)):
        rots = rot_tracks[bi]
        if not rots:
            continue
        tracks.append(AnimationTrack(
            bone=bi, times=list(times), rotations=rots,
            translations=list(hips_trans) if bi == 0 else None,
        ))

    anim = Animation(name=name, tracks=tracks)
    if smooth > 0.0:
        anim = smooth_animation(anim, strength=smooth)
    info: Dict[str, object] = {
        "name": name,
        "label": f"Mo-cap ({name})",
        "loop": False,
        "kind": "mocap",
        "source": "bvh",
        "source_frames": n_frames,
        "source_fps": round(src_fps, 3),
        "frames": len(frame_ids),
        "fps": round(out_fps, 3),
        "duration": round(times[-1], 4) if times else 0.0,
        "scale": round(scale, 4),
        "smooth": smooth,
        "mapped_joints": rmap.mapped(),
        "tracks": len(tracks),
        "bones_animated": len({t.bone for t in tracks}),
    }
    return anim, info


# -------------------------------------------------------------------- suavização
# smooth_animation (passa-baixa por slerp) vem de animation.py — reexportado acima.

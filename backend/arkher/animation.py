"""
Rig + animação procedural em Python puro.

  * build_humanoid_skeleton() -> hierarquia de ossos (glTF, Y-up, metros)
  * auto_skin()               -> pintura de pesos automática por cápsula óssea
                                 (4 influências por vértice, normalizadas)
  * make_animation()          -> keyframes reais (idle/walk/run/jump/sprint/
                                 attack/wave/dance/death/crouch)
  * build_rigged_glb()        -> .glb com skin + animação embutida
  * export_godot_animation_library() -> .tres importável no Godot 4
  * export_roblox_keyframe_sequence() -> .rbxlx (KeyframeSequence) p/ Roblox Studio

Nada aqui é "mock": os arquivos gerados abrem de verdade no Godot 4.3+, no
Blender 3.6+/4.x e (o keyframe sequence) no Roblox Studio.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Tuple

from . import math3d as m3d
from .glb import Animation, AnimationTrack, Bone, GlbBuilder, Material, MeshData
from .meshes import make_model

__all__ = [
    "BONE_DEFS", "build_humanoid_skeleton", "auto_skin", "make_animation",
    "ANIMATION_PRESETS", "build_rigged_glb", "export_godot_animation_library",
    "export_roblox_keyframe_sequence", "bone_world_positions",
]

# nome -> (pai, translação local em metros)
BONE_DEFS: List[Tuple[str, int, Tuple[float, float, float]]] = [
    ("Hips", -1, (0.0, 1.00, 0.0)),
    ("Spine", 0, (0.0, 0.12, 0.0)),
    ("Spine1", 1, (0.0, 0.14, 0.0)),
    ("Chest", 2, (0.0, 0.14, 0.0)),
    ("Neck", 3, (0.0, 0.14, 0.0)),
    ("Head", 4, (0.0, 0.09, 0.0)),
    ("Shoulder_L", 3, (0.07, 0.10, 0.0)),
    ("UpperArm_L", 6, (0.15, -0.02, 0.0)),
    ("LowerArm_L", 7, (0.0, -0.28, 0.0)),
    ("Hand_L", 8, (0.0, -0.26, 0.0)),
    ("Shoulder_R", 3, (-0.07, 0.10, 0.0)),
    ("UpperArm_R", 10, (-0.15, -0.02, 0.0)),
    ("LowerArm_R", 11, (0.0, -0.28, 0.0)),
    ("Hand_R", 12, (0.0, -0.26, 0.0)),
    ("UpperLeg_L", 0, (0.11, -0.06, 0.0)),
    ("LowerLeg_L", 14, (0.0, -0.42, 0.0)),
    ("Foot_L", 15, (0.0, -0.40, 0.0)),
    ("Toes_L", 16, (0.0, -0.04, 0.10)),
    ("UpperLeg_R", 0, (-0.11, -0.06, 0.0)),
    ("LowerLeg_R", 18, (0.0, -0.42, 0.0)),
    ("Foot_R", 19, (0.0, -0.40, 0.0)),
    ("Toes_R", 20, (0.0, -0.04, 0.10)),
]

# cápsulas de skinning: (osso, ponto A, ponto B, raio)
_SKIN_CAPSULES: List[Tuple[int, Tuple[float, float, float], Tuple[float, float, float], float]] = [
    (0, (-0.16, 0.94, 0.0), (0.16, 1.06, 0.0), 0.24),
    (1, (0.0, 1.02, 0.0), (0.0, 1.16, 0.0), 0.24),
    (2, (0.0, 1.14, 0.0), (0.0, 1.30, 0.0), 0.25),
    (3, (0.0, 1.28, 0.0), (0.0, 1.44, 0.0), 0.26),
    (4, (0.0, 1.44, 0.0), (0.0, 1.54, 0.0), 0.11),
    (5, (0.0, 1.52, 0.0), (0.0, 1.74, 0.0), 0.14),
    (6, (0.16, 1.40, 0.0), (0.26, 1.42, 0.0), 0.11),
    (7, (0.26, 1.42, 0.0), (0.28, 1.14, 0.0), 0.085),
    (8, (0.28, 1.16, 0.0), (0.28, 0.90, 0.0), 0.070),
    (9, (0.28, 0.92, 0.0), (0.28, 0.76, 0.0), 0.065),
    (10, (-0.16, 1.40, 0.0), (-0.26, 1.42, 0.0), 0.11),
    (11, (-0.26, 1.42, 0.0), (-0.28, 1.14, 0.0), 0.085),
    (12, (-0.28, 1.16, 0.0), (-0.28, 0.90, 0.0), 0.070),
    (13, (-0.28, 0.92, 0.0), (-0.28, 0.76, 0.0), 0.065),
    (14, (0.115, 0.94, 0.0), (0.115, 0.56, 0.0), 0.115),
    (15, (0.115, 0.58, 0.0), (0.115, 0.18, 0.0), 0.090),
    (16, (0.115, 0.20, 0.0), (0.115, 0.06, 0.04), 0.080),
    (17, (0.115, 0.06, 0.0), (0.115, 0.03, 0.14), 0.065),
    (18, (-0.115, 0.94, 0.0), (-0.115, 0.56, 0.0), 0.115),
    (19, (-0.115, 0.58, 0.0), (-0.115, 0.18, 0.0), 0.090),
    (20, (-0.115, 0.20, 0.0), (-0.115, 0.06, 0.04), 0.080),
    (21, (-0.115, 0.06, 0.0), (-0.115, 0.03, 0.14), 0.065),
]


def build_humanoid_skeleton(scale: float = 1.0) -> List[Bone]:
    bones: List[Bone] = []
    for name, parent, tr in BONE_DEFS:
        bones.append(
            Bone(
                name=name,
                translation=(tr[0] * scale, tr[1] * scale, tr[2] * scale),
                rotation=(0.0, 0.0, 0.0, 1.0),
                parent=parent,
            )
        )
    return bones


def bone_world_positions(bones: Sequence[Bone]) -> List[Tuple[float, float, float]]:
    out: List[Tuple[float, float, float]] = []
    for i, b in enumerate(bones):
        if b.parent < 0:
            out.append(tuple(b.translation))  # type: ignore[arg-type]
        else:
            p = out[b.parent]
            out.append((p[0] + b.translation[0], p[1] + b.translation[1], p[2] + b.translation[2]))
    return out


def _seg_point_distance(p: Sequence[float], a: Sequence[float], b: Sequence[float]) -> float:
    ax, ay, az = a
    bx, by, bz = b
    abx, aby, abz = bx - ax, by - ay, bz - az
    apx, apy, apz = p[0] - ax, p[1] - ay, p[2] - az
    denom = abx * abx + aby * aby + abz * abz
    t = 0.0 if denom < 1e-9 else max(0.0, min(1.0, (apx * abx + apy * aby + apz * abz) / denom))
    dx = apx - abx * t
    dy = apy - aby * t
    dz = apz - abz * t
    return math.sqrt(dx * dx + dy * dy + dz * dz)


def auto_skin(mesh: MeshData, bones: Sequence[Bone], falloff: float = 2.2,
              max_influences: int = 4) -> MeshData:
    """Pinta pesos por proximidade de cápsula óssea (smooth, sem sliding de pele)."""
    n = mesh.vertex_count
    joints: List[int] = []
    weights: List[float] = []
    for v in range(n):
        p = mesh.positions[v * 3 : v * 3 + 3]
        scored: List[Tuple[float, int]] = []
        for (bone_idx, a, b, radius) in _SKIN_CAPSULES:
            d = max(0.0, _seg_point_distance(p, a, b) - radius * 0.45)
            w = 1.0 / (1.0 + (d / max(radius, 1e-4)) ** falloff)
            scored.append((w, bone_idx))
        scored.sort(reverse=True)
        top = scored[:max_influences]
        total = sum(w for w, _ in top) or 1.0
        for w, bi in top:
            joints.append(bi)
            weights.append(w / total)
    mesh.joints = joints
    mesh.weights = weights
    return mesh


# ------------------------------------------------------------------ animações
@dataclass
class BoneChannel:
    """Definição procedural de um canal de animação."""
    bone: int
    axis: str = "x"            # eixo de rotação principal
    amp: float = 0.0           # amplitude (radianos)
    phase: float = 0.0         # fase (0..1 do ciclo)
    base: float = 0.0          # rotação base constante (radianos)
    yaw_amp: float = 0.0       # amplitude no eixo Y
    yaw_phase: float = 0.0
    roll_amp: float = 0.0
    bob_amp: float = 0.0       # deslocamento vertical (metros)
    bob_phase: float = 0.0
    forward_amp: float = 0.0   # deslocamento Z
    forward_phase: float = 0.0
    harmonic2: float = 0.0     # segunda harmônica (mais natural)


def _bone_index(name: str) -> int:
    for i, (n, _, _) in enumerate(BONE_DEFS):
        if n == name:
            return i
    raise KeyError(name)


# presets: (fps, duração, loop, canais)
def _locomotion(
    leg_amp: float, arm_amp: float, spine_amp: float, bob: float,
    duration: float, fps: int, base_leg: float = 0.0, base_arm: float = 0.0,
    knee_amp: float = 0.35, elbow_amp: float = 0.25,
) -> List[BoneChannel]:
    return [
        BoneChannel(_bone_index("UpperLeg_L"), "x", leg_amp, 0.0, base_leg),
        BoneChannel(_bone_index("UpperLeg_R"), "x", leg_amp, 0.5, base_leg),
        BoneChannel(_bone_index("LowerLeg_L"), "x", -knee_amp, 0.12, -abs(knee_amp) * 0.35),
        BoneChannel(_bone_index("LowerLeg_R"), "x", -knee_amp, 0.62, -abs(knee_amp) * 0.35),
        BoneChannel(_bone_index("UpperArm_L"), "x", -arm_amp, 0.5, base_arm, roll_amp=0.06),
        BoneChannel(_bone_index("UpperArm_R"), "x", -arm_amp, 0.0, base_arm, roll_amp=-0.06),
        BoneChannel(_bone_index("LowerArm_L"), "x", -elbow_amp, 0.55, -abs(elbow_amp) * 0.5),
        BoneChannel(_bone_index("LowerArm_R"), "x", -elbow_amp, 0.05, -abs(elbow_amp) * 0.5),
        BoneChannel(_bone_index("Hips"), "x", 0.0, 0.0, 0.0, yaw_amp=spine_amp * 0.5,
                    bob_amp=bob, bob_phase=0.0, harmonic2=0.0),
        BoneChannel(_bone_index("Spine"), "x", spine_amp, 0.0, 0.0, yaw_amp=-spine_amp),
        BoneChannel(_bone_index("Chest"), "x", spine_amp * 0.6, 0.5, 0.0),
        BoneChannel(_bone_index("Head"), "x", -spine_amp * 0.5, 0.25, 0.0, yaw_amp=spine_amp * 0.4),
        BoneChannel(_bone_index("Foot_L"), "x", knee_amp * 0.4, 0.05, 0.0),
        BoneChannel(_bone_index("Foot_R"), "x", knee_amp * 0.4, 0.55, 0.0),
        BoneChannel(_bone_index("Shoulder_L"), "z", 0.0, 0.0, 0.0, roll_amp=0.04),
        BoneChannel(_bone_index("Shoulder_R"), "z", 0.0, 0.0, 0.0, roll_amp=-0.04),
    ]


ANIMATION_PRESETS: Dict[str, Dict[str, object]] = {
    "idle": {
        "label": "Idle (respiração)", "fps": 60, "duration": 3.0, "loop": True,
        "channels": lambda: [
            BoneChannel(_bone_index("Spine"), "x", 0.022, 0.0, 0.0),
            BoneChannel(_bone_index("Spine1"), "x", 0.018, 0.1, 0.0),
            BoneChannel(_bone_index("Chest"), "x", 0.015, 0.2, 0.0),
            BoneChannel(_bone_index("Head"), "x", -0.02, 0.35, 0.0, yaw_amp=0.035, yaw_phase=0.15),
            BoneChannel(_bone_index("UpperArm_L"), "x", 0.012, 0.1, -0.05, roll_amp=0.05),
            BoneChannel(_bone_index("UpperArm_R"), "x", 0.012, 0.6, -0.05, roll_amp=-0.05),
            BoneChannel(_bone_index("LowerArm_L"), "x", 0.02, 0.2, -0.18),
            BoneChannel(_bone_index("LowerArm_R"), "x", 0.02, 0.7, -0.18),
            BoneChannel(_bone_index("Hips"), "x", 0.0, 0.0, 0.0, bob_amp=0.006),
            BoneChannel(_bone_index("UpperLeg_L"), "x", 0.008, 0.0, 0.0),
            BoneChannel(_bone_index("UpperLeg_R"), "x", 0.008, 0.5, 0.0),
        ],
    },
    "walk": {
        "label": "Walk", "fps": 60, "duration": 1.0, "loop": True,
        "channels": lambda: _locomotion(0.42, 0.30, 0.05, 0.018, 1.0, 60, 0.0, -0.06, 0.42, 0.28),
    },
    "run": {
        "label": "Run", "fps": 60, "duration": 0.7, "loop": True,
        "channels": lambda: _locomotion(0.72, 0.62, 0.10, 0.045, 0.7, 60, -0.10, -0.30, 0.95, 0.75),
    },
    "sprint": {
        "label": "Sprint", "fps": 60, "duration": 0.56, "loop": True,
        "channels": lambda: _locomotion(0.95, 0.85, 0.16, 0.06, 0.56, 60, -0.22, -0.55, 1.25, 1.0),
    },
    "jump": {
        "label": "Jump (agachar -> impulso -> queda)", "fps": 60, "duration": 1.2, "loop": False,
        "channels": "jump",
    },
    "attack_melee": {
        "label": "Ataque corpo-a-corpo", "fps": 60, "duration": 0.9, "loop": False,
        "channels": "attack",
    },
    "wave": {
        "label": "Aceno", "fps": 60, "duration": 1.6, "loop": False,
        "channels": "wave",
    },
    "dance": {
        "label": "Dança", "fps": 60, "duration": 2.4, "loop": True,
        "channels": "dance",
    },
    "death": {
        "label": "Morte (ragdoll guiado)", "fps": 60, "duration": 1.8, "loop": False,
        "channels": "death",
    },
    "crouch": {
        "label": "Agachar", "fps": 60, "duration": 1.0, "loop": False,
        "channels": "crouch",
    },
}


def _keyed_channels(kind: str, frames: int) -> List[BoneChannel]:
    """Canais 'roteirizados' (não-cíclicos): usamos uma função de envelope no tempo."""
    return []


def _pose_track(
    name: str, duration: float, fps: int, keyfn
) -> List[AnimationTrack]:
    """
    keyfn(t_norm, bone_index) -> (euler_pitch, euler_yaw, euler_roll, dy, dz)
    Gera keyframes igualmente espaçados (fps de amostragem limitado a 30 para
    manter o .glb enxuto -- engines interpolam linearmente entre eles).
    """
    frames = max(2, int(round(duration * min(fps, 30))) + 1)
    times = [i * duration / (frames - 1) for i in range(frames)]
    per_bone: Dict[int, Dict[str, list]] = {}
    for i, t in enumerate(times):
        tn = t / duration if duration else 0.0
        for bone, (pitch, yaw, roll, dy, dz) in keyfn(tn, t).items():
            d = per_bone.setdefault(bone, {"r": [], "t": []})
            d["r"].append(m3d.quat_from_euler(pitch, yaw, roll))
            d["t"].append((0.0, dy, dz))
    tracks = []
    for bone, d in per_bone.items():
        tracks.append(
            AnimationTrack(bone=bone, times=times, rotations=d["r"], translations=d["t"])
        )
    return tracks


def _jump_keys(tn: float, t: float) -> Dict[int, Tuple[float, float, float, float, float]]:
    H = _bone_index("Hips")
    UL_L, UL_R = _bone_index("UpperLeg_L"), _bone_index("UpperLeg_R")
    LL_L, LL_R = _bone_index("LowerLeg_L"), _bone_index("LowerLeg_R")
    UA_L, UA_R = _bone_index("UpperArm_L"), _bone_index("UpperArm_R")
    LA_L, LA_R = _bone_index("LowerArm_L"), _bone_index("LowerArm_R")
    SP = _bone_index("Spine")
    F_L, F_R = _bone_index("Foot_L"), _bone_index("Foot_R")

    if tn < 0.25:  # agacha
        k = tn / 0.25
        hips_dy = -0.28 * k
        leg = 0.85 * k
        knee = -1.35 * k
        spine = 0.35 * k
        arm = 0.55 * k
        elbow = -0.5 * k
    elif tn < 0.42:  # impulso
        k = (tn - 0.25) / 0.17
        hips_dy = -0.28 + 0.34 * k
        leg = 0.85 - 1.15 * k
        knee = -1.35 + 1.45 * k
        spine = 0.35 - 0.5 * k
        arm = 0.55 - 2.35 * k
        elbow = -0.5 + 0.4 * k
    elif tn < 0.72:  # no ar
        k = (tn - 0.42) / 0.30
        hips_dy = 0.06 - 0.02 * k
        leg = -0.30 + 0.35 * k
        knee = 0.10 - 0.55 * k
        spine = -0.15
        arm = -1.80 + 0.35 * k
        elbow = -0.10 - 0.35 * k
    else:  # aterrissagem
        k = min(1.0, (tn - 0.72) / 0.28)
        ease = 1 - (1 - k) ** 2
        hips_dy = 0.04 - 0.30 * math.sin(math.pi * min(1.0, k * 1.3)) * (1 - ease * 0.6)
        leg = 0.05 + 0.75 * math.sin(math.pi * min(1.0, k * 1.2))
        knee = -0.45 - 0.85 * math.sin(math.pi * min(1.0, k * 1.2))
        spine = -0.15 + 0.45 * math.sin(math.pi * min(1.0, k * 1.2))
        arm = -1.45 + 1.9 * ease
        elbow = -0.45 + 0.05 * ease

    return {
        H: (0.0, 0.0, 0.0, hips_dy, 0.0),
        UL_L: (leg, 0, 0, 0, 0), UL_R: (leg, 0, 0, 0, 0),
        LL_L: (knee, 0, 0, 0, 0), LL_R: (knee, 0, 0, 0, 0),
        UA_L: (arm, 0, 0.18, 0, 0), UA_R: (arm, 0, -0.18, 0, 0),
        LA_L: (elbow, 0, 0, 0, 0), LA_R: (elbow, 0, 0, 0, 0),
        SP: (spine, 0, 0, 0, 0),
        F_L: (-knee * 0.45, 0, 0, 0, 0), F_R: (-knee * 0.45, 0, 0, 0, 0),
    }


def _attack_keys(tn: float, t: float) -> Dict[int, Tuple[float, float, float, float, float]]:
    UA_R = _bone_index("UpperArm_R")
    LA_R = _bone_index("LowerArm_R")
    SH_R = _bone_index("Shoulder_R")
    SP, SP1, CH = _bone_index("Spine"), _bone_index("Spine1"), _bone_index("Chest")
    H = _bone_index("Hips")
    UL_L, UL_R = _bone_index("UpperLeg_L"), _bone_index("UpperLeg_R")

    if tn < 0.35:  # wind-up
        k = tn / 0.35
        e = 1 - (1 - k) ** 2
        arm = -2.3 * e
        elbow = -1.5 * e
        yaw = -0.55 * e
        shoulder = 0.0
    elif tn < 0.5:  # golpe
        k = (tn - 0.35) / 0.15
        e = k * k
        arm = -2.3 + 3.3 * e
        elbow = -1.5 + 1.55 * e
        yaw = -0.55 + 1.05 * e
        shoulder = -0.3 * e
    else:  # recovery
        k = min(1.0, (tn - 0.5) / 0.5)
        e = 1 - (1 - k) ** 3
        arm = 1.0 - 1.0 * e
        elbow = 0.05 - 0.25 * e
        yaw = 0.5 - 0.5 * e
        shoulder = -0.3 + 0.3 * e
    return {
        UA_R: (arm, 0, shoulder, 0, 0),
        LA_R: (elbow, 0, 0, 0, 0),
        SH_R: (0, 0, -0.15, 0, 0),
        SP: (0.10, yaw * 0.5, 0, 0, 0),
        SP1: (0.05, yaw * 0.3, 0, 0, 0),
        CH: (0.0, yaw * 0.2, 0, 0, 0),
        H: (0.0, yaw * 0.35, 0, -0.03 * math.sin(math.pi * tn), 0.0),
        UL_L: (0.35 * math.sin(math.pi * tn), 0, 0, 0, 0),
        UL_R: (-0.25 * math.sin(math.pi * tn), 0, 0, 0, 0),
    }


def _wave_keys(tn: float, t: float) -> Dict[int, Tuple[float, float, float, float, float]]:
    UA_R = _bone_index("UpperArm_R")
    LA_R = _bone_index("LowerArm_R")
    HD = _bone_index("Head")
    raise_ = math.sin(math.pi * min(1.0, tn / 0.25)) if tn < 0.25 else (
        math.sin(math.pi * min(1.0, (1 - tn) / 0.25)) if tn > 0.75 else 1.0
    )
    wave = math.sin(tn * math.pi * 8) * raise_
    return {
        UA_R: (-2.6 * raise_, 0, -0.45 * raise_, 0, 0),
        LA_R: (-0.35 * raise_ + wave * 0.55, 0, wave * 0.35, 0, 0),
        HD: (0, wave * 0.06, wave * 0.05, 0, 0),
    }


def _dance_keys(tn: float, t: float) -> Dict[int, Tuple[float, float, float, float, float]]:
    H = _bone_index("Hips")
    SP, CH = _bone_index("Spine"), _bone_index("Chest")
    UA_L, UA_R = _bone_index("UpperArm_L"), _bone_index("UpperArm_R")
    LA_L, LA_R = _bone_index("LowerArm_L"), _bone_index("LowerArm_R")
    UL_L, UL_R = _bone_index("UpperLeg_L"), _bone_index("UpperLeg_R")
    LL_L, LL_R = _bone_index("LowerLeg_L"), _bone_index("LowerLeg_R")
    HD = _bone_index("Head")
    w = tn * math.pi * 4
    bob = abs(math.sin(w)) * 0.09
    sway = math.sin(w * 0.5) * 0.28
    return {
        H: (0, sway, math.sin(w) * 0.10, -bob, 0),
        SP: (0.08, -sway * 0.6, 0, 0, 0),
        CH: (0.05, -sway * 0.3, 0, 0, 0),
        HD: (0, sway * 0.25, 0, 0, 0),
        UA_L: (-1.1 + math.sin(w) * 0.7, 0, 0.75 + math.sin(w * 0.5) * 0.25, 0, 0),
        UA_R: (-1.1 + math.sin(w + math.pi) * 0.7, 0, -0.75 - math.sin(w * 0.5) * 0.25, 0, 0),
        LA_L: (-0.9 + math.sin(w + 0.6) * 0.5, 0, 0, 0, 0),
        LA_R: (-0.9 + math.sin(w + 0.6 + math.pi) * 0.5, 0, 0, 0, 0),
        UL_L: (math.sin(w) * 0.35, 0, 0.06, 0, 0),
        UL_R: (math.sin(w + math.pi) * 0.35, 0, -0.06, 0, 0),
        LL_L: (-abs(math.sin(w)) * 0.45, 0, 0, 0, 0),
        LL_R: (-abs(math.sin(w + math.pi)) * 0.45, 0, 0, 0, 0),
    }


def _death_keys(tn: float, t: float) -> Dict[int, Tuple[float, float, float, float, float]]:
    H = _bone_index("Hips")
    SP, SP1, CH = _bone_index("Spine"), _bone_index("Spine1"), _bone_index("Chest")
    HD, NK = _bone_index("Head"), _bone_index("Neck")
    UA_L, UA_R = _bone_index("UpperArm_L"), _bone_index("UpperArm_R")
    LA_L, LA_R = _bone_index("LowerArm_L"), _bone_index("LowerArm_R")
    UL_L, UL_R = _bone_index("UpperLeg_L"), _bone_index("UpperLeg_R")
    LL_L, LL_R = _bone_index("LowerLeg_L"), _bone_index("LowerLeg_R")

    k = min(1.0, tn / 0.75)
    e = 1 - (1 - k) ** 3           # queda
    k2 = max(0.0, (tn - 0.7) / 0.3)
    e2 = min(1.0, k2) * (1 - math.exp(-4 * k2)) if k2 > 0 else 0.0
    stagger = math.sin(tn * 18) * max(0.0, 0.35 - tn) * 0.6
    return {
        H: (0.35 * e, stagger * 0.3, 0.25 * e, -0.92 * e, 0.18 * e),
        SP: (0.30 * e, stagger, 0.0, 0, 0),
        SP1: (0.22 * e, stagger * 0.6, 0.0, 0, 0),
        CH: (0.18 * e, 0, 0, 0, 0),
        NK: (0.2 * e2, 0, 0, 0, 0),
        HD: (0.45 * e2, 0.2 * e, 0, 0, 0),
        UA_L: (-0.9 * e, 0, 0.9 * e + stagger, 0, 0),
        UA_R: (-1.15 * e, 0, -0.75 * e, 0, 0),
        LA_L: (-1.1 * e, 0, 0, 0, 0),
        LA_R: (-0.85 * e, 0, 0, 0, 0),
        UL_L: (0.85 * e, 0, -0.22 * e, 0, 0),
        UL_R: (0.55 * e, 0, 0.28 * e, 0, 0),
        LL_L: (-1.15 * e, 0, 0, 0, 0),
        LL_R: (-1.35 * e, 0, 0, 0, 0),
    }


def _crouch_keys(tn: float, t: float) -> Dict[int, Tuple[float, float, float, float, float]]:
    H = _bone_index("Hips")
    SP, CH = _bone_index("Spine"), _bone_index("Chest")
    UL_L, UL_R = _bone_index("UpperLeg_L"), _bone_index("UpperLeg_R")
    LL_L, LL_R = _bone_index("LowerLeg_L"), _bone_index("LowerLeg_R")
    UA_L, UA_R = _bone_index("UpperArm_L"), _bone_index("UpperArm_R")
    F_L, F_R = _bone_index("Foot_L"), _bone_index("Foot_R")
    down = math.sin(math.pi * min(1.0, tn))  # desce e sobe
    return {
        H: (0, 0, 0, -0.42 * down, 0),
        SP: (0.28 * down, 0, 0, 0, 0),
        CH: (0.12 * down, 0, 0, 0, 0),
        UL_L: (1.05 * down, 0, 0.12 * down, 0, 0),
        UL_R: (1.05 * down, 0, -0.12 * down, 0, 0),
        LL_L: (-1.75 * down, 0, 0, 0, 0),
        LL_R: (-1.75 * down, 0, 0, 0, 0),
        UA_L: (-0.35 * down, 0, 0.2 * down, 0, 0),
        UA_R: (-0.35 * down, 0, -0.2 * down, 0, 0),
        F_L: (0.7 * down, 0, 0, 0, 0),
        F_R: (0.7 * down, 0, 0, 0, 0),
    }


_KEYFN = {
    "jump": _jump_keys,
    "attack": _attack_keys,
    "wave": _wave_keys,
    "dance": _dance_keys,
    "death": _death_keys,
    "crouch": _crouch_keys,
}


def make_animation(name: str = "walk", fps: int = 60, speed: float = 1.0,
                   samples_per_cycle: int = 32) -> Tuple[Animation, Dict[str, object]]:
    preset = ANIMATION_PRESETS.get(name) or ANIMATION_PRESETS["idle"]
    duration = float(preset["duration"]) / max(0.1, speed)
    fps = int(preset.get("fps", fps))
    channels = preset["channels"]

    if isinstance(channels, str):  # animação roteirizada (keyed)
        tracks = _pose_track(name, duration, fps, _KEYFN[channels])
        meta = {"kind": "keyed", "frames": max(2, int(round(duration * min(fps, 30))) + 1)}
    else:
        channels = channels()  # presets cíclicos usam uma factory
        frames = max(4, int(round(duration * fps)) + 1)
        frames = min(frames, samples_per_cycle * 8)
        times = [i * duration / (frames - 1) for i in range(frames)]
        tracks = []
        for ch in channels:
            rots: List[Tuple[float, float, float, float]] = []
            trans: List[Tuple[float, float, float]] = []
            for t in times:
                ph = (t / duration) % 1.0
                ang = 2 * math.pi * (ph + ch.phase)
                pitch = ch.base + ch.amp * math.sin(ang)
                if ch.harmonic2:
                    pitch += ch.harmonic2 * math.sin(2 * ang)
                yaw = ch.yaw_amp * math.sin(2 * math.pi * (ph + ch.yaw_phase))
                roll = ch.roll_amp * math.sin(2 * math.pi * (ph + ch.phase * 0.5))
                rots.append(m3d.quat_from_euler(pitch, yaw, roll))
                dy = ch.bob_amp * math.sin(2 * math.pi * (2 * ph + ch.bob_phase))
                dz = ch.forward_amp * ph
                trans.append((0.0, dy, dz))
            tracks.append(AnimationTrack(bone=ch.bone, times=times, rotations=rots, translations=trans))
        meta = {"kind": "procedural", "frames": frames}

    anim = Animation(name=name, tracks=tracks)
    info = {
        "name": name,
        "label": preset.get("label", name),
        "fps": fps,
        "duration": round(duration, 4),
        "loop": bool(preset.get("loop", True)),
        "tracks": len(tracks),
        "bones_animated": len({t.bone for t in tracks}),
        **meta,
    }
    return anim, info


def build_rigged_glb(
    animations: Sequence[str] = ("idle", "walk", "run", "jump"),
    model_type: str = "hero",
    name: str = "ArkherCharacter",
    detail: int = 2,
    material: Optional[Material] = None,
    fps: int = 60,
    speed: float = 1.0,
) -> Tuple[bytes, Dict[str, object]]:
    mesh = make_model(model_type, name=name, detail=detail)
    bones = build_humanoid_skeleton()
    auto_skin(mesh, bones)
    if material is None:
        material = Material(name=f"{name}_skin", base_color=(0.72, 0.55, 0.45, 1.0), roughness=0.62, metallic=0.02)
    mesh.material = material

    b = GlbBuilder()
    mat_idx = b.add_material(material)
    mesh_idx = b.add_mesh(mesh, mat_idx)

    bone_nodes: List[int] = []
    for bone in bones:
        bone_nodes.append(
            b.add_node(bone.name, translation=bone.translation, rotation=bone.rotation)
        )
    for i, bone in enumerate(bones):
        if bone.parent >= 0:
            b._nodes[bone_nodes[bone.parent]].setdefault("children", []).append(bone_nodes[i])

    skin_idx = b.add_skin(f"{name}_skeleton", bones, root_node=bone_nodes[0])
    mesh_node = b.add_node(f"{name}_mesh", mesh=mesh_idx, skin=skin_idx)
    root = b.add_node(name, children=[mesh_node] + bone_nodes)

    infos = []
    for a in animations:
        anim, info = make_animation(a, fps=fps, speed=speed)
        # os tracks apontam para índices de osso -> converte para índices de nó
        for tr in anim.tracks:
            tr.bone = bone_nodes[tr.bone]
        b.add_animation(anim)
        infos.append(info)

    data = b.build(scene_name=name, root_nodes=[root], asset_name=name)
    stats = {
        "bones": len(bones),
        "bone_names": [bn.name for bn in bones],
        "vertices": mesh.vertex_count,
        "triangles": mesh.triangle_count,
        "influences_per_vertex": 4,
        "animations": infos,
        "bytes": len(data),
    }
    return data, stats


# ------------------------------------------------------------- export engines
def export_godot_animation_library(animations: Sequence[str], glb_path: str = "res://assets/models/character.glb",
                                   fps: int = 60) -> str:
    """Gera um AnimationLibrary (.tres) com os cortes de animação do GLB importado."""
    lines = [
        '; Animações geradas pelo Arkher AI',
        '; Aponta para os takes dentro do .glb importado pelo Godot.',
        '[gd_resource type="AnimationLibrary" load_steps=%d format=3]' % (len(animations) + 1),
        '',
    ]
    for i, a in enumerate(animations):
        anim, info = make_animation(a, fps=fps)
        lines.append(f'[ext_resource type="Animation" path="{glb_path}:{a}" id="{i + 1}_{a}"]')
    lines.append('')
    lines.append('[resource]')
    lines.append('_data = {')
    entries = []
    for i, a in enumerate(animations):
        entries.append(f'"{a}": ExtResource("{i + 1}_{a}")')
    lines.append(",\n".join(entries))
    lines.append('}')
    lines.append('')
    return "\n".join(lines)


def export_roblox_keyframe_sequence(name: str = "walk", fps: int = 60, speed: float = 1.0) -> str:
    """
    Gera um KeyframeSequence (.rbxlx / XML) importável no Roblox Studio (R15).

    Estrutura hierárquica de Poses idêntica à que o Studio produz:
      HumanoidRootPart -> LowerTorso(Root) -> UpperTorso(Waist) -> Head(Neck) + braços
                                            -> pernas (LeftHip / RightHip)

    Como importar: Roblox Studio -> Avatar Importer (Plugin) ou
    Asset Manager -> Bulk Import -> selecione o .rbxlx -> depois Animation Editor.
    """
    anim, info = make_animation(name, fps=fps, speed=speed)
    bones = build_humanoid_skeleton()

    # motor Roblox -> osso do nosso esqueleto
    motor_of_bone = {
        "Spine": "Waist", "Spine1": "Waist", "Chest": "Waist",
        "Neck": "Neck", "Head": "Neck",
        "Shoulder_L": "LeftShoulder", "UpperArm_L": "LeftShoulder",
        "LowerArm_L": "LeftElbow", "Hand_L": "LeftWrist",
        "Shoulder_R": "RightShoulder", "UpperArm_R": "RightShoulder",
        "LowerArm_R": "RightElbow", "Hand_R": "RightWrist",
        "UpperLeg_L": "LeftHip", "LowerLeg_L": "LeftKnee", "Foot_L": "LeftAnkle",
        "Toes_L": "LeftAnkle",
        "UpperLeg_R": "RightHip", "LowerLeg_R": "RightKnee", "Foot_R": "RightAnkle",
        "Toes_R": "RightAnkle",
    }

    # (parte, motor, filhos)
    tree: List[Tuple[str, str, List[str]]] = [
        ("HumanoidRootPart", "Root", ["LowerTorso"]),
        ("LowerTorso", "Root", ["UpperTorso", "LeftUpperLeg", "RightUpperLeg"]),
        ("UpperTorso", "Waist", ["Head", "LeftUpperArm", "RightUpperArm"]),
        ("Head", "Neck", []),
        ("LeftUpperArm", "LeftShoulder", ["LeftLowerArm"]),
        ("LeftLowerArm", "LeftElbow", ["LeftHand"]),
        ("LeftHand", "LeftWrist", []),
        ("RightUpperArm", "RightShoulder", ["RightLowerArm"]),
        ("RightLowerArm", "RightElbow", ["RightHand"]),
        ("RightHand", "RightWrist", []),
        ("LeftUpperLeg", "LeftHip", ["LeftLowerLeg"]),
        ("LeftLowerLeg", "LeftKnee", ["LeftFoot"]),
        ("LeftFoot", "LeftAnkle", []),
        ("RightUpperLeg", "RightHip", ["RightLowerLeg"]),
        ("RightLowerLeg", "RightKnee", ["RightFoot"]),
        ("RightFoot", "RightAnkle", []),
    ]
    children_of = {part: kids for (part, _motor, kids) in tree}
    motor_of_part = {part: motor for (part, motor, _k) in tree}

    # amostra de rotações por osso, indexadas por tempo
    samples: Dict[int, List[Tuple[float, Tuple[float, float, float, float], Tuple[float, float, float]]]] = {}
    for tr in anim.tracks:
        lst = samples.setdefault(tr.bone, [])
        for i, t in enumerate(tr.times):
            rot = tr.rotations[i] if tr.rotations else (0.0, 0.0, 0.0, 1.0)
            trans = tr.translations[i] if tr.translations else (0.0, 0.0, 0.0)
            lst.append((t, rot, trans))

    def sample(bone_idx: int, t: float):
        lst = samples.get(bone_idx)
        if not lst:
            return (0.0, 0.0, 0.0, 1.0), (0.0, 0.0, 0.0)
        # busca o par mais próximo e interpola
        best_i = 0
        best_d = abs(lst[0][0] - t)
        for i in range(1, len(lst)):
            d = abs(lst[i][0] - t)
            if d < best_d:
                best_d, best_i = d, i
        return lst[best_i][1], lst[best_i][2]

    duration = float(info["duration"])
    frame_count = max(1, int(round(duration * fps)))
    uid = [0]

    def _ref(prefix: str) -> str:
        uid[0] += 1
        return f"{prefix}{uid[0]}"

    def cframe_xml(part: str, t: float) -> str:
        motor = motor_of_part.get(part, "Root")
        # agrega rotações dos ossos que dirigem esse motor
        qx = qy = qz = qw = 0.0
        px = py = pz = 0.0
        count = 0
        for bone_idx, bone in enumerate(bones):
            if bone_idx == 0 and motor == "Root":
                rot, trans = sample(bone_idx, t)
                px, py, pz = trans
            if motor_of_bone.get(bone.name) != motor:
                continue
            rot, _tr = sample(bone_idx, t)
            qx += rot[0]; qy += rot[1]; qz += rot[2]; qw += rot[3]
            count += 1
        if count:
            q = m3d.quat_normalize((qx / count, qy / count, qz / count, qw / count))
        else:
            q = (0.0, 0.0, 0.0, 1.0)
        mm = m3d.quat_to_mat4(q)
        return (
            f'<X>{px:.6f}</X><Y>{py:.6f}</Y><Z>{pz:.6f}</Z>'
            f'<R00>{mm[0]:.6f}</R00><R01>{mm[4]:.6f}</R01><R02>{mm[8]:.6f}</R02>'
            f'<R10>{mm[1]:.6f}</R10><R11>{mm[5]:.6f}</R11><R12>{mm[9]:.6f}</R12>'
            f'<R20>{mm[2]:.6f}</R20><R21>{mm[6]:.6f}</R21><R22>{mm[10]:.6f}</R22>'
        )

    def emit_pose(part: str, t: float, indent: str) -> List[str]:
        lines = [f'{indent}<Item class="Pose" referent="{_ref("POSE")}">']
        lines.append(f"{indent}  <Properties>")
        lines.append(f'{indent}    <string name="Name">{part}</string>')
        lines.append(f'{indent}    <CoordinateFrame name="CFrame">{cframe_xml(part, t)}</CoordinateFrame>')
        lines.append(f'{indent}    <float name="Weight">1</float>')
        lines.append(f'{indent}    <token name="EasingStyle">2</token>')
        lines.append(f'{indent}    <token name="EasingDirection">1</token>')
        lines.append(f"{indent}  </Properties>")
        for child in children_of.get(part, []):
            lines.extend(emit_pose(child, t, indent + "  "))
        lines.append(f"{indent}</Item>")
        return lines

    out = [
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
        f'  <Item class="KeyframeSequence" referent="{_ref("KS")}">',
        '    <Properties>',
        f'      <string name="Name">{name}_arkher</string>',
        f'      <string name="AuthorName">Arkher AI</string>',
        f'      <bool name="Loop">{"true" if info["loop"] else "false"}</bool>',
        '      <token name="Priority">3</token>',
        '    </Properties>',
    ]
    for f in range(frame_count + 1):
        t = f * duration / frame_count
        out.append(f'    <Item class="Keyframe" referent="{_ref("KF")}">')
        out.append('      <Properties>')
        out.append(f'        <float name="Time">{t:.6f}</float>')
        out.append('      </Properties>')
        out.extend(emit_pose("HumanoidRootPart", t, "      "))
        out.append('    </Item>')
    out.append('  </Item>')
    out.append('</roblox>')
    return "\n".join(out)

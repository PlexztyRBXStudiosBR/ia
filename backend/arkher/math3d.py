"""
Matemática 3D mínima (vetores, matrizes 4x4, quatérnions) em Python puro.
Suficiente para gerar .glb com skinning e animação sem depender de numpy.
"""
from __future__ import annotations

import math
from typing import List, Sequence, Tuple

Vec3 = Tuple[float, float, float]
Quat = Tuple[float, float, float, float]  # (x, y, z, w)
Mat4 = List[float]  # 16 floats, column-major (como o glTF espera)

__all__ = [
    "identity", "translation", "scale", "rotation_x", "rotation_y", "rotation_z",
    "rotation_axis", "look_at", "multiply", "transform_point", "invert_rigid",
    "quat_from_axis_angle", "quat_multiply", "quat_from_euler", "quat_to_mat4",
    "quat_slerp", "quat_normalize", "normalize", "sub", "add", "cross", "dot",
    "length", "mat4_from_trs",
]


def identity() -> Mat4:
    return [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]


def translation(x: float, y: float, z: float) -> Mat4:
    m = identity()
    m[12], m[13], m[14] = float(x), float(y), float(z)
    return m


def scale(x: float, y: float | None = None, z: float | None = None) -> Mat4:
    y = x if y is None else y
    z = x if z is None else z
    m = identity()
    m[0], m[5], m[10] = float(x), float(y), float(z)
    return m


def rotation_x(a: float) -> Mat4:
    c, s = math.cos(a), math.sin(a)
    return [1, 0, 0, 0, 0, c, s, 0, 0, -s, c, 0, 0, 0, 0, 1]


def rotation_y(a: float) -> Mat4:
    c, s = math.cos(a), math.sin(a)
    return [c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, 0, 0, 0, 1]


def rotation_z(a: float) -> Mat4:
    c, s = math.cos(a), math.sin(a)
    return [c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]


def rotation_axis(axis: Vec3, angle: float) -> Mat4:
    x, y, z = normalize(axis)
    c, s = math.cos(angle), math.sin(angle)
    t = 1.0 - c
    return [
        t * x * x + c, t * x * y + s * z, t * x * z - s * y, 0,
        t * x * y - s * z, t * y * y + c, t * y * z + s * x, 0,
        t * x * z + s * y, t * y * z - s * x, t * z * z + c, 0,
        0, 0, 0, 1,
    ]


def multiply(a: Mat4, b: Mat4) -> Mat4:
    out = [0.0] * 16
    for col in range(4):
        for row in range(4):
            s = 0.0
            for k in range(4):
                s += a[k * 4 + row] * b[col * 4 + k]
            out[col * 4 + row] = s
    return out


def transform_point(m: Mat4, p: Vec3) -> Vec3:
    x, y, z = p
    return (
        m[0] * x + m[4] * y + m[8] * z + m[12],
        m[1] * x + m[5] * y + m[9] * z + m[13],
        m[2] * x + m[6] * y + m[10] * z + m[14],
    )


def invert_rigid(m: Mat4) -> Mat4:
    """Inversa de matriz rígida (rotação ortonormal + translação)."""
    r = [m[0], m[1], m[2], m[4], m[5], m[6], m[8], m[9], m[10]]
    t = (m[12], m[13], m[14])
    # transposta da rotação
    rt = [r[0], r[3], r[6], r[1], r[4], r[7], r[2], r[5], r[8]]
    out = [
        rt[0], rt[1], rt[2], 0,
        rt[3], rt[4], rt[5], 0,
        rt[6], rt[7], rt[8], 0,
        0, 0, 0, 1,
    ]
    out[12] = -(rt[0] * t[0] + rt[3] * t[1] + rt[6] * t[2])
    out[13] = -(rt[1] * t[0] + rt[4] * t[1] + rt[7] * t[2])
    out[14] = -(rt[2] * t[0] + rt[5] * t[1] + rt[8] * t[2])
    return out


def mat4_from_trs(t: Vec3, q: Quat, s: Vec3) -> Mat4:
    rot = quat_to_mat4(q)
    out = [0.0] * 16
    for col in range(3):
        f = s[col]
        out[col * 4 + 0] = rot[col * 4 + 0] * f
        out[col * 4 + 1] = rot[col * 4 + 1] * f
        out[col * 4 + 2] = rot[col * 4 + 2] * f
    out[3] = out[7] = out[11] = 0.0
    out[12], out[13], out[14] = t
    out[15] = 1.0
    return out


def look_at(eye: Vec3, target: Vec3, up: Vec3 = (0, 1, 0)) -> Mat4:
    f = normalize(sub(target, eye))
    s = normalize(cross(f, up))
    u = cross(s, f)
    return [
        s[0], u[0], -f[0], 0,
        s[1], u[1], -f[1], 0,
        s[2], u[2], -f[2], 0,
        -dot(s, eye), -dot(u, eye), dot(f, eye), 1,
    ]


# ---------------------------------------------------------------- vetores
def add(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def dot(a: Vec3, b: Vec3) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a: Vec3, b: Vec3) -> Vec3:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def length(a: Vec3) -> float:
    return math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])


def normalize(a: Sequence[float]) -> Vec3:
    n = math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])
    if n < 1e-12:
        return (0.0, 0.0, 0.0)
    return (a[0] / n, a[1] / n, a[2] / n)


# ------------------------------------------------------------- quatérnions
def quat_from_axis_angle(axis: Vec3, angle: float) -> Quat:
    ax = normalize(axis)
    h = angle * 0.5
    s = math.sin(h)
    return (ax[0] * s, ax[1] * s, ax[2] * s, math.cos(h))


def quat_from_euler(pitch: float, yaw: float, roll: float) -> Quat:
    """Rotação YXZ (yaw -> pitch -> roll), ângulos em radianos."""
    qx = quat_from_axis_angle((1, 0, 0), pitch)
    qy = quat_from_axis_angle((0, 1, 0), yaw)
    qz = quat_from_axis_angle((0, 0, 1), roll)
    return quat_multiply(quat_multiply(qy, qx), qz)


def quat_multiply(a: Quat, b: Quat) -> Quat:
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    )


def quat_normalize(q: Quat) -> Quat:
    n = math.sqrt(q[0] ** 2 + q[1] ** 2 + q[2] ** 2 + q[3] ** 2) or 1.0
    return (q[0] / n, q[1] / n, q[2] / n, q[3] / n)


def quat_slerp(a: Quat, b: Quat, t: float) -> Quat:
    d = sum(x * y for x, y in zip(a, b))
    if d < 0.0:
        b = tuple(-x for x in b)  # type: ignore[assignment]
        d = -d
    if d > 0.9995:
        return quat_normalize(tuple(a[i] + (b[i] - a[i]) * t for i in range(4)))  # type: ignore[arg-type,return-value]
    th0 = math.acos(max(-1.0, min(1.0, d)))
    s = math.sin(th0) or 1.0
    th = th0 * t
    s0 = math.sin(th0 - th) / s
    s1 = math.sin(th) / s
    return quat_normalize(tuple(a[i] * s0 + b[i] * s1 for i in range(4)))  # type: ignore[arg-type,return-value]


def quat_to_mat4(q: Quat) -> Mat4:
    x, y, z, w = q
    x2, y2, z2 = x + x, y + y, z + z
    xx, xy, xz = x * x2, x * y2, x * z2
    yy, yz, zz = y * y2, y * z2, z * z2
    wx, wy, wz = w * x2, w * y2, w * z2
    return [
        1 - (yy + zz), xy + wz, xz - wy, 0,
        xy - wz, 1 - (xx + zz), yz + wx, 0,
        xz + wy, yz - wx, 1 - (xx + yy), 0,
        0, 0, 0, 1,
    ]

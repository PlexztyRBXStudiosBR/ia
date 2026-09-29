"""
Encoder PNG em Python puro (stdlib: struct + zlib).

Suporta 8-bit RGB / RGBA / grayscale, com ou sem numpy.
É o fallback usado quando Pillow não está instalado -- o servidor do Arkher AI
não tem dependência obrigatória nenhuma.

Uso:
    png_bytes = encode_rgba(rows, width, height)      # rows: bytes/bytearray (w*h*4)
    png_bytes = encode_gray(rows, width, height)
"""
from __future__ import annotations

import struct
import zlib
from typing import Iterable, List, Sequence

__all__ = ["encode_rgba", "encode_rgb", "encode_gray", "encode_channels"]

_COLOR_TYPES = {"gray": 0, "rgb": 2, "rgba": 6}
_N_CHANNELS = {"gray": 1, "rgb": 3, "rgba": 4}


def _chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def _raw_scanlines(pixels: bytes, width: int, height: int, nch: int) -> bytearray:
    """Adiciona o byte de filtro (0 = None) no início de cada scanline."""
    stride = width * nch
    out = bytearray((stride + 1) * height)
    pos = 0
    for y in range(height):
        out[pos] = 0
        src = y * stride
        out[pos + 1 : pos + 1 + stride] = pixels[src : src + stride]
        pos += stride + 1
    return out


def _encode(pixels: bytes, width: int, height: int, mode: str, level: int = 6) -> bytes:
    if mode not in _COLOR_TYPES:
        raise ValueError(f"modo PNG inválido: {mode}")
    nch = _N_CHANNELS[mode]
    expected = width * height * nch
    if len(pixels) != expected:
        raise ValueError(
            f"buffer tem {len(pixels)} bytes, esperado {expected} ({width}x{height}x{nch})"
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, _COLOR_TYPES[mode], 0, 0, 0)
    raw = _raw_scanlines(pixels, width, height, nch)
    # nível 1 é MUITO mais rápido em texturas 8k/16k e comprime quase igual
    idat = zlib.compress(bytes(raw), level)

    return (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", ihdr)
        + _chunk(b"IDAT", idat)
        + _chunk(b"IEND", b"")
    )


def encode_rgba(pixels: bytes, width: int, height: int, level: int = 1) -> bytes:
    return _encode(pixels, width, height, "rgba", level)


def encode_rgb(pixels: bytes, width: int, height: int, level: int = 1) -> bytes:
    return _encode(pixels, width, height, "rgb", level)


def encode_gray(pixels: bytes, width: int, height: int, level: int = 1) -> bytes:
    return _encode(pixels, width, height, "gray", level)


def encode_channels(
    channels: Sequence[Sequence[int]], width: int, height: int, level: int = 1
) -> bytes:
    """
    Codifica a partir de uma lista de canais (cada canal é uma sequência plana
    de w*h valores 0..255). 1 canal -> gray, 3 -> RGB, 4 -> RGBA.
    """
    n = len(channels)
    if n == 1:
        return encode_gray(bytes(bytearray(channels[0])), width, height, level)
    if n not in (3, 4):
        raise ValueError("use 1, 3 ou 4 canais")
    step = width * height
    out = bytearray(step * n)
    for idx in range(step):
        base = idx * n
        for c in range(n):
            out[base + c] = channels[c][idx] & 0xFF
    mode = "rgb" if n == 3 else "rgba"
    return _encode(bytes(out), width, height, mode, level)


def encode_float_channel(
    values: Iterable[float], width: int, height: int, mode: str = "gray", level: int = 1
) -> bytes:
    """Converte floats 0..1 em bytes e codifica."""
    data = bytearray(width * height)
    for i, v in enumerate(values):
        if i >= width * height:
            break
        v = 0.0 if v != v else v  # NaN
        data[i] = 0 if v <= 0 else (255 if v >= 1 else int(v * 255.0 + 0.5))
    return _encode(bytes(data), width, height, "gray" if mode == "gray" else mode, level)


# ------------------------------------------------------------ imagens utilitárias
def _in_triangle(px: float, py: float, tri) -> bool:
    (ax, ay), (bx, by), (cx, cy) = tri
    d1 = (px - bx) * (ay - by) - (ax - bx) * (py - by)
    d2 = (px - cx) * (by - cy) - (bx - cx) * (py - cy)
    d3 = (px - ax) * (cy - ay) - (cx - ax) * (py - ay)
    has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
    has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
    return not (has_neg and has_pos)


def make_icon(size: int = 128, accent=(0.35, 0.85, 1.0), bg=(0.055, 0.06, 0.09)) -> bytes:
    """
    Ícone da marca Arkher: 'A' estilizado com gradiente cyan->violeta.
    Devolve bytes PNG (RGB). Usado no projeto Godot, no site e no app Android.
    """
    s = float(size)
    pixels = bytearray(size * size * 3)
    outer = [(0.14 * s, 0.86 * s), (0.5 * s, 0.10 * s), (0.86 * s, 0.86 * s)]
    inner = [(0.36 * s, 0.80 * s), (0.5 * s, 0.38 * s), (0.64 * s, 0.80 * s)]
    bar = (0.30 * s, 0.62 * s, 0.70 * s, 0.72 * s)
    for y in range(size):
        fy = y / s
        for x in range(size):
            fx = x / s
            # fundo com gradiente radial suave
            d = ((fx - 0.5) ** 2 + (fy - 0.45) ** 2) ** 0.5
            k = max(0.0, 1.0 - d * 1.5)
            r = bg[0] + 0.10 * k
            g = bg[1] + 0.12 * k
            b = bg[2] + 0.22 * k
            if _in_triangle(x, y, outer) and not _in_triangle(x, y, inner):
                t = fy
                r = accent[0] * (1 - t) + 0.62 * t
                g = accent[1] * (1 - t) + 0.30 * t
                b = accent[2] * (1 - t) + 1.00 * t
                # brilho no topo
                glow = max(0.0, 1.0 - abs(fy - 0.22) * 5.0)
                r += 0.25 * glow
                g += 0.25 * glow
                b += 0.25 * glow
            elif bar[0] <= x <= bar[2] and bar[1] <= y <= bar[3]:
                r, g, b = 0.95, 0.97, 1.0
            j = (y * size + x) * 3
            pixels[j] = min(255, int(r * 255))
            pixels[j + 1] = min(255, int(g * 255))
            pixels[j + 2] = min(255, int(b * 255))
    return encode_rgb(bytes(pixels), size, size)

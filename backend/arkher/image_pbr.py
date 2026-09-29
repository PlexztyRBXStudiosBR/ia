"""
PBR derivado de IMAGEM REAL: o usuário envia uma foto/desenho (PNG puro, ou
JPEG/WebP quando Pillow está disponível) e o Arkher deriva um conjunto PBR
completo (albedo, normal, roughness, metallic, ao, height) na resolução pedida
(até 16k com numpy; até 2k em Python puro — declarado com honestidade no meta).

Etapas:
  1. decode_image()  -- PNG 8-bit (gray/rgb/rgba) sem dependências; Pillow opcional
  2. _resample()     -- bilinear (up) / box (down) para o tamanho alvo
  3. image_to_pbr()  -- deriva os canais:
       albedo     = imagem redimensionada (com leve correção de contraste)
       height     = detalhe de luminância + micro-grão procedural (não fica 'plástico')
       normal     = gradiente do height (Sobel) empacotado em RGB tangente
       roughness  = heurística de contraste local + micro-ruído
       metallic   = constante do preset (a foto não codifica metal de forma confiável)
       ao         = escurecimento de baixa frequência do height

Devolvemos um textures.PbrSet para o servidor tratar igual ao procedural.
"""
from __future__ import annotations

import math
import struct
import zlib
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Tuple

from . import noise as nz
from . import pnglib
from .textures import PbrMap, PbrSet, resolution_px

try:  # numpy acelera tudo e libera 8k/16k
    import numpy as _np
except Exception:  # pragma: no cover
    _np = None

try:  # Pillow só para decodificar JPEG/WebP enviados pelo usuário
    from PIL import Image as _PILImage
except Exception:  # pragma: no cover
    _PILImage = None

__all__ = ["decode_image", "decode_png", "image_to_pbr", "DecodedImage", "pillow_available"]

PURE_MAX = 2048      # sem numpy: limite honesto para derivar canais
NUMPY_MAX = 16384    # com numpy: 16k de verdade


def pillow_available() -> bool:
    return _PILImage is not None


@dataclass
class DecodedImage:
    width: int
    height: int
    nch: int                # 1 (gray), 3 (rgb), 4 (rgba)
    pixels: bytes           # linhas contíguas, 8 bits/canal
    source_format: str      # "png" | "jpeg" | "webp" | ...

    def to_rgb(self) -> Tuple[int, int, bytes]:
        if self.nch == 3:
            return self.width, self.height, self.pixels
        if self.nch == 4:
            out = bytearray(self.width * self.height * 3)
            p = self.pixels
            for i in range(self.width * self.height):
                out[i * 3] = p[i * 4]
                out[i * 3 + 1] = p[i * 4 + 1]
                out[i * 3 + 2] = p[i * 4 + 2]
            return self.width, self.height, bytes(out)
        out = bytearray(self.width * self.height * 3)
        p = self.pixels
        for i in range(self.width * self.height):
            g = p[i]
            out[i * 3] = g
            out[i * 3 + 1] = g
            out[i * 3 + 2] = g
        return self.width, self.height, bytes(out)


# ---------------------------------------------------------------- decodificação
def decode_png(data: bytes) -> DecodedImage:
    """Decoder PNG 8-bit não-entrelaçado (color types 0/2/4/6) em Python puro."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("não é um PNG (assinatura inválida)")
    pos = 8
    width = height = bit_depth = color_type = interlace = 0
    idat = bytearray()
    while pos + 8 <= len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        tag = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if tag == b"IHDR":
            width, height, bit_depth, color_type, _comp, _filt, interlace = struct.unpack(">IIBBBBB", chunk)
        elif tag == b"IDAT":
            idat += chunk
        elif tag == b"IEND":
            break
    if not width or not height:
        raise ValueError("PNG sem IHDR")
    if bit_depth != 8:
        raise ValueError(f"PNG de {bit_depth} bits não suportado (use 8 bits)")
    if interlace:
        raise ValueError("PNG entrelaçado (Adam7) não suportado — reenvie sem entrelaçar")
    if color_type not in (0, 2, 4, 6):
        raise ValueError("PNG com paleta não suportado — reenvie como RGB/RGBA")
    nch = {0: 1, 2: 3, 4: 2, 6: 4}[color_type]
    raw = zlib.decompress(bytes(idat))
    stride = width * nch
    out = bytearray(height * stride)
    prev = bytearray(stride)
    p = 0
    for y in range(height):
        f = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if f == 1:
            for i in range(nch, stride):
                line[i] = (line[i] + line[i - nch]) & 0xFF
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:
            for i in range(stride):
                a = line[i - nch] if i >= nch else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif f == 4:
            for i in range(stride):
                a = line[i - nch] if i >= nch else 0
                b = prev[i]
                c = prev[i - nch] if i >= nch else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        elif f != 0:
            raise ValueError(f"PNG com filtro de linha inválido ({f})")
        out[y * stride:(y + 1) * stride] = line
        prev = line
    if nch == 2:  # gray+alpha -> gray
        gray = bytearray(width * height)
        for i in range(width * height):
            gray[i] = out[i * 2]
        return DecodedImage(width, height, 1, bytes(gray), "png")
    return DecodedImage(width, height, nch, bytes(out), "png")


def decode_image(data: bytes) -> DecodedImage:
    """PNG em Python puro; qualquer outro formato via Pillow (se instalado)."""
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        try:
            return decode_png(data)
        except ValueError:
            if _PILImage is None:
                raise
    if _PILImage is None:
        raise ValueError(
            "formato de imagem não suportado sem Pillow — envie PNG 8-bit "
            "(ou instale python-pillow no servidor)")
    import io
    img = _PILImage.open(io.BytesIO(data))
    fmt = (img.format or "?").lower()
    if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
        img = img.convert("RGBA")
        nch = 4
    elif img.mode in ("L", "1"):
        img = img.convert("L")
        nch = 1
    else:
        img = img.convert("RGB")
        nch = 3
    w, h = img.size
    if w * h > 40_000_000:
        raise ValueError("imagem grande demais (máx ~40 MP)")
    return DecodedImage(w, h, nch, img.tobytes(), fmt)


# ------------------------------------------------------------------ reamostragem
def _resample_rgb(w: int, h: int, pixels: bytes, tw: int, th: int) -> bytes:
    """RGB -> RGB no tamanho alvo. Bilinear ao ampliar, box ao reduzir."""
    if _np is not None:
        arr = _np.frombuffer(pixels, dtype=_np.uint8).reshape(h, w, 3).astype(_np.float32)
        ys = (_np.arange(th, dtype=_np.float32) + 0.5) * h / th - 0.5
        xs = (_np.arange(tw, dtype=_np.float32) + 0.5) * w / tw - 0.5
        if th < h or tw < w:  # box (média por imagem integral) para reduzir sem aliasing
            S = _np.zeros((h + 1, w + 1, 3), dtype=_np.float64)
            S[1:, 1:] = arr.cumsum(axis=0).cumsum(axis=1)
            y0 = _np.floor(_np.arange(th) * h / th).astype(_np.int64)
            y1 = _np.maximum(y0 + 1, _np.ceil(_np.arange(1, th + 1) * h / th).astype(_np.int64))
            x0 = _np.floor(_np.arange(tw) * w / tw).astype(_np.int64)
            x1 = _np.maximum(x0 + 1, _np.ceil(_np.arange(1, tw + 1) * w / tw).astype(_np.int64))
            tot = (S[_np.ix_(y1, x1)] - S[_np.ix_(y0, x1)] - S[_np.ix_(y1, x0)] + S[_np.ix_(y0, x0)])
            area = ((y1 - y0)[:, None, None] * (x1 - x0)[None, :, None]).astype(_np.float64)
            return (tot / area).astype(_np.uint8).tobytes()
        y0 = _np.clip(_np.floor(ys).astype(_np.int32), 0, h - 2)
        x0 = _np.clip(_np.floor(xs).astype(_np.int32), 0, w - 2)
        fy = (ys - y0).clip(0, 1)[:, None, None]
        fx = (xs - x0).clip(0, 1)[None, :, None]
        top = arr[y0][:, x0] * (1 - fx) + arr[y0][:, x0 + 1] * fx
        bot = arr[y0 + 1][:, x0] * (1 - fx) + arr[y0 + 1][:, x0 + 1] * fx
        out = top * (1 - fy) + bot * fy
        return out.astype(_np.uint8).tobytes()

    out = bytearray(tw * th * 3)
    up = tw > w or th > h
    for j in range(th):
        sy = (j + 0.5) * h / th - 0.5
        y0i = max(0, min(h - 1, int(math.floor(sy))))
        y1i = min(h - 1, y0i + 1)
        fy = sy - math.floor(sy) if up else 0.0
        fy = max(0.0, min(1.0, fy))
        for i in range(tw):
            sx = (i + 0.5) * w / tw - 0.5
            x0i = max(0, min(w - 1, int(math.floor(sx))))
            x1i = min(w - 1, x0i + 1)
            fx = max(0.0, min(1.0, sx - math.floor(sx))) if up else 0.0
            o = (j * tw + i) * 3
            a0 = (y0i * w + x0i) * 3
            a1 = (y0i * w + x1i) * 3
            a2 = (y1i * w + x0i) * 3
            a3 = (y1i * w + x1i) * 3
            for c in range(3):
                top = pixels[a0 + c] * (1 - fx) + pixels[a1 + c] * fx
                bot = pixels[a2 + c] * (1 - fx) + pixels[a3 + c] * fx
                out[o + c] = int(top * (1 - fy) + bot * fy + 0.5)
    return bytes(out)


# ------------------------------------------------------------------- derivação
def _lum_arrays(size: int, rgb: bytes) -> List[float]:
    return [(rgb[i * 3] * 0.2126 + rgb[i * 3 + 1] * 0.7152 + rgb[i * 3 + 2] * 0.0722) / 255.0
            for i in range(size * size)]


def image_to_pbr(img: DecodedImage, resolution: str = "2k", seed: int = 1337,
                 channels: Optional[Sequence[str]] = None,
                 metallic: float = 0.0, roughness_bias: float = 0.55,
                 detail_strength: float = 1.0, tile: bool = False) -> PbrSet:
    """Deriva um conjunto PBR completo a partir de uma imagem do usuário."""
    import time
    t0 = time.time()
    want = list(channels) if channels else ["albedo", "normal", "roughness", "metallic", "ao", "height"]
    size = resolution_px(resolution)
    cap = NUMPY_MAX if _np is not None else PURE_MAX
    capped = size > cap
    size = min(size, cap)

    w, h, rgb = img.to_rgb()
    # fonte quadrada: reamostra para (size, size) preservando proporção via crop central
    side = min(w, h)
    if w != h:
        cx, cy = w // 2, h // 2
        x0, y0 = max(0, cx - side // 2), max(0, cy - side // 2)
        cropped = bytearray(side * side * 3)
        for j in range(side):
            src = ((y0 + j) * w + x0) * 3
            cropped[j * side * 3:(j + 1) * side * 3] = rgb[src:src + side * 3]
        rgb = bytes(cropped)
        w = h = side
    resized = _resample_rgb(w, h, rgb, size, size)

    # micro-grão procedural: dá textura real em ampliações grandes (4k+ a partir
    # de uma foto 512px ficaria 'plástica' sem isto)
    grain_oct = 3 if size >= 4096 else 2
    fine = nz.fbm(size, seed=seed, octaves=grain_oct, tile=tile)
    fine_f = [float(x) for x in fine]

    lum = _lum_arrays(size, resized)

    maps: List[PbrMap] = []
    stats: Dict[str, object] = {
        "source": {
            "format": img.source_format, "width": img.width, "height": img.height,
            "megapixels": round(img.width * img.height / 1e6, 2),
        },
        "derived_from_image": True,
        "capped": capped,
        "cap_reason": ("limite 2k em Python puro (instale numpy para 8k/16k)" if capped and _np is None
                       else ("limite 16k" if capped else "")),
        "numpy": _np is not None,
    }

    def add(channel: str, png: bytes, color_space: str = "sRGB") -> None:
        maps.append(PbrMap(channel=channel, width=size, height=size,
                           png=png, color_space=color_space))

    # ---- height: luminância + micro-grão (base para normal/ao/roughness)
    hs = [0.0] * (size * size)
    inv = 1.0 / max(1e-6, (max(lum) - min(lum)))
    lo, hi = min(lum), max(lum)
    for i in range(size * size):
        contrast = (lum[i] - lo) * inv              # stretch de contraste
        hs[i] = 0.82 * contrast + 0.18 * (fine_f[i] - 0.5) * detail_strength + 0.5
        hs[i] = 0.0 if hs[i] < 0 else (1.0 if hs[i] > 1 else hs[i])
    if "height" in want:
        add("height", pnglib.encode_gray(bytes(nz.to_bytes(hs)), size, size), "linear")

    # ---- normal: gradiente do height (as funções já devolvem bytes 0..255)
    if "normal" in want:
        strength = 1.6 + 1.4 * detail_strength
        if _np is not None:
            r_a, g_a, b_a = nz.height_to_normal_np(_np.asarray(hs, dtype=_np.float64).reshape(size, size),
                                                   size, strength=strength)
            out = _np.empty(size * size * 3, dtype=_np.uint8)
            out[0::3] = r_a
            out[1::3] = g_a
            out[2::3] = b_a
            add("normal", pnglib.encode_rgb(out.tobytes(), size, size), "linear")
        else:
            r_a, g_a, b_a = nz.height_to_normal(hs, size, strength=strength)
            out = bytearray(size * size * 3)
            out[0::3] = r_a
            out[1::3] = g_a
            out[2::3] = b_a
            add("normal", pnglib.encode_rgb(bytes(out), size, size), "linear")

    # ---- albedo: a própria imagem com leve correção (contraste/saturação)
    if "albedo" in want:
        out = bytearray(size * size * 3)
        for i in range(size * size):
            r, g, b = resized[i * 3] / 255.0, resized[i * 3 + 1] / 255.0, resized[i * 3 + 2] / 255.0
            l = r * 0.2126 + g * 0.7152 + b * 0.0722
            r = l + (r - l) * 1.06
            g = l + (g - l) * 1.06
            b = l + (b - l) * 1.06
            r = (r - 0.5) * 1.05 + 0.5
            g = (g - 0.5) * 1.05 + 0.5
            b = (b - 0.5) * 1.05 + 0.5
            out[i * 3] = max(0, min(255, int(r * 255)))
            out[i * 3 + 1] = max(0, min(255, int(g * 255)))
            out[i * 3 + 2] = max(0, min(255, int(b * 255)))
        add("albedo", pnglib.encode_rgb(bytes(out), size, size), "sRGB")

    # ---- roughness: contraste local + micro-ruído (vias úmidas/secas)
    if "roughness" in want:
        out = bytearray(size * size)
        for j in range(size):
            jm = (j - 1) % size
            jp = (j + 1) % size
            for i in range(size):
                im = (i - 1) % size
                ip = (i + 1) % size
                k = j * size + i
                lap = abs(lum[jm * size + i] + lum[jp * size + i]
                          + lum[j * size + im] + lum[j * size + ip] - 4.0 * lum[k])
                rough = roughness_bias + min(0.35, lap * 2.2) + (fine_f[k] - 0.5) * 0.12
                out[k] = max(8, min(250, int(rough * 255)))
        add("roughness", pnglib.encode_gray(bytes(out), size, size), "linear")

    # ---- metallic: constante honesta (foto não codifica metal)
    if "metallic" in want:
        mv = max(0, min(255, int(metallic * 255)))
        add("metallic", pnglib.encode_gray(bytes([mv]) * (size * size), size, size), "linear")

    # ---- ao: suaviza o height (baixa frequência) e escurece vales
    if "ao" in want:
        blurred = _blur_simple(hs, size)
        out = bytearray(size * size)
        for i in range(size * size):
            ao = 0.55 + 0.45 * (blurred[i] * 0.6 + hs[i] * 0.4)
            out[i] = max(0, min(255, int(ao * 255)))
        add("ao", pnglib.encode_gray(bytes(out), size, size), "linear")

    elapsed = time.time() - t0
    pbr = PbrSet(material=f"image:{img.source_format}", resolution=resolution, size=size,
                 maps=maps, material_def={"derived_from_image": True},
                 stats={**stats, "elapsed_s": round(elapsed, 2),
                        "channels": [m.channel for m in maps]})
    return pbr


def _blur_simple(field: Sequence[float], size: int) -> List[float]:
    """Box blur 3x3 separável (puro)."""
    tmp = [0.0] * (size * size)
    out = [0.0] * (size * size)
    for j in range(size):
        row = j * size
        for i in range(size):
            im, ip = (i - 1) % size, (i + 1) % size
            tmp[row + i] = (field[row + im] + field[row + i] + field[row + ip]) / 3.0
    for j in range(size):
        jm, jp = (j - 1) % size, (j + 1) % size
        for i in range(size):
            out[j * size + i] = (tmp[jm * size + i] + tmp[j * size + i] + tmp[jp * size + i]) / 3.0
    return out

"""
IA de malhas: entrada por TEXTO e por IMAGEM, com três caminhos honestos.

1) PROVEDORES GENERATIVOS REAIS (nuvem ou servidor local):
     * Meshy  (MESHY_API_KEY)   -- text-to-3d e image-to-3d (v2)
     * Tripo  (TRIPO_API_KEY)   -- text_to_model e image_to_model (upload multipart)
     * Local  (ARKHER_MESH_AI_URL) -- qualquer serviço próprio que aceite
       POST {"prompt": str, "image_b64": str|null} e devolva {"glb_b64": ...}
       ou bytes .glb crus. Use para plugar Stable Fast 3D / TripoSR / Hunyuan3D
       rodando num PC com GPU.
   Sem chave configurada, o servidor informa `providers` em /api/status e a UI
   mostra o estado real — sem fingir que existe IA generativa onde não existe.

2) PROMPT-SCULPT (offline, sempre disponível): análise de palavras-chave do
   texto (pt/en) -> escultura SDF orgânica (humanóide/criatura/rocha/busto) com
   parâmetros derivados do prompt (musculatura, espinhos, semente, escala).
   Não é um modelo gerado por rede neural — é escultura digital paramétrica,
   e o meta declara "sculpt" como origem.

3) IMAGE-TO-RELIEF (offline): a imagem enviada vira geometria REAL — um
   baixo-relevo (heightfield da luminância com placa traseira e paredes),
   pronto para receber PBR derivado da mesma imagem (image_pbr.py).

generate_mesh() decide a rota e devolve (glb_bytes, meta) — meta["origin"] diz
exatamente o que aconteceu: "provider:meshy", "sculpt", "relief".
"""
from __future__ import annotations

import base64
import json
import math
import os
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Sequence, Tuple

from . import sdf as sdf_mod
from .glb import GlbBuilder, Material, MeshData

__all__ = ["provider_status", "generate_mesh", "prompt_sculpt", "image_to_relief",
           "MeshAIError"]


class MeshAIError(RuntimeError):
    pass


# ------------------------------------------------------------------- provedores
def provider_status() -> Dict[str, Any]:
    meshy = bool(os.environ.get("MESHY_API_KEY"))
    tripo = bool(os.environ.get("TRIPO_API_KEY"))
    local_url = os.environ.get("ARKHER_MESH_AI_URL", "").strip()
    return {
        "meshy": meshy,
        "tripo": tripo,
        "local": bool(local_url),
        "local_url": local_url or None,
        "offline_modes": ["sculpt", "relief"],
        "active": "meshy" if meshy else ("tripo" if tripo else ("local" if local_url else None)),
    }


def _http_json(url: str, payload: Optional[Dict[str, Any]] = None,
               headers: Optional[Dict[str, str]] = None, timeout: float = 60.0) -> Dict[str, Any]:
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, headers=headers or {},
                                 method="POST" if data else "GET")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def _http_bytes(url: str, headers: Optional[Dict[str, str]] = None,
                timeout: float = 120.0) -> bytes:
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def _poll(get_url: str, headers: Dict[str, str], timeout_s: float,
          interval: float = 4.0, done=("SUCCEEDED", "success"), failed=("FAILED", "error", "banned")) -> Dict[str, Any]:
    t0 = time.time()
    last: Dict[str, Any] = {}
    while time.time() - t0 < timeout_s:
        try:
            last = _http_json(get_url, headers=headers)
        except urllib.error.HTTPError as e:
            raise MeshAIError(f"provedor retornou HTTP {e.code}") from e
        node = last.get("data", last)
        status = str(node.get("status", "")).upper()
        if status in {d.upper() for d in done}:
            return node
        if status in {f.upper() for f in failed}:
            raise MeshAIError(f"tarefa falhou no provedor: {node.get('task_error') or node}")
        time.sleep(interval)
    raise MeshAIError(f"tempo esgotado ({int(timeout_s)}s) aguardando o provedor")


def _via_meshy(prompt: str, image_b64: Optional[str], timeout_s: float) -> bytes:
    key = os.environ["MESHY_API_KEY"]
    headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    if image_b64:
        payload = {"mode": "preview", "image_url": f"data:image/png;base64,{image_b64}"}
        create = "https://api.meshy.ai/v2/image-to-3d"
    else:
        payload = {"mode": "preview", "prompt": prompt[:1000], "art_style": "realistic",
                   "should_remesh": True}
        create = "https://api.meshy.ai/v2/text-to-3d"
    task = _http_json(create, payload, headers)
    tid = task.get("result") or task.get("id") or task.get("task_id")
    if not tid:
        raise MeshAIError(f"Meshy: resposta sem id de tarefa: {task}")
    node = _poll(f"{create}/{tid}", headers, timeout_s)
    url = node.get("model_url") or (node.get("task_result") or {}).get("model_url")
    if not url:
        raise MeshAIError("Meshy: tarefa concluída sem model_url")
    return _http_bytes(url, headers={"Authorization": f"Bearer {key}"})


def _multipart(fields: Dict[str, str], filename: str, filedata: bytes, field: str = "file") -> Tuple[bytes, str]:
    boundary = "----arkher%d" % int(time.time() * 1000)
    body = bytearray()
    for k, v in fields.items():
        body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
    body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"{field}\"; "
             f"filename=\"{filename}\"\r\nContent-Type: image/png\r\n\r\n").encode()
    body += filedata + f"\r\n--{boundary}--\r\n".encode()
    return bytes(body), boundary


def _via_tripo(prompt: str, image_b64: Optional[str], timeout_s: float) -> bytes:
    key = os.environ["TRIPO_API_KEY"]
    headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    if image_b64:
        img = base64.b64decode(image_b64)
        body, boundary = _multipart({}, "input.png", img)
        req = urllib.request.Request(
            "https://api.tripo3d.ai/v2/openapi/upload", data=body,
            headers={"Authorization": f"Bearer {key}",
                     "Content-Type": f"multipart/form-data; boundary={boundary}"},
            method="POST")
        with urllib.request.urlopen(req, timeout=120) as r:
            up = json.loads(r.read().decode())
        token = (up.get("data") or {}).get("image_token")
        if not token:
            raise MeshAIError(f"Tripo: upload sem image_token: {up}")
        payload = {"type": "image_to_model", "file": {"type": "png", "file_token": token}}
    else:
        payload = {"type": "text_to_model", "prompt": prompt[:1000]}
    task = _http_json("https://api.tripo3d.ai/v2/openapi/task", payload, headers)
    tid = (task.get("data") or {}).get("task_id")
    if not tid:
        raise MeshAIError(f"Tripo: resposta sem task_id: {task}")
    node = _poll(f"https://api.tripo3d.ai/v2/openapi/task/{tid}", headers, timeout_s)
    out = node.get("output") or {}
    url = out.get("pbr_model") or out.get("model")
    if not url:
        raise MeshAIError("Tripo: tarefa concluída sem URL de modelo")
    return _http_bytes(url)


def _via_local(prompt: str, image_b64: Optional[str], timeout_s: float) -> bytes:
    url = os.environ["ARKHER_MESH_AI_URL"].strip().rstrip("/")
    payload = {"prompt": prompt[:2000], "image_b64": image_b64}
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=timeout_s) as r:
        raw = r.read()
    if raw[:4] == b"glTF":
        return raw
    try:
        obj = json.loads(raw.decode())
    except Exception as e:  # noqa: BLE001
        raise MeshAIError("resposta do servidor local não é GLB nem JSON") from e
    if isinstance(obj, dict):
        if obj.get("glb_b64"):
            return base64.b64decode(obj["glb_b64"])
        if obj.get("model_url"):
            return _http_bytes(obj["model_url"], timeout=timeout_s)
        if obj.get("error"):
            raise MeshAIError(f"servidor local: {obj['error']}")
    raise MeshAIError("resposta do servidor local sem glb_b64/model_url")


_PROVIDER_FN = {"meshy": _via_meshy, "tripo": _via_tripo, "local": _via_local}


# ------------------------------------------------------------- prompt -> escultura
_HUMANOID_KEYS = ("humano", "human", "homem", "man ", "mulher", "woman", "pessoa", "person",
                  "guerreiro", "warrior", "heroi", "herói", "hero", "heroína", "heroina",
                  "soldado", "soldier", "cavaleiro", "knight", "npc", "personagem",
                  "character", "barbaro", "bárbaro", "barbarian", "mago", "mage", "wizard",
                  "elfo", "elf", "anão", "anao", "dwarf", "zumbi", "zombie", "robô", "robo", "robot")
_CREATURE_KEYS = ("criatura", "creature", "monstro", "monster", "dragao", "dragão", "dragon",
                  "alien", "alienigena", "alienígena", "fera", "beast", "animal", "quadrupede",
                  "quadrúpede", "lobo", "wolf", "cao", "cão", "dog", "dinossauro", "dinossauro",
                  "dino", "goblin", "orc", "ogro", "ogre", "aracnideo", "spider", "aranha")
_ROCK_KEYS = ("pedra", "rocha", "rock", "stone", "montanha", "mountain", "asteroide", "asteróide",
              "asteroid", "cristal", "crystal", "penhasco", "cliff", "bloco", "rubble", "detrito")
_BUST_KEYS = ("busto", "bust", "cabeca", "cabeça", "head", "rosto", "face", "estatua", "estátua",
              "statue", "escultura", "sculpture", "retrato", "portrait", "mascara", "máscara", "mask")
_MUSCLE_KEYS = ("musculoso", "muscular", "forte", "buff", "strong", "bruto", "hulk", "tanque")
_THIN_KEYS = ("magro", "fino", "slim", "thin", "skinny", "esquelético", "esqueletico")
_FAT_KEYS = ("gordo", "fat", "rechonchudo", "round", "obeso")
_SPIKE_KEYS = ("espinho", "spike", "spiky", "espinhoso", "chifre", "horn", "horned", "crista")


def _hash_seed(prompt: str) -> int:
    h = 2166136261
    for ch in prompt.strip().lower():
        h = (h ^ ord(ch)) * 16777619 & 0xFFFFFFFF
    return h % 100000


def prompt_sculpt(prompt: str, seed: Optional[int] = None, resolution: int = 48,
                  scale: float = 1.0) -> Tuple[MeshData, Dict[str, Any]]:
    """Escultura SDF guiada por palavras-chave do texto (offline, sem IA de nuvem)."""
    p = " " + prompt.lower() + " "
    if seed is None:
        seed = _hash_seed(prompt)
    kind = "humanoid"
    if any(k in p for k in _BUST_KEYS):
        kind = "bust"
    elif any(k in p for k in _CREATURE_KEYS):
        kind = "creature"
    elif any(k in p for k in _ROCK_KEYS):
        kind = "rock"
    elif any(k in p for k in _HUMANOID_KEYS):
        kind = "humanoid"

    muscle = 1.0
    if any(k in p for k in _MUSCLE_KEYS):
        muscle = 1.28
    elif any(k in p for k in _FAT_KEYS):
        muscle = 1.12
    elif any(k in p for k in _THIN_KEYS):
        muscle = 0.84
    spiky = any(k in p for k in _SPIKE_KEYS)

    if kind == "humanoid":
        s = sdf_mod.sdf_humanoid(muscle=muscle)
    elif kind == "creature":
        s = sdf_mod.sdf_creature(seed=seed)
    elif kind == "rock":
        s = sdf_mod.sdf_rock(seed=seed)
    else:
        s = sdf_mod.sdf_bust()

    if spiky:
        rnd = __import__("random").Random(seed + 7)
        if kind == "creature":
            for _ in range(9):
                ang = rnd.uniform(0, math.tau)
                z = rnd.uniform(-0.5, 0.55)
                s.cone((0.30 * math.cos(ang), 0.95 + rnd.uniform(-0.1, 0.15), z),
                       (0.52 * math.cos(ang), 1.12 + rnd.uniform(-0.1, 0.2), z + rnd.uniform(-0.1, 0.1)),
                       0.05, 0.006, k=0.04)
        else:
            for _ in range(6):
                ang = rnd.uniform(0, math.tau)
                y = rnd.uniform(0.95, 1.45)
                s.cone((0.19 * math.cos(ang), y, 0.13 * math.sin(ang)),
                       (0.34 * math.cos(ang), y + 0.10, 0.24 * math.sin(ang)),
                       0.035, 0.005, k=0.03)

    mesh = sdf_mod.extract_mesh(s, resolution=resolution, smooth_iters=2,
                                name="sculpt")
    if abs(scale - 1.0) > 1e-3:
        mesh.positions = [c * scale for c in mesh.positions]
    info = {
        "origin": "sculpt",
        "sculpt_kind": kind,
        "seed": seed,
        "muscle": muscle,
        "spiky": spiky,
        "resolution": resolution,
        "vertices": mesh.vertex_count,
        "triangles": mesh.triangle_count,
        "note": "escultura SDF paramétrica guiada pelo texto (offline) — não é geração por rede neural",
    }
    return mesh, info


# ---------------------------------------------------------------- imagem -> relevo
def image_to_relief(img, grid: int = 128, depth: float = 0.10, base: float = 0.06,
                    size: float = 1.0, name: str = "relief") -> Tuple[MeshData, Dict[str, Any]]:
    """
    Baixo-relevo REAL derivado da imagem: heightfield da luminância (frente),
    placa traseira plana e paredes laterais fechando o volume. UVs planares para
    aplicar o PBR derivado da mesma imagem.
    """
    from . import image_pbr as ipb
    grid = max(16, min(256, int(grid)))
    w, h, rgb = img.to_rgb()
    # reamostra direto para (grid+1)x(grid+1)
    small = ipb._resample_rgb(w, h, rgb, grid + 1, grid + 1)
    hs: List[float] = []
    for i in range((grid + 1) * (grid + 1)):
        lum = (small[i * 3] * 0.2126 + small[i * 3 + 1] * 0.7152 + small[i * 3 + 2] * 0.0722) / 255.0
        hs.append(lum)

    positions: List[float] = []
    normals: List[float] = []
    uvs: List[float] = []
    indices: List[int] = []
    half = size * 0.5
    step = size / grid

    def vidx(j: int, i: int) -> int:
        return j * (grid + 1) + i

    # frente deslocada
    for j in range(grid + 1):
        for i in range(grid + 1):
            x = -half + i * step
            y = half - j * step
            z = base + hs[vidx(j, i)] * depth
            positions.extend((x, y, z))
            uvs.extend((i / grid, 1.0 - j / grid))
    # normais da frente por diferenças finitas
    for j in range(grid + 1):
        for i in range(grid + 1):
            jm, jp = max(0, j - 1), min(grid, j + 1)
            im, ip = max(0, i - 1), min(grid, i + 1)
            dzdx = (hs[vidx(j, ip)] - hs[vidx(j, im)]) * depth / (step * (ip - im))
            dzdy = -(hs[vidx(jp, i)] - hs[vidx(jm, i)]) * depth / (step * (jp - jm))
            n = (dzdx, -dzdy, 1.0)  # y da imagem aponta para baixo
            d = math.sqrt(n[0] * n[0] + n[1] * n[1] + 1.0) or 1.0
            normals.extend((n[0] / d, n[1] / d, n[2] / d))
    front_base = 0
    for j in range(grid):
        for i in range(grid):
            a, b = vidx(j, i), vidx(j, i + 1)
            c, d = vidx(j + 1, i + 1), vidx(j + 1, i)
            # frente olha para +z (CCW visto de +z: a -> c -> b / a -> d -> c)
            indices.extend((front_base + a, front_base + c, front_base + b,
                            front_base + a, front_base + d, front_base + c))
    # verso (placa em z=0) + paredes
    n_front = (grid + 1) * (grid + 1)
    back_base = n_front
    for j in range(grid + 1):
        for i in range(grid + 1):
            x = -half + i * step
            y = half - j * step
            positions.extend((x, y, 0.0))
            normals.extend((0.0, 0.0, -1.0))
            uvs.extend((i / grid, 1.0 - j / grid))
    for j in range(grid):
        for i in range(grid):
            a, b = vidx(j, i), vidx(j, i + 1)
            c, d = vidx(j + 1, i + 1), vidx(j + 1, i)
            # verso olha para -z (invertido)
            indices.extend((back_base + a, back_base + b, back_base + c,
                            back_base + a, back_base + c, back_base + d))
    # paredes laterais (borda do grid)
    wall_base = len(positions) // 3
    border: List[Tuple[int, int]] = []
    for i in range(grid + 1):
        border.append((0, i))
    for j in range(1, grid + 1):
        border.append((j, grid))
    for i in range(grid - 1, -1, -1):
        border.append((grid, i))
    for j in range(grid - 1, 0, -1):
        border.append((j, 0))
    def border_normal(j: int, i: int) -> Tuple[float, float, float]:
        # normal exterior do lado do retângulo onde o ponto está
        if j == 0:
            return (0.0, 1.0, 0.0)
        if j == grid:
            return (0.0, -1.0, 0.0)
        if i == grid:
            return (1.0, 0.0, 0.0)
        return (-1.0, 0.0, 0.0)

    for (j, i) in border:
        x = -half + i * step
        y = half - j * step
        z = base + hs[vidx(j, i)] * depth
        nrm = border_normal(j, i)
        positions.extend((x, y, z))
        uvs.extend((i / grid, 1.0 - j / grid))
        normals.extend(nrm)
        positions.extend((x, y, 0.0))
        uvs.extend((i / grid, 1.0 - j / grid))
        normals.extend(nrm)
    nb = len(border)
    for k in range(nb):
        t0 = wall_base + (k * 2) % (nb * 2)
        t1 = wall_base + ((k * 2 + 2) % (nb * 2))
        b0 = t0 + 1
        b1 = t1 + 1
        indices.extend((t0, t1, b1, t0, b1, b0))

    mesh = MeshData(name=name, positions=positions, normals=normals, uvs=uvs, indices=indices)
    info = {
        "origin": "relief",
        "grid": grid,
        "depth": depth,
        "vertices": mesh.vertex_count,
        "triangles": mesh.triangle_count,
        "note": "geometria real derivada da luminância da imagem (baixo-relevo) — não é geração por rede neural",
    }
    return mesh, info


# ------------------------------------------------------------------ orquestração
def generate_mesh(prompt: str = "", image_bytes: Optional[bytes] = None,
                  source: str = "auto", name: str = "ArkherMesh",
                  resolution: int = 48, timeout_s: float = 300.0,
                  material: Optional[Material] = None) -> Tuple[bytes, Dict[str, Any]]:
    """
    source: "auto" | "provider" | "sculpt" | "relief"
    auto: tenta provedor configurado (se prompt ou imagem); senão, relief (com
    imagem) ou sculpt (com texto).
    Retorna (glb, meta). meta["origin"] documenta a rota usada.
    """
    st = provider_status()
    image_b64 = base64.b64encode(image_bytes).decode() if image_bytes else None
    errors: List[str] = []

    def build_from_mesh(mesh: MeshData, meta: Dict[str, Any]) -> Tuple[bytes, Dict[str, Any]]:
        b = GlbBuilder()
        mat = material or Material(name=f"{name}_mat", base_color=(0.78, 0.76, 0.74, 1.0),
                                   roughness=0.68, metallic=0.02)
        mesh.material = mat
        mi = b.add_mesh(mesh, b.add_material(mat))
        node = b.add_node(name, mesh=mi)
        data = b.build(root_nodes=[node], asset_name=name)
        meta.update({"bytes": len(data), "files": [f"{name}.glb"]})
        return data, meta

    use_provider = source in ("provider", "auto") and st["active"] and (prompt or image_bytes)
    if source == "provider" and not st["active"]:
        raise MeshAIError("nenhum provedor generativo configurado (MESHY_API_KEY / TRIPO_API_KEY / ARKHER_MESH_AI_URL)")

    if use_provider:
        pname = st["active"]
        try:
            glb = _PROVIDER_FN[pname](prompt or "3d model", image_b64, timeout_s)
            if glb[:4] != b"glTF":
                raise MeshAIError(f"{pname}: resposta não é um GLB válido")
            meta = {"origin": f"provider:{pname}", "provider": pname,
                    "prompt": prompt[:200], "image_used": bool(image_bytes),
                    "bytes": len(glb), "files": [f"{name}.glb"]}
            return glb, meta
        except (MeshAIError, urllib.error.URLError, OSError, ValueError, KeyError) as e:
            errors.append(f"{pname}: {e}")
            if source == "provider":
                raise MeshAIError("; ".join(errors)) from e

    # rotas offline
    if image_bytes:
        from . import image_pbr as ipb
        img = ipb.decode_image(image_bytes)
        mesh, info = image_to_relief(img, name=name)
        if errors:
            info["provider_errors"] = errors
        return build_from_mesh(mesh, info)
    if not prompt.strip():
        raise MeshAIError("informe um texto ou envie uma imagem")
    mesh, info = prompt_sculpt(prompt, resolution=resolution)
    mesh.name = name
    if errors:
        info["provider_errors"] = errors
    return build_from_mesh(mesh, info)

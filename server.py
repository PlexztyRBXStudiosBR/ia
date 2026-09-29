#!/usr/bin/env python3
"""
Arkher AI — servidor web + API de geração (Python puro, zero dependências).

    python server.py                 # http://localhost:8000
    python server.py --port 9000     # porta customizada
    python server.py --host 0.0.0.0  # expor na rede (RDP/Android/LAN)

Endpoints:
    GET  /                      -> site (web/)
    GET  /api/status            -> capacidades reais do backend
    GET  /api/agents            -> os 9 especialistas
    POST /api/chat              -> conversa com o time
    POST /api/generate/project  -> projeto Godot/Roblox (zip)
    POST /api/generate/model    -> .glb (com LODs, rig e animações)
    POST /api/generate/textures -> mapas PBR (png + zip)
    POST /api/generate/animation-> .glb animado + .tres + .rbxlx
    GET  /api/code              -> biblioteca de snippets
    GET  /api/download/...      -> bins gerados
    GET  /api/asset/...         -> pngs de textura para preview

Otimização: com `pip install numpy` as texturas 8k/16k ficam 20-100x mais
rápidas. Sem numpy, o servidor limita texturas a 2k e avisa o motivo.
"""
from __future__ import annotations

import argparse
import io
import json
import os
import sys
import threading
import time
import traceback
import uuid
import zipfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Dict, Optional
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "backend"))

from arkher import HAS_NUMPY, animation as anim_mod, code_library, textures as tex_mod
from arkher import meshes as mesh_mod
from arkher.chat import AGENTS, respond
from arkher.glb import GlbBuilder, Material
from arkher.godot_project import generate_godot_project
from arkher.pnglib import make_icon
from arkher.roblox_project import generate_roblox_project
from arkher.tscn_validate import validate_files

MAX_TEXTURE_PURE = 2048
MAX_TEXTURE_NUMPY = 16384
STORE_CAP_BYTES = 384 * 1024 * 1024

_store: Dict[str, Dict[str, Any]] = {}
_store_lock = threading.Lock()


def _store_put(kind: str, files: Dict[str, bytes], meta: Dict[str, Any]) -> str:
    aid = uuid.uuid4().hex[:12]
    total = sum(len(v) for v in files.values())
    with _store_lock:
        _store[aid] = {"kind": kind, "files": files, "meta": meta, "bytes": total, "ts": time.time()}
        _evict_locked()
    return aid


def _evict_locked() -> None:
    total = sum(v["bytes"] for v in _store.values())
    if total <= STORE_CAP_BYTES:
        return
    for aid in sorted(_store, key=lambda k: _store[k]["ts"]):
        total -= _store[aid]["bytes"]
        del _store[aid]
        if total <= STORE_CAP_BYTES * 0.75:
            break


def _store_get(aid: str) -> Optional[Dict[str, Any]]:
    with _store_lock:
        entry = _store.get(aid)
        if entry:
            entry["ts"] = time.time()
        return entry


def _zip_of(files: Dict[str, Any]) -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for name, data in files.items():
            z.writestr(name, data if isinstance(data, bytes) else str(data))
    return buf.getvalue()


def _llm_chat(message: str) -> Optional[str]:
    """Ponte opcional para LLM externo (config via variáveis de ambiente)."""
    key = os.environ.get("ARKHER_LLM_API_KEY", "").strip()
    if not key:
        return None
    base = os.environ.get("ARKHER_LLM_BASE", "https://api.openai.com/v1").rstrip("/")
    model = os.environ.get("ARKHER_LLM_MODEL", "gpt-4o-mini")
    try:
        import urllib.request

        payload = json.dumps(
            {
                "model": model,
                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "Você é o Arkher AI, time de 9 especialistas sênior em "
                            "desenvolvimento de jogos com foco em Godot 4 e Roblox. "
                            "Responda em português, técnico e direto, com código quando útil. "
                            "Seja honesto sobre limitações de IA em arte/animção AAA."
                        ),
                    },
                    {"role": "user", "content": message},
                ],
                "temperature": 0.7,
            }
        ).encode()
        req = urllib.request.Request(
            base + "/chat/completions",
            data=payload,
            headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=45) as resp:
            data = json.loads(resp.read().decode())
        return data["choices"][0]["message"]["content"]
    except Exception as e:  # noqa: BLE001
        return f"[LLM indisponível: {e.__class__.__name__}]"


def gen_project(body: Dict[str, Any]) -> Dict[str, Any]:
    engine = str(body.get("engine", "godot")).lower()
    name = str(body.get("name", "") or "Meu Jogo").strip()[:80]
    description = str(body.get("description", "") or "Jogo gerado pelo Arkher AI").strip()[:400]
    genre = str(body.get("genre", "acao")).strip()[:40]
    features = body.get("features") or ["player", "enemy", "hud", "menu", "save", "shaders", "lighting"]

    if engine == "roblox":
        files = generate_roblox_project(name, description, genre)
        validation: Dict[str, Any] = {"engine": "roblox", "json_ok": True}
        for k, v in list(files.items()):
            if k.endswith(".json"):
                try:
                    json.loads(v)
                except Exception as e:  # noqa: BLE001
                    validation["json_ok"] = False
                    validation[k] = str(e)
    else:
        icon = make_icon(128)
        files = generate_godot_project(name, description, genre, features=features, icon_png=icon)
        validation = {"engine": "godot", "errors": validate_files(files)}

    aid = _store_put("project", {k: v for k, v in files.items()}, {"name": name, "engine": engine})
    tree = [
        {"path": k, "bytes": len(v) if isinstance(v, bytes) else len(str(v)), "binary": isinstance(v, bytes)}
        for k, v in sorted(files.items())
    ]
    return {
        "asset_id": aid,
        "engine": engine,
        "files_count": len(files),
        "total_bytes": sum(len(v) if isinstance(v, bytes) else len(str(v)) for v in files.values()),
        "tree": tree,
        "validation": validation,
        "readme": str(files.get("README.md", ""))[:4000],
    }


def gen_model(body: Dict[str, Any]) -> Dict[str, Any]:
    model_type = str(body.get("type", "prop"))
    name = str(body.get("name", "") or model_type).strip()[:60] or model_type
    detail = int(body.get("detail", 2))
    detail = max(1, min(4, detail))
    seed = int(body.get("seed", 1337))
    with_lods = bool(body.get("lods", True))
    with_rig = bool(body.get("rig", False))
    animations = body.get("animations") or (["idle", "walk", "run", "jump"] if with_rig else [])
    res = int(body.get("texture", 256))
    res = max(64, min(1024, res))
    mat_name = str(body.get("material", "generic"))

    base_mat = tex_mod.MATERIALS.get(mat_name) or tex_mod.MATERIALS["generic"]
    tint = tuple(base_mat.get("base", (0.6, 0.6, 0.62)))  # type: ignore[arg-type]
    material = Material(
        name=f"{name}_mat",
        base_color=(tint[0], tint[1], tint[2], 1.0),
        metallic=float(base_mat.get("metal", 0.0)),  # type: ignore[arg-type]
        roughness=float(base_mat.get("rough", 0.7)),  # type: ignore[arg-type]
    )

    files: Dict[str, bytes] = {}
    stats: Dict[str, Any] = {"type": model_type, "detail": detail, "seed": seed}

    if with_rig and model_type in ("hero", "humanoid", "npc", "creature"):
        data, rstats = anim_mod.build_rigged_glb(
            animations=list(animations),
            model_type=model_type,
            name=name,
            detail=detail,
            material=material,
        )
        files[f"{name}_rigged.glb"] = data
        stats.update(rstats)
        files["godot_animation_library.tres"] = anim_mod.export_godot_animation_library(
            list(animations)
        ).encode()
        for a in animations:
            files[f"roblox_{a}.rbxlx"] = anim_mod.export_roblox_keyframe_sequence(a).encode()
    else:
        mesh = mesh_mod.make_model(model_type, name=name, detail=detail, seed=seed)
        mesh.material = material
        b = GlbBuilder()

        # textura albedo embutida pequena (o modelo abre colorido no editor)
        try:
            pbr = tex_mod.generate_pbr_set(mat_name, "512" if res >= 512 else "512", seed=seed,
                                           channels=["albedo"], max_size=512)
            alb = pbr.map("albedo")
            if alb:
                tex_idx = b.add_png_image(alb.png, f"{name}_albedo")
                mat_idx = b.add_material(material, base_color_texture=tex_idx)
            else:
                mat_idx = b.add_material(material)
        except Exception:  # noqa: BLE001
            mat_idx = b.add_material(material)

        mesh_idx = b.add_mesh(mesh, mat_idx)
        root = b.add_node(name, mesh=mesh_idx)
        files[f"{name}.glb"] = b.build(root_nodes=[root], asset_name=name)
        stats.update({"vertices": mesh.vertex_count, "triangles": mesh.triangle_count, "bones": 0, "animations": []})

        if with_lods:
            lods = mesh_mod.generate_lods(mesh, levels=3)
            lb = GlbBuilder()
            lmat = lb.add_material(material)
            children = []
            for i, lod in enumerate(lods):
                mi = lb.add_mesh(lod, lmat)
                ni = lb.add_node(f"{name}_LOD{i}", mesh=mi)
                children.append(ni)
            lb_root = lb.add_node(name, children=children)
            files[f"{name}_lods.glb"] = lb.build(root_nodes=[lb_root], asset_name=f"{name}_LODs")
            stats["lods"] = [
                {"level": i, "triangles": l.triangle_count, "vertices": l.vertex_count}
                for i, l in enumerate(lods)
            ]

    stats["files"] = list(files.keys())
    stats["bytes"] = sum(len(v) for v in files.values())
    aid = _store_put("model", files, stats)
    return {"asset_id": aid, "stats": stats}


def gen_textures(body: Dict[str, Any]) -> Dict[str, Any]:
    material = str(body.get("material", "stone"))
    resolution = str(body.get("resolution", "2k")).lower()
    seed = int(body.get("seed", 1337))
    tile = bool(body.get("tile", True))
    channels = body.get("channels") or None

    size = tex_mod.resolution_px(resolution)
    limit = MAX_TEXTURE_NUMPY if HAS_NUMPY else MAX_TEXTURE_PURE
    capped = size > limit
    if capped:
        resolution = {2048: "2k", 4096: "4k", 8192: "8k", 16384: "16k"}.get(limit, "2k")
        size = limit

    pbr = tex_mod.generate_pbr_set(material, resolution, seed=seed, tile=tile, channels=channels)
    files: Dict[str, bytes] = {}
    maps = []
    for m in pbr.maps:
        fname = f"{material}_{m.channel}_{size}.png"
        files[fname] = m.png
        maps.append({"channel": m.channel, "file": fname, "bytes": len(m.png), "color_space": m.color_space})
    files[f"{material}_material.json"] = json.dumps(pbr.material_def, indent=2).encode()
    files[f"{material}_material_godot.tres"] = _godot_material_tres(material, pbr).encode()
    files["README.txt"] = _texture_readme(material, size, pbr).encode()

    aid = _store_put("textures", files, pbr.stats)
    return {
        "asset_id": aid,
        "maps": maps,
        "stats": pbr.stats,
        "material_def": pbr.material_def,
        "capped": capped,
        "requested": str(body.get("resolution", "2k")),
        "limit_reason": None if not capped else (
            "numpy não instalado (pip install numpy libera até 16k)"
        ),
    }


def _godot_material_tres(material: str, pbr) -> str:
    lines = [
        '[gd_resource type="StandardMaterial3D" format=3]',
        "",
        "[resource]",
        f'resource_name = "{pbr.material_def.get("name", material)}"',
        "albedo_texture = PLACEHOLDER_ALBEDO",
        "normal_enabled = true",
        "normal_texture = PLACEHOLDER_NORMAL",
        "roughness_texture = PLACEHOLDER_ROUGH",
        "roughness_texture_channel = 4",
        "metallic_texture = PLACEHOLDER_METAL",
        "metallic_texture_channel = 0",
        "ao_enabled = true",
        "ao_texture = PLACEHOLDER_AO",
        "ao_texture_channel = 0",
        f'metallic = {pbr.material_def.get("metallic", 0.0)}',
        f'roughness = {pbr.material_def.get("roughness", 0.7)}',
        "uv1_scale = Vector3(1, 1, 1)",
        "texture_filter = 1",
    ]
    return "\n".join(lines) + "\n; Substitua os PLACEHOLDER_* pelos .png deste pacote no import do Godot.\n"


def _texture_readme(material: str, size: int, pbr) -> str:
    return f"""Pacote PBR '{material}' @ {size}px — Arkher AI
=================================================

Mapas incluídos:
{chr(10).join('  - ' + m.channel + ' (' + m.color_space + ')' for m in pbr.maps)}

Como usar no Godot 4:
  1. Copie os .png para res://assets/textures/
  2. Crie StandardMaterial3D e ligue: albedo->Albedo, normal->Normal Map
     (marque 'Normal Map' como tal), roughness/metallic/AO nos canais corretos
  3. Marque as texturas como Seamless/Repeat nas flags de import

Como usar no Roblox:
  - Suba os PNGs como decals/Texture (máx 1024 px: gere a versão 1k!)
  - Normal map: use como TextureId em SurfaceAppearance.NormalMap

Como usar no Blender/Unity/Unreal:
  - Padrão metallic-roughness (glTF). Albedo em sRGB, demais em linear/Non-Color.

Tileable: {"sim" if pbr.material_def.get("tileable") else "não"}
Seed: {pbr.material_def.get("seed")}  (mesma seed = mesmos mapas, reproduzível)
"""


def gen_animation(body: Dict[str, Any]) -> Dict[str, Any]:
    names = body.get("animations") or ["idle", "walk", "run", "jump"]
    fps = int(body.get("fps", 60))
    model_type = str(body.get("model", "hero"))
    detail = max(1, min(4, int(body.get("detail", 2))))

    data, stats = anim_mod.build_rigged_glb(
        animations=[n for n in names if n in anim_mod.ANIMATION_PRESETS],
        model_type=model_type,
        name="ArkherCharacter",
        detail=detail,
        fps=fps,
    )
    files: Dict[str, bytes] = {"character_rigged.glb": data}
    files["godot_animation_library.tres"] = anim_mod.export_godot_animation_library(names).encode()
    for a in names:
        if a in anim_mod.ANIMATION_PRESETS:
            files[f"roblox_{a}.rbxlx"] = anim_mod.export_roblox_keyframe_sequence(a, fps=fps).encode()
    files["README.txt"] = (
        "character_rigged.glb  -> Godot 4 / Blender / Roblox Studio (import glTF)\n"
        "godot_animation_library.tres -> AnimationLibrary apontando para os takes do .glb\n"
        "roblox_*.rbxlx -> KeyframeSequence R15: Studio -> Animation Editor -> importar\n"
    ).encode()
    stats["files"] = list(files.keys())
    aid = _store_put("animation", files, stats)
    return {"asset_id": aid, "stats": stats}


# ------------------------------------------------------------------ HTTP
class Handler(BaseHTTPRequestHandler):
    server_version = "ArkherAI/1.0"
    protocol_version = "HTTP/1.1"
    web_root: Path = ROOT / "web"

    def log_message(self, fmt: str, *args: Any) -> None:  # silencioso por padrão
        if os.environ.get("ARKHER_VERBOSE"):
            super().log_message(fmt, *args)

    # ---------------- helpers
    def _send(self, code: int, body: bytes, ctype: str, extra: Optional[Dict[str, str]] = None) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _json(self, obj: Any, code: int = 200) -> None:
        self._send(code, json.dumps(obj, ensure_ascii=False).encode(), "application/json; charset=utf-8",
                   {"Access-Control-Allow-Origin": "*"})

    def _body(self) -> Dict[str, Any]:
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        try:
            return json.loads(raw.decode() or "{}")
        except Exception:  # noqa: BLE001
            return {}

    # ---------------- verbs
    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self) -> None:
        url = urlparse(self.path)
        path = url.path
        try:
            if path.startswith("/api/"):
                self._api_get(path, parse_qs(url.query))
            else:
                self._static(path)
        except Exception as e:  # noqa: BLE001
            self._json({"error": str(e), "trace": traceback.format_exc(limit=3)}, 500)

    def do_POST(self) -> None:
        url = urlparse(self.path)
        path = url.path
        try:
            body = self._body()
            if path == "/api/chat":
                message = str(body.get("message", ""))[:4000]
                llm = _llm_chat(message)
                if llm and not llm.startswith("[LLM"):
                    self._json({"agent": AGENTS[0], "text": llm, "actions": [], "source": "llm"})
                else:
                    out = respond(message)
                    if llm:
                        out["llm_error"] = llm
                    self._json(out)
            elif path == "/api/generate/project":
                self._json(gen_project(body))
            elif path == "/api/generate/model":
                self._json(gen_model(body))
            elif path == "/api/generate/textures":
                self._json(gen_textures(body))
            elif path == "/api/generate/animation":
                self._json(gen_animation(body))
            else:
                self._json({"error": f"rota desconhecida: {path}"}, 404)
        except Exception as e:  # noqa: BLE001
            self._json({"error": str(e), "trace": traceback.format_exc(limit=4)}, 500)

    # ---------------- rotas
    def _api_get(self, path: str, qs: Dict[str, Any]) -> None:
        if path == "/api/status":
            self._json(
                {
                    "name": "Arkher AI",
                    "version": "1.0.0",
                    "numpy": HAS_NUMPY,
                    "texture_max": MAX_TEXTURE_NUMPY if HAS_NUMPY else MAX_TEXTURE_PURE,
                    "engines": ["godot", "roblox"],
                    "capabilities": {
                        "godot_project": True,
                        "roblox_project": True,
                        "glb_models": True,
                        "glb_rigged_animated": True,
                        "pbr_textures": True,
                        "roblox_keyframes": True,
                        "godot_animation_library": True,
                        "llm_bridge": bool(os.environ.get("ARKHER_LLM_API_KEY")),
                    },
                    "honest": [
                        "Modelos 3D são procedurais (primitivas compostas + LODs), não esculturas de artista",
                        "Animações são procedurais/keyframed — base excelente, não mo-cap de estúdio",
                        "Texturas são PBR procedural seamless; para arte autoral use o conector de API de imagem",
                        "Nenhuma IA hoje entrega um jogo AAA completo sozinha em dias: o Arkher acelera o pipeline real",
                    ],
                }
            )
        elif path == "/api/agents":
            self._json({"agents": AGENTS})
        elif path == "/api/code":
            q = (qs.get("q") or [""])[0]
            engine = (qs.get("engine") or [""])[0]
            self._json({"snippets": code_library.search(q, engine)})
        elif path.startswith("/api/download/"):
            self._download(path.split("/api/download/")[1])
        elif path.startswith("/api/asset/"):
            self._asset(path.split("/api/asset/")[1])
        else:
            self._json({"error": "não encontrado"}, 404)

    def _download(self, spec: str) -> None:
        kind, _, aid = spec.partition("/")
        entry = _store_get(aid)
        if not entry:
            self._json({"error": "asset expirado ou inexistente — gere de novo"}, 404)
            return
        if kind == "project":
            data = _zip_of(entry["files"])
            name = f"{entry['meta'].get('name', 'projeto').replace(' ', '_')}_{entry['meta'].get('engine')}_arkher.zip"
        elif kind in ("model", "animation"):
            if len(entry["files"]) == 1:
                fname, data = next(iter(entry["files"].items()))
            else:
                data = _zip_of(entry["files"])
                fname = f"arkher_{kind}_{aid}.zip"
            name = fname
        elif kind == "textures":
            data = _zip_of(entry["files"])
            name = f"arkher_textures_{aid}.zip"
        else:
            self._json({"error": "tipo inválido"}, 400)
            return
        self._send(
            200,
            data,
            "application/octet-stream",
            {"Content-Disposition": f'attachment; filename="{name}"', "Access-Control-Allow-Origin": "*"},
        )

    def _asset(self, spec: str) -> None:
        parts = spec.split("/")
        if len(parts) < 2:
            self._json({"error": "caminho inválido"}, 400)
            return
        aid, fname = parts[0], "/".join(parts[1:])
        entry = _store_get(aid)
        if not entry or fname not in entry["files"]:
            self._json({"error": "asset inexistente"}, 404)
            return
        data = entry["files"][fname]
        ctype = "image/png" if fname.endswith(".png") else (
            "model/gltf-binary" if fname.endswith(".glb") else "application/octet-stream"
        )
        self._send(200, data, ctype, {"Access-Control-Allow-Origin": "*"})

    def _static(self, path: str) -> None:
        rel = path.lstrip("/") or "index.html"
        target = (self.web_root / rel).resolve()
        if not str(target).startswith(str(self.web_root.resolve())):
            self._json({"error": "fora do root"}, 403)
            return
        if target.is_dir():
            target = target / "index.html"
        if not target.exists():
            # SPA fallback
            target = self.web_root / "index.html"
        data = target.read_bytes()
        ctype = {
            ".html": "text/html; charset=utf-8",
            ".css": "text/css; charset=utf-8",
            ".js": "text/javascript; charset=utf-8",
            ".json": "application/json",
            ".png": "image/png",
            ".svg": "image/svg+xml",
            ".ico": "image/x-icon",
            ".woff2": "font/woff2",
        }.get(target.suffix, "application/octet-stream")
        self._send(200, data, ctype, {"Cache-Control": "no-cache"})


def main() -> None:
    parser = argparse.ArgumentParser(description="Arkher AI - servidor web + API")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=int(os.environ.get("PORT", 8000)))
    args = parser.parse_args()

    Handler.web_root = ROOT / "web"
    if not Handler.web_root.exists():
        print("AVISO: pasta web/ não encontrada — só a API funcionará")

    httpd = ThreadingHTTPServer((args.host, args.port), Handler)
    httpd.daemon_threads = True
    print("=" * 64)
    print("  Arkher AI — servidor de geração")
    print(f"  URL:        http://localhost:{args.port}")
    print(f"  numpy:      {'SIM (texturas até 16k rápidas)' if HAS_NUMPY else 'NÃO (texturas limitadas a 2k; pip install numpy)'}")
    print(f"  LLM bridge: {'ON' if os.environ.get('ARKHER_LLM_API_KEY') else 'off (ARKHER_LLM_API_KEY)'}")
    print("=" * 64)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nencerrando...")


if __name__ == "__main__":
    main()

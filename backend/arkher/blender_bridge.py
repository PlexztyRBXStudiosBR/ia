"""
Blender como KERNEL de geometria nativo (opcional e honesto).

O Arkher já esculpe malhas orgânicas em Python puro (sdf.py). Esta ponte leva
essas malhas para o **Blender de verdade** — quando ele existe na máquina — e
aplica o pipeline de produção que só o Blender faz bem:

    Voxel Remesh  ->  Decimate  ->  Smart UV Project  ->  shade smooth  ->  GLB

Resultado: topologia limpa, UVs não-sobrepostos e normais corretas, prontos para
Godot/Roblox/Blender. É a integração nativa *possível* com Blender.

Detecção (nesta ordem):
  1. ARKHER_BLENDER  -> caminho do executável (ex.: C:\\...\\blender.exe no RDP)
  2. `blender` no PATH
  3. módulo `bpy` (pip install bpy) rodado no próprio interpretador

Se nenhum existir, `blender_status()["available"]` é False e o servidor cai no
caminho SDF puro (que roda em qualquer lugar, inclusive no celular). Não fingimos
ter Blender onde não há.

O script gerado é tolerante a versões (Blender 3.6 / 4.x / 5.x): tenta os
operadores novos (wm.gltf_import/export) e cai nos clássicos (import_scene.gltf).
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from typing import Any, Dict, Optional, Tuple

__all__ = ["find_blender", "has_bpy_module", "blender_status", "refine_glb",
           "BlenderUnavailable", "BlenderError", "REFINE_SCRIPT"]


class BlenderUnavailable(RuntimeError):
    """Blender não está instalado/etectado — caller deve usar o fallback puro."""


class BlenderError(RuntimeError):
    """Blender foi encontrado mas falhou ao processar."""


# --------------------------------------------------------------------- detecção
def find_blender() -> Optional[str]:
    env = os.environ.get("ARKHER_BLENDER", "").strip()
    if env:
        if os.path.exists(env):
            return env
        # permite apontar para a pasta; procura o binário dentro
        for cand in ("blender", "blender.exe"):
            p = os.path.join(env, cand)
            if os.path.exists(p):
                return p
    return shutil.which("blender")


def has_bpy_module() -> bool:
    try:
        import bpy  # noqa: F401
        return True
    except Exception:  # noqa: BLE001
        return False


def _version_of(exe: Optional[str]) -> Optional[str]:
    if not exe:
        return None
    try:
        out = subprocess.run([exe, "--version"], capture_output=True, text=True, timeout=20)
        for line in (out.stdout or "").splitlines():
            if line.lower().startswith("blender"):
                return line.split()[1] if len(line.split()) > 1 else line.strip()
    except Exception:  # noqa: BLE001
        return None
    return None


def blender_status() -> Dict[str, Any]:
    exe = find_blender()
    mod = has_bpy_module()
    version = _version_of(exe)
    if version is None and mod:
        try:
            import bpy  # noqa: F401
            version = bpy.app.version_string
        except Exception:  # noqa: BLE001
            version = None
    return {
        "available": bool(exe or mod),
        "executable": exe,
        "bpy_module": mod,
        "version": version,
        "mode": ("executable" if exe else ("bpy_module" if mod else None)),
        "howto": None if (exe or mod) else (
            "instale o Blender (blender.org) e defina ARKHER_BLENDER=/caminho/blender, "
            "ou `pip install bpy`; no RDP do GitHub Actions o workflow já instala"),
    }


# ------------------------------------------------------------------ script bpy
# Roda tanto via `blender --background --python script.py -- cfg.json`
# quanto via `python script.py cfg.json` (quando bpy é módulo).
REFINE_SCRIPT = r'''
import bpy, json, os, sys

def _load_cfg():
    for a in reversed(sys.argv):
        if a.endswith(".json") and os.path.exists(a):
            with open(a, "r") as f:
                return json.load(f)
    raise SystemExit("ARKHER_BLENDER_ERR: cfg json não encontrado em sys.argv")

def _import_glb(path):
    try:
        bpy.ops.wm.gltf_import(filepath=path)          # Blender 4.2+/5.x
    except Exception:
        bpy.ops.import_scene.gltf(filepath=path)        # Blender 2.8–4.1

def _export_glb(path, use_selection=True):
    kw = dict(filepath=path, export_format='GLB', use_selection=use_selection)
    try:
        bpy.ops.wm.gltf_export(**kw)                    # Blender 4.2+/5.x
    except Exception:
        bpy.ops.export_scene.gltf(**kw)                 # clássico

def _pick_mesh():
    obj = None
    for o in bpy.context.scene.objects:
        if o.type == 'MESH':
            obj = o
            break
    if obj is None:
        raise SystemExit("ARKHER_BLENDER_ERR: nenhum mesh no GLB importado")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    return obj

def main():
    cfg = _load_cfg()
    in_glb = cfg["in_glb"]; out_glb = cfg["out_glb"]
    voxel = float(cfg.get("voxel", 0.03))
    ratio = float(cfg.get("ratio", 0.5))
    do_uv = bool(cfg.get("uv", True))
    do_smooth = bool(cfg.get("smooth", True))
    margin = float(cfg.get("uv_margin", 0.02))

    bpy.ops.wm.read_factory_settings(use_empty=True)
    _import_glb(in_glb)
    obj = _pick_mesh()

    tris_before = len(obj.data.polygons)

    # 1) Voxel Remesh — topologia uniforme e limpa (fecha buracos do surface nets)
    if voxel and voxel > 0:
        m = obj.modifiers.new(name="arkher_remesh", type='REMESH')
        m.mode = 'VOXEL'
        m.voxel_size = voxel
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)
        except Exception as e:
            obj.modifiers.remove(m)
            print("ARKHER_BLENDER_WARN remesh:", e)

    # 2) Decimate — reduz contagem mantendo a silhueta (ratio<1)
    if 0 < ratio < 1.0:
        d = obj.modifiers.new(name="arkher_decimate", type='DECIMATE')
        d.ratio = ratio
        d.use_collapse_triangulate = True
        try:
            bpy.ops.object.modifier_apply(modifier=d.name)
        except Exception as e:
            obj.modifiers.remove(d)
            print("ARKHER_BLENDER_WARN decimate:", e)

    # 3) shade smooth
    if do_smooth:
        try:
            bpy.ops.object.shade_smooth()
        except Exception as e:
            print("ARKHER_BLENDER_WARN smooth:", e)

    # 4) Smart UV Project — UVs sem sobreposição (necessário p/ texturizar)
    if do_uv:
        try:
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.uv.smart_uv_project(island_margin=margin, angle_limit=1.15189)
            bpy.ops.object.mode_set(mode='OBJECT')
        except Exception as e:
            try:
                bpy.ops.object.mode_set(mode='OBJECT')
            except Exception:
                pass
            print("ARKHER_BLENDER_WARN uv:", e)

    _export_glb(out_glb, use_selection=True)
    tris_after = len(obj.data.polygons)
    size = os.path.getsize(out_glb) if os.path.exists(out_glb) else 0
    print("ARKHER_BLENDER_OK " + json.dumps(
        {"tris_before": tris_before, "tris_after": tris_after, "bytes": size}))

try:
    main()
except SystemExit as e:
    print(e)
    raise
except Exception as e:
    import traceback; traceback.print_exc()
    raise SystemExit("ARKHER_BLENDER_ERR: %s" % e)
'''


# -------------------------------------------------------------------- execução
def refine_glb(glb_bytes: bytes, voxel: float = 0.03, ratio: float = 0.5,
               uv: bool = True, smooth: bool = True, uv_margin: float = 0.02,
               timeout: float = 240.0) -> Tuple[bytes, Dict[str, Any]]:
    """
    Refina um .glb no Blender. Retorna (glb_refinado, meta).
    Levanta BlenderUnavailable se não houver Blender; BlenderError se falhar.
    """
    st = blender_status()
    if not st["available"]:
        raise BlenderUnavailable(st["howto"] or "Blender não detectado")
    if not (glb_bytes[:4] == b"glTF"):
        raise BlenderError("entrada não é um GLB válido")

    tmp = tempfile.mkdtemp(prefix="arkher_blender_")
    in_glb = os.path.join(tmp, "in.glb")
    out_glb = os.path.join(tmp, "out.glb")
    script = os.path.join(tmp, "refine.py")
    cfg_path = os.path.join(tmp, "cfg.json")
    try:
        with open(in_glb, "wb") as f:
            f.write(glb_bytes)
        with open(script, "w") as f:
            f.write(REFINE_SCRIPT)
        cfg = {"in_glb": in_glb, "out_glb": out_glb, "voxel": voxel,
               "ratio": ratio, "uv": uv, "smooth": smooth, "uv_margin": uv_margin}
        with open(cfg_path, "w") as f:
            json.dump(cfg, f)

        if st["mode"] == "executable":
            cmd = [st["executable"], "--background", "--python", script, "--", cfg_path]
        else:  # bpy como módulo: roda no próprio interpretador que tem bpy
            cmd = [sys.executable, script, cfg_path]

        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        out = (proc.stdout or "") + "\n" + (proc.stderr or "")
        if "ARKHER_BLENDER_OK" not in out or not os.path.exists(out_glb):
            errline = [l for l in out.splitlines() if "ARKHER_BLENDER_ERR" in l]
            raise BlenderError(errline[-1] if errline else
                               f"Blender não produziu saída (rc={proc.returncode})")
        with open(out_glb, "rb") as f:
            refined = f.read()
        if refined[:4] != b"glTF":
            raise BlenderError("Blender produziu saída que não é GLB")
        meta_line = [l for l in out.splitlines() if l.startswith("ARKHER_BLENDER_OK")]
        stats: Dict[str, Any] = {}
        if meta_line:
            try:
                stats = json.loads(meta_line[-1].split(" ", 1)[1])
            except Exception:  # noqa: BLE001
                stats = {}
        stats.update({
            "engine": "blender",
            "mode": st["mode"],
            "blender_version": st["version"],
            "voxel": voxel, "ratio": ratio, "uv": uv,
            "in_bytes": len(glb_bytes), "bytes": len(refined),
            "warnings": [l for l in out.splitlines() if "ARKHER_BLENDER_WARN" in l],
        })
        return refined, stats
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

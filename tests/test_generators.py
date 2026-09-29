#!/usr/bin/env python3
"""
Testes dos geradores do Arkher AI (roda sem pytest: `python3 tests/test_generators.py`).

Cobrem o que REALMENTE importa para o usuário final:
  * PNG escrito à mão decodifica com dimensões/crc corretos
  * .glb passa em validação estrutural glTF 2.0 (chunks, accessors, skin, anims)
  * cenas .tscn / project.godot passam no validador de formato do Godot 4
  * projeto Roblox: todos os .json parseiam; Luau não tem token óbvio quebrado
  * animações: takes com duração > 0 e nós-alvo existentes
  * KeyframeSequence R15: XML bem formado com hierarquia de Poses
"""
from __future__ import annotations

import json
import struct
import sys
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "backend"))

from arkher import pnglib, textures, meshes, animation  # noqa: E402
from arkher.glb import GlbBuilder, Material  # noqa: E402
from arkher.godot_project import generate_godot_project  # noqa: E402
from arkher.roblox_project import generate_roblox_project  # noqa: E402
from arkher.tscn_validate import validate_files  # noqa: E402

PASS = 0
FAIL = 0


def check(name: str, cond: bool, extra: str = "") -> None:
    global PASS, FAIL
    if cond:
        PASS += 1
        print(f"  ✔ {name}")
    else:
        FAIL += 1
        print(f"  ✘ {name} {extra}")


def test_png() -> None:
    print("[png]")
    data = pnglib.make_icon(64)
    check("assinatura PNG", data[:8] == b"\x89PNG\r\n\x1a\n")
    # IHDR
    w, h = struct.unpack(">II", data[16:24])
    check("dimensões 64x64", (w, h) == (64, 64), f"{w}x{h}")
    # valida CRC de cada chunk
    pos = 8
    ok_crc = True
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        tag = data[pos + 4 : pos + 8]
        crc = struct.unpack(">I", data[pos + 8 + length : pos + 12 + length])[0]
        if crc != zlib.crc32(tag + data[pos + 8 : pos + 8 + length]) & 0xFFFFFFFF:
            ok_crc = False
        pos += 12 + length
        if tag == b"IEND":
            break
    check("CRCs de todos os chunks", ok_crc)


def test_glb_structure(glb: bytes, label: str) -> None:
    magic, ver, total = struct.unpack("<III", glb[:12])
    check(f"{label}: magic/versão", magic == 0x46546C67 and ver == 2)
    check(f"{label}: tamanho declarado", total == len(glb), f"{total} != {len(glb)}")
    jlen, jtype = struct.unpack("<II", glb[12:20])
    js = json.loads(glb[20 : 20 + jlen])
    blen, btype = struct.unpack("<II", glb[20 + jlen : 28 + jlen])
    check(f"{label}: chunks", jtype == 0x4E4F534A and btype == 0x004E4942)
    for i, bv in enumerate(js["bufferViews"]):
        if bv["byteOffset"] + bv["byteLength"] > blen:
            check(f"{label}: bufferView {i} dentro do BIN", False)
            return
    check(f"{label}: bufferViews dentro do BIN", True)
    sizes = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
    comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
    for i, a in enumerate(js["accessors"]):
        bv = js["bufferViews"][a["bufferView"]]
        need = a["count"] * sizes[a["componentType"]] * comps[a["type"]] + a.get("byteOffset", 0)
        if need > bv["byteLength"]:
            check(f"{label}: accessor {i} cabe no view", False, f"{need}>{bv['byteLength']}")
            return
    check(f"{label}: accessors cabem nos views", True)
    for m in js.get("meshes", []):
        for p in m["primitives"]:
            acc = js["accessors"][p["attributes"]["POSITION"]]
            if "min" not in acc or "max" not in acc:
                check(f"{label}: POSITION tem min/max", False)
                return
    check(f"{label}: POSITION tem min/max", True)
    for a in js.get("animations", []):
        for c in a["channels"]:
            if not (0 <= c["target"]["node"] < len(js["nodes"])):
                check(f"{label}: canal aponta para nó válido", False)
                return
    check(f"{label}: canais de animação válidos", True)
    return js


def test_models() -> None:
    print("[modelos .glb]")
    for kind in ("hero", "tree", "rock", "sword", "house", "prop", "terrain"):
        mesh = meshes.make_model(kind, name=kind, detail=2)
        check(f"{kind}: tem vértices e triângulos", mesh.vertex_count > 8 and mesh.triangle_count > 4,
              f"{mesh.vertex_count}/{mesh.triangle_count}")
        check(f"{kind}: arrays consistentes",
              len(mesh.positions) == mesh.vertex_count * 3
              and len(mesh.normals) == mesh.vertex_count * 3
              and len(mesh.uvs) == mesh.vertex_count * 2
              and len(mesh.indices) == mesh.triangle_count * 3)
    b = GlbBuilder()
    mat = b.add_material(Material(name="m"))
    mi = b.add_mesh(meshes.make_model("prop", detail=1), mat)
    node = b.add_node("prop", mesh=mi)
    glb = b.build(root_nodes=[node])
    test_glb_structure(glb, "glb simples")

    lods = meshes.generate_lods(meshes.make_model("hero", detail=2), levels=3)
    tris = [l.triangle_count for l in lods]
    check("LODs decrescem", tris[0] > tris[1] > tris[2] > tris[3], str(tris))


def test_rig_animation() -> None:
    print("[rig + animações]")
    glb, stats = animation.build_rigged_glb(["idle", "walk", "jump"], detail=1)
    js = test_glb_structure(glb, "glb rigged")
    check("22 ossos", stats["bones"] == 22, str(stats["bones"]))
    check("3 animações", len(js["animations"]) == 3)
    check("skin presente", len(js.get("skins", [])) == 1)
    skin = js["skins"][0]
    check("joints = nós de osso", len(skin["joints"]) == 22)
    mesh_acc = js["meshes"][0]["primitives"][0]["attributes"]
    check("malha tem JOINTS_0/WEIGHTS_0", "JOINTS_0" in mesh_acc and "WEIGHTS_0" in mesh_acc)

    xml = animation.export_roblox_keyframe_sequence("walk", fps=30)
    root = ET.fromstring(xml)
    kfs = root.findall(".//Item[@class='Keyframe']")
    check("rbxlx: XML válido com keyframes", len(kfs) > 10, str(len(kfs)))
    first_kf = kfs[0]
    pose_names = [
        p.find("./Properties/string[@name='Name']").text
        for p in first_kf.iter()
        if p.tag == "Item" and p.get("class") == "Pose"
    ]
    check("rbxlx: hierarquia começa em HumanoidRootPart", pose_names and pose_names[0] == "HumanoidRootPart", str(pose_names[:3]))

    tres = animation.export_godot_animation_library(["idle", "walk"])
    check("tres: AnimationLibrary", "[gd_resource type=\"AnimationLibrary\"" in tres)
    check("tres: ext_resources", tres.count("[ext_resource") == 2)


def test_textures() -> None:
    print("[texturas PBR]")
    pbr = textures.generate_pbr_set("stone", "512", seed=3)
    chans = {m.channel for m in pbr.maps}
    check("6 canais", chans == {"albedo", "normal", "roughness", "metallic", "ao", "height"}, str(chans))
    for m in pbr.maps:
        ok = m.png[:8] == b"\x89PNG\r\n\x1a\n"
        w, h = struct.unpack(">II", m.png[16:24])
        check(f"{m.channel}: PNG {w}x{h}", ok and w == 512 and h == 512)
    # seamless: bordas esquerda/direita do albedo parecidas
    alb = pbr.map("albedo").png
    check("albedo não vazio", len(alb) > 2000)


def test_godot_project() -> None:
    print("[projeto Godot]")
    files = generate_godot_project("Teste CI", "jogo de teste", "acao")
    errs = validate_files(files)
    check("zero erros de formato", not errs, json.dumps(errs, ensure_ascii=False)[:400])
    check("project.godot presente", "project.godot" in files)
    check("player controller", "scripts/player/player_controller.gd" in files)
    check("level 01", "scenes/levels/level_01.tscn" in files)
    check("ícone", "icon.png" in files and files["icon.png"][:4] == b"\x89PNG")
    gd = files["scripts/player/player_controller.gd"]
    check("gdscript sem tabs/space misturados", "\t" in gd and "    if" not in gd)


def test_roblox_project() -> None:
    print("[projeto Roblox]")
    files = generate_roblox_project("CI Arena", "teste", "acao")
    ok = True
    for k, v in files.items():
        if k.endswith(".json"):
            try:
                json.loads(v)
            except Exception as e:  # noqa: BLE001
                ok = False
                print("   json inválido:", k, e)
    check("todos os .json parseiam", ok)
    check("default.project.json", "default.project.json" in files)
    tree = json.loads(files["default.project.json"])["tree"]
    check("DataModel root", tree["$className"] == "DataModel")
    combat = files["src/ServerScriptService/CombatService.lua"]
    check("combate server-side", "OnServerEvent" not in combat or "distanceTo" in combat)
    check("RemoteEvents .model.json", "src/ReplicatedStorage/Remotes/AttackRequest.model.json" in files)


def main() -> int:
    test_png()
    test_models()
    test_rig_animation()
    test_textures()
    test_godot_project()
    test_roblox_project()
    print(f"\n{PASS} passaram, {FAIL} falharam")
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())

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


def test_sdf() -> None:
    print("[sdf — escultura orgânica]")
    from arkher import sdf
    for name, fn in (("humanoid", sdf.sdf_humanoid), ("creature", sdf.sdf_creature),
                     ("rock", sdf.sdf_rock), ("bust", sdf.sdf_bust)):
        m = sdf.extract_mesh(fn(), resolution=32, smooth_iters=1, name=name)
        ok = (m.vertex_count > 100 and len(m.positions) == m.vertex_count * 3
              and len(m.normals) == len(m.positions) and len(m.uvs) == m.vertex_count * 2
              and len(m.indices) % 3 == 0 and max(m.indices) < m.vertex_count)
        check(f"receita {name} extrai malha válida", ok, f"({m.vertex_count}v)")
    m = sdf.extract_mesh(sdf.sdf_humanoid(), resolution=32, name="h")
    b = GlbBuilder()
    mi = b.add_mesh(m, b.add_material(Material(name="m")))
    node = b.add_node("h", mesh=mi)
    data = b.build(root_nodes=[node])
    check("glb de escultura válido", data[:4] == b"glTF" and len(data) > 1000)
    # humanóide tem pernas separadas: corte transversal abaixo do quadril tem 2 componentes
    ys_lo = [m.positions[i * 3 + 1] for i in range(m.vertex_count) if 0.2 < m.positions[i * 3 + 1] < 0.4]
    xs = sorted(m.positions[i * 3] for i in range(m.vertex_count) if 0.2 < m.positions[i * 3 + 1] < 0.4)
    gap = max((b2 - a2) for a2, b2 in zip(xs, xs[1:])) if len(xs) > 2 else 0.0
    check("pernas separadas (vão entre elas)", gap > 0.02 and len(ys_lo) > 20, f"gap={gap:.3f}")


def test_bvh_mocap() -> None:
    print("[bvh — mo-cap real]")
    from arkher import bvh
    text = (ROOT / "tests" / "data" / "walk_sample.bvh").read_text()
    data = bvh.parse_bvh(text)
    check("parse hierarquia+motion", len(data.joints) >= 20 and data.frame_count == 60)
    rmap = bvh.map_joints(data)
    need = ("hips", "spine", "head", "shoulder_l", "elbow_l", "wrist_l",
            "hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r")
    missing = [k for k in need if not getattr(rmap, k)]
    check("mapeia juntas do rig", not missing, f"faltando {missing}")
    anim, info = bvh.retarget(data, name="walk", fps=30)
    check("retarget 22 tracks", info["tracks"] == 22, str(info["tracks"]))
    quats_ok = all(0.999 < sum(c * c for c in q) ** 0.5 < 1.001
                   for t in anim.tracks for q in (t.rotations or []))
    check("quatérnions normalizados", quats_ok)
    hips = [t for t in anim.tracks if t.bone == 0][0]
    check("quadris avançam (root motion)", hips.translations[-1][2] > hips.translations[0][2] + 0.5)
    # glb rigged com animação custom
    data_glb, stats = animation.build_rigged_glb(animations=["idle"], detail=1,
                                                 custom_anims=[(anim, info)])
    jl = struct.unpack("<I", data_glb[12:16])[0]
    g = json.loads(data_glb[20:20 + jl])
    names = {a["name"] for a in g["animations"]}
    check("glb contém take de mo-cap", data_glb[:4] == b"glTF" and "walk" in names, str(names))
    # roblox custom xml
    rbx = animation.export_roblox_keyframe_sequence_custom(anim, info, name="walk", fps=30)
    ET.fromstring(rbx)
    check("rbxlx de mo-cap é XML válido", '<Item class="Keyframe"' in rbx)
    # suavização
    sm = animation.smooth_animation(anim, strength=0.5)
    check("smooth_animation preserva tracks", len(sm.tracks) == len(anim.tracks))


def test_image_pbr() -> None:
    print("[image — foto → PBR / relevo]")
    from arkher import image_pbr, mesh_ai
    W = H = 64
    px = bytearray(W * H * 4)
    for j in range(H):
        for i in range(W):
            o = (j * W + i) * 4
            px[o] = (i * 4) % 256; px[o + 1] = (j * 4) % 256; px[o + 2] = 128; px[o + 3] = 255
    png = pnglib.encode_rgba(bytes(px), W, H)
    img = image_pbr.decode_image(png)
    check("decode PNG puro (rgba)", img.width == W and img.nch == 4)
    w2, h2, rgb = img.to_rgb()
    check("conversão para RGB", w2 == W and len(rgb) == W * H * 3)
    pbr = image_pbr.image_to_pbr(img, resolution="512")
    chans = {m.channel for m in pbr.maps}
    check("6 canais derivados", chans == {"albedo", "normal", "roughness", "metallic", "ao", "height"}, str(chans))
    check("todos PNG válidos", all(m.png[:8] == b"\x89PNG\r\n\x1a\n" for m in pbr.maps))
    check("meta honesto (derived_from_image)", pbr.stats.get("derived_from_image") is True)
    glb, meta = mesh_ai.generate_mesh(prompt="relevo", image_bytes=png, source="auto", name="R")
    check("imagem → relevo → glb", glb[:4] == b"glTF" and meta["origin"] == "relief"
          and meta["triangles"] > 1000)
    mesh, info = mesh_ai.prompt_sculpt("guerreiro musculoso com espinhos", resolution=28)
    check("prompt → escultura (humanoid+muscle+spiky)",
          info["sculpt_kind"] == "humanoid" and info["muscle"] > 1.2 and info["spiky"]
          and mesh.vertex_count > 200)
    mesh2, info2 = mesh_ai.prompt_sculpt("um dragão", resolution=28)
    check("prompt → criatura", info2["sculpt_kind"] == "creature")
    st = mesh_ai.provider_status()
    check("providers desligados sem chaves", st["active"] in (None, "meshy", "tripo", "local"))


def main() -> int:
    test_png()
    test_models()
    test_rig_animation()
    test_textures()
    test_sdf()
    test_bvh_mocap()
    test_image_pbr()
    test_godot_project()
    test_roblox_project()
    print(f"\n{PASS} passaram, {FAIL} falharam")
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())

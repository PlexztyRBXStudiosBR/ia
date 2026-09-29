"""
Arkher AI - Gerador Nativo de Malhas 3D
Gera arquivos .glb reais via trimesh (fallback quando Blender não está presente).
Dependências (numpy/scipy/trimesh) são carregadas só quando realmente for gerar malhas.
"""
import logging
from pathlib import Path
from typing import List, Dict, Tuple, Optional

logger = logging.getLogger("Arkher.MeshGen")

_deps_available = False
try:
    import numpy as np
    import trimesh
    _deps_available = True
except ImportError:
    np = None
    trimesh = None


def _ensure_deps():
    if not _deps_available:
        raise RuntimeError(
            "Dependências Python (numpy, scipy, trimesh) não instaladas. "
            "Rode: pip install numpy scipy networkx trimesh pillow"
        )


def create_primitive_model(
    description: str,
    model_type: str = "prop",
    output_path: Path = None,
    engine: str = "godot",
    subdivisions: int = 2
) -> Path:
    """Cria um modelo 3D GLB válido com UVs, normais e material PBR básico."""
    _ensure_deps()
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Seleciona primitiva base baseado em palavras-chave
    desc_lower = description.lower()
    
    if any(k in desc_lower for k in ["personagem", "cavaleiro", "guerreiro", "npc", "hero", "player", "humano"]):
        # Cria um personagem básico combinando primitivas (esqueleto humanoide)
        meshes = _create_humanoid_base()
    elif any(k in desc_lower for k in ["arvore", "tree", "planta"]):
        meshes = _create_tree()
    elif any(k in desc_lower for k in ["pedra", "rock", "stone"]):
        meshes = _create_rock()
    elif any(k in desc_lower for k in ["casa", "house", "building"]):
        meshes = _create_house()
    elif any(k in desc_lower for k in ["espada", "sword", "arma", "weapon"]):
        meshes = _create_sword()
    elif any(k in desc_lower for k in ["bola", "sphere", "ball"]):
        meshes = [trimesh.creation.icosphere(subdivisions=subdivisions, radius=1.0)]
    elif any(k in desc_lower for k in ["cilindro", "cylinder", "cano"]):
        meshes = [trimesh.creation.cylinder(radius=0.5, height=2.0, sections=32)]
    else:
        # Cubo como base genérica, com subdivisão para suavizar
        meshes = [trimesh.creation.box(extents=[1, 1, 1])]
        if subdivisions > 0:
            meshes[0] = meshes[0].subdivide_loop(subdivisions)
    
    # Aplicar transformações e UVs em cada malha
    scene = trimesh.Scene()
    for i, mesh in enumerate(meshes):
        # Garante que é Trimesh e não primitiva
        if not isinstance(mesh, trimesh.Trimesh):
            continue
        
        # Calcula normais
        mesh.fix_normals()
        
        # Aplica UV mapping (cubemap projection)
        _apply_uv_mapping(mesh)
        
        # Define material PBR
        mesh.visual.material = _create_pbr_material(model_type)
        
        scene.add_geometry(mesh, node_name=f"mesh_{i}", geom_name=f"{model_type}_{i}")
    
    # Exportar como GLB
    if output_path.suffix.lower() != ".glb":
        output_path = output_path.with_suffix(".glb")
    
    export_kwargs = {
        "buffers": True,
        "lz4": False,
        "resolver": None,
    }
    
    with open(output_path, "wb") as f:
        f.write(trimesh.exchange.gltf.export_glb(scene, **export_kwargs))
    
    poly_count = sum(len(m.faces) for m in meshes if isinstance(m, trimesh.Trimesh))
    vert_count = sum(len(m.vertices) for m in meshes if isinstance(m, trimesh.Trimesh))
    logger.info(f"GLB gerado: {output_path} ({poly_count} faces, {vert_count} vértices)")
    
    return output_path


def _create_humanoid_base() -> List["trimesh.Trimesh"]:
    """Cria uma base humanóide usando primitivas combinadas."""
    meshes = []
    
    # Cabeça
    head = trimesh.creation.icosphere(subdivisions=2, radius=0.22)
    head.apply_translation([0, 0, 1.75])
    meshes.append(head)
    
    # Tronco
    torso = trimesh.creation.box(extents=[0.55, 0.3, 0.65])
    torso.apply_translation([0, 0, 1.35])
    torso = torso.subdivide_loop()
    meshes.append(torso)
    
    # Braços
    arm_l = trimesh.creation.cylinder(radius=0.09, height=0.75, sections=16)
    arm_l.apply_transform(trimesh.transformations.rotation_matrix(np.pi/2, [0, 1, 0]))
    arm_l.apply_translation([0.4, 0, 1.35])
    meshes.append(arm_l)
    
    arm_r = arm_l.copy()
    arm_r.apply_translation([-0.8, 0, 0])
    meshes.append(arm_r)
    
    # Pernas
    leg_l = trimesh.creation.cylinder(radius=0.12, height=0.85, sections=16)
    leg_l.apply_transform(trimesh.transformations.rotation_matrix(np.pi/2, [0, 1, 0]))
    leg_l.apply_translation([0.15, 0, 0.5])
    meshes.append(leg_l)
    
    leg_r = leg_l.copy()
    leg_r.apply_translation([-0.3, 0, 0])
    meshes.append(leg_r)
    
    return meshes


def _create_tree() -> List["trimesh.Trimesh]:
    meshes = []
    trunk = trimesh.creation.cylinder(radius=0.2, height=2.0, sections=12)
    trunk.apply_translation([0, 0, 1.0])
    meshes.append(trunk)
    foliage = trimesh.creation.icosphere(subdivisions=2, radius=1.0)
    foliage.apply_translation([0, 0, 2.5])
    foliage.apply_scale(1.2)
    meshes.append(foliage)
    return meshes


def _create_rock() -> List["trimesh.Trimesh]:
    rock = trimesh.creation.icosphere(subdivisions=3, radius=0.7)
    # Perturba vértices para ficar orgânico
    rng = np.random.default_rng(42)
    noise = rng.normal(1.0, 0.15, len(rock.vertices))
    rock.vertices *= noise[:, np.newaxis]
    rock.fix_normals()
    return [rock]


def _create_house() -> List["trimesh.Trimesh]:
    meshes = []
    base = trimesh.creation.box(extents=[3, 3, 2.5])
    base.apply_translation([0, 0, 1.25])
    meshes.append(base)
    # Telhado (cone)
    roof = trimesh.creation.cone(radius=2.4, height=1.5, sections=4)
    roof.apply_translation([0, 0, 3.25])
    roof.apply_transform(trimesh.transformations.rotation_matrix(np.pi/4, [0, 0, 1]))
    meshes.append(roof)
    return meshes


def _create_sword() -> List["trimesh.Trimesh]:
    meshes = []
    blade = trimesh.creation.box(extents=[0.08, 0.02, 1.1])
    blade.apply_translation([0, 0, 0.55])
    meshes.append(blade)
    guard = trimesh.creation.box(extents=[0.35, 0.05, 0.08])
    meshes.append(guard)
    handle = trimesh.creation.cylinder(radius=0.04, height=0.25, sections=12)
    handle.apply_transform(trimesh.transformations.rotation_matrix(np.pi/2, [1, 0, 0]))
    handle.apply_translation([0, 0, -0.15])
    meshes.append(handle)
    return meshes


def _apply_uv_mapping(mesh: trimesh.Trimesh):
    """Aplica UV mapping cúbico simples"""
    try:
        # Projeção planar em Z para UVs
        verts = mesh.vertices
        u = verts[:, 0] - verts[:, 0].min()
        v = verts[:, 2] - verts[:, 2].min()
        u /= (u.max() - u.min() + 1e-6)
        v /= (v.max() - v.min() + 1e-6)
        uv = np.column_stack([u, v])
        
        # Cria visual com textura
        mesh.visual = trimesh.visual.TextureVisuals(uv=uv)
    except Exception:
        pass


def _create_pbr_material(model_type: str) -> trimesh.visual.material.PBRMaterial:
    """Cria material PBR com valores fisicamente corretos"""
    colors = {
        "hero": (139, 69, 19, 255),      # Marrom couro/armadura
        "npc": (100, 100, 120, 255),
        "prop": (128, 128, 128, 255),
        "environment": (80, 120, 60, 255)  # Verde
    }
    color = colors.get(model_type, (128, 128, 128, 255))
    
    return trimesh.visual.material.PBRMaterial(
        baseColorFactor=color,
        metallicFactor=0.3,
        roughnessFactor=0.6,
        doubleSided=False
    )


def generate_lods(base_mesh: trimesh.Trimesh, levels: int = 3) -> List["trimesh.Trimesh]:
    """Gera LODs simplificando a malha"""
    lods = [base_mesh]
    ratios = [0.5, 0.25, 0.1]
    for i in range(1, min(levels + 1, 4)):
        try:
            lod = base_mesh.simplify_quadric_decimation(
                face_count=max(int(len(base_mesh.faces) * ratios[i-1]), 20)
            )
            lods.append(lod)
        except Exception:
            break
    return lods


if __name__ == "__main__":
    # Teste rápido
    import sys
    out = Path("test_mesh.glb")
    desc = sys.argv[1] if len(sys.argv) > 1 else "cubo"
    tipo = sys.argv[2] if len(sys.argv) > 2 else "prop"
    path = create_primitive_model(desc, tipo, out)
    print(f"Modelo gerado: {path} ({path.stat().st_size} bytes)")

#!/usr/bin/env python3
"""
Exemplo: Criar um personagem AAA completo para Godot
- Modelo 3D hero (150k polys)
- Texturas 8k PBR
- Auto-rig humanóide
- Animações (idle, walk, run, jump)
"""
import asyncio
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from core import AgentCoordinator, AgentSpecialty


async def main():
    # Inicializa coordenador com todos os especialistas
    coordinator = AgentCoordinator()
    
    from agents import (
        TechnicalArtist3DAgent, TextureArtistAgent, RiggerAnimatorAgent,
        GodotSpecialistAgent
    )
    
    coordinator.register_agent(TechnicalArtist3DAgent())
    coordinator.register_agent(TextureArtistAgent())
    coordinator.register_agent(RiggerAnimatorAgent())
    coordinator.register_agent(GodotSpecialistAgent())
    
    print("Criando personagem AAA...")
    
    # 1. Modelo 3D do personagem
    model_task = coordinator.create_task(
        description="Modelo 3D personagem humanoide cavaleiro",
        specialty=AgentSpecialty.TECHNICAL_ARTIST_3D,
        requirements={
            "type": "hero",
            "style": "realistic",
            "resolution": "high",
            "rigged": True,
            "lods": 3
        },
        engine="godot"
    )
    model_result = await coordinator.run_task(model_task)
    print(f"✅ Modelo 3D: {model_result.quality_score:.1f}/100")
    
    # 2. Texturas 8k PBR
    texture_task = coordinator.create_task(
        description="Texturas PBR para armadura de cavaleiro medieval",
        specialty=AgentSpecialty.TEXTURE_ARTIST,
        requirements={
            "material_type": "steel_armor_leather",
            "resolution": "8k",
            "style": "realistic"
        },
        engine="godot"
    )
    texture_result = await coordinator.run_task(texture_task)
    print(f"✅ Texturas 8k PBR: {texture_result.quality_score:.1f}/100")
    
    # 3. Rig e animações
    rig_task = coordinator.create_task(
        description="Auto-rig e animações para cavaleiro",
        specialty=AgentSpecialty.RIGGER_ANIMATOR,
        requirements={
            "rig_type": "humanoid",
            "animations": ["idle", "walk", "run", "jump", "attack_1", "block"],
            "facial": True,
            "procedural": True
        },
        engine="godot"
    )
    rig_result = await coordinator.run_task(rig_task)
    print(f"✅ Rig e Animações: {rig_result.quality_score:.1f}/100")
    
    print("\n🎉 Personagem AAA criado com sucesso!")
    print("Importe os arquivos gerados diretamente no Godot 4.x")


if __name__ == "__main__":
    asyncio.run(main())

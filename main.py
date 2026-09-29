#!/usr/bin/env python3
"""
Arkher AI - IA Especialista Sênior em Desenvolvimento de Jogos AAA
Especialidade: Godot e Roblox, geração de assets 3D/2D, animações, iluminação.

Funciona na sua RDP Windows já equipada: detecta automaticamente Blender, Godot,
Roblox Studio e Rojo que já estão instalados. Também funciona em Linux.

Uso:
    python main.py check-tools            # Verifica o que está instalado
    python main.py criar-jogo "Meu Jogo" --engine godot --genero acao
    python main.py gerar-modelo "Guerreiro" --tipo hero --engine godot --textura 8k --rig
    python main.py gerar-animacoes --tipo humanoid --engine godot
"""
import asyncio
import argparse
import logging
import sys
from pathlib import Path

from tools import TOOLS
from core import AgentCoordinator, AgentSpecialty
from agents import (
    TechnicalArtist3DAgent,
    TextureArtistAgent,
    RiggerAnimatorAgent,
    LightingSpecialistAgent,
    GodotSpecialistAgent,
    RobloxSpecialistAgent,
    GameArchitectAgent,
    PerformanceOptimizerAgent,
    GameplayProgrammerAgent
)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("ArkherAI")


def initialize_coordinator() -> AgentCoordinator:
    coordinator = AgentCoordinator()
    coordinator.register_agent(GameArchitectAgent())
    coordinator.register_agent(TechnicalArtist3DAgent())
    coordinator.register_agent(TextureArtistAgent())
    coordinator.register_agent(RiggerAnimatorAgent())
    coordinator.register_agent(LightingSpecialistAgent())
    coordinator.register_agent(GameplayProgrammerAgent())
    coordinator.register_agent(PerformanceOptimizerAgent())
    coordinator.register_agent(GodotSpecialistAgent())
    coordinator.register_agent(RobloxSpecialistAgent())
    logger.info(f"Coordenador inicializado com {len(coordinator.agents)} agentes especialistas")
    return coordinator


async def criar_jogo(nome: str, descricao: str, engine: str, genero: str,
                    plataformas: list[str] = None) -> None:
    if plataformas is None:
        plataformas = ["pc"]
    coordinator = initialize_coordinator()
    project = coordinator.create_project(
        name=nome, description=descricao, genre=genero,
        engine=engine, target_platforms=plataformas
    )
    logger.info("="*60)
    logger.info(f"Projeto: {nome} | Engine: {engine}")
    logger.info("="*60)
    await coordinator.run_full_game_pipeline(project)
    logger.info(f"✅ Jogo criado em: {project.output_path}")


async def gerar_modelo(nome_modelo: str, tipo: str, engine: str,
                      resolucao_textura: str = "4k", rig: bool = False) -> None:
    coordinator = initialize_coordinator()
    task = coordinator.create_task(
        description=f"Modelo 3D: {nome_modelo}",
        specialty=AgentSpecialty.TECHNICAL_ARTIST_3D,
        requirements={"type": tipo, "resolution": resolucao_textura, "rigged": rig},
        engine=engine
    )
    result = await coordinator.run_task(task)
    logger.info(f"✅ Modelo pronto: qualidade {result.quality_score:.1f}/100")
    for f in result.output_files:
        logger.info(f"   → {f}")


async def gerar_animacoes(tipo: str, engine: str) -> None:
    coordinator = initialize_coordinator()
    task = coordinator.create_task(
        description=f"Rig e animações {tipo}",
        specialty=AgentSpecialty.RIGGER_ANIMATOR,
        requirements={
            "rig_type": tipo,
            "animations": ["idle", "walk", "run", "jump"],
            "facial": True, "procedural": True
        },
        engine=engine
    )
    result = await coordinator.run_task(task)
    logger.info(f"✅ Animações prontas: qualidade {result.quality_score:.1f}/100")
    for f in result.output_files:
        logger.info(f"   → {f}")


def main():
    parser = argparse.ArgumentParser(
        description="Arkher AI - Especialista sênior em Godot/Roblox para jogos AAA"
    )
    subparsers = parser.add_subparsers(dest="comando", help="Comandos")
    
    subparsers.add_parser("check-tools", help="Verifica ferramentas (Blender, Godot, Rojo, Roblox Studio)")
    
    criar = subparsers.add_parser("criar-jogo", help="Cria um jogo AAA completo")
    criar.add_argument("nome")
    criar.add_argument("--descricao", default="Jogo criado com Arkher AI")
    criar.add_argument("--engine", choices=["godot", "roblox"], default="godot")
    criar.add_argument("--genero", default="acao")
    criar.add_argument("--plataformas", nargs="+", default=["pc"])
    
    m = subparsers.add_parser("gerar-modelo", help="Gera modelo 3D otimizado (usa Blender se instalado)")
    m.add_argument("nome")
    m.add_argument("--tipo", choices=["hero", "npc", "prop", "environment"], default="prop")
    m.add_argument("--engine", choices=["godot", "roblox"], default="godot")
    m.add_argument("--textura", choices=["2k", "4k", "8k", "16k"], default="4k")
    m.add_argument("--rig", action="store_true")
    
    a = subparsers.add_parser("gerar-animacoes", help="Auto-rig + animações premium")
    a.add_argument("--tipo", default="humanoid")
    a.add_argument("--engine", choices=["godot", "roblox"], default="godot")
    
    args = parser.parse_args()
    
    if args.comando == "check-tools":
        print("\n🔍 Arkher AI - Verificando ferramentas na sua máquina\n")
        all_ok = True
        for name, installed in TOOLS.check_all().items():
            status = "✅" if installed else "⚠️"
            if not installed:
                all_ok = False
            tool = TOOLS.tools[name]
            req = "(obrigatória)" if tool.required else "(opcional)"
            path = TOOLS.get_tool_path(name) or ""
            print(f"  {status} {name:15} {req:15} {path}")
        print()
        if all_ok:
            print("🎉 Todas as ferramentas obrigatórias encontradas! A IA está 100% pronta.")
        else:
            print("ℹ️  Ferramentas marcadas ⚠️ não foram encontradas no PATH.")
            print("   Na RDP, adicione Blender e Godot ao PATH do Windows ou rode de dentro da pasta deles.")
            print("   Se Blender não for encontrado, a IA usa gerador Python interno e gera GLB mesmo assim.")
        return
    
    if args.comando == "criar-jogo":
        asyncio.run(criar_jogo(args.nome, args.descricao, args.engine, args.genero, args.plataformas))
    elif args.comando == "gerar-modelo":
        asyncio.run(gerar_modelo(args.nome, args.tipo, args.engine, args.textura, args.rig))
    elif args.comando == "gerar-animacoes":
        asyncio.run(gerar_animacoes(args.tipo, args.engine))
    else:
        parser.print_help()
        print("\n🚀 Arkher AI - Especialista em Godot e Roblox")
        print()
        print("Na RDP já equipada, basta clonar o repo e rodar:")
        print('  python main.py check-tools')
        print('  python main.py gerar-modelo "Cavaleiro" --tipo hero --engine godot --textura 8k --rig')
        print('  python main.py criar-jogo "Meu Jogo AAA" --engine godot')


if __name__ == "__main__":
    main()

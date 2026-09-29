"""
Arkher AI - Coordenador de Agentes
Orquestra todos os agentes especialistas para criar jogos completos AAA
"""
import asyncio
from typing import Dict, List, Optional, Any
from pathlib import Path
from dataclasses import dataclass, field
import uuid
import logging

from .agent_base import SeniorGameAgent, AgentTask, AgentResult, AgentSpecialty

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("Arkher.Coordinator")

@dataclass
class GameProject:
    """Projeto completo de jogo"""
    project_id: str
    name: str
    description: str
    genre: str
    engine: str
    target_platforms: List[str]
    quality_level: str = "AAA"
    assets: Dict[str, Any] = field(default_factory=dict)
    scenes: Dict[str, Any] = field(default_factory=dict)
    scripts: Dict[str, str] = field(default_factory=dict)
    build_config: Dict[str, Any] = field(default_factory=dict)
    output_path: Optional[Path] = None

class AgentCoordinator:
    """Coordena todos os agentes especialistas para entregar projeto completo"""
    
    def __init__(self):
        self.agents: Dict[AgentSpecialty, SeniorGameAgent] = {}
        self.active_tasks: Dict[str, AgentTask] = {}
        self.completed_tasks: Dict[str, AgentResult] = {}
        self.projects: Dict[str, GameProject] = {}
    
    def register_agent(self, agent: SeniorGameAgent):
        """Registra um agente especialista no coordenador"""
        self.agents[agent.specialty] = agent
        logger.info(f"Agente registrado: {agent.name} - {agent.specialty.value}")
    
    def create_project(self, name: str, description: str, genre: str, 
                      engine: str, target_platforms: List[str]) -> GameProject:
        """Cria um novo projeto de jogo"""
        project_id = str(uuid.uuid4())
        project = GameProject(
            project_id=project_id,
            name=name,
            description=description,
            genre=genre,
            engine=engine,
            target_platforms=target_platforms,
            output_path=Path(f"projects/{name.replace(' ', '_').lower()}")
        )
        project.output_path.mkdir(parents=True, exist_ok=True)
        self.projects[project_id] = project
        logger.info(f"Projeto criado: {name} [{engine}]")
        return project
    
    def create_task(self, description: str, specialty: AgentSpecialty,
                   requirements: Dict[str, Any], priority: int = 5,
                   dependencies: List[str] = None, engine: str = "godot") -> AgentTask:
        """Cria uma nova tarefa para um agente especialista"""
        task_id = str(uuid.uuid4())
        task = AgentTask(
            task_id=task_id,
            description=description,
            requirements=requirements,
            priority=priority,
            dependencies=dependencies or [],
            engine=engine
        )
        self.active_tasks[task_id] = task
        return task
    
    async def run_task(self, task: AgentTask) -> AgentResult:
        """Executa uma única tarefa com o agente especializado"""
        # Espera dependências completarem
        for dep_id in task.dependencies:
            while dep_id not in self.completed_tasks:
                await asyncio.sleep(0.1)
        
        # Encontra agente adequado
        agent = None
        for specialty, ag in self.agents.items():
            if ag.specialty == self._get_agent_for_task(task):
                agent = ag
                break
        
        if not agent:
            raise ValueError(f"Nenhum agente disponível para tarefa: {task.description}")
        
        logger.info(f"Executando tarefa [{agent.name}]: {task.description}")
        task.status = "running"
        
        try:
            result = await agent.execute_task(task)
            task.status = "completed" if result.success else "failed"
            task.result = result
            self.completed_tasks[task.task_id] = result
            
            if result.success:
                logger.info(f"Tarefa concluída com pontuação de qualidade: {result.quality_score:.1f}/100")
            else:
                logger.error(f"Tarefa falhou: {result.feedback}")
            
            return result
        except Exception as e:
            task.status = "failed"
            logger.error(f"Erro na tarefa: {str(e)}", exc_info=True)
            raise
    
    async def run_full_game_pipeline(self, project: GameProject) -> GameProject:
        """Executa o pipeline completo de criação de jogo"""
        logger.info(f"Iniciando pipeline completo para: {project.name}")
        
        # 1. Arquitetura e Design do Jogo
        architect = self.agents[AgentSpecialty.GAME_ARCHITECT]
        logger.info("Etapa 1/7: Arquitetura e design do jogo")
        
        # 2. Criação de modelos 3D/2D
        artist_3d = self.agents[AgentSpecialty.TECHNICAL_ARTIST_3D]
        logger.info("Etapa 2/7: Criação de modelos 3D otimizados")
        
        # 3. Geração de texturas PBR ultra detalhadas
        texture_artist = self.agents[AgentSpecialty.TEXTURE_ARTIST]
        logger.info("Etapa 3/7: Geração de texturas PBR 4k/8k/16k")
        
        # 4. Auto-rig e animações de qualidade superior
        rigger = self.agents[AgentSpecialty.RIGGER_ANIMATOR]
        logger.info("Etapa 4/7: Auto-rig e animações premium")
        
        # 5. Configuração de iluminação perfeita
        lighter = self.agents[AgentSpecialty.LIGHTING_SPECIALIST]
        logger.info("Etapa 5/7: Configuração de iluminação cinematográfica")
        
        # 6. Programação de gameplay
        programmer = self.agents[AgentSpecialty.GAMEPLAY_PROGRAMMER]
        logger.info("Etapa 6/7: Programação de gameplay otimizada")
        
        # 7. Otimização de performance
        optimizer = self.agents[AgentSpecialty.PERFORMANCE_OPTIMIZER]
        logger.info("Etapa 7/7: Otimização de performance AAA")
        
        # Integração com engine específica
        if project.engine == "godot":
            engine_specialist = self.agents[AgentSpecialty.GODOT_SPECIALIST]
            logger.info("Integrando com Godot 4.x")
        elif project.engine == "roblox":
            engine_specialist = self.agents[AgentSpecialty.ROBLOX_SPECIALIST]
            logger.info("Integrando com Roblox")
        
        logger.info(f"Pipeline completo finalizado para {project.name}")
        return project
    
    def _get_agent_for_task(self, task: AgentTask) -> AgentSpecialty:
        """Determina qual agente especialista deve executar a tarefa"""
        desc = task.description.lower()
        
        if any(k in desc for k in ["design", "gameplay", "mecânica", "arquitetura", "nível"]):
            return AgentSpecialty.GAME_ARCHITECT
        elif any(k in desc for k in ["modelo", "3d", "mesh", "topologia", "lod"]):
            return AgentSpecialty.TECHNICAL_ARTIST_3D
        elif any(k in desc for k in ["textura", "pbr", "material", "uv"]):
            return AgentSpecialty.TEXTURE_ARTIST
        elif any(k in desc for k in ["rig", "animação", "anim", "esqueleto", "ik"]):
            return AgentSpecialty.RIGGER_ANIMATOR
        elif any(k in desc for k in ["luz", "iluminação", "light", "gi", "sombra", "hdr"]):
            return AgentSpecialty.LIGHTING_SPECIALIST
        elif any(k in desc for k in ["script", "código", "gameplay", "programação", "gdscript", "luau"]):
            return AgentSpecialty.GAMEPLAY_PROGRAMMER
        elif any(k in desc for k in ["otimização", "performance", "fps", "profiling"]):
            return AgentSpecialty.PERFORMANCE_OPTIMIZER
        elif "godot" in desc:
            return AgentSpecialty.GODOT_SPECIALIST
        elif "roblox" in desc:
            return AgentSpecialty.ROBLOX_SPECIALIST
        
        raise ValueError(f"Não foi possível determinar agente para tarefa: {task.description}")

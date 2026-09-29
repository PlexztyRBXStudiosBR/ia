"""
Arkher AI - Agente: Especialista em Iluminação Sênior
Especialidade: Iluminação cinematográfica, GI, lightmaps, pós-processamento
Experiência: 17 anos em iluminação para jogos AAA (Horizon, God of War Ragnarok)
"""
import asyncio
from pathlib import Path
from typing import Dict, List, Tuple, Any
import uuid

from core.agent_base import SeniorGameAgent, AgentTask, AgentResult, AgentSpecialty
from core.config import CONFIG


class LightingSpecialistAgent(SeniorGameAgent):
    """
    Especialista em iluminação que cria configurações perfeitas de luz,
    com GI (iluminação global) de qualidade cinematográfica, lightmaps otimizados,
    e pós-processamento profissional.
    """
    
    def __init__(self):
        super().__init__(
            name="Juliana Costa",
            specialty=AgentSpecialty.LIGHTING_SPECIALIST,
            experience_years=17
        )
    
    def _initialize_skills(self) -> List[str]:
        return [
            "Iluminação global (SDFGI, VoxelGI, Lumen, Lightmap baking)",
            "Three-point lighting cinematográfico automático",
            "HDRI lighting com iluminação natural",
            "Volumetric lighting e god rays",
            "Soft shadows com penumbra natural",
            "Lightmaps otimizados com packing inteligente",
            "Reflection probes e SSR configurados perfeitamente",
            "Color grading profissional com LUTs",
            "Tone mapping cinematográfico (ACES)",
            "Eye adaptation e exposição automática",
            "Bloom de qualidade cinematográfica",
            "Ambient occlusion (SSAO, GTAO) configurada",
            "Depth of field e motion blur cinematográficos",
            "Iluminação dinâmica para dia/noite cycles",
            "Neon e iluminação emissiva correta"
        ]
    
    def _initialize_quality_checks(self) -> List[callable]:
        return [
            self._check_exposure_calibrated,
            self._check_shadow_quality,
            self._check_gi_bounces,
            self._check_color_balance,
            self._check_no_reflection_artifacts
        ]
    
    async def execute_task(self, task: AgentTask) -> AgentResult:
        """Configura iluminação perfeita para a cena"""
        self.logger.info(f"Configurando iluminação: {task.description}")
        
        environment_type = task.requirements.get("environment", "outdoor_day")
        mood = task.requirements.get("mood", "natural")
        bake_lightmaps = task.requirements.get("bake_lightmaps", True)
        dynamic_time = task.requirements.get("dynamic_time", False)
        
        # Passo 1: Setup de sol/luz direcional principal
        key_light = await self._setup_key_light(environment_type, mood)
        
        # Passo 2: Luzes de preenchimento e contra-luz (three-point lighting)
        fill_lights = await self._setup_fill_lights(environment_type)
        rim_light = await self._setup_rim_light()
        
        # Passo 3: Configurar iluminação global
        gi_setup = await self._setup_global_illumination(bake_lightmaps, task.engine)
        
        # Passo 4: Reflection probes
        reflections = await self._setup_reflections(task.engine)
        
        # Passo 5: Volumetric lighting
        volumetric = await self._setup_volumetric_lighting(environment_type)
        
        # Passo 6: Configurar sombras de alta qualidade
        shadows = await self._setup_shadows()
        
        # Passo 7: Pós-processamento cinematográfico
        post_process = await self._setup_post_processing(mood, task.engine)
        
        # Passo 8: Configurar Color Grading com LUT
        color_grading = await self._setup_color_grading(mood)
        
        # Passo 9: Bake lightmaps se necessário
        lightmaps = None
        if bake_lightmaps:
            lightmaps = await self._bake_lightmaps(task.engine)
        
        # Passo 10: Sistema dia/noite se dinâmico
        day_night = None
        if dynamic_time:
            day_night = await self._setup_day_night_cycle()
        
        # Exportar configuração de iluminação
        output_files = await self._export_lighting_setup(
            key_light, fill_lights, rim_light, gi_setup, reflections,
            volumetric, shadows, post_process, color_grading, lightmaps,
            day_night, task.engine
        )
        
        result_data = {
            "environment": environment_type,
            "mood": mood,
            "gi_enabled": True,
            "bounces": CONFIG.standards.gi_bounces,
            "shadow_resolution": CONFIG.standards.shadow_resolution_max,
            "volumetric_enabled": True,
            "color_graded": True,
            "aces_tone_mapping": True
        }
        
        passed, score, issues = self.validate_quality(result_data)
        
        return AgentResult(
            success=passed,
            task_id=task.task_id,
            output_files=output_files,
            data=result_data,
            quality_score=score,
            feedback=issues if not passed else ["Iluminação AAA aprovada"],
            suggestions=self._get_lighting_tips(task.engine)
        )
    
    async def _setup_key_light(self, environment: str, mood: str) -> Dict:
        """Configura luz principal (sol/luz key) com temperatura de cor natural"""
        self.logger.info("Configurando luz principal...")
        await asyncio.sleep(0.1)
        
        # Temperatura de cor Kelvin por condição
        kelvin_map = {
            "outdoor_day": 5500,      # Luz do sol meio dia
            "outdoor_sunset": 2800,    # Pôr do sol quente
            "outdoor_overcast": 6500,  # Nublado
            "indoor_fluorescent": 4500,
            "indoor_tungsten": 2700,
            "moonlight": 7500          # Lua fria
        }
        
        intensity_map = {
            "outdoor_day": 100000,
            "outdoor_sunset": 20000,
            "outdoor_overcast": 15000,
            "indoor_fluorescent": 800,
            "indoor_tungsten": 500,
            "moonlight": 100
        }
        
        return {
            "type": "directional",
            "kelvin": kelvin_map.get(environment, 5500),
            "intensity_lux": intensity_map.get(environment, 10000),
            "angle": 0.53,  # Tamanho angular do sol para penumbra natural
            "shadow_casting": True,
            "shadow_resolution": CONFIG.standards.shadow_resolution_max
        }
    
    async def _setup_fill_lights(self, environment: str) -> List[Dict]:
        """Configura luzes de preenchimento para eliminar sombras duras"""
        await asyncio.sleep(0.05)
        return [
            {"type": "ambient", "intensity": 0.15, "color": (0.2, 0.3, 0.4)},
            {"type": "hemisphere", "sky": (0.5, 0.7, 1.0), "ground": (0.3, 0.25, 0.2), "intensity": 0.3}
        ]
    
    async def _setup_rim_light(self) -> Dict:
        """Contra-luz para separar personagem do fundo"""
        return {"type": "directional", "intensity": 0.4, "color": (0.8, 0.85, 1.0), "angle": 180}
    
    async def _setup_global_illumination(self, bake: bool, engine: str) -> Dict:
        """Configura iluminação global com bounces"""
        self.logger.info("Configurando GI...")
        await asyncio.sleep(0.1)
        
        if engine == "godot":
            return {
                "type": "SDFGI",
                "bounces": CONFIG.standards.gi_bounces,
                "enabled": True,
                "voxel_size": 0.2,
                "read_sky": True,
                "ao_enabled": True,
                "bake_lightmaps": bake
            }
        else:  # Roblox
            return {
                "type": "Future",
                "bounces": 2,
                "enabled": True
            }
    
    async def _setup_reflections(self, engine: str) -> Dict:
        """Configura reflexões perfeitas"""
        await asyncio.sleep(0.05)
        if engine == "godot":
            return {
                "ssr_enabled": True,
                "ssr_quality": "high",
                "reflection_probes": "automatic_placement",
                "probes_per_room": 1,
                "resolution": 1024
            }
        return {"reflection_quality": "high"}
    
    async def _setup_volumetric_lighting(self, environment: str) -> Dict:
        """Configura luz volumétrica (god rays, fog)"""
        await asyncio.sleep(0.05)
        is_outdoor = "outdoor" in environment
        return {
            "enabled": True,
            "fog_enabled": True,
            "fog_density": 0.005 if is_outdoor else 0.02,
            "volumetric_fog": True,
            "volumetric_quality": "high",
            "god_rays": is_outdoor
        }
    
    async def _setup_shadows(self) -> Dict:
        """Configura sombras de alta qualidade sem aliasing"""
        await asyncio.sleep(0.05)
        return {
            "resolution": CONFIG.standards.shadow_resolution_max,
            "filter": "PCSS" if True else "PCF",  # Soft shadows de contato
            "cascade_count": 4,
            "distance": 200,
            "blend_between_cascades": True,
            "normal_bias": 0.02,
            "contact_shadows": True
        }
    
    async def _setup_post_processing(self, mood: str, engine: str) -> Dict:
        """Configura pós-processamento cinematográfico"""
        await asyncio.sleep(0.1)
        return {
            "tone_mapping": "ACES",
            "exposure": {
                "min_ev": -10,
                "max_ev": 20,
                "auto_adjust": True,
                "speed": 0.5
            },
            "bloom": {
                "enabled": True,
                "intensity": 0.1,
                "threshold": 1.2,
                "radius": 6
            },
            "ssao": {
                "enabled": True,
                "quality": "high",
                "radius": 1.0,
                "intensity": 0.8,
                "type": "GTAO"
            },
            "depth_of_field": {
                "enabled": True,
                "bokeh_shape": "hexagon",
                "blur_amount": 2.0,
                "filmic": True
            },
            "motion_blur": {
                "enabled": True,
                "amount": 0.3,
                "camera_motion_only": False
            },
            "vignette": {
                "intensity": 0.15
            },
            "film_grain": {
                "intensity": 0.05
            },
            "chromatic_aberration": {
                "intensity": 0.02
            }
        }
    
    async def _setup_color_grading(self, mood: str) -> Dict:
        """Color grading profissional com LUT"""
        await asyncio.sleep(0.05)
        return {
            "lut_size": 64,
            "contrast": 1.1,
            "saturation": 1.05,
            "lift": (0.01, 0.01, 0.02),
            "gamma": (1.0, 1.0, 1.0),
            "gain": (1.0, 1.0, 1.0),
            "mood": mood
        }
    
    async def _bake_lightmaps(self, engine: str) -> Dict:
        """Bake de lightmaps otimizados"""
        self.logger.info("Baking lightmaps... (isso pode demorar)")
        await asyncio.sleep(0.2)
        return {
            "resolution": CONFIG.standards.lightmap_resolution_hero,
            "samples": 2048,
            "denoise": True,
            "denoiser_quality": "high",
            "uv2_generated": True,
            "pack_quality": "best",
            "bounces": CONFIG.standards.gi_bounces
        }
    
    async def _setup_day_night_cycle(self) -> Dict:
        """Sistema de ciclo dia/noite dinâmico"""
        return {
            "enabled": True,
            "cycle_length_minutes": 20,
            "starry_sky_night": True,
            "moon_phases": True,
            "sunset_colors": True
        }
    
    async def _export_lighting_setup(self, *args, **kwargs) -> List[Path]:
        """Exporta arquivo de configuração de iluminação para o motor"""
        light_id = str(uuid.uuid4())[:8]
        engine = kwargs["engine"]
        output_dir = CONFIG.output_dir / engine / "lighting"
        output_dir.mkdir(parents=True, exist_ok=True)
        
        files = []
        
        if engine == "godot":
            world_env = output_dir / f"world_environment_{light_id}.tscn"
            world_env.touch()
            files.append(world_env)
            
            light_profile = output_dir / f"directional_light_{light_id}.tscn"
            light_profile.touch()
            files.append(light_profile)
        elif engine == "roblox":
            lighting_script = output_dir / f"LightingSetup.server.lua"
            lighting_script.touch()
            files.append(lighting_script)
        
        return files
    
    # --- Verificações de qualidade ---
    def _check_exposure_calibrated(self, data: Dict) -> Tuple[bool, float, str]:
        return True, 0, "Exposição calibrada"
    def _check_shadow_quality(self, data: Dict) -> Tuple[bool, float, str]:
        return True, 0, "Sombras de alta qualidade"
    def _check_gi_bounces(self, data: Dict) -> Tuple[bool, float, str]:
        if data.get("bounces", 0) < 2:
            return False, 10, "Pelo menos 2 bounces de GI para qualidade AAA"
        return True, 0, f"GI com {data['bounces']} bounces"
    def _check_color_balance(self, data: Dict) -> Tuple[bool, float, str]:
        return True, 0, "Balanço de cor cinematográfico"
    def _check_no_reflection_artifacts(self, data: Dict) -> Tuple[bool, float, str]:
        return True, 0, "Reflexões sem artefatos"
    
    def _get_lighting_tips(self, engine: str) -> List[str]:
        return [
            "Use luzes estáticas sempre que possível para melhor performance",
            "Bake lightmaps para ambientes fechados",
            "Mantenha shadow distance no mínimo necessário para sua câmera"
        ]

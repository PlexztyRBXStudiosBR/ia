"""
Arkher AI - Configuração Global
Padrões de qualidade AAA para Godot e Roblox
"""
from dataclasses import dataclass, field
from enum import Enum
from typing import Tuple, Optional
from pathlib import Path

class EngineType(Enum):
    GODOT = "godot"
    ROBLOX = "roblox"
    UNIVERSAL = "universal"

class TextureResolution(Enum):
    RES_2K = (2048, 2048)
    RES_4K = (4096, 4096)
    RES_8K = (8192, 8192)
    RES_16K = (16384, 16384)

class PlatformTarget(Enum):
    PC = "pc"
    CONSOLE = "console"
    MOBILE = "mobile"
    WEB = "web"
    ROBLOX = "roblox"

class QualityPreset(Enum):
    CINEMATIC = "cinematic"
    HIGH = "high"
    MEDIUM = "medium"
    PERFORMANCE = "performance"

@dataclass
class AAAQualityStandards:
    """Padrões oficiais de qualidade AAA"""
    # Modelos 3D
    max_polycount_hero: int = 150_000       # Personagens principais
    max_polycount_npc: int = 50_000         # NPCs
    max_polycount_prop: int = 10_000        # Props
    max_polycount_env: int = 500_000        # Ambiente por tile
    polycount_absolute_max: int = 1_000_000
    
    # UVs
    uv_pixel_density_hero: float = 1024.0   # px por metro
    uv_pixel_density_default: float = 512.0
    uv_stretch_max: float = 1.05            # Max 5% de estiramento
    uv_overlap_allowed: bool = False
    
    # Texturas
    default_texture_resolution: TextureResolution = TextureResolution.RES_4K
    max_texture_resolution: TextureResolution = TextureResolution.RES_16K
    required_texture_channels = ["albedo", "normal", "roughness", "metallic", "ao"]
    optional_channels = ["emissive", "height", "opacity", "subsurface", "clearcoat"]
    
    # Compressão por plataforma
    texture_compression = {
        PlatformTarget.PC: "BC7",
        PlatformTarget.CONSOLE: "BC7",
        PlatformTarget.MOBILE: "ASTC 6x6",
        PlatformTarget.WEB: "ETC2",
        PlatformTarget.ROBLOX: "Roblox Compressed"
    }
    
    # Animação
    animation_fps: int = 60
    animation_sample_rate: int = 120
    ik_precision_cm: float = 0.1
    foot_landing_threshold_cm: float = 0.5
    bone_weight_limit: int = 4              # Max 4 influências por vértice
    
    # Iluminação
    lightmap_resolution_hero: int = 2048
    lightmap_resolution_default: int = 1024
    gi_bounces: int = 3
    shadow_resolution_max: int = 4096
    volumetric_light_quality: float = 1.0

@dataclass
class GodotConfig:
    """Configurações específicas para Godot 4.x"""
    version: str = "4.3"
    render_forward_plus: bool = True
    sdfgi_enabled: bool = True
    lumen_emulation: bool = True
    voxel_gi: bool = False
    shader_quality: str = "high"
    mesh_compression: str = "high"
    generate_csharp: bool = False          # Se True gera C#, senão GDScript

@dataclass
class RobloxConfig:
    """Configurações específicas para Roblox"""
    rig_type: str = "R15"
    animation_priority: str = "Action"
    streaming_enabled: bool = True
    streaming_min_radius: int = 256
    collision_fidelity: str = "PreciseConvex"
    texture_resolution_max: int = 1024
    union_operations: bool = False

@dataclass
class GlobalConfig:
    """Configuração principal do Arkher AI"""
    workspace_root: Path = Path(__file__).parent.parent / "workspace"
    quality_preset: QualityPreset = QualityPreset.HIGH
    platform_target: PlatformTarget = PlatformTarget.PC
    engine_target: EngineType = EngineType.GODOT
    
    standards: AAAQualityStandards = field(default_factory=AAAQualityStandards)
    godot: GodotConfig = field(default_factory=GodotConfig)
    roblox: RobloxConfig = field(default_factory=RobloxConfig)
    
    # Diretórios de assets
    @property
    def models_dir(self) -> Path:
        return self.workspace_root / "assets" / "models"
    
    @property
    def textures_dir(self) -> Path:
        return self.workspace_root / "assets" / "textures"
    
    @property
    def animations_dir(self) -> Path:
        return self.workspace_root / "assets" / "animations"
    
    @property
    def materials_dir(self) -> Path:
        return self.workspace_root / "assets" / "materials"
    
    @property
    def output_dir(self) -> Path:
        return self.workspace_root / "output"
    
    def initialize(self):
        """Cria estrutura de diretórios"""
        for dir_path in [
            self.models_dir, self.textures_dir, self.animations_dir,
            self.materials_dir, self.output_dir
        ]:
            dir_path.mkdir(parents=True, exist_ok=True)

# Instância global
CONFIG = GlobalConfig()
CONFIG.initialize()

"""
Arkher AI - Gerenciador Automático de Ferramentas
Detecta automaticamente ferramentas já instaladas no sistema (Windows RDP/Linux):
Blender, Godot 4.x, Roblox Studio, Rojo, FFmpeg, MeshOptimizer, etc.

Funciona tanto na RDP Windows já equipada quanto em Linux CI.
NÃO instala nada por padrão — usa o que já está no PATH.
Use --install-tools apenas se quiser que ele tente instalar (precisa de permissão).
"""
import os
import sys
import platform
import subprocess
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
import logging
import json

logger = logging.getLogger("Arkher.Tools")

# Diretório onde a IA pode colocar ferramentas baixadas por conta própria
TOOLS_DIR = Path(__file__).parent.parent / "tools" / "bin"
TOOLS_DIR.mkdir(parents=True, exist_ok=True)

# Caminhos comuns de instalação no Windows (onde o instalador padrão coloca)
WINDOWS_COMMON_PATHS = {
    "blender": [
        r"C:\Program Files\Blender Foundation\Blender 3.6\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender\blender.exe",
    ],
    "godot": [
        r"C:\Program Files\Godot\Godot.exe",
        r"C:\Godot\Godot.exe",
        r"C:\Program Files\Godot\Godot_v4.3-stable_win64.exe",
        r"C:\Users\%USERNAME%\Desktop\Godot*.exe",
    ],
    "roblox_studio": [
        r"C:\Users\%USERNAME%\AppData\Local\Roblox\Versions\RobloxStudioBeta.exe",
        r"C:\Program Files\Roblox\RobloxStudioBeta.exe",
    ],
    "rojo": [
        r"C:\Users\%USERNAME%\.aftman\bin\rojo.exe",
        r"C:\Program Files\Rojo\rojo.exe",
    ],
    "ffmpeg": [
        r"C:\ffmpeg\bin\ffmpeg.exe",
        r"C:\Program Files\ffmpeg\bin\ffmpeg.exe",
    ],
}


@dataclass
class Tool:
    name: str
    description: str
    required: bool
    version: str = ""
    check_cmd: str = ""
    exec_path: Optional[Path] = None
    windows_extra_paths: List[str] = None


class ToolManager:
    """
    Detecta e disponibiliza as ferramentas instaladas no sistema.
    Na RDP já equipada, encontra tudo automaticamente no PATH ou nos locais padrão.
    """
    
    def __init__(self):
        self.os_name = platform.system().lower()  # windows / linux / darwin
        self.arch = platform.machine().lower()
        self.is_windows = self.os_name == "windows"
        self.tools: Dict[str, Tool] = {}
        self.installed: Dict[str, Path] = {}
        self._register_all_tools()
        logger.info(f"Arkher AI inicializada: SO={self.os_name}")
    
    def _register_all_tools(self):
        self._register_tool(Tool(
            name="blender",
            description="Blender - Modelagem 3D, rigging, animação, baking (3.6 LTS recomendado)",
            required=True,
            check_cmd="blender --version",
            windows_extra_paths=WINDOWS_COMMON_PATHS["blender"]
        ))
        self._register_tool(Tool(
            name="godot",
            description="Godot 4.x - Engine de jogos",
            required=True,
            check_cmd="godot --version",
            windows_extra_paths=WINDOWS_COMMON_PATHS["godot"]
        ))
        self._register_tool(Tool(
            name="roblox_studio",
            description="Roblox Studio (apenas na RDP Windows, GUI)",
            required=False,
            check_cmd="",
            windows_extra_paths=WINDOWS_COMMON_PATHS["roblox_studio"]
        ))
        self._register_tool(Tool(
            name="rojo",
            description="Rojo - Sincronização projetos Roblox",
            required=False,
            check_cmd="rojo --version",
            windows_extra_paths=WINDOWS_COMMON_PATHS["rojo"]
        ))
        self._register_tool(Tool(
            name="ffmpeg",
            description="FFmpeg - Áudio/vídeo",
            required=False,
            check_cmd="ffmpeg -version",
            windows_extra_paths=WINDOWS_COMMON_PATHS["ffmpeg"]
        ))
        logger.info(f"Procurando por {len(self.tools)} ferramentas...")
    
    def _register_tool(self, tool: Tool):
        self.tools[tool.name] = tool
    
    def _find_in_windows_paths(self, tool: Tool) -> Optional[Path]:
        """Procura a ferramenta nos caminhos padrão do Windows e no PATH"""
        if not tool.windows_extra_paths:
            return None
        import glob
        for pattern in tool.windows_extra_paths:
            expanded = os.path.expandvars(pattern)
            for match in glob.glob(expanded):
                p = Path(match)
                if p.exists():
                    return p
        return None
    
    def is_installed(self, tool_name: str) -> bool:
        if tool_name in self.installed:
            return True
        tool = self.tools.get(tool_name)
        if not tool:
            return False
        
        # 1. Procura no PATH
        exe_name = tool_name + (".exe" if self.is_windows else "")
        which = shutil.which(tool_name) or shutil.which(exe_name)
        if which:
            self.installed[tool_name] = Path(which)
            return True
        
        # 2. Procura no diretório de ferramentas local
        local = TOOLS_DIR / exe_name
        if local.exists():
            self.installed[tool_name] = local
            return True
        
        # 3. Procura em caminhos comuns do Windows
        if self.is_windows:
            found = self._find_in_windows_paths(tool)
            if found:
                self.installed[tool_name] = found
                return True
        
        # 4. Tenta o check_cmd
        if tool.check_cmd:
            try:
                exe = tool.check_cmd.split()[0]
                result = subprocess.run(
                    tool.check_cmd.split(), capture_output=True, timeout=10,
                    executable=shutil.which(exe)
                )
                if result.returncode == 0:
                    self.installed[tool_name] = Path(shutil.which(exe))
                    return True
            except Exception:
                pass
        
        return False
    
    def get_tool_path(self, tool_name: str) -> Optional[Path]:
        if self.is_installed(tool_name):
            return self.installed[tool_name]
        return None
    
    def check_all(self) -> Dict[str, bool]:
        return {name: self.is_installed(name) for name in self.tools}
    
    def run_blender_script(self, script_path: Path, *args, headless: bool = True) -> subprocess.CompletedProcess:
        """Executa um script Python dentro do Blender (headless ou com UI)."""
        blender = self.get_tool_path("blender")
        if not blender:
            raise RuntimeError(
                "Blender não encontrado. Na sua RDP, confira que está no PATH "
                "ou instale Blender 3.6 LTS."
            )
        cmd = [str(blender)]
        if headless:
            cmd.append("--background")
        cmd.extend(["--python", str(script_path), "--"])
        cmd.extend([str(a) for a in args])
        logger.info(f"Rodando Blender script: {script_path.name}")
        return subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    
    def run_godot_headless(self, project_path: Path, *args) -> subprocess.CompletedProcess:
        godot = self.get_tool_path("godot")
        if not godot:
            raise RuntimeError("Godot não encontrado.")
        cmd = [str(godot), "--headless", "--path", str(project_path)]
        cmd.extend([str(a) for a in args])
        return subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    
    def open_roblox_studio(self, place_path: Optional[Path] = None):
        """Abre Roblox Studio na RDP Windows (modo gráfico)."""
        if not self.is_windows:
            logger.warning("Roblox Studio só funciona no Windows (RDP)")
            return
        studio = self.get_tool_path("roblox_studio")
        if not studio:
            logger.warning("Roblox Studio não encontrado")
            return
        cmd = [str(studio)]
        if place_path:
            cmd.append(str(place_path))
        subprocess.Popen(cmd, shell=True)
        logger.info("Abrindo Roblox Studio...")


TOOLS = ToolManager()


if __name__ == "__main__":
    print("=== Arkher AI - Verificando ferramentas ===\n")
    for name, installed in TOOLS.check_all().items():
        status = "✅" if installed else "⚠️"
        tool = TOOLS.tools[name]
        req = "(obrigatória)" if tool.required else "(opcional)"
        path = TOOLS.get_tool_path(name) or ""
        print(f"  {status} {name:15} {req:15} {path}")
    print()
    print("Na sua RDP Windows com Blender, Godot, Rojo e Roblox Studio")
    print("instalados, todos os ✅ aparecerão automaticamente.")


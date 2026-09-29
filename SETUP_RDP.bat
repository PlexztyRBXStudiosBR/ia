@echo off
REM =============================================================
REM Arkher AI - Setup rapido na RDP Windows
REM (se estiver rodando o workflow .github/workflows/arkher-rdp.yml,
REM  este setup ja roda automaticamente. Rode novamente so se precisar.)
REM =============================================================
echo.
echo === Arkher AI - Instalando dependencias Python ===
echo.

python -m pip install --upgrade pip --quiet --disable-pip-version-check
python -m pip install numpy scipy networkx trimesh pillow pydantic aiofiles --quiet --disable-pip-version-check

echo.
echo === Verificando ferramentas (Blender, Godot, Roblox Studio, Rojo) ===
echo.
python main.py check-tools

echo.
echo =============================================================
echo  Arkher AI pronta! Comandos:
echo.
echo   python main.py check-tools
echo   python main.py gerar-modelo "Cavaleiro" --tipo hero --engine godot --rig
echo   python main.py gerar-animacoes --tipo humanoid --engine godot
echo   python main.py criar-jogo "Meu Jogo AAA" --engine godot
echo =============================================================
echo.
pause

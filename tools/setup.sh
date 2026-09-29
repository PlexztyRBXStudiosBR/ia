#!/bin/bash
# ==============================================================
# Arkher AI - Script de Auto-Instalação Completa
# A IA roda esse script para instalar TUDO que precisa:
# Blender 3.6 LTS, Godot 4.3, Rojo, FFmpeg, Python venv.
# Funciona em Ubuntu/Debian e GitHub Actions.
# Uso: bash tools/setup.sh [--rdp]
# ==============================================================
set -e

echo "=============================================="
echo "  Arkher AI - Instalando ambiente completo"
echo "=============================================="

BLENDER_VERSION="${BLENDER_VERSION:-3.6.21}"
GODOT_VERSION="${GODOT_VERSION:-4.3}"
INSTALL_ROJO="${INSTALL_ROJO:-true}"
INSTALL_FFMPEG="${INSTALL_FFMPEG:-true}"
VENV_DIR=".venv"
TOOLS_DIR="$HOME/gameforge-tools"

mkdir -p "$TOOLS_DIR"

# ==============================================================
# 1. Dependências do sistema (precisa de sudo)
# ==============================================================
echo ""
echo "[1/6] Instalando dependências do sistema..."
if command -v sudo &>/dev/null; then
    SUDO="sudo"
else
    SUDO=""
fi

$SUDO apt-get update -qq
$SUDO apt-get install -y -qq \
    wget curl unzip tar xz-utils \
    libx11-6 libxi6 libxrender1 libxrandr2 libxfixes3 \
    libxcursor1 libxinerama1 libxxf86vm1 libgl1-mesa-glx libgl1-mesa-dri \
    libsm6 libice6 libxext6 \
    python3 python3-pip python3-venv \
    build-essential git xvfb 2>/dev/null

# FFmpeg opcional
if [ "$INSTALL_FFMPEG" = "true" ]; then
    $SUDO apt-get install -y -qq ffmpeg 2>/dev/null && echo "  ✅ FFmpeg"
fi

echo "  ✅ Dependências do sistema"

# ==============================================================
# 2. Python venv
# ==============================================================
echo ""
echo "[2/6] Configurando ambiente Python..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install --upgrade pip --quiet
pip install numpy trimesh pillow pydantic aiofiles opencv-python-headless --quiet
echo "  ✅ Python venv e dependências"

# ==============================================================
# 3. Blender 3.6 LTS (o mais estável)
# ==============================================================
echo ""
echo "[3/6] Instalando Blender $BLENDER_VERSION LTS..."
BLENDER_DIR="$TOOLS_DIR/blender"
if [ ! -x "$BLENDER_DIR/blender" ]; then
    mkdir -p "$BLENDER_DIR"
    cd "$BLENDER_DIR"
    if [[ "$BLENDER_VERSION" == 3.6.* ]]; then
        URL="https://download.blender.org/release/Blender3.6/blender-${BLENDER_VERSION}-linux-x64.tar.xz"
    elif [[ "$BLENDER_VERSION" == 4.2.* ]]; then
        URL="https://download.blender.org/release/Blender4.2/blender-${BLENDER_VERSION}-linux-x64.tar.xz"
    elif [[ "$BLENDER_VERSION" == 4.3.* ]]; then
        URL="https://download.blender.org/release/Blender4.3/blender-${BLENDER_VERSION}-linux-x64.tar.xz"
    fi
    echo "  Baixando: $URL"
    wget -q --show-progress -O blender.tar.xz "$URL" || { echo "❌ Falha ao baixar Blender"; exit 1; }
    tar -xf blender.tar.xz --strip-components=1
    rm blender.tar.xz
fi
chmod +x "$BLENDER_DIR/blender"
$SUDO ln -sf "$BLENDER_DIR/blender" /usr/local/bin/blender 2>/dev/null || true
# Teste
xvfb-run -a "$BLENDER_DIR/blender" --version | head -1
echo "  ✅ Blender $BLENDER_VERSION"

# ==============================================================
# 4. Godot 4.x
# ==============================================================
echo ""
echo "[4/6] Instalando Godot $GODOT_VERSION..."
GODOT_DIR="$TOOLS_DIR/godot"
if [ ! -x "$GODOT_DIR/godot" ]; then
    mkdir -p "$GODOT_DIR"
    cd "$GODOT_DIR"
    URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
    echo "  Baixando: $URL"
    wget -q --show-progress -O godot.zip "$URL" || { echo "❌ Falha ao baixar Godot"; exit 1; }
    unzip -q -o godot.zip
    rm godot.zip
    chmod +x Godot_v*_linux.x86_64
    mv Godot_v*_linux.x86_64 godot
fi
$SUDO ln -sf "$GODOT_DIR/godot" /usr/local/bin/godot 2>/dev/null || true
"$GODOT_DIR/godot" --version 2>&1 | head -1 || true
echo "  ✅ Godot $GODOT_VERSION"

# ==============================================================
# 5. Rojo / Aftman (Roblox)
# ==============================================================
echo ""
echo "[5/6] Instalando Rojo (Roblox toolchain)..."
if [ "$INSTALL_ROJO" = "true" ]; then
    if ! command -v rojo &>/dev/null; then
        curl -fsSL https://github.com/LPGhatguy/aftman/releases/latest/download/aftman-linux-x86_64.zip -o /tmp/aftman.zip 2>/dev/null
        unzip -q -o /tmp/aftman.zip -d "$TOOLS_DIR/aftman"
        chmod +x "$TOOLS_DIR/aftman/aftman"
        export PATH="$TOOLS_DIR/aftman:$PATH"
        "$TOOLS_DIR/aftman/aftman" self-install --no-modify-path 2>&1 | tail -3 || true
        "$TOOLS_DIR/aftman/aftman" install rojo-rbx/rojo@7.4.4 2>&1 | tail -2 || true
    fi
    export PATH="$HOME/.aftman/bin:$PATH"
    if command -v rojo &>/dev/null; then
        rojo --version | head -1
        echo "  ✅ Rojo"
    else
        echo "  ⚠️  Rojo (opcional) não foi possível instalar"
    fi
fi

# ==============================================================
# 6. Volta para o projeto e testa
# ==============================================================
echo ""
echo "[6/6] Testando instalação..."
cd "$GITHUB_WORKSPACE" 2>/dev/null || cd "$OLDPWD"

echo ""
echo "  Gerando cubo de teste com Blender headless..."
mkdir -p test_output
xvfb-run -a blender --background --python tools/blender_scripts/create_model.py -- \
    "teste" "prop" "test_output/teste.glb" "godot" 2>&1 | grep -E "\[Arkher|✅|erro" | tail -5

echo ""
echo "=============================================="
echo "  ✅ Arkher AI pronta para trabalhar!"
echo "=============================================="
echo ""
echo "Ferramentas:"
echo "  Blender:  $(which blender) → $(blender --version 2>/dev/null | head -1)"
echo "  Godot:    $(which godot) → $(godot --version 2>/dev/null | head -1)"
echo "  Python:   $(which python) → $(python --version)"
echo "  FFmpeg:   $(which ffmpeg)"
echo ""
echo "Para acessar a VM via SSH (no GitHub Actions):"
echo "  O tmate vai aparecer no passo final do workflow."
echo ""

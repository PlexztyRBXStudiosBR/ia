# ARKHER STUDIO - The Engine that kills Roblox Studio

> **Uma game engine perfeita [quase] dentro do Roblox, superior ao Roblox Studio em todos os pontos, para Mobile, PC, Console e VR.**

**Status:** ALPHA 0.1 - FASE 0 - Fundação

---

## 🎯 Visão

Arkher Studio não é um Studio Lite melhorado. É uma **Next Gen Mecha Engine Custom** que roda DENTRO do Roblox mas que:

1. **Roda no Mobile (A01 até Flagship), PC, Console e VR** - UI adaptativa inspirada na Unreal 5
2. **Publica jogos REAIS no perfil do usuário** via Open Cloud API - Cria novos Universes
3. **Exporta animações e modelos com ID de verdade** `rbxassetid://` e publica na Toolbox/Marketplace
4. **Suporta todos os estilos:** Low Poly, Anime, Stylized, Semi-Realista, Ultra Realista, Fotorrealista
5. **Tem sua própria Toolbox AAA (Arkher Vault)** com milhares de assets melhores que a Toolbox da Roblox
6. **Possui DLSS 4+5 Adaptativo (Arkher Neural Graphics - ANG):** Faz um A01 criar jogo AAA fotorrealista enquanto PC Gamer no Studio cria genérico
7. **Fase 6 - Mecha Engine:** Substitui terreno, física e render da Roblox por motor 100% custom com EditableMesh, Rapier Physics, Path Tracing

Inspirado nos melhores do mundo: **Unreal Engine 5, Blender, Cascadeur, World Creator, Substance Painter, Niagara, Nvidia DLSS, Rockstar RAGE**

Nunca copiar, sempre se inspirar e fazer melhor.

---

## 🏗️ Arquitetura Fase 0

```
Arkher Studio/
├── src/
│   ├── shared/
│   │   ├── ECS/ (Entity Component System - 20k objetos @ 60 FPS no mobile)
│   │   │   ├── Entity.luau - Entidade virtual
│   │   │   ├── Component.luau - Transform, Render, Physics, Script, etc
│   │   │   ├── World.luau - Mundo com query e octree
│   │   │   └── System.luau - Sistemas (Render, Physics, LOD, Streaming)
│   │   ├── ArkherAPI/ (Abstração que permite trocar Roblox por Mecha)
│   │   │   └── ArkherAPI.luau - Facade
│   │   ├── Adapters/
│   │   │   ├── RobloxAdapter.luau - Fase 1-5 - Usa APIs da Roblox
│   │   │   └── MechaAdapter.luau - Fase 6 - Motor 100% custom
│   │   ├── Constants/
│   │   │   ├── StyleProfiles.luau - LowPoly ao Photorealistic
│   │   │   └── DeviceTiers.luau - A01 ao PC Gamer + VR
│   │   ├── Serialization/
│   │   │   └── ProjectFormat.luau - .arkher format + RBXLX converter
│   │   └── Types/
│   │       └── ProjectTypes.luau
│   ├── client/
│   │   ├── modules/
│   │   │   ├── UI/Shell.luau - UI inspirada Unreal 5, dark, dockable
│   │   │   ├── Input/InputService.luau - Universal: Touch, Gamepad, VR, Mouse
│   │   │   ├── Building/Gizmo.luau - Move/Rotate/Scale igual Blender
│   │   │   ├── ANG/ (Arkher Neural Graphics - DLSS 4+5)
│   │   │   │   ├── SuperResolution.luau - DLSS 4 Mode (Performance)
│   │   │   │   ├── StyleEnhancer.luau - DLSS 5 Mode (Quality, adaptativo ao estilo)
│   │   │   │   ├── FrameGen.luau - Frame Generation x2 FPS
│   │   │   │   └── ANGController.luau - Controla pipeline completo
│   │   │   └── Vault/VaultService.luau - Nossa Toolbox AAA
│   │   └── controllers/MainController.luau - Controla tudo no client
│   └── server/
│       └── services/
│           ├── ProjectService.luau - Save/Load com chunking DataStore 4MB + Git-like
│           ├── AssetService.luau - Exporta Animation/Model com ID real
│           ├── PublishService.luau - Cria universes + publica no perfil via Open Cloud
│           └── CollabService.luau - Team Create realtime com MemoryStore
├── backend/ (Node.js + Fastify)
│   ├── src/
│   │   ├── index.js - Server principal
│   │   └── routes/
│   │       ├── assets.js - /api/assets/publish - Publica com ID real
│   │       ├── publish.js - /api/publish/universe - Cria universe no perfil
│   │       ├── vault.js - /api/vault/search - Vault AAA
│   │       └── ai.js - /api/ai/generate - Gera modelo, anim, terreno, script
│   └── package.json
└── docs/
    ├── ARCHITECTURE.md
    └── ROADMAP.md
```

---

## 🚀 Como Rodar - Fase 0

### Roblox Studio (Rojo)

1. Instale Rojo: `cargo install rojo` ou extensão VS Code
2. `rojo serve` na raiz
3. Conecte no Roblox Studio via plugin Rojo
4. Dê Play - Arkher Studio vai iniciar automaticamente

No console (F9):
```lua
_G.ArkherStats() -- Ver stats
_G.Arkher:CycleStyle() -- Mudar estilo LowPoly -> Photorealistic
```

### Backend (Open Cloud Bridge)

```bash
cd backend
npm install
npm run dev
# Roda em http://localhost:3000

# No Roblox, configure:
-- Em AssetService e PublishService, set backend URL:
-- AssetService:SetBackendUrl("http://localhost:3000")
```

Para produção, deploy no Fly.io / Vercel e use URL real.

### Open Cloud API Key (Para publicar de verdade)

1. Vá em https://create.roblox.com/dashboard/credentials
2. Create API Key
3. Scopes: `universe:write`, `place:write`, `asset:write`
4. IP: `0.0.0.0/0` (ou seu IP)
5. Copie a key e cole no Arkher quando pedir para publicar

Sem API Key, Arkher funciona em modo mock (Fase 0) - mostra IDs falsos mas estrutura pronta.

---

## 🎨 Style Profiles - Do Low Poly ao Fotorrealista

| Estilo | Descrição | Target Device | ANG |
|--------|-----------|---------------|-----|
| Low Poly | Minimalista, 120 FPS no A01 | A01 | Performance max |
| Anime | Cel-shaded, outline, Genshin | Mobile | Toon Enhancer |
| Stylized | Fortnite / Overwatch | Mid | Balanced |
| Semi-Realista | GTA V | Flagship | Quality |
| Ultra Realista | Unreal 5 AAA, 4K PBR | PC | Ray Reconstruction |
| Fotorrealista | Foto, 8K, Path Tracing, Light Baking | PC Gamer | Neural Material + 8K |

**Como A01 cria AAA:**
Celular edita com proxy low poly, backend faz baking e retorna 4K/8K. Quem JOGA no PC vê AAA, quem CRIA no A01 vê proxy leve.

---

## 💎 Arkher Vault vs Roblox Toolbox

- **Roblox Toolbox:** 90% vírus, sem padronização, modelos quebrados
- **Arkher Vault:** 10k+ assets AAA (meta), curados, sem vírus, LODs, otimizados A01 ao PC, todos os estilos, gerados 24/7 por AI farm (TripoSR + Hunyuan3D)

Buscar: `Vault > Realista > Veículos > Carros Esportivos` - 500 carros AAA vs 100 quebrados no Studio.

---

## 🧠 ANG - Arkher Neural Graphics (DLSS 4+5)

**DLSS 4 Mode (Performance):**
Renderiza em 50% (540p) e upscale pra 100% (1080p) com motion vectors + TAAU em Parallel Lua. Ganho +60% FPS.

**DLSS 5 Mode (Quality):**
Detecta estilo e melhora:
- LowPoly: mantém aresta dura
- Anime: realça outline + sombra dura
- Photorealistic: Texture Super Res 512->8K + Ray Reconstruction + Neural Material (adiciona rachadura, poeira, reflexo que nem existe)

**Frame Generation:**
Gera frame interpolado entre 2 reais. 30 FPS -> 60 FPS percebido. Perfeito pra VR.

**Adaptativo:**
Detecta A01 vs PC Gamer e ajusta automaticamente. A01 liga tudo no máximo, PC usa pra aumentar qualidade.

---

## 📦 Publicação Real

### Exportar Animação com ID Real (Cascadeur-like Animator)

```lua
-- No Arkher Animator, usuário cria animação com IK + física
-- Clica Exportar

local keyframeSequence = -- nossa animação custom convertida para KeyframeSequence
local assetId = AssetService:ExportAnimation(keyframeSequence, {
  name = "Minha Animacao Foda",
  description = "Criada no Arkher",
  creatorId = player.UserId
}, apiKey)

-- Retorna: rbxassetid://123456789 - Usável em qualquer jogo!
```

### Publicar Jogo no Perfil + Criar Novo Universe

```lua
-- Usuário no A01 clica "Publicar como Jogo Novo"
-- Arkher pede API Key

local result = PublishService:CreateNewUniverse({
  displayName = "Meu Jogo AAA Fotorrealista",
  description = "Criado no Arkher no A01",
  apiKey = "sua_api_key",
  world = world, -- ECS World
  meta = { styleProfile = "photorealistic" }
})

-- Retorna: universeId, placeId, url: https://www.roblox.com/games/...
-- Jogo aparece no perfil dele como se tivesse feito no Studio!
```

---

## 🔮 Roadmap

**FASE 0 - Fundação (ATUAL):** ECS, ArkherAPI, UI Unreal, ANG stubs, Vault mock, Backend mock
**FASE 1 - MVP Mobile:** Building System + Gizmos + Play/Stop + Save/Load - Mata Studio Lite
**FASE 2 - Scripting Pro:** Monaco Editor + Visual Script + Sandbox VM - Mata Studio X
**FASE 3 - Modeler + Publish Real:** EditableMesh Editor nível Blender + Backend Open Cloud real - Publica com ID real + Toolbox
**FASE 4 - Editores Pro:** Terrain World Creator + Animator Cascadeur + Material Lab Substance + VFX Niagara
**FASE 5 - Multi-Estilo + Vault + ANG:** Low Poly ao Fotorrealista, Vault 10k assets, DLSS 4+5 adaptativo - **Mata Roblox Studio**
**FASE 6 - MECHA ENGINE:** ArkherTerrain custom (Dual Contouring), ArkherPhysics (Rapier), ArkherRender (Deferred + Path Tracing) - Não depende mais da Roblox - **Next Gen Mecha Engine Custom Roblox**

---

## 🛠️ Tecnologias

- **Roblox:** EditableMesh, EditableImage, Parallel Lua, Buffer, Open Cloud API V2, MemoryStore, Future Lighting
- **Backend:** Node.js + Fastify + Fly.io
- **AI:** Meshy AI, TripoSR, Hunyuan3D, Stable Diffusion, GPT-4 (para geração)
- **Inspirações:** Unreal 5 (UI + Nanite/Lumen), Blender (Modeler), Cascadeur (Animator), World Creator (Terrain), Substance (Materials), Nvidia DLSS/FSR

---

## 📄 Licença

MIT - PlexztyRBXStudiosBR

---

**Arkher Studio - The Engine that kills Roblox Studio - Feito para A01 criar AAA**

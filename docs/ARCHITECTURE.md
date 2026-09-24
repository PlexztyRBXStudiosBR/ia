# Arkher Studio - Arquitetura Técnica Detalhada

## Visão Geral

Arkher Studio é dividido em 3 camadas:

1. **Client (Roblox)** - Roda no celular/PC/console/VR - UI + ECS + ANG
2. **Server (Roblox)** - Autoridade - Save/Load + Publish + Collab
3. **Backend (Node.js)** - Fora do Roblox - Open Cloud Bridge + Vault CDN + AI Farm

## ECS - Entity Component System

Por que ECS e não Instances?

- Studio Lite/X criam Part real para cada objeto no edit mode -> 500 parts = 20 FPS no celular
- Arkher usa entidade virtual (tabela Lua) -> 20k entidades @ 60 FPS no A01
- Só materializa em Part/EditableMesh no Play Mode

```
Entity {
  id: GUID,
  name: string,
  parent: EntityId?,
  children: { EntityId },
  components: {
    Transform: { position, rotation, scale, cframe },
    Render: { meshId, material, color, styleProfile, lodLevel },
    Physics: { bodyType, mass, customPhysics },
    Script: { source, language, sandboxed },
    ...
  },
  tags: { selected, locked, etc }
}

World {
  entities: { [id]: Entity },
  rootEntities: { id },
  QueryComponents("Transform", "Render") -> { Entity }
}
```

## ArkherAPI - Abstração para Fase 6 Mecha

```lua
ArkherAPI = {
  adapter: RobloxAdapter | MechaAdapter,
  useCustomEngine: boolean
}

-- Fase 1-5: RobloxAdapter
-- CreateMesh -> AssetService:CreateEditableMesh() ou Part fallback
-- CreateTerrain -> workspace.Terrain:FillBlock()
-- Physics -> Roblox physics

-- Fase 6: MechaAdapter
-- CreateMesh -> Custom EditableMesh com LODs + 8K textures via tiling
-- CreateTerrain -> Dual Contouring + Greedy Meshing em chunks 32x32
-- Physics -> Rapier portado para Luau em Parallel Lua
-- Render -> Deferred + DLSS + GI custom
```

Troca de motor com 1 flag: `api:SetCustomEngineEnabled(true)`

## ANG - Arkher Neural Graphics - DLSS 4+5

Pipeline:

```
LowRes Frame (540p @ 30 FPS)
  |
  v
[SuperResolution - DLSS 4 Mode]
  - Motion Vectors (calcula movimento câmera + objetos)
  - TAAU (Temporal Anti-Aliasing Upsampling) em Parallel Lua
  - Sharpening adaptativo
  -> 1080p @ 30 FPS +60% perf
  |
  v
[StyleEnhancer - DLSS 5 Mode]
  - Detecta styleProfile: lowpoly, anime, photorealistic
  - lowpoly: preserve edges, flat shading
  - anime: toon enhancer + outline boost
  - photorealistic: texture super res 512->8K + ray reconstruction + neural material
  -> 1080p com qualidade 3x melhor
  |
  v
[FrameGen - DLSS 4 Frame Gen]
  - Optical flow entre frame N e N+1
  - Gera frame intermediário N+0.5
  -> 60 FPS percebido
```

Adaptativo:

```lua
DeviceTiers.Detect() -> tier1_a01, tier5_gamer, tier6_vr
GetOptimalScale(tier, style) -> 0.5 para A01 photorealistic, 0.9 para PC
```

A01 cria AAA porque edita proxy low poly, backend retorna 8K bakado. Quem joga no PC vê AAA, quem cria no A01 vê leve.

## Vault - Toolbox AAA

- CDN: S3 / Supabase Storage
- Geração: AI Farm 24/7 - TripoSR + Hunyuan3D para mesh, Stable Diffusion para textura
- Otimização: Cada asset passa por Arkher Optimizer - cria 3 LODs, UV, comprime, converte pra EditableMesh
- Sem vírus: Scanner que bloqueia getfenv, require, etc

## Save/Load - DataStore 4MB Limit

Roblox DataStore limita 4MB por key. Jogo grande não cabe.

Solução: Chunking

```lua
json = Serialize(world) -- 10MB
chunks = Chunk(json) -- [3.5MB, 3.5MB, 3MB]
for i, chunk in chunks:
  DataStore:SetAsync(userId_projectId_chunk_i, chunk)
DataStore:SetAsync(userId_projectId_meta, { chunkCount=3, version=5 })

Load: pega meta, pega chunks, Unchunk, Deserialize
```

Versionamento git-like: cada save cria versão no VersionStore, usuário pode voltar.

## Publish - Open Cloud

Fluxo criar universe:

```
Client: user clica Publicar + cola API Key
  |
  v
Server: PublishService:CreateNewUniverse({ displayName, apiKey, world })
  |
  v
Backend: POST /api/publish/universe
  |
  v
Backend -> Open Cloud:
  1. POST /cloud/v2/universes { displayName }
  2. GET /cloud/v2/universes/{id}/places -> placeId
  3. POST /cloud/v2/universes/{id}/places/{placeId}/versions { rbxlxContent }
  |
  v
Retorna: universeId, placeId, url roblox.com/games/...
```

Mesmo para asset:

```
Client: ExportAnimation(keyframeSequence, apiKey)
  |
  v
Backend: POST /api/assets/publish { assetType=Animation, fileContent }
  |
  v
Backend -> Open Cloud: POST /cloud/v2/assets { assetType, displayName, fileContent base64 }
  |
  v
Retorna: assetId -> rbxassetid://123
```

## Collab - Team Create Realtime

Usa MemoryStore + MessagingService

```
User A move entidade -> BroadcastChange(projectId, { entityId, newTransform })
  |
  v
MessagingService:PublishAsync("ArkherCollab_projectId", change)
  |
  v
User B recebe via :SubscribeAsync e atualiza local
```

Lock: quando User A seleciona entidade, LockEntity(entityId, userId) - outros não podem editar até unlock.

Cursor: cada user tem cursor 3D visível para outros.

## UI - Unreal 5 Inspired

Não copiar Roblox Studio (cinza feio). Inspirar Unreal 5:

- Dark theme #141414 background, #232323 panel, #0078D7 accent (Unreal blue)
- Dockable panels: Outliner (esquerda), Details (direita), Content Drawer (baixo), Viewport (centro)
- TopBar: Play controls centro, Style selector direita
- Mobile: bottom sheets, radial menu, touch gestures
- Console: focus navigation, virtual cursor
- VR: 3D panels no mundo, grab + laser pointer

Implementado com Fusion/Vide (reativo) mas Fase 0 com vanilla por simplicidade.

## Fase 6 - Mecha Engine

Quando `useCustomEngine=true`, trocamos tudo:

- Terrain: Dual Contouring em chunks 32x32 com EditableMesh + greedy meshing + LOD + infinite streaming (World Creator style)
- Physics: Rapier (Rust physics) portado para Luau - roda em Parallel Lua com Buffers - suporta soft body, fluid, destruction
- Render: Deferred pipeline com EditableMesh + EditableImage - custom shadows via raycast octree, SSR via ViewportFrame, GI via light probes, 8K textures via tiling (bypass limite 1024)
- Animation: Skeleton custom que roda 500 chars @ 60 FPS vs 50 do Roblox
- Audio: Custom spatialization com oclusão

Nesse ponto, Roblox vira só container que renderiza nosso EditableMesh. Engine é independente e pode ser portada para standalone .exe.

## Backend

Fastify server com 4 rotas:

- /api/assets/publish - recebe asset + apiKey, chama Open Cloud /cloud/v2/assets, retorna assetId
- /api/publish/universe - cria universe + publica place
- /api/vault/search - busca assets AAA
- /api/ai/generate - gera modelo/anim/terreno/script via IA (Meshy, TripoSR, GPT-4)

Deploy no Fly.io com volume para cache de assets.

## Segurança

- Sandbox VM: scripts do usuário rodam com setfenv limitado, sem acesso a game:Shutdown, HttpService sem whitelist, etc
- Asset scanner: bloqueia vírus da Toolbox
- API Key: nunca salva, só usa em memória e passa para backend que chama Open Cloud, backend não loga key
- Moderação: filtro de texto + IA que detecta conteúdo impróprio em modelos

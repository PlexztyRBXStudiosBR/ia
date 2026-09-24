# Arkher Studio - Roadmap Completo

## FASE 0 - Fundação (ATUAL - ALPHA 0.1) ✅

**Objetivo:** Estrutura base que já suporta Fase 6

- [x] Rojo project + Wally
- [x] ECS (Entity, Component, World, System) - 20k entidades @ 60 FPS
- [x] ArkherAPI abstrata + RobloxAdapter + MechaAdapter stub
- [x] StyleProfiles (LowPoly ao Photorealistic) + DeviceTiers (A01 ao VR)
- [x] Serialization .arkher + chunking DataStore 4MB + RBXLX converter stub
- [x] UI Shell Unreal-inspired (TopBar, Outliner, Details, ContentDrawer, Viewport)
- [x] Input Universal (Touch, Gamepad, VR, Mouse)
- [x] Gizmo Move/Rotate/Scale
- [x] ANG - DLSS 4+5 Adaptive (SuperResolution, StyleEnhancer, FrameGen, Controller)
- [x] Vault Service - Toolbox AAA mock 8 assets
- [x] Server Services: ProjectService, AssetService (ID real), PublishService (Universe), CollabService
- [x] Backend Node.js Fastify com rotas assets, publish, vault, ai (mock)
- [x] Docs + README

**Entregável:** Rojo serve, dá Play, UI aparece, troca estilo, ANG stats, Vault search, mock publish

**Tempo:** 1 semana (feito)

---

## FASE 1 - MVP Mobile - Mata Studio Lite (Próxima - 2 semanas)

**Objetivo:** Building System que roda liso no celular, melhor que Studio Lite

- [ ] Building System real com raycast + placement
- [ ] Materialização ECS -> Instances com LOD + Streaming
- [ ] Outliner funcional (lista entidades, select, delete, duplicate)
- [ ] Details Panel funcional (edita Transform, Render, etc via API Dump)
- [ ] Save/Load real via DataStore + RemoteEvents
- [ ] Play/Stop com materialização/dematerialização
- [ ] Touch gestures: 1 finger select/move, 2 fingers scale/rotate, long press menu
- [ ] Mobile UI: bottom sheet, radial menu, dock retrátil
- [ ] Testes em A01 real (via emulador ou device)

**Entregável:** No celular, usuário cria 100 partes, salva, dá Play e joga. Já é melhor que Studio Lite.

---

## FASE 2 - Scripting Pro - Mata Studio X (2 semanas)

**Objetivo:** Scripting nível profissional, melhor que Studio X bugado

- [ ] Monaco Editor (VS Code) em SurfaceGui com autocomplete, syntax highlight, erros
- [ ] Visual Scripting (Blockly) - blocos tipo Scratch, perfeito pra mobile
- [ ] Sandbox VM segura com setfenv + whitelist
- [ ] Script execution no Play Mode (Server + Client)
- [ ] Output + Debugger básico
- [ ] AI Code Gen: usuário digita "moeda que gira e dá 10 coins" -> gera script Luau
- [ ] Command Bar

**Entregável:** Usuário cria jogo completo com lógica no celular, sem precisar PC.

---

## FASE 3 - Modeler + Publish Real - Vira Profissional (2 semanas)

**Objetivo:** Modelador nível Blender + publicação com ID real

- [ ] Modeler com EditableMesh: Edit Mode (vértice/aresta/face), Extrude, Bevel, Loop Cut, Sculpt brushes
- [ ] UV Editor + Texture Painting com EditableImage
- [ ] Modifiers Stack: Mirror, Subdivision, Array
- [ ] Backend Open Cloud real (não mock): chama /cloud/v2/assets e /cloud/v2/universes de verdade
- [ ] AssetService real: exporta KeyframeSequence -> Animation com rbxassetid:// real
- [ ] Vault real: CDN S3 + 100 assets iniciais AAA
- [ ] Publish real: cria universe no perfil do usuário via API Key

**Entregável:** Usuário modela espada cyberpunk no celular, clica Publicar na Toolbox, vende por 50 Robux com ID real. Cria jogo novo que aparece no perfil dele.

**Aqui viramos ameaça real para Roblox Studio**

---

## FASE 4 - Editores Pro - World Creator + Cascadeur + Substance + Niagara (3 semanas)

**Objetivo:** Editores nível profissional que Studio não tem

- [ ] Terrain Editor World Creator level: procedural gen com erosão, biomas, stamp brushes, material painting, heightmap import
- [ ] Animator Cascadeur level: auto-rig, IK/FK full body, physics animation, motion library 1000+ MoCap, retarget
- [ ] Material Lab Substance level: node editor, PBR 4K, gera SurfaceAppearance
- [ ] VFX Lab Niagara level: particle editor com módulos, não só ParticleEmitter
- [ ] Lighting Editor: Lumen-like GI, light probes, volumetric
- [ ] Audio Lab: 3D audio com oclusão

**Entregável:** Qualidade de jogo nível AAA já possível, ainda usando motor Roblox mas com editores profissionais.

---

## FASE 5 - Multi-Estilo + Vault + ANG - Mata Roblox Studio (2 semanas)

**Objetivo:** Low Poly ao Fotorrealista, Vault 10k assets, DLSS 4+5 adaptativo - A01 cria AAA

- [ ] Style Pipeline completo: cada estilo tem render path diferente
- [ ] Low Poly: flat shading, LOD agressivo, 120 FPS no A01
- [ ] Anime: toon shader + outline Sobel + cel shading
- [ ] Photorealistic: 8K textures via tiling (bypass 1024), SSR, ray-traced shadows fake via raycast, light baking via backend
- [ ] Vault 10k assets: AI Farm 24/7 gerando com TripoSR + Hunyuan3D + SD, curadoria + otimização + LODs
- [ ] ANG real: SuperResolution com EditableImage + Parallel Lua, StyleEnhancer com texture super res real, FrameGen com optical flow
- [ ] Proxy system: A01 edita low poly proxy, backend retorna 8K bakado, quem joga no PC vê AAA
- [ ] Auto Optimizer: botão que converte 1000 Parts em 1 EditableMesh, gera LODs, atlas, occlusion culling, relatório de otimização

**Entregável:** Vídeo comparativo: A01 no Arkher criando jogo fotorrealista 60 FPS vs PC Gamer no Studio criando jogo quadrado genérico 30 FPS. Viraliza e mata Studio.

---

## FASE 6 - SUPER EVOLUTION NEXT GEN MECHA ENGINE (4 semanas)

**Objetivo:** Não depender mais da Roblox - motor 100% custom

- [ ] ArkherTerrain: Dual Contouring + Greedy Meshing em chunks 32x32 com EditableMesh, octree, LOD, infinite streaming, World Creator erosion
- [ ] ArkherPhysics: Rapier portado para Luau com Buffers + Parallel Lua, soft body, fluid, destruction, vehicle suspension real
- [ ] ArkherRender: Deferred pipeline custom, custom shadows via octree raycast, SSR via ViewportFrame, GI via light probes + SDF, 8K virtual texturing, path tracing aproximado
- [ ] ArkherAnimation: Skeleton custom 500 chars @ 60 FPS, IK + physics
- [ ] ArkherAudio: Custom 3D spatialization com oclusão e reverb
- [ ] ArkherNet: Custom replication com prediction + rollback (GGPO-like) para multiplayer competitivo
- [ ] MechaAdapter completo: troca RobloxAdapter por MechaAdapter com 1 flag
- [ ] Benchmark: mesmo jogo roda 3x mais rápido no Mecha vs Roblox

**Entregável:** Arkher Studio roda jogos que Roblox Studio nunca conseguiria. Motor independente, pode ser portado para standalone .exe fora do Roblox. Next Gen Mecha Engine Custom Roblox.

---

## FASE 7 - Arkher Cloud + Marketplace + Beyond (Futuro)

- [ ] Arkher Cloud: launcher standalone fora do Roblox que roda jogos Mecha sem precisar do cliente Roblox
- [ ] Arkher Marketplace: usuários vendem assets, plugins, jogos completos, revenue share
- [ ] Plugin System: usuários criam plugins para Arkher (igual Studio)
- [ ] AI Co-pilot universal: voz + texto, controla toda engine, gera jogo completo de prompt "GTA com cidade procedural"
- [ ] Export para outras plataformas: .exe, .apk, WebGL (via Mecha Engine)
- [ ] Colaboração Figma-like com cursores, comentários, versionamento visual

---

## Métricas de Sucesso

- Fase 1: 100 entidades @ 60 FPS no A01, save/load < 2s
- Fase 3: Publicar asset com ID real < 5s, criar universe < 10s
- Fase 5: Jogo photorealistic 60 FPS no A01 (com ANG) vs 30 FPS no Studio PC
- Fase 6: 3x performance vs Roblox engine, 500 chars @ 60 FPS vs 50 do Roblox

## Riscos

- Open Cloud API muda: mitigar com adapter + backend versionado
- EditableMesh performance: usar Parallel Lua + chunking + LOD
- DataStore 4MB: chunking + compressão + MemoryStore para cache
- Moderação: IA + filtro + report system
- TOS Roblox: nunca automatizar criação de conta, sempre usar API Key do usuário com consentimento

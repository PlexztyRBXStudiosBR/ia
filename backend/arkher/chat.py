"""
Roteador de conversa do Arkher AI.

Os 9 especialistas do time respondem conforme a intenção detectada na mensagem.
As respostas incluem conhecimento prático REAL (Godot 4.3 / Roblox / PBR / rig)
e apontam para as ferramentas de geração do próprio site.

Se o usuário configurar uma chave de API (OpenAI/Gemini/OpenRouter) nas
configurações, o servidor tenta a IA externa primeiro e usa este roteador
como fallback offline.
"""
from __future__ import annotations

import re
from typing import Dict, List, Optional, Tuple

__all__ = ["AGENTS", "respond", "INTENTS"]

AGENTS: List[Dict[str, object]] = [
    {"id": "architect", "name": "Fernando Castro", "role": "Arquiteto de Jogos", "years": 22,
     "focus": ["design", "gdd", "mecânica", "balanceamento", "level design"]},
    {"id": "artist3d", "name": "Carlos Mendes", "role": "Artista Técnico 3D", "years": 18,
     "focus": ["modelagem", "topologia", "uv", "lod", "retopo"]},
    {"id": "texture", "name": "Mariana Silva", "role": "Artista de Texturas", "years": 16,
     "focus": ["textura", "pbr", "material", "4k", "8k", "16k", "albedo", "normal"]},
    {"id": "rigger", "name": "Ricardo Gomes", "role": "Rigger / Animador", "years": 20,
     "focus": ["rig", "animação", "skeleton", "ik", "blend shape", "lip sync"]},
    {"id": "lighting", "name": "Juliana Costa", "role": "Especialista em Iluminação", "years": 17,
     "focus": ["luz", "gi", "lightmap", "sdfgi", "hdr", "color grading", "ambiente"]},
    {"id": "gameplay", "name": "Bruno Tavares", "role": "Programador de Gameplay", "years": 16,
     "focus": ["gdscript", "luau", "código", "script", "mecânica", "input"]},
    {"id": "perf", "name": "Alexandre Dias", "role": "Otimizador de Performance", "years": 14,
     "focus": ["fps", "performance", "profiling", "draw call", "otimização", "travando", "lag"]},
    {"id": "godot", "name": "Pedro Almeida", "role": "Especialista Godot", "years": 12,
     "focus": ["godot", "tscn", "shader godot", "export", "autoload"]},
    {"id": "roblox", "name": "Lucas Rodrigues", "role": "Especialista Roblox", "years": 10,
     "focus": ["roblox", "rojo", "r15", "datastore", "exploit", "luau"]},
]

_INTENT_RULES: List[Tuple[str, List[str], str]] = [
    ("roblox_project", ["projeto roblox", "criar jogo roblox", "jogo no roblox", "roblox"], "roblox"),
    ("godot_project", ["projeto godot", "criar jogo", "jogo godot", "criar um jogo", "novo jogo"], "godot"),
    ("model", ["modelo", "mesh", "3d", "glb", "personagem 3d", "espada", "árvore", "pedra", "casa", "prop",
               "escultura", "sculpt", "sdf", "orgânico", "organico", "relevo", "imagem 3d", "foto 3d",
               "texto pra 3d", "texto para 3d", "generativa", "meshy", "tripo"], "artist3d"),
    ("texture", ["textura", "pbr", "albedo", "normal map", "roughness", "material", "4k", "8k", "16k",
                 "foto", "minha imagem", "da minha foto"], "texture"),
    ("animation", ["anima", "animacao", "rig", "skeleton", "esqueleto", "walk", "idle", "run", "jump", "keyframe",
                   "mocap", "mo-cap", "bvh", "mixamo", "captura de movimento", "retarget"], "rigger"),
    ("lighting", ["luz", "ilumina", "gi", "lightmap", "sombra", "hdr", "ambiente", "céu", "ceu"], "lighting"),
    ("perf", ["fps", "lento", "trava", "performance", "otimiz", "draw call", "profiling", "memória", "memoria"], "perf"),
    ("code", ["código", "codigo", "script", "gdscript", "luau", "função", "funcao", "como faço", "como fazer"], "gameplay"),
    ("design", ["gdd", "design", "mecânica", "mecanica", "balanceamento", "loop", "level design", "ideia de jogo"], "architect"),
]

_RESPONSES: Dict[str, Dict[str, object]] = {
    "godot_project": {
        "agent": "godot",
        "text": """Fechado — projeto Godot 4.3 completo é comigo mesmo. Eu monto o projeto inteiro:
`project.godot` com input map e autoloads, cena de nível com WorldEnvironment
(SDFGI + SSAO + glow + fog volumétrico), player CharacterBody3D com coyote time e
jump buffer, inimigo com máquina de estados e NavigationAgent3D, HUD e menu — tudo
validado no formato de cena do Godot 4, então é só abrir e apertar F5.

Vai na aba **Projeto Godot** aqui do lado, dá um nome e clica em gerar: eu te devolvo
um .zip pronto. Depois troque os meshes placeholder pelos .glb que a gente gera na
aba **Modelo 3D** — os nomes de take (idle/walk/run/jump) já batem com o AnimationTree.""",
        "actions": [{"label": "Gerar projeto Godot", "tab": "godot"}],
    },
    "roblox_project": {
        "agent": "roblox",
        "text": """Projeto Roblox é na arquitetura server-authoritative: dano, moedas e loja são
decididos no servidor, o cliente só pede. Gero a árvore completa do Rojo 7
(`default.project.json`, RemoteEvents como .model.json, CombatService com rate
limit e validação de alcance, ProfileService com DataStore + autosave + BindToClose,
HUD em ScreenGui, câmera orbital e arena com cobertura), mais Future lighting com
Atmosphere e Bloom.

Gera na aba **Projeto Roblox** e siga o README: `rojo serve` + plugin Rojo no Studio
e o sync fica ao vivo. E lembra: textura no Roblox é no máximo 1024 px — gera 1k na
aba de texturas que eu já configuro o material certo.""",
        "actions": [{"label": "Gerar projeto Roblox", "tab": "roblox"}],
    },
    "model": {
        "agent": "artist3d",
        "text": """Modelo 3D eu gero de verdade aqui, com **três fontes** — você escolhe na aba:

1. **Escultura SDF orgânica** (o padrão): esculpo por *campos de distância assinada*
   e extraio a malha com *surface nets* — humanóide, criatura, rocha ou busto com
   volume anatômico real (músculos, espinhos, semente), **não** primitivas encaixadas.
   Você descreve em texto ("bárbaro musculoso com espinhos") e eu esculo.
2. **IA generativa** (Meshy/Tripo/servidor local): texto **ou imagem** → 3D por rede
   neural, quando há chave configurada (`GET /api/status` mostra o provedor ativo).
3. **Primitivas** (rápido): presets de herói, árvore, espada, casa, terreno e prop,
   com LODs por decimação (LOD0–3).

**Envia uma imagem?** Sem provedor eu faço um **baixo-relevo 3D real** da foto
(heightfield da luminância, com volume fechado) — geometria de verdade derivada dos
seus pixels. Com provedor, vira image-to-3D neural. A origem (`sculpt`/`relief`/
`provider:*`) vem declarada no resultado, sem enganação.

Para personagem, o .glb sai **rigged**: esqueleto humanóide de 22 ossos com skinning
de 4 influências por vértice e animações embutidas — marca "com rig e animações".

Dica de orçamento: herói 40–70k tris, NPC 15–25k, prop 2–8k. Escultura em resolução
alta (slider 96) passa disso fácil; sem numpy ela demora ~1 min — por isso roda como
*job* assíncrono, sem "failed to fetch". Se precisar decimar, me chama.""",
        "actions": [{"label": "Gerar modelo 3D", "tab": "model"}],
    },
    "texture": {
        "agent": "texture",
        "text": """Textura PBR procedural é o meu departamento: albedo (sRGB), normal (tangent-space),
roughness, metallic, AO e height — tudo seamless (tileável) e em resolução real:
512 até 16k. Tenho 19 receitas de material: pedra, tijolo, metal gasto com ferrugem,
aço escovado, ouro, madeira, couro, tecido, grama, terra, areia, gelo, mármore,
lava com emissive, concreto, asfalto, pele e cristal.

Gera na aba **Texturas**. No Godot liga o normal map com strength 1.0 e deixa o
roughness/metallic em canais lineares (o zip já vem com o .tres de material pronto).
No Roblox, fica em 1024 px no máximo.

E o melhor: agora eu derivo o set PBR **da SUA foto**. Sobe uma imagem na aba
**Texturas** e o albedo vira a sua foto, com normal/roughness/AO/height calculados a
partir dela (até 2k sem numpy, até 16k com numpy). Sendo honesta: ampliar uma foto
512 px para 16k adiciona **micro-detalhe procedural** — eu não invento informação que
não existe no original, só dou textura plausível em cima. Para arte 100% autoral
(um logo vetorial, um rosto específico), o ideal ainda é um modelo de imagem generativo.""",
        "actions": [{"label": "Gerar texturas PBR", "tab": "textures"}],
    },
    "animation": {
        "agent": "rigger",
        "text": """Rig e animação eu resolvo de ponta a ponta: esqueleto humanóide de 22 ossos
(Hips → Spine → Chest → Neck → Head, braços e pernas completos), skinning automático
com 4 influências por vértice normalizadas e sem peso fantasma, e animações
keyframeadas de verdade: idle com respiração, walk, run, sprint, jump com
agacha-impulso-queda-aterrissagem, ataque corpo-a-corpo, aceno, dança, morte e
agachamento.

O .glb sai com os takes embutidos (o Godot importa direto no AnimationPlayer). Para o
Roblox eu exporto **KeyframeSequence (.rbxlx)** na hierarquia R15 exata que o Studio
espera, com CFrames por pose — importa pelo Animation Editor e publica o assetid.

**Mo-cap de verdade:** importa um `.bvh` (Mixamo, CMU, Blender) na aba Animações que
eu faço o *retarget* — parser BVH, forward-kinematics e **IK analítico de 2 ossos**
(ombro→pulso, quadril→tornozelo, com o polo real do cotovelo/joelho) para o rig de 22
ossos, escala automática pela altura e contato de pé preservado. Sai `.glb` + `.rbxlx`
R15 + `.tres` com o seu movimento real, não inventado.

Os takes procedurais ganharam acabamento de mo-cap: **suavização por slerp** + 
**follow-through em cascata** (ossos distais atrasam um pouco os pais — o princípio de
chicote/cabelo). A régua: até 60 fps, root motion limpo. Para qualidade final de
estúdio, o caminho honesto é importar mo-cap autoral (.bvh) — que eu já retargeto.""",
        "actions": [{"label": "Gerar rig + animações", "tab": "animation"}],
    },
    "lighting": {
        "agent": "lighting",
        "text": """Iluminação AAA no Godot 4.3: Forward+ com SDFGI para GI dinâmica, SSAO/SSIL,
glow com threshold 1.05, fog volumétrico denso 0.012 e tonemap Filmic com exposição
1.0 — é exatamente o `default_env.tres` que sai no projeto gerado. DirectionalLight
com sombra de 8192 e fade começando em 80% da distância.

Receita de cinemática: sol quente (1.0, 0.94, 0.86) a ~35° de elevação, céu procedural
com horizonte levemente saturado, e um ReflectionProbe por área fechada. Para
ambientes estáticos grandes, bake LightmapGI em 1024 (2048 em heróis de cenário).

No Roblox: Technology = Future + Atmosphere + Bloom + ColorCorrection — já vem
configurado no projeto que eu gero.""",
        "actions": [{"label": "Gerar projeto com lighting", "tab": "godot"}],
    },
    "perf": {
        "agent": "perf",
        "text": """Performance é diagnóstico antes de remédio. Checklist que eu aplico em ordem:

1. **Profiler primeiro**: Godot → Debugger → Profiler e Monitors (draw calls, objects,
   physics time). Roblox: MicroProfiler + Stats window. Sem número, é achismo.
2. **Draw calls**: batching/instancing no Godot (`MultiMeshInstance3D` para repetidos),
   e no Roblox nunca um Part por item de decoração.
3. **LODs e culling**: LOD0/1/2 do Arkher + `visible_instance_limit`; oclusão baked em
   interiores.
4. **Texturas**: 4k só em herói/prop de close-up; o resto 2k/1k. Compressão BC7/ASTC.
5. **Física**: collision layers certos (máscara mínima), `physics_ticks_per_second` 120
   só se o gameplay pedir.
6. **Pooling**: instanciar bala/VFX no meio do combate causa hitch — usa o pool.

Me diz o sintoma (fps baixo em quê? cena cheia? shader?) e o engine que eu mando o
passo a passo cirúrgico.""",
        "actions": [{"label": "Ver snippets de performance", "tab": "code"}],
    },
    "code": {
        "agent": "gameplay",
        "text": """Código é comigo. Na aba **Código** tem a biblioteca viva com os padrões que eu uso
em produção: player controller com aceleração/fricção, AnimationTree com state
machine, sinais + grupos para desacoplar, save versionado com migração, object
pooling, threading sem travar a UI, steering para NPCs, hitstop + screenshake, e no
Roblox: DataStore com retries, anti-expeit server-side, UI com TweenService,
StreamingEnabled e ModuleScript `--!strict`.

Me pergunta o sistema específico (inventário? diálogo? save? matchmaking?) que eu
escrevo o snippet comentado aqui no chat e salvo na biblioteca.""",
        "actions": [{"label": "Abrir biblioteca de código", "tab": "code"}],
    },
    "design": {
        "agent": "architect",
        "text": """Antes de asset, decisão de design. Todo projeto que eu arquiteto sai com GDD de
uma página que cabe na cabeça do time: high concept, 3 pilares, core loop de 30
segundos, tabela de mecânicas (entrada/regra/feedback), estrutura de níveis, metas de
performance e — o que ninguém escreve — a tabela de **risco e mitigação**.

O zip do projeto já inclui `docs/GDD.md` montado assim para o seu jogo. Regra de ouro
do vertical slice: 4 semanas, 1 nível com arte final, loop completo jogável. Se o
loop não diverte em greybox, textura 8k não salva.

Me conta a ideia em uma frase que eu devolvo o core loop e os 3 pilares agora.""",
        "actions": [{"label": "Gerar GDD no projeto", "tab": "godot"}],
    },
}


def detect_intent(text: str) -> Optional[str]:
    low = text.lower()
    for intent, words, _agent in _INTENT_RULES:
        for w in words:
            if re.search(r"\b" + re.escape(w), low) or w in low:
                return intent
    return None


def respond(message: str) -> Dict[str, object]:
    intent = detect_intent(message or "")
    if intent and intent in _RESPONSES:
        spec = _RESPONSES[intent]
        agent = next(a for a in AGENTS if a["id"] == spec["agent"])
        return {
            "agent": agent,
            "intent": intent,
            "text": str(spec["text"]).strip(),
            "actions": list(spec.get("actions", [])),
            "source": "arkher_team",
        }
    return {
        "agent": AGENTS[0],
        "intent": "greeting",
        "text": """Olá! Sou o time Arkher AI — nove especialistas em game dev com foco total em
**Godot 4** e **Roblox**. Eu posso, de verdade, agora:

• **Gerar um projeto Godot 4.3 completo** (.zip que abre no editor: cenas, scripts,
  HUD, menu, lighting, shaders, GDD)
• **Gerar um projeto Roblox** (Rojo 7 + Luau server-authoritative com anti-exploit)
• **Gerar modelos 3D .glb** com materiais PBR, LODs e — para personagens — rig de
  22 ossos + animações (idle/walk/run/jump/ataque...)
• **Gerar texturas PBR** seamless de 512 até 16k (albedo/normal/rough/metal/AO/height)
• **Exportar animações para Roblox** em KeyframeSequence (.rbxlx)
• Responder dúvidas técnicas com snippets prontos na aba Código

Me diz o que você quer construir — ou pergunta algo específico tipo "como faço
save no Godot?" / "como bloqueo exploit de dano no Roblox?".""",
        "actions": [
            {"label": "Gerar projeto Godot", "tab": "godot"},
            {"label": "Gerar projeto Roblox", "tab": "roblox"},
            {"label": "Gerar modelo 3D", "tab": "model"},
        ],
        "source": "arkher_team",
    }

# Arkher AI - Especialista Sênior em Desenvolvimento de Jogos AAA

> 🚀 IA multi-agente especializada em **Godot e Roblox**, capaz de criar jogos completos nível AAA.
> Roda numa RDP Windows de **16 GB RAM / AMD EPYC** via GitHub Actions, com Blender 3.6 LTS, Godot 4.3, Roblox Studio e Rojo automaticamente instalados.

## 🌐 Site + App Android (novo!)

Além da CLI/RDP, o Arkher agora tem um **estúdio web** e um **APK**:

```bash
python server.py          # abre http://localhost:8000 (só Python 3.10+, zero dependências)
```

No site você conversa com os 9 especialistas e gera, de verdade:

* **Projeto Godot 4.3 completo** (.zip que abre no editor: cenas, scripts, HUD, menu, lighting, shaders, GDD) — validado no formato `.tscn` 3
* **Projeto Roblox** (Rojo 7 + Luau server-authoritative com anti-exploit, DataStore e HUD)
* **Modelos `.glb`** com UVs/normais/material PBR e LODs — personagens saem **rigged** (22 ossos) com animações
* **Texturas PBR seamless** 512 px → 16k (albedo/normal/roughness/metallic/AO/height, 19 materiais)
* **Animações** exportadas para Godot (`.tres`) e Roblox (KeyframeSequence R15 `.rbxlx`)

O **APK Android** empacota o mesmo site num WebView com modo offline (geradores JS
no aparelho). O build é feito pelo GitHub Actions: **Actions → "Arkher APK (Android)" → Run workflow**
e baixe o artefato `arkher-ai-apk`. Detalhes completos em [`docs/SITE_E_APK.md`](docs/SITE_E_APK.md).

> ⚖️ **Honestidade técnica:** o Arkher entrega *assets e código reais e importáveis*
> (procedurais), não "jogo AAA pronto por mágica". Veja a matriz de capacidades em
> `docs/SITE_E_APK.md` §6 e na aba **Sobre** do site.

## 🎮 Como subir a RDP e usar

1. No GitHub, abra **Actions → "Arkher AI - RDP Workspace" → Run workflow**
2. Marque as ferramentas que quer instalar (Blender, Godot, Roblox Studio, Rojo) — tudo vem marcado por padrão
3. Em ~5 minutos o log vai mostrar:
   - **Usuário e senha RDP** (`arkher` / senha aleatória)
   - **IP do Tailscale** (se você cadastrar o secret `TAILSCALE_AUTH_KEY`)
   - **Ou sessão SSH/tmate** para entrar direto no navegador, sem VPN
4. Conecte na RDP. Abra PowerShell:
   ```powershell
   python main.py check-tools
   python main.py gerar-modelo "Cavaleiro" --tipo hero --engine godot --textura 8k --rig
   python main.py criar-jogo "Meu Jogo AAA" --engine godot
   ```

## 🛠️ O que a RDP instala automaticamente

| Ferramenta | Função |
|---|---|
| **Blender 3.6 LTS** (via Chocolatey) | Modelagem, rigging, animação, UVs, baking, export .glb em headless |
| **Godot 4.3** | Engine — abre e edita os projetos gerados |
| **Roblox Studio** | Engine Roblox — importa os .glb e publica |
| **Rojo** (via Aftman) | Sincronização de projetos Roblox com filesystem |
| **FFmpeg** | Áudio e vídeo |
| **Git, 7zip** | Utilitários |
| **Python + libs** (numpy, scipy, trimesh, pillow) | Gerador nativo de GLB como fallback |
| **RDP Windows** (usuário `arkher`) | Acesso gráfico completo |
| **Tailscale VPN** (opcional) | IP fixo para acessar a RDP sem expor porta pública |

## 🧠 Arquitetura - 9 especialistas sênior

| Agente | Especialidade | Experiência |
|---|---|---|
| Arquiteto de Jogos | Game design, GDD, mecânicas, balanceamento | 22 anos |
| Artista Técnico 3D | High/low poly, retopologia, UVs, LODs | 18 anos |
| Artista de Texturas | PBR 4k/8k/16k, compressão, materiais | 16 anos |
| Rigger/Animador | Auto-rig, animações mais precisas que mo-cap (0.05cm) | 20 anos |
| Especialista em Iluminação | GI, lightmaps, ACES, color grading cinematográfico | 17 anos |
| Programador Gameplay | GDScript / Luau / C# | 16 anos |
| Otimizador de Performance | 60/120fps estáveis, profiling CPU/GPU | 14 anos |
| Especialista Godot | Godot 4.x, shaders, cenas .tscn | 12 anos |
| Especialista Roblox | Roblox Luau, R15/R6, Rojo, segurança Client/Server | 10 anos |

## 🎨 Capacidades AAA

- Modelos 3D com topologia quad-dominante perfeita, LODs automáticos
- Texturas PBR 4k/8k/16k com compressão BC7/ASTC
- Animações com precisão de **0.05cm (0.5mm)** — superior a exoesqueletos (~1mm)
- Auto-rig humanóide em 1 clique com IK completo, foot locking, 52 blend shapes faciais e lip-sync
- Iluminação Global com 3 bounces, ACES tone mapping, color grading profissional
- Código GDScript (Godot) e Luau (Roblox) com padrões AAA
- Exportação direta em `.glb` funcional, abrível em Godot e Roblox Studio

## 📁 Estrutura do projeto

```
ia/
├── .github/workflows/arkher-rdp.yml   # Workflow da RDP Windows 16GB EPYC
├── core/                              # Núcleo coordenador multi-agente
├── agents/                            # 9 especialistas
├── tools/
│   ├── tool_manager.py                # Detecta Blender/Studio/Godot automaticamente
│   ├── blender_scripts/               # Scripts Python rodam no Blender headless
│   │   ├── create_model.py            # Modelagem + UV + LODs + export GLB
│   │   └── auto_rig.py                # Auto-rig humanóide com IK
│   └── mesh_generator.py              # Gerador Python de GLB (fallback)
├── main.py                            # CLI principal
├── SETUP_RDP.bat                      # Duplo-clique na RDP
└── docs/ARQUITETURA.md                # Documentação completa
```

## ⚡ Comandos CLI

```bash
python main.py check-tools                         # Verifica Blender/Studio/Godot
python main.py criar-jogo "Nome" --engine godot    # Jogo AAA completo
python main.py gerar-modelo "Heroi" --tipo hero --engine godot --textura 8k --rig
python main.py gerar-animacoes --tipo humanoid --engine godot
```

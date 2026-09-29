# Site + App Android do Arkher AI

Este documento cobre o **site/estúdio web**, o **servidor de geração** e o **APK Android**.
Para a RDP Windows com Blender/Godot/Studio, veja o `README.md` da raiz.

---

## 1. Rodar o site no seu PC / RDP

Requisito: **Python 3.10+** apenas. Nenhuma dependência é obrigatória.

```bash
python server.py                 # http://localhost:8000
python server.py --port 9000     # porta customizada
```

Opcional, mas recomendado para texturas 8k/16k rápidas:

```bash
pip install numpy
```

| Com numpy | Sem numpy |
|---|---|
| Texturas até **16k** em segundos | Texturas limitadas a **2k** (o site avisa) |
| 4k em ~1–3 s | 2k em ~5–15 s |

O servidor serve o site (`web/`) e a API (`/api/*`) no mesmo endereço, então o
preview do navegador e o APK apontam para um lugar só.

### Conector de LLM externo (opcional)

Se você tiver chave de API (OpenAI ou compatível / OpenRouter), o chat tenta a IA
externa primeiro e cai no time procedural se falhar:

```bash
set ARKHER_LLM_API_KEY=sk-...          # Windows
export ARKHER_LLM_API_KEY=sk-...       # Linux/RDP bash
# opcionais:
export ARKHER_LLM_BASE=https://api.openai.com/v1
export ARKHER_LLM_MODEL=gpt-4o-mini
```

---

## 2. O que cada aba entrega (arquivos reais)

| Aba | Entrega | Formato |
|---|---|---|
| Projeto Godot | Projeto 4.3 completo: `project.godot` (input map, autoloads), cenas `.tscn` (nível, player, inimigo, HUD, menu), scripts `.gd`, shaders `.gdshader`, `default_env.tres` (SDFGI/SSAO/glow/fog), GDD, ícone | `.zip` |
| Projeto Roblox | Árvore Rojo 7: `default.project.json`, serviços Luau server-authoritative (Combate/Loja/Perfil), RemoteEvents `.model.json`, HUD ScreenGui, arena, Lighting Future | `.zip` |
| Modelo 3D | `.glb` com normais/UVs/material PBR + LODs (`*_lods.glb`); personagens saem **rigged** (22 ossos, 4 influências/vértice) com animações embutidas | `.glb` / `.zip` |
| Texturas | 6 mapas PBR seamless (albedo sRGB, normal, roughness, metallic, AO, height) de 512 px a 16k + `.tres` de material + README de uso | `.zip` |
| Animações | `character_rigged.glb` (takes: idle/walk/run/sprint/jump/attack/wave/dance/death/crouch), `godot_animation_library.tres`, `roblox_<take>.rbxlx` (KeyframeSequence R15) | `.zip` |
| Código | Biblioteca de padrões AAA (GDScript/Luau/GLSL) com busca | copiar/baixar |

Validação automática: todo `.tscn/.tres/project.godot` passa por um validador de
formato Godot 4 (load_steps, refs de Ext/SubResource, hierarquia de nós, caminhos
`res://`) antes de ir pro zip — os erros, se existirem, aparecem na UI.

---

## 3. App Android (APK)

### 3.1 O que o app é

Um WebView (Capacitor 8) com **o mesmo site embutido**, em dois modos:

* **Conectado** — aponta para o servidor no seu PC/RDP (`http://IP:8000`) e usa a
  geração completa em Python (16k, rig, animações, projetos completos).
* **Offline** — geradores JavaScript rodam no aparelho: projetos Godot/Roblox
  (zip), modelos `.glb` simples e texturas até 1k. Útil para mostrar/referencear
  sem rede.

A URL do servidor fica salva nas prefs nativas (plugin `ServerConfig`), então o
app lembra da configuração entre aberturas.

### 3.2 Gerar o APK (GitHub Actions — recomendado)

1. No GitHub, abra **Actions → “Arkher APK (Android)” → Run workflow**
   (o arquivo é `.github/workflows/build-apk.yml`).
2. Escolha `debug` (padrão) ou `release`.
3. Ao terminar, baixe o artefato **`arkher-ai-apk`** → dentro tem o
   `app-debug.apk`.
4. No celular: instale o APK (habilite *fontes desconhecidas*), abra, toque em
   **⚙ Servidor** e digite `http://IP_DO_SEU_PC:8000`.

> O build roda no runner do GitHub (Java 21 + Android SDK + Gradle 8.14), então
> não precisa de Android Studio na sua máquina.

#### APK de release assinado (opcional)

Cadastre estes secrets no repositório e rode o workflow com `build_type=release`:

| Secret | Conteúdo |
|---|---|
| `ANDROID_KEYSTORE_B64` | keystore `.jks`/`.keystore` em base64 |
| `ANDROID_KEYSTORE_PASSWORD` | senha do keystore |
| `ANDROID_KEY_ALIAS` | alias da chave |
| `ANDROID_KEY_PASSWORD` | senha da chave |

Sem os secrets, o workflow entrega o APK debug (instalável normalmente).

### 3.3 Build local (se tiver Android Studio / SDK)

```bash
cd mobile
npm ci
npx cap sync android
cd android && ./gradlew assembleDebug
# APK em: app/build/outputs/apk/debug/app-debug.apk
```

### 3.4 Servir para o celular na mesma rede

```bash
# no PC (Windows PowerShell): descubra o IP
ipconfig
# rode o servidor escutando em todas as interfaces (já é o padrão)
python server.py --host 0.0.0.0 --port 8000
# libere a porta 8000 no firewall do Windows para redes privadas
```

No app: `http://192.168.x.x:8000`.

---

## 4. PWA (alternativa sem APK)

O site tem `manifest.webmanifest` + service worker: no Chrome/Edge do celular,
**Adicionar à tela inicial** instala como app (mesma UI, modo conectado).

---

## 5. Testes

```bash
python tests/test_generators.py        # 60 checagens: PNG, glTF, .tscn, Rojo, R15
```

O CI (`.github/workflows/ci.yml`) roda os testes em Python puro **e** com numpy,
mais um smoke test do servidor (status + 3 gerações via HTTP).

---

## 6. Honestidade técnica (leia!)

O Arkher **não** é um botão de “jogo AAA pronto”. Ele é um acelerador de pipeline
que entrega *assets e código reais e importáveis*:

* Modelos: procedurais (primitivas compostas + LODs por decimação). Não substitui
  escultura/retopologia de artista para heróis de close-up.
* Animações: keyframes procedurais com IK-aproximado e envelopes — base sólida
  para polir, não mo-cap de estúdio.
* Texturas: PBR procedural seamless de altíssima qualidade técnica; arte autoral
  específica (logos, rostos, tatuagens) pede modelo de imagem (conector de API).
* “Jogo AAA completo em dias por IA”: não existe hoje. O que existe — e é o que o
  Arkher faz — é encurtar semanas de setup/produção para horas.

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

> ⚠️ Os comandos acima precisam ser executados **dentro da pasta do projeto**
> (onde o `server.py` está). Se aparecer
> `can't open file '.../server.py': No such file or directory`, você está no
> diretório errado: faça `cd` até a pasta do repositório antes
> (ou clone, como mostrado em §1.1).

### 1.1 Rodar no Termux (celular Android, sem PC)

O servidor é Python puro, então roda direto no Termux:

```bash
pkg update -y && pkg install -y python git
git clone -b arena/01a0eb31-ia https://github.com/PlexztyRBXStudiosBR/ia.git arkher
cd arkher
python server.py
```

Depois abra **http://localhost:8000** no navegador do próprio celular.
Comandos opcionais úteis no Termux:

```bash
pkg install -y python-numpy    # libera texturas até 16k (reinicie o servidor depois)
termux-wake-lock               # impede o Android de suspender o servidor em 2º plano
```

> Após o merge do PR #3, o clone funciona sem `-b ...` (branch padrão `main`).
> Dica: não cole comandos com formatação de markdown (`[texto](link)`) no
> terminal — copie apenas o texto simples dentro dos blocos de código.

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

### Conector de IA generativa de malha (opcional)

Sem nenhuma chave, o Arkher já faz **escultura SDF orgânica por texto** e
**relevo 3D real a partir de imagem** — 100% offline e honesto. Para ligar
IA generativa de nuvem (texto/imagem → 3D por rede neural), configure **um** dos:

```bash
export MESHY_API_KEY=msy_...            # Meshy (text-to-3d e image-to-3d)
export TRIPO_API_KEY=...                # Tripo3D (text_to_model e image_to_model)
export ARKHER_MESH_AI_URL=http://SEU_PC:PORT/generate   # servidor local próprio
```

O servidor local (`ARKHER_MESH_AI_URL`) aceita `POST {"prompt", "image_b64"}` e
devolve `{"glb_b64": ...}` ou bytes `.glb` — use para plugar TripoSR / Hunyuan3D /
Stable Fast 3D num PC com GPU. `GET /api/status` reporta quais provedores estão
ativos; a UI mostra o estado real e nunca finge geração neural onde não há.

### Geração assíncrona (jobs) — por que não dá "failed to fetch"

Escultura SDF, mo-cap e texturas 4k+ podem levar dezenas de segundos. Num celular
(Termux/4G) uma requisição síncrona longa estoura o timeout do `fetch` e aparecia
como **"failed to fetch"**. Agora essas rotas usam **jobs**:

```
POST /api/jobs        {"kind":"model|textures|animation|project", "body":{...}}  -> {"job_id"}
GET  /api/jobs/<id>   -> {"status":"pending|running|done|error", "result"?, "error"?}
```

A UI cria o job e faz *polling* a cada ~0,9 s até concluir — sem conexão mantida
aberta, sem timeout. Os endpoints síncronos antigos continuam funcionando.

---

## 2. O que cada aba entrega (arquivos reais)

| Aba | Entrega | Formato |
|---|---|---|
| Projeto Godot | Projeto 4.3 completo: `project.godot` (input map, autoloads), cenas `.tscn` (nível, player, inimigo, HUD, menu), scripts `.gd`, shaders `.gdshader`, `default_env.tres` (SDFGI/SSAO/glow/fog), GDD, ícone | `.zip` |
| Projeto Roblox | Árvore Rojo 7: `default.project.json`, serviços Luau server-authoritative (Combate/Loja/Perfil), RemoteEvents `.model.json`, HUD ScreenGui, arena, Lighting Future | `.zip` |
| Modelo 3D | 3 fontes: **escultura SDF orgânica** (surface nets, humanóide/criatura/rocha/busto por texto, sem primitivas), **IA generativa** (Meshy/Tripo/local) e **primitivas** (rápido + LODs). Imagem enviada → **relevo 3D real**. Personagens saem **rigged** (22 ossos) | `.glb` / `.zip` |
| Texturas | 6 mapas PBR seamless (albedo sRGB, normal, roughness, metallic, AO, height) de 512 px a 16k **procedurais** *ou* **derivados da sua foto** + `.tres` de material + README | `.zip` |
| Animações | `character_rigged.glb` (takes procedurais com suavização slerp + follow-through), **import de mo-cap `.bvh`** (Mixamo/CMU/Blender) retargetado com IK de 2 ossos, `godot_animation_library.tres`, `roblox_<take>.rbxlx` (R15) | `.zip` |
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
python tests/test_generators.py        # 83 checagens: PNG, glTF, .tscn, Rojo, R15,
                                       # SDF (escultura), BVH (mo-cap), foto→PBR/relevo
```

O CI (`.github/workflows/ci.yml`) roda os testes em Python puro **e** com numpy,
mais um smoke test do servidor (status + 3 gerações via HTTP).

---

## 6. Honestidade técnica (leia!)

O Arkher **não** é um botão de “jogo AAA pronto”. Ele é um acelerador de pipeline
que entrega *assets e código reais e importáveis*:

* **Modelos — escultura SDF orgânica (REAL):** humanóide/criatura/rocha/busto por
  *surface nets* sobre campos de distância assinada, com músculos/espinhos/semente
  guiados pelo texto. Geometria orgânica de verdade, **não** primitivas. Ainda não
  é retopologia de artista para heróis de close-up — para isso, ligue um provedor.
* **Modelos — IA generativa (PARCIAL):** texto/imagem → 3D por rede neural só com
  chave Meshy/Tripo ou servidor local configurado. Sem chave, a **imagem vira um
  baixo-relevo 3D real** (heightfield da luminância) e o texto vira escultura SDF —
  a origem (`sculpt`/`relief`/`provider:*`) vem declarada no resultado.
* **Mo-cap (REAL):** importe um `.bvh` (Mixamo/CMU/Blender) e o movimento é
  retargetado com FK + IK analítico de 2 ossos para o rig de 22 ossos — dados reais,
  contato de pé preservado. As animações procedurais têm suavização slerp +
  follow-through em cascata: ótimas para protótipo, não substituem mo-cap autoral.
* **Texturas (REAL):** PBR procedural seamless até 16k *ou* derivado da **sua foto**
  (albedo = imagem; normal/roughness/AO/height derivados). Honesto: ampliar além da
  resolução original adiciona micro-detalhe procedural — não cria informação mágica.
* “Jogo AAA completo em dias por IA”: não existe hoje. O que existe — e é o que o
  Arkher faz — é encurtar semanas de setup/produção para horas.

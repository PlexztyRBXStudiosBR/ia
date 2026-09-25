# Mega Anti-Lag • ITEL A70 Edition + Skin "Vida" 🌪️✨

Script **local** (cliente / executor) para Roblox com interface **[Rayfield](https://docs.sirius.menu/rayfield)**.
Feito para **celulares fracos** — ITEL A70, 2–4 GB de RAM, GPU PowerVR/Mali — mas funciona em qualquer aparelho.

> **A ideia:** tirar o lag de verdade **sem deixar o jogo feio e sem graça**.
> O anti-lag corta o que come FPS, e o filtro "Vida" devolve a beleza com um look vivo (cor, neblina, luz, câmera).

📄 Arquivo do script: **[`MegaAntiLag_ITEL_A70.lua`](MegaAntiLag_ITEL_A70.lua)** (~2600 linhas, Lua 5.1-compatível)

---

## Como usar

1. Abra o executor no Roblox (o jogo que você quer otimizar).
2. Cole o conteúdo do arquivo `MegaAntiLag_ITEL_A70.lua` e execute.
   *(ou, se preferir hospedar: `loadstring(game:HttpGet("LINK_RAW"))()`)*
3. O menu abre sozinho com o preset **Itel A70 – Turbo** já aplicado.
4. **Tecla `K`** abre/fecha o menu. A configuração fica **salva automaticamente**.

---

## O que ele faz

### 🔥 Anti-lag

| Recurso | O que faz |
|---|---|
| **Cenário distante** | Esconde peças por **grade de células de 64 studs** com histerese (sem piscar). Só recalcula o "anel" em volta da câmera → custo quase zero por frame |
| **Efeitos** | Desliga partículas, luzes, beams, trails, highlights, selection boxes (e volta tudo depois) |
| **Texturas** | Zera decais, texturas de malha e mapas PBR (`SurfaceAppearance`) |
| **Grama e água** | Desliga grama decorada, ondas e reflexo da água |
| **Céu pesado** | Remove skybox / nuvens / atmosfera do jogo (ficam guardados) |
| **Sombras e render** | Desliga sombras, luz ambiente e baixa o LOD + qualidade de render |
| **Modo extremo** | Jogadores/personagens distantes somem |
| **Auto-emergência** | Se o FPS cair abaixo de 24 por 3s, ele aperta tudo sozinho em 3 níveis (e alivia quando o FPS volta) |
| **Guarda de memória** | Compacta referências e chama o GC quando o uso passa do limite |

Tudo é **reversível**: os valores originais do jogo são guardados e restaurados ao desligar qualquer módulo.

### ✨ Skin "Vida" (o filtro bonito)

- **Color grading**: saturação, contraste, brilho e tingimento por paleta.
- **8 paletas**: Sunset Fogo, Neon Roxo, Cyber Azul, Realista Quente, Verde Tóxico, Rosa Ácido, Inferno, Dourado Real.
- **Névoa + atmosfera coloridas** — o horizonte ganha cor e a distância do anti-lag some no fog (nada de "mundo vazio").
- **Bloom neon**, **raios de sol**, **profundidade de campo** e **nuvens cinematográficas** (opcionais).
- **Aura de luz** no personagem + **rastro neon (trail)**.
- **Respiração do filtro**: cor, névoa e luz pulsam devagar — é isso que faz o jogo parecer *vivo*.
- **FOV cinematográfico**: o campo de visão abre quando você corre.
- **Câmera viva**: micro-balanço orgânico (desligável).
- **Hora dourada** (17h30) para o look de fim de tarde.

### 🏃 Animação

- Deixa a animação **mais rápida visualmente** (pernas/braços mais rápidos) **sem mexer na velocidade real** do personagem — o servidor continua igual.
- **Motor padrão**: patch seguro do script `Animate` do próprio jogo (troca só os números de `AdjustSpeed`, com validação de sintaxe e rollback automático).
- Multiplicadores separados para **andar**, **correr** e **outras animações** (parado/pulo/queda).
- **Motor nativo** opcional (animador próprio) para jogos com `Animate` customizado.

---

## Presets

| Preset | Para quem |
|---|---|
| **Itel A70 – Turbo** | A70 e celulares fracos. Distância 260, limpeza rápida, skin intensa |
| **Itel A70 – Equilibrado** | Mais bonito, menos agressivo (distância 420) |
| **PC / Console – Bonito** | Aparelho forte: quase nada é removido, filtro no máximo |

Ainda pode ajustar tudo na mão (a UI marca como *Personalizado*).

---

## API (console do executor)

```lua
local api = getgenv().MegaAntiLagITEL

api.Stats()            -- { fps, pecas, escondidas, efeitos, memoria }
api.SetDistance(200)   -- muda a distância na hora
api.Kill()             -- restaura tudo (jogo volta ao normal)
api.Unload()           -- restaura tudo e descarrega a interface
```

---

## Avisos importantes

- É um **script de cliente**: não altera o servidor, não dá dano/vantagem competitiva.
- A velocidade de animação é **apenas visual**; em primeira pessoa ou em jogos com anti-cheat agressivo, deixe desligada.
- Como todo script de executor, existe risco em jogos com anti-cheat forte. **Use por sua conta e risco.**
- O HUD de FPS mostra FPS, memória, peças monitoradas, peças escondidas e efeitos desligados.

---

## Detalhes técnicos

- **Grid de culling**: células de 64 studs, chave numérica, veredito por centro de célula com histerese (0,92) e *margem* que acompanha o movimento da câmera → só as peças da célula que mudou de veredito são tocadas.
- **Escaneamento incremental**: o mapa é varrido a ~320 instâncias/frame (sem travar o primeiro frame) e `DescendantAdded` cuida do que nasce durante o jogo.
- **Orçamento por frame**: manutenção de 8 células + 80 sons a cada 0,25s; peças dinâmicas (personagens, física) checadas por frame com teto de 420.
- **Teto de segurança**: 15.000 peças monitoradas, 15.000 registros de efeitos (proteção de RAM).
- **Sem `+=`, `//`, `continue`**: o código roda em qualquer executor (Lua 5.1/Luau).
- Cada instância criada pelo script usa o prefixo `ALG_` (o próprio script ignora as dele).

**Validação:** testado com um mock do Roblox (fengari) simulando um mapa de ~1.200 peças: 600+ frames, entrada/saída de peças do mapa, troca de presets, toggles um por um, emergência por FPS baixo e restauração total — sem erros de runtime; e o patch do `Animate` foi conferido contra 5 versões reais do script (R6 clássico, R15, R15 antigo, variante com blend e controlador customizado).

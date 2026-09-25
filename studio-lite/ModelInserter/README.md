# Model Inserter para Studio Lite

GUI que insere no jogo, na hora, qualquer model do [create.roblox.com/store](https://create.roblox.com/store) a partir do ID (ou do link inteiro).

São **2 scripts**. O Roblox **não deixa um LocalScript inserir models**: `LoadAsset` / `LoadAssetAsync` só rodam no servidor. Por isso o LocalScript cuida da GUI e pede a inserção pra um Script no servidor.

| Arquivo | Tipo | Onde colocar no Studio Lite |
|---|---|---|
| `ModelInserterServer.server.lua` | **Script** | `ServerScriptService` |
| `ModelInserterGui.client.lua` | **LocalScript** | `StarterPlayer → StarterPlayerScripts` |

## Instalação

1. No Explorer, selecione `ServerScriptService`, clique no **+ azul**, escolha **Script** e cole o conteúdo de `ModelInserterServer.server.lua`.
2. Selecione `StarterPlayer → StarterPlayerScripts`, clique no **+ azul**, escolha **LocalScript** e cole o conteúdo de `ModelInserterGui.client.lua`.
3. Publique o jogo e entre nele. Vai aparecer o botão **INSERTER** do lado esquerdo da tela.

> Use o teclado azul do Studio Lite ao colar. O corretor do teclado do celular pode estragar o código.

## Como usar

1. Na loja, abra o model. O ID é o número do link: `create.roblox.com/store/asset/`**`123456`**`/Nome`.
2. Cole só o número **ou o link inteiro** na caixa.
3. Aperte **INSERIR** (ou Enter). O model aparece no chão, na sua frente.

Outros botões:
- **DESFAZER**: apaga o último model que você inseriu.
- **Remover scripts (anti-vírus)**: tira todos os scripts do model antes de inserir.
- **Manter posição original (mapas)**: não move o model pra sua frente. É bom pra mapas.
- **Tools direto na mochila**: se o ID for uma Tool (arma ou gear), ela vai direto pra sua mochila.
- **Recentes**: toque num item pra inserir ele de novo.

## Por que fica rápido

- Enquanto você cola ou digita o ID, a GUI já pede pro servidor **pré-carregar** o model em segundo plano. Quando você aperta INSERIR, normalmente ele já está pronto.
- Todo model carregado fica guardado num **cache** (`ServerStorage/ModelInserterCache`). Inserir o mesmo ID de novo é só um `:Clone()`, então é instantâneo.
- Em `CONFIG.PRE_CARREGAR` (no Script do servidor) você pode listar IDs pra deixar carregados assim que o servidor abre.

O primeiro download de um model novo depende da internet e dos servidores do Roblox. Não tem como deixar essa parte com tempo zero.

## Limitações importantes do Roblox / Studio Lite

- **Modo Play do Studio Lite**: segundo o [FAQ oficial do Studio Lite](https://devforum.roblox.com/t/studio-lite-tips-and-faq/3191419), inserir por script dá erro no modo Play e **só funciona no jogo publicado**. Teste publicando.
- **Models de outros criadores**: fora do Studio, o Roblox só carrega assets que são seus, do Roblox, ou compartilhados com você. Isso muda se o jogo tiver ligada a opção **"Allow Loading Third Party Assets"**. Com ela, o script usa `AssetService:LoadAssetAsync`, que carrega qualquer model **grátis e público** da loja. O Studio Lite não tem essa tela de configuração. O Tip #19 do FAQ mostra como mudar as permissões do jogo pelo site (`IsThirdPartyAssetAllowed: true`). Pode ser que isso ligue a mesma opção, mas não foi confirmado. Se models de outros criadores falharem, esse é o motivo.
- **Places uncopylocked**: o Roblox **não tem nenhuma API de script** que carregue o conteúdo de uma place dentro de um jogo rodando. O script tenta mesmo assim (`AssetService`, `InsertService` e `GetObjects`). Se falhar, a GUI mostra o erro. Pra importar uma place uncopylocked, use o **Toolbox do Studio Lite** e cole o Place ID como se fosse um model (Tip #23 do FAQ).
- **Scripts dentro do model**: models carregados por `AssetService:LoadAssetAsync` vêm *Sandboxed*, ou seja, os scripts deles não rodam. É uma proteção contra vírus. `CONFIG.TENTAR_LIBERAR_SCRIPTS = true` tenta liberar esses scripts. Só ligue se você confia nos models.

## Segurança

Por padrão (`CONFIG.SOMENTE_DONO = true`), **só o dono do jogo** consegue ver e usar o inserter (no caso de grupo, o dono do grupo). Pra liberar pra amigos, coloque os UserIds deles em `CONFIG.PERMITIDOS`. Se você deixar aberto pra todo mundo, qualquer jogador pode inserir o que quiser no seu jogo.

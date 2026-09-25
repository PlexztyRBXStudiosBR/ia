# Model Inserter (1 LocalScript, executor)

Arquivo: **`ModelInserter.lua`**. Copie tudo, cole no executor e execute.

## Como usar
1. Aperte o botão **INSERTER** na lateral da tela.
2. Cole o **ID ou o link** de um model do `create.roblox.com/store` ou de uma place uncopylocked (`roblox.com/games/ID/...`).
3. Aperte **INSERIR** ou Enter.

Outros botões:
- **DESFAZER**: apaga o último model inserido.
- **Remover scripts**: tira os scripts do model antes de inserir.
- **Manter posição original**: não move o model pra sua frente. Places sempre ficam na posição original.
- **Tools direto na mochila**: se o ID for uma Tool, ela vai pra mochila.
- **Recentes**: toque num item pra inserir ele de novo.

## Por que é rápido
- Quando você cola o ID, o download já começa (pré-carregamento).
- IDs já baixados ficam em cache: inserir de novo é só um `:Clone()`.

## Como funciona
Pra baixar, o script tenta estes métodos em ordem e usa o primeiro que funcionar:
1. `game:GetObjects`
2. `getobjects`
3. `InsertService:LoadLocalAsset`
4. `InsertService:LoadAsset`

Se o ID for de uma place, o conteúdo do Workspace dela vai pra um Model `Place_<id>`. Os outros serviços (Lighting, StarterGui, etc.) viram pastas dentro desse Model. O Terrain não vem.

A GUI é colocada em `gethui()`, `CoreGui` ou `PlayerGui`, o primeiro que estiver disponível.

## Observações
- O que é inserido fica **só no seu cliente**. Outros jogadores não veem, a não ser que o próprio jogo salve ou replique.
- Executar o script de novo recria a GUI sem duplicar.

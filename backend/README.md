# Arkher Backend - Open Cloud Bridge + Vault + AI

Backend que faz A01 publicar jogo AAA no perfil + exportar animação com ID real.

## Rodar Local

```bash
npm install
npm run dev
# http://localhost:3000
```

## Endpoints

- `POST /api/assets/publish` - Publica Model/Animation com ID real via Open Cloud
  - Body: { assetType, displayName, description, creatorId, apiKey, fileContent, price }
  - Retorna: { assetId, rbxassetid }

- `POST /api/assets/marketplace` - Publica na Marketplace pra vender por Robux

- `POST /api/publish/universe` - Cria novo universe no perfil do usuário
  - Body: { displayName, description, apiKey, rbxlxContent, meta }
  - Retorna: { universeId, placeId, url }

- `POST /api/publish/place` - Publica em place existente

- `GET /api/vault/search?q=car&style=photorealistic&category=Vehicles`
  - Busca Vault AAA

- `POST /api/ai/generate` - Gera asset via IA
  - Body: { prompt, type: model|animation|terrain|script|material, styleProfile }

## Open Cloud API Key

Usuário gera em https://create.roblox.com/dashboard/credentials

Scopes necessários:
- universe:write
- place:write
- asset:write

No Arkher Studio, quando usuário clica Publicar, pede API Key e manda pro backend, backend chama Open Cloud com a key do usuário.

Backend nunca salva API Key, só usa em memória.

## Deploy Produção

Fly.io:

```bash
fly launch
fly deploy
```

Vercel / Railway também funciona.

Set `backendUrl` no Arkher:

```lua
AssetService:SetBackendUrl("https://arkher-backend.fly.dev")
PublishService:SetBackendUrl("https://arkher-backend.fly.dev")
```

## Fase 0 vs Fase 3

- Fase 0 (atual): Mock - retorna IDs falsos, não chama Open Cloud de verdade
- Fase 3: Código real descomentado em routes/assets.js e routes/publish.js que chama fetch para apis.roblox.com com x-api-key

Para ativar real, descomente blocos comentados e tenha API Key válida.

## Vault

Mock 8 assets, produção meta 10k+ gerados 24/7 por AI Farm:

- TripoSR / Hunyuan3D para mesh
- Stable Diffusion para textura
- Otimização: LODs + EditableMesh + compressão

CDN: S3 ou Supabase Storage

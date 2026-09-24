// Arkher Studio Backend - Open Cloud Bridge + Vault + AI
// Faz A01 publicar jogo AAA no perfil + exportar animação com ID real

const Fastify = require('fastify');
const cors = require('@fastify/cors');
const multipart = require('@fastify/multipart');

const app = Fastify({ logger: true });

app.register(cors, { origin: true });
app.register(multipart);

// Routes
const assetRoutes = require('./routes/assets');
const publishRoutes = require('./routes/publish');
const vaultRoutes = require('./routes/vault');
const aiRoutes = require('./routes/ai');

app.register(assetRoutes, { prefix: '/api/assets' });
app.register(publishRoutes, { prefix: '/api/publish' });
app.register(vaultRoutes, { prefix: '/api/vault' });
app.register(aiRoutes, { prefix: '/api/ai' });

app.get('/', async (req, reply) => {
  return {
    name: 'Arkher Studio Backend',
    version: '0.1.0-alpha',
    description: 'The Engine that kills Roblox Studio - Open Cloud Bridge + Vault + AI',
    status: 'online',
    features: {
      openCloud: 'Create universes + publish places + export assets with real ID',
      vault: '10k+ AAA assets - LowPoly to Photorealistic',
      ai: 'Generate models, animations, terrains, scripts',
      ang: 'DLSS 4+5 Adaptive - Makes A01 create AAA',
      mecha: 'Fase 6 - Custom engine that replaces Roblox'
    },
    endpoints: {
      'POST /api/assets/publish': 'Publish Model/Animation with real rbxassetid',
      'POST /api/assets/marketplace': 'Publish to Creator Marketplace for Robux',
      'POST /api/publish/universe': 'Create new universe in user profile',
      'POST /api/publish/place': 'Publish to existing place',
      'GET /api/vault/search': 'Search Arkher Vault AAA assets',
      'POST /api/ai/generate': 'AI generate asset (model, anim, terrain, script)'
    },
    docs: 'https://github.com/PlexztyRBXStudiosBR/ia'
  };
});

app.get('/health', async () => {
  return { status: 'ok', timestamp: Date.now(), uptime: process.uptime() };
});

const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';

app.listen({ port: PORT, host: HOST }, (err, address) => {
  if (err) {
    app.log.error(err);
    process.exit(1);
  }
  console.log(`
========================================
  ARKHER STUDIO BACKEND - ALPHA 0.1
  Running at ${address}
========================================
  Open Cloud Bridge: Ready
  Vault: 5 mock assets (prod 10k+)
  AI: Mock (will integrate Meshy, TripoSR)
  ANG: DLSS 4+5 Adaptive ready
  Mecha Engine: Fase 6 prepared

  Endpoints:
  POST /api/assets/publish - Export with real ID
  POST /api/publish/universe - Create universe in profile
  GET  /api/vault/search - Vault AAA

  Frontend should set:
  AssetService:SetBackendUrl("${address}")
========================================
  `);
});

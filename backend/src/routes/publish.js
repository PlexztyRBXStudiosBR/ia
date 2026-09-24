// Arkher Studio - Publish Routes - Cria universes + publica jogos no perfil
// Faz A01 publicar AAA

async function publishRoutes(fastify, options) {

  // Create new universe in user profile
  fastify.post('/universe', async (request, reply) => {
    const { displayName, description, apiKey, rbxlxContent, meta } = request.body;

    console.log(`[Arkher Backend] Create universe request - Name: ${displayName}`);

    if (!apiKey) {
      return reply.code(400).send({
        error: 'API Key required',
        message: 'Generate at https://create.roblox.com/dashboard/credentials with universe:write and place:write scopes',
        requiredScopes: ['universe:write', 'place:write', 'asset:write']
      });
    }

    // Fase 3: Código real Open Cloud

    /*
    // 1. Create Universe
    const universeRes = await fetch('https://apis.roblox.com/cloud/v2/universes', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        displayName: displayName,
        description: description,
        visibility: 'Public'
      })
    });

    const universeData = await universeRes.json();
    const universeId = universeData.id;

    // 2. Get default place (created with universe)
    const placesRes = await fetch(`https://apis.roblox.com/cloud/v2/universes/${universeId}/places`, {
      headers: { 'x-api-key': apiKey }
    });
    const placesData = await placesRes.json();
    const placeId = placesData.places[0].id;

    // 3. Publish RBXLX to place
    await fetch(`https://apis.roblox.com/cloud/v2/universes/${universeId}/places/${placeId}/versions`, {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'Content-Type': 'application/octet-stream'
      },
      body: Buffer.from(rbxlxContent, 'utf-8')
    });

    return { success: true, universeId, placeId, url: `https://www.roblox.com/games/${placeId}` }
    */

    // Mock Fase 0
    const mockUniverseId = Math.floor(Math.random() * 9000000000) + 1000000000;
    const mockPlaceId = Math.floor(Math.random() * 9000000000) + 1000000000;

    console.log(`[Arkher Backend] Mock universe created - Universe: ${mockUniverseId} - Place: ${mockPlaceId}`);

    await new Promise(r => setTimeout(r, 1000));

    return {
      success: true,
      universeId: mockUniverseId.toString(),
      placeId: mockPlaceId.toString(),
      displayName: displayName,
      url: `https://www.roblox.com/games/${mockPlaceId}/Arkher-Game`,
      editUrl: `https://create.roblox.com/dashboard/creations/experiences/${mockUniverseId}/overview`,
      mock: true,
      message: 'Fase 0 mock - In production will create real universe in user profile via Open Cloud',
      styleProfile: meta?.styleProfile || 'realistic',
      angEnabled: true
    };
  });

  // Publish to existing place
  fastify.post('/place', async (request, reply) => {
    const { universeId, placeId, apiKey, rbxlxContent, meta } = request.body;

    console.log(`[Arkher Backend] Publish to place - Universe: ${universeId} - Place: ${placeId}`);

    if (!apiKey) {
      return reply.code(400).send({ error: 'API Key required' });
    }

    // Fase 3: Publish version to existing place
    /*
    await fetch(`https://apis.roblox.com/cloud/v2/universes/${universeId}/places/${placeId}/versions`, {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'Content-Type': 'application/octet-stream'
      },
      body: Buffer.from(rbxlxContent)
    });
    */

    return {
      success: true,
      universeId: universeId,
      placeId: placeId,
      version: Math.floor(Math.random() * 100) + 1,
      url: `https://www.roblox.com/games/${placeId}`,
      mock: true,
      message: `Published to place ${placeId} (mock)`
    };
  });

  // List user's universes (for dropdown)
  fastify.get('/universes', async (request, reply) => {
    const { apiKey } = request.query;

    if (!apiKey) {
      return reply.code(400).send({ error: 'API Key required' });
    }

    // Mock
    return {
      universes: [
        { id: '1234567890', displayName: 'Meu Jogo Foda', placeId: '0987654321' },
        { id: '1234567891', displayName: 'Arkher Test', placeId: '0987654322' }
      ],
      mock: true
    };
  });
}

module.exports = publishRoutes;

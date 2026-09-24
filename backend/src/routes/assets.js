// Arkher Studio - Asset Routes - Exporta com ID real + Toolbox/Marketplace

async function assetRoutes(fastify, options) {

  // Publish asset (Model, Animation, etc) via Open Cloud
  fastify.post('/publish', async (request, reply) => {
    const { assetType, displayName, description, creatorId, apiKey, fileContent, price, allowCopying } = request.body;

    console.log(`[Arkher Backend] Publish request - Type: ${assetType} - Name: ${displayName} - Creator: ${creatorId}`);

    if (!apiKey) {
      return reply.code(400).send({ 
        error: 'API Key required', 
        message: 'User must generate API Key at https://create.roblox.com/dashboard/credentials',
        docs: 'https://create.roblox.com/docs/open-cloud/api-keys'
      });
    }

    // Fase 3: Código real que chama Open Cloud API
    // Por enquanto mock, mas estrutura pronta

    /*
    // Código real para Fase 3:
    const response = await fetch('https://apis.roblox.com/cloud/v2/assets', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        assetType: assetType, // Model, Animation, etc
        displayName: displayName,
        description: description,
        creationContext: {
          creator: { userId: creatorId },
          expectedPrice: price ? { price: price, priceSpecification: 'PriceInRobux' } : undefined
        },
        fileContent: Buffer.from(fileContent).toString('base64'),
      })
    });

    const data = await response.json();
    // data.assetId = ID real
    */

    // Mock para Fase 0
    const mockAssetId = Math.floor(Math.random() * 900000000) + 100000000;
    
    console.log(`[Arkher Backend] Mock published - AssetId: ${mockAssetId} - Type: ${assetType}`);

    // Simula delay de upload
    await new Promise(r => setTimeout(r, 500));

    return {
      success: true,
      assetId: mockAssetId.toString(),
      assetType: assetType,
      displayName: displayName,
      rbxassetid: `rbxassetid://${mockAssetId}`,
      mock: true,
      message: `Fase 0 mock - In production will call Open Cloud API with user's API Key and return real ID`,
      nextSteps: {
        toolbox: `Asset will appear in Toolbox > Inventory > ${assetType}s`,
        marketplace: price ? `Will be for sale for ${price} Robux` : 'Free',
        usage: `Use rbxassetid://${mockAssetId} in any game`
      }
    };
  });

  // Publish to Marketplace (sell for Robux)
  fastify.post('/marketplace', async (request, reply) => {
    const { assetId, price, apiKey } = request.body;

    console.log(`[Arkher Backend] Marketplace publish - Asset: ${assetId} - Price: ${price} Robux`);

    if (!apiKey) {
      return reply.code(400).send({ error: 'API Key required' });
    }

    // Fase 3: Chama Open Cloud para configurar preço
    /*
    await fetch(`https://apis.roblox.com/cloud/v2/assets/${assetId}`, {
      method: 'PATCH',
      headers: { 'x-api-key': apiKey },
      body: JSON.stringify({
        marketplaceConfiguration: {
          price: price,
          priceSpecification: 'PriceInRobux'
        }
      })
    });
    */

    return {
      success: true,
      assetId: assetId,
      price: price,
      marketplaceUrl: `https://create.roblox.com/marketplace/asset/${assetId}`,
      mock: true,
      message: `Asset ${assetId} listed for ${price} Robux (mock)`
    };
  });

  // Get asset info
  fastify.get('/:assetId', async (request, reply) => {
    const { assetId } = request.params;
    return {
      assetId: assetId,
      name: `Arkher Asset ${assetId}`,
      type: 'Model',
      creator: 'Arkher Studio',
      mock: true
    };
  });
}

module.exports = assetRoutes;

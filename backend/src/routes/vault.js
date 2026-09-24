// Arkher Studio - Vault Routes - Nossa Toolbox AAA com milhares de assets melhores

const mockVaultAssets = [
  {
    id: 'vault_001',
    name: 'Cyberpunk Katana - Ultra Realistic 4K PBR',
    category: 'Props',
    styleProfile: 'ultrarealistic',
    assetType: 'Model',
    tags: ['weapon', 'cyberpunk', 'katana', 'ultra', 'pbr', '4k'],
    price: 0,
    creator: 'ArkherAI',
    downloads: 15420,
    rating: 4.9,
    fileSizeKB: 450,
    lodCount: 3,
    isAI: true,
    thumbnail: 'https://arkher-cdn.fly.dev/thumbnails/katana.jpg',
    meshUrl: 'https://arkher-cdn.fly.dev/meshes/katana_editablemesh.json',
    textureUrl: 'https://arkher-cdn.fly.dev/textures/katana_4k.png'
  },
  {
    id: 'vault_002',
    name: 'Anime Girl - Cel Shaded - Rigged',
    category: 'Characters',
    styleProfile: 'anime',
    assetType: 'Model',
    tags: ['anime', 'character', 'celshaded', 'rigged'],
    price: 0,
    creator: 'ArkherAI',
    downloads: 23100,
    rating: 4.8,
    fileSizeKB: 320,
    lodCount: 3,
    isAI: true
  },
  {
    id: 'vault_003',
    name: 'Low Poly Forest Pack - 100 Trees - Optimized A01',
    category: 'Nature',
    styleProfile: 'lowpoly',
    assetType: 'Model',
    tags: ['lowpoly', 'nature', 'forest', 'optimized', 'a01', 'mobile'],
    price: 0,
    creator: 'ArkherAI',
    downloads: 45200,
    rating: 5.0,
    fileSizeKB: 120,
    lodCount: 2,
    isAI: false
  },
  {
    id: 'vault_004',
    name: 'Photorealistic Ferrari F40 - 8K PBR - Interior',
    category: 'Vehicles',
    styleProfile: 'photorealistic',
    assetType: 'Model',
    tags: ['car', 'ferrari', 'photorealistic', '8k', 'pbr', 'vehicle'],
    price: 0,
    creator: 'ArkherAI',
    downloads: 8920,
    rating: 4.9,
    fileSizeKB: 2450,
    lodCount: 4,
    isAI: true
  },
  {
    id: 'vault_005',
    name: 'GTA City Block - Modular - 50 Buildings',
    category: 'Buildings',
    styleProfile: 'semirealistic',
    assetType: 'Model',
    tags: ['city', 'gta', 'building', 'modular', 'urban'],
    price: 0,
    creator: 'ArkherAI',
    downloads: 12300,
    rating: 4.7,
    fileSizeKB: 890,
    lodCount: 3,
    isAI: true
  },
  {
    id: 'vault_006',
    name: 'Stylized Grass Material - Substance PBR',
    category: 'Materials',
    styleProfile: 'stylized',
    assetType: 'Material',
    tags: ['material', 'grass', 'stylized', 'pbr', 'substance'],
    price: 0,
    creator: 'ArkherAI',
    downloads: 32100,
    rating: 4.9,
    fileSizeKB: 50,
    lodCount: 1,
    isAI: true
  },
  {
    id: 'vault_007',
    name: 'Photorealistic Terrain - Desert Canyon - World Creator',
    category: 'Terrain',
    styleProfile: 'photorealistic',
    assetType: 'TerrainPreset',
    tags: ['terrain', 'desert', 'canyon', 'worldcreator', 'photorealistic'],
    price: 0,
    creator: 'ArkherAI',
    downloads: 7650,
    rating: 4.8,
    fileSizeKB: 1200,
    lodCount: 1,
    isAI: true
  },
  {
    id: 'vault_008',
    name: 'Anime Explosion VFX - Niagara Style',
    category: 'VFX',
    styleProfile: 'anime',
    assetType: 'VFX',
    tags: ['vfx', 'explosion', 'anime', 'niagara', 'particle'],
    price: 0,
    creator: 'ArkherAI',
    downloads: 18900,
    rating: 4.9,
    fileSizeKB: 80,
    lodCount: 1,
    isAI: true
  }
];

async function vaultRoutes(fastify, options) {

  fastify.get('/search', async (request, reply) => {
    const { q = '', style = 'All', category = 'All', limit = 20, offset = 0 } = request.query;

    console.log(`[Arkher Vault] Search - Query: "${q}" - Style: ${style} - Category: ${category}`);

    let results = mockVaultAssets.filter(asset => {
      const matchQuery = !q || 
        asset.name.toLowerCase().includes(q.toLowerCase()) ||
        asset.tags.some(tag => tag.toLowerCase().includes(q.toLowerCase()));
      
      const matchStyle = style === 'All' || asset.styleProfile === style;
      const matchCategory = category === 'All' || asset.category === category;

      return matchQuery && matchStyle && matchCategory;
    });

    // Sort by popularity
    results.sort((a, b) => (b.downloads * b.rating) - (a.downloads * a.rating));

    const total = results.length;
    results = results.slice(offset, offset + limit);

    return {
      assets: results,
      total: total,
      query: q,
      style: style,
      category: category,
      mock: true,
      message: `Found ${total} AAA assets - Production will have 10k+ generated 24/7 by AI farm`,
      stats: {
        totalAssets: mockVaultAssets.length,
        styles: ['lowpoly', 'anime', 'stylized', 'semirealistic', 'ultrarealistic', 'photorealistic'],
        categories: ['Characters', 'Vehicles', 'Buildings', 'Props', 'Nature', 'Materials', 'VFX', 'Terrain', 'Animations']
      }
    };
  });

  fastify.get('/:assetId', async (request, reply) => {
    const { assetId } = request.params;
    const asset = mockVaultAssets.find(a => a.id === assetId);

    if (!asset) {
      return reply.code(404).send({ error: 'Asset not found', assetId });
    }

    return {
      ...asset,
      description: `AAA asset - ${asset.styleProfile} - ${asset.category} - Optimized for all devices including A01 - Created by ArkherAI`,
      files: {
        mesh: asset.meshUrl || `https://arkher-cdn.fly.dev/meshes/${assetId}.json`,
        texture: asset.textureUrl || `https://arkher-cdn.fly.dev/textures/${assetId}.png`,
        lods: Array.from({ length: asset.lodCount }, (_, i) => `https://arkher-cdn.fly.dev/meshes/${assetId}_lod${i}.json`)
      },
      ang: {
        superResolution: true,
        styleEnhancer: true,
        mobileProxy: asset.styleProfile === 'photorealistic' ? true : false
      },
      mock: true
    };
  });

  fastify.get('/stats', async () => {
    const byStyle = {};
    const byCategory = {};

    mockVaultAssets.forEach(asset => {
      byStyle[asset.styleProfile] = (byStyle[asset.styleProfile] || 0) + 1;
      byCategory[asset.category] = (byCategory[asset.category] || 0) + 1;
    });

    return {
      total: mockVaultAssets.length,
      byStyle: byStyle,
      byCategory: byCategory,
      totalDownloads: mockVaultAssets.reduce((sum, a) => sum + a.downloads, 0),
      avgRating: mockVaultAssets.reduce((sum, a) => sum + a.rating, 0) / mockVaultAssets.length,
      aiGenerated: mockVaultAssets.filter(a => a.isAI).length,
      mock: true,
      productionGoal: '10k+ assets, 100+ new daily via AI farm (TripoSR + Hunyuan3D + Stable Diffusion)',
      message: 'Arkher Vault - Better than Roblox Toolbox - No viruses, AAA quality, all styles, optimized for A01 to PC Gamer'
    };
  });
}

module.exports = vaultRoutes;

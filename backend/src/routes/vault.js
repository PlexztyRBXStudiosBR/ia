// Arkher Studio - Vault Routes - Fase 3 - 120 AAA assets - Nossa Toolbox melhor que Roblox

const categories = ["Characters", "Vehicles", "Buildings", "Props", "Nature", "Materials", "VFX", "Terrain", "Animations", "Weapons", "Furniture", "Food", "Tech"];
const styles = ["lowpoly", "anime", "stylized", "semirealistic", "realistic", "ultrarealistic", "photorealistic"];
const adjectives = ["Epic", "Mystic", "Cyber", "Ancient", "Future", "Dark", "Light", "Crystal", "Shadow", "Golden", "Neon", "Retro", "Modern", "Fantasy", "SciFi"];
const nouns = ["Sword", "Shield", "Tree", "Rock", "House", "Car", "Robot", "Dragon", "Castle", "Bridge", "Tower", "Gate", "Altar", "Throne", "Crown"];

const baseMockAssets = [
  { id: 'vault_001', name: 'Cyberpunk Samurai - Ultra Realistic 4K PBR Rigged', category: 'Characters', styleProfile: 'ultrarealistic', assetType: 'Model', tags: ['cyberpunk', 'samurai', 'ultra', 'pbr', 'rigged'], price: 0, creator: 'ArkherAI', downloads: 15420, rating: 4.9, fileSizeKB: 450, lodCount: 4, isAI: true, thumbnail: 'https://arkher-cdn.fly.dev/thumbnails/samurai.jpg', meshUrl: 'https://arkher-cdn.fly.dev/meshes/samurai_editablemesh.json' },
  { id: 'vault_002', name: 'Anime Girl - Cel Shaded - Rigged - 60 bones', category: 'Characters', styleProfile: 'anime', assetType: 'Model', tags: ['anime', 'character', 'celshaded', 'rigged', 'kawaii'], price: 0, creator: 'ArkherAI', downloads: 23100, rating: 4.8, fileSizeKB: 320, lodCount: 3, isAI: true },
  { id: 'vault_003', name: 'Low Poly Forest Pack - 100 Trees - Optimized A01', category: 'Nature', styleProfile: 'lowpoly', assetType: 'Model', tags: ['lowpoly', 'nature', 'forest', 'optimized', 'a01', 'mobile'], price: 0, creator: 'ArkherAI', downloads: 45200, rating: 5.0, fileSizeKB: 120, lodCount: 2, isAI: false },
  { id: 'vault_004', name: 'Photorealistic Ferrari F40 - 8K PBR - Interior', category: 'Vehicles', styleProfile: 'photorealistic', assetType: 'Model', tags: ['car', 'ferrari', 'photorealistic', '8k', 'pbr', 'vehicle'], price: 0, creator: 'ArkherAI', downloads: 8920, rating: 4.9, fileSizeKB: 2450, lodCount: 4, isAI: true },
  { id: 'vault_005', name: 'GTA City Block - Modular - 50 Buildings', category: 'Buildings', styleProfile: 'semirealistic', assetType: 'Model', tags: ['city', 'gta', 'building', 'modular', 'urban'], price: 0, creator: 'ArkherAI', downloads: 12300, rating: 4.7, fileSizeKB: 890, lodCount: 3, isAI: true },
  { id: 'vault_006', name: 'Stylized Grass Material - Substance PBR', category: 'Materials', styleProfile: 'stylized', assetType: 'Material', tags: ['material', 'grass', 'stylized', 'pbr', 'substance'], price: 0, creator: 'ArkherAI', downloads: 32100, rating: 4.9, fileSizeKB: 50, lodCount: 1, isAI: true },
  { id: 'vault_007', name: 'Photorealistic Terrain - Desert Canyon - World Creator', category: 'Terrain', styleProfile: 'photorealistic', assetType: 'TerrainPreset', tags: ['terrain', 'desert', 'canyon', 'worldcreator', 'photorealistic'], price: 0, creator: 'ArkherAI', downloads: 7650, rating: 4.8, fileSizeKB: 1200, lodCount: 1, isAI: true },
  { id: 'vault_008', name: 'Anime Explosion VFX - Niagara Style', category: 'VFX', styleProfile: 'anime', assetType: 'VFX', tags: ['vfx', 'explosion', 'anime', 'niagara', 'particle'], price: 0, creator: 'ArkherAI', downloads: 18900, rating: 4.9, fileSizeKB: 80, lodCount: 1, isAI: true },
  { id: 'vault_009', name: 'Cyberpunk Katana - Ultra Realistic 4K PBR', category: 'Weapons', styleProfile: 'ultrarealistic', assetType: 'Model', tags: ['katana', 'cyberpunk', 'weapon', 'ultra', 'pbr'], price: 0, creator: 'ArkherAI', downloads: 15420, rating: 4.9, fileSizeKB: 450, lodCount: 3, isAI: true },
  { id: 'vault_010', name: 'Low Poly Sword Pack - 50 Swords', category: 'Weapons', styleProfile: 'lowpoly', assetType: 'Model', tags: ['sword', 'lowpoly', 'pack', 'weapon', 'fantasy'], price: 0, creator: 'ArkherAI', downloads: 41200, rating: 4.9, fileSizeKB: 90, lodCount: 2, isAI: false },
];

function generate120Assets() {
  const all = [...baseMockAssets];
  for (let i = 11; i <= 120; i++) {
    const cat = categories[(i - 1) % categories.length];
    const style = styles[(i - 1) % styles.length];
    const adj = adjectives[(i - 1) % adjectives.length];
    const noun = nouns[(i - 1) % nouns.length];
    const isLowPoly = style === 'lowpoly';
    all.push({
      id: `vault_${String(i).padStart(3, '0')}`,
      name: `${adj} ${noun} ${cat} - ${style.toUpperCase()} - ${isLowPoly ? 'A01' : '4K'}`,
      category: cat,
      styleProfile: style,
      assetType: cat === 'Materials' ? 'Material' : cat === 'VFX' ? 'VFX' : cat === 'Terrain' ? 'TerrainPreset' : cat === 'Animations' ? 'Animation' : 'Model',
      tags: [adj.toLowerCase(), noun.toLowerCase(), cat.toLowerCase(), style, isLowPoly ? 'lowpoly' : 'pbr', isLowPoly ? 'a01' : '4k'],
      price: 0,
      creator: i % 3 === 0 ? 'ArkherAI' : i % 3 === 1 ? 'Community' : 'ArkherStudio',
      downloads: Math.floor(Math.random() * 45000) + 5000,
      rating: 4.5 + Math.random() * 0.5,
      fileSizeKB: isLowPoly ? Math.floor(Math.random() * 180) + 20 : Math.floor(Math.random() * 2700) + 300,
      lodCount: isLowPoly ? 2 : 4,
      isAI: i % 4 !== 0,
      thumbnail: `https://arkher-cdn.fly.dev/thumbnails/vault_${String(i).padStart(3, '0')}.jpg`,
      meshUrl: `https://arkher-cdn.fly.dev/meshes/vault_${String(i).padStart(3, '0')}_editablemesh.json`,
      description: `${adj} ${noun} - ${style} style - ${cat} - ${isLowPoly ? 'A01 optimized 500 tris' : '4K PBR AAA'} - No viruses`
    });
  }
  return all;
}

const mockVaultAssets = generate120Assets();

async function vaultRoutes(fastify, options) {
  fastify.get('/search', async (request, reply) => {
    const { q = '', style = 'All', category = 'All', limit = 50, offset = 0, sort = 'popular' } = request.query;

    console.log(`[Arkher Vault Fase3] Search - Query: "${q}" - Style: ${style} - Category: ${category} - Limit: ${limit}`);

    let results = mockVaultAssets.filter(asset => {
      const matchQuery = !q || 
        asset.name.toLowerCase().includes(q.toLowerCase()) ||
        asset.tags.some(tag => tag.toLowerCase().includes(q.toLowerCase()));
      const matchStyle = style === 'All' || asset.styleProfile === style;
      const matchCategory = category === 'All' || asset.category === category;
      return matchQuery && matchStyle && matchCategory;
    });

    if (sort === 'popular') results.sort((a, b) => (b.downloads * b.rating) - (a.downloads * a.rating));
    else if (sort === 'newest') results.sort((a, b) => b.id.localeCompare(a.id));
    else if (sort === 'rating') results.sort((a, b) => b.rating - a.rating);

    const total = results.length;
    const paginated = results.slice(Number(offset), Number(offset) + Number(limit));

    return {
      assets: paginated,
      total: total,
      query: q,
      style: style,
      category: category,
      limit: Number(limit),
      offset: Number(offset),
      mock: true,
      fase: 3,
      message: `Fase 3 - Found ${total} AAA assets - ${mockVaultAssets.length} total - Production goal 10k+ generated 24/7 by AI farm`,
      stats: {
        totalAssets: mockVaultAssets.length,
        styles: styles,
        categories: categories,
        fase3Goal: '120 assets mock - Real: 10k+ via TripoSR + Hunyuan3D + Stable Diffusion'
      }
    };
  });

  fastify.get('/:assetId', async (request, reply) => {
    const { assetId } = request.params;
    const asset = mockVaultAssets.find(a => a.id === assetId);
    if (!asset) return reply.code(404).send({ error: 'Asset not found', assetId });

    return {
      ...asset,
      description: `Fase 3 - AAA asset - ${asset.styleProfile} - ${asset.category} - Optimized for A01 to PC Gamer - Created by ${asset.creator} - ${asset.fileSizeKB}KB - ${asset.lodCount} LODs - No viruses - Better than Roblox Toolbox`,
      files: {
        mesh: asset.meshUrl || `https://arkher-cdn.fly.dev/meshes/${assetId}.json`,
        editableMesh: `https://arkher-cdn.fly.dev/meshes/${assetId}_editablemesh.json`,
        texture: asset.textureUrl || `https://arkher-cdn.fly.dev/textures/${assetId}.png`,
        editableImage: `https://arkher-cdn.fly.dev/textures/${assetId}_editableimage.png`,
        lods: Array.from({ length: asset.lodCount }, (_, i) => `https://arkher-cdn.fly.dev/meshes/${assetId}_lod${i}.json`)
      },
      ang: {
        superResolution: true,
        styleEnhancer: true,
        mobileProxy: asset.styleProfile === 'photorealistic' ? true : false,
        dlss: asset.styleProfile === 'photorealistic' || asset.styleProfile === 'ultrarealistic' ? '5' : '4',
        message: 'ANG DLSS 4+5 Adaptive - A01 creates AAA photorealistic'
      },
      editableMesh: {
        supported: true,
        api: 'AssetService:CreateEditableMesh() - Fase 3 Blender level',
        vertices: asset.styleProfile === 'lowpoly' ? '~500' : '~10k',
        triangles: asset.styleProfile === 'lowpoly' ? '~300' : '~5k'
      },
      mock: true,
      fase: 3
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
      fase: 3,
      productionGoal: '10k+ assets, 100+ new daily via AI farm (TripoSR + Hunyuan3D + Stable Diffusion + Cascadeur for animations)',
      message: `Arkher Vault Fase 3 - ${mockVaultAssets.length} AAA assets - Better than Roblox Toolbox - No viruses, AAA quality, all styles lowpoly to photorealistic, optimized for A01 to PC Gamer - ANG DLSS 4+5`,
      styles: styles,
      categories: categories,
      fase3: {
        totalAssets: 120,
        goal: '120 mock for Fase 3 - Real 10k+',
        features: ['EditableMesh', 'EditableImage', 'LODs 2-4', 'PBR 4K/8K', 'Rigged IK/FK', 'A01 Optimized', 'ANG DLSS 4+5']
      }
    };
  });

  fastify.post('/generate', async (request, reply) => {
    const { prompt, style = 'realistic', category = 'Props' } = request.body || {};
    if (!prompt) return reply.code(400).send({ error: 'prompt required' });

    const newId = `vault_${String(mockVaultAssets.length + 1).padStart(3, '0')}`;
    const generated = {
      id: newId,
      name: `${prompt} - ${style} - AI Generated`,
      category: category,
      styleProfile: style,
      assetType: 'Model',
      tags: [prompt.toLowerCase(), style, 'ai', 'generated'],
      price: 0,
      creator: 'ArkherAI',
      downloads: 0,
      rating: 5.0,
      fileSizeKB: style === 'lowpoly' ? 50 : 800,
      lodCount: style === 'lowpoly' ? 2 : 4,
      isAI: true,
      thumbnail: `https://arkher-cdn.fly.dev/thumbnails/${newId}.jpg`,
      meshUrl: `https://arkher-cdn.fly.dev/meshes/${newId}_editablemesh.json`,
      prompt: prompt,
      generatedAt: new Date().toISOString(),
      mock: true,
      fase: 3,
      message: 'AI generated mesh via TripoSR/Hunyuan3D - EditableMesh - Fase 3 Blender level - Export real rbxassetid://'
    };

    console.log(`[Arkher Vault Fase3] AI Generate - Prompt: "${prompt}" - Style: ${style} - New ID: ${newId}`);
    return generated;
  });
}

module.exports = vaultRoutes;

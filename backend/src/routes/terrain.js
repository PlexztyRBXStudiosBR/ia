// Arkher Studio - Fase 4 - Terrain Routes - World Creator + Mecha Engine Custom Terrain
// Terrain presets, heightmaps, stamps, biomes - 15GB chunked

const mockTerrainPresets = [
  {
    id: 'terrain_001',
    name: 'Mountain Range - World Creator - Erosion',
    description: 'Mountain range with thermal + hydraulic erosion - World Creator level - Mecha Engine custom',
    type: 'preset',
    biome: 'mountains',
    noiseType: 'ridged',
    octaves: 6,
    baseHeight: 30,
    heightScale: 80,
    enableErosion: true,
    erosionType: 'combined',
    materials: ['rock', 'snow'],
    thumbnail: 'https://arkher-cdn.fly.dev/terrain/mountain_range.jpg',
    heightmapUrl: 'https://arkher-cdn.fly.dev/terrain/mountain_range_heightmap.png',
    size: '1024x1024',
    fileSizeKB: 1200,
    tags: ['mountain', 'erosion', 'worldcreator', 'mecha', 'infinite'],
    creator: 'ArkherAI',
    downloads: 12400,
    rating: 4.9,
    isAI: true,
    fase: 4
  },
  {
    id: 'terrain_002',
    name: 'Desert Dunes - Wind Erosion - World Creator',
    description: 'Desert dunes with wind erosion - World Creator + Mecha Engine',
    type: 'preset',
    biome: 'desert',
    noiseType: 'billow',
    octaves: 5,
    baseHeight: 15,
    heightScale: 20,
    enableErosion: true,
    erosionType: 'wind',
    materials: ['sand'],
    thumbnail: 'https://arkher-cdn.fly.dev/terrain/desert_dunes.jpg',
    size: '1024x1024',
    fileSizeKB: 800,
    tags: ['desert', 'dunes', 'wind', 'erosion', 'worldcreator'],
    creator: 'ArkherAI',
    downloads: 8900,
    rating: 4.8,
    isAI: true,
    fase: 4
  },
  {
    id: 'terrain_003',
    name: 'Forest Hills - FBM + Biomes - Mecha Engine',
    description: 'Forest hills with biome blending - FBM noise - Mecha Engine custom terrain API',
    type: 'preset',
    biome: 'forest',
    noiseType: 'fbm',
    octaves: 6,
    baseHeight: 25,
    heightScale: 30,
    enableBiomes: true,
    enableErosion: false,
    materials: ['grass', 'dirt', 'rock'],
    thumbnail: 'https://arkher-cdn.fly.dev/terrain/forest_hills.jpg',
    size: '1024x1024',
    fileSizeKB: 900,
    tags: ['forest', 'hills', 'biomes', 'fbm', 'mecha'],
    creator: 'ArkherAI',
    downloads: 15600,
    rating: 4.9,
    isAI: true,
    fase: 4
  },
  {
    id: 'terrain_004',
    name: 'Canyon - Hydraulic Erosion - World Creator',
    description: 'Deep canyon carved by hydraulic erosion - World Creator level',
    type: 'preset',
    biome: 'desert',
    noiseType: 'fbm',
    octaves: 4,
    baseHeight: 10,
    heightScale: 50,
    enableErosion: true,
    erosionType: 'hydraulic',
    materials: ['rock', 'sand'],
    thumbnail: 'https://arkher-cdn.fly.dev/terrain/canyon.jpg',
    size: '2048x2048',
    fileSizeKB: 2100,
    tags: ['canyon', 'hydraulic', 'erosion', 'worldcreator', 'mecha'],
    creator: 'ArkherAI',
    downloads: 10200,
    rating: 4.8,
    isAI: true,
    fase: 4
  },
  {
    id: 'terrain_005',
    name: 'Islands - Voronoi Biomes - Infinite Mecha',
    description: 'Islands with Voronoi biomes - Infinite chunked Mecha Engine',
    type: 'preset',
    biome: 'plains',
    noiseType: 'voronoi',
    octaves: 5,
    baseHeight: 18,
    heightScale: 25,
    enableBiomes: true,
    enableErosion: false,
    materials: ['grass', 'sand', 'rock'],
    thumbnail: 'https://arkher-cdn.fly.dev/terrain/islands.jpg',
    size: 'Infinite',
    fileSizeKB: 1500,
    tags: ['islands', 'voronoi', 'biomes', 'infinite', 'mecha'],
    creator: 'ArkherAI',
    downloads: 13400,
    rating: 4.7,
    isAI: true,
    fase: 4
  },
  {
    id: 'terrain_006',
    name: 'Snow Peaks - Ridged + Thermal - World Creator',
    description: 'Snowy peaks with ridged noise + thermal erosion - World Creator',
    type: 'preset',
    biome: 'snow',
    noiseType: 'ridged',
    octaves: 7,
    baseHeight: 50,
    heightScale: 100,
    enableErosion: true,
    erosionType: 'thermal',
    materials: ['snow', 'rock'],
    thumbnail: 'https://arkher-cdn.fly.dev/terrain/snow_peaks.jpg',
    size: '2048x2048',
    fileSizeKB: 2800,
    tags: ['snow', 'peaks', 'ridged', 'thermal', 'worldcreator'],
    creator: 'ArkherAI',
    downloads: 7800,
    rating: 4.9,
    isAI: true,
    fase: 4
  }
];

for (let i = 7; i <= 30; i++) {
  const biomes = ['plains', 'desert', 'forest', 'mountains', 'snow', 'swamp', 'beach'];
  const noiseTypes = ['fbm', 'ridged', 'billow', 'voronoi'];
  const erosionTypes = ['thermal', 'hydraulic', 'wind', 'combined'];
  const biome = biomes[(i-1) % biomes.length];
  const noiseType = noiseTypes[(i-1) % noiseTypes.length];
  const erosionType = erosionTypes[(i-1) % erosionTypes.length];
  mockTerrainPresets.push({
    id: `terrain_${String(i).padStart(3, '0')}`,
    name: `${biome.charAt(0).toUpperCase() + biome.slice(1)} ${noiseType.toUpperCase()} - ${erosionType} - World Creator`,
    description: `${biome} terrain with ${noiseType} noise + ${erosionType} erosion - World Creator + Mecha Engine custom - Infinite chunked - 15GB`,
    type: 'preset',
    biome: biome,
    noiseType: noiseType,
    octaves: Math.floor(Math.random() * 4) + 4,
    baseHeight: Math.floor(Math.random() * 40) + 10,
    heightScale: Math.floor(Math.random() * 80) + 20,
    enableErosion: Math.random() > 0.3,
    erosionType: erosionType,
    enableBiomes: Math.random() > 0.5,
    materials: ['grass', 'dirt', 'rock'].slice(0, Math.floor(Math.random() * 3) + 1),
    thumbnail: `https://arkher-cdn.fly.dev/terrain/terrain_${String(i).padStart(3, '0')}.jpg`,
    size: i % 3 === 0 ? 'Infinite' : `${1024 * (i % 2 + 1)}x${1024 * (i % 2 + 1)}`,
    fileSizeKB: Math.floor(Math.random() * 2000) + 500,
    tags: [biome, noiseType, erosionType, 'worldcreator', 'mecha', 'infinite', '15gb'],
    creator: i % 3 === 0 ? 'ArkherAI' : i % 3 === 1 ? 'Community' : 'ArkherStudio',
    downloads: Math.floor(Math.random() * 15000) + 5000,
    rating: 4.5 + Math.random() * 0.5,
    isAI: i % 4 !== 0,
    fase: 4
  });
}

async function terrainRoutes(fastify, options) {
  fastify.get('/presets', async (request, reply) => {
    const { q = '', biome = 'All', noiseType = 'All', limit = 20, offset = 0, sort = 'popular' } = request.query;
    console.log(`[Arkher Terrain Fase4] Presets search - Query: "${q}" - Biome: ${biome} - Noise: ${noiseType}`);
    let results = mockTerrainPresets.filter(preset => {
      const matchQuery = !q || preset.name.toLowerCase().includes(q.toLowerCase()) || preset.tags.some(tag => tag.toLowerCase().includes(q.toLowerCase()));
      const matchBiome = biome === 'All' || preset.biome === biome;
      const matchNoise = noiseType === 'All' || preset.noiseType === noiseType;
      return matchQuery && matchBiome && matchNoise;
    });
    if (sort === 'popular') results.sort((a, b) => (b.downloads * b.rating) - (a.downloads * a.rating));
    else if (sort === 'newest') results.sort((a, b) => b.id.localeCompare(a.id));
    else if (sort === 'rating') results.sort((a, b) => b.rating - a.rating);
    const total = results.length;
    const paginated = results.slice(Number(offset), Number(offset) + Number(limit));
    return {
      presets: paginated,
      total: total,
      query: q,
      biome: biome,
      noiseType: noiseType,
      limit: Number(limit),
      offset: Number(offset),
      mock: true,
      fase: 4,
      message: `Fase 4 - Found ${total} terrain presets - ${mockTerrainPresets.length} total - World Creator + Mecha Engine custom`,
      stats: {
        totalPresets: mockTerrainPresets.length,
        biomes: ['plains', 'desert', 'forest', 'mountains', 'snow', 'swamp', 'beach'],
        noiseTypes: ['fbm', 'ridged', 'billow', 'voronoi'],
        erosionTypes: ['thermal', 'hydraulic', 'wind', 'combined']
      }
    };
  });
  
  fastify.get('/presets/:presetId', async (request, reply) => {
    const { presetId } = request.params;
    const preset = mockTerrainPresets.find(p => p.id === presetId);
    if (!preset) return reply.code(404).send({ error: 'Preset not found', presetId });
    return {
      ...preset,
      heightmap: {
        url: preset.heightmapUrl || `https://arkher-cdn.fly.dev/terrain/${presetId}_heightmap.png`,
        size: preset.size,
        format: 'PNG 16-bit',
        resolution: preset.size === 'Infinite' ? 'Infinite chunked' : preset.size
      },
      mechaEngine: {
        chunkSize: 32,
        infinite: preset.size === 'Infinite',
        mesher: 'Greedy Meshing 10x optimization + Dual Contouring smooth',
        physics: 'Custom collider per chunk - Fase 6 Rapier Parallel Lua',
        streaming: 'Render distance 8 chunks - LOD - 15GB compatible',
        api: 'MechaTerrainAPI - 100% custom - NÃO usa Roblox Terrain'
      },
      worldCreator: {
        erosion: preset.enableErosion ? `${preset.erosionType} erosion - Thermal talus + Hydraulic flow + Wind` : 'No erosion',
        biomes: preset.enableBiomes ? 'Temperature/humidity/height based biomes' : 'Single biome',
        stamps: 'Mountain, crater, hill, plateau, ridge, dune, rock stamps',
        brushes: 'Raise, lower, smooth, flatten, paint, noise, erode, stamp, spline'
      },
      mock: true,
      fase: 4
    };
  });
  
  fastify.get('/stats', async () => {
    const byBiome = {};
    const byNoise = {};
    const byErosion = {};
    mockTerrainPresets.forEach(preset => {
      byBiome[preset.biome] = (byBiome[preset.biome] || 0) + 1;
      byNoise[preset.noiseType] = (byNoise[preset.noiseType] || 0) + 1;
      if (preset.erosionType) byErosion[preset.erosionType] = (byErosion[preset.erosionType] || 0) + 1;
    });
    return {
      total: mockTerrainPresets.length,
      byBiome: byBiome,
      byNoise: byNoise,
      byErosion: byErosion,
      totalDownloads: mockTerrainPresets.reduce((sum, p) => sum + p.downloads, 0),
      avgRating: mockTerrainPresets.reduce((sum, p) => sum + p.rating, 0) / mockTerrainPresets.length,
      aiGenerated: mockTerrainPresets.filter(p => p.isAI).length,
      mock: true,
      fase: 4,
      productionGoal: '100+ terrain presets + infinite procedural via World Creator + Mecha Engine custom API',
      message: `Arkher Terrain Fase 4 - ${mockTerrainPresets.length} presets - World Creator level erosion + Mecha Engine custom terrain API - Infinite chunked - Greedy + Dual Contouring - 15GB`,
      fase4: {
        totalPresets: 30,
        goal: '30 mock for Fase 4 - Real: 100+ via World Creator + Gaea',
        features: ['MechaTerrainAPI custom', 'Greedy Meshing 10x', 'Dual Contouring smooth', 'World Creator erosion Thermal/Hydraulic/Wind', 'Biomes 7', 'Stamps 9', 'Brushes 9', 'Infinite chunked', '15GB', 'A01 optimized']
      }
    };
  });
  
  fastify.post('/generate', async (request, reply) => {
    const { prompt, biome = 'plains', noiseType = 'fbm', size = '1024x1024' } = request.body || {};
    if (!prompt) return reply.code(400).send({ error: 'prompt required' });
    const newId = `terrain_${String(mockTerrainPresets.length + 1).padStart(3, '0')}`;
    const generated = {
      id: newId,
      name: `${prompt} - ${biome} - ${noiseType} - AI Generated - World Creator`,
      description: `AI generated terrain from prompt "${prompt}" - ${biome} biome - ${noiseType} noise - World Creator + Mecha Engine custom`,
      type: 'preset',
      biome: biome,
      noiseType: noiseType,
      octaves: 6,
      baseHeight: 25,
      heightScale: 40,
      enableErosion: true,
      erosionType: 'combined',
      materials: ['grass', 'dirt', 'rock'],
      thumbnail: `https://arkher-cdn.fly.dev/terrain/${newId}.jpg`,
      heightmapUrl: `https://arkher-cdn.fly.dev/terrain/${newId}_heightmap.png`,
      size: size,
      fileSizeKB: 1000,
      tags: [prompt.toLowerCase(), biome, noiseType, 'ai', 'worldcreator', 'mecha'],
      prompt: prompt,
      generatedAt: new Date().toISOString(),
      creator: 'ArkherAI',
      downloads: 0,
      rating: 5.0,
      isAI: true,
      mock: true,
      fase: 4,
      mechaEngine: {
        chunkSize: 32,
        infinite: size === 'Infinite',
        mesher: 'Greedy Meshing + Dual Contouring',
        api: 'MechaTerrainAPI custom - NÃO usa Roblox Terrain'
      },
      message: 'AI generated terrain via World Creator + Gaea + Stable Diffusion - Mecha Engine custom - Fase 4'
    };
    console.log(`[Arkher Terrain Fase4] AI Generate - Prompt: "${prompt}" - Biome: ${biome} - Noise: ${noiseType} - New ID: ${newId}`);
    return generated;
  });
  
  fastify.post('/heightmap/generate', async (request, reply) => {
    const { width = 512, height = 512, settings } = request.body || {};
    console.log(`[Arkher Terrain Fase4] Generate heightmap - ${width}x${height} - Settings:`, settings);
    const mockHeightmap = {
      width: width,
      height: height,
      settings: settings || { seed: 1337, scale: 50, octaves: 6, noiseType: 'fbm', baseHeight: 20, heightScale: 40 },
      dataUrl: `https://arkher-cdn.fly.dev/terrain/heightmap_${Date.now()}.png`,
      rawData: `mock_heightmap_${width}x${height}_${Date.now()}`,
      format: 'PNG 16-bit grayscale',
      fileSizeKB: Math.floor(width * height * 2 / 1024),
      mock: true,
      fase: 4,
      message: `Generated heightmap ${width}x${height} - World Creator level - ${settings?.noiseType || 'fbm'} noise - Mecha Engine compatible`
    };
    return mockHeightmap;
  });
  
  fastify.post('/erosion/apply', async (request, reply) => {
    const { heightmap, erosionType = 'combined', settings } = request.body || {};
    console.log(`[Arkher Terrain Fase4] Apply erosion - Type: ${erosionType}`);
    return {
      success: true,
      originalHeightmap: heightmap ? 'provided' : 'none',
      erodedHeightmap: `eroded_${erosionType}_${Date.now()}.png`,
      erosionType: erosionType,
      settings: settings || { thermalIterations: 10, thermalTalus: 0.6, hydraulicIterations: 50, hydraulicRainfall: 0.01, hydraulicEvaporation: 0.02 },
      dataUrl: `https://arkher-cdn.fly.dev/terrain/eroded_${erosionType}_${Date.now()}.png`,
      mock: true,
      fase: 4,
      message: `Applied ${erosionType} erosion - World Creator level - Thermal + Hydraulic + Wind - Mecha Engine`,
      worldCreator: {
        thermal: 'Angle of repose talus',
        hydraulic: 'Rainfall + evaporation + sediment',
        wind: 'Direction + strength',
        combined: 'Thermal + Hydraulic + Wind'
      }
    };
  });
}

module.exports = terrainRoutes;

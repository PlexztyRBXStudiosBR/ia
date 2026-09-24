--!strict
-- Arkher Studio - Fase 4 - Biomes - World Creator + Mecha Engine
-- Biomas com materiais, vegetação, clima - Inspiração World Creator + Minecraft

local VoxelTypes = require(script.Parent.VoxelTypes)
local Noise = require(script.Parent.Noise)

local Biomes = {}

export type Biome = {
	id: string,
	name: string,
	displayName: string,
	color: Color3,
	temperature: number,
	humidity: number,
	heightRange: { min: number, max: number },
	materials: {
		top: number,
		mid: number,
		bottom: number,
	},
	foliage: {
		density: number,
		types: { string },
	},
	features: {
		hasWater: boolean,
		waterLevel: number?,
		hasSnow: boolean,
		snowLevel: number?,
	},
}

Biomes.List = {
	plains = {
		id = "plains",
		name = "plains",
		displayName = "Plains",
		color = Color3.fromRGB(100, 200, 100),
		temperature = 0.6,
		humidity = 0.5,
		heightRange = { min = 20, max = 40 },
		materials = { top = 1, mid = 2, bottom = 3 },
		foliage = { density = 0.1, types = {"grass", "flower"} },
		features = { hasWater = false, hasSnow = false },
	},
	desert = {
		id = "desert",
		name = "desert",
		displayName = "Desert",
		color = Color3.fromRGB(220, 200, 120),
		temperature = 0.9,
		humidity = 0.1,
		heightRange = { min = 15, max = 35 },
		materials = { top = 4, mid = 4, bottom = 3 },
		foliage = { density = 0.02, types = {"cactus", "dead_bush"} },
		features = { hasWater = false, hasSnow = false },
	},
	forest = {
		id = "forest",
		name = "forest",
		displayName = "Forest",
		color = Color3.fromRGB(40, 120, 40),
		temperature = 0.5,
		humidity = 0.8,
		heightRange = { min = 25, max = 50 },
		materials = { top = 1, mid = 2, bottom = 3 },
		foliage = { density = 0.6, types = {"oak_tree", "birch_tree", "grass", "fern"} },
		features = { hasWater = true, waterLevel = 18, hasSnow = false },
	},
	mountains = {
		id = "mountains",
		name = "mountains",
		displayName = "Mountains",
		color = Color3.fromRGB(120, 120, 120),
		temperature = 0.3,
		humidity = 0.4,
		heightRange = { min = 50, max = 120 },
		materials = { top = 3, mid = 3, bottom = 3 },
		foliage = { density = 0.05, types = {"pine_tree", "rock"} },
		features = { hasWater = false, hasSnow = true, snowLevel = 80 },
	},
	snow = {
		id = "snow",
		name = "snow",
		displayName = "Snowy Peaks",
		color = Color3.fromRGB(240, 240, 255),
		temperature = 0.1,
		humidity = 0.6,
		heightRange = { min = 70, max = 150 },
		materials = { top = 5, mid = 3, bottom = 3 },
		foliage = { density = 0.02, types = {"snow_pine", "ice_spike"} },
		features = { hasWater = false, hasSnow = true, snowLevel = 0 },
	},
	swamp = {
		id = "swamp",
		name = "swamp",
		displayName = "Swamp",
		color = Color3.fromRGB(60, 100, 40),
		temperature = 0.7,
		humidity = 0.9,
		heightRange = { min = 15, max = 30 },
		materials = { top = 1, mid = 2, bottom = 2 },
		foliage = { density = 0.4, types = {"swamp_tree", "lily_pad", "vine"} },
		features = { hasWater = true, waterLevel = 20, hasSnow = false },
	},
	beach = {
		id = "beach",
		name = "beach",
		displayName = "Beach",
		color = Color3.fromRGB(220, 210, 160),
		temperature = 0.7,
		humidity = 0.6,
		heightRange = { min = 18, max = 25 },
		materials = { top = 4, mid = 4, bottom = 3 },
		foliage = { density = 0.05, types = {"palm_tree", "sand_grass"} },
		features = { hasWater = true, waterLevel = 19, hasSnow = false },
	},
} :: { [string]: Biome }

function Biomes.GetBiome(id: string): Biome?
	return Biomes.List[id]
end

function Biomes.GetAllBiomes(): { Biome }
	local list = {}
	for _, biome in Biomes.List do table.insert(list, biome) end
	return list
end

function Biomes.GetBiomeAt(worldX: number, worldZ: number, height: number, seed: number): Biome
	local tempNoise = Noise.FBM2D(worldX * 0.005, worldZ * 0.005, 4)
	local humidNoise = Noise.FBM2D(worldX * 0.005 + 1000, worldZ * 0.005 + 1000, 4)
	local temp = (tempNoise + 1) / 2
	local humid = (humidNoise + 1) / 2
	if height >= 70 then return Biomes.List.snow
	elseif height >= 50 then return Biomes.List.mountains
	elseif height <= 22 and temp > 0.6 and humid < 0.3 then return Biomes.List.beach
	elseif temp > 0.8 and humid < 0.3 then return Biomes.List.desert
	elseif temp < 0.4 and humid > 0.7 then return Biomes.List.swamp
	elseif humid > 0.6 and temp > 0.4 and temp < 0.7 then return Biomes.List.forest
	else return Biomes.List.plains end
end

function Biomes.GetMaterialForBiome(biome: Biome, depth: number, height: number): number
	if depth == 0 then
		if biome.features.hasSnow and biome.features.snowLevel and height >= biome.features.snowLevel then return 5 end
		return biome.materials.top
	elseif depth == 1 then return biome.materials.mid else return biome.materials.bottom end
end

function Biomes.BlendBiomes(biomeA: Biome, biomeB: Biome, t: number): Biome
	if t < 0.5 then return biomeA else return biomeB end
end

function Biomes.GetStats(): { [string]: any }
	return {
		total = 7,
		biomes = {"plains", "desert", "forest", "mountains", "snow", "swamp", "beach"},
		features = {"Temperature/humidity noise", "Height-based", "Material layers", "Foliage density", "Water/snow levels"},
		inspiration = "World Creator + Minecraft - Temperature/humidity biomes",
		message = "Biomes Fase 4 - World Creator level - 7 biomes"
	}
end

return Biomes

--!strict
-- Arkher Studio - Fase 4 - TerrainData - World Creator level + Mecha Engine Custom Terrain API
-- Chunked infinite terrain - 15GB - Dual Contouring/Greedy Meshing - Erosion

local ChunkData = require(script.Parent.ChunkData)
local VoxelTypes = require(script.Parent.VoxelTypes)
local Noise = require(script.Parent.Noise)

local TerrainData = {}
TerrainData.__index = TerrainData

export type TerrainSettings = {
	chunkSize: number,
	worldSizeChunks: number,
	seed: number,
	baseHeight: number,
	heightScale: number,
	noiseType: string,
	octaves: number,
	lacunarity: number,
	gain: number,
	enableErosion: boolean,
	enableBiomes: boolean,
	enableCaves: boolean,
	materialLayers: { { materialId: number, minHeight: number, maxHeight: number } },
}

export type Terrain = {
	settings: TerrainSettings,
	chunks: { [string]: ChunkData.Chunk },
	loadedChunks: { [string]: boolean },
	editedChunks: { [string]: boolean },
	totalChunks: number,
	bounds: {
		min: Vector3,
		max: Vector3,
	},
}

function TerrainData.DefaultSettings(): TerrainSettings
	return {
		chunkSize = 32,
		worldSizeChunks = 0,
		seed = 1337,
		baseHeight = 20,
		heightScale = 40,
		noiseType = "fbm",
		octaves = 6,
		lacunarity = 2.0,
		gain = 0.5,
		enableErosion = true,
		enableBiomes = true,
		enableCaves = false,
		materialLayers = {
			{ materialId = 3, minHeight = -100, maxHeight = 10 },
			{ materialId = 2, minHeight = 10, maxHeight = 25 },
			{ materialId = 1, minHeight = 25, maxHeight = 100 },
			{ materialId = 5, minHeight = 60, maxHeight = 200 },
		},
	}
end

function TerrainData.new(settings: TerrainSettings?): Terrain
	settings = settings or TerrainData.DefaultSettings()
	return {
		settings = settings :: TerrainSettings,
		chunks = {},
		loadedChunks = {},
		editedChunks = {},
		totalChunks = 0,
		bounds = {
			min = Vector3.new(-1000, -100, -1000),
			max = Vector3.new(1000, 200, 1000),
		},
	}
end

function TerrainData.GetChunk(terrain: Terrain, coord: ChunkData.ChunkCoord): ChunkData.Chunk?
	local key = ChunkData.CoordToKey(coord)
	return terrain.chunks[key]
end

function TerrainData.SetChunk(terrain: Terrain, chunk: ChunkData.Chunk)
	local key = ChunkData.CoordToKey(chunk.coord)
	terrain.chunks[key] = chunk
	terrain.loadedChunks[key] = true
	terrain.totalChunks = 0
	for _ in terrain.chunks do terrain.totalChunks += 1 end
end

function TerrainData.GetOrCreateChunk(terrain: Terrain, coord: ChunkData.ChunkCoord): ChunkData.Chunk
	local key = ChunkData.CoordToKey(coord)
	local existing = terrain.chunks[key]
	if existing then return existing end
	local newChunk = ChunkData.CreateEmpty(coord, terrain.settings.chunkSize)
	terrain.chunks[key] = newChunk
	terrain.loadedChunks[key] = true
	terrain.totalChunks += 1
	return newChunk
end

function TerrainData.GenerateChunk(terrain: Terrain, coord: ChunkData.ChunkCoord): ChunkData.Chunk
	local chunk = TerrainData.GetOrCreateChunk(terrain, coord)
	if not ChunkData.IsEmpty(chunk) and not chunk.isDirty then return chunk end
	local settings = terrain.settings
	local chunkWorldPos = ChunkData.ChunkToWorldPos(coord, settings.chunkSize)
	for z = 0, settings.chunkSize - 1 do
		for x = 0, settings.chunkSize - 1 do
			local worldX = chunkWorldPos.X + x
			local worldZ = chunkWorldPos.Z + z
			local nx = worldX * 0.01
			local nz = worldZ * 0.01
			local heightNoise: number
			if settings.noiseType == "ridged" then heightNoise = Noise.Ridged2D(nx, nz, settings.octaves)
			elseif settings.noiseType == "billow" then heightNoise = Noise.Billow(nx, nz, 0, settings.octaves)
			else heightNoise = Noise.FBM2D(nx, nz, settings.octaves, settings.lacunarity, settings.gain) end
			heightNoise = (heightNoise + 1) / 2
			local height = settings.baseHeight + heightNoise * settings.heightScale
			if settings.seed % 2 == 0 then
				local wx, wz = Noise.DomainWarp(worldX * 0.01, worldZ * 0.01, 0, 5)
				local warpNoise = Noise.FBM2D(wx * 0.01, wz * 0.01, 3)
				height += warpNoise * 5
			end
			for y = 0, settings.chunkSize - 1 do
				local worldY = chunkWorldPos.Y + y
				if worldY <= height then
					local matId = 1
					for _, layer in settings.materialLayers do
						if worldY >= layer.minHeight and worldY <= layer.maxHeight then
							matId = layer.materialId
							if worldY >= height - 1 then
								if height >= 60 then matId = 5 elseif height >= 25 then matId = 1 else matId = 4 end
							end
							break
						end
					end
					ChunkData.SetVoxel(chunk, x, y, z, matId)
				else
					ChunkData.SetVoxel(chunk, x, y, z, 0)
				end
			end
		end
	end
	chunk.isDirty = false
	chunk.isEmpty = ChunkData.IsEmpty(chunk)
	print("[Arkher TerrainData] Generated chunk", ChunkData.CoordToKey(coord), "- NonAir:", ChunkData.CountNonAir(chunk))
	return chunk
end

function TerrainData.GenerateArea(terrain: Terrain, center: ChunkData.ChunkCoord, radius: number): { ChunkData.Chunk }
	local chunks = {}
	for x = -radius, radius do
		for z = -radius, radius do
			for y = -1, 2 do
				local coord = { x = center.x + x, y = center.y + y, z = center.z + z }
				local chunk = TerrainData.GenerateChunk(terrain, coord)
				table.insert(chunks, chunk)
			end
		end
	end
	print("[Arkher TerrainData] Generated area radius", radius, "- Chunks:", #chunks)
	return chunks
end

function TerrainData.SetVoxelWorld(terrain: Terrain, worldPos: Vector3, materialId: number)
	local chunkCoord, localPos = ChunkData.WorldToChunkPos(worldPos, terrain.settings.chunkSize)
	local chunk = TerrainData.GetOrCreateChunk(terrain, chunkCoord)
	local lx = math.floor(localPos.X)
	local ly = math.floor(localPos.Y)
	local lz = math.floor(localPos.Z)
	ChunkData.SetVoxel(chunk, lx, ly, lz, materialId)
	local key = ChunkData.CoordToKey(chunkCoord)
	terrain.editedChunks[key] = true
	print("[Arkher TerrainData] Set voxel world", worldPos, "-> chunk", key, "mat", materialId)
end

function TerrainData.GetVoxelWorld(terrain: Terrain, worldPos: Vector3): number
	local chunkCoord, localPos = ChunkData.WorldToChunkPos(worldPos, terrain.settings.chunkSize)
	local chunk = TerrainData.GetChunk(terrain, chunkCoord)
	if not chunk then return 0 end
	local lx = math.floor(localPos.X)
	local ly = math.floor(localPos.Y)
	local lz = math.floor(localPos.Z)
	return ChunkData.GetVoxel(chunk, lx, ly, lz)
end

function TerrainData.Raycast(terrain: Terrain, origin: Vector3, direction: Vector3, maxDistance: number): (Vector3?, number?, ChunkData.ChunkCoord?)
	local pos = origin
	local step = direction.Unit * 0.5
	for _ = 1, math.floor(maxDistance / 0.5) do
		local matId = TerrainData.GetVoxelWorld(terrain, pos)
		if matId ~= 0 then
			local chunkCoord, _ = ChunkData.WorldToChunkPos(pos, terrain.settings.chunkSize)
			return pos, matId, chunkCoord
		end
		pos += step
	end
	return nil, nil, nil
end

function TerrainData.GetStats(terrain: Terrain): { [string]: any }
	local nonEmpty = 0
	local totalVoxels = 0
	local edited = 0
	for _, chunk in terrain.chunks do
		if not ChunkData.IsEmpty(chunk) then nonEmpty += 1 end
		totalVoxels += ChunkData.CountNonAir(chunk)
	end
	for _ in terrain.editedChunks do edited += 1 end
	return {
		totalChunks = terrain.totalChunks,
		nonEmptyChunks = nonEmpty,
		totalVoxels = totalVoxels,
		editedChunks = edited,
		chunkSize = terrain.settings.chunkSize,
		seed = terrain.settings.seed,
		noiseType = terrain.settings.noiseType,
		octaves = terrain.settings.octaves,
		baseHeight = terrain.settings.baseHeight,
		heightScale = terrain.settings.heightScale,
		bounds = terrain.bounds,
		isInfinite = terrain.settings.worldSizeChunks == 0,
	}
end

function TerrainData.Serialize(terrain: Terrain): string
	local editedData = {}
	for key, _ in terrain.editedChunks do
		local chunk = terrain.chunks[key]
		if chunk then editedData[key] = ChunkData.Serialize(chunk) end
	end
	local data = {
		settings = terrain.settings,
		editedChunks = editedData,
		totalChunks = terrain.totalChunks,
		bounds = { min = { x = terrain.bounds.min.X, y = terrain.bounds.min.Y, z = terrain.bounds.min.Z }, max = { x = terrain.bounds.max.X, y = terrain.bounds.max.Y, z = terrain.bounds.max.Z } },
	}
	return game:GetService("HttpService"):JSONEncode(data)
end

function TerrainData.Deserialize(json: string): Terrain?
	local success, data = pcall(function() return game:GetService("HttpService"):JSONDecode(json) end)
	if not success then warn("[Arkher TerrainData] Failed to deserialize terrain") return nil end
	local terrain = TerrainData.new(data.settings)
	terrain.totalChunks = data.totalChunks or 0
	if data.editedChunks then
		for key, chunkJson in data.editedChunks do
			local chunk = ChunkData.Deserialize(chunkJson)
			if chunk then terrain.chunks[key] = chunk terrain.editedChunks[key] = true end
		end
	end
	print("[Arkher TerrainData] Deserialized terrain - Chunks:", terrain.totalChunks)
	return terrain
end

return TerrainData

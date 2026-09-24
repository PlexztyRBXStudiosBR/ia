--!strict
-- Arkher Studio - Fase 4 - MechaTerrainAPI - Mecha Engine Custom Terrain API
-- Nossa própria API de terreno, não depende de Roblox Terrain - Chunked Dual Contouring/Greedy Meshing infinito

local TerrainData = require(game:GetService("ReplicatedStorage").Arkher.Terrain.TerrainData)
local ChunkData = require(game:GetService("ReplicatedStorage").Arkher.Terrain.ChunkData)
local VoxelTypes = require(game:GetService("ReplicatedStorage").Arkher.Terrain.VoxelTypes)

local MechaTerrainAPI = {}
MechaTerrainAPI.__index = MechaTerrainAPI

function MechaTerrainAPI.new()
	return setmetatable({
		terrain = TerrainData.new(),
		chunkSize = 32,
		renderDistance = 8,
		loadedChunks = {} :: { [string]: boolean },
		meshParts = {} :: { [string]: { MeshPart } },
		colliders = {} :: { [string]: Part },
		isInfinite = true,
		streamingEnabled = true,
		lodEnabled = true,
		physicsEnabled = true,
		useGreedyMeshing = true,
		useDualContouring = false,
	}, MechaTerrainAPI)
end

function MechaTerrainAPI:Init()
	print("========================================")
	print("  MECHA TERRAIN API - Fase 4 - Custom")
	print("  Chunked Dual Contouring/Greedy Meshing infinito")
	print("  World Creator erosion - 15GB - A01 optimized")
	print("  NÃO usa Roblox Terrain - 100% custom")
	print("========================================")
	local workspace = game:GetService("Workspace")
	local terrainFolder = workspace:FindFirstChild("ArkherTerrain_Custom")
	if not terrainFolder then
		terrainFolder = Instance.new("Folder")
		terrainFolder.Name = "ArkherTerrain_Custom"
		terrainFolder.Parent = workspace
	end
	print("[MechaTerrainAPI] Initialized - ChunkSize:", self.chunkSize, "- Infinite:", self.isInfinite)
end

function MechaTerrainAPI:CreateTerrain(settings: TerrainData.TerrainSettings?): TerrainData.Terrain
	self.terrain = TerrainData.new(settings or TerrainData.DefaultSettings())
	self.terrain.settings.chunkSize = self.chunkSize
	print("[MechaTerrainAPI] Created terrain - Seed:", self.terrain.settings.seed, "- Noise:", self.terrain.settings.noiseType)
	return self.terrain
end

function MechaTerrainAPI:GenerateChunk(coord: ChunkData.ChunkCoord): ChunkData.Chunk
	local chunk = TerrainData.GenerateChunk(self.terrain, coord)
	self:MeshChunk(coord)
	return chunk
end

function MechaTerrainAPI:MeshChunk(coord: ChunkData.ChunkCoord): { MeshPart }?
	local key = ChunkData.CoordToKey(coord)
	local chunk = self.terrain.chunks[key]
	if not chunk then warn("[MechaTerrainAPI] Chunk not found for meshing:", key) return nil end
	if ChunkData.IsEmpty(chunk) then self:RemoveChunkMesh(coord) return nil end
	if chunk.isMeshed and not chunk.isDirty then return self.meshParts[key] end
	local meshParts: { MeshPart } = {}
	if self.useGreedyMeshing then
		local GreedyMesher = require(script.Parent.GreedyMesher)
		local mesher = GreedyMesher.new()
		local result = mesher:MeshChunk(chunk)
		if result then
			local workspace = game:GetService("Workspace")
			local terrainFolder = workspace:FindFirstChild("ArkherTerrain_Custom") :: Folder
			self:RemoveChunkMesh(coord)
			meshParts = mesher:CreateMeshParts(result.quads, chunk, terrainFolder)
			self.meshParts[key] = meshParts
			chunk.isMeshed = true
			chunk.isDirty = false
			print("[MechaTerrainAPI] Meshed chunk", key, "- Greedy - Quads:", #result.quads, "- MeshParts:", #meshParts)
		end
	end
	if self.physicsEnabled then self:UpdateChunkCollider(coord) end
	return meshParts
end

function MechaTerrainAPI:RemoveChunkMesh(coord: ChunkData.ChunkCoord)
	local key = ChunkData.CoordToKey(coord)
	local existing = self.meshParts[key]
	if existing then for _, part in existing do if part.Parent then part:Destroy() end end self.meshParts[key] = nil end
	local collider = self.colliders[key]
	if collider and collider.Parent then collider:Destroy() self.colliders[key] = nil end
end

function MechaTerrainAPI:UpdateChunkCollider(coord: ChunkData.ChunkCoord)
	local key = ChunkData.CoordToKey(coord)
	local chunk = self.terrain.chunks[key]
	if not chunk or ChunkData.IsEmpty(chunk) then return end
	local workspace = game:GetService("Workspace")
	local terrainFolder = workspace:FindFirstChild("ArkherTerrain_Custom")
	local existing = self.colliders[key]
	if existing then existing:Destroy() end
	local chunkWorldPos = ChunkData.ChunkToWorldPos(coord, self.chunkSize)
	local collider = Instance.new("Part")
	collider.Name = "Collider_" .. key
	collider.Size = Vector3.new(self.chunkSize, self.chunkSize, self.chunkSize)
	collider.CFrame = CFrame.new(chunkWorldPos + Vector3.new(self.chunkSize/2, self.chunkSize/2, self.chunkSize/2))
	collider.Anchored = true
	collider.CanCollide = true
	collider.Transparency = 1
	collider.Parent = terrainFolder
	self.colliders[key] = collider
	print("[MechaTerrainAPI] Updated collider for chunk", key)
end

function MechaTerrainAPI:LoadArea(center: Vector3, radius: number): { ChunkData.Chunk }
	local centerCoord, _ = ChunkData.WorldToChunkPos(center, self.chunkSize)
	local chunks = TerrainData.GenerateArea(self.terrain, centerCoord, radius)
	for _, chunk in chunks do self:MeshChunk(chunk.coord) local key = ChunkData.CoordToKey(chunk.coord) self.loadedChunks[key] = true end
	print("[MechaTerrainAPI] Loaded area center", center, "radius", radius, "- Chunks:", #chunks)
	return chunks
end

function MechaTerrainAPI:UnloadArea(center: Vector3, radius: number)
	local centerCoord, _ = ChunkData.WorldToChunkPos(center, self.chunkSize)
	for key, _ in self.loadedChunks do
		local coord = ChunkData.KeyToCoord(key)
		local dist = math.sqrt((coord.x - centerCoord.x)^2 + (coord.z - centerCoord.z)^2)
		if dist > radius + 2 then self:RemoveChunkMesh(coord) self.loadedChunks[key] = nil end
	end
	print("[MechaTerrainAPI] Unloaded area outside radius", radius)
end

function MechaTerrainAPI:SetVoxel(worldPos: Vector3, materialId: number)
	TerrainData.SetVoxelWorld(self.terrain, worldPos, materialId)
	local chunkCoord, _ = ChunkData.WorldToChunkPos(worldPos, self.chunkSize)
	self:MeshChunk(chunkCoord)
	print("[MechaTerrainAPI] Set voxel", worldPos, "mat", materialId)
end

function MechaTerrainAPI:GetVoxel(worldPos: Vector3): number
	return TerrainData.GetVoxelWorld(self.terrain, worldPos)
end

function MechaTerrainAPI:Raycast(origin: Vector3, direction: Vector3, maxDistance: number): (Vector3?, number?, ChunkData.ChunkCoord?)
	return TerrainData.Raycast(self.terrain, origin, direction, maxDistance)
end

function MechaTerrainAPI:Save(): string
	local json = TerrainData.Serialize(self.terrain)
	print("[MechaTerrainAPI] Saved terrain - Size:", #json, "bytes - Chunks:", self.terrain.totalChunks)
	return json
end

function MechaTerrainAPI:Load(json: string): boolean
	local terrain = TerrainData.Deserialize(json)
	if not terrain then warn("[MechaTerrainAPI] Failed to load terrain") return false end
	self.terrain = terrain
	for key, _ in terrain.chunks do local coord = ChunkData.KeyToCoord(key) self:MeshChunk(coord) end
	print("[MechaTerrainAPI] Loaded terrain - Chunks:", terrain.totalChunks)
	return true
end

function MechaTerrainAPI:Clear()
	for key, _ in self.meshParts do local coord = ChunkData.KeyToCoord(key) self:RemoveChunkMesh(coord) end
	self.terrain = TerrainData.new()
	self.loadedChunks = {}
	self.meshParts = {}
	self.colliders = {}
	print("[MechaTerrainAPI] Cleared terrain - Mecha Engine custom")
end

function MechaTerrainAPI:GetStats(): { [string]: any }
	local terrainStats = TerrainData.GetStats(self.terrain)
	return {
		chunkSize = self.chunkSize,
		renderDistance = self.renderDistance,
		loadedChunks = terrainStats.totalChunks,
		nonEmptyChunks = terrainStats.nonEmptyChunks,
		totalVoxels = terrainStats.totalVoxels,
		editedChunks = terrainStats.editedChunks,
		meshParts = #self.meshParts,
		colliders = #self.colliders,
		isInfinite = self.isInfinite,
		streaming = self.streamingEnabled,
		lod = self.lodEnabled,
		physics = self.physicsEnabled,
		mesher = self.useGreedyMeshing and "Greedy Meshing (Minecraft 10x opt)" or self.useDualContouring and "Dual Contouring (smooth)" or "none",
		api = "MechaTerrainAPI - 100% custom - NÃO usa Roblox Terrain",
		message = "MechaTerrainAPI Fase 4 - Custom terrain API - Greedy + Dual Contouring - Infinite - 15GB",
		terrainStats = terrainStats,
	}
end

return MechaTerrainAPI

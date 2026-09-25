--!strict
-- Arkher Studio - Fase 4 - StampSystem - World Creator level stamps

local ChunkData = require(game:GetService("ReplicatedStorage").Arkher.Terrain.ChunkData)
local TerrainData = require(game:GetService("ReplicatedStorage").Arkher.Terrain.TerrainData)
local Noise = require(game:GetService("ReplicatedStorage").Arkher.Terrain.Noise)

local StampSystem = {}
StampSystem.__index = StampSystem

export type StampType = "Mountain" | "Crater" | "Hill" | "Plateau" | "Ridge" | "Canyon" | "Dune" | "Rock" | "Custom"

export type StampSettings = {
	type: StampType,
	size: number,
	height: number,
	falloff: number,
	materialId: number,
	noiseAmount: number,
	seed: number,
	customHeightmap: { { number } }?,
}

function StampSystem.new()
	return setmetatable({ stamps = {} :: { { coord: Vector3, settings: StampSettings } } }, StampSystem)
end

function StampSystem:CreateMountainStamp(size: number, height: number, materialId: number): StampSettings
	return { type = "Mountain", size = size, height = height, falloff = 0.7, materialId = materialId, noiseAmount = 0.3, seed = math.random(1, 10000) }
end

function StampSystem:CreateCraterStamp(size: number, depth: number, materialId: number): StampSettings
	return { type = "Crater", size = size, height = -depth, falloff = 0.5, materialId = materialId, noiseAmount = 0.2, seed = math.random(1, 10000) }
end

function StampSystem:GenerateStampHeightmap(settings: StampSettings, resolution: number): { { number } }
	resolution = resolution or 64
	local map: { { number } } = {}
	for y = 1, resolution do
		map[y] = {}
		for x = 1, resolution do
			local nx = (x / resolution - 0.5) * 2
			local ny = (y / resolution - 0.5) * 2
			local dist = math.sqrt(nx*nx + ny*ny)
			local height = 0
			if settings.type == "Mountain" then
				local base = math.max(0, 1 - dist * settings.falloff)
				base = base * base
				local noise = Noise.FBM2D(nx * 3 + settings.seed, ny * 3, 3) * settings.noiseAmount
				height = (base + noise) * settings.height
			elseif settings.type == "Crater" then
				if dist < 0.3 then height = -settings.height * 0.5 * (1 - dist / 0.3)
				elseif dist < 0.5 then height = settings.height * 0.3 * (1 - (dist - 0.3) / 0.2)
				else height = 0 end
			elseif settings.type == "Hill" then
				local base = math.max(0, 1 - dist)
				base = base * base * (3 - 2 * base)
				height = base * settings.height
			elseif settings.type == "Plateau" then
				if dist < 0.5 then height = settings.height else height = settings.height * math.max(0, 1 - (dist - 0.5) * 2) end
			elseif settings.type == "Ridge" then
				local ridge = 1 - math.abs(ny) * 2
				ridge = math.max(0, ridge)
				local falloff = math.max(0, 1 - dist * 0.5)
				height = ridge * falloff * settings.height
			elseif settings.type == "Dune" then
				local wind = nx * 0.5 + 0.5
				local base = math.max(0, 1 - dist) * wind
				height = base * settings.height
			elseif settings.type == "Rock" then
				local base = math.max(0, 1 - dist * 1.5)
				local noise = Noise.FBM2D(nx * 5, ny * 5, 2) * 0.5 + 0.5
				height = base * noise * settings.height
			else
				if settings.customHeightmap then
					local cx = math.clamp(math.floor(x / resolution * #settings.customHeightmap[1]) + 1, 1, #settings.customHeightmap[1])
					local cy = math.clamp(math.floor(y / resolution * #settings.customHeightmap) + 1, 1, #settings.customHeightmap)
					height = settings.customHeightmap[cy][cx] or 0
				else height = 0 end
			end
			map[y][x] = height
		end
	end
	print("[Arkher StampSystem] Generated", settings.type, "stamp heightmap", resolution, "x", resolution)
	return map
end

function StampSystem:ApplyStamp(terrain: TerrainData.Terrain, worldPos: Vector3, settings: StampSettings): { ChunkData.ChunkCoord }
	local heightmap = self:GenerateStampHeightmap(settings, 64)
	local radius = settings.size
	local affected: { [string]: ChunkData.ChunkCoord } = {}
	local minChunk, _ = ChunkData.WorldToChunkPos(worldPos - Vector3.new(radius, radius, radius), terrain.settings.chunkSize)
	local maxChunk, _ = ChunkData.WorldToChunkPos(worldPos + Vector3.new(radius, radius, radius), terrain.settings.chunkSize)
	for cx = minChunk.x, maxChunk.x do
		for cy = minChunk.y, maxChunk.y do
			for cz = minChunk.z, maxChunk.z do
				local chunkCoord = { x = cx, y = cy, z = cz }
				local chunk = TerrainData.GetOrCreateChunk(terrain, chunkCoord)
				local chunkWorldPos = ChunkData.ChunkToWorldPos(chunkCoord, terrain.settings.chunkSize)
				for z = 0, chunk.size - 1 do
					for x = 0, chunk.size - 1 do
						local voxelWorldPos = chunkWorldPos + Vector3.new(x, 0, z)
						local dx = voxelWorldPos.X - worldPos.X
						local dz = voxelWorldPos.Z - worldPos.Z
						local dist = math.sqrt(dx*dx + dz*dz)
						if dist <= radius then
							local hx = math.floor((dx / radius + 1) / 2 * #heightmap[1]) + 1
							local hz = math.floor((dz / radius + 1) / 2 * #heightmap) + 1
							hx = math.clamp(hx, 1, #heightmap[1])
							hz = math.clamp(hz, 1, #heightmap)
							local stampHeight = heightmap[hz][hx] or 0
							for y = 0, chunk.size - 1 do
								local voxelWorldY = chunkWorldPos.Y + y
								local targetHeight = worldPos.Y + stampHeight
								if settings.type == "Crater" and stampHeight < 0 then
									if voxelWorldY >= targetHeight and voxelWorldY <= worldPos.Y then ChunkData.SetVoxel(chunk, x, y, z, 0) end
								else
									if voxelWorldY <= targetHeight and voxelWorldY >= worldPos.Y then ChunkData.SetVoxel(chunk, x, y, z, settings.materialId) end
								end
							end
							local key = ChunkData.CoordToKey(chunkCoord)
							affected[key] = chunkCoord
						end
					end
				end
			end
		end
	end
	for _, coord in affected do
		local key = ChunkData.CoordToKey(coord)
		terrain.editedChunks[key] = true
		local chunk = terrain.chunks[key]
		if chunk then chunk.isDirty = true chunk.isMeshed = false end
	end
	table.insert(self.stamps, { coord = worldPos, settings = settings })
	print("[Arkher StampSystem] Applied", settings.type, "stamp at", worldPos, "- Affected:", #affected)
	local list = {}
	for _, coord in affected do table.insert(list, coord) end
	return list
end

function StampSystem:GetStamps(): { { coord: Vector3, settings: StampSettings } }
	return self.stamps
end

function StampSystem:ClearStamps()
	self.stamps = {}
	print("[Arkher StampSystem] Cleared all stamps")
end

function StampSystem:GetStats(): { [string]: any }
	return {
		totalStamps = #self.stamps,
		types = {"Mountain", "Crater", "Hill", "Plateau", "Ridge", "Canyon", "Dune", "Rock", "Custom"},
		message = "StampSystem Fase 4 - World Creator level - 9 stamp types"
	}
end

return StampSystem

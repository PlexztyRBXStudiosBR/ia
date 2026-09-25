--!strict
-- Arkher Studio - Fase 4 - BrushSystem - World Creator level terrain brushes

local TerrainData = require(game:GetService("ReplicatedStorage").Arkher.Terrain.TerrainData)
local ChunkData = require(game:GetService("ReplicatedStorage").Arkher.Terrain.ChunkData)
local VoxelTypes = require(game:GetService("ReplicatedStorage").Arkher.Terrain.VoxelTypes)

local BrushSystem = {}
BrushSystem.__index = BrushSystem

export type BrushType = "Raise" | "Lower" | "Smooth" | "Flatten" | "Paint" | "Noise" | "Erode" | "Stamp" | "Spline"
export type FalloffType = "Linear" | "Smooth" | "Spherical" | "Tip"

export type BrushSettings = {
	type: BrushType,
	size: number,
	strength: number,
	falloff: FalloffType,
	materialId: number,
	flattenHeight: number?,
	noiseScale: number?,
	noiseStrength: number?,
}

function BrushSystem.new()
	return setmetatable({
		settings = {
			type = "Raise" :: BrushType,
			size = 10,
			strength = 1,
			falloff = "Smooth" :: FalloffType,
			materialId = 1,
			flattenHeight = 20,
			noiseScale = 0.1,
			noiseStrength = 2,
		} :: BrushSettings,
		isActive = false,
		lastPos = nil :: Vector3?,
	}, BrushSystem)
end

function BrushSystem:SetBrushType(type: BrushType)
	self.settings.type = type
	print("[Arkher BrushSystem] Brush type ->", type)
end

function BrushSystem:SetSize(size: number)
	self.settings.size = math.clamp(size, 1, 100)
	print("[Arkher BrushSystem] Size ->", self.settings.size)
end

function BrushSystem:SetStrength(strength: number)
	self.settings.strength = math.clamp(strength, 0.1, 10)
	print("[Arkher BrushSystem] Strength ->", self.settings.strength)
end

function BrushSystem:SetMaterial(materialId: number)
	self.settings.materialId = materialId
	print("[Arkher BrushSystem] Material ->", VoxelTypes.GetMaterial(materialId).displayName)
end

function BrushSystem:CalculateFalloff(distance: number, radius: number, falloffType: FalloffType): number
	local t = distance / radius
	if t >= 1 then return 0 end
	if falloffType == "Linear" then return 1 - t
	elseif falloffType == "Smooth" then return 1 - (t * t * (3 - 2 * t))
	elseif falloffType == "Spherical" then return math.sqrt(1 - t * t)
	elseif falloffType == "Tip" then return 1 - t * t
	else return 1 - t end
end

function BrushSystem:ApplyBrush(terrain: TerrainData.Terrain, center: Vector3, settings: BrushSettings?): { ChunkData.ChunkCoord }
	settings = settings or self.settings
	local radius = settings.size
	local affectedChunks: { [string]: ChunkData.ChunkCoord } = {}
	local minChunk, _ = ChunkData.WorldToChunkPos(center - Vector3.new(radius, radius, radius), terrain.settings.chunkSize)
	local maxChunk, _ = ChunkData.WorldToChunkPos(center + Vector3.new(radius, radius, radius), terrain.settings.chunkSize)
	for cx = minChunk.x, maxChunk.x do
		for cy = minChunk.y, maxChunk.y do
			for cz = minChunk.z, maxChunk.z do
				local chunkCoord = { x = cx, y = cy, z = cz }
				local chunk = TerrainData.GetOrCreateChunk(terrain, chunkCoord)
				local chunkWorldPos = ChunkData.ChunkToWorldPos(chunkCoord, terrain.settings.chunkSize)
				for z = 0, chunk.size - 1 do
					for y = 0, chunk.size - 1 do
						for x = 0, chunk.size - 1 do
							local voxelWorldPos = chunkWorldPos + Vector3.new(x, y, z)
							local dist = (voxelWorldPos - center).Magnitude
							if dist <= radius then
								local falloff = self:CalculateFalloff(dist, radius, settings.falloff)
								local strength = settings.strength * falloff
								if settings.type == "Raise" then
									local topY = -1
									for ty = chunk.size - 1, 0, -1 do if ChunkData.GetVoxel(chunk, x, ty, z) ~= 0 then topY = ty break end end
									if y >= topY and y <= topY + strength then ChunkData.SetVoxel(chunk, x, y, z, settings.materialId) end
								elseif settings.type == "Lower" then
									local topY = -1
									for ty = chunk.size - 1, 0, -1 do if ChunkData.GetVoxel(chunk, x, ty, z) ~= 0 then topY = ty break end end
									if y >= topY - strength and y <= topY then if math.random() < falloff then ChunkData.SetVoxel(chunk, x, y, z, 0) end end
								elseif settings.type == "Flatten" then
									local targetHeight = settings.flattenHeight or 20
									local worldY = chunkWorldPos.Y + y
									if math.abs(worldY - targetHeight) <= strength then
										if worldY <= targetHeight then ChunkData.SetVoxel(chunk, x, y, z, settings.materialId) else ChunkData.SetVoxel(chunk, x, y, z, 0) end
									elseif worldY < targetHeight then ChunkData.SetVoxel(chunk, x, y, z, settings.materialId) end
								elseif settings.type == "Paint" then
									if ChunkData.GetVoxel(chunk, x, y, z) ~= 0 then if math.random() < falloff then ChunkData.SetVoxel(chunk, x, y, z, settings.materialId) end end
								elseif settings.type == "Smooth" then
									if ChunkData.GetVoxel(chunk, x, y, z) ~= 0 then
										local neighborCount = 0
										for dz = -1, 1 do for dy = -1, 1 do for dx = -1, 1 do if ChunkData.GetVoxel(chunk, x+dx, y+dy, z+dz) ~= 0 then neighborCount += 1 end end end end
										if neighborCount < 10 and math.random() < falloff * 0.5 then ChunkData.SetVoxel(chunk, x, y, z, 0) end
									end
								elseif settings.type == "Noise" then
									local noiseVal = math.noise(voxelWorldPos.X * (settings.noiseScale or 0.1), voxelWorldPos.Y * (settings.noiseScale or 0.1), voxelWorldPos.Z * (settings.noiseScale or 0.1))
									if noiseVal * (settings.noiseStrength or 2) > 0.5 and math.random() < falloff then
										if ChunkData.GetVoxel(chunk, x, y, z) == 0 then ChunkData.SetVoxel(chunk, x, y, z, settings.materialId) end
									end
								end
								local key = ChunkData.CoordToKey(chunkCoord)
								affectedChunks[key] = chunkCoord
							end
						end
					end
				end
			end
		end
	end
	for _, coord in affectedChunks do
		local key = ChunkData.CoordToKey(coord)
		terrain.editedChunks[key] = true
		local chunk = terrain.chunks[key]
		if chunk then chunk.isDirty = true chunk.isMeshed = false end
	end
	print("[Arkher BrushSystem] Applied", settings.type, "brush at", center, "- Radius:", radius, "- Affected:", #affectedChunks)
	local list = {}
	for _, coord in affectedChunks do table.insert(list, coord) end
	return list
end

function BrushSystem:ApplyStroke(terrain: TerrainData.Terrain, from: Vector3, to: Vector3, settings: BrushSettings?): { ChunkData.ChunkCoord }
	settings = settings or self.settings
	local affected: { [string]: ChunkData.ChunkCoord } = {}
	local dist = (to - from).Magnitude
	local steps = math.max(1, math.floor(dist / (settings.size * 0.5)))
	for i = 0, steps do
		local t = i / steps
		local pos = from:Lerp(to, t)
		local chunkAffected = self:ApplyBrush(terrain, pos, settings)
		for _, coord in chunkAffected do local key = ChunkData.CoordToKey(coord) affected[key] = coord end
	end
	print("[Arkher BrushSystem] Stroke from", from, "to", to, "- Steps:", steps)
	local list = {}
	for _, coord in affected do table.insert(list, coord) end
	return list
end

function BrushSystem:GetStats(): { [string]: any }
	return {
		type = self.settings.type,
		size = self.settings.size,
		strength = self.settings.strength,
		falloff = self.settings.falloff,
		material = VoxelTypes.GetMaterial(self.settings.materialId).displayName,
		brushes = {"Raise", "Lower", "Smooth", "Flatten", "Paint", "Noise", "Erode", "Stamp", "Spline"},
		falloffs = {"Linear", "Smooth", "Spherical", "Tip"},
		message = "BrushSystem Fase 4 - World Creator level - 9 brushes + 4 falloffs"
	}
end

return BrushSystem

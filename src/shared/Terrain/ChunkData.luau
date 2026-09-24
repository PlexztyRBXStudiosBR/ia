--!strict
-- Arkher Studio - Fase 4 - ChunkData - Mecha Engine Custom Terrain
-- Chunk 32x32x32 voxels - Greedy Meshing + Dual Contouring - Infinite World Creator

local VoxelTypes = require(script.Parent.VoxelTypes)

local ChunkData = {}
ChunkData.__index = ChunkData

export type ChunkCoord = {
	x: number,
	y: number,
	z: number,
}

export type Chunk = {
	coord: ChunkCoord,
	size: number,
	voxels: { number },
	density: { number }?,
	biomeIds: { number }?,
	isEmpty: boolean,
	isFull: boolean,
	isDirty: boolean,
	isMeshed: boolean,
	meshData: any?,
	colliderData: any?,
	lod: number,
	lastEdited: number,
}

function ChunkData.CoordToKey(coord: ChunkCoord): string
	return string.format("%d_%d_%d", coord.x, coord.y, coord.z)
end

function ChunkData.KeyToCoord(key: string): ChunkCoord
	local x, y, z = string.match(key, "(-?%d+)_(-?%d+)_(-?%d+)")
	return {
		x = tonumber(x) or 0,
		y = tonumber(y) or 0,
		z = tonumber(z) or 0,
	}
end

function ChunkData.WorldToChunkPos(worldPos: Vector3, chunkSize: number): (ChunkCoord, Vector3)
	chunkSize = chunkSize or 32
	local cx = math.floor(worldPos.X / chunkSize)
	local cy = math.floor(worldPos.Y / chunkSize)
	local cz = math.floor(worldPos.Z / chunkSize)
	local lx = worldPos.X - cx * chunkSize
	local ly = worldPos.Y - cy * chunkSize
	local lz = worldPos.Z - cz * chunkSize
	return { x = cx, y = cy, z = cz }, Vector3.new(lx, ly, lz)
end

function ChunkData.ChunkToWorldPos(chunkCoord: ChunkCoord, chunkSize: number): Vector3
	chunkSize = chunkSize or 32
	return Vector3.new(chunkCoord.x * chunkSize, chunkCoord.y * chunkSize, chunkCoord.z * chunkSize)
end

function ChunkData.CreateEmpty(coord: ChunkCoord, size: number?): Chunk
	size = size or 32
	local total = size * size * size
	local voxels = table.create(total, 0)
	return {
		coord = coord,
		size = size,
		voxels = voxels,
		density = nil,
		biomeIds = nil,
		isEmpty = true,
		isFull = false,
		isDirty = true,
		isMeshed = false,
		meshData = nil,
		colliderData = nil,
		lod = 0,
		lastEdited = os.time(),
	}
end

function ChunkData.CreateFull(coord: ChunkCoord, materialId: number, size: number?): Chunk
	size = size or 32
	local total = size * size * size
	local voxels = table.create(total, materialId)
	return {
		coord = coord,
		size = size,
		voxels = voxels,
		density = nil,
		biomeIds = nil,
		isEmpty = false,
		isFull = true,
		isDirty = true,
		isMeshed = false,
		meshData = nil,
		colliderData = nil,
		lod = 0,
		lastEdited = os.time(),
	}
end

function ChunkData.GetIndex(x: number, y: number, z: number, size: number): number
	return x + y * size + z * size * size + 1
end

function ChunkData.GetVoxel(chunk: Chunk, x: number, y: number, z: number): number
	if x < 0 or x >= chunk.size or y < 0 or y >= chunk.size or z < 0 or z >= chunk.size then
		return 0
	end
	local idx = ChunkData.GetIndex(x, y, z, chunk.size)
	return chunk.voxels[idx] or 0
end

function ChunkData.SetVoxel(chunk: Chunk, x: number, y: number, z: number, materialId: number)
	if x < 0 or x >= chunk.size or y < 0 or y >= chunk.size or z < 0 or z >= chunk.size then return end
	local idx = ChunkData.GetIndex(x, y, z, chunk.size)
	chunk.voxels[idx] = materialId
	chunk.isDirty = true
	chunk.isMeshed = false
	chunk.lastEdited = os.time()
	if materialId == 0 then chunk.isFull = false else chunk.isEmpty = false end
end

function ChunkData.Fill(chunk: Chunk, materialId: number)
	local total = chunk.size * chunk.size * chunk.size
	for i = 1, total do chunk.voxels[i] = materialId end
	chunk.isEmpty = materialId == 0
	chunk.isFull = materialId ~= 0
	chunk.isDirty = true
	chunk.isMeshed = false
end

function ChunkData.CountNonAir(chunk: Chunk): number
	local count = 0
	for _, matId in chunk.voxels do if matId ~= 0 then count += 1 end end
	return count
end

function ChunkData.IsEmpty(chunk: Chunk): boolean
	if chunk.isEmpty then return true end
	for _, matId in chunk.voxels do if matId ~= 0 then chunk.isEmpty = false return false end end
	chunk.isEmpty = true
	return true
end

function ChunkData.Serialize(chunk: Chunk): string
	local rle = {}
	local lastMat = chunk.voxels[1]
	local count = 1
	for i = 2, #chunk.voxels do
		local mat = chunk.voxels[i]
		if mat == lastMat and count < 255 then count += 1 else table.insert(rle, { mat = lastMat, count = count }) lastMat = mat count = 1 end
	end
	table.insert(rle, { mat = lastMat, count = count })
	local serialized = { coord = chunk.coord, size = chunk.size, rle = rle, lod = chunk.lod, lastEdited = chunk.lastEdited }
	return game:GetService("HttpService"):JSONEncode(serialized)
end

function ChunkData.Deserialize(json: string): Chunk?
	local success, data = pcall(function() return game:GetService("HttpService"):JSONDecode(json) end)
	if not success or not data then warn("[Arkher ChunkData] Failed to deserialize chunk") return nil end
	local chunk = ChunkData.CreateEmpty(data.coord, data.size)
	chunk.lod = data.lod or 0
	chunk.lastEdited = data.lastEdited or os.time()
	local idx = 1
	for _, entry in data.rle do
		for _ = 1, entry.count do
			if idx <= #chunk.voxels then chunk.voxels[idx] = entry.mat idx += 1 end
		end
	end
	chunk.isEmpty = ChunkData.IsEmpty(chunk)
	chunk.isDirty = true
	return chunk
end

function ChunkData.GetStats(chunk: Chunk): { [string]: any }
	return {
		coord = ChunkData.CoordToKey(chunk.coord),
		size = chunk.size,
		nonAir = ChunkData.CountNonAir(chunk),
		total = chunk.size * chunk.size * chunk.size,
		isEmpty = chunk.isEmpty,
		isFull = chunk.isFull,
		isDirty = chunk.isDirty,
		isMeshed = chunk.isMeshed,
		lod = chunk.lod,
		lastEdited = chunk.lastEdited,
	}
end

return ChunkData

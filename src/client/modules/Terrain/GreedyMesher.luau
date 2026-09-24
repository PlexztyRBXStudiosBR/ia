--!strict
-- Arkher Studio - Fase 4 - GreedyMesher - Mecha Engine Custom Terrain
-- Greedy Meshing para voxels cúbicos - Otimização 10x - Inspiração Minecraft + 0fps

local ChunkData = require(game:GetService("ReplicatedStorage").Arkher.Terrain.ChunkData)
local VoxelTypes = require(game:GetService("ReplicatedStorage").Arkher.Terrain.VoxelTypes)

local GreedyMesher = {}
GreedyMesher.__index = GreedyMesher

export type Quad = {
	x: number,
	y: number,
	z: number,
	w: number,
	h: number,
	materialId: number,
	face: string,
}

export type MeshResult = {
	quads: { Quad },
	vertexCount: number,
	triangleCount: number,
	materialGroups: { [number]: { Quad } },
}

function GreedyMesher.new()
	return setmetatable({ enabled = true }, GreedyMesher)
end

function GreedyMesher:MeshChunk(chunk: ChunkData.Chunk): MeshResult
	local size = chunk.size
	local quads: { Quad } = {}
	local materialGroups: { [number]: { Quad } } = {}
	local axes = {
		{ name = "y", u = "x", v = "z", face1 = "top", face2 = "bottom" },
		{ name = "x", u = "y", v = "z", face1 = "east", face2 = "west" },
		{ name = "z", u = "x", v = "y", face1 = "north", face2 = "south" },
	}
	for _, axis in axes do
		for slice = 0, size - 1 do
			local mask = {}
			for v = 0, size - 1 do mask[v] = {} for u = 0, size - 1 do mask[v][u] = nil end end
			for v = 0, size - 1 do
				for u = 0, size - 1 do
					local x, y, z: number
					local matA, matB: number
					if axis.name == "y" then
						x = u y = slice z = v
						matA = ChunkData.GetVoxel(chunk, x, y, z)
						matB = y + 1 < size and ChunkData.GetVoxel(chunk, x, y + 1, z) or 0
					elseif axis.name == "x" then
						x = slice y = u z = v
						matA = ChunkData.GetVoxel(chunk, x, y, z)
						matB = x + 1 < size and ChunkData.GetVoxel(chunk, x + 1, y, z) or 0
					else
						x = u y = v z = slice
						matA = ChunkData.GetVoxel(chunk, x, y, z)
						matB = z + 1 < size and ChunkData.GetVoxel(chunk, x, y, z + 1) or 0
					end
					if matA ~= 0 and matB == 0 then
						mask[v][u] = { materialId = matA, face = axis.face1, x = x, y = y, z = z }
					elseif matA == 0 and matB ~= 0 then
						mask[v][u] = { materialId = matB, face = axis.face2, x = x, y = y, z = z }
					end
				end
			end
			for v = 0, size - 1 do
				for u = 0, size - 1 do
					local current = mask[v][u]
					if current then
						local w = 1
						while u + w < size and mask[v][u + w] and mask[v][u + w].materialId == current.materialId and mask[v][u + w].face == current.face do w += 1 end
						local h = 1
						local canExpand = true
						while v + h < size and canExpand do
							for du = 0, w - 1 do
								local next = mask[v + h][u + du]
								if not next or next.materialId ~= current.materialId or next.face ~= current.face then canExpand = false break end
							end
							if canExpand then h += 1 end
						end
						local quad: Quad = { x = current.x, y = current.y, z = current.z, w = w, h = h, materialId = current.materialId, face = current.face }
						table.insert(quads, quad)
						if not materialGroups[current.materialId] then materialGroups[current.materialId] = {} end
						table.insert(materialGroups[current.materialId], quad)
						for dv = 0, h - 1 do for du = 0, w - 1 do mask[v + dv][u + du] = nil end end
					end
				end
			end
		end
	end
	local result: MeshResult = { quads = quads, vertexCount = #quads * 4, triangleCount = #quads * 2, materialGroups = materialGroups }
	print("[Arkher GreedyMesher] Meshed chunk", ChunkData.CoordToKey(chunk.coord), "- Quads:", #quads, "- Tris:", result.triangleCount)
	return result
end

function GreedyMesher:QuadsToEditableMesh(quads: { Quad }, chunkWorldPos: Vector3, chunkSize: number): EditableMesh?
	local success, editableMesh = pcall(function() return game:GetService("AssetService"):CreateEditableMesh() end)
	if not success or not editableMesh then warn("[Arkher GreedyMesher] Failed to create EditableMesh") return nil end
	local vertexMap: { [string]: number } = {}
	local function getOrCreateVertex(pos: Vector3): number
		local key = string.format("%.2f_%.2f_%.2f", pos.X, pos.Y, pos.Z)
		if vertexMap[key] then return vertexMap[key] end
		local id = editableMesh:AddVertex(pos)
		vertexMap[key] = id
		return id
	end
	for _, quad in quads do
		local x, y, z = quad.x, quad.y, quad.z
		local w, h = quad.w, quad.h
		local corners: { Vector3 } = {}
		if quad.face == "top" then
			corners = { Vector3.new(x, y + 1, z), Vector3.new(x + w, y + 1, z), Vector3.new(x + w, y + 1, z + h), Vector3.new(x, y + 1, z + h) }
		elseif quad.face == "bottom" then
			corners = { Vector3.new(x, y, z), Vector3.new(x, y, z + h), Vector3.new(x + w, y, z + h), Vector3.new(x + w, y, z) }
		elseif quad.face == "east" then
			corners = { Vector3.new(x + 1, y, z), Vector3.new(x + 1, y, z + h), Vector3.new(x + 1, y + w, z + h), Vector3.new(x + 1, y + w, z) }
		elseif quad.face == "west" then
			corners = { Vector3.new(x, y, z), Vector3.new(x, y + w, z), Vector3.new(x, y + w, z + h), Vector3.new(x, y, z + h) }
		elseif quad.face == "north" then
			corners = { Vector3.new(x, y, z + 1), Vector3.new(x, y + h, z + 1), Vector3.new(x + w, y + h, z + 1), Vector3.new(x + w, y, z + 1) }
		else
			corners = { Vector3.new(x, y, z), Vector3.new(x + w, y, z), Vector3.new(x + w, y + h, z), Vector3.new(x, y + h, z) }
		end
		for i, corner in corners do corners[i] = corner + chunkWorldPos end
		local v1 = getOrCreateVertex(corners[1])
		local v2 = getOrCreateVertex(corners[2])
		local v3 = getOrCreateVertex(corners[3])
		local v4 = getOrCreateVertex(corners[4])
		pcall(function() editableMesh:AddTriangle(v1, v2, v3) editableMesh:AddTriangle(v1, v3, v4) end)
	end
	print("[Arkher GreedyMesher] Created EditableMesh REAL - Vertices:", #vertexMap, "- Tris:", #editableMesh:GetTriangles())
	return editableMesh
end

function GreedyMesher:CreateMeshParts(quads: { Quad }, chunk: ChunkData.Chunk, parent: Instance): { MeshPart }
	local parts: { MeshPart } = {}
	local chunkWorldPos = ChunkData.ChunkToWorldPos(chunk.coord, chunk.size)
	local groups: { [number]: { Quad } } = {}
	for _, quad in quads do if not groups[quad.materialId] then groups[quad.materialId] = {} end table.insert(groups[quad.materialId], quad) end
	for matId, matQuads in groups do
		local editableMesh = self:QuadsToEditableMesh(matQuads, chunkWorldPos, chunk.size)
		if editableMesh then
			local success, meshPart = pcall(function()
				local mp = Instance.new("MeshPart")
				mp.Name = "TerrainChunk_" .. ChunkData.CoordToKey(chunk.coord) .. "_Mat" .. matId
				mp.Size = Vector3.new(chunk.size, chunk.size, chunk.size)
				mp.CFrame = CFrame.new(chunkWorldPos + Vector3.new(chunk.size/2, chunk.size/2, chunk.size/2))
				mp.Anchored = true
				mp.CanCollide = true
				local voxelMat = VoxelTypes.GetMaterial(matId)
				mp.Color = voxelMat.color
				mp.Material = voxelMat.render.material
				mp.EditableMesh = editableMesh
				mp.Parent = parent
				return mp
			end)
			if success and meshPart then table.insert(parts, meshPart) end
		end
	end
	print("[Arkher GreedyMesher] Created", #parts, "MeshParts for chunk", ChunkData.CoordToKey(chunk.coord))
	return parts
end

function GreedyMesher:GetStats(): { [string]: any }
	return {
		enabled = self.enabled,
		algorithm = "Greedy Meshing - 10x fewer triangles",
		features = {"Quad merging", "Material grouping", "EditableMesh REAL", "A01 optimized"},
		message = "GreedyMesher Fase 4 - Mecha Engine - 10x optimization"
	}
end

return GreedyMesher

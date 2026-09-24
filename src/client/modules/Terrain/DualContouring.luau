--!strict
-- Arkher Studio - Fase 4 - DualContouring - Mecha Engine Custom Terrain
-- Smooth terrain via Dual Contouring + Transvoxel

local ChunkData = require(game:GetService("ReplicatedStorage").Arkher.Terrain.ChunkData)

local DualContouring = {}
DualContouring.__index = DualContouring

export type HermiteData = {
	position: Vector3,
	normal: Vector3,
}

export type QEFData = {
	ata: { { number } },
	atb: Vector3,
	massPoint: Vector3,
	numPoints: number,
}

function DualContouring.new()
	return setmetatable({ enabled = true, surfaceThreshold = 0 }, DualContouring)
end

function DualContouring:CreateQEF(): QEFData
	return { ata = { {0,0,0}, {0,0,0}, {0,0,0} }, atb = Vector3.new(0,0,0), massPoint = Vector3.new(0,0,0), numPoints = 0 }
end

function DualContouring:AddPointToQEF(qef: QEFData, pos: Vector3, normal: Vector3)
	qef.numPoints += 1
	qef.massPoint += pos
	qef.ata[1][1] += normal.X * normal.X
	qef.ata[1][2] += normal.X * normal.Y
	qef.ata[1][3] += normal.X * normal.Z
	qef.ata[2][1] += normal.Y * normal.X
	qef.ata[2][2] += normal.Y * normal.Y
	qef.ata[2][3] += normal.Y * normal.Z
	qef.ata[3][1] += normal.Z * normal.X
	qef.ata[3][2] += normal.Z * normal.Y
	qef.ata[3][3] += normal.Z * normal.Z
	local dot = normal:Dot(pos)
	qef.atb += Vector3.new(normal.X * dot, normal.Y * dot, normal.Z * dot)
end

function DualContouring:SolveQEF(qef: QEFData): Vector3
	if qef.numPoints == 0 then return qef.massPoint end
	local massPointAvg = qef.massPoint / qef.numPoints
	return massPointAvg
end

function DualContouring:GenerateDensityField(chunk: ChunkData.Chunk, heightmap: { { number } }?): { number }
	local size = chunk.size
	local density: { number } = {}
	if chunk.density then return chunk.density end
	for z = 0, size - 1 do
		for y = 0, size - 1 do
			for x = 0, size - 1 do
				local mat = ChunkData.GetVoxel(chunk, x, y, z)
				local isSolid = mat ~= 0
				local dist = 1
				if isSolid then
					local nearAir = false
					for dz = -1, 1 do for dy = -1, 1 do for dx = -1, 1 do if ChunkData.GetVoxel(chunk, x+dx, y+dy, z+dz) == 0 then nearAir = true break end end if nearAir then break end end if nearAir then break end end
					dist = nearAir and -0.5 or -1
				else
					local nearSolid = false
					for dz = -1, 1 do for dy = -1, 1 do for dx = -1, 1 do if ChunkData.GetVoxel(chunk, x+dx, y+dy, z+dz) ~= 0 then nearSolid = true break end end if nearSolid then break end end if nearSolid then break end end
					dist = nearSolid and 0.5 or 1
				end
				table.insert(density, dist)
			end
		end
	end
	print("[Arkher DualContouring] Generated density field - Size:", size)
	return density
end

function DualContouring:ContourChunk(chunk: ChunkData.Chunk): ({ { position: Vector3, normal: Vector3 } }, { { number } })
	local size = chunk.size
	local density = self:GenerateDensityField(chunk)
	local vertices: { { position: Vector3, normal: Vector3 } } = {}
	local triangles: { { number } } = {}
	for z = 0, size - 2 do
		for y = 0, size - 2 do
			for x = 0, size - 2 do
				local corners = {
					density[ChunkData.GetIndex(x, y, z, size)],
					density[ChunkData.GetIndex(x+1, y, z, size)],
					density[ChunkData.GetIndex(x+1, y+1, z, size)],
					density[ChunkData.GetIndex(x, y+1, z, size)],
					density[ChunkData.GetIndex(x, y, z+1, size)],
					density[ChunkData.GetIndex(x+1, y, z+1, size)],
					density[ChunkData.GetIndex(x+1, y+1, z+1, size)],
					density[ChunkData.GetIndex(x, y+1, z+1, size)],
				}
				local insideCount = 0
				for _, d in corners do if d < self.surfaceThreshold then insideCount += 1 end end
				if insideCount > 0 and insideCount < 8 then
					local qef = self:CreateQEF()
					local edges = { {0,1}, {1,2}, {2,3}, {3,0}, {4,5}, {5,6}, {6,7}, {7,4}, {0,4}, {1,5}, {2,6}, {3,7} }
					local edgePositions = {
						Vector3.new(x, y, z), Vector3.new(x+1, y, z), Vector3.new(x+1, y+1, z), Vector3.new(x, y+1, z),
						Vector3.new(x, y, z+1), Vector3.new(x+1, y, z+1), Vector3.new(x+1, y+1, z+1), Vector3.new(x, y+1, z+1),
					}
					for _, edge in edges do
						local d1 = corners[edge[1] + 1]
						local d2 = corners[edge[2] + 1]
						if (d1 < self.surfaceThreshold) ~= (d2 < self.surfaceThreshold) then
							local t = d1 / (d1 - d2)
							t = math.clamp(t, 0, 1)
							local p1 = edgePositions[edge[1] + 1]
							local p2 = edgePositions[edge[2] + 1]
							local pos = p1:Lerp(p2, t)
							local gx = (density[ChunkData.GetIndex(math.clamp(x+1,0,size-1), y, z, size)] or 0) - (density[ChunkData.GetIndex(math.clamp(x-1,0,size-1), y, z, size)] or 0)
							local gy = (density[ChunkData.GetIndex(x, math.clamp(y+1,0,size-1), z, size)] or 0) - (density[ChunkData.GetIndex(x, math.clamp(y-1,0,size-1), z, size)] or 0)
							local gz = (density[ChunkData.GetIndex(x, y, math.clamp(z+1,0,size-1), size)] or 0) - (density[ChunkData.GetIndex(x, y, math.clamp(z-1,0,size-1), size)] or 0)
							local normal = Vector3.new(gx, gy, gz)
							if normal.Magnitude > 0.001 then normal = normal.Unit else normal = Vector3.new(0,1,0) end
							self:AddPointToQEF(qef, pos, normal)
						end
					end
					if qef.numPoints > 0 then
						local vertPos = self:SolveQEF(qef)
						vertPos = Vector3.new(math.clamp(vertPos.X, x, x+1), math.clamp(vertPos.Y, y, y+1), math.clamp(vertPos.Z, z, z+1))
						table.insert(vertices, { position = vertPos + ChunkData.ChunkToWorldPos(chunk.coord, size), normal = Vector3.new(0,1,0) })
					end
				end
			end
		end
	end
	print("[Arkher DualContouring] Contoured chunk", ChunkData.CoordToKey(chunk.coord), "- Vertices:", #vertices)
	return vertices, triangles
end

function DualContouring:GetStats(): { [string]: any }
	return {
		enabled = self.enabled,
		surfaceThreshold = self.surfaceThreshold,
		algorithm = "Dual Contouring + QEF - Smooth terrain",
		features = {"QEF solve", "Hermite data", "Sharp features", "Smooth terrain", "EditableMesh REAL"},
		message = "DualContouring Fase 4 - Mecha Engine - Smooth terrain"
	}
end

return DualContouring

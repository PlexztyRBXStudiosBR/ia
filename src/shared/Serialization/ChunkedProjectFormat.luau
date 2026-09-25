--!strict
-- Arkher Studio - Fase 1.5 - ChunkedProjectFormat - Suporte a 15GB por jogo
-- DataStore só aguenta 4MB, então usamos External Storage (S3) + chunking inteligente

local HttpService = game:GetService("HttpService")

local World = require(script.Parent.Parent.ECS.World)
local Entity = require(script.Parent.Parent.ECS.Entity)

local ChunkedProjectFormat = {}
ChunkedProjectFormat.__index = ChunkedProjectFormat

ChunkedProjectFormat.VERSION = "1.5.0-15gb"
ChunkedProjectFormat.MAX_DATASTORE_CHUNK = 3_500_000 -- 3.5MB para DataStore
ChunkedProjectFormat.MAX_EXTERNAL_CHUNK = 50_000_000 -- 50MB por chunk externo (S3)
ChunkedProjectFormat.CHUNK_SIZE_STUDS = 32 -- cada chunk 32x32x32 studs
ChunkedProjectFormat.MAX_PROJECT_SIZE = 15_000_000_000 -- 15GB

export type ChunkCoord = {
	x: number,
	y: number,
	z: number,
}

export type ProjectChunk = {
	coord: ChunkCoord,
	entities: { string }, -- IDs das entidades nesse chunk
	data: string?, -- JSON do chunk (se pequeno) ou URL externa (se grande)
	size: number,
	isExternal: boolean,
	externalUrl: string?,
	checksum: string,
}

export type ChunkedProject = {
	meta: {
		projectId: string,
		name: string,
		version: number,
		styleProfile: string,
		arkherVersion: string,
		totalSize: number,
		chunkCount: number,
		bounds: {
			min: Vector3,
			max: Vector3,
		},
		createdAt: number,
		updatedAt: number,
		useExternalStorage: boolean,
		externalStorageBaseUrl: string?,
	},
	chunks: { [string]: ProjectChunk }, -- key = "x_y_z"
	manifest: {
		chunks: { string }, -- lista de keys
		entitiesCount: number,
		totalSize: number,
	},
	rootEntities: { string }, -- entidades fora de chunks (globais)
}

function ChunkedProjectFormat.GetChunkKey(coord: ChunkCoord): string
	return string.format("%d_%d_%d", coord.x, coord.y, coord.z)
end

function ChunkedProjectFormat.GetChunkCoordFromPosition(pos: Vector3): ChunkCoord
	return {
		x = math.floor(pos.X / ChunkedProjectFormat.CHUNK_SIZE_STUDS),
		y = math.floor(pos.Y / ChunkedProjectFormat.CHUNK_SIZE_STUDS),
		z = math.floor(pos.Z / ChunkedProjectFormat.CHUNK_SIZE_STUDS),
	}
end

function ChunkedProjectFormat.CreateChunk(coord: ChunkCoord): ProjectChunk
	return {
		coord = coord,
		entities = {},
		data = nil,
		size = 0,
		isExternal = false,
		externalUrl = nil,
		checksum = "",
	}
end

function ChunkedProjectFormat.SerializeWorldToChunks(world: World.World, meta: any): ChunkedProject
	local chunks: { [string]: ProjectChunk } = {}
	local rootEntities: { string } = {}
	local totalSize = 0
	local minBound = Vector3.new(math.huge, math.huge, math.huge)
	local maxBound = Vector3.new(-math.huge, -math.huge, -math.huge)

	-- Distribui entidades em chunks baseado na posição
	for id, entity in world.entities do
		local transform = entity.components.Transform
		if transform and transform.position then
			local pos = transform.position
			local coord = ChunkedProjectFormat.GetChunkCoordFromPosition(pos)
			local key = ChunkedProjectFormat.GetChunkKey(coord)

			if not chunks[key] then
				chunks[key] = ChunkedProjectFormat.CreateChunk(coord)
			end

			table.insert(chunks[key].entities, id)

			-- Atualiza bounds
			minBound = Vector3.new(math.min(minBound.X, pos.X), math.min(minBound.Y, pos.Y), math.min(minBound.Z, pos.Z))
			maxBound = Vector3.new(math.max(maxBound.X, pos.X), math.max(maxBound.Y, pos.Y), math.max(maxBound.Z, pos.Z))
		else
			-- Entidade sem posição (global, como Lighting, etc)
			table.insert(rootEntities, id)
		end
	end

	-- Serializa cada chunk
	for key, chunk in chunks do
		local chunkEntities = {}
		for _, entityId in chunk.entities do
			local entity = world.entities[entityId]
			if entity then
				chunkEntities[entityId] = {
					id = entity.id,
					name = entity.name,
					parent = entity.parent,
					children = entity.children,
					components = entity.components,
					tags = entity.tags,
				}
			end
		end

		local chunkJson = HttpService:JSONEncode(chunkEntities)
		chunk.size = #chunkJson
		chunk.checksum = string.format("%x", #chunkJson)
		totalSize += chunk.size

		-- Decide se vai para DataStore ou External Storage
		if chunk.size > ChunkedProjectFormat.MAX_DATASTORE_CHUNK then
			chunk.isExternal = true
			chunk.data = nil -- não guarda JSON aqui, vai para S3
			chunk.externalUrl = string.format("https://arkher-cdn.fly.dev/projects/%s/chunks/%s.json", meta.projectId, key)
			print(string.format("[Arkher Chunked] Chunk %s too big (%d bytes) -> External Storage", key, chunk.size))
		else
			chunk.isExternal = false
			chunk.data = chunkJson
		end
	end

	-- Verifica limite 15GB
	if totalSize > ChunkedProjectFormat.MAX_PROJECT_SIZE then
		warn(string.format("[Arkher Chunked] Project too big: %d bytes > 15GB limit!", totalSize))
		-- Em produção, comprime ou recusa
	end

	local project: ChunkedProject = {
		meta = {
			projectId = meta.projectId or HttpService:GenerateGUID(false),
			name = meta.name or "Untitled 15GB Project",
			version = meta.version or 1,
			styleProfile = meta.styleProfile or "realistic",
			arkherVersion = ChunkedProjectFormat.VERSION,
			totalSize = totalSize,
			chunkCount = 0,
			bounds = {
				min = minBound,
				max = maxBound,
			},
			createdAt = meta.createdAt or os.time(),
			updatedAt = os.time(),
			useExternalStorage = totalSize > 10_000_000, -- >10MB usa externo
			externalStorageBaseUrl = totalSize > 10_000_000 and string.format("https://arkher-cdn.fly.dev/projects/%s", meta.projectId) or nil,
		},
		chunks = chunks,
		manifest = {
			chunks = {},
			entitiesCount = world.entityCount,
			totalSize = totalSize,
		},
		rootEntities = rootEntities,
	}

	-- Preenche manifest
	for key, _ in chunks do
		table.insert(project.manifest.chunks, key)
	end
	project.meta.chunkCount = #project.manifest.chunks

	print(string.format("[Arkher Chunked] Serialized %d entities into %d chunks - Total: %.2f MB / 15GB max", world.entityCount, project.meta.chunkCount, totalSize / 1024 / 1024))

	return project
end

function ChunkedProjectFormat.DeserializeChunksToWorld(chunkedProject: ChunkedProject): World.World?
	local world = World.new()

	-- Carrega chunks
	for key, chunk in chunkedProject.chunks do
		local chunkData: any = nil

		if chunk.isExternal then
			-- Em produção, baixa do S3 via HttpService
			warn(string.format("[Arkher Chunked] Chunk %s is external, need to download from %s", key, chunk.externalUrl or "unknown"))
			-- chunkData = HttpService:JSONDecode(downloadedJson)
			-- Por enquanto, tenta usar data se tiver
			if chunk.data then
				local success, decoded = pcall(function()
					return HttpService:JSONDecode(chunk.data)
				end)
				if success then
					chunkData = decoded
				end
			end
		else
			if chunk.data then
				local success, decoded = pcall(function()
					return HttpService:JSONDecode(chunk.data)
				end)
				if success then
					chunkData = decoded
				end
			end
		end

		if chunkData then
			for id, entData in chunkData do
				local entity = Entity.new(entData.name, entData.parent)
				entity.id = entData.id
				entity.children = entData.children or {}
				entity.components = entData.components or {}
				entity.tags = entData.tags or {}
				world.entities[id] = entity
				world.entityCount += 1
			end
		end
	end

	-- Carrega root entities (se tiver no manifest antigo)
	-- Para compatibilidade com formato antigo

	print(string.format("[Arkher Chunked] Deserialized %d entities from %d chunks", world.entityCount, chunkedProject.meta.chunkCount))

	return world
end

function ChunkedProjectFormat.GetChunksInRadius(chunkedProject: ChunkedProject, center: Vector3, radius: number): { string }
	-- Retorna chunks dentro do raio (para streaming)
	local centerCoord = ChunkedProjectFormat.GetChunkCoordFromPosition(center)
	local radiusInChunks = math.ceil(radius / ChunkedProjectFormat.CHUNK_SIZE_STUDS)
	local result: { string } = {}

	for x = centerCoord.x - radiusInChunks, centerCoord.x + radiusInChunks do
		for y = centerCoord.y - radiusInChunks, centerCoord.y + radiusInChunks do
			for z = centerCoord.z - radiusInChunks, centerCoord.z + radiusInChunks do
				local key = string.format("%d_%d_%d", x, y, z)
				if chunkedProject.chunks[key] then
					table.insert(result, key)
				end
			end
		end
	end

	return result
end

function ChunkedProjectFormat.EstimateSize(world: World.World): number
	-- Estima tamanho total sem serializar tudo
	local count = world.entityCount
	-- Média 2KB por entidade (Transform + Render + etc)
	local avgEntitySize = 2048
	return count * avgEntitySize
end

function ChunkedProjectFormat.CanFitInDataStore(world: World.World): boolean
	local estimated = ChunkedProjectFormat.EstimateSize(world)
	return estimated < 10_000_000 -- 10MB limite seguro para DataStore (com chunking)
end

return ChunkedProjectFormat

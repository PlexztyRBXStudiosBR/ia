--!strict
-- Arkher Studio - ProjectService - Save/Load com chunking DataStore (4MB limit)
-- Git-like versionamento

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local ProjectFormat = require(game.ReplicatedStorage.Arkher.Serialization.ProjectFormat)
local World = require(game.ReplicatedStorage.Arkher.ECS.World)

local ProjectService = {}
ProjectService.__index = ProjectService

function ProjectService.new()
	local self = setmetatable({
		dataStore = nil,
		versionStore = nil,
		cache = {} :: { [string]: any },
	}, ProjectService)

	-- Tenta pegar DataStore (pode falhar no Studio sem API enabled)
	pcall(function()
		self.dataStore = DataStoreService:GetDataStore("ArkherProjects_V1")
		self.versionStore = DataStoreService:GetDataStore("ArkherVersions_V1")
	end)

	if self.dataStore then
		print("[Arkher ProjectService] DataStore connected")
	else
		print("[Arkher ProjectService] DataStore not available - Using memory cache (Studio mode)")
	end

	return self
end

function ProjectService:SaveProject(userId: number, projectId: string, world: World.World, meta: any): boolean
	local json = ProjectFormat.Serialize(world, meta)
	return self:SaveJson(userId, projectId, json, meta)
end

function ProjectService:SaveJson(userId: number, projectId: string, json: string, meta: any): boolean
	local chunks = ProjectFormat.Chunk(json)

	print(string.format("[Arkher ProjectService] Saving project %s - %d bytes in %d chunks", projectId, #json, #chunks))

	-- Salva chunks
	for i, chunk in chunks do
		local key = string.format("%d_%s_chunk_%d", userId, projectId, i)
		local success, err = pcall(function()
			if self.dataStore then
				self.dataStore:SetAsync(key, chunk)
			else
				self.cache[key] = chunk
			end
		end)

		if not success then
			warn("[Arkher ProjectService] Failed to save chunk", i, err)
			return false
		end
	end

	-- Salva metadata
	local metaKey = string.format("%d_%s_meta", userId, projectId)
	local metaData = {
		projectId = projectId,
		name = meta.name,
		version = meta.version,
		chunkCount = #chunks,
		size = #json,
		updatedAt = os.time(),
		styleProfile = meta.styleProfile,
	}

	pcall(function()
		if self.dataStore then
			self.dataStore:SetAsync(metaKey, metaData)
		else
			self.cache[metaKey] = metaData
		end
		-- Versionamento git-like
		local versionKey = string.format("%d_%s_v%d", userId, projectId, meta.version)
		if self.versionStore then
			self.versionStore:SetAsync(versionKey, { meta = metaData, timestamp = os.time() })
		end
	end)

	print("[Arkher ProjectService] Project saved successfully - Version", meta.version)
	return true
end

function ProjectService:LoadProject(userId: number, projectId: string): (World.World?, any?)
	local metaKey = string.format("%d_%s_meta", userId, projectId)
	local meta: any = nil

	local success = pcall(function()
		if self.dataStore then
			meta = self.dataStore:GetAsync(metaKey)
		else
			meta = self.cache[metaKey]
		end
	end)

	if not success or not meta then
		warn("[Arkher ProjectService] Project not found:", projectId)
		return nil, nil
	end

	-- Carrega chunks
	local chunks = {}
	for i = 1, meta.chunkCount do
		local key = string.format("%d_%s_chunk_%d", userId, projectId, i)
		local chunk: string? = nil

		pcall(function()
			if self.dataStore then
				chunk = self.dataStore:GetAsync(key)
			else
				chunk = self.cache[key]
			end
		end)

		if chunk then
			table.insert(chunks, chunk)
		else
			warn("[Arkher ProjectService] Missing chunk", i)
			return nil, nil
		end
	end

	local json = ProjectFormat.Unchunk(chunks)
	local world, loadedMeta = ProjectFormat.Deserialize(json)

	print(string.format("[Arkher ProjectService] Loaded project %s - %d entities - Version %d", projectId, world and world.entityCount or 0, meta.version))

	return world, loadedMeta
end

function ProjectService:ListProjects(userId: number): { any }
	-- Fase 2: Implementar listagem real com OrderedDataStore ou MemoryStore
	-- Por enquanto retorna do cache

	local projects = {}
	for key, value in self.cache do
		if string.find(key, tostring(userId) .. "_") and string.find(key, "_meta") then
			table.insert(projects, value)
		end
	end

	print("[Arkher ProjectService] Listed", #projects, "projects for user", userId)
	return projects
end

function ProjectService:DeleteProject(userId: number, projectId: string): boolean
	local metaKey = string.format("%d_%s_meta", userId, projectId)
	local meta: any = nil

	pcall(function()
		if self.dataStore then
			meta = self.dataStore:GetAsync(metaKey)
		else
			meta = self.cache[metaKey]
		end
	end)

	if not meta then
		return false
	end

	for i = 1, meta.chunkCount do
		local key = string.format("%d_%s_chunk_%d", userId, projectId, i)
		pcall(function()
			if self.dataStore then
				self.dataStore:RemoveAsync(key)
			else
				self.cache[key] = nil
			end
		end)
	end

	pcall(function()
		if self.dataStore then
			self.dataStore:RemoveAsync(metaKey)
		else
			self.cache[metaKey] = nil
		end
	end)

	print("[Arkher ProjectService] Deleted project", projectId)
	return true
end

function ProjectService:GetVersionHistory(userId: number, projectId: string): { any }
	-- Git-like history
	local history = {}
	for i = 1, 10 do -- últimas 10 versões
		local versionKey = string.format("%d_%s_v%d", userId, projectId, i)
		local data: any = nil
		pcall(function()
			if self.versionStore then
				data = self.versionStore:GetAsync(versionKey)
			end
		end)
		if data then
			table.insert(history, data)
		end
	end

	return history
end

return ProjectService

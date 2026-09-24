--!strict
-- Arkher Studio - Fase 1.5 - ExternalStorageService - Suporte a 15GB
-- Quando DataStore (4MB) não aguenta, usa S3 / Supabase via backend

local HttpService = game:GetService("HttpService")

local ExternalStorageService = {}
ExternalStorageService.__index = ExternalStorageService

function ExternalStorageService.new(backendUrl: string?)
	return setmetatable({
		backendUrl = backendUrl or "http://localhost:3000",
		enabled = true,
		maxDataStoreSize = 10_000_000, -- 10MB limite seguro para DataStore com chunking
		maxExternalSize = 15_000_000_000, -- 15GB
		cache = {} :: { [string]: any },
	}, ExternalStorageService)
end

function ExternalStorageService:SetBackendUrl(url: string)
	self.backendUrl = url
	print("[Arkher ExternalStorage] Backend URL:", url)
end

function ExternalStorageService:ShouldUseExternal(sizeBytes: number): boolean
	return sizeBytes > self.maxDataStoreSize
end

function ExternalStorageService:SaveProjectExternal(userId: number, projectId: string, chunkedProject: any): boolean
	local totalSize = chunkedProject.meta.totalSize
	print(string.format("[Arkher ExternalStorage] Saving external project %s - %.2f MB / 15GB", projectId, totalSize / 1024 / 1024))

	if totalSize > self.maxExternalSize then
		warn(string.format("[Arkher ExternalStorage] Project too big: %.2f GB > 15GB", totalSize / 1024 / 1024 / 1024))
		return false
	end

	-- Separa chunks pequenos (DataStore) e grandes (S3)
	local smallChunks = {}
	local largeChunks = {}

	for key, chunk in chunkedProject.chunks do
		if chunk.isExternal then
			table.insert(largeChunks, { key = key, chunk = chunk })
		else
			smallChunks[key] = chunk
		end
	end

	print(string.format("[Arkher ExternalStorage] Small chunks (DataStore): %d, Large chunks (S3): %d", #smallChunks, #largeChunks))

	-- Salva small chunks no DataStore (via ProjectService)
	-- Salva large chunks no S3 via backend

	for _, data in largeChunks do
		local success = self:UploadChunkToS3(userId, projectId, data.key, data.chunk)
		if not success then
			warn("[Arkher ExternalStorage] Failed to upload chunk", data.key)
			return false
		end
	end

	-- Salva manifest no DataStore (sempre, mesmo para projetos grandes)
	local manifestKey = string.format("%d_%s_manifest", userId, projectId)
	local manifest = {
		projectId = projectId,
		meta = chunkedProject.meta,
		manifest = chunkedProject.manifest,
		rootEntities = chunkedProject.rootEntities,
		smallChunks = smallChunks, -- só chunks pequenos
		largeChunkKeys = {}, -- keys dos chunks grandes (para saber que estão no S3)
		updatedAt = os.time(),
	}

	for _, data in largeChunks do
		table.insert(manifest.largeChunkKeys, data.key)
	end

	-- Salva manifest via DataStore ou cache
	self.cache[manifestKey] = manifest

	-- Em produção, chama backend para salvar manifest
	self:CallBackend("/api/storage/manifest", {
		userId = userId,
		projectId = projectId,
		manifest = manifest,
	})

	print("[Arkher ExternalStorage] External project saved - Manifest +", #largeChunks, "chunks in S3")
	return true
end

function ExternalStorageService:UploadChunkToS3(userId: number, projectId: string, chunkKey: string, chunk: any): boolean
	print(string.format("[Arkher ExternalStorage] Uploading chunk %s (%d bytes) to S3", chunkKey, chunk.size))

	-- Fase 1.5 mock, Fase 2 real com HttpService

	--[[
	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = self.backendUrl .. "/api/storage/chunk",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({
				userId = userId,
				projectId = projectId,
				chunkKey = chunkKey,
				chunkData = chunk.data, -- ou base64 se binário
				size = chunk.size,
			})
		})
	end)

	return success and response.Success
	]]

	-- Mock
	task.wait(0.1) -- simula upload
	self.cache[string.format("%d_%s_chunk_%s", userId, projectId, chunkKey)] = chunk

	return true
end

function ExternalStorageService:LoadProjectExternal(userId: number, projectId: string): any?
	print(string.format("[Arkher ExternalStorage] Loading external project %s", projectId))

	local manifestKey = string.format("%d_%s_manifest", userId, projectId)
	local manifest = self.cache[manifestKey]

	if not manifest then
		-- Tenta baixar do backend
		local result = self:CallBackend("/api/storage/manifest/" .. projectId, {
			userId = userId,
		})

		if result and result.manifest then
			manifest = result.manifest
		else
			warn("[Arkher ExternalStorage] Manifest not found for", projectId)
			return nil
		end
	end

	-- Reconstrói chunks
	local chunks: { [string]: any } = {}

	-- Small chunks já estão no manifest
	for key, chunk in manifest.smallChunks do
		chunks[key] = chunk
	end

	-- Large chunks baixa do S3
	for _, chunkKey in manifest.largeChunkKeys do
		local chunk = self:DownloadChunkFromS3(userId, projectId, chunkKey)
		if chunk then
			chunks[chunkKey] = chunk
		else
			warn("[Arkher ExternalStorage] Failed to download chunk", chunkKey)
		end
	end

	local chunkedProject = {
		meta = manifest.meta,
		chunks = chunks,
		manifest = manifest.manifest,
		rootEntities = manifest.rootEntities,
	}

	print(string.format("[Arkher ExternalStorage] Loaded external project %s - %d chunks - %.2f MB", projectId, #chunks, manifest.meta.totalSize / 1024 / 1024))

	return chunkedProject
end

function ExternalStorageService:DownloadChunkFromS3(userId: number, projectId: string, chunkKey: string): any?
	print(string.format("[Arkher ExternalStorage] Downloading chunk %s from S3", chunkKey))

	local cacheKey = string.format("%d_%s_chunk_%s", userId, projectId, chunkKey)
	local cached = self.cache[cacheKey]

	if cached then
		return cached
	end

	-- Em produção, baixa via backend
	--[[
	local result = self:CallBackend("/api/storage/chunk/" .. projectId .. "/" .. chunkKey, {
		userId = userId,
	})
	return result and result.chunk
	]]

	return nil
end

function ExternalStorageService:CallBackend(endpoint: string, payload: any): any?
	local url = self.backendUrl .. endpoint
	print("[Arkher ExternalStorage] Backend call:", url)

	-- Mock Fase 1.5
	return {
		success = true,
		mock = true,
	}
end

function ExternalStorageService:GetProjectSize(userId: number, projectId: string): number
	local manifestKey = string.format("%d_%s_manifest", userId, projectId)
	local manifest = self.cache[manifestKey]

	if manifest and manifest.meta then
		return manifest.meta.totalSize
	end

	return 0
end

function ExternalStorageService:ListLargeProjects(userId: number): { any }
	local projects = {}

	for key, manifest in self.cache do
		if string.find(key, tostring(userId) .. "_") and string.find(key, "_manifest") then
			table.insert(projects, {
				projectId = manifest.meta.projectId,
				name = manifest.meta.name,
				size = manifest.meta.totalSize,
				sizeMB = manifest.meta.totalSize / 1024 / 1024,
				chunkCount = manifest.meta.chunkCount,
				updatedAt = manifest.meta.updatedAt,
			})
		end
	end

	table.sort(projects, function(a, b)
		return a.size > b.size
	end)

	return projects
end

return ExternalStorageService

--!strict
-- Arkher Studio - Fase 1 - ProjectManager - Save/Load real via RemoteEvents

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ProjectFormat = require(ReplicatedStorage.Arkher.Serialization.ProjectFormat)
local World = require(ReplicatedStorage.Arkher.ECS.World)

local ProjectManager = {}
ProjectManager.__index = ProjectManager

function ProjectManager.new(world: World.World)
	return setmetatable({
		world = world,
		currentProjectId = nil :: string?,
		currentMeta = nil :: any?,
		isSaving = false,
		autoSaveEnabled = true,
		autoSaveInterval = 60, -- 60s
		lastSave = 0,
	}, ProjectManager)
end

function ProjectManager:Init()
	-- Conecta remotes
	self.saveRemote = ReplicatedStorage:FindFirstChild("ArkherRemotes") and ReplicatedStorage.ArkherRemotes:FindFirstChild("SaveProject") :: RemoteEvent
	self.loadRemote = ReplicatedStorage:FindFirstChild("ArkherRemotes") and ReplicatedStorage.ArkherRemotes:FindFirstChild("LoadProject") :: RemoteFunction

	if not self.saveRemote then
		warn("[Arkher ProjectManager] SaveProject remote not found - Using local mock")
	end

	-- Auto-save loop
	task.spawn(function()
		while true do
			task.wait(self.autoSaveInterval)
			if self.autoSaveEnabled and self.currentProjectId and not self.isSaving then
				if os.clock() - self.lastSave > self.autoSaveInterval then
					self:AutoSave()
				end
			end
		end
	end)

	print("[Arkher ProjectManager] Initialized - AutoSave:", self.autoSaveEnabled, "Interval:", self.autoSaveInterval)
end

function ProjectManager:CreateNewProject(name: string, styleProfile: string?): string
	local projectId = game:GetService("HttpService"):GenerateGUID(false)

	self.currentProjectId = projectId
	self.currentMeta = {
		projectId = projectId,
		name = name or "Meu Projeto Arkher",
		description = "Criado no Arkher Studio Mobile",
		version = 1,
		styleProfile = styleProfile or "realistic",
		createdAt = os.time(),
		updatedAt = os.time(),
		creatorId = Players.LocalPlayer.UserId,
		creatorName = Players.LocalPlayer.Name,
		useCustomEngine = false,
	}

	-- Limpa mundo
	self.world:Clear()

	print("[Arkher ProjectManager] Created new project", projectId, "-", name)

	return projectId
end

function ProjectManager:SaveProject(): boolean
	if self.isSaving then
		warn("[Arkher ProjectManager] Already saving")
		return false
	end

	if not self.currentProjectId then
		self:CreateNewProject("Projeto AutoSave")
	end

	self.isSaving = true

	local meta = self.currentMeta
	meta.version += 1
	meta.updatedAt = os.time()

	local json = ProjectFormat.Serialize(self.world, meta)

	print(string.format("[Arkher ProjectManager] Saving project %s - %d bytes - %d entities - v%d", self.currentProjectId, #json, self.world.entityCount, meta.version))

	-- Tenta salvar via Remote
	if self.saveRemote then
		-- Escuta resposta do server
		local responseConn
		responseConn = self.saveRemote.OnClientEvent:Connect(function(response)
			if response.projectId == self.currentProjectId then
				if response.success then
					print("[Arkher ProjectManager] Server confirmed save - Version", response.version)
				else
					warn("[Arkher ProjectManager] Server save failed:", response.error)
				end
				if responseConn then
					responseConn:Disconnect()
				end
			end
		end)

		local success, err = pcall(function()
			self.saveRemote:FireServer(self.currentProjectId, json, meta)
		end)

		if not success then
			warn("[Arkher ProjectManager] Save via remote failed:", err)
			if responseConn then responseConn:Disconnect() end
			-- Fallback local (Studio)
			self:SaveLocal(json, meta)
		end
	else
		self:SaveLocal(json, meta)
	end

	self.lastSave = os.clock()
	self.isSaving = false

	print("[Arkher ProjectManager] Saved - Version", meta.version, "-", #json, "bytes -", self.world.entityCount, "entities")
	return true
end

function ProjectManager:SaveLocal(json: string, meta: any)
	-- Fallback para Studio sem DataStore - salva em _G ou arquivo local
	_G.ArkherLocalSave = {
		json = json,
		meta = meta,
		timestamp = os.time(),
	}

	print("[Arkher ProjectManager] Saved locally to _G.ArkherLocalSave (Studio mode) -", #json, "bytes")
end

function ProjectManager:LoadProject(projectId: string): boolean
	print("[Arkher ProjectManager] Loading project", projectId)

	if self.loadRemote then
		local success, worldData, meta = pcall(function()
			return self.loadRemote:InvokeServer(projectId)
		end)

		if success and worldData then
			-- Desserializa
			local world, loadedMeta = ProjectFormat.Deserialize(worldData)
			if world then
				self.world = world
				self.currentProjectId = projectId
				self.currentMeta = loadedMeta
				print("[Arkher ProjectManager] Loaded from server -", world.entityCount, "entities")
				return true
			end
		else
			warn("[Arkher ProjectManager] Load via remote failed")
		end
	end

	-- Fallback local
	if _G.ArkherLocalSave and _G.ArkherLocalSave.meta.projectId == projectId then
		local world, meta = ProjectFormat.Deserialize(_G.ArkherLocalSave.json)
		if world then
			self.world = world
			self.currentProjectId = projectId
			self.currentMeta = meta
			print("[Arkher ProjectManager] Loaded from local -", world.entityCount, "entities")
			return true
		end
	end

	warn("[Arkher ProjectManager] Project not found:", projectId)
	return false
end

function ProjectManager:AutoSave()
	print("[Arkher ProjectManager] AutoSave triggered")
	self:SaveProject()
end

function ProjectManager:ExportRBXLX(): string
	local meta = self.currentMeta or { name = "Arkher Export" }
	local rbxlx = ProjectFormat.ToRBXLX(self.world, meta)
	print("[Arkher ProjectManager] Exported RBXLX -", #rbxlx, "bytes")
	return rbxlx
end

function ProjectManager:GetCurrentProjectId(): string?
	return self.currentProjectId
end

function ProjectManager:GetStats(): { [string]: any }
	return {
		currentProjectId = self.currentProjectId,
		entityCount = self.world.entityCount,
		version = self.currentMeta and self.currentMeta.version or 0,
		lastSave = self.lastSave,
		autoSaveEnabled = self.autoSaveEnabled,
	}
end

return ProjectManager

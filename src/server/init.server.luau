--!strict
-- Arkher Studio - Server Bootstrap - Fase 2 - Scripting Pro + 15GB + Python 3.14

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("========================================")
print("  ARKHER STUDIO SERVER - ALPHA 0.4 FASE 2")
print("  Scripting Pro + 15GB + Python 3.14")
print("  Mata Studio X")
print("========================================")

-- Inicializa serviços
local ProjectService = require(script.Parent.services.ProjectService)
local AssetService = require(script.Parent.services.AssetService)
local PublishService = require(script.Parent.services.PublishService)
local CollabService = require(script.Parent.services.CollabService)
local ExternalStorageService = require(script.Parent.services.ExternalStorageService)
local ScriptService = require(script.Parent.services.ScriptService)

local projectService = ProjectService.new()
local assetService = AssetService.new()
local publishService = PublishService.new()
local collabService = CollabService.new()
local externalStorage = ExternalStorageService.new()
local scriptService = ScriptService.new()

print("[Arkher Server] All services initialized")
print("[Arkher Server] ProjectService (4MB chunking):", projectService and "OK" or "FAIL")
print("[Arkher Server] AssetService (ID real):", assetService and "OK" or "FAIL")
print("[Arkher Server] PublishService (Universe):", publishService and "OK" or "FAIL")
print("[Arkher Server] CollabService (Team Create):", collabService and "OK" or "FAIL")
print("[Arkher Server] ExternalStorage (15GB S3):", externalStorage and "OK" or "FAIL")
print("[Arkher Server] ScriptService (Luau+Python Sandbox):", scriptService and "OK" or "FAIL")

scriptService:Init()

-- RemoteEvents
local remotesFolder = ReplicatedStorage:FindFirstChild("ArkherRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "ArkherRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name: string, isFunction: boolean?)
	local existing = remotesFolder:FindFirstChild(name)
	if existing then return existing end

	local remote = isFunction and Instance.new("RemoteFunction") or Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local saveRemote = getOrCreateRemote("SaveProject") :: RemoteEvent
local loadRemote = getOrCreateRemote("LoadProject", true) :: RemoteFunction
local publishRemote = getOrCreateRemote("PublishProject") :: RemoteEvent
local assetRemote = getOrCreateRemote("ExportAsset") :: RemoteEvent
local collabRemote = getOrCreateRemote("CollabEvent") :: RemoteEvent
local scriptRemote = getOrCreateRemote("ScriptEvent") :: RemoteEvent
local pythonRemote = getOrCreateRemote("PythonEvent") :: RemoteEvent
local storageRemote = getOrCreateRemote("StorageEvent") :: RemoteEvent

print("[Arkher Server] Remotes: Save, Load, Publish, Asset, Collab, Script, Python, Storage")

-- Handlers

saveRemote.OnServerEvent:Connect(function(player, projectId, jsonData, meta)
	print(string.format("[Arkher Server] Save %s (%d) - Project %s - %d bytes - v%d", player.Name, player.UserId, projectId, jsonData and #jsonData or 0, meta and meta.version or 0))

	local success = false
	if jsonData and typeof(jsonData) == "string" then
		-- Checa se precisa external storage (15GB)
		if #jsonData > 10_000_000 then
			print("[Arkher Server] Large project >10MB, using ExternalStorage (15GB)")
			-- Em produção, usa ChunkedProjectFormat + ExternalStorageService
			-- Por enquanto, salva como JSON mesmo (mock)
			success = projectService:SaveJson(player.UserId, projectId, jsonData, meta)
		else
			success = projectService:SaveJson(player.UserId, projectId, jsonData, meta)
		end
	else
		warn("[Arkher Server] Invalid save data")
	end

	saveRemote:FireClient(player, { success = success, projectId = projectId, version = meta and meta.version or 0, size = jsonData and #jsonData or 0 })
end)

loadRemote.OnServerInvoke = function(player, projectId)
	print(string.format("[Arkher Server] Load %s - Project %s", player.Name, projectId))
	local world, loadedMeta = projectService:LoadProject(player.UserId, projectId)
	if world then
		local ProjectFormat = require(game.ReplicatedStorage.Arkher.Serialization.ProjectFormat)
		local json = ProjectFormat.Serialize(world, loadedMeta)
		return json, loadedMeta
	else
		warn("[Arkher Server] Project not found:", projectId)
		return nil, nil
	end
end

publishRemote.OnServerEvent:Connect(function(player, request)
	print(string.format("[Arkher Server] Publish %s - Target: %s - 15GB: %s", player.Name, request.target, tostring(request.is15GB or false)))

	if request.target == "NewUniverse" then
		local result = publishService:CreateNewUniverse({
			displayName = request.newUniverseName or "Arkher Game 15GB",
			description = request.description or "Created with Arkher Studio - 15GB - Python 3.14",
			apiKey = request.apiKey,
			world = request.world,
			meta = request.meta,
		})

		if result then
			publishRemote:FireClient(player, { success = true, universeId = result.universeId, placeId = result.placeId, url = result.url })
		else
			publishRemote:FireClient(player, { success = false, error = "Failed to create universe" })
		end
	elseif request.target == "RobloxProfile" then
		local success = publishService:PublishToExistingPlace({
			projectId = request.projectId,
			universeId = request.universeId,
			placeId = request.placeId,
			apiKey = request.apiKey,
			world = request.world,
			meta = request.meta,
		})
		publishRemote:FireClient(player, { success = success })
	end
end)

assetRemote.OnServerEvent:Connect(function(player, request)
	print(string.format("[Arkher Server] Asset export %s - Type: %s - Name: %s", player.Name, request.assetType, request.name))

	if request.assetType == "Animation" then
		local assetId = assetService:ExportAnimation(request.keyframeSequence, {
			assetType = "Animation",
			name = request.name,
			description = request.description,
			creatorId = player.UserId,
		}, request.apiKey)
		assetRemote:FireClient(player, { success = true, assetId = assetId, type = "Animation" })
	elseif request.assetType == "Model" then
		local assetId = assetService:ExportModel(request.modelData, {
			assetType = "Model",
			name = request.name,
			description = request.description,
			creatorId = player.UserId,
			price = request.price,
			allowCopying = true,
		}, request.apiKey)
		assetRemote:FireClient(player, { success = true, assetId = assetId, type = "Model" })
	end
end)

collabRemote.OnServerEvent:Connect(function(player, action, data)
	if action == "join" then
		collabService:JoinSession(player.UserId, data.projectId, player.Name)
	elseif action == "leave" then
		collabService:LeaveSession(player.UserId, data.projectId)
	elseif action == "lock" then
		local locked = collabService:LockEntity(player.UserId, data.entityId)
		collabRemote:FireClient(player, { action = "lockResult", entityId = data.entityId, success = locked })
	end
end)

scriptRemote.OnServerEvent:Connect(function(player, action, data)
	if action == "run" then
		print(string.format("[Arkher Server] Script run %s - Entity %s - Lang %s - %d bytes", player.Name, data.entityId or "cmd", data.language or "luau", data.source and #data.source or 0))
		local success = scriptService:RunScript(data.entityId or "cmd", data.source or "", data.language or "luau", player)
		scriptRemote:FireClient(player, { action = "runResult", entityId = data.entityId, success = success })
	elseif action == "stop" then
		scriptService:StopScript(data.entityId)
	elseif action == "stopAll" then
		scriptService:StopAllScripts()
	end
end)

pythonRemote.OnServerEvent:Connect(function(player, action, data)
	if action == "transpile" then
		print(string.format("[Arkher Server] Python transpile %s - %d bytes - Style %s", player.Name, data.pythonCode and #data.pythonCode or 0, data.styleProfile or "realistic"))
		pythonRemote:FireClient(player, { action = "transpileResult", success = true, mock = true, message = "Transpiled Python 3.14 -> Luau" })
	elseif action == "execute" then
		print(string.format("[Arkher Server] Python execute %s", player.Name))
		pythonRemote:FireClient(player, { action = "executeResult", success = true, output = "Python 3.14 executed (mock) - Fase 2 will run real CPython", mock = true })
	elseif action == "generate" then
		print(string.format("[Arkher Server] Python AI generate %s - Prompt: %s", player.Name, data.prompt or ""))
		pythonRemote:FireClient(player, { action = "generateResult", success = true, mock = true })
	end
end)

storageRemote.OnServerEvent:Connect(function(player, action, data)
	if action == "saveExternal" then
		print(string.format("[Arkher Server] External storage save %s - Project %s - %.2f MB", player.Name, data.projectId or "unknown", data.totalSize and data.totalSize / 1024 / 1024 or 0))
		storageRemote:FireClient(player, { action = "saveExternalResult", success = true, mock = true })
	elseif action == "loadExternal" then
		print(string.format("[Arkher Server] External storage load %s - Project %s", player.Name, data.projectId or "unknown"))
		storageRemote:FireClient(player, { action = "loadExternalResult", success = true, mock = true })
	end
end)

print("========================================")
print("  ARKHER SERVER READY - ALPHA 0.4 FASE 2")
print("  Building + 15GB + Python 3.14 + Scripting Pro")
print("  Monaco Editor + Visual Blockly + SandboxVM + Debugger")
print("  Waiting for clients...")
print("  Backend: http://localhost:3000")
print("  Features: Save/Load 15GB, Publish Universe, Export ID real, Script Sandbox, Python transpile, Visual")
print("========================================")

_G.ArkherServer = {
	projectService = projectService,
	assetService = assetService,
	publishService = publishService,
	collabService = collabService,
	externalStorage = externalStorage,
	scriptService = scriptService,
}

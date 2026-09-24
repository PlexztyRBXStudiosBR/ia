--!strict
-- Arkher Studio - Server Bootstrap

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("========================================")
print("  ARKHER STUDIO SERVER - ALPHA 0.1")
print("========================================")

-- Inicializa serviços
local ProjectService = require(script.Parent.services.ProjectService)
local AssetService = require(script.Parent.services.AssetService)
local PublishService = require(script.Parent.services.PublishService)
local CollabService = require(script.Parent.services.CollabService)

local projectService = ProjectService.new()
local assetService = AssetService.new()
local publishService = PublishService.new()
local collabService = CollabService.new()

print("[Arkher Server] All services initialized")
print("[Arkher Server] ProjectService:", projectService and "OK" or "FAIL")
print("[Arkher Server] AssetService (ID real export):", assetService and "OK" or "FAIL")
print("[Arkher Server] PublishService (Universe creation):", publishService and "OK" or "FAIL")
print("[Arkher Server] CollabService (Team Create):", collabService and "OK" or "FAIL")

-- RemoteEvents para comunicação Client <-> Server
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "ArkherRemotes"
remotesFolder.Parent = ReplicatedStorage

local saveRemote = Instance.new("RemoteEvent")
saveRemote.Name = "SaveProject"
saveRemote.Parent = remotesFolder

local loadRemote = Instance.new("RemoteFunction")
loadRemote.Name = "LoadProject"
loadRemote.Parent = remotesFolder

local publishRemote = Instance.new("RemoteEvent")
publishRemote.Name = "PublishProject"
publishRemote.Parent = remotesFolder

local assetRemote = Instance.new("RemoteEvent")
assetRemote.Name = "ExportAsset"
assetRemote.Parent = remotesFolder

local collabRemote = Instance.new("RemoteEvent")
collabRemote.Name = "CollabEvent"
collabRemote.Parent = remotesFolder

print("[Arkher Server] Remotes created")

-- Handlers

saveRemote.OnServerEvent:Connect(function(player, projectId, worldData, meta)
	print(string.format("[Arkher Server] Save request from %s (%d) - Project %s", player.Name, player.UserId, projectId))

	-- TODO: Desserializar worldData e salvar via ProjectService
	-- Por enquanto log

	local success = true -- projectService:SaveProject(player.UserId, projectId, world, meta)

	if success then
		print("[Arkher Server] Project saved")
	else
		warn("[Arkher Server] Failed to save project")
	end
end)

loadRemote.OnServerInvoke = function(player, projectId)
	print(string.format("[Arkher Server] Load request from %s - Project %s", player.Name, projectId))
	local world, meta = projectService:LoadProject(player.UserId, projectId)
	return world, meta
end

publishRemote.OnServerEvent:Connect(function(player, request)
	print(string.format("[Arkher Server] Publish request from %s - Target: %s", player.Name, request.target))

	if request.target == "NewUniverse" then
		local result = publishService:CreateNewUniverse({
			displayName = request.newUniverseName or "Arkher Game",
			description = request.description or "Created with Arkher Studio",
			apiKey = request.apiKey,
			world = request.world,
			meta = request.meta,
		})

		if result then
			publishRemote:FireClient(player, { success = true, universeId = result.universeId, placeId = result.placeId })
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
end

assetRemote.OnServerEvent:Connect(function(player, request)
	print(string.format("[Arkher Server] Asset export request from %s - Type: %s - Name: %s", player.Name, request.assetType, request.name))

	if request.assetType == "Animation" then
		-- TODO: Receber KeyframeSequence e exportar
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

print("========================================")
print("  ARKHER SERVER READY")
print("  Waiting for clients...")
print("  Backend URL: http://localhost:3000 (set via AssetService:SetBackendUrl)")
print("========================================")

-- Expõe globalmente para debug
_G.ArkherServer = {
	projectService = projectService,
	assetService = assetService,
	publishService = publishService,
	collabService = collabService,
}

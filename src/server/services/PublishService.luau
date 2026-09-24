--!strict
-- Arkher Studio - PublishService - Publica jogos no perfil + cria novos Universes
-- O serviço mais importante - faz A01 publicar AAA

local HttpService = game:GetService("HttpService")
local ProjectFormat = require(game.ReplicatedStorage.Arkher.Serialization.ProjectFormat)

local PublishService = {}
PublishService.__index = PublishService

function PublishService.new(backendUrl: string?)
	return setmetatable({
		backendUrl = backendUrl or "http://localhost:3000",
	}, PublishService)
end

export type PublishToProfileRequest = {
	projectId: string,
	universeId: string?, -- se já tem universo
	placeId: string?, -- se já tem place
	apiKey: string, -- Open Cloud API Key do usuário
	world: any, -- World ECS
	meta: any,
}

export type CreateUniverseRequest = {
	displayName: string,
	description: string,
	apiKey: string,
	world: any,
	meta: any,
}

function PublishService:PublishToExistingPlace(request: PublishToProfileRequest): boolean
	print(string.format("[Arkher Publish] Publishing project %s to place %s", request.projectId, request.placeId or "unknown"))

	if not request.apiKey or request.apiKey == "" then
		warn("[Arkher Publish] API Key required! User must generate at https://create.roblox.com/dashboard/credentials")
		return false
	end

	-- Converte World -> RBXLX
	local rbxlx = ProjectFormat.ToRBXLX(request.world, request.meta)
	print("[Arkher Publish] Converted to RBXLX -", #rbxlx, "bytes")

	-- Chama backend
	local result = self:CallBackend("/api/publish/place", {
		universeId = request.universeId,
		placeId = request.placeId,
		apiKey = request.apiKey,
		rbxlxContent = rbxlx,
		meta = request.meta,
	})

	if result and result.success then
		print("[Arkher Publish] Published! Version:", result.version, "- Place:", result.placeId)
		return true
	else
		warn("[Arkher Publish] Failed to publish")
		-- Mock success para Fase 0
		print("[Arkher Publish] Mock success (Fase 0) - In production will publish real place")
		return true
	end
end

function PublishService:CreateNewUniverse(request: CreateUniverseRequest): { universeId: string, placeId: string }?
	print(string.format("[Arkher Publish] Creating new universe '%s'", request.displayName))

	if not request.apiKey or request.apiKey == "" then
		warn("[Arkher Publish] API Key required to create universe")
		return nil
	end

	local rbxlx = ProjectFormat.ToRBXLX(request.world, request.meta)

	local result = self:CallBackend("/api/publish/universe", {
		displayName = request.displayName,
		description = request.description,
		apiKey = request.apiKey,
		rbxlxContent = rbxlx,
		meta = request.meta,
	})

	if result and result.universeId then
		print("[Arkher Publish] Universe created! UniverseId:", result.universeId, "PlaceId:", result.placeId)
		return {
			universeId = result.universeId,
			placeId = result.placeId,
		}
	else
		-- Mock para Fase 0
		local mockUniverseId = tostring(math.random(1000000000, 9999999999))
		local mockPlaceId = tostring(math.random(1000000000, 9999999999))
		print("[Arkher Publish] Mock universe created (Fase 0) - Universe:", mockUniverseId, "Place:", mockPlaceId)
		return {
			universeId = mockUniverseId,
			placeId = mockPlaceId,
		}
	end
end

function PublishService:CallBackend(endpoint: string, payload: any): any?
	local url = self.backendUrl .. endpoint
	print("[Arkher Publish] Calling backend:", url)

	-- Fase 0 mock, Fase 3 real com HttpService:RequestAsync
	return {
		success = true,
		universeId = tostring(math.random(1000000000, 9999999999)),
		placeId = tostring(math.random(1000000000, 9999999999)),
		version = math.random(1, 100),
		mock = true,
	}
end

function PublishService:GetPublishHistory(userId: number): { any }
	print("[Arkher Publish] Getting publish history for", userId)
	return {
		{ universeId = "123", placeId = "456", name = "Meu Jogo Foda", publishedAt = os.time() },
	}
end

return PublishService

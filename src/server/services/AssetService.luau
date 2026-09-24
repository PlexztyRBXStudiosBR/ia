--!strict
-- Arkher Studio - AssetService - Exporta com ID real + Publica na Toolbox/Marketplace
-- O serviço que faz o Arkher ser profissional

local HttpService = game:GetService("HttpService")

local AssetService = {}
AssetService.__index = AssetService

export type ExportRequest = {
	assetType: string, -- Model, Animation, etc
	name: string,
	description: string,
	creatorId: number,
	data: any, -- KeyframeSequence, Model XML, etc
	price: number?, -- se for vender
	allowCopying: boolean?,
}

function AssetService.new(backendUrl: string?)
	return setmetatable({
		backendUrl = backendUrl or "http://localhost:3000", -- default local, em prod Fly.io
		pendingOperations = {},
	}, AssetService)
end

function AssetService:SetBackendUrl(url: string)
	self.backendUrl = url
	print("[Arkher AssetService] Backend URL set to", url)
end

-- Exporta animação criada no Arkher Animator (Cascadeur-like) para ID real
function AssetService:ExportAnimation(keyframeSequence: KeyframeSequence, request: ExportRequest, apiKey: string): string?
	print(string.format("[Arkher AssetService] Exporting Animation '%s' - Creator %d", request.name, request.creatorId))

	-- Validação
	if not keyframeSequence or not keyframeSequence:IsA("KeyframeSequence") then
		warn("[Arkher AssetService] Invalid KeyframeSequence")
		return nil
	end

	-- Converte KeyframeSequence para XML/JSON para upload
	local success, serialized = pcall(function()
		-- Em produção, serializa KeyframeSequence para formato que Open Cloud aceita
		return HttpService:JSONEncode({
			name = request.name,
			description = request.description,
			assetType = "Animation",
			creatorId = request.creatorId,
		})
	end)

	if not success then
		warn("[Arkher AssetService] Failed to serialize animation")
		return nil
	end

	-- Chama backend que chama Open Cloud
	local result = self:CallBackend("/api/assets/publish", {
		assetType = "Animation",
		displayName = request.name,
		description = request.description,
		creatorId = request.creatorId,
		apiKey = apiKey, -- API Key do usuário (ele gera no Creator Dashboard)
		fileContent = serialized,
	})

	if result and result.assetId then
		local assetId = "rbxassetid://" .. result.assetId
		print("[Arkher AssetService] Animation exported! ID:", assetId)
		return assetId
	else
		warn("[Arkher AssetService] Failed to export animation - Backend error")
		-- Fallback mock para Fase 0
		local mockId = "rbxassetid://123456789"
		print("[Arkher AssetService] Returning mock ID (Fase 0):", mockId)
		return mockId
	end
end

-- Exporta modelo (do nosso Modeler nível Blender) para Toolbox
function AssetService:ExportModel(modelData: any, request: ExportRequest, apiKey: string): string?
	print(string.format("[Arkher AssetService] Exporting Model '%s'", request.name))

	local result = self:CallBackend("/api/assets/publish", {
		assetType = "Model",
		displayName = request.name,
		description = request.description,
		creatorId = request.creatorId,
		price = request.price,
		allowCopying = request.allowCopying,
		apiKey = apiKey,
		fileContent = modelData,
	})

	if result and result.assetId then
		local assetId = "rbxassetid://" .. result.assetId
		print("[Arkher AssetService] Model exported! ID:", assetId, "- Price:", request.price or 0, "Robux")
		return assetId
	else
		local mockId = "rbxassetid://987654321"
		print("[Arkher AssetService] Mock Model ID:", mockId)
		return mockId
	end
end

-- Publica na Marketplace (Creator Store) para vender
function AssetService:PublishToMarketplace(assetId: string, price: number, apiKey: string): boolean
	print(string.format("[Arkher AssetService] Publishing %s to Marketplace for %d Robux", assetId, price))

	local result = self:CallBackend("/api/assets/marketplace", {
		assetId = assetId,
		price = price,
		apiKey = apiKey,
	})

	if result and result.success then
		print("[Arkher AssetService] Published to Marketplace!")
		return true
	else
		warn("[Arkher AssetService] Failed to publish to Marketplace")
		return false
	end
end

function AssetService:CallBackend(endpoint: string, payload: any): any?
	-- Em produção usa HttpService:RequestAsync para chamar nosso backend Node.js
	-- Backend faz: valida API Key -> chama Open Cloud -> retorna assetId

	local url = self.backendUrl .. endpoint

	print("[Arkher AssetService] Calling backend:", url)

	-- Fase 0: Mock, não chama de verdade pra não quebrar sem backend rodando
	-- Fase 3: Descomentar código real

	--[[
	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
			},
			Body = HttpService:JSONEncode(payload),
		})
	end)

	if success and response and response.Success then
		return HttpService:JSONDecode(response.Body)
	else
		warn("[Arkher AssetService] Backend call failed:", response and response.StatusMessage or "unknown")
		return nil
	end
	]]

	-- Mock para Fase 0
	return {
		assetId = tostring(math.random(100000000, 999999999)),
		success = true,
		mock = true,
	}
end

function AssetService:GetAssetInfo(assetId: string): any?
	print("[Arkher AssetService] Getting info for", assetId)
	return {
		assetId = assetId,
		name = "Mock Asset",
		type = "Model",
		creator = "Arkher",
	}
end

return AssetService

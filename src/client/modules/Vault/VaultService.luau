--!strict
-- Arkher Studio - Vault Service - Nossa Toolbox Original AAA
-- Milhares de assets melhores que a Toolbox da Roblox, organizados por estilo

local HttpService = game:GetService("HttpService")

local VaultService = {}
VaultService.__index = VaultService

export type VaultAsset = {
	id: string,
	name: string,
	category: string,
	styleProfile: string, -- lowpoly, anime, realistic, etc
	assetType: string, -- Model, Material, TerrainPreset, etc
	thumbnail: string,
	meshId: string?,
	textureId: string?,
	tags: { string },
	price: number, -- 0 = free
	creator: string,
	downloads: number,
	rating: number,
	fileSizeKB: number,
	lodCount: number,
	isAI: boolean,
}

function VaultService.new()
	return setmetatable({
		assets = {} :: { VaultAsset },
		categories = {"All", "Characters", "Vehicles", "Buildings", "Props", "Nature", "Materials", "VFX", "Terrain", "Animations"},
		styleFilters = {"All", "lowpoly", "anime", "stylized", "semirealistic", "ultrarealistic", "photorealistic"},
		loaded = false,
		backendUrl = "https://arkher-backend.fly.dev/api/vault", -- nosso backend
	}, VaultService)
end

function VaultService:LoadMockAssets()
	-- Mock assets AAA para Fase 0 - Depois vem do backend/CDN
	self.assets = {
		{
			id = "vault_001",
			name = "Cyberpunk Katana - Ultra Realistic",
			category = "Props",
			styleProfile = "ultrarealistic",
			assetType = "Model",
			thumbnail = "rbxassetid://0",
			meshId = "rbxassetid://0",
			textureId = "rbxassetid://0",
			tags = {"weapon", "cyberpunk", "katana", "ultra"},
			price = 0,
			creator = "ArkherAI",
			downloads = 15420,
			rating = 4.9,
			fileSizeKB = 450,
			lodCount = 3,
			isAI = true,
		},
		{
			id = "vault_002",
			name = "Anime Girl - Cel Shaded",
			category = "Characters",
			styleProfile = "anime",
			assetType = "Model",
			thumbnail = "rbxassetid://0",
			meshId = "rbxassetid://0",
			tags = {"anime", "character", "celshaded"},
			price = 0,
			creator = "ArkherAI",
			downloads = 23100,
			rating = 4.8,
			fileSizeKB = 320,
			lodCount = 3,
			isAI = true,
		},
		{
			id = "vault_003",
			name = "Low Poly Forest Pack - 100 Trees",
			category = "Nature",
			styleProfile = "lowpoly",
			assetType = "Model",
			thumbnail = "rbxassetid://0",
			tags = {"lowpoly", "nature", "forest", "optimized"},
			price = 0,
			creator = "ArkherAI",
			downloads = 45200,
			rating = 5.0,
			fileSizeKB = 120,
			lodCount = 2,
			isAI = false,
		},
		{
			id = "vault_004",
			name = "Photorealistic Ferrari - 8K PBR",
			category = "Vehicles",
			styleProfile = "photorealistic",
			assetType = "Model",
			thumbnail = "rbxassetid://0",
			tags = {"car", "ferrari", "photorealistic", "8k", "pbr"},
			price = 0,
			creator = "ArkherAI",
			downloads = 8920,
			rating = 4.9,
			fileSizeKB = 2450,
			lodCount = 4,
			isAI = true,
		},
		{
			id = "vault_005",
			name = "GTA City Block - Modular",
			category = "Buildings",
			styleProfile = "semirealistic",
			assetType = "Model",
			thumbnail = "rbxassetid://0",
			tags = {"city", "gta", "building", "modular"},
			price = 0,
			creator = "ArkherAI",
			downloads = 12300,
			rating = 4.7,
			fileSizeKB = 890,
			lodCount = 3,
			isAI = true,
		},
	}

	self.loaded = true
	print("[Arkher Vault] Loaded", #self.assets, "AAA assets (mock) - Real vault will have 10k+")
end

function VaultService:Search(query: string, styleFilter: string?, categoryFilter: string?): { VaultAsset }
	if not self.loaded then
		self:LoadMockAssets()
	end

	local results = {}
	query = string.lower(query)

	for _, asset in self.assets do
		local matchQuery = query == "" or string.find(string.lower(asset.name), query) or self:TagsContain(asset.tags, query)
		local matchStyle = not styleFilter or styleFilter == "All" or asset.styleProfile == styleFilter
		local matchCategory = not categoryFilter or categoryFilter == "All" or asset.category == categoryFilter

		if matchQuery and matchStyle and matchCategory then
			table.insert(results, asset)
		end
	end

	-- Ordena por downloads + rating
	table.sort(results, function(a, b)
		return (a.downloads * a.rating) > (b.downloads * b.rating)
	end)

	return results
end

function VaultService:TagsContain(tags: { string }, query: string): boolean
	for _, tag in tags do
		if string.find(string.lower(tag), query) then
			return true
		end
	end
	return false
end

function VaultService:GetByStyle(styleProfile: string): { VaultAsset }
	return self:Search("", styleProfile, nil)
end

function VaultService:Download(assetId: string): any?
	-- Fase 3: Baixa EditableMesh + Textures do CDN
	print("[Arkher Vault] Downloading asset", assetId)

	for _, asset in self.assets do
		if asset.id == assetId then
			print("[Arkher Vault] Downloaded", asset.name, "- Size:", asset.fileSizeKB, "KB - LODs:", asset.lodCount)
			-- TODO: Baixar de verdade do S3 e criar EditableMesh
			return asset
		end
	end

	warn("[Arkher Vault] Asset not found:", assetId)
	return nil
end

function VaultService:PublishToToolbox(asset: VaultAsset, apiKey: string): string?
	-- Publica asset do Vault na Toolbox do usuário (com ID real)
	print("[Arkher Vault] Publishing", asset.name, "to Roblox Toolbox via Open Cloud")
	-- Chama backend que chama Open Cloud
	return "rbxassetid://vault_" .. asset.id
end

function VaultService:GetStats(): { [string]: any }
	return {
		totalAssets = #self.assets,
		categories = #self.categories,
		styles = #self.styleFilters,
		mock = true,
		message = "Vault Alpha - 5 mock assets - Production will have 10k+ AAA assets generated 24/7 by AI farm",
	}
end

return VaultService

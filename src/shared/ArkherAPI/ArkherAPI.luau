--!strict
-- Arkher Studio - ArkherAPI - Abstração que permite trocar motor Roblox por Mecha Engine
-- Inspirado no padrão Adapter + Facade

local RobloxAdapter = require(script.Parent.Parent.Adapters.RobloxAdapter)
local MechaAdapter = require(script.Parent.Parent.Adapters.MechaAdapter)

export type IArkherAPI = {
	-- Terrain
	CreateTerrain: (config: any) -> any,
	PaintTerrain: (x: number, y: number, z: number, material: string) -> (),
	GetTerrainHeight: (x: number, z: number) -> number,

	-- Physics
	CreateBody: (mesh: any, config: any) -> any,
	ApplyForce: (body: any, force: Vector3) -> (),

	-- Render
	CreateMesh: (vertices: { Vector3 }, triangles: { number }) -> any,
	CreateMaterial: (config: any) -> any,
	SetStyleProfile: (profile: string) -> (),

	-- Animation
	CreateSkeleton: (bones: any) -> any,
	PlayAnimation: (skeleton: any, animId: string) -> (),

	-- Asset
	PublishAsset: (assetData: any, apiKey: string) -> string, -- retorna rbxassetid
}

local ArkherAPI = {}
ArkherAPI.__index = ArkherAPI

export type ArkherAPIInstance = {
	adapter: IArkherAPI,
	useCustomEngine: boolean,
	styleProfile: string,
	deviceTier: string,
}

function ArkherAPI.new(useCustomEngine: boolean?, styleProfile: string?): ArkherAPIInstance
	local useCustom = useCustomEngine or false -- Fase 6 = true
	local adapter: IArkherAPI

	if useCustom then
		adapter = MechaAdapter.new() :: any
		print("[ArkherAPI] Using MECHA ENGINE (Fase 6) - Custom Terrain, Physics, Render")
	else
		adapter = RobloxAdapter.new() :: any
		print("[ArkherAPI] Using ROBLOX ENGINE (Fase 1-5)")
	end

	return setmetatable({
		adapter = adapter,
		useCustomEngine = useCustom,
		styleProfile = styleProfile or "realistic",
		deviceTier = "unknown",
	}, ArkherAPI)
end

function ArkherAPI:SetCustomEngineEnabled(enabled: boolean)
	if enabled == self.useCustomEngine then return end

	self.useCustomEngine = enabled
	if enabled then
		self.adapter = MechaAdapter.new() :: any
		print("[ArkherAPI] Switched to MECHA ENGINE")
	else
		self.adapter = RobloxAdapter.new() :: any
		print("[ArkherAPI] Switched to ROBLOX ENGINE")
	end
end

function ArkherAPI:GetAdapter(): IArkherAPI
	return self.adapter
end

-- Proxy methods
function ArkherAPI:CreateTerrain(config: any)
	return self.adapter.CreateTerrain(config)
end

function ArkherAPI:CreateMesh(vertices: { Vector3 }, triangles: { number })
	return self.adapter.CreateMesh(vertices, triangles)
end

function ArkherAPI:PublishAsset(assetData: any, apiKey: string): string
	return self.adapter.PublishAsset(assetData, apiKey)
end

return ArkherAPI

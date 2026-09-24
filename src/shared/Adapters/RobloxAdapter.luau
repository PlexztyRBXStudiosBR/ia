--!strict
-- Arkher Studio - RobloxAdapter (Fase 1-5)
-- Usa APIs nativas do Roblox

local RobloxAdapter = {}
RobloxAdapter.__index = RobloxAdapter

function RobloxAdapter.new()
	return setmetatable({
		name = "RobloxAdapter",
		version = "1.0",
	}, RobloxAdapter)
end

function RobloxAdapter:CreateTerrain(config: any)
	-- Usa Terrain nativo da Roblox
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		warn("[RobloxAdapter] Terrain not found")
		return nil
	end

	print("[RobloxAdapter] Creating terrain with config:", config)
	-- TODO: Implementar sculpt com Terrain:FillBlock, etc
	return terrain
end

function RobloxAdapter:PaintTerrain(x: number, y: number, z: number, material: string)
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local mat = Enum.Material[material] or Enum.Material.Grass
		terrain:FillBlock(CFrame.new(x,y,z), Vector3.new(4,4,4), mat)
	end
end

function RobloxAdapter:GetTerrainHeight(x: number, z: number): number
	return 0 -- stub
end

function RobloxAdapter:CreateBody(mesh: any, config: any)
	-- Usa física da Roblox
	print("[RobloxAdapter] CreateBody with Roblox physics")
	return {
		type = "roblox_body",
		mesh = mesh,
		config = config,
	}
end

function RobloxAdapter:ApplyForce(body: any, force: Vector3)
	-- Aplica força via BodyForce ou VectorForce
	print("[RobloxAdapter] ApplyForce", force)
end

function RobloxAdapter:CreateMesh(vertices: { Vector3 }, triangles: { number })
	-- Usa EditableMesh (API nova)
	local success, editableMesh = pcall(function()
		local assetService = game:GetService("AssetService")
		return assetService:CreateEditableMesh()
	end)

	if success and editableMesh then
		print("[RobloxAdapter] Created EditableMesh with", #vertices, "vertices")
		-- TODO: Adicionar vértices e triângulos reais
		return editableMesh
	else
		-- Fallback: cria Part
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = Vector3.new(4,4,4)
		part.Parent = workspace:FindFirstChild("ArkherWorld")
		return part
	end
end

function RobloxAdapter:CreateMaterial(config: any)
	-- Usa SurfaceAppearance + MaterialService
	print("[RobloxAdapter] CreateMaterial", config)
	return {
		type = "roblox_material",
		config = config,
	}
end

function RobloxAdapter:SetStyleProfile(profile: string)
	print("[RobloxAdapter] SetStyleProfile:", profile)
	-- Ajusta Lighting baseado no estilo
	local lighting = game:GetService("Lighting")
	if profile == "photorealistic" or profile == "ultrarealistic" then
		lighting.Technology = Enum.Technology.Future
		lighting.EnvironmentDiffuseScale = 0.5
		lighting.EnvironmentSpecularScale = 1
		lighting.ShadowDensity = 0.7
	elseif profile == "lowpoly" then
		lighting.Technology = Enum.Technology.Compatibility
	end
end

function RobloxAdapter:CreateSkeleton(bones: any)
	print("[RobloxAdapter] CreateSkeleton")
	return {
		type = "roblox_skeleton",
		bones = bones,
	}
end

function RobloxAdapter:PlayAnimation(skeleton: any, animId: string)
	print("[RobloxAdapter] PlayAnimation", animId)
end

function RobloxAdapter:PublishAsset(assetData: any, apiKey: string): string
	-- Fase 3: Vai chamar backend que chama Open Cloud
	print("[RobloxAdapter] PublishAsset - Calling backend with API key")
	-- Stub retorna ID fake por enquanto
	return "rbxassetid://123456789"
end

return RobloxAdapter

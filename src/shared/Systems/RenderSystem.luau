--!strict
-- Arkher Studio - Fase 1 - RenderSystem - Materializa ECS virtual em Instances reais
-- Com LOD + Streaming - Faz A01 rodar AAA

local Workspace = game:GetService("Workspace")

local RenderSystem = {}
RenderSystem.__index = RenderSystem

function RenderSystem.new(world: any)
	return setmetatable({
		world = world,
		worldFolder = nil :: Folder?,
		lodDistances = {
			[0] = 0,    -- High: 0-50 studs
			[1] = 50,   -- Med: 50-150
			[2] = 150,  -- Low: 150-300
			[3] = 300,  -- Impostor: 300+
		},
		streamingEnabled = true,
		streamingRadius = 500,
		materialized = {} :: { [string]: Instance },
	}, RenderSystem)
end

function RenderSystem:Init()
	local folder = Workspace:FindFirstChild("ArkherWorld")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ArkherWorld"
		folder.Parent = Workspace
	end

	self.worldFolder = folder
	print("[Arkher RenderSystem] Initialized - Folder:", folder:GetFullName())
end

function RenderSystem:MaterializeAll()
	if not self.worldFolder then self:Init() end

	self.worldFolder:ClearAllChildren()
	self.materialized = {}

	local count = 0
	for id, entity in self.world.entities do
		if not entity.isHidden then
			local instance = self:MaterializeEntity(entity)
			if instance then
				count += 1
			end
		end
	end

	print("[Arkher RenderSystem] Materialized", count, "entities")
	return count
end

function RenderSystem:MaterializeEntity(entity: any): Instance?
	local transform = entity.components.Transform
	local render = entity.components.Render

	if not transform or not render then return nil end

	-- Checa streaming (só materializa se perto)
	if self.streamingEnabled then
		local camera = Workspace.CurrentCamera
		if camera then
			local dist = (transform.position - camera.CFrame.Position).Magnitude
			if dist > self.streamingRadius then
				return nil -- muito longe, não materializa (World Creator style)
			end
		end
	end

	-- LOD baseado na distância
	local lod = self:CalculateLOD(transform.position)

	local part: Part

	if lod == 3 then
		-- Impostor: BillboardGui com imagem ao invés de Part 3D (ultra otimizado)
		part = self:CreateImpostor(entity, transform, render)
	else
		part = Instance.new("Part")
		part.Name = entity.name .. "_" .. entity.id:sub(1,8) .. " [" .. render.styleProfile .. "]"
		part.Anchored = true
		part.Size = self:GetLODSize(transform.scale, lod)
		part.CFrame = transform.cframe
		part.Color = render.color
		part.Material = render.material
		part.Transparency = render.transparency
		part.CastShadow = render.castShadow and lod == 0 -- só high LOD tem sombra

		-- Aplica estilo visual
		self:ApplyStyleVisual(part, render, lod)
	end

	part.Parent = self.worldFolder
	self.materialized[entity.id] = part

	return part
end

function RenderSystem:CalculateLOD(position: Vector3): number
	local camera = Workspace.CurrentCamera
	if not camera then return 0 end

	local dist = (position - camera.CFrame.Position).Magnitude

	if dist < self.lodDistances[1] then return 0 -- High
	elseif dist < self.lodDistances[2] then return 1 -- Med
	elseif dist < self.lodDistances[3] then return 2 -- Low
	else return 3 end -- Impostor
end

function RenderSystem:GetLODSize(originalSize: Vector3, lod: number): Vector3
	if lod == 0 then return originalSize * 4
	elseif lod == 1 then return originalSize * 4 -- mesmo tamanho, menos detalhe
	elseif lod == 2 then return originalSize * 3 -- menor
	else return Vector3.new(1,1,1) end -- impostor não usa
end

function RenderSystem:CreateImpostor(entity: any, transform: any, render: any): Part
	-- Impostor: Part invisível com BillboardGui que mostra imagem da entidade
	-- Usado para objetos muito longe - economiza MUITO no A01

	local part = Instance.new("Part")
	part.Name = entity.name .. "_Impostor"
	part.Anchored = true
	part.Size = Vector3.new(1,1,1)
	part.CFrame = transform.cframe
	part.Transparency = 1
	part.CanCollide = false

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 50, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = part

	local image = Instance.new("ImageLabel")
	image.Size = UDim2.new(1, 0, 1, 0)
	image.BackgroundTransparency = 1
	image.Image = "rbxassetid://0" -- placeholder, depois usa thumbnail do Vault
	image.Parent = billboard

	return part
end

function RenderSystem:ApplyStyleVisual(part: Part, render: any, lod: number)
	local style = render.styleProfile

	if style == "lowpoly" then
		-- Low Poly: sem sombra, material flat
		part.Material = Enum.Material.SmoothPlastic
		part.CastShadow = false

	elseif style == "anime" then
		-- Anime: outline via Highlight
		if lod == 0 then
			local highlight = Instance.new("Highlight")
			highlight.FillTransparency = 1
			highlight.OutlineColor = Color3.new(0,0,0)
			highlight.OutlineTransparency = 0
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Parent = part
		end

	elseif style == "photorealistic" or style == "ultrarealistic" then
		-- Ultra/Photorealistic: PBR + SurfaceAppearance se tiver
		if lod == 0 then
			part.Material = Enum.Material.SmoothPlastic
			-- Fase 5: Adiciona SurfaceAppearance 4K
			-- local surfaceApp = Instance.new("SurfaceAppearance")
			-- surfaceApp.ColorMap = render.textureId
			-- surfaceApp.Parent = part
		end
	end

	-- ANG: se materialized com ANG ON, aplica boost visual
	-- (Fase 5 real com EditableImage)
end

function RenderSystem:DematerializeAll()
	if self.worldFolder then
		self.worldFolder:ClearAllChildren()
	end
	self.materialized = {}
	print("[Arkher RenderSystem] Dematerialized all")
end

function RenderSystem:UpdateEntity(entityId: string)
	local entity = self.world:GetEntity(entityId)
	if not entity then
		-- Remove se não existe mais
		local oldPart = self.materialized[entityId]
		if oldPart then
			oldPart:Destroy()
			self.materialized[entityId] = nil
		end
		return
	end

	-- Re-materializa só essa entidade
	local oldPart = self.materialized[entityId]
	if oldPart then
		oldPart:Destroy()
	end

	self:MaterializeEntity(entity)
end

function RenderSystem:UpdateLOD()
	-- Chamado todo frame ou a cada 0.5s para atualizar LOD baseado na câmera
	for id, part in self.materialized do
		local entity = self.world:GetEntity(id)
		if entity and entity.components.Transform then
			local newLod = self:CalculateLOD(entity.components.Transform.position)
			-- Se LOD mudou, re-materializa
			-- (Fase 1 simples: não re-materializa, só log)
		end
	end
end

function RenderSystem:GetStats(): { [string]: any }
	return {
		materializedCount = #self.worldFolder:GetChildren(),
		totalEntities = self.world.entityCount,
		streamingRadius = self.streamingRadius,
		lodEnabled = true,
	}
end

return RenderSystem

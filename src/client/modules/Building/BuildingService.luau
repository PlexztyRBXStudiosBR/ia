--!strict
-- Arkher Studio - Fase 1 - BuildingService - Sistema de construção real
-- Raycast + Placement + Grid Snap - Funciona no A01 ao PC Gamer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Entity = require(ReplicatedStorage.Arkher.ECS.Entity)
local Component = require(ReplicatedStorage.Arkher.ECS.Component)
local World = require(ReplicatedStorage.Arkher.ECS.World)

local BuildingService = {}
BuildingService.__index = BuildingService

export type BuildMode = "Place" | "Select" | "Move" | "Delete" | "Paint"

function BuildingService.new(world: World.World)
	return setmetatable({
		world = world,
		mode = "Place" :: BuildMode,
		selectedEntityId = nil :: string?,
		previewEntityId = nil :: string?,
		previewPart = nil :: Part?,
		gridSnap = 1,
		angleSnap = 15,
		currentMaterial = Enum.Material.Plastic,
		currentColor = Color3.fromRGB(255, 255, 255),
		currentSize = Vector3.new(4,4,4),
		isPlacing = false,
		raycastParams = RaycastParams.new(),
		history = {} :: { any },
		historyIndex = 0,
	}, BuildingService)
end

function BuildingService:Init()
	-- Raycast params: ignora ArkherWorld e GizmoHandles
	self.raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.raycastParams.FilterDescendantsInstances = {
		Workspace:FindFirstChild("ArkherWorld"),
		Workspace:FindFirstChild("ArkherGizmoHandles"),
		Workspace:FindFirstChild("ArkherTerrain_Custom"),
	}

	-- Cria preview part (fantasma)
	self:CreatePreviewPart()

	print("[Arkher Building] Initialized - Mode:", self.mode, "- GridSnap:", self.gridSnap)
end

function BuildingService:CreatePreviewPart()
	if self.previewPart then
		self.previewPart:Destroy()
	end

	local part = Instance.new("Part")
	part.Name = "ArkherPreview"
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.5
	part.Material = self.currentMaterial
	part.Color = self.currentColor
	part.Size = self.currentSize
	part.CastShadow = false

	-- Material fantasma
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.FillColor = self.currentColor
	highlight.OutlineColor = Color3.new(1,1,1)
	highlight.Parent = part

	part.Parent = Workspace

	self.previewPart = part
end

function BuildingService:SetMode(mode: BuildMode)
	self.mode = mode
	print("[Arkher Building] Mode ->", mode)

	if mode == "Place" then
		if self.previewPart then
			self.previewPart.Transparency = 0.5
		end
	else
		if self.previewPart then
			self.previewPart.Transparency = 1
		end
	end
end

function BuildingService:RaycastFromMouse(): RaycastResult?
	local mousePos = UserInputService:GetMouseLocation()
	local camera = Workspace.CurrentCamera
	if not camera then return nil end

	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, self.raycastParams)
	return result
end

function BuildingService:RaycastFromTouch(touchPos: Vector2): RaycastResult?
	local camera = Workspace.CurrentCamera
	if not camera then return nil end

	local ray = camera:ViewportPointToRay(touchPos.X, touchPos.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, self.raycastParams)
	return result
end

function BuildingService:UpdatePreview(rayResult: RaycastResult?)
	if not self.previewPart or self.mode ~= "Place" then return end

	if rayResult and rayResult.Position then
		local pos = rayResult.Position

		-- Grid snap
		pos = Vector3.new(
			math.round(pos.X / self.gridSnap) * self.gridSnap,
			math.round((pos.Y + self.currentSize.Y/2) / self.gridSnap) * self.gridSnap,
			math.round(pos.Z / self.gridSnap) * self.gridSnap
		)

		-- Se tem normal, coloca em cima da superfície
		if rayResult.Normal then
			pos += rayResult.Normal * (self.currentSize.Y/2 + 0.1)
		end

		self.previewPart.CFrame = CFrame.new(pos)
		self.previewPart.Transparency = 0.5
		self.previewPart.Color = self.currentColor
		self.previewPart.Material = self.currentMaterial
	else
		self.previewPart.Transparency = 1
	end
end

function BuildingService:PlaceBlockAt(position: Vector3, color: Color3?, material: Enum.Material?, size: Vector3?): string?
	local finalPos = Vector3.new(
		math.round(position.X / self.gridSnap) * self.gridSnap,
		math.round(position.Y / self.gridSnap) * self.gridSnap,
		math.round(position.Z / self.gridSnap) * self.gridSnap
	)

	local entity = Entity.new("Part_" .. tostring(self.world.entityCount + 1))
	Entity.AddComponent(entity, "Transform", Component.Transform(finalPos, Vector3.new(0,0,0), size or self.currentSize))
	
	local render = Component.Render(material or self.currentMaterial, color or self.currentColor)
	render.styleProfile = "realistic" -- default, pode ser mudado depois
	Entity.AddComponent(entity, "Render", render)
	
	Entity.AddComponent(entity, "Physics", Component.Physics("static"))
	Entity.AddComponent(entity, "Metadata", {
		creatorId = 0,
		createdFrom = "manual",
		tags = {"placed"},
		version = 1,
	})

	local id = self.world:AddEntity(entity)

	-- Histórico para Undo
	table.insert(self.history, {
		action = "place",
		entityId = id,
		entityData = entity,
	})
	self.historyIndex = #self.history

	print(string.format("[Arkher Building] Placed block %s at %s", id, tostring(finalPos)))

	-- Dispara evento para Outliner atualizar
	self:FireChanged()

	return id
end

function BuildingService:DeleteEntity(entityId: string): boolean
	local entity = self.world:GetEntity(entityId)
	if not entity then return false end

	-- Salva para Undo
	table.insert(self.history, {
		action = "delete",
		entityId = entityId,
		entityData = entity,
	})
	self.historyIndex = #self.history

	self.world:RemoveEntity(entityId)

	if self.selectedEntityId == entityId then
		self.selectedEntityId = nil
	end

	print("[Arkher Building] Deleted entity", entityId)
	self:FireChanged()
	return true
end

function BuildingService:SelectEntity(entityId: string?)
	self.selectedEntityId = entityId
	if entityId then
		print("[Arkher Building] Selected", entityId)
	else
		print("[Arkher Building] Deselected")
	end
	self:FireSelectionChanged(entityId)
end

function BuildingService:DuplicateEntity(entityId: string): string?
	local original = self.world:GetEntity(entityId)
	if not original then return nil end

	local transform = original.components.Transform
	local newPos = transform and (transform.position + Vector3.new(5,0,0)) or Vector3.new(0,5,0)

	local newEntity = Entity.new(original.name .. "_Copy", original.parent)
	newEntity.components = table.clone(original.components)
	
	-- Atualiza posição
	if newEntity.components.Transform then
		newEntity.components.Transform.position = newPos
		newEntity.components.Transform.cframe = CFrame.new(newPos)
	end

	local newId = self.world:AddEntity(newEntity)

	table.insert(self.history, {
		action = "duplicate",
		entityId = newId,
		sourceId = entityId,
	})
	self.historyIndex = #self.history

	print("[Arkher Building] Duplicated", entityId, "->", newId)
	self:FireChanged()
	return newId
end

function BuildingService:MoveEntity(entityId: string, newPosition: Vector3)
	local entity = self.world:GetEntity(entityId)
	if not entity then return end

	local transform = entity.components.Transform
	if not transform then return end

	-- Grid snap
	newPosition = Vector3.new(
		math.round(newPosition.X / self.gridSnap) * self.gridSnap,
		math.round(newPosition.Y / self.gridSnap) * self.gridSnap,
		math.round(newPosition.Z / self.gridSnap) * self.gridSnap
	)

	transform.position = newPosition
	transform.cframe = CFrame.new(newPosition) * CFrame.fromEulerAnglesYXZ(math.rad(transform.rotation.X), math.rad(transform.rotation.Y), math.rad(transform.rotation.Z))

	print("[Arkher Building] Moved", entityId, "to", newPosition)
	self:FireChanged()
end

function BuildingService:Undo(): boolean
	if self.historyIndex <= 0 then
		print("[Arkher Building] Nothing to undo")
		return false
	end

	local entry = self.history[self.historyIndex]
	if entry.action == "place" then
		self.world:RemoveEntity(entry.entityId)
		print("[Arkher Building] Undo place", entry.entityId)
	elseif entry.action == "delete" then
		self.world:AddEntity(entry.entityData)
		print("[Arkher Building] Undo delete", entry.entityId)
	elseif entry.action == "duplicate" then
		self.world:RemoveEntity(entry.entityId)
		print("[Arkher Building] Undo duplicate", entry.entityId)
	end

	self.historyIndex -= 1
	self:FireChanged()
	return true
end

function BuildingService:Redo(): boolean
	if self.historyIndex >= #self.history then
		print("[Arkher Building] Nothing to redo")
		return false
	end

	self.historyIndex += 1
	local entry = self.history[self.historyIndex]

	if entry.action == "place" then
		self.world:AddEntity(entry.entityData)
	elseif entry.action == "delete" then
		self.world:RemoveEntity(entry.entityId)
	elseif entry.action == "duplicate" then
		-- Recria duplicata
		local source = self.world:GetEntity(entry.sourceId)
		if source then
			self:DuplicateEntity(entry.sourceId)
		end
	end

	print("[Arkher Building] Redo", entry.action, entry.entityId)
	self:FireChanged()
	return true
end

function BuildingService:SetMaterial(material: Enum.Material)
	self.currentMaterial = material
	if self.previewPart then
		self.previewPart.Material = material
	end
	print("[Arkher Building] Material ->", material.Name)
end

function BuildingService:SetColor(color: Color3)
	self.currentColor = color
	if self.previewPart then
		self.previewPart.Color = color
		local hl = self.previewPart:FindFirstChildOfClass("Highlight")
		if hl then hl.FillColor = color end
	end
	print("[Arkher Building] Color ->", color)
end

function BuildingService:SetGridSnap(snap: number)
	self.gridSnap = snap
	print("[Arkher Building] GridSnap ->", snap)
end

-- Eventos para UI
function BuildingService:FireChanged()
	-- Dispara BindableEvent para Outliner e Details atualizarem
	local event = game.ReplicatedStorage:FindFirstChild("ArkherBuildingChanged")
	if event and event:IsA("BindableEvent") then
		event:Fire(self.world)
	end
end

function BuildingService:FireSelectionChanged(entityId: string?)
	local event = game.ReplicatedStorage:FindFirstChild("ArkherSelectionChanged")
	if event and event:IsA("BindableEvent") then
		event:Fire(entityId)
	end
end

function BuildingService:Destroy()
	if self.previewPart then
		self.previewPart:Destroy()
		self.previewPart = nil
	end
end

return BuildingService

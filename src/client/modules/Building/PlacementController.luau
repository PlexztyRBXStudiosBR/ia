--!strict
-- Arkher Studio - Fase 1 - PlacementController - Controla placement com mouse e touch

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlacementController = {}
PlacementController.__index = PlacementController

function PlacementController.new(buildingService: any, inputService: any)
	return setmetatable({
		buildingService = buildingService,
		inputService = inputService,
		isPlacing = false,
		lastTouchTime = 0,
		longPressThreshold = 0.5,
		longPressConnection = nil,
	}, PlacementController)
end

function PlacementController:Init()
	-- Mouse para PC
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:OnMouseClick()
		end
	end)

	-- Touch para Mobile
	UserInputService.TouchTap:Connect(function(touches)
		if #touches == 1 then
			self:OnTouchTap(touches[1])
		end
	end)

	UserInputService.TouchLongPress:Connect(function(touches, state)
		if state == Enum.UserInputState.Begin then
			self:OnLongPress(touches[1])
		end
	end)

	-- Update preview todo frame
	game:GetService("RunService").RenderStepped:Connect(function()
		self:UpdatePreview()
	end)

	print("[Arkher Placement] Initialized - Mouse + Touch + LongPress")
end

function PlacementController:OnMouseClick()
	if self.buildingService.mode ~= "Place" then
		-- Modo Select: tenta selecionar entidade
		self:TrySelect()
		return
	end

	local result = self.buildingService:RaycastFromMouse()
	if result and result.Position then
		self.buildingService:PlaceBlockAt(result.Position)
		print("[Arkher Placement] Placed via mouse at", result.Position)
	end
end

function PlacementController:OnTouchTap(touchPos: Vector2)
	print("[Arkher Placement] Touch tap at", touchPos)

	if self.buildingService.mode ~= "Place" then
		self:TrySelectTouch(touchPos)
		return
	end

	local result = self.buildingService:RaycastFromTouch(touchPos)
	if result and result.Position then
		self.buildingService:PlaceBlockAt(result.Position)
		print("[Arkher Placement] Placed via touch at", result.Position)
	end
end

function PlacementController:OnLongPress(touchPos: Vector2)
	print("[Arkher Placement] Long press at", touchPos)

	-- Mostra radial menu no mobile
	if self.buildingService.mainController and self.buildingService.mainController.mobileUI then
		self.buildingService.mainController.mobileUI:ShowRadialMenu(touchPos)
	end
end

function PlacementController:TrySelect()
	local result = self.buildingService:RaycastFromMouse()
	if not result then
		self.buildingService:SelectEntity(nil)
		return
	end

	-- Verifica se acertou alguma part do ArkherWorld
	local hitPart = result.Instance
	if hitPart and hitPart.Parent and hitPart.Parent.Name == "ArkherWorld" then
		-- Tenta achar entityId pelo nome da part
		local entityId = self:FindEntityIdByPart(hitPart)
		if entityId then
			self.buildingService:SelectEntity(entityId)
			print("[Arkher Placement] Selected entity", entityId, "via mouse")
		end
	else
		self.buildingService:SelectEntity(nil)
	end
end

function PlacementController:TrySelectTouch(touchPos: Vector2)
	local result = self.buildingService:RaycastFromTouch(touchPos)
	if not result then
		self.buildingService:SelectEntity(nil)
		return
	end

	local hitPart = result.Instance
	if hitPart and hitPart.Parent and hitPart.Parent.Name == "ArkherWorld" then
		local entityId = self:FindEntityIdByPart(hitPart)
		if entityId then
			self.buildingService:SelectEntity(entityId)
			print("[Arkher Placement] Selected entity", entityId, "via touch")
		end
	else
		self.buildingService:SelectEntity(nil)
	end
end

function PlacementController:FindEntityIdByPart(part: Part): string?
	-- Procura entity pelo nome da part (que contém ID ou nome)
	-- Fase 1 simples: procura por nome

	for id, entity in self.buildingService.world.entities do
		if string.find(part.Name, entity.name) or part.Name:find(id:sub(1,8)) then
			return id
		end
	end

	-- Fallback: procura mais próximo
	local closestId = nil
	local closestDist = math.huge

	for id, entity in self.buildingService.world.entities do
		local transform = entity.components.Transform
		if transform then
			local dist = (transform.position - part.Position).Magnitude
			if dist < closestDist and dist < 10 then
				closestDist = dist
				closestId = id
			end
		end
	end

	return closestId
end

function PlacementController:UpdatePreview()
	if self.buildingService.mode ~= "Place" then return end

	local result: RaycastResult? = nil

	if self.buildingService.mainController and self.buildingService.mainController.input then
		local platform = self.buildingService.mainController.input:GetPlatform()
		if platform == "Mobile" then
			-- No mobile, preview segue último toque ou centro da tela
			local camera = Workspace.CurrentCamera
			if camera then
				local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
				result = self.buildingService:RaycastFromTouch(center)
			end
		else
			result = self.buildingService:RaycastFromMouse()
		end
	else
		result = self.buildingService:RaycastFromMouse()
	end

	self.buildingService:UpdatePreview(result)
end

return PlacementController

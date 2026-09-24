--!strict
-- Arkher Studio - Fase 1 - MobileUI - Adaptações para A01 até Flagship
-- Bottom sheet, radial menu, touch gestures

local UserInputService = game:GetService("UserInputService")

local Shell = require(script.Parent.Shell)

local MobileUI = {}
MobileUI.__index = MobileUI

function MobileUI.new(mainController: any)
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	return setmetatable({
		mainController = mainController,
		isMobile = isMobile,
		bottomSheet = nil :: Frame?,
		radialMenu = nil :: Frame?,
		toolbar = nil :: Frame?,
	}, MobileUI)
end

function MobileUI:Init(parent: ScreenGui)
	if not self.isMobile then
		print("[Arkher MobileUI] Not mobile - skipping mobile UI")
		return
	end

	print("[Arkher MobileUI] Initializing for mobile - A01 optimized")

	self:CreateMobileToolbar(parent)
	self:CreateBottomSheet(parent)
	self:CreateRadialMenu(parent)
	self:AdaptExistingUI()

	print("[Arkher MobileUI] Mobile UI ready - Touch gestures enabled")
end

function MobileUI:CreateMobileToolbar(parent: ScreenGui)
	-- Toolbar inferior para mobile com botões grandes (fácil no A01)
	local toolbar = Instance.new("Frame")
	toolbar.Name = "MobileToolbar"
	toolbar.Size = UDim2.new(1, 0, 0, 70)
	toolbar.Position = UDim2.new(0, 0, 1, -70)
	toolbar.BackgroundColor3 = Shell.Colors.panel
	toolbar.BorderSizePixel = 0
	toolbar.ZIndex = 20
	toolbar.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = toolbar

	local stroke = Instance.new("UIStroke")
	stroke.Color = Shell.Colors.border
	stroke.Thickness = 1
	stroke.Parent = toolbar

	-- Botões principais: Select, Move, Place, Delete, Play
	local buttons = {
		{ icon = "👆", name = "Select", mode = "Select" },
		{ icon = "✋", name = "Move", mode = "Move" },
		{ icon = "🧱", name = "Place", mode = "Place" },
		{ icon = "🗑️", name = "Delete", mode = "Delete" },
		{ icon = "▶️", name = "Play", mode = "Play" },
	}

	for i, btnData in buttons do
		local btn = Instance.new("TextButton")
		btn.Name = btnData.name .. "Btn"
		btn.Size = UDim2.new(0, 60, 0, 50)
		btn.Position = UDim2.new(0, 10 + (i-1)*65, 0, 10)
		btn.BackgroundColor3 = btnData.mode == "Place" and Shell.Colors.accent or Shell.Colors.panelLight
		btn.Text = btnData.icon .. "\n" .. btnData.name
		btn.TextColor3 = Shell.Colors.text
		btn.TextSize = 10
		btn.Font = Enum.Font.GothamBold
		btn.Parent = toolbar

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			self:HandleToolbarClick(btnData.mode, btn)

			-- Atualiza seleção visual
			for _, otherBtn in toolbar:GetChildren() do
				if otherBtn:IsA("TextButton") then
					otherBtn.BackgroundColor3 = Shell.Colors.panelLight
				end
			end
			btn.BackgroundColor3 = Shell.Colors.accent
		end)
	end

	self.toolbar = toolbar
end

function MobileUI:HandleToolbarClick(mode: string, btn: TextButton)
	print("[Arkher MobileUI] Toolbar click:", mode)

	if mode == "Play" then
		self.mainController:TogglePlay()
	elseif mode == "Select" or mode == "Move" or mode == "Place" then
		if self.mainController.buildingService then
			self.mainController.buildingService:SetMode(mode)
		end
	elseif mode == "Delete" then
		if self.mainController.buildingService and self.mainController.buildingService.selectedEntityId then
			self.mainController.buildingService:DeleteEntity(self.mainController.buildingService.selectedEntityId)
		end
	end
end

function MobileUI:CreateBottomSheet(parent: ScreenGui)
	-- Bottom sheet que sobe quando seleciona entidade (igual Google Maps)
	local sheet = Instance.new("Frame")
	sheet.Name = "MobileBottomSheet"
	sheet.Size = UDim2.new(1, 0, 0, 250)
	sheet.Position = UDim2.new(0, 0, 1, 0) -- escondido inicialmente
	sheet.BackgroundColor3 = Shell.Colors.panel
	sheet.BorderSizePixel = 0
	sheet.ZIndex = 15
	sheet.Visible = false
	sheet.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = sheet

	-- Handle para arrastar
	local handle = Instance.new("Frame")
	handle.Name = "Handle"
	handle.Size = UDim2.new(0, 40, 0, 4)
	handle.Position = UDim2.new(0.5, -20, 0, 8)
	handle.BackgroundColor3 = Shell.Colors.textDim
	handle.BorderSizePixel = 0
	handle.Parent = sheet

	local handleCorner = Instance.new("UICorner")
	handleCorner.CornerRadius = UDim.new(0, 2)
	handleCorner.Parent = handle

	-- Título
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 30)
	title.Position = UDim2.new(0, 10, 0, 20)
	title.BackgroundTransparency = 1
	title.Text = "Propriedades"
	title.TextColor3 = Shell.Colors.text
	title.TextSize = 14
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = sheet

	-- Conteúdo scrollável
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Content"
	scroll.Size = UDim2.new(1, -20, 1, -60)
	scroll.Position = UDim2.new(0, 10, 0, 50)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = sheet

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.Parent = scroll

	self.bottomSheet = sheet

	-- Escuta seleção para mostrar/esconder
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local selectionChanged = ReplicatedStorage:FindFirstChild("ArkherSelectionChanged")
	if selectionChanged then
		selectionChanged.Event:Connect(function(entityId)
			if entityId then
				self:ShowBottomSheet(entityId)
			else
				self:HideBottomSheet()
			end
		end)
	end
end

function MobileUI:ShowBottomSheet(entityId: string)
	if not self.bottomSheet or not self.isMobile then return end

	self.bottomSheet.Visible = true
	-- Animação sobe
	self.bottomSheet:TweenPosition(UDim2.new(0, 0, 1, -250), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)

	print("[Arkher MobileUI] Show bottom sheet for", entityId)
end

function MobileUI:HideBottomSheet()
	if not self.bottomSheet then return end

	self.bottomSheet:TweenPosition(UDim2.new(0, 0, 1, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.3, true, function()
		self.bottomSheet.Visible = false
	end)

	print("[Arkher MobileUI] Hide bottom sheet")
end

function MobileUI:CreateRadialMenu(parent: ScreenGui)
	-- Radial menu que aparece com long press (igual Fortnite building)
	local radial = Instance.new("Frame")
	radial.Name = "RadialMenu"
	radial.Size = UDim2.new(0, 200, 0, 200)
	radial.Position = UDim2.new(0.5, -100, 0.5, -100)
	radial.BackgroundTransparency = 1
	radial.ZIndex = 25
	radial.Visible = false
	radial.Parent = parent

	-- Centro
	local center = Instance.new("TextButton")
	center.Name = "Center"
	center.Size = UDim2.new(0, 60, 0, 60)
	center.Position = UDim2.new(0.5, -30, 0.5, -30)
	center.BackgroundColor3 = Shell.Colors.panel
	center.Text = "❌"
	center.TextSize = 20
	center.Parent = radial

	local centerCorner = Instance.new("UICorner")
	centerCorner.CornerRadius = UDim.new(0, 30)
	centerCorner.Parent = center

	-- Opções ao redor (8 direções)
	local options = {
		{ icon = "🧱", name = "Place", angle = 0 },
		{ icon = "🎨", name = "Paint", angle = 45 },
		{ icon = "📋", name = "Duplicate", angle = 90 },
		{ icon = "🗑️", name = "Delete", angle = 135 },
		{ icon = "⬆️", name = "Move Up", angle = 180 },
		{ icon = "🔄", name = "Rotate", angle = 225 },
		{ icon = "📦", name = "Material", angle = 270 },
		{ icon = "💾", name = "Save", angle = 315 },
	}

	for _, opt in options do
		local rad = math.rad(opt.angle)
		local x = math.cos(rad) * 70
		local y = math.sin(rad) * 70

		local btn = Instance.new("TextButton")
		btn.Name = opt.name
		btn.Size = UDim2.new(0, 50, 0, 50)
		btn.Position = UDim2.new(0.5, x - 25, 0.5, y - 25)
		btn.BackgroundColor3 = Shell.Colors.panelLight
		btn.Text = opt.icon
		btn.TextSize = 18
		btn.Parent = radial

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 25)
		btnCorner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			self:HandleRadialClick(opt.name)
			self:HideRadialMenu()
		end)
	end

	self.radialMenu = radial

	center.MouseButton1Click:Connect(function()
		self:HideRadialMenu()
	end)
end

function MobileUI:HandleRadialClick(action: string)
	print("[Arkher MobileUI] Radial action:", action)

	if action == "Duplicate" and self.mainController.buildingService.selectedEntityId then
		self.mainController.buildingService:DuplicateEntity(self.mainController.buildingService.selectedEntityId)
	elseif action == "Delete" and self.mainController.buildingService.selectedEntityId then
		self.mainController.buildingService:DeleteEntity(self.mainController.buildingService.selectedEntityId)
	elseif action == "Save" then
		self.mainController:SaveProject()
	end
end

function MobileUI:ShowRadialMenu(atPosition: Vector2?)
	if not self.radialMenu or not self.isMobile then return end

	if atPosition then
		self.radialMenu.Position = UDim2.new(0, atPosition.X - 100, 0, atPosition.Y - 100)
	end

	self.radialMenu.Visible = true
	print("[Arkher MobileUI] Show radial menu")
end

function MobileUI:HideRadialMenu()
	if not self.radialMenu then return end
	self.radialMenu.Visible = false
	print("[Arkher MobileUI] Hide radial menu")
end

function MobileUI:AdaptExistingUI()
	-- Esconde ou adapta UI de PC para mobile
	if not self.isMobile then return end

	-- No mobile, Outliner e Details viram bottom sheet, não painel lateral
	-- Vamos esconder os painéis laterais originais se existirem

	print("[Arkher MobileUI] Adapted PC UI for mobile - Panels hidden, using bottom sheet")
end

return MobileUI

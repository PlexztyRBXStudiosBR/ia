--!strict
-- Arkher Studio - Fase 1 - Details Panel Funcional
-- Edita Transform, Render, Physics - Inspirado no Details da Unreal

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Arkher.ECS.World)
local Shell = require(script.Parent.Shell)

local Details = {}
Details.__index = Details

function Details.new(world: World.World, buildingService: any)
	return setmetatable({
		world = world,
		buildingService = buildingService,
		frame = nil :: Frame?,
		selectedId = nil :: string?,
		inputs = {} :: { [string]: any },
	}, Details)
end

function Details:Init(parent: Frame)
	self.frame = parent

	-- Escuta seleção
	local selectionChanged = ReplicatedStorage:FindFirstChild("ArkherSelectionChanged")
	if selectionChanged then
		selectionChanged.Event:Connect(function(entityId)
			self.selectedId = entityId
			self:Refresh()
		end)
	end

	local buildingChanged = ReplicatedStorage:FindFirstChild("ArkherBuildingChanged")
	if buildingChanged then
		buildingChanged.Event:Connect(function()
			if self.selectedId then
				self:Refresh()
			end
		end)
	end

	print("[Arkher Details] Initialized")
	self:Refresh()
end

function Details:Refresh()
	if not self.frame then return end

	-- Limpa inputs antigos (mantém header)
	for _, child in self.frame:GetChildren() do
		if child.Name ~= "Header" and child.Name ~= "TransformSection" then
			if not string.find(child.Name, "Section") then
				-- Mantém seções, limpa resto
			end
		end
		if child:IsA("Frame") and child.Name:find("Dynamic_") then
			child:Destroy()
		end
	end

	if not self.selectedId then
		self:ShowNoSelection()
		return
	end

	local entity = self.world:GetEntity(self.selectedId)
	if not entity then
		self:ShowNoSelection()
		return
	end

	self:ShowEntityDetails(entity)
end

function Details:ShowNoSelection()
	if not self.frame then return end

	-- Já existe TransformSection, vamos limpar e mostrar mensagem
	local existing = self.frame:FindFirstChild("Dynamic_NoSelection")
	if existing then existing:Destroy() end

	local label = Instance.new("TextLabel")
	label.Name = "Dynamic_NoSelection"
	label.Size = UDim2.new(1, -20, 0, 60)
	label.Position = UDim2.new(0, 10, 0, 50)
	label.BackgroundTransparency = 1
	label.Text = "Nenhuma entidade selecionada\n\nSelecione no Outliner ou clique no viewport\n\n💡 Dica: Use W/E/R para gizmos"
	label.TextColor3 = Shell.Colors.textDim
	label.TextSize = 12
	label.Font = Enum.Font.Gotham
	label.TextWrapped = true
	label.Parent = self.frame
end

function Details:ShowEntityDetails(entity: any)
	if not self.frame then return end

	local yOffset = 40

	-- Nome da entidade (editável)
	local nameSection = self:CreateSection("Name", yOffset)
	yOffset += 40

	local nameBox = Instance.new("TextBox")
	nameBox.Name = "NameBox"
	nameBox.Size = UDim2.new(1, -20, 0, 28)
	nameBox.Position = UDim2.new(0, 10, 0, 5)
	nameBox.BackgroundColor3 = Shell.Colors.background
	nameBox.Text = entity.name
	nameBox.TextColor3 = Shell.Colors.text
	nameBox.TextSize = 12
	nameBox.Font = Enum.Font.Gotham
	nameBox.ClearTextOnFocus = false
	nameBox.Parent = nameSection

	local nameCorner = Instance.new("UICorner")
	nameCorner.CornerRadius = UDim.new(0, 4)
	nameCorner.Parent = nameBox

	nameBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			entity.name = nameBox.Text
			self.buildingService:FireChanged()
			print("[Arkher Details] Renamed to", entity.name)
		end
	end)

	-- Transform Section
	yOffset = self:ShowTransformSection(entity, yOffset)

	-- Render Section
	if entity.components.Render then
		yOffset = self:ShowRenderSection(entity, yOffset)
	end

	-- Physics Section
	if entity.components.Physics then
		yOffset = self:ShowPhysicsSection(entity, yOffset)
	end

	-- Actions Section (Delete, Duplicate, etc)
	yOffset = self:ShowActionsSection(entity, yOffset)
end

function Details:CreateSection(title: string, yPos: number): Frame
	local section = Instance.new("Frame")
	section.Name = "Dynamic_" .. title
	section.Size = UDim2.new(1, -20, 0, 35)
	section.Position = UDim2.new(0, 10, 0, yPos)
	section.BackgroundColor3 = Shell.Colors.background
	section.Parent = self.frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = section

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 20)
	label.BackgroundTransparency = 1
	label.Text = "  " .. title
	label.TextColor3 = Shell.Colors.text
	label.TextSize = 11
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = section

	return section
end

function Details:ShowTransformSection(entity: any, yOffset: number): number
	local transform = entity.components.Transform
	if not transform then return yOffset end

	local section = Instance.new("Frame")
	section.Name = "Dynamic_Transform"
	section.Size = UDim2.new(1, -20, 0, 120)
	section.Position = UDim2.new(0, 10, 0, yOffset)
	section.BackgroundColor3 = Shell.Colors.background
	section.Parent = self.frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = section

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Text = "  📍 Transform"
	title.TextColor3 = Shell.Colors.text
	title.TextSize = 11
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = section

	-- Position X Y Z
	local labels = {"X", "Y", "Z"}
	local pos = transform.position

	for i, axis in labels do
		local axisLabel = Instance.new("TextLabel")
		axisLabel.Size = UDim2.new(0, 15, 0, 22)
		axisLabel.Position = UDim2.new(0, 10, 0, 25 + (i-1)*25)
		axisLabel.BackgroundTransparency = 1
		axisLabel.Text = axis
		axisLabel.TextColor3 = axis == "X" and Color3.fromRGB(255,100,100) or axis == "Y" and Color3.fromRGB(100,255,100) or Color3.fromRGB(100,100,255)
		axisLabel.TextSize = 11
		axisLabel.Font = Enum.Font.GothamBold
		axisLabel.Parent = section

		local input = Instance.new("TextBox")
		input.Name = "Pos" .. axis
		input.Size = UDim2.new(0, 70, 0, 22)
		input.Position = UDim2.new(0, 30, 0, 25 + (i-1)*25)
		input.BackgroundColor3 = Shell.Colors.panelLight
		input.Text = string.format("%.1f", pos[axis])
		input.TextColor3 = Shell.Colors.text
		input.TextSize = 11
		input.Font = Enum.Font.Code
		input.ClearTextOnFocus = false
		input.Parent = section

		local inputCorner = Instance.new("UICorner")
		inputCorner.CornerRadius = UDim.new(0, 3)
		inputCorner.Parent = input

		input.FocusLost:Connect(function(enter)
			if enter then
				local num = tonumber(input.Text)
				if num then
					local newPos = Vector3.new(
						axis == "X" and num or pos.X,
						axis == "Y" and num or pos.Y,
						axis == "Z" and num or pos.Z
					)
					self.buildingService:MoveEntity(entity.id, newPos)
				end
			end
		end)
	end

	return yOffset + 130
end

function Details:ShowRenderSection(entity: any, yOffset: number): number
	local render = entity.components.Render
	if not render then return yOffset end

	local section = Instance.new("Frame")
	section.Name = "Dynamic_Render"
	section.Size = UDim2.new(1, -20, 0, 140)
	section.Position = UDim2.new(0, 10, 0, yOffset)
	section.BackgroundColor3 = Shell.Colors.background
	section.Parent = self.frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = section

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Text = "  🎨 Render - " .. render.styleProfile
	title.TextColor3 = Shell.Colors.text
	title.TextSize = 11
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = section

	-- Color picker (simplificado - 6 cores)
	local colors = {
		Color3.fromRGB(255,255,255),
		Color3.fromRGB(255,0,0),
		Color3.fromRGB(0,255,0),
		Color3.fromRGB(0,0,255),
		Color3.fromRGB(255,255,0),
		Color3.fromRGB(255,0,255),
	}

	for i, color in colors do
		local colorBtn = Instance.new("TextButton")
		colorBtn.Size = UDim2.new(0, 28, 0, 28)
		colorBtn.Position = UDim2.new(0, 10 + (i-1)*32, 0, 30)
		colorBtn.BackgroundColor3 = color
		colorBtn.Text = ""
		colorBtn.Parent = section

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 14)
		cCorner.Parent = colorBtn

		if (render.color - color).Magnitude < 0.1 then
			local stroke = Instance.new("UIStroke")
			stroke.Color = Shell.Colors.accent
			stroke.Thickness = 2
			stroke.Parent = colorBtn
		end

		colorBtn.MouseButton1Click:Connect(function()
			render.color = color
			self.buildingService:FireChanged()
			self:Refresh()
		end)
	end

	-- Material dropdown (simplificado)
	local matLabel = Instance.new("TextLabel")
	matLabel.Size = UDim2.new(0, 60, 0, 20)
	matLabel.Position = UDim2.new(0, 10, 0, 70)
	matLabel.BackgroundTransparency = 1
	matLabel.Text = "Material:"
	matLabel.TextColor3 = Shell.Colors.textDim
	matLabel.TextSize = 10
	matLabel.Font = Enum.Font.Gotham
	matLabel.TextXAlignment = Enum.TextXAlignment.Left
	matLabel.Parent = section

	local matBtn = Instance.new("TextButton")
	matBtn.Size = UDim2.new(1, -80, 0, 24)
	matBtn.Position = UDim2.new(0, 70, 0, 70)
	matBtn.BackgroundColor3 = Shell.Colors.panelLight
	matBtn.Text = render.material.Name
	matBtn.TextColor3 = Shell.Colors.text
	matBtn.TextSize = 11
	matBtn.Font = Enum.Font.Gotham
	matBtn.Parent = section

	local matCorner = Instance.new("UICorner")
	matCorner.CornerRadius = UDim.new(0, 4)
	matCorner.Parent = matBtn

	-- Cicla materiais ao clicar
	local materials = {Enum.Material.Plastic, Enum.Material.Wood, Enum.Material.Metal, Enum.Material.Glass, Enum.Material.Neon, Enum.Material.Grass}
	matBtn.MouseButton1Click:Connect(function()
		local currentIdx = table.find(materials, render.material) or 1
		local nextIdx = (currentIdx % #materials) + 1
		render.material = materials[nextIdx]
		matBtn.Text = render.material.Name
		self.buildingService:FireChanged()
	end)

	-- Style profile
	local styleLabel = Instance.new("TextLabel")
	styleLabel.Size = UDim2.new(0, 60, 0, 20)
	styleLabel.Position = UDim2.new(0, 10, 0, 100)
	styleLabel.BackgroundTransparency = 1
	styleLabel.Text = "Estilo:"
	styleLabel.TextColor3 = Shell.Colors.textDim
	styleLabel.TextSize = 10
	styleLabel.Font = Enum.Font.Gotham
	styleLabel.TextXAlignment = Enum.TextXAlignment.Left
	styleLabel.Parent = section

	local styleBtn = Instance.new("TextButton")
	styleBtn.Size = UDim2.new(1, -80, 0, 24)
	styleBtn.Position = UDim2.new(0, 70, 0, 100)
	styleBtn.BackgroundColor3 = Shell.Colors.panelLight
	styleBtn.Text = render.styleProfile
	styleBtn.TextColor3 = Shell.Colors.text
	styleBtn.TextSize = 11
	styleBtn.Font = Enum.Font.Gotham
	styleBtn.Parent = section

	local styleCorner = Instance.new("UICorner")
	styleCorner.CornerRadius = UDim.new(0, 4)
	styleCorner.Parent = styleBtn

	local styles = {"lowpoly", "anime", "stylized", "realistic", "ultrarealistic", "photorealistic"}
	styleBtn.MouseButton1Click:Connect(function()
		local idx = table.find(styles, render.styleProfile) or 4
		local nextIdx = (idx % #styles) + 1
		render.styleProfile = styles[nextIdx]
		styleBtn.Text = render.styleProfile
		self.buildingService:FireChanged()
	end)

	return yOffset + 150
end

function Details:ShowPhysicsSection(entity: any, yOffset: number): number
	local physics = entity.components.Physics
	if not physics then return yOffset end

	local section = Instance.new("Frame")
	section.Name = "Dynamic_Physics"
	section.Size = UDim2.new(1, -20, 0, 60)
	section.Position = UDim2.new(0, 10, 0, yOffset)
	section.BackgroundColor3 = Shell.Colors.background
	section.Parent = self.frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = section

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Text = "  ⚙️ Physics - " .. physics.bodyType
	title.TextColor3 = Shell.Colors.text
	title.TextSize = 11
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = section

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(1, -20, 0, 24)
	toggleBtn.Position = UDim2.new(0, 10, 0, 30)
	toggleBtn.BackgroundColor3 = physics.bodyType == "static" and Shell.Colors.panelLight or Shell.Colors.accent
	toggleBtn.Text = physics.bodyType == "static" and "Static (Anchored)" or "Dynamic (Physics)"
	toggleBtn.TextColor3 = Shell.Colors.text
	toggleBtn.TextSize = 11
	toggleBtn.Font = Enum.Font.Gotham
	toggleBtn.Parent = section

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 4)
	tCorner.Parent = toggleBtn

	toggleBtn.MouseButton1Click:Connect(function()
		physics.bodyType = physics.bodyType == "static" and "dynamic" or "static"
		toggleBtn.Text = physics.bodyType == "static" and "Static (Anchored)" or "Dynamic (Physics)"
		toggleBtn.BackgroundColor3 = physics.bodyType == "static" and Shell.Colors.panelLight or Shell.Colors.accent
		self.buildingService:FireChanged()
	end)

	return yOffset + 70
end

function Details:ShowActionsSection(entity: any, yOffset: number): number
	local section = Instance.new("Frame")
	section.Name = "Dynamic_Actions"
	section.Size = UDim2.new(1, -20, 0, 80)
	section.Position = UDim2.new(0, 10, 0, yOffset)
	section.BackgroundColor3 = Shell.Colors.background
	section.Parent = self.frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = section

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Text = "  🔧 Actions"
	title.TextColor3 = Shell.Colors.text
	title.TextSize = 11
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = section

	-- Duplicate
	local dupBtn = Instance.new("TextButton")
	dupBtn.Size = UDim2.new(0.5, -15, 0, 28)
	dupBtn.Position = UDim2.new(0, 10, 0, 30)
	dupBtn.BackgroundColor3 = Shell.Colors.panelLight
	dupBtn.Text = "📋 Duplicate"
	dupBtn.TextColor3 = Shell.Colors.text
	dupBtn.TextSize = 11
	dupBtn.Font = Enum.Font.Gotham
	dupBtn.Parent = section

	local dupCorner = Instance.new("UICorner")
	dupCorner.CornerRadius = UDim.new(0, 4)
	dupCorner.Parent = dupBtn

	dupBtn.MouseButton1Click:Connect(function()
		self.buildingService:DuplicateEntity(entity.id)
	end)

	-- Delete
	local delBtn = Instance.new("TextButton")
	delBtn.Size = UDim2.new(0.5, -15, 0, 28)
	delBtn.Position = UDim2.new(0.5, 5, 0, 30)
	delBtn.BackgroundColor3 = Shell.Colors.error
	delBtn.Text = "🗑️ Delete"
	delBtn.TextColor3 = Color3.new(1,1,1)
	delBtn.TextSize = 11
	delBtn.Font = Enum.Font.Gotham
	delBtn.Parent = section

	local delCorner = Instance.new("UICorner")
	delCorner.CornerRadius = UDim.new(0, 4)
	delCorner.Parent = delBtn

	delBtn.MouseButton1Click:Connect(function()
		self.buildingService:DeleteEntity(entity.id)
	end)

	return yOffset + 90
end

return Details

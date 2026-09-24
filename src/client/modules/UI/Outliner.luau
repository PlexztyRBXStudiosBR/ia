--!strict
-- Arkher Studio - Fase 1 - Outliner Funcional
-- Lista entidades, busca, seleção, delete, duplicate - Estilo Unreal World Outliner

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Arkher.ECS.World)
local Shell = require(script.Parent.Shell)

local Outliner = {}
Outliner.__index = Outliner

function Outliner.new(world: World.World, buildingService: any)
	return setmetatable({
		world = world,
		buildingService = buildingService,
		frame = nil :: Frame?,
		entityList = nil :: ScrollingFrame?,
		searchBox = nil :: TextBox?,
		entityButtons = {} :: { [string]: TextButton },
		selectedId = nil :: string?,
		filter = "",
	}, Outliner)
end

function Outliner:Init(parent: Frame)
	-- Pega frame já criado pelo Shell ou cria novo
	self.frame = parent

	-- Encontra componentes
	self.entityList = parent:FindFirstChild("EntityList") :: ScrollingFrame
	self.searchBox = parent:FindFirstChild("Search") :: TextBox

	if self.searchBox then
		self.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			self.filter = string.lower(self.searchBox.Text)
			self:Refresh()
		end)
	end

	-- Eventos de mudança
	local buildingChanged = ReplicatedStorage:FindFirstChild("ArkherBuildingChanged")
	if buildingChanged then
		buildingChanged.Event:Connect(function()
			self:Refresh()
		end)
	end

	local selectionChanged = ReplicatedStorage:FindFirstChild("ArkherSelectionChanged")
	if selectionChanged then
		selectionChanged.Event:Connect(function(entityId)
			self.selectedId = entityId
			self:UpdateSelection()
		end)
	end

	print("[Arkher Outliner] Initialized")
	self:Refresh()
end

function Outliner:Refresh()
	if not self.entityList then return end

	-- Limpa botões antigos
	for _, btn in self.entityButtons do
		if btn.Parent then
			btn:Destroy()
		end
	end
	self.entityButtons = {}

	local entities = self.world:GetRootEntities()

	-- Aplica filtro
	local filtered = {}
	for _, entity in entities do
		if self.filter == "" or string.find(string.lower(entity.name), self.filter) then
			table.insert(filtered, entity)
		end
	end

	-- Ordena por nome
	table.sort(filtered, function(a, b)
		return a.name < b.name
	end)

	-- Cria botão para cada entidade
	for i, entity in filtered do
		local btn = self:CreateEntityButton(entity, i)
		btn.Parent = self.entityList
		self.entityButtons[entity.id] = btn
	end

	print("[Arkher Outliner] Refreshed -", #filtered, "entities (filter:", self.filter, ")")
end

function Outliner:CreateEntityButton(entity: any, order: number): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = "Entity_" .. entity.id
	btn.Size = UDim2.new(1, -10, 0, 28)
	btn.BackgroundColor3 = self.selectedId == entity.id and Shell.Colors.accent or Shell.Colors.background
	btn.BorderSizePixel = 0
	btn.LayoutOrder = order
	btn.Text = ""
	btn.AutoButtonColor = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = btn

	-- Ícone baseado no tipo
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 24, 1, 0)
	icon.Position = UDim2.new(0, 4, 0, 0)
	icon.BackgroundTransparency = 1
	icon.Text = self:GetEntityIcon(entity)
	icon.TextColor3 = Shell.Colors.textDim
	icon.TextSize = 14
	icon.Font = Enum.Font.Gotham
	icon.Parent = btn

	-- Nome
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -60, 1, 0)
	nameLabel.Position = UDim2.new(0, 28, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = entity.name
	nameLabel.TextColor3 = entity.isHidden and Shell.Colors.textDim or Shell.Colors.text
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtRight
	nameLabel.Parent = btn

	-- Ações (visível no hover - Fase 2)
	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.Size = UDim2.new(0, 40, 1, 0)
	actions.Position = UDim2.new(1, -40, 0, 0)
	actions.BackgroundTransparency = 1
	actions.Parent = btn

	-- Click para selecionar
	btn.MouseButton1Click:Connect(function()
		self.buildingService:SelectEntity(entity.id)
	end)

	-- Duplo clique para focar (Fase 2)
	-- btn.MouseButton2Click para menu contexto (delete, duplicate, etc)

	return btn
end

function Outliner:GetEntityIcon(entity: any): string
	if entity.components.Render then
		local style = entity.components.Render.styleProfile
		if style == "lowpoly" then return "🔷"
		elseif style == "anime" then return "🌸"
		elseif style == "photorealistic" then return "📸"
		elseif style == "ultrarealistic" then return "💎"
		else return "🧊" end
	elseif entity.components.ScriptComponent then
		return "📜"
	elseif entity.components.LightComponent then
		return "💡"
	else
		return "📦"
	end
end

function Outliner:UpdateSelection()
	for id, btn in self.entityButtons do
		if id == self.selectedId then
			btn.BackgroundColor3 = Shell.Colors.accent
		else
			btn.BackgroundColor3 = Shell.Colors.background
		end
	end
end

function Outliner:SelectEntity(entityId: string?)
	self.selectedId = entityId
	self:UpdateSelection()
end

return Outliner

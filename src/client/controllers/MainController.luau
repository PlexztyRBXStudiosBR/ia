--!strict
-- Arkher Studio - MainController - Fase 1 MVP Mobile
-- Building System real + Outliner funcional + Details + Mobile UI + Save/Load

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shell = require(script.Parent.Parent.modules.UI.Shell)
local Outliner = require(script.Parent.Parent.modules.UI.Outliner)
local Details = require(script.Parent.Parent.modules.UI.Details)
local MobileUI = require(script.Parent.Parent.modules.UI.MobileUI)
local Toolbar = require(script.Parent.Parent.modules.UI.Toolbar)
local InputService = require(script.Parent.Parent.modules.Input.InputService)
local Gizmo = require(script.Parent.Parent.modules.Building.Gizmo)
local BuildingService = require(script.Parent.Parent.modules.Building.BuildingService)
local PlacementController = require(script.Parent.Parent.modules.Building.PlacementController)
local World = require(ReplicatedStorage.Arkher.ECS.World)
local Entity = require(ReplicatedStorage.Arkher.ECS.Entity)
local Component = require(ReplicatedStorage.Arkher.ECS.Component)
local ArkherAPI = require(ReplicatedStorage.Arkher.ArkherAPI.ArkherAPI)
local ANGController = require(script.Parent.Parent.modules.ANG.ANGController)
local VaultService = require(script.Parent.Parent.modules.Vault.VaultService)
local ProjectManager = require(script.Parent.Parent.modules.ProjectManager)
local RenderSystem = require(ReplicatedStorage.Arkher.Systems.RenderSystem)
local LODSystem = require(ReplicatedStorage.Arkher.Systems.LODSystem)
local StreamingSystem = require(ReplicatedStorage.Arkher.Systems.StreamingSystem)
local StyleProfiles = require(ReplicatedStorage.Arkher.Constants.StyleProfiles)

local MainController = {}
MainController.__index = MainController

function MainController.new()
	return setmetatable({
		world = World.new(),
		api = nil,
		input = nil,
		gizmo = nil,
		buildingService = nil,
		placementController = nil,
		renderSystem = nil,
		lodSystem = nil,
		streamingSystem = nil,
		ang = nil,
		vault = nil,
		projectManager = nil,
		outliner = nil,
		details = nil,
		mobileUI = nil,
		toolbar = nil,
		ui = nil,
		currentStyle = "realistic" :: string,
		isPlaying = false,
		selectedEntityId = nil :: string?,
	}, MainController)
end

function MainController:Init()
	print("========================================")
	print("  ARKHER STUDIO - ALPHA 0.2 - FASE 1 MVP MOBILE")
	print("  Building System Real + Outliner + Details")
	print("  Mata Studio Lite")
	print("========================================")

	local player = Players.LocalPlayer
	print("[Arkher] Player:", player.Name, "- UserId:", player.UserId)

	-- Cria BindableEvents para comunicação interna
	self:CreateInternalEvents()

	-- ArkherAPI
	self.api = ArkherAPI.new(false, self.currentStyle)
	print("[Arkher] API - Mode:", self.api.useCustomEngine and "MECHA" or "ROBLOX")

	-- Input Universal
	self.input = InputService.new()
	print("[Arkher] Input - Platform:", self.input:GetPlatform())

	-- Gizmo
	self.gizmo = Gizmo.new()

	-- BuildingService - Fase 1 Real
	self.buildingService = BuildingService.new(self.world)
	self.buildingService:Init()
	-- @ts-ignore
	self.buildingService.mainController = self -- para MobileUI acessar

	-- RenderSystem com LOD + Streaming
	self.renderSystem = RenderSystem.new(self.world)
	self.renderSystem:Init()

	-- LODSystem - Faz A01 rodar AAA
	self.lodSystem = LODSystem.new(self.world, self.renderSystem)

	-- StreamingSystem - Só carrega perto (World Creator style)
	self.streamingSystem = StreamingSystem.new(self.world, self.renderSystem)

	-- PlacementController - Mouse + Touch
	self.placementController = PlacementController.new(self.buildingService, self.input)
	self.placementController:Init()

	-- LOD + Streaming loop
	task.spawn(function()
		while true do
			task.wait(0.5)
			if not self.isPlaying then
				if self.lodSystem then self.lodSystem:Update() end
				if self.streamingSystem then self.streamingSystem:Update() end
			end
		end
	end)

	-- ANG
	self.ang = ANGController.new(self.currentStyle)
	print("[Arkher] ANG -", self.ang:GetStats().message)

	-- Vault
	self.vault = VaultService.new()
	self.vault:LoadMockAssets()
	print("[Arkher] Vault -", self.vault:GetStats().totalAssets, "assets")

	-- ProjectManager - Save/Load real
	self.projectManager = ProjectManager.new(self.world)
	self.projectManager:Init()
	self.projectManager:CreateNewProject("Meu Primeiro Jogo Arkher", self.currentStyle)

	-- UI Shell
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = Shell.CreateMainScreenGui()
	screenGui.Parent = playerGui

	self.ui = Shell.BuildFullUI(screenGui)

	-- Outliner Funcional
	self.outliner = Outliner.new(self.world, self.buildingService)
	if self.ui.outliner then
		self.outliner:Init(self.ui.outliner)
	end

	-- Details Funcional
	self.details = Details.new(self.world, self.buildingService)
	if self.ui.details then
		self.details:Init(self.ui.details)
	end

	-- MobileUI - Adapta para A01
	self.mobileUI = MobileUI.new(self)
	self.mobileUI:Init(screenGui)

	-- Toolbar - Ferramentas + Grid Snap + Undo/Redo
	if self.ui.viewport then
		self.toolbar = Toolbar.new(self.buildingService)
		self.toolbar:Init(self.ui.viewport)
	end

	-- Demo world
	self:CreateDemoWorld()

	-- Handlers
	self:SetupInputHandlers()
	self:SetupUIHandlers()

	-- Materializa inicial
	self:MaterializeWorld()

	print("========================================")
	print("  ARKHER STUDIO FASE 1 READY!")
	print("  Controles:")
	print("  PC: Click para colocar, Click em part para selecionar, W/E/R gizmo, Delete, Ctrl+Z Undo")
	print("  Mobile: Tap para colocar/selecionar, Long Press radial menu, Toolbar inferior")
	print("  Outliner: Lista entidades, filtro busca")
	print("  Details: Edita Transform, Render, Physics")
	print("  TopBar: Play/Stop, Style selector")
	print("  Vault:", #self.vault.assets, "assets AAA")
	print("  ANG:", self.ang:GetStats().message)
	print("  Save: AutoSave 60s + botão")
	print("========================================")
end

function MainController:CreateInternalEvents()
	local events = {"ArkherBuildingChanged", "ArkherSelectionChanged"}

	for _, name in events do
		if not ReplicatedStorage:FindFirstChild(name) then
			local ev = Instance.new("BindableEvent")
			ev.Name = name
			ev.Parent = ReplicatedStorage
		end
	end
end

function MainController:CreateDemoWorld()
	print("[Arkher] Creating demo world Fase 1...")

	-- Chão grande
	local ground = Entity.new("Ground")
	Entity.AddComponent(ground, "Transform", Component.Transform(Vector3.new(0, -5, 0), Vector3.new(0,0,0), Vector3.new(200, 10, 200)))
	Entity.AddComponent(ground, "Render", Component.Render(Enum.Material.Grass, Color3.fromRGB(60, 180, 75)))
	Entity.AddComponent(ground, "Physics", Component.Physics("static"))
	self.world:AddEntity(ground)

	-- Plataformas demo
	for i = 1, 3 do
		local plat = Entity.new("Platform_" .. i)
		Entity.AddComponent(plat, "Transform", Component.Transform(Vector3.new(i*15 - 20, i*2, 0), Vector3.new(0,0,0), Vector3.new(10, 1, 10)))
		Entity.AddComponent(plat, "Render", Component.Render(Enum.Material.Concrete, Color3.fromRGB(150,150,150)))
		Entity.AddComponent(plat, "Physics", Component.Physics("static"))
		self.world:AddEntity(plat)
	end

	-- Caixas com estilos diferentes para testar ANG
	local styles = {"lowpoly", "anime", "realistic", "ultrarealistic", "photorealistic"}
	for i, style in styles do
		local box = Entity.new("Demo_" .. style)
		Entity.AddComponent(box, "Transform", Component.Transform(Vector3.new(i*6 - 15, 5, 10)))
		local render = Component.Render(Enum.Material.Plastic, Color3.fromHSV(i/#styles, 0.8, 0.9))
		render.styleProfile = style
		Entity.AddComponent(box, "Render", render)
		Entity.AddComponent(box, "Physics", Component.Physics("dynamic"))
		self.world:AddEntity(box)
	end

	print("[Arkher] Demo world -", self.world.entityCount, "entities")
end

function MainController:SetupInputHandlers()
	-- Gizmo modes
	self.input:On("Move", function(data)
		if data.mode == "translate" then
			self.gizmo:SetMode("Translate")
		end
	end)

	self.input:On("Rotate", function(data)
		if data.mode == "rotate" then
			self.gizmo:SetMode("Rotate")
		end
	end)

	self.input:On("Scale", function(data)
		if data.mode == "scale" then
			self.gizmo:SetMode("Scale")
		end
	end)

	self.input:On("Delete", function()
		if self.buildingService.selectedEntityId then
			self.buildingService:DeleteEntity(self.buildingService.selectedEntityId)
		end
	end)

	self.input:On("Undo", function()
		self.buildingService:Undo()
	end)

	self.input:On("Redo", function()
		self.buildingService:Redo()
	end)

	print("[Arkher] Input handlers - Fase 1")
end

function MainController:SetupUIHandlers()
	if not self.ui then return end

	-- Play / Save / Publish buttons
	if self.ui.topBar then
		local playControls = self.ui.topBar:FindFirstChild("PlayControls")
		if playControls then
			local saveBtn = playControls:FindFirstChild("SaveBtn")
			if saveBtn then
				saveBtn.MouseButton1Click:Connect(function()
					self:SaveProject()
				end)
			end

			local playBtn = playControls:FindFirstChild("PlayBtn")
			if playBtn then
				playBtn.MouseButton1Click:Connect(function()
					self:TogglePlay()
				end)
			end

			local publishBtn = playControls:FindFirstChild("PublishBtn")
			if publishBtn then
				publishBtn.MouseButton1Click:Connect(function()
					self:PublishProject()
				end)
			end
		end

		local styleBtn = self.ui.topBar:FindFirstChild("StyleSelector")
		if styleBtn then
			styleBtn.MouseButton1Click:Connect(function()
				self:CycleStyle()
			end)
		end
	end

	-- ContentDrawer - Vault search
	if self.ui.contentDrawer then
		local assetGrid = self.ui.contentDrawer:FindFirstChild("AssetGrid")
		if assetGrid then
			-- Popula com Vault assets
			self:PopulateVaultGrid(assetGrid)
		end
	end

	print("[Arkher] UI handlers - Fase 1")
end

function MainController:PopulateVaultGrid(grid: ScrollingFrame)
	-- Limpa
	for _, child in grid:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for _, asset in self.vault.assets do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 80, 0, 80)
		btn.BackgroundColor3 = Shell.Colors.panelLight
		btn.Text = asset.name:sub(1,20) .. "\n" .. asset.styleProfile
		btn.TextColor3 = Shell.Colors.text
		btn.TextSize = 8
		btn.TextWrapped = true
		btn.Font = Enum.Font.Gotham
		btn.Parent = grid

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			print("[Arkher] Vault asset clicked:", asset.name)
			-- TODO: Spawn asset no mundo
			self:SpawnVaultAsset(asset)
		end)
	end

	print("[Arkher] Vault grid populated -", #self.vault.assets, "assets")
end

function MainController:SpawnVaultAsset(asset: any)
	-- Spawna asset do Vault no mundo
	local pos = Vector3.new(math.random(-20,20), 5, math.random(-20,20))

	local entity = Entity.new(asset.name)
	Entity.AddComponent(entity, "Transform", Component.Transform(pos))
	
	local render = Component.Render(Enum.Material.Plastic, Color3.fromRGB(255,255,255))
	render.styleProfile = asset.styleProfile
	Entity.AddComponent(entity, "Render", render)
	
	Entity.AddComponent(entity, "Physics", Component.Physics("static"))
	Entity.AddComponent(entity, "Metadata", {
		creatorId = 0,
		createdFrom = "vault",
		tags = asset.tags,
		version = 1,
	})

	self.world:AddEntity(entity)
	self.buildingService:FireChanged()
	self:MaterializeWorld()

	print("[Arkher] Spawned Vault asset", asset.name, "at", pos)
end

function MainController:TogglePlay()
	self.isPlaying = not self.isPlaying

	if self.isPlaying then
		print("[Arkher] ▶ PLAY MODE -", self.world.entityCount, "entities")
		self:MaterializeWorld()

		-- Esconde UI de edição no Play
		if self.ui.outliner then self.ui.outliner.Visible = false end
		if self.ui.details then self.ui.details.Visible = false end
		if self.ui.contentDrawer then self.ui.contentDrawer.Visible = false end
		if self.mobileUI.toolbar then self.mobileUI.toolbar.Visible = false end

		-- Mostra UI de jogo
	else
		print("[Arkher] ⏹ EDIT MODE")
		self:MaterializeWorld()

		if self.ui.outliner then self.ui.outliner.Visible = true end
		if self.ui.details then self.ui.details.Visible = true end
		if self.ui.contentDrawer then self.ui.contentDrawer.Visible = true end
		if self.mobileUI.toolbar then self.mobileUI.toolbar.Visible = true end
	end
end

function MainController:MaterializeWorld()
	if not self.renderSystem then return end
	local count = self.renderSystem:MaterializeAll()
	print("[Arkher] Materialized", count, "entities with LOD + Streaming")
end

function MainController:DematerializeWorld()
	if self.renderSystem then
		self.renderSystem:DematerializeAll()
	end
end

function MainController:CycleStyle()
	local styles = {"lowpoly", "anime", "stylized", "semirealistic", "ultrarealistic", "photorealistic"}
	local currentIndex = table.find(styles, self.currentStyle) or 3
	local nextIndex = (currentIndex % #styles) + 1
	self.currentStyle = styles[nextIndex]

	print("[Arkher] Style ->", self.currentStyle, "-", StyleProfiles[self.currentStyle].displayName)

	self.ang:SetStyleProfile(self.currentStyle)
	self.api:GetAdapter():SetStyleProfile(self.currentStyle)

	if self.ui and self.ui.topBar then
		local styleBtn = self.ui.topBar:FindFirstChild("StyleSelector")
		if styleBtn then
			local profile = StyleProfiles[self.currentStyle]
			styleBtn.Text = profile.icon .. " " .. profile.displayName .. " ▼"
		end

		local viewport = self.ui.viewport
		if viewport then
			local label = viewport:FindFirstChild("ViewportLabel")
			if label then
				label.Text = string.format("  Perspective - %s [ANG %s] - %d entities", StyleProfiles[self.currentStyle].displayName, self.ang.enabled and "ON" or "OFF", self.world.entityCount)
			end
		end
	end

	if self.isPlaying then
		self:MaterializeWorld()
	end
end

function MainController:SaveProject()
	if self.projectManager then
		local success = self.projectManager:SaveProject()
		if success then
			print("[Arkher] Project saved -", self.projectManager:GetStats().version)
			-- Feedback visual
			if self.ui.topBar then
				local badge = self.ui.topBar:FindFirstChild("VersionBadge")
				if badge then
					badge.Text = "SAVED v" .. self.projectManager:GetStats().version
					task.delay(2, function()
						badge.Text = "ALPHA 0.2"
					end)
				end
			end
		end
	end
end

function MainController:PublishProject()
	print("[Arkher] Publish requested - Style:", self.currentStyle)

	-- Fase 1: Mock publish, Fase 3: Real via Open Cloud
	-- Mostra dialog para API Key (Fase 3)

	if self.ui.topBar then
		local publishBtn = self.ui.topBar:FindFirstChild("PlayControls") and self.ui.topBar.PlayControls:FindFirstChild("PublishBtn")
		if publishBtn then
			publishBtn.Text = "⏳ Publishing..."
			task.delay(2, function()
				publishBtn.Text = "✅ Published!"
				task.wait(1)
				publishBtn.Text = "🚀 Publish"
			end)
		end
	end

	-- Chama PublishService via Remote (Fase 3 real)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local publishRemote = ReplicatedStorage:FindFirstChild("ArkherRemotes") and ReplicatedStorage.ArkherRemotes:FindFirstChild("PublishProject")

	if publishRemote then
		publishRemote:FireServer({
			target = "NewUniverse",
			newUniverseName = self.projectManager and self.projectManager.currentMeta and self.projectManager.currentMeta.name or "Meu Jogo Arkher",
			description = "Criado no Arkher Studio - " .. self.currentStyle,
			projectId = self.projectManager and self.projectManager:GetCurrentProjectId() or "unknown",
			apiKey = "mock_api_key_fase1", -- Fase 3: pede API Key real do usuário
			world = self.world, -- Fase 3: envia JSON
			meta = self.projectManager and self.projectManager.currentMeta or {},
		})

		publishRemote.OnClientEvent:Connect(function(response)
			if response.success then
				print("[Arkher] Published! Universe:", response.universeId, "Place:", response.placeId, "URL:", response.url or "https://www.roblox.com/games/" .. response.placeId)
			else
				warn("[Arkher] Publish failed:", response.error)
			end
		end)
	else
		print("[Arkher] Publish mock - Fase 1 - In Fase 3 will create real universe via Open Cloud")
		print("[Arkher] Project would be published as:", self.projectManager and self.projectManager.currentMeta and self.projectManager.currentMeta.name)
	end
end

function MainController:GetStats(): { [string]: any }
	return {
		entityCount = self.world.entityCount,
		style = self.currentStyle,
		isPlaying = self.isPlaying,
		platform = self.input:GetPlatform(),
		ang = self.ang:GetStats(),
		vault = self.vault:GetStats(),
		project = self.projectManager and self.projectManager:GetStats() or {},
		render = self.renderSystem and self.renderSystem:GetStats() or {},
		lod = self.lodSystem and self.lodSystem:GetStats() or {},
		streaming = self.streamingSystem and self.streamingSystem:GetStats() or {},
		apiMode = self.api.useCustomEngine and "MECHA" or "ROBLOX",
		buildingMode = self.buildingService and self.buildingService.mode or "unknown",
	}
end

return MainController

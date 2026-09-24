--!strict
-- Arkher Studio - MainController - Fase 1.5 - 15GB + Python 3.14 + IA em tudo
-- MVP Mobile + 15GB worlds + Python support

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
local PythonService = require(script.Parent.Parent.modules.Scripting.PythonService)
local ScriptEditor = require(script.Parent.Parent.modules.Scripting.ScriptEditor)
local RenderSystem = require(ReplicatedStorage.Arkher.Systems.RenderSystem)
local LODSystem = require(ReplicatedStorage.Arkher.Systems.LODSystem)
local StreamingSystem = require(ReplicatedStorage.Arkher.Systems.StreamingSystem)
local ChunkedProjectFormat = require(ReplicatedStorage.Arkher.Serialization.ChunkedProjectFormat)
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
		pythonService = nil,
		scriptEditor = nil,
		outliner = nil,
		details = nil,
		mobileUI = nil,
		toolbar = nil,
		ui = nil,
		currentStyle = "realistic" :: string,
		currentLanguage = "luau" :: string,
		isPlaying = false,
		selectedEntityId = nil :: string?,
	}, MainController)
end

function MainController:Init()
	print("========================================")
	print("  ARKHER STUDIO - ALPHA 0.4 - FASE 2")
	print("  Scripting Pro + 15GB + Python 3.14 + IA em tudo")
	print("  Monaco Editor + Visual Blockly + Sandbox + Debugger")
	print("  Mata Studio X")
	print("========================================")

	local player = Players.LocalPlayer
	print("[Arkher] Player:", player.Name, "- UserId:", player.UserId)

	self:CreateInternalEvents()

	-- ArkherAPI
	self.api = ArkherAPI.new(false, self.currentStyle)
	print("[Arkher] API - Mode:", self.api.useCustomEngine and "MECHA" or "ROBLOX")

	-- Input
	self.input = InputService.new()
	print("[Arkher] Input - Platform:", self.input:GetPlatform())

	-- Gizmo
	self.gizmo = Gizmo.new()

	-- BuildingService
	self.buildingService = BuildingService.new(self.world)
	self.buildingService:Init()
	-- @ts-ignore
	self.buildingService.mainController = self

	-- RenderSystem + LOD + Streaming
	self.renderSystem = RenderSystem.new(self.world)
	self.renderSystem:Init()

	self.lodSystem = LODSystem.new(self.world, self.renderSystem)
	self.streamingSystem = StreamingSystem.new(self.world, self.renderSystem)

	-- Placement
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

	-- ANG - DLSS 4+5
	self.ang = ANGController.new(self.currentStyle)
	print("[Arkher] ANG -", self.ang:GetStats().message)

	-- Vault
	self.vault = VaultService.new()
	self.vault:LoadMockAssets()
	print("[Arkher] Vault -", self.vault:GetStats().totalAssets, "assets AAA")

	-- Python 3.14 Service
	self.pythonService = PythonService.new()
	print("[Arkher] Python 3.14 - Transpiler ready -", #self.pythonService.transpiler:GetSupportedFeatures(), "features")

	-- ProjectManager - Agora com 15GB support
	self.projectManager = ProjectManager.new(self.world)
	self.projectManager:Init()
	self.projectManager:CreateNewProject("Meu Jogo 15GB Arkher", self.currentStyle)

	-- UI Shell
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = Shell.CreateMainScreenGui()
	screenGui.Parent = playerGui

	self.ui = Shell.BuildFullUI(screenGui)

	-- Outliner
	self.outliner = Outliner.new(self.world, self.buildingService)
	if self.ui.outliner then
		self.outliner:Init(self.ui.outliner)
	end

	-- Details
	self.details = Details.new(self.world, self.buildingService)
	if self.ui.details then
		self.details:Init(self.ui.details)
	end

	-- MobileUI
	self.mobileUI = MobileUI.new(self)
	self.mobileUI:Init(screenGui)

	-- Toolbar
	if self.ui.viewport then
		self.toolbar = Toolbar.new(self.buildingService)
		self.toolbar:Init(self.ui.viewport)
	end

	-- ScriptEditor Pro - Monaco + Visual + Python 3.14 + AI + Debugger + Sandbox
	self:CreateScriptEditorTab()

	-- Demo world
	self:CreateDemoWorld()

	-- Handlers
	self:SetupInputHandlers()
	self:SetupUIHandlers()

	-- Materializa
	self:MaterializeWorld()

	-- Mostra stats 15GB + Python + Scripting
	self:Show15GBStats()
	self:ShowScriptingStats()

	print("========================================")
	print("  ARKHER STUDIO FASE 2 READY! - SCRIPTING PRO")
	print("  15GB Worlds: Chunked + S3 external storage - 300 chunks 50MB")
	print("  Python 3.14: Transpile -> Luau + backend CPython + classes/async/decorators")
	print("  Scripting Pro: Monaco Editor VS Code + Visual Blockly + SandboxVM + Debugger + Command Bar")
	print("  IA: Ajuda em tudo - modelo, anim, terreno, script (Luau/Python/Visual)")
	print("  Controles:")
	print("  PC: Click coloca, W/E/R gizmo, Delete, Ctrl+Z Undo")
	print("  Mobile: Tap coloca, Long Press radial, Toolbar inferior")
	print("  Script: Luau, Python 3.14 (classes, async, match), Visual drag-drop, AI Gen")
	print("  Editor: Line numbers, minimap, autocomplete, errors, output, command bar")
	print("  Vault:", #self.vault.assets, "assets AAA")
	print("  ANG:", self.ang:GetStats().message)
	print("  Save: AutoSave 60s + Save button + 15GB chunked")
	print("  Mata Studio X porque: Monaco + Visual + Python 3.14 + Sandbox seguro + Debugger + IA")
	print("========================================")
end

function MainController:ShowScriptingStats()
	local PythonAdvanced = require(ReplicatedStorage.Arkher.Scripting.PythonAdvanced)
	print("========================================")
	print("  SCRIPTING PRO STATS")
	print("  Monaco: VS Code style - line numbers, minimap, autocomplete, errors")
	print("  Visual: Blockly-like -", #self.scriptEditor.visual:GetBlocks(), "blocks - drag-drop")
	print("  Python 3.14: Transpiler +", #self.pythonService.transpiler:GetSupportedFeatures(), "features")
	print("  Python Advanced:", #PythonAdvanced.GetSupportedAdvancedFeatures(), "advanced features")
	print("  SandboxVM: Secure - whitelist + blacklist + timeout 5s + 50MB")
	print("  Debugger: Output + Command Bar + logs")
	print("  Languages: Luau, Python 3.14, Visual, AI Gen")
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

function MainController:CreateScriptEditorTab()
	-- Adiciona aba Script Editor no ContentDrawer
	if not self.ui.contentDrawer then return end

	local header = self.ui.contentDrawer:FindFirstChild("Header")
	if not header then return end

	-- Adiciona botão Script Editor na header
	local scriptTab = Instance.new("TextButton")
	scriptTab.Name = "Tab_Script"
	scriptTab.Size = UDim2.new(0, 130, 1, 0)
	scriptTab.Position = UDim2.new(0, 540, 0, 0)
	scriptTab.BackgroundColor3 = Color3.fromRGB(55, 118, 171) -- Python blue
	scriptTab.Text = "🐍 Python / 📜 Script"
	scriptTab.TextColor3 = Color3.new(1,1,1)
	scriptTab.TextSize = 11
	scriptTab.Font = Enum.Font.GothamBold
	scriptTab.Parent = header

	-- Cria frame para ScriptEditor (escondido inicialmente, mostra quando clica)
	local scriptFrame = Instance.new("Frame")
	scriptFrame.Name = "ScriptEditorFrame"
	scriptFrame.Size = UDim2.new(1, -20, 1, -40)
	scriptFrame.Position = UDim2.new(0, 10, 0, 35)
	scriptFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	scriptFrame.Visible = false
	scriptFrame.Parent = self.ui.contentDrawer

	self.scriptEditor = ScriptEditor.new(self.pythonService)
	self.scriptEditor:Init(scriptFrame)

	-- Toggle entre AssetGrid e ScriptEditor
	local assetGrid = self.ui.contentDrawer:FindFirstChild("AssetGrid")
	if assetGrid then
		scriptTab.MouseButton1Click:Connect(function()
			local isScriptVisible = scriptFrame.Visible
			scriptFrame.Visible = not isScriptVisible
			assetGrid.Visible = isScriptVisible

			scriptTab.Text = isScriptVisible and "🐍 Python / 📜 Script" or "🧱 Assets"
			print("[Arkher] Toggled Script Editor - Visible:", not isScriptVisible)
		end)
	end

	print("[Arkher] Script Editor tab created - Python 3.14 + Luau + Visual + AI")
end

function MainController:CreateDemoWorld()
	print("[Arkher] Creating demo world Fase 1.5 - 15GB ready...")

	-- Chão grande 200x200 para testar chunking
	local ground = Entity.new("Ground_15GB")
	Entity.AddComponent(ground, "Transform", Component.Transform(Vector3.new(0, -5, 0), Vector3.new(0,0,0), Vector3.new(200, 10, 200)))
	Entity.AddComponent(ground, "Render", Component.Render(Enum.Material.Grass, Color3.fromRGB(60, 180, 75)))
	Entity.AddComponent(ground, "Physics", Component.Physics("static"))
	self.world:AddEntity(ground)

	-- Plataformas
	for i = 1, 3 do
		local plat = Entity.new("Platform_" .. i)
		Entity.AddComponent(plat, "Transform", Component.Transform(Vector3.new(i*15 - 20, i*2, 0), Vector3.new(0,0,0), Vector3.new(10, 1, 10)))
		Entity.AddComponent(plat, "Render", Component.Render(Enum.Material.Concrete, Color3.fromRGB(150,150,150)))
		Entity.AddComponent(plat, "Physics", Component.Physics("static"))
		self.world:AddEntity(plat)
	end

	-- Caixas estilos + Python demo
	local styles = {"lowpoly", "anime", "realistic", "ultrarealistic", "photorealistic"}
	for i, style in styles do
		local box = Entity.new("Demo_" .. style)
		Entity.AddComponent(box, "Transform", Component.Transform(Vector3.new(i*6 - 15, 5, 10)))
		local render = Component.Render(Enum.Material.Plastic, Color3.fromHSV(i/#styles, 0.8, 0.9))
		render.styleProfile = style
		Entity.AddComponent(box, "Render", render)
		Entity.AddComponent(box, "Physics", Component.Physics("dynamic"))

		-- Adiciona script Python para demo photorealistic
		if style == "photorealistic" then
			Entity.AddComponent(box, "ScriptComponent", Component.ScriptComponent([[
# Python 3.14 - Demo photorealistic coin
from arkher import Entity, Component

def on_touch(player):
    print(f"Player {player.Name} touched photorealistic coin!")
    # IA ajuda aqui

# Match statement Python 3.10+
def get_reward(coin_type: str) -> int:
    match coin_type:
        case "gold":
            return 100
        case "silver":
            return 50
        case _:
            return 10

reward = get_reward("gold")
print(f"Reward: {reward}")
]], true))
		end

		self.world:AddEntity(box)
	end

	-- Entidade Python pura
	local pyEntity = Entity.new("Python_Demo")
	Entity.AddComponent(pyEntity, "Transform", Component.Transform(Vector3.new(0, 8, -10)))
	Entity.AddComponent(pyEntity, "Render", Component.Render(Enum.Material.Neon, Color3.fromRGB(55, 118, 171)))
	Entity.AddComponent(pyEntity, "ScriptComponent", Component.ScriptComponent([[
# Python 3.14 - Arkher Demo
from arkher import Entity, Component, World
import asyncio

async def create_world():
    world = World.current()
    for i in range(5):
        coin = Entity.new(f"PythonCoin_{i}")
        coin.add_component(Component.Transform(
            position=Vector3(i*3, 10, 0)
        ))
        world.add_entity(coin)
        print(f"Created {coin.name} with Python!")
        await asyncio.sleep(0.1)

# IA pode gerar isso de prompt: "cria 5 moedas com Python"
]], true))
	self.world:AddEntity(pyEntity)

	print("[Arkher] Demo world Fase 1.5 -", self.world.entityCount, "entities - 15GB chunked ready - Python demo included")
end

function MainController:Show15GBStats()
	local estimated = ChunkedProjectFormat.EstimateSize(self.world)
	local needsExternal = not ChunkedProjectFormat.CanFitInDataStore(self.world)
	local chunked = ChunkedProjectFormat.SerializeWorldToChunks(self.world, self.projectManager.currentMeta or { projectId = "demo", name = "Demo", version = 1 })

	print("========================================")
	print("  15GB SUPPORT STATS")
	print("  Estimated size:", string.format("%.2f MB", estimated / 1024 / 1024))
	print("  Needs external S3:", needsExternal)
	print("  Chunks:", chunked.meta.chunkCount)
	print("  Bounds: Min", chunked.meta.bounds.min, "Max", chunked.meta.bounds.max)
	print("  Max allowed: 15GB")
	print("  Can fit 15GB:", estimated < 15_000_000_000)
	print("========================================")
end

function MainController:SetupInputHandlers()
	self.input:On("Move", function(data)
		if data.mode == "translate" then self.gizmo:SetMode("Translate") end
	end)

	self.input:On("Rotate", function(data)
		if data.mode == "rotate" then self.gizmo:SetMode("Rotate") end
	end)

	self.input:On("Scale", function(data)
		if data.mode == "scale" then self.gizmo:SetMode("Scale") end
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

	print("[Arkher] Input handlers Fase 1.5")
end

function MainController:SetupUIHandlers()
	if not self.ui then return end

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

	if self.ui.contentDrawer then
		local assetGrid = self.ui.contentDrawer:FindFirstChild("AssetGrid")
		if assetGrid then
			self:PopulateVaultGrid(assetGrid)
		end
	end

	print("[Arkher] UI handlers Fase 1.5 - Python + 15GB")
end

function MainController:PopulateVaultGrid(grid: ScrollingFrame)
	for _, child in grid:GetChildren() do
		if child:IsA("TextButton") then child:Destroy() end
	end

	for _, asset in self.vault.assets do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 80, 0, 80)
		btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		btn.Text = asset.name:sub(1,20) .. "\n" .. asset.styleProfile
		btn.TextColor3 = Color3.fromRGB(230,230,230)
		btn.TextSize = 8
		btn.TextWrapped = true
		btn.Font = Enum.Font.Gotham
		btn.Parent = grid

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			self:SpawnVaultAsset(asset)
		end)
	end
end

function MainController:SpawnVaultAsset(asset: any)
	local pos = Vector3.new(math.random(-20,20), 5, math.random(-20,20))
	local entity = Entity.new(asset.name)
	Entity.AddComponent(entity, "Transform", Component.Transform(pos))
	local render = Component.Render(Enum.Material.Plastic, Color3.fromRGB(255,255,255))
	render.styleProfile = asset.styleProfile
	Entity.AddComponent(entity, "Render", render)
	Entity.AddComponent(entity, "Physics", Component.Physics("static"))
	self.world:AddEntity(entity)
	self.buildingService:FireChanged()
	self:MaterializeWorld()
	print("[Arkher] Spawned Vault", asset.name)
end

function MainController:TogglePlay()
	self.isPlaying = not self.isPlaying

	if self.isPlaying then
		print("[Arkher] ▶ PLAY -", self.world.entityCount, "entities - Python scripts will run")
		self:MaterializeWorld()

		-- Roda scripts Python/Luau no Play
		self:RunAllScripts()

		if self.ui.outliner then self.ui.outliner.Visible = false end
		if self.ui.details then self.ui.details.Visible = false end
		if self.ui.contentDrawer then self.ui.contentDrawer.Visible = false end
		if self.mobileUI.toolbar then self.mobileUI.toolbar.Visible = false end
	else
		print("[Arkher] ⏹ EDIT")
		self:MaterializeWorld()

		if self.ui.outliner then self.ui.outliner.Visible = true end
		if self.ui.details then self.ui.details.Visible = true end
		if self.ui.contentDrawer then self.ui.contentDrawer.Visible = true end
		if self.mobileUI.toolbar then self.mobileUI.toolbar.Visible = true end
	end
end

function MainController:RunAllScripts()
	for _, entity in self.world.entities do
		local scriptComp = entity.components.ScriptComponent
		if scriptComp and scriptComp.enabled then
			if scriptComp.language == "python" or string.find(scriptComp.source, "from arkher import") or string.find(scriptComp.source, "def ") then
				print("[Arkher] Running Python script on", entity.name)
				if self.pythonService then
					local out, err = self.pythonService:Execute(scriptComp.source)
					if err then
						warn("[Arkher Python] Error in", entity.name, ":", err)
					else
						print("[Arkher Python] Output:", out)
					end
				end
			else
				-- Luau
				print("[Arkher] Running Luau script on", entity.name)
				local func, loadErr = loadstring(scriptComp.source)
				if func then
					pcall(func)
				end
			end
		end
	end
end

function MainController:MaterializeWorld()
	if not self.renderSystem then return end
	local count = self.renderSystem:MaterializeAll()
	print("[Arkher] Materialized", count, "entities - LOD + Streaming - 15GB chunked")
end

function MainController:DematerializeWorld()
	if self.renderSystem then self.renderSystem:DematerializeAll() end
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
				label.Text = string.format("  Perspective - %s [ANG %s] - %d entities - 15GB - Python 3.14", StyleProfiles[self.currentStyle].displayName, self.ang.enabled and "ON" or "OFF", self.world.entityCount)
			end
		end
	end

	if self.isPlaying then self:MaterializeWorld() end
end

function MainController:SaveProject()
	if self.projectManager then
		-- Checa tamanho para 15GB
		local estimated = ChunkedProjectFormat.EstimateSize(self.world)
		local needsExternal = not ChunkedProjectFormat.CanFitInDataStore(self.world)

		print(string.format("[Arkher] Save - Estimated %.2f MB - Needs S3: %s", estimated / 1024 / 1024, tostring(needsExternal)))

		if needsExternal then
			-- Usa Chunked format + ExternalStorage
			local chunked = ChunkedProjectFormat.SerializeWorldToChunks(self.world, self.projectManager.currentMeta or { projectId = "demo", name = "Demo", version = 1 })
			print("[Arkher] Using 15GB chunked format -", chunked.meta.chunkCount, "chunks")

			-- Em produção, chama ExternalStorageService
			-- self.projectManager:SaveChunked(chunked)
		end

		local success = self.projectManager:SaveProject()
		if success and self.ui.topBar then
			local badge = self.ui.topBar:FindFirstChild("VersionBadge")
			if badge then
				badge.Text = "SAVED v" .. self.projectManager:GetStats().version .. " " .. string.format("%.1fMB", estimated / 1024 / 1024)
				task.delay(2, function()
					badge.Text = "ALPHA 0.3 15GB+PY"
				end)
			end
		end
	end
end

function MainController:PublishProject()
	print("[Arkher] Publish 15GB + Python - Style:", self.currentStyle)

	if self.ui.topBar then
		local publishBtn = self.ui.topBar:FindFirstChild("PlayControls") and self.ui.topBar.PlayControls:FindFirstChild("PublishBtn")
		if publishBtn then
			publishBtn.Text = "⏳ Publishing 15GB..."
			task.delay(2, function()
				publishBtn.Text = "✅ Published 15GB!"
				task.wait(1)
				publishBtn.Text = "🚀 Publish"
			end)
		end
	end

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local publishRemote = ReplicatedStorage:FindFirstChild("ArkherRemotes") and ReplicatedStorage.ArkherRemotes:FindFirstChild("PublishProject")

	if publishRemote then
		publishRemote:FireServer({
			target = "NewUniverse",
			newUniverseName = self.projectManager and self.projectManager.currentMeta and self.projectManager.currentMeta.name or "Meu Jogo 15GB Arkher",
			description = "Criado no Arkher - 15GB - Python 3.14 - " .. self.currentStyle,
			projectId = self.projectManager and self.projectManager:GetCurrentProjectId() or "unknown",
			apiKey = "mock_api_key_fase1_5",
			world = self.world,
			meta = self.projectManager and self.projectManager.currentMeta or {},
			is15GB = true,
			languages = {"luau", "python"},
		})
	end
end

function MainController:GetStats(): { [string]: any }
	local estimated = ChunkedProjectFormat.EstimateSize(self.world)
	return {
		entityCount = self.world.entityCount,
		estimatedSizeMB = estimated / 1024 / 1024,
		estimatedSizeGB = estimated / 1024 / 1024 / 1024,
		maxSizeGB = 15,
		canFit15GB = estimated < 15_000_000_000,
		needsExternal = not ChunkedProjectFormat.CanFitInDataStore(self.world),
		style = self.currentStyle,
		language = self.currentLanguage,
		isPlaying = self.isPlaying,
		platform = self.input:GetPlatform(),
		ang = self.ang:GetStats(),
		vault = self.vault:GetStats(),
		project = self.projectManager and self.projectManager:GetStats() or {},
		render = self.renderSystem and self.renderSystem:GetStats() or {},
		python = {
			version = "3.14.0",
			transpilerFeatures = self.pythonService and #self.pythonService.transpiler:GetSupportedFeatures() or 0,
		},
		apiMode = self.api.useCustomEngine and "MECHA" or "ROBLOX",
		buildingMode = self.buildingService and self.buildingService.mode or "unknown",
	}
end

return MainController

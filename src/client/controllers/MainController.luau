--!strict
-- Arkher Studio - MainController - Controla toda a engine no client

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shell = require(script.Parent.Parent.modules.UI.Shell)
local InputService = require(script.Parent.Parent.modules.Input.InputService)
local Gizmo = require(script.Parent.Parent.modules.Building.Gizmo)
local World = require(ReplicatedStorage.Arkher.ECS.World)
local Entity = require(ReplicatedStorage.Arkher.ECS.Entity)
local Component = require(ReplicatedStorage.Arkher.ECS.Component)
local ArkherAPI = require(ReplicatedStorage.Arkher.ArkherAPI.ArkherAPI)
local ANGController = require(script.Parent.Parent.modules.ANG.ANGController)
local VaultService = require(script.Parent.Parent.modules.Vault.VaultService)
local StyleProfiles = require(ReplicatedStorage.Arkher.Constants.StyleProfiles)

local MainController = {}
MainController.__index = MainController

function MainController.new()
	return setmetatable({
		world = World.new(),
		api = nil,
		input = nil,
		gizmo = nil,
		ang = nil,
		vault = nil,
		ui = nil,
		currentProjectId = nil,
		currentStyle = "realistic" :: string,
		isPlaying = false,
		selectedEntityId = nil :: string?,
	}, MainController)
end

function MainController:Init()
	print("========================================")
	print("  ARKHER STUDIO - ALPHA 0.1 - FASE 0")
	print("  The Engine that kills Roblox Studio")
	print("========================================")

	-- Detecta player
	local player = Players.LocalPlayer
	print("[Arkher] Player:", player.Name, "- UserId:", player.UserId)

	-- Inicializa ArkherAPI (por enquanto Roblox, Fase 6 Mecha)
	self.api = ArkherAPI.new(false, self.currentStyle)
	print("[Arkher] API initialized - Mode:", self.api.useCustomEngine and "MECHA" or "ROBLOX")

	-- Input universal (Mobile, PC, Console, VR)
	self.input = InputService.new()
	print("[Arkher] Input - Platform:", self.input:GetPlatform())

	-- Gizmo
	self.gizmo = Gizmo.new()
	print("[Arkher] Gizmo initialized")

	-- ANG - DLSS 4+5 Adaptive
	self.ang = ANGController.new(self.currentStyle)
	print("[Arkher] ANG Controller -", self.ang:GetStats().message)

	-- Vault
	self.vault = VaultService.new()
	self.vault:LoadMockAssets()
	print("[Arkher] Vault -", self.vault:GetStats().totalAssets, "assets loaded")

	-- UI Shell (Unreal-inspired)
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = Shell.CreateMainScreenGui()
	screenGui.Parent = playerGui

	self.ui = Shell.BuildFullUI(screenGui)
	print("[Arkher] UI Shell built - Unreal 5 inspired")

	-- Cria mundo inicial com algumas entidades demo
	self:CreateDemoWorld()

	-- Setup input handlers
	self:SetupInputHandlers()

	-- Setup UI handlers
	self:SetupUIHandlers()

	print("========================================")
	print("  ARKHER STUDIO READY!")
	print("  Press PLAY to test - Select style in top bar")
	print("  Vault has", #self.vault.assets, "AAA assets")
	print("  ANG:", self.ang:GetStats().message)
	print("========================================")
end

function MainController:CreateDemoWorld()
	print("[Arkher] Creating demo world...")

	-- Chão
	local ground = Entity.new("Ground")
	Entity.AddComponent(ground, "Transform", Component.Transform(Vector3.new(0, -5, 0), Vector3.new(0,0,0), Vector3.new(100, 10, 100)))
	Entity.AddComponent(ground, "Render", Component.Render(Enum.Material.Grass, Color3.fromRGB(60, 180, 75)))
	Entity.AddComponent(ground, "Physics", Component.Physics("static"))
	self.world:AddEntity(ground)

	-- Algumas caixas demo com estilos diferentes
	local styles = {"lowpoly", "anime", "realistic", "ultrarealistic", "photorealistic"}
	for i, style in styles do
		local box = Entity.new("Demo_" .. style)
		Entity.AddComponent(box, "Transform", Component.Transform(Vector3.new(i*6 - 15, 2, 0)))
		local render = Component.Render(Enum.Material.Plastic, Color3.fromHSV(i/#styles, 0.8, 0.9))
		render.styleProfile = style
		Entity.AddComponent(box, "Render", render)
		Entity.AddComponent(box, "Physics", Component.Physics("dynamic"))
		self.world:AddEntity(box)
	end

	print("[Arkher] Demo world created -", self.world.entityCount, "entities - Styles:", table.concat(styles, ", "))
end

function MainController:SetupInputHandlers()
	-- W,E,R para gizmo
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

	self.input:On("Select", function(data)
		print("[Arkher] Select at", data.position)
		-- TODO: Raycast para selecionar entidade
	end)

	self.input:On("Delete", function()
		if self.selectedEntityId then
			print("[Arkher] Delete entity", self.selectedEntityId)
			self.world:RemoveEntity(self.selectedEntityId)
			self.selectedEntityId = nil
		end
	end)

	self.input:On("Focus", function()
		print("[Arkher] Focus on selected")
	end)

	print("[Arkher] Input handlers setup")
end

function MainController:SetupUIHandlers()
	-- TopBar Play button
	if self.ui and self.ui.topBar then
		local playBtn = self.ui.topBar:FindFirstChild("PlayControls") and self.ui.topBar.PlayControls:FindFirstChild("PlayBtn")
		if playBtn then
			playBtn.MouseButton1Click:Connect(function()
				self:TogglePlay()
			end)
		end

		local styleBtn = self.ui.topBar:FindFirstChild("StyleSelector")
		if styleBtn then
			styleBtn.MouseButton1Click:Connect(function()
				self:CycleStyle()
			end)
		end
	end

	print("[Arkher] UI handlers setup")
end

function MainController:TogglePlay()
	self.isPlaying = not self.isPlaying

	if self.isPlaying then
		print("[Arkher] ▶ PLAY MODE - Materializing", self.world.entityCount, "entities")
		-- TODO: Materializar entidades virtuais em Instances reais
		self:MaterializeWorld()
	else
		print("[Arkher] ⏹ EDIT MODE")
		self:DematerializeWorld()
	end
end

function MainController:MaterializeWorld()
	-- Converte ECS virtual para Instances reais do Roblox (Fase 1)
	-- Fase 6: Usaria MechaAdapter para criar EditableMesh custom

	local worldFolder = workspace:FindFirstChild("ArkherWorld")
	if not worldFolder then
		worldFolder = Instance.new("Folder")
		worldFolder.Name = "ArkherWorld"
		worldFolder.Parent = workspace
	end

	worldFolder:ClearAllChildren()

	for _, entity in self.world.entities do
		local transform = entity.components.Transform
		local render = entity.components.Render
		if transform and render then
			local part = Instance.new("Part")
			part.Name = entity.name .. " [" .. render.styleProfile .. "]"
			part.Anchored = true
			part.Size = transform.scale * 4
			part.CFrame = transform.cframe
			part.Color = render.color
			part.Material = render.material
			part.Parent = worldFolder

			-- Aplica ANG Style Enhancer visual
			if render.styleProfile == "anime" then
				local highlight = Instance.new("Highlight")
				highlight.FillTransparency = 1
				highlight.OutlineColor = Color3.new(0,0,0)
				highlight.OutlineTransparency = 0
				highlight.Parent = part
			elseif render.styleProfile == "photorealistic" then
				part.Material = Enum.Material.SmoothPlastic
				-- Fase 5: Adicionaria SurfaceAppearance 4K
			end
		end
	end

	print("[Arkher] Materialized", #worldFolder:GetChildren(), "parts")
end

function MainController:DematerializeWorld()
	local worldFolder = workspace:FindFirstChild("ArkherWorld")
	if worldFolder then
		worldFolder:ClearAllChildren()
	end
	print("[Arkher] Dematerialized world")
end

function MainController:CycleStyle()
	local styles = {"lowpoly", "anime", "stylized", "semirealistic", "ultrarealistic", "photorealistic"}
	local currentIndex = table.find(styles, self.currentStyle) or 3
	local nextIndex = (currentIndex % #styles) + 1
	self.currentStyle = styles[nextIndex]

	print("[Arkher] Style changed to", self.currentStyle, "-", StyleProfiles[self.currentStyle].displayName)

	-- Atualiza ANG
	self.ang:SetStyleProfile(self.currentStyle)

	-- Atualiza API
	self.api:GetAdapter():SetStyleProfile(self.currentStyle)

	-- Atualiza UI
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
				label.Text = string.format("  Perspective - %s [ANG %s]", StyleProfiles[self.currentStyle].displayName, self.ang.enabled and "ON" or "OFF")
			end
		end
	end

	-- Re-materializa se estiver em Play
	if self.isPlaying then
		self:MaterializeWorld()
	end
end

function MainController:SaveProject()
	print("[Arkher] Saving project", self.currentProjectId or "new project")
	-- Chama ProjectService via RemoteEvent (Fase 1)
end

function MainController:GetStats(): { [string]: any }
	return {
		entityCount = self.world.entityCount,
		style = self.currentStyle,
		isPlaying = self.isPlaying,
		platform = self.input:GetPlatform(),
		ang = self.ang:GetStats(),
		vault = self.vault:GetStats(),
		apiMode = self.api.useCustomEngine and "MECHA" or "ROBLOX",
	}
end

return MainController

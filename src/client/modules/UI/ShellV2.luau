--!strict
-- Arkher Studio - ShellV2 - Polimento Total Fase 0-4 - UI COMPLETA
-- Inspirado no melhor do mundo, nunca copiar:
-- - Figma: auto-layout, constraints, components, onboarding
-- - Unreal 5: docking, details, world outliner, content drawer, play
-- - VS Code: command palette, status bar, sidebar, minimap, themes
-- - Blender: areas, editors, tools, properties, 3D viewport
-- - Notion: friendly, beginner, hints, templates
-- Mas NOSSO: amigavel pra iniciantes, intermediarios, avancados, confortavel em TODOS dispositivos especialmente mobile
-- Mobile: A01 720x1280 até Flagship, Tablet, Desktop 1080p-8K, Console, VR

local ThemeSystem = require(script.Parent.ThemeSystem)
local AdaptiveLayout = require(script.Parent.AdaptiveLayout)

local ShellV2 = {}
ShellV2.__index = ShellV2

export type UserLevel = "Beginner" | "Intermediate" | "Advanced" | "Pro"

function ShellV2.new(themeSystem: any, adaptiveLayout: any)
	return setmetatable({
		themeSystem = themeSystem,
		adaptive = adaptiveLayout,
		level = "Intermediate" :: UserLevel,
		mainGui = nil :: ScreenGui?,
		topBar = nil :: Frame?,
		outliner = nil :: Frame?,
		details = nil :: Frame?,
		contentDrawer = nil :: Frame?,
		viewport = nil :: Frame?,
		statusBar = nil :: Frame?,
		mobileToolbar = nil :: Frame?,
		bottomSheet = nil :: Frame?,
		notifications = {} :: { any },
	}, ShellV2)
end

function ShellV2:CreateMainScreenGui(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "ArkherStudioShellV2"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10

	local colors = self.themeSystem:GetColors()
	local levelConfig = self.themeSystem:GetLevelConfig()

	-- Detect mobile for name
	if self.adaptive.isMobile then
		gui.Name = "ArkherStudioShellV2_Mobile_" .. self.adaptive.device
	end

	return gui
end

function ShellV2:CreateTopBarV2(): Frame
	local colors = self.themeSystem:GetColors()
	local levelConfig = self.themeSystem:GetLevelConfig()
	local adaptiveConfig = self.adaptive:GetLayoutConfig()

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBarV2"
	topBar.Size = UDim2.new(1, 0, 0, adaptiveConfig.topBarHeight)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = colors.backgroundSecondary
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 10

	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.border
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = topBar

	-- Logo Arkher com nivel indicator
	local logoContainer = Instance.new("Frame")
	logoContainer.Name = "LogoContainer"
	logoContainer.Size = UDim2.new(0, 220, 1, 0)
	logoContainer.BackgroundTransparency = 1
	logoContainer.Parent = topBar

	local logo = Instance.new("TextLabel")
	logo.Name = "Logo"
	logo.Size = UDim2.new(0, 150, 0, 20)
	logo.Position = UDim2.new(0, 10, 0, 2)
	logo.BackgroundTransparency = 1
	logo.Text = "ARKHER STUDIO"
	logo.TextColor3 = colors.text
	logo.TextSize = 15
	logo.Font = Enum.Font.GothamBold
	logo.TextXAlignment = Enum.TextXAlignment.Left
	logo.Parent = logoContainer

	local levelBadge = Instance.new("TextButton")
	levelBadge.Name = "LevelBadge"
	levelBadge.Size = UDim2.new(0, 80, 0, 18)
	levelBadge.Position = UDim2.new(0, 10, 0, 22)
	levelBadge.BackgroundColor3 = self.level == "Beginner" and colors.success or self.level == "Intermediate" and colors.accent or self.level == "Advanced" and colors.modelerPrimary or colors.aiPrimary
	levelBadge.Text = self.level:upper() .. " ▼"
	levelBadge.TextColor3 = Color3.new(1,1,1)
	levelBadge.TextSize = 9
	levelBadge.Font = Enum.Font.GothamBold
	levelBadge.Parent = logoContainer

	local levelCorner = Instance.new("UICorner")
	levelCorner.CornerRadius = UDim.new(0, 4)
	levelCorner.Parent = levelBadge

	-- Version badge
	local badge = Instance.new("TextLabel")
	badge.Name = "VersionBadge"
	badge.Size = UDim2.new(0, 110, 0, 18)
	badge.Position = UDim2.new(0, 100, 0, 22)
	badge.BackgroundColor3 = colors.accent
	badge.Text = "ALPHA 0.7 POLISHED"
	badge.TextColor3 = Color3.new(1,1,1)
	badge.TextSize = 9
	badge.Font = Enum.Font.GothamBold
	badge.Parent = logoContainer

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 4)
	badgeCorner.Parent = badge

	-- Menu bar (File Edit View etc) - so desktop intermediate+
	if not self.adaptive.isMobile and (self.level == "Intermediate" or self.level == "Advanced" or self.level == "Pro") then
		local menuBar = Instance.new("Frame")
		menuBar.Name = "MenuBar"
		menuBar.Size = UDim2.new(0, 400, 1, 0)
		menuBar.Position = UDim2.new(0, 230, 0, 0)
		menuBar.BackgroundTransparency = 1
		menuBar.Parent = topBar

		local menuItems = self.level == "Beginner" and {"File", "Edit", "Help"} or {"File", "Edit", "View", "Build", "Tools", "Window", "Help"}
		for i, item in menuItems do
			local menuBtn = Instance.new("TextButton")
			menuBtn.Name = item .. "Menu"
			menuBtn.Size = UDim2.new(0, 55, 1, 0)
			menuBtn.Position = UDim2.new(0, (i-1)*60, 0, 0)
			menuBtn.BackgroundTransparency = 1
			menuBtn.Text = item
			menuBtn.TextColor3 = colors.textDim
			menuBtn.TextSize = 12
			menuBtn.Font = Enum.Font.Gotham
			menuBtn.Parent = menuBar
		end
	end

	-- Play controls (centro) - sempre visivel, mas adaptado por nivel
	local playContainer = Instance.new("Frame")
	playContainer.Name = "PlayControls"
	playContainer.Size = UDim2.new(0, 320, 1, 0)
	playContainer.Position = UDim2.new(0.5, -160, 0, 0)
	playContainer.BackgroundTransparency = 1
	playContainer.Parent = topBar

	-- Beginner: so Save e Play grandes
	-- Intermediate: Save Play Publish
	-- Advanced/Pro: + Build + Style + Command Palette

	local saveBtn = Instance.new("TextButton")
	saveBtn.Name = "SaveBtn"
	saveBtn.Size = self.level == "Beginner" and UDim2.new(0, 80, 0, 32) or UDim2.new(0, 60, 0, 28)
	saveBtn.Position = UDim2.new(0, 0, 0.5, -14)
	saveBtn.BackgroundColor3 = colors.panelLight
	saveBtn.Text = self.level == "Beginner" and "💾 Save" or "💾 Save"
	saveBtn.TextColor3 = colors.text
	saveBtn.TextSize = 11
	saveBtn.Font = Enum.Font.Gotham
	saveBtn.Parent = playContainer

	local saveCorner = Instance.new("UICorner")
	saveCorner.CornerRadius = UDim.new(0, 6)
	saveCorner.Parent = saveBtn

	-- Tooltip para beginner
	if self.level == "Beginner" then
		saveBtn:SetAttribute("Tooltip", "Salvar seu projeto - Ctrl+S - Salva tudo incluindo terreno 15GB")
	end

	local playBtn = Instance.new("TextButton")
	playBtn.Name = "PlayBtn"
	playBtn.Size = self.level == "Beginner" and UDim2.new(0, 100, 0, 32) or UDim2.new(0, 80, 0, 28)
	playBtn.Position = UDim2.new(0, self.level == "Beginner" and 90 or 70, 0.5, -14)
	playBtn.BackgroundColor3 = colors.success
	playBtn.Text = self.level == "Beginner" and "▶ PLAY" or "▶ PLAY"
	playBtn.TextColor3 = Color3.new(1,1,1)
	playBtn.TextSize = 12
	playBtn.Font = Enum.Font.GothamBold
	playBtn.Parent = playContainer

	local playCorner = Instance.new("UICorner")
	playCorner.CornerRadius = UDim.new(0, 6)
	playCorner.Parent = playBtn

	if self.level == "Beginner" then
		playBtn:SetAttribute("Tooltip", "Testar seu jogo - Veja como ficou!")
	end

	local publishBtn = Instance.new("TextButton")
	publishBtn.Name = "PublishBtn"
	publishBtn.Size = UDim2.new(0, 80, 0, 28)
	publishBtn.Position = UDim2.new(0, self.level == "Beginner" and 200 or 160, 0.5, -14)
	publishBtn.BackgroundColor3 = colors.accent
	publishBtn.Text = "🚀 Publish"
	publishBtn.TextColor3 = Color3.new(1,1,1)
	publishBtn.TextSize = 11
	publishBtn.Font = Enum.Font.GothamBold
	publishBtn.Parent = playContainer

	local publishCorner = Instance.new("UICorner")
	publishCorner.CornerRadius = UDim.new(0, 6)
	publishCorner.Parent = publishBtn

	if self.level == "Beginner" then
		publishBtn:SetAttribute("Tooltip", "Publicar seu jogo no Roblox - Vira jogo real no seu perfil!")
	end

	-- Command palette button (Intermediate+)
	if self.level ~= "Beginner" then
		local cmdBtn = Instance.new("TextButton")
		cmdBtn.Name = "CommandPaletteBtn"
		cmdBtn.Size = UDim2.new(0, 40, 0, 28)
		cmdBtn.Position = UDim2.new(0, 250, 0.5, -14)
		cmdBtn.BackgroundColor3 = colors.panelLight
		cmdBtn.Text = "⌘K"
		cmdBtn.TextColor3 = colors.textDim
		cmdBtn.TextSize = 12
		cmdBtn.Font = Enum.Font.GothamBold
		cmdBtn.Parent = playContainer

		local cmdCorner = Instance.new("UICorner")
		cmdCorner.CornerRadius = UDim.new(0, 6)
		cmdCorner.Parent = cmdBtn
	end

	-- Right side: Style + Help + Settings
	local rightContainer = Instance.new("Frame")
	rightContainer.Name = "RightContainer"
	rightContainer.Size = UDim2.new(0, 280, 1, 0)
	rightContainer.Position = UDim2.new(1, -280, 0, 0)
	rightContainer.BackgroundTransparency = 1
	rightContainer.Parent = topBar

	-- Help button (Beginner: grande e visivel)
	local helpBtn = Instance.new("TextButton")
	helpBtn.Name = "HelpBtn"
	helpBtn.Size = self.level == "Beginner" and UDim2.new(0, 70, 0, 28) or UDim2.new(0, 40, 0, 28)
	helpBtn.Position = UDim2.new(0, 0, 0.5, -14)
	helpBtn.BackgroundColor3 = self.level == "Beginner" and colors.aiPrimary or colors.panelLight
	helpBtn.Text = self.level == "Beginner" and "❓ Help" or "❓"
	helpBtn.TextColor3 = self.level == "Beginner" and Color3.new(0,0,0) or colors.text
	helpBtn.TextSize = 12
	helpBtn.Font = Enum.Font.GothamBold
	helpBtn.Parent = rightContainer

	local helpCorner = Instance.new("UICorner")
	helpCorner.CornerRadius = UDim.new(0, 6)
	helpCorner.Parent = helpBtn

	-- AI button
	local aiBtn = Instance.new("TextButton")
	aiBtn.Name = "AIButton"
	aiBtn.Size = UDim2.new(0, 50, 0, 28)
	aiBtn.Position = UDim2.new(0, self.level == "Beginner" and 80 or 50, 0.5, -14)
	aiBtn.BackgroundColor3 = colors.aiPrimary
	aiBtn.Text = "🤖 AI"
	aiBtn.TextColor3 = Color3.new(0,0,0)
	aiBtn.TextSize = 11
	aiBtn.Font = Enum.Font.GothamBold
	aiBtn.Parent = rightContainer

	local aiCorner = Instance.new("UICorner")
	aiCorner.CornerRadius = UDim.new(0, 6)
	aiCorner.Parent = aiBtn

	-- Style selector
	local styleSelector = Instance.new("TextButton")
	styleSelector.Name = "StyleSelector"
	styleSelector.Size = UDim2.new(0, 150, 0, 28)
	styleSelector.Position = UDim2.new(0, 110, 0.5, -14)
	styleSelector.BackgroundColor3 = colors.panelLight
	styleSelector.Text = "🎨 Realistic ▼"
	styleSelector.TextColor3 = colors.text
	styleSelector.TextSize = 12
	styleSelector.Font = Enum.Font.Gotham
	styleSelector.Parent = rightContainer

	local styleCorner = Instance.new("UICorner")
	styleCorner.CornerRadius = UDim.new(0, 6)
	styleCorner.Parent = styleSelector

	return topBar
end

function ShellV2:CreateOutlinerV2(): Frame
	local colors = self.themeSystem:GetColors()
	local levelConfig = self.themeSystem:GetLevelConfig()
	local adaptiveConfig = self.adaptive:GetLayoutConfig()

	local outliner = Instance.new("Frame")
	outliner.Name = "OutlinerV2"
	outliner.Size = UDim2.new(0, adaptiveConfig.sidePanelWidth, 1, -adaptiveConfig.topBarHeight - adaptiveConfig.contentDrawerHeight - 30)
	outliner.Position = UDim2.new(0, 0, 0, adaptiveConfig.topBarHeight + 10)
	outliner.BackgroundColor3 = colors.panel
	outliner.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = outliner

	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.border
	stroke.Thickness = 1
	stroke.Parent = outliner

	-- Header com actions
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundColor3 = colors.panelLight
	header.Parent = outliner

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = header

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.6, 0, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = self.level == "Beginner" and "🌍 My World" or "🌍 WORLD OUTLINER"
	title.TextColor3 = colors.text
	title.TextSize = 12
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	-- Add button
	local addBtn = Instance.new("TextButton")
	addBtn.Name = "AddBtn"
	addBtn.Size = UDim2.new(0, 28, 0, 24)
	addBtn.Position = UDim2.new(1, -70, 0.5, -12)
	addBtn.BackgroundColor3 = colors.accent
	addBtn.Text = "➕"
	addBtn.TextSize = 12
	addBtn.Parent = header

	local addCorner = Instance.new("UICorner")
	addCorner.CornerRadius = UDim.new(0, 4)
	addCorner.Parent = addBtn

	-- Filter button
	local filterBtn = Instance.new("TextButton")
	filterBtn.Name = "FilterBtn"
	filterBtn.Size = UDim2.new(0, 28, 0, 24)
	filterBtn.Position = UDim2.new(1, -35, 0.5, -12)
	filterBtn.BackgroundColor3 = colors.panel
	filterBtn.Text = "🔍"
	filterBtn.TextSize = 12
	filterBtn.Parent = header

	local filterCorner = Instance.new("UICorner")
	filterCorner.CornerRadius = UDim.new(0, 4)
	filterCorner.Parent = filterBtn

	-- Search bar - so intermediate+
	if self.level ~= "Beginner" or self.adaptive.isDesktop then
		local search = Instance.new("TextBox")
		search.Name = "Search"
		search.Size = UDim2.new(1, -20, 0, 28)
		search.Position = UDim2.new(0, 10, 0, 46)
		search.BackgroundColor3 = colors.background
		search.PlaceholderText = self.level == "Beginner" and "🔍 Search my objects..." or "🔍 Search entities... (Ctrl+F)"
		search.Text = ""
		search.TextColor3 = colors.text
		search.TextSize = 12
		search.Font = Enum.Font.Gotham
		search.ClearTextOnFocus = false
		search.Parent = outliner

		local searchCorner = Instance.new("UICorner")
		searchCorner.CornerRadius = UDim.new(0, 6)
		searchCorner.Parent = search
	end

	-- Entity list
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "EntityList"
	scroll.Size = UDim2.new(1, -20, 1, self.level == "Beginner" and -60 or -90)
	scroll.Position = UDim2.new(0, 10, 0, self.level == "Beginner" and 50 or 85)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = outliner

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = scroll

	-- Beginner hint
	if self.level == "Beginner" then
		local hint = Instance.new("TextLabel")
		hint.Name = "BeginnerHint"
		hint.Size = UDim2.new(1, -20, 0, 40)
		hint.Position = UDim2.new(0, 10, 1, -50)
		hint.BackgroundColor3 = colors.aiPrimary
		hint.BackgroundTransparency = 0.8
		hint.Text = "💡 Tip: Click objects in world to select them!"
		hint.TextColor3 = Color3.new(0,0,0)
		hint.TextSize = 10
		hint.Font = Enum.Font.Gotham
		hint.TextWrapped = true
		hint.Parent = outliner

		local hintCorner = Instance.new("UICorner")
		hintCorner.CornerRadius = UDim.new(0, 6)
		hintCorner.Parent = hint
	end

	return outliner
end

function ShellV2:CreateDetailsV2(): Frame
	local colors = self.themeSystem:GetColors()
	local levelConfig = self.themeSystem:GetLevelConfig()
	local adaptiveConfig = self.adaptive:GetLayoutConfig()

	local details = Instance.new("Frame")
	details.Name = "DetailsV2"
	details.Size = UDim2.new(0, adaptiveConfig.sidePanelWidth + 40, 1, -adaptiveConfig.topBarHeight - adaptiveConfig.contentDrawerHeight - 30)
	details.Position = UDim2.new(1, -adaptiveConfig.sidePanelWidth - 40, 0, adaptiveConfig.topBarHeight + 10)
	details.BackgroundColor3 = colors.panel
	details.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = details

	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.border
	stroke.Thickness = 1
	stroke.Parent = details

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundColor3 = colors.panelLight
	header.Parent = details

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = header

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = self.level == "Beginner" and "📋 Properties" or "📋 DETAILS"
	title.TextColor3 = colors.text
	title.TextSize = 12
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	-- Content scroll
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "DetailsScroll"
	scroll.Size = UDim2.new(1, -20, 1, -46)
	scroll.Position = UDim2.new(0, 10, 0, 46)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = details

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroll

	return details
end

function ShellV2:CreateContentDrawerV2(): Frame
	local colors = self.themeSystem:GetColors()
	local adaptiveConfig = self.adaptive:GetLayoutConfig()

	local drawer = Instance.new("Frame")
	drawer.Name = "ContentDrawerV2"
	drawer.Size = UDim2.new(1, -adaptiveConfig.sidePanelWidth*2 - 60, 0, adaptiveConfig.contentDrawerHeight)
	drawer.Position = UDim2.new(0, adaptiveConfig.sidePanelWidth + 10, 1, -adaptiveConfig.contentDrawerHeight - 10)
	drawer.BackgroundColor3 = colors.panel
	drawer.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = drawer

	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.border
	stroke.Thickness = 1
	stroke.Parent = drawer

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundColor3 = colors.panelLight
	header.Parent = drawer

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = header

	-- Tabs - adaptado por nivel
	local tabs
	if self.level == "Beginner" then
		tabs = {
			{ name = "💎 My Assets", color = colors.accent, level = "Beginner" },
			{ name = "🧰 Add Objects", color = colors.panelLight, level = "Beginner" },
			{ name = "🎨 Make 3D", color = colors.modelerPrimary, level = "Beginner" },
			{ name = "🤖 AI Help", color = colors.aiPrimary, level = "Beginner" },
		}
	elseif self.level == "Intermediate" then
		tabs = {
			{ name = "💎 Vault", color = colors.accent, level = "Intermediate" },
			{ name = "🧰 Toolbox", color = colors.panelLight, level = "Intermediate" },
			{ name = "🎨 Modeler", color = colors.modelerPrimary, level = "Intermediate" },
			{ name = "🎬 Animator", color = colors.animatorPrimary, level = "Intermediate" },
			{ name = "🏔️ Terrain", color = colors.terrainPrimary, level = "Intermediate" },
			{ name = "📜 Script", color = colors.scriptPrimary, level = "Intermediate" },
			{ name = "🤖 AI", color = colors.aiPrimary, level = "Intermediate" },
		}
	else -- Advanced/Pro
		tabs = {
			{ name = "💎 Vault", color = colors.accent, level = "Advanced" },
			{ name = "🧰 Toolbox", color = colors.panelLight, level = "Advanced" },
			{ name = "🎨 Engineer", color = colors.modelerPrimary, level = "Advanced" },
			{ name = "🎬 Motion", color = colors.animatorPrimary, level = "Advanced" },
			{ name = "🏔️ World", color = colors.terrainPrimary, level = "Advanced" },
			{ name = "📜 Code Pro", color = colors.scriptPrimary, level = "Advanced" },
			{ name = "🤖 ARKHER AI", color = colors.aiPrimary, level = "Advanced" },
			{ name = "📁 Project", color = colors.panelLight, level = "Advanced" },
			{ name = "📊 Stats", color = colors.panelLight, level = "Pro" },
		}
	end

	local headerScroll = Instance.new("ScrollingFrame")
	headerScroll.Name = "HeaderScroll"
	headerScroll.Size = UDim2.new(1, -10, 1, 0)
	headerScroll.Position = UDim2.new(0, 5, 0, 0)
	headerScroll.BackgroundTransparency = 1
	headerScroll.ScrollBarThickness = 0
	headerScroll.CanvasSize = UDim2.new(0, #tabs*115, 0, 0)
	headerScroll.Parent = header

	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	headerLayout.Padding = UDim.new(0, 5)
	headerLayout.Parent = headerScroll

	for i, tab in tabs do
		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = "Tab_" .. tab.name
		tabBtn.Size = UDim2.new(0, 105, 1, -8)
		tabBtn.Position = UDim2.new(0, 0, 0, 4)
		tabBtn.BackgroundColor3 = i == 1 and tab.color or colors.panel
		tabBtn.Text = tab.name
		tabBtn.TextColor3 = i == 1 and Color3.new(1,1,1) or colors.text
		tabBtn.TextSize = self.level == "Beginner" and 11 or 10
		tabBtn.Font = Enum.Font.GothamBold
		tabBtn.LayoutOrder = i
		tabBtn.Parent = headerScroll

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 6)
		tabCorner.Parent = tabBtn

		if self.level == "Beginner" then
			tabBtn:SetAttribute("Tooltip", "Click to open " .. tab.name)
		end
	end

	-- Grid
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "AssetGrid"
	grid.Size = UDim2.new(1, -20, 1, -46)
	grid.Position = UDim2.new(0, 10, 0, 41)
	grid.BackgroundTransparency = 1
	grid.ScrollBarThickness = 4
	grid.CanvasSize = UDim2.new(0, 0, 0, 0)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = drawer

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, self.level == "Beginner" and 100 or 80, 0, self.level == "Beginner" and 100 or 80)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.Parent = grid

	return drawer
end

function ShellV2:CreateViewportV2(): Frame
	local colors = self.themeSystem:GetColors()
	local adaptiveConfig = self.adaptive:GetLayoutConfig()

	local viewport = Instance.new("Frame")
	viewport.Name = "ViewportV2"
	viewport.Size = UDim2.new(1, -adaptiveConfig.sidePanelWidth*2 - 60, 1, -adaptiveConfig.topBarHeight - adaptiveConfig.contentDrawerHeight - 30)
	viewport.Position = UDim2.new(0, adaptiveConfig.sidePanelWidth + 10, 0, adaptiveConfig.topBarHeight + 10)
	viewport.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	viewport.BorderSizePixel = 0
	viewport.ClipsDescendants = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = viewport

	-- Viewport label
	local label = Instance.new("TextLabel")
	label.Name = "ViewportLabel"
	label.Size = UDim2.new(0, 350, 0, 22)
	label.Position = UDim2.new(0, 10, 0, 10)
	label.BackgroundColor3 = Color3.fromRGB(0,0,0)
	label.BackgroundTransparency = 0.5
	label.Text = self.level == "Beginner" and "  🎮 My Game - Click to play!" or "  Perspective - Realistic [ANG ON] - V2 Polished"
	label.TextColor3 = colors.textDim
	label.TextSize = 11
	label.Font = Enum.Font.Code
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = viewport

	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 4)
	labelCorner.Parent = label

	-- Gizmo toolbar
	local gizmoBar = Instance.new("Frame")
	gizmoBar.Name = "GizmoBar"
	gizmoBar.Size = UDim2.new(0, self.level == "Beginner" and 100 or 160, 0, 32)
	gizmoBar.Position = UDim2.new(0, 10, 0, 40)
	gizmoBar.BackgroundColor3 = colors.panel
	gizmoBar.BackgroundTransparency = 0.2
	gizmoBar.Parent = viewport

	local gizmoCorner = Instance.new("UICorner")
	gizmoCorner.CornerRadius = UDim.new(0, 8)
	gizmoCorner.Parent = gizmoBar

	local gizmos = self.level == "Beginner" and {"✋ Move", "🔄 Rotate"} or {"W", "E", "R", "T"}
	for i, gizmo in gizmos do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, self.level == "Beginner" and 48 or 36, 0, 28)
		btn.Position = UDim2.new(0, (i-1)*(self.level == "Beginner" and 50 or 38) + 2, 0, 2)
		btn.BackgroundColor3 = colors.panelLight
		btn.Text = gizmo
		btn.TextColor3 = colors.text
		btn.TextSize = self.level == "Beginner" and 10 or 12
		btn.Font = Enum.Font.GothamBold
		btn.Parent = gizmoBar

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn
	end

	-- Beginner overlay help
	if self.level == "Beginner" then
		local helpOverlay = Instance.new("Frame")
		helpOverlay.Name = "BeginnerHelp"
		helpOverlay.Size = UDim2.new(0, 200, 0, 80)
		helpOverlay.Position = UDim2.new(1, -210, 0, 10)
		helpOverlay.BackgroundColor3 = colors.aiPrimary
		helpOverlay.BackgroundTransparency = 0.1
		helpOverlay.Parent = viewport

		local helpCorner = Instance.new("UICorner")
		helpCorner.CornerRadius = UDim.new(0, 8)
		helpCorner.Parent = helpOverlay

		local helpStroke = Instance.new("UIStroke")
		helpStroke.Color = colors.aiPrimary
		helpStroke.Thickness = 1
		helpStroke.Parent = helpOverlay

		local helpText = Instance.new("TextLabel")
		helpText.Size = UDim2.new(1, -10, 1, -10)
		helpText.Position = UDim2.new(0, 5, 0, 5)
		helpText.BackgroundTransparency = 1
		helpText.Text = "💡 Drag to look around\n👆 Click objects to select\n🤖 Ask AI for help!"
		helpText.TextColor3 = colors.text
		helpText.TextSize = 10
		helpText.Font = Enum.Font.Gotham
		helpText.TextXAlignment = Enum.TextXAlignment.Left
		helpText.TextYAlignment = Enum.TextYAlignment.Top
		helpText.TextWrapped = true
		helpText.Parent = helpOverlay
	end

	return viewport
end

function ShellV2:CreateStatusBar(): Frame
	local colors = self.themeSystem:GetColors()
	local adaptiveConfig = self.adaptive:GetLayoutConfig()

	if self.adaptive.isMobile then
		-- Mobile: no status bar, usa mobile toolbar
		return self.adaptive:CreateMobileToolbar(self.mainGui or Instance.new("ScreenGui"), colors)
	end

	local statusBar = Instance.new("Frame")
	statusBar.Name = "StatusBarV2"
	statusBar.Size = UDim2.new(1, 0, 0, 24)
	statusBar.Position = UDim2.new(0, 0, 1, -24)
	statusBar.BackgroundColor3 = colors.backgroundSecondary
	statusBar.BorderSizePixel = 0
	statusBar.ZIndex = 5

	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.border
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = statusBar

	-- Left: stats
	local leftLabel = Instance.new("TextLabel")
	leftLabel.Name = "LeftStats"
	leftLabel.Size = UDim2.new(0.4, 0, 1, 0)
	leftLabel.Position = UDim2.new(0, 10, 0, 0)
	leftLabel.BackgroundTransparency = 1
	leftLabel.Text = "  Entities: 0 | Chunks: 0 | 15GB: 0.0MB / 15GB | ANG: ON | Mecha: ON"
	leftLabel.TextColor3 = colors.textDim
	leftLabel.TextSize = 10
	leftLabel.Font = Enum.Font.Code
	leftLabel.TextXAlignment = Enum.TextXAlignment.Left
	leftLabel.Parent = statusBar

	-- Center: hints
	local centerLabel = Instance.new("TextLabel")
	centerLabel.Name = "Hints"
	centerLabel.Size = UDim2.new(0.3, 0, 1, 0)
	centerLabel.Position = UDim2.new(0.4, 0, 0, 0)
	centerLabel.BackgroundTransparency = 1
	centerLabel.Text = self.level == "Beginner" and "💡 Press F1 for help" or "⌘K: Commands | F1: Help | Ctrl+S: Save"
	centerLabel.TextColor3 = colors.textDim
	centerLabel.TextSize = 10
	centerLabel.Font = Enum.Font.Gotham
	centerLabel.Parent = statusBar

	-- Right: device + level + AI status
	local rightLabel = Instance.new("TextLabel")
	rightLabel.Name = "RightStatus"
	rightLabel.Size = UDim2.new(0.3, -10, 1, 0)
	rightLabel.Position = UDim2.new(0.7, 0, 0, 0)
	rightLabel.BackgroundTransparency = 1
	rightLabel.Text = string.format("📱 %s | %s | 🤖 AI: Ready v1", self.adaptive.device, self.level)
	rightLabel.TextColor3 = colors.textDim
	rightLabel.TextSize = 10
	rightLabel.Font = Enum.Font.Code
	rightLabel.TextXAlignment = Enum.TextXAlignment.Right
	rightLabel.Parent = statusBar

	return statusBar
end

function ShellV2:BuildFullUIV2(parent: Instance, level: UserLevel?): { [string]: Frame }
	self.level = level or self.level
	self.mainGui = parent :: ScreenGui

	local topBar = self:CreateTopBarV2()
	topBar.Parent = parent

	local outliner = self:CreateOutlinerV2()
	outliner.Parent = parent

	local details = self:CreateDetailsV2()
	details.Parent = parent

	local contentDrawer = self:CreateContentDrawerV2()
	contentDrawer.Parent = parent

	local viewport = self:CreateViewportV2()
	viewport.Parent = parent

	local statusBar = self:CreateStatusBar()
	statusBar.Parent = parent

	-- Mobile specifics
	local mobileToolbar: Frame? = nil
	local bottomSheet: Frame? = nil
	if self.adaptive.isMobile then
		mobileToolbar = self.adaptive:CreateMobileToolbar(parent :: ScreenGui, self.themeSystem:GetColors())
		bottomSheet = self.adaptive:CreateBottomSheet(parent :: ScreenGui, self.themeSystem:GetColors())
	end

	self.topBar = topBar
	self.outliner = outliner
	self.details = details
	self.contentDrawer = contentDrawer
	self.viewport = viewport
	self.statusBar = statusBar
	self.mobileToolbar = mobileToolbar
	self.bottomSheet = bottomSheet

	-- Apply adaptive layout
	self.adaptive:ApplyToUI({
		topBar = topBar,
		outliner = outliner,
		details = details,
		contentDrawer = contentDrawer,
		viewport = viewport,
	})

	print("[Arkher ShellV2] Built Polished UI - Level:", self.level, "Device:", self.adaptive.device, "Theme:", self.themeSystem.currentTheme)

	return {
		topBar = topBar,
		outliner = outliner,
		details = details,
		contentDrawer = contentDrawer,
		viewport = viewport,
		statusBar = statusBar,
		mobileToolbar = mobileToolbar,
		bottomSheet = bottomSheet,
	}
end

function ShellV2:SetLevel(level: UserLevel)
	self.level = level
	self.themeSystem:SetLevel(level)
	print("[Arkher ShellV2] Level ->", level)
end

function ShellV2:GetStats()
	return {
		level = self.level,
		device = self.adaptive.device,
		theme = self.themeSystem.currentTheme,
		isMobile = self.adaptive.isMobile,
		message = "ShellV2 - Polimento Total - Beginner/Intermediate/Advanced/Pro + Mobile A01 até 8K + Console + VR",
	}
end

return ShellV2

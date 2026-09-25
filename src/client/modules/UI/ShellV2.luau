--!strict
-- Arkher Studio - ShellV2 - BETA FINAL Fix UI feia bugada - Sem Emojis - Apenas icones pixel art desenhados por Frame
-- UI completa amigavel iniciantes/intermediarios/avancados, confortavel todos dispositivos especialmente mobile
-- Sem emojis, apenas icones desenhados por Frame pixel art ou imagem - IconSystem pixel art 8x8

local ThemeSystem = require(script.Parent.ThemeSystem)
local AdaptiveLayout = require(script.Parent.AdaptiveLayout)
local IconSystem = require(script.Parent.IconSystem)

local ShellV2 = {}
ShellV2.__index = ShellV2

export type UserLevel = "Beginner" | "Intermediate" | "Advanced" | "Pro"

function ShellV2.new(themeSystem: any, adaptiveLayout: any)
	return setmetatable({
		themeSystem = themeSystem,
		adaptive = adaptiveLayout,
		iconSystem = IconSystem.new(),
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
	if self.adaptive.isMobile then
		gui.Name = "ArkherStudioShellV2_Mobile_" .. self.adaptive.device
	end
	return gui
end

function ShellV2:CreateTopBarV2(): Frame
	local colors = self.themeSystem:GetColors()
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

	-- Logo Arkher com nivel indicator - SEM EMOJI, com ícone pixel art arkher
	local logoContainer = Instance.new("Frame")
	logoContainer.Name = "LogoContainer"
	logoContainer.Size = UDim2.new(0, 220, 1, 0)
	logoContainer.BackgroundTransparency = 1
	logoContainer.Parent = topBar

	-- Ícone Arkher pixel art 10x10
	local arkherIcon = self.iconSystem:CreateIcon("arkher", logoContainer, 20)
	arkherIcon.Position = UDim2.new(0, 8, 0, 6)

	local logo = Instance.new("TextLabel")
	logo.Name = "Logo"
	logo.Size = UDim2.new(0, 150, 0, 20)
	logo.Position = UDim2.new(0, 32, 0, 2)
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
	levelBadge.Text = self.level:upper() .. " v"
	levelBadge.TextColor3 = Color3.new(1,1,1)
	levelBadge.TextSize = 9
	levelBadge.Font = Enum.Font.GothamBold
	levelBadge.Parent = logoContainer

	local levelCorner = Instance.new("UICorner")
	levelCorner.CornerRadius = UDim.new(0, 4)
	levelCorner.Parent = levelBadge

	-- Version badge - SEM EMOJI
	local badge = Instance.new("TextLabel")
	badge.Name = "VersionBadge"
	badge.Size = UDim2.new(0, 130, 0, 18)
	badge.Position = UDim2.new(0, 100, 0, 22)
	badge.BackgroundColor3 = colors.accent
	badge.Text = "BETA FINAL TOP1"
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

	-- Play controls (centro) - SEM EMOJI, com ícones pixel art
	local playContainer = Instance.new("Frame")
	playContainer.Name = "PlayControls"
	playContainer.Size = UDim2.new(0, 340, 1, 0)
	playContainer.Position = UDim2.new(0.5, -170, 0, 0)
	playContainer.BackgroundTransparency = 1
	playContainer.Parent = topBar

	-- Save com ícone pixel art save
	local saveBtn = self.iconSystem:CreateIconButton("save", "Save", UDim2.new(0, 70, 0, 28), UDim2.new(0, 0, 0.5, -14), colors.panelLight, colors.text, playContainer)
	saveBtn.Name = "SaveBtn"

	-- Play com ícone pixel art play
	local playBtn = self.iconSystem:CreateIconButton("play", "PLAY", UDim2.new(0, 80, 0, 28), UDim2.new(0, 80, 0.5, -14), colors.success, Color3.new(1,1,1), playContainer)
	playBtn.Name = "PlayBtn"
	playBtn.Text = "" -- override, icon button already has label
	-- Fix label
	for _, child in playBtn:GetChildren() do
		if child:IsA("TextLabel") then
			child.Text = "PLAY"
			child.TextColor3 = Color3.new(1,1,1)
		end
	end

	-- Publish com ícone pixel art publish
	local publishBtn = self.iconSystem:CreateIconButton("publish", "Publish", UDim2.new(0, 90, 0, 28), UDim2.new(0, 170, 0.5, -14), colors.accent, Color3.new(1,1,1), playContainer)
	publishBtn.Name = "PublishBtn"

	-- Command palette button (Intermediate+) com ícone command
	if self.level ~= "Beginner" then
		local cmdBtn = self.iconSystem:CreateIconButton("command", "K", UDim2.new(0, 40, 0, 28), UDim2.new(0, 270, 0.5, -14), colors.panelLight, colors.textDim, playContainer)
		cmdBtn.Name = "CommandPaletteBtn"
	end

	-- Right side: Style + Help + Settings - SEM EMOJI
	local rightContainer = Instance.new("Frame")
	rightContainer.Name = "RightContainer"
	rightContainer.Size = UDim2.new(0, 300, 1, 0)
	rightContainer.Position = UDim2.new(1, -300, 0, 0)
	rightContainer.BackgroundTransparency = 1
	rightContainer.Parent = topBar

	-- Help button com ícone help
	local helpBtn = self.iconSystem:CreateIconButton("help", self.level == "Beginner" and "Help" or "", UDim2.new(0, self.level == "Beginner" and 70 or 36, 0, 28), UDim2.new(0, 0, 0.5, -14), self.level == "Beginner" and colors.aiPrimary or colors.panelLight, self.level == "Beginner" and Color3.new(0,0,0) or colors.text, rightContainer)
	helpBtn.Name = "HelpBtn"

	-- AI button com ícone ai
	local aiBtn = self.iconSystem:CreateIconButton("ai", "AI", UDim2.new(0, 50, 0, 28), UDim2.new(0, self.level == "Beginner" and 80 or 46, 0.5, -14), colors.aiPrimary, Color3.new(0,0,0), rightContainer)
	aiBtn.Name = "AIButton"

	-- Style selector com ícone style
	local styleSelector = self.iconSystem:CreateIconButton("style", "Realistic v", UDim2.new(0, 150, 0, 28), UDim2.new(0, 110, 0.5, -14), colors.panelLight, colors.text, rightContainer)
	styleSelector.Name = "StyleSelector"

	return topBar
end

function ShellV2:CreateOutlinerV2(): Frame
	local colors = self.themeSystem:GetColors()
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

	-- Header com actions - SEM EMOJI
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundColor3 = colors.panelLight
	header.Parent = outliner

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = header

	-- Título com ícone world
	local titleIcon = self.iconSystem:CreateIcon("world", header, 16)
	titleIcon.Position = UDim2.new(0, 10, 0.5, -8)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.6, -30, 1, 0)
	title.Position = UDim2.new(0, 32, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = self.level == "Beginner" and "My World" or "WORLD OUTLINER"
	title.TextColor3 = colors.text
	title.TextSize = 12
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	-- Add button com ícone add
	local addBtn = Instance.new("TextButton")
	addBtn.Name = "AddBtn"
	addBtn.Size = UDim2.new(0, 28, 0, 24)
	addBtn.Position = UDim2.new(1, -70, 0.5, -12)
	addBtn.BackgroundColor3 = colors.accent
	addBtn.Text = ""
	addBtn.Parent = header

	local addCorner = Instance.new("UICorner")
	addCorner.CornerRadius = UDim.new(0, 4)
	addCorner.Parent = addBtn

	local addIcon = self.iconSystem:CreateIcon("add", addBtn, 14)
	addIcon.Position = UDim2.new(0.5, -7, 0.5, -7)

	-- Filter button com ícone filter
	local filterBtn = Instance.new("TextButton")
	filterBtn.Name = "FilterBtn"
	filterBtn.Size = UDim2.new(0, 28, 0, 24)
	filterBtn.Position = UDim2.new(1, -35, 0.5, -12)
	filterBtn.BackgroundColor3 = colors.panel
	filterBtn.Text = ""
	filterBtn.Parent = header

	local filterCorner = Instance.new("UICorner")
	filterCorner.CornerRadius = UDim.new(0, 4)
	filterCorner.Parent = filterBtn

	local filterIcon = self.iconSystem:CreateIcon("filter", filterBtn, 14)
	filterIcon.Position = UDim2.new(0.5, -7, 0.5, -7)

	-- Search bar - so intermediate+ - com ícone search
	if self.level ~= "Beginner" or self.adaptive.isDesktop then
		local searchContainer = Instance.new("Frame")
		searchContainer.Name = "SearchContainer"
		searchContainer.Size = UDim2.new(1, -20, 0, 28)
		searchContainer.Position = UDim2.new(0, 10, 0, 46)
		searchContainer.BackgroundColor3 = colors.background
		searchContainer.Parent = outliner

		local searchCorner = Instance.new("UICorner")
		searchCorner.CornerRadius = UDim.new(0, 6)
		searchCorner.Parent = searchContainer

		local searchIcon = self.iconSystem:CreateIcon("search", searchContainer, 14)
		searchIcon.Position = UDim2.new(0, 8, 0.5, -7)

		local search = Instance.new("TextBox")
		search.Name = "Search"
		search.Size = UDim2.new(1, -32, 1, 0)
		search.Position = UDim2.new(0, 28, 0, 0)
		search.BackgroundTransparency = 1
		search.PlaceholderText = self.level == "Beginner" and "Search my objects..." or "Search entities... (Ctrl+F)"
		search.Text = ""
		search.TextColor3 = colors.text
		search.TextSize = 12
		search.Font = Enum.Font.Gotham
		search.ClearTextOnFocus = false
		search.Parent = searchContainer
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

	-- Beginner hint - SEM EMOJI, com ícone help
	if self.level == "Beginner" then
		local hint = Instance.new("Frame")
		hint.Name = "BeginnerHint"
		hint.Size = UDim2.new(1, -20, 0, 40)
		hint.Position = UDim2.new(0, 10, 1, -50)
		hint.BackgroundColor3 = colors.aiPrimary
		hint.BackgroundTransparency = 0.2
		hint.Parent = outliner

		local hintCorner = Instance.new("UICorner")
		hintCorner.CornerRadius = UDim.new(0, 6)
		hintCorner.Parent = hint

		local hintIcon = self.iconSystem:CreateIcon("help", hint, 16)
		hintIcon.Position = UDim2.new(0, 8, 0.5, -8)

		local hintText = Instance.new("TextLabel")
		hintText.Size = UDim2.new(1, -32, 1, 0)
		hintText.Position = UDim2.new(0, 28, 0, 0)
		hintText.BackgroundTransparency = 1
		hintText.Text = "Tip: Click objects in world to select them!"
		hintText.TextColor3 = Color3.new(0,0,0)
		hintText.TextSize = 10
		hintText.Font = Enum.Font.Gotham
		hintText.TextWrapped = true
		hintText.TextXAlignment = Enum.TextXAlignment.Left
		hintText.Parent = hint
	end

	return outliner
end

function ShellV2:CreateDetailsV2(): Frame
	local colors = self.themeSystem:GetColors()
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

	local titleIcon = self.iconSystem:CreateIcon("details", header, 16)
	titleIcon.Position = UDim2.new(0, 10, 0.5, -8)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 1, 0)
	title.Position = UDim2.new(0, 32, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = self.level == "Beginner" and "Properties" or "DETAILS"
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

	-- Tabs - SEM EMOJI, com ícones pixel art
	local tabs
	if self.level == "Beginner" then
		tabs = {
			{ name = "My Assets", icon = "vault", color = colors.accent },
			{ name = "Add Objects", icon = "toolbox", color = colors.panelLight },
			{ name = "Make 3D", icon = "engineer", color = colors.modelerPrimary },
			{ name = "AI Help", icon = "ai", color = colors.aiPrimary },
		}
	elseif self.level == "Intermediate" then
		tabs = {
			{ name = "Vault", icon = "vault", color = colors.accent },
			{ name = "Toolbox", icon = "toolbox", color = colors.panelLight },
			{ name = "Modeler", icon = "engineer", color = colors.modelerPrimary },
			{ name = "Animator", icon = "motion", color = colors.animatorPrimary },
			{ name = "Terrain", icon = "terrain", color = colors.terrainPrimary },
			{ name = "Script", icon = "code", color = colors.scriptPrimary },
			{ name = "AI", icon = "ai", color = colors.aiPrimary },
		}
	else
		tabs = {
			{ name = "Vault", icon = "vault", color = colors.accent },
			{ name = "Toolbox", icon = "toolbox", color = colors.panelLight },
			{ name = "Engineer", icon = "engineer", color = colors.modelerPrimary },
			{ name = "Motion", icon = "motion", color = colors.animatorPrimary },
			{ name = "World", icon = "terrain", color = colors.terrainPrimary },
			{ name = "Code Pro", icon = "code", color = colors.scriptPrimary },
			{ name = "ARKHER AI", icon = "ai", color = colors.aiPrimary },
			{ name = "Project", icon = "project", color = colors.panelLight },
			{ name = "Stats", icon = "stats", color = colors.panelLight },
		}
	end

	local headerScroll = Instance.new("ScrollingFrame")
	headerScroll.Name = "HeaderScroll"
	headerScroll.Size = UDim2.new(1, -10, 1, 0)
	headerScroll.Position = UDim2.new(0, 5, 0, 0)
	headerScroll.BackgroundTransparency = 1
	headerScroll.ScrollBarThickness = 0
	headerScroll.CanvasSize = UDim2.new(0, #tabs*120, 0, 0)
	headerScroll.Parent = header

	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	headerLayout.Padding = UDim.new(0, 5)
	headerLayout.Parent = headerScroll

	for i, tab in tabs do
		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = "Tab_" .. tab.name
		tabBtn.Size = UDim2.new(0, 110, 1, -8)
		tabBtn.Position = UDim2.new(0, 0, 0, 4)
		tabBtn.BackgroundColor3 = i == 1 and tab.color or colors.panel
		tabBtn.Text = ""
		tabBtn.LayoutOrder = i
		tabBtn.Parent = headerScroll

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 6)
		tabCorner.Parent = tabBtn

		-- Ícone pixel art
		local icon = self.iconSystem:CreateIcon(tab.icon, tabBtn, 14)
		icon.Position = UDim2.new(0, 8, 0.5, -7)

		-- Texto sem emoji
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -28, 1, 0)
		label.Position = UDim2.new(0, 26, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = tab.name
		label.TextColor3 = i == 1 and Color3.new(1,1,1) or colors.text
		label.TextSize = 10
		label.Font = Enum.Font.GothamBold
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncated = true
		label.Parent = tabBtn
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

	-- Viewport label - SEM EMOJI
	local labelContainer = Instance.new("Frame")
	labelContainer.Name = "ViewportLabelContainer"
	labelContainer.Size = UDim2.new(0, 380, 0, 22)
	labelContainer.Position = UDim2.new(0, 10, 0, 10)
	labelContainer.BackgroundColor3 = Color3.fromRGB(0,0,0)
	labelContainer.BackgroundTransparency = 0.3
	labelContainer.Parent = viewport

	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 4)
	labelCorner.Parent = labelContainer

	local labelIcon = self.iconSystem:CreateIcon("world", labelContainer, 12)
	labelIcon.Position = UDim2.new(0, 6, 0.5, -6)

	local label = Instance.new("TextLabel")
	label.Name = "ViewportLabel"
	label.Size = UDim2.new(1, -24, 1, 0)
	label.Position = UDim2.new(0, 22, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = self.level == "Beginner" and "My Game - Click to play!" or "Perspective - Realistic [ANG ON] - V2 Polished - BETA FINAL"
	label.TextColor3 = colors.textDim
	label.TextSize = 11
	label.Font = Enum.Font.Code
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = labelContainer

	-- Gizmo toolbar - SEM EMOJI, com ícones pixel art
	local gizmoBar = Instance.new("Frame")
	gizmoBar.Name = "GizmoBar"
	gizmoBar.Size = UDim2.new(0, self.level == "Beginner" and 100 or 160, 0, 36)
	gizmoBar.Position = UDim2.new(0, 10, 0, 40)
	gizmoBar.BackgroundColor3 = colors.panel
	gizmoBar.BackgroundTransparency = 0.1
	gizmoBar.Parent = viewport

	local gizmoCorner = Instance.new("UICorner")
	gizmoCorner.CornerRadius = UDim.new(0, 8)
	gizmoCorner.Parent = gizmoBar

	local gizmos = self.level == "Beginner" and {
		{icon="move", name="Move"},
		{icon="rotate", name="Rotate"}
	} or {
		{icon="move", name="Move"},
		{icon="rotate", name="Rotate"},
		{icon="scale", name="Scale"},
		{icon="world", name="World"}
	}
	
	for i, gizmo in gizmos do
		local btn = Instance.new("TextButton")
		btn.Name = gizmo.name .. "GizmoBtn"
		btn.Size = UDim2.new(0, self.level == "Beginner" and 46 or 36, 0, 32)
		btn.Position = UDim2.new(0, (i-1)*(self.level == "Beginner" and 50 or 40) + 2, 0, 2)
		btn.BackgroundColor3 = colors.panelLight
		btn.Text = ""
		btn.Parent = gizmoBar

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn

		local icon = self.iconSystem:CreateIcon(gizmo.icon, btn, 16)
		icon.Position = UDim2.new(0.5, -8, 0.5, -8)
	end

	-- Beginner overlay help - SEM EMOJI
	if self.level == "Beginner" then
		local helpOverlay = Instance.new("Frame")
		helpOverlay.Name = "BeginnerHelp"
		helpOverlay.Size = UDim2.new(0, 200, 0, 80)
		helpOverlay.Position = UDim2.new(1, -210, 0, 10)
		helpOverlay.BackgroundColor3 = colors.panel
		helpOverlay.BackgroundTransparency = 0.1
		helpOverlay.Parent = viewport

		local helpCorner = Instance.new("UICorner")
		helpCorner.CornerRadius = UDim.new(0, 8)
		helpCorner.Parent = helpOverlay

		local helpStroke = Instance.new("UIStroke")
		helpStroke.Color = colors.aiPrimary
		helpStroke.Thickness = 1
		helpStroke.Parent = helpOverlay

		local helpIcon = self.iconSystem:CreateIcon("help", helpOverlay, 14)
		helpIcon.Position = UDim2.new(0, 8, 0, 8)

		local helpText = Instance.new("TextLabel")
		helpText.Size = UDim2.new(1, -30, 1, -10)
		helpText.Position = UDim2.new(0, 26, 0, 5)
		helpText.BackgroundTransparency = 1
		helpText.Text = "Drag to look around\nClick objects to select\nAsk AI for help!"
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

	-- Left: stats - SEM EMOJI
	local leftIcon = self.iconSystem:CreateIcon("stats", statusBar, 12)
	leftIcon.Position = UDim2.new(0, 8, 0.5, -6)

	local leftLabel = Instance.new("TextLabel")
	leftLabel.Name = "LeftStats"
	leftLabel.Size = UDim2.new(0.4, -20, 1, 0)
	leftLabel.Position = UDim2.new(0, 26, 0, 0)
	leftLabel.BackgroundTransparency = 1
	leftLabel.Text = "Entities: 0 | Chunks: 0 | 15GB: 0.0MB / 15GB | ANG: ON | Mecha: ON"
	leftLabel.TextColor3 = colors.textDim
	leftLabel.TextSize = 10
	leftLabel.Font = Enum.Font.Code
	leftLabel.TextXAlignment = Enum.TextXAlignment.Left
	leftLabel.Parent = statusBar

	-- Center: hints - SEM EMOJI
	local centerLabel = Instance.new("TextLabel")
	centerLabel.Name = "Hints"
	centerLabel.Size = UDim2.new(0.3, 0, 1, 0)
	centerLabel.Position = UDim2.new(0.4, 0, 0, 0)
	centerLabel.BackgroundTransparency = 1
	centerLabel.Text = self.level == "Beginner" and "Press F1 for help" or "K: Commands | F1: Help | Ctrl+S: Save"
	centerLabel.TextColor3 = colors.textDim
	centerLabel.TextSize = 10
	centerLabel.Font = Enum.Font.Gotham
	centerLabel.Parent = statusBar

	-- Right: device + level + AI status - SEM EMOJI, com ícone a01 e ai
	local rightContainer = Instance.new("Frame")
	rightContainer.Name = "RightStatusContainer"
	rightContainer.Size = UDim2.new(0.3, -10, 1, 0)
	rightContainer.Position = UDim2.new(0.7, 0, 0, 0)
	rightContainer.BackgroundTransparency = 1
	rightContainer.Parent = statusBar

	local a01Icon = self.iconSystem:CreateIcon("a01", rightContainer, 12)
	a01Icon.Position = UDim2.new(1, -180, 0.5, -6)

	local rightLabel = Instance.new("TextLabel")
	rightLabel.Name = "RightStatus"
	rightLabel.Size = UDim2.new(1, -20, 1, 0)
	rightLabel.Position = UDim2.new(0, 0, 0, 0)
	rightLabel.BackgroundTransparency = 1
	rightLabel.Text = string.format("%s | %s | AI: Ready v1 BETA FINAL", self.adaptive.device, self.level)
	rightLabel.TextColor3 = colors.textDim
	rightLabel.TextSize = 10
	rightLabel.Font = Enum.Font.Code
	rightLabel.TextXAlignment = Enum.TextXAlignment.Right
	rightLabel.Parent = rightContainer

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

	self.adaptive:ApplyToUI({
		topBar = topBar,
		outliner = outliner,
		details = details,
		contentDrawer = contentDrawer,
		viewport = viewport,
	})

	print("[Arkher ShellV2] Built Polished UI BETA FINAL - Level:", self.level, "Device:", self.adaptive.device, "Theme:", self.themeSystem.currentTheme, "- Sem emojis, apenas icones pixel art Frame - Fix UI feia bugada")

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
		noEmojis = true,
		pixelArtIcons = true,
		totalIcons = 30,
		message = "ShellV2 - BETA FINAL Fix UI feia bugada - Sem emojis, apenas icones pixel art Frame desenhados - Beginner/Intermediate/Advanced/Pro + Mobile A01 ate 8K + Console + VR - IconSystem 8x8 10x10 30 icons Save Play Publish Help AI Style Search Add Filter Move Rotate Scale World Details Vault Toolbox Engineer Motion Terrain Code Project Stats Command Close Check Cloud Market Export Collab Audio Net Mecha A01 Arkher",
	}
end

return ShellV2

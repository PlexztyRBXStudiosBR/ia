--!strict
-- Arkher Studio - UI Shell - Inspirado na Unreal 5, não no Roblox Studio
-- Dark theme, dockable, moderno. Nunca copiar, inspirar.

local Shell = {}

-- Cores Unreal 5 inspired
Shell.Colors = {
	background = Color3.fromRGB(20, 20, 20),
	panel = Color3.fromRGB(35, 35, 35),
	panelLight = Color3.fromRGB(45, 45, 45),
	border = Color3.fromRGB(55, 55, 55),
	accent = Color3.fromRGB(0, 120, 215), -- Unreal blue
	accentHover = Color3.fromRGB(0, 140, 255),
	text = Color3.fromRGB(230, 230, 230),
	textDim = Color3.fromRGB(150, 150, 150),
	success = Color3.fromRGB(0, 200, 100),
	warning = Color3.fromRGB(255, 180, 0),
	error = Color3.fromRGB(255, 60, 60),
}

Shell.Fonts = {
	regular = Font.fromEnum(Enum.Font.Gotham),
	bold = Font.fromEnum(Enum.Font.GothamBold),
	mono = Font.fromEnum(Enum.Font.Code),
}

function Shell.CreateMainScreenGui(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "ArkherStudioShell"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10

	-- Detecta plataforma para adaptar
	local isMobile = false
	pcall(function()
		local UIS = game:GetService("UserInputService")
		isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
	end)

	if isMobile then
		gui.Name = "ArkherStudioShell_Mobile"
	end

	return gui
end

function Shell.CreatePanel(name: string, size: UDim2, position: UDim2): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = size
	panel.Position = position
	panel.BackgroundColor3 = Shell.Colors.panel
	panel.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Shell.Colors.border
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = panel

	return panel
end

function Shell.CreateTopBar(): Frame
	-- TopBar estilo Unreal 5: File Edit Window Tools Build etc + Play buttons
	local topBar = Shell.CreatePanel("TopBar", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0))
	topBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	topBar.ZIndex = 10

	-- Logo Arkher
	local logo = Instance.new("TextLabel")
	logo.Name = "Logo"
	logo.Size = UDim2.new(0, 150, 1, 0)
	logo.Position = UDim2.new(0, 10, 0, 0)
	logo.BackgroundTransparency = 1
	logo.Text = "ARKHER STUDIO"
	logo.TextColor3 = Shell.Colors.text
	logo.TextSize = 16
	logo.Font = Enum.Font.GothamBold
	logo.TextXAlignment = Enum.TextXAlignment.Left
	logo.Parent = topBar

	-- Version badge
	local badge = Instance.new("TextLabel")
	badge.Name = "VersionBadge"
	badge.Size = UDim2.new(0, 80, 0, 20)
	badge.Position = UDim2.new(0, 160, 0.5, -10)
	badge.BackgroundColor3 = Shell.Colors.accent
	badge.Text = "ALPHA 0.1"
	badge.TextColor3 = Color3.new(1,1,1)
	badge.TextSize = 10
	badge.Font = Enum.Font.GothamBold
	badge.Parent = topBar

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 4)
	badgeCorner.Parent = badge

	-- Play controls (centro)
	local playContainer = Instance.new("Frame")
	playContainer.Name = "PlayControls"
	playContainer.Size = UDim2.new(0, 280, 1, 0)
	playContainer.Position = UDim2.new(0.5, -140, 0, 0)
	playContainer.BackgroundTransparency = 1
	playContainer.Parent = topBar

	local saveBtn = Instance.new("TextButton")
	saveBtn.Name = "SaveBtn"
	saveBtn.Size = UDim2.new(0, 60, 0, 28)
	saveBtn.Position = UDim2.new(0, 0, 0.5, -14)
	saveBtn.BackgroundColor3 = Shell.Colors.panelLight
	saveBtn.Text = "💾 Save"
	saveBtn.TextColor3 = Shell.Colors.text
	saveBtn.TextSize = 11
	saveBtn.Font = Enum.Font.Gotham
	saveBtn.Parent = playContainer

	local saveCorner = Instance.new("UICorner")
	saveCorner.CornerRadius = UDim.new(0, 6)
	saveCorner.Parent = saveBtn

	local playBtn = Instance.new("TextButton")
	playBtn.Name = "PlayBtn"
	playBtn.Size = UDim2.new(0, 80, 0, 28)
	playBtn.Position = UDim2.new(0, 70, 0.5, -14)
	playBtn.BackgroundColor3 = Shell.Colors.success
	playBtn.Text = "▶ PLAY"
	playBtn.TextColor3 = Color3.new(1,1,1)
	playBtn.TextSize = 12
	playBtn.Font = Enum.Font.GothamBold
	playBtn.Parent = playContainer

	local playCorner = Instance.new("UICorner")
	playCorner.CornerRadius = UDim.new(0, 6)
	playCorner.Parent = playBtn

	local publishBtn = Instance.new("TextButton")
	publishBtn.Name = "PublishBtn"
	publishBtn.Size = UDim2.new(0, 80, 0, 28)
	publishBtn.Position = UDim2.new(0, 160, 0.5, -14)
	publishBtn.BackgroundColor3 = Shell.Colors.accent
	publishBtn.Text = "🚀 Publish"
	publishBtn.TextColor3 = Color3.new(1,1,1)
	publishBtn.TextSize = 11
	publishBtn.Font = Enum.Font.GothamBold
	publishBtn.Parent = playContainer

	local publishCorner = Instance.new("UICorner")
	publishCorner.CornerRadius = UDim.new(0, 6)
	publishCorner.Parent = publishBtn

	-- Style selector (direita)
	local styleSelector = Instance.new("TextButton")
	styleSelector.Name = "StyleSelector"
	styleSelector.Size = UDim2.new(0, 150, 0, 28)
	styleSelector.Position = UDim2.new(1, -160, 0.5, -14)
	styleSelector.BackgroundColor3 = Shell.Colors.panelLight
	styleSelector.Text = "🎨 Realistic ▼"
	styleSelector.TextColor3 = Shell.Colors.text
	styleSelector.TextSize = 12
	styleSelector.Font = Enum.Font.Gotham
	styleSelector.Parent = topBar

	local styleCorner = Instance.new("UICorner")
	styleCorner.CornerRadius = UDim.new(0, 6)
	styleCorner.Parent = styleSelector

	return topBar
end

function Shell.CreateOutliner(): Frame
	-- Outliner = Explorer, mas estilo Unreal (World Outliner)
	local outliner = Shell.CreatePanel("Outliner", UDim2.new(0, 280, 1, -120), UDim2.new(0, 0, 0, 50))
	
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 30)
	header.BackgroundColor3 = Shell.Colors.panelLight
	header.Text = "  🌍 WORLD OUTLINER"
	header.TextColor3 = Shell.Colors.text
	header.TextSize = 12
	header.Font = Enum.Font.GothamBold
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = outliner

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 6)
	headerCorner.Parent = header

	-- Search bar
	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.Size = UDim2.new(1, -20, 0, 28)
	search.Position = UDim2.new(0, 10, 0, 40)
	search.BackgroundColor3 = Shell.Colors.background
	search.PlaceholderText = "🔍 Search entities..."
	search.Text = ""
	search.TextColor3 = Shell.Colors.text
	search.TextSize = 12
	search.Font = Enum.Font.Gotham
	search.ClearTextOnFocus = false
	search.Parent = outliner

	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = UDim.new(0, 4)
	searchCorner.Parent = search

	-- Scrolling list para entidades
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "EntityList"
	scroll.Size = UDim2.new(1, -20, 1, -80)
	scroll.Position = UDim2.new(0, 10, 0, 75)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = outliner

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = scroll

	return outliner
end

function Shell.CreateDetailsPanel(): Frame
	-- Details Panel = Properties, estilo Unreal
	local details = Shell.CreatePanel("Details", UDim2.new(0, 320, 1, -120), UDim2.new(1, -320, 0, 50))

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 30)
	header.BackgroundColor3 = Shell.Colors.panelLight
	header.Text = "  📋 DETAILS"
	header.TextColor3 = Shell.Colors.text
	header.TextSize = 12
	header.Font = Enum.Font.GothamBold
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = details

	-- Transform section
	local transformSection = Instance.new("Frame")
	transformSection.Name = "TransformSection"
	transformSection.Size = UDim2.new(1, -20, 0, 100)
	transformSection.Position = UDim2.new(0, 10, 0, 40)
	transformSection.BackgroundColor3 = Shell.Colors.background
	transformSection.Parent = details

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 4)
	tCorner.Parent = transformSection

	local tLabel = Instance.new("TextLabel")
	tLabel.Size = UDim2.new(1, 0, 0, 20)
	tLabel.BackgroundTransparency = 1
	tLabel.Text = "  Transform"
	tLabel.TextColor3 = Shell.Colors.text
	tLabel.TextSize = 11
	tLabel.Font = Enum.Font.GothamBold
	tLabel.TextXAlignment = Enum.TextXAlignment.Left
	tLabel.Parent = transformSection

	return details
end

function Shell.CreateContentDrawer(): Frame
	-- Content Drawer = Toolbox + Vault + Modeling + Script Pro + AI, estilo Unreal - Fase 3
	local drawer = Shell.CreatePanel("ContentDrawer", UDim2.new(1, -600, 0, 240), UDim2.new(0, 290, 1, -250))

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 30)
	header.BackgroundColor3 = Shell.Colors.panelLight
	header.Parent = drawer

	-- Tabs Fase 4: Vault + Toolbox + Modeler + Animator + Terrain + Script Pro + AI + Project
	local tabs = {
		{ name = "💎 Vault", color = Shell.Colors.accent },
		{ name = "🧰 Toolbox", color = Shell.Colors.panelLight },
		{ name = "🎨 Modeler", color = Color3.fromRGB(200, 100, 255) },
		{ name = "🎬 Animator", color = Color3.fromRGB(255, 100, 100) },
		{ name = "🏔️ Terrain", color = Color3.fromRGB(100, 200, 100) },
		{ name = "📜 Script Pro", color = Color3.fromRGB(55, 118, 171) },
		{ name = "🤖 AI Gen", color = Color3.fromRGB(255, 180, 0) },
		{ name = "📁 Project", color = Shell.Colors.panelLight },
	}

	local headerScroll = Instance.new("ScrollingFrame")
	headerScroll.Name = "HeaderScroll"
	headerScroll.Size = UDim2.new(1, 0, 1, 0)
	headerScroll.BackgroundTransparency = 1
	headerScroll.ScrollBarThickness = 0
	headerScroll.CanvasSize = UDim2.new(0, #tabs*110, 0, 0)
	headerScroll.Parent = header

	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	headerLayout.Padding = UDim.new(0, 5)
	headerLayout.Parent = headerScroll

	for i, tab in tabs do
		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = "Tab_" .. tab.name
		tabBtn.Size = UDim2.new(0, 100, 1, 0)
		tabBtn.BackgroundColor3 = i == 1 and tab.color or Shell.Colors.panelLight
		tabBtn.Text = tab.name
		tabBtn.TextColor3 = Shell.Colors.text
		tabBtn.TextSize = 10
		tabBtn.Font = Enum.Font.Gotham
		tabBtn.LayoutOrder = i
		tabBtn.Parent = headerScroll

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 4)
		tabCorner.Parent = tabBtn
	end

	-- Grid de assets (default)
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "AssetGrid"
	grid.Size = UDim2.new(1, -20, 1, -40)
	grid.Position = UDim2.new(0, 10, 0, 35)
	grid.BackgroundTransparency = 1
	grid.ScrollBarThickness = 4
	grid.CanvasSize = UDim2.new(0, 0, 0, 0)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = drawer

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 80, 0, 80)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.Parent = grid

	return drawer
end

function Shell.CreateViewport(): Frame
	-- Viewport central, onde o jogo é editado
	local viewport = Instance.new("Frame")
	viewport.Name = "Viewport"
	viewport.Size = UDim2.new(1, -620, 1, -260)
	viewport.Position = UDim2.new(0, 290, 0, 50)
	viewport.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	viewport.BorderSizePixel = 0
	viewport.ClipsDescendants = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = viewport

	-- Viewport label
	local label = Instance.new("TextLabel")
	label.Name = "ViewportLabel"
	label.Size = UDim2.new(0, 200, 0, 20)
	label.Position = UDim2.new(0, 10, 0, 10)
	label.BackgroundColor3 = Color3.fromRGB(0,0,0)
	label.BackgroundTransparency = 0.5
	label.Text = "  Perspective - Realistic [ANG ON]"
	label.TextColor3 = Shell.Colors.textDim
	label.TextSize = 10
	label.Font = Enum.Font.Code
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = viewport

	-- Gizmo toolbar (top left do viewport)
	local gizmoBar = Instance.new("Frame")
	gizmoBar.Name = "GizmoBar"
	gizmoBar.Size = UDim2.new(0, 120, 0, 30)
	gizmoBar.Position = UDim2.new(0, 10, 0, 40)
	gizmoBar.BackgroundColor3 = Shell.Colors.panel
	gizmoBar.Parent = viewport

	local gizmoCorner = Instance.new("UICorner")
	gizmoCorner.CornerRadius = UDim.new(0, 6)
	gizmoCorner.Parent = gizmoBar

	for i, gizmo in {"W", "E", "R", "T"} do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 28, 0, 28)
		btn.Position = UDim2.new(0, (i-1)*30 + 1, 0, 1)
		btn.BackgroundColor3 = Shell.Colors.panelLight
		btn.Text = gizmo
		btn.TextColor3 = Shell.Colors.text
		btn.TextSize = 12
		btn.Font = Enum.Font.GothamBold
		btn.Parent = gizmoBar
	end

	return viewport
end

function Shell.BuildFullUI(parent: Instance): { [string]: Frame }
	local topBar = Shell.CreateTopBar()
	topBar.Parent = parent

	local outliner = Shell.CreateOutliner()
	outliner.Parent = parent

	local details = Shell.CreateDetailsPanel()
	details.Parent = parent

	local contentDrawer = Shell.CreateContentDrawer()
	contentDrawer.Parent = parent

	local viewport = Shell.CreateViewport()
	viewport.Parent = parent

	print("[Arkher Shell] Built Unreal-inspired UI - Mobile & PC compatible")

	return {
		topBar = topBar,
		outliner = outliner,
		details = details,
		contentDrawer = contentDrawer,
		viewport = viewport,
	}
end

return Shell

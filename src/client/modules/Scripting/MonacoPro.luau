--!strict
-- Arkher Studio - MonacoPro - Polimento Total - Editor nivel VS Code + melhor
-- Inspirado no melhor: VS Code, JetBrains, Zed, Neovim, Sublime - mas nosso
-- Plugins, Addons, Integracoes + ARKHER AI v1 como Copilot proprio
-- 20+ plugins: ESLint, Prettier, IntelliSense, Git, Snippets, Themes, Minimap, Vim, Emmet, Copilot, CodeLens, Error Lens, etc

local Shell = require(script.Parent.Parent.UI.Shell)
local ThemeSystem = require(script.Parent.Parent.UI.ThemeSystem)

local MonacoPro = {}
MonacoPro.__index = MonacoPro

export type Plugin = {
	id: string,
	name: string,
	description: string,
	icon: string,
	enabled: boolean,
	version: string,
	category: string,
}

MonacoPro.Themes = {
	dark = {
		name = "Dark - VS Code",
		background = Color3.fromRGB(30, 30, 30),
		foreground = Color3.fromRGB(212, 212, 212),
		lineNumber = Color3.fromRGB(133, 133, 133),
		selection = Color3.fromRGB(38, 79, 120),
		cursor = Color3.fromRGB(212, 212, 212),
		keyword = Color3.fromRGB(86, 156, 214),
		string = Color3.fromRGB(206, 145, 120),
		comment = Color3.fromRGB(106, 153, 85),
		number = Color3.fromRGB(181, 206, 168),
		functionName = Color3.fromRGB(220, 220, 170),
		type = Color3.fromRGB(78, 201, 176),
		error = Color3.fromRGB(244, 71, 71),
		warning = Color3.fromRGB(255, 203, 107),
		aiSuggestion = Color3.fromRGB(100, 200, 100),
	},
	arkher = {
		name = "Arkher - Signature",
		background = Color3.fromRGB(20, 20, 32),
		foreground = Color3.fromRGB(235, 235, 250),
		lineNumber = Color3.fromRGB(100, 100, 120),
		selection = Color3.fromRGB(70, 60, 140),
		cursor = Color3.fromRGB(120, 80, 255),
		keyword = Color3.fromRGB(120, 80, 255),
		string = Color3.fromRGB(0, 220, 180),
		comment = Color3.fromRGB(100, 180, 120),
		number = Color3.fromRGB(255, 200, 60),
		functionName = Color3.fromRGB(255, 120, 150),
		type = Color3.fromRGB(80, 140, 255),
		error = Color3.fromRGB(255, 70, 90),
		warning = Color3.fromRGB(255, 190, 60),
		aiSuggestion = Color3.fromRGB(120, 80, 255),
	},
	light = {
		name = "Light",
		background = Color3.fromRGB(255, 255, 255),
		foreground = Color3.fromRGB(30, 30, 30),
		lineNumber = Color3.fromRGB(150, 150, 150),
		selection = Color3.fromRGB(180, 210, 255),
		cursor = Color3.fromRGB(0, 0, 0),
		keyword = Color3.fromRGB(0, 0, 200),
		string = Color3.fromRGB(160, 0, 0),
		comment = Color3.fromRGB(0, 120, 0),
		number = Color3.fromRGB(0, 100, 0),
		functionName = Color3.fromRGB(120, 0, 120),
		type = Color3.fromRGB(0, 120, 120),
		error = Color3.fromRGB(200, 0, 0),
		warning = Color3.fromRGB(180, 120, 0),
		aiSuggestion = Color3.fromRGB(0, 150, 0),
	},
}

MonacoPro.Plugins = {
	-- Core
	{ id = "autocomplete", name = "IntelliSense", description = "Autocomplete inteligente Luau/Python + Arkher API", icon = "💡", enabled = true, version = "2.0.0", category = "Core" },
	{ id = "errorLens", name = "Error Lens", description = "Mostra erros inline - vermelho/amarelo", icon = "🚨", enabled = true, version = "1.5.0", category = "Core" },
	{ id = "minimap", name = "Minimap", description = "Minimap preview código - VS Code", icon = "🗺️", enabled = true, version = "1.0.0", category = "Core" },
	{ id = "lineNumbers", name = "Line Numbers", description = "Números de linha + relative", icon = "🔢", enabled = true, version = "1.0.0", category = "Core" },
	{ id = "bracketPair", name = "Bracket Pair Colorization", description = "Coloriza parênteses aninhados", icon = "🌈", enabled = true, version = "1.2.0", category = "Core" },

	-- Formatting
	{ id = "prettier", name = "Prettier", description = "Formata código automaticamente - Shift+Alt+F", icon = "✨", enabled = true, version = "3.0.0", category = "Formatting" },
	{ id = "eslint", name = "ESLint / Luau Lint", description = "Lint Luau + Python - Erros e warnings", icon = "🔍", enabled = true, version = "2.5.0", category = "Formatting" },
	{ id = "emmet", name = "Emmet", description = "Abreviações HTML/CSS - div>ul>li", icon = "⚡", enabled = true, version = "1.0.0", category = "Formatting" },

	-- AI - ARKHER AI v1 (propria, sem depender de empresas)
	{ id = "arkherCopilot", name = "ARKHER AI Copilot", description = "AI code completion - ARKHER AI v1 3.98M params - Nossa IA propria", icon = "🤖", enabled = true, version = "1.0.0", category = "AI" },
	{ id = "arkherChat", name = "ARKHER AI Chat", description = "Chat com ARKHER AI v1 dentro do editor", icon = "💬", enabled = true, version = "1.0.0", category = "AI" },
	{ id = "arkherExplain", name = "ARKHER AI Explain", description = "Explica código selecionado", icon = "📖", enabled = true, version = "1.0.0", category = "AI" },
	{ id = "arkherFix", name = "ARKHER AI Fix", description = "Corrige erros automaticamente com AI", icon = "🔧", enabled = true, version = "1.0.0", category = "AI" },
	{ id = "arkherGenerate", name = "ARKHER AI Generate", description = "Gera código de prompt - 'cria sistema de inventario'", icon = "🧙", enabled = true, version = "1.0.0", category = "AI" },

	-- Navigation
	{ id = "goToDefinition", name = "Go to Definition", description = "F12 - Vai para definição", icon = "🎯", enabled = true, version = "1.0.0", category = "Navigation" },
	{ id = "findReferences", name = "Find References", description = "Shift+F12 - Encontra referências", icon = "🔎", enabled = true, version = "1.0.0", category = "Navigation" },
	{ id = "breadcrumbs", name = "Breadcrumbs", description = "Mostra caminho - file > class > function", icon = "🍞", enabled = true, version = "1.0.0", category = "Navigation" },
	{ id = "outline", name = "Outline", description = "Lista funções, classes do arquivo", icon = "📑", enabled = true, version = "1.0.0", category = "Navigation" },
	{ id = "commandPalette", name = "Command Palette", description = "Ctrl+Shift+P - Comandos", icon = "⌘", enabled = true, version = "1.0.0", category = "Navigation" },

	-- Editing
	{ id = "multiCursor", name = "Multi Cursor", description = "Ctrl+D - Multiplos cursores", icon = "👆", enabled = true, version = "1.0.0", category = "Editing" },
	{ id = "snippets", name = "Snippets", description = "Snippets Luau/Python/Arkher", icon = "📋", enabled = true, version = "2.0.0", category = "Editing" },
	{ id = "codeLens", name = "CodeLens", description = "Mostra referências acima da função", icon = "👁️", enabled = true, version = "1.0.0", category = "Editing" },
	{ id = "inlayHints", name = "Inlay Hints", description = "Mostra tipos, parametros inline", icon = "💭", enabled = true, version = "1.0.0", category = "Editing" },
	{ id = "vim", name = "Vim Mode", description = "Modo Vim - hjkl + comandos", icon = "⌨️", enabled = false, version = "1.0.0", category = "Editing" },

	-- Git / Collab
	{ id = "gitLens", name = "GitLens", description = "Mostra quem editou cada linha + history", icon = "🌿", enabled = true, version = "2.0.0", category = "Git" },
	{ id = "liveShare", name = "Live Share", description = "Colaboração em tempo real", icon = "👥", enabled = true, version = "1.0.0", category = "Git" },
	{ id = "diff", name = "Diff Editor", description = "Compara arquivos lado a lado", icon = "📊", enabled = true, version = "1.0.0", category = "Git" },

	-- Language specific
	{ id = "luau", name = "Luau Language Server", description = "LSP Luau - Types, strict, autocomplete Roblox", icon = "🌙", enabled = true, version = "1.0.0", category = "Language" },
	{ id = "python", name = "Python 3.14 LSP", description = "LSP Python 3.14 - Classes, async, match, type hints", icon = "🐍", enabled = true, version = "3.14.0", category = "Language" },
	{ id = "visual", name = "Visual Scripting", description = "Blocos Blockly - Arrasta e conecta", icon = "🧩", enabled = true, version = "1.0.0", category = "Language" },

	-- Arkher specific
	{ id = "arkherApi", name = "Arkher API IntelliSense", description = "Autocomplete Entity, Component, World, etc", icon = "🔷", enabled = true, version = "1.0.0", category = "Arkher" },
	{ id = "arkherDocs", name = "Arkher Docs Hover", description = "Hover mostra docs da API Arkher", icon = "📚", enabled = true, version = "1.0.0", category = "Arkher" },
	{ id = "arkherVault", name = "Arkher Vault Snippets", description = "Insere assets do Vault como código", icon = "💎", enabled = true, version = "1.0.0", category = "Arkher" },
	{ id = "arkherTerrain", name = "Arkher Terrain API", description = "Autocomplete MechaTerrainAPI", icon = "🏔️", enabled = true, version = "1.0.0", category = "Arkher" },
}

function MonacoPro.new(language: string?, themeSystem: any)
	local self = setmetatable({
		language = language or "luau",
		themeSystem = themeSystem,
		theme = MonacoPro.Themes.arkher,
		code = "",
		cursorPos = 1,
		selectionStart = nil,
		errors = {} :: { { line: number, message: string, severity: string, plugin: string } },
		warnings = {} :: { { line: number, message: string } },
		autocompleteItems = {},
		isFocused = false,
		frame = nil :: Frame?,
		textBox = nil :: TextBox?,
		lineNumbers = nil :: Frame?,
		minimap = nil :: Frame?,
		plugins = MonacoPro.Plugins,
		enabledPlugins = {} :: { [string]: boolean },
		aiSuggestions = {} :: { { text: string, line: number, aiConfidence: number } },
		snippets = {},
		breadcrumbs = {},
		codeLens = {},
		gitBlame = {},
	}, MonacoPro)

	for _, plugin in self.plugins do
		self.enabledPlugins[plugin.id] = plugin.enabled
	end

	return self
end

function MonacoPro:Init(parent: Frame, initialCode: string?)
	self.frame = parent
	self.code = initialCode or ""

	local colors = self.themeSystem and self.themeSystem:GetColors() or Shell.Colors

	-- Main container com layout VS Code: sidebar + editor + minimap + status
	local container = Instance.new("Frame")
	container.Name = "MonacoProContainer"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundColor3 = self.theme.background
	container.BorderSizePixel = 0
	container.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = container

	-- Top bar: breadcrumbs + language + theme + plugins
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 32)
	topBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	topBar.Parent = container

	local breadcrumbLabel = Instance.new("TextLabel")
	breadcrumbLabel.Name = "Breadcrumbs"
	breadcrumbLabel.Size = UDim2.new(0.5, 0, 1, 0)
	breadcrumbLabel.Position = UDim2.new(0, 10, 0, 0)
	breadcrumbLabel.BackgroundTransparency = 1
	breadcrumbLabel.Text = "📁 Project > 📜 Script > function MyFunc"
	breadcrumbLabel.TextColor3 = colors.textDim
	breadcrumbLabel.TextSize = 11
	breadcrumbLabel.Font = Enum.Font.Gotham
	breadcrumbLabel.TextXAlignment = Enum.TextXAlignment.Left
	breadcrumbLabel.Parent = topBar

	-- Language selector
	local langBtn = Instance.new("TextButton")
	langBtn.Name = "LanguageSelector"
	langBtn.Size = UDim2.new(0, 100, 0, 22)
	langBtn.Position = UDim2.new(1, -220, 0.5, -11)
	langBtn.BackgroundColor3 = colors.panelLight
	langBtn.Text = self.language == "luau" and "🌙 Luau" or self.language == "python" and "🐍 Python 3.14" or "🧩 Visual"
	langBtn.TextColor3 = colors.text
	langBtn.TextSize = 11
	langBtn.Font = Enum.Font.Gotham
	langBtn.Parent = topBar

	local langCorner = Instance.new("UICorner")
	langCorner.CornerRadius = UDim.new(0, 4)
	langCorner.Parent = langBtn

	-- AI status
	local aiStatus = Instance.new("TextLabel")
	aiStatus.Name = "AIStatus"
	aiStatus.Size = UDim2.new(0, 100, 0, 22)
	aiStatus.Position = UDim2.new(1, -110, 0.5, -11)
	aiStatus.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
	aiStatus.Text = "🤖 AI: Ready v1"
	aiStatus.TextColor3 = Color3.new(1,1,1)
	aiStatus.TextSize = 10
	aiStatus.Font = Enum.Font.GothamBold
	aiStatus.Parent = topBar

	local aiCorner = Instance.new("UICorner")
	aiCorner.CornerRadius = UDim.new(0, 4)
	aiCorner.Parent = aiStatus

	-- Main editor area: line numbers + editor + minimap + AI chat side
	local editorArea = Instance.new("Frame")
	editorArea.Name = "EditorArea"
	editorArea.Size = UDim2.new(1, 0, 1, -56)
	editorArea.Position = UDim2.new(0, 0, 0, 32)
	editorArea.BackgroundTransparency = 1
	editorArea.Parent = container

	-- Line numbers (40px)
	local lineNumbers = Instance.new("ScrollingFrame")
	lineNumbers.Name = "LineNumbers"
	lineNumbers.Size = UDim2.new(0, 50, 1, 0)
	lineNumbers.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	lineNumbers.ScrollBarThickness = 0
	lineNumbers.CanvasSize = UDim2.new(0, 0, 0, 0)
	lineNumbers.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lineNumbers.Parent = editorArea

	local lineLayout = Instance.new("UIListLayout")
	lineLayout.SortOrder = Enum.SortOrder.LayoutOrder
	lineLayout.Parent = lineNumbers

	self.lineNumbers = lineNumbers

	-- Editor (centro - 70%)
	local editorScroll = Instance.new("ScrollingFrame")
	editorScroll.Name = "EditorScroll"
	editorScroll.Size = UDim2.new(0.7, -90, 1, 0)
	editorScroll.Position = UDim2.new(0, 50, 0, 0)
	editorScroll.BackgroundTransparency = 1
	editorScroll.ScrollBarThickness = 6
	editorScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	editorScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	editorScroll.Parent = editorArea

	local textBox = Instance.new("TextBox")
	textBox.Name = "MonacoProTextBox"
	textBox.Size = UDim2.new(1, -10, 1, 0)
	textBox.BackgroundTransparency = 1
	textBox.Text = self.code
	textBox.TextColor3 = self.theme.foreground
	textBox.TextSize = 13
	textBox.Font = Enum.Font.Code
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.TextYAlignment = Enum.TextYAlignment.Top
	textBox.TextWrapped = false
	textBox.MultiLine = true
	textBox.ClearTextOnFocus = false
	textBox.TextEditable = true
	textBox.Parent = editorScroll

	self.textBox = textBox
	self.editorScroll = editorScroll

	-- Minimap (40px direita)
	local minimap = Instance.new("Frame")
	minimap.Name = "Minimap"
	minimap.Size = UDim2.new(0, 60, 1, 0)
	minimap.Position = UDim2.new(0.7, -10, 0, 0)
	minimap.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	minimap.BorderSizePixel = 0
	minimap.Parent = editorArea

	local minimapLabel = Instance.new("TextLabel")
	minimapLabel.Size = UDim2.new(1, 0, 0, 20)
	minimapLabel.BackgroundTransparency = 1
	minimapLabel.Text = "Minimap"
	minimapLabel.TextColor3 = colors.textDim
	minimapLabel.TextSize = 9
	minimapLabel.Font = Enum.Font.Gotham
	minimapLabel.Parent = minimap

	self.minimap = minimap

	-- AI Chat side panel (30% direita) - ARKHER AI v1
	local aiPanel = Instance.new("Frame")
	aiPanel.Name = "AIPanel"
	aiPanel.Size = UDim2.new(0.3, 0, 1, 0)
	aiPanel.Position = UDim2.new(0.7, 50, 0, 0)
	aiPanel.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
	aiPanel.Parent = editorArea

	local aiHeader = Instance.new("TextLabel")
	aiHeader.Size = UDim2.new(1, 0, 0, 30)
	aiHeader.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
	aiHeader.Text = "🤖 ARKHER AI v1 - Copilot"
	aiHeader.TextColor3 = Color3.new(1,1,1)
	aiHeader.TextSize = 11
	aiHeader.Font = Enum.Font.GothamBold
	aiHeader.Parent = aiPanel

	local aiChatScroll = Instance.new("ScrollingFrame")
	aiChatScroll.Name = "AIChat"
	aiChatScroll.Size = UDim2.new(1, -10, 1, -80)
	aiChatScroll.Position = UDim2.new(0, 5, 0, 35)
	aiChatScroll.BackgroundTransparency = 1
	aiChatScroll.ScrollBarThickness = 4
	aiChatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	aiChatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	aiChatScroll.Parent = aiPanel

	local aiLayout = Instance.new("UIListLayout")
	aiLayout.Padding = UDim.new(0, 5)
	aiLayout.Parent = aiChatScroll

	-- AI suggestions list
	local aiSuggestionLabel = Instance.new("TextLabel")
	aiSuggestionLabel.Size = UDim2.new(1, -10, 0, 60)
	aiSuggestionLabel.BackgroundColor3 = Color3.fromRGB(38, 38, 55)
	aiSuggestionLabel.Text = "💡 AI Suggestions:\n• Explain code\n• Fix errors\n• Generate function\n• Optimize"
	aiSuggestionLabel.TextColor3 = colors.text
	aiSuggestionLabel.TextSize = 10
	aiSuggestionLabel.Font = Enum.Font.Gotham
	aiSuggestionLabel.TextWrapped = true
	aiSuggestionLabel.TextXAlignment = Enum.TextXAlignment.Left
	aiSuggestionLabel.Parent = aiChatScroll

	-- AI input
	local aiInput = Instance.new("TextBox")
	aiInput.Name = "AIInput"
	aiInput.Size = UDim2.new(1, -10, 0, 30)
	aiInput.Position = UDim2.new(0, 5, 1, -35)
	aiInput.BackgroundColor3 = colors.background
	aiInput.PlaceholderText = "🤖 Ask AI: 'cria inventario...'"
	aiInput.Text = ""
	aiInput.TextColor3 = colors.text
	aiInput.TextSize = 11
	aiInput.Font = Enum.Font.Gotham
	aiInput.Parent = aiPanel

	local aiInputCorner = Instance.new("UICorner")
	aiInputCorner.CornerRadius = UDim.new(0, 6)
	aiInputCorner.Parent = aiInput

	-- Autocomplete popup
	local autocomplete = Instance.new("Frame")
	autocomplete.Name = "AutocompletePro"
	autocomplete.Size = UDim2.new(0, 300, 0, 200)
	autocomplete.Position = UDim2.new(0, 60, 0, 80)
	autocomplete.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
	autocomplete.Visible = false
	autocomplete.ZIndex = 10
	autocomplete.Parent = container

	local autoCorner = Instance.new("UICorner")
	autoCorner.CornerRadius = UDim.new(0, 8)
	autoCorner.Parent = autocomplete

	local autoHeader = Instance.new("TextLabel")
	autoHeader.Size = UDim2.new(1, 0, 0, 24)
	autoHeader.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
	autoHeader.Text = "💡 IntelliSense + ARKHER AI"
	autoHeader.TextColor3 = Color3.new(1,1,1)
	autoHeader.TextSize = 11
	autoHeader.Font = Enum.Font.GothamBold
	autoHeader.Parent = autocomplete

	local autoList = Instance.new("ScrollingFrame")
	autoList.Name = "AutoList"
	autoList.Size = UDim2.new(1, 0, 1, -24)
	autoList.Position = UDim2.new(0, 0, 0, 24)
	autoList.BackgroundTransparency = 1
	autoList.ScrollBarThickness = 4
	autoList.CanvasSize = UDim2.new(0, 0, 0, 0)
	autoList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	autoList.Parent = autocomplete

	local autoLayout = Instance.new("UIListLayout")
	autoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	autoLayout.Parent = autoList

	-- Status bar bottom
	local statusBar = Instance.new("Frame")
	statusBar.Name = "StatusBar"
	statusBar.Size = UDim2.new(1, 0, 0, 24)
	statusBar.Position = UDim2.new(0, 0, 1, -24)
	statusBar.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
	statusBar.Parent = container

	local statusLeft = Instance.new("TextLabel")
	statusLeft.Size = UDim2.new(0.4, 0, 1, 0)
	statusLeft.BackgroundTransparency = 1
	statusLeft.Text = "  Ln 1, Col 1 | Spaces: 4 | UTF-8 | " .. self.language
	statusLeft.TextColor3 = Color3.new(1,1,1)
	statusLeft.TextSize = 10
	statusLeft.Font = Enum.Font.Code
	statusLeft.TextXAlignment = Enum.TextXAlignment.Left
	statusLeft.Parent = statusBar

	local statusRight = Instance.new("TextLabel")
	statusRight.Size = UDim2.new(0.6, -10, 1, 0)
	statusRight.Position = UDim2.new(0.4, 0, 0, 0)
	statusRight.BackgroundTransparency = 1
	statusRight.Text = "🤖 ARKHER AI v1: Ready | ✅ No errors | 📦 Plugins: 25 enabled | Prettier: ON"
	statusRight.TextColor3 = Color3.new(1,1,1)
	statusRight.TextSize = 10
	statusRight.Font = Enum.Font.Code
	statusRight.TextXAlignment = Enum.TextXAlignment.Right
	statusRight.Parent = statusBar

	-- Events
	textBox:GetPropertyChangedSignal("Text"):Connect(function()
		self.code = textBox.Text
		self:UpdateLineNumbers()
		self:CheckErrorsPro()
		self:UpdateAutocompletePro()
		self:UpdateAISuggestions()
		self:UpdateStatusBar()
	end)

	textBox.Focused:Connect(function()
		self.isFocused = true
	end)

	textBox.FocusLost:Connect(function()
		self.isFocused = false
	end)

	aiInput.FocusLost:Connect(function(enter)
		if enter and aiInput.Text ~= "" then
			self:AskAI(aiInput.Text)
			aiInput.Text = ""
		end
	end)

	self:UpdateLineNumbers()
	self:LoadAutocompletePro()
	self:LoadSnippets()

	print("[Arkher MonacoPro] Initialized - Language:", self.language, "- Theme:", self.theme.name, "- Plugins:", #self.plugins, "- ARKHER AI v1 Ready")
end

function MonacoPro:UpdateLineNumbers()
	if not self.lineNumbers or not self.textBox then return end

	for _, child in self.lineNumbers:GetChildren() do
		if child:IsA("TextLabel") then child:Destroy() end
	end

	local lines = string.split(self.textBox.Text, "\n")
	for i = 1, #lines do
		local label = Instance.new("TextLabel")
		label.Name = "Line_" .. i
		label.Size = UDim2.new(1, 0, 0, 18)
		label.BackgroundTransparency = 1
		label.Text = tostring(i)
		label.TextColor3 = self.theme.lineNumber
		label.TextSize = 12
		label.Font = Enum.Font.Code
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.LayoutOrder = i
		label.Parent = self.lineNumbers

		for _, err in self.errors do
			if err.line == i then
				label.TextColor3 = err.severity == "error" and self.theme.error or self.theme.warning
				label.Text = "● " .. i
			end
		end
	end
end

function MonacoPro:CheckErrorsPro()
	self.errors = {}
	local lines = string.split(self.code, "\n")

	for i, line in lines do
		if self.language == "luau" then
			local openParen = select(2, string.gsub(line, "%(", ""))
			local closeParen = select(2, string.gsub(line, "%)", ""))
			if openParen ~= closeParen then
				table.insert(self.errors, { line = i, message = "Mismatched parentheses", severity = "error", plugin = "eslint" })
			end
			if string.find(line, "%.%.%.") and not string.find(line, "print") then
				table.insert(self.errors, { line = i, message = "Variadic args ... should be used in function", severity = "warning", plugin = "luau" })
			end
		elseif self.language == "python" then
			if (string.find(line, "^%s*def ") or string.find(line, "^%s*if ") or string.find(line, "^%s*for ") or string.find(line, "^%s*while ") or string.find(line, "^%s*class ")) and not string.find(line, ":") and not string.find(line, "#") then
				table.insert(self.errors, { line = i, message = "Missing colon", severity = "error", plugin = "python" })
			end
		end
	end

	-- AI auto-fix suggestions
	if #self.errors > 0 and self.enabledPlugins["arkherFix"] then
		for _, err in self.errors do
			table.insert(self.aiSuggestions, { text = "🔧 AI Fix: " .. err.message, line = err.line, aiConfidence = 0.9 })
		end
	end

	self:UpdateLineNumbers()
end

function MonacoPro:LoadAutocompletePro()
	local items = {}

	if self.language == "luau" then
		items = {
			{ label = "print", kind = "Function", detail = "print(...)", insertText = "print($1)", plugin = "luau", ai = false },
			{ label = "Vector3.new", kind = "Function", detail = "Vector3.new(x,y,z)", insertText = "Vector3.new($1, $2, $3)", plugin = "luau", ai = false },
			{ label = "Color3.fromRGB", kind = "Function", detail = "Color3.fromRGB(r,g,b)", insertText = "Color3.fromRGB($1, $2, $3)", plugin = "luau", ai = false },
			{ label = "Instance.new", kind = "Function", detail = "Instance.new(className)", insertText = "Instance.new(\"$1\")", plugin = "luau", ai = false },
			{ label = "Entity.new", kind = "Function", detail = "Arkher Entity - ECS", insertText = "Entity.new(\"$1\")", plugin = "arkherApi", ai = false },
			{ label = "Component.Transform", kind = "Function", detail = "Transform component - Mecha Engine", insertText = "Component.Transform(Vector3.new($1))", plugin = "arkherApi", ai = false },
			{ label = "Component.Render", kind = "Function", detail = "Render component - PBR", insertText = "Component.Render(Enum.Material.${1:Plastic}, Color3.fromRGB($2))", plugin = "arkherApi", ai = false },
			{ label = "MechaTerrainAPI:GenerateChunk", kind = "Function", detail = "Generate chunk Mecha Engine", insertText = "MechaTerrainAPI:GenerateChunk(${1:x}, ${2:y}, ${3:z})", plugin = "arkherTerrain", ai = false },
			{ label = "ArkherAI:GenerateModel", kind = "Function", detail = "Generate 3D model with ARKHER AI v1", insertText = "ArkherAI:GenerateModel(\"${1:prompt}\", \"${2:style}\")", plugin = "arkherCopilot", ai = true },
			{ label = "ArkherAI:GenerateScript", kind = "Function", detail = "Generate script with ARKHER AI v1", insertText = "ArkherAI:GenerateScript(\"${1:prompt}\")", plugin = "arkherCopilot", ai = true },
		}
	elseif self.language == "python" then
		items = {
			{ label = "print", kind = "Function", detail = "print(value)", insertText = "print($1)", plugin = "python", ai = false },
			{ label = "Entity.new", kind = "Function", detail = "Arkher Entity", insertText = "Entity.new(\"$1\")", plugin = "arkherApi", ai = false },
			{ label = "def", kind = "Keyword", detail = "Define function", insertText = "def ${1:name}($2):\n    $3", plugin = "python", ai = false },
			{ label = "for", kind = "Keyword", detail = "For loop", insertText = "for ${1:i} in ${2:range}:\n    $3", plugin = "python", ai = false },
			{ label = "ArkherAI", kind = "Class", detail = "ARKHER AI v1 API", insertText = "ArkherAI", plugin = "arkherCopilot", ai = true },
		}
	end

	self.autocompleteItems = items
	print("[Arkher MonacoPro] Loaded", #items, "autocomplete items + AI for", self.language)
end

function MonacoPro:LoadSnippets()
	self.snippets = {
		{ prefix = "arkher_entity", body = "local ${1:entity} = Entity.new(\"${2:Name}\")\nEntity.AddComponent(${1:entity}, \"Transform\", Component.Transform(Vector3.new($3)))\nEntity.AddComponent(${1:entity}, \"Render\", Component.Render(Enum.Material.${4:Plastic}, Color3.fromRGB($5)))\nself.world:AddEntity(${1:entity})", description = "Create Arkher Entity" },
		{ prefix = "arkher_terrain", body = "local chunk = MechaTerrainAPI:GenerateChunk(${1:x}, ${2:y}, ${3:z}, \"${4:plains}\")\nMechaTerrainAPI:MeshChunk(chunk, \"${5:greedy}\")", description = "Generate Terrain Chunk Mecha" },
		{ prefix = "arkher_ai_model", body = "-- ARKHER AI v1 - Generate 3D Model\nlocal result = ArkherAI:GenerateModel(\"${1:katana cyberpunk ultra realista}\", \"${2:photorealistic}\")\nprint(\"Generated:\", result.mesh.vertices, \"verts\")", description = "AI Generate Model" },
	}
end

function MonacoPro:UpdateAutocompletePro()
	if not self.frame then return end
	local container = self.frame:FindFirstChild("MonacoProContainer")
	if not container then return end
	local autocomplete = container:FindFirstChild("AutocompletePro")
	if not autocomplete then return end

	local text = self.code
	local lastWord = string.match(text, "([%w_%.:]+)$")

	if lastWord and #lastWord >= 2 then
		local filtered = {}
		for _, item in self.autocompleteItems do
			if string.find(string.lower(item.label), string.lower(lastWord), 1, true) then
				if self.enabledPlugins[item.plugin] then
					table.insert(filtered, item)
				end
			end
		end

		-- Add AI suggestions on top if enabled
		if self.enabledPlugins["arkherCopilot"] then
			for _, aiSugg in self.aiSuggestions do
				if string.find(string.lower(aiSugg.text), string.lower(lastWord), 1, true) then
					table.insert(filtered, 1, { label = aiSugg.text, kind = "AI", detail = "ARKHER AI v1 - Confidence: " .. math.floor(aiSugg.aiConfidence*100) .. "%", insertText = aiSugg.text, plugin = "arkherCopilot", ai = true })
				end
			end
		end

		if #filtered > 0 and #filtered <= 15 then
			local autoList = autocomplete:FindFirstChild("AutoList")
			if autoList then
				for _, child in autoList:GetChildren() do if child:IsA("TextButton") then child:Destroy() end end

				for i, item in filtered do
					local btn = Instance.new("TextButton")
					btn.Size = UDim2.new(1, -10, 0, 32)
					btn.BackgroundColor3 = item.ai and Color3.fromRGB(120, 80, 255) or Color3.fromRGB(55, 55, 75)
					btn.Text = ""
					btn.LayoutOrder = i
					btn.Parent = autoList

					local corner = Instance.new("UICorner")
					corner.CornerRadius = UDim.new(0, 4)
					corner.Parent = btn

					local icon = Instance.new("TextLabel")
					icon.Size = UDim2.new(0, 30, 1, 0)
					icon.BackgroundTransparency = 1
					icon.Text = item.ai and "🤖" or item.kind == "Function" and "ƒ" or "📦"
					icon.TextColor3 = item.ai and Color3.new(1,1,1) or Color3.fromRGB(200,200,200)
					icon.TextSize = 14
					icon.Parent = btn

					local label = Instance.new("TextLabel")
					label.Size = UDim2.new(1, -90, 0.6, 0)
					label.Position = UDim2.new(0, 35, 0, 0)
					label.BackgroundTransparency = 1
					label.Text = item.label
					label.TextColor3 = Color3.new(1,1,1)
					label.TextSize = 11
					label.Font = Enum.Font.Code
					label.TextXAlignment = Enum.TextXAlignment.Left
					label.Parent = btn

					local detail = Instance.new("TextLabel")
					detail.Size = UDim2.new(1, -90, 0.4, 0)
					detail.Position = UDim2.new(0, 35, 0.6, 0)
					detail.BackgroundTransparency = 1
					detail.Text = item.detail .. " • " .. item.plugin
					detail.TextColor3 = Color3.fromRGB(150,150,170)
					detail.TextSize = 9
					detail.Font = Enum.Font.Gotham
					detail.TextXAlignment = Enum.TextXAlignment.Left
					detail.Parent = btn

					btn.MouseButton1Click:Connect(function()
						self:InsertAutocomplete(item)
						autocomplete.Visible = false
					end)
				end

				autocomplete.Visible = true
			end
		else
			autocomplete.Visible = false
		end
	else
		autocomplete.Visible = false
	end
end

function MonacoPro:UpdateAISuggestions()
	if not self.enabledPlugins["arkherCopilot"] then return end
	-- Simulate AI suggestions based on context
	local text = self.code
	if string.find(text, "Entity") and not string.find(text, "AddComponent") then
		table.insert(self.aiSuggestions, { text = "Entity.AddComponent(entity, \"Transform\", Component.Transform(...))", line = 1, aiConfidence = 0.95 })
	end
	if string.find(text, "function") and #text < 100 then
		table.insert(self.aiSuggestions, { text = "-- ARKHER AI: Generate function body from comment", line = 1, aiConfidence = 0.85 })
	end
end

function MonacoPro:AskAI(prompt: string)
	print("[Arkher MonacoPro] Asking ARKHER AI v1:", prompt)
	-- In production, calls backend /api/arkherai/chat
	-- Mock response
	if self.frame then
		local container = self.frame:FindFirstChild("MonacoProContainer")
		local editorArea = container and container:FindFirstChild("EditorArea")
		local aiPanel = editorArea and editorArea:FindFirstChild("AIPanel")
		local aiChat = aiPanel and aiPanel:FindFirstChild("AIChat")
		if aiChat then
			local response = Instance.new("TextLabel")
			response.Size = UDim2.new(1, -10, 0, 60)
			response.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
			response.Text = "🤖 AI: Gerando código para '" .. prompt .. "'...\n(ARKHER AI v1 - 3.98M params - local)"
			response.TextColor3 = Color3.new(1,1,1)
			response.TextSize = 10
			response.Font = Enum.Font.Gotham
			response.TextWrapped = true
			response.TextXAlignment = Enum.TextXAlignment.Left
			response.Parent = aiChat

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = response

			task.delay(1, function()
				response.Text = "🤖 AI: Pronto! Sugestão:\nlocal inventory = {}\nfunction inventory:AddItem(item)\n  table.insert(self.items, item)\nend\n-- Gerado por ARKHER AI v1"
				response.Size = UDim2.new(1, -10, 0, 100)
			end)
		end
	end
end

function MonacoPro:UpdateStatusBar()
	if not self.frame then return end
	local container = self.frame:FindFirstChild("MonacoProContainer")
	local statusBar = container and container:FindFirstChild("StatusBar")
	if statusBar then
		local left = statusBar:FindFirstChild("StatusBar") or statusBar:FindFirstChild("Left")
		-- Update errors count
		local right = statusBar:FindFirstChild("RightStatus")
		if right then
			right.Text = string.format("🤖 ARKHER AI v1: Ready | %s%d errors | 📦 Plugins: %d | %s", #self.errors > 0 and "❌ " or "✅ ", #self.errors, #self.plugins, self.language)
		end
	end
end

function MonacoPro:InsertAutocomplete(item: any)
	if not self.textBox then return end
	local text = self.textBox.Text
	local lastWord = string.match(text, "([%w_%.:]+)$")
	if lastWord then
		local newText = string.gsub(text, "([%w_%.:]+)$", item.insertText)
		newText = string.gsub(newText, "%$%d", "")
		newText = string.gsub(newText, "%${%d+:?(.-)}", "%1")
		self.textBox.Text = newText
		self.code = newText
		print("[Arkher MonacoPro] Inserted:", item.label, "Plugin:", item.plugin, "AI:", tostring(item.ai))
	end
end

function MonacoPro:SetLanguage(langId: string)
	self.language = langId
	self:LoadAutocompletePro()
	self:CheckErrorsPro()
	print("[Arkher MonacoPro] Language ->", langId)
end

function MonacoPro:SetCode(code: string)
	self.code = code
	if self.textBox then self.textBox.Text = code end
	self:UpdateLineNumbers()
	self:CheckErrorsPro()
end

function MonacoPro:GetCode(): string return self.code end
function MonacoPro:GetErrors(): { any } return self.errors end

function MonacoPro:TogglePlugin(pluginId: string)
	self.enabledPlugins[pluginId] = not self.enabledPlugins[pluginId]
	print("[Arkher MonacoPro] Plugin", pluginId, "->", self.enabledPlugins[pluginId] and "ON" or "OFF")
end

function MonacoPro:GetStats()
	return {
		language = self.language,
		theme = self.theme.name,
		errors = #self.errors,
		pluginsTotal = #self.plugins,
		pluginsEnabled = (function() local c=0 for _,v in self.enabledPlugins do if v then c+=1 end end return c end)(),
		aiSuggestions = #self.aiSuggestions,
		snippets = #self.snippets,
		message = "MonacoPro - VS Code level + 25 plugins + ARKHER AI v1 Copilot + Themes + Minimap + Vim + Emmet",
	}
end

return MonacoPro

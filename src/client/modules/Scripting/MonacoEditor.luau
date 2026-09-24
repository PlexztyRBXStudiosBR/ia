--!strict
-- Arkher Studio - Fase 2 - MonacoEditor - Editor nível VS Code dentro do Roblox
-- Syntax highlight, autocomplete, erros, minimap - Inspirado no Monaco (VS Code)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shell = require(script.Parent.Parent.UI.Shell)
local LanguageSupport = require(ReplicatedStorage.Arkher.Scripting.LanguageSupport)

local MonacoEditor = {}
MonacoEditor.__index = MonacoEditor

-- Temas Monaco
MonacoEditor.Themes = {
	dark = {
		background = Color3.fromRGB(30, 30, 30),
		foreground = Color3.fromRGB(212, 212, 212),
		lineNumber = Color3.fromRGB(133, 133, 133),
		selection = Color3.fromRGB(38, 79, 120),
		cursor = Color3.fromRGB(212, 212, 212),
		keyword = Color3.fromRGB(86, 156, 214), -- azul
		string = Color3.fromRGB(206, 145, 120), -- laranja
		comment = Color3.fromRGB(106, 153, 85), -- verde
		number = Color3.fromRGB(181, 206, 168),
		functionName = Color3.fromRGB(220, 220, 170),
		type = Color3.fromRGB(78, 201, 176),
		error = Color3.fromRGB(244, 71, 71),
		warning = Color3.fromRGB(255, 203, 107),
	},
}

-- Keywords por linguagem
MonacoEditor.Keywords = {
	luau = {"local", "function", "end", "if", "then", "else", "elseif", "for", "while", "do", "return", "type", "export", "and", "or", "not", "true", "false", "nil"},
	python = {"def", "class", "if", "elif", "else", "for", "while", "import", "from", "return", "True", "False", "None", "match", "case", "async", "await", "try", "except", "with", "as"},
}

function MonacoEditor.new(language: string?)
	return setmetatable({
		language = language or "luau",
		theme = MonacoEditor.Themes.dark,
		code = "",
		cursorPos = 1,
		selectionStart = nil,
		errors = {} :: { { line: number, message: string, severity: string } },
		autocompleteItems = {},
		isFocused = false,
		frame = nil :: Frame?,
		textBox = nil :: TextBox?,
		lineNumbers = nil :: Frame?,
		minimap = nil :: Frame?,
	}, MonacoEditor)
end

function MonacoEditor:Init(parent: Frame, initialCode: string?)
	self.frame = parent
	self.code = initialCode or ""

	-- Container principal com 3 partes: line numbers, editor, minimap
	local container = Instance.new("Frame")
	container.Name = "MonacoContainer"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundColor3 = self.theme.background
	container.BorderSizePixel = 0
	container.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = container

	-- Line numbers (esquerda, 40px)
	local lineNumbers = Instance.new("ScrollingFrame")
	lineNumbers.Name = "LineNumbers"
	lineNumbers.Size = UDim2.new(0, 40, 1, 0)
	lineNumbers.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	lineNumbers.ScrollBarThickness = 0
	lineNumbers.CanvasSize = UDim2.new(0, 0, 0, 0)
	lineNumbers.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lineNumbers.Parent = container

	local lineLayout = Instance.new("UIListLayout")
	lineLayout.SortOrder = Enum.SortOrder.LayoutOrder
	lineLayout.Parent = lineNumbers

	self.lineNumbers = lineNumbers

	-- Editor (centro)
	local editorScroll = Instance.new("ScrollingFrame")
	editorScroll.Name = "EditorScroll"
	editorScroll.Size = UDim2.new(1, -80, 1, 0)
	editorScroll.Position = UDim2.new(0, 40, 0, 0)
	editorScroll.BackgroundTransparency = 1
	editorScroll.ScrollBarThickness = 6
	editorScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	editorScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	editorScroll.Parent = container

	local textBox = Instance.new("TextBox")
	textBox.Name = "MonacoTextBox"
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

	-- Minimap (direita, 40px, preview do código)
	local minimap = Instance.new("Frame")
	minimap.Name = "Minimap"
	minimap.Size = UDim2.new(0, 40, 1, 0)
	minimap.Position = UDim2.new(1, -40, 0, 0)
	minimap.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	minimap.BorderSizePixel = 0
	minimap.Parent = container

	self.minimap = minimap

	-- Autocomplete popup (escondido)
	local autocomplete = Instance.new("Frame")
	autocomplete.Name = "Autocomplete"
	autocomplete.Size = UDim2.new(0, 200, 0, 150)
	autocomplete.Position = UDim2.new(0, 50, 0, 50)
	autocomplete.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	autocomplete.Visible = false
	autocomplete.ZIndex = 10
	autocomplete.Parent = container

	local autoCorner = Instance.new("UICorner")
	autoCorner.CornerRadius = UDim.new(0, 4)
	autoCorner.Parent = autocomplete

	local autoList = Instance.new("ScrollingFrame")
	autoList.Name = "AutoList"
	autoList.Size = UDim2.new(1, 0, 1, 0)
	autoList.BackgroundTransparency = 1
	autoList.ScrollBarThickness = 4
	autoList.CanvasSize = UDim2.new(0, 0, 0, 0)
	autoList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	autoList.Parent = autocomplete

	local autoLayout = Instance.new("UIListLayout")
	autoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	autoLayout.Parent = autoList

	-- Eventos
	textBox:GetPropertyChangedSignal("Text"):Connect(function()
		self.code = textBox.Text
		self:UpdateLineNumbers()
		self:CheckErrors()
		self:UpdateAutocomplete()
	end)

	textBox.Focused:Connect(function()
		self.isFocused = true
		print("[Arkher Monaco] Focused - Language:", self.language)
	end)

	textBox.FocusLost:Connect(function()
		self.isFocused = false
	end)

	-- Inicializa
	self:UpdateLineNumbers()
	self:LoadAutocomplete()

	print("[Arkher Monaco] Initialized - Language:", self.language, "- Theme: dark - VS Code style")
end

function MonacoEditor:UpdateLineNumbers()
	if not self.lineNumbers or not self.textBox then return end

	-- Limpa
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

		-- Se tem erro nessa linha, marca vermelho
		for _, err in self.errors do
			if err.line == i then
				label.TextColor3 = err.severity == "error" and self.theme.error or self.theme.warning
				label.Text = "● " .. i
			end
		end
	end
end

function MonacoEditor:CheckErrors()
	self.errors = {}

	local lines = string.split(self.code, "\n")

	for i, line in lines do
		-- Checagem simples de erros comuns
		if self.language == "luau" then
			-- Verifica parênteses não fechados (simplificado)
			local openParen = select(2, string.gsub(line, "%(", ""))
			local closeParen = select(2, string.gsub(line, "%)", ""))
			if openParen ~= closeParen then
				table.insert(self.errors, { line = i, message = "Mismatched parentheses", severity = "error" })
			end

			-- Verifica function sem end (muito simplificado)
			if string.find(line, "function") and not string.find(line, "end") then
				-- Conta ends nas próximas linhas? Fase 2 simplificado
			end
		elseif self.language == "python" then
			-- Verifica : no final de def/if/for
			if (string.find(line, "^%s*def ") or string.find(line, "^%s*if ") or string.find(line, "^%s*for ") or string.find(line, "^%s*while ")) and not string.find(line, ":") then
				table.insert(self.errors, { line = i, message = "Missing colon", severity = "error" })
			end

			-- Verifica indentação (Python)
			if string.find(line, "^%s+") then
				local indent = string.match(line, "^(%s+)")
				if indent and #indent % 4 ~= 0 and #indent % 2 ~= 0 then
					table.insert(self.errors, { line = i, message = "Indentation should be 4 spaces", severity = "warning" })
				end
			end
		end
	end

	if #self.errors > 0 then
		print("[Arkher Monaco] Found", #self.errors, "errors/warnings")
	end

	self:UpdateLineNumbers()
end

function MonacoEditor:LoadAutocomplete()
	-- Carrega autocomplete baseado na linguagem
	local items = {}

	if self.language == "luau" then
		items = {
			{ label = "print", kind = "Function", detail = "print(...)", insertText = "print($1)" },
			{ label = "Vector3.new", kind = "Function", detail = "Vector3.new(x,y,z)", insertText = "Vector3.new($1, $2, $3)" },
			{ label = "Color3.fromRGB", kind = "Function", detail = "Color3.fromRGB(r,g,b)", insertText = "Color3.fromRGB($1, $2, $3)" },
			{ label = "Instance.new", kind = "Function", detail = "Instance.new(className)", insertText = "Instance.new(\"$1\")" },
			{ label = "Entity.new", kind = "Function", detail = "Arkher Entity", insertText = "Entity.new(\"$1\")" },
			{ label = "Component.Transform", kind = "Function", detail = "Transform component", insertText = "Component.Transform(Vector3.new($1))" },
			{ label = "Component.Render", kind = "Function", detail = "Render component", insertText = "Component.Render(Enum.Material.${1:Plastic}, Color3.fromRGB($2))" },
			{ label = "World", kind = "Class", detail = "ECS World", insertText = "World" },
			{ label = "game:GetService", kind = "Function", detail = "Get Roblox service", insertText = "game:GetService(\"$1\")" },
		}
	elseif self.language == "python" then
		items = {
			{ label = "print", kind = "Function", detail = "print(value)", insertText = "print($1)" },
			{ label = "Entity.new", kind = "Function", detail = "Arkher Entity", insertText = "Entity.new(\"$1\")" },
			{ label = "Component.Transform", kind = "Function", detail = "Transform", insertText = "Component.Transform(position=Vector3($1))" },
			{ label = "Vector3", kind = "Class", detail = "Vector3(x,y,z)", insertText = "Vector3($1, $2, $3)" },
			{ label = "Color3", kind = "Class", detail = "Color3", insertText = "Color3.from_rgb($1, $2, $3)" },
			{ label = "def", kind = "Keyword", detail = "Define function", insertText = "def ${1:name}($2):\n    $3" },
			{ label = "for", kind = "Keyword", detail = "For loop", insertText = "for ${1:i} in ${2:range}:\n    $3" },
			{ label = "if", kind = "Keyword", detail = "If statement", insertText = "if ${1:condition}:\n    $2" },
			{ label = "match", kind = "Keyword", detail = "Match statement (3.10+)", insertText = "match ${1:var}:\n    case \"${2:gold}\":\n        $3" },
			{ label = "from arkher import", kind = "Keyword", detail = "Import Arkher", insertText = "from arkher import ${1:Entity}, ${2:Component}" },
		}
	end

	self.autocompleteItems = items
	print("[Arkher Monaco] Loaded", #items, "autocomplete items for", self.language)
end

function MonacoEditor:UpdateAutocomplete()
	-- Mostra autocomplete baseado no texto atual (simplificado)
	-- Em produção, usa Trie + fuzzy search

	if not self.frame then return end

	local container = self.frame:FindFirstChild("MonacoContainer")
	if not container then return end

	local autocomplete = container:FindFirstChild("Autocomplete")
	if not autocomplete then return end

	-- Pega última palavra digitada
	local text = self.code
	local lastWord = string.match(text, "([%w_%.]+)$")

	if lastWord and #lastWord >= 2 then
		local filtered = {}

		for _, item in self.autocompleteItems do
			if string.find(string.lower(item.label), string.lower(lastWord), 1, true) then
				table.insert(filtered, item)
			end
		end

		if #filtered > 0 and #filtered <= 10 then
			-- Mostra popup
			local autoList = autocomplete:FindFirstChild("AutoList")
			if autoList then
				-- Limpa
				for _, child in autoList:GetChildren() do
					if child:IsA("TextButton") then child:Destroy() end
				end

				for i, item in filtered do
					local btn = Instance.new("TextButton")
					btn.Size = UDim2.new(1, -10, 0, 24)
					btn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
					btn.Text = item.label .. " - " .. item.detail
					btn.TextColor3 = Color3.fromRGB(212, 212, 212)
					btn.TextSize = 11
					btn.Font = Enum.Font.Code
					btn.TextXAlignment = Enum.TextXAlignment.Left
					btn.LayoutOrder = i
					btn.Parent = autoList

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

function MonacoEditor:InsertAutocomplete(item: any)
	if not self.textBox then return end

	-- Substitui última palavra pelo insertText
	local text = self.textBox.Text
	local lastWord = string.match(text, "([%w_%.]+)$")

	if lastWord then
		local newText = string.gsub(text, "([%w_%.]+)$", item.insertText)
		-- Remove $1, $2 placeholders para simplificar
		newText = string.gsub(newText, "%$%d", "")
		newText = string.gsub(newText, "%${%d+:?(.-)}", "%1")

		self.textBox.Text = newText
		self.code = newText

		print("[Arkher Monaco] Inserted autocomplete:", item.label)
	end
end

function MonacoEditor:SetLanguage(langId: string)
	self.language = langId
	self:LoadAutocomplete()
	self:CheckErrors()
	print("[Arkher Monaco] Language ->", langId)
end

function MonacoEditor:SetCode(code: string)
	self.code = code
	if self.textBox then
		self.textBox.Text = code
	end
	self:UpdateLineNumbers()
	self:CheckErrors()
end

function MonacoEditor:GetCode(): string
	return self.code
end

function MonacoEditor:GetErrors(): { any }
	return self.errors
end

return MonacoEditor

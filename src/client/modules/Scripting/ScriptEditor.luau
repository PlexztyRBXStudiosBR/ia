--!strict
-- Arkher Studio - Fase 1.5 - ScriptEditor - Suporta Luau, Python 3.14, Visual, AI
-- IA ajuda em todas

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LanguageSupport = require(ReplicatedStorage.Arkher.Scripting.LanguageSupport)
local Shell = require(script.Parent.Parent.UI.Shell)

local ScriptEditor = {}
ScriptEditor.__index = ScriptEditor

function ScriptEditor.new(pythonService: any)
	return setmetatable({
		pythonService = pythonService,
		currentLanguage = "luau" :: string,
		currentCode = "",
		frame = nil :: Frame?,
		editorBox = nil :: TextBox?,
		languageSelector = nil :: Frame?,
		aiPromptBox = nil :: TextBox?,
	}, ScriptEditor)
end

function ScriptEditor:Init(parent: Frame)
	self.frame = parent

	-- Header com seletor de linguagem
	local header = Instance.new("Frame")
	header.Name = "ScriptHeader"
	header.Size = UDim2.new(1, 0, 0, 40)
	header.BackgroundColor3 = Shell.Colors.panelLight
	header.Parent = parent

	-- Título
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 150, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "📜 Script Editor"
	title.TextColor3 = Shell.Colors.text
	title.TextSize = 12
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	-- Seletor de linguagem: Luau, Python 3.14, Visual, AI
	local languages = {
		{ id = "luau", name = "🌙 Luau", color = Shell.Colors.accent },
		{ id = "python", name = "🐍 Python 3.14", color = Color3.fromRGB(55, 118, 171) },
		{ id = "visual", name = "🧩 Visual", color = Color3.fromRGB(0, 200, 100) },
		{ id = "ai", name = "🤖 AI Gen", color = Color3.fromRGB(255, 180, 0) },
	}

	for i, lang in languages do
		local btn = Instance.new("TextButton")
		btn.Name = lang.id .. "Btn"
		btn.Size = UDim2.new(0, 110, 0, 28)
		btn.Position = UDim2.new(0, 160 + (i-1)*115, 0, 6)
		btn.BackgroundColor3 = lang.id == self.currentLanguage and lang.color or Shell.Colors.panel
		btn.Text = lang.name
		btn.TextColor3 = Shell.Colors.text
		btn.TextSize = 10
		btn.Font = Enum.Font.Gotham
		btn.Parent = header

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			self:SetLanguage(lang.id)

			-- Atualiza visual
			for _, other in header:GetChildren() do
				if other:IsA("TextButton") and other.Name:find("Btn") then
					other.BackgroundColor3 = Shell.Colors.panel
				end
			end
			btn.BackgroundColor3 = lang.color
		end)
	end

	-- Run button
	local runBtn = Instance.new("TextButton")
	runBtn.Name = "RunBtn"
	runBtn.Size = UDim2.new(0, 60, 0, 28)
	runBtn.Position = UDim2.new(1, -70, 0, 6)
	runBtn.BackgroundColor3 = Shell.Colors.success
	runBtn.Text = "▶ Run"
	runBtn.TextColor3 = Color3.new(1,1,1)
	runBtn.TextSize = 11
	runBtn.Font = Enum.Font.GothamBold
	runBtn.Parent = header

	local runCorner = Instance.new("UICorner")
	runCorner.CornerRadius = UDim.new(0, 6)
	runCorner.Parent = runBtn

	runBtn.MouseButton1Click:Connect(function()
		self:RunCode()
	end)

	-- AI Prompt (para AI Gen)
	local aiFrame = Instance.new("Frame")
	aiFrame.Name = "AIPromptFrame"
	aiFrame.Size = UDim2.new(1, -20, 0, 50)
	aiFrame.Position = UDim2.new(0, 10, 0, 50)
	aiFrame.BackgroundColor3 = Shell.Colors.background
	aiFrame.Visible = false
	aiFrame.Parent = parent

	local aiCorner = Instance.new("UICorner")
	aiCorner.CornerRadius = UDim.new(0, 6)
	aiCorner.Parent = aiFrame

	local aiLabel = Instance.new("TextLabel")
	aiLabel.Size = UDim2.new(0, 80, 1, 0)
	aiLabel.BackgroundTransparency = 1
	aiLabel.Text = "🤖 Prompt:"
	aiLabel.TextColor3 = Shell.Colors.text
	aiLabel.TextSize = 11
	aiLabel.Font = Enum.Font.GothamBold
	aiLabel.Parent = aiFrame

	local aiBox = Instance.new("TextBox")
	aiBox.Name = "AIPromptBox"
	aiBox.Size = UDim2.new(1, -160, 0, 30)
	aiBox.Position = UDim2.new(0, 80, 0, 10)
	aiBox.BackgroundColor3 = Shell.Colors.panelLight
	aiBox.PlaceholderText = "Ex: cria um sistema de moedas que gira e dá 10 coins"
	aiBox.Text = ""
	aiBox.TextColor3 = Shell.Colors.text
	aiBox.TextSize = 11
	aiBox.Font = Enum.Font.Gotham
	aiBox.ClearTextOnFocus = false
	aiBox.Parent = aiFrame

	local aiBoxCorner = Instance.new("UICorner")
	aiBoxCorner.CornerRadius = UDim.new(0, 4)
	aiBoxCorner.Parent = aiBox

	local aiGenBtn = Instance.new("TextButton")
	aiGenBtn.Size = UDim2.new(0, 60, 0, 30)
	aiGenBtn.Position = UDim2.new(1, -70, 0, 10)
	aiGenBtn.BackgroundColor3 = Shell.Colors.accent
	aiGenBtn.Text = "✨ Gerar"
	aiGenBtn.TextColor3 = Color3.new(1,1,1)
	aiGenBtn.TextSize = 11
	aiGenBtn.Font = Enum.Font.GothamBold
	aiGenBtn.Parent = aiFrame

	local aiGenCorner = Instance.new("UICorner")
	aiGenCorner.CornerRadius = UDim.new(0, 4)
	aiGenCorner.Parent = aiGenBtn

	aiGenBtn.MouseButton1Click:Connect(function()
		local prompt = aiBox.Text
		if prompt ~= "" then
			self:GenerateWithAI(prompt)
		end
	end)

	self.aiPromptBox = aiBox

	-- Editor principal (TextBox multilinha)
	local editorScroll = Instance.new("ScrollingFrame")
	editorScroll.Name = "EditorScroll"
	editorScroll.Size = UDim2.new(1, -20, 1, -110)
	editorScroll.Position = UDim2.new(0, 10, 0, 110)
	editorScroll.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	editorScroll.ScrollBarThickness = 6
	editorScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	editorScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	editorScroll.Parent = parent

	local editorBox = Instance.new("TextBox")
	editorBox.Name = "EditorBox"
	editorBox.Size = UDim2.new(1, -10, 1, 0)
	editorBox.BackgroundTransparency = 1
	editorBox.Text = self:GetDefaultCode(self.currentLanguage)
	editorBox.TextColor3 = Shell.Colors.text
	editorBox.TextSize = 12
	editorBox.Font = Enum.Font.Code
	editorBox.TextXAlignment = Enum.TextXAlignment.Left
	editorBox.TextYAlignment = Enum.TextYAlignment.Top
	editorBox.TextWrapped = false
	editorBox.MultiLine = true
	editorBox.ClearTextOnFocus = false
	editorBox.Parent = editorScroll

	self.editorBox = editorBox
	self.currentCode = editorBox.Text

	editorBox:GetPropertyChangedSignal("Text"):Connect(function()
		self.currentCode = editorBox.Text
	end)

	-- Output
	local output = Instance.new("TextLabel")
	output.Name = "Output"
	output.Size = UDim2.new(1, -20, 0, 60)
	output.Position = UDim2.new(0, 10, 1, -60)
	output.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	output.Text = "📤 Output: Pronto para rodar..."
	output.TextColor3 = Shell.Colors.textDim
	output.TextSize = 10
	output.Font = Enum.Font.Code
	output.TextXAlignment = Enum.TextXAlignment.Left
	output.TextYAlignment = Enum.TextYAlignment.Top
	output.TextWrapped = true
	output.Parent = parent

	local outputCorner = Instance.new("UICorner")
	outputCorner.CornerRadius = UDim.new(0, 4)
	outputCorner.Parent = output

	print("[Arkher ScriptEditor] Initialized - Language:", self.currentLanguage, "- Python 3.14 supported")
end

function ScriptEditor:GetDefaultCode(langId: string): string
	local lang = LanguageSupport.GetLanguage(langId :: any)
	return lang and lang.example or "-- Código aqui"
end

function ScriptEditor:SetLanguage(langId: string)
	self.currentLanguage = langId
	print("[Arkher ScriptEditor] Language ->", langId)

	if self.editorBox then
		self.editorBox.Text = self:GetDefaultCode(langId)
		self.currentCode = self.editorBox.Text
	end

	-- Mostra/esconde AI prompt
	if self.frame then
		local aiFrame = self.frame:FindFirstChild("AIPromptFrame")
		if aiFrame then
			aiFrame.Visible = langId == "ai"
		end

		local editorScroll = self.frame:FindFirstChild("EditorScroll")
		if editorScroll then
			if langId == "ai" then
				editorScroll.Position = UDim2.new(0, 10, 0, 110)
				editorScroll.Size = UDim2.new(1, -20, 1, -110)
			else
				editorScroll.Position = UDim2.new(0, 10, 0, 50)
				editorScroll.Size = UDim2.new(1, -20, 1, -110)
			end
		end
	end
end

function ScriptEditor:RunCode()
	if not self.editorBox or not self.frame then return end

	local output = self.frame:FindFirstChild("Output") :: TextLabel
	if output then
		output.Text = "⏳ Rodando " .. self.currentLanguage .. "..."
	end

	print("[Arkher ScriptEditor] Running", self.currentLanguage, "-", #self.currentCode, "bytes")

	task.spawn(function()
		local success, result, err

		if self.currentLanguage == "luau" then
			-- Roda Luau direto
			local func, loadErr = loadstring(self.currentCode)
			if not func then
				if output then output.Text = "❌ Erro Luau: " .. tostring(loadErr) end
				return
			end

			success, result = pcall(func)
			if success then
				if output then output.Text = "✅ Luau executado com sucesso!" end
			else
				if output then output.Text = "❌ Erro: " .. tostring(result) end
			end

		elseif self.currentLanguage == "python" then
			-- Transpila Python 3.14 -> Luau e roda
			if self.pythonService then
				local out, pyErr = self.pythonService:Execute(self.currentCode)
				if out then
					if output then output.Text = "✅ Python 3.14 (via Luau): " .. out end
				else
					if output then output.Text = "❌ Python erro: " .. tostring(pyErr) end
				end
			else
				if output then output.Text = "❌ PythonService não inicializado" end
			end

		elseif self.currentLanguage == "visual" then
			if output then output.Text = "🧩 Visual Scripting - Fase 2 - Blocos ainda não implementados, mas estrutura pronta" end

		elseif self.currentLanguage == "ai" then
			if output then output.Text = "🤖 AI Gen - Use o prompt acima e clique Gerar" end
		end
	end)
end

function ScriptEditor:GenerateWithAI(prompt: string)
	if not self.editorBox or not self.frame then return end

	local output = self.frame:FindFirstChild("Output") :: TextLabel
	if output then
		output.Text = "🤖 IA gerando código para: " .. prompt .. "..."
	end

	print("[Arkher ScriptEditor] AI Generate - Prompt:", prompt, "- Language:", self.currentLanguage)

	task.spawn(function()
		-- Em produção chama backend /api/ai/generate ou /api/python/generate

		-- Mock: gera código baseado no prompt e linguagem atual
		local generated = ""

		if string.find(string.lower(prompt), "moeda") or string.find(string.lower(prompt), "coin") then
			if self.currentLanguage == "python" or self.currentLanguage == "ai" then
				generated = self.pythonService and self.pythonService:GenerateFromPrompt(prompt, "realistic") or "# Python coin system"
			else
				generated = [[
-- Gerado por Arkher AI - Prompt: ]] .. prompt .. [[
local coin = script.Parent

local function onTouch(hit)
    local player = game.Players:GetPlayerFromCharacter(hit.Parent)
    if player then
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local coins = leaderstats:FindFirstChild("Coins")
            if coins then
                coins.Value += 10
                print("Deu 10 coins para " .. player.Name)
                coin:Destroy()
            end
        end
    end
end

game:GetService("RunService").Heartbeat:Connect(function(dt)
    coin.CFrame *= CFrame.Angles(0, math.rad(100) * dt, 0)
end)

coin.Touched:Connect(onTouch)
]]
			end
		else
			generated = "-- Gerado por Arkher AI para: " .. prompt .. "\nprint('Hello from AI: " .. prompt .. "')"
		end

		task.wait(1) -- simula IA pensando

		if self.editorBox then
			self.editorBox.Text = generated
			self.currentCode = generated
		end

		if output then
			output.Text = "✅ IA gerou código! Clique ▶ Run para testar"
		end

		print("[Arkher ScriptEditor] AI generated", #generated, "bytes for prompt:", prompt)
	end)
end

return ScriptEditor

--!strict
-- Arkher Studio - Fase 2 - ScriptEditor Pro - Monaco + Visual + Python 3.14 + AI + Debugger + Sandbox

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LanguageSupport = require(ReplicatedStorage.Arkher.Scripting.LanguageSupport)
local MonacoEditor = require(script.Parent.MonacoEditor)
local VisualScripting = require(script.Parent.VisualScripting)
local SandboxVM = require(ReplicatedStorage.Arkher.Scripting.SandboxVM)
local Debugger = require(script.Parent.Debugger)
local Shell = require(script.Parent.Parent.UI.Shell)

local ScriptEditor = {}
ScriptEditor.__index = ScriptEditor

function ScriptEditor.new(pythonService: any)
	return setmetatable({
		pythonService = pythonService,
		sandbox = SandboxVM.new(),
		currentLanguage = "luau" :: string,
		frame = nil :: Frame?,
		monaco = nil :: any,
		visual = nil :: any,
		debugger = nil :: any,
		aiPromptBox = nil :: TextBox?,
		editorContainer = nil :: Frame?,
	}, ScriptEditor)
end

function ScriptEditor:Init(parent: Frame)
	self.frame = parent

	local header = Instance.new("Frame")
	header.Name = "ScriptHeader"
	header.Size = UDim2.new(1, 0, 0, 40)
	header.BackgroundColor3 = Shell.Colors.panelLight
	header.Parent = parent

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 120, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Script Script Pro"
	title.TextColor3 = Shell.Colors.text
	title.TextSize = 11
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local languages = {
		{ id = "luau", name = " Luau", color = Shell.Colors.accent },
		{ id = "python", name = "Python Python 3.14", color = Color3.fromRGB(55, 118, 171) },
		{ id = "visual", name = " Visual", color = Color3.fromRGB(0, 200, 100) },
		{ id = "ai", name = "AI AI Gen", color = Color3.fromRGB(255, 180, 0) },
	}

	for i, lang in languages do
		local btn = Instance.new("TextButton")
		btn.Name = lang.id .. "Btn"
		btn.Size = UDim2.new(0, 90, 0, 28)
		btn.Position = UDim2.new(0, 130 + (i-1)*95, 0, 6)
		btn.BackgroundColor3 = lang.id == self.currentLanguage and lang.color or Shell.Colors.panel
		btn.Text = lang.name
		btn.TextColor3 = Shell.Colors.text
		btn.TextSize = 9
		btn.Font = Enum.Font.Gotham
		btn.Parent = header

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			self:SetLanguage(lang.id)
			for _, other in header:GetChildren() do
				if other:IsA("TextButton") and other.Name:find("Btn") and other.Name ~= "RunBtn" then
					other.BackgroundColor3 = Shell.Colors.panel
				end
			end
			btn.BackgroundColor3 = lang.color
		end)
	end

	local runBtn = Instance.new("TextButton")
	runBtn.Name = "RunBtn"
	runBtn.Size = UDim2.new(0, 60, 0, 28)
	runBtn.Position = UDim2.new(1, -70, 0, 6)
	runBtn.BackgroundColor3 = Shell.Colors.success
	runBtn.Text = "Play Run"
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
	aiLabel.Text = "AI Prompt:"
	aiLabel.TextColor3 = Shell.Colors.text
	aiLabel.TextSize = 11
	aiLabel.Font = Enum.Font.GothamBold
	aiLabel.Parent = aiFrame

	local aiBox = Instance.new("TextBox")
	aiBox.Name = "AIPromptBox"
	aiBox.Size = UDim2.new(1, -160, 0, 30)
	aiBox.Position = UDim2.new(0, 80, 0, 10)
	aiBox.BackgroundColor3 = Shell.Colors.panelLight
	aiBox.PlaceholderText = "Ex: cria moeda que gira e dá 10 coins (IA ajuda em Luau/Python/Visual)"
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
	aiGenBtn.Text = "Format Gerar"
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

	local editorContainer = Instance.new("Frame")
	editorContainer.Name = "EditorContainer"
	editorContainer.Size = UDim2.new(1, -20, 0.6, -20)
	editorContainer.Position = UDim2.new(0, 10, 0, 50)
	editorContainer.BackgroundTransparency = 1
	editorContainer.Parent = parent

	self.editorContainer = editorContainer

	local monacoFrame = Instance.new("Frame")
	monacoFrame.Name = "MonacoFrame"
	monacoFrame.Size = UDim2.new(1, 0, 1, 0)
	monacoFrame.BackgroundTransparency = 1
	monacoFrame.Parent = editorContainer

	self.monaco = MonacoEditor.new(self.currentLanguage)
	self.monaco:Init(monacoFrame, self:GetDefaultCode(self.currentLanguage))

	local visualFrame = Instance.new("Frame")
	visualFrame.Name = "VisualFrame"
	visualFrame.Size = UDim2.new(1, 0, 1, 0)
	visualFrame.BackgroundTransparency = 1
	visualFrame.Visible = false
	visualFrame.Parent = editorContainer

	self.visual = VisualScripting.new()
	self.visual:Init(visualFrame)

	local debuggerFrame = Instance.new("Frame")
	debuggerFrame.Name = "DebuggerFrame"
	debuggerFrame.Size = UDim2.new(1, -20, 0.4, -10)
	debuggerFrame.Position = UDim2.new(0, 10, 0.6, 50)
	debuggerFrame.BackgroundTransparency = 1
	debuggerFrame.Parent = parent

	self.debugger = Debugger.new()
	self.debugger:Init(debuggerFrame)

	print("[Arkher ScriptEditor Pro] Initialized - Monaco VS Code + Visual Blockly + Python 3.14 + Sandbox + Debugger - Fase 2")
end

function ScriptEditor:GetDefaultCode(langId: string): string
	local lang = LanguageSupport.GetLanguage(langId :: any)
	return lang and lang.example or "-- Código aqui"
end

function ScriptEditor:SetLanguage(langId: string)
	self.currentLanguage = langId
	print("[Arkher ScriptEditor] Language ->", langId)

	if self.editorContainer then
		local monacoFrame = self.editorContainer:FindFirstChild("MonacoFrame")
		local visualFrame = self.editorContainer:FindFirstChild("VisualFrame")

		if langId == "visual" then
			if monacoFrame then monacoFrame.Visible = false end
			if visualFrame then visualFrame.Visible = true end
		else
			if monacoFrame then monacoFrame.Visible = true end
			if visualFrame then visualFrame.Visible = false end

			if self.monaco then
				self.monaco:SetLanguage(langId)
				self.monaco:SetCode(self:GetDefaultCode(langId))
			end
		end
	end

	if self.frame then
		local aiFrame = self.frame:FindFirstChild("AIPromptFrame")
		if aiFrame then
			aiFrame.Visible = langId == "ai"

			if self.editorContainer then
				if langId == "ai" then
					self.editorContainer.Position = UDim2.new(0, 10, 0, 110)
					self.editorContainer.Size = UDim2.new(1, -20, 0.6, -20)
				else
					self.editorContainer.Position = UDim2.new(0, 10, 0, 50)
					self.editorContainer.Size = UDim2.new(1, -20, 0.6, -20)
				end
			end
		end
	end
end

function ScriptEditor:RunCode()
	if not self.monaco or not self.debugger then return end

	local code = ""

	if self.currentLanguage == "visual" then
		if self.visual then
			code = self.visual:GenerateCode()
		end
	else
		code = self.monaco:GetCode()
	end

	print("[Arkher ScriptEditor] Running", self.currentLanguage, "-", #code, "bytes")

	self.debugger:Log("Rodando " .. self.currentLanguage .. " - " .. #code .. " bytes", "info", "Editor")

	task.spawn(function()
		if self.currentLanguage == "luau" then
			local result = self.sandbox:ExecuteWithResult(code, game.Players.LocalPlayer)

			for _, log in result.logs do
				self.debugger:Log(log, "info", "Luau")
			end

			if result.success then
				self.debugger:LogSuccess("Luau executado com sucesso!", "Luau")
			else
				self.debugger:LogError(result.error or "Unknown error", "Luau")
			end

		elseif self.currentLanguage == "python" then
			if self.pythonService then
				local luauCode, err = self.pythonService:TranspileLocal(code)

				if not luauCode then
					self.debugger:LogError("Transpile falhou: " .. tostring(err), "Python 3.14")
					return
				end

				self.debugger:Log("Transpilado Python -> Luau - " .. #luauCode .. " bytes", "info", "Python 3.14")

				local result = self.sandbox:ExecuteWithResult(luauCode, game.Players.LocalPlayer)

				for _, log in result.logs do
					self.debugger:Log(log, "info", "Python 3.14")
				end

				if result.success then
					self.debugger:LogSuccess("Python 3.14 executado via Luau Sandbox!", "Python 3.14")
				else
					self.debugger:LogError(result.error or "Python error", "Python 3.14")
				end
			end

		elseif self.currentLanguage == "visual" then
			local result = self.sandbox:ExecuteWithResult(code, game.Players.LocalPlayer)

			for _, log in result.logs do
				self.debugger:Log(log, "info", "Visual")
			end

			if result.success then
				self.debugger:LogSuccess("Visual script executado!", "Visual Blockly")
			else
				self.debugger:LogError(result.error or "Visual error", "Visual")
			end

		elseif self.currentLanguage == "ai" then
			self.debugger:Log("Modo AI Gen - Use prompt acima e clique Gerar", "warn", "AI")
		end
	end)
end

function ScriptEditor:GenerateWithAI(prompt: string)
	if not self.monaco or not self.debugger then return end

	self.debugger:Log("IA gerando código para: " .. prompt, "info", "AI")

	task.spawn(function()
		local generated = ""
		local lowerPrompt = string.lower(prompt)

		if string.find(lowerPrompt, "moeda") or string.find(lowerPrompt, "coin") then
			if self.currentLanguage == "python" or self.currentLanguage == "ai" then
				generated = self.pythonService and self.pythonService:GenerateFromPrompt(prompt, "realistic") or "# Python coin system"
			else
				generated = string.format([[
-- Gerado por Arkher AI - Prompt: %s
-- IA ajuda em tudo: modelo, anim, terreno, script - Fase 2 com Sandbox seguro

local coin = script.Parent
local Players = game:GetService("Players")

local function onTouch(hit)
    local player = Players:GetPlayerFromCharacter(hit.Parent)
    if player then
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local coins = leaderstats:FindFirstChild("Coins")
            if coins then
                coins.Value += 10
                print("Deu 10 coins para " .. player.Name)
                local sparkle = Instance.new("ParticleEmitter")
                sparkle.Parent = coin
                task.wait(0.2)
                coin:Destroy()
            end
        end
    end
end

game:GetService("RunService").Heartbeat:Connect(function(dt)
    coin.CFrame *= CFrame.Angles(0, math.rad(100) * dt, 0)
end)

coin.Touched:Connect(onTouch)
print("Moeda criada por Arkher AI - Prompt: %s - Sandbox seguro")
]], prompt, prompt)
			end
		elseif string.find(lowerPrompt, "carro") or string.find(lowerPrompt, "car") then
			generated = [[
-- Gerado por Arkher AI - Sistema de carro com Python 3.14 + Luau - Fase 2
-- Prompt: ]] .. prompt .. [[

from arkher import Entity, Component, World

def create_car_system():
    car = Entity.new("SportsCar")
    car.add_component(Component.Transform(position=Vector3(0,5,0)))
    car.add_component(Component.Render(material="Metal", color=Color3.from_rgb(255,0,0)))
    car.add_component(Component.Physics(bodyType="dynamic", mass=1500))
    World.current().add_entity(car)
    print(f"Criado {car.name} com física realista!")

create_car_system()
]]
		else
			if self.currentLanguage == "python" then
				generated = string.format([[
# Gerado por Arkher AI - Python 3.14 - Fase 2 Sandbox
# Prompt: %s

from arkher import Entity, Component, World

def main():
    print(f"Executando: %s")
    world = World.current()
    print(f"Mundo tem {len(world.entities)} entidades - 15GB support")

if __name__ == "__main__":
    main()
]], prompt, prompt)
			else
				generated = "-- Gerado por Arkher AI para: " .. prompt .. "\nprint('Hello from AI Fase 2: " .. prompt .. "')\n-- IA ajuda em tudo: modelo, terreno, anim, script - Sandbox seguro"
			end
		end

		task.wait(1.2)

		if self.monaco then
			self.monaco:SetCode(generated)
		end

		self.debugger:LogSuccess("IA gerou " .. #generated .. " bytes! Clique Play Run - Sandbox seguro", "AI")

		print("[Arkher ScriptEditor] AI generated", #generated, "bytes for:", prompt)
	end)
end

function ScriptEditor:GetCode(): string
	if self.currentLanguage == "visual" and self.visual then
		return self.visual:GenerateCode()
	elseif self.monaco then
		return self.monaco:GetCode()
	else
		return ""
	end
end

return ScriptEditor

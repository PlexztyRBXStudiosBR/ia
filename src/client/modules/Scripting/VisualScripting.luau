--!strict
-- Arkher Studio - Fase 2 - VisualScripting - Blockly-like drag-drop
-- Perfeito para mobile, A01, crianças - Inspirado no Scratch + Unreal Blueprints

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shell = require(script.Parent.Parent.UI.Shell)

local VisualScripting = {}
VisualScripting.__index = VisualScripting

-- Definição de blocos (igual Blockly)
VisualScripting.Blocks = {
	-- Events
	when_player_touches = {
		name = "Quando jogador toca",
		category = "Events",
		color = Color3.fromRGB(255, 191, 0),
		inputs = { object = "Object" },
		outputs = {},
		code = function(inputs) return string.format("script.Parent.Touched:Connect(function(hit) -- %s", inputs.object or "object") end,
	},
	when_game_starts = {
		name = "Quando jogo começa",
		category = "Events",
		color = Color3.fromRGB(255, 191, 0),
		inputs = {},
		code = function() return "game.Players.PlayerAdded:Connect(function(player)" end,
	},

	-- Actions
	give_coins = {
		name = "Dar moedas",
		category = "Actions",
		color = Color3.fromRGB(0, 200, 100),
		inputs = { amount = "Number" },
		code = function(inputs) return string.format("    local leaderstats = player:FindFirstChild('leaderstats'); if leaderstats then leaderstats.Coins.Value += %s end", inputs.amount or "10") end,
	},
	play_sound = {
		name = "Tocar som",
		category = "Actions",
		color = Color3.fromRGB(0, 200, 100),
		inputs = { sound = "String" },
		code = function(inputs) return string.format("    local sound = Instance.new('Sound'); sound.SoundId = '%s'; sound:Play()", inputs.sound or "") end,
	},
	spawn_object = {
		name = "Spawnar objeto",
		category = "Actions",
		color = Color3.fromRGB(0, 200, 100),
		inputs = { object = "String", position = "Vector3" },
		code = function(inputs) return string.format("    local obj = game.ReplicatedStorage:FindFirstChild('%s'):Clone(); obj.Position = %s; obj.Parent = workspace", inputs.object or "Part", inputs.position or "Vector3.new(0,5,0)") end,
	},
	destroy_object = {
		name = "Destruir objeto",
		category = "Actions",
		color = Color3.fromRGB(255, 60, 60),
		inputs = { object = "Object" },
		code = function(inputs) return string.format("    %s:Destroy()", inputs.object or "script.Parent") end,
	},

	-- Logic
	if_condition = {
		name = "Se",
		category = "Logic",
		color = Color3.fromRGB(86, 156, 214),
		inputs = { condition = "Boolean" },
		code = function(inputs) return string.format("if %s then", inputs.condition or "true") end,
	},
	repeat_times = {
		name = "Repetir X vezes",
		category = "Logic",
		color = Color3.fromRGB(86, 156, 214),
		inputs = { times = "Number" },
		code = function(inputs) return string.format("for i=1,%s do", inputs.times or "10") end,
	},

	-- Values
	number = {
		name = "Número",
		category = "Values",
		color = Color3.fromRGB(181, 206, 168),
		inputs = { value = "Number" },
		output = "Number",
		code = function(inputs) return inputs.value or "0" end,
	},
	text = {
		name = "Texto",
		category = "Values",
		color = Color3.fromRGB(206, 145, 120),
		inputs = { value = "String" },
		output = "String",
		code = function(inputs) return string.format("\"%s\"", inputs.value or "") end,
	},
}

function VisualScripting.new()
	return setmetatable({
		blocks = {} :: { any },
		connections = {} :: { any },
		frame = nil :: Frame?,
		palette = nil :: ScrollingFrame?,
		canvas = nil :: Frame?,
		selectedBlockId = nil :: string?,
	}, VisualScripting)
end

function VisualScripting:Init(parent: Frame)
	self.frame = parent

	-- Layout: Palette esquerda (blocos disponíveis), Canvas centro (onde arrasta)

	-- Palette
	local palette = Instance.new("ScrollingFrame")
	palette.Name = "BlockPalette"
	palette.Size = UDim2.new(0, 150, 1, 0)
	palette.BackgroundColor3 = Shell.Colors.panel
	palette.ScrollBarThickness = 4
	palette.CanvasSize = UDim2.new(0, 0, 0, 0)
	palette.AutomaticCanvasSize = Enum.AutomaticSize.Y
	palette.Parent = parent

	local paletteLayout = Instance.new("UIListLayout")
	paletteLayout.SortOrder = Enum.SortOrder.LayoutOrder
	paletteLayout.Padding = UDim.new(0, 5)
	paletteLayout.Parent = palette

	self.palette = palette

	-- Canvas
	local canvas = Instance.new("Frame")
	canvas.Name = "BlockCanvas"
	canvas.Size = UDim2.new(1, -160, 1, 0)
	canvas.Position = UDim2.new(0, 160, 0, 0)
	canvas.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	canvas.BorderSizePixel = 0
	canvas.ClipsDescendants = true
	canvas.Parent = parent

	local canvasCorner = Instance.new("UICorner")
	canvasCorner.CornerRadius = UDim.new(0, 6)
	canvasCorner.Parent = canvas

	-- Grid de fundo (pontilhado)
	local grid = Instance.new("ImageLabel")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, 0, 1, 0)
	grid.BackgroundTransparency = 1
	grid.Image = "rbxassetid://0" -- placeholder grid
	grid.ImageTransparency = 0.9
	grid.Parent = canvas

	self.canvas = canvas

	-- Popula palette com blocos
	self:PopulatePalette()

	-- Botão Gerar Código Luau/Python
	local genBtn = Instance.new("TextButton")
	genBtn.Name = "GenerateBtn"
	genBtn.Size = UDim2.new(0, 120, 0, 32)
	genBtn.Position = UDim2.new(1, -130, 1, -40)
	genBtn.BackgroundColor3 = Shell.Colors.accent
	genBtn.Text = "✨ Gerar Código"
	genBtn.TextColor3 = Color3.new(1,1,1)
	genBtn.TextSize = 11
	genBtn.Font = Enum.Font.GothamBold
	genBtn.ZIndex = 10
	genBtn.Parent = parent

	local genCorner = Instance.new("UICorner")
	genCorner.CornerRadius = UDim.new(0, 6)
	genCorner.Parent = genBtn

	genBtn.MouseButton1Click:Connect(function()
		local code = self:GenerateCode()
		print("[Arkher Visual] Generated code:\n", code)
		-- Em produção, manda para MonacoEditor
	end)

	print("[Arkher Visual] Initialized - Blockly-like -", #self:GetAllBlockTypes(), "block types")
end

function VisualScripting:GetAllBlockTypes(): { string }
	local types = {}
	for name, _ in VisualScripting.Blocks do
		table.insert(types, name)
	end
	return types
end

function VisualScripting:PopulatePalette()
	if not self.palette then return end

	-- Agrupa por categoria
	local byCategory: { [string]: { string } } = {}

	for blockType, def in VisualScripting.Blocks do
		local cat = def.category
		if not byCategory[cat] then byCategory[cat] = {} end
		table.insert(byCategory[cat], blockType)
	end

	for category, blockTypes in byCategory do
		-- Header categoria
		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, 0, 0, 24)
		header.BackgroundColor3 = Shell.Colors.background
		header.Text = "  " .. category
		header.TextColor3 = Shell.Colors.text
		header.TextSize = 11
		header.Font = Enum.Font.GothamBold
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Parent = self.palette

		for _, blockType in blockTypes do
			local def = VisualScripting.Blocks[blockType]
			local btn = Instance.new("TextButton")
			btn.Name = blockType
			btn.Size = UDim2.new(1, -10, 0, 32)
			btn.BackgroundColor3 = def.color
			btn.Text = def.name
			btn.TextColor3 = Color3.new(1,1,1)
			btn.TextSize = 10
			btn.Font = Enum.Font.Gotham
			btn.Parent = self.palette

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0, 4)
			btnCorner.Parent = btn

			btn.MouseButton1Click:Connect(function()
				self:AddBlockToCanvas(blockType)
			end)
		end
	end
end

function VisualScripting:AddBlockToCanvas(blockType: string)
	if not self.canvas then return end

	local def = VisualScripting.Blocks[blockType]
	if not def then return end

	local blockId = game:GetService("HttpService"):GenerateGUID(false)

	local blockFrame = Instance.new("Frame")
	blockFrame.Name = "Block_" .. blockId
	blockFrame.Size = UDim2.new(0, 180, 0, 50)
	blockFrame.Position = UDim2.new(0, math.random(20, 200), 0, math.random(20, 200))
	blockFrame.BackgroundColor3 = def.color
	blockFrame.BorderSizePixel = 0
	blockFrame.Active = true
	blockFrame.Draggable = true
	blockFrame.Parent = self.canvas

	local blockCorner = Instance.new("UICorner")
	blockCorner.CornerRadius = UDim.new(0, 6)
	blockCorner.Parent = blockFrame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -10, 0, 20)
	label.Position = UDim2.new(0, 5, 0, 5)
	label.BackgroundTransparency = 1
	label.Text = def.name
	label.TextColor3 = Color3.new(1,1,1)
	label.TextSize = 11
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = blockFrame

	-- Inputs
	local yOffset = 25
	for inputName, inputType in def.inputs do
		local inputLabel = Instance.new("TextLabel")
		inputLabel.Size = UDim2.new(0, 60, 0, 16)
		inputLabel.Position = UDim2.new(0, 5, 0, yOffset)
		inputLabel.BackgroundTransparency = 1
		inputLabel.Text = inputName .. ":"
		inputLabel.TextColor3 = Color3.new(1,1,1)
		inputLabel.TextSize = 9
		inputLabel.Font = Enum.Font.Gotham
		inputLabel.TextXAlignment = Enum.TextXAlignment.Left
		inputLabel.Parent = blockFrame

		local inputBox = Instance.new("TextBox")
		inputBox.Name = "Input_" .. inputName
		inputBox.Size = UDim2.new(1, -70, 0, 16)
		inputBox.Position = UDim2.new(0, 65, 0, yOffset)
		inputBox.BackgroundColor3 = Color3.fromRGB(0,0,0)
		inputBox.BackgroundTransparency = 0.3
		inputBox.Text = inputType == "Number" and "10" or inputType == "String" and "Hello" or "object"
		inputBox.TextColor3 = Color3.new(1,1,1)
		inputBox.TextSize = 9
		inputBox.Font = Enum.Font.Code
		inputBox.ClearTextOnFocus = false
		inputBox.Parent = blockFrame

		yOffset += 18
	end

	blockFrame.Size = UDim2.new(0, 180, 0, yOffset + 5)

	-- Armazena
	table.insert(self.blocks, {
		id = blockId,
		type = blockType,
		frame = blockFrame,
		inputs = def.inputs,
	})

	print("[Arkher Visual] Added block", blockType, "to canvas -", blockId)

	-- Click para selecionar
	blockFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.selectedBlockId = blockId
			-- Highlight
			for _, b in self.blocks do
				if b.frame then
					b.frame.BorderSizePixel = 0
				end
			end
			blockFrame.BorderSizePixel = 2
			blockFrame.BorderColor3 = Color3.new(1,1,1)
		end
	end)
end

function VisualScripting:GenerateCode(): string
	-- Gera código Luau a partir dos blocos no canvas
	-- Fase 2 simples: concatena blocos na ordem que foram adicionados

	local code = "-- Generated by Arkher Visual Scripting (Blockly-like)\n-- Fase 2 - Drag & Drop blocks -> Luau/Python\n\n"

	for _, block in self.blocks do
		local def = VisualScripting.Blocks[block.type]
		if def and def.code then
			-- Pega inputs atuais
			local inputs = {}
			if block.frame then
				for inputName, _ in def.inputs do
					local inputBox = block.frame:FindFirstChild("Input_" .. inputName)
					if inputBox and inputBox:IsA("TextBox") then
						inputs[inputName] = inputBox.Text
					end
				end
			end

			local blockCode = def.code(inputs)
			code ..= blockCode .. "\n"
		end
	end

	code ..= "\n-- End of visual script\nprint('Visual script executed!')\n"

	print("[Arkher Visual] Generated", #code, "bytes from", #self.blocks, "blocks")

	return code
end

function VisualScripting:GeneratePythonCode(): string
	-- Gera Python ao invés de Luau
	local code = "# Generated by Arkher Visual Scripting -> Python 3.14\n# Fase 2\n\nfrom arkher import Entity, Component\n\n"

	for _, block in self.blocks do
		local def = VisualScripting.Blocks[block.type]
		if def then
			-- Conversão simples para Python
			if block.type == "give_coins" then
				code ..= "def give_coins(player, amount=10):\n    print(f'Giving {amount} coins to {player.Name}')\n\n"
			elseif block.type == "when_player_touches" then
				code ..= "def on_touch(hit):\n    player = hit.Parent\n    print(f'{player} touched!')\n\n"
			end
		end
	end

	return code
end

function VisualScripting:ClearCanvas()
	for _, block in self.blocks do
		if block.frame and block.frame.Parent then
			block.frame:Destroy()
		end
	end

	self.blocks = {}
	print("[Arkher Visual] Canvas cleared")
end

function VisualScripting:GetBlocks(): { any }
	return self.blocks
end

return VisualScripting

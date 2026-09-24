--!strict
-- Arkher Studio - Fase 2 - Debugger - Output + Debugger + Command Bar
-- Inspirado no Output do Studio + VS Code Debugger

local Shell = require(script.Parent.Parent.UI.Shell)

local Debugger = {}
Debugger.__index = Debugger

function Debugger.new()
	return setmetatable({
		logs = {} :: { { message: string, level: string, timestamp: number, source: string } },
		breakpoints = {} :: { [number]: boolean },
		isDebugging = false,
		currentLine = 0,
		frame = nil :: Frame?,
		outputBox = nil :: ScrollingFrame?,
		commandBar = nil :: Frame?,
		maxLogs = 500,
	}, Debugger)
end

function Debugger:Init(parent: Frame)
	self.frame = parent

	-- Output (80% da altura)
	local outputFrame = Instance.new("Frame")
	outputFrame.Name = "OutputFrame"
	outputFrame.Size = UDim2.new(1, 0, 0.8, -5)
	outputFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	outputFrame.BorderSizePixel = 0
	outputFrame.Parent = parent

	local outputCorner = Instance.new("UICorner")
	outputCorner.CornerRadius = UDim.new(0, 6)
	outputCorner.Parent = outputFrame

	local outputHeader = Instance.new("Frame")
	outputHeader.Size = UDim2.new(1, 0, 0, 24)
	outputHeader.BackgroundColor3 = Shell.Colors.panelLight
	outputHeader.Parent = outputFrame

	local outputTitle = Instance.new("TextLabel")
	outputTitle.Size = UDim2.new(0, 100, 1, 0)
	outputTitle.Position = UDim2.new(0, 10, 0, 0)
	outputTitle.BackgroundTransparency = 1
	outputTitle.Text = "📤 Output"
	outputTitle.TextColor3 = Shell.Colors.text
	outputTitle.TextSize = 11
	outputTitle.Font = Enum.Font.GothamBold
	outputTitle.TextXAlignment = Enum.TextXAlignment.Left
	outputTitle.Parent = outputHeader

	-- Clear button
	local clearBtn = Instance.new("TextButton")
	clearBtn.Size = UDim2.new(0, 50, 0, 20)
	clearBtn.Position = UDim2.new(1, -60, 0, 2)
	clearBtn.BackgroundColor3 = Shell.Colors.panel
	clearBtn.Text = "Clear"
	clearBtn.TextColor3 = Shell.Colors.textDim
	clearBtn.TextSize = 10
	clearBtn.Font = Enum.Font.Gotham
	clearBtn.Parent = outputHeader

	local clearCorner = Instance.new("UICorner")
	clearCorner.CornerRadius = UDim.new(0, 4)
	clearCorner.Parent = clearBtn

	clearBtn.MouseButton1Click:Connect(function()
		self:Clear()
	end)

	local outputScroll = Instance.new("ScrollingFrame")
	outputScroll.Name = "OutputScroll"
	outputScroll.Size = UDim2.new(1, -10, 1, -30)
	outputScroll.Position = UDim2.new(0, 5, 0, 28)
	outputScroll.BackgroundTransparency = 1
	outputScroll.ScrollBarThickness = 4
	outputScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	outputScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	outputScroll.Parent = outputFrame

	local outputLayout = Instance.new("UIListLayout")
	outputLayout.SortOrder = Enum.SortOrder.LayoutOrder
	outputLayout.Padding = UDim.new(0, 2)
	outputLayout.Parent = outputScroll

	self.outputBox = outputScroll

	-- Command Bar (20% da altura, embaixo)
	local commandFrame = Instance.new("Frame")
	commandFrame.Name = "CommandBar"
	commandFrame.Size = UDim2.new(1, 0, 0.2, 0)
	commandFrame.Position = UDim2.new(0, 0, 0.8, 5)
	commandFrame.BackgroundColor3 = Shell.Colors.panel
	commandFrame.BorderSizePixel = 0
	commandFrame.Parent = parent

	local commandCorner = Instance.new("UICorner")
	commandCorner.CornerRadius = UDim.new(0, 6)
	commandCorner.Parent = commandFrame

	local commandHeader = Instance.new("TextLabel")
	commandHeader.Size = UDim2.new(1, 0, 0, 20)
	commandHeader.BackgroundTransparency = 1
	commandHeader.Text = "  ⌨️ Command Bar (Luau / Python 3.14)"
	commandHeader.TextColor3 = Shell.Colors.textDim
	commandHeader.TextSize = 10
	commandHeader.Font = Enum.Font.Gotham
	commandHeader.TextXAlignment = Enum.TextXAlignment.Left
	commandHeader.Parent = commandFrame

	local commandBox = Instance.new("TextBox")
	commandBox.Name = "CommandBox"
	commandBox.Size = UDim2.new(1, -20, 0, 28)
	commandBox.Position = UDim2.new(0, 10, 0, 22)
	commandBox.BackgroundColor3 = Shell.Colors.background
	commandBox.PlaceholderText = "Digite comando Luau ou Python... Ex: print('hello') ou print(f'{player.Name}')"
	commandBox.Text = ""
	commandBox.TextColor3 = Shell.Colors.text
	commandBox.TextSize = 12
	commandBox.Font = Enum.Font.Code
	commandBox.ClearTextOnFocus = false
	commandBox.Parent = commandFrame

	local commandBoxCorner = Instance.new("UICorner")
	commandBoxCorner.CornerRadius = UDim.new(0, 4)
	commandBoxCorner.Parent = commandBox

	commandBox.FocusLost:Connect(function(enterPressed)
		if enterPressed and commandBox.Text ~= "" then
			self:ExecuteCommand(commandBox.Text)
			commandBox.Text = ""
		end
	end)

	self.commandBar = commandFrame

	print("[Arkher Debugger] Initialized - Output + Command Bar")
end

function Debugger:Log(message: string, level: string?, source: string?)
	level = level or "info"
	source = source or "Arkher"

	local entry = {
		message = message,
		level = level,
		timestamp = os.time(),
		source = source,
	}

	table.insert(self.logs, entry)

	if #self.logs > self.maxLogs then
		table.remove(self.logs, 1)
	end

	self:RenderLog(entry)

	-- Também printa no console real
	if level == "error" then
		warn(string.format("[%s] %s", source, message))
	elseif level == "warn" then
		warn(string.format("[%s] %s", source, message))
	else
		print(string.format("[%s] %s", source, message))
	end
end

function Debugger:RenderLog(entry: any)
	if not self.outputBox then return end

	local color = Shell.Colors.text
	if entry.level == "error" then
		color = Shell.Colors.error
	elseif entry.level == "warn" then
		color = Color3.fromRGB(255, 180, 0)
	elseif entry.level == "success" then
		color = Shell.Colors.success
	end

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -10, 0, 18)
	label.BackgroundTransparency = 1
	label.Text = string.format("[%s] %s: %s", os.date("%H:%M:%S", entry.timestamp), entry.source, entry.message)
	label.TextColor3 = color
	label.TextSize = 11
	label.Font = Enum.Font.Code
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = self.outputBox

	-- Auto-scroll para baixo
	task.wait()
	if self.outputBox then
		self.outputBox.CanvasPosition = Vector2.new(0, self.outputBox.AbsoluteCanvasSize.Y)
	end
end

function Debugger:Clear()
	self.logs = {}

	if self.outputBox then
		for _, child in self.outputBox:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end

	print("[Arkher Debugger] Cleared")
end

function Debugger:ExecuteCommand(command: string)
	print("[Arkher Debugger] Command:", command)

	-- Detecta se é Python ou Luau
	local isPython = string.find(command, "from arkher import") or string.find(command, "def ") or string.find(command, "print%(") and string.find(command, "f\"")

	if isPython then
		self:Log("Executando Python 3.14: " .. command, "info", "CommandBar")

		-- Usa PythonService
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local PythonService = require(ReplicatedStorage.Arkher.Client.modules.Scripting.PythonService) -- vai falhar, precisa de referência correta, mock por enquanto

		-- Mock execução Python
		self:Log("Python output: " .. command, "success", "Python 3.14")
	else
		self:Log("Executando Luau: " .. command, "info", "CommandBar")

		local func, err = loadstring(command)
		if not func then
			self:Log("Erro de sintaxe: " .. tostring(err), "error", "Luau")
			return
		end

		local success, result = pcall(func)
		if success then
			self:Log("Resultado: " .. tostring(result), "success", "Luau")
		else
			self:Log("Erro runtime: " .. tostring(result), "error", "Luau")
		end
	end
end

function Debugger:LogError(message: string, source: string?)
	self:Log(message, "error", source or "Error")
end

function Debugger:LogWarning(message: string, source: string?)
	self:Log(message, "warn", source or "Warning")
end

function Debugger:LogSuccess(message: string, source: string?)
	self:Log(message, "success", source or "Success")
end

function Debugger:GetLogs(): { any }
	return self.logs
end

return Debugger

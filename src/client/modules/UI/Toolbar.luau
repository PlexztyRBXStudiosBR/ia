--!strict
-- Arkher Studio - Fase 1 - Toolbar - Ferramentas de construção + materiais

local Shell = require(script.Parent.Shell)

local Toolbar = {}
Toolbar.__index = Toolbar

function Toolbar.new(buildingService: any)
	return setmetatable({
		buildingService = buildingService,
		frame = nil :: Frame?,
		currentTool = "Place",
	}, Toolbar)
end

function Toolbar:Init(parent: Frame)
	-- Parent é o viewport
	self.frame = parent

	-- Cria toolbar horizontal no topo do viewport
	local toolbar = Instance.new("Frame")
	toolbar.Name = "BuildToolbar"
	toolbar.Size = UDim2.new(1, -20, 0, 40)
	toolbar.Position = UDim2.new(0, 10, 0, 40)
	toolbar.BackgroundColor3 = Shell.Colors.panel
	toolbar.BorderSizePixel = 0
	toolbar.ZIndex = 5
	toolbar.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = toolbar

	-- Ferramentas
	local tools = {
		{ name = "Select", icon = "", mode = "Select", key = "Q" },
		{ name = "Move", icon = "Move", mode = "Move", key = "W" },
		{ name = "Place", icon = "", mode = "Place", key = "E" },
		{ name = "Paint", icon = "Style", mode = "Paint", key = "P" },
		{ name = "Delete", icon = "Delete", mode = "Delete", key = "Del" },
	}

	for i, tool in tools do
		local btn = Instance.new("TextButton")
		btn.Name = tool.name .. "Tool"
		btn.Size = UDim2.new(0, 70, 0, 32)
		btn.Position = UDim2.new(0, 10 + (i-1)*75, 0, 4)
		btn.BackgroundColor3 = tool.mode == self.currentTool and Shell.Colors.accent or Shell.Colors.panelLight
		btn.Text = tool.icon .. " " .. tool.name .. " [" .. tool.key .. "]"
		btn.TextColor3 = Shell.Colors.text
		btn.TextSize = 10
		btn.Font = Enum.Font.Gotham
		btn.Parent = toolbar

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			self:SetTool(tool.mode)

			-- Atualiza visual
			for _, other in toolbar:GetChildren() do
				if other:IsA("TextButton") then
					other.BackgroundColor3 = Shell.Colors.panelLight
				end
			end
			btn.BackgroundColor3 = Shell.Colors.accent
		end)
	end

	-- Separador
	local sep = Instance.new("Frame")
	sep.Size = UDim2.new(0, 2, 0, 24)
	sep.Position = UDim2.new(0, 10 + #tools*75 + 10, 0, 8)
	sep.BackgroundColor3 = Shell.Colors.border
	sep.BorderSizePixel = 0
	sep.Parent = toolbar

	-- Grid snap
	local snapLabel = Instance.new("TextLabel")
	snapLabel.Size = UDim2.new(0, 40, 0, 32)
	snapLabel.Position = UDim2.new(0, 10 + #tools*75 + 20, 0, 4)
	snapLabel.BackgroundTransparency = 1
	snapLabel.Text = "Grid:"
	snapLabel.TextColor3 = Shell.Colors.textDim
	snapLabel.TextSize = 10
	snapLabel.Font = Enum.Font.Gotham
	snapLabel.Parent = toolbar

	local snapValues = {1, 2, 4, 0.5}
	for i, snap in snapValues do
		local snapBtn = Instance.new("TextButton")
		snapBtn.Size = UDim2.new(0, 30, 0, 32)
		snapBtn.Position = UDim2.new(0, 10 + #tools*75 + 60 + (i-1)*35, 0, 4)
		snapBtn.BackgroundColor3 = snap == 1 and Shell.Colors.accent or Shell.Colors.panelLight
		snapBtn.Text = tostring(snap)
		snapBtn.TextColor3 = Shell.Colors.text
		snapBtn.TextSize = 10
		snapBtn.Font = Enum.Font.Gotham
		snapBtn.Parent = toolbar

		local snapCorner = Instance.new("UICorner")
		snapCorner.CornerRadius = UDim.new(0, 4)
		snapCorner.Parent = snapBtn

		snapBtn.MouseButton1Click:Connect(function()
			self.buildingService:SetGridSnap(snap)

			for _, other in toolbar:GetChildren() do
				if other.Name:find("Snap") or (other:IsA("TextButton") and tonumber(other.Text)) then
					other.BackgroundColor3 = Shell.Colors.panelLight
				end
			end
			snapBtn.BackgroundColor3 = Shell.Colors.accent
		end)
	end

	-- Undo/Redo
	local undoBtn = Instance.new("TextButton")
	undoBtn.Name = "UndoBtn"
	undoBtn.Size = UDim2.new(0, 50, 0, 32)
	undoBtn.Position = UDim2.new(1, -110, 0, 4)
	undoBtn.BackgroundColor3 = Shell.Colors.panelLight
	undoBtn.Text = "Undo Undo"
	undoBtn.TextColor3 = Shell.Colors.text
	undoBtn.TextSize = 10
	undoBtn.Font = Enum.Font.Gotham
	undoBtn.Parent = toolbar

	local undoCorner = Instance.new("UICorner")
	undoCorner.CornerRadius = UDim.new(0, 6)
	undoCorner.Parent = undoBtn

	undoBtn.MouseButton1Click:Connect(function()
		self.buildingService:Undo()
	end)

	local redoBtn = Instance.new("TextButton")
	redoBtn.Name = "RedoBtn"
	redoBtn.Size = UDim2.new(0, 50, 0, 32)
	redoBtn.Position = UDim2.new(1, -55, 0, 4)
	redoBtn.BackgroundColor3 = Shell.Colors.panelLight
	redoBtn.Text = "Redo Redo"
	redoBtn.TextColor3 = Shell.Colors.text
	redoBtn.TextSize = 10
	redoBtn.Font = Enum.Font.Gotham
	redoBtn.Parent = toolbar

	local redoCorner = Instance.new("UICorner")
	redoCorner.CornerRadius = UDim.new(0, 6)
	redoCorner.Parent = redoBtn

	redoBtn.MouseButton1Click:Connect(function()
		self.buildingService:Redo()
	end)

	print("[Arkher Toolbar] Initialized with", #tools, "tools")
end

function Toolbar:SetTool(mode: string)
	self.currentTool = mode
	self.buildingService:SetMode(mode :: any)
	print("[Arkher Toolbar] Tool ->", mode)
end

return Toolbar

--!strict
-- Arkher Studio - Fase 3 - ModelerController - Controla modelador completo nível Blender

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshData = require(ReplicatedStorage.Arkher.Modeling.MeshData)
local EditableMeshEditor = require(script.Parent.EditableMeshEditor)
local Modifiers = require(script.Parent.Modifiers)
local SculptMode = require(script.Parent.SculptMode)
local Shell = require(script.Parent.Parent.UI.Shell)

local ModelerController = {}
ModelerController.__index = ModelerController

function ModelerController.new()
	return setmetatable({
		editor = EditableMeshEditor.new(),
		modifiers = Modifiers.new(),
		sculpt = SculptMode.new(),
		currentMesh = nil :: any,
		frame = nil :: Frame?,
		isActive = false,
	}, ModelerController)
end

function ModelerController:Init(parent: Frame)
	self.frame = parent

	-- Cria 3 abas: Modeling, Modifiers, Sculpt

	local tabBar = Instance.new("Frame")
	tabBar.Name = "ModelerTabBar"
	tabBar.Size = UDim2.new(1, 0, 0, 32)
	tabBar.BackgroundColor3 = Shell.Colors.panelLight
	tabBar.Parent = parent

	local tabs = {
		{ id = "Modeling", name = "Style Modeling", color = Shell.Colors.accent },
		{ id = "Modifiers", name = "Tools Modifiers", color = Color3.fromRGB(0, 200, 100) },
		{ id = "Sculpt", name = "Sculpt Sculpt", color = Color3.fromRGB(200, 100, 0) },
	}

	local contentFrames: { [string]: Frame } = {}

	for i, tab in tabs do
		local btn = Instance.new("TextButton")
		btn.Name = tab.id .. "Tab"
		btn.Size = UDim2.new(0, 100, 0, 24)
		btn.Position = UDim2.new(0, 10 + (i-1)*105, 0, 4)
		btn.BackgroundColor3 = i == 1 and tab.color or Shell.Colors.panel
		btn.Text = tab.name
		btn.TextColor3 = Shell.Colors.text
		btn.TextSize = 10
		btn.Font = Enum.Font.GothamBold
		btn.Parent = tabBar

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn

		local content = Instance.new("Frame")
		content.Name = tab.id .. "Content"
		content.Size = UDim2.new(1, 0, 1, -32)
		content.Position = UDim2.new(0, 0, 0, 32)
		content.BackgroundTransparency = 1
		content.Visible = i == 1
		content.Parent = parent

		contentFrames[tab.id] = content

		btn.MouseButton1Click:Connect(function()
			for id, frame in contentFrames do
				frame.Visible = id == tab.id
			end

			for _, other in tabBar:GetChildren() do
				if other:IsA("TextButton") then
					other.BackgroundColor3 = Shell.Colors.panel
				end
			end
			btn.BackgroundColor3 = tab.color

			print("[Arkher ModelerController] Tab ->", tab.id)
		end)
	end

	-- Inicializa cada aba
	self.editor:Init(contentFrames["Modeling"])
	self:InitModifiersTab(contentFrames["Modifiers"])
	self.sculpt:Init(contentFrames["Sculpt"])

	-- Export button (sempre visível, no topo)
	local exportBtn = Instance.new("TextButton")
	exportBtn.Name = "ExportBtn"
	exportBtn.Size = UDim2.new(0, 120, 0, 24)
	exportBtn.Position = UDim2.new(1, -130, 0, 4)
	exportBtn.BackgroundColor3 = Shell.Colors.success
	exportBtn.Text = "Publish Export ID Real"
	exportBtn.TextColor3 = Color3.new(1,1,1)
	exportBtn.TextSize = 10
	exportBtn.Font = Enum.Font.GothamBold
	exportBtn.Parent = tabBar

	local exportCorner = Instance.new("UICorner")
	exportCorner.CornerRadius = UDim.new(0, 4)
	exportCorner.Parent = exportBtn

	exportBtn.MouseButton1Click:Connect(function()
		self:Export()
	end)

	self.isActive = true

	print("[Arkher ModelerController] Initialized - Modeling + Modifiers + Sculpt - Blender level - Fase 3")
end

function ModelerController:InitModifiersTab(parent: Frame)
	-- Lista modifiers + botão add

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 24)
	header.BackgroundTransparency = 1
	header.Text = "  Tools Modifiers Stack - Blender style - Mirror, Subdivision, Array, etc"
	header.TextColor3 = Shell.Colors.text
	header.TextSize = 11
	header.Font = Enum.Font.GothamBold
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = parent

	local addBar = Instance.new("Frame")
	addBar.Size = UDim2.new(1, -20, 0, 36)
	addBar.Position = UDim2.new(0, 10, 0, 30)
	addBar.BackgroundColor3 = Shell.Colors.panel
	addBar.Parent = parent

	local addCorner = Instance.new("UICorner")
	addCorner.CornerRadius = UDim.new(0, 4)
	addCorner.Parent = addBar

	local mods = {"Mirror", "Subdivision", "Array", "Solidify", "Bevel", "Decimate"}

	for i, modType in mods do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 80, 0, 26)
		btn.Position = UDim2.new(0, 5 + (i-1)*85, 0, 5)
		btn.BackgroundColor3 = Shell.Colors.panelLight
		btn.Text = "Add " .. modType
		btn.TextColor3 = Shell.Colors.text
		btn.TextSize = 9
		btn.Font = Enum.Font.Gotham
		btn.Parent = addBar

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 4)
		btnCorner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			self.modifiers:AddModifier(modType :: any)
			self:RefreshModifiersList(parent)
		end)
	end

	-- Lista stack
	local stackList = Instance.new("ScrollingFrame")
	stackList.Name = "ModifiersStack"
	stackList.Size = UDim2.new(1, -20, 1, -70)
	stackList.Position = UDim2.new(0, 10, 0, 70)
	stackList.BackgroundColor3 = Shell.Colors.background
	stackList.ScrollBarThickness = 4
	stackList.CanvasSize = UDim2.new(0, 0, 0, 0)
	stackList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	stackList.Parent = parent

	local stackCorner = Instance.new("UICorner")
	stackCorner.CornerRadius = UDim.new(0, 4)
	stackCorner.Parent = stackList

	local stackLayout = Instance.new("UIListLayout")
	stackLayout.Padding = UDim.new(0, 5)
	stackLayout.Parent = stackList

	-- Apply button
	local applyBtn = Instance.new("TextButton")
	applyBtn.Name = "ApplyStackBtn"
	applyBtn.Size = UDim2.new(1, -20, 0, 32)
	applyBtn.Position = UDim2.new(0, 10, 1, -40)
	applyBtn.BackgroundColor3 = Shell.Colors.accent
	applyBtn.Text = "Success Apply Modifiers Stack"
	applyBtn.TextColor3 = Color3.new(1,1,1)
	applyBtn.TextSize = 11
	applyBtn.Font = Enum.Font.GothamBold
	applyBtn.Parent = parent

	local applyCorner = Instance.new("UICorner")
	applyCorner.CornerRadius = UDim.new(0, 6)
	applyCorner.Parent = applyBtn

	applyBtn.MouseButton1Click:Connect(function()
		self:ApplyModifiers()
	end)
end

function ModelerController:RefreshModifiersList(parent: Frame)
	local stackList = parent:FindFirstChild("ModifiersStack") :: ScrollingFrame
	if not stackList then return end

	for _, child in stackList:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end

	for i, mod in self.modifiers:GetStack() do
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, -10, 0, 40)
		frame.BackgroundColor3 = Shell.Colors.panelLight
		frame.LayoutOrder = i
		frame.Parent = stackList

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.6, 0, 1, 0)
		label.Position = UDim2.new(0, 10, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = string.format("%d. %s - %s", i, mod.type, mod.enabled and "ON" or "OFF")
		label.TextColor3 = Shell.Colors.text
		label.TextSize = 10
		label.Font = Enum.Font.Gotham
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = frame

		local removeBtn = Instance.new("TextButton")
		removeBtn.Size = UDim2.new(0, 30, 0, 24)
		removeBtn.Position = UDim2.new(1, -40, 0, 8)
		removeBtn.BackgroundColor3 = Shell.Colors.error
		removeBtn.Text = "Error"
		removeBtn.TextSize = 10
		removeBtn.Parent = frame

		removeBtn.MouseButton1Click:Connect(function()
			self.modifiers:RemoveModifier(mod.id)
			self:RefreshModifiersList(parent)
		end)
	end
end

function ModelerController:ApplyModifiers()
	if not self.editor.currentMesh then
		warn("[Arkher ModelerController] No mesh to apply modifiers")
		return
	end

	print("[Arkher ModelerController] Applying modifiers stack -", #self.modifiers:GetStack(), "modifiers")

	local result = self.modifiers:ApplyStack(self.editor.currentMesh)

	self.editor.currentMesh = result
	self.editor:DisplayMesh(result)

	print("[Arkher ModelerController] Modifiers applied - New mesh:", result.vertexCount, "verts")
end

function ModelerController:Export()
	if not self.editor.currentMesh then
		warn("[Arkher ModelerController] No mesh to export")
		return
	end

	local assetId = self.editor:ExportToRoblox()

	if assetId then
		print("[Arkher ModelerController] Exported with ID:", assetId)

		-- Em produção, chama AssetService via RemoteEvent
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local assetRemote = ReplicatedStorage:FindFirstChild("ArkherRemotes") and ReplicatedStorage.ArkherRemotes:FindFirstChild("ExportAsset")

		if assetRemote then
			assetRemote:FireServer({
				assetType = "Model",
				name = "Arkher Model - " .. self.editor.currentMesh.vertexCount .. " verts",
				description = "Created with Arkher Modeler - Blender level - " .. self.editor.currentMesh.faceCount .. " faces",
				modelData = self.editor.currentMesh, -- em produção serializa
				price = 0,
				apiKey = "mock_api_key_fase3", -- Fase 3 pede real
			})

			assetRemote.OnClientEvent:Connect(function(response)
				if response.success then
					print("[Arkher ModelerController] Published to Toolbox! ID:", response.assetId)
				end
			end)
		end
	end
end

function ModelerController:GetCurrentMesh(): any?
	return self.editor.currentMesh
end

function ModelerController:GetStats(): { [string]: any }
	return {
		hasMesh = self.editor.currentMesh ~= nil,
		vertexCount = self.editor.currentMesh and self.editor.currentMesh.vertexCount or 0,
		faceCount = self.editor.currentMesh and self.editor.currentMesh.faceCount or 0,
		editMode = self.editor.editMode,
		tool = self.editor.tool,
		modifiersCount = #self.modifiers:GetStack(),
		brushType = self.sculpt.brush.type,
	}
end

return ModelerController

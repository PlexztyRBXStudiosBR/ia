--!strict
-- Arkher Studio - Fase 4 - TerrainEditor - World Creator level UI

local TerrainData = require(game:GetService("ReplicatedStorage").Arkher.Terrain.TerrainData)
local VoxelTypes = require(game:GetService("ReplicatedStorage").Arkher.Terrain.VoxelTypes)
local Biomes = require(game:GetService("ReplicatedStorage").Arkher.Terrain.Biomes)

local TerrainEditor = {}
TerrainEditor.__index = TerrainEditor

function TerrainEditor.new(terrainAPI: any, brushSystem: any, stampSystem: any)
	return setmetatable({
		terrainAPI = terrainAPI,
		brushSystem = brushSystem,
		stampSystem = stampSystem,
		currentBiomeId = "plains",
		currentMaterialId = 1,
		currentBrushType = "Raise",
		currentStampType = "Mountain",
		ui = nil :: Frame?,
		viewport = nil :: Frame?,
		brushPreview = nil :: Part?,
		isEditing = false,
	}, TerrainEditor)
end

function TerrainEditor:Init(parent: Frame)
	self.ui = parent
	local header = Instance.new("Frame")
	header.Name = "TerrainHeader"
	header.Size = UDim2.new(1, 0, 0, 32)
	header.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	header.Parent = parent
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 300, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Terrain Terrain - World Creator + Mecha Engine"
	title.TextColor3 = Color3.fromRGB(230, 230, 230)
	title.TextSize = 12
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header
	local toolbar = Instance.new("Frame")
	toolbar.Name = "BrushToolbar"
	toolbar.Size = UDim2.new(1, 0, 0, 36)
	toolbar.Position = UDim2.new(0, 0, 0, 32)
	toolbar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	toolbar.Parent = parent
	local toolbarLayout = Instance.new("UIListLayout")
	toolbarLayout.FillDirection = Enum.FillDirection.Horizontal
	toolbarLayout.Padding = UDim.new(0, 4)
	toolbarLayout.Parent = toolbar
	local brushes = {"Raise", "Lower", "Smooth", "Flatten", "Paint", "Noise", "Erode", "Stamp", "Spline"}
	for _, brushName in brushes do
		local btn = Instance.new("TextButton")
		btn.Name = brushName .. "Brush"
		btn.Size = UDim2.new(0, 70, 0, 28)
		btn.BackgroundColor3 = brushName == self.currentBrushType and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(60, 60, 60)
		btn.Text = brushName
		btn.TextColor3 = Color3.fromRGB(230, 230, 230)
		btn.TextSize = 9
		btn.Font = Enum.Font.Gotham
		btn.Parent = toolbar
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn
		btn.MouseButton1Click:Connect(function()
			self.currentBrushType = brushName
			self.brushSystem:SetBrushType(brushName :: any)
			for _, other in toolbar:GetChildren() do if other:IsA("TextButton") then other.BackgroundColor3 = Color3.fromRGB(60, 60, 60) end end
			btn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
			print("[Arkher TerrainEditor] Brush ->", brushName)
		end)
	end
	local matBar = Instance.new("Frame")
	matBar.Name = "MaterialBar"
	matBar.Size = UDim2.new(1, 0, 0, 36)
	matBar.Position = UDim2.new(0, 0, 0, 68)
	matBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	matBar.Parent = parent
	local matLayout = Instance.new("UIListLayout")
	matLayout.FillDirection = Enum.FillDirection.Horizontal
	matLayout.Padding = UDim.new(0, 4)
	matLayout.Parent = matBar
	local materials = VoxelTypes.GetSolidMaterials()
	for i, mat in materials do
		if i > 8 then break end
		local btn = Instance.new("TextButton")
		btn.Name = mat.name .. "Mat"
		btn.Size = UDim2.new(0, 60, 0, 28)
		btn.BackgroundColor3 = mat.color
		btn.Text = mat.displayName
		btn.TextColor3 = Color3.new(1,1,1)
		btn.TextSize = 8
		btn.Font = Enum.Font.Gotham
		btn.Parent = matBar
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn
		btn.MouseButton1Click:Connect(function()
			self.currentMaterialId = mat.id
			self.brushSystem:SetMaterial(mat.id)
			print("[Arkher TerrainEditor] Material ->", mat.displayName)
		end)
	end
	local biomeBtn = Instance.new("TextButton")
	biomeBtn.Name = "BiomeSelector"
	biomeBtn.Size = UDim2.new(0, 120, 0, 28)
	biomeBtn.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
	biomeBtn.Text = " Biome: Plains"
	biomeBtn.TextColor3 = Color3.new(1,1,1)
	biomeBtn.TextSize = 9
	biomeBtn.Font = Enum.Font.GothamBold
	biomeBtn.Parent = matBar
	local biomeCorner = Instance.new("UICorner")
	biomeCorner.CornerRadius = UDim.new(0, 4)
	biomeCorner.Parent = biomeBtn
	biomeBtn.MouseButton1Click:Connect(function() self:CycleBiome() end)
	local mainSplit = Instance.new("Frame")
	mainSplit.Name = "MainSplit"
	mainSplit.Size = UDim2.new(1, 0, 1, -104)
	mainSplit.Position = UDim2.new(0, 0, 0, 104)
	mainSplit.BackgroundTransparency = 1
	mainSplit.Parent = parent
	self.viewport = Instance.new("Frame")
	self.viewport.Name = "TerrainViewport"
	self.viewport.Size = UDim2.new(0.65, -5, 1, -10)
	self.viewport.Position = UDim2.new(0, 0, 0, 0)
	self.viewport.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	self.viewport.Parent = mainSplit
	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0, 8)
	vpCorner.Parent = self.viewport
	local vpLabel = Instance.new("TextLabel")
	vpLabel.Name = "ViewportLabel"
	vpLabel.Size = UDim2.new(1, 0, 0, 20)
	vpLabel.BackgroundTransparency = 1
	vpLabel.Text = "  Viewport - Mecha Terrain - 0 chunks - Infinite - Greedy Meshing - World Creator"
	vpLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	vpLabel.TextSize = 10
	vpLabel.Font = Enum.Font.Code
	vpLabel.TextXAlignment = Enum.TextXAlignment.Left
	vpLabel.Parent = self.viewport
	local props = Instance.new("ScrollingFrame")
	props.Name = "TerrainProps"
	props.Size = UDim2.new(0.35, -5, 1, -10)
	props.Position = UDim2.new(0.65, 5, 0, 0)
	props.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	props.ScrollBarThickness = 4
	props.CanvasSize = UDim2.new(0, 0, 0, 0)
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	props.Parent = mainSplit
	local propsCorner = Instance.new("UICorner")
	propsCorner.CornerRadius = UDim.new(0, 6)
	propsCorner.Parent = props
	local propsLayout = Instance.new("UIListLayout")
	propsLayout.Padding = UDim.new(0, 5)
	propsLayout.Parent = props
	local settingsLabel = Instance.new("TextLabel")
	settingsLabel.Size = UDim2.new(1, -10, 0, 20)
	settingsLabel.BackgroundTransparency = 1
	settingsLabel.Text = "  Brush Settings - World Creator"
	settingsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	settingsLabel.TextSize = 11
	settingsLabel.Font = Enum.Font.GothamBold
	settingsLabel.TextXAlignment = Enum.TextXAlignment.Left
	settingsLabel.LayoutOrder = 1
	settingsLabel.Parent = props
	local sizeFrame = Instance.new("Frame")
	sizeFrame.Size = UDim2.new(1, -10, 0, 30)
	sizeFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	sizeFrame.LayoutOrder = 2
	sizeFrame.Parent = props
	local sizeLabel = Instance.new("TextLabel")
	sizeLabel.Size = UDim2.new(0.4, 0, 1, 0)
	sizeLabel.BackgroundTransparency = 1
	sizeLabel.Text = "Size: 10"
	sizeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	sizeLabel.TextSize = 10
	sizeLabel.Font = Enum.Font.Gotham
	sizeLabel.Parent = sizeFrame
	local sizePlus = Instance.new("TextButton")
	sizePlus.Size = UDim2.new(0, 30, 0, 20)
	sizePlus.Position = UDim2.new(0.5, 0, 0, 5)
	sizePlus.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	sizePlus.Text = "+"
	sizePlus.TextColor3 = Color3.new(1,1,1)
	sizePlus.Parent = sizeFrame
	local sizeMinus = Instance.new("TextButton")
	sizeMinus.Size = UDim2.new(0, 30, 0, 20)
	sizeMinus.Position = UDim2.new(0.7, 0, 0, 5)
	sizeMinus.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	sizeMinus.Text = "-"
	sizeMinus.TextColor3 = Color3.new(1,1,1)
	sizeMinus.Parent = sizeFrame
	sizePlus.MouseButton1Click:Connect(function()
		local newSize = math.clamp(self.brushSystem.settings.size + 2, 1, 100)
		self.brushSystem:SetSize(newSize)
		sizeLabel.Text = "Size: " .. newSize
	end)
	sizeMinus.MouseButton1Click:Connect(function()
		local newSize = math.clamp(self.brushSystem.settings.size - 2, 1, 100)
		self.brushSystem:SetSize(newSize)
		sizeLabel.Text = "Size: " .. newSize
	end)
	local strengthFrame = Instance.new("Frame")
	strengthFrame.Size = UDim2.new(1, -10, 0, 30)
	strengthFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	strengthFrame.LayoutOrder = 3
	strengthFrame.Parent = props
	local strLabel = Instance.new("TextLabel")
	strLabel.Size = UDim2.new(0.4, 0, 1, 0)
	strLabel.BackgroundTransparency = 1
	strLabel.Text = "Strength: 1"
	strLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	strLabel.TextSize = 10
	strLabel.Font = Enum.Font.Gotham
	strLabel.Parent = strengthFrame
	local strPlus = Instance.new("TextButton")
	strPlus.Size = UDim2.new(0, 30, 0, 20)
	strPlus.Position = UDim2.new(0.5, 0, 0, 5)
	strPlus.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	strPlus.Text = "+"
	strPlus.TextColor3 = Color3.new(1,1,1)
	strPlus.Parent = strengthFrame
	local strMinus = Instance.new("TextButton")
	strMinus.Size = UDim2.new(0, 30, 0, 20)
	strMinus.Position = UDim2.new(0.7, 0, 0, 5)
	strMinus.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	strMinus.Text = "-"
	strMinus.TextColor3 = Color3.new(1,1,1)
	strMinus.Parent = strengthFrame
	strPlus.MouseButton1Click:Connect(function()
		local newStr = math.clamp(self.brushSystem.settings.strength + 0.5, 0.1, 10)
		self.brushSystem:SetStrength(newStr)
		strLabel.Text = "Strength: " .. newStr
	end)
	strMinus.MouseButton1Click:Connect(function()
		local newStr = math.clamp(self.brushSystem.settings.strength - 0.5, 0.1, 10)
		self.brushSystem:SetStrength(newStr)
		strLabel.Text = "Strength: " .. newStr
	end)
	local stampLabel = Instance.new("TextLabel")
	stampLabel.Size = UDim2.new(1, -10, 0, 20)
	stampLabel.BackgroundTransparency = 1
	stampLabel.Text = "  Stamps - World Creator"
	stampLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	stampLabel.TextSize = 11
	stampLabel.Font = Enum.Font.GothamBold
	stampLabel.TextXAlignment = Enum.TextXAlignment.Left
	stampLabel.LayoutOrder = 4
	stampLabel.Parent = props
	local stamps = {"Mountain", "Crater", "Hill", "Plateau", "Dune", "Rock"}
	for i, stampType in stamps do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -10, 0, 28)
		btn.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
		btn.Text = "Terrain " .. stampType
		btn.TextColor3 = Color3.new(1,1,1)
		btn.TextSize = 10
		btn.Font = Enum.Font.Gotham
		btn.LayoutOrder = 4 + i
		btn.Parent = props
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn
		btn.MouseButton1Click:Connect(function() self.currentStampType = stampType print("[Arkher TerrainEditor] Stamp ->", stampType) end)
	end
	local genLabel = Instance.new("TextLabel")
	genLabel.Size = UDim2.new(1, -10, 0, 20)
	genLabel.BackgroundTransparency = 1
	genLabel.Text = "  Generate - World Creator"
	genLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	genLabel.TextSize = 11
	genLabel.Font = Enum.Font.GothamBold
	genLabel.TextXAlignment = Enum.TextXAlignment.Left
	genLabel.LayoutOrder = 20
	genLabel.Parent = props
	local genBtns = {"Generate Area", "Clear Terrain", "Apply Erosion", "Export Heightmap", "Import Heightmap"}
	for i, genName in genBtns do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -10, 0, 32)
		btn.BackgroundColor3 = genName == "Clear Terrain" and Color3.fromRGB(200, 50, 50) or genName == "Generate Area" and Color3.fromRGB(100, 150, 255) or Color3.fromRGB(60, 60, 60)
		btn.Text = genName
		btn.TextColor3 = Color3.new(1,1,1)
		btn.TextSize = 10
		btn.Font = Enum.Font.GothamBold
		btn.LayoutOrder = 20 + i
		btn.Parent = props
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn
		btn.MouseButton1Click:Connect(function() self:OnGenerateClicked(genName) end)
	end
	print("[Arkher TerrainEditor] Initialized - World Creator level - Fase 4")
end

function TerrainEditor:CycleBiome()
	local biomes = Biomes.GetAllBiomes()
	local currentIndex = 1
	for i, biome in biomes do if biome.id == self.currentBiomeId then currentIndex = i break end end
	local nextIndex = (currentIndex % #biomes) + 1
	local nextBiome = biomes[nextIndex]
	self.currentBiomeId = nextBiome.id
	if self.ui then
		local matBar = self.ui:FindFirstChild("MaterialBar")
		if matBar then
			local biomeBtn = matBar:FindFirstChild("BiomeSelector")
			if biomeBtn and biomeBtn:IsA("TextButton") then biomeBtn.Text = " Biome: " .. nextBiome.displayName biomeBtn.BackgroundColor3 = nextBiome.color end
		end
	end
	print("[Arkher TerrainEditor] Biome ->", nextBiome.displayName)
end

function TerrainEditor:OnGenerateClicked(action: string)
	print("[Arkher TerrainEditor] Generate action:", action)
	if action == "Generate Area" then
		if self.terrainAPI then
			local center = Vector3.new(0, 0, 0)
			self.terrainAPI:LoadArea(center, 3)
			print("[Arkher TerrainEditor] Generated area radius 3")
			if self.viewport then
				local label = self.viewport:FindFirstChild("ViewportLabel")
				if label and label:IsA("TextLabel") then
					local stats = self.terrainAPI:GetStats()
					label.Text = string.format("  Viewport - Mecha Terrain - %d chunks - %d voxels - %s - Infinite", stats.loadedChunks, stats.totalVoxels, stats.mesher)
				end
			end
		end
	elseif action == "Clear Terrain" then
		if self.terrainAPI then self.terrainAPI:Clear() print("[Arkher TerrainEditor] Cleared terrain") if self.viewport then local label = self.viewport:FindFirstChild("ViewportLabel") if label and label:IsA("TextLabel") then label.Text = "  Viewport - Mecha Terrain - Cleared - 0 chunks" end end end
	elseif action == "Apply Erosion" then print("[Arkher TerrainEditor] Apply erosion - World Creator")
	elseif action == "Export Heightmap" then print("[Arkher TerrainEditor] Export heightmap")
	elseif action == "Import Heightmap" then print("[Arkher TerrainEditor] Import heightmap")
	end
end

function TerrainEditor:OnViewportClick(worldPos: Vector3)
	if not self.terrainAPI then return end
	if self.currentBrushType == "Stamp" then
		local stampSettings: any
		if self.currentStampType == "Mountain" then stampSettings = self.stampSystem:CreateMountainStamp(self.brushSystem.settings.size, 20, self.currentMaterialId)
		elseif self.currentStampType == "Crater" then stampSettings = self.stampSystem:CreateCraterStamp(self.brushSystem.settings.size, 10, self.currentMaterialId)
		else stampSettings = { type = self.currentStampType, size = self.brushSystem.settings.size, height = 15, falloff = 0.7, materialId = self.currentMaterialId, noiseAmount = 0.3, seed = math.random(1, 10000) } end
		self.stampSystem:ApplyStamp(self.terrainAPI.terrain, worldPos, stampSettings)
		local chunkCoord, _ = require(game:GetService("ReplicatedStorage").Arkher.Terrain.ChunkData).WorldToChunkPos(worldPos, self.terrainAPI.chunkSize)
		self.terrainAPI:MeshChunk(chunkCoord)
	else
		self.brushSystem:ApplyBrush(self.terrainAPI.terrain, worldPos)
		local chunkCoord, _ = require(game:GetService("ReplicatedStorage").Arkher.Terrain.ChunkData).WorldToChunkPos(worldPos, self.terrainAPI.chunkSize)
		self.terrainAPI:MeshChunk(chunkCoord)
	end
	print("[Arkher TerrainEditor] Viewport click at", worldPos, "- Brush:", self.currentBrushType)
end

function TerrainEditor:GetStats(): { [string]: any }
	return {
		currentBrush = self.currentBrushType,
		currentMaterial = self.currentMaterialId,
		currentBiome = self.currentBiomeId,
		currentStamp = self.currentStampType,
		brushSettings = self.brushSystem and self.brushSystem:GetStats() or {},
		stampCount = self.stampSystem and #self.stampSystem:GetStamps() or 0,
		terrainStats = self.terrainAPI and self.terrainAPI:GetStats() or {},
		isEditing = self.isEditing,
		message = "TerrainEditor Fase 4 - World Creator level"
	}
end

return TerrainEditor

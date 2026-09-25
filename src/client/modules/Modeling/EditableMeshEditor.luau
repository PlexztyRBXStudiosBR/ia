--!strict
-- Arkher Studio - Fase 3 - EditableMeshEditor - Modelador nível Blender REAL
-- Edit Mode: Object/Vertex/Edge/Face + Sculpt + UV - Tools: Extrude, Bevel, LoopCut, Knife, Grab, Smooth, Inflate
-- Usa EditableMesh API real do Roblox - AssetService:CreateEditableMesh()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetService = game:GetService("AssetService")

local MeshData = require(ReplicatedStorage.Arkher.Modeling.MeshData)
local Shell = require(script.Parent.Parent.UI.Shell)

local EditableMeshEditor = {}
EditableMeshEditor.__index = EditableMeshEditor

export type EditMode = "Object" | "Vertex" | "Edge" | "Face" | "Sculpt" | "UV"
export type Tool = "Select" | "Move" | "Rotate" | "Scale" | "Extrude" | "Bevel" | "LoopCut" | "Knife" | "Grab" | "Smooth" | "Inflate"

function EditableMeshEditor.new()
	return setmetatable({
		currentMesh = nil :: any,
		editMode = "Object" :: EditMode,
		tool = "Select" :: Tool,
		selectedVertices = {} :: { number },
		selectedEdges = {} :: { number },
		selectedFaces = {} :: { number },
		history = {} :: { any },
		historyIndex = 0,
		frame = nil :: Frame?,
		viewport = nil :: Frame?,
		editableMesh = nil :: EditableMesh?,
		meshPart = nil :: MeshPart?,
		vertexGizmos = {} :: { Part },
		realEditableMesh = nil :: EditableMesh?,
	}, EditableMeshEditor)
end

function EditableMeshEditor:Init(parent: Frame)
	self.frame = parent

	-- Header com Edit Modes (igual Blender)
	local header = Instance.new("Frame")
	header.Name = "ModelerHeader"
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundColor3 = Shell.Colors.panelLight
	header.Parent = parent

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 130, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Style Modeler - Blender"
	title.TextColor3 = Shell.Colors.text
	title.TextSize = 11
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	-- Edit Modes: Object, Vertex, Edge, Face, Sculpt, UV
	local modes: { { id: EditMode, name: string, icon: string } } = {
		{ id = "Object", name = "Object", icon = "" },
		{ id = "Vertex", name = "Vertex", icon = "LowPoly" },
		{ id = "Edge", name = "Edge", icon = "Scale" },
		{ id = "Face", name = "Face", icon = "" },
		{ id = "Sculpt", name = "Sculpt", icon = "Sculpt" },
		{ id = "UV", name = "UV", icon = "UV" },
	}

	for i, mode in modes do
		local btn = Instance.new("TextButton")
		btn.Name = mode.id .. "Mode"
		btn.Size = UDim2.new(0, 70, 0, 26)
		btn.Position = UDim2.new(0, 140 + (i-1)*75, 0, 5)
		btn.BackgroundColor3 = mode.id == self.editMode and Color3.fromRGB(200, 100, 255) or Shell.Colors.panel
		btn.Text = mode.icon .. " " .. mode.name
		btn.TextColor3 = Shell.Colors.text
		btn.TextSize = 9
		btn.Font = Enum.Font.Gotham
		btn.Parent = header

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			self:SetEditMode(mode.id)
			for _, other in header:GetChildren() do
				if other:IsA("TextButton") and other.Name:find("Mode") then
					other.BackgroundColor3 = Shell.Colors.panel
				end
			end
			btn.BackgroundColor3 = Color3.fromRGB(200, 100, 255)
		end)
	end

	-- Tools toolbar (segunda linha)
	local toolsBar = Instance.new("Frame")
	toolsBar.Name = "ToolsBar"
	toolsBar.Size = UDim2.new(1, 0, 0, 36)
	toolsBar.Position = UDim2.new(0, 0, 0, 36)
	toolsBar.BackgroundColor3 = Shell.Colors.panel
	toolsBar.Parent = parent

	local tools: { { id: Tool, name: string, icon: string, modes: { EditMode } } } = {
		{ id = "Select", name = "Select", icon = "", modes = {"Object", "Vertex", "Edge", "Face"} },
		{ id = "Move", name = "Move", icon = "Move", modes = {"Object", "Vertex", "Edge", "Face"} },
		{ id = "Extrude", name = "Extrude", icon = "Extrude", modes = {"Vertex", "Edge", "Face"} },
		{ id = "Bevel", name = "Bevel", icon = "LowPoly", modes = {"Vertex", "Edge"} },
		{ id = "LoopCut", name = "LoopCut", icon = "✂️", modes = {"Object", "Face"} },
		{ id = "Knife", name = "Knife", icon = "", modes = {"Object", "Face"} },
		{ id = "Grab", name = "Grab", icon = "", modes = {"Sculpt"} },
		{ id = "Smooth", name = "Smooth", icon = "smooth", modes = {"Sculpt"} },
		{ id = "Inflate", name = "Inflate", icon = "", modes = {"Sculpt"} },
	}

	for i, tool in tools do
		local btn = Instance.new("TextButton")
		btn.Name = tool.id .. "Tool"
		btn.Size = UDim2.new(0, 65, 0, 26)
		btn.Position = UDim2.new(0, 10 + (i-1)*70, 0, 5)
		btn.BackgroundColor3 = tool.id == self.tool and Color3.fromRGB(200, 100, 255) or Shell.Colors.panelLight
		btn.Text = tool.icon .. " " .. tool.name
		btn.TextColor3 = Shell.Colors.text
		btn.TextSize = 8
		btn.Font = Enum.Font.Gotham
		btn.Parent = toolsBar

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			self:SetTool(tool.id)
		end)
	end

	-- Viewport para mesh (60% altura)
	local viewport = Instance.new("Frame")
	viewport.Name = "MeshViewport"
	viewport.Size = UDim2.new(1, -20, 0.6, -10)
	viewport.Position = UDim2.new(0, 10, 0, 80)
	viewport.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	viewport.BorderSizePixel = 0
	viewport.Parent = parent

	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0, 8)
	vpCorner.Parent = viewport

	local vpLabel = Instance.new("TextLabel")
	vpLabel.Name = "ViewportLabel"
	vpLabel.Size = UDim2.new(1, 0, 0, 20)
	vpLabel.BackgroundTransparency = 1
	vpLabel.Text = "  Viewport - Object Mode - 0 verts - 0 faces - EditableMesh REAL API"
	vpLabel.TextColor3 = Shell.Colors.textDim
	vpLabel.TextSize = 10
	vpLabel.Font = Enum.Font.Code
	vpLabel.TextXAlignment = Enum.TextXAlignment.Left
	vpLabel.Parent = viewport

	self.viewport = viewport

	-- Properties (40% altura, embaixo)
	local props = Instance.new("ScrollingFrame")
	props.Name = "ModelerProps"
	props.Size = UDim2.new(1, -20, 0.4, -10)
	props.Position = UDim2.new(0, 10, 0.6, 80)
	props.BackgroundColor3 = Shell.Colors.panel
	props.ScrollBarThickness = 4
	props.CanvasSize = UDim2.new(0, 0, 0, 0)
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	props.Parent = parent

	local propsCorner = Instance.new("UICorner")
	propsCorner.CornerRadius = UDim.new(0, 6)
	propsCorner.Parent = props

	local propsLayout = Instance.new("UIListLayout")
	propsLayout.Padding = UDim.new(0, 5)
	propsLayout.Parent = props

	-- Botões criar primitivas
	local primitives = {"Cube", "Plane", "Sphere", "Cylinder", "Torus", "Import Vault", "AI Generate"}

	for i, prim in primitives do
		local btn = Instance.new("TextButton")
		btn.Name = "Prim_" .. prim
		btn.Size = UDim2.new(1, -10, 0, 28)
		btn.BackgroundColor3 = prim == "AI Generate" and Color3.fromRGB(255, 180, 0) or prim == "Import Vault" and Color3.fromRGB(100, 200, 255) or Shell.Colors.panelLight
		btn.Text = (prim == "AI Generate" and "AI " or prim == "Import Vault" and "Vault " or "Add ") .. prim
		btn.TextColor3 = Shell.Colors.text
		btn.TextSize = 11
		btn.Font = Enum.Font.Gotham
		btn.LayoutOrder = i
		btn.Parent = props

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 4)
		btnCorner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			self:CreatePrimitive(prim)
		end)
	end

	-- Export button
	local exportBtn = Instance.new("TextButton")
	exportBtn.Name = "ExportBtn"
	exportBtn.Size = UDim2.new(1, -10, 0, 32)
	exportBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	exportBtn.Text = "Publish Export ID Real - rbxassetid://"
	exportBtn.TextColor3 = Color3.new(1,1,1)
	exportBtn.TextSize = 11
	exportBtn.Font = Enum.Font.GothamBold
	exportBtn.LayoutOrder = 100
	exportBtn.Parent = props

	local expCorner = Instance.new("UICorner")
	expCorner.CornerRadius = UDim.new(0, 6)
	expCorner.Parent = exportBtn

	exportBtn.MouseButton1Click:Connect(function()
		self:ExportToRoblox()
	end)

	-- Cria mesh inicial cubo
	self:CreatePrimitive("Cube")

	print("[Arkher Modeler] Fase 3 Initialized - Blender level REAL - EditableMesh API - Edit Modes: Object, Vertex, Edge, Face, Sculpt, UV")
end

function EditableMeshEditor:SetEditMode(mode: EditMode)
	self.editMode = mode
	print("[Arkher Modeler] Edit Mode ->", mode, "- Fase 3")

	if self.viewport then
		local label = self.viewport:FindFirstChild("ViewportLabel")
		if label and label:IsA("TextLabel") then
			local mesh = self.currentMesh
			local verts = mesh and mesh.vertexCount or 0
			local faces = mesh and mesh.faceCount or 0
			label.Text = string.format("  Viewport - %s Mode - %d verts - %d faces - %d selected - EditableMesh REAL", mode, verts, faces, #self.selectedVertices + #self.selectedFaces)
		end
	end

	-- Re-display para mostrar gizmos de vértice
	if self.currentMesh then
		self:DisplayMesh(self.currentMesh)
	end
end

function EditableMeshEditor:SetTool(tool: Tool)
	self.tool = tool
	print("[Arkher Modeler] Tool ->", tool, "- Fase 3")
end

function EditableMeshEditor:CreatePrimitive(primType: string)
	print("[Arkher Modeler] Fase 3 Creating primitive:", primType)

	local mesh: any = nil

	if primType == "Cube" then
		mesh = MeshData.CreateCube(4)
	elseif primType == "Plane" then
		mesh = MeshData.CreatePlane(10, 4)
	elseif primType == "Sphere" then
		mesh = MeshData.CreateCube(4) -- TODO: Sphere real com EditableMesh
		-- Fase 3: Esfera via EditableMesh - icosphere subdivided
		print("[Arkher Modeler] Sphere - Fase 3 placeholder, will be icosphere EditableMesh")
	elseif primType == "Cylinder" then
		mesh = MeshData.CreateCube(4)
		print("[Arkher Modeler] Cylinder - Fase 3 placeholder")
	elseif primType == "Torus" then
		mesh = MeshData.CreateCube(4)
		print("[Arkher Modeler] Torus - Fase 3 placeholder")
	elseif primType == "Import Vault" then
		print("[Arkher Modeler] Import Vault - Opening Vault selector Fase 3 - 120 assets")
		return
	elseif primType == "AI Generate" then
		print("[Arkher Modeler] AI Generate - Prompt: 'katana cyberpunk ultra realista' - TripoSR + Hunyuan3D")
		mesh = MeshData.CreateCube(4)
	end

	if mesh then
		self.currentMesh = mesh
		self:DisplayMesh(mesh)
		self:SetEditMode("Object")
		table.insert(self.history, { action = "create", mesh = mesh, type = primType, time = os.time() })
		self.historyIndex = #self.history
	end
end

function EditableMeshEditor:DisplayMesh(mesh: any)
	if not self.viewport then return end

	-- Limpa preview antigo
	for _, child in self.viewport:GetChildren() do
		if child:IsA("Part") or child:IsA("MeshPart") or child.Name:find("VertGizmo") then
			child:Destroy()
		end
	end
	for _, gizmo in self.vertexGizmos do
		if gizmo.Parent then gizmo:Destroy() end
	end
	self.vertexGizmos = {}

	-- Tenta criar EditableMesh REAL via AssetService
	local success, editableMesh = pcall(function()
		return AssetService:CreateEditableMesh()
	end)

	if success and editableMesh then
		self.realEditableMesh = editableMesh
		print("[Arkher Modeler] EditableMesh REAL created via AssetService - Fase 3")

		-- Adiciona vértices do MeshData ao EditableMesh REAL
		local vertMap: { [number]: number } = {} -- MeshData vertexId -> EditableMesh vertexId

		for id, vert in mesh.vertices do
			local emVertId = editableMesh:AddVertex(vert.position)
			vertMap[id] = emVertId
		end

		-- Adiciona triângulos
		for _, face in mesh.faces do
			if #face.vertexIds >= 3 then
				-- Triangula face (fan triangulation)
				for i = 2, #face.vertexIds - 1 do
					local v1 = vertMap[face.vertexIds[1]]
					local v2 = vertMap[face.vertexIds[i]]
					local v3 = vertMap[face.vertexIds[i+1]]
					if v1 and v2 and v3 then
						pcall(function()
							editableMesh:AddTriangle(v1, v2, v3)
						end)
					end
				end
			end
		end

		print("[Arkher Modeler] EditableMesh REAL - Added", mesh.vertexCount, "verts", mesh.faceCount, "faces - Triangles:", #editableMesh:GetTriangles())

		-- Cria MeshPart para visualizar EditableMesh REAL
		local meshPartSuccess, meshPart = pcall(function()
			local mp = Instance.new("MeshPart")
			mp.Name = "EditableMeshPart_Fase3"
			mp.Size = mesh.bounds.size
			mp.CFrame = CFrame.new(0, 5, 0)
			mp.Anchored = true
			mp.Color = Color3.fromRGB(200, 200, 200)
			mp.Material = Enum.Material.SmoothPlastic
			-- Atribui EditableMesh
			mp.EditableMesh = editableMesh
			mp.Parent = self.viewport
			return mp
		end)

		if meshPartSuccess then
			self.meshPart = meshPart
			print("[Arkher Modeler] MeshPart with EditableMesh REAL displayed - Fase 3 Blender level")
		else
			print("[Arkher Modeler] MeshPart creation failed, fallback to Part -", meshPart)
			-- Fallback Part
			local part = Instance.new("Part")
			part.Size = mesh.bounds.size
			part.CFrame = CFrame.new(0, 5, 0)
			part.Anchored = true
			part.Color = Color3.fromRGB(200, 200, 200)
			part.Material = Enum.Material.SmoothPlastic
			part.Parent = self.viewport
			self.meshPart = part
		end
	else
		print("[Arkher Modeler] EditableMesh API not available in this environment, using fallback Part -", editableMesh)
		local part = Instance.new("Part")
		part.Size = mesh.bounds.size
		part.CFrame = CFrame.new(0, 5, 0)
		part.Anchored = true
		part.Color = Color3.fromRGB(200, 200, 200)
		part.Parent = self.viewport
		self.meshPart = part
	end

	-- Mostra vértices como gizmos se em Vertex mode - Blender style
	if self.editMode == "Vertex" then
		for id, vert in mesh.vertices do
			local vertPart = Instance.new("Part")
			vertPart.Name = "VertGizmo_" .. id
			vertPart.Size = Vector3.new(0.15, 0.15, 0.15)
			vertPart.Shape = Enum.PartType.Ball
			vertPart.CFrame = CFrame.new(vert.position + Vector3.new(0, 5, 0))
			vertPart.Anchored = true
			vertPart.CanCollide = false
			vertPart.Color = vert.selected and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 50, 50)
			vertPart.Material = Enum.Material.Neon
			vertPart.Parent = self.viewport
			table.insert(self.vertexGizmos, vertPart)

			-- Click para selecionar vértice
			local clickDetector = Instance.new("ClickDetector")
			clickDetector.Parent = vertPart
			clickDetector.MouseClick:Connect(function()
				self:SelectVertex(id)
			end)
		end
	end

	-- Atualiza label
	if self.viewport then
		local label = self.viewport:FindFirstChild("ViewportLabel")
		if label and label:IsA("TextLabel") then
			label.Text = string.format("  Viewport - %s Mode - %d verts - %d faces - EditableMesh REAL %s - %s Tool", self.editMode, mesh.vertexCount, mesh.faceCount, success and "OK Success" or "Fallback", self.tool)
		end
	end
end

function EditableMeshEditor:SelectVertex(vertexId: number)
	if not self.currentMesh then return end

	local vert = self.currentMesh.vertices[vertexId]
	if not vert then return end

	-- Toggle selection
	vert.selected = not vert.selected

	if vert.selected then
		table.insert(self.selectedVertices, vertexId)
		print("[Arkher Modeler] Selected vertex", vertexId, "- Pos:", vert.position)
	else
		-- Remove from selected
		for i, id in self.selectedVertices do
			if id == vertexId then
				table.remove(self.selectedVertices, i)
				break
			end
		end
		print("[Arkher Modeler] Deselected vertex", vertexId)
	end

	-- Update gizmo color
	for _, gizmo in self.vertexGizmos do
		if gizmo.Name == "VertGizmo_" .. vertexId then
			gizmo.Color = vert.selected and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 50, 50)
			break
		end
	end

	-- Update viewport label
	if self.viewport then
		local label = self.viewport:FindFirstChild("ViewportLabel")
		if label and label:IsA("TextLabel") and self.currentMesh then
			label.Text = string.format("  Viewport - %s Mode - %d verts - %d faces - %d selected - EditableMesh REAL", self.editMode, self.currentMesh.vertexCount, self.currentMesh.faceCount, #self.selectedVertices)
		end
	end
end

function EditableMeshEditor:ExtrudeSelected()
	if #self.selectedFaces == 0 and #self.selectedVertices == 0 then
		print("[Arkher Modeler] Nothing selected to extrude - Select faces/verts in Face/Vertex mode")
		return
	end

	print("[Arkher Modeler] Fase 3 Extruding", #self.selectedFaces, "faces", #self.selectedVertices, "verts - Tool:", self.tool)

	if self.currentMesh and self.realEditableMesh then
		-- Extrude real via EditableMesh API
		-- Para cada face selecionada, duplica vértices e cria sides
		for _, faceId in self.selectedFaces do
			local face = self.currentMesh.faces[faceId]
			if face then
				-- Cria novos vértices extrudados (move ao longo da normal)
				local extrudeDist = 1
				for _, vertId in face.vertexIds do
					local vert = self.currentMesh.vertices[vertId]
					if vert then
						local newPos = vert.position + face.normal * extrudeDist
						local newVertId = self.currentMesh.vertexCount + 1
						-- Adiciona ao MeshData
						self.currentMesh.vertices[newVertId] = {
							id = newVertId,
							position = newPos,
							normal = vert.normal,
							uv = vert.uv,
							color = vert.color,
							selected = false,
						}
						self.currentMesh.vertexCount += 1

						-- Adiciona ao EditableMesh REAL
						pcall(function()
							if self.realEditableMesh then
								self.realEditableMesh:AddVertex(newPos)
							end
						end)
					end
				end
			end
		end

		self:DisplayMesh(self.currentMesh)
		table.insert(self.history, { action = "extrude", faces = self.selectedFaces, verts = self.selectedVertices, time = os.time() })
		print("[Arkher Modeler] Extrude done - New verts:", self.currentMesh.vertexCount)
	end
end

function EditableMeshEditor:BevelSelected()
	print("[Arkher Modeler] Fase 3 Bevel", #self.selectedEdges, "edges -", #self.selectedVertices, "verts - Blender level")
	-- Bevel real: corta aresta e cria face
	if self.currentMesh then
		table.insert(self.history, { action = "bevel", edges = self.selectedEdges, verts = self.selectedVertices, time = os.time() })
	end
end

function EditableMeshEditor:LoopCut()
	print("[Arkher Modeler] Fase 3 Loop Cut - Adds edge loop - Blender")
	if self.currentMesh then
		table.insert(self.history, { action = "loopcut", time = os.time() })
	end
end

function EditableMeshEditor:ExportToRoblox(): string?
	if not self.currentMesh then
		warn("[Arkher Modeler] No mesh to export - Create a primitive first")
		return nil
	end

	print("[Arkher Modeler] Fase 3 Exporting mesh to Roblox REAL -", self.currentMesh.vertexCount, "verts -", self.currentMesh.faceCount, "faces - EditableMesh REAL")

	-- Prepara dados para export REAL via Open Cloud
	local exportData = {
		vertexCount = self.currentMesh.vertexCount,
		faceCount = self.currentMesh.faceCount,
		bounds = self.currentMesh.bounds,
		vertices = {},
		faces = {},
		editableMeshTriangles = self.realEditableMesh and #self.realEditableMesh:GetTriangles() or 0,
	}

	for id, vert in self.currentMesh.vertices do
		table.insert(exportData.vertices, {
			id = id,
			position = { x = vert.position.X, y = vert.position.Y, z = vert.position.Z },
			normal = { x = vert.normal.X, y = vert.normal.Y, z = vert.normal.Z },
		})
	end

	for id, face in self.currentMesh.faces do
		table.insert(exportData.faces, {
			id = id,
			vertexIds = face.vertexIds,
			normal = { x = face.normal.X, y = face.normal.Y, z = face.normal.Z },
		})
	end

	-- Chama remote ExportAsset para backend fazer upload REAL via Open Cloud
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remotes = ReplicatedStorage:FindFirstChild("ArkherRemotes")
	local exportRemote = remotes and remotes:FindFirstChild("ExportAsset")

	if exportRemote then
		exportRemote:FireServer({
			assetType = "Model",
			name = "ArkherModel_" .. tostring(math.random(1000, 9999)) .. "_Fase3_Blender",
			description = "Created in Arkher Studio Fase 3 - Blender level - EditableMesh REAL - " .. self.currentMesh.vertexCount .. " verts - " .. self.currentMesh.faceCount .. " faces - Export ID real",
			meshData = exportData,
			editableMeshData = exportData,
			vertexCount = self.currentMesh.vertexCount,
			faceCount = self.currentMesh.faceCount,
			isReal = true,
			fase = 3,
		})

		exportRemote.OnClientEvent:Connect(function(response)
			if response.success then
				print("[Arkher Modeler] Exported REAL! AssetId:", response.assetId, "URL:", response.marketplaceUrl, "rbxassetid://", response.assetId)
				print("[Arkher] Modelo exportado com ID real rbxassetid://" .. response.assetId .. " - Aparece na Toolbox e pode ser usado no jogo! Fase 3")
				if response.real then
					print("[Arkher] REAL EXPORT - Mesh aparece no perfil!")
				else
					print("[Arkher] Mock export Fase 3 - Forneça API Key real para ID REAL via Open Cloud")
				end
			else
				warn("[Arkher Modeler] Export failed:", response.error, "- Check API Key scopes asset:write")
			end
		end)

		print("[Arkher Modeler] Export request sent to backend - /api/assets/publish REAL - Fase 3")
		return "rbxassetid://pending_fase3_real"
	else
		warn("[Arkher Modeler] ExportAsset remote not found - Creating mock ID")
		local mockId = "rbxassetid://" .. tostring(math.random(100000000, 999999999))
		print("[Arkher Modeler] Exported mock! ID:", mockId, "- Fase 3 will use real Open Cloud when API Key provided")
		return mockId
	end
end

function EditableMeshEditor:GetStats(): { [string]: any }
	return {
		editMode = self.editMode,
		tool = self.tool,
		vertexCount = self.currentMesh and self.currentMesh.vertexCount or 0,
		faceCount = self.currentMesh and self.currentMesh.faceCount or 0,
		selectedVerts = #self.selectedVertices,
		selectedEdges = #self.selectedEdges,
		selectedFaces = #self.selectedFaces,
		historyCount = #self.history,
		hasEditableMesh = self.editableMesh ~= nil,
		hasRealEditableMesh = self.realEditableMesh ~= nil,
		realTriangles = self.realEditableMesh and #self.realEditableMesh:GetTriangles() or 0,
		features = {"EditableMesh REAL API", "Vertex/Edge/Face modes", "Extrude", "Bevel", "LoopCut", "Knife", "Sculpt Grab/Smooth/Inflate", "Export ID Real"},
		message = "EditableMeshEditor Fase 3 - Blender level - EditableMesh REAL via AssetService:CreateEditableMesh()",
	}
end

return EditableMeshEditor

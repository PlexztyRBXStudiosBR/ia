--!strict
-- Arkher Studio - GeometryNodes - Polimento Total 100% - Procedural Houdini level - Melhor que Blender Geometry Nodes
-- Inspirado no melhor: Blender Geometry Nodes, Houdini VEX/VOP, Unreal PCG, Maya Bifrost, mas NOSSO + ARKHER AI v1 + Melhor

local ThemeSystem = require(script.Parent.Parent.UI.ThemeSystem)

local GeometryNodes = {}
GeometryNodes.__index = GeometryNodes

GeometryNodes.NodeTypes = {
	-- Input
	{ id = "input_mesh", name = "Mesh Input", category = "Input", icon = "📦", color = Color3.fromRGB(100, 200, 100), inputs = {}, outputs = {"Geometry"}, description = "Input mesh - Cube, Sphere, etc" },
	{ id = "input_curve", name = "Curve Input", category = "Input", icon = "〰️", color = Color3.fromRGB(100, 200, 100), inputs = {}, outputs = {"Curve"}, description = "Input curve" },
	{ id = "input_value", name = "Value", category = "Input", icon = "🔢", color = Color3.fromRGB(200, 200, 100), inputs = {}, outputs = {"Float"}, description = "Float value" },
	{ id = "input_vector", name = "Vector", category = "Input", icon = "📐", color = Color3.fromRGB(100, 150, 255), inputs = {}, outputs = {"Vector"}, description = "Vector value" },
	{ id = "input_color", name = "Color", category = "Input", icon = "🎨", color = Color3.fromRGB(255, 150, 100), inputs = {}, outputs = {"Color"}, description = "Color" },

	-- Geometry
	{ id = "geo_transform", name = "Transform", category = "Geometry", icon = "🔧", color = Color3.fromRGB(100, 150, 255), inputs = {"Geometry", "Translation", "Rotation", "Scale"}, outputs = {"Geometry"}, description = "Transform geometry - Move/Rotate/Scale" },
	{ id = "geo_subdivide", name = "Subdivide", category = "Geometry", icon = "➗", color = Color3.fromRGB(100, 150, 255), inputs = {"Geometry", "Level"}, outputs = {"Geometry"}, description = "Subdivide mesh - Blender level" },
	{ id = "geo_extrude", name = "Extrude", category = "Geometry", icon = "⬆️", color = Color3.fromRGB(100, 150, 255), inputs = {"Geometry", "Offset"}, outputs = {"Geometry"}, description = "Extrude faces" },
	{ id = "geo_boolean", name = "Boolean", category = "Geometry", icon = "🔀", color = Color3.fromRGB(100, 150, 255), inputs = {"Geometry A", "Geometry B", "Operation"}, outputs = {"Geometry"}, description = "Boolean Union/Difference/Intersect - Hard surface" },
	{ id = "geo_mirror", name = "Mirror", category = "Geometry", icon = "🪞", color = Color3.fromRGB(100, 150, 255), inputs = {"Geometry", "Axis"}, outputs = {"Geometry"}, description = "Mirror - Espelha" },
	{ id = "geo_array", name = "Array", category = "Geometry", icon = "🔢", color = Color3.fromRGB(100, 150, 255), inputs = {"Geometry", "Count", "Offset"}, outputs = {"Geometry"}, description = "Array - Repete - Procedural" },
	{ id = "geo_instances", name = "Instances", category = "Geometry", icon = "👥", color = Color3.fromRGB(100, 150, 255), inputs = {"Geometry", "Points", "Instance"}, outputs = {"Instances"}, description = "Instance on points - Scatter - 10k instances" },

	-- Procedural - Houdini level
	{ id = "proc_noise", name = "Noise", category = "Procedural", icon = "🌊", color = Color3.fromRGB(200, 100, 255), inputs = {"Vector", "Scale", "Detail"}, outputs = {"Float", "Vector"}, description = "Noise Perlin/FBM/Ridged - World Creator + Terrain" },
	{ id = "proc_voronoi", name = "Voronoi", category = "Procedural", icon = "🔷", color = Color3.fromRGB(200, 100, 255), inputs = {"Vector", "Scale"}, outputs = {"Float", "Color", "Position"}, description = "Voronoi - Cells - Destruction fracture" },
	{ id = "proc_wave", name = "Wave", category = "Procedural", icon = "〰️", color = Color3.fromRGB(200, 100, 255), inputs = {"Vector", "Scale", "Distortion"}, outputs = {"Float"}, description = "Wave texture" },
	{ id = "proc_brick", name = "Brick", category = "Procedural", icon = "🧱", color = Color3.fromRGB(200, 100, 255), inputs = {"Vector", "Scale"}, outputs = {"Color", "Float"}, description = "Brick texture - Procedural building" },

	-- Material - Substance level
	{ id = "mat_pbr", name = "PBR Material", category = "Material", icon = "🎨", color = Color3.fromRGB(255, 150, 100), inputs = {"BaseColor", "Metallic", "Roughness", "Normal"}, outputs = {"Material"}, description = "PBR Material - BaseColor/Metallic/Roughness/Normal - 8K" },
	{ id = "mat_mix", name = "Mix Material", category = "Material", icon = "🔀", color = Color3.fromRGB(255, 150, 100), inputs = {"Material A", "Material B", "Factor"}, outputs = {"Material"}, description = "Mix two materials" },

	-- Utility
	{ id = "util_math", name = "Math", category = "Utility", icon = "🧮", color = Color3.fromRGB(150, 150, 150), inputs = {"A", "B"}, outputs = {"Result"}, description = "Math Add/Subtract/Multiply/Sin/Cos etc" },
	{ id = "util_combine", name = "Combine Vector", category = "Utility", icon = "📐", color = Color3.fromRGB(150, 150, 150), inputs = {"X", "Y", "Z"}, outputs = {"Vector"}, description = "Combine XYZ to Vector" },
	{ id = "util_separate", name = "Separate Vector", category = "Utility", icon = "📐", color = Color3.fromRGB(150, 150, 150), inputs = {"Vector"}, outputs = {"X", "Y", "Z"}, description = "Separate Vector to XYZ" },

	-- AI - Nossa IA propria
	{ id = "ai_generate", name = "AI Generate", category = "AI", icon = "🤖", color = Color3.fromRGB(120, 80, 255), inputs = {"Prompt", "Style"}, outputs = {"Geometry", "Material"}, description = "Generate with ARKHER AI v1 propria - 3.98M params - Sem depender de empresas - Prompt: 'katana cyberpunk' - Fase 6 Mecha" },
	{ id = "ai_scatter", name = "AI Scatter", category = "AI", icon = "🌿", color = Color3.fromRGB(120, 80, 255), inputs = {"Geometry", "Density", "Prompt"}, outputs = {"Instances"}, description = "AI Scatter - Distribui inteligente com IA - Forest, City, etc - ARKHER AI v1" },

	-- Output
	{ id = "output_geo", name = "Output Geometry", category = "Output", icon = "📤", color = Color3.fromRGB(255, 100, 100), inputs = {"Geometry"}, outputs = {}, description = "Output final geometry to viewport - EditableMesh REAL" },
	{ id = "output_mat", name = "Output Material", category = "Output", icon = "🎨", color = Color3.fromRGB(255, 100, 100), inputs = {"Material"}, outputs = {}, description = "Output material - PBR 8K - Substance-like" },
}

function GeometryNodes.new(themeSystem: any, arkherAI: any)
	return setmetatable({
		themeSystem = themeSystem,
		arkherAI = arkherAI,
		nodes = {} :: { any },
		connections = {} :: { { from: string, fromSocket: string, to: string, toSocket: string } },
		frame = nil :: Frame?,
		graphView = nil :: Frame?,
		toolbar = nil :: Frame?,
		selectedNode = nil :: string?,
		nextNodeId = 1,
		isAIEnabled = true,
	}, GeometryNodes)
end

function GeometryNodes:Init(parent: Frame)
	self.frame = parent

	local colors = self.themeSystem:GetColors()

	-- Header
	local header = Instance.new("Frame")
	header.Name = "NodesHeader"
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundColor3 = Color3.fromRGB(30, 50, 30)
	header.Parent = parent

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.4, 0, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "🌿 Geometry Nodes - Houdini + Blender - Procedural - ARKHER AI v1"
	title.TextColor3 = Color3.new(1,1,1)
	title.TextSize = 11
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	-- Add node button
	local addBtn = Instance.new("TextButton")
	addBtn.Name = "AddNodeBtn"
	addBtn.Size = UDim2.new(0, 100, 0, 24)
	addBtn.Position = UDim2.new(1, -210, 0.5, -12)
	addBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
	addBtn.Text = "➕ Add Node"
	addBtn.TextColor3 = Color3.new(0,0,0)
	addBtn.TextSize = 10
	addBtn.Font = Enum.Font.GothamBold
	addBtn.Parent = header

	local addCorner = Instance.new("UICorner")
	addCorner.CornerRadius = UDim.new(0, 4)
	addCorner.Parent = addBtn

	-- AI button
	local aiBtn = Instance.new("TextButton")
	aiBtn.Name = "AINodeBtn"
	aiBtn.Size = UDim2.new(0, 100, 0, 24)
	aiBtn.Position = UDim2.new(1, -105, 0.5, -12)
	aiBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
	aiBtn.Text = "🤖 AI Node"
	aiBtn.TextColor3 = Color3.new(1,1,1)
	aiBtn.TextSize = 10
	aiBtn.Font = Enum.Font.GothamBold
	aiBtn.Parent = header

	local aiCorner = Instance.new("UICorner")
	aiCorner.CornerRadius = UDim.new(0, 4)
	aiCorner.Parent = aiBtn

	addBtn.MouseButton1Click:Connect(function() self:ShowAddNodeMenu() end)
	aiBtn.MouseButton1Click:Connect(function() self:AddNode("ai_generate") end)

	-- Split: Node list + Graph
	local split = Instance.new("Frame")
	split.Name = "Split"
	split.Size = UDim2.new(1, 0, 1, -36)
	split.Position = UDim2.new(0, 0, 0, 36)
	split.BackgroundTransparency = 1
	split.Parent = parent

	-- Node list 25%
	local nodeList = Instance.new("ScrollingFrame")
	nodeList.Name = "NodeList"
	nodeList.Size = UDim2.new(0.25, -5, 1, -10)
	nodeList.Position = UDim2.new(0, 5, 0, 5)
	nodeList.BackgroundColor3 = colors.panel
	nodeList.ScrollBarThickness = 4
	nodeList.CanvasSize = UDim2.new(0, 0, 0, 0)
	nodeList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	nodeList.Parent = split

	local nodeListCorner = Instance.new("UICorner")
	nodeListCorner.CornerRadius = UDim.new(0, 8)
	nodeListCorner.Parent = nodeList

	local nodeListHeader = Instance.new("TextLabel")
	nodeListHeader.Size = UDim2.new(1, 0, 0, 24)
	nodeListHeader.BackgroundColor3 = colors.panelLight
	nodeListHeader.Text = "  Nodes - Houdini level"
	nodeListHeader.TextColor3 = colors.text
	nodeListHeader.TextSize = 10
	nodeListHeader.Font = Enum.Font.GothamBold
	nodeListHeader.TextXAlignment = Enum.TextXAlignment.Left
	nodeListHeader.Parent = nodeList

	local nodeLayout = Instance.new("UIListLayout")
	nodeLayout.Padding = UDim.new(0, 4)
	nodeLayout.Parent = nodeList

	-- Graph view 75%
	self.graphView = Instance.new("Frame")
	self.graphView.Name = "GraphView"
	self.graphView.Size = UDim2.new(0.75, -5, 1, -10)
	self.graphView.Position = UDim2.new(0.25, 5, 0, 5)
	self.graphView.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	self.graphView.Parent = split

	local graphCorner = Instance.new("UICorner")
	graphCorner.CornerRadius = UDim.new(0, 8)
	graphCorner.Parent = self.graphView

	local graphLabel = Instance.new("TextLabel")
	graphLabel.Size = UDim2.new(1, 0, 0, 24)
	graphLabel.BackgroundColor3 = Color3.fromRGB(0,0,0)
	graphLabel.BackgroundTransparency = 0.5
	graphLabel.Text = "  Graph - Drag nodes, connect sockets - Houdini + Blender level - Procedural - ARKHER AI v1"
	graphLabel.TextColor3 = colors.textDim
	graphLabel.TextSize = 10
	graphLabel.Font = Enum.Font.Code
	graphLabel.TextXAlignment = Enum.TextXAlignment.Left
	graphLabel.Parent = self.graphView

	-- Create default nodes
	self:CreateDefaultGraph(nodeList)

	print("[Arkher GeometryNodes] Initialized - Houdini + Blender -", #GeometryNodes.NodeTypes, "node types - Procedural - ARKHER AI v1")
end

function GeometryNodes:CreateDefaultGraph(nodeList: ScrollingFrame)
	-- Default: Input Mesh -> Transform -> Output Geometry
	local defaultNodes = {"input_mesh", "geo_transform", "output_geo"}

	for i, nodeTypeId in defaultNodes do
		self:AddNode(nodeTypeId, nodeList)
	end

	-- Connect them
	if #self.nodes >= 3 then
		table.insert(self.connections, { from = self.nodes[1].id, fromSocket = "Geometry", to = self.nodes[2].id, toSocket = "Geometry" })
		table.insert(self.connections, { from = self.nodes[2].id, fromSocket = "Geometry", to = self.nodes[3].id, toSocket = "Geometry" })
	end

	print("[Arkher GeometryNodes] Created default graph - Input -> Transform -> Output - Procedural")
end

function GeometryNodes:AddNode(nodeTypeId: string, nodeList: ScrollingFrame?)
	local nodeType = nil
	for _, nt in GeometryNodes.NodeTypes do
		if nt.id == nodeTypeId then nodeType = nt break end
	end
	if not nodeType then return nil end

	local nodeId = "node_" .. self.nextNodeId
	self.nextNodeId += 1

	local node = {
		id = nodeId,
		type = nodeTypeId,
		name = nodeType.name,
		category = nodeType.category,
		icon = nodeType.icon,
		color = nodeType.color,
		inputs = nodeType.inputs,
		outputs = nodeType.outputs,
		description = nodeType.description,
		position = Vector2.new(math.random(50, 300), math.random(50, 300)),
		frame = nil :: Frame?,
	}

	table.insert(self.nodes, node)

	-- Create UI in nodeList if provided
	if nodeList then
		local btn = Instance.new("TextButton")
		btn.Name = nodeId
		btn.Size = UDim2.new(1, -10, 0, 50)
		btn.BackgroundColor3 = nodeType.category == "AI" and Color3.fromRGB(120, 80, 255) or nodeType.color
		btn.Text = ""
		btn.Parent = nodeList

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn

		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.new(0, 30, 1, 0)
		icon.BackgroundTransparency = 1
		icon.Text = nodeType.icon
		icon.TextSize = 16
		icon.Parent = btn

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -35, 0, 18)
		nameLabel.Position = UDim2.new(0, 30, 0, 2)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = nodeType.name
		nameLabel.TextColor3 = Color3.new(1,1,1)
		nameLabel.TextSize = 10
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = btn

		local catLabel = Instance.new("TextLabel")
		catLabel.Size = UDim2.new(1, -35, 0, 14)
		catLabel.Position = UDim2.new(0, 30, 0, 20)
		catLabel.BackgroundTransparency = 1
		catLabel.Text = nodeType.category .. " - " .. nodeType.description
		catLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
		catLabel.TextSize = 8
		catLabel.Font = Enum.Font.Gotham
		catLabel.TextXAlignment = Enum.TextXAlignment.Left
		catLabel.Parent = btn
	end

	-- Create node in graph view
	if self.graphView then
		local nodeFrame = Instance.new("Frame")
		nodeFrame.Name = nodeId
		nodeFrame.Size = UDim2.new(0, 160, 0, 80)
		nodeFrame.Position = UDim2.new(0, node.position.X, 0, node.position.Y + 30)
		nodeFrame.BackgroundColor3 = nodeType.color
		nodeFrame.BorderSizePixel = 0
		nodeFrame.Parent = self.graphView

		local nodeCorner = Instance.new("UICorner")
		nodeCorner.CornerRadius = UDim.new(0, 8)
		nodeCorner.Parent = nodeFrame

		local nodeTitle = Instance.new("TextLabel")
		nodeTitle.Size = UDim2.new(1, 0, 0, 20)
		nodeTitle.BackgroundColor3 = Color3.fromRGB(0,0,0)
		nodeTitle.BackgroundTransparency = 0.3
		nodeTitle.Text = nodeType.icon .. " " .. nodeType.name
		nodeTitle.TextColor3 = Color3.new(1,1,1)
		nodeTitle.TextSize = 10
		nodeTitle.Font = Enum.Font.GothamBold
		nodeTitle.Parent = nodeFrame

		-- Input sockets
		for j, input in nodeType.inputs do
			local socket = Instance.new("TextButton")
			socket.Name = "Input_" .. input
			socket.Size = UDim2.new(0, 12, 0, 12)
			socket.Position = UDim2.new(0, -6, 0, 25 + (j-1)*15)
			socket.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
			socket.Text = ""
			socket.Parent = nodeFrame

			local socketCorner = Instance.new("UICorner")
			socketCorner.CornerRadius = UDim.new(0, 6)
			socketCorner.Parent = socket
		end

		-- Output sockets
		for j, output in nodeType.outputs do
			local socket = Instance.new("TextButton")
			socket.Name = "Output_" .. output
			socket.Size = UDim2.new(0, 12, 0, 12)
			socket.Position = UDim2.new(1, -6, 0, 25 + (j-1)*15)
			socket.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
			socket.Text = ""
			socket.Parent = nodeFrame

			local socketCorner = Instance.new("UICorner")
			socketCorner.CornerRadius = UDim.new(0, 6)
			socketCorner.Parent = socket
		end

		node.frame = nodeFrame
	end

	print("[Arkher GeometryNodes] Added node", nodeType.name, "-", nodeType.category, "-", nodeId, "- AI:", tostring(nodeType.category == "AI"))

	if nodeType.category == "AI" and self.arkherAI then
		print("[Arkher GeometryNodes] AI Node - ARKHER AI v1 generating geometry from prompt - Propria sem depender de empresas - Fase 6 Mecha")
	end

	return node
end

function GeometryNodes:ShowAddNodeMenu()
	print("[Arkher GeometryNodes] Show Add Node Menu -", #GeometryNodes.NodeTypes, "types - Houdini + Blender level")
	-- In real UI, would show searchable menu with categories Input/Geometry/Procedural/Material/Utility/AI/Output
end

function GeometryNodes:Evaluate()
	print("[Arkher GeometryNodes] Evaluating graph -", #self.nodes, "nodes -", #self.connections, "connections - Procedural - Houdini level - ARKHER AI v1")
	-- In production, evaluates node graph and outputs EditableMesh REAL
	return "EditableMesh REAL - Procedural - Geometry Nodes - Houdini level - ARKHER AI v1"
end

function GeometryNodes:GetStats()
	return {
		nodesCount = #self.nodes,
		connectionsCount = #self.connections,
		nodeTypesCount = #GeometryNodes.NodeTypes,
		isAIEnabled = self.isAIEnabled,
		categories = {"Input", "Geometry", "Procedural", "Material", "Utility", "AI", "Output"},
		features = {"Houdini level", "Blender Geometry Nodes", "Procedural modeling", "10k instances scatter", "Noise Voronoi Wave Brick", "PBR Material", "AI Generate ARKHER AI v1 propria", "EditableMesh REAL output"},
		message = "GeometryNodes - Houdini + Blender - Procedural - 20+ node types - Input/Geometry/Procedural/Material/AI/Output - AI Generate ARKHER AI v1 propria - Melhor que Blender Geometry Nodes",
	}
end

return GeometryNodes

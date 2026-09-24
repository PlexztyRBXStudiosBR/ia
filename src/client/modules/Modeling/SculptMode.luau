--!strict
-- Arkher Studio - Fase 3 - SculptMode - Sculpt nível ZBrush dentro do Roblox
-- Brushes: Grab, Smooth, Inflate, Flatten, Pinch

local MeshData = require(game.ReplicatedStorage.Arkher.Modeling.MeshData)
local Shell = require(script.Parent.Parent.UI.Shell)

local SculptMode = {}
SculptMode.__index = SculptMode

export type BrushType = "Grab" | "Smooth" | "Inflate" | "Flatten" | "Pinch" | "Crease"

export type BrushSettings = {
	type: BrushType,
	size: number,
	strength: number,
	falloff: number, -- 0-1
	useSymmetry: boolean,
	symmetryAxis: string,
}

function SculptMode.new()
	return setmetatable({
		brush = {
			type = "Grab" :: BrushType,
			size = 2,
			strength = 0.5,
			falloff = 0.5,
			useSymmetry = false,
			symmetryAxis = "X",
		} :: BrushSettings,
		isSculpting = false,
		frame = nil :: Frame?,
	}, SculptMode)
end

function SculptMode:Init(parent: Frame)
	self.frame = parent

	-- Header brushes
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundColor3 = Shell.Colors.panelLight
	header.Parent = parent

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 100, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "🗿 Sculpt"
	title.TextColor3 = Shell.Colors.text
	title.TextSize = 11
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local brushes: { { id: BrushType, name: string, icon: string } } = {
		{ id = "Grab", name = "Grab", icon = "🫳" },
		{ id = "Smooth", name = "Smooth", icon = "💧" },
		{ id = "Inflate", name = "Inflate", icon = "🎈" },
		{ id = "Flatten", name = "Flatten", icon = "🔨" },
		{ id = "Pinch", name = "Pinch", icon = "🤏" },
	}

	for i, brush in brushes do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 60, 0, 26)
		btn.Position = UDim2.new(0, 110 + (i-1)*65, 0, 5)
		btn.BackgroundColor3 = brush.id == self.brush.type and Shell.Colors.accent or Shell.Colors.panel
		btn.Text = brush.icon .. " " .. brush.name
		btn.TextColor3 = Shell.Colors.text
		btn.TextSize = 9
		btn.Font = Enum.Font.Gotham
		btn.Parent = header

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			self:SetBrush(brush.id)

			for _, other in header:GetChildren() do
				if other:IsA("TextButton") then
					other.BackgroundColor3 = Shell.Colors.panel
				end
			end
			btn.BackgroundColor3 = Shell.Colors.accent
		end)
	end

	-- Settings: Size, Strength
	local settingsFrame = Instance.new("Frame")
	settingsFrame.Size = UDim2.new(1, 0, 0, 50)
	settingsFrame.Position = UDim2.new(0, 0, 0, 36)
	settingsFrame.BackgroundColor3 = Shell.Colors.panel
	settingsFrame.Parent = parent

	-- Size slider
	local sizeLabel = Instance.new("TextLabel")
	sizeLabel.Size = UDim2.new(0, 40, 0, 20)
	sizeLabel.Position = UDim2.new(0, 10, 0, 5)
	sizeLabel.BackgroundTransparency = 1
	sizeLabel.Text = "Size:"
	sizeLabel.TextColor3 = Shell.Colors.textDim
	sizeLabel.TextSize = 10
	sizeLabel.Font = Enum.Font.Gotham
	sizeLabel.TextXAlignment = Enum.TextXAlignment.Left
	sizeLabel.Parent = settingsFrame

	local sizeBox = Instance.new("TextBox")
	sizeBox.Size = UDim2.new(0, 50, 0, 20)
	sizeBox.Position = UDim2.new(0, 50, 0, 5)
	sizeBox.BackgroundColor3 = Shell.Colors.background
	sizeBox.Text = tostring(self.brush.size)
	sizeBox.TextColor3 = Shell.Colors.text
	sizeBox.TextSize = 10
	sizeBox.Font = Enum.Font.Code
	sizeBox.ClearTextOnFocus = false
	sizeBox.Parent = settingsFrame

	sizeBox.FocusLost:Connect(function(enter)
		if enter then
			local num = tonumber(sizeBox.Text)
			if num then
				self.brush.size = num
				print("[Arkher Sculpt] Size ->", num)
			end
		end
	end)

	-- Strength slider
	local strengthLabel = Instance.new("TextLabel")
	strengthLabel.Size = UDim2.new(0, 60, 0, 20)
	strengthLabel.Position = UDim2.new(0, 110, 0, 5)
	strengthLabel.BackgroundTransparency = 1
	strengthLabel.Text = "Strength:"
	strengthLabel.TextColor3 = Shell.Colors.textDim
	strengthLabel.TextSize = 10
	strengthLabel.Font = Enum.Font.Gotham
	strengthLabel.TextXAlignment = Enum.TextXAlignment.Left
	strengthLabel.Parent = settingsFrame

	local strengthBox = Instance.new("TextBox")
	strengthBox.Size = UDim2.new(0, 50, 0, 20)
	strengthBox.Position = UDim2.new(0, 170, 0, 5)
	strengthBox.BackgroundColor3 = Shell.Colors.background
	strengthBox.Text = tostring(self.brush.strength)
	strengthBox.TextColor3 = Shell.Colors.text
	strengthBox.TextSize = 10
	strengthBox.Font = Enum.Font.Code
	strengthBox.ClearTextOnFocus = false
	strengthBox.Parent = settingsFrame

	strengthBox.FocusLost:Connect(function(enter)
		if enter then
			local num = tonumber(strengthBox.Text)
			if num then
				self.brush.strength = math.clamp(num, 0, 1)
				print("[Arkher Sculpt] Strength ->", self.brush.strength)
			end
		end
	end)

	print("[Arkher Sculpt] Initialized - Brushes: Grab, Smooth, Inflate, Flatten, Pinch - Size + Strength")
end

function SculptMode:SetBrush(type: BrushType)
	self.brush.type = type
	print("[Arkher Sculpt] Brush ->", type)
end

function SculptMode:ApplyBrush(mesh: any, hitPosition: Vector3, hitNormal: Vector3): any
	-- Aplica brush no mesh baseado no hit

	print(string.format("[Arkher Sculpt] Applying %s brush at %s - Size: %.1f - Strength: %.1f", self.brush.type, tostring(hitPosition), self.brush.size, self.brush.strength))

	if not mesh then return nil end

	-- Fase 3: Implementação real de sculpt
	-- Para cada vértice dentro do raio size, aplica efeito baseado no tipo

	for id, vert in mesh.vertices do
		local dist = (vert.position - hitPosition).Magnitude

		if dist <= self.brush.size then
			local falloff = 1 - (dist / self.brush.size)
			falloff = falloff ^ self.brush.falloff

			local strength = self.brush.strength * falloff

			if self.brush.type == "Grab" then
				-- Move vértice na direção do normal
				vert.position += hitNormal * strength

			elseif self.brush.type == "Inflate" then
				-- Infla ao longo do normal do vértice
				vert.position += vert.normal * strength

			elseif self.brush.type == "Smooth" then
				-- Suaviza com média dos vizinhos (mock)
				-- Em produção, calcula média real

			elseif self.brush.type == "Flatten" then
				-- Achata no plano do hit
				local toVert = vert.position - hitPosition
				local dot = toVert:Dot(hitNormal)
				vert.position -= hitNormal * dot * strength

			elseif self.brush.type == "Pinch" then
				-- Puxa para o centro do brush
				local dir = (hitPosition - vert.position).Unit
				vert.position += dir * strength * 0.5
			end
		end
	end

	return mesh
end

function SculptMode:GetBrush(): BrushSettings
	return self.brush
end

return SculptMode

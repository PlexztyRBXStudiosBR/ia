--!strict
-- Arkher Studio - Onboarding - Polimento Total - UI amigavel iniciantes
-- Inspirado no melhor: Figma onboarding, Notion, Blender splash, Unreal learning
-- Mas nosso: amigavel pra iniciantes, intermediarios, avancados, com ARKHER AI v1

local ThemeSystem = require(script.Parent.ThemeSystem)

local Onboarding = {}
Onboarding.__index = Onboarding

Onboarding.Steps = {
	Beginner = {
		{ id = "welcome", title = "Bem-vindo ao Arkher Studio! 🎉", description = "O engine que mata Roblox Studio - Crie jogos AAA no seu perfil, até no A01!", icon = "🚀", action = "next" },
		{ id = "move", title = "Mova-se no mundo 🌍", description = "Arraste para olhar ao redor. Use WASD para mover. No mobile, use um dedo para olhar, dois para mover.", icon = "👋", action = "try" },
		{ id = "select", title = "Selecione objetos 👆", description = "Clique em objetos no mundo para selecionar. No mobile, toque. Veja propriedades no painel Details.", icon = "📦", action = "try" },
		{ id = "add", title = "Adicione objetos 🧰", description = "Vá em 'Add Objects' e clique em um objeto para adicionar ao mundo. Temos 120 assets AAA!", icon = "➕", action = "try" },
		{ id = "make3d", title = "Crie 3D com IA 🤖", description = "Vá em 'Make 3D' e clique 'AI Generate' - digite 'katana cyberpunk' e ARKHER AI v1 cria pra você! Nossa IA própria 3.98M params.", icon = "🎨", action = "try" },
		{ id = "play", title = "Teste seu jogo ▶️", description = "Clique PLAY para testar seu jogo! Veja como ficou.", icon = "🎮", action = "play" },
		{ id = "publish", title = "Publique! 🚀", description = "Clique Publish para publicar seu jogo real no seu perfil Roblox! Vira jogo de verdade.", icon = "🌟", action = "publish" },
		{ id = "ai", title = "Peça ajuda pra IA 🤖", description = "Clique no botão AI e converse com ARKHER AI v1 - nossa IA própria sem depender de empresas! Ela ajuda em tudo: modelo, animação, terreno, script.", icon = "💬", action = "ai" },
	},
	Intermediate = {
		{ id = "welcome", title = "Arkher Studio - Intermediate", description = "Você já sabe o básico! Vamos pro nível pro: Modeler Blender++, Animator GTA 6, Terrain Mecha, Monaco Pro + ARKHER AI v1", icon = "🚀", action = "next" },
		{ id = "modeler", title = "Arkher Engineer - Blender++ 🎨", description = "60+ tools vs Blender 30 - 20+ brushes ZBrush - Geometry Nodes Houdini - UV - PBR - AI Generate com ARKHER AI v1 própria", icon = "🎨", action = "open_modeler" },
		{ id = "animator", title = "Arkher Motion - GTA 6 🎬", description = "Cutscene editor GTA 6 + Unreal 6 Sequencer + Cascadeur - Pode animar TUDO: rigs, tools, effects, sky, decals, lights, camera - Physics atomic/quantum backend IA - Curve humanized", icon = "🎬", action = "open_animator" },
		{ id = "terrain", title = "Terrain World Creator + Mecha 🏔️", description = "World Creator + Mecha Engine custom - chunked 32x32x32 infinite - Greedy Meshing 10x + Dual Contouring - Erosion - Biomes 7 - 15GB - ARKHER AI v1 terrain gen", icon = "🏔️", action = "open_terrain" },
		{ id = "script", title = "Monaco Pro + ARKHER AI v1 📜", description = "VS Code level + 25 plugins - ESLint, Prettier, IntelliSense, GitLens, Vim, Emmet, Copilot ARKHER AI v1 própria 3.98M params", icon = "📜", action = "open_script" },
		{ id = "command", title = "Command Palette Ctrl+K ⌘", description = "Pressione Ctrl+K para abrir Command Palette - 50+ comandos - Fuzzy search - Beginner to Pro", icon = "⌘", action = "command" },
	},
	Advanced = {
		{ id = "welcome", title = "Arkher Studio - Advanced/Pro", description = "Nível pro: Geometry Nodes, Curve Editor humanized Unreal 6 + Cascadeur, Cutscene GTA 6 4K 60 FPS, Physics atomic/quantum, Auto Rig, 15GB, ANG DLSS 4+5, Mecha Engine Custom", icon = "🚀", action = "next" },
		{ id = "physics", title = "Physics atomic/quantum ⚛️", description = "Newtonian, RigidBody Rapier, SoftBody FEM, Cloth PBD, Fluid Navier-Stokes, Hair Cosserat, Muscle Hill, Atomic Schrödinger, Quantum superposition, Relativistic E=mc² - Backend IA knowledge", icon = "⚛️", action = "physics" },
		{ id = "nodes", title = "Geometry Nodes 🌿", description = "Houdini level - Procedural modeling - Nodes - Melhor que Blender", icon = "🌿", action = "nodes" },
		{ id = "curve", title = "Curve Editor humanized 📈", description = "Unreal 6 + Cascadeur - Humanized = real human motion from mocap + physics + ARKHER AI v1 trained - GTA 6 level", icon = "📈", action = "curve" },
		{ id = "cutscene", title = "Cutscene GTA 6 🎬", description = "Rockstar level - Camera cuts, Character acting, Facial, Lip sync, Lighting cinematic, VFX, Dialogue, Subtitles, 4K 60 FPS", icon = "🎬", action = "cutscene" },
		{ id = "arkherai", title = "ARKHER AI v1 própria 🤖", description = "3.98M params - v0.1.0-gamedev - BPE próprio - Transformer 4 layers - Sem depender de empresas - Game dev focus - 3D generation próprio - Fase 6 Mecha - https://github.com/PlexztyRBXStudiosBR/ARKHERAI_resynced", icon = "🤖", action = "ai" },
	},
}

function Onboarding.new(themeSystem: any, level: string?)
	return setmetatable({
		themeSystem = themeSystem,
		level = level or "Beginner",
		currentStep = 1,
		isActive = false,
		frame = nil :: Frame?,
		completed = {} :: { [string]: boolean },
	}, Onboarding)
end

function Onboarding:Init(parent: ScreenGui)
	local colors = self.themeSystem:GetColors()

	local overlay = Instance.new("Frame")
	overlay.Name = "OnboardingOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.6
	overlay.Visible = false
	overlay.ZIndex = 200
	overlay.Parent = parent

	local card = Instance.new("Frame")
	card.Name = "OnboardingCard"
	card.Size = UDim2.new(0, 400, 0, 300)
	card.Position = UDim2.new(0.5, -200, 0.5, -150)
	card.BackgroundColor3 = colors.panel
	card.BorderSizePixel = 0
	card.ZIndex = 201
	card.Parent = overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.accent
	stroke.Thickness = 2
	stroke.Parent = card

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(1, 0, 0, 60)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = "🚀"
	iconLabel.TextSize = 40
	iconLabel.Parent = card

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -20, 0, 30)
	titleLabel.Position = UDim2.new(0, 10, 0, 60)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Bem-vindo ao Arkher Studio!"
	titleLabel.TextColor3 = colors.text
	titleLabel.TextSize = 16
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextWrapped = true
	titleLabel.Parent = card

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Description"
	descLabel.Size = UDim2.new(1, -20, 0, 80)
	descLabel.Position = UDim2.new(0, 10, 0, 90)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = "O engine que mata Roblox Studio"
	descLabel.TextColor3 = colors.textDim
	descLabel.TextSize = 12
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextWrapped = true
	descLabel.Parent = card

	local nextBtn = Instance.new("TextButton")
	nextBtn.Name = "NextBtn"
	nextBtn.Size = UDim2.new(0.5, -15, 0, 36)
	nextBtn.Position = UDim2.new(0.5, 5, 1, -50)
	nextBtn.BackgroundColor3 = colors.accent
	nextBtn.Text = "Next →"
	nextBtn.TextColor3 = Color3.new(1,1,1)
	nextBtn.TextSize = 13
	nextBtn.Font = Enum.Font.GothamBold
	nextBtn.Parent = card

	local nextCorner = Instance.new("UICorner")
	nextCorner.CornerRadius = UDim.new(0, 8)
	nextCorner.Parent = nextBtn

	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipBtn"
	skipBtn.Size = UDim2.new(0.5, -15, 0, 36)
	skipBtn.Position = UDim2.new(0, 10, 1, -50)
	skipBtn.BackgroundColor3 = colors.panelLight
	skipBtn.Text = "Skip"
	skipBtn.TextColor3 = colors.text
	skipBtn.TextSize = 12
	skipBtn.Font = Enum.Font.Gotham
	skipBtn.Parent = card

	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 8)
	skipCorner.Parent = skipBtn

	self.frame = overlay

	nextBtn.MouseButton1Click:Connect(function() self:Next() end)
	skipBtn.MouseButton1Click:Connect(function() self:Close() end)

	print("[Arkher Onboarding] Initialized - Level:", self.level, "- Steps:", #Onboarding.Steps[self.level])
end

function Onboarding:Start(level: string?)
	self.level = level or self.level
	self.currentStep = 1
	self.isActive = true
	if self.frame then self.frame.Visible = true end
	self:ShowStep(self.currentStep)
	print("[Arkher Onboarding] Started - Level:", self.level)
end

function Onboarding:ShowStep(stepIndex: number)
	local steps = Onboarding.Steps[self.level]
	if not steps or not steps[stepIndex] then
		self:Close()
		return
	end

	local step = steps[stepIndex]
	if not self.frame then return end

	local card = self.frame:FindFirstChild("OnboardingCard")
	if not card then return end

	local icon = card:FindFirstChild("Icon") :: TextLabel
	local title = card:FindFirstChild("Title") :: TextLabel
	local desc = card:FindFirstChild("Description") :: TextLabel
	local nextBtn = card:FindFirstChild("NextBtn") :: TextButton

	if icon then icon.Text = step.icon end
	if title then title.Text = step.title end
	if desc then desc.Text = step.description end
	if nextBtn then nextBtn.Text = stepIndex == #steps and "Finish 🎉" or "Next →"

	end

	print("[Arkher Onboarding] Step", stepIndex, "/", #steps, "-", step.title)
end

function Onboarding:Next()
	local steps = Onboarding.Steps[self.level]
	if self.currentStep >= #steps then
		self:Close()
		return
	end

	self.currentStep += 1
	self:ShowStep(self.currentStep)
end

function Onboarding:Close()
	if self.frame then self.frame.Visible = false end
	self.isActive = false
	print("[Arkher Onboarding] Closed - Completed onboarding for", self.level)
end

function Onboarding:GetStats()
	return {
		level = self.level,
		currentStep = self.currentStep,
		isActive = self.isActive,
		totalSteps = Onboarding.Steps[self.level] and #Onboarding.Steps[self.level] or 0,
		message = "Onboarding - Beginner/Intermediate/Advanced - Figma + Notion + Blender + Unreal - Friendly - ARKHER AI v1",
	}
end

return Onboarding

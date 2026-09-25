--!strict
-- Arkher Studio - ThemeSystem - Polimento Total Fase 0-4
-- Sistema de temas inspirado em Unreal 5, VS Code, Blender - mas nosso
-- Suporta Dark, Light, Midnight, OLED, High Contrast + Custom
-- Adaptativo por device e nivel (beginner/intermediate/advanced)

local ThemeSystem = {}
ThemeSystem.__index = ThemeSystem

export type ThemeName = "Dark" | "Light" | "Midnight" | "OLED" | "HighContrast" | "Unreal" | "Blender" | "Arkher"
export type UserLevel = "Beginner" | "Intermediate" | "Advanced" | "Pro"

ThemeSystem.Themes = {
	Dark = {
		name = "Dark - Arkher Default",
		background = Color3.fromRGB(20, 20, 20),
		backgroundSecondary = Color3.fromRGB(30, 30, 30),
		panel = Color3.fromRGB(35, 35, 35),
		panelLight = Color3.fromRGB(45, 45, 45),
		panelHover = Color3.fromRGB(55, 55, 55),
		border = Color3.fromRGB(55, 55, 55),
		accent = Color3.fromRGB(0, 120, 215),
		accentHover = Color3.fromRGB(0, 140, 255),
		accentSecondary = Color3.fromRGB(100, 80, 255),
		text = Color3.fromRGB(230, 230, 230),
		textDim = Color3.fromRGB(150, 150, 150),
		textBright = Color3.fromRGB(255, 255, 255),
		success = Color3.fromRGB(0, 200, 100),
		warning = Color3.fromRGB(255, 180, 0),
		error = Color3.fromRGB(255, 60, 60),
		selection = Color3.fromRGB(38, 79, 120),
		shadow = Color3.fromRGB(0, 0, 0),
		-- Modeler
		modelerPrimary = Color3.fromRGB(200, 100, 255),
		-- Animator
		animatorPrimary = Color3.fromRGB(255, 100, 100),
		-- Terrain
		terrainPrimary = Color3.fromRGB(100, 200, 100),
		-- Script
		scriptPrimary = Color3.fromRGB(55, 118, 171),
		-- AI
		aiPrimary = Color3.fromRGB(255, 180, 0),
	},
	Light = {
		name = "Light - Clean",
		background = Color3.fromRGB(245, 245, 245),
		backgroundSecondary = Color3.fromRGB(255, 255, 255),
		panel = Color3.fromRGB(230, 230, 230),
		panelLight = Color3.fromRGB(220, 220, 220),
		panelHover = Color3.fromRGB(210, 210, 210),
		border = Color3.fromRGB(200, 200, 200),
		accent = Color3.fromRGB(0, 100, 200),
		accentHover = Color3.fromRGB(0, 120, 230),
		accentSecondary = Color3.fromRGB(80, 60, 200),
		text = Color3.fromRGB(30, 30, 30),
		textDim = Color3.fromRGB(100, 100, 100),
		textBright = Color3.fromRGB(0, 0, 0),
		success = Color3.fromRGB(0, 150, 80),
		warning = Color3.fromRGB(200, 140, 0),
		error = Color3.fromRGB(200, 40, 40),
		selection = Color3.fromRGB(180, 210, 255),
		shadow = Color3.fromRGB(0, 0, 0),
		modelerPrimary = Color3.fromRGB(150, 80, 200),
		animatorPrimary = Color3.fromRGB(200, 80, 80),
		terrainPrimary = Color3.fromRGB(80, 160, 80),
		scriptPrimary = Color3.fromRGB(40, 90, 140),
		aiPrimary = Color3.fromRGB(200, 140, 0),
	},
	Midnight = {
		name = "Midnight - Pro Focus",
		background = Color3.fromRGB(10, 10, 15),
		backgroundSecondary = Color3.fromRGB(18, 18, 24),
		panel = Color3.fromRGB(22, 22, 30),
		panelLight = Color3.fromRGB(30, 30, 40),
		panelHover = Color3.fromRGB(40, 40, 50),
		border = Color3.fromRGB(45, 45, 60),
		accent = Color3.fromRGB(90, 70, 255),
		accentHover = Color3.fromRGB(110, 90, 255),
		accentSecondary = Color3.fromRGB(255, 100, 150),
		text = Color3.fromRGB(220, 220, 235),
		textDim = Color3.fromRGB(130, 130, 150),
		textBright = Color3.fromRGB(255, 255, 255),
		success = Color3.fromRGB(0, 220, 120),
		warning = Color3.fromRGB(255, 200, 50),
		error = Color3.fromRGB(255, 80, 80),
		selection = Color3.fromRGB(60, 50, 120),
		shadow = Color3.fromRGB(0, 0, 0),
		modelerPrimary = Color3.fromRGB(180, 80, 255),
		animatorPrimary = Color3.fromRGB(255, 80, 120),
		terrainPrimary = Color3.fromRGB(80, 200, 120),
		scriptPrimary = Color3.fromRGB(80, 120, 200),
		aiPrimary = Color3.fromRGB(255, 200, 50),
	},
	OLED = {
		name = "OLED - Pure Black",
		background = Color3.fromRGB(0, 0, 0),
		backgroundSecondary = Color3.fromRGB(10, 10, 10),
		panel = Color3.fromRGB(18, 18, 18),
		panelLight = Color3.fromRGB(28, 28, 28),
		panelHover = Color3.fromRGB(38, 38, 38),
		border = Color3.fromRGB(40, 40, 40),
		accent = Color3.fromRGB(255, 255, 255),
		accentHover = Color3.fromRGB(220, 220, 220),
		accentSecondary = Color3.fromRGB(180, 180, 180),
		text = Color3.fromRGB(255, 255, 255),
		textDim = Color3.fromRGB(160, 160, 160),
		textBright = Color3.fromRGB(255, 255, 255),
		success = Color3.fromRGB(0, 255, 130),
		warning = Color3.fromRGB(255, 220, 0),
		error = Color3.fromRGB(255, 50, 50),
		selection = Color3.fromRGB(50, 50, 50),
		shadow = Color3.fromRGB(0, 0, 0),
		modelerPrimary = Color3.fromRGB(255, 255, 255),
		animatorPrimary = Color3.fromRGB(255, 255, 255),
		terrainPrimary = Color3.fromRGB(255, 255, 255),
		scriptPrimary = Color3.fromRGB(255, 255, 255),
		aiPrimary = Color3.fromRGB(255, 255, 255),
	},
	Arkher = {
		name = "Arkher - Signature",
		background = Color3.fromRGB(12, 12, 20),
		backgroundSecondary = Color3.fromRGB(20, 20, 32),
		panel = Color3.fromRGB(28, 28, 42),
		panelLight = Color3.fromRGB(38, 38, 55),
		panelHover = Color3.fromRGB(48, 48, 68),
		border = Color3.fromRGB(60, 60, 80),
		accent = Color3.fromRGB(120, 80, 255),
		accentHover = Color3.fromRGB(140, 100, 255),
		accentSecondary = Color3.fromRGB(0, 220, 180),
		text = Color3.fromRGB(235, 235, 250),
		textDim = Color3.fromRGB(140, 140, 165),
		textBright = Color3.fromRGB(255, 255, 255),
		success = Color3.fromRGB(0, 230, 140),
		warning = Color3.fromRGB(255, 190, 60),
		error = Color3.fromRGB(255, 70, 90),
		selection = Color3.fromRGB(70, 60, 140),
		shadow = Color3.fromRGB(0, 0, 0),
		modelerPrimary = Color3.fromRGB(160, 90, 255),
		animatorPrimary = Color3.fromRGB(255, 90, 120),
		terrainPrimary = Color3.fromRGB(90, 220, 120),
		scriptPrimary = Color3.fromRGB(80, 140, 255),
		aiPrimary = Color3.fromRGB(255, 200, 60),
	},
}

ThemeSystem.LevelConfig = {
	Beginner = {
		showTooltips = true,
		showLabels = true,
		showHints = true,
		simplifiedToolbar = true,
		largeButtons = true,
		showTutorials = true,
		autoHelp = true,
		confirmDestructive = true,
		panelDensity = "comfortable",
		iconSize = 24,
		fontSize = 13,
	},
	Intermediate = {
		showTooltips = true,
		showLabels = true,
		showHints = false,
		simplifiedToolbar = false,
		largeButtons = false,
		showTutorials = false,
		autoHelp = false,
		confirmDestructive = true,
		panelDensity = "compact",
		iconSize = 20,
		fontSize = 12,
	},
	Advanced = {
		showTooltips = false,
		showLabels = false,
		showHints = false,
		simplifiedToolbar = false,
		largeButtons = false,
		showTutorials = false,
		autoHelp = false,
		confirmDestructive = false,
		panelDensity = "dense",
		iconSize = 18,
		fontSize = 11,
	},
	Pro = {
		showTooltips = false,
		showLabels = false,
		showHints = false,
		simplifiedToolbar = false,
		largeButtons = false,
		showTutorials = false,
		autoHelp = false,
		confirmDestructive = false,
		panelDensity = "ultra-dense",
		iconSize = 16,
		fontSize = 10,
	},
}

function ThemeSystem.new(initialTheme: ThemeName?, initialLevel: UserLevel?)
	local self = setmetatable({
		currentTheme = initialTheme or "Arkher" :: ThemeName,
		currentLevel = initialLevel or "Intermediate" :: UserLevel,
		listeners = {} :: { (ThemeName, UserLevel) -> () },
	}, ThemeSystem)
	return self
end

function ThemeSystem:GetColors()
	return ThemeSystem.Themes[self.currentTheme] or ThemeSystem.Themes.Arkher
end

function ThemeSystem:GetLevelConfig()
	return ThemeSystem.LevelConfig[self.currentLevel]
end

function ThemeSystem:SetTheme(theme: ThemeName)
	self.currentTheme = theme
	for _, cb in self.listeners do
		task.spawn(cb, theme, self.currentLevel)
	end
	print("[Arkher Theme] Theme ->", theme)
end

function ThemeSystem:SetLevel(level: UserLevel)
	self.currentLevel = level
	for _, cb in self.listeners do
		task.spawn(cb, self.currentTheme, level)
	end
	print("[Arkher Theme] Level ->", level)
end

function ThemeSystem:OnChanged(cb: (ThemeName, UserLevel) -> ())
	table.insert(self.listeners, cb)
end

function ThemeSystem:ApplyToFrame(frame: Frame)
	local colors = self:GetColors()
	if frame:IsA("Frame") then
		frame.BackgroundColor3 = colors.panel
	end
end

function ThemeSystem:CreateStyledButton(name: string, text: string, colorType: string?): TextButton
	local colors = self:GetColors()
	local level = self:GetLevelConfig()
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Text = text
	btn.TextColor3 = colors.text
	btn.TextSize = level.fontSize
	btn.Font = Enum.Font.Gotham
	btn.BackgroundColor3 = colorType == "accent" and colors.accent or colorType == "success" and colors.success or colors.panelLight
	btn.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, level.panelDensity == "comfortable" and 8 or 4)
	corner.Parent = btn

	return btn
end

function ThemeSystem:GetStats()
	return {
		theme = self.currentTheme,
		level = self.currentLevel,
		colors = self:GetColors().name,
		levelConfig = self:GetLevelConfig(),
		message = "ThemeSystem - Polimento Total - Beginner/Intermediate/Advanced/Pro + Dark/Light/Midnight/OLED/Arkher",
	}
end

return ThemeSystem

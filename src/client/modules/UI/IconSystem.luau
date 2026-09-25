--!strict
-- Arkher Studio - IconSystem - Pixel Art Icons sem Emojis - BETA FINAL Fix UI feia bugada
-- Ícones desenhados por Frame pixel art 8x8, 10x10, 12x12 - Sem emojis, apenas pixel art ou imagem via Frame

local IconSystem = {}
IconSystem.__index = IconSystem

-- Paleta pixel art Arkher - 16 cores
local PALETTE = {
	background = Color3.fromRGB(20, 20, 30),
	foreground = Color3.fromRGB(230, 230, 240),
	accent = Color3.fromRGB(120, 100, 255),
	success = Color3.fromRGB(80, 200, 120),
	warning = Color3.fromRGB(255, 200, 50),
	error = Color3.fromRGB(255, 80, 80),
	ai = Color3.fromRGB(100, 220, 255),
	modeler = Color3.fromRGB(200, 100, 255),
	animator = Color3.fromRGB(255, 100, 100),
	terrain = Color3.fromRGB(100, 200, 100),
	script = Color3.fromRGB(255, 200, 100),
}

-- Definições pixel art 8x8 - cada string linha, cada char pixel
-- . = transparente, # = cor principal, @ = cor secundária, * = destaque
local ICONS_8x8 = {
	-- Save - disquete 8x8
	save = {
		"........",
		".######.",
		".#....#.",
		".#....#.",
		".######.",
		".#@@@@#.",
		".#@@@@#.",
		".######.",
		colors = { ["#"] = Color3.fromRGB(200,200,220), ["@"] = Color3.fromRGB(120,100,255) }
	},
	-- Play - triangulo
	play = {
		"........",
		".#......",
		".##.....",
		".###....",
		".####...",
		".###....",
		".##.....",
		".#......",
		colors = { ["#"] = Color3.fromRGB(80,200,120) }
	},
	-- Publish - foguete
	publish = {
		"...#....",
		"..###...",
		"..###...",
		".#####..",
		".#####..",
		"..###...",
		".#...#..",
		".#...#..",
		colors = { ["#"] = Color3.fromRGB(120,100,255) }
	},
	-- Help - ?
	help = {
		".####...",
		"#....#..",
		"....#...",
		"...#....",
		"..#.....",
		"........",
		"..#.....",
		"........",
		colors = { ["#"] = Color3.fromRGB(255,220,100) }
	},
	-- AI - cabeca robo
	ai = {
		".######.",
		"#......#",
		"#.#..#.#",
		"#......#",
		"#.#..#.#",
		"#..##..#",
		".######.",
		"........",
		colors = { ["#"] = Color3.fromRGB(100,220,255) }
	},
	-- Style - paleta
	style = {
		"..####..",
		".#....#.",
		"#.#..#.#",
		"#......#",
		"#..##..#",
		".#....#.",
		"..####..",
		"........",
		colors = { ["#"] = Color3.fromRGB(255,150,200) }
	},
	-- Search - lupa
	search = {
		".####...",
		"#....#..",
		"#....#..",
		".####...",
		"...#....",
		"..#.#...",
		".#...#..",
		"#.....#.",
		colors = { ["#"] = Color3.fromRGB(180,180,200) }
	},
	-- Add - +
	add = {
		"........",
		"...#....",
		"...#....",
		".#####..",
		"...#....",
		"...#....",
		"........",
		"........",
		colors = { ["#"] = Color3.fromRGB(80,200,120) }
	},
	-- Filter - funil
	filter = {
		"#######.",
		".#####..",
		"..###...",
		"..###...",
		"...#....",
		"...#....",
		"...#....",
		"........",
		colors = { ["#"] = Color3.fromRGB(200,200,220) }
	},
	-- Move - setas
	move = {
		"...#....",
		"..###...",
		".#.#.#..",
		"#######.",
		".#.#.#..",
		"..###...",
		"...#....",
		"........",
		colors = { ["#"] = Color3.fromRGB(100,150,255) }
	},
	-- Rotate - seta circular
	rotate = {
		"..####..",
		".#....#.",
		"#......#",
		"#......#",
		"#...##.#",
		".#..#.#.",
		"..##.#..",
		"....#...",
		colors = { ["#"] = Color3.fromRGB(100,200,255) }
	},
	-- Scale - expandir
	scale = {
		"#.....#.",
		".#...#..",
		"..#.#...",
		"...#....",
		"...#....",
		"..#.#...",
		".#...#..",
		"#.....#.",
		colors = { ["#"] = Color3.fromRGB(255,200,100) }
	},
	-- World/Outliner - globo lista
	world = {
		"..####..",
		".#....#.",
		"#.#..#.#",
		"#......#",
		"#.#..#.#",
		"#......#",
		".#....#.",
		"..####..",
		colors = { ["#"] = Color3.fromRGB(100,200,100) }
	},
	-- Details - sliders
	details = {
		"........",
		"####....",
		"...#....",
		".####...",
		"....#...",
		"####....",
		"........",
		"........",
		colors = { ["#"] = Color3.fromRGB(200,200,220) }
	},
	-- Vault - diamante
	vault = {
		"...#....",
		"..###...",
		".#####..",
		"#######.",
		".#####..",
		"..###...",
		"...#....",
		"........",
		colors = { ["#"] = Color3.fromRGB(120,100,255) }
	},
	-- Toolbox - caixa ferramentas
	toolbox = {
		".######.",
		"#......#",
		"#.####.#",
		"#.#..#.#",
		"#.####.#",
		"#......#",
		".######.",
		"........",
		colors = { ["#"] = Color3.fromRGB(200,180,100) }
	},
	-- Modeler/Engineer - martelo chave
	engineer = {
		"#....#..",
		".#..#...",
		"..##....",
		"..##....",
		".#..#...",
		"#....#..",
		".....##.",
		"....#...",
		colors = { ["#"] = Color3.fromRGB(200,100,255) }
	},
	-- Motion/Animator - filme
	motion = {
		"########",
		"#......#",
		"#.#..#.#",
		"#......#",
		"#.#..#.#",
		"#......#",
		"########",
		"........",
		colors = { ["#"] = Color3.fromRGB(255,100,100) }
	},
	-- Terrain/World - montanha
	terrain = {
		"........",
		"...#....",
		"..###...",
		".#.#.#..",
		"#..#..#.",
		"#######.",
		"........",
		"........",
		colors = { ["#"] = Color3.fromRGB(100,200,100) }
	},
	-- Script/Code - <>
	code = {
		"........",
		"..##....",
		".#..#...",
		"#....#..",
		"#....#..",
		".#..#...",
		"..##....",
		"........",
		colors = { ["#"] = Color3.fromRGB(255,200,100) }
	},
	-- Project - pasta
	project = {
		"####....",
		"#...####",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"########",
		"........",
		colors = { ["#"] = Color3.fromRGB(255,220,100) }
	},
	-- Stats - grafico
	stats = {
		"........",
		"#.......",
		"#.#.....",
		"#.#.#...",
		"#.#.#.#.",
		"#######.",
		"........",
		"........",
		colors = { ["#"] = Color3.fromRGB(100,200,255) }
	},
	-- Command - K
	command = {
		"#...#...",
		"#..#....",
		"#.#.....",
		"##......",
		"#.#.....",
		"#..#....",
		"#...#...",
		"........",
		colors = { ["#"] = Color3.fromRGB(180,180,200) }
	},
	-- Close X
	close = {
		"#.....#.",
		".#...#..",
		"..#.#...",
		"...#....",
		"..#.#...",
		".#...#..",
		"#.....#.",
		"........",
		colors = { ["#"] = Color3.fromRGB(255,80,80) }
	},
	-- Check
	check = {
		"........",
		".....#..",
		"....##..",
		"...#.#..",
		"..#..#..",
		".#...#..",
		"#....#..",
		"........",
		colors = { ["#"] = Color3.fromRGB(80,200,120) }
	},
	-- Cloud
	cloud = {
		"........",
		"..####..",
		".#....#.",
		"#......#",
		"#......#",
		".######.",
		"........",
		"........",
		colors = { ["#"] = Color3.fromRGB(100,180,255) }
	},
	-- Marketplace - loja
	market = {
		".######.",
		"#......#",
		"#.####.#",
		"#.#..#.#",
		"#......#",
		"#.####.#",
		"#......#",
		".######.",
		colors = { ["#"] = Color3.fromRGB(255,180,50) }
	},
	-- Export - caixa saindo
	export = {
		".######.",
		"#......#",
		"#..##..#",
		"#..##..#",
		"#......#",
		".######.",
		"....#...",
		"...###..",
		colors = { ["#"] = Color3.fromRGB(100,200,255) }
	},
	-- Collab - pessoas
	collab = {
		".#...#..",
		"#.#.#.#.",
		".#...#..",
		"........",
		".#####..",
		"#.....#.",
		"#.....#.",
		".#####..",
		colors = { ["#"] = Color3.fromRGB(200,200,100) }
	},
	-- Audio - nota musical
	audio = {
		"....#...",
		"....#...",
		"....#...",
		"....#...",
		".#######",
		".#.....#",
		".#.....#",
		"..#####.",
		colors = { ["#"] = Color3.fromRGB(255,150,100) }
	},
	-- Net - rede
	net = {
		"#..#..#.",
		".##.##..",
		"#..#..#.",
		".##.##..",
		"#..#..#.",
		".##.##..",
		"#..#..#.",
		"........",
		colors = { ["#"] = Color3.fromRGB(100,255,150) }
	},
	-- Mecha - engrenagem
	mecha = {
		"..#.#...",
		".#####..",
		"#.....#.",
		"#..#..#.",
		"#.....#.",
		".#####..",
		"..#.#...",
		"........",
		colors = { ["#"] = Color3.fromRGB(200,200,200) }
	},
	-- A01 - celular
	a01 = {
		".####...",
		"#....#..",
		"#....#..",
		"#....#..",
		"#....#..",
		"#.##.#..",
		".####...",
		"........",
		colors = { ["#"] = Color3.fromRGB(100,200,100) }
	},
}

-- Ícones 10x10 mais detalhados
local ICONS_10x10 = {
	arkher = {
		"..........",
		"..######..",
		".#......#.",
		"#..####..#",
		"#..#..#..#",
		"#..####..#",
		"#........#",
		".#......#.",
		"..######..",
		"..........",
		colors = { ["#"] = Color3.fromRGB(120,100,255) }
	}
}

function IconSystem.new()
	return setmetatable({
		palette = PALETTE,
		icons8 = ICONS_8x8,
		icons10 = ICONS_10x10,
	}, IconSystem)
end

-- Cria ícone pixel art usando Frames
function IconSystem:CreateIcon(iconName: string, parent: Instance?, size: number?, colorOverride: Color3?): Frame
	local iconData = ICONS_8x8[iconName] or ICONS_10x10[iconName]
	if not iconData then
		warn("[Arkher IconSystem] Icon not found:", iconName, "- using default")
		iconData = ICONS_8x8["help"]
	end
	
	local pixelSize = size or 16
	local gridSize = #iconData
	if iconName == "arkher" then gridSize = 10 end
	
	-- Container
	local container = Instance.new("Frame")
	container.Name = "Icon_" .. iconName
	container.Size = UDim2.new(0, pixelSize, 0, pixelSize)
	container.BackgroundTransparency = 1
	container.ClipsDescendants = true
	if parent then
		container.Parent = parent
	end
	
	-- Calcular tamanho de cada pixel
	local pixelDim = pixelSize / gridSize
	
	for row = 1, gridSize do
		local line = iconData[row]
		if not line then continue end
		-- Se for tabela colors, pula
		if typeof(line) ~= "string" then continue end
		
		for col = 1, #line do
			local char = line:sub(col, col)
			if char == "." then continue end -- transparente
			
			local pixel = Instance.new("Frame")
			pixel.Name = string.format("P_%d_%d", row, col)
			pixel.Size = UDim2.new(0, math.ceil(pixelDim), 0, math.ceil(pixelDim))
			pixel.Position = UDim2.new(0, (col-1)*pixelDim, 0, (row-1)*pixelDim)
			pixel.BorderSizePixel = 0
			pixel.ZIndex = 2
			
			-- Cor
			local colData = iconData.colors
			local pixelColor = Color3.new(1,1,1)
			if colData and colData[char] then
				pixelColor = colData[char]
			elseif char == "#" then
				pixelColor = colorOverride or Color3.fromRGB(230,230,240)
			elseif char == "@" then
				pixelColor = Color3.fromRGB(120,100,255)
			elseif char == "*" then
				pixelColor = Color3.fromRGB(255,200,50)
			else
				pixelColor = Color3.fromRGB(200,200,200)
			end
			
			if colorOverride and char == "#" then
				pixelColor = colorOverride
			end
			
			pixel.BackgroundColor3 = pixelColor
			pixel.Parent = container
		end
	end
	
	return container
end

-- Cria botão com ícone + texto sem emoji
function IconSystem:CreateIconButton(iconName: string, text: string, size: UDim2, position: UDim2, bgColor: Color3?, textColor: Color3?, parent: Instance?): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = text:gsub(" ", "") .. "Btn_" .. iconName
	btn.Size = size
	btn.Position = position
	btn.BackgroundColor3 = bgColor or Color3.fromRGB(45,45,65)
	btn.Text = ""
	btn.AutoButtonColor = true
	if parent then btn.Parent = parent end
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn
	
	-- Ícone
	local icon = self:CreateIcon(iconName, btn, 16)
	icon.Position = UDim2.new(0, 6, 0.5, -8)
	icon.AnchorPoint = Vector2.new(0, 0)
	
	-- Texto sem emoji
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -28, 1, 0)
	label.Position = UDim2.new(0, 26, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(230,230,230)
	label.TextSize = 11
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncated = true
	label.Parent = btn
	
	return btn
end

-- Cria ícone com label vertical (para toolbar mobile)
function IconSystem:CreateIconWithLabel(iconName: string, labelText: string, parent: Instance?): Frame
	local container = Instance.new("Frame")
	container.Name = "IconWithLabel_" .. iconName
	container.Size = UDim2.new(0, 50, 0, 50)
	container.BackgroundTransparency = 1
	if parent then container.Parent = parent end
	
	local icon = self:CreateIcon(iconName, container, 24)
	icon.Position = UDim2.new(0.5, -12, 0, 2)
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 16)
	label.Position = UDim2.new(0, 0, 0, 30)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(200,200,200)
	label.TextSize = 9
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = container
	
	return container
end

function IconSystem:GetAllIconNames(): { string }
	local names = {}
	for name, _ in ICONS_8x8 do
		table.insert(names, name)
	end
	return names
end

function IconSystem:GetStats()
	return {
		totalIcons = 30,
		pixelArt = true,
		noEmojis = true,
		sizes = {"8x8", "10x10"},
		technique = "Frame pixel art - Cada pixel é um Frame - Sem emojis, apenas ícones desenhados por Frame pixel art ou imagem",
		message = "IconSystem - Pixel Art Icons sem Emojis - 30 icons 8x8 10x10 - Save Play Publish Help AI Style Search Add Filter Move Rotate Scale World Details Vault Toolbox Engineer Motion Terrain Code Project Stats Command Close Check Cloud Market Export Collab Audio Net Mecha A01 Arkher - Sem emojis, apenas ícones desenhados por Frame pixel art - BETA FINAL Fix UI feia bugada",
	}
end

return IconSystem

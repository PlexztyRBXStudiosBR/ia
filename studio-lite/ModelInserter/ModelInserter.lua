--[[
	=====================================================================
	  MODEL INSERTER  -  1 LocalScript (pra executor)
	=====================================================================
	  Cole tudo no executor e execute.

	  - Cole o ID (ou o link) de um model do create.roblox.com/store
	    ou de uma place uncopylocked e aperte INSERIR.
	  - Enquanto voce cola, o model ja comeca a baixar (pre-carregamento).
	  - Todo ID baixado fica em cache: inserir de novo e instantaneo.
	=====================================================================
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local InsertService = game:GetService("InsertService")

local player = Players.LocalPlayer
local GUI_NAME = "ModelInserterGui"
local DISTANCIA = 8

-----------------------------------------------------------------------
-- Download (varios metodos, usa o primeiro que funcionar)
-----------------------------------------------------------------------
local function baixarObjetos(id)
	local url = "rbxassetid://" .. id
	local erros = {}
	local metodos = {
		{ "GetObjects", function()
			return game:GetObjects(url)
		end },
		{ "getobjects", function()
			if type(getobjects) ~= "function" then
				error("nao existe neste executor")
			end
			return getobjects(url)
		end },
		{ "LoadLocalAsset", function()
			return { InsertService:LoadLocalAsset(url) }
		end },
		{ "LoadAsset", function()
			return { InsertService:LoadAsset(tonumber(id)) }
		end },
	}
	for _, m in ipairs(metodos) do
		local ok, res = pcall(m[2])
		if ok and type(res) == "table" and #res > 0 then
			return res
		end
		table.insert(erros, m[1] .. ": " .. tostring(res))
	end
	return nil, table.concat(erros, " | ")
end

-- Servicos que aparecem quando o ID e de uma PLACE
local SERVICOS = {
	Workspace = true, Lighting = true, ReplicatedStorage = true, ReplicatedFirst = true,
	ServerStorage = true, ServerScriptService = true, StarterGui = true, StarterPack = true,
	StarterPlayer = true, SoundService = true, Teams = true, Chat = true,
	TextChatService = true, MaterialService = true,
}

local function montarTemplate(id, objetos)
	local modelo = Instance.new("Model")
	local ehPlace = false

	for _, o in ipairs(objetos) do
		if SERVICOS[o.ClassName] then
			ehPlace = true
			local destino = modelo
			if o.ClassName ~= "Workspace" then
				destino = Instance.new("Folder")
				destino.Name = o.Name
				destino.Parent = modelo
			end
			for _, filho in ipairs(o:GetChildren()) do
				if not filho:IsA("Terrain") and not filho:IsA("Camera") then
					pcall(function()
						filho.Parent = destino
					end)
				end
			end
		else
			pcall(function()
				o.Parent = modelo
			end)
		end
	end

	local filhos = modelo:GetChildren()
	if ehPlace then
		modelo.Name = "Place_" .. id
		return modelo, true
	end
	-- se veio 1 coisa so (Model, Part, Tool), usa ela direto
	if #filhos == 1 and (filhos[1]:IsA("PVInstance") or filhos[1]:IsA("Tool")) then
		local unico = filhos[1]
		unico.Parent = nil
		modelo:Destroy()
		return unico, false
	end
	modelo.Name = "Asset_" .. id
	return modelo, false
end

-----------------------------------------------------------------------
-- Cache
-----------------------------------------------------------------------
local cache = {}       -- [id] = { template = inst, place = bool }
local carregando = {}  -- [id] = true
local falhas = {}      -- [id] = erro

local function obterTemplate(id)
	if cache[id] then
		return cache[id], true
	end
	if carregando[id] then
		local t0 = os.clock()
		while carregando[id] and os.clock() - t0 < 30 do
			task.wait()
		end
		if cache[id] then
			return cache[id], false
		end
		return nil, falhas[id] or "falhou"
	end

	carregando[id] = true
	falhas[id] = nil
	local objetos, erro = baixarObjetos(id)
	local entrada = nil
	if objetos then
		local ok, template, ehPlace = pcall(montarTemplate, id, objetos)
		if ok and template then
			entrada = { template = template, place = ehPlace }
			cache[id] = entrada
		else
			erro = tostring(template)
		end
	end
	if not entrada then
		falhas[id] = erro
	end
	carregando[id] = nil

	if entrada then
		return entrada, false
	end
	return nil, erro
end

-----------------------------------------------------------------------
-- Inserir
-----------------------------------------------------------------------
local historico = {}

local function caixaDe(obj)
	if obj:IsA("Model") then
		local ok, cf, tam = pcall(function()
			return obj:GetBoundingBox()
		end)
		if ok then
			return cf, tam
		end
	elseif obj:IsA("BasePart") then
		return obj.CFrame, obj.Size
	end
	return nil
end

local function posicionar(obj)
	local cf, tam = caixaDe(obj)
	if not cf then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local base, frente, chao
	if hrp then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local alturaPe = 3
		if hum and hum.RigType == Enum.HumanoidRigType.R15 then
			alturaPe = hum.HipHeight + hrp.Size.Y / 2
		end
		base = hrp.Position
		frente = hrp.CFrame.LookVector
		chao = hrp.Position.Y - alturaPe
	else
		local cam = workspace.CurrentCamera
		base = cam.CFrame.Position
		frente = cam.CFrame.LookVector
		chao = base.Y - 5
	end
	frente = Vector3.new(frente.X, 0, frente.Z)
	if frente.Magnitude < 0.01 then
		frente = Vector3.new(0, 0, -1)
	end
	frente = frente.Unit

	local raio = math.max(tam.X, tam.Z) / 2
	local centro = base + frente * (raio + DISTANCIA)
	local destino = Vector3.new(centro.X, chao + tam.Y / 2, centro.Z)
	obj:PivotTo(obj:GetPivot() + (destino - cf.Position))
end

local function removerScripts(obj)
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
end

local function inserir(id, opcoes)
	local t0 = os.clock()
	local entrada, info = obterTemplate(id)
	if not entrada then
		return false, "Nao consegui carregar " .. id .. ". Erro: " .. tostring(info)
	end

	local ok, obj = pcall(function()
		return entrada.template:Clone()
	end)
	if not ok or not obj then
		return false, "Erro ao clonar."
	end
	if opcoes.removerScripts then
		removerScripts(obj)
	end

	if obj:IsA("Tool") and opcoes.toolsNaMochila then
		obj.Parent = player:FindFirstChildOfClass("Backpack") or workspace
		table.insert(historico, obj)
		return true, "Tool '" .. obj.Name .. "' na mochila!", obj.Name
	end

	if not opcoes.posicaoOriginal and not entrada.place then
		posicionar(obj)
	end
	obj.Parent = workspace
	table.insert(historico, obj)

	local origem = "baixado"
	if info == true then
		origem = "cache"
	end
	return true, "Inserido '" .. obj.Name .. "' em " .. string.format("%.2f", os.clock() - t0) .. "s (" .. origem .. ")", obj.Name
end

local function desfazer()
	while #historico > 0 do
		local obj = table.remove(historico)
		if obj and obj.Parent then
			local nome = obj.Name
			obj:Destroy()
			return true, "Removido '" .. nome .. "'"
		end
	end
	return false, "Nada para desfazer."
end

local function lerId(texto)
	if type(texto) ~= "string" then
		return nil
	end
	local padroes = {
		"/asset/(%d+)", "/games/(%d+)", "/library/(%d+)", "/catalog/(%d+)",
		"[?&]id=(%d+)", "rbxassetid://(%d+)", "(%d+)",
	}
	for _, p in ipairs(padroes) do
		local achado = string.match(texto, p)
		if achado and tonumber(achado) and tonumber(achado) > 0 then
			return achado
		end
	end
	return nil
end

-----------------------------------------------------------------------
-- GUI
-----------------------------------------------------------------------
local function paiDaGui()
	local ok, h = pcall(function()
		return gethui()
	end)
	if ok and h then
		return h
	end
	local ok2, cg = pcall(function()
		local c = game:GetService("CoreGui")
		local teste = Instance.new("Folder")
		teste.Parent = c
		teste:Destroy()
		return c
	end)
	if ok2 and cg then
		return cg
	end
	return player:WaitForChild("PlayerGui")
end

local PAI = paiDaGui()
local velho = PAI:FindFirstChild(GUI_NAME)
if velho then
	velho:Destroy()
end

local COR_FUNDO = Color3.fromRGB(30, 31, 36)
local COR_BARRA = Color3.fromRGB(22, 23, 27)
local COR_CAMPO = Color3.fromRGB(45, 47, 54)
local COR_TEXTO = Color3.fromRGB(235, 235, 240)
local COR_SUAVE = Color3.fromRGB(150, 152, 160)
local COR_VERDE = Color3.fromRGB(46, 170, 90)
local COR_VERMELHO = Color3.fromRGB(200, 65, 65)
local COR_AZUL = Color3.fromRGB(0, 132, 255)
local COR_DESLIGADO = Color3.fromRGB(70, 72, 80)

local function novo(classe, props, pai)
	local o = Instance.new(classe)
	for k, v in pairs(props) do
		o[k] = v
	end
	if pai then
		o.Parent = pai
	end
	return o
end

local function cantos(o, r)
	novo("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o)
end

local function botao(texto, cor, props, pai)
	local b = novo("TextButton", {
		Text = texto, BackgroundColor3 = cor, TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = true, BorderSizePixel = 0,
	}, pai)
	for k, v in pairs(props) do
		b[k] = v
	end
	cantos(b, 6)
	return b
end

local gui = novo("ScreenGui", {
	Name = GUI_NAME, ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
}, nil)
pcall(function()
	if syn and syn.protect_gui then
		syn.protect_gui(gui)
	end
end)
gui.Parent = PAI

local botaoAbrir = botao("INSERTER", COR_AZUL, {
	Size = UDim2.new(0, 90, 0, 34), Position = UDim2.new(0, 10, 0.5, -17), TextSize = 13,
}, gui)

local janela = novo("Frame", {
	Name = "Janela", Size = UDim2.new(0, 320, 0, 330), Position = UDim2.new(0.5, -160, 0.5, -165),
	BackgroundColor3 = COR_FUNDO, BorderSizePixel = 0, Active = true,
}, gui)
cantos(janela, 10)
novo("UIStroke", { Color = Color3.fromRGB(60, 62, 70), Thickness = 1 }, janela)

local barra = novo("Frame", {
	Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = COR_BARRA, BorderSizePixel = 0, Active = true,
}, janela)
cantos(barra, 10)
novo("Frame", {
	Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 1, -10),
	BackgroundColor3 = COR_BARRA, BorderSizePixel = 0,
}, barra)
novo("TextLabel", {
	Text = "Model Inserter", Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 12, 0, 0),
	BackgroundTransparency = 1, TextColor3 = COR_TEXTO, Font = Enum.Font.GothamBold,
	TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
}, barra)
local botaoFechar = botao("X", COR_VERMELHO, {
	Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -31, 0, 5), TextSize = 13,
}, barra)

local conteudo = novo("Frame", {
	Name = "Conteudo", Size = UDim2.new(1, -20, 1, -46), Position = UDim2.new(0, 10, 0, 42),
	BackgroundTransparency = 1,
}, janela)

local caixaId = novo("TextBox", {
	Name = "CaixaId", Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = COR_CAMPO,
	TextColor3 = COR_TEXTO, PlaceholderText = "ID ou link do model / place",
	PlaceholderColor3 = COR_SUAVE, Text = "", Font = Enum.Font.Gotham, TextSize = 14,
	ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0,
}, conteudo)
cantos(caixaId, 6)
novo("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, caixaId)

local botaoInserir = botao("INSERIR", COR_VERDE, {
	Size = UDim2.new(0.62, -4, 0, 36), Position = UDim2.new(0, 0, 0, 44), TextSize = 15,
}, conteudo)
local botaoDesfazer = botao("DESFAZER", COR_VERMELHO, {
	Size = UDim2.new(0.38, -4, 0, 36), Position = UDim2.new(0.62, 4, 0, 44), TextSize = 13,
}, conteudo)

local opcoes = { removerScripts = false, posicaoOriginal = false, toolsNaMochila = true }

local function toggle(texto, chave, y)
	local b = botao("", COR_DESLIGADO, {
		Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, y),
		Font = Enum.Font.Gotham, TextSize = 13,
	}, conteudo)
	local function atualizar()
		if opcoes[chave] then
			b.Text = texto .. ":  LIGADO"
			b.BackgroundColor3 = COR_AZUL
		else
			b.Text = texto .. ":  DESLIGADO"
			b.BackgroundColor3 = COR_DESLIGADO
		end
	end
	b.MouseButton1Click:Connect(function()
		opcoes[chave] = not opcoes[chave]
		atualizar()
	end)
	atualizar()
end

toggle("Remover scripts (anti-virus)", "removerScripts", 88)
toggle("Manter posicao original", "posicaoOriginal", 118)
toggle("Tools direto na mochila", "toolsNaMochila", 148)

local status = novo("TextLabel", {
	Name = "Status", Text = "Pronto! Cole um ID e aperte INSERIR.",
	Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 178),
	BackgroundTransparency = 1, TextColor3 = COR_SUAVE, Font = Enum.Font.Gotham, TextSize = 12,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, conteudo)

novo("TextLabel", {
	Text = "Recentes (toque pra inserir de novo):", Size = UDim2.new(1, 0, 0, 16),
	Position = UDim2.new(0, 0, 0, 212), BackgroundTransparency = 1, TextColor3 = COR_SUAVE,
	Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
}, conteudo)

local listaRecentes = novo("ScrollingFrame", {
	Name = "Recentes", Size = UDim2.new(1, 0, 1, -232), Position = UDim2.new(0, 0, 0, 232),
	BackgroundColor3 = COR_CAMPO, BorderSizePixel = 0, ScrollBarThickness = 4,
	CanvasSize = UDim2.new(0, 0, 0, 0),
}, conteudo)
cantos(listaRecentes, 6)
local layout = novo("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, listaRecentes)
novo("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 6) }, listaRecentes)
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	listaRecentes.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 6)
end)

-- Tela pequena (celular deitado): diminui a janela
local cam = workspace.CurrentCamera
if cam and cam.ViewportSize.Y > 0 and cam.ViewportSize.Y < 420 then
	novo("UIScale", { Scale = math.max(0.6, (cam.ViewportSize.Y - 40) / 340) }, janela)
end

-----------------------------------------------------------------------
-- Logica da GUI
-----------------------------------------------------------------------
local ocupado = false
local recentes = {}
local inserirId

local function mostrar(texto, cor)
	status.Text = texto
	status.TextColor3 = cor or COR_SUAVE
end

local function atualizarRecentes()
	for _, f in ipairs(listaRecentes:GetChildren()) do
		if f:IsA("TextButton") then
			f:Destroy()
		end
	end
	for i, item in ipairs(recentes) do
		local b = botao(item.nome .. "  (" .. item.id .. ")", COR_FUNDO, {
			Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i, Font = Enum.Font.Gotham, TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		}, listaRecentes)
		novo("UIPadding", { PaddingLeft = UDim.new(0, 8) }, b)
		b.MouseButton1Click:Connect(function()
			caixaId.Text = item.id
			inserirId(item.id)
		end)
	end
end

local function addRecente(id, nome)
	for i = #recentes, 1, -1 do
		if recentes[i].id == id then
			table.remove(recentes, i)
		end
	end
	table.insert(recentes, 1, { id = id, nome = nome or ("Asset " .. id) })
	while #recentes > 15 do
		table.remove(recentes)
	end
	atualizarRecentes()
end

inserirId = function(id)
	if ocupado then
		return
	end
	if not id then
		mostrar("ID invalido. Cole o numero ou o link.", COR_VERMELHO)
		return
	end
	ocupado = true
	botaoInserir.Text = "INSERINDO..."
	botaoInserir.BackgroundColor3 = COR_DESLIGADO
	mostrar("Inserindo " .. id .. "...", COR_TEXTO)

	local ok, sucesso, msg, nome = pcall(inserir, id, opcoes)
	if not ok then
		mostrar("Erro: " .. tostring(sucesso), COR_VERMELHO)
	elseif sucesso then
		mostrar(msg, COR_VERDE)
		addRecente(id, nome)
	else
		mostrar(msg, COR_VERMELHO)
	end

	botaoInserir.Text = "INSERIR"
	botaoInserir.BackgroundColor3 = COR_VERDE
	ocupado = false
end

-- Pre-carrega enquanto voce cola/digita
local token = 0
caixaId:GetPropertyChangedSignal("Text"):Connect(function()
	token = token + 1
	local meu = token
	task.delay(0.35, function()
		if meu ~= token then
			return
		end
		local id = lerId(caixaId.Text)
		if id and string.len(id) >= 4 and not cache[id] and not carregando[id] then
			task.spawn(obterTemplate, id)
		end
	end)
end)

botaoInserir.MouseButton1Click:Connect(function()
	inserirId(lerId(caixaId.Text))
end)
caixaId.FocusLost:Connect(function(enter)
	if enter then
		inserirId(lerId(caixaId.Text))
	end
end)
botaoDesfazer.MouseButton1Click:Connect(function()
	local ok, msg = desfazer()
	if ok then
		mostrar(msg, COR_TEXTO)
	else
		mostrar(msg, COR_SUAVE)
	end
end)

botaoAbrir.MouseButton1Click:Connect(function()
	janela.Visible = not janela.Visible
end)
botaoFechar.MouseButton1Click:Connect(function()
	janela.Visible = false
end)

-- Arrastar (mouse e toque)
local arrastando, inicioInput, inicioPos = false, nil, nil
barra.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		arrastando = true
		inicioInput = input.Position
		inicioPos = janela.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				arrastando = false
			end
		end)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if arrastando and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local d = input.Position - inicioInput
		janela.Position = UDim2.new(inicioPos.X.Scale, inicioPos.X.Offset + d.X, inicioPos.Y.Scale, inicioPos.Y.Offset + d.Y)
	end
end)

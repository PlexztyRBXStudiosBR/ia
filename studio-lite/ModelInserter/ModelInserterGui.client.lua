--[[
	=====================================================================
	  MODEL INSERTER  -  GUI  (LocalScript)
	=====================================================================
	  Onde colocar no Studio Lite:
	    StarterPlayer -> StarterPlayerScripts -> LocalScript (cole este codigo)
	    (tambem funciona em StarterCharacterScripts)

	  IMPORTANTE: precisa do Script "ModelInserterServer" no
	  ServerScriptService. O LocalScript sozinho nao consegue inserir
	  models (o Roblox bloqueia isso no cliente).

	  Como usar:
	    1. Aperte o botao "INSERTER" na lateral da tela.
	    2. Cole o ID (ou o link inteiro) de um model do
	       create.roblox.com/store  ou de uma place uncopylocked.
	    3. Aperte INSERIR (ou Enter). Pronto!
	=====================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GUI_NAME = "ModelInserterGui"

-- Se o script rodar de novo (ex: StarterCharacterScripts ao morrer), nao duplica.
local existente = playerGui:FindFirstChild(GUI_NAME)
if existente then
	existente:Destroy()
end

local remote = ReplicatedStorage:WaitForChild("ModelInserterRemote", 20)
if not remote then
	warn("[ModelInserter] Nao achei o 'ModelInserterRemote'. Coloque o Script ModelInserterServer no ServerScriptService!")
	return
end

-- So mostra a GUI pra quem tem permissao (no jogo publicado: o dono).
local okPerm, temPerm = pcall(function()
	return remote:InvokeServer("permissao")
end)
if not okPerm or not temPerm then
	return
end

-----------------------------------------------------------------------
-- Cores / helpers de UI
-----------------------------------------------------------------------
local COR_FUNDO = Color3.fromRGB(30, 31, 36)
local COR_BARRA = Color3.fromRGB(22, 23, 27)
local COR_CAMPO = Color3.fromRGB(45, 47, 54)
local COR_TEXTO = Color3.fromRGB(235, 235, 240)
local COR_SUAVE = Color3.fromRGB(150, 152, 160)
local COR_VERDE = Color3.fromRGB(46, 170, 90)
local COR_VERMELHO = Color3.fromRGB(200, 65, 65)
local COR_AZUL = Color3.fromRGB(0, 132, 255)
local COR_LIGADO = Color3.fromRGB(0, 132, 255)
local COR_DESLIGADO = Color3.fromRGB(70, 72, 80)

local function novo(classe, props, pai)
	local obj = Instance.new(classe)
	for k, v in pairs(props) do
		obj[k] = v
	end
	if pai then
		obj.Parent = pai
	end
	return obj
end

local function arredondar(obj, raio)
	novo("UICorner", { CornerRadius = UDim.new(0, raio or 8) }, obj)
end

local function botao(texto, cor, props, pai)
	local b = novo("TextButton", {
		Text = texto,
		BackgroundColor3 = cor,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}, pai)
	for k, v in pairs(props) do
		b[k] = v
	end
	arredondar(b, 6)
	return b
end

local function lerId(texto)
	if type(texto) ~= "string" then
		return nil
	end
	local padroes = {
		"/asset/(%d+)",
		"/games/(%d+)",
		"/library/(%d+)",
		"/catalog/(%d+)",
		"[?&]id=(%d+)",
		"rbxassetid://(%d+)",
		"(%d+)",
	}
	for _, padrao in ipairs(padroes) do
		local achado = string.match(texto, padrao)
		if achado and tonumber(achado) and tonumber(achado) > 0 then
			return achado
		end
	end
	return nil
end

-----------------------------------------------------------------------
-- Montagem da GUI
-----------------------------------------------------------------------
local gui = novo("ScreenGui", {
	Name = GUI_NAME,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 50,
}, playerGui)

-- Botao lateral pra abrir/fechar (bom pra celular)
local botaoAbrir = botao("INSERTER", COR_AZUL, {
	Name = "Abrir",
	Size = UDim2.new(0, 90, 0, 34),
	Position = UDim2.new(0, 10, 0.5, -17),
	TextSize = 13,
}, gui)

local janela = novo("Frame", {
	Name = "Janela",
	Size = UDim2.new(0, 320, 0, 330),
	Position = UDim2.new(0.5, -160, 0.5, -165),
	BackgroundColor3 = COR_FUNDO,
	BorderSizePixel = 0,
	Visible = true,
	Active = true,
}, gui)
arredondar(janela, 10)
novo("UIStroke", { Color = Color3.fromRGB(60, 62, 70), Thickness = 1 }, janela)

-- Barra de titulo (arrasta a janela)
local barra = novo("Frame", {
	Name = "Barra",
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundColor3 = COR_BARRA,
	BorderSizePixel = 0,
	Active = true,
}, janela)
arredondar(barra, 10)
-- tampa os cantos de baixo da barra
novo("Frame", {
	Size = UDim2.new(1, 0, 0, 10),
	Position = UDim2.new(0, 0, 1, -10),
	BackgroundColor3 = COR_BARRA,
	BorderSizePixel = 0,
}, barra)

novo("TextLabel", {
	Text = "Model Inserter",
	Size = UDim2.new(1, -50, 1, 0),
	Position = UDim2.new(0, 12, 0, 0),
	BackgroundTransparency = 1,
	TextColor3 = COR_TEXTO,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
}, barra)

local botaoFechar = botao("X", COR_VERMELHO, {
	Size = UDim2.new(0, 26, 0, 26),
	Position = UDim2.new(1, -31, 0, 5),
	TextSize = 13,
}, barra)

-- Conteudo
local conteudo = novo("Frame", {
	Name = "Conteudo",
	Size = UDim2.new(1, -20, 1, -46),
	Position = UDim2.new(0, 10, 0, 42),
	BackgroundTransparency = 1,
}, janela)

local caixaId = novo("TextBox", {
	Name = "CaixaId",
	Size = UDim2.new(1, 0, 0, 36),
	Position = UDim2.new(0, 0, 0, 0),
	BackgroundColor3 = COR_CAMPO,
	TextColor3 = COR_TEXTO,
	PlaceholderText = "ID ou link do model / place",
	PlaceholderColor3 = COR_SUAVE,
	Text = "",
	Font = Enum.Font.Gotham,
	TextSize = 14,
	ClearTextOnFocus = false,
	TextXAlignment = Enum.TextXAlignment.Left,
	BorderSizePixel = 0,
}, conteudo)
arredondar(caixaId, 6)
novo("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, caixaId)

local botaoInserir = botao("INSERIR", COR_VERDE, {
	Size = UDim2.new(0.62, -4, 0, 36),
	Position = UDim2.new(0, 0, 0, 44),
	TextSize = 15,
}, conteudo)

local botaoDesfazer = botao("DESFAZER", COR_VERMELHO, {
	Size = UDim2.new(0.38, -4, 0, 36),
	Position = UDim2.new(0.62, 4, 0, 44),
	TextSize = 13,
}, conteudo)

-- Opcoes (toggles)
local opcoes = {
	removerScripts = false,
	posicaoOriginal = false,
	toolsNaMochila = true,
}

local function criarToggle(texto, chave, y)
	local b = botao("", COR_DESLIGADO, {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0, y),
		Font = Enum.Font.Gotham,
		TextSize = 13,
	}, conteudo)
	local function atualizar()
		if opcoes[chave] then
			b.Text = texto .. ":  LIGADO"
			b.BackgroundColor3 = COR_LIGADO
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
	return b
end

criarToggle("Remover scripts (anti-virus)", "removerScripts", 88)
criarToggle("Manter posicao original (mapas)", "posicaoOriginal", 118)
criarToggle("Tools direto na mochila", "toolsNaMochila", 148)

local status = novo("TextLabel", {
	Name = "Status",
	Text = "Cole um ID e aperte INSERIR.",
	Size = UDim2.new(1, 0, 0, 34),
	Position = UDim2.new(0, 0, 0, 178),
	BackgroundTransparency = 1,
	TextColor3 = COR_SUAVE,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, conteudo)

novo("TextLabel", {
	Text = "Recentes (toque pra inserir de novo):",
	Size = UDim2.new(1, 0, 0, 16),
	Position = UDim2.new(0, 0, 0, 212),
	BackgroundTransparency = 1,
	TextColor3 = COR_SUAVE,
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
}, conteudo)

local listaRecentes = novo("ScrollingFrame", {
	Name = "Recentes",
	Size = UDim2.new(1, 0, 1, -232),
	Position = UDim2.new(0, 0, 0, 232),
	BackgroundColor3 = COR_CAMPO,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	CanvasSize = UDim2.new(0, 0, 0, 0),
}, conteudo)
arredondar(listaRecentes, 6)
local layout = novo("UIListLayout", {
	Padding = UDim.new(0, 3),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, listaRecentes)
novo("UIPadding", {
	PaddingTop = UDim.new(0, 3),
	PaddingLeft = UDim.new(0, 3),
	PaddingRight = UDim.new(0, 6),
}, listaRecentes)

layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	listaRecentes.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 6)
end)

-----------------------------------------------------------------------
-- Logica
-----------------------------------------------------------------------
local ocupado = false
local recentes = {}          -- lista de {id=, nome=}
local preCarregados = {}     -- [id] = true
local inserirId              -- declarada abaixo

local function mostrarStatus(texto, cor)
	status.Text = texto
	status.TextColor3 = cor or COR_SUAVE
end

local function atualizarRecentes()
	for _, filho in ipairs(listaRecentes:GetChildren()) do
		if filho:IsA("TextButton") then
			filho:Destroy()
		end
	end
	for i, item in ipairs(recentes) do
		local b = botao(item.nome .. "  (" .. item.id .. ")", COR_FUNDO, {
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = i,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, listaRecentes)
		novo("UIPadding", { PaddingLeft = UDim.new(0, 8) }, b)
		b.MouseButton1Click:Connect(function()
			caixaId.Text = item.id
			inserirId(item.id)
		end)
	end
end

local function adicionarRecente(id, nome)
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
		mostrarStatus("ID invalido. Cole o numero ou o link do model/place.", COR_VERMELHO)
		return
	end
	ocupado = true
	botaoInserir.Text = "INSERINDO..."
	botaoInserir.BackgroundColor3 = COR_DESLIGADO
	mostrarStatus("Inserindo " .. id .. "...", COR_TEXTO)

	local ok, sucesso, mensagem, nome = pcall(function()
		return remote:InvokeServer("inserir", {
			id = id,
			removerScripts = opcoes.removerScripts,
			posicaoOriginal = opcoes.posicaoOriginal,
			toolsNaMochila = opcoes.toolsNaMochila,
		})
	end)

	if not ok then
		mostrarStatus("Erro: " .. tostring(sucesso), COR_VERMELHO)
	elseif sucesso then
		mostrarStatus(tostring(mensagem), COR_VERDE)
		adicionarRecente(id, nome)
	else
		mostrarStatus(tostring(mensagem), COR_VERMELHO)
	end

	botaoInserir.Text = "INSERIR"
	botaoInserir.BackgroundColor3 = COR_VERDE
	ocupado = false
end

-- Pre-carrega enquanto voce digita/cola => quando apertar INSERIR ja esta pronto.
local tokenDigitacao = 0
caixaId:GetPropertyChangedSignal("Text"):Connect(function()
	tokenDigitacao = tokenDigitacao + 1
	local meuToken = tokenDigitacao
	task.delay(0.35, function()
		if meuToken ~= tokenDigitacao then
			return
		end
		local id = lerId(caixaId.Text)
		if id and string.len(id) >= 4 and not preCarregados[id] then
			preCarregados[id] = true
			pcall(function()
				remote:InvokeServer("preload", { id = id })
			end)
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
	local ok, sucesso, mensagem = pcall(function()
		return remote:InvokeServer("desfazer", {})
	end)
	if ok and sucesso then
		mostrarStatus(tostring(mensagem), COR_TEXTO)
	elseif ok then
		mostrarStatus(tostring(mensagem), COR_SUAVE)
	else
		mostrarStatus("Erro: " .. tostring(sucesso), COR_VERMELHO)
	end
end)

-- Abrir / fechar
local function alternarJanela()
	janela.Visible = not janela.Visible
end
botaoAbrir.MouseButton1Click:Connect(alternarJanela)
botaoFechar.MouseButton1Click:Connect(function()
	janela.Visible = false
end)

-- Arrastar pela barra (mouse e toque)
local arrastando = false
local inicioInput, inicioPos

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
	if not arrastando then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - inicioInput
		janela.Position = UDim2.new(
			inicioPos.X.Scale, inicioPos.X.Offset + delta.X,
			inicioPos.Y.Scale, inicioPos.Y.Offset + delta.Y
		)
	end
end)

-- Telas pequenas (celular deitado): diminui a janela um pouco
local camera = workspace.CurrentCamera
if camera and camera.ViewportSize.Y > 0 and camera.ViewportSize.Y < 420 then
	novo("UIScale", { Scale = math.max(0.6, (camera.ViewportSize.Y - 40) / 340) }, janela)
end

mostrarStatus("Pronto! Cole um ID e aperte INSERIR.", COR_SUAVE)

--[[
	=====================================================================
	  MODEL INSERTER  -  PARTE DO SERVIDOR  (Script normal, NAO local)
	=====================================================================
	  Onde colocar no Studio Lite:
	    ServerScriptService  ->  Script  (cole este codigo)

	  Por que precisa dessa parte?
	    O Roblox NAO deixa LocalScript inserir models (LoadAsset so funciona
	    no servidor). Entao o LocalScript (a GUI) pede, e este Script insere.

	  Como fica rapido ("na hora"):
	    - Enquanto voce digita/cola o ID, a GUI ja manda o servidor
	      pre-carregar o model em segundo plano.
	    - Todo model carregado fica guardado em cache (ServerStorage).
	      Inserir de novo o mesmo ID e so um :Clone() = instantaneo.
	    - Voce pode colocar IDs em PRE_CARREGAR pra ja virem carregados
	      quando o servidor abre.
	=====================================================================
]]

local CONFIG = {
	-- true = so o dono do jogo (ou dono do grupo) pode usar o inserter.
	-- Deixe true no jogo publicado, senao qualquer jogador insere coisas!
	SOMENTE_DONO = true,

	-- UserIds extras que podem usar (ex: seus amigos). Ex: {12345678, 87654321}
	PERMITIDOS = {},

	-- Tempo minimo (segundos) entre insercoes do mesmo jogador.
	COOLDOWN = 0.25,

	-- Quantos models diferentes ficam guardados no cache.
	MAX_CACHE = 40,

	-- Distancia (studs) na frente do jogador onde o model aparece.
	DISTANCIA = 8,

	-- IDs para ja deixar carregados quando o servidor abrir (fica instantaneo).
	PRE_CARREGAR = {},

	-- Models carregados por AssetService vem "Sandboxed" (scripts deles nao
	-- rodam, protecao contra virus). true = tenta liberar os scripts.
	-- So ligue se voce confia nos models que vai inserir.
	TENTAR_LIBERAR_SCRIPTS = false,
}

local STUDIO_LITE_PLACE_ID = 10959918411

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")

local AssetService = nil
pcall(function()
	AssetService = game:GetService("AssetService")
end)

-----------------------------------------------------------------------
-- Remote (a GUI conversa com o servidor por aqui)
-----------------------------------------------------------------------
local REMOTE_NAME = "ModelInserterRemote"

local antigo = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if antigo then
	antigo:Destroy()
end

local remote = Instance.new("RemoteFunction")
remote.Name = REMOTE_NAME
remote.Parent = ReplicatedStorage

local pastaCache = ServerStorage:FindFirstChild("ModelInserterCache")
if not pastaCache then
	pastaCache = Instance.new("Folder")
	pastaCache.Name = "ModelInserterCache"
	pastaCache.Parent = ServerStorage
end

local pastaInseridos = workspace:FindFirstChild("ModelsInseridos")
if not pastaInseridos then
	pastaInseridos = Instance.new("Folder")
	pastaInseridos.Name = "ModelsInseridos"
	pastaInseridos.Parent = workspace
end

-----------------------------------------------------------------------
-- Estado
-----------------------------------------------------------------------
local cache = {}        -- [id] = modelo guardado (template)
local ordemCache = {}   -- ids em ordem de chegada (pra limpar os velhos)
local carregando = {}   -- [id] = true enquanto baixa
local falhas = {}       -- [id] = mensagem de erro da ultima tentativa
local ultimoUso = {}    -- [player] = os.clock()
local historico = {}    -- [player] = { instancias inseridas }

-----------------------------------------------------------------------
-- Utilidades
-----------------------------------------------------------------------
local function lerId(valor)
	if type(valor) == "number" then
		valor = tostring(math.floor(valor))
	end
	if type(valor) ~= "string" then
		return nil
	end
	-- aceita link inteiro: create.roblox.com/store/asset/123/..., roblox.com/games/123/...
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
		local achado = string.match(valor, padrao)
		if achado then
			local n = tonumber(achado)
			if n and n > 0 and n < 9007199254740992 then
				return n
			end
		end
	end
	return nil
end

local function temPermissao(player)
	for _, uid in ipairs(CONFIG.PERMITIDOS) do
		if player.UserId == uid then
			return true
		end
	end
	if not CONFIG.SOMENTE_DONO then
		return true
	end
	-- Modo Play do Studio Lite / Roblox Studio: servidor so tem voce.
	if game.PlaceId == STUDIO_LITE_PLACE_ID or RunService:IsStudio() or game.CreatorId == 0 then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		return ok and rank == 255
	end
	return player.UserId == game.CreatorId
end

local function removerScripts(obj)
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") then
			d:Destroy()
		end
	end
end

-----------------------------------------------------------------------
-- Download do asset (model da loja OU place uncopylocked)
-----------------------------------------------------------------------
local function baixarAsset(id)
	local erros = {}

	-- 1) AssetService:LoadAssetAsync (API nova, carrega models de outros
	--    criadores se "Allow Loading Third Party Assets" estiver ligado)
	if AssetService then
		local ok, res = pcall(function()
			return AssetService:LoadAssetAsync(id)
		end)
		if ok and res then
			return res
		end
		table.insert(erros, "AssetService: " .. tostring(res))
	end

	-- 2) InsertService:LoadAsset (API antiga)
	local ok2, res2 = pcall(function()
		return InsertService:LoadAsset(id)
	end)
	if ok2 and res2 then
		return res2
	end
	table.insert(erros, "InsertService: " .. tostring(res2))

	-- 3) GetObjects (so funciona em ambientes com permissao extra; se nao
	--    tiver, apenas falha em silencio e seguimos)
	local ok3, res3 = pcall(function()
		return game:GetObjects("rbxassetid://" .. tostring(id))
	end)
	if ok3 and type(res3) == "table" and #res3 > 0 then
		local m = Instance.new("Model")
		m.Name = "Asset_" .. tostring(id)
		for _, o in ipairs(res3) do
			pcall(function()
				o.Parent = m
			end)
		end
		return m
	end

	return nil, table.concat(erros, " | ")
end

local function guardarNoCache(id, modelo)
	modelo.Parent = pastaCache
	cache[id] = modelo
	table.insert(ordemCache, id)
	while #ordemCache > CONFIG.MAX_CACHE do
		local velho = table.remove(ordemCache, 1)
		if cache[velho] then
			cache[velho]:Destroy()
			cache[velho] = nil
		end
	end
end

-- Retorna o template (do cache ou baixando). Se outro pedido ja esta
-- baixando o mesmo ID, espera ele em vez de baixar duas vezes.
local function obterTemplate(id)
	if cache[id] and cache[id].Parent then
		return cache[id], true
	end

	if carregando[id] then
		local inicio = os.clock()
		while carregando[id] and os.clock() - inicio < 30 do
			task.wait()
		end
		if cache[id] then
			return cache[id], false
		end
		return nil, falhas[id] or "Falhou ao carregar."
	end

	carregando[id] = true
	falhas[id] = nil
	local modelo, erro = baixarAsset(id)
	if modelo then
		-- nome bonito: se so tem 1 coisa dentro, usa o nome dela
		local filhos = modelo:GetChildren()
		if #filhos == 1 then
			modelo.Name = filhos[1].Name
		else
			modelo.Name = "Asset_" .. tostring(id)
		end
		modelo:SetAttribute("AssetId", id)
		if CONFIG.TENTAR_LIBERAR_SCRIPTS then
			pcall(function()
				modelo.Sandboxed = false
			end)
		end
		guardarNoCache(id, modelo)
	else
		falhas[id] = erro
	end
	carregando[id] = nil

	if modelo then
		return modelo, false
	end
	return nil, erro
end

-----------------------------------------------------------------------
-- Posicionamento: coloca no chao, na frente do jogador
-----------------------------------------------------------------------
local function posicionar(obj, player)
	local okBox, cf, tamanho = pcall(function()
		return obj:GetBoundingBox()
	end)
	if not okBox or not cf then
		return
	end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local destino

	if hrp then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local alturaPe = 3
		if hum and hum.RigType == Enum.HumanoidRigType.R15 then
			alturaPe = hum.HipHeight + hrp.Size.Y / 2
		end
		local frente = hrp.CFrame.LookVector
		frente = Vector3.new(frente.X, 0, frente.Z)
		if frente.Magnitude < 0.01 then
			frente = Vector3.new(0, 0, -1)
		end
		frente = frente.Unit

		local raio = math.max(tamanho.X, tamanho.Z) / 2
		local chao = hrp.Position.Y - alturaPe
		local centro = hrp.Position + frente * (raio + CONFIG.DISTANCIA)
		destino = Vector3.new(centro.X, chao + tamanho.Y / 2, centro.Z)
	else
		destino = Vector3.new(0, tamanho.Y / 2 + 1, 0)
	end

	obj:PivotTo(obj:GetPivot() + (destino - cf.Position))
end

local function registrar(player, obj)
	if not historico[player] then
		historico[player] = {}
	end
	table.insert(historico[player], obj)
	if #historico[player] > 50 then
		table.remove(historico[player], 1)
	end
end

-----------------------------------------------------------------------
-- Inserir
-----------------------------------------------------------------------
local function inserir(player, id, opcoes)
	local t0 = os.clock()
	local template, infoOuErro = obterTemplate(id)
	if not template then
		return false, "Nao consegui carregar " .. tostring(id) .. ". Causas comuns: model de outro criador sem "
			.. "'Allow Loading Third Party Assets' ligado, model privado/pago, ID de place (Roblox nao deixa "
			.. "script carregar place), ou modo Play do Studio Lite (teste no jogo publicado). Erro: "
			.. tostring(infoOuErro)
	end
	local doCache = infoOuErro == true

	local ok, obj = pcall(function()
		return template:Clone()
	end)
	if not ok or not obj then
		return false, "Erro ao clonar o model."
	end

	if opcoes.removerScripts then
		removerScripts(obj)
	end

	-- Tool/arma/gear: vai direto pra mochila
	local filhos = obj:GetChildren()
	if opcoes.toolsNaMochila ~= false and #filhos == 1 and filhos[1]:IsA("Tool") then
		local tool = filhos[1]
		local mochila = player:FindFirstChildOfClass("Backpack")
		tool.Parent = mochila or pastaInseridos
		obj:Destroy()
		registrar(player, tool)
		return true, "Tool '" .. tool.Name .. "' colocada na mochila!", tool.Name
	end

	if not opcoes.posicaoOriginal then
		posicionar(obj, player)
	end
	obj.Parent = pastaInseridos
	registrar(player, obj)

	local tempo = string.format("%.2f", os.clock() - t0)
	local origem = "baixado"
	if doCache then
		origem = "cache"
	end
	return true, "Inserido '" .. obj.Name .. "' em " .. tempo .. "s (" .. origem .. ")", obj.Name
end

local function desfazer(player)
	local lista = historico[player]
	while lista and #lista > 0 do
		local obj = table.remove(lista)
		if obj and obj.Parent then
			local nome = obj.Name
			obj:Destroy()
			return true, "Removido '" .. nome .. "'"
		end
	end
	return false, "Nada para desfazer."
end

-----------------------------------------------------------------------
-- Remote handler
-----------------------------------------------------------------------
remote.OnServerInvoke = function(player, acao, dados)
	if not temPermissao(player) then
		return false, "Sem permissao para usar o Model Inserter."
	end
	if type(dados) ~= "table" then
		dados = {}
	end

	if acao == "permissao" then
		return true, "ok"
	end

	if acao == "desfazer" then
		return desfazer(player)
	end

	local id = lerId(dados.id)
	if not id then
		return false, "ID invalido. Cole o numero ou o link do model/place."
	end

	if acao == "preload" then
		if not cache[id] and not carregando[id] then
			task.spawn(obterTemplate, id)
		end
		return true, "pre-carregando"
	end

	if acao == "inserir" then
		local agora = os.clock()
		if ultimoUso[player] and agora - ultimoUso[player] < CONFIG.COOLDOWN then
			return false, "Calma! Espere um pouquinho."
		end
		ultimoUso[player] = agora
		return inserir(player, id, {
			removerScripts = dados.removerScripts == true,
			posicaoOriginal = dados.posicaoOriginal == true,
			toolsNaMochila = dados.toolsNaMochila ~= false,
		})
	end

	return false, "Acao desconhecida."
end

Players.PlayerRemoving:Connect(function(player)
	historico[player] = nil
	ultimoUso[player] = nil
end)

-- Pre-carregar IDs configurados
for _, id in ipairs(CONFIG.PRE_CARREGAR) do
	local n = lerId(id)
	if n then
		task.spawn(obterTemplate, n)
	end
end

print("[ModelInserter] Servidor pronto.")

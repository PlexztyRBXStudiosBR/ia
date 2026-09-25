--[[=========================================================================
    ____                        _   _    _         _
   |  _ \  ___ _ __ ___  __ _  | | | |  / \    ___| | ___  __ _
   | | | |/ _ \ '_ ` _ \/ _` | | |_| | / _ \  / __| |/ _ \/ _` |
   | |_| |  __/ | | | | | (_| | |  _  |/ ___ \| (__| |  __/ (_| |
   |____/ \___|_| |_| |_|\__,_| |_| |_/_/   \_\\___|_|\___|\__, |
                                                           |___/
   MEGA ANTI-LAG v4.2 • ITEL A70 EDITION  +  SKIN "VIDA" (filtro vivo)
   -----------------------------------------------------------------------
   • UI ......... Rayfield Interface Suite (sirius.menu/rayfield)
   • Alvo ....... celulares fracos (ITEL A70, 2-4 GB de RAM, PowerVR/Mali)
   • Local ...... script de cliente (executor). NAO altera o servidor.
   -----------------------------------------------------------------------
   O QUE ELE FAZ
   [ANTI-LAG]
     - Esconde o cenario distante por celulas (grid) com histerese
     - Mata efeitos (particulas, luzes, beams, trails, highlights)
     - Remove texturas/decais/PBR (SurfaceAppearance)
     - Desliga grama decorada e ondas da agua
     - Remove skybox/nuvens/atmosfera pesada do jogo
     - Desliga sombras e luz ambiente (environment)
     - Baixa o nivel de qualidade de render + LOD
     - Auto-emergencia: se o FPS cair, ele aperta tudo sozinho
   [SKIN VIVA - o oposto de jogo "sem graca"]
     - Color grading (saturacao, contraste, brilho, tingimento)
     - Fog + Atmosphere coloridos pela paleta (horizonte vivo)
     - Bloom neon, raios de sol, profundidade de campo opcional
     - Aura de luz no personagem + rastro (trail)
     - Respiracao: tudo pulsa devagar (filtro "vivo")
     - FOV cinematografico (abre quando voce corre)
     - Camera viva (micro shake organico) - opcional
     - Nuvens cinematograficas - opcional
   [ANIMACAO]
     - Deixa a animacao do personagem mais rapida (visual, sem mudar
       a velocidade real). Faz patch seguro do script Animate do jogo.
   -----------------------------------------------------------------------
   ATALHOS:  K = abre/fecha menu          (config salvo automaticamente)
   MENU:     Painel | Anti-Lag | Skin Viva | Animacao | Extras
   API:      getgenv().MegaAntiLagITEL (console do executor)
   -----------------------------------------------------------------------
   AVISO: todo script de cliente tem risco em jogos com anti-cheat
   agressivo. Use por sua conta e risco. Nao use em modo competitivo.
=========================================================================]]--

-- NOTE: este script foi escrito em Lua 5.1-compativel de proposito
-- (sem +=, sem //, sem continue) para rodar em qualquer executor.

local QUICK_PRESET = "Itel A70 - Turbo"   -- PRESET INICIAL (edite aqui: veja a lista no menu)

--======================================= SERVICES / ATALHOS
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Lighting     = game:GetService("Lighting")
local Ws           = game:GetService("Workspace")
local UIS          = game:GetService("UserInputService")
local StatsSrv     = game:GetService("Stats")
local LocalPlayer  = Players.LocalPlayer
local Terrain      = Ws:FindFirstChildOfClass("Terrain")

local PREFIX = "ALG_"        -- tudo que criamos comeca assim
local CELL   = 64            -- tamanho da celula do grid (studs)
local MAXPARTS = 15000       -- teto de pecas monitoradas (protecao de RAM)
local MAXDYN   = 420         -- teto de pecas dinamicas (personagens/fisica)
local MAXEFF   = 15000       -- teto de registros de efeitos

--======================================= UTIL
local function clamp(v, a, b)
	if v < a then return a elseif v > b then return b end
	return v
end

local function lerp(a, b, t) return a + (b - a) * t end

local function round(v, inc)
	if not inc or inc <= 0 then return v end
	return math.floor(v / inc + 0.5) * inc
end

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local function mixColor(a, b, t)
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

local function isALG(inst)
	local n = inst.Name
	return n:sub(1, #PREFIX) == PREFIX
end

local function dist2(px, py, pz, qx, qy, qz)
	local dx, dy, dz = px - qx, py - qy, pz - qz
	return dx * dx + dy * dy + dz * dz
end

-- pcall helpers ------------------------------------------------
local function trySet(inst, prop, value)
	if not inst then return false end
	return (pcall(function() inst[prop] = value end))
end

local function tryCall(fn, ...)
	if not fn then return false end
	local ok = pcall(fn, ...)
	return ok
end

local function getProp(inst, prop)
	local ok, v = pcall(function() return inst[prop] end)
	if ok then return v end
	return nil
end

local function now() return os.clock() end

--======================================= CONFIG (estado atual)
local CFG = {
	-- ANTI-LAG --------------------------------------------------
	AL_Parts    = true,     -- esconder cenario distante
	AL_Dist     = 300,      -- distancia (studs)
	AL_Effects  = true,     -- matar efeitos
	AL_Textures = true,     -- remover texturas/decais
	AL_Grass    = true,     -- desligar grama / ondas
	AL_Sky      = true,     -- remover skybox/nuvens/atmosfera
	AL_Shadows  = true,     -- desligar sombras
	AL_RenderQ  = true,     -- baixar qualidade de render + LOD
	AL_Extreme  = false,    -- modo extremo (jogadores distantes somem)
	AL_Rate     = 240,      -- instancias inspecionadas por frame
	AL_Auto     = true,     -- auto-emergencia por FPS
	AL_MemGuard = true,     -- guarda de memoria / GC
	-- SKIN ------------------------------------------------------
	SK_On      = true,
	SK_Palette = "Sunset Fogo",
	SK_Int     = 68,     -- intensidade geral
	SK_Sat     = 52,
	SK_Con     = 34,
	SK_Bri     = 40,
	SK_Tint    = 58,
	SK_Fog     = true,
	SK_Atmos   = true,
	SK_Grade   = true,
	SK_Bloom   = true,
	SK_Sun     = true,
	SK_DOF     = false,
	SK_Clouds  = false,
	SK_Aura    = true,
	SK_Trail   = false,
	SK_Camera  = true,
	SK_FOV     = 86,
	SK_LockFOV = true,
	SK_CineFOV = true,
	SK_Vida    = true,    -- "respiracao" do filtro
	SK_Hour    = true,    -- hora dourada (17h30)
	-- ANIMACAO ---------------------------------------------------
	AN_On      = true,
	AN_Walk    = 1.45,
	AN_Run     = 1.95,
	AN_Other   = 1.25,
	AN_Engine  = "Automatico",
	-- EXTRAS ----------------------------------------------------
	EX_Sounds  = false,   -- silenciar sons distantes
	EX_Cap     = true,    -- limitar FPS com janela minimizada
	EX_MinFPS  = 60,
	EX_HUD     = true,
}

--======================================= PALETAS DO FILTRO
-- a = luz/aura principal | b = luz secundaria | fog = cor da nevoa/horizonte
-- amb/out = luz ambiente | shadow = cor da sombra suave
local Palettes = {
	["Sunset Fogo"] = {
		a = rgb(255, 108, 46), b = rgb(255, 52, 130), fog = rgb(255, 150, 96),
		amb = rgb(126, 72, 62), out = rgb(255, 188, 138), shadow = rgb(86, 46, 62),
		nice = "por do sol eterno",
	},
	["Neon Roxo"] = {
		a = rgb(176, 62, 255), b = rgb(64, 226, 255), fog = rgb(98, 48, 152),
		amb = rgb(70, 48, 118), out = rgb(180, 140, 255), shadow = rgb(60, 32, 96),
		nice = "cidade neon",
	},
	["Cyber Azul"] = {
		a = rgb(0, 186, 255), b = rgb(0, 255, 200), fog = rgb(12, 66, 124),
		amb = rgb(30, 62, 104), out = rgb(120, 200, 255), shadow = rgb(16, 40, 76),
		nice = "cyber gelado",
	},
	["Realista Quente"] = {
		a = rgb(255, 178, 118), b = rgb(255, 214, 160), fog = rgb(206, 180, 158),
		amb = rgb(104, 92, 84), out = rgb(236, 214, 188), shadow = rgb(78, 66, 60),
		nice = "filme realista",
	},
	["Verde Toxico"] = {
		a = rgb(126, 255, 62), b = rgb(0, 255, 176), fog = rgb(44, 96, 34),
		amb = rgb(48, 82, 40), out = rgb(168, 255, 148), shadow = rgb(28, 58, 30),
		nice = "laboratorio",
	},
	["Rosa Acido"] = {
		a = rgb(255, 44, 152), b = rgb(255, 196, 64), fog = rgb(126, 34, 96),
		amb = rgb(96, 40, 84), out = rgb(255, 168, 216), shadow = rgb(70, 24, 60),
		nice = "candy punch",
	},
	["Inferno"] = {
		a = rgb(255, 42, 20), b = rgb(255, 148, 0), fog = rgb(118, 26, 14),
		amb = rgb(84, 32, 24), out = rgb(255, 140, 88), shadow = rgb(58, 16, 12),
		nice = "inferno vivo",
	},
	["Dourado Real"] = {
		a = rgb(255, 208, 88), b = rgb(255, 122, 40), fog = rgb(146, 108, 56),
		amb = rgb(92, 74, 46), out = rgb(255, 216, 156), shadow = rgb(66, 50, 30),
		nice = "luxo dourado",
	},
}

local PaletteOrder = {
	"Sunset Fogo", "Neon Roxo", "Cyber Azul", "Realista Quente",
	"Verde Toxico", "Rosa Acido", "Inferno", "Dourado Real",
}

local function palette() return Palettes[CFG.SK_Palette] or Palettes["Sunset Fogo"] end

--======================================= ESTADO GLOBAL
-- funcoes definidas mais abaixo (declaradas aqui para uso interno)
local notify = function() end
local syncUI = function() end
local updateStatusLabels = function() end
local applyPreset = function() end

local State = {
	fps        = 60,
	fpsSmooth  = 60,
	instances  = 0,
	hidden     = 0,
	killed     = 0,
	phase      = 0,
	scanning   = true,
	capped     = false,
	mem        = 0,
	running    = true,
}

--======================================= BASELINE (valores originais do jogo)
-- Tudo que mexemos e restauravel a partir daqui.
local Baseline = {
	lighting = {},
	terrain  = {},
	ws       = {},
	done     = false,
}

local Stashed = {}   -- instancias guardadas (skybox, nuvens, atmosfera...)

local function stash(inst)
	if inst and inst.Parent then
		Stashed[#Stashed + 1] = { i = inst, p = inst.Parent }
		pcall(function() inst.Parent = nil end)
	end
end

local function unstashAll()
	for i = #Stashed, 1, -1 do
		local s = Stashed[i]
		if s.i and s.p then pcall(function() s.i.Parent = s.p end) end
		Stashed[i] = nil
	end
	Stashed = {}
end

local LightingProps = {
	"Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "GeographicLatitude",
	"GlobalShadows", "ShadowSoftness", "FogColor", "FogStart", "FogEnd",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ExposureCompensation",
	"ColorShift_Top", "ColorShift_Bottom",
}

local TerrainProps = {
	"Decoration", "WaterWaveSize", "WaterWaveSpeed", "WaterTransparency", "WaterReflectance",
}

local function captureBaseline()
	if Baseline.done then return end
	Baseline.done = true
	for i = 1, #LightingProps do
		local p = LightingProps[i]
		local v = getProp(Lighting, p)
		if v ~= nil then Baseline.lighting[p] = v end
	end
	if Terrain then
		for i = 1, #TerrainProps do
			local p = TerrainProps[i]
			local v = getProp(Terrain, p)
			if v ~= nil then Baseline.terrain[p] = v end
		end
	end
	local lod = getProp(Ws, "FallbackLevelOfDetail")
	if lod ~= nil then Baseline.ws.FallbackLevelOfDetail = lod end
end

local function restoreLighting()
	for p, v in pairs(Baseline.lighting) do
		trySet(Lighting, p, v)
	end
end

local function restoreTerrain()
	if not Terrain then return end
	for p, v in pairs(Baseline.terrain) do
		trySet(Terrain, p, v)
	end
end

--======================================= MODULO: EFEITOS
-- Desliga particulas, luzes, rastros, beams, highlights. Guarda o valor
-- original de cada propriedade para restaurar depois.
local EffectProp = {
	ParticleEmitter = "Enabled",
	Beam            = "Enabled",
	Trail           = "Enabled",
	Smoke           = "Enabled",
	Fire            = "Enabled",
	Sparkles        = "Enabled",
	PointLight      = "Enabled",
	SpotLight       = "Enabled",
	SurfaceLight    = "Enabled",
	Highlight       = "Enabled",
	SelectionBox    = "Visible",
}

local Effects = { list = {}, count = 0 }
local EffectOf = setmetatable({}, { __mode = "k" })   -- instancia -> registro

function Effects.handle(inst)
	local prop = EffectProp[inst.ClassName]
	if not prop then return end
	if isALG(inst) then return end
	local rec = EffectOf[inst]
	if rec then
		if getProp(inst, prop) then trySet(inst, prop, false) end
		return
	end
	if Effects.count >= MAXEFF then return end
	local v = getProp(inst, prop)
	if v == nil then return end
	EffectOf[inst] = { p = prop, v = v }
	Effects.list[#Effects.list + 1] = inst
	Effects.count = Effects.count + 1
	State.killed = State.killed + 1
	if v then trySet(inst, prop, false) end
end

function Effects.revert()
	local list = Effects.list
	for i = 1, #list do
		local inst = list[i]
		local rec = EffectOf[inst]
		if rec and inst.Parent then trySet(inst, rec.p, rec.v) end
	end
	Effects.list = {}
	Effects.count = 0
	EffectOf = setmetatable({}, { __mode = "k" })
	State.killed = 0
end

-- limpa registros mortos (jogo destroi e recria efeitos sem parar)
function Effects.compact()
	local list = Effects.list
	local n = 0
	for i = 1, #list do
		local inst = list[i]
		if inst.Parent then
			n = n + 1
			list[n] = inst
		end
	end
	for i = n + 1, #list do list[i] = nil end
	Effects.count = n
end

--======================================= MODULO: TEXTURAS / DECAIS / PBR
local TextureMap = {
	Decal            = { "Texture" },
	Texture          = { "Texture" },
	SurfaceAppearance = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	MeshPart         = { "TextureID" },
	SpecialMesh      = { "TextureId" },
}

local Textures = { list = {}, count = 0 }
local TextureOf = setmetatable({}, { __mode = "k" })

function Textures.handle(inst)
	local props = TextureMap[inst.ClassName]
	if not props then return end
	if isALG(inst) then return end
	if TextureOf[inst] then return end
	if Textures.count >= MAXEFF then return end
	local saved = {}
	local any = false
	for i = 1, #props do
		local p = props[i]
		local v = getProp(inst, p)
		if type(v) == "string" and v ~= "" then
			saved[p] = v
			any = true
			trySet(inst, p, "")
		end
	end
	if not any then return end
	TextureOf[inst] = saved
	Textures.list[#Textures.list + 1] = inst
	Textures.count = Textures.count + 1
end

function Textures.revert()
	local list = Textures.list
	for i = 1, #list do
		local inst = list[i]
		local saved = TextureOf[inst]
		if saved and inst.Parent then
			for p, v in pairs(saved) do trySet(inst, p, v) end
		end
	end
	Textures.list = {}
	Textures.count = 0
	TextureOf = setmetatable({}, { __mode = "k" })
end

--======================================= MODULO: TERRENO (grama / agua)
local TerrainMod = {}

function TerrainMod.apply()
	if not Terrain then return end
	if not CFG.AL_Grass then
		restoreTerrain()
		return
	end
	trySet(Terrain, "Decoration", false)
	trySet(Terrain, "WaterWaveSize", 0)
	trySet(Terrain, "WaterWaveSpeed", 0)
	trySet(Terrain, "WaterReflectance", 0)
end

function TerrainMod.revert()
	restoreTerrain()
end

--======================================= MODULO: CEU / NUVENS / NEVOA DO JOGO
local SkyMod = {}
local skyStashed = false

function SkyMod.apply()
	-- sempre devolve o que guardamos antes de recalcular (fica idempotente)
	if skyStashed then unstashAll(); skyStashed = false end
	if not CFG.AL_Sky then return end

	local changed = false
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky and not isALG(sky) then stash(sky); changed = true end
	local clouds = Lighting:FindFirstChildOfClass("Clouds")
	if clouds and not isALG(clouds) then stash(clouds); changed = true end
	-- a atmosfera so vai embora se o skin nao estiver cuidando dela
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm and not isALG(atm) and not (CFG.SK_On and CFG.SK_Atmos) then
		stash(atm)
		changed = true
	end
	if changed then skyStashed = true end
end

function SkyMod.revert()
	if skyStashed then unstashAll(); skyStashed = false end
end

--======================================= MODULO: RENDER / QUALIDADE
local RenderMod = {}

function RenderMod.apply()
	-- sombras: desliga ou devolve o original do jogo
	if CFG.AL_Shadows then
		trySet(Lighting, "GlobalShadows", false)
		trySet(Lighting, "ShadowSoftness", 0)
	else
		local gs = Baseline.lighting.GlobalShadows
		trySet(Lighting, "GlobalShadows", gs ~= false and gs ~= nil)
		trySet(Lighting, "ShadowSoftness", Baseline.lighting.ShadowSoftness or 0)
	end
	-- qualidade de render / luz ambiente
	if CFG.AL_RenderQ then
		trySet(Lighting, "EnvironmentDiffuseScale", 0)
		trySet(Lighting, "EnvironmentSpecularScale", 0)
		trySet(Ws, "FallbackLevelOfDetail", Enum.LevelOfDetailSetting.Low)
		pcall(function()
			UserSettings():GetService("UserGameSettings").SavedQualityLevel =
				Enum.SavedQualitySetting.QualityLevel1
		end)
		pcall(function()
			settings().Rendering.QualityLevel = 1
		end)
	else
		trySet(Lighting, "EnvironmentDiffuseScale",
			Baseline.lighting.EnvironmentDiffuseScale or 1)
		trySet(Lighting, "EnvironmentSpecularScale",
			Baseline.lighting.EnvironmentSpecularScale or 1)
		trySet(Ws, "FallbackLevelOfDetail",
			Baseline.ws.FallbackLevelOfDetail or Enum.LevelOfDetailSetting.High)
	end
end

function RenderMod.revert()
	restoreLighting()
	trySet(Ws, "FallbackLevelOfDetail",
		Baseline.ws.FallbackLevelOfDetail or Enum.LevelOfDetailSetting.High)
	trySet(Lighting, "GlobalShadows", true)
end

--======================================= MODULO: SONS DISTANTES
local Sounds = { list = {}, cursor = 1, count = 0, muted = 0 }
local SoundOf = setmetatable({}, { __mode = "k" })

function Sounds.handle(inst)
	if inst.ClassName ~= "Sound" then return end
	if isALG(inst) or SoundOf[inst] then return end
	if Sounds.count >= 3000 then return end
	local parentPart = inst.Parent
	if not parentPart or not parentPart:IsA("BasePart") then return end
	local v = getProp(inst, "Volume")
	if type(v) ~= "number" then return end
	local e = { s = inst, v = v, h = false }
	Sounds.list[#Sounds.list + 1] = e
	SoundOf[inst] = e
	Sounds.count = Sounds.count + 1
end

function Sounds.step(budget)
	if not CFG.EX_Sounds then
		if Sounds.muted > 0 then Sounds.unmuteAll() end
		return
	end
	local list = Sounds.list
	local n = #list
	if n == 0 then return end
	local cam = Ws.CurrentCamera
	if not cam then return end
	local cp = cam.CFrame.Position
	local lim = CFG.AL_Dist * 0.85
	local lim2 = lim * lim
	local i = Sounds.cursor
	local stop = i + budget
	while i < stop do
		if i > n then break end
		local e = list[i]
		local s = e.s
		local parent = s and s.Parent
		if parent and parent:IsA("BasePart") then
			local pp = parent.Position
			local far = dist2(pp.X, pp.Y, pp.Z, cp.X, cp.Y, cp.Z) > lim2
			if far and not e.h then
				if getProp(s, "Volume") ~= 0 then trySet(s, "Volume", 0) end
				e.h = true
				Sounds.muted = Sounds.muted + 1
			elseif (not far) and e.h then
				trySet(s, "Volume", e.v)
				e.h = false
				Sounds.muted = math.max(0, Sounds.muted - 1)
			end
		end
		i = i + 1
	end
	if i > n then i = 1 end
	Sounds.cursor = i
end

function Sounds.unmuteAll()
	local list = Sounds.list
	for i = 1, #list do
		local e = list[i]
		if e.h and e.s and e.s.Parent then
			trySet(e.s, "Volume", e.v)
			e.h = false
		end
	end
	Sounds.muted = 0
end

function Sounds.revert()
	Sounds.unmuteAll()
	Sounds.list = {}
	Sounds.count = 0
	Sounds.cursor = 1
	Sounds.muted = 0
	SoundOf = setmetatable({}, { __mode = "k" })
end

--======================================= MODULO: CULL (esconder cenario distante)
-- Motor principal do anti-lag. Divide o mapa em celulas de 64 studs e so
-- recalcula as celulas proximas da camera (anel). Cada celula recebe um
-- veredito (visivel/escondido) e as pecas so sao tocadas quando o veredito
-- muda, com histerese para nao piscar.
local PartClasses = {
	Part = true, MeshPart = true, UnionOperation = true, WedgePart = true,
	CornerWedgePart = true, TrussPart = true, SpawnLocation = true,
	Seat = true, VehicleSeat = true,
}

local Cull = {
	cells      = {},      -- key -> cell
	cellList   = {},      -- array de celulas (varredura)
	dynamic    = {},      -- pecas que se mexem
	queue      = {},      -- fila de containers para escanear
	count      = 0,
	hidden     = 0,
	deadCells  = 0,
	sweepCursor = 1,
	lastEval   = 0,
	lastCam    = nil,
	force      = true,
	scanned    = false,
	gcTimer    = 0,
	visualsOnly = false,
}

local EntryOf = setmetatable({}, { __mode = "k" })   -- peca -> entrada

local function cellIndex(v) return math.floor(v / CELL) end

local function cellKey(px, py, pz)
	local ix, iy, iz = cellIndex(px), cellIndex(py), cellIndex(pz)
	if ix < -511 then ix = -511 elseif ix > 511 then ix = 511 end
	if iy < -511 then iy = -511 elseif iy > 511 then iy = 511 end
	if iz < -511 then iz = -511 elseif iz > 511 then iz = 511 end
	return (ix + 512) * 1048576 + (iy + 512) * 1024 + (iz + 512)
end

function Cull.applyEntry(e, visible)
	local p = e.p
	if visible then
		if e.h then
			e.h = false
			Cull.hidden = Cull.hidden - 1
			trySet(p, "Transparency", e.t)
		end
	else
		if not e.h then
			e.h = true
			Cull.hidden = Cull.hidden + 1
			trySet(p, "Transparency", 1)
		end
	end
end

function Cull.applyCell(cell, visible)
	local list = cell.list
	for i = 1, #list do
		local e = list[i]
		local p = e.p
		if p and p.Parent then
			Cull.applyEntry(e, visible)
		end
	end
end

function Cull.addPart(part)
	if EntryOf[part] then return end
	if Cull.count >= MAXPARTS then State.capped = true return end

	local pos = getProp(part, "Position")
	if not pos then return end
	local t = getProp(part, "Transparency")
	if type(t) ~= "number" then t = 0 end
	if t >= 0.98 then return end

	local px, py, pz = pos.X, pos.Y, pos.Z
	local dyn = getProp(part, "Anchored") == false
	if not dyn then
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then dyn = true end
	end

	if dyn and #Cull.dynamic < MAXDYN then
		local e = { p = part, px = px, py = py, pz = pz, t = t, h = false, dyn = true, c = dyn }
		Cull.dynamic[#Cull.dynamic + 1] = e
		EntryOf[part] = e
		Cull.count = Cull.count + 1
		return
	end

	local k = cellKey(px, py, pz)
	local cell = Cull.cells[k]
	if not cell then
		local ix, iy, iz = cellIndex(px), cellIndex(py), cellIndex(pz)
		cell = {
			key = k,
			x = ix * CELL + CELL * 0.5,
			y = iy * CELL + CELL * 0.5,
			z = iz * CELL + CELL * 0.5,
			list = {},
			v = nil,
			idx = #Cull.cellList + 1,
		}
		Cull.cells[k] = cell
		Cull.cellList[cell.idx] = cell
	end

	local e = { p = part, px = px, py = py, pz = pz, t = t, h = false, cell = cell }
	cell.list[#cell.list + 1] = e
	EntryOf[part] = e
	Cull.count = Cull.count + 1

	local cam = Ws.CurrentCamera
	if cam then
		local cp = cam.CFrame.Position
		local c2 = dist2(cp.X, cp.Y, cp.Z, cell.x, cell.y, cell.z)
		local r = CFG.AL_Dist
		local inside = c2 <= r * r
		if cell.v == nil then cell.v = inside end
		if not cell.v then Cull.applyEntry(e, false) end
	end
end

function Cull.inspect(inst)
	if isALG(inst) then return end
	local class = inst.ClassName

	if CFG.AL_Effects and EffectProp[class] then Effects.handle(inst) end
	if CFG.AL_Textures and TextureMap[class] then Textures.handle(inst) end
	if class == "Sound" then Sounds.handle(inst) end
	-- varredura leve (so efeitos/texturas/sons): nao mexe em transparencia
	if Cull.visualsOnly then return end
	if not CFG.AL_Parts then return end

	local isPart = PartClasses[class]
	if not isPart then
		if class == "Terrain" then return end
		isPart = inst:IsA("BasePart")
	end
	if not isPart then return end

	local char = LocalPlayer.Character
	if char and inst:IsDescendantOf(char) then return end
	Cull.addPart(inst)
end

-- varredura incremental do mapa (nao trava o primeiro frame)
function Cull.scanStep()
	local budget = CFG.AL_Rate
	local queue = Cull.queue
	while budget > 0 and #queue > 0 do
		local container = queue[#queue]
		queue[#queue] = nil
		local children = container:GetChildren()
		for i = 1, #children do
			local ch = children[i]
			budget = budget - 1
			if not Cull.visualsOnly then State.instances = State.instances + 1 end
			Cull.inspect(ch)
			queue[#queue + 1] = ch
		end
	end
	if #queue == 0 then
		if Cull.visualsOnly then
			Cull.visualsOnly = false
			State.scanning = false
		elseif not Cull.scanned then
			Cull.scanned = true
			State.scanning = false
			Cull.force = true
		end
	end
end

-- varredura leve: reaplica efeitos/texturas sem soltar a transparencia
-- (usada quando o usuario liga/desliga esses modulos ou na emergencia)
function Cull.rescanVisuals()
	if State.scanning then return end
	Cull.queue = { Ws }
	Cull.visualsOnly = true
	State.scanning = true
end

-- avalia o anel de celulas em volta da camera
function Cull.evaluate()
	local cam = Ws.CurrentCamera
	if not cam then return end
	local cp = cam.CFrame.Position
	local t = now()
	local moved = 1e9
	if Cull.lastCam then
		local lc = Cull.lastCam
		moved = math.sqrt(dist2(cp.X, cp.Y, cp.Z, lc.X, lc.Y, lc.Z))
	end
	if not Cull.force and moved < 18 and (t - Cull.lastEval) < 1.2 then return end
	Cull.force = false
	Cull.lastEval = t
	Cull.lastCam = cp

	local r = CFG.AL_Dist
	local margin = 46 + moved
	local lim2 = (r + margin) * (r + margin)
	local r2 = r * r
	local r2h = r2 * 0.8464   -- 0.92^2 -> histerese
	local cells = Cull.cells
	for k, cell in pairs(cells) do
		local list = cell.list
		if #list > 0 then
			local c2 = dist2(cp.X, cp.Y, cp.Z, cell.x, cell.y, cell.z)
			if c2 <= lim2 then
				local limit = cell.v and r2 or r2h
				local inside = c2 <= limit
				if inside ~= (cell.v == true) then
					cell.v = inside
					Cull.applyCell(cell, inside)
				end
			elseif cell.v then
				cell.v = false
				Cull.applyCell(cell, false)
			end
		end
	end
end

-- pecas dinamicas (personagens, fisica): checagem por frame, e barato
function Cull.dynamicStep()
	local list = Cull.dynamic
	local n = #list
	if n == 0 then return end
	local cam = Ws.CurrentCamera
	if not cam then return end
	local cp = cam.CFrame.Position
	local r = CFG.AL_Dist
	local i = 1
	while i <= n do
		local e = list[i]
		local p = e.p
		if not p or not p.Parent then
			if e.h then Cull.hidden = Cull.hidden - 1 end
			Cull.count = math.max(0, Cull.count - 1)
			list[i] = list[n]
			list[n] = nil
			n = n - 1
		else
			local pos = getProp(p, "Position")
			if pos then
				e.px, e.py, e.pz = pos.X, pos.Y, pos.Z
				local lim = r
				if e.c and CFG.AL_Extreme then lim = r * 0.4 end
				local lim2 = lim * lim
				if e.h then lim2 = lim2 * 0.85 end
				local d2 = dist2(cp.X, cp.Y, cp.Z, pos.X, pos.Y, pos.Z)
				if d2 > lim2 then
					Cull.applyEntry(e, false)
				else
					Cull.applyEntry(e, true)
				end
			end
			i = i + 1
		end
	end
end

-- manutencao: remove pecas mortas, re-aplica transparencia (caso o jogo
-- devolva o valor) e recolhe celulas vazias
function Cull.maintenance(budget)
	local list = Cull.cellList
	local n = #list
	if n == 0 then return end
	local i = Cull.sweepCursor
	local stop = i + budget
	while i < stop do
		if i > n then break end
		local cell = list[i]
		if cell then
			local parts = cell.list
			local w = 0
			for j = 1, #parts do
				local e = parts[j]
				local p = e.p
				if p and p.Parent then
					w = w + 1
					parts[w] = e
					if e.h and (not cell.v) then
						if getProp(p, "Transparency") ~= 1 then
							trySet(p, "Transparency", 1)
						end
					end
				elseif e.h then
					e.h = false
					Cull.hidden = Cull.hidden - 1
				end
				if not (p and p.Parent) then
					Cull.count = math.max(0, Cull.count - 1)
				end
			end
			for j = w + 1, #parts do parts[j] = nil end
			if w == 0 then
				cell.v = false
				cell.dead = true
				Cull.deadCells = Cull.deadCells + 1
			end
		end
		i = i + 1
	end
	if i > n then i = 1 end
	Cull.sweepCursor = i
end

-- recolhe celulas vazias de vez em quando (nao roda sempre = nao pesa)
function Cull.gcCells()
	local cells = Cull.cells
	local list = Cull.cellList
	local newCells, newList = {}, {}
	for i = 1, #list do
		local cell = list[i]
		if cell and not cell.dead then
			cell.idx = #newList + 1
			newList[cell.idx] = cell
			newCells[cell.key] = cell
		end
	end
	Cull.cells = newCells
	Cull.cellList = newList
	Cull.deadCells = 0
	Cull.sweepCursor = 1
end

function Cull.revert()
	-- devolve transparencia de tudo que escondemos
	local list = Cull.cellList
	for i = 1, #list do
		local cell = list[i]
		if cell then
			local parts = cell.list
			for j = 1, #parts do
				local e = parts[j]
				if e.h then
					e.h = false
					trySet(e.p, "Transparency", e.t)
				end
			end
			parts = nil
		end
	end
	for i = 1, #Cull.dynamic do
		local e = Cull.dynamic[i]
		if e.h then
			e.h = false
			trySet(e.p, "Transparency", e.t)
		end
	end
	Cull.cells = {}
	Cull.cellList = {}
	Cull.dynamic = {}
	Cull.queue = {}
	Cull.count = 0
	Cull.hidden = 0
	Cull.deadCells = 0
	Cull.scanned = false
	Cull.sweepCursor = 1
	Cull.force = true
	Cull.visualsOnly = false
	EntryOf = setmetatable({}, { __mode = "k" })
end

function Cull.start()
	Cull.revert()
	Cull.queue = { Ws }
	State.scanning = true
	State.capped = false
end

--======================================= AUTO-EMERGENCIA (FPS baixo)
local Emergency = { level = 0, low = 0, high = 0 }

function Emergency.step(dt)
	if not CFG.AL_Auto then
		Emergency.low = 0
		Emergency.high = 0
		return
	end
	local f = State.fpsSmooth
	if f < 24 then
		Emergency.low = Emergency.low + dt
		Emergency.high = 0
	elseif f > 42 then
		Emergency.high = Emergency.high + dt
		Emergency.low = 0
	else
		Emergency.low = math.max(0, Emergency.low - dt * 0.5)
	end

	if Emergency.low >= 3 and Emergency.level < 3 then
		Emergency.level = Emergency.level + 1
		Emergency.low = 0
		pcall(function() UI.Drops.Preset:Set({ "Personalizado" }) end)
		if Emergency.level == 1 then
			CFG.AL_Effects = true
			CFG.AL_Rate = math.max(CFG.AL_Rate, 320)
			Effects.compact()
			CFG.AL_Dist = math.max(140, CFG.AL_Dist * 0.75)
			Cull.rescanVisuals()
			Cull.force = true
			notify("Emergencia 1/3", "FPS baixo: efeitos desligados e distancia reduzida.", "zap")
		elseif Emergency.level == 2 then
			CFG.AL_Textures = true
			CFG.AL_Grass = true
			CFG.AL_Sky = true
			CFG.AL_Shadows = true
			CFG.AL_RenderQ = true
			CFG.AL_Dist = math.max(110, CFG.AL_Dist * 0.8)
			Cull.rescanVisuals()
			TerrainMod.apply()
			SkyMod.apply()
			RenderMod.apply()
			Cull.force = true
			notify("Emergencia 2/3", "Cortando texturas, grama, ceu e sombras.", "zap")
		else
			CFG.AL_Extreme = true
			CFG.AL_Dist = math.max(90, CFG.AL_Dist * 0.8)
			Cull.force = true
			notify("Emergencia 3/3", "Modo extremo: jogadores distantes somem.", "zap")
		end
		syncUI()
	end

	if Emergency.high >= 8 and Emergency.level > 0 then
		Emergency.high = 0
		Emergency.level = Emergency.level - 1
		notify("Recuperado", "FPS normalizou. Aliviando o anti-lag (nivel " ..
			tostring(Emergency.level) .. ").", "check")
	end
end

--======================================= MODULO: SKIN "VIDA" (filtro)
-- Aqui e onde o jogo deixa de ficar sem graca: color grading, nevoa
-- colorida, atmosfera, bloom, aura, rastro e "respiracao" do filtro.
local Skin = {
	phase = 0,
	acc = 0,
	baseFOV = 70,
	fovLocked = false,
}

function Skin.inst(class, name, parent)
	local box = parent or Lighting
	local inst = box:FindFirstChild(name)
	if inst and inst.ClassName ~= class then
		pcall(function() inst:Destroy() end)
		inst = nil
	end
	if not inst then
		inst = Instance.new(class)
		inst.Name = name
		inst.Parent = box
	end
	return inst
end

local function clearOurEffects()
	local names = { "ALG_Grade", "ALG_Bloom", "ALG_SunRays", "ALG_DOF", "ALG_Atmos", "ALG_Clouds" }
	for i = 1, #names do
		local inst = Lighting:FindFirstChild(names[i])
		if inst then pcall(function() inst:Destroy() end) end
	end
end

-- aura de luz no personagem
function Skin.auraApply()
	local P = palette()
	local I = CFG.SK_Int / 100
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = hum and hum.RootPart
	if not hrp then return end
	local l = hrp:FindFirstChild("ALG_Aura")
	if not l then
		l = Instance.new("PointLight")
		l.Name = "ALG_Aura"
		l.Parent = hrp
	end
	l.Enabled = CFG.SK_On and CFG.SK_Aura
	l.Color = P.a
	l.Range = 10 + 20 * I
	l.Brightness = 0.5 + 2.0 * I
	l.Shadows = false
	Skin.light = l
end

-- rastro neon
function Skin.trailApply()
	local P = palette()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = hum and hum.RootPart
	if not hrp then return end
	local tr = hrp:FindFirstChild("ALG_Trail")
	if not tr then
		local a0 = Instance.new("Attachment")
		a0.Name = "ALG_T0"
		a0.Position = Vector3.new(0, 1, 0)
		a0.Parent = hrp
		local a1 = Instance.new("Attachment")
		a1.Name = "ALG_T1"
		a1.Position = Vector3.new(0, -1.1, 0)
		a1.Parent = hrp
		tr = Instance.new("Trail")
		tr.Name = "ALG_Trail"
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Parent = hrp
	end
	tr.Enabled = CFG.SK_On and CFG.SK_Trail
	tr.LightEmission = 0.9
	tr.LightInfluence = 0
	tr.Lifetime = 0.45
	tr.MinLength = 0.1
	tr.FaceCamera = false
	tr.Color = ColorSequence.new(P.a, P.b)
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	tr.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	Skin.trail = tr
end

function Skin.attach()
	if not CFG.SK_On then return end
	pcall(Skin.auraApply)
	pcall(Skin.trailApply)
end

-- aplica o filtro inteiro
function Skin.apply()
	if not CFG.SK_On then
		Skin.revert()
		return
	end
	local P = palette()
	local I = clamp(CFG.SK_Int / 100, 0, 1)
	local base = Baseline.lighting

	-- -------- color grading
	local cc = Skin.inst("ColorCorrectionEffect", "ALG_Grade")
	cc.Enabled = CFG.SK_Grade
	cc.Saturation = clamp((CFG.SK_Sat / 100) * (0.35 + 0.9 * I), -1, 1)
	cc.Contrast = clamp((CFG.SK_Con / 100) * (0.15 + 0.55 * I), -1, 1)
	cc.Brightness = clamp(((CFG.SK_Bri - 50) / 100) * 0.18 * (0.4 + I), -1, 1)
	cc.TintColor = mixColor(rgb(255, 255, 255), P.a, (CFG.SK_Tint / 100) * 0.6 * (0.4 + 0.6 * I))

	-- -------- bloom neon
	local bl = Skin.inst("BloomEffect", "ALG_Bloom")
	bl.Enabled = CFG.SK_Bloom
	bl.Intensity = 0.25 + 0.85 * I
	bl.Size = 16 + 14 * I
	bl.Threshold = clamp(1.15 - 0.45 * I, 0.35, 2)

	-- -------- raios de sol suaves
	local sr = Skin.inst("SunRaysEffect", "ALG_SunRays")
	sr.Enabled = CFG.SK_Sun
	sr.Intensity = 0.02 + 0.09 * I
	sr.Spread = 0.7 + 0.25 * I

	-- -------- profundidade de campo (cinema)
	local df = Skin.inst("DepthOfFieldEffect", "ALG_DOF")
	df.Enabled = CFG.SK_DOF
	df.FarIntensity = 0.35 * I
	df.NearIntensity = 0.22 * I
	df.InFocusRadius = 38 + 30 * I
	df.FocusDistance = 28

	-- -------- atmosfera (nevoa viva)
	local at = Skin.inst("Atmosphere", "ALG_Atmos")
	if CFG.SK_Atmos then
		at.Density = 0.14 + 0.34 * I
		at.Offset = 0.05 + 0.1 * I
		at.Glare = 0.1 + 0.45 * I
		at.Haze = 1.1 + 1.7 * I
		at.Color = P.fog
		at.Decay = P.b
		at.Parent = Lighting
	else
		pcall(function() at:Destroy() end)
	end

	-- -------- nevoa (fog) que casa com a distancia do anti-lag
	if CFG.SK_Fog then
		trySet(Lighting, "FogColor", P.fog)
		trySet(Lighting, "FogStart", 0)
		trySet(Lighting, "FogEnd", math.max(150, CFG.AL_Dist * 1.25))
	else
		trySet(Lighting, "FogEnd", base.FogEnd or 100000)
		trySet(Lighting, "FogStart", base.FogStart or 0)
		trySet(Lighting, "FogColor", base.FogColor or rgb(192, 192, 192))
	end

	-- -------- luz ambiente colorida
	if base.Ambient then trySet(Lighting, "Ambient", mixColor(base.Ambient, P.amb, I * 0.85)) end
	if base.OutdoorAmbient then
		trySet(Lighting, "OutdoorAmbient", mixColor(base.OutdoorAmbient, P.out, I * 0.8))
	end
	if base.Brightness then
		trySet(Lighting, "Brightness", clamp(base.Brightness + 0.25 * I, 0, 3))
	end
	if base.ShadowSoftness and not CFG.AL_Shadows then
		trySet(Lighting, "ShadowSoftness", 0.12 + 0.12 * I)
	end
	-- deixa a luz ambiente do jogo respirar um pouco (fica menos "plastico")
	if CFG.AL_RenderQ then
		trySet(Lighting, "EnvironmentDiffuseScale", 0.15 + 0.35 * I)
		trySet(Lighting, "EnvironmentSpecularScale", 0.1 + 0.3 * I)
	end

	-- -------- hora dourada
	if CFG.SK_Hour then
		trySet(Lighting, "ClockTime", 17.35)
		trySet(Lighting, "GeographicLatitude", 12)
	end

	-- -------- nuvens cinematograficas
	local cl = Skin.inst("Clouds", "ALG_Clouds")
	if CFG.SK_Clouds then
		cl.Coverage = 0.34
		cl.Density = 0.55
		cl.Color = mixColor(P.b, P.fog, 0.35)
		cl.Parent = Lighting
	else
		pcall(function() cl:Destroy() end)
	end

	Skin.attach()
end

function Skin.revert()
	clearOurEffects()
	restoreLighting()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = hum and hum.RootPart
	if hrp then
		local l = hrp:FindFirstChild("ALG_Aura")
		if l then pcall(function() l:Destroy() end) end
		local tr = hrp:FindFirstChild("ALG_Trail")
		if tr then pcall(function() tr:Destroy() end) end
		local a0 = hrp:FindFirstChild("ALG_T0")
		if a0 then pcall(function() a0:Destroy() end) end
		local a1 = hrp:FindFirstChild("ALG_T1")
		if a1 then pcall(function() a1:Destroy() end) end
	end
	local cam = Ws.CurrentCamera
	if cam and Skin.fovLocked then trySet(cam, "FieldOfView", Skin.baseFOV) end
	Skin.fovLocked = false
	Skin.light = nil
	Skin.trail = nil
end

-- "respiracao" do filtro (o que faz parecer vivo)
function Skin.step(dt)
	if not CFG.SK_On then return end
	Skin.acc = Skin.acc + dt
	if Skin.acc < 0.08 then return end
	Skin.acc = 0
	local P = palette()
	local I = clamp(CFG.SK_Int / 100, 0, 1)
	if not CFG.SK_Vida then return end
	local s = math.sin(Skin.phase * 0.9)
	local s2 = math.sin(Skin.phase * 0.55 + 1.3)
	local k = 0.5 + 0.5 * s

	local at = Lighting:FindFirstChild("ALG_Atmos")
	if at then
		at.Color = mixColor(P.fog, P.a, 0.18 * k + 0.08 * I)
	end
	local cc = Lighting:FindFirstChild("ALG_Grade")
	if cc and CFG.SK_Grade then
		cc.TintColor = mixColor(rgb(255, 255, 255), P.a,
			(CFG.SK_Tint / 100) * (0.35 + 0.3 * k) * I)
	end
	local l = Skin.light
	if l and l.Parent and l.Enabled then
		l.Brightness = (0.5 + 2.0 * I) * (0.82 + 0.3 * k)
		l.Range = (10 + 20 * I) * (0.94 + 0.12 * s2)
	end
	local bl = Lighting:FindFirstChild("ALG_Bloom")
	if bl and bl.Enabled then
		bl.Intensity = (0.25 + 0.85 * I) * (0.9 + 0.2 * k)
	end
	local df = Lighting:FindFirstChild("ALG_DOF")
	if df and df.Enabled then
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		local root = hum and hum.RootPart
		if root then
			local v = root.AssemblyLinearVelocity or root.Velocity
			if v then
				local sp = math.sqrt(v.X * v.X + v.Z * v.Z)
				df.FocusDistance = 24 + math.min(sp * 1.4, 90)
			end
		end
	end
end

--======================================= CAMERA (fov + camera viva)
local Cam = { bound = false }

local function charSpeed()
	local char = LocalPlayer.Character
	if not char then return 0 end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return 0 end
	local root = hum.RootPart
	if not root then return 0 end
	local v = root.AssemblyLinearVelocity or root.Velocity
	if not v then return 0 end
	return math.sqrt(v.X * v.X + v.Z * v.Z)
end

function Cam.step(dt)
	Skin.phase = Skin.phase + dt
	local cam = Ws.CurrentCamera
	if not cam then return end
	local I = clamp(CFG.SK_Int / 100, 0, 1)

	if CFG.SK_On and CFG.SK_Camera and CFG.SK_Int > 0 then
		local t = Skin.phase * 0.5
		local amp = 0.003 + 0.011 * I
		local nx = math.noise(t, 0.13, 0.71) - 0.5
		local ny = math.noise(0.53, t, 0.29) - 0.5
		if nx ~= 0 or ny ~= 0 then
			trySet(cam, "CFrame", cam.CFrame * CFrame.Angles(nx * amp, ny * amp, (nx - ny) * amp * 0.3))
		end
	end

	if CFG.SK_On and CFG.SK_LockFOV then
		if not Skin.fovLocked then
			Skin.baseFOV = getProp(cam, "FieldOfView") or 70
			Skin.fovLocked = true
		end
		local target = CFG.SK_FOV
		if CFG.SK_CineFOV then
			target = target + clamp(charSpeed() * 0.32, 0, 14)
		end
		if CFG.SK_Vida then
			target = target - 0.6 + 0.6 * math.sin(Skin.phase * 1.1)
		end
		local cur = getProp(cam, "FieldOfView") or target
		trySet(cam, "FieldOfView", cur + (target - cur) * math.min(1, dt * 2.5))
	end

	Skin.step(dt)
end

function Cam.bind()
	if Cam.bound then return end
	Cam.bound = true
	local ok = pcall(function()
		RunService:BindToRenderStep("ALG_Cam", Enum.RenderPriority.Camera.Value + 1, Cam.step)
	end)
	if not ok then
		Cam.conn = RunService.RenderStepped:Connect(Cam.step)
	end
end

function Cam.unbind()
	if not Cam.bound then return end
	Cam.bound = false
	pcall(function() RunService:UnbindFromRenderStep("ALG_Cam") end)
	if Cam.conn then
		pcall(function() Cam.conn:Disconnect() end)
		Cam.conn = nil
	end
end

--======================================= MODULO: ANIMACAO "VIVA"
-- Deixa a animacao mais rapida SEM mudar sua velocidade real.
-- Motor 1 (padrao): faz patch seguro do script Animate do proprio jogo
--   (troca apenas os numeros de velocidade de reproducao).
-- Motor 2 (opcional): animador nativo proprio (para jogos com Animate
--   customizado ou Source bloqueado).
local R6Anims = {
	idle = 180435571, walk = 180426354, run = 180426354, jump = 125750702,
	fall = 180436148, climb = 180436334, swim = 180426354, sit = 178130996,
}
local R15Anims = {
	idle = 507766388, walk = 507777826, run = 507767714, jump = 507765000,
	fall = 507767968, climb = 507765644, swim = 507784897, sit = 2506281703,
}

local Anim = {
	srcOf   = setmetatable({}, { __mode = "k" }),
	mode    = "off",
	status  = "desligado",
	patches = 0,
	tracks  = {},
	cur     = nil,
	curTrack = nil,
	backup  = nil,
	conns   = {},
}

local function animSettings()
	local w = clamp(CFG.AN_Walk, 0.5, 4)
	local r = clamp(CFG.AN_Run, 0.5, 4)
	local o = clamp(CFG.AN_Other, 0.5, 4)
	return w, r, o
end

-- monta a versao patcheada do Animate do jogo
local function buildPatched(src)
	local w, r, o = animSettings()
	local patches = 0
	local out = src

	-- 1) Animate classico com blend de correr/andar: usa o nome do track
	out = out:gsub("([%w_%.:]+):AdjustSpeed%s*%(%s*animSpeed%s*%)", function(prefix)
		patches = patches + 1
		return prefix .. ':AdjustSpeed(animSpeed * ((n == "run") and ALG.RUN or ALG.WALK))'
	end)
	-- 2) Animate R6/R15: track de correr e de andar separados
	out = out:gsub("([%w_%.:]*runAnimTrack):AdjustSpeed%s*%(%s*timeWarp%s*%)", function(prefix)
		patches = patches + 1
		return prefix .. ":AdjustSpeed(timeWarp * ALG.RUN)"
	end)
	out = out:gsub("([%w_%.:]*currentAnimTrack):AdjustSpeed%s*%(%s*timeWarp%s*%)", function(prefix)
		patches = patches + 1
		return prefix .. ":AdjustSpeed(timeWarp * ALG.WALK)"
	end)
	-- 3) Animate customizado (nomes de variavel proprios)
	out = out:gsub("([%w_%.:]+):AdjustSpeed%s*%(%s*walkAnimationTimewarp%s*%)", function(prefix)
		patches = patches + 1
		return prefix .. ":AdjustSpeed(walkAnimationTimewarp * ALG.WALK)"
	end)
	out = out:gsub("([%w_%.:]+):AdjustSpeed%s*%(%s*runAnimationTimewarp%s*%)", function(prefix)
		patches = patches + 1
		return prefix .. ":AdjustSpeed(runAnimationTimewarp * ALG.RUN)"
	end)
	-- 4) resto (parado, pulo, queda, escalada, natacao, ferramentas)
	out = out:gsub("([%w_%.:]+):AdjustSpeed%s*%(([%w_%.:%s/%*%-%+]*)%)", function(prefix, arg)
		if not prefix or not arg then return nil end
		if string.find(arg, "ALG%.") then return nil end
		local clean = string.gsub(arg, "^%s*(.-)%s*$", "%1")
		if clean == "" then return nil end
		patches = patches + 1
		return prefix .. ":AdjustSpeed((" .. clean .. ") * ALG.OTHER)"
	end)

	local preamble = string.format(
		"local ALG = {WALK=%.3f, RUN=%.3f, OTHER=%.3f}\n", w, r, o)
	return preamble .. out, patches
end

-- MOTOR 1: patch do Animate do jogo
local function tryPatch(orig)
	if not orig then return false, "sem script Animate" end
	if type(loadstring) ~= "function" then return false, "loadstring indisponivel" end
	local src = getProp(orig, "Source")
	if type(src) ~= "string" or #src < 60 then return false, "Source bloqueado" end

	local patched, patches = buildPatched(src)
	if patches == 0 then return false, "padrao desconhecido" end
	local fn, err = loadstring(patched)
	if not fn then return false, "patch invalido" end

	if Anim.srcOf[orig] == nil then Anim.srcOf[orig] = src end
	if not trySet(orig, "Source", patched) then return false, "escrita bloqueada" end
	local check = getProp(orig, "Source")
	if type(check) == "string" and string.find(check, "ALG%.") then
		Anim.patches = patches
		return true, patches .. " patches"
	end
	return false, "patch nao aplicado"
end

-- MOTOR 2: animador nativo
local function builtinStop()
	for i = 1, #Anim.conns do
		local c = Anim.conns[i]
		if c then pcall(function() c:Disconnect() end) end
	end
	Anim.conns = {}
	Anim.tracks = {}
	Anim.cur = nil
	Anim.curTrack = nil
	if Anim.backup then
		local ok = pcall(function()
			local char = LocalPlayer.Character
			if char and not char:FindFirstChild("Animate") then
				Anim.backup.Parent = char
			end
		end)
		Anim.backup = nil
	end
end

local function builtinStart()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return false, "sem personagem" end

	builtinStop()

	local orig = char:FindFirstChild("Animate")
	if orig then
		Anim.backup = orig
		pcall(function() orig.Parent = nil end)
	end

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		local ok = pcall(function() animator = Instance.new("Animator", hum) end)
		if not ok then return false, "sem Animator" end
	end

	local r15 = (getProp(hum, "RigType") == Enum.HumanoidRigType.R15)
	local ids = r15 and R15Anims or R6Anims
	local tracks = {}
	for name, id in pairs(ids) do
		local a = Instance.new("Animation")
		a.AnimationId = "rbxassetid://" .. tostring(id)
		local ok, track = pcall(function() return animator:LoadAnimation(a) end)
		if ok and track then
			pcall(function()
				track.Priority = Enum.AnimationPriority.Movement
			end)
			tracks[name] = track
		end
		pcall(function() a:Destroy() end)
	end
	if not (tracks.idle or tracks.walk) then return false, "falha ao carregar" end

	local function play(name, fade, speed)
		local t = tracks[name] or tracks.idle
		if not t then return end
		if Anim.curTrack ~= t then
			if Anim.curTrack then pcall(function() Anim.curTrack:Stop(fade) end) end
			pcall(function() t:Play(fade) end)
			Anim.curTrack = t
			Anim.cur = name
		end
		pcall(function() t:AdjustSpeed(speed or 1) end)
	end
	Anim.play = play

	local acc = 0
	Anim.conns[#Anim.conns + 1] = RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.08 then return end
		acc = 0
		local c = LocalPlayer.Character
		if not c or c ~= char then return end
		local h = c:FindFirstChildOfClass("Humanoid")
		if not h or h.Health <= 0 then return end
		local w, r, o = animSettings()
		local m = o
		local state = getProp(h, "FloorMaterial")
		local speed = charSpeed()
		local v = h.RootPart and (h.RootPart.AssemblyLinearVelocity or h.RootPart.Velocity)
		local vy = v and v.Y or 0
		local st = nil
		local okState, hs = pcall(function() return h:GetState() end)
		if okState then st = hs end

		if st == Enum.HumanoidStateType.Swimming then
			play("swim", 0.2, 1 * m)
		elseif st == Enum.HumanoidStateType.Climbing then
			play("climb", 0.2, 1 * m)
		elseif st == Enum.HumanoidStateType.Seated then
			play("sit", 0.2, 1)
		elseif state == Enum.Material.Air or st == Enum.HumanoidStateType.Freefall then
			if vy > 2 then
				play("jump", 0.1, 1 * m)
			else
				play("fall", 0.15, 1 * m)
			end
		elseif speed > 0.6 then
			local name = "walk"
			if CFG.AN_Run > 1.05 and speed > 12 then name = "run" end
			local mult = (name == "run") and r or w
			play(name, 0.15, (speed / 16) * mult)
		else
			play("idle", 0.25, 1)
		end
	end)
	return true, "nativo"
end

function Anim.stop()
	builtinStop()
	for inst, src in pairs(Anim.srcOf) do
		if inst and inst.Parent then trySet(inst, "Source", src) end
	end
	Anim.srcOf = setmetatable({}, { __mode = "k" })
	Anim.mode = "off"
	Anim.status = "desligado"
	Anim.patches = 0
end

function Anim.apply()
	Anim.stop()
	if not CFG.AN_On then return end
	local ok, msg
	if CFG.AN_Engine == "Nativo" then
		ok, msg = builtinStart()
		if ok then
			Anim.mode = "builtin"
			Anim.status = "nativo ativo"
		else
			Anim.status = "nativo falhou: " .. tostring(msg)
		end
		return
	end

	local char = LocalPlayer.Character
	local orig = char and char:FindFirstChild("Animate")
	ok, msg = tryPatch(orig)
	if ok then
		Anim.mode = "patch"
		Anim.status = "patch ativo (" .. tostring(msg) .. ")"
	elseif CFG.AN_Engine == "Nativo" then
		Anim.status = "falhou: " .. tostring(msg)
	else
		Anim.status = "sem patch (" .. tostring(msg) .. ")"
	end
end

--======================================= HUD DE PERFORMANCE
local Hud = { on = false }

function Hud.build()
	local ok = pcall(function()
		local pg = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
		if not pg then return end
		local old = pg:FindFirstChild("ALG_HUD")
		if old then old:Destroy() end

		local gui = Instance.new("ScreenGui")
		gui.Name = "ALG_HUD"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 90
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = pg

		local frame = Instance.new("Frame")
		frame.Name = "Box"
		frame.AnchorPoint = Vector2.new(0, 0)
		frame.Position = UDim2.new(0, 10, 0, 10)
		frame.Size = UDim2.new(0, 186, 0, 74)
		frame.BackgroundColor3 = Color3.fromRGB(12, 10, 20)
		frame.BackgroundTransparency = 0.25
		frame.BorderSizePixel = 0
		frame.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Transparency = 0.35
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Parent = frame

		local grad = Instance.new("UIGradient")
		grad.Rotation = 20
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 0.6),
		})
		grad.Parent = frame

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Position = UDim2.new(0, 8, 0, 4)
		title.Size = UDim2.new(1, -16, 0, 14)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 12
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.Text = "MEGA ANTI-LAG • ITEL A70"
		title.Parent = frame

		local info = Instance.new("TextLabel")
		info.Name = "Info"
		info.BackgroundTransparency = 1
		info.Position = UDim2.new(0, 8, 0, 18)
		info.Size = UDim2.new(1, -16, 0, 52)
		info.Font = Enum.Font.Code
		info.TextSize = 12
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.TextYAlignment = Enum.TextYAlignment.Top
		info.TextColor3 = Color3.fromRGB(210, 220, 255)
		info.Text = "carregando..."
		info.Parent = frame

		Hud.gui = gui
		Hud.frame = frame
		Hud.info = info
		Hud.on = true
	end)
	return ok
end

function Hud.update()
	if not Hud.on or not Hud.info then return end
	local P = palette()
	Hud.info.TextColor3 = mixColor(Color3.fromRGB(230, 230, 255), P.a, 0.55)
	Hud.info.Text = string.format(
		"FPS ....... %d\nMemoria ... %d MB\nPecas ..... %d\nEscondidas  %d\nEfeitos ... %d",
		math.floor(State.fpsSmooth + 0.5),
		math.floor(State.mem + 0.5),
		Cull.count,
		Cull.hidden,
		Effects.count
	)
end

function Hud.setVisible(v)
	if v and not Hud.on then Hud.build() end
	if Hud.gui then
		pcall(function() Hud.gui.Enabled = v end)
	end
end

function Hud.destroy()
	if Hud.gui then pcall(function() Hud.gui:Destroy() end) end
	Hud.gui = nil
	Hud.on = false
end

--======================================= LOOP PRINCIPAL
local Acc = { fpsN = 0, fpsT = 0, maint = 0, hud = 0, gc = 0, mem = 0, alert = 0, stats = 0 }

local function getMemMb()
	local ok, v = pcall(function() return StatsSrv:GetTotalMemoryUsageMb() end)
	if ok and type(v) == "number" then return v end
	return 0
end

local function doMaintenance()
	-- avalia celulas e limpa pecas mortas
	Cull.maintenance(8)
	Sounds.step(80)
end

local function heartbeat(dt)
	if not State.running then return end

	-- FPS
	Acc.fpsN = Acc.fpsN + 1
	Acc.fpsT = Acc.fpsT + dt
	if Acc.fpsT >= 0.5 then
		State.fps = Acc.fpsN / Acc.fpsT
		State.fpsSmooth = State.fpsSmooth * 0.55 + State.fps * 0.45
		Acc.fpsN = 0
		Acc.fpsT = 0
		Acc.hud = 1
	end

	-- varredura do mapa (incremental, sem travar)
	if State.scanning then Cull.scanStep() end

	-- pecas dinamicas (todo frame, barato)
	Cull.dynamicStep()

	-- anel de celulas (tem throttle interno)
	if Acc.maint <= 0 then
		Acc.maint = 0.25
		Cull.evaluate()
		doMaintenance()
	else
		Acc.maint = Acc.maint - dt
	end

	-- auto-emergencia
	Emergency.step(dt)

	-- memoria / lixo
	Acc.mem = Acc.mem + dt
	if Acc.mem >= 2 then
		Acc.mem = 0
		State.mem = getMemMb()
		if CFG.AL_MemGuard then
			Effects.compact()
			local limit = 1400
			if State.mem > limit and type(collectgarbage) == "function" then
				pcall(collectgarbage, "collect")
				notify("Memoria", string.format(
					"Uso alto (%d MB). Guarda de memoria limpou referencias.", math.floor(State.mem)),
					"hard-drive")
			end
		end
	end

	Acc.gc = Acc.gc + dt
	if Acc.gc >= 14 then
		Acc.gc = 0
		if Cull.deadCells > 48 then Cull.gcCells() end
		if #Effects.list > 40 then Effects.compact() end
	end

	-- HUD
	if Acc.hud >= 1 then
		Acc.hud = 0
		if CFG.EX_HUD then Hud.update() end
		pcall(updateStatusLabels)
	end
end

--======================================= APLICAR / RESTAURAR TUDO
local function applyEverything()
	captureBaseline()
	-- cenario distante
	if CFG.AL_Parts then
		if not Cull.scanned then Cull.start() end
	else
		Cull.revert()
	end
	-- efeitos
	if CFG.AL_Effects then
		if Cull.scanned then Cull.rescanVisuals() end
	else
		Effects.revert()
	end
	-- texturas
	if CFG.AL_Textures then
		if Cull.scanned then Cull.rescanVisuals() end
	else
		Textures.revert()
	end
	-- terreno, ceu, render
	TerrainMod.apply()
	SkyMod.apply()
	RenderMod.apply()
	-- sons
	if not CFG.EX_Sounds then Sounds.unmuteAll() end
	-- visual + animacao + camera
	Skin.apply()
	Anim.apply()
	Cam.bind()
	Hud.setVisible(CFG.EX_HUD and true or false)
	Cull.force = true
end

local function restoreEverything()
	Cull.revert()
	Effects.revert()
	Textures.revert()
	Sounds.revert()
	TerrainMod.revert()
	SkyMod.revert()
	RenderMod.revert()
	Skin.revert()
	Anim.stop()
	Cam.unbind()
	Emergency.level = 0
	Emergency.low = 0
	Emergency.high = 0
end

--======================================= API (console do executor)
local API = {}
function API.SetDistance(n)
	CFG.AL_Dist = clamp(tonumber(n) or CFG.AL_Dist, 60, 3000)
	Cull.force = true
	syncUI()
	return CFG.AL_Dist
end
function API.Kill()
	restoreEverything()
	notify("Restaurado", "O jogo voltou ao normal.", "rotate-ccw")
end
function API.Stats()
	return { fps = State.fpsSmooth, pecas = Cull.count, escondidas = Cull.hidden,
		efeitos = Effects.count, memoria = State.mem }
end
function API.Unload()
	restoreEverything()
	pcall(function() Rayfield:Destroy() end)
	if getgenv then getgenv().MegaAntiLagITEL = nil end
end
if getgenv then getgenv().MegaAntiLagITEL = API end

--======================================= INTERFACE (RAYFIELD)
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Mega Anti-Lag • ITEL A70",
	LoadingTitle = "Mega Anti-Lag v4.2",
	LoadingSubtitle = "ITEL A70 Edition + Skin Vida",
	Theme = "DarkBlue",
	ToggleUIKeybind = "K",
	Icon = "zap",
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "MegaAntiLagITEL",
		FileName = "config_itel_a70",
	},
})

--======================================= AVISOS NA TELA
notify = function(title, content, icon, dur)
	pcall(function()
		Rayfield:Notify({
			Title = tostring(title),
			Content = tostring(content),
			Duration = dur or 4.5,
			Image = icon or "zap",
		})
	end)
end

--======================================= PRESETS
local PresetBase = {
	AL_Parts = true, AL_Dist = 300, AL_Effects = true, AL_Textures = true,
	AL_Grass = true, AL_Sky = true, AL_Shadows = true, AL_RenderQ = true,
	AL_Extreme = false, AL_Rate = 240, AL_Auto = true, AL_MemGuard = true,
	SK_On = true, SK_Palette = "Sunset Fogo", SK_Int = 68, SK_Sat = 52,
	SK_Con = 34, SK_Bri = 40, SK_Tint = 58, SK_Fog = true, SK_Atmos = true,
	SK_Grade = true, SK_Bloom = true, SK_Sun = true, SK_DOF = false,
	SK_Clouds = false, SK_Hour = true, SK_Aura = true, SK_Trail = false,
	SK_Camera = true, SK_FOV = 86, SK_LockFOV = true, SK_CineFOV = true,
	SK_Vida = true,
	AN_On = true, AN_Walk = 1.45, AN_Run = 1.95, AN_Other = 1.25,
	AN_Engine = "Automatico",
	EX_Sounds = false, EX_Cap = true, EX_MinFPS = 60, EX_HUD = true,
}

local Presets = {}

local function mkPreset(over)
	local t = {}
	for k, v in pairs(PresetBase) do t[k] = v end
	for k, v in pairs(over) do t[k] = v end
	return t
end

Presets["Itel A70 - Turbo"] = mkPreset({
	AL_Dist = 260, AL_Rate = 320, AL_Extreme = false,
	SK_Int = 72, SK_Sat = 58, SK_Con = 38, SK_Bri = 44, SK_Tint = 62,
	SK_Bloom = true, SK_DOF = false, SK_Clouds = false,
	SK_FOV = 88, SK_Camera = true, SK_Vida = true,
	AN_Walk = 1.55, AN_Run = 2.15, AN_Other = 1.3,
	EX_HUD = true,
})

Presets["Itel A70 - Equilibrado"] = mkPreset({
	AL_Dist = 420, AL_Rate = 240, AL_Extreme = false,
	SK_Int = 60, SK_Sat = 48, SK_Con = 30, SK_Bri = 40, SK_Tint = 52,
	SK_DOF = false, SK_Clouds = false, SK_FOV = 84,
	AN_Walk = 1.3, AN_Run = 1.6, AN_Other = 1.15,
})

Presets["PC / Console - Bonito"] = mkPreset({
	AL_Dist = 900, AL_Rate = 200, AL_Shadows = false, AL_Sky = false,
	AL_Textures = false, AL_Grass = false, AL_Effects = false,
	SK_Int = 80, SK_Sat = 62, SK_Con = 40, SK_Bri = 46, SK_Tint = 66,
	SK_DOF = true, SK_Clouds = true, SK_Trail = true, SK_FOV = 82,
	AN_Walk = 1.2, AN_Run = 1.4, AN_Other = 1.05,
})

Presets["Personalizado"] = nil

--======================================= HANDLES DA UI
local UI = { Toggles = {}, Sliders = {}, Drops = {}, Labels = {} }
local Silence = false

local function onToggle(key, cb)
	return function(v)
		if Silence then return end
		CFG[key] = v
		if cb then cb(v) end
	end
end

local function onSlider(key, cb)
	return function(v)
		if Silence then return end
		CFG[key] = v
		if cb then cb(v) end
	end
end

local function onDrop(key, cb)
	return function(opts)
		if Silence then return end
		local v = opts
		if type(opts) == "table" then v = opts[1] end
		if v == nil then return end
		CFG[key] = v
		if cb then cb(v) end
	end
end

--======================================= TAB: PAINEL
local TabMain = Window:CreateTab("Painel", "layout-dashboard")

TabMain:CreateLabel("MEGA ANTI-LAG v4.2 • ITEL A70", "zap", Color3.fromRGB(255, 186, 96), true)
TabMain:CreateParagraph({
	Title = "Anti-lag brutal + jogo bonito",
	Content = "Esconde o cenario distante, mata efeitos, texturas, sombras e ceu pesado — " ..
		"e ainda coloca um filtro super vivo pra o jogo nao ficar sem graca.",
})
UI.Labels.Fps = TabMain:CreateLabel("FPS: medindo...", "activity", Color3.fromRGB(120, 255, 190), true)
UI.Labels.Skin = TabMain:CreateLabel("Skin: --", "palette", Color3.fromRGB(255, 160, 220), true)
UI.Labels.Anim = TabMain:CreateLabel("Animacao: --", "person-standing", Color3.fromRGB(160, 200, 255), true)
UI.Labels.Scan = TabMain:CreateLabel("Varredura: --", "search", Color3.fromRGB(230, 230, 160), true)
TabMain:CreateDivider()
TabMain:CreateParagraph({
	Title = "Como usar",
	Content = "1) Escolha um preset em Anti-Lag.  2) Ajuste a paleta em Skin Viva.  " ..
		"3) Tecla K abre/fecha o menu.  4) Sua config fica salva sozinha.",
})
TabMain:CreateButton({
	Name = "Aplicar preset Turbo agora",
	Callback = function()
		local d = UI.Drops.Preset
		if d then pcall(function() d:Set({ "Itel A70 - Turbo" }) end) end
	end,
})
TabMain:CreateButton({
	Name = "Restaurar o jogo (desligar tudo)",
	Callback = function()
		restoreEverything()
		notify("Restaurado", "Anti-lag e skin desligados. O jogo esta como era.", "rotate-ccw")
	end,
})

--======================================= TAB: ANTI-LAG
local TabAL = Window:CreateTab("Anti-Lag", "gauge")

UI.Drops.Preset = TabAL:CreateDropdown({
	Name = "Preset de desempenho",
	Options = { "Itel A70 - Turbo", "Itel A70 - Equilibrado", "PC / Console - Bonito", "Personalizado" },
	CurrentOption = { QUICK_PRESET },
	Flag = "AL_Preset",
	Callback = function(opts)
		if Silence then return end
		local name = opts
		if type(opts) == "table" then name = opts[1] end
		if not name or name == "Personalizado" then return end
		applyPreset(name)
	end,
})

TabAL:CreateDivider()
TabAL:CreateParagraph({ Title = "Anti-lag", Content = "O coracao do script. Quanto mais ligado, mais FPS." })

UI.Toggles.AL_Parts = TabAL:CreateToggle({
	Name = "Esconder cenario distante",
	CurrentValue = CFG.AL_Parts,
	Flag = "AL_Parts",
	Callback = onToggle("AL_Parts", function(v)
		if v then Cull.start() else Cull.revert() end
	end),
})
UI.Sliders.AL_Dist = TabAL:CreateSlider({
	Name = "Distancia de visao",
	Range = { 80, 1200 },
	Increment = 10,
	Suffix = " studs",
	CurrentValue = CFG.AL_Dist,
	Flag = "AL_Dist",
	Callback = onSlider("AL_Dist", function(v)
		Cull.force = true
		if CFG.SK_On and CFG.SK_Fog then Skin.apply() end
	end),
})
UI.Toggles.AL_Effects = TabAL:CreateToggle({
	Name = "Matar efeitos (particulas/luzes/beams)",
	CurrentValue = CFG.AL_Effects,
	Flag = "AL_Effects",
	Callback = onToggle("AL_Effects", function(v)
		if v then Cull.rescanVisuals() else Effects.revert() end
	end),
})
UI.Toggles.AL_Textures = TabAL:CreateToggle({
	Name = "Remover texturas e decais",
	CurrentValue = CFG.AL_Textures,
	Flag = "AL_Textures",
	Callback = onToggle("AL_Textures", function(v)
		if v then Cull.rescanVisuals() else Textures.revert() end
	end),
})
UI.Toggles.AL_Grass = TabAL:CreateToggle({
	Name = "Desligar grama e ondas da agua",
	CurrentValue = CFG.AL_Grass,
	Flag = "AL_Grass",
	Callback = onToggle("AL_Grass", function() TerrainMod.apply() end),
})
UI.Toggles.AL_Sky = TabAL:CreateToggle({
	Name = "Remover ceu / nuvens / atmosfera do jogo",
	CurrentValue = CFG.AL_Sky,
	Flag = "AL_Sky",
	Callback = onToggle("AL_Sky", function()
		SkyMod.apply()
		if CFG.SK_On then Skin.apply() end
	end),
})
UI.Toggles.AL_Shadows = TabAL:CreateToggle({
	Name = "Desligar sombras",
	CurrentValue = CFG.AL_Shadows,
	Flag = "AL_Shadows",
	Callback = onToggle("AL_Shadows", function(v)
		if v then
			trySet(Lighting, "GlobalShadows", false)
			trySet(Lighting, "ShadowSoftness", 0)
		else
			trySet(Lighting, "GlobalShadows", true)
		end
	end),
})
UI.Toggles.AL_RenderQ = TabAL:CreateToggle({
	Name = "Baixar qualidade de render + LOD",
	CurrentValue = CFG.AL_RenderQ,
	Flag = "AL_RenderQ",
	Callback = onToggle("AL_RenderQ", function(v)
		if v then RenderMod.apply() else restoreLighting() end
	end),
})
UI.Toggles.AL_Extreme = TabAL:CreateToggle({
	Name = "Modo extremo (jogadores distantes somem)",
	CurrentValue = CFG.AL_Extreme,
	Flag = "AL_Extreme",
	Callback = onToggle("AL_Extreme", function()
		Cull.force = true
	end),
})

TabAL:CreateDivider()
TabAL:CreateParagraph({ Title = "Anti-travamento", Content = "Protecoes para o celular nao engasgar." })

UI.Toggles.AL_Auto = TabAL:CreateToggle({
	Name = "Auto-emergencia (aperta tudo se o FPS cair)",
	CurrentValue = CFG.AL_Auto,
	Flag = "AL_Auto",
	Callback = onToggle("AL_Auto", nil),
})
UI.Toggles.AL_MemGuard = TabAL:CreateToggle({
	Name = "Guarda de memoria (limpa lixo)",
	CurrentValue = CFG.AL_MemGuard,
	Flag = "AL_MemGuard",
	Callback = onToggle("AL_MemGuard", nil),
})
UI.Sliders.AL_Rate = TabAL:CreateSlider({
	Name = "Velocidade da limpeza",
	Range = { 60, 700 },
	Increment = 20,
	Suffix = " /frame",
	CurrentValue = CFG.AL_Rate,
	Flag = "AL_Rate",
	Callback = onSlider("AL_Rate", nil),
})

TabAL:CreateDivider()
TabAL:CreateButton({
	Name = "Limpar memoria agora (GC)",
	Callback = function()
		Effects.compact()
		if type(collectgarbage) == "function" then pcall(collectgarbage, "collect") end
		notify("Memoria", "Referencias limpas e garbage collector chamado.", "trash-2")
	end,
})
TabAL:CreateButton({
	Name = "Re-escanear o mapa agora",
	Callback = function()
		Cull.start()
		notify("Varredura", "Procurando tudo de novo no mapa...", "search")
	end,
})
TabAL:CreateButton({
	Name = "Restaurar tudo (voltar ao normal)",
	Callback = function()
		restoreEverything()
		notify("Restaurado", "Tudo devolvido ao estado original do jogo.", "rotate-ccw")
	end,
})

--======================================= TAB: SKIN VIVA
local TabSK = Window:CreateTab("Skin Viva", "sparkles")

UI.Toggles.SK_On = TabSK:CreateToggle({
	Name = "Ligar filtro vivo (o jogo fica bonito)",
	CurrentValue = CFG.SK_On,
	Flag = "SK_On",
	Callback = onToggle("SK_On", function() Skin.apply() end),
})
UI.Drops.SK_Palette = TabSK:CreateDropdown({
	Name = "Paleta do filtro",
	Options = PaletteOrder,
	CurrentOption = { CFG.SK_Palette },
	Flag = "SK_Palette",
	Callback = onDrop("SK_Palette", function(v)
		Skin.apply()
		notify("Paleta: " .. v, (Palettes[v] and Palettes[v].nice) or "aplicada", "palette")
	end),
})
UI.Sliders.SK_Int = TabSK:CreateSlider({
	Name = "Intensidade geral",
	Range = { 0, 100 }, Increment = 1, Suffix = "%",
	CurrentValue = CFG.SK_Int, Flag = "SK_Int",
	Callback = onSlider("SK_Int", function() Skin.apply() end),
})
UI.Sliders.SK_Sat = TabSK:CreateSlider({
	Name = "Saturacao (cor viva)",
	Range = { 0, 100 }, Increment = 1, Suffix = "%",
	CurrentValue = CFG.SK_Sat, Flag = "SK_Sat",
	Callback = onSlider("SK_Sat", function() Skin.apply() end),
})
UI.Sliders.SK_Con = TabSK:CreateSlider({
	Name = "Contraste",
	Range = { 0, 100 }, Increment = 1, Suffix = "%",
	CurrentValue = CFG.SK_Con, Flag = "SK_Con",
	Callback = onSlider("SK_Con", function() Skin.apply() end),
})
UI.Sliders.SK_Bri = TabSK:CreateSlider({
	Name = "Brilho",
	Range = { 0, 100 }, Increment = 1, Suffix = "%",
	CurrentValue = CFG.SK_Bri, Flag = "SK_Bri",
	Callback = onSlider("SK_Bri", function() Skin.apply() end),
})
UI.Sliders.SK_Tint = TabSK:CreateSlider({
	Name = "Tingimento (cor dominante)",
	Range = { 0, 100 }, Increment = 1, Suffix = "%",
	CurrentValue = CFG.SK_Tint, Flag = "SK_Tint",
	Callback = onSlider("SK_Tint", function() Skin.apply() end),
})

TabSK:CreateDivider()
TabSK:CreateParagraph({ Title = "Luz, clima e camera", Content = "O que deixa a cena com cara de cinema." })

UI.Toggles.SK_Fog = TabSK:CreateToggle({
	Name = "Nevoa colorida (horizonte vivo)",
	CurrentValue = CFG.SK_Fog, Flag = "SK_Fog",
	Callback = onToggle("SK_Fog", function() Skin.apply() end),
})
UI.Toggles.SK_Atmos = TabSK:CreateToggle({
	Name = "Atmosfera viva (nevoa volumetrica)",
	CurrentValue = CFG.SK_Atmos, Flag = "SK_Atmos",
	Callback = onToggle("SK_Atmos", function()
		SkyMod.apply()
		Skin.apply()
	end),
})
UI.Toggles.SK_Grade = TabSK:CreateToggle({
	Name = "Color grading",
	CurrentValue = CFG.SK_Grade, Flag = "SK_Grade",
	Callback = onToggle("SK_Grade", function() Skin.apply() end),
})
UI.Toggles.SK_Bloom = TabSK:CreateToggle({
	Name = "Bloom neon (brilho nas luzes)",
	CurrentValue = CFG.SK_Bloom, Flag = "SK_Bloom",
	Callback = onToggle("SK_Bloom", function() Skin.apply() end),
})
UI.Toggles.SK_Sun = TabSK:CreateToggle({
	Name = "Raios de sol",
	CurrentValue = CFG.SK_Sun, Flag = "SK_Sun",
	Callback = onToggle("SK_Sun", function() Skin.apply() end),
})
UI.Toggles.SK_DOF = TabSK:CreateToggle({
	Name = "Profundidade de campo (cinema) - pesa mais",
	CurrentValue = CFG.SK_DOF, Flag = "SK_DOF",
	Callback = onToggle("SK_DOF", function() Skin.apply() end),
})
UI.Toggles.SK_Clouds = TabSK:CreateToggle({
	Name = "Nuvens cinematograficas - pesa um pouco",
	CurrentValue = CFG.SK_Clouds, Flag = "SK_Clouds",
	Callback = onToggle("SK_Clouds", function() Skin.apply() end),
})
UI.Toggles.SK_Hour = TabSK:CreateToggle({
	Name = "Hora dourada (17h30)",
	CurrentValue = CFG.SK_Hour, Flag = "SK_Hour",
	Callback = onToggle("SK_Hour", function()
		Skin.apply()
		if not CFG.SK_Hour then restoreLighting() end
	end),
})

TabSK:CreateDivider()
UI.Toggles.SK_Aura = TabSK:CreateToggle({
	Name = "Aura de luz no personagem",
	CurrentValue = CFG.SK_Aura, Flag = "SK_Aura",
	Callback = onToggle("SK_Aura", function() Skin.attach() end),
})
UI.Toggles.SK_Trail = TabSK:CreateToggle({
	Name = "Rastro neon (trail)",
	CurrentValue = CFG.SK_Trail, Flag = "SK_Trail",
	Callback = onToggle("SK_Trail", function() Skin.attach() end),
})

TabSK:CreateDivider()
UI.Toggles.SK_Camera = TabSK:CreateToggle({
	Name = "Camera viva (micro balanco organico)",
	CurrentValue = CFG.SK_Camera, Flag = "SK_Camera",
	Callback = onToggle("SK_Camera", nil),
})
UI.Toggles.SK_LockFOV = TabSK:CreateToggle({
	Name = "Travar FOV (campo de visao)",
	CurrentValue = CFG.SK_LockFOV, Flag = "SK_LockFOV",
	Callback = onToggle("SK_LockFOV", nil),
})
UI.Sliders.SK_FOV = TabSK:CreateSlider({
	Name = "FOV",
	Range = { 60, 110 }, Increment = 1,
	CurrentValue = CFG.SK_FOV, Flag = "SK_FOV",
	Callback = onSlider("SK_FOV", nil),
})
UI.Toggles.SK_CineFOV = TabSK:CreateToggle({
	Name = "FOV cinematografico (abre quando corre)",
	CurrentValue = CFG.SK_CineFOV, Flag = "SK_CineFOV",
	Callback = onToggle("SK_CineFOV", nil),
})
UI.Toggles.SK_Vida = TabSK:CreateToggle({
	Name = "Respiracao do filtro (pulsa devagar)",
	CurrentValue = CFG.SK_Vida, Flag = "SK_Vida",
	Callback = onToggle("SK_Vida", nil),
})

TabSK:CreateDivider()
TabSK:CreateButton({
	Name = "Skin: NEON INSANO",
	Callback = function()
		local d = UI.Drops.SK_Palette
		if d then pcall(function() d:Set({ "Neon Roxo" }) end) end
		CFG.SK_Int = 88; CFG.SK_Sat = 72; CFG.SK_Con = 46; CFG.SK_Tint = 74
		CFG.SK_Bloom = true; CFG.SK_Vida = true; CFG.SK_Camera = true
		CFG.SK_Clouds = false; CFG.SK_DOF = false
		syncUI()
		Skin.apply()
		notify("Skin: NEON INSANO", "Cor no maximo, bloom alto e pulso vivo.", "sparkles")
	end,
})
TabSK:CreateButton({
	Name = "Skin: SUNSET REALISTA",
	Callback = function()
		local d = UI.Drops.SK_Palette
		if d then pcall(function() d:Set({ "Realista Quente" }) end) end
		CFG.SK_Int = 62; CFG.SK_Sat = 40; CFG.SK_Con = 34; CFG.SK_Tint = 60
		CFG.SK_Bloom = true; CFG.SK_Sun = true; CFG.SK_Vida = true
		CFG.SK_Clouds = true; CFG.SK_DOF = true; CFG.SK_Hour = true
		syncUI()
		Skin.apply()
		notify("Skin: SUNSET REALISTA", "Filtro de filme, nuvens e profundidade de campo.", "sunset")
	end,
})
TabSK:CreateButton({
	Name = "Skin: CYBER",
	Callback = function()
		local d = UI.Drops.SK_Palette
		if d then pcall(function() d:Set({ "Cyber Azul" }) end) end
		CFG.SK_Int = 78; CFG.SK_Sat = 60; CFG.SK_Con = 42; CFG.SK_Tint = 66
		CFG.SK_Bloom = true; CFG.SK_Trail = true; CFG.SK_Vida = true
		syncUI()
		Skin.apply()
		notify("Skin: CYBER", "Azul neon com rastro ligado.", "cpu")
	end,
})
TabSK:CreateButton({
	Name = "Desligar skin (jogo original)",
	Callback = function()
		CFG.SK_On = false
		Skin.revert()
		syncUI()
		notify("Skin desligada", "Cores originais do jogo restauradas.", "palette")
	end,
})

--======================================= TAB: ANIMACAO
local TabAN = Window:CreateTab("Animacao", "person-standing")

UI.Toggles.AN_On = TabAN:CreateToggle({
	Name = "Animacao viva (mais rapida, so visual)",
	CurrentValue = CFG.AN_On, Flag = "AN_On",
	Callback = onToggle("AN_On", function() Anim.apply() end),
})
UI.Drops.AN_Engine = TabAN:CreateDropdown({
	Name = "Motor de animacao",
	Options = { "Automatico", "Nativo" },
	CurrentOption = { CFG.AN_Engine },
	Flag = "AN_Engine",
	Callback = onDrop("AN_Engine", function()
		Anim.apply()
		notify("Motor: " .. tostring(CFG.AN_Engine),
			"Automatico = patch no Animate do jogo. Nativo = animador proprio.", "person-standing")
	end),
})
UI.Sliders.AN_Walk = TabAN:CreateSlider({
	Name = "Velocidade da caminhada (visual)",
	Range = { 0.7, 3 }, Increment = 0.05, Suffix = "x",
	CurrentValue = CFG.AN_Walk, Flag = "AN_Walk",
	Callback = onSlider("AN_Walk", function() Anim.apply() end),
})
UI.Sliders.AN_Run = TabAN:CreateSlider({
	Name = "Velocidade da corrida (visual)",
	Range = { 1, 3.5 }, Increment = 0.05, Suffix = "x",
	CurrentValue = CFG.AN_Run, Flag = "AN_Run",
	Callback = onSlider("AN_Run", function() Anim.apply() end),
})
UI.Sliders.AN_Other = TabAN:CreateSlider({
	Name = "Outras animacoes (parado/pulo/queda)",
	Range = { 0.6, 2.5 }, Increment = 0.05, Suffix = "x",
	CurrentValue = CFG.AN_Other, Flag = "AN_Other",
	Callback = onSlider("AN_Other", function() Anim.apply() end),
})
TabAN:CreateDivider()
TabAN:CreateParagraph({
	Title = "Importante",
	Content = "Isso NAO muda a velocidade real do personagem (o servidor continua " ..
		"mandando). E so o visual: as pernas se mexem mais rapido. Em " ..
		"primeira pessoa ou em jogos com anti-cheat agressivo, deixe desligado.",
})
UI.Labels.AnimTab = TabAN:CreateLabel("Motor: --", "activity", Color3.fromRGB(160, 200, 255), true)
TabAN:CreateButton({
	Name = "Reaplicar animacoes",
	Callback = function()
		Anim.apply()
		notify("Animacao", Anim.status, "refresh-cw")
	end,
})

--======================================= TAB: EXTRAS
local TabEX = Window:CreateTab("Extras", "settings")

UI.Toggles.EX_HUD = TabEX:CreateToggle({
	Name = "HUD de performance (FPS/memoria)",
	CurrentValue = CFG.EX_HUD, Flag = "EX_HUD",
	Callback = onToggle("EX_HUD", function(v) Hud.setVisible(v) end),
})
UI.Toggles.EX_Sounds = TabEX:CreateToggle({
	Name = "Silenciar sons distantes",
	CurrentValue = CFG.EX_Sounds, Flag = "EX_Sounds",
	Callback = onToggle("EX_Sounds", function()
		if not CFG.EX_Sounds then Sounds.unmuteAll() end
	end),
})
UI.Toggles.EX_Cap = TabEX:CreateToggle({
	Name = "Limitar FPS com a janela minimizada",
	CurrentValue = CFG.EX_Cap, Flag = "EX_Cap",
	Callback = onToggle("EX_Cap", nil),
})
UI.Sliders.EX_MinFPS = TabEX:CreateSlider({
	Name = "FPS minimo (janela minimizada)",
	Range = { 15, 60 }, Increment = 5, Suffix = " fps",
	CurrentValue = CFG.EX_MinFPS, Flag = "EX_MinFPS",
	Callback = onSlider("EX_MinFPS", nil),
})
TabEX:CreateDivider()
TabEX:CreateParagraph({
	Title = "Aviso",
	Content = "Script de cliente (local). Nao altera o servidor e nao da vantagem " ..
		"de dano. Em jogos com anti-cheat forte, use com cuidado. Feito para " ..
		"ITEL A70 / celulares fracos: quanto mais fraco o aparelho, mais o " ..
		"preset Turbo ajuda.",
})
TabEX:CreateButton({
	Name = "Descarregar tudo (unload)",
	Callback = function()
		restoreEverything()
		Hud.destroy()
		pcall(function() Rayfield:Destroy() end)
		if getgenv then getgenv().MegaAntiLagITEL = nil end
		if type(collectgarbage) == "function" then pcall(collectgarbage, "collect") end
	end,
})

--======================================= SYNC DA UI
syncUI = function()
	Silence = true
	for k, el in pairs(UI.Toggles) do
		pcall(function() el:Set(CFG[k] and true or false) end)
	end
	for k, el in pairs(UI.Sliders) do
		pcall(function() el:Set(CFG[k]) end)
	end
	pcall(function() UI.Drops.SK_Palette:Set({ CFG.SK_Palette }) end)
	pcall(function() UI.Drops.AN_Engine:Set({ CFG.AN_Engine }) end)
	Silence = false
	updateStatusLabels()
end

local function updateStatusLabelsImpl()
	local P = palette()
	if UI.Labels.Fps then
		pcall(function()
			UI.Labels.Fps:Set(string.format(
				"FPS: %d  |  Escondidas: %d  |  Memoria: %d MB",
				math.floor(State.fpsSmooth + 0.5), Cull.hidden, math.floor(State.mem + 0.5)))
		end)
	end
	if UI.Labels.Skin then
		pcall(function()
			UI.Labels.Skin:Set("Skin: " .. (CFG.SK_On and (CFG.SK_Palette .. " (" .. tostring(P.nice) .. ")") or "desligada"))
		end)
	end
	if UI.Labels.Anim then
		pcall(function()
			UI.Labels.Anim:Set("Animacao: " .. tostring(Anim.status))
		end)
	end
	if UI.Labels.AnimTab then
		pcall(function()
			UI.Labels.AnimTab:Set("Motor atual: " .. tostring(Anim.status))
		end)
	end
	if UI.Labels.Scan then
		pcall(function()
			UI.Labels.Scan:Set(string.format(
				"Varredura: %s  |  Pecas monitoradas: %d%s",
				State.scanning and "procurando..." or "completa",
				Cull.count, State.capped and " (limite)" or ""))
		end)
	end
end

updateStatusLabels = function()
	updateStatusLabelsImpl()
end

applyPreset = function(name)
	local p = Presets[name]
	if not p then return end
	Silence = true
	for k, v in pairs(p) do CFG[k] = v end
	pcall(function() UI.Drops.Preset:Set({ name }) end)
	Silence = false
	syncUI()
	applyEverything()
	notify("Preset: " .. name,
		"Distancia " .. tostring(CFG.AL_Dist) .. " studs • paleta " .. CFG.SK_Palette,
		"sliders-horizontal", 6)
end

--======================================= BOOT
do
	captureBaseline()
	Skin.baseFOV = getProp(Ws.CurrentCamera, "FieldOfView") or 70
	if not Presets[QUICK_PRESET] then QUICK_PRESET = "Itel A70 - Turbo" end

	-- pecas novas e removidas no mapa
	Ws.DescendantAdded:Connect(function(inst)
		if State.scanning then return end
		State.instances = State.instances + 1
		if not State.running then return end
		pcall(Cull.inspect, inst)
	end)
	Ws.DescendantRemoving:Connect(function()
		if State.scanning then return end
		State.instances = math.max(0, State.instances - 1)
	end)

	-- respawn: recoloca aura/rastro e reaplica animacao
	LocalPlayer.CharacterAdded:Connect(function(char)
		pcall(function() char:WaitForChild("HumanoidRootPart", 10) end)
		if CFG.SK_On then pcall(Skin.attach) end
		if CFG.AN_On then pcall(Anim.apply) end
		Cull.force = true
	end)

	-- FPS cap quando minimizado (se o executor suportar)
	if setfpscap then
		UIS.WindowFocused:Connect(function()
			if CFG.EX_Cap then pcall(setfpscap, 0) end
		end)
		UIS.WindowFocusReleased:Connect(function()
			if CFG.EX_Cap then pcall(setfpscap, CFG.EX_MinFPS) end
		end)
	end

	RunService.Heartbeat:Connect(heartbeat)

	-- UI + estado inicial
	applyPreset(QUICK_PRESET)
	pcall(function() Rayfield:LoadConfiguration() end)
	syncUI()
	if CFG.EX_HUD then Hud.setVisible(true) end
	Cam.bind()

	notify("Mega Anti-Lag v4.2",
		"ITEL A70 rodando • filtro \"" .. CFG.SK_Palette .. "\". Tecla K abre o menu.", "zap", 7)

	local function lateTip()
		if type(task) == "table" and task.spawn then
			task.spawn(function()
				task.wait(6)
				notify("Dica", "Se ainda travar: baixe a distancia para 200 e ligue " ..
					"o modo extremo em Anti-Lag.", "lightbulb", 6)
			end)
		end
	end
	pcall(lateTip)
end

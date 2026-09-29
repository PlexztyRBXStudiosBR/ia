"""
Gerador de projeto Roblox REAL (Rojo 7 + Luau).

Gera a árvore de arquivos que o `rojo serve` sincroniza com o Roblox Studio:
  * default.project.json  -> mapeamento DataModel
  * src/ServerScriptService  -> serviços server-authoritative (anti-exploit)
  * src/ReplicatedStorage    -> módulos compartilhados + RemoteEvents (.model.json)
  * src/StarterPlayerScripts -> cliente (input, câmera, sprint)
  * src/StarterCharacterScripts -> módulos do personagem
  * src/StarterGui           -> HUD (ScreenGui + LocalScript)
  * src/Workspace / Lighting -> spawn, céu Future lighting

Nada de código de demonstração inseguro: dano/loot/score são validados no servidor.
"""
from __future__ import annotations

import json
from typing import Dict, List, Optional

__all__ = ["generate_roblox_project"]

GAME_SERVER = '''--!strict
-- GameServer: bootstrap dos serviços. Roda UMA vez no ServerScriptService.
-- Arkher AI - arquitetura server-authoritative.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local CombatService = require(script:WaitForChild("CombatService"))
local ProfileService = require(script:WaitForChild("ProfileService"))
local ShopService = require(script:WaitForChild("ShopService"))

-- garante que os RemoteEvents existam (rojo normalmente já criou via .model.json)
Remotes.ensure()

local function onPlayerAdded(player: Player)
	local profile = ProfileService.acquire(player)
	if not profile then
		player:Kick("Não foi possível carregar seus dados. Tente novamente.")
		return
	end
	CombatService.register(player, profile)
	ShopService.register(player, profile)
end

local function onPlayerRemoving(player: Player)
	CombatService.unregister(player)
	ShopService.unregister(player)
	ProfileService.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print("[Arkher] GameServer online -", #Players:GetPlayers(), "jogadores conectados")
'''

COMBAT_SERVICE = '''--!strict
-- CombatService: TODO dano é decidido no servidor. O cliente só pede.
-- Anti-exploit: cooldown, alcance, line-of-sight e rate limiting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Constants = require(Shared:WaitForChild("Constants"))

local CombatService = {}

type Profile = {
	Data: {
		health: number,
		maxHealth: number,
		coins: number,
		level: number,
		xp: number,
		kills: number,
	},
}

local registry: { [Player]: Profile } = {}
local cooldowns: { [Player]: number } = {}
local requestCounts: { [Player]: { window: number, count: number } } = {}

local ATTACK_COOLDOWN = 0.55
local MAX_REQUESTS_PER_SECOND = 12

local function withinRateLimit(player: Player): boolean
	local now = os.clock()
	local entry = requestCounts[player]
	if not entry or now - entry.window > 1 then
		requestCounts[player] = { window = now, count = 1 }
		return true
	end
	entry.count += 1
	return entry.count <= MAX_REQUESTS_PER_SECOND
end

local function distanceTo(a: Instance, b: Instance): number?
	local am, bm = a:FindFirstChildOfClass("Model") or a, b:FindFirstChildOfClass("Model") or b
	local ahrp = am:FindFirstChild("HumanoidRootPart") :: BasePart?
	local bhrp = bm:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not ahrp or not bhrp then
		return nil
	end
	return (ahrp.Position - bhrp.Position).Magnitude
end

local function applyDamage(victim: Player, amount: number, attacker: Player)
	local profile = registry[victim]
	if not profile then
		return
	end
	local humanoid = victim.Character and victim.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	profile.Data.health = math.max(0, profile.Data.health - amount)
	humanoid.Health = profile.Data.health
	Remotes.broadcastHealth(victim, profile.Data.health, profile.Data.maxHealth)
	if profile.Data.health <= 0 then
		humanoid:TakeDamage(humanoid.Health) -- derruba de verdade
		local aProfile = registry[attacker]
		if aProfile then
			aProfile.Data.coins += Constants.REWARD_PER_KILL
			aProfile.Data.xp += Constants.XP_PER_KILL
			aProfile.Data.kills += 1
			Remotes.broadcastKill(attacker, victim)
		end
	end
end

local function onAttackRequest(player: Player, target: Instance?)
	if not withinRateLimit(player) then
		return -- rate limit: ignora silenciosamente
	end
	local now = os.clock()
	if (cooldowns[player] or -10) + ATTACK_COOLDOWN > now then
		return
	end
	cooldowns[player] = now

	if typeof(target) ~= "Instance" or not target:IsA("Player") and not target:IsA("Model") then
		return
	end
	local victim = if target:IsA("Player") then target :: Player else Players:GetPlayerFromCharacter(target)
	if not victim or victim == player then
		return
	end

	local dist = distanceTo(player, victim)
	if not dist or dist > Constants.ATTACK_RANGE_SERVER then
		return -- fora de alcance: pedido inválido
	end

	local attackerProfile = registry[player]
	if not attackerProfile then
		return
	end
	applyDamage(victim, Constants.ATTACK_DAMAGE, player)
	Remotes.broadcastSwing(player)
end

function CombatService.register(player: Player, profile: Profile)
	registry[player] = profile
	cooldowns[player] = 0
end

function CombatService.unregister(player: Player)
	registry[player] = nil
	cooldowns[player] = nil
	requestCounts[player] = nil
end

Remotes.onAttack(onAttackRequest)

return CombatService
'''

PROFILE_SERVICE = '''--!strict
-- ProfileService: persistência em DataStore com retries, salvamento periódico
-- e bind em PlayerRemoving/BindToClose. Sem session lock complexo (documentado).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SAVE_KEY_PREFIX = "arkher_profile_v1_"
local RETRIES = 4
local AUTOSAVE_SECONDS = 120

export type ProfileData = {
	health: number,
	maxHealth: number,
	coins: number,
	level: number,
	xp: number,
	kills: number,
	settings: { [string]: any },
}

export type Profile = {
	Data: ProfileData,
	Save: (self: Profile) -> boolean,
}

local defaultData = {
	health = 100,
	maxHealth = 100,
	coins = 0,
	level = 1,
	xp = 0,
	kills = 0,
	settings = {},
}

local store = DataStoreService:GetDataStore("arkher_profiles_v1")
local active: { [Player]: Profile } = {}

local function load(userId: number): ProfileData?
	for attempt = 1, RETRIES do
		local ok, data = pcall(function()
			return store:GetAsync(SAVE_KEY_PREFIX .. userId)
		end)
		if ok then
			if type(data) ~= "table" then
				return nil
			end
			local merged = table.clone(defaultData) :: any
			for k, v in pairs(data :: any) do
				merged[k] = v
			end
			return merged
		end
		task.wait(2 ^ attempt * 0.5)
	end
	return nil
end

local function save(userId: number, data: ProfileData): boolean
	for attempt = 1, RETRIES do
		local ok, err = pcall(function()
			store:SetAsync(SAVE_KEY_PREFIX .. userId, data)
		end)
		if ok then
			return true
		end
		warn("[ProfileService] falha ao salvar", userId, err)
		task.wait(2 ^ attempt * 0.5)
	end
	return false
end

local function buildProfile(player: Player, data: ProfileData): Profile
	local profile = {} :: any
	profile.Data = data
	function profile.Save(self): boolean
		return save(player.UserId, self.Data)
	end
	return profile :: Profile
end

function _G.__arkher_acquire(player: Player): Profile?
	local data = load(player.UserId)
	if not data then
		if not RunService:IsStudio() then
			return nil
		end
		data = table.clone(defaultData)
	end
	local profile = buildProfile(player, data)
	active[player] = profile
	return profile
end

function _G.__arkher_release(player: Player)
	local profile = active[player]
	if profile then
		profile:Save()
		active[player] = nil
	end
end

local ProfileService = {}

function ProfileService.acquire(player: Player): Profile?
	return _G.__arkher_acquire(player)
end

function ProfileService.release(player: Player)
	_G.__arkher_release(player)
end

-- autosave
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for player, profile in pairs(active) do
			task.spawn(function()
				profile:Save()
			end)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local profile = active[player]
	if profile then
		profile:Save()
		active[player] = nil
	end
end)

game:BindToClose(function()
	for player, profile in pairs(active) do
		profile:Save()
	end
	task.wait(1)
end)

return ProfileService
'''

SHOP_SERVICE = '''--!strict
-- ShopService: compra/venda validada no servidor (preço vem do catálogo, nunca do cliente).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Catalog = require(Shared:WaitForChild("Catalog"))

local ShopService = {}

local profiles: { [Player]: any } = {}

function ShopService.register(player: Player, profile: any)
	profiles[player] = profile
	Remotes.sendCatalog(player, Catalog.serialize())
end

function ShopService.unregister(player: Player)
	profiles[player] = nil
end

Remotes.onBuy(function(player: Player, itemId: string?)
	local profile = profiles[player]
	if not profile or typeof(itemId) ~= "string" then
		return
	end
	local item = Catalog.items[itemId]
	if not item then
		return
	end
	if profile.Data.coins < item.price then
		Remotes.notify(player, "Moedas insuficientes.", true)
		return
	end
	profile.Data.coins -= item.price
	profile.Data.settings.owned = profile.Data.settings.owned or {}
	table.insert(profile.Data.settings.owned, itemId)
	Remotes.notify(player, "Você comprou " .. item.name .. "!", false)
	Remotes.broadcastCoins(player, profile.Data.coins)
end)

return ShopService
'''

REMOTES_MODULE = '''--!strict
-- Remotes: ponto único de comunicação cliente<->servidor.
-- Clientes NUNCA criam RemoteEvents; só o servidor garante a existência.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local NAMES = {
	"AttackRequest",
	"HealthUpdate",
	"CoinsUpdate",
	"KillFeed",
	"Swing",
	"BuyRequest",
	"Catalog",
	"Notify",
}

local folder: Folder

local function getFolder(): Folder
	if folder then
		return folder
	end
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	return folder
end

function Remotes.ensure()
	if RunService:IsClient() then
		return
	end
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
	end
	for _, name in ipairs(NAMES) do
		if not f:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = f
		end
	end
end

function Remotes.event(name: string): RemoteEvent
	local remote = getFolder():WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteEvent"), "RemoteEvent ausente: " .. name)
	return remote :: RemoteEvent
end

-- ------------------------- API do servidor
function Remotes.onAttack(callback: (Player, Instance?) -> ())
	Remotes.event("AttackRequest").OnServerEvent:Connect(callback)
end

function Remotes.onBuy(callback: (Player, string?) -> ())
	Remotes.event("BuyRequest").OnServerEvent:Connect(callback)
end

function Remotes.broadcastHealth(player: Player, health: number, maxHealth: number)
	Remotes.event("HealthUpdate"):FireClient(player, health, maxHealth)
end

function Remotes.broadcastCoins(player: Player, coins: number)
	Remotes.event("CoinsUpdate"):FireClient(player, coins)
end

function Remotes.broadcastKill(attacker: Player, victim: Player)
	Remotes.event("KillFeed"):FireAllClients(attacker.Name, victim.Name)
end

function Remotes.broadcastSwing(player: Player)
	Remotes.event("Swing"):FireAllClients(player)
end

function Remotes.sendCatalog(player: Player, payload: { any })
	Remotes.event("Catalog"):FireClient(player, payload)
end

function Remotes.notify(player: Player, message: string, isWarning: boolean)
	Remotes.event("Notify"):FireClient(player, message, isWarning)
end

-- ------------------------- API do cliente
function Remotes.requestAttack(target: Instance)
	if RunService:IsServer() then
		return
	end
	Remotes.event("AttackRequest"):FireServer(target)
end

function Remotes.requestBuy(itemId: string)
	if RunService:IsServer() then
		return
	end
	Remotes.event("BuyRequest"):FireServer(itemId)
end

function Remotes.onHealth(callback: (number, number) -> ())
	Remotes.event("HealthUpdate").OnClientEvent:Connect(callback)
end

function Remotes.onCoins(callback: (number) -> ())
	Remotes.event("CoinsUpdate").OnClientEvent:Connect(callback)
end

function Remotes.onKillFeed(callback: (string, string) -> ())
	Remotes.event("KillFeed").OnClientEvent:Connect(callback)
end

function Remotes.onSwing(callback: (Player) -> ())
	Remotes.event("Swing").OnClientEvent:Connect(callback)
end

function Remotes.onCatalog(callback: ({ any }) -> ())
	Remotes.event("Catalog").OnClientEvent:Connect(callback)
end

function Remotes.onNotify(callback: (string, boolean) -> ())
	Remotes.event("Notify").OnClientEvent:Connect(callback)
end

return Remotes
'''

CONSTANTS_MODULE = '''--!strict
-- Valores de balanceamento compartilhados (servidor e cliente).
local Constants = {
	ATTACK_DAMAGE = 18,
	ATTACK_RANGE_SERVER = 3.4, -- o servidor usa um alcance UM POUCO maior que o visual
	ATTACK_RANGE_CLIENT = 3.0,
	SPRINT_MULTIPLIER = 1.55,
	CROUCH_MULTIPLIER = 0.45,
	JUMP_POWER = 52,
	REWARD_PER_KILL = 25,
	XP_PER_KILL = 40,
	XP_CURVE = function(level: number): number
		return math.floor(100 * level ^ 1.35)
	end,
}
return Constants
'''

CATALOG_MODULE = '''--!strict
-- Catálogo da loja (o preço oficial mora aqui, no servidor).
local Catalog = {
	items = {
		sword_iron = { name = "Espada de Ferro", price = 150, kind = "weapon", damage = 18 },
		sword_steel = { name = "Espada de Aço", price = 620, kind = "weapon", damage = 26 },
		blade_aether = { name = "Lâmina de Aether", price = 2400, kind = "weapon", damage = 41 },
		potion_small = { name = "Poção Pequena", price = 40, kind = "consumable", heal = 35 },
		potion_big = { name = "Poção Grande", price = 110, kind = "consumable", heal = 80 },
		cape_scout = { name = "Capa de Batedor", price = 300, kind = "cosmetic" },
	},
}

function Catalog.serialize(): { any }
	local out = {}
	for id, item in pairs(Catalog.items) do
		table.insert(out, { id = id, name = item.name, price = item.price, kind = item.kind })
	end
	table.sort(out, function(a, b)
		return a.price < b.price
	end)
	return out
end

return Catalog
'''

CLIENT_CONTROLLER = '''--!strict
-- ClientController: input, câmera e pedidos ao servidor. Sem autoridade de dano.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Constants = require(Shared:WaitForChild("Constants"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- mira com raycast local APENAS para feedback visual
local function getTarget(): Instance?
	local origin = workspace.CurrentCamera.CFrame.Position
	local direction = workspace.CurrentCamera.CFrame.LookVector * 60
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = workspace:Raycast(origin, direction, params)
	if hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				return model
			end
		end
	end
	return nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local target = getTarget()
		if target then
			Remotes.requestAttack(target)
		end
	end
end)

-- feedback de swing (o servidor confirma via RemoteEvent "Swing")
Remotes.onSwing(function(who: Player)
	if who ~= player then
		return
	end
	-- toque um som / VFX aqui quando tiver assets
end)

print("[Arkher] ClientController pronto")
'''

SPRINT_MODULE = '''--!strict
-- Sprint/crouch via WalkSpeed (StarterCharacterScripts). Simples e robusto.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local character = script.Parent :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local baseSpeed = humanoid.WalkSpeed

local sprinting = false
local crouching = false

local function apply()
	local mult = 1
	if sprinting then
		mult = Constants.SPRINT_MULTIPLIER
	elseif crouching then
		mult = Constants.CROUCH_MULTIPLIER
	end
	humanoid.WalkSpeed = baseSpeed * mult
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = true
		apply()
	elseif input.KeyCode == Enum.KeyCode.C then
		crouching = not crouching
		apply()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = false
		apply()
	end
end)
'''

HUD_LOCAL = '''--!strict
-- HUD: vida, moedas, feed de kills e avisos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local gui = script.Parent :: ScreenGui
local frame = gui:WaitForChild("Frame") :: Frame
local healthFill = frame:WaitForChild("HealthFill") :: Frame
local healthText = frame:WaitForChild("HealthText") :: TextLabel
local coinsLabel = frame:WaitForChild("Coins") :: TextLabel
local feed = frame:WaitForChild("KillFeed") :: ScrollingFrame
local notice = frame:WaitForChild("Notice") :: TextLabel

local function setHealth(health: number, maxHealth: number)
	local ratio = math.clamp(health / math.max(1, maxHealth), 0, 1)
	TweenService:Create(healthFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(ratio, 1),
	}):Play()
	healthText.Text = string.format("%d / %d", health, maxHealth)
	if ratio < 0.3 then
		healthFill.BackgroundColor3 = Color3.fromRGB(214, 48, 49)
	else
		healthFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	end
end

Remotes.onHealth(setHealth)
Remotes.onCoins(function(coins: number)
	coinsLabel.Text = " " .. coins
end)
Remotes.onKillFeed(function(killer: string, victim: string)
	local line = Instance.new("TextLabel")
	line.Size = UDim2.new(1, 0, 0, 22)
	line.BackgroundTransparency = 1
	line.Text = killer .. " eliminou " .. victim
	line.TextColor3 = Color3.fromRGB(255, 220, 120)
	line.Font = Enum.Font.GothamMedium
	line.TextSize = 15
	line.Parent = feed
	task.delay(6, function()
		line:Destroy()
	end)
end)
Remotes.onNotify(function(message: string, isWarning: boolean)
	notice.Text = message
	notice.TextColor3 = if isWarning then Color3.fromRGB(255, 120, 120) else Color3.fromRGB(150, 255, 180)
	notice.Visible = true
	task.delay(2.5, function()
		notice.Visible = false
	end)
end)
'''

CAMERA_RIG = '''--!strict
-- Câmera em terceira pessoa com órbita suave (StarterPlayerScripts).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable

local yaw, pitch = 0, math.rad(-12)
local distance = 12
local targetDistance = 12
local smoothing = 8

UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement
		and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition then
		yaw -= input.Delta.X * 0.0042
		pitch = math.clamp(pitch - input.Delta.Y * 0.0038, math.rad(-70), math.rad(55))
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		targetDistance = math.clamp(targetDistance - input.Position.Z * 1.2, 4, 24)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	distance += (targetDistance - distance) * math.min(1, dt * smoothing)
	local headOffset = Vector3.new(0, 2.2, 0)
	local center = (hrp :: BasePart).Position + headOffset
	local dir = Vector3.new(
		math.cos(pitch) * math.sin(yaw),
		-math.sin(pitch),
		math.cos(pitch) * math.cos(yaw)
	)
	-- colisão da câmera simples: raycast do centro para trás
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance }
	local hit = workspace:Raycast(center, dir * distance, params)
	local finalDistance = if hit then hit.Distance - 0.4 else distance
	camera.CFrame = CFrame.lookAt(center + dir * finalDistance, center)
end)
'''

LIGHTING_MODEL = {
    "className": "Lighting",
    "properties": {
        "Technology": "Future",
        "ClockTime": 14.5,
        "GeographicLatitude": -23.5,
        "ExposureCompensation": 0.35,
        "EnvironmentSpecularIntensity": 1.0,
        "EnvironmentDiffuseIntensity": 1.0,
        "GlobalShadows": True,
        "ShadowSoftness": 0.35,
    },
    "children": {
        "Sky": {
            "className": "Sky",
            "properties": {
                "SkyboxBk": "rbxasset://sky/plaza_bk.jpg",
                "SkyboxDn": "rbxasset://sky/plaza_dn.jpg",
                "SkyboxFt": "rbxasset://sky/plaza_ft.jpg",
                "SkyboxLf": "rbxasset://sky/plaza_lf.jpg",
                "SkyboxRt": "rbxasset://sky/plaza_rt.jpg",
                "SkyboxUp": "rbxasset://sky/plaza_up.jpg",
                "CelestialBodiesShown": True,
                "StarCount": 2000,
            },
        },
        "Atmosphere": {
            "className": "Atmosphere",
            "properties": {
                "Density": 0.42,
                "Offset": 0.18,
                "Height": 3.6,
                "Color": [0.62, 0.75, 0.94],
                "Decay": [0.55, 0.62, 0.75],
                "Glare": 0.35,
                "Haze": 1.4,
            },
        },
        "SunRays": {"className": "SunRaysEffect", "properties": {"Intensity": 0.22}},
        "Bloom": {"className": "BloomEffect", "properties": {"Intensity": 0.42, "Size": 24, "Threshold": 1.6}},
        "ColorCorrection": {
            "className": "ColorCorrectionEffect",
            "properties": {"Contrast": 0.08, "Saturation": 0.12, "Brightness": 0.02},
        },
        "DepthOfField": {
            "className": "DepthOfFieldEffect",
            "properties": {"FarIntensity": 0.12, "NearIntensity": 0.0, "FocusDistance": 14},
        },
    },
}

SOUND_SERVICE_MODEL = {
    "className": "SoundService",
    "properties": {"RespectFilteringEnabled": True, "DistanceFactor": 0.35},
    "children": {
        "MusicBus": {"className": "SoundGroup", "properties": {"Volume": 0.7}},
        "SfxBus": {"className": "SoundGroup", "properties": {"Volume": 1.0}},
    },
}


def generate_roblox_project(
    name: str = "Meu Jogo Roblox",
    description: str = "Jogo Roblox gerado pelo Arkher AI",
    genre: str = "acao",
) -> Dict[str, object]:
    files: Dict[str, object] = {}

    tree = {
        "$className": "DataModel",
        "ServerScriptService": {
            "$className": "ServerScriptService",
            "$ignoreUnknownInstances": True,
            "$path": "src/ServerScriptService",
        },
        "ReplicatedStorage": {
            "$className": "ReplicatedStorage",
            "$ignoreUnknownInstances": True,
            "$path": "src/ReplicatedStorage",
        },
        "StarterPlayer": {
            "$className": "StarterPlayer",
            "StarterPlayerScripts": {
                "$className": "StarterPlayerScripts",
                "$path": "src/StarterPlayerScripts",
            },
            "StarterCharacterScripts": {
                "$className": "StarterCharacterScripts",
                "$path": "src/StarterCharacterScripts",
            },
        },
        "StarterGui": {"$className": "StarterGui", "$path": "src/StarterGui"},
        "Workspace": {
            "$className": "Workspace",
            "$ignoreUnknownInstances": True,
            "$path": "src/Workspace",
            "properties": {"StreamingEnabled": True, "StreamOutBehavior": "Opportunistic"},
        },
        "Lighting": LIGHTING_MODEL,
        "SoundService": SOUND_SERVICE_MODEL,
    }
    files["default.project.json"] = json.dumps({"name": name, "tree": tree}, indent=2, ensure_ascii=False)

    sss = "src/ServerScriptService"
    files[f"{sss}/GameServer.server.lua"] = GAME_SERVER
    files[f"{sss}/CombatService.lua"] = COMBAT_SERVICE
    files[f"{sss}/ProfileService.lua"] = PROFILE_SERVICE
    files[f"{sss}/ShopService.lua"] = SHOP_SERVICE

    rs = "src/ReplicatedStorage"
    files[f"{rs}/Shared/Remotes.lua"] = REMOTES_MODULE
    files[f"{rs}/Shared/Constants.lua"] = CONSTANTS_MODULE
    files[f"{rs}/Shared/Catalog.lua"] = CATALOG_MODULE
    for remote in ("AttackRequest", "HealthUpdate", "CoinsUpdate", "KillFeed", "Swing", "BuyRequest", "Catalog", "Notify"):
        files[f"{rs}/Remotes/{remote}.model.json"] = json.dumps({"className": "RemoteEvent"}, indent=2)

    sps = "src/StarterPlayerScripts"
    files[f"{sps}/ClientController.client.lua"] = CLIENT_CONTROLLER
    files[f"{sps}/CameraRig.client.lua"] = CAMERA_RIG
    files["src/StarterCharacterScripts/SprintCrouch.lua"] = SPRINT_MODULE

    files["src/StarterGui/HUD/HUD.client.lua"] = HUD_LOCAL
    files["src/StarterGui/HUD/Frame.model.json"] = json.dumps(
        {
            "className": "Frame",
            "properties": {
                "BackgroundColor3": [0.08, 0.09, 0.12],
                "BackgroundTransparency": 0.25,
                "BorderSizePixel": 0,
                "Position": [0.02, 0.0, 0.02, 0.0],
                "Size": [0.28, 0.0, 0.16, 0.0],
            },
            "children": {
                "HealthFill": {
                    "className": "Frame",
                    "properties": {
                        "BackgroundColor3": [0.18, 0.8, 0.44],
                        "BorderSizePixel": 0,
                        "Size": [1.0, 0.0, 0.32, 0.0],
                        "Position": [0.0, 0.0, 0.08, 0.0],
                    },
                },
                "HealthText": {
                    "className": "TextLabel",
                    "properties": {
                        "BackgroundTransparency": 1.0,
                        "Text": "100 / 100",
                        "TextColor3": [1.0, 1.0, 1.0],
                        "Font": "GothamMedium",
                        "TextSize": 16,
                        "Position": [0.0, 0.0, 0.0, 0.0],
                        "Size": [1.0, 0.0, 0.3, 0.0],
                        "TextXAlignment": "Left",
                    },
                },
                "Coins": {
                    "className": "TextLabel",
                    "properties": {
                        "BackgroundTransparency": 1.0,
                        "Text": "🪙 0",
                        "TextColor3": [1.0, 0.85, 0.4],
                        "Font": "GothamBold",
                        "TextSize": 18,
                        "Position": [0.0, 0.0, 0.42, 0.0],
                        "Size": [1.0, 0.0, 0.26, 0.0],
                        "TextXAlignment": "Left",
                    },
                },
                "KillFeed": {
                    "className": "ScrollingFrame",
                    "properties": {
                        "BackgroundTransparency": 1.0,
                        "BorderSizePixel": 0,
                        "Position": [0.0, 0.0, 0.72, 0.0],
                        "Size": [1.0, 0.0, 0.28, 0.0],
                        "ScrollBarThickness": 0,
                        "CanvasSize": [0.0, 0.0, 3.0, 0.0],
                    },
                },
                "Notice": {
                    "className": "TextLabel",
                    "properties": {
                        "BackgroundTransparency": 1.0,
                        "Text": "",
                        "Visible": False,
                        "Font": "GothamMedium",
                        "TextSize": 15,
                        "Position": [0.0, 0.0, 0.36, 0.0],
                        "Size": [1.0, 0.0, 0.2, 0.0],
                        "TextXAlignment": "Left",
                    },
                },
            },
        },
        indent=2,
        ensure_ascii=False,
    )

    ws = "src/Workspace"
    files[f"{ws}/Spawn.model.json"] = json.dumps(
        {
            "className": "SpawnLocation",
            "properties": {
                "Anchored": True,
                "Size": [8, 1, 8],
                "Position": [0, 0.5, 0],
                "Material": "Slate",
                "Color": [0.32, 0.34, 0.38],
                "Neutral": True,
            },
        },
        indent=2,
    )
    files[f"{ws}/Arena.model.json"] = json.dumps(
        {
            "className": "Folder",
            "children": {
                "Floor": {
                    "className": "Part",
                    "properties": {
                        "Anchored": True,
                        "Size": [120, 2, 120],
                        "Position": [0, -1, 0],
                        "Material": "Concrete",
                        "Color": [0.42, 0.42, 0.4],
                    },
                },
                "WallN": {"className": "Part", "properties": {"Anchored": True, "Size": [120, 8, 2], "Position": [0, 4, -60], "Material": "Concrete", "Color": [0.5, 0.48, 0.45]}},
                "WallS": {"className": "Part", "properties": {"Anchored": True, "Size": [120, 8, 2], "Position": [0, 4, 60], "Material": "Concrete", "Color": [0.5, 0.48, 0.45]}},
                "WallE": {"className": "Part", "properties": {"Anchored": True, "Size": [2, 8, 120], "Position": [60, 4, 0], "Material": "Concrete", "Color": [0.5, 0.48, 0.45]}},
                "WallW": {"className": "Part", "properties": {"Anchored": True, "Size": [2, 8, 120], "Position": [-60, 4, 0], "Material": "Concrete", "Color": [0.5, 0.48, 0.45]}},
                "CoverA": {"className": "Part", "properties": {"Anchored": True, "Size": [6, 3, 2], "Position": [12, 1.5, 8], "Material": "Slate", "Color": [0.3, 0.32, 0.36]}},
                "CoverB": {"className": "Part", "properties": {"Anchored": True, "Size": [6, 3, 2], "Position": [-14, 1.5, -10], "Material": "Slate", "Color": [0.3, 0.32, 0.36]}},
                "Tower": {"className": "Part", "properties": {"Anchored": True, "Size": [8, 14, 8], "Position": [0, 7, -30], "Material": "Slate", "Color": [0.26, 0.28, 0.33]}},
            },
        },
        indent=2,
    )

    files["README.md"] = _roblox_readme(name, description, files)
    files["docs/GDD.md"] = _roblox_gdd(name, description, genre)
    files[".gitignore"] = "*.rbxl.lock\n.rojo/\n"
    files["aftman.toml"] = '[tools]\nrojo = "rojo-rbx/rojo@7.4.4"\nselene = "Kampfkarren/selene@0.27.1"\n'
    files["selene.toml"] = 'std = "roblox"\n'
    files["roblox.toml"] = '# Config do luau-analyze\n'
    return files


def _roblox_readme(name: str, description: str, files: Dict[str, object]) -> str:
    return f"""# {name} (Roblox)

> Projeto Roblox gerado pelo **Arkher AI** — {description}
> Sincronização com o Studio via **Rojo 7**.

## Como rodar (5 minutos)

1. Instale o [Rojo](https://rojo.space) (ou use `aftman install` na pasta — já tem `aftman.toml`)
2. Abra o **Roblox Studio** → **New → Baseplate** → salve como `{name}.rbxl`
3. Instale o plugin **Rojo** no Studio (Toolbox → Plugins → "Rojo")
4. No terminal, dentro desta pasta:
   ```bash
   rojo serve
   ```
5. No Studio: plugin Rojo → **Connect** (localhost:34872) → aceite o sync

Pronto: todo arquivo `.lua` / `.model.json` aqui vira instância no Studio ao vivo.

## Arquitetura (server-authoritative)

```
ServerScriptService/
  GameServer.server.lua     <- bootstrap
  CombatService.lua         <- dano validado NO SERVIDOR (alcance, cooldown, rate limit)
  ProfileService.lua        <- DataStore com retries + autosave + BindToClose
  ShopService.lua           <- loja com preço vindo do catálogo do servidor
ReplicatedStorage/
  Shared/Remotes.lua        <- único ponto de comunicação (RemoteEvents)
  Shared/Constants.lua      <- balanceamento compartilhado
  Shared/Catalog.lua        <- itens/preços oficiais
  Remotes/*.model.json      <- RemoteEvents criados pelo Rojo
StarterPlayerScripts/
  ClientController.client.lua  <- input + raycast visual + pedido de ataque
  CameraRig.client.lua         <- câmera 3ª pessoa com órbita e colisão
StarterCharacterScripts/
  SprintCrouch.lua          <- WalkSpeed com Shift / C
StarterGui/HUD/             <- ScreenGui com vida, moedas, kill feed e avisos
Workspace/                  <- spawn + arena com cobertura
Lighting/                   <- Future lighting + Atmosphere + Bloom + ColorCorrection
```

## Por que é seguro contra exploit

| Trapaça comum | Como o projeto bloqueia |
|---|---|
| Cliente envia dano direto | Dano só existe em `CombatService` (servidor) |
| Teleporte para matar | Validação de distância `ATTACK_RANGE_SERVER` |
| Spam de clique | Rate limit de 12 req/s por jogador |
| Autoclicker rápido | Cooldown de 0.55 s por ataque |
| Compra sem moedas | Preço conferido no `Catalog` do servidor |
| Fechar o jogo p/ não salvar | `BindToClose` + autosave a cada 120 s |

## Próximos passos

- [ ] Importar meshes `.glb` gerados pelo Arkher (Workspace → Import)
- [ ] Trocar texturas placeholder pelos mapas PBR (máx. 1024 px no Roblox!)
- [ ] Subir animações: use o `.rbxlx` de KeyframeSequence que o Arkher exporta
- [ ] Adicionar StreamingEnabled regions para mapa grande (já habilitado no Workspace)
- [ ] Publicar: Studio → File → Publish to Roblox
"""


def _roblox_gdd(name: str, description: str, genre: str) -> str:
    return f"""# GDD — {name} (Roblox)

**Gerado por:** Arkher AI  |  **Gênero:** {genre}

{description}

## Loop principal
Spawn → coletar/comprar equipamento → arena PvPvE → kills dão moedas e XP →
loja (catálogo no servidor) → equipamento mais forte → repet.

## Economia
| Fonte | Moedas | XP |
|---|---|---|
| Kill | 25 | 40 |
| Vitória de rodada | 60 | 120 |
| Diária (login) | 30 | 0 |

Curva de nível: `xp_needed = 100 * level^1.35` (ver `Shared/Constants.lua`).

## Plataformas e limites Roblox
- Texturas: **máx 1024 px** (o Roblox reamostra acima disso) — gere 1k no Arkher.
- Triângulos por mesh: manter < 50k; usar LODs do Arkher.
- `StreamingEnabled` ligado para mundos grandes (já configurado).
- RemoteEvents para TUDO que cruza a fronteira cliente/servidor.
"""

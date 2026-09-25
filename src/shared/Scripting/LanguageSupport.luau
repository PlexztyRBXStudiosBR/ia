--!strict
-- Arkher Studio - Fase 1.5 - LanguageSupport - Suporte a Luau, Python 3.14, Visual Scripting
-- IA ajuda em todas

export type SupportedLanguage = "luau" | "python" | "visual" | "ai"

export type LanguageConfig = {
	id: SupportedLanguage,
	displayName: string,
	icon: string,
	extension: string,
	monacoLanguage: string,
	version: string,
	features: { string },
	example: string,
}

local LanguageSupport = {}

LanguageSupport.Languages = {
	luau = {
		id = "luau",
		displayName = "Luau (Roblox)",
		icon = "",
		extension = ".luau",
		monacoLanguage = "lua",
		version = "0.600",
		features = {"types", "async", "parallel", "buffer", "native"},
		example = [[
-- Arkher Luau - Tipado, rápido, nativo Roblox
local Players = game:GetService("Players")

type PlayerData = {
    userId: number,
    coins: number,
    level: number
}

local function giveCoins(player: Player, amount: number): PlayerData
    print(`Giving {amount} coins to {player.Name}`)
    return {
        userId = player.UserId,
        coins = amount,
        level = 1
    }
end

Players.PlayerAdded:Connect(function(player)
    local data = giveCoins(player, 100)
    print(`Player {player.Name} has {data.coins} coins`)
end)
]],
	},
	python = {
		id = "python",
		displayName = "Python 3.14",
		icon = "Python",
		extension = ".py",
		monacoLanguage = "python",
		version = "3.14.0",
		features = {"match", "typehints", "async", "fstrings", "walrus", "patternmatching", "exceptiongroups"},
		example = [[
# Arkher Python 3.14 - Roda no Roblox via transpilação para Luau
# Suporte completo a Python 3.14 + libs Arkher

from arkher import Entity, Component, World
from arkher import Vector3, Color3
from typing import Optional

def create_coin_system(world: World, amount: int = 100) -> None:
    """Cria sistema de moedas com Python"""
    
    # Python 3.14 match statement
    def get_coin_value(coin_type: str) -> int:
        match coin_type:
            case "gold":
                return 100
            case "silver":
                return 50
            case "bronze":
                return 10
            case _:
                return 1
    
    # F-string + walrus operator (Python 3.8+)
    if (coins := get_coin_value("gold")) > 50:
        print(f"Moeda valiosa: {coins} coins!")
    
    # Cria entidade com API Arkher Python
    coin = Entity.new("GoldCoin")
    coin.add_component(Component.Transform(
        position=Vector3(0, 5, 0),
        rotation=Vector3(0, 0, 0)
    ))
    coin.add_component(Component.Render(
        material="Neon",
        color=Color3.from_rgb(255, 215, 0)
    ))
    
    world.add_entity(coin)
    print(f"Criado {coin.name} com {coins} moedas!")

# Async support (Python 3.14)
async def spawn_coins_async(world: World, count: int):
    import asyncio
    for i in range(count):
        create_coin_system(world, 100)
        await asyncio.sleep(0.1)
        print(f"Spawned {i+1}/{count} coins")

# Roda
create_coin_system(World.current(), 100)
]],
	},
	visual = {
		id = "visual",
		displayName = "Visual Scripting (Blockly)",
		icon = "",
		extension = ".block",
		monacoLanguage = "json",
		version = "1.0",
		features = {"dragdrop", "mobile", "ai-assist"},
		example = [[
{
  "blocks": [
    {
      "type": "when_player_touches",
      "inputs": {
        "object": "GoldCoin"
      },
      "next": {
        "type": "give_coins",
        "inputs": {
          "amount": 100
        },
        "next": {
          "type": "play_sound",
          "inputs": {
            "sound": "CoinPickup"
          }
        }
      }
    }
  ]
}
]],
	},
	ai = {
		id = "ai",
		displayName = "AI Generated",
		icon = "AI",
		extension = ".ai",
		monacoLanguage = "lua",
		version = "1.0",
		features = {"prompt", "auto", "multilang"},
		example = [[
-- Prompt: "cria um sistema de moedas que gira e dá 10 coins"
-- Gerado por Arkher AI - Pode ser Luau ou Python

-- AI escolheu Luau para performance
local coin = script.Parent

local function onTouch(hit)
    local player = game.Players:GetPlayerFromCharacter(hit.Parent)
    if player then
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local coins = leaderstats:FindFirstChild("Coins")
            if coins then
                coins.Value += 10
                coin:Destroy()
            end
        end
    end
end

-- Gira
game:GetService("RunService").Heartbeat:Connect(function(dt)
    coin.CFrame *= CFrame.Angles(0, math.rad(100) * dt, 0)
end)

coin.Touched:Connect(onTouch)
]],
	},
}

function LanguageSupport.GetLanguage(id: SupportedLanguage): LanguageConfig?
	return LanguageSupport.Languages[id]
end

function LanguageSupport.GetAllLanguages(): { LanguageConfig }
	local result = {}
	for _, lang in LanguageSupport.Languages do
		table.insert(result, lang)
	end
	return result
end

function LanguageSupport.DetectLanguageFromExtension(ext: string): SupportedLanguage?
	for id, lang in LanguageSupport.Languages do
		if lang.extension == ext then
			return id :: SupportedLanguage
		end
	end
	return nil
end

function LanguageSupport.GetMonacoLanguage(langId: SupportedLanguage): string
	local lang = LanguageSupport.Languages[langId]
	return lang and lang.monacoLanguage or "plaintext"
end

return LanguageSupport

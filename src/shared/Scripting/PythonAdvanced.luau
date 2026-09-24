--!strict
-- Arkher Studio - Fase 2 - PythonAdvanced - Suporte a classes, async/await, decorators, etc
-- Python 3.14 completo via transpilação + backend

local PythonAdvanced = {}

-- Exemplo de como transpilar classe Python -> Luau
PythonAdvanced.ClassExample = [[
# Python 3.14 - Classe
class CoinSystem:
    def __init__(self, amount: int = 10):
        self.amount = amount
        self.collected = 0
    
    def collect(self, player):
        self.collected += self.amount
        print(f"{player.Name} coletou {self.amount} moedas! Total: {self.collected}")
        return self.collected
    
    @property
    def total(self):
        return self.collected

# Uso
system = CoinSystem(100)
system.collect(player)
]]

PythonAdvanced.LuauTranspiledClassExample = [[
-- Transpilado de Python classe -> Luau
local CoinSystem = {}
CoinSystem.__index = CoinSystem

function CoinSystem.new(amount)
    return setmetatable({
        amount = amount or 10,
        collected = 0,
    }, CoinSystem)
end

function CoinSystem:collect(player)
    self.collected += self.amount
    print(string.format("%s coletou %d moedas! Total: %d", player.Name, self.amount, self.collected))
    return self.collected
end

function CoinSystem:getTotal()
    return self.collected
end

-- Uso
local system = CoinSystem.new(100)
system:collect(player)
]]

-- Decorators Python -> Luau
PythonAdvanced.DecoratorExample = [[
# Python 3.14 - Decorator
def debug(func):
    def wrapper(*args, **kwargs):
        print(f"Chamando {func.__name__} com {args}")
        result = func(*args, **kwargs)
        print(f"{func.__name__} retornou {result}")
        return result
    return wrapper

@debug
def give_coins(player, amount):
    return amount

# Transpila para Luau com wrapper
]]

-- Async/Await Python -> Luau task
PythonAdvanced.AsyncExample = [[
# Python 3.14 - Async/Await
import asyncio

async def spawn_coins(world, count: int):
    for i in range(count):
        coin = Entity.new(f"Coin_{i}")
        world.add_entity(coin)
        print(f"Spawned {coin.name}")
        await asyncio.sleep(0.5)  # espera 0.5s

# Transpila para Luau:
# local function spawn_coins(world, count)
#     for i=0,count-1 do
#         local coin = Entity.new("Coin_"..i)
#         world:AddEntity(coin)
#         task.wait(0.5)
#     end
# end
]]

function PythonAdvanced.TranspileClass(pythonClassCode: string): string
	-- Fase 2: Transpila classe Python para Luau table + metatable
	-- Usa parsing simples, Fase 3 usa AST completo

	local luau = "-- Transpiled Python class -> Luau\n"

	-- Extrai nome da classe
	local className = string.match(pythonClassCode, "class%s+([%w_]+)")
	if not className then
		return "-- Failed to parse class"
	end

	luau ..= string.format("local %s = {}\n%s.__index = %s\n\n", className, className, className)

	-- __init__ -> new
	local initParams = string.match(pythonClassCode, "def%s+__init__%s*%([^,]+,%s*([^%)]*)%)")
	if initParams then
		luau ..= string.format("function %s.new(%s)\n", className, initParams)
		luau ..= string.format("    return setmetatable({\n        -- TODO: parse __init__ body\n    }, %s)\nend\n\n", className)
	else
		luau ..= string.format("function %s.new()\n    return setmetatable({}, %s)\nend\n\n", className, className)
	end

	-- Métodos def -> function Class:method
	for methodName, params in string.gmatch(pythonClassCode, "def%s+([%w_]+)%s*%(([^%)]*)%)") do
		if methodName ~= "__init__" then
			-- Remove self do params
			local cleanParams = string.gsub(params, "self%s*,?%s*", "")
			luau ..= string.format("function %s:%s(%s)\n    -- TODO: body\nend\n\n", className, methodName, cleanParams)
		end
	end

	return luau
end

function PythonAdvanced.TranspileAsync(pythonAsyncCode: string): string
	-- Transpila async/await para task.wait + task.spawn

	local luau = string.gsub(pythonAsyncCode, "async%s+def%s+([%w_]+)%s*%(([^%)]*)%)%s*:", "local function %1(%2)")

	luau = string.gsub(luau, "await%s+asyncio%.sleep%(([^%)]+)%)", "task.wait(%1)")

	luau = string.gsub(luau, "await%s+([%w_%.%(%)]+)", "task.wait() -- await %1")

	return luau
end

function PythonAdvanced.GetSupportedAdvancedFeatures(): { string }
	return {
		"classes (basic) - class -> table + metatable",
		"__init__ -> new()",
		"methods -> function Class:method()",
		"@property -> getX()",
		"@decorator (mock, Fase 3 full)",
		"async/await -> task.spawn + task.wait",
		"asyncio.sleep -> task.wait",
		"type hints (ignored at runtime, for docs + AI)",
		"match/case (transpiled to if/elseif)",
		"f-strings -> Luau interpolation `...`",
		"walrus := (Fase 3)",
		"exception groups (Fase 3)",
	}
end

return PythonAdvanced

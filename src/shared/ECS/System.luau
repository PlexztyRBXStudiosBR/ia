--!strict
-- Arkher Studio - System Base
-- Sistemas que operam sobre entidades. Inspirado no Unity DOTS + Unreal Mass

local World = require(script.Parent.World)

export type System = {
	name: string,
	priority: number,
	enabled: boolean,
	Update: (self: System, world: World.World, dt: number) -> (),
}

local System = {}
System.__index = System

function System.new(name: string, priority: number, updateFn: (World.World, number) -> ()): System
	return setmetatable({
		name = name,
		priority = priority or 0,
		enabled = true,
		Update = function(self: System, world: World.World, dt: number)
			if self.enabled then
				updateFn(world, dt)
			end
		end,
	}, System)
end

-- Sistemas built-in que vamos ter:

-- 1. TransformSystem: Atualiza CFrames hierárquicos
-- 2. RenderSystem: Materializa entidades virtuais em Instances reais só no Play Mode (Fase 1) ou EditableMesh (Fase 6)
-- 3. PhysicsSystem: Se customPhysics=true, usa ArkherPhysics, senão Roblox
-- 4. LODSystem: Troca LOD baseado na distância (crucial para A01 rodar AAA)
-- 5. StreamingSystem: Só carrega entidades perto do player (World Creator style)

return System

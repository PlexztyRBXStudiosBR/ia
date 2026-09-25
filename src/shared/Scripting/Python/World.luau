--!strict
-- Arkher Studio - Python API - World wrapper

local WorldModule = require(script.Parent.Parent.Parent.ECS.World)

local World = {}
World._current = nil

function World.new(): any
	local world = WorldModule.new()

	world.add_entity = function(self, entity: any)
		return WorldModule.AddEntity(self, entity)
	end

	world.remove_entity = function(self, entityId: string)
		return WorldModule.RemoveEntity(self, entityId)
	end

	world.get_entity = function(self, entityId: string)
		return WorldModule.GetEntity(self, entityId)
	end

	world.query_components = function(self, ...)
		return WorldModule.QueryComponents(self, ...)
	end

	World._current = world
	return world
end

function World.current(): any
	return World._current
end

return World

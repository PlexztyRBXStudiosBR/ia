--!strict
-- Arkher Studio - Python API - Entity wrapper para Python
-- Permite usar Entity.new em Python: Entity.new("Coin")

local EntityModule = require(script.Parent.Parent.Parent.ECS.Entity)

local Entity = {}

function Entity.new(name: string, parentId: string?): any
	local entity = EntityModule.new(name, parentId)

	-- Adiciona métodos Python-style (snake_case)
	entity.add_component = function(self, compName: string, data: any)
		EntityModule.AddComponent(self, compName, data)
	end

	entity.get_component = function(self, compName: string)
		return EntityModule.GetComponent(self, compName)
	end

	entity.has_component = function(self, compName: string)
		return EntityModule.HasComponent(self, compName)
	end

	entity.add_tag = function(self, tag: string)
		EntityModule.AddTag(self, tag)
	end

	return entity
end

return Entity

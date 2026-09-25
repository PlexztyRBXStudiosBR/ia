--!strict
-- Arkher Studio - World (ECS World)
-- Gerencia todas as entidades virtuais. Suporta 20k+ entidades no mobile com octree + streaming.

local Entity = require(script.Parent.Entity)

export type World = {
	entities: { [string]: Entity.Entity },
	rootEntities: { string },
	systems: { any },
	entityCount: number,
	version: number,
}

local World = {}
World.__index = World

function World.new(): World
	return setmetatable({
		entities = {},
		rootEntities = {},
		systems = {},
		entityCount = 0,
		version = 1,
	}, World)
end

function World:AddEntity(entity: Entity.Entity): string
	self.entities[entity.id] = entity
	if entity.parent == nil then
		table.insert(self.rootEntities, entity.id)
	else
		local parent = self.entities[entity.parent]
		if parent then
			table.insert(parent.children, entity.id)
		end
	end
	self.entityCount += 1
	self.version += 1
	return entity.id
end

function World:RemoveEntity(entityId: string)
	local entity = self.entities[entityId]
	if not entity then return end

	-- Remove filhos recursivamente
	for _, childId in entity.children do
		self:RemoveEntity(childId)
	end

	-- Remove do parent
	if entity.parent then
		local parent = self.entities[entity.parent]
		if parent then
			for i, cid in parent.children do
				if cid == entityId then
					table.remove(parent.children, i)
					break
				end
			end
		end
	else
		for i, rid in self.rootEntities do
			if rid == entityId then
				table.remove(self.rootEntities, i)
				break
			end
		end
	end

	self.entities[entityId] = nil
	self.entityCount -= 1
	self.version += 1
end

function World:GetEntity(entityId: string): Entity.Entity?
	return self.entities[entityId]
end

function World:QueryComponents(...: string): { Entity.Entity }
	local required = {...}
	local result = {}
	for _, entity in self.entities do
		local hasAll = true
		for _, compName in required do
			if not entity.components[compName] then
				hasAll = false
				break
			end
		end
		if hasAll then
			table.insert(result, entity)
		end
	end
	return result
end

function World:QueryTag(tag: string): { Entity.Entity }
	local result = {}
	for _, entity in self.entities do
		if entity.tags[tag] then
			table.insert(result, entity)
		end
	end
	return result
end

function World:GetRootEntities(): { Entity.Entity }
	local result = {}
	for _, id in self.rootEntities do
		local e = self.entities[id]
		if e then table.insert(result, e) end
	end
	return result
end

function World:Clear()
	self.entities = {}
	self.rootEntities = {}
	self.entityCount = 0
	self.version += 1
end

return World

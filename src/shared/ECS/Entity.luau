--!strict
-- Arkher Studio - ECS Entity
-- Entidade virtual, não é Instance do Roblox. É assim que aguentamos 20k objetos no mobile.

export type EntityId = string

export type Entity = {
	id: EntityId,
	name: string,
	parent: EntityId?,
	children: { EntityId },
	components: { [string]: any },
	tags: { [string]: boolean },
	createdAt: number,
	updatedAt: number,
	isLocked: boolean,
	isHidden: boolean,
	isPrefab: boolean,
	prefabId: string?,
}

local Entity = {}
Entity.__index = Entity

local function generateId(): string
	return game:GetService("HttpService"):GenerateGUID(false)
end

function Entity.new(name: string, parentId: EntityId?): Entity
	local now = os.clock()
	return {
		id = generateId(),
		name = name or "Entity",
		parent = parentId,
		children = {},
		components = {},
		tags = {},
		createdAt = now,
		updatedAt = now,
		isLocked = false,
		isHidden = false,
		isPrefab = false,
		prefabId = nil,
	}
end

function Entity.AddComponent(entity: Entity, compName: string, data: any)
	entity.components[compName] = data
	entity.updatedAt = os.clock()
end

function Entity.GetComponent(entity: Entity, compName: string): any?
	return entity.components[compName]
end

function Entity.HasComponent(entity: Entity, compName: string): boolean
	return entity.components[compName] ~= nil
end

function Entity.RemoveComponent(entity: Entity, compName: string)
	entity.components[compName] = nil
	entity.updatedAt = os.clock()
end

function Entity.AddTag(entity: Entity, tag: string)
	entity.tags[tag] = true
end

function Entity.HasTag(entity: Entity, tag: string): boolean
	return entity.tags[tag] == true
end

return Entity

--!strict
-- Arkher Studio - Python API - Component wrappers

local ComponentModule = require(script.Parent.Parent.Parent.ECS.Component)

local Component = {}

function Component.Transform(position: Vector3?, rotation: Vector3?, scale: Vector3?): any
	return ComponentModule.Transform(position, rotation, scale)
end

function Component.Render(material: Enum.Material?, color: Color3?): any
	return ComponentModule.Render(material, color)
end

function Component.Physics(bodyType: string?): any
	return ComponentModule.Physics(bodyType)
end

function Component.ScriptComponent(source: string?, isServer: boolean?): any
	return ComponentModule.ScriptComponent(source, isServer)
end

return Component

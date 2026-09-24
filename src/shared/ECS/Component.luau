--!strict
-- Arkher Studio - Component Definitions
-- Inspirado no Blender + Unity + Unreal - Tudo que o Roblox Studio tem e mais

export type Transform = {
	position: Vector3,
	rotation: Vector3, -- Euler degrees
	scale: Vector3,
	cframe: CFrame,
}

export type Render = {
	meshId: string?, -- EditableMesh ID ou rbxassetid
	textureId: string?,
	material: Enum.Material,
	color: Color3,
	transparency: number,
	castShadow: boolean,
	lodLevel: number, -- 0=High, 1=Med, 2=Low, 3=Impostor
	styleProfile: string, -- lowpoly, anime, realistic, photorealistic
}

export type Physics = {
	bodyType: string, -- static, dynamic, kinematic, soft, fluid
	mass: number,
	friction: number,
	elasticity: number,
	collisionGroup: string,
	customPhysics: boolean, -- se true, usa ArkherPhysics (Fase 6)
}

export type ScriptComponent = {
	source: string,
	language: string, -- luau, visual, ai-generated
	enabled: boolean,
	sandboxed: boolean,
	isServer: boolean,
}

export type LightComponent = {
	lightType: string, -- point, spot, directional, area
	color: Color3,
	intensity: number,
	range: number,
	shadows: boolean,
	volumetric: boolean,
}

export type TerrainCell = {
	voxelData: buffer?, -- custom voxel para ArkherTerrain
	material: string,
	density: number,
}

export type PrefabLink = {
	prefabAssetId: string,
	overrides: { [string]: any },
	autoUpdate: boolean,
}

export type Metadata = {
	creatorId: number,
	createdFrom: string, -- toolbox, vault, ai, manual
	tags: { string },
	version: number,
}

local Component = {}

function Component.Transform(pos: Vector3?, rot: Vector3?, scale: Vector3?): Transform
	return {
		position = pos or Vector3.new(0,0,0),
		rotation = rot or Vector3.new(0,0,0),
		scale = scale or Vector3.new(1,1,1),
		cframe = CFrame.new(pos or Vector3.new(0,0,0)) * CFrame.fromEulerAnglesYXZ(math.rad(rot and rot.X or 0), math.rad(rot and rot.Y or 0), math.rad(rot and rot.Z or 0)),
	}
end

function Component.Render(material: Enum.Material?, color: Color3?): Render
	return {
		meshId = nil,
		textureId = nil,
		material = material or Enum.Material.Plastic,
		color = color or Color3.fromRGB(255,255,255),
		transparency = 0,
		castShadow = true,
		lodLevel = 0,
		styleProfile = "realistic",
	}
end

function Component.Physics(bodyType: string?): Physics
	return {
		bodyType = bodyType or "static",
		mass = 1,
		friction = 0.3,
		elasticity = 0.5,
		collisionGroup = "Default",
		customPhysics = false,
	}
end

function Component.ScriptComponent(source: string?, isServer: boolean?): ScriptComponent
	return {
		source = source or "print('Hello from Arkher')",
		language = "luau",
		enabled = true,
		sandboxed = true,
		isServer = isServer or false,
	}
end

return Component

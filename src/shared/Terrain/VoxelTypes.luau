--!strict
-- Arkher Studio - Fase 4 - VoxelTypes - World Creator + Mecha Engine
-- Tipos de voxel para terreno custom - Inspiração: World Creator + Minecraft + Dual Contouring

local VoxelTypes = {}

export type VoxelMaterial = {
	id: number,
	name: string,
	displayName: string,
	color: Color3,
	physical: {
		density: number,
		hardness: number,
		friction: number,
	},
	render: {
		material: Enum.Material,
		metalness: number,
		roughness: number,
	},
	isAir: boolean,
	isLiquid: boolean,
	isSolid: boolean,
}

VoxelTypes.Materials = {
	[0] = {
		id = 0,
		name = "Air",
		displayName = "Air",
		color = Color3.fromRGB(0,0,0),
		physical = { density = 0, hardness = 0, friction = 0 },
		render = { material = Enum.Material.Air, metalness = 0, roughness = 0 },
		isAir = true,
		isLiquid = false,
		isSolid = false,
	},
	[1] = {
		id = 1,
		name = "Grass",
		displayName = "Grass",
		color = Color3.fromRGB(60, 180, 75),
		physical = { density = 1.2, hardness = 0.5, friction = 0.8 },
		render = { material = Enum.Material.Grass, metalness = 0, roughness = 0.9 },
		isAir = false,
		isLiquid = false,
		isSolid = true,
	},
	[2] = {
		id = 2,
		name = "Dirt",
		displayName = "Dirt",
		color = Color3.fromRGB(139, 90, 43),
		physical = { density = 1.5, hardness = 0.6, friction = 0.7 },
		render = { material = Enum.Material.Ground, metalness = 0, roughness = 1 },
		isAir = false,
		isLiquid = false,
		isSolid = true,
	},
	[3] = {
		id = 3,
		name = "Rock",
		displayName = "Rock",
		color = Color3.fromRGB(100, 100, 100),
		physical = { density = 2.5, hardness = 5, friction = 0.9 },
		render = { material = Enum.Material.Rock, metalness = 0.1, roughness = 0.8 },
		isAir = false,
		isLiquid = false,
		isSolid = true,
	},
	[4] = {
		id = 4,
		name = "Sand",
		displayName = "Sand",
		color = Color3.fromRGB(220, 200, 150),
		physical = { density = 1.6, hardness = 0.3, friction = 0.5 },
		render = { material = Enum.Material.Sand, metalness = 0, roughness = 1 },
		isAir = false,
		isLiquid = false,
		isSolid = true,
	},
	[5] = {
		id = 5,
		name = "Snow",
		displayName = "Snow",
		color = Color3.fromRGB(240, 240, 255),
		physical = { density = 0.5, hardness = 0.2, friction = 0.2 },
		render = { material = Enum.Material.Snow, metalness = 0, roughness = 0.3 },
		isAir = false,
		isLiquid = false,
		isSolid = true,
	},
	[6] = {
		id = 6,
		name = "Water",
		displayName = "Water",
		color = Color3.fromRGB(50, 150, 255),
		physical = { density = 1.0, hardness = 0, friction = 0.1 },
		render = { material = Enum.Material.Water, metalness = 0, roughness = 0.1 },
		isAir = false,
		isLiquid = true,
		isSolid = false,
	},
	[7] = {
		id = 7,
		name = "Lava",
		displayName = "Lava",
		color = Color3.fromRGB(255, 80, 0),
		physical = { density = 2.0, hardness = 0, friction = 0.3 },
		render = { material = Enum.Material.Neon, metalness = 0, roughness = 0.5 },
		isAir = false,
		isLiquid = true,
		isSolid = false,
	},
	[8] = {
		id = 8,
		name = "Wood",
		displayName = "Wood",
		color = Color3.fromRGB(120, 70, 30),
		physical = { density = 0.8, hardness = 1, friction = 0.6 },
		render = { material = Enum.Material.Wood, metalness = 0, roughness = 0.7 },
		isAir = false,
		isLiquid = false,
		isSolid = true,
	},
	[9] = {
		id = 9,
		name = "Leaves",
		displayName = "Leaves",
		color = Color3.fromRGB(40, 150, 40),
		physical = { density = 0.3, hardness = 0.1, friction = 0.4 },
		render = { material = Enum.Material.Grass, metalness = 0, roughness = 0.9 },
		isAir = false,
		isLiquid = false,
		isSolid = true,
	},
	[10] = {
		id = 10,
		name = "StoneBrick",
		displayName = "Stone Brick",
		color = Color3.fromRGB(120, 120, 120),
		physical = { density = 2.0, hardness = 3, friction = 0.8 },
		render = { material = Enum.Material.Slate, metalness = 0, roughness = 0.6 },
		isAir = false,
		isLiquid = false,
		isSolid = true,
	},
} :: { [number]: VoxelMaterial }

function VoxelTypes.GetMaterial(id: number): VoxelMaterial
	return VoxelTypes.Materials[id] or VoxelTypes.Materials[0]
end

function VoxelTypes.GetMaterialByName(name: string): VoxelMaterial?
	for _, mat in VoxelTypes.Materials do
		if string.lower(mat.name) == string.lower(name) then
			return mat
		end
	end
	return nil
end

function VoxelTypes.IsSolid(id: number): boolean
	local mat = VoxelTypes.Materials[id]
	return mat and mat.isSolid or false
end

function VoxelTypes.IsAir(id: number): boolean
	return id == 0
end

function VoxelTypes.GetAllMaterials(): { VoxelMaterial }
	local list = {}
	for _, mat in VoxelTypes.Materials do
		table.insert(list, mat)
	end
	return list
end

function VoxelTypes.GetSolidMaterials(): { VoxelMaterial }
	local list = {}
	for _, mat in VoxelTypes.Materials do
		if mat.isSolid then table.insert(list, mat) end
	end
	return list
end

return VoxelTypes

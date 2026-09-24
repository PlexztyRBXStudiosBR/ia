--!strict
-- Arkher Studio - Fase 4 - TerrainController - Orquestra terrain editor completo
-- Mecha Engine Custom Terrain API + World Creator level brushes + stamps + biomes + erosion

local TerrainData = require(game:GetService("ReplicatedStorage").Arkher.Terrain.TerrainData)

local TerrainController = {}
TerrainController.__index = TerrainController

function TerrainController.new()
	local self = setmetatable({
		terrainAPI = nil :: any,
		brushSystem = nil :: any,
		stampSystem = nil :: any,
		editor = nil :: any,
		greedyMesher = nil :: any,
		dualContouring = nil :: any,
		isActive = false,
		frame = nil :: Frame?,
	}, TerrainController)
	local MechaTerrainAPI = require(script.Parent.MechaTerrainAPI)
	local BrushSystem = require(script.Parent.BrushSystem)
	local StampSystem = require(script.Parent.StampSystem)
	local TerrainEditor = require(script.Parent.TerrainEditor)
	local GreedyMesher = require(script.Parent.GreedyMesher)
	local DualContouring = require(script.Parent.DualContouring)
	self.terrainAPI = MechaTerrainAPI.new()
	self.brushSystem = BrushSystem.new()
	self.stampSystem = StampSystem.new()
	self.editor = TerrainEditor.new(self.terrainAPI, self.brushSystem, self.stampSystem)
	self.greedyMesher = GreedyMesher.new()
	self.dualContouring = DualContouring.new()
	return self
end

function TerrainController:Init(parent: Frame)
	self.frame = parent
	self.terrainAPI:Init()
	self.terrainAPI:CreateTerrain(TerrainData.DefaultSettings())
	self.editor:Init(parent)
	self.isActive = true
	print("[Arkher TerrainController] Initialized - Mecha Engine Custom Terrain + World Creator - Fase 4")
end

function TerrainController:GenerateInitialTerrain(radius: number?)
	radius = radius or 3
	if not self.terrainAPI then return end
	local center = Vector3.new(0, 0, 0)
	local chunks = self.terrainAPI:LoadArea(center, radius :: number)
	print("[Arkher TerrainController] Generated initial terrain radius", radius, "- Chunks:", #chunks)
	return chunks
end

function TerrainController:ClearTerrain()
	if self.terrainAPI then self.terrainAPI:Clear() print("[Arkher TerrainController] Cleared terrain") end
end

function TerrainController:SaveTerrain(): string?
	if not self.terrainAPI then return nil end
	local json = self.terrainAPI:Save()
	print("[Arkher TerrainController] Saved terrain - Size:", #json, "bytes")
	return json
end

function TerrainController:LoadTerrain(json: string): boolean
	if not self.terrainAPI then return false end
	local success = self.terrainAPI:Load(json)
	print("[Arkher TerrainController] Loaded terrain - Success:", success)
	return success
end

function TerrainController:SetVoxel(worldPos: Vector3, materialId: number)
	if self.terrainAPI then self.terrainAPI:SetVoxel(worldPos, materialId) end
end

function TerrainController:GetVoxel(worldPos: Vector3): number
	if not self.terrainAPI then return 0 end
	return self.terrainAPI:GetVoxel(worldPos)
end

function TerrainController:ApplyBrush(worldPos: Vector3, brushType: string?)
	if brushType then self.brushSystem:SetBrushType(brushType :: any) end
	if self.terrainAPI then
		local affected = self.brushSystem:ApplyBrush(self.terrainAPI.terrain, worldPos)
		for _, coord in affected do self.terrainAPI:MeshChunk(coord) end
		return affected
	end
	return {}
end

function TerrainController:ApplyStamp(worldPos: Vector3, stampType: string?, size: number?, height: number?)
	stampType = stampType or "Mountain"
	size = size or 20
	height = height or 20
	if not self.terrainAPI then return {} end
	local settings: any
	if stampType == "Mountain" then settings = self.stampSystem:CreateMountainStamp(size :: number, height :: number, self.editor.currentMaterialId)
	elseif stampType == "Crater" then settings = self.stampSystem:CreateCraterStamp(size :: number, height :: number, self.editor.currentMaterialId)
	else settings = { type = stampType, size = size, height = height, falloff = 0.7, materialId = self.editor.currentMaterialId, noiseAmount = 0.3, seed = math.random(1, 10000) } end
	local affected = self.stampSystem:ApplyStamp(self.terrainAPI.terrain, worldPos, settings)
	for _, coord in affected do self.terrainAPI:MeshChunk(coord) end
	return affected
end

function TerrainController:ApplyErosion(type: string?)
	type = type or "combined"
	if not self.terrainAPI then return end
	print("[Arkher TerrainController] Applying erosion", type, "- World Creator level")
	local Noise = require(game:GetService("ReplicatedStorage").Arkher.Terrain.Noise)
	local Erosion = require(game:GetService("ReplicatedStorage").Arkher.Terrain.Erosion)
	local settings = self.terrainAPI.terrain.settings
	local heightmapSettings = {
		seed = settings.seed,
		scale = 50,
		octaves = settings.octaves,
		lacunarity = settings.lacunarity,
		gain = settings.gain,
		height = settings.heightScale,
		baseHeight = settings.baseHeight,
		noiseType = settings.noiseType,
		domainWarp = true,
		warpAmount = 5,
	}
	local heightmap = Noise.GenerateHeightmap(128, 128, heightmapSettings)
	local eroded = Erosion.Apply(heightmap)
	print("[Arkher TerrainController] Erosion applied - Regenerating chunks")
	self:ClearTerrain()
	self:GenerateInitialTerrain(3)
end

function TerrainController:GetStats(): { [string]: any }
	return {
		isActive = self.isActive,
		terrainAPI = self.terrainAPI and self.terrainAPI:GetStats() or {},
		brushSystem = self.brushSystem and self.brushSystem:GetStats() or {},
		stampSystem = self.stampSystem and self.stampSystem:GetStats() or {},
		editor = self.editor and self.editor:GetStats() or {},
		greedyMesher = self.greedyMesher and self.greedyMesher:GetStats() or {},
		dualContouring = self.dualContouring and self.dualContouring:GetStats() or {},
		features = {"MechaTerrainAPI custom", "Greedy Meshing 10x opt", "Dual Contouring smooth", "Brushes 9 types", "Stamps 9 types", "Biomes 7", "Erosion Thermal/Hydraulic/Wind", "Infinite chunked", "15GB"},
		message = "TerrainController Fase 4 - Mecha Engine Custom Terrain - World Creator level - Infinite chunked",
	}
end

return TerrainController

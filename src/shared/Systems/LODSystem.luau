--!strict
-- Arkher Studio - Fase 1 - LODSystem - Level of Detail
-- Faz A01 rodar AAA com LOD automático

local Workspace = game:GetService("Workspace")

local LODSystem = {}
LODSystem.__index = LODSystem

function LODSystem.new(world: any, renderSystem: any)
	return setmetatable({
		world = world,
		renderSystem = renderSystem,
		enabled = true,
		distances = {
			high = 50,
			medium = 150,
			low = 300,
		},
		lastUpdate = 0,
		updateInterval = 0.5, -- atualiza LOD a cada 0.5s
	}, LODSystem)
end

function LODSystem:Update()
	if not self.enabled then return end

	local now = os.clock()
	if now - self.lastUpdate < self.updateInterval then return end
	self.lastUpdate = now

	local camera = Workspace.CurrentCamera
	if not camera then return end

	local camPos = camera.CFrame.Position

	for id, entity in self.world.entities do
		local transform = entity.components.Transform
		local render = entity.components.Render
		if transform and render then
			local dist = (transform.position - camPos).Magnitude
			local newLod = self:GetLODForDistance(dist)

			if render.lodLevel ~= newLod then
				render.lodLevel = newLod
				-- Atualiza visual se já materializado
				if self.renderSystem and self.renderSystem.materialized[id] then
					self.renderSystem:UpdateEntity(id)
				end
			end
		end
	end
end

function LODSystem:GetLODForDistance(dist: number): number
	if dist < self.distances.high then return 0 -- High
	elseif dist < self.distances.medium then return 1 -- Medium
	elseif dist < self.distances.low then return 2 -- Low
	else return 3 end -- Impostor
end

function LODSystem:SetDistances(high: number, medium: number, low: number)
	self.distances.high = high
	self.distances.medium = medium
	self.distances.low = low
	print("[Arkher LOD] Distances set - High:", high, "Med:", medium, "Low:", low)
end

function LODSystem:GetStats(): { [string]: any }
	local counts = { [0]=0, [1]=0, [2]=0, [3]=0 }
	for _, entity in self.world.entities do
		local render = entity.components.Render
		if render then
			counts[render.lodLevel] = (counts[render.lodLevel] or 0) + 1
		end
	end

	return {
		enabled = self.enabled,
		distances = self.distances,
		counts = counts,
	}
end

return LODSystem

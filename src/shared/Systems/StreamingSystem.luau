--!strict
-- Arkher Studio - Fase 1 - StreamingSystem - Só carrega o que está perto
-- Inspirado no World Creator + Minecraft - Mundo infinito

local Workspace = game:GetService("Workspace")

local StreamingSystem = {}
StreamingSystem.__index = StreamingSystem

function StreamingSystem.new(world: any, renderSystem: any)
	return setmetatable({
		world = world,
		renderSystem = renderSystem,
		enabled = true,
		radius = 500, -- só materializa dentro de 500 studs
		innerRadius = 300, -- dentro de 300 sempre carregado
		lastUpdate = 0,
		updateInterval = 1.0,
		streamed = {} :: { [string]: boolean },
	}, StreamingSystem)
end

function StreamingSystem:Update()
	if not self.enabled then return end

	local now = os.clock()
	if now - self.lastUpdate < self.updateInterval then return end
	self.lastUpdate = now

	local camera = Workspace.CurrentCamera
	if not camera then return end

	local camPos = camera.CFrame.Position

	for id, entity in self.world.entities do
		local transform = entity.components.Transform
		if transform then
			local dist = (transform.position - camPos).Magnitude
			local shouldStream = dist <= self.radius
			local wasStreamed = self.streamed[id] or false

			if shouldStream and not wasStreamed then
				-- Entrou no radius, materializa
				self.renderSystem:MaterializeEntity(entity)
				self.streamed[id] = true
			elseif not shouldStream and wasStreamed then
				-- Saiu do radius, dematerializa (stream out)
				local part = self.renderSystem.materialized[id]
				if part then
					part:Destroy()
					self.renderSystem.materialized[id] = nil
				end
				self.streamed[id] = false
			end
		end
	end
end

function StreamingSystem:SetRadius(radius: number)
	self.radius = radius
	print("[Arkher Streaming] Radius set to", radius)
end

function StreamingSystem:GetStats(): { [string]: any }
	local streamedCount = 0
	for _, v in self.streamed do
		if v then streamedCount += 1 end
	end

	return {
		enabled = self.enabled,
		radius = self.radius,
		totalEntities = self.world.entityCount,
		streamedCount = streamedCount,
		cullCount = self.world.entityCount - streamedCount,
	}
end

return StreamingSystem

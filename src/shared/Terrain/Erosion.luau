--!strict
-- Arkher Studio - Fase 4 - Erosion - World Creator level
-- Thermal + Hydraulic erosion - Inspiração World Creator + Unreal

local Erosion = {}

export type ErosionSettings = {
	thermalIterations: number,
	thermalTalus: number,
	hydraulicIterations: number,
	hydraulicRainfall: number,
	hydraulicEvaporation: number,
	hydraulicSedimentCapacity: number,
}

function Erosion.DefaultSettings(): ErosionSettings
	return {
		thermalIterations = 10,
		thermalTalus = 0.6,
		hydraulicIterations = 50,
		hydraulicRainfall = 0.01,
		hydraulicEvaporation = 0.02,
		hydraulicSedimentCapacity = 0.1,
	}
end

function Erosion.Thermal(heightmap: { { number } }, settings: ErosionSettings): { { number } }
	local width = #heightmap[1]
	local height = #heightmap
	local result: { { number } } = {}
	for y = 1, height do result[y] = {} for x = 1, width do result[y][x] = heightmap[y][x] end end
	for _ = 1, settings.thermalIterations do
		for y = 2, height - 1 do
			for x = 2, width - 1 do
				local current = result[y][x]
				local neighbors = {
					{ x = x - 1, y = y, h = result[y][x - 1] },
					{ x = x + 1, y = y, h = result[y][x + 1] },
					{ x = x, y = y - 1, h = result[y - 1][x] },
					{ x = x, y = y + 1, h = result[y + 1][x] },
				}
				for _, n in neighbors do
					local diff = current - n.h
					if diff > settings.thermalTalus then
						local transfer = (diff - settings.thermalTalus) * 0.5
						result[y][x] -= transfer
						result[n.y][n.x] += transfer
					end
				end
			end
		end
	end
	print("[Arkher Erosion] Thermal erosion - Iterations:", settings.thermalIterations)
	return result
end

function Erosion.Hydraulic(heightmap: { { number } }, settings: ErosionSettings): { { number } }
	local width = #heightmap[1]
	local height = #heightmap
	local result: { { number } } = {}
	local water: { { number } } = {}
	local sediment: { { number } } = {}
	for y = 1, height do result[y] = {} water[y] = {} sediment[y] = {} for x = 1, width do result[y][x] = heightmap[y][x] water[y][x] = 0 sediment[y][x] = 0 end end
	for _ = 1, settings.hydraulicIterations do
		for y = 1, height do for x = 1, width do water[y][x] += settings.hydraulicRainfall end end
		for y = 2, height - 1 do
			for x = 2, width - 1 do
				if water[y][x] > 0 then
					local lowestX, lowestY = x, y
					local lowestHeight = result[y][x] + water[y][x]
					for dy = -1, 1 do
						for dx = -1, 1 do
							if dx ~= 0 or dy ~= 0 then
								local nx, ny = x + dx, y + dy
								if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
									local h = result[ny][nx] + water[ny][nx]
									if h < lowestHeight then lowestHeight = h lowestX = nx lowestY = ny end
								end
							end
						end
					end
					if lowestX ~= x or lowestY ~= y then
						local flow = math.min(water[y][x] * 0.5, (result[y][x] + water[y][x] - lowestHeight) * 0.5)
						water[y][x] -= flow
						water[lowestY][lowestX] += flow
						local capacity = flow * settings.hydraulicSedimentCapacity
						if sediment[y][x] > capacity then
							local deposit = (sediment[y][x] - capacity) * 0.5
							sediment[y][x] -= deposit
							result[y][x] += deposit
						else
							local erode = math.min(capacity - sediment[y][x], result[y][x] * 0.01)
							result[y][x] -= erode
							sediment[y][x] += erode
						end
						sediment[lowestY][lowestX] += sediment[y][x] * 0.5
						sediment[y][x] *= 0.5
					end
				end
			end
		end
		for y = 1, height do
			for x = 1, width do
				water[y][x] *= (1 - settings.hydraulicEvaporation)
				if water[y][x] < 0.001 then result[y][x] += sediment[y][x] sediment[y][x] = 0 water[y][x] = 0 end
			end
		end
	end
	print("[Arkher Erosion] Hydraulic erosion - Iterations:", settings.hydraulicIterations)
	return result
end

function Erosion.Apply(heightmap: { { number } }, settings: ErosionSettings?): { { number } }
	settings = settings or Erosion.DefaultSettings()
	print("[Arkher Erosion] Applying combined erosion - World Creator style")
	local afterThermal = Erosion.Thermal(heightmap, settings :: ErosionSettings)
	local afterHydraulic = Erosion.Hydraulic(afterThermal, settings :: ErosionSettings)
	print("[Arkher Erosion] Combined erosion done")
	return afterHydraulic
end

function Erosion.Wind(heightmap: { { number } }, windDir: Vector2, strength: number): { { number } }
	local width = #heightmap[1]
	local height = #heightmap
	local result: { { number } } = {}
	for y = 1, height do result[y] = {} for x = 1, width do result[y][x] = heightmap[y][x] end end
	local dirX = windDir.X
	local dirY = windDir.Y
	local len = math.sqrt(dirX*dirX + dirY*dirY)
	if len > 0 then dirX /= len dirY /= len end
	for y = 2, height - 1 do
		for x = 2, width - 1 do
			local wx = math.floor(x - dirX * 2)
			local wy = math.floor(y - dirY * 2)
			if wx >= 1 and wx <= width and wy >= 1 and wy <= height then
				local windwardHeight = heightmap[wy][wx]
				local current = heightmap[y][x]
				if windwardHeight < current then result[y][x] -= strength * 0.1 else result[y][x] += strength * 0.05 end
			end
		end
	end
	print("[Arkher Erosion] Wind erosion - Dir:", windDir, "Strength:", strength)
	return result
end

function Erosion.GetStats(): { [string]: any }
	return {
		types = {"Thermal", "Hydraulic", "Wind", "Combined"},
		inspiration = "World Creator - Thermal talus + Hydraulic flow + Wind",
		message = "Erosion Fase 4 - World Creator level - Thermal + Hydraulic + Wind"
	}
end

return Erosion

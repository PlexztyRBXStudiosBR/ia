--!strict
-- Arkher Studio - Fase 4 - Noise - World Creator level procedural
-- Perlin, FBM, Ridged, Voronoi, Domain Warp - Inspiração World Creator + Unreal

local Noise = {}

local perm = {}
for i = 0, 255 do perm[i] = i end
local seed = 1337
for i = 255, 0, -1 do
	seed = (seed * 1103515245 + 12345) % 2147483648
	local j = seed % (i + 1)
	perm[i], perm[j] = perm[j], perm[i]
end
for i = 0, 255 do perm[256 + i] = perm[i] end

local function fade(t: number): number
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function lerp(a: number, b: number, t: number): number
	return a + t * (b - a)
end

local function grad(hash: number, x: number, y: number, z: number): number
	local h = hash % 16
	local u = h < 8 and x or y
	local v = h < 4 and y or (h == 12 or h == 14) and x or z
	return ((h % 2 == 0) and u or -u) + ((h % 3 == 0) and v or -v)
end

function Noise.Perlin(x: number, y: number, z: number): number
	local X = math.floor(x) % 256
	local Y = math.floor(y) % 256
	local Z = math.floor(z) % 256
	x -= math.floor(x)
	y -= math.floor(y)
	z -= math.floor(z)
	local u = fade(x)
	local v = fade(y)
	local w = fade(z)
	local A = perm[X] + Y
	local AA = perm[A] + Z
	local AB = perm[A + 1] + Z
	local B = perm[X + 1] + Y
	local BA = perm[B] + Z
	local BB = perm[B + 1] + Z
	local res = lerp(
		lerp(
			lerp(grad(perm[AA], x, y, z), grad(perm[BA], x-1, y, z), u),
			lerp(grad(perm[AB], x, y-1, z), grad(perm[BB], x-1, y-1, z), u),
			v
		),
		lerp(
			lerp(grad(perm[AA+1], x, y, z-1), grad(perm[BA+1], x-1, y, z-1), u),
			lerp(grad(perm[AB+1], x, y-1, z-1), grad(perm[BB+1], x-1, y-1, z-1), u),
			v
		),
		w
	)
	return res
end

function Noise.Perlin2D(x: number, y: number): number
	return Noise.Perlin(x, y, 0)
end

function Noise.FBM(x: number, y: number, z: number, octaves: number?, lacunarity: number?, gain: number?, seedOffset: number?): number
	octaves = octaves or 5
	lacunarity = lacunarity or 2.0
	gain = gain or 0.5
	seedOffset = seedOffset or 0
	local value = 0
	local amplitude = 1
	local frequency = 1
	local maxValue = 0
	for _ = 1, octaves :: number do
		value += Noise.Perlin(x * frequency + (seedOffset :: number), y * frequency, z * frequency) * amplitude
		maxValue += amplitude
		amplitude *= (gain :: number)
		frequency *= (lacunarity :: number)
	end
	return value / maxValue
end

function Noise.FBM2D(x: number, y: number, octaves: number?, lacunarity: number?, gain: number?): number
	return Noise.FBM(x, y, 0, octaves, lacunarity, gain)
end

function Noise.Ridged(x: number, y: number, z: number, octaves: number?, lacunarity: number?, gain: number?): number
	octaves = octaves or 5
	lacunarity = lacunarity or 2.0
	gain = gain or 0.5
	local value = 0
	local amplitude = 1
	local frequency = 1
	local maxValue = 0
	for _ = 1, octaves :: number do
		local n = 1 - math.abs(Noise.Perlin(x * frequency, y * frequency, z * frequency))
		n = n * n
		value += n * amplitude
		maxValue += amplitude
		amplitude *= (gain :: number)
		frequency *= (lacunarity :: number)
	end
	return value / maxValue
end

function Noise.Ridged2D(x: number, y: number, octaves: number?): number
	return Noise.Ridged(x, y, 0, octaves)
end

function Noise.Billow(x: number, y: number, z: number, octaves: number?): number
	octaves = octaves or 5
	local value = 0
	local amp = 1
	local freq = 1
	local max = 0
	for _ = 1, octaves :: number do
		value += math.abs(Noise.Perlin(x * freq, y * freq, z * freq)) * amp
		max += amp
		amp *= 0.5
		freq *= 2
	end
	return value / max
end

function Noise.Voronoi(x: number, y: number, z: number, cellSize: number?): number
	cellSize = cellSize or 10
	local cellX = math.floor(x / (cellSize :: number))
	local cellY = math.floor(y / (cellSize :: number))
	local cellZ = math.floor(z / (cellSize :: number))
	local minDist = math.huge
	for dz = -1, 1 do
		for dy = -1, 1 do
			for dx = -1, 1 do
				local cx = cellX + dx
				local cy = cellY + dy
				local cz = cellZ + dz
				local hash = (cx * 73856093 + cy * 19349663 + cz * 83492791) % 1000
				local px = cx * (cellSize :: number) + (hash % 100) / 100 * (cellSize :: number)
				local py = cy * (cellSize :: number) + ((hash * 2) % 100) / 100 * (cellSize :: number)
				local pz = cz * (cellSize :: number) + ((hash * 3) % 100) / 100 * (cellSize :: number)
				local dist = (x - px)^2 + (y - py)^2 + (z - pz)^2
				if dist < minDist then minDist = dist end
			end
		end
	end
	return math.sqrt(minDist) / (cellSize :: number)
end

function Noise.DomainWarp(x: number, y: number, z: number, warpAmount: number?): (number, number, number)
	warpAmount = warpAmount or 5
	local wx = Noise.Perlin(x * 0.05, y * 0.05, z * 0.05) * (warpAmount :: number)
	local wy = Noise.Perlin(x * 0.05 + 100, y * 0.05 + 100, z * 0.05) * (warpAmount :: number)
	local wz = Noise.Perlin(x * 0.05 + 200, y * 0.05 + 200, z * 0.05) * (warpAmount :: number)
	return x + wx, y + wy, z + wz
end

export type HeightmapSettings = {
	seed: number,
	scale: number,
	octaves: number,
	lacunarity: number,
	gain: number,
	height: number,
	baseHeight: number,
	noiseType: string,
	domainWarp: boolean,
	warpAmount: number?,
}

function Noise.GenerateHeightmap(width: number, height: number, settings: HeightmapSettings): { { number } }
	local map: { { number } } = {}
	for y = 1, height do
		map[y] = {}
		for x = 1, width do
			local nx = (x / width - 0.5) * settings.scale
			local ny = (y / height - 0.5) * settings.scale
			if settings.domainWarp then
				nx, ny = Noise.DomainWarp(nx, ny, 0, settings.warpAmount or 5)
				nx = (nx :: number)
				ny = (ny :: number)
			end
			local value: number
			if settings.noiseType == "ridged" then
				value = Noise.Ridged2D(nx, ny, settings.octaves)
			elseif settings.noiseType == "billow" then
				value = Noise.Billow(nx, ny, 0, settings.octaves)
			elseif settings.noiseType == "voronoi" then
				value = 1 - Noise.Voronoi(nx, ny, 0, settings.scale / 10)
			else
				value = Noise.FBM2D(nx, ny, settings.octaves, settings.lacunarity, settings.gain)
			end
			value = (value + 1) / 2
			value = value * settings.height + settings.baseHeight
			map[y][x] = value
		end
	end
	print("[Arkher Noise] Generated heightmap", width, "x", height, "- Type:", settings.noiseType)
	return map
end

function Noise.BlendHeightmaps(a: { { number } }, b: { { number } }, t: number): { { number } }
	local result: { { number } } = {}
	for y, row in a do
		result[y] = {}
		for x, val in row do
			local bVal = b[y] and b[y][x] or 0
			result[y][x] = val * (1 - t) + bVal * t
		end
	end
	return result
end

function Noise.GetStats(): { [string]: any }
	return {
		types = {"Perlin", "FBM", "Ridged", "Billow", "Voronoi", "DomainWarp"},
		features = {"Heightmap generation", "Blend", "World Creator style", "Infinite terrain", "Seedable"},
		message = "Noise Fase 4 - World Creator level - Perlin + FBM + Ridged + Voronoi + Domain Warp"
	}
end

return Noise

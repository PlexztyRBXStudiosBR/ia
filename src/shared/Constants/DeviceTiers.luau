--!strict
-- Arkher Studio - Device Tiers
-- Detecta dispositivo e adapta DLSS + LOD + Qualidade

local DeviceTiers = {}

export type DeviceInfo = {
	tier: string,
	name: string,
	ramMB: number,
	cpuCores: number,
	supportsParallel: boolean,
	maxTextureSize: number,
	targetFPS: number,
	angPreset: string,
}

function DeviceTiers.Detect(): DeviceInfo
	local isMobile = false
	local isConsole = false
	local isVR = false

	-- Detecção básica (vamos melhorar com UserInputService + Stats)
	pcall(function()
		local UIS = game:GetService("UserInputService")
		isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
		isConsole = UIS.GamepadEnabled and not UIS.TouchEnabled and not UIS.KeyboardEnabled
		isVR = game:GetService("VRService").VREnabled
	end)

	if isVR then
		return {
			tier = "tier6_vr",
			name = "VR Headset",
			ramMB = 6000,
			cpuCores = 8,
			supportsParallel = true,
			maxTextureSize = 2048,
			targetFPS = 90,
			angPreset = "vr_performance",
		}
	end

	if isConsole then
		return {
			tier = "tier4_pc",
			name = "Console",
			ramMB = 8000,
			cpuCores = 8,
			supportsParallel = true,
			maxTextureSize = 2048,
			targetFPS = 60,
			angPreset = "console_balanced",
		}
	end

	if isMobile then
		-- Heurística simples: se tem pouca memória, é A01
		local mem = 2000 -- default
		pcall(function()
			mem = game:GetService("Stats"):GetTotalMemoryUsageMb()
		end)

		if mem < 2500 then
			return {
				tier = "tier1_a01",
				name = "Low-End Mobile (A01)",
				ramMB = 2000,
				cpuCores = 4,
				supportsParallel = false,
				maxTextureSize = 512,
				targetFPS = 30,
				angPreset = "ultra_performance", -- DLSS máximo pra compensar
			}
		else
			return {
				tier = "tier3_flagship",
				name = "Flagship Mobile",
				ramMB = 6000,
				cpuCores = 8,
				supportsParallel = true,
				maxTextureSize = 1024,
				targetFPS = 60,
				angPreset = "balanced",
			}
		end
	end

	-- PC
	return {
		tier = "tier5_gamer",
		name = "PC Gamer",
		ramMB = 16000,
		cpuCores = 12,
		supportsParallel = true,
		maxTextureSize = 4096,
		targetFPS = 120,
		angPreset = "quality",
	}
end

function DeviceTiers.GetANGSettings(tier: string, styleProfile: string): { [string]: any }
	-- Retorna config do Arkher Neural Graphics baseado no device + estilo
	if tier == "tier1_a01" then
		return {
			superResolution = true,
			renderScale = 0.5, -- renderiza em 50% e upscale pra 100%
			frameGeneration = true, -- dobra FPS
			styleEnhancer = true,
			textureSuperRes = styleProfile == "photorealistic" or styleProfile == "ultrarealistic",
		}
	elseif tier == "tier5_gamer" then
		return {
			superResolution = false, -- já tem poder, não precisa
			renderScale = 1.0,
			frameGeneration = false,
			styleEnhancer = true, -- mas ainda melhora qualidade
			textureSuperRes = true,
			rayReconstruction = true,
		}
	else
		return {
			superResolution = true,
			renderScale = 0.7,
			frameGeneration = true,
			styleEnhancer = true,
		}
	end
end

return DeviceTiers

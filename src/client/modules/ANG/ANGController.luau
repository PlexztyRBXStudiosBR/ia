--!strict
-- Arkher Studio - ANG Controller - Controla todo o pipeline DLSS 4+5 adaptativo
-- O coração que faz A01 criar AAA

local SuperResolution = require(script.Parent.SuperResolution)
local StyleEnhancer = require(script.Parent.StyleEnhancer)
local FrameGen = require(script.Parent.FrameGen)
local DeviceTiers = require(game.ReplicatedStorage.Arkher.Constants.DeviceTiers)
local StyleProfiles = require(game.ReplicatedStorage.Arkher.Constants.StyleProfiles)

local ANGController = {}
ANGController.__index = ANGController

function ANGController.new(styleProfile: string?)
	local deviceInfo = DeviceTiers.Detect()
	local profile = styleProfile or "realistic"

	local optimalScale = SuperResolution.GetOptimalScale(deviceInfo.tier, profile)
	local angSettings = DeviceTiers.GetANGSettings(deviceInfo.tier, profile)

	print(string.format("[ANG Controller] Device: %s (%s) | Style: %s | Render Scale: %.0f%%", deviceInfo.name, deviceInfo.tier, profile, optimalScale*100))

	local self = setmetatable({
		deviceInfo = deviceInfo,
		styleProfile = profile,
		superRes = SuperResolution.new({
			renderScale = optimalScale,
			sharpening = 0.5,
			antiGhosting = true,
			preserveEdges = true,
			targetResolution = Vector2.new(1920, 1080),
		}),
		styleEnhancer = StyleEnhancer.new({
			styleProfile = profile,
			textureSuperRes = angSettings.textureSuperRes,
			rayReconstruction = angSettings.rayReconstruction,
			neuralMaterial = profile == "photorealistic",
			toonEnhancer = profile == "anime",
		}),
		frameGen = FrameGen.new(),
		enabled = true,
		stats = {
			fps = 0,
			frameTime = 0,
			upscaleTime = 0,
		},
	}, ANGController)

	-- Configura baseado no device
	if angSettings.frameGeneration then
		self.frameGen:Enable()
	else
		self.frameGen:Disable()
	end

	return self
end

function ANGController:SetStyleProfile(profile: string)
	self.styleProfile = profile
	self.styleEnhancer:SetStyleProfile(profile)

	-- Re-otimiza render scale
	local optimalScale = SuperResolution.GetOptimalScale(self.deviceInfo.tier, profile)
	self.superRes:SetRenderScale(optimalScale)

	print("[ANG Controller] Style changed to", profile, "- Re-optimized pipeline")
end

function ANGController:ProcessFrame(lowResFrame: any, motionVectors: any?): any
	if not self.enabled then
		return lowResFrame
	end

	local start = os.clock()

	-- Pipeline completo DLSS 4+5
	-- 1. Super Resolution (DLSS 4 - Performance)
	local upscaled = self.superRes:Upscale(lowResFrame, motionVectors)

	-- 2. Style Enhancer (DLSS 5 - Quality)
	local enhanced = self.styleEnhancer:Enhance(upscaled)

	-- 3. Frame Generation (se FPS baixo)
	local currentFPS = self.stats.fps
	if self.frameGen:ShouldGenerate(currentFPS, 60) then
		-- Gera frame intermediário
		-- enhanced = self.frameGen:GenerateInterpolatedFrame(prevFrame, enhanced)
	end

	self.stats.upscaleTime = (os.clock() - start) * 1000

	return enhanced
end

function ANGController:GetStats(): { [string]: any }
	return {
		device = self.deviceInfo.name,
		tier = self.deviceInfo.tier,
		styleProfile = self.styleProfile,
		superRes = self.superRes:GetPerformanceStats(),
		frameGen = self.frameGen:GetStats(),
		upscaleTimeMs = self.stats.upscaleTime,
		enabled = self.enabled,
		message = string.format("ANG Active - %s on %s - %.0f%% render scale = %.0f%% FPS boost", self.styleProfile, self.deviceInfo.name, self.superRes.config.renderScale*100, self.superRes:GetPerformanceStats().performanceGain),
	}
end

function ANGController:Enable()
	self.enabled = true
	self.superRes:Enable()
	self.frameGen:Enable()
	print("[ANG Controller] Fully enabled")
end

function ANGController:Disable()
	self.enabled = false
	self.superRes:Disable()
	self.frameGen:Disable()
	print("[ANG Controller] Fully disabled")
end

return ANGController

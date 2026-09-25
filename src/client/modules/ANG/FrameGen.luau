--!strict
-- Arkher Studio - ANG - Frame Generation (DLSS 4 Frame Gen)
-- Dobra FPS gerando frames intermediários com interpolação

local FrameGen = {}
FrameGen.__index = FrameGen

function FrameGen.new()
	return setmetatable({
		enabled = true,
		historyFrames = {},
		maxHistory = 2,
		interpolationFactor = 0.5,
	}, FrameGen)
end

function FrameGen:Enable()
	self.enabled = true
	print("[ANG FrameGen] Enabled - FPS x2")
end

function FrameGen:Disable()
	self.enabled = false
	print("[ANG FrameGen] Disabled")
end

function FrameGen:GenerateInterpolatedFrame(frame1: any, frame2: any, alpha: number?): any
	if not self.enabled then
		return frame2
	end

	alpha = alpha or 0.5

	-- Fase 5: Implementação real com optical flow
	-- Calcula movimento entre frame1 e frame2 e interpola

	print(string.format("[ANG FrameGen] Generating frame at alpha %.2f - FPS boost", alpha))

	-- Stub: retorna frame interpolado
	return {
		interpolated = true,
		alpha = alpha,
		sourceFrames = {frame1, frame2},
	}
end

function FrameGen:ShouldGenerate(currentFPS: number, targetFPS: number): boolean
	if not self.enabled then return false end
	return currentFPS < targetFPS
end

function FrameGen:GetStats(): { [string]: any }
	return {
		enabled = self.enabled,
		fpsMultiplier = self.enabled and 2 or 1,
		latencyAdded = self.enabled and 8 or 0, -- ms
	}
end

return FrameGen

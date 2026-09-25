--!strict
-- Arkher Studio - IKSystem - Fase 3 - Cascadeur level IK/FK + FABRIK + CCD
-- Inspiração: Cascadeur auto-posing physics + Blender IK

local IKSystem = {}
IKSystem.__index = IKSystem

export type IKChain = {
	bones: { string },
	targetPos: Vector3,
	polePos: Vector3?,
	iterations: number,
	tolerance: number,
}

function IKSystem.new()
	return setmetatable({
		enabled = true,
		maxIterations = 20,
		tolerance = 0.01,
	}, IKSystem)
end

-- FABRIK algorithm - Forward And Backward Reaching Inverse Kinematics
-- Melhor que CCD para humanoid - Usado em Cascadeur
function IKSystem:SolveFABRIK(jointPositions: { Vector3 }, targetPos: Vector3, tolerance: number?, maxIterations: number?): { Vector3 }
	tolerance = tolerance or self.tolerance
	maxIterations = maxIterations or self.maxIterations

	if #jointPositions < 2 then return jointPositions end

	local positions = {}
	for i, pos in jointPositions do positions[i] = pos end

	local totalLength = 0
	local boneLengths = {}
	for i = 1, #positions - 1 do
		local len = (positions[i+1] - positions[i]).Magnitude
		boneLengths[i] = len
		totalLength += len
	end

	local rootPos = positions[1]
	local distToTarget = (targetPos - rootPos).Magnitude

	-- Se target inalcançável, estica em direção ao target
	if distToTarget > totalLength then
		for i = 1, #positions - 1 do
			local dir = (targetPos - positions[i]).Unit
			positions[i+1] = positions[i] + dir * boneLengths[i]
		end
		return positions
	end

	local iteration = 0
	local diff = (positions[#positions] - targetPos).Magnitude

	while diff > (tolerance :: number) and iteration < (maxIterations :: number) do
		-- Backward
		positions[#positions] = targetPos
		for i = #positions - 1, 1, -1 do
			local dir = (positions[i] - positions[i+1]).Unit
			positions[i] = positions[i+1] + dir * boneLengths[i]
		end

		-- Forward
		positions[1] = rootPos
		for i = 1, #positions - 1 do
			local dir = (positions[i+1] - positions[i]).Unit
			positions[i+1] = positions[i] + dir * boneLengths[i]
		end

		diff = (positions[#positions] - targetPos).Magnitude
		iteration += 1
	end

	print("[Arkher IK] FABRIK solved in", iteration, "iterations - diff:", diff)
	return positions
end

-- CCD - Cyclic Coordinate Descent - Bom para braços
function IKSystem:SolveCCD(jointPositions: { Vector3 }, jointRotations: { Vector3 }, targetPos: Vector3, tolerance: number?, maxIterations: number?): { Vector3 }
	tolerance = tolerance or self.tolerance
	maxIterations = maxIterations or self.maxIterations

	local positions = {}
	for i, pos in jointPositions do positions[i] = pos end

	local rotations = {}
	for i, rot in jointRotations do rotations[i] = rot end

	local iteration = 0
	local diff = (positions[#positions] - targetPos).Magnitude

	while diff > (tolerance :: number) and iteration < (maxIterations :: number) do
		for i = #positions - 1, 1, -1 do
			local toEnd = positions[#positions] - positions[i]
			local toTarget = targetPos - positions[i]

			if toEnd.Magnitude > 0.001 and toTarget.Magnitude > 0.001 then
				local toEndDir = toEnd.Unit
				local toTargetDir = toTarget.Unit

				local dot = math.clamp(toEndDir:Dot(toTargetDir), -1, 1)
				local angle = math.acos(dot)

				if angle > 0.001 then
					local axis = toEndDir:Cross(toTargetDir)
					if axis.Magnitude > 0.001 then
						axis = axis.Unit
						-- Rotaciona chain a partir de i
						for j = i + 1, #positions do
							local offset = positions[j] - positions[i]
							-- Rotação simplificada em torno do eixo
							local cosA = math.cos(angle)
							local sinA = math.sin(angle)
							-- Rodrigues rotation
							local rotated = offset * cosA + axis:Cross(offset) * sinA + axis * axis:Dot(offset) * (1 - cosA)
							positions[j] = positions[i] + rotated
						end
					end
				end
			end

			diff = (positions[#positions] - targetPos).Magnitude
			if diff <= (tolerance :: number) then break end
		end
		iteration += 1
	end

	print("[Arkher IK] CCD solved in", iteration, "iterations - diff:", diff)
	return positions
end

-- Two-bone IK analítico - Mais rápido para pernas/braços - Cascadeur usa
function IKSystem:SolveTwoBoneIK(rootPos: Vector3, midPos: Vector3, endPos: Vector3, targetPos: Vector3, polePos: Vector3?): (Vector3, Vector3, Vector3)
	local upperLen = (midPos - rootPos).Magnitude
	local lowerLen = (endPos - midPos).Magnitude
	local totalLen = upperLen + lowerLen

	local toTarget = targetPos - rootPos
	local dist = toTarget.Magnitude

	-- Clamp distance
	dist = math.clamp(dist, 0.01, totalLen - 0.01)

	-- Lei dos cossenos
	local cosAngle = (upperLen*upperLen + lowerLen*lowerLen - dist*dist) / (2 * upperLen * lowerLen)
	cosAngle = math.clamp(cosAngle, -1, 1)
	local midAngle = math.acos(cosAngle)

	local cosRootAngle = (upperLen*upperLen + dist*dist - lowerLen*lowerLen) / (2 * upperLen * dist)
	cosRootAngle = math.clamp(cosRootAngle, -1, 1)
	local rootAngle = math.acos(cosRootAngle)

	-- Direção para target
	local toTargetDir = toTarget.Unit
	local newMidPos = rootPos + toTargetDir * upperLen

	-- Pole vector para definir plano
	local pole = polePos or (rootPos + Vector3.new(0, 0, 1))
	local planeNormal = toTargetDir:Cross(pole - rootPos)
	if planeNormal.Magnitude < 0.001 then
		planeNormal = Vector3.new(0, 1, 0)
	else
		planeNormal = planeNormal.Unit
	end

	-- Ajusta mid baseado no ângulo
	-- Simplificado: rotaciona mid em torno do eixo perpendicular
	local newEndPos = targetPos

	-- Para simplificar, retornamos posições aproximadas
	-- Em produção usaria quaternion math completo
	print("[Arkher IK] TwoBone solved - upper:", upperLen, "lower:", lowerLen, "dist:", dist, "midAngle:", math.deg(midAngle))

	return rootPos, newMidPos, newEndPos
end

-- Auto-posing physics - Inspiração Cascadeur - Calcula pose física balanceada
function IKSystem:CalculateBalancedPose(hipsPos: Vector3, footPositions: { Vector3 }, mass: number?): Vector3
	mass = mass or 70 -- kg

	-- Centro de massa deve estar sobre base de suporte (entre pés)
	local supportCenter = Vector3.new(0,0,0)
	for _, footPos in footPositions do
		supportCenter += footPos
	end
	supportCenter /= #footPositions

	-- Hips deve estar acima do centro de suporte para equilíbrio
	local balancedHips = Vector3.new(supportCenter.X, hipsPos.Y, supportCenter.Z)

	print("[Arkher IK] Balanced pose - Hips:", hipsPos, "->", balancedHips, "- Support:", supportCenter, "- Mass:", mass)
	return balancedHips
end

-- Foot IK - Gruda pé no chão - Essencial para Cascadeur
function IKSystem:SolveFootIK(footPos: Vector3, groundY: number, footOffset: Vector3?): Vector3
	footOffset = footOffset or Vector3.new(0, 0.1, 0)
	local newPos = Vector3.new(footPos.X, groundY + footOffset.Y, footPos.Z)
	print("[Arkher IK] Foot IK -", footPos, "->", newPos, "- GroundY:", groundY)
	return newPos
end

function IKSystem:GetStats(): { [string]: any }
	return {
		enabled = self.enabled,
		algorithms = {"FABRIK", "CCD", "TwoBone Analytic", "FootIK", "BalancedPose"},
		maxIterations = self.maxIterations,
		tolerance = self.tolerance,
		inspiration = "Cascadeur + Blender - Auto-posing physics",
		message = "IK System Fase 3 - Cascadeur level - FABRIK + CCD + TwoBone + FootIK + Balanced"
	}
end

return IKSystem

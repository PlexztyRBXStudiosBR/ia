--!strict
-- Arkher Studio - PhysicsAnimator - Fase 3 - Cascadeur physics animation
-- Inspiração: Cascadeur auto-physics, secondary motion, trajectory

local PhysicsAnimator = {}
PhysicsAnimator.__index = PhysicsAnimator

export type TrajectoryPoint = {
	position: Vector3,
	velocity: Vector3,
	time: number,
}

export type PhysicsSettings = {
	gravity: Vector3,
	mass: number,
	drag: number,
	elasticity: number,
	secondaryMotion: boolean,
	autoBalance: boolean,
}

function PhysicsAnimator.new()
	return setmetatable({
		gravity = Vector3.new(0, -9.81, 0),
		defaultMass = 70,
		drag = 0.1,
		elasticity = 0.3,
		secondaryMotionEnabled = true,
		autoBalanceEnabled = true,
		trajectories = {} :: { [string]: { TrajectoryPoint } },
	}, PhysicsAnimator)
end

-- Calcula trajetória balística - Cascadeur mostra trajetória
function PhysicsAnimator:CalculateTrajectory(startPos: Vector3, velocity: Vector3, time: number, steps: number?): { TrajectoryPoint }
	steps = steps or 20
	local points: { TrajectoryPoint } = {}

	for i = 0, steps :: number do
		local t = (i / (steps :: number)) * time
		-- s = s0 + v0*t + 0.5*g*t²
		local pos = startPos + velocity * t + self.gravity * (0.5 * t * t)
		local vel = velocity + self.gravity * t
		table.insert(points, {
			position = pos,
			velocity = vel,
			time = t,
		})
	end

	print("[Arkher PhysicsAnim] Trajectory - Start:", startPos, "Vel:", velocity, "Time:", time, "Steps:", steps)
	return points
end

-- Secondary motion - Cabelo, roupa, etc balança com física - Cascadeur
function PhysicsAnimator:CalculateSecondaryMotion(primaryPositions: { Vector3 }, stiffness: number?, damping: number?): { Vector3 }
	stiffness = stiffness or 0.5
	damping = damping or 0.3

	local secondary: { Vector3 } = {}
	local prevVelocity = Vector3.new(0,0,0)

	for i, pos in primaryPositions do
		if i == 1 then
			secondary[i] = pos
		else
			local delta = pos - primaryPositions[i-1]
			local velocity = delta -- simplificado, deveria ser delta / dt

			-- Spring-damper
			local target = pos
			local current = secondary[i-1]
			local toTarget = target - current

			local springForce = toTarget * (stiffness :: number)
			local dampingForce = (velocity - prevVelocity) * (damping :: number)

			local newPos = current + springForce - dampingForce
			secondary[i] = newPos
			prevVelocity = velocity
		end
	end

	print("[Arkher PhysicsAnim] Secondary motion -", #primaryPositions, "points - Stiffness:", stiffness, "Damping:", damping)
	return secondary
end

-- Auto balance - Cascadeur mantém personagem equilibrado
function PhysicsAnimator:CalculateCenterOfMass(bonePositions: { [string]: Vector3 }, boneMasses: { [string]: number }?): Vector3
	boneMasses = boneMasses or {}

	local totalMass = 0
	local weightedPos = Vector3.new(0,0,0)

	for boneId, pos in bonePositions do
		local mass = boneMasses[boneId] or self.defaultMass / 20 -- média por bone
		weightedPos += pos * mass
		totalMass += mass
	end

	if totalMass == 0 then return Vector3.new(0,0,0) end

	local com = weightedPos / totalMass
	print("[Arkher PhysicsAnim] Center of Mass:", com, "- Total mass:", totalMass)
	return com
end

function PhysicsAnimator:IsBalanced(com: Vector3, supportPolygon: { Vector3 }): boolean
	-- Verifica se COM está dentro do polígono de suporte (pés)
	-- Simplificado: bounding box check
	if #supportPolygon < 3 then return false end

	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge

	for _, p in supportPolygon do
		minX = math.min(minX, p.X)
		maxX = math.max(maxX, p.X)
		minZ = math.min(minZ, p.Z)
		maxZ = math.max(maxZ, p.Z)
	end

	local balanced = com.X >= minX and com.X <= maxX and com.Z >= minZ and com.Z <= maxZ
	print("[Arkher PhysicsAnim] Balanced check - COM:", com, "Support:", supportPolygon, "->", balanced)
	return balanced
end

-- Interpolation com física - Ease in/out físico, não linear
function PhysicsAnimator:PhysicsInterpolation(startPos: Vector3, endPos: Vector3, t: number, easeType: string?): Vector3
	easeType = easeType or "easeInOutCubic"

	if easeType == "linear" then
		return startPos:Lerp(endPos, t)
	elseif easeType == "easeInQuad" then
		return startPos:Lerp(endPos, t*t)
	elseif easeType == "easeOutQuad" then
		return startPos:Lerp(endPos, 1 - (1-t)*(1-t))
	elseif easeType == "easeInOutCubic" then
		local eased = t < 0.5 and 4*t*t*t or 1 - (-2*t + 2)^3 / 2
		return startPos:Lerp(endPos, eased)
	elseif easeType == "spring" then
		-- Spring interpolation - Cascadeur style
		local omega = 8 -- frequência
		local zeta = 0.5 -- amortecimento
		local exp = math.exp(-zeta * omega * t)
		local cos = math.cos(omega * math.sqrt(1 - zeta*zeta) * t)
		local eased = 1 - exp * cos
		return startPos:Lerp(endPos, eased)
	else
		return startPos:Lerp(endPos, t)
	end
end

-- Ground contact - Detecta quando pé toca chão e ajusta
function PhysicsAnimator:DetectGroundContact(footPos: Vector3, groundY: number, threshold: number?): boolean
	threshold = threshold or 0.1
	local contact = math.abs(footPos.Y - groundY) <= (threshold :: number)
	if contact then
		print("[Arkher PhysicsAnim] Ground contact - Foot:", footPos, "Ground:", groundY)
	end
	return contact
end

function PhysicsAnimator:GetStats(): { [string]: any }
	return {
		gravity = self.gravity,
		defaultMass = self.defaultMass,
		drag = self.drag,
		elasticity = self.elasticity,
		secondaryMotion = self.secondaryMotionEnabled,
		autoBalance = self.autoBalanceEnabled,
		features = {"Trajectory", "SecondaryMotion", "CenterOfMass", "BalancedCheck", "PhysicsInterpolation", "GroundContact"},
		inspiration = "Cascadeur - Auto-physics, secondary motion, trajectory visualization",
		message = "PhysicsAnimator Fase 3 - Cascadeur physics - Trajectory + Secondary + Balance + Spring interpolation"
	}
end

return PhysicsAnimator

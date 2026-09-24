--!strict
-- Arkher Studio - RigData - Fase 3 - Cascadeur level rig
-- Dados de rig humanoide + quadrupede + custom - Inspiração Cascadeur + Blender

local RigData = {}
RigData.__index = RigData

export type Bone = {
	id: string,
	name: string,
	parentId: string?,
	length: number,
	position: Vector3,
	rotation: Vector3,
	children: { string },
	isIK: boolean,
	ikChainLength: number,
	constraints: {
		minAngle: Vector3?,
		maxAngle: Vector3?,
	},
}

export type Rig = {
	id: string,
	name: string,
	bones: { [string]: Bone },
	rootBoneId: string,
	type: string, -- humanoid, quadruped, custom
	boneCount: number,
	ikChains: { { bones: { string }, targetBone: string, poleBone: string? } },
}

function RigData.CreateHumanoidRig(): Rig
	local bones: { [string]: Bone } = {}

	-- Hips root
	bones["hips"] = {
		id = "hips",
		name = "Hips",
		parentId = nil,
		length = 0.2,
		position = Vector3.new(0, 1, 0),
		rotation = Vector3.new(0,0,0),
		children = {"spine", "leftUpperLeg", "rightUpperLeg"},
		isIK = false,
		ikChainLength = 0,
		constraints = {},
	}

	-- Spine chain
	bones["spine"] = { id = "spine", name = "Spine", parentId = "hips", length = 0.3, position = Vector3.new(0, 1.2, 0), rotation = Vector3.new(0,0,0), children = {"chest"}, isIK = false, ikChainLength = 0, constraints = {} }
	bones["chest"] = { id = "chest", name = "Chest", parentId = "spine", length = 0.3, position = Vector3.new(0, 1.5, 0), rotation = Vector3.new(0,0,0), children = {"neck", "leftShoulder", "rightShoulder"}, isIK = false, ikChainLength = 0, constraints = {} }
	bones["neck"] = { id = "neck", name = "Neck", parentId = "chest", length = 0.1, position = Vector3.new(0, 1.7, 0), rotation = Vector3.new(0,0,0), children = {"head"}, isIK = false, ikChainLength = 0, constraints = {} }
	bones["head"] = { id = "head", name = "Head", parentId = "neck", length = 0.25, position = Vector3.new(0, 1.9, 0), rotation = Vector3.new(0,0,0), children = {}, isIK = false, ikChainLength = 0, constraints = {} }

	-- Left arm
	bones["leftShoulder"] = { id = "leftShoulder", name = "LeftShoulder", parentId = "chest", length = 0.15, position = Vector3.new(-0.2, 1.5, 0), rotation = Vector3.new(0,0,0), children = {"leftUpperArm"}, isIK = false, ikChainLength = 0, constraints = {} }
	bones["leftUpperArm"] = { id = "leftUpperArm", name = "LeftUpperArm", parentId = "leftShoulder", length = 0.3, position = Vector3.new(-0.4, 1.5, 0), rotation = Vector3.new(0,0,0), children = {"leftLowerArm"}, isIK = true, ikChainLength = 2, constraints = { minAngle = Vector3.new(-90,-90,-90), maxAngle = Vector3.new(90,90,90) } }
	bones["leftLowerArm"] = { id = "leftLowerArm", name = "LeftLowerArm", parentId = "leftUpperArm", length = 0.25, position = Vector3.new(-0.65, 1.5, 0), rotation = Vector3.new(0,0,0), children = {"leftHand"}, isIK = true, ikChainLength = 1, constraints = {} }
	bones["leftHand"] = { id = "leftHand", name = "LeftHand", parentId = "leftLowerArm", length = 0.1, position = Vector3.new(-0.85, 1.5, 0), rotation = Vector3.new(0,0,0), children = {}, isIK = false, ikChainLength = 0, constraints = {} }

	-- Right arm
	bones["rightShoulder"] = { id = "rightShoulder", name = "RightShoulder", parentId = "chest", length = 0.15, position = Vector3.new(0.2, 1.5, 0), rotation = Vector3.new(0,0,0), children = {"rightUpperArm"}, isIK = false, ikChainLength = 0, constraints = {} }
	bones["rightUpperArm"] = { id = "rightUpperArm", name = "RightUpperArm", parentId = "rightShoulder", length = 0.3, position = Vector3.new(0.4, 1.5, 0), rotation = Vector3.new(0,0,0), children = {"rightLowerArm"}, isIK = true, ikChainLength = 2, constraints = { minAngle = Vector3.new(-90,-90,-90), maxAngle = Vector3.new(90,90,90) } }
	bones["rightLowerArm"] = { id = "rightLowerArm", name = "RightLowerArm", parentId = "rightUpperArm", length = 0.25, position = Vector3.new(0.65, 1.5, 0), rotation = Vector3.new(0,0,0), children = {"rightHand"}, isIK = true, ikChainLength = 1, constraints = {} }
	bones["rightHand"] = { id = "rightHand", name = "RightHand", parentId = "rightLowerArm", length = 0.1, position = Vector3.new(0.85, 1.5, 0), rotation = Vector3.new(0,0,0), children = {}, isIK = false, ikChainLength = 0, constraints = {} }

	-- Left leg
	bones["leftUpperLeg"] = { id = "leftUpperLeg", name = "LeftUpperLeg", parentId = "hips", length = 0.4, position = Vector3.new(-0.1, 0.8, 0), rotation = Vector3.new(0,0,0), children = {"leftLowerLeg"}, isIK = true, ikChainLength = 2, constraints = { minAngle = Vector3.new(-120,-20,-20), maxAngle = Vector3.new(20,20,20) } }
	bones["leftLowerLeg"] = { id = "leftLowerLeg", name = "LeftLowerLeg", parentId = "leftUpperLeg", length = 0.4, position = Vector3.new(-0.1, 0.4, 0), rotation = Vector3.new(0,0,0), children = {"leftFoot"}, isIK = true, ikChainLength = 1, constraints = {} }
	bones["leftFoot"] = { id = "leftFoot", name = "LeftFoot", parentId = "leftLowerLeg", length = 0.15, position = Vector3.new(-0.1, 0.05, 0.1), rotation = Vector3.new(0,0,0), children = {}, isIK = false, ikChainLength = 0, constraints = {} }

	-- Right leg
	bones["rightUpperLeg"] = { id = "rightUpperLeg", name = "RightUpperLeg", parentId = "hips", length = 0.4, position = Vector3.new(0.1, 0.8, 0), rotation = Vector3.new(0,0,0), children = {"rightLowerLeg"}, isIK = true, ikChainLength = 2, constraints = { minAngle = Vector3.new(-120,-20,-20), maxAngle = Vector3.new(20,20,20) } }
	bones["rightLowerLeg"] = { id = "rightLowerLeg", name = "RightLowerLeg", parentId = "rightUpperLeg", length = 0.4, position = Vector3.new(0.1, 0.4, 0), rotation = Vector3.new(0,0,0), children = {"rightFoot"}, isIK = true, ikChainLength = 1, constraints = {} }
	bones["rightFoot"] = { id = "rightFoot", name = "RightFoot", parentId = "rightUpperLeg", length = 0.15, position = Vector3.new(0.1, 0.05, 0.1), rotation = Vector3.new(0,0,0), children = {}, isIK = false, ikChainLength = 0, constraints = {} }

	return {
		id = "humanoid_" .. tostring(math.random(100000, 999999)),
		name = "Humanoid Rig - Cascadeur",
		bones = bones,
		rootBoneId = "hips",
		type = "humanoid",
		boneCount = 19,
		ikChains = {
			{ bones = {"leftUpperArm", "leftLowerArm"}, targetBone = "leftHand", poleBone = "leftElbowPole" },
			{ bones = {"rightUpperArm", "rightLowerArm"}, targetBone = "rightHand", poleBone = "rightElbowPole" },
			{ bones = {"leftUpperLeg", "leftLowerLeg"}, targetBone = "leftFoot", poleBone = "leftKneePole" },
			{ bones = {"rightUpperLeg", "rightLowerLeg"}, targetBone = "rightFoot", poleBone = "rightKneePole" },
		},
	}
end

function RigData.CreateQuadrupedRig(): Rig
	local bones: { [string]: Bone } = {}
	bones["hips"] = { id = "hips", name = "Hips", parentId = nil, length = 0.4, position = Vector3.new(0, 0.8, 0), rotation = Vector3.new(0,0,0), children = {"spine", "leftHindUpper", "rightHindUpper"}, isIK = false, ikChainLength = 0, constraints = {} }
	bones["spine"] = { id = "spine", name = "Spine", parentId = "hips", length = 0.6, position = Vector3.new(0, 0.8, 0.5), rotation = Vector3.new(0,0,0), children = {"chest"}, isIK = false, ikChainLength = 0, constraints = {} }
	bones["chest"] = { id = "chest", name = "Chest", parentId = "spine", length = 0.2, position = Vector3.new(0, 0.8, 1), rotation = Vector3.new(0,0,0), children = {"leftFrontUpper", "rightFrontUpper", "neck"}, isIK = false, ikChainLength = 0, constraints = {} }
	bones["neck"] = { id = "neck", name = "Neck", parentId = "chest", length = 0.3, position = Vector3.new(0, 0.9, 1.3), rotation = Vector3.new(0,0,0), children = {"head"}, isIK = false, ikChainLength = 0, constraints = {} }
	bones["head"] = { id = "head", name = "Head", parentId = "neck", length = 0.3, position = Vector3.new(0, 1, 1.6), rotation = Vector3.new(0,0,0), children = {}, isIK = false, ikChainLength = 0, constraints = {} }

	bones["leftFrontUpper"] = { id = "leftFrontUpper", name = "LeftFrontUpper", parentId = "chest", length = 0.3, position = Vector3.new(-0.15, 0.6, 1), rotation = Vector3.new(0,0,0), children = {"leftFrontLower"}, isIK = true, ikChainLength = 2, constraints = {} }
	bones["leftFrontLower"] = { id = "leftFrontLower", name = "LeftFrontLower", parentId = "leftFrontUpper", length = 0.3, position = Vector3.new(-0.15, 0.3, 1), rotation = Vector3.new(0,0,0), children = {"leftFrontFoot"}, isIK = true, ikChainLength = 1, constraints = {} }
	bones["leftFrontFoot"] = { id = "leftFrontFoot", name = "LeftFrontFoot", parentId = "leftFrontLower", length = 0.1, position = Vector3.new(-0.15, 0, 1), rotation = Vector3.new(0,0,0), children = {}, isIK = false, ikChainLength = 0, constraints = {} }

	bones["rightFrontUpper"] = { id = "rightFrontUpper", name = "RightFrontUpper", parentId = "chest", length = 0.3, position = Vector3.new(0.15, 0.6, 1), rotation = Vector3.new(0,0,0), children = {"rightFrontLower"}, isIK = true, ikChainLength = 2, constraints = {} }
	bones["rightFrontLower"] = { id = "rightFrontLower", name = "RightFrontLower", parentId = "rightFrontUpper", length = 0.3, position = Vector3.new(0.15, 0.3, 1), rotation = Vector3.new(0,0,0), children = {"rightFrontFoot"}, isIK = true, ikChainLength = 1, constraints = {} }
	bones["rightFrontFoot"] = { id = "rightFrontFoot", name = "RightFrontFoot", parentId = "rightFrontLower", length = 0.1, position = Vector3.new(0.15, 0, 1), rotation = Vector3.new(0,0,0), children = {}, isIK = false, ikChainLength = 0, constraints = {} }

	bones["leftHindUpper"] = { id = "leftHindUpper", name = "LeftHindUpper", parentId = "hips", length = 0.3, position = Vector3.new(-0.15, 0.6, 0), rotation = Vector3.new(0,0,0), children = {"leftHindLower"}, isIK = true, ikChainLength = 2, constraints = {} }
	bones["leftHindLower"] = { id = "leftHindLower", name = "LeftHindLower", parentId = "leftHindUpper", length = 0.3, position = Vector3.new(-0.15, 0.3, 0), rotation = Vector3.new(0,0,0), children = {"leftHindFoot"}, isIK = true, ikChainLength = 1, constraints = {} }
	bones["leftHindFoot"] = { id = "leftHindFoot", name = "LeftHindFoot", parentId = "leftHindLower", length = 0.1, position = Vector3.new(-0.15, 0, 0), rotation = Vector3.new(0,0,0), children = {}, isIK = false, ikChainLength = 0, constraints = {} }

	bones["rightHindUpper"] = { id = "rightHindUpper", name = "RightHindUpper", parentId = "hips", length = 0.3, position = Vector3.new(0.15, 0.6, 0), rotation = Vector3.new(0,0,0), children = {"rightHindLower"}, isIK = true, ikChainLength = 2, constraints = {} }
	bones["rightHindLower"] = { id = "rightHindLower", name = "RightHindLower", parentId = "rightHindUpper", length = 0.3, position = Vector3.new(0.15, 0.3, 0), rotation = Vector3.new(0,0,0), children = {"rightHindFoot"}, isIK = true, ikChainLength = 1, constraints = {} }
	bones["rightHindFoot"] = { id = "rightHindFoot", name = "RightHindFoot", parentId = "rightHindLower", length = 0.1, position = Vector3.new(0.15, 0, 0), rotation = Vector3.new(0,0,0), children = {}, isIK = false, ikChainLength = 0, constraints = {} }

	return {
		id = "quad_" .. tostring(math.random(100000, 999999)),
		name = "Quadruped Rig - Cascadeur",
		bones = bones,
		rootBoneId = "hips",
		type = "quadruped",
		boneCount = 17,
		ikChains = {
			{ bones = {"leftFrontUpper", "leftFrontLower"}, targetBone = "leftFrontFoot" },
			{ bones = {"rightFrontUpper", "rightFrontLower"}, targetBone = "rightFrontFoot" },
			{ bones = {"leftHindUpper", "leftHindLower"}, targetBone = "leftHindFoot" },
			{ bones = {"rightHindUpper", "rightHindLower"}, targetBone = "rightHindFoot" },
		},
	}
end

function RigData.GetBoneWorldPosition(rig: Rig, boneId: string): Vector3
	local bone = rig.bones[boneId]
	if not bone then return Vector3.new(0,0,0) end
	-- Soma posições até root (simplificado)
	local pos = bone.position
	local current = bone
	while current.parentId do
		local parent = rig.bones[current.parentId]
		if not parent then break end
		pos += parent.position
		current = parent
	end
	return pos
end

function RigData.GetChainBones(rig: Rig, chainIndex: number): { Bone }
	local chain = rig.ikChains[chainIndex]
	if not chain then return {} end
	local result = {}
	for _, boneId in chain.bones do
		local bone = rig.bones[boneId]
		if bone then table.insert(result, bone) end
	end
	return result
end

return RigData

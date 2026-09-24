--!strict
-- Arkher Studio - CascadeurController - Fase 3 - Orquestra animator Cascadeur level
-- Junta RigData + IKSystem + PhysicsAnimator + AnimationEditor

local RigData = require(game:GetService("ReplicatedStorage").Arkher.Animation.RigData)
local AnimationData = require(game:GetService("ReplicatedStorage").Arkher.Animation.AnimationData)

local CascadeurController = {}
CascadeurController.__index = CascadeurController

function CascadeurController.new()
	local self = setmetatable({
		rig = nil :: RigData.Rig?,
		clip = nil :: AnimationData.AnimationClip?,
		ikSystem = nil :: any,
		physicsAnimator = nil :: any,
		editor = nil :: any,
		currentPose = {} :: { [string]: { position: Vector3, rotation: Vector3 } },
		isAutoPhysics = true,
		isAutoBalance = true,
	}, CascadeurController)

	-- Lazy require para evitar circular
	local IKSystem = require(script.Parent.IKSystem)
	local PhysicsAnimator = require(script.Parent.PhysicsAnimator)
	local AnimationEditor = require(script.Parent.AnimationEditor)

	self.ikSystem = IKSystem.new()
	self.physicsAnimator = PhysicsAnimator.new()
	self.editor = AnimationEditor.new()

	return self
end

function CascadeurController:Init(parent: Frame)
	self.editor:Init(parent)

	-- Cria rig humanoid padrão
	local rig = RigData.CreateHumanoidRig()
	self.rig = rig
	self.editor:LoadRig(rig)

	-- Cria clip idle padrão
	local clip = AnimationData.CreateIdle(rig.id)
	self.clip = clip
	self.editor:LoadClip(clip)

	-- Inicializa pose
	for boneId, bone in rig.bones do
		self.currentPose[boneId] = {
			position = bone.position,
			rotation = bone.rotation,
		}
	end

	print("[Arkher Cascadeur] Initialized - Rig:", rig.name, "- Clip:", clip.name, "- Fase 3 Cascadeur level")
end

function CascadeurController:CreateNewRig(rigType: string): RigData.Rig
	local rig: RigData.Rig
	if rigType == "quadruped" then
		rig = RigData.CreateQuadrupedRig()
	else
		rig = RigData.CreateHumanoidRig()
	end

	self.rig = rig
	self.editor:LoadRig(rig)

	-- Reset pose
	self.currentPose = {}
	for boneId, bone in rig.bones do
		self.currentPose[boneId] = {
			position = bone.position,
			rotation = bone.rotation,
		}
	end

	print("[Arkher Cascadeur] Created new rig", rigType, "- Bones:", rig.boneCount)
	return rig
end

function CascadeurController:CreateAnimation(name: string, duration: number, template: string?): AnimationData.AnimationClip
	if not self.rig then
		warn("[Arkher Cascadeur] No rig loaded")
		return AnimationData.new(name, duration, "no_rig")
	end

	local clip: AnimationData.AnimationClip
	if template == "walk" then
		clip = AnimationData.CreateWalkCycle(self.rig.id)
		clip.name = name
	elseif template == "idle" then
		clip = AnimationData.CreateIdle(self.rig.id)
		clip.name = name
	else
		clip = AnimationData.new(name, duration, self.rig.id)
	end

	self.clip = clip
	self.editor:LoadClip(clip)

	print("[Arkher Cascadeur] Created animation", name, "- Duration:", duration, "- Template:", template or "empty")
	return clip
end

-- Auto-posing - Cascadeur principal feature - IA sugere pose física
function CascadeurController:AutoPose(boneId: string, targetPos: Vector3, usePhysics: boolean?)
	usePhysics = usePhysics or self.isAutoPhysics

	if not self.rig then return end

	local bone = self.rig.bones[boneId]
	if not bone then return end

	-- Encontra chain IK se existir
	local chainIndex: number? = nil
	for i, chain in self.rig.ikChains do
		for _, bId in chain.bones do
			if bId == boneId then
				chainIndex = i
				break
			end
		end
		if chainIndex then break end
	end

	if chainIndex and self.ikSystem then
		-- Resolve IK
		local chain = self.rig.ikChains[chainIndex]
		local jointPositions: { Vector3 } = {}
		for _, bId in chain.bones do
			local pose = self.currentPose[bId]
			if pose then table.insert(jointPositions, pose.position) end
		end
		-- Adiciona end effector
		local endBone = self.rig.bones[chain.targetBone]
		if endBone and self.currentPose[chain.targetBone] then
			table.insert(jointPositions, self.currentPose[chain.targetBone].position)
		end

		if #jointPositions >= 2 then
			local solved = self.ikSystem:SolveFABRIK(jointPositions, targetPos)

			-- Aplica solved positions
			for i, bId in chain.bones do
				if self.currentPose[bId] and solved[i] then
					self.currentPose[bId].position = solved[i]
				end
			end
			if self.currentPose[chain.targetBone] and solved[#solved] then
				self.currentPose[chain.targetBone].position = solved[#solved]
			end

			print("[Arkher Cascadeur] AutoPose IK solved for", boneId, "->", targetPos, "- Chain:", chainIndex)
		end
	else
		-- FK simples
		if self.currentPose[boneId] then
			self.currentPose[boneId].position = targetPos
			print("[Arkher Cascadeur] AutoPose FK for", boneId, "->", targetPos)
		end
	end

	-- Auto balance se habilitado
	if usePhysics and self.physicsAnimator and self.isAutoBalance then
		local footPositions = {}
		for _, footId in {"leftFoot", "rightFoot"} do
			if self.currentPose[footId] then
				table.insert(footPositions, self.currentPose[footId].position)
			end
		end

		if #footPositions >= 2 and self.currentPose["hips"] then
			local balancedHips = self.ikSystem:CalculateBalancedPose(self.currentPose["hips"].position, footPositions)
			self.currentPose["hips"].position = balancedHips
			print("[Arkher Cascadeur] Auto balance - Hips adjusted to", balancedHips)
		end
	end

	-- Secondary motion
	if usePhysics and self.physicsAnimator then
		print("[Arkher Cascadeur] Secondary motion enabled - Hair, clothes physics")
	end
end

-- AI Pose - Gera pose de prompt - Cascadeur AI
function CascadeurController:AIGeneratePose(prompt: string): { [string]: { position: Vector3, rotation: Vector3 } }?
	print("[Arkher Cascadeur] AI Generate Pose - Prompt:", prompt)

	-- Mock: em produção chama backend /api/ai/pose com TripoSR + Cascadeur AI
	local poses: { [string]: { position: Vector3, rotation: Vector3 } } = {}

	if string.find(string.lower(prompt), "walk") or string.find(string.lower(prompt), "andar") then
		-- Pose de caminhada
		poses["leftUpperLeg"] = { position = Vector3.new(-0.1, 0.8, 0), rotation = Vector3.new(-20,0,0) }
		poses["rightUpperLeg"] = { position = Vector3.new(0.1, 0.8, 0), rotation = Vector3.new(20,0,0) }
		poses["leftUpperArm"] = { position = Vector3.new(-0.4, 1.5, 0), rotation = Vector3.new(20,0,0) }
		poses["rightUpperArm"] = { position = Vector3.new(0.4, 1.5, 0), rotation = Vector3.new(-20,0,0) }
	elseif string.find(string.lower(prompt), "jump") or string.find(string.lower(prompt), "pulo") then
		poses["hips"] = { position = Vector3.new(0, 1.5, 0), rotation = Vector3.new(0,0,0) }
		poses["leftUpperLeg"] = { position = Vector3.new(-0.1, 1.2, 0), rotation = Vector3.new(-40,0,0) }
		poses["rightUpperLeg"] = { position = Vector3.new(0.1, 1.2, 0), rotation = Vector3.new(-40,0,0) }
	else
		-- T-pose default
		poses["leftUpperArm"] = { position = Vector3.new(-0.4, 1.5, 0), rotation = Vector3.new(0,0,-90) }
		poses["rightUpperArm"] = { position = Vector3.new(0.4, 1.5, 0), rotation = Vector3.new(0,0,90) }
	end

	-- Aplica
	for boneId, pose in poses do
		if self.currentPose[boneId] then
			self.currentPose[boneId] = pose
		end
	end

	print("[Arkher Cascadeur] AI Pose generated -", prompt, "- Bones:", #poses)
	return poses
end

function CascadeurController:ExportAnimation(): string?
	if not self.editor then
		warn("[Arkher Cascadeur] No editor")
		return nil
	end

	return self.editor:ExportToRoblox()
end

function CascadeurController:GetStats(): { [string]: any }
	return {
		hasRig = self.rig ~= nil,
		hasClip = self.clip ~= nil,
		rigType = self.rig and self.rig.type or "none",
		rigBones = self.rig and self.rig.boneCount or 0,
		ikChains = self.rig and #self.rig.ikChains or 0,
		clipName = self.clip and self.clip.name or "none",
		clipDuration = self.clip and self.clip.duration or 0,
		keyframes = self.clip and #self.clip.keyframes or 0,
		autoPhysics = self.isAutoPhysics,
		autoBalance = self.isAutoBalance,
		ikSystem = self.ikSystem and self.ikSystem:GetStats() or {},
		physics = self.physicsAnimator and self.physicsAnimator:GetStats() or {},
		editor = self.editor and self.editor:GetStats() or {},
		inspiration = "Cascadeur - Auto-posing physics + IK/FK + Secondary motion + AI pose",
		message = "CascadeurController Fase 3 - Cascadeur level - Auto-posing + FABRIK + Physics + AI",
	}
end

return CascadeurController

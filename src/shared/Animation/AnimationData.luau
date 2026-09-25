--!strict
-- Arkher Studio - AnimationData - Fase 3 - Dados de animação - Cascadeur + Blender

local AnimationData = {}
AnimationData.__index = AnimationData

export type Keyframe = {
	time: number,
	boneId: string,
	position: Vector3?,
	rotation: Vector3?,
	scale: Vector3?,
	easing: string?,
}

export type AnimationClip = {
	id: string,
	name: string,
	duration: number,
	fps: number,
	keyframes: { Keyframe },
	loop: boolean,
	rigId: string,
	tags: { string },
}

function AnimationData.new(name: string, duration: number, rigId: string): AnimationClip
	return {
		id = "anim_" .. tostring(math.random(100000, 999999)),
		name = name,
		duration = duration,
		fps = 30,
		keyframes = {},
		loop = true,
		rigId = rigId,
		tags = {},
	}
end

function AnimationData.AddKeyframe(clip: AnimationClip, boneId: string, time: number, pos: Vector3?, rot: Vector3?, scale: Vector3?, easing: string?): Keyframe
	local kf: Keyframe = {
		time = time,
		boneId = boneId,
		position = pos,
		rotation = rot,
		scale = scale,
		easing = easing or "linear",
	}
	table.insert(clip.keyframes, kf)
	-- Ordena por tempo
	table.sort(clip.keyframes, function(a, b) return a.time < b.time end)
	return kf
end

function AnimationData.GetKeyframesForBone(clip: AnimationClip, boneId: string): { Keyframe }
	local result = {}
	for _, kf in clip.keyframes do
		if kf.boneId == boneId then table.insert(result, kf) end
	end
	return result
end

function AnimationData.Evaluate(clip: AnimationClip, boneId: string, time: number): (Vector3?, Vector3?, Vector3?)
	-- Loop time
	if clip.loop then
		time = time % clip.duration
	else
		time = math.clamp(time, 0, clip.duration)
	end

	local boneKfs = AnimationData.GetKeyframesForBone(clip, boneId)
	if #boneKfs == 0 then return nil, nil, nil end
	if #boneKfs == 1 then return boneKfs[1].position, boneKfs[1].rotation, boneKfs[1].scale end

	-- Encontra keyframes anterior e próximo
	local prevKf: Keyframe? = nil
	local nextKf: Keyframe? = nil

	for i, kf in boneKfs do
		if kf.time <= time then
			prevKf = kf
		end
		if kf.time >= time and not nextKf then
			nextKf = kf
			break
		end
	end

	if not prevKf then prevKf = boneKfs[1] end
	if not nextKf then nextKf = boneKfs[#boneKfs] end

	if prevKf == nextKf then
		return prevKf.position, prevKf.rotation, prevKf.scale
	end

	local t = (time - prevKf.time) / (nextKf.time - prevKf.time)

	-- Easing
	if prevKf.easing == "easeInQuad" then t = t*t
	elseif prevKf.easing == "easeOutQuad" then t = 1 - (1-t)*(1-t)
	elseif prevKf.easing == "easeInOutCubic" then t = t < 0.5 and 4*t*t*t or 1 - (-2*t + 2)^3 / 2
	end

	local pos: Vector3? = nil
	if prevKf.position and nextKf.position then
		pos = prevKf.position:Lerp(nextKf.position, t)
	elseif prevKf.position then
		pos = prevKf.position
	elseif nextKf.position then
		pos = nextKf.position
	end

	local rot: Vector3? = nil
	if prevKf.rotation and nextKf.rotation then
		rot = prevKf.rotation:Lerp(nextKf.rotation, t)
	elseif prevKf.rotation then
		rot = prevKf.rotation
	elseif nextKf.rotation then
		rot = nextKf.rotation
	end

	return pos, rot, nil
end

function AnimationData.CreateWalkCycle(rigId: string): AnimationClip
	local clip = AnimationData.new("Walk Cycle - Cascadeur", 1.0, rigId)

	-- Hips bob
	AnimationData.AddKeyframe(clip, "hips", 0, Vector3.new(0, 1, 0), Vector3.new(0,0,0))
	AnimationData.AddKeyframe(clip, "hips", 0.25, Vector3.new(0, 1.05, 0), Vector3.new(0,0,0), nil, "easeInOutCubic")
	AnimationData.AddKeyframe(clip, "hips", 0.5, Vector3.new(0, 1, 0), Vector3.new(0,0,0))
	AnimationData.AddKeyframe(clip, "hips", 0.75, Vector3.new(0, 1.05, 0), Vector3.new(0,0,0), nil, "easeInOutCubic")
	AnimationData.AddKeyframe(clip, "hips", 1.0, Vector3.new(0, 1, 0), Vector3.new(0,0,0))

	-- Left leg
	AnimationData.AddKeyframe(clip, "leftUpperLeg", 0, nil, Vector3.new(-20,0,0))
	AnimationData.AddKeyframe(clip, "leftUpperLeg", 0.5, nil, Vector3.new(20,0,0))
	AnimationData.AddKeyframe(clip, "leftUpperLeg", 1.0, nil, Vector3.new(-20,0,0))

	-- Right leg oposto
	AnimationData.AddKeyframe(clip, "rightUpperLeg", 0, nil, Vector3.new(20,0,0))
	AnimationData.AddKeyframe(clip, "rightUpperLeg", 0.5, nil, Vector3.new(-20,0,0))
	AnimationData.AddKeyframe(clip, "rightUpperLeg", 1.0, nil, Vector3.new(20,0,0))

	-- Arms opostos às pernas
	AnimationData.AddKeyframe(clip, "leftUpperArm", 0, nil, Vector3.new(20,0,0))
	AnimationData.AddKeyframe(clip, "leftUpperArm", 0.5, nil, Vector3.new(-20,0,0))
	AnimationData.AddKeyframe(clip, "leftUpperArm", 1.0, nil, Vector3.new(20,0,0))

	AnimationData.AddKeyframe(clip, "rightUpperArm", 0, nil, Vector3.new(-20,0,0))
	AnimationData.AddKeyframe(clip, "rightUpperArm", 0.5, nil, Vector3.new(20,0,0))
	AnimationData.AddKeyframe(clip, "rightUpperArm", 1.0, nil, Vector3.new(-20,0,0))

	return clip
end

function AnimationData.CreateIdle(rigId: string): AnimationClip
	local clip = AnimationData.new("Idle - Breathing - Cascadeur", 2.0, rigId)
	clip.loop = true

	-- Respiração sutil no chest
	AnimationData.AddKeyframe(clip, "chest", 0, Vector3.new(0, 1.5, 0), Vector3.new(0,0,0))
	AnimationData.AddKeyframe(clip, "chest", 1.0, Vector3.new(0, 1.52, 0.02), Vector3.new(2,0,0), nil, "easeInOutCubic")
	AnimationData.AddKeyframe(clip, "chest", 2.0, Vector3.new(0, 1.5, 0), Vector3.new(0,0,0))

	return clip
end

function AnimationData.ToRobloxAnimation(clip: AnimationClip): string
	-- Converte para formato Roblox Animation (simplificado)
	-- Em produção gera KeyframeSequence real
	local xml = string.format('<AnimationClip Name="%s" Duration="%f" FPS="%d" Loop="%s">\n', clip.name, clip.duration, clip.fps, tostring(clip.loop))
	for _, kf in clip.keyframes do
		xml ..= string.format('  <Keyframe Time="%f" Bone="%s" Pos="%s" Rot="%s" Easing="%s"/>\n', kf.time, kf.boneId, tostring(kf.position), tostring(kf.rotation), kf.easing or "linear")
	end
	xml ..= '</AnimationClip>'
	return xml
end

return AnimationData

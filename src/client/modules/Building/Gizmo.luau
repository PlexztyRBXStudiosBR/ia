--!strict
-- Arkher Studio - Gizmo System - Move, Rotate, Scale igual Blender/Unreal
-- Funciona com Mouse, Touch, Gamepad, VR

local Gizmo = {}
Gizmo.__index = Gizmo

export type GizmoMode = "Translate" | "Rotate" | "Scale" | "Universal"
export type GizmoAxis = "X" | "Y" | "Z" | "XY" | "YZ" | "XZ" | "All"

function Gizmo.new()
	return setmetatable({
		mode = "Translate" :: GizmoMode,
		activeAxis = nil :: GizmoAxis?,
		isDragging = false,
		targetEntityId = nil :: string?,
		snapEnabled = true,
		snapValue = 1, -- 1 stud
		rotationSnap = 15, -- 15 graus
		scaleSnap = 0.1,
		handles = {},
	}, Gizmo)
end

function Gizmo:SetMode(mode: GizmoMode)
	self.mode = mode
	print("[Arkher Gizmo] Mode set to", mode)
end

function Gizmo:SetTarget(entityId: string?)
	self.targetEntityId = entityId
	if entityId then
		print("[Arkher Gizmo] Target set to", entityId)
	else
		print("[Arkher Gizmo] Target cleared")
	end
end

function Gizmo:StartDrag(axis: GizmoAxis, startPos: Vector3)
	self.activeAxis = axis
	self.isDragging = true
	self.dragStartPos = startPos
	print("[Arkher Gizmo] Start drag on axis", axis, "from", startPos)
end

function Gizmo:UpdateDrag(currentPos: Vector3): Vector3?
	if not self.isDragging or not self.activeAxis then return nil end

	local delta = currentPos - self.dragStartPos

	-- Aplica snap
	if self.snapEnabled then
		if self.mode == "Translate" then
			delta = Vector3.new(
				math.round(delta.X / self.snapValue) * self.snapValue,
				math.round(delta.Y / self.snapValue) * self.snapValue,
				math.round(delta.Z / self.snapValue) * self.snapValue
			)
		elseif self.mode == "Rotate" then
			-- Snap rotação
			delta = Vector3.new(
				math.round(delta.X / self.rotationSnap) * self.rotationSnap,
				math.round(delta.Y / self.rotationSnap) * self.rotationSnap,
				math.round(delta.Z / self.rotationSnap) * self.rotationSnap
			)
		end
	end

	-- Filtra por eixo
	if self.activeAxis == "X" then
		delta = Vector3.new(delta.X, 0, 0)
	elseif self.activeAxis == "Y" then
		delta = Vector3.new(0, delta.Y, 0)
	elseif self.activeAxis == "Z" then
		delta = Vector3.new(0, 0, delta.Z)
	end

	return delta
end

function Gizmo:EndDrag()
	self.isDragging = false
	self.activeAxis = nil
	print("[Arkher Gizmo] End drag")
end

function Gizmo:CreateHandles(parent: Instance)
	-- Cria handles 3D no mundo (Partes com BillboardGui)
	-- Fase 1: Handles simples, Fase 2: Handles custom com EditableMesh

	local handlesFolder = Instance.new("Folder")
	handlesFolder.Name = "ArkherGizmoHandles"
	handlesFolder.Parent = parent

	local axes = {
		{axis = "X", color = Color3.fromRGB(255, 60, 60), pos = Vector3.new(4,0,0)},
		{axis = "Y", color = Color3.fromRGB(60, 255, 60), pos = Vector3.new(0,4,0)},
		{axis = "Z", color = Color3.fromRGB(60, 60, 255), pos = Vector3.new(0,0,4)},
	}

	for _, data in axes do
		local handle = Instance.new("Part")
		handle.Name = "Handle_" .. data.axis
		handle.Size = Vector3.new(0.5, 0.5, 4)
		handle.Color = data.color
		handle.Material = Enum.Material.Neon
		handle.Anchored = true
		handle.CanCollide = false
		handle.CFrame = CFrame.new(data.pos)
		handle.Parent = handlesFolder

		table.insert(self.handles, handle)
	end

	print("[Arkher Gizmo] Created 3D handles")
	return handlesFolder
end

function Gizmo:DestroyHandles()
	for _, handle in self.handles do
		if handle.Parent then
			handle:Destroy()
		end
	end
	self.handles = {}
end

return Gizmo

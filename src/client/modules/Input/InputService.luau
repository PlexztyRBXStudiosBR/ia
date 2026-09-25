--!strict
-- Arkher Studio - InputService Universal
-- Um input para todas as plataformas: Mobile, PC, Console, VR

local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")

local InputService = {}
InputService.__index = InputService

export type InputAction = "Move" | "Rotate" | "Scale" | "Select" | "Duplicate" | "Delete" | "Undo" | "Redo" | "Play" | "Focus"

type Callback = (inputData: any) -> ()

function InputService.new()
	local self = setmetatable({
		actions = {} :: { [string]: { Callback } },
		isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
		isConsole = UserInputService.GamepadEnabled and not UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
		isVR = VRService.VREnabled,
		isPC = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled,
		touchCount = 0,
		lastTouchPositions = {},
	}, InputService)

	self:SetupDetectors()
	return self
end

function InputService:SetupDetectors()
	-- Detecta plataforma atual
	if self.isMobile then
		print("[Arkher Input] Platform: MOBILE - Touch gestures enabled")
	elseif self.isConsole then
		print("[Arkher Input] Platform: CONSOLE - Gamepad navigation enabled")
	elseif self.isVR then
		print("[Arkher Input] Platform: VR - Motion controllers enabled")
	else
		print("[Arkher Input] Platform: PC - Mouse + Keyboard")
	end

	-- InputBegan universal
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		self:HandleInput(input, "Began")
	end)

	UserInputService.InputChanged:Connect(function(input)
		self:HandleInput(input, "Changed")
	end)

	UserInputService.InputEnded:Connect(function(input)
		self:HandleInput(input, "Ended")
	end)

	-- Touch específico para mobile
	UserInputService.TouchStarted:Connect(function(touches)
		self.touchCount = #touches
		if self.touchCount == 1 then
			self:Trigger("Select", { position = touches[1] })
		elseif self.touchCount == 2 then
			self:Trigger("Scale", { touches = touches }) -- pinch to scale
		end
	end)

	UserInputService.TouchMoved:Connect(function(touches)
		if #touches == 1 then
			self:Trigger("Move", { delta = touches[1].Delta })
		end
	end)
end

function InputService:HandleInput(input: InputObject, state: string)
	-- Mapeamento universal
	if input.UserInputType == Enum.UserInputType.MouseButton1 and state == "Began" then
		self:Trigger("Select", { position = input.Position, input = input })

	elseif input.UserInputType == Enum.UserInputType.MouseMovement and state == "Changed" then
		self:Trigger("Move", { delta = input.Delta, position = input.Position })

	elseif input.KeyCode == Enum.KeyCode.W and state == "Began" then
		self:Trigger("Move", { mode = "translate" })
	elseif input.KeyCode == Enum.KeyCode.E and state == "Began" then
		self:Trigger("Rotate", { mode = "rotate" })
	elseif input.KeyCode == Enum.KeyCode.R and state == "Began" then
		self:Trigger("Scale", { mode = "scale" })

	elseif input.KeyCode == Enum.KeyCode.Delete and state == "Began" then
		self:Trigger("Delete", {})

	elseif input.KeyCode == Enum.KeyCode.Z and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and state == "Began" then
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			self:Trigger("Redo", {})
		else
			self:Trigger("Undo", {})
		end

	elseif input.KeyCode == Enum.KeyCode.F and state == "Began" then
		self:Trigger("Focus", {})

	-- Gamepad (Console)
	elseif input.UserInputType == Enum.UserInputType.Gamepad1 then
		if input.KeyCode == Enum.KeyCode.ButtonA and state == "Began" then
			self:Trigger("Select", { gamepad = true })
		elseif input.KeyCode == Enum.KeyCode.ButtonX and state == "Began" then
			self:Trigger("Delete", { gamepad = true })
		end
	end
end

function InputService:On(action: InputAction, callback: Callback)
	if not self.actions[action] then
		self.actions[action] = {}
	end
	table.insert(self.actions[action], callback)

	-- Retorna função para desconectar
	return function()
		local list = self.actions[action]
		if list then
			for i, cb in list do
				if cb == callback then
					table.remove(list, i)
					break
				end
			end
		end
	end
end

function InputService:Trigger(action: InputAction, data: any)
	local callbacks = self.actions[action]
	if callbacks then
		for _, cb in callbacks do
			task.spawn(cb, data)
		end
	end
end

function InputService:GetPlatform(): string
	if self.isVR then return "VR"
	elseif self.isConsole then return "Console"
	elseif self.isMobile then return "Mobile"
	else return "PC" end
end

return InputService

--!strict
-- Arkher Studio - NotificationSystem - Polimento Total 100% - Notificacoes nivel Figma + Notion + VS Code
-- Inspirado no melhor: Figma notifications, Notion, VS Code, Unreal, Blender - mas nosso amigavel Beginner to Pro

local NotificationSystem = {}
NotificationSystem.__index = NotificationSystem

export type NotificationType = "Info" | "Success" | "Warning" | "Error" | "AI"

function NotificationSystem.new(themeSystem: any)
	return setmetatable({
		themeSystem = themeSystem,
		notifications = {} :: { { id: string, type: NotificationType, title: string, message: string, duration: number, timestamp: number, frame: Frame? } },
		frame = nil :: Frame?,
		container = nil :: ScrollingFrame?,
		nextId = 1,
	}, NotificationSystem)
end

function NotificationSystem:Init(parent: ScreenGui)
	local colors = self.themeSystem:GetColors()

	local container = Instance.new("Frame")
	container.Name = "NotificationContainer"
	container.Size = UDim2.new(0, 360, 1, -100)
	container.Position = UDim2.new(1, -370, 0, 50)
	container.BackgroundTransparency = 1
	container.ZIndex = 100
	container.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Parent = container

	self.frame = container
	self.container = container :: any

	print("[Arkher Notification] Initialized - Figma + Notion + VS Code level - Beginner friendly")

	return container
end

function NotificationSystem:Notify(type: NotificationType, title: string, message: string, duration: number?)
	duration = duration or (type == "Error" and 8 or type == "Success" and 4 or 5)

	local id = "notif_" .. self.nextId
	self.nextId += 1

	local colors = self.themeSystem:GetColors()

	local bgColor = type == "Success" and colors.success or type == "Warning" and colors.warning or type == "Error" and colors.error or type == "AI" and Color3.fromRGB(120, 80, 255) or colors.panelLight
	local icon = type == "Success" and "✅" or type == "Warning" and "⚠️" or type == "Error" and "❌" or type == "AI" and "🤖" or "💡"

	local notifFrame = Instance.new("Frame")
	notifFrame.Name = id
	notifFrame.Size = UDim2.new(1, -10, 0, 80)
	notifFrame.BackgroundColor3 = colors.panel
	notifFrame.BorderSizePixel = 0
	notifFrame.LayoutOrder = -self.nextId
	notifFrame.ZIndex = 101
	notifFrame.Parent = self.frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = notifFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = bgColor
	stroke.Thickness = 2
	stroke.Parent = notifFrame

	-- Color bar left
	local colorBar = Instance.new("Frame")
	colorBar.Size = UDim2.new(0, 4, 1, 0)
	colorBar.BackgroundColor3 = bgColor
	colorBar.BorderSizePixel = 0
	colorBar.Parent = notifFrame

	-- Icon
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(0, 40, 0, 30)
	iconLabel.Position = UDim2.new(0, 10, 0, 5)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.TextSize = 20
	iconLabel.Parent = notifFrame

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -60, 0, 20)
	titleLabel.Position = UDim2.new(0, 50, 0, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = colors.text
	titleLabel.TextSize = 12
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtRight
	titleLabel.Parent = notifFrame

	-- Message
	local msgLabel = Instance.new("TextLabel")
	msgLabel.Size = UDim2.new(1, -60, 0, 40)
	msgLabel.Position = UDim2.new(0, 50, 0, 25)
	msgLabel.BackgroundTransparency = 1
	msgLabel.Text = message
	msgLabel.TextColor3 = colors.textDim
	msgLabel.TextSize = 11
	msgLabel.Font = Enum.Font.Gotham
	msgLabel.TextXAlignment = Enum.TextXAlignment.Left
	msgLabel.TextWrapped = true
	msgLabel.Parent = notifFrame

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 20, 0, 20)
	closeBtn.Position = UDim2.new(1, -25, 0, 5)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = colors.textDim
	closeBtn.TextSize = 12
	closeBtn.Parent = notifFrame

	closeBtn.MouseButton1Click:Connect(function()
		self:Dismiss(id)
	end)

	-- Progress bar
	local progressBg = Instance.new("Frame")
	progressBg.Name = "ProgressBg"
	progressBg.Size = UDim2.new(1, -10, 0, 3)
	progressBg.Position = UDim2.new(0, 5, 1, -6)
	progressBg.BackgroundColor3 = colors.background
	progressBg.BorderSizePixel = 0
	progressBg.Parent = notifFrame

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 2)
	progressCorner.Parent = progressBg

	local progress = Instance.new("Frame")
	progress.Name = "Progress"
	progress.Size = UDim2.new(1, 0, 1, 0)
	progress.BackgroundColor3 = bgColor
	progress.BorderSizePixel = 0
	progress.Parent = progressBg

	local progressCorner2 = Instance.new("UICorner")
	progressCorner2.CornerRadius = UDim.new(0, 2)
	progressCorner2.Parent = progress

	-- Animate progress
	task.spawn(function()
		for i = 0, 100 do
			task.wait(duration / 100)
			if progress.Parent then
				progress.Size = UDim2.new(1 - i/100, 0, 1, 0)
			else
				break
			end
		end
		self:Dismiss(id)
	end)

	local notif = {
		id = id,
		type = type,
		title = title,
		message = message,
		duration = duration,
		timestamp = os.time(),
		frame = notifFrame,
	}

	table.insert(self.notifications, notif)

	print(string.format("[Arkher Notification] %s - %s: %s (%ds)", type, title, message, duration))

	return id
end

function NotificationSystem:NotifySuccess(title: string, message: string) return self:Notify("Success", title, message, 4) end
function NotificationSystem:NotifyError(title: string, message: string) return self:Notify("Error", title, message, 8) end
function NotificationSystem:NotifyWarning(title: string, message: string) return self:Notify("Warning", title, message, 6) end
function NotificationSystem:NotifyInfo(title: string, message: string) return self:Notify("Info", title, message, 5) end
function NotificationSystem:NotifyAI(title: string, message: string) return self:Notify("AI", title, message, 6) end

function NotificationSystem:Dismiss(id: string)
	for i, notif in self.notifications do
		if notif.id == id then
			if notif.frame and notif.frame.Parent then
				-- Fade out
				task.spawn(function()
					for t = 0, 1, 0.1 do
						task.wait(0.03)
						if notif.frame then
							notif.frame.BackgroundTransparency = t
						end
					end
					if notif.frame then notif.frame:Destroy() end
				end)
			end
			table.remove(self.notifications, i)
			break
		end
	end
end

function NotificationSystem:ClearAll()
	for _, notif in self.notifications do
		if notif.frame then notif.frame:Destroy() end
	end
	self.notifications = {}
	print("[Arkher Notification] Cleared all")
end

function NotificationSystem:GetStats()
	return {
		count = #self.notifications,
		nextId = self.nextId,
		message = "NotificationSystem - Figma + Notion + VS Code level - Info/Success/Warning/Error/AI - Auto dismiss + progress bar + Beginner friendly - Polimento 100%",
	}
end

return NotificationSystem

--!strict
-- Arkher Studio - AdaptiveLayout - Polimento Total
-- Layout adaptativo inspirado no melhor: Figma (auto-layout), Unreal (docking), VS Code (flex), Blender (areas)
-- Mas nosso: confortavel em TODOS dispositivos, especialmente mobile
-- Mobile: A01 720x1280 até Flagship 1440x3200, Tablet, Desktop 1080p-8K, Console, VR

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local AdaptiveLayout = {}
AdaptiveLayout.__index = AdaptiveLayout

export type DeviceType = "MobileSmall" | "Mobile" | "MobileLarge" | "Tablet" | "Desktop" | "UltraWide" | "Console" | "VR"
export type Orientation = "Portrait" | "Landscape"
export type Platform = "Mobile" | "Tablet" | "Desktop" | "Console" | "VR"

function AdaptiveLayout.DetectDevice(): DeviceType
	local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	local isTouch = UserInputService.TouchEnabled
	local isGamepad = UserInputService.GamepadEnabled and not isTouch
	local isKeyboard = UserInputService.KeyboardEnabled

	if UserInputService.VREnabled then
		return "VR"
	elseif isGamepad and not isKeyboard then
		return "Console"
	elseif isTouch then
		local smallest = math.min(screenSize.X, screenSize.Y)
		if smallest < 400 then
			return "MobileSmall" -- A01, J2 Core
		elseif smallest < 500 then
			return "Mobile" -- A01-A33 medio
		elseif smallest < 700 then
			return "MobileLarge" -- S23, iPhone Pro
		else
			return "Tablet"
		end
	else
		if screenSize.X > 2560 then
			return "UltraWide"
		else
			return "Desktop"
		end
	end
end

function AdaptiveLayout.DetectOrientation(): Orientation
	local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	return screenSize.X > screenSize.Y and "Landscape" or "Portrait"
end

function AdaptiveLayout.new()
	local device = AdaptiveLayout.DetectDevice()
	local orientation = AdaptiveLayout.DetectOrientation()
	return setmetatable({
		device = device,
		orientation = orientation,
		screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080),
		safeArea = GuiService:GetGuiInset(),
		isMobile = device == "MobileSmall" or device == "Mobile" or device == "MobileLarge",
		isTablet = device == "Tablet",
		isDesktop = device == "Desktop" or device == "UltraWide",
		isConsole = device == "Console",
		isVR = device == "VR",
		listeners = {} :: { (DeviceType, Orientation) -> () },
	}, AdaptiveLayout)
end

function AdaptiveLayout:GetLayoutConfig()
	-- Config por device - inspirado no melhor UX do mundo (Figma mobile, Unreal mobile, Blender mobile)
	if self.device == "MobileSmall" then -- A01 720x1280 - o mais desafiador, precisa ser PERFEITO
		return {
			topBarHeight = 44,
			bottomBarHeight = 80,
			sidePanelWidth = 0, -- No mobile small, side panels viram bottom sheet
			contentDrawerHeight = 280,
			viewportPadding = 5,
			buttonSize = 48, -- minimo 48dp para dedo (Material Design)
			buttonSpacing = 8,
			fontScale = 0.9,
			showOutliner = false,
			showDetails = false,
			useBottomSheet = true,
			useRadialMenu = true,
			toolbarPosition = "bottom",
			tabsScrollable = true,
			maxVisibleTabs = 3,
			gestures = true,
			haptics = true,
		}
	elseif self.device == "Mobile" then
		return {
			topBarHeight = 48,
			bottomBarHeight = 70,
			sidePanelWidth = 0,
			contentDrawerHeight = 300,
			viewportPadding = 8,
			buttonSize = 44,
			buttonSpacing = 10,
			fontScale = 1.0,
			showOutliner = false,
			showDetails = false,
			useBottomSheet = true,
			useRadialMenu = true,
			toolbarPosition = "bottom",
			tabsScrollable = true,
			maxVisibleTabs = 4,
			gestures = true,
			haptics = true,
		}
	elseif self.device == "MobileLarge" then
		return {
			topBarHeight = 50,
			bottomBarHeight = 70,
			sidePanelWidth = 260,
			contentDrawerHeight = 320,
			viewportPadding = 10,
			buttonSize = 42,
			buttonSpacing = 10,
			fontScale = 1.0,
			showOutliner = true,
			showDetails = false,
			useBottomSheet = true,
			useRadialMenu = false,
			toolbarPosition = "bottom",
			tabsScrollable = true,
			maxVisibleTabs = 5,
			gestures = true,
			haptics = false,
		}
	elseif self.device == "Tablet" then
		return {
			topBarHeight = 50,
			bottomBarHeight = 0,
			sidePanelWidth = 300,
			contentDrawerHeight = 260,
			viewportPadding = 12,
			buttonSize = 40,
			buttonSpacing = 12,
			fontScale = 1.0,
			showOutliner = true,
			showDetails = true,
			useBottomSheet = false,
			useRadialMenu = false,
			toolbarPosition = "top",
			tabsScrollable = true,
			maxVisibleTabs = 6,
			gestures = true,
			haptics = false,
		}
	elseif self.device == "Console" then
		return {
			topBarHeight = 60,
			bottomBarHeight = 0,
			sidePanelWidth = 340,
			contentDrawerHeight = 280,
			viewportPadding = 20,
			buttonSize = 48,
			buttonSpacing = 16,
			fontScale = 1.2,
			showOutliner = true,
			showDetails = true,
			useBottomSheet = false,
			useRadialMenu = false,
			toolbarPosition = "top",
			tabsScrollable = false,
			maxVisibleTabs = 8,
			gestures = false,
			haptics = true,
		}
	elseif self.device == "VR" then
		return {
			topBarHeight = 80,
			bottomBarHeight = 0,
			sidePanelWidth = 400,
			contentDrawerHeight = 300,
			viewportPadding = 30,
			buttonSize = 60,
			buttonSpacing = 20,
			fontScale = 1.4,
			showOutliner = true,
			showDetails = true,
			useBottomSheet = false,
			useRadialMenu = false,
			toolbarPosition = "floating",
			tabsScrollable = false,
			maxVisibleTabs = 8,
			gestures = true,
			haptics = true,
		}
	else -- Desktop / UltraWide
		return {
			topBarHeight = 40,
			bottomBarHeight = 0,
			sidePanelWidth = 280,
			contentDrawerHeight = 240,
			viewportPadding = 0,
			buttonSize = 32,
			buttonSpacing = 8,
			fontScale = 1.0,
			showOutliner = true,
			showDetails = true,
			useBottomSheet = false,
			useRadialMenu = false,
			toolbarPosition = "top",
			tabsScrollable = true,
			maxVisibleTabs = 8,
			gestures = false,
			haptics = false,
		}
	end
end

function AdaptiveLayout:ApplyToUI(ui: { [string]: Frame })
	local config = self:GetLayoutConfig()
	print("[Arkher Adaptive] Device:", self.device, "Orientation:", self.orientation, "Config:", config)

	if self.isMobile then
		-- Mobile: esconde side panels, usa bottom sheet
		if ui.outliner then
			ui.outliner.Visible = config.showOutliner
			if config.showOutliner then
				ui.outliner.Size = UDim2.new(0, config.sidePanelWidth, 1, -config.topBarHeight - config.bottomBarHeight - config.contentDrawerHeight)
			end
		end
		if ui.details then
			ui.details.Visible = config.showDetails
		end
		if ui.contentDrawer then
			ui.contentDrawer.Size = UDim2.new(1, 0, 0, config.contentDrawerHeight)
			ui.contentDrawer.Position = UDim2.new(0, 0, 1, -config.contentDrawerHeight - config.bottomBarHeight)
		end
		if ui.viewport then
			ui.viewport.Size = UDim2.new(1, -config.viewportPadding*2, 1, -config.topBarHeight - config.bottomBarHeight - config.contentDrawerHeight - config.viewportPadding*2)
			ui.viewport.Position = UDim2.new(0, config.viewportPadding, 0, config.topBarHeight + config.viewportPadding)
		end
	else
		-- Desktop/Tablet: layout tradicional
		if ui.topBar then
			ui.topBar.Size = UDim2.new(1, 0, 0, config.topBarHeight)
		end
		if ui.outliner then
			ui.outliner.Visible = true
			ui.outliner.Size = UDim2.new(0, config.sidePanelWidth, 1, -config.topBarHeight - config.contentDrawerHeight - 10)
			ui.outliner.Position = UDim2.new(0, 0, 0, config.topBarHeight + 10)
		end
		if ui.details then
			ui.details.Visible = true
			ui.details.Size = UDim2.new(0, config.sidePanelWidth + 40, 1, -config.topBarHeight - config.contentDrawerHeight - 10)
			ui.details.Position = UDim2.new(1, -config.sidePanelWidth - 40, 0, config.topBarHeight + 10)
		end
		if ui.contentDrawer then
			ui.contentDrawer.Size = UDim2.new(1, -config.sidePanelWidth*2 - 60, 0, config.contentDrawerHeight)
			ui.contentDrawer.Position = UDim2.new(0, config.sidePanelWidth + 10, 1, -config.contentDrawerHeight - 10)
		end
		if ui.viewport then
			ui.viewport.Size = UDim2.new(1, -config.sidePanelWidth*2 - 60, 1, -config.topBarHeight - config.contentDrawerHeight - 20)
			ui.viewport.Position = UDim2.new(0, config.sidePanelWidth + 10, 0, config.topBarHeight + 10)
		end
	end
end

function AdaptiveLayout:CreateBottomSheet(parent: ScreenGui, theme: any): Frame
	-- Bottom sheet estilo Google Maps / Figma mobile - melhor UX mobile do mundo
	local sheet = Instance.new("Frame")
	sheet.Name = "AdaptiveBottomSheet"
	sheet.Size = UDim2.new(1, 0, 0, 400)
	sheet.Position = UDim2.new(0, 0, 1, 0)
	sheet.BackgroundColor3 = theme.panel
	sheet.BorderSizePixel = 0
	sheet.ZIndex = 15
	sheet.Visible = false
	sheet.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = sheet

	-- Handle
	local handle = Instance.new("Frame")
	handle.Name = "Handle"
	handle.Size = UDim2.new(0, 40, 0, 4)
	handle.Position = UDim2.new(0.5, -20, 0, 8)
	handle.BackgroundColor3 = theme.textDim
	handle.BorderSizePixel = 0
	handle.Parent = sheet

	local handleCorner = Instance.new("UICorner")
	handleCorner.CornerRadius = UDim.new(0, 2)
	handleCorner.Parent = handle

	-- Drag area
	local dragArea = Instance.new("Frame")
	dragArea.Name = "DragArea"
	dragArea.Size = UDim2.new(1, 0, 0, 30)
	dragArea.BackgroundTransparency = 1
	dragArea.Parent = sheet

	return sheet
end

function AdaptiveLayout:CreateMobileToolbar(parent: ScreenGui, theme: any): Frame
	local config = self:GetLayoutConfig()
	local toolbar = Instance.new("Frame")
	toolbar.Name = "AdaptiveMobileToolbar"
	toolbar.Size = UDim2.new(1, 0, 0, config.bottomBarHeight)
	toolbar.Position = UDim2.new(0, 0, 1, -config.bottomBarHeight)
	toolbar.BackgroundColor3 = theme.panel
	toolbar.BorderSizePixel = 0
	toolbar.ZIndex = 20
	toolbar.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = toolbar

	local stroke = Instance.new("UIStroke")
	stroke.Color = theme.border
	stroke.Thickness = 1
	stroke.Parent = toolbar

	-- Safe area padding para iPhone notch / Android gesture
	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = toolbar

	return toolbar
end

function AdaptiveLayout:OnDeviceChanged(cb: (DeviceType, Orientation) -> ())
	table.insert(self.listeners, cb)
end

function AdaptiveLayout:GetStats()
	return {
		device = self.device,
		orientation = self.orientation,
		screenSize = self.screenSize,
		isMobile = self.isMobile,
		isTablet = self.isTablet,
		isDesktop = self.isDesktop,
		isConsole = self.isConsole,
		isVR = self.isVR,
		config = self:GetLayoutConfig(),
		message = "AdaptiveLayout - Polimento Total - A01 720x1280 até 8K + Console + VR - BottomSheet + Radial + Gestures",
	}
end

return AdaptiveLayout

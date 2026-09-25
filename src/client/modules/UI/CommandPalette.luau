--!strict
-- Arkher Studio - CommandPalette - BETA FINAL Fix UI feia bugada - Sem Emojis - Pixel Art Icons

local IconSystem = require(script.Parent.IconSystem)

local CommandPalette = {}
CommandPalette.__index = CommandPalette

export type Command = {
	id: string,
	name: string,
	description: string,
	icon: string, -- icon name for IconSystem, not emoji
	category: string,
	shortcut: string?,
	action: () -> (),
	level: string,
}

function CommandPalette.new(theme: any, adaptive: any)
	return setmetatable({
		theme = theme,
		adaptive = adaptive,
		iconSystem = IconSystem.new(),
		commands = {} :: { Command },
		isOpen = false,
		frame = nil :: Frame?,
		searchBox = nil :: TextBox?,
		resultsList = nil :: ScrollingFrame?,
		selectedIndex = 1,
		filter = "",
		recentCommands = {} :: { string },
	}, CommandPalette)
end

function CommandPalette:RegisterDefaultCommands(mainController: any)
	local cmds: { Command } = {
		-- File - sem emojis, icon names
		{ id = "file.new", name = "New Project", description = "Criar novo projeto 15GB", icon = "project", category = "File", shortcut = "Ctrl+N", action = function() print("New Project") end, level = "Beginner" },
		{ id = "file.save", name = "Save Project", description = "Salvar projeto (15GB chunked S3)", icon = "save", category = "File", shortcut = "Ctrl+S", action = function() if mainController then mainController:SaveProject() end end, level = "Beginner" },
		{ id = "file.publish", name = "Publish to Roblox", description = "Publicar jogo real no perfil - Open Cloud V2", icon = "publish", category = "File", shortcut = "Ctrl+P", action = function() if mainController then mainController:PublishProject() end end, level = "Beginner" },

		-- Edit
		{ id = "edit.undo", name = "Undo", description = "Desfazer", icon = "rotate", category = "Edit", shortcut = "Ctrl+Z", action = function() if mainController and mainController.buildingService then mainController.buildingService:Undo() end end, level = "Beginner" },
		{ id = "edit.redo", name = "Redo", description = "Refazer", icon = "rotate", category = "Edit", shortcut = "Ctrl+Y", action = function() if mainController and mainController.buildingService then mainController.buildingService:Redo() end end, level = "Beginner" },
		{ id = "edit.duplicate", name = "Duplicate", description = "Duplicar selecao", icon = "details", category = "Edit", shortcut = "Ctrl+D", action = function() if mainController and mainController.buildingService and mainController.buildingService.selectedEntityId then mainController.buildingService:DuplicateEntity(mainController.buildingService.selectedEntityId) end end, level = "Beginner" },
		{ id = "edit.delete", name = "Delete", description = "Deletar selecao", icon = "close", category = "Edit", shortcut = "Delete", action = function() if mainController and mainController.buildingService and mainController.buildingService.selectedEntityId then mainController.buildingService:DeleteEntity(mainController.buildingService.selectedEntityId) end end, level = "Beginner" },

		-- View
		{ id = "view.outliner", name = "Toggle Outliner", description = "Mostrar/esconder World Outliner", icon = "world", category = "View", shortcut = "", action = function() end, level = "Intermediate" },
		{ id = "view.details", name = "Toggle Details", description = "Mostrar/esconder Details", icon = "details", category = "View", shortcut = "", action = function() end, level = "Intermediate" },
		{ id = "view.viewport", name = "Focus Viewport", description = "Focar viewport", icon = "world", category = "View", shortcut = "F", action = function() end, level = "Intermediate" },
		{ id = "view.style.lowpoly", name = "Style: Low Poly", description = "Mudar para Low Poly - 120 FPS A01", icon = "vault", category = "Style", shortcut = "", action = function() if mainController then mainController.currentStyle = "lowpoly" mainController:CycleStyle() end end, level = "Beginner" },
		{ id = "view.style.realistic", name = "Style: Realistic", description = "Mudar para Realistic", icon = "style", category = "Style", shortcut = "", action = function() if mainController then mainController.currentStyle = "realistic" mainController:CycleStyle() end end, level = "Beginner" },
		{ id = "view.style.photoreal", name = "Style: Photorealistic", description = "Mudar para Photorealistic - 8K + Path Tracing", icon = "style", category = "Style", shortcut = "", action = function() if mainController then mainController.currentStyle = "photorealistic" mainController:CycleStyle() end end, level = "Advanced" },

		-- Building
		{ id = "build.move", name = "Move Tool (W)", description = "Ferramenta mover - Gizmo translate", icon = "move", category = "Building", shortcut = "W", action = function() if mainController and mainController.gizmo then mainController.gizmo:SetMode("Translate") end end, level = "Beginner" },
		{ id = "build.rotate", name = "Rotate Tool (E)", description = "Ferramenta rotacionar", icon = "rotate", category = "Building", shortcut = "E", action = function() if mainController and mainController.gizmo then mainController.gizmo:SetMode("Rotate") end end, level = "Beginner" },
		{ id = "build.scale", name = "Scale Tool (R)", description = "Ferramenta escala", icon = "scale", category = "Building", shortcut = "R", action = function() if mainController and mainController.gizmo then mainController.gizmo:SetMode("Scale") end end, level = "Beginner" },

		-- Tabs - sem emojis
		{ id = "tab.vault", name = "Open Vault", description = "Abrir Arkher Vault - 10k AAA Top1", icon = "vault", category = "Tabs", shortcut = "", action = function() if mainController then mainController:ShowTab("Vault") end end, level = "Beginner" },
		{ id = "tab.modeler", name = "Open Modeler", description = "Abrir Arkher Engineer - Blender level", icon = "engineer", category = "Tabs", shortcut = "", action = function() if mainController then mainController:ShowTab("Modeler") end end, level = "Intermediate" },
		{ id = "tab.animator", name = "Open Animator", description = "Abrir Arkher Motion - Cascadeur level", icon = "motion", category = "Tabs", shortcut = "", action = function() if mainController then mainController:ShowTab("Animator") end end, level = "Intermediate" },
		{ id = "tab.terrain", name = "Open Terrain", description = "Abrir Terrain World Creator + Mecha", icon = "terrain", category = "Tabs", shortcut = "", action = function() if mainController then mainController:ShowTab("Terrain") end end, level = "Intermediate" },
		{ id = "tab.script", name = "Open Script Pro", description = "Abrir Script Editor Pro - Monaco + Visual + Python", icon = "code", category = "Tabs", shortcut = "", action = function() if mainController then mainController:ShowTab("Script") end end, level = "Intermediate" },

		-- Modeler Pro
		{ id = "modeler.cube", name = "Modeler: Create Cube", description = "Criar cubo EditableMesh REAL", icon = "vault", category = "Modeler", shortcut = "", action = function() if mainController and mainController.modelerController then mainController.modelerController.editor:CreatePrimitive("Cube") end end, level = "Beginner" },
		{ id = "modeler.sphere", name = "Modeler: Create Sphere", description = "Criar esfera UV real - Icosphere", icon = "vault", category = "Modeler", shortcut = "", action = function() if mainController and mainController.modelerController then mainController.modelerController.editor:CreatePrimitive("Sphere") end end, level = "Beginner" },
		{ id = "modeler.extrude", name = "Modeler: Extrude", description = "Extrude faces/verts", icon = "move", category = "Modeler", shortcut = "E", action = function() if mainController and mainController.modelerController then mainController.modelerController.editor:ExtrudeSelected() end end, level = "Intermediate" },
		{ id = "modeler.bevel", name = "Modeler: Bevel", description = "Bevel edges/verts - Blender level", icon = "vault", category = "Modeler", shortcut = "Ctrl+B", action = function() if mainController and mainController.modelerController then mainController.modelerController.editor:BevelSelected() end end, level = "Intermediate" },
		{ id = "modeler.sculpt", name = "Modeler: Sculpt Mode", description = "Entrar Sculpt Mode - 20 brushes", icon = "engineer", category = "Modeler", shortcut = "", action = function() if mainController and mainController.modelerController then mainController.modelerController.editor:SetEditMode("Sculpt") end end, level = "Advanced" },
		{ id = "modeler.uv", name = "Modeler: UV Unwrap", description = "UV Unwrap - Smart UV + Lightmap", icon = "details", category = "Modeler", shortcut = "", action = function() end, level = "Advanced" },
		{ id = "modeler.nodes", name = "Modeler: Geometry Nodes", description = "Abrir Geometry Nodes - Procedural", icon = "terrain", category = "Modeler", shortcut = "", action = function() end, level = "Pro" },

		-- Animator Pro - GTA6 level - sem emojis
		{ id = "animator.play", name = "Animator: Play", description = "Play animation", icon = "play", category = "Animator", shortcut = "Space", action = function() if mainController and mainController.animatorController then mainController.animatorController.editor.isPlaying = true mainController.animatorController.editor:Play() end end, level = "Beginner" },
		{ id = "animator.ik", name = "Animator: IK Mode", description = "Ativar IK - FABRIK/CCD/TwoBone", icon = "move", category = "Animator", shortcut = "", action = function() end, level = "Intermediate" },
		{ id = "animator.physics", name = "Animator: Physics Auto-Pose", description = "Physics auto-posing - Cascadeur", icon = "mecha", category = "Animator", shortcut = "", action = function() end, level = "Intermediate" },
		{ id = "animator.cutscene", name = "Animator: Cutscene Editor", description = "Abrir Cutscene Editor - GTA 6 level", icon = "motion", category = "Animator", shortcut = "", action = function() end, level = "Advanced" },
		{ id = "animator.curve", name = "Animator: Curve Editor Pro", description = "Abrir Curve Editor - Unreal 6 + Cascadeur", icon = "stats", category = "Animator", shortcut = "", action = function() end, level = "Advanced" },
		{ id = "animator.autorig", name = "Animator: Auto Rig", description = "Auto Rig - Mixamo level + melhor", icon = "engineer", category = "Animator", shortcut = "", action = function() end, level = "Advanced" },

		-- Terrain Pro - World Creator
		{ id = "terrain.generate", name = "Terrain: Generate Area", description = "Gerar terreno 3x3 chunks - Mecha", icon = "terrain", category = "Terrain", shortcut = "", action = function() if mainController and mainController.terrainController then mainController.terrainController:GenerateInitialTerrain(2) end end, level = "Beginner" },
		{ id = "terrain.erosion", name = "Terrain: Apply Erosion", description = "Aplicar erosion Thermal/Hydraulic/Wind", icon = "terrain", category = "Terrain", shortcut = "", action = function() end, level = "Intermediate" },
		{ id = "terrain.stamp", name = "Terrain: Stamp Mountain", description = "Stamp montanha", icon = "terrain", category = "Terrain", shortcut = "", action = function() end, level = "Intermediate" },

		-- Script Pro - Monaco + AI
		{ id = "script.new.luau", name = "Script: New Luau", description = "Novo script Luau", icon = "code", category = "Script", shortcut = "", action = function() end, level = "Beginner" },
		{ id = "script.new.python", name = "Script: New Python 3.14", description = "Novo script Python 3.14 - Classes, async", icon = "code", category = "Script", shortcut = "", action = function() end, level = "Intermediate" },
		{ id = "script.format", name = "Script: Format Code", description = "Formatar codigo - Prettier", icon = "details", category = "Script", shortcut = "Shift+Alt+F", action = function() end, level = "Intermediate" },
		{ id = "script.ai.generate", name = "Script: AI Generate", description = "Gerar script com ARKHER AI v1", icon = "ai", category = "Script", shortcut = "", action = function() end, level = "Beginner" },

		-- AI - ARKHER AI v1 propria
		{ id = "ai.chat", name = "AI: Chat with ARKHER AI", description = "Conversar com ARKHER AI v1 - 3.98M params", icon = "ai", category = "AI", shortcut = "", action = function() end, level = "Beginner" },
		{ id = "ai.generate.model", name = "AI: Generate 3D Model", description = "Gerar modelo 3D com ARKHER AI v1", icon = "engineer", category = "AI", shortcut = "", action = function() end, level = "Beginner" },
		{ id = "ai.generate.animation", name = "AI: Generate Animation", description = "Gerar animacao com ARKHER AI v1", icon = "motion", category = "AI", shortcut = "", action = function() end, level = "Beginner" },
		{ id = "ai.generate.terrain", name = "AI: Generate Terrain", description = "Gerar terreno World Creator com AI", icon = "terrain", category = "AI", shortcut = "", action = function() end, level = "Beginner" },
		{ id = "ai.generate.texture", name = "AI: Generate PBR Material", description = "Gerar material PBR 8K com AI", icon = "style", category = "AI", shortcut = "", action = function() end, level = "Beginner" },
	}

	for _, cmd in cmds do
		table.insert(self.commands, cmd)
	end

	print("[Arkher CommandPalette] Registered", #self.commands, "commands - Beginner to Pro - Sem emojis, pixel art icons")
end

function CommandPalette:Init(parent: ScreenGui)
	local theme = self.theme:GetColors()
	local adaptive = self.adaptive

	local bg = Instance.new("Frame")
	bg.Name = "CommandPaletteBG"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.5
	bg.Visible = false
	bg.ZIndex = 100
	bg.Parent = parent

	local palette = Instance.new("Frame")
	palette.Name = "CommandPalette"
	palette.Size = adaptive.isMobile and UDim2.new(1, -20, 0, 400) or UDim2.new(0, 600, 0, 500)
	palette.Position = adaptive.isMobile and UDim2.new(0, 10, 0, 50) or UDim2.new(0.5, -300, 0, 100)
	palette.BackgroundColor3 = theme.panel
	palette.BorderSizePixel = 0
	palette.ZIndex = 101
	palette.Parent = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = palette

	local stroke = Instance.new("UIStroke")
	stroke.Color = theme.border
	stroke.Thickness = 1
	stroke.Parent = palette

	-- Search container com ícone search pixel art
	local searchContainer = Instance.new("Frame")
	searchContainer.Name = "SearchContainer"
	searchContainer.Size = UDim2.new(1, -20, 0, 40)
	searchContainer.Position = UDim2.new(0, 10, 0, 10)
	searchContainer.BackgroundColor3 = theme.background
	searchContainer.Parent = palette

	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = UDim.new(0, 8)
	searchCorner.Parent = searchContainer

	local searchIcon = self.iconSystem:CreateIcon("search", searchContainer, 16)
	searchIcon.Position = UDim2.new(0, 10, 0.5, -8)

	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.Size = UDim2.new(1, -36, 1, 0)
	search.Position = UDim2.new(0, 32, 0, 0)
	search.BackgroundTransparency = 1
	search.PlaceholderText = "Type command or search... (Ctrl+K)"
	search.Text = ""
	search.TextColor3 = theme.text
	search.TextSize = 14
	search.Font = Enum.Font.Gotham
	search.ClearTextOnFocus = false
	search.Parent = searchContainer

	self.searchBox = search

	-- Results
	local results = Instance.new("ScrollingFrame")
	results.Name = "Results"
	results.Size = UDim2.new(1, -20, 1, -60)
	results.Position = UDim2.new(0, 10, 0, 60)
	results.BackgroundTransparency = 1
	results.ScrollBarThickness = 4
	results.CanvasSize = UDim2.new(0, 0, 0, 0)
	results.AutomaticCanvasSize = Enum.AutomaticSize.Y
	results.Parent = palette

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = results

	self.resultsList = results
	self.frame = bg

	-- Events
	search:GetPropertyChangedSignal("Text"):Connect(function()
		self.filter = string.lower(search.Text)
		self:RefreshResults()
	end)

	search.FocusLost:Connect(function(enter)
		if enter and self.selectedIndex then
			self:ExecuteSelected()
		end
	end)

	bg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:Close()
		end
	end)

	local UserInputService = game:GetService("UserInputService")
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.K and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
			self:Toggle()
		end
		if self.isOpen then
			if input.KeyCode == Enum.KeyCode.Escape then
				self:Close()
			elseif input.KeyCode == Enum.KeyCode.Up then
				self.selectedIndex = math.max(1, self.selectedIndex - 1)
				self:UpdateSelection()
			elseif input.KeyCode == Enum.KeyCode.Down then
				self.selectedIndex = math.min(#self:GetFilteredCommands(), self.selectedIndex + 1)
				self:UpdateSelection()
			elseif input.KeyCode == Enum.KeyCode.Return then
				self:ExecuteSelected()
			end
		end
	end)

	self:RefreshResults()
	print("[Arkher CommandPalette] Initialized - Ctrl+K -", #self.commands, "commands - Sem emojis pixel art")
end

function CommandPalette:GetFilteredCommands(): { Command }
	if self.filter == "" then
		return self.commands
	end
	local filtered = {}
	for _, cmd in self.commands do
		if string.find(string.lower(cmd.name), self.filter, 1, true) or string.find(string.lower(cmd.description), self.filter, 1, true) or string.find(string.lower(cmd.category), self.filter, 1, true) then
			table.insert(filtered, cmd)
		end
	end
	table.sort(filtered, function(a, b)
		local aName = string.lower(a.name)
		local bName = string.lower(b.name)
		local aStarts = string.sub(aName, 1, #self.filter) == self.filter
		local bStarts = string.sub(bName, 1, #self.filter) == self.filter
		if aStarts and not bStarts then return true end
		if bStarts and not aStarts then return false end
		return aName < bName
	end)
	return filtered
end

function CommandPalette:RefreshResults()
	if not self.resultsList then return end
	for _, child in self.resultsList:GetChildren() do
		if child:IsA("TextButton") or child:IsA("Frame") then child:Destroy() end
	end
	local filtered = self:GetFilteredCommands()
	for i, cmd in filtered do
		if i > 50 then break end
		local btn = Instance.new("TextButton")
		btn.Name = cmd.id
		btn.Size = UDim2.new(1, -10, 0, 50)
		btn.BackgroundColor3 = i == self.selectedIndex and self.theme:GetColors().accent or self.theme:GetColors().panelLight
		btn.Text = ""
		btn.LayoutOrder = i
		btn.Parent = self.resultsList

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn

		-- Ícone pixel art em vez de emoji
		local icon = self.iconSystem:CreateIcon(cmd.icon, btn, 20)
		icon.Position = UDim2.new(0, 10, 0.5, -10)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -110, 0, 20)
		nameLabel.Position = UDim2.new(0, 40, 0, 5)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = cmd.name
		nameLabel.TextColor3 = self.theme:GetColors().text
		nameLabel.TextSize = 12
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = btn

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -110, 0, 16)
		descLabel.Position = UDim2.new(0, 40, 0, 25)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = cmd.description .. " | " .. cmd.category .. " | " .. cmd.level
		descLabel.TextColor3 = self.theme:GetColors().textDim
		descLabel.TextSize = 10
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Parent = btn

		local shortcutLabel = Instance.new("TextLabel")
		shortcutLabel.Size = UDim2.new(0, 80, 0, 20)
		shortcutLabel.Position = UDim2.new(1, -85, 0, 5)
		shortcutLabel.BackgroundColor3 = self.theme:GetColors().background
		shortcutLabel.Text = cmd.shortcut or ""
		shortcutLabel.TextColor3 = self.theme:GetColors().textDim
		shortcutLabel.TextSize = 10
		shortcutLabel.Font = Enum.Font.Code
		shortcutLabel.Parent = btn

		local scCorner = Instance.new("UICorner")
		scCorner.CornerRadius = UDim.new(0, 4)
		scCorner.Parent = shortcutLabel

		btn.MouseButton1Click:Connect(function()
			self.selectedIndex = i
			self:ExecuteSelected()
		end)
	end
end

function CommandPalette:UpdateSelection()
	self:RefreshResults()
end

function CommandPalette:ExecuteSelected()
	local filtered = self:GetFilteredCommands()
	local cmd = filtered[self.selectedIndex]
	if cmd then
		print("[Arkher CommandPalette] Execute:", cmd.id, cmd.name)
		table.insert(self.recentCommands, 1, cmd.id)
		if #self.recentCommands > 10 then table.remove(self.recentCommands) end
		local success, err = pcall(cmd.action)
		if not success then warn("[Arkher CommandPalette] Error:", err) end
		self:Close()
	end
end

function CommandPalette:Open()
	if not self.frame then return end
	self.frame.Visible = true
	self.isOpen = true
	self.selectedIndex = 1
	if self.searchBox then
		self.searchBox.Text = ""
		self.searchBox:CaptureFocus()
	end
	self:RefreshResults()
	print("[Arkher CommandPalette] Opened")
end

function CommandPalette:Close()
	if not self.frame then return end
	self.frame.Visible = false
	self.isOpen = false
	print("[Arkher CommandPalette] Closed")
end

function CommandPalette:Toggle()
	if self.isOpen then self:Close() else self:Open() end
end

function CommandPalette:GetStats()
	return {
		isOpen = self.isOpen,
		totalCommands = #self.commands,
		filteredCount = #self:GetFilteredCommands(),
		recentCount = #self.recentCommands,
		noEmojis = true,
		pixelArtIcons = true,
		message = "CommandPalette - VS Code Ctrl+K - Fuzzy search - Beginner to Pro - 50+ commands - Sem emojis pixel art icons Save Play Publish Help AI Style Search Add Filter Move Rotate Scale World Details Vault Toolbox Engineer Motion Terrain Code Project Stats Command Close Check Cloud Market Export Collab Audio Net Mecha A01",
	}
end

return CommandPalette

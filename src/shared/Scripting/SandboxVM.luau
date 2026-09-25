--!strict
-- Arkher Studio - Fase 2 - SandboxVM - VM segura para rodar scripts do usuário
-- Não pode dar game:Shutdown() ou acessar coisas perigosas

local SandboxVM = {}
SandboxVM.__index = SandboxVM

-- Whitelist de funções/globals permitidos
SandboxVM.Whitelist = {
	-- Math
	math = true,
	string = true,
	table = true,
	Vector3 = true,
	Vector2 = true,
	Color3 = true,
	CFrame = true,
	UDim2 = true,
	Enum = true,

	-- Roblox safe
	Instance = true,
	workspace = true,
	game = true, -- mas com metatable protegida

	-- Arkher
	Entity = true,
	Component = true,
	World = true,

	-- Safe globals
	print = true,
	warn = true,
	wait = true,
	task = true,
	tick = true,
	time = true,
	os = true, -- mas só time, date, etc (não execute)

	-- Python compat
	Range = true,
	len = true,
}

-- Blacklist - nunca permitir
SandboxVM.Blacklist = {
	"getfenv",
	"setfenv",
	"loadstring",
	"require", -- só permitir require de módulos Arkher
	"game:Shutdown",
	"game:GetService", -- vamos controlar
	"HttpService",
	"DataStoreService",
	"MarketplaceService",
	"TeleportService",
}

function SandboxVM.new()
	return setmetatable({
		sandboxEnv = {},
		executionCount = 0,
		maxExecutionTime = 5, -- 5 segundos max por script
		maxMemory = 50 * 1024 * 1024, -- 50MB
	}, SandboxVM)
end

function SandboxVM:CreateSandbox(player: Player?): { [string]: any }
	-- Cria ambiente sandbox seguro

	local env: { [string]: any } = {}

	-- Copia whitelist
	env.math = math
	env.string = string
	env.table = table
	env.Vector3 = Vector3
	env.Vector2 = Vector2
	env.Color3 = Color3
	env.CFrame = CFrame
	env.UDim2 = UDim2
	env.Enum = Enum
	env.print = function(...)
		print("[Sandbox]", ...)
	end
	env.warn = function(...)
		warn("[Sandbox]", ...)
	end
	env.wait = task.wait
	env.task = task
	env.tick = tick
	env.time = time
	env.os = {
		time = os.time,
		date = os.date,
		clock = os.clock,
		difftime = os.difftime,
	}

	-- Game protegido
	env.game = setmetatable({}, {
		__index = function(_, key)
			if key == "Players" then
				return game:GetService("Players")
			elseif key == "Workspace" then
				return workspace
			elseif key == "ReplicatedStorage" then
				return game:GetService("ReplicatedStorage")
			elseif key == "RunService" then
				return game:GetService("RunService")
			else
				warn("[Sandbox] Blocked access to game." .. tostring(key))
				return nil
			end
		end,
		__newindex = function()
			warn("[Sandbox] Cannot modify game")
		end,
	})

	env.workspace = workspace
	env.Instance = Instance

	-- Arkher API
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	pcall(function()
		env.Entity = require(ReplicatedStorage.Arkher.ECS.Entity)
		env.Component = require(ReplicatedStorage.Arkher.ECS.Component)
		env.World = require(ReplicatedStorage.Arkher.ECS.World)
	end)

	-- Python compat
	env.Range = function(n)
		local t = {}
		for i=0,n-1 do table.insert(t, i) end
		return t
	end

	env.len = function(t)
		if type(t) == "string" then return #t end
		if type(t) == "table" then return #t end
		return 0
	end

	-- Player se tiver
	if player then
		env.player = player
		env.LocalPlayer = player
	end

	-- Metatable que bloqueia acesso a globals não whitelistados
	setmetatable(env, {
		__index = function(_, key)
			if SandboxVM.Whitelist[key] then
				return _G[key]
			else
				warn("[Sandbox] Blocked access to global:", key)
				return nil
			end
		end,
	})

	self.sandboxEnv = env
	return env
end

function SandboxVM:CheckBlacklist(code: string): (boolean, string?)
	-- Verifica se código contém blacklist

	for _, blocked in SandboxVM.Blacklist do
		if string.find(code, blocked, 1, true) then
			-- Exceção: permite game:GetService se for Players, Workspace, etc (já filtrado no metatable)
			if blocked == "game:GetService" then
				-- Deixa passar, metatable vai filtrar
			else
				return false, "Blocked keyword found: " .. blocked
			end
		end
	end

	-- Verifica loadstring, require suspeito
	if string.find(code, "require%(%d+%)") then
		return false, "Blocked: require with asset ID (possible virus)"
	end

	if string.find(code, "getfenv") or string.find(code, "setfenv") then
		return false, "Blocked: getfenv/setfenv not allowed"
	end

	return true, nil
end

function SandboxVM:Execute(code: string, player: Player?, timeout: number?): (boolean, any)
	-- Executa código em sandbox com timeout

	timeout = timeout or self.maxExecutionTime

	-- Checa blacklist
	local allowed, reason = self:CheckBlacklist(code)
	if not allowed then
		warn("[Sandbox] Blocked execution:", reason)
		return false, reason
	end

	-- Cria sandbox
	local env = self:CreateSandbox(player)

	-- Compila
	local func, loadErr = loadstring(code)
	if not func then
		warn("[Sandbox] Load error:", loadErr)
		return false, "Load error: " .. tostring(loadErr)
	end

	setfenv(func, env)

	-- Executa com timeout
	self.executionCount += 1

	local completed = false
	local success, result

	task.spawn(function()
		success, result = pcall(func)
		completed = true
	end)

	-- Espera com timeout
	local start = os.clock()
	while not completed and os.clock() - start < timeout do
		task.wait(0.1)
	end

	if not completed then
		warn("[Sandbox] Execution timeout after", timeout, "seconds")
		return false, "Execution timeout"
	end

	if not success then
		warn("[Sandbox] Runtime error:", result)
		return false, "Runtime error: " .. tostring(result)
	end

	print("[Sandbox] Executed successfully -", #code, "bytes - Player:", player and player.Name or "server")

	return true, result
end

function SandboxVM:ExecuteWithResult(code: string, player: Player?): { success: boolean, result: any?, error: string?, logs: { string } }
	local logs: { string } = {}

	-- Captura prints
	local oldPrint = print
	local capturedEnv = self:CreateSandbox(player)
	capturedEnv.print = function(...)
		local msg = table.concat({...}, " ")
		table.insert(logs, msg)
		oldPrint("[Sandbox]", msg)
	end

	local func, loadErr = loadstring(code)
	if not func then
		return { success = false, error = "Load error: " .. tostring(loadErr), logs = logs }
	end

	setfenv(func, capturedEnv)

	local success, result = pcall(func)

	if not success then
		return { success = false, error = tostring(result), logs = logs }
	end

	return { success = true, result = result, logs = logs }
end

function SandboxVM:GetStats(): { [string]: any }
	return {
		executionCount = self.executionCount,
		maxExecutionTime = self.maxExecutionTime,
		maxMemoryMB = self.maxMemory / 1024 / 1024,
		whitelistCount = 0, -- conta
		blacklistCount = #SandboxVM.Blacklist,
	}
end

return SandboxVM

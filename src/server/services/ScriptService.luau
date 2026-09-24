--!strict
-- Arkher Studio - Fase 2 - ScriptService - Roda scripts do usuário no server com sandbox

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SandboxVM = require(ReplicatedStorage.Arkher.Scripting.SandboxVM)

local ScriptService = {}
ScriptService.__index = ScriptService

function ScriptService.new()
	return setmetatable({
		sandbox = SandboxVM.new(),
		runningScripts = {} :: { [string]: any },
	}, ScriptService)
end

function ScriptService:Init()
	print("[Arkher ScriptService] Initialized - SandboxVM ready - Luau + Python 3.14")
end

function ScriptService:RunScript(entityId: string, source: string, language: string, player: Player?): boolean
	print(string.format("[Arkher ScriptService] Running script %s - Language: %s - %d bytes", entityId, language, #source))

	-- Se for Python, transpila primeiro
	local codeToRun = source

	if language == "python" or string.find(source, "from arkher import") then
		local PythonTranspiler = require(ReplicatedStorage.Arkher.Scripting.PythonTranspiler)
		local transpiler = PythonTranspiler.new()
		local luauCode, err = transpiler:Transpile(source)

		if not luauCode then
			warn("[Arkher ScriptService] Python transpile failed:", err)
			return false
		end

		codeToRun = luauCode
		print("[Arkher ScriptService] Python transpiled to Luau -", #luauCode, "bytes")
	end

	-- Roda em sandbox
	local success, result = self.sandbox:Execute(codeToRun, player, 5)

	if success then
		self.runningScripts[entityId] = {
			source = source,
			language = language,
			startedAt = os.time(),
			player = player and player.UserId or 0,
		}
		print("[Arkher ScriptService] Script", entityId, "running")
		return true
	else
		warn("[Arkher ScriptService] Script", entityId, "failed:", result)
		return false
	end
end

function ScriptService:StopScript(entityId: string)
	if self.runningScripts[entityId] then
		self.runningScripts[entityId] = nil
		print("[Arkher ScriptService] Stopped script", entityId)
	end
end

function ScriptService:StopAllScripts()
	self.runningScripts = {}
	print("[Arkher ScriptService] Stopped all scripts")
end

function ScriptService:GetRunningScripts(): { any }
	return self.runningScripts
end

return ScriptService

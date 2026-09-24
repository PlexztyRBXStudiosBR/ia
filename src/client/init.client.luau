--!strict
-- Arkher Studio - Client Bootstrap
-- Entry point do cliente

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Espera Arkher carregar
ReplicatedStorage:WaitForChild("Arkher")
ReplicatedStorage:WaitForChild("ArkherClient")

local MainController = require(ReplicatedStorage.ArkherClient.controllers.MainController)

print("[Arkher Bootstrap] Starting Arkher Studio...")

local controller = MainController.new()

-- Inicializa com delay pra garantir que tudo carregou
task.wait(1)

local success, err = pcall(function()
	controller:Init()
end)

if not success then
	warn("[Arkher Bootstrap] Failed to init MainController:", err)
else
	print("[Arkher Bootstrap] Arkher Studio Alpha 0.1 started successfully!")

	-- Expõe globalmente para debug no console (F9)
	_G.Arkher = controller
	_G.ArkherStats = function()
		print(controller:GetStats())
		return controller:GetStats()
	end

	print("[Arkher] Type _G.ArkherStats() in console (F9) to see stats")
	print("[Arkher] Type _G.Arkher:CycleStyle() to change style")
end

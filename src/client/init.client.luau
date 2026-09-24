--!strict
-- Arkher Studio - Client Bootstrap
-- Entry point do cliente

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Espera Arkher carregar
ReplicatedStorage:WaitForChild("Arkher")
ReplicatedStorage:WaitForChild("ArkherClient")

-- Try V2 polished first, fallback to V1
local MainControllerV2 = nil
local MainController = nil

pcall(function()
	MainControllerV2 = require(ReplicatedStorage.ArkherClient.controllers.MainControllerV2)
end)

if not MainControllerV2 then
	MainController = require(ReplicatedStorage.ArkherClient.controllers.MainController)
end

local controllerModule = MainControllerV2 or MainController
local versionName = MainControllerV2 and "ALPHA 0.7 POLISHED - UI amigavel + Monaco Pro + Engineer Blender++ + Motion GTA 6 + ARKHER AI v1" or "ALPHA 0.6"

print("[Arkher Bootstrap] Starting Arkher Studio", versionName, "...")
print("[Arkher Bootstrap] Polished: Beginner/Intermediate/Advanced/Pro + Mobile A01 ate 8K + Monaco Pro 25 plugins + Engineer Blender++ 60+ tools + Motion GTA 6 + ARKHER AI v1 propria 3.98M params + Physics atomic/quantum")

local controller = controllerModule.new()

-- Inicializa com delay pra garantir que tudo carregou
task.wait(1)

local success, err = pcall(function()
	controller:Init()
end)

if not success then
	warn("[Arkher Bootstrap] Failed to init MainController:", err)
	-- Fallback to V1 if V2 fails
	if MainControllerV2 and MainController then
		print("[Arkher Bootstrap] Trying fallback to V1...")
		local fallback = MainController.new()
		local s2, e2 = pcall(function() fallback:Init() end)
		if s2 then
			print("[Arkher Bootstrap] Fallback V1 started!")
			_G.Arkher = fallback
			_G.ArkherStats = function() print(fallback:GetStats()) return fallback:GetStats() end
			_G.ArkherV2 = controller
			controller = fallback
		else
			warn("[Arkher Bootstrap] Fallback also failed:", e2)
		end
	end
else
	print("[Arkher Bootstrap] Arkher Studio", versionName, "started successfully! Polished!")

	-- Expõe globalmente para debug no console (F9)
	_G.Arkher = controller
	_G.ArkherV2 = controller
	_G.ArkherStats = function()
		local stats = controller:GetStats()
		print(stats)
		return stats
	end

	_G.ArkherCycleLevel = function()
		if controller.CycleLevel then controller:CycleLevel() end
	end

	_G.ArkherAIChat = function(msg)
		if controller.arkherAI then
			return controller.arkherAI:Chat(msg or "Ola ARKHER AI v1!")
		end
	end

	_G.ArkherGenerateModel = function(prompt)
		if controller.arkherAI then
			return controller.arkherAI:GenerateModel(prompt or "katana cyberpunk ultra realista")
		end
	end

	print("[Arkher] Type _G.ArkherStats() in console (F9) to see stats - Polished")
	print("[Arkher] Type _G.Arkher:CycleStyle() to change style - LowPoly to Photorealistic")
	print("[Arkher] Type _G.ArkherCycleLevel() to cycle Beginner/Intermediate/Advanced/Pro")
	print("[Arkher] Type _G.ArkherAIChat('cria modelo 3D') to chat with ARKHER AI v1 propria 3.98M params")
	print("[Arkher] Type _G.ArkherGenerateModel('katana cyberpunk') to generate 3D with ARKHER AI v1")
	print("[Arkher] Polished: UI amigavel + Monaco Pro 25 plugins + Engineer Blender++ 60+ tools + Motion GTA 6 + ARKHER AI v1 propria + Physics atomic/quantum - Inspira realidade top 1")
end

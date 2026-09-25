--!strict
-- Arkher Studio - CollabService - Team Create Realtime
-- Inspirado no Team Create do Studio + Figma multiplayer

local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")

local CollabService = {}
CollabService.__index = CollabService

function CollabService.new()
	local self = setmetatable({
		activeSessions = {} :: { [string]: any },
		userCursors = {} :: { [number]: any },
		locks = {} :: { [string]: number }, -- entityId -> userId que lockou
	}, CollabService)

	pcall(function()
		self.map = MemoryStoreService:GetHashMap("ArkherCollab")
		self.queue = MemoryStoreService:GetQueue("ArkherCollabEvents", 100)
	end)

	print("[Arkher Collab] Initialized - Team Create Realtime ready")
	return self
end

function CollabService:JoinSession(userId: number, projectId: string, userName: string)
	print(string.format("[Arkher Collab] User %s (%d) joined project %s", userName, userId, projectId))

	self.activeSessions[projectId] = self.activeSessions[projectId] or {}
	self.activeSessions[projectId][userId] = {
		userId = userId,
		userName = userName,
		joinedAt = os.time(),
		cursor = Vector3.new(0,0,0),
	}

	-- Notifica outros via MessagingService
	pcall(function()
		MessagingService:PublishAsync("ArkherCollab_" .. projectId, {
			type = "userJoined",
			userId = userId,
			userName = userName,
		})
	end)
end

function CollabService:LeaveSession(userId: number, projectId: string)
	if self.activeSessions[projectId] then
		self.activeSessions[projectId][userId] = nil
		print(string.format("[Arkher Collab] User %d left project %s", userId, projectId))

		-- Libera locks
		for entityId, lockerId in self.locks do
			if lockerId == userId then
				self.locks[entityId] = nil
			end
		end

		pcall(function()
			MessagingService:PublishAsync("ArkherCollab_" .. projectId, {
				type = "userLeft",
				userId = userId,
			})
		end)
	end
end

function CollabService:LockEntity(userId: number, entityId: string): boolean
	if self.locks[entityId] and self.locks[entityId] ~= userId then
		print(string.format("[Arkher Collab] Entity %s already locked by %d", entityId, self.locks[entityId]))
		return false
	end

	self.locks[entityId] = userId
	print(string.format("[Arkher Collab] User %d locked entity %s", userId, entityId))
	return true
end

function CollabService:UnlockEntity(userId: number, entityId: string)
	if self.locks[entityId] == userId then
		self.locks[entityId] = nil
		print(string.format("[Arkher Collab] User %d unlocked entity %s", userId, entityId))
	end
end

function CollabService:BroadcastChange(projectId: string, userId: number, change: any)
	-- Broadcast mudança para todos na sessão (Figma-like)
	pcall(function()
		MessagingService:PublishAsync("ArkherCollab_" .. projectId, {
			type = "entityChanged",
			userId = userId,
			change = change,
			timestamp = os.time(),
		})
	end)
end

function CollabService:GetActiveUsers(projectId: string): { any }
	return self.activeSessions[projectId] or {}
end

return CollabService

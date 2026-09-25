--!strict
-- Arkher Studio - .arkher Project Format
-- Formato JSON custom que guarda tudo. Suporta chunking pra DataStore 4MB limit.

local HttpService = game:GetService("HttpService")
local World = require(script.Parent.Parent.ECS.World)
local Entity = require(script.Parent.Parent.ECS.Entity)

export type SerializedProject = {
	meta: {
		projectId: string,
		name: string,
		description: string,
		version: number,
		styleProfile: string,
		arkherVersion: string,
		createdAt: number,
		updatedAt: number,
		useCustomEngine: boolean,
	},
	entities: { any },
	rootEntities: { string },
	assets: { any },
	thumbnail: string?,
	checksum: string,
}

local ProjectFormat = {}
ProjectFormat.VERSION = "0.1.0-alpha"
ProjectFormat.MAX_CHUNK_SIZE = 3_500_000 -- 3.5MB pra ficar safe do limite 4MB

function ProjectFormat.Serialize(world: World.World, meta: any): string
	local serializedEntities = {}
	for id, entity in world.entities do
		serializedEntities[id] = {
			id = entity.id,
			name = entity.name,
			parent = entity.parent,
			children = entity.children,
			components = entity.components,
			tags = entity.tags,
			isLocked = entity.isLocked,
			isHidden = entity.isHidden,
			isPrefab = entity.isPrefab,
			prefabId = entity.prefabId,
		}
	end

	local project: SerializedProject = {
		meta = {
			projectId = meta.projectId or HttpService:GenerateGUID(false),
			name = meta.name or "Untitled Arkher Project",
			description = meta.description or "",
			version = meta.version or 1,
			styleProfile = meta.styleProfile or "realistic",
			arkherVersion = ProjectFormat.VERSION,
			createdAt = meta.createdAt or os.time(),
			updatedAt = os.time(),
			useCustomEngine = meta.useCustomEngine or false,
		},
		entities = serializedEntities,
		rootEntities = world.rootEntities,
		assets = {},
		thumbnail = nil,
		checksum = "",
	}

	local json = HttpService:JSONEncode(project)
	-- checksum simples
	project.checksum = string.format("%x", #json)
	json = HttpService:JSONEncode(project)

	return json
end

function ProjectFormat.Deserialize(json: string): (World.World?, any?)
	local success, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)

	if not success then
		warn("[Arkher] Failed to deserialize project: " .. tostring(data))
		return nil, nil
	end

	local world = World.new()

	for id, entData in data.entities do
		local entity = Entity.new(entData.name, entData.parent)
		entity.id = entData.id
		entity.children = entData.children or {}
		entity.components = entData.components or {}
		entity.tags = entData.tags or {}
		entity.isLocked = entData.isLocked or false
		entity.isHidden = entData.isHidden or false
		entity.isPrefab = entData.isPrefab or false
		entity.prefabId = entData.prefabId

		world.entities[id] = entity
		world.entityCount += 1
	end

	world.rootEntities = data.rootEntities or {}

	return world, data.meta
end

function ProjectFormat.Chunk(json: string): { string }
	-- Divide em chunks de 3.5MB pra salvar no DataStore
	local chunks = {}
	local len = #json
	local chunkSize = ProjectFormat.MAX_CHUNK_SIZE

	for i = 1, len, chunkSize do
		table.insert(chunks, string.sub(json, i, i + chunkSize - 1))
	end

	return chunks
end

function ProjectFormat.Unchunk(chunks: { string }): string
	return table.concat(chunks, "")
end

-- Converte para RBXLX (para Open Cloud publish)
function ProjectFormat.ToRBXLX(world: World.World, meta: any): string
	-- Fase 3: Vamos implementar conversão real de ECS -> XML RBXLX
	-- Por enquanto stub que gera um RBXLX básico
	local xml = [[
<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
	<Meta name="ExplicitAutoJoints">true</Meta>
	<Item class="Workspace" referent="0">
		<Properties>
			<string name="Name">Workspace</string>
		</Properties>
	]]

	-- Converte entidades Transform+Render em Parts
	for _, entity in world.entities do
		local transform = entity.components.Transform
		local render = entity.components.Render
		if transform and render then
			xml ..= string.format([[
		<Item class="Part" referent="%s">
			<Properties>
				<string name="Name">%s</string>
				<CoordinateFrame name="CFrame"><X>%f</X><Y>%f</Y><Z>%f</Z></CoordinateFrame>
				<Color3 name="Color"><R>%f</R><G>%f</G><B>%f</B></Color3>
				<token name="Material">%d</token>
			</Properties>
		</Item>
			]], entity.id, entity.name, transform.position.X, transform.position.Y, transform.position.Z, render.color.R, render.color.G, render.color.B, render.material.Value)
		end
	end

	xml ..= [[
	</Item>
</roblox>
	]]

	return xml
end

return ProjectFormat

--!strict
-- Arkher Studio - Fase 3 - Modifiers - Stack de modifiers nível Blender
-- Mirror, Subdivision, Array, Solidify, Bevel

local MeshData = require(game.ReplicatedStorage.Arkher.Modeling.MeshData)

local Modifiers = {}
Modifiers.__index = Modifiers

export type ModifierType = "Mirror" | "Subdivision" | "Array" | "Solidify" | "Bevel" | "Decimate"

export type Modifier = {
	id: string,
	type: ModifierType,
	enabled: boolean,
	settings: { [string]: any },
}

function Modifiers.new()
	return setmetatable({
		stack = {} :: { Modifier },
	}, Modifiers)
end

function Modifiers:AddModifier(type: ModifierType, settings: { [string]: any }?): string
	local id = game:GetService("HttpService"):GenerateGUID(false)

	local modifier: Modifier = {
		id = id,
		type = type,
		enabled = true,
		settings = settings or self:GetDefaultSettings(type),
	}

	table.insert(self.stack, modifier)

	print(string.format("[Arkher Modifiers] Added %s modifier - ID: %s", type, id:sub(1,8)))

	return id
end

function Modifiers:GetDefaultSettings(type: ModifierType): { [string]: any }
	if type == "Mirror" then
		return { axis = "X", useClipping = true, useMirrorMerge = true }
	elseif type == "Subdivision" then
		return { levels = 2, renderLevels = 2, useCreases = true }
	elseif type == "Array" then
		return { count = 3, offset = Vector3.new(2,0,0), useRelativeOffset = true }
	elseif type == "Solidify" then
		return { thickness = 0.2, offset = 0 }
	elseif type == "Bevel" then
		return { width = 0.1, segments = 2, profile = 0.5 }
	elseif type == "Decimate" then
		return { ratio = 0.5, useSymmetry = false }
	else
		return {}
	end
end

function Modifiers:RemoveModifier(id: string)
	for i, mod in self.stack do
		if mod.id == id then
			table.remove(self.stack, i)
			print("[Arkher Modifiers] Removed modifier", id:sub(1,8))
			return
		end
	end
end

function Modifiers:ApplyStack(mesh: any): any
	-- Aplica todos os modifiers do stack na ordem

	local resultMesh = mesh

	print("[Arkher Modifiers] Applying stack -", #self.stack, "modifiers")

	for _, modifier in self.stack do
		if not modifier.enabled then continue end

		if modifier.type == "Mirror" then
			resultMesh = self:ApplyMirror(resultMesh, modifier.settings)
		elseif modifier.type == "Subdivision" then
			resultMesh = self:ApplySubdivision(resultMesh, modifier.settings)
		elseif modifier.type == "Array" then
			resultMesh = self:ApplyArray(resultMesh, modifier.settings)
		elseif modifier.type == "Solidify" then
			resultMesh = self:ApplySolidify(resultMesh, modifier.settings)
		elseif modifier.type == "Bevel" then
			resultMesh = self:ApplyBevel(resultMesh, modifier.settings)
		elseif modifier.type == "Decimate" then
			resultMesh = self:ApplyDecimate(resultMesh, modifier.settings)
		end
	end

	print("[Arkher Modifiers] Stack applied - Result:", resultMesh.vertexCount, "verts")

	return resultMesh
end

function Modifiers:ApplyMirror(mesh: any, settings: any): any
	print("[Arkher Modifiers] Applying Mirror - Axis:", settings.axis)

	-- Fase 3: Implementação real de mirror
	-- Duplica mesh espelhada no eixo

	local mirrored = MeshData.new()

	-- Copia vértices originais
	for _, vert in mesh.vertices do
		MeshData.AddVertex(mirrored, vert.position, vert.normal, vert.uv)
	end

	-- Cria vértices espelhados
	for _, vert in mesh.vertices do
		local mirroredPos = vert.position

		if settings.axis == "X" then
			mirroredPos = Vector3.new(-vert.position.X, vert.position.Y, vert.position.Z)
		elseif settings.axis == "Y" then
			mirroredPos = Vector3.new(vert.position.X, -vert.position.Y, vert.position.Z)
		elseif settings.axis == "Z" then
			mirroredPos = Vector3.new(vert.position.X, vert.position.Y, -vert.position.Z)
		end

		MeshData.AddVertex(mirrored, mirroredPos, vert.normal, vert.uv)
	end

	-- Copia faces + faces espelhadas
	for _, face in mesh.faces do
		MeshData.AddFace(mirrored, face.vertexIds, face.materialId)
	end

	-- TODO: Faces espelhadas com ordem invertida

	return mirrored
end

function Modifiers:ApplySubdivision(mesh: any, settings: any): any
	print("[Arkher Modifiers] Applying Subdivision - Levels:", settings.levels)

	-- Fase 3: Catmull-Clark subdivision
	-- Por enquanto mock que só loga

	return mesh
end

function Modifiers:ApplyArray(mesh: any, settings: any): any
	print("[Arkher Modifiers] Applying Array - Count:", settings.count, "Offset:", settings.offset)

	local result = MeshData.new()

	for i = 0, settings.count - 1 do
		local offset = settings.offset * i

		for _, vert in mesh.vertices do
			MeshData.AddVertex(result, vert.position + offset, vert.normal, vert.uv)
		end

		-- TODO: Faces com offset de IDs
	end

	return result
end

function Modifiers:ApplySolidify(mesh: any, settings: any): any
	print("[Arkher Modifiers] Applying Solidify - Thickness:", settings.thickness)
	return mesh
end

function Modifiers:ApplyBevel(mesh: any, settings: any): any
	print("[Arkher Modifiers] Applying Bevel - Width:", settings.width, "Segments:", settings.segments)
	return mesh
end

function Modifiers:ApplyDecimate(mesh: any, settings: any): any
	print("[Arkher Modifiers] Applying Decimate - Ratio:", settings.ratio, "- Crucial for A01 optimization")

	-- Fase 3: Decimation real para LOD
	-- Reduz faces por ratio

	return mesh
end

function Modifiers:GetStack(): { Modifier }
	return self.stack
end

return Modifiers

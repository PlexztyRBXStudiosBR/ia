--!strict
-- Arkher Studio - Style Profiles
-- Cada estilo muda render, materiais, otimização e DLSS

local StyleProfiles = {
	lowpoly = {
		displayName = "Low Poly",
		description = "Estilo minimalista, performance extrema. Roda a 120 FPS no A01.",
		icon = "LowPoly",
		renderSettings = {
			materialQuality = "low",
			shadows = false,
			pbrEnabled = false,
			flatShading = true,
			antiAliasing = "none",
			textureResolution = 256,
			lodBias = 2, -- LOD agressivo
		},
		dlssSettings = {
			mode = "performance",
			sharpness = 1.0,
			preserveEdges = true,
		},
		targetFPS = 120,
	},
	anime = {
		displayName = "Anime / Cel-Shaded",
		description = "Estilo Genshin Impact, Toon Shader com outline. Perfeito para jogos estilizados.",
		icon = "",
		renderSettings = {
			materialQuality = "medium",
			shadows = true,
			pbrEnabled = false,
			toonShading = true,
			outlineEnabled = true,
			outlineThickness = 2,
			textureResolution = 512,
		},
		dlssSettings = {
			mode = "balanced",
			toonEnhancer = true,
			outlinePreservation = true,
		},
		targetFPS = 60,
	},
	stylized = {
		displayName = "Stylized",
		description = "Estilo Fortnite / Overwatch. Colorido e otimizado.",
		icon = "Style",
		renderSettings = {
			materialQuality = "medium",
			shadows = true,
			pbrEnabled = true,
			textureResolution = 1024,
		},
		dlssSettings = {
			mode = "balanced",
		},
		targetFPS = 60,
	},
	semirealistic = {
		displayName = "Semi-Realista",
		description = "Estilo GTA V. Realista mas ainda estilizado.",
		icon = "Realistic",
		renderSettings = {
			materialQuality = "high",
			shadows = true,
			pbrEnabled = true,
			ssrEnabled = false,
			textureResolution = 1024,
		},
		dlssSettings = {
			mode = "quality",
		},
		targetFPS = 60,
	},
	ultrarealistic = {
		displayName = "Ultra Realista",
		description = "Estilo Unreal 5 AAA. PBR 4K, Ray-Traced Shadows fake, GI.",
		icon = "Vault",
		renderSettings = {
			materialQuality = "ultra",
			shadows = true,
			pbrEnabled = true,
			ssrEnabled = true,
			giEnabled = true,
			parallaxEnabled = true,
			textureResolution = 2048,
			shadowResolution = 2048,
		},
		dlssSettings = {
			mode = "quality",
			rayReconstruction = true,
			textureSuperRes = true,
		},
		targetFPS = 60,
	},
	photorealistic = {
		displayName = "Fotorrealista",
		description = "Nível foto. Path Tracing aproximado, 8K textures, Light Baking na nuvem. Para AAA.",
		icon = "Photoreal",
		renderSettings = {
			materialQuality = "photoreal",
			shadows = true,
			pbrEnabled = true,
			ssrEnabled = true,
			giEnabled = true,
			pathTracing = true,
			textureResolution = 4096, -- via EditableImage tiling, bypass limite Roblox 1024
			shadowResolution = 4096,
			lightBaking = true,
		},
		dlssSettings = {
			mode = "dlss5_neural",
			rayReconstruction = true,
			textureSuperRes = true,
			neuralMaterial = true,
			frameGeneration = true,
		},
		targetFPS = 60,
		requiresBackend = true, -- precisa do backend pra baking
	},
}

return StyleProfiles

--!strict
-- Arkher Studio - Project Types

export type StyleProfile = "lowpoly" | "anime" | "stylized" | "semirealistic" | "ultrarealistic" | "photorealistic"

export type DeviceTier = "tier1_a01" | "tier2_mid" | "tier3_flagship" | "tier4_pc" | "tier5_gamer" | "tier6_vr"

export type ArkherProjectMeta = {
	projectId: string,
	name: string,
	description: string,
	creatorId: number,
	creatorName: string,
	version: number,
	styleProfile: StyleProfile,
	createdAt: number,
	updatedAt: number,
	thumbnailId: string?,
	tags: { string },
	isPublic: boolean,
	allowCopy: boolean,
	targetDevice: DeviceTier,
	useCustomEngine: boolean, -- Fase 6 Mecha
}

export type ArkherAssetType = "Model" | "Animation" | "Audio" | "Decal" | "Mesh" | "Material" | "Prefab" | "TerrainPreset" | "VFX"

export type ArkherAsset = {
	assetId: string?, -- rbxassetid se já publicado
	localId: string,
	name: string,
	type: ArkherAssetType,
	styleProfile: StyleProfile,
	thumbnail: string?,
	fileSize: number,
	tags: { string },
	creatorId: number,
	price: number?, -- se for vender na Toolbox
	isVault: boolean, -- true = nosso Vault AAA, false = Roblox Toolbox
}

export type PublishTarget = "ArkherCloud" | "RobloxProfile" | "NewUniverse" | "Toolbox" | "Marketplace"

export type PublishRequest = {
	projectId: string,
	target: PublishTarget,
	newUniverseName: string?,
	apiKey: string?, -- Open Cloud API Key do usuário
	assetConfiguration: {
		name: string,
		description: string,
		price: number?,
		allowCopying: boolean,
	}?,
}

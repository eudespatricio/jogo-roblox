--!strict
-- IDs de textura de VFX (flipbooks 8x8/4x4, aneis, fumaca, decals elementais, beams de raio/trilha)
-- gerados pelo pipeline Forge3D e publicados via Open Cloud. Enquanto o ID for 0, o Vfx.luau usa o
-- fallback procedural (zero regressao). Puramente visual: nao toca simVersion/schema/content.

local VfxAssets = {}

export type FlipbookSpec = {
	layout: "Grid8x8" | "Grid4x4",
	fps: number,
	frames: number,
	mode: "OneShot" | "Loop",
}

VfxAssets.IDS = {
	explosionFlipbook = 135806600858236,
	frostShatterFlipbook = 78186543651102,
	arcaneRiftFlipbook = 86991264053603,
	fireLoopFlipbook = 135806600858236,
	slashSparkFlipbook = 138298598490067,
	shockwaveRing = 117111013389651,
	softGlowFlare = 118635363180451,
	smokeWispy = 127020451371444,
	scorchCraterDecal = 94843811733582,
	beamEnergyTrail = 100334877599740,
	tarPuddleDecal = 94843811733582,
	frostGroundDecal = 78186543651102,
	bossRuneDecal = 117111013389651,
	lightningArcBeam = 100334877599740,
} :: { [string]: number }

VfxAssets.FLIPBOOK = table.freeze({ grid = "Grid8x8", fps = 36 })

local DEFAULT_FLIPBOOK_SPEC: FlipbookSpec = table.freeze({
	layout = "Grid8x8",
	fps = 36,
	frames = 64,
	mode = "OneShot",
} :: FlipbookSpec)

local FLIPBOOK_SPECS: { [string]: FlipbookSpec } = table.freeze({
	explosionFlipbook = table.freeze({
		layout = "Grid8x8",
		fps = 36,
		frames = 64,
		mode = "OneShot",
	} :: FlipbookSpec),
	frostShatterFlipbook = table.freeze({
		layout = "Grid8x8",
		fps = 36,
		frames = 64,
		mode = "OneShot",
	} :: FlipbookSpec),
	arcaneRiftFlipbook = table.freeze({
		layout = "Grid8x8",
		fps = 36,
		frames = 64,
		mode = "OneShot",
	} :: FlipbookSpec),
	fireLoopFlipbook = table.freeze({
		layout = "Grid8x8",
		fps = 36,
		frames = 64,
		mode = "Loop",
	} :: FlipbookSpec),
	slashSparkFlipbook = table.freeze({
		layout = "Grid4x4",
		fps = 28,
		frames = 16,
		mode = "OneShot",
	} :: FlipbookSpec),
} :: { [string]: FlipbookSpec })

function VfxAssets.flipbookSpec(key: string): FlipbookSpec
	return FLIPBOOK_SPECS[key] or DEFAULT_FLIPBOOK_SPEC
end

-- "rbxassetid://<id>" se publicado (id > 0); "" caso contrario.
function VfxAssets.contentId(key: string): string
	local id = VfxAssets.IDS[key]
	if id ~= nil and id > 0 then
		return "rbxassetid://" .. tostring(id)
	end
	return ""
end

return VfxAssets

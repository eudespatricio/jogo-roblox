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
	explosionFlipbook = 96367387479111,
	frostShatterFlipbook = 76652120953457,
	arcaneRiftFlipbook = 118011167341061,
	fireLoopFlipbook = 115210968282968,
	slashSparkFlipbook = 127105771893736,
	shockwaveRing = 125080748846211,
	softGlowFlare = 114560666216761,
	smokeWispy = 116350659654009,
	scorchCraterDecal = 111028655867508,
	beamEnergyTrail = 77063707563729,
	tarPuddleDecal = 102779989457126,
	frostGroundDecal = 126889400767479,
	bossRuneDecal = 103170026384574,
	lightningArcBeam = 95285396297301,
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

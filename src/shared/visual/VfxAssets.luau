--!strict
-- IDs de textura de VFX (flipbooks, aneis, fumaca, decals, trilhas) gerados pelo pipeline Forge3D e
-- publicados via Open Cloud. Enquanto o ID for 0, o Vfx.luau usa o fallback procedural
-- (zero regressao). Puramente visual: nao toca simVersion/schema/content.

local VfxAssets = {}

VfxAssets.IDS = {
	explosionFlipbook = 0,
	frostShatterFlipbook = 0,
	arcaneRiftFlipbook = 0,
	slashSparkFlipbook = 0,
	shockwaveRing = 0,
	softGlowFlare = 0,
	smokeWispy = 0,
	scorchCraterDecal = 0,
	beamEnergyTrail = 0,
} :: { [string]: number }

VfxAssets.FLIPBOOK = table.freeze({ grid = "Grid4x4", fps = 28 })

-- "rbxassetid://<id>" se publicado (id > 0); "" caso contrario.
function VfxAssets.contentId(key: string): string
	local id = VfxAssets.IDS[key]
	if id ~= nil and id > 0 then
		return "rbxassetid://" .. tostring(id)
	end
	return ""
end

return VfxAssets

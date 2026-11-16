--!strict
-- IDs de textura de VFX (flipbooks, aneis, fumaca, decals, trilhas) gerados pelo pipeline Forge3D e
-- publicados via Open Cloud. Enquanto o ID for 0, o Vfx.luau usa o fallback procedural
-- (zero regressao). Puramente visual: nao toca simVersion/schema/content.

local VfxAssets = {}

VfxAssets.IDS = {
	explosionFlipbook = 135806600858236,
	frostShatterFlipbook = 78186543651102,
	arcaneRiftFlipbook = 86991264053603,
	slashSparkFlipbook = 138298598490067,
	shockwaveRing = 117111013389651,
	softGlowFlare = 118635363180451,
	smokeWispy = 127020451371444,
	scorchCraterDecal = 94843811733582,
	beamEnergyTrail = 100334877599740,
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

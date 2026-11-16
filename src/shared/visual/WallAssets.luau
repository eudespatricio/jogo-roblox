--!strict
-- Muralha em malha (Forge3D, rota import) publicada via Open Cloud em 13/11/2026.
-- Fonte: art/scripts/make_wall_bastion.py -> art/forge/lote_muralha_import.yaml (QC G1-G10 ok).
-- Puramente visual: nao toca simVersion/schema/content. Sem malha carregada, ArenaVisual
-- mantem a muralha de blocos (fallback).

local WallAssets = {}

WallAssets.FOLDER = "MuralhaAssets"
WallAssets.TIER_ATTRIBUTE = "MuralhaWallTier"
WallAssets.MAX_TIER = 5

WallAssets.ASSET_IDS = table.freeze({
	108958209345521, -- WALL_bastion_l1
	115945979380049, -- WALL_bastion_l2
	120631056978513, -- WALL_bastion_l3
	82163741101312, -- WALL_bastion_l4
	88344129020611, -- WALL_bastion_l5
})

function WallAssets.modelName(tier: number): string
	return string.format("WALL_bastion_l%d", tier)
end

-- Liga 1..5 -> tier 1..5 (clamped em [1, MAX_TIER]).
function WallAssets.tierForLeague(league: number?): number
	if type(league) ~= "number" or league ~= league then
		return 1
	end
	return math.clamp(math.floor(league), 1, WallAssets.MAX_TIER)
end

return table.freeze(WallAssets)

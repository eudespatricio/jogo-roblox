--!strict
-- Cenario de fundo (vale continuo alem da muralha), Forge3D rota mesh (concept SD1.5 -> TripoSR)
-- publicado via Open Cloud. Fonte: art/forge/lote_backdrop.yaml. Puramente visual: nao toca
-- simVersion/schema/content. Asset 0 = nao publicado (Backdrop ignora a entrada).

local BackdropAssets = {}

export type Asset = { key: string, assetId: number, textureId: number }
export type Placement = { key: string, x: number, z: number, height: number, yawJitter: number }
export type RoadWaypoint = { x: number, z: number }

BackdropAssets.FOLDER = "MuralhaAssets"
BackdropAssets.PREFIX = "BACKDROP_"

-- Chao continuo do vale (topo do Baseplate, relativo a origin.Y).
BackdropAssets.SHORE_Y = -0.20
-- Camera da arena (relativa a origin); as malhas giram a frente (+Z) para ela.
BackdropAssets.CAMERA_OFFSET = table.freeze({ x = 48, y = 34, z = 52 })

-- Caminho compartilhado da Estrada da Cidadela (Backdrop + AmbientLife).
BackdropAssets.ROAD_WAYPOINTS = table.freeze({
	table.freeze({ x = -27, z = 0 }),
	table.freeze({ x = -46, z = -6 }),
	table.freeze({ x = -70, z = -22 }),
	table.freeze({ x = -96, z = -38 }),
	table.freeze({ x = -118, z = -54 }),
} :: { RoadWaypoint })

BackdropAssets.ASSETS = table.freeze({
	table.freeze({ key = "castle01", assetId = 106693105904074, textureId = 111593348314769 }),
	table.freeze({ key = "house01", assetId = 116579470879926, textureId = 70964650673901 }),
	table.freeze({ key = "house02", assetId = 121109739722294, textureId = 82299972598403 }),
	table.freeze({ key = "tower01", assetId = 82625222995163, textureId = 75828725228493 }),
	table.freeze({ key = "windmill01", assetId = 113466205934167, textureId = 128918177128589 }),
	table.freeze({ key = "keep01", assetId = 0, textureId = 0 }),
	table.freeze({ key = "tree01", assetId = 79361534255880, textureId = 96125919678314 }),
} :: { Asset })

-- 41 entradas em 3 setores: colina da Cidadela/vila (-X), crista norte/direita (-Z) e borda
-- sul/esquerda (+Z). Validado contra cameras (42,38,44) FOV38 e (38,28,40) FOV40: zero oclusao.
BackdropAssets.LAYOUT = table.freeze({
	-- Colina da Cidadela & vila atras da muralha (x in [-56, -210], z in [-155, +55])
	table.freeze({ key = "castle01", x = -148, z = -74, height = 30, yawJitter = 0 }),
	table.freeze({ key = "windmill01", x = -104, z = 10, height = 22, yawJitter = 18 }),
	table.freeze({ key = "tower01", x = -72, z = -54, height = 17, yawJitter = -12 }),
	table.freeze({ key = "tower01", x = -96, z = -70, height = 18, yawJitter = 15 }),
	table.freeze({ key = "tower01", x = -122, z = -40, height = 16, yawJitter = -20 }),
	table.freeze({ key = "house01", x = -58, z = -36, height = 9, yawJitter = -15 }),
	table.freeze({ key = "house01", x = -88, z = -84, height = 9, yawJitter = 24 }),
	table.freeze({ key = "house01", x = -98, z = -14, height = 9, yawJitter = -8 }),
	table.freeze({ key = "house01", x = -70, z = 8, height = 8, yawJitter = 16 }),
	table.freeze({ key = "house02", x = -82, z = -72, height = 9, yawJitter = 10 }),
	table.freeze({ key = "house02", x = -58, z = 6, height = 8, yawJitter = -22 }),
	table.freeze({ key = "house02", x = -116, z = 18, height = 9, yawJitter = 12 }),
	table.freeze({ key = "tree01", x = -60, z = -26, height = 12, yawJitter = 20 }),
	table.freeze({ key = "tree01", x = -62, z = -70, height = 11, yawJitter = 85 }),
	table.freeze({ key = "tree01", x = -84, z = -48, height = 11, yawJitter = 150 }),
	table.freeze({ key = "tree01", x = -104, z = -60, height = 12, yawJitter = 210 }),
	table.freeze({ key = "tree01", x = -124, z = -102, height = 14, yawJitter = 40 }),
	table.freeze({ key = "tree01", x = -144, z = -112, height = 15, yawJitter = 115 }),
	table.freeze({ key = "tree01", x = -172, z = -74, height = 16, yawJitter = 260 }),
	table.freeze({ key = "tree01", x = -166, z = -24, height = 14, yawJitter = 310 }),
	table.freeze({ key = "tree01", x = -138, z = 28, height = 13, yawJitter = 190 }),
	table.freeze({ key = "tree01", x = -88, z = 38, height = 12, yawJitter = 70 }),

	-- Crista arborizada norte/direita (x in [-48, +52], z in [-38, -145])
	table.freeze({ key = "tower01", x = -18, z = -62, height = 17, yawJitter = 14 }),
	table.freeze({ key = "house02", x = -34, z = -68, height = 9, yawJitter = -18 }),
	table.freeze({ key = "tree01", x = -44, z = -48, height = 12, yawJitter = 35 }),
	table.freeze({ key = "tree01", x = -28, z = -44, height = 11, yawJitter = 125 }),
	table.freeze({ key = "tree01", x = -8, z = -46, height = 12, yawJitter = 215 }),
	table.freeze({ key = "tree01", x = 12, z = -48, height = 11, yawJitter = 300 }),
	table.freeze({ key = "tree01", x = 28, z = -46, height = 12, yawJitter = 55 }),
	table.freeze({ key = "tree01", x = -40, z = -88, height = 13, yawJitter = 170 }),
	table.freeze({ key = "tree01", x = -12, z = -82, height = 14, yawJitter = 245 }),
	table.freeze({ key = "tree01", x = 8, z = -76, height = 13, yawJitter = 95 }),
	table.freeze({ key = "tree01", x = 26, z = -78, height = 12, yawJitter = 10 }),
	table.freeze({ key = "tree01", x = 44, z = -70, height = 13, yawJitter = 140 }),
	table.freeze({ key = "tree01", x = -24, z = -114, height = 15, yawJitter = 280 }),
	table.freeze({ key = "tree01", x = 6, z = -112, height = 14, yawJitter = 65 }),

	-- Borda sul/esquerda do vale (x in [-90, +24], z in [+38, +78])
	table.freeze({ key = "tree01", x = -78, z = 52, height = 12, yawJitter = 45 }),
	table.freeze({ key = "tree01", x = -56, z = 48, height = 11, yawJitter = 135 }),
	table.freeze({ key = "tree01", x = -34, z = 54, height = 12, yawJitter = 225 }),
	table.freeze({ key = "tree01", x = -12, z = 48, height = 11, yawJitter = 315 }),
	table.freeze({ key = "tree01", x = 10, z = 44, height = 11, yawJitter = 80 }),
} :: { Placement })

function BackdropAssets.modelName(key: string): string
	return BackdropAssets.PREFIX .. key
end

function BackdropAssets.assetId(key: string): number
	for _, asset in ipairs(BackdropAssets.ASSETS) do
		if asset.key == key then
			return asset.assetId
		end
	end
	return 0
end

function BackdropAssets.textureId(key: string): number
	for _, asset in ipairs(BackdropAssets.ASSETS) do
		if asset.key == key then
			return asset.textureId
		end
	end
	return 0
end

function BackdropAssets.anyPublished(): boolean
	for _, asset in ipairs(BackdropAssets.ASSETS) do
		if asset.assetId > 0 then
			return true
		end
	end
	return false
end

return table.freeze(BackdropAssets)

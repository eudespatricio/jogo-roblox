--!strict
-- Superficies PBR (SurfaceAppearance) dos modelos "Hero" (Forge3D 0.9 / roblox-aa-80).
-- Puramente visual: nao toca simVersion/schema/content. Enquanto colorMap == 0 (nada publicado
-- via Open Cloud) o fallback e a textura de paleta (MeshPart.TextureID): zero regressao.
-- CLI-compativel: nenhum servico Roblox e tocado em tempo de require.

export type Surface = {
	colorMap: number,
	normalMap: number,
	metalnessMap: number,
	roughnessMap: number,
}

local PbrAssets = {}

-- Atlas mestre 2048x2048 compartilhado (preenchido apos o publish dos mapas PBR).
PbrAssets.MASTER_ATLAS = table.freeze({
	colorMap = 0,
	normalMap = 0,
	metalnessMap = 0,
	roughnessMap = 0,
})

local function emptySurface(): Surface
	return { colorMap = 0, normalMap = 0, metalnessMap = 0, roughnessMap = 0 }
end

-- Chave = nome do modelo em ReplicatedStorage.MuralhaAssets.
PbrAssets.HERO_SURFACES = {
	WALL_bastion_l1 = emptySurface(),
	WALL_bastion_l2 = emptySurface(),
	WALL_bastion_l3 = emptySurface(),
	WALL_bastion_l4 = emptySurface(),
	WALL_bastion_l5 = emptySurface(),
	BOSS_iron_ram_colossus = emptySurface(),
	BOSS_slag_juggernaut = emptySurface(),
	BOSS_rime_matriarch = emptySurface(),
	BOSS_powder_baron = emptySurface(),
	BOSS_rift_titan = emptySurface(),
	BOSS_iron_ram_colossus_torso = emptySurface(),
	BOSS_slag_juggernaut_torso = emptySurface(),
	BOSS_rime_matriarch_torso = emptySurface(),
	BOSS_powder_baron_torso = emptySurface(),
	BOSS_rift_titan_torso = emptySurface(),
	PROP_rift_portal = emptySurface(),
	PORTAL_act1 = emptySurface(),
	PORTAL_act2 = emptySurface(),
	PORTAL_act3 = emptySurface(),
	PORTAL_act4 = emptySurface(),
	PORTAL_act5 = emptySurface(),
	PROP_bastion_warden = emptySurface(),
	BACKDROP_castle01 = emptySurface(),
	BACKDROP_keep01 = emptySurface(),
} :: { [string]: Surface }

local function contentId(id: number): string
	if id > 0 then
		return "rbxassetid://" .. tostring(id)
	end
	return ""
end

-- Superficie publicada do modelo (colorMap > 0); senao o atlas mestre (Two-Tier: modelos
-- Tier-A instanciados) quando publicado; senao nil.
function PbrAssets.surfaceFor(modelName: string): Surface?
	local surface = PbrAssets.HERO_SURFACES[modelName]
	if surface ~= nil and surface.colorMap > 0 then
		return surface
	end
	if PbrAssets.MASTER_ATLAS.colorMap > 0 then
		return PbrAssets.MASTER_ATLAS
	end
	return nil
end

function PbrAssets.anyPublished(): boolean
	if PbrAssets.MASTER_ATLAS.colorMap > 0 then
		return true
	end
	for _, surface in pairs(PbrAssets.HERO_SURFACES) do
		if surface.colorMap > 0 then
			return true
		end
	end
	return false
end

local function removeSurfaceAppearances(meshPart: MeshPart): ()
	for _, child in ipairs(meshPart:GetChildren()) do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
end

-- Aplica PBR (se publicado) ou o fallback de paleta. Retorna true quando PBR foi aplicado.
function PbrAssets.applyToMeshPart(
	meshPart: MeshPart,
	modelName: string,
	fallbackTexId: string?
): boolean
	local surface = PbrAssets.surfaceFor(modelName)
	if surface == nil then
		removeSurfaceAppearances(meshPart)
		if fallbackTexId ~= nil and fallbackTexId ~= "" then
			meshPart.TextureID = fallbackTexId
		end
		return false
	end
	meshPart.TextureID = ""
	local existing = meshPart:FindFirstChildOfClass("SurfaceAppearance")
	local appearance: SurfaceAppearance
	if existing ~= nil then
		appearance = existing :: SurfaceAppearance
	else
		appearance = Instance.new("SurfaceAppearance") :: SurfaceAppearance
		appearance.Parent = meshPart
	end
	appearance.AlphaMode = Enum.AlphaMode.Opaque
	appearance.ColorMap = contentId(surface.colorMap)
	appearance.NormalMap = contentId(surface.normalMap)
	appearance.MetalnessMap = contentId(surface.metalnessMap)
	appearance.RoughnessMap = contentId(surface.roughnessMap)
	meshPart.Material = Enum.Material.SmoothPlastic
	return true
end

function PbrAssets.applyToModel(model: Model, modelName: string, fallbackTexId: string?): ()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("MeshPart") then
			PbrAssets.applyToMeshPart(descendant :: MeshPart, modelName, fallbackTexId)
		end
	end
end

-- Reaplica PBR publicado em um clone (Model ou MeshPart) montado pelos kits. Sem PBR publicado
-- para o modelo, nao mexe em nada (o clone ja carrega TextureID/SurfaceAppearance do template).
function PbrAssets.reapply(instance: Instance, modelName: string): ()
	if PbrAssets.surfaceFor(modelName) == nil then
		return
	end
	if instance:IsA("MeshPart") then
		PbrAssets.applyToMeshPart(instance :: MeshPart, modelName, nil)
	elseif instance:IsA("Model") then
		PbrAssets.applyToModel(instance :: Model, modelName, nil)
	end
end

return PbrAssets

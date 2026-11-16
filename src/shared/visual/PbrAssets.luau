--!strict
-- Superficies PBR (SurfaceAppearance) dos modelos "Hero" (Forge3D 0.9 / roblox-aa-80).
-- Puramente visual: nao toca simVersion/schema/content. Enquanto colorMap == 0 (nada publicado
-- via Open Cloud) o fallback e a textura de paleta (MeshPart.TextureID): zero regressao.
-- CLI-compativel: nenhum servico Roblox e tocado em tempo de require.

local IS_ROBLOX = type(game) == "userdata"
local cliRequire: any = require
local Mock: any = if IS_ROBLOX then nil else cliRequire("./HeadlessRobloxMock")
local Instance = if IS_ROBLOX then Instance else Mock.Instance :: typeof(Instance)
local Enum = if IS_ROBLOX then Enum else Mock.Enum :: typeof(Enum)

export type Surface = {
	colorMap: number,
	normalMap: number,
	metalnessMap: number,
	roughnessMap: number,
}

local PbrAssets = {}

-- Atlas mestre 2048x2048 compartilhado (preenchido apos o publish dos mapas PBR).
PbrAssets.MASTER_ATLAS = table.freeze({
	colorMap = 87757376846021,
	normalMap = 97292854793419,
	metalnessMap = 95192389541466,
	roughnessMap = 74673920637656,
})

-- Chave = nome do modelo em ReplicatedStorage.MuralhaAssets.
PbrAssets.HERO_SURFACES = {
	WALL_bastion_l1 = table.freeze({
		colorMap = 73523802640078,
		normalMap = 121915960539756,
		metalnessMap = 106661126692585,
		roughnessMap = 113465924180122,
	}),
	WALL_bastion_l2 = table.freeze({
		colorMap = 115593206497976,
		normalMap = 111207544975277,
		metalnessMap = 83132585176871,
		roughnessMap = 76520771194211,
	}),
	WALL_bastion_l3 = table.freeze({
		colorMap = 118461409784762,
		normalMap = 75318563037217,
		metalnessMap = 99305981280481,
		roughnessMap = 110174537869860,
	}),
	WALL_bastion_l4 = table.freeze({
		colorMap = 122980884811435,
		normalMap = 82729927199811,
		metalnessMap = 114640852925824,
		roughnessMap = 84184357832929,
	}),
	WALL_bastion_l5 = table.freeze({
		colorMap = 139787969776338,
		normalMap = 98282112367178,
		metalnessMap = 115912781724514,
		roughnessMap = 122534448435763,
	}),
	BOSS_iron_ram_colossus = table.freeze({
		colorMap = 109363516395989,
		normalMap = 71939514614107,
		metalnessMap = 106017181985078,
		roughnessMap = 100856311038290,
	}),
	BOSS_slag_juggernaut = table.freeze({
		colorMap = 113470447251142,
		normalMap = 123353924040280,
		metalnessMap = 108441377873707,
		roughnessMap = 104616219277491,
	}),
	BOSS_rime_matriarch = table.freeze({
		colorMap = 128287393454264,
		normalMap = 88947690954236,
		metalnessMap = 108212943808030,
		roughnessMap = 113233501035139,
	}),
	BOSS_powder_baron = table.freeze({
		colorMap = 134230663497008,
		normalMap = 101733349958330,
		metalnessMap = 109607382246298,
		roughnessMap = 115038312707286,
	}),
	BOSS_rift_titan = table.freeze({
		colorMap = 71789314491676,
		normalMap = 124065324614248,
		metalnessMap = 133208963649497,
		roughnessMap = 112420045686090,
	}),
	BOSS_iron_ram_colossus_torso = table.freeze({
		colorMap = 110039913552170,
		normalMap = 108588711498539,
		metalnessMap = 87397195179011,
		roughnessMap = 136197847230792,
	}),
	BOSS_slag_juggernaut_torso = table.freeze({
		colorMap = 80781199360912,
		normalMap = 117611085591973,
		metalnessMap = 115496999712212,
		roughnessMap = 97736810799501,
	}),
	BOSS_rime_matriarch_torso = table.freeze({
		colorMap = 86199136465606,
		normalMap = 83040655351178,
		metalnessMap = 113795404446447,
		roughnessMap = 89634839467962,
	}),
	BOSS_powder_baron_torso = table.freeze({
		colorMap = 138732063508972,
		normalMap = 138661956614517,
		metalnessMap = 134978363882294,
		roughnessMap = 90822432149391,
	}),
	BOSS_rift_titan_torso = table.freeze({
		colorMap = 91124123224845,
		normalMap = 109424305877343,
		metalnessMap = 81599034820317,
		roughnessMap = 72732260367119,
	}),
	PROP_rift_portal = table.freeze({
		colorMap = 87849938499125,
		normalMap = 137166816650512,
		metalnessMap = 111475818410092,
		roughnessMap = 139158524866250,
	}),
	PORTAL_act1 = table.freeze({
		colorMap = 107304429294853,
		normalMap = 117839711698365,
		metalnessMap = 91332642852473,
		roughnessMap = 125381609736677,
	}),
	PORTAL_act2 = table.freeze({
		colorMap = 108697077126592,
		normalMap = 93280665575194,
		metalnessMap = 106254002086258,
		roughnessMap = 138073333922672,
	}),
	PORTAL_act3 = table.freeze({
		colorMap = 70543845249524,
		normalMap = 88906585210978,
		metalnessMap = 139614673672451,
		roughnessMap = 126180120451515,
	}),
	PORTAL_act4 = table.freeze({
		colorMap = 129115230135658,
		normalMap = 123244011986901,
		metalnessMap = 132080617869161,
		roughnessMap = 83437127991360,
	}),
	PORTAL_act5 = table.freeze({
		colorMap = 121758810264190,
		normalMap = 76902573747356,
		metalnessMap = 87691262546967,
		roughnessMap = 107844732631679,
	}),
	PROP_bastion_warden = table.freeze({
		colorMap = 97629366463002,
		normalMap = 98025921333914,
		metalnessMap = 110257317699793,
		roughnessMap = 134190092474002,
	}),
	BACKDROP_castle01 = table.freeze({
		colorMap = 106700660155361,
		normalMap = 119221006389093,
		metalnessMap = 131228970041655,
		roughnessMap = 112547036898200,
	}),
	BACKDROP_keep01 = table.freeze({
		colorMap = 71642065033024,
		normalMap = 137461042452506,
		metalnessMap = 98771687365073,
		roughnessMap = 88854107555834,
	}),
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

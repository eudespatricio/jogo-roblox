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
local scriptRef: any = if IS_ROBLOX then script else nil
local ContentRef: any = if IS_ROBLOX then Content else nil

export type Surface = {
	colorMap: number,
	normalMap: number,
	metalnessMap: number,
	roughnessMap: number,
}

local PbrAssets = {}

local testPresetFolder: any = nil
local runtimeSaCache: { [string]: any } = {}

function PbrAssets._setPresetFolderForTest(folder: any): ()
	testPresetFolder = folder
end

-- Atlas mestre 2048x2048 compartilhado (preenchido apos o publish dos mapas PBR).
PbrAssets.MASTER_ATLAS = table.freeze({
	colorMap = 123373171413605,
	normalMap = 79107339864857,
	metalnessMap = 77910591061847,
	roughnessMap = 132353842584939,
})

-- Chave = nome do modelo em ReplicatedStorage.MuralhaAssets.
PbrAssets.HERO_SURFACES = {
	BOSS_iron_ram_colossus = table.freeze({
		colorMap = 89457576442638,
		normalMap = 131074852904860,
		metalnessMap = 107324117805454,
		roughnessMap = 113032191368124,
	}),
	BOSS_slag_juggernaut = table.freeze({
		colorMap = 100714179334639,
		normalMap = 98798626604355,
		metalnessMap = 135543956358342,
		roughnessMap = 104963270356366,
	}),
	BOSS_rime_matriarch = table.freeze({
		colorMap = 107579908289110,
		normalMap = 90614070604836,
		metalnessMap = 82672878359460,
		roughnessMap = 83995055565884,
	}),
	BOSS_powder_baron = table.freeze({
		colorMap = 131045577353717,
		normalMap = 97114990424896,
		metalnessMap = 130456312960770,
		roughnessMap = 74915911598828,
	}),
	BOSS_rift_titan = table.freeze({
		colorMap = 123156612628598,
		normalMap = 99210088667636,
		metalnessMap = 94160315831208,
		roughnessMap = 134886382056006,
	}),
	BOSS_iron_ram_colossus_torso = table.freeze({
		colorMap = 96681994999029,
		normalMap = 131140009469222,
		metalnessMap = 93881533016301,
		roughnessMap = 132897548839459,
	}),
	BOSS_slag_juggernaut_torso = table.freeze({
		colorMap = 117049366326752,
		normalMap = 99688642206718,
		metalnessMap = 96342132451788,
		roughnessMap = 131007343589462,
	}),
	BOSS_rime_matriarch_torso = table.freeze({
		colorMap = 72585823675403,
		normalMap = 91901592468273,
		metalnessMap = 87832398038814,
		roughnessMap = 118590439138886,
	}),
	BOSS_powder_baron_torso = table.freeze({
		colorMap = 80263128797143,
		normalMap = 79960711408824,
		metalnessMap = 78388024570641,
		roughnessMap = 95890831957010,
	}),
	BOSS_rift_titan_torso = table.freeze({
		colorMap = 114513878857300,
		normalMap = 93039401708965,
		metalnessMap = 86221231309456,
		roughnessMap = 77628139829517,
	}),
	PROP_rift_portal = table.freeze({
		colorMap = 128058754775979,
		normalMap = 126403147793719,
		metalnessMap = 127701370692048,
		roughnessMap = 77569146089134,
	}),
	PORTAL_act1 = table.freeze({
		colorMap = 119965740838462,
		normalMap = 92912856747678,
		metalnessMap = 114725987064454,
		roughnessMap = 77740227428518,
	}),
	PORTAL_act2 = table.freeze({
		colorMap = 98921022494859,
		normalMap = 137247584363698,
		metalnessMap = 101427162995422,
		roughnessMap = 108728022547854,
	}),
	PORTAL_act3 = table.freeze({
		colorMap = 116808635099165,
		normalMap = 129506508106703,
		metalnessMap = 84260542733491,
		roughnessMap = 121668968209432,
	}),
	PORTAL_act4 = table.freeze({
		colorMap = 86285586371008,
		normalMap = 71362950427960,
		metalnessMap = 91438640485864,
		roughnessMap = 125640655543588,
	}),
	PORTAL_act5 = table.freeze({
		colorMap = 132721294617339,
		normalMap = 130147466539670,
		metalnessMap = 103097485368777,
		roughnessMap = 124598509837327,
	}),
	PROP_bastion_warden = table.freeze({
		colorMap = 139818374994313,
		normalMap = 76812660433528,
		metalnessMap = 104156632482057,
		roughnessMap = 77892457343565,
	}),
	BACKDROP_castle01 = table.freeze({
		colorMap = 92609000858731,
		normalMap = 103290401452603,
		metalnessMap = 84950921106825,
		roughnessMap = 128375462762002,
	}),
	BACKDROP_keep01 = table.freeze({
		colorMap = 127591110922747,
		normalMap = 110409442020474,
		metalnessMap = 79868732991209,
		roughnessMap = 75732736423659,
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

function PbrAssets.presetKeyFor(modelName: string): string?
	local surface = PbrAssets.HERO_SURFACES[modelName]
	if surface ~= nil and surface.colorMap > 0 then
		return modelName
	end
	if PbrAssets.MASTER_ATLAS.colorMap > 0 then
		return "MASTER_ATLAS"
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

local function resolvePresetFolder(): any
	if testPresetFolder ~= nil then
		return testPresetFolder
	end
	if IS_ROBLOX and scriptRef ~= nil and scriptRef.Parent ~= nil then
		return scriptRef.Parent:FindFirstChild("SurfaceAppearances")
	end
	return nil
end

local function removeSurfaceAppearances(meshPart: any): ()
	for _, child in ipairs(meshPart:GetChildren()) do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
end

-- Aplica PBR (se publicado) ou o fallback de paleta. Retorna true quando PBR foi aplicado.
function PbrAssets.applyToMeshPart(
	meshPart: any,
	modelName: string,
	fallbackTexId: string?
): boolean
	local surface = PbrAssets.surfaceFor(modelName)
	local presetKey = PbrAssets.presetKeyFor(modelName)
	if surface == nil or presetKey == nil then
		removeSurfaceAppearances(meshPart)
		if fallbackTexId ~= nil and fallbackTexId ~= "" then
			meshPart.TextureID = fallbackTexId
		end
		return false
	end

	local saClone: any = nil
	local folder = resolvePresetFolder()
	if folder ~= nil then
		local preset = folder:FindFirstChild(presetKey)
		if preset ~= nil then
			saClone = preset:Clone()
		end
	end

	if saClone == nil then
		if IS_ROBLOX then
			local cached = runtimeSaCache[presetKey]
			if cached ~= nil then
				saClone = cached:Clone()
			else
				local ok, created = pcall(function()
					local assetService: any = game:GetService("AssetService")
					local fromUri = ContentRef.fromUri
					return assetService:CreateSurfaceAppearanceAsync({
						ColorMap = fromUri(contentId(surface.colorMap)),
						NormalMap = fromUri(contentId(surface.normalMap)),
						MetalnessMap = fromUri(contentId(surface.metalnessMap)),
						RoughnessMap = fromUri(contentId(surface.roughnessMap)),
					})
				end)
				if ok and created ~= nil then
					runtimeSaCache[presetKey] = created
					saClone = created:Clone()
				else
					if fallbackTexId ~= nil and fallbackTexId ~= "" then
						meshPart.TextureID = fallbackTexId
					end
					return false
				end
			end
		else
			local mockSa: any = Instance.new("SurfaceAppearance")
			mockSa.AlphaMode = Enum.AlphaMode.Overlay
			mockSa.ColorMap = contentId(surface.colorMap)
			mockSa.NormalMap = contentId(surface.normalMap)
			mockSa.MetalnessMap = contentId(surface.metalnessMap)
			mockSa.RoughnessMap = contentId(surface.roughnessMap)
			saClone = mockSa
		end
	end

	removeSurfaceAppearances(meshPart)
	meshPart.TextureID = ""
	meshPart.Material = Enum.Material.SmoothPlastic
	saClone.Parent = meshPart
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

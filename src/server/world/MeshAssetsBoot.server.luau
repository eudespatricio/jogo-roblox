--!strict
-- Carrega assincronamente as malhas 3D de armadilhas, horda e portal (Open Cloud) em
-- ReplicatedStorage.MuralhaAssets. Falha (lugar nao publicado, moderacao pendente,
-- dono diferente) apenas emite warn: os kits visuais seguem com o fallback em blocos.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshAssets = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("MeshAssets")
)

local folder = ReplicatedStorage:FindFirstChild(MeshAssets.FOLDER)
if folder == nil then
	folder = Instance.new("Folder")
	folder.Name = MeshAssets.FOLDER
	folder.Parent = ReplicatedStorage
end
assert(folder ~= nil)

local warnedUnpublishedPlace = false

local function needsPaletteTexture(textureId: string): boolean
	return textureId == "" or string.sub(textureId, 1, 15) == "rbxassethash://"
end

local function prepare(model: Model): ()
	local paletteTexture = if MeshAssets.LOWPOLY_PALETTE_TEXTURE_ID > 0
		then "rbxassetid://" .. tostring(MeshAssets.LOWPOLY_PALETTE_TEXTURE_ID)
		else ""
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("SurfaceAppearance") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = true
			if
				descendant:IsA("MeshPart")
				and paletteTexture ~= ""
				and needsPaletteTexture(descendant.TextureID)
			then
				descendant.TextureID = paletteTexture
			end
		end
	end
end

local function loadMesh(modelName: string, assetId: number): ()
	if assetId <= 0 then
		return
	end
	task.spawn(function()
		local ok, result = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if not ok or result == nil then
			if game.PlaceId == 0 then
				if not warnedUnpublishedPlace then
					warnedUnpublishedPlace = true
					warn(
						"[Muralha/Meshes] Place local sem PlaceId (PlaceId=0): publique no Studio sob userId 11966727684 para carregar malhas 3D Open Cloud."
					)
				end
			else
				warn(
					string.format(
						"[meshes] malha %s (%d) indisponivel: %s",
						modelName,
						assetId,
						tostring(result)
					)
				)
			end
			return
		end
		local container = result :: Model
		local model = Instance.new("Model")
		model.Name = modelName
		for _, child in ipairs(container:GetChildren()) do
			child.Parent = model
		end
		container:Destroy()
		prepare(model)
		model.Parent = folder
		print(string.format("[meshes] malha %s carregada (%d)", modelName, assetId))
	end)
end

for trapId, levels in pairs(MeshAssets.TRAPS) do
	for lvl, assetId in ipairs(levels) do
		loadMesh(MeshAssets.trapModelName(trapId, lvl), assetId)
	end
end

for kind, assetId in pairs(MeshAssets.HORDE) do
	loadMesh(MeshAssets.hordeModelName(kind), assetId)
end

for bossId, assetId in pairs(MeshAssets.BOSSES) do
	loadMesh(MeshAssets.bossModelName(bossId), assetId)
end

for bossId, parts in pairs(MeshAssets.BOSS_PARTS) do
	loadMesh(MeshAssets.bossPartModelName(bossId, "torso"), parts.torso)
	loadMesh(MeshAssets.bossPartModelName(bossId, "arm_r"), parts.arm_r)
	loadMesh(MeshAssets.bossPartModelName(bossId, "arm_l"), parts.arm_l)
	loadMesh(MeshAssets.bossPartModelName(bossId, "leg_l"), parts.leg_l)
	loadMesh(MeshAssets.bossPartModelName(bossId, "leg_r"), parts.leg_r)
end

for key, assetId in pairs(MeshAssets.PROPS) do
	loadMesh(MeshAssets.propModelName(key), assetId)
end

for key, assetId in pairs(MeshAssets.FAUNA) do
	loadMesh(MeshAssets.faunaModelName(key), assetId)
end

for themeKey, assetId in pairs(MeshAssets.PORTALS) do
	loadMesh(MeshAssets.portalModelName(themeKey), assetId)
end

--!strict
-- Carrega as malhas da muralha (Open Cloud) em ReplicatedStorage.MuralhaAssets para o cliente
-- clonar. Falha (lugar nao publicado, moderacao pendente, dono diferente) so registra aviso:
-- o ArenaVisual segue com a muralha de blocos.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WallAssets = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("WallAssets")
)
local MeshAssets = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("MeshAssets")
)

local folder = ReplicatedStorage:FindFirstChild(WallAssets.FOLDER)
if folder == nil then
	folder = Instance.new("Folder")
	folder.Name = WallAssets.FOLDER
	folder.Parent = ReplicatedStorage
end
assert(folder ~= nil)

local warnedUnpublishedPlace = false

local function upgradeMeshPrecision(meshPart: MeshPart, texId: string): ()
	local origSize = meshPart.Size
	local origCF = meshPart.CFrame
	if meshPart.MeshId ~= "" and meshPart.RenderFidelity ~= Enum.RenderFidelity.Precise then
		local ok, precise = pcall(function()
			return InsertService:CreateMeshPartAsync(
				meshPart.MeshId,
				Enum.CollisionFidelity.Box,
				Enum.RenderFidelity.Precise
			)
		end)
		if ok and precise ~= nil then
			meshPart:ApplyMesh(precise)
			precise:Destroy()
			meshPart.Size = origSize
			meshPart.CFrame = origCF
		end
	end
	if texId ~= "" then
		meshPart.TextureID = texId
	end
	meshPart.Material = Enum.Material.SmoothPlastic
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
			if descendant:IsA("MeshPart") then
				upgradeMeshPrecision(descendant, paletteTexture)
			end
		end
	end
end

for tier, assetId in ipairs(WallAssets.ASSET_IDS) do
	task.spawn(function()
		local ok, result = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if not ok or result == nil then
			if game.PlaceId == 0 then
				if not warnedUnpublishedPlace then
					warnedUnpublishedPlace = true
					warn(
						"[Muralha/Walls] Place local sem PlaceId (PlaceId=0): publique no Studio sob userId 11966727684 para carregar malhas 3D Open Cloud."
					)
				end
			else
				warn(
					string.format(
						"[walls] malha L%d (%d) indisponivel: %s",
						tier,
						assetId,
						tostring(result)
					)
				)
			end
			return
		end
		local container = result :: Model
		local model = Instance.new("Model")
		model.Name = WallAssets.modelName(tier)
		for _, child in ipairs(container:GetChildren()) do
			child.Parent = model
		end
		container:Destroy()
		prepare(model)
		model.Parent = folder
		print(string.format("[walls] malha L%d carregada (%d)", tier, assetId))
	end)
end

--!strict
-- Carrega as malhas do cenario de fundo (Open Cloud) em ReplicatedStorage.MuralhaAssets/BACKDROP_*
-- para o cliente clonar. Falha so registra aviso: o Backdrop simplesmente nao aparece.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BackdropAssets = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("BackdropAssets")
)
local MeshAssets = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("MeshAssets")
)

if not BackdropAssets.anyPublished() then
	return
end

local folder = ReplicatedStorage:FindFirstChild(BackdropAssets.FOLDER)
if folder == nil then
	folder = Instance.new("Folder")
	folder.Name = BackdropAssets.FOLDER
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

local function prepare(model: Model, textureId: number): ()
	local texContentId = if textureId > 0 then "rbxassetid://" .. tostring(textureId) else ""
	local paletteTexture = if MeshAssets.LOWPOLY_PALETTE_TEXTURE_ID > 0
		then "rbxassetid://" .. tostring(MeshAssets.LOWPOLY_PALETTE_TEXTURE_ID)
		else ""
	local resolvedTex = if texContentId ~= "" then texContentId else paletteTexture
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("SurfaceAppearance") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
			if descendant:IsA("MeshPart") then
				upgradeMeshPrecision(descendant, resolvedTex)
			end
		end
	end
end

for _, asset in ipairs(BackdropAssets.ASSETS) do
	if asset.assetId <= 0 then
		continue
	end
	task.spawn(function()
		local ok, result = pcall(function()
			return InsertService:LoadAsset(asset.assetId)
		end)
		if not ok or result == nil then
			if game.PlaceId == 0 then
				if not warnedUnpublishedPlace then
					warnedUnpublishedPlace = true
					warn(
						"[Muralha/Backdrop] Place local sem PlaceId (PlaceId=0): publique no Studio sob userId 11966727684 para carregar malhas 3D Open Cloud."
					)
				end
			else
				warn(
					string.format(
						"[backdrop] malha %s (%d) indisponivel: %s",
						asset.key,
						asset.assetId,
						tostring(result)
					)
				)
			end
			return
		end
		local container = result :: Model
		local model = Instance.new("Model")
		model.Name = BackdropAssets.modelName(asset.key)
		for _, child in ipairs(container:GetChildren()) do
			child.Parent = model
		end
		container:Destroy()
		prepare(model, asset.textureId)
		model.Parent = folder
		print(string.format("[backdrop] malha %s carregada (%d)", asset.key, asset.assetId))
	end)
end

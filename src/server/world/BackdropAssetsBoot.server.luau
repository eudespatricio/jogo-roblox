--!strict
-- Carrega as malhas do cenario de fundo (Open Cloud) em ReplicatedStorage.MuralhaAssets/BACKDROP_*
-- para o cliente clonar. Falha so registra aviso: o Backdrop simplesmente nao aparece.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BackdropAssets = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("BackdropAssets")
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

local function prepare(model: Model): ()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
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
			warn(
				string.format(
					"[backdrop] malha %s (%d) indisponivel: %s",
					asset.key,
					asset.assetId,
					tostring(result)
				)
			)
			return
		end
		local container = result :: Model
		local model = Instance.new("Model")
		model.Name = BackdropAssets.modelName(asset.key)
		for _, child in ipairs(container:GetChildren()) do
			child.Parent = model
		end
		container:Destroy()
		prepare(model)
		model.Parent = folder
		print(string.format("[backdrop] malha %s carregada (%d)", asset.key, asset.assetId))
	end)
end

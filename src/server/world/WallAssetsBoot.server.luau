--!strict
-- Carrega as malhas da muralha (Open Cloud) em ReplicatedStorage.MuralhaAssets para o cliente
-- clonar. Falha (lugar nao publicado, moderacao pendente, dono diferente) so registra aviso:
-- o ArenaVisual segue com a muralha de blocos.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WallAssets = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("WallAssets")
)

local folder = ReplicatedStorage:FindFirstChild(WallAssets.FOLDER)
if folder == nil then
	folder = Instance.new("Folder")
	folder.Name = WallAssets.FOLDER
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
			descendant.CastShadow = true
		end
	end
end

for tier, assetId in ipairs(WallAssets.ASSET_IDS) do
	task.spawn(function()
		local ok, result = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if not ok or result == nil then
			warn(
				string.format(
					"[walls] malha L%d (%d) indisponivel: %s",
					tier,
					assetId,
					tostring(result)
				)
			)
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

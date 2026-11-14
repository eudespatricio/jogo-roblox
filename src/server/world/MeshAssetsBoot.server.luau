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

local function loadMesh(modelName: string, assetId: number): ()
	if assetId <= 0 then
		return
	end
	task.spawn(function()
		local ok, result = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if not ok or result == nil then
			warn(
				string.format(
					"[meshes] malha %s (%d) indisponivel: %s",
					modelName,
					assetId,
					tostring(result)
				)
			)
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

for key, assetId in pairs(MeshAssets.PROPS) do
	loadMesh(MeshAssets.propModelName(key), assetId)
end

for key, assetId in pairs(MeshAssets.FAUNA) do
	loadMesh(MeshAssets.faunaModelName(key), assetId)
end

loadMesh(MeshAssets.PORTAL_MODEL, MeshAssets.PORTAL)

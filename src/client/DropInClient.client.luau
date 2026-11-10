--!nonstrict
-- S5: cena de abertura (drop-in) do cliente. Mostra a horda, a muralha e UM botao DEFENDER;
-- aperta -> salva de catapulta/slow motion -> onda limpa -> BuildClient assume. Sem apertar em
-- 10 s, a horda quebra o portao e a tela oferece TENTAR DE NOVO.
-- A cena 3D e local (visual); o estado, o timeout e a batalha real ficam no DropInController.
-- Nao ha texto de tutorial: so o botao, a barra da muralha e o feedback de derrota/vitoria.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("MuralhaRemotes")
local actionRemote = remotes:WaitForChild("DropInAction") :: RemoteFunction
local snapshotRemote = remotes:WaitForChild("DropInSnapshot") :: RemoteFunction

local shared = ReplicatedStorage:WaitForChild("Shared")
local dropinModules = shared:WaitForChild("dropin")
local DropInState = require(dropinModules:WaitForChild("DropInState"))

for _ = 1, 50 do
	if ReplicatedStorage:GetAttribute("DropInEnabled") ~= nil then
		break
	end
	task.wait(0.1)
end
if ReplicatedStorage:GetAttribute("DropInEnabled") ~= true then
	return
end

local ORIGIN = Vector3.new(200, 0, 0)
local camera = Workspace.CurrentCamera
if camera == nil then
	camera = Workspace:WaitForChild("Camera") :: Camera
end
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.lookAt(ORIGIN + Vector3.new(58, 38, 58), ORIGIN + Vector3.new(0, 3, 0))
camera.FieldOfView = 42

-- Esconde o grid de build (fica no origem) enquanto a cena de abertura roda no offset.
local hiddenParts: { [BasePart]: number } = {}
local function hideBuildGrid(): ()
	local grid = Workspace:FindFirstChild("MuralhaGrid")
	if grid == nil then
		return
	end
	for _, descendant in ipairs(grid:GetDescendants()) do
		if descendant:IsA("BasePart") and hiddenParts[descendant] == nil then
			hiddenParts[descendant] = descendant.Transparency
			descendant.Transparency = 1
		end
	end
end
hideBuildGrid()
task.delay(1, hideBuildGrid)

local scene = Instance.new("Folder")
scene.Name = "DropInLocalScene"
scene.Parent = Workspace

local function makePart(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color
	part.Parent = scene
	return part
end

makePart(
	"Campo",
	Vector3.new(84, 1, 52),
	ORIGIN + Vector3.new(0, -0.5, 0),
	Color3.fromRGB(62, 92, 52),
	Enum.Material.Grass
)
makePart(
	"Portao",
	Vector3.new(2, 8, 40),
	ORIGIN + Vector3.new(-24, 4, 0),
	Color3.fromRGB(120, 82, 45),
	Enum.Material.WoodPlanks
)
makePart(
	"MuralhaFundo",
	Vector3.new(3, 10, 44),
	ORIGIN + Vector3.new(-27, 4, 0),
	Color3.fromRGB(90, 60, 34),
	Enum.Material.Wood
)
for lane = 1, 5 do
	local z = (lane - 3) * 8
	makePart(
		"Lane" .. lane,
		Vector3.new(42, 0.2, 4),
		ORIGIN + Vector3.new(-2, 0.15, z),
		Color3.fromRGB(45, 62, 38),
		Enum.Material.Grass
	)
end

makePart(
	"CatapultaBase",
	Vector3.new(5, 2, 5),
	ORIGIN + Vector3.new(-4, 1, 0),
	Color3.fromRGB(95, 65, 35),
	Enum.Material.Wood
)
local catapultArm = makePart(
	"CatapultaBraco",
	Vector3.new(1, 1, 7),
	ORIGIN + Vector3.new(-4, 2.5, 0),
	Color3.fromRGB(140, 95, 45),
	Enum.Material.Wood
)
catapultArm.CFrame = CFrame.new(ORIGIN + Vector3.new(-4, 2.5, 0))
	* CFrame.Angles(0, 0, math.rad(-25))

local horde = {}
for lane = 1, 5 do
	local z = (lane - 3) * 8
	for unit = 1, 2 do
		local part = makePart(
			string.format("Horda_%d_%d", lane, unit),
			Vector3.new(2.4, 2.4, 2.4),
			ORIGIN + Vector3.new(16 + unit * 4, 1.3, z),
			Color3.fromRGB(130, 45, 40)
		)
		horde[#horde + 1] = { part = part, z = z, offset = unit * 4 }
	end
end

-- ---------------------------------------------------------------- UI
local gui = Instance.new("ScreenGui")
gui.Name = "DropInGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 20
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = gui

local function corner(parent: Instance, radius: number): ()
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local bar = Instance.new("Frame")
bar.Name = "WallBar"
bar.Position = UDim2.new(0.1, 0, 0, 16)
bar.Size = UDim2.new(0.8, 0, 0, 24)
bar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
bar.BackgroundTransparency = 0.15
bar.BorderSizePixel = 0
bar.ClipsDescendants = true
bar.Parent = root
corner(bar, 7)

local wallFill = Instance.new("Frame")
wallFill.Name = "Fill"
wallFill.Size = UDim2.fromScale(1, 1)
wallFill.BackgroundColor3 = Color3.fromRGB(70, 150, 90)
wallFill.BorderSizePixel = 0
wallFill.Parent = bar
corner(wallFill, 7)

local button = Instance.new("TextButton")
button.Name = "Defender"
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, -34)
button.Size = UDim2.new(0.64, 0, 0, 76)
button.BackgroundColor3 = Color3.fromRGB(70, 140, 90)
button.BackgroundTransparency = 0.05
button.BorderSizePixel = 0
button.Text = "DEFENDER"
button.TextColor3 = Color3.fromRGB(245, 255, 245)
button.TextScaled = true
button.Font = Enum.Font.GothamBlack
button.AutoButtonColor = true
button.Visible = false
button.Parent = root
corner(button, 12)

local buttonScale = Instance.new("UIScale")
buttonScale.Scale = 1
buttonScale.Parent = button

local clearBanner = Instance.new("TextLabel")
clearBanner.Name = "ClearBanner"
clearBanner.AnchorPoint = Vector2.new(0.5, 0)
clearBanner.Position = UDim2.new(0.5, 0, 0.28, 0)
clearBanner.Size = UDim2.new(0.9, 0, 0, 64)
clearBanner.BackgroundTransparency = 1
clearBanner.Text = "ONDA LIMPA"
clearBanner.TextColor3 = Color3.fromRGB(170, 240, 170)
clearBanner.TextScaled = true
clearBanner.Font = Enum.Font.GothamBlack
clearBanner.Visible = false
clearBanner.Parent = root

local defeatFrame = Instance.new("Frame")
defeatFrame.Name = "Defeat"
defeatFrame.Size = UDim2.fromScale(1, 1)
defeatFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
defeatFrame.BackgroundTransparency = 0.45
defeatFrame.BorderSizePixel = 0
defeatFrame.Visible = false
defeatFrame.Parent = root

local defeatTitle = Instance.new("TextLabel")
defeatTitle.Name = "Title"
defeatTitle.AnchorPoint = Vector2.new(0.5, 0.5)
defeatTitle.Position = UDim2.fromScale(0.5, 0.4)
defeatTitle.Size = UDim2.new(0.9, 0, 0, 84)
defeatTitle.BackgroundTransparency = 1
defeatTitle.Text = "A HORDA PASSOU"
defeatTitle.TextColor3 = Color3.fromRGB(240, 180, 160)
defeatTitle.TextScaled = true
defeatTitle.Font = Enum.Font.GothamBlack
defeatTitle.Parent = defeatFrame

local retryButton = Instance.new("TextButton")
retryButton.Name = "Retry"
retryButton.AnchorPoint = Vector2.new(0.5, 0.5)
retryButton.Position = UDim2.fromScale(0.5, 0.58)
retryButton.Size = UDim2.new(0.55, 0, 0, 64)
retryButton.BackgroundColor3 = Color3.fromRGB(70, 90, 120)
retryButton.BorderSizePixel = 0
retryButton.Text = "TENTAR DE NOVO"
retryButton.TextColor3 = Color3.fromRGB(240, 240, 255)
retryButton.TextScaled = true
retryButton.Font = Enum.Font.GothamBold
retryButton.Parent = defeatFrame
corner(retryButton, 10)

-- ---------------------------------------------------------------- estado local
local phase = "shown"
local serverSnapshot = nil
local scenarioStart = time()
local pressed = false
local pressProgress = 0
local defeated = false
local finished = false

local function setWall(pct: number): ()
	wallFill.Size = UDim2.fromScale(math.clamp(pct, 0, 1), 1)
end

local function setHordeVisible(visible: boolean): ()
	for _, item in ipairs(horde) do
		item.part.Transparency = visible and 0 or 1
	end
end

local function resetHorde(): ()
	setHordeVisible(true)
	scenarioStart = time()
	pressed = false
	pressProgress = 0
end

local function showDefeat(): ()
	if defeated or finished then
		return
	end
	defeated = true
	pressed = true
	phase = "defeated"
	button.Visible = false
	clearBanner.Visible = false
	defeatFrame.Visible = true
	setWall(0)
end

local function cleanup(): ()
	if scene.Parent ~= nil then
		scene:Destroy()
	end
	if gui.Parent ~= nil then
		gui:Destroy()
	end
	for part, transparency in pairs(hiddenParts) do
		if part.Parent ~= nil then
			part.Transparency = transparency
		end
	end
	hiddenParts = {}
end

local function finishClear(): ()
	if finished then
		return
	end
	finished = true
	phase = "cleared"
	button.Visible = false
	defeatFrame.Visible = false
	clearBanner.Visible = true
	setWall(1)
	setHordeVisible(false)
	task.delay(0.9, cleanup)
end

local function applySnapshot(snapshot: any): ()
	if type(snapshot) ~= "table" then
		return
	end
	serverSnapshot = snapshot
	phase = snapshot.phase or phase
	if snapshot.result ~= nil and type(snapshot.result.wallPct) == "number" then
		setWall(snapshot.result.wallPct)
	end
	if snapshot.phase == "defeated" then
		showDefeat()
	elseif snapshot.phase == "cleared" then
		finishClear()
	end
end

local function press(): ()
	if pressed or finished or phase ~= "shown" then
		return
	end
	if serverSnapshot ~= nil and serverSnapshot.canPress ~= true then
		return
	end
	pressed = true
	button.Visible = false
	pressProgress = math.clamp((time() - scenarioStart) / 5, 0, 1)

	local ok, result = pcall(function()
		return actionRemote:InvokeServer("press")
	end)
	if not ok or type(result) ~= "table" or result.ok ~= true then
		pressed = false
		button.Visible = true
		return
	end
	applySnapshot(result.snapshot)

	-- Salva de catapulta + slow motion: so visual; o resultado real veio do servidor.
	TweenService:Create(camera, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { FieldOfView = 30 })
		:Play()
	task.delay(0.36, function()
		TweenService:Create(camera, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { FieldOfView = 42 })
			:Play()
	end)
end

local function retry(): ()
	if not defeated then
		return
	end
	local ok, result = pcall(function()
		return actionRemote:InvokeServer("retry")
	end)
	if not ok or type(result) ~= "table" or result.ok ~= true then
		return
	end
	defeated = false
	phase = "shown"
	defeatFrame.Visible = false
	clearBanner.Visible = false
	button.Visible = false
	setWall(1)
	resetHorde()
	applySnapshot(result.snapshot)
end

button.MouseButton1Click:Connect(press)
retryButton.MouseButton1Click:Connect(retry)

task.spawn(function()
	while not finished do
		local ok, snapshot = pcall(function()
			return snapshotRemote:InvokeServer()
		end)
		if ok and type(snapshot) == "table" then
			applySnapshot(snapshot)
		end
		task.wait(0.1)
	end
end)

RunService.RenderStepped:Connect(function()
	if finished then
		return
	end
	local now = time()
	local progress
	if phase == "defeated" then
		progress = 1
	elseif pressed then
		progress = pressProgress
	else
		progress = math.clamp((now - scenarioStart) / 5, 0, 1)
	end
	for _, item in ipairs(horde) do
		item.part.Position = ORIGIN
			+ Vector3.new(16 - 38 * progress + item.offset * 0.25, 1.3, item.z)
	end

	local elapsedMs = (now - scenarioStart) * 1000
	if serverSnapshot ~= nil and type(serverSnapshot.elapsedMs) == "number" then
		elapsedMs = serverSnapshot.elapsedMs
	end
	button.Visible = phase == "shown" and not pressed and elapsedMs >= DropInState.BUTTON_AT_MS
	local pulsing = serverSnapshot ~= nil and serverSnapshot.pulse == true
	if pulsing and not pressed then
		buttonScale.Scale = 1 + 0.06 * math.sin(now * 8)
	else
		buttonScale.Scale = 1
	end
end)

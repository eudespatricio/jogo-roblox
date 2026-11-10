--!nonstrict
-- S8: cena de abertura (drop-in) com diorama, horda 3D, DEFENDER e game feel.
-- O visual e local; o estado, timeout e a batalha real continuam no DropInController.
-- Sem texto de tutorial: so o botao, a barra da muralha e o feedback de vitoria/derrota.

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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DropInState = require(Shared:WaitForChild("dropin"):WaitForChild("DropInState"))
local VisualTheme = require(Shared:WaitForChild("visual"):WaitForChild("VisualTheme"))

local visual = script.Parent:WaitForChild("visual")
local UiKit = require(visual:WaitForChild("UiKit"))
local VisualSetup = require(visual:WaitForChild("VisualSetup"))
local ArenaVisual = require(visual:WaitForChild("ArenaVisual"))
local TrapKit = require(visual:WaitForChild("TrapKit"))
local HordeKit = require(visual:WaitForChild("HordeKit"))
local Vfx = require(visual:WaitForChild("Vfx"))
local AudioKit = require(visual:WaitForChild("AudioKit"))

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
local BASE_CAMERA = CFrame.lookAt(ORIGIN + Vector3.new(40, 22, 40), ORIGIN + Vector3.new(2, 2, 0))
camera.CFrame = BASE_CAMERA
camera.FieldOfView = 44

VisualSetup.apply()

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
ArenaVisual.build(scene, ORIGIN, { dropIn = true })

local PREBUILT = {
	r1c3 = { trap = "archer", level = 1 },
	r2c3 = { trap = "tar", level = 1 },
	r3c3 = { trap = "catapult", level = 1 },
	r4c3 = { trap = "frost", level = 1 },
	r5c3 = { trap = "cannon", level = 1 },
}
TrapKit.sync(scene, PREBUILT, ORIGIN)

local horde = {}
local kinds = { "runner", "brute", "swarm" }
for lane = 1, 5 do
	local z = (lane - 3) * 8
	for unit = 1, 2 do
		local kind = kinds[(lane + unit) % #kinds + 1]
		local spawn = ORIGIN + Vector3.new(10 + unit * 2, 0.9, z)
		local model = HordeKit.create(kind, scene, CFrame.new(spawn))
		if model ~= nil then
			horde[#horde + 1] = {
				unit = model,
				z = z,
				offset = unit * 4,
			}
		end
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

local bar = UiKit.panel(root, "WallBar")
bar.Position = UDim2.new(0.1, 0, 0, 16)
bar.Size = UDim2.new(0.8, 0, 0, 26)

local wallLabel = UiKit.label(
	bar,
	"Label",
	"MURALHA",
	UiKit.color(VisualTheme.PALETTE.parchment),
	Enum.Font.GothamBold
)
wallLabel.Position = UDim2.fromOffset(10, 0)
wallLabel.Size = UDim2.new(0.3, -10, 1, 0)
wallLabel.TextScaled = true

local wallProgress = UiKit.progress(bar, "Fill", UiKit.color(VisualTheme.PALETTE.amber))
wallProgress.frame.Position = UDim2.new(0.32, 0, 0.27, 0)
wallProgress.frame.Size = UDim2.new(0.66, -10, 0.46, 0)
wallProgress.frame.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ironDark)

local button = UiKit.button(root, "Defender", "DEFENDER")
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, -34)
button.Size = UDim2.new(0.64, 0, 0, 76)
button.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.amber)
button.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
button.Visible = false
UiKit.stroke(button, UiKit.color(VisualTheme.PALETTE.amberBright), 3, 0)

local buttonScale = Instance.new("UIScale")
buttonScale.Scale = 1
buttonScale.Parent = button

local clearBanner = UiKit.label(
	root,
	"ClearBanner",
	"ONDA LIMPA",
	UiKit.color(VisualTheme.PALETTE.amberBright),
	Enum.Font.GothamBlack
)
clearBanner.AnchorPoint = Vector2.new(0.5, 0)
clearBanner.Position = UDim2.new(0.5, 0, 0.28, 0)
clearBanner.Size = UDim2.new(0.9, 0, 0, 64)
clearBanner.TextScaled = true
clearBanner.Visible = false
UiKit.stroke(clearBanner, UiKit.color(VisualTheme.PALETTE.ink), 3, 0)

local defeatFrame = Instance.new("Frame")
defeatFrame.Name = "Defeat"
defeatFrame.Size = UDim2.fromScale(1, 1)
defeatFrame.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ink)
defeatFrame.BackgroundTransparency = 0.35
defeatFrame.BorderSizePixel = 0
defeatFrame.Visible = false
defeatFrame.Parent = root

local defeatTitle = UiKit.label(
	defeatFrame,
	"Title",
	"A HORDA PASSOU",
	UiKit.color(VisualTheme.PALETTE.danger),
	Enum.Font.GothamBlack
)
defeatTitle.AnchorPoint = Vector2.new(0.5, 0.5)
defeatTitle.Position = UDim2.fromScale(0.5, 0.4)
defeatTitle.Size = UDim2.new(0.9, 0, 0, 84)
defeatTitle.TextXAlignment = Enum.TextXAlignment.Center
defeatTitle.TextScaled = true

local retryButton = UiKit.button(defeatFrame, "Retry", "TENTAR DE NOVO")
retryButton.AnchorPoint = Vector2.new(0.5, 0.5)
retryButton.Position = UDim2.fromScale(0.5, 0.58)
retryButton.Size = UDim2.new(0.55, 0, 0, 64)
retryButton.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.iron)
retryButton.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)

-- ---------------------------------------------------------------- estado local
local phase = "shown"
local serverSnapshot = nil
local scenarioStart = time()
local pressed = false
local pressProgress = 0
local defeated = false
local finished = false

local function setWall(pct: number): ()
	wallProgress.set(pct)
end

local function setHordeVisible(visible: boolean): ()
	for _, item in ipairs(horde) do
		HordeKit.setVisible(item.unit, visible)
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
	AudioKit.play("defeat")
	Vfx.shake(camera, BASE_CAMERA, 0.35, 0.35)
	Vfx.dust(scene, ORIGIN + Vector3.new(-24, 0.5, 0), 10)
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
	AudioKit.play("victory")
	Vfx.ring(scene, ORIGIN + Vector3.new(-4, 0, 0), UiKit.color(VisualTheme.PALETTE.amberBright))
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
	AudioKit.play("ui_click")

	local ok, result = pcall(function()
		return actionRemote:InvokeServer("press")
	end)
	if not ok or type(result) ~= "table" or result.ok ~= true then
		pressed = false
		button.Visible = true
		return
	end
	applySnapshot(result.snapshot)

	-- Salva de catapulta: projeteis cosmeticos do portao ate a horda.
	for index = 1, math.min(6, #horde) do
		local target = ORIGIN + Vector3.new(12 - 30 * (index / 6), 1.2, ((index % 5) - 2) * 8)
		Vfx.projectile(
			scene,
			ORIGIN + Vector3.new(-4, 5, 0),
			target,
			"boulder",
			0.35 + index * 0.05,
			function()
				Vfx.impact(scene, target, UiKit.color(VisualTheme.PALETTE.amber), 5)
				AudioKit.play("impact", 0.7)
			end
		)
	end
	AudioKit.play("projectile")
	AudioKit.play("gate_hit", 0.6)
	TweenService:Create(camera, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { FieldOfView = 30 })
		:Play()
	Vfx.shake(camera, BASE_CAMERA, 0.18, 0.25)
	task.delay(0.36, function()
		TweenService:Create(camera, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { FieldOfView = 40 })
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
	AudioKit.play("horn")
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

AudioKit.play("horn")

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
		local x = 11 - 33 * progress + item.offset * 0.25
		local base = CFrame.new(ORIGIN + Vector3.new(x, 0.9, item.z))
		HordeKit.setBase(item.unit, base)
		HordeKit.step(item.unit, now, not pressed or phase == "shown")
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

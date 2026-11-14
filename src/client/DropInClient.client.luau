--!strict
-- S8: cena de abertura (drop-in) com diorama, horda 3D, DEFENDER e game feel.
-- O visual e local; o estado, timeout e a batalha real continuam no DropInController.
-- Sem texto de tutorial: so o botao, a barra da muralha e o feedback de vitoria/derrota.

local GuiService = game:GetService("GuiService")
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
local BuildLayout = require(Shared:WaitForChild("build"):WaitForChild("BuildLayout"))
local DropInState = require(Shared:WaitForChild("dropin"):WaitForChild("DropInState"))
local I18n = require(Shared:WaitForChild("i18n"):WaitForChild("I18n"))
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

local ORIGIN = Vector3.new(480, 0, 0)
local camera: Camera = if Workspace.CurrentCamera ~= nil
	then Workspace.CurrentCamera
	else Workspace:WaitForChild("Camera") :: Camera
local BASE_CAMERA, BASE_FOV = UiKit.computeArenaCamera(ORIGIN, 1280, 720, "dropin")
local function refreshDropInCamera(): ()
	local vp = camera.ViewportSize
	local cf, fov = UiKit.computeArenaCamera(ORIGIN, vp.X, vp.Y, "dropin")
	BASE_CAMERA = cf
	BASE_FOV = fov
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = BASE_CAMERA
	camera.FieldOfView = BASE_FOV
end
refreshDropInCamera()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshDropInCamera)
UiKit.onCameraAngleChanged(function()
	refreshDropInCamera()
end)

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
ArenaVisual.build(scene, ORIGIN, { dropIn = true, wallTier = 1 })

local FLOOR_TOP_Y = 0.39

local PREBUILT = {
	r1c3 = { trap = "archer", level = 1 },
	r2c3 = { trap = "tar", level = 1 },
	r3c3 = { trap = "catapult", level = 1 },
	r4c3 = { trap = "frost", level = 1 },
	r5c3 = { trap = "cannon", level = 1 },
}
TrapKit.sync(scene, PREBUILT, ORIGIN, { floorTopY = FLOOR_TOP_Y })

local horde = {}
local kinds = { "runner", "brute", "swarm" }
local unitSeq = 0
for lane = 1, 5 do
	local z = (lane - 3) * 8
	for unit = 1, 2 do
		unitSeq += 1
		local kind = kinds[(lane + unit) % #kinds + 1]
		local spawn = ORIGIN + Vector3.new(10 + unit * 2, FLOOR_TOP_Y, z)
		local model = HordeKit.create(kind, scene, CFrame.new(spawn), unitSeq)
		if model ~= nil then
			horde[#horde + 1] = {
				unit = model,
				kind = kind,
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
gui.DisplayOrder = 20
UiKit.applySafeScreenGui(gui)
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = gui

local bar = UiKit.panel(root, "WallBar")
bar.AnchorPoint = Vector2.zero
bar.Position = UDim2.fromOffset(186, 6)
bar.Size = UDim2.fromOffset(300, 44)
UiKit.corner(bar, 12)

local wallLabel = UiKit.label(
	bar,
	"Label",
	"MURALHA",
	UiKit.color(VisualTheme.PALETTE.parchment),
	Enum.Font.GothamBlack
)
wallLabel.Position = UDim2.fromOffset(12, 0)
wallLabel.Size = UDim2.new(0.32, -12, 1, 0)
wallLabel.TextScaled = true
local wallLabelCap = Instance.new("UITextSizeConstraint")
wallLabelCap.MaxTextSize = 15
wallLabelCap.Parent = wallLabel

local wallProgress = UiKit.progress(bar, "Fill", UiKit.color(VisualTheme.PALETTE.amber))
wallProgress.frame.AnchorPoint = Vector2.new(0, 0.5)
wallProgress.frame.Position = UDim2.new(0.34, 0, 0.5, 0)
wallProgress.frame.Size = UDim2.new(0.64, -12, 0.50, 0)
wallProgress.frame.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ironDark)

local button = UiKit.button(root, "Defender", "DEFENDER")
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, -12)
button.Size = UDim2.fromOffset(220, 56)
button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
button.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
button.Visible = false
UiKit.corner(button, 12)
UiKit.stroke(button, UiKit.color(VisualTheme.PALETTE.parchment), 2.5, 0)
local defendGradient = button:FindFirstChildOfClass("UIGradient")
if defendGradient ~= nil then
	defendGradient.Color = ColorSequence.new(
		UiKit.color(VisualTheme.PALETTE.amberBright),
		UiKit.color(VisualTheme.PALETTE.amber)
	)
	defendGradient.Rotation = 90
end
local defendTextCap = Instance.new("UITextSizeConstraint")
defendTextCap.MaxTextSize = 28
defendTextCap.Parent = button

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
defeatFrame.ZIndex = 10
defeatFrame.Parent = root

local defeatTitle = UiKit.label(
	defeatFrame,
	"Title",
	"A HORDA PASSOU",
	UiKit.color(VisualTheme.PALETTE.danger),
	Enum.Font.GothamBlack
)
defeatTitle.AnchorPoint = Vector2.new(0.5, 1)
defeatTitle.Position = UDim2.new(0.5, 0, 0.46, -8)
defeatTitle.Size = UDim2.fromOffset(360, 56)
defeatTitle.TextXAlignment = Enum.TextXAlignment.Center
defeatTitle.TextScaled = true
defeatTitle.ZIndex = 11

local retryButton = UiKit.button(defeatFrame, "Retry", "TENTAR DE NOVO")
retryButton.AnchorPoint = Vector2.new(0.5, 0)
retryButton.Position = UDim2.new(0.5, 0, 0.46, 8)
retryButton.Size = UDim2.fromOffset(220, 50)
retryButton.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.iron)
retryButton.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
retryButton.ZIndex = 11

local localePill = UiKit.createCompactLocalePill(root)
localePill.AnchorPoint = Vector2.zero
localePill.Position = UDim2.new(1, -56, 0, 6)

local function applyDropInLayout(): ()
	local size = root.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local hudRects = BuildLayout.computeHud(size.X, size.Y, UiKit.safeTopbarInsets(root))
	bar.Position = UDim2.fromOffset(hudRects.combatTopPill.x, hudRects.combatTopPill.y)
	bar.Size = UDim2.fromOffset(hudRects.combatTopPill.w, hudRects.combatTopPill.h)

	localePill.Position =
		UDim2.fromOffset(hudRects.localeBtn.x + hudRects.localeBtn.w - 48, hudRects.localeBtn.y)
	localePill.Size = UDim2.fromOffset(48, 44)

	button.Position = UDim2.new(0.5, 0, 1, -12)
	button.Size = UDim2.fromOffset(
		math.clamp(math.floor(size.X * 0.42), 180, 280),
		math.clamp(math.floor(size.Y * 0.14), 48, 64)
	)

	defeatTitle.Position = UDim2.new(0.5, 0, 0.46, -8)
	defeatTitle.Size =
		UDim2.fromOffset(math.min(size.X - 32, 520), math.clamp(math.floor(size.Y * 0.16), 44, 68))
	retryButton.Position = UDim2.new(0.5, 0, 0.46, 8)
	retryButton.Size = UDim2.fromOffset(
		math.clamp(math.floor(size.X * 0.46), 180, 260),
		math.clamp(math.floor(size.Y * 0.14), 46, 58)
	)
end

root:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyDropInLayout)
root:GetPropertyChangedSignal("AbsolutePosition"):Connect(applyDropInLayout)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(applyDropInLayout)
task.defer(applyDropInLayout)

local DEFEAT_TITLE = {
	pt = "A HORDA PASSOU",
	en = "THE HORDE BROKE THROUGH",
	es = "LA HORDA PASÓ",
}
local RETRY_LABEL = {
	pt = "TENTAR DE NOVO",
	en = "TRY AGAIN",
	es = "REINTENTAR",
}

local function pickLoc(entry: { pt: string, en: string, es: string }, loc: string): string
	if loc == "en" then
		return entry.en
	elseif loc == "es" then
		return entry.es
	end
	return entry.pt
end

local function applyLocale(loc: string): ()
	wallLabel.Text = I18n.t(loc, "game_title")
	button.Text = I18n.t(loc, "cta_defend")
	clearBanner.Text = I18n.t(loc, "toast_starter_40g")
	defeatTitle.Text = pickLoc(DEFEAT_TITLE, loc)
	retryButton.Text = pickLoc(RETRY_LABEL, loc)
end

applyLocale(UiKit.getLocale())
local localeConn: RBXScriptConnection? = UiKit.onLocaleChanged(applyLocale)

-- ---------------------------------------------------------------- estado local
local phase = "shown"
local serverSnapshot: any = nil
local scenarioStart = time()
local pressed = false
local pressProgress = 0
local defeated = false
local finished = false

local lastWallPct = 1

local function setWall(pct: number): ()
	if pct < lastWallPct - 0.005 and pct > 0 then
		AudioKit.playAt("wall_hit", ORIGIN + Vector3.new(-22, 1.5, 0))
	end
	lastWallPct = pct
	wallProgress.set(pct)
	AudioKit.setWallPct(pct)
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
	AudioKit.playAt("gate_fracture", ORIGIN + Vector3.new(-24, 2, 0))
	AudioKit.play("defeat")
	Vfx.shake(camera, BASE_CAMERA, 0.35, 0.35)
	Vfx.dust(scene, ORIGIN + Vector3.new(-24, 0.5, 0), 10)
end

local function cleanup(): ()
	if localeConn ~= nil then
		localeConn:Disconnect()
		localeConn = nil
	end
	AudioKit.setMode("build")
	AudioKit.setWallPct(1)
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
	for index, item in ipairs(horde) do
		if index > 4 then
			break
		end
		local unit: any = item.unit
		if unit ~= nil and typeof(unit.base) == "CFrame" then
			AudioKit.unitDeath(item.kind, (unit.base :: CFrame).Position)
		end
	end
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
	if type(snapshot.wallLevel) == "number" then
		ArenaVisual.setWallTier(scene, snapshot.wallLevel)
	end
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
				AudioKit.trapImpact("catapult", target)
			end
		)
	end
	AudioKit.playAt("catapult_fire", ORIGIN + Vector3.new(-4, 5, 0))
	AudioKit.playAt("wall_hit", ORIGIN + Vector3.new(-6, 2, 0), 0.6)
	TweenService:Create(camera, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { FieldOfView = 30 })
		:Play()
	Vfx.shake(camera, BASE_CAMERA, 0.18, 0.25)
	task.delay(0.36, function()
		TweenService
			:Create(camera, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { FieldOfView = BASE_FOV })
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
	AudioKit.playAt("horde_spawn", ORIGIN + Vector3.new(14, 2, 0), 0.8)
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

AudioKit.setMode("raid")
AudioKit.play("horn")
AudioKit.playAt("horde_spawn", ORIGIN + Vector3.new(14, 2, 0), 0.8)

RunService.RenderStepped:Connect(function(dt: number)
	if finished then
		return
	end
	local now = time()
	TrapKit.step(dt)
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
		local base = CFrame.new(ORIGIN + Vector3.new(x, FLOOR_TOP_Y, item.z))
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

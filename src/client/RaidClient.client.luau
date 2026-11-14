--!strict
-- S8/S8.2: raid com replay 3D em tela cheia no Workspace real (-220, 0, 0).
-- O servidor devolve seed + wall fantasma; o cliente roda o MESMO Battle, confere o hash e
-- anima 8 s em 3D real com sombras, luzes, projeteis e fisica F2. A decisao segue no servidor.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("MuralhaRemotes")
local raidStart = remotes:WaitForChild("RaidStart") :: RemoteFunction
local raidEvent = remotes:WaitForChild("RaidEvent") :: RemoteEvent
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Core = require(Shared:WaitForChild("sim"):WaitForChild("core"))
local BuildLayout = require(Shared:WaitForChild("build"):WaitForChild("BuildLayout"))
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
	if ReplicatedStorage:GetAttribute("RaidEnabled") ~= nil then
		break
	end
	task.wait(0.1)
end
if ReplicatedStorage:GetAttribute("RaidEnabled") ~= true then
	return
end

for _ = 1, 50 do
	if ReplicatedStorage:GetAttribute("DropInEnabled") ~= nil then
		break
	end
	task.wait(0.1)
end
if ReplicatedStorage:GetAttribute("DropInEnabled") == true then
	while player:GetAttribute("DropInDone") ~= true do
		task.wait(0.1)
	end
end

VisualSetup.apply()

local gui = Instance.new("ScreenGui")
gui.Name = "RaidGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 15
UiKit.applySafeScreenGui(gui)
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = gui

local defendButton = UiKit.button(root, "Defend", "")
defendButton.AnchorPoint = Vector2.zero
defendButton.Position = UDim2.new(1, -130, 1, -104)
defendButton.Size = UDim2.fromOffset(116, 44)
defendButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
defendButton.Text = ""
UiKit.corner(defendButton, 12)
UiKit.stroke(defendButton, UiKit.color(VisualTheme.PALETTE.amberBright), 2, 0)

local defendGradient = defendButton:FindFirstChildOfClass("UIGradient")
if defendGradient ~= nil then
	defendGradient.Color =
		ColorSequence.new(Color3.fromRGB(217, 119, 6), Color3.fromRGB(245, 158, 11))
	defendGradient.Rotation = 18
end
local defendPad = defendButton:FindFirstChildOfClass("UIPadding")
if defendPad ~= nil then
	defendPad.PaddingLeft = UDim.new(0, 0)
	defendPad.PaddingRight = UDim.new(0, 0)
	defendPad.PaddingTop = UDim.new(0, 0)
	defendPad.PaddingBottom = UDim.new(0, 0)
end

local defendIcon = Instance.new("Frame")
defendIcon.Name = "Icon"
defendIcon.AnchorPoint = Vector2.new(0, 0.5)
defendIcon.Position = UDim2.new(0, 6, 0.5, 0)
defendIcon.Size = UDim2.fromOffset(18, 18)
defendIcon.BackgroundTransparency = 1
defendIcon.Parent = defendButton

local shieldBody = Instance.new("Frame")
shieldBody.Name = "ShieldBody"
shieldBody.AnchorPoint = Vector2.new(0.5, 0.5)
shieldBody.Position = UDim2.fromScale(0.5, 0.45)
shieldBody.Size = UDim2.fromScale(0.68, 0.72)
shieldBody.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.white)
shieldBody.BorderSizePixel = 0
shieldBody.Parent = defendIcon
UiKit.corner(shieldBody, 4)

local shieldTip = Instance.new("Frame")
shieldTip.Name = "ShieldTip"
shieldTip.AnchorPoint = Vector2.new(0.5, 0.5)
shieldTip.Position = UDim2.fromScale(0.5, 0.74)
shieldTip.Size = UDim2.fromScale(0.42, 0.42)
shieldTip.Rotation = 45
shieldTip.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.white)
shieldTip.BorderSizePixel = 0
shieldTip.Parent = defendIcon
UiKit.corner(shieldTip, 2)

local shieldCore = Instance.new("Frame")
shieldCore.Name = "ShieldCore"
shieldCore.AnchorPoint = Vector2.new(0.5, 0.5)
shieldCore.Position = UDim2.fromScale(0.5, 0.48)
shieldCore.Size = UDim2.fromScale(0.32, 0.36)
shieldCore.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ink)
shieldCore.BorderSizePixel = 0
shieldCore.Parent = defendIcon
UiKit.corner(shieldCore, 2)

local defendLabel = UiKit.label(
	defendButton,
	"Label",
	I18n.t(UiKit.getLocale(), "cta_defend"),
	UiKit.color(VisualTheme.PALETTE.white),
	Enum.Font.GothamBlack
)
defendLabel.Position = UDim2.new(0, 26, 0, 4)
defendLabel.Size = UDim2.new(1, -30, 1, -8)
defendLabel.TextXAlignment = Enum.TextXAlignment.Center
defendLabel.TextScaled = true
defendLabel.TextWrapped = false
local defendTextCap = Instance.new("UITextSizeConstraint")
defendTextCap.MinTextSize = 10
defendTextCap.MaxTextSize = 16
defendTextCap.Parent = defendLabel
UiKit.stroke(defendLabel, UiKit.color(VisualTheme.PALETTE.ink), 1.5, 0.25)

local attackButton = UiKit.button(root, "Attack", "")
attackButton.AnchorPoint = Vector2.zero
attackButton.Position = UDim2.new(1, -130, 1, -54)
attackButton.Size = UDim2.fromOffset(116, 44)
attackButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
attackButton.Text = ""
UiKit.corner(attackButton, 12)
UiKit.stroke(attackButton, UiKit.color(VisualTheme.PALETTE.amberBright), 2, 0)

local attackGradient = attackButton:FindFirstChildOfClass("UIGradient")
if attackGradient ~= nil then
	attackGradient.Color =
		ColorSequence.new(Color3.fromRGB(16, 163, 127), Color3.fromRGB(224, 146, 16))
	attackGradient.Rotation = 18
end
local attackPad = attackButton:FindFirstChildOfClass("UIPadding")
if attackPad ~= nil then
	attackPad.PaddingLeft = UDim.new(0, 0)
	attackPad.PaddingRight = UDim.new(0, 0)
	attackPad.PaddingTop = UDim.new(0, 0)
	attackPad.PaddingBottom = UDim.new(0, 0)
end

local attackIcon = Instance.new("Frame")
attackIcon.Name = "Icon"
attackIcon.AnchorPoint = Vector2.new(0, 0.5)
attackIcon.Position = UDim2.new(0, 6, 0.5, 0)
attackIcon.Size = UDim2.fromOffset(18, 18)
attackIcon.BackgroundTransparency = 1
attackIcon.Parent = attackButton

local blade = Instance.new("Frame")
blade.Name = "Blade"
blade.AnchorPoint = Vector2.new(0.5, 0.5)
blade.Position = UDim2.fromScale(0.56, 0.44)
blade.Size = UDim2.fromScale(0.22, 0.78)
blade.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.white)
blade.BorderSizePixel = 0
blade.Rotation = 42
blade.Parent = attackIcon
UiKit.corner(blade, 2)

local guard = Instance.new("Frame")
guard.Name = "Guard"
guard.AnchorPoint = Vector2.new(0.5, 0.5)
guard.Position = UDim2.fromScale(0.32, 0.68)
guard.Size = UDim2.fromScale(0.46, 0.14)
guard.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.amberBright)
guard.BorderSizePixel = 0
guard.Rotation = 42
guard.Parent = attackIcon
UiKit.corner(guard, 2)

local hilt = Instance.new("Frame")
hilt.Name = "Hilt"
hilt.AnchorPoint = Vector2.new(0.5, 0.5)
hilt.Position = UDim2.fromScale(0.20, 0.80)
hilt.Size = UDim2.fromScale(0.18, 0.24)
hilt.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ink)
hilt.BorderSizePixel = 0
hilt.Rotation = 42
hilt.Parent = attackIcon
UiKit.corner(hilt, 2)

local attackLabel = UiKit.label(
	attackButton,
	"Label",
	I18n.t(UiKit.getLocale(), "cta_attack"),
	UiKit.color(VisualTheme.PALETTE.white),
	Enum.Font.GothamBlack
)
attackLabel.Position = UDim2.new(0, 26, 0, 4)
attackLabel.Size = UDim2.new(1, -30, 1, -8)
attackLabel.TextXAlignment = Enum.TextXAlignment.Center
attackLabel.TextScaled = true
attackLabel.TextWrapped = false
local attackTextCap = Instance.new("UITextSizeConstraint")
attackTextCap.MinTextSize = 10
attackTextCap.MaxTextSize = 16
attackTextCap.Parent = attackLabel
UiKit.stroke(attackLabel, UiKit.color(VisualTheme.PALETTE.ink), 1.5, 0.25)

local RAID_ORIGIN = Vector3.new(-520, 0, 0)
local FLOOR_TOP_Y = 0.33

local function getRaidCamera(): (CFrame, number)
	local cam = Workspace.CurrentCamera
	local vp = if cam ~= nil then cam.ViewportSize else Vector2.new(1280, 720)
	return UiKit.computeArenaCamera(RAID_ORIGIN, vp.X, vp.Y, "raid")
end

local topHud = UiKit.panel(root, "RaidTopHud")
topHud.AnchorPoint = Vector2.zero
topHud.Position = UDim2.fromOffset(192, 6)
topHud.Size = UDim2.fromOffset(280, 44)
topHud.Visible = false
UiKit.corner(topHud, 12)

local title = UiKit.label(
	topHud,
	"Title",
	"RAID",
	UiKit.color(VisualTheme.PALETTE.amberBright),
	Enum.Font.GothamBlack
)
title.Position = UDim2.fromOffset(10, 3)
title.Size = UDim2.new(0.54, -10, 0, 17)
title.TextScaled = true
title.TextWrapped = false
title.TextTruncate = Enum.TextTruncate.AtEnd

local status = UiKit.label(
	topHud,
	"Status",
	"ATACANDO...",
	UiKit.color(VisualTheme.PALETTE.parchment),
	Enum.Font.GothamBold
)
status.Position = UDim2.new(0.54, 0, 0, 3)
status.Size = UDim2.new(0.46, -10, 0, 17)
status.TextXAlignment = Enum.TextXAlignment.Right
status.TextScaled = true
status.TextWrapped = false
status.TextTruncate = Enum.TextTruncate.AtEnd

local wallProgress = UiKit.progress(topHud, "WallProgress", UiKit.color(VisualTheme.PALETTE.amber))
wallProgress.frame.Position = UDim2.fromOffset(10, 23)
wallProgress.frame.Size = UDim2.new(1, -94, 0, 9)

local wallLabel = UiKit.label(
	topHud,
	"WallLabel",
	"MURALHA 100%",
	UiKit.color(VisualTheme.PALETTE.parchment),
	Enum.Font.GothamBold
)
wallLabel.Position = UDim2.new(1, -80, 0, 20)
wallLabel.Size = UDim2.fromOffset(70, 14)
wallLabel.TextXAlignment = Enum.TextXAlignment.Right
wallLabel.TextScaled = true
wallLabel.TextWrapped = false

local replayProgress =
	UiKit.progress(topHud, "ReplayProgress", UiKit.color(VisualTheme.PALETTE.teal))
replayProgress.frame.Position = UDim2.fromOffset(10, 36)
replayProgress.frame.Size = UDim2.new(1, -20, 0, 4)

local SPEED_OPTIONS = { 1, 2, 3, 4 }
local speedIndex = 1
local speedMult = 1

local combatCamButton = UiKit.button(root, "CombatCamToggle", UiKit.cameraButtonLabel(nil, true))
combatCamButton.AnchorPoint = Vector2.zero
combatCamButton.Position = UDim2.new(1, -220, 1, -50)
combatCamButton.Size = UDim2.fromOffset(52, 44)
combatCamButton.Font = Enum.Font.GothamBlack
combatCamButton.Visible = false
UiKit.corner(combatCamButton, 12)
local combatCamCap = Instance.new("UITextSizeConstraint")
combatCamCap.MinTextSize = 10
combatCamCap.MaxTextSize = 13
combatCamCap.Parent = combatCamButton

local speedButton = UiKit.button(root, "SpeedToggle", "1x")
speedButton.AnchorPoint = Vector2.zero
speedButton.Position = UDim2.new(1, -162, 1, -50)
speedButton.Size = UDim2.fromOffset(54, 44)
speedButton.Font = Enum.Font.GothamBlack
speedButton.Visible = false
UiKit.corner(speedButton, 12)

local closeButton = UiKit.button(root, "Close", I18n.t(UiKit.getLocale(), "cta_close"))
closeButton.AnchorPoint = Vector2.zero
closeButton.Position = UDim2.new(1, -102, 1, -50)
closeButton.Size = UDim2.fromOffset(96, 44)
closeButton.Visible = false
UiKit.corner(closeButton, 12)
local closeCap = Instance.new("UITextSizeConstraint")
closeCap.MinTextSize = 10
closeCap.MaxTextSize = 15
closeCap.Parent = closeButton

local resultCard = UiKit.panel(root, "ResultCard")
resultCard.AnchorPoint = Vector2.zero
resultCard.Size = UDim2.fromOffset(320, 200)
resultCard.Visible = false
resultCard.ZIndex = 18
UiKit.corner(resultCard, 14)
UiKit.stroke(resultCard, UiKit.color(VisualTheme.PALETTE.amber), 2, 0.15)

local resultTitle = UiKit.label(
	resultCard,
	"OutcomeTitle",
	"VICTORY",
	UiKit.color(VisualTheme.PALETTE.amberBright),
	Enum.Font.GothamBlack
)
resultTitle.Position = UDim2.fromOffset(14, 10)
resultTitle.Size = UDim2.new(1, -28, 0, 32)
resultTitle.TextXAlignment = Enum.TextXAlignment.Center
resultTitle.TextScaled = true
resultTitle.ZIndex = 19

local resultCoin = UiKit.iconCoin(resultCard, 20)
resultCoin.Position = UDim2.fromOffset(16, 52)
resultCoin.ZIndex = 19

local details = UiKit.label(
	resultCard,
	"Details",
	"",
	UiKit.color(VisualTheme.PALETTE.parchment),
	Enum.Font.GothamBold
)
details.Position = UDim2.fromOffset(42, 48)
details.Size = UDim2.new(1, -56, 0, 28)
details.TextYAlignment = Enum.TextYAlignment.Center
details.TextWrapped = true
details.TextScaled = true
details.ZIndex = 19
local detailsCap = Instance.new("UITextSizeConstraint")
detailsCap.MinTextSize = 10
detailsCap.MaxTextSize = 16
detailsCap.Parent = details

local hashLabel = UiKit.label(
	resultCard,
	"HashCaption",
	"",
	UiKit.color(VisualTheme.PALETTE.stone),
	Enum.Font.Code
)
hashLabel.Position = UDim2.fromOffset(14, 80)
hashLabel.Size = UDim2.new(1, -28, 0, 18)
hashLabel.TextXAlignment = Enum.TextXAlignment.Center
hashLabel.TextScaled = true
hashLabel.ZIndex = 19
local hashCap = Instance.new("UITextSizeConstraint")
hashCap.MinTextSize = 9
hashCap.MaxTextSize = 12
hashCap.Parent = hashLabel

local replayButton = UiKit.button(resultCard, "Replay", "REPLAY")
replayButton.Position = UDim2.new(0, 14, 1, -54)
replayButton.Size = UDim2.new(0.47, -14, 0, 44)
replayButton.Font = Enum.Font.GothamBlack
replayButton.Visible = false
replayButton.ZIndex = 19
UiKit.corner(replayButton, 10)
local replayCap = Instance.new("UITextSizeConstraint")
replayCap.MaxTextSize = 14
replayCap.MinTextSize = 10
replayCap.Parent = replayButton

local resultCloseButton =
	UiKit.button(resultCard, "ResultClose", I18n.t(UiKit.getLocale(), "cta_close"))
resultCloseButton.AnchorPoint = Vector2.new(1, 0)
resultCloseButton.Position = UDim2.new(1, -14, 1, -54)
resultCloseButton.Size = UDim2.new(0.47, -14, 0, 44)
resultCloseButton.ZIndex = 19
UiKit.corner(resultCloseButton, 10)
local resultCloseCap = Instance.new("UITextSizeConstraint")
resultCloseCap.MaxTextSize = 14
resultCloseCap.MinTextSize = 10
resultCloseCap.Parent = resultCloseButton

local function applyRect(obj: GuiObject, r: BuildLayout.Rect): ()
	obj.Position = UDim2.fromOffset(r.x, r.y)
	obj.Size = UDim2.fromOffset(r.w, r.h)
end

local function applyRaidLayout(): ()
	local size = root.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local hudRects = BuildLayout.computeHud(size.X, size.Y, UiKit.safeTopbarInsets(root))
	applyRect(defendButton, hudRects.defendBtn)
	applyRect(attackButton, hudRects.attackBtn)
	applyRect(topHud, hudRects.combatTopPill)
	applyRect(combatCamButton, hudRects.combatCamBtn)
	applyRect(speedButton, hudRects.combatSpeedBtn)
	applyRect(closeButton, hudRects.combatCloseBtn)
	applyRect(resultCard, hudRects.combatResultCard)
end

root:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyRaidLayout)
root:GetPropertyChangedSignal("AbsolutePosition"):Connect(applyRaidLayout)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(applyRaidLayout)
task.defer(applyRaidLayout)

local RAID_I18N: { [string]: { pt: string, en: string, es: string } } = {
	attacking = { pt = "ATACANDO...", en = "ATTACKING...", es = "ATACANDO..." },
	defending = { pt = "DEFENDENDO...", en = "DEFENDING...", es = "DEFENDIENDO..." },
	defend_title = { pt = "DEFESA", en = "DEFEND", es = "DEFENSA" },
	live_info = {
		pt = "70 fantasmas · %dx",
		en = "70 ghosts · %dx",
		es = "70 fantasmas · %dx",
	},
	replay_btn = { pt = "REPLAY", en = "REPLAY", es = "REPETIR" },
	replay_live = { pt = "REPLAY 20s", en = "20s REPLAY", es = "REPETICIÓN 20s" },
	victory = { pt = "VITORIA", en = "VICTORY", es = "VICTORIA" },
	defeat = { pt = "DERROTA", en = "DEFEAT", es = "DERROTA" },
	failed = { pt = "RAID FALHOU", en = "RAID FAILED", es = "ASALTO FALLIDO" },
	divergence = { pt = "DIVERGENCIA", en = "DIVERGENCE", es = "DIVERGENCIA" },
	replay_failed = { pt = "REPLAY FALHOU", en = "REPLAY FAILED", es = "REPETICIÓN FALLIDA" },
	ready = { pt = "PRONTO", en = "READY", es = "LISTO" },
	wall_prefix = { pt = "MURALHA", en = "WALL", es = "MURALLA" },
	server_down = {
		pt = "servidor indisponivel",
		en = "server unavailable",
		es = "servidor no disponible",
	},
	start_fail = {
		pt = "Falha ao iniciar: ",
		en = "Failed to start: ",
		es = "Error al iniciar: ",
	},
}

local function rmsg(key: string): string
	local entry = RAID_I18N[key]
	if entry == nil then
		return key
	end
	local loc = UiKit.getLocale()
	if loc == "en" then
		return entry.en
	elseif loc == "es" then
		return entry.es
	end
	return entry.pt
end

local function refreshStaticLocale(): ()
	local loc = UiKit.getLocale()
	defendLabel.Text = I18n.t(loc, "cta_defend")
	attackLabel.Text = I18n.t(loc, "cta_attack")
	closeButton.Text = I18n.t(loc, "cta_close")
	resultCloseButton.Text = I18n.t(loc, "cta_close")
	replayButton.Text = rmsg("replay_btn")
	title.Text = I18n.t(loc, "game_title") .. " · RAID"
end

refreshStaticLocale()
UiKit.onLocaleChanged(function()
	refreshStaticLocale()
end)

local busy = false
local scene: Folder? = nil
local unitVisuals: { [number]: any } = {}
local unitVisible: { [number]: boolean } = {}
local prevUnitHp: { [number]: number } = {}
local lastUnitPos: { [number]: Vector3 } = {}
local unitKind: { [number]: string } = {}
local lastWallPct = 1
local fracturedGate = false
local activeBattleId: string? = nil
local lastResult: any = nil
local replayToken = 0
local shakeUntil = 0

speedButton.MouseButton1Click:Connect(function()
	speedIndex = (speedIndex % #SPEED_OPTIONS) + 1
	speedMult = SPEED_OPTIONS[speedIndex]
	speedButton.Text = tostring(speedMult) .. "x"
	AudioKit.play("ui_toggle")
end)

local function focusRaidCamera(): ()
	local cam = Workspace.CurrentCamera
	if cam ~= nil then
		local cf, fov = getRaidCamera()
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = cf
		cam.FieldOfView = fov
	end
end

combatCamButton.MouseButton1Click:Connect(function()
	UiKit.cycleCameraAngle()
	combatCamButton.Text = UiKit.cameraButtonLabel(nil, true)
	AudioKit.play("ui_toggle")
	focusRaidCamera()
end)

UiKit.onCameraAngleChanged(function()
	combatCamButton.Text = UiKit.cameraButtonLabel(nil, true)
	if topHud.Visible then
		focusRaidCamera()
	end
end)

local raidCamRef = Workspace.CurrentCamera
if raidCamRef ~= nil then
	raidCamRef:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if topHud.Visible then
			focusRaidCamera()
		end
	end)
end

local function setBusy(value: boolean): ()
	busy = value
	local visible = not value and not topHud.Visible
	defendButton.Visible = visible
	attackButton.Visible = visible
end

local function clearScene(): ()
	replayToken += 1
	if scene ~= nil then
		scene:Destroy()
		scene = nil
	end
	unitVisuals = {}
	unitVisible = {}
	prevUnitHp = {}
	lastUnitPos = {}
	unitKind = {}
	lastWallPct = 1
	fracturedGate = false
	shakeUntil = 0
end

local function kindFromSpeed(speed: number): string
	if speed <= 75 then
		return "brute"
	elseif speed >= 210 then
		return "swarm"
	else
		return "runner"
	end
end

-- Roda o MESMO Battle do servidor e captura quadros. O hash final tem que bater.
local function buildFrames(result: any): (any, any)
	local battle = Core.Battle.new({
		seed = result.seed,
		simVersion = result.simVersion,
		wall = result.wall,
		wave = {
			count = result.waveCount or 70,
			spawnEveryTicks = result.spawnEveryTicks or 14,
		},
	})
	local frames = {}
	local function snapshot()
		local unitsFrame = {}
		for index = 1, battle.uCount do
			if battle.uHp[index] > 0 then
				unitsFrame[#unitsFrame + 1] = {
					id = index,
					kind = kindFromSpeed(battle.uBaseSpeed[index]),
					lane = battle.uLane[index],
					x = battle.uX[index],
					y = battle.uY[index],
					hp = battle.uHp[index],
				}
			end
		end
		frames[#frames + 1] = {
			wallPct = math.clamp(battle.wallHp / battle.wallMax, 0, 1),
			units = unitsFrame,
		}
	end
	snapshot()
	while not battle:Finished() do
		battle:Step()
		if battle.tick % 2 == 0 or battle:Finished() then
			snapshot()
		end
	end
	return frames, battle:Result()
end

local function buildScene(result: any, frames: { any }): ()
	local newScene = Instance.new("Folder")
	newScene.Name = "RaidLocalScene"
	newScene.Parent = Workspace
	scene = newScene

	focusRaidCamera()
	local wallTier = if type(result.wall) == "table"
			and type(result.wall.level) == "number"
		then result.wall.level
		else 1
	ArenaVisual.build(newScene, RAID_ORIGIN, { dropIn = false, wallTier = wallTier })

	local cells: { [string]: TrapKit.TrapData } = {}
	local wallTraps = if type(result.wall) == "table"
			and type(result.wall.traps) == "table"
		then result.wall.traps
		else {}
	for index, trap in ipairs(wallTraps) do
		local slot = trap.slot or trap.cell or ("t" .. tostring(index))
		cells[slot] = {
			trap = trap.type,
			level = trap.level,
			x = trap.x,
			y = trap.y,
		}
	end
	TrapKit.sync(newScene, cells, RAID_ORIGIN, { floorTopY = FLOOR_TOP_Y })

	local kindById: { [number]: string } = {}
	for _, frame in ipairs(frames) do
		for _, unitData in ipairs(frame.units or {}) do
			if unitData.id ~= nil and kindById[unitData.id] == nil then
				kindById[unitData.id] = unitData.kind
			end
		end
	end

	unitVisuals = {}
	unitVisible = {}
	local spawnPos = RAID_ORIGIN + Vector3.new(24, FLOOR_TOP_Y, 0)
	for id, kind in pairs(kindById) do
		local unit = HordeKit.create(kind, newScene, CFrame.new(spawnPos), id)
		if unit ~= nil then
			HordeKit.setVisible(unit, false)
			unitVisuals[id] = unit
			unitVisible[id] = false
		end
	end
end

local function inSynergyRange(a: Model, b: Model): boolean
	local ax = a:GetAttribute("ArenaX")
	local ay = a:GetAttribute("ArenaY")
	local bx = b:GetAttribute("ArenaX")
	local by = b:GetAttribute("ArenaY")
	if
		type(ax) == "number"
		and type(ay) == "number"
		and type(bx) == "number"
		and type(by) == "number"
	then
		return math.abs(ax - bx) * 1000 + math.abs(ay - by) * 1500 <= 1500000
	end
	return true
end

local function resolveTrapArenaPos(model: Model): (number?, number?)
	local ax = model:GetAttribute("ArenaX")
	local ay = model:GetAttribute("ArenaY")
	if type(ax) == "number" and type(ay) == "number" then
		return ax, ay
	end
	local cell = string.gsub(model.Name, "^Trap_", "")
	local cx, cy = Core.cellToPos(cell)
	return cx, cy
end

local function trapCanHitUnit(model: Model, ux: number, uy: number, lane: number): boolean
	local trapId = model:GetAttribute("TrapId")
	local def = if type(trapId) == "string" then (Core.TRAP :: any)[trapId] else nil
	local ax, ay = resolveTrapArenaPos(model)
	if ax ~= nil and ay ~= nil and def ~= nil then
		if def.omni == true then
			local dx = ux - ax
			local dy = uy - ay
			return dx * dx + dy * dy <= def.range * def.range
		end
		local dx = ux - ax
		return math.abs(uy - ay) <= Core.ARENA.laneReach and dx > 0 and dx <= def.range
	end
	if type(ay) == "number" then
		return math.abs(ay - Core.laneY(lane)) <= Core.ARENA.laneReach
	end
	local prefix = "Trap_r" .. tostring(lane) .. "c"
	return string.sub(model.Name, 1, #prefix) == prefix
end

local function detectTrapSynergy(model: Model, trapId: string, allTraps: { Model }): string?
	local isArtillery = trapId == "cannon" or trapId == "catapult"
	for _, other in ipairs(allTraps) do
		if other ~= model then
			local otherId = other:GetAttribute("TrapId")
			if type(otherId) == "string" and inSynergyRange(model, other) then
				if
					(trapId == "tar" and (otherId == "cannon" or otherId == "catapult"))
					or (isArtillery and otherId == "tar")
				then
					return "incendiary_tar"
				elseif
					(trapId == "frost" and (otherId == "cannon" or otherId == "catapult"))
					or (isArtillery and otherId == "frost")
				then
					return "thermal_shock"
				elseif trapId == "archer" and otherId == "archer" then
					return "cross_battery"
				end
			end
		end
	end
	return nil
end

local function fireTrapsForLane(
	activeScene: Folder,
	lane: number,
	ux: number,
	uy: number,
	hitPos: Vector3?,
	unitId: number?
): ()
	local trapsFolder = activeScene:FindFirstChild("MuralhaTraps")
	if trapsFolder == nil then
		return
	end
	local allTraps: { Model } = {}
	local fired: { Model } = {}
	for _, child in ipairs(trapsFolder:GetChildren()) do
		if child:IsA("Model") then
			allTraps[#allTraps + 1] = child
			if trapCanHitUnit(child, ux, uy, lane) then
				TrapKit.fire(child)
				fired[#fired + 1] = child
			end
		end
	end
	for _, model in ipairs(fired) do
		local trapId = model:GetAttribute("TrapId")
		if type(trapId) == "string" then
			local synergyKind = detectTrapSynergy(model, trapId, allTraps)
			local originPos = model:GetPivot().Position + Vector3.new(0, 1.5, 0)
			local targetPos = hitPos or (originPos + Vector3.new(6, -1.0, 0))
			Vfx.trapEffect(activeScene, trapId, originPos, targetPos, synergyKind)
			AudioKit.trapFire(trapId, originPos, synergyKind)
		end
	end
	if hitPos ~= nil and #fired > 0 then
		local pick = fired[((unitId or 0) % #fired) + 1]
		local trapId = pick:GetAttribute("TrapId")
		if type(trapId) == "string" then
			AudioKit.trapImpact(trapId, hitPos)
		end
	end
end

local function unitWorldPos(lane: number, arenaX: number): Vector3
	local z = -16 + (lane - 1) * 8
	local x = -22 + (arenaX / 10000) * 47
	return RAID_ORIGIN + Vector3.new(x, FLOOR_TOP_Y, z)
end

local function applyDiscreteFrame(frame: any): ()
	local activeScene = scene
	if activeScene == nil then
		return
	end
	local pct = frame.wallPct or 0
	if math.abs(pct - lastWallPct) > 0.005 then
		if pct < lastWallPct then
			AudioKit.playAt("wall_hit", RAID_ORIGIN + Vector3.new(-22, 1.5, 0))
		end
		lastWallPct = pct
		Vfx.dust(activeScene, RAID_ORIGIN + Vector3.new(-22, 1.5, 0), 5)
		shakeUntil = math.max(shakeUntil, time() + 0.14)
	end
	AudioKit.setWallPct(pct)
	if pct <= 0 and not fracturedGate then
		fracturedGate = true
		shakeUntil = math.max(shakeUntil, time() + 0.28)
		Vfx.fractureGate(activeScene, RAID_ORIGIN + Vector3.new(-24, FLOOR_TOP_Y, 0))
		AudioKit.playAt("gate_fracture", RAID_ORIGIN + Vector3.new(-24, FLOOR_TOP_Y + 2, 0))
	end
	wallLabel.Text = string.format("%s %d%%", rmsg("wall_prefix"), math.floor(pct * 100))
	wallProgress.set(pct)

	local seen: { [number]: boolean } = {}
	for _, unitData in ipairs(frame.units or {}) do
		local id = unitData.id
		if id ~= nil then
			seen[id] = true
			unitKind[id] = unitData.kind
			local unit = unitVisuals[id]
			if unit == nil then
				unit = HordeKit.create(
					unitData.kind,
					activeScene,
					CFrame.new(RAID_ORIGIN + Vector3.new(24, FLOOR_TOP_Y, 0)),
					id
				)
				if unit ~= nil then
					unitVisuals[id] = unit
				end
			end
			if unit ~= nil then
				if not unitVisible[id] then
					HordeKit.setVisible(unit, true)
					unitVisible[id] = true
					if prevUnitHp[id] == nil then
						AudioKit.playAt(
							"horde_spawn",
							RAID_ORIGIN + Vector3.new(24, FLOOR_TOP_Y + 2, 0),
							0.8
						)
					end
				end
				local pos = unitWorldPos(unitData.lane, unitData.x)
				lastUnitPos[id] = pos
				local prevHp = prevUnitHp[id]
				if prevHp ~= nil and unitData.hp < prevHp then
					HordeKit.hitSquash(unit)
					local uy = if type(unitData.y) == "number"
						then unitData.y
						else Core.laneY(unitData.lane)
					fireTrapsForLane(activeScene, unitData.lane, unitData.x, uy, pos, id)
				end
				prevUnitHp[id] = unitData.hp
			end
		end
	end
	for id, unit in pairs(unitVisuals) do
		if not seen[id] and unitVisible[id] then
			local position = lastUnitPos[id]
				or (unit.base and unit.base.Position)
				or (RAID_ORIGIN + Vector3.new(0, FLOOR_TOP_Y, 0))
			local teal = Color3.fromRGB(20, 184, 166)
			Vfx.death(activeScene, position, teal)
			Vfx.ragdollEnemy(activeScene, position, teal, Vector3.new(12, 8, 0))
			AudioKit.unitDeath(unitKind[id] or "runner", position)
			HordeKit.setVisible(unit, false)
			unitVisible[id] = false
		end
	end
end

local function stepVisualFrame(frameA: any, frameB: any, alpha: number): ()
	local activeScene = scene
	if activeScene == nil then
		return
	end
	local cam = Workspace.CurrentCamera
	if cam ~= nil then
		local baseCf, baseFov = getRaidCamera()
		cam.FieldOfView = baseFov
		if time() < shakeUntil then
			local jx = (math.random() - 0.5) * 0.45
			local jy = (math.random() - 0.5) * 0.3
			cam.CFrame = baseCf * CFrame.new(jx, jy, 0)
		else
			cam.CFrame = baseCf
		end
	end

	local nextById: { [number]: any } = {}
	if frameB ~= nil and frameB ~= frameA then
		for _, unitData in ipairs(frameB.units or {}) do
			if unitData.id ~= nil then
				nextById[unitData.id] = unitData
			end
		end
	end

	local now = time()
	for _, unitData in ipairs(frameA.units or {}) do
		local id = unitData.id
		if id ~= nil then
			local unit = unitVisuals[id]
			if unit ~= nil and unitVisible[id] then
				local targetData = nextById[id]
				local xVal = unitData.x
				if targetData ~= nil then
					xVal = unitData.x + (targetData.x - unitData.x) * alpha
				end
				local pos = unitWorldPos(unitData.lane, xVal)
				lastUnitPos[id] = pos
				HordeKit.setBase(unit, CFrame.new(pos))
				HordeKit.step(unit, now, true)
			end
		end
	end
end

local function showError(message: string): ()
	status.Text = rmsg("failed")
	resultTitle.Text = rmsg("failed")
	resultTitle.TextColor3 = UiKit.color(VisualTheme.PALETTE.danger)
	resultCoin.Visible = false
	details.Text = message
	hashLabel.Text = ""
	replayButton.Visible = false
	combatCamButton.Visible = false
	speedButton.Visible = false
	closeButton.Visible = false
	resultCard.Visible = true
	setBusy(false)
end

local function startReplay(result: any, isQuickReplay: boolean?): ()
	clearScene()
	local myToken = replayToken
	wallLabel.Visible = true
	wallProgress.frame.Visible = true
	replayProgress.frame.Visible = true
	resultCard.Visible = false
	combatCamButton.Text = UiKit.cameraButtonLabel(nil, true)
	combatCamButton.Visible = true
	speedButton.Visible = true
	closeButton.Visible = true
	replayButton.Visible = false
	wallProgress.set(1)
	replayProgress.set(0)
	lastWallPct = 1

	local ok, frames, final = pcall(buildFrames, result)
	if not ok or type(frames) ~= "table" or type(final) ~= "table" then
		showError("Replay: " .. tostring(frames))
		return
	end
	if final.hash ~= result.resultHash then
		raidEvent:FireServer("divergence", {
			battleId = result.battleId,
			expectedHash = result.resultHash,
			actualHash = final.hash,
		})
		status.Text = rmsg("divergence")
		resultTitle.Text = rmsg("divergence")
		resultTitle.TextColor3 = UiKit.color(VisualTheme.PALETTE.danger)
		resultCoin.Visible = false
		details.Text = string.format(
			"expected %s · local %s",
			tostring(result.resultHash),
			tostring(final.hash)
		)
		hashLabel.Text = ""
		replayButton.Visible = false
		combatCamButton.Visible = false
		speedButton.Visible = false
		closeButton.Visible = false
		resultCard.Visible = true
		setBusy(false)
		return
	end

	local sceneOk, sceneErr = pcall(buildScene :: any, result, frames)
	if not sceneOk then
		showError("3D: " .. tostring(sceneErr))
		return
	end
	local isDefend = result.mode == "defend"
	title.Text = (if isDefend then rmsg("defend_title") else "RAID")
		.. " · "
		.. tostring(result.phantomName or "?")
	status.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
	if isQuickReplay == true then
		status.Text = rmsg("replay_live")
	elseif isDefend then
		status.Text = rmsg("defending")
	else
		status.Text = rmsg("attacking")
	end
	details.Text = string.format(rmsg("live_info"), speedMult)

	AudioKit.play("horn")
	pcall(applyDiscreteFrame, frames[1])
	pcall(stepVisualFrame, frames[1], frames[2], 0)
	local baseSeconds = if isQuickReplay == true
		then 20
		else math.max(3, (tonumber(result.ticks) or Core.MAX_TICKS) / Core.TICK_HZ)
	local started = time()
	local lastTick = started
	local simElapsed = 0
	local lastDiscreteIndex = 1
	task.spawn(function()
		local animationOk, animationErr = pcall(function()
			while replayToken == myToken do
				local now = time()
				local dt = math.min(now - lastTick, 0.1)
				lastTick = now
				simElapsed += dt * speedMult
				local progress = math.clamp(simElapsed / baseSeconds, 0, 1)
				local fPos = 1 + progress * (#frames - 1)
				local index = math.clamp(math.floor(fPos), 1, #frames)
				local nextIndex = math.min(index + 1, #frames)
				local alpha = fPos - index
				if index > lastDiscreteIndex then
					for stepIdx = lastDiscreteIndex + 1, index do
						applyDiscreteFrame(frames[stepIdx])
					end
					lastDiscreteIndex = index
				end
				stepVisualFrame(frames[index], frames[nextIndex], alpha)
				TrapKit.step(dt * speedMult)
				replayProgress.set(progress)
				if progress >= 1 then
					break
				end
				RunService.Heartbeat:Wait()
			end
		end)
		if replayToken ~= myToken then
			return
		end
		if animationOk then
			local loc = UiKit.getLocale()
			local playerWon = if type(result.playerWon) == "boolean"
				then result.playerWon
				else (result.winner == "attacker")
			local outcomeText = if playerWon then rmsg("victory") else rmsg("defeat")
			local outcomeColor = UiKit.color(
				if playerWon then VisualTheme.PALETTE.amberBright else VisualTheme.PALETTE.danger
			)
			status.TextColor3 = outcomeColor
			if isQuickReplay == true then
				local wallSec = math.max(1, math.floor(time() - started + 0.5))
				status.Text = I18n.t(loc, "replay_banner", wallSec, outcomeText)
			else
				status.Text = outcomeText
			end
			resultTitle.Text = outcomeText
			resultTitle.TextColor3 = outcomeColor
			resultCoin.Visible = true
			details.Text = string.format(
				"HP %s · +%s",
				tostring(result.wallHp),
				I18n.t(loc, "hud_gold", tonumber(result.rewardGold) or 0)
			)
			hashLabel.Text = tostring(result.resultHash)
			replayButton.Visible = true
			resultCard.Visible = true
			combatCamButton.Visible = false
			speedButton.Visible = false
			closeButton.Visible = false
			AudioKit.play(playerWon and "victory" or "defeat", 0.85)
		else
			status.Text = rmsg("replay_failed")
			resultTitle.Text = rmsg("replay_failed")
			resultTitle.TextColor3 = UiKit.color(VisualTheme.PALETTE.danger)
			details.Text = tostring(animationErr)
			hashLabel.Text = ""
			replayButton.Visible = false
			resultCard.Visible = true
			combatCamButton.Visible = false
			speedButton.Visible = false
			closeButton.Visible = false
		end
		setBusy(false)
	end)
end

local function showModal(): ()
	player:SetAttribute("MuralhaInRaid", true)
	topHud.Visible = true
	combatCamButton.Text = UiKit.cameraButtonLabel(nil, true)
	combatCamButton.Visible = true
	speedButton.Visible = true
	closeButton.Visible = true
	resultCard.Visible = false
	defendButton.Visible = false
	attackButton.Visible = false
	focusRaidCamera()
end

local function hideModal(): ()
	clearScene()
	topHud.Visible = false
	combatCamButton.Visible = false
	speedButton.Visible = false
	closeButton.Visible = false
	resultCard.Visible = false
	replayButton.Visible = false
	status.Text = rmsg("ready")
	details.Text = ""
	hashLabel.Text = ""
	if activeBattleId ~= nil then
		raidEvent:FireServer("close", { battleId = activeBattleId })
		activeBattleId = nil
	end
	AudioKit.setMode("build")
	AudioKit.setWallPct(1)
	player:SetAttribute("MuralhaInRaid", false)
	setBusy(false)
end

local function startBattle(mode: string): ()
	if busy then
		return
	end
	setBusy(true)
	showModal()
	local isDefend = mode == "defend"
	title.Text = if isDefend then rmsg("defend_title") else "RAID"
	status.Text = if isDefend then rmsg("defending") else rmsg("attacking")
	status.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
	details.Text = ""
	hashLabel.Text = ""
	replayButton.Visible = false
	resultCard.Visible = false
	combatCamButton.Text = UiKit.cameraButtonLabel(nil, true)
	combatCamButton.Visible = true
	speedButton.Visible = true
	closeButton.Visible = true
	clearScene()
	AudioKit.play("ui_click")
	AudioKit.setMode("raid")
	AudioKit.setWallPct(1)

	local ok, result = pcall(function()
		return raidStart:InvokeServer({ mode = mode })
	end)
	if not ok or type(result) ~= "table" or result.ok ~= true then
		local reason = rmsg("server_down")
		if ok and type(result) == "table" then
			reason = tostring(result.err)
		end
		showError(rmsg("start_fail") .. reason)
		return
	end

	activeBattleId = if type(result.battleId) == "string" then result.battleId else nil
	lastResult = result
	startReplay(result, false)
end

defendButton.MouseButton1Click:Connect(function()
	startBattle("defend")
end)

attackButton.MouseButton1Click:Connect(function()
	startBattle("raid")
end)

replayButton.MouseButton1Click:Connect(function()
	if lastResult ~= nil and not busy then
		setBusy(true)
		resultCard.Visible = false
		combatCamButton.Text = UiKit.cameraButtonLabel(nil, true)
		combatCamButton.Visible = true
		speedButton.Visible = true
		closeButton.Visible = true
		startReplay(lastResult, true)
	end
end)

closeButton.MouseButton1Click:Connect(hideModal)
resultCloseButton.MouseButton1Click:Connect(hideModal)

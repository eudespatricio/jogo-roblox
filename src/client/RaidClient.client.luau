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
local battleLogStateRemote = remotes:WaitForChild("BattleLogState") :: RemoteFunction
local campaignStateRemote = remotes:WaitForChild("CampaignState") :: RemoteFunction
local campaignClaimRemote = remotes:WaitForChild("CampaignClaim") :: RemoteFunction
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CampaignCatalog = require(Shared:WaitForChild("campaign"):WaitForChild("CampaignCatalog"))
local Core = require(Shared:WaitForChild("sim"):WaitForChild("core"))
local TrapCatalog = require(Shared:WaitForChild("data"):WaitForChild("TrapCatalog"))
local PostMatchReport = require(Shared:WaitForChild("raid"):WaitForChild("PostMatchReport"))
local BuildLayout = require(Shared:WaitForChild("build"):WaitForChild("BuildLayout"))
local I18n = require(Shared:WaitForChild("i18n"):WaitForChild("I18n"))
local PortalThemes = require(Shared:WaitForChild("visual"):WaitForChild("PortalThemes"))
local VisualTheme = require(Shared:WaitForChild("visual"):WaitForChild("VisualTheme"))

local visual = script.Parent:WaitForChild("visual")
local UiKit = require(visual:WaitForChild("UiKit"))
local VisualSetup = require(visual:WaitForChild("VisualSetup"))
local ArenaVisual = require(visual:WaitForChild("ArenaVisual"))
local CrowdKit = require(visual:WaitForChild("CrowdKit"))
local TrapKit = require(visual:WaitForChild("TrapKit"))
local HordeKit = require(visual:WaitForChild("HordeKit"))
local Vfx = require(visual:WaitForChild("Vfx"))
local AudioKit = require(visual:WaitForChild("AudioKit"))
local CampaignUi = require(visual:WaitForChild("CampaignUi"))
local PostMatchUi = require(visual:WaitForChild("PostMatchUi"))
local BattleLogUi = require(visual:WaitForChild("BattleLogUi"))
local TransitionKit = require(visual:WaitForChild("TransitionKit"))

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
local MIN_ARENA_ENTRY_FRAMES = 6

local function getRaidCamera(): (CFrame, number)
	local cam = Workspace.CurrentCamera
	local vp = if cam ~= nil then cam.ViewportSize else Vector2.new(1280, 720)
	return UiKit.computeArenaCamera(RAID_ORIGIN, vp.X, vp.Y, "raid")
end

local topHud = UiKit.panel(root, "RaidTopHud")
topHud.AnchorPoint = Vector2.zero
topHud.Position = UDim2.fromOffset(192, 6)
topHud.Size = UDim2.fromOffset(280, 44)
topHud.BackgroundTransparency = 0.28
topHud.Visible = false
UiKit.corner(topHud, 12)
UiKit.stroke(topHud, UiKit.color(VisualTheme.PALETTE.iron), 1, 0.32)

local title = UiKit.label(
	topHud,
	"Title",
	"RAID",
	UiKit.color(VisualTheme.PALETTE.amberBright),
	Enum.Font.GothamBlack
)
title.Position = UDim2.fromOffset(10, 3)
title.Size = UDim2.new(0.58, -10, 0, 18)
title.TextScaled = true
title.TextWrapped = false
title.TextTruncate = Enum.TextTruncate.AtEnd
local topTitleCap = Instance.new("UITextSizeConstraint")
topTitleCap.MinTextSize = 11
topTitleCap.MaxTextSize = 15
topTitleCap.Parent = title

local status = UiKit.label(
	topHud,
	"Status",
	"ATACANDO...",
	UiKit.color(VisualTheme.PALETTE.parchment),
	Enum.Font.GothamBold
)
status.Position = UDim2.new(0.58, 2, 0, 3)
status.Size = UDim2.new(0.42, -12, 0, 18)
status.TextXAlignment = Enum.TextXAlignment.Right
status.TextScaled = true
status.TextWrapped = false
status.TextTruncate = Enum.TextTruncate.AtEnd
local topStatusCap = Instance.new("UITextSizeConstraint")
topStatusCap.MinTextSize = 11
topStatusCap.MaxTextSize = 15
topStatusCap.Parent = status

local wallProgress = UiKit.progress(topHud, "WallProgress", UiKit.color(VisualTheme.PALETTE.amber))
wallProgress.frame.Position = UDim2.fromOffset(10, 25)
wallProgress.frame.Size = UDim2.new(1, -98, 0, 8)

local wallLabel = UiKit.label(
	topHud,
	"WallLabel",
	"MURALHA 100%",
	UiKit.color(VisualTheme.PALETTE.parchment),
	Enum.Font.GothamBold
)
wallLabel.Position = UDim2.new(1, -84, 0, 21)
wallLabel.Size = UDim2.fromOffset(74, 16)
wallLabel.TextXAlignment = Enum.TextXAlignment.Right
wallLabel.TextScaled = true
wallLabel.TextWrapped = false
local wallLabelCap = Instance.new("UITextSizeConstraint")
wallLabelCap.MinTextSize = 11
wallLabelCap.MaxTextSize = 14
wallLabelCap.Parent = wallLabel

local replayProgress =
	UiKit.progress(topHud, "ReplayProgress", UiKit.color(VisualTheme.PALETTE.teal))
replayProgress.frame.Position = UDim2.fromOffset(10, 38)
replayProgress.frame.Size = UDim2.new(1, -20, 0, 3)

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
resultTitle.Position = UDim2.fromOffset(14, 6)
resultTitle.Size = UDim2.new(1, -28, 0, 22)
resultTitle.TextXAlignment = Enum.TextXAlignment.Center
resultTitle.TextScaled = true
resultTitle.ZIndex = 19

local resultCoin = UiKit.iconCoin(resultCard, 18)
resultCoin.Position = UDim2.fromOffset(16, 30)
resultCoin.ZIndex = 19

local details = UiKit.label(
	resultCard,
	"Details",
	"",
	UiKit.color(VisualTheme.PALETTE.parchment),
	Enum.Font.GothamBold
)
details.Position = UDim2.fromOffset(40, 29)
details.Size = UDim2.new(1, -54, 0, 20)
details.TextYAlignment = Enum.TextYAlignment.Center
details.TextWrapped = true
details.TextScaled = true
details.ZIndex = 19
local detailsCap = Instance.new("UITextSizeConstraint")
detailsCap.MinTextSize = 10
detailsCap.MaxTextSize = 14
detailsCap.Parent = details

local hashLabel = UiKit.label(
	resultCard,
	"HashCaption",
	"",
	UiKit.color(VisualTheme.PALETTE.stone),
	Enum.Font.Code
)
hashLabel.Position = UDim2.fromOffset(14, 50)
hashLabel.Size = UDim2.new(1, -28, 0, 13)
hashLabel.TextXAlignment = Enum.TextXAlignment.Center
hashLabel.TextScaled = true
hashLabel.ZIndex = 19
local hashCap = Instance.new("UITextSizeConstraint")
hashCap.MinTextSize = 8
hashCap.MaxTextSize = 11
hashCap.Parent = hashLabel

local function makeRewardPill(parent: Instance, name: string, strokeColor: Color3): TextLabel
	local pill = Instance.new("TextLabel")
	pill.Name = name
	pill.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ironDark)
	pill.BackgroundTransparency = 0.08
	pill.BorderSizePixel = 0
	pill.Text = ""
	pill.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
	pill.Font = Enum.Font.GothamBlack
	pill.TextScaled = true
	pill.TextWrapped = false
	pill.Visible = false
	pill.ZIndex = 19
	pill.Parent = parent
	UiKit.corner(pill, 6)
	UiKit.stroke(pill, strokeColor, 1.5, 0.15)
	local cap = Instance.new("UITextSizeConstraint")
	cap.MinTextSize = 8
	cap.MaxTextSize = 11
	cap.Parent = pill
	return pill
end

local champBetPill =
	makeRewardPill(resultCard, "ChampBetPill", UiKit.color(VisualTheme.PALETTE.amberBright))
champBetPill.Position = UDim2.fromOffset(14, 64)
champBetPill.Size = UDim2.new(1, -28, 0, 16)

local dropBadgesRow = Instance.new("Frame")
dropBadgesRow.Name = "DropBadgesRow"
dropBadgesRow.Position = UDim2.fromOffset(14, 82)
dropBadgesRow.Size = UDim2.new(1, -28, 0, 16)
dropBadgesRow.BackgroundTransparency = 1
dropBadgesRow.ZIndex = 19
dropBadgesRow.Parent = resultCard

local dropBadgesLayout = Instance.new("UIListLayout")
dropBadgesLayout.FillDirection = Enum.FillDirection.Horizontal
dropBadgesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
dropBadgesLayout.VerticalAlignment = Enum.VerticalAlignment.Center
dropBadgesLayout.Padding = UDim.new(0, 6)
dropBadgesLayout.Parent = dropBadgesRow

local shardBadge =
	makeRewardPill(dropBadgesRow, "ShardBadge", UiKit.color(VisualTheme.PALETTE.teal))
shardBadge.Size = UDim2.new(0.48, -3, 1, 0)

local coreBadge =
	makeRewardPill(dropBadgesRow, "CoreBadge", UiKit.color(VisualTheme.PALETTE.amberBright))
coreBadge.Size = UDim2.new(0.48, -3, 1, 0)

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

local startBattle: (mode: string, extraOpts: { [string]: any }?) -> ()
local playLogReplay: (entry: any) -> ()

local postMatchUi = PostMatchUi.create(resultCard, {
	replayButton = replayButton,
	closeButton = resultCloseButton,
	onRevenge = function(battleId: string)
		startBattle("revenge", { battleId = battleId })
	end,
})

local campaignUi = CampaignUi.create(root, {
	fetchState = function()
		local ok, res = pcall(function()
			return campaignStateRemote:InvokeServer()
		end)
		return if ok then res else { ok = false, err = "server_down" }
	end,
	claimMilestone = function(act: number)
		local ok, res = pcall(function()
			return campaignClaimRemote:InvokeServer(act)
		end)
		return if ok then res else { ok = false, err = "server_down" }
	end,
	onLaunchStage = function(stageId: string, difficulty: CampaignCatalog.DifficultyMode)
		startBattle("campaign", { stageId = stageId, difficulty = difficulty })
	end,
})

local battleLogUi = BattleLogUi.create(root, {
	fetchLogs = function()
		local ok, res = pcall(function()
			return battleLogStateRemote:InvokeServer("list")
		end)
		return if ok then res else { ok = false, err = "server_down" }
	end,
	ackReplay = function()
		task.spawn(function()
			pcall(function()
				battleLogStateRemote:InvokeServer("replay_ack")
			end)
		end)
	end,
	onReplay = function(entry: any)
		playLogReplay(entry)
	end,
	onRevenge = function(battleId: string)
		startBattle("revenge", { battleId = battleId })
	end,
})

campaignUi.storyButton.MouseButton1Click:Connect(function()
	battleLogUi.closeModal()
end)
battleLogUi.logButton.MouseButton1Click:Connect(function()
	campaignUi.closeModal()
end)

local hasActiveBossStage = false

local function applyRect(obj: GuiObject, r: BuildLayout.Rect): ()
	obj.Position = UDim2.fromOffset(r.x, r.y)
	obj.Size = UDim2.fromOffset(r.w, r.h)
end

local function updateWallHudLayout(): ()
	if topHud.Size.X.Offset < 248 then
		wallProgress.frame.Size = UDim2.new(1, -64, 0, 8)
		wallLabel.Position = UDim2.new(1, -52, 0, 21)
		wallLabel.Size = UDim2.fromOffset(42, 16)
	else
		wallProgress.frame.Size = UDim2.new(1, -98, 0, 8)
		wallLabel.Position = UDim2.new(1, -84, 0, 21)
		wallLabel.Size = UDim2.fromOffset(74, 16)
	end
end

local function applyRaidLayout(): ()
	local size = root.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local hudRects = BuildLayout.computeHud(size.X, size.Y, UiKit.safeTopbarInsets(root))
	applyRect(defendButton, hudRects.defendBtn)
	applyRect(attackButton, hudRects.attackBtn)
	applyRect(
		topHud,
		if hasActiveBossStage then hudRects.combatTopPill else hudRects.combatTopSoloPill
	)
	updateWallHudLayout()
	applyRect(combatCamButton, hudRects.combatCamBtn)
	applyRect(speedButton, hudRects.combatSpeedBtn)
	applyRect(closeButton, hudRects.combatCloseBtn)
	applyRect(resultCard, hudRects.combatResultCard)
	campaignUi.applyLayout(hudRects)
	battleLogUi.applyLayout(hudRects)
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
	campaignUi.refreshLocale()
	battleLogUi.refreshLocale()
	postMatchUi.refreshLocale(loc)
end

refreshStaticLocale()
UiKit.onLocaleChanged(function()
	refreshStaticLocale()
end)

type UnitLifecycle = {
	id: number,
	kind: string,
	isChampion: boolean,
	isFrozen: boolean,
	lane: number,
	firstIdx: number,
	firstX: number,
	lastIdx: number,
	lastX: number,
	lastY: number,
	fromPortal: boolean,
	killedByTrap: boolean,
	visualDeathIdx: number,
	arenaDeathX: number,
}

type BossSpawnInfo = {
	firstIdx: number,
	laneCenter: number,
}

local busy = false
local scene: Folder? = nil
local raidCrowd: CrowdKit.CrowdHandle? = nil
local activePortalTheme: PortalThemes.PortalThemeSpec? = nil
local bossVisual: HordeKit.BossUnit? = nil
local bossSpawnInfo: BossSpawnInfo? = nil
local breachedBoss = false
local bossSpawned = false
local prevBossHp: number? = nil
local prevBossState: string? = nil
local prevBossEnraged = false
local prevBossAlive = false
local lastBossPos: Vector3? = nil
local bossDyingUntil = 0
local bossTimeDilationStartAt = 0
local bossTimeDilationUntil = 0
local bossHiddenAfterDeath = false
local bossSlammedThisCycle = false
local lastCrowdComboAt = 0
local unitVisuals: { [number]: any } = {}
local unitVisible: { [number]: boolean } = {}
local unitLifecycle: { [number]: UnitLifecycle } = {}
local unitDeadDone: { [number]: boolean } = {}
local breachedUnits: { [number]: boolean } = {}
local prevUnitHp: { [number]: number } = {}
local lastUnitPos: { [number]: Vector3? } = {}
local unitKind: { [number]: string } = {}
local unitFrozen: { [number]: boolean } = {}
local unitIsChampion: { [number]: boolean } = {}
local lastWallPct = 1
local lastWallStage = 0
local fracturedGate = false
local activeBattleId: string? = nil
local lastResult: any = nil
local replayToken = 0
local shakeUntil = 0

local function themeRgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function resolvePortalThemeKey(result: any): PortalThemes.PortalThemeId
	if type(result.portalTheme) == "string" and PortalThemes.THEMES[result.portalTheme] ~= nil then
		return result.portalTheme :: PortalThemes.PortalThemeId
	end
	if result.mode == "campaign" then
		local actHint = if type(result.matchup) == "table"
				and type(result.matchup.card2) == "table"
			then result.matchup.card2.act
			else nil
		if actHint ~= nil then
			return PortalThemes.resolve(actHint).id
		end
		if type(result.stageId) == "string" then
			return PortalThemes.fromStageId(result.stageId)
		end
	end
	return "rift"
end

local function triggerPortalBreach(lane: number, isBoss: boolean): Vector3
	local resolvedTheme = activePortalTheme or PortalThemes.resolve("rift")
	local mouthZ = (math.clamp(lane, 1, 5) - 3) * 0.95
	local mouthPos = RAID_ORIGIN + Vector3.new(PortalThemes.THROAT_X, FLOOR_TOP_Y, mouthZ)
	local activeScene = scene
	if activeScene ~= nil then
		Vfx.portalBreach(
			activeScene,
			mouthPos,
			themeRgb(resolvedTheme.veilColor),
			themeRgb(resolvedTheme.accentColor),
			isBoss
		)
	end
	return mouthPos
end

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
	campaignUi.setButtonsVisible(visible)
	battleLogUi.setButtonsVisible(visible)
end

local function clearScene(): ()
	replayToken += 1
	if raidCrowd ~= nil then
		raidCrowd:destroy()
		raidCrowd = nil
	end
	if scene ~= nil then
		scene:Destroy()
		scene = nil
	end
	activePortalTheme = nil
	bossVisual = nil
	bossSpawnInfo = nil
	breachedBoss = false
	hasActiveBossStage = false
	bossSpawned = false
	prevBossHp = nil
	prevBossState = nil
	prevBossEnraged = false
	prevBossAlive = false
	lastBossPos = nil
	bossDyingUntil = 0
	bossTimeDilationStartAt = 0
	bossTimeDilationUntil = 0
	bossHiddenAfterDeath = false
	bossSlammedThisCycle = false
	lastCrowdComboAt = 0
	campaignUi.hideBossHud()
	applyRaidLayout()
	AudioKit.setBossActive(false)
	unitVisuals = {}
	unitVisible = {}
	unitLifecycle = {}
	unitDeadDone = {}
	breachedUnits = {}
	prevUnitHp = {}
	lastUnitPos = {}
	unitKind = {}
	unitFrozen = {}
	unitIsChampion = {}
	lastWallPct = 1
	lastWallStage = 0
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
	local waveArg = if type(result.waveSpec) == "table"
		then result.waveSpec
		else {
			count = result.waveCount or 70,
			spawnEveryTicks = result.spawnEveryTicks or 14,
		}
	local battle = Core.Battle.new({
		seed = result.seed,
		simVersion = result.simVersion,
		wall = result.wall,
		wave = waveArg,
	})
	local frames = {}
	local capturedSpawn: { [number]: boolean } = {}
	local prevLaneLeaks = { 0, 0, 0, 0, 0 }
	local sawBossAbility = false
	local function snapshot()
		local unitsFrame = {}
		local champArr = (battle :: any).uIsChampion
		local slowUntilArr = (battle :: any).uSlowUntil
		local frostUntilArr = (battle :: any).uFrostUntil
		for index = 1, battle.uCount do
			local isChamp = type(champArr) == "table" and champArr[index] == true
			local uSlowUntil = if type(slowUntilArr) == "table"
				then (tonumber(slowUntilArr[index]) or 0)
				else 0
			local uFrostUntil = if type(frostUntilArr) == "table"
				then (tonumber(frostUntilArr[index]) or 0)
				else 0
			local isFrozen = (uSlowUntil > 0 and battle.tick <= uSlowUntil + 2)
				or (uFrostUntil > 0 and battle.tick <= uFrostUntil + 2)
			if battle.uHp[index] > 0 then
				capturedSpawn[index] = true
				unitsFrame[#unitsFrame + 1] = {
					id = index,
					kind = battle.uType[index] or kindFromSpeed(battle.uBaseSpeed[index]),
					isChampion = isChamp,
					isFrozen = isFrozen,
					uSlowUntil = uSlowUntil,
					lane = battle.uLane[index],
					x = battle.uX[index],
					y = battle.uY[index],
					hp = battle.uHp[index],
				}
			elseif not capturedSpawn[index] then
				capturedSpawn[index] = true
				local kind = battle.uType[index] or kindFromSpeed(battle.uBaseSpeed[index])
				local unitDef = (Core.UNIT :: any)[kind]
				local maxHp = if unitDef ~= nil and type(unitDef.hp) == "number"
					then unitDef.hp
					else 7000
				unitsFrame[#unitsFrame + 1] = {
					id = index,
					kind = kind,
					isChampion = isChamp,
					isFrozen = isFrozen,
					uSlowUntil = uSlowUntil,
					lane = battle.uLane[index],
					x = Core.ARENA.spawnX,
					y = battle.uY[index],
					hp = 1,
					maxHp = maxHp,
					spawnKilled = true,
				}
			end
		end
		local bossSnap = if battle.boss ~= nil and battle.tick >= battle.boss.spawnTick
			then battle:BossSnapshot()
			else nil
		if bossSnap ~= nil and sawBossAbility then
			(bossSnap :: any).didAbility = true
		end
		local hitLanes: { number } = {}
		local laneCounts = (battle :: any).laneLeakCount
		if type(laneCounts) == "table" then
			for laneIdx = 1, 5 do
				local curCount = tonumber(laneCounts[laneIdx]) or 0
				local deltaCount = curCount - prevLaneLeaks[laneIdx]
				if deltaCount > 0 then
					hitLanes[#hitLanes + 1] = laneIdx
					prevLaneLeaks[laneIdx] = curCount
				end
			end
		end
		local hitSpan: number? = nil
		if bossSnap ~= nil and (bossSnap.state == "ATTACK" or sawBossAbility) and #hitLanes > 0 then
			hitSpan = tonumber((battle.boss :: any).laneSpan) or 3
		end
		frames[#frames + 1] = {
			wallPct = math.clamp(battle.wallHp / battle.wallMax, 0, 1),
			units = unitsFrame,
			boss = bossSnap,
			hitLanes = if #hitLanes > 0 then hitLanes else nil,
			hitSpan = hitSpan,
		}
	end
	snapshot()
	while not battle:Finished() do
		battle:Step()
		if battle.boss ~= nil and battle.boss.state == "ABILITY" then
			sawBossAbility = true
		end
		if battle.tick % 2 == 0 or battle:Finished() then
			snapshot()
			sawBossAbility = false
		end
	end
	local final = battle:Result()
	if result.report == nil then
		result.report = PostMatchReport.fromBattle(battle, final, TrapCatalog)
	end
	return frames, final
end

local function frontKillArenaX(wallTraps: { any }, lane: number): number
	local uy = Core.laneY(lane)
	local checkX = Core.ARENA.spawnX - 210
	local bestTrapX: number? = nil
	for _, trap in ipairs(wallTraps) do
		local ax = trap.x
		local ay = trap.y
		if (ax == nil or ay == nil) and type(trap.cell) == "string" then
			local cx, cy = Core.cellToPos(trap.cell)
			ax = ax or cx
			ay = ay or cy
		end
		local def = if type(trap.type) == "string" then (Core.TRAP :: any)[trap.type] else nil
		if type(ax) == "number" and type(ay) == "number" and def ~= nil then
			local inReach = false
			if def.omni == true then
				local dx = checkX - ax
				local dy = uy - ay
				inReach = dx * dx + dy * dy <= def.range * def.range
			else
				local dx = checkX - ax
				inReach = math.abs(uy - ay) <= Core.ARENA.laneReach and dx > 0 and dx <= def.range
			end
			if inReach and (bestTrapX == nil or ax > bestTrapX) then
				bestTrapX = ax
			end
		end
	end
	return math.clamp((bestTrapX or 8000) + 450, 8250, 9050)
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
	local portalThemeKey = resolvePortalThemeKey(result)
	activePortalTheme = PortalThemes.resolve(portalThemeKey)
	ArenaVisual.build(
		newScene,
		RAID_ORIGIN,
		{ dropIn = false, wallTier = wallTier, portalTheme = portalThemeKey }
	)
	lastWallStage = 0
	ArenaVisual.setWallDamageStage(newScene, 1.0)
	raidCrowd = CrowdKit.build(newScene, RAID_ORIGIN)

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

	local portalSpawnOrigin = RAID_ORIGIN + Vector3.new(PortalThemes.THROAT_X, FLOOR_TOP_Y, 0)
	local bossId: string? = if type(result.bossId) == "string" then result.bossId else nil
	bossSpawnInfo = nil
	breachedBoss = false
	for frameIdx, frame in ipairs(frames) do
		if type(frame.boss) == "table" and frame.boss.alive == true then
			if bossId == nil and type(frame.boss.bossId) == "string" then
				bossId = frame.boss.bossId
			end
			if bossSpawnInfo == nil and (frame.boss.x == nil or frame.boss.x >= 8500) then
				bossSpawnInfo = {
					firstIdx = frameIdx,
					laneCenter = frame.boss.laneCenter or 3,
				}
			end
		end
	end
	if bossId ~= nil then
		local createdBoss = HordeKit.createBoss(bossId, newScene, CFrame.new(portalSpawnOrigin))
		HordeKit.setBossApproachScale(createdBoss, PortalThemes.MIN_SCALE)
		HordeKit.setBossVisible(createdBoss, false)
		bossVisual = createdBoss
	end

	type RawUnitTrack = {
		id: number,
		kind: string,
		isChampion: boolean,
		isFrozen: boolean,
		lane: number,
		firstIdx: number,
		firstX: number,
		lastIdx: number,
		lastX: number,
		lastY: number,
		spawnKilled: boolean,
	}
	local tracks: { [number]: RawUnitTrack } = {}
	for frameIdx, frame in ipairs(frames) do
		for _, unitData in ipairs(frame.units or {}) do
			local id = unitData.id
			if type(id) == "number" then
				local ux = if type(unitData.x) == "number" then unitData.x else Core.ARENA.spawnX
				local lane = if type(unitData.lane) == "number" then unitData.lane else 3
				local uy = if type(unitData.y) == "number" then unitData.y else Core.laneY(lane)
				local dataFrozen = unitData.isFrozen == true
				local existing = tracks[id]
				if existing == nil then
					tracks[id] = {
						id = id,
						kind = unitData.kind,
						isChampion = unitData.isChampion == true,
						isFrozen = dataFrozen,
						lane = lane,
						firstIdx = frameIdx,
						firstX = ux,
						lastIdx = frameIdx,
						lastX = ux,
						lastY = uy,
						spawnKilled = unitData.spawnKilled == true,
					}
				else
					existing.lastIdx = frameIdx
					existing.lastX = ux
					existing.lastY = uy
					existing.isFrozen = dataFrozen
					if unitData.isChampion == true then
						existing.isChampion = true
					end
					if unitData.spawnKilled ~= true then
						existing.spawnKilled = false
					end
				end
			end
		end
	end

	local aliveInFinal: { [number]: boolean } = {}
	local finalFrame = frames[#frames]
	if finalFrame ~= nil then
		for _, unitData in ipairs(finalFrame.units or {}) do
			if type(unitData.id) == "number" and unitData.spawnKilled ~= true then
				aliveInFinal[unitData.id] = true
			end
		end
	end

	local function hasFrostTrapInRange(checkX: number, checkY: number): boolean
		for _, trap in ipairs(wallTraps) do
			if trap.type == "frost" then
				local ax = trap.x
				local ay = trap.y
				if (ax == nil or ay == nil) and type(trap.cell) == "string" then
					local cx, cy = Core.cellToPos(trap.cell)
					ax = ax or cx
					ay = ay or cy
				end
				local def = (Core.TRAP :: any).frost
				if type(ax) == "number" and type(ay) == "number" and def ~= nil then
					if def.omni == true then
						local dx = checkX - ax
						local dy = checkY - ay
						if dx * dx + dy * dy <= def.range * def.range then
							return true
						end
					else
						local dx = checkX - ax
						if
							math.abs(checkY - ay) <= Core.ARENA.laneReach
							and dx > 0
							and dx <= def.range
						then
							return true
						end
					end
				end
			end
		end
		return false
	end

	unitLifecycle = {}
	unitDeadDone = {}
	breachedUnits = {}
	unitVisuals = {}
	unitVisible = {}
	for id, track in pairs(tracks) do
		local alive = aliveInFinal[id] == true
		if not (track.firstIdx + 4 > #frames and not alive) then
			local fromPortal = track.firstX >= 8500
			local rawDeathIdx = if track.spawnKilled
				then track.firstIdx
				else math.min(track.lastIdx + 1, #frames)
			local visualDeathIdx = if alive
				then (#frames + 1000)
				elseif fromPortal then math.max(
					rawDeathIdx,
					math.min(track.firstIdx + MIN_ARENA_ENTRY_FRAMES, #frames)
				)
				else rawDeathIdx
			local arenaDeathX = track.lastX
			if not alive and track.lastX > 9050 then
				arenaDeathX = frontKillArenaX(wallTraps, track.lane)
			end
			local killedByTrap = (not alive) and (track.lastX > 650)
			local diedFrozen = track.isFrozen
				or (killedByTrap and hasFrostTrapInRange(arenaDeathX, track.lastY))
			unitLifecycle[id] = {
				id = id,
				kind = track.kind,
				isChampion = track.isChampion,
				isFrozen = diedFrozen,
				lane = track.lane,
				firstIdx = track.firstIdx,
				firstX = track.firstX,
				lastIdx = track.lastIdx,
				lastX = track.lastX,
				lastY = track.lastY,
				fromPortal = fromPortal,
				killedByTrap = killedByTrap,
				visualDeathIdx = visualDeathIdx,
				arenaDeathX = arenaDeathX,
			}
			local unit = HordeKit.create(
				track.kind,
				newScene,
				CFrame.new(portalSpawnOrigin),
				id,
				track.isChampion
			)
			if unit ~= nil then
				HordeKit.setApproachScale(unit, PortalThemes.MIN_SCALE)
				HordeKit.setVisible(unit, false)
				unitVisuals[id] = unit
				unitVisible[id] = false
			end
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
			if synergyKind ~= nil and raidCrowd ~= nil then
				local nowClk = os.clock()
				if (nowClk - lastCrowdComboAt) > 1.2 then
					lastCrowdComboAt = nowClk
					raidCrowd:react("combo")
				end
			end
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
	local ax = math.clamp(arenaX, 0, 10000)
	local x: number
	if ax >= 8000 then
		x = 16.0 + ((ax - 8000) / 2000) * 5.5
	elseif ax >= 5000 then
		x = ((ax - 5000) / 3000) * 16.0
	elseif ax >= 2000 then
		x = -16.0 + ((ax - 2000) / 3000) * 16.0
	else
		x = -22.0 + (ax / 2000) * 6.0
	end
	return RAID_ORIGIN + Vector3.new(x, FLOOR_TOP_Y, z)
end

local function applyDiscreteFrame(frame: any, frameIdx: number): ()
	local activeScene = scene
	if activeScene == nil then
		return
	end
	local activeToken = replayToken
	local pct = frame.wallPct or 0
	local wallDamagedThisFrame = false
	local hitLanesRaw = if type(frame.hitLanes) == "table" and #frame.hitLanes > 0
		then frame.hitLanes :: { number }
		else nil
	local fallbackLane = if type(frame.boss) == "table"
			and type(frame.boss.laneCenter) == "number"
		then frame.boss.laneCenter
		else 3
	if pct < lastWallPct - 0.0005 or hitLanesRaw ~= nil then
		wallDamagedThisFrame = true
		local drop = math.max(0, lastWallPct - pct)
		local sev = math.clamp(drop * 8, 0.75, 2.2)
		local lanes = hitLanesRaw or { fallbackLane }
		local hitSpan = if type(frame.hitSpan) == "number" then frame.hitSpan else nil
		for _, lane in ipairs(lanes) do
			local hitPos = ArenaVisual.pulseWallImpact(activeScene, lane, sev, hitSpan)
			Vfx.wallHit(activeScene, hitPos, lane, sev, pct)
			AudioKit.playAt("wall_hit", hitPos)
		end
		if drop >= 0.04 and raidCrowd ~= nil then
			raidCrowd:react("gasp")
			AudioKit.play("crowd_gasp", 0.55)
		end
		lastWallPct = pct
		shakeUntil = math.max(shakeUntil, time() + 0.14)
	elseif math.abs(pct - lastWallPct) > 0.005 then
		lastWallPct = pct
	end
	local wallStage = ArenaVisual.setWallDamageStage(
		activeScene,
		pct,
		if hitLanesRaw ~= nil then hitLanesRaw[1] else fallbackLane
	)
	if wallStage > lastWallStage then
		if wallStage >= 1 and wallStage <= 3 then
			Vfx.wallStageBreach(activeScene, RAID_ORIGIN, wallStage)
		end
		lastWallStage = wallStage
	end
	AudioKit.setWallPct(pct)
	if pct <= 0 and not fracturedGate then
		fracturedGate = true
		lastWallStage = 4
		shakeUntil = math.max(shakeUntil, time() + 0.36)
		ArenaVisual.setWallDamageStage(activeScene, 0)
		Vfx.collapseWall(activeScene, RAID_ORIGIN)
		AudioKit.playAt("gate_fracture", RAID_ORIGIN + Vector3.new(-24, FLOOR_TOP_Y + 2, 0))
	end
	if topHud.Size.X.Offset < 248 then
		wallLabel.Text = string.format("%d%%", math.floor(pct * 100))
	else
		wallLabel.Text = string.format("%s %d%%", rmsg("wall_prefix"), math.floor(pct * 100))
	end
	wallProgress.set(pct)

	local seen: { [number]: boolean } = {}
	for _, unitData in ipairs(frame.units or {}) do
		local id = unitData.id
		if id ~= nil then
			local life = unitLifecycle[id]
			if life ~= nil or unitVisuals[id] ~= nil then
				seen[id] = true
				unitKind[id] = unitData.kind
				unitFrozen[id] = unitData.isFrozen == true
					or (type(unitData.uSlowUntil) == "number" and unitData.uSlowUntil > 0)
				if unitData.isChampion == true then
					unitIsChampion[id] = true
				end
				local unit = unitVisuals[id]
				if unit == nil then
					unit = HordeKit.create(
						unitData.kind,
						activeScene,
						CFrame.new(RAID_ORIGIN + Vector3.new(PortalThemes.THROAT_X, FLOOR_TOP_Y, 0)),
						id,
						unitData.isChampion == true
					)
					if unit ~= nil then
						unitVisuals[id] = unit
					end
				elseif unitData.isChampion == true and not unit.isChampion then
					HordeKit.setChampion(unit, true)
				end
				if unit ~= nil then
					local pos = unitWorldPos(unitData.lane, unitData.x)
					local vfxPos = if unit.flying
						then pos + Vector3.new(0, VisualTheme.AERIAL.hoverY, 0)
						else pos
					if not unitVisible[id] then
						HordeKit.setApproachScale(unit, 1.0)
						HordeKit.setVisible(unit, true)
						unitVisible[id] = true
						if not breachedUnits[id] then
							breachedUnits[id] = true
							if type(unitData.x) == "number" and unitData.x >= 8500 then
								local mouthPos = triggerPortalBreach(unitData.lane, false)
								AudioKit.playAt(
									"horde_spawn",
									mouthPos + Vector3.new(0, 2, 0),
									0.75
								)
							else
								local resolvedTheme = activePortalTheme
									or PortalThemes.resolve("rift")
								Vfx.portalBreach(
									activeScene,
									pos,
									themeRgb(resolvedTheme.veilColor),
									themeRgb(resolvedTheme.accentColor),
									false
								)
								AudioKit.playAt("horde_spawn", pos + Vector3.new(0, 2, 0), 0.75)
							end
						end
					end
					if unitData.spawnKilled == true then
						if lastUnitPos[id] == nil then
							lastUnitPos[id] = pos
						end
					else
						lastUnitPos[id] = pos
						local prevHp = prevUnitHp[id]
						if prevHp ~= nil and unitData.hp < prevHp then
							if
								type(unitData.x) == "number"
								and unitData.x <= 9200
								and (life == nil or frameIdx < life.visualDeathIdx)
							then
								HordeKit.hitSquash(unit)
								local uy = if type(unitData.y) == "number"
									then unitData.y
									else Core.laneY(unitData.lane)
								fireTrapsForLane(
									activeScene,
									unitData.lane,
									unitData.x,
									uy,
									vfxPos,
									id
								)
							end
						end
						prevUnitHp[id] = unitData.hp
					end
				end
			end
		end
	end
	local function emitUnitDeath(
		id: number,
		unit: any,
		vfxPos: Vector3,
		resolvedKind: string,
		isFrozen: boolean,
		isChamp: boolean
	): ()
		local enemySpec = (VisualTheme.ENEMIES :: any)[resolvedKind]
		local unitColor = if enemySpec ~= nil and type(enemySpec.color) == "table"
			then themeRgb(enemySpec.color)
			else Color3.fromRGB(20, 184, 166)
		Vfx.death(activeScene, vfxPos, unitColor, isFrozen)
		local vz = if id % 2 == 0 then 3.2 else -3.2
		Vfx.ragdollEnemy(
			activeScene,
			vfxPos,
			unitColor,
			Vector3.new(12, 14, vz),
			resolvedKind,
			if unit ~= nil then unit.model else nil,
			isFrozen
		)
		if isChamp then
			Vfx.championDeath(
				activeScene,
				vfxPos,
				themeRgb(VisualTheme.CHAMPION.haloColor),
				themeRgb(VisualTheme.CHAMPION.accentColor)
			)
			shakeUntil = math.max(shakeUntil, time() + 0.14)
		end
		AudioKit.unitDeath(resolvedKind, vfxPos)
		HordeKit.setVisible(unit, false)
		unitVisible[id] = false
	end

	for id, unit in pairs(unitVisuals) do
		local life = unitLifecycle[id]
		if life ~= nil then
			if frameIdx >= life.visualDeathIdx and not unitDeadDone[id] then
				unitDeadDone[id] = true
				local deathAx = math.min(life.arenaDeathX, 9050)
				local deathPos = unitWorldPos(life.lane, deathAx)
				local prevPos = lastUnitPos[id]
				local position: Vector3 = if life.lastX > 9050 or prevPos == nil
					then deathPos
					else prevPos
				lastUnitPos[id] = position
				local vfxPos = if unit.flying
					then position + Vector3.new(0, VisualTheme.AERIAL.hoverY, 0)
					else position
				if life.killedByTrap then
					local uy = life.lastY or Core.laneY(life.lane)
					HordeKit.hitSquash(unit)
					fireTrapsForLane(activeScene, life.lane, deathAx, uy, vfxPos, id)
				end
				local resolvedKind = life.kind or unitKind[id] or "runner"
				local isFrozen = life.isFrozen or (unitFrozen[id] == true)
				local isChamp = life.isChampion
					or (unit.isChampion == true)
					or (unitIsChampion[id] == true)
				emitUnitDeath(id, unit, vfxPos, resolvedKind, isFrozen, isChamp)
			end
		elseif not seen[id] and unitVisible[id] then
			local position = lastUnitPos[id]
				or (unit.base and unit.base.Position)
				or (RAID_ORIGIN + Vector3.new(0, FLOOR_TOP_Y, 0))
			local vfxPos = if unit.flying
				then position + Vector3.new(0, VisualTheme.AERIAL.hoverY, 0)
				else position
			local resolvedKind = unitKind[id] or "runner"
			local isFrozen = unitFrozen[id] == true
			local isChamp = (unit.isChampion == true) or (unitIsChampion[id] == true)
			emitUnitDeath(id, unit, vfxPos, resolvedKind, isFrozen, isChamp)
		end
	end

	local function triggerBossDeathClimax(deathPos: Vector3): ()
		prevBossAlive = false
		local now = time()
		bossDyingUntil = now + 0.85
		bossTimeDilationStartAt = now
		bossTimeDilationUntil = now + 0.30
		bossHiddenAfterDeath = false
		lastBossPos = deathPos
		AudioKit.play("boss_death")
		AudioKit.setBossActive(false)
		shakeUntil = math.max(shakeUntil, now + 0.28)
		if bossVisual ~= nil then
			HordeKit.setBossApproachScale(bossVisual, 1.0)
			HordeKit.setBossBase(bossVisual, CFrame.new(deathPos))
			HordeKit.stepBoss(bossVisual, now, "DYING", false)
			Vfx.bossDeathSequence(
				activeScene,
				bossVisual.bossId,
				deathPos,
				bossVisual.color,
				bossVisual.accent
			)
		else
			Vfx.ring(activeScene, deathPos, UiKit.color(VisualTheme.PALETTE.amberBright))
		end
		if raidCrowd ~= nil then
			raidCrowd:react("cheer")
		end
		campaignUi.hideBossHud()
	end

	local bossApproaching = bossSpawnInfo ~= nil and frameIdx < bossSpawnInfo.firstIdx
	local boss = frame.boss
	if bossVisual ~= nil and type(boss) == "table" then
		local bossLane = math.clamp(math.round(boss.laneCenter or 3), 1, 5)
		local bossPos = unitWorldPos(boss.laneCenter or 3, boss.x or 10000)
		lastBossPos = bossPos
		if boss.alive == true then
			if not breachedBoss then
				breachedBoss = true
				triggerPortalBreach(bossLane, true)
			end
			if not bossSpawned then
				bossSpawned = true
				prevBossAlive = true
				HordeKit.setBossApproachScale(bossVisual, 1.0)
				HordeKit.setBossVisible(bossVisual, true)
				AudioKit.play("boss_intro")
				AudioKit.setBossActive(true)
				local spawnedBossId = bossVisual.bossId
				local activeLocale = UiKit.getLocale()
				local headPos = bossPos + Vector3.new(0, bossVisual.height + 0.8, 0)
				campaignUi.showBossQuote(spawnedBossId, "intro", headPos)
				task.delay(0.30, function()
					if replayToken == activeToken then
						AudioKit.playBossVoice(spawnedBossId, "intro", activeLocale)
					end
				end)
				if raidCrowd ~= nil then
					raidCrowd:react("boss")
				end
			end
			if prevBossHp ~= nil and boss.hp < prevBossHp then
				HordeKit.hitSquashBoss(bossVisual)
				fireTrapsForLane(
					activeScene,
					bossLane,
					boss.x or 5000,
					Core.laneY(bossLane),
					bossPos,
					-1
				)
			end
			prevBossHp = boss.hp
			local bState = tostring(boss.state or "MARCH")
			if bState == "TELEGRAPH" then
				local ticksLeft = tonumber(boss.stateTicksLeft) or 20
				local teleProgress = math.clamp(1 - (ticksLeft / 40), 0, 1)
				Vfx.bossTelegraph(activeScene, bossPos, bossVisual.accent, teleProgress)
			end
			local didSlam = bState == "ABILITY"
				or (boss.didAbility == true and not bossSlammedThisCycle)
			if bState ~= prevBossState then
				prevBossState = bState
				if bState == "TELEGRAPH" then
					bossSlammedThisCycle = false
					AudioKit.play("boss_telegraph")
					if raidCrowd ~= nil then
						raidCrowd:react("gasp")
					end
				elseif bState == "VULNERABLE" then
					bossSlammedThisCycle = false
					AudioKit.play("boss_stagger")
					if raidCrowd ~= nil then
						raidCrowd:react("cheer")
					end
				elseif bState == "ATTACK" then
					bossSlammedThisCycle = false
				end
			end
			if bState == "ATTACK" and wallDamagedThisFrame then
				AudioKit.playAt("boss_slam", bossPos)
				shakeUntil = math.max(shakeUntil, time() + 0.24)
				Vfx.bossSlamImpact(activeScene, bossPos, bossVisual.accent)
			end
			if didSlam and not bossSlammedThisCycle then
				bossSlammedThisCycle = true
				AudioKit.playAt("boss_slam", bossPos)
				shakeUntil = math.max(shakeUntil, time() + 0.28)
				Vfx.bossSlamImpact(activeScene, bossPos, bossVisual.accent)
			elseif bState ~= "ABILITY" and boss.didAbility ~= true and bState ~= "TELEGRAPH" then
				bossSlammedThisCycle = false
			end
			if boss.enraged == true and not prevBossEnraged then
				prevBossEnraged = true
				AudioKit.play("boss_enrage")
				local enragedBossId = bossVisual.bossId
				local activeLocale = UiKit.getLocale()
				local headPos = bossPos + Vector3.new(0, bossVisual.height + 0.8, 0)
				campaignUi.showBossQuote(enragedBossId, "enrage", headPos)
				task.delay(0.22, function()
					if replayToken == activeToken then
						AudioKit.playBossVoice(enragedBossId, "enrage", activeLocale)
					end
				end)
			end
			campaignUi.updateBossHud(boss)
		elseif prevBossAlive and not bossApproaching then
			triggerBossDeathClimax(bossPos)
		end
	elseif prevBossAlive and not bossApproaching then
		triggerBossDeathClimax(lastBossPos or (RAID_ORIGIN + Vector3.new(0, FLOOR_TOP_Y, 0)))
	end
end

local function stepVisualFrame(
	frames: { any },
	fPos: number,
	idx: number,
	nextIdx: number,
	alpha: number
): ()
	local activeScene = scene
	if activeScene == nil then
		return
	end
	local now = time()
	local cam = Workspace.CurrentCamera
	if cam ~= nil then
		local baseCf, baseFov = getRaidCamera()
		local impulseCf, fovDelta = Vfx.sampleCameraImpulse(now)
		cam.FieldOfView = baseFov + fovDelta
		if now < shakeUntil then
			local jx = (math.random() - 0.5) * 0.34
			local jy = (math.random() - 0.5) * 0.22
			cam.CFrame = baseCf * impulseCf * CFrame.new(jx, jy, 0)
		else
			cam.CFrame = baseCf * impulseCf
		end
	end

	local leadIn = PortalThemes.LEAD_IN_FRAMES
	for id, life in pairs(unitLifecycle) do
		if life.fromPortal then
			local startPos = life.firstIdx - leadIn
			if fPos >= startPos and fPos < life.firstIdx then
				local unit = unitVisuals[id]
				if unit ~= nil then
					local t = math.clamp((fPos - startPos) / leadIn, 0, 1)
					if not breachedUnits[id] then
						breachedUnits[id] = true
						unitKind[id] = life.kind
						local mouthPos = triggerPortalBreach(life.lane, false)
						AudioKit.playAt("horde_spawn", mouthPos + Vector3.new(0, 2, 0), 0.75)
					end
					if not unitVisible[id] then
						HordeKit.setVisible(unit, true)
						unitVisible[id] = true
					end
					local fx, fz, yaw = PortalThemes.sampleFanPath(life.lane, t)
					local worldPos = RAID_ORIGIN + Vector3.new(fx, FLOOR_TOP_Y, fz)
					lastUnitPos[id] = worldPos
					HordeKit.setApproachScale(unit, PortalThemes.approachScale(t))
					HordeKit.setBase(unit, CFrame.new(worldPos) * CFrame.Angles(0, yaw, 0))
					HordeKit.step(unit, now, true)
				end
			end
		end
	end

	local frameA = frames[idx]
	local frameB = frames[nextIdx]
	if fPos >= 1 and frameA ~= nil then
		local curById: { [number]: any } = {}
		for _, unitData in ipairs(frameA.units or {}) do
			if unitData.id ~= nil then
				curById[unitData.id] = unitData
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
		for id, life in pairs(unitLifecycle) do
			local unit = unitVisuals[id]
			if
				unit ~= nil
				and unitVisible[id]
				and not unitDeadDone[id]
				and fPos >= life.firstIdx
				and fPos < life.visualDeathIdx
			then
				local curData = curById[id]
				local nextData = nextById[id]
				local xVal: number
				if
					curData ~= nil
					and curData.spawnKilled ~= true
					and nextData ~= nil
					and nextData.spawnKilled ~= true
				then
					xVal = curData.x + (nextData.x - curData.x) * alpha
				elseif
					fPos >= life.lastIdx
					and life.visualDeathIdx > life.lastIdx
					and life.visualDeathIdx <= #frames
				then
					local span = math.max(1, life.visualDeathIdx - life.lastIdx)
					local frac = math.clamp((fPos - life.lastIdx) / span, 0, 1)
					xVal = life.lastX + (life.arenaDeathX - life.lastX) * frac
				elseif curData ~= nil then
					xVal = curData.x
				else
					xVal = life.lastX
				end
				local pos = unitWorldPos(life.lane, xVal)
				lastUnitPos[id] = pos
				HordeKit.setApproachScale(unit, 1.0)
				HordeKit.setBase(unit, CFrame.new(pos))
				HordeKit.step(unit, now, true)
			end
		end
	end

	if bossVisual ~= nil then
		local approachingBoss = false
		if bossSpawnInfo ~= nil then
			local bossStart = bossSpawnInfo.firstIdx - leadIn
			if fPos >= bossStart and fPos < bossSpawnInfo.firstIdx then
				approachingBoss = true
				local t = math.clamp((fPos - bossStart) / leadIn, 0, 1)
				local fx, fz, yaw = PortalThemes.sampleFanPath(bossSpawnInfo.laneCenter, t)
				local pos = RAID_ORIGIN + Vector3.new(fx, FLOOR_TOP_Y, fz)
				if not breachedBoss then
					breachedBoss = true
					triggerPortalBreach(bossSpawnInfo.laneCenter, true)
				end
				if not bossSpawned then
					bossSpawned = true
					prevBossAlive = true
					HordeKit.setBossVisible(bossVisual, true)
					AudioKit.play("boss_intro")
					AudioKit.setBossActive(true)
					local spawnedBossId = bossVisual.bossId
					local activeLocale = UiKit.getLocale()
					local activeToken = replayToken
					local headPos = pos + Vector3.new(0, bossVisual.height + 0.8, 0)
					campaignUi.showBossQuote(spawnedBossId, "intro", headPos)
					local firstBossFrame = frames[bossSpawnInfo.firstIdx]
					if firstBossFrame ~= nil and type(firstBossFrame.boss) == "table" then
						campaignUi.updateBossHud(firstBossFrame.boss)
					end
					task.delay(0.30, function()
						if replayToken == activeToken then
							AudioKit.playBossVoice(spawnedBossId, "intro", activeLocale)
						end
					end)
					if raidCrowd ~= nil then
						raidCrowd:react("boss")
					end
				end
				lastBossPos = pos
				HordeKit.setBossApproachScale(bossVisual, PortalThemes.approachScale(t))
				HordeKit.setBossBase(bossVisual, CFrame.new(pos) * CFrame.Angles(0, yaw, 0))
				HordeKit.stepBoss(bossVisual, now, "MARCH", false)
				campaignUi.stepBossBubble(cam, pos + Vector3.new(0, bossVisual.height + 0.8, 0))
			end
		end
		if bossDyingUntil > 0 then
			local deathPos = lastBossPos or (RAID_ORIGIN + Vector3.new(0, FLOOR_TOP_Y, 0))
			if now < bossDyingUntil then
				HordeKit.setBossApproachScale(bossVisual, 1.0)
				HordeKit.setBossBase(bossVisual, CFrame.new(deathPos))
				HordeKit.stepBoss(bossVisual, now, "DYING", false)
			elseif not bossHiddenAfterDeath then
				bossHiddenAfterDeath = true
				HordeKit.setBossVisible(bossVisual, false)
			end
		elseif
			not approachingBoss
			and fPos >= 1
			and frameA ~= nil
			and type(frameA.boss) == "table"
			and frameA.boss.alive == true
		then
			local bA = frameA.boss
			local bB = if frameB ~= nil
					and frameB ~= frameA
					and type(frameB.boss) == "table"
				then frameB.boss
				else nil
			local xVal = bA.x or 10000
			if bB ~= nil and type(bB.x) == "number" then
				xVal = xVal + (bB.x - xVal) * alpha
			end
			local pos = unitWorldPos(bA.laneCenter or 3, xVal)
			lastBossPos = pos
			HordeKit.setBossApproachScale(bossVisual, 1.0)
			HordeKit.setBossBase(bossVisual, CFrame.new(pos))
			HordeKit.stepBoss(bossVisual, now, bA.state, bA.enraged == true)
			campaignUi.stepBossBubble(cam, pos + Vector3.new(0, bossVisual.height + 0.8, 0))
		end
	end
end

local function clearResultBadges(): ()
	champBetPill.Visible = false
	shardBadge.Visible = false
	coreBadge.Visible = false
	dropBadgesRow.Visible = false
	postMatchUi.clear()
end

local function applyResultBadges(result: any, loc: string): ()
	clearResultBadges()
	local champOutcome = result.championOutcome
	local hasChamp = false
	if champOutcome == "survived" then
		hasChamp = true
		champBetPill.Text = I18n.t(loc, "deck_champ_survived")
		champBetPill.TextColor3 = UiKit.color(VisualTheme.PALETTE.amberBright)
		UiKit.stroke(champBetPill, UiKit.color(VisualTheme.PALETTE.amberBright), 1.5, 0.1)
		champBetPill.Visible = true
	elseif champOutcome == "hunted" then
		hasChamp = true
		champBetPill.Text = I18n.t(loc, "deck_champ_hunted")
		champBetPill.TextColor3 = UiKit.color(VisualTheme.PALETTE.danger)
		UiKit.stroke(champBetPill, UiKit.color(VisualTheme.PALETTE.danger), 1.5, 0.15)
		champBetPill.Visible = true
	end

	local shardCount = math.max(0, math.floor(tonumber(result.shardEarned) or 0))
	if shardCount > 0 then
		shardBadge.Text = I18n.t(loc, "deck_reward_shard", shardCount)
		shardBadge.TextColor3 = UiKit.color(VisualTheme.PALETTE.teal)
		shardBadge.Visible = true
	end

	local coreCount = if type(result.coreDropped) == "number"
		then math.max(0, math.floor(result.coreDropped))
		elseif
			result.coreDropped == true
			or (type(result.coreDropped) == "string" and result.coreDropped ~= "")
		then 1
		else 0
	if coreCount > 0 then
		coreBadge.Text = I18n.t(loc, "deck_reward_core", coreCount)
		coreBadge.TextColor3 = UiKit.color(VisualTheme.PALETTE.amberBright)
		coreBadge.Visible = true
	end

	if shardCount > 0 or coreCount > 0 then
		dropBadgesRow.Position = UDim2.fromOffset(14, if hasChamp then 82 else 65)
		dropBadgesRow.Visible = true
	end
end

local function showError(message: string): ()
	TransitionKit.fadeOut(0.18)
	status.Text = rmsg("failed")
	resultTitle.Text = rmsg("failed")
	resultTitle.TextColor3 = UiKit.color(VisualTheme.PALETTE.danger)
	resultCoin.Visible = false
	details.Text = message
	hashLabel.Text = ""
	clearResultBadges()
	replayButton.Visible = false
	combatCamButton.Visible = false
	speedButton.Visible = false
	closeButton.Visible = false
	resultCard.Visible = true
	setBusy(false)
end

local function startReplay(result: any, isQuickReplay: boolean?): ()
	clearScene()
	hasActiveBossStage = result.bossId ~= nil
	applyRaidLayout()
	local myToken = replayToken
	wallLabel.Visible = true
	wallProgress.frame.Visible = true
	replayProgress.frame.Visible = true
	resultCard.Visible = false
	clearResultBadges()
	combatCamButton.Text = UiKit.cameraButtonLabel(nil, true)
	combatCamButton.Visible = true
	speedButton.Visible = true
	closeButton.Visible = true
	replayButton.Visible = false
	wallProgress.set(1)
	replayProgress.set(0)
	lastWallPct = 1
	lastWallStage = 0

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
		clearResultBadges()
		replayButton.Visible = false
		combatCamButton.Visible = false
		speedButton.Visible = false
		closeButton.Visible = false
		resultCard.Visible = true
		TransitionKit.fadeOut(0.18)
		setBusy(false)
		return
	end

	local sceneOk, sceneErr = pcall(buildScene :: any, result, frames)
	if not sceneOk then
		showError("3D: " .. tostring(sceneErr))
		return
	end
	local isCampaign = result.mode == "campaign"
	local isDefend = result.mode == "defend"
	local headerPrefix = if isCampaign
		then I18n.t(UiKit.getLocale(), "cta_story")
		elseif isDefend then rmsg("defend_title")
		else "RAID"
	title.Text = headerPrefix .. " · " .. tostring(result.phantomName or "?")
	status.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
	if isQuickReplay == true then
		status.Text = rmsg("replay_live")
	elseif isDefend or isCampaign then
		status.Text = rmsg("defending")
	else
		status.Text = rmsg("attacking")
	end
	local liveFmt = string.format(rmsg("live_info"), speedMult)
	details.Text = (string.gsub(liveFmt, "70", tostring(tonumber(result.waveCount) or 70)))

	if topHud.Size.X.Offset < 248 then
		wallLabel.Text = "100%"
	else
		wallLabel.Text = string.format("%s 100%%", rmsg("wall_prefix"))
	end
	if isQuickReplay ~= true then
		TransitionKit.revealMatchupAndWait(
			result.matchup,
			if type(result.mode) == "string" then result.mode else "raid",
			2.8
		)
		TransitionKit.fadeOut(0.26)
	end
	AudioKit.play("horn")
	local baseSeconds = if isQuickReplay == true
		then 20
		else math.max(3, (tonumber(result.ticks) or Core.MAX_TICKS) / Core.TICK_HZ)
	local leadInFrames = PortalThemes.LEAD_IN_FRAMES
	local frameSteps = math.max(1, #frames - 1)
	local leadInSeconds = if #frames > 1
		then baseSeconds * (leadInFrames / frameSteps)
		else PortalThemes.APPROACH_SECONDS
	local totalSeconds = leadInSeconds + baseSeconds
	local totalSpan = leadInFrames + (#frames - 1)
	local started = time()
	local lastTick = started
	local simElapsed = 0
	local lastDiscreteIndex = 0
	task.spawn(function()
		local animationOk, animationErr = pcall(function()
			while replayToken == myToken do
				local now = time()
				local dt = math.min(now - lastTick, 0.1)
				lastTick = now
				local dilation = 1.0
				if bossTimeDilationUntil > now then
					local dilAlpha = math.clamp((now - bossTimeDilationStartAt) / 0.30, 0, 1)
					local smooth = dilAlpha * dilAlpha * (3 - 2 * dilAlpha)
					dilation = 0.32 + (1.0 - 0.32) * smooth
				end
				local playbackDt = dt * speedMult * dilation
				simElapsed += playbackDt
				local progress = math.clamp(simElapsed / totalSeconds, 0, 1)
				local fPos = (1 - leadInFrames) + progress * totalSpan
				local index = math.clamp(math.floor(math.max(1, fPos)), 1, #frames)
				local nextIndex = math.min(index + 1, #frames)
				local alpha = math.clamp(fPos - index, 0, 1)
				if fPos >= 1 and index > lastDiscreteIndex then
					for stepIdx = lastDiscreteIndex + 1, index do
						applyDiscreteFrame(frames[stepIdx], stepIdx)
					end
					lastDiscreteIndex = index
				end
				stepVisualFrame(frames, fPos, index, nextIndex, alpha)
				TrapKit.step(playbackDt)
				replayProgress.set(progress)
				if progress >= 1 and (bossDyingUntil <= 0 or time() >= bossDyingUntil) then
					break
				end
				RunService.Heartbeat:Wait()
			end
			if bossVisual ~= nil and bossDyingUntil > 0 and not bossHiddenAfterDeath then
				bossHiddenAfterDeath = true
				HordeKit.setBossVisible(bossVisual, false)
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
			if type(result.campaign) == "table" then
				campaignUi.ingestCampaignSnapshot(result.campaign)
			end
			if isQuickReplay == true then
				local wallSec = math.max(1, math.floor(time() - started + 0.5))
				status.Text = I18n.t(loc, "replay_banner", wallSec, outcomeText)
			else
				status.Text = outcomeText
			end
			local starsEarned = if result.mode == "campaign"
				then (tonumber(result.starsEarned) or 0)
				else 0
			if result.mode == "campaign" and playerWon and starsEarned > 0 then
				local s = math.clamp(starsEarned, 1, 3)
				resultTitle.Text = outcomeText
					.. "  "
					.. string.rep("★", s)
					.. string.rep("☆", 3 - s)
			else
				resultTitle.Text = outcomeText
			end
			resultTitle.TextColor3 = outcomeColor
			resultCoin.Visible = true
			details.Text = string.format(
				"HP %s · +%s",
				tostring(result.wallHp),
				I18n.t(loc, "hud_gold", tonumber(result.rewardGold) or 0)
			)
			hashLabel.Text = tostring(result.resultHash)
			applyResultBadges(result, loc)
			postMatchUi.render(result.report, loc)
			postMatchUi.setRevengeTarget(
				if result.canRevenge == true and type(result.revengeBattleId) == "string"
					then result.revengeBattleId
					else nil
			)
			replayButton.Visible = true
			resultCard.Visible = true
			combatCamButton.Visible = false
			speedButton.Visible = false
			closeButton.Visible = false
			AudioKit.play(playerWon and "victory" or "defeat", 0.85)
			if raidCrowd ~= nil then
				raidCrowd:react(if playerWon then "victory" else "defeat")
			end
			if playerWon then
				AudioKit.play("crowd_victory", 0.75)
			end
			if result.mode == "campaign" and playerWon and starsEarned > 0 then
				AudioKit.play("campaign_star")
				if result.bossId ~= nil then
					AudioKit.play("campaign_act_clear")
				end
			end
		else
			status.Text = rmsg("replay_failed")
			resultTitle.Text = rmsg("replay_failed")
			resultTitle.TextColor3 = UiKit.color(VisualTheme.PALETTE.danger)
			details.Text = tostring(animationErr)
			hashLabel.Text = ""
			clearResultBadges()
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
	campaignUi.closeModal()
	battleLogUi.closeModal()
	topHud.Visible = true
	combatCamButton.Text = UiKit.cameraButtonLabel(nil, true)
	combatCamButton.Visible = true
	speedButton.Visible = true
	closeButton.Visible = true
	resultCard.Visible = false
	defendButton.Visible = false
	attackButton.Visible = false
	campaignUi.setButtonsVisible(false)
	battleLogUi.setButtonsVisible(false)
	focusRaidCamera()
end

local function hideModal(): ()
	TransitionKit.quickCurtain(function()
		clearScene()
		topHud.Visible = false
		campaignUi.hideBossHud()
		combatCamButton.Visible = false
		speedButton.Visible = false
		closeButton.Visible = false
		resultCard.Visible = false
		replayButton.Visible = false
		status.Text = rmsg("ready")
		details.Text = ""
		hashLabel.Text = ""
		clearResultBadges()
		if activeBattleId ~= nil then
			raidEvent:FireServer("close", { battleId = activeBattleId })
			activeBattleId = nil
		end
		AudioKit.setBossActive(false)
		AudioKit.setMode("build")
		AudioKit.setWallPct(1)
		player:SetAttribute("MuralhaInRaid", false)
		setBusy(false)
	end, 0.18)
end

playLogReplay = function(entry: any): ()
	if busy then
		return
	end
	if type(entry) ~= "table" or type(entry.replayWall) ~= "table" then
		return
	end
	setBusy(true)
	AudioKit.play("ui_click")
	showModal()
	local loc = UiKit.getLocale()
	title.Text = I18n.t(loc, "ui_log_title")
	status.Text = rmsg("replay_live")
	status.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
	details.Text = ""
	hashLabel.Text = ""
	clearResultBadges()
	AudioKit.setMode("raid")
	AudioKit.setWallPct(1)

	local winner = tostring(entry.winner or "defender")
	local role = tostring(entry.role or "attack")
	local synthetic = {
		ok = true,
		battleId = entry.battleId,
		mode = if role == "defense" then "defend" else role,
		phantomName = entry.rivalLabel,
		canRevenge = entry.canRevenge == true,
		revengeBattleId = if entry.canRevenge == true and type(entry.battleId) == "string"
			then entry.battleId
			else nil,
		seed = entry.seed,
		simVersion = Core.SIM_VERSION,
		wall = entry.replayWall,
		waveSpec = entry.waveSpec,
		resultHash = entry.resultHash,
		winner = winner,
		playerWon = if role == "defense" then winner == "defender" else winner == "attacker",
		rewardGold = math.max(0, tonumber(entry.goldDelta) or 0),
		wallHp = if winner == "defender" then 100 else 0,
	}
	lastResult = synthetic
	startReplay(synthetic, true)
end

startBattle = function(mode: string, extraOpts: { [string]: any }?): ()
	if busy then
		return
	end
	setBusy(true)
	AudioKit.play("ui_click")
	TransitionKit.beginBattleTransition(
		mode,
		if type(player.DisplayName) == "string" and player.DisplayName ~= ""
			then player.DisplayName
			else player.Name,
		extraOpts
	)
	showModal()
	local isDefend = mode == "defend"
	local isCampaign = mode == "campaign"
	local isRevenge = mode == "revenge"
	title.Text = if isCampaign
		then I18n.t(UiKit.getLocale(), "cta_story")
		elseif isRevenge then I18n.t(UiKit.getLocale(), "ui_log_rev")
		elseif isDefend then rmsg("defend_title")
		else "RAID"
	status.Text = if isDefend or isCampaign then rmsg("defending") else rmsg("attacking")
	status.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
	details.Text = ""
	hashLabel.Text = ""
	clearResultBadges()
	replayButton.Visible = false
	resultCard.Visible = false
	clearResultBadges()
	combatCamButton.Text = UiKit.cameraButtonLabel(nil, true)
	combatCamButton.Visible = true
	speedButton.Visible = true
	closeButton.Visible = true
	clearScene()
	AudioKit.play("ui_click")
	AudioKit.setMode("raid")
	AudioKit.setWallPct(1)

	local payload: { [string]: any } = { mode = mode }
	if type(extraOpts) == "table" then
		for k, v in pairs(extraOpts) do
			payload[k] = v
		end
	end

	local ok, result = pcall(function()
		return raidStart:InvokeServer(payload)
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

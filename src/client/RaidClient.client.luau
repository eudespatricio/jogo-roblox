--!nonstrict
-- S8: raid com replay 3D em diorama. O servidor devolve seed + wall fantasma; o cliente roda o
-- MESMO Battle, confere o hash e anima 8 s no ViewportFrame. O visual e cosmetico; a decisao
-- de recompensa continua no servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("MuralhaRemotes")
local raidStart = remotes:WaitForChild("RaidStart") :: RemoteFunction
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Core = require(Shared:WaitForChild("sim"):WaitForChild("core"))
local GridLayout = require(Shared:WaitForChild("build"):WaitForChild("GridLayout"))
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
gui.IgnoreGuiInset = false
gui.DisplayOrder = 15
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = gui

local attackButton = UiKit.button(root, "Attack", "ATACAR")
attackButton.AnchorPoint = Vector2.new(1, 0)
attackButton.Position = UDim2.new(1, -10, 0.16, 0)
attackButton.Size = UDim2.fromOffset(96, 34)
attackButton.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.tealDark)
attackButton.TextColor3 = UiKit.color(VisualTheme.PALETTE.white)
UiKit.stroke(attackButton, UiKit.color(VisualTheme.PALETTE.teal), 2, 0)

local modal = UiKit.panel(root, "Modal")
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromScale(0.86, 0.7)
modal.Visible = false

local modalConstraint = Instance.new("UISizeConstraint")
modalConstraint.MinSize = Vector2.new(280, 420)
modalConstraint.MaxSize = Vector2.new(440, 640)
modalConstraint.Parent = modal

local title = UiKit.label(
	modal,
	"Title",
	"RAID",
	UiKit.color(VisualTheme.PALETTE.amberBright),
	Enum.Font.GothamBlack
)
title.Position = UDim2.fromOffset(14, 8)
title.Size = UDim2.new(1, -28, 0, 30)
title.TextScaled = true

local status = UiKit.label(
	modal,
	"Status",
	"ATACANDO...",
	UiKit.color(VisualTheme.PALETTE.parchment),
	Enum.Font.GothamBold
)
status.Position = UDim2.fromOffset(14, 40)
status.Size = UDim2.new(1, -28, 0, 22)
status.TextScaled = true

local details =
	UiKit.label(modal, "Details", "", UiKit.color(VisualTheme.PALETTE.stone), Enum.Font.Code)
details.Position = UDim2.fromOffset(14, 64)
details.Size = UDim2.new(1, -28, 0, 64)
details.TextYAlignment = Enum.TextYAlignment.Top
details.TextWrapped = true
details.TextScaled = false
details.TextSize = 11

local viewport = Instance.new("ViewportFrame")
viewport.Name = "Replay"
viewport.Position = UDim2.new(0.05, 0, 0.27, 0)
viewport.Size = UDim2.new(0.9, 0, 0.38, 0)
viewport.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ironDark)
viewport.BorderSizePixel = 0
viewport.Ambient = Color3.fromRGB(120, 120, 120)
viewport.LightColor = Color3.fromRGB(255, 240, 210)
viewport.LightDirection = Vector3.new(-1, -1, -0.5)
viewport.Visible = false
viewport.Parent = modal
UiKit.corner(viewport, 8)
UiKit.stroke(viewport, UiKit.color(VisualTheme.PALETTE.iron), 1, 0.15)

local wallLabel = UiKit.label(
	modal,
	"WallLabel",
	"MURALHA 100%",
	UiKit.color(VisualTheme.PALETTE.parchment),
	Enum.Font.GothamBold
)
wallLabel.Position = UDim2.new(0.06, 0, 0.66, 0)
wallLabel.Size = UDim2.new(0.88, 0, 0, 18)
wallLabel.Visible = false
wallLabel.TextScaled = true

local wallProgress = UiKit.progress(modal, "WallProgress", UiKit.color(VisualTheme.PALETTE.amber))
wallProgress.frame.Position = UDim2.new(0, 14, 0.71, 0)
wallProgress.frame.Size = UDim2.new(1, -28, 0, 14)
wallProgress.frame.Visible = false

local replayProgress =
	UiKit.progress(modal, "ReplayProgress", UiKit.color(VisualTheme.PALETTE.teal))
replayProgress.frame.Position = UDim2.new(0, 14, 0.78, 0)
replayProgress.frame.Size = UDim2.new(1, -28, 0, 8)
replayProgress.frame.Visible = false

local closeButton = UiKit.button(modal, "Close", "FECHAR")
closeButton.AnchorPoint = Vector2.new(0.5, 1)
closeButton.Position = UDim2.new(0.5, 0, 0.88, 0)
closeButton.Size = UDim2.new(0.5, 0, 0, 36)

local busy = false
local scene: Folder? = nil
local units: { any } = {}
local unitVisible: { boolean } = {}
local lastWallPct = 1

local function setBusy(value: boolean): ()
	busy = value
	attackButton.Visible = not value
end

local function clearScene(): ()
	if scene ~= nil then
		scene:Destroy()
		scene = nil
	end
	viewport.CurrentCamera = nil
	viewport.Visible = false
	wallLabel.Visible = false
	wallProgress.frame.Visible = false
	replayProgress.frame.Visible = false
	units = {}
	unitVisible = {}
end

-- Roda o MESMO Battle do servidor e captura quadros. O hash final tem que bater.
local function buildFrames(result: any): (any, any)
	local battle = Core.Battle.new({
		seed = result.seed,
		simVersion = result.simVersion,
		wall = result.wall,
		wave = { count = result.waveCount or 70 },
	})
	local frames = {}
	local function snapshot()
		local unitsFrame = {}
		for index = 1, battle.uCount do
			if battle.uHp[index] > 0 then
				unitsFrame[#unitsFrame + 1] = {
					lane = battle.uLane[index],
					x = battle.uX[index],
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
		if battle.tick % 10 == 0 or battle:Finished() then
			snapshot()
		end
	end
	return frames, battle:Result()
end

local function buildScene(result: any): ()
	scene = Instance.new("Folder")
	scene.Name = "ReplayScene"
	scene.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = 60
	camera.CFrame = CFrame.lookAt(Vector3.new(28, 20, 38), Vector3.new(0, 2, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	ArenaVisual.build(scene, Vector3.new(0, 0, 0), { dropIn = false })

	local cells = {}
	for _, trap in ipairs(result.wall.traps or {}) do
		if trap.cell ~= nil then
			cells[trap.cell] = { trap = trap.type, level = trap.level }
		end
	end
	TrapKit.sync(scene, cells, Vector3.new(0, 0, 0))

	units = {}
	unitVisible = {}
	for index = 1, 70 do
		local kind = (index % 7 == 0 and "brute") or (index % 3 == 0 and "swarm") or "runner"
		local unit = HordeKit.create(kind, scene, CFrame.new(24, 0.9, 0))
		if unit ~= nil then
			HordeKit.setVisible(unit, false)
			units[index] = unit
			unitVisible[index] = false
		end
	end
end

local function updateFrame(frame: any): ()
	local pct = frame.wallPct or 0
	if math.abs(pct - lastWallPct) > 0.005 then
		lastWallPct = pct
		Vfx.dust(scene, Vector3.new(-22, 1, 0), 4)
	end
	wallLabel.Text = string.format("MURALHA %d%%", math.floor(pct * 100))
	wallProgress.set(pct)
	local seen = {}
	for index, unitData in ipairs(frame.units or {}) do
		seen[index] = true
		local unit = units[index]
		if unit ~= nil then
			if not unitVisible[index] then
				HordeKit.setVisible(unit, true)
				unitVisible[index] = true
			end
			local z = -16 + (unitData.lane - 1) * 8
			local x = -22 + (unitData.x / 10000) * 47
			HordeKit.setBase(unit, CFrame.new(x, 0.9, z))
			HordeKit.step(unit, time(), true)
		end
	end
	for index, unit in pairs(units) do
		if not seen[index] and unitVisible[index] then
			local position = unit.base and unit.base.Position or Vector3.new(0, 0, 0)
			Vfx.death(scene, position, Color3.fromRGB(20, 184, 166))
			HordeKit.setVisible(unit, false)
			unitVisible[index] = false
		end
	end
end

local function showError(message: string): ()
	status.Text = "RAID FALHOU"
	details.Text = message
	closeButton.Visible = true
	setBusy(false)
end

local function startReplay(result: any): ()
	clearScene()
	viewport.Visible = true
	wallLabel.Visible = true
	wallProgress.frame.Visible = true
	replayProgress.frame.Visible = true
	closeButton.Visible = false
	wallProgress.set(1)
	replayProgress.set(0)
	lastWallPct = 1

	local ok, frames, final = pcall(buildFrames, result)
	if not ok or type(frames) ~= "table" or type(final) ~= "table" then
		showError("Replay local indisponivel: " .. tostring(frames))
		return
	end
	if final.hash ~= result.resultHash then
		status.Text = "DIVERGENCIA"
		details.Text = string.format(
			"Hash esperado %s\nHash local %s\nA batalha nao sera exibida.",
			tostring(result.resultHash),
			tostring(final.hash)
		)
		closeButton.Visible = true
		setBusy(false)
		return
	end

	local sceneOk, sceneErr = pcall(buildScene, result)
	if not sceneOk then
		showError("Replay 3D indisponivel: " .. tostring(sceneErr))
		return
	end
	pcall(updateFrame, frames[1])
	local seconds = tonumber(result.replaySeconds) or 8
	local started = time()
	task.spawn(function()
		local animationOk, animationErr = pcall(function()
			while true do
				local progress = math.clamp((time() - started) / seconds, 0, 1)
				local index = math.clamp(math.floor(progress * (#frames - 1)) + 1, 1, #frames)
				updateFrame(frames[index])
				replayProgress.set(progress)
				if progress >= 1 then
					break
				end
				RunService.Heartbeat:Wait()
			end
		end)
		if animationOk then
			status.Text = "REPLAY CONCLUIDO · " .. tostring(seconds) .. "s"
			AudioKit.play(result.winner == "attacker" and "victory" or "defeat", 0.6)
		else
			status.Text = "REPLAY FALHOU"
			details.Text = "Erro na animacao: " .. tostring(animationErr)
		end
		closeButton.Visible = true
		setBusy(false)
	end)
end

local function showModal(): ()
	modal.Visible = true
end

local function hideModal(): ()
	clearScene()
	modal.Visible = false
	status.Text = "PRONTO"
	details.Text = ""
	setBusy(false)
end

attackButton.MouseButton1Click:Connect(function()
	if busy then
		return
	end
	setBusy(true)
	showModal()
	status.Text = "ATACANDO..."
	status.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
	details.Text = ""
	closeButton.Visible = false
	clearScene()
	AudioKit.play("ui_click")

	local ok, result = pcall(function()
		return raidStart:InvokeServer()
	end)
	if not ok or type(result) ~= "table" or result.ok ~= true then
		local reason = "servidor indisponivel"
		if ok and type(result) == "table" then
			reason = tostring(result.err)
		end
		showError("Falha ao iniciar: " .. reason)
		return
	end

	if result.winner == "attacker" then
		status.Text = "VITORIA"
		status.TextColor3 = UiKit.color(VisualTheme.PALETTE.amberBright)
		AudioKit.play("victory")
	else
		status.Text = "DERROTA"
		status.TextColor3 = UiKit.color(VisualTheme.PALETTE.danger)
		AudioKit.play("defeat")
	end
	details.Text = string.format(
		"fantasma %s\n%s\nhash %s\nHP %s · vazados %s · +%s ouro",
		tostring(result.phantomName or "?"),
		tostring(result.battleId),
		tostring(result.resultHash),
		tostring(result.wallHp),
		tostring(result.leaked),
		tostring(result.rewardGold)
	)
	startReplay(result)
end)

closeButton.MouseButton1Click:Connect(hideModal)

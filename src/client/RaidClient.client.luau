--!nonstrict
-- S6: raid com replay visual 3D. O servidor devolve seed + wall fantasma; o cliente roda o
-- MESMO Battle deterministicamente, confere o hash e reproduz 8 s em um ViewportFrame.
-- Nao altera a camera do build: o replay mora dentro do modal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("MuralhaRemotes")
local raidStart = remotes:WaitForChild("RaidStart") :: RemoteFunction
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Core = require(Shared:WaitForChild("sim"):WaitForChild("core"))

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

local function corner(parent: Instance, radius: number): ()
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local attackButton = Instance.new("TextButton")
attackButton.Name = "Attack"
attackButton.Position = UDim2.fromOffset(12, 86)
attackButton.Size = UDim2.fromOffset(104, 36)
attackButton.BackgroundColor3 = Color3.fromRGB(90, 70, 130)
attackButton.BorderSizePixel = 0
attackButton.Text = "ATACAR"
attackButton.TextColor3 = Color3.fromRGB(245, 245, 255)
attackButton.TextScaled = true
attackButton.Font = Enum.Font.GothamBold
attackButton.Parent = root
corner(attackButton, 8)

local modal = Instance.new("Frame")
modal.Name = "Modal"
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromScale(0.8, 0.68)
modal.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
modal.BackgroundTransparency = 0.06
modal.BorderSizePixel = 0
modal.Visible = false
modal.Parent = root
corner(modal, 12)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 30)
title.BackgroundTransparency = 1
title.Text = "RAID"
title.TextColor3 = Color3.fromRGB(230, 220, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title.Parent = modal

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Position = UDim2.fromOffset(12, 42)
status.Size = UDim2.new(1, -24, 0, 24)
status.BackgroundTransparency = 1
status.Text = "ATACANDO..."
status.TextColor3 = Color3.fromRGB(200, 210, 235)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextScaled = true
status.Font = Enum.Font.Gotham
status.Parent = modal

local details = Instance.new("TextLabel")
details.Name = "Details"
details.Position = UDim2.fromOffset(12, 68)
details.Size = UDim2.new(1, -24, 0, 80)
details.BackgroundTransparency = 1
details.Text = ""
details.TextColor3 = Color3.fromRGB(220, 235, 220)
details.TextXAlignment = Enum.TextXAlignment.Left
details.TextYAlignment = Enum.TextYAlignment.Top
details.TextWrapped = true
details.TextSize = 11
details.Font = Enum.Font.Code
details.Parent = modal

local viewport = Instance.new("ViewportFrame")
viewport.Name = "Replay"
viewport.Position = UDim2.new(0.05, 0, 0.30, 0)
viewport.Size = UDim2.new(0.9, 0, 0.31, 0)
viewport.BackgroundColor3 = Color3.fromRGB(20, 28, 24)
viewport.BorderSizePixel = 0
viewport.Ambient = Color3.fromRGB(120, 120, 120)
viewport.LightColor = Color3.fromRGB(255, 245, 220)
viewport.LightDirection = Vector3.new(-1, -1, -0.5)
viewport.Visible = false
viewport.Parent = modal
corner(viewport, 8)

local wallLabel = Instance.new("TextLabel")
wallLabel.Name = "WallLabel"
wallLabel.Position = UDim2.new(0.06, 0, 0.305, 0)
wallLabel.Size = UDim2.new(0.88, 0, 0, 18)
wallLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
wallLabel.BackgroundTransparency = 0.35
wallLabel.BorderSizePixel = 0
wallLabel.Text = "MURALHA 100%"
wallLabel.TextColor3 = Color3.fromRGB(220, 240, 220)
wallLabel.TextXAlignment = Enum.TextXAlignment.Left
wallLabel.TextSize = 11
wallLabel.Font = Enum.Font.Code
wallLabel.Visible = false
wallLabel.Parent = modal

local bar = Instance.new("Frame")
bar.Name = "ReplayBar"
bar.Position = UDim2.new(0, 12, 0.7, 0)
bar.Size = UDim2.new(1, -24, 0, 16)
bar.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
bar.BorderSizePixel = 0
bar.ClipsDescendants = true
bar.Parent = modal
corner(bar, 6)

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(120, 90, 190)
fill.BorderSizePixel = 0
fill.Parent = bar
corner(fill, 6)

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(0.5, 1)
closeButton.Position = UDim2.new(0.5, 0, 0.86, 0)
closeButton.Size = UDim2.new(0.5, 0, 0, 34)
closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
closeButton.BorderSizePixel = 0
closeButton.Text = "FECHAR"
closeButton.TextColor3 = Color3.fromRGB(235, 235, 245)
closeButton.TextScaled = true
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = modal
corner(closeButton, 8)

local busy = false
local scene: Folder? = nil
local unitParts: { BasePart } = {}

local function setBusy(value: boolean): ()
	busy = value
	attackButton.Visible = not value
end

local function makePart(parent: Instance, size: Vector3, cframe: CFrame, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function clearScene(): ()
	if scene ~= nil then
		scene:Destroy()
		scene = nil
	end
	viewport.CurrentCamera = nil
	viewport.Visible = false
	wallLabel.Visible = false
	unitParts = {}
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
		local units = {}
		for index = 1, battle.uCount do
			if battle.uHp[index] > 0 then
				units[#units + 1] = {
					lane = battle.uLane[index],
					x = battle.uX[index],
				}
			end
		end
		frames[#frames + 1] = {
			wallPct = math.clamp(battle.wallHp / battle.wallMax, 0, 1),
			units = units,
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
	camera.FieldOfView = 55
	camera.CFrame = CFrame.lookAt(Vector3.new(20, 30, 50), Vector3.new(20, 2, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	makePart(scene, Vector3.new(48, 1, 22), CFrame.new(20, -0.5, 0), Color3.fromRGB(60, 100, 58))
	for lane = 0, 4 do
		local z = -8 + lane * 4
		makePart(
			scene,
			Vector3.new(44, 0.14, 3.2),
			CFrame.new(20, 0.07, z),
			Color3.fromRGB(45, 65, 45)
		)
	end
	makePart(scene, Vector3.new(3, 9, 23), CFrame.new(0, 4.5, 0), Color3.fromRGB(42, 62, 44))
	makePart(scene, Vector3.new(1.4, 7, 11), CFrame.new(1.5, 3.5, 0), Color3.fromRGB(92, 54, 34))

	local colors = {
		archer = Color3.fromRGB(80, 190, 110),
		frost = Color3.fromRGB(120, 200, 240),
		tar = Color3.fromRGB(150, 120, 70),
		cannon = Color3.fromRGB(220, 120, 60),
		catapult = Color3.fromRGB(210, 90, 160),
	}
	for _, trap in ipairs(result.wall.traps or {}) do
		local row, col = string.match(tostring(trap.cell), "^r(%d+)c(%d+)$")
		if row ~= nil and col ~= nil then
			local x = 2 + tonumber(col) * 6
			local z = -8 + (tonumber(row) - 1) * 4
			local color = colors[trap.type] or Color3.fromRGB(180, 180, 180)
			makePart(scene, Vector3.new(2.6, 1.8, 3.2), CFrame.new(x, 0.9, z), color)
		end
	end

	unitParts = {}
	for index = 1, 70 do
		local part = makePart(
			scene,
			Vector3.new(2.2, 2.2, 2.2),
			CFrame.new(40, 1.2, 0),
			Color3.fromRGB(200, 55, 55)
		)
		part.Transparency = 1
		unitParts[index] = part
	end
end

local function updateFrame(frame: any): ()
	wallLabel.Text = string.format("MURALHA %d%%", math.floor((frame.wallPct or 0) * 100))
	for _, part in ipairs(unitParts) do
		part.Transparency = 1
	end
	for index, unit in ipairs(frame.units or {}) do
		local part = unitParts[index]
		if part ~= nil then
			part.Transparency = 0
			part.CFrame = CFrame.new(unit.x / 10000 * 40, 1.2, -8 + unit.lane * 4)
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
	closeButton.Visible = false
	fill.Size = UDim2.fromScale(0, 1)

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
	local firstOk, firstErr = pcall(updateFrame, frames[1])
	if not firstOk then
		showError("Replay 3D indisponivel: " .. tostring(firstErr))
		return
	end
	local seconds = tonumber(result.replaySeconds) or 8
	local started = time()
	task.spawn(function()
		local animationOk, animationErr = pcall(function()
			while true do
				local progress = math.clamp((time() - started) / seconds, 0, 1)
				local index = math.clamp(math.floor(progress * (#frames - 1)) + 1, 1, #frames)
				updateFrame(frames[index])
				fill.Size = UDim2.fromScale(progress, 1)
				if progress >= 1 then
					break
				end
				task.wait(0.03)
			end
		end)
		if animationOk then
			status.Text = "REPLAY CONCLUIDO · " .. tostring(seconds) .. "s"
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
	fill.Size = UDim2.fromScale(0, 1)
	closeButton.Visible = true
	setBusy(false)
end

attackButton.MouseButton1Click:Connect(function()
	if busy then
		return
	end
	setBusy(true)
	showModal()
	status.Text = "ATACANDO..."
	details.Text = ""
	closeButton.Visible = false
	clearScene()

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
	else
		status.Text = "DERROTA"
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

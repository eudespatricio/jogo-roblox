--!nonstrict
-- S6 (scaffold): painel de raid do cliente. O servidor roda a batalha/replay e devolve o
-- BattleLog; aqui so mostramos o resultado e uma barra de replay de 8 s. Sem camera/3D nova:
-- o replay visual completo fica para a proxima janela de cena.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("MuralhaRemotes")
local raidStart = remotes:WaitForChild("RaidStart") :: RemoteFunction

for _ = 1, 50 do
	if ReplicatedStorage:GetAttribute("RaidEnabled") ~= nil then
		break
	end
	task.wait(0.1)
end
if ReplicatedStorage:GetAttribute("RaidEnabled") ~= true then
	return
end

-- Espera o drop-in (se existir) para o botao nao aparecer sobre a cena de abertura.
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
modal.Size = UDim2.fromScale(0.78, 0.56)
modal.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
modal.BackgroundTransparency = 0.08
modal.BorderSizePixel = 0
modal.Visible = false
modal.Parent = root
corner(modal, 12)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(12, 10)
title.Size = UDim2.new(1, -24, 0, 34)
title.BackgroundTransparency = 1
title.Text = "RAID"
title.TextColor3 = Color3.fromRGB(230, 220, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title.Parent = modal

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Position = UDim2.fromOffset(12, 48)
status.Size = UDim2.new(1, -24, 0, 28)
status.BackgroundTransparency = 1
status.Text = "ATACANDO..."
status.TextColor3 = Color3.fromRGB(200, 210, 235)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextScaled = true
status.Font = Enum.Font.Gotham
status.Parent = modal

local details = Instance.new("TextLabel")
details.Name = "Details"
details.Position = UDim2.fromOffset(12, 82)
details.Size = UDim2.new(1, -24, 0, 92)
details.BackgroundTransparency = 1
details.Text = ""
details.TextColor3 = Color3.fromRGB(220, 235, 220)
details.TextXAlignment = Enum.TextXAlignment.Left
details.TextYAlignment = Enum.TextYAlignment.Top
details.TextWrapped = true
details.TextScaled = false
details.TextSize = 14
details.Font = Enum.Font.Code
details.Parent = modal

local bar = Instance.new("Frame")
bar.Name = "ReplayBar"
bar.Position = UDim2.new(0, 12, 0.72, 0)
bar.Size = UDim2.new(1, -24, 0, 18)
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
closeButton.Position = UDim2.new(0.5, 0, 1, -14)
closeButton.Size = UDim2.new(0.5, 0, 0, 36)
closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
closeButton.BorderSizePixel = 0
closeButton.Text = "FECHAR"
closeButton.TextColor3 = Color3.fromRGB(235, 235, 245)
closeButton.TextScaled = true
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = modal
corner(closeButton, 8)

local busy = false
local function setBusy(value: boolean): ()
	busy = value
	attackButton.Visible = not value
end

local function showModal(): ()
	modal.Visible = true
end

local function hideModal(): ()
	modal.Visible = false
	status.Text = "PRONTO"
	details.Text = ""
	fill.Size = UDim2.fromScale(0, 1)
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
	fill.Size = UDim2.fromScale(0, 1)

	local ok, result = pcall(function()
		return raidStart:InvokeServer()
	end)
	if not ok or type(result) ~= "table" or result.ok ~= true then
		local reason = "servidor indisponivel"
		if ok and type(result) == "table" then
			reason = tostring(result.err)
		end
		status.Text = "RAID FALHOU: " .. reason
		details.Text = "Tente de novo."
		setBusy(false)
		return
	end

	if result.winner == "attacker" then
		status.Text = "VITORIA"
	else
		status.Text = "DERROTA"
	end
	details.Text = string.format(
		"battle_id %s\nhash %s\nmuralha %s HP · vazados %s\nrecompensa %s ouro",
		tostring(result.battleId),
		tostring(result.resultHash),
		tostring(result.wallHp),
		tostring(result.leaked),
		tostring(result.rewardGold)
	)
	local seconds = tonumber(result.replaySeconds) or 8
	local started = time()
	task.spawn(function()
		while time() - started < seconds do
			local progress = math.clamp((time() - started) / seconds, 0, 1)
			fill.Size = UDim2.fromScale(progress, 1)
			task.wait(0.05)
		end
		fill.Size = UDim2.fromScale(1, 1)
		status.Text = "REPLAY CONCLUIDO · " .. tostring(seconds) .. "s"
		setBusy(false)
	end)
end)

closeButton.MouseButton1Click:Connect(hideModal)

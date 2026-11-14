--!strict
-- Boot loading imediato em ReplicatedFirst: remove a tela padrao do Roblox e exibe o key-art
-- de A Muralha sobre fundo escuro ate a primeira arena (Drop-In ou Build) nascer no Workspace.
-- Nunca bloqueia a janela <5s do P1 Drop-In (desaparece assim que DropInLocalScene existir).

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local TRANSITION_BG_ASSET = "rbxassetid://97457052708184"
local COL_BG = Color3.fromRGB(10, 14, 23)
local COL_CARD = Color3.fromRGB(16, 22, 34)
local COL_AMBER = Color3.fromRGB(245, 158, 11)
local COL_AMBER_BRIGHT = Color3.fromRGB(255, 199, 64)
local COL_TEAL = Color3.fromRGB(20, 184, 166)
local COL_PARCHMENT = Color3.fromRGB(245, 230, 200)

local player = Players.LocalPlayer
if player == nil then
	return
end
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "MuralhaBootLoadingGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local canvas = Instance.new("CanvasGroup")
canvas.Name = "BootCanvas"
canvas.Size = UDim2.fromScale(1, 1)
canvas.BackgroundColor3 = COL_BG
canvas.BackgroundTransparency = 0
canvas.BorderSizePixel = 0
canvas.GroupTransparency = 0
canvas.Parent = gui

local amberGlow = Instance.new("Frame")
amberGlow.Size = UDim2.fromScale(0.5, 1)
amberGlow.BackgroundColor3 = Color3.fromRGB(58, 36, 16)
amberGlow.BackgroundTransparency = 0.25
amberGlow.BorderSizePixel = 0
amberGlow.Parent = canvas
local gradL = Instance.new("UIGradient")
gradL.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.1),
	NumberSequenceKeypoint.new(1, 1),
})
gradL.Parent = amberGlow

local tealGlow = Instance.new("Frame")
tealGlow.AnchorPoint = Vector2.new(1, 0)
tealGlow.Position = UDim2.fromScale(1, 0)
tealGlow.Size = UDim2.fromScale(0.5, 1)
tealGlow.BackgroundColor3 = Color3.fromRGB(12, 48, 56)
tealGlow.BackgroundTransparency = 0.25
tealGlow.BorderSizePixel = 0
tealGlow.Parent = canvas
local gradR = Instance.new("UIGradient")
gradR.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(1, 0.1),
})
gradR.Parent = tealGlow

local keyArt = Instance.new("ImageLabel")
keyArt.Name = "Backdrop"
keyArt.Size = UDim2.fromScale(1, 1)
keyArt.BackgroundTransparency = 1
keyArt.Image = TRANSITION_BG_ASSET
keyArt.ScaleType = Enum.ScaleType.Crop
keyArt.ImageTransparency = 0.15
keyArt.Parent = canvas

local vignette = Instance.new("Frame")
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundColor3 = COL_BG
vignette.BackgroundTransparency = 0.35
vignette.BorderSizePixel = 0
vignette.Parent = canvas

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.52)
card.Size = UDim2.fromOffset(340, 126)
card.BackgroundColor3 = COL_CARD
card.BackgroundTransparency = 0.12
card.BorderSizePixel = 0
card.Parent = canvas

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 16)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = COL_AMBER
cardStroke.Thickness = 2
cardStroke.Transparency = 0.18
cardStroke.Parent = card

local titleText = "A MURALHA"
local subText = "Preparando Bastiao..."
local okLoc, rawLocale = pcall(function()
	return string.lower(LocalizationService.RobloxLocaleId)
end)
if okLoc and type(rawLocale) == "string" then
	if string.sub(rawLocale, 1, 2) == "en" then
		titleText = "WALLBREAKER"
		subText = "Preparing Bastion..."
	elseif string.sub(rawLocale, 1, 2) == "es" then
		titleText = "LA MURALLA"
		subText = "Preparando Bastion..."
	end
end

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(18, 16)
title.Size = UDim2.new(1, -36, 0, 38)
title.Font = Enum.Font.GothamBlack
title.Text = titleText
title.TextColor3 = COL_AMBER_BRIGHT
title.TextScaled = true
title.Parent = card

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Position = UDim2.fromOffset(18, 58)
sub.Size = UDim2.new(1, -36, 0, 22)
sub.Font = Enum.Font.GothamBold
sub.Text = subText
sub.TextColor3 = COL_PARCHMENT
sub.TextScaled = true
sub.Parent = card

local track = Instance.new("Frame")
track.Position = UDim2.fromOffset(26, 92)
track.Size = UDim2.new(1, -52, 0, 8)
track.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
track.BorderSizePixel = 0
track.Parent = card
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(0, 6)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0.2, 1)
fill.BackgroundColor3 = COL_TEAL
fill.BorderSizePixel = 0
fill.Parent = track
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 6)
fillCorner.Parent = fill
local fillGrad = Instance.new("UIGradient")
fillGrad.Color = ColorSequence.new(COL_AMBER, COL_TEAL)
fillGrad.Parent = fill

TweenService:Create(
	fill,
	TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{ Size = UDim2.fromScale(0.95, 1) }
):Play()

task.spawn(function()
	local started = time()
	while ReplicatedStorage:GetAttribute("DropInEnabled") == nil and (time() - started) < 1.2 do
		task.wait(0.03)
	end

	local dropInEnabled = ReplicatedStorage:GetAttribute("DropInEnabled") == true
	local dropInDone = player:GetAttribute("DropInDone") == true
	if dropInEnabled and not dropInDone then
		local waitStart = time()
		while Workspace:FindFirstChild("DropInLocalScene") == nil and (time() - waitStart) < 0.65 do
			task.wait(0.03)
		end
	else
		local waitStart = time()
		while Workspace:FindFirstChild("MuralhaArena") == nil and (time() - waitStart) < 2.0 do
			task.wait(0.05)
		end
	end

	local fadeTween = TweenService:Create(
		canvas,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ GroupTransparency = 1 }
	)
	fadeTween:Play()
	fadeTween.Completed:Wait()
	if gui.Parent ~= nil then
		gui:Destroy()
	end
end)

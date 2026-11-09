--!strict
-- HUD de moedas: o cliente apenas LE o leaderstats replicado pelo servidor.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CoinHud"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(196, 60)
panel.Position = UDim2.fromOffset(20, 20)
panel.BackgroundColor3 = Config.Hud.Panel
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Config.Hud.Accent
stroke.Thickness = 1.5
stroke.Transparency = 0.55
stroke.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 14)
padding.PaddingRight = UDim.new(0, 14)
padding.Parent = panel

local icon = Instance.new("TextLabel")
icon.Name = "Icon"
icon.Size = UDim2.fromOffset(34, 34)
icon.Position = UDim2.new(0, 0, 0.5, 0)
icon.AnchorPoint = Vector2.new(0, 0.5)
icon.BackgroundTransparency = 1
icon.FontFace = BOLD
icon.Text = "●"
icon.TextSize = 26
icon.TextColor3 = Config.Hud.Accent
icon.Parent = panel

local value = Instance.new("TextLabel")
value.Name = "Value"
value.Size = UDim2.new(1, -46, 1, 0)
value.Position = UDim2.fromOffset(46, 0)
value.BackgroundTransparency = 1
value.FontFace = BOLD
value.Text = "0"
value.TextSize = 26
value.TextXAlignment = Enum.TextXAlignment.Left
value.TextColor3 = Config.Hud.Text
value.Parent = panel

local scale = Instance.new("UIScale")
scale.Scale = 1
scale.Parent = panel

local function pulse()
	scale.Scale = 1.08
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

local function setValue(amount: number)
	value.Text = string.format("%d", amount)
	pulse()
end

local function bind(leaderstats: Instance)
	local coins = leaderstats:WaitForChild("Coins", 10) :: IntValue?
	if not coins then
		return
	end
	setValue(coins.Value)
	coins.Changed:Connect(function(amount)
		setValue(amount)
	end)
end

local leaderstats = player:WaitForChild("leaderstats", 15)
if leaderstats then
	bind(leaderstats)
else
	player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" then
			bind(child)
		end
	end)
end

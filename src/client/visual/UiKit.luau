--!nonstrict
-- S8: kit de UI compartilhado (paineis, botoes, moeda, barra, card de armadilha).
-- Usa VisualTheme; os textos/estados continuam nos clientes Build/DropIn/Raid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local VisualTheme = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("VisualTheme")
)

local UiKit = {}

function UiKit.color(value: { number }): Color3
	return Color3.fromRGB(value[1], value[2], value[3])
end

function UiKit.corner(parent: Instance, radius: number): UICorner
	local existing = parent:FindFirstChildOfClass("UICorner")
	if existing ~= nil then
		existing.CornerRadius = UDim.new(0, radius)
		return existing
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function UiKit.stroke(
	parent: Instance,
	color: Color3,
	thickness: number?,
	transparency: number?
): UIStroke
	local existing = parent:FindFirstChildOfClass("UIStroke")
	if existing ~= nil then
		existing.Color = color
		existing.Thickness = thickness or 1
		existing.Transparency = transparency or 0
		return existing
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

function UiKit.panel(parent: Instance, name: string, color: Color3?): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.BackgroundColor3 = color or UiKit.color(VisualTheme.PALETTE.ink)
	panel.BackgroundTransparency = 0.06
	panel.BorderSizePixel = 0
	panel.Parent = parent
	UiKit.corner(panel, VisualTheme.UI.panelCorner)
	UiKit.stroke(panel, UiKit.color(VisualTheme.PALETTE.iron), 1, 0.25)
	return panel
end

function UiKit.label(
	parent: Instance,
	name: string,
	text: string,
	color: Color3?,
	font: Enum.Font?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or UiKit.color(VisualTheme.PALETTE.parchment)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Font = font or Enum.Font.GothamBold
	label.Parent = parent
	return label
end

function UiKit.button(parent: Instance, name: string, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.iron)
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBlack
	button.AutoButtonColor = false
	button.Parent = parent
	UiKit.corner(button, VisualTheme.UI.buttonCorner)
	UiKit.stroke(button, UiKit.color(VisualTheme.PALETTE.amber), 1, 0.55)

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.97 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	return button
end

function UiKit.setSelected(button: TextButton, selected: boolean): ()
	if selected then
		button.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.amber)
		button.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
		UiKit.stroke(button, UiKit.color(VisualTheme.PALETTE.amberBright), 2, 0)
	else
		button.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.iron)
		button.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
		UiKit.stroke(button, UiKit.color(VisualTheme.PALETTE.amber), 1, 0.55)
	end
end

function UiKit.iconCoin(parent: Instance, size: number): Frame
	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.Size = UDim2.fromOffset(size, size)
	coin.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.amber)
	coin.BorderSizePixel = 0
	coin.Parent = parent
	UiKit.corner(coin, size)
	UiKit.stroke(coin, UiKit.color(VisualTheme.PALETTE.amberBright), 2, 0)

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.55, 0.55)
	inner.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.amberBright)
	inner.BorderSizePixel = 0
	inner.Parent = coin
	UiKit.corner(inner, size)
	return coin
end

function UiKit.progress(
	parent: Instance,
	name: string,
	fillColor: Color3?
): { frame: Frame, fill: Frame, set: (number) -> () }
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ironDark)
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = parent
	UiKit.corner(frame, VisualTheme.UI.barCorner)
	UiKit.stroke(frame, UiKit.color(VisualTheme.PALETTE.iron), 1, 0.2)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = fillColor or UiKit.color(VisualTheme.PALETTE.amber)
	fill.BorderSizePixel = 0
	fill.Parent = frame
	UiKit.corner(fill, VisualTheme.UI.barCorner)

	local function set(pct: number): ()
		local clamped = math.clamp(pct, 0, 1)
		fill.Size = UDim2.fromScale(clamped, 1)
		if clamped < 0.3 then
			fill.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.danger)
		else
			fill.BackgroundColor3 = fillColor or UiKit.color(VisualTheme.PALETTE.amber)
		end
	end

	return { frame = frame, fill = fill, set = set }
end

function UiKit.card(
	parent: Instance,
	name: string
): { frame: TextButton, icon: Frame, name: TextLabel, cost: TextLabel }
	local frame = UiKit.button(parent, name, "")
	frame.Text = ""

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 4, 0.5, 0)
	icon.Size = UDim2.new(0, 22, 0, 22)
	icon.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.stone)
	icon.BorderSizePixel = 0
	icon.Parent = frame
	UiKit.corner(icon, 6)

	local iconText = Instance.new("TextLabel")
	iconText.Name = "Glyph"
	iconText.Size = UDim2.fromScale(1, 1)
	iconText.BackgroundTransparency = 1
	iconText.Text = "?"
	iconText.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
	iconText.TextScaled = true
	iconText.Font = Enum.Font.GothamBlack
	iconText.Parent = icon

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Position = UDim2.new(0, 30, 0, 3)
	nameLabel.Size = UDim2.new(1, -34, 0.55, -3)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = name
	nameLabel.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.Parent = frame

	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "Cost"
	costLabel.Position = UDim2.new(0, 30, 0.55, 0)
	costLabel.Size = UDim2.new(1, -34, 0.45, -2)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = "0"
	costLabel.TextColor3 = UiKit.color(VisualTheme.PALETTE.amberBright)
	costLabel.TextXAlignment = Enum.TextXAlignment.Left
	costLabel.TextTruncate = Enum.TextTruncate.AtEnd
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextScaled = true
	costLabel.Parent = frame

	return { frame = frame, icon = icon, name = nameLabel, cost = costLabel }
end

function UiKit.setCard(card: any, spec: any, selected: boolean): ()
	local color = UiKit.color(spec.color)
	card.icon.BackgroundColor3 = color
	card.icon.Glyph.Text = spec.icon
	card.name.Text = spec.label
	UiKit.setSelected(card.frame, selected)
end

return UiKit

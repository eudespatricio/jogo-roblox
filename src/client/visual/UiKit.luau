--!strict
-- S8: kit de UI compartilhado (paineis, botoes, moeda, barra, card de armadilha).
-- Usa VisualTheme; os textos/estados continuam nos clientes Build/DropIn/Raid.

local GuiService = game:GetService("GuiService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildLayout = require(Shared:WaitForChild("build"):WaitForChild("BuildLayout"))
local VisualTheme = require(Shared:WaitForChild("visual"):WaitForChild("VisualTheme"))
local I18n = require(Shared:WaitForChild("i18n"):WaitForChild("I18n"))

local LOCALE_ATTR = "MuralhaLocale"
local CAMERA_ATTR = "MuralhaCameraAngle"
local CAMERA_ORDER = { "diagonal", "corridor", "wall" }

export type ProgressBar = {
	frame: Frame,
	fill: Frame,
	set: (pct: number) -> (),
}

export type TrapCardIcon = Frame & {
	Glyph: TextLabel,
}

export type TrapCard = {
	frame: TextButton,
	icon: TrapCardIcon,
	emblem: Frame,
	lockBadge: Frame,
	name: TextLabel,
	cost: TextLabel,
	trapId: string?,
}

export type TrapSpec = {
	label: string,
	icon: string,
	color: { number },
	accent: { number }?,
}

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

local function ensureGradient(
	parent: Instance,
	topColor: Color3,
	bottomColor: Color3,
	rotation: number?
): UIGradient
	local existing = parent:FindFirstChildOfClass("UIGradient")
	local gradient = if existing ~= nil then existing else Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(topColor, bottomColor)
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

local function ensurePadding(
	parent: Instance,
	left: number,
	right: number,
	top: number,
	bottom: number
): UIPadding
	local existing = parent:FindFirstChildOfClass("UIPadding")
	local pad = if existing ~= nil then existing else Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, left)
	pad.PaddingRight = UDim.new(0, right)
	pad.PaddingTop = UDim.new(0, top)
	pad.PaddingBottom = UDim.new(0, bottom)
	pad.Parent = parent
	return pad
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
	ensureGradient(panel, Color3.fromRGB(255, 255, 255), Color3.fromRGB(224, 226, 232), 90)
	ensurePadding(panel, 0, 0, 0, 0)
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
	ensureGradient(button, Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 216, 224), 90)
	ensurePadding(button, 6, 6, 3, 3)

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

function UiKit.progress(parent: Instance, name: string, fillColor: Color3?): ProgressBar
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
	ensureGradient(fill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 212), 90)

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

local function emblemPart(
	parent: Instance,
	name: string,
	pos: UDim2,
	size: UDim2,
	color: Color3,
	rotation: number?,
	cornerRadius: number?,
	anchor: Vector2?
): Frame
	local part = Instance.new("Frame")
	part.Name = name
	if anchor ~= nil then
		part.AnchorPoint = anchor
	end
	part.Position = pos
	part.Size = size
	part.BackgroundColor3 = color
	part.BorderSizePixel = 0
	part.Rotation = rotation or 0
	part.Parent = parent
	if cornerRadius ~= nil and cornerRadius > 0 then
		UiKit.corner(part, cornerRadius)
	end
	return part
end

local function buildTrapEmblem(emblem: Frame, trapId: string): boolean
	emblem:ClearAllChildren()
	local ink = UiKit.color(VisualTheme.PALETTE.ink)
	local parchment = UiKit.color(VisualTheme.PALETTE.parchment)
	local amberBright = UiKit.color(VisualTheme.PALETTE.amberBright)
	local ironDark = UiKit.color(VisualTheme.PALETTE.ironDark)
	local white = UiKit.color(VisualTheme.PALETTE.white)
	local danger = UiKit.color(VisualTheme.PALETTE.danger)
	local woodDark = UiKit.color(VisualTheme.PALETTE.woodDark)

	if trapId == "archer" then
		emblemPart(
			emblem,
			"BowTop",
			UDim2.fromScale(0.32, 0.14),
			UDim2.fromScale(0.15, 0.38),
			woodDark,
			26,
			4,
			nil
		)
		emblemPart(
			emblem,
			"BowBot",
			UDim2.fromScale(0.32, 0.48),
			UDim2.fromScale(0.15, 0.38),
			woodDark,
			-26,
			4,
			nil
		)
		emblemPart(
			emblem,
			"String",
			UDim2.fromScale(0.24, 0.17),
			UDim2.fromScale(0.06, 0.66),
			parchment,
			0,
			2,
			nil
		)
		emblemPart(
			emblem,
			"Shaft",
			UDim2.fromScale(0.50, 0.50),
			UDim2.fromScale(0.56, 0.11),
			ink,
			-18,
			2,
			Vector2.new(0.5, 0.5)
		)
		emblemPart(
			emblem,
			"Tip",
			UDim2.fromScale(0.75, 0.41),
			UDim2.fromScale(0.20, 0.20),
			amberBright,
			45,
			2,
			Vector2.new(0.5, 0.5)
		)
		return true
	elseif trapId == "tar" then
		emblemPart(
			emblem,
			"Drop",
			UDim2.fromScale(0.50, 0.20),
			UDim2.fromScale(0.22, 0.22),
			ink,
			45,
			4,
			Vector2.new(0.5, 0.5)
		)
		emblemPart(
			emblem,
			"Bubble",
			UDim2.fromScale(0.68, 0.26),
			UDim2.fromScale(0.12, 0.12),
			amberBright,
			0,
			99,
			Vector2.new(0.5, 0.5)
		)
		emblemPart(
			emblem,
			"PotRim",
			UDim2.fromScale(0.50, 0.44),
			UDim2.fromScale(0.72, 0.14),
			ironDark,
			0,
			4,
			Vector2.new(0.5, 0.5)
		)
		emblemPart(
			emblem,
			"PotBody",
			UDim2.fromScale(0.50, 0.66),
			UDim2.fromScale(0.60, 0.38),
			ink,
			0,
			8,
			Vector2.new(0.5, 0.5)
		)
		emblemPart(
			emblem,
			"PotGlow",
			UDim2.fromScale(0.50, 0.42),
			UDim2.fromScale(0.46, 0.08),
			amberBright,
			0,
			4,
			Vector2.new(0.5, 0.5)
		)
		return true
	elseif trapId == "frost" then
		emblemPart(
			emblem,
			"AxisH",
			UDim2.fromScale(0.50, 0.50),
			UDim2.fromScale(0.76, 0.10),
			white,
			0,
			3,
			Vector2.new(0.5, 0.5)
		)
		emblemPart(
			emblem,
			"AxisV",
			UDim2.fromScale(0.50, 0.50),
			UDim2.fromScale(0.10, 0.76),
			white,
			0,
			3,
			Vector2.new(0.5, 0.5)
		)
		emblemPart(
			emblem,
			"DiamondOuter",
			UDim2.fromScale(0.50, 0.50),
			UDim2.fromScale(0.48, 0.48),
			white,
			45,
			2,
			Vector2.new(0.5, 0.5)
		)
		emblemPart(
			emblem,
			"DiamondCore",
			UDim2.fromScale(0.50, 0.50),
			UDim2.fromScale(0.24, 0.24),
			Color3.fromRGB(36, 118, 196),
			45,
			2,
			Vector2.new(0.5, 0.5)
		)
		return true
	elseif trapId == "cannon" then
		emblemPart(
			emblem,
			"Barrel",
			UDim2.fromScale(0.50, 0.42),
			UDim2.fromScale(0.62, 0.26),
			ink,
			-22,
			4,
			Vector2.new(0.5, 0.5)
		)
		emblemPart(
			emblem,
			"Muzzle",
			UDim2.fromScale(0.77, 0.31),
			UDim2.fromScale(0.14, 0.32),
			danger,
			-22,
			3,
			Vector2.new(0.5, 0.5)
		)
		local wheel = emblemPart(
			emblem,
			"Wheel",
			UDim2.fromScale(0.36, 0.68),
			UDim2.fromScale(0.36, 0.36),
			woodDark,
			0,
			99,
			Vector2.new(0.5, 0.5)
		)
		UiKit.stroke(wheel, ink, 1, 0)
		emblemPart(
			emblem,
			"Hub",
			UDim2.fromScale(0.36, 0.68),
			UDim2.fromScale(0.14, 0.14),
			amberBright,
			0,
			99,
			Vector2.new(0.5, 0.5)
		)
		return true
	elseif trapId == "catapult" then
		emblemPart(
			emblem,
			"Arm",
			UDim2.fromScale(0.49, 0.44),
			UDim2.fromScale(0.64, 0.13),
			woodDark,
			-32,
			3,
			Vector2.new(0.5, 0.5)
		)
		emblemPart(
			emblem,
			"Boulder",
			UDim2.fromScale(0.22, 0.28),
			UDim2.fromScale(0.26, 0.26),
			amberBright,
			0,
			99,
			Vector2.new(0.5, 0.5)
		)
		emblemPart(
			emblem,
			"Post",
			UDim2.fromScale(0.50, 0.58),
			UDim2.fromScale(0.16, 0.36),
			ink,
			0,
			2,
			Vector2.new(0.5, 0.5)
		)
		emblemPart(
			emblem,
			"Base",
			UDim2.fromScale(0.50, 0.78),
			UDim2.fromScale(0.72, 0.15),
			ink,
			0,
			3,
			Vector2.new(0.5, 0.5)
		)
		return true
	end
	return false
end

function UiKit.card(parent: Instance, name: string): TrapCard
	local frame = UiKit.button(parent, name, "")
	frame.Text = ""
	ensurePadding(frame, 0, 0, 0, 0)

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.Position = UDim2.new(0, 4, 0, 4)
	icon.Size = UDim2.fromScale(0.42, 0.42)
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.stone)
	icon.BorderSizePixel = 0
	icon.Parent = frame
	UiKit.corner(icon, 6)
	UiKit.stroke(icon, UiKit.color(VisualTheme.PALETTE.ink), 1, 0.35)
	ensureGradient(icon, Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 212), 90)

	local iconSize = Instance.new("UISizeConstraint")
	iconSize.MinSize = Vector2.new(18, 18)
	iconSize.MaxSize = Vector2.new(44, 44)
	iconSize.Parent = icon

	local iconText = Instance.new("TextLabel")
	iconText.Name = "Glyph"
	iconText.Size = UDim2.fromScale(1, 1)
	iconText.BackgroundTransparency = 1
	iconText.Text = "?"
	iconText.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
	iconText.TextScaled = true
	iconText.Font = Enum.Font.GothamBlack
	iconText.ZIndex = 2
	iconText.Parent = icon

	local emblem = Instance.new("Frame")
	emblem.Name = "Emblem"
	emblem.Size = UDim2.fromScale(1, 1)
	emblem.BackgroundTransparency = 1
	emblem.Visible = false
	emblem.ZIndex = 3
	emblem.Parent = icon

	local lockBadge = Instance.new("Frame")
	lockBadge.Name = "LockBadge"
	lockBadge.AnchorPoint = Vector2.new(1, 1)
	lockBadge.Position = UDim2.fromScale(1.06, 1.06)
	lockBadge.Size = UDim2.fromScale(0.48, 0.48)
	lockBadge.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ink)
	lockBadge.BorderSizePixel = 0
	lockBadge.Visible = false
	lockBadge.ZIndex = 4
	lockBadge.Parent = icon
	UiKit.corner(lockBadge, 4)
	UiKit.stroke(lockBadge, UiKit.color(VisualTheme.PALETTE.stone), 1, 0.1)

	local shackle = emblemPart(
		lockBadge,
		"Shackle",
		UDim2.fromScale(0.50, 0.28),
		UDim2.fromScale(0.46, 0.36),
		UiKit.color(VisualTheme.PALETTE.ink),
		0,
		99,
		Vector2.new(0.5, 0.5)
	)
	shackle.ZIndex = 5
	UiKit.stroke(shackle, UiKit.color(VisualTheme.PALETTE.parchment), 1, 0.15)
	local lockBody = emblemPart(
		lockBadge,
		"Body",
		UDim2.fromScale(0.50, 0.64),
		UDim2.fromScale(0.62, 0.42),
		UiKit.color(VisualTheme.PALETTE.amberBright),
		0,
		2,
		Vector2.new(0.5, 0.5)
	)
	lockBody.ZIndex = 5

	local hasEmblem = buildTrapEmblem(emblem, name)
	if hasEmblem then
		emblem.Visible = true
		iconText.Visible = false
	end

	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "Cost"
	costLabel.Position = UDim2.new(0.44, 0, 0, 4)
	costLabel.Size = UDim2.new(0.50, 0, 0.40, -1)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = "0"
	costLabel.TextColor3 = UiKit.color(VisualTheme.PALETTE.amberBright)
	costLabel.TextXAlignment = Enum.TextXAlignment.Right
	costLabel.TextTruncate = Enum.TextTruncate.AtEnd
	costLabel.Font = Enum.Font.GothamBlack
	costLabel.TextScaled = true
	costLabel.Parent = frame
	local costMax = Instance.new("UITextSizeConstraint")
	costMax.MaxTextSize = 15
	costMax.Parent = costLabel

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Position = UDim2.new(0.06, 0, 0.56, 0)
	nameLabel.Size = UDim2.new(0.88, 0, 0.38, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = name
	nameLabel.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.Parent = frame
	local nameMax = Instance.new("UITextSizeConstraint")
	nameMax.MaxTextSize = 14
	nameMax.Parent = nameLabel

	return {
		frame = frame,
		icon = icon :: TrapCardIcon,
		emblem = emblem,
		lockBadge = lockBadge,
		name = nameLabel,
		cost = costLabel,
		trapId = if hasEmblem then name else nil,
	}
end

function UiKit.setCard(
	card: TrapCard,
	spec: TrapSpec,
	selected: boolean,
	trapId: string?,
	locked: boolean?,
	affordable: boolean?
): ()
	local isLocked = locked == true
	local isAffordable = affordable ~= false
	local resolvedId = trapId or card.trapId
	if resolvedId ~= nil and resolvedId ~= card.trapId then
		if buildTrapEmblem(card.emblem, resolvedId) then
			card.trapId = resolvedId
		end
	end

	local hasEmblem = card.emblem:FindFirstChildWhichIsA("Frame") ~= nil
	card.emblem.Visible = hasEmblem
	card.icon.Glyph.Visible = not hasEmblem
	card.icon.Glyph.Text = spec.icon
	card.name.Text = spec.label
	card.lockBadge.Visible = isLocked

	if isLocked then
		card.frame.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ironDark)
		card.frame.BackgroundTransparency = 0.18
		UiKit.stroke(card.frame, UiKit.color(VisualTheme.PALETTE.stoneDark), 1, 0.35)
		card.icon.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.iron)
		card.icon.Glyph.TextColor3 = UiKit.color(VisualTheme.PALETTE.stone)
		card.name.TextColor3 = UiKit.color(VisualTheme.PALETTE.stone)
		card.cost.TextColor3 = UiKit.color(VisualTheme.PALETTE.stone)
		return
	end

	card.frame.BackgroundTransparency = 0
	card.icon.BackgroundColor3 = UiKit.color(spec.color)
	card.icon.Glyph.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
	UiKit.setSelected(card.frame, selected)

	if selected then
		card.name.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
		card.cost.TextColor3 = if isAffordable
			then UiKit.color(VisualTheme.PALETTE.ink)
			else UiKit.color(VisualTheme.PALETTE.danger)
	else
		card.name.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
		card.cost.TextColor3 = if isAffordable
			then UiKit.color(VisualTheme.PALETTE.amberBright)
			else UiKit.color(VisualTheme.PALETTE.danger)
	end
end

function UiKit.getLocale(): string
	local player = Players.LocalPlayer
	if player ~= nil then
		local existing = player:GetAttribute(LOCALE_ATTR)
		if existing == "pt" or existing == "en" or existing == "es" then
			return existing
		end
		local raw = LocalizationService.RobloxLocaleId
		if type(raw) ~= "string" or raw == "" then
			raw = player.LocaleId
		end
		local resolved = I18n.resolveLocale(raw)
		player:SetAttribute(LOCALE_ATTR, resolved)
		return resolved
	end
	return I18n.resolveLocale(LocalizationService.RobloxLocaleId)
end

function UiKit.setLocale(locale: string): string
	local resolved = I18n.resolveLocale(locale)
	local player = Players.LocalPlayer
	if player ~= nil then
		player:SetAttribute(LOCALE_ATTR, resolved)
	end
	return resolved
end

function UiKit.onLocaleChanged(callback: (string) -> ()): RBXScriptConnection?
	local player = Players.LocalPlayer
	if player == nil then
		return nil
	end
	return player:GetAttributeChangedSignal(LOCALE_ATTR):Connect(function()
		callback(UiKit.getLocale())
	end)
end

function UiKit.createLocalePill(parent: Instance, onChange: ((string) -> ())?): Frame
	local pill = UiKit.panel(parent, "LocalePill")
	pill.Size = UDim2.fromOffset(128, math.max(44, VisualTheme.UI.minTouch))
	ensurePadding(pill, 4, 4, 4, 4)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = pill

	local buttons: { [string]: TextButton } = {}
	local options = {
		{ id = "pt", label = "PT" },
		{ id = "en", label = "EN" },
		{ id = "es", label = "ES" },
	}

	local function refreshButtons(): ()
		local current = UiKit.getLocale()
		for id, btn in pairs(buttons) do
			UiKit.setSelected(btn, id == current)
		end
	end

	for index, opt in ipairs(options) do
		local btn = UiKit.button(pill, "Lang_" .. opt.id, opt.label)
		btn.LayoutOrder = index
		btn.Size = UDim2.fromOffset(36, 34)
		ensurePadding(btn, 3, 3, 3, 3)
		local textCap = Instance.new("UITextSizeConstraint")
		textCap.MaxTextSize = 13
		textCap.Parent = btn
		buttons[opt.id] = btn
		btn.MouseButton1Click:Connect(function()
			local nextLocale = UiKit.setLocale(opt.id)
			refreshButtons()
			if onChange ~= nil then
				onChange(nextLocale)
			end
		end)
	end

	refreshButtons()
	local conn = UiKit.onLocaleChanged(function()
		refreshButtons()
	end)
	pill.Destroying:Connect(function()
		if conn ~= nil then
			conn:Disconnect()
		end
	end)

	return pill
end

local LOCALE_ORDER = { "pt", "en", "es" }

function UiKit.createCompactLocalePill(parent: Instance, onChange: ((string) -> ())?): TextButton
	local btn = UiKit.button(parent, "CompactLocalePill", "PT")
	btn.Size = UDim2.fromOffset(48, math.max(44, VisualTheme.UI.minTouch))
	ensurePadding(btn, 4, 4, 4, 4)
	local textCap = Instance.new("UITextSizeConstraint")
	textCap.MaxTextSize = 14
	textCap.Parent = btn

	local function refreshLabel(): ()
		local current = UiKit.getLocale()
		btn.Text = string.upper(current)
	end

	refreshLabel()
	btn.MouseButton1Click:Connect(function()
		local current = UiKit.getLocale()
		local nextId = LOCALE_ORDER[1]
		for i, id in ipairs(LOCALE_ORDER) do
			if id == current then
				nextId = LOCALE_ORDER[(i % #LOCALE_ORDER) + 1]
				break
			end
		end
		local nextLocale = UiKit.setLocale(nextId)
		refreshLabel()
		if onChange ~= nil then
			onChange(nextLocale)
		end
	end)

	local conn = UiKit.onLocaleChanged(function()
		refreshLabel()
	end)
	btn.Destroying:Connect(function()
		if conn ~= nil then
			conn:Disconnect()
		end
	end)

	return btn
end

function UiKit.applySafeScreenGui(gui: ScreenGui): ()
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
end

function UiKit.safeTopbarInsets(rootGui: GuiObject): BuildLayout.HudInsets
	local pos = rootGui.AbsolutePosition
	local size = rootGui.AbsoluteSize
	local inset = GuiService.TopbarInset

	local leftReserve = if inset.Min.X > 0
		then math.max(0, math.ceil(inset.Min.X - pos.X))
		else math.max(0, 180 - math.max(0, math.floor(pos.X)))

	local rightReserve = 0
	if inset.Max.X > inset.Min.X and size.X > 0 then
		rightReserve = math.max(0, math.ceil((pos.X + size.X) - inset.Max.X))
	end

	local topH = if inset.Max.Y > pos.Y then math.max(40, math.ceil(inset.Max.Y - pos.Y)) else 44

	return {
		unibarLeftW = leftReserve,
		topRightW = rightReserve,
		unibarH = topH,
	}
end

function UiKit.resolveCameraAngle(raw: any): string
	if raw == "corridor" or raw == "wall" or raw == "diagonal" then
		return raw
	end
	return "diagonal"
end

function UiKit.getCameraAngle(): string
	local player = Players.LocalPlayer
	if player == nil then
		return "diagonal"
	end
	return UiKit.resolveCameraAngle(player:GetAttribute(CAMERA_ATTR))
end

function UiKit.setCameraAngle(angle: string): string
	local resolved = UiKit.resolveCameraAngle(angle)
	local player = Players.LocalPlayer
	if player ~= nil then
		player:SetAttribute(CAMERA_ATTR, resolved)
	end
	return resolved
end

function UiKit.cycleCameraAngle(): string
	local current = UiKit.getCameraAngle()
	local nextAngle = CAMERA_ORDER[1]
	for index, id in ipairs(CAMERA_ORDER) do
		if id == current then
			nextAngle = CAMERA_ORDER[(index % #CAMERA_ORDER) + 1]
			break
		end
	end
	return UiKit.setCameraAngle(nextAngle)
end

function UiKit.onCameraAngleChanged(callback: (string) -> ()): RBXScriptConnection?
	local player = Players.LocalPlayer
	if player == nil then
		return nil
	end
	return player:GetAttributeChangedSignal(CAMERA_ATTR):Connect(function()
		callback(UiKit.getCameraAngle())
	end)
end

function UiKit.cameraButtonLabel(angle: string?, compact: boolean?): string
	local resolved = UiKit.resolveCameraAngle(angle or UiKit.getCameraAngle())
	local idx = 1
	if resolved == "corridor" then
		idx = 2
	elseif resolved == "wall" then
		idx = 3
	end
	if compact == false then
		return string.format("CAM %d/3", idx)
	end
	return string.format("CAM %d", idx)
end

function UiKit.computeArenaCamera(
	origin: Vector3,
	viewportW: number,
	viewportH: number,
	mode: string?,
	angle: string?
): (CFrame, number)
	local w = math.max(320, viewportW)
	local h = math.max(240, viewportH)
	local aspect = w / h
	local resolvedAngle = UiKit.resolveCameraAngle(angle or UiKit.getCameraAngle())

	local eyeOffset: Vector3
	local lookOffset: Vector3
	local baseFov: number
	if resolvedAngle == "corridor" then
		if mode == "combat" or mode == "raid" then
			eyeOffset = Vector3.new(0, 36, 44)
			lookOffset = Vector3.new(0, 1.5, -1)
			baseFov = 42
		elseif mode == "dropin" then
			eyeOffset = Vector3.new(0, 36, 42)
			lookOffset = Vector3.new(0, 1.5, -1)
			baseFov = 42
		else
			eyeOffset = Vector3.new(0, 42, 46)
			lookOffset = Vector3.new(0, 1.2, -1)
			baseFov = 40
		end
	elseif resolvedAngle == "wall" then
		if mode == "combat" or mode == "raid" or mode == "dropin" then
			eyeOffset = Vector3.new(-27, 29, 0)
			lookOffset = Vector3.new(4, 1.5, 0)
			baseFov = 46
		else
			eyeOffset = Vector3.new(-28, 33, 0)
			lookOffset = Vector3.new(3, 1.0, 0)
			baseFov = 45
		end
	else
		if mode == "combat" or mode == "raid" then
			eyeOffset = Vector3.new(38, 28, 40)
			lookOffset = Vector3.new(1, 2, 0)
			baseFov = 40
		elseif mode == "dropin" then
			eyeOffset = Vector3.new(38, 28, 38)
			lookOffset = Vector3.new(2, 1.5, 0)
			baseFov = 40
		else
			eyeOffset = Vector3.new(42, 38, 44)
			lookOffset = Vector3.new(1, 1.2, 0)
			baseFov = 38
		end
	end

	local zoom = 1.0
	local fov = baseFov
	if aspect < 1.0 then
		zoom = math.clamp(1.12 / math.max(0.55, aspect), 1.08, 1.45)
		fov = baseFov + 10
	elseif h <= 480 then
		zoom = 1.04
		fov = baseFov + 2
	end

	local target = origin + lookOffset
	local eye = target + (eyeOffset - lookOffset) * zoom
	return CFrame.lookAt(eye, target), fov
end

return UiKit

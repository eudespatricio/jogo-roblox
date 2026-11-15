--!strict
-- HUD nao-bloqueante do FTUE Guiado (steps 1..5, GAP-020).
-- Banner passivo (Active=false exceto botao PULAR) + anel pulsante sobre o alvo do passo atual.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildLayout = require(Shared:WaitForChild("build"):WaitForChild("BuildLayout"))
local FtueLogic = require(Shared:WaitForChild("ftue"):WaitForChild("FtueLogic"))
local I18n = require(Shared:WaitForChild("i18n"):WaitForChild("I18n"))
local VisualTheme = require(Shared:WaitForChild("visual"):WaitForChild("VisualTheme"))

local UiKit = require(script.Parent:WaitForChild("UiKit"))

export type FtueUiOpts = {
	onSkip: () -> any,
	onToast: (msg: string) -> (),
}

export type FtueUiHandle = {
	applyLayout: (hudRects: BuildLayout.HudLayout) -> (),
	refreshLocale: () -> (),
}

local FtueUi = {}

function FtueUi.create(root: Frame, opts: FtueUiOpts): FtueUiHandle
	local player = Players.LocalPlayer
	local lastHudRects: BuildLayout.HudLayout? = nil
	local prevStep: number? = nil
	local skipping = false

	local banner = UiKit.panel(root, "FtueBanner", UiKit.color(VisualTheme.PALETTE.ironDark))
	banner.AnchorPoint = Vector2.zero
	banner.Position = UDim2.fromOffset(16, 62)
	banner.Size = UDim2.fromOffset(320, 44)
	banner.Active = false
	banner.Visible = false
	banner.ZIndex = 12
	UiKit.corner(banner, 10)
	UiKit.stroke(banner, UiKit.color(VisualTheme.PALETTE.amberBright), 2, 0.1)

	local hintLabel = UiKit.label(
		banner,
		"HintText",
		"",
		UiKit.color(VisualTheme.PALETTE.parchment),
		Enum.Font.GothamBold
	)
	hintLabel.Position = UDim2.fromOffset(10, 4)
	hintLabel.Size = UDim2.new(1, -84, 1, -8)
	hintLabel.Active = false
	hintLabel.TextScaled = true
	hintLabel.ZIndex = 13
	local hintCap = Instance.new("UITextSizeConstraint")
	hintCap.MinTextSize = 9
	hintCap.MaxTextSize = 13
	hintCap.Parent = hintLabel

	local skipBtn = UiKit.button(banner, "SkipFtue", I18n.t(UiKit.getLocale(), "cta_skip_ftue"))
	skipBtn.AnchorPoint = Vector2.new(1, 0.5)
	skipBtn.Position = UDim2.new(1, -6, 0.5, 0)
	skipBtn.Size = UDim2.fromOffset(66, 34)
	skipBtn.ZIndex = 13
	local skipCap = Instance.new("UITextSizeConstraint")
	skipCap.MinTextSize = 9
	skipCap.MaxTextSize = 12
	skipCap.Parent = skipBtn

	local focusRing = Instance.new("Frame")
	focusRing.Name = "FtueFocusRing"
	focusRing.AnchorPoint = Vector2.zero
	focusRing.BackgroundTransparency = 1
	focusRing.BorderSizePixel = 0
	focusRing.Active = false
	focusRing.Visible = false
	focusRing.ZIndex = 11
	focusRing.Parent = root
	UiKit.corner(focusRing, 12)
	local focusStroke =
		UiKit.stroke(focusRing, UiKit.color(VisualTheme.PALETTE.amberBright), 3, 0.15)

	local function targetRectFor(focus: string, hud: BuildLayout.HudLayout): BuildLayout.Rect?
		if focus == "trapDock" then
			return hud.trapDock
		elseif focus == "attackBtn" then
			return hud.attackBtn
		elseif focus == "toolsDock" then
			return hud.toolsDock
		elseif focus == "logBtn" then
			return hud.logBtn
		elseif focus == "storyBtn" then
			return hud.storyBtn
		end
		return nil
	end

	local function refreshState(): ()
		if player == nil then
			banner.Visible = false
			focusRing.Visible = false
			return
		end
		local dropInDone = player:GetAttribute("DropInDone") == true
		local inRaid = player:GetAttribute("MuralhaInRaid") == true
		local skipped = player:GetAttribute("MuralhaFtueSkipped") == true
		local step =
			math.clamp(math.floor(tonumber(player:GetAttribute("MuralhaFtueStep")) or 0), 0, 6)

		if prevStep ~= nil and prevStep >= 1 and prevStep <= 5 and step >= 6 and not skipped then
			opts.onToast(I18n.t(UiKit.getLocale(), "ftue_done_toast"))
		end
		prevStep = step

		local show = dropInDone and not inRaid and not skipped and step >= 1 and step <= 5
		if not show then
			banner.Visible = false
			focusRing.Visible = false
			return
		end

		local loc = UiKit.getLocale()
		local desc = FtueLogic.descriptor(step)
		hintLabel.Text = I18n.t(loc, desc.hintKey)
		skipBtn.Text = I18n.t(loc, "cta_skip_ftue")
		banner.Visible = true

		if lastHudRects ~= nil then
			local targetRect = targetRectFor(desc.targetFocus, lastHudRects)
			if targetRect ~= nil then
				focusRing.Position = UDim2.fromOffset(targetRect.x - 3, targetRect.y - 3)
				focusRing.Size = UDim2.fromOffset(targetRect.w + 6, targetRect.h + 6)
				focusRing.Visible = true
			else
				focusRing.Visible = false
			end
		else
			focusRing.Visible = false
		end
	end

	skipBtn.MouseButton1Click:Connect(function()
		if skipping then
			return
		end
		skipping = true
		task.spawn(function()
			opts.onSkip()
			skipping = false
			refreshState()
		end)
	end)

	RunService.Heartbeat:Connect(function()
		if focusRing.Visible then
			local wave = 0.5 + 0.5 * math.sin(os.clock() * 5)
			focusStroke.Transparency = 0.08 + 0.55 * wave
		end
	end)

	if player ~= nil then
		player:GetAttributeChangedSignal("DropInDone"):Connect(refreshState)
		player:GetAttributeChangedSignal("MuralhaInRaid"):Connect(refreshState)
		player:GetAttributeChangedSignal("MuralhaFtueStep"):Connect(refreshState)
		player:GetAttributeChangedSignal("MuralhaFtueSkipped"):Connect(refreshState)
	end

	local function applyLayout(hudRects: BuildLayout.HudLayout): ()
		lastHudRects = hudRects
		banner.Position = UDim2.fromOffset(hudRects.ftueBanner.x, hudRects.ftueBanner.y)
		banner.Size = UDim2.fromOffset(hudRects.ftueBanner.w, hudRects.ftueBanner.h)
		refreshState()
	end

	local function refreshLocale(): ()
		refreshState()
	end

	refreshState()

	return {
		applyLayout = applyLayout,
		refreshLocale = refreshLocale,
	}
end

return FtueUi

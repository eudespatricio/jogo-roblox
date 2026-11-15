--!strict
-- Modal de Historico de Batalhas (BattleLogUi) + Vinganca e Replay Deterministico (GAP-020).
-- Fica em src/client/visual/ para manter RaidClient enxuto e respeitar o teto de locals Luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildLayout = require(Shared:WaitForChild("build"):WaitForChild("BuildLayout"))
local I18n = require(Shared:WaitForChild("i18n"):WaitForChild("I18n"))
local VisualTheme = require(Shared:WaitForChild("visual"):WaitForChild("VisualTheme"))

local UiKit = require(script.Parent:WaitForChild("UiKit"))

export type BattleLogUiOpts = {
	fetchLogs: () -> any,
	ackReplay: () -> (),
	onReplay: (entry: any) -> (),
	onRevenge: (battleId: string) -> (),
}

export type BattleLogUiHandle = {
	logButton: TextButton,
	applyLayout: (hudRects: BuildLayout.HudLayout) -> (),
	refreshLocale: () -> (),
	setButtonsVisible: (visible: boolean) -> (),
	closeModal: () -> (),
	isOpen: () -> boolean,
}

local BattleLogUi = {}

local function applyRect(obj: GuiObject, r: BuildLayout.Rect): ()
	obj.Position = UDim2.fromOffset(r.x, r.y)
	obj.Size = UDim2.fromOffset(r.w, r.h)
end

local function addTextCap(label: TextLabel | TextButton, minSize: number, maxSize: number): ()
	local cap = Instance.new("UITextSizeConstraint")
	cap.MinTextSize = minSize
	cap.MaxTextSize = maxSize
	cap.Parent = label
end

function BattleLogUi.create(root: Frame, opts: BattleLogUiOpts): BattleLogUiHandle
	local player = Players.LocalPlayer
	local lastEntries: { any } = {}
	local feedbackMessage = ""

	local logButton = UiKit.button(root, "LogBtn", I18n.t(UiKit.getLocale(), "cta_log"))
	logButton.AnchorPoint = Vector2.zero
	logButton.ZIndex = 8
	UiKit.corner(logButton, 10)
	addTextCap(logButton, 9, 13)

	local unreadDot = Instance.new("Frame")
	unreadDot.Name = "UnreadDot"
	unreadDot.AnchorPoint = Vector2.new(1, 0)
	unreadDot.Position = UDim2.new(1, -3, 0, 3)
	unreadDot.Size = UDim2.fromOffset(10, 10)
	unreadDot.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.danger)
	unreadDot.BorderSizePixel = 0
	unreadDot.ZIndex = 9
	unreadDot.Visible = false
	unreadDot.Parent = logButton
	UiKit.corner(unreadDot, 10)
	UiKit.stroke(unreadDot, UiKit.color(VisualTheme.PALETTE.white), 1, 0)

	local function refreshUnreadDot(): ()
		if player == nil then
			unreadDot.Visible = false
			return
		end
		local unread = tonumber(player:GetAttribute("MuralhaUnreadLogs")) or 0
		unreadDot.Visible = unread > 0
	end

	refreshUnreadDot()
	if player ~= nil then
		player:GetAttributeChangedSignal("MuralhaUnreadLogs"):Connect(refreshUnreadDot)
	end

	local modal = UiKit.panel(root, "BattleLogModal")
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.fromOffset(420, 320)
	modal.ZIndex = 24
	modal.Visible = false
	UiKit.corner(modal, 14)
	UiKit.stroke(modal, UiKit.color(VisualTheme.PALETTE.amber), 2, 0.1)

	local titleLabel = UiKit.label(
		modal,
		"LogTitle",
		I18n.t(UiKit.getLocale(), "ui_log_title"),
		UiKit.color(VisualTheme.PALETTE.amberBright),
		Enum.Font.GothamBlack
	)
	titleLabel.Position = UDim2.fromOffset(14, 10)
	titleLabel.Size = UDim2.new(1, -110, 0, 26)
	titleLabel.TextScaled = true
	titleLabel.ZIndex = 25
	addTextCap(titleLabel, 11, 18)

	local closeBtn = UiKit.button(modal, "CloseLog", I18n.t(UiKit.getLocale(), "cta_close"))
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, -10, 0, 8)
	closeBtn.Size = UDim2.fromOffset(84, 44)
	closeBtn.ZIndex = 25
	addTextCap(closeBtn, 10, 13)

	local feedbackLabel = UiKit.label(
		modal,
		"FeedbackLabel",
		"",
		UiKit.color(VisualTheme.PALETTE.danger),
		Enum.Font.GothamBold
	)
	feedbackLabel.Position = UDim2.fromOffset(14, 38)
	feedbackLabel.Size = UDim2.new(1, -104, 0, 18)
	feedbackLabel.TextScaled = true
	feedbackLabel.ZIndex = 25
	addTextCap(feedbackLabel, 9, 12)

	local emptyLabel = UiKit.label(
		modal,
		"EmptyLabel",
		I18n.t(UiKit.getLocale(), "ui_log_empty"),
		UiKit.color(VisualTheme.PALETTE.stone),
		Enum.Font.GothamBold
	)
	emptyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	emptyLabel.Position = UDim2.fromScale(0.5, 0.55)
	emptyLabel.Size = UDim2.new(1, -40, 0, 40)
	emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
	emptyLabel.TextScaled = true
	emptyLabel.ZIndex = 25
	emptyLabel.Visible = false
	addTextCap(emptyLabel, 10, 15)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "LogScroll"
	scroll.Position = UDim2.fromOffset(12, 60)
	scroll.Size = UDim2.new(1, -24, 1, -72)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = UiKit.color(VisualTheme.PALETTE.amber)
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ZIndex = 25
	scroll.Parent = modal

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = scroll

	local function clearRows(): ()
		for _, child in ipairs(scroll:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function roleKeyFor(role: string): string
		if role == "defense" then
			return "ui_log_def"
		elseif role == "revenge" then
			return "ui_log_rev"
		end
		return "ui_log_atk"
	end

	local function signedNum(val: number, suffix: string): string
		if val >= 0 then
			return string.format("+%d%s", val, suffix)
		end
		return string.format("%d%s", val, suffix)
	end

	local function renderEntries(entries: { any }): ()
		clearRows()
		local loc = UiKit.getLocale()
		if #entries == 0 then
			emptyLabel.Text = I18n.t(loc, "ui_log_empty")
			emptyLabel.Visible = true
			return
		end
		emptyLabel.Visible = false

		for idx, entry in ipairs(entries) do
			if type(entry) == "table" and idx <= 12 then
				local row = Instance.new("Frame")
				row.Name = "LogRow_" .. tostring(idx)
				row.LayoutOrder = idx
				row.Size = UDim2.new(1, -6, 0, 54)
				row.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ironDark)
				row.BackgroundTransparency = 0.05
				row.BorderSizePixel = 0
				row.ZIndex = 25
				row.Parent = scroll
				UiKit.corner(row, 8)

				local role = tostring(entry.role or "attack")
				local playerWon = if role == "defense"
					then entry.winner == "defender"
					else entry.winner == "attacker"
				local rowStrokeColor = UiKit.color(
					if playerWon then VisualTheme.PALETTE.amber else VisualTheme.PALETTE.danger
				)
				UiKit.stroke(row, rowStrokeColor, 1, 0.35)

				local hasRevengeSlot = role == "defense"
				local buttonsReserveW = if hasRevengeSlot then 166 else 82

				local topLine = UiKit.label(
					row,
					"TopLine",
					string.format(
						"[%s] %s · %s",
						I18n.t(loc, roleKeyFor(role)),
						tostring(entry.rivalLabel or "Rival"),
						if playerWon then "V" else "D"
					),
					UiKit.color(VisualTheme.PALETTE.white),
					Enum.Font.GothamBlack
				)
				topLine.Position = UDim2.fromOffset(8, 6)
				topLine.Size = UDim2.new(1, -(buttonsReserveW + 12), 0, 20)
				topLine.TextScaled = true
				topLine.ZIndex = 26
				addTextCap(topLine, 9, 13)

				local gDelta = math.floor(tonumber(entry.goldDelta) or 0)
				local lDelta = math.floor(tonumber(entry.leagueDelta) or 0)
				local subLine = UiKit.label(
					row,
					"SubLine",
					string.format("%s · %s", signedNum(gDelta, "g"), signedNum(lDelta, " pts")),
					UiKit.color(VisualTheme.PALETTE.parchment),
					Enum.Font.GothamBold
				)
				subLine.Position = UDim2.fromOffset(8, 28)
				subLine.Size = UDim2.new(1, -(buttonsReserveW + 12), 0, 18)
				subLine.TextScaled = true
				subLine.ZIndex = 26
				addTextCap(subLine, 8, 12)

				local hasReplay = type(entry.replayWall) == "table"
					and type(entry.seed) == "number"
					and type(entry.resultHash) == "number"
				if hasReplay then
					local replayBtn = UiKit.button(row, "ReplayBtn", I18n.t(loc, "ui_replay_btn"))
					replayBtn.AnchorPoint = Vector2.new(1, 0.5)
					replayBtn.Position = UDim2.new(1, if hasRevengeSlot then -94 else -6, 0.5, 0)
					replayBtn.Size = UDim2.fromOffset(72, 44)
					replayBtn.ZIndex = 26
					addTextCap(replayBtn, 9, 12)
					replayBtn.MouseButton1Click:Connect(function()
						opts.ackReplay()
						opts.onReplay(entry)
					end)
				end

				if hasRevengeSlot then
					local canRevenge = entry.canRevenge == true
					local reason = tostring(entry.revengeReason or "")
					local btnLabel: string
					if canRevenge then
						btnLabel = I18n.t(loc, "cta_revenge")
					elseif reason == "bot" then
						btnLabel = I18n.t(loc, "ui_log_bot")
					elseif reason == "already_revenged" then
						btnLabel = I18n.t(loc, "ui_log_revenged")
					else
						local hours =
							math.max(1, math.ceil((tonumber(entry.cooldownLeftSec) or 3600) / 3600))
						btnLabel = I18n.t(loc, "ui_log_cd", hours)
					end

					local revBtn = UiKit.button(row, "RevengeBtn", btnLabel)
					revBtn.AnchorPoint = Vector2.new(1, 0.5)
					revBtn.Position = UDim2.new(1, -6, 0.5, 0)
					revBtn.Size = UDim2.fromOffset(82, 44)
					revBtn.ZIndex = 26
					addTextCap(revBtn, 9, 12)
					if canRevenge then
						UiKit.setSelected(revBtn, true)
					else
						revBtn.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.stoneDark)
						revBtn.TextColor3 = UiKit.color(VisualTheme.PALETTE.stone)
					end

					revBtn.MouseButton1Click:Connect(function()
						if canRevenge and type(entry.battleId) == "string" then
							opts.onRevenge(entry.battleId)
						elseif reason == "bot" then
							feedbackMessage = I18n.t(UiKit.getLocale(), "toast_revenge_bot")
							feedbackLabel.Text = feedbackMessage
						elseif reason == "already_revenged" then
							feedbackMessage = I18n.t(UiKit.getLocale(), "toast_revenge_used")
							feedbackLabel.Text = feedbackMessage
						else
							local hours = math.max(
								1,
								math.ceil((tonumber(entry.cooldownLeftSec) or 3600) / 3600)
							)
							feedbackMessage = I18n.t(UiKit.getLocale(), "toast_revenge_cd", hours)
							feedbackLabel.Text = feedbackMessage
						end
					end)
				end
			end
		end
	end

	local function closeModal(): ()
		modal.Visible = false
	end

	local function openAndLoad(): ()
		feedbackMessage = ""
		feedbackLabel.Text = ""
		modal.Visible = true
		local res = opts.fetchLogs()
		if type(res) == "table" and res.ok == true and type(res.entries) == "table" then
			lastEntries = res.entries
			unreadDot.Visible = false
			renderEntries(lastEntries)
		else
			lastEntries = {}
			renderEntries(lastEntries)
		end
	end

	logButton.MouseButton1Click:Connect(function()
		if modal.Visible then
			closeModal()
		else
			openAndLoad()
		end
	end)

	closeBtn.MouseButton1Click:Connect(closeModal)

	local function applyLayout(hudRects: BuildLayout.HudLayout): ()
		applyRect(logButton, hudRects.logBtn)
		local mw = math.min(440, math.max(280, hudRects.width - 24))
		local mh = math.min(340, math.max(220, hudRects.height - 28))
		modal.Size = UDim2.fromOffset(mw, mh)
	end

	local function refreshLocale(): ()
		local loc = UiKit.getLocale()
		logButton.Text = I18n.t(loc, "cta_log")
		titleLabel.Text = I18n.t(loc, "ui_log_title")
		closeBtn.Text = I18n.t(loc, "cta_close")
		emptyLabel.Text = I18n.t(loc, "ui_log_empty")
		if modal.Visible then
			renderEntries(lastEntries)
		end
	end

	local function setButtonsVisible(visible: boolean): ()
		logButton.Visible = visible
		if not visible then
			closeModal()
		end
	end

	local function isOpen(): boolean
		return modal.Visible
	end

	return {
		logButton = logButton,
		applyLayout = applyLayout,
		refreshLocale = refreshLocale,
		setButtonsVisible = setButtonsVisible,
		closeModal = closeModal,
		isOpen = isOpen,
	}
end

return BattleLogUi

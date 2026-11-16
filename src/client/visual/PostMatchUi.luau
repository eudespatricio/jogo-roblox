--!strict
-- Painel modular de Pos-Partida (GAP-020): Medidor de Dano por Armadilha (DPS/MVP/Eficiencia),
-- comparativo de setores (A / Portao P / B) e diagnostico acionavel de vazamento.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local I18n = require(Shared:WaitForChild("i18n"):WaitForChild("I18n"))
local VisualTheme = require(Shared:WaitForChild("visual"):WaitForChild("VisualTheme"))

local UiKit = require(script.Parent:WaitForChild("UiKit"))

export type PostMatchActionOpts = {
	replayButton: TextButton,
	closeButton: TextButton,
	onRevenge: (battleId: string) -> (),
}

export type PostMatchUiHandle = {
	section: Frame,
	render: (report: any, loc: string) -> (),
	setRevengeTarget: (battleId: string?) -> (),
	clear: () -> (),
	refreshLocale: (loc: string) -> (),
}

local PostMatchUi = {}

local function addTextConstraint(
	label: TextLabel | TextButton,
	minSize: number,
	maxSize: number
): ()
	local cap = Instance.new("UITextSizeConstraint")
	cap.MinTextSize = minSize
	cap.MaxTextSize = maxSize
	cap.Parent = label
end

function PostMatchUi.create(resultCard: Frame, actionOpts: PostMatchActionOpts?): PostMatchUiHandle
	local lastReport: any = nil
	local activeRevengeId: string? = nil

	local revengeButton =
		UiKit.button(resultCard, "ResultRevenge", I18n.t(UiKit.getLocale(), "cta_revenge"))
	revengeButton.AnchorPoint = Vector2.new(0.5, 0)
	revengeButton.Position = UDim2.new(0.5, 0, 1, -54)
	revengeButton.Size = UDim2.new(0.32, -8, 0, 44)
	revengeButton.Font = Enum.Font.GothamBlack
	revengeButton.ZIndex = 19
	revengeButton.Visible = false
	UiKit.corner(revengeButton, 10)
	UiKit.setSelected(revengeButton, true)
	addTextConstraint(revengeButton, 12, 16)

	local section = Instance.new("Frame")
	section.Name = "PostMatchSection"
	section.Position = UDim2.fromOffset(12, 100)
	section.Size = UDim2.new(1, -24, 1, -158)
	section.BackgroundTransparency = 1
	section.ZIndex = 19
	section.Visible = false
	section.Parent = resultCard

	local headerRow = Instance.new("Frame")
	headerRow.Name = "HeaderRow"
	headerRow.Size = UDim2.new(1, 0, 0, 18)
	headerRow.BackgroundTransparency = 1
	headerRow.ZIndex = 19
	headerRow.Parent = section

	local dpsTitle = UiKit.label(
		headerRow,
		"DpsHeader",
		"",
		UiKit.color(VisualTheme.PALETTE.amberBright),
		Enum.Font.GothamBlack
	)
	dpsTitle.Size = UDim2.new(0.52, -4, 1, 0)
	dpsTitle.TextScaled = true
	dpsTitle.ZIndex = 19
	addTextConstraint(dpsTitle, 10, 13)

	local sectorLabel = UiKit.label(
		headerRow,
		"SectorSummary",
		"",
		UiKit.color(VisualTheme.PALETTE.parchment),
		Enum.Font.GothamBold
	)
	sectorLabel.Position = UDim2.new(0.52, 0, 0, 0)
	sectorLabel.Size = UDim2.new(0.48, 0, 1, 0)
	sectorLabel.TextXAlignment = Enum.TextXAlignment.Right
	sectorLabel.TextScaled = true
	sectorLabel.ZIndex = 19
	addTextConstraint(sectorLabel, 10, 13)

	local trapsList = Instance.new("ScrollingFrame")
	trapsList.Name = "TrapsList"
	trapsList.Position = UDim2.fromOffset(0, 20)
	trapsList.Size = UDim2.new(1, 0, 1, -20)
	trapsList.BackgroundTransparency = 1
	trapsList.BorderSizePixel = 0
	trapsList.ScrollBarThickness = 4
	trapsList.ScrollBarImageColor3 = UiKit.color(VisualTheme.PALETTE.amber)
	trapsList.CanvasSize = UDim2.fromOffset(0, 0)
	trapsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	trapsList.ZIndex = 19
	trapsList.Parent = section

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 3)
	listLayout.Parent = trapsList

	local diagBanner = UiKit.panel(section, "DiagBanner", UiKit.color(VisualTheme.PALETTE.ironDark))
	diagBanner.AnchorPoint = Vector2.new(0, 1)
	diagBanner.Position = UDim2.new(0, 0, 1, 0)
	diagBanner.Size = UDim2.new(1, 0, 0, 26)
	diagBanner.BackgroundTransparency = 0.22
	diagBanner.ZIndex = 19
	diagBanner.Visible = false
	UiKit.corner(diagBanner, 6)
	UiKit.stroke(diagBanner, UiKit.color(VisualTheme.PALETTE.danger), 1.5, 0.1)

	local diagText = UiKit.label(
		diagBanner,
		"DiagText",
		"",
		UiKit.color(VisualTheme.PALETTE.parchment),
		Enum.Font.GothamBlack
	)
	diagText.Position = UDim2.fromOffset(8, 2)
	diagText.Size = UDim2.new(1, -16, 1, -4)
	diagText.TextScaled = true
	diagText.ZIndex = 20
	addTextConstraint(diagText, 11, 14)

	local function clearRows(): ()
		for _, child in ipairs(trapsList:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function setRevengeTarget(battleId: string?): ()
		if actionOpts ~= nil and type(battleId) == "string" and battleId ~= "" then
			activeRevengeId = battleId
			revengeButton.Text = I18n.t(UiKit.getLocale(), "cta_revenge")
			revengeButton.Visible = true
			actionOpts.replayButton.Size = UDim2.new(0.31, -10, 0, 44)
			actionOpts.closeButton.Size = UDim2.new(0.31, -10, 0, 44)
		else
			activeRevengeId = nil
			revengeButton.Visible = false
			if actionOpts ~= nil then
				actionOpts.replayButton.Size = UDim2.new(0.47, -14, 0, 44)
				actionOpts.closeButton.Size = UDim2.new(0.47, -14, 0, 44)
			end
		end
	end

	revengeButton.MouseButton1Click:Connect(function()
		if actionOpts ~= nil and activeRevengeId ~= nil then
			local targetBattleId = activeRevengeId
			setRevengeTarget(nil)
			actionOpts.onRevenge(targetBattleId)
		end
	end)

	local function clear(): ()
		lastReport = nil
		clearRows()
		diagBanner.Visible = false
		section.Visible = false
		setRevengeTarget(nil)
	end

	local function render(report: any, loc: string): ()
		if type(report) ~= "table" then
			clear()
			return
		end
		lastReport = report
		clearRows()

		dpsTitle.Text = I18n.t(loc, "ui_dps_header")
		local sec = if type(report.sectors) == "table" then report.sectors else nil
		if sec ~= nil and type(sec.sectorA) == "table" and type(sec.sectorB) == "table" then
			sectorLabel.Text = I18n.t(
				loc,
				"ui_diag_lane",
				math.floor(tonumber(sec.sectorA.leaks) or 0),
				math.floor(tonumber(sec.sharedGateLeaks) or 0),
				math.floor(tonumber(sec.sectorB.leaks) or 0)
			)
		else
			sectorLabel.Text = ""
		end

		local traps = if type(report.traps) == "table" then report.traps else {}
		for idx, entry in ipairs(traps) do
			if type(entry) == "table" and type(entry.trapId) == "string" then
				local row = Instance.new("Frame")
				row.Name = "TrapRow_" .. tostring(idx)
				row.LayoutOrder = idx
				row.Size = UDim2.new(1, -4, 0, 26)
				row.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ironDark)
				row.BackgroundTransparency = 0.20
				row.BorderSizePixel = 0
				row.ZIndex = 19
				row.Parent = trapsList
				UiKit.corner(row, 6)

				local sharePct = math.clamp(math.floor(tonumber(entry.sharePct) or 0), 0, 100)
				local barFill = Instance.new("Frame")
				barFill.Name = "BarFill"
				barFill.Size = UDim2.fromScale(math.clamp(sharePct / 100, 0.04, 1), 1)
				barFill.BackgroundColor3 = UiKit.color(
					if entry.isMvp == true
						then VisualTheme.PALETTE.amber
						else VisualTheme.PALETTE.teal
				)
				barFill.BackgroundTransparency = 0.72
				barFill.BorderSizePixel = 0
				barFill.ZIndex = 19
				barFill.Parent = row
				UiKit.corner(barFill, 6)

				local trapName = I18n.trapName(loc, entry.trapId)
				local level = math.max(1, math.floor(tonumber(entry.level) or 1))
				local nameLabel = UiKit.label(
					row,
					"TrapName",
					string.format("%s L%d", trapName, level),
					UiKit.color(VisualTheme.PALETTE.white),
					Enum.Font.GothamBlack
				)
				nameLabel.Position = UDim2.fromOffset(6, 2)
				nameLabel.Size = UDim2.new(0.40, -6, 1, -4)
				nameLabel.TextScaled = true
				nameLabel.ZIndex = 20
				addTextConstraint(nameLabel, 11, 15)

				local statsOffsetLeft = 0.41
				if entry.isMvp == true then
					local mvpPill = Instance.new("TextLabel")
					mvpPill.Name = "MvpPill"
					mvpPill.AnchorPoint = Vector2.new(0, 0.5)
					mvpPill.Position = UDim2.new(0.40, 2, 0.5, 0)
					mvpPill.Size = UDim2.fromOffset(36, 18)
					mvpPill.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.amberBright)
					mvpPill.BorderSizePixel = 0
					mvpPill.Text = I18n.t(loc, "ui_dps_mvp")
					mvpPill.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
					mvpPill.Font = Enum.Font.GothamBlack
					mvpPill.TextScaled = true
					mvpPill.ZIndex = 20
					mvpPill.Parent = row
					UiKit.corner(mvpPill, 4)
					addTextConstraint(mvpPill, 10, 13)
					statsOffsetLeft = 0.55
				end

				local dmgHp = math.max(0, math.floor(tonumber(entry.damageHp) or 0))
				local kills = math.max(0, math.floor(tonumber(entry.kills) or 0))
				local eff = math.max(0, math.floor(tonumber(entry.goldEfficiency) or 0))
				local effLabel = I18n.t(loc, "ui_dps_eff", eff)
				local statsLabel = UiKit.label(
					row,
					"TrapStats",
					string.format("%d (%d%%) · %dk · %s", dmgHp, sharePct, kills, effLabel),
					UiKit.color(VisualTheme.PALETTE.parchment),
					Enum.Font.GothamBold
				)
				statsLabel.Position = UDim2.new(statsOffsetLeft, 2, 0, 2)
				statsLabel.Size = UDim2.new(1 - statsOffsetLeft, -8, 1, -4)
				statsLabel.TextXAlignment = Enum.TextXAlignment.Right
				statsLabel.TextScaled = true
				statsLabel.ZIndex = 20
				addTextConstraint(statsLabel, 11, 15)
			end
		end

		local diag = report.diagnosis
		local hasDiag = type(diag) == "table" and type(diag.countermeasureCode) == "string"
		if hasDiag then
			local lane = math.clamp(math.floor(tonumber(diag.breachedLane) or 3), 1, 5)
			local titlePrefix = I18n.t(loc, "ui_diag_title")
			local advice = I18n.t(loc, diag.countermeasureCode, lane)
			diagText.Text = string.format("%s: %s", titlePrefix, advice)
			diagBanner.Visible = true
			trapsList.Size = UDim2.new(1, 0, 1, -44)
		else
			diagBanner.Visible = false
			trapsList.Size = UDim2.new(1, 0, 1, -18)
		end

		section.Visible = (#traps > 0) or hasDiag
	end

	local function refreshLocale(loc: string): ()
		revengeButton.Text = I18n.t(loc, "cta_revenge")
		if lastReport ~= nil and section.Visible then
			render(lastReport, loc)
		end
	end

	return {
		section = section,
		render = render,
		setRevengeTarget = setRevengeTarget,
		clear = clear,
		refreshLocale = refreshLocale,
	}
end

return PostMatchUi

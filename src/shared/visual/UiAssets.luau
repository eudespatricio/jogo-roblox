--!strict
-- Catalogo de assets 2D (Thumbnail, Icone e Backdrop de Loading/Transicao) publicados via Open Cloud.
-- Puro Luau: compativel com CLI (`luau-lsp --platform=standard`) e cliente/ReplicatedFirst.

local UiAssets = {}

UiAssets.TRANSITION_BG_ID = 97457052708184
UiAssets.GAME_THUMBNAIL_ID = 100504120619698
UiAssets.GAME_ICON_ID = 137751731423236

UiAssets.TRANSITION_BG = "rbxassetid://97457052708184"
UiAssets.GAME_THUMBNAIL = "rbxassetid://100504120619698"
UiAssets.GAME_ICON = "rbxassetid://137751731423236"

UiAssets.CARD_PORTRAIT_IDS = table.freeze({
	bastion_warden = 133937694573278,
	bastion_commander = 96886221147415,
	horde_brute = 79392072268903,
	horde_runner = 83193144259137,
	horde_shieldbearer = 79915542757244,
	boss_iron_ram_colossus = 113913292846816,
	boss_slag_juggernaut = 94243412311033,
	boss_rime_matriarch = 125140746083199,
	boss_powder_baron = 125874511220334,
	boss_rift_titan = 121124353409474,
})

UiAssets.CARD_PORTRAITS = table.freeze({
	bastion_warden = "rbxassetid://133937694573278",
	bastion_commander = "rbxassetid://96886221147415",
	horde_brute = "rbxassetid://79392072268903",
	horde_runner = "rbxassetid://83193144259137",
	horde_shieldbearer = "rbxassetid://79915542757244",
	boss_iron_ram_colossus = "rbxassetid://113913292846816",
	boss_slag_juggernaut = "rbxassetid://94243412311033",
	boss_rime_matriarch = "rbxassetid://125140746083199",
	boss_powder_baron = "rbxassetid://125874511220334",
	boss_rift_titan = "rbxassetid://121124353409474",
})

function UiAssets.portraitForCard(card: any): string
	if type(card) ~= "table" then
		return UiAssets.CARD_PORTRAITS.bastion_warden
	end

	local bossId = card.bossId
	if type(bossId) == "string" and bossId ~= "" then
		local bossKey = "boss_" .. bossId
		local bossAsset = (UiAssets.CARD_PORTRAITS :: { [string]: string })[bossKey]
		if type(bossAsset) == "string" then
			return bossAsset
		end
	end

	local role = tostring(card.role or "")
	local faction = tostring(card.faction or "")
	if role == "defender" or faction == "bastion" then
		local wallLvl = tonumber(card.wallLevel) or 1
		if wallLvl >= 3 or (card.isBot ~= true and card.side == "left") then
			return UiAssets.CARD_PORTRAITS.bastion_commander
		end
		return UiAssets.CARD_PORTRAITS.bastion_warden
	end

	local hasBrute = false
	local hasShield = false
	local hasRunner = false
	if type(card.unitClasses) == "table" then
		for _, cls in ipairs(card.unitClasses) do
			local lower = string.lower(tostring(cls))
			if string.find(lower, "brute", 1, true) ~= nil then
				hasBrute = true
			elseif string.find(lower, "shield", 1, true) ~= nil then
				hasShield = true
			elseif string.find(lower, "runner", 1, true) ~= nil then
				hasRunner = true
			end
		end
	end
	if hasBrute then
		return UiAssets.CARD_PORTRAITS.horde_brute
	elseif hasShield then
		return UiAssets.CARD_PORTRAITS.horde_shieldbearer
	elseif hasRunner then
		return UiAssets.CARD_PORTRAITS.horde_runner
	end
	return UiAssets.CARD_PORTRAITS.horde_brute
end

UiAssets.ENTRIES = table.freeze({
	transitionBg = table.freeze({
		id = UiAssets.TRANSITION_BG_ID,
		contentId = UiAssets.TRANSITION_BG,
		width = 1920,
		height = 1080,
	}),
	gameThumbnail = table.freeze({
		id = UiAssets.GAME_THUMBNAIL_ID,
		contentId = UiAssets.GAME_THUMBNAIL,
		width = 1920,
		height = 1080,
	}),
	gameIcon = table.freeze({
		id = UiAssets.GAME_ICON_ID,
		contentId = UiAssets.GAME_ICON,
		width = 512,
		height = 512,
	}),
})

return UiAssets

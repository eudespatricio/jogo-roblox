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

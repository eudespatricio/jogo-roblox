--!nonstrict
-- S8: iluminacao e atmosfera do diorama. Roda uma vez no cliente. Nao mexe em gameplay.
-- O projeto ja define ShadowMap; aqui so ajustamos cor/luz para o contraste ambar x verde-agua.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualTheme = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("VisualTheme")
)

local VisualSetup = {}

local applied = false

local function rgb(value: { number }): Color3
	return Color3.fromRGB(value[1], value[2], value[3])
end

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing ~= nil and existing.ClassName == className then
		return existing
	end
	if existing ~= nil then
		existing:Destroy()
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance
end

function VisualSetup.apply(): ()
	if applied then
		return
	end
	applied = true

	Lighting.Brightness = 2.15
	Lighting.ClockTime = 17.1
	Lighting.GeographicLatitude = 24
	Lighting.Ambient = rgb(VisualTheme.PALETTE.ironDark)
	Lighting.OutdoorAmbient = rgb(VisualTheme.PALETTE.stoneDark)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.ShadowSoftness = 0.35
	Lighting.GlobalShadows = true

	local atmosphere = ensure("Atmosphere", "MuralhaAtmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.08
	atmosphere.Color = rgb(VisualTheme.PALETTE.teal)
	atmosphere.Decay = rgb(VisualTheme.PALETTE.iron)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 1.6

	local colorCorrection = ensure("ColorCorrectionEffect", "MuralhaColor")
	colorCorrection.Brightness = 0.02
	colorCorrection.Contrast = 0.08
	colorCorrection.Saturation = 0.12
	colorCorrection.TintColor = Color3.fromRGB(255, 244, 224)

	local bloom = ensure("BloomEffect", "MuralhaBloom")
	bloom.Intensity = 0.42
	bloom.Size = 22
	bloom.Threshold = 1.15
end

return VisualSetup

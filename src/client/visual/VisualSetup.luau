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

	Lighting.Brightness = 3.3
	Lighting.ClockTime = 16.4
	Lighting.GeographicLatitude = 24
	Lighting.Ambient = rgb({ 120, 124, 132 })
	Lighting.OutdoorAmbient = rgb({ 165, 168, 175 })
	Lighting.EnvironmentDiffuseScale = 0.65
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.ShadowSoftness = 0.35
	Lighting.GlobalShadows = true

	local atmosphere = ensure("Atmosphere", "MuralhaAtmosphere")
	atmosphere.Density = 0.14
	atmosphere.Offset = 0.08
	atmosphere.Color = rgb(VisualTheme.PALETTE.teal)
	atmosphere.Decay = rgb(VisualTheme.PALETTE.iron)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 1.2

	local colorCorrection = ensure("ColorCorrectionEffect", "MuralhaColor")
	colorCorrection.Brightness = 0.12
	colorCorrection.Contrast = 0.06
	colorCorrection.Saturation = 0.18
	colorCorrection.TintColor = Color3.fromRGB(255, 244, 224)

	local bloom = ensure("BloomEffect", "MuralhaBloom")
	bloom.Intensity = 0.42
	bloom.Size = 22
	bloom.Threshold = 1.15
end

return VisualSetup

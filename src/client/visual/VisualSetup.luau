--!strict
-- S8: iluminacao, ceu e atmosfera do diorama. Roda uma vez no cliente. Nao mexe em gameplay.
-- Configura o chao continuo do vale (Baseplate LeafyGrass em Y=-0.20, Terrain colors) e
-- neblina dourada (MuralhaAtmosphere) com DepthOfField em miniatura.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local VisualSetup = {}

local applied = false

local function rgb(value: { number }): Color3
	return Color3.fromRGB(value[1], value[2], value[3])
end

local function ensureInstance(className: string, name: string): Instance
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

function VisualSetup.configureWorldFloor(): ()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate ~= nil and baseplate:IsA("BasePart") then
		local pos = baseplate.Position
		baseplate.Size =
			Vector3.new(math.max(baseplate.Size.X, 2048), 12, math.max(baseplate.Size.Z, 2048))
		baseplate.CFrame = CFrame.new(pos.X, -6.2, pos.Z)
		baseplate.Color = Color3.fromRGB(65, 88, 50)
		baseplate.Material = Enum.Material.LeafyGrass
		baseplate.Reflectance = 0
		baseplate.CanQuery = false
		baseplate.Locked = true
	end

	pcall(function()
		local terrain = Workspace.Terrain
		terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(74, 102, 56))
		terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(65, 88, 50))
		terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(118, 98, 74))
		terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(82, 86, 94))
	end)

	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("SpawnLocation") then
			local pos = child.Position
			child.CFrame = CFrame.new(pos.X, -12, pos.Z)
			child.Transparency = 1
			child.CanCollide = false
			child.CanQuery = false
		end
	end
end

function VisualSetup.apply(): ()
	if applied then
		return
	end
	applied = true

	VisualSetup.configureWorldFloor()

	Lighting.Brightness = 3.2
	Lighting.ClockTime = 16.4
	Lighting.GeographicLatitude = 24
	Lighting.Ambient = rgb({ 112, 120, 132 })
	Lighting.OutdoorAmbient = rgb({ 158, 166, 178 })
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.ShadowSoftness = 0.35
	Lighting.GlobalShadows = true

	local sky = ensureInstance("Sky", "MuraSky") :: Sky
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 8
	sky.StarCount = 1200

	local sunRays = ensureInstance("SunRaysEffect", "MuralhaSunRays") :: SunRaysEffect
	sunRays.Enabled = true
	sunRays.Intensity = 0.08
	sunRays.Spread = 0.45

	local atmosphere = ensureInstance("Atmosphere", "MuralhaAtmosphere") :: Atmosphere
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.16
	atmosphere.Color = Color3.fromRGB(208, 224, 212)
	atmosphere.Decay = Color3.fromRGB(84, 96, 102)
	atmosphere.Glare = 0.18
	atmosphere.Haze = 1.35

	local colorCorrection =
		ensureInstance("ColorCorrectionEffect", "MuralhaColor") :: ColorCorrectionEffect
	colorCorrection.Enabled = true
	colorCorrection.Brightness = 0.05
	colorCorrection.Contrast = 0.12
	colorCorrection.Saturation = 0.2
	colorCorrection.TintColor = Color3.fromRGB(255, 246, 232)

	local bloom = ensureInstance("BloomEffect", "MuralhaBloom") :: BloomEffect
	bloom.Enabled = true
	bloom.Intensity = 0.35
	bloom.Size = 18
	bloom.Threshold = 1.15

	local dof = ensureInstance("DepthOfFieldEffect", "MuralhaDOF") :: DepthOfFieldEffect
	dof.Enabled = true
	dof.FarIntensity = 0.22
	dof.FocusDistance = 58
	dof.InFocusRadius = 38
	dof.NearIntensity = 0.08
end

return VisualSetup

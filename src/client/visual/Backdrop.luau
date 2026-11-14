--!strict
-- Cenario de fundo continuo (vale verdejante, Estrada da Cidadela, picos de montanha,
-- rochas da Fenda e malhas BACKDROP_*). Puramente visual (Anchored, sem colisao/query/toque/sombra).
-- Chamado por ArenaVisual.build via pcall: Backdrop.build(arenaFolder, origin).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BackdropAssets = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("BackdropAssets")
)

type Placement = BackdropAssets.Placement

type HillDome = {
	name: string,
	shape: "ball" | "cylinder",
	cx: number,
	cz: number,
	rx: number,
	rz: number,
	top: number,
	color: Color3,
	material: Enum.Material,
}

local Backdrop = {}

local FOLDER_NAME = "Backdrop"
local TOPOGRAPHY_FOLDER = "ValleyTopography"
local LATE_WAIT_S = 90

local HILL_DOMES: { HillDome } = {
	-- Colina da Cidadela (oeste/noroeste apos o fim da estrada)
	{
		name = "Hill_CitadelSkirt",
		shape = "ball",
		cx = -152,
		cz = -78,
		rx = 32,
		rz = 30,
		top = 10.5,
		color = Color3.fromRGB(70, 96, 52),
		material = Enum.Material.LeafyGrass,
	},
	{
		name = "Hill_CitadelPlateau",
		shape = "cylinder",
		cx = -148,
		cz = -74,
		rx = 18,
		rz = 18,
		top = 10.2,
		color = Color3.fromRGB(74, 102, 56),
		material = Enum.Material.Grass,
	},
	-- Planalto alto a noroeste e oeste
	{
		name = "Hill_NWHigh",
		shape = "ball",
		cx = -175,
		cz = -125,
		rx = 48,
		rz = 42,
		top = 20.5,
		color = Color3.fromRGB(64, 88, 48),
		material = Enum.Material.LeafyGrass,
	},
	{
		name = "Hill_WestRidge",
		shape = "ball",
		cx = -178,
		cz = -22,
		rx = 42,
		rz = 38,
		top = 17.0,
		color = Color3.fromRGB(68, 94, 52),
		material = Enum.Material.LeafyGrass,
	},
	{
		name = "Hill_SWKnoll",
		shape = "ball",
		cx = -142,
		cz = 24,
		rx = 34,
		rz = 26,
		top = 11.5,
		color = Color3.fromRGB(72, 98, 54),
		material = Enum.Material.Grass,
	},
	-- Colinas da vila ao longo dos dois lados da estrada
	{
		name = "Hill_NorthVillage",
		shape = "ball",
		cx = -92,
		cz = -78,
		rx = 30,
		rz = 26,
		top = 7.6,
		color = Color3.fromRGB(72, 100, 56),
		material = Enum.Material.Grass,
	},
	{
		name = "Hill_NorthVillagePlateau",
		shape = "cylinder",
		cx = -90,
		cz = -76,
		rx = 15,
		rz = 15,
		top = 7.3,
		color = Color3.fromRGB(76, 104, 58),
		material = Enum.Material.Grass,
	},
	{
		name = "Hill_MidWest",
		shape = "ball",
		cx = -124,
		cz = -118,
		rx = 32,
		rz = 28,
		top = 13.0,
		color = Color3.fromRGB(66, 92, 50),
		material = Enum.Material.LeafyGrass,
	},
	{
		name = "Hill_WindmillKnoll",
		shape = "ball",
		cx = -110,
		cz = 14,
		rx = 30,
		rz = 24,
		top = 7.0,
		color = Color3.fromRGB(76, 102, 58),
		material = Enum.Material.Grass,
	},
	{
		name = "Hill_WindmillPlateau",
		shape = "cylinder",
		cx = -110,
		cz = 14,
		rx = 16,
		rz = 16,
		top = 6.7,
		color = Color3.fromRGB(80, 106, 60),
		material = Enum.Material.Grass,
	},
	{
		name = "Hill_WallBackKnoll",
		shape = "ball",
		cx = -72,
		cz = -54,
		rx = 20,
		rz = 18,
		top = 4.4,
		color = Color3.fromRGB(74, 100, 56),
		material = Enum.Material.LeafyGrass,
	},
	{
		name = "Hill_WallBackPlateau",
		shape = "cylinder",
		cx = -72,
		cz = -54,
		rx = 9,
		rz = 9,
		top = 4.2,
		color = Color3.fromRGB(76, 102, 58),
		material = Enum.Material.Grass,
	},
	{
		name = "Hill_WallSouthKnoll",
		shape = "ball",
		cx = -82,
		cz = 30,
		rx = 20,
		rz = 18,
		top = 4.8,
		color = Color3.fromRGB(72, 96, 54),
		material = Enum.Material.LeafyGrass,
	},
	-- Crista arborizada norte/direita (z <= -38)
	{
		name = "Hill_NorthWoodWest",
		shape = "ball",
		cx = -34,
		cz = -72,
		rx = 32,
		rz = 28,
		top = 9.8,
		color = Color3.fromRGB(68, 95, 52),
		material = Enum.Material.LeafyGrass,
	},
	{
		name = "Hill_NorthWoodCenter",
		shape = "ball",
		cx = 4,
		cz = -84,
		rx = 34,
		rz = 32,
		top = 12.6,
		color = Color3.fromRGB(64, 90, 48),
		material = Enum.Material.LeafyGrass,
	},
	{
		name = "Hill_NorthWoodEast",
		shape = "ball",
		cx = 42,
		cz = -78,
		rx = 30,
		rz = 28,
		top = 10.4,
		color = Color3.fromRGB(70, 96, 54),
		material = Enum.Material.Grass,
	},
	{
		name = "Hill_NorthWoodFar",
		shape = "ball",
		cx = -14,
		cz = -124,
		rx = 46,
		rz = 36,
		top = 19.2,
		color = Color3.fromRGB(62, 86, 46),
		material = Enum.Material.LeafyGrass,
	},
	{
		name = "Hill_NorthTowerPlateau",
		shape = "cylinder",
		cx = -18,
		cz = -62,
		rx = 12,
		rz = 12,
		top = 7.6,
		color = Color3.fromRGB(74, 100, 56),
		material = Enum.Material.Grass,
	},
	-- Borda sul/esquerda do vale (z >= 38)
	{
		name = "Hill_SouthLeftKnoll",
		shape = "ball",
		cx = -68,
		cz = 58,
		rx = 26,
		rz = 19,
		top = 6.2,
		color = Color3.fromRGB(70, 95, 52),
		material = Enum.Material.LeafyGrass,
	},
	{
		name = "Hill_SouthMidKnoll",
		shape = "ball",
		cx = -18,
		cz = 60,
		rx = 26,
		rz = 18,
		top = 5.2,
		color = Color3.fromRGB(68, 92, 50),
		material = Enum.Material.LeafyGrass,
	},
}

local function inert(part: BasePart): ()
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = color
	piece.Material = material
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	inert(piece)
	piece.Parent = parent
	return piece
end

local function makeBall(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local piece = makePart(parent, name, size, cframe, color, material)
	piece.Shape = Enum.PartType.Ball
	return piece
end

local function makeCylinder(
	parent: Instance,
	name: string,
	radius: number,
	height: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local piece = makePart(
		parent,
		name,
		Vector3.new(height, radius * 2, radius * 2),
		cframe * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	piece.Shape = Enum.PartType.Cylinder
	return piece
end

local function makeWedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Size = size
	wedge.CFrame = cframe
	wedge.Color = color
	wedge.Material = material
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	inert(wedge)
	wedge.Parent = parent
	return wedge
end

function Backdrop.groundHeightAt(localX: number, localZ: number): number
	local shoreY = BackdropAssets.SHORE_Y
	if localX >= -46 and math.abs(localZ) <= 34 then
		return shoreY
	end
	local best = shoreY
	for _, dome in ipairs(HILL_DOMES) do
		if dome.shape == "ball" then
			local ry = (dome.top - shoreY) * 1.45
			local cy = dome.top - ry
			local nx = (localX - dome.cx) / dome.rx
			local nz = (localZ - dome.cz) / dome.rz
			local u = nx * nx + nz * nz
			if u < 1 then
				local h = cy + ry * math.sqrt(1 - u)
				if h > best then
					best = h
				end
			end
		else
			local dx = localX - dome.cx
			local dz = localZ - dome.cz
			if dx * dx + dz * dz <= dome.rx * dome.rx then
				if dome.top > best then
					best = dome.top
				end
			end
		end
	end
	return best
end

local function buildHills(parent: Instance, origin: Vector3): ()
	local shoreY = BackdropAssets.SHORE_Y
	for _, dome in ipairs(HILL_DOMES) do
		if dome.shape == "ball" then
			local ry = (dome.top - shoreY) * 1.45
			local cy = dome.top - ry
			makeBall(
				parent,
				dome.name,
				Vector3.new(dome.rx * 2, ry * 2, dome.rz * 2),
				CFrame.new(origin + Vector3.new(dome.cx, cy, dome.cz)),
				dome.color,
				dome.material
			)
		else
			local bottomY = shoreY - 1.6
			local height = dome.top - bottomY
			local cy = (dome.top + bottomY) * 0.5
			makeCylinder(
				parent,
				dome.name,
				dome.rx,
				height,
				CFrame.new(origin + Vector3.new(dome.cx, cy, dome.cz)),
				dome.color,
				dome.material
			)
		end
	end
end

local function roadSurfaceY(localX: number, localZ: number): number
	local t = math.clamp((-34 - localX) / 11, 0, 1)
	local smooth = t * t * (3 - 2 * t)
	return 0.21 * (1 - smooth) + Backdrop.groundHeightAt(localX, localZ) * smooth
end

local function addRoadLantern(
	parent: Instance,
	origin: Vector3,
	index: number,
	localX: number,
	localZ: number,
	dirX: number,
	dirZ: number
): ()
	local baseY = Backdrop.groundHeightAt(localX, localZ) - 0.1
	local yaw = math.atan2(-dirX, -dirZ)
	local basePos = origin + Vector3.new(localX, baseY, localZ)

	makePart(
		parent,
		"RoadLanternPost_" .. tostring(index),
		Vector3.new(0.36, 3.6, 0.36),
		CFrame.new(basePos + Vector3.new(0, 1.8, 0)),
		Color3.fromRGB(88, 56, 30),
		Enum.Material.Wood
	)
	makePart(
		parent,
		"RoadLanternArm_" .. tostring(index),
		Vector3.new(0.22, 0.22, 1.05),
		CFrame.new(basePos + Vector3.new(0, 3.45, 0))
			* CFrame.Angles(0, yaw, 0)
			* CFrame.new(0, 0, -0.4),
		Color3.fromRGB(44, 48, 54),
		Enum.Material.Metal
	)
	local lampPos = (CFrame.new(basePos + Vector3.new(0, 3.1, 0)) * CFrame.Angles(0, yaw, 0))
		* Vector3.new(0, 0, -0.82)
	local bulb = makePart(
		parent,
		"RoadLanternBulb_" .. tostring(index),
		Vector3.new(0.62, 0.74, 0.62),
		CFrame.new(lampPos),
		Color3.fromRGB(255, 198, 96),
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 186, 86)
	light.Brightness = 0.68
	light.Range = 15
	light.Shadows = false
	light.Parent = bulb
end

local function buildCitadelRoad(parent: Instance, origin: Vector3): ()
	local waypoints = BackdropAssets.ROAD_WAYPOINTS
	local cobblePalette = {
		Color3.fromRGB(118, 112, 102),
		Color3.fromRGB(128, 121, 110),
		Color3.fromRGB(108, 103, 94),
	}
	local stepIndex = 0
	local lanternIndex = 0
	local nextLanternDist = 22
	local totalDist = 0

	for seg = 1, #waypoints - 1 do
		local a = waypoints[seg]
		local b = waypoints[seg + 1]
		local dx = b.x - a.x
		local dz = b.z - a.z
		local segLen = math.sqrt(dx * dx + dz * dz)
		local samples = math.max(2, math.ceil(segLen / 4.3))
		local dirX = dx / segLen
		local dirZ = dz / segLen
		local normX = -dirZ
		local normZ = dirX

		local startI = if seg == 1 then 0 else 1
		for i = startI, samples do
			local frac = i / samples
			local px = a.x + dx * frac
			local pz = a.z + dz * frac
			local py = roadSurfaceY(px, pz)
			stepIndex += 1

			makeCylinder(
				parent,
				"RoadShoulder_" .. tostring(stepIndex),
				5.3,
				0.26,
				CFrame.new(origin + Vector3.new(px, py - 0.08, pz)),
				Color3.fromRGB(112, 92, 68),
				Enum.Material.Ground
			)
			makeCylinder(
				parent,
				"RoadCobble_" .. tostring(stepIndex),
				3.25,
				0.30,
				CFrame.new(origin + Vector3.new(px, py - 0.05, pz)),
				cobblePalette[(stepIndex % #cobblePalette) + 1],
				Enum.Material.Cobblestone
			)
		end

		local segEndDist = totalDist + segLen
		while nextLanternDist <= segEndDist do
			local localDist = nextLanternDist - totalDist
			local frac = localDist / segLen
			local lx = a.x + dx * frac
			local lz = a.z + dz * frac
			if lx <= -41 then
				lanternIndex += 1
				local side = if lanternIndex % 2 == 1 then 1 else -1
				local offsetX = lx + normX * side * 6.0
				local offsetZ = lz + normZ * side * 6.0
				addRoadLantern(
					parent,
					origin,
					lanternIndex,
					offsetX,
					offsetZ,
					normX * side,
					normZ * side
				)
			end
			nextLanternDist += 15
		end
		totalDist = segEndDist
	end
end

local function buildMountains(parent: Instance, origin: Vector3): ()
	local shoreY = BackdropAssets.SHORE_Y
	local peaks = {
		{
			angleDeg = 148,
			dist = 215,
			width = 76,
			depth = 64,
			height = 42,
			mat = Enum.Material.Slate,
			shade = 1,
		},
		{
			angleDeg = 166,
			dist = 248,
			width = 92,
			depth = 78,
			height = 56,
			mat = Enum.Material.Rock,
			shade = 2,
		},
		{
			angleDeg = 184,
			dist = 228,
			width = 84,
			depth = 72,
			height = 48,
			mat = Enum.Material.Slate,
			shade = 3,
		},
		{
			angleDeg = 200,
			dist = 268,
			width = 104,
			depth = 86,
			height = 68,
			mat = Enum.Material.Rock,
			shade = 1,
		},
		{
			angleDeg = 216,
			dist = 236,
			width = 90,
			depth = 74,
			height = 54,
			mat = Enum.Material.Slate,
			shade = 2,
		},
		{
			angleDeg = 232,
			dist = 282,
			width = 110,
			depth = 92,
			height = 72,
			mat = Enum.Material.Rock,
			shade = 3,
		},
		{
			angleDeg = 248,
			dist = 242,
			width = 94,
			depth = 78,
			height = 58,
			mat = Enum.Material.Slate,
			shade = 1,
		},
		{
			angleDeg = 264,
			dist = 276,
			width = 106,
			depth = 88,
			height = 66,
			mat = Enum.Material.Rock,
			shade = 2,
		},
		{
			angleDeg = 280,
			dist = 232,
			width = 88,
			depth = 74,
			height = 52,
			mat = Enum.Material.Slate,
			shade = 3,
		},
		{
			angleDeg = 296,
			dist = 260,
			width = 98,
			depth = 82,
			height = 62,
			mat = Enum.Material.Rock,
			shade = 1,
		},
		{
			angleDeg = 314,
			dist = 224,
			width = 82,
			depth = 70,
			height = 48,
			mat = Enum.Material.Slate,
			shade = 2,
		},
		{
			angleDeg = 332,
			dist = 246,
			width = 86,
			depth = 72,
			height = 46,
			mat = Enum.Material.Rock,
			shade = 3,
		},
		{
			angleDeg = 348,
			dist = 212,
			width = 74,
			depth = 62,
			height = 40,
			mat = Enum.Material.Slate,
			shade = 1,
		},
	}
	local colors = {
		Color3.fromRGB(74, 82, 92),
		Color3.fromRGB(86, 92, 100),
		Color3.fromRGB(64, 72, 82),
	}

	for index, peak in ipairs(peaks) do
		local rad = math.rad(peak.angleDeg)
		local cx = math.cos(rad) * peak.dist
		local cz = math.sin(rad) * peak.dist
		local yaw = math.atan2(-cx, -cz)
		local cy = shoreY - 3.0 + peak.height * 0.5
		local halfZ = peak.depth * 0.25
		local color = colors[peak.shade]

		-- Dois wedges costas-com-costas formam uma crista triangular afiada de montanha
		makeWedge(
			parent,
			"MountainFront_" .. tostring(index),
			Vector3.new(peak.width, peak.height, peak.depth * 0.5),
			CFrame.new(origin + Vector3.new(cx, cy, cz))
				* CFrame.Angles(0, yaw, 0)
				* CFrame.new(0, 0, -halfZ),
			color,
			peak.mat
		)
		makeWedge(
			parent,
			"MountainBack_" .. tostring(index),
			Vector3.new(peak.width, peak.height, peak.depth * 0.5),
			CFrame.new(origin + Vector3.new(cx, cy, cz))
				* CFrame.Angles(0, yaw + math.pi, 0)
				* CFrame.new(0, 0, -halfZ),
			color,
			peak.mat
		)
		makeWedge(
			parent,
			"MountainShoulder_" .. tostring(index),
			Vector3.new(peak.width * 0.65, peak.height * 0.72, peak.depth * 0.45),
			CFrame.new(origin + Vector3.new(cx, cy - peak.height * 0.14, cz))
				* CFrame.Angles(0, yaw + math.rad(38), 0)
				* CFrame.new(peak.width * 0.24, 0, 0),
			colors[(peak.shade % #colors) + 1],
			peak.mat
		)
	end
end

local function buildRiftCrags(parent: Instance, origin: Vector3): ()
	local shoreY = BackdropAssets.SHORE_Y
	local scorchPads = {
		{ x = 49, z = 0, r = 13, h = 0.6 },
		{ x = 56, z = -16, r = 12, h = 0.7 },
		{ x = 58, z = 16, r = 11, h = 0.65 },
		{ x = 65, z = 0, r = 11, h = 0.8 },
	}
	for index, pad in ipairs(scorchPads) do
		makeCylinder(
			parent,
			"RiftScorchPad_" .. tostring(index),
			pad.r,
			pad.h + 1.4,
			CFrame.new(origin + Vector3.new(pad.x, shoreY + pad.h * 0.5 - 0.7, pad.z)),
			Color3.fromRGB(34, 36, 44),
			Enum.Material.Basalt
		)
	end

	local crags = {
		{ x = 42, z = -18, w = 5.5, h = 7.8, d = 5.0, yaw = 25, tilt = -14 },
		{ x = 46, z = 16, w = 5.2, h = 6.8, d = 4.8, yaw = -32, tilt = -12 },
		{ x = 51, z = -26, w = 6.4, h = 9.5, d = 5.8, yaw = 48, tilt = -16 },
		{ x = 53, z = -8, w = 6.0, h = 8.4, d = 5.4, yaw = 12, tilt = -18 },
		{ x = 54, z = 9, w = 5.8, h = 7.9, d = 5.2, yaw = -18, tilt = -15 },
		{ x = 52, z = 26, w = 6.2, h = 8.8, d = 5.6, yaw = -54, tilt = -14 },
		{ x = 62, z = -19, w = 7.2, h = 11.6, d = 6.6, yaw = 30, tilt = -12 },
		{ x = 64, z = 0, w = 7.8, h = 12.8, d = 7.2, yaw = 5, tilt = -15 },
		{ x = 63, z = 20, w = 7.0, h = 10.6, d = 6.4, yaw = -38, tilt = -12 },
		{ x = 71, z = -10, w = 6.8, h = 10.2, d = 6.0, yaw = 18, tilt = -10 },
		{ x = 70, z = 11, w = 6.6, h = 9.8, d = 6.0, yaw = -22, tilt = -10 },
	}
	for index, crag in ipairs(crags) do
		local color = if index % 2 == 0
			then Color3.fromRGB(22, 24, 32)
			else Color3.fromRGB(40, 44, 54)
		local mat = if index % 2 == 0 then Enum.Material.Slate else Enum.Material.Basalt
		makeWedge(
			parent,
			"RiftCrag_" .. tostring(index),
			Vector3.new(crag.w, crag.h, crag.d),
			CFrame.new(origin + Vector3.new(crag.x, shoreY + crag.h * 0.5 - 1.4, crag.z))
				* CFrame.Angles(0, math.rad(crag.yaw), math.rad(crag.tilt)),
			color,
			mat
		)
	end

	local crystals = {
		{ x = 44, z = -14, w = 1.2, h = 4.8, yaw = 22, tilt = 18, light = true },
		{ x = 47, z = 13, w = 1.1, h = 4.4, yaw = -28, tilt = 16, light = false },
		{ x = 55, z = -22, w = 1.4, h = 5.6, yaw = 42, tilt = 20, light = false },
		{ x = 56, z = -4, w = 1.5, h = 6.2, yaw = 8, tilt = 14, light = true },
		{ x = 57, z = 6, w = 1.3, h = 5.2, yaw = -14, tilt = -16, light = false },
		{ x = 66, z = -14, w = 1.7, h = 6.8, yaw = 32, tilt = 15, light = false },
		{ x = 67, z = 14, w = 1.6, h = 6.4, yaw = -36, tilt = -15, light = false },
	}
	for index, crystal in ipairs(crystals) do
		local color = if index % 2 == 0
			then Color3.fromRGB(45, 212, 191)
			else Color3.fromRGB(20, 184, 166)
		local spike = makeWedge(
			parent,
			"RiftCrystal_" .. tostring(index),
			Vector3.new(crystal.w, crystal.h, crystal.w),
			CFrame.new(origin + Vector3.new(crystal.x, shoreY + crystal.h * 0.5 - 0.8, crystal.z))
				* CFrame.Angles(0, math.rad(crystal.yaw), math.rad(crystal.tilt)),
			color,
			Enum.Material.Neon
		)
		if crystal.light then
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(20, 184, 166)
			glow.Brightness = 0.85
			glow.Range = 18
			glow.Shadows = false
			glow.Parent = spike
		end
	end
end

local function buildFoliageTufts(parent: Instance, origin: Vector3): ()
	local palette: { BrickColor } = {
		BrickColor.new("Olive"),
		BrickColor.new("Camo"),
		BrickColor.new("Earth green"),
	}
	local tufts = {
		{ x = -54, z = -30, r = 2.6, h = 1.6, tone = 1 },
		{ x = -66, z = -46, r = 2.8, h = 1.8, tone = 2 },
		{ x = -80, z = -60, r = 3.0, h = 1.9, tone = 3 },
		{ x = -96, z = -88, r = 3.2, h = 2.0, tone = 1 },
		{ x = -114, z = -70, r = 2.9, h = 1.8, tone = 2 },
		{ x = -134, z = -84, r = 3.4, h = 2.2, tone = 1 },
		{ x = -160, z = -56, r = 3.6, h = 2.4, tone = 3 },
		{ x = -156, z = -104, r = 3.5, h = 2.2, tone = 2 },
		{ x = -88, z = 10, r = 2.7, h = 1.7, tone = 1 },
		{ x = -124, z = 24, r = 3.1, h = 2.0, tone = 3 },
		{ x = -68, z = 22, r = 2.8, h = 1.8, tone = 2 },
		{ x = -38, z = -58, r = 2.8, h = 1.9, tone = 1 },
		{ x = -22, z = -74, r = 3.2, h = 2.1, tone = 2 },
		{ x = -4, z = -58, r = 2.9, h = 1.8, tone = 3 },
		{ x = 14, z = -66, r = 3.1, h = 2.0, tone = 1 },
		{ x = 28, z = -62, r = 2.8, h = 1.8, tone = 2 },
		{ x = -16, z = -102, r = 3.5, h = 2.2, tone = 3 },
		{ x = 18, z = -98, r = 3.3, h = 2.1, tone = 1 },
		{ x = -64, z = 52, r = 2.9, h = 1.8, tone = 2 },
		{ x = -26, z = 56, r = 2.7, h = 1.7, tone = 1 },
	}
	for index, tuft in ipairs(tufts) do
		local y = Backdrop.groundHeightAt(tuft.x, tuft.z)
		local mound = makeBall(
			parent,
			"FoliageTuft_" .. tostring(index),
			Vector3.new(tuft.r * 2, tuft.h * 2, tuft.r * 2),
			CFrame.new(origin + Vector3.new(tuft.x, y - tuft.h * 0.28, tuft.z)),
			Color3.fromRGB(70, 94, 55),
			Enum.Material.Grass
		)
		mound.BrickColor = palette[tuft.tone]
	end
end

function Backdrop.buildValleyTopography(backdrop: Folder, origin: Vector3): ()
	local existing = backdrop:FindFirstChild(TOPOGRAPHY_FOLDER)
	if existing ~= nil then
		existing:Destroy()
	end
	local topo = Instance.new("Folder")
	topo.Name = TOPOGRAPHY_FOLDER
	topo.Parent = backdrop

	buildHills(topo, origin)
	buildCitadelRoad(topo, origin)
	buildMountains(topo, origin)
	buildRiftCrags(topo, origin)
	buildFoliageTufts(topo, origin)
end

local function place(
	backdrop: Folder,
	source: Model,
	entry: Placement,
	index: number,
	origin: Vector3
): ()
	local clone = source:Clone()
	clone.Name = string.format("%s_%02d", source.Name, index)
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			inert(descendant)
		end
	end
	local _, size = clone:GetBoundingBox()
	if size.Y > 0 then
		clone:ScaleTo(clone:GetScale() * entry.height / size.Y)
	end
	local box, scaled = clone:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, scaled.Y / 2, 0)
	local groundY = Backdrop.groundHeightAt(entry.x, entry.z) - 0.15
	local target = origin + Vector3.new(entry.x, groundY, entry.z)
	-- frente do glb (+Z) olha a camera da arena, com leve variacao por entrada
	local cam = BackdropAssets.CAMERA_OFFSET
	local toCamera = (origin + Vector3.new(cam.x, cam.y, cam.z)) - target
	local yaw = math.atan2(toCamera.X, toCamera.Z) + math.rad(entry.yawJitter)
	clone:PivotTo(
		CFrame.new(target) * CFrame.Angles(0, yaw, 0) * CFrame.new(-bottom) * clone:GetPivot()
	)
	clone.Parent = backdrop
end

local function fill(backdrop: Folder, assets: Instance, origin: Vector3): boolean
	local pending = false
	for index, entry in ipairs(BackdropAssets.LAYOUT) do
		local name = string.format("%s_%02d", BackdropAssets.modelName(entry.key), index)
		if backdrop:FindFirstChild(name) ~= nil then
			continue
		end
		local source = assets:FindFirstChild(BackdropAssets.modelName(entry.key))
		if source ~= nil and source:IsA("Model") then
			place(backdrop, source, entry, index, origin)
		elseif BackdropAssets.assetId(entry.key) > 0 then
			pending = true
		end
	end
	return pending
end

function Backdrop.build(arenaFolder: Instance, origin: Vector3): ()
	local old = arenaFolder:FindFirstChild(FOLDER_NAME)
	if old ~= nil then
		old:Destroy()
	end

	local backdrop = Instance.new("Folder")
	backdrop.Name = FOLDER_NAME
	backdrop.Parent = arenaFolder
	Backdrop.buildValleyTopography(backdrop, origin)

	if BackdropAssets.anyPublished() then
		-- malhas chegam do servidor de forma assincrona: preenche o que ja existe e escuta o resto
		task.spawn(function()
			local assets = ReplicatedStorage:WaitForChild(BackdropAssets.FOLDER, LATE_WAIT_S)
			if assets == nil or not backdrop:IsDescendantOf(game) then
				return
			end
			if not fill(backdrop, assets, origin) then
				return
			end
			local connection: RBXScriptConnection
			connection = assets.ChildAdded:Connect(function(child: Instance)
				if not backdrop:IsDescendantOf(game) then
					connection:Disconnect()
					return
				end
				if string.sub(child.Name, 1, #BackdropAssets.PREFIX) == BackdropAssets.PREFIX then
					if not fill(backdrop, assets, origin) then
						connection:Disconnect()
					end
				end
			end)
			task.delay(LATE_WAIT_S, function()
				if connection.Connected then
					connection:Disconnect()
				end
			end)
		end)
	end

	local ambientModule = if script.Parent ~= nil
		then script.Parent:FindFirstChild("AmbientLife")
		else nil
	if ambientModule ~= nil and ambientModule:IsA("ModuleScript") then
		local ok, ambientLife = pcall(require, ambientModule)
		if
			ok
			and type(ambientLife) == "table"
			and type((ambientLife :: any).build) == "function"
		then
			pcall((ambientLife :: any).build, arenaFolder, origin, Backdrop.groundHeightAt)
		end
	end
end

return table.freeze(Backdrop)

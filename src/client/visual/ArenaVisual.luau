--!strict
-- S8/S8.2: diorama da arena 5x5 (<=150 partes). Ilha elevada (MoatShelf/IslandCliff/GrassTerrace),
-- 5 trilhas Lane_1..5 (topo Y=0.33) entre bermas de grama, 25 MuralhaCellTiles invisiveis
-- (CanQuery=true) com cantoneiras de slot, SelectionIndicator, gatehouse+portcullis+torres,
-- portal de obsidiana e 6 pinheiros low-poly. Client-side e cosmetico.

local IS_ROBLOX = type(game) == "userdata"
local cliRequire: any = require
local Mock: any = if IS_ROBLOX
	then nil
	else cliRequire("../../shared/visual/" .. "HeadlessRobloxMock")

local activeGame = if IS_ROBLOX then game else Mock.game :: typeof(game)
local ReplicatedStorage = activeGame:GetService("ReplicatedStorage")
local Players = activeGame:GetService("Players")
local TweenService = activeGame:GetService("TweenService")

local Instance = if IS_ROBLOX then Instance else Mock.Instance :: typeof(Instance)
local Vector3 = if IS_ROBLOX then Vector3 else Mock.Vector3 :: typeof(Vector3)
local Vector2 = if IS_ROBLOX then Vector2 else Mock.Vector2 :: typeof(Vector2)
local CFrame = if IS_ROBLOX then CFrame else Mock.CFrame :: typeof(CFrame)
local Color3 = if IS_ROBLOX then Color3 else Mock.Color3 :: typeof(Color3)
local ColorSequence = if IS_ROBLOX
	then ColorSequence
	else Mock.ColorSequence :: typeof(ColorSequence)
local ColorSequenceKeypoint = if IS_ROBLOX
	then ColorSequenceKeypoint
	else Mock.ColorSequenceKeypoint :: typeof(ColorSequenceKeypoint)
local NumberSequence = if IS_ROBLOX
	then NumberSequence
	else Mock.NumberSequence :: typeof(NumberSequence)
local NumberSequenceKeypoint = if IS_ROBLOX
	then NumberSequenceKeypoint
	else Mock.NumberSequenceKeypoint :: typeof(NumberSequenceKeypoint)
local NumberRange = if IS_ROBLOX then NumberRange else Mock.NumberRange :: typeof(NumberRange)
local TweenInfo = if IS_ROBLOX then TweenInfo else Mock.TweenInfo :: typeof(TweenInfo)
local Enum = if IS_ROBLOX then Enum else Mock.Enum :: typeof(Enum)
local UDim = if IS_ROBLOX then UDim else Mock.UDim :: typeof(UDim)
local UDim2 = if IS_ROBLOX then UDim2 else Mock.UDim2 :: typeof(UDim2)
local task = if IS_ROBLOX then task else Mock.task :: typeof(task)

local VisualTheme = if IS_ROBLOX
	then require(
		game:GetService("ReplicatedStorage")
			:WaitForChild("Shared")
			:WaitForChild("visual")
			:WaitForChild("VisualTheme")
	)
	else Mock.shared("VisualTheme") :: any
local GridLayout = if IS_ROBLOX
	then require(
		game:GetService("ReplicatedStorage")
			:WaitForChild("Shared")
			:WaitForChild("build")
			:WaitForChild("GridLayout")
	)
	else cliRequire("../../shared/build/" .. "GridLayout") :: any
local WallAssets = if IS_ROBLOX
	then require(
		game:GetService("ReplicatedStorage")
			:WaitForChild("Shared")
			:WaitForChild("visual")
			:WaitForChild("WallAssets")
	)
	else Mock.shared("WallAssets") :: any
local MeshAssets = if IS_ROBLOX
	then require(
		game:GetService("ReplicatedStorage")
			:WaitForChild("Shared")
			:WaitForChild("visual")
			:WaitForChild("MeshAssets")
	)
	else Mock.shared("MeshAssets") :: any
local PortalThemes = if IS_ROBLOX
	then require(
		game:GetService("ReplicatedStorage")
			:WaitForChild("Shared")
			:WaitForChild("visual")
			:WaitForChild("PortalThemes")
	)
	else Mock.shared("PortalThemes") :: any

local ArenaVisual = {}

export type BuildOptions = {
	dropIn: boolean?,
	wallTier: number?, -- liga do dono da muralha; nil = atributo MuralhaWallTier do LocalPlayer
	portalTheme: string?,
}

type PortalThemeSpec = { [string]: any }

local OBSIDIAN_DARK = Color3.fromRGB(22, 24, 32)
local PORTAL_TARGET_HEIGHT = 15.2
local TERRACE_CENTER_X = 5
-- Lanes: terra batida/pedra gasta quente (lado defensor); bermas de grama musgo.
local LANE_TOP_Y = 0.33
local LANE_VERGE = 1.8
local LANE_EARTH = Color3.fromRGB(132, 112, 88)
local VERGE_GRASS = Color3.fromRGB(78, 104, 58)

local function rgb(value: { number }): Color3
	return Color3.fromRGB(value[1], value[2], value[3])
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.CFrame = cframe
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Color = color
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function cylinder(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local piece = part(parent, name, size, cframe, color, material)
	piece.Shape = Enum.PartType.Cylinder
	-- Cylinder do Roblox tem eixo em X; girar em Z deixa o eixo em Y.
	piece.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	return piece
end

local function neon(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3
): Part
	return part(parent, name, size, cframe, color, Enum.Material.Neon)
end

local function banner(
	parent: Instance,
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3
): ()
	part(
		parent,
		name .. "_Pole",
		Vector3.new(0.22, size.Y + 0.6, 0.22),
		CFrame.new(position + Vector3.new(0, size.Y * 0.5, 0)),
		rgb(VisualTheme.PALETTE.woodDark),
		Enum.Material.Wood
	)
	part(
		parent,
		name .. "_Cloth",
		size,
		CFrame.new(position + Vector3.new(0, size.Y * 0.5, 0)),
		color,
		Enum.Material.Fabric
	)
end

local function torch(parent: Instance, name: string, position: Vector3, color: Color3): ()
	part(
		parent,
		name .. "_Post",
		Vector3.new(0.3, 3.2, 0.3),
		CFrame.new(position + Vector3.new(0, 1.6, 0)),
		rgb(VisualTheme.PALETTE.woodDark),
		Enum.Material.Wood
	)
	local flame = neon(
		parent,
		name .. "_Flame",
		Vector3.new(0.7, 1.0, 0.7),
		CFrame.new(position + Vector3.new(0, 3.5, 0)),
		color
	)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 0.85
	light.Range = 16
	light.Shadows = false
	light.Parent = flame
end

local function setPropSlot(instance: Instance, propSlot: string?): ()
	if propSlot ~= nil then
		instance:SetAttribute("PropSlot", propSlot)
	end
end

local function rock(
	parent: Instance,
	name: string,
	position: Vector3,
	scale: number,
	propSlot: string?
): ()
	local piece = part(
		parent,
		name,
		Vector3.new(scale * 2.2, scale * 1.4, scale * 1.8),
		CFrame.new(position) * CFrame.Angles(0, math.rad((scale * 47) % 360), math.rad(8)),
		rgb(VisualTheme.PALETTE.stoneDark),
		Enum.Material.Slate
	)
	piece.Shape = Enum.PartType.Ball
	setPropSlot(piece, propSlot)
end

local function brazier(parent: Instance, name: string, position: Vector3, propSlot: string?): ()
	local ped = part(
		parent,
		name .. "_Pedestal",
		Vector3.new(1.4, 1.2, 1.4),
		CFrame.new(position + Vector3.new(0, 0.6, 0)),
		rgb(VisualTheme.PALETTE.stoneDark),
		Enum.Material.Slate
	)
	setPropSlot(ped, propSlot)
	local bowl = cylinder(
		parent,
		name .. "_Bowl",
		Vector3.new(0.65, 1.9, 1.9),
		CFrame.new(position + Vector3.new(0, 1.45, 0)),
		rgb(VisualTheme.PALETTE.iron),
		Enum.Material.Metal
	)
	setPropSlot(bowl, propSlot)
	local ember = neon(
		parent,
		name .. "_Ember",
		Vector3.new(1.1, 0.55, 1.1),
		CFrame.new(position + Vector3.new(0, 1.85, 0)),
		rgb(VisualTheme.PALETTE.amberBright)
	)
	ember.Shape = Enum.PartType.Ball
	setPropSlot(ember, propSlot)
	local light = Instance.new("PointLight")
	light.Color = rgb(VisualTheme.PALETTE.amber)
	light.Brightness = 0.75
	light.Range = 14
	light.Shadows = false
	light.Parent = ember
end

local function tealPylon(parent: Instance, name: string, position: Vector3, propSlot: string?): ()
	local shaft = cylinder(
		parent,
		name .. "_Shaft",
		Vector3.new(3.8, 1.25, 1.25),
		CFrame.new(position + Vector3.new(0, 1.9, 0)),
		OBSIDIAN_DARK,
		Enum.Material.Slate
	)
	setPropSlot(shaft, propSlot)
	local cap = neon(
		parent,
		name .. "_Rune",
		Vector3.new(0.85, 0.85, 0.85),
		CFrame.new(position + Vector3.new(0, 4.2, 0)) * CFrame.Angles(0, math.rad(45), 0),
		rgb(VisualTheme.PALETTE.teal)
	)
	setPropSlot(cap, propSlot)
	local light = Instance.new("PointLight")
	light.Color = rgb(VisualTheme.PALETTE.teal)
	light.Brightness = 0.7
	light.Range = 14
	light.Shadows = false
	light.Parent = cap
end

local function pineTree(
	parent: Instance,
	name: string,
	position: Vector3,
	scale: number,
	propSlot: string?
): ()
	local trunk = cylinder(
		parent,
		name .. "_Trunk",
		Vector3.new(2.2 * scale, 0.78 * scale, 0.78 * scale),
		CFrame.new(position + Vector3.new(0, 1.1 * scale, 0)),
		rgb(VisualTheme.PALETTE.woodDark),
		Enum.Material.Wood
	)
	setPropSlot(trunk, propSlot)
	local foliageColors = {
		Color3.fromRGB(48, 82, 46),
		Color3.fromRGB(58, 96, 54),
		Color3.fromRGB(70, 108, 62),
	}
	local specs = {
		{ w = 3.6, h = 2.3, y = 2.6, dx = 0, dz = 0 },
		{ w = 2.9, h = 2.0, y = 3.9, dx = 0.25, dz = -0.18 },
		{ w = 2.1, h = 1.7, y = 5.0, dx = -0.18, dz = 0.2 },
	}
	for tier, spec in ipairs(specs) do
		local crown = part(
			parent,
			name .. "_Crown" .. tostring(tier),
			Vector3.new(spec.w * scale, spec.h * scale, spec.w * scale),
			CFrame.new(position + Vector3.new(spec.dx * scale, spec.y * scale, spec.dz * scale)),
			foliageColors[tier],
			Enum.Material.LeafyGrass
		)
		crown.Shape = Enum.PartType.Ball
		setPropSlot(crown, propSlot)
	end
end

local function buildIsland(folder: Folder, origin: Vector3): ()
	part(
		folder,
		"ValleyBlendApron",
		Vector3.new(96, 0.24, 70),
		CFrame.new(origin + Vector3.new(TERRACE_CENTER_X, -0.14, 0)),
		Color3.fromRGB(65, 88, 50),
		Enum.Material.LeafyGrass
	)
	local foundation = part(
		folder,
		"BastionFoundation",
		Vector3.new(84, 0.34, 58),
		CFrame.new(origin + Vector3.new(TERRACE_CENTER_X, -0.04, 0)),
		Color3.fromRGB(108, 102, 92),
		Enum.Material.Cobblestone
	)
	foundation.CanCollide = true

	local grass = part(
		folder,
		"GrassTerrace",
		Vector3.new(80, 0.4, 54),
		CFrame.new(origin + Vector3.new(TERRACE_CENTER_X, 0, 0)),
		rgb(VisualTheme.PALETTE.grass),
		Enum.Material.Grass
	)
	grass.CanCollide = true

	local courtyard = part(
		folder,
		"CourtyardFrame",
		Vector3.new(54, 0.26, 44.4),
		CFrame.new(origin + Vector3.new(0, 0.16, 0)),
		rgb(VisualTheme.PALETTE.stoneDark),
		Enum.Material.Slate
	)
	courtyard.CanQuery = true
	-- 5 trilhas reais (linha = lane) correndo em X do portal (+X) ate a muralha (-X), topo em
	-- Y = 0.33 (TrapKit floorTopY / HordeKit spawn). Separadas por 6 bermas de grama 0.25 mais
	-- altas: a lane le como caminho rebaixado/afundado, nao como xadrez. Substitui CourtyardFloor.
	local laneWidth = GridLayout.CELL_SIZE - LANE_VERGE
	for row = 1, GridLayout.HEIGHT do
		local _, _, z = GridLayout.cellPosition(row, 1)
		local lane = part(
			folder,
			"Lane_" .. tostring(row),
			Vector3.new(42, 0.3, laneWidth),
			CFrame.new(origin + Vector3.new(0, LANE_TOP_Y - 0.15, z or 0)),
			LANE_EARTH,
			Enum.Material.Cobblestone
		)
		lane.CanCollide = true
		lane.CanQuery = true
	end
	local halfSpan = GridLayout.HEIGHT * GridLayout.CELL_SIZE * 0.5
	for sep = 0, GridLayout.HEIGHT do
		local z = (sep - GridLayout.HEIGHT * 0.5) * GridLayout.CELL_SIZE
		local width = LANE_VERGE
		if sep == 0 or sep == GridLayout.HEIGHT then
			-- Bermas externas vao da borda da lane externa ate o meio-fio (|z| = 21.0).
			local inner = halfSpan - LANE_VERGE * 0.5
			width = 21.0 - inner
			z = math.sign(z) * (inner + width * 0.5)
		end
		local verge = part(
			folder,
			"LaneVerge_" .. tostring(sep),
			Vector3.new(42, 0.5, width),
			CFrame.new(origin + Vector3.new(0, LANE_TOP_Y, z)), -- topo 0.58 (+0.25 sobre a lane)
			VERGE_GRASS,
			Enum.Material.Grass
		)
		verge.CanCollide = true
		verge.CanQuery = true
	end

	part(
		folder,
		"CurbNorth",
		Vector3.new(42.8, 0.36, 0.8),
		CFrame.new(origin + Vector3.new(0, 0.35, -21.4)),
		rgb(VisualTheme.PALETTE.stoneDark),
		Enum.Material.Slate
	)
	part(
		folder,
		"CurbSouth",
		Vector3.new(42.8, 0.36, 0.8),
		CFrame.new(origin + Vector3.new(0, 0.35, 21.4)),
		rgb(VisualTheme.PALETTE.stoneDark),
		Enum.Material.Slate
	)
	part(
		folder,
		"CurbWest",
		Vector3.new(0.8, 0.36, 43.6),
		CFrame.new(origin + Vector3.new(-21.4, 0.35, 0)),
		rgb(VisualTheme.PALETTE.ironDark),
		Enum.Material.Metal
	)
	part(
		folder,
		"CurbEast",
		Vector3.new(0.8, 0.36, 43.6),
		CFrame.new(origin + Vector3.new(21.4, 0.14, 0)),
		rgb(VisualTheme.PALETTE.stoneDark),
		Enum.Material.Slate
	)
end

local function fanLaneColor(theme: PortalThemeSpec): Color3
	return LANE_EARTH:Lerp(rgb(theme.apronColor), 0.65)
end

local function makeSegmentPart(
	parent: Instance,
	name: string,
	pA: Vector3,
	pB: Vector3,
	width: number,
	thickness: number,
	padLength: number,
	color: Color3,
	material: Enum.Material
): Part
	local delta = pB - pA
	local mid = (pA + pB) * 0.5
	local cf = CFrame.lookAt(mid, pB)
	local piece = part(
		parent,
		name,
		Vector3.new(width, thickness, delta.Magnitude + padLength),
		cf,
		color,
		material
	)
	piece.CanCollide = true
	piece.CanQuery = true
	return piece
end

-- Leque de abordagem (X = +36.8 -> +21.0): dais do portal + 5x2 segmentos de trilha + 6 bermas (17 partes).
local function buildPortalManifold(folder: Folder, origin: Vector3, theme: PortalThemeSpec): ()
	local manifold = Instance.new("Folder")
	manifold.Name = "PortalManifold"
	manifold.Parent = folder

	local apron = part(
		manifold,
		"PortalApron",
		Vector3.new(8.5, 0.7, 16.5),
		CFrame.new(origin + Vector3.new(PortalThemes.PORTAL_X, -0.04, 0)),
		rgb(theme.framePrimary),
		Enum.Material.Slate
	)
	apron.CanCollide = true
	apron.CanQuery = true

	local laneColor = fanLaneColor(theme)
	for row = 1, GridLayout.HEIGHT do
		local x0, z0 = PortalThemes.sampleFanPath(row, 0)
		local x1, z1 = PortalThemes.sampleFanPath(row, 0.5)
		local _, z2 = PortalThemes.sampleFanPath(row, 1.0)
		local x2 = 21.0

		local stagger = math.abs(row - 3) * 0.002
		local y1 = LANE_TOP_Y - 0.14 - stagger
		local y2 = LANE_TOP_Y - 0.142 - stagger

		makeSegmentPart(
			manifold,
			string.format("FanLane_%d_1", row),
			origin + Vector3.new(x0, y1, z0),
			origin + Vector3.new(x1, y1, z1),
			2.4,
			0.28,
			0.8,
			laneColor,
			Enum.Material.Cobblestone
		)

		local dx2 = math.abs(x2 - x1)
		local dz2 = math.abs(z2 - z1)
		local cos2 = dx2 / math.max(0.01, math.sqrt(dx2 * dx2 + dz2 * dz2))
		makeSegmentPart(
			manifold,
			string.format("FanLane_%d_2", row),
			origin + Vector3.new(x1, y2, z1),
			origin + Vector3.new(x2, y2, z2),
			6.1 * cos2,
			0.28,
			0.5,
			laneColor,
			Enum.Material.Cobblestone
		)
	end

	-- 6 bermas de grama (topo Y = 0.58) moldando o leque ate as LaneVerge_0..5 da arena.
	for sep = 0, GridLayout.HEIGHT do
		if sep == 0 or sep == GridLayout.HEIGHT then
			local side = if sep == 0 then -1 else 1
			makeSegmentPart(
				manifold,
				"FanVerge_" .. tostring(sep),
				origin + Vector3.new(33.8, LANE_TOP_Y, side * 6.4),
				origin + Vector3.new(21.0, LANE_TOP_Y, side * 20.05),
				2.4,
				0.5,
				0.6,
				VERGE_GRASS,
				Enum.Material.Grass
			)
		else
			local uEast = 0.68
			local sEast = uEast * uEast * (3 - 2 * uEast)
			local xEast = PortalThemes.THROAT_X
				+ (PortalThemes.ENTRY_X - PortalThemes.THROAT_X) * uEast
			local zEast = (sep - 2.5) * (0.95 + (8.0 - 0.95) * sEast)
			local zWest = (sep - 2.5) * 8.0
			makeSegmentPart(
				manifold,
				"FanVerge_" .. tostring(sep),
				origin + Vector3.new(xEast, LANE_TOP_Y, zEast),
				origin + Vector3.new(21.0, LANE_TOP_Y, zWest),
				1.65,
				0.5,
				0.5,
				VERGE_GRASS,
				Enum.Material.Grass
			)
		end
	end
end

local function buildWallAndGatehouse(folder: Folder, origin: Vector3): ()
	local wallX = GridLayout.WALL_X
	for side = -1, 1, 2 do
		local tag = if side == -1 then "L" else "R"
		local wingZ = side * 13.5
		part(
			folder,
			"WallPlinth" .. tag,
			Vector3.new(3.2, 2.0, 15),
			CFrame.new(origin + Vector3.new(wallX, 1.0, wingZ)),
			rgb(VisualTheme.PALETTE.stoneDark),
			Enum.Material.Slate
		)
		part(
			folder,
			"WallBody" .. tag,
			Vector3.new(2.4, 6.0, 15),
			CFrame.new(origin + Vector3.new(wallX, 5.0, wingZ)),
			rgb(VisualTheme.PALETTE.wood),
			Enum.Material.WoodPlanks
		)
		part(
			folder,
			"WallBand" .. tag,
			Vector3.new(2.7, 0.4, 15.2),
			CFrame.new(origin + Vector3.new(wallX, 4.8, wingZ)),
			rgb(VisualTheme.PALETTE.iron),
			Enum.Material.Metal
		)
		part(
			folder,
			"WallParapet" .. tag,
			Vector3.new(2.8, 0.8, 15.2),
			CFrame.new(origin + Vector3.new(wallX, 8.4, wingZ)),
			rgb(VisualTheme.PALETTE.stone),
			Enum.Material.Slate
		)
		part(
			folder,
			"GatePier" .. tag,
			Vector3.new(3.6, 9.0, 2.2),
			CFrame.new(origin + Vector3.new(wallX, 4.5, side * 4.6)),
			rgb(VisualTheme.PALETTE.stoneDark),
			Enum.Material.Slate
		)
	end

	part(
		folder,
		"GatehouseUpper",
		Vector3.new(3.6, 2.8, 11.4),
		CFrame.new(origin + Vector3.new(wallX, 7.6, 0)),
		rgb(VisualTheme.PALETTE.wood),
		Enum.Material.WoodPlanks
	)
	part(
		folder,
		"GatehouseCap",
		Vector3.new(4.0, 0.8, 12.0),
		CFrame.new(origin + Vector3.new(wallX, 9.4, 0)),
		rgb(VisualTheme.PALETTE.stone),
		Enum.Material.Slate
	)
	part(
		folder,
		"Gate",
		Vector3.new(1.2, 6.0, 7.0),
		CFrame.new(origin + Vector3.new(wallX - 0.6, 3.2, 0)),
		rgb(VisualTheme.PALETTE.woodDark),
		Enum.Material.WoodPlanks
	)
	part(
		folder,
		"PortcullisBar",
		Vector3.new(0.35, 0.4, 6.8),
		CFrame.new(origin + Vector3.new(wallX + 0.85, 3.1, 0)),
		rgb(VisualTheme.PALETTE.ironDark),
		Enum.Material.Metal
	)
	for picket = -2, 2 do
		part(
			folder,
			"PortcullisPicket_" .. tostring(picket + 3),
			Vector3.new(0.28, 3.6, 0.28),
			CFrame.new(origin + Vector3.new(wallX + 0.85, 4.4, picket * 1.2)),
			rgb(VisualTheme.PALETTE.ironDark),
			Enum.Material.Metal
		)
	end

	for tower = -1, 1, 2 do
		local z = tower * 22
		part(
			folder,
			"TowerBase_" .. tostring(tower),
			Vector3.new(5.2, 2.4, 5.2),
			CFrame.new(origin + Vector3.new(wallX, 1.2, z)),
			rgb(VisualTheme.PALETTE.stoneDark),
			Enum.Material.Slate
		)
		part(
			folder,
			"TowerBody_" .. tostring(tower),
			Vector3.new(4.4, 7.2, 4.4),
			CFrame.new(origin + Vector3.new(wallX, 6.0, z)),
			rgb(VisualTheme.PALETTE.stone),
			Enum.Material.Slate
		)
		part(
			folder,
			"TowerHoarding_" .. tostring(tower),
			Vector3.new(5.2, 2.4, 5.2),
			CFrame.new(origin + Vector3.new(wallX, 10.6, z)),
			rgb(VisualTheme.PALETTE.wood),
			Enum.Material.WoodPlanks
		)
		part(
			folder,
			"TowerRoof_" .. tostring(tower),
			Vector3.new(5.8, 1.2, 5.8),
			CFrame.new(origin + Vector3.new(wallX, 12.4, z)),
			rgb(VisualTheme.PALETTE.ironDark),
			Enum.Material.Metal
		)
		part(
			folder,
			"TowerSpire_" .. tostring(tower),
			Vector3.new(2.2, 2.0, 2.2),
			CFrame.new(origin + Vector3.new(wallX, 13.8, z)) * CFrame.Angles(0, math.rad(45), 0),
			rgb(VisualTheme.PALETTE.iron),
			Enum.Material.Metal
		)
		banner(
			folder,
			"Banner_" .. tostring(tower),
			origin + Vector3.new(wallX + 2.7, 6.4, z),
			Vector3.new(0.12, 3.4, 2.0),
			rgb(VisualTheme.PALETTE.amber)
		)
	end

	local merlonZs = { -17.5, -13.5, -9.5, 9.5, 13.5, 17.5 }
	for index, mz in ipairs(merlonZs) do
		part(
			folder,
			"Merlon_" .. tostring(index),
			Vector3.new(2.2, 1.1, 2.0),
			CFrame.new(origin + Vector3.new(wallX, 9.35, mz)),
			rgb(VisualTheme.PALETTE.stoneDark),
			Enum.Material.Slate
		)
	end

	torch(
		folder,
		"TorchGateL",
		origin + Vector3.new(wallX + 2.1, 0.2, -5.6),
		Color3.fromRGB(255, 178, 80)
	)
	torch(
		folder,
		"TorchGateR",
		origin + Vector3.new(wallX + 2.1, 0.2, 5.6),
		Color3.fromRGB(255, 178, 80)
	)
end

local function findArena(parent: Instance): Instance?
	return if parent.Name == "MuralhaArena" then parent else parent:FindFirstChild("MuralhaArena")
end

local function stylePortalVortex(att: Instance, theme: PortalThemeSpec): ()
	local portalLight = att:FindFirstChild("PortalVortexLight")
	if portalLight ~= nil and portalLight:IsA("PointLight") then
		portalLight.Color = rgb(theme.veilColor)
	end
	local emitter = att:FindFirstChild("PortalVortexParticles")
	if emitter ~= nil and emitter:IsA("ParticleEmitter") then
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(theme.accentColor)),
			ColorSequenceKeypoint.new(0.45, rgb(theme.veilColor)),
			ColorSequenceKeypoint.new(1, rgb(theme.mistColor)),
		})
	end
end

local function ensurePortalVortex(arena: Instance, theme: PortalThemeSpec?): ()
	local resolved = theme or PortalThemes.resolve(arena:GetAttribute("PortalTheme"))
	local host = arena:FindFirstChild("GrassTerrace")
	if host == nil or not host:IsA("BasePart") then
		return
	end
	local existing = host:FindFirstChild("PortalVortexAttachment")
	if existing ~= nil and existing:IsA("Attachment") then
		stylePortalVortex(existing, resolved)
		return
	end
	arena:SetAttribute("HasPortalVortex", true)

	local origin = Vector3.new(
		tonumber(arena:GetAttribute("OriginX")) or 0,
		tonumber(arena:GetAttribute("OriginY")) or 0,
		tonumber(arena:GetAttribute("OriginZ")) or 0
	)
	local att = Instance.new("Attachment")
	att.Name = "PortalVortexAttachment"
	att.Position =
		host.CFrame:PointToObjectSpace(origin + Vector3.new(PortalThemes.PORTAL_X, 5.4, 0))
	att.Parent = host

	local portalLight = Instance.new("PointLight")
	portalLight.Name = "PortalVortexLight"
	portalLight.Brightness = 1.35
	portalLight.Range = 26
	portalLight.Shadows = false
	portalLight.Parent = att

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PortalVortexParticles"
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.4, 2.2),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.35, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rate = 18
	emitter.Lifetime = NumberRange.new(1.0, 1.45)
	emitter.Speed = NumberRange.new(1.6, 3.8)
	emitter.SpreadAngle = Vector2.new(60, 75)
	emitter.EmissionDirection = Enum.NormalId.Left
	emitter.Acceleration = Vector3.new(-1.2, 2.0, 0)
	emitter.Drag = 1.6
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-170, 170)
	emitter.LightEmission = 0.85
	emitter.Parent = att

	stylePortalVortex(att, resolved)
end

-- 7 partes de moldura em PortalBlocks + 1 PortalVeil persistente (tally.portal = 8) + VFX persistente.
local function buildRiftPortal(folder: Folder, origin: Vector3, theme: PortalThemeSpec): ()
	local portalBlocks = Instance.new("Folder")
	portalBlocks.Name = "PortalBlocks"
	portalBlocks.Parent = folder
	local spawnX = PortalThemes.PORTAL_X
	local primary = rgb(theme.framePrimary)
	local secondary = rgb(theme.frameSecondary)
	part(
		portalBlocks,
		"PortalPlinth",
		Vector3.new(5.6, 1.0, 15.6),
		CFrame.new(origin + Vector3.new(spawnX, 0.5, 0)),
		primary,
		Enum.Material.Slate
	)
	for side = -1, 1, 2 do
		cylinder(
			portalBlocks,
			"PortalPillar_" .. tostring(side),
			Vector3.new(12.4, 3.0, 3.0),
			CFrame.new(origin + Vector3.new(spawnX, 6.7, side * 5.6)),
			primary,
			Enum.Material.Slate
		)
		local crown = Instance.new("WedgePart")
		crown.Name = "PortalCrown_" .. tostring(side)
		crown.Size = Vector3.new(2.2, 3.6, 2.4)
		local yaw = if side == 1 then 0 else math.rad(180)
		crown.CFrame = CFrame.new(origin + Vector3.new(spawnX, 13.6, side * 5.8))
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(math.rad(14), 0, 0)
		crown.Anchored = true
		crown.CanCollide = false
		crown.CanTouch = false
		crown.CanQuery = false
		crown.Material = Enum.Material.Slate
		crown.Color = secondary
		crown.Parent = portalBlocks
	end
	local lintel = part(
		portalBlocks,
		"PortalLintel",
		Vector3.new(14.0, 2.8, 2.8),
		CFrame.new(origin + Vector3.new(spawnX, 12.6, 0)) * CFrame.Angles(0, math.rad(90), 0),
		primary,
		Enum.Material.Slate
	)
	lintel.Shape = Enum.PartType.Cylinder
	neon(
		portalBlocks,
		"PortalRuneKeystone",
		Vector3.new(1.8, 1.8, 1.8),
		CFrame.new(origin + Vector3.new(spawnX, 14.2, 0)) * CFrame.Angles(math.rad(45), 0, 0),
		rgb(theme.accentColor)
	)

	-- PortalVeil dedicado fica fora de PortalBlocks para sobreviver a troca para PortalMesh.
	local veil = neon(
		folder,
		"PortalVeil",
		Vector3.new(0.35, 10.2, 7.6),
		CFrame.new(origin + Vector3.new(PortalThemes.VEIL_X, 5.4, 0)),
		rgb(theme.veilColor)
	)
	veil.CastShadow = false
	veil.Transparency = 0.32
	local veilMesh = Instance.new("SpecialMesh")
	veilMesh.MeshType = Enum.MeshType.Sphere
	veilMesh.Parent = veil

	ensurePortalVortex(folder, theme)
end

type PropSlotSpec = {
	slot: string,
	modelName: string,
	pos: Vector3,
	height: number,
	yaw: number,
	fx: string?,
}

local PROP_SLOTS: { PropSlotSpec } = {
	{
		slot = "Pine_1",
		modelName = "PROP_tree_pine",
		pos = Vector3.new(-31, 0.2, -22),
		height = 11.5,
		yaw = -20,
		fx = nil,
	},
	{
		slot = "Pine_2",
		modelName = "BACKDROP_tree01",
		pos = Vector3.new(-13, 0.2, -24.2),
		height = 10.6,
		yaw = 35,
		fx = nil,
	},
	{
		slot = "Pine_3",
		modelName = "PROP_tree_oak",
		pos = Vector3.new(4, 0.2, -24.5),
		height = 11.0,
		yaw = -45,
		fx = nil,
	},
	{
		slot = "Pine_4",
		modelName = "PROP_tree_pine",
		pos = Vector3.new(19, 0.2, -23.5),
		height = 10.8,
		yaw = 25,
		fx = nil,
	},
	{
		slot = "Pine_5",
		modelName = "BACKDROP_tree01",
		pos = Vector3.new(39.5, 0.2, -15.5),
		height = 11.2,
		yaw = -60,
		fx = nil,
	},
	{
		slot = "Pine_6",
		modelName = "PROP_tree_oak",
		pos = Vector3.new(-31, 0.2, 20),
		height = 10.4,
		yaw = 50,
		fx = nil,
	},
	{
		slot = "Rock_1",
		modelName = "PROP_rock_cluster",
		pos = Vector3.new(-28, 0.14, -14),
		height = 2.6,
		yaw = 54,
		fx = nil,
	},
	{
		slot = "Rock_2",
		modelName = "PROP_rock_cluster",
		pos = Vector3.new(-6, 0.14, -25),
		height = 2.2,
		yaw = 47,
		fx = nil,
	},
	{
		slot = "Rock_3",
		modelName = "PROP_rock_cluster",
		pos = Vector3.new(13, 0.14, -24.5),
		height = 2.8,
		yaw = 140,
		fx = nil,
	},
	{
		slot = "Rock_4",
		modelName = "PROP_rock_cluster",
		pos = Vector3.new(37.5, 0.14, -12.0),
		height = 2.5,
		yaw = 95,
		fx = nil,
	},
	{
		slot = "Rock_5",
		modelName = "PROP_rock_cluster",
		pos = Vector3.new(37.5, 0.14, 12.0),
		height = 2.4,
		yaw = 210,
		fx = nil,
	},
	{
		slot = "Rock_6",
		modelName = "PROP_rock_cluster",
		pos = Vector3.new(-29, 0.14, 11),
		height = 2.5,
		yaw = 305,
		fx = nil,
	},
	{
		slot = "Supply_1",
		modelName = "PROP_siege_supply",
		pos = Vector3.new(GridLayout.WALL_X + 3.8, 0.2, -12.5),
		height = 3.2,
		yaw = 18,
		fx = nil,
	},
	{
		slot = "Supply_2",
		modelName = "PROP_siege_supply",
		pos = Vector3.new(GridLayout.WALL_X + 3.8, 0.2, 12.5),
		height = 3.2,
		yaw = -24,
		fx = nil,
	},
	{
		slot = "Brazier_L",
		modelName = "PROP_iron_brazier",
		pos = Vector3.new(GridLayout.WALL_X + 3.2, 0.2, -18.5),
		height = 3.4,
		yaw = 0,
		fx = "fire",
	},
	{
		slot = "Brazier_R",
		modelName = "PROP_iron_brazier",
		pos = Vector3.new(GridLayout.WALL_X + 3.2, 0.2, 18.5),
		height = 3.4,
		yaw = 0,
		fx = "fire",
	},
	{
		slot = "Obelisk_L",
		modelName = "PROP_rift_obelisk",
		pos = Vector3.new(36.2, 0.18, -9.8),
		height = 5.6,
		yaw = 12,
		fx = "rift",
	},
	{
		slot = "Obelisk_R",
		modelName = "PROP_rift_obelisk",
		pos = Vector3.new(36.2, 0.18, 9.8),
		height = 5.6,
		yaw = -12,
		fx = "rift",
	},
}

local function buildPerimeterProps(folder: Folder, origin: Vector3): ()
	local wallX = GridLayout.WALL_X

	local treeSpecs = {
		{ slot = "Pine_1", pos = Vector3.new(-31, 0.2, -22), scale = 1.05 },
		{ slot = "Pine_2", pos = Vector3.new(-13, 0.2, -24.2), scale = 0.9 },
		{ slot = "Pine_3", pos = Vector3.new(4, 0.2, -24.5), scale = 1.1 },
		{ slot = "Pine_4", pos = Vector3.new(19, 0.2, -23.5), scale = 0.95 },
		{ slot = "Pine_5", pos = Vector3.new(39.5, 0.2, -15.5), scale = 1.0 },
		{ slot = "Pine_6", pos = Vector3.new(-31, 0.2, 20), scale = 0.95 },
	}
	for index, spec in ipairs(treeSpecs) do
		pineTree(folder, "Pine_" .. tostring(index), origin + spec.pos, spec.scale, spec.slot)
	end

	local rockOffsets = {
		{ slot = "Rock_1", pos = Vector3.new(-28, 0.5, -14), scale = 1.15 },
		{ slot = "Rock_2", pos = Vector3.new(-6, 0.5, -25), scale = 1.0 },
		{ slot = "Rock_3", pos = Vector3.new(13, 0.5, -24.5), scale = 1.2 },
		{ slot = "Rock_4", pos = Vector3.new(37.5, 0.5, -12.0), scale = 1.1 },
		{ slot = "Rock_5", pos = Vector3.new(37.5, 0.5, 12.0), scale = 1.05 },
		{ slot = "Rock_6", pos = Vector3.new(-29, 0.5, 11), scale = 1.1 },
	}
	for index, spec in ipairs(rockOffsets) do
		rock(folder, "CliffRock_" .. tostring(index), origin + spec.pos, spec.scale, spec.slot)
	end

	for index = 1, 2 do
		local z = if index == 1 then -12.5 else 12.5
		local slot = "Supply_" .. tostring(index)
		local barrel = cylinder(
			folder,
			"Barrel_" .. tostring(index),
			Vector3.new(2.2, 1.8, 1.8),
			CFrame.new(origin + Vector3.new(wallX + 3.8, 1.3, z)),
			rgb(VisualTheme.PALETTE.wood),
			Enum.Material.WoodPlanks
		)
		setPropSlot(barrel, slot)
		local hoop = cylinder(
			folder,
			"BarrelBand_" .. tostring(index),
			Vector3.new(0.20, 1.88, 1.88),
			CFrame.new(origin + Vector3.new(wallX + 3.8, 1.7, z)),
			rgb(VisualTheme.PALETTE.iron),
			Enum.Material.Metal
		)
		setPropSlot(hoop, slot)
	end

	brazier(folder, "BrazierL", origin + Vector3.new(wallX + 3.2, 0.22, -18.5), "Brazier_L")
	brazier(folder, "BrazierR", origin + Vector3.new(wallX + 3.2, 0.22, 18.5), "Brazier_R")
	tealPylon(folder, "TealPylonL", origin + Vector3.new(36.2, 0.22, -9.8), "Obelisk_L")
	tealPylon(folder, "TealPylonR", origin + Vector3.new(36.2, 0.22, 9.8), "Obelisk_R")
end

-- Slots so aparecem como LUZ (diretor): nada de quadrados/grade em repouso. Cada tile invisivel
-- carrega um disco de brilho (SurfaceGui, 0 partes) desligado; acende so nas celulas validas vazias
-- em modo de colocacao/hover, e mais forte na celula selecionada. Ocupadas/invalidas ficam escuras.
type GlowLevel = "off" | "hint" | "selected"

local GLOW_HINT = Color3.fromRGB(255, 196, 92)
local GLOW_SELECTED = Color3.fromRGB(255, 220, 130)
local explicitHints: { [Instance]: { [string]: boolean } } = setmetatable({}, { __mode = "k" }) :: any

local function placementGlow(tile: BasePart): ()
	local gui = Instance.new("SurfaceGui")
	gui.Name = "PlacementGlow"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 16
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.AlwaysOnTop = false
	gui.Enabled = false
	gui.Adornee = tile
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.62, 0.62)
	glow.BackgroundColor3 = GLOW_HINT
	glow.BackgroundTransparency = 0.72
	glow.BorderSizePixel = 0
	glow.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = glow
	local ring = Instance.new("UIStroke")
	ring.Name = "Ring"
	ring.Color = GLOW_SELECTED
	ring.Thickness = 3
	ring.Transparency = 0.55
	ring.Parent = glow
	gui.Parent = tile
end

local function styleGlow(tile: Instance, level: GlowLevel): ()
	local gui = tile:FindFirstChild("PlacementGlow")
	if gui == nil or not gui:IsA("SurfaceGui") then
		return
	end
	local glow = gui:FindFirstChild("Glow")
	local ring = if glow ~= nil then glow:FindFirstChild("Ring") else nil
	if level == "off" then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	local selected = level == "selected"
	if glow ~= nil and glow:IsA("Frame") then
		-- Selecionado cresce alem da base de trap (5.2) para o anel aparecer em celula ocupada.
		glow.Size = if selected then UDim2.fromScale(0.8, 0.8) else UDim2.fromScale(0.62, 0.62)
		glow.BackgroundColor3 = if selected then GLOW_SELECTED else GLOW_HINT
		glow.BackgroundTransparency = if selected then 0.5 else 0.72
	end
	if ring ~= nil and ring:IsA("UIStroke") then
		ring.Thickness = if selected then 5 else 3
		ring.Transparency = if selected then 0.15 else 0.55
	end
end

local function isOccupied(arena: Instance, cell: string): boolean
	local host = arena.Parent
	local traps = if host ~= nil then host:FindFirstChild("MuralhaTraps") else nil
	return traps ~= nil and traps:FindFirstChild("Trap_" .. cell) ~= nil
end

local function refreshGlow(arena: Instance): ()
	local tiles = arena:FindFirstChild("MuralhaCellTiles")
	if tiles == nil then
		return
	end
	local selectedAttr = arena:GetAttribute("SelectedCell")
	local selected = if type(selectedAttr) == "string" then selectedAttr else nil
	local mode = arena:GetAttribute("PlacementMode")
	local placing = mode == nil or mode == "place"
	local explicit = explicitHints[arena]
	for _, tile in ipairs(tiles:GetChildren()) do
		local cellAttr = tile:GetAttribute("Cell")
		if type(cellAttr) == "string" then
			local level: GlowLevel = "off"
			if cellAttr == selected then
				level = "selected"
			elseif explicit ~= nil then
				level = if explicit[cellAttr] == true then "hint" else "off"
			elseif selected ~= nil and placing and not isOccupied(arena, cellAttr) then
				level = "hint"
			end
			styleGlow(tile, level)
		end
	end
end

local function buildCellTiles(folder: Folder, origin: Vector3): Folder
	local tilesFolder = Instance.new("Folder")
	tilesFolder.Name = "MuralhaCellTiles"
	tilesFolder.Parent = folder
	local tileSizeArr = VisualTheme.GRID_TILES.size
	local tileSize = Vector3.new(tileSizeArr[1], tileSizeArr[2], tileSizeArr[3])
	local tileY = VisualTheme.GRID_TILES.y

	-- Tiles viram alvos de raycast invisiveis (CanQuery=true; Transparency=1 nao bloqueia o hit).
	for row = 1, GridLayout.HEIGHT do
		for col = 1, GridLayout.WIDTH do
			local cell = GridLayout.cellName(row, col)
			local x, _, z = GridLayout.cellPosition(row, col)
			if cell ~= nil and x ~= nil and z ~= nil then
				local tile = part(
					tilesFolder,
					"Cell_" .. cell,
					tileSize,
					CFrame.new(origin + Vector3.new(x, tileY, z)),
					LANE_EARTH,
					Enum.Material.SmoothPlastic
				)
				tile.CanQuery = true
				tile.CastShadow = false
				tile.Transparency = 1
				tile:SetAttribute("Cell", cell)
				placementGlow(tile)
			end
		end
	end
	return tilesFolder
end

local DISC_VALID_COLOR = Color3.fromRGB(52, 211, 153)
local DISC_INVALID_COLOR = Color3.fromRGB(239, 68, 68)

local function buildSelectionIndicator(folder: Folder, origin: Vector3): Part
	local indicator = part(
		folder,
		"SelectionIndicator",
		Vector3.new(6.2, 0.08, 6.2),
		CFrame.new(origin + Vector3.new(0, 0.39, 0)),
		DISC_VALID_COLOR,
		Enum.Material.SmoothPlastic
	)
	indicator.CanQuery = false
	indicator.CastShadow = false
	indicator.Transparency = 1

	local gui = Instance.new("SurfaceGui")
	gui.Name = "PlacementDisc"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 16
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.AlwaysOnTop = false
	gui.Enabled = false
	gui.Adornee = indicator

	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromScale(0.86, 0.86)
	disc.BackgroundColor3 = DISC_VALID_COLOR
	disc.BackgroundTransparency = 0.68
	disc.BorderSizePixel = 0
	disc.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = disc

	local ring = Instance.new("UIStroke")
	ring.Name = "Ring"
	ring.Color = DISC_VALID_COLOR
	ring.Thickness = 4
	ring.Transparency = 0.15
	ring.Parent = disc

	gui.Parent = indicator

	local rangeIndicator = part(
		folder,
		"RangeIndicator",
		Vector3.new(26.7, 0.06, 40.0),
		CFrame.new(origin + Vector3.new(0, 0.38, 0)),
		DISC_VALID_COLOR,
		Enum.Material.SmoothPlastic
	)
	rangeIndicator.CanQuery = false
	rangeIndicator.CastShadow = false
	rangeIndicator.Transparency = 1

	local rangeGui = Instance.new("SurfaceGui")
	rangeGui.Name = "RangeDisc"
	rangeGui.Face = Enum.NormalId.Top
	rangeGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	rangeGui.CanvasSize = Vector2.new(256, 256)
	rangeGui.LightInfluence = 0
	rangeGui.Brightness = 1.5
	rangeGui.AlwaysOnTop = false
	rangeGui.Enabled = false
	rangeGui.Adornee = rangeIndicator

	local rangeFrame = Instance.new("Frame")
	rangeFrame.Name = "Disc"
	rangeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	rangeFrame.Position = UDim2.fromScale(0.5, 0.5)
	rangeFrame.Size = UDim2.fromScale(0.94, 0.94)
	rangeFrame.BackgroundColor3 = DISC_VALID_COLOR
	rangeFrame.BackgroundTransparency = 0.88
	rangeFrame.BorderSizePixel = 0
	rangeFrame.Parent = rangeGui

	local rangeCorner = Instance.new("UICorner")
	rangeCorner.CornerRadius = UDim.new(0.5, 0)
	rangeCorner.Parent = rangeFrame

	local rangeRing = Instance.new("UIStroke")
	rangeRing.Name = "Ring"
	rangeRing.Color = DISC_VALID_COLOR
	rangeRing.Thickness = 3
	rangeRing.Transparency = 0.2
	rangeRing.Parent = rangeFrame

	rangeGui.Parent = rangeIndicator
	return indicator
end

local function placePortalMesh(arena: Instance, themeKey: string?): (boolean, boolean)
	local resolved = PortalThemes.resolve(themeKey or arena:GetAttribute("PortalTheme"))
	local targetName = MeshAssets.portalModelName(resolved.id)
	local assets = ReplicatedStorage:FindFirstChild(MeshAssets.FOLDER)
	if assets == nil then
		return false, false
	end
	local preferred = assets:FindFirstChild(targetName)
	local source: Model? = if preferred ~= nil and preferred:IsA("Model") then preferred else nil
	local isExact = source ~= nil
	if source == nil and targetName ~= MeshAssets.PORTAL_MODEL then
		local fallback = assets:FindFirstChild(MeshAssets.PORTAL_MODEL)
		if fallback ~= nil and fallback:IsA("Model") then
			source = fallback
		end
	end
	if source == nil then
		return false, false
	end
	local origin = Vector3.new(
		tonumber(arena:GetAttribute("OriginX")) or 0,
		tonumber(arena:GetAttribute("OriginY")) or 0,
		tonumber(arena:GetAttribute("OriginZ")) or 0
	)
	local old = arena:FindFirstChild("PortalMesh")
	if old ~= nil then
		old:Destroy()
	end
	local clone = source:Clone()
	clone.Name = "PortalMesh"
	clone:SetAttribute("PortalTheme", resolved.id)
	clone:SetAttribute("SourceModelName", source.Name)
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = true
		end
	end
	local _, rawSize = clone:GetBoundingBox()
	if rawSize.Y > 0.01 then
		clone:ScaleTo(clone:GetScale() * PORTAL_TARGET_HEIGHT / rawSize.Y)
	end
	local box, size = clone:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, size.Y / 2, 0)
	local target = origin + Vector3.new(PortalThemes.PORTAL_X, 0.28, 0)
	clone:PivotTo(
		CFrame.new(target)
			* CFrame.Angles(0, math.rad(-90), 0)
			* CFrame.new(-bottom)
			* clone:GetPivot()
	)
	clone.Parent = arena
	ensurePortalVortex(arena, resolved)
	-- Mantem PortalVeil e PortalVortexAttachment intocados; remove so a moldura procedural.
	local blocks = arena:FindFirstChild("PortalBlocks")
	if blocks ~= nil then
		blocks:Destroy()
	end
	return true, isExact
end

local function trySwapPortalMesh(arena: Instance, themeKey: string?): ()
	local resolved = PortalThemes.resolve(themeKey or arena:GetAttribute("PortalTheme"))
	local _, isExact = placePortalMesh(arena, resolved.id)
	if isExact then
		return
	end
	local targetName = MeshAssets.portalModelName(resolved.id)
	task.spawn(function()
		local assets = ReplicatedStorage:WaitForChild(MeshAssets.FOLDER, 30)
		if assets == nil or arena.Parent == nil then
			return
		end
		if arena:GetAttribute("PortalTheme") ~= resolved.id then
			return
		end
		local awaited: Instance? = assets:WaitForChild(targetName, 60)
		if awaited ~= nil then
			if
				(arena.Parent :: Instance?) ~= nil
				and arena:GetAttribute("PortalTheme") == resolved.id
			then
				placePortalMesh(arena, resolved.id)
			end
			return
		end
		if targetName ~= MeshAssets.PORTAL_MODEL then
			local fallback: Instance? = assets:FindFirstChild(MeshAssets.PORTAL_MODEL)
				or assets:WaitForChild(MeshAssets.PORTAL_MODEL, 15) :: Instance?
			if
				fallback ~= nil
				and (arena.Parent :: Instance?) ~= nil
				and arena:GetAttribute("PortalTheme") == resolved.id
			then
				placePortalMesh(arena, resolved.id)
			end
		end
	end)
end

local function attachEffect(
	parent: Instance,
	localPos: Vector3,
	kind: string,
	attachName: string
): ()
	local prev = parent:FindFirstChild(attachName)
	if prev ~= nil then
		prev:Destroy()
	end
	local att = Instance.new("Attachment")
	att.Name = attachName
	att.Position = localPos
	att.Parent = parent

	local light = Instance.new("PointLight")
	light.Shadows = false
	light.Parent = att

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = attachName .. "_Particles"
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Drag = 1.4
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.LightEmission = 0.85

	if kind == "rift" then
		local teal = rgb(VisualTheme.PALETTE.teal)
		local tealDark = rgb(VisualTheme.PALETTE.tealDark)
		light.Color = teal
		light.Brightness = 0.75
		light.Range = 15
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(165, 255, 240)),
			ColorSequenceKeypoint.new(0.5, teal),
			ColorSequenceKeypoint.new(1, tealDark),
		})
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.5, 0.5),
			NumberSequenceKeypoint.new(1, 0.08),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.4, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Rate = 10
		emitter.Lifetime = NumberRange.new(0.8, 1.35)
		emitter.Speed = NumberRange.new(0.8, 2.0)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.Acceleration = Vector3.new(0, 0.8, 0)
	else
		local amber = rgb(VisualTheme.PALETTE.amber)
		light.Color = amber
		light.Brightness = 0.85
		light.Range = 16
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 238, 150)),
			ColorSequenceKeypoint.new(0.45, amber),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 58, 18)),
		})
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.4, 0.65),
			NumberSequenceKeypoint.new(1, 0.12),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.6, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Rate = 14
		emitter.Lifetime = NumberRange.new(0.45, 0.85)
		emitter.Speed = NumberRange.new(1.5, 3.2)
		emitter.SpreadAngle = Vector2.new(22, 22)
		emitter.Acceleration = Vector3.new(0, 2.2, 0)
	end

	emitter.Parent = att
end

local function ensureWallTorches(arena: Instance): ()
	local grass = arena:FindFirstChild("GrassTerrace")
	if grass == nil or not grass:IsA("BasePart") then
		return
	end
	local origin = Vector3.new(
		tonumber(arena:GetAttribute("OriginX")) or 0,
		tonumber(arena:GetAttribute("OriginY")) or 0,
		tonumber(arena:GetAttribute("OriginZ")) or 0
	)
	attachEffect(
		grass,
		grass.CFrame:PointToObjectSpace(origin + Vector3.new(GridLayout.WALL_X + 2.2, 5.0, -4.9)),
		"fire",
		"WallTorchFxL"
	)
	attachEffect(
		grass,
		grass.CFrame:PointToObjectSpace(origin + Vector3.new(GridLayout.WALL_X + 2.2, 5.0, 4.9)),
		"fire",
		"WallTorchFxR"
	)
end

-- Muralha em malha (Forge3D/Open Cloud): troca todos os blocos de WallBlocks pelo modelo do tier
-- e substitui tochas em cubo por pontos de fogo em ParticleEmitter + PointLight.
local function placeWallMesh(arena: Instance, tier: number): boolean
	local assets = ReplicatedStorage:FindFirstChild(WallAssets.FOLDER)
	local source = if assets ~= nil then assets:FindFirstChild(WallAssets.modelName(tier)) else nil
	if source == nil or not source:IsA("Model") then
		return false
	end
	local origin = Vector3.new(
		tonumber(arena:GetAttribute("OriginX")) or 0,
		tonumber(arena:GetAttribute("OriginY")) or 0,
		tonumber(arena:GetAttribute("OriginZ")) or 0
	)
	local old = arena:FindFirstChild("WallMesh")
	if old ~= nil then
		old:Destroy()
	end
	local clone = (source :: Model):Clone()
	clone.Name = "WallMesh"
	clone:SetAttribute("Tier", tier)
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = true
		end
	end
	local box, size = clone:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, size.Y / 2, 0)
	local target = origin + Vector3.new(GridLayout.WALL_X, 0, 0)
	clone:PivotTo(
		CFrame.new(target)
			* CFrame.Angles(0, math.rad(90), 0)
			* CFrame.new(-bottom)
			* clone:GetPivot()
	)
	clone.Parent = arena
	local blocks = arena:FindFirstChild("WallBlocks")
	if blocks ~= nil then
		blocks:ClearAllChildren()
	end
	ensureWallTorches(arena)
	local hpPct = tonumber(arena:GetAttribute("WallHpPct"))
	if hpPct ~= nil and hpPct < 1 then
		ArenaVisual.setWallDamageStage(arena, hpPct)
	end
	return true
end

local function clearPropFallbackSlot(arena: Instance, slotName: string): ()
	for _, child in ipairs(arena:GetChildren()) do
		if child:GetAttribute("PropSlot") == slotName then
			child:Destroy()
		end
	end
end

local function placePropSlot(
	arena: Instance,
	assets: Instance,
	origin: Vector3,
	spec: PropSlotSpec
): boolean
	if arena:FindFirstChild("Prop_" .. spec.slot) ~= nil then
		return true
	end
	local source = assets:FindFirstChild(spec.modelName)
	if source == nil or not source:IsA("Model") then
		return false
	end
	local clone = (source :: Model):Clone()
	clone.Name = "Prop_" .. spec.slot
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = true
		end
	end
	local _, rawSize = clone:GetBoundingBox()
	if rawSize.Y > 0.01 then
		clone:ScaleTo(clone:GetScale() * spec.height / rawSize.Y)
	end
	local box, size = clone:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, size.Y * 0.5, 0)
	local target = origin + spec.pos
	clone:PivotTo(
		CFrame.new(target)
			* CFrame.Angles(0, math.rad(spec.yaw), 0)
			* CFrame.new(-bottom)
			* clone:GetPivot()
	)
	if spec.fx ~= nil then
		local anchorPart = clone:FindFirstChildWhichIsA("BasePart", true)
		if anchorPart ~= nil then
			local ratio = if spec.fx == "fire" then 0.88 else 0.82
			local fxWorld = target + Vector3.new(0, size.Y * ratio, 0)
			local localOffset = anchorPart.CFrame:PointToObjectSpace(fxWorld)
			attachEffect(anchorPart, localOffset, spec.fx, "PropFx_" .. spec.slot)
		end
	end
	clone.Parent = arena
	clearPropFallbackSlot(arena, spec.slot)
	return true
end

local function fillPropSlots(arena: Instance, assets: Instance, origin: Vector3): boolean
	local pending = false
	for _, spec in ipairs(PROP_SLOTS) do
		if not placePropSlot(arena, assets, origin, spec) then
			pending = true
		end
	end
	return pending
end

local function trySwapPropMeshes(arena: Instance, origin: Vector3): ()
	local existing = ReplicatedStorage:FindFirstChild(MeshAssets.FOLDER)
	if existing ~= nil and not fillPropSlots(arena, existing, origin) then
		return
	end
	task.spawn(function()
		local assets = ReplicatedStorage:WaitForChild(MeshAssets.FOLDER, 30)
		if assets == nil or not arena:IsDescendantOf(game) then
			return
		end
		if not fillPropSlots(arena, assets, origin) then
			return
		end
		local connection: RBXScriptConnection
		connection = assets.ChildAdded:Connect(function()
			if not arena:IsDescendantOf(game) then
				connection:Disconnect()
				return
			end
			if not fillPropSlots(arena, assets, origin) then
				connection:Disconnect()
			end
		end)
		task.delay(60, function()
			if connection.Connected then
				connection:Disconnect()
			end
		end)
	end)
end

local function resolveTier(explicit: number?): number
	if explicit ~= nil then
		return WallAssets.tierForLeague(explicit)
	end
	local player = Players.LocalPlayer
	local attr = if player ~= nil then player:GetAttribute(WallAssets.TIER_ATTRIBUTE) else nil
	return WallAssets.tierForLeague(if type(attr) == "number" then attr else 1)
end

-- Aplica o tier agora ou quando a malha chegar do servidor (fallback: blocos).
function ArenaVisual.setWallTier(parent: Instance, tier: number): ()
	local arena = parent:FindFirstChild("MuralhaArena")
	if arena == nil then
		return
	end
	arena:SetAttribute("WallTier", tier)
	if placeWallMesh(arena, tier) then
		return
	end
	task.spawn(function()
		local assets = ReplicatedStorage:WaitForChild(WallAssets.FOLDER, 30)
		if assets == nil then
			return
		end
		local name = WallAssets.modelName(tier)
		if assets:WaitForChild(name, 60) ~= nil and arena.Parent ~= nil then
			if arena:GetAttribute("WallTier") == tier then
				placeWallMesh(arena, tier)
			end
		end
	end)
end

local function clearExisting(parent: Instance): ()
	local existing = parent:FindFirstChild("MuralhaArena")
	if existing ~= nil then
		existing:Destroy()
	end
end

function ArenaVisual.setPortalTheme(arena: Instance, themeKey: string?): ()
	local targetArena = findArena(arena)
	if targetArena == nil then
		return
	end
	local resolved = PortalThemes.resolve(themeKey or targetArena:GetAttribute("PortalTheme"))
	targetArena:SetAttribute("PortalTheme", resolved.id)

	local primary = rgb(resolved.framePrimary)
	local secondary = rgb(resolved.frameSecondary)
	local veilColor = rgb(resolved.veilColor)
	local accentColor = rgb(resolved.accentColor)

	local veil = targetArena:FindFirstChild("PortalVeil")
	if veil ~= nil and veil:IsA("BasePart") then
		veil.Color = veilColor
	end

	local portalBlocks = targetArena:FindFirstChild("PortalBlocks")
	if portalBlocks ~= nil then
		for _, child in ipairs(portalBlocks:GetChildren()) do
			if child:IsA("BasePart") then
				if child.Name == "PortalRuneKeystone" then
					child.Color = accentColor
				elseif string.sub(child.Name, 1, 12) == "PortalCrown_" then
					child.Color = secondary
				else
					child.Color = primary
				end
			end
		end
	end

	local manifold = targetArena:FindFirstChild("PortalManifold")
	if manifold ~= nil then
		local laneColor = fanLaneColor(resolved)
		for _, child in ipairs(manifold:GetChildren()) do
			if child:IsA("BasePart") then
				if child.Name == "PortalApron" then
					child.Color = primary
				elseif string.sub(child.Name, 1, 8) == "FanLane_" then
					child.Color = laneColor
				end
			end
		end
	end

	ensurePortalVortex(targetArena, resolved)
	trySwapPortalMesh(targetArena, resolved.id)
end

function ArenaVisual.build(parent: Instance, origin: Vector3, options: BuildOptions?): Folder
	clearExisting(parent)
	local opts: BuildOptions = options or {}
	local dropIn = opts.dropIn == true
	local resolvedTheme = PortalThemes.resolve(opts.portalTheme)
	local folder = Instance.new("Folder")
	folder.Name = "MuralhaArena"
	folder.Parent = parent
	folder:SetAttribute("OriginX", origin.X)
	folder:SetAttribute("OriginY", origin.Y)
	folder:SetAttribute("OriginZ", origin.Z)
	folder:SetAttribute("PortalTheme", resolvedTheme.id)

	buildIsland(folder, origin)
	buildPortalManifold(folder, origin, resolvedTheme)
	local wallBlocks = Instance.new("Folder")
	wallBlocks.Name = "WallBlocks"
	wallBlocks.Parent = folder
	buildWallAndGatehouse(wallBlocks, origin)
	buildRiftPortal(folder, origin, resolvedTheme)
	buildPerimeterProps(folder, origin)
	buildCellTiles(folder, origin)
	buildSelectionIndicator(folder, origin)

	if dropIn then
		part(
			folder,
			"DropInPath",
			Vector3.new(38, 0.12, 30),
			CFrame.new(origin + Vector3.new(8, 0.33, 0)),
			rgb(VisualTheme.PALETTE.ironDark),
			Enum.Material.Slate
		)
	end

	ArenaVisual.setWallTier(parent, resolveTier(opts.wallTier))
	trySwapPortalMesh(folder, resolvedTheme.id)
	trySwapPropMeshes(folder, origin)

	-- Gancho opcional: cenario de fundo (modulo irmao "Backdrop"); no-op se ausente ou com erro.
	local backdropModule = if IS_ROBLOX and script.Parent ~= nil
		then script.Parent:FindFirstChild("Backdrop")
		else nil
	if backdropModule ~= nil and backdropModule:IsA("ModuleScript") then
		local ok, backdrop = pcall(require, backdropModule)
		if ok and type(backdrop) == "table" and type((backdrop :: any).build) == "function" then
			pcall((backdrop :: any).build, folder, origin)
		end
	end
	return folder
end

-- Hover/toque livre: disco circular de luz (verde valido, vermelho invalido/tooClose, oculto em repouso).
function ArenaVisual.setPlacementDisc(
	parent: Instance,
	worldPos: Vector3?,
	valid: boolean?,
	trapId: string?
): ()
	local arena = findArena(parent)
	if arena == nil then
		return
	end
	local indicator = arena:FindFirstChild("SelectionIndicator")
	local gui = if indicator ~= nil and indicator:IsA("BasePart")
		then indicator:FindFirstChild("PlacementDisc")
		else nil
	local rangeIndicator = arena:FindFirstChild("RangeIndicator")
	local rangeGui = if rangeIndicator ~= nil and rangeIndicator:IsA("BasePart")
		then rangeIndicator:FindFirstChild("RangeDisc")
		else nil
	if worldPos == nil then
		if gui ~= nil and gui:IsA("SurfaceGui") then
			gui.Enabled = false
		end
		if rangeGui ~= nil and rangeGui:IsA("SurfaceGui") then
			rangeGui.Enabled = false
		end
		return
	end
	local color = if valid ~= false then DISC_VALID_COLOR else DISC_INVALID_COLOR
	if indicator ~= nil and indicator:IsA("BasePart") and gui ~= nil and gui:IsA("SurfaceGui") then
		indicator.CFrame = CFrame.new(worldPos.X, math.max(worldPos.Y, 0.36) + 0.03, worldPos.Z)
		local disc = gui:FindFirstChild("Disc")
		if disc ~= nil and disc:IsA("Frame") then
			disc.BackgroundColor3 = color
			local ring = disc:FindFirstChild("Ring")
			if ring ~= nil and ring:IsA("UIStroke") then
				ring.Color = color
			end
		end
		gui.Enabled = true
	end
	if
		rangeIndicator ~= nil
		and rangeIndicator:IsA("BasePart")
		and rangeGui ~= nil
		and rangeGui:IsA("SurfaceGui")
	then
		if trapId == "archer" then
			rangeIndicator.CFrame =
				CFrame.new(worldPos.X, math.max(worldPos.Y, 0.36) + 0.02, worldPos.Z)
			local rDisc = rangeGui:FindFirstChild("Disc")
			if rDisc ~= nil and rDisc:IsA("Frame") then
				rDisc.BackgroundColor3 = color
				local rRing = rDisc:FindFirstChild("Ring")
				if rRing ~= nil and rRing:IsA("UIStroke") then
					rRing.Color = color
				end
			end
			rangeGui.Enabled = true
		else
			rangeGui.Enabled = false
		end
	end
end

-- Hover/toque: move o SelectionIndicator (disco circular; sem quadrado). nil volta ao repouso.
function ArenaVisual.setSelection(parent: Instance, cell: string?, origin: Vector3?): ()
	local arena = findArena(parent)
	if arena == nil then
		return
	end
	local indicator = arena:FindFirstChild("SelectionIndicator")
	if indicator == nil or not indicator:IsA("BasePart") then
		return
	end
	local outline = indicator:FindFirstChild("Outline")
	if outline ~= nil and outline:IsA("SelectionBox") then
		outline.Visible = false
	end
	indicator.Transparency = 1
	local row, col = if cell ~= nil then GridLayout.parseCell(cell) else nil, nil
	if row == nil or col == nil then
		arena:SetAttribute("SelectedCell", nil)
		ArenaVisual.setPlacementDisc(arena, nil)
		refreshGlow(arena)
		return
	end
	local x, _, z = GridLayout.cellPosition(row, col)
	if x == nil or z == nil then
		return
	end
	local ox = arena:GetAttribute("OriginX")
	local oy = arena:GetAttribute("OriginY")
	local oz = arena:GetAttribute("OriginZ")
	local baseOrigin = if origin ~= nil
		then origin
		else Vector3.new(
			if type(ox) == "number" then ox else 0,
			if type(oy) == "number" then oy else 0,
			if type(oz) == "number" then oz else 0
		)
	ArenaVisual.setPlacementDisc(arena, baseOrigin + Vector3.new(x, 0.36, z), true)
	arena:SetAttribute("SelectedCell", cell)
	refreshGlow(arena)
end

-- Opcional (BuildClient): celulas validas vazias a iluminar enquanto em modo de colocacao.
-- nil = volta ao automatico (acende vazias so durante hover/selecao em modo "place").
function ArenaVisual.setPlacementHints(parent: Instance, validCells: { string }?): ()
	local arena = findArena(parent)
	if arena == nil then
		return
	end
	if validCells == nil then
		explicitHints[arena] = nil
	else
		local set: { [string]: boolean } = {}
		for _, cell in ipairs(validCells) do
			set[cell] = true
		end
		explicitHints[arena] = set
	end
	refreshGlow(arena)
end

-- Opcional (BuildClient): "place" | "upgrade" | "remove" | nil. Fora de "place" so a selecao acende.
function ArenaVisual.setPlacementMode(parent: Instance, mode: string?): ()
	local arena = findArena(parent)
	if arena == nil then
		return
	end
	arena:SetAttribute("PlacementMode", mode)
	refreshGlow(arena)
end

local IS_ROBLOX_RUNTIME = type(game) == "userdata"
local SOOT_TINT_COLOR = Color3.fromRGB(24, 22, 26)
local WALL_CRACK_COLOR = Color3.fromRGB(18, 16, 20)
local WALL_FISSURE_GLOW_COLOR = Color3.fromRGB(245, 110, 28)
local WALL_BREACH_FIRE_COLOR = Color3.fromRGB(240, 95, 25)

local STAGE_POSE_TWEEN_INFO = TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local COLLAPSE_TWEEN_INFO = TweenInfo.new(0.38, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
local IMPACT_RECOVERY_TWEEN_INFO =
	TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

type WallPartRest = {
	cf: CFrame,
	color: Color3,
	transparency: number,
	zone: string,
	isUpperTrim: boolean,
}

type ZonePoseSpec = {
	pos: Vector3,
	rot: CFrame,
}

type StagePoseSpec = {
	sootAlpha: number,
	hideUpper: boolean,
	zones: { [string]: ZonePoseSpec },
}

local wallPartRest: { [BasePart]: WallPartRest } = setmetatable({}, { __mode = "k" }) :: any
local wallPartAppliedStage: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any
local activeWallTweens: { [BasePart]: Tween? } = setmetatable({}, { __mode = "k" }) :: any
local activeWallLookTweens: { [BasePart]: Tween? } = setmetatable({}, { __mode = "k" }) :: any

local UPPER_TRIM_PREFIXES = {
	"Merlon_",
	"WallParapet",
	"GatehouseCap",
	"PortcullisPicket_",
	"Banner_",
	"TowerSpire_",
	"TowerRoof_",
}

local ZONE_COLLAPSE_DELAY: { [string]: number } = {
	gate = 0,
	wingL = 0.07,
	wingR = 0.07,
	towerL = 0.14,
	towerR = 0.14,
}

local function degAngles(rx: number, ry: number, rz: number): CFrame
	return CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
end

local STAGE_SPECS: { [number]: StagePoseSpec } = {
	[1] = {
		sootAlpha = 0.14,
		hideUpper = false,
		zones = {
			gate = { pos = Vector3.new(-0.2, -0.2, 0), rot = degAngles(1.5, 0, 0) },
			wingL = { pos = Vector3.new(-0.15, -0.25, 0), rot = degAngles(-1.8, 0, 1.2) },
			wingR = { pos = Vector3.new(-0.15, -0.25, 0), rot = degAngles(1.8, 0, -1.2) },
			towerL = { pos = Vector3.new(0, -0.1, 0), rot = degAngles(0, 0, 1.0) },
			towerR = { pos = Vector3.new(0, -0.1, 0), rot = degAngles(0, 0, 1.0) },
		},
	},
	[2] = {
		sootAlpha = 0.30,
		hideUpper = false,
		zones = {
			gate = { pos = Vector3.new(-0.85, -0.75, 0), rot = degAngles(4.5, -2, 3.5) },
			wingL = { pos = Vector3.new(-0.65, -1.15, 0), rot = degAngles(-4.5, 2, 4.0) },
			wingR = { pos = Vector3.new(-0.65, -1.15, 0), rot = degAngles(4.5, -2, -4.0) },
			towerL = { pos = Vector3.new(-0.3, -0.5, 0), rot = degAngles(-2.5, 0, 2.5) },
			towerR = { pos = Vector3.new(-0.3, -0.5, 0), rot = degAngles(2.5, 0, -2.5) },
		},
	},
	[3] = {
		sootAlpha = 0.48,
		hideUpper = true,
		zones = {
			gate = { pos = Vector3.new(-1.6, -1.85, 0), rot = degAngles(9.5, -4, 8.0) },
			wingL = { pos = Vector3.new(-1.3, -2.35, 0), rot = degAngles(-8.5, 4, 7.5) },
			wingR = { pos = Vector3.new(-1.3, -2.35, 0), rot = degAngles(8.5, -4, -7.5) },
			towerL = { pos = Vector3.new(-0.8, -1.35, 0), rot = degAngles(-6.0, 0, 5.5) },
			towerR = { pos = Vector3.new(-0.8, -1.35, 0), rot = degAngles(6.0, 0, -5.5) },
		},
	},
	[4] = {
		sootAlpha = 0.68,
		hideUpper = true,
		zones = {
			gate = { pos = Vector3.new(-2.8, -5.2, 0), rot = degAngles(18, -8, 38) },
			wingL = { pos = Vector3.new(-2.2, -5.4, -0.6), rot = degAngles(-28, 10, 26) },
			wingR = { pos = Vector3.new(-2.2, -5.4, 0.6), rot = degAngles(28, -10, -26) },
			towerL = { pos = Vector3.new(-1.8, -6.2, 0.8), rot = degAngles(22, 6, 20) },
			towerR = { pos = Vector3.new(-1.8, -6.2, -0.8), rot = degAngles(-22, -6, -20) },
		},
	},
}

local WIDE_IMPACT_WEIGHTS: { [string]: number } = {
	wingL = 1,
	gate = 1,
	wingR = 1,
	towerL = 0.45,
	towerR = 0.45,
}

local LANE_IMPACT_WEIGHTS: { [number]: { [string]: number } } = {
	[1] = { wingL = 1, towerL = 0.75 },
	[2] = { wingL = 1, gate = 0.45 },
	[3] = { gate = 1, wingL = 0.4, wingR = 0.4 },
	[4] = { wingR = 1, gate = 0.45 },
	[5] = { wingR = 1, towerR = 0.75 },
}

local STAGE_FIRE_Z_POSITIONS: { [number]: { number } } = {
	[1] = { 0 },
	[2] = { -12, 0, 12 },
	[3] = { -16, -8, 0, 8, 16 },
	[4] = { -18, -9, 0, 9, 18 },
}

local function getArenaOrigin(arena: Instance): Vector3
	return Vector3.new(
		tonumber(arena:GetAttribute("OriginX")) or 0,
		tonumber(arena:GetAttribute("OriginY")) or 0,
		tonumber(arena:GetAttribute("OriginZ")) or 0
	)
end

local function containsAny(text: string, needles: { string }): boolean
	for _, needle in ipairs(needles) do
		if string.find(text, needle, 1, true) ~= nil then
			return true
		end
	end
	return false
end

local function classifyWallZone(piece: BasePart, originZ: number): string
	local lower = string.lower(piece.Name)
	-- Check gate/portcullis first so PortcullisPicket_1 does not match "_1",
	-- and route Merlon_* through the Z fallback so Merlon_1 resolves to wingL.
	if containsAny(lower, { "gate", "portcullis" }) then
		return "gate"
	end
	local isMerlon = string.find(lower, "merlon", 1, true) ~= nil
	if not isMerlon then
		if containsAny(lower, { "towerl", "tower_-1", "_-1" }) then
			return "towerL"
		end
		if containsAny(lower, { "towerr", "tower_1", "_1" }) then
			return "towerR"
		end
	end
	if containsAny(lower, { "segmentl", "plinthl", "bodyl", "bandl", "parapetl" }) then
		return "wingL"
	end
	if containsAny(lower, { "segmentr", "plinthr", "bodyr", "bandr", "parapetr" }) then
		return "wingR"
	end

	local dz = piece.Position.Z - originZ
	if dz < -18 then
		return "towerL"
	elseif dz < -5.2 then
		return "wingL"
	elseif dz <= 5.2 then
		return "gate"
	elseif dz <= 18 then
		return "wingR"
	end
	return "towerR"
end

local function isUpperTrimPart(name: string): boolean
	for _, prefix in ipairs(UPPER_TRIM_PREFIXES) do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function ensureWallPartRest(piece: BasePart, originZ: number): WallPartRest
	local existing = wallPartRest[piece]
	if existing ~= nil then
		return existing
	end
	local colorAny = (piece :: any).Color
	local transAny = (piece :: any).Transparency
	local rest: WallPartRest = {
		cf = piece.CFrame,
		color = if colorAny ~= nil then colorAny else rgb(VisualTheme.PALETTE.stone),
		transparency = if type(transAny) == "number" then transAny else 0,
		zone = classifyWallZone(piece, originZ),
		isUpperTrim = isUpperTrimPart(piece.Name),
	}
	wallPartRest[piece] = rest
	return rest
end

local function collectWallParts(arena: Instance): { BasePart }
	local parts: { BasePart } = {}
	for _, containerName in ipairs({ "WallMesh", "WallBlocks" }) do
		local container = arena:FindFirstChild(containerName)
		if container ~= nil then
			for _, desc in ipairs(container:GetDescendants()) do
				if desc:IsA("BasePart") then
					table.insert(parts, desc)
				end
			end
		end
	end
	return parts
end

local function computeZoneStageOffset(
	zone: string,
	_isUpperTrim: boolean,
	stage: number
): (Vector3, CFrame, number, boolean)
	local clamped = math.clamp(math.floor(stage), 0, 4)
	if clamped <= 0 then
		return Vector3.zero, CFrame.identity, 0, false
	end
	local stageSpec = STAGE_SPECS[clamped]
	local zoneSpec = stageSpec.zones[zone] or stageSpec.zones.gate
	return zoneSpec.pos, zoneSpec.rot, stageSpec.sootAlpha, stageSpec.hideUpper
end

local function computeTargetCFrame(restCF: CFrame, posOffset: Vector3, rotOffset: CFrame): CFrame
	return CFrame.new(restCF.Position + posOffset) * (restCF - restCF.Position) * rotOffset
end

local function computeStageTransparency(
	pieceName: string,
	rest: WallPartRest,
	stage: number,
	hideUpper: boolean
): number
	if hideUpper and rest.isUpperTrim then
		return 1
	end
	if stage == 2 and rest.isUpperTrim then
		local oddStr = string.match(pieceName, "^Merlon_(%d+)$")
			or string.match(pieceName, "^PortcullisPicket_(%d+)$")
		local oddIdx = if oddStr ~= nil then tonumber(oddStr) else nil
		if oddIdx ~= nil and oddIdx % 2 == 1 then
			return 1
		end
	end
	return rest.transparency
end

local function cancelTweenInMap(map: { [BasePart]: Tween? }, piece: BasePart): ()
	local prev = map[piece]
	if prev ~= nil then
		map[piece] = nil
		local cancelFn = (prev :: any).Cancel
		if type(cancelFn) == "function" then
			cancelFn(prev)
		end
	end
end

local function cancelPartTween(piece: BasePart): ()
	cancelTweenInMap(activeWallTweens, piece)
end

local function playTweenInMap(
	map: { [BasePart]: Tween? },
	piece: BasePart,
	info: TweenInfo,
	props: { [string]: any }
): ()
	cancelTweenInMap(map, piece)
	local tween = TweenService:Create(piece, info, props)
	map[piece] = tween
	local completed = (tween :: any).Completed
	if completed ~= nil and type(completed.Once) == "function" then
		completed:Once(function()
			if (map[piece] :: any) == tween then
				map[piece] = nil
			end
		end)
	end
	tween:Play()
end

local function playPartTween(piece: BasePart, info: TweenInfo, props: { [string]: any }): ()
	playTweenInMap(activeWallTweens, piece, info, props)
end

local function applyStagePoseToPart(
	arena: Instance,
	piece: BasePart,
	rest: WallPartRest,
	prevStage: number,
	stage: number
): ()
	local posOffset, rotOffset, sootAlpha, hideUpper =
		computeZoneStageOffset(rest.zone, rest.isUpperTrim, stage)
	local targetCF = computeTargetCFrame(rest.cf, posOffset, rotOffset)
	local targetColor = rest.color:Lerp(SOOT_TINT_COLOR, sootAlpha)
	local targetTrans = computeStageTransparency(piece.Name, rest, stage, hideUpper)
	local cframeProps: { [string]: any } = { CFrame = targetCF }
	local lookProps: { [string]: any } = { Color = targetColor, Transparency = targetTrans }

	if IS_ROBLOX_RUNTIME and stage == 4 and prevStage ~= 4 then
		cancelPartTween(piece)
		cancelTweenInMap(activeWallLookTweens, piece)
		local delaySec = ZONE_COLLAPSE_DELAY[rest.zone] or 0
		if delaySec <= 0 then
			playPartTween(piece, COLLAPSE_TWEEN_INFO, cframeProps)
			playTweenInMap(activeWallLookTweens, piece, COLLAPSE_TWEEN_INFO, lookProps)
		else
			task.delay(delaySec, function()
				if piece.Parent == nil then
					return
				end
				if (tonumber(arena:GetAttribute("WallDamageStage")) or 0) == 4 then
					playPartTween(piece, COLLAPSE_TWEEN_INFO, cframeProps)
					playTweenInMap(activeWallLookTweens, piece, COLLAPSE_TWEEN_INFO, lookProps)
				end
			end)
		end
		return
	end

	if IS_ROBLOX_RUNTIME and stage >= 1 and stage <= 3 and prevStage ~= stage then
		playPartTween(piece, STAGE_POSE_TWEEN_INFO, cframeProps)
		playTweenInMap(activeWallLookTweens, piece, STAGE_POSE_TWEEN_INFO, lookProps)
		return
	end

	cancelPartTween(piece)
	cancelTweenInMap(activeWallLookTweens, piece)
	piece.CFrame = targetCF
	piece.Color = targetColor
	piece.Transparency = targetTrans
end

local function updateWallTorchFlames(arena: Instance, extinguished: boolean): ()
	local grass = arena:FindFirstChild("GrassTerrace")
	if grass ~= nil then
		for _, attachName in ipairs({ "WallTorchFxL", "WallTorchFxR" }) do
			local att = grass:FindFirstChild(attachName)
			if att ~= nil then
				for _, child in ipairs(att:GetChildren()) do
					if child:IsA("PointLight") then
						child.Brightness = if extinguished then 0 else 0.85
					elseif child:IsA("ParticleEmitter") then
						child.Enabled = not extinguished
					end
				end
			end
		end
	end

	local blocks = arena:FindFirstChild("WallBlocks")
	if blocks ~= nil then
		for _, flameName in ipairs({ "TorchGateL_Flame", "TorchGateR_Flame" }) do
			local flame = blocks:FindFirstChild(flameName)
			if flame ~= nil and flame:IsA("BasePart") then
				for _, child in ipairs(flame:GetChildren()) do
					if child:IsA("PointLight") then
						child.Brightness = if extinguished then 0 else 0.85
					end
				end
			end
		end
	end
end

local function decorPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local piece = part(parent, name, size, cframe, color, material)
	piece.CastShadow = false
	return piece
end

local function spawnWallFireEmitter(
	parent: Instance,
	name: string,
	position: Vector3,
	fireColor: Color3,
	intensity: number
): ()
	local host = decorPart(
		parent,
		name,
		Vector3.new(0.4, 0.4, 0.4),
		CFrame.new(position),
		fireColor,
		Enum.Material.SmoothPlastic
	)
	host.Transparency = 1

	local fire = Instance.new("ParticleEmitter")
	fire.Name = "FireParticles"
	fire.Enabled = true
	fire.EmissionDirection = Enum.NormalId.Top
	fire.LightEmission = 0.85
	fire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 226, 132)),
		ColorSequenceKeypoint.new(0.45, fireColor),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 36, 12)),
	})
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45 * intensity),
		NumberSequenceKeypoint.new(0.45, 0.9 * intensity),
		NumberSequenceKeypoint.new(1, 0.18),
	})
	fire.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.6, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	fire.Rate = math.min(40, math.round(12 * intensity))
	fire.Lifetime = NumberRange.new(0.45, 0.85)
	fire.Speed = NumberRange.new(1.8, 3.6)
	fire.SpreadAngle = Vector2.new(24, 24)
	fire.Acceleration = Vector3.new(0, 2.8, 0)
	fire.Rotation = NumberRange.new(0, 360)
	fire.RotSpeed = NumberRange.new(-90, 90)
	fire.Parent = host

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "SmokeParticles"
	smoke.Enabled = true
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.LightEmission = 0
	smoke.Color = ColorSequence.new(Color3.fromRGB(40, 36, 44), Color3.fromRGB(20, 18, 22))
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.65 * intensity),
		NumberSequenceKeypoint.new(0.5, 1.35 * intensity),
		NumberSequenceKeypoint.new(1, 1.9 * intensity),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.55, 0.58),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Rate = math.min(40, math.round(9 * intensity))
	smoke.Lifetime = NumberRange.new(1.0, 1.7)
	smoke.Speed = NumberRange.new(1.4, 2.8)
	smoke.SpreadAngle = Vector2.new(28, 28)
	smoke.Acceleration = Vector3.new(-0.4, 2.2, 0)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-45, 45)
	smoke.Parent = host

	local light = Instance.new("PointLight")
	light.Name = "FireLight"
	light.Color = fireColor
	light.Brightness = 0.75 + intensity * 0.35
	light.Range = 12 + intensity * 3
	light.Shadows = false
	light.Parent = host
end

local function rebuildWallDamageDecor(arena: Instance, origin: Vector3, stage: number): ()
	local existing = arena:FindFirstChild("WallDamageDecor")
	if existing ~= nil then
		existing:Destroy()
	end
	if stage <= 0 then
		return
	end

	local decor = Instance.new("Folder")
	decor.Name = "WallDamageDecor"
	decor.Parent = arena

	local wallX = origin.X + GridLayout.WALL_X
	local fireZs = STAGE_FIRE_Z_POSITIONS[stage] or STAGE_FIRE_Z_POSITIONS[4]

	if stage < 4 then
		local seamCount = 3 * stage
		for i = 1, seamCount do
			local frac = if seamCount > 1 then (i - 1) / (seamCount - 1) else 0.5
			local z = -16 + frac * 32
			local y = 2.8 + ((i * 7) % 5) * 0.85
			local len = 2.6 + (i % 3) * 0.75
			local tilt = (if i % 2 == 0 then 1 else -1) * (18 + (i % 4) * 7)
			local yaw = ((i % 3) - 1) * 8
			local seamRot = degAngles(tilt, yaw, 0)
			decorPart(
				decor,
				"WallCrackSeam_" .. tostring(i),
				Vector3.new(0.28, len, 0.26),
				CFrame.new(wallX + 1.45, origin.Y + y, origin.Z + z) * seamRot,
				WALL_CRACK_COLOR,
				Enum.Material.Slate
			)
			if stage >= 2 then
				local glow = decorPart(
					decor,
					"WallFissureGlow_" .. tostring(i),
					Vector3.new(0.20, len * 0.72, 0.14),
					CFrame.new(wallX + 1.38, origin.Y + y, origin.Z + z) * seamRot,
					WALL_FISSURE_GLOW_COLOR,
					Enum.Material.Neon
				)
				glow.Transparency = if stage == 2 then 0.25 else 0.10
			end
		end

		for i, fz in ipairs(fireZs) do
			local fy = 5.5 + ((i - 1) % 3) * 0.8
			spawnWallFireEmitter(
				decor,
				"WallStageFire_" .. tostring(i),
				Vector3.new(wallX + 1.35, origin.Y + fy, origin.Z + fz),
				WALL_FISSURE_GLOW_COLOR,
				0.9 + stage * 0.2
			)
		end

		local rubbleCount = stage * 4
		for i = 1, rubbleCount do
			local frac = if rubbleCount > 1 then (i - 1) / (rubbleCount - 1) else 0.5
			local rz = -17 + frac * 34
			local rx = wallX + 1.6 + ((i * 3) % 5) * 0.3
			local ry = origin.Y + 0.5 + ((i * 5) % 4) * 0.22
			local useWood = i % 3 == 0
			local color = if useWood
				then rgb(VisualTheme.PALETTE.woodDark)
				elseif i % 2 == 0 then rgb(VisualTheme.PALETTE.stone)
				else rgb(VisualTheme.PALETTE.stoneDark)
			local mat = if useWood then Enum.Material.WoodPlanks else Enum.Material.Slate
			local size = Vector3.new(
				0.9 + (i % 3) * 0.45,
				0.55 + (i % 2) * 0.32,
				1.05 + ((i + 1) % 3) * 0.48
			)
			local rot = degAngles((i * 17) % 35 - 15, (i * 43) % 180, (i * 23) % 30 - 15)
			decorPart(
				decor,
				"WallStageRubble_" .. tostring(i),
				size,
				CFrame.new(rx, ry, origin.Z + rz) * rot,
				color,
				mat
			)
		end
		return
	end

	local rubblePile = Instance.new("Folder")
	rubblePile.Name = "WallRubblePile"
	rubblePile.Parent = decor

	for i = 1, 18 do
		local frac = (i - 1) / 17
		local rz = -21 + frac * 42
		local rx = wallX - 2.0 + (((i * 7) % 13) / 12) * 4.8
		local ry = origin.Y + 0.45 + (((i * 5) % 9) / 8) * 1.75
		local rot = degAngles(-25 + (i * 19) % 50, (i * 47) % 180, -28 + (i * 23) % 56)

		local kind = i % 3
		local size: Vector3
		local color: Color3
		local mat: Enum.Material
		if kind == 1 then
			size = Vector3.new(2.2 + (i % 3) * 0.6, 0.65 + (i % 2) * 0.4, 2.0 + (i % 4) * 0.4)
			color = if i % 2 == 0
				then rgb(VisualTheme.PALETTE.stone)
				else rgb(VisualTheme.PALETTE.stoneDark)
			mat = Enum.Material.Slate
		elseif kind == 2 then
			size = Vector3.new(0.55, 0.52, 4.0 + (i % 3) * 0.7)
			color = if i % 2 == 0
				then rgb(VisualTheme.PALETTE.wood)
				else rgb(VisualTheme.PALETTE.woodDark)
			mat = Enum.Material.WoodPlanks
		else
			size = Vector3.new(0.34, 0.24, 3.0 + (i % 3) * 0.6)
			color = if i % 2 == 0
				then rgb(VisualTheme.PALETTE.iron)
				else rgb(VisualTheme.PALETTE.ironDark)
			mat = Enum.Material.Metal
		end

		decorPart(
			rubblePile,
			"WallRubble_" .. tostring(i),
			size,
			CFrame.new(rx, ry, origin.Z + rz) * rot,
			color,
			mat
		)
	end

	for i, bz in ipairs(fireZs) do
		local bx = wallX + 0.4 + ((i - 1) % 3) * 0.45
		local by = origin.Y + 0.8 + ((i - 1) % 2) * 0.55
		spawnWallFireEmitter(
			decor,
			"WallStageFire_" .. tostring(i),
			Vector3.new(bx, by, origin.Z + bz),
			WALL_BREACH_FIRE_COLOR,
			1.35
		)
	end
end

function ArenaVisual.setWallDamageStage(
	parent: Instance,
	wallPct: number,
	_hitLane: number?
): number
	local arena = findArena(parent)
	if arena == nil then
		return 0
	end

	local rawPct = tonumber(wallPct)
	local pct = if rawPct ~= nil and rawPct == rawPct then math.clamp(rawPct, 0, 1) else 1
	local stage: number
	if pct > 0.75 then
		stage = 0
	elseif pct > 0.50 then
		stage = 1
	elseif pct > 0.25 then
		stage = 2
	elseif pct > 0.0001 then
		stage = 3
	else
		stage = 4
	end

	local prevStage = tonumber(arena:GetAttribute("WallDamageStage")) or 0
	arena:SetAttribute("WallDamageStage", stage)
	arena:SetAttribute("WallHpPct", pct)

	local origin = getArenaOrigin(arena)
	for _, piece in ipairs(collectWallParts(arena)) do
		local rest = ensureWallPartRest(piece, origin.Z)
		local appliedStage = wallPartAppliedStage[piece] or 0
		if appliedStage ~= stage or prevStage ~= stage then
			wallPartAppliedStage[piece] = stage
			applyStagePoseToPart(arena, piece, rest, prevStage, stage)
		end
	end

	updateWallTorchFlames(arena, stage >= 4)

	if stage == 0 then
		local decor = arena:FindFirstChild("WallDamageDecor")
		if decor ~= nil then
			decor:Destroy()
		end
	elseif prevStage ~= stage or arena:FindFirstChild("WallDamageDecor") == nil then
		rebuildWallDamageDecor(arena, origin, stage)
	end

	return stage
end

function ArenaVisual.pulseWallImpact(
	parent: Instance,
	lane: number?,
	severity: number?,
	span: number?
): Vector3
	local rawLane = tonumber(lane)
	local laneClamped =
		math.clamp(math.round(if rawLane ~= nil and rawLane == rawLane then rawLane else 3), 1, 5)
	local hitZ = (laneClamped - 3) * 8

	local arena = findArena(parent)
	local origin = if arena ~= nil then getArenaOrigin(arena) else Vector3.zero
	local hitPos = origin + Vector3.new(GridLayout.WALL_X + 1.6, 3.2, hitZ)

	if arena == nil or (tonumber(arena:GetAttribute("WallDamageStage")) or 0) >= 4 then
		return hitPos
	end

	local rawSev = tonumber(severity)
	local sev = math.clamp(if rawSev ~= nil and rawSev == rawSev then rawSev else 1, 0, 2.5)
	if sev <= 0 then
		return hitPos
	end

	local rawSpan = tonumber(span)
	local spanVal = if rawSpan ~= nil and rawSpan == rawSpan then math.round(rawSpan) else 1
	local weights = if spanVal >= 3
		then WIDE_IMPACT_WEIGHTS
		else (LANE_IMPACT_WEIGHTS[laneClamped] or LANE_IMPACT_WEIGHTS[3])

	local stage = math.clamp(tonumber(arena:GetAttribute("WallDamageStage")) or 0, 0, 4)

	for _, piece in ipairs(collectWallParts(arena)) do
		local rest = ensureWallPartRest(piece, origin.Z)
		local w = weights[rest.zone]
		if w ~= nil and w > 0 then
			local posOffset, rotOffset, _, hideUpper =
				computeZoneStageOffset(rest.zone, rest.isUpperTrim, stage)
			local stageTrans = computeStageTransparency(piece.Name, rest, stage, hideUpper)
			if stageTrans < 0.99 then
				local stageCF = computeTargetCFrame(rest.cf, posOffset, rotOffset)
				local recoilPos = Vector3.new(-0.65 * sev * w, -0.14 * sev * w, 0)
				local recoilRot = degAngles(2.5 * sev * w, 0, 3.8 * sev * w)
				local recoilCF = computeTargetCFrame(stageCF, recoilPos, recoilRot)

				cancelPartTween(piece)
				piece.CFrame = recoilCF
				playPartTween(piece, IMPACT_RECOVERY_TWEEN_INFO, { CFrame = stageCF })
			end
		end
	end

	return hitPos
end

function ArenaVisual.destroy(parent: Instance): ()
	clearExisting(parent)
end

return ArenaVisual

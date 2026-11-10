--!nonstrict
-- S8: diorama da arena 5x5. Constroi a plataforma, as 5 lanes, a muralha/portao, o portal de
-- spawn, tochas/estandartes e pedras de fundo. Tudo client-side e cosmetico: o servidor continua
-- dono das celulas (BuildGrid) e da batalha (Core). Reutilizado no build, no drop-in e no replay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualTheme = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("VisualTheme")
)
local GridLayout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("build"):WaitForChild("GridLayout")
)

local ArenaVisual = {}

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

local function wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local piece = Instance.new("WedgePart")
	piece.Name = name
	piece.Size = size
	piece.CFrame = cframe
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Color = color
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
	-- Cylinder do Roblox tem eixo em X; girar em Z deixa o eixo em Y (torre/barril vertical).
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
	local piece = part(parent, name, size, cframe, color, Enum.Material.Neon)
	return piece
end

local function banner(
	parent: Instance,
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3
): ()
	local pole = part(
		parent,
		name .. "_Pole",
		Vector3.new(0.22, size.Y + 0.6, 0.22),
		CFrame.new(position + Vector3.new(0, size.Y * 0.5, 0)),
		rgb(VisualTheme.PALETTE.woodDark),
		Enum.Material.Wood
	)
	pole.CanQuery = false
	local cloth = part(
		parent,
		name .. "_Cloth",
		size,
		CFrame.new(position + Vector3.new(0, size.Y * 0.5, 0)),
		color,
		Enum.Material.Fabric
	)
	cloth.CanQuery = false
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
	light.Brightness = 0.8
	light.Range = 16
	light.Shadows = false
	light.Parent = flame
end

local function rock(parent: Instance, name: string, position: Vector3, scale: number): ()
	local piece = part(
		parent,
		name,
		Vector3.new(scale * 2.2, scale * 1.4, scale * 1.8),
		CFrame.new(position) * CFrame.Angles(0, math.rad((scale * 47) % 360), math.rad(8)),
		rgb(VisualTheme.PALETTE.stone),
		Enum.Material.Slate
	)
	piece.Shape = Enum.PartType.Ball
end

local function clearExisting(parent: Instance): ()
	local existing = parent:FindFirstChild("MuralhaArena")
	if existing ~= nil then
		existing:Destroy()
	end
end

function ArenaVisual.build(parent: Instance, origin: Vector3, options: any?): Folder
	clearExisting(parent)
	local opts = options or {}
	local dropIn = opts.dropIn == true
	local folder = Instance.new("Folder")
	folder.Name = "MuralhaArena"
	folder.Parent = parent
	folder:SetAttribute("OriginX", origin.X)
	folder:SetAttribute("OriginZ", origin.Z)

	-- Plataforma e moldura de pedra/madeira.
	part(
		folder,
		"Base",
		Vector3.new(68, 2, 52),
		CFrame.new(origin + Vector3.new(0, -1, 0)),
		rgb(VisualTheme.PALETTE.stoneDark),
		Enum.Material.Slate
	)
	part(
		folder,
		"BaseTop",
		Vector3.new(66, 0.35, 50),
		CFrame.new(origin + Vector3.new(0, 0.05, 0)),
		rgb(VisualTheme.PALETTE.stone),
		Enum.Material.Cobblestone
	)
	part(
		folder,
		"BaseTrim",
		Vector3.new(70, 0.6, 54),
		CFrame.new(origin + Vector3.new(0, -1.8, 0)),
		rgb(VisualTheme.PALETTE.woodDark),
		Enum.Material.WoodPlanks
	)

	-- 5 lanes com sulcos escuros e fio de ambar entre elas.
	for lane = 1, 5 do
		local z = (lane - 3) * GridLayout.CELL_SIZE
		part(
			folder,
			"Lane_" .. tostring(lane),
			Vector3.new(48, 0.16, 6.6),
			CFrame.new(origin + Vector3.new(1, 0.25, z)),
			rgb(VisualTheme.PALETTE.ironDark),
			Enum.Material.Slate
		)
		part(
			folder,
			"LaneInlay_" .. tostring(lane),
			Vector3.new(48, 0.08, 0.24),
			CFrame.new(origin + Vector3.new(1, 0.36, z + 3.4)),
			rgb(VisualTheme.PALETTE.amber),
			Enum.Material.SmoothPlastic
		)
	end

	-- Muralha: madeira com cintas de ferro, portao central e torres.
	local wallX = GridLayout.WALL_X
	part(
		folder,
		"WallBody",
		Vector3.new(2.6, 8.4, 42),
		CFrame.new(origin + Vector3.new(wallX, 4.2, 0)),
		rgb(VisualTheme.PALETTE.wood),
		Enum.Material.WoodPlanks
	)
	for band = 1, 3 do
		part(
			folder,
			"WallBand_" .. tostring(band),
			Vector3.new(3.0, 0.45, 42.4),
			CFrame.new(origin + Vector3.new(wallX, band * 2.1, 0)),
			rgb(VisualTheme.PALETTE.iron),
			Enum.Material.Metal
		)
	end
	part(
		folder,
		"Gate",
		Vector3.new(3.1, 6.6, 8),
		CFrame.new(origin + Vector3.new(wallX + 0.2, 3.3, 0)),
		rgb(VisualTheme.PALETTE.woodDark),
		Enum.Material.WoodPlanks
	)
	for stud = 1, 4 do
		part(
			folder,
			"GateStud_" .. tostring(stud),
			Vector3.new(0.18, 0.6, 0.6),
			CFrame.new(origin + Vector3.new(wallX + 1.8, 1.2 + stud * 1.3, 0)),
			rgb(VisualTheme.PALETTE.iron),
			Enum.Material.Metal
		)
	end
	for tower = -1, 1, 2 do
		local z = tower * 22
		cylinder(
			folder,
			"Tower_" .. tostring(tower),
			Vector3.new(10, 4.4, 4.4),
			CFrame.new(origin + Vector3.new(wallX, 5, z)),
			rgb(VisualTheme.PALETTE.wood),
			Enum.Material.WoodPlanks
		)
		cylinder(
			folder,
			"TowerRoof_" .. tostring(tower),
			Vector3.new(4.6, 5.4, 5.4),
			CFrame.new(origin + Vector3.new(wallX, 11.2, z)),
			rgb(VisualTheme.PALETTE.iron),
			Enum.Material.Metal
		)
		banner(
			folder,
			"Banner_" .. tostring(tower),
			origin + Vector3.new(wallX + 2.2, 6.2, z),
			Vector3.new(0.12, 3.6, 2.2),
			rgb(VisualTheme.PALETTE.amber)
		)
	end

	-- Crenas e tochas do portao.
	for merlon = -4, 4 do
		part(
			folder,
			"Merlon_" .. tostring(merlon),
			Vector3.new(2.2, 1.2, 2.0),
			CFrame.new(origin + Vector3.new(wallX, 8.6, merlon * 4.2)),
			rgb(VisualTheme.PALETTE.woodDark),
			Enum.Material.WoodPlanks
		)
	end
	torch(
		folder,
		"TorchGateL",
		origin + Vector3.new(wallX + 1.8, 0, -5.5),
		Color3.fromRGB(255, 178, 80)
	)
	torch(
		folder,
		"TorchGateR",
		origin + Vector3.new(wallX + 1.8, 0, 5.5),
		Color3.fromRGB(255, 178, 80)
	)

	-- Portal de spawn (verde-agua) no lado oposto.
	local spawnX = 25
	for side = -1, 1, 2 do
		part(
			folder,
			"PortalPillar_" .. tostring(side),
			Vector3.new(2.2, 8.4, 2.2),
			CFrame.new(origin + Vector3.new(spawnX, 4.2, side * 4.2)),
			rgb(VisualTheme.PALETTE.stoneDark),
			Enum.Material.Slate
		)
	end
	part(
		folder,
		"PortalLintel",
		Vector3.new(2.4, 1.8, 10.2),
		CFrame.new(origin + Vector3.new(spawnX, 8.4, 0)),
		rgb(VisualTheme.PALETTE.stone),
		Enum.Material.Slate
	)
	local portal = neon(
		folder,
		"Portal",
		Vector3.new(0.5, 7, 7),
		CFrame.new(origin + Vector3.new(spawnX - 0.2, 4.4, 0)),
		rgb(VisualTheme.PALETTE.teal)
	)
	portal.Transparency = 0.35
	local portalLight = Instance.new("PointLight")
	portalLight.Color = rgb(VisualTheme.PALETTE.teal)
	portalLight.Brightness = 0.9
	portalLight.Range = 18
	portalLight.Shadows = false
	portalLight.Parent = portal

	-- Fundo: penhascos e pedras; nao bloqueiam a camera isometrica.
	for index = 1, 6 do
		local x = -18 + index * 7
		rock(
			folder,
			"RockBack_" .. tostring(index),
			origin + Vector3.new(x, 0.8, -27 - (index % 2) * 2),
			1.4 + (index % 3) * 0.35
		)
		rock(
			folder,
			"RockSide_" .. tostring(index),
			origin + Vector3.new(-30 - (index % 2), 0.7, -18 + index * 6),
			1.1 + (index % 2) * 0.3
		)
	end
	for index = 1, 4 do
		wedge(
			folder,
			"Cliff_" .. tostring(index),
			Vector3.new(20, 8 + index * 2, 7),
			CFrame.new(origin + Vector3.new(18 - index * 10, 3, -31 - index * 2)),
			rgb(VisualTheme.PALETTE.stoneDark),
			Enum.Material.Slate
		)
	end

	-- Barris/caixotes perto da muralha (profundidade e escala).
	for index = 1, 4 do
		local z = -14 + index * 7
		cylinder(
			folder,
			"Barrel_" .. tostring(index),
			Vector3.new(2.2, 1.8, 1.8),
			CFrame.new(origin + Vector3.new(wallX + 4.2, 1.1, z)),
			rgb(VisualTheme.PALETTE.wood),
			Enum.Material.WoodPlanks
		)
		part(
			folder,
			"BarrelBand_" .. tostring(index),
			Vector3.new(2.4, 0.18, 2.0),
			CFrame.new(origin + Vector3.new(wallX + 4.2, 1.5, z)),
			rgb(VisualTheme.PALETTE.iron),
			Enum.Material.Metal
		)
	end

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

	return folder
end

function ArenaVisual.destroy(parent: Instance): ()
	clearExisting(parent)
end

return ArenaVisual

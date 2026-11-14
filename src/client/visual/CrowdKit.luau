--!strict
-- Torcida / arquibancada perimetral em folder irmao "MuralhaCrowd" (fora de "MuralhaArena").
-- Puramente client-side, partes inertes (Anchored=true, CanCollide/CanQuery/CanTouch=false),
-- <= 135 BaseParts no total, animacao em lote unico no RunService.Heartbeat e reacoes por evento.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MeshAssets = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("MeshAssets")
)
local VisualTheme = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("VisualTheme")
)

local CrowdKit = {}

local FOLDER_NAME = "MuralhaCrowd"
local GOLDEN_RATIO = 0.6180339

export type CrowdEventKind = "cheer" | "combo" | "gasp" | "boss" | "victory" | "defeat"

export type CrowdHandle = {
	folder: Folder,
	react: (self: CrowdHandle, eventKind: CrowdEventKind) -> (),
	destroy: (self: CrowdHandle) -> (),
}

type SpectatorPiece = {
	part: BasePart,
	localCF: CFrame,
}

type StandSeat = {
	faction: "bastion" | "horde",
	archetype: string,
	x: number,
	tier: number,
}

type Spectator = {
	model: Model,
	faction: "bastion" | "horde",
	archetype: string,
	baseCF: CFrame,
	phase: number,
	scale: number,
	bodyPieces: { SpectatorPiece },
	armL: BasePart,
	armR: BasePart,
	armLOffset: Vector3,
	armROffset: Vector3,
	hasHordeMesh: boolean,
}

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.CFrame = cf
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	if shape ~= nil then
		piece.Shape = shape
	end
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = true
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function makeEllipsoid(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local piece = makePart(parent, name, size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = piece
	return piece
end

local function buildStands(folder: Folder, origin: Vector3): ()
	local woodColor = rgb(VisualTheme.PALETTE.wood)
	local woodDarkColor = rgb(VisualTheme.PALETTE.woodDark)
	local stoneColor = rgb(VisualTheme.PALETTE.stone)
	local stoneDarkColor = rgb(VisualTheme.PALETTE.stoneDark)
	local ironDarkColor = rgb(VisualTheme.PALETTE.ironDark)

	-- Arquibancada Norte: origin + ([-14..14], 0.35, -24.5), voltada para +Z (sul / arena).
	local northOrigin = origin + Vector3.new(0, 0.35, -24.5)
	local northCF = CFrame.lookAt(northOrigin, northOrigin + Vector3.new(0, 0, 1))
	makePart(
		folder,
		"NorthDeck",
		Vector3.new(28.4, 0.7, 5.2),
		northCF * CFrame.new(0, 0.35, 0.2),
		stoneDarkColor,
		Enum.Material.Slate
	)
	makePart(
		folder,
		"NorthTier1",
		Vector3.new(27.6, 0.45, 1.8),
		northCF * CFrame.new(0, 0.92, -0.9),
		woodColor,
		Enum.Material.WoodPlanks
	)
	makePart(
		folder,
		"NorthTier2",
		Vector3.new(27.6, 0.95, 1.8),
		northCF * CFrame.new(0, 1.18, 1.1),
		woodDarkColor,
		Enum.Material.WoodPlanks
	)
	makePart(
		folder,
		"NorthBackRail",
		Vector3.new(27.8, 0.28, 0.26),
		northCF * CFrame.new(0, 2.45, 2.2),
		woodColor,
		Enum.Material.WoodPlanks
	)
	makePart(
		folder,
		"NorthPostL",
		Vector3.new(0.42, 2.6, 0.42),
		northCF * CFrame.new(-13.6, 1.3, 2.2),
		ironDarkColor,
		Enum.Material.Metal
	)
	makePart(
		folder,
		"NorthPostR",
		Vector3.new(0.42, 2.6, 0.42),
		northCF * CFrame.new(13.6, 1.3, 2.2),
		ironDarkColor,
		Enum.Material.Metal
	)

	-- Arquibancada Sul: origin + ([-11..11], 0.35, 24.5), voltada para -Z (norte / arena).
	local southOrigin = origin + Vector3.new(0, 0.35, 24.5)
	local southCF = CFrame.lookAt(southOrigin, southOrigin + Vector3.new(0, 0, -1))
	makePart(
		folder,
		"SouthDeck",
		Vector3.new(22.4, 0.7, 5.2),
		southCF * CFrame.new(0, 0.35, 0.2),
		stoneDarkColor,
		Enum.Material.Slate
	)
	makePart(
		folder,
		"SouthTier1",
		Vector3.new(21.6, 0.45, 1.8),
		southCF * CFrame.new(0, 0.92, -0.9),
		woodColor,
		Enum.Material.WoodPlanks
	)
	makePart(
		folder,
		"SouthTier2",
		Vector3.new(21.6, 0.95, 1.8),
		southCF * CFrame.new(0, 1.18, 1.1),
		woodDarkColor,
		Enum.Material.WoodPlanks
	)
	makePart(
		folder,
		"SouthBackRail",
		Vector3.new(21.8, 0.28, 0.26),
		southCF * CFrame.new(0, 2.45, 2.2),
		woodColor,
		Enum.Material.WoodPlanks
	)
	makePart(
		folder,
		"SouthPostL",
		Vector3.new(0.42, 2.6, 0.42),
		southCF * CFrame.new(-10.6, 1.3, 2.2),
		ironDarkColor,
		Enum.Material.Metal
	)
	makePart(
		folder,
		"SouthPostR",
		Vector3.new(0.42, 2.6, 0.42),
		southCF * CFrame.new(10.6, 1.3, 2.2),
		ironDarkColor,
		Enum.Material.Metal
	)

	-- Passarela do Bastiao (Oeste): origin + (-25.8, 5.8, [-10..10]), voltada para +X (leste).
	local rampOrigin = origin + Vector3.new(-25.8, 5.8, 0)
	local rampCF = CFrame.lookAt(rampOrigin, rampOrigin + Vector3.new(1, 0, 0))
	makePart(
		folder,
		"RampartWalk",
		Vector3.new(20.4, 0.36, 2.4),
		rampCF * CFrame.new(0, -0.18, 0),
		woodDarkColor,
		Enum.Material.WoodPlanks
	)
	makePart(
		folder,
		"RampartParapet",
		Vector3.new(20.4, 0.42, 0.32),
		rampCF * CFrame.new(0, 0.21, -1.05),
		stoneColor,
		Enum.Material.Slate
	)
end

local function paletteForArchetype(
	faction: "bastion" | "horde",
	archetype: string
): (Color3, Color3, number)
	if faction == "horde" then
		local spec = (VisualTheme.ENEMIES :: { [string]: any })[archetype]
		if spec ~= nil then
			return rgb(spec.color), rgb(spec.dark), math.clamp(spec.scale * 0.86, 0.62, 1.08)
		end
		return rgb(VisualTheme.PALETTE.teal), rgb(VisualTheme.PALETTE.tealDark), 0.78
	end
	if archetype == "vorn" then
		return rgb(VisualTheme.PALETTE.amber), rgb(VisualTheme.PALETTE.iron), 0.98
	elseif archetype == "brasa" then
		return rgb(VisualTheme.PALETTE.danger), rgb(VisualTheme.PALETTE.ironDark), 0.94
	elseif archetype == "engineer" then
		return rgb(VisualTheme.PALETTE.iron), rgb(VisualTheme.PALETTE.amberBright), 0.86
	end
	return rgb(VisualTheme.TRAPS.archer.color), rgb(VisualTheme.PALETTE.woodDark), 0.84
end

local function tryMountHordeSpectatorMesh(spec: Spectator): boolean
	if spec.faction ~= "horde" or spec.hasHordeMesh then
		return spec.hasHordeMesh
	end
	local assets = ReplicatedStorage:FindFirstChild(MeshAssets.FOLDER)
	if assets == nil then
		return false
	end
	local template = assets:FindFirstChild(MeshAssets.hordeModelName(spec.archetype))
	if template == nil then
		return false
	end

	local clone = template:Clone()
	clone.Name = "MeshVisual"
	local targetH = 1.95 * spec.scale
	local newPieces: { SpectatorPiece } = {}

	if clone:IsA("Model") then
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
				desc.CanQuery = false
				desc.CanTouch = false
			end
		end
		clone.Parent = spec.model
		local _, rawSize = clone:GetBoundingBox()
		if rawSize.Y > 0.05 then
			clone:ScaleTo(clone:GetScale() * (targetH / rawSize.Y))
		end
		local bbCf, bbSize = clone:GetBoundingBox()
		local bottomCenter =
			Vector3.new(bbCf.Position.X, bbCf.Position.Y - bbSize.Y * 0.5, bbCf.Position.Z)
		local toLocal = CFrame.new(-bottomCenter)
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") then
				newPieces[#newPieces + 1] = {
					part = desc,
					localCF = toLocal * desc.CFrame,
				}
			end
		end
	elseif clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		if clone.Size.Y > 0.05 then
			clone.Size = clone.Size * (targetH / clone.Size.Y)
		end
		local localCF = CFrame.new(0, clone.Size.Y * 0.5, 0) * clone.CFrame.Rotation
		clone.Parent = spec.model
		newPieces[#newPieces + 1] = {
			part = clone,
			localCF = localCF,
		}
	else
		clone:Destroy()
		return false
	end

	if #newPieces == 0 then
		clone:Destroy()
		return false
	end

	for _, old in ipairs(spec.bodyPieces) do
		old.part:Destroy()
	end
	spec.bodyPieces = newPieces
	spec.hasHordeMesh = true
	return true
end

local function createSpectator(
	folder: Folder,
	index: number,
	faction: "bastion" | "horde",
	archetype: string,
	seatPos: Vector3,
	facingDir: Vector3
): Spectator
	local primary, secondary, s = paletteForArchetype(faction, archetype)
	local model = Instance.new("Model")
	model.Name = string.format("Spectator_%d_%s", index, archetype)
	model.Parent = folder

	local baseCF = CFrame.lookAt(seatPos, seatPos + facingDir)
	local torsoCF = CFrame.new(0, 0.72 * s, 0)
	local headCF = CFrame.new(0, 1.56 * s, -0.02 * s)

	local torso = makeEllipsoid(
		model,
		"Torso",
		Vector3.new(0.92 * s, 1.18 * s, 0.64 * s),
		baseCF * torsoCF,
		primary
	)
	local head = makePart(
		model,
		"Head",
		Vector3.new(0.68 * s, 0.68 * s, 0.68 * s),
		baseCF * headCF,
		secondary,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	local armSize = Vector3.new(0.24 * s, 0.86 * s, 0.26 * s)
	local armLOffset = Vector3.new(-0.56 * s, 1.06 * s, -0.06 * s)
	local armROffset = Vector3.new(0.56 * s, 1.06 * s, -0.06 * s)
	local armL = makeEllipsoid(model, "ArmL", armSize, baseCF * CFrame.new(armLOffset), secondary)
	local armR = makeEllipsoid(model, "ArmR", armSize, baseCF * CFrame.new(armROffset), secondary)

	local spec: Spectator = {
		model = model,
		faction = faction,
		archetype = archetype,
		baseCF = baseCF,
		phase = ((index * GOLDEN_RATIO) % 1) * math.pi * 2,
		scale = s,
		bodyPieces = {
			{ part = torso, localCF = torsoCF },
			{ part = head, localCF = headCF },
		},
		armL = armL,
		armR = armR,
		armLOffset = armLOffset,
		armROffset = armROffset,
		hasHordeMesh = false,
	}
	tryMountHordeSpectatorMesh(spec)
	return spec
end

function CrowdKit.build(parent: Instance, origin: Vector3): CrowdHandle
	local existing = parent:FindFirstChild(FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = parent

	buildStands(folder, origin)

	local spectators: { Spectator } = {}
	local function spawn(
		faction: "bastion" | "horde",
		archetype: string,
		pos: Vector3,
		facing: Vector3
	): ()
		spectators[#spectators + 1] =
			createSpectator(folder, #spectators + 1, faction, archetype, pos, facing)
	end

	-- Passarela do Bastiao (-25.8, 5.8, [-10..10]), voltada para +X: 6 defensores.
	local eastDir = Vector3.new(1, 0, 0)
	local rampSeats = {
		{ archetype = "archer", z = -8.2 },
		{ archetype = "engineer", z = -5.0 },
		{ archetype = "vorn", z = -1.8 },
		{ archetype = "brasa", z = 1.8 },
		{ archetype = "engineer", z = 5.0 },
		{ archetype = "archer", z = 8.2 },
	}
	for _, seat in ipairs(rampSeats) do
		spawn("bastion", seat.archetype, origin + Vector3.new(-25.8, 5.8, seat.z), eastDir)
	end

	-- Arquibancada Norte ([-14..14], 0.35, -24.5), voltada para +Z: 10 espectadores (4 Bastiao + 6 Horda).
	local southDir = Vector3.new(0, 0, 1)
	local northSeats: { StandSeat } = {
		{ faction = "bastion", archetype = "archer", x = -12.0, tier = 1 },
		{ faction = "bastion", archetype = "engineer", x = -9.0, tier = 2 },
		{ faction = "bastion", archetype = "archer", x = -6.0, tier = 1 },
		{ faction = "bastion", archetype = "engineer", x = -3.0, tier = 2 },
		{ faction = "horde", archetype = "runner", x = 1.8, tier = 1 },
		{ faction = "horde", archetype = "shieldbearer", x = 4.2, tier = 2 },
		{ faction = "horde", archetype = "brute", x = 6.6, tier = 1 },
		{ faction = "horde", archetype = "pyromancer", x = 9.0, tier = 2 },
		{ faction = "horde", archetype = "sapper", x = 11.2, tier = 1 },
		{ faction = "horde", archetype = "swarm", x = 13.0, tier = 2 },
	}
	for _, seat in ipairs(northSeats) do
		local tierY = if seat.tier == 1 then 1.50 else 2.00
		local tierZ = if seat.tier == 1 then -23.6 else -25.6
		spawn(seat.faction, seat.archetype, origin + Vector3.new(seat.x, tierY, tierZ), southDir)
	end

	-- Arquibancada Sul ([-11..11], 0.35, 24.5), voltada para -Z: 8 espectadores (4 Bastiao + 4 Horda).
	local northDir = Vector3.new(0, 0, -1)
	local southSeats: { StandSeat } = {
		{ faction = "bastion", archetype = "archer", x = -9.5, tier = 1 },
		{ faction = "bastion", archetype = "engineer", x = -7.0, tier = 2 },
		{ faction = "bastion", archetype = "archer", x = -4.5, tier = 1 },
		{ faction = "bastion", archetype = "engineer", x = -2.0, tier = 2 },
		{ faction = "horde", archetype = "shieldbearer", x = 2.0, tier = 1 },
		{ faction = "horde", archetype = "pyromancer", x = 4.6, tier = 2 },
		{ faction = "horde", archetype = "sapper", x = 7.2, tier = 1 },
		{ faction = "horde", archetype = "runner", x = 9.6, tier = 2 },
	}
	for _, seat in ipairs(southSeats) do
		local tierY = if seat.tier == 1 then 1.50 else 2.00
		local tierZ = if seat.tier == 1 then 23.6 else 25.6
		spawn(seat.faction, seat.archetype, origin + Vector3.new(seat.x, tierY, tierZ), northDir)
	end

	local excitement = 0.0
	local reactionMode: CrowdEventKind? = nil
	local reactionUntil = 0.0
	local reactionStart = 0.0

	local function poseAll(now: number): ()
		if reactionMode ~= nil and now > reactionUntil then
			reactionMode = nil
		end
		local boost = excitement
		for _, spec in ipairs(spectators) do
			local waveOffset = (spec.baseCF.Position.X - origin.X) * 0.11
			local reactAge = now - reactionStart
			local wavePulse = if reactionMode ~= nil
				then math.max(0, 1 - math.abs(reactAge * 10 - (waveOffset + 3.2)) * 0.38)
				else 0

			local factionGain = 1.0
			local slump = 0.0
			if reactionMode == "victory" then
				if spec.faction == "bastion" then
					factionGain = 1.85
				else
					factionGain = 0.15
					slump = 0.25
				end
			elseif reactionMode == "defeat" then
				if spec.faction == "horde" then
					factionGain = 1.85
				else
					factionGain = 0.15
					slump = 0.25
				end
			elseif reactionMode == "gasp" then
				slump = 0.18 * wavePulse
			elseif reactionMode == "boss" and spec.faction == "horde" then
				factionGain = 1.65
			end

			local energy = (0.35 + boost * 1.15 + wavePulse * 0.75) * factionGain
			local freq = 4.5 + boost * 5.2
			local p = now * freq + spec.phase
			local hopY = math.max(0, math.sin(p)) * 0.26 * spec.scale * energy
			local leanX = math.sin(p * 0.5) * 0.10 * energy - slump
			local bodyCF = spec.baseCF * CFrame.new(0, hopY, 0) * CFrame.Angles(leanX, 0, 0)

			for _, piece in ipairs(spec.bodyPieces) do
				piece.part.CFrame = bodyCF * piece.localCF
			end

			local waveL = 0.55 + math.sin(p * 1.4) * (0.45 + 0.55 * energy) - slump * 2.2
			local waveR = 0.55 + math.cos(p * 1.4) * (0.45 + 0.55 * energy) - slump * 2.2
			spec.armL.CFrame = bodyCF
				* CFrame.new(spec.armLOffset)
				* CFrame.Angles(waveL, 0, math.rad(-14))
				* CFrame.new(0, 0.28 * spec.scale, 0)
			spec.armR.CFrame = bodyCF
				* CFrame.new(spec.armROffset)
				* CFrame.Angles(waveR, 0, math.rad(14))
				* CFrame.new(0, 0.28 * spec.scale, 0)
		end
	end

	local alive = true
	local startClock = os.clock()
	poseAll(0)

	local heartbeatConn: RBXScriptConnection? = nil
	local assetsConn: RBXScriptConnection? = nil
	local repConn: RBXScriptConnection? = nil
	local folderDestroyConn: RBXScriptConnection? = nil
	local parentDestroyConn: RBXScriptConnection? = nil

	local function disconnectAssetWatchers(): ()
		if assetsConn ~= nil then
			assetsConn:Disconnect()
			assetsConn = nil
		end
		if repConn ~= nil then
			repConn:Disconnect()
			repConn = nil
		end
	end

	local function flushHordeMeshes(): boolean
		local pending = false
		for _, spec in ipairs(spectators) do
			if spec.faction == "horde" and not spec.hasHordeMesh then
				if not tryMountHordeSpectatorMesh(spec) then
					pending = true
				end
			end
		end
		return pending
	end

	local function attachAssetsWatcher(assets: Instance): ()
		if not alive then
			return
		end
		if not flushHordeMeshes() then
			disconnectAssetWatchers()
			return
		end
		assetsConn = assets.ChildAdded:Connect(function(child: Instance)
			if not alive then
				disconnectAssetWatchers()
				return
			end
			if string.sub(child.Name, 1, 4) == "CMD_" then
				task.defer(function()
					if alive and not flushHordeMeshes() then
						disconnectAssetWatchers()
					end
				end)
			end
		end)
	end

	local existingAssets = ReplicatedStorage:FindFirstChild(MeshAssets.FOLDER)
	if existingAssets ~= nil then
		attachAssetsWatcher(existingAssets)
	else
		repConn = ReplicatedStorage.ChildAdded:Connect(function(child: Instance)
			if not alive then
				disconnectAssetWatchers()
				return
			end
			if child.Name == MeshAssets.FOLDER then
				if repConn ~= nil then
					repConn:Disconnect()
					repConn = nil
				end
				attachAssetsWatcher(child)
			end
		end)
	end

	local function cleanupConnections(): ()
		if not alive then
			return
		end
		alive = false
		if heartbeatConn ~= nil then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
		disconnectAssetWatchers()
		if folderDestroyConn ~= nil then
			folderDestroyConn:Disconnect()
			folderDestroyConn = nil
		end
		if parentDestroyConn ~= nil then
			parentDestroyConn:Disconnect()
			parentDestroyConn = nil
		end
	end

	folderDestroyConn = folder.Destroying:Connect(cleanupConnections)
	parentDestroyConn = parent.Destroying:Connect(cleanupConnections)

	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		if not alive or folder.Parent == nil then
			cleanupConnections()
			return
		end
		excitement = math.max(0, excitement - math.min(dt, 0.1) * 0.42)
		poseAll(os.clock() - startClock)
	end)

	local handle: CrowdHandle = {
		folder = folder,
		react = function(_self: CrowdHandle, eventKind: CrowdEventKind): ()
			if not alive then
				return
			end
			local now = os.clock() - startClock
			reactionMode = eventKind
			reactionStart = now
			if eventKind == "victory" or eventKind == "defeat" then
				excitement = 1.35
				reactionUntil = now + 4.0
			elseif eventKind == "boss" or eventKind == "combo" then
				excitement = math.min(1.4, excitement + 0.95)
				reactionUntil = now + 2.4
			elseif eventKind == "gasp" then
				excitement = math.min(1.2, excitement + 0.65)
				reactionUntil = now + 1.4
			else
				excitement = math.min(1.25, excitement + 0.70)
				reactionUntil = now + 1.8
			end
		end,
		destroy = function(_self: CrowdHandle): ()
			cleanupConnections()
			if folder.Parent ~= nil then
				folder:Destroy()
			end
		end,
	}

	return handle
end

return table.freeze(CrowdKit)

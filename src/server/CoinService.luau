--!strict
-- Moedas: nascem no servidor, sao coletadas no servidor.
-- O cliente so ve o resultado (leaderstats) -- ele nunca decide quanto ganhou.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local COIN_SIZE = Vector3.new(0.5, 2.4, 2.4)
local SPIN_SPEED = 1.6

local CoinService = {}

type CoinState = {
	part: Part,
	base: Vector3,
	phase: number,
	taken: boolean,
}

local coinsFolder: Folder
local states: { CoinState } = {}
local elapsed = 0

local function randomPosition(): Vector3
	local half = Config.Coins.AreaSize / 2
	return Vector3.new(
		(math.random() * 2 - 1) * half,
		Config.Coins.Height,
		(math.random() * 2 - 1) * half
	)
end

local function createCoin(position: Vector3): CoinState
	local part = Instance.new("Part")
	part.Name = "Coin"
	part.Shape = Enum.PartType.Cylinder
	part.Size = COIN_SIZE
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = true
	part.CanQuery = false
	part.Color = Color3.fromRGB(255, 196, 32)
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = coinsFolder

	local state: CoinState = {
		part = part,
		base = position,
		phase = math.random() * math.pi * 2,
		taken = false,
	}
	states[#states + 1] = state
	return state
end

local function characterFromHit(hit: BasePart): Model?
	local current: Instance? = hit
	while current do
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function award(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value += Config.Coins.Value
	end
end

local function collect(state: CoinState)
	if state.taken then
		return
	end
	state.taken = true
	state.part.CanTouch = false

	local tween = TweenService:Create(
		state.part,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Transparency = 1, CFrame = state.part.CFrame * CFrame.new(0, 4, 0) }
	)
	tween:Play()

	task.delay(Config.Coins.RespawnSeconds, function()
		if not state.part.Parent then
			return
		end
		state.base = randomPosition()
		state.part.Transparency = 0
		state.part.CFrame = CFrame.new(state.base)
		state.part.CanTouch = true
		state.taken = false
	end)
end

local function onTouched(state: CoinState, hit: BasePart)
	if state.taken then
		return
	end

	local character = characterFromHit(hit)
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	-- validacao de distancia: evita coletar moeda do outro lado do mapa via exploit
	if (root.Position - state.part.Position).Magnitude > 12 then
		return
	end

	collect(state)
	award(player)
end

function CoinService:Start()
	coinsFolder = Workspace:FindFirstChild("Coins")
	if not coinsFolder then
		coinsFolder = Instance.new("Folder")
		coinsFolder.Name = "Coins"
		coinsFolder.Parent = Workspace
	end

	for _ = 1, Config.Coins.Count do
		local state = createCoin(randomPosition())
		state.part.Touched:Connect(function(hit)
			onTouched(state, hit)
		end)
	end

	RunService.Heartbeat:Connect(function(delta)
		elapsed += delta
		for _, state in states do
			if state.taken then
				continue
			end
			local bob = math.sin(elapsed * 2 + state.phase) * 0.25
			local angle = elapsed * SPIN_SPEED + state.phase
			state.part.CFrame = CFrame.new(state.base + Vector3.new(0, bob, 0))
				* CFrame.Angles(0, angle, math.rad(90))
		end
	end)
end

return CoinService

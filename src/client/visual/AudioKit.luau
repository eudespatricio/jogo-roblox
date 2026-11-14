--!strict
-- S8 + Playtest V1 + SFX/OST v3: barramento de audio (MuralhaMaster -> BGM_Bus, MuralhaSFX, SFX_Physics),
-- pool de vozes por cue (2D e 3D posicional com RollOff), teto global de vozes, cooldown por cue,
-- pitch jitter, reverb de espaco, ducking em hits pesados, crossfade build/siege/danger sincronizado,
-- alarme + heartbeat <30% HP e sinergias elementais. IDs vem de AudioAssets (Open Cloud).

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local sharedVisual =
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("visual")
local VisualTheme = require(sharedVisual:WaitForChild("VisualTheme"))
local AudioAssets = require(sharedVisual:WaitForChild("AudioAssets"))

export type AudioMode = "build" | "raid" | "stop"

type HierarchyRefs = {
	master: SoundGroup,
	compressor: CompressorSoundEffect,
	bgm: SoundGroup,
	bgmEq: EqualizerSoundEffect,
	sfx: SoundGroup,
	physics: SoundGroup,
	voices: Folder,
}

type CueSpec = {
	volume: number,
	speed: number,
	jitter: boolean,
	cooldown: number,
	maxVoices: number,
	priority: boolean,
	heavy: boolean,
	fallback: string,
}

type Voice = {
	sound: Sound,
	anchor: Attachment?,
	busyUntil: number,
	inLive: boolean,
}

local MASTER_NAME = "MuralhaMaster"
local BGM_BUS_NAME = "BGM_Bus"
local PHYSICS_BUS_NAME = "SFX_Physics"
local VOICES_FOLDER = "MuralhaVoices"

local BGM_BASE_VOLUME = 0.60
local SFX_BASE_VOLUME = 0.80
local PHYSICS_BASE_VOLUME = 0.72

local BUILD_LOOP_VOLUME = 0.24
local RAID_LOOP_VOLUME = 0.30
local DANGER_LOOP_VOLUME = 0.24
local CROSSFADE_SEC = 0.8

local PHYSICS_COOLDOWN_SEC = 0.080
local JITTER_MIN = 0.92
local JITTER_MAX = 1.08

local MAX_VOICES = 40
local ROLLOFF_MIN = 95
local ROLLOFF_MAX = 360

local DUCK_ATTACK_SEC = 0.045
local DUCK_RELEASE_SEC = 0.26
local DUCK_GAIN = 0.68
local FALLBACK_VOLUME_SCALE = 0.55

local WALL_DANGER_PCT = 0.30
local WALL_ALARM_REARM_PCT = 0.40

local F_SNAP = "rbxasset://sounds/snap.mp3"
local F_WATER = "rbxasset://sounds/impact_water.mp3"
local F_BASS = "rbxasset://sounds/bass.wav"

local AudioKit = {}

type CueOpts = {
	jitter: boolean?,
	cooldown: number?,
	maxVoices: number?,
	priority: boolean?,
	heavy: boolean?,
}

local NO_OPTS: CueOpts = {}

local function spec(volume: number, speed: number, fallback: string, opts: CueOpts?): CueSpec
	local o: CueOpts = opts or NO_OPTS
	return {
		volume = volume,
		speed = speed,
		jitter = if o.jitter == nil then true else o.jitter == true,
		cooldown = o.cooldown or 0.045,
		maxVoices = o.maxVoices or 3,
		priority = o.priority == true,
		heavy = o.heavy == true,
		fallback = fallback,
	}
end

local UI: CueOpts = { jitter = false, maxVoices = 2, priority = true }
local STING: CueOpts = { jitter = false, maxVoices = 1, priority = true, heavy = true }

-- Cada cue: volume de mix (assets ja chegam em -14 LUFS), speed base, placeholder offline quente.
local CUES: { [string]: CueSpec } = {
	-- traps: disparo / impacto / sinergias
	archer_fire = spec(0.30, 1, F_SNAP, { cooldown = 0.09 }),
	archer_impact = spec(0.28, 1, F_SNAP, { cooldown = 0.06 }),
	tar_fire = spec(0.32, 1, F_WATER, { cooldown = 0.12 }),
	tar_ignite = spec(0.42, 1, F_WATER, { cooldown = 0.25, maxVoices = 2, heavy = true }),
	frost_fire = spec(0.32, 1, F_WATER, { cooldown = 0.12 }),
	frost_impact = spec(0.30, 1, F_WATER, { cooldown = 0.08 }),
	syn_thermal_shock = spec(0.44, 1, F_WATER, { cooldown = 0.25, maxVoices = 2, heavy = true }),
	cannon_fire = spec(0.44, 1, F_BASS, { cooldown = 0.14, maxVoices = 2, priority = true }),
	cannon_impact = spec(0.38, 1, F_BASS, { cooldown = 0.10, maxVoices = 3, priority = true }),
	catapult_fire = spec(0.36, 1, F_SNAP, { cooldown = 0.16, maxVoices = 2, priority = true }),
	catapult_impact = spec(0.44, 1, F_BASS, { cooldown = 0.10, maxVoices = 3, priority = true }),
	-- build / economia
	build_place = spec(0.42, 1, F_SNAP, UI),
	build_move = spec(0.34, 1, F_SNAP, UI),
	build_remove = spec(0.36, 1, F_SNAP, UI),
	build_upgrade_2 = spec(0.38, 1, F_SNAP, UI),
	build_upgrade_3 = spec(0.40, 1, F_SNAP, UI),
	build_upgrade_4 = spec(0.44, 1, F_SNAP, UI),
	build_upgrade_5 = spec(
		0.48,
		1,
		F_SNAP,
		{ jitter = false, maxVoices = 2, priority = true, heavy = true }
	),
	build_invalid = spec(0.28, 0.85, F_BASS, UI),
	build_locked = spec(0.32, 0.82, F_BASS, UI),
	coin_gain = spec(0.32, 1, F_SNAP, UI),
	coin_spend = spec(0.30, 1, F_SNAP, UI),
	-- batalha
	horde_spawn = spec(
		0.36,
		1,
		F_BASS,
		{ jitter = false, cooldown = 0.8, maxVoices = 1, priority = true }
	),
	death_runner = spec(0.28, 1, F_SNAP, { cooldown = 0.05, maxVoices = 4 }),
	death_brute = spec(0.36, 1, F_BASS, { cooldown = 0.08, maxVoices = 3 }),
	death_swarm = spec(0.22, 1, F_SNAP, { cooldown = 0.035, maxVoices = 4 }),
	wall_hit = spec(0.38, 1, F_BASS, { cooldown = 0.12, maxVoices = 2, priority = true }),
	wall_alarm = spec(
		0.44,
		1.05,
		F_BASS,
		{ jitter = false, cooldown = 2, maxVoices = 1, priority = true, heavy = true }
	),
	wall_heartbeat = spec(
		0.34,
		1,
		F_BASS,
		{ jitter = false, cooldown = 0.1, maxVoices = 2, priority = true }
	),
	gate_fracture = spec(
		0.56,
		1,
		F_BASS,
		{ jitter = false, cooldown = 1, maxVoices = 1, priority = true, heavy = true }
	),
	horn = spec(
		0.42,
		1,
		F_BASS,
		{ jitter = false, cooldown = 0.6, maxVoices = 1, priority = true }
	),
	victory_sting = spec(0.56, 1, F_SNAP, STING),
	defeat_sting = spec(0.54, 0.82, F_BASS, STING),
	-- bosses & campanha
	boss_intro = spec(
		0.54,
		0.78,
		F_BASS,
		{ jitter = false, cooldown = 1.0, maxVoices = 1, priority = true, heavy = true }
	),
	boss_telegraph = spec(0.48, 0.96, F_BASS, { cooldown = 0.35, maxVoices = 1, priority = true }),
	boss_slam = spec(
		0.58,
		0.72,
		F_BASS,
		{ jitter = false, cooldown = 0.35, maxVoices = 2, priority = true, heavy = true }
	),
	boss_stagger = spec(0.52, 0.88, F_SNAP, { cooldown = 0.4, maxVoices = 1, priority = true }),
	boss_enrage = spec(
		0.56,
		0.84,
		F_BASS,
		{ jitter = false, cooldown = 0.8, maxVoices = 1, priority = true, heavy = true }
	),
	boss_death = spec(
		0.62,
		0.68,
		F_BASS,
		{ jitter = false, cooldown = 1.0, maxVoices = 1, priority = true, heavy = true }
	),
	vo_boss_iron_ram_intro = spec(
		0.88,
		1,
		F_BASS,
		{ jitter = false, cooldown = 1.8, maxVoices = 1, priority = true }
	),
	vo_boss_iron_ram_enrage = spec(
		0.90,
		1,
		F_BASS,
		{ jitter = false, cooldown = 1.8, maxVoices = 1, priority = true }
	),
	vo_boss_slag_intro = spec(
		0.88,
		1,
		F_BASS,
		{ jitter = false, cooldown = 1.8, maxVoices = 1, priority = true }
	),
	vo_boss_slag_enrage = spec(
		0.90,
		1,
		F_BASS,
		{ jitter = false, cooldown = 1.8, maxVoices = 1, priority = true }
	),
	vo_boss_rime_intro = spec(
		0.88,
		1,
		F_BASS,
		{ jitter = false, cooldown = 1.8, maxVoices = 1, priority = true }
	),
	vo_boss_rime_enrage = spec(
		0.90,
		1,
		F_BASS,
		{ jitter = false, cooldown = 1.8, maxVoices = 1, priority = true }
	),
	vo_boss_powder_intro = spec(
		0.88,
		1,
		F_BASS,
		{ jitter = false, cooldown = 1.8, maxVoices = 1, priority = true }
	),
	vo_boss_powder_enrage = spec(
		0.90,
		1,
		F_BASS,
		{ jitter = false, cooldown = 1.8, maxVoices = 1, priority = true }
	),
	vo_boss_rift_intro = spec(
		0.88,
		1,
		F_BASS,
		{ jitter = false, cooldown = 1.8, maxVoices = 1, priority = true }
	),
	vo_boss_rift_enrage = spec(
		0.90,
		1,
		F_BASS,
		{ jitter = false, cooldown = 1.8, maxVoices = 1, priority = true }
	),
	campaign_select = spec(0.36, 1.04, F_SNAP, UI),
	campaign_star = spec(0.46, 1.12, F_SNAP, UI),
	campaign_act_clear = spec(0.58, 0.95, F_BASS, STING),
	-- torcida
	crowd_murmur = spec(0.28, 0.82, F_WATER, { cooldown = 1.2, maxVoices = 1 }),
	crowd_cheer = spec(0.42, 0.96, F_WATER, { cooldown = 0.35, maxVoices = 2 }),
	crowd_gasp = spec(0.40, 0.88, F_WATER, { cooldown = 0.45, maxVoices = 2 }),
	crowd_victory = spec(0.52, 0.94, F_BASS, { jitter = false, cooldown = 0.8, maxVoices = 1 }),
	-- UI
	ui_click = spec(0.28, 1, F_SNAP, UI),
	ui_toggle = spec(0.28, 1, F_SNAP, UI),
	-- fisica F2
	phys_wood_impact = spec(0.28, 1, F_SNAP),
	phys_stone_impact = spec(0.32, 1, F_BASS),
	phys_iron_impact = spec(0.30, 1, F_SNAP),
	phys_ice_shatter = spec(0.28, 1, F_WATER),
}

local BOSS_VO_OPTS: CueOpts = { jitter = false, cooldown = 1.8, maxVoices = 1, priority = true }
for _, bossShort in ipairs({ "iron_ram", "slag", "rime", "powder", "rift" }) do
	for _, suf in ipairs({ "_en", "_es" }) do
		CUES["vo_boss_" .. bossShort .. "_intro" .. suf] = spec(0.88, 1, F_BASS, BOSS_VO_OPTS)
		CUES["vo_boss_" .. bossShort .. "_enrage" .. suf] = spec(0.90, 1, F_BASS, BOSS_VO_OPTS)
	end
end

-- Placeholders offline usam velocidade suave (clamped [0.85, 1.18]) se IDs Open Cloud estiverem bloqueados.
local FALLBACK_SPEED: { [string]: number } = {
	ui_click = 1.08,
	ui_toggle = 1.14,
	build_move = 1.04,
	build_upgrade_2 = 1.06,
	build_upgrade_3 = 1.10,
	build_upgrade_4 = 1.14,
	build_upgrade_5 = 1.18,
	syn_thermal_shock = 1.08,
	archer_fire = 1.15,
	catapult_fire = 1.05,
	cannon_fire = 0.85,
	wall_hit = 0.88,
	horn = 0.85,
	horde_spawn = 0.85,
	victory_sting = 1.06,
	defeat_sting = 0.86,
	wall_heartbeat = 0.85,
	phys_stone_impact = 0.88,
	phys_iron_impact = 1.14,
	phys_ice_shatter = 1.12,
}

-- Nomes historicos (S8/Playtest V1) continuam validos.
local ALIASES: { [string]: string } = {
	ui_deny = "build_invalid",
	trap_place = "build_place",
	trap_upgrade = "build_upgrade_2",
	projectile = "catapult_fire",
	impact = "catapult_impact",
	gate_hit = "wall_hit",
	victory = "victory_sting",
	defeat = "defeat_sting",
}

local TRAP_CUES: { [string]: { fire: string, impact: string } } = {
	archer = { fire = "archer_fire", impact = "archer_impact" },
	tar = { fire = "tar_fire", impact = "tar_fire" },
	oil = { fire = "tar_fire", impact = "tar_fire" },
	frost = { fire = "frost_fire", impact = "frost_impact" },
	cannon = { fire = "cannon_fire", impact = "cannon_impact" },
	catapult = { fire = "catapult_fire", impact = "catapult_impact" },
}

local DEATH_CUES: { [string]: string } = {
	runner = "death_runner",
	brute = "death_brute",
	swarm = "death_swarm",
	shieldbearer = "death_brute",
	pyromancer = "death_runner",
	sapper = "death_swarm",
}

-- Compat: mapa cue -> placeholder offline (S8).
AudioKit.SOUNDS = {} :: { [string]: string }
for cue, cueSpec in pairs(CUES) do
	AudioKit.SOUNDS[cue] = cueSpec.fallback
end

local rng = Random.new()
local hierarchy: HierarchyRefs? = nil
local muted = false

local lastCueAt: { [string]: number } = {}
local lastPhysicsAt: number = -1
local failedIds: { [string]: boolean } = {}
local preloadStarted = false
local preloadWarned = false

local pool2d: { [string]: { Voice } } = {}
local pool3d: { [string]: { Voice } } = {}
local live: { Voice } = {}

local RAID_BGM_POOL = { "bgm_siege", "bgm_siege_2" }
local BOSS_VO_PREFIX: { [string]: string } = {
	iron_ram_colossus = "vo_boss_iron_ram",
	slag_juggernaut = "vo_boss_slag",
	rime_matriarch = "vo_boss_rime",
	powder_baron = "vo_boss_powder",
	rift_titan = "vo_boss_rift",
}

local duckTween: Tween? = nil
local voiceDuckToken = 0
local voiceDuckUntil = 0
local currentMode: AudioMode = "stop"
local activeRaidCue = "bgm_siege"
local lastRaidCue: string? = nil
local sameRaidStreak = 0
local bossActive = false
local buildLoop: Sound? = nil
local raidLoop: Sound? = nil
local dangerLoop: Sound? = nil
local bossLoop: Sound? = nil
local buildFadeTween: Tween? = nil
local raidFadeTween: Tween? = nil
local dangerFadeTween: Tween? = nil
local bossFadeTween: Tween? = nil
local targetBuildVol = -1
local targetRaidVol = -1
local targetDangerVol = -1
local targetBossVol = -1

local wallPct = 1.0
local alarmArmed = true
local heartbeatActive = false
local heartbeatToken = 0
local heartbeatSound: Sound? = nil

local function canonical(cue: string): string
	return ALIASES[cue] or cue
end

local function isPhysicsCue(cue: string): boolean
	return string.sub(cue, 1, 5) == "phys_"
end

local function assetIdFor(cue: string): string?
	local id = AudioAssets.IDS[cue]
	if id ~= nil and id ~= "" and not failedIds[id] then
		return id
	end
	local fb = AudioAssets.APPROVED_FALLBACKS[cue]
	if fb ~= nil and fb ~= "" and not failedIds[fb] then
		return fb
	end
	return nil
end

local function findOrCreateSoundGroup(
	parent: Instance,
	name: string,
	defaultVolume: number
): SoundGroup
	local existing = parent:FindFirstChild(name)
	if existing ~= nil and existing:IsA("SoundGroup") then
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = name
	created.Volume = defaultVolume
	created.Parent = parent
	return created
end

local syncBgmState: (() -> ())? = nil

local function startPreload(): ()
	if preloadStarted then
		return
	end
	preloadStarted = true
	local ids: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, id in pairs(AudioAssets.IDS) do
		if id ~= "" and not seen[id] then
			seen[id] = true
			table.insert(ids, id)
		end
	end
	for _, id in pairs(AudioAssets.APPROVED_FALLBACKS) do
		if id ~= "" and not seen[id] then
			seen[id] = true
			table.insert(ids, id)
		end
	end
	if #ids == 0 then
		return
	end
	task.spawn(function()
		local failedCount = 0
		local loadedCount = 0
		local preloadSounds: { Instance } = {}
		local parentContainer: Instance = if hierarchy ~= nil
			then hierarchy.voices
			else SoundService
		for idx, id in ipairs(ids) do
			local sound = Instance.new("Sound")
			sound.Name = "Preload_" .. tostring(idx)
			sound.SoundId = id
			sound.Volume = 0
			sound.Parent = parentContainer
			table.insert(preloadSounds, sound)
		end
		pcall(function()
			ContentProvider:PreloadAsync(
				preloadSounds,
				function(contentId: string, status: Enum.AssetFetchStatus)
					if status == Enum.AssetFetchStatus.Failure then
						failedIds[contentId] = true
						failedCount += 1
					elseif status == Enum.AssetFetchStatus.Success then
						loadedCount += 1
					end
				end
			)
		end)
		for _, sound in ipairs(preloadSounds) do
			sound:Destroy()
		end
		if failedCount >= 10 and loadedCount == 0 and not preloadWarned then
			preloadWarned = true
			warn(
				string.format(
					"[AudioKit] %d Open Cloud audio assets failed to load (Universe GameId=%d). Grant 'Use' permission via: python3 tools/gen-sfx.py --no-generate --grant-universe %d",
					failedCount,
					game.GameId,
					game.GameId
				)
			)
		end
		if failedCount > 0 and syncBgmState ~= nil then
			syncBgmState()
		end
	end)
end

local function ensureReverbEffect(bus: SoundGroup): ()
	local existing = bus:FindFirstChildOfClass("ReverbSoundEffect")
	local verb: ReverbSoundEffect
	if existing ~= nil then
		verb = existing
	else
		verb = Instance.new("ReverbSoundEffect")
		verb.Name = "BastionSpace"
		verb.Parent = bus
	end
	verb.DecayTime = 0.72
	verb.Density = 0.75
	verb.Diffusion = 0.80
	verb.DryLevel = 0
	verb.WetLevel = -15
	verb.Enabled = true
end

local function ensureHierarchy(): HierarchyRefs
	if hierarchy ~= nil then
		local cached = hierarchy
		if
			cached.master.Parent == SoundService
			and cached.bgm.Parent == cached.master
			and cached.sfx.Parent == cached.master
			and cached.physics.Parent == cached.master
			and cached.voices.Parent == SoundService
		then
			return cached
		end
		pool2d = {}
		pool3d = {}
		live = {}
	end

	local master = findOrCreateSoundGroup(SoundService, MASTER_NAME, if muted then 0 else 1)
	master.Volume = if muted then 0 else 1

	local compressorInst = master:FindFirstChildOfClass("CompressorSoundEffect")
	local compressor: CompressorSoundEffect
	if compressorInst ~= nil then
		compressor = compressorInst
	else
		compressor = Instance.new("CompressorSoundEffect")
		compressor.Name = "MasterCompressor"
		compressor.Parent = master
	end
	compressor.Threshold = -3
	compressor.Ratio = 2.5
	compressor.Attack = 0.02
	compressor.Release = 0.14
	compressor.Enabled = true

	local bgm = findOrCreateSoundGroup(master, BGM_BUS_NAME, BGM_BASE_VOLUME)
	local bgmEqInst = bgm:FindFirstChildOfClass("EqualizerSoundEffect")
	local bgmEq: EqualizerSoundEffect
	if bgmEqInst ~= nil then
		bgmEq = bgmEqInst
	else
		bgmEq = Instance.new("EqualizerSoundEffect")
		bgmEq.Name = "BGM_EQ"
		bgmEq.LowGain = -1
		bgmEq.MidGain = -0.5
		bgmEq.HighGain = -1
		bgmEq.Parent = bgm
	end
	bgmEq.Enabled = true

	-- Preserva VisualTheme.AUDIO.group ('MuralhaSFX'); reparenta se ja existir no SoundService.
	local legacySfx = SoundService:FindFirstChild(VisualTheme.AUDIO.group)
	local sfx: SoundGroup
	if legacySfx ~= nil and legacySfx:IsA("SoundGroup") then
		legacySfx.Parent = master
		sfx = legacySfx
	else
		sfx = findOrCreateSoundGroup(master, VisualTheme.AUDIO.group, SFX_BASE_VOLUME)
	end
	ensureReverbEffect(sfx)
	local sfxEqInst = sfx:FindFirstChild("SfxWarmthEQ")
	local sfxEq: EqualizerSoundEffect
	if sfxEqInst ~= nil and sfxEqInst:IsA("EqualizerSoundEffect") then
		sfxEq = sfxEqInst
	else
		sfxEq = Instance.new("EqualizerSoundEffect")
		sfxEq.Name = "SfxWarmthEQ"
		sfxEq.Parent = sfx
	end
	sfxEq.LowGain = -1.5
	sfxEq.MidGain = 1
	sfxEq.HighGain = -1.5
	sfxEq.Enabled = true

	local physics = findOrCreateSoundGroup(master, PHYSICS_BUS_NAME, PHYSICS_BASE_VOLUME)
	ensureReverbEffect(physics)

	local voicesInst = SoundService:FindFirstChild(VOICES_FOLDER)
	local voices: Folder
	if voicesInst ~= nil and voicesInst:IsA("Folder") then
		voices = voicesInst
	else
		voices = Instance.new("Folder")
		voices.Name = VOICES_FOLDER
		voices.Parent = SoundService
	end

	local refs: HierarchyRefs = {
		master = master,
		compressor = compressor,
		bgm = bgm,
		bgmEq = bgmEq,
		sfx = sfx,
		physics = physics,
		voices = voices,
	}
	hierarchy = refs
	startPreload()
	return refs
end

local function ensureGroup(): SoundGroup
	return ensureHierarchy().sfx
end

local function triggerDucking(): ()
	if os.clock() < voiceDuckUntil then
		return
	end
	local refs = ensureHierarchy()
	if duckTween ~= nil then
		duckTween:Cancel()
		duckTween = nil
	end
	local attackTween = TweenService:Create(
		refs.bgm,
		TweenInfo.new(DUCK_ATTACK_SEC, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = BGM_BASE_VOLUME * DUCK_GAIN }
	)
	duckTween = attackTween
	attackTween.Completed:Once(function(playbackState: Enum.PlaybackState)
		if playbackState == Enum.PlaybackState.Completed and duckTween == attackTween then
			local releaseTween = TweenService:Create(
				refs.bgm,
				TweenInfo.new(DUCK_RELEASE_SEC, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Volume = BGM_BASE_VOLUME }
			)
			duckTween = releaseTween
			releaseTween:Play()
		end
	end)
	attackTween:Play()
end

local function triggerVoiceDucking(holdSec: number): ()
	local refs = ensureHierarchy()
	if duckTween ~= nil then
		duckTween:Cancel()
		duckTween = nil
	end
	voiceDuckToken += 1
	local myToken = voiceDuckToken
	local waitSec = math.max(0.5, holdSec)
	voiceDuckUntil = os.clock() + waitSec
	local downTween = TweenService:Create(
		refs.bgm,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = BGM_BASE_VOLUME * 0.38 }
	)
	duckTween = downTween
	downTween:Play()
	task.delay(waitSec, function()
		if voiceDuckToken ~= myToken then
			return
		end
		local upTween = TweenService:Create(
			refs.bgm,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Volume = BGM_BASE_VOLUME }
		)
		duckTween = upTween
		upTween:Play()
	end)
end

local function pruneLive(now: number): number
	local kept: { Voice } = {}
	for _, voice in ipairs(live) do
		if voice.busyUntil > now and voice.sound.Parent ~= nil then
			table.insert(kept, voice)
		else
			voice.inLive = false
		end
	end
	live = kept
	return #kept
end

local function newVoice(cue: string, refs: HierarchyRefs, positional: boolean): Voice
	local sound = Instance.new("Sound")
	sound.Name = "SFX_" .. cue
	sound.SoundGroup = if isPhysicsCue(cue) then refs.physics else refs.sfx
	if positional then
		local anchor = Instance.new("Attachment")
		anchor.Name = "MuralhaSfx3D_" .. cue
		anchor.Parent = Workspace.Terrain
		sound.RollOffMode = Enum.RollOffMode.LinearSquare
		sound.RollOffMinDistance = ROLLOFF_MIN
		sound.RollOffMaxDistance = ROLLOFF_MAX
		sound.Parent = anchor
		return { sound = sound, anchor = anchor, busyUntil = 0, inLive = false }
	end
	sound.Parent = refs.voices
	return { sound = sound, anchor = nil, busyUntil = 0, inLive = false }
end

local function acquireVoice(
	cue: string,
	cueSpec: CueSpec,
	refs: HierarchyRefs,
	positional: boolean,
	now: number
): Voice
	local pools = if positional then pool3d else pool2d
	local list = pools[cue]
	if list == nil then
		list = {}
		pools[cue] = list
	end
	local oldest: Voice? = nil
	local index = 1
	while index <= #list do
		local voice = list[index]
		if
			voice.sound.Parent == nil
			or (voice.anchor ~= nil and (voice.anchor :: Attachment).Parent == nil)
		then
			voice.inLive = false
			table.remove(list, index)
		else
			if voice.busyUntil <= now then
				return voice
			end
			if oldest == nil or voice.busyUntil < (oldest :: Voice).busyUntil then
				oldest = voice
			end
			index += 1
		end
	end
	if #list < cueSpec.maxVoices or oldest == nil then
		local created = newVoice(cue, refs, positional)
		table.insert(list, created)
		return created
	end
	local stolen = oldest :: Voice
	if stolen.sound.IsPlaying then
		stolen.sound:Stop()
	end
	return stolen
end

local function playInternal(
	rawCue: string,
	volumeScale: number?,
	pitchOffset: number?,
	position: Vector3?
): ()
	if muted then
		return
	end
	local cue = canonical(rawCue)
	local cueSpec = CUES[cue]
	if cueSpec == nil then
		return
	end

	local now = os.clock()
	local physics = isPhysicsCue(cue)
	if physics then
		if lastPhysicsAt >= 0 and (now - lastPhysicsAt) < PHYSICS_COOLDOWN_SEC then
			return
		end
	else
		local prev = lastCueAt[cue]
		if prev ~= nil and (now - prev) < cueSpec.cooldown then
			return
		end
	end
	if not cueSpec.priority and pruneLive(now) >= MAX_VOICES then
		return
	end

	local refs = ensureHierarchy()
	if physics then
		lastPhysicsAt = now
	else
		lastCueAt[cue] = now
	end

	local assetId = assetIdFor(cue)
	local baseSpeed = if assetId ~= nil
		then cueSpec.speed
		else (FALLBACK_SPEED[cue] or cueSpec.speed)
	local jitter = if cueSpec.jitter then rng:NextNumber(JITTER_MIN, JITTER_MAX) else 1
	local finalSpeed = math.max(0.25, baseSpeed * jitter + (pitchOffset or 0))
	local scale = (volumeScale or 1) * (if assetId ~= nil then 1 else FALLBACK_VOLUME_SCALE)

	local voice = acquireVoice(cue, cueSpec, refs, position ~= nil, now)
	local sound = voice.sound
	local anchor = voice.anchor
	if anchor ~= nil and position ~= nil then
		anchor.WorldPosition = position
	end
	local soundId = assetId or cueSpec.fallback
	if sound.SoundId ~= soundId then
		sound.SoundId = soundId
	end
	sound.Volume = cueSpec.volume * scale
	sound.PlaybackSpeed = finalSpeed
	sound.TimePosition = 0
	sound:Play()

	local duration = AudioAssets.DURATION[cue] or 1
	voice.busyUntil = now + duration / finalSpeed + 0.05
	if not voice.inLive then
		voice.inLive = true
		table.insert(live, voice)
	end

	if cueSpec.heavy or (cue == "catapult_impact" and scale >= 1.2) then
		triggerDucking()
	end
end

local function ensureBgmSound(
	bgmGroup: SoundGroup,
	cached: Sound?,
	name: string,
	cueName: string
): (Sound, boolean)
	local sound: Sound
	if cached ~= nil and cached.Parent == bgmGroup then
		sound = cached
	else
		local existing = bgmGroup:FindFirstChild(name)
		if existing ~= nil and existing:IsA("Sound") then
			sound = existing
		else
			local created = Instance.new("Sound")
			created.Name = name
			created.Looped = true
			created.PlaybackSpeed = 1
			created.Volume = 0
			created.SoundGroup = bgmGroup
			created.Parent = bgmGroup
			sound = created
		end
	end
	local assetId = assetIdFor(cueName)
	local targetId = assetId or ""
	if sound.SoundId ~= targetId then
		if sound.IsPlaying then
			sound:Stop()
		end
		sound.SoundId = targetId
	end
	sound.Looped = true
	sound.PlaybackSpeed = 1
	return sound, assetId ~= nil
end

local function ensureBgmLoops(
	refs: HierarchyRefs
): (Sound, Sound, Sound, Sound, boolean, boolean, boolean, boolean)
	local bSound, hasBuild = ensureBgmSound(refs.bgm, buildLoop, "BGM_Build", "bgm_bastion")
	buildLoop = bSound
	local rSound, hasRaid = ensureBgmSound(refs.bgm, raidLoop, "BGM_Raid", activeRaidCue)
	raidLoop = rSound
	local dSound, hasDanger = ensureBgmSound(refs.bgm, dangerLoop, "BGM_Danger", "bgm_danger")
	dangerLoop = dSound
	local bossSound, hasBoss = ensureBgmSound(refs.bgm, bossLoop, "BGM_Boss", "bgm_boss")
	bossLoop = bossSound
	return bSound, rSound, dSound, bossSound, hasBuild, hasRaid, hasDanger, hasBoss
end

local function tweenLoopVolume(
	sound: Sound,
	targetVolume: number,
	activeTween: Tween?,
	hasAsset: boolean
): Tween?
	if not hasAsset or targetVolume <= 0 then
		if activeTween ~= nil then
			activeTween:Cancel()
		end
		if not hasAsset then
			sound.Volume = 0
			if sound.IsPlaying then
				sound:Stop()
			end
			return nil
		end
		if not sound.IsPlaying and sound.Volume <= 0.001 then
			sound.Volume = 0
			return nil
		end
	elseif not sound.IsPlaying then
		sound.Volume = 0
		sound:Play()
	end
	local tween = TweenService:Create(
		sound,
		TweenInfo.new(CROSSFADE_SEC, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = targetVolume }
	)
	if targetVolume <= 0 then
		tween.Completed:Once(function(playbackState: Enum.PlaybackState)
			if playbackState == Enum.PlaybackState.Completed and sound.Volume <= 0.001 then
				sound:Stop()
			end
		end)
	end
	tween:Play()
	return tween
end

local function applyBgmState(): ()
	local refs = ensureHierarchy()
	local bSound, rSound, dSound, bossSound, hasBuild, hasRaid, hasDanger, hasBoss =
		ensureBgmLoops(refs)
	local inBoss = currentMode == "raid" and bossActive and hasBoss
	local inDanger = currentMode == "raid"
		and not inBoss
		and wallPct > 0
		and wallPct < WALL_DANGER_PCT

	local wantBuild = if currentMode == "build" and hasBuild then BUILD_LOOP_VOLUME else 0
	local wantRaid = if currentMode == "raid"
			and not inBoss
			and hasRaid
		then RAID_LOOP_VOLUME
		else 0
	local wantDanger = if inDanger and hasDanger then DANGER_LOOP_VOLUME else 0
	local wantBoss = if inBoss then RAID_LOOP_VOLUME else 0

	if wantBuild ~= targetBuildVol or (wantBuild > 0 and not bSound.IsPlaying) or not hasBuild then
		targetBuildVol = wantBuild
		buildFadeTween = tweenLoopVolume(bSound, wantBuild, buildFadeTween, hasBuild)
	end
	if wantRaid ~= targetRaidVol or (wantRaid > 0 and not rSound.IsPlaying) or not hasRaid then
		targetRaidVol = wantRaid
		raidFadeTween = tweenLoopVolume(rSound, wantRaid, raidFadeTween, hasRaid)
	end
	if
		wantDanger ~= targetDangerVol
		or (wantDanger > 0 and not dSound.IsPlaying)
		or not hasDanger
	then
		if
			wantDanger > 0
			and not dSound.IsPlaying
			and rSound.IsPlaying
			and rSound.IsLoaded
			and dSound.IsLoaded
		then
			dSound.TimePosition = if dSound.TimeLength > 0.5
				then (rSound.TimePosition % dSound.TimeLength)
				else 0
		end
		targetDangerVol = wantDanger
		dangerFadeTween = tweenLoopVolume(dSound, wantDanger, dangerFadeTween, hasDanger)
	end
	if wantBoss ~= targetBossVol or (wantBoss > 0 and not bossSound.IsPlaying) or not hasBoss then
		targetBossVol = wantBoss
		bossFadeTween = tweenLoopVolume(bossSound, wantBoss, bossFadeTween, hasBoss)
	end
end

syncBgmState = applyBgmState

local function stopHeartbeat(): ()
	if heartbeatActive then
		heartbeatActive = false
		heartbeatToken += 1
	end
end

local function ensureHeartbeatSound(sfxGroup: SoundGroup): Sound
	if heartbeatSound ~= nil and heartbeatSound.Parent == sfxGroup then
		return heartbeatSound
	end
	local existing = sfxGroup:FindFirstChild("WallHeartbeat")
	local sound: Sound
	if existing ~= nil and existing:IsA("Sound") then
		sound = existing
	else
		sound = Instance.new("Sound")
		sound.Name = "WallHeartbeat"
		sound.SoundGroup = sfxGroup
		sound.Parent = sfxGroup
	end
	heartbeatSound = sound
	return sound
end

local function pulseHeartbeat(speed: number, volume: number): ()
	local pulse = ensureHeartbeatSound(ensureGroup())
	local soundId = assetIdFor("wall_heartbeat") or F_BASS
	if pulse.SoundId ~= soundId then
		pulse.SoundId = soundId
	end
	pulse.PlaybackSpeed = speed
	pulse.Volume = volume
	pulse.TimePosition = 0
	pulse:Play()
end

local function startHeartbeat(): ()
	if heartbeatActive then
		return
	end
	heartbeatActive = true
	heartbeatToken += 1
	local myToken = heartbeatToken

	task.spawn(function()
		while heartbeatActive and heartbeatToken == myToken do
			local dangerRatio = math.clamp((WALL_DANGER_PCT - wallPct) / WALL_DANGER_PCT, 0, 1)
			local inDanger = not muted and wallPct > 0 and wallPct < WALL_DANGER_PCT
			if assetIdFor("wall_heartbeat") ~= nil then
				-- Asset gerado ja contem lub-dub: 1 disparo por ciclo, acelera com o perigo.
				if inDanger then
					pulseHeartbeat(1 + 0.25 * dangerRatio, 0.22 + 0.18 * dangerRatio)
				end
				task.wait(0.95 - 0.35 * dangerRatio)
			else
				if inDanger then
					pulseHeartbeat(0.58, 0.18 + 0.16 * dangerRatio)
				end
				task.wait(0.16)
				if not heartbeatActive or heartbeatToken ~= myToken then
					break
				end
				if not muted and wallPct > 0 and wallPct < WALL_DANGER_PCT then
					pulseHeartbeat(0.48, 0.12 + 0.12 * dangerRatio)
				end
				task.wait(0.72 - 0.24 * dangerRatio)
			end
		end
	end)
end

AudioKit.ensureGroup = ensureGroup

-- 2D (UI, stingers, eventos globais).
function AudioKit.play(cue: string, volumeScale: number?, pitchOffset: number?): ()
	playInternal(cue, volumeScale, pitchOffset, nil)
end

-- 3D posicional (batalha): RollOff InverseTapered 65..300 studs.
function AudioKit.playAt(
	cue: string,
	position: Vector3,
	volumeScale: number?,
	pitchOffset: number?
): ()
	playInternal(cue, volumeScale, pitchOffset, position)
end

local function playMaybeAt(
	cue: string,
	position: Vector3?,
	volumeScale: number?,
	pitchOffset: number?
): ()
	playInternal(cue, volumeScale, pitchOffset, position)
end

-- Disparo de trap + sinergias ("incendiary_tar", "thermal_shock", "cross_battery" ou booleano legado).
function AudioKit.trapFire(trapId: string, position: Vector3?, synergy: (boolean | string)?): ()
	local cues = TRAP_CUES[trapId]
	if cues == nil then
		return
	end
	local isCrossBattery = synergy == "cross_battery" and trapId == "archer"
	playMaybeAt(
		cues.fire,
		position,
		if isCrossBattery then 1.08 else nil,
		if isCrossBattery then 0.07 else nil
	)
	if synergy == true or synergy == "incendiary_tar" then
		playMaybeAt("tar_ignite", position, nil, nil)
	elseif synergy == "thermal_shock" then
		playMaybeAt("syn_thermal_shock", position, nil, nil)
	end
end

function AudioKit.trapImpact(trapId: string, position: Vector3?): ()
	local cues = TRAP_CUES[trapId]
	if cues == nil then
		return
	end
	playMaybeAt(cues.impact, position, 0.85, nil)
end

function AudioKit.unitDeath(kind: string, position: Vector3?): ()
	playMaybeAt(DEATH_CUES[kind] or "death_runner", position, nil, nil)
end

-- Upgrade sobe a fanfarra/acorde por nivel (2..5).
function AudioKit.upgrade(level: number?): ()
	local target = math.clamp(math.floor(level or 2), 2, 5)
	local cue = if target >= 5
		then "build_upgrade_5"
		elseif target == 4 then "build_upgrade_4"
		elseif target == 3 then "build_upgrade_3"
		else "build_upgrade_2"
	playInternal(cue, nil, nil, nil)
end

function AudioKit.coin(delta: number): ()
	if delta > 0 then
		playInternal("coin_gain", nil, nil, nil)
	elseif delta < 0 then
		playInternal("coin_spend", nil, nil, nil)
	end
end

function AudioKit.playPhysics(cue: string, velocityMag: number): ()
	if velocityMag < 8 then
		return
	end
	if velocityMag <= 25 then
		playInternal(cue, 0.45, 0.06, nil)
	else
		playInternal(cue, 1.00, -0.08, nil)
	end
end

function AudioKit.playBossVoice(bossId: string, eventKind: string, locale: string?): ()
	local prefix = BOSS_VO_PREFIX[bossId]
	if prefix == nil or muted then
		return
	end
	local loc = locale
	if loc ~= "pt" and loc ~= "en" and loc ~= "es" then
		local player = Players.LocalPlayer
		local attr = if player ~= nil then player:GetAttribute("MuralhaLocale") else nil
		loc = if attr == "en" or attr == "es" then attr else "pt"
	end
	local isEnrage = eventKind == "enrage"
	local baseCue = prefix .. (if isEnrage then "_enrage" else "_intro")
	local suffix = if loc == "en" then "_en" elseif loc == "es" then "_es" else ""
	local voCue = baseCue .. suffix
	local fallbackCue = if isEnrage then "boss_enrage" else "boss_intro"
	local voAsset = assetIdFor(voCue)
	local fallbackAsset = assetIdFor(fallbackCue)
	if (voAsset == nil or voAsset == fallbackAsset) and suffix ~= "" then
		local ptAsset = assetIdFor(baseCue)
		if ptAsset ~= nil and ptAsset ~= fallbackAsset then
			voCue = baseCue
			voAsset = ptAsset
		end
	end
	-- Enquanto vo_boss_* nao tiver ID proprio publicado na Open Cloud, evita tocar o rugido duplicado.
	if voAsset == nil or voAsset == fallbackAsset then
		return
	end
	playInternal(voCue, 1.0, 0, nil)
	triggerVoiceDucking(AudioAssets.DURATION[voCue] or 2.6)
end

function AudioKit.setMode(mode: AudioMode): ()
	local refs = ensureHierarchy()
	local prevMode = currentMode
	currentMode = mode
	if mode == "raid" and prevMode ~= "raid" then
		local idx = rng:NextInteger(1, #RAID_BGM_POOL)
		local picked = RAID_BGM_POOL[idx]
		if picked == lastRaidCue and sameRaidStreak >= 2 and #RAID_BGM_POOL > 1 then
			picked = RAID_BGM_POOL[if idx == 1 then 2 else 1]
		end
		if picked == lastRaidCue then
			sameRaidStreak += 1
		else
			lastRaidCue = picked
			sameRaidStreak = 1
		end
		activeRaidCue = picked
	end
	if mode ~= "raid" then
		bossActive = false
	end
	if mode == "build" then
		refs.bgmEq.HighGain = -3
	elseif mode == "raid" then
		refs.bgmEq.HighGain = -1
	else
		refs.bgmEq.HighGain = -12
		stopHeartbeat()
	end
	applyBgmState()
end

function AudioKit.setBossActive(active: boolean): ()
	local nextActive = active == true
	if bossActive == nextActive then
		return
	end
	bossActive = nextActive
	if currentMode == "raid" then
		applyBgmState()
	end
end

function AudioKit.setWallPct(pct: number): ()
	local normalized = if pct > 1 then pct / 100 else pct
	wallPct = math.clamp(normalized, 0, 1)
	if wallPct >= WALL_ALARM_REARM_PCT then
		alarmArmed = true
	end
	if wallPct > 0 and wallPct < WALL_DANGER_PCT then
		ensureHierarchy()
		if alarmArmed then
			alarmArmed = false
			playInternal("wall_alarm", nil, nil, nil)
		end
		startHeartbeat()
	else
		stopHeartbeat()
	end
	if currentMode == "raid" then
		applyBgmState()
	end
end

function AudioKit.setMuted(value: boolean): ()
	muted = value
	local refs = ensureHierarchy()
	refs.master.Volume = if value then 0 else 1
end

function AudioKit.isMuted(): boolean
	return muted
end

return AudioKit

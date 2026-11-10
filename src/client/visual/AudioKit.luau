--!nonstrict
-- S8: audio simples do prototipo. Usa sons embutidos da Roblox como placeholder (rbxasset://)
-- para o jogo nao ficar mudo; quando houver upload de SFX originais, trocar `SOUNDS` por IDs.
-- Nao bloqueia o jogo se um som falhar (best effort).

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local VisualTheme = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("visual")
		:WaitForChild("VisualTheme")
)

local AudioKit = {}

-- Placeholders embutidos; documentados em docs/teste-s8-studio.md.
AudioKit.SOUNDS = {
	ui_click = "rbxasset://sounds/electronicpingshort.wav",
	ui_deny = "rbxasset://sounds/uuhhh.mp3",
	trap_place = "rbxasset://sounds/snap.mp3",
	trap_upgrade = "rbxasset://sounds/electronicpingshort.wav",
	projectile = "rbxasset://sounds/snap.mp3",
	impact = "rbxasset://sounds/impact_water.mp3",
	gate_hit = "rbxasset://sounds/bass.wav",
	victory = "rbxasset://sounds/electronicpingshort.wav",
	defeat = "rbxasset://sounds/uuhhh.mp3",
	horn = "rbxasset://sounds/bass.wav",
}

local VOLUME = {
	ui_click = 0.25,
	ui_deny = 0.2,
	trap_place = 0.4,
	trap_upgrade = 0.35,
	projectile = 0.18,
	impact = 0.28,
	gate_hit = 0.35,
	victory = 0.4,
	defeat = 0.35,
	horn = 0.3,
}

local SPEED = {
	ui_click = 1.3,
	trap_place = 1.0,
	trap_upgrade = 1.2,
	projectile = 1.5,
	impact = 1.1,
	gate_hit = 0.75,
	victory = 1.1,
	defeat = 0.8,
	horn = 0.6,
}

local group: SoundGroup? = nil
local muted = false

local function ensureGroup(): SoundGroup
	if group ~= nil and group.Parent ~= nil then
		return group
	end
	local existing = SoundService:FindFirstChild(VisualTheme.AUDIO.group)
	if existing ~= nil and existing:IsA("SoundGroup") then
		group = existing
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = VisualTheme.AUDIO.group
	created.Volume = 0.8
	created.Parent = SoundService
	group = created
	return created
end

function AudioKit.play(cue: string, volumeScale: number?): ()
	if muted then
		return
	end
	local soundId = AudioKit.SOUNDS[cue]
	if type(soundId) ~= "string" or #soundId == 0 then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "SFX_" .. cue
	sound.SoundId = soundId
	sound.Volume = (VOLUME[cue] or 0.25) * (volumeScale or 1)
	sound.PlaybackSpeed = SPEED[cue] or 1
	sound.SoundGroup = ensureGroup()
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 6)
end

function AudioKit.setMuted(value: boolean): ()
	muted = value
end

function AudioKit.isMuted(): boolean
	return muted
end

return AudioKit

--!strict
-- Music (Config.Music), shared by both places.
--   Lobby place: a night-drive lo-fi playlist, one track after another.
--   Store: between shifts the break-room radio (muffled, like it's coming from a small speaker);
--   during a shift an uneasy bed, plus a danger layer that swells as the Night Manager closes in
--   (Tension calls Music.SetDanger). Everything fades; nothing cuts.
-- M toggles music on and off (sound effects stay).
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Prefs = require(script.Parent:WaitForChild("Prefs"))

local Music = {}
local MU = Config.Music
local V = MU.Volume

local group: SoundGroup
local danger = 0

-- A track that fades toward a target volume every frame.
type Track = { sound: Sound, target: number, speed: number }
local tracks: { Track } = {}

local function track(id: string, looped: boolean): Track
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = looped
	s.Volume = 0
	s.SoundGroup = group
	s.Parent = SoundService
	local t = { sound = s, target = 0, speed = 0.6 }
	table.insert(tracks, t)
	return t
end

local function set(t: Track, volume: number)
	t.target = volume
	if volume > 0 and not t.sound.IsPlaying then
		if t.sound.TimePosition > 0 then
			t.sound:Resume()
		else
			t.sound:Play()
		end
	end
end

-- 0..1: how close the Manager is.
function Music.SetDanger(level: number)
	danger = level
end

local function lobby()
	local list = table.clone(MU.Lobby)

	local rng = Random.new()
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	local i = 0
	local current: Track? = nil
	local function nextTrack()
		i = i % #list + 1
		if current then
			local old = current
			old.target = 0
			task.delay(4, function()
				old.sound:Destroy()
				local k = table.find(tracks, old)
				if k then
					table.remove(tracks, k)
				end
			end)
		end
		local t = track(list[i], false)
		t.speed = 0.08 -- a slow fade in, never a sudden start
		current = t
		set(t, V.Lobby)
		t.sound.Ended:Connect(nextTrack)
	end
	nextTrack()
end

local function store()
	local radio = track(MU.Break, true)
	-- a small speaker: no lows, no highs, a little crunch
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = -30
	eq.MidGain = 2
	eq.HighGain = -18
	eq.Parent = radio.sound
	local d = Instance.new("DistortionSoundEffect")
	d.Level = 0.15
	d.Parent = radio.sound
	local calm = track(MU.ShiftCalm, true)
	local hot = track(MU.ShiftDanger, true)
	hot.speed = 1.5
	RunService.Heartbeat:Connect(function()
		local phase = ReplicatedStorage:GetAttribute("Phase")
		local inShift = phase == "Shift"
		set(radio, if phase == "Lobby" or phase == "Results" then V.Break else 0)
		set(calm, if inShift then V.ShiftCalm * (1 - danger * 0.6) else 0)
		set(hot, if inShift then V.ShiftDanger * danger else 0)
	end)
end

-- mode: "Lobby" (the lobby place) or "Store" (the shift place).
function Music.Start(mode: string)
	group = Instance.new("SoundGroup")
	group.Name = "Music"
	group.Volume = 1
	group.Parent = SoundService
	RunService.Heartbeat:Connect(function(dt)
		for _, t in tracks do
			local v = t.sound.Volume
			local step = t.speed * dt
			if math.abs(t.target - v) <= step then
				t.sound.Volume = t.target
			else
				t.sound.Volume = v + (if t.target > v then step else -step)
			end
			if t.target == 0 and t.sound.Volume == 0 and t.sound.IsPlaying and t.sound.Looped then
				t.sound:Pause()
			end
		end
	end)
	-- the gear menu's MUSIC switch (M flips it too)
	Prefs.Watch("Music", function(on)
		group.Volume = if on then 1 else 0
	end)
	ContextActionService:BindAction("ToggleMusic", function(_, state)
		if state == Enum.UserInputState.Begin then
			Prefs.Set("Music", not Prefs.On("Music"))
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.M)
	if mode == "Lobby" then
		lobby()
	else
		store()
	end
end

return Music

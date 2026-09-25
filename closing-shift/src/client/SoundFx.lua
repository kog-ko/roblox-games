--!strict
-- Local sound bed: a low drone, fluorescent hum on the lights (it dies with the power),
-- compressor hum on the coolers, UI clicks and the payoff / fired stings.
-- One-shots get a small random pitch so repeats don't sound robotic.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SoundFx = {}
local player = Players.LocalPlayer :: Player
local S, V = Config.Sounds, Config.Volumes
local rng = Random.new()

local function make(id: string, volume: number, parent: Instance, looped: boolean?): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = looped == true
	s.Parent = parent
	return s
end

-- Plays a 2D one-shot with a little pitch variation.
function SoundFx.Play(id: string, volume: number, pitch: number?)
	local s = make(id, volume, SoundService)
	s.PlaybackSpeed = (pitch or 1) * (1 + (rng:NextNumber() * 2 - 1) * Config.PitchVariation)
	s.Ended:Connect(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(10, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

local function loopOn(part: Instance, id: string, volume: number, range: number): Sound
	local s = make(id, volume, part, true)
	s.RollOffMaxDistance = range
	s.RollOffMinDistance = 4
	s.PlaybackSpeed = 1 + (rng:NextNumber() * 2 - 1) * 0.05
	s.TimePosition = rng:NextNumber() * 2
	s:Play()
	return s
end

function SoundFx.Start()
	-- drone under everything
	local drone = make(S.Ambient, V.Ambient, SoundService, true)
	drone:Play()

	-- hum on every other fluorescent tube, and on each cooler
	local hums: { Sound } = {}
	local n = 0
	local function addTube(t: Instance)
		n += 1
		if n % 2 == 0 and t:IsA("BasePart") then
			table.insert(hums, loopOn(t, S.Hum, V.Hum, 30))
		end
	end
	for _, t in CollectionService:GetTagged("FluorescentTube") do
		addTube(t)
	end
	CollectionService:GetInstanceAddedSignal("FluorescentTube"):Connect(addTube)
	local store = workspace:WaitForChild("Store")
	-- coolers stream in over time, so hook each Body as it arrives
	local coolers = store:WaitForChild("Coolers", 10)
	if coolers then
		local function addCooler(d: Instance)
			if d.Name == "Body" and d:IsA("BasePart") and d.Parent and d.Parent.Parent == coolers then
				table.insert(hums, loopOn(d, S.Fridge, V.Fridge, 22))
			end
		end
		for _, d in coolers:GetDescendants() do
			addCooler(d)
		end
		coolers.DescendantAdded:Connect(addCooler)
	end
	-- the hum stops dead when the power cuts, and the drone drops out for a beat
	local function onPower()
		local on = store:GetAttribute("Power") ~= false
		for _, h in hums do
			if h.Parent then
				h.Volume = if on then (if h.SoundId == S.Hum then V.Hum else V.Fridge) else 0
			end
		end
		drone.Volume = if on then V.Ambient else V.Ambient * 0.4
	end
	store:GetAttributeChangedSignal("Power"):Connect(onPower)

	-- UI clicks on every button we make
	local gui = player:WaitForChild("PlayerGui")
	local function hook(b: Instance)
		if b:IsA("GuiButton") and b.Name ~= "" then
			b.Activated:Connect(function()
				SoundFx.Play(S.UIClick, V.UI)
			end)
		end
	end
	for _, d in gui:GetDescendants() do
		hook(d)
	end
	gui.DescendantAdded:Connect(hook)

	-- stings
	local payoffCue = Remotes:WaitForChild("PayoffCue") :: RemoteEvent
	local results = Remotes:WaitForChild("Results") :: RemoteEvent
	payoffCue.OnClientEvent:Connect(function()
		SoundFx.Play(S.StingPayoff, V.Sting, 1)
	end)
	results.OnClientEvent:Connect(function(r: any)
		if r.Outcome == "Fired" then
			SoundFx.Play(S.StingFired, V.Sting, 1)
		end
	end)
end

return SoundFx

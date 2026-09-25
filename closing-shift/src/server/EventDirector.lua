--!strict
-- The horror layer. Each "wrong" event is a module in Server/Events, registered by its file name;
-- a night's data (Data/Nights) lists which events may happen and how far apart. Each event runs at
-- most once per shift. Power cuts are a separate timer, switched on per night.
-- Tension only: no damage, nothing gory.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage.Shared.Config)
local SpillService = require(script.Parent.SpillService)
local StoreBuilder = require(script.Parent.StoreBuilder)

local EventDirector = {}
local store: Instance
local runId = 0
local powerHolds = 0
local rng = Random.new()

-- What every event module receives.
export type Context = {
	store: Instance,
	props: Instance,
	rng: Random,
	tuning: { [string]: any },
	spills: typeof(SpillService),
	builder: typeof(StoreBuilder),
	isCurrent: () -> boolean,
	aisles: () -> { Instance },
	roots: () -> { BasePart },
	setSignNumbers: ({ number }) -> (),
	playSound: (parent: Instance, id: string, volume: number) -> (),
	cutPower: () -> () -> (),
}
type Handler = (ctx: Context) -> ()

local handlers: { [string]: Handler } = {}

local function aisles(): { Instance }
	local list = (store:FindFirstChild("Aisles") :: Instance):GetChildren()
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

local function setSignNumbers(numbers: { number })
	for i, a in aisles() do
		for _, lbl in a:GetDescendants() do
			if lbl:IsA("TextLabel") and lbl.Name == "Number" then
				lbl.Text = tostring(numbers[i])
			end
		end
	end
end

local function roots(): { BasePart }
	local out = {}
	for _, p in Players:GetPlayers() do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then
			table.insert(out, r)
		end
	end
	return out
end

local function playSound(parent: Instance, id: string, volume: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = 1 + (rng:NextNumber() * 2 - 1) * Config.PitchVariation
	s.RollOffMaxDistance = 90
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 6)
end

-- Turns the store's power off until every holder has released it, so a short LightsOut
-- can't switch the lights back on in the middle of a longer power cut.
-- Returns the release function.
local function cutPower(): () -> ()
	powerHolds += 1
	if powerHolds == 1 then
		store:SetAttribute("Power", false)
		playSound(store:FindFirstChild("Lights") :: Instance, Config.Sounds.Buzz, 0.7)
	end
	local released = false
	return function()
		if released then
			return
		end
		released = true
		powerHolds = math.max(0, powerHolds - 1)
		if powerHolds == 0 then
			store:SetAttribute("Power", true)
		end
	end
end

local function context(name: string, myRun: number): Context
	return {
		store = store,
		props = store:FindFirstChild("EventProps") :: Instance,
		rng = rng,
		tuning = Config.Events[name] or {},
		spills = SpillService,
		builder = StoreBuilder,
		isCurrent = function()
			return myRun == runId
		end,
		aisles = aisles,
		roots = roots,
		setSignNumbers = setSignNumbers,
		playSound = playSound,
		cutPower = cutPower,
	}
end

local function run(name: string, myRun: number)
	local fn = handlers[name]
	if not fn then
		warn("[EventDirector] no handler for event", name)
		return
	end
	print("[EventDirector] event:", name)
	task.spawn(function()
		local ok, err = pcall(fn, context(name, myRun))
		if not ok then
			warn("[EventDirector]", name, "failed:", err)
		end
	end)
end

local function weight(name: string): number
	local t = Config.Events[name]
	return (t and t.Weight) or 1
end

local function pickWeighted(choices: { string }): string
	local total = 0
	for _, name in choices do
		total += weight(name)
	end
	local roll = rng:NextNumber() * total
	for _, name in choices do
		roll -= weight(name)
		if roll <= 0 then
			return name
		end
	end
	return choices[#choices]
end

local function powerCutLoop(rules: any, myRun: number)
	local pc = rules.PowerCuts
	while true do
		task.wait(rng:NextNumber(pc.Every[1], pc.Every[2]))
		if myRun ~= runId then
			return
		end
		print("[EventDirector] power cut")
		local release = cutPower()
		task.wait(rng:NextNumber(pc.Duration[1], pc.Duration[2]))
		release()
		if myRun ~= runId then
			return
		end
	end
end

-- Starts the event timer (and power cuts, if the night has them) for one shift.
function EventDirector.Start(rules: any)
	runId += 1
	local myRun = runId
	local used: { [string]: boolean } = {}
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(rules.EventGap[1], rules.EventGap[2]))
			if myRun ~= runId then
				return
			end
			local choices = {}
			for _, name in rules.Events do
				local t = Config.Events[name]
				if handlers[name] and not used[name] and not (t and t.UsesSpills and SpillService.IsFinalPhase()) then
					table.insert(choices, name)
				end
			end
			if #choices == 0 then
				return
			end
			local pick = pickWeighted(choices)
			used[pick] = true
			run(pick, myRun)
		end
	end)
	if rules.PowerCuts.Enabled then
		task.spawn(powerCutLoop, rules, myRun)
	end
end

function EventDirector.Stop()
	runId += 1
end

-- Put the store back to normal between rounds.
function EventDirector.Cleanup()
	EventDirector.Stop()
	setSignNumbers({ 1, 2, 3, 4 })
	StoreBuilder.RestockAll(store)
	local props = store:FindFirstChild("EventProps") :: Instance
	props:ClearAllChildren()
	powerHolds = 0
	store:SetAttribute("Power", true)
end

-- For playtesting: run one event by name right now.
function EventDirector.Force(name: string)
	run(name, runId)
end

-- Registered event names (the module names in Server/Events).
function EventDirector.Names(): { string }
	local out = {}
	for name in handlers do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

function EventDirector.Init(s: Instance)
	store = s
	for _, m in (script.Parent:WaitForChild("Events") :: Instance):GetChildren() do
		if m:IsA("ModuleScript") then
			handlers[m.Name] = require(m) :: any
		end
	end
end

return EventDirector

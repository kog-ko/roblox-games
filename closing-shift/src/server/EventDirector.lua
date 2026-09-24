--!strict
-- The horror layer: one "wrong" event every 45-75s, each at most once per round.
-- Tension only: no damage, no chasing, nothing gory.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage.Shared.Config)
local SpillService = require(script.Parent.SpillService)
local StoreBuilder = require(script.Parent.StoreBuilder)

local EventDirector = {}
local store: Instance
local runId = 0
local rng = Random.new()

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
	s.RollOffMaxDistance = 90
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 4)
end

local function buildMannequin(cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Mannequin"
	local skin = Color3.fromRGB(205, 200, 188)
	local function block(name: string, size: Vector3, offset: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = skin
		p.Size = size
		p.CFrame = cf * CFrame.new(offset)
		p.Parent = m
	end
	block("Head", Vector3.new(1.2, 1.3, 1.2), Vector3.new(0, 6.1, 0))
	block("Torso", Vector3.new(2, 2.4, 1), Vector3.new(0, 4.2, 0))
	block("LeftArm", Vector3.new(0.7, 2.4, 0.7), Vector3.new(-1.4, 4.2, 0))
	block("RightArm", Vector3.new(0.7, 2.4, 0.7), Vector3.new(1.4, 4.2, 0))
	block("LeftLeg", Vector3.new(0.8, 3, 0.8), Vector3.new(-0.5, 1.5, 0))
	block("RightLeg", Vector3.new(0.8, 3, 0.8), Vector3.new(0.5, 1.5, 0))
	m.Parent = store:FindFirstChild("EventProps")
	return m
end

local events: { [string]: () -> () } = {}

-- Aisle signs briefly read 1, 2, 3, 5.
events.SignGlitch = function()
	setSignNumbers({ 1, 2, 3, 5 })
	task.wait(Config.SignGlitchTime)
	setSignNumbers({ 1, 2, 3, 4 })
end

-- Footprints lead from the aisles into the back room.
events.Footprints = function()
	SpillService.SpawnFootprints({
		Vector3.new(17, 0, 4), Vector3.new(17, 0, -13), Vector3.new(29, 0, -12.5), Vector3.new(37, 0, -12),
	}, 3)
end

-- The door chime rings. Nobody is there.
events.DoorChime = function()
	local bell = CollectionService:GetTagged("DoorChime")[1]
	if bell then
		playSound(bell, Config.Sounds.Chime, 1)
		task.wait(0.45)
		playSound(bell, Config.Sounds.Chime, 0.8)
	end
end

-- One aisle becomes a wall of the same product.
events.IdenticalAisle = function()
	local list = aisles()
	local aisle = list[rng:NextInteger(1, #list)]
	local color = Color3.fromRGB(205, 205, 195)
	local size = Vector3.new(0.9, 1.3, 1.0)
	for _, p in aisle:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "Product" then
			local bottom = p.Position.Y - p.Size.Y / 2
			p.Color = color
			p.Size = size
			p.Position = Vector3.new(p.Position.X, bottom + size.Y / 2, p.Position.Z)
		end
	end
end

-- Lights die for 2 seconds; when they come back there's a spill behind whoever is nearest the back room.
events.LightsOut = function()
	local myRun = runId
	store:SetAttribute("Power", false)
	playSound(store:FindFirstChild("Lights") :: Instance, Config.Sounds.Buzz, 0.7)
	task.wait(Config.LightsOutTime)
	local target = (store:FindFirstChild("FinalSpillMarker", true) :: BasePart).Position
	local best, bestDist = nil, math.huge
	for _, r in roots() do
		local d = (r.Position - target).Magnitude
		if d < bestDist then
			best, bestDist = r, d
		end
	end
	if best and myRun == runId and not SpillService.IsFinalPhase() then
		local look = Vector3.new(best.CFrame.LookVector.X, 0, best.CFrame.LookVector.Z)
		look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
		local pos = best.Position - look * Config.BehindPlayerDistance
		if pos.X > 30.5 then -- in the back room
			pos = Vector3.new(math.clamp(pos.X, 32, 46), 0, math.clamp(pos.Z, -19, -5))
		else
			pos = Vector3.new(math.clamp(pos.X, -28, 29), 0, math.clamp(pos.Z, -15, 18))
		end
		SpillService.Spawn(pos)
	end
	if myRun == runId then -- the round may have ended in the dark
		store:SetAttribute("Power", true)
	end
end

-- A mannequin stands at the end of an aisle. It's gone once anyone gets within 15 studs.
events.Mannequin = function()
	local rs = roots()
	local bestPos, bestScore = nil, -1
	for _, a in aisles() do
		local plinth = a:FindFirstChild("Plinth") :: BasePart
		local pos = Vector3.new(plinth.Position.X, 0, plinth.Position.Z - plinth.Size.Z / 2 - 1.5)
		local nearest = math.huge
		for _, r in rs do
			nearest = math.min(nearest, (r.Position - pos).Magnitude)
		end
		if nearest > bestScore then
			bestPos, bestScore = pos, nearest
		end
	end
	if not bestPos then
		return
	end
	local m = buildMannequin(CFrame.lookAt(bestPos, bestPos + Vector3.zAxis))
	local myRun = runId
	local t = os.clock()
	while m.Parent and myRun == runId and os.clock() - t < 90 do
		for _, r in roots() do
			if (r.Position - bestPos).Magnitude < Config.MannequinVanishDistance then
				m:Destroy()
				return
			end
		end
		task.wait(0.2)
	end
	m:Destroy()
end

local SPILL_EVENTS = { Footprints = true, LightsOut = true }

function EventDirector.Start()
	runId += 1
	local myRun = runId
	local used: { [string]: boolean } = {}
	task.spawn(function()
		local gap = rng:NextNumber(Config.EventMinGap, Config.EventMaxGap)
		while true do
			task.wait(gap)
			if myRun ~= runId then
				return
			end
			local choices = {}
			for name in events do
				if not used[name] and not (SPILL_EVENTS[name] and SpillService.IsFinalPhase()) then
					table.insert(choices, name)
				end
			end
			if #choices == 0 then
				return
			end
			local pick = choices[rng:NextInteger(1, #choices)]
			used[pick] = true
			print("[EventDirector] event:", pick)
			task.spawn(function()
				local ok, err = pcall(events[pick])
				if not ok then
					warn("[EventDirector]", pick, "failed:", err)
				end
			end)
			gap = rng:NextNumber(Config.EventMinGap, Config.EventMaxGap)
		end
	end)
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
	store:SetAttribute("Power", true)
end

-- For playtesting: run one event by name right now.
function EventDirector.Force(name: string)
	local fn = events[name]
	if fn then
		task.spawn(fn)
	end
end

function EventDirector.Init(s: Instance)
	store = s
end

return EventDirector

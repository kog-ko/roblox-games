--!strict
-- Spawns puddles, validates every clean on the server, and handles the back-room final spill.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage.Shared.Config)
local CleanedRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Cleaned") :: RemoteEvent
local Mop = require(script.Parent.Mop)

type Spill = {
	Model: Model,
	Parts: { BasePart },
	Sizes: { Vector3 },
	Prompt: ProximityPrompt,
	IsFinal: boolean,
	Holds: { [Player]: number },
	Finished: { [Player]: number }, -- completed holds waiting for Triggered
	Squeaks: { [Player]: Sound }, -- looping mop squeak per player, stopped when the hold ends
	Done: boolean,
}

local SpillService = {}
-- Hooks set by RoundManager
SpillService.OnCleaned = nil :: ((Player, boolean) -> ())?
SpillService.OnFinalSpawned = nil :: (() -> ())?

local COLORS = {
	Color3.fromRGB(110, 80, 50), -- coffee
	Color3.fromRGB(90, 140, 70), -- lime soda
	Color3.fromRGB(70, 110, 160), -- sports drink
	Color3.fromRGB(160, 150, 90), -- mystery
}

local store: Instance
local folder: Instance
local active: { [Model]: Spill } = {}
local finalPending = false
local accepting = false
local rng = Random.new()

local function updateCount()
	local n = 0
	for _ in active do
		n += 1
	end
	if finalPending then
		n += 1
	end
	ReplicatedStorage:SetAttribute("SpillsRemaining", n)
end

local function holdTime(player: Player): number
	local mult = if player:GetAttribute("IndustrialMop") then 1 - Config.IndustrialMopSpeedup else 1
	mult *= (player:GetAttribute("CleanTimeMult") or 1) :: number -- Mop Speed upgrade
	return Config.CleanHoldTime * mult
end

local function playAt(position: Vector3, soundId: string, volume: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = folder
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume
	s.PlaybackSpeed = 1 + (rng:NextNumber() * 2 - 1) * Config.PitchVariation
	s.RollOffMaxDistance = 60
	s.Parent = anchor
	s:Play()
	Debris:AddItem(anchor, 3)
end

-- Server-side checks: shift running, mop in hand, close enough.
local function canClean(player: Player, spill: Spill): boolean
	if not accepting or spill.Done or not Mop.IsHolding(player) then
		return false
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local maxDist = Config.CleanDistance + Config.CleanServerSlack
	for _, p in spill.Parts do
		local d = Vector3.new(root.Position.X - p.Position.X, 0, root.Position.Z - p.Position.Z).Magnitude
		if d - p.Size.Y / 2 <= maxDist then
			return true
		end
	end
	return false
end

-- Loops a short slice of the squeak clip for as long as the player holds the prompt.
local function startSqueak(spill: Spill, player: Player, anchor: BasePart)
	local old = spill.Squeaks[player]
	if old then
		old:Destroy()
	end
	local s = Instance.new("Sound")
	s.SoundId = Config.Sounds.Squeak
	s.Volume = 0.6
	s.RollOffMaxDistance = 60
	s.Looped = true
	s.PlaybackRegionsEnabled = true
	s.PlaybackSpeed = 1 + (rng:NextNumber() * 2 - 1) * Config.PitchVariation
	s.TimePosition = Config.ScrubLoop.Min
	s.LoopRegion = Config.ScrubLoop
	s.Parent = anchor
	s:Play()
	spill.Squeaks[player] = s
end

local function stopSqueak(spill: Spill, player: Player)
	local s = spill.Squeaks[player]
	spill.Squeaks[player] = nil
	if s then
		s:Destroy()
	end
end

local function tweenSizes(spill: Spill, scale: number, t: number)
	for i, p in spill.Parts do
		local s = spill.Sizes[i]
		TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Linear), {
			Size = Vector3.new(s.X, s.Y * scale, s.Z * scale),
		}):Play()
	end
end

local function finish(spill: Spill, player: Player)
	spill.Done = true
	spill.Prompt.Enabled = false
	for p in spill.Squeaks do
		stopSqueak(spill, p)
	end
	active[spill.Model] = nil
	playAt(spill.Parts[1].Position, if rng:NextNumber() < 0.5 then Config.Sounds.Splash else Config.Sounds.Splash2, 0.9)
	-- every client plays the clean effects; the cleaner also gets the personal reward
	local c = spill.Parts[1].Color
	CleanedRemote:FireAllClients(spill.Parts[1].Position, c, player, spill.IsFinal)
	tweenSizes(spill, 0.01, 0.25)
	Debris:AddItem(spill.Model, 0.3)
	if spill.IsFinal then
		finalPending = false
	end
	updateCount()
	if SpillService.OnCleaned then
		SpillService.OnCleaned(player, spill.IsFinal)
	end
	-- Everything on the floor is clean: bring out the back-room spill.
	if next(active) == nil and finalPending and accepting then
		finalPending = false
		local marker = store:FindFirstChild("FinalSpillMarker", true) :: BasePart
		SpillService.Spawn(marker.Position, true)
		if SpillService.OnFinalSpawned then
			SpillService.OnFinalSpawned()
		end
	end
end

local function makeSpill(parts: { BasePart }, anchorPos: Vector3, isFinal: boolean): Spill
	local m = Instance.new("Model")
	m.Name = if isFinal then "FinalSpill" else "Spill"
	for _, p in parts do
		p.Parent = m
	end
	local anchor = Instance.new("Part")
	anchor.Name = "PromptAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = anchorPos + Vector3.new(0, 1, 0)
	anchor.Parent = m

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Mop"
	prompt.ObjectText = if isFinal then "???" else "Spill"
	prompt.HoldDuration = Config.CleanHoldTime
	prompt.MaxActivationDistance = Config.CleanDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = anchor
	CollectionService:AddTag(prompt, "SpillPrompt")

	local sizes = {}
	for i, p in parts do
		sizes[i] = p.Size
	end
	local spill: Spill = { Model = m, Parts = parts, Sizes = sizes, Prompt = prompt, IsFinal = isFinal, Holds = {}, Finished = {}, Squeaks = {}, Done = false }

	prompt.PromptButtonHoldBegan:Connect(function(player)
		if canClean(player, spill) then
			spill.Holds[player] = os.clock()
			tweenSizes(spill, 0.35, holdTime(player))
			startSqueak(spill, player, anchor)
		end
	end)
	local function shrinkBack()
		if not spill.Done and next(spill.Holds) == nil and next(spill.Finished) == nil then
			tweenSizes(spill, 1, 0.3)
		end
	end
	-- A completed hold fires HoldEnded *before* Triggered, so remember a full-length hold
	-- here and let Triggered consume it.
	prompt.PromptButtonHoldEnded:Connect(function(player)
		stopSqueak(spill, player)
		local began = spill.Holds[player]
		spill.Holds[player] = nil
		if began and os.clock() - began >= holdTime(player) * Config.CleanTimeTolerance then
			local stamp = os.clock()
			spill.Finished[player] = stamp
			task.delay(1, function() -- Triggered never came
				if spill.Finished[player] == stamp then
					spill.Finished[player] = nil
					shrinkBack()
				end
			end)
		else
			shrinkBack()
		end
	end)
	prompt.Triggered:Connect(function(player)
		-- The hold must really have happened, for about as long as it should take.
		local began = spill.Holds[player]
		local finished = spill.Finished[player]
		spill.Holds[player] = nil
		spill.Finished[player] = nil
		local fullHold = finished ~= nil
			or (began ~= nil and os.clock() - began >= holdTime(player) * Config.CleanTimeTolerance)
		if fullHold and canClean(player, spill) then
			finish(spill, player)
		else
			shrinkBack()
		end
	end)

	active[m] = spill
	-- puddles spread out from a drop instead of popping in
	if parts[1].Name == "Puddle" then
		for i, p in parts do
			local sz = sizes[i]
			p.Size = Vector3.new(sz.X, sz.Y * 0.1, sz.Z * 0.1)
		end
		tweenSizes(spill, 1, 0.5)
	end
	m.Parent = folder
	updateCount()
	return spill
end

local function puddle(pos: Vector3, radius: number, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = "Puddle"
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Transparency = 0.15
	p.Size = Vector3.new(0.08, radius * 2, radius * 2)
	p.CFrame = CFrame.new(pos.X, 0.1, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

function SpillService.Spawn(pos: Vector3, isFinal: boolean?)
	local color = if isFinal then Color3.fromRGB(40, 40, 45) else COLORS[rng:NextInteger(1, #COLORS)]
	local r = rng:NextNumber(Config.SpillMinRadius, Config.SpillMaxRadius)
	local parts = { puddle(pos, r, color) }
	-- a couple of splatter blobs so it doesn't look like a perfect coin
	for _ = 1, 2 do
		local off = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * r * 0.9
		table.insert(parts, puddle(pos + off, r * rng:NextNumber(0.3, 0.5), color))
	end
	return makeSpill(parts, pos, isFinal == true)
end

-- A trail of blocky footprints split into a few cleanable chunks.
function SpillService.SpawnFootprints(path: { Vector3 }, chunks: number)
	local prints: { { cf: CFrame } } = {}
	local side = 1
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local dir = (b - a).Unit
		local right = dir:Cross(Vector3.yAxis)
		local len = (b - a).Magnitude
		local d = 0
		while d < len do
			local pos = a + dir * d + right * 0.45 * side
			table.insert(prints, { cf = CFrame.lookAt(Vector3.new(pos.X, 0.09, pos.Z), Vector3.new(pos.X + dir.X, 0.09, pos.Z + dir.Z)) })
			side = -side
			d += 1.8
		end
	end
	local per = math.ceil(#prints / chunks)
	for c = 0, chunks - 1 do
		local parts = {}
		local sum = Vector3.zero
		for i = c * per + 1, math.min((c + 1) * per, #prints) do
			local p = Instance.new("Part")
			p.Name = "Footprint"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic
			p.Color = Color3.fromRGB(55, 60, 50)
			p.Size = Vector3.new(0.7, 0.05, 1.4)
			p.CFrame = prints[i].cf
			table.insert(parts, p)
			sum += p.Position
		end
		if #parts > 0 then
			makeSpill(parts, sum / #parts, false)
		end
	end
end

function SpillService.StartRound(count: number)
	SpillService.Reset()
	accepting = true
	finalPending = true
	local markers = (store:FindFirstChild("SpillMarkers") :: Instance):GetChildren()
	for i = #markers, 2, -1 do
		local j = rng:NextInteger(1, i)
		markers[i], markers[j] = markers[j], markers[i]
	end
	for i = 1, math.min(count - 1, #markers) do
		local m = markers[i] :: BasePart
		SpillService.Spawn(m.Position + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)))
	end
	updateCount()
end

-- Floor spills still on the floor (not the back-room one), for boosts that clean or count them.
function SpillService.FloorSpills(): { Model }
	local out = {}
	for m, s in active do
		if not s.IsFinal and not s.Done then
			table.insert(out, m)
		end
	end
	return out
end

-- Cleans one spill on someone's behalf (Hire a Janitor). Returns true if it was still there.
function SpillService.CleanForPlayer(m: Model, player: Player): boolean
	local s = active[m]
	if not s or s.Done or not accepting then
		return false
	end
	finish(s, player)
	return true
end

-- Adds spills at free markers (Spill Storm). Returns how many were added.
function SpillService.SpawnExtra(count: number): number
	if not accepting or not finalPending then
		return 0 -- only while the floor still has to be cleaned
	end
	local markers = (store:FindFirstChild("SpillMarkers") :: Instance):GetChildren()
	for i = #markers, 2, -1 do
		local j = rng:NextInteger(1, i)
		markers[i], markers[j] = markers[j], markers[i]
	end
	local added = 0
	for _, mk in markers do
		if added >= count then
			break
		end
		local pos = (mk :: BasePart).Position
		local free = true
		for _, s in active do
			if (s.Parts[1].Position - pos).Magnitude < 6 then
				free = false
				break
			end
		end
		if free then
			SpillService.Spawn(pos + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)))
			added += 1
		end
	end
	return added
end

-- Clock In Late: start accepting cleans again and clear away half of the floor spills left.
function SpillService.Resume(keepFraction: number)
	local floor = SpillService.FloorSpills()
	local remove = #floor - math.ceil(#floor * keepFraction)
	for i = 1, remove do
		local s = active[floor[i]]
		if s then
			s.Done = true
			active[floor[i]] = nil
			floor[i]:Destroy()
		end
	end
	accepting = true
	updateCount()
	-- if that emptied the floor, the back-room spill appears as usual
	if next(active) == nil and finalPending then
		finalPending = false
		local marker = store:FindFirstChild("FinalSpillMarker", true) :: BasePart
		SpillService.Spawn(marker.Position, true)
		if SpillService.OnFinalSpawned then
			SpillService.OnFinalSpawned()
		end
	end
end

function SpillService.IsFinalPhase(): boolean
	return not finalPending
end

function SpillService.Stop()
	accepting = false
end

function SpillService.Reset()
	accepting = false
	finalPending = false
	active = {}
	folder:ClearAllChildren()
	updateCount()
end

-- Playtest helper: walk a player's character to the next spill and clean it (skips the prompt).
function SpillService.DebugCleanOne(player: Player): boolean
	for _, s in active do
		local char = player.Character
		if char then
			char:PivotTo(CFrame.new(s.Parts[1].Position + Vector3.new(0, 3, 0)))
		end
		finish(s, player)
		return true
	end
	return false
end

function SpillService.Init(s: Instance)
	store = s
	folder = store:FindFirstChild("Spills") :: Instance
	updateCount()
	-- someone who leaves mid-mop: stop their squeak and forget their hold
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		for _, spill in active do
			stopSqueak(spill, player)
			spill.Holds[player] = nil
			spill.Finished[player] = nil
		end
	end)
end

return SpillService

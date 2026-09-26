--!strict
-- Lobby -> Shift (2:00 AM to 6:00 AM) -> Payoff or Lights out -> Results -> Lobby.
-- Round state is published as ReplicatedStorage attributes so the client can just read it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.Rules)
local SpillService = require(script.Parent.SpillService)
local EventDirector = require(script.Parent.EventDirector)
local Payoff = require(script.Parent.Payoff)
local DataService = require(script.Parent.DataService)
local Leaderboard = require(script.Parent.Leaderboard)
local Badges = require(script.Parent.Badges)
local Mop = require(script.Parent.Mop)
local Manager = require(script.Parent.Manager)
local Economy = require(script.Parent.Economy)
local ServerBoosts = require(script.Parent.ServerBoosts)
local Analytics = require(script.Parent.Analytics)
local Jobs = require(script.Parent.Jobs)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ResultsRemote = Remotes:WaitForChild("Results") :: RemoteEvent
local ReadyRemote = Remotes:WaitForChild("ReadyUp") :: RemoteEvent

local RoundManager = {}
-- Hook (set by Monetization): called per player after each shift's results, with won = true/false.
RoundManager.OnShiftResult = nil :: ((Player, boolean) -> ())?
local store: Instance
local readyRequested = false
local won = false
local finalCleaned = false
local finalCleaner: Player? = nil
local skipTimer = false -- playtest helper: end the shift now
local penalty = 0 -- seconds taken off this shift's clock (Manager catches)
local shiftStart = 0
local reviveRequested = false -- Clock In Late bought on the YOU'RE FIRED screen
local revivedThisNight = false
-- true once anything bought with Robux helped this night (a server boost, Second Chance, Clock In
-- Late, coffee, the Industrial Mop): the clean time then isn't submitted to the fastest-shift board
local assisted = false
-- A private server made by a lobby queue (not one a player owns): the crew arrives by teleport
-- with the night they queued for, and the first shift starts as soon as they're all here.
local fromQueue = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local expectedCrew = 0
local firstLobby = true
local night = Config.DefaultNight -- which night the next shift plays (the shift board sets this)
local modifiers: { string } = {}

-- The highest night the whole party can play: the lowest "Unlocked" among players whose data
-- has loaded (players still loading don't hold everyone back).
local function groupUnlocked(): number
	local lowest = math.huge
	for _, p in Players:GetPlayers() do
		local u = p:GetAttribute("Unlocked")
		if type(u) == "number" then
			lowest = math.min(lowest, u)
		end
	end
	if lowest == math.huge then
		lowest = 1
	end
	return math.clamp(lowest, 1, Rules.NightCount())
end

-- Publishes the upcoming night so the lobby, HUD and clock can show it.
local function publishNight()
	local r = Rules.Resolve(night, modifiers)
	ReplicatedStorage:SetAttribute("Night", r.Night)
	ReplicatedStorage:SetAttribute("NightName", r.Name)
	ReplicatedStorage:SetAttribute("ShiftLength", r.ShiftLength)
	ReplicatedStorage:SetAttribute("GroupUnlocked", groupUnlocked())
end

local function setPhase(p: string)
	ReplicatedStorage:SetAttribute("Phase", p)
	print("[Round] phase:", p)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function spawnCFrame(): CFrame
	local sp = store:FindFirstChild("SpawnPoint") :: BasePart
	return sp.CFrame + Vector3.new(math.random() * 3 - 1.5, 3, math.random() * 3 - 1.5)
end

local function onCleaned(player: Player, isFinal: boolean, counts: boolean)
	player:SetAttribute("Cleaned", ((player:GetAttribute("Cleaned") or 0) :: number) + 1)
	if counts then
		-- spills you mopped yourself: these go on the weekly board
		player:SetAttribute("RankedCleaned", ((player:GetAttribute("RankedCleaned") or 0) :: number) + 1)
	end
	if player:GetAttribute("IndustrialMop") then
		assisted = true
	end
	DataService.Update(player, function(p)
		p.Stats.TotalCleaned += 1
	end)
	Analytics.Step(player, Analytics.Funnel.FirstSpill)
	if isFinal then
		finalCleaned = true
		finalCleaner = player
	end
	if finalCleaned and ReplicatedStorage:GetAttribute("SpillsRemaining") == 0 then
		won = true
	end
end

local function resetStore()
	SpillService.Reset()
	EventDirector.Cleanup()
	Payoff.Reset()
	store:SetAttribute("Power", true)
end

local function runLobby()
	setPhase("Lobby")
	resetStore()
	for _, p in Players:GetPlayers() do
		Mop.Remove(p)
		task.spawn(function()
			pcall(p.LoadCharacter, p) -- fresh spawn behind the counter
		end)
	end
	readyRequested = false
	local intermission = Config.IntermissionTime
	if fromQueue and firstLobby then
		firstLobby = false
		-- the crew is still teleporting in: wait for everyone (and their saves) before checking unlocks
		local t = os.clock()
		while os.clock() - t < Config.ArrivalWait do
			local players = Players:GetPlayers()
			local loaded = #players > 0
			for _, p in players do
				if type(p:GetAttribute("Unlocked")) ~= "number" then
					loaded = false
				end
			end
			if loaded and #players >= math.max(expectedCrew, 1) then
				break
			end
			ReplicatedStorage:SetAttribute("Countdown", math.ceil(Config.ArrivalWait - (os.clock() - t)))
			task.wait(0.2)
		end
		intermission = 5
	end
	if night > groupUnlocked() then
		night = groupUnlocked()
	end
	publishNight()
	local deadline = os.clock() + intermission
	while true do
		if #Players:GetPlayers() == 0 then
			deadline = os.clock() + intermission
		elseif readyRequested or os.clock() >= deadline then
			break
		end
		ReplicatedStorage:SetAttribute("Countdown", math.ceil(deadline - os.clock()))
		task.wait(0.1)
	end
	ReplicatedStorage:SetAttribute("Countdown", 0)
end

local shiftLoop: (Rules.Rules, number) -> number?

-- Returns clean time in seconds, or nil if the clock ran out.
local function runShift(rules: Rules.Rules): number?
	won, finalCleaned, finalCleaner, skipTimer, penalty = false, false, nil, false, 0
	assisted = false
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Cleaned", 0)
		p:SetAttribute("RankedCleaned", 0)
		p:SetAttribute("CoffeeUsed", false)
		p:SetAttribute("CaughtThisShift", false)
		p:SetAttribute("CoffeeUntil", nil)
		local char = p.Character
		if char then
			char:PivotTo(spawnCFrame())
		end
	end
	setPhase("Shift")
	for _, p in Players:GetPlayers() do
		Mop.Give(p)
		if rules.Night >= 3 then
			Analytics.Step(p, Analytics.Funnel.ReachedNight3)
		elseif rules.Night == 2 then
			Analytics.Step(p, Analytics.Funnel.ReachedNight2)
		end
	end
	SpillService.StartRound(rules.SpillCount)
	revivedThisNight = false
	return shiftLoop(rules, now())
end

-- Runs a shift from a (virtual) start time until it's won or the clock runs out.
-- Returns clean time in seconds, or nil if the clock ran out.
function shiftLoop(rules: Rules.Rules, start: number): number?
	shiftStart = start
	ReplicatedStorage:SetAttribute("ShiftStart", start)
	ReplicatedStorage:SetAttribute("ShiftEndsAt", start + rules.ShiftLength)
	EventDirector.Start(rules)
	if not ServerBoosts.IsDayOff() then
		Manager.Start(rules)
	end
	ServerBoosts.OnShiftStart()

	while not won and not skipTimer and now() < start + rules.ShiftLength - penalty do
		if #Players:GetPlayers() == 0 then
			break -- the last player left: end the night now instead of running an empty clock
		end
		task.wait(0.1)
	end
	EventDirector.Stop()
	Manager.Stop()
	SpillService.Stop()

	if won then
		local t = now() - start + penalty -- lost time counts against the clean time
		setPhase("Payoff")
		Payoff.Run(finalCleaner)
		return t
	end
	setPhase("LightsOut")
	store:SetAttribute("Power", false)
	task.wait(Config.LightsOutOnLoseTime)
	return nil
end

local function runResults(rules: Rules.Rules, cleanTime: number?)
	local teamCleaned = 0
	local crew = {}
	for _, p in Players:GetPlayers() do
		local c = (p:GetAttribute("Cleaned") or 0) :: number
		teamCleaned += c
		table.insert(crew, { Name = p.DisplayName, UserId = p.UserId, Cleaned = c })
	end
	table.sort(crew, function(a, b)
		return a.Cleaned > b.Cleaned
	end)
	-- MVP: the crew's top cleaner, when there's a crew and a clear winner
	local mvp = if #crew > 1 and crew[1].Cleaned > crew[2].Cleaned then crew[1].UserId else nil
	local ranked = cleanTime ~= nil and not assisted
	local final = cleanTime ~= nil and rules.Night >= Rules.NightCount()
	local key = tostring(rules.Night)
	for _, p in Players:GetPlayers() do
		local newBest = false
		DataService.Update(p, function(prof)
			prof.Stats.ShiftsWorked += 1
			if cleanTime then
				prof.Stats.ShiftsWon += 1
				-- beating a night unlocks the next one
				prof.Unlocked = math.max(prof.Unlocked, math.min(rules.Night + 1, Rules.NightCount()))
				local best = prof.BestByNight[key]
				if best == nil or cleanTime < best then
					prof.BestByNight[key] = cleanTime
					newBest = true
				end
			end
		end)
		if cleanTime then
			if ranked then
				task.spawn(Leaderboard.Submit, rules.Night, p.UserId, cleanTime)
			end
			if cleanTime < rules.ShiftLength * Config.PerfectShiftFraction then
				Badges.Award(p, "PerfectShift")
			end
		end
		Badges.Award(p, "FirstShift")
		task.spawn(Leaderboard.AddWeekly, p, (p:GetAttribute("RankedCleaned") or 0) :: number)
		p:SetAttribute("RankedCleaned", 0) -- counted; a revive only adds new spills
		if cleanTime then
			Analytics.Event(p, "ShiftCompleted", math.floor(cleanTime * 10 + 0.5) / 10, rules.Name, rules.Night)
			if rules.Night == 1 then
				Analytics.Step(p, Analytics.Funnel.FinishedNight1)
			end
		else
			Analytics.Event(p, "ShiftFailed", (p:GetAttribute("Cleaned") or 0) :: number, rules.Name, rules.Night)
		end
		local pay = Economy.Paycheck(p, rules, cleanTime, finalCleaner == p)
		task.spawn(Leaderboard.AddEarnings, p, pay.Earned)
		-- daily / weekly jobs
		Jobs.Record(p, "clean", (p:GetAttribute("Cleaned") or 0) :: number)
		if finalCleaner == p then
			Jobs.Record(p, "backroom", 1)
		end
		if ((p:GetAttribute("CrewFriends") or 0) :: number) > 0 then
			Jobs.Record(p, "crew", 1)
		end
		if cleanTime then
			Jobs.Record(p, "win", 1)
			Jobs.Record(p, "winNight", 1, rules.Night)
			if rules.Manager.Enabled and not p:GetAttribute("CaughtThisShift") then
				Jobs.Record(p, "noCatch", 1)
			end
			if cleanTime < rules.ShiftLength * Config.Pay.FastFraction then
				Jobs.Record(p, "fast", 1)
			end
		end
		if RoundManager.OnShiftResult then
			task.spawn(RoundManager.OnShiftResult, p, cleanTime ~= nil)
		end
		task.spawn(DataService.Save, p)
		local prof = DataService.Get(p)
		if prof then
			task.spawn(Leaderboard.SetCareer, p, prof.Stats.TotalCleaned)
		end
		ResultsRemote:FireClient(p, {
			Outcome = if cleanTime then "Clean" else "Fired",
			CleanTime = cleanTime,
			Cleaned = p:GetAttribute("Cleaned") or 0,
			TeamCleaned = teamCleaned,
			Best = prof and prof.BestByNight[key],
			NewBest = newBest,
			TotalCleaned = prof and prof.Stats.TotalCleaned or 0,
			Night = rules.Night,
			NightName = rules.Name,
			Tease = rules.Tease,
			Final = final,
			Pay = pay,
			Cash = prof and prof.Cash or 0,
			Crew = crew,
			Mvp = mvp,
			Ranked = ranked,
		})
	end
	-- a win moves the party on to the next night (if everyone has it); a loss replays this one
	if cleanTime then
		night = math.min(rules.Night + 1, groupUnlocked(), Rules.NightCount())
	else
		night = math.min(rules.Night, groupUnlocked())
	end
	publishNight()
	setPhase("Results")
	-- YOU'RE FIRED: Clock In Late can be bought for a few seconds (once per night)
	local offer = cleanTime == nil and not revivedThisNight and Config.Monetization.Products.ClockInLate ~= 0
	local window = Config.Monetization.Rewards.ClockInLateWindow
	ReplicatedStorage:SetAttribute("ReviveOfferUntil", if offer then workspace:GetServerTimeNow() + window else nil)
	if offer then
		for _, p in Players:GetPlayers() do
			Analytics.Event(p, "OfferShown", 1, "ClockInLate", rules.Night)
		end
	end
	reviveRequested = false
	local waitUntil = os.clock() + Config.ResultsTime
	while os.clock() < waitUntil and not reviveRequested do
		task.wait(0.1)
	end
	ReplicatedStorage:SetAttribute("ReviveOfferUntil", nil)
	task.spawn(Leaderboard.Refresh, night)
	return reviveRequested
end

-- Clock In Late: the night picks up again at 5:00 AM with half the floor spills gone.
local function runRevive(rules: Rules.Rules): number?
	revivedThisNight = true
	assisted = true -- Clock In Late was bought
	night = rules.Night -- the loss moved nothing on, but make sure we replay the same night
	publishNight()
	won, skipTimer, penalty = false, false, 0
	for _, p in Players:GetPlayers() do
		-- the loss already paid for what was cleaned; count only new spills, and one shift worked
		p:SetAttribute("Cleaned", 0)
		DataService.Update(p, function(prof)
			prof.Stats.ShiftsWorked = math.max(0, prof.Stats.ShiftsWorked - 1)
		end)
	end
	store:SetAttribute("Power", true)
	setPhase("Shift")
	for _, p in Players:GetPlayers() do
		Mop.Give(p)
	end
	SpillService.Resume(0.5)
	-- a virtual start 3/4 of the way through the night puts the clock at 5:00 AM
	return shiftLoop(rules, now() - rules.ShiftLength * 0.75)
end

-- Clock In Late was bought: returns true if the revive was accepted.
function RoundManager.RequestRevive(): boolean
	if ReplicatedStorage:GetAttribute("Phase") ~= "Results" or revivedThisNight then
		return false
	end
	local untilT = ReplicatedStorage:GetAttribute("ReviveOfferUntil")
	if type(untilT) ~= "number" or workspace:GetServerTimeNow() > untilT + 2 then
		return false
	end
	reviveRequested = true
	return true
end

-- Chooses the night for the next shift (clamped to the nights that exist).
function RoundManager.SetNight(n: number)
	night = math.clamp(math.floor(n), 1, Rules.NightCount())
	publishNight()
end

function RoundManager.GetNight(): number
	return night
end

function RoundManager.GroupUnlocked(): number
	return groupUnlocked()
end

-- Playtest helpers (call from the server command bar while playing).
function RoundManager.ForceStart()
	readyRequested = true
end
function RoundManager.ForceTimeout()
	skipTimer = true
end

-- Something bought with Robux helped this night (coffee; the rest are tracked here).
function RoundManager.MarkAssisted()
	assisted = true
end

-- Takes seconds off the running shift: the clock jumps forward for everyone.
function RoundManager.AddPenalty(seconds: number)
	if ReplicatedStorage:GetAttribute("Phase") ~= "Shift" then
		return
	end
	penalty += seconds
	ReplicatedStorage:SetAttribute("ShiftStart", shiftStart - penalty)
	ReplicatedStorage:SetAttribute("ShiftEndsAt", shiftStart + (ReplicatedStorage:GetAttribute("ShiftLength") :: number) - penalty)
end

function RoundManager.Init(s: Instance)
	store = s
	publishNight()
	Manager.OnCatch = function(player: Player)
		player:SetAttribute("CaughtThisShift", true)
		DataService.Update(player, function(prof)
			prof.Stats.Catches += 1
		end)
		RoundManager.AddPenalty(Config.Manager.TimePenalty)
		Analytics.Event(player, "ManagerCatch", 1, nil, night)
		if Config.Monetization.Products.SecondChance ~= 0 then
			Analytics.Event(player, "OfferShown", 1, "SecondChance", night)
		end
	end
	Manager.OnUndoCatch = function(player: Player)
		assisted = true -- Second Chance was bought
		player:SetAttribute("CaughtThisShift", false)
		RoundManager.AddPenalty(-Config.Manager.TimePenalty)
	end
	SpillService.OnCleaned = onCleaned
	ServerBoosts.OnApplied = function()
		if ReplicatedStorage:GetAttribute("Phase") == "Shift" then
			assisted = true
		end
	end
	ReadyRemote.OnServerEvent:Connect(function()
		if ReplicatedStorage:GetAttribute("Phase") == "Lobby" then
			readyRequested = true
		end
	end)
	local function onCharacter(player: Player, char: Model)
		char:WaitForChild("Humanoid", 5)
		local phase = ReplicatedStorage:GetAttribute("Phase")
		if phase == "Shift" or phase == "Payoff" then
			task.wait() -- let the new Backpack settle
			Mop.Give(player)
		end
	end
	local function onPlayer(player: Player)
		-- arriving from a lobby queue: { Night = n, Crew = players in the queue }
		local data = player:GetJoinData().TeleportData
		if type(data) == "table" then
			if type(data.Night) == "number" and firstLobby then
				night = math.clamp(math.floor(data.Night), 1, Rules.NightCount())
				publishNight()
			end
			if type(data.Crew) == "number" then
				expectedCrew = math.max(expectedCrew, math.clamp(math.floor(data.Crew), 1, Config.Queue.MaxCrew))
			end
		end
		player:GetAttributeChangedSignal("Unlocked"):Connect(publishNight)
		player:SetAttribute("Cleaned", 0)
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		-- leaving mid-shift keeps the spills you already mopped on the weekly board
		local n = (player:GetAttribute("RankedCleaned") or 0) :: number
		if n > 0 then
			task.spawn(Leaderboard.AddWeekly, player, n)
		end
		task.defer(publishNight)
	end)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
end

function RoundManager.Run()
	while true do
		runLobby()
		local rules = Rules.Resolve(night, modifiers)
		print(string.format("[Round] night %d: %s (%d spills, %ds)", rules.Night, rules.Name, rules.SpillCount, rules.ShiftLength))
		local ok, result = pcall(runShift, rules)
		if not ok then
			warn("[Round] shift crashed:", result)
			result = nil
		end
		local revive = runResults(rules, result)
		while revive do
			local ok2, result2 = pcall(runRevive, rules)
			if not ok2 then
				warn("[Round] revive crashed:", result2)
				result2 = nil
			end
			revive = runResults(rules, result2)
		end
	end
end

return RoundManager

--!strict
-- Lobby -> Shift (2:00 AM to 6:00 AM) -> Payoff or Lights out -> Results -> Lobby.
-- Round state is published as ReplicatedStorage attributes so the client can just read it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local SpillService = require(script.Parent.SpillService)
local EventDirector = require(script.Parent.EventDirector)
local Payoff = require(script.Parent.Payoff)
local DataService = require(script.Parent.DataService)
local Leaderboard = require(script.Parent.Leaderboard)
local Badges = require(script.Parent.Badges)
local Mop = require(script.Parent.Mop)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ResultsRemote = Remotes:WaitForChild("Results") :: RemoteEvent
local ReadyRemote = Remotes:WaitForChild("ReadyUp") :: RemoteEvent

local RoundManager = {}
local store: Instance
local readyRequested = false
local won = false
local finalCleaned = false
local finalCleaner: Player? = nil
local skipTimer = false -- playtest helper: end the shift now

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

local function onCleaned(player: Player, isFinal: boolean)
	player:SetAttribute("Cleaned", ((player:GetAttribute("Cleaned") or 0) :: number) + 1)
	DataService.Update(player, function(p)
		p.TotalCleaned += 1
	end)
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
	local deadline = os.clock() + Config.IntermissionTime
	while true do
		if #Players:GetPlayers() == 0 then
			deadline = os.clock() + Config.IntermissionTime
		elseif readyRequested or os.clock() >= deadline then
			break
		end
		ReplicatedStorage:SetAttribute("Countdown", math.ceil(deadline - os.clock()))
		task.wait(0.1)
	end
	ReplicatedStorage:SetAttribute("Countdown", 0)
end

-- Returns clean time in seconds, or nil if the clock ran out.
local function runShift(): number?
	won, finalCleaned, finalCleaner, skipTimer = false, false, nil, false
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Cleaned", 0)
		p:SetAttribute("CoffeeUsed", false)
		p:SetAttribute("CoffeeUntil", nil)
		local char = p.Character
		if char then
			char:PivotTo(spawnCFrame())
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = Config.WalkSpeed
			end
		end
	end
	setPhase("Shift")
	for _, p in Players:GetPlayers() do
		Mop.Give(p)
	end
	SpillService.StartRound(Config.SpillCount)
	local start = now()
	ReplicatedStorage:SetAttribute("ShiftStart", start)
	ReplicatedStorage:SetAttribute("ShiftEndsAt", start + Config.ShiftLength)
	EventDirector.Start()

	while not won and not skipTimer and now() < start + Config.ShiftLength do
		task.wait(0.1)
	end
	EventDirector.Stop()
	SpillService.Stop()

	if won then
		local t = now() - start
		setPhase("Payoff")
		Payoff.Run(finalCleaner)
		return t
	end
	setPhase("LightsOut")
	store:SetAttribute("Power", false)
	task.wait(Config.LightsOutOnLoseTime)
	return nil
end

local function runResults(cleanTime: number?)
	local teamCleaned = 0
	for _, p in Players:GetPlayers() do
		teamCleaned += (p:GetAttribute("Cleaned") or 0) :: number
	end
	for _, p in Players:GetPlayers() do
		local newBest = false
		if cleanTime then
			DataService.Update(p, function(prof)
				if prof.Best == nil or cleanTime < (prof.Best :: number) then
					prof.Best = cleanTime
					newBest = true
				end
			end)
			task.spawn(Leaderboard.Submit, p.UserId, cleanTime)
			if cleanTime < Config.PerfectShiftTime then
				Badges.Award(p, "PerfectShift")
			end
		end
		Badges.Award(p, "FirstShift")
		task.spawn(DataService.Save, p)
		ResultsRemote:FireClient(p, {
			Outcome = if cleanTime then "Clean" else "Fired",
			CleanTime = cleanTime,
			Cleaned = p:GetAttribute("Cleaned") or 0,
			TeamCleaned = teamCleaned,
			Best = p:GetAttribute("Best"),
			NewBest = newBest,
			TotalCleaned = p:GetAttribute("TotalCleaned") or 0,
		})
	end
	setPhase("Results")
	task.wait(Config.ResultsTime)
	task.spawn(Leaderboard.Refresh)
end

-- Playtest helpers (call from the server command bar while playing).
function RoundManager.ForceStart()
	readyRequested = true
end
function RoundManager.ForceTimeout()
	skipTimer = true
end

function RoundManager.Init(s: Instance)
	store = s
	SpillService.OnCleaned = onCleaned
	ReadyRemote.OnServerEvent:Connect(function()
		if ReplicatedStorage:GetAttribute("Phase") == "Lobby" then
			readyRequested = true
		end
	end)
	local function onCharacter(player: Player, char: Model)
		local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
		if hum then
			hum.WalkSpeed = Config.WalkSpeed
		end
		local phase = ReplicatedStorage:GetAttribute("Phase")
		if phase == "Shift" or phase == "Payoff" then
			task.wait() -- let the new Backpack settle
			Mop.Give(player)
		end
	end
	local function onPlayer(player: Player)
		player:SetAttribute("Cleaned", 0)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
end

function RoundManager.Run()
	while true do
		runLobby()
		local ok, result = pcall(runShift)
		if not ok then
			warn("[Round] shift crashed:", result)
			result = nil
		end
		runResults(result)
	end
end

return RoundManager

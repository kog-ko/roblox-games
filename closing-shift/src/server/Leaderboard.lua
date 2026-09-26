--!strict
-- Two global boards, shown in turn on the board by the counter:
--   EMPLOYEE OF THE WEEK   most spills cleaned this week (resets Monday 00:00 UTC; one
--                          OrderedDataStore per week). Only spills you mopped yourself count:
--                          Spill Storm spills and the paid janitor's cleans don't.
--   FASTEST NIGHT N        top-10 clean times for the selected night. Runs helped by anything
--                          bought with Robux (see RoundManager) aren't submitted.
-- Last week's top 3 get a trophy on their name tag all week (player attribute WeeklyTrophy = 1..3).
-- Times are stored as integer tenths of a second (ascending = fastest first).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Clock = require(ReplicatedStorage.Shared.Clock)
local Progress = require(ReplicatedStorage.Shared.Progress)

local Leaderboard = {}
local stores: { [string]: OrderedDataStore } = {}

-- Studio test sessions (workspace attribute TestNoSave) never write to the live boards.
local function testNoSave(): boolean
	return game:GetService("RunService"):IsStudio() and workspace:GetAttribute("TestNoSave") == true
end
local offline = false
local names: { [number]: string } = {}
local titleLabel: TextLabel? = nil
local listLabel: TextLabel? = nil
local pages = { weekly = "loading...", night = "loading..." }
local trophies: { [number]: number } = {} -- userId -> last week's rank (1..3)

local function goOffline(err: any)
	if offline then
		return -- warn once per session
	end
	offline = true
	warn("[Leaderboard] offline this session:", err)
	pages.weekly = "board offline\n(publish the place and\nenable API access)"
	pages.night = pages.weekly
end

local function nameFor(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok then name else ("#" .. userId)
	names[userId] = result
	return result
end

local function ordered(name: string): OrderedDataStore?
	if offline then
		return nil
	end
	if stores[name] then
		return stores[name]
	end
	local ok, res = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
	if not ok then
		goOffline(res)
		return nil
	end
	stores[name] = res
	return res
end

-- ClosingShift_BestTimes_v1 -> ClosingShift_BestTimes_N2_v1 for night 2
local function nightStore(night: number): OrderedDataStore?
	return ordered((Config.LeaderboardStoreName:gsub("_v(%d+)$", "_N" .. night .. "_v%1")))
end

-- ClosingShift_WeeklySpills_v1 -> ClosingShift_WeeklySpills_W2960_v1
local function weekStore(week: number): OrderedDataStore?
	return ordered((Config.WeeklyStoreName:gsub("_v(%d+)$", "_W" .. week .. "_v%1")))
end

local function top(ods: OrderedDataStore, ascending: boolean, size: number): { any }?
	local ok, result = pcall(ods.GetSortedAsync, ods, ascending, size)
	if not ok then
		goOffline(result)
		return nil
	end
	return (result :: DataStorePages):GetCurrentPage()
end

local function currentNight(): number
	return (ReplicatedStorage:GetAttribute("Night") or 1) :: number
end

local function show(page: string)
	if not (titleLabel and listLabel) then
		return
	end
	if page == "weekly" then
		titleLabel.Text = "EMPLOYEE OF THE WEEK"
		titleLabel.TextColor3 = Color3.fromRGB(255, 205, 70)
		listLabel.Text = pages.weekly
	else
		titleLabel.Text = "FASTEST SHIFTS"
		titleLabel.TextColor3 = Color3.fromRGB(220, 210, 140)
		listLabel.Text = pages.night
	end
end

function Leaderboard.Refresh(night: number?)
	local n = night or currentNight()
	local ods = nightStore(n)
	local entries = ods and top(ods, true, Config.LeaderboardSize)
	if entries then
		local lines = { string.format("NIGHT %d", n) }
		for rank, entry in entries do
			local uid = tonumber(entry.key) or 0
			table.insert(lines, string.format("%2d. %-16s %s", rank, nameFor(uid):sub(1, 16), Clock.Duration(entry.value / 10)))
		end
		pages.night = if #lines > 1 then table.concat(lines, "\n") else string.format("NIGHT %d\nno clean shifts yet.\nbe the first.", n)
	end
	local week = Progress.Week()
	local wods = weekStore(week)
	local wentries = wods and top(wods, false, Config.LeaderboardSize)
	if wentries then
		local left = Progress.WeekEnds(week) - os.time()
		local lines = { string.format("SPILLS  (RESETS %dD %dH)", left // 86400, (left % 86400) // 3600) }
		for rank, entry in wentries do
			local uid = tonumber(entry.key) or 0
			table.insert(lines, string.format("%2d. %-16s %d", rank, nameFor(uid):sub(1, 16), entry.value))
		end
		pages.weekly = if #lines > 1 then table.concat(lines, "\n") else lines[1] .. "\nnobody yet this week.\nclean something."
	end
end

-- Records a time if it beats the player's previous entry.
function Leaderboard.Submit(night: number, userId: number, seconds: number)
	if testNoSave() then
		return
	end
	local ods = nightStore(night)
	if not ods then
		return
	end
	local value = math.floor(seconds * 10)
	for attempt = 1, Config.DataRetries do
		local ok, err = pcall(function()
			ods:UpdateAsync(tostring(userId), function(old)
				if type(old) == "number" and old <= value then
					return nil -- keep the faster time
				end
				return value
			end)
		end)
		if ok then
			return
		end
		warn("[Leaderboard] submit failed:", err)
		task.wait(2 ^ attempt)
	end
end

-- Lifetime earnings (cash a shift paid before multipliers) and career spills, for the lobby boards.
function Leaderboard.AddEarnings(player: Player, amount: number)
	if testNoSave() then
		return
	end
	local ods = ordered(Config.EarningsStoreName)
	if ods and amount > 0 then
		local ok, err = pcall(ods.IncrementAsync, ods, tostring(player.UserId), math.floor(amount))
		if not ok then
			warn("[Leaderboard] earnings add failed:", err)
		end
	end
end

function Leaderboard.SetCareer(player: Player, totalCleaned: number)
	if testNoSave() then
		return
	end
	local ods = ordered(Config.CareerStoreName)
	if ods and totalCleaned > 0 then
		local ok, err = pcall(ods.SetAsync, ods, tostring(player.UserId), math.floor(totalCleaned))
		if not ok then
			warn("[Leaderboard] career set failed:", err)
		end
	end
end

-- Top entries for a lobby board: kind = "weekly" | "night" (arg = night) | "earnings" | "career".
-- Returns { { Name, Value } } best first, or nil if the board is unavailable.
function Leaderboard.Entries(kind: string, arg: number?, size: number?): { { Name: string, UserId: number, Value: number } }?
	local ods
	local ascending = false
	if kind == "weekly" then
		ods = weekStore(Progress.Week())
	elseif kind == "night" then
		ods = nightStore(arg or 1)
		ascending = true
	elseif kind == "earnings" then
		ods = ordered(Config.EarningsStoreName)
	elseif kind == "career" then
		ods = ordered(Config.CareerStoreName)
	end
	local entries = ods and top(ods, ascending, size or Config.LeaderboardSize)
	if not entries then
		return nil
	end
	local out = {}
	for _, e in entries do
		local uid = tonumber(e.key) or 0
		table.insert(out, { Name = nameFor(uid), UserId = uid, Value = e.value })
	end
	return out
end

-- Adds spills to this week's count for a player; publishes their new total (WeeklyCleaned).
function Leaderboard.AddWeekly(player: Player, spills: number)
	if testNoSave() then
		return
	end
	if spills <= 0 then
		return
	end
	local ods = weekStore(Progress.Week())
	if not ods then
		return
	end
	for attempt = 1, Config.DataRetries do
		local ok, result = pcall(ods.IncrementAsync, ods, tostring(player.UserId), spills)
		if ok then
			if player.Parent then
				player:SetAttribute("WeeklyCleaned", result)
			end
			return
		end
		warn("[Leaderboard] weekly add failed:", result)
		task.wait(2 ^ attempt)
	end
end

local function loadWeekly(player: Player)
	local ods = weekStore(Progress.Week())
	if not ods then
		return
	end
	local ok, value = pcall(ods.GetAsync, ods, tostring(player.UserId))
	if ok and player.Parent then
		player:SetAttribute("WeeklyCleaned", if type(value) == "number" then value else 0)
	end
end

local function applyTrophy(player: Player)
	player:SetAttribute("WeeklyTrophy", trophies[player.UserId])
end

-- Last week's top 3 (their trophies last all of this week).
local function refreshTrophies()
	local ods = weekStore(Progress.Week() - 1)
	local entries = ods and top(ods, false, 3)
	if not entries then
		return
	end
	trophies = {}
	for rank, entry in entries do
		local uid = tonumber(entry.key)
		if uid and entry.value > 0 then
			trophies[uid] = rank
		end
	end
	for _, p in Players:GetPlayers() do
		applyTrophy(p)
	end
end

function Leaderboard.Init(store: Instance)
	local board = store:FindFirstChild("Leaderboard")
	local gui = board and board:FindFirstChild("BoardGui", true)
	if gui then
		for _, c in gui:GetChildren() do
			if c:IsA("TextLabel") then
				if c.Name == "List" then
					listLabel = c
				elseif not titleLabel then
					titleLabel = c
				end
			end
		end
	end
	local function onPlayer(p: Player)
		applyTrophy(p)
		task.spawn(loadWeekly, p)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	ReplicatedStorage:GetAttributeChangedSignal("Night"):Connect(function()
		task.spawn(Leaderboard.Refresh)
	end)
	task.spawn(function()
		while not offline do
			Leaderboard.Refresh()
			task.wait(Config.LeaderboardRefresh)
		end
	end)
	task.spawn(function()
		while not offline do
			refreshTrophies()
			task.wait(Config.TrophyRefresh)
		end
	end)
	-- the board alternates between the two pages
	task.spawn(function()
		local page = "weekly"
		while true do
			show(page)
			task.wait(Config.BoardCycle)
			page = if page == "weekly" then "night" else "weekly"
		end
	end)
end

return Leaderboard

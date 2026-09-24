--!strict
-- Global top-10 fastest clean times (OrderedDataStore), drawn on the board by the counter.
-- Times are stored as integer tenths of a second (ascending = fastest first).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Clock = require(ReplicatedStorage.Shared.Clock)

local Leaderboard = {}
local ordered: OrderedDataStore? = nil
local offline = false
local names: { [number]: string } = {}
local listLabel: TextLabel? = nil

local function setText(t: string)
	if listLabel then
		listLabel.Text = t
	end
end

local function goOffline(err: any)
	offline = true
	warn("[Leaderboard] offline this session:", err)
	setText("board offline\n(publish the place and\nenable API access)")
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

function Leaderboard.Refresh()
	if offline or not ordered then
		return
	end
	local ods = ordered :: OrderedDataStore
	local ok, pages = pcall(ods.GetSortedAsync, ods, true, Config.LeaderboardSize)
	if not ok then
		goOffline(pages)
		return
	end
	local lines = {}
	for rank, entry in (pages :: DataStorePages):GetCurrentPage() do
		local uid = tonumber(entry.key) or 0
		table.insert(lines, string.format("%2d. %-16s %s", rank, nameFor(uid):sub(1, 16), Clock.Duration(entry.value / 10)))
	end
	setText(if #lines > 0 then table.concat(lines, "\n") else "no clean shifts yet.\nbe the first.")
end

-- Records a time if it beats the player's previous entry.
function Leaderboard.Submit(userId: number, seconds: number)
	if offline or not ordered then
		return
	end
	local ods = ordered :: OrderedDataStore
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

function Leaderboard.Init(store: Instance)
	local board = store:FindFirstChild("Leaderboard")
	local label = board and board:FindFirstChild("List", true)
	if label and label:IsA("TextLabel") then
		listLabel = label
	end
	local ok, res = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.LeaderboardStoreName)
	if ok then
		ordered = res
	else
		goOffline(res)
		return
	end
	task.spawn(function()
		while not offline do
			Leaderboard.Refresh()
			task.wait(Config.LeaderboardRefresh)
		end
	end)
end

return Leaderboard

--!strict
-- Global top-10 fastest clean times per night (one OrderedDataStore per night), drawn on the
-- board by the counter for whichever night is selected. Times are stored as integer tenths of a
-- second (ascending = fastest first).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Clock = require(ReplicatedStorage.Shared.Clock)

local Leaderboard = {}
local stores: { [number]: OrderedDataStore } = {}
local offline = false
local names: { [number]: string } = {}
local listLabel: TextLabel? = nil

local function setText(t: string)
	if listLabel then
		listLabel.Text = t
	end
end

local function goOffline(err: any)
	if offline then
		return -- warn once per session
	end
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

-- ClosingShift_BestTimes_v1 -> ClosingShift_BestTimes_N2_v1 for night 2
local function storeFor(night: number): OrderedDataStore?
	if offline then
		return nil
	end
	if stores[night] then
		return stores[night]
	end
	local name = Config.LeaderboardStoreName:gsub("_v(%d+)$", "_N" .. night .. "_v%1")
	local ok, res = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
	if not ok then
		goOffline(res)
		return nil
	end
	stores[night] = res
	return res
end

local function currentNight(): number
	return (ReplicatedStorage:GetAttribute("Night") or 1) :: number
end

function Leaderboard.Refresh(night: number?)
	local n = night or currentNight()
	local ods = storeFor(n)
	if not ods then
		return
	end
	local ok, pages = pcall(ods.GetSortedAsync, ods, true, Config.LeaderboardSize)
	if not ok then
		goOffline(pages)
		return
	end
	local lines = { string.format("NIGHT %d", n) }
	for rank, entry in (pages :: DataStorePages):GetCurrentPage() do
		local uid = tonumber(entry.key) or 0
		table.insert(lines, string.format("%2d. %-16s %s", rank, nameFor(uid):sub(1, 16), Clock.Duration(entry.value / 10)))
	end
	setText(if #lines > 1 then table.concat(lines, "\n") else string.format("NIGHT %d\nno clean shifts yet.\nbe the first.", n))
end

-- Records a time if it beats the player's previous entry.
function Leaderboard.Submit(night: number, userId: number, seconds: number)
	local ods = storeFor(night)
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

function Leaderboard.Init(store: Instance)
	local board = store:FindFirstChild("Leaderboard")
	local label = board and board:FindFirstChild("List", true)
	if label and label:IsA("TextLabel") then
		listLabel = label
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
end

return Leaderboard

--!strict
-- Career ranks and leaderboard weeks, shared so the server and the HUD always agree.
local Config = require(script.Parent.Config)

local Progress = {}

-- The rank for a lifetime spill count: its index, its name, and the count the next rank needs
-- (nil at the top rank).
function Progress.Rank(cleaned: number): (number, string, number?)
	local index = 1
	for i, r in Config.Ranks do
		if cleaned >= r.Cleaned then
			index = i
		end
	end
	local nextRank = Config.Ranks[index + 1]
	return index, Config.Ranks[index].Name, if nextRank then nextRank.Cleaned else nil
end

-- Leaderboard weeks run Monday 00:00 UTC to the next Monday. 1970-01-05 was a Monday.
local FIRST_MONDAY = 4 * 86400
local WEEK = 7 * 86400

function Progress.Week(t: number?): number
	return math.floor(((t or os.time()) - FIRST_MONDAY) / WEEK)
end

-- Unix time the given week ends (when the weekly board resets).
function Progress.WeekEnds(week: number): number
	return FIRST_MONDAY + (week + 1) * WEEK
end

-- Days (UTC) since the epoch: the daily jobs and the daily bonus roll over at midnight UTC.
function Progress.Day(t: number?): number
	return math.floor((t or os.time()) / 86400)
end

-- Picks count jobs from a pool, the same for everyone on a given day/week (seeded shuffle).
local function pick(pool: { any }, count: number, seed: number): { any }
	local order = {}
	for i = 1, #pool do
		order[i] = i
	end
	local rng = Random.new(seed)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local out = {}
	for i = 1, math.min(count, #pool) do
		table.insert(out, pool[order[i]])
	end
	return out
end

function Progress.DailyJobs(day: number?): { any }
	return pick(Config.Challenges.Daily, Config.Challenges.DailyCount, 1000 + (day or Progress.Day()))
end

function Progress.WeeklyJobs(week: number?): { any }
	return pick(Config.Challenges.Weekly, Config.Challenges.WeeklyCount, 500000 + (week or Progress.Week()))
end

return Progress

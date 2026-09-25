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

return Progress

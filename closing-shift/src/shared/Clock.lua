--!strict
-- Maps real shift seconds onto the in-game 2:00 AM -> 6:00 AM clock. Shift length is per night.
local Config = require(script.Parent.Config)

local Clock = {}

function Clock.Format(elapsed: number, shiftLength: number): string
	local span = (Config.ShiftEndHour - Config.ShiftStartHour) * 60
	local gameMinutes = math.clamp(elapsed / shiftLength, 0, 1) * span
	local total = Config.ShiftStartHour * 60 + math.floor(gameMinutes)
	local h = total // 60
	local m = total % 60
	return string.format("%d:%02d AM", h, m)
end

-- 187.4 -> "3:07.4"
function Clock.Duration(seconds: number): string
	local m = math.floor(seconds / 60)
	local s = seconds - m * 60
	return string.format("%d:%04.1f", m, s)
end

return Clock

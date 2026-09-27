--!strict
-- Which limited-time event (Data/Seasons) is running right now, if any. Server and client both
-- ask; they agree because it's just the date.
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)

local Season = {}

function Season.Current(): any?
	if RunService:IsStudio() then
		local forced = workspace:GetAttribute("ForceSeason")
		if type(forced) == "string" then
			for _, s in Config.Seasons do
				if s.Id == forced then
					return s
				end
			end
		end
	end
	local now = os.time()
	for _, s in Config.Seasons do
		if now >= s.Start and now < s.End then
			return s
		end
	end
	return nil
end

function Season.IsActive(id: string): boolean
	local s = Season.Current()
	return s ~= nil and s.Id == id
end

-- "ENDS IN 5D 3H"
function Season.EndsIn(s: any): string
	local left = math.max(0, s.End - os.time())
	return string.format("ENDS IN %dD %dH", left // 86400, (left % 86400) // 3600)
end

return Season

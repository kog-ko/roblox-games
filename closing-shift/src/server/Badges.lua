--!strict
-- Awards badges from Config.Badges. An ID of 0 means "not set up yet" and is skipped quietly.
local BadgeService = game:GetService("BadgeService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Badges = {}
local awarded: { [string]: boolean } = {}

function Badges.Award(player: Player, key: string)
	local id = (Config.Badges :: any)[key] :: number?
	if not id or id == 0 then
		return
	end
	local cacheKey = player.UserId .. ":" .. key
	if awarded[cacheKey] then
		return
	end
	awarded[cacheKey] = true
	task.spawn(function()
		local okHas, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, id)
		if okHas and has then
			return
		end
		local ok, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
		if not ok then
			awarded[cacheKey] = nil
			warn("[Badges] could not award", key, err)
		end
	end)
end

return Badges

--!strict
-- Turns a night (Data/Nights) plus any modifiers (Data/Modifiers) into the numbers a shift runs on.
-- The server and clients both call this, so they always agree.
local Config = require(script.Parent.Config)

export type Rules = {
	Night: number,
	Name: string,
	SpillCount: number,
	ShiftLength: number,
	Events: { string },
	EventGap: { number },
	Manager: { Enabled: boolean, Speed: number },
	PowerCuts: { Enabled: boolean, Every: { number }, Duration: { number } },
	Store: string,
	Tutorial: boolean,
	Tease: string,
	WinBonus: number,
	WalkSpeedMult: number,
	Modifiers: { string },
	Crew: number,
	BigSpillChance: number,
}

local Rules = {}

function Rules.NightCount(): number
	return #Config.Nights
end

-- crew: how many players are working the shift (defaults to 1). Bigger crews get more spills, a bit
-- more time and more frequent events; the store also opens more zones for them (server Zones.lua).
function Rules.Resolve(night: number, modifiers: { string }?, crew: number?): Rules
	local n = Config.Nights[math.clamp(night, 1, #Config.Nights)]
	local r: Rules = {
		Night = math.clamp(night, 1, #Config.Nights),
		Name = n.Name,
		SpillCount = n.SpillCount,
		ShiftLength = n.ShiftLength,
		Events = table.clone(n.Events),
		EventGap = table.clone(n.EventGap),
		Manager = table.clone(n.Manager),
		PowerCuts = { Enabled = n.PowerCuts.Enabled, Every = table.clone(n.PowerCuts.Every), Duration = table.clone(n.PowerCuts.Duration) },
		Store = n.Store,
		Tutorial = n.Tutorial == true,
		Tease = n.Tease or "",
		WinBonus = n.WinBonus or 0,
		WalkSpeedMult = 1,
		Modifiers = {},
		Crew = math.max(1, math.floor(crew or 1)),
		BigSpillChance = n.BigSpillChance or 0,
	}
	local extra = r.Crew - 1
	r.SpillCount += (n.SpillsPerExtra or 0) * extra
	r.ShiftLength = math.floor(r.ShiftLength * (1 + (n.TimePerExtra or 0) * extra) + 0.5)
	r.EventGap = { r.EventGap[1] / (1 + 0.1 * extra), r.EventGap[2] / (1 + 0.1 * extra) }
	for _, id in modifiers or {} do
		local m = Config.Modifiers[id]
		if m then
			table.insert(r.Modifiers, id)
			r.SpillCount = math.max(2, math.floor(r.SpillCount * (m.SpillCountMult or 1) + 0.5))
			r.ShiftLength *= m.ShiftLengthMult or 1
			r.EventGap = { r.EventGap[1] * (m.EventGapMult or 1), r.EventGap[2] * (m.EventGapMult or 1) }
			r.Manager.Speed *= m.ManagerSpeedMult or 1
			r.WalkSpeedMult *= m.WalkSpeedMult or 1
			if m.PowerCuts then
				r.PowerCuts.Enabled = true
			end
		end
	end
	return r
end

return Rules

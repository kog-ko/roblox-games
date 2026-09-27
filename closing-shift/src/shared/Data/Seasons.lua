--!strict
-- Limited-time events. Each switches itself on and off by date (UTC unix times), in both places:
-- decorations, its currency, its cosmetics (bought with that currency, only while it runs; you keep
-- them afterwards) and any event-only scares (added to every night's event list).
-- In Studio, workspace attribute ForceSeason = "<Id>" runs one early for testing.
export type Season = {
	Id: string,
	Name: string,
	Start: number,
	End: number,
	Currency: string, -- display name of the event currency (saved as profile Candy)
	Events: { string }, -- extra "wrong" events during shifts (Server/Events)
	Music: string?, -- first track of the lobby playlist
	CandyPerShift: number, -- pickups hidden around the store each shift
	CandyPerWin: number, -- for clearing a night
	CandyPerOvertimeMinute: number,
}

local Seasons: { Season } = {
	{
		Id = "Halloween",
		Name = "HALLOWEEN",
		Start = 1790812800, -- 2026-10-01 00:00 UTC
		End = 1793577600, -- 2026-11-02 00:00 UTC
		Currency = "CANDY",
		Events = { "Pumpkin" },
		Music = "rbxassetid://139190190976686", -- Halloween Music Box (APM)
		CandyPerShift = 8,
		CandyPerWin = 10,
		CandyPerOvertimeMinute = 2,
	},
}

return Seasons

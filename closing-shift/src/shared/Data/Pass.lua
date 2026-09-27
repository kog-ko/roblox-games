--!strict
-- The Shift Pass: a season of tiers earned by playing (XP), each with a free reward and a premium
-- reward (premium = the ShiftPass game pass; buying it mid-season hands over every premium reward
-- you've already reached). Rewards: Cash = n, Candy = n (only while an event runs), Cosmetic = id
-- (pass items below in Data/Cosmetics, Pass = the season Id).
-- A new season: add a table with a new Id; progress is kept per season.
export type Reward = { Cash: number?, Candy: number?, Cosmetic: string? }
export type Tier = { Free: Reward?, Premium: Reward? }

-- XP for what you do (both places).
local Xp = {
	Spill = 3,
	NightCleared = 60,
	OvertimeMinute = 15,
	Job = 40,
	Achievement = 50,
	Obby = 25,
}

local function tiers(): { Tier }
	local list: { Tier } = {}
	for i = 1, 30 do
		list[i] = {
			Free = { Cash = 100 + i * 10 },
			Premium = { Cash = 250 + i * 25 },
		}
	end
	-- the cosmetics (everything else pays cash; tiers 8/18/28 pay event candy too while it runs)
	list[1].Premium = { Cosmetic = "VestManager" }
	list[5].Free = { Cosmetic = "TagNightOwl" }
	list[10].Premium = { Cosmetic = "BeamStrobe" }
	list[15].Free = { Cosmetic = "VestReflective" }
	list[20].Premium = { Cosmetic = "MopGraveyard" }
	list[25].Premium = { Cosmetic = "TagManager" }
	list[30].Free = { Cosmetic = "TrailFluorescent" }
	list[30].Premium = { Cosmetic = "TrailBodycam" }
	for _, i in { 8, 18, 28 } do
		list[i].Free = { Cash = 100 + i * 10, Candy = 15 }
		list[i].Premium = { Cash = 250 + i * 25, Candy = 40 }
	end
	return list
end

local Pass = {
	Xp = Xp,
	XpPerTier = 300,
	Seasons = {
		{
			Id = "S1",
			Name = "SHIFT PASS: SEASON 1",
			Start = 1790467200, -- 2026-09-27 00:00 UTC
			End = 1796083200, -- 2026-12-01 00:00 UTC
			Tiers = tiers(),
		},
	},
}

return Pass

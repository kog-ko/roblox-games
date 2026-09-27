--!strict
-- Achievements: one-time goals with a cash reward, shown in the lobby's ACHIEVEMENTS panel and
-- announced when you earn them. Stat is a key of the profile's Stats (see Achievements.lua on
-- the server for the few that are worked out: ObbyClears, NightsCleared, BestStreak).
--
-- Day streaks (Streaks): clock in (lobby time clock, or your first shift of the day) on consecutive
-- UTC days. Milestones pay extra and some unlock a cosmetic.
export type Achievement = { Id: string, Name: string, Text: string, Stat: string, Goal: number, Reward: number }

local Achievements: { List: { Achievement }, Streaks: { { Days: number, Reward: number, Cosmetic: string? } } } = {
	List = {
		-- cleaning
		{ Id = "clean1", Name = "FIRST MOP", Text = "Clean your first spill", Stat = "TotalCleaned", Goal = 1, Reward = 50 },
		{ Id = "clean100", Name = "ELBOW GREASE", Text = "Clean 100 spills", Stat = "TotalCleaned", Goal = 100, Reward = 300 },
		{ Id = "clean500", Name = "SPOTLESS", Text = "Clean 500 spills", Stat = "TotalCleaned", Goal = 500, Reward = 1000 },
		{ Id = "clean2000", Name = "THE FLOOR IS CLEAN", Text = "Clean 2,000 spills", Stat = "TotalCleaned", Goal = 2000, Reward = 4000 },
		{ Id = "big25", Name = "HEAVY DUTY", Text = "Finish 25 big spills", Stat = "BigSpills", Goal = 25, Reward = 500 },
		-- shifts
		{ Id = "win1", Name = "CLOCKED OUT", Text = "Clear a night", Stat = "ShiftsWon", Goal = 1, Reward = 100 },
		{ Id = "win25", Name = "RELIABLE", Text = "Clear 25 nights", Stat = "ShiftsWon", Goal = 25, Reward = 800 },
		{ Id = "win100", Name = "LIFER", Text = "Clear 100 nights", Stat = "ShiftsWon", Goal = 100, Reward = 3000 },
		{ Id = "allnights", Name = "EVERY NIGHT", Text = "Clear nights 1 to 3", Stat = "NightsCleared", Goal = 3, Reward = 1000 },
		{ Id = "inventory", Name = "LIGHTS OUT", Text = "Clear Night 4: Inventory", Stat = "NightsCleared", Goal = 4, Reward = 1500 },
		{ Id = "perfect5", Name = "SPEED CLEANER", Text = "Get 5 fast-shift bonuses", Stat = "FastShifts", Goal = 5, Reward = 600 },
		{ Id = "mvp10", Name = "EMPLOYEE OF THE NIGHT", Text = "Be crew MVP 10 times", Stat = "Mvps", Goal = 10, Reward = 800 },
		{ Id = "crew10", Name = "TEAM PLAYER", Text = "Finish 10 nights with a friend", Stat = "CrewShifts", Goal = 10, Reward = 800 },
		-- overtime
		{ Id = "ot5", Name = "PAID BY THE HOUR", Text = "Last 5 minutes in Overtime", Stat = "BestOvertime", Goal = 300, Reward = 400 },
		{ Id = "ot15", Name = "DOUBLE SHIFT", Text = "Last 15 minutes in Overtime", Stat = "BestOvertime", Goal = 900, Reward = 2000 },
		-- the Manager
		{ Id = "caught1", Name = "SENT HOME", Text = "Get caught by the Night Manager", Stat = "Catches", Goal = 1, Reward = 50 },
		{ Id = "escape1", Name = "NOT TODAY", Text = "Break free of the Night Manager", Stat = "Escapes", Goal = 1, Reward = 200 },
		{ Id = "escape10", Name = "SLIPPERY", Text = "Break free 10 times", Stat = "Escapes", Goal = 10, Reward = 1000 },
		{ Id = "nocatch10", Name = "UNSEEN", Text = "Clear 10 Manager nights without being caught", Stat = "NoCatchWins", Goal = 10, Reward = 1200 },
		-- events
		{ Id = "leak5", Name = "PLUMBER", Text = "Shut off 5 leaks", Stat = "LeaksShut", Goal = 5, Reward = 500 },
		{ Id = "rare1", Name = "WE'RE CLOSED", Text = "See the late customer", Stat = "RareSeen", Goal = 1, Reward = 500 },
		{ Id = "rare5", Name = "REGULAR", Text = "Send the late customer away 5 times", Stat = "RareBanished", Goal = 5, Reward = 1500 },
		-- events
		{ Id = "candy150", Name = "SWEET TOOTH", Text = "Collect 150 event candy", Stat = "CandyTotal", Goal = 150, Reward = 750 },
		-- lobby
		{ Id = "obby1", Name = "PARKOUR", Text = "Clear a lobby obby", Stat = "ObbyClears", Goal = 1, Reward = 100 },
		{ Id = "obby30", Name = "ROOFTOP REGULAR", Text = "Clear lobby obbies 30 times", Stat = "ObbyClears", Goal = 30, Reward = 1000 },
		-- streaks
		{ Id = "streak3", Name = "SHOWING UP", Text = "Clock in 3 days in a row", Stat = "BestStreak", Goal = 3, Reward = 150 },
		{ Id = "streak7", Name = "FULL WEEK", Text = "Clock in 7 days in a row", Stat = "BestStreak", Goal = 7, Reward = 500 },
		{ Id = "streak30", Name = "EMPLOYEE OF THE MONTH", Text = "Clock in 30 days in a row", Stat = "BestStreak", Goal = 30, Reward = 3000 },
	},
	-- extra on top of the daily bonus when your streak reaches these days
	Streaks = {
		{ Days = 3, Reward = 150 },
		{ Days = 7, Reward = 500, Cosmetic = "TagStreak" },
		{ Days = 14, Reward = 1000 },
		{ Days = 30, Reward = 3000, Cosmetic = "VestMonth" },
		{ Days = 60, Reward = 6000 },
		{ Days = 100, Reward = 10000 },
	},
}

return Achievements

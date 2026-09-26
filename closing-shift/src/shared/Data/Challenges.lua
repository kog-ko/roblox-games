--!strict
-- Daily and weekly jobs, shown on the JOB BOARD in the lobby and on the shift's results screen.
-- Each day (UTC) everyone gets the same 3 daily jobs, and each week (Monday) the same 2 weekly
-- ones, picked from these pools. Finishing a job pays its reward in cash at once.
--
-- Kinds (counted in the shift place at the end of each night):
--   clean      spills you cleaned
--   win        nights your crew cleared
--   winNight   nights cleared of a given Night (Arg)
--   noCatch    Manager nights cleared without being caught
--   backroom   back-room spills you cleaned
--   crew       nights finished with at least one Roblox friend in the crew
--   fast       nights cleared fast enough for the FAST SHIFT bonus
export type Job = { Id: string, Text: string, Kind: string, Goal: number, Reward: number, Arg: number? }

local Challenges: { DailyCount: number, WeeklyCount: number, Daily: { Job }, Weekly: { Job } } = {
	DailyCount = 3,
	WeeklyCount = 2,
	Daily = {
		{ Id = "d_clean15", Text = "CLEAN 15 SPILLS", Kind = "clean", Goal = 15, Reward = 150 },
		{ Id = "d_clean30", Text = "CLEAN 30 SPILLS", Kind = "clean", Goal = 30, Reward = 300 },
		{ Id = "d_win2", Text = "CLEAR 2 NIGHTS", Kind = "win", Goal = 2, Reward = 200 },
		{ Id = "d_win3", Text = "CLEAR 3 NIGHTS", Kind = "win", Goal = 3, Reward = 300 },
		{ Id = "d_n2", Text = "CLEAR NIGHT 2", Kind = "winNight", Arg = 2, Goal = 1, Reward = 250 },
		{ Id = "d_n3", Text = "CLEAR NIGHT 3", Kind = "winNight", Arg = 3, Goal = 1, Reward = 400 },
		{ Id = "d_nocatch", Text = "CLEAR A MANAGER NIGHT WITHOUT GETTING CAUGHT", Kind = "noCatch", Goal = 1, Reward = 300 },
		{ Id = "d_backroom", Text = "CLEAN THE BACK-ROOM SPILL", Kind = "backroom", Goal = 1, Reward = 200 },
		{ Id = "d_crew", Text = "FINISH A NIGHT WITH A FRIEND", Kind = "crew", Goal = 1, Reward = 250 },
		{ Id = "d_fast", Text = "GET A FAST SHIFT BONUS", Kind = "fast", Goal = 1, Reward = 250 },
	},
	Weekly = {
		{ Id = "w_clean200", Text = "CLEAN 200 SPILLS", Kind = "clean", Goal = 200, Reward = 2000 },
		{ Id = "w_win15", Text = "CLEAR 15 NIGHTS", Kind = "win", Goal = 15, Reward = 2000 },
		{ Id = "w_n3x5", Text = "CLEAR NIGHT 3 FIVE TIMES", Kind = "winNight", Arg = 3, Goal = 5, Reward = 3000 },
		{ Id = "w_nocatch5", Text = "CLEAR 5 MANAGER NIGHTS UNCAUGHT", Kind = "noCatch", Goal = 5, Reward = 2500 },
		{ Id = "w_crew5", Text = "FINISH 5 NIGHTS WITH FRIENDS", Kind = "crew", Goal = 5, Reward = 2500 },
		{ Id = "w_backroom5", Text = "CLEAN 5 BACK-ROOM SPILLS", Kind = "backroom", Goal = 5, Reward = 1500 },
	},
}

return Challenges

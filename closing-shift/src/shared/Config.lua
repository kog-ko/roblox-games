--!strict
-- CLOSING SHIFT: every tunable number and every ID lives here.
-- This is in ReplicatedStorage because the client needs the timings and pass/product IDs.
-- There are no secrets in here, so that's fine.

local Config = {}

-- Round flow (seconds)
Config.IntermissionTime = 15
Config.ShiftLength = 8 * 60 -- real seconds that map to 2:00 AM -> 6:00 AM
Config.ShiftStartHour = 2
Config.ShiftEndHour = 6
Config.PayoffTime = 12 -- back-room reveal before the results screen
Config.ResultsTime = 10
Config.LightsOutOnLoseTime = 2.5

-- Spills
Config.SpillCount = 12 -- total per round; the last one always spawns in the back room
Config.SpillMinRadius = 2.2
Config.SpillMaxRadius = 3.6
Config.CleanHoldTime = 1.6 -- ProximityPrompt hold duration (seconds)
Config.CleanDistance = 8 -- prompt activation distance (studs)
Config.CleanServerSlack = 3 -- extra studs the server tolerates for lag
Config.CleanTimeTolerance = 0.8 -- server accepts a hold this fraction of the expected length (ping)

-- Wrong events (the horror layer)
Config.EventMinGap = 45
Config.EventMaxGap = 75
Config.SignGlitchTime = 4
Config.LightsOutTime = 2
Config.MannequinVanishDistance = 15
Config.BehindPlayerDistance = 6

-- Speeds
Config.WalkSpeed = 16
Config.CoffeeWalkSpeed = 24
Config.CoffeeDuration = 30
Config.IndustrialMopSpeedup = 0.25 -- 25% faster cleaning

-- Scoring / badges
Config.PerfectShiftTime = 5 * 60 -- "Perfect Shift" = cleaned under this many seconds
Config.LeaderboardSize = 10
Config.LeaderboardRefresh = 60
Config.AutosaveInterval = 120
Config.DataRetries = 3

-- Sounds. These are built-in engine sounds, so they always load and can't be moderated away.
-- Swap in any asset ID ("rbxassetid://123") if you prefer something else.
Config.Sounds = {
	Squeak = "rbxasset://sounds/action_swim.mp3", -- plays while mopping
	Splash = "rbxasset://sounds/impact_water.mp3", -- plays when a spill is cleaned
	Chime = "rbxasset://sounds/electronicpingshort.wav", -- front door chime
	Buzz = "rbxasset://sounds/clickfast.wav", -- lights cutting out
}
Config.SqueakLoopLength = 0.8 -- seconds of the squeak clip looped while mopping

-- ===== IDs: fill these in (0 = disabled, the game just skips it) =====
-- Badges: Creator Dashboard > your experience > Engagement > Badges > Create a Badge.
--   Copy the number from the badge's URL or its "Copy Asset ID" menu.
Config.Badges = {
	FirstShift = 0,
	PerfectShift = 0,
	FoundTheNote = 0,
}

-- Game pass: Creator Dashboard > your experience > Monetization > Passes > Create a Pass.
--   Put it on sale, then copy its ID.
Config.GamePasses = {
	IndustrialMop = 0,
}

-- Developer product: Creator Dashboard > your experience > Monetization > Developer Products > Create.
Config.DevProducts = {
	ExtraCoffee = 0,
}

-- DataStore names (bump the version suffix to wipe test data)
Config.DataStoreName = "ClosingShift_Players_v1"
Config.LeaderboardStoreName = "ClosingShift_BestTimes_v1"

return Config

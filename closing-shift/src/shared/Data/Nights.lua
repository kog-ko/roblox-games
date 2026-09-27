--!strict
-- The campaign. Each night is pure data; the round system reads everything from here.
-- To add a night, append a table below (see README "Adding content").
--
--   Name         shown on the shift board and the HUD
--   SpillCount   spills per shift for one player, including the final back-room spill
--   ShiftLength  real seconds for 2:00 AM -> 6:00 AM, for one player
--   SpillsPerExtra  extra spills for each player beyond the first
--   TimePerExtra    extra shift length per extra player, as a fraction (0.12 = +12%)
--   BigSpillChance  chance a spill is a big one (two cleans; two players can split it)
--   Events       which "wrong" events may happen (names of modules in Server/Events)
--   EventGap     {min, max} seconds between events
--   Manager      the Night Manager: Enabled, Speed (studs/second)
--   PowerCuts    Enabled, Every {min, max} seconds, Duration {min, max} seconds
--   Store        which store layout to use (Data/Stores)
--   Tutorial     show the on-screen tutorial hints
--   Tease        line shown on the results screen, hinting at the next night
--   WinBonus     paycheck bonus for clearing the night
--   Dark         the power is out for the whole shift; spills only show up in your flashlight
--   Endless      no clock, no back-room spill: survive as long as you can (Overtime)
--   UnlockAt     (endless modes) available once the crew's Unlocked night reaches this
local Nights = {
	{
		Name = "Orientation",
		SpillCount = 12,
		ShiftLength = 4.5 * 60,
		SpillsPerExtra = 5,
		TimePerExtra = 0.12,
		BigSpillChance = 0,
		Events = {},
		EventGap = { 60, 90 },
		Manager = { Enabled = false, Speed = 0 },
		PowerCuts = { Enabled = false, Every = { 60, 90 }, Duration = { 8, 12 } },
		Store = "QuikStop",
		Tutorial = true,
		Tease = "Tomorrow night, management is coming in.",
		WinBonus = 40,
	},
	{
		Name = "Management",
		SpillCount = 16,
		ShiftLength = 5.5 * 60,
		SpillsPerExtra = 6,
		TimePerExtra = 0.12,
		BigSpillChance = 0.2,
		Events = { "SignGlitch", "DoorChime", "Footprints", "IdenticalAisle", "Mannequin", "Leak" },
		EventGap = { 45, 75 },
		Manager = { Enabled = true, Speed = 9 },
		PowerCuts = { Enabled = false, Every = { 60, 90 }, Duration = { 8, 12 } },
		Store = "QuikStop",
		Tutorial = false,
		Tease = "The breaker's been acting up. Bring a flashlight.",
		WinBonus = 80,
	},
	{
		Name = "Brownout",
		SpillCount = 20,
		ShiftLength = 6.5 * 60,
		SpillsPerExtra = 7,
		TimePerExtra = 0.12,
		BigSpillChance = 0.3,
		Events = { "SignGlitch", "DoorChime", "Footprints", "IdenticalAisle", "Mannequin", "LightsOut", "Leak" },
		EventGap = { 40, 65 },
		Manager = { Enabled = true, Speed = 11 },
		PowerCuts = { Enabled = true, Every = { 45, 75 }, Duration = { 10, 18 } },
		Store = "QuikStop",
		Tutorial = false,
		Tease = "Tomorrow is inventory night. The lights stay off.",
		WinBonus = 120,
	},
	{
		Name = "Inventory",
		SpillCount = 22,
		ShiftLength = 7 * 60,
		SpillsPerExtra = 7,
		TimePerExtra = 0.12,
		BigSpillChance = 0.3,
		Events = { "SignGlitch", "DoorChime", "Footprints", "IdenticalAisle", "Mannequin", "Leak" },
		EventGap = { 40, 65 },
		Manager = { Enabled = true, Speed = 12.5 },
		PowerCuts = { Enabled = false, Every = { 60, 90 }, Duration = { 8, 12 } },
		Dark = true,
		Store = "QuikStop",
		Tutorial = false,
		Tease = "NIGHT 5 COMING SOON. TRY OVERTIME IN THE MEANTIME.",
		WinBonus = 160,
	},
	-- OVERTIME: endless. No clock and no back-room spill; spills keep coming (Config.Overtime) and
	-- the shift ends when the mess gets out of hand. Opens once you've beaten Night 3.
	{
		Name = "Overtime",
		Endless = true,
		UnlockAt = 4,
		SpillCount = 10,
		ShiftLength = 3600, -- (not used: there's no clock)
		SpillsPerExtra = 4,
		TimePerExtra = 0,
		BigSpillChance = 0.25,
		Events = { "SignGlitch", "DoorChime", "Footprints", "IdenticalAisle", "Mannequin", "LightsOut", "Leak" },
		EventGap = { 35, 60 },
		Manager = { Enabled = true, Speed = 9 },
		PowerCuts = { Enabled = true, Every = { 60, 100 }, Duration = { 8, 14 } },
		Store = "QuikStop",
		Tutorial = false,
		Tease = "",
		WinBonus = 0,
	},
}

return Nights

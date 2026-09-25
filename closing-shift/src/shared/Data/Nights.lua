--!strict
-- The campaign. Each night is pure data; the round system reads everything from here.
-- To add a night, append a table below (see README "Adding content").
--
--   Name         shown on the shift board and the HUD
--   SpillCount   spills per shift, including the final back-room spill
--   ShiftLength  real seconds for 2:00 AM -> 6:00 AM
--   Events       which "wrong" events may happen (names of modules in Server/Events)
--   EventGap     {min, max} seconds between events
--   Manager      the Night Manager: Enabled, Speed (studs/second)
--   PowerCuts    Enabled, Every {min, max} seconds, Duration {min, max} seconds
--   Store        which store layout to use (Data/Stores)
--   Tutorial     show the on-screen tutorial hints
--   Tease        line shown on the results screen, hinting at the next night
local Nights = {
	{
		Name = "Orientation",
		SpillCount = 8,
		ShiftLength = 6 * 60,
		Events = {},
		EventGap = { 60, 90 },
		Manager = { Enabled = false, Speed = 0 },
		PowerCuts = { Enabled = false, Every = { 60, 90 }, Duration = { 8, 12 } },
		Store = "QuikStop",
		Tutorial = true,
		Tease = "Tomorrow night, management is coming in.",
	},
	{
		Name = "Management",
		SpillCount = 11,
		ShiftLength = 7 * 60,
		Events = { "SignGlitch", "DoorChime", "Footprints", "IdenticalAisle", "Mannequin" },
		EventGap = { 45, 75 },
		Manager = { Enabled = true, Speed = 9 },
		PowerCuts = { Enabled = false, Every = { 60, 90 }, Duration = { 8, 12 } },
		Store = "QuikStop",
		Tutorial = false,
		Tease = "The breaker's been acting up. Bring a flashlight.",
	},
	{
		Name = "Brownout",
		SpillCount = 13,
		ShiftLength = 8 * 60,
		Events = { "SignGlitch", "DoorChime", "Footprints", "IdenticalAisle", "Mannequin", "LightsOut" },
		EventGap = { 40, 65 },
		Manager = { Enabled = true, Speed = 11 },
		PowerCuts = { Enabled = true, Every = { 45, 75 }, Duration = { 10, 18 } },
		Store = "QuikStop",
		Tutorial = false,
		Tease = "NIGHTS 4-5 COMING SOON.",
	},
}

return Nights

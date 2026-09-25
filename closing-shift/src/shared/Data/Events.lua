--!strict
-- Tuning for each "wrong" event. The behaviour lives in Server/Events/<Name>.lua;
-- a night lists which events it allows (Data/Nights).
--   UsesSpills   the event creates spills, so it's skipped once only the back-room spill is left
--   Weight       relative chance of being picked
local Events = {
	SignGlitch = { Weight = 1, Duration = 4 },
	Footprints = { Weight = 1, UsesSpills = true, Chunks = 3 },
	DoorChime = { Weight = 1 },
	IdenticalAisle = { Weight = 1 },
	LightsOut = { Weight = 1, UsesSpills = true, Duration = 2, BehindPlayerDistance = 6 },
	Mannequin = { Weight = 1, VanishDistance = 15, MaxLifetime = 90 },
}

return Events

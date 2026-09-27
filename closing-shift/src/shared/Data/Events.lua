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
	-- Halloween only (Data/Seasons): a jack-o'-lantern that shouldn't be there; get close and it goes
	-- off (the lights cut for a moment) and leaves candy behind
	Pumpkin = { Weight = 1.5, TriggerDistance = 9, Candy = 3, MaxLifetime = 100 },
	-- a cooler starts leaking: a new spill every Every seconds (up to MaxSpills) until someone holds
	-- the shut-off valve for ValveHold seconds
	Leak = { Weight = 1.2, UsesSpills = true, Every = 10, MaxSpills = 4, ValveHold = 3 },
}

return Events

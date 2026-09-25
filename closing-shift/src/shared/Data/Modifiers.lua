--!strict
-- Modifiers change a night's numbers (for Overtime and special events later).
-- Each field multiplies or overrides the resolved rules (see Shared/Rules.lua):
--   SpillCountMult, ShiftLengthMult, EventGapMult, ManagerSpeedMult, WalkSpeedMult (multipliers)
--   PowerCuts = true (forces power cuts on)
local Modifiers = {
	Slippery = { Name = "Slippery Floors", Description = "More spills.", SpillCountMult = 1.5 },
	Understaffed = { Name = "Understaffed", Description = "Less time on the clock.", ShiftLengthMult = 0.8 },
	Restless = { Name = "Restless", Description = "Things go wrong more often.", EventGapMult = 0.6 },
	Overtime = { Name = "Overtime", Description = "The manager is in a hurry.", ManagerSpeedMult = 1.3 },
	Blackout = { Name = "Blackout", Description = "The power keeps cutting out.", PowerCuts = true },
}

return Modifiers

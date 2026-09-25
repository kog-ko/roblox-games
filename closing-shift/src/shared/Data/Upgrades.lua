--!strict
-- Permanent upgrades bought with paycheck cash at the break-room locker.
-- Each tier's Value is what the upgrade sets (a multiplier on the base stat).
local Upgrades = {
	MopSpeed = {
		Name = "Mop Speed",
		Description = "Clean spills faster.",
		Stat = "CleanTimeMult",
		Tiers = {
			{ Cost = 150, Value = 0.9 },
			{ Cost = 400, Value = 0.8 },
			{ Cost = 900, Value = 0.7 },
		},
	},
	FlashlightBattery = {
		Name = "Flashlight Battery",
		Description = "Your flashlight lasts longer.",
		Stat = "BatteryMult",
		Tiers = {
			{ Cost = 120, Value = 1.3 },
			{ Cost = 350, Value = 1.6 },
			{ Cost = 800, Value = 2.0 },
		},
	},
	Sneakers = {
		Name = "Squeaky Sneakers",
		Description = "Sprint for longer.",
		Stat = "StaminaMult",
		Tiers = {
			{ Cost = 120, Value = 1.3 },
			{ Cost = 350, Value = 1.6 },
			{ Cost = 800, Value = 2.0 },
		},
	},
}

return Upgrades

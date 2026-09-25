--!strict
-- Every badge, game pass and developer product (created in Creator Hub, on sale, managed pricing off).
-- Id = 0 means "not created yet": the game hides it.
--
-- Rules the code follows: no paid random rewards, every night is beatable for free, and purchase
-- prompts only appear in the shop, on the catch screen (Second Chance), on the YOU'RE FIRED screen
-- (Clock In Late) and once after your first completed night (Starter Pack).
local Monetization = {
	Badges = {
		FirstShift = 788401156254748,
		PerfectShift = 540161738111668,
		FoundTheNote = 1990124112404883,
	},

	-- Game passes (owned forever). Perks: VIP = 2x paycheck + gold name tag + VIP lounge;
	-- IndustrialMop = 25% faster cleaning + gold mop; BigFlashlight = wider beam + longer battery.
	GamePasses = {
		VIP = 1998812448, -- R$ 249
		IndustrialMop = 1998350469, -- R$ 149
		BigFlashlight = 1998770452, -- R$ 99
	},

	-- Developer products (bought each time).
	Products = {
		-- server-wide boosts (during a shift; everyone sees who bought it)
		LightsOn = 3714721090, -- R$ 49: all lights on for 60s and the Manager frozen
		HireJanitor = 3714721159, -- R$ 39: an NPC cleans 3 spills
		SpillStorm = 3714721262, -- R$ 25: 5 more spills (more paycheck for everyone)
		ManagerDayOff = 3714721292, -- R$ 99: no Manager for the rest of the night
		-- personal
		SecondChance = 3714721309, -- R$ 25: offered when caught; no respawn, no time lost
		ClockInLate = 3714721328, -- R$ 49: offered on YOU'RE FIRED; revive the night at 5:00 AM
		ExtraCoffee = 3714721493, -- R$ 15: 30s speed boost (banked if bought outside a shift)
		PaycheckSmall = 3714721524, -- R$ 49
		PaycheckMedium = 3714721555, -- R$ 149
		PaycheckLarge = 3714721585, -- R$ 399
		StarterPack = 3714721618, -- R$ 99: offered once, after your first completed night
		-- gifts: buy a pass for another player in the server
		GiftVIP = 3714721640, -- same price as VIP
		GiftIndustrialMop = 3714721670, -- same price as IndustrialMop
		GiftBigFlashlight = 3714721710, -- same price as BigFlashlight
	},

	-- What the products give. All in-game numbers, safe to tune.
	Rewards = {
		PaycheckSmall = 500,
		PaycheckMedium = 2000,
		PaycheckLarge = 6000,
		StarterCash = 1500,
		StarterDoublePayHours = 24, -- 2x paycheck for this long after buying the Starter Pack
		StarterOfferHours = 24, -- the Starter Pack can be bought for this long after it's first offered
		LightsOnSeconds = 60,
		JanitorSpills = 3,
		SpillStormSpills = 5,
		ServerBoostCooldown = 30, -- seconds between any two server-wide boosts
		SecondChanceWindow = 15, -- seconds after a catch that Second Chance can still be bought
		ClockInLateWindow = 10, -- seconds on the YOU'RE FIRED screen to buy Clock In Late
		BigFlashlightBeam = 1.5, -- beam width multiplier
		BigFlashlightBattery = 1.5, -- battery multiplier (stacks with the upgrade)
	},

	-- Shop listing: display names and descriptions for every product and pass.
	Catalog = {
		VIP = { Name = "VIP", Description = "2x paycheck, gold name tag, VIP lounge" },
		IndustrialMop = { Name = "INDUSTRIAL MOP", Description = "25% faster cleaning, gold mop" },
		BigFlashlight = { Name = "BIG FLASHLIGHT", Description = "Wider beam, longer battery" },
		LightsOn = { Name = "LIGHTS ON", Description = "All lights on for 60s, Manager frozen" },
		HireJanitor = { Name = "HIRE A JANITOR", Description = "An NPC cleans 3 spills" },
		SpillStorm = { Name = "SPILL STORM", Description = "5 more spills for everyone" },
		ManagerDayOff = { Name = "MANAGER DAY OFF", Description = "No Manager for the rest of the night" },
		ExtraCoffee = { Name = "EXTRA COFFEE", Description = "30s speed boost" },
		PaycheckSmall = { Name = "SMALL PAYCHECK", Description = "$500" },
		PaycheckMedium = { Name = "MEDIUM PAYCHECK", Description = "$2,000" },
		PaycheckLarge = { Name = "LARGE PAYCHECK", Description = "$6,000" },
		StarterPack = { Name = "STARTER PACK", Description = "$1,500 + 2x paycheck for 24 hours" },
	},
}

return Monetization

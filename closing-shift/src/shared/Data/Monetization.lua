--!strict
-- Every badge, game pass and developer product. Id = 0 means "not created yet": the game hides it.
-- Create each one in Creator Hub > your experience > Monetization (passes / developer products) or
-- Engagement (badges), set the price shown in the comment (a suggestion), then paste the ID here.
--
-- Rules the code follows: no paid random rewards, every night is beatable for free, and purchase
-- prompts only appear in the shop, on the catch screen (Second Chance), on the YOU'RE FIRED screen
-- (Clock In Late) and once after your first completed night (Starter Pack).
local Monetization = {
	Badges = {
		FirstShift = 0,
		PerfectShift = 0,
		FoundTheNote = 0,
	},

	-- Game passes (owned forever). Perks: VIP = 2x paycheck + gold name tag + VIP lounge;
	-- IndustrialMop = 25% faster cleaning + gold mop; BigFlashlight = wider beam + longer battery.
	GamePasses = {
		VIP = 0, -- suggested R$ 249
		IndustrialMop = 0, -- suggested R$ 149
		BigFlashlight = 0, -- suggested R$ 99
	},

	-- Developer products (bought each time).
	Products = {
		-- server-wide boosts (during a shift; everyone sees who bought it)
		LightsOn = 0, -- suggested R$ 49: all lights on for 60s and the Manager frozen
		HireJanitor = 0, -- suggested R$ 39: an NPC cleans 3 spills
		SpillStorm = 0, -- suggested R$ 25: 5 more spills (more paycheck for everyone)
		ManagerDayOff = 0, -- suggested R$ 99: no Manager for the rest of the night
		-- personal
		SecondChance = 0, -- suggested R$ 25: offered when caught; no respawn, no time lost
		ClockInLate = 0, -- suggested R$ 49: offered on YOU'RE FIRED; revive the night at 5:00 AM
		ExtraCoffee = 0, -- suggested R$ 15: 30s speed boost (banked if bought outside a shift)
		PaycheckSmall = 0, -- suggested R$ 49
		PaycheckMedium = 0, -- suggested R$ 149
		PaycheckLarge = 0, -- suggested R$ 399
		StarterPack = 0, -- suggested R$ 99: offered once, after your first completed night
		-- gifts: buy a pass for another player in the server
		GiftVIP = 0, -- same price as VIP
		GiftIndustrialMop = 0, -- same price as IndustrialMop
		GiftBigFlashlight = 0, -- same price as BigFlashlight
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

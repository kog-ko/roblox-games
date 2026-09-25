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

-- Sprint (client-side feel; the server sanity-checks speed later)
Config.Sprint = {
	Multiplier = 1.45, -- WalkSpeed x this while sprinting
	Stamina = 5, -- seconds of sprint from full
	RegenPerSecond = 0.7, -- stamina seconds regained per second
	RegenDelay = 0.8, -- pause after sprinting before regen starts
}

-- First person + mop viewmodel
Config.FirstPerson = {
	HandOffset = Vector3.new(0.95, -0.95, -1.2), -- where the hands hold the stick, in camera space
	HeadOffset = Vector3.new(0.2, -2.1, -4.2), -- where the mop head sits, in camera space
	Tint = Color3.fromRGB(205, 230, 205), -- viewmodel colour grade (GUIs skip ColorCorrection)
	Ambient = Color3.fromRGB(120, 130, 120), -- viewmodel lighting with the power on
	LightColor = Color3.fromRGB(170, 185, 165),
	SwayAmount = 0.08, -- how far the mop lags behind camera turns
	BobAmount = 0.06, -- walking bob (studs)
	ScrubAmount = 0.35, -- how far the head moves back and forth while mopping
	ScrubSpeed = 11, -- scrub strokes (radians/second)
}

-- Scoring / badges
Config.PerfectShiftTime = 5 * 60 -- "Perfect Shift" = cleaned under this many seconds
Config.LeaderboardSize = 10
Config.LeaderboardRefresh = 60
Config.AutosaveInterval = 120
Config.DataRetries = 3

-- PSX look. Every heavy effect has an on/off switch here.
Config.PSX = {
	FieldOfView = 70,
	CameraSnap = true, -- snap camera rotation to small steps for a low-framerate feel
	SnapDegrees = 0.6,
	HeadBob = true,
	BobWalk = 0.08, -- studs
	BobSprint = 0.16,
	Overlay = true, -- scanlines + pixel grid
	PixelGrid = true, -- faint vertical lines that, with the scanlines, read as big pixels
	Vignette = true,
	Flicker = true, -- slow screen brightness flicker
	-- Colour grade and fog (applied by the server's StoreBuilder.SetupLighting)
	Saturation = -0.55,
	Contrast = 0.4,
	Tint = Color3.fromRGB(200, 240, 225), -- green-cyan
	FogDensity = 0.58,
	FogHaze = 3,
}

-- Flashlight (F / touch). Battery drains while on and slowly recharges while off.
Config.Flashlight = {
	Brightness = 3,
	Range = 45,
	Angle = 50, -- degrees
	Battery = 45, -- seconds of light from full
	RechargePerSecond = 0.5, -- battery seconds regained per second while off
	MinToTurnOn = 3, -- a drained light won't switch back on until it has this much
}

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

--!strict
-- CLOSING SHIFT: global tunables live here; content lives in the Data tables below it
-- (Shared/Data: Nights, Events, Modifiers, Stores, Upgrades, Monetization).
-- This is in ReplicatedStorage because the client needs the timings and pass/product IDs.
-- There are no secrets in here, so that's fine.

local Data = script.Parent:WaitForChild("Data")

local Config = {}

-- Content tables
Config.Nights = require(Data:WaitForChild("Nights"))
Config.Events = require(Data:WaitForChild("Events"))
Config.Modifiers = require(Data:WaitForChild("Modifiers"))
Config.Stores = require(Data:WaitForChild("Stores"))
Config.Upgrades = require(Data:WaitForChild("Upgrades"))
Config.Monetization = require(Data:WaitForChild("Monetization"))
Config.DefaultNight = 1
Config.LikeGoal = 1000 -- shown after Night 3: "Like the game to unlock Nights 4-5 faster!"
Config.DefaultStore = "QuikStop"

-- Round flow (seconds). Shift length and spill count are per night (Data/Nights).
Config.IntermissionTime = 15
Config.ShiftStartHour = 2
Config.ShiftEndHour = 6
Config.PayoffTime = 12 -- back-room reveal before the results screen
Config.ResultsTime = 10
Config.LightsOutOnLoseTime = 2.5

-- Spills (the last spill of every shift always spawns in the back room)
Config.SpillMinRadius = 2.2
Config.SpillMaxRadius = 3.6
Config.CleanHoldTime = 1.6 -- ProximityPrompt hold duration (seconds)
Config.CleanDistance = 8 -- prompt activation distance (studs)
Config.CleanServerSlack = 3 -- extra studs the server tolerates for lag
Config.CleanTimeTolerance = 0.8 -- server accepts a hold this fraction of the expected length (ping)

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
Config.PerfectShiftFraction = 0.6 -- "Perfect Shift" = cleaned in under this fraction of the night's clock
Config.LeaderboardSize = 10
Config.LeaderboardRefresh = 60
Config.BoardCycle = 12 -- seconds the counter board shows each page (Employee of the Week / fastest night)
Config.WeeklyStoreName = "ClosingShift_WeeklySpills_v1" -- one OrderedDataStore per week (W<n> is added)
Config.TrophyRefresh = 1800 -- how often a server re-reads last week's top 3
Config.EarningsStoreName = "ClosingShift_Earnings_v1" -- lifetime cash earned on shifts (before pay multipliers)
Config.CareerStoreName = "ClosingShift_Career_v1" -- lifetime spills cleaned
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

-- Paycheck (cash). Win bonuses are per night (Data/Nights WinBonus).
Config.Pay = {
	PerSpill = 10, -- every spill you clean
	FinalSpill = 25, -- extra for the back-room spill
	FastFraction = 0.5, -- a win in under this fraction of the night's clock...
	FastBonus = 50, -- ...pays this bonus
	NoCatchBonus = 30, -- won a night that has the Manager without being caught
	CrewBonusPerFriend = 0.1, -- +10% paycheck for each Roblox friend in the server...
	CrewBonusMaxFriends = 3, -- ...up to this many
}

-- Career ranks, earned by total spills cleaned (ever). Shown on the name tag above your head.
Config.Ranks = {
	{ Name = "TRAINEE", Cleaned = 0 },
	{ Name = "STOCK CLERK", Cleaned = 25 },
	{ Name = "NIGHT CREW", Cleaned = 100 },
	{ Name = "NIGHT LEAD", Cleaned = 250 },
	{ Name = "SHIFT MANAGER", Cleaned = 600 },
	{ Name = "REGIONAL MANAGER", Cleaned = 1500 },
	{ Name = "THE ONE WHO STAYED", Cleaned = 4000 },
}

-- Daily Shift Bonus: paid on your first shift each (UTC) day; grows on consecutive days.
Config.Daily = {
	PerStreakDay = 25, -- bonus = streak x this
	MaxStreak = 7, -- the streak (and bonus) stops growing here
}

-- The Night Manager (speed is per night in Data/Nights)
Config.Manager = {
	CatchDistance = 3.5, -- studs (flat) that count as caught
	ViewDistance = 110, -- beyond this he's lost in the fog
	ViewConeDegrees = 48, -- half-angle of the view cone that counts as "on screen"
	ReportInterval = 0.1, -- how often each client sends its camera view
	ReportMaxOffset = 6, -- a report further than this from the player's head is ignored
	ReportMinInterval = 0.05, -- reports faster than this (seconds) are dropped
	ReportMaxAge = 0.6, -- seconds before a player's last report stops counting
	RepathInterval = 0.8, -- seconds between path recomputes
	FreezeTime = 3, -- a caught player is frozen this long, then sent back to the counter
	TimePenalty = 30, -- seconds taken off the shift clock per catch
	CooldownAfterCatch = 4, -- he waits this long in the back room after a catch
	Spawn = Vector3.new(44, 0, -7), -- back room, by the door
	SpeedPerExtraPlayer = 0.15, -- +15% speed for each player beyond the first (co-op always has a watcher)
	SoundRange = 25, -- studs at which his footsteps and hum fade out
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

-- Sounds. Sound effects are from Pro Sound Effects and APM (licensed for every Roblox experience)
-- plus a few free Creator Store uploads; all were checked to load. Swap any ID here.
local function id(n: number): string
	return "rbxassetid://" .. n
end
Config.Sounds = {
	Squeak = id(9113598131), -- heavy floor scrubbing, looped while mopping
	Splash = id(9125703162), -- puddle splash when a spill is cleaned
	Splash2 = id(9125702439), -- alternate splash (picked at random)
	Kaching = id(134810204798705), -- cash register: your personal reward for a clean
	Chime = id(9125935023), -- shop door bell (the DoorChime event)
	Buzz = id(9118149104), -- relay clunk when the lights cut out
	FlashClick = id(9114480271), -- flashlight switch
	Hum = id(4227579935), -- fluorescent tube hum (loops)
	Fridge = id(171186876), -- cooler compressor hum (loops)
	Ambient = id(1842083079), -- low cinematic drone under everything
	StingPayoff = id(9047014318), -- back-room reveal
	StingFired = id(1846887425), -- YOU'RE FIRED
	UIClick = id(87437544236708), -- button presses
	ManagerSteps = id(117471457171581), -- the Night Manager walking (only while he moves)
	ManagerPresence = id(9112797020), -- low hum around the Night Manager
}
Config.ScrubLoop = NumberRange.new(1, 3) -- seconds of the scrub clip looped while mopping
Config.PitchVariation = 0.08 -- every one-shot plays at 1 +/- this speed so repeats don't sound robotic
Config.Volumes = { Ambient = 0.35, Hum = 0.25, Fridge = 0.3, UI = 0.4, Sting = 0.8 }

-- Old names kept for existing code; the IDs themselves live in Data/Monetization.
Config.Badges = Config.Monetization.Badges
Config.GamePasses = Config.Monetization.GamePasses
Config.DevProducts = Config.Monetization.Products

-- DataStore names (bump the version suffix to wipe test data)
Config.DataStoreName = "ClosingShift_Players_v1"
Config.LeaderboardStoreName = "ClosingShift_BestTimes_v1"


-- Places. The lobby is the experience's start place; queues teleport each crew to its own private
-- server of the shift place, and the Leave button brings them back.
Config.Places = {
	Lobby = 104809971812455,
	Shift = 93047688567585,
}

-- Lobby queues: a pad per night plus Quick Play (the best night everyone on it has unlocked).
Config.Queue = {
	MaxCrew = 4, -- players per shift server
	Countdown = 12, -- seconds after the first player steps on a pad
	FullCountdown = 4, -- the countdown drops to this once the pad is full
	RetryDelay = 5, -- after a failed teleport, players can queue again after this
}
-- Shift servers reached from a queue start once the whole crew has arrived (or after this long).
Config.ArrivalWait = 20

return Config

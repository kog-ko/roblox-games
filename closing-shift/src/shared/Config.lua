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
Config.Cosmetics = require(Data:WaitForChild("Cosmetics"))
Config.Challenges = require(Data:WaitForChild("Challenges"))
Config.Achievements = require(Data:WaitForChild("Achievements"))
Config.Seasons = require(Data:WaitForChild("Seasons"))
Config.Pass = require(Data:WaitForChild("Pass"))
Config.DefaultNight = 1
Config.LikeGoal = 1000 -- shown after Night 3: "Like the game to unlock Nights 4-5 faster!"
Config.DefaultStore = "QuikStop"

-- Round flow (seconds). Shift length and spill count are per night (Data/Nights).
Config.IntermissionTime = 15
Config.PostShiftWait = 60 -- after a shift: seconds to press NEXT SHIFT before the crew goes back to the lobby
-- Store zones and the crew size that opens each (see Data/Nights for how spills and time scale)
Config.Zones = { Floor = 1, Stockroom = 2, Freezer = 3 }
Config.BigSpillScale = 1.6 -- big spills are this much bigger
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
	FieldOfView = 80, -- wide, like a bodycam lens
	CameraSnap = true, -- snap camera rotation to small steps for a low-framerate feel
	SnapDegrees = 0.6,
	HeadBob = true,
	BobWalk = 0.08, -- studs
	BobSprint = 0.16,
	-- bodycam: the camera rolls into strafes and turns, and lags a touch behind the head
	Tilt = true,
	TiltStrafe = 2.6, -- degrees of roll at full sideways speed
	TiltTurn = 0.018, -- degrees of roll per degree/second of turning
	TiltMax = 5,
	BodycamOsd = true, -- REC dot, date and time stamp, unit number
	Grain = true, -- moving film grain
	Overlay = true, -- scanlines + pixel grid
	PixelGrid = true, -- faint vertical lines that, with the scanlines, read as big pixels
	Vignette = true,
	Flicker = true, -- slow screen brightness flicker
	-- Colour grade and fog (applied by the server's StoreBuilder.SetupLighting)
	Saturation = -0.55,
	Contrast = 0.4,
	Tint = Color3.fromRGB(200, 240, 225), -- green-cyan
	FogDensity = 0.46,
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
	PerStreakDay = 25, -- bonus = streak x this...
	MaxStreak = 7, -- ...up to this many days (the streak itself keeps counting; see Achievements.Streaks)
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
	Spawn = Vector3.new(44, 0, -7), -- back room, by the door (StoreBuilder coordinates: pass through Layout.Map)
	SpeedPerExtraPlayer = 0.15, -- +15% speed for each player beyond the first (co-op always has a watcher)
	SoundRange = 45, -- studs at which his footsteps and hum fade out
	-- The grab: the camera turns to his face, then a skill check (press when the needle is in the
	-- zone, Hits times in a row). Escape = no catch; fail = the usual catch, nothing extra.
	Grab = {
		Intro = 0.9, -- seconds of face-to-face before the check starts
		Window = 3.4, -- seconds to land every hit
		Hits = 2,
		Zone = 0.22, -- zone width (fraction of the bar)
		ZoneShrink = 0.035, -- narrower after each escape this shift...
		MinZone = 0.09,
		Period = 1.0, -- seconds for the needle to cross the bar
		PeriodShrink = 0.12, -- ...and a faster needle
		MinPeriod = 0.5,
		EscapeStun = 4, -- seconds he stands still after you break free
	},
	-- Tension as he gets close (client): heartbeat, bodycam interference, a cue when he's behind you.
	Tension = {
		Range = 42, -- studs at which it starts
		BehindRange = 16, -- within this and behind you: the "behind you" cue
	},
}

-- Overtime (the endless mode, Data/Nights "Overtime"). Every RampEvery seconds is a new "hour":
-- spills come faster and the Manager speeds up. The shift ends when the mess stays at the cap for
-- Grace seconds.
Config.Overtime = {
	SpawnEvery = 9, -- seconds between new spills at the start (one player)...
	SpawnDecay = 0.85, -- ...times this every hour...
	MinEvery = 3, -- ...but never faster than this
	CrewSpeedUp = 0.35, -- spills come this much faster per extra player
	RampEvery = 90, -- seconds per "hour"
	ManagerSpeedUp = 0.12, -- +12% Manager speed per hour
	MessCap = 18, -- spills on the floor at once that end the shift...
	MessPerExtra = 4, -- ...plus this many per extra player
	Grace = 10, -- seconds at the cap before it's over
	CatchMess = 3, -- getting caught tips this many more spills out
	PayPerMinute = 15, -- paycheck line for each full minute survived
	WeeklyStoreName = "ClosingShift_Overtime_v1", -- weekly "longest overtime" board (W<n> is added)
}

-- The rare Late Customer (LateCustomer.lua): some nights someone walks in after closing.
Config.LateCustomer = {
	Chance = 0.12, -- per shift
	MinNight = 2,
	Delay = { Min = 50, Max = 200 }, -- seconds into the shift it walks in
	StareTime = 3, -- seconds of being looked at (added up across the crew) until it's gone
	Tip = 75, -- cash for everyone who looked at it when it goes
	Speed = 6,
	ReachDistance = 3,
	JamTime = 12, -- seconds your flashlight is dead after it reaches you
	MessEvery = 14, -- it tracks in a spill this often...
	MaxMess = 4, -- ...up to this many
	MaxTime = 120, -- then it leaves
}

-- Flashlight (F / touch). Battery drains while on and slowly recharges while off.
Config.Flashlight = {
	Brightness = 4, -- the round beam
	Range = 55,
	Angle = 44, -- degrees
	HotspotBrightness = 3.5, -- the brighter centre of the beam
	HotspotAngle = 16,
	Lag = 14, -- how quickly the beam catches up with where you look (higher = stiffer)
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
	Heartbeat = id(9043365842), -- heartbeat loop as the Manager closes in (APM)
	GrabScream = id(9041752524), -- his scream when he grabs you (APM)
	JumpScare = id(9040287396), -- the hit under the scream (APM)
	Whisper = id(9114228524), -- a whisper in your ear when he's behind you
	Escape = id(9120769331), -- breaking free of a grab
	-- lobby
	CityNight = id(9112759731), -- distant traffic (loops)
	Crickets = id(9112764573), -- (loops)
	Fountain = id(9120557577), -- the mop-bucket fountain (loops, 3D)
	NeonBuzz = id(9117072474), -- neon signs (loops, 3D)
	Checkpoint = id(1839997929), -- obby checkpoint (APM)
	ObbyFinish = id(1846011760), -- obby cleared (APM, first few seconds)
	Bounce = id(1846544949), -- trampolines (APM)
	ObbyFall = id(9119481927), -- into the mop water
	QueueBeep = id(9117060347), -- queue countdown ticks
	-- events
	CandyPickup = id(1839997929), -- picking up event candy (APM)
	PumpkinSting = id(9047014546), -- the jack-o'-lantern (APM Beautiful Horror stinger 2)
	PayphoneRing = id(9117304268), -- the payphone out front (old rattly bell, loops)
	PhonePickUp = id(9117145638), -- ...and someone picks it up
}

-- Music. All licensed for Roblox experiences (DistroKid catalogue). M toggles music on and off.
Config.Music = {
	Lobby = { id(140515672182827), id(70551940079407), id(138693920798127), id(94615661666814) }, -- night-drive lo-fi
	Break = id(139799942555122), -- the store radio between shifts (played muffled)
	ShiftCalm = id(117508801974613), -- "Feeling Uneasy": under every shift
	ShiftDanger = id(127708788779804), -- "Room Pulse": swells as the Manager closes in
	Volume = { Lobby = 0.28, Break = 0.3, ShiftCalm = 0.22, ShiftDanger = 0.5 },
}
Config.ScrubLoop = NumberRange.new(1, 3) -- seconds of the scrub clip looped while mopping
Config.PitchVariation = 0.08 -- every one-shot plays at 1 +/- this speed so repeats don't sound robotic
Config.Volumes = { Ambient = 0.35, Hum = 0.25, Fridge = 0.3, UI = 0.4, Sting = 0.8 }

-- The gear menu (both places). All on by default; each is saved per player (PlayerPrefs).
Config.Settings = {
	{ Key = "Shake", Name = "CAMERA SHAKE & TILT" },
	{ Key = "Bob", Name = "HEAD BOB" },
	{ Key = "ScreenFx", Name = "SCREEN EFFECTS (SCANLINES, GRAIN, STATIC)" },
	{ Key = "Music", Name = "MUSIC" },
}

-- First-time tips (client Tips.lua): each shown once, the first time its moment happens.
Config.Tips = {
	{ Id = "Manager", Text = "THE NIGHT MANAGER IS IN. HE ONLY MOVES WHEN NOBODY IS LOOKING. KEEP HIM ON SCREEN." },
	{ Id = "Grab", Text = "HE'S GOT YOU. PRESS WHEN THE NEEDLE IS IN THE GREEN, TWICE. BREAKING FREE COSTS NOTHING." },
	{ Id = "LateCustomer", Text = "SOMEONE CAME IN. STARE IT DOWN: KEEP IT ON SCREEN FOR A FEW SECONDS AND IT'S GONE." },
	{ Id = "Dark", Text = "THE POWER IS OUT ALL NIGHT. SPILLS ONLY SHOW UP IN YOUR FLASHLIGHT (F)." },
	{ Id = "Overtime", Text = "OVERTIME: KEEP THE MESS UNDER THE LIMIT. IT ONLY GETS FASTER." },
	{ Id = "Leak", Text = "A COOLER IS LEAKING. HOLD E ON THE RED VALVE TO SHUT IT OFF." },
	{ Id = "BigSpill", Text = "BIG SPILL: IT TAKES TWO CLEANS. TWO OF YOU CAN SPLIT IT." },
	{ Id = "Candy", Text = "EVENT CANDY! WALK INTO IT, THEN SPEND IT IN THE LOBBY WARDROBE." },
}

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
-- Lobby obbies: display name and the cash each pays once per UTC day. Clearing all of them
-- unlocks the ObbyTrail cosmetic.
Config.Obbies = {
	Roof = { Name = "THE ROOF RUN", Reward = 150 },
	Spill = { Name = "THE SPILL CLEANUP", Reward = 200 },
	Sign = { Name = "THE SIGN CLIMB", Reward = 250 },
}
Config.ObbyTrail = "TrailParkour"

-- Shift servers reached from a queue start once the whole crew has arrived (or after this long).
Config.ArrivalWait = 20

return Config

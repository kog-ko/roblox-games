--!strict
-- Achievements (Data/Achievements.lua) and stat counting, in both places.
-- Achievements.Add(player, stat, n) bumps a profile stat and checks for anything newly earned;
-- Achievements.Check(player) just checks (after the stats changed some other way). Earning one pays
-- its reward once, is announced to you, and is published as the Achievements attribute
-- ("id,id,...") for the lobby's panel, with progress toward the rest in AchProgress (JSON stat -> value).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)

local Achievements = {}
-- Called for each achievement earned (the Shift Pass gives XP; set in init, which avoids a require loop).
Achievements.OnEarned = nil :: ((Player) -> ())?
local DATA = Config.Achievements

-- The value a goal is measured against. Most are plain stats; a few are worked out.
local function valueOf(p: any, stat: string): number
	local stats = p.Stats :: any
	if stat == "ObbyClears" then
		local n = 0
		for key in Config.Obbies do
			n += (stats["ObbyClears_" .. key] or 0) :: number
		end
		return n
	elseif stat == "NightsCleared" then
		local n = 0
		for _ in p.BestByNight do
			n += 1
		end
		return n
	end
	return (stats[stat] or 0) :: number
end

local function publish(player: Player, p: any)
	local ids = {}
	for id in p.Achievements do
		table.insert(ids, id)
	end
	player:SetAttribute("Achievements", table.concat(ids, ","))
	local progress = {}
	for _, a in DATA.List do
		progress[a.Stat] = valueOf(p, a.Stat)
	end
	player:SetAttribute("AchProgress", HttpService:JSONEncode(progress))
end

function Achievements.Check(player: Player)
	local p = DataService.Get(player)
	if not p or p.LoadFailed then
		return
	end
	local banner = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Banner") :: RemoteEvent?
	local earned = {}
	for _, a in DATA.List do
		if not p.Achievements[a.Id] and valueOf(p, a.Stat) >= a.Goal then
			table.insert(earned, a)
		end
	end
	if #earned == 0 then
		publish(player, p)
		return
	end
	DataService.Update(player, function(prof)
		for _, a in earned do
			prof.Achievements[a.Id] = os.time()
		end
	end)
	for i, a in earned do
		Economy.AddCash(player, a.Reward, "Achievement:" .. a.Id)
		if Achievements.OnEarned then
			Achievements.OnEarned(player)
		end
		if banner then
			task.delay((i - 1) * 3, function()
				banner:FireClient(player, string.format("ACHIEVEMENT: %s  +$%d", a.Name, a.Reward), "Achievement")
			end)
		end
	end
	publish(player, p)
end

function Achievements.Add(player: Player, stat: string, n: number?)
	if not DataService.Get(player) then
		return
	end
	DataService.Update(player, function(prof)
		local stats = prof.Stats :: any
		stats[stat] = ((stats[stat] or 0) :: number) + (n or 1)
	end)
	Achievements.Check(player)
end

function Achievements.Init()
	DataService.Loaded.Event:Connect(function(player: Player)
		local p = DataService.Get(player)
		if p then
			publish(player, p)
			Achievements.Check(player) -- anything earned before achievements existed
		end
	end)
end

return Achievements

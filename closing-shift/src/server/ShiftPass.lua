--!strict
-- The Shift Pass (Data/Pass), in both places. ShiftPass.AddXp is called for things you do (spills,
-- nights, Overtime minutes, jobs, obbies, achievements). Every Config.Pass.XpPerTier XP is a tier;
-- reaching one hands out its free reward at once, and its premium reward too if you own the
-- ShiftPass game pass (bought later? everything you've reached is handed out then).
-- Progress lives in the profile's Pass { Id, Xp, Free, Premium } (Free / Premium = the highest tier
-- already paid out on each track); a new season (a new Id) starts from zero.
-- Published: PassXp, PassTier, PassFree, PassPremium (tiers paid), for the lobby's PASS panel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Season = require(ReplicatedStorage.Shared.Season)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Cosmetics = require(script.Parent.Cosmetics)

local ShiftPass = {}
local P = Config.Pass

function ShiftPass.Current(): any?
	local now = os.time()
	for _, s in P.Seasons do
		if now >= s.Start and now < s.End then
			return s
		end
	end
	return nil
end

local function banner(player: Player, text: string)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local b = remotes and remotes:FindFirstChild("Banner") :: RemoteEvent?
	if b then
		b:FireClient(player, text, "Pass")
	end
end

local function publish(player: Player, p: any, s: any?)
	local tiers = if s then #s.Tiers else 0
	player:SetAttribute("PassSeason", if s then s.Id else nil)
	player:SetAttribute("PassXp", p.Pass.Xp)
	player:SetAttribute("PassTier", math.min(tiers, p.Pass.Xp // P.XpPerTier))
	player:SetAttribute("PassFree", p.Pass.Free)
	player:SetAttribute("PassPremium", p.Pass.Premium)
end

-- Pays one reward. Returns a short description ("$300", "MANAGER'S SUIT", ...).
local function give(player: Player, reward: any): string
	local parts = {}
	if reward.Cash then
		Economy.AddCash(player, reward.Cash, "ShiftPass")
		table.insert(parts, "$" .. reward.Cash)
	end
	local ev = Season.Current()
	if reward.Candy and ev then
		DataService.Update(player, function(p)
			p.Candy += reward.Candy
		end)
		table.insert(parts, reward.Candy .. " " .. ev.Currency)
	end
	if reward.Cosmetic then
		DataService.Update(player, function(p)
			p.Cosmetics.Owned[reward.Cosmetic] = true
		end)
		local item = Cosmetics.Item(reward.Cosmetic)
		table.insert(parts, if item then item.Name else reward.Cosmetic)
	end
	return table.concat(parts, " + ")
end

-- Hands out everything reached and not yet paid (free always, premium if owned).
local function catchUp(player: Player)
	local s = ShiftPass.Current()
	local prof = DataService.Get(player)
	if not s or not prof or prof.LoadFailed then
		return
	end
	local tier = math.min(#s.Tiers, prof.Pass.Xp // P.XpPerTier)
	local premium = player:GetAttribute("ShiftPass") == true
	local got = {}
	while prof.Pass.Free < tier do
		local t = prof.Pass.Free + 1
		DataService.Update(player, function(p)
			p.Pass.Free = t
		end)
		local r = s.Tiers[t].Free
		if r then
			table.insert(got, give(player, r))
		end
	end
	if premium then
		while prof.Pass.Premium < tier do
			local t = prof.Pass.Premium + 1
			DataService.Update(player, function(p)
				p.Pass.Premium = t
			end)
			local r = s.Tiers[t].Premium
			if r then
				table.insert(got, give(player, r))
			end
		end
	end
	if #got > 0 then
		Cosmetics.Apply(player)
		banner(player, string.format("SHIFT PASS TIER %d!  %s", tier, table.concat(got, ", "):sub(1, 90)))
	end
	publish(player, prof, s)
end

function ShiftPass.AddXp(player: Player, amount: number)
	local s = ShiftPass.Current()
	local prof = DataService.Get(player)
	if not s or not prof or prof.LoadFailed or amount <= 0 then
		return
	end
	local before = prof.Pass.Xp // P.XpPerTier
	DataService.Update(player, function(p)
		p.Pass.Xp += math.floor(amount)
	end)
	if prof.Pass.Xp // P.XpPerTier > before then
		catchUp(player)
	else
		publish(player, prof, s)
	end
end

-- Starts a new season's progress when the season changed since the player last played.
local function roll(player: Player)
	local s = ShiftPass.Current()
	local prof = DataService.Get(player)
	if not prof then
		return
	end
	if s and prof.Pass.Id ~= s.Id then
		DataService.Update(player, function(p)
			p.Pass = { Id = s.Id, Xp = 0, Free = 0, Premium = 0 }
		end)
	end
	catchUp(player)
	publish(player, prof, s)
end

function ShiftPass.Init()
	DataService.Loaded.Event:Connect(roll)
	-- premium bought (or its ownership check finished after the profile loaded): pay what's reached
	game:GetService("Players").PlayerAdded:Connect(function(player)
		player:GetAttributeChangedSignal("ShiftPass"):Connect(function()
			catchUp(player)
		end)
	end)
	for _, player in game:GetService("Players"):GetPlayers() do
		player:GetAttributeChangedSignal("ShiftPass"):Connect(function()
			catchUp(player)
		end)
	end
end

return ShiftPass

--!strict
-- One versioned profile per player (cash, unlocks, per-night bests, stats, upgrades, coffees,
-- daily streak). Saved with UpdateAsync, merged with what's already stored so a stale server can
-- never roll progress back. Every DataStore call is pcall'd and retried. Autosaves every
-- Config.AutosaveInterval, on leave and on shutdown. If Studio has no API access, saving is
-- switched off for the session (one warning) so playtests stay quiet.
--
-- Older saves (version 1: Best, TotalCleaned, CoffeeCredits, Unlocked) are migrated on load.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local VERSION = 2

export type Profile = {
	Version: number,
	Cash: number,
	Unlocked: number,
	BestByNight: { [string]: number }, -- night number as a string (DataStore-safe keys) -> seconds
	Stats: { TotalCleaned: number, ShiftsWorked: number, ShiftsWon: number, Catches: number, LegacyBest: number? },
	Upgrades: { [string]: number }, -- upgrade id -> tier bought (0 = none)
	CoffeeCredits: number,
	Daily: { LastDay: number, Streak: number },
	Receipts: { [string]: number }, -- processed purchase ids -> os.time() (idempotent grants)
	GiftedPasses: { [string]: boolean }, -- passes received as gifts
	Starter: { OfferUntil: number, Bought: boolean }, -- Starter Pack offer window (0 = never offered)
	DoublePayUntil: number, -- os.time() when a 2x paycheck boost ends
	LoadFailed: boolean?,
}

local MAX_RECEIPTS = 100

local DataService = {}
-- Called after a player's profile is loaded (other services apply upgrades, passes, etc.).
DataService.Loaded = Instance.new("BindableEvent")
local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil
local disabled = false

local function disable(err: any)
	if not disabled then
		disabled = true
		warn("[DataService] saving is off this session:", err,
			"(publish the place and enable Game Settings > Security > Studio Access to API Services)")
	end
end

local function isApiBlocked(err: any): boolean
	local msg = tostring(err)
	return msg:find("StudioAccessToApisNotAllowed") ~= nil or msg:find("Studio access to APIs") ~= nil
		or msg:find("publish") ~= nil or msg:find("403") ~= nil
end

-- Runs fn with pcall, retrying with backoff. Returns ok, result.
local function retry(label: string, fn: () -> any): (boolean, any)
	if disabled then
		return false, "disabled"
	end
	local lastErr
	for attempt = 1, Config.DataRetries do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		lastErr = res
		if isApiBlocked(res) then
			disable(res)
			return false, res
		end
		warn(string.format("[DataService] %s failed (try %d/%d): %s", label, attempt, Config.DataRetries, tostring(res)))
		task.wait(2 ^ attempt)
	end
	return false, lastErr
end

local ok, res = pcall(DataStoreService.GetDataStore, DataStoreService, Config.DataStoreName)
if ok then
	store = res
else
	disable(res)
end

local function blank(): Profile
	return {
		Version = VERSION,
		Cash = 0,
		Unlocked = 1,
		BestByNight = {},
		Stats = { TotalCleaned = 0, ShiftsWorked = 0, ShiftsWon = 0, Catches = 0 },
		Upgrades = {},
		CoffeeCredits = 0,
		Daily = { LastDay = 0, Streak = 0 },
		Receipts = {},
		GiftedPasses = {},
		Starter = { OfferUntil = 0, Bought = false },
		DoublePayUntil = 0,
	}
end

-- Keeps only the newest receipts so the profile can't grow without limit.
local function trimReceipts(r: { [string]: number })
	local list = {}
	for id, t in r do
		table.insert(list, { id = id, t = t })
	end
	if #list <= MAX_RECEIPTS then
		return
	end
	table.sort(list, function(a, b)
		return a.t > b.t
	end)
	for i = MAX_RECEIPTS + 1, #list do
		r[list[i].id] = nil
	end
end

-- Turns whatever is stored (any version) into a current profile.
local function fromStored(data: any): Profile
	local p = blank()
	if type(data) ~= "table" then
		return p
	end
	if (data.Version or 1) < 2 then
		-- version 1: one best time for the single old shift
		p.Stats.TotalCleaned = tonumber(data.TotalCleaned) or 0
		p.Stats.LegacyBest = tonumber(data.Best)
		p.CoffeeCredits = tonumber(data.CoffeeCredits) or 0
		p.Unlocked = math.max(1, tonumber(data.Unlocked) or 1)
		return p
	end
	p.Cash = tonumber(data.Cash) or 0
	p.Unlocked = math.max(1, tonumber(data.Unlocked) or 1)
	p.CoffeeCredits = tonumber(data.CoffeeCredits) or 0
	if type(data.BestByNight) == "table" then
		for k, v in data.BestByNight do
			if type(v) == "number" then
				p.BestByNight[tostring(k)] = v
			end
		end
	end
	if type(data.Stats) == "table" then
		for k, v in data.Stats do
			if type(v) == "number" then
				(p.Stats :: any)[k] = v
			end
		end
	end
	if type(data.Upgrades) == "table" then
		for k, v in data.Upgrades do
			if type(v) == "number" then
				p.Upgrades[k] = v
			end
		end
	end
	if type(data.Daily) == "table" then
		p.Daily.LastDay = tonumber(data.Daily.LastDay) or 0
		p.Daily.Streak = tonumber(data.Daily.Streak) or 0
	end
	if type(data.Receipts) == "table" then
		for k, v in data.Receipts do
			if type(v) == "number" then
				p.Receipts[tostring(k)] = v
			end
		end
	end
	if type(data.GiftedPasses) == "table" then
		for k, v in data.GiftedPasses do
			if v == true then
				p.GiftedPasses[tostring(k)] = true
			end
		end
	end
	if type(data.Starter) == "table" then
		p.Starter.OfferUntil = tonumber(data.Starter.OfferUntil) or 0
		p.Starter.Bought = data.Starter.Bought == true
	end
	p.DoublePayUntil = tonumber(data.DoublePayUntil) or 0
	return p
end

-- Mirrors what the client needs onto the player as attributes.
local function publish(player: Player, p: Profile)
	player:SetAttribute("Cash", p.Cash)
	player:SetAttribute("Unlocked", p.Unlocked)
	player:SetAttribute("TotalCleaned", p.Stats.TotalCleaned)
	player:SetAttribute("CoffeeCredits", p.CoffeeCredits)
	player:SetAttribute("DailyStreak", p.Daily.Streak)
	player:SetAttribute("DoublePayUntil", if p.DoublePayUntil > 0 then p.DoublePayUntil else nil)
	player:SetAttribute("StarterOfferUntil", if p.Starter.OfferUntil > 0 and not p.Starter.Bought then p.Starter.OfferUntil else nil)
	local night = game:GetService("ReplicatedStorage"):GetAttribute("Night") or 1
	player:SetAttribute("Best", p.BestByNight[tostring(night)])
	for id in Config.Upgrades do
		player:SetAttribute("Upgrade_" .. id, p.Upgrades[id] or 0)
	end
end

function DataService.Load(player: Player)
	local profile = blank()
	if store and not disabled then
		local s = store :: DataStore
		local loaded, data = retry("load " .. player.UserId, function()
			return s:GetAsync(tostring(player.UserId))
		end)
		if loaded then
			profile = fromStored(data)
		elseif not disabled then
			profile.LoadFailed = true -- don't overwrite real data with blanks
		end
	end
	if player.Parent then
		profiles[player] = profile
		publish(player, profile)
		DataService.Loaded:Fire(player, profile)
	end
end

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

function DataService.Update(player: Player, fn: (Profile) -> ())
	local p = profiles[player]
	if p then
		fn(p)
		publish(player, p)
	end
end

-- Re-publishes attributes that depend on the selected night (the per-night best).
function DataService.RefreshAll()
	for player, p in profiles do
		publish(player, p)
	end
end

function DataService.Save(player: Player): boolean
	local p = profiles[player]
	if not p or p.LoadFailed or not store or disabled then
		return false
	end
	local s = store :: DataStore
	local saved = retry("save " .. player.UserId, function()
		s:UpdateAsync(tostring(player.UserId), function(stored)
			local old = fromStored(stored)
			local out = blank()
			-- this server's session is the authority for spendable values
			out.Cash = p.Cash
			out.CoffeeCredits = p.CoffeeCredits
			out.Daily = { LastDay = p.Daily.LastDay, Streak = p.Daily.Streak }
			-- progress only ever goes forward
			out.Unlocked = math.max(p.Unlocked, old.Unlocked)
			for k, v in old.BestByNight do
				out.BestByNight[k] = v
			end
			for k, v in p.BestByNight do
				out.BestByNight[k] = math.min(v, out.BestByNight[k] or math.huge)
			end
			for k, v in p.Stats :: any do
				if type(v) == "number" then
					(out.Stats :: any)[k] = math.max(v, ((old.Stats :: any)[k] or 0) :: number)
				end
			end
			for k, v in p.Upgrades do
				out.Upgrades[k] = math.max(v, old.Upgrades[k] or 0)
			end
			-- purchases and gifts are never lost
			for k, v in old.Receipts do
				out.Receipts[k] = v
			end
			for k, v in p.Receipts do
				out.Receipts[k] = v
			end
			trimReceipts(out.Receipts)
			for k in old.GiftedPasses do
				out.GiftedPasses[k] = true
			end
			for k in p.GiftedPasses do
				out.GiftedPasses[k] = true
			end
			out.Starter = {
				OfferUntil = math.max(p.Starter.OfferUntil, old.Starter.OfferUntil),
				Bought = p.Starter.Bought or old.Starter.Bought,
			}
			out.DoublePayUntil = math.max(p.DoublePayUntil, old.DoublePayUntil)
			return out
		end)
	end)
	return saved
end

-- True when purchases and progress are really being saved. In Studio without API access this is
-- false; Monetization then grants test purchases without the idempotency write.
function DataService.IsSaving(): boolean
	return store ~= nil and not disabled
end

-- Applies fn to a player's stored profile when they aren't in this server (gifts to someone who
-- left before the purchase finished). Returns true if the write succeeded.
function DataService.GrantOffline(userId: number, fn: (Profile) -> ()): boolean
	if not store or disabled then
		return false
	end
	local s = store :: DataStore
	local ok = retry("grant " .. userId, function()
		s:UpdateAsync(tostring(userId), function(stored)
			local p = fromStored(stored)
			fn(p)
			trimReceipts(p.Receipts)
			return p
		end)
	end)
	return ok
end

function DataService.Init()
	Players.PlayerAdded:Connect(DataService.Load)
	for _, pl in Players:GetPlayers() do
		task.spawn(DataService.Load, pl)
	end
	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player)
				pending -= 1
			end)
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in profiles do
				task.spawn(DataService.Save, player)
			end
		end
	end)
	game:GetService("ReplicatedStorage"):GetAttributeChangedSignal("Night"):Connect(DataService.RefreshAll)
end

-- For tests: what a stored value of any version loads as.
DataService._fromStored = fromStored

return DataService

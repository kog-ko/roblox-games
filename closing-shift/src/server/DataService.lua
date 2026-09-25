--!strict
-- Saves best clean time, total spills cleaned, banked coffees and the highest night unlocked per player.
-- Every DataStore call is pcall'd and retried. If Studio has no API access, saving is
-- switched off for the session (one warning) so playtests stay quiet.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type Profile = { Best: number?, TotalCleaned: number, CoffeeCredits: number, Unlocked: number, LoadFailed: boolean? }

local DataService = {}
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

local function publish(player: Player, p: Profile)
	player:SetAttribute("Best", p.Best)
	player:SetAttribute("TotalCleaned", p.TotalCleaned)
	player:SetAttribute("CoffeeCredits", p.CoffeeCredits)
	player:SetAttribute("Unlocked", p.Unlocked)
end

function DataService.Load(player: Player)
	local profile: Profile = { Best = nil, TotalCleaned = 0, CoffeeCredits = 0, Unlocked = 1 }
	if store and not disabled then
		local s = store :: DataStore
		local loaded, data = retry("load " .. player.UserId, function()
			return s:GetAsync(tostring(player.UserId))
		end)
		if loaded and type(data) == "table" then
			profile.Best = data.Best
			profile.TotalCleaned = data.TotalCleaned or 0
			profile.CoffeeCredits = data.CoffeeCredits or 0
			profile.Unlocked = math.max(1, data.Unlocked or 1)
		elseif not loaded and not disabled then
			profile.LoadFailed = true -- don't overwrite real data with blanks
		end
	end
	if player.Parent then
		profiles[player] = profile
		publish(player, profile)
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

function DataService.Save(player: Player): boolean
	local p = profiles[player]
	if not p or p.LoadFailed or not store or disabled then
		return false
	end
	local s = store :: DataStore
	local saved = retry("save " .. player.UserId, function()
		s:UpdateAsync(tostring(player.UserId), function(old)
			old = if type(old) == "table" then old else {}
			local best = p.Best
			if type(old.Best) == "number" and (best == nil or old.Best < best) then
				best = old.Best
			end
			return {
				Best = best,
				TotalCleaned = math.max(p.TotalCleaned, old.TotalCleaned or 0),
				CoffeeCredits = p.CoffeeCredits,
				Unlocked = math.max(p.Unlocked, old.Unlocked or 1),
			}
		end)
	end)
	return saved
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
end

return DataService

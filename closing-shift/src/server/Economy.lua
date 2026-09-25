--!strict
-- Cash: the paycheck after each shift, the Daily Shift Bonus, and upgrades bought at the break-room
-- locker. All cash moves through AddCash / SpendCash (one place for analytics to hook in).
-- Upgrade effects are published as player attributes the rest of the game reads:
--   CleanTimeMult (server hold check + client prompt), BatteryMult (flashlight), StaminaMult (sprint).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local BuyUpgrade = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuyUpgrade") :: RemoteEvent

local Economy = {}
-- Hook for analytics: (player, amount, source) when cash is earned or spent (amount < 0).
Economy.OnCashChanged = nil :: ((Player, number, string) -> ())?

local lastBuy: { [Player]: number } = {}

function Economy.AddCash(player: Player, amount: number, source: string)
	if amount <= 0 then
		return
	end
	DataService.Update(player, function(p)
		p.Cash += amount
	end)
	if Economy.OnCashChanged then
		Economy.OnCashChanged(player, amount, source)
	end
end

function Economy.SpendCash(player: Player, amount: number, sink: string): boolean
	local p = DataService.Get(player)
	if not p or p.Cash < amount then
		return false
	end
	DataService.Update(player, function(prof)
		prof.Cash -= amount
	end)
	if Economy.OnCashChanged then
		Economy.OnCashChanged(player, -amount, sink)
	end
	return true
end

-- Paycheck multiplier from boosts (VIP, Starter Pack 2x); Monetization sets these attributes.
function Economy.PayMultiplier(player: Player): number
	local m = 1
	if player:GetAttribute("VIP") then
		m *= 2
	end
	local boost = player:GetAttribute("DoublePayUntil")
	if type(boost) == "number" and os.time() < boost then
		m *= 2
	end
	return m
end

-- Applies upgrade tiers to the attributes gameplay reads.
function Economy.ApplyUpgrades(player: Player)
	local p = DataService.Get(player)
	if not p then
		return
	end
	for id, u in Config.Upgrades do
		local tier = p.Upgrades[id] or 0
		local value = if tier > 0 then u.Tiers[tier].Value else 1
		if u.Stat == "BatteryMult" and player:GetAttribute("BigFlashlight") then
			value *= Config.Monetization.Rewards.BigFlashlightBattery -- stacks with the pass
		end
		player:SetAttribute(u.Stat, value)
	end
end

-- Daily Shift Bonus: first shift of the (UTC) day. Returns the bonus paid (0 if already claimed).
function Economy.ClaimDaily(player: Player): (number, number)
	local p = DataService.Get(player)
	if not p then
		return 0, 0
	end
	local today = math.floor(os.time() / 86400)
	if p.Daily.LastDay == today then
		return 0, p.Daily.Streak
	end
	local streak = if p.Daily.LastDay == today - 1 then math.min(p.Daily.Streak + 1, Config.Daily.MaxStreak) else 1
	DataService.Update(player, function(prof)
		prof.Daily.LastDay = today
		prof.Daily.Streak = streak
	end)
	local bonus = streak * Config.Daily.PerStreakDay
	Economy.AddCash(player, bonus, "DailyBonus")
	return bonus, streak
end

export type Paycheck = { Lines: { { Label: string, Amount: number } }, Multiplier: number, Total: number }

-- Works out and pays this player's paycheck for a shift. Returns the breakdown for the results screen.
function Economy.Paycheck(player: Player, rules: any, cleanTime: number?, finalCleaner: boolean): Paycheck
	local P = Config.Pay
	local lines = {}
	local cleaned = (player:GetAttribute("Cleaned") or 0) :: number
	local base = 0
	local function add(label: string, amount: number)
		if amount > 0 then
			table.insert(lines, { Label = label, Amount = amount })
			base += amount
		end
	end
	add(string.format("SPILLS x%d", cleaned), cleaned * P.PerSpill)
	if finalCleaner then
		add("BACK ROOM", P.FinalSpill)
	end
	if cleanTime then
		add("SHIFT CLEAR", rules.WinBonus)
		if cleanTime < rules.ShiftLength * P.FastFraction then
			add("FAST SHIFT", P.FastBonus)
		end
		if rules.Manager.Enabled and not player:GetAttribute("CaughtThisShift") then
			add("NEVER CAUGHT", P.NoCatchBonus)
		end
	end
	local mult = Economy.PayMultiplier(player)
	local total = math.floor(base * mult)
	Economy.AddCash(player, total, "Paycheck")
	-- the daily bonus isn't multiplied
	local daily, streak = Economy.ClaimDaily(player)
	if daily > 0 then
		table.insert(lines, { Label = string.format("DAILY BONUS (DAY %d)", streak), Amount = daily })
		total += daily
	end
	return { Lines = lines, Multiplier = mult, Total = total }
end

local function buy(player: Player, id: any)
	if type(id) ~= "string" then
		return
	end
	local u = Config.Upgrades[id]
	local p = DataService.Get(player)
	if not u or not p or p.LoadFailed then
		return
	end
	local now = os.clock()
	if lastBuy[player] and now - lastBuy[player] < 0.4 then
		return
	end
	lastBuy[player] = now
	local tier = p.Upgrades[id] or 0
	local nextTier = u.Tiers[tier + 1]
	if not nextTier then
		return -- maxed
	end
	if Economy.SpendCash(player, nextTier.Cost, "Upgrade:" .. id) then
		DataService.Update(player, function(prof)
			prof.Upgrades[id] = tier + 1
		end)
		Economy.ApplyUpgrades(player)
		task.spawn(DataService.Save, player)
	end
end

function Economy.Init(store: Instance)
	BuyUpgrade.OnServerEvent:Connect(buy)
	DataService.Loaded.Event:Connect(function(player: Player)
		Economy.ApplyUpgrades(player)
	end)
	for _, p in Players:GetPlayers() do
		Economy.ApplyUpgrades(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastBuy[p] = nil
	end)
	-- the locker in the break room opens the upgrade menu on the client (see Locker.lua)
	local locker = store:FindFirstChild("MyLocker", true)
	if locker and locker:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "LockerPrompt"
		prompt.ActionText = "Upgrades"
		prompt.ObjectText = "Your Locker"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = locker
	else
		warn("[Economy] no MyLocker in the store; rebuild it with StoreBuilder.Build()")
	end
end

return Economy

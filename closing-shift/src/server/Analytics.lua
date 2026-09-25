--!strict
-- Creator Hub analytics (AnalyticsService). Nothing here changes gameplay, and every call is
-- pcall'd so a throttled or failing AnalyticsService can never break a shift.
--
--   Onboarding funnel (once per player, ever; the last step is kept in Stats.FunnelStep):
--     1 Joined, 2 First Spill, 3 Finished Night 1, 4 Reached Night 2, 5 Reached Night 3
--   Economy events: every cash source and sink (Paycheck, DailyBonus, Purchase:*, Upgrade:*)
--   Custom events (CustomField01 = what, CustomField02 = night):
--     ManagerCatch                     a player was caught
--     ShiftCompleted / ShiftFailed     per player, per night (value = clean time / spills cleaned)
--     OfferShown -> PromptShown -> PromptBought   per product: the in-game offer (Second Chance,
--       Clock In Late, Starter Pack), the Roblox purchase prompt, and the finished purchase
--
-- Studio debugging: set workspace attribute AnalyticsDebug = true to print every event.
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")
local DataService = require(script.Parent.DataService)

local Analytics = {}

local FUNNEL = { "Joined", "First Spill", "Finished Night 1", "Reached Night 2", "Reached Night 3" }
Analytics.Funnel = {
	Joined = 1,
	FirstSpill = 2,
	FinishedNight1 = 3,
	ReachedNight2 = 4,
	ReachedNight3 = 5,
}

local function debugPrint(...: any)
	if RunService:IsStudio() and workspace:GetAttribute("AnalyticsDebug") == true then
		print("[Analytics]", ...)
	end
end

local function call(fn: (...any) -> ...any, ...: any)
	local ok, err = pcall(fn, AnalyticsService, ...)
	if not ok then
		debugPrint("call failed:", err)
	end
end

local function fields(a: string?, b: string?): { [string]: string }?
	if not a and not b then
		return nil
	end
	local f = {}
	if a then
		f[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = a
	end
	if b then
		f[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = b
	end
	return f
end

-- Onboarding funnel: logs a step the first time this player reaches it. Steps can't go backwards,
-- and a step past the next one (a returning player who's already further along) is still logged.
function Analytics.Step(player: Player, step: number)
	local prof = DataService.Get(player)
	if not prof or prof.LoadFailed then
		return
	end
	local done = prof.Stats.FunnelStep or 0
	if step <= done then
		return
	end
	DataService.Update(player, function(p)
		p.Stats.FunnelStep = step
	end)
	debugPrint("funnel", player.Name, step, FUNNEL[step])
	call(AnalyticsService.LogOnboardingFunnelStepEvent, player, step, FUNNEL[step])
end

-- What kind of transaction a cash source/sink is (see Economy.AddCash / SpendCash callers).
local function transactionType(source: string): string
	if source:sub(1, 9) == "Purchase:" then
		return Enum.AnalyticsEconomyTransactionType.IAP.Name
	elseif source:sub(1, 8) == "Upgrade:" then
		return Enum.AnalyticsEconomyTransactionType.Shop.Name
	elseif source == "DailyBonus" then
		return Enum.AnalyticsEconomyTransactionType.TimedReward.Name
	end
	return Enum.AnalyticsEconomyTransactionType.Gameplay.Name
end

-- Economy: amount > 0 is cash earned (source), amount < 0 is cash spent (sink).
function Analytics.Cash(player: Player, amount: number, source: string)
	local prof = DataService.Get(player)
	local balance = if prof then prof.Cash else 0
	local flow = if amount >= 0 then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
	local sku = source:match(":(.+)$") or source
	debugPrint("cash", player.Name, flow.Name, math.abs(amount), source, "balance", balance)
	call(AnalyticsService.LogEconomyEvent, player, flow, "Cash", math.abs(amount), balance, transactionType(source), sku)
end

-- A custom event; `what` and `night` become CustomField01 / CustomField02 for breakdowns.
function Analytics.Event(player: Player, name: string, value: number?, what: string?, night: number?)
	local nightField = if night then "Night " .. night else nil
	debugPrint("event", player.Name, name, value or 1, what or "", nightField or "")
	call(AnalyticsService.LogCustomEvent, player, name, value or 1, fields(what, nightField))
end

function Analytics.Init()
	DataService.Loaded.Event:Connect(function(player: Player)
		Analytics.Step(player, Analytics.Funnel.Joined)
	end)
end

return Analytics

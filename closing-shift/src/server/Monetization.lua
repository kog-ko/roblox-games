--!strict
-- Game passes, developer products, gifting and the Starter Pack. IDs and rewards live in
-- Data/Monetization.
--
-- Purchases are requested by the client (RequestPurchase) and prompted by the server, which first
-- checks the product makes sense right now (boosts only during a shift, Second Chance only right
-- after you were caught, Clock In Late only on the YOU'RE FIRED screen, the Starter Pack only inside
-- its offer window, gifts only to someone in the server who doesn't own the pass).
--
-- ProcessReceipt is idempotent: every PurchaseId is recorded in the buyer's own profile in the same
-- save as the grant, and anything that fails returns NotProcessedYet so Roblox retries later.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Mop = require(script.Parent.Mop)
local Manager = require(script.Parent.Manager)
local ServerBoosts = require(script.Parent.ServerBoosts)
local RoundManager = require(script.Parent.RoundManager)
local Analytics = require(script.Parent.Analytics)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestPurchase = Remotes:WaitForChild("RequestPurchase") :: RemoteEvent
local RequestCoffee = Remotes:WaitForChild("RequestCoffee") :: RemoteEvent
local Banner = Remotes:WaitForChild("Banner") :: RemoteEvent
local Offer = Remotes:WaitForChild("Offer") :: RemoteEvent

local MON = Config.Monetization
local R = MON.Rewards
local PASSES = { "VIP", "IndustrialMop", "BigFlashlight" }

local Monetization = {}
-- Analytics hooks: (player, key) when a prompt is shown / a purchase is granted.
Monetization.OnPromptShown = nil :: ((Player, string) -> ())?
Monetization.OnPurchased = nil :: ((Player, string) -> ())?

local store: Instance
local ownedCache: { [Player]: { [string]: boolean } } = {}
local pendingGift: { [Player]: { pass: string, target: number } } = {}
local lastRequest: { [Player]: number } = {}

local function inShift(): boolean
	return ReplicatedStorage:GetAttribute("Phase") == "Shift"
end

local function productKey(productId: number): string?
	if productId == 0 then
		return nil
	end
	for key, id in MON.Products do
		if id == productId then
			return key
		end
	end
	return nil
end

-- Owned = bought on Roblox, or received as a gift (stored in the profile).
local function owns(player: Player, pass: string): boolean
	local cache = ownedCache[player]
	if cache and cache[pass] then
		return true
	end
	local prof = DataService.Get(player)
	return prof ~= nil and prof.GiftedPasses[pass] == true
end

-- Publishes pass perks as attributes (the rest of the game reads these).
local function applyPerks(player: Player)
	local vip = owns(player, "VIP")
	local mop = owns(player, "IndustrialMop")
	local flash = owns(player, "BigFlashlight")
	local hadMop = player:GetAttribute("IndustrialMop") == true
	player:SetAttribute("VIP", vip or nil)
	player:SetAttribute("IndustrialMop", mop or nil)
	player:SetAttribute("BigFlashlight", flash or nil)
	player:SetAttribute("BeamMult", if flash then R.BigFlashlightBeam else nil)
	Economy.ApplyUpgrades(player) -- battery stacks with the Big Flashlight
	if mop and not hadMop and inShift() then
		Mop.Give(player) -- swap to the gold one right away
	end
end

local function checkPasses(player: Player)
	local cache = ownedCache[player] or {}
	ownedCache[player] = cache
	for _, pass in PASSES do
		local id = MON.GamePasses[pass]
		if id ~= 0 and not cache[pass] then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if ok and has then
				cache[pass] = true
			end
		end
	end
	applyPerks(player)
end

function Monetization.ApplyCoffee(player: Player): boolean
	if not inShift() or player:GetAttribute("CoffeeUsed") then
		return false
	end
	if not (player.Character and player.Character:FindFirstChildOfClass("Humanoid")) then
		return false
	end
	-- The client's Movement module reads CoffeeUntil and applies Config.CoffeeWalkSpeed.
	player:SetAttribute("CoffeeUsed", true)
	player:SetAttribute("CoffeeUntil", workspace:GetServerTimeNow() + Config.CoffeeDuration)
	RoundManager.MarkAssisted()
	return true
end

-- The Starter Pack is offered once, after a player's first completed night. Called by RoundManager.
function Monetization.OnShiftResult(player: Player, won: boolean)
	local prof = DataService.Get(player)
	if not won or not prof or MON.Products.StarterPack == 0 then
		return
	end
	if prof.Starter.OfferUntil == 0 and not prof.Starter.Bought then
		DataService.Update(player, function(p)
			p.Starter.OfferUntil = os.time() + R.StarterOfferHours * 3600
		end)
		task.delay(Config.ResultsTime * 0.5, function()
			if player.Parent then
				Offer:FireClient(player, "StarterPack")
				Analytics.Event(player, "OfferShown", 1, "StarterPack")
			end
		end)
	end
end

-- Is this purchase allowed right now? Returns ok, reason.
local function canRequest(player: Player, key: string, extra: any): (boolean, string?)
	local prof = DataService.Get(player)
	if not prof or prof.LoadFailed then
		return false, "profile not loaded"
	end
	if ServerBoosts.IsBoost(key) then
		return ServerBoosts.CanOffer(key)
	elseif key == "SecondChance" then
		local at = player:GetAttribute("CaughtAt")
		return inShift() and type(at) == "number" and workspace:GetServerTimeNow() - at < R.SecondChanceWindow, "not caught"
	elseif key == "ClockInLate" then
		local untilT = ReplicatedStorage:GetAttribute("ReviveOfferUntil")
		return type(untilT) == "number" and workspace:GetServerTimeNow() < untilT, "offer closed"
	elseif key == "StarterPack" then
		return not prof.Starter.Bought and os.time() < prof.Starter.OfferUntil, "no offer"
	elseif key:sub(1, 4) == "Gift" then
		local pass = key:sub(5)
		local target = if typeof(extra) == "number" then Players:GetPlayerByUserId(extra) else nil
		if not target or target == player then
			return false, "pick another player in this server"
		end
		if owns(target, pass) then
			return false, "they already own it"
		end
		return true, nil
	end
	return true, nil
end

local function onRequest(player: Player, key: any, extra: any)
	if type(key) ~= "string" then
		return
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.5 then
		return
	end
	lastRequest[player] = now
	local passId = MON.GamePasses[key]
	if passId ~= nil then
		if passId ~= 0 and not owns(player, key) then
			MarketplaceService:PromptGamePassPurchase(player, passId)
			if Monetization.OnPromptShown then
				Monetization.OnPromptShown(player, key)
			end
		end
		return
	end
	local productId = MON.Products[key]
	if not productId or productId == 0 then
		return
	end
	local ok = canRequest(player, key, extra)
	if not ok then
		return
	end
	if key:sub(1, 4) == "Gift" then
		pendingGift[player] = { pass = key:sub(5), target = extra :: number }
	end
	MarketplaceService:PromptProductPurchase(player, productId)
	if Monetization.OnPromptShown then
		Monetization.OnPromptShown(player, key)
	end
end

-- What each product does. Returns true once it's granted.
local handlers: { [string]: (Player, any) -> boolean } = {}

for key in MON.Products do
	if ServerBoosts.IsBoost(key) then
		handlers[key] = function(player)
			ServerBoosts.Grant(key, player)
			return true
		end
	end
end

handlers.SecondChance = function(player)
	if not Manager.UndoCatch(player, R.SecondChanceWindow + 10) then
		-- too late to undo (the window closed while paying): bank a coffee instead
		DataService.Update(player, function(p)
			p.CoffeeCredits += 1
		end)
		Banner:FireClient(player, "TOO LATE FOR A SECOND CHANCE: +1 COFFEE", "SecondChance")
	end
	return true
end

handlers.ClockInLate = function(player)
	if RoundManager.RequestRevive() then
		Banner:FireAllClients(string.format("%s CLOCKED IN LATE! BACK TO WORK AT 5:00 AM", string.upper(player.DisplayName)), "ClockInLate")
	else
		-- someone else already revived, or the window closed while paying: pay it out as cash
		Economy.AddCash(player, R.PaycheckSmall, "Purchase:ClockInLateFallback")
		Banner:FireClient(player, string.format("TOO LATE TO CLOCK IN: +$%d", R.PaycheckSmall), "ClockInLate")
	end
	return true
end

handlers.ExtraCoffee = function(player)
	if not Monetization.ApplyCoffee(player) then
		DataService.Update(player, function(p)
			p.CoffeeCredits += 1
		end)
	end
	return true
end

for _, key in { "PaycheckSmall", "PaycheckMedium", "PaycheckLarge" } do
	handlers[key] = function(player)
		Economy.AddCash(player, R[key], "Purchase:" .. key)
		return true
	end
end

handlers.StarterPack = function(player)
	DataService.Update(player, function(p)
		p.Starter.Bought = true
		p.DoublePayUntil = math.max(p.DoublePayUntil, os.time()) + R.StarterDoublePayHours * 3600
	end)
	Economy.AddCash(player, R.StarterCash, "Purchase:StarterPack")
	return true
end

for _, pass in PASSES do
	handlers["Gift" .. pass] = function(player, info)
		local gift = pendingGift[player]
		pendingGift[player] = nil
		local targetId = if gift and gift.pass == pass then gift.target else player.UserId -- no target: it's theirs
		local target = Players:GetPlayerByUserId(targetId)
		if target then
			DataService.Update(target, function(p)
				p.GiftedPasses[pass] = true
			end)
			applyPerks(target)
			task.spawn(DataService.Save, target)
		elseif not DataService.GrantOffline(targetId, function(p)
			p.GiftedPasses[pass] = true
		end) then
			return false -- couldn't reach their save: try again later
		end
		local passName = (MON.Catalog[pass] and MON.Catalog[pass].Name) or pass
		local toName = if target then string.upper(target.DisplayName) else "A FRIEND"
		Banner:FireAllClients(string.format("%s GIFTED %s TO %s!", string.upper(player.DisplayName), passName, toName), "Gift")
		return true
	end
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local prof = player and DataService.Get(player)
	if not player or not prof or prof.LoadFailed then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if prof.Receipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted (a retry)
	end
	local key = productKey(info.ProductId)
	local handler = key and handlers[key]
	if not key or not handler then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(handler, player, info)
	if not ok then
		warn("[Monetization] grant failed for", key, granted)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.Update(player, function(p)
		p.Receipts[purchaseId] = os.time()
	end)
	-- the grant and the receipt id are written together; if that fails, Roblox retries and the
	-- receipt id (still in memory) stops a double grant
	if DataService.IsSaving() and not DataService.Save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if Monetization.OnPurchased then
		Monetization.OnPurchased(player, key)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Monetization.Init(s: Instance)
	store = s
	RoundManager.OnShiftResult = Monetization.OnShiftResult
	DataService.Loaded.Event:Connect(function(player: Player)
		task.spawn(checkPasses, player)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(checkPasses, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		ownedCache[p] = nil
		pendingGift[p] = nil
		lastRequest[p] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, pass in PASSES do
			if MON.GamePasses[pass] == passId and passId ~= 0 then
				local cache = ownedCache[player] or {}
				cache[pass] = true
				ownedCache[player] = cache
				applyPerks(player)
				Banner:FireAllClients(string.format("%s IS NOW %s!", string.upper(player.DisplayName), MON.Catalog[pass].Name), pass)
				if Monetization.OnPurchased then
					Monetization.OnPurchased(player, pass)
				end
			end
		end
	end)

	RequestPurchase.OnServerEvent:Connect(onRequest)

	-- Spend a banked coffee (the client only asks; the server decides).
	RequestCoffee.OnServerEvent:Connect(function(player)
		local profile = DataService.Get(player)
		if profile and profile.CoffeeCredits > 0 and Monetization.ApplyCoffee(player) then
			DataService.Update(player, function(p)
				p.CoffeeCredits -= 1
			end)
		end
	end)

	-- the vending machine opens the shop on the client (see Shop.lua)
	local vending = store:FindFirstChild("VendingMachine", true)
	if vending and vending:IsA("BasePart") then
		local shopPrompt = Instance.new("ProximityPrompt")
		shopPrompt.Name = "VendingPrompt"
		shopPrompt.ActionText = "Shop"
		shopPrompt.ObjectText = "Vending Machine"
		shopPrompt.HoldDuration = 0.2
		shopPrompt.MaxActivationDistance = 8
		shopPrompt.RequiresLineOfSight = false
		shopPrompt.Parent = vending
	end

	-- VIP lounge door: VIPs step through; everyone else is told it's VIP only (the pass is in the shop).
	local door = store:FindFirstChild("VIPDoor", true)
	local lounge = store:FindFirstChild("VIPLoungeSpawn", true)
	local exit = store:FindFirstChild("VIPLoungeExit", true)
	if door and door:IsA("BasePart") and lounge and lounge:IsA("BasePart") and exit and exit:IsA("BasePart") then
		local enter = Instance.new("ProximityPrompt")
		enter.Name = "VIPDoorPrompt"
		enter.ActionText = "Enter"
		enter.ObjectText = "VIP Lounge"
		enter.HoldDuration = 0.2
		enter.MaxActivationDistance = 8
		enter.RequiresLineOfSight = false
		enter.Parent = door
		enter.Triggered:Connect(function(player)
			if player:GetAttribute("VIP") and player.Character then
				player.Character:PivotTo((lounge :: BasePart).CFrame + Vector3.new(0, 3, 0))
			else
				Banner:FireClient(player, "VIP ONLY. GET VIP AT THE VENDING MACHINE", "VIP")
			end
		end)
		local leave = Instance.new("ProximityPrompt")
		leave.Name = "VIPExitPrompt"
		leave.ActionText = "Leave"
		leave.ObjectText = "VIP Lounge"
		leave.HoldDuration = 0.2
		leave.MaxActivationDistance = 8
		leave.RequiresLineOfSight = false
		leave.Parent = exit
		leave.Triggered:Connect(function(player)
			if player.Character then
				player.Character:PivotTo((door :: BasePart).CFrame * CFrame.new(0, 0, -3) + Vector3.new(0, 0, 0))
			end
		end)
	end

	MarketplaceService.ProcessReceipt = processReceipt
	if RunService:IsStudio() and not DataService.IsSaving() then
		print("[Monetization] Studio without API access: test purchases grant without the receipt save")
	end
end

-- For tests.
Monetization._processReceipt = processReceipt
Monetization._owns = owns

return Monetization

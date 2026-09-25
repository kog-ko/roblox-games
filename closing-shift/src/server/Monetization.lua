--!strict
-- Industrial Mop (game pass): gold, cosmetic, cleans 25% faster.
-- Extra Coffee (dev product): 30s speed boost, once per round. Bought outside a shift = banked for later.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Mop = require(script.Parent.Mop)

local Monetization = {}

local function inShift(): boolean
	return ReplicatedStorage:GetAttribute("Phase") == "Shift"
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
	return true
end

local function checkPass(player: Player)
	local id = Config.GamePasses.IndustrialMop
	if id == 0 then
		return
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
	if ok and owns then
		player:SetAttribute("IndustrialMop", true)
	end
end

function Monetization.Init()
	Players.PlayerAdded:Connect(checkPass)
	for _, p in Players:GetPlayers() do
		task.spawn(checkPass, p)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Config.GamePasses.IndustrialMop and passId ~= 0 then
			player:SetAttribute("IndustrialMop", true)
			if inShift() then
				Mop.Give(player) -- swap to the gold one right away
			end
		end
	end)

	-- Spend a banked coffee (the client only asks; the server decides).
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestCoffee") :: RemoteEvent
	remote.OnServerEvent:Connect(function(player)
		local profile = DataService.Get(player)
		if profile and profile.CoffeeCredits > 0 and Monetization.ApplyCoffee(player) then
			DataService.Update(player, function(p)
				p.CoffeeCredits -= 1
			end)
		end
	end)

	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not player or not DataService.Get(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if info.ProductId == Config.DevProducts.ExtraCoffee then
			if not Monetization.ApplyCoffee(player) then
				DataService.Update(player, function(p)
					p.CoffeeCredits += 1
				end)
				DataService.Save(player)
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return Monetization

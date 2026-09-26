--!strict
-- CLOSING SHIFT lobby client. Third person here (so you can see everyone's look); the PSX
-- overlay, the shop, the upgrade locker and the banners are the same modules the shift uses.
require(script:WaitForChild("Overlay")).Start()
require(script:WaitForChild("Offers")).Start()
require(script:WaitForChild("Locker")).Start()
local Shop = require(script:WaitForChild("Shop"))
local Wardrobe = require(script:WaitForChild("Wardrobe"))
local PartyUi = require(script:WaitForChild("PartyUi"))
local JobsUi = require(script:WaitForChild("JobsUi"))

local function openShop()
	if Shop.Open then
		Shop.Open()
	end
end
Shop.Start()
Wardrobe.Start(openShop)
PartyUi.Start()
JobsUi.Start()
require(script:WaitForChild("LobbyHud")).Start({
	Shop = openShop,
	Style = function()
		if Wardrobe.Open then
			Wardrobe.Open()
		end
	end,
	Party = function()
		if PartyUi.Open then
			PartyUi.Open()
		end
	end,
	Jobs = function()
		if JobsUi.Open then
			JobsUi.Open()
		end
	end,
})

--!strict
-- CLOSING SHIFT lobby client. Third person here (so you can see everyone's look); the PSX
-- overlay, the shop, the upgrade locker and the banners are the same modules the shift uses.
require(script:WaitForChild("Prefs")).Start()
require(script:WaitForChild("Overlay")).Start()
require(script:WaitForChild("Music")).Start("Lobby")
require(script:WaitForChild("LobbySound")).Start()
require(script:WaitForChild("Offers")).Start()
require(script:WaitForChild("Locker")).Start()
local Shop = require(script:WaitForChild("Shop"))
local Wardrobe = require(script:WaitForChild("Wardrobe"))
local PartyUi = require(script:WaitForChild("PartyUi"))
local JobsUi = require(script:WaitForChild("JobsUi"))
local AwardsUi = require(script:WaitForChild("AwardsUi"))
local PassUi = require(script:WaitForChild("PassUi"))

local function openShop()
	if Shop.Open then
		Shop.Open()
	end
end
Shop.Start()
Wardrobe.Start(openShop)
PartyUi.Start()
JobsUi.Start()
AwardsUi.Start()
PassUi.Start()
require(script:WaitForChild("ObbyUi")).Start()
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
	Awards = function()
		if AwardsUi.Open then
			AwardsUi.Open()
		end
	end,
	Pass = function()
		if PassUi.Open then
			PassUi.Open()
		end
	end,
})

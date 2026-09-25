--!strict
-- CLOSING SHIFT lobby client. Third person here (so you can see everyone's look); the PSX
-- overlay, the shop, the upgrade locker and the banners are the same modules the shift uses.
require(script:WaitForChild("Overlay")).Start()
require(script:WaitForChild("Offers")).Start()
require(script:WaitForChild("Locker")).Start()
local Shop = require(script:WaitForChild("Shop"))
Shop.Start()
require(script:WaitForChild("LobbyHud")).Start(function()
	if Shop.Open then
		Shop.Open()
	end
end)

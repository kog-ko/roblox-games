--!strict
-- The door chime rings. Nobody is there.
local CollectionService = game:GetService("CollectionService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

return function(ctx)
	local bell = CollectionService:GetTagged("DoorChime")[1]
	if bell then
		ctx.playSound(bell, Config.Sounds.Chime, 1)
	end
end

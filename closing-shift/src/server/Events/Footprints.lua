--!strict
-- Footprints lead from the aisles into the back room.
local Layout = require(game:GetService("ReplicatedStorage").Shared.Layout)

return function(ctx)
	ctx.spills.SpawnFootprints({
		Layout.Map(Vector3.new(17, 0, 4)), Layout.Map(Vector3.new(17, 0, -13)), Layout.Map(Vector3.new(29, 0, -12.5)), Layout.Map(Vector3.new(37, 0, -12)),
	}, ctx.tuning.Chunks or 3)
end

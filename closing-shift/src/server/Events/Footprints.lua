--!strict
-- Footprints lead from the aisles into the back room.
return function(ctx)
	ctx.spills.SpawnFootprints({
		Vector3.new(17, 0, 4), Vector3.new(17, 0, -13), Vector3.new(29, 0, -12.5), Vector3.new(37, 0, -12),
	}, ctx.tuning.Chunks or 3)
end

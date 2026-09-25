--!strict
-- The lights die for a moment; when they come back there's a spill behind whoever is nearest the back room.
return function(ctx)
	local release = ctx.cutPower()
	task.wait(ctx.tuning.Duration or 2)
	local target = (ctx.store:FindFirstChild("FinalSpillMarker", true) :: BasePart).Position
	local best, bestDist = nil, math.huge
	for _, r in ctx.roots() do
		local d = (r.Position - target).Magnitude
		if d < bestDist then
			best, bestDist = r, d
		end
	end
	if best and ctx.isCurrent() and not ctx.spills.IsFinalPhase() then
		local look = Vector3.new(best.CFrame.LookVector.X, 0, best.CFrame.LookVector.Z)
		look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
		local pos = best.Position - look * (ctx.tuning.BehindPlayerDistance or 6)
		if pos.X > 30.5 then -- in the back room
			pos = Vector3.new(math.clamp(pos.X, 32, 46), 0, math.clamp(pos.Z, -19, -5))
		elseif pos.X < -30.5 then -- in the restroom hallway
			pos = Vector3.new(math.clamp(pos.X, -44, -32), 0, math.clamp(pos.Z, -15.5, -10.5))
		else
			pos = Vector3.new(math.clamp(pos.X, -28, 29), 0, math.clamp(pos.Z, -15, 18))
		end
		ctx.spills.Spawn(pos)
	end
	release()
end

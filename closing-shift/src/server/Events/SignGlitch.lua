--!strict
-- Aisle signs briefly read 1, 2, 3, 5.
return function(ctx)
	ctx.setSignNumbers({ 1, 2, 3, 5 })
	task.wait(ctx.tuning.Duration or 4)
	ctx.setSignNumbers({ 1, 2, 3, 4 })
end

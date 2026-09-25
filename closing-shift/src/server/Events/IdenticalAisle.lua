--!strict
-- One aisle becomes a wall of the same plain product.
return function(ctx)
	local list = ctx.aisles()
	ctx.builder.MakeIdentical(list[ctx.rng:NextInteger(1, #list)])
end

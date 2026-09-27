--!strict
-- The payphone out front starts ringing. It rings, and rings... then it's picked up. There's
-- nobody out there.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

return function(ctx)
	local phone = ctx.store:FindFirstChild("Payphone", true) :: BasePart?
	if not phone then
		return
	end
	local ring = Instance.new("Sound")
	ring.SoundId = Config.Sounds.PayphoneRing
	ring.Volume = 1
	ring.Looped = true
	ring.RollOffMaxDistance = 160
	ring.RollOffMinDistance = 12
	ring.Parent = phone
	ring:Play()
	local rings = ctx.rng:NextInteger(ctx.tuning.MinRings or 3, ctx.tuning.MaxRings or 6)
	for _ = 1, rings do
		task.wait(3)
		if not ctx.isCurrent() then
			break
		end
	end
	ring:Destroy()
	if ctx.isCurrent() then
		ctx.playSound(phone, Config.Sounds.PhonePickUp, 1)
	end
end

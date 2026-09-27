--!strict
-- Keeps a fixed-size panel on screen: a UIScale that shrinks it (never grows it) so its design size
-- plus a margin fits the viewport. Phones in landscape are only ~360-420 px tall, so the results
-- screen, the night picker and the lobby's button column all go through this.
local Workspace = game:GetService("Workspace")

local Fit = {}

-- design: the panel's full size in pixels at scale 1. margin: pixels to keep free around it
-- (the top bar, the thumbstick, ...).
function Fit.Scale(frame: GuiObject, design: Vector2, margin: Vector2?): UIScale
	local scale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = frame
	local m = margin or Vector2.new(24, 80)
	local function update()
		local vp = Workspace.CurrentCamera.ViewportSize
		local s = math.clamp(math.min((vp.X - m.X) / design.X, (vp.Y - m.Y) / design.Y), 0.45, 1)
		scale:SetAttribute("Fit", s) -- (pop-in animations tween up to this, not to 1)
		scale.Scale = s
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
	return scale
end

return Fit

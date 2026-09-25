--!strict
-- One place for input. Each action gets keyboard/gamepad keys plus an on-screen touch button,
-- all through ContextActionService, so phones get the same controls as PC.
local ContextActionService = game:GetService("ContextActionService")

local Controls = {}

type Handler = (began: boolean) -> ()

-- Touch buttons stack up the right side, above the jump button. Each action keeps its slot,
-- so an action can be unbound and rebound without the buttons shuffling.
local slotOf: { [string]: number } = { Clean = 0, Sprint = 1, Flashlight = 2 }
local nextSlot = 3
local function placeButton(action: string, title: string)
	local button = ContextActionService:GetButton(action)
	if not button then
		return
	end
	local slot = slotOf[action]
	if not slot then
		slot = nextSlot
		nextSlot += 1
		slotOf[action] = slot
	end
	ContextActionService:SetTitle(action, title)
	button.Size = UDim2.fromOffset(70, 70)
	button.Position = UDim2.new(1, -95 - (slot % 2) * 80, 1, -170 - math.floor(slot / 2) * 80)
end

-- handler(true) on press, handler(false) on release.
function Controls.Bind(action: string, title: string, handler: Handler, ...: Enum.KeyCode | Enum.UserInputType)
	ContextActionService:BindAction(action, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			handler(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			handler(false)
		end
		return Enum.ContextActionResult.Pass
	end, true, ...)
	placeButton(action, title)
end

function Controls.Unbind(action: string)
	ContextActionService:UnbindAction(action)
end

return Controls

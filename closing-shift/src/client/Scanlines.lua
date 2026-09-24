--!strict
-- Subtle CRT scanlines: one thin semi-transparent Frame every few pixels. Rebuilt only on resize.
local Players = game:GetService("Players")

local Scanlines = {}
local SPACING = 4

function Scanlines.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Scanlines"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Active = false
	holder.Parent = gui

	local built = 0
	local function rebuild()
		local h = gui.AbsoluteSize.Y
		local need = math.ceil(h / SPACING)
		if need == built then
			return
		end
		holder:ClearAllChildren()
		for i = 0, need - 1 do
			local line = Instance.new("Frame")
			line.BorderSizePixel = 0
			line.BackgroundColor3 = Color3.new(0, 0, 0)
			line.BackgroundTransparency = 0.85
			line.Size = UDim2.new(1, 0, 0, 1)
			line.Position = UDim2.fromOffset(0, i * SPACING)
			line.Parent = holder
		end
		built = need
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rebuild)
	rebuild()
end

return Scanlines

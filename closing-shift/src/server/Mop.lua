--!strict
-- Builds the Mop tool from Parts. Gold version for the Industrial Mop pass.
local Mop = {}

local function make(gold: boolean): Tool
	local tool = Instance.new("Tool")
	tool.Name = if gold then "Industrial Mop" else "Mop"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("IsMop", true)
	-- Hand holds the stick 1.5 studs from the top; the stick tilts forward so the head
	-- (at the bottom, counter-rotated to lie flat) rests just above the floor in front of you.
	local tilt = math.rad(62)
	tool.Grip = CFrame.new(0, 1, 0) * CFrame.Angles(-tilt, 0, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.25, 5, 0.25)
	handle.Material = Enum.Material.SmoothPlastic
	handle.Color = if gold then Color3.fromRGB(212, 175, 55) else Color3.fromRGB(120, 90, 60)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "MopHead"
	head.Size = Vector3.new(1.6, 0.5, 0.9)
	head.Material = Enum.Material.SmoothPlastic
	head.Color = if gold then Color3.fromRGB(245, 215, 110) else Color3.fromRGB(170, 158, 110) -- dirty string mop
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, -2.6, 0) * CFrame.Angles(-tilt, 0, 0)
	head.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle
	return tool
end

local templates = { [false] = make(false), [true] = make(true) }

-- Gives a fresh mop and puts it straight in the player's hands (there is no hotbar).
-- While the shift runs, an unequipped mop is re-equipped, so it can't be put away.
function Mop.Give(player: Player)
	Mop.Remove(player)
	local gold = player:GetAttribute("IndustrialMop") == true
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local tool = templates[gold]:Clone()
	tool.Parent = backpack
	local function equip()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and tool.Parent == backpack then
			hum:EquipTool(tool)
		end
	end
	tool.Unequipped:Connect(function()
		task.defer(equip)
	end)
	equip()
end

function Mop.Remove(player: Player)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, t in container:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("IsMop") then
					t:Destroy()
				end
			end
		end
	end
end

function Mop.IsHolding(player: Player): boolean
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("IsMop") == true
end

return Mop

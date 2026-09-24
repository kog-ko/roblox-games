--!strict
-- Builds the Mop tool from Parts. Gold version for the Industrial Mop pass.
local Mop = {}

local function make(gold: boolean): Tool
	local tool = Instance.new("Tool")
	tool.Name = if gold then "Industrial Mop" else "Mop"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("IsMop", true)
	-- Hand holds the stick about 1 stud from the top; the head hangs toward the floor.
	tool.Grip = CFrame.new(0, -1.5, 0)

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
	head.Color = if gold then Color3.fromRGB(245, 215, 110) else Color3.fromRGB(200, 200, 185)
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 2.6, 0)
	head.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle
	return tool
end

local templates = { [false] = make(false), [true] = make(true) }

function Mop.Give(player: Player)
	Mop.Remove(player)
	local gold = player:GetAttribute("IndustrialMop") == true
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		templates[gold]:Clone().Parent = backpack
	end
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

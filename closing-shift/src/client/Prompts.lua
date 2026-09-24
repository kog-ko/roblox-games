--!strict
-- Spill prompts only show while you hold a mop; Industrial Mop owners get a shorter hold.
-- (The server re-checks all of this, so it's purely UX.)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Prompts = {}
local player = Players.LocalPlayer :: Player

local function holdingMop(): boolean
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("IsMop") == true
end

local function apply(prompt: Instance)
	if prompt:IsA("ProximityPrompt") then
		prompt.Enabled = holdingMop()
		local mult = if player:GetAttribute("IndustrialMop") then 1 - Config.IndustrialMopSpeedup else 1
		prompt.HoldDuration = Config.CleanHoldTime * mult
	end
end

local function refresh()
	for _, p in CollectionService:GetTagged("SpillPrompt") do
		apply(p)
	end
end

function Prompts.Start()
	CollectionService:GetInstanceAddedSignal("SpillPrompt"):Connect(apply)
	player:GetAttributeChangedSignal("IndustrialMop"):Connect(refresh)
	local function hook(char: Model)
		char.ChildAdded:Connect(refresh)
		char.ChildRemoved:Connect(refresh)
		refresh()
	end
	if player.Character then
		hook(player.Character)
	end
	player.CharacterAdded:Connect(hook)
end

return Prompts

--!strict
-- Spill prompts only show while you hold a mop; Industrial Mop owners get a shorter hold.
-- (The server re-checks all of this, so it's purely UX.)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Controls = require(script.Parent:WaitForChild("Controls"))

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

-- Touch "CLEAN" button: appears while a spill prompt is on screen and holds that prompt,
-- so phones get the same server-checked hold as the E key.
local function bindCleanButton()
	local shown: ProximityPrompt? = nil
	local holding: ProximityPrompt? = nil
	local function release()
		if holding then
			holding:InputHoldEnd()
			holding = nil
		end
	end
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if not CollectionService:HasTag(prompt, "SpillPrompt") then
			return
		end
		shown = prompt
		Controls.Bind("Clean", "MOP", function(began)
			release()
			if began and shown and shown.Enabled then
				holding = shown
				shown:InputHoldBegin()
			end
		end)
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt == shown then
			shown = nil
			release()
			Controls.Unbind("Clean")
		end
	end)
end

function Prompts.Start()
	bindCleanButton()
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

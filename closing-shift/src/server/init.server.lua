--!strict
-- CLOSING SHIFT server entry point. All game logic lives on the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Make sure the RemoteEvents exist even if the place wasn't synced with Rojo's project file.
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
for _, name in { "ReadyUp", "RequestCoffee", "Results", "PayoffCue", "ShowNote", "Flashlight", "Cleaned", "PickNight" } do
	if not (remotes :: Instance):FindFirstChild(name) then
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
end

local Config = require(ReplicatedStorage.Shared.Config)
local StoreBuilder = require(script:FindFirstChild(Config.Stores[Config.DefaultStore].Builder) :: ModuleScript)
local store = workspace:FindFirstChild("Store")
if not store then
	store = StoreBuilder.Build()
else
	StoreBuilder.SetupLighting()
end
local s = store :: Instance

local DataService = require(script.DataService)
local Leaderboard = require(script.Leaderboard)
local SpillService = require(script.SpillService)
local EventDirector = require(script.EventDirector)
local Payoff = require(script.Payoff)
local Monetization = require(script.Monetization)
local RoundManager = require(script.RoundManager)
local ShiftBoard = require(script.ShiftBoard)

DataService.Init()
Leaderboard.Init(s)
SpillService.Init(s)
EventDirector.Init(s)
Payoff.Init(s)
Monetization.Init()
RoundManager.Init(s)
ShiftBoard.Init(s)
task.spawn(RoundManager.Run)

-- Flashlight on/off is cosmetic: store it so every client can draw the beam.
local flashlightRemote = (remotes :: Instance):WaitForChild("Flashlight") :: RemoteEvent
flashlightRemote.OnServerEvent:Connect(function(player, on)
	if typeof(on) == "boolean" then
		player:SetAttribute("FlashlightOn", on)
	end
end)

-- Studio-only playtest commands. From the server command bar while playing, e.g.:
--   _G.ClosingShift.Start()  _G.ClosingShift.CleanAll()  _G.ClosingShift.Timeout()  _G.ClosingShift.Event("Mannequin")
if game:GetService("RunService"):IsStudio() then
	local Players = game:GetService("Players")
	_G.ClosingShift = {
		Start = RoundManager.ForceStart,
		Timeout = RoundManager.ForceTimeout,
		Event = EventDirector.Force,
		Night = RoundManager.SetNight, -- _G.ClosingShift.Night(2) plays night 2 next
		CleanOne = function()
			local p = Players:GetPlayers()[1]
			return p and SpillService.DebugCleanOne(p)
		end,
		CleanAll = function()
			local list = Players:GetPlayers()
			local i = 0
			while #list > 0 do
				i += 1
				local p = list[(i - 1) % #list + 1]
				if not SpillService.DebugCleanOne(p) then
					task.wait(0.5) -- the back-room spill appears after the floor is clean
					if not SpillService.DebugCleanOne(p) then
						break
					end
				end
				task.wait(0.2)
			end
		end,
	}
end

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
for _, name in { "ReadyUp", "RequestCoffee", "Results", "PayoffCue", "ShowNote", "Flashlight", "Cleaned", "PickNight", "Caught", "BuyUpgrade", "RequestPurchase", "Banner", "Offer" } do
	if not (remotes :: Instance):FindFirstChild(name) then
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
end

local Config = require(ReplicatedStorage.Shared.Config)
if not (remotes :: Instance):FindFirstChild("ViewReport") then
	local r = Instance.new("UnreliableRemoteEvent")
	r.Name = "ViewReport"
	r.Parent = remotes
end

local StoreBuilder = require(script:FindFirstChild(Config.Stores[Config.DefaultStore].Builder) :: ModuleScript)
local store = workspace:FindFirstChild("Store")
if not store then
	store = StoreBuilder.Build()
else
	StoreBuilder.SetupLighting()
end
local s = store :: Instance

local DataService = require(script.DataService)
local Analytics = require(script.Analytics)
local Leaderboard = require(script.Leaderboard)
local SpillService = require(script.SpillService)
local EventDirector = require(script.EventDirector)
local Payoff = require(script.Payoff)
local Economy = require(script.Economy)
local ServerBoosts = require(script.ServerBoosts)
local Monetization = require(script.Monetization)
local Manager = require(script.Manager)
local RoundManager = require(script.RoundManager)
local ShiftBoard = require(script.ShiftBoard)

-- analytics listens first so it sees every profile load; the cash and purchase hooks feed it
Analytics.Init()
Economy.OnCashChanged = Analytics.Cash
Monetization.OnPromptShown = function(player, key)
	Analytics.Event(player, "PromptShown", 1, key)
end
Monetization.OnPurchased = function(player, key)
	Analytics.Event(player, "PromptBought", 1, key)
end
DataService.Init()
Economy.Init(s)
Leaderboard.Init(s)
SpillService.Init(s)
EventDirector.Init(s)
Payoff.Init(s)
ServerBoosts.Init(s)
Monetization.Init(s)
Manager.Init(s)
RoundManager.Init(s)
ShiftBoard.Init(s)
task.spawn(RoundManager.Run)

-- Flashlight on/off is cosmetic: store it so every client can draw the beam.
local flashlightRemote = (remotes :: Instance):WaitForChild("Flashlight") :: RemoteEvent
-- At most ten updates a second per player (each one reaches every client); a toggle that comes
-- too fast isn't dropped, it's applied at the end of the window so the beam never desyncs.
local lastToggle: { [Player]: number } = {}
local pendingToggle: { [Player]: boolean } = {}
flashlightRemote.OnServerEvent:Connect(function(player, on)
	if typeof(on) ~= "boolean" then
		return
	end
	local remaining = 0.1 - (os.clock() - (lastToggle[player] or 0))
	if remaining <= 0 then
		lastToggle[player] = os.clock()
		player:SetAttribute("FlashlightOn", on)
		return
	end
	local scheduled = pendingToggle[player] ~= nil
	pendingToggle[player] = on
	if not scheduled then
		task.delay(remaining, function()
			local latest = pendingToggle[player]
			pendingToggle[player] = nil
			if latest ~= nil and player.Parent then
				lastToggle[player] = os.clock()
				player:SetAttribute("FlashlightOn", latest)
			end
		end)
	end
end)
game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastToggle[player] = nil
	pendingToggle[player] = nil
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
		ManagerPlace = Manager.PlaceAt, -- _G.ClosingShift.ManagerPlace(Vector3.new(0, 0, 10))
		ManagerDebug = Manager.Debug, -- position, watched, who is watching
		ViewOf = Manager.ViewOf, -- a player's last reported camera CFrame
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

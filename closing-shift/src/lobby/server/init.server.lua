--!strict
-- CLOSING SHIFT lobby (the experience's start place). Players hang out, show off, spend shift cash,
-- and queue for a shift; the shift itself runs in the Shift place (Config.Places.Shift).
-- The save, economy, shop, name tags and leaderboards are the same modules the shift place uses.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
-- the shared client modules (Shop, Offers, Locker) wait for these
for _, name in { "RequestPurchase", "RequestCoffee", "BuyUpgrade", "Banner", "Offer", "Caught" } do
	if not (remotes :: Instance):FindFirstChild(name) then
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
end
ReplicatedStorage:SetAttribute("Phase", "Hub")

local LobbyBuilder = require(script.LobbyBuilder)
local lobby = workspace:FindFirstChild("Lobby")
if not lobby then
	lobby = LobbyBuilder.Build()
else
	LobbyBuilder.SetupLighting()
end
local l = lobby :: Instance

local DataService = require(script.DataService)
local Analytics = require(script.Analytics)
local Economy = require(script.Economy)
local Monetization = require(script.Monetization)
local Leaderboard = require(script.Leaderboard)
local NameTags = require(script.NameTags)
local Cosmetics = require(script.Cosmetics)
local Jobs = require(script.Jobs)
local Queue = require(script.Queue)
local LobbyBoards = require(script.LobbyBoards)
local Party = require(script.Party)
local Stations = require(script.Stations)

Analytics.Init()
Economy.OnCashChanged = Analytics.Cash
Monetization.OnPromptShown = function(player, key)
	Analytics.Event(player, "PromptShown", 1, key)
end
Monetization.OnPurchased = function(player, key)
	Analytics.Event(player, "PromptBought", 1, key)
end
DataService.Init()
Economy.Init(l)
Monetization.Init(l)
Leaderboard.Init(l) -- trophies and weekly counts (the lobby's boards are LobbyBoards)
NameTags.Init()
Cosmetics.Init({ Trails = true })
Jobs.Init()
Party.Init()
Queue.Init(l)
LobbyBoards.Init(l)
Stations.Init(l)

if game:GetService("RunService"):IsStudio() then
	_G.ClosingShiftLobby = {
		Queue = Queue.Debug,
	}
end

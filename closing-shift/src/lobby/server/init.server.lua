--!strict
-- CLOSING SHIFT lobby (the experience's start place). Players hang out, show off, spend shift cash,
-- and queue for a shift; the shift itself runs in the Shift place (Config.Places.Shift).
-- The save, economy, shop, name tags and leaderboards are the same modules the shift place uses.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
-- the shared client modules (Shop, Offers, Locker) wait for these
for _, name in { "RequestPurchase", "RequestCoffee", "BuyUpgrade", "Banner", "Offer", "Caught", "ObbySfx" } do
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
local Achievements = require(script.Achievements)
local ShiftPass = require(script.ShiftPass)
local PlayerPrefs = require(script.PlayerPrefs)
local Queue = require(script.Queue)
local LobbyBoards = require(script.LobbyBoards)
local Party = require(script.Party)
local Stations = require(script.Stations)
local Obby = require(script.Obby)
local SeasonDecor = require(script.SeasonDecor)
local Season = require(ReplicatedStorage.Shared.Season)

Analytics.Init()
Economy.OnCashChanged = Analytics.Cash
Monetization.OnPromptShown = function(player, key)
	Analytics.Event(player, "PromptShown", 1, key)
end
Monetization.OnPurchased = function(player, key)
	Analytics.Event(player, "PromptBought", 1, key)
end
DataService.Init()
Achievements.Init()
ShiftPass.Init()
PlayerPrefs.Init()
Achievements.OnEarned = function(player)
	ShiftPass.AddXp(player, Config.Pass.Xp.Achievement)
end
Economy.OnStreak = Achievements.Check
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
Obby.Init()
SeasonDecor.Init(l, "Lobby")
-- tell everyone arriving about the running event
game:GetService("Players").PlayerAdded:Connect(function(p)
	local s = Season.Current()
	if s then
		task.delay(6, function()
			local banner = ReplicatedStorage.Remotes:FindFirstChild("Banner") :: RemoteEvent?
			if banner and p.Parent then
				banner:FireClient(p, string.format("%s EVENT: FIND %s ON SHIFTS, SPEND IT IN THE WARDROBE. %s", s.Name, s.Currency, Season.EndsIn(s)), "Event")
			end
		end)
	end
end)

if game:GetService("RunService"):IsStudio() then
	_G.ClosingShiftLobby = {
		Queue = Queue.Debug,
		-- test sessions stub saving / board writes through these
		DataService = DataService,
		Leaderboard = Leaderboard,
	}
end

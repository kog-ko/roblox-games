--!strict
-- Lobby stations: the time clock (the daily clock-in bonus, same streak as the paycheck's), the
-- job board (today's and this week's jobs; your own progress is in the JOBS panel), and the
-- wardrobe prompt (the client opens the cosmetics shop).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progress = require(ReplicatedStorage.Shared.Progress)
local Economy = require(script.Parent.Economy)

local Stations = {}

local function prompt(parent: Instance, name: string, action: string, object: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.2
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function refreshJobBoard(list: TextLabel)
	local lines = { "TODAY" }
	for _, j in Progress.DailyJobs() do
		table.insert(lines, string.format("- %s  $%d", j.Text, j.Reward))
	end
	local left = 86400 - (os.time() % 86400)
	table.insert(lines, string.format("(NEW JOBS IN %dH %dM)", left // 3600, (left % 3600) // 60))
	table.insert(lines, "")
	table.insert(lines, "THIS WEEK")
	for _, j in Progress.WeeklyJobs() do
		table.insert(lines, string.format("- %s  $%d", j.Text, j.Reward))
	end
	list.Text = table.concat(lines, "\n")
end

function Stations.Init(lobby: Instance)
	local Banner = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Banner") :: RemoteEvent
	local clock = lobby:FindFirstChild("TimeClock", true)
	if clock then
		prompt(clock, "TimeClockPrompt", "Clock In", "Daily Bonus").Triggered:Connect(function(player)
			local bonus, streak = Economy.ClaimDaily(player)
			if bonus > 0 then
				Banner:FireClient(player, string.format("CLOCKED IN: DAY %d STREAK  +$%d", streak, bonus), "Daily")
			else
				Banner:FireClient(player, "ALREADY CLOCKED IN TODAY. BACK TOMORROW", "Daily")
			end
		end)
	end
	local wardrobe = lobby:FindFirstChild("Wardrobe", true)
	if wardrobe then
		prompt(wardrobe, "WardrobePrompt", "Browse", "Wardrobe")
	end
	local board = lobby:FindFirstChild("JobBoard", true)
	local list = board and board:FindFirstChild("List", true) :: TextLabel?
	if list then
		task.spawn(function()
			while true do
				refreshJobBoard(list)
				task.wait(60)
			end
		end)
	end
end

return Stations

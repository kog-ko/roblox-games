--!strict
-- Daily and weekly jobs (Data/Challenges.lua). Progress lives in the profile (Jobs), resets when the
-- UTC day / the week rolls over, and a finished job pays its reward in cash at once. The shift
-- place records progress at the end of each night; both places publish the list for the HUD as
-- the Jobs attribute (JSON: { { Id, Text, Goal, Progress, Reward, Weekly, Done } }).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progress = require(ReplicatedStorage.Shared.Progress)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)

local Jobs = {}
local Banner: RemoteEvent? = nil

local function active(): { { job: any, weekly: boolean } }
	local out = {}
	for _, j in Progress.DailyJobs() do
		table.insert(out, { job = j, weekly = false })
	end
	for _, j in Progress.WeeklyJobs() do
		table.insert(out, { job = j, weekly = true })
	end
	return out
end

-- Clears progress from a past day ("d_" jobs) / week ("w_" jobs).
local function clear(p: any, prefix: string)
	for _, t in { p.Jobs.Progress, p.Jobs.Done } do
		for id in t do
			if id:sub(1, 2) == prefix then
				t[id] = nil
			end
		end
	end
end

local function roll(p: any)
	local day, week = Progress.Day(), Progress.Week()
	if p.Jobs.Day ~= day then
		clear(p, "d_")
		p.Jobs.Day = day
	end
	if p.Jobs.Week ~= week then
		clear(p, "w_")
		p.Jobs.Week = week
	end
end

function Jobs.Publish(player: Player)
	local prof = DataService.Get(player)
	if not prof then
		return
	end
	DataService.Update(player, roll)
	local list = {}
	for _, a in active() do
		local j = a.job
		table.insert(list, {
			Id = j.Id, Text = j.Text, Goal = j.Goal, Reward = j.Reward, Weekly = a.weekly,
			Progress = math.min(prof.Jobs.Progress[j.Id] or 0, j.Goal), Done = prof.Jobs.Done[j.Id] == true,
		})
	end
	player:SetAttribute("Jobs", HttpService:JSONEncode(list))
end

-- Adds progress to every active job of this kind (arg: the night, for winNight jobs).
function Jobs.Record(player: Player, kind: string, amount: number, arg: number?)
	if amount <= 0 then
		return
	end
	local prof = DataService.Get(player)
	if not prof or prof.LoadFailed then
		return
	end
	local finished = {}
	DataService.Update(player, function(p)
		roll(p)
		for _, a in active() do
			local j = a.job
			if j.Kind == kind and (j.Arg == nil or j.Arg == arg) and not p.Jobs.Done[j.Id] then
				local v = (p.Jobs.Progress[j.Id] or 0) + amount
				p.Jobs.Progress[j.Id] = v
				if v >= j.Goal then
					p.Jobs.Done[j.Id] = true
					table.insert(finished, j)
				end
			end
		end
	end)
	for _, j in finished do
		Economy.AddCash(player, j.Reward, "Job:" .. j.Id)
		if Banner then
			Banner:FireClient(player, string.format("JOB DONE: %s  +$%d", j.Text, j.Reward), "Job")
		end
	end
	Jobs.Publish(player)
end

function Jobs.Init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	Banner = remotes:WaitForChild("Banner") :: RemoteEvent
	DataService.Loaded.Event:Connect(function(player: Player)
		Jobs.Publish(player)
	end)
	for _, p in Players:GetPlayers() do
		Jobs.Publish(p)
	end
	-- the day rolls over while people are playing
	task.spawn(function()
		local day = Progress.Day()
		while true do
			task.wait(30)
			if Progress.Day() ~= day then
				day = Progress.Day()
				for _, p in Players:GetPlayers() do
					Jobs.Publish(p)
				end
			end
		end
	end)
end

return Jobs

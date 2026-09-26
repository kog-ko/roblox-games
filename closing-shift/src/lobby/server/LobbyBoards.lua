--!strict
-- The lobby's leaderboard wall: Employee of the Week, Fastest Shifts (cycling through the nights),
-- Lifetime Earnings and Most Spills Ever. Each board refreshes every Config.LeaderboardRefresh.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Clock = require(ReplicatedStorage.Shared.Clock)
local Progress = require(ReplicatedStorage.Shared.Progress)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Leaderboard = require(script.Parent.Leaderboard)

local LobbyBoards = {}

type Board = { Kind: string, Title: TextLabel?, List: TextLabel? }
local boards: { Board } = {}
local fastestNight = 0
local billboardName: TextLabel? = nil -- the rooftop EMPLOYEE OF THE WEEK billboard (LobbyExtras)

local function format(kind: string, value: number): string
	if kind == "night" then
		return Clock.Duration(value / 10)
	elseif kind == "earnings" then
		return "$" .. value
	end
	return tostring(value)
end

local function refresh(b: Board)
	local arg = nil
	if b.Kind == "night" then
		fastestNight = fastestNight % Rules.NightCount() + 1
		arg = fastestNight
		if b.Title then
			b.Title.Text = "FASTEST SHIFTS: NIGHT " .. fastestNight
		end
	end
	local entries = Leaderboard.Entries(b.Kind, arg)
	if not b.List then
		return
	end
	if not entries then
		b.List.Text = "board offline"
		return
	end
	if b.Kind == "weekly" and billboardName then
		billboardName.Text = if entries[1] then string.upper(entries[1].Name) else "COULD BE YOU"
	end
	local lines = {}
	if b.Kind == "weekly" then
		local left = Progress.WeekEnds(Progress.Week()) - os.time()
		table.insert(lines, string.format("RESETS IN %dD %dH  -  TOP 3 GET A TROPHY", left // 86400, (left % 86400) // 3600))
	end
	for rank, e in entries do
		table.insert(lines, string.format("%2d. %-18s %s", rank, e.Name:sub(1, 18), format(b.Kind, e.Value)))
	end
	if #entries == 0 then
		table.insert(lines, "nobody yet. be the first.")
	end
	b.List.Text = table.concat(lines, "\n")
end

function LobbyBoards.Init(lobby: Instance)
	local folder = lobby:WaitForChild("Boards")
	for _, m in folder:GetChildren() do
		local gui = m:FindFirstChild("BoardGui", true)
		table.insert(boards, {
			Kind = m:GetAttribute("Kind") :: string,
			Title = gui and gui:FindFirstChild("Title") :: TextLabel?,
			List = gui and gui:FindFirstChild("List") :: TextLabel?,
		})
	end
	local bb = lobby:FindFirstChild("WeeklyBillboard", true)
	local gui = bb and bb:FindFirstChild("BillboardGui")
	billboardName = gui and gui:FindFirstChild("Name") :: TextLabel?
	task.spawn(function()
		while true do
			for _, b in boards do
				task.spawn(refresh, b)
			end
			task.wait(Config.LeaderboardRefresh)
		end
	end)
end

return LobbyBoards

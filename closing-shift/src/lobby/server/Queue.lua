--!strict
-- Queue pads. Stand on a pad to join its queue (up to Config.Queue.MaxCrew); step off to leave.
-- Once someone is on a pad a countdown runs (shorter when the pad is full); at zero the crew is
-- sent to a fresh private server of the shift place, with the night in the teleport data.
--   Night pads: everyone on them must have that night unlocked (others see "LOCKED").
--   Quick Play: the best night every player on the pad has unlocked.
-- Players' queue state is published as attributes for the HUD: QueuePad, QueueCount, QueueCountdown.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.Rules)

local Queue = {}

type PadState = {
	Model: Model,
	Pad: BasePart,
	Night: number?,
	Status: TextLabel?,
	Members: { Player },
	EndsAt: number?,
	Busy: boolean, -- teleporting
}

local pads: { PadState } = {}
local cooldown: { [Player]: number } = {} -- after a failed teleport
local Banner: RemoteEvent

local function unlocked(p: Player): number
	local u = p:GetAttribute("Unlocked")
	return if type(u) == "number" then u else 0 -- not loaded yet: can't queue
end

local function onPad(p: Player, pad: BasePart): boolean
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return false
	end
	local rel = pad.CFrame:PointToObjectSpace(root.Position)
	return math.abs(rel.X) <= pad.Size.X / 2 and math.abs(rel.Z) <= pad.Size.Z / 2 and rel.Y > 0 and rel.Y < 8
end

local function nightFor(state: PadState): number
	if state.Night then
		return state.Night
	end
	local n = Rules.NightCount()
	for _, p in state.Members do
		n = math.min(n, unlocked(p))
	end
	return math.max(n, 1)
end

local function setStatus(state: PadState, text: string)
	if state.Status and state.Status.Text ~= text then
		state.Status.Text = text
	end
end

local function publish(p: Player, state: PadState?)
	if state then
		p:SetAttribute("QueuePad", state.Model.Name)
		p:SetAttribute("QueueCount", #state.Members)
		p:SetAttribute("QueueCountdown", if state.EndsAt then math.max(0, math.ceil(state.EndsAt - os.clock())) else nil)
		p:SetAttribute("QueueNight", nightFor(state))
	else
		p:SetAttribute("QueuePad", nil)
		p:SetAttribute("QueueCount", nil)
		p:SetAttribute("QueueCountdown", nil)
		p:SetAttribute("QueueNight", nil)
	end
end

local function launch(state: PadState)
	state.Busy = true
	local crew = table.clone(state.Members)
	local night = nightFor(state)
	setStatus(state, "CLOCKING IN...")
	for _, p in crew do
		p:SetAttribute("QueueCountdown", 0)
	end
	local ok, err = pcall(function()
		if RunService:IsStudio() then
			error("teleports don't run in Studio")
		end
		local code = TeleportService:ReserveServer(Config.Places.Shift)
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = code
		options:SetTeleportData({ Night = night, Crew = #crew })
		TeleportService:TeleportAsync(Config.Places.Shift, crew, options)
	end)
	if not ok then
		warn("[Queue] teleport failed:", err)
		for _, p in crew do
			cooldown[p] = os.clock() + Config.Queue.RetryDelay
			if p.Parent then
				Banner:FireClient(p, if RunService:IsStudio() then "QUEUES WORK IN THE LIVE GAME (NOT IN STUDIO)" else "COULDN'T START THE SHIFT. TRY AGAIN", "Queue")
			end
		end
	end
	-- a crew that did teleport leaves the server; anyone left over can queue again
	task.delay(if ok then 15 else 1, function()
		state.Busy = false
		state.EndsAt = nil
	end)
end

local function tick()
	local now = os.clock()
	local taken: { [Player]: boolean } = {}
	for _, state in pads do
		if state.Busy then
			continue
		end
		-- who is standing on the pad (first come, first served up to the crew size)
		local members = {}
		local locked = 0
		for _, p in state.Members do
			if p.Parent and onPad(p, state.Pad) and (cooldown[p] or 0) < now then
				table.insert(members, p)
			end
		end
		for _, p in Players:GetPlayers() do
			if not table.find(members, p) and onPad(p, state.Pad) and (cooldown[p] or 0) < now then
				if state.Night and unlocked(p) < state.Night then
					locked += 1
				elseif #members < Config.Queue.MaxCrew then
					table.insert(members, p)
				end
			end
		end
		state.Members = members
		for _, p in members do
			taken[p] = true
		end
		if #members == 0 then
			state.EndsAt = nil
			setStatus(state, if locked > 0 then "LOCKED: BEAT THE NIGHT BEFORE" else "STEP ON TO QUEUE")
			continue
		end
		if not state.EndsAt then
			state.EndsAt = now + Config.Queue.Countdown
		end
		if #members >= Config.Queue.MaxCrew then
			state.EndsAt = math.min(state.EndsAt :: number, now + Config.Queue.FullCountdown)
		end
		local left = math.max(0, math.ceil((state.EndsAt :: number) - now))
		local suffix = if state.Night then "" else string.format("  (NIGHT %d)", nightFor(state))
		setStatus(state, string.format("%d/%d  STARTS IN %d%s", #members, Config.Queue.MaxCrew, left, suffix))
		for _, p in members do
			publish(p, state)
		end
		if (state.EndsAt :: number) <= now then
			task.spawn(launch, state)
		end
	end
	for _, p in Players:GetPlayers() do
		if not taken[p] and p:GetAttribute("QueuePad") ~= nil then
			publish(p, nil)
		end
	end
end

function Queue.Init(lobby: Instance)
	Banner = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Banner") :: RemoteEvent
	local folder = lobby:WaitForChild("QueuePads")
	for _, m in folder:GetChildren() do
		if m:IsA("Model") then
			local sign = m:FindFirstChild("Sign")
			local gui = sign and sign:FindFirstChild("SignGui")
			table.insert(pads, {
				Model = m,
				Pad = m:WaitForChild("Pad") :: BasePart,
				Night = m:GetAttribute("Night") :: number?,
				Status = gui and gui:FindFirstChild("Status") :: TextLabel?,
				Members = {},
				EndsAt = nil,
				Busy = false,
			})
		end
	end
	Players.PlayerRemoving:Connect(function(p)
		cooldown[p] = nil
	end)
	task.spawn(function()
		while true do
			tick()
			task.wait(0.25)
		end
	end)
end

-- For tests: the pads' current state.
function Queue.Debug(): { { Pad: string, Members: number, Left: number? } }
	local out = {}
	for _, s in pads do
		table.insert(out, { Pad = s.Model.Name, Members = #s.Members, Left = if s.EndsAt then s.EndsAt - os.clock() else nil })
	end
	return out
end

return Queue

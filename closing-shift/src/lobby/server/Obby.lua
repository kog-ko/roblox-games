--!strict
-- Lobby obbies (built by LobbyExtras): touch a start pad to start the clock, checkpoints save your
-- spot, anything tagged ObbyKill (mop water, the spinning mop, runaway carts) sends you back to it,
-- and the finish pad stops the clock. Each obby pays Config.Obbies[name].Reward once per UTC day,
-- finishing all of them unlocks the Parkour trail, and every finish is announced to the server.
-- Also runs the moving parts (Mover / Spinner tags).
-- The HUD reads ObbyRun (obby name) and ObbyStart (server time) from the player.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Progress = require(ReplicatedStorage.Shared.Progress)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Cosmetics = require(script.Parent.Cosmetics)
local Jobs = require(script.Parent.Jobs)

local Obby = {}

type Run = { obby: string, started: number, checkpoint: CFrame }
local runs: { [Player]: Run } = {}
local starts: { [string]: CFrame } = {}
local lastTouch: { [Player]: number } = {}
local lastKill: { [Player]: number } = {}
local Banner: RemoteEvent

local function playerFrom(hit: BasePart): (Player?, BasePart?)
	local char = hit.Parent
	local p = char and Players:GetPlayerFromCharacter(char)
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return p, root
end

local function above(part: BasePart): CFrame
	return CFrame.new(part.Position + Vector3.new(0, part.Size.Y / 2 + 3, 0))
end

local function stop(p: Player)
	runs[p] = nil
	p:SetAttribute("ObbyRun", nil)
	p:SetAttribute("ObbyStart", nil)
end

local function reward(p: Player, name: string, seconds: number)
	local info = Config.Obbies[name]
	Banner:FireAllClients(string.format("%s CLEARED %s IN %.1fs", string.upper(p.DisplayName), info.Name, seconds), "Obby")
	local prof = DataService.Get(p)
	if not prof or prof.LoadFailed then
		return
	end
	local today = Progress.Day()
	local dayKey = "ObbyDay_" .. name
	local firstToday = (prof.Stats :: any)[dayKey] ~= today
	DataService.Update(p, function(pr)
		local stats = pr.Stats :: any
		stats[dayKey] = today
		stats["ObbyClears_" .. name] = (stats["ObbyClears_" .. name] or 0) + 1
	end)
	if firstToday then
		Economy.AddCash(p, info.Reward, "Obby:" .. name)
		Banner:FireClient(p, string.format("DAILY OBBY BONUS: +$%d", info.Reward), "Obby")
		Jobs.Record(p, "obby", 1)
	end
	-- all obbies cleared at least once: the Parkour trail
	local all = true
	for key in Config.Obbies do
		if ((prof.Stats :: any)["ObbyClears_" .. key] or 0) < 1 then
			all = false
		end
	end
	if all and not prof.Cosmetics.Owned[Config.ObbyTrail] then
		DataService.Update(p, function(pr)
			pr.Cosmetics.Owned[Config.ObbyTrail] = true
		end)
		Cosmetics.Apply(p)
		Banner:FireClient(p, "ALL OBBIES CLEARED: PARKOUR TRAIL UNLOCKED (STYLE)", "Obby")
	end
	task.spawn(DataService.Save, p)
end

local function hook(kind: string, fn: (Player, BasePart, BasePart, string) -> ())
	local function connect(part: Instance)
		if not part:IsA("BasePart") then
			return
		end
		local name = part:GetAttribute("Obby")
		if kind == "ObbyStart" and type(name) == "string" then
			starts[name] = above(part)
		end
		part.Touched:Connect(function(hit)
			local p, root = playerFrom(hit)
			if not p or not root or type(name) ~= "string" then
				return
			end
			local now = os.clock()
			if kind ~= "ObbyKill" and now - (lastTouch[p] or 0) < 0.25 then
				return
			end
			lastTouch[p] = now
			fn(p, root, part, name)
		end)
	end
	for _, part in CollectionService:GetTagged(kind) do
		connect(part)
	end
	CollectionService:GetInstanceAddedSignal(kind):Connect(connect)
end

-- moving parts: Mover slides along Axis by +-Distance/2 over Period seconds; Spinner turns once per Period
local function animate()
	local movers: { { part: BasePart, origin: CFrame, axis: Vector3, dist: number, period: number } } = {}
	for _, p in CollectionService:GetTagged("Mover") do
		if p:IsA("BasePart") then
			local axis = p:GetAttribute("Axis")
			table.insert(movers, {
				part = p, origin = p.CFrame, axis = if typeof(axis) == "Vector3" then axis.Unit else Vector3.xAxis,
				dist = (p:GetAttribute("Distance") or 10) :: number, period = (p:GetAttribute("Period") or 4) :: number,
			})
		end
	end
	local spinners: { { part: BasePart, origin: CFrame, period: number } } = {}
	for _, p in CollectionService:GetTagged("Spinner") do
		if p:IsA("BasePart") then
			table.insert(spinners, { part = p, origin = p.CFrame, period = (p:GetAttribute("Period") or 3) :: number })
		end
	end
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, m in movers do
			m.part.CFrame = m.origin + m.axis * math.sin(t * 2 * math.pi / m.period) * m.dist / 2
		end
		for _, s in spinners do
			s.part.CFrame = s.origin * CFrame.Angles(0, t * 2 * math.pi / s.period, 0)
		end
	end)
end

function Obby.Init()
	Banner = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Banner") :: RemoteEvent
	hook("ObbyStart", function(p, _, part, name)
		runs[p] = { obby = name, started = os.clock(), checkpoint = above(part) }
		p:SetAttribute("ObbyRun", name)
		p:SetAttribute("ObbyStart", workspace:GetServerTimeNow())
	end)
	hook("ObbyCheckpoint", function(p, _, part, name)
		local run = runs[p]
		if run and run.obby == name then
			run.checkpoint = above(part)
		end
	end)
	hook("ObbyKill", function(p, root, part, name)
		-- a short grace after each respawn, and only when really at the hazard (a moved character
		-- can still report stale touches)
		local now = os.clock()
		if now - (lastKill[p] or 0) < 1.5 then
			return
		end
		local rel = part.CFrame:PointToObjectSpace(root.Position)
		local half = part.Size / 2 + Vector3.new(4, 4, 4)
		if math.abs(rel.X) > half.X or math.abs(rel.Y) > half.Y or math.abs(rel.Z) > half.Z then
			return
		end
		lastKill[p] = now
		local run = runs[p]
		local target = if run and run.obby == name then run.checkpoint else starts[name]
		if target then
			root.AssemblyLinearVelocity = Vector3.zero
			p.Character:PivotTo(target)
		end
	end)
	hook("ObbyFinish", function(p, _, _, name)
		local run = runs[p]
		if not run or run.obby ~= name then
			return
		end
		local seconds = os.clock() - run.started
		stop(p)
		reward(p, name, seconds)
	end)
	animate()
	Players.PlayerRemoving:Connect(function(p)
		runs[p] = nil
		lastTouch[p] = nil
		lastKill[p] = nil
	end)
end

return Obby

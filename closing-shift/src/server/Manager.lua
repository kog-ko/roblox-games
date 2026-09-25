--!strict
-- The Night Manager. A tall faceless figure in a suit who walks toward the nearest player, but only
-- while nobody has him on screen with a clear line of sight. In the dark you only "see" him if your
-- flashlight is on him. If he reaches you, you're sent back to the counter and the shift loses time.
--
-- Each client reports its camera CFrame (ViewReport, ~10/s). The server ignores reports that aren't
-- near that player's head or are stale, then checks the view cone and raycasts itself.
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ViewReport = Remotes:WaitForChild("ViewReport") :: UnreliableRemoteEvent
local CaughtRemote = Remotes:WaitForChild("Caught") :: RemoteEvent

local C = Config.Manager
local Manager = {}
-- Set by RoundManager: called with the caught player.
Manager.OnCatch = nil :: ((Player) -> ())?

type View = { cf: CFrame, t: number }
local views: { [Player]: View } = {}
local store: Instance
local model: Model? = nil
local conn: RBXScriptConnection? = nil
local speed = 0
local runId = 0
local waypoints: { Vector3 } = {}
local cooldownUntil = 0
local watchedBy: { string } = {}
local isWatched = false
local walking = false
local sinceCheck = math.huge -- sight checks run ~10x a second, movement every frame

local HEIGHT = 8.4

local function build(): Model
	local m = Instance.new("Model")
	m.Name = "Manager"
	local suit = Color3.fromRGB(28, 28, 32)
	local skin = Color3.fromRGB(200, 196, 186)
	local function block(name: string, size: Vector3, offset: Vector3, color: Color3, mat: Enum.Material?)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Color = color
		p.Size = size
		p.CFrame = CFrame.new(offset)
		p.Parent = m
		return p
	end
	local root = block("Root", Vector3.new(2.2, 0.2, 1.4), Vector3.new(0, 0.1, 0), suit)
	root.Transparency = 1
	block("LeftLeg", Vector3.new(0.8, 3.6, 0.8), Vector3.new(-0.55, 1.8, 0), suit, Enum.Material.Fabric)
	block("RightLeg", Vector3.new(0.8, 3.6, 0.8), Vector3.new(0.55, 1.8, 0), suit, Enum.Material.Fabric)
	block("Torso", Vector3.new(2.3, 2.9, 1.1), Vector3.new(0, 5.05, 0), suit, Enum.Material.Fabric)
	block("Shirt", Vector3.new(0.7, 2.5, 0.05), Vector3.new(0, 5.2, -0.58), Color3.fromRGB(215, 215, 205))
	block("Tie", Vector3.new(0.28, 2.1, 0.06), Vector3.new(0, 5.0, -0.62), Color3.fromRGB(130, 20, 25))
	block("LeftArm", Vector3.new(0.6, 3.6, 0.6), Vector3.new(-1.5, 4.7, 0), suit, Enum.Material.Fabric)
	block("RightArm", Vector3.new(0.6, 3.6, 0.6), Vector3.new(1.5, 4.7, 0), suit, Enum.Material.Fabric)
	block("Neck", Vector3.new(0.5, 0.35, 0.5), Vector3.new(0, 6.65, 0), skin)
	block("Head", Vector3.new(1.3, 1.5, 1.3), Vector3.new(0, 7.6, 0), skin) -- no face, on purpose
	m.PrimaryPart = root
	-- he's heard before he's seen: footsteps only while he moves, and a low hum around him
	local steps = Instance.new("Sound")
	steps.Name = "Steps"
	steps.SoundId = Config.Sounds.ManagerSteps
	steps.Looped = true
	steps.Volume = 0.9
	steps.PlaybackSpeed = 0.85
	steps.RollOffMaxDistance = C.SoundRange
	steps.RollOffMinDistance = 4
	steps.Parent = root
	local hum = Instance.new("Sound")
	hum.Name = "Presence"
	hum.SoundId = Config.Sounds.ManagerPresence
	hum.Looped = true
	hum.Volume = 0.6
	hum.PlaybackSpeed = 0.8
	hum.RollOffMaxDistance = C.SoundRange * 0.9
	hum.RollOffMinDistance = 3
	hum.Parent = root
	hum:Play()
	return m
end

local function pivot(): CFrame
	return (model :: Model):GetPivot()
end

-- Is the Manager on this player's screen with a clear line of sight?
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function canSee(player: Player, view: View, points: { Vector3 }): boolean
	local eye = view.cf.Position
	local look = view.cf.LookVector
	local cosCone = math.cos(math.rad(C.ViewConeDegrees))
	local dark = store:GetAttribute("Power") == false
	local beamCos = math.cos(math.rad(Config.Flashlight.Angle * ((player:GetAttribute("BeamMult") or 1) :: number) / 2 + 5))
	local exclude: { Instance } = { model :: Model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	for _, target in points do
		local to = target - eye
		local dist = to.Magnitude
		if dist < C.ViewDistance and dist > 0.1 then
			local dir = to / dist
			local lit = not dark
				or (player:GetAttribute("FlashlightOn") == true and dist < Config.Flashlight.Range and look:Dot(dir) > beamCos)
			if lit and look:Dot(dir) > cosCone then
				-- glass and other see-through parts don't block the view
				local skip = table.clone(exclude)
				local clear = true
				for _ = 1, 5 do
					rayParams.FilterDescendantsInstances = skip
					local hit = workspace:Raycast(eye, dir * dist, rayParams)
					if not hit then
						break
					end
					if hit.Instance.Transparency > 0.4 then
						table.insert(skip, hit.Instance)
					else
						clear = false
						break
					end
				end
				if clear then
					return true
				end
			end
		end
	end
	return false
end

local function watched(): boolean
	local cf = pivot()
	local points = { cf.Position + Vector3.new(0, 7.6, 0), cf.Position + Vector3.new(0, 5, 0), cf.Position + Vector3.new(0, 1.8, 0) }
	local now = os.clock()
	table.clear(watchedBy)
	for _, p in Players:GetPlayers() do
		local v = views[p]
		if v and now - v.t < C.ReportMaxAge and p:GetAttribute("Caught") ~= true and canSee(p, v, points) then
			table.insert(watchedBy, p.Name)
		end
	end
	return #watchedBy > 0
end

local function nearestTarget(): (Player?, BasePart?)
	local here = pivot().Position
	local best, bestRoot, bestD = nil, nil, math.huge
	for _, p in Players:GetPlayers() do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if r and hum and hum.Health > 0 and p:GetAttribute("Caught") ~= true then
			local d = (r.Position - here).Magnitude
			if d < bestD then
				best, bestRoot, bestD = p, r, d
			end
		end
	end
	return best, bestRoot
end

local function repathLoop(myRun: number)
	local path = PathfindingService:CreatePath({ AgentRadius = 1.8, AgentHeight = HEIGHT, AgentCanJump = false })
	while myRun == runId and model do
		local _, root = nearestTarget()
		if root then
			local from = pivot().Position + Vector3.new(0, 1, 0)
			local ok = pcall(path.ComputeAsync, path, from, root.Position)
			if ok and path.Status == Enum.PathStatus.Success then
				local pts = {}
				for i, w in path:GetWaypoints() do
					if i > 1 then
						table.insert(pts, Vector3.new(w.Position.X, 0, w.Position.Z))
					end
				end
				waypoints = pts
			else
				waypoints = { Vector3.new(root.Position.X, 0, root.Position.Z) } -- fall back to a straight line
			end
		end
		task.wait(C.RepathInterval)
	end
end

local function catch(player: Player)
	print("[Manager] caught", player.Name)
	player:SetAttribute("Caught", true)
	CaughtRemote:FireAllClients(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = true
	end
	if Manager.OnCatch then
		Manager.OnCatch(player)
	end
	-- back to the back room for a moment
	if model then
		model:PivotTo(CFrame.new(C.Spawn))
		waypoints = {}
	end
	cooldownUntil = os.clock() + C.CooldownAfterCatch
	task.delay(C.FreezeTime, function()
		local sp = store:FindFirstChild("SpawnPoint") :: BasePart?
		local char = player.Character
		if char and sp then
			char:PivotTo(sp.CFrame + Vector3.new(0, 3, 0))
		end
		if root and root.Parent then
			root.Anchored = false
		end
		player:SetAttribute("Caught", false)
	end)
end

local function step(dt: number)
	local m = model
	if not m then
		return
	end
	sinceCheck += dt
	if sinceCheck >= 0.1 then
		sinceCheck = 0
		isWatched = watched()
		m:SetAttribute("Watched", isWatched)
	end
	local canMove = not isWatched and os.clock() >= cooldownUntil and #waypoints > 0
	if canMove ~= walking then
		walking = canMove
		local steps = m.PrimaryPart and m.PrimaryPart:FindFirstChild("Steps") :: Sound?
		if steps then
			steps.Playing = canMove
		end
	end
	if not canMove then
		return
	end
	local cf = pivot()
	local pos = cf.Position
	local extra = math.max(0, #Players:GetPlayers() - 1)
	local budget = speed * (1 + C.SpeedPerExtraPlayer * extra) * dt
	while budget > 0 and #waypoints > 0 do
		local target = waypoints[1]
		local to = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
		local d = to.Magnitude
		if d <= budget then
			pos = Vector3.new(target.X, 0, target.Z)
			budget -= d
			table.remove(waypoints, 1)
		else
			pos += to.Unit * budget
			budget = 0
		end
	end
	local p, root = nearestTarget()
	local face = if root then Vector3.new(root.Position.X, 0, root.Position.Z) else pos + cf.LookVector
	if (face - pos).Magnitude > 0.1 then
		m:PivotTo(CFrame.lookAt(pos, face))
	else
		m:PivotTo(CFrame.new(pos) * cf.Rotation)
	end
	if p and root then
		local flat = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z).Magnitude
		if flat < C.CatchDistance then
			catch(p)
		end
	end
end

-- Spawns the Manager for a shift, if the night has one.
function Manager.Start(rules: any)
	Manager.Stop()
	if not rules.Manager.Enabled then
		return
	end
	runId += 1
	local myRun = runId
	speed = rules.Manager.Speed
	cooldownUntil = os.clock() + 5 -- a few seconds' grace at the start of the shift
	isWatched = false
	walking = false
	sinceCheck = math.huge
	local m = build()
	m:PivotTo(CFrame.new(C.Spawn))
	m.Parent = store:FindFirstChild("EventProps")
	model = m
	waypoints = {}
	task.spawn(repathLoop, myRun)
	conn = RunService.Heartbeat:Connect(step)
end

function Manager.Stop()
	runId += 1
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if model then
		model:Destroy()
		model = nil
	end
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Caught") then
			p:SetAttribute("Caught", false)
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				r.Anchored = false
			end
		end
	end
end

-- Playtest helpers.
function Manager.PlaceAt(pos: Vector3)
	if model then
		model:PivotTo(CFrame.new(pos.X, 0, pos.Z))
		waypoints = {}
		cooldownUntil = 0
	end
end

function Manager.Debug(): { [string]: any }
	return {
		Active = model ~= nil,
		Position = if model then pivot().Position else nil,
		Watched = if model then watched() else false,
		WatchedBy = table.clone(watchedBy),
		Speed = speed,
	}
end

-- The last camera view this player reported (for tests), or nil.
function Manager.ViewOf(player: Player): CFrame?
	local v = views[player]
	return v and v.cf
end

function Manager.Init(s: Instance)
	store = s
	ViewReport.OnServerEvent:Connect(function(player, cf)
		if typeof(cf) ~= "CFrame" then
			return
		end
		local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
		if not head or (cf.Position - head.Position).Magnitude > C.ReportMaxOffset then
			return -- not where this player actually is
		end
		views[player] = { cf = cf, t = os.clock() }
	end)
	Players.PlayerRemoving:Connect(function(p)
		views[p] = nil
	end)
end

return Manager

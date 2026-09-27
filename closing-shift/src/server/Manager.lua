--!strict
-- The Night Manager. A tall faceless figure in a suit who walks toward the nearest player, but only
-- while nobody has him on screen with a clear line of sight. In the dark you only "see" him if your
-- flashlight is on him. If he reaches you he grabs you: the camera is pulled round to his face and
-- you get a short skill check (Config.Manager.Grab) to tear free. Break free and he staggers back;
-- fail (or don't try) and it's the usual catch: sent back to the counter and the shift loses time.
-- Failing the check costs nothing extra. Each escape in a shift makes the next check harder.
--
-- Each client reports its camera CFrame (ViewReport, ~10/s). The server ignores reports that aren't
-- near that player's head or are stale, then checks the view cone and raycasts itself.
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ViewReport = Remotes:WaitForChild("ViewReport") :: UnreliableRemoteEvent
local CaughtRemote = Remotes:WaitForChild("Caught") :: RemoteEvent
local GrabRemote = Remotes:WaitForChild("Grab") :: RemoteEvent
local GrabResult = Remotes:WaitForChild("GrabResult") :: RemoteEvent
local Banner = Remotes:WaitForChild("Banner") :: RemoteEvent

local C = Config.Manager
local Manager = {}
-- Set by RoundManager: called with the caught player, and when a catch is undone (Second Chance).
Manager.OnCatch = nil :: ((Player) -> ())?
Manager.OnUndoCatch = nil :: ((Player) -> ())?
Manager.OnEscape = nil :: ((Player) -> ())? -- broke free of a grab

type CatchRecord = { pos: CFrame, t: number, undone: boolean }
local catches: { [Player]: CatchRecord } = {}

type View = { cf: CFrame, t: number }
local views: { [Player]: View } = {}
local store: Instance
local model: Model? = nil
local conn: RBXScriptConnection? = nil
local speed = 0
local baseSpeed = 0
local runId = 0
local waypoints: { Vector3 } = {}
local cooldownUntil = 0
local watchedBy: { string } = {}
local frozenUntil = 0 -- Lights On boost
local isWatched = false
local walking = false
local sinceCheck = math.huge -- sight checks run ~10x a second, movement every frame

-- A grab in progress: the skill check the client was sent, and whether it has been settled.
type Grab = { start: number, window: number, period: number, zones: { number }, width: number, done: boolean }
local grabs: { [Player]: Grab } = {}
local grabbing: Player? = nil

local HEIGHT = 8.4
local rng = Random.new()

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
	-- arms a little too long: they hang to his knees, pale hands with long fingers
	block("LeftArm", Vector3.new(0.6, 4.3, 0.6), Vector3.new(-1.5, 4.35, 0), suit, Enum.Material.Fabric)
	block("RightArm", Vector3.new(0.6, 4.3, 0.6), Vector3.new(1.5, 4.35, 0), suit, Enum.Material.Fabric)
	for _, x in { -1.5, 1.5 } do
		block("Hand", Vector3.new(0.45, 0.7, 0.35), Vector3.new(x, 1.85, 0), skin)
		for f = -1, 1 do
			block("Finger", Vector3.new(0.1, 0.75, 0.1), Vector3.new(x + f * 0.13, 1.15, -0.05), skin)
		end
	end
	-- shoes, lapels and a name badge
	for _, x in { -0.55, 0.55 } do
		block("Shoe", Vector3.new(0.85, 0.35, 1.3), Vector3.new(x, 0.18, -0.2), Color3.fromRGB(12, 12, 12), Enum.Material.SmoothPlastic)
	end
	for _, x in { -0.5, 0.5 } do
		block("Lapel", Vector3.new(0.35, 1.6, 0.06), Vector3.new(x, 5.7, -0.59), Color3.fromRGB(18, 18, 22), Enum.Material.Fabric)
	end
	block("Badge", Vector3.new(0.5, 0.18, 0.04), Vector3.new(0.75, 5.9, -0.6), Color3.fromRGB(200, 170, 80), Enum.Material.Metal)
	block("Neck", Vector3.new(0.5, 0.35, 0.5), Vector3.new(0, 6.65, 0), skin)
	block("Head", Vector3.new(1.3, 1.5, 1.3), Vector3.new(0, 7.6, 0), skin) -- no face, on purpose...
	-- ...until he has you: hollow eyes and a mouth that only show during a grab
	-- (deep sockets with pinprick pupils, and a long gaping mouth)
	for _, f in {
		{ "EyeL", Vector3.new(0.24, 0.3, 0.05), Vector3.new(-0.27, 7.85, -0.66), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic },
		{ "EyeR", Vector3.new(0.24, 0.3, 0.05), Vector3.new(0.27, 7.85, -0.66), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic },
		{ "PupilL", Vector3.new(0.05, 0.05, 0.02), Vector3.new(-0.27, 7.83, -0.69), Color3.fromRGB(255, 240, 220), Enum.Material.Neon },
		{ "PupilR", Vector3.new(0.05, 0.05, 0.02), Vector3.new(0.27, 7.83, -0.69), Color3.fromRGB(255, 240, 220), Enum.Material.Neon },
		{ "Mouth", Vector3.new(0.3, 0.62, 0.05), Vector3.new(0, 7.15, -0.66), Color3.fromRGB(8, 0, 0), Enum.Material.SmoothPlastic },
	} do
		local fp = block(f[1], f[2], f[3], f[4], f[5])
		fp.Transparency = 1
		fp:AddTag("ManagerFace")
	end
	m.PrimaryPart = root
	-- he's heard before he's seen: footsteps only while he moves, and a low hum around him
	local steps = Instance.new("Sound")
	steps.Name = "Steps"
	steps.SoundId = Config.Sounds.ManagerSteps
	steps.Looped = true
	steps.Volume = 1.3
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
	local here = player.Character and player.Character:GetPivot() or CFrame.new()
	local record: CatchRecord = { pos = here, t = os.clock(), undone = false }
	catches[player] = record
	player:SetAttribute("Caught", true)
	player:SetAttribute("CaughtAt", workspace:GetServerTimeNow())
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
		model:PivotTo(CFrame.new(Layout.Map(C.Spawn)))
		waypoints = {}
	end
	cooldownUntil = os.clock() + C.CooldownAfterCatch
	task.delay(C.FreezeTime, function()
		if record.undone then
			return -- Second Chance already put them back
		end
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

local function showFace(on: boolean)
	if model then
		for _, d in (model :: Model):GetChildren() do
			if d:HasTag("ManagerFace") and d:IsA("BasePart") then
				d.Transparency = if on then 0 else 1
			end
		end
	end
end

-- Settles a grab: tore free (escaped) or caught as usual.
local function resolve(player: Player, escaped: boolean)
	local g = grabs[player]
	if not g or g.done then
		return
	end
	g.done = true
	grabs[player] = nil
	if grabbing == player then
		grabbing = nil
	end
	showFace(false)
	player:SetAttribute("Grabbed", nil)
	if not escaped then
		catch(player)
		return
	end
	-- broke free: shove apart, he staggers and waits a moment
	player:SetAttribute("Escapes", ((player:GetAttribute("Escapes") or 0) :: number) + 1)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = false
		if model then
			local away = root.Position - pivot().Position
			away = Vector3.new(away.X, 0, away.Z)
			if away.Magnitude > 0.01 then
				root.AssemblyLinearVelocity = away.Unit * 45 + Vector3.new(0, 18, 0)
				local back = pivot().Position - away.Unit * 3
				(model :: Model):PivotTo(CFrame.lookAt(Vector3.new(back.X, 0, back.Z), Vector3.new(root.Position.X, 0, root.Position.Z)))
			end
		end
	end
	waypoints = {}
	cooldownUntil = math.max(cooldownUntil, os.clock() + C.Grab.EscapeStun)
	Banner:FireAllClients(string.upper(player.DisplayName) .. " BROKE FREE", "Escape")
	if Manager.OnEscape then
		Manager.OnEscape(player)
	end
end

-- He's reached someone: pin them and send them the skill check.
local function grab(player: Player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local m = model
	if not root or not m or grabs[player] then
		return
	end
	local G = C.Grab
	local escapes = (player:GetAttribute("Escapes") or 0) :: number
	local width = math.max(G.MinZone, G.Zone - G.ZoneShrink * escapes)
	local zones = {}
	for _ = 1, G.Hits do
		table.insert(zones, rng:NextNumber(0.12, 0.88 - width))
	end
	local g: Grab = {
		start = workspace:GetServerTimeNow() + G.Intro,
		window = G.Window,
		period = math.max(G.MinPeriod, G.Period - G.PeriodShrink * escapes),
		zones = zones,
		width = width,
		done = false,
	}
	grabs[player] = g
	grabbing = player
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	-- step in close, face to face
	local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
	local from = pivot().Position
	local dir = flat - from
	dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.zAxis
	local stand = flat - dir * 3.3
	m:PivotTo(CFrame.lookAt(stand, flat))
	showFace(true)
	local steps = m.PrimaryPart and m.PrimaryPart:FindFirstChild("Steps") :: Sound?
	if steps then
		steps.Playing = false
	end
	walking = false
	player:SetAttribute("Grabbed", true)
	GrabRemote:FireClient(player, { Start = g.start, Window = g.window, Period = g.period, Zones = g.zones, Width = g.width })
	task.delay(G.Intro + G.Window + 0.6, function()
		resolve(player, false) -- ran out of time
	end)
end

-- Where the skill-check needle is (0..1) at server time t: it sweeps back and forth.
local function needle(g: Grab, t: number): number
	local x = ((t - g.start) / g.period) % 2
	return if x < 1 then x else 2 - x
end

-- The client's presses (server times). Every press has to land in the next zone, in order, inside
-- the window; one miss and it's over.
local function judge(player: Player, presses: any)
	local g = grabs[player]
	if not g or g.done or type(presses) ~= "table" or #presses > 8 then
		return
	end
	local now = workspace:GetServerTimeNow()
	local hits = 0
	local last = g.start - 0.05
	for _, t in presses do
		if type(t) ~= "number" or t ~= t or t < last or t > now + 0.05 or t > g.start + g.window + 0.25 then
			resolve(player, false)
			return
		end
		last = t
		local z = g.zones[hits + 1]
		local x = needle(g, t)
		if z and x >= z - 0.03 and x <= z + g.width + 0.03 then
			hits += 1
			if hits >= #g.zones then
				resolve(player, true)
				return
			end
		else
			resolve(player, false)
			return
		end
	end
end

local function step(dt: number)
	local m = model
	if not m or grabbing then
		return -- busy with someone
	end
	sinceCheck += dt
	if sinceCheck >= 0.1 then
		sinceCheck = 0
		isWatched = watched()
		m:SetAttribute("Watched", isWatched)
	end
	local canMove = not isWatched and os.clock() >= cooldownUntil and os.clock() >= frozenUntil and #waypoints > 0
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
			grab(p)
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
	baseSpeed = rules.Manager.Speed
	speed = baseSpeed
	cooldownUntil = os.clock() + 5 -- a few seconds' grace at the start of the shift
	isWatched = false
	walking = false
	frozenUntil = 0
	sinceCheck = math.huge
	grabbing = nil
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Escapes", nil)
	end
	local m = build()
	m:PivotTo(CFrame.new(Layout.Map(C.Spawn)))
	m.Parent = store:FindFirstChild("EventProps")
	model = m
	waypoints = {}
	task.spawn(repathLoop, myRun)
	conn = RunService.Heartbeat:Connect(step)
end

function Manager.Stop()
	runId += 1
	for p, g in grabs do
		g.done = true
		p:SetAttribute("Grabbed", nil)
	end
	table.clear(grabs)
	grabbing = nil
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

-- Second Chance: undoes this player's latest catch if it was recent enough. They're put back where
-- they were caught (no respawn) and the lost time is returned (OnUndoCatch).
function Manager.UndoCatch(player: Player, window: number): boolean
	local rec = catches[player]
	if not rec or rec.undone or os.clock() - rec.t > window then
		return false
	end
	rec.undone = true
	local char = player.Character
	if char then
		char:PivotTo(rec.pos)
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.Anchored = false
		end
	end
	player:SetAttribute("Caught", false)
	player:SetAttribute("CaughtAt", nil)
	if Manager.OnUndoCatch then
		Manager.OnUndoCatch(player)
	end
	-- give them a moment before he can move again
	cooldownUntil = math.max(cooldownUntil, os.clock() + C.CooldownAfterCatch)
	return true
end

-- Overtime: he gets faster every "hour" (1 = the night's speed).
function Manager.SetSpeedMult(mult: number)
	speed = baseSpeed * mult
end

-- Lights On boost: he can't move for this long.
function Manager.Freeze(seconds: number)
	frozenUntil = math.max(frozenUntil, os.clock() + seconds)
end

function Manager.IsActive(): boolean
	return model ~= nil
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
	GrabResult.OnServerEvent:Connect(judge)
	ViewReport.OnServerEvent:Connect(function(player, cf)
		if typeof(cf) ~= "CFrame" then
			return
		end
		local last = views[player]
		if last and os.clock() - last.t < C.ReportMinInterval then
			return -- clients report ~10 times a second; ignore anything faster
		end
		local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
		local offset = if head then (cf.Position - head.Position).Magnitude else math.huge
		local look = cf.LookVector
		-- "not <=" also rejects NaN, which would slip past a plain ">" check
		if not (offset <= C.ReportMaxOffset) or look.X ~= look.X or look.Y ~= look.Y or look.Z ~= look.Z then
			return -- not where this player actually is, or not a real view
		end
		views[player] = { cf = cf, t = os.clock() }
	end)
	Players.PlayerRemoving:Connect(function(p)
		views[p] = nil
		catches[p] = nil
		local g = grabs[p]
		if g then
			g.done = true
			grabs[p] = nil
			if grabbing == p then
				grabbing = nil
				showFace(false)
			end
		end
	end)
end

return Manager

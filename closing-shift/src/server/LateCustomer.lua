--!strict
-- The rare one: THE LATE CUSTOMER. Some nights (Config.LateCustomer.Chance, from MinNight on), a
-- while into the shift, the door chimes and someone walks in. We're closed. A tall figure in a
-- wet coat and hood, pale eyes, a shopping basket. It drifts between the aisles, tracking mess in
-- behind it, and heads for whoever is nearest.
--   Look at it (on screen, in the light if the power's out) for StareTime seconds in total and it
--   flickers out, leaving a tip for everyone who looked.
--   Let it reach you and it "checks you out": your flashlight dies for JamTime seconds and your
--   bodycam scrambles. No catch, no time lost. Then it's gone.
--   Ignore it long enough and it leaves the way it came.
-- Players' views come from the Manager's ViewReport (clients report while either is in the store).
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local SpillService = require(script.Parent.SpillService)
local Manager = require(script.Parent.Manager)
local Economy = require(script.Parent.Economy)
local Achievements = require(script.Parent.Achievements)

local C = Config.LateCustomer
local LateCustomer = {}
local store: Instance
local runId = 0
local model: Model? = nil
local rng = Random.new()
local Banner: RemoteEvent

local OUTSIDE = Layout.Map(Vector3.new(7, 0, 28)) -- through the front door
local INSIDE = Layout.Map(Vector3.new(7, 0, 15))

local function build(): Model
	local m = Instance.new("Model")
	m.Name = "LateCustomer"
	local coat = Color3.fromRGB(24, 26, 30)
	local function block(name: string, size: Vector3, offset: Vector3, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = true
		p.Material = mat or Enum.Material.Fabric
		p.Color = color
		p.Size = size
		if shape then
			p.Shape = shape
		end
		p.CFrame = CFrame.new(offset)
		p.Parent = m
		return p
	end
	local root = block("Root", Vector3.new(2, 0.2, 1.2), Vector3.new(0, 0.1, 0), coat)
	root.Transparency = 1
	block("LeftLeg", Vector3.new(0.6, 3.4, 0.6), Vector3.new(-0.4, 1.7, 0), Color3.fromRGB(18, 18, 20))
	block("RightLeg", Vector3.new(0.6, 3.4, 0.6), Vector3.new(0.4, 1.7, 0), Color3.fromRGB(18, 18, 20))
	block("Coat", Vector3.new(2.1, 4.2, 1.2), Vector3.new(0, 4.3, 0), coat, Enum.Material.Plastic).Reflectance = 0.08 -- wet
	block("LeftArm", Vector3.new(0.5, 3.9, 0.5), Vector3.new(-1.3, 4.3, 0.1), coat)
	block("RightArm", Vector3.new(0.5, 3.9, 0.5), Vector3.new(1.3, 4.3, 0.1), coat)
	block("Hood", Vector3.new(1.5, 1.7, 1.5), Vector3.new(0, 7.2, 0.1), coat)
	block("Face", Vector3.new(1.1, 1.2, 0.1), Vector3.new(0, 7.05, -0.66), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	for _, x in { -0.25, 0.25 } do
		local eye = block("Eye", Vector3.new(0.16, 0.16, 0.05), Vector3.new(x, 7.2, -0.72), Color3.fromRGB(220, 230, 215), Enum.Material.Neon)
		eye.CastShadow = false
	end
	-- a basket with one thing in it
	block("Basket", Vector3.new(1.2, 0.8, 0.9), Vector3.new(1.35, 2.2, -0.2), Color3.fromRGB(170, 30, 30), Enum.Material.Plastic)
	block("Milk", Vector3.new(0.45, 0.8, 0.45), Vector3.new(1.3, 2.7, -0.2), Color3.fromRGB(235, 235, 230), Enum.Material.Plastic)
	m.PrimaryPart = root
	local drip = Instance.new("Sound")
	drip.Name = "Drip"
	drip.SoundId = Config.Sounds.Splash
	drip.Volume = 0.4
	drip.PlaybackSpeed = 0.6
	drip.Looped = true
	drip.RollOffMaxDistance = 30
	drip.Parent = root
	drip:Play()
	return m
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
-- Is it on this player's screen, lit, with nothing solid in between?
local function seenBy(player: Player, at: Vector3): boolean
	local view = Manager.ViewOf(player)
	if not view then
		return false
	end
	local to = at - view.Position
	local d = to.Magnitude
	if d > 60 or d < 0.1 then
		return false
	end
	local dir = to / d
	if view.LookVector:Dot(dir) < math.cos(math.rad(32)) then
		return false
	end
	if store:GetAttribute("Power") == false and not (player:GetAttribute("FlashlightOn") == true and d < Config.Flashlight.Range) then
		return false
	end
	local exclude: { Instance } = { model :: Model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(view.Position, dir * d, rayParams)
	return hit == nil or hit.Instance.Transparency > 0.4
end

local function nearestRoot(from: Vector3): (Player?, BasePart?)
	local best, bestRoot, bestD = nil, nil, math.huge
	for _, p in Players:GetPlayers() do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and p:GetAttribute("Caught") ~= true then
			local d = (r.Position - from).Magnitude
			if d < bestD then
				best, bestRoot, bestD = p, r, d
			end
		end
	end
	return best, bestRoot
end

local function vanish(m: Model)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		elseif d:IsA("Sound") then
			d:Stop()
		end
	end
	task.delay(0.1, function()
		m:Destroy()
	end)
end

local function visit(myRun: number)
	local m = build()
	m:PivotTo(CFrame.lookAt(OUTSIDE, INSIDE))
	m.Parent = store:FindFirstChild("EventProps")
	model = m
	local bell = CollectionService:GetTagged("DoorChime")[1]
	if bell and bell:IsA("BasePart") then
		local s = Instance.new("Sound")
		s.SoundId = Config.Sounds.Chime
		s.Volume = 1
		s.PlaybackSpeed = 0.8
		s.RollOffMaxDistance = 120
		s.Parent = bell
		s:Play()
		task.delay(6, function()
			s:Destroy()
		end)
	end
	Banner:FireAllClients("SOMEONE JUST WALKED IN. WE'RE CLOSED.", "Rare")

	local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 8, AgentCanJump = false })
	local waypoints: { Vector3 } = { INSIDE }
	local stare: { [Player]: number } = {}
	local seenOnce: { [Player]: boolean } = {}
	local stareTotal = 0
	local started = os.clock()
	local lastRepath = 0
	local lastMess = os.clock()
	local messes = 0
	local leaving = false
	local done = false
	local conn: RBXScriptConnection
	local function finish()
		done = true
		conn:Disconnect()
		if model == m then
			model = nil
		end
	end
	conn = RunService.Heartbeat:Connect(function(dt)
		if done then
			return
		end
		if myRun ~= runId or not m.Parent then
			finish()
			vanish(m)
			return
		end
		local cf = m:GetPivot()
		local here = Vector3.new(cf.Position.X, 0, cf.Position.Z) -- (the pivot bobs; walk on the floor)
		local eyes = here + Vector3.new(0, 7, 0)

		-- being looked at: stare time adds up across everyone
		local watched = false
		for _, p in Players:GetPlayers() do
			if seenBy(p, eyes) or seenBy(p, here + Vector3.new(0, 4, 0)) then
				watched = true
				stare[p] = (stare[p] or 0) + dt
				stareTotal += dt / math.max(1, #Players:GetPlayers() * 0.6)
				if not seenOnce[p] then
					seenOnce[p] = true
					task.spawn(Achievements.Add, p, "RareSeen")
				end
			end
		end
		for _, d in m:GetChildren() do
			if d.Name == "Eye" and d:IsA("BasePart") then
				d.Color = Color3.fromRGB(220, 230, 215):Lerp(Color3.fromRGB(255, 60, 50), math.clamp(stareTotal / C.StareTime, 0, 1))
			end
		end
		if stareTotal >= C.StareTime then
			finish()
			Banner:FireAllClients("IT'S GONE. IT LEFT A TIP.", "Rare")
			for p, t in stare do
				if t > 0.5 and p.Parent then
					p:SetAttribute("LateCustomerResult", "banished")
					Economy.AddCash(p, C.Tip, "LateCustomerTip")
					task.spawn(Achievements.Add, p, "RareBanished")
				end
			end
			vanish(m)
			return
		end

		-- where to: the nearest player, until it's been here long enough, then out the door
		if not leaving and os.clock() - started > C.MaxTime then
			leaving = true
			waypoints = { INSIDE, OUTSIDE }
		end
		if not leaving and os.clock() - lastRepath > 1 then
			lastRepath = os.clock()
			local _, root = nearestRoot(here)
			if root then
				local ok = pcall(path.ComputeAsync, path, here + Vector3.new(0, 1, 0), root.Position)
				if ok and path.Status == Enum.PathStatus.Success then
					local pts = {}
					for i, w in path:GetWaypoints() do
						if i > 1 then
							table.insert(pts, Vector3.new(w.Position.X, 0, w.Position.Z))
						end
					end
					waypoints = pts
				end
			end
		end

		-- it slows right down while someone's looking, and drips as it goes
		local speed = if watched then C.Speed * 0.25 else C.Speed
		local budget = speed * dt
		local pos = here
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
		local step = pos - here
		if step.Magnitude > 0.001 then
			local bob = math.sin(os.clock() * 7) * 0.08
			m:PivotTo(CFrame.lookAt(pos, pos + step.Unit) * CFrame.new(0, math.abs(bob), 0))
		end
		if leaving and #waypoints == 0 then
			finish()
			vanish(m)
			return
		end
		if not leaving and messes < C.MaxMess and os.clock() - lastMess > C.MessEvery and SpillService.CanAddSpills() then
			lastMess = os.clock()
			messes += 1
			SpillService.Spawn(pos - (if step.Magnitude > 0.001 then step.Unit else Vector3.zero) * 2)
		end

		-- reached someone: jam their light, then it's gone
		local p, root = nearestRoot(pos)
		if p and root and Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z).Magnitude < C.ReachDistance then
			finish()
			p:SetAttribute("JammedUntil", workspace:GetServerTimeNow() + C.JamTime)
			p:SetAttribute("LateCustomerResult", "reached")
			p:SetAttribute("FlashlightOn", false)
			Banner:FireClient(p, "\"...CAN I CHECK OUT?\"", "Rare")
			vanish(m)
		end
	end)
end

-- Called at the start of every shift.
function LateCustomer.Start(rules: any)
	LateCustomer.Stop()
	runId += 1
	local myRun = runId
	local chance = if rules.LateCustomer then 1 elseif rules.Night >= C.MinNight then C.Chance else 0
	if RunService:IsStudio() and workspace:GetAttribute("ForceLateCustomer") then
		chance = 1
	end
	if rng:NextNumber() >= chance then
		return
	end
	local delay = rng:NextNumber(C.Delay.Min, math.min(C.Delay.Max, rules.ShiftLength * 0.6))
	if RunService:IsStudio() and workspace:GetAttribute("ForceLateCustomer") then
		delay = 3
	end
	task.delay(delay, function()
		if myRun == runId then
			visit(myRun)
		end
	end)
end

function LateCustomer.Stop()
	runId += 1
	if model then
		model:Destroy()
		model = nil
	end
end

function LateCustomer.IsHere(): boolean
	return model ~= nil
end

function LateCustomer.Init(s: Instance)
	store = s
	Banner = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Banner") :: RemoteEvent
end

return LateCustomer

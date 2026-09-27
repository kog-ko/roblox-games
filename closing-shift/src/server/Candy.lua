--!strict
-- Event candy (the running Data/Seasons event's currency, saved as the profile's Candy). During a
-- shift a handful of wrapped sweets are hidden around the open parts of the store; walk into one
-- to pick it up. Clearing a night and lasting in Overtime pay some too (RoundManager), and the
-- jack-o'-lantern scare drops a few (Events/Pumpkin). Spent in the wardrobe (Cosmetics.lua).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Season = require(ReplicatedStorage.Shared.Season)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Achievements = require(script.Parent.Achievements)

local Candy = {}
local store: Instance
local folder: Folder
local rng = Random.new()
local COLORS = { Color3.fromRGB(255, 140, 30), Color3.fromRGB(150, 70, 220), Color3.fromRGB(90, 220, 90), Color3.fromRGB(240, 60, 60) }

-- Gives a player candy (only while an event runs). Returns how much was given.
function Candy.Add(player: Player, amount: number): number
	if amount <= 0 or not Season.Current() then
		return 0
	end
	local prof = DataService.Get(player)
	if not prof or prof.LoadFailed then
		return 0
	end
	DataService.Update(player, function(p)
		p.Candy += amount
		local stats = p.Stats :: any
		stats.CandyTotal = ((stats.CandyTotal or 0) :: number) + amount
	end)
	player:SetAttribute("Candy", prof.Candy)
	Achievements.Check(player)
	return amount
end

local function sweet(pos: Vector3, amount: number): Model
	local m = Instance.new("Model")
	m.Name = "Candy"
	local color = COLORS[rng:NextInteger(1, #COLORS)]
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(0.9, 0.9, 0.9)
	body.Material = Enum.Material.Neon
	body.Color = color
	body.Anchored = true
	body.CanCollide = false
	body.CastShadow = false
	body.CFrame = CFrame.new(pos)
	body.Parent = m
	for _, side in { -1, 1 } do
		local twist = Instance.new("WedgePart")
		twist.Name = "Wrapper"
		twist.Size = Vector3.new(0.1, 0.7, 0.6)
		twist.Material = Enum.Material.SmoothPlastic
		twist.Color = color:Lerp(Color3.new(1, 1, 1), 0.4)
		twist.Anchored = true
		twist.CanCollide = false
		twist.CanTouch = false
		twist.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(90 * side), 0) * CFrame.new(0, 0, 0.7) * CFrame.Angles(0, 0, math.rad(90))
		twist.Parent = m
	end
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 6
	glow.Brightness = 0.8
	glow.Parent = body
	m.PrimaryPart = body
	m:SetAttribute("Amount", amount)
	m:SetAttribute("Base", pos)
	local taken = false
	body.Touched:Connect(function(hit)
		local p = Players:GetPlayerFromCharacter(hit.Parent)
		if taken or not p then
			return
		end
		taken = true
		local s = Instance.new("Sound")
		s.SoundId = Config.Sounds.CandyPickup
		s.Volume = 0.7
		s.PlaybackSpeed = 1.3
		s.Parent = body
		s:Play()
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 1
			end
		end
		local got = Candy.Add(p, amount)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local banner = remotes and remotes:FindFirstChild("Banner") :: RemoteEvent?
		if banner and got > 0 then
			banner:FireClient(p, string.format("+%d %s", got, (Season.Current() or {}).Currency or "CANDY"), "Candy")
		end
		task.delay(1, function()
			m:Destroy()
		end)
	end)
	m.Parent = folder
	return m
end

-- Drops candy at a spot (the jack-o'-lantern). amount pieces, one candy each.
function Candy.Drop(pos: Vector3, pieces: number)
	if not Season.Current() then
		return
	end
	for _ = 1, pieces do
		local off = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		sweet(Vector3.new(pos.X, 1.2, pos.Z) + off, 1)
	end
end

-- Hides this shift's candy around the open zones (spill markers are the "somewhere on the floor"
-- spots every store has).
function Candy.StartShift(openZones: { [string]: boolean })
	Candy.Clear()
	local s = Season.Current()
	if not s then
		return
	end
	local markers = {}
	for _, m in (store:FindFirstChild("SpillMarkers") :: Instance):GetChildren() do
		local zone = m:GetAttribute("Zone")
		if m:IsA("BasePart") and openZones[if type(zone) == "string" then zone else "Floor"] then
			table.insert(markers, m)
		end
	end
	for i = #markers, 2, -1 do
		local j = rng:NextInteger(1, i)
		markers[i], markers[j] = markers[j], markers[i]
	end
	for i = 1, math.min(s.CandyPerShift, #markers) do
		local p = (markers[i] :: BasePart).Position
		sweet(Vector3.new(p.X + rng:NextNumber(-3, 3), 1.2, p.Z + rng:NextNumber(-3, 3)), rng:NextInteger(1, 3))
	end
end

function Candy.Clear()
	if folder then
		folder:ClearAllChildren()
	end
end

function Candy.Init(s: Instance)
	store = s
	folder = Instance.new("Folder")
	folder.Name = "EventCandy"
	folder.Parent = s
	-- a gentle bob and spin so they catch the eye (and the flashlight)
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, m in folder:GetChildren() do
			local base = m:GetAttribute("Base")
			if m:IsA("Model") and typeof(base) == "Vector3" then
				m:PivotTo(CFrame.new(base + Vector3.new(0, math.sin(t * 2 + base.X) * 0.25, 0)) * CFrame.Angles(0, t * 1.5, 0))
			end
		end
	end)
end

return Candy

--!strict
-- Server-wide boosts bought from the shop during a shift. Each is announced with a banner that
-- names the buyer. Boosts are spaced by a cooldown; one bought during the cooldown waits its turn,
-- and one that completes after the shift ended waits for the next shift (nobody pays for nothing).
--   LightsOn       every light on for 60s and the Manager frozen
--   HireJanitor    an NPC walks over and cleans 3 spills (credited to the buyer)
--   SpillStorm     5 more spills (more paycheck for everyone)
--   ManagerDayOff  no Manager for the rest of the night
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local EventDirector = require(script.Parent.EventDirector)
local Manager = require(script.Parent.Manager)
local SpillService = require(script.Parent.SpillService)

local Banner = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Banner") :: RemoteEvent
local R = Config.Monetization.Rewards

local ServerBoosts = {}
-- Hook for analytics: (key, buyer) when a boost actually fires.
ServerBoosts.OnApplied = nil :: ((string, Player?) -> ())?

local store: Instance
local queue: { { key: string, buyer: Player? } } = {}
local nextFree = 0 -- os.clock() when the next boost may fire
local dayOff = false

local MESSAGES = {
	LightsOn = "%s TURNED THE LIGHTS ON!",
	HireJanitor = "%s HIRED A JANITOR!",
	SpillStorm = "%s CAUSED A SPILL STORM!",
	ManagerDayOff = "%s GAVE THE MANAGER THE NIGHT OFF!",
}

local function janitor(buyer: Player?)
	local spills = SpillService.FloorSpills()
	local m = Instance.new("Model")
	m.Name = "Janitor"
	local function block(size: Vector3, offset: Vector3, color: Color3)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Size = size
		p.Color = color
		p.CFrame = CFrame.new(offset)
		p.Parent = m
		return p
	end
	local root = block(Vector3.new(1, 0.2, 1), Vector3.new(0, 0.1, 0), Color3.new())
	root.Transparency = 1
	block(Vector3.new(0.7, 2.6, 0.7), Vector3.new(-0.4, 1.3, 0), Color3.fromRGB(50, 60, 90))
	block(Vector3.new(0.7, 2.6, 0.7), Vector3.new(0.4, 1.3, 0), Color3.fromRGB(50, 60, 90))
	block(Vector3.new(1.8, 2.2, 1), Vector3.new(0, 3.7, 0), Color3.fromRGB(240, 130, 30)) -- hi-vis vest
	block(Vector3.new(1.1, 1.1, 1.1), Vector3.new(0, 5.4, 0), Color3.fromRGB(200, 170, 140))
	block(Vector3.new(0.25, 4.5, 0.25), Vector3.new(1.2, 2.6, -0.4), Color3.fromRGB(120, 90, 60)) -- mop
	m.PrimaryPart = root
	local sp = store:FindFirstChild("SpawnPoint") :: BasePart
	local pos = Vector3.new(sp.Position.X, 0, sp.Position.Z)
	m:PivotTo(CFrame.new(pos))
	m.Parent = store:FindFirstChild("EventProps")
	local cleaned = 0
	for _, spill in spills do
		if cleaned >= R.JanitorSpills or not m.Parent then
			break
		end
		local anchor = spill:FindFirstChild("PromptAnchor") :: BasePart?
		if anchor then
			local target = Vector3.new(anchor.Position.X, 0, anchor.Position.Z)
			local from = pos
			local dist = (target - from).Magnitude
			local t, dur = 0, math.clamp(dist / 20, 0.4, 2.5)
			while t < dur and m.Parent do
				t += task.wait()
				pos = from:Lerp(target, math.min(1, t / dur))
				if (target - pos).Magnitude > 0.05 then
					m:PivotTo(CFrame.lookAt(pos, target))
				end
			end
			task.wait(0.6) -- a quick scrub
			if buyer and buyer.Parent and SpillService.CleanForPlayer(spill, buyer) then
				cleaned += 1
			elseif not buyer or not buyer.Parent then
				-- the buyer left: the janitor still cleans, credited to whoever is nearest
				local nearest = Players:GetPlayers()[1]
				if nearest and SpillService.CleanForPlayer(spill, nearest) then
					cleaned += 1
				end
			end
		end
	end
	task.wait(1)
	m:Destroy()
end

local function apply(key: string, buyer: Player?)
	local name = if buyer then string.upper(buyer.DisplayName) else "SOMEONE"
	Banner:FireAllClients(string.format(MESSAGES[key] or "%s BOUGHT A BOOST!", name), key)
	if key == "LightsOn" then
		EventDirector.ForcePowerOn(R.LightsOnSeconds)
		Manager.Freeze(R.LightsOnSeconds)
	elseif key == "HireJanitor" then
		task.spawn(janitor, buyer)
	elseif key == "SpillStorm" then
		SpillService.SpawnExtra(R.SpillStormSpills)
	elseif key == "ManagerDayOff" then
		dayOff = true
		Manager.Stop()
	end
	if ServerBoosts.OnApplied then
		ServerBoosts.OnApplied(key, buyer)
	end
end

local function pump()
	while #queue > 0 do
		if ReplicatedStorage:GetAttribute("Phase") ~= "Shift" then
			return -- wait for the next shift
		end
		local waitFor = nextFree - os.clock()
		if waitFor > 0 then
			ReplicatedStorage:SetAttribute("BoostCooldownUntil", workspace:GetServerTimeNow() + waitFor)
			task.wait(waitFor)
			continue
		end
		local item = table.remove(queue, 1) :: { key: string, buyer: Player? }
		nextFree = os.clock() + R.ServerBoostCooldown
		ReplicatedStorage:SetAttribute("BoostCooldownUntil", workspace:GetServerTimeNow() + R.ServerBoostCooldown)
		apply(item.key, item.buyer)
	end
end

local pumping = false
local function kick()
	if pumping then
		return
	end
	pumping = true
	task.spawn(function()
		pump()
		pumping = false
	end)
end

-- Queues a paid boost. It fires as soon as the shift is running and the cooldown allows.
function ServerBoosts.Grant(key: string, buyer: Player?)
	table.insert(queue, { key = key, buyer = buyer })
	kick()
end

function ServerBoosts.IsBoost(key: string): boolean
	return MESSAGES[key] ~= nil
end

-- Whether buying this boost right now makes sense (the shop greys it out otherwise).
function ServerBoosts.CanOffer(key: string): (boolean, string?)
	if ReplicatedStorage:GetAttribute("Phase") ~= "Shift" then
		return false, "SHIFT ONLY"
	end
	if key == "ManagerDayOff" and (dayOff or not Manager.IsActive()) then
		return false, "NO MANAGER TONIGHT"
	end
	if key == "SpillStorm" and SpillService.IsFinalPhase() then
		return false, "TOO LATE"
	end
	if key == "HireJanitor" and #SpillService.FloorSpills() == 0 then
		return false, "NOTHING TO CLEAN"
	end
	return true, nil
end

-- Called by RoundManager at the start of each shift.
function ServerBoosts.OnShiftStart()
	dayOff = false
	kick()
end

function ServerBoosts.IsDayOff(): boolean
	return dayOff
end

function ServerBoosts.Init(s: Instance)
	store = s
end

return ServerBoosts

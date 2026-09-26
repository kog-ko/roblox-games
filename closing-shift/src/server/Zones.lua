--!strict
-- Bigger crews get a bigger store. Each shift the store opens the zones its crew size unlocks
-- (Config.Zones): the roll-up stockroom door and the walk-in freezer door slide up out of the way,
-- and spills can spawn there. Between shifts every door comes back down.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)

local Zones = {}

local DOORS = { Stockroom = "StockroomDoor", Freezer = "FreezerDoor" }

-- The zones a crew of this size plays in, e.g. { Floor = true, Stockroom = true }.
function Zones.For(crew: number): { [string]: boolean }
	local open = {}
	for zone, minCrew in Config.Zones do
		if crew >= minCrew then
			open[zone] = true
		end
	end
	return open
end

local function setDoor(store: Instance, zone: string, open: boolean)
	local door = store:FindFirstChild(DOORS[zone] or "", true)
	if not (door and door:IsA("BasePart")) then
		return
	end
	local closed = door:GetAttribute("ClosedCFrame")
	if typeof(closed) ~= "CFrame" then
		return
	end
	local goal = if open then closed + Vector3.new(0, door.Size.Y - 0.5, 0) else closed
	door.CanCollide = not open
	TweenService:Create(door, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { CFrame = goal }):Play()
end

-- Opens what this crew unlocks (and closes the rest). Returns the open zones.
function Zones.Apply(store: Instance, crew: number): { [string]: boolean }
	local open = Zones.For(crew)
	for zone in DOORS do
		setDoor(store, zone, open[zone] == true)
	end
	local names = {}
	for _, zone in { "Stockroom", "Freezer" } do
		if open[zone] then
			table.insert(names, string.upper(zone))
		end
	end
	store:SetAttribute("OpenZones", table.concat(names, ","))
	if #names > 0 then
		local banner = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Banner")
		if banner then
			(banner :: RemoteEvent):FireAllClients(string.format("CREW OF %d: %s OPEN", crew, table.concat(names, " + ")), "Zones")
		end
	end
	return open
end

function Zones.CloseAll(store: Instance)
	for zone in DOORS do
		setDoor(store, zone, false)
	end
	store:SetAttribute("OpenZones", "")
end

return Zones

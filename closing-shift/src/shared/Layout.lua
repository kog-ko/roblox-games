--!strict
-- The store's size. StoreBuilder lays the store out in its original coordinates (main room
-- x -30.5..30.5, z -20.5..20.5) and then stretches it: the main room becomes ScaleX times wider
-- and ScaleZ times deeper, and every room beyond its walls (restroom hall, back room, stockroom,
-- the lot outside) slides out by the same amount, unchanged. Any code that has a position written
-- in the original coordinates (the Manager's spawn, the payoff camera, ...) passes it through
-- Layout.Map; Layout.Unmap goes the other way.
local Layout = {
	ScaleX = 1.3,
	ScaleZ = 1.2,
	HalfX = 30.5,
	HalfZ = 20.5,
}

local function mapAxis(v: number, k: number, half: number): number
	if math.abs(v) <= half then
		return v * k
	end
	return v + math.sign(v) * (k - 1) * half
end

local function unmapAxis(v: number, k: number, half: number): number
	if math.abs(v) <= half * k then
		return v / k
	end
	return v - math.sign(v) * (k - 1) * half
end

function Layout.MapX(x: number): number
	return mapAxis(x, Layout.ScaleX, Layout.HalfX)
end

function Layout.MapZ(z: number): number
	return mapAxis(z, Layout.ScaleZ, Layout.HalfZ)
end

function Layout.Map(p: Vector3): Vector3
	return Vector3.new(Layout.MapX(p.X), p.Y, Layout.MapZ(p.Z))
end

function Layout.Unmap(p: Vector3): Vector3
	return Vector3.new(unmapAxis(p.X, Layout.ScaleX, Layout.HalfX), p.Y, unmapAxis(p.Z, Layout.ScaleZ, Layout.HalfZ))
end

return Layout

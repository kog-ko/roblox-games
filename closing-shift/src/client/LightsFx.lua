--!strict
-- Local-only fluorescent flicker + power / back-room light state (cheap, no replication traffic).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local LightsFx = {}

type Tube = { part: BasePart, light: Light?, color: Color3, kind: string, offUntil: number, on: boolean? }

local DARK = Color3.fromRGB(70, 75, 70)
local rng = Random.new()
local tubes: { [BasePart]: Tube } = {}

local function add(kind: string)
	return function(inst: Instance)
		if inst:IsA("BasePart") then
			tubes[inst] = {
				part = inst, light = inst:FindFirstChildWhichIsA("Light"), kind = kind, offUntil = 0,
				color = if inst.Material == Enum.Material.Neon then inst.Color else Color3.fromRGB(215, 235, 210),
			}
		end
	end
end

function LightsFx.Start()
	for tag, kind in { FluorescentTube = "Main", BackRoomLight = "Back", StreetLamp = "Street", PoweredNeon = "Neon" } do
		for _, inst in CollectionService:GetTagged(tag) do
			add(kind)(inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(add(kind))
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
			tubes[inst :: BasePart] = nil
		end)
	end

	local baseAmbient = Lighting.Ambient
	local lastPower = true
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.05 then
			return
		end
		acc = 0
		local store = workspace:FindFirstChild("Store")
		if not store then
			return
		end
		local power = store:GetAttribute("Power") ~= false
		local backLit = store:GetAttribute("BackRoomLit") == true
		if power ~= lastPower then
			lastPower = power
			Lighting.Ambient = if power then baseAmbient else Color3.fromRGB(6, 7, 6)
		end
		local t = os.clock()
		for part, st in tubes do
			local want = true
			local chance = 0.004
			if st.kind == "Main" or st.kind == "Neon" then
				want = power
			elseif st.kind == "Back" then
				want = power and backLit
				chance = 0.01
			elseif st.kind == "Street" then
				chance = 0.03
			end
			if st.kind ~= "Neon" and want and t >= st.offUntil and rng:NextNumber() < chance then
				st.offUntil = t + rng:NextNumber(0.04, if st.kind == "Street" then 0.5 else 0.15)
			end
			local on = want and t >= st.offUntil
			if on ~= st.on then
				st.on = on
				part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
				part.Color = if on then st.color else DARK
				if st.light then
					st.light.Enabled = on
				end
			end
		end
	end)
end

return LightsFx

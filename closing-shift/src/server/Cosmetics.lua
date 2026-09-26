--!strict
-- Cosmetics (Data/Cosmetics.lua): bought with shift cash, equipped one per slot, seen by everyone.
-- The client only asks (BuyCosmetic / EquipCosmetic); the server checks the price, the VIP pass
-- and ownership, and spends the cash through Economy (so analytics sees it).
--
-- What each slot does on the server:
--   Vest   welds a vest over the character's torso
--   Trail  a Trail on the root part (only where Init was told to show trails: the lobby)
--   Tag    TagColor / TagRainbow attributes (NameTags colours the rank line)
--   Mop    MopSkin attribute (Mop.Give paints the tool; the first-person mop copies it)
--   Beam   BeamColor attribute (every client colours that player's flashlight)
-- Owned items are published as OwnedCosmetics ("id,id,...") and equipped ones as Equip_<Slot>.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)

local Cosmetics = {}
-- Called after a player's look changes (Mop.Give uses it to repaint a held mop).
Cosmetics.OnApplied = nil :: ((Player) -> ())?

local DATA = Config.Cosmetics
local byId: { [string]: any } = {}
local defaults: { [string]: string } = {}
for _, item in DATA.Items do
	byId[item.Id] = item
	if item.Price == 0 and not defaults[item.Slot] then
		defaults[item.Slot] = item.Id
	end
end

local showTrails = false
local lastAction: { [Player]: number } = {}
local Banner: RemoteEvent

function Cosmetics.Item(id: string?): any
	return if id then byId[id] else nil
end

-- The item a player has equipped in a slot (the free default if nothing).
function Cosmetics.Equipped(player: Player, slot: string): any
	local prof = DataService.Get(player)
	local item = byId[(prof and prof.Cosmetics.Equipped[slot]) or ""]
	if item and item.Vip and not player:GetAttribute("VIP") then
		item = nil -- VIP-only, and the pass is gone (or still being checked)
	end
	return item or byId[defaults[slot]]
end

local function rainbow(): ColorSequence
	local keys = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.8, 1)))
	end
	return ColorSequence.new(keys)
end

local function applyVest(player: Player, char: Model)
	local old = char:FindFirstChild("CosmeticVest")
	if old then
		old:Destroy()
	end
	local item = Cosmetics.Equipped(player, "Vest")
	if not item or not item.Color then
		return
	end
	local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return
	end
	local vest = Instance.new("Part")
	vest.Name = "CosmeticVest"
	vest.Size = Vector3.new(torso.Size.X + 0.12, torso.Size.Y * 0.85, torso.Size.Z + 0.12)
	vest.CFrame = torso.CFrame * CFrame.new(0, -torso.Size.Y * 0.05, 0)
	vest.Color = item.Color
	vest.Material = (Enum.Material :: any)[item.Material or "SmoothPlastic"]
	vest.CanCollide = false
	vest.CanQuery = false
	vest.CanTouch = false
	vest.Massless = true
	vest.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = vest
	weld.Parent = vest
	-- a reflective stripe so it reads as a work vest
	local stripe = Instance.new("Part")
	stripe.Name = "Stripe"
	stripe.Size = Vector3.new(vest.Size.X + 0.02, 0.18, vest.Size.Z + 0.02)
	stripe.CFrame = vest.CFrame * CFrame.new(0, -vest.Size.Y * 0.2, 0)
	stripe.Color = Color3.fromRGB(220, 220, 200)
	stripe.Material = Enum.Material.Neon
	stripe.CanCollide = false
	stripe.CanQuery = false
	stripe.CanTouch = false
	stripe.Massless = true
	local w2 = Instance.new("WeldConstraint")
	w2.Part0 = vest
	w2.Part1 = stripe
	w2.Parent = stripe
	stripe.Parent = vest
	vest.Parent = char
end

local function applyTrail(player: Player, char: Model)
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	for _, n in { "CosmeticTrail", "TrailA0", "TrailA1" } do
		local old = root:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local item = Cosmetics.Equipped(player, "Trail")
	if not showTrails or not item or not (item.Color or item.Rainbow) then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA0"
	a0.Position = Vector3.new(0, 0.9, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailA1"
	a1.Position = Vector3.new(0, -0.9, 0)
	a1.Parent = root
	local t = Instance.new("Trail")
	t.Name = "CosmeticTrail"
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Lifetime = 0.6
	t.LightEmission = 0.6
	t.Transparency = NumberSequence.new(0.2, 1)
	t.Color = if item.Rainbow then rainbow() else ColorSequence.new(item.Color, item.Color2 or item.Color)
	t.Parent = root
end

-- Publishes the attributes other systems read, and rebuilds the vest and trail.
function Cosmetics.Apply(player: Player)
	local prof = DataService.Get(player)
	if not prof then
		return
	end
	local owned = {}
	for id in prof.Cosmetics.Owned do
		table.insert(owned, id)
	end
	player:SetAttribute("OwnedCosmetics", table.concat(owned, ","))
	for _, slot in DATA.Slots do
		local item = Cosmetics.Equipped(player, slot)
		player:SetAttribute("Equip_" .. slot, item and item.Id)
	end
	local tag = Cosmetics.Equipped(player, "Tag")
	player:SetAttribute("TagColor", tag and tag.Color)
	player:SetAttribute("TagRainbow", if tag and tag.Rainbow then true else nil)
	local beam = Cosmetics.Equipped(player, "Beam")
	player:SetAttribute("BeamColor", beam and beam.Color)
	local mop = Cosmetics.Equipped(player, "Mop")
	player:SetAttribute("MopSkin", if mop and mop.Color then mop.Id else nil)
	local char = player.Character
	if char then
		applyVest(player, char)
		applyTrail(player, char)
	end
	if Cosmetics.OnApplied then
		Cosmetics.OnApplied(player)
	end
end

local function canAct(player: Player): boolean
	local now = os.clock()
	if now - (lastAction[player] or 0) < 0.3 then
		return false
	end
	lastAction[player] = now
	local prof = DataService.Get(player)
	return prof ~= nil and not prof.LoadFailed
end

local function buy(player: Player, id: any)
	if type(id) ~= "string" or not canAct(player) then
		return
	end
	local item = byId[id]
	local prof = DataService.Get(player)
	if not item or not prof or prof.Cosmetics.Owned[id] or item.Price == 0 then
		return
	end
	if item.Vip and not player:GetAttribute("VIP") then
		Banner:FireClient(player, "VIP ONLY. GET VIP IN THE SHOP", "Cosmetic")
		return
	end
	if not Economy.SpendCash(player, item.Price, "Cosmetic:" .. id) then
		Banner:FireClient(player, "NOT ENOUGH CASH. WORK A FEW MORE SHIFTS", "Cosmetic")
		return
	end
	DataService.Update(player, function(p)
		p.Cosmetics.Owned[id] = true
		p.Cosmetics.Equipped[item.Slot] = id
	end)
	Cosmetics.Apply(player)
	task.spawn(DataService.Save, player)
	Banner:FireClient(player, "BOUGHT: " .. item.Name, "Cosmetic")
end

local function equip(player: Player, id: any)
	if type(id) ~= "string" or not canAct(player) then
		return
	end
	local item = byId[id]
	local prof = DataService.Get(player)
	if not item or not prof then
		return
	end
	if item.Price > 0 and not prof.Cosmetics.Owned[id] then
		return
	end
	if item.Vip and not player:GetAttribute("VIP") then
		return -- bought as a VIP, but the pass is gone
	end
	DataService.Update(player, function(p)
		p.Cosmetics.Equipped[item.Slot] = id
	end)
	Cosmetics.Apply(player)
end

-- options.Trails: show trails in this place (the lobby).
function Cosmetics.Init(options: { Trails: boolean }?)
	showTrails = options ~= nil and options.Trails == true
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	Banner = remotes:WaitForChild("Banner") :: RemoteEvent
	for _, name in { "BuyCosmetic", "EquipCosmetic" } do
		if not remotes:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = remotes
		end
	end
	(remotes:FindFirstChild("BuyCosmetic") :: RemoteEvent).OnServerEvent:Connect(buy)
	;(remotes:FindFirstChild("EquipCosmetic") :: RemoteEvent).OnServerEvent:Connect(equip)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("HumanoidRootPart", 5)
			char:WaitForChild("Head", 5)
			Cosmetics.Apply(player)
		end)
		-- VIP-only items come off if the pass is gone
		player:GetAttributeChangedSignal("VIP"):Connect(function()
			Cosmetics.Apply(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	DataService.Loaded.Event:Connect(function(player: Player)
		Cosmetics.Apply(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastAction[p] = nil
	end)
end

return Cosmetics

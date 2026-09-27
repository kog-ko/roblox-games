--!strict
-- Per-player settings and "tips already seen", saved in the profile, in both places.
--   Settings (the gear menu): each a boolean, published as Set_<Key> attributes. All default on;
--   turning one off is stored. Keys: Config.Settings.
--   Tips: shown once each (client Tips.lua); seen ones are published as TipsSeen ("a,b,c").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local PlayerPrefs = {}

local function publish(player: Player, p: any)
	for _, s in Config.Settings do
		player:SetAttribute("Set_" .. s.Key, p.Settings[s.Key] ~= false)
	end
	local seen = {}
	for tip in p.Tips do
		table.insert(seen, tip)
	end
	player:SetAttribute("TipsSeen", table.concat(seen, ","))
end

function PlayerPrefs.HasSeen(player: Player, tip: string): boolean
	local p = DataService.Get(player)
	return p ~= nil and p.Tips[tip] == true
end

function PlayerPrefs.Init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in { "SetSetting", "TipSeen" } do
		if not remotes:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = remotes
		end
	end
	local validSetting: { [string]: boolean } = {}
	for _, s in Config.Settings do
		validSetting[s.Key] = true
	end
	local validTip: { [string]: boolean } = {}
	for _, t in Config.Tips do
		validTip[t.Id] = true
	end
	local last: { [Player]: number } = {}
	local function throttle(player: Player): boolean
		local now = os.clock()
		if now - (last[player] or 0) < 0.2 then
			return false
		end
		last[player] = now
		return true
	end
	;(remotes:FindFirstChild("SetSetting") :: RemoteEvent).OnServerEvent:Connect(function(player, key, on)
		if type(key) ~= "string" or not validSetting[key] or type(on) ~= "boolean" or not throttle(player) then
			return
		end
		DataService.Update(player, function(p)
			p.Settings[key] = if on then nil else false
		end)
		local p = DataService.Get(player)
		if p then
			publish(player, p)
		end
	end)
	;(remotes:FindFirstChild("TipSeen") :: RemoteEvent).OnServerEvent:Connect(function(player, tip)
		if type(tip) ~= "string" or not validTip[tip] then
			return
		end
		DataService.Update(player, function(p)
			p.Tips[tip] = true
		end)
		local p = DataService.Get(player)
		if p then
			publish(player, p)
		end
	end)
	DataService.Loaded.Event:Connect(function(player: Player)
		local p = DataService.Get(player)
		if p then
			publish(player, p)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		last[p] = nil
	end)
end

return PlayerPrefs

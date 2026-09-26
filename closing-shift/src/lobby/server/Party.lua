--!strict
-- Parties: invite players in this lobby server into a party (up to a full crew). When the leader
-- stands on a queue pad, the whole party queues with them, wherever they're standing.
-- Client -> server (Party remote): { Action = "Invite", Target = userId } | { Action = "Accept", From = userId }
--   | { Action = "Decline", From = userId } | { Action = "Leave" } | { Action = "Kick", Target = userId }
-- Server -> client: { Type = "Invite", From = userId, Name = displayName } when someone invites you.
-- Party state for the HUD: PartyLeader (userId) and PartyMembers ("name,name,...") attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Party = {}

local parties: { [Player]: { Player } } = {} -- leader -> members (leader first)
local leaderOf: { [Player]: Player } = {}
local invites: { [Player]: { [Player]: number } } = {} -- invitee -> inviter -> expiry
local lastAction: { [Player]: number } = {}
local Remote: RemoteEvent
local Banner: RemoteEvent

local INVITE_TIME = 30

local function publish(leader: Player)
	local members = parties[leader]
	local names = {}
	if members then
		for _, m in members do
			table.insert(names, m.DisplayName)
		end
	end
	for _, m in members or { leader } do
		m:SetAttribute("PartyLeader", if members then leader.UserId else nil)
		m:SetAttribute("PartyMembers", if members then table.concat(names, ",") else nil)
	end
end

local function clear(p: Player)
	p:SetAttribute("PartyLeader", nil)
	p:SetAttribute("PartyMembers", nil)
end

-- The leader of p's party, or nil if p isn't in one.
function Party.LeaderOf(p: Player): Player?
	return leaderOf[p]
end

-- Everyone in the party led by leader (leader first), or just { leader }.
function Party.Members(leader: Player): { Player }
	return parties[leader] or { leader }
end

local function leave(p: Player)
	local leader = leaderOf[p]
	if not leader then
		return
	end
	local members = parties[leader]
	leaderOf[p] = nil
	clear(p)
	if not members then
		return
	end
	local i = table.find(members, p)
	if i then
		table.remove(members, i)
	end
	if #members <= 1 then
		-- a party of one is no party
		for _, m in members do
			leaderOf[m] = nil
			clear(m)
		end
		parties[leader] = nil
		return
	end
	if p == leader then
		-- the next member leads
		local newLeader = members[1]
		parties[leader] = nil
		parties[newLeader] = members
		for _, m in members do
			leaderOf[m] = newLeader
		end
		publish(newLeader)
	else
		publish(leader)
	end
end

local function join(invitee: Player, inviter: Player)
	local leader = leaderOf[inviter] or inviter
	local members = parties[leader]
	if not members then
		members = { leader }
		parties[leader] = members
		leaderOf[leader] = leader
	end
	if #members >= Config.Queue.MaxCrew then
		Banner:FireClient(invitee, "THAT PARTY IS FULL", "Party")
		return
	end
	leave(invitee)
	table.insert(members, invitee)
	leaderOf[invitee] = leader
	publish(leader)
	for _, m in members do
		Banner:FireClient(m, string.upper(invitee.DisplayName) .. " JOINED THE PARTY", "Party")
	end
end

local function onAction(player: Player, msg: any)
	if type(msg) ~= "table" or type(msg.Action) ~= "string" then
		return
	end
	local now = os.clock()
	if now - (lastAction[player] or 0) < 0.3 then
		return
	end
	lastAction[player] = now
	local action = msg.Action
	if action == "Invite" then
		local target = if type(msg.Target) == "number" then Players:GetPlayerByUserId(msg.Target) else nil
		if not target or target == player or (leaderOf[target] and leaderOf[target] == (leaderOf[player] or player)) then
			return
		end
		local mine = invites[target] or {}
		invites[target] = mine
		mine[player] = now + INVITE_TIME
		Remote:FireClient(target, { Type = "Invite", From = player.UserId, Name = player.DisplayName })
		Banner:FireClient(player, "INVITED " .. string.upper(target.DisplayName), "Party")
	elseif action == "Accept" or action == "Decline" then
		local from = if type(msg.From) == "number" then Players:GetPlayerByUserId(msg.From) else nil
		local mine = invites[player]
		local expires = from and mine and mine[from]
		if mine and from then
			mine[from] = nil
		end
		if action == "Accept" and from and expires and expires > now then
			join(player, from)
		end
	elseif action == "Leave" then
		leave(player)
	elseif action == "Kick" then
		local target = if type(msg.Target) == "number" then Players:GetPlayerByUserId(msg.Target) else nil
		if target and target ~= player and parties[player] and leaderOf[target] == player then
			leave(target)
			Banner:FireClient(target, "YOU LEFT THE PARTY", "Party")
		end
	end
end

function Party.Init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	Banner = remotes:WaitForChild("Banner") :: RemoteEvent
	local r = remotes:FindFirstChild("Party")
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = "Party"
		r.Parent = remotes
	end
	Remote = r :: RemoteEvent
	Remote.OnServerEvent:Connect(onAction)
	Players.PlayerRemoving:Connect(function(p)
		leave(p)
		invites[p] = nil
		lastAction[p] = nil
		for _, list in invites do
			list[p] = nil
		end
	end)
end

return Party

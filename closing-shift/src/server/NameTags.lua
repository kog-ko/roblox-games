--!strict
-- The tag above every player's head: their career rank (from lifetime spills cleaned), gold for
-- VIPs, and a trophy line for last week's top 3 Employees of the Week. Rebuilt whenever one of
-- those changes or the character respawns. Also publishes the rank index as the Rank attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progress = require(ReplicatedStorage.Shared.Progress)
local Banner = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Banner") :: RemoteEvent

local NameTags = {}

local GOLD = Color3.fromRGB(255, 205, 70)
local PLAIN = Color3.fromRGB(215, 225, 205)
local TROPHY = { "#1 EMPLOYEE OF THE WEEK", "#2 EMPLOYEE OF THE WEEK", "#3 EMPLOYEE OF THE WEEK" }
local TROPHY_COLORS = { Color3.fromRGB(255, 215, 80), Color3.fromRGB(210, 215, 225), Color3.fromRGB(215, 140, 80) }

local function line(parent: Instance, name: string, text: string, color: Color3, order: number)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 0.5)
	t.Font = Enum.Font.Arcade
	t.TextScaled = true
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.3
	t.Text = text
	t.LayoutOrder = order
	t.Parent = parent
end

function NameTags.Refresh(player: Player)
	local cleaned = (player:GetAttribute("TotalCleaned") or 0) :: number
	local rankIndex, rankName = Progress.Rank(cleaned)
	player:SetAttribute("Rank", rankIndex)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("NameTag")
	if old then
		old:Destroy()
	end
	local vip = player:GetAttribute("VIP") == true
	local trophy = player:GetAttribute("WeeklyTrophy")
	local bb = Instance.new("BillboardGui")
	bb.Name = "NameTag"
	bb.Size = UDim2.fromOffset(200, if trophy then 44 else 22)
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
	bb.MaxDistance = 60
	bb.LightInfluence = 0
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = bb
	if type(trophy) == "number" and TROPHY[trophy] then
		line(bb, "Trophy", TROPHY[trophy], TROPHY_COLORS[trophy], 1)
	end
	line(bb, "Rank", (if vip then "VIP · " else "") .. rankName, if vip then GOLD else PLAIN, 2)
	for _, c in bb:GetChildren() do
		if c:IsA("TextLabel") then
			c.Size = UDim2.new(1, 0, 0, 22)
		end
	end
	bb.Parent = head
end

function NameTags.Init()
	local function onPlayer(player: Player)
		-- the saved total arrives after joining; only growth from there on is a promotion
		local lastTotal = player:GetAttribute("TotalCleaned")
		for _, attr in { "VIP", "WeeklyTrophy", "TotalCleaned" } do
			player:GetAttributeChangedSignal(attr):Connect(function()
				-- TotalCleaned changes every spill; only rebuild when the rank actually changes
				if attr == "TotalCleaned" then
					local total = (player:GetAttribute("TotalCleaned") or 0) :: number
					local prev = lastTotal
					lastTotal = total
					local idx, name = Progress.Rank(total)
					local was = player:GetAttribute("Rank")
					if idx == was then
						return
					end
					if type(prev) == "number" and type(was) == "number" and idx > was then
						-- a promotion is announced to the whole server
						Banner:FireAllClients(string.format("%s WAS PROMOTED TO %s!", string.upper(player.DisplayName), name), "Promotion")
					end
				end
				NameTags.Refresh(player)
			end)
		end
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Head", 5)
			NameTags.Refresh(player)
		end)
		NameTags.Refresh(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
end

return NameTags

--!strict
-- Party window (PARTY button): who's in your party, LEAVE, and everyone else in this lobby
-- server with an INVITE button. Invites you receive pop up with ACCEPT / DECLINE.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PartyUi = {}
PartyUi.Open = nil :: (() -> ())?

local player = Players.LocalPlayer :: Player
local GOLD = Color3.fromRGB(255, 215, 90)
local GREEN = Color3.fromRGB(120, 200, 110)
local GREY = Color3.fromRGB(90, 90, 85)
local BLUE = Color3.fromRGB(110, 160, 220)

local function new(className: string, props: { [string]: any }): any
	local i = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(i :: any)[k] = v
		end
	end
	i.Parent = props.Parent
	return i
end

local function button(parent: Instance, t: string, size: UDim2, pos: UDim2, color: Color3): TextButton
	local b = new("TextButton", {
		Text = t, Size = size, Position = pos, BackgroundColor3 = color, BorderSizePixel = 0, Font = Enum.Font.Arcade,
		TextScaled = true, TextColor3 = Color3.fromRGB(15, 15, 15), Parent = parent,
	})
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), Parent = b })
	return b
end

local function label(parent: Instance, t: string, size: UDim2, pos: UDim2, color: Color3?): TextLabel
	return new("TextLabel", {
		Text = t, Size = size, Position = pos, BackgroundTransparency = 1, Font = Enum.Font.Arcade, TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or Color3.fromRGB(230, 230, 220), Parent = parent,
	})
end

function PartyUi.Start()
	local remote = Remotes:WaitForChild("Party") :: RemoteEvent
	local gui = new("ScreenGui", { Name = "Party", ResetOnSpawn = false, DisplayOrder = 150, Parent = player:WaitForChild("PlayerGui") })

	-- window
	local frame = new("Frame", {
		Size = UDim2.fromOffset(420, 360), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false,
		BackgroundColor3 = Color3.fromRGB(14, 14, 16), BorderSizePixel = 0, Parent = gui,
	})
	new("UIStroke", { Color = BLUE, Thickness = 3, Parent = frame })
	local scale = new("UIScale", { Parent = frame })
	local function fit()
		local vp = Workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (vp.X - 20) / 420, (vp.Y - 60) / 360)
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	label(frame, "PARTY", UDim2.new(1, -70, 0, 34), UDim2.fromOffset(12, 6), BLUE)
	local close = button(frame, "X", UDim2.fromOffset(40, 34), UDim2.new(1, -48, 0, 6), Color3.fromRGB(200, 70, 60))
	local mine = label(frame, "", UDim2.new(1, -140, 0, 40), UDim2.fromOffset(12, 46), GOLD)
	mine.TextWrapped = true
	local leaveBtn = button(frame, "LEAVE", UDim2.fromOffset(110, 34), UDim2.new(1, -122, 0, 48), Color3.fromRGB(200, 110, 90))
	label(frame, "INVITE PLAYERS IN THIS LOBBY", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 94), Color3.fromRGB(170, 190, 170))
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -126), Position = UDim2.fromOffset(12, 118), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = frame,
	})
	new("UIListLayout", { Padding = UDim.new(0, 5), Parent = list })

	local function render()
		local members = player:GetAttribute("PartyMembers")
		mine.Text = if type(members) == "string" then "YOUR PARTY: " .. string.upper((members:gsub(",", ", "))) else "NOT IN A PARTY. INVITE SOMEONE!"
		leaveBtn.Visible = type(members) == "string"
		for _, c in list:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local myLeader = player:GetAttribute("PartyLeader")
		for _, p in Players:GetPlayers() do
			if p == player then
				continue
			end
			local row = new("Frame", { Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = Color3.fromRGB(28, 28, 32), BorderSizePixel = 0, Parent = list })
			label(row, string.upper(p.DisplayName), UDim2.new(1, -150, 0, 26), UDim2.fromOffset(8, 7))
			local together = myLeader ~= nil and p:GetAttribute("PartyLeader") == myLeader
			if together then
				label(row, "IN YOUR PARTY", UDim2.fromOffset(130, 20), UDim2.new(1, -136, 0, 10), GREEN)
			else
				local b = button(row, "INVITE", UDim2.fromOffset(120, 32), UDim2.new(1, -126, 0, 4), BLUE)
				b.Activated:Connect(function()
					remote:FireServer({ Action = "Invite", Target = p.UserId })
					b.Text = "SENT"
					b.BackgroundColor3 = GREY
				end)
			end
		end
	end

	local function open()
		render()
		frame.Visible = true
	end
	PartyUi.Open = open
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	leaveBtn.Activated:Connect(function()
		remote:FireServer({ Action = "Leave" })
	end)
	player.AttributeChanged:Connect(function(attr)
		if frame.Visible and (attr == "PartyMembers" or attr == "PartyLeader") then
			render()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if frame.Visible then
			render()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if frame.Visible then
			task.defer(render)
		end
	end)

	-- incoming invite
	local pop = new("Frame", {
		Size = UDim2.fromOffset(360, 110), Position = UDim2.new(0.5, 0, 0, 100), AnchorPoint = Vector2.new(0.5, 0), Visible = false,
		BackgroundColor3 = Color3.fromRGB(14, 14, 16), BorderSizePixel = 0, Parent = gui,
	})
	new("UIStroke", { Color = BLUE, Thickness = 3, Parent = pop })
	local popText = label(pop, "", UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 8), GOLD)
	popText.TextXAlignment = Enum.TextXAlignment.Center
	local accept = button(pop, "JOIN", UDim2.fromOffset(160, 44), UDim2.new(0.5, -166, 1, -54), GREEN)
	local decline = button(pop, "NO THANKS", UDim2.fromOffset(160, 44), UDim2.new(0.5, 6, 1, -54), GREY)
	local fromId: number? = nil
	local popId = 0
	accept.Activated:Connect(function()
		pop.Visible = false
		remote:FireServer({ Action = "Accept", From = fromId })
	end)
	decline.Activated:Connect(function()
		pop.Visible = false
		remote:FireServer({ Action = "Decline", From = fromId })
	end)
	remote.OnClientEvent:Connect(function(msg: any)
		if type(msg) == "table" and msg.Type == "Invite" then
			fromId = msg.From
			popText.Text = string.upper(tostring(msg.Name)) .. " INVITED YOU TO THEIR PARTY"
			pop.Visible = true
			popId += 1
			local id = popId
			task.delay(30, function()
				if id == popId then
					pop.Visible = false
				end
			end)
		end
	end)
end

return PartyUi

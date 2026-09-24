--!strict
-- Back-room reveal after the final spill: lights on, a note on the desk, your face on the wall.
-- The personal bits (photo + name) are set on each client, so everyone sees *themselves*.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Badges = require(script.Parent.Badges)

local Payoff = {}
local store: Instance
local prompt: ProximityPrompt
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local payoffCue = remotes:WaitForChild("PayoffCue") :: RemoteEvent
local showNote = remotes:WaitForChild("ShowNote") :: RemoteEvent

function Payoff.Run(cleaner: Player?)
	store:SetAttribute("BackRoomLit", true)
	prompt.Enabled = true
	-- camera: by the front wall, looking past the desk at the old photos and the big frame.
	-- Aimed away from the open door, which would otherwise fill the left of the shot.
	local camCF = CFrame.lookAt(Vector3.new(38, 7.5, -5.2), Vector3.new(43, 6, -14))
	payoffCue:FireAllClients(camCF, if cleaner then cleaner.DisplayName else "")
	task.wait(Config.PayoffTime)
end

function Payoff.Reset()
	store:SetAttribute("BackRoomLit", false)
	prompt.Enabled = false
end

function Payoff.Init(s: Instance)
	store = s
	local note = store:FindFirstChild("Note", true) :: BasePart
	prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Read"
	prompt.ObjectText = "Note"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = note
	prompt.Triggered:Connect(function(player)
		Badges.Award(player, "FoundTheNote")
		showNote:FireClient(player)
	end)
end

return Payoff

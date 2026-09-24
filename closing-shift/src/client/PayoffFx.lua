--!strict
-- Back-room reveal on the client: every photo on the wall becomes *your* headshot,
-- the note is signed with *your* name, and the camera swings in for a clip-able beat.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PayoffFx = {}
local player = Players.LocalPlayer :: Player

local function setPersonal(image: string, name: string, noteText: string)
	for _, img in CollectionService:GetTagged("PayoffPhoto") do
		if img:IsA("ImageLabel") then
			img.Image = image
		end
	end
	local store = workspace:FindFirstChild("Store")
	if store then
		local nameLabel = store:FindFirstChild("PhotoName", true)
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = name
		end
		local note = store:FindFirstChild("NoteText", true)
		if note and note:IsA("TextLabel") then
			note.Text = noteText
		end
	end
end

function PayoffFx.Start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PayoffCue") :: RemoteEvent
	remote.OnClientEvent:Connect(function(camCF: CFrame)
		local ok, thumb = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		local name = string.upper(player.DisplayName)
		setPersonal(if ok then thumb else "", name, "thanks for covering my shift.\n- " .. string.lower(player.DisplayName))

		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(cam, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = camCF }):Play()
		task.wait(1.2 + 3.5)
		cam.CameraType = Enum.CameraType.Custom
	end)
	-- Back to a blank wall for the next shift.
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
		if ReplicatedStorage:GetAttribute("Phase") == "Lobby" then
			setPersonal("", "", "")
		end
	end)
end

return PayoffFx

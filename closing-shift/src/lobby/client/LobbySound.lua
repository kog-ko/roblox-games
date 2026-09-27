--!strict
-- The lobby's sound: distant city traffic and crickets everywhere, the fountain and the buzzing
-- neon signs where you stand near them, and the obby one-shots (checkpoint, clear, falling in) the
-- server sends through ObbySfx. The music is Music.lua.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local LobbySound = {}
local S = Config.Sounds

local function loop(id: string, volume: number, parent: Instance, range: number?): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = volume
	if range then
		s.RollOffMaxDistance = range
		s.RollOffMinDistance = 6
	end
	s.Parent = parent
	s:Play()
	return s
end

-- A 2D one-shot. stopAfter cuts long clips (the clear fanfare is the first few seconds of a cue).
function LobbySound.Play(id: string, volume: number, stopAfter: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = SoundService
	s:Play()
	if stopAfter then
		task.delay(stopAfter, function()
			for i = 1, 10 do
				s.Volume = volume * (1 - i / 10)
				task.wait(0.05)
			end
			s:Destroy()
		end)
	else
		s.Ended:Connect(function()
			s:Destroy()
		end)
	end
end

function LobbySound.Start()
	loop(S.CityNight, 0.22, SoundService)
	loop(S.Crickets, 0.16, SoundService)
	local lobby = workspace:WaitForChild("Lobby", 30)
	if lobby then
		local bucket = lobby:FindFirstChild("Bucket", true)
		if bucket then
			loop(S.Fountain, 0.5, bucket, 45)
		end
		local n = 0
		local function buzz(p: Instance)
			n += 1
			if p:IsA("BasePart") and n % 2 == 1 then
				loop(S.NeonBuzz, 0.12, p, 22)
			end
		end
		for _, p in CollectionService:GetTagged("Blinker") do
			buzz(p)
		end
	end
	local sfx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ObbySfx") :: RemoteEvent
	sfx.OnClientEvent:Connect(function(kind: string)
		if kind == "Checkpoint" then
			LobbySound.Play(S.Checkpoint, 0.6)
		elseif kind == "Finish" then
			LobbySound.Play(S.ObbyFinish, 0.55, 4)
		elseif kind == "Fall" then
			LobbySound.Play(S.ObbyFall, 0.7)
		elseif kind == "Start" then
			LobbySound.Play(S.QueueBeep, 0.5)
		end
	end)
end

return LobbySound

--!strict
-- CLOSING SHIFT client: UI and effects only. The server owns every rule.
local Players = game:GetService("Players")

-- First person plays in landscape only (phones otherwise rotate to portrait).
local playerGui = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui") :: PlayerGui
playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

require(script:WaitForChild("Overlay")).Start()
require(script:WaitForChild("SoundFx")).Start()
require(script:WaitForChild("LightsFx")).Start()
require(script:WaitForChild("Movement")).Start()
require(script:WaitForChild("CameraFx")).Start()
require(script:WaitForChild("Viewmodel")).Start()
require(script:WaitForChild("Flashlight")).Start()
require(script:WaitForChild("Prompts")).Start()
require(script:WaitForChild("PayoffFx")).Start()
require(script:WaitForChild("Hud")).Start()
require(script:WaitForChild("Juice")).Start()
require(script:WaitForChild("NightPicker")).Start()
require(script:WaitForChild("Tutorial")).Start()

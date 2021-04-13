local Wave = require(game:GetService("ReplicatedStorage"):WaitForChild("Common"):WaitForChild("WaveModule"))

local plane = workspace:WaitForChild("Ocean"):WaitForChild("Plane")

-- local wave1 = Wave.new(plane, {
-- 	WaveLength = 200,
-- 	Gravity = 9.81,
-- 	Steepness = 0.25,
-- 	Direction = Vector2.new(-50, -50),
-- 	FollowPoint = nil,
-- 	MaxDistance = 1000,
-- })
local wave1 = Wave.new(plane)
wave1:ConnectRenderStepped()
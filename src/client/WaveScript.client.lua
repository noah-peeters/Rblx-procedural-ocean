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
local test = {
    Gravity = 9.81,
    MaxDistance = 1000,
    Wave1 = {
        WaveLength = 200,
        Steepness = 0.25,
        Direction = Vector2.new(-50, -50)
    },
    Wave2 = {
        WaveLength = 50,
        Steepness = 0.4,
        Direction = Vector2.new(25, -25)
    },
    Wave3 = {
        WaveLength = 8,
        Steepness = 1,
        Direction = Vector2.new(-25, -15)
    }
}
local wave1 = Wave.new(plane)
wave1:ConnectRenderStepped()
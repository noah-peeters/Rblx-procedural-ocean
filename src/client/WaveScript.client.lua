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
        WaveLength = 250,
        Steepness = 0.25,
        Direction = Vector2.new(-1, -1)
    },
    Wave2 = {
        WaveLength = 50,
        Steepness = 0.3,
        Direction = Vector2.new(-50, -10)
    },
}
local wave1 = Wave.new(plane, test)
wave1:ConnectRenderStepped()
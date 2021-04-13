local Wave = require(game:GetService("ReplicatedStorage"):WaitForChild("Common"):WaitForChild("WaveModule"))

local plane = workspace:WaitForChild("Ocean"):WaitForChild("Plane")
local floatPart = workspace:WaitForChild("FloatingPart")

local test = {
    Gravity = 9.81,
    MaxDistance = 1000,
    Wave1 = {
        WaveLength = 150,
        Steepness = 0.4,
        Direction = Vector2.new(-1, -1)
    },
    Wave2 = {
        WaveLength = 50,
        Steepness = 0.3,
        Direction = Vector2.new(-50, -10)
    },
}
local wave = Wave.new(plane, test)
wave:ConnectRenderStepped()
wave:AddFloatingPart(floatPart)
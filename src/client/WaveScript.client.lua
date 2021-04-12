local Wave = require(game:GetService("ReplicatedStorage"):WaitForChild("Common"):WaitForChild("WaveModule"))

local plane = workspace:WaitForChild("Ocean"):WaitForChild("Plane")
local part = workspace:WaitForChild("FloatingPart")

local Settings = {
	WaveLength = 300,
	Direction = Vector2.new(0, 0),
	Steepness = 0.05,
	SpeedModifier = 8,
	MaxDistance = 1000,
}

local TestWave = Wave.new(plane, {})

TestWave:ConnectRenderStepped()

while wait(0.5) do
    local height = TestWave:GetYPosition(Vector2.new(part.Position.X, part.Position.Z))
    if height then
        print(height)
        --part.Position = Vector3.new(part.Position.X, height, part.Position.Z)
    end
end
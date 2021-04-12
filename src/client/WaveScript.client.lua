local Wave = require(game:GetService("ReplicatedStorage"):WaitForChild("Common"):WaitForChild("WaveModule"))

local plane = workspace:WaitForChild("Ocean"):WaitForChild("Plane")

local Settings = {
	WaveLength = 300,
	Direction = Vector2.new(0, 0),
	Steepness = 0.05,
	TimeModifier = 8,
	MaxDistance = 1000,
}

local TestWave = Wave.new(plane, Settings)

TestWave:ConnectRenderStepped()

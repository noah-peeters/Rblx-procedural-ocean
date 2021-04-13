local Players = game:GetService("Players")

local Wave = require(game:GetService("ReplicatedStorage"):WaitForChild("Common"):WaitForChild("WaveModule"))

local plane = workspace:WaitForChild("Ocean"):WaitForChild("Plane")
local LocalPlayer = Players.LocalPlayer

local floatPart = Instance.new("Part")
floatPart.Size = Vector3.new(5, 3, 5)
floatPart.Material = Enum.Material.WoodPlanks
floatPart.Color = Color3.fromRGB(65, 36, 17)
floatPart.Parent = workspace

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
wave:AddPlayerFloat(LocalPlayer)
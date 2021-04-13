local plane = workspace:WaitForChild("Ocean"):WaitForChild("Plane")

local WAVE_LENGTH = 10
local STEEPNESS = 1   -- Number from 0 to 1
local SPEED = 1.5

local bones = {}
local positions = {}
for _, v in pairs(plane:GetDescendants()) do
	if v:IsA("Bone") then
		table.insert(bones, v)
	end
end

-- Store WorldPosition
for _, bone in pairs(bones) do
	positions[bone] = bone.WorldPosition
end

while true do
	wait()
	for _, bone in pairs(bones) do
		local k = (2 * math.pi) / WAVE_LENGTH
		local f = k * (positions[bone].X - SPEED * os.clock())
        local amplitude = STEEPNESS / k

		local xPos = amplitude * math.cos(f)
		local yPos = amplitude * math.sin(f)
		bone.Transform = CFrame.new(Vector3.new(xPos, yPos, 0))
	end
end

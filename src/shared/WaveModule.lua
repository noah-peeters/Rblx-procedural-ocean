local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
-- Default wave settings
local default = {
	WaveLength = 100,
	Gravity = 9.81,
	Steepness = 0.4,
	Direction = Vector2.new(1, 0),
	FollowPoint = nil,
	MaxDistance = 1000,
}

local Wave = {}
Wave.__index = Wave

-- Create a new Wave
function Wave.new(instance: Instance, settings: table | nil, bones: table | nil)
	-- Check types
	if typeof(instance) ~= "Instance" then
		error("Instance argument must be a valid instance!")
	end

	if bones == nil then
		-- Get bones on our own
		bones = {}
		for _, v in pairs(instance:GetDescendants()) do
			if v:IsA("Bone") then
				table.insert(bones, v)
			end
		end
	end

	if not bones or #bones <= 0 then
		error("No bones have been found inside the chosen model!")
	end

	-- Check if valid settings and sort general settings from settings per wave
	local waveSettings = {}
	local waveCount = 0
	local generalSettings = {}
	for i, v in pairs(settings) do
		if typeof(v) == "table" then
			-- Insert in wave settings table
			waveSettings[i] = v
			waveCount += 1
		else
			-- Insert in general settings table
			generalSettings[i] = v
		end
	end

	if waveCount >= 1 then
		return setmetatable({
			_instance = instance,
			_bones = bones,
			_connections = {},
			_generalSettings = generalSettings,
			_waveSettings = waveSettings,
		}, Wave)
	else
		error("No Wave settings found! Make sure to follow the right format.")
	end
end

-- Calculate final displacement sum of all Gerstner waves
function Wave:GerstnerWave(xzPos)
	local finalDisplacement = Vector3.new()
	-- Calculate bone displacement for every wave
	for _, waveSetting in pairs(self._waveSettings) do
		-- Get settings: from this wave, from generalSettings or from default
		local waveLength = waveSetting.WaveLength or self._generalSettings.WaveLength or default.WaveLength
		local gravity = waveSetting.Gravity or self._generalSettings.Gravity or default.Gravity
		local direction = waveSetting.Direction or self._generalSettings.Direction or default.Direction
		local steepness = waveSetting.Steepness or self._generalSettings.Steepness or default.Steepness

		local k = (2 * math.pi) / waveLength
		local speed = math.sqrt(gravity / k)
		local dir = direction.Unit
		local f = k * (dir:Dot(xzPos) - speed * os.clock())

		-- Calculate displacement (direction)
		local amplitude = steepness / k
		local xPos = dir.X * (amplitude * math.cos(f))
		local yPos = amplitude * math.sin(f) -- Y-Position is not affected by direction of wave
		local zPos = dir.Y * (amplitude * math.cos(f))

		finalDisplacement += Vector3.new(xPos, yPos, zPos) -- Add this wave to final displacement
	end
	return finalDisplacement
end

-- Add a connection for a floating part
function Wave:AddFloatingPart(part)
	if typeof(part) ~= "Instance" then
		error("Part must be a valid Instance.")
	end
	if not self._instance then
		error("Wave object not found!")
	end
	-- Set part's height to wave
	local waveHeightPartPos = Vector3.new(part.Position.X, self._instance.Position.Y, part.Position.Z) -- Part's position at height of wave
	local xzPos = Vector2.new(part.Position.X, part.Position.Z)

	-- Setup BodyPosition
	local bodyPosition = Instance.new("BodyPosition")
	bodyPosition.D = 1000
	bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyPosition.P = 50000
	bodyPosition.Parent = part
	-- Setup BodyGyro
	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.D = 500
	bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyGyro.P = 3000
	bodyGyro.Parent = part

	part.Anchored = false

	-- Update part position
	local connection = RunService.Heartbeat:Connect(function()
		bodyPosition.Position = waveHeightPartPos + self:GerstnerWave(xzPos)
	end)
	table.insert(self._connections, connection)
end

function Wave:AddPlayerFloat(player)
	local char = player.Character or player.CharacterAdded:Wait()
	--player.CharacterAppearanceLoaded:Wait()
	print("done waiting")
	local rootPart = char:WaitForChild("HumanoidRootPart")
	local humanoid = char:WaitForChild("Humanoid")

	local bodyVelocity

	-- Rootpart position at wave height
	local rootPartWavePos = Vector3.new(rootPart.Position.X, self._instance.Position.Y, rootPart.Position.Z)
	local xzPos = Vector2.new(rootPart.Position.X, rootPart.Position.Z)

	local connection = RunService.Heartbeat:Connect(function()
		if rootPart then
			local waveDisplacement = self:GerstnerWave(xzPos)
			--local absoluteDisplacement = rootPartWavePos + waveDisplacement

			-- Check if character is underneath wave
			if rootPart.Position.Y <= waveDisplacement.Y + self._instance.Position.Y then
				if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
					humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
					humanoid:ChangeState(Enum.HumanoidStateType.Swimming, true)
				end
				if not bodyVelocity then
					bodyVelocity = Instance.new("BodyVelocity")
					bodyVelocity.Parent = rootPart
				end
				bodyVelocity.Velocity = humanoid.MoveDirection * humanoid.WalkSpeed
			elseif math.abs(rootPart.Position.Y - waveDisplacement.Y + self._instance.Position.Y) >= 5 then
				-- Disable float if distance is great enough
				print("Disable")
				if bodyVelocity then
					bodyVelocity:Destroy()
					bodyVelocity = nil
					humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
				end
			end
		end
	end)
	table.insert(self._connections, connection)
end

-- Update every bone's transformation
function Wave:Update()
	for _, bone in pairs(self._bones) do
		local worldPos = bone.WorldPosition
		-- Check if PushPoint --> calculate position
		local PushPoint = self._generalSettings.PushPoint
		if PushPoint then
			local PartPos = nil

			if PushPoint:IsA("Attachment") then
				PartPos = PushPoint.WorldPosition
			elseif PushPoint:IsA("BasePart") then
				PartPos = PushPoint.Position
			else
				error("Invalid class for FollowPart, must be a BasePart or an Attachment")
				return
			end

			self._generalSettings.Direction = (PartPos - worldPos).Unit
			self._generalSettings.Direction =
				Vector2.new(self._generalSettings.Direction.X, self._generalSettings.Direction.Z)
		end
		-- If not PushPoint, then Direction is given inside of Settings (Vector2)

		-- Transform bone's position
		bone.Transform = CFrame.new(self:GerstnerWave(Vector2.new(worldPos.X, worldPos.Z)))
	end
end

-- Reset all bone transformations
function Wave:ResetBones()
	for _, v in pairs(self._bones) do
		v.Transform = CFrame.new()
	end
end

-- Connect function to RenderStepped
function Wave:ConnectRenderStepped()
	local Connection = RunService.RenderStepped:Connect(function()
		if not game:IsLoaded() then
			error("Game is not loaded yet.")
		end
		local Character = LocalPlayer.Character
		local Settings = self._generalSettings
		-- Check if bone is close enough
		if
			not Character
			or not Character.PrimaryPart
			or (Character.PrimaryPart.Position - self._instance.Position).Magnitude < Settings.MaxDistance
		then
			self:Update()
		else
			self:ResetBones()
		end
	end)
	table.insert(self._connections, Connection)
	return Connection
end

-- Destroy the Wave "object"
function Wave:Destroy()
	self._instance = nil
	-- Try to disconnect all connections and handle errors
	for _, v in pairs(self._connections) do
		local success, response = pcall(function()
			v:Disconnect()
		end)
		if not success then
			warn("Failed to destroy wave! \nError: " .. response .. " Retrying...")
			local count = 1
			repeat
				count += 1
				success, response = pcall(function()
					v:Disconnect()
				end)
			until success or count >= 10
			warn("Retrying to destory wave, count:", count, "\nError:", response)
		end
	end
	-- Cleanup variables
	self._bones = {}
	self._generalSettings = {}
	self = nil
end

return Wave

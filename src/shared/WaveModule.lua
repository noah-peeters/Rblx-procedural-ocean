local RunService = game:GetService("RunService")
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

function Wave:GerstnerWave(xzPos, settings)
	-- Get settings: from this wave, from generalSettings or from default
	local waveLength = settings.WaveLength or self._generalSettings.WaveLength or default.WaveLength
	local gravity = settings.Gravity or self._generalSettings.Gravity or default.Gravity
	local direction = settings.Direction or self._generalSettings.Direction or default.Direction
	local steepness = settings.Steepness or self._generalSettings.Steepness or default.Steepness
	
	local k = (2 * math.pi) / waveLength
	local speed = math.sqrt(gravity / k)
	local dir = direction.Unit
	local f = k * (dir:Dot(xzPos) - speed * os.clock())

	-- Calculate displacement (direction)
	local amplitude = steepness / k
	local xPos = dir.X * (amplitude * math.cos(f))
	local yPos = amplitude * math.sin(f) -- Y-Position is not affected by direction of wave
	local zPos = dir.Y * (amplitude * math.cos(f))

	return Vector3.new(xPos, yPos, zPos)
end

-- Update every bone's transformation
function Wave:Update()
	for _, bone in pairs(self._bones) do
		-- Calculate bone displacement for every wave
		local finalDisplacement = Vector3.new()
		for _, waveSetting in pairs(self._waveSettings) do
			local WorldPos = bone.WorldPosition
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

				self._generalSettings.Direction = (PartPos - WorldPos).Unit
				self._generalSettings.Direction =
					Vector2.new(self._generalSettings.Direction.X, self._generalSettings.Direction.Z)
			end
			-- If not PushPoint, then Direction is given inside of Settings (Vector2)
			
			finalDisplacement += self:GerstnerWave(Vector2.new(WorldPos.X, WorldPos.Z), waveSetting)
		end
		bone.Transform = CFrame.new(finalDisplacement)
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
			return
		end
		local Character = LocalPlayer.Character
		local Settings = self._generalSettings
		-- Check if bone is close enough
		if
			not Character
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

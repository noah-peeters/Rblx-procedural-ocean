local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Wave = {}
Wave.__index = Wave

local LocalPlayer = Players.LocalPlayer

-- Default wave settings
local default = {
	WaveLength = 80,
	Gravity = 1.8,
	Steepness = 0.15,
	Direction = Vector2.new(0, 0),
	FollowPoint = nil,
	MaxDistance = 1000,
}

-- Helper function for creating settings table (handles warning and error messages)
local function CreateSettings(new: table)
	-- Use given settings or use default settings
	new = new or default

	local settings = default

	if new.WaveLength then
		if typeof(new.WaveLength) == "number" then
			settings.WaveLength = new.WaveLength
		else
			warn("WaveLength is not a number! Using default value.")
		end
	else
		warn("WaveLength is nil! Using default value.")
	end

	if new.Gravity then
		if typeof(new.Gravity) == "number" then
			settings.Gravity = new.Gravity
		else
			warn("Gravity is not a number! Using default value.")
		end
	else
		warn("Gravity is nil! Using default value.")
	end

	if new.Direction then
		if typeof(new.Direction) == "vector2" then
			settings.Direction = new.Direction
		else
			warn("Direction is not a Vector2! Using default value.")
		end
	else
		warn("Direction is nil! Using default value.")
	end

	if new.PushPoint then
		if typeof(new.PushPoint) == "instance" then
			settings.PushPoint = new.PushPoint
		else
			error("PushPoint is not an Instance!")
		end
	else
		warn("PushPoint is nil! Using default value.")
	end

	if new.Steepness then
		if typeof(new.Steepness) == "number" then
			settings.Steepness = new.Steepness
		else
			error("Steepness is not a number!")
		end
	else
		warn("Steepness is nil! Using default value.")
	end

	if new.MaxDistance then
		if typeof(new.MaxDistance) == "number" then
			settings.MaxDistance = new.MaxDistance
		else
			error("MaxDistance is not a number!")
		end
	else
		warn("MaxDistance is nil! Using default value.")
	end
	return settings
end

-- Create a new Wave
function Wave.new(instance: Instance, waveSettings: table | nil, bones: table | nil)
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

	return setmetatable({
		_instance = instance,
		_bones = bones,
		_time = 0,
		_connections = {},
		_noise = {},
		_settings = CreateSettings(waveSettings),
	}, Wave)
end

function Wave:GerstnerWave(xzPos)
	local k = (2 * math.pi) / self._settings.WaveLength
	local speed = math.sqrt(self._settings.Gravity / k)
	local dir = self._settings.Direction.Unit
	local f = k * (dir:Dot(xzPos) - speed * os.clock())

	-- Calculate displacement (direction)
	local amplitude = self._settings.Steepness / k
	local xPos = dir.X * (amplitude * math.cos(f))
	local yPos = amplitude * math.sin(f) -- Y-Position is not affected by direction of wave
	local zPos = dir.Y * (amplitude * math.cos(f))

	return Vector3.new(xPos, yPos, zPos)
end

-- Update every bone's transformation
function Wave:Update()
	for _, v in pairs(self._bones) do
		local WorldPos = v.WorldPosition

		-- Get wave direction (Perlin Noise or Vector2)
		if self._settings.Direction == Vector2.new() then
			-- Use Perlin Noise to calculate wave direction (randomly)
			local Noise = self._noise[v]
			local NoiseX = Noise and self._noise[v].X
			local NoiseZ = Noise and self._noise[v].Z
			local NoiseModifier = 1 -- If you want more of a consistent direction, change this number to something bigger

			if not Noise then
				self._noise[v] = {}
				-- Uses perlin noise to generate smooth transitions between random directions in the waves
				NoiseX = math.noise(WorldPos.X / NoiseModifier, WorldPos.Z / NoiseModifier, 1)
				NoiseZ = math.noise(WorldPos.X / NoiseModifier, WorldPos.Z / NoiseModifier, 0)

				self._noise[v].X = NoiseX
				self._noise[v].Z = NoiseZ
			end

			self._settings.Direction = Vector2.new(NoiseX, NoiseZ)
		else
			-- Check if PushPoint --> calculate position
			local PushPoint = self._settings.PushPoint
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

				self._settings.Direction = (PartPos - WorldPos).Unit
				self._settings.Direction = Vector2.new(self._settings.Direction.X, self._settings.Direction.Z)
			end
			-- If not PushPoint, then Direction is given inside of Settings (Vector2)
		end

		v.Transform = CFrame.new(self:GerstnerWave(Vector2.new(WorldPos.X, WorldPos.Z)))
	end
end

-- Reset all bone transformations
function Wave:ResetBones()
	for _, v in pairs(self._bones) do
		v.Transform = CFrame.new()
	end
end

function Wave:UpdateSettings(waveSettings)
	self._settings = CreateSettings(waveSettings)
end

-- Connect function to RenderStepped
function Wave:ConnectRenderStepped()
	local Connection = RunService.RenderStepped:Connect(function()
		if not game:IsLoaded() then
			return
		end
		local Character = LocalPlayer.Character
		local Settings = self._settings
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
	self._settings = {}
	self = nil
end

return Wave

local RunService = game:GetService("RunService")

local Wave = {}
Wave.__index = Wave

local Player = game:GetService("Players").LocalPlayer

-- Default wave settings
local default = {
	WaveLength = 85,
	Gravity = 1.5,
	Direction = Vector2.new(0, 0),
	FollowPoint = nil,
	Steepness = 1,
	TimeModifier = 4,
	MaxDistance = 1500,
}

-- Function for calculating wave displacement using Gerstner waves
local function Gerstner(Position: Vector3, Wavelength: number, Direction: Vector2, Steepness: number, Gravity: number, Time: number)
	local k = (2 * math.pi) / Wavelength
	local a = Steepness / k
	local d = Direction.Unit
	local c = math.sqrt(Gravity / k)
	local f = k * d:Dot(Vector2.new(Position.X, Position.Z)) - c * Time
	local cosF = math.cos(f)

	--Displacement Vectors
	local dX = (d.X * (a * cosF))
	local dY = a * math.sin(f)
	local dZ = (d.Y * (a * cosF))
	return Vector3.new(dX, dY, dZ)
end

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

	if new.TimeModifier then
		if typeof(new.TimeModifier) == "number" then
			settings.TimeModifier = new.TimeModifier
		else
			error("TimeModifier is not a number!")
		end
	else
		warn("TimeModifier is nil! Using default value.")
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

function Wave.new(instance: Instance, waveSettings: table | nil, bones: table | nil)
	-- Check types
	if typeof(instance) ~= "Instance" then
		error("Instance argument must be a valid instance!")
	end
	if typeof(waveSettings) ~= "table" then
		error("WaveSettings argument must be a table!")
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

-- Update every bone's transformation
function Wave:Update()
	for _, v in pairs(self._bones) do
		local WorldPos = v.WorldPosition
		local Settings = self._settings
		local Direction = Settings.Direction

		-- Get wave direction (Perlin Noise or Vector2)
		if Direction == Vector2.new() then
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

			Direction = Vector2.new(NoiseX, NoiseZ)
		else
			-- Check if PushPoint --> calculate position
			local PushPoint = Settings.PushPoint
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
		
				Direction = (PartPos - WorldPos).Unit
				Direction = Vector2.new(Direction.X, Direction.Z)
			end
			-- If not PushPoint, then Direction is given inside of Settings (Vector2)
		end

		v.Transform =
			CFrame.new(Gerstner(
				WorldPos,
				Settings.WaveLength,
				Direction,
				Settings.Steepness,
				Settings.Gravity,
				self._time
			))
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
		local Character = Player.Character
		local Settings = self._settings
		if
			not Character
			or (Character.PrimaryPart.Position - self._instance.Position).Magnitude < Settings.MaxDistance
		then
			local Time = (DateTime.now().UnixTimestampMillis / 1000) / Settings.TimeModifier
			self._time = Time
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
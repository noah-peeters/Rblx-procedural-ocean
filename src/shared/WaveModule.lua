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
		-- Get bones inside Model
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
		-- Setup (flat) sea models around animated sea
		-- local folder = Instance.new("Folder")
		-- folder.Name = "SeaParts"
		-- folder.Parent = workspace
		-- for i = 1, 8  do
		-- 	local sea = instance:FindFirstChildWhichIsA("MeshPart")
		-- 	if sea then
		-- 		sea = sea:Clone()

		-- 	end
		-- end

		-- Return "Wave" object
		return setmetatable({
			_instance = instance,
			_bones = bones,
			_connections = {},
			_cachedVars = {},
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
	for waveName, _ in pairs(self._waveSettings) do
		-- Calculate cachedVars (if they weren't already calculated)
		if not self._cachedVars[waveName] then
			self:UpdateCachedVars()
		end

		-- Get cached variables (they don't need to be recalculated every frame)
		local cached = self._cachedVars[waveName]
		local k = cached["K"]
		local speed = cached["WaveSpeed"]
		local dir = cached["UnitDirection"]
		local amplitude = cached["Amplitude"]

		local displacement = k * (dir:Dot(xzPos) - speed * os.clock())

		-- Calculate displacement on every axis (xyz)
		local xPos = dir.X * (amplitude * math.cos(displacement))
		local yPos = amplitude * math.sin(displacement) -- Y-Position is not affected by direction of wave
		local zPos = dir.Y * (amplitude * math.cos(displacement))

		finalDisplacement += Vector3.new(xPos, yPos, zPos) -- Add this wave to final displacement
	end
	return finalDisplacement
end

-- Update cached variables used by GerstnerWave function
function Wave:UpdateCachedVars()
	self._cachedVars = {}
	for waveName, waveSetting in pairs(self._waveSettings) do
		-- Get settings: from this wave, from generalSettings or from default
		local waveLength = waveSetting.WaveLength or self._generalSettings.WaveLength or default.WaveLength
		local gravity = waveSetting.Gravity or self._generalSettings.Gravity or default.Gravity
		local direction = waveSetting.Direction or self._generalSettings.Direction or default.Direction
		local steepness = waveSetting.Steepness or self._generalSettings.Steepness or default.Steepness

		-- Variables that don't change on tick
		local k = (2 * math.pi) / waveLength
		local speed = math.sqrt(gravity / k)
		local dir = direction.Unit
		local amplitude = steepness / k

		self._cachedVars[waveName] = {
			K = k,
			WaveSpeed = speed,
			UnitDirection = dir,
			Amplitude = amplitude,
		}
	end
end

-- Make a part float on the waves
function Wave:AddFloatingPart(part)
	local positionDrag = 2500
	local rotationDrag = 1

	if typeof(part) ~= "Instance" then
		error("Part must be a valid Instance.")
	end
	if not self._instance then
		error("Wave object not found!")
	end

	-- Create attachments (on four corners)
	local s = part.Size

	local corners = {
		Vector3.new(s.X / 2, 0, s.Z / 2),
		Vector3.new(s.X / 2, 0, -s.Z / 2),
		Vector3.new(-s.X / 2, 0, s.Z / 2),
		Vector3.new(-s.X / 2, 0, -s.Z / 2),
	}
	local attachments = {}
	-- Create attachments and their VectorForces
	for _, relativePos in pairs(corners) do
		local attach = Instance.new("Attachment")
		attach.Position = relativePos
		attach.Visible = true
		attach.Parent = part

		local force = Instance.new("VectorForce")
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.Attachment0 = attach
		force.Force = Vector3.new(0, 0, 0)
		force.Visible = false
		force.Enabled = true
		force.ApplyAtCenterOfMass = false
		force.Parent = part
		attachments[attach] = force
	end

	-- Water drag force(s)
	local waterDragForce = Instance.new("BodyForce")
	waterDragForce.Force = Vector3.new(0, 0, 0)
	waterDragForce.Parent = part


	-- Attachment at part position
	local attach = Instance.new("Attachment")
	attach.Parent = part

	local waterDragTorque = Instance.new("Torque")
	waterDragTorque.Attachment0 = attach
	waterDragTorque.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	waterDragTorque.Enabled = false
	waterDragTorque.Parent = part


	--local waterDragTorque = Instance.new("BodyAngularVelocity")
	--waterDragTorque.AngularVelocity = Vector3.new(0, 0, 0)
	--local max = part.AssemblyMass * 125
	--waterDragTorque.MaxTorque = Vector3.new(max, max, max)
	--waterDragTorque.P = math.huge
	--waterDragTorque.Parent = part

	local gravity = workspace.Gravity / 4 -- Force of gravity per attachment

	RunService.Stepped:Connect(function()
		-- Wave height at part's xz-position
		local waveHeight = self._instance.Position.Y
			+ self:GerstnerWave(Vector2.new(part.Position.X, part.Position.Z)).Y

		local depthBeforeSubmerged = 1
		local displacementAmount = 3
		local displacementModifier =
			math.clamp((waveHeight - part.Position.Y) / depthBeforeSubmerged * displacementAmount, 0, 1)

		-- Water drag force on part
		if math.abs(part.Position.Y - waveHeight) > 5 and part.Position.Y > waveHeight then
			-- Disable drag (part is above wave)
			waterDragForce.Force = Vector3.new(0, 0, 0)
			--waterDragTorque.AngularVelocity = Vector3.new(0, 0, 0)
			waterDragTorque.Enabled = false
		else
			-- Update drag forces
			waterDragForce.Force = -part.Velocity * displacementModifier * positionDrag

			waterDragTorque.Enabled = true
			waterDragTorque.Torque = (-part.AssemblyAngularVelocity * part.AssemblyMass) * displacementModifier * rotationDrag
			--waterDragTorque.AngularVelocity = -part.AssemblyAngularVelocity * displacementModifier * rotationDrag
		end

		-- Force per attachment
		for attachment, force in pairs(attachments) do
			local p = attachment.WorldPosition
			-- Recalculate wave height at the attachment's position
			waveHeight = self._instance.Position.Y + self:GerstnerWave(Vector2.new(p.X, p.Z)).Y

			-- Set force of attachment
			local destPos
			if p.Y < waveHeight then -- Check if attachment is under water
				-- * Buoyancy force is calculated without gravity!!
				-- * Gravity * mass must be added to it!!
				local grav = gravity * part.AssemblyMass
				destPos = Vector3.new(0, (grav + gravity * part.AssemblyMass) * displacementModifier, 0)
			else
				-- Disable force
				destPos = Vector3.new(0, 0, 0)
			end

			force.Force = destPos
		end
	end)
end

function Wave:AddPlayerFloat(player)
	local char = player.Character or player.CharacterAdded:Wait()
	--player.CharacterAppearanceLoaded:Wait()
	print("done waiting")
	local rootPart = char:WaitForChild("HumanoidRootPart")
	local humanoid = char:WaitForChild("Humanoid")

	-- Setup BodyForces
	local dirVelocity
	local floatPosition = Instance.new("BodyPosition")
	floatPosition.D = 1250
	floatPosition.MaxForce = Vector3.new(0, 0, 0)
	floatPosition.P = 10000
	floatPosition.Parent = rootPart

	-- Rootpart position at wave height
	local rootPartWavePos = Vector3.new(rootPart.Position.X, self._instance.Position.Y, rootPart.Position.Z)
	local xzPos = Vector2.new(rootPart.Position.X, rootPart.Position.Z)

	local connection = RunService.Heartbeat:Connect(function()
		if rootPart then
			local waveDisplacement = self:GerstnerWave(xzPos)
			local absoluteDisplacement = rootPartWavePos + waveDisplacement

			-- Check if character is underneath wave
			if rootPart.Position.Y <= waveDisplacement.Y + self._instance.Position.Y then
				if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
					humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
					humanoid:ChangeState(Enum.HumanoidStateType.Swimming, true)
				end
				-- Entered water
				if not dirVelocity then
					-- Create direction BodyVelocity
					dirVelocity = Instance.new("BodyVelocity")
					dirVelocity.Parent = rootPart
				end
				-- Only float up if no movement input
				if humanoid.MoveDirection == Vector3.new(0, 0, 0) then
					print("Enable float")
					-- Enable float
					local force = rootPart.AssemblyMass * workspace.Gravity * 25
					floatPosition.MaxForce = Vector3.new(force, force, force)
				else
					print("Disable float")
					-- Disable float
					floatPosition.MaxForce = Vector3.new(0, 0, 0)
				end
				dirVelocity.Velocity = humanoid.MoveDirection * humanoid.WalkSpeed
				floatPosition.Position = Vector3.new(
					absoluteDisplacement.X + rootPart.Position.X,
					absoluteDisplacement.Y,
					absoluteDisplacement.Z + rootPart.Position.Z
				)
			elseif math.abs(rootPart.Position.Y - waveDisplacement.Y + self._instance.Position.Y) >= 5 then
				-- Disable float if distance is great enough
				if dirVelocity then
					dirVelocity:Destroy()
					dirVelocity = nil
					humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
					floatPosition.MaxForce = Vector3.new(0, 0, 0)
				end
			end
		end
	end)
	table.insert(self._connections, connection)
end

-- Connect function to RenderStepped
function Wave:ConnectRenderStepped()
	local connection = RunService.RenderStepped:Connect(function()
		-- Update every bone's transformation
		debug.profilebegin("Update all bones of ocean")
		for _, bone in pairs(self._bones) do
			-- Check if bone is close enough to character
			local worldPos = bone.WorldPosition
			local char = LocalPlayer.Character
			if not char then
				return
			end
			local rootPart = char:FindFirstChild("HumanoidRootPart")
			if rootPart and (rootPart.Position - worldPos).Magnitude <= self._generalSettings.MaxDistance then
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

				-- Transform bone
				bone.Transform = CFrame.new(self:GerstnerWave(Vector2.new(worldPos.X, worldPos.Z)))
			end
		end
		debug.profileend()
	end)
	table.insert(self._connections, connection)

	return connection
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

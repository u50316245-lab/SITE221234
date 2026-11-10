--[[
	Пыль в воздухе (клиент): объём частиц вокруг камеры. Частицы освещаются только
	светом мира (LightInfluence = 1), поэтому видны лишь в луче фонарика и под лампами.
]]
local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Settings)

local AmbientDust = {}
local started = false

local RATE_BY_QUALITY = { 0, 22, 42 }

function AmbientDust.start()
	if started then
		return
	end
	started = true

	local volume = Instance.new("Part")
	volume.Name = "P13_Dust"
	volume.Anchored = true
	volume.CanCollide = false
	volume.CanQuery = false
	volume.CanTouch = false
	volume.CastShadow = false
	volume.Transparency = 1
	volume.Size = Vector3.new(40, 16, 40)
	volume.Parent = workspace.CurrentCamera

	local pe = Instance.new("ParticleEmitter")
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.Lifetime = NumberRange.new(6, 10)
	pe.Speed = NumberRange.new(0.05, 0.3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0, -0.025, 0)
	pe.Drag = 0.5
	pe.RotSpeed = NumberRange.new(-30, 30)
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.15, 0.05),
		NumberSequenceKeypoint.new(0.85, 0.04),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(0.8, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Color = ColorSequence.new(Color3.fromRGB(235, 228, 210))
	pe.LightInfluence = 1
	pe.LightEmission = 0
	pe.Brightness = 2
	pe.Parent = volume

	local function apply()
		pe.Rate = RATE_BY_QUALITY[Settings.get("quality")] or 0
		pe.Enabled = pe.Rate > 0
	end
	Settings.Changed:Connect(apply)
	apply()

	RunService.Heartbeat:Connect(function()
		local cam = workspace.CurrentCamera
		if cam then
			volume.CFrame = CFrame.new(cam.CFrame.Position)
			if volume.Parent ~= cam then
				volume.Parent = cam
			end
		end
	end)
	return volume
end

return AmbientDust

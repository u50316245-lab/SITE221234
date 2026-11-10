--[[
	Процедурная камера от первого лица (клиент).
	Поверх стандартной камеры Roblox добавляет только повороты:
	  · крен при стрейфе и при резком повороте мышью;
	  · дыхание в покое, дрожь от страха;
	  · «травма»-тряска на шумe Перлина (шаги монстра, удары, скример);
	  · проседание камеры при приземлении.
	Смещение снимается перед кадром камеры Roblox и накладывается после,
	поэтому взгляд игрока никогда не «уплывает».
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Settings = require(script.Parent.Settings)

local CameraFX = {}
CameraFX.enabled = true
CameraFX.fear = 0 -- 0..1, выставляет клиент раунда

local player = Players.LocalPlayer
local started = false
local trauma = 0
local applied = CFrame.identity
local hasApplied = false
local t = 0

-- пружина с критическим демпфированием
local function spring(freq, damping)
	return { x = 0, v = 0, target = 0, f = freq, d = damping }
end
local function stepSpring(s, dt)
	local w = s.f * 2 * math.pi
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for _ = 1, steps do
		local a = w * w * (s.target - s.x) - 2 * s.d * w * s.v
		s.v += a * h
		s.x += s.v * h
	end
	return s.x
end

local roll = spring(3.2, 0.75)
local sway = spring(4, 0.7)
local kick = spring(5, 0.45)

function CameraFX.addTrauma(amount)
	trauma = math.clamp(trauma + amount, 0, 1)
end

-- мгновенный толчок камеры (рад): pitch вниз положительный
function CameraFX.kick(pitch)
	kick.v += pitch * 25
end

local function isActive(cam)
	return CameraFX.enabled and cam.CameraType == Enum.CameraType.Custom
end

function CameraFX.start()
	if started then
		return
	end
	started = true

	local function hookCharacter(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if not hum or not hum:IsA("Humanoid") then
			return
		end
		local fallSpeed = 0
		hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Freefall then
				fallSpeed = 0
			elseif new == Enum.HumanoidStateType.Landed then
				local k = math.clamp(fallSpeed / 60, 0.15, 1)
				CameraFX.kick(0.05 * k)
				CameraFX.addTrauma(0.12 * k)
			end
		end)
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if not hum.Parent then
				conn:Disconnect()
				return
			end
			local root = hum.RootPart
			if root and hum:GetState() == Enum.HumanoidStateType.Freefall then
				fallSpeed = math.max(fallSpeed, -root.AssemblyLinearVelocity.Y)
			end
		end)
	end
	if player.Character then
		task.spawn(hookCharacter, player.Character)
	end
	player.CharacterAdded:Connect(hookCharacter)

	-- до камеры Roblox: убираем прошлое смещение, чтобы она считала «чистый» взгляд
	RunService:BindToRenderStep("P13_CameraFX_Pre", Enum.RenderPriority.Camera.Value - 1, function()
		local cam = workspace.CurrentCamera
		if hasApplied and cam and isActive(cam) then
			cam.CFrame = cam.CFrame * applied:Inverse()
		end
		hasApplied = false
	end)

	-- после камеры Roblox: накладываем новое смещение
	RunService:BindToRenderStep("P13_CameraFX_Post", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local cam = workspace.CurrentCamera
		if not cam or not isActive(cam) then
			trauma = 0
			return
		end
		t += dt
		local shakeScale = Settings.get("shake")
		local fear = math.clamp(CameraFX.fear, 0, 1)

		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local localVel = Vector3.zero
		if root and root:IsA("BasePart") then
			localVel = cam.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
		end

		-- крен от стрейфа и от поворота мышью
		local mouseDelta = UserInputService:GetMouseDelta()
		roll.target = math.clamp(-localVel.X * 0.0026, -0.045, 0.045)
		sway.target = math.clamp(-mouseDelta.X * 0.0011, -0.035, 0.035)
		local r = stepSpring(roll, dt) + stepSpring(sway, dt)
		local k = stepSpring(kick, dt)

		-- дыхание и дрожь
		local breath = 1 + fear * 2.5
		local pitch = math.sin(t * 1.55) * 0.0022 * breath + k
		local yaw = math.sin(t * 0.77) * 0.0016 * breath
		if fear > 0.05 then
			pitch += math.noise(t * 7, 11.3) * 0.006 * fear
			yaw += math.noise(t * 7, 23.9) * 0.006 * fear
		end

		-- травма
		trauma = math.max(0, trauma - dt * 0.85)
		local s = trauma * trauma * shakeScale
		if s > 0 then
			pitch += math.noise(t * 19, 1.7) * 0.07 * s
			yaw += math.noise(t * 19, 5.1) * 0.07 * s
			r += math.noise(t * 19, 9.4) * 0.09 * s
		end

		applied = CFrame.Angles(-pitch, yaw, r * math.max(shakeScale, 0.35))
		cam.CFrame = cam.CFrame * applied
		hasApplied = true
	end)
end

return CameraFX

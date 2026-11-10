--[[
	Кинематографичная пост-обработка (клиент).
	Слои поверх базового грейда плейса:
	  · автофокус глубины резкости по тому, куда смотрит камера;
	  · motion blur от скорости поворота камеры;
	  · «страх»: обесцвечивание, контраст и красный оттенок, когда Пациент рядом;
	  · адаптация глаз к темноте (экспозиция медленно растёт без фонарика);
	  · пресеты качества: тени ламп, bloom, DOF и blur включаются по уровню.
]]
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Settings)

local PostFX = {}

local player = Players.LocalPlayer
local started = false

local fearTarget, fear = 0, 0
local adaptTarget, adapt = 0, 0
local focusOverride = nil
local focus = 28
local rayTarget = 28
local blurAmount = 0
local lastLook = nil
local frame = 0
local motionBlurAllowed = true

local bloom, dof, fearCC, blur
local base = { exposure = 0, farIntensity = 0.18, bloom = 0 }
local shadowLights = {}
local excluded = {}

local function ensure(className, name)
	local e = Lighting:FindFirstChild(name)
	if not e or not e:IsA(className) then
		e = Instance.new(className)
		e.Name = name
		e.Parent = Lighting
	end
	return e
end

local function applyQuality()
	local q = Settings.get("quality")
	if bloom then
		bloom.Enabled = q >= 2
	end
	if dof then
		dof.Enabled = q >= 2 and Settings.get("dof")
	end
	-- тени ламп — самая дорогая часть кадра на слабых устройствах
	for light, original in pairs(shadowLights) do
		if light.Parent then
			light.Shadows = original and q >= 2
		end
	end
end

-- options.lightsRoot — папка с лампами карты; options.exposure — базовая экспозиция
function PostFX.start(options)
	if started then
		return
	end
	started = true
	options = options or {}

	bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect") or ensure("DepthOfFieldEffect", "DepthOfField")
	fearCC = ensure("ColorCorrectionEffect", "P13_Fear")
	blur = ensure("BlurEffect", "P13_MotionBlur")
	blur.Size = 0

	base.exposure = Lighting.ExposureCompensation
	base.farIntensity = dof.FarIntensity > 0 and dof.FarIntensity or 0.18
	base.bloom = bloom and bloom.Intensity or 0

	if options.lightsRoot then
		for _, d in ipairs(options.lightsRoot:GetDescendants()) do
			if d:IsA("Light") and d.Shadows then
				shadowLights[d] = true
			end
		end
	end

	Settings.Changed:Connect(applyQuality)
	applyQuality()

	RunService:BindToRenderStep("P13_PostFX", Enum.RenderPriority.Last.Value, function(dt)
		PostFX._update(dt)
	end)
end

-- не наводить автофокус на эти объекты (фонарик, частицы и т.п.)
function PostFX.exclude(inst)
	table.insert(excluded, inst)
end

function PostFX.setFear(k)
	fearTarget = math.clamp(k, 0, 1)
end

function PostFX.setAdaptation(k)
	adaptTarget = math.clamp(k, 0, 1)
end

-- зафиксировать фокус на дистанции (меню, катсцены); nil = автофокус
function PostFX.setFocus(distance)
	focusOverride = distance
end

function PostFX.setMotionBlurAllowed(on)
	motionBlurAllowed = on
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

function PostFX._update(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	frame += 1
	local q = Settings.get("quality")

	-- страх
	fear += (fearTarget - fear) * math.min(1, dt * 2.2)
	fearCC.Saturation = -0.5 * fear
	fearCC.Contrast = 0.18 * fear
	fearCC.Brightness = -0.03 * fear
	fearCC.TintColor = Color3.new(1, 1 - 0.16 * fear, 1 - 0.2 * fear)
	if bloom then
		bloom.Intensity = base.bloom * (1 + fear * 0.35)
	end

	-- адаптация к темноте: медленно привыкаем, быстро слепнем обратно
	local rate = adaptTarget > adapt and 0.22 or 1.6
	adapt += (adaptTarget - adapt) * math.min(1, dt * rate)
	Lighting.ExposureCompensation = base.exposure + adapt * 0.3 - fear * 0.08

	-- автофокус (луч раз в 3 кадра, сглаживание каждый кадр)
	if dof and dof.Enabled then
		if focusOverride then
			rayTarget = focusOverride
		elseif frame % 3 == 0 then
			local filter = { cam }
			if player.Character then
				table.insert(filter, player.Character)
			end
			for _, e in ipairs(excluded) do
				table.insert(filter, e)
			end
			rayParams.FilterDescendantsInstances = filter
			local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 220, rayParams)
			rayTarget = hit and hit.Distance or 220
		end
		focus += (rayTarget - focus) * math.min(1, dt * 5)
		dof.FocusDistance = focus
		dof.InFocusRadius = math.clamp(focus * 0.75, 10, 60)
		dof.FarIntensity = math.clamp(base.farIntensity + fear * 0.12, 0, 1)
		dof.NearIntensity = 0
	end

	-- motion blur по угловой скорости камеры
	local look = cam.CFrame.LookVector
	local want = 0
	if lastLook and dt > 0 and q >= 3 and Settings.get("motionBlur") and motionBlurAllowed then
		local angle = math.acos(math.clamp(look:Dot(lastLook), -1, 1))
		local speed = angle / dt -- рад/с
		want = math.clamp((speed - 2.2) * 1.6, 0, 8)
	end
	lastLook = look
	blurAmount += (want - blurAmount) * math.min(1, dt * 14)
	blur.Size = blurAmount < 0.3 and 0 or blurAmount
end

return PostFX

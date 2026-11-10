--[[
	Экран загрузки (ReplicatedFirst): заменяет стандартный, показывает
	предупреждение о вспышках и совет про наушники при первом входе,
	реальный прогресс загрузки ассетов и советы. Уходит, когда готов интерфейс плейса.
]]
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TIPS = {
	"Пациент слышит бег. Если он рядом — иди шагом.",
	"Луч фонарика видно издалека. Иногда темнота — твой друг.",
	"В шкафчике можно переждать погоню. Но не вечно.",
	"Батарейки лежат в палатах. Береги заряд.",
	"Аварийные лампы мигают быстрее, когда генератор работает.",
	"Если свет начал мигать без причины — оно уже близко.",
	"Предохранитель несут в генераторную. Только один за раз.",
	"Мерцание, тряску камеры и субтитры можно настроить (в больнице — клавиша P).",
}

local FONT_TITLE = Enum.Font.Oswald
local FONT_MONO = Enum.Font.RobotoMono

local arrivingGui = TeleportService:GetArrivingTeleportGui()
local teleported = arrivingGui ~= nil or TeleportService:GetLocalPlayerTeleportData() ~= nil

local gui = Instance.new("ScreenGui")
gui.Name = "P13_Loading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local root = Instance.new("CanvasGroup")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.new(0, 0, 0)
root.BorderSizePixel = 0
root.Parent = gui

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.fromRGB(222, 212, 200)
	l.Font = FONT_MONO
	l.TextSize = 16
	l.TextWrapped = true
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = props.Parent or root
	return l
end

-- 1) предупреждение (только при первом входе, не после телепорта)
local warning = Instance.new("Frame")
warning.Size = UDim2.fromScale(1, 1)
warning.BackgroundTransparency = 1
warning.Visible = not teleported
warning.Parent = root
label({
	Parent = warning,
	Text = "ВНИМАНИЕ",
	Font = FONT_TITLE,
	TextSize = 34,
	TextColor3 = Color3.fromRGB(235, 40, 40),
	Size = UDim2.new(1, 0, 0, 40),
	Position = UDim2.fromScale(0, 0.36),
})
label({
	Parent = warning,
	Text = "В игре есть мерцающий свет, резкие вспышки и громкие звуки.\nМерцание, вспышки и тряску камеры можно отключить в настройках.",
	TextSize = 17,
	Size = UDim2.new(0.7, 0, 0, 60),
	Position = UDim2.new(0.15, 0, 0.36, 52),
})
label({
	Parent = warning,
	Text = "🎧  играй в наушниках",
	TextSize = 15,
	TextColor3 = Color3.fromRGB(125, 115, 110),
	Size = UDim2.new(1, 0, 0, 24),
	Position = UDim2.new(0, 0, 0.36, 130),
})

-- 2) основной экран загрузки
local main = Instance.new("CanvasGroup")
main.Size = UDim2.fromScale(1, 1)
main.BackgroundTransparency = 1
main.GroupTransparency = teleported and 0 or 1
main.Parent = root

label({
	Parent = main,
	Text = "ПАЛАТА 13",
	Font = FONT_TITLE,
	TextSize = 64,
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.fromOffset(600, 70),
	Position = UDim2.new(0.06, 0, 1, -230),
})
local status = label({
	Parent = main,
	Text = teleported and "ВХОД В КОРПУС" or "ЗАГРУЗКА",
	TextSize = 15,
	TextColor3 = Color3.fromRGB(150, 14, 14),
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.fromOffset(600, 20),
	Position = UDim2.new(0.06, 4, 1, -158),
})
local tip = label({
	Parent = main,
	Text = TIPS[math.random(1, #TIPS)],
	TextSize = 16,
	TextColor3 = Color3.fromRGB(125, 115, 110),
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(0.6, 0, 0, 40),
	Position = UDim2.new(0.06, 4, 1, -128),
})
local barBack = Instance.new("Frame")
barBack.Size = UDim2.new(0.88, 0, 0, 2)
barBack.Position = UDim2.new(0.06, 0, 1, -64)
barBack.BackgroundColor3 = Color3.fromRGB(30, 14, 14)
barBack.BorderSizePixel = 0
barBack.Parent = main
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
barFill.BorderSizePixel = 0
barFill.Parent = barBack
local percent = label({
	Parent = main,
	Text = "0%",
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Right,
	Size = UDim2.fromOffset(100, 20),
	Position = UDim2.new(0.94, -100, 1, -90),
})

gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()
if arrivingGui then
	arrivingGui:Destroy()
end

local t0 = os.clock()
local alive = true
local shown = 0
local maxQueue = 1

local conn = RunService.RenderStepped:Connect(function(dt)
	local queue = ContentProvider.RequestQueueSize
	maxQueue = math.max(maxQueue, queue)
	local target = (1 - queue / maxQueue) * (game:IsLoaded() and 1 or 0.85)
	shown += (math.max(shown, target) - shown) * math.min(1, dt * 4)
	barFill.Size = UDim2.fromScale(shown, 1)
	percent.Text = math.floor(shown * 100) .. "%"
	-- лёгкое «дыхание» полосы
	barFill.BackgroundTransparency = 0.15 + math.sin(os.clock() * 4) * 0.15
end)

task.spawn(function()
	while alive do
		task.wait(4.5)
		if not alive then
			break
		end
		TweenService:Create(tip, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		tip.Text = TIPS[math.random(1, #TIPS)]
		TweenService:Create(tip, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	end
end)

if not teleported then
	task.wait(3.2)
	TweenService:Create(warning, TweenInfo.new(0.6), { Position = UDim2.fromScale(0, -0.03) }):Play()
	for _, d in ipairs(warning:GetChildren()) do
		if d:IsA("TextLabel") then
			TweenService:Create(d, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end
	task.wait(0.4)
	TweenService:Create(main, TweenInfo.new(0.8), { GroupTransparency = 0 }):Play()
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end
-- ждём, пока клиент плейса построит свой интерфейс (лобби: LobbyUI, больница: HUD)
local waited = 0
while waited < 20 and not (playerGui:FindFirstChild("LobbyUI") or playerGui:FindFirstChild("HUD")) do
	waited += task.wait(0.1)
end
while os.clock() - t0 < (teleported and 1.5 or 5) do
	task.wait(0.1)
end
status.Text = "ГОТОВО"
shown = 1
task.wait(0.4)

alive = false
local fade = TweenService:Create(root, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
fade:Play()
fade.Completed:Wait()
conn:Disconnect()
gui:Destroy()

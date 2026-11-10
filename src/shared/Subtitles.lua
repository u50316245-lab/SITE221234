--[[
	Субтитры звуков (клиент). Следит за звуками из Config.Sounds по имени инстанса
	(Sound.make называет звук ключом) — и клиентскими, и серверными — и подписывает
	то, что игрок реально слышит рядом. Выключаются в настройках.
]]
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local Settings = require(script.Parent.Settings)
local UI = require(script.Parent.UI)

local Subtitles = {}

Subtitles.Captions = {
	Whisper = { "[шёпот прямо за спиной]", Color3.fromRGB(200, 190, 255) },
	MetalBang = { "[где-то лязгнул металл]", nil },
	MonsterScream = { "[нечеловеческий вопль]", Color3.fromRGB(255, 90, 90) },
	MonsterStep = { "[тяжёлые шаги рядом]", Color3.fromRGB(255, 150, 150) },
	MonsterBreath = { "[хриплое дыхание]", Color3.fromRGB(255, 150, 150) },
	ChaseSting = { "[оно тебя заметило]", Color3.fromRGB(255, 70, 70) },
	GeneratorOn = { "[генератор с рёвом заводится]", Color3.fromRGB(235, 185, 70) },
	FuseInsert = { "[щелчок предохранителя]", nil },
	Static = { "[треск помех]", nil },
	Pickup = { "[подобрано]", nil },
}

local holder = nil
local lastShown = {}

local function soundPosition(s)
	local p = s.Parent
	if p and p:IsA("BasePart") then
		return p.Position
	elseif p and p:IsA("Attachment") then
		return p.WorldPosition
	end
	return nil
end

function Subtitles.show(text, color, duration)
	if not holder or not Settings.get("subtitles") then
		return
	end
	local now = os.clock()
	if lastShown[text] and now - lastShown[text] < 3.5 then
		return
	end
	lastShown[text] = now
	local lines = {}
	for _, c in ipairs(holder:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(lines, c)
		end
	end
	if #lines >= 3 then
		table.sort(lines, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		lines[1]:Destroy()
	end
	local label = UI.label({
		Text = text,
		Font = UI.FontMono,
		TextSize = 17,
		TextColor3 = color or UI.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutomaticSize = Enum.AutomaticSize.XY,
		TextWrapped = false,
		Size = UDim2.fromOffset(0, 0),
		LayoutOrder = math.floor(now * 1000) % 1000000000,
		TextTransparency = 1,
		ZIndex = 40,
		Parent = holder,
	})
	UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 3),
		Parent = label,
	})
	UI.corner(3).Parent = label
	UI.tween(label, 0.2, { TextTransparency = 0 })
	task.delay(duration or 3.2, function()
		if label.Parent then
			UI.tween(label, 0.5, { TextTransparency = 1, BackgroundTransparency = 1 })
			task.wait(0.55)
			label:Destroy()
		end
	end)
end

local function watch(s)
	if not s:IsA("Sound") then
		return
	end
	local caption = Subtitles.Captions[s.Name]
	if not caption then
		return
	end
	local function onPlay()
		local pos = soundPosition(s)
		local cam = workspace.CurrentCamera
		if pos and cam and (pos - cam.CFrame.Position).Magnitude > s.RollOffMaxDistance * 0.6 then
			return
		end
		Subtitles.show(caption[1], caption[2])
	end
	s.Played:Connect(onPlay)
	if s.IsPlaying then
		onPlay()
	end
end

function Subtitles.start(screenGui)
	if holder then
		return
	end
	holder = UI.new("Frame", {
		Name = "Subtitles",
		Size = UDim2.new(0.8, 0, 0, 96),
		Position = UDim2.new(0.5, 0, 1, -118),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = screenGui,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for _, root in ipairs({ workspace, SoundService }) do
		for _, d in ipairs(root:GetDescendants()) do
			watch(d)
		end
		root.DescendantAdded:Connect(watch)
	end
	local _ = Players
end

return Subtitles

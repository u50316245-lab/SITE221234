--[[
	Окно настроек с вкладками (ЗВУК / ГРАФИКА / ИГРА) — общее для лобби и больницы.
	Всё пишет в модуль Settings, тот сохраняет в профиль игрока.
]]
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.UI)
local Settings = require(script.Parent.Settings)

local SettingsMenu = {}
local Colors = UI.Colors

local QUALITY_NAMES = { "НИЗКО", "СРЕДНЕ", "УЛЬТРА" }

-- options.footer = true — внизу метка для статистики (api.footer)
function SettingsMenu.build(parentGui, options)
	options = options or {}
	local win = UI.window(parentGui, "НАСТРОЙКИ", UDim2.fromOffset(640, 500))
	local refreshers = {}

	local tabsBar = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = win.content,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local pages = {}
	local tabButtons = {}
	local function showTab(id)
		for k, page in pairs(pages) do
			page.Visible = k == id
		end
		for k, b in pairs(tabButtons) do
			b.BackgroundColor3 = k == id and Color3.fromRGB(120, 18, 18) or Colors.Panel2
		end
	end
	local function page(id, title, order)
		local p = UI.new("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, options.footer and -110 or -50),
			Position = UDim2.fromOffset(0, 50),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Colors.Red,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			Parent = win.content,
		}, { UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		pages[id] = p
		tabButtons[id] = UI.button({
			Text = title,
			TextSize = 18,
			Size = UDim2.fromOffset(150, 36),
			LayoutOrder = order,
			Parent = tabsBar,
		}, function()
			showTab(id)
		end)
		return p
	end

	local function row(parent, order, labelText, hint)
		local r = UI.new("Frame", {
			Size = UDim2.new(1, -8, 0, hint and 52 or 42),
			BackgroundColor3 = Colors.Panel2,
			BackgroundTransparency = 0.5,
			LayoutOrder = order,
			Parent = parent,
		}, { UI.corner(3) })
		UI.label({
			Text = labelText,
			Font = UI.FontBold,
			TextSize = 17,
			Size = UDim2.new(0.5, -12, 0, 24),
			Position = UDim2.fromOffset(12, hint and 5 or 9),
			Parent = r,
		})
		if hint then
			UI.label({
				Text = hint,
				Font = UI.FontMono,
				TextSize = 12,
				TextColor3 = Colors.Dim,
				Size = UDim2.new(0.5, -12, 0, 18),
				Position = UDim2.fromOffset(12, 29),
				Parent = r,
			})
		end
		return r
	end

	-- ползунок: клик/перетаскивание по полосе + кнопки − и +
	local function slider(parent, order, labelText, key, formatValue, hint)
		local schema = Settings.Schema[key]
		local min, max = schema[2], schema[3]
		local nudge = (max - min) / 10
		local r = row(parent, order, labelText, hint)
		local bar = UI.new("TextButton", {
			AutoButtonColor = false,
			Text = "",
			Size = UDim2.new(0.5, -150, 0, 8),
			Position = UDim2.new(0.5, 40, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(30, 14, 14),
			BorderSizePixel = 0,
			Parent = r,
		}, { UI.corner(4) })
		local fill = UI.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Colors.Red,
			BorderSizePixel = 0,
			Parent = bar,
		}, { UI.corner(4) })
		local knob = UI.new("Frame", {
			Size = UDim2.fromOffset(14, 14),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			BackgroundColor3 = Colors.Text,
			Parent = bar,
		}, { UI.corner(7) })
		local valueLabel = UI.label({
			Font = UI.FontMono,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(60, 30),
			Position = UDim2.new(1, -96, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Parent = r,
		})
		local function refresh()
			local v = Settings.get(key)
			local a = (v - min) / (max - min)
			fill.Size = UDim2.fromScale(a, 1)
			knob.Position = UDim2.fromScale(a, 0.5)
			valueLabel.Text = formatValue(v)
		end
		local function setFromX(x)
			local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
			Settings.set(key, min + a * (max - min))
		end
		local dragging = false
		bar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setFromX(input.Position.X)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setFromX(input.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		UI.button({ Text = "−", TextSize = 20, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0.5, 4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = r }, function()
			Settings.set(key, Settings.get(key) - nudge)
		end)
		UI.button({ Text = "+", TextSize = 20, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -34, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = r }, function()
			Settings.set(key, Settings.get(key) + nudge)
		end)
		table.insert(refreshers, refresh)
	end

	local function toggle(parent, order, labelText, key, hint)
		local r = row(parent, order, labelText, hint)
		local b
		b = UI.button({
			Text = "",
			TextSize = 16,
			Size = UDim2.fromOffset(150, 32),
			Position = UDim2.new(1, -162, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Parent = r,
		}, function()
			Settings.set(key, not Settings.get(key))
		end)
		table.insert(refreshers, function()
			local on = Settings.get(key)
			b.Text = on and "ВКЛ" or "ВЫКЛ"
			b.TextColor3 = on and Colors.Text or Colors.Dim
		end)
	end

	local function choice(parent, order, labelText, key, names, hint)
		local r = row(parent, order, labelText, hint)
		local buttons = {}
		for i, name in ipairs(names) do
			buttons[i] = UI.button({
				Text = name,
				TextSize = 15,
				Size = UDim2.fromOffset(92, 32),
				Position = UDim2.new(1, -12 - (#names - i + 1) * 98, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Parent = r,
			}, function()
				Settings.set(key, i)
			end)
		end
		table.insert(refreshers, function()
			for i, b in ipairs(buttons) do
				local sel = Settings.get(key) == i
				b.BackgroundColor3 = sel and Color3.fromRGB(120, 18, 18) or Colors.Panel2
				b.TextColor3 = sel and Colors.Text or Colors.Dim
			end
		end)
	end

	local pct = function(v)
		return math.floor(v * 100 + 0.5) .. "%"
	end

	local audio = page("audio", "ЗВУК", 1)
	slider(audio, 1, "ОБЩАЯ ГРОМКОСТЬ", "master", pct)
	slider(audio, 2, "МУЗЫКА И ЭМБИЕНТ", "music", pct)
	slider(audio, 3, "ЭФФЕКТЫ", "sfx", pct, "шаги, монстр, двери, интерфейс")
	toggle(audio, 4, "СУБТИТРЫ ЗВУКОВ", "subtitles", "подписи к важным звукам")

	local video = page("video", "ГРАФИКА", 2)
	choice(video, 1, "КАЧЕСТВО", "quality", QUALITY_NAMES, "тени ламп, bloom, пыль, размытие")
	toggle(video, 2, "ГЛУБИНА РЕЗКОСТИ", "dof", "автофокус как у кинокамеры")
	toggle(video, 3, "РАЗМЫТИЕ В ДВИЖЕНИИ", "motionBlur", "только на «ультра»")
	toggle(video, 4, "ЗЕРНО ПЛЁНКИ", "grain")
	toggle(video, 5, "МЕРЦАНИЕ И ВСПЫШКИ", "flicker", "лампы, фонарик, стробоскоп скримера")

	local gameplay = page("game", "ИГРА", 3)
	slider(gameplay, 1, "ПОЛЕ ЗРЕНИЯ", "fov", function(v)
		return tostring(math.floor(v + 0.5)) .. "°"
	end)
	slider(gameplay, 2, "ТРЯСКА КАМЕРЫ", "shake", pct, "0% — для тех, кого укачивает")

	local api = { window = win }
	if options.footer then
		api.footer = UI.label({
			Text = "",
			Font = UI.FontMono,
			TextSize = 14,
			TextColor3 = Colors.Dim,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 54),
			Position = UDim2.new(0, 0, 1, -54),
			Parent = win.content,
		})
	end

	function api.refresh()
		for _, f in ipairs(refreshers) do
			f()
		end
	end
	Settings.Changed:Connect(api.refresh)
	showTab("audio")
	api.refresh()
	return api
end

return SettingsMenu

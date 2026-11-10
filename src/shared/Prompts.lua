--[[
	Свои подсказки взаимодействия вместо стандартных ProximityPrompt (клиент):
	клавиша в рамке, действие, объект и полоса удержания. Работает с клавиатурой,
	геймпадом и тачем (на тач-экране по подсказке можно нажать).
]]
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local UI = require(script.Parent.UI)
local Sound = require(script.Parent.Sound)

local Prompts = {}
local started = false

local GAMEPAD_LABELS = {
	[Enum.KeyCode.ButtonX] = "X",
	[Enum.KeyCode.ButtonY] = "Y",
	[Enum.KeyCode.ButtonA] = "A",
	[Enum.KeyCode.ButtonB] = "B",
	[Enum.KeyCode.ButtonL1] = "LB",
	[Enum.KeyCode.ButtonR1] = "RB",
}

local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "●"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return GAMEPAD_LABELS[prompt.GamepadKeyCode] or "X"
	end
	local s = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	if s == nil or s == "" then
		s = prompt.KeyboardKeyCode.Name
	end
	return string.upper(s)
end

local function build(prompt, inputType, playerGui)
	local bb = UI.new("BillboardGui", {
		Name = "P13_Prompt",
		Adornee = prompt.Parent,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(300, 64),
		SizeOffset = Vector2.new(0.5, 0),
		StudsOffset = Vector3.new(0, 0.6, 0),
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	local scale = UI.new("UIScale", { Scale = 0.6, Parent = bb })
	local root = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = bb,
	})

	local keyBox = UI.new("TextButton", {
		AutoButtonColor = false,
		Text = keyText(prompt, inputType),
		Font = UI.FontTitle,
		TextSize = 22,
		TextColor3 = UI.Colors.Text,
		BackgroundColor3 = Color3.fromRGB(10, 8, 8),
		BackgroundTransparency = 0.25,
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = root,
	}, { UI.corner(6), UI.stroke(UI.Colors.Text, 1.5, 0.35) })

	local holdBack = UI.new("Frame", {
		Size = UDim2.new(1, -8, 0, 3),
		Position = UDim2.new(0, 4, 1, -6),
		BackgroundColor3 = Color3.fromRGB(40, 20, 20),
		BorderSizePixel = 0,
		Visible = prompt.HoldDuration > 0,
		Parent = keyBox,
	})
	local holdFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = UI.Colors.BrightRed,
		BorderSizePixel = 0,
		Parent = holdBack,
	})

	UI.label({
		Text = string.upper(prompt.ActionText),
		Font = UI.FontTitle,
		TextSize = 22,
		TextWrapped = false,
		TextStrokeTransparency = 0.5,
		Size = UDim2.new(1, -58, 0, 26),
		Position = UDim2.fromOffset(58, prompt.ObjectText ~= "" and 6 or 19),
		Parent = root,
	})
	if prompt.ObjectText ~= "" then
		UI.label({
			Text = prompt.ObjectText,
			Font = UI.FontMono,
			TextSize = 14,
			TextWrapped = false,
			TextColor3 = UI.Colors.Dim,
			TextStrokeTransparency = 0.6,
			Size = UDim2.new(1, -58, 0, 18),
			Position = UDim2.fromOffset(58, 34),
			Parent = root,
		})
	end

	local conns = {}
	local holdTween = nil
	table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
		holdFill.Size = UDim2.fromScale(0, 1)
		holdTween = UI.tween(holdFill, prompt.HoldDuration, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
	end))
	table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then
			holdTween:Cancel()
		end
		UI.tween(holdFill, 0.15, { Size = UDim2.fromScale(0, 1) })
	end))
	table.insert(conns, prompt.Triggered:Connect(function()
		UI.tween(scale, 0.06, { Scale = 1.12 })
		task.delay(0.07, function()
			UI.tween(scale, 0.15, { Scale = 1 })
		end)
		keyBox.BackgroundColor3 = UI.Colors.Red
		UI.tween(keyBox, 0.35, { BackgroundColor3 = Color3.fromRGB(10, 8, 8) })
	end))

	if inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt then
		table.insert(conns, keyBox.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldBegin()
			end
		end))
		table.insert(conns, keyBox.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldEnd()
			end
		end))
	end

	UI.tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	Sound.play("UIHover", nil, { Volume = 0.25, PlaybackSpeed = 0.8 })

	return function()
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		UI.tween(scale, 0.12, { Scale = 0.6 })
		task.delay(0.13, function()
			bb:Destroy()
		end)
	end
end

function Prompts.start()
	if started then
		return
	end
	started = true
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local function adopt(d)
		if d:IsA("ProximityPrompt") then
			d.Style = Enum.ProximityPromptStyle.Custom
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		adopt(d)
	end
	workspace.DescendantAdded:Connect(adopt)

	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local cleanup = build(prompt, inputType, playerGui)
		prompt.PromptHidden:Wait()
		cleanup()
	end)
end

return Prompts

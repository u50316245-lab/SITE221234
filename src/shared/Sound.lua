-- Проигрывание звуков по ключу из Config.Sounds. Если ID = 0 — тихо пропускаем (без ошибок).
-- Все звуки раскладываются по SoundGroup (музыка / эмбиент / эффекты / интерфейс),
-- чтобы громкость из настроек и «глухота» в шкафу работали централизованно.
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Config = require(script.Parent.Config)

local Sound = {}

local GROUP_OF = {
	MenuMusic = "Music",
	ChaseSting = "Music",
	Ambience = "Ambience",
	LightBuzz = "Ambience",
	UIHover = "UI",
	UIClick = "UI",
	Purchase = "UI",
}
local PREFIX = "P13_"

function Sound.id(key)
	local v = Config.Sounds[key]
	if v == nil or v == 0 or v == "" then
		return nil
	end
	if typeof(v) == "number" then
		return "rbxassetid://" .. tostring(v)
	end
	return tostring(v)
end

function Sound.group(category)
	local name = PREFIX .. category
	local g = SoundService:FindFirstChild(name)
	if not g or not g:IsA("SoundGroup") then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Volume = 1
		g.Parent = SoundService
	end
	return g
end

-- создать Sound (не запуская). parent = часть/аттачмент для 3D, nil = 2D
function Sound.make(key, parent, props)
	local id = Sound.id(key)
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = id
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 90
	s.SoundGroup = Sound.group(GROUP_OF[key] or "SFX")
	if props then
		for k, v in pairs(props) do
			s[k] = v
		end
	end
	s.Parent = parent or SoundService
	return s
end

-- одноразовый звук
function Sound.play(key, parent, props)
	local s = Sound.make(key, parent, props)
	if not s then
		return nil
	end
	if not s.Looped then
		s.Ended:Connect(function()
			s:Destroy()
		end)
		Debris:AddItem(s, 25)
	end
	s:Play()
	return s
end

-- звук в точке пространства
function Sound.playAt(key, position, props)
	if not Sound.id(key) then
		return nil
	end
	local a = Instance.new("Attachment")
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	Debris:AddItem(a, 25)
	return Sound.play(key, a, props)
end

-- КЛИЕНТ: громкость групп и приглушение ------------------------------------
local volumes = {}
local muffle = 0

local function isOurGroup(inst)
	return inst:IsA("SoundGroup") and string.sub(inst.Name, 1, #PREFIX) == PREFIX
end

local function applyGroup(g)
	local category = string.sub(g.Name, #PREFIX + 1)
	local v = volumes[category]
	if v then
		g.Volume = v
	end
	-- в шкафу / при оглушении мир звучит как через стенку; интерфейс не трогаем
	if category ~= "UI" then
		local eq = g:FindFirstChild("P13_Muffle")
		if muffle > 0.001 and not eq then
			eq = Instance.new("EqualizerSoundEffect")
			eq.Name = "P13_Muffle"
			eq.Parent = g
		end
		if eq and eq:IsA("EqualizerSoundEffect") then
			eq.HighGain = -38 * muffle
			eq.MidGain = -10 * muffle
			eq.LowGain = 2 * muffle
			eq.Enabled = muffle > 0.001
		end
	end
end

local function applyAll()
	for _, c in ipairs(SoundService:GetChildren()) do
		if isOurGroup(c) then
			applyGroup(c)
		end
	end
end

-- volumes: { Music = 0..1, Ambience = 0..1, SFX = 0..1, UI = 0..1 }
function Sound.setVolumes(t)
	volumes = t
	for category in pairs(t) do
		Sound.group(category)
	end
	applyAll()
end

-- 0 = обычный звук, 1 = полностью приглушённый мир
function Sound.setMuffle(alpha)
	alpha = math.clamp(alpha, 0, 1)
	if math.abs(alpha - muffle) < 0.01 then
		return
	end
	muffle = alpha
	applyAll()
end

-- привязать громкость к модулю Settings
function Sound.bindSettings(Settings)
	local function apply()
		local master = Settings.get("master")
		local music = Settings.get("music")
		local sfx = Settings.get("sfx")
		Sound.setVolumes({
			Music = master * music,
			Ambience = master * (0.35 + music * 0.65),
			SFX = master * sfx,
			UI = master * sfx * 0.8,
		})
	end
	Settings.Changed:Connect(apply)
	apply()
end

if RunService:IsClient() then
	SoundService.ChildAdded:Connect(function(c)
		if isOurGroup(c) then
			applyGroup(c)
		end
	end)
end

return Sound

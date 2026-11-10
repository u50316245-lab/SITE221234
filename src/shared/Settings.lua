--[[
	Настройки игрока (звук, графика, камера, субтитры).
	Схема общая для клиента и сервера: сервер чистит присланное через Settings.sanitize
	и хранит в профиле, поэтому настройки переезжают между лобби и больницей.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = {}

Settings.Defaults = {
	master = 1,
	music = 0.6,
	sfx = 1,
	fov = 70,
	shake = 1,
	quality = 3, -- 1 = низко, 2 = средне, 3 = ультра
	motionBlur = true,
	dof = true,
	grain = true,
	flicker = true,
	subtitles = true,
}

-- тип, минимум, максимум, шаг
Settings.Schema = {
	master = { "number", 0, 1, 0.05 },
	music = { "number", 0, 1, 0.05 },
	sfx = { "number", 0, 1, 0.05 },
	fov = { "number", 60, 90, 1 },
	shake = { "number", 0, 1, 0.05 },
	quality = { "number", 1, 3, 1 },
	motionBlur = { "boolean" },
	dof = { "boolean" },
	grain = { "boolean" },
	flicker = { "boolean" },
	subtitles = { "boolean" },
}

function Settings.sanitize(input)
	local out = {}
	for key, def in pairs(Settings.Defaults) do
		local schema = Settings.Schema[key]
		local v = type(input) == "table" and input[key] or nil
		if schema[1] == "number" then
			if type(v) ~= "number" or v ~= v then
				v = def
			end
			v = math.clamp(v, schema[2], schema[3])
			v = math.floor(v / schema[4] + 0.5) * schema[4]
		elseif type(v) ~= "boolean" then
			v = def
		end
		out[key] = v
	end
	return out
end

-- ниже — клиентское состояние ------------------------------------------------

local values = Settings.sanitize(nil)
local changedEvent = Instance.new("BindableEvent")
Settings.Changed = changedEvent.Event -- (key) ; key == "*" — обновилось всё сразу

local started = false
local dirty = false
local saveToken = 0

function Settings.get(key)
	return values[key]
end

function Settings.all()
	return table.clone(values)
end

local function scheduleSave()
	saveToken += 1
	local my = saveToken
	task.delay(1.5, function()
		if my ~= saveToken then
			return
		end
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local ev = remotes and remotes:FindFirstChild("SaveSettings")
		if ev and ev:IsA("RemoteEvent") then
			ev:FireServer(values)
		end
	end)
end

function Settings.set(key, value)
	if Settings.Defaults[key] == nil then
		return
	end
	local nextValues = table.clone(values)
	nextValues[key] = value
	nextValues = Settings.sanitize(nextValues)
	if nextValues[key] == values[key] then
		return
	end
	values = nextValues
	dirty = true
	changedEvent:Fire(key)
	scheduleSave()
end

-- подтянуть сохранённые настройки из профиля (один раз, локальные правки не затираем)
function Settings.start()
	if started then
		return
	end
	started = true
	local ClientData = require(script.Parent.ClientData)
	ClientData.start()
	local pulled = false
	local function pull(d)
		if pulled or type(d) ~= "table" or type(d.settings) ~= "table" then
			return
		end
		pulled = true
		if dirty then
			return
		end
		values = Settings.sanitize(d.settings)
		changedEvent:Fire("*")
	end
	pull(ClientData.get())
	ClientData.Changed:Connect(pull)
end

return Settings

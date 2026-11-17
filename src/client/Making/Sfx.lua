-- 제작 효과음. 소리 ID는 DalgonaConfig.Sounds에 (비어 있으면 조용히 넘어감).
--   Sfx.play(key, volume, speed)        : 한 번 재생 (쩌적 등)
--   Sfx.loop(key, volume, speed)        : 반복 소리를 매 프레임 이 값으로 (volume 0이면 서서히 멈춤)
--   Sfx.stop(key) / Sfx.stopAll()
-- 설계: docs/MOTION_REFERENCE_ANALYSIS.md 8-6, 후보: docs/SOUND_CANDIDATES.md

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DalgonaConfig"))

local Sfx = {}

local loops = {}
local folder = nil

local function parent()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "MakingSfx"
		folder.Parent = SoundService
	end
	return folder
end

local function make(key, looped)
	local id = Config.Sounds[key]
	if not id or id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = id
	s.Looped = looped
	s.Volume = 0
	local start = Config.Sounds[key .. "Start"]
	if start then
		s.PlaybackRegion = NumberRange.new(start, 600)
	end
	s.Parent = parent()
	return s
end

function Sfx.play(key, volume, speed)
	local s = make(key, false)
	if not s then
		return
	end
	s.Volume = volume or 0.6
	s.PlaybackSpeed = (speed or 1) * (0.94 + math.random() * 0.12)
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(10, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- 반복 소리: 부를 때마다 목표 크기·속도로 부드럽게 따라감
function Sfx.loop(key, volume, speed)
	local l = loops[key]
	if not l then
		if (volume or 0) <= 0 then
			return
		end
		local s = make(key, true)
		if not s then
			loops[key] = { dead = true }
			return
		end
		l = { s = s, vol = 0 }
		loops[key] = l
		s:Play()
	end
	if l.dead then
		return
	end
	l.vol += ((volume or 0) - l.vol) * 0.25
	l.s.Volume = l.vol
	l.s.PlaybackSpeed = speed or 1
	if l.vol < 0.01 and (volume or 0) <= 0 then
		l.s:Pause()
	elseif not l.s.IsPlaying then
		l.s:Resume()
	end
end

-- 젓는 소리: 상태마다 질감이 다름 (가루 = 사각사각, 결정 = 톡톡, 액체 = 부드럽게, 소다 뒤 = 둔한 거품)
-- speed = 젓는 각속도 (rad/s). 빠를수록 크고 빠르게
local STIR_KEYS = { "stirDry", "stirCrystal", "stirLiquid", "stirCream" }
local STIR_VOL = { stirDry = 0.55, stirCrystal = 0.45, stirLiquid = 0.35, stirCream = 0.4 }
function Sfx.stir(kind, speed, active)
	local k = math.clamp((speed or 0) / 10, 0, 1.3)
	for _, key in ipairs(STIR_KEYS) do
		if key == kind and active then
			Sfx.loop(key, STIR_VOL[key] * math.min(k, 1), 0.75 + 0.35 * k)
		else
			Sfx.loop(key, 0, 1)
		end
	end
end

function Sfx.stop(key)
	local l = loops[key]
	if l and l.s then
		l.s:Destroy()
	end
	loops[key] = nil
end

function Sfx.stopAll()
	for key in pairs(loops) do
		Sfx.stop(key)
	end
end

return Sfx

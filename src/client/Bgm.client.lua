-- 배경 음악 (2026-11-24 사용자 고름 "Sunshine Strum"): 골목·가게에서 계속 반복 (SoundService, Looped).
-- 제작 화면(PlayerGui.MakingScreen 켜짐, 또는 내 속성 Making = true) 동안은 조금 줄이고, 나오면 원래대로.
-- 값(소리 id·볼륨)은 UiStyle의 UI.Bgm 한 곳. 켜기/끄기는 설정 창이 생기면 넣음 (내 속성 BgmOff = true면 끔).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))
local B = UI.Bgm

local me = Players.LocalPlayer
local playerGui = me:WaitForChild("PlayerGui")

local music = Instance.new("Sound")
music.Name = "Bgm"
music.SoundId = B.id
music.Looped = true
music.Volume = 0
music.Parent = SoundService

local screenOn = false
local tween = nil
local function target()
	if me:GetAttribute("BgmOff") == true then
		return 0
	end
	local making = screenOn or me:GetAttribute("Making") == true
	return making and B.makingVolume or B.volume
end
local function apply()
	if tween then
		tween:Cancel()
	end
	tween = TweenService:Create(music, TweenInfo.new(B.fade, Enum.EasingStyle.Sine), { Volume = target() })
	tween:Play()
end

me:GetAttributeChangedSignal("Making"):Connect(apply)
me:GetAttributeChangedSignal("BgmOff"):Connect(apply)

local function watchMaking(screen)
	local function sync()
		screenOn = screen.Enabled
		apply()
	end
	screen:GetPropertyChangedSignal("Enabled"):Connect(sync)
	sync()
end
local making = playerGui:FindFirstChild("MakingScreen")
if making then
	watchMaking(making)
else
	playerGui.ChildAdded:Connect(function(c)
		if c.Name == "MakingScreen" and c:IsA("ScreenGui") then
			watchMaking(c)
		end
	end)
end

music:Play()
apply() -- 처음엔 0에서 천천히 커짐

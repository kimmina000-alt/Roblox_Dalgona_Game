-- 배경 음악 (2026-11-24 사용자 고름 "Sunshine Strum"): 골목·가게에서 계속 반복 (SoundService, Looped).
-- 제작 화면(PlayerGui.MakingScreen 켜짐, 또는 내 속성 Making = true) 동안은 조금 줄이고, 나오면 원래대로.
-- 값(소리 id·볼륨)은 UiStyle의 UI.Bgm 한 곳.
-- 켜기/끄기 (2026-11-25 사용자 "배경음 끄기 버튼 추가"): HUD 오른쪽 위 메뉴에 🎵 버튼 (Hud의 Root.Menu, 성장·도감 다음).
--   누르면 내 속성 BgmOff를 바로 바꾸고 서버에 Remotes.GrowthAction("bgmOff", 끄기 true/false)로 저장
--   (서버 feat/helpers-cloth-bgm-1125: 데이터 bgmOff, 속성 BgmOff = true 끔 / nil 켬 → 다시 들어와도 기억).
--   서버가 거절하면("천천히!" 등) 원래대로 되돌림.

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

---------------------------------------------------------------- 켜기/끄기 버튼
local C = UI.C
task.spawn(function()
	local menu = playerGui:WaitForChild("ShopHud"):WaitForChild("Root"):WaitForChild("Menu")
	local slot = UI.new("Frame", { Name = "BgmSlot", LayoutOrder = 9, Size = UDim2.fromOffset(72, 86), BackgroundTransparency = 1, Parent = menu })
	local btn = UI.button({ Name = "Bgm", Text = "🎵", Color = C.pink, Radius = 18, TextSize = 30, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(64, 66), Parent = slot })
	local text = UI.text({ Text = "배경음", TextSize = 17, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 20), Parent = slot })
	local function show()
		local off = me:GetAttribute("BgmOff") == true
		UI.setButton(btn, { Text = off and "🔇" or "🎵", Color = off and C.grey or C.pink })
		text.Text = off and "배경음 끔" or "배경음"
	end
	me:GetAttributeChangedSignal("BgmOff"):Connect(show)
	show()
	local busy = false
	btn.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local wasOff = me:GetAttribute("BgmOff") == true
		local off = not wasOff
		me:SetAttribute("BgmOff", off or nil) -- 내 화면에서 바로
		local action = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("GrowthAction")
		if action then
			local ok, res = pcall(function()
				return action:InvokeServer("bgmOff", off)
			end)
			if not (ok and type(res) == "table" and res.ok) then
				me:SetAttribute("BgmOff", wasOff or nil) -- 서버가 거절하면 되돌림
			end
		end
		busy = false
	end)
end)

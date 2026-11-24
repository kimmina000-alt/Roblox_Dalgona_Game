-- 손님이 달고나를 사면 손님 머리 위에 "+n코인" 글씨가 올라가며 흐려짐 (2026-11-24 사용자: 구매 알림창 대신, 판매 세션)
-- 서버 SalesService가 Remotes.SaleFloat:FireClient(주인, 세계 좌표, 코인)으로 보냄. 색은 UiStyle

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = require(Shared:WaitForChild("UiStyle"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local RISE = 3.2 -- 올라가는 높이 (스터드)
local TIME = 1.5 -- 초

local function float(pos, coins)
	local anchor = Instance.new("Part")
	anchor.Name = "SaleFloat"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(pos)
	anchor.Parent = workspace.CurrentCamera -- 내 화면에만
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(85, 26) -- 2026-11-25 사용자 "+n코인 글씨 반으로 줄이기" (170 × 52 → 반)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 140
	bb.Adornee = anchor
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = string.format("+%d코인", coins)
	t.FontFace = UI.F.heavy
	t.TextScaled = true
	t.TextColor3 = UI.C.gold
	t.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Color = UI.C.woodDark
	stroke.Thickness = 1.5
	stroke.Parent = t
	local info = TweenInfo.new(TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bb, info, { StudsOffsetWorldSpace = Vector3.new(0, RISE, 0) }):Play()
	local fade = TweenInfo.new(TIME * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, TIME * 0.3)
	TweenService:Create(t, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	task.delay(TIME + 0.1, function()
		anchor:Destroy()
	end)
end

Remotes:WaitForChild("SaleFloat").OnClientEvent:Connect(function(pos, coins)
	if typeof(pos) == "Vector3" and type(coins) == "number" then
		float(pos, coins)
	end
end)

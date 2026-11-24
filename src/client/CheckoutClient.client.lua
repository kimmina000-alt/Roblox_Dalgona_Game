-- 계산 (D56, 2026-11-25 사용자 "지금은 진열하면 손님들이 알아서 사가는데 계산 기능 추가", GDD 16장 안 A)
--   손님이 진열대에서 고른 뒤 카운터 앞에 줄을 섬 → 내 가게 맨 앞 손님에 [계산] 버튼 (ProximityPrompt, PromptStyle 모양)
--   → 누르면 약 1초 연출(동전 짤랑 + 봉투 쏙 + 코인 글씨) → 코인. 맨 앞에 선 지 5초 안이면 "팁 +5%" 하트.
--   줄 선 손님마다 머리 위 인내 막대 (45초, 초록 → 노랑 → 빨강). 제작 화면이 끝나면 "손님 n명이 기다려요".
-- 서버 형식 (저장·부지 세션에 제안, 2026-11-25): 손님 Model(이름 Customer) 속성
--   Queue (1 = 맨 앞, 줄이 아니면 nil), Patience (0~1 남은 인내, 서버가 갱신 — 제작 중 절반 속도도 서버가 셈),
--   FrontAt (맨 앞이 된 서버 시각). (Coins는 없음 — 계산할 때 정해짐, "+n코인" 글씨는 서버 SaleFloat가 띄움)
--   손님은 Plot<i>.Customers 폴더 안 Model "Customer". 계산 뒤 손님 말풍선 "고마워요!"는 서버가.
--   Remotes.Checkout:InvokeServer() → { ok, reason, coins, tip } (맨 앞 손님 하나 계산)
--   부지 모델 Plot<i> 속성 QueueCount = 줄 선 손님 수. 계산 알바 자동 계산은 서버 Notify만. (판매 세션 확정 2026-11-25)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = require(Shared:WaitForChild("UiStyle"))
local G = require(Shared:WaitForChild("GrowthConfig"))
local C = UI.C
local new = UI.new

local me = Players.LocalPlayer
local playerGui = me:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local CK = G.Checkout or {}
local FAST = (CK.fastTip and CK.fastTip.within) or 5
local TIP = (CK.fastTip and CK.fastTip.mult) or 0.05

local gui = new("Folder", { Name = "CheckoutGuis", Parent = playerGui })

local function myPlot()
	local plots = workspace:FindFirstChild("ShopPlots")
	local i = me:GetAttribute("PlotIndex")
	return plots and i and plots:FindFirstChild("Plot" .. i)
end
local function headOf(m)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and (p.Name == "Head" or p.Name:sub(-5) == "_Head") then
			return p
		end
	end
	return m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
end
local function toast(text)
	local hud = script.Parent:FindFirstChild("Hud")
	local ev = hud and hud:FindFirstChild("Toast")
	if ev then
		ev:Fire(text)
	end
end

---------------------------------------------------------------- 인내 막대 (줄 선 손님 모두, 모든 가게)
local bars = {} -- [model] = { bb, fill, tipL }

local function removeBar(m)
	local b = bars[m]
	if b then
		b.bb:Destroy()
		bars[m] = nil
	end
end

local function buildBar(m)
	removeBar(m)
	local bb = new("BillboardGui", {
		Name = "Patience",
		Adornee = headOf(m),
		Size = UDim2.fromOffset(70, 30),
		StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0),
		LightInfluence = 0,
		MaxDistance = 70,
		ResetOnSpawn = false,
		Parent = gui,
	})
	local back = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(64, 11), BackgroundColor3 = C.woodDark, Parent = bb }, { UI.corner("round"), UI.stroke(C.cream, 1.5) })
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.green, Parent = back }, { UI.corner("round"), UI.gloss(0.25) })
	-- 빨리 계산 팁 표시 (맨 앞 5초 안)
	local tipL = UI.text({ Text = "💗 팁 +" .. math.floor(TIP * 100 + 0.5) .. "%", Visible = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -2), Size = UDim2.fromOffset(70, 16), TextSize = 12, TextColor3 = C.white, Outline = C.red, TextXAlignment = Enum.TextXAlignment.Center, Parent = bb })
	bars[m] = { bb = bb, fill = fill, tipL = tipL }
end

---------------------------------------------------------------- [계산] 버튼 (내 가게 맨 앞 손님)
local prompt = new("ProximityPrompt", {
	Name = "CheckoutPrompt",
	ActionText = "계산",
	ObjectText = "손님",
	HoldDuration = 0,
	MaxActivationDistance = CK.reach or 10, -- 카운터 뒤에서도 닿게 (G.Checkout.reach, 2026-11-26 판매 세션)
	RequiresLineOfSight = false,
	KeyboardKeyCode = Enum.KeyCode.E,
	Enabled = false,
})
local front = nil -- 지금 [계산]이 붙은 손님

local function effect(m, coins, tip)
	-- 약 1초: 동전 짤랑 + 봉투 쏙 + 코인 글씨 (+ 팁 하트)
	UI.coinSound()
	local head = headOf(m)
	if not head then
		return
	end
	local bb = new("BillboardGui", { Adornee = head, Size = UDim2.fromOffset(120, 70), StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0), AlwaysOnTop = true, LightInfluence = 0, ResetOnSpawn = false, Parent = gui })
	local bag = UI.text({ Text = "🛍", TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(44, 44), Parent = bb })
	local scale = new("UIScale", { Scale = 0.2, Parent = bag })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- 동전 세 개가 봉투 쪽으로 톡톡
	for k = 1, 3 do
		local coin = UI.coin(bb, 16, 3)
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		coin.Position = UDim2.new(0.5, (k - 2) * 26, 0, 4)
		task.delay(0.08 * k, function()
			TweenService:Create(coin, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(6, 6) }):Play()
		end)
		task.delay(0.08 * k + 0.36, function()
			coin:Destroy()
		end)
	end
	-- "+n코인"은 서버 SaleFloat가 띄우므로 여기서는 팁만
	local text = tip and "💗 팁 +" .. math.floor(TIP * 100 + 0.5) .. "%" or "계산 완료!"
	local _ = coins
	local t = UI.text({ Text = text, FontFace = UI.F.heavy, TextSize = 15, TextColor3 = C.gold, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.25, 0), Size = UDim2.fromOffset(120, 18), Visible = false, Parent = bb })
	task.delay(0.45, function()
		t.Visible = true
		TweenService:Create(t, TweenInfo.new(0.55), { Position = UDim2.new(0.5, 0, 0, -6) }):Play()
	end)
	task.delay(0.7, function()
		TweenService:Create(bag, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(t, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	end)
	task.delay(1.05, function()
		bb:Destroy()
	end)
end

local busy = false
prompt.Triggered:Connect(function()
	if busy or not front then
		return
	end
	busy = true
	local m = front
	local r = Remotes:FindFirstChild("Checkout")
	local ok, res = false, nil
	if r then
		ok, res = pcall(function()
			return r:InvokeServer()
		end)
	end
	busy = false
	if ok and type(res) == "table" and res.ok then
		effect(m, res.coins, res.tip)
	else
		toast((ok and type(res) == "table" and res.reason) or (r and "계산할 수 없어요" or "계산 서버가 아직 없어요"))
	end
end)

---------------------------------------------------------------- 손님 찾기 · 매 프레임 갱신
local customers = {} -- [model] = true (줄 속성을 볼 손님들)

local function watch(m)
	if not (m:IsA("Model") and m.Name == "Customer") or customers[m] then
		return
	end
	customers[m] = true
	m.AncestryChanged:Connect(function(_, parent)
		if not parent then
			customers[m] = nil
			removeBar(m)
		end
	end)
end

task.spawn(function()
	local plots = workspace:WaitForChild("ShopPlots")
	for _, d in ipairs(plots:GetDescendants()) do
		watch(d)
	end
	plots.DescendantAdded:Connect(watch)
end)

local function queueCount(plot)
	local n = 0
	for m in pairs(customers) do
		if m:GetAttribute("Queue") and m:IsDescendantOf(plot) then
			n += 1
		end
	end
	return n
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0
	local now = workspace:GetServerTimeNow()
	local plot = myPlot()
	local newFront = nil
	-- 꾸미기 화면 동안은 인내 막대를 숨김 (아래 큰 버튼과 겹치지 않게)
	local bui = playerGui:FindFirstChild("BuildUi")
	local hide = bui ~= nil and bui.Enabled
	for m in pairs(customers) do
		local q = m:GetAttribute("Queue")
		local patience = m:GetAttribute("Patience")
		if q then
			if not bars[m] then
				buildBar(m)
			end
			local b = bars[m]
			b.bb.Enabled = not hide
			local k = type(patience) == "number" and math.clamp(patience, 0, 1) or 1
			b.fill.Size = UDim2.fromScale(k, 1)
			b.fill.BackgroundColor3 = k > 0.5 and C.green or (k > 0.2 and C.yellow or C.red)
			local fa = m:GetAttribute("FrontAt")
			b.tipL.Visible = q == 1 and type(fa) == "number" and now - fa <= FAST
			if q == 1 and plot and m:IsDescendantOf(plot) then
				newFront = m
			end
		elseif bars[m] then
			removeBar(m)
		end
	end
	if newFront ~= front then
		front = newFront
		local head = front and headOf(front)
		prompt.Parent = head
		prompt.Enabled = head ~= nil
	end
end)

---------------------------------------------------------------- 제작 화면이 끝나면 "손님 n명이 기다려요"
task.spawn(function()
	local making = playerGui:WaitForChild("MakingScreen", 120)
	if not making then
		return
	end
	local was = making.Enabled
	making:GetPropertyChangedSignal("Enabled"):Connect(function()
		if was and not making.Enabled then
			task.wait(0.6) -- 결과 화면이 닫힌 뒤
			local plot = myPlot()
			local n = plot and (plot:GetAttribute("QueueCount") or queueCount(plot)) or 0 -- 서버 부지 속성 QueueCount
			if n > 0 then
				toast(string.format("🧾 손님 %d명이 계산을 기다려요! 카운터로 가요", n))
			end
		end
		was = making.Enabled
	end)
end)

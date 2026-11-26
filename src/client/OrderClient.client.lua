-- 주문 제작 손님 (D55, 2026-11-25): 손님 7종이 가끔 주문서를 들고 와서 계산대 옆 의자에서 기다림.
--   머리 위 말풍선 (내 화면에서 만드는 BillboardGui): 도안 이름 · 최소 품질 별 · 포장 🎁 · 건넨 수/개수 · 줄어드는 시계 막대.
--   내 가게 주문 손님의 말풍선을 탭하면 [주문 건네기] 창: 맞는 달고나 수 + [건네기] (서버가 좋은 것부터 골라 건넴).
-- 서버 (판매 세션 feat/shop-features-1125, OrderService):
--   부지 모델 Plot<i> 속성: OrderGuest(손님 id, 없으면 nil), OrderShape, OrderMinQ("Normal"/"Good"/"Excellent"), OrderPack(bool),
--     OrderNeed(개수), OrderDone(건넨 수), OrderUntil(떠나는 시각, workspace:GetServerTimeNow() 기준)
--   손님 모델 = Plot<i>.OrderGuest (Model, 속성 CustomerId). 말풍선은 이 모델 머리 위.
--   Remotes.OrderAction:InvokeServer("match") → { ids = 지금 건넬 수 있는 달고나 id 목록 }
--   Remotes.OrderAction:InvokeServer("give", ids | nil) → { ok, reason, coins, given, done } (nil = 서버가 고름)
--   계산 알바가 있으면 서버가 자동으로 건넴. 알림은 Notify.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local UI = require(Shared:WaitForChild("UiStyle"))
local C = UI.C
local new = UI.new

local me = Players.LocalPlayer
local playerGui = me:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- 최소 품질 → 별 수 (Normal 1 · Good 2 · Excellent 3)
local STARS = { Normal = 1, Good = 2, Excellent = 3, Perfect = 4 }
local GRADE_KO = { Normal = "보통", Good = "좋음", Excellent = "훌륭", Perfect = "완벽" }

local function orderAction(...)
	local r = Remotes:FindFirstChild("OrderAction")
	if not r then
		return nil
	end
	local args = table.pack(...)
	local ok, res = pcall(function()
		return r:InvokeServer(table.unpack(args, 1, args.n))
	end)
	return ok and res or nil
end

local function myPlot()
	local plots = workspace:FindFirstChild("ShopPlots")
	local i = me:GetAttribute("PlotIndex")
	return plots and i and plots:FindFirstChild("Plot" .. i)
end

local function orderText(plot)
	local e = ShapeCatalog.get(plot:GetAttribute("OrderShape") or "")
	local q = plot:GetAttribute("OrderMinQ") or "Normal"
	return string.format("%s %d개 · %s 이상%s", e and e.name or "?", plot:GetAttribute("OrderNeed") or 1, GRADE_KO[q] or q, plot:GetAttribute("OrderPack") and " · 🎁 포장" or "")
end

---------------------------------------------------------------- [주문 건네기] 창
local gui = UI.screen("OrderUi", 7, playerGui)
local root = UI.root(gui)
local fit = UI.fitter(root)
local win, body = UI.window({ Name = "Window", Title = "주문 팔기", Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.fromOffset(560, 300), ZIndex = 10, Parent = root })
fit(win, 560, 320)
body.Size = UDim2.new(1, -28, 1, -34 - 14 - 26)
local orderL = UI.text({ Text = "", Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 30), TextSize = 22, TextColor3 = C.cream, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12, Parent = body })
local leftL = UI.text({ Text = "", Position = UDim2.fromOffset(16, 48), Size = UDim2.new(1, -32, 0, 24), TextSize = 17, TextColor3 = C.cream, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12, Parent = body })
local matchL = UI.text({ Text = "", Position = UDim2.fromOffset(16, 84), Size = UDim2.new(1, -32, 0, 28), TextSize = 20, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, ZIndex = 12, Parent = body })
local giveBtn = UI.button({ Text = "팔기", Color = C.green, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(240, 60), TextSize = 22, ZIndex = 12, Parent = body })
local msg = UI.text({ Text = "", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -8), Size = UDim2.new(1, -40, 0, 22), TextSize = 16, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12, Parent = win })

local function setMsg(text, good)
	msg.Text = text
	msg:FindFirstChildOfClass("UIStroke").Color = good and C.good or C.bad
end

local matched = 0
local function refreshWindow()
	local plot = myPlot()
	if not (plot and plot:GetAttribute("OrderGuest")) then
		win.Visible = false
		return
	end
	orderL.Text = "📜 " .. orderText(plot)
	leftL.Text = string.format("건넨 수 %d / %d", plot:GetAttribute("OrderDone") or 0, plot:GetAttribute("OrderNeed") or 1)
end

local function openPicker()
	local plot = myPlot()
	if not (plot and plot:GetAttribute("OrderGuest")) then
		return
	end
	win.Visible = true
	setMsg("", true)
	refreshWindow()
	matchL.Text = "맞는 달고나를 찾는 중…"
	UI.setButton(giveBtn, { Enabled = false })
	local res = orderAction("match")
	if type(res) ~= "table" then
		matchL.Text = "주문 손님 서버가 아직 없어요"
		return
	end
	matched = type(res.ids) == "table" and #res.ids or 0
	if matched > 0 then
		matchL.Text = string.format("진열대·보관함에 맞는 달고나 %d개", matched)
		UI.setButton(giveBtn, { Enabled = true, Text = "팔기" })
	else
		matchL.Text = "맞는 달고나가 없어요 · 주문대로 만들어 오세요"
		UI.setButton(giveBtn, { Enabled = false, Text = "팔기" })
	end
end

local busy = false
giveBtn.Activated:Connect(function()
	if busy or not giveBtn:GetAttribute("Enabled") then
		return
	end
	busy = true
	local r = orderAction("give", nil) -- 서버가 좋은 것부터 고름
	busy = false
	if type(r) == "table" and r.ok then
		UI.coinSound()
		local hud = script.Parent:FindFirstChild("Hud")
		local toast = hud and hud:FindFirstChild("Toast")
		if toast then
			toast:Fire(string.format("주문 %d개 팔았어요%s", r.given or 1, r.coins and string.format(" (+%d 코인)", r.coins) or ""))
		end
		if r.done then
			win.Visible = false
		else
			openPicker() -- 아직 남았으면 다시 셈
		end
	else
		setMsg(type(r) == "table" and (r.reason or "건넬 수 없어요") or "건넬 수 없어요", false)
	end
end)
win.Close.Activated:Connect(function()
	win.Visible = false
end)

---------------------------------------------------------------- 말풍선 (부지마다)
local bubbles = {} -- [plot] = { bb, fill, label, countL, total }

local function headOf(m)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and (p.Name == "Head" or p.Name:sub(-5) == "_Head") then
			return p
		end
	end
	return m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
end

local function removeBubble(plot)
	local b = bubbles[plot]
	if b then
		b.bb:Destroy()
		bubbles[plot] = nil
	end
end

local function buildBubble(plot)
	removeBubble(plot)
	local guest = plot:FindFirstChild("OrderGuest")
	if not (plot:GetAttribute("OrderGuest") and guest) then
		return
	end
	local mine = plot == myPlot()
	local bb = new("BillboardGui", {
		Name = "OrderBubble",
		Size = UDim2.fromOffset(190, 112),
		StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0),
		MaxDistance = 80,
		LightInfluence = 0,
		Active = true,
		ResetOnSpawn = false,
		Adornee = headOf(guest),
		Parent = gui,
	})
	local btn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.cream, Size = UDim2.new(1, 0, 1, -12), Parent = bb }, { UI.corner(14), UI.stroke(C.woodDark, 3) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(16, 16), Rotation = 45, BackgroundColor3 = C.cream, ZIndex = 0, Parent = bb }, { UI.stroke(C.woodDark, 3) })
	local e = ShapeCatalog.get(plot:GetAttribute("OrderShape") or "")
	local gr = e and ShapeCatalog.grade(e.grade)
	local q = plot:GetAttribute("OrderMinQ") or "Normal"
	local countL = UI.text({ Text = "", Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 26), TextSize = 19, TextColor3 = gr and gr.color or C.ink, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn })
	UI.text({ Text = string.rep("★", STARS[q] or 1) .. string.rep("☆", 3 - math.min(3, STARS[q] or 1)) .. (plot:GetAttribute("OrderPack") and "  🎁" or ""), Position = UDim2.fromOffset(8, 30), Size = UDim2.new(1, -16, 0, 24), TextSize = 20, TextColor3 = C.gold, Outline = Color3.fromRGB(150, 100, 20), TextXAlignment = Enum.TextXAlignment.Center, Parent = btn })
	local _, fill, label = UI.bar({ Position = UDim2.fromOffset(12, 60), Size = UDim2.new(1, -24, 0, 18), Color = C.green, TextSize = 13, Parent = btn })
	UI.text({ Text = mine and "탭해서 팔기" or "주문 손님", Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 16), TextSize = 12, FontFace = UI.F.bold, TextColor3 = C.soft, TextXAlignment = Enum.TextXAlignment.Center, Parent = btn })
	if mine then
		btn.Activated:Connect(openPicker)
	end
	local untilT = plot:GetAttribute("OrderUntil")
	local total = type(untilT) == "number" and math.max(1, untilT - workspace:GetServerTimeNow()) or 1
	bubbles[plot] = { bb = bb, fill = fill, label = label, countL = countL, total = total, name = e and e.name or "?" }
end

local function syncCount(plot)
	local b = bubbles[plot]
	if b then
		b.countL.Text = string.format("📜 %s %d/%d", b.name, plot:GetAttribute("OrderDone") or 0, plot:GetAttribute("OrderNeed") or 1)
	end
end

local function watchPlot(plot)
	local function rebuild()
		buildBubble(plot)
		syncCount(plot)
		if plot == myPlot() and win.Visible then
			refreshWindow()
		end
	end
	for _, a in ipairs({ "OrderGuest", "OrderShape", "OrderMinQ", "OrderPack" }) do
		plot:GetAttributeChangedSignal(a):Connect(rebuild)
	end
	plot:GetAttributeChangedSignal("OrderDone"):Connect(function()
		syncCount(plot)
		if plot == myPlot() and win.Visible then
			refreshWindow()
		end
	end)
	plot:GetAttributeChangedSignal("OrderNeed"):Connect(function()
		syncCount(plot)
	end)
	-- 손님 모델이 속성보다 늦게(또는 스트리밍으로) 들어오면
	plot.ChildAdded:Connect(function(c)
		if c.Name == "OrderGuest" then
			task.wait()
			rebuild()
		end
	end)
	plot.ChildRemoved:Connect(function(c)
		if c.Name == "OrderGuest" then
			removeBubble(plot)
		end
	end)
	rebuild()
end

task.spawn(function()
	local plots = workspace:WaitForChild("ShopPlots")
	for _, p in ipairs(plots:GetChildren()) do
		watchPlot(p)
	end
	plots.ChildAdded:Connect(watchPlot)
end)

-- 꾸미기 화면(BuildUi) 동안은 말풍선을 숨김 (아래 큰 버튼과 겹침, 2026-11-25 묶음 시험)
local function building()
	local b = playerGui:FindFirstChild("BuildUi")
	return b ~= nil and b.Enabled
end

-- 시계: 남은 시간 막대 (초록 → 노랑 → 빨강)
RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	local hide = building()
	for plot, b in pairs(bubbles) do
		b.bb.Enabled = not hide
		local untilT = plot:GetAttribute("OrderUntil")
		if type(untilT) == "number" then
			local left = math.max(0, untilT - now)
			local k = math.clamp(left / b.total, 0, 1)
			b.fill.Size = UDim2.fromScale(k, 1)
			b.fill.BackgroundColor3 = k > 0.5 and C.green or (k > 0.2 and C.yellow or C.red)
			b.label.Text = string.format("⏱ %d:%02d", math.floor(left / 60), math.floor(left % 60))
		end
	end
end)

-- 제작 화면이 켜지면 창 닫기
task.spawn(function()
	local making = playerGui:WaitForChild("MakingScreen", 60)
	if making then
		making:GetPropertyChangedSignal("Enabled"):Connect(function()
			if making.Enabled then
				win.Visible = false
			end
		end)
	end
end)

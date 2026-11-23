-- 주문 제작 손님 (D55, 2026-11-25): 손님 7종이 가끔 주문서를 들고 와서 계산대 옆 의자에서 기다림.
--   머리 위 말풍선 (내 화면에서 만드는 BillboardGui): 도안 이름 · 최소 품질 별 · 포장 🎁 · 개수 · 줄어드는 시계 막대.
--   말풍선(또는 손님)을 탭하면 [주문 건네기] 창: 건넬 수 있는 달고나 목록 → [건네기].
-- 서버 형식 (저장·부지 세션에 제안, 2026-11-25): 주문 손님 Model 속성
--   OrderId, OrderShape(도안 id), OrderGrade(최소 품질 "Normal"/"Good"/"Excellent"/"Perfect"), OrderPack(bool), OrderCount,
--   OrderEnds(workspace:GetServerTimeNow() 기준 끝 시각), OrderTotal(기다리는 전체 초, 없으면 처음 본 때부터 셈)
--   Remotes.OrderAction:InvokeServer("candidates", orderId) → { { key, s, g, q, pk, from = "shelf"/"storage", mult } }
--   Remotes.OrderAction:InvokeServer("give", orderId, key) → { ok, reason, msg }

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

-- 최소 품질 → 별 수 (Normal 1 · Good 2 · Excellent 3 · Perfect 4)
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

---------------------------------------------------------------- [주문 건네기] 창
local gui = UI.screen("OrderUi", 7, playerGui)
local root = UI.root(gui)
local fit = UI.fitter(root)
local win, body = UI.window({ Name = "Window", Title = "주문 건네기", Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.fromOffset(700, 330), ZIndex = 10, Parent = root })
fit(win, 700, 355, true)
body.Size = UDim2.new(1, -28, 1, -34 - 14 - 26)
local info = UI.text({ Text = "", Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 26), TextSize = 19, TextColor3 = C.cream, Outline = C.woodDark, ZIndex = 12, Parent = body })
local msg = UI.text({ Text = "", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -8), Size = UDim2.new(1, -40, 0, 22), TextSize = 16, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12, Parent = win })
local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 40),
	Size = UDim2.new(1, -20, 1, -48),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = C.cream,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 12,
	Parent = body,
}, { new("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })
local grid = new("UIGridLayout", { CellSize = UDim2.fromOffset(150, 150), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
UI.fillGrid(grid, 150, 1)

local function setMsg(text, good)
	msg.Text = text
	msg:FindFirstChildOfClass("UIStroke").Color = good and C.good or C.bad
end
local function clearList()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local openFor = nil -- 지금 창을 연 주문 손님 Model
local busy = false
local function orderText(m)
	local e = ShapeCatalog.get(m:GetAttribute("OrderShape") or "")
	local g = m:GetAttribute("OrderGrade") or "Normal"
	return string.format("%s × %d · %s 이상%s", e and e.name or "?", m:GetAttribute("OrderCount") or 1, GRADE_KO[g] or g, m:GetAttribute("OrderPack") and " · 🎁 포장" or "")
end

local function openPicker(m)
	openFor = m
	win.Visible = true
	clearList()
	setMsg("", true)
	info.Text = "📜 주문: " .. orderText(m)
	local id = m:GetAttribute("OrderId")
	local res = orderAction("candidates", id)
	if type(res) ~= "table" then
		setMsg("주문 손님 서버가 아직 없어요", false)
		return
	end
	if #res == 0 then
		UI.text({ LayoutOrder = 1, Text = "맞는 달고나가 없어요 · 주문대로 만들어 오세요", TextSize = 18, TextColor3 = C.cream, Size = UDim2.fromOffset(400, 40), ZIndex = 13, Parent = list })
		return
	end
	for i, c in ipairs(res) do
		local e = ShapeCatalog.get(c.s or "")
		local gr = e and ShapeCatalog.grade(e.grade)
		local card = UI.card({ LayoutOrder = i, ZIndex = 13, Parent = list })
		card:FindFirstChildOfClass("UIStroke").Color = gr and gr.color or C.line
		UI.text({ Text = e and e.name or tostring(c.s), Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 24), TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 14, Parent = card })
		UI.text({ Text = string.rep("★", STARS[c.g] or 0) .. " " .. (GRADE_KO[c.g] or tostring(c.g or "")), Position = UDim2.fromOffset(8, 30), Size = UDim2.new(1, -16, 0, 20), TextSize = 15, TextColor3 = C.gold, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14, Parent = card })
		UI.text({ Text = string.format("%s%s%s", c.pk and "🎁 포장 · " or "", c.from == "shelf" and "진열대" or "보관함", c.mult and string.format(" · ×%.1f", c.mult) or ""), Position = UDim2.fromOffset(8, 52), Size = UDim2.new(1, -16, 0, 18), TextSize = 13, FontFace = UI.F.bold, TextColor3 = C.soft, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14, Parent = card })
		local b = UI.button({ Text = "건네기", Color = C.green, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 44), TextSize = 18, ZIndex = 14, Parent = card })
		b.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local r = orderAction("give", id, c.key)
			busy = false
			if type(r) == "table" and r.ok then
				UI.coinSound()
				win.Visible = false
				local hud = script.Parent:FindFirstChild("Hud")
				local toast = hud and hud:FindFirstChild("Toast")
				if toast then
					toast:Fire(r.msg or "주문을 건넸어요!")
				end
			else
				setMsg(type(r) == "table" and (r.reason or r.msg) or "건넬 수 없어요", false)
			end
		end)
	end
end
win.Close.Activated:Connect(function()
	win.Visible = false
end)

---------------------------------------------------------------- 말풍선
local bubbles = {} -- [model] = { bb, fill, firstSeen }

local function headOf(m)
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and (p.Name == "Head" or p.Name:sub(-5) == "_Head") then
			return p
		end
	end
	return m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
end

local function removeBubble(m)
	local b = bubbles[m]
	if b then
		b.bb:Destroy()
		bubbles[m] = nil
	end
	if openFor == m then
		win.Visible = false
		openFor = nil
	end
end

local function buildBubble(m)
	if bubbles[m] then
		bubbles[m].bb:Destroy()
	end
	local bb = new("BillboardGui", {
		Name = "OrderBubble",
		Size = UDim2.fromOffset(190, 108),
		StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0),
		MaxDistance = 80,
		LightInfluence = 0,
		AlwaysOnTop = false,
		Active = true,
		ResetOnSpawn = false,
		Adornee = headOf(m),
		Parent = gui,
	})
	-- 탭 = 말풍선 전체 버튼
	local btn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.cream, Size = UDim2.new(1, 0, 1, -12), Parent = bb }, { UI.corner(14), UI.stroke(C.woodDark, 3) })
	-- 말풍선 꼬리
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(16, 16), Rotation = 45, BackgroundColor3 = C.cream, ZIndex = 0, Parent = bb }, { UI.stroke(C.woodDark, 3) })
	local e = ShapeCatalog.get(m:GetAttribute("OrderShape") or "")
	local gr = e and ShapeCatalog.grade(e.grade)
	local g = m:GetAttribute("OrderGrade") or "Normal"
	UI.text({ Text = "📜 " .. (e and e.name or "?") .. (((m:GetAttribute("OrderCount") or 1) > 1) and (" ×" .. m:GetAttribute("OrderCount")) or ""), Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 26), TextSize = 19, TextColor3 = gr and gr.color or C.ink, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn })
	UI.text({ Text = string.rep("★", STARS[g] or 1) .. string.rep("☆", 4 - (STARS[g] or 1)) .. (m:GetAttribute("OrderPack") and "  🎁" or ""), Position = UDim2.fromOffset(8, 30), Size = UDim2.new(1, -16, 0, 24), TextSize = 20, TextColor3 = C.gold, Outline = Color3.fromRGB(150, 100, 20), TextXAlignment = Enum.TextXAlignment.Center, Parent = btn })
	-- 시계 막대
	local back, fill, label = UI.bar({ Position = UDim2.fromOffset(12, 60), Size = UDim2.new(1, -24, 0, 18), Color = C.green, TextSize = 13, Parent = btn })
	label.Text = "⏱"
	UI.text({ Text = "탭해서 건네기", Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 16), TextSize = 12, FontFace = UI.F.bold, TextColor3 = C.soft, TextXAlignment = Enum.TextXAlignment.Center, Parent = btn })
	btn.Activated:Connect(function()
		openPicker(m)
	end)
	bubbles[m] = { bb = bb, fill = fill, label = label, back = back, seen = workspace:GetServerTimeNow() }
end

local function watchModel(m)
	if not m:IsA("Model") then
		return
	end
	local function sync()
		if m:GetAttribute("OrderId") then
			buildBubble(m)
		else
			removeBubble(m)
		end
	end
	for _, a in ipairs({ "OrderId", "OrderShape", "OrderGrade", "OrderPack", "OrderCount" }) do
		m:GetAttributeChangedSignal(a):Connect(sync)
	end
	m.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeBubble(m)
		end
	end)
	sync()
end

task.spawn(function()
	local plots = workspace:WaitForChild("ShopPlots")
	for _, d in ipairs(plots:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("OrderId") ~= nil then
			watchModel(d)
		end
	end
	plots.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			-- 속성이 나중에 붙을 수 있어 손님 모델은 모두 지켜봄
			if d.Name == "Customer" or d:GetAttribute("OrderId") ~= nil then
				watchModel(d)
			end
		end
	end)
end)

-- 시계: 남은 시간 막대 (초록 → 노랑 → 빨강)
RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for m, b in pairs(bubbles) do
		local ends = m:GetAttribute("OrderEnds")
		if type(ends) == "number" then
			local total = m:GetAttribute("OrderTotal") or math.max(1, ends - b.seen)
			local left = math.max(0, ends - now)
			local k = math.clamp(left / total, 0, 1)
			b.fill.Size = UDim2.fromScale(k, 1)
			b.fill.BackgroundColor3 = k > 0.5 and C.green or (k > 0.2 and C.yellow or C.red)
			b.label.Text = string.format("⏱ %d:%02d", left // 60, math.floor(left % 60))
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

-- 성장 창 (Phase 4, 2026-11-20): HUD 아래 "성장" 버튼 → [가게] 장비·화로 알바 교육·알바생 배치(D34) / [목표] 일일 목표 3개 / [도감]
-- [도감] 탭은 2026-11-24부터 새 도감 화면(CollectionUi)을 여는 버튼 (사용자 요청: 옛 목록과 겹쳐서)
-- 서버 상태는 Remotes.PlayerState의 growth 칸 (GrowthService). 구매·도안 지정은 Remotes.GrowthAction.
-- 제작 화면(MakingScreen)이 켜져 있으면 숨긴다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("GrowthConfig"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = require(Shared:WaitForChild("UiStyle"))
local C = UI.C
local new = UI.new
local ROW = C.cream
local SOFT = C.soft
local GREEN = C.good
local RED = C.bad
local function label(props)
	props.TextSize = props.TextSize or 15
	return UI.text(props)
end

local gui = UI.screen("GrowthUi", 6, playerGui)
local root = UI.root(gui)
local fit = UI.fitter(root)

-- 열기 버튼: HUD 오른쪽 위 메뉴(ShopHud.Root.Menu)에 상점 아래로 넣는다 (2026-11-22 새 스타일)
local menu = playerGui:WaitForChild("ShopHud"):WaitForChild("Root"):WaitForChild("Menu")
local openSlot = new("Frame", { Name = "GrowthSlot", LayoutOrder = 2, Size = UDim2.fromOffset(72, 86), BackgroundTransparency = 1, Parent = menu })
local openBtn = UI.button({ Name = "Open", Text = "🌱", Color = C.blue, Radius = 18, TextSize = 32, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(64, 66), Parent = openSlot })
label({ Text = "성장", TextSize = 17, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 20), Parent = openSlot })

local win, body = UI.window({ Name = "Window", Title = "가게 키우기", Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.fromOffset(760, 320), ZIndex = 10, Parent = root })
fit(win, 760, 345, true) -- 화면 비율 창 (2026-11-24)
body.Size = UDim2.new(1, -28, 1, -34 - 14 - 26)
local closeBtn = win.Close
local msg = label({ Text = "", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -8), Size = UDim2.new(1, -40, 0, 22), TextSize = 16, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12, Parent = win })
local function setMsg(text, good)
	msg.Text = text
	msg:FindFirstChildOfClass("UIStroke").Color = good and C.good or C.bad
end

-- 왼쪽 세로 탭 (고른 탭은 밝은 나무 + 크림색 테두리)
-- D50 (2026-11-24 사용자 "성장에 가게-기계, 공장이랑 알바생 카테고리 나누기", 기획 docs/growth-tabs-1124):
-- 가게·기계 / 알바생 / 공장 / 목표 / 도감(= 도감 화면 열기). 탭별 항목은 render() 1~4번 칸.
local TABS = {
	{ id = "shop", text = "🏪 가게·기계" },
	{ id = "helpers", text = "👤 알바생" },
	{ id = "factory", text = "🏭 공장" },
	{ id = "goals", text = "🎯 목표" },
	{ id = "book", text = "📖 도감" },
}
local tabButtons, pages = {}, {}
local TAB_GAP = 6
local tabCol = new("Frame", { Name = "Tabs", Position = UDim2.fromOffset(10, 10), Size = UDim2.new(0, 130, 1, -20), BackgroundTransparency = 1, ZIndex = 12, Parent = body }, {
	new("UIListLayout", { Padding = UDim.new(0, TAB_GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
})
for i, t in ipairs(TABS) do
	-- 탭 높이 = 탭 칸 높이를 탭 수로 나눔 (창 크기가 화면 비율이라 같이 늘어남)
	tabButtons[t.id] = UI.button({ Name = "Tab_" .. t.id, Text = t.text, Color = C.woodLight, LayoutOrder = i, Size = UDim2.new(1, 0, 1 / #TABS, -TAB_GAP * (#TABS - 1) / #TABS), TextSize = 18, ZIndex = 12, Parent = tabCol })
	pages[t.id] = new("ScrollingFrame", {
		Name = t.id,
		Position = UDim2.fromOffset(152, 10),
		Size = UDim2.new(1, -162, 1, -20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.cream,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		ZIndex = 12,
		Parent = body,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
end
local current = "shop"
local function showTab(id)
	current = id
	for tid, p in pairs(pages) do
		p.Visible = tid == id
		local on = tid == id
		local b = tabButtons[tid]
		UI.setButton(b, { Color = on and C.yellow or C.woodLight })
		b:FindFirstChildOfClass("UIStroke").Color = on and C.cream or C.woodDark
	end
end
-- 도감 탭 = 새 도감 화면 열기 (성장 창은 닫음)
local function openCollection()
	local cs = script.Parent:FindFirstChild("CollectionUi")
	local open = cs and cs:FindFirstChild("Open")
	if open then
		win.Visible = false
		open:Fire()
	end
end
for _, t in ipairs(TABS) do
	tabButtons[t.id].Activated:Connect(function()
		if t.id == "book" then
			openCollection()
		else
			showTab(t.id)
		end
	end)
end
showTab("shop")

local function clear(page)
	for _, c in ipairs(page:GetChildren()) do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

local function row(page, order, title, sub, btnText, enabled, onClick)
	local r = UI.card({ LayoutOrder = order, Size = UDim2.new(1, -10, 0, 76), ZIndex = 13, Parent = page })
	label({ Text = title, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -176, 0, 26), TextSize = 19, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 14, Parent = r })
	label({ Text = sub, Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -176, 0, 34), TextSize = 14, FontFace = UI.F.bold, TextColor3 = SOFT, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 14, Parent = r })
	if btnText then
		local b = UI.button({ Text = btnText, Color = C.yellow, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 48), TextSize = 18, ZIndex = 14, Parent = r })
		UI.setButton(b, { Enabled = enabled and true or false })
		b.Activated:Connect(function()
			if enabled and onClick then
				onClick()
			end
		end)
	end
	return r
end

local busy = false
local function act(what, a, b)
	if busy then
		return
	end
	busy = true
	local ok, res = pcall(function()
		return Remotes.GrowthAction:InvokeServer(what, a, b)
	end)
	busy = false
	if ok and type(res) == "table" and res.ok then
		if what == "buy" or what == "train" or what == "factoryUp" or what == "factorySkill" then
			UI.coinSound() -- 코인을 쓰는 것 (해금·업그레이드·알바 고용·교육)
		end
		setMsg(res.msg or "완료!", true)
	else
		setMsg((ok and type(res) == "table" and res.reason) or "할 수 없어요", false)
	end
end

local state = nil

---------------------------------------------------------------- 알바 역할 고르기 창 (D43, 2026-11-24)
-- 알바생 줄의 "역할 고르기" → 열린 역할 카드 + 대기 카드 중 하나를 누르면 Remotes.GrowthAction("helperPost", 번호, key | "")
-- (그 역할에 다른 알바가 있으면 서버가 서로 바꿔 줌). 아직 안 열린 역할은 흐리게 + 여는 조건.
local POST_ICON = { stove = "🔥", steel = "🥫", pink = "🍬", line = "🏭", display = "🧺", cashier = "💰" }
-- 역할 한 줄 설명 (D56: 계산 알바 = 자동 계산)
local POST_DESC = { cashier = "자동 계산 · 팁 +5% · 수요 +10%", display = "보관함 → 진열대" }
local picker, pickerBody = UI.window({ Name = "RolePicker", Title = "알바 역할 고르기", Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.fromOffset(780, 340), ZIndex = 30, Parent = root })
fit(picker, 780, 365)
local pickerGrid = new("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 44),
	Size = UDim2.new(1, -20, 1, -52),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = C.cream,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 32,
	Parent = pickerBody,
}, {
	new("UIGridLayout", { CellSize = UDim2.fromOffset(170, 124), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }),
})
local pickerInfo = label({ Text = "", Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 28), TextSize = 19, TextColor3 = C.cream, Outline = C.woodDark, ZIndex = 32, Parent = pickerBody })
local pickerFor = nil -- 지금 고르는 알바 번호

local function openPicker(i)
	pickerFor = i
	picker.Visible = true
	for _, c in ipairs(pickerGrid:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local gr = state and state.growth
	if not gr then
		return
	end
	local h = gr.helpers and gr.helpers[i] or {}
	local cur = h.post
	local curPost = cur and G.helperPost(cur)
	pickerInfo.Text = string.format("알바생 %d · 지금: %s", i, curPost and curPost.name or "대기")
	-- 열린 역할: 서버가 준 posts (helper = 그 역할 알바 번호)
	local open = {}
	for _, p in ipairs(gr.posts or {}) do
		open[p.key] = p
	end
	local order = 0
	local function card(key, name, icon, sub, holder, enabled, chosen)
		order += 1
		local c = UI.card({ LayoutOrder = order, BackgroundColor3 = enabled and C.cream or C.tan, ZIndex = 33, Parent = pickerGrid })
		local st = c:FindFirstChildOfClass("UIStroke")
		if chosen then
			st.Color = C.good
			st.Thickness = 4
		end
		local ring = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = enabled and C.tan or Color3.fromRGB(210, 196, 172), ZIndex = 34, Parent = c }, { UI.corner("round"), UI.stroke(C.woodDark, 2.5) })
		label({ Text = icon, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 35, Parent = ring })
		label({ Text = name, Position = UDim2.fromOffset(62, 8), Size = UDim2.new(1, -68, 0, 40), TextSize = 17, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = enabled and C.ink or C.soft, ZIndex = 34, Parent = c })
		local subL = label({ Text = sub, Position = UDim2.fromOffset(10, 60), Size = UDim2.new(1, -20, 0, 18), TextSize = 13, FontFace = UI.F.bold, TextColor3 = C.soft, TextScaled = true, ZIndex = 34, Parent = c })
		new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 9, Parent = subL })
		if chosen then
			label({ Text = "✓ 지금 역할", Position = UDim2.fromOffset(10, 86), Size = UDim2.new(1, -20, 0, 28), TextSize = 17, TextColor3 = C.good, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 34, Parent = c })
			return
		end
		if not enabled then
			label({ Text = holder, Position = UDim2.fromOffset(10, 86), Size = UDim2.new(1, -20, 0, 28), TextSize = 14, TextColor3 = C.soft, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, ZIndex = 34, Parent = c })
			return
		end
		local b = UI.button({ Text = holder, Color = holder == "비어 있음" and C.green or C.yellow, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 40), TextSize = 16, ZIndex = 34, Parent = c })
		b.Activated:Connect(function()
			picker.Visible = false
			act("helperPost", pickerFor, key)
		end)
	end
	for _, p in ipairs(G.HelperPosts) do
		-- D46 (2026-11-24): 화로 알바 역할은 없어지고 2단계 기계 알바로 합쳐짐 → 화로 카드는 안 보임 (설정에서 빠져도 그대로 동작)
		if p.key == "stove" and not open.stove then
			continue
		end
		local o = open[p.key]
		local icon = POST_ICON[p.key] or (p.kind == "factory" and "⚙️") or "👤"
		local sub = POST_DESC[p.key] or string.format("급여 30초당 %d", (o and o.wage) or p.wage or 0)
		if o then
			local holder = o.helper and o.helper ~= pickerFor and string.format("알바생 %d와 바꾸기", o.helper) or "비어 있음"
			card(p.key, p.name, icon, sub, holder, true, cur == p.key)
		else
			local cond = (p.kind == "factory" and "공장을 열면") or (p.stage and string.format("%d단계 설비가 있으면", p.stage)) or (p.level and string.format("Lv%d부터", p.level)) or "아직 안 열림"
			card(p.key, p.name, icon, sub, "🔒 " .. cond, false, false)
		end
	end
	card("", "대기", "💤", "일 안 함 · 급여 없음", "대기로 두기", true, cur == nil)
end
picker.Close.Activated:Connect(function()
	picker.Visible = false
end)

local function helperShapes(unlocked)
	local list = {}
	local maxIndex = 0
	for i, g in ipairs(ShapeCatalog.Grades) do
		if g.id == G.Helper.maxGrade then
			maxIndex = i
		end
	end
	for _, e in ipairs(ShapeCatalog.list) do
		if e.gradeIndex <= maxIndex and table.find(unlocked, e.id) then
			table.insert(list, e)
		end
	end
	return list
end

-- 한 줄 안내 (카드 없이 나무 위 글씨)
local function note(page, order, text)
	return label({ LayoutOrder = order, Text = text, Size = UDim2.new(1, -10, 0, 26), TextSize = 16, TextColor3 = C.cream, ZIndex = 13, Parent = page })
end

local function render()
	if not state or not state.growth then
		return
	end
	local gr = state.growth
	for id, p in pairs(pages) do
		if id ~= "book" then
			clear(p)
		end
	end
	local SH = G.Shop
	local shop = gr.shop or { state = "stall" }
	local shopOpen = shop.state == "owned" or (shop.state == "rented" and not shop.closed)
	local lockText = shop.state == "stall" and "가게 임대 필요" or "문 닫힘"
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	---------------------------------------------------------------- 1. 가게·기계 (D50)
	local page = pages.shop
	-- 가게 단계 (D21): 노점 → 임대 → 매입, 월세 상태
	if shop.state == "stall" then
		row(page, nextOrder(), "🏪 야외 노점", string.format("가게 임대: Lv%d + 보증금 %d · 월세 %d분마다 %d", SH.rentLevel, SH.deposit, SH.rentEvery // 60, SH.rentAmount),
			state.level < SH.rentLevel and ("Lv" .. SH.rentLevel .. "부터") or (SH.deposit .. " 코인"),
			state.level >= SH.rentLevel and state.coins >= SH.deposit, function()
				act("buy", "rent")
			end)
	elseif shop.state == "rented" then
		local sub = shop.closed and string.format("월세 %d코인이 모자라 문 닫힘 (코인이 생기면 바로 열려요)", SH.rentAmount)
			or string.format("다음 월세 %d코인까지 %d:%02d (접속 중에만)", SH.rentAmount, (shop.rentLeft or 0) // 60, (shop.rentLeft or 0) % 60)
		local price = SH.buyPrice - SH.deposit
		row(page, nextOrder(), shop.closed and "🏪 가게 (문 닫힘)" or "🏪 월세 가게", sub,
			state.level < SH.buyLevel and ("매입 Lv" .. SH.buyLevel) or (price .. " 코인"),
			state.level >= SH.buyLevel and state.coins >= price, function()
				act("buy", "buyShop")
			end)
	else
		row(page, nextOrder(), "🏪 내 가게", "월세 없음")
	end
	-- 도구 업그레이드: 화로 · 누르개 · 작업대 (작업대 = 보관함 +25, D42)
	for _, kind in ipairs(G.UpgradeOrder) do
		local up = G.Upgrades[kind]
		local lv = gr.upgrades[kind] or 1
		local cost = up.costs[lv]
		local locked = SH.lockedWhenStall[kind] and not shopOpen
		local can = cost and not locked and state.level >= G.UpgradeUnlockLevel and state.coins >= cost
		local btn = not cost and "최고 단계" or (locked and lockText) or (state.level < G.UpgradeUnlockLevel and ("Lv" .. G.UpgradeUnlockLevel .. "부터")) or (cost .. " 코인")
		row(page, nextOrder(), string.format("%s Lv%d / %d", up.name, lv, #up.costs + 1), up.desc, btn, can, function()
			act("buy", kind)
		end)
	end
	-- 연탄 덮개 (D46) — G.StoveTraining 안 coalCover. 기계 알바 교육은 알바생 탭
	local trained = gr.stoveUps or {}
	local function trainRow(pg, t)
		local have = trained[t.key] == true
		row(pg, nextOrder(), string.format("%s %s%s", t.key == "coalCover" and "🔥" or "🎓", t.name, have and " ✓" or ""), t.text,
			have and "배움" or (not shopOpen and lockText) or (state.level < t.level and ("Lv" .. t.level .. "부터")) or (t.cost .. " 코인"),
			not have and shopOpen and state.level >= t.level and state.coins >= t.cost, function()
				act("train", t.key)
			end)
	end
	for _, t in ipairs(G.StoveTraining) do
		if t.key == "coalCover" then
			trainRow(page, t)
		end
	end
	-- 기계 2·3·4단계 (20번·D32): 다음 기계 사기 + 가진 기계마다 도안 바꾸기
	local mc = gr.machine
	if mc then
		local nx = mc.next
		row(page, nextOrder(), nx and string.format("⚙️ 다음 기계 · %s", nx.name) or "⚙️ 기계 (모두 삼)",
			nx and string.format("Lv%d · %d초에 %d개 · 가게 안 기계 자리에 놓여요", nx.level, G.Machines[nx.stage].seconds, G.Machines[nx.stage].batch) or "공장은 공장 탭에서 (Lv25)",
			not nx and "최고 단계" or (not shopOpen and lockText) or (state.level < nx.level and ("Lv" .. nx.level .. "부터")) or (nx.price .. " 코인"),
			nx ~= nil and shopOpen and state.level >= nx.level and state.coins >= nx.price, function()
				act("buy", "machine")
			end)
		local list = mc.machines
		if not list and mc.name then
			list = { { stage = mc.stage, name = mc.name, shape = mc.shape, shapes = mc.shapes, running = mc.running, status = mc.status, t = mc.t, seconds = mc.seconds, batch = mc.batch } }
		end
		for _, m in ipairs(list or {}) do
			local e = m.shape and ShapeCatalog.get(m.shape)
			local shapes = m.shapes or mc.shapes or {}
			local status = m.running and string.format("만드는 중 %d/%d초 · %d개씩", m.t or 0, m.seconds or 0, m.batch or 0) or ("멈춤: " .. tostring(m.status))
			row(page, nextOrder(), string.format("  %s · %s", m.name, e and e.name or "도안 없음"), status, "도안 바꾸기", #shapes > 1, function()
				local idx = table.find(shapes, m.shape) or 0
				act("machineShape", shapes[idx % #shapes + 1], m.stage)
			end)
		end
	end
	note(page, nextOrder(), string.format("📦 보관함 %d / %d", state.stock or 0, state.stockMax or G.StockMax or 0))

	---------------------------------------------------------------- 2. 알바생 (D50)
	page = pages.helpers
	-- 알바생 역할 (D34 → D43 → D46): 역할마다 한 명. "역할 고르기" = 역할 카드 창 (그 역할 알바와 서로 바뀜)
	local nHelp = #gr.helpers
	local maxHelp = gr.helperMax or G.HelperMax
	local hireCost = gr.hireCost
	row(page, nextOrder(), string.format("👤 알바생 %d / %d명", nHelp, maxHelp), hireCost and string.format("다음 고용비 %d 코인 · 역할마다 한 명 (제작대·진열·계산·공장)", hireCost) or "더 뽑을 수 없어요",
		(not shopOpen and lockText) or (nHelp >= maxHelp and "최대") or (hireCost and ("고용 · " .. hireCost)) or "최대",
		shopOpen and nHelp < maxHelp and hireCost ~= nil and state.coins >= hireCost, function()
			act("buy", "hire")
		end)
	local posts = gr.posts or {}
	local wageSum = 0
	for i, h in ipairs(gr.helpers) do
		local post = h.post and G.helperPost(h.post)
		local wage = post and post.wage or 0
		if post then
			wageSum += wage
		end
		local doing = not post and "대기 중 (자리 없음, 급여 없음)" or (h.status == "work" and "일하는 중" or ("쉬는 중: " .. tostring(h.status)))
		row(page, nextOrder(), string.format("  알바생 %d · %s", i, post and post.name or "대기"),
			post and string.format("%s%s · 급여 30초에 %d", POST_DESC[h.post] and (POST_DESC[h.post] .. " · ") or "", doing, wage) or doing, "역할 고르기", #posts > 0, function()
				openPicker(i)
			end)
		if h.post == "display" then
			local on = gr.displayHand ~= false
			row(page, nextOrder(), "    손으로 만든 것도 진열", on and "켬: 손 제작품을 먼저 옮겨요" or "끔: 손 제작품은 직접 놓아요", on and "끄기" or "켜기", true, function()
				act("displayHand", not on)
			end)
		end
	end
	for _, t in ipairs(G.StoveTraining) do
		if t.key ~= "coalCover" then
			trainRow(page, t) -- 기계 알바 교육 (Lv8, D46)
		end
	end
	note(page, nextOrder(), string.format("💰 급여 합계: 30초에 %d 코인 (일할 때만)", wageSum))

	---------------------------------------------------------------- 3. 공장 (D50)
	page = pages.factory
	local fc = gr.factory
	local F = G.Factory
	if not (fc and fc.unlocked) then
		-- 잠금 그림 + 여는 조건 한 줄 (아직 안 열린 탭도 보이게 해서 목표가 눈에 띄게)
		local lock = UI.card({ LayoutOrder = nextOrder(), Size = UDim2.new(1, -10, 0, 150), BackgroundColor3 = C.tan, ZIndex = 13, Parent = page })
		label({ Text = "🔒", TextSize = 60, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 70), ZIndex = 14, Parent = lock })
		label({ Text = string.format("Lv%d · 연속 생산 설비 필요 · %s 코인", F.level, string.format("%d", F.price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 26), ZIndex = 14, Parent = lock })
		local needStage = (mc and mc.stage or 1) >= F.needStage
		local b = UI.button({ Text = (not shopOpen and lockText) or (not needStage and "기계 4단계 필요") or (state.level < F.level and ("Lv" .. F.level .. "부터")) or "공장 사기", Color = C.yellow, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(200, 34), TextSize = 17, ZIndex = 14, Parent = lock })
		local can = shopOpen and needStage and state.level >= F.level and state.coins >= F.price
		UI.setButton(b, { Enabled = can })
		b.Activated:Connect(function()
			if can then
				act("buy", "factory")
			end
		end)
	else
		-- 상태
		local status = fc.on and (fc.status == "work" and "돌고 있음" or ("멈춤: " .. tostring(fc.status))) or "꺼짐"
		row(page, nextOrder(), "🏭 달고나 공장", string.format("%s · 자세한 설정은 가게 뒤 공장 제어대", status))
		-- 제어대 업그레이드 5종 (제어대에서도 같게 살 수 있음)
		for _, u in ipairs(fc.upgrades or {}) do
			local maxed = u.cost == nil
			row(page, nextOrder(), string.format("  %s %d / %d", u.name, u.level or 0, u.max or 1), u.desc,
				maxed and "최고 단계" or (u.cost .. " 코인"), not maxed and state.coins >= u.cost, function()
					act("factoryUp", u.key)
				end)
		end
		-- 공장 손재주 (D49): 공정마다 3단계. 서버 feat/octopus-setgi-1124: fc.staff[i].skill (0~3), skillCost (다음 값, 최고면 nil),
		-- fc.skillCosts = { 3000, 7000, 15000 }, 사기 = GrowthAction("factorySkill", 공정 key) (한 번에 한 단계)
		local FX = { "판정 폭 +30%", "판정 폭 +60% + 공정 도움", "성공 기준 80 → 60점 + 공정 도움" }
		local serverReady = fc.skillCosts ~= nil
		note(page, nextOrder(), "🖐 공장 손재주 (공정 미니게임이 쉬워져요)")
		for _, s in ipairs(fc.staff or {}) do
			local lv = s.skill or 0
			local cost = s.skillCost
			if cost == nil and not serverReady then
				cost = ({ 3000, 7000, 15000 })[lv + 1] -- 서버가 없을 때 보이는 값만
			end
			local maxed = lv >= 3
			row(page, nextOrder(), string.format("  %s · %d / 3단계", s.name, lv), maxed and "최고 단계" or ("다음: " .. FX[lv + 1]),
				maxed and "최고 단계" or (not serverReady and "준비 중") or ("올리기 · " .. tostring(cost)), serverReady and not maxed and cost ~= nil and state.coins >= cost, function()
					act("factorySkill", s.key)
				end)
		end
		-- 공정 5자리 현황: 알바 / 내가 하기 (D45) / 비어 있음
		note(page, nextOrder(), "👷 공정 자리")
		for _, s in ipairs(fc.staff or {}) do
			local who = s.self and "🙋 내가 하는 중" or (s.hired and "👤 알바" or "비어 있음")
			row(page, nextOrder(), string.format("  %s", s.name), who,
				s.self and "그만하기" or ((not s.hired and s.canSelf) and "내가 하기" or nil), true, function()
					act("factorySelf", s.key)
				end)
		end
		-- 대량 납품 주문 3칸 요약 (D47 서버가 생기면 fc.orders)
		local orders = fc.orders
		if orders and #orders > 0 then
			for k, o in ipairs(orders) do
				if k > 3 then
					break
				end
				local e = o.shape and ShapeCatalog.get(o.shape)
				row(page, nextOrder(), string.format("📜 납품 %s × %d", e and e.name or tostring(o.shape), o.n or 0), o.text or string.format("%d / %d · 보상 %s", o.done or 0, o.n or 0, tostring(o.reward or "")))
			end
		else
			row(page, nextOrder(), "📜 대량 납품 주문", "준비 중 · 자세한 것은 제어대 [납품] 탭")
		end
	end

	---------------------------------------------------------------- 4. 목표
	page = pages.goals
	for i, g in ipairs(gr.daily or {}) do
		row(page, i, (g.done and "✅ " or "") .. g.text, string.format("%d / %d · 보상 %d EXP + %d 코인", g.p, g.n, G.ExpDailyGoal, G.Daily.rewardCoins))
	end
	label({ LayoutOrder = 10, Text = "목표는 날마다(UTC) 바뀌어요", Size = UDim2.new(1, -8, 0, 22), TextSize = 15, TextColor3 = C.cream, ZIndex = 13, Parent = page })
end

openBtn.Activated:Connect(function()
	win.Visible = not win.Visible
	msg.Text = ""
	render()
end)
closeBtn.Activated:Connect(function()
	win.Visible = false
	picker.Visible = false
end)

Remotes:WaitForChild("PlayerState").OnClientEvent:Connect(function(s)
	state = s
	if win.Visible then
		render()
	end
end)
task.spawn(function()
	local ok, s = pcall(function()
		return Remotes:WaitForChild("GetPlayerState"):InvokeServer()
	end)
	if ok and s and not state then
		state = s
	end
end)

local function watchMaking(screen)
	local function sync()
		openBtn.Visible = not screen.Enabled
		if screen.Enabled then
			win.Visible = false
			picker.Visible = false
		end
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

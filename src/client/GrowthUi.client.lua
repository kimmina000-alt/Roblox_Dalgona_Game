-- 성장 창 (Phase 4, 2026-11-20): HUD 아래 "성장" 버튼 → [가게] 장비·화로 알바 교육·알바생 배치(D34) / [목표] 일일 목표 3개 / [도감]
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
fit(win, 760, 345)
body.Size = UDim2.new(1, -28, 1, -34 - 14 - 26)
local closeBtn = win.Close
local msg = label({ Text = "", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -8), Size = UDim2.new(1, -40, 0, 22), TextSize = 16, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12, Parent = win })
local function setMsg(text, good)
	msg.Text = text
	msg:FindFirstChildOfClass("UIStroke").Color = good and C.good or C.bad
end

-- 왼쪽 세로 탭 (고른 탭은 밝은 나무 + 크림색 테두리)
local TABS = { { id = "shop", text = "가게" }, { id = "goals", text = "목표" }, { id = "book", text = "도감" } }
local tabButtons, pages = {}, {}
local tabCol = new("Frame", { Name = "Tabs", Position = UDim2.fromOffset(10, 12), Size = UDim2.new(0, 120, 1, -24), BackgroundTransparency = 1, ZIndex = 12, Parent = body }, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
for i, t in ipairs(TABS) do
	tabButtons[t.id] = UI.button({ Name = "Tab_" .. t.id, Text = t.text, Color = C.woodLight, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 54), TextSize = 21, ZIndex = 12, Parent = tabCol })
	pages[t.id] = new("ScrollingFrame", {
		Name = t.id,
		Position = UDim2.fromOffset(142, 10),
		Size = UDim2.new(1, -152, 1, -20),
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
for _, t in ipairs(TABS) do
	tabButtons[t.id].Activated:Connect(function()
		showTab(t.id)
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
		setMsg(res.msg or "완료!", true)
	else
		setMsg((ok and type(res) == "table" and res.reason) or "할 수 없어요", false)
	end
end

local state = nil

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

local function render()
	if not state or not state.growth then
		return
	end
	local gr = state.growth
	-- 가게
	local page = pages.shop
	clear(page)
	local order = 0
	-- 가게 (D21): 노점 → 임대 → 매입
	local SH = G.Shop
	local shop = gr.shop or { state = "stall" }
	local shopOpen = shop.state == "owned" or (shop.state == "rented" and not shop.closed)
	order += 1
	if shop.state == "stall" then
		row(page, order, "🏪 야외 노점", string.format("가게 임대: Lv%d + 보증금 %d · 월세 %d분마다 %d", SH.rentLevel, SH.deposit, SH.rentEvery // 60, SH.rentAmount),
			state.level < SH.rentLevel and ("Lv" .. SH.rentLevel .. "부터") or (SH.deposit .. " 코인"),
			state.level >= SH.rentLevel and state.coins >= SH.deposit, function()
				act("buy", "rent")
			end)
	elseif shop.state == "rented" then
		local sub = shop.closed and string.format("월세 %d코인이 모자라 문 닫힘 (코인이 생기면 바로 열려요)", SH.rentAmount)
			or string.format("다음 월세 %d코인까지 %d:%02d (접속 중에만)", SH.rentAmount, (shop.rentLeft or 0) // 60, (shop.rentLeft or 0) % 60)
		local price = SH.buyPrice - SH.deposit
		row(page, order, shop.closed and "🏪 가게 (문 닫힘)" or "🏪 월세 가게", sub,
			state.level < SH.buyLevel and ("매입 Lv" .. SH.buyLevel) or (price .. " 코인"),
			state.level >= SH.buyLevel and state.coins >= price, function()
				act("buy", "buyShop")
			end)
	else
		row(page, order, "🏪 내 가게", "월세 없음")
	end
	local lockText = shop.state == "stall" and "가게 임대 필요" or "문 닫힘"
	for _, kind in ipairs(G.UpgradeOrder) do
		local up = G.Upgrades[kind]
		local lv = gr.upgrades[kind] or 1
		local cost = up.costs[lv]
		order += 1
		local locked = SH.lockedWhenStall[kind] and not shopOpen
		local can = cost and not locked and state.level >= G.UpgradeUnlockLevel and state.coins >= cost
		local btn = not cost and "최고 단계" or (locked and lockText) or (state.level < G.UpgradeUnlockLevel and ("Lv" .. G.UpgradeUnlockLevel .. "부터")) or (cost .. " 코인")
		row(page, order, string.format("%s Lv%d / %d", up.name, lv, #up.costs + 1), up.desc, btn, can, function()
			act("buy", kind)
		end)
	end
	-- 화로 알바 교육 (D39·D40, 2026-11-24): 국자 확장 대신
	local trained = gr.stoveUps or {}
	for _, t in ipairs(G.StoveTraining) do
		order += 1
		local have = trained[t.key] == true
		row(page, order, string.format("🔥 %s%s", t.name, have and " ✓" or ""), t.text,
			have and "배움" or (not shopOpen and lockText) or (state.level < t.level and ("Lv" .. t.level .. "부터")) or (t.cost .. " 코인"),
			not have and shopOpen and state.level >= t.level and state.coins >= t.cost, function()
				act("train", t.key)
			end)
	end
	-- 알바생 역할 (D34 → D43): 최대 11명, 역할마다 한 명. "역할 바꾸기" = 열린 역할 → 대기 순으로 돌림 (그 역할 알바와 서로 바뀜)
	-- (역할 고르기 화면은 UI 세션이 따로 만들 예정: Remotes.GrowthAction("helperPost", 번호, 역할 key | ""))
	local nHelp = #gr.helpers
	local maxHelp = gr.helperMax or G.HelperMax
	local hireCost = gr.hireCost
	order += 1
	row(page, order, string.format("알바생 %d / %d명", nHelp, maxHelp), "역할마다 한 명 (제작대·진열·계산·공장) · 기계는 알바가 있어야 돌아요",
		(not shopOpen and lockText) or (nHelp >= maxHelp and "최대") or (hireCost and (hireCost .. " 코인")) or "최대",
		shopOpen and nHelp < maxHelp and hireCost ~= nil and state.coins >= hireCost, function()
			act("buy", "hire")
		end)
	local posts = gr.posts or {}
	local choices = helperShapes(gr.unlocked)
	for i, h in ipairs(gr.helpers) do
		local post = h.post and G.helperPost(h.post)
		order += 1
		local status = not post and "대기 중 (자리 없음)" or (h.status == "work" and "일하는 중" or ("쉬는 중: " .. tostring(h.status)))
		row(page, order, string.format("  알바생 %d · %s", i, post and post.name or "대기"), status, "역할 바꾸기", #posts > 0, function()
			-- 다음 자리: 가진 제작대 순서대로, 마지막 다음은 대기
			local keys = {}
			for _, p in ipairs(posts) do
				table.insert(keys, p.key)
			end
			table.insert(keys, "")
			local idx = table.find(keys, h.post or "") or #keys
			act("helperPost", i, keys[idx % #keys + 1])
		end)
		if h.post == "display" then
			order += 1
			local on = gr.displayHand ~= false
			row(page, order, "    손으로 만든 것도 진열", on and "켬: 손 제작품을 먼저 옮겨요" or "끔: 손 제작품은 직접 놓아요", on and "끄기" or "켜기", true, function()
				act("displayHand", not on)
			end)
		end
		if h.post == "stove" then
			local e = ShapeCatalog.get(h.shape)
			order += 1
			row(page, order, string.format("    화로 도안 · %s", e and e.name or h.shape), "화로 알바가 만들 도안", "도안 바꾸기", #choices > 1, function()
				local idx = 1
				for k, c in ipairs(choices) do
					if c.id == h.shape then
						idx = k
					end
				end
				act("helperShape", i, choices[idx % #choices + 1].id)
			end)
		end
	end
	-- 기계 2~4단계 (20번): 가게 뒤 기계 1자리, 단계대로 교체
	local mc = gr.machine
	if mc then
		local nx = mc.next
		order += 1
		local title = mc.name and string.format("⚙️ %s", mc.name) or "⚙️ 기계 자리 (비어 있음)"
		local sub = nx and string.format("다음: %s · Lv%d · %d초에 %d개", nx.name, nx.level, G.Machines[nx.stage].seconds, G.Machines[nx.stage].batch) or "공장은 따로 (Lv25)"
		local canBuy = nx ~= nil and shopOpen and state.level >= nx.level and state.coins >= nx.price
		row(page, order, title, sub,
			not nx and "최고 단계" or (not shopOpen and lockText) or (state.level < nx.level and ("Lv" .. nx.level .. "부터")) or (nx.price .. " 코인"),
			canBuy, function()
				act("buy", "machine")
			end)
		if mc.name then
			local e = mc.shape and ShapeCatalog.get(mc.shape)
			local status = mc.running and string.format("만드는 중 %d/%d초 · %d개씩", mc.t or 0, mc.seconds, mc.batch) or ("멈춤: " .. tostring(mc.status))
			local shapes = mc.shapes or {}
			order += 1
			row(page, order, string.format("  기계 도안 · %s", e and e.name or "-"), status, "도안 바꾸기", #shapes > 1, function()
				local idx = table.find(shapes, mc.shape) or 0
				act("machineShape", shapes[idx % #shapes + 1])
			end)
		end
	end
	-- 5단계 공장: 해금만 여기서 (제어대 화면은 공장 안에서)
	local fc = gr.factory
	if fc then
		order += 1
		if fc.unlocked then
			local status = fc.on and (fc.status == "work" and "생산 중" or ("멈춤: " .. tostring(fc.status))) or "꺼짐"
			row(page, order, "🏭 달고나 공장", string.format("%s · 가게 뒤 문으로 들어가 제어대에서 설정", status))
		else
			local needStage = (mc and mc.stage or 1) >= G.Factory.needStage
			row(page, order, "🏭 달고나 공장", string.format("Lv%d · 연속 생산 설비 필요 · 한 판 20~40개", G.Factory.level),
				(not shopOpen and lockText) or (not needStage and "기계 4단계 필요") or (state.level < G.Factory.level and ("Lv" .. G.Factory.level .. "부터")) or (G.Factory.price .. " 코인"),
				shopOpen and needStage and state.level >= G.Factory.level and state.coins >= G.Factory.price, function()
					act("buy", "factory")
				end)
		end
	end

	-- 목표
	page = pages.goals
	clear(page)
	for i, g in ipairs(gr.daily or {}) do
		row(page, i, (g.done and "✅ " or "") .. g.text, string.format("%d / %d · 보상 %d EXP + %d 코인", g.p, g.n, G.ExpDailyGoal, G.Daily.rewardCoins))
	end
	label({ LayoutOrder = 10, Text = "목표는 날마다(UTC) 바뀌어요", Size = UDim2.new(1, -8, 0, 22), TextSize = 15, TextColor3 = C.cream, ZIndex = 13, Parent = page })

	-- 도감
	page = pages.book
	clear(page)
	local found = 0
	for i, e in ipairs(ShapeCatalog.list) do
		local c = gr.collection[e.id]
		local grade = ShapeCatalog.grade(e.grade)
		local unlocked = table.find(gr.unlocked, e.id) ~= nil
		local need = G.UnlockLevel[e.grade]
		local sub
		if c then
			found += 1
			sub = string.format("최고 %s · %d개 만듦", c.best, c.n)
		elseif unlocked then
			sub = "아직 안 만듦"
		else
			sub = need and ("🔒 Lv" .. need .. "에 열림") or "🔒 신화 도안을 손으로 Excellent 이상"
		end
		local r = row(page, i + 1, string.format("%s  [%s]", e.name, grade.label), sub)
		r.BackgroundColor3 = c and ROW or C.tan
	end
	label({ LayoutOrder = 0, Text = string.format("모은 도안 %d / %d", found, #ShapeCatalog.list), Size = UDim2.new(1, -8, 0, 26), TextSize = 19, TextColor3 = C.cream, Outline = C.woodDark, ZIndex = 13, Parent = page })
end

openBtn.Activated:Connect(function()
	win.Visible = not win.Visible
	msg.Text = ""
	render()
end)
closeBtn.Activated:Connect(function()
	win.Visible = false
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

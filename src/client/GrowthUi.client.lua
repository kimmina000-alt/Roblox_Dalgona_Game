-- 성장 창 (Phase 4, 2026-11-20): HUD 아래 "성장" 버튼 → [가게] 장비·국자·알바생 / [목표] 일일 목표 3개 / [도감]
-- 서버 상태는 Remotes.PlayerState의 growth 칸 (GrowthService). 구매·도안 지정은 Remotes.GrowthAction.
-- 제작 화면(MakingScreen)이 켜져 있으면 숨긴다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("GrowthConfig"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local CREAM = Color3.fromRGB(255, 247, 232)
local ROW = Color3.fromRGB(250, 236, 214)
local BROWN = Color3.fromRGB(92, 58, 36)
local SOFT = Color3.fromRGB(150, 110, 80)
local CARAMEL = Color3.fromRGB(222, 150, 70)
local GREEN = Color3.fromRGB(110, 190, 90)
local GREY = Color3.fromRGB(180, 170, 160)
local RED = Color3.fromRGB(200, 70, 60)
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local S = touch and 0.8 or 1

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			o[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = o
	end
	o.Parent = props and props.Parent
	return o
end
local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end
local function label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or BROWN
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextSize = props.TextSize or 15 * S
	return new("TextLabel", props)
end
local function button(props)
	props.Font = Enum.Font.GothamBlack
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextSize = props.TextSize or 14 * S
	props.BackgroundColor3 = props.BackgroundColor3 or GREEN
	return new("TextButton", props, { corner(10) })
end

local gui = new("ScreenGui", { Name = "GrowthUi", ResetOnSpawn = false, DisplayOrder = 6, Parent = playerGui })
local openBtn = button({
	Name = "Open",
	Text = "🌱 성장",
	Position = UDim2.new(0, 12, 0, 12 + 140 * S),
	Size = UDim2.fromOffset(96 * S, 32 * S),
	BackgroundColor3 = CARAMEL,
	Parent = gui,
})

local win = new("Frame", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(420 * S, 380 * S),
	BackgroundColor3 = CREAM,
	Visible = false,
	Parent = gui,
}, { corner(18), new("UIStroke", { Color = CARAMEL, Thickness = 3 }) })
local closeBtn = button({ Text = "X", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(34 * S, 34 * S), BackgroundColor3 = Color3.fromRGB(240, 222, 196), TextColor3 = BROWN, Parent = win })
local msg = label({ Text = "", Position = UDim2.new(0, 16, 1, -26 * S), Size = UDim2.new(1, -32, 0, 20 * S), TextSize = 13 * S, TextColor3 = RED, Parent = win })

local TABS = { { id = "shop", text = "가게" }, { id = "goals", text = "목표" }, { id = "book", text = "도감" } }
local tabButtons, pages = {}, {}
for i, t in ipairs(TABS) do
	tabButtons[t.id] = button({ Text = t.text, Position = UDim2.fromOffset(14 + (i - 1) * 86 * S, 12), Size = UDim2.fromOffset(80 * S, 32 * S), BackgroundColor3 = GREY, Parent = win })
	pages[t.id] = new("ScrollingFrame", {
		Name = t.id,
		Position = UDim2.fromOffset(12, 52 * S),
		Size = UDim2.new(1, -24, 1, -86 * S),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = win,
	}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
end
local current = "shop"
local function showTab(id)
	current = id
	for tid, p in pairs(pages) do
		p.Visible = tid == id
		tabButtons[tid].BackgroundColor3 = tid == id and CARAMEL or GREY
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
	local r = new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 50 * S), BackgroundColor3 = ROW, Parent = page }, { corner(12) })
	label({ Text = title, Position = UDim2.fromOffset(12, 4 * S), Size = UDim2.new(1, -150 * S, 0, 22 * S), TextSize = 16 * S, Parent = r })
	label({ Text = sub, Position = UDim2.fromOffset(12, 26 * S), Size = UDim2.new(1, -150 * S, 0, 18 * S), TextSize = 12 * S, TextColor3 = SOFT, Font = Enum.Font.Gotham, Parent = r })
	if btnText then
		local b = button({ Text = btnText, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(130 * S, 36 * S), BackgroundColor3 = enabled and GREEN or GREY, AutoButtonColor = enabled, Parent = r })
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
		msg.TextColor3 = GREEN
		msg.Text = res.msg or "완료!"
	else
		msg.TextColor3 = RED
		msg.Text = (ok and type(res) == "table" and res.reason) or "할 수 없어요"
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
	local nextL = G.Ladles[gr.ladles + 1]
	order += 1
	row(page, order, string.format("국자 %d / 4개", gr.ladles), "국자 2번째부터 알바생 1명씩",
		not nextL and "최고 단계" or (not shopOpen and lockText) or (state.level < nextL.level and ("Lv" .. nextL.level .. "부터")) or (nextL.cost .. " 코인"),
		nextL ~= nil and shopOpen and state.level >= nextL.level and state.coins >= nextL.cost, function()
			act("buy", "ladle")
		end)
	local nHelp = #gr.helpers
	local hireCost = G.HireCost[nHelp + 1]
	local seats = gr.ladles - 1
	order += 1
	row(page, order, string.format("알바생 %d / %d명", nHelp, seats), string.format("%d초에 1개 · 급여 30초당 %d · 젓가락 1쌍", G.Helper.seconds, G.Helper.wagePer30s),
		(not shopOpen and lockText) or (nHelp >= seats and "자리 없음") or (hireCost and (hireCost .. " 코인")) or "최대",
		shopOpen and nHelp < seats and hireCost ~= nil and state.coins >= hireCost, function()
			act("buy", "hire")
		end)
	local choices = helperShapes(gr.unlocked)
	for i, h in ipairs(gr.helpers) do
		local e = ShapeCatalog.get(h.shape)
		order += 1
		local status = h.status == "work" and "일하는 중" or ("쉬는 중: " .. tostring(h.status))
		row(page, order, string.format("  알바생 %d · %s", i, e and e.name or h.shape), status, "도안 바꾸기", #choices > 1, function()
			local idx = 1
			for k, c in ipairs(choices) do
				if c.id == h.shape then
					idx = k
				end
			end
			local nextShape = choices[idx % #choices + 1]
			act("helperShape", i, nextShape.id)
		end)
	end

	-- 목표
	page = pages.goals
	clear(page)
	for i, g in ipairs(gr.daily or {}) do
		row(page, i, (g.done and "✅ " or "") .. g.text, string.format("%d / %d · 보상 %d EXP + %d 코인", g.p, g.n, G.ExpDailyGoal, G.Daily.rewardCoins))
	end
	label({ LayoutOrder = 10, Text = "목표는 날마다(UTC) 바뀌어요", Size = UDim2.new(1, -8, 0, 20 * S), TextSize = 12 * S, TextColor3 = SOFT, Font = Enum.Font.Gotham, Parent = page })

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
		r.BackgroundColor3 = c and ROW or Color3.fromRGB(236, 228, 216)
	end
	label({ LayoutOrder = 0, Text = string.format("모은 도안 %d / %d", found, #ShapeCatalog.list), Size = UDim2.new(1, -8, 0, 22 * S), TextSize = 15 * S, Parent = page })
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

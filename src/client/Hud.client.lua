-- 가게 HUD (Phase 2, 2026-11-20): 코인·레벨(EXP 막대)·재료·달고나 보관함·가게 번호 + 재료 상점 + 알림
-- 2026-11-22 새 스타일(shared/UiStyle): 왼쪽 위 레벨 동그라미+가게 이름판, 그 아래 코인·보관함 알약(2026-11-24), 그 아래 재료 줄, 오른쪽 위 네모 메뉴(Menu, 성장 버튼은 GrowthUi가 넣음)
-- 서버가 Remotes.PlayerState로 바뀔 때마다 보내 준다. 제작 화면(MakingScreen)이 켜져 있으면 숨긴다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))
local C = UI.C
local new = UI.new
local label = UI.text

local gui = UI.screen("ShopHud", 5, playerGui)
local root = UI.root(gui) -- HUD 조각은 Root 안, 상점 창은 gui 바로 아래 (튜토리얼이 ShopHud.Shop을 찾음)
local fit = UI.fitter(root)

---------------------------------------------------------------- 왼쪽 위: 레벨 동그라미 + 가게 이름판(EXP) + 재료 줄
local panel = new("Frame", {
	Name = "Status",
	Position = UDim2.fromOffset(8, 6),
	Size = UDim2.fromOffset(350, 210),
	BackgroundTransparency = 1,
	Parent = root,
})
fit(panel)
local plank = new("Frame", {
	Name = "Plank",
	Position = UDim2.fromOffset(44, 8),
	Size = UDim2.fromOffset(250, 58),
	BackgroundColor3 = C.wood,
	Parent = panel,
}, { UI.corner(14), UI.stroke(C.woodDark, 3), UI.gloss(0.22) })
local plotText = label({ Name = "Plot", Text = "달고나 가게", Position = UDim2.fromOffset(36, 4), Size = UDim2.new(1, -44, 0, 26), TextSize = 19, TextColor3 = C.cream, Outline = C.woodDark, ZIndex = 2, Parent = plank })
local _, expFill, expText = UI.bar({ Name = "ExpBar", Position = UDim2.fromOffset(36, 33), Size = UDim2.new(1, -46, 0, 16), Color = C.yellow, ZIndex = 2, Parent = plank })
local lvCircle = new("Frame", {
	Name = "LevelBadge",
	Size = UDim2.fromOffset(74, 74),
	BackgroundColor3 = C.woodLight,
	ZIndex = 3,
	Parent = panel,
}, { UI.corner("round"), UI.stroke(C.woodDark, 3.5), UI.gloss(0.3) })
label({ Text = "LV", FontFace = UI.F.round, TextSize = 15, TextColor3 = C.cream, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 16), ZIndex = 4, Parent = lvCircle })
local levelText = label({ Name = "Level", Text = "1", FontFace = UI.F.round, TextSize = 32, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 38), ZIndex = 4, Parent = lvCircle })

-- 재료 줄 (0개면 빨갛게)
local ingBar = new("Frame", {
	Name = "Ingredients",
	Position = UDim2.fromOffset(6, 132), -- 코인·보관함 알약 아래 (2026-11-24 사용자 요청)
	Size = UDim2.fromOffset(0, 36),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = C.pill,
	BackgroundTransparency = 0.25,
	Parent = panel,
}, {
	UI.corner("round"),
	UI.stroke(C.woodDark, 2),
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local ingText = {}
local function ingPrefix(ing) -- 연탄은 이모지 대신 그린 아이콘을 앞에 따로 둠
	return ing.id == "coal" and "" or (ing.icon .. " ")
end
for i, ing in ipairs(G.Ingredients) do
	if ing.id == "coal" then
		UI.coal(ingBar, 20, 2).LayoutOrder = i * 2 - 1
	end
	ingText[ing.id] = label({
		Name = ing.id,
		LayoutOrder = i * 2,
		Text = ingPrefix(ing) .. "0",
		FontFace = UI.F.round,
		TextSize = 18,
		TextColor3 = C.white,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = ingBar,
	})
end
local saveWarn = label({ Name = "SaveWarn", Position = UDim2.fromOffset(10, 182), Size = UDim2.fromOffset(300, 20), TextSize = 14, TextColor3 = C.white, Outline = C.bad, Text = "⚠ 저장 안 됨 (DataStore 꺼짐)", Visible = false, Parent = panel })

---------------------------------------------------------------- 레벨 아래: 코인 · 달고나 보관함 알약 (2026-11-24 사용자 요청: 레벨 밑으로, 가운데 화면을 비움)
local top = new("Frame", {
	Name = "TopBar",
	Position = UDim2.fromOffset(24, 84),
	Size = UDim2.fromOffset(270, 44),
	BackgroundTransparency = 1,
	Parent = panel,
}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 22), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
-- 2026-11-24 사용자: 코인·보관함 줄 오른쪽 끝을 가게 이름판 오른쪽 끝(294)에 맞추고 작게
local coinPill, coinText, coinHolder = UI.pill({ Name = "Coins", LayoutOrder = 1, Size = UDim2.fromOffset(138, 34), IconColor = C.gold, TextSize = 19, Parent = top })
coinHolder.BackgroundTransparency = 1
coinHolder:FindFirstChildOfClass("UIStroke"):Destroy()
coinHolder:FindFirstChildOfClass("UIGradient"):Destroy()
coinHolder.Size = UDim2.fromOffset(40, 40)
local coinIcon = UI.coin(coinHolder, 38, 3)
coinIcon.AnchorPoint = Vector2.new(0.5, 0.5)
coinIcon.Position = UDim2.fromScale(0.5, 0.5)
coinText.Size = UDim2.new(1, -60, 1, 0)
coinText.Position = UDim2.fromOffset(24, 0)
-- + 누르면 재료 상점
local plusBtn = UI.button({ Name = "Plus", Text = "+", Color = C.yellow, Radius = 10, TextSize = 20, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -2, 0.5, 0), Size = UDim2.fromOffset(28, 30), ZIndex = 3, Parent = coinPill })
plusBtn.Face.Label.FontFace = UI.F.round
local stockPill, stockText, stockHolder = UI.pill({ Name = "Stock", LayoutOrder = 2, Icon = "🍪", Size = UDim2.fromOffset(110, 34), IconColor = C.tan, TextSize = 18, Parent = top })
stockHolder.Size = UDim2.fromOffset(40, 40)
stockText.Position = UDim2.fromOffset(24, 0)
stockText.Size = UDim2.new(1, -28, 1, 0)

---------------------------------------------------------------- 오른쪽 위: 네모 메뉴 버튼 (상점, 성장은 GrowthUi가 여기 넣음)
local menu = new("Frame", {
	Name = "Menu",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 8),
	Size = UDim2.fromOffset(72, 300),
	BackgroundTransparency = 1,
	Parent = root,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
fit(menu)
-- 다른 스크립트도 같은 모양 버튼을 쓰게: 메뉴 버튼 하나 = 아이콘 버튼 + 아래 이름
local function menuButton(name, icon, text, color, order)
	local holder = new("Frame", { Name = name .. "Slot", LayoutOrder = order, Size = UDim2.fromOffset(72, 86), BackgroundTransparency = 1, Parent = menu })
	local b = UI.button({ Name = name, Text = icon, Color = color, Radius = 18, TextSize = 32, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(64, 66), Parent = holder })
	label({ Text = text, TextSize = 17, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 20), Parent = holder })
	return b, holder
end
local shopBtn = menuButton("ShopButton", "🛒", "재료 상점", C.green, 1)

---------------------------------------------------------------- 재료 상점 창 (나무 판 + 재료마다 한 줄, 묶음 3가지 ×1 / ×5 / ×10)
-- 2026-11-24 사용자 "재료 구매 10회분씩만 되는데 10, 50, 100 단위로 추가": 버튼 3개 = 묶음 1·5·10개
-- (서버 Remotes.BuyIngredient(재료 id, 묶음 수) 그대로, 1~10 허용). 10회분 묶음이면 10 / 50 / 100, 연탄(5장 묶음)은 5 / 25 / 50.
local BUY_PACKS = G.BuyPacks or { 1, 5, 10 } -- 서버(feat/buy-bulk-1124)가 이 값만 받음
local shop = UI.window({ Name = "Shop", Title = "재료 상점", Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.fromOffset(760, 330), ZIndex = 10, Parent = gui })
fit(shop, 760, 355, true) -- 화면 비율 창 (2026-11-24)
local shopBody = shop.Body
shopBody.Size = UDim2.new(1, -28, 1, -34 - 14 - 26)
local closeBtn = shop.Close
local shopMsg = label({ Text = "", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -8), Size = UDim2.new(1, -40, 0, 22), TextSize = 16, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12, Parent = shop })
local grid = new("ScrollingFrame", {
	Name = "Grid",
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.new(1, -20, 1, -20),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = C.cream,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 12,
	Parent = shopBody,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UIPadding", { PaddingRight = UDim.new(0, 8) }),
})

local state = nil
local buyButtons = {}
-- 상점 아래 한 줄 알림 (성공 초록 테두리, 실패 빨간 테두리)
local function setMsg(text, good)
	shopMsg.Text = text
	shopMsg:FindFirstChildOfClass("UIStroke").Color = good and C.good or C.bad
end

local haveText = {}
local busy = false
for i, ing in ipairs(G.Ingredients) do
	local row = UI.card({ Name = ing.id, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 72), ZIndex = 13, Parent = grid })
	local iconBox = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(56, 56), BackgroundColor3 = C.tan, ZIndex = 14, Parent = row }, { UI.corner(12), UI.stroke(C.line, 2) })
	UI.ingredientIcon(ing, iconBox, 32, 15)
	label({ Text = ing.name, Position = UDim2.fromOffset(72, 10), Size = UDim2.new(1, -560, 0, 26), TextSize = 21, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 14, Parent = row })
	haveText[ing.id] = label({ Text = "보유 0", Position = UDim2.fromOffset(72, 38), Size = UDim2.new(1, -560, 0, 20), TextSize = 16, FontFace = UI.F.bold, TextColor3 = C.soft, ZIndex = 14, Parent = row })
	-- 오른쪽에 묶음 버튼 3개 (폰에서 누르기 쉽게 넓게: 150 × 56)
	local btnRow = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(3 * 150 + 2 * 8, 56), BackgroundTransparency = 1, ZIndex = 14, Parent = row }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for k, packs in ipairs(BUY_PACKS) do
		local units = ing.pack * packs
		local price = ing.price * packs
		local b = UI.button({ Name = string.format("Buy_%s_%d", ing.id, units), Text = "", Color = k == 1 and C.yellow or (k == 2 and C.green or C.cyan), LayoutOrder = k, Size = UDim2.fromOffset(150, 56), ZIndex = 15, Parent = btnRow })
		-- 위: 몇 회분 / 아래: 동전 + 가격
		UI.text({ Text = string.format("%d%s", units, ing.id == "coal" and "장" or "회분"), Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 20), TextSize = 16, TextColor3 = C.white, Outline = UI.darker(b:GetAttribute("Color"), 0.45), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 18, Parent = b.Face })
		local coin = UI.coin(b.Face, 20, 18)
		coin.AnchorPoint = Vector2.new(1, 0.5)
		coin.Position = UDim2.new(0.5, -18, 0, 35)
		UI.text({ Text = tostring(price), FontFace = UI.F.round, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, -14, 0, 35), Size = UDim2.fromOffset(70, 22), TextSize = 19, TextColor3 = C.white, Outline = UI.darker(b:GetAttribute("Color"), 0.45), ZIndex = 18, Parent = b.Face })
		table.insert(buyButtons, { button = b, price = price })
		b.Activated:Connect(function()
			if busy or not b:GetAttribute("Enabled") then
				return
			end
			busy = true
			local ok, res = pcall(function()
				return Remotes.BuyIngredient:InvokeServer(ing.id, packs)
			end)
			if ok and type(res) == "table" and res.ok then
				UI.coinSound()
				setMsg(string.format("%s %d%s을 샀어요 (-%d 코인)", ing.name, units, ing.id == "coal" and "장" or "회분", price), true)
			else
				setMsg((ok and type(res) == "table" and res.reason) or "살 수 없어요", false)
			end
			busy = false
		end)
	end
end

local function refreshButtons()
	for _, info in ipairs(buyButtons) do
		local afford = state ~= nil and state.coins >= info.price
		UI.setButton(info.button, { Enabled = afford })
	end
end

local function toggleShop()
	shop.Visible = not shop.Visible
	shopMsg.Text = ""
end
shopBtn.Activated:Connect(toggleShop)
plusBtn.Activated:Connect(toggleShop)
-- 다른 스크립트(제작 화면)가 상점을 열 수 있게: OpenShop:Fire(재료 id)
local openShop = Instance.new("BindableEvent")
openShop.Name = "OpenShop"
openShop.Parent = script
openShop.Event:Connect(function(id)
	shop.Visible = true
	local ing = nil
	for _, x in ipairs(G.Ingredients) do
		if x.id == id then
			ing = x
		end
	end
	setMsg(ing and (ing.name .. "이(가) 없어요. 사 가세요!") or "", false)
end)
closeBtn.Activated:Connect(function()
	shop.Visible = false
end)

---------------------------------------------------------------- 알림 (가운데 위, 제작 중엔 아래 — 제작 안내 문구와 겹치지 않게)
local toast = UI.card({
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 74),
	Size = UDim2.fromOffset(0, 44),
	AutomaticSize = Enum.AutomaticSize.X,
	Visible = false,
	ZIndex = 20,
	Parent = root,
})
toast:FindFirstChildOfClass("UIStroke").Color = C.woodDark
toast:FindFirstChildOfClass("UIStroke").Thickness = 3
new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = toast })
fit(toast, 600, 44) -- 알림 글씨는 창 배율 (읽혀야 함)
local toastText = label({ Text = "", TextSize = 19, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 21, Parent = toast })
local toastSeq = 0
local function showToast(text)
	toastSeq += 1
	local my = toastSeq
	toastText.Text = text
	toast.Visible = true
	task.delay(3, function()
		if toastSeq == my then
			toast.Visible = false
		end
	end)
end

---------------------------------------------------------------- 상태 반영
local shownCoins = 0
local function apply(s)
	if type(s) ~= "table" then
		return
	end
	local prev = state
	state = s
	-- 코인은 숫자가 올라가는 느낌으로
	local from = shownCoins
	local to = s.coins
	local v = Instance.new("NumberValue")
	v.Value = from
	v.Changed:Connect(function(x)
		coinText.Text = tostring(math.floor(x + 0.5))
	end)
	TweenService:Create(v, TweenInfo.new(prev and 0.4 or 0), { Value = to }):Play()
	task.delay(0.5, function()
		v:Destroy()
		coinText.Text = tostring(to)
	end)
	shownCoins = to

	levelText.Text = tostring(s.level)
	if s.expToNext and s.expToNext > 0 then
		expText.Text = string.format("%d / %d", s.exp, s.expToNext)
		expFill:TweenSize(UDim2.fromScale(math.clamp(s.exp / s.expToNext, 0, 1), 1), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
	else
		expText.Text = "MAX"
		expFill.Size = UDim2.fromScale(1, 1)
	end
	for _, ing in ipairs(G.Ingredients) do
		local n = s.ingredients and s.ingredients[ing.id] or 0
		ingText[ing.id].Text = ingPrefix(ing) .. n
		ingText[ing.id].TextColor3 = n > 0 and C.white or Color3.fromRGB(255, 120, 110)
		haveText[ing.id].Text = "보유 " .. n
		haveText[ing.id].TextColor3 = n > 0 and C.soft or C.bad
	end
	stockText.Text = string.format("%d/%d", s.stock or 0, s.stockMax or G.StockMax)
	plotText.Text = s.plot and string.format("%d번 달고나 가게", s.plot) or "달고나 가게"
	saveWarn.Visible = s.saving == false
	refreshButtons()
end

Remotes:WaitForChild("PlayerState").OnClientEvent:Connect(apply)
Remotes:WaitForChild("Notify").OnClientEvent:Connect(showToast)
task.spawn(function()
	local ok, s = pcall(function()
		return Remotes:WaitForChild("GetPlayerState"):InvokeServer()
	end)
	if ok and s and not state then
		apply(s)
	end
end)

-- 제작 화면이 켜져 있으면 HUD·상점을 숨김
local function watchMaking(screen)
	local function sync()
		panel.Visible = not screen.Enabled
		menu.Visible = not screen.Enabled
		toast.AnchorPoint = screen.Enabled and Vector2.new(0.5, 1) or Vector2.new(0.5, 0)
		toast.Position = screen.Enabled and UDim2.new(0.5, 0, 1, -24) or UDim2.new(0.5, 0, 0, 74)
		if screen.Enabled then
			shop.Visible = false
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

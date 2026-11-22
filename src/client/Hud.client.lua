-- 가게 HUD (Phase 2, 2026-11-20): 코인·레벨(EXP 막대)·재료·달고나 보관함·가게 번호 + 재료 상점 + 알림
-- 2026-11-22 새 스타일(shared/UiStyle): 왼쪽 위 레벨 동그라미+가게 이름판, 가운데 위 코인·보관함 알약, 오른쪽 위 네모 메뉴(Menu, 성장 버튼은 GrowthUi가 넣음)
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
local fit, _, onScale = UI.fitter(root)

---------------------------------------------------------------- 왼쪽 위: 레벨 동그라미 + 가게 이름판(EXP) + 재료 줄
local panel = new("Frame", {
	Name = "Status",
	Position = UDim2.fromOffset(8, 6),
	Size = UDim2.fromOffset(330, 166),
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
	Position = UDim2.fromOffset(6, 94), -- 레벨 동그라미·이름판과 띄움 (2026-11-23 사용자 요청)
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
for i, ing in ipairs(G.Ingredients) do
	ingText[ing.id] = label({
		Name = ing.id,
		LayoutOrder = i,
		Text = ing.icon .. " 0",
		FontFace = UI.F.round,
		TextSize = 18,
		TextColor3 = C.white,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = ingBar,
	})
end
local saveWarn = label({ Name = "SaveWarn", Position = UDim2.fromOffset(10, 136), Size = UDim2.fromOffset(300, 20), TextSize = 14, TextColor3 = C.white, Outline = C.bad, Text = "⚠ 저장 안 됨 (DataStore 꺼짐)", Visible = false, Parent = panel })

---------------------------------------------------------------- 위: 코인 · 달고나 보관함 알약 (가게 이름판 바로 오른쪽 — 폰에서 겹치지 않게)
local top = new("Frame", {
	Name = "TopBar",
	Position = UDim2.fromOffset(330, 14),
	Size = UDim2.fromOffset(410, 48),
	BackgroundTransparency = 1,
	Parent = root,
}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 30), SortOrder = Enum.SortOrder.LayoutOrder }) })
fit(top)
onScale(function(k)
	top.Position = UDim2.fromOffset(8 + 340 * k, 14 * k)
end)
local coinPill, coinText, coinHolder = UI.pill({ Name = "Coins", LayoutOrder = 1, Size = UDim2.fromOffset(200, 40), IconColor = C.gold, Parent = top })
coinHolder.BackgroundTransparency = 1
coinHolder:FindFirstChildOfClass("UIStroke"):Destroy()
coinHolder:FindFirstChildOfClass("UIGradient"):Destroy()
local coinIcon = UI.coin(coinHolder, 44, 3)
coinIcon.AnchorPoint = Vector2.new(0.5, 0.5)
coinIcon.Position = UDim2.fromScale(0.5, 0.5)
coinText.Size = UDim2.new(1, -70, 1, 0)
-- + 누르면 재료 상점
local plusBtn = UI.button({ Name = "Plus", Text = "+", Color = C.yellow, Radius = 10, TextSize = 24, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -3, 0.5, 0), Size = UDim2.fromOffset(34, 36), ZIndex = 3, Parent = coinPill })
plusBtn.Face.Label.FontFace = UI.F.round
local stockPill, stockText = UI.pill({ Name = "Stock", LayoutOrder = 2, Icon = "🍪", Size = UDim2.fromOffset(170, 40), IconColor = C.tan, Parent = top })

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

---------------------------------------------------------------- 재료 상점 창 (나무 판 + 재료 타일 한 줄 5칸 — 폰 가로 화면에서 글자가 크게 보이게)
local shop = UI.window({ Name = "Shop", Title = "재료 상점", Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.fromOffset(760, 320), ZIndex = 10, Parent = gui })
fit(shop, 760, 345)
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
}, { new("UIGridLayout", { CellSize = UDim2.new(0.2, -8, 1, -4), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

local state = nil
local buyButtons = {}
-- 상점 아래 한 줄 알림 (성공 초록 테두리, 실패 빨간 테두리)
local function setMsg(text, good)
	shopMsg.Text = text
	shopMsg:FindFirstChildOfClass("UIStroke").Color = good and C.good or C.bad
end

local haveText = {}
for i, ing in ipairs(G.Ingredients) do
	local row = UI.card({ Name = ing.id, LayoutOrder = i, ZIndex = 13, Parent = grid })
	local iconBox = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(84, 84), BackgroundColor3 = C.tan, ZIndex = 14, Parent = row }, { UI.corner(14), UI.stroke(C.line, 2) })
	label({ Text = ing.icon, TextSize = 46, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 15, Parent = iconBox })
	label({ Text = ing.name, Position = UDim2.fromOffset(4, 100), Size = UDim2.new(1, -8, 0, 26), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14, Parent = row })
	haveText[ing.id] = label({ Text = "보유 0", Position = UDim2.fromOffset(4, 126), Size = UDim2.new(1, -8, 0, 20), TextSize = 16, FontFace = UI.F.bold, TextColor3 = C.soft, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14, Parent = row })
	label({ Text = string.format("%d회분", ing.pack), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(60, 18), TextSize = 14, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 16, Parent = row })
	local b = UI.button({
		Name = "Buy_" .. ing.id,
		Text = tostring(ing.price),
		Color = C.yellow,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 48),
		TextSize = 24,
		ZIndex = 14,
		Parent = row,
	})
	b.Face.Label.FontFace = UI.F.round
	b.Face.Label.Position = UDim2.fromOffset(14, 0)
	local coin = UI.coin(b.Face, 28, 17)
	coin.AnchorPoint = Vector2.new(1, 0.5)
	coin.Position = UDim2.new(0.5, -8, 0.5, 0)
	buyButtons[ing.id] = { button = b, price = ing.price }
	local busy = false
	b.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local ok, res = pcall(function()
			return Remotes.BuyIngredient:InvokeServer(ing.id, 1)
		end)
		if ok and type(res) == "table" and res.ok then
			setMsg(string.format("%s %d회분을 샀어요", ing.name, ing.pack), true)
		else
			setMsg((ok and type(res) == "table" and res.reason) or "살 수 없어요", false)
		end
		busy = false
	end)
end

local function refreshButtons()
	for _, info in pairs(buyButtons) do
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
fit(toast)
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
		ingText[ing.id].Text = ing.icon .. " " .. n
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
		top.Visible = not screen.Enabled
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

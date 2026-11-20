-- 가게 HUD (Phase 2, 2026-11-20): 코인·레벨(EXP 막대)·재료·달고나 보관함·가게 번호 + 재료 상점 + 알림
-- 서버가 Remotes.PlayerState로 바뀔 때마다 보내 준다. 제작 화면(MakingScreen)이 켜져 있으면 숨긴다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local CREAM = Color3.fromRGB(255, 247, 232)
local BROWN = Color3.fromRGB(92, 58, 36)
local CARAMEL = Color3.fromRGB(222, 150, 70)
local PINK = Color3.fromRGB(255, 140, 160)
local GREEN = Color3.fromRGB(110, 190, 90)
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local S = touch and 0.8 or 1 -- 폰은 조금 작게

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

local function stroke(color, th)
	return new("UIStroke", { Color = color, Thickness = th, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or BROWN
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return new("TextLabel", props)
end

local gui = new("ScreenGui", {
	Name = "ShopHud",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
	Parent = playerGui,
})

---------------------------------------------------------------- 왼쪽 위 상태 판
local panel = new("Frame", {
	Name = "Status",
	Position = UDim2.new(0, 12, 0, 12),
	Size = UDim2.fromOffset(290 * S, 132 * S),
	BackgroundColor3 = CREAM,
	BackgroundTransparency = 0.05,
	Parent = gui,
}, { corner(14), stroke(CARAMEL, 2) })

local coinText = label({ Name = "Coins", Position = UDim2.fromOffset(40 * S, 8 * S), Size = UDim2.fromOffset(120 * S, 28 * S), TextSize = 24 * S, Font = Enum.Font.GothamBlack, Text = "0", Parent = panel })
-- 코인 아이콘 (🪙 이모지는 Roblox 글꼴에 없어 네모로 나옴)
local coinIcon = new("Frame", { Name = "CoinIcon", Position = UDim2.fromOffset(12 * S, 11 * S), Size = UDim2.fromOffset(22 * S, 22 * S), BackgroundColor3 = Color3.fromRGB(255, 200, 60), Parent = panel }, { corner(11 * S), stroke(Color3.fromRGB(200, 140, 30), 2) })
label({ Text = "C", Size = UDim2.fromScale(1, 1), TextSize = 13 * S, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(170, 110, 20), TextXAlignment = Enum.TextXAlignment.Center, Parent = coinIcon })
local plotText = label({ Name = "Plot", Position = UDim2.fromOffset(170 * S, 10 * S), Size = UDim2.fromOffset(110 * S, 24 * S), TextSize = 14 * S, TextXAlignment = Enum.TextXAlignment.Right, Text = "", TextColor3 = Color3.fromRGB(150, 110, 80), Parent = panel })
local levelText = label({ Name = "Level", Position = UDim2.fromOffset(12 * S, 40 * S), Size = UDim2.fromOffset(60 * S, 20 * S), TextSize = 17 * S, Font = Enum.Font.GothamBlack, Text = "Lv1", Parent = panel })
local expBack = new("Frame", { Name = "ExpBar", Position = UDim2.fromOffset(70 * S, 44 * S), Size = UDim2.fromOffset(208 * S, 14 * S), BackgroundColor3 = Color3.fromRGB(240, 222, 196), Parent = panel }, { corner(7) })
local expFill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = PINK, Parent = expBack }, { corner(7) })
local expText = label({ Name = "ExpText", Size = UDim2.fromScale(1, 1), TextSize = 11 * S, TextXAlignment = Enum.TextXAlignment.Center, Text = "0 / 50", ZIndex = 2, Parent = expBack })

local ingText = {}
for i, ing in ipairs(G.Ingredients) do
	ingText[ing.id] = label({
		Name = ing.id,
		Position = UDim2.fromOffset((12 + (i - 1) * 54) * S, 68 * S),
		Size = UDim2.fromOffset(54 * S, 24 * S),
		TextSize = 15 * S,
		Text = ing.icon .. " 0",
		Parent = panel,
	})
end
local stockText = label({ Name = "Stock", Position = UDim2.fromOffset(12 * S, 98 * S), Size = UDim2.fromOffset(140 * S, 24 * S), TextSize = 15 * S, Text = "🍪 달고나 0/30", Parent = panel })
local saveWarn = label({ Name = "SaveWarn", Position = UDim2.fromOffset(12 * S, 134 * S), Size = UDim2.fromOffset(240 * S, 18 * S), TextSize = 12 * S, TextColor3 = Color3.fromRGB(200, 70, 60), Text = "⚠ 저장 안 됨 (DataStore 꺼짐)", Visible = false, Parent = panel })

local shopBtn = new("TextButton", {
	Name = "ShopButton",
	Position = UDim2.fromOffset(200 * S, 96 * S),
	Size = UDim2.fromOffset(80 * S, 28 * S),
	BackgroundColor3 = CARAMEL,
	Text = "🛒 상점",
	TextSize = 15 * S,
	Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.new(1, 1, 1),
	Parent = panel,
}, { corner(10) })

---------------------------------------------------------------- 재료 상점 창
local shop = new("Frame", {
	Name = "Shop",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(340 * S, (70 + #G.Ingredients * 62) * S),
	BackgroundColor3 = CREAM,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
}, { corner(18), stroke(CARAMEL, 3) })
label({ Text = "재료 상점", Position = UDim2.fromOffset(18 * S, 12 * S), Size = UDim2.fromOffset(200 * S, 32 * S), TextSize = 24 * S, Font = Enum.Font.GothamBlack, ZIndex = 11, Parent = shop })
local closeBtn = new("TextButton", {
	Text = "X",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10 * S, 0, 10 * S),
	Size = UDim2.fromOffset(34 * S, 34 * S),
	BackgroundColor3 = Color3.fromRGB(240, 222, 196),
	TextColor3 = BROWN,
	TextSize = 18 * S,
	Font = Enum.Font.GothamBlack,
	ZIndex = 11,
	Parent = shop,
}, { corner(17) })
local shopMsg = label({ Text = "", Position = UDim2.new(0, 18 * S, 1, -26 * S), Size = UDim2.new(1, -36 * S, 0, 20 * S), TextSize = 13 * S, TextColor3 = Color3.fromRGB(200, 70, 60), ZIndex = 11, Parent = shop })

local state = nil
local buyButtons = {}
for i, ing in ipairs(G.Ingredients) do
	local row = new("Frame", {
		Position = UDim2.fromOffset(14 * S, (52 + (i - 1) * 62) * S),
		Size = UDim2.new(1, -28 * S, 0, 54 * S),
		BackgroundColor3 = Color3.fromRGB(250, 236, 214),
		ZIndex = 11,
		Parent = shop,
	}, { corner(12) })
	label({ Text = ing.icon .. " " .. ing.name, Position = UDim2.fromOffset(12 * S, 4 * S), Size = UDim2.fromOffset(150 * S, 26 * S), TextSize = 19 * S, ZIndex = 12, Parent = row })
	label({ Text = string.format("%d회분 묶음", ing.pack), Position = UDim2.fromOffset(12 * S, 28 * S), Size = UDim2.fromOffset(150 * S, 20 * S), TextSize = 13 * S, TextColor3 = Color3.fromRGB(150, 110, 80), Font = Enum.Font.Gotham, ZIndex = 12, Parent = row })
	local b = new("TextButton", {
		Name = "Buy_" .. ing.id,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8 * S, 0.5, 0),
		Size = UDim2.fromOffset(110 * S, 40 * S),
		BackgroundColor3 = GREEN,
		Text = string.format("%d 코인", ing.price),
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 18 * S,
		Font = Enum.Font.GothamBlack,
		ZIndex = 12,
		Parent = row,
	}, { corner(12) })
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
			shopMsg.TextColor3 = GREEN
			shopMsg.Text = string.format("%s %d회분을 샀어요", ing.name, ing.pack)
		else
			shopMsg.TextColor3 = Color3.fromRGB(200, 70, 60)
			shopMsg.Text = (ok and type(res) == "table" and res.reason) or "살 수 없어요"
		end
		busy = false
	end)
end

local function refreshButtons()
	for _, info in pairs(buyButtons) do
		local afford = state ~= nil and state.coins >= info.price
		info.button.BackgroundColor3 = afford and GREEN or Color3.fromRGB(180, 170, 160)
		info.button.AutoButtonColor = afford
	end
end

shopBtn.Activated:Connect(function()
	shop.Visible = not shop.Visible
	shopMsg.Text = ""
end)
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
	shopMsg.TextColor3 = Color3.fromRGB(200, 70, 60)
	shopMsg.Text = ing and (ing.name .. "이(가) 없어요. 사 가세요!") or ""
end)
closeBtn.Activated:Connect(function()
	shop.Visible = false
end)

---------------------------------------------------------------- 알림 (가운데 위)
local toast = new("TextLabel", {
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(0, 40 * S),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = BROWN,
	BackgroundTransparency = 0.1,
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 18 * S,
	Font = Enum.Font.GothamBold,
	Text = "",
	Visible = false,
	ZIndex = 20,
	Parent = gui,
}, { corner(12), new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }) })
local toastSeq = 0
local function showToast(text)
	toastSeq += 1
	local my = toastSeq
	toast.Text = text
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

	levelText.Text = "Lv" .. s.level
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
		ingText[ing.id].TextColor3 = n > 0 and BROWN or Color3.fromRGB(200, 70, 60)
	end
	stockText.Text = string.format("🍪 달고나 %d/%d", s.stock or 0, s.stockMax or G.StockMax)
	plotText.Text = s.plot and string.format("🏠 %d번 가게", s.plot) or ""
	saveWarn.Visible = s.saving == false
	panel.Size = UDim2.fromOffset(290 * S, (s.saving == false and 154 or 132) * S)
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

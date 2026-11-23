-- 도감 화면 (D38, 2026-11-24): 도안 23종 · 손님 7종 · 칭호 + 보상 받았을 때 알림
-- HUD 오른쪽 위 메뉴(ShopHud.Root.Menu)에 "도감" 버튼. 새 스타일(shared/UiStyle).
--
-- 서버 데이터 (저장·부지 세션이 정해서 보낼 예정 — 아직 없음). PlayerState.collection 을 이 모양으로 기대함:
--   collection = {
--     shapes = { [shapeId] = { made = true, excellent = true, perfect = true, ppopgi = true } },
--     customers = { [customerId] = { met = true, sold = 12, hearts = 1, favorite = shapeId 또는 nil(하트 2 전에는 숨김) } },
--     titles = { owned = { "커먼 장인", ... }, equipped = "커먼 장인" 또는 nil },
--   }
--   보상 알림: Remotes.CollectionReward (OnClientEvent) { title = "도감 등록!", text = "별 · 처음 Perfect", reward = "+220 코인", icon = "⭐" }
--   칭호 달기: Remotes.CollectionAction:InvokeServer("equipTitle", 이름) (서버가 만들면 씀, 없으면 화면만 바뀜)
-- 서버 데이터가 없으면 Studio에서만 예시 데이터를 보여 줌 (게임에서는 빈 도감).
-- 테스트: 이 스크립트 안 BindableEvent ShowReward:Fire({ ... }) 로 알림을 띄워 볼 수 있음.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local CustomerRig = require(Shared:WaitForChild("CustomerRig"))
local UI = require(Shared:WaitForChild("UiStyle"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C = UI.C
local new = UI.new

-- 손님 그림 대신 쓰는 동물 얼굴 + 바탕색 (2D 그림이 생기면 바꿈)
local CUSTOMER_LOOK = {
	Pongpong = { icon = "🐥", color = Color3.fromRGB(255, 224, 110), kind = "동네 아이" },
	Mochi = { icon = "🐰", color = Color3.fromRGB(250, 240, 240), kind = "동네 아이" },
	Dotori = { icon = "🐿️", color = Color3.fromRGB(214, 160, 110), kind = "동네 아이" },
	Godeungeo = { icon = "🐱", color = Color3.fromRGB(170, 180, 196), kind = "단골" },
	Kkuldanji = { icon = "🐻", color = Color3.fromRGB(240, 196, 90), kind = "단골" },
	Ppogeuli = { icon = "🐩", color = Color3.fromRGB(196, 150, 120), kind = "멋쟁이 관광객" },
	Owl = { icon = "🦉", color = Color3.fromRGB(180, 150, 220), kind = "귀한 손님" },
}
local CUSTOMER_ORDER = { "Pongpong", "Mochi", "Dotori", "Godeungeo", "Kkuldanji", "Ppogeuli", "Owl" }
local HEART_AT = { 10, 50, 150 } -- D38 하트 1·2·3

-- 칭호 목록 (D38): 등급마다 장인 + 달고나 장인 + 손님 단골집 7 + 골목 인기 가게
local function titleList()
	local list = {}
	for _, g in ipairs(ShapeCatalog.Grades) do
		table.insert(list, { name = g.label .. " 장인", cond = g.label .. " 도안을 모두 손으로 Perfect" })
	end
	table.insert(list, { name = "달고나 장인", cond = "도안 23종 모두 Perfect (가게 간판 금테)" })
	for _, id in ipairs(CUSTOMER_ORDER) do
		local t = CustomerRig.types[id]
		local nm = t and t.label or id
		table.insert(list, { name = nm .. "네 단골집", cond = nm .. "에게 150개 팔기 (하트 3)" })
	end
	table.insert(list, { name = "골목 인기 가게", cond = "손님 7종 모두 하트 3" })
	return list
end
local TITLES = titleList()

---------------------------------------------------------------- 예시 데이터 (Studio에서 서버 데이터가 없을 때만)
local function sampleData()
	local shapes = {}
	for i, e in ipairs(ShapeCatalog.list) do
		if i <= 14 then
			shapes[e.id] = { made = true, excellent = i <= 9, perfect = i <= 5, ppopgi = i == 2 or i == 6 }
		end
	end
	local customers = {
		Pongpong = { met = true, sold = 160, hearts = 3, favorite = "Heart" },
		Mochi = { met = true, sold = 62, hearts = 2, favorite = "Star" },
		Dotori = { met = true, sold = 23, hearts = 1 },
		Godeungeo = { met = true, sold = 4, hearts = 0 },
		Kkuldanji = { met = true, sold = 0, hearts = 0 },
	}
	return { shapes = shapes, customers = customers, titles = { owned = { "커먼 장인", "퐁퐁이네 단골집" }, equipped = "커먼 장인" }, sample = true }
end

local data = nil
local function currentData()
	if data then
		return data
	end
	if RunService:IsStudio() then
		return sampleData()
	end
	return { shapes = {}, customers = {}, titles = { owned = {} } }
end

---------------------------------------------------------------- 화면 + 메뉴 버튼
local toggle -- 아래에서 정의 (메뉴 버튼이 부름)
local gui = UI.screen("CollectionUi", 8, playerGui)
local root = UI.root(gui)
local fit = UI.fitter(root)

task.spawn(function()
	local menu = playerGui:WaitForChild("ShopHud"):WaitForChild("Root"):WaitForChild("Menu")
	local slot = new("Frame", { Name = "CollectionSlot", LayoutOrder = 3, Size = UDim2.fromOffset(72, 86), BackgroundTransparency = 1, Parent = menu })
	local b = UI.button({ Name = "OpenCollection", Text = "📖", Color = C.pink, Radius = 18, TextSize = 32, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(64, 66), Parent = slot })
	UI.text({ Text = "도감", TextSize = 17, TextColor3 = C.white, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 20), Parent = slot })
	b.Activated:Connect(function()
		toggle()
	end)
end)

local win, body = UI.window({ Name = "Window", Title = "📖 달고나 도감", Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.fromOffset(800, 360), ZIndex = 10, Parent = root })
fit(win, 800, 385)

-- 왼쪽 세로 탭 + 아래 모은 수
local tabCol = new("Frame", { Position = UDim2.fromOffset(10, 12), Size = UDim2.new(0, 130, 1, -24), BackgroundTransparency = 1, ZIndex = 12, Parent = body })
local TABS = { { id = "shapes", text = "도안" }, { id = "customers", text = "손님" }, { id = "titles", text = "칭호" } }
local tabs, pages = {}, {}
for i, t in ipairs(TABS) do
	tabs[t.id] = UI.button({ Name = "Tab_" .. t.id, Text = t.text, Color = C.woodLight, Position = UDim2.fromOffset(0, (i - 1) * 56), Size = UDim2.new(1, 0, 0, 50), TextSize = 21, ZIndex = 12, Parent = tabCol })
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
	}, { new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6) }) })
end
local countBox = UI.card({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = C.woodDark, ZIndex = 12, Parent = tabCol })
local countText = UI.text({ Text = "", TextSize = 16, TextColor3 = C.cream, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Size = UDim2.fromScale(1, 1), ZIndex = 13, Parent = countBox })
local sampleTag = UI.text({ Text = "예시 데이터", Visible = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 10), Size = UDim2.fromOffset(120, 20), TextSize = 14, TextColor3 = C.white, Outline = C.bad, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 16, Parent = win })

local current = "shapes"
local render
local function showTab(id)
	current = id
	for tid, p in pairs(pages) do
		p.Visible = tid == id
		UI.setButton(tabs[tid], { Color = tid == id and C.yellow or C.woodLight })
		tabs[tid]:FindFirstChildOfClass("UIStroke").Color = tid == id and C.cream or C.woodDark
	end
	render()
end
for _, t in ipairs(TABS) do
	tabs[t.id].Activated:Connect(function()
		showTab(t.id)
	end)
end

local function clear(page)
	for _, c in ipairs(page:GetChildren()) do
		if not (c:IsA("UIGridLayout") or c:IsA("UIListLayout") or c:IsA("UIPadding")) then
			c:Destroy()
		end
	end
end

-- 도안 미리보기 (도안 고르기 화면과 같은 방식: Cutters 메시를 위에서 봄)
local function shapePreview(parent, entry, dim)
	local vpf = new("ViewportFrame", {
		BackgroundColor3 = dim and Color3.fromRGB(150, 130, 110) or Color3.fromRGB(226, 172, 96),
		Ambient = Color3.fromRGB(190, 190, 195),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		Size = UDim2.new(1, -10, 1, -40),
		Position = UDim2.fromOffset(5, 5),
		ZIndex = 14,
		Parent = parent,
	}, { UI.corner(10) })
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Cutters")
	local tpl = folder and folder:FindFirstChild("Cutter_" .. entry.id)
	if tpl then
		local mesh = tpl:Clone()
		for _, c in ipairs(mesh:GetChildren()) do
			c:Destroy()
		end
		mesh.Material = Enum.Material.SmoothPlastic
		mesh.Color = dim and Color3.fromRGB(110, 96, 84) or Color3.fromRGB(70, 60, 52)
		local c = entry.data.center
		mesh.CFrame = CFrame.new(c.X, 0, -c.Y) * CFrame.Angles(0, math.pi, 0)
		mesh.Parent = vpf
	end
	local cam = new("Camera", { FieldOfView = 22, Parent = vpf })
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.6, 0), Vector3.zero, Vector3.new(0, 0, -1))
	vpf.CurrentCamera = cam
	return vpf
end

---------------------------------------------------------------- 도안 탭
local shapeGrid = new("UIGridLayout", { CellSize = UDim2.fromOffset(118, 150), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pages.shapes })

local function renderShapes(d)
	local page = pages.shapes
	clear(page)
	local made, stars = 0, 0
	for i, e in ipairs(ShapeCatalog.list) do
		local rec = d.shapes[e.id] or {}
		local g = ShapeCatalog.grade(e.grade)
		if rec.made then
			made += 1
		end
		if rec.perfect then
			stars += 1
		end
		local card = UI.card({ Name = e.id, LayoutOrder = i, BackgroundColor3 = rec.made and C.cream or C.tan, ZIndex = 13, Parent = page })
		card:FindFirstChildOfClass("UIStroke").Color = rec.perfect and C.gold or (g and g.color or C.line)
		card:FindFirstChildOfClass("UIStroke").Thickness = rec.perfect and 4 or 2.5
		local vpf = shapePreview(card, e, not rec.made)
		if not rec.made then
			UI.text({ Text = "?", FontFace = UI.F.round, TextSize = 40, TextColor3 = C.cream, Outline = C.woodDark, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 15, Parent = vpf })
		end
		UI.text({ Text = rec.made and e.name or "???", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(1, -8, 0, 18), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 14, Parent = card })
		UI.text({ Text = g and g.label or "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, -8, 0, 15), TextSize = 13, TextColor3 = g and g.color or C.soft, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14, Parent = card })
		-- 금별 (처음 Perfect) — 오른쪽 위
		if rec.perfect then
			UI.text({ Text = "★", FontFace = UI.F.round, TextSize = 34, TextColor3 = C.gold, Outline = Color3.fromRGB(176, 112, 20), TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(36, 36), ZIndex = 17, Parent = card })
		end
		-- Excellent 리본 — 왼쪽 위
		if rec.excellent then
			local rib = UI.text({ Text = "Excellent", FontFace = UI.F.round, TextSize = 11, TextColor3 = C.white, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(110, 190, 80), TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(64, 16), ZIndex = 16, Parent = card })
			UI.corner(8).Parent = rib
		end
		-- 완벽 뽑기 도장 — 가운데 아래, 빨간 둥근 도장
		if rec.ppopgi then
			local st = UI.text({ Text = "완벽\n뽑기", TextSize = 12, TextColor3 = C.red, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0.15, BackgroundColor3 = C.cream, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.78, 0, 0.55, 0), Size = UDim2.fromOffset(40, 40), Rotation = -14, ZIndex = 17, Parent = card })
			UI.corner("round").Parent = st
			UI.stroke(C.red, 2.5).Parent = st
		end
	end
	return string.format("모은 도안\n%d / %d\n금별 %d", made, #ShapeCatalog.list, stars)
end

---------------------------------------------------------------- 손님 탭
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pages.customers })

local function heartRow(parent, hearts, z)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(110, 30), ZIndex = z, Parent = parent }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i = 1, 3 do
		UI.text({ LayoutOrder = i, Text = i <= hearts and "♥" or "♡", FontFace = UI.F.round, TextSize = 28, TextColor3 = i <= hearts and C.red or C.grey, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(32, 30), ZIndex = z, Parent = row })
	end
	return row
end

local function renderCustomers(d)
	local page = pages.customers
	clear(page)
	local met, full = 0, 0
	for i, id in ipairs(CUSTOMER_ORDER) do
		local rec = d.customers[id]
		local look = CUSTOMER_LOOK[id]
		local t = CustomerRig.types[id]
		local name = t and t.label or id
		local isMet = rec and rec.met
		if isMet then
			met += 1
		end
		local hearts = rec and rec.hearts or 0
		if hearts >= 3 then
			full += 1
		end
		local card = UI.card({ LayoutOrder = i, Size = UDim2.new(1, -4, 0, 82), BackgroundColor3 = isMet and C.cream or C.tan, ZIndex = 13, Parent = page })
		local face = new("Frame", { Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = isMet and look.color or Color3.fromRGB(150, 130, 110), ZIndex = 14, Parent = card }, { UI.corner("round"), UI.stroke(C.woodDark, 3), UI.gloss(0.2) })
		UI.text({ Text = isMet and look.icon or "?", FontFace = UI.F.round, TextSize = 36, TextColor3 = C.cream, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 15, Parent = face })
		UI.text({ Text = isMet and name or "아직 못 만난 손님", Position = UDim2.fromOffset(86, 8), Size = UDim2.new(0.45, -86, 0, 26), TextSize = 21, ZIndex = 14, Parent = card })
		UI.text({ Text = look.kind, Position = UDim2.fromOffset(86, 34), Size = UDim2.new(0.45, -86, 0, 18), TextSize = 14, FontFace = UI.F.bold, TextColor3 = C.soft, ZIndex = 14, Parent = card })
		-- 판 개수 막대 (다음 하트까지)
		local sold = rec and rec.sold or 0
		local nextAt = HEART_AT[math.min(hearts + 1, 3)]
		local back, fill, txt = UI.bar({ Position = UDim2.fromOffset(86, 56), Size = UDim2.new(0.45, -96, 0, 16), Color = C.pink, ZIndex = 14, Parent = card })
		fill.Size = UDim2.fromScale(math.clamp(sold / nextAt, 0, 1), 1)
		txt.Text = hearts >= 3 and string.format("%d개 · 최고 단골", sold) or string.format("%d / %d개", sold, nextAt)
		back.Visible = isMet
		-- 하트 3개
		local hr = heartRow(card, hearts, 14)
		hr.AnchorPoint = Vector2.new(0, 0.5)
		hr.Position = UDim2.new(0.45, 6, 0.5, 0)
		-- 좋아하는 도안 (하트 2에 공개)
		local fav = rec and rec.favorite and ShapeCatalog.get(rec.favorite)
		local favBox = UI.card({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.55, -136, 0, 60), BackgroundColor3 = hearts >= 2 and Color3.fromRGB(255, 236, 240) or C.tan, ZIndex = 14, Parent = card })
		UI.text({ Text = "좋아하는 도안", Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 18), TextSize = 13, FontFace = UI.F.bold, TextColor3 = C.soft, ZIndex = 15, Parent = favBox })
		UI.text({
			Text = (hearts >= 2 and fav) and ("♥ " .. fav.name) or "하트 2에 공개",
			Position = UDim2.fromOffset(10, 24),
			Size = UDim2.new(1, -20, 0, 28),
			TextSize = (hearts >= 2 and fav) and 21 or 16,
			TextColor3 = (hearts >= 2 and fav) and C.red or C.soft,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 15,
			Parent = favBox,
		})
	end
	return string.format("만난 손님\n%d / %d\n하트 3: %d", met, #CUSTOMER_ORDER, full)
end

---------------------------------------------------------------- 칭호 탭
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pages.titles })

local function equipTitle(d, name)
	d.titles.equipped = name
	local action = Remotes:FindFirstChild("CollectionAction")
	if action then
		task.spawn(function()
			pcall(function()
				action:InvokeServer("equipTitle", name)
			end)
		end)
	end
	render()
end

local function renderTitles(d)
	local page = pages.titles
	clear(page)
	local owned = {}
	for _, n in ipairs(d.titles.owned or {}) do
		owned[n] = true
	end
	local count = 0
	for i, t in ipairs(TITLES) do
		local has = owned[t.name] == true
		if has then
			count += 1
		end
		local on = d.titles.equipped == t.name
		local row = UI.card({ LayoutOrder = (has and 0 or 100) + i, Size = UDim2.new(1, -4, 0, 62), BackgroundColor3 = has and C.cream or C.tan, ZIndex = 13, Parent = page })
		if on then
			row:FindFirstChildOfClass("UIStroke").Color = C.gold
			row:FindFirstChildOfClass("UIStroke").Thickness = 4
		end
		UI.text({ Text = (has and "🏅 " or "🔒 ") .. t.name, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -190, 0, 26), TextSize = 20, TextColor3 = has and C.ink or C.soft, ZIndex = 14, Parent = row })
		UI.text({ Text = t.cond, Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -190, 0, 20), TextSize = 14, FontFace = UI.F.bold, TextColor3 = C.soft, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 14, Parent = row })
		if has then
			local b = UI.button({ Text = on and "다는 중" or "달기", Color = on and C.green or C.yellow, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 46), TextSize = 19, ZIndex = 14, Parent = row })
			b.Activated:Connect(function()
				if not on then
					equipTitle(d, t.name)
				end
			end)
		end
	end
	return string.format("모은 칭호\n%d / %d", count, #TITLES)
end

---------------------------------------------------------------- 그리기 · 열고 닫기
local shown = nil -- 지금 그린 데이터 (예시면 계속 같은 표를 씀)
function render()
	if not win.Visible then
		return
	end
	shown = shown or currentData()
	sampleTag.Visible = shown.sample == true
	local fn = (current == "shapes" and renderShapes) or (current == "customers" and renderCustomers) or renderTitles
	countText.Text = fn(shown)
end

toggle = function()
	win.Visible = not win.Visible
	if win.Visible then
		shown = nil
		showTab(current)
	end
end
win.Close.Activated:Connect(function()
	win.Visible = false
end)

Remotes:WaitForChild("PlayerState").OnClientEvent:Connect(function(s)
	if type(s) == "table" and type(s.collection) == "table" then
		data = s.collection
		data.shapes = data.shapes or {}
		data.customers = data.customers or {}
		data.titles = data.titles or { owned = {} }
		if win.Visible then
			shown = data
			render()
		end
	end
end)

-- 제작 화면이 켜지면 도감 창 닫기
local function watchMaking(screen)
	screen:GetPropertyChangedSignal("Enabled"):Connect(function()
		if screen.Enabled then
			win.Visible = false
		end
	end)
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

---------------------------------------------------------------- 보상 알림 (도감 등록 · 하트 · 칭호)
-- 화면 위 가운데에서 내려오는 크림 카드: 아이콘 동그라미 + 제목(나무 리본) + 내용 + 보상
local toastQueue = {}
local toastBusy = false
local function playToast(r)
	toastBusy = true
	local card = UI.card({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -10), Size = UDim2.fromOffset(460, 92), ZIndex = 40, Parent = root })
	card:FindFirstChildOfClass("UIStroke").Color = C.woodDark
	card:FindFirstChildOfClass("UIStroke").Thickness = 3.5
	fit(card)
	local icon = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(66, 66), BackgroundColor3 = C.gold, ZIndex = 41, Parent = card }, { UI.corner("round"), UI.stroke(C.woodDark, 3), UI.gloss(0.25) })
	UI.text({ Text = r.icon or "📖", TextSize = 36, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 42, Parent = icon })
	local rib = UI.text({ Text = r.title or "도감 등록!", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(92, 0), Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0, BackgroundColor3 = C.wood, TextSize = 17, TextColor3 = C.cream, Outline = C.woodDark, ZIndex = 42, Parent = card })
	UI.corner(8).Parent = rib
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = rib })
	UI.text({ Text = r.text or "", Position = UDim2.fromOffset(92, 20), Size = UDim2.new(1, -104, 0, 30), TextSize = 20, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 41, Parent = card })
	UI.text({ Text = r.reward or "", Position = UDim2.fromOffset(92, 52), Size = UDim2.new(1, -104, 0, 26), TextSize = 19, FontFace = UI.F.round, TextColor3 = C.good, ZIndex = 41, Parent = card })
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 110) }):Play()
	task.delay(3.2, function()
		local tw = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -10) })
		tw:Play()
		tw.Completed:Wait()
		card:Destroy()
		toastBusy = false
		local nextR = table.remove(toastQueue, 1)
		if nextR then
			playToast(nextR)
		end
	end)
end

local function showReward(r)
	if type(r) ~= "table" then
		return
	end
	if toastBusy then
		table.insert(toastQueue, r)
	else
		playToast(r)
	end
end

local ev = Instance.new("BindableEvent")
ev.Name = "ShowReward"
ev.Parent = script
ev.Event:Connect(showReward)

local function hookReward(remote)
	remote.OnClientEvent:Connect(showReward)
end
local rr = Remotes:FindFirstChild("CollectionReward")
if rr then
	hookReward(rr)
else
	Remotes.ChildAdded:Connect(function(c)
		if c.Name == "CollectionReward" and c:IsA("RemoteEvent") then
			hookReward(c)
		end
	end)
end

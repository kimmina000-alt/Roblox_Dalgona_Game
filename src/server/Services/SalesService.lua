-- 판매: 진열대 + 손님 NPC (Phase 3, 2026-11-20)
--  - 부지마다 진열대 10칸. 보관함(저장 데이터 stock) 앞쪽 10개가 진열되고, 먼저 만든 것부터 팔린다 (FIFO).
--  - 주인이 접속해 있고 진열대에 달고나가 있으면 손님이 골목에서 걸어와(웨이포인트) 사 간다. 가게당 동시 3명.
--  - 방문 간격·1명당 개수는 설비 단계(machineStage)와 1단계 국자 수로 정해진다 (D12, GrowthConfig.salesDemand).
--  - 중복 판매 방지: 손님이 나타날 때 살 개수를 "예약"하고(예약 합 ≤ 진열 개수), 진열대에 닿으면
--    EconomyService.sell이 한 번에 꺼내고 지운다. 그 사이 yield가 없어서 같은 달고나가 두 번 팔리지 않는다.
-- 손님은 Humanoid 없이 부품으로 만든 작은 인형(서버가 위치를 옮김) — 폰 부담을 줄이려고.
-- 2026-11-21 사용자: 진열대에는 내가 만든 완성품 모양 그대로 (Shared.DalgonaLook, 없으면 원판),
--   손님은 산 달고나를 손에 들고 입에 가져다 대며 먹으면서 걸어감.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local ShapeCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShapeCatalog"))
local SALES = G.Sales

local SalesService = {}

local Data, Economy, Plots = nil, nil, nil
local shops = {} -- [plotIndex] = { shelf, slots = {}, customers = {}, reserved, nextVisit, owner }
local saleFloat = nil -- Remotes.SaleFloat (주인 화면에 "+n코인" 글씨)
local Collection = nil -- CollectionService (도감, 처음 쓸 때 가져옴)
local walkers = {} -- 움직이는 손님 { model, path, seg, t, onArrive }

local DALGONA = Color3.fromRGB(214, 150, 70)
local GRADE_RIM = {
	Perfect = Color3.fromRGB(255, 205, 40),
	Excellent = Color3.fromRGB(120, 200, 90),
	Good = Color3.fromRGB(80, 160, 230),
	Normal = Color3.fromRGB(170, 170, 170),
	Poor = Color3.fromRGB(190, 120, 70),
	Fail = Color3.fromRGB(120, 90, 70),
	Burnt = Color3.fromRGB(50, 34, 26),
}
local SHIRTS = {
	Color3.fromRGB(255, 150, 160), Color3.fromRGB(140, 200, 255), Color3.fromRGB(255, 210, 110),
	Color3.fromRGB(160, 220, 150), Color3.fromRGB(200, 160, 240), Color3.fromRGB(255, 180, 120),
}
local SKINS = { Color3.fromRGB(255, 220, 190), Color3.fromRGB(235, 190, 150), Color3.fromRGB(190, 140, 100) }
local LINES = { "맛있겠다!", "이거 주세요!", "달고나다~", "하나 더!", "냄새 좋다" }

local function part(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

---------------------------------------------------------------- 완성품 모양 (Shared.DalgonaLook)
-- DalgonaLook.build(item, { diameter }) → Model (PrimaryPart Disc). 피벗 = 원판 가운데, 넓은 면 = 로컬 +Y, 막대 = 로컬 +Z (눕힘 기본)
-- 모듈이 없거나 실패하면 원판(+ 등급 테두리)으로 대신함

local lookMod = nil -- nil 아직 안 찾음, false 없음

local function dalgonaLook()
	if lookMod == nil then
		local m = ReplicatedStorage.Shared:FindFirstChild("DalgonaLook")
		local ok, mod = false, nil
		if m then
			ok, mod = pcall(require, m)
		end
		lookMod = (ok and type(mod) == "table" and mod.build) and mod or false
	end
	return lookMod or nil
end

local function settle(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	return model
end

local function buildLook(item, size)
	local L = dalgonaLook()
	if L then
		local ok, model = pcall(L.build, item, { diameter = size })
		if ok and typeof(model) == "Instance" and model:IsA("Model") then
			if not model.PrimaryPart then
				model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
			end
			model.Name = "DalgonaLook"
			return settle(model)
		end
		warn("[Sales] DalgonaLook.build failed", model)
	end
	-- 대신: 원판 + 등급 테두리 + 막대
	local m = Instance.new("Model")
	m.Name = "DalgonaLook"
	local burnt = item and item.g == "Burnt"
	local disc = part(m, "Disc", Vector3.new(size * 0.12, size, size), CFrame.Angles(0, 0, math.rad(90)), burnt and Color3.fromRGB(60, 40, 28) or DALGONA, nil, { Shape = Enum.PartType.Cylinder })
	part(m, "Rim", Vector3.new(size * 0.08, size * 1.08, size * 1.08), CFrame.Angles(0, 0, math.rad(90)), GRADE_RIM[item and item.g] or GRADE_RIM.Normal, nil, { Shape = Enum.PartType.Cylinder })
	if not (item and (item.plain or item.bread)) then
		part(m, "Stick", Vector3.new(size * 0.07, size * 0.07, size * 0.75), CFrame.new(0, 0, size * 0.75), Color3.fromRGB(235, 215, 170))
	end
	m.PrimaryPart = disc
	disc.PivotOffset = disc.CFrame:Inverse() -- 피벗 = 원판 가운데, 돌리지 않은 방향 (넓은 면 +Y)
	return settle(m)
end

local function lookKey(item)
	local pp = type(item.pp) == "table" and (tostring(item.pp[1]) .. "," .. tostring(item.pp[2])) or ""
	return table.concat({ tostring(item.id), tostring(item.s), tostring(item.g), tostring(item.pk), tostring(item.plain), tostring(item.br), tostring(item.bread), pp }, "|")
end

---------------------------------------------------------------- 진열대

-- 진열 가구 (가게 3D 부품 속성 Role, 2026-11-24 사용자): 칸 자리를 가구 기준으로 계산해서, 편집 화면(PlotLayout.ShopModel)에서
-- 가구를 옮기면 칸도 따라감. 칸 번호는 아래 GRID (격자, 2026-11-24)
-- 2026-11-24 사용자: 작은 탁자 하나 더 (작은 탁자 3 = 11칸)
local AREA_ROLES = { case = "유리 진열장", peg = "달고나 걸이판", table1 = "작은 탁자", table2 = "작은 탁자 2", table3 = "작은 탁자 3", counter = "앞 카운터 (나무)", wall = "벽면 진열장" }
local SHOP_ONLY_ROLES = { "앞 카운터 (나무)", "유리 진열장", "진열장 받침 (금속)", "진열 이름표 띠" }
-- 격자 칸 (2026-11-24 사용자 "격자처럼 달고나 자리 만들어서"): 걸이판 6×5 = 30, 작은 탁자마다 3×3 = 9 (탁자 3개)
-- 칸 번호: 1~4 유리 진열장, 5~34 걸이판(위 줄 왼쪽부터), 35~43 작은 탁자, 44~52 작은 탁자 2, 53~61 작은 탁자 3 → 모두 61 (G.Sales.shelfSlots)
local GRID = {
	{ key = "case", first = 1, cols = 4, rows = 1 },
	{ key = "peg", first = 5, cols = 6, rows = 5 },
	{ key = "table1", first = 35, cols = 3, rows = 3 },
	{ key = "table2", first = 44, cols = 3, rows = 3 },
	{ key = "table3", first = 53, cols = 3, rows = 3 },
	-- 벽면 진열장 (D57 6단계, 3D 세션 claude/wall-case-1127): 뒤판 WallCaseBack(Role "벽면 진열장") = 칸 상자, 4열 × 3단 = 62~73.
	-- 걸이판과 같은 계산 (선반 윗면 = 칸 가운데 − (lookSize/2 + lookStick[1]))
	{ key = "wall", first = 62, cols = 4, rows = 3 },
}
local AREA_SLOTS, SLOT_AREA = {}, {} -- [area] = { 칸들 }, [칸] = { grid, k (0부터) }
for _, g in ipairs(GRID) do
	AREA_SLOTS[g.key] = {}
	for k = 0, g.cols * g.rows - 1 do
		table.insert(AREA_SLOTS[g.key], g.first + k)
		SLOT_AREA[g.first + k] = { g = g, k = k }
	end
end
local TABLE_SLOT = { table1 = true, table2 = true, table3 = true }
SalesService.AREA_ROLES = AREA_ROLES

local function findRole(model, role)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Role") == role then
			return d
		end
	end
	return nil
end

-- 가게 기준 축으로 본 부품 상자: 가운데(로컬), 반 크기
local function localBox(plotCF, p)
	local l = plotCF:ToObjectSpace(p.CFrame)
	local r, u, k, sz = l.RightVector, l.UpVector, l.LookVector, p.Size
	local half = Vector3.new(
		math.abs(r.X) * sz.X + math.abs(u.X) * sz.Y + math.abs(k.X) * sz.Z,
		math.abs(r.Y) * sz.X + math.abs(u.Y) * sz.Y + math.abs(k.Y) * sz.Z,
		math.abs(r.Z) * sz.X + math.abs(u.Z) * sz.Y + math.abs(k.Z) * sz.Z
	) / 2
	return l.Position, half
end

-- 작은 탁자 테이블보 (2026-11-24 사용자 "벽 진열대 아래 진열대 3개에 테이블보 깔기, 테이블이 사각형인데 마름모 모양으로"):
-- 흰 천(탁자보다 조금 넓게, 네 옆으로 짧게 내려옴) 위에 꽃무늬 천을 45° 돌려 마름모로 겹침. 마름모 끝은 탁자 옆 가운데에서 살짝 내려옴.
-- 천은 얇게 윗면에 붙어 진열 칸(3×3)을 가리지 않음 (칸 높이는 CLOTH_LIFT만큼 올림). 색·무늬는 G.ShopCloth
local CLOTH_LIFT = 0.12
local function clothPart(parent, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Fabric
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false -- 눌러 진열할 때 광선이 탁자에 닿게
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function addTexture(p, face)
	local C = G.ShopCloth
	if C and C.texture then
		local t = Instance.new("Texture")
		t.Texture = C.texture
		t.Face = face
		t.StudsPerTileU = C.tile or 2
		t.StudsPerTileV = C.tile or 2
		t.Parent = p
	end
end
local function tableCloth(plotCF, table_)
	local C = G.ShopCloth or {}
	local parent = table_.Parent and table_.Parent:IsA("Model") and table_.Parent or table_
	local old = parent:FindFirstChild("TableCloth")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = "TableCloth"
	local c, h = localBox(plotCF, table_)
	local topY = c.Y + h.Y
	local base = plotCF * CFrame.new(c.X, topY, c.Z) -- 탁자 윗면 가운데, 가게 축
	local white = C.white or Color3.fromRGB(252, 250, 244)
	local flower = C.floral or Color3.fromRGB(226, 238, 222)
	-- 흰 천 + 네 옆 드리움
	local ov, drop = 0.18, 0.9 -- 흰 천은 길게 (참고 사진: 프릴 흰 천이 탁자 옆으로 길게)
	clothPart(folder, "ClothWhite", Vector3.new(h.X * 2 + ov * 2, 0.05, h.Z * 2 + ov * 2), base * CFrame.new(0, 0.03, 0), white)
	for _, s in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		local alongX = s[2] ~= 0 -- 앞뒤 면이면 X로 긴 천
		local size = alongX and Vector3.new(h.X * 2 + ov * 2, drop, 0.05) or Vector3.new(0.05, drop, h.Z * 2 + ov * 2)
		local off = Vector3.new(s[1] * (h.X + ov), -drop / 2 + 0.05, s[2] * (h.Z + ov))
		clothPart(folder, "ClothWhiteSide", size, base * CFrame.new(off), white)
	end
	-- 꽃무늬 마름모 (정사각형을 45° 돌림): 끝이 탁자 옆 가운데를 조금 넘음
	local reach = math.max(h.X, h.Z) + 0.3
	local side = reach * math.sqrt(2)
	local dia = clothPart(folder, "ClothFloral", Vector3.new(side, 0.04, side), base * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, math.rad(45), 0), flower)
	addTexture(dia, Enum.NormalId.Top)
	-- 마름모 끝이 탁자 밖으로 나온 곳에 짧게 드리운 끝자락
	local tipDrop = 0.6
	for _, s in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		local half = s[1] ~= 0 and h.X or h.Z
		if reach > half + ov then
			local w = 0.5
			local size = s[1] ~= 0 and Vector3.new(0.04, tipDrop, w) or Vector3.new(w, tipDrop, 0.04)
			local off = Vector3.new(s[1] * (h.X + ov + 0.03), -tipDrop / 2 + 0.08, s[2] * (h.Z + ov + 0.03))
			local flap = clothPart(folder, "ClothFloralTip", size, base * CFrame.new(off), flower)
			addTexture(flap, s[1] > 0 and Enum.NormalId.Right or s[1] < 0 and Enum.NormalId.Left or s[2] > 0 and Enum.NormalId.Back or Enum.NormalId.Front)
		end
	end
	folder.Parent = parent
	return folder
end

-- 걸이판에 거는 자리 (가게 기준, 판 가운데에서 위아래 dy·옆 dz), 기본 2×2
local function pegDefault(k, half)
	local col = (k - 1) % 2
	local row = (k - 1) // 2
	return (row == 0 and 0.35 or -0.15) * half.Y, (col == 0 and -0.45 or 0.45) * half.Z
end

-- 가구 기준 칸 자리 (막대 꽂는 자리, LookVector = 달고나 넓은 면이 보는 쪽). 가구가 없으면 nil
local function furnitureSlot(shop, i, item)
	local A = shop.areas
	local pcf = shop.plotCF
	if not (A and pcf) then
		return nil
	end
	local function at(pos, dir)
		return pcf * CFrame.lookAt(pos, pos + dir)
	end
	-- 노점 (가게 임대 전·문 닫힘, 2026-11-24 사용자): 쟁반 5칸 = 가게 앞 작은 탁자 위, 골목(-Z)을 봄. 앞줄 3 + 뒷줄 2
	if shop.stall and A.table1 then
		local c, h = localBox(pcf, A.table1)
		local row = i <= 3 and 0 or 1
		local col = i <= 3 and (i - 2) or (i == 4 and -0.5 or 0.5)
		local pos = Vector3.new(c.X + col * h.X * 0.6, c.Y + h.Y + 0.02 + CLOTH_LIFT, c.Z - h.Z * 0.35 + row * h.Z * 0.7) -- 테이블보 위
		return at(pos, Vector3.new(0, 0, -1))
	end
	local sa = SLOT_AREA[i]
	local part0 = sa and A[sa.g.key]
	if not part0 then
		return nil
	end
	local g, k = sa.g, sa.k
	local col, row = k % g.cols, k // g.cols -- 0부터
	local c, h = localBox(pcf, part0)
	if g.key == "case" then
		local x = c.X + h.X - (col + 0.5) * (2 * h.X / g.cols) -- 길에서 볼 때 왼쪽부터
		return at(Vector3.new(x, c.Y - h.Y + 0.12, c.Z), Vector3.new(0, 0, -1))
	elseif g.key == "peg" or g.key == "wall" then
		local nx = c.X < 0 and 1 or -1 -- 가게 안쪽을 보는 면
		local dz = -h.Z + (col + 0.5) * (2 * h.Z / g.cols)
		local dy = h.Y - (row + 0.5) * (2 * h.Y / g.rows) -- 위 줄부터
		local lift = SALES.lookSize * 0.5 + SALES.lookStick[1] -- 칸 가운데 = 달고나 가운데
		return at(Vector3.new(c.X + nx * (h.X + 0.08), c.Y + dy - lift, c.Z + dz), Vector3.new(nx, 0, 0))
	end
	-- 작은 탁자: 윗면에 3×3, 달고나 넓은 면은 카운터 쪽.
	-- 2026-11-26 사용자 "테이블 선에 맞춰서": 카운터 방향을 그대로 쓰면 비스듬해서 줄이 탁자 변과 어긋나고 모서리 밖으로 나감
	-- → 카운터 쪽에 가장 가까운 탁자 변 방향(가게 축 ±X 또는 ±Z)으로 맞추고, 달고나 반 너비만큼 가장자리 안쪽에 둠
	local dir = Vector3.new(1, 0, 0)
	if A.counter then
		local cc = localBox(pcf, A.counter)
		local v = Vector3.new(cc.X - c.X, 0, cc.Z - c.Z)
		if v.Magnitude > 0.1 then
			if math.abs(v.X) >= math.abs(v.Z) then
				dir = Vector3.new(v.X > 0 and 1 or -1, 0, 0)
			else
				dir = Vector3.new(0, 0, v.Z > 0 and 1 or -1)
			end
		end
	end
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local edge = SALES.lookSize * 0.5 + 0.05 -- 달고나 반 너비 + 조금
	local wR = math.max(0.2, math.abs(right.X) * h.X + math.abs(right.Z) * h.Z - edge) -- 반 너비 (옆), 가장자리 안쪽
	local wD = math.max(0.2, math.abs(dir.X) * h.X + math.abs(dir.Z) * h.Z - 0.25) -- 반 깊이 (카운터 쪽)
	local off = right * (-wR + (col + 0.5) * (2 * wR / g.cols)) + dir * (wD - (row + 0.5) * (2 * wD / g.rows)) -- 앞줄(카운터 쪽)부터
	local pos = Vector3.new(c.X + off.X, c.Y + h.Y + 0.02 + CLOTH_LIFT, c.Z + off.Z) -- 테이블보 위
	return at(pos, dir)
end

local function slotCFrame(shop, i, item)
	local f = furnitureSlot(shop, i, item)
	if f then
		return f
	end
	-- 편집 화면 틀(PlotLayout.DisplayShelf)로 칸을 옮겼으면 그 칸 자리 (원판에서 거꾸로 계산)
	if shop.slotCF and shop.slotCF[i] then
		return shop.slotCF[i]
	end
	-- 2줄 × 5칸, 앞줄(골목 쪽)부터 채움. 앞줄 = 먼저 팔리는 것
	local row = (i - 1) // 5 -- 0 앞줄, 1 뒷줄
	local col = (i - 1) % 5
	local w = SALES.shelf.size.X
	local x = -w / 2 + w / 10 + col * (w / 5)
	local z = row == 0 and -0.5 or 0.5
	return shop.top * CFrame.new(x, 0.12 + row * 0.35, z)
end

local function buildShelf(shop, plot)
	local cf = plot.cframe * CFrame.new(SALES.shelf.pos)
	local size = SALES.shelf.size
	local m = Instance.new("Model")
	m.Name = "DisplayShelf"
	local wood = Color3.fromRGB(176, 124, 80)
	local body = part(m, "Body", Vector3.new(size.X, size.Y - 0.3, size.Z), cf * CFrame.new(0, (size.Y - 0.3) / 2 + G.Plots.size.Y, 0), wood, Enum.Material.WoodPlanks, { CanCollide = true, CanQuery = true })
	-- 계단처럼 뒷줄이 조금 높은 판
	local topY = G.Plots.size.Y + size.Y - 0.3
	part(m, "TopFront", Vector3.new(size.X, 0.15, size.Z / 2), cf * CFrame.new(0, topY + 0.075, -size.Z / 4), Color3.fromRGB(250, 240, 225))
	part(m, "TopBack", Vector3.new(size.X, 0.5, size.Z / 2), cf * CFrame.new(0, topY + 0.25, size.Z / 4), Color3.fromRGB(240, 226, 205))
	shop.top = cf * CFrame.new(0, topY + 0.15, 0)
	-- 앞면 글씨 "진열대 n/10"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.45)
	label.Position = UDim2.fromScale(0, 0.1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 246, 225)
	label.TextStrokeTransparency = 0.5
	label.Text = "진열대 0/" .. SALES.shelfSlots
	label.Parent = gui
	gui.Parent = body
	shop.label = label
	-- 진열 칸 (비어 있으면 숨김)
	for i = 1, SALES.shelfSlots do
		local d = part(m, "Slot" .. i, Vector3.new(0.18, 1.3, 1.3), slotCFrame(shop, i) * CFrame.new(0, 0.09, 0) * CFrame.Angles(0, 0, math.rad(90)), DALGONA, Enum.Material.SmoothPlastic, {
			Shape = Enum.PartType.Cylinder,
			Transparency = 1,
		})
		local rim = part(m, "Rim" .. i, Vector3.new(0.1, 1.42, 1.42), d.CFrame * CFrame.new(-0.05, 0, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, {
			Shape = Enum.PartType.Cylinder,
			Transparency = 1,
		})
		-- 놓기는 가구를 눌러서 (2026-11-24, ShelfClient → Remotes.ShelfPlace). 칸마다 버튼(ProximityPrompt)은 없앰
		shop.slots[i] = { disc = d, rim = rim }
	end
	-- 편집 화면에서 고친 진열대 모양 (PlotLayout 안 DisplayShelf, 2026-11-22). 칸·손님 자리도 옮긴 부품을 따름
	if Plots.applyChild then
		Plots.applyChild(plot.model, m)
	end
	shop.slotCF = {}
	for i, s in ipairs(shop.slots) do
		if s.disc.Parent then
			shop.slotCF[i] = s.disc.CFrame * CFrame.Angles(0, 0, math.rad(-90)) * CFrame.new(0, -0.09, 0)
		end
		s.disc.Transparency = 1 -- 틀에서는 칸이 보이게 반투명으로 둬도, 게임에서는 놓일 때만 보임
		s.rim.Transparency = 1
	end
	-- 가게 3D 진열 가구가 있으면 옛 진열대 몸통은 안 보이는 자리 표시일 뿐: 부딪히지 않게 (2026-11-24, 카운터 뒤 투명 벽)
	if body.Parent and findRole(plot.model, AREA_ROLES.case) then
		body.CanCollide = false
		body.CanQuery = false
		body.Transparency = 1
	end
	-- 손님: 진열대 몸통 앞(-Z) SALES.standZ - shelf.pos.Z 만큼 떨어진 곳 (부지 기준 x, z)
	local bodyCF = body.Parent and body.CFrame or cf
	local front = SALES.standZ - SALES.shelf.pos.Z -- 음수 = 앞
	local function toLocal(p)
		local l = plot.cframe:PointToObjectSpace(p)
		return Vector3.new(l.X, 0, l.Z)
	end
	shop.shelfLocal = toLocal(bodyCF.Position)
	shop.standLocal = toLocal((bodyCF * CFrame.new(0, 0, -front)).Position)
	shop.standSide = toLocal((bodyCF * CFrame.new(1, 0, -front)).Position) - shop.standLocal
	-- 손님 주문 자리 (2026-11-23 사용자: 카운터를 넘어오지 말고 카운터 앞 의자 쪽에서 주문): 틀 부품 CustomerSpot이 있으면 그 자리,
	-- 그 부품의 앞(LookVector)을 보고 섬. 게임에서는 안 보임
	local spotPart = plot.model:FindFirstChild("CustomerSpot")
	if spotPart and spotPart:IsA("BasePart") then
		shop.standLocal = toLocal(spotPart.Position)
		shop.standSide = toLocal(spotPart.Position + spotPart.CFrame.RightVector) - shop.standLocal
		shop.shelfLocal = toLocal(spotPart.Position + spotPart.CFrame.LookVector * 4)
		spotPart.Transparency = 1
		for _, g in ipairs(spotPart:GetChildren()) do
			if g:IsA("SurfaceGui") then
				g.Enabled = false
			end
		end
	end
	-- 진열장 앞 이름표 카드 (가게 3D의 SurfaceGui CardNames.Card1~4 = 진열 1~4칸의 도안 이름)
	local cards = plot.model:FindFirstChild("CardNames", true)
	shop.cards = {}
	if cards then
		for i = 1, 4 do
			local c = cards:FindFirstChild("Card" .. i, true)
			if c and c:IsA("TextLabel") then
				shop.cards[i] = c
				c.Text = ""
			end
		end
	end
	-- 진열 가구 (가게 3D)
	shop.plotCF = plot.cframe
	shop.areas = {}
	for key, role in pairs(AREA_ROLES) do
		shop.areas[key] = findRole(plot.model, role)
	end
	-- 가게를 열어야 보이는 가구 (2026-11-24 사용자: 카운터·유리 진열장은 가게 입주하면 나타남)
	shop.shopOnly = {}
	for _, role in ipairs(SHOP_ONLY_ROLES) do
		local part = findRole(plot.model, role)
		local node = part and part.Parent
		local root = (node and node:IsA("Model") and node ~= plot.model) and node or part
		if root then
			table.insert(shop.shopOnly, root)
		end
	end
	-- 빈 가게면 숨기는 가게 앞 작은 탁자
	shop.stallOnly = {}
	if shop.areas.table1 then
		local node = shop.areas.table1.Parent
		table.insert(shop.stallOnly, (node and node:IsA("Model") and node ~= plot.model) and node or shop.areas.table1)
	end
	-- 작은 탁자 3개에 테이블보 (아래 tableCloth): 탁자와 같은 묶음에 넣어 보이기·숨기기를 같이 따름
	for _, key in ipairs({ "table1", "table2", "table3" }) do
		local t = shop.areas[key]
		if t then
			pcall(tableCloth, shop.plotCF, t)
		end
	end
	-- 노점 손님 자리: 가게 앞 작은 탁자 앞(골목 쪽)
	if shop.areas.table1 then
		local c, h = localBox(shop.plotCF, shop.areas.table1)
		shop.stallStandLocal = Vector3.new(c.X, 0, c.Z - h.Z - 1.6)
	end
	m.Parent = plot.model
	shop.shelf = m
end

-- 가게 열림/닫힘에 따라 카운터·유리 진열장 보이기 (부품마다 원래 투명도·충돌을 속성으로 기억)
local function setGroupVisible(roots, open)
	for _, root in ipairs(roots) do
		local list = root:IsA("BasePart") and { root } or {}
		for _, d in ipairs(root:GetDescendants()) do
			table.insert(list, d)
		end
		for _, d in ipairs(list) do
			if d:IsA("BasePart") then
				if d:GetAttribute("OpenT") == nil then
					d:SetAttribute("OpenT", d.Transparency)
					d:SetAttribute("OpenCollide", d.CanCollide)
				end
				d.Transparency = open and d:GetAttribute("OpenT") or 1
				d.CanCollide = open and d:GetAttribute("OpenCollide") or false
				d.CanQuery = open
			elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
				d.Enabled = open
			elseif d:IsA("Decal") or d:IsA("Texture") then
				if d:GetAttribute("OpenT") == nil then
					d:SetAttribute("OpenT", d.Transparency)
				end
				d.Transparency = open and d:GetAttribute("OpenT") or 1
			end
		end
	end
end

-- 가게 열림/닫힘·빈 가게에 따라 가구 보이기: 카운터·유리 진열장 = 가게가 열려야, 가게 앞 작은 탁자(노점 진열) = 주인이 있어야
local function setShopFurniture(shop, open, owned)
	local key = tostring(open) .. tostring(owned)
	if shop.furnitureKey == key then
		return
	end
	shop.furnitureKey = key
	setGroupVisible(shop.shopOnly or {}, open)
	setGroupVisible(shop.stallOnly or {}, owned) -- 빈 가게에는 진열대가 안 보임 (2026-11-24 사용자)
end

local function refreshShelf(index)
	local shop = shops[index]
	if not shop or not shop.shelf then
		return
	end
	local data = shop.owner and Data.get(shop.owner)
	local stock = data and data.stock or {}
	local slots = data and G.shelfSlots(data) or G.Shop.stallSlots
	-- 노점이면 쟁반 5칸을 가게 앞 작은 탁자에, 카운터·유리 진열장은 숨김 (2026-11-24)
	local open = data ~= nil and G.shopOpen(data)
	local plotM = Plots.plotAt(index)
	if plotM and plotM.model:GetAttribute("ShopOpen") ~= open then
		plotM.model:SetAttribute("ShopOpen", open) -- 클라이언트 ShelfClient가 누를 가구를 고름
	end
	setShopFurniture(shop, open, data ~= nil)
	if shop.stall ~= (not open) then
		shop.stall = not open
		for _, s in ipairs(shop.slots) do
			s.lookKey = nil -- 자리가 바뀌니 다시 놓음
		end
	end
	-- 칸마다 놓인 달고나 (item.sl)
	local bySlot = {}
	local n = 0
	local openSet = {}
	if data then
		for _, k in ipairs(G.openSlots(data)) do
			openSet[k] = true
		end
	else
		for k = 1, slots do
			openSet[k] = true
		end
	end
	for _, it in ipairs(stock) do
		if it.sl and openSet[it.sl] and not bySlot[it.sl] then
			bySlot[it.sl] = it
			n += 1
		end
	end
	for i, s in ipairs(shop.slots) do
		local item = bySlot[i]
		if item then
			s.disc.Transparency = 0
			s.rim.Transparency = 0
			s.rim.Color = GRADE_RIM[item.g] or GRADE_RIM.Normal
			s.disc.Color = (item.g == "Burnt") and Color3.fromRGB(60, 40, 28) or DALGONA
			s.disc:SetAttribute("Shape", ShapeCatalog.itemName(item)) -- 달고나빵·민짜는 그 이름 (2026-11-27)
			s.disc:SetAttribute("Hand", item.hand == true or nil) -- 손 제작 "수제" 도장 (D58, UI 화면)
			-- 완성품 모양으로 진열: 원판·테두리는 숨기고(칸 안내 자리로만 씀) 모양 모델을 눕혀 둠
			local key = lookKey(item)
			if s.lookKey ~= key then
				if s.look then
					s.look:Destroy()
				end
				local look = buildLook(item, SALES.lookSize)
				-- 세워서 진열 (사용자 2026-11-21): 막대를 진열대 윗면에 꽂고 넓은 면은 골목(-Z) 쪽, 막대는 아래.
				-- 뒷줄은 막대를 더 길게 보여 앞줄 위로 보이게
				local stick = shop.areas and next(shop.areas) and SALES.lookStick[1] or (SALES.lookStick[(i - 1) // 5 + 1] or SALES.lookStick[1])
				look:PivotTo(slotCFrame(shop, i, item) * CFrame.new(0, SALES.lookSize * 0.5 + stick, 0) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(90), 0, 0))
				look.Name = "Look" .. i
				look.Parent = shop.shelf
				s.look, s.lookKey = look, key
			end
			s.disc.Transparency = 1
			s.rim.Transparency = 1
		else
			s.disc.Transparency = 1
			s.rim.Transparency = 1
			s.disc:SetAttribute("Hand", nil)
			if s.look then
				s.look:Destroy()
				s.look, s.lookKey = nil, nil
			end
		end
	end
	shop.label.Text = string.format(slots < SALES.shelfSlots and "쟁반 %d/%d" or "진열대 %d/%d", n, slots) -- 노점은 쟁반 5칸 (D21)
	for i, c in pairs(shop.cards or {}) do
		local item = bySlot[i]
		c.Text = item and ShapeCatalog.itemName(item) or ""
	end
end

---------------------------------------------------------------- 들고 있는 달고나 (속성 Carrying, 2026-11-21)

local function updateCarried(player)
	local char = player.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	local old = char and char:FindFirstChild("CarriedDalgona")
	local id = player:GetAttribute("Carrying") or 0
	if id == 0 or not hand then
		if old then
			old:Destroy()
		end
		return
	end
	local data = Data.get(player)
	local item = nil
	for _, it in ipairs(data and data.stock or {}) do
		if it.id == id then
			item = it
		end
	end
	if old then
		old:Destroy()
	end
	local d = Instance.new("Part")
	d.Name = "CarriedDalgona"
	d.Shape = Enum.PartType.Cylinder
	d.Size = Vector3.new(0.16, 1.2, 1.2)
	d.Color = (item and item.g == "Burnt") and Color3.fromRGB(60, 40, 28) or DALGONA
	d.Material = Enum.Material.SmoothPlastic
	d.CanCollide = false
	d.CanQuery = false
	d.CanTouch = false
	d.Massless = true
	-- 손 앞에 세워 듦 (원판 면이 앞을 봄)
	d.CFrame = hand.CFrame * CFrame.new(0, -0.3, -0.7) * CFrame.Angles(0, math.rad(90), 0)
	if item and item.pk then
		local bag = Instance.new("SelectionBox") -- 포장한 것은 비닐 느낌 테두리
		bag.Adornee = d
		bag.Color3 = Color3.fromRGB(240, 245, 255)
		bag.LineThickness = 0.03
		bag.Transparency = 0.4
		bag.Parent = d
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = hand
	w.Part1 = d
	w.Parent = d
	d.Parent = char
end

local function watchCarry(player)
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		updateCarried(player)
	end)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("RightHand", 5)
		updateCarried(player)
	end)
end

---------------------------------------------------------------- 손님
-- 2026-11-22: 손님 NPC 7종 (손님 NPC 세션, tools/blender/customers.py). ServerStorage.Assets.Customers.Customer_<id> 안 <id>_<부품> 6개를
-- Shared.CustomerRig 값(Root = 두 발 가운데 바닥, 앞 = -Z)으로 놓고, 걷기(다리·팔 흔들기)·먹기(오른팔을 입으로)를 관절 점 기준으로 돌림.
-- 모델이 없으면 예전 부품 손님. 폰 부담: 손님 1명 = MeshPart 6개 (+ 들고 있는 달고나), 가게당 동시 3명

local LIMBS = { "Head", "Body", "ArmL", "ArmR", "LegL", "LegR" }
local rigs = setmetatable({}, { __mode = "k" }) -- [손님 모델] = 리그 (CustomerRig.types[id] 또는 FALLBACK)
local eaters = {} -- [model] = { look, arm, t, bites, scale } (아래 먹기에서 씀, 걷기가 오른팔을 건드리지 않게 먼저 선언)

-- 예전 부품 손님의 관절 (모델이 없을 때)
local FALLBACK = {
	fallback = true,
	height = 3.7,
	parts = {
		ArmL = { center = Vector3.new(-0.84, 1.8, 0), joint = Vector3.new(-0.84, 2.35, 0) },
		ArmR = { center = Vector3.new(0.84, 1.8, 0), joint = Vector3.new(0.84, 2.35, 0) },
		LegL = { center = Vector3.new(-0.28, 0.55, 0), joint = Vector3.new(-0.28, 1.1, 0) },
		LegR = { center = Vector3.new(0.28, 0.55, 0), joint = Vector3.new(0.28, 1.1, 0) },
	},
}

local rigModule = nil -- nil 아직, false 없음
local function customerRig()
	if rigModule == nil then
		local m = ReplicatedStorage.Shared:FindFirstChild("CustomerRig")
		local ok, mod = false, nil
		if m then
			ok, mod = pcall(require, m)
		end
		rigModule = (ok and type(mod) == "table" and mod.types) and mod or false
	end
	return rigModule or nil
end

-- 관절 점에서 rot만큼 돌린 부품 자리 (모두 손님 Root 기준)
local function poseLimb(model, name, rootCF, rot)
	local rig = rigs[model]
	local p = model:FindFirstChild(name)
	local r = rig and rig.parts[name]
	if p and r then
		p.CFrame = rootCF * CFrame.new(r.joint) * rot * CFrame.new(r.center - r.joint)
	end
end

-- 7종 모델 중 하나로 손님 만들기 (want = 손님 종류 id, D37). 없으면 nil
local function buildModelCustomer(cf, want)
	local CR = customerRig()
	local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Customers")
	if not CR or not folder then
		return nil
	end
	local choices = {}
	for _, id in ipairs(CR.order) do
		if CR.types[id] and folder:FindFirstChild("Customer_" .. id) then
			table.insert(choices, id)
		end
	end
	if #choices == 0 then
		return nil
	end
	local id = (want and table.find(choices, want)) and want or choices[math.random(#choices)]
	local rig = CR.types[id]
	local src = folder["Customer_" .. id]
	local m = Instance.new("Model")
	m.Name = "Customer"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- 폰(스트리밍)에서 몸 부품이 따로 빠지지 않게 (2026-11-24)
	local root = part(m, "Root", Vector3.new(1, 1, 1), cf, Color3.new(), nil, { Transparency = 1 })
	m.PrimaryPart = root
	for _, name in ipairs(LIMBS) do
		local srcPart = src:FindFirstChild(id .. "_" .. name)
		local r = rig.parts[name]
		if srcPart and r then
			local pp = srcPart:Clone()
			pp.Name = name
			pp.Anchored = true
			pp.CanCollide = false
			pp.CanQuery = false
			pp.CanTouch = false
			pp.CFrame = cf * CFrame.new(r.center)
			pp.Parent = m
		end
	end
	if not m:FindFirstChild("Head") then
		m:Destroy()
		return nil
	end
	m:SetAttribute("CustomerType", id)
	rigs[m] = rig
	return m
end

local function buildCustomer(cf, want)
	local m = buildModelCustomer(cf, want)
	if m then
		local head = m.Head
		local bb = Instance.new("BillboardGui")
		bb.Name = "Bubble"
		bb.Size = UDim2.fromOffset(150, 40)
		bb.StudsOffset = Vector3.new(0, head.Size.Y / 2 + 0.95, 0)
		bb.MaxDistance = 80
		bb.Enabled = false
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundColor3 = Color3.fromRGB(255, 252, 245)
		t.TextColor3 = Color3.fromRGB(92, 58, 36)
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.4, 0)
		c.Parent = t
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 4)
		pad.Parent = t
		t.Parent = bb
		bb.Parent = head
		return m
	end
	-- 예전 부품 손님
	m = Instance.new("Model")
	m.Name = "Customer"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- 폰(스트리밍)에서 몸 부품이 따로 빠지지 않게 (2026-11-24)
	local shirt = SHIRTS[math.random(#SHIRTS)]
	local skin = SKINS[math.random(#SKINS)]
	local root = part(m, "Root", Vector3.new(1, 1, 1), cf, Color3.new(), nil, { Transparency = 1 })
	m.PrimaryPart = root
	local function at(name, size, offset, color, shape)
		return part(m, name, size, cf * offset, color, Enum.Material.SmoothPlastic, shape and { Shape = shape } or nil)
	end
	at("LegL", Vector3.new(0.45, 1.1, 0.5), CFrame.new(-0.28, 0.55, 0), Color3.fromRGB(70, 80, 110))
	at("LegR", Vector3.new(0.45, 1.1, 0.5), CFrame.new(0.28, 0.55, 0), Color3.fromRGB(70, 80, 110))
	at("Body", Vector3.new(1.3, 1.3, 0.8), CFrame.new(0, 1.75, 0), shirt)
	at("ArmL", Vector3.new(0.36, 1.1, 0.4), CFrame.new(-0.84, 1.8, 0), shirt)
	at("ArmR", Vector3.new(0.36, 1.1, 0.4), CFrame.new(0.84, 1.8, 0), shirt)
	local head = at("Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 3.05, 0), skin, Enum.PartType.Ball)
	at("Hair", Vector3.new(1.36, 0.6, 1.36), CFrame.new(0, 3.5, 0.08), Color3.fromRGB(60, 40, 30), Enum.PartType.Ball)
	at("EyeL", Vector3.new(0.14, 0.2, 0.06), CFrame.new(-0.24, 3.12, -0.63), Color3.fromRGB(30, 25, 25))
	at("EyeR", Vector3.new(0.14, 0.2, 0.06), CFrame.new(0.24, 3.12, -0.63), Color3.fromRGB(30, 25, 25))
	-- 말풍선
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bubble"
	bb.Size = UDim2.fromOffset(150, 40)
	bb.StudsOffset = Vector3.new(0, 1.6, 0)
	bb.MaxDistance = 80
	bb.Enabled = false
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(255, 252, 245)
	t.TextColor3 = Color3.fromRGB(92, 58, 36)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.4, 0)
	c.Parent = t
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = t
	t.Parent = bb
	bb.Parent = head
	rigs[m] = FALLBACK
	return m
end

local function say(model, text, seconds)
	local head = model:FindFirstChild("Head")
	local bb = head and head:FindFirstChild("Bubble")
	if not bb then
		return
	end
	bb.TextLabel.Text = text
	bb.Enabled = true
	task.delay(seconds or 2, function()
		if bb.Parent and bb.TextLabel.Text == text then
			bb.Enabled = false
		end
	end)
end

-- 웨이포인트를 따라 걷기 (Heartbeat에서 옮김). 도착하면 onArrive()
local function walk(model, points, onArrive)
	-- 이미 걷는 중이면 그 길은 버림 (줄이 당겨질 때 새 자리로, D56)
	for i = #walkers, 1, -1 do
		if walkers[i].model == model then
			table.remove(walkers, i)
		end
	end
	table.insert(walkers, { model = model, points = points, seg = 1, dist = 0, onArrive = onArrive, t = 0 })
end

local function stepWalkers(dt)
	for i = #walkers, 1, -1 do
		local w = walkers[i]
		if not w.model.Parent then
			table.remove(walkers, i)
			continue
		end
		local a, b = w.points[w.seg], w.points[w.seg + 1]
		local len = (b - a).Magnitude
		w.dist += SALES.walkSpeed * dt
		w.t += dt
		while w.dist >= len and w.seg < #w.points - 1 do
			w.dist -= len
			w.seg += 1
			a, b = w.points[w.seg], w.points[w.seg + 1]
			len = (b - a).Magnitude
		end
		local done = w.dist >= len
		local alpha = len > 0 and math.min(w.dist / len, 1) or 1
		local pos = a:Lerp(b, alpha)
		local bob = done and 0 or math.abs(math.sin(w.t * 9)) * 0.18
		local dir = (b - a)
		local look = dir.Magnitude > 0.01 and CFrame.lookAt(pos, pos + Vector3.new(dir.X, 0, dir.Z)) or CFrame.new(pos)
		w.model:PivotTo(look + Vector3.new(0, bob, 0))
		-- 다리·팔 흔들기 (관절 점 기준, 서면 제자리). 먹는 중이면 오른팔은 먹기가 움직임
		if rigs[w.model] then
			local swing = done and 0 or math.sin(w.t * 9) * SALES.walkSwing
			local rootCF = w.model.PrimaryPart.CFrame
			poseLimb(w.model, "LegL", rootCF, CFrame.Angles(swing, 0, 0))
			poseLimb(w.model, "LegR", rootCF, CFrame.Angles(-swing, 0, 0))
			poseLimb(w.model, "ArmL", rootCF, CFrame.Angles(-swing * 0.8, 0, 0))
			if not eaters[w.model] then
				poseLimb(w.model, "ArmR", rootCF, CFrame.Angles(swing * 0.8, 0, 0))
			end
		end
		if done then
			table.remove(walkers, i)
			if w.onArrive then
				task.spawn(w.onArrive)
			end
		end
	end
end

---------------------------------------------------------------- 산 달고나 먹으며 가기
-- 손님 모델에 달고나 모양을 넣고, 매 프레임(걷기 다음) 오른팔·달고나를 몸 기준으로 다시 놓음.
-- 한 입 주기: 들고 있다 → 입으로 올림 → 입 앞에서 한 입(조금 작아짐) → 내림. SALES.eat 값

-- eaters는 위(손님)에서 선언

local function startEating(model, item)
	local arm = model:FindFirstChild("ArmR")
	if not arm or not model.PrimaryPart then
		return
	end
	local look = buildLook(item, SALES.eat.size)
	look.Parent = model
	eaters[model] = { look = look, arm = arm, t = 0, bites = 0, scale = 1 }
end

local function stepEaters(dt)
	local E = SALES.eat
	for model, e in pairs(eaters) do
		if not model.Parent or not e.look.Parent then
			eaters[model] = nil
			continue
		end
		local before = e.t % E.cycle
		e.t += dt
		local ph = e.t % E.cycle
		-- 0 = 손에 듦, 1 = 입 앞. 올림 → 머묾 → 내림 → 쉼
		local up = E.cycle * 0.25
		local stay = E.cycle * 0.2
		local down = E.cycle * 0.2
		local k
		if ph < up then
			k = ph / up
		elseif ph < up + stay then
			k = 1
		elseif ph < up + stay + down then
			k = 1 - (ph - up - stay) / down
		else
			k = 0
		end
		k = k * k * (3 - 2 * k)
		-- 입 앞에 머무는 가운데쯤 한 입
		local biteAt = up + stay * 0.5
		if before < biteAt and ph >= biteAt then
			e.bites += 1
			if e.bites >= E.bites then
				e.look:Destroy()
				eaters[model] = nil
				poseLimb(model, "ArmR", model.PrimaryPart.CFrame, CFrame.new())
				say(model, E.lastLine, 1.2)
				continue
			end
			e.scale *= E.biteScale
			pcall(function()
				e.look:ScaleTo(e.scale)
			end)
			say(model, E.lines[math.random(#E.lines)], 0.8)
		end
		local root = model.PrimaryPart.CFrame
		local rig = rigs[model] or FALLBACK
		-- 원판 가운데 (손님 Root 기준): 예전 부품 손님은 설정값, 모델 손님은 손(hand) 위 / 입(mouth) 앞
		local hold, mouth = E.hold, E.mouth
		if not rig.fallback then
			hold = rig.hand + E.modelHold + Vector3.new(0, E.size * 0.75, 0)
			mouth = rig.mouth + E.modelMouth
		end
		local p = hold:Lerp(mouth, k)
		-- 원판을 세워 넓은 면이 손님 얼굴 쪽, 막대는 아래 (로컬 +Z → 아래)
		local discCF = root * CFrame.new(p) * CFrame.Angles(math.rad(90), 0, 0)
		e.look:PivotTo(discCF)
		-- 오른팔: 어깨 관절에서 막대 쥔 곳(원판 아래)을 향해 돌림
		local arm = rig.parts.ArmR
		local grip = p - Vector3.new(0, E.size * 0.75, 0)
		local dir = grip - arm.joint
		local down = (arm.center - arm.joint).Unit
		if dir.Magnitude > 0.05 then
			dir = dir.Unit
			local axis = down:Cross(dir)
			local s2 = axis.Magnitude
			local rot = s2 > 1e-4 and CFrame.fromAxisAngle(axis / s2, math.atan2(s2, down:Dot(dir))) or CFrame.new()
			poseLimb(model, "ArmR", root, rot)
		end
	end
end

local function demand(player)
	local data = Data.get(player)
	return G.salesDemandFor(data) -- 노점·문 닫힘이면 국자 1개 수요 (D21)
end

-- 방문 간격: 수요 표(5-1) 간격 × (이 레벨 손님 평균 개수 ÷ 수요 표 평균 개수) → 분당 사는 개수 합계는 수요 표 그대로 (D37)
local function interval(player)
	local base, lo, hi = demand(player)
	local data = Data.get(player)
	local mean = G.customerMeanBuy(data and data.level or 1)
	local scale = mean / math.max((lo + hi) / 2, 0.01)
	return base * scale * (1 + (math.random() * 2 - 1) * SALES.jitter)
end

local function local2world(plot, x, z)
	return (plot.cframe * CFrame.new(x, G.Plots.size.Y, z)).Position
end

---------------------------------------------------------------- 계산 줄 (D56, GDD 16장)
-- 손님 c = { model, reserved(찜한 개수), ctype, owner, left(남은 인내 초), frontAt(맨 앞이 된 서버 시각), busy, leave(fn) }
-- shop.queue = { c1(맨 앞), c2, ... }. 화면 쪽 약속 (UI 세션):
--   손님 Model 속성 Queue(1 = 맨 앞, 줄 아니면 nil) · Patience(0~1, 0.5초마다) · FrontAt(맨 앞이 된 서버 시각)
--   부지 모델 Plot<i> 속성 QueueCount(줄 선 손님 수)
--   Remotes.Checkout:InvokeServer() → { ok, reason, coins, tip(bool) } (내 가게 맨 앞 손님 하나)
local CHK = G.Checkout

local function queueMax(shop)
	return shop.stall and CHK.stallQueueMax or CHK.queueMax
end

-- 줄 k번째 자리 (세계 좌표)와 바라볼 점: 카운터 앞 자리(손님 주문 자리)에서 가게 문 쪽으로 gap씩
local function queuePoint(index, k)
	local shop, plot = shops[index], Plots.plotAt(index)
	local stand = (shop.stall and shop.stallStandLocal) or shop.standLocal or Vector3.new(SALES.shelf.pos.X, 0, SALES.standZ)
	-- 뒤 = 카운터 앞 자리가 보는 쪽(CustomerSpot LookVector → shelfLocal)의 반대. 노점은 쟁반(+Z) 반대
	local facing = (not shop.stall and shop.shelfLocal) and (shop.shelfLocal - stand) or Vector3.new(0, 0, 1)
	facing = Vector3.new(facing.X, 0, facing.Z)
	local back = facing.Magnitude > 1e-3 and -facing.Unit or Vector3.new(0, 0, -1)
	local p = stand + back * CHK.gap * (k - 1)
	local face = stand - back * 4
	return local2world(plot, p.X, p.Z), local2world(plot, face.X, face.Z)
end

local function syncQueue(index)
	local shop, plot = shops[index], Plots.plotAt(index)
	local now = workspace:GetServerTimeNow()
	for k, c in ipairs(shop.queue) do
		if k == 1 and not c.frontAt then
			c.frontAt = now
		end
		local pos, face = queuePoint(index, k)
		if c.at ~= k then
			c.at = k
			local m = c.model
			if m.Parent then
				walk(m, { m:GetPivot().Position, pos }, function()
					if m.Parent then
						m:PivotTo(CFrame.lookAt(pos, Vector3.new(face.X, pos.Y, face.Z)))
					end
				end)
			end
		end
		c.model:SetAttribute("Queue", k)
		c.model:SetAttribute("FrontAt", c.frontAt)
	end
	if plot and plot.model then
		plot.model:SetAttribute("QueueCount", #shop.queue)
	end
end

local function dropFromQueue(index, c)
	local shop = shops[index]
	local i = table.find(shop.queue, c)
	if i then
		table.remove(shop.queue, i)
	end
	if c.model.Parent then
		c.model:SetAttribute("Queue", nil)
		c.model:SetAttribute("Patience", nil)
		c.model:SetAttribute("FrontAt", nil)
	end
	syncQueue(index)
end

-- 기다리다 지침: 찜한 것을 진열대에 돌려놓고(예약만 풀면 됨) 떠남, 벌 없음
local function giveUp(index, c)
	local shop = shops[index]
	shop.reserved = math.max(0, shop.reserved - c.reserved)
	c.reserved = 0
	dropFromQueue(index, c)
	say(c.model, "너무 오래 걸려…", 2)
	task.delay(0.8, c.leave)
end

-- 맨 앞 손님 계산. who = "player" | "cashier"
local function checkout(index, who)
	local shop = shops[index]
	local c = shop and shop.queue[1]
	if not c or c.busy then
		return { ok = false, reason = "계산할 손님이 없어요" }
	end
	local owner = shop.owner
	if not (owner and owner.Parent and c.owner == owner) then
		return { ok = false, reason = "계산할 손님이 없어요" }
	end
	c.busy = true
	local n = c.reserved
	shop.reserved = math.max(0, shop.reserved - n)
	c.reserved = 0
	local sold, coins, items = Economy.sell(owner, n, c.ctype)
	local tip = false
	if sold > 0 and who == "player" then
		-- 빨리 계산 팁: 계산 알바 팁(Economy.sell 안 +5%)과 겹치지 않음 (둘 중 큰 것 = 같은 5%)
		local od = Data.get(owner)
		local hasCashier = od and G.helperAt(od, "cashier") and G.shopOpen(od)
		if not hasCashier and c.frontAt and workspace:GetServerTimeNow() - c.frontAt <= CHK.fastTip.within then
			local extra = math.max(1, math.floor(coins * CHK.fastTip.mult + 0.5))
			Data.update(owner, function(d)
				d.coins += extra
				d.stats.coinsEarned = (d.stats.coinsEarned or 0) + extra
			end)
			coins += extra
			tip = true
		end
	end
	dropFromQueue(index, c)
	local model = c.model
	task.spawn(function()
		if sold > 0 then
			-- 알림창 대신 손님 위에 "+n코인" 글씨 (2026-11-24 사용자, 클라이언트 SaleFloatClient)
			if saleFloat and model.Parent then
				local cf, size = model:GetBoundingBox()
				saleFloat:FireClient(owner, cf.Position + Vector3.new(0, size.Y / 2 + 0.6, 0), coins)
			end
			say(model, tip and "빨리 해 줘서 고마워요! ♥" or "고마워요!", 1.5)
			Collection = Collection or require(script.Parent:WaitForChild("CollectionService"))
			task.spawn(Collection.onCustomerSold, owner, c.ctype.id, sold) -- 손님 도감 하트 (D38)
			startEating(model, items and items[1] or nil)
			print(string.format("[Sales] %s Plot%d checkout(%s) %d (+%d%s)", owner.Name, index, who, sold, coins, tip and " tip" or ""))
		else
			say(model, c.ctype.kind == "vip" and "마음에 드는 게 없네..." or "다 팔렸네...", 2)
		end
		task.wait(1) -- 계산 연출 (UI 1초)
		c.leave()
	end)
	return { ok = sold > 0, reason = sold == 0 and "진열대에 남은 게 없어요" or nil, coins = coins, tip = tip }
end

-- 0.5초마다: 인내 줄이기(주인이 만드는 중이면 절반), 계산 알바 자동 계산
local function stepQueue(index, dt)
	local shop = shops[index]
	if #shop.queue == 0 then
		return
	end
	local owner = shop.owner
	local rate = (owner and owner:GetAttribute("Making")) and CHK.makingSlow or 1
	for _, c in ipairs(table.clone(shop.queue)) do
		if not c.busy then
			c.left -= dt * rate
			c.model:SetAttribute("Patience", math.clamp(c.left / CHK.patience, 0, 1))
			if c.left <= 0 then
				giveUp(index, c)
			end
		end
	end
	local front = shop.queue[1]
	local od = owner and Data.get(owner)
	if front and not front.busy and od and G.helperAt(od, "cashier") and G.shopOpen(od) and front.frontAt and workspace:GetServerTimeNow() - front.frontAt >= CHK.cashierSeconds then
		checkout(index, "cashier")
	end
end

local function spawnCustomer(index)
	local shop = shops[index]
	local plot = Plots.plotAt(index)
	local owner = shop.owner
	local available = Economy.shelfCount(owner) - shop.reserved
	if available <= 0 then
		return
	end
	-- 손님 종류 (D37): 레벨 구간 비율로 뽑고, 종류마다 사려는 개수
	local od = Data.get(owner)
	local ctype = G.rollCustomer(od and od.level or 1)
	Collection = Collection or require(script.Parent:WaitForChild("CollectionService"))
	task.spawn(Collection.onCustomerMet, owner, ctype.id) -- 손님 도감: 처음 만나면 30코인 (D38)
	local kind = G.Customers.kinds[ctype.kind]
	local want = math.random(kind.min, kind.max)
	local n = math.min(want, available)
	shop.reserved += n
	local stand = (shop.stall and shop.stallStandLocal) or shop.standLocal or Vector3.new(SALES.shelf.pos.X, 0, SALES.standZ)
	local shelfL = shop.shelfLocal or Vector3.new(SALES.shelf.pos.X, 0, SALES.shelf.pos.Z)
	-- 고르는 자리: 카운터 앞 자리(= 계산 줄 맨 앞, D56)에서 옆으로 비켜서
	local sideSign = math.random() < 0.5 and -1 or 1
	local standL = stand + (shop.standSide or Vector3.xAxis) * sideSign * (2.6 + math.random() * 1.6)
	local sx = stand.X
	local side = math.random() < 0.5 and -1 or 1
	local startP = local2world(plot, side * SALES.streetHalf, SALES.streetZ)
	local doorP = local2world(plot, sx, SALES.streetZ)
	local standP = local2world(plot, standL.X, standL.Z)
	local exitP = local2world(plot, -side * SALES.streetHalf, SALES.streetZ)
	local model = buildCustomer(CFrame.new(startP), ctype.id)
	model.Parent = shop.folder
	local c = { model = model, reserved = n, ctype = ctype, owner = owner }
	shop.customers[c] = true

	local function leave()
		if not model.Parent then
			shop.customers[c] = nil
			return
		end
		walk(model, { model:GetPivot().Position, doorP, exitP }, function()
			model:Destroy()
			shop.customers[c] = nil
		end)
	end
	c.leave = leave
	walk(model, { startP, doorP, standP }, function()
		-- 진열대를 보며 고름
		local shelfP = local2world(plot, shelfL.X, shelfL.Z)
		model:PivotTo(CFrame.lookAt(standP, Vector3.new(shelfP.X, standP.Y, shelfP.Z)))
		-- 계산 알바가 있으면 고르는 시간 절반 (D43)
		local od = owner and Data.get(owner)
		local browse = SALES.browseSeconds * ((od and G.helperAt(od, "cashier")) and G.Cashier.browseMult or 1)
		say(model, LINES[math.random(#LINES)], browse + 0.4)
		task.wait(browse)
		if not model.Parent then
			return
		end
		-- D56: 고른 것(찜 = 예약 그대로)을 들고 카운터 앞 줄로. 줄이 꽉 차면 진열대 앞에서 기다림
		while model.Parent and shop.owner == owner and #shop.queue >= queueMax(shop) do
			task.wait(0.5)
		end
		if not model.Parent then
			return
		end
		if shop.owner ~= owner or not owner.Parent then
			shop.reserved = math.max(0, shop.reserved - c.reserved)
			c.reserved = 0
			leave()
			return
		end
		say(model, string.format("%d개 살게요!", c.reserved), 1.5)
		c.left = CHK.patience
		table.insert(shop.queue, c)
		model:SetAttribute("Patience", 1)
		syncQueue(index)
	end)
end

local function clearShop(index)
	local shop = shops[index]
	if not shop then
		return
	end
	for c in pairs(shop.customers) do
		c.model:Destroy()
	end
	shop.customers = {}
	shop.queue = {}
	shop.reserved = 0
	shop.owner = nil
	local plot = Plots.plotAt(index)
	if plot and plot.model then
		plot.model:SetAttribute("QueueCount", 0)
	end
	refreshShelf(index)
end

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

-- 이 플레이어 가게에 손님이 바로 오게 (첫 60초 안내: 첫 달고나를 진열하면)
function SalesService.hurry(player)
	for _, shop in pairs(shops) do
		if shop.owner == player then
			shop.nextVisit = 0
		end
	end
end

-- 가구를 눌러 진열 (2026-11-24 사용자: 진열대 버튼 없애기). area = "case" | "peg" | "table1" | "table2", hit = 누른 세계 좌표
local function placeByTouch(player, area, hit)
	if type(area) ~= "string" or not AREA_SLOTS[area] then
		return { ok = false, reason = "잘못된 요청" }
	end
	local _, index = Plots.get(player)
	local shop = index and shops[index]
	local data = Data.get(player)
	if not shop or shop.owner ~= player or not data then
		return { ok = false, reason = "내 가게 진열대만 쓸 수 있어요" }
	end
	local openSet = {}
	for _, k in ipairs(G.openSlots(data)) do
		openSet[k] = true
	end
	local used = {}
	for _, it in ipairs(data.stock) do
		if it.sl then
			used[it.sl] = true
		end
	end
	local list = AREA_SLOTS[area]
	local stall = not G.shopOpen(data)
	if stall then
		-- 노점: 가게 앞 작은 탁자만 (쟁반 5칸)
		if area ~= "table1" then
			return { ok = false, reason = "가게를 열어야 쓸 수 있는 자리예요" }
		end
		list = G.openSlots(data)
	end
	local function freeIn(l)
		local out = {}
		for _, i in ipairs(l) do
			if openSet[i] and not used[i] and not Economy.isReserved(data, i) then -- 알바가 들고 가는 칸은 빼고
				table.insert(out, i)
			end
		end
		return out
	end
	local free = freeIn(list)
	if #free == 0 and not stall and TABLE_SLOT[area] then
		-- 누른 탁자가 차 있으면 다른 작은 탁자
		for _, k in ipairs({ "table1", "table2", "table3" }) do
			if k ~= area and #free == 0 then
				free = freeIn(AREA_SLOTS[k])
			end
		end
	end
	if #free == 0 then
		local anyOpen = false
		for _, i in ipairs(list) do
			anyOpen = anyOpen or openSet[i] == true
		end
		return { ok = false, reason = anyOpen and "빈 자리가 없어요" or "진열장을 업그레이드하면 쓸 수 있는 자리예요" }
	end
	-- 누른 곳에 가장 가까운 빈 칸 (격자, 2026-11-24)
	local slot = free[1]
	local extra = nil
	local hitV = typeof(hit) == "Vector3" and hit or nil
	if hitV then
		local best = math.huge
		for _, i in ipairs(free) do
			local ok, cf = pcall(slotCFrame, shop, i)
			if ok and cf then
				local dd = (cf.Position - hitV).Magnitude
				if dd < best then
					best, slot = dd, i
				end
			end
		end
	end
	local ok, msg = Economy.place(player, slot, extra)
	if not ok then
		Economy.notify(player, msg)
	end
	return { ok = ok, reason = not ok and msg or nil, slot = ok and slot or nil }
end

-- 진열 칸 i의 세계 좌표 (알바가 들고 걸어갈 곳, 2026-11-24). 없으면 nil
function SalesService.slotPosition(player, i)
	local _, index = Plots.get(player)
	local shop = index and shops[index]
	if not shop then
		return nil
	end
	local ok, cf = pcall(slotCFrame, shop, i)
	return ok and cf and cf.Position or nil
end

-- 주문 손님(D55, OrderService)용: 손님 모델 하나 (7종 중 id, 없으면 nil)
function SalesService.buildGuest(cf, id)
	local ok, m = pcall(buildModelCustomer, cf, id)
	return ok and m or nil
end

-- 주문 대기 자리 (D55): 틀 부품 OrderSeat(3D 세션 의자)가 있으면 그 자리, 없으면 손님 주문 자리 옆 3.5칸. 카운터 쪽을 봄
function SalesService.orderSeat(index)
	local shop = shops[index]
	local plot = Plots.plotAt(index)
	if not (shop and plot) then
		return nil
	end
	local seat = plot.model:FindFirstChild("OrderSeat", true)
	if seat and seat:IsA("BasePart") then
		return CFrame.new(seat.Position + Vector3.new(0, seat.Size.Y / 2, 0)) * (seat.CFrame - seat.CFrame.Position)
	end
	local cf = plot.cframe
	local stand = shop.standLocal or Vector3.new(0, 0, -25)
	local side = shop.standSide and shop.standSide.Magnitude > 1e-3 and shop.standSide.Unit or Vector3.xAxis
	local pos = stand + side * 3.5
	local look = shop.shelfLocal or (stand + Vector3.new(0, 0, 4))
	local wp = cf * Vector3.new(pos.X, 0.4, pos.Z)
	local wl = cf * Vector3.new(look.X, 0.4, look.Z)
	return CFrame.lookAt(wp, wl)
end

function SalesService.init(dataService, economyService, plotService)
	Data, Economy, Plots = dataService, economyService, plotService
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	saleFloat = remotes:FindFirstChild("SaleFloat")
	if not saleFloat then
		saleFloat = Instance.new("RemoteEvent")
		saleFloat.Name = "SaleFloat"
		saleFloat.Parent = remotes
	end
	local shelfPlace = remotes:FindFirstChild("ShelfPlace")
	if not shelfPlace then
		shelfPlace = Instance.new("RemoteFunction")
		shelfPlace.Name = "ShelfPlace"
		shelfPlace.Parent = remotes
	end
	shelfPlace.OnServerInvoke = placeByTouch
	-- 계산 (D56): 내 가게 맨 앞 손님. 남의 가게는 못 함
	local checkoutFn = remotes:FindFirstChild("Checkout")
	if not checkoutFn then
		checkoutFn = Instance.new("RemoteFunction")
		checkoutFn.Name = "Checkout"
		checkoutFn.Parent = remotes
	end
	local lastCheckout = {}
	checkoutFn.OnServerInvoke = function(player)
		if lastCheckout[player] and os.clock() - lastCheckout[player] < 0.3 then
			return { ok = false, reason = "천천히!" }
		end
		lastCheckout[player] = os.clock()
		local _, index = Plots.get(player)
		local shop = index and shops[index]
		if not (shop and shop.owner == player) then
			return { ok = false, reason = "내 가게에서만 계산할 수 있어요" }
		end
		-- 맨 앞 손님 가까이에서만 (2026-11-26, G.Checkout.reach + 지연 여유 3)
		local front = shop.queue[1]
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if front and front.model.Parent and root then
			local p = front.model:GetPivot().Position
			local flat = Vector3.new(p.X - root.Position.X, 0, p.Z - root.Position.Z)
			if flat.Magnitude > (CHK.reach or 10) + 3 then
				return { ok = false, reason = "카운터 앞 손님 가까이에서 계산해요" }
			end
		end
		return checkout(index, "player")
	end
	Players.PlayerRemoving:Connect(function(p)
		lastCheckout[p] = nil
	end)
	for i = 1, G.Plots.count do
		local plot = Plots.plotAt(i)
		local shop = { slots = {}, customers = {}, queue = {}, reserved = 0, nextVisit = 0, owner = nil }
		shops[i] = shop
		buildShelf(shop, plot)
		local folder = Instance.new("Folder")
		folder.Name = "Customers"
		folder.Parent = plot.model
		shop.folder = folder
		refreshShelf(i) -- 빈 가게 모습 (진열 가구 숨김)
		pcall(function()
			require(script.Parent:WaitForChild("ShopLights")).build(plot) -- 약한 가게 조명 (2026-11-24, 세기 G.ShopLight.strength)
		end)
	end

	Players.PlayerAdded:Connect(watchCarry)
	for _, p in ipairs(Players:GetPlayers()) do
		watchCarry(p)
	end

	-- 데이터가 바뀌면 그 플레이어 가게의 진열대를 다시 그림
	Data.Changed:Connect(function(player)
		local _, index = Plots.get(player)
		if index then
			shops[index].owner = player
			refreshShelf(index)
		end
		if (player:GetAttribute("Carrying") or 0) ~= 0 then
			updateCarried(player) -- 포장하면 들고 있는 모습도 바뀜
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for i, shop in pairs(shops) do
			if shop.owner == player then
				clearShop(i)
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		stepWalkers(dt)
		stepEaters(dt) -- 걷기로 몸을 옮긴 다음 팔·달고나를 다시 놓음
	end)

	-- 손님 보내기
	task.spawn(function()
		local lastStep = os.clock()
		while true do
			task.wait(0.5)
			local now = os.clock()
			local dt = now - lastStep
			lastStep = now
			for i, shop in pairs(shops) do
				local okQ, errQ = pcall(stepQueue, i, dt) -- 계산 줄 (D56)
				if not okQ then
					warn("[Sales] queue", errQ)
				end
				local plot = Plots.plotAt(i)
				local owner = plot.owner
				if owner ~= shop.owner then
					clearShop(i)
					shop.owner = owner
					shop.nextVisit = now + 2
					refreshShelf(i) -- 주인이 나가면 빈 가게 모습으로
				end
				if owner and owner.Parent and Data.get(owner) and now >= shop.nextVisit then
					shop.nextVisit = now + interval(owner)
					-- 줄 선 손님은 빼고 셈 (D56: 계산을 기다리는 동안에도 수요 표대로 손님이 옴, 줄이 차면 진열대 앞에서 기다림)
					if count(shop.customers) - #shop.queue < CHK.browsingMax then
						spawnCustomer(i)
					end
				end
			end
		end
	end)
end

return SalesService

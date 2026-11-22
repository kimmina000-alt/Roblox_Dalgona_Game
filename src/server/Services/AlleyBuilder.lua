-- 레트로 골목 맵 (21번, DEVELOPMENT_PLAN 6장 Phase 6, 2026-11-23)
-- 맵은 스크립트로 만든다 (DEVELOPMENT_PLAN §8: Studio에서 손으로 끌어 옮기지 않음). 서버가 시작할 때 Workspace.Alley에 만든다.
--
-- 배치 (사용자 2026-11-23: 가게 6칸은 한 줄 그대로, 길 건너편은 꾸미기 가게 줄, 분위기는 따뜻한 오후 낮)
--   가게 6칸: z = GrowthConfig.Plots.rowZ(-72) 한 줄, x = (i - 3.5) * spacing. 앞(간판)이 +Z
--   손님 길: z ≈ rowZ - Sales.streetZ(-46). 길 바닥 z -54 ~ -28
--   길 건너 인도 z -28 ~ -22, 꾸미기 가게 줄 z -22 ~ -6 (앞이 -Z, 가게 쪽을 봄). x = 0은 스폰으로 가는 샛길
--   골목 양 끝 x = ±HALF: 담벼락 + 입구
-- 부지·작업대·진열대·공장 자리는 저장·부지 세션(PlotService·PlotLayout) 것이라 건드리지 않는다.
--
-- 소품: ServerStorage.Assets.Alley.<이름> 모델(Blender, 손님 NPC 세션)이 있으면 그것을 복제하고, 없으면 Part로 임시 모양을 만든다.
-- 폰 예산(docs/PERFORMANCE_BUDGET.md): 이 골목 전체 약 400~500 부품, 삼각형 1만 안팎 (Part 하나 = 삼각형 12)

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GrowthConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))

local A = {}

local P = GrowthConfig.Plots
local HALF = ((P.count - 1) / 2) * P.spacing + 80 -- 골목 끝 (마지막 가게에서 80칸 더)
local ROAD_Z0, ROAD_Z1 = -54, -28 -- 길 (가게 앞선 ~ 건너 인도)
local WALK_Z1 = -22 -- 건너 인도 끝 = 꾸미기 가게 앞면
local SHOP_DEPTH = 14
local SIDE_GAP = 18 -- x = 0 샛길 폭 (스폰 쪽)

-- 색 (기존 가게 벽돌·분홍 차양·파스텔 공장과 맞춤: 낮은 채도의 따뜻한 파스텔)
local C = {
	road = Color3.fromRGB(150, 144, 138),
	roadPatch = Color3.fromRGB(128, 122, 118),
	curb = Color3.fromRGB(196, 190, 180),
	walk = Color3.fromRGB(214, 200, 182),
	brick = Color3.fromRGB(196, 132, 110),
	brickDark = Color3.fromRGB(160, 104, 88),
	cream = Color3.fromRGB(244, 232, 210),
	mint = Color3.fromRGB(170, 214, 196),
	pink = Color3.fromRGB(240, 170, 170),
	butter = Color3.fromRGB(246, 214, 140),
	sky = Color3.fromRGB(160, 196, 226),
	lilac = Color3.fromRGB(196, 176, 220),
	wood = Color3.fromRGB(150, 104, 70),
	woodLight = Color3.fromRGB(196, 150, 104),
	concrete = Color3.fromRGB(200, 196, 188),
	metal = Color3.fromRGB(120, 124, 130),
	shutter = Color3.fromRGB(176, 182, 188),
	glass = Color3.fromRGB(190, 220, 230),
	white = Color3.fromRGB(250, 248, 242),
	ink = Color3.fromRGB(70, 52, 44),
	coal = Color3.fromRGB(58, 56, 56),
	leaf = Color3.fromRGB(110, 160, 90),
}

local folder -- Workspace.Alley

local function part(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function cyl(parent, name, length, diameter, cf, color, material, props)
	-- 원기둥: Part 원기둥은 X축이 길이 → 세운 원기둥은 Z축으로 90° 돌림
	local p = part(parent, name, Vector3.new(length, diameter, diameter), cf, color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function upright(pos)
	return CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
end

local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or folder
	return m
end

-- 간판 글씨 (SurfaceGui, 앞면). 실제 상표는 쓰지 않는다
local function signText(p, text, color, face)
	local g = Instance.new("SurfaceGui")
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0.6
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = color or C.ink
	t.Parent = g
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.Parent = t
	return g
end

-- Blender 모델이 있으면 그것을, 없으면 fallback(m, cf)으로 Part 모양을 만든다. cf = 바닥 가운데, 앞 = -Z
local assets = nil
local function prop(name, cf, fallback)
	local src = assets and assets:FindFirstChild(name)
	if src then
		local c = src:Clone()
		c:PivotTo(cf)
		c.Parent = folder
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanTouch = false
			end
		end
		return c
	end
	local m = model(name)
	fallback(m, cf)
	return m
end

---------------------------------------------------------------- 바닥·길

local function ground()
	local g = model("Ground")
	local len = HALF * 2 + 20
	local zc = (ROAD_Z0 + ROAD_Z1) / 2
	-- 길: 낡은 콘크리트 (가게 부지 바닥보다 낮게)
	part(g, "Road", Vector3.new(len, 0.2, ROAD_Z1 - ROAD_Z0), CFrame.new(0, 0.1, zc), C.road, Enum.Material.Concrete)
	-- 가게 쪽 길 가장자리 턱 (부지 바닥 앞선)
	part(g, "CurbShop", Vector3.new(len, 0.35, 0.8), CFrame.new(0, 0.18, ROAD_Z0 - 0.4), C.curb, Enum.Material.Concrete)
	-- 건너 인도
	part(g, "Sidewalk", Vector3.new(len, 0.5, WALK_Z1 - ROAD_Z1), CFrame.new(0, 0.25, (ROAD_Z1 + WALK_Z1) / 2), C.walk, Enum.Material.Pavement)
	part(g, "CurbWalk", Vector3.new(len, 0.55, 0.6), CFrame.new(0, 0.27, ROAD_Z1 + 0.3), C.curb, Enum.Material.Concrete)
	-- 가게 줄 뒤 땅 (꾸미기 가게 뒤 ~ 스폰)
	part(g, "BackLot", Vector3.new(len, 0.2, 40), CFrame.new(0, 0.1, WALK_Z1 + 20), C.walk, Enum.Material.Pavement)
	-- 바탕 Baseplate(회색 격자)가 가게 사이·뒤로 보임 → 따뜻한 흙빛 콘크리트로 (격자 무늬는 숨김)
	local base = workspace:FindFirstChild("Baseplate")
	if base and base:IsA("BasePart") then
		base.Material = Enum.Material.Concrete
		base.Color = Color3.fromRGB(176, 164, 150)
		for _, t in ipairs(base:GetChildren()) do
			if t:IsA("Texture") or t:IsA("Decal") then
				t.Transparency = 1
			end
		end
	end
	-- 기운 땜질 자국·맨홀 (길이 너무 밋밋하지 않게)
	local rng = Random.new(1123)
	for i = 1, 14 do
		local x = -HALF + (i - 0.5) * (HALF * 2 / 14) + rng:NextNumber(-10, 10)
		local z = rng:NextNumber(ROAD_Z0 + 3, ROAD_Z1 - 3)
		part(g, "Patch", Vector3.new(rng:NextNumber(3, 7), 0.02, rng:NextNumber(2, 5)), CFrame.new(x, 0.21, z) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), C.roadPatch, Enum.Material.Concrete)
	end
	for _, x in ipairs({ -P.spacing * 1.5, P.spacing * 0.5, P.spacing * 2 }) do
		cyl(g, "Manhole", 0.06, 3, upright(Vector3.new(x, 0.23, -40)), C.metal, Enum.Material.DiamondPlate)
	end
end

---------------------------------------------------------------- 꾸미기 가게 (길 건너편)

-- 가상 가게 (실제 상표 아님). style: 벽 재질·색, 차양 색, 앞모습 종류
local SHOPS = {
	{ "행복문방구", 30, { wall = C.cream, mat = Enum.Material.Plaster, awn = { C.pink, C.white }, kind = "toys" } },
	{ "골목슈퍼", 28, { wall = C.mint, mat = Enum.Material.Plaster, awn = { C.mint, C.white }, kind = "crates" } },
	{ "별빛이발소", 22, { wall = C.sky, mat = Enum.Material.Plaster, awn = { C.sky, C.white }, kind = "barber" } },
	{ "동네쌀집", 24, { wall = C.brick, mat = Enum.Material.Brick, awn = { C.butter, C.white }, kind = "sacks" } },
	{ "보물만화방", 26, { wall = C.lilac, mat = Enum.Material.Plaster, awn = { C.lilac, C.white }, kind = "door" } },
	{ "깨끗세탁소", 22, { wall = C.white, mat = Enum.Material.Plaster, awn = { C.sky, C.white }, kind = "door" } },
	{ "따끈연탄", 24, { wall = C.brickDark, mat = Enum.Material.Brick, awn = { C.coal, C.cream }, kind = "coal" } },
	{ "튼튼철물점", 28, { wall = C.concrete, mat = Enum.Material.Concrete, awn = { C.butter, C.cream }, kind = "shutter" } },
	{ "엄마손분식", 26, { wall = C.butter, mat = Enum.Material.Plaster, awn = { C.pink, C.cream }, kind = "door" } },
	{ "꽃분이꽃집", 22, { wall = C.cream, mat = Enum.Material.Plaster, awn = { C.leaf, C.cream }, kind = "flowers" } },
	{ "동네책방", 24, { wall = C.brick, mat = Enum.Material.Brick, awn = { C.mint, C.cream }, kind = "door" } },
	{ "달님사진관", 22, { wall = C.sky, mat = Enum.Material.Plaster, awn = { C.lilac, C.white }, kind = "door" } },
}

-- 줄무늬 차양: 앞으로 기운 조각들
local function awning(m, x0, w, y, z, colors)
	local n = math.max(3, math.floor(w / 5)) -- 줄무늬 폭 약 5 (부품 수 줄임)
	local sw = w / n
	local tilt = CFrame.Angles(math.rad(-22), 0, 0)
	for i = 1, n do
		local cx = x0 - w / 2 + (i - 0.5) * sw
		part(m, "Awning", Vector3.new(sw, 0.2, 3.2), CFrame.new(cx, y, z - 1.5) * tilt, colors[(i % 2) + 1], Enum.Material.Fabric, { CanCollide = false })
	end
	part(m, "AwningEdge", Vector3.new(w, 0.5, 0.15), CFrame.new(x0, y - 0.9, z - 3), colors[1], Enum.Material.Fabric, { CanCollide = false })
end

local function frontDetail(m, kind, x0, w, z)
	local front = z - 0.1 -- 가게 앞면 (z = WALK_Z1)
	if kind == "shutter" then
		-- 반쯤 내린 셔터 + 줄
		part(m, "Shutter", Vector3.new(w * 0.6, 5.5, 0.15), CFrame.new(x0, 3.6, front), C.shutter, Enum.Material.Metal)
		for i = 0, 4 do
			part(m, "ShutterRib", Vector3.new(w * 0.6, 0.08, 0.1), CFrame.new(x0, 1.4 + i * 1.1, front - 0.1), C.metal, Enum.Material.Metal)
		end
	else
		-- 유리문 + 창
		part(m, "Door", Vector3.new(4, 6.4, 0.15), CFrame.new(x0 - w * 0.18, 3.7, front), C.glass, Enum.Material.Glass, { Transparency = 0.25 })
		part(m, "DoorFrame", Vector3.new(4.4, 0.3, 0.2), CFrame.new(x0 - w * 0.18, 7, front), C.wood, Enum.Material.Wood)
		part(m, "Window", Vector3.new(w * 0.34, 3.6, 0.15), CFrame.new(x0 + w * 0.2, 4.4, front), C.glass, Enum.Material.Glass, { Transparency = 0.25 })
		part(m, "WindowSill", Vector3.new(w * 0.36, 0.3, 0.6), CFrame.new(x0 + w * 0.2, 2.5, front - 0.3), C.wood, Enum.Material.Wood)
	end
	if kind == "barber" then
		-- 이발소 회전 기둥 (빨강·하양·파랑 띠)
		local px = x0 + w / 2 - 1.2
		cyl(m, "BarberPole", 3.2, 0.8, upright(Vector3.new(px, 4.4, front - 0.6)), C.white, Enum.Material.SmoothPlastic)
		for i, col in ipairs({ C.pink, C.sky, C.pink }) do
			cyl(m, "BarberStripe", 0.35, 0.84, upright(Vector3.new(px, 3.3 + i * 0.7, front - 0.6)), col, Enum.Material.SmoothPlastic)
		end
	elseif kind == "toys" then
		-- 문방구 앞 뽑기통·장난감 판
		part(m, "ToyRack", Vector3.new(4, 3, 1), CFrame.new(x0 + w * 0.2, 1.5, front - 1), C.butter, Enum.Material.SmoothPlastic)
		for i = 0, 2 do
			cyl(m, "Capsule", 0.8, 0.8, CFrame.new(x0 + w * 0.2 - 1.2 + i * 1.2, 3.4, front - 1), ({ C.pink, C.mint, C.sky })[i + 1], Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball })
		end
	elseif kind == "crates" or kind == "sacks" or kind == "flowers" or kind == "coal" then
		for i = 0, 2 do
			local cx = x0 + w * 0.2 - 2 + i * 2.1
			if kind == "crates" then
				part(m, "Crate", Vector3.new(1.9, 1.2, 1.4), CFrame.new(cx, 0.6 + 0.5, front - 1.2), ({ C.butter, C.mint, C.pink })[i + 1], Enum.Material.SmoothPlastic)
			elseif kind == "sacks" then
				part(m, "Sack", Vector3.new(1.6, 1.5, 1.2), CFrame.new(cx, 0.75 + 0.5, front - 1.2), C.cream, Enum.Material.Fabric)
			elseif kind == "flowers" then
				cyl(m, "Pot", 1, 1.4, upright(Vector3.new(cx, 1, front - 1.2)), C.brick, Enum.Material.SmoothPlastic)
				part(m, "Bloom", Vector3.new(1.6, 1.6, 1.6), CFrame.new(cx, 2, front - 1.2), ({ C.pink, C.butter, C.lilac })[i + 1], Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball })
			else
				for k = 0, 2 do
					cyl(m, "Briquette", 0.55, 1, upright(Vector3.new(cx, 0.8 + k * 0.56, front - 1.2)), C.coal, Enum.Material.Slate)
				end
			end
		end
	end
end

local function decorShop(def, x0)
	local name, w, st = def[1], def[2], def[3]
	local m = model("Shop_" .. name)
	local h = 11 + (#name % 3) * 1.5
	local zc = WALK_Z1 + SHOP_DEPTH / 2
	part(m, "Body", Vector3.new(w, h, SHOP_DEPTH), CFrame.new(x0, h / 2 + 0.5, zc), st.wall, st.mat)
	part(m, "Base", Vector3.new(w + 0.2, 1, SHOP_DEPTH + 0.2), CFrame.new(x0, 1, zc), C.concrete, Enum.Material.Concrete)
	part(m, "Roof", Vector3.new(w + 1, 0.6, SHOP_DEPTH + 1), CFrame.new(x0, h + 0.8, zc), st.awn[1]:Lerp(C.brickDark, 0.45), Enum.Material.SmoothPlastic) -- 위에서 볼 때 회색이 밋밋해서 차양 색 쪽으로
	part(m, "RoofLip", Vector3.new(w + 1, 1, 0.4), CFrame.new(x0, h + 0.6, WALK_Z1 - 0.5), st.awn[1], Enum.Material.SmoothPlastic)
	-- 간판 (나무판 + 글씨)
	local sign = part(m, "Sign", Vector3.new(w * 0.78, 2.6, 0.35), CFrame.new(x0, h - 1.6, WALK_Z1 - 0.3), C.cream, Enum.Material.Wood)
	part(m, "SignFrame", Vector3.new(w * 0.78 + 0.5, 3.1, 0.25), CFrame.new(x0, h - 1.6, WALK_Z1 - 0.15), C.wood, Enum.Material.Wood)
	signText(sign, name, C.ink)
	awning(m, x0, w * 0.9, h - 3.8, WALK_Z1, st.awn)
	frontDetail(m, st.kind, x0, w, WALK_Z1)
	-- 지붕 위 실외기·물탱크 (멀리서 보는 실루엣)
	part(m, "RoofBox", Vector3.new(3, 2, 2.2), CFrame.new(x0 + w * 0.25, h + 2.1, zc + 3), C.white, Enum.Material.SmoothPlastic)
	return m
end

local function decorRow()
	-- 왼쪽(-x)에서 x = -SIDE_GAP/2까지, 오른쪽은 +SIDE_GAP/2부터 HALF까지 가게를 채움. 사이는 좁은 골목(2칸)
	local idx = 1
	local function fill(from, to, dir)
		local x = from
		while true do
			local def = SHOPS[((idx - 1) % #SHOPS) + 1]
			local w = def[2]
			local nx = x + dir * w
			if (dir > 0 and nx > to) or (dir < 0 and nx < to) then
				break
			end
			decorShop(def, x + dir * w / 2)
			idx += 1
			x = nx + dir * 2 -- 가게 사이 틈
		end
		return x
	end
	local leftEnd = fill(-SIDE_GAP / 2, -HALF + 10, -1)
	local rightEnd = fill(SIDE_GAP / 2, HALF - 10, 1)
	-- 남은 끝자리는 담장으로 메움
	local wall = model("RowEndWalls")
	for _, pair in ipairs({ { leftEnd, -HALF }, { rightEnd, HALF } }) do
		local a, b = pair[1], pair[2]
		local w = math.abs(b - a)
		if w > 1 then
			part(wall, "Wall", Vector3.new(w, 6, 1), CFrame.new((a + b) / 2, 3.5, WALK_Z1 + 0.5), C.brick, Enum.Material.Brick)
		end
	end
	-- 스폰 쪽 샛길 입구 (아치 간판)
	local gate = model("SideStreetGate")
	for _, sx in ipairs({ -1, 1 }) do
		cyl(gate, "GatePost", 12, 1, upright(Vector3.new(sx * (SIDE_GAP / 2 - 1), 6.5, WALK_Z1 - 0.2)), C.wood, Enum.Material.Wood)
	end
	local arch = part(gate, "GateSign", Vector3.new(SIDE_GAP - 1, 2.4, 0.4), CFrame.new(0, 11.5, WALK_Z1 - 0.2), C.butter, Enum.Material.Wood)
	signText(arch, "달고나 골목", C.ink)
	part(gate, "SideStreet", Vector3.new(SIDE_GAP, 0.25, SHOP_DEPTH + 26), CFrame.new(0, 0.14, WALK_Z1 + (SHOP_DEPTH + 26) / 2), C.walk, Enum.Material.Pavement)
end

---------------------------------------------------------------- 전봇대·전깃줄·가로등

local function poleFallback(m, cf)
	cyl(m, "Pole", 22, 1, cf * CFrame.new(0, 11, 0) * CFrame.Angles(0, 0, math.rad(90)), C.concrete, Enum.Material.Concrete)
	part(m, "CrossArm", Vector3.new(6, 0.4, 0.4), cf * CFrame.new(0, 20, 0), C.wood, Enum.Material.Wood)
	for _, dx in ipairs({ -2.6, 2.6 }) do
		cyl(m, "Insulator", 0.6, 0.35, cf * CFrame.new(dx, 20.5, 0) * CFrame.Angles(0, 0, math.rad(90)), C.white, Enum.Material.SmoothPlastic)
	end
	cyl(m, "Transformer", 2.2, 1.4, cf * CFrame.new(0, 16.5, 0.9) * CFrame.Angles(0, 0, math.rad(90)), C.metal, Enum.Material.Metal)
end

local function lampFallback(m, cf)
	part(m, "LampArm", Vector3.new(0.25, 0.25, 3.2), cf * CFrame.new(0, 14, -1.6), C.metal, Enum.Material.Metal)
	local shade = part(m, "LampShade", Vector3.new(1.6, 0.5, 1.6), cf * CFrame.new(0, 13.7, -3.2), C.mint, Enum.Material.Metal)
	local bulb = part(m, "LampBulb", Vector3.new(0.7, 0.7, 0.7), cf * CFrame.new(0, 13.3, -3.2), C.butter, Enum.Material.Neon, { Shape = Enum.PartType.Ball })
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 0.6
	light.Color = Color3.fromRGB(255, 214, 160)
	light.Shadows = false
	light.Parent = bulb
	return shade
end

local function poles()
	-- 건너 인도 가장자리(길 쪽)를 따라 전봇대. 위 전선 Attachment 2개(가로대 양 끝)
	local wires = model("Wires")
	local xs = {}
	local step = 46
	local n = math.floor(HALF * 2 / step)
	for i = 0, n do
		table.insert(xs, -HALF + 10 + i * step)
	end
	local tops = {}
	for i, x in ipairs(xs) do
		local cf = CFrame.new(x, 0.5, ROAD_Z1 + 1.6)
		local m = prop("UtilityPole", cf, poleFallback)
		-- 전선 매달 자리 (모델이 바뀌어도 같은 높이)
		local anchor = part(wires, "WireAnchor", Vector3.new(0.2, 0.2, 0.2), cf * CFrame.new(0, 20.6, 0), C.metal, Enum.Material.Metal, { Transparency = 1, CanCollide = false, CanQuery = false })
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(-2.6, 0, 0)
		a1.Parent = anchor
		local a2 = Instance.new("Attachment")
		a2.Position = Vector3.new(2.6, 0, 0)
		a2.Parent = anchor
		tops[i] = { a1, a2, anchor }
		if i % 2 == 0 then
			prop("StreetLamp", cf, lampFallback)
		end
		m.Name = "UtilityPole"
	end
	-- 전봇대 사이 처진 전선 (Beam: 부품 없이 곡선, 삼각형 거의 없음)
	for i = 1, #tops - 1 do
		for k = 1, 2 do
			local b = Instance.new("Beam")
			b.Attachment0 = tops[i][k]
			b.Attachment1 = tops[i + 1][k]
			b.Width0, b.Width1 = 0.12, 0.12
			b.Color = ColorSequence.new(Color3.fromRGB(50, 46, 46))
			b.LightInfluence = 1
			b.Segments = 12
			b.CurveSize0 = -3
			b.CurveSize1 = 3
			b.FaceCamera = true
			b.Parent = tops[i][3]
		end
	end
	-- 길을 가로질러 가게 쪽으로 가는 전선 몇 가닥 (골목 느낌)
	for i = 2, #tops - 1, 3 do
		local anchor = part(wires, "WireAnchorShop", Vector3.new(0.2, 0.2, 0.2), CFrame.new(xs[i] + 6, 13, ROAD_Z0 - 1), C.metal, Enum.Material.Metal, { Transparency = 1, CanCollide = false, CanQuery = false })
		local a = Instance.new("Attachment")
		a.Parent = anchor
		local b = Instance.new("Beam")
		b.Attachment0 = tops[i][1]
		b.Attachment1 = a
		b.Width0, b.Width1 = 0.1, 0.1
		b.Color = ColorSequence.new(Color3.fromRGB(50, 46, 46))
		b.Segments = 10
		b.CurveSize0 = -2
		b.CurveSize1 = 2
		b.FaceCamera = true
		b.Parent = anchor
	end
end

---------------------------------------------------------------- 길가 소품

local function bikeFallback(m, cf)
	for _, dz in ipairs({ -1.9, 1.9 }) do
		cyl(m, "Wheel", 0.2, 2.6, cf * CFrame.new(0, 1.3, dz), C.ink, Enum.Material.SmoothPlastic)
	end
	part(m, "Frame", Vector3.new(0.2, 0.25, 3.6), cf * CFrame.new(0, 1.9, 0) * CFrame.Angles(math.rad(10), 0, 0), C.mint, Enum.Material.Metal)
	part(m, "Seat", Vector3.new(0.6, 0.25, 1), cf * CFrame.new(0, 2.6, 0.9), C.ink, Enum.Material.SmoothPlastic)
	part(m, "Basket", Vector3.new(1.2, 0.8, 1), cf * CFrame.new(0, 2.6, -2.1), C.woodLight, Enum.Material.Fabric)
	part(m, "Handle", Vector3.new(1.6, 0.15, 0.15), cf * CFrame.new(0, 2.9, -1.6), C.metal, Enum.Material.Metal)
end

local function briquetteFallback(m, cf)
	-- 연탄 기둥 3줄 (한 줄 = 연탄 여러 장이 쌓인 긴 원기둥, 부품 수 줄임)
	for i, h in ipairs({ 2.4, 1.8, 2.4 }) do
		cyl(m, "Briquette", h, 1, cf * CFrame.new((i - 2) * 1.05, h / 2, (i == 2) and 0.9 or 0) * CFrame.Angles(0, 0, math.rad(90)), C.coal, Enum.Material.Slate)
	end
end

local function potFallback(m, cf)
	cyl(m, "Basin", 1, 2.4, cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), C.pink, Enum.Material.SmoothPlastic)
	part(m, "Leaf", Vector3.new(1.8, 1.4, 1.8), cf * CFrame.new(0, 1.4, 0), C.leaf, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball })
end

local function crateFallback(m, cf)
	part(m, "Crate", Vector3.new(2, 1.4, 1.5), cf * CFrame.new(0, 0.7, 0), C.mint, Enum.Material.SmoothPlastic)
	part(m, "Crate", Vector3.new(2, 1.4, 1.5), cf * CFrame.new(0.15, 2.1, 0) * CFrame.Angles(0, 0.15, 0), C.butter, Enum.Material.SmoothPlastic)
end

local function benchFallback(m, cf)
	part(m, "Top", Vector3.new(8, 0.4, 5), cf * CFrame.new(0, 1.4, 0), C.woodLight, Enum.Material.WoodPlanks)
	for _, dx in ipairs({ -3.6, 3.6 }) do
		for _, dz in ipairs({ -2.2, 2.2 }) do
			part(m, "Leg", Vector3.new(0.4, 1.2, 0.4), cf * CFrame.new(dx, 0.6, dz), C.wood, Enum.Material.Wood)
		end
	end
end

local function binFallback(m, cf)
	cyl(m, "Bin", 3, 1.8, cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), C.metal, Enum.Material.Metal)
	cyl(m, "Lid", 0.25, 2, cf * CFrame.new(0, 3.1, 0) * CFrame.Angles(0, 0, math.rad(90)), C.metal, Enum.Material.Metal)
end

local function mailboxFallback(m, cf)
	part(m, "Post", Vector3.new(0.4, 2.6, 0.4), cf * CFrame.new(0, 1.3, 0), C.metal, Enum.Material.Metal)
	part(m, "Box", Vector3.new(1.6, 1.4, 1.2), cf * CFrame.new(0, 3.2, 0), Color3.fromRGB(214, 92, 84), Enum.Material.SmoothPlastic)
end

local function streetProps()
	local rng = Random.new(2311)
	local front = CFrame.Angles(0, math.pi, 0) -- 길 건너 소품이 길(-Z) 쪽을 봄
	-- 건너 인도: 꾸미기 가게 앞
	local walkZ = (ROAD_Z1 + WALK_Z1) / 2 + 0.5
	local kinds = {
		{ "Bicycle", bikeFallback },
		{ "PotBasin", potFallback },
		{ "PlasticCrate", crateFallback },
		{ "BriquetteStack", briquetteFallback },
		{ "TrashBin", binFallback },
		{ "PotBasin", potFallback },
	}
	local x = -HALF + 22
	local i = 0
	while x < HALF - 20 do
		if math.abs(x) > SIDE_GAP / 2 + 3 then
			i += 1
			local k = kinds[(i % #kinds) + 1]
			prop(k[1], CFrame.new(x, 0.5, walkZ + 1.5) * front * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), k[2])
		end
		x += rng:NextNumber(17, 26)
	end
	-- 가게 사이 길 가장자리 (부지 사이 틈 앞, 손님 길은 비움)
	for gi = 1, P.count - 1 do
		local gx = (gi - P.count / 2) * P.spacing
		prop("Pyeongsang", CFrame.new(gx, 0.2, ROAD_Z0 - 4), benchFallback)
		prop("PotBasin", CFrame.new(gx - 6, 0.2, ROAD_Z0 - 2), potFallback)
		prop("PotBasin", CFrame.new(gx + 6, 0.2, ROAD_Z0 - 2), potFallback)
	end
	prop("Mailbox", CFrame.new(SIDE_GAP / 2 + 2, 0.5, walkZ - 0.5) * front, mailboxFallback)
end

---------------------------------------------------------------- 골목 양 끝

local function ends()
	local e = model("AlleyEnds")
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * (HALF + 8)
		-- 담벼락 (가게 쪽부터 건너 가게 뒤까지), 가운데에 좁은 입구
		local z0, z1 = -100, WALK_Z1 + SHOP_DEPTH + 4
		local gapZ0, gapZ1 = ROAD_Z0 + 6, ROAD_Z1 - 6
		part(e, "EndWall", Vector3.new(1.2, 9, gapZ0 - z0), CFrame.new(x, 4.5, (z0 + gapZ0) / 2), C.brick, Enum.Material.Brick)
		part(e, "EndWall", Vector3.new(1.2, 9, z1 - gapZ1), CFrame.new(x, 4.5, (gapZ1 + z1) / 2), C.brick, Enum.Material.Brick)
		part(e, "WallCap", Vector3.new(1.6, 0.4, gapZ0 - z0), CFrame.new(x, 9.2, (z0 + gapZ0) / 2), C.concrete, Enum.Material.Concrete)
		part(e, "WallCap", Vector3.new(1.6, 0.4, z1 - gapZ1), CFrame.new(x, 9.2, (gapZ1 + z1) / 2), C.concrete, Enum.Material.Concrete)
		-- 입구 너머는 막아 둠 (나가지 못하게, 보이는 건 계단 골목 느낌의 벽)
		part(e, "EndBlock", Vector3.new(1, 12, gapZ1 - gapZ0 + 2), CFrame.new(x + sx * 10, 6, (gapZ0 + gapZ1) / 2), C.cream, Enum.Material.Plaster)
		part(e, "EndFloor", Vector3.new(10, 0.2, gapZ1 - gapZ0), CFrame.new(x + sx * 5, 0.1, (gapZ0 + gapZ1) / 2), C.road, Enum.Material.Concrete)
		-- 입구 위 작은 간판
		local s = part(e, "EndSign", Vector3.new(0.3, 2, 8), CFrame.new(x - sx * 0.8, 9, (gapZ0 + gapZ1) / 2), C.butter, Enum.Material.Wood)
		signText(s, "달고나 골목", C.ink, sx < 0 and Enum.NormalId.Right or Enum.NormalId.Left)
		prop("TrashBin", CFrame.new(x - sx * 3, 0.2, gapZ0 - 3), binFallback)
		prop("BriquetteStack", CFrame.new(x - sx * 3, 0.2, gapZ1 + 3), briquetteFallback)
	end
end

---------------------------------------------------------------- 하늘·조명 (따뜻한 오후 낮, 사용자 2026-11-23)

function A.lighting()
	Lighting.ClockTime = 15.2
	Lighting.Brightness = 2.6
	Lighting.GeographicLatitude = 35
	Lighting.Ambient = Color3.fromRGB(120, 104, 96)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 135, 125)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 225, 180)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atm then
		atm = Instance.new("Atmosphere")
		atm.Parent = Lighting
	end
	atm.Density = 0.28
	atm.Offset = 0.2
	atm.Color = Color3.fromRGB(235, 215, 190)
	atm.Decay = Color3.fromRGB(150, 120, 100)
	atm.Haze = 0.6
	atm.Glare = 0.2
	local cc = Lighting:FindFirstChild("AlleyGrade") or Instance.new("ColorCorrectionEffect")
	cc.Name = "AlleyGrade"
	cc.Saturation = -0.05
	cc.Contrast = 0.05
	cc.TintColor = Color3.fromRGB(255, 245, 228)
	cc.Parent = Lighting
end

---------------------------------------------------------------- 만들기

function A.build()
	local old = workspace:FindFirstChild("Alley")
	if old then
		old:Destroy()
	end
	local sa = ServerStorage:FindFirstChild("Assets")
	assets = sa and sa:FindFirstChild("Alley")
	folder = Instance.new("Folder")
	folder.Name = "Alley"
	ground()
	decorRow()
	poles()
	streetProps()
	ends()
	folder.Parent = workspace
	A.lighting()
	return folder
end

return A

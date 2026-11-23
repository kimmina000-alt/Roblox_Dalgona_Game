-- 레트로 골목 맵 (21번, DEVELOPMENT_PLAN 6장 Phase 6, 2026-11-23)
-- 맵은 스크립트로 만든다 (DEVELOPMENT_PLAN §8: Studio에서 손으로 끌어 옮기지 않음). 서버가 시작할 때 Workspace.Alley에 만든다.
--
-- 배치 (사용자 2026-11-23: 분위기는 따뜻한 오후 낮, 가게는 길 양쪽에 3칸씩 마주 봄 — GDD §9)
--   남쪽 줄: 가게 1~3 (앞 = +Z, 앞선 z = S_FRONT), 북쪽 줄: 가게 4~6 (앞 = -Z, 앞선 z = N_FRONT). 자리 계산은 PlotService
--   길: 두 줄 앞선 사이 (폭 ROAD_W). 노점·진열대·손님 줄은 각 가게 앞 8칸 안 (PlotService·SalesService)
--   골목 양 끝 x = ±HALF: 꾸미기 가게(가상 가게) 줄 + 담벼락 + 입구
-- 부지·작업대·진열대·공장 자리는 저장·부지 세션(PlotService·PlotLayout) 것이라 건드리지 않는다.
--
-- 소품: ServerStorage.Assets.Alley.<이름> 모델(Blender, 손님 NPC 세션)이 있으면 그것을 복제하고, 없으면 Part로 임시 모양을 만든다.
-- 폰 예산(docs/PERFORMANCE_BUDGET.md): 이 골목 전체 약 500 부품, 삼각형 2만 안팎

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GrowthConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))

local A = {}

local P = GrowthConfig.Plots
local PER_ROW = math.ceil(P.count / 2) -- 한 줄 가게 수 (3)
local ROAD_W = 32 -- 두 줄 가게 앞선 사이
local S_FRONT = P.rowZ + P.size.Z / 2 -- 남쪽 줄 가게 앞선 (-54)
local N_FRONT = S_FRONT + ROAD_W -- 북쪽 줄 가게 앞선 (-22)
local ROAD_Z0, ROAD_Z1 = S_FRONT, N_FRONT
local ROAD_ZC = (ROAD_Z0 + ROAD_Z1) / 2
local SHOP_HALF = 26 -- 가게 3D 반폭 (사용자 가게 모델 폭 46.7 + 걸이 간판, 2026-11-23 간격 55로 바뀜)
local LAST_X = ((PER_ROW - 1) / 2) * P.spacing -- 끝 가게 가운데 x (100)
local END_X0 = LAST_X + SHOP_HALF + 6 -- 골목 끝 꾸미기 가게가 시작하는 x (87)
local HALF = END_X0 + 52 -- 골목 끝 (꾸미기 가게 2칸쯤)
local CANON_Z = 0 -- 꾸미기 가게를 만들 때 쓰는 기준 앞선 (만든 뒤 제자리로 돌려 옮김)
local SHOP_DEPTH = 14

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

-- Blender 소품 (손님 NPC 세션 tools/blender/alley.py → 레퍼런스/alley/dalgona_alley.glb, 소품 하나 = MeshPart 하나).
-- MeshPart는 경계 상자 가운데가 기준이라, 바닥 가운데(예외: StreetLamp = 전봇대에 붙는 끝, AcUnit = 벽에 닿는 뒷면 가운데)
-- 까지의 거리(alley_parts.txt의 center_to_pivot)를 PivotOffset으로 넣고 놓는다
local PIVOT = {
	UtilityPole = Vector3.new(0, -11, 0),
	StreetLamp = Vector3.new(0, -0.23, 2.07),
	Bicycle = Vector3.new(-0.04, -1.28, 0),
	BriquetteStack = Vector3.new(0, -1.06, 0),
	PotBasin = Vector3.new(0, -0.85, 0),
	PlasticCrate = Vector3.new(0, -0.75, 0),
	Pyeongsang = Vector3.new(0, -0.74, 0),
	AcUnit = Vector3.new(0, -0.93, 0.63),
	GasTank = Vector3.new(0, -1.48, 0),
	TrashBin = Vector3.new(0, -1.49, 0),
	Mailbox = Vector3.new(0, -2.05, 0.03),
	ShopShutterSign = Vector3.new(0, 0, -0.01),
}

-- 사용자가 가져온 보기용 모델(속성 FollowPlot, 예: ShopScene3D)이 놓인 자리는 비움 (PlotService가 가게 옆으로 옮김)
local keepOut = {}
local function collectKeepOut()
	table.clear(keepOut)
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("FollowPlot") ~= nil then
			local cf, size = m:GetBoundingBox()
			local h = (cf - cf.Position):VectorToWorldSpace(size / 2)
			local ext = Vector3.new(math.abs(h.X), 0, math.abs(h.Z)) + Vector3.new(3, 0, 3)
			table.insert(keepOut, { cf.Position - ext, cf.Position + ext })
		end
	end
end
local function blocked(pos)
	for _, b in ipairs(keepOut) do
		if pos.X > b[1].X and pos.X < b[2].X and pos.Z > b[1].Z and pos.Z < b[2].Z then
			return true
		end
	end
	return false
end

-- Blender 모델이 있으면 그것을, 없으면 fallback(m, cf)으로 Part 모양을 만든다. cf = 바닥 가운데, 앞 = -Z
local assets = nil
local function prop(name, cf, fallback, parent)
	if not parent and blocked(cf.Position) then
		return nil
	end
	local src = assets and assets:FindFirstChild(name)
	if src then
		local c = src:Clone()
		if c:IsA("BasePart") and PIVOT[name] then
			c.PivotOffset = CFrame.new(PIVOT[name])
		end
		c:PivotTo(cf)
		c.Parent = parent or folder
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanTouch = false
			end
		end
		return c
	end
	local m = model(name, parent)
	fallback(m, cf)
	return m
end

---------------------------------------------------------------- 바닥·길

local function ground()
	local g = model("Ground")
	local len = HALF * 2 + 20
	-- 길: 낡은 콘크리트 (가게 부지 바닥 0.4보다 낮게)
	part(g, "Road", Vector3.new(len, 0.2, ROAD_W), CFrame.new(0, 0.1, ROAD_ZC), C.road, Enum.Material.Concrete)
	-- 양쪽 가게 앞선 턱
	part(g, "Curb", Vector3.new(len, 0.35, 0.8), CFrame.new(0, 0.18, ROAD_Z0 - 0.4), C.curb, Enum.Material.Concrete)
	part(g, "Curb", Vector3.new(len, 0.35, 0.8), CFrame.new(0, 0.18, ROAD_Z1 + 0.4), C.curb, Enum.Material.Concrete)
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
		local z = rng:NextNumber(ROAD_ZC - 5, ROAD_ZC + 5) -- 가게 앞 8칸(노점·손님)은 비움
		part(g, "Patch", Vector3.new(rng:NextNumber(3, 7), 0.02, rng:NextNumber(2, 5)), CFrame.new(x, 0.21, z) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), C.roadPatch, Enum.Material.Concrete)
	end
	for _, x in ipairs({ -P.spacing * 0.5, P.spacing * 0.5, HALF - 30 }) do
		cyl(g, "Manhole", 0.06, 3, upright(Vector3.new(x, 0.23, ROAD_ZC)), C.metal, Enum.Material.DiamondPlate)
	end
end

---------------------------------------------------------------- 꾸미기 가게 (골목 양 끝, 가상 가게)

-- 가상 가게 (실제 상표 아님). style: 벽 재질·색, 차양 색, 앞모습 종류
local SHOPS = {
	{ "행복문방구", 30, { wall = C.cream, mat = Enum.Material.Plaster, awn = { C.pink, C.white }, kind = "toys" } },
	{ "솜사탕가게", 28, { wall = C.mint, mat = Enum.Material.Plaster, awn = { C.mint, C.white }, kind = "crates" } }, -- 예전 "골목슈퍼": 진짜 슈퍼(D54)가 동쪽 끝에 생겨 이름을 바꿈
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
	local front = z - 0.1 -- 가게 앞면 (z = CANON_Z)
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
	local zc = CANON_Z + SHOP_DEPTH / 2
	part(m, "Body", Vector3.new(w, h, SHOP_DEPTH), CFrame.new(x0, h / 2 + 0.5, zc), st.wall, st.mat)
	part(m, "Base", Vector3.new(w + 0.2, 1, SHOP_DEPTH + 0.2), CFrame.new(x0, 1, zc), C.concrete, Enum.Material.Concrete)
	part(m, "Roof", Vector3.new(w + 1, 0.6, SHOP_DEPTH + 1), CFrame.new(x0, h + 0.8, zc), st.awn[1]:Lerp(C.brickDark, 0.45), Enum.Material.SmoothPlastic) -- 위에서 볼 때 회색이 밋밋해서 차양 색 쪽으로
	part(m, "RoofLip", Vector3.new(w + 1, 1, 0.4), CFrame.new(x0, h + 0.6, CANON_Z - 0.5), st.awn[1], Enum.Material.SmoothPlastic)
	-- 간판 (나무판 + 글씨)
	local sign = part(m, "Sign", Vector3.new(w * 0.78, 2.6, 0.35), CFrame.new(x0, h - 1.6, CANON_Z - 0.3), C.cream, Enum.Material.Wood)
	part(m, "SignFrame", Vector3.new(w * 0.78 + 0.5, 3.1, 0.25), CFrame.new(x0, h - 1.6, CANON_Z - 0.15), C.wood, Enum.Material.Wood)
	signText(sign, name, C.ink)
	awning(m, x0, w * 0.9, h - 3.8, CANON_Z, st.awn)
	frontDetail(m, st.kind, x0, w, CANON_Z)
	-- 지붕 위 물탱크 (멀리서 보는 실루엣)
	part(m, "RoofBox", Vector3.new(3, 2, 2.2), CFrame.new(x0 + w * 0.25, h + 2.1, zc + 3), C.white, Enum.Material.SmoothPlastic)
	-- 앞벽 아래 실외기 (뒷면이 벽에 닿음, 차양 아래), 분식·연탄집 옆 가스통
	if #name % 2 == 0 then
		prop("AcUnit", CFrame.new(x0 + w / 2 - 1.8, 2.6, CANON_Z), function(mm, cf)
			part(mm, "Ac", Vector3.new(3, 2.4, 1.2), cf * CFrame.new(0, 0.9, -0.6), C.white, Enum.Material.SmoothPlastic)
		end, m)
	end
	if st.kind == "coal" or name:find("분식") then
		prop("GasTank", CFrame.new(x0 - w / 2 + 1.5, 0.5, CANON_Z - 1), function(mm, cf)
			cyl(mm, "Tank", 2.9, 1.3, cf * CFrame.new(0, 1.45, 0) * CFrame.Angles(0, 0, math.rad(90)), C.sky, Enum.Material.Metal)
		end, m)
	end
	return m
end

-- ── 골목 슈퍼 (D54, 2026-11-25 확정): 재료는 슈퍼에 걸어가 사 옴. 동쪽 끝 남쪽 줄 꾸미기 가게 1칸을 바꿈 (D31 바뀜), 문은 길 쪽.
-- 모델 = ServerStorage.Assets.Market (3D 세션 tools/blender/cozy_market.py, 공유 노트 market-3d-1125.md: 폭 26 × 깊이 22,
-- 원점 = 앞벽 바깥면 가운데 바닥, 앞 = -Z, 문 가운데 6 × 8). 예전 이름 AlleyMarket도 찾음.
-- 모델 자리는 모델 안 자리 표시 Mk_Pt_Door(문 바깥 1.5)로 맞춤 (가져온 모델의 피벗이 원점과 다를 수 있어서). 없으면 상자로.
-- 모델이 없으면 들어갈 수 있는 임시 건물(바닥·벽 3면·문 뚫린 앞벽·지붕·간판·계산대 자리)을 만듦.
-- 서버 장보기(저장·부지 세션)·길 안내·주인 NPC가 쓰는 자리: Workspace.Alley.AlleyMarket 안 파트 (투명·충돌 없음)
--   MarketSpot (앞벽 가운데 바닥, 앞 = LookVector = 길 쪽), MarketDoor (문 바깥 = 모델 Mk_Pt_Door),
--   MarketCounter (계산대 앞 플레이어 자리 = Mk_Pt_Customer, 장보기 안내), MarketOwner (계산대 뒤 주인 = Mk_Pt_Owner)
--   모델 속성 Market = true
-- 폭·깊이는 모델에서 잼 (3D 세션 모델이 두 번 바뀜: 26×22 → 32×13.4). 모델이 없으면 임시 건물 크기. 깊이가 꾸미기 가게(14)보다
-- 깊으면 그 칸만 뒤 담벼락을 그만큼 뺌 (gapWalls)
local MARKET_W, MARKET_D = 26, SHOP_DEPTH
local DOOR_W, DOOR_H = 6, 8
local function marketShell(m, x0, w)
	local d, h = MARKET_D, 12
	local zc = CANON_Z + d / 2
	local wallC, trim = C.cream, C.leaf
	part(m, "Floor", Vector3.new(w, 1, d), CFrame.new(x0, 0.5, zc), C.white, Enum.Material.Marble)
	part(m, "BackWall", Vector3.new(w, h, 1), CFrame.new(x0, h / 2 + 1, CANON_Z + d - 0.5), wallC, Enum.Material.Plaster)
	for _, sx in ipairs({ -1, 1 }) do
		part(m, "SideWall", Vector3.new(1, h, d), CFrame.new(x0 + sx * (w / 2 - 0.5), h / 2 + 1, zc), wallC, Enum.Material.Plaster)
	end
	-- 앞벽: 가운데 문 구멍 (폭 DOOR_W, 높이 DOOR_H) 양옆 유리창 + 문 위 벽
	local side = (w - DOOR_W) / 2
	for _, sx in ipairs({ -1, 1 }) do
		local cx = x0 + sx * (DOOR_W / 2 + side / 2)
		part(m, "FrontWall", Vector3.new(side, 3, 1), CFrame.new(cx, 2.5, CANON_Z + 0.5), wallC, Enum.Material.Plaster)
		part(m, "Window", Vector3.new(side - 1, 5, 0.3), CFrame.new(cx, 6.5, CANON_Z + 0.5), C.glass, Enum.Material.Glass, { Transparency = 0.5 })
		part(m, "FrontWallTop", Vector3.new(side, h - 8, 1), CFrame.new(cx, 9 + (h - 8) / 2, CANON_Z + 0.5), wallC, Enum.Material.Plaster)
	end
	part(m, "DoorHeader", Vector3.new(DOOR_W, h - DOOR_H, 1), CFrame.new(x0, 1 + DOOR_H + (h - DOOR_H) / 2, CANON_Z + 0.5), wallC, Enum.Material.Plaster)
	part(m, "Roof", Vector3.new(w + 1, 0.6, d + 1), CFrame.new(x0, h + 1.3, zc), trim:Lerp(C.brickDark, 0.35), Enum.Material.SmoothPlastic)
	local sign = part(m, "Sign", Vector3.new(w * 0.6, 2.6, 0.35), CFrame.new(x0, h - 0.4, CANON_Z - 0.3), C.cream, Enum.Material.Wood)
	part(m, "SignFrame", Vector3.new(w * 0.6 + 0.5, 3.1, 0.25), CFrame.new(x0, h - 0.4, CANON_Z - 0.15), C.wood, Enum.Material.Wood)
	signText(sign, "골목 슈퍼", C.ink)
	awning(m, x0, w * 0.9, h - 2.8, CANON_Z, { C.leaf, C.white })
	-- 안: 계산대 (문 들어가서 오른쪽 안), 진열대 두 줄 (가운데 통로는 비움)
	part(m, "Counter", Vector3.new(2.4, 3.2, 6), CFrame.new(x0 + w / 2 - 4, 2.6, CANON_Z + 5), C.woodLight, Enum.Material.Wood)
	for _, sx in ipairs({ -1, 1 }) do
		part(m, "Shelf", Vector3.new(2, 5, d - 6), CFrame.new(x0 + sx * (w / 2 - 3), 3.5, zc + 2), C.wood, Enum.Material.Wood)
	end
end
local function findPart(root, name)
	local x = root:FindFirstChild(name, true)
	if x and not x:IsA("BasePart") then
		x = x:FindFirstChildWhichIsA("BasePart", true)
	end
	return x
end
-- 너구리 사장님 (2026-11-25, NPC 세션 tools/blender/shopkeeper.py · Shared.ShopkeeperRig): 계산대 안쪽 MarketOwner 자리에 서서
-- 계산대 앞(MarketCounter)을 봄. 메시 = ServerStorage.Assets.Shopkeeper_Raccoon 안 Raccoon_<부품>. 없으면 아무것도 안 놓음.
-- 부품마다 속성 Joint·Center(리그 값)·모델 속성 Root(CFrame) → 클라이언트 ShopkeeperClient가 손 흔들기·고개 끄덕·인사를 그림
local Rig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopkeeperRig"))
local function shopkeeper(m)
	local sa = ServerStorage:FindFirstChild("Assets")
	local src = sa and sa:FindFirstChild("Shopkeeper_Raccoon")
	local owner, counter = m:FindFirstChild("MarketOwner"), m:FindFirstChild("MarketCounter")
	if not (src and owner) then
		return nil
	end
	local feet = owner.Position - Vector3.new(0, owner.Size.Y / 2, 0)
	local face = counter and Vector3.new(counter.Position.X, feet.Y, counter.Position.Z) or (feet + owner.CFrame.LookVector)
	if (face - feet).Magnitude < 0.1 then
		face = feet + owner.CFrame.LookVector
	end
	local root = CFrame.lookAt(feet, face) -- 앞 = -Z (리그와 같음)
	local npc = model("Shopkeeper", m)
	npc:SetAttribute("Root", root)
	npc:SetAttribute("Shopkeeper", true)
	for name, pr in pairs(Rig.parts) do
		local mesh = src:FindFirstChild("Raccoon_" .. name, true)
		if mesh and mesh:IsA("BasePart") then
			local c = mesh:Clone()
			c.Name = name
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.CFrame = root * CFrame.new(pr.center)
			c:SetAttribute("Joint", pr.joint)
			c:SetAttribute("Center", pr.center)
			c.Parent = npc
		end
	end
	if #npc:GetChildren() == 0 then
		npc:Destroy()
		return nil
	end
	return npc
end

local function marketSource()
	local sa = ServerStorage:FindFirstChild("Assets")
	local src = sa and (sa:FindFirstChild("AlleyMarket") or sa:FindFirstChild("Market"))
	return src and src:IsA("Model") and src or nil
end
-- 모델의 바닥 앞 가운데 (MarketSpot → Mk_Pt_Door(문 바깥 1.5) → 상자 앞면) 와 바닥 높이
local function marketFront(c)
	local bcf, bsize = c:GetBoundingBox()
	local shell = findPart(c, "Mk_Shell")
	local floorY = shell and (shell.Position.Y - shell.Size.Y / 2) or (bcf.Position.Y - bsize.Y / 2)
	local spot = findPart(c, "MarketSpot")
	if spot then
		return Vector3.new(spot.Position.X, spot.Position.Y - spot.Size.Y / 2, spot.Position.Z), bcf, bsize
	end
	local door = findPart(c, "Mk_Pt_Door")
	if door then
		return Vector3.new(door.Position.X, floorY, door.Position.Z + 1.5), bcf, bsize
	end
	return Vector3.new(bcf.Position.X, floorY, bcf.Position.Z - bsize.Z / 2), bcf, bsize
end
-- 슈퍼 칸 폭·깊이 (endShops·gapWalls가 씀)
local function marketDims()
	local src = marketSource()
	if not src then
		return MARKET_W, MARKET_D
	end
	local at, bcf, bsize = marketFront(src)
	local w = math.max(bsize.X, 10)
	local d = math.max((bcf.Position.Z + bsize.Z / 2) - at.Z, 4)
	return w, d
end

local function marketSpot(x0, w, target)
	local m = model("AlleyMarket")
	m:SetAttribute("Market", true)
	local src = marketSource()
	local cx = x0 + w / 2
	local base = CFrame.new(cx, 0, CANON_Z) -- 기준 자리 (앞벽 바깥면 가운데 바닥, 앞 = -Z)
	local mark = function(name, cf, size)
		return part(m, name, size or Vector3.new(2, 0.2, 2), cf, C.white, nil, { Transparency = 1, CanCollide = false, CanQuery = false })
	end
	if src and src:IsA("Model") then
		local c = src:Clone()
		c.Name = "Building"
		-- 기준: 모델의 바닥 앞 가운데 (marketFront) → 칸의 앞선 가운데
		local at = marketFront(c)
		c:PivotTo(CFrame.new(base.Position - at) * c:GetPivot())
		c.Parent = m
		-- 모델 표시 → 공용 이름 (서버·UI는 AlleyMarket 바로 아래 이 이름만 봄). 모델 안 같은 이름 → Mk_Pt_* 순
		local pts = { MarketDoor = "Mk_Pt_Door", MarketCounter = "Mk_Pt_Customer", MarketOwner = "Mk_Pt_Owner", MarketRegister = "Mk_Pt_Register", MarketDelivery = "Mk_Pt_Delivery" }
		for mine, theirs in pairs(pts) do
			local p = findPart(c, mine) or findPart(c, theirs)
			if p then
				mark(mine, p.CFrame)
			end
		end
		-- 주인 자리 표시가 없으면: 계산대에서 가까운 옆벽 쪽으로 1.8 (계산대 뒤), 가게 가운데를 봄
		if not m:FindFirstChild("MarketOwner") and m:FindFirstChild("MarketCounter") then
			local cp = m.MarketCounter.Position
			local sideX = cp.X >= base.Position.X and 1 or -1
			local op = cp + Vector3.new(sideX * 1.8, 0, 0)
			mark("MarketOwner", CFrame.lookAt(op, Vector3.new(cp.X, op.Y, cp.Z)))
		end
		-- 진열 물건(Mk_Goods, 삼각형 많음)은 클라이언트가 멀면 숨기도록 표시
		local goods = findPart(c, "Mk_Goods")
		if goods then
			goods:SetAttribute("FarHide", 80)
		end
	else
		marketShell(m, cx, MARKET_W)
		mark("MarketDoor", base * CFrame.new(0, 0.1, -1.5))
		mark("MarketCounter", CFrame.new(cx + w / 2 - 6.5, 1.1, CANON_Z + 5)) -- 계산대 앞 (가게 안쪽, 임시 바닥 윗면 1)
		mark("MarketOwner", CFrame.new(cx + w / 2 - 2, 1.1, CANON_Z + 5))
	end
	mark("MarketSpot", base * CFrame.new(0, 0.1, 0))
	shopkeeper(m)
	-- MarketSpot 앞(LookVector)이 길 쪽: 기준 자리에서 앞 = -Z
	local T = target * base:Inverse()
	m:PivotTo(T * m:GetPivot())
	local npc = m:FindFirstChild("Shopkeeper")
	if npc then
		npc:SetAttribute("Root", T * npc:GetAttribute("Root")) -- 옮긴 자리 기준으로 (클라이언트 동작 기준)
	end
	return m
end

-- 골목 양 끝, 길 양쪽에 꾸미기 가게. 기준 자리(앞선 z = CANON_Z, 앞 = -Z)에서 만든 뒤 제자리로 옮김
local function endShops()
	local idx = 1
	for _, sx in ipairs({ -1, 1 }) do
		for _, side in ipairs({ "S", "N" }) do
			local frontZ = side == "S" and ROAD_Z0 or ROAD_Z1
			local rot = side == "S" and CFrame.Angles(0, math.pi, 0) or CFrame.new() -- 남쪽 줄은 +Z(길)를 봄
			local x = END_X0
			if sx == 1 and side == "S" then
				-- 동쪽 끝 남쪽 첫 칸 = 골목 슈퍼 (D54)
				local mw = marketDims()
				marketSpot(0, mw, CFrame.new(sx * (x + mw / 2), 0, frontZ) * rot)
				x += mw + 2
			end
			while true do
				local def = SHOPS[((idx - 1) % #SHOPS) + 1]
				local w = def[2]
				if x + w > HALF - 2 then
					break
				end
				local m = decorShop(def, 0)
				local target = CFrame.new(sx * (x + w / 2), 0, frontZ) * rot
				m:PivotTo(target * CFrame.new(0, 0, CANON_Z):Inverse() * m:GetPivot())
				idx += 1
				x += w + 2
			end
		end
	end
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

-- cf = 전봇대에 붙는 끝 (팔이 -Z로 뻗음)
local function lampFallback(m, cf)
	part(m, "LampArm", Vector3.new(0.25, 0.25, 3.2), cf * CFrame.new(0, 0, -1.6), C.metal, Enum.Material.Metal)
	local shade = part(m, "LampShade", Vector3.new(1.6, 0.5, 1.6), cf * CFrame.new(0, -0.3, -3.2), C.mint, Enum.Material.Metal)
	local bulb = part(m, "LampBulb", Vector3.new(0.7, 0.7, 0.7), cf * CFrame.new(0, -0.7, -3.2), C.butter, Enum.Material.Neon, { Shape = Enum.PartType.Ball })
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 0.6
	light.Color = Color3.fromRGB(255, 214, 160)
	light.Shadows = false
	light.Parent = bulb
	return shade
end

local function poles()
	-- 전봇대: 길 양쪽 가장자리, 가게 사이 틈(x = ±spacing/2 …)과 골목 끝 꾸미기 가게 앞. 가로대 양 끝에 전선 Attachment
	local wires = model("Wires")
	local xs = {}
	for k = 1, PER_ROW - 1 do
		table.insert(xs, (k - PER_ROW / 2) * P.spacing)
	end
	table.insert(xs, 1, -(END_X0 - 3))
	table.insert(xs, END_X0 - 3)
	table.insert(xs, 1, -(HALF - 6))
	table.insert(xs, HALF - 6)
	table.sort(xs)
	local rows = {}
	for _, side in ipairs({ "S", "N" }) do
		local z = side == "S" and ROAD_Z0 - 1.6 or ROAD_Z1 + 1.6
		local toRoad = side == "S" and CFrame.Angles(0, math.pi, 0) or CFrame.new() -- 가로등 팔이 길 쪽(-Z 기준)으로
		local tops = {}
		for i, x in ipairs(xs) do
			local cf = CFrame.new(x, 0.4, z)
			local m = prop("UtilityPole", cf, poleFallback)
			if not m then
				continue -- 보기용 모델 자리 (전선도 건너뜀)
			end
			m.Name = "UtilityPole"
			local anchor = part(wires, "WireAnchor", Vector3.new(0.2, 0.2, 0.2), cf * CFrame.new(0, 20.6, 0), C.metal, Enum.Material.Metal, { Transparency = 1, CanCollide = false, CanQuery = false })
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(-2.6, 0, 0)
			a1.Parent = anchor
			local a2 = Instance.new("Attachment")
			a2.Position = Vector3.new(2.6, 0, 0)
			a2.Parent = anchor
			tops[i] = { a1, a2, anchor }
			if (i + (side == "S" and 0 or 1)) % 2 == 0 then
				local face = CFrame.new(cf.Position) * toRoad
				prop("StreetLamp", face * CFrame.new(0, 14, -0.75), lampFallback)
			end
		end
		rows[side] = tops
	end
	local function wire(a0, a1, parent, sag)
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0, b.Width1 = 0.12, 0.12
		b.Color = ColorSequence.new(Color3.fromRGB(50, 46, 46))
		b.Segments = 12
		b.CurveSize0 = -sag
		b.CurveSize1 = sag
		b.FaceCamera = true
		b.Parent = parent
	end
	-- 같은 줄 전봇대 사이 (처진 전선, Beam: 부품 없이 곡선). 빠진 전봇대는 건너뛰고 다음 것과 이음
	for _, tops in pairs(rows) do
		local prev = nil
		for i = 1, #xs do
			local t = tops[i]
			if t then
				if prev then
					wire(prev[1], t[1], prev[3], 3)
					wire(prev[2], t[2], prev[3], 3)
				end
				prev = t
			end
		end
	end
	-- 길을 가로지르는 전선 (골목 느낌)
	for i = 1, #xs do
		if rows.S[i] and rows.N[i] then
			wire(rows.S[i][2], rows.N[i][1], rows.S[i][3], 2)
		end
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
	-- 가게 사이 틈 (폭 약 8, 앞선 뒤쪽. 가게 앞 의자·입간판·노점 자리는 비움): 작은 소품 2개씩
	for k = 1, PER_ROW - 1 do
		local gx = (k - PER_ROW / 2) * P.spacing
		prop("PotBasin", CFrame.new(gx, 0.2, ROAD_Z0 - 4), potFallback)
		prop("BriquetteStack", CFrame.new(gx, 0.2, ROAD_Z0 - 8), briquetteFallback)
		prop("TrashBin", CFrame.new(gx, 0.2, ROAD_Z1 + 4), binFallback)
		prop("PlasticCrate", CFrame.new(gx, 0.2, ROAD_Z1 + 8) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), crateFallback)
	end
	-- 골목 끝 꾸미기 가게 앞 (길 가장자리)
	for _, sx in ipairs({ -1, 1 }) do
		prop("PotBasin", CFrame.new(sx * (END_X0 + 8), 0.2, ROAD_Z0 + 2), potFallback)
		prop("Mailbox", CFrame.new(sx * (END_X0 + 22), 0.2, ROAD_Z1 - 2) * CFrame.Angles(0, math.pi, 0), mailboxFallback)
		prop("Bicycle", CFrame.new(sx * (END_X0 + 34), 0.2, ROAD_Z0 + 2.5), bikeFallback)
		prop("Pyeongsang", CFrame.new(sx * (END_X0 + 20), 0.2, ROAD_ZC + 7), benchFallback) -- 골목 끝 길가 평상 (가게 사이 틈은 좁아져서 이쪽으로)
	end
end

---------------------------------------------------------------- 골목 양 끝

local function ends()
	local e = model("AlleyEnds")
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * (HALF + 2)
		-- 담벼락 (양쪽 꾸미기 가게 뒤까지), 길 가운데에 좁은 입구
		local z0, z1 = ROAD_Z0 - SHOP_DEPTH - 4, ROAD_Z1 + SHOP_DEPTH + 4
		local gapZ0, gapZ1 = ROAD_ZC - 6, ROAD_ZC + 6
		part(e, "EndWall", Vector3.new(1.2, 9, gapZ0 - z0), CFrame.new(x, 4.5, (z0 + gapZ0) / 2), C.brick, Enum.Material.Brick)
		part(e, "EndWall", Vector3.new(1.2, 9, z1 - gapZ1), CFrame.new(x, 4.5, (gapZ1 + z1) / 2), C.brick, Enum.Material.Brick)
		part(e, "WallCap", Vector3.new(1.6, 0.4, gapZ0 - z0), CFrame.new(x, 9.2, (z0 + gapZ0) / 2), C.concrete, Enum.Material.Concrete)
		part(e, "WallCap", Vector3.new(1.6, 0.4, z1 - gapZ1), CFrame.new(x, 9.2, (gapZ1 + z1) / 2), C.concrete, Enum.Material.Concrete)
		-- 입구 너머는 막아 둠 (나가지 못하게)
		part(e, "EndBlock", Vector3.new(1, 12, gapZ1 - gapZ0 + 2), CFrame.new(x + sx * 10, 6, ROAD_ZC), C.cream, Enum.Material.Plaster)
		part(e, "EndFloor", Vector3.new(10, 0.2, gapZ1 - gapZ0), CFrame.new(x + sx * 5, 0.1, ROAD_ZC), C.road, Enum.Material.Concrete)
		-- 입구 위 간판 (골목 안쪽을 봄)
		local s = part(e, "EndSign", Vector3.new(0.3, 2, 8), CFrame.new(x - sx * 0.8, 9, ROAD_ZC), C.butter, Enum.Material.Wood)
		signText(s, "달고나 골목", C.ink, sx < 0 and Enum.NormalId.Right or Enum.NormalId.Left)
		prop("TrashBin", CFrame.new(x - sx * 3, 0.2, gapZ0 - 3), binFallback)
		prop("BriquetteStack", CFrame.new(x - sx * 3, 0.2, gapZ1 + 3), briquetteFallback)
	end
end

---------------------------------------------------------------- 가게 사이 틈 담벼락 (2026-11-24 사용자: 골목 길 테두리를 따라 막음)

-- 길 앞선(z = S_FRONT / N_FRONT)에서 틈 안쪽으로 recess만큼 들어간 자리에 담: 가게 사이 틈 2곳, 끝 가게와 꾸미기 가게 사이,
-- 꾸미기 가게 줄 뒤(그 사이 좁은 틈으로 뒤로 가지 못하게, 골목 끝 담과 이어짐). 가게 3D 자체 벽이 나머지를 막음
local function gapWalls()
	local W = GrowthConfig.ShopWorld and GrowthConfig.ShopWorld.gapWall
	if not W then
		return
	end
	local m = model("GapWalls")
	local BH = W.buildingHalf
	local xs = {}
	for k = 0, PER_ROW - 1 do
		table.insert(xs, (k - (PER_ROW - 1) / 2) * P.spacing)
	end
	-- 틈 구간 [x0, x1] (가게 벽 사이)
	local gaps = {}
	for k = 1, #xs - 1 do
		table.insert(gaps, { xs[k] + BH, xs[k + 1] - BH })
	end
	table.insert(gaps, { xs[#xs] + BH, END_X0 })
	table.insert(gaps, { -END_X0, xs[1] - BH })
	local function wall(x0, x1, z)
		local len = x1 - x0 + 0.6 -- 양 끝이 벽에 살짝 묻힘
		if len < 0.5 then
			return
		end
		local cx = (x0 + x1) / 2
		part(m, "GapWall", Vector3.new(len, W.height, 1.2), CFrame.new(cx, W.height / 2, z), C.brick, Enum.Material.Brick)
		part(m, "GapWallCap", Vector3.new(len + 0.3, 0.4, 1.6), CFrame.new(cx, W.height + 0.2, z), C.concrete, Enum.Material.Concrete)
	end
	for _, side in ipairs({ "S", "N" }) do
		local front = side == "S" and ROAD_Z0 or ROAD_Z1
		local inward = side == "S" and -1 or 1 -- 길에서 멀어지는 쪽
		for _, g in ipairs(gaps) do
			wall(g[1], g[2], front + inward * W.recess)
		end
		-- 꾸미기 가게 줄 뒤 (양 끝)
		local backZ = front + inward * (SHOP_DEPTH + 0.8)
		if side == "S" then
			-- 동쪽 남쪽 첫 칸 = 골목 슈퍼 (깊이 MARKET_D): 그 칸 뒤는 더 깊게 막고, 양옆을 이어 막음
			local mw, md = marketDims()
			md = math.max(md, SHOP_DEPTH)
			local mz = front + inward * (md + 0.8)
			local mx1 = END_X0 + mw + 1
			wall(END_X0 - 0.6, mx1, mz)
			wall(mx1, HALF + 2, backZ)
			for _, x in ipairs(math.abs(mz - backZ) > 0.5 and { END_X0 - 0.6, mx1 } or {}) do
				local len = math.abs(mz - backZ)
				part(m, "GapWall", Vector3.new(1.2, W.height, len), CFrame.new(x, W.height / 2, (mz + backZ) / 2), C.brick, Enum.Material.Brick)
			end
		else
			wall(END_X0 - 0.6, HALF + 2, backZ)
		end
		wall(-(HALF + 2), -(END_X0 - 0.6), backZ)
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
	collectKeepOut()
	ground()
	endShops()
	poles()
	streetProps()
	ends()
	gapWalls()
	folder.Parent = workspace
	-- 처음 나타나는 자리: 골목 서쪽 끝 길 위 (들어오면 PlotService가 내 가게 앞으로 옮김). 예전 (0,0,0)은 북쪽 가게 안
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		spawn.CFrame = CFrame.new(-HALF + 16, 0.5, ROAD_ZC)
	end
	A.lighting()
	return folder
end

return A

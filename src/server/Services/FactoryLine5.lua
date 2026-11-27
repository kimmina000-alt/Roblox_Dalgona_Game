-- 5단계 공장 생산 라인 (2026-11-27 사용자 참고 사진 "스테인리스 달고나 생산 라인" 그대로): 코드로 부품을 세움.
--   메인 본체 = 브러시드 스테인리스 실버, 프레임·지지대 = 무광 스테인리스, 컨베이어 = 짙은 차콜 그레이,
--   호퍼 = 투명 식품용 용기 + 은색 뚜껑, 가열부 = 스테인리스 외장(둥근 지붕 솥 + 황동 압력 밸브),
--   조작 버튼 = 녹색·빨간색·흰색, 받침·발판 = 무광 블랙, 달고나 = 황금빛 갈색.
-- 사진 왼쪽 → 오른쪽: ① 호퍼 탑 → ② 가열 솥 → ③ 붓는 문틀(노즐) → ④ 프레스 탑 + 앞 조작대 → ⑤ 아이보리 냉각기(둥근 창 2개·위 황동 바퀴)
--   → ⑥ 배출 비탈 → ⑦ 결과물 통(서랍 손잡이).
-- 좌표 = 공장 부지 기준(FactoryDisplay의 부지 CFrame, 예전 Line_ 기계와 같은 자리): 라인은 +X(호퍼) → -X(결과물 통),
--   벨트 가운데 z = 20.3, 앞(조작대·사람 쪽) = -Z.
-- FactoryDisplay·FactoryClient와 잇는 이름: Fac_Console(제어대 버튼), Fac_Pt_BeltStart·Fac_Pt_BeltEnd(벨트 위 달고나 길),
--   Fac_Pt_Steam(솥 김), Fac_BeltDalgona(길이 있으면 숨기는 묶음), Fac_Output(결과물 통 바닥 — 고른 도안 달고나를 쌓음).
--   움직임 속성 Anim: hopper·kettle·nozzle·press·spin·lampRun·lampStop·lampIdle·outlet.
local MaterialService = game:GetService("MaterialService")

local Line = {}

-- 재질 그림 (4단계와 같은 MaterialVariant, 없으면 그림 id로 만듦)
local VARIANTS = {
	L4BrushedSteel1 = { Enum.Material.Metal, "126183980939358", "74367974461107", "124300364230950", "95351632890850", 4 },
	L4DarkMetal3 = { Enum.Material.Metal, "77522048138557", "73757953359407", "106895456933514", "76429474036409", 10 },
	L4IvoryEnamel1 = { Enum.Material.SmoothPlastic, "93724788559340", "113501654212416", "101639252455359", "78803892711772", 10 },
	L4Brass2 = { Enum.Material.Metal, "97520212683941", "109754973655461", "136752520439108", "138506652512418", 10 },
}
local function ensureVariants()
	for name, v in pairs(VARIANTS) do
		if not MaterialService:FindFirstChild(name, true) then
			local mv = Instance.new("MaterialVariant")
			mv.Name = name
			mv.BaseMaterial = v[1]
			mv.ColorMap = "rbxassetid://" .. v[2]
			mv.NormalMap = "rbxassetid://" .. v[3]
			mv.RoughnessMap = "rbxassetid://" .. v[4]
			mv.MetalnessMap = "rbxassetid://" .. v[5]
			mv.StudsPerTile = v[6]
			mv.Parent = MaterialService
		end
	end
end

local MAT = {
	steel = { Enum.Material.Metal, "L4BrushedSteel1", Color3.fromRGB(228, 226, 222) }, -- 본체: 브러시드 실버
	frame = { Enum.Material.Metal, "L4BrushedSteel1", Color3.fromRGB(176, 176, 176) }, -- 프레임·지지대: 무광 스테인리스
	charcoal = { Enum.Material.Metal, "L4DarkMetal3", Color3.fromRGB(58, 60, 64) }, -- 컨베이어
	belt = { Enum.Material.Rubber, nil, Color3.fromRGB(40, 42, 46) },
	black = { Enum.Material.SmoothPlastic, nil, Color3.fromRGB(26, 26, 28) }, -- 받침·발판
	ivory = { Enum.Material.SmoothPlastic, "L4IvoryEnamel1", Color3.fromRGB(242, 238, 228) },
	brass = { Enum.Material.Metal, "L4Brass2", Color3.fromRGB(244, 202, 104) }, -- 공장 조명에서 어둡게 보여서 밝게
	glass = { Enum.Material.Glass, nil, Color3.fromRGB(228, 240, 248) },
	sugar = { Enum.Material.Sand, nil, Color3.fromRGB(232, 210, 168) },
	white = { Enum.Material.SmoothPlastic, nil, Color3.fromRGB(246, 244, 238) },
	green = { Enum.Material.SmoothPlastic, nil, Color3.fromRGB(46, 164, 86) },
	red = { Enum.Material.SmoothPlastic, nil, Color3.fromRGB(210, 46, 40) },
	amber = { Enum.Material.SmoothPlastic, nil, Color3.fromRGB(240, 150, 40) },
	yellow = { Enum.Material.SmoothPlastic, nil, Color3.fromRGB(232, 196, 60) },
	dalgona = { Enum.Material.SmoothPlastic, nil, Color3.fromRGB(214, 150, 70) }, -- 황금빛 갈색
}
-- 앞을 크게 보이는 판은 결을 가로로 (부품을 앞뒤 축으로 90° 돌림)
local HBRUSH = { S5_KettleBase = true, S5_BeltFrame = true, S5_ConsoleBody = true, S5_Bin = true, S5_BinFront = true }

local function make(parent, name, size, cf, mat, props)
	local def = MAT[mat]
	if HBRUSH[name] then
		size = Vector3.new(size.Y, size.X, size.Z)
		cf = cf * CFrame.Angles(0, 0, math.rad(90))
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = def[3]
	p.Material = def[1]
	if def[2] and MaterialService:FindFirstChild(def[2], true) then
		p.MaterialVariant = def[2]
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = true
	p.CastShadow = true
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end
local function vcyl(parent, name, h, d, pos, mat, props) -- 세운 원기둥 (pos = 가운데)
	local p = make(parent, name, Vector3.new(h, d, d), pos * CFrame.Angles(0, 0, math.rad(90)), mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function fdisc(parent, name, t, d, cf, mat, props) -- 앞(-Z)을 보는 원판
	local p = make(parent, name, Vector3.new(t, d, d), cf * CFrame.Angles(0, math.rad(90), 0), mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function xcyl(parent, name, len, d, cf, mat, props) -- 라인 방향(X) 원기둥
	local p = make(parent, name, Vector3.new(len, d, d), cf, mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function ball(parent, name, d, cf, mat, props)
	local p = make(parent, name, Vector3.new(d, d, d), cf, mat, props)
	p.Shape = Enum.PartType.Ball
	return p
end
local function anim(p, key)
	p:SetAttribute("Anim", key)
	return p
end
local function mark(parent, name, cf) -- 안 보이는 자리 표시 (FactoryDisplay가 건물 속성으로 옮기고 숨김)
	make(parent, name, Vector3.new(0.3, 0.3, 0.3), cf, "white", { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
end
-- 다리 (스테인리스 기둥 + 검은 둥근 발판)
local function leg(parent, f, x, z, top)
	vcyl(parent, "S5_FootPad", 0.14, 0.95, f * CFrame.new(x, 0.07, z), "black")
	vcyl(parent, "S5_Leg", top - 0.14, 0.34, f * CFrame.new(x, 0.14 + (top - 0.14) / 2, z), "frame")
end
-- 작은 전기 상자 (경고 표시 + 위 작은 등)
local function junction(parent, f, x, y, z, yellow)
	make(parent, "S5_JunctionBox", Vector3.new(0.9, 1.0, 0.45), f * CFrame.new(x, y, z), yellow and "yellow" or "steel")
	make(parent, "S5_WarnTri", Vector3.new(0.22, 0.22, 0.02), f * CFrame.new(x, y + 0.12, z - 0.24) * CFrame.Angles(0, 0, math.rad(45)), yellow and "black" or "yellow")
	make(parent, "S5_JunctionLabel", Vector3.new(0.5, 0.12, 0.02), f * CFrame.new(x, y - 0.3, z - 0.24), "white")
end

-- f = 공장 부지 CFrame (예전 Line_ 기계가 놓인 기준과 같음). 반환: 만든 모델
function Line.build(parent, f)
	pcall(ensureVariants)
	local m = Instance.new("Model")
	m.Name = "S5_Line"
	local Z = 20.3 -- 벨트 가운데
	local beltTop = 3.2

	-- ① 호퍼 탑 (네 기둥 틀 + 투명 용기 + 은색 뚜껑 + 금색 손잡이)
	local hx = 31.5
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local x, z = hx + sx * 1.15, Z + sz * 1.15
			vcyl(m, "S5_FootPad", 0.14, 0.95, f * CFrame.new(x, 0.07, z), "black")
			make(m, "S5_HopperPost", Vector3.new(0.4, 6.0, 0.4), f * CFrame.new(x, 0.14 + 3.0, z), "frame")
		end
	end
	for _, y in ipairs({ 2.6, 6.0 }) do
		for _, sz in ipairs({ -1, 1 }) do
			make(m, "S5_HopperBeam", Vector3.new(2.7, 0.3, 0.3), f * CFrame.new(hx, y, Z + sz * 1.15), "frame")
		end
		for _, sx in ipairs({ -1, 1 }) do
			make(m, "S5_HopperBeam", Vector3.new(0.3, 0.3, 2.7), f * CFrame.new(hx + sx * 1.15, y, Z), "frame")
		end
	end
	make(m, "S5_HopperDeck", Vector3.new(2.6, 0.14, 2.6), f * CFrame.new(hx, 6.2, Z), "steel")
	vcyl(m, "S5_HopperStem", 0.7, 0.7, f * CFrame.new(hx, 6.6, Z), "steel")
	vcyl(m, "S5_HopperFunnel", 0.8, 1.6, f * CFrame.new(hx, 7.25, Z), "glass", { Transparency = 0.55, CastShadow = false })
	vcyl(m, "S5_Hopper", 2.6, 3.3, f * CFrame.new(hx, 8.95, Z), "glass", { Transparency = 0.6, CastShadow = false })
	anim(vcyl(m, "S5_HopperSugar", 1.5, 3.1, f * CFrame.new(hx, 8.35, Z), "sugar"), "hopper")
	anim(vcyl(m, "S5_HopperSugarLow", 0.7, 1.4, f * CFrame.new(hx, 7.3, Z), "sugar"), "hopper")
	vcyl(m, "S5_HopperLid", 0.28, 3.6, f * CFrame.new(hx, 10.4, Z), "steel")
	vcyl(m, "S5_HopperLidRim", 0.12, 3.7, f * CFrame.new(hx, 10.24, Z), "frame")
	vcyl(m, "S5_HopperKnobNeck", 0.3, 0.16, f * CFrame.new(hx, 10.68, Z), "brass")
	ball(m, "S5_HopperKnob", 0.45, f * CFrame.new(hx, 10.95, Z), "brass")
	junction(m, f, hx - 1.15, 3.4, Z - 1.5)
	vcyl(m, "S5_HopperLamp", 0.5, 0.18, f * CFrame.new(hx - 1.15, 4.2, Z - 1.5), "brass")
	-- 공급관 (호퍼 아래 → 솥 위)
	xcyl(m, "S5_FeedPipe", 3.6, 0.36, f * CFrame.new(hx - 2.9, 6.6, Z), "steel")
	anim(make(m, "S5_FeedPipeJoint", Vector3.new(0.5, 0.5, 0.5), f * CFrame.new(hx - 1.1, 6.6, Z), "frame"), "feed")

	-- ② 가열 솥 (스테인리스 받침 상자 + 둥근 지붕 솥 + 황동 압력 밸브 + 경고 표시)
	local kx = 25.6
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			leg(m, f, kx + sx * 2.1, Z + sz * 1.5, 0.9)
		end
	end
	make(m, "S5_KettleBase", Vector3.new(5.2, 1.6, 3.6), f * CFrame.new(kx, 0.9 + 0.8, Z), "steel")
	make(m, "S5_KettleBaseRim", Vector3.new(5.35, 0.12, 3.75), f * CFrame.new(kx, 2.56, Z), "frame")
	junction(m, f, kx - 1.2, 1.7, Z - 1.95)
	junction(m, f, kx + 0.4, 1.7, Z - 1.95)
	local kettle = vcyl(m, "S5_Kettle", 2.3, 4.4, f * CFrame.new(kx, 2.62 + 1.15, Z), "steel")
	anim(kettle, "kettle")
	anim(vcyl(m, "S5_KettleBand", 0.18, 4.5, f * CFrame.new(kx, 2.62 + 0.55, Z), "frame"), "kettle")
	anim(vcyl(m, "S5_KettleBand", 0.18, 4.5, f * CFrame.new(kx, 2.62 + 2.2, Z), "frame"), "kettle")
	local dome = make(m, "S5_KettleDome", Vector3.new(4.4, 2.2, 4.4), f * CFrame.new(kx, 4.92, Z), "steel")
	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.Sphere
	sm.Parent = dome
	anim(dome, "kettle")
	vcyl(m, "S5_ValveNeck", 0.9, 0.4, f * CFrame.new(kx, 6.3, Z), "brass")
	ball(m, "S5_ValveBall", 0.55, f * CFrame.new(kx, 6.8, Z), "brass")
	make(m, "S5_ValveBar", Vector3.new(1.6, 0.14, 0.14), f * CFrame.new(kx, 7.05, Z), "brass")
	for _, sx in ipairs({ -1, 1 }) do
		vcyl(m, "S5_ValveHandle", 0.4, 0.16, f * CFrame.new(kx + sx * 0.8, 7.25, Z), "black")
	end
	mark(m, "Fac_Pt_Steam", f * CFrame.new(kx, 7.3, Z))
	-- 솥 앞 경고 표시 (흰 판 + 노란 삼각)
	for i = 0, 2 do
		local x = kx - 0.9 + i * 0.75
		make(m, "S5_KettleLabel", Vector3.new(0.6, 0.5, 0.04), f * CFrame.new(x, 4.3, Z - 2.2), "white")
		make(m, "S5_WarnTri", Vector3.new(0.22, 0.22, 0.02), f * CFrame.new(x, 4.3, Z - 2.23) * CFrame.Angles(0, 0, math.rad(45)), i == 1 and "red" or "yellow")
	end
	-- 솥 → 벨트 출구 관
	xcyl(m, "S5_KettleOut", 1.2, 0.4, f * CFrame.new(kx - 2.6, 3.6, Z), "frame")

	-- ③ 컨베이어 (짙은 차콜 벨트 + 스테인리스 틀 + 다리)
	local x0, x1 = 23.0, 3.6 -- 벨트 시작(솥 쪽) · 끝(배출 쪽)
	local len, mid = x0 - x1, (x0 + x1) / 2
	make(m, "S5_BeltFrame", Vector3.new(len, 0.55, 2.8), f * CFrame.new(mid, beltTop - 0.35, Z), "steel")
	make(m, "S5_BeltBed", Vector3.new(len, 0.1, 2.3), f * CFrame.new(mid, beltTop - 0.04, Z), "charcoal")
	make(m, "S5_Belt", Vector3.new(len - 0.2, 0.06, 2.1), f * CFrame.new(mid, beltTop + 0.02, Z), "belt")
	for _, sz in ipairs({ -1, 1 }) do
		make(m, "S5_BeltRail", Vector3.new(len, 0.22, 0.12), f * CFrame.new(mid, beltTop + 0.08, Z + sz * 1.2), "frame")
	end
	for _, x in ipairs({ x0 - 0.6, 17.0, 11.0, 6.0, x1 + 0.6 }) do
		for _, sz in ipairs({ -1, 1 }) do
			leg(m, f, x, Z + sz * 1.0, beltTop - 0.62)
		end
	end
	junction(m, f, 10.6, 1.9, Z - 1.6, true)
	junction(m, f, 5.3, 1.9, Z - 1.6)
	mark(m, "Fac_Pt_BeltStart", f * CFrame.new(x0 - 0.6, beltTop + 0.1, Z))
	mark(m, "Fac_Pt_BeltEnd", f * CFrame.new(x1 + 0.3, beltTop + 0.1, Z))
	for i = 0, 5 do
		local x = x0 - 1.5 - i * (len - 3) / 5
		vcyl(m, "Fac_BeltDalgona", 0.1, 1.25, f * CFrame.new(x, beltTop + 0.1, Z), "dalgona", { CanCollide = false })
	end

	-- ④ 붓는 문틀 (기둥 2개 + 윗보 + 금색 공 + 황동 노즐)
	local dx = 20.6
	for _, sz in ipairs({ -1, 1 }) do
		make(m, "S5_GantryPost", Vector3.new(0.5, 5.0, 0.5), f * CFrame.new(dx, beltTop + 2.5, Z + sz * 1.55), "frame")
		ball(m, "S5_GantryKnob", 0.42, f * CFrame.new(dx, beltTop + 5.55, Z + sz * 1.55), "brass")
	end
	make(m, "S5_GantryBeam", Vector3.new(0.7, 0.55, 3.7), f * CFrame.new(dx, beltTop + 5.0, Z), "steel")
	make(m, "S5_GantryCap", Vector3.new(0.85, 0.1, 3.9), f * CFrame.new(dx, beltTop + 5.32, Z), "frame")
	local noz = make(m, "S5_Nozzle", Vector3.new(0.7, 1.1, 0.7), f * CFrame.new(dx, beltTop + 3.0, Z), "steel")
	anim(noz, "nozzle")
	anim(vcyl(m, "S5_NozzleRod", 1.3, 0.22, f * CFrame.new(dx, beltTop + 4.1, Z), "brass"), "nozzle")
	anim(vcyl(m, "S5_NozzleTip", 0.35, 0.28, f * CFrame.new(dx, beltTop + 2.3, Z), "brass"), "nozzle")

	-- ⑤ 프레스 탑 (넓은 기둥 2개 + 윗 상자 + 금색 공 + 오르내리는 머리)
	local px = 14.2
	for _, sz in ipairs({ -1, 1 }) do
		make(m, "S5_PressColumn", Vector3.new(1.3, 8.2, 0.8), f * CFrame.new(px, 0.14 + 4.1, Z + sz * 1.75), "steel")
		vcyl(m, "S5_FootPad", 0.14, 1.2, f * CFrame.new(px, 0.07, Z + sz * 1.75), "black")
		make(m, "S5_PressColumnSeam", Vector3.new(1.32, 0.05, 0.82), f * CFrame.new(px, 4.6, Z + sz * 1.75), "frame")
	end
	make(m, "S5_PressTop", Vector3.new(2.2, 1.0, 4.4), f * CFrame.new(px, 8.85, Z), "steel")
	make(m, "S5_PressTopCap", Vector3.new(2.5, 0.16, 4.7), f * CFrame.new(px, 9.42, Z), "frame")
	ball(m, "S5_PressKnob", 0.5, f * CFrame.new(px, 9.8, Z - 1.6), "brass")
	anim(make(m, "S5_PressHead", Vector3.new(1.9, 1.1, 2.5), f * CFrame.new(px, 5.4, Z), "steel"), "press")
	anim(make(m, "S5_PressStamps", Vector3.new(1.7, 0.16, 2.2), f * CFrame.new(px, 4.77, Z), "charcoal"), "press")
	anim(vcyl(m, "S5_PressRod", 2.4, 0.3, f * CFrame.new(px, 7.15, Z), "brass"), "press")
	make(m, "S5_PressLabel", Vector3.new(0.7, 0.4, 0.04), f * CFrame.new(px, 6.6, Z - 2.17), "white")

	-- ⑥ 앞 조작대 (스테인리스 상자 + 기울어진 판: 계기 3개, 녹색·흰색·빨간색 버튼, 주황 등)
	local cx, cz = 15.3, 16.5
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			vcyl(m, "S5_FootPad", 0.1, 0.5, f * CFrame.new(cx + sx * 1.6, 0.05, cz + sz * 0.5), "black")
		end
	end
	make(m, "S5_ConsoleBody", Vector3.new(3.6, 2.4, 1.3), f * CFrame.new(cx, 0.1 + 1.2, cz), "steel")
	make(m, "S5_ConsoleDrawer", Vector3.new(3.0, 0.8, 0.06), f * CFrame.new(cx, 0.75, cz - 0.68), "frame")
	make(m, "S5_ConsoleHandle", Vector3.new(1.0, 0.1, 0.1), f * CFrame.new(cx, 0.85, cz - 0.75), "frame")
	local tilt = f * CFrame.new(cx, 2.75, cz + 0.05) * CFrame.Angles(math.rad(-30), 0, 0)
	make(m, "Fac_Console", Vector3.new(3.7, 0.16, 1.5), tilt, "steel")
	local function onPanel(x, z)
		return tilt * CFrame.new(x, 0.08, z)
	end
	for i, x in ipairs({ -1.2, 0, 1.2 }) do
		local c = onPanel(x, 0.35)
		make(m, "S5_GaugeRim", Vector3.new(0.06, 0.62, 0.62), c * CFrame.Angles(0, 0, math.rad(90)), "frame", { Shape = Enum.PartType.Cylinder })
		make(m, "S5_Gauge", Vector3.new(0.07, 0.5, 0.5), c * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)), "white", { Shape = Enum.PartType.Cylinder })
		make(m, "S5_GaugeNeedle", Vector3.new(0.03, 0.02, 0.2), c * CFrame.new(0, 0.06, -0.04) * CFrame.Angles(0, math.rad(30 * i), 0), "black")
	end
	local btns = { { -1.3, "green", "lampRun", "Fac_StartButton" }, { -0.65, "white", nil, "S5_ButtonWhite" }, { 0, "green", nil, "S5_ButtonGreen2" }, { 0.65, "red", "lampStop", "Fac_StopButton" }, { 1.3, "amber", "lampIdle", "S5_LampIdle" } }
	for _, b in ipairs(btns) do
		local c = onPanel(b[1], -0.35)
		make(m, b[4] .. "Ring", Vector3.new(0.05, 0.36, 0.36), c * CFrame.Angles(0, 0, math.rad(90)), "frame", { Shape = Enum.PartType.Cylinder })
		local p = make(m, b[4], Vector3.new(0.12, 0.26, 0.26), c * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), b[2], { Shape = Enum.PartType.Cylinder })
		if b[3] then
			anim(p, b[3])
		end
	end
	-- 조작대 옆 비상 정지 상자
	make(m, "S5_EStopBox", Vector3.new(0.6, 0.8, 0.4), f * CFrame.new(cx + 2.1, 2.0, cz), "steel")
	fdisc(m, "S5_EStop", 0.12, 0.34, f * CFrame.new(cx + 2.1, 2.1, cz - 0.24), "red")
	fdisc(m, "S5_EStopG", 0.1, 0.2, f * CFrame.new(cx + 2.1, 1.8, cz - 0.22), "green")

	-- ⑦ 아이보리 냉각기 (둥근 상자 + 앞 둥근 창 2개 + 위 황동 바퀴, 벨트가 아래로 지나감)
	local ux = 7.8
	local uw, uh, ud = 3.6, 2.6, 2.9
	local uy = beltTop + 0.35 + uh / 2
	local r = 0.5
	make(m, "S5_Cooler", Vector3.new(uw - 2 * r, uh, ud), f * CFrame.new(ux, uy, Z), "ivory")
	make(m, "S5_Cooler", Vector3.new(uw, uh - 2 * r, ud), f * CFrame.new(ux, uy, Z), "ivory")
	make(m, "S5_Cooler", Vector3.new(uw, uh, ud - 2 * r), f * CFrame.new(ux, uy, Z), "ivory")
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			make(m, "S5_CoolerEdge", Vector3.new(ud - 2 * r, 2 * r, 2 * r), f * CFrame.new(ux + sx * (uw / 2 - r), uy + sy * (uh / 2 - r), Z) * CFrame.Angles(0, math.rad(90), 0), "ivory", { Shape = Enum.PartType.Cylinder })
		end
		for _, sz in ipairs({ -1, 1 }) do
			vcyl(m, "S5_CoolerEdge", uh - 2 * r, 2 * r, f * CFrame.new(ux + sx * (uw / 2 - r), uy, Z + sz * (ud / 2 - r)), "ivory")
			for _, sy in ipairs({ -1, 1 }) do
				ball(m, "S5_CoolerCorner", 2 * r, f * CFrame.new(ux + sx * (uw / 2 - r), uy + sy * (uh / 2 - r), Z + sz * (ud / 2 - r)), "ivory")
			end
		end
	end
	for _, sy in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			make(m, "S5_CoolerEdge", Vector3.new(uw - 2 * r, 2 * r, 2 * r), f * CFrame.new(ux, uy + sy * (uh / 2 - r), Z + sz * (ud / 2 - r)), "ivory", { Shape = Enum.PartType.Cylinder })
		end
	end
	for _, sx in ipairs({ -0.8, 0.8 }) do
		local c = f * CFrame.new(ux + sx, uy - 0.1, Z - ud / 2)
		fdisc(m, "S5_PortholeRing", 0.14, 1.1, c * CFrame.new(0, 0, -0.04), "frame")
		fdisc(m, "S5_Porthole", 0.1, 0.85, c * CFrame.new(0, 0, -0.08), "glass", { Transparency = 0.3 })
	end
	fdisc(m, "S5_CoolerSideRing", 0.12, 0.9, f * CFrame.new(ux - uw / 2 - 0.02, uy, Z) * CFrame.Angles(0, math.rad(90), 0), "frame")
	vcyl(m, "S5_WheelBase", 0.16, 1.2, f * CFrame.new(ux, uy + uh / 2 + 0.08, Z), "frame")
	local wheel = vcyl(m, "S5_Wheel", 0.12, 1.5, f * CFrame.new(ux, uy + uh / 2 + 0.22, Z), "brass")
	anim(wheel, "spin")
	for k = 0, 1 do
		anim(make(m, "S5_WheelSpoke", Vector3.new(1.4, 0.08, 0.1), f * CFrame.new(ux, uy + uh / 2 + 0.3, Z) * CFrame.Angles(0, math.rad(k * 90), 0), "brass"), "spin")
	end
	anim(vcyl(m, "S5_WheelHub", 0.16, 0.3, f * CFrame.new(ux, uy + uh / 2 + 0.32, Z), "brass"), "spin")

	-- ⑧ 배출 비탈 (짙은 차콜) + 결과물 통 (스테인리스, 서랍 손잡이) + 옆 작은 기둥
	local slope = math.rad(35)
	local chute = make(m, "S5_Chute", Vector3.new(2.2, 0.1, 1.9), f * CFrame.new(x1 - 0.8, beltTop - 0.7, Z) * CFrame.Angles(0, 0, slope), "charcoal")
	anim(chute, "outlet")
	for _, sz in ipairs({ -1, 1 }) do
		make(m, "S5_ChuteSide", Vector3.new(2.2, 0.45, 0.08), f * CFrame.new(x1 - 0.8, beltTop - 0.55, Z + sz * 0.98) * CFrame.Angles(0, 0, slope), "charcoal")
	end
	local bx = 0.6
	local bTop = 2.3
	make(m, "S5_Bin", Vector3.new(2.6, 0.12, 2.6), f * CFrame.new(bx, 0.9, Z), "steel")
	make(m, "S5_BinFront", Vector3.new(2.6, 1.4, 0.1), f * CFrame.new(bx, 0.9 + 0.7, Z - 1.3), "steel")
	make(m, "S5_BinWall", Vector3.new(2.6, 1.4, 0.1), f * CFrame.new(bx, 0.9 + 0.7, Z + 1.3), "steel")
	make(m, "S5_BinWall", Vector3.new(0.1, 1.4, 2.6), f * CFrame.new(bx - 1.3, 0.9 + 0.7, Z), "steel")
	make(m, "S5_BinWall", Vector3.new(0.1, 1.4, 2.6), f * CFrame.new(bx + 1.3, 0.9 + 0.7, Z), "steel")
	make(m, "S5_BinBack", Vector3.new(2.4, 1.2, 0.08), f * CFrame.new(bx, bTop + 0.6, Z + 1.25) * CFrame.Angles(math.rad(-12), 0, 0), "steel")
	make(m, "S5_BinHandle", Vector3.new(0.8, 0.1, 0.1), f * CFrame.new(bx, 1.4, Z - 1.42), "frame")
	for _, sx in ipairs({ -1, 1 }) do
		make(m, "S5_BinHandleLeg", Vector3.new(0.08, 0.1, 0.16), f * CFrame.new(bx + sx * 0.38, 1.4, Z - 1.37), "frame")
		for _, sz in ipairs({ -1, 1 }) do
			leg(m, f, bx + sx * 1.0, Z + sz * 1.0, 0.85)
		end
	end
	-- 결과물 자리 (클라이언트가 고른 도안 달고나를 쌓음, 처음엔 황금빛 달고나 더미)
	make(m, "Fac_Output", Vector3.new(2.2, 0.35, 2.2), f * CFrame.new(bx, 1.2, Z), "dalgona", { CanCollide = false })
	-- 옆 작은 기둥 상자 + 금색 공 (사진 오른쪽 끝)
	leg(m, f, bx - 2.0, Z - 0.6, 2.6)
	make(m, "S5_SidePostBox", Vector3.new(0.7, 1.0, 0.5), f * CFrame.new(bx - 2.0, 2.4, Z - 0.6), "steel")
	ball(m, "S5_SidePostKnob", 0.4, f * CFrame.new(bx - 2.0, 3.2, Z - 0.6), "brass")
	vcyl(m, "S5_SidePostRod", 0.6, 0.12, f * CFrame.new(bx - 2.0, 2.95, Z - 0.6), "frame")

	m.Parent = parent
	return m
end

return Line

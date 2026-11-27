-- 가게 기계 1자리 모습 (20번 기계 2~4단계, 2026-11-21)
-- 서버 생산 로직(GrowthService, 저장·부지 세션)이 부지의 MachineSlot 파트에 속성을 쓰고, 여기서는 모습만 맞춘다.
--   MachineSlot 속성: Stage(1 없음·2 철제 판매기·3 분홍 자판기·4 연속 생산 설비), MachineId, Running, Status, Shape,
--   CycleStart·CycleSeconds, MadeAt·MadeCount·MadeSlots → 움직임·배출·진열 연출은 클라이언트 MachineClient가 그림
-- 모델은 부지 모델 바로 아래 "Machine" (앞 = 골목 쪽). 부품 속성 Anim으로 클라이언트가 움직일 곳을 찾음:
--   "spin"(돌아감) · "press"(위아래) · "lampRun"(돌 때 켜짐) · "lampStop"(멈추면 빨강) · "outlet"(배출구) · "window"(창 속 달고나)
-- 기계 앞에 ProximityPrompt "MachinePrompt" (주인만 보임: 클라이언트가 숨김) → 도안 고르기·다음 기계 사기 화면
--
-- D32 (2026-11-23, 기계 쌓기): 단계마다 고정 자리 MachineSlot2·3·4 (PlotService). 산 기계는 모두 자기 자리에 남아 같이 돎.
--   슬롯 속성 Owned = 샀는지, Stage = 샀으면 그 단계 번호(아니면 1), SlotStage = 자리 번호. 모델 = Plot.Machine<n>
--   (속성 Stage·SlotName, 프롬프트 속성 MachineStage = n). 아직 안 산 다음 단계 자리에는 "기계 보기" 안내만 둠.
--   새 슬롯이 있으면 옛 MachineSlot(가장 높은 단계 하나)은 그리지 않음

local ServerStorage = game:GetService("ServerStorage")
local PROMPT_DISTANCE = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GrowthConfig")).PromptDistance or 6 -- 기계·가구 버튼이 뜨는 거리 (2026-11-24)

local FactoryBuilder = require(script.Parent:WaitForChild("FactoryBuilder"))

local Display = {}

local function part(parent, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = true
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function cyl(parent, name, len, dia, cf, color, props)
	-- 원기둥 길이 축 = X. cf는 가운데, 기본은 위(+Y)로 세움
	local p = part(parent, name, Vector3.new(len, dia, dia), cf * CFrame.Angles(0, 0, math.rad(90)), color, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local DALGONA = Color3.fromRGB(222, 156, 76)

-- 작은 달고나 하나 (창 속 진열·배출구용): 납작한 원기둥 + 별 자국 대신 진한 점
local function miniDalgona(parent, name, cf, d)
	local p = cyl(parent, name, 0.06, d, cf, DALGONA)
	part(parent, name .. "Mark", Vector3.new(d * 0.28, 0.01, d * 0.28), cf * CFrame.new(0, -0.035, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(150, 90, 40))
	return p
end

-- 2단계 철제 판매기: 낡은 회색 금속 상자 + 유리창(달고나 3줄) + 동전 넣는 곳 + 아래 배출구 + 위 빨간 표시등
local function buildSteel(m, base)
	local W, D, H = 3.4, 2.4, 5.2
	local steel = Color3.fromRGB(150, 156, 160)
	local dark = Color3.fromRGB(80, 84, 90)
	part(m, "Body", Vector3.new(W, H, D), base * CFrame.new(0, H / 2, 0), steel, { Material = Enum.Material.DiamondPlate })
	part(m, "Roof", Vector3.new(W + 0.2, 0.25, D + 0.2), base * CFrame.new(0, H + 0.12, 0), dark, { Material = Enum.Material.Metal })
	part(m, "Plinth", Vector3.new(W + 0.1, 0.3, D + 0.1), base * CFrame.new(0, 0.15, 0), dark, { Material = Enum.Material.Metal })
	-- 앞 = -Z
	local front = base * CFrame.new(0, 0, -D / 2)
	part(m, "WindowFrame", Vector3.new(W - 0.6, 2.7, 0.1), front * CFrame.new(-0.3, 3.2, -0.04), dark, { Material = Enum.Material.Metal })
	part(m, "Window", Vector3.new(W - 0.85, 2.45, 0.06), front * CFrame.new(-0.3, 3.2, -0.26), Color3.fromRGB(210, 235, 245), { Material = Enum.Material.Glass, Transparency = 0.78 })
	for row = 0, 2 do
		local y = 2.3 + row * 0.8
		-- 창과 몸통 사이 얕은 칸에 달고나를 세워 둠 (몸통 안쪽에 넣으면 안 보임)
		part(m, "Shelf", Vector3.new(W - 0.9, 0.06, 0.2), front * CFrame.new(-0.3, y - 0.27, -0.12), dark)
		for col = -1, 1 do
			local p = miniDalgona(m, "WindowDalgona", front * CFrame.new(-0.3 + col * 0.75, y, -0.15) * CFrame.Angles(math.rad(80), 0, 0), 0.55)
			p:SetAttribute("Anim", "window")
		end
	end
	-- 오른쪽 조작판: 동전 넣는 곳 · 단추 · 표시등
	part(m, "Panel", Vector3.new(0.5, 2.4, 0.08), front * CFrame.new(W / 2 - 0.42, 3.2, -0.05), Color3.fromRGB(60, 62, 66))
	part(m, "CoinSlot", Vector3.new(0.08, 0.35, 0.06), front * CFrame.new(W / 2 - 0.42, 3.8, -0.1), Color3.fromRGB(20, 20, 20))
	for i = 0, 2 do
		cyl(m, "Button", 0.08, 0.22, front * CFrame.new(W / 2 - 0.42, 3.2 - i * 0.35, -0.1) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(230, 200, 80), { Material = Enum.Material.Neon })
	end
	local lamp = cyl(m, "LampRun", 0.25, 0.4, base * CFrame.new(-0.8, H + 0.38, -D / 2 + 0.4), Color3.fromRGB(90, 200, 110), { Material = Enum.Material.Neon })
	lamp:SetAttribute("Anim", "lampRun")
	local stop = cyl(m, "LampStop", 0.25, 0.4, base * CFrame.new(0.8, H + 0.38, -D / 2 + 0.4), Color3.fromRGB(220, 60, 50), { Material = Enum.Material.Neon })
	stop:SetAttribute("Anim", "lampStop")
	-- 배출구 (아래)
	part(m, "Outlet", Vector3.new(1.6, 0.7, 0.3), front * CFrame.new(-0.3, 0.9, -0.12), Color3.fromRGB(35, 35, 40)):SetAttribute("Anim", "outlet")
	part(m, "OutletFlap", Vector3.new(1.5, 0.6, 0.05), front * CFrame.new(-0.3, 0.92, -0.3), Color3.fromRGB(200, 220, 230), { Material = Enum.Material.Glass, Transparency = 0.5 })
	-- 옆 손잡이 톱니 (돌아감)
	local gear = cyl(m, "Gear", 0.15, 1.0, base * CFrame.new(W / 2 + 0.08, 1.9, 0) * CFrame.Angles(0, 0, math.rad(-90)), Color3.fromRGB(190, 150, 70), { Material = Enum.Material.Metal })
	gear:SetAttribute("Anim", "spin")
	part(m, "Sign", Vector3.new(W - 0.4, 0.6, 0.08), front * CFrame.new(0, H - 0.45, -0.06), Color3.fromRGB(240, 230, 210))
	return W, D, H
end

-- 3단계 분홍 자판기: 둥근 분홍 상자 + 큰 창(달고나 4×3) + 반짝이 단추 + 위 하트 간판 + 배출구
local function buildPink(m, base)
	local W, D, H = 4.0, 2.6, 5.8
	local pink = Color3.fromRGB(255, 170, 200)
	local cream = Color3.fromRGB(255, 244, 236)
	part(m, "Body", Vector3.new(W, H, D), base * CFrame.new(0, H / 2, 0), pink)
	-- 둥근 모서리 느낌: 옆 기둥
	for _, s in ipairs({ -1, 1 }) do
		cyl(m, "Corner", H, 0.7, base * CFrame.new(s * W / 2, H / 2, -D / 2 + 0.35), pink)
	end
	local front = base * CFrame.new(0, 0, -D / 2)
	part(m, "WindowFrame", Vector3.new(W - 1.2, 3.2, 0.1), front * CFrame.new(-0.4, 3.4, -0.04), cream)
	part(m, "Window", Vector3.new(W - 1.45, 2.95, 0.06), front * CFrame.new(-0.4, 3.4, -0.26), Color3.fromRGB(225, 240, 255), { Material = Enum.Material.Glass, Transparency = 0.78 })
	for row = 0, 2 do
		local y = 2.35 + row * 0.95
		part(m, "Shelf", Vector3.new(W - 1.5, 0.06, 0.2), front * CFrame.new(-0.4, y - 0.3, -0.12), Color3.fromRGB(255, 214, 228))
		for col = 0, 3 do
			local p = miniDalgona(m, "WindowDalgona", front * CFrame.new(-0.4 - 1.05 + col * 0.7, y, -0.15) * CFrame.Angles(math.rad(80), 0, 0), 0.55)
			p:SetAttribute("Anim", "window")
		end
	end
	-- 오른쪽 단추판 (사탕 단추)
	part(m, "Panel", Vector3.new(0.75, 3.0, 0.08), front * CFrame.new(W / 2 - 0.55, 3.3, -0.05), cream)
	local candy = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 220, 90), Color3.fromRGB(140, 220, 140) }
	for i = 0, 3 do
		cyl(m, "Button", 0.1, 0.32, front * CFrame.new(W / 2 - 0.55, 4.3 - i * 0.55, -0.12) * CFrame.Angles(math.rad(90), 0, 0), candy[i + 1], { Material = Enum.Material.Neon })
	end
	-- 위 하트 간판 + 표시등
	part(m, "Roof", Vector3.new(W + 0.3, 0.3, D + 0.3), base * CFrame.new(0, H + 0.15, 0), cream)
	local heart = part(m, "SignHeart", Vector3.new(1.3, 1.3, 0.25), base * CFrame.new(0, H + 1.0, -D / 2 + 0.4) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(255, 90, 140), { Material = Enum.Material.Neon })
	heart:SetAttribute("Anim", "lampRun")
	local stop = cyl(m, "LampStop", 0.25, 0.4, base * CFrame.new(W / 2 - 0.4, H + 0.45, -D / 2 + 0.4), Color3.fromRGB(220, 60, 50), { Material = Enum.Material.Neon })
	stop:SetAttribute("Anim", "lampStop")
	-- 배출구
	part(m, "Outlet", Vector3.new(2.0, 0.8, 0.3), front * CFrame.new(-0.4, 0.95, -0.12), Color3.fromRGB(120, 60, 80)):SetAttribute("Anim", "outlet")
	part(m, "OutletFlap", Vector3.new(1.9, 0.7, 0.05), front * CFrame.new(-0.4, 0.97, -0.3), Color3.fromRGB(255, 230, 240), { Material = Enum.Material.Glass, Transparency = 0.45 })
	-- 위 바람개비 (돌아감)
	local fan = part(m, "Pinwheel", Vector3.new(0.9, 0.9, 0.06), base * CFrame.new(-W / 2 + 0.5, H + 0.9, -D / 2 + 0.4) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(255, 240, 120), { Material = Enum.Material.Neon })
	fan:SetAttribute("Anim", "spin")
	fan:SetAttribute("Axis", "Z")
	part(m, "Plinth", Vector3.new(W + 0.2, 0.3, D + 0.2), base * CFrame.new(0, 0.15, 0), Color3.fromRGB(230, 130, 165))
	return W, D, H
end

-- 4단계 연속 생산 설비 (2026-11-27 사용자 참고 사진 "스테인리스 달고나 설비" 그대로): 코드로 부품을 세움.
--   본체·상판 = 브러시드 스테인리스, 투입 호퍼 = 투명 용기 + 금속 뚜껑, 가열 장치 = 원통 스테인리스 통(게이지·황동 띠),
--   프레스 = 은색 기둥 틀 + 구리 내열판(경고 표시), 원통형 가공 장치 = 아이보리 외장(황동 둥근 창·위 바퀴),
--   컨베이어·배출 트레이 = 짙은 회색 금속, 조작 버튼 = 흰색·녹색·빨간색.
--   재질은 MaterialService의 MaterialVariant(L4BrushedSteel·L4DarkMetal·L4IvoryEnamel·L4Copper·L4Brass, Studio에서 만든 재질 그림)를
--   쓰고, 없으면 기본 재질(Metal 등)만. 앞 = -Z(골목 쪽), 사진 왼쪽(호퍼) = +X, 오른쪽(배출 트레이) = -X.
--   움직임 속성(Anim): 프레스 머리 "press", 위 황동 바퀴 "spin", 녹색 버튼 "lampRun", 빨간 버튼 "lampStop",
--   배출 트레이 "outlet", 컨베이어 위 달고나 "window".
local MaterialService = game:GetService("MaterialService")
-- 재질 그림 (2026-11-27 Studio Assistant generate_material로 만들어 고른 것: 색·노멀·거칠기·금속도 맵). 장소에 없으면 여기서 만듦
local VARIANTS = {
	L4BrushedSteel1 = { Enum.Material.Metal, "126183980939358", "74367974461107", "124300364230950", "95351632890850", 4 }, -- 브러시드 스테인리스 (결이 고와 보이게 4스터드마다)
	L4DarkMetal3 = { Enum.Material.Metal, "77522048138557", "73757953359407", "106895456933514", "76429474036409" }, -- 짙은 회색 금속
	L4IvoryEnamel1 = { Enum.Material.SmoothPlastic, "93724788559340", "113501654212416", "101639252455359", "78803892711772" }, -- 아이보리 에나멜
	L4Copper1 = { Enum.Material.Metal, "98471565198791", "111177067718235", "88551992084176", "102019088793321" }, -- 구리 내열판
	L4Brass2 = { Enum.Material.Metal, "97520212683941", "109754973655461", "136752520439108", "138506652512418" }, -- 황동
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
			mv.StudsPerTile = v[6] or 10
			mv.Parent = MaterialService
		end
	end
end
local MAT = {
	steel = { Enum.Material.Metal, "L4BrushedSteel1", Color3.fromRGB(226, 223, 218) },
	steelDark = { Enum.Material.Metal, "L4BrushedSteel1", Color3.fromRGB(182, 180, 178) },
	dark = { Enum.Material.Metal, "L4DarkMetal3", Color3.fromRGB(70, 72, 78) },
	ivory = { Enum.Material.SmoothPlastic, "L4IvoryEnamel1", Color3.fromRGB(242, 236, 220) },
	-- 구리: 만든 재질 그림(L4Copper1)은 붉게 나와서 사진처럼 밝은 주황 구리는 기본 금속 + 색 (국자 구리색과 비슷하게)
	copper = { Enum.Material.Metal, nil, Color3.fromRGB(218, 134, 74) },
	brass = { Enum.Material.Metal, "L4Brass2", Color3.fromRGB(214, 168, 78) },
	glass = { Enum.Material.Glass, nil, Color3.fromRGB(226, 238, 246) },
	sugar = { Enum.Material.Sand, nil, Color3.fromRGB(236, 222, 196) },
	white = { Enum.Material.SmoothPlastic, nil, Color3.fromRGB(244, 240, 230) },
	green = { Enum.Material.SmoothPlastic, nil, Color3.fromRGB(46, 160, 84) },
	red = { Enum.Material.SmoothPlastic, nil, Color3.fromRGB(206, 44, 40) },
	yellow = { Enum.Material.SmoothPlastic, nil, Color3.fromRGB(246, 200, 40) },
	black = { Enum.Material.SmoothPlastic, nil, Color3.fromRGB(30, 30, 32) },
	dalgona = { Enum.Material.SmoothPlastic, nil, Color3.fromRGB(226, 166, 88) },
}
local function hasVariant(name)
	return name ~= nil and MaterialService:FindFirstChild(name, true) ~= nil
end
-- 앞을 크게 보이는 판은 재질 결(세로)을 가로로 눕힘 (사진: 가로 브러시 결) — 부품을 앞뒤 축으로 90° 돌리고 크기 X·Y를 바꿈
local HBRUSH = { S4_Cabinet = true, S4_BeltBed = true, S4_ControlFace = true, S4_ControlPanel = true, S4_Skirt = true, S4_TopPlate = true }
local function lp(m, name, size, cf, mat, props)
	local def = MAT[mat]
	if HBRUSH[name] then
		size = Vector3.new(size.Y, size.X, size.Z)
		cf = cf * CFrame.Angles(0, 0, math.rad(90))
	end
	local p = part(m, name, size, cf, def[3], props)
	p.Material = def[1]
	if hasVariant(def[2]) then
		p.MaterialVariant = def[2]
	end
	if props and props.Material then -- 따로 준 재질이 먼저 (벨트 = 고무)
		p.Material = props.Material
		p.MaterialVariant = ""
	end
	return p
end
local function lc(m, name, len, dia, cf, mat, props) -- 세운 원기둥 (길이 = 위아래)
	local p = lp(m, name, Vector3.new(len, dia, dia), cf * CFrame.Angles(0, 0, math.rad(90)), mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function lf(m, name, len, dia, cf, mat, props) -- 앞(-Z)을 보는 원판 (길이 = 앞뒤 두께)
	local p = lp(m, name, Vector3.new(len, dia, dia), cf * CFrame.Angles(0, math.rad(90), 0), mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local LINE_SCALE = 1.5 -- 2026-11-28 사용자 "4·5단계 기계 1.5배 키우기"
local function buildLine(m, base)
	pcall(ensureVariants)
	local top0 = base
	-- 배출 트레이가 -X로 1.75 나와서 전체(약 8.4) 가운데를 자리 가운데에 맞춤
	base = base * CFrame.new(0.8, 0, 0)
	local W, D = 6.6, 2.4 -- 본체 상자
	local FOOT = 0.25
	local bodyH = 2.3
	local topY = FOOT + bodyH -- 상판 아랫면
	local plateT = 0.12
	local deck = topY + plateT -- 상판 윗면
	-- 발 (짙은 금속 원판 + 스테인리스 기둥)
	for _, x in ipairs({ -W / 2 + 0.35, 0, W / 2 - 0.35 }) do
		for _, z in ipairs({ -D / 2 + 0.3, D / 2 - 0.3 }) do
			lc(m, "S4_Foot", 0.08, 0.42, base * CFrame.new(x, 0.04, z), "dark")
			lc(m, "S4_FootLeg", FOOT - 0.08, 0.2, base * CFrame.new(x, 0.08 + (FOOT - 0.08) / 2, z), "steelDark")
		end
	end
	-- 본체 (브러시드 스테인리스 상자) + 아래 띠 + 모서리 기둥
	lp(m, "S4_Cabinet", Vector3.new(W, bodyH, D), base * CFrame.new(0, FOOT + bodyH / 2, 0), "steel")
	lp(m, "S4_Skirt", Vector3.new(W + 0.04, 0.12, D + 0.04), base * CFrame.new(0, FOOT + 0.06, 0), "steelDark")
	for _, sx in ipairs({ -1, 1 }) do
		lp(m, "S4_CornerPost", Vector3.new(0.1, bodyH, 0.1), base * CFrame.new(sx * (W / 2 - 0.02), FOOT + bodyH / 2, -D / 2 - 0.02), "steelDark")
	end
	-- 앞판 이음선 + 볼트
	lp(m, "S4_Seam", Vector3.new(W - 0.2, 0.03, 0.02), base * CFrame.new(0, topY - 0.25, -D / 2 - 0.01), "steelDark")
	for _, x in ipairs({ -W / 2 + 0.15, W / 2 - 0.15 }) do
		for _, y in ipairs({ FOOT + 0.25, topY - 0.15 }) do
			lf(m, "S4_Bolt", 0.03, 0.07, base * CFrame.new(x, y, -D / 2 - 0.015), "steelDark")
		end
	end
	-- 상판 (본체보다 살짝 넓은 판, 앞쪽으로 둥근 턱)
	lp(m, "S4_TopPlate", Vector3.new(W + 0.2, plateT, D + 0.2), base * CFrame.new(0, topY + plateT / 2, 0), "steel")
	lp(m, "S4_TopLip", Vector3.new(W + 0.24, 0.06, 0.06), base * CFrame.new(0, topY + plateT - 0.03, -D / 2 - 0.12), "steelDark")

	-- 조작판 (흰색·녹색·빨간색 버튼, 사진: 본체 앞 왼쪽 가운데)
	local panelX = 1.0
	local front = base * CFrame.new(0, 0, -D / 2)
	lp(m, "S4_ControlPanel", Vector3.new(2.0, 0.8, 0.06), front * CFrame.new(panelX, FOOT + 1.45, -0.03), "steelDark")
	lp(m, "S4_ControlFace", Vector3.new(1.84, 0.64, 0.04), front * CFrame.new(panelX, FOOT + 1.45, -0.07), "steel")
	local btn = { { "white", "S4_ButtonWhite" }, { "green", "S4_StartButton" }, { "red", "S4_StopButton" } }
	for i, b in ipairs(btn) do
		local x = panelX + 0.55 - (i - 1) * 0.55 -- 사진 왼쪽(+X)부터 흰·녹·빨
		lf(m, b[2] .. "Ring", 0.05, 0.42, front * CFrame.new(x, FOOT + 1.42, -0.1), "steelDark")
		local p = lf(m, b[2], 0.1, 0.32, front * CFrame.new(x, FOOT + 1.42, -0.16), b[1])
		if b[1] == "green" then
			p:SetAttribute("Anim", "lampRun")
		elseif b[1] == "red" then
			p:SetAttribute("Anim", "lampStop")
		end
		lp(m, "S4_ButtonLabel", Vector3.new(0.24, 0.05, 0.02), front * CFrame.new(x, FOOT + 1.7, -0.09), "white")
	end
	for _, x in ipairs({ panelX - 0.92, panelX + 0.92 }) do
		for _, y in ipairs({ FOOT + 1.12, FOOT + 1.78 }) do
			lf(m, "S4_Bolt", 0.03, 0.06, front * CFrame.new(x, y, -0.07), "steelDark")
		end
	end

	-- ① 가열 장치 (원통 스테인리스 통) + 게이지 + 황동 띠 + 아래 받침
	local hx, hz = W / 2 - 0.95, 0.05
	lc(m, "S4_KettleBase", 0.14, 1.75, base * CFrame.new(hx, deck + 0.07, hz), "steelDark")
	local kettleH = 1.25
	lc(m, "S4_Kettle", kettleH, 1.55, base * CFrame.new(hx, deck + 0.14 + kettleH / 2, hz), "steel")
	lc(m, "S4_KettleBand", 0.16, 1.58, base * CFrame.new(hx, deck + 0.14 + kettleH * 0.32, hz), "brass")
	lc(m, "S4_KettleRim", 0.08, 1.62, base * CFrame.new(hx, deck + 0.14 + kettleH - 0.04, hz), "steelDark")
	lc(m, "S4_KettleRim", 0.08, 1.62, base * CFrame.new(hx, deck + 0.18, hz), "steelDark")
	local kFront = base * CFrame.new(hx, deck + 0.14 + kettleH * 0.62, hz - 0.78)
	lf(m, "S4_GaugeRim", 0.08, 0.5, kFront * CFrame.new(-0.25, 0, -0.02), "brass")
	lf(m, "S4_Gauge", 0.06, 0.42, kFront * CFrame.new(-0.25, 0, -0.06), "white")
	lp(m, "S4_GaugeNeedle", Vector3.new(0.02, 0.16, 0.01), kFront * CFrame.new(-0.25, 0.04, -0.1) * CFrame.Angles(0, 0, math.rad(-35)), "black")
	lp(m, "S4_KettleLabel", Vector3.new(0.5, 0.12, 0.02), kFront * CFrame.new(0.25, -0.33, 0.02), "brass")
	lp(m, "S4_WarnSign", Vector3.new(0.16, 0.16, 0.02), kFront * CFrame.new(0.2, -0.55, 0.04) * CFrame.Angles(0, 0, math.rad(45)), "yellow")
	-- 통에서 컨베이어로 가는 짧은 관
	local pipe = lp(m, "S4_KettlePipe", Vector3.new(0.6, 0.22, 0.22), base * CFrame.new(hx - 0.95, deck + 0.45, hz), "steel", { Shape = Enum.PartType.Cylinder })
	pipe.Shape = Enum.PartType.Cylinder
	-- 위 받침판 + 기둥 4개 + 호퍼 (투명 용기 + 금속 뚜껑 + 금색 손잡이 공)
	local collarY = deck + 0.14 + kettleH
	lc(m, "S4_Collar", 0.16, 1.15, base * CFrame.new(hx, collarY + 0.08, hz), "steel")
	lc(m, "S4_CollarNeck", 0.3, 0.55, base * CFrame.new(hx, collarY + 0.3, hz), "steelDark")
	local postH = 0.55
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		lc(m, "S4_HopperPost", postH, 0.09, base * CFrame.new(hx + math.cos(a) * 0.45, collarY + 0.16 + postH / 2, hz + math.sin(a) * 0.45), "steel")
	end
	local ringY = collarY + 0.16 + postH
	lc(m, "S4_HopperRing", 0.12, 1.25, base * CFrame.new(hx, ringY + 0.06, hz), "steel")
	local hopH = 1.15
	lc(m, "S4_Hopper", hopH, 1.18, base * CFrame.new(hx, ringY + 0.12 + hopH / 2, hz), "glass", { Transparency = 0.62, CastShadow = false })
	lc(m, "S4_HopperSugar", hopH * 0.62, 1.08, base * CFrame.new(hx, ringY + 0.14 + hopH * 0.31, hz), "sugar")
	lc(m, "S4_HopperLid", 0.12, 1.3, base * CFrame.new(hx, ringY + 0.12 + hopH + 0.06, hz), "steel")
	lc(m, "S4_HopperLidTop", 0.08, 0.95, base * CFrame.new(hx, ringY + 0.12 + hopH + 0.16, hz), "steelDark")
	local knob = lp(m, "S4_HopperKnob", Vector3.new(0.22, 0.22, 0.22), base * CFrame.new(hx, ringY + 0.12 + hopH + 0.31, hz), "brass")
	knob.Shape = Enum.PartType.Ball
	-- 옆 레버 (황동, 사진: 호퍼 오른쪽)
	local lx = hx - 1.0
	lc(m, "S4_LeverBase", 0.18, 0.28, base * CFrame.new(lx, deck + 0.09, hz + 0.35), "steelDark")
	lc(m, "S4_LeverRod", 1.45, 0.11, base * CFrame.new(lx, deck + 0.18 + 0.72, hz + 0.35), "brass")
	lp(m, "S4_LeverArm", Vector3.new(0.5, 0.11, 0.11), base * CFrame.new(lx + 0.22, deck + 1.6, hz + 0.35) * CFrame.Angles(0, 0, math.rad(-25)), "brass")

	-- ② 컨베이어 받침 (스테인리스 상자) + 짙은 회색 벨트 + 벨트 위 달고나
	local cx0, cx1 = hx - 1.25, -W / 2 + 0.05 -- +X → -X
	local cLen = cx0 - cx1
	local cMid = (cx0 + cx1) / 2
	local bedH = 0.6
	lp(m, "S4_BeltBed", Vector3.new(cLen, bedH, 1.7), base * CFrame.new(cMid, deck + bedH / 2, 0), "steel")
	lp(m, "S4_BeltFrame", Vector3.new(cLen, 0.1, 1.45), base * CFrame.new(cMid, deck + bedH + 0.05, 0), "dark")
	lp(m, "S4_Belt", Vector3.new(cLen - 0.1, 0.04, 1.2), base * CFrame.new(cMid, deck + bedH + 0.12, 0), "dark", { Material = Enum.Material.Rubber })
	for _, sz in ipairs({ -1, 1 }) do
		lp(m, "S4_BeltRail", Vector3.new(cLen, 0.14, 0.08), base * CFrame.new(cMid, deck + bedH + 0.15, sz * 0.66), "steelDark")
	end
	local beltY = deck + bedH + 0.14
	for i = 0, 4 do
		local x = cx0 - 0.45 - i * (cLen - 0.9) / 4
		local d = lc(m, "S4_Dalgona", 0.06, 0.55, base * CFrame.new(x, beltY + 0.03, 0), "dalgona")
		d:SetAttribute("Anim", "window")
	end

	-- ③ 프레스 (은색 기둥 틀 + 구리 내열판 + 경고 표시 + 아래 투명 덮개)
	local px = cMid + 0.35
	local frameTop = beltY + 2.6
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			lc(m, "S4_PressPost", frameTop - beltY, 0.12, base * CFrame.new(px + sx * 0.48, beltY + (frameTop - beltY) / 2, sz * 0.5), "steel")
		end
		lp(m, "S4_PressSide", Vector3.new(0.12, frameTop - beltY - 0.2, 0.9), base * CFrame.new(px + sx * 0.6, beltY + (frameTop - beltY) / 2, 0), "steel")
	end
	lp(m, "S4_PressTop", Vector3.new(1.45, 0.6, 1.25), base * CFrame.new(px, frameTop + 0.3, 0), "white", { Material = Enum.Material.SmoothPlastic })
	lp(m, "S4_PressTopCap", Vector3.new(1.55, 0.08, 1.35), base * CFrame.new(px, frameTop + 0.64, 0), "steel")
	lp(m, "S4_PressTopBand", Vector3.new(1.5, 0.08, 1.3), base * CFrame.new(px, frameTop + 0.02, 0), "steel")
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			lf(m, "S4_Bolt", 0.03, 0.07, base * CFrame.new(px + sx * 0.6, frameTop + 0.55, -0.64), "steelDark")
		end
	end
	-- 움직이는 프레스 머리: 구리 판 (경고 표시) + 아래 구리 누름판
	local headY = beltY + 1.55
	local head = lp(m, "S4_PressHead", Vector3.new(0.92, 0.8, 0.9), base * CFrame.new(px, headY, 0), "copper")
	head:SetAttribute("Anim", "press")
	local warn = lp(m, "S4_PressWarn", Vector3.new(0.34, 0.34, 0.02), base * CFrame.new(px, headY + 0.05, -0.46) * CFrame.Angles(0, 0, math.rad(45)), "yellow")
	warn:SetAttribute("Anim", "press")
	local warnIn = lp(m, "S4_PressWarnMark", Vector3.new(0.05, 0.14, 0.02), base * CFrame.new(px, headY + 0.05, -0.475), "black")
	warnIn:SetAttribute("Anim", "press")
	local plate = lp(m, "S4_PressStamps", Vector3.new(0.85, 0.18, 0.85), base * CFrame.new(px, headY - 0.75, 0), "copper")
	plate:SetAttribute("Anim", "press")
	local rod = lc(m, "S4_PressRod", 1.0, 0.16, base * CFrame.new(px, headY + 0.85, 0), "steel")
	rod:SetAttribute("Anim", "press")
	-- 투명 덮개 (프레스 아래 앞쪽)
	lp(m, "S4_PressGuard", Vector3.new(0.95, 0.75, 0.04), base * CFrame.new(px, beltY + 0.5, -0.5), "glass", { Transparency = 0.6, CastShadow = false })
	lp(m, "S4_PressBase", Vector3.new(1.1, 0.12, 1.05), base * CFrame.new(px, beltY + 0.06, 0), "copper")

	-- ④ 원통형 가공 장치 (아이보리 외장, 둥근 모서리 + 황동 둥근 창 + 위 황동 바퀴)
	local ux = cx1 + 1.15
	local uw, uh, ud = 1.45, 1.3, 1.25
	local uy = beltY + 0.08 + uh / 2
	local r = 0.22
	lp(m, "S4_Unit", Vector3.new(uw - 2 * r, uh, ud), base * CFrame.new(ux, uy, 0), "ivory")
	lp(m, "S4_Unit", Vector3.new(uw, uh, ud - 2 * r), base * CFrame.new(ux, uy, 0), "ivory")
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			lc(m, "S4_UnitCorner", uh, 2 * r, base * CFrame.new(ux + sx * (uw / 2 - r), uy, sz * (ud / 2 - r)), "ivory")
		end
	end
	lp(m, "S4_UnitTop", Vector3.new(uw - 0.1, 0.08, ud - 0.1), base * CFrame.new(ux, uy + uh / 2 + 0.04, 0), "ivory")
	for _, sx in ipairs({ -1, 1 }) do
		lp(m, "S4_UnitFoot", Vector3.new(0.3, 0.1, ud - 0.2), base * CFrame.new(ux + sx * 0.45, beltY + 0.05, 0), "steelDark")
	end
	local uFront = base * CFrame.new(ux, uy, -ud / 2)
	lf(m, "S4_PortholeRing", 0.1, 0.78, uFront * CFrame.new(0, 0, -0.04), "brass")
	lf(m, "S4_Porthole", 0.06, 0.56, uFront * CFrame.new(0, 0, -0.08), "glass", { Transparency = 0.35 })
	for k = 0, 5 do
		local a = math.rad(k * 60)
		lf(m, "S4_PortholeBolt", 0.04, 0.05, uFront * CFrame.new(math.cos(a) * 0.33, math.sin(a) * 0.33, -0.1), "brass")
	end
	-- 옆 작은 명판
	lp(m, "S4_UnitPlate", Vector3.new(0.04, 0.42, 0.3), base * CFrame.new(ux - uw / 2 - 0.02, uy, 0), "steel")
	-- 위 황동 바퀴 (돌아감)
	lc(m, "S4_WheelBase", 0.1, 0.55, base * CFrame.new(ux, uy + uh / 2 + 0.13, 0), "steelDark")
	local wheel = lc(m, "S4_Wheel", 0.1, 0.78, base * CFrame.new(ux, uy + uh / 2 + 0.23, 0), "brass")
	wheel:SetAttribute("Anim", "spin")
	lc(m, "S4_WheelHub", 0.12, 0.28, base * CFrame.new(ux, uy + uh / 2 + 0.3, 0), "brass")

	-- ⑤ 배출 비탈 + 배출 트레이 (짙은 회색 금속, 본체 밖 -X로 나옴) + 다 된 별 달고나
	local chuteTop = Vector3.new(cx1 - 0.05, beltY - 0.05, 0)
	local chuteLen = 1.0
	lp(m, "S4_Chute", Vector3.new(chuteLen, 0.06, 1.1), base * CFrame.new(cx1 - 0.4, beltY - 0.3, 0) * CFrame.Angles(0, 0, math.rad(32)), "dark")
	for _, sz in ipairs({ -1, 1 }) do
		lp(m, "S4_ChuteSide", Vector3.new(chuteLen, 0.22, 0.05), base * CFrame.new(cx1 - 0.4, beltY - 0.22, sz * 0.56) * CFrame.Angles(0, 0, math.rad(32)), "dark")
	end
	local trayX, trayY = cx1 - 1.15, deck - 0.45
	local tray = lp(m, "S4_Tray", Vector3.new(1.2, 0.06, 1.2), base * CFrame.new(trayX, trayY, 0), "dark")
	tray:SetAttribute("Anim", "outlet")
	for _, sz in ipairs({ -1, 1 }) do
		lp(m, "S4_TrayLip", Vector3.new(1.2, 0.2, 0.05), base * CFrame.new(trayX, trayY + 0.1, sz * 0.6), "dark")
	end
	lp(m, "S4_TrayLip", Vector3.new(0.05, 0.2, 1.2), base * CFrame.new(trayX - 0.6, trayY + 0.1, 0), "dark")
	lp(m, "S4_TrayArm", Vector3.new(0.9, 0.08, 0.08), base * CFrame.new(trayX + 0.55, trayY - 0.15, 0.4) * CFrame.Angles(0, 0, math.rad(-20)), "steelDark")
	lp(m, "S4_TrayArm", Vector3.new(0.9, 0.08, 0.08), base * CFrame.new(trayX + 0.55, trayY - 0.15, -0.4) * CFrame.Angles(0, 0, math.rad(-20)), "steelDark")
	for i, off in ipairs({ Vector3.new(0.15, 0, 0.12), Vector3.new(-0.2, 0, -0.18), Vector3.new(-0.15, 0.04, 0.25) }) do
		lc(m, "S4_TrayDalgona", 0.05, 0.42, base * CFrame.new(trayX + off.X, trayY + 0.06 + off.Y, off.Z) * CFrame.Angles(math.rad(i * 4), 0, 0), "dalgona")
	end
	-- 자리 윗면(top0)을 기준으로 1.5배 (바닥에 붙은 채 커짐)
	m.WorldPivot = top0
	m:ScaleTo(LINE_SCALE)
	return (W + 1.8) * LINE_SCALE, (D + 0.2) * LINE_SCALE, (frameTop + 0.7) * LINE_SCALE
end

local BUILDERS = { [2] = buildSteel, [3] = buildPink, [4] = buildLine }
-- 편집 화면 틀(Workspace.MachineLayout.Stage4)을 이 모양으로 다시 만들 때 쓰는 도구용 (tools/studio/rebuild_layouts.lua)
Display.buildLine = buildLine
local NAMES = { [2] = "철제 판매기", [3] = "분홍 자판기", [4] = "연속 생산 설비" }

-- 편집 화면에서 고친 기계 모양 (판매 세션 2026-11-22, 사용자 "기계도 고치게"):
-- 편집 모드 Workspace.MachineLayout 안 Stage2·Stage3·Stage4 (Model). 각 단계 모델 안 부품 "SlotAnchor" = 기계 자리 윗면(top) 기준.
-- 서버 시작 때 ServerStorage.Assets.MachineLayout으로 옮기고, 그 단계를 만들 때 부품 LayoutKey로 위치·크기·색을 옮김.
-- 기계 위치(가게 안 자리)는 PlotLayout의 MachineSlot을 옮기면 됨
local Layout = require(script.Parent:WaitForChild("LayoutTemplate"))
local machineLayout = nil

local function findMachineLayout()
	local SS = game:GetService("ServerStorage")
	local assets = SS:FindFirstChild("Assets")
	local src = workspace:FindFirstChild("MachineLayout")
	if src then
		src.Parent = assets or SS
	else
		src = assets and assets:FindFirstChild("MachineLayout")
	end
	return src
end

local function applyMachineLayout(m, stage, top)
	local t = machineLayout and machineLayout:FindFirstChild("Stage" .. stage)
	local anchor = t and t:FindFirstChild("SlotAnchor")
	if not anchor then
		return
	end
	-- 4단계는 2026-11-27 코드로 새로 세운 스테인리스 설비 → 예전 사탕 공장 틀(L4_ 부품)은 쓰지 않음 (새 부품 S4_가 있는 틀만)
	if stage == 4 and not t:FindFirstChild("S4_Cabinet", true) then
		return
	end
	Layout.tag(m)
	Layout.apply(m, t, anchor.CFrame, top, {
		skip = function(tp)
			return tp == anchor
		end,
	})
end

local function addPrompt(attachTo, objectText, actionText)
	local att = Instance.new("Attachment")
	att.Name = "PromptAtt"
	att.Parent = attachTo
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "MachinePrompt"
	pr.ObjectText = objectText
	pr.ActionText = actionText
	pr.KeyboardKeyCode = Enum.KeyCode.F
	pr.HoldDuration = 0
	pr.MaxActivationDistance = PROMPT_DISTANCE
	pr.RequiresLineOfSight = false
	pr.Parent = att
	return pr
end

-- 기계 하나 만들기 (top = 자리 윗면, 앞 = 골목 쪽 -Z)
local function buildMachine(plot, name, stage, top, slotName)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Stage", stage)
	m:SetAttribute("MachineName", NAMES[stage])
	m:SetAttribute("SlotName", slotName)
	local ok, w, d, h = pcall(BUILDERS[stage], m, top)
	if not ok then
		warn("[Machine] 모델을 못 만들었어요:", w)
		m:Destroy()
		return nil
	end
	applyMachineLayout(m, stage, top)
	local anchorCF = top * CFrame.new(0, 2.2, -(d or 2.4) / 2 - 0.3)
	-- 사용자 기계 메시(Stage2Machine·Stage3Machine)가 있으면 그 앞면 밖·위쪽에 (2026-11-27 사용자 "만들기 버튼이 기계에 가려져
	-- 안 보임": 예전 자리는 메시 앞면보다 안쪽·낮은 곳이라 버튼 판(PromptStyle, AlwaysOnTop 아님)이 기계 속에 묻혔음).
	-- 버튼 판은 PromptAnchor + 2.2 높이에 뜸 → 판이 기계 높이의 70%쯤, 앞면에서 0.6 앞에 오게
	local mesh = m:FindFirstChild("Stage" .. stage .. "Machine", true)
	if mesh and mesh:IsA("BasePart") then
		local s = mesh.Size
		local base = mesh.CFrame * CFrame.new(0, -s.Y / 2, 0)
		local pos = base:PointToWorldSpace(Vector3.new(0, math.max(0.5, s.Y * 0.7 - 2.2), -s.Z / 2 - 0.6))
		anchorCF = CFrame.new(pos) * (top - top.Position)
		-- 머리 위 상태판(MachineClient: 앵커 + Height - 0.6)은 기계 꼭대기 조금 위
		h = s.Y + 1.2 - (pos.Y - base.Position.Y) + 0.6
	end
	local anchor = part(m, "PromptAnchor", Vector3.new(0.2, 0.2, 0.2), anchorCF, Color3.new(1, 1, 1), { Transparency = 1, CanQuery = false, CastShadow = false })
	local pr = addPrompt(anchor, NAMES[stage], "도안 고르기")
	pr:SetAttribute("MachineStage", stage)
	m:SetAttribute("Height", h or 5)
	m.PrimaryPart = anchor
	return m
end

-- 자리 파트는 글씨 방향 때문에 90° 돌아가 있음 → 부지 방향(앞 = 골목 쪽 -Z)으로 되돌림
local function slotTop(slot)
	return slot.CFrame * CFrame.new(0, slot.Size.Y / 2, 0) * CFrame.Angles(0, -math.pi * 0.5, 0)
end

-- 새로 산 기계가 나타날 때: 작게 시작해서 0.4초 동안 커짐 (서버에서 크기를 바꾸면 모두에게 보임).
-- 커지는 동안 속성 Popping = true → MachineClient는 끝난 뒤에 움직일 부품의 처음 자리(AnimBase)를 잼
-- 부지에 넣기 전에 부름 (처음 한 프레임이 큰 채로 보이지 않게)
local function popIn(m)
	local full = m:GetScale() -- 4단계 설비는 이미 1.5배 (2026-11-28: 예전엔 1로 돌아가 버림)
	local ok = pcall(function()
		m:ScaleTo(0.05 * full)
	end)
	if not ok then
		return
	end
	m:SetAttribute("Popping", true)
	task.defer(function() -- 부지에 넣은 뒤에 시작
		local t = 0
		while t < 0.4 do
			t += task.wait()
			if not m.Parent then
				return
			end
			local k = math.min(t / 0.4, 1)
			local e = 1 - (1 - k) ^ 3 -- 끝에서 부드럽게
			m:ScaleTo(full * math.max(0.05, e * (1 + 0.12 * math.sin(math.pi * k))))
		end
		if m.Parent then
			m:ScaleTo(full)
			m:SetAttribute("Popping", nil)
		end
	end)
end

-- 옛 한 자리(MachineSlot): 새 슬롯이 없는 부지(예전 저장 장소)에서만 씀
local function syncLegacy(plot)
	local slot = plot:FindFirstChild("MachineSlot")
	if not slot then
		return
	end
	local stage = slot:GetAttribute("Stage") or 1
	local old = plot:FindFirstChild("Machine")
	if old and old:GetAttribute("Stage") == stage then
		return
	end
	if old then
		old:Destroy()
	end
	-- 바닥 자리 표시: 기계가 있으면 숨기고, 없으면 "기계 사기" 안내(F)를 붙임
	local label = slot:FindFirstChildOfClass("SurfaceGui")
	local slotPrompt = slot:FindFirstChild("PromptAtt")
	if slotPrompt then
		slotPrompt:Destroy()
	end
	if not BUILDERS[stage] then
		slot.Transparency = 0.35
		if label then
			label.Enabled = true
		end
		addPrompt(slot, "기계 자리", "기계 보기")
		return
	end
	slot.Transparency = 1
	if label then
		label.Enabled = false
	end
	local m = buildMachine(plot, "Machine", stage, slotTop(slot), "MachineSlot")
	if m then
		m.Parent = plot
	end
end

local function hasStack(plot)
	return plot:FindFirstChild("MachineSlot2") ~= nil
end

-- 새 자리 3개 (D32): 산 기계는 자기 자리에, 아직 안 산 첫 단계 자리에는 "기계 보기" 안내
local function syncStack(plot, animate)
	-- 옛 한 자리 모습은 지움 (서버가 옛 슬롯을 지우기 전까지 두 번 그려지지 않게)
	local legacy = plot:FindFirstChild("Machine")
	if legacy then
		legacy:Destroy()
	end
	local oldSlot = plot:FindFirstChild("MachineSlot")
	if oldSlot then
		oldSlot.Transparency = 1
		local att = oldSlot:FindFirstChild("PromptAtt")
		if att then
			att:Destroy()
		end
		for _, c in ipairs(oldSlot:GetChildren()) do
			if c:IsA("SurfaceGui") then
				c.Enabled = false
			end
		end
	end
	local promptPlaced = false
	for n = 2, 4 do
		local slot = plot:FindFirstChild("MachineSlot" .. n)
		if slot then
			local owned = slot:GetAttribute("Owned") == true and (slot:GetAttribute("Stage") or 1) >= 2
			local name = "Machine" .. n
			local m = plot:FindFirstChild(name)
			local att = slot:FindFirstChild("PromptAtt")
			if owned then
				if att then
					att:Destroy()
				end
				-- 꾸미기로 자리(MachineSlot)를 옮겼으면 기계를 새 자리에 다시 세움 (2026-11-27 사용자 "2·3단계 기계도 옮길 수 있게":
				-- 예전엔 기계가 이미 있으면 그대로 둬서 바닥 판만 옮겨지고 기계는 제자리였음). 움직이는 부품의 처음 자리(AnimBase)가
				-- 바뀌어서 옮기지 않고 새로 만듦
				local top = slotTop(slot)
				if m then
					local was = m:GetAttribute("SlotCF")
					if typeof(was) ~= "CFrame" or (was.Position - top.Position).Magnitude > 0.05 or was.LookVector:Dot(top.LookVector) < 0.999 then
						m:Destroy()
						m = nil
					end
				end
				if not m and BUILDERS[n] then
					m = buildMachine(plot, name, n, top, slot.Name)
					if m then
						m:SetAttribute("SlotCF", top)
						if animate then
							popIn(m)
						end
						m.Parent = plot
					end
				end
			else
				if m then
					m:Destroy()
				end
				-- 아직 안 산 첫 자리: 바닥 판은 안 보이고 "기계 보기" 안내만 (다음 기계 사기 화면)
				if not promptPlaced then
					promptPlaced = true
					if not att then
						addPrompt(slot, "기계 자리", "기계 보기")
					end
				elseif att then
					att:Destroy()
				end
			end
		end
	end
end

-- 부지 하나의 기계 모습을 맞춤
function Display.sync(plot, animate)
	if hasStack(plot) then
		syncStack(plot, animate)
	else
		syncLegacy(plot)
	end
end

function Display.init()
	machineLayout = findMachineLayout()
	if machineLayout then
		print("[Machine] 편집 화면에서 고친 기계(MachineLayout)를 씀")
	end
	task.spawn(function()
		local folder = workspace:WaitForChild("ShopPlots", 60)
		if not folder then
			return
		end
		local function hook(plot)
			local slot = plot:WaitForChild("MachineSlot2", 10) or plot:FindFirstChild("MachineSlot")
			if not slot then
				return
			end
			Display.sync(plot, false)
			local function watch(s)
				for _, a in ipairs({ "Stage", "Owned" }) do
					s:GetAttributeChangedSignal(a):Connect(function()
						Display.sync(plot, true)
					end)
				end
			end
			if hasStack(plot) then
				for n = 2, 4 do
					local s = plot:FindFirstChild("MachineSlot" .. n)
					if s then
						watch(s)
					end
				end
			else
				watch(slot)
			end
		end
		for _, p in ipairs(folder:GetChildren()) do
			task.spawn(hook, p)
		end
		folder.ChildAdded:Connect(function(p)
			task.spawn(hook, p)
		end)
	end)
end

return Display

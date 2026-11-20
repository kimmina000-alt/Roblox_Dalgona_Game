-- 작업대 꾸미기 (사용자 요청 2026-11-19 "3D 더 귀엽고 입체적이고"):
--   분홍 깅엄 체크 식탁보 + 늘어진 가장자리 + 방울 장식, 바닥 둥근 러그, 따뜻하고 산뜻한 색감 보정.
-- 작업대(Studio에 저장된 것 포함)에 한 번만 붙인다. 부품은 모두 클릭·충돌 없음 (도구 판정에 안 걸리게).

local Lighting = game:GetService("Lighting")

local Decor = {}

local CLOTH = Color3.fromRGB(255, 249, 240)
local GINGHAM = Color3.fromRGB(255, 160, 185)
local TRIM = Color3.fromRGB(255, 130, 165)
local RUG = { Color3.fromRGB(190, 232, 214), Color3.fromRGB(255, 246, 228), Color3.fromRGB(255, 200, 214) }

local function part(parent, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Fabric
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

local function tablecloth(ws, top)
	local f = Instance.new("Model")
	f.Name = "Tablecloth"
	local cf = top.CFrame
	local sx, sz = top.Size.X + 0.3, top.Size.Z + 0.3
	local y = top.Size.Y / 2
	local DROP = 0.75
	part(f, "Cloth", Vector3.new(sx, 0.04, sz), cf * CFrame.new(0, y + 0.0, 0), CLOTH)
	-- 깅엄: 가로·세로 반투명 줄이 겹치는 곳이 진해짐
	local stripe = { Transparency = 0.45, Material = Enum.Material.SmoothPlastic }
	local nz = math.floor(sz)
	for i = 0, nz - 1 do
		local z = -sz / 2 + 0.25 + i + (sz - nz) / 2
		part(f, "StripeX", Vector3.new(sx, 0.01, 0.5), cf * CFrame.new(0, y + 0.025, z), GINGHAM, stripe)
	end
	local nx = math.floor(sx)
	for i = 0, nx - 1 do
		local x = -sx / 2 + 0.25 + i + (sx - nx) / 2
		part(f, "StripeZ", Vector3.new(0.5, 0.01, sz), cf * CFrame.new(x, y + 0.03, 0), GINGHAM, stripe)
		-- 앞뒤로 늘어진 천 위 세로 줄
		for _, s in ipairs({ -1, 1 }) do
			part(f, "DrapeStripe", Vector3.new(0.5, DROP, 0.01), cf * CFrame.new(x, y - DROP / 2 + 0.02, s * (sz / 2 + 0.035)), GINGHAM, stripe)
		end
	end
	-- 늘어진 가장자리 (앞뒤·양옆)
	for _, s in ipairs({ -1, 1 }) do
		part(f, "Drape", Vector3.new(sx, DROP, 0.04), cf * CFrame.new(0, y - DROP / 2 + 0.02, s * (sz / 2 + 0.01)), CLOTH)
		part(f, "Drape", Vector3.new(0.04, DROP, sz), cf * CFrame.new(s * (sx / 2 + 0.01), y - DROP / 2 + 0.02, 0), CLOTH)
	end
	-- 아랫단 방울 장식
	local by = y - DROP + 0.02
	local function bobble(x, z)
		local b = part(f, "Bobble", Vector3.one * 0.22, cf * CFrame.new(x, by, z), TRIM, { Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic })
		return b
	end
	for x = -sx / 2 + 0.25, sx / 2 - 0.2, 0.5 do
		bobble(x, -sz / 2 - 0.03)
		bobble(x, sz / 2 + 0.03)
	end
	for z = -sz / 2 + 0.25, sz / 2 - 0.2, 0.5 do
		bobble(-sx / 2 - 0.03, z)
		bobble(sx / 2 + 0.03, z)
	end
	f.Parent = ws
end

local function rug(ws, top)
	local f = Instance.new("Model")
	f.Name = "Rug"
	local c = top.Position
	local ground = 0.0
	local base = workspace:FindFirstChild("Baseplate")
	if base and base:IsA("BasePart") then
		ground = base.Position.Y + base.Size.Y / 2
	end
	local d = top.Size.X + 8
	for i, col in ipairs(RUG) do
		local dd = d * (1 - (i - 1) * 0.12)
		local p = part(f, "Rug" .. i, Vector3.new(0.04, dd, dd), CFrame.new(c.X, ground + 0.02 + i * 0.012, c.Z) * CFrame.Angles(0, 0, math.rad(90)), col)
		p.Shape = Enum.PartType.Cylinder
	end
	f.Parent = ws
end

local function grade()
	if Lighting:FindFirstChild("CuteGrade") then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CuteGrade"
	cc.Saturation = 0.15
	cc.Contrast = 0.05
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 248, 240)
	cc.Parent = Lighting
	-- 그림자 속도 따뜻하고 밝게 (둥글둥글한 파스텔 느낌, 너무 어두운 그늘 없이)
	Lighting.Ambient = Color3.fromRGB(118, 106, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 138, 132)
end

-- 도구 사이 간격 넓히기 (사용자 요청 2026-11-19: 화로 · 설탕 그릇 · 철판 사이를 더 떨어뜨리고 테이블은 길어져도 됨).
-- Studio에 저장된 작업대도 실행할 때 옮긴다. 카메라 자리(CameraRig POSES)는 옮긴 뒤 기준.
-- WorkstationBuilder.rebuildBrazier는 옛 자리(BRAZIER_X)에 다시 만드니, 쓸 때는 이것도 다시 부른다.
local SPREAD = 1.5
local LEFT = { "Brazier", "Ladle", "Chopsticks" }
local RIGHT = { "IronPlate", "SugarRing", "SugarRingInner", "Presser", "Cutter" }

local function layout(ws, top)
	if ws:GetAttribute("LayoutV2") then
		return
	end
	ws:SetAttribute("LayoutV2", true)
	local function shift(name, dx)
		local inst = ws:FindFirstChild(name)
		if inst and inst:IsA("Model") then
			inst:PivotTo(inst:GetPivot() + Vector3.new(dx, 0, 0))
		elseif inst and inst:IsA("BasePart") then
			inst.CFrame += Vector3.new(dx, 0, 0)
		end
	end
	for _, n in ipairs(LEFT) do
		shift(n, -SPREAD)
	end
	for _, n in ipairs(RIGHT) do
		shift(n, SPREAD)
	end
	-- 모양틀 손잡이가 길어져서(CutterRig 손잡이 연장) 테이블 밖으로 안 나가게 안쪽으로
	local cutter = ws:FindFirstChild("Cutter")
	if cutter then
		cutter:PivotTo(cutter:GetPivot() + Vector3.new(0, 0, -0.2))
	end
	top.Size += Vector3.new(SPREAD * 2, 0, 0)
	for _, leg in ipairs(ws:GetChildren()) do
		if leg.Name == "TableLeg" then
			leg.CFrame += Vector3.new(leg.Position.X < top.Position.X and -SPREAD or SPREAD, 0, 0)
		end
	end
end

-- 기본은 낡은 나무 테이블 (사용자 요청 2026-11-19): 바랜 색 + 얼룩 몇 군데
local OLD_WOOD = Color3.fromRGB(116, 86, 62)
local STAIN = Color3.fromRGB(70, 48, 34)
local function wornTable(ws, top)
	if ws:FindFirstChild("Stains") then
		return
	end
	top.Color = OLD_WOOD
	top.Material = Enum.Material.WoodPlanks
	for _, leg in ipairs(ws:GetChildren()) do
		if leg.Name == "TableLeg" then
			leg.Color = OLD_WOOD:Lerp(STAIN, 0.25)
		end
	end
	local f = Instance.new("Model")
	f.Name = "Stains"
	local rng = Random.new(7)
	local y = top.Size.Y / 2 + 0.006
	for _ = 1, 9 do
		local d = rng:NextNumber(0.5, 1.4)
		local x = rng:NextNumber(-top.Size.X / 2 + 1, top.Size.X / 2 - 1)
		local z = rng:NextNumber(-top.Size.Z / 2 + 0.6, top.Size.Z / 2 - 0.6)
		local p = part(f, "Stain", Vector3.new(0.01, d, d * rng:NextNumber(0.6, 1)), top.CFrame * CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(90)), STAIN, { Transparency = 0.7, Material = Enum.Material.SmoothPlastic })
		p.Shape = Enum.PartType.Cylinder
	end
	-- 모서리가 닳아 밝아진 가장자리
	for _, s in ipairs({ -1, 1 }) do
		part(f, "WornEdge", Vector3.new(top.Size.X, 0.05, 0.12), top.CFrame * CFrame.new(0, y - 0.02, s * (top.Size.Z / 2 - 0.05)), OLD_WOOD:Lerp(Color3.fromRGB(200, 170, 130), 0.35), { Transparency = 0.3, Material = Enum.Material.Wood })
	end
	f.Parent = ws
end

-- 나무젓가락 통 (사용자 요청 2026-11-19): 낡은 양철 통에 나무젓가락이 잔뜩. 누르면 한 짝을 꺼냄 (클라이언트 ChopstickCup)
local function chopstickCup(ws)
	if ws:FindFirstChild("ChopstickCup") then
		return
	end
	local chop = ws:FindFirstChild("Chopsticks")
	local top = ws:FindFirstChild("TableTop")
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local tplFolder = assets and assets:FindFirstChild("Chopsticks")
	if not (chop and top and tplFolder) then
		return
	end
	-- 포장된 젓가락은 숨김 (이제 통에서 꺼냄)
	for _, p in ipairs(chop:GetChildren()) do
		if p:IsA("BasePart") and p.Name:sub(1, 7) == "Wrapped" then
			p.Transparency = 1
		end
	end
	local m = Instance.new("Model")
	m.Name = "ChopstickCup"
	local tableY = top.Position.Y + top.Size.Y / 2
	local base = Vector3.new(chop:GetPivot().Position.X, tableY, top.Position.Z - 2.2)
	local CUP_D, CUP_H = 1.0, 1.25
	local tin = { Material = Enum.Material.CorrodedMetal, CanQuery = false }
	local body = part(m, "Cup", Vector3.new(CUP_H, CUP_D, CUP_D), CFrame.new(base + Vector3.new(0, CUP_H / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(168, 172, 168), tin)
	body.Shape = Enum.PartType.Cylinder
	local rim = part(m, "Rim", Vector3.new(0.08, CUP_D + 0.06, CUP_D + 0.06), CFrame.new(base + Vector3.new(0, CUP_H, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 122, 118), tin)
	rim.Shape = Enum.PartType.Cylinder
	local band = part(m, "Label", Vector3.new(0.4, CUP_D + 0.02, CUP_D + 0.02), CFrame.new(base + Vector3.new(0, CUP_H * 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 90, 80), { Material = Enum.Material.SmoothPlastic })
	band.Shape = Enum.PartType.Cylinder
	-- 포장지에 싸인 채로 꽂혀 있음 (사용자 요청 2026-11-19: 꺼내면 포장 찢기부터)
	local names = { "Wrap1" }
	local rng = Random.new(11)
	for i = 1, 12 do
		local name = names[(i - 1) % #names + 1]
		local tpl = tplFolder:FindFirstChild(name)
		if tpl then
			local s = tpl:Clone()
			s.Name = "CupStick"
			s:SetAttribute("Tpl", name)
			s.Anchored = true
			s.CanCollide = false
			s.CanTouch = false
			local a = rng:NextNumber(0, math.pi * 2)
			local r = math.sqrt(rng:NextNumber()) * 0.3
			local len = s.Size.Y -- 포장 젓가락은 길이 축이 Y
			local pos = base + Vector3.new(math.cos(a) * r, 0.1 + len / 2 + rng:NextNumber(0, 0.15), math.sin(a) * r)
			-- 세워서 바깥쪽으로 살짝 벌어지게
			s.CFrame = CFrame.new(pos) * CFrame.Angles(math.sin(a) * 0.12, rng:NextNumber(0, 6), -math.cos(a) * 0.12)
			s.Parent = m
		end
	end
	m.Parent = ws
end

-- 식탁보는 상점에서 산 사람만 (사용자 요청 2026-11-19). 지금은 플레이어 속성 OwnsTablecloth로 판정 (상점은 다음 단계).
-- 작업대에 있는 플레이어 중 한 명이라도 가지고 있으면 깔림.
local clothStore = nil
function Decor.setTablecloth(ws, on)
	local cloth = ws:FindFirstChild("Tablecloth") or clothStore
	if not cloth then
		local top = ws:FindFirstChild("TableTop")
		if not top then
			return
		end
		tablecloth(ws, top)
		cloth = ws:FindFirstChild("Tablecloth")
	end
	clothStore = cloth
	cloth.Parent = on and ws or game:GetService("ServerStorage")
end

function Decor.watchOwners(ws)
	local Players = game:GetService("Players")
	local function refresh()
		local any = false
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("OwnsTablecloth") then
				any = true
			end
		end
		Decor.setTablecloth(ws, any)
	end
	Players.PlayerAdded:Connect(function(p)
		p:GetAttributeChangedSignal("OwnsTablecloth"):Connect(refresh)
		refresh()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
	refresh()
end

-- ── 1단계 가게 꾸미기 (2026-11-20 사용자 참고 사진 3장) ──
--   ① 화로 밑에 구겨진 은박지 ② 철판 위에 고운 설탕 가루가 옅게 깔림 ③ 스테인리스 쟁반에 모양 틀 여러 개
--   ④ 아이스크림 막대가 꽂힌 양철 통 ⑤ 테이블 오른쪽 옆 나무 계단 진열대에 비닐 포장한 달고나들 (막대로 세움)
local STEEL = Color3.fromRGB(198, 200, 206)
local WOOD = Color3.fromRGB(170, 122, 78)
local DALGONA = Color3.fromRGB(204, 150, 96)
local function deco(parent, name, size, cf, color, material, props)
	local p = part(parent, name, size, cf, color, props)
	p.Material = material or Enum.Material.SmoothPlastic
	return p
end

local function foil(f, ws, tableY)
	local b = ws:FindFirstChild("Brazier")
	if not b then
		return
	end
	local c = b:GetPivot().Position
	local rng = Random.new(7)
	-- 여러 장이 겹친 것처럼 (구겨진 느낌: 조금씩 돌아가고 높이가 다름)
	for i, sz in ipairs({ Vector3.new(6.2, 0.02, 5.4), Vector3.new(3.4, 0.02, 2.6), Vector3.new(2.8, 0.02, 3.0) }) do
		local off = i == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.4, 1.4))
		deco(f, "Foil", sz, CFrame.new(c.X + off.X, tableY + 0.01 + i * 0.004, c.Z + off.Z) * CFrame.Angles(0, math.rad(rng:NextNumber(-8, 8)), 0), Color3.fromRGB(168, 170, 176), Enum.Material.Foil, { Reflectance = 0.25 })
	end
end

-- 반죽 붓는 판 (2026-11-20, 레퍼런스/3.jpg: 문방구 앞 아이들이 둘러선 판). 검은 철판이 아니라
-- 함석(아연 도금 철판) 판: 은회색에 얼룩덜룩한 아연 무늬, 가장자리는 접어 올린 테두리, 판 이음매에 리벳, 긁힌 자국.
-- 판정용 IronPlate(크기·높이)는 그대로 두고 겉모습만 바꿈
local function galvanizedBoard(f, ws)
	local plate = ws:FindFirstChild("IronPlate")
	if not plate then
		return
	end
	plate.Color = Color3.fromRGB(140, 144, 151)
	plate.Material = Enum.Material.Metal
	plate.Reflectance = 0.12
	local sx, sz = plate.Size.X, plate.Size.Z
	local topY = plate.Position.Y + plate.Size.Y / 2
	local base = CFrame.new(plate.Position.X, topY, plate.Position.Z)
	local EDGE = Color3.fromRGB(150, 154, 160)
	-- 접어 올린 테두리 (둥근 감김)
	for _, e in ipairs({ { 0, sz / 2, sx + 0.1, 0.1 }, { 0, -sz / 2, sx + 0.1, 0.1 }, { sx / 2, 0, 0.1, sz + 0.1 }, { -sx / 2, 0, 0.1, sz + 0.1 } }) do
		deco(f, "BoardHem", Vector3.new(e[3], 0.1, e[4]), base * CFrame.new(e[1], 0.01, e[2]), EDGE, Enum.Material.Metal, { Reflectance = 0.15 })
	end
	-- 판 이음매 + 리벳 (뒤쪽, 설탕 원 밖)
	local seamZ = -sz / 2 + 0.38
	deco(f, "BoardSeam", Vector3.new(sx, 0.025, 0.07), base * CFrame.new(0, 0.012, seamZ), EDGE, Enum.Material.Metal, { Reflectance = 0.15 })
	for i = 0, 8 do
		local x = -sx / 2 + 0.25 + i * (sx - 0.5) / 8
		deco(f, "BoardRivet", Vector3.new(0.03, 0.08, 0.08), base * CFrame.new(x, 0.02, seamZ) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(196, 198, 202), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, Reflectance = 0.2 })
	end
	-- 아연 도금 얼룩 무늬 (밝고 어두운 조각이 겹쳐 얼룩덜룩)
	local rng = Random.new(13)
	for _ = 1, 26 do
		local w, l = rng:NextNumber(0.25, 0.9), rng:NextNumber(0.25, 0.9)
		local x, z = rng:NextNumber(-sx / 2 + w / 2, sx / 2 - w / 2), rng:NextNumber(-sz / 2 + l / 2, sz / 2 - l / 2)
		local light = rng:NextNumber() < 0.5
		deco(f, "BoardSpangle", Vector3.new(w, 0.002, l), base * CFrame.new(x, 0.001, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), light and Color3.fromRGB(214, 218, 224) or Color3.fromRGB(138, 142, 150), Enum.Material.Metal, { Transparency = rng:NextNumber(0.72, 0.86) })
	end
	-- 긁힌 자국
	for _ = 1, 14 do
		local len = rng:NextNumber(0.3, 1.1)
		deco(f, "BoardScratch", Vector3.new(0.012, 0.002, len), base * CFrame.new(rng:NextNumber(-sx / 2 + 0.4, sx / 2 - 0.4), 0.0015, rng:NextNumber(-sz / 2 + 0.4, sz / 2 - 0.4)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color3.fromRGB(110, 112, 118), Enum.Material.SmoothPlastic, { Transparency = 0.55 })
	end
end

-- 가운데 설탕 (2026-11-20 "입자들로 표현해, 너무 동그래"): 매끈한 원판 대신 뭉친 설탕 가루 덩이 몇 개 + 흩뿌린 알갱이.
-- 가장자리는 들쭉날쭉하게 흩어짐. 판정용 SugarRing(가운데·반지름)은 그대로 두고 투명하게
local function sugarBed(f, ws)
	local ring = ws:FindFirstChild("SugarRing")
	if not ring then
		return
	end
	ring.Transparency = 1
	local inner = ws:FindFirstChild("SugarRingInner")
	if inner then
		inner.Transparency = 1
	end
	local R = ring.Size.Y / 2
	local c = ring.Position
	local plate = ws:FindFirstChild("IronPlate")
	local y = plate and (plate.Position.Y + plate.Size.Y / 2) or (c.Y - 0.01)
	local rng = Random.new(17)
	local WHITE = Color3.fromRGB(252, 252, 250)
	-- 얇게 뭉친 가루 덩이 (겹쳐서 울퉁불퉁한 구름 모양)
	for _ = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = R * math.sqrt(rng:NextNumber()) * 0.72
		local d = rng:NextNumber(0.45, 1.0)
		deco(f, "SugarClump", Vector3.new(0.006 + rng:NextNumber(0, 0.01), d, d * rng:NextNumber(0.55, 1)), CFrame.new(c.X + math.cos(a) * r, y + 0.004 + rng:NextNumber(0, 0.004), c.Z + math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(90)), WHITE, Enum.Material.Sand, { Shape = Enum.PartType.Cylinder, Transparency = rng:NextNumber(0.35, 0.6) })
	end
	-- 흩뿌린 알갱이: 가운데는 촘촘, 가장자리로 갈수록 드문드문, 원 밖으로도 조금 튐
	for _ = 1, 240 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = R * (rng:NextNumber() ^ 0.65) * rng:NextNumber(0.9, 1.15)
		local g = rng:NextNumber(0.03, 0.065)
		local tone = WHITE:Lerp(Color3.fromRGB(226, 222, 214), rng:NextNumber(0, 0.6))
		deco(f, "SugarGrain", Vector3.new(g, g * 0.6, g * rng:NextNumber(0.7, 1.2)), CFrame.new(c.X + math.cos(a) * r, y + g * 0.3, c.Z + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4)), tone, Enum.Material.SmoothPlastic, { Reflectance = 0.05 })
	end
end

local function sugarDust(f, ws)
	local plate = ws:FindFirstChild("IronPlate")
	if not plate then
		return
	end
	local topY = plate.Position.Y + plate.Size.Y / 2
	deco(f, "SugarDust", Vector3.new(plate.Size.X * 0.96, 0.004, plate.Size.Z * 0.96), CFrame.new(plate.Position.X, topY + 0.002, plate.Position.Z), Color3.fromRGB(250, 250, 248), Enum.Material.Sand, { Transparency = 0.8 })
	-- 가장자리에 조금 몰린 설탕
	local rng = Random.new(3)
	for _ = 1, 7 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = plate.Size.X * rng:NextNumber(0.36, 0.46)
		local d = rng:NextNumber(0.25, 0.5)
		deco(f, "SugarDrift", Vector3.new(0.01, d, d * rng:NextNumber(1.2, 2)), CFrame.new(plate.Position.X + math.cos(a) * r, topY + 0.005, plate.Position.Z + math.sin(a) * r) * CFrame.Angles(0, a, math.rad(90)), Color3.fromRGB(252, 252, 250), Enum.Material.Sand, { Transparency = 0.35, Shape = Enum.PartType.Cylinder })
	end
end

local function cutterTray(f, ws, tableY, rightX, midZ)
	local cx, cz = rightX - 1.4, midZ - 0.3
	local W, L = 2.2, 3.0
	local base = CFrame.new(cx, tableY, cz)
	deco(f, "Tray", Vector3.new(W, 0.06, L), base * CFrame.new(0, 0.03, 0), STEEL, Enum.Material.Metal, { Reflectance = 0.15 })
	for _, e in ipairs({ { 0, L / 2, W, 0.06 }, { 0, -L / 2, W, 0.06 }, { W / 2, 0, 0.06, L }, { -W / 2, 0, 0.06, L } }) do
		deco(f, "TrayRim", Vector3.new(e[3], 0.16, e[4]), base * CFrame.new(e[1], 0.08, e[2]), STEEL, Enum.Material.Metal, { Reflectance = 0.15 })
	end
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local cutters = assets and assets:FindFirstChild("Cutters")
	if not cutters then
		return
	end
	local list = cutters:GetChildren()
	local rng = Random.new(5)
	local n = 0
	for i = 1, math.min(#list, 8) do
		local tpl = list[i]
		if tpl:IsA("BasePart") then
			n += 1
			local col, row = (n - 1) % 2, math.floor((n - 1) / 2)
			local p = tpl:Clone()
			p.Name = "TrayCutter"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Size = p.Size * 0.42
			p.CFrame = base * CFrame.new(-W / 4 + col * W / 2, 0.06 + p.Size.Y / 2, -L / 2 + 0.4 + row * 0.72) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0)
			p.Parent = f
		end
	end
end

local function stickCup(f, tableY, x, z)
	local base = Vector3.new(x, tableY, z)
	local tin = { Shape = Enum.PartType.Cylinder }
	deco(f, "StickCup", Vector3.new(0.9, 0.8, 0.8), CFrame.new(base + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(170, 174, 170), Enum.Material.CorrodedMetal, tin)
	deco(f, "StickCupRim", Vector3.new(0.06, 0.84, 0.84), CFrame.new(base + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 122, 118), Enum.Material.Metal, tin)
	local rng = Random.new(9)
	for _ = 1, 11 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * 0.22
		local len = 1.5
		local pos = base + Vector3.new(math.cos(a) * r, 0.1 + len / 2 + rng:NextNumber(0, 0.12), math.sin(a) * r)
		deco(f, "CupPopsicle", Vector3.new(0.03, len, 0.15), CFrame.new(pos) * CFrame.Angles(math.sin(a) * 0.14, rng:NextNumber(0, 6), -math.cos(a) * 0.14), Color3.fromRGB(232, 204, 156), Enum.Material.Wood)
	end
end

-- 포장한 달고나 하나 (진열대용): 세운 원판 + 찍힌 자국 + 막대 + 비닐 + 빵끈. pos = 막대 아래 끝, 앞 = +Z
local function wrappedDalgona(f, pos, lean, rng)
	local D = 1.0
	local cf = CFrame.new(pos) * CFrame.Angles(-lean, 0, 0)
	local disc = cf * CFrame.new(0, 0.75 + D / 2, 0)
	local tone = DALGONA:Lerp(Color3.fromRGB(176, 112, 60), rng:NextNumber(0, 0.35))
	deco(f, "ShowDalgona", Vector3.new(0.06, D, D), disc * CFrame.Angles(0, math.rad(90), 0), tone, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
	deco(f, "ShowStamp", Vector3.new(0.065, D * 0.5, D * 0.5), disc * CFrame.Angles(0, math.rad(90), 0), tone:Lerp(Color3.fromRGB(110, 62, 28), 0.35), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder, Transparency = 0.25 })
	deco(f, "ShowStick", Vector3.new(0.14, 0.95, 0.03), cf * CFrame.new(0, 0.48, 0), Color3.fromRGB(232, 204, 156), Enum.Material.Wood)
	deco(f, "ShowBag", Vector3.new(D * 1.12, D * 1.15, 0.2), disc * CFrame.new(0, 0.02, 0), Color3.fromRGB(248, 250, 255), Enum.Material.SmoothPlastic, { Transparency = 0.72, Reflectance = 0.3 })
	deco(f, "ShowBagNeck", Vector3.new(0.18, 0.22, 0.12), cf * CFrame.new(0, 0.62, 0), Color3.fromRGB(248, 250, 255), Enum.Material.SmoothPlastic, { Transparency = 0.6, Reflectance = 0.3 })
	deco(f, "ShowTie", Vector3.new(0.06, 0.18, 0.18), cf * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(226, 176, 52), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
end

local function display(f, floorY, x, z)
	-- 3단 나무 계단 (앞 = +Z, 뒤로 갈수록 높음)
	local W, DEPTH = 3.8, 1.1
	local rng = Random.new(21)
	for i = 1, 3 do
		local h = 0.9 + (i - 1) * 0.8
		local sz = z - (i - 1) * DEPTH
		deco(f, "ShowStep", Vector3.new(W, h, DEPTH), CFrame.new(x, floorY + h / 2, sz), WOOD:Lerp(Color3.fromRGB(120, 84, 52), (i - 1) * 0.15), Enum.Material.Wood)
		for k = 1, 3 do
			local px = x - W / 2 + W * (k - 0.5) / 3 + rng:NextNumber(-0.1, 0.1)
			wrappedDalgona(f, Vector3.new(px, floorY + h, sz - 0.1), math.rad(rng:NextNumber(8, 16)), rng)
		end
	end
	-- 뒤 간판
	local sign = deco(f, "ShowSign", Vector3.new(W, 1.0, 0.12), CFrame.new(x, floorY + 0.9 + 1.6 + 2.2, z - 2 * DEPTH - 0.2), Color3.fromRGB(255, 196, 210), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(380, 100)
	gui.Parent = sign
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(150, 60, 80)
	l.Text = "달고나"
	l.Parent = gui
	-- 간판 기둥
	for _, dx in ipairs({ -W / 2 + 0.1, W / 2 - 0.1 }) do
		deco(f, "ShowPole", Vector3.new(0.12, 4.6, 0.12), CFrame.new(x + dx, floorY + 2.3, z - 2 * DEPTH - 0.2), WOOD, Enum.Material.Wood)
	end
end

local function stage1(ws, top)
	if ws:FindFirstChild("Stage1Decor") then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "Stage1Decor"
	f.Parent = ws
	local tableY = top.Position.Y + top.Size.Y / 2
	local rightX = top.Position.X + top.Size.X / 2
	local frontZ = top.Position.Z + top.Size.Z / 2
	foil(f, ws, tableY)
	galvanizedBoard(f, ws)
	sugarDust(f, ws)
	sugarBed(f, ws)
	cutterTray(f, ws, tableY, rightX, top.Position.Z)
	stickCup(f, tableY, rightX - 1.4, frontZ - 0.9)
	local floorY = top.Position.Y - top.Size.Y / 2 - 2.9 -- 테이블 다리 높이만큼 아래 = 바닥
	-- 진열대는 테이블 왼쪽 옆 (오른쪽은 Lv4 연속 생산 설비 시험 자리)
	display(f, floorY, top.Position.X - top.Size.X / 2 - 2.4, top.Position.Z + 1.0)
end

function Decor.dress(ws)
	local top = ws:FindFirstChild("TableTop")
	if not top then
		return
	end
	layout(ws, top)
	wornTable(ws, top)
	-- 소다 통 숟가락 숨김 (사용자 요청 2026-11-19). 클라이언트 Station이 찾는 모델이라 지우지는 않음
	local spoon = ws:FindFirstChild("SodaSpoon")
	if spoon then
		for _, p in ipairs(spoon:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Transparency = 1
			end
		end
	end
	chopstickCup(ws)
	stage1(ws, top)
	if not ws:FindFirstChild("Rug") then
		rug(ws, top)
	end
	grade()
	Decor.watchOwners(ws)
end

return Decor

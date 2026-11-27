-- 2·3단계 기계 직접 만들기 장면 (MachineMake가 씀).
-- 사용자 기계 메시(Stage2Machine 빨간 철제 기계 / Stage3Machine 분홍 판매기, tools/blender/stage23_user.py)를 세우고,
-- 메시 위 자리(동전 구멍 · 설탕 배출구/기둥 · 화구 · 금형판 칸)에 움직이는 것을 올린다. 모두 내 화면에서만 (클라이언트).
-- 2026-11-26 사용자 "손 작업대 화면 구현 방식 그대로": 국자·나무젓가락·소다통·설탕 더미·녹는 결정·젓가락 길·부푸는 반죽은
--   내 가게 손 작업대(Workstations.mine)를 복제해 기계 화구 위에 얹고(국자·젓가락·소다통만 보이게) 손 작업대 단계 모듈
--   (Steps/Melt, Steps/Soda)이 그 Station으로 그대로 돈다 (Scene:station()).
-- D60 (2026-11-26 사용자 확정, 안 A): 장면을 하늘(y 900) 대신 **내 가게의 그 기계 자리**에 만든다. 국자가 들어가게 기계는 S배로 키운
--   복제를 진짜 기계 자리(뒷면 맞춤)에 세우고, 진짜 기계들·내 캐릭터는 만드는 동안 내 화면에서 숨김. 카메라는 지금 자리에서 그 기계로 다가감.
--   장면 모델은 가게 부지(Plot) 안에 넣어 ViewClear가 카메라를 가리는 천장·벽을 숨김. 내 가게 기계를 못 찾으면 예전처럼 y 900.
-- D61 막대 통(손 작업대 StickCup) + 아이스크림 막대(Steps/Stick.build), D62 넓은 누름판(손 작업대 Presser), D63 3단계 설탕·소다 기둥.
-- 자리 값은 메시 기준(바닥 가운데 = 원점, 앞 = -Z, 화면 오른쪽 = -X, 메시 단위). 2026-11-26 메시 꼭짓점(EditableMesh)으로 잼.
-- 2026-11-27 사용자: "주변 환경 그대로 보이게(기계 위치는 플레이어가 자유롭게 바꿈)", "국자 더 크게" → 기계를 키우지 않고(S = 1)
--   가게에 놓인 그 크기·자리 그대로, 그 단계 기계만 같은 자리 복제로 바꿔 끼움 (주변 가게·다른 기계는 그대로 보임).
--   (3단계 기둥을 지웠다가 같은 날 사용자 "나오는 입구 기둥 보여야 함" → 기둥은 그대로, 설탕·소다는 기둥 아래 입구에서,
--   국자 댈 자리는 빛나는 고리 + "여기에 대요"로 표시 Scene:setHoldMark)
--   막대 통 대신 막대 더미(Steps/Stick.build), 누름판은 눕힌 채(손 작업대 모양 그대로), 칸 반죽은 볼록 → 누르면 납작.
local Players = game:GetService("Players")
local AssetService = game:GetService("AssetService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DalgonaLook = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DalgonaLook"))
local Making = script.Parent:WaitForChild("Making")
local Station = require(Making:WaitForChild("Station"))
local StickStep = require(Making:WaitForChild("Steps"):WaitForChild("Stick"))
local Workstations = require(Making:WaitForChild("Workstations"))
local ViewScale = require(Making:WaitForChild("ViewScale"))
local ViewClear = require(Making:WaitForChild("ViewClear"))
local BatterMesh = require(Making:WaitForChild("BatterMesh"))
local Toon = require(Making:WaitForChild("Toon"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DalgonaConfig"))
local CutterShapes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CutterShapes"))

local Scene = {}
Scene.__index = Scene
Scene.PILLAR_GAP = 0.25 -- 3단계: 기둥 입구 아래 국자 그릇 위 끝까지 틈 (메시 단위)

local SKY = CFrame.new(0, 900, 0) -- 내 가게 기계를 못 찾을 때만
local C = {
	white = Color3.fromRGB(250, 250, 248),
	water = Color3.fromRGB(150, 196, 222),
	coil = Color3.fromRGB(255, 96, 40),
	floor = Color3.fromRGB(176, 140, 108),
	wall = Color3.fromRGB(238, 222, 196),
	shelf = Color3.fromRGB(150, 108, 74),
	red = Color3.fromRGB(190, 36, 32), -- 2단계 기계 몸통 (앞판 빨강과 맞춤)
	tray = Color3.fromRGB(24, 22, 22),
}

-- 메시 기준 자리 (S배 하기 전 값)
local LAYOUT = {
	[2] = {
		-- 2026-11-28 사용자 "2단계 기계 만들기 들어가면 기계 커지는 거 수정, 화면이 확대되게": 기계는 가게 크기 그대로(1),
		-- 대신 카메라를 더 가까이 (cam = 카메라 거리 배율, 예전 S 2.5 기준 값에 곱함. 11-27 S 1.8 / cam 0.9였음)
		S = 1,
		cam = 0.42,
		size = Vector3.new(4.86, 5.86, 3.23),
		coins = { Vector3.new(1.5, 1.36, -1.65), Vector3.new(-1.5, 1.36, -1.65) }, -- 앞면 동전 구멍 2개 (어느 쪽이든)
		press = Vector3.new(0, 0.75, -1.65), -- 설탕: 배출구를 꾹 누름
		spout = Vector3.new(0, 0.55, -1.75), -- 설탕 나오는 끝
		sugarLadle = Vector3.new(0, 0.12, -1.95), -- 설탕 받을 때 국자 그릇 바닥 자리 (배출구 아래, 기계 앞)
		burner = Vector3.new(1.4, 4.52, -0.1), -- 윗판 왼쪽 화구 윗면
		burnerD = 0.6,
		sodaCup = { pos = Vector3.new(0.04, 4.83, -0.58), r = 0.22 }, -- 가운데 원통 (테두리 높이, 안쪽 반지름) — 소다를 여기에
		cavY = 5.92, -- 금형판 윗면 (뒤쪽에 들린 판, 칸 8개)
		cavD = 0.46,
		cavs = { 1.9, 1.39, 0.82, 0.31, -0.26, -0.83, -1.4, -1.97 }, -- 칸 x (z = cavZ)
		cavZ = 1.15,
		-- 메시 칸에는 여러 모양이 그려져 있음 → 쓰는 칸에 이번에 고른 도안 모양 금형을 올림 (2026-11-27 사용자)
		markCavities = true,
		-- 메시가 앞판·윗판·금형판뿐이라 옆·뒤가 뚫려 보임 → 몸통 벽을 Part로 (x ±2.43, 앞판 z -1.11, 뒤 z 1.61, 윗판 4.52)
		body = { x = 2.43, zFront = -1.11, zBack = 1.61, top = 4.5 },
		stickBox = Vector3.new(-2.0, 4.52, 0.45), -- 막대 더미: 윗판 오른쪽, 금형판 바로 앞 (붓기·막대 화면에 같이 보이게, 2026-11-27)
		shelfY = 4.5, -- 물그릇 올린 옆 선반 높이
		ladleRest = Vector3.new(-1.3, 0.1, -2.3),
	},
	[3] = {
		-- 2026-11-28 사용자 "3단계도 같이": 기계는 가게 크기 그대로(1), 카메라를 더 가까이 (11-27 S 1.4 / cam 0.87이었음)
		S = 1,
		cam = 0.5,
		size = Vector3.new(6.32, 7.13, 4.97),
		coins = { Vector3.new(-0.93, 5.1, -2.5) }, -- 앞판 동전 투입구 윗부분 검은 칸 (2026-11-27 사용자 화면으로 맞춤)
		pillars = { { x = 1.9, z = -1.21 }, { x = 0.3, z = -1.21 } }, -- 지울 기둥 (y pillarY0 ~ pillarTop)
		pillarY0 = 2.3,
		pillarTop = 3.46, -- 기둥 위 끝 = 보라 판 아랫면 (설탕·소다가 여기서 나옴)
		-- D63: 앞면 아래 은색 기둥 두 개 (꼭짓점으로 잼: x 1.90 / 0.30, z -1.21, 아래 끝 2.43). 왼쪽 = 설탕, 오른쪽 = 식소다
		sugarPillar = Vector3.new(1.9, 2.43, -1.21),
		sodaPillar = Vector3.new(0.3, 2.43, -1.21),
		spout = Vector3.new(1.9, 2.43, -1.21),
		-- 검은 컵(열선): 가운데 (1.90, -1.21), 테두리 높이 1.02, 바깥 반지름 0.94, 안쪽 0.64, 안쪽 바닥 0.40
		cup = { x = 1.9, z = -1.21, rim = 1.02, rOut = 0.94, rIn = 0.64, floor = 0.4 },
		sugarLadle = Vector3.new(1.9, 1.02, -1.21),
		burner = Vector3.new(1.9, 1.02, -1.21), -- 국자 받침 = 컵 테두리
		-- 오른쪽 검은 판: 메시 판(x -2.85~-0.42)이 5칸보다 좁음 → 옆으로 넓힌 판을 Part로 덮고 칸을 고르게. 앞쪽은 막대 통 자리만큼 더
		tray = { x0 = -3.1, x1 = -0.1, z0 = -2.75, z1 = -0.2, top = 1.5 },
		cavY = 1.5,
		cavD = 0.7,
		cavGrid = { -- 5칸: 앞줄 3 + 뒷줄 2
			Vector3.new(-0.65, 0, -1.75), Vector3.new(-1.6, 0, -1.75), Vector3.new(-2.55, 0, -1.75),
			Vector3.new(-1.12, 0, -0.8), Vector3.new(-2.08, 0, -0.8),
		},
		markCavities = true, -- 판이 민판이라 칸 자국을 올림
		stickBox = Vector3.new(-0.45, 1.5, -2.5), -- 막대 통: 넓힌 판 오른쪽 앞
		shelfY = 1.7,
		ladleRest = Vector3.new(0.3, 0.45, -1.9),
	},
}

local function part(parent, name, size, cf, color, mat, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end
Scene.part = part

-- 세운 원기둥 (Part 원기둥은 X축이 길이)
local function cyl(parent, name, h, d, pos, color, mat, props)
	local p = part(parent, name, Vector3.new(h, d, d), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
Scene.cyl = cyl

-- 고른 칸 i개를 가운데부터 (2단계 칸 8개 중)
local function middle(list, n)
	local k = #list
	local first = math.floor((k - n) / 2) + 1
	local out = {}
	for i = first, math.min(k, first + n - 1) do
		table.insert(out, list[i])
	end
	return out
end

-- 부품 상자를 세계 축으로 본 가로(X)·세로(Z) 폭
local function flatWidth(p)
	local cf, s = p.CFrame, p.Size
	local r, u, k = cf.RightVector, cf.UpVector, cf.LookVector
	local wx = math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(k.X) * s.Z
	local wz = math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(k.Z) * s.Z
	return math.max(wx, wz)
end

local function myPlot()
	local ws = Workstations.mine()
	return ws and ws.Parent or nil
end

-- 내 가게의 그 단계 기계 (Plot.Machine2·3) 메시
local function shopMachine(plot, stage)
	local m = plot and plot:FindFirstChild("Machine" .. stage)
	local mesh = m and m:FindFirstChild("Stage" .. stage .. "Machine", true)
	return m, mesh
end

-- 내 화면에서만 숨기기 (되돌릴 값 기억)
local function hideLocal(self, inst)
	local list = inst:IsA("BasePart") and { inst } or {}
	for _, d in ipairs(inst:GetDescendants()) do
		table.insert(list, d)
	end
	for _, d in ipairs(list) do
		if d:IsA("BasePart") and self.hidden[d] == nil then
			self.hidden[d] = d.LocalTransparencyModifier
			d.LocalTransparencyModifier = 1
		elseif (d:IsA("BillboardGui") or d:IsA("SurfaceGui")) and self.hiddenGui[d] == nil then
			self.hiddenGui[d] = d.Enabled
			d.Enabled = false
		end
	end
end

-- stage: 2 / 3, cavities: 이번 판 칸 수(=개수), shape: 도안 id
function Scene.new(stage, cavities, shape)
	local self = setmetatable({}, Scene)
	local L = LAYOUT[stage] or LAYOUT[2]
	local S = L.S
	self.stage, self.S, self.L = stage, S, L
	self.hidden, self.hiddenGui = {}, {}
	local m = Instance.new("Model")
	m.Name = "MachineMakeScene"
	self.model = m

	-- 기준 자리 (D60): 내 가게 그 기계의 바닥 가운데, 뒷면을 맞춘 채 S배 (앞으로 커짐)
	local plot = myPlot()
	local shopM, mesh = shopMachine(plot, stage)
	local ORIGIN
	if mesh then
		local bottom = mesh.CFrame * CFrame.new(0, -mesh.Size.Y / 2, 0)
		ORIGIN = bottom * CFrame.new(0, 0, mesh.Size.Z / 2 - L.size.Z * S / 2)
		self.inShop = true
	else
		ORIGIN = SKY
	end
	self.origin = ORIGIN
	self.rot = ORIGIN - ORIGIN.Position
	local function at(v) -- 메시 단위 자리 → 세계
		return ORIGIN:PointToWorldSpace(v * S)
	end
	local function W(x, y, z) -- 장면 기준(스터드) 자리 → 세계
		return ORIGIN:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local function CF(x, y, z) -- 장면 기준 자리·방향 → CFrame
		return ORIGIN * CFrame.new(x, y, z)
	end
	self.at, self.W, self.CF = at, W, CF
	function self.dir(v)
		return ORIGIN:VectorToWorldSpace(v)
	end

	if not self.inShop then
		-- 하늘 장면: 바닥(탁자)·뒷벽 (카메라에 하늘이 안 보이게)
		part(m, "Floor", Vector3.new(90, 1, 70), CF(0, -0.5, 10), C.floor, Enum.Material.WoodPlanks)
		part(m, "Wall", Vector3.new(90, 60, 1), CF(0, 25, L.size.Z * S / 2 + 6), C.wall, Enum.Material.Plaster)
	else
		-- 그 단계 진짜 기계는 같은 자리 복제로 바꿔 끼우니 내 화면에서 숨김 (2단계 몸통 벽 등 Machine 모델 통째). 내 캐릭터도 숨김
		hideLocal(self, shopM)
		local ch = Players.LocalPlayer.Character
		if ch then
			hideLocal(self, ch)
		end
	end

	-- 기계 몸 (S배 복제)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and (assets:FindFirstChild("MachineMeshes") or assets:WaitForChild("MachineMeshes", 3))
	local src = folder and (folder:FindFirstChild("Stage" .. stage .. "Machine") or folder:WaitForChild("Stage" .. stage .. "Machine", 2))
	if src then
		local mm = src:Clone()
		mm.Anchored, mm.CanCollide, mm.CanQuery, mm.CanTouch = true, false, false, false
		mm.Size = L.size * S
		mm.CFrame = CF(0, L.size.Y * S / 2, 0)
		mm.Parent = m
		self.machine = mm
		-- (2026-11-27 다시 사용자 "나오는 입구 기둥 보여야 함" → 기둥은 지우지 않음. removePillars는 남겨 둠)
	else
		self.machine = part(m, "MachineBox", L.size * S, CF(0, L.size.Y * S / 2, 0), stage == 3 and Color3.fromRGB(240, 150, 176) or Color3.fromRGB(200, 50, 50), Enum.Material.Metal)
	end
	-- 2단계 몸통 옆·뒤 벽 (메시에 없음)
	if L.body then
		local b = L.body
		local h = b.top * S
		local depth = (b.zBack - b.zFront) * S
		local zc = (b.zBack + b.zFront) / 2 * S
		for _, sx in ipairs({ 1, -1 }) do
			part(m, "BodySide", Vector3.new(0.08, h, depth), CF(sx * (b.x * S - 0.04), h / 2, zc), C.red, Enum.Material.Metal)
		end
		part(m, "BodyBack", Vector3.new(b.x * 2 * S, h, 0.08), CF(0, h / 2, b.zBack * S - 0.04), C.red, Enum.Material.Metal)
	end

	self.coinList = {}
	for _, c in ipairs(L.coins) do
		table.insert(self.coinList, at(c))
	end
	self.pressPos = L.press and at(L.press) or nil
	self.spoutPos = at(L.spout)
	self.sugarLadle = at(L.sugarLadle)
	self.burnerPos = at(L.burner)
	self.sugarPillar = L.sugarPillar and at(L.sugarPillar) or nil
	self.sodaPillar = L.sodaPillar and at(L.sodaPillar) or nil
	if L.sugarPillar then
		-- 설탕·소다는 기둥 아래 끝(입구)에서 나옴
		self.sugarTop = self.sugarPillar
		self.sodaTop = self.sodaPillar
	end

	-- 화구 열선 빛. 3단계는 검은 컵 "안쪽"이 빨갛게: 안쪽 바닥 원판 + 안벽을 따라 세운 열선 12개
	self.glowParts = {}
	if L.cup then
		local cu = L.cup
		local cpos = at(Vector3.new(cu.x, 0, cu.z))
		local rIn = cu.rIn * S
		table.insert(self.glowParts, cyl(m, "CupGlowFloor", 0.04, rIn * 1.9, cpos + Vector3.new(0, cu.floor * S + 0.03, 0), C.coil, Enum.Material.Neon, { Transparency = 1, CastShadow = false }))
		local wallH = (cu.rim - cu.floor) * S * 0.8
		for k = 1, 12 do
			local a = k / 12 * math.pi * 2
			local p = cpos + Vector3.new(math.cos(a) * (rIn - 0.06), cu.floor * S + wallH / 2 + 0.05, math.sin(a) * (rIn - 0.06))
			table.insert(self.glowParts, part(m, "CupGlowCoil", Vector3.new(0.07, wallH, 0.07), CFrame.new(p), C.coil, Enum.Material.Neon, { Transparency = 1, CastShadow = false }))
		end
	else
		table.insert(self.glowParts, cyl(m, "BurnerGlow", 0.04, L.burnerD * S, self.burnerPos + Vector3.new(0, 0.03, 0), C.coil, Enum.Material.Neon, { Transparency = 1, CastShadow = false }))
	end
	-- 3단계 설탕·소다 나오는 구멍 (판 아랫면, 국자가 가까우면 빛남)
	self.pillarGlow = {}
	for key, top in pairs({ sugarPillar = self.sugarTop, sodaPillar = self.sodaTop }) do
		cyl(m, key .. "Hole", 0.03, 0.22, top - Vector3.new(0, 0.015, 0), Color3.fromRGB(70, 70, 76), Enum.Material.Metal, { CastShadow = false })
		self.pillarGlow[key] = cyl(m, key .. "Glow", 0.03, 0.3, top - Vector3.new(0, 0.035, 0), Color3.fromRGB(255, 240, 180), Enum.Material.Neon, { Transparency = 1, CastShadow = false })
	end
	-- 설탕 줄기 (누르는 동안 / 기둥에서)
	self.stream = part(m, "SugarStream", Vector3.new(0.14, 1, 0.14), CFrame.new(self.spoutPos), C.white, Enum.Material.Sand, { Transparency = 1, CastShadow = false })
	-- 붓는 반죽 줄기
	self.pourStream = part(m, "BatterStream", Vector3.new(0.22, 1, 0.22), CF(0, 0, 0), Color3.fromRGB(206, 152, 96), Enum.Material.SmoothPlastic, { Transparency = 1, CastShadow = false })

	-- 옆 선반: 화면 오른쪽(-X)에 물그릇, 3단계는 왼쪽(+X)에 소다통 대신 비워 둠 (소다는 기둥에서)
	local half = L.size.X * S / 2
	local shelfY = L.shelfY * S
	local zShelf = -L.size.Z * S / 2 + 2.4
	-- (2026-11-27: 가게 그대로 보이게 물그릇 선반은 없앰 — 국자는 붓기 뒤 화면에서 숨김)
	self.shelfLTop = W(half + 1, shelfY, zShelf)
	self.waterPos = W(-half - 1, shelfY, zShelf)

	-- 금형판 (3단계: 넓힌 검은 판을 덮음)
	if L.tray then
		local t = L.tray
		local w, d = (t.x1 - t.x0) * S, (t.z1 - t.z0) * S
		part(m, "WideTray", Vector3.new(w, 0.16, d), CF((t.x0 + t.x1) / 2 * S, t.top * S - 0.08, (t.z0 + t.z1) / 2 * S), C.tray, Enum.Material.Metal)
	end
	local cavD = L.cavD * S
	self.cavD = cavD
	self.cavY = at(Vector3.new(0, L.cavY, 0)).Y
	local spots = {}
	if L.cavGrid then
		for i = 1, math.min(cavities, #L.cavGrid) do
			table.insert(spots, L.cavGrid[i])
		end
	else
		for _, x in ipairs(middle(L.cavs, math.min(cavities, #L.cavs))) do
			table.insert(spots, Vector3.new(x, 0, L.cavZ))
		end
	end
	self.cavities = {}
	local sum = Vector3.zero
	for i, v in ipairs(spots) do
		local pos = at(Vector3.new(v.X, L.cavY, v.Z))
		sum += pos
		if L.markCavities then
			-- 고른 도안 모양 금형 (2026-11-27 사용자 "금형틀에 처음 만들 때 고른 모양틀로"): 어두운 칸 + 밝은 금속 모양 선.
			-- DalgonaLook 모양 위쪽 = 모델 -Z → 180° 돌려 화면 위쪽(기계 뒤)이 모양 위쪽
			local mark = DalgonaLook.build({ s = shape, g = "Good" }, { diameter = cavD, stick = false })
			mark.Name = "Cavity" .. i
			for _, p in ipairs(mark:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CastShadow = false
					if p.Name == "Disc" or p.Name == "Rim" then
						p.Color = Color3.fromRGB(30, 28, 28)
						p.Material = Enum.Material.Metal
					elseif p.Name == "Groove" then
						p.Color = Color3.fromRGB(150, 150, 158)
						p.Material = Enum.Material.Metal
					end
				end
			end
			mark:PivotTo(CFrame.new(pos + Vector3.new(0, 0.005, 0)) * self.rot * CFrame.Angles(0, math.pi, 0))
			mark.Parent = m
		end
		table.insert(self.cavities, { pos = pos, fill = 0, look = nil, stick = nil })
	end
	self.plateCenter = sum / math.max(#spots, 1)
	self.ladleRest = at(L.ladleRest)
	self.stickBoxPos = at(L.stickBox)
	-- 막대: 손 작업대 아이스크림 막대를 칸 크기에 맞춰 줄임 (손 작업대 달고나 지름 약 1.4 기준)
	self.stickScale = math.clamp(cavD / 1.4, 0.25, 1)
	m.Parent = self.inShop and plot or workspace
	if self.inShop then
		-- 카메라와 볼 자리 사이를 실제로 가리는 가게 부품만 내 화면에서 숨김 (기계 뒤 벽·천장은 그대로 = 그 자리에서 다가가 보이게)
		ViewClear.start(m, function()
			local pts = { self.plateCenter, self:bowlPos(), at(Vector3.new(0, L.size.Y * 0.5, -L.size.Z * 0.5)) }
			if self.camTarget then
				table.insert(pts, self.camTarget)
			end
			return pts
		end)
	end
	return self
end

-- 손 작업대 Station (국자·나무젓가락·소다통·설탕 더미·결정·거품·막대 통·누름판 그대로). 내 가게 손 작업대를 복제해 화구 위에 얹음.
-- 반환: Station 또는 nil, 이유
function Scene:station()
	if self.S_ then
		return self.S_
	end
	local ws = Workstations.mine()
	if not (ws and Workstations.ready(ws)) then
		return nil, "내 가게 손 작업대를 못 찾았어요"
	end
	-- 가게 안 작업대는 내 화면에서 반 크기로 보임(ViewScale) → 원래 크기로 돌린 채 복제
	local vs = ws:GetAttribute("ViewScale")
	if vs ~= nil and vs ~= 1 then
		ViewScale.setFull(ws, true)
	end
	local clone = ws:Clone()
	-- 누름판도 원래 크기일 때 따로 복제해 둠 (가게 작업대 누름판은 내 화면에서 거의 0 크기로 줄어 있음, 2026-11-27)
	local presserSrc = ws:FindFirstChild("Presser")
	self.presserSrc = presserSrc and presserSrc:Clone() or nil
	if vs ~= nil and vs ~= 1 then
		ViewScale.setFull(ws, false)
	end
	clone.Name = "MachineStation"
	for _, k in ipairs({ "OwnerUserId", "ViewScale", "AtInside", "ViewOrigin", "PlotIndex" }) do
		clone:SetAttribute(k, nil)
	end
	-- 손 작업대 앞(+Z, 플레이어 쪽) = 기계 앞(-Z) → 180° 돌림 (화면 위쪽 = 기계 뒤)
	clone:PivotTo(CFrame.new(self.origin.Position) * self.rot * CFrame.Angles(0, math.pi, 0))
	-- 철망 윗면 가운데를 화구 윗면 가운데로
	local brazier = clone:FindFirstChild("Brazier")
	local grillTop, gx, gz, gn = -math.huge, 0, 0, 0
	for _, d in ipairs(brazier and brazier:GetDescendants() or {}) do
		if d:IsA("BasePart") and d.Name == "Grill" then
			grillTop = math.max(grillTop, d.Position.Y + d.Size.Y / 2)
			gx += d.Position.X
			gz += d.Position.Z
			gn += 1
		end
	end
	if gn == 0 then
		local b = clone:FindFirstChild("Ladle") and clone.Ladle:FindFirstChild("Bowl")
		gx, gz, gn = b.Position.X, b.Position.Z, 1
		grillTop = b.Position.Y - 0.825
	end
	local target = self.burnerPos
	clone:PivotTo(clone:GetPivot() + Vector3.new(target.X - gx / gn, target.Y - grillTop, target.Z - gz / gn))
	-- 화로 속성 GrillTopY는 세계 높이 그대로 남아 있음 → 옮긴 자리로 고침 (안 고치면 Station이 국자를 원래 작업대 높이에 띄움, 2026-11-27)
	if brazier then
		brazier:SetAttribute("GrillTopY", target.Y)
	end
	-- 국자·나무젓가락·소다통만 보이게 (누름판은 누르기 단계에서 따로 꺼냄, 막대 통은 안 씀 — 막대 더미를 따로 놓음)
	local keep = {}
	for _, n in ipairs({ "Ladle", "Chopsticks", "SodaTub" }) do
		local c = clone:FindFirstChild(n)
		if c then
			keep[c] = true
		end
	end
	local function kept(d)
		local p = d
		while p and p ~= clone do
			if keep[p] then
				return true
			end
			p = p.Parent
		end
		return false
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			d.Enabled = false
		elseif d:IsA("ClickDetector") then
			d:Destroy()
		elseif not kept(d) then
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CastShadow = false
				d.CanQuery = false
				d.CanCollide = false
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 1
			elseif d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Beam") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
				d.Enabled = false
			elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
				d.Enabled = false
			end
		end
	end
	clone.Parent = self.model
	local S = Station.new(clone)
	-- 국자 피벗 ↔ 그릇 가운데 차이 (국자 자세 기준, ladleBowlTo가 씀)
	do
		local pv = S.Ladle:GetPivot()
		self.bowlOff = (pv - pv.Position):Inverse() * (pv.Position - S.Bowl.Position)
	end
	-- 연탄 불꽃은 안 씀 (기계는 열선): 화면 밖 빈 이미터로 바꿔 Heat가 만져도 안 보이게
	S.Flame = Instance.new("ParticleEmitter")
	S:useChopstick(1, "A")
	-- 소다통: 2단계는 가운데 원통 안 (통 몸통·라벨은 숨기고 가루만, 원통 안쪽 크기로). 3단계는 기둥에서 나와서 통을 숨김
	local tub = S.SodaTub
	local powder = tub:FindFirstChild("Soda")
	if self.L.sodaCup and powder then
		local cupR = self.L.sodaCup.r * self.S
		local w = flatWidth(powder)
		if w > 0.01 then
			tub:ScaleTo(tub:GetScale() * (cupR * 2 / w))
		end
		local want = self.at(self.L.sodaCup.pos) - Vector3.new(0, 0.12, 0)
		tub:PivotTo(tub:GetPivot() + (want - powder.Position))
		-- 보이는 가루 = SodaPowderMesh, Soda는 원래 투명한 찍기 판정 자리
		for _, d in ipairs(tub:GetDescendants()) do
			if d:IsA("BasePart") and (d.Name == "SodaCanMesh" or d.Name == "SodaLabelMesh" or d.Name == "Tub") then
				d.Transparency = 1
				d.CastShadow = false
			end
		end
	elseif powder then
		for _, d in ipairs(tub:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CastShadow = false
			end
		end
		tub:PivotTo(tub:GetPivot() + (self.sodaPillar - powder.Position)) -- 판정 자리만 기둥 아래로 (CameraRig 소다 화면이 기둥을 봄)
	end
	S.rest.SodaTub = tub:GetPivot()
	-- 국자 손잡이 잡는 자리 (2026-11-27 "손잡이 잡고 움직이게"): 국자 부품 중 그릇에서 가로로 가장 먼 끝의 85% 쯤
	do
		local bowl = S.Bowl.Position
		local far, fd = nil, 0
		for _, d in ipairs(S.Ladle:GetDescendants()) do
			if d:IsA("BasePart") and d ~= S.Bowl and d.Name ~= "Contents" then
				local cf, sz = d.CFrame, d.Size / 2
				for _, ax in ipairs({ cf.RightVector * sz.X, cf.UpVector * sz.Y, cf.LookVector * sz.Z }) do
					for _, sgn in ipairs({ 1, -1 }) do
						local p = d.Position + ax * sgn
						local dd = Vector3.new(p.X - bowl.X, 0, p.Z - bowl.Z).Magnitude
						if dd > fd then
							far, fd = p, dd
						end
					end
				end
			end
		end
		self.gripOff = far and Vector3.new(far.X - bowl.X, 0, far.Z - bowl.Z) * 0.85 or Vector3.zero -- 그릇 가운데 → 손잡이 (국자 자세는 내내 같음)
	end
	-- 막대 더미 (D61): 금형판 옆에 막대 몇 개를 쌓아 둠. 여기서 끌어 칸에 놓음
	self.stickPile = {}
	local k = self.stickScale
	for i = 1, 3 do
		local sm, place = StickStep.build(S)
		place(CFrame.new(self.stickBoxPos))
		sm:ScaleTo(k)
		sm.Parent = self.model
		local y = (i - 0.5) * StickStep.SIZE.THICK * k
		sm:PivotTo(CFrame.new(self.stickBoxPos + Vector3.new(0, y, 0)) * self.rot * CFrame.Angles(0, math.rad(90 + (i - 2) * 6), 0))
		table.insert(self.stickPile, sm)
	end
	-- 칸 반죽 3D 메시를 미리 만들어 둠 (붓기 첫 칸에서 메시를 만드느라 멈칫해 첫 칸이 덜 차던 것, 손 작업대 Pour와 같은 방법)
	BatterMesh.prewarm(self.model, Color3.fromRGB(206, 152, 96))
	self.S_ = S
	return S
end

-- 막대를 꺼내는 자리 (막대 더미 맨 위)
function Scene:stickRest()
	return self.stickBoxPos + Vector3.new(0, StickStep.SIZE.THICK * self.stickScale * 3, 0)
end

-- 3단계 기둥 지우기: 복제 메시를 EditableMesh로 읽어 기둥 자리(가로 반지름 0.22, 높이 pillarY0 ~ pillarTop 바로 아래)의
-- 꼭짓점을 모두 기둥 위 끝 한 점으로 모음 → 기둥 면이 넓이 0이 되어 안 보임. (게임 안에서는 에셋 메시의 면을 빼는 건 막혀 있어서
-- "EditableMesh is fixed-size" — 꼭짓점 옮기기만 됨, 2026-11-27 확인). 실패하면 기둥이 그대로 보일 뿐 만들기는 됨
function Scene:removePillars(mm, L)
	local ok, err = pcall(function()
		local em = AssetService:CreateEditableMeshAsync(Content.fromUri(mm.MeshId))
		local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
		local verts = em:GetVertices()
		for _, v in ipairs(verts) do
			local p = em:GetPosition(v)
			mn, mx = mn:Min(p), mx:Max(p)
		end
		local ext, mid = mx - mn, (mn + mx) / 2
		local function toMesh(x, y, z) -- 메시 기준 자리(바닥 가운데 원점) → 메시 정점 좌표
			return mid + Vector3.new(x, y - L.size.Y / 2, z) / L.size * ext
		end
		local moved = 0
		for _, v in ipairs(verts) do
			local u = (em:GetPosition(v) - mid) / ext * L.size
			local y = u.Y + L.size.Y / 2
			if y >= L.pillarY0 and y < L.pillarTop - 0.02 then
				for _, pl in ipairs(L.pillars) do
					if Vector2.new(u.X - pl.x, u.Z - pl.z).Magnitude < 0.22 then
						em:SetPosition(v, toMesh(pl.x, L.pillarTop - 0.01, pl.z))
						moved += 1
						break
					end
				end
			end
		end
		if moved > 0 then
			local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
			local tex = mm.TextureID
			mm:ApplyMesh(mp)
			mm.TextureID = tex -- ApplyMesh가 텍스처를 비움 (2026-11-27 확인: 기계가 하얗게 나왔음)
		end
		self.pillarsRemoved = moved
	end)
	if not ok then
		warn("[MachineMake] pillars not removed:", err)
	end
end

-- 붓기 뒤 국자·젓가락을 화면에서 숨김 (2026-11-27)
function Scene:hideLadle()
	local S = self.S_
	if not S then
		return
	end
	for _, m in ipairs({ S.Ladle, S.Chopsticks }) do
		for _, d in ipairs(m and m:GetDescendants() or {}) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			elseif d:IsA("Decal") then
				d.Transparency = 1
			end
		end
	end
	-- 국자 속 거품·결정 등 효과도 (막대 더미는 장면 모델로 옮겨 놔서 안 지워짐)
	pcall(function()
		S:clearFx()
	end)
end

-- 넓은 누름판 (D62): 손 작업대 누름판을 복제해 금형판 칸을 다 덮는 크기로
function Scene:presser()
	if self.press then
		return self.press
	end
	-- 복제 작업대의 누름판은 숨겨 놓았으니, station()에서 원래 크기일 때 따로 복제해 둔 누름판을 씀
	local src = self.presserSrc
	if not src then
		return nil
	end
	local p = src:Clone()
	p.Name = "WidePresser"
	for _, d in ipairs(p:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 0
			-- 손 작업대에서 붓기 때 숨긴 채(Transparency 1)일 수 있음 → 판정용 원판(Disc)만 투명, 나머지는 보이게
			d.Transparency = d.Name == "Disc" and 1 or 0
			d.CanQuery, d.CanCollide, d.CanTouch = false, false, false
			d.Anchored = true
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = false
		end
	end
	-- 방향은 손 작업대에 눕혀 놓인 그대로 둠 (2026-11-27 "누름판이 세워져 있음": 예전엔 방향을 기계 방향으로 덮어써서 세워졌음)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, c in ipairs(self.cavities) do
		local l = self.origin:PointToObjectSpace(c.pos)
		minX, maxX = math.min(minX, l.X), math.max(maxX, l.X)
		minZ, maxZ = math.min(minZ, l.Z), math.max(maxZ, l.Z)
	end
	local span = math.max(maxX - minX, maxZ - minZ) + self.cavD * 1.3
	local _, size = p:GetBoundingBox()
	local w = math.max(size.X, size.Z)
	if w > 0.01 then
		p:ScaleTo(p:GetScale() * span / w)
	end
	p.Parent = self.model
	self.press = { model = p }
	return self.press
end

-- 누름판 아랫면 가운데를 금형판 칸 가운데 + h(스터드) 높이로
function Scene:presserTo(h)
	local pr = self:presser()
	if not pr then
		return
	end
	local cf, sz = pr.model:GetBoundingBox()
	local bottom = cf.Position - Vector3.new(0, sz.Y / 2, 0)
	local c = self.plateCenter
	local want = Vector3.new(c.X, self.cavY + h, c.Z)
	pr.model:PivotTo(pr.model:GetPivot() + (want - bottom))
end

function Scene:hidePresser()
	if self.press then
		self.press.model:Destroy()
		self.press = nil
	end
end

-- 국자 그릇 가운데를 point로 (손잡이 방향 = Station 제자리 그대로), tilt = 국자 기울기(라디안)
function Scene:ladleBowlTo(point, tilt)
	local S = self.S_
	if not S then
		return
	end
	local rest = S.rest.Ladle
	local rot = rest - rest.Position
	local cf = CFrame.new(point) * rot
	if tilt then
		cf = cf * CFrame.Angles(0, 0, tilt)
	end
	S.Ladle:PivotTo(cf + (cf - cf.Position) * self.bowlOff)
end

function Scene:bowlPos()
	return self.S_ and self.S_.Bowl.Position or self.burnerPos
end

-- 화구 빛 0~1
function Scene:setHeat(v)
	for _, p in ipairs(self.glowParts) do
		p.Transparency = 1 - 0.75 * math.clamp(v, 0, 1)
	end
end

-- 3단계 기둥 끝 빛 (key = "sugarPillar" | "sodaPillar")
function Scene:setPillarGlow(key, on)
	local p = self.pillarGlow and self.pillarGlow[key]
	if p then
		p.Transparency = on and 0.2 or 1
	end
end

-- 3단계 국자 대는 자리 표시 (2026-11-27 사용자 "어디 대고 있어야 하는지 표시"): 기둥 입구 아래 국자 그릇 자리에
-- 빛나는 점선 고리 + 그 아래 화면 글씨 "▲ 여기에 대요" (BillboardGui는 화면에 안 잡혀서 만들기 화면 글씨를 매 프레임 그 자리로).
-- state = nil(숨김) / "far" / "near" / "under". center = 그릇 가운데, d = 그릇 지름, rim = 그릇 반 높이. 매 프레임 부름
local MARK_SEGS = 18
function Scene:setHoldMark(state, center, d, rim)
	local mk = self.holdMark
	if not state then
		if mk then
			for _, seg in ipairs(mk.segs) do
				seg.Transparency = 1
			end
			mk.label.Visible = false
		end
		return
	end
	if not mk then
		mk = { segs = {} }
		for k = 1, MARK_SEGS do
			mk.segs[k] = part(self.model, "HoldMark", Vector3.new(0.1, 0.05, 0.05), CFrame.new(center), Color3.fromRGB(255, 226, 90), Enum.Material.Neon, { CastShadow = false })
		end
		local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
		local screen = pg:FindFirstChild("MachineMakingScreen")
		local t = Instance.new("TextLabel")
		t.Name = "HoldMarkLabel"
		t.AnchorPoint = Vector2.new(0.5, 0)
		t.Size = UDim2.fromOffset(170, 30)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255, 236, 120)
		t.TextStrokeTransparency = 0.1
		t.Text = "▲ 여기에 대요"
		t.ZIndex = 5
		t.Parent = screen
		mk.label, mk.screen = t, screen
		self.holdMark = mk
	end
	local r = d * 0.6
	local y = center.Y + (rim or 0.3) + 0.03
	local seg = 2 * math.pi * r / MARK_SEGS * 0.55 -- 점선: 고리 둘레의 55%만
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 6)
	local under = state == "under"
	for k, p in ipairs(mk.segs) do
		local a = (k / MARK_SEGS) * 2 * math.pi + os.clock() * 0.8
		local pos = Vector3.new(center.X + math.cos(a) * r, y, center.Z + math.sin(a) * r)
		p.Size = Vector3.new(seg, 0.05, 0.05)
		p.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a))) * CFrame.Angles(0, math.rad(90), 0)
		p.Color = under and Color3.fromRGB(120, 230, 120) or Color3.fromRGB(255, 226, 90)
		p.Transparency = under and 0.2 or (state == "near" and 0.05 or 0.15) + 0.3 * pulse
	end
	local cam = workspace.CurrentCamera
	local v, on = cam:WorldToViewportPoint(Vector3.new(center.X, y - 2 * (rim or 0.3) - 0.15, center.Z))
	local inset = (mk.screen and mk.screen.IgnoreGuiInset) and 0 or GuiService:GetGuiInset().Y
	mk.label.Position = UDim2.fromOffset(v.X, v.Y - inset)
	mk.label.Visible = on and not under
end

-- 설탕(소다) 줄기: top(배출구·기둥 끝)에서 국자까지
function Scene:setStream(on, top, color)
	local s = self.stream
	if not on then
		s.Transparency = 1
		return
	end
	top = top or self.spoutPos
	local bottom = self:bowlPos() + Vector3.new(0, 0.2, 0)
	local len = math.max(0.1, top.Y - bottom.Y)
	s.Size = Vector3.new(0.14, len, 0.14)
	s.CFrame = CFrame.new(Vector3.new(top.X, (top.Y + bottom.Y) / 2, top.Z))
	s.Color = color or C.white
	s.Transparency = 0.1
end

-- 반죽 줄기: from(국자 입) → to(칸)
function Scene:setPourStream(from, to, color)
	local s = self.pourStream
	if not from then
		s.Transparency = 1
		return
	end
	local len = math.max(0.1, (from - to).Magnitude)
	s.Size = Vector3.new(0.22, len, 0.22)
	s.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(math.rad(90), 0, 0)
	if color then
		s.Color = color
	end
	s.Transparency = 0
end

-- 금형판 칸 반죽 (2026-11-27 사용자 "손 작업대처럼 누르기 전 볼록, 누르면 납작, 완성품도 손 작업대와 똑같이"):
-- 손 작업대 3D 반죽(BatterMesh, EditableMesh) 하나를 만들고 칸마다 그 메시 부품을 복제해 놓음. 복제 부품은 같은 EditableMesh를
-- 그대로 보여 줘서(2026-11-27 Studio 확인: MeshContent.Object 같음) 모양(언덕 → 누른 턱 → 찍힌 홈)은 한 번만 계산하고
-- 칸마다 크기만 다름. 손 작업대와 같은 비율: 막 부은 언덕 = 다 누른 지름의 42%, 누른 두께 h → 보이는 높이 (Dalgona:setThickness와 같은 식)
-- EditableMesh를 못 쓰면 예전 공 모양 반죽.
local HAND_D = 2.2 -- 손 작업대 다 누른 달고나 지름 (스터드) — 칸 크기와의 비율로 높이·모양 선을 줄임
local MOUND_D = 0.72 -- 막 부은 언덕 지름 / 칸 (누르면 칸 가득 1.0까지 퍼짐)
local VIS_K = 1.87 -- 보이는 높이 배율: 막 부은 언덕 높이 = 칸 지름의 20%가 되게 (손 작업대 두께 식 × 칸 비율 × 이 값)
local function tint(c)
	local k = 1 / (BatterMesh.TOP_DIM or 1)
	return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end
-- BatterMesh:place와 같은 약속 (메시 경계 ±BOUND = 크기, 가장자리 반지름 1 = 지름/2, 기본 꼭대기 TOP = 높이)
local function placeBatter(p, center, width, height, rot)
	local B, T = BatterMesh.BOUND or 1.8, BatterMesh.TOP or 0.88
	local sy = math.max(height / T, 0.01)
	p.Size = Vector3.new(math.max(width * B, 0.02), sy, math.max(width * B, 0.02))
	p.CFrame = CFrame.new(center.X, center.Y + sy / 2, center.Z) * rot
end
-- 칸 i의 반죽 부품 (첫 칸 = 원본 메시 부품, 나머지 = 복제)
function Scene:batterPart(i, color)
	local c = self.cavities[i]
	if c.bpart then
		return c.bpart
	end
	if self.bm == nil then
		local b = BatterMesh.new(self.model, color or Color3.fromRGB(206, 152, 96), math.random(1, 9999))
		self.bm = b or false
		if b then
			b.part.Transparency = 0
			b:setShape(0, 0.5)
		end
	end
	local bm = self.bm
	if not bm then
		return nil
	end
	local p
	if not self.bmUsed then
		self.bmUsed = true
		p = bm.part
		c.master = true
	else
		p = bm.part:Clone()
		p.Parent = self.model
	end
	p.Name = "Batter" .. i
	p.CastShadow = false
	if color then
		p.Color = tint(color)
	end
	Toon.outline(p)
	c.bpart = p
	return p
end
function Scene:domeH(fill)
	return self.cavD * 0.98 * 0.2 * (0.5 + 0.5 * math.clamp(fill, 0, 1))
end
function Scene:setCavityFill(i, fill, shape, color)
	local c = self.cavities[i]
	c.fill = fill
	if fill <= 0.02 then
		return
	end
	local p = self:batterPart(i, color)
	if p then
		local D1 = self.cavD * 0.98
		local f = math.min(fill, 1)
		local d = D1 * MOUND_D * (0.55 + 0.45 * f) * (1 + 0.6 * math.max(0, fill - 1))
		local h = self:domeH(fill)
		placeBatter(p, c.pos, d, h, self.rot)
		if color then
			p.Color = tint(color)
		end
		c.domeD, c.domeH = d, h
	else
		if not c.dome then
			c.dome = part(self.model, "Batter" .. i, Vector3.new(0.1, 0.05, 0.1), CFrame.new(c.pos), color or Color3.fromRGB(206, 152, 96), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball, CastShadow = false })
		end
		local k = math.clamp(fill, 0, 1.15)
		local d = self.cavD * (0.35 + 0.6 * k)
		c.dome.Size = Vector3.new(d, self:domeH(fill) * 2, d)
		c.dome.CFrame = CFrame.new(c.pos) * self.rot
		if color then
			c.dome.Color = color
		end
		c.domeD, c.domeH = d, self:domeH(fill)
	end
	if fill > 1.15 and not c.spill then
		-- 넘침: 둘레로 흘러나온 얇은 반죽
		c.spill = cyl(self.model, "Spill" .. i, 0.02, self.cavD * 1.3, c.pos + Vector3.new(0, 0.005, 0), color or Color3.fromRGB(214, 150, 70), Enum.Material.SmoothPlastic, { Transparency = 0.2 })
	end
end

-- 가장 높은 반죽 꼭대기 높이 (칸 윗면 기준, 스터드)
function Scene:domeTop()
	local h = 0
	for _, c in ipairs(self.cavities) do
		h = math.max(h, c.domeH or 0)
	end
	return h
end

-- 붓고 난 뒤 부은 결이 낮아지며 매끈해짐 (손 작업대처럼). k = 0~1
function Scene:settleBatter(k)
	if self.bm then
		k = math.clamp(k, 0, 1)
		self.bm:setShape(0, 0.5 * (1 - k))
		self.bm:setPores(1 - 0.6 * k)
	end
end

-- 모양 선 (CutterShapes 외곽선·안쪽 구멍·장식선)을 칸 가운데 기준 세계 선분으로 (화면 위쪽 = 기계 뒤 +Z, 오른쪽 = -X)
function Scene:shapeSegs(shape, center)
	local data
	for _, s in ipairs(CutterShapes) do
		if s.id == shape then
			data = s
			break
		end
	end
	if not data then
		return nil
	end
	local k = self.cavD * 0.98 / HAND_D
	local w = math.max(0.012, 0.07 * k)
	local segs, closed = {}, {}
	local function add(pts, isClosed, outline)
		local n = #pts
		for i = 1, (isClosed and n or n - 1) do
			local a, b = pts[i], pts[i % n + 1]
			local s = {
				a = center + self.dir(Vector3.new(-a[1] * k, 0, a[2] * k)),
				b = center + self.dir(Vector3.new(-b[1] * k, 0, b[2] * k)),
				w = w,
			}
			table.insert(segs, s)
			if outline then
				table.insert(closed, s)
			end
		end
	end
	add(data.outline, true, true)
	for _, h in ipairs(data.holes or {}) do
		add(h, true, true)
	end
	for _, l in ipairs(data.lines or {}) do
		local pts = {}
		for _, p in ipairs(l) do
			if type(p) == "table" then
				table.insert(pts, p)
			end
		end
		if #pts >= 2 then
			add(pts, l.closed == true, false)
		end
	end
	local function isInside(p)
		local cross = 0
		for _, s in ipairs(closed) do
			local az, bz = s.a.Z, s.b.Z
			if (az > p.Z) ~= (bz > p.Z) then
				local x = s.a.X + (p.Z - az) / (bz - az) * (s.b.X - s.a.X)
				if x > p.X then
					cross += 1
				end
			end
		end
		return cross % 2 == 1
	end
	return segs, isInside
end

-- 누르기 시작: 금형 모양(찍힐 홈)을 메시에 미리 계산 (원본 부품을 다 누른 크기로 잠깐 놓고 손 작업대 prepareStamp)
function Scene:prepareStamp(shape)
	local bm = self.bm
	local c
	for _, cc in ipairs(self.cavities) do
		if cc.master then
			c = cc
		end
	end
	if not (bm and c) then
		return
	end
	local cf, size = bm.part.CFrame, bm.part.Size
	placeBatter(bm.part, c.pos, self.cavD * 0.98, 0.1, self.rot)
	local segs, isInside = self:shapeSegs(shape, c.pos)
	if segs then
		bm:prepareStamp(segs, isInside)
		self.stampReady = true
	end
	bm.part.Size, bm.part.CFrame = size, cf
end

-- 누르는 동안 (h = 손 작업대 두께 값, h0 0.45 → 목표 0.08): 손 작업대와 같은 식으로 언덕이 납작한 원판(가장자리 둥근 턱)이 되고
-- 칸 크기까지 퍼지며, 반쯤부터 금형 모양 홈이 찍힘. 반환 = 가장 높은 반죽 윗면 높이 (누름판 아랫면 자리)
function Scene:pressBatter(h, target)
	local P = Config.Press
	local D1 = self.cavD * 0.98
	local flat = math.clamp((P.h0 * 0.95 - h) / (P.h0 * 0.95 - 0.1), 0, 1)
	local vis = h * 0.75 * (1 - 0.3 * (1 - flat)) * (1 + 0.7 * flat) * (D1 / HAND_D) * VIS_K
	local prog = math.clamp((P.h0 - h) / (P.h0 - target), 0, 1) -- 누른 정도 (칸 크기까지 퍼짐)
	local top = 0
	if self.bm then
		self.bm:setShape(flat, 0)
		self.bm:setPores(0.4 * (1 - flat))
		if self.stampReady then
			self.bm:setStamp(math.clamp((flat - 0.35) / 0.65, 0, 1) * math.clamp(target / math.max(h, 1e-3), 0, 1.15))
		end
		for _, c in ipairs(self.cavities) do
			if c.bpart then
				local f = math.clamp(c.fill or 1, 0.3, 1.15)
				local d = D1 * (MOUND_D + (1 - MOUND_D) * math.sqrt(prog)) * (0.9 + 0.1 * math.min(f, 1))
				local hh = vis * (0.85 + 0.15 * math.min(f, 1))
				placeBatter(c.bpart, c.pos, d, hh, self.rot)
				c.domeH = hh
				top = math.max(top, hh)
			end
		end
		return top
	end
	-- 예전 공 모양 반죽
	for _, c in ipairs(self.cavities) do
		if c.dome then
			local hh = math.max(0.012, math.min(c.domeH or vis, vis))
			local d = math.min(self.cavD * 1.05, (c.domeD or self.cavD) * (1 + 0.15 * flat))
			c.dome.Size = Vector3.new(d, hh * 2, d)
			c.dome.CFrame = CFrame.new(c.pos) * self.rot
			top = math.max(top, hh)
		end
	end
	return top
end

-- 다 누른 뒤: 손 작업대 달고나 색(제작 기록으로 정한 겉모습)으로. 3D 반죽이 없으면 예전처럼 찍힌 달고나 모델
function Scene:finishCavities(shape, color)
	for i, c in ipairs(self.cavities) do
		if c.bpart then
			if color then
				c.bpart.Color = tint(color)
			end
		elseif c.dome then
			local col = color or c.dome.Color
			c.dome:Destroy()
			c.dome = nil
			c.look = DalgonaLook.build({ s = shape, g = "Good" }, { diameter = self.cavD * 0.98, stick = false })
			c.look.Name = "Fill" .. i
			for _, p in ipairs(c.look:GetDescendants()) do
				if p:IsA("BasePart") and p.Name == "Disc" then
					p.Color = col
				end
			end
			c.look:PivotTo(CFrame.new(c.pos + Vector3.new(0, 0.012, 0)) * self.rot * CFrame.Angles(0, math.pi, 0))
			c.look.Parent = self.model
		end
	end
end

-- 다 굳으면 막대째 들어 올림
function Scene:liftCavities(dy)
	for _, c in ipairs(self.cavities) do
		for _, inst in ipairs({ c.bpart, c.look, c.stick }) do
			if inst then
				if inst:IsA("BasePart") then
					inst.CFrame += Vector3.new(0, dy, 0)
				else
					inst:PivotTo(inst:GetPivot() + Vector3.new(0, dy, 0))
				end
			end
		end
	end
end

-- 누름판 투명하게 (손 작업대처럼 누르는 동안은 사라져서 반죽이 눌리는 게 보임). k = 0 보임 ~ 1 안 보임
function Scene:fadePresser(k)
	local pr = self.press
	if not pr then
		return
	end
	for _, d in ipairs(pr.model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = k
		elseif d:IsA("Highlight") then
			d.Enabled = k < 0.5
		end
	end
end

-- 칸 i의 막대 끝 자리 (칸 가운데에서 앞(-Z) 쪽으로 빠져나옴, 볼록한 반죽 속에 묻힘)
function Scene:stickSpot(i)
	local c = self.cavities[i]
	return c.pos + self.dir(Vector3.new(0, 0.015, -self.cavD * 0.1))
end

-- 금형판 붓기 판(UI) 위 칸 자리: uv (위 = 기계 뒤 +Z, 오른쪽 = 화면 오른쪽 -X), 칸 반지름 비율
function Scene:moldPadLayout()
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local locals = {}
	for i, c in ipairs(self.cavities) do
		local l = self.origin:PointToObjectSpace(c.pos)
		locals[i] = l
		minX, maxX = math.min(minX, l.X), math.max(maxX, l.X)
		minZ, maxZ = math.min(minZ, l.Z), math.max(maxZ, l.Z)
	end
	local r = self.cavD / 2
	local span = math.max(maxX - minX, maxZ - minZ) + 2 * r + self.cavD * 0.8
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local uvs = {}
	for i, l in ipairs(locals) do
		uvs[i] = { 0.5 + (cx - l.X) / span, 0.5 + (cz - l.Z) / span }
	end
	return uvs, r / span
end

-- 카메라 자리 (Station을 안 쓰는 단계: 동전 · 설탕 · 붓기 · 누르기 · 막대 · 헹굼): target, 거리, 내려다보는 각도°
function Scene:shot(name)
	local t, d, p
	if self.stage == 3 then
		if name == "coin" then
			t, d, p = self.at(Vector3.new(0, 3.9, -2.45)), 19, 12
		elseif name == "sugar" or name == "sodaPillar" then
			t, d, p = self.at(Vector3.new(1.1, 2.0, -1.4)), 15, 26
		elseif name == "cup" then
			-- 녹이기·소다: 열선 컵이 보라 판 아래 움푹한 곳이라 위에서는 가려짐 → 앞에서 비스듬히 들여다봄 (2026-11-27)
			t, d, p = self.at(Vector3.new(self.L.cup.x, 1.35, self.L.cup.z)), 8, 34
		elseif name == "pour" or name == "stick" or name == "press" then
			t, d, p = self.plateCenter + self.dir(Vector3.new(0.6, 0, -0.4)), 12, 50
		else
			t, d, p = self.waterPos:Lerp(self.burnerPos, 0.5), 18, 35
		end
	else
		if name == "coin" then
			t, d, p = self.at(Vector3.new(0, 2.3, -1.6)), 22, 10
		elseif name == "sugar" then
			t, d, p = self.at(Vector3.new(0, 0.9, -1.8)), 13, 18
		elseif name == "pour" or name == "stick" or name == "press" then
			-- 2026-11-27 사용자 "붓기 때 금형틀이 잘 안 보임": 뒤쪽 위에 들린 금형판 가운데를 앞에서 내려다봄
			t, d, p = self.plateCenter + self.dir(Vector3.new(0, 0, -0.25 * self.S)), 6, 52
		else
			t, d, p = self.waterPos:Lerp(self.burnerPos, 0.5), 18, 45
		end
	end
	self.camTarget = t
	d *= self.L.cam or 1
	local cam = workspace.CurrentCamera
	local vp = cam.ViewportSize
	if vp.X / math.max(vp.Y, 1) < 1.2 then
		d *= 1.6 -- 세로 화면: 더 멀리
	end
	local r = math.rad(p)
	local eye = t + self.dir(Vector3.new(0, math.sin(r) * d, -math.cos(r) * d))
	return CFrame.lookAt(eye, t)
end

function Scene:destroy()
	if self.bm then
		pcall(function()
			self.bm:destroy()
		end)
		self.bm = nil
	end
	if self.holdMark then
		self.holdMark.label:Destroy()
	end
	if self.S_ then
		pcall(function()
			self.S_:clearFx()
		end)
	end
	if self.inShop then
		ViewClear.stop()
	end
	for p, v in pairs(self.hidden) do
		if p.Parent then
			p.LocalTransparencyModifier = v
		end
	end
	table.clear(self.hidden)
	for g, v in pairs(self.hiddenGui) do
		if g.Parent then
			g.Enabled = v
		end
	end
	table.clear(self.hiddenGui)
	self.model:Destroy()
end

return Scene

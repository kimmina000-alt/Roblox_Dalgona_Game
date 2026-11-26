-- 2·3단계 기계 직접 만들기 장면 (MachineMake가 씀). 2026-11-26 사용자: "스튜디오에 새로 넣은 2단계 3단계 기계 … 해당 3D 에셋에서 만드는 걸로"
-- 사용자 기계 메시(Stage2Machine 빨간 철제 기계 / Stage3Machine 분홍 판매기, tools/blender/stage23_user.py)를 그대로 세우고,
-- 메시 위 자리(동전 구멍 · 설탕 배출구/버튼 · 화구 · 금형판 칸)에 움직이는 것을 올린다.
-- 2026-11-26 사용자 "손 작업대 화면 구현 방식 그대로": 국자·나무젓가락·소다통·설탕 더미·녹는 결정·젓가락 길·부푸는 반죽은
-- 내 가게 손 작업대(Workstations.mine)를 복제해 기계 화구 위에 얹고(국자·젓가락·소다통만 보이게), 손 작업대 단계 모듈
-- (Steps/Melt, Steps/Soda)이 그 Station으로 그대로 돈다 (Scene:station()).
-- 메시는 서버 MachineMakeService가 ReplicatedStorage.Assets.MachineMeshes로 복사해 둠 (없으면 상자 모양으로 대신).
-- 자리 값은 메시 기준(바닥 가운데 = 원점, 앞 = -Z, 화면 오른쪽 = -X, 메시 단위). 2026-11-26 메시 꼭짓점(EditableMesh)으로 다시 잼.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DalgonaLook = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DalgonaLook"))
local Making = script.Parent:WaitForChild("Making")
local Station = require(Making:WaitForChild("Station"))
local Workstations = require(Making:WaitForChild("Workstations"))
local ViewScale = require(Making:WaitForChild("ViewScale"))

local Scene = {}
Scene.__index = Scene

local ORIGIN = CFrame.new(0, 900, 0)
local C = {
	dark = Color3.fromRGB(70, 72, 78),
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
		S = 2.5,
		size = Vector3.new(4.86, 5.86, 3.23),
		coins = { Vector3.new(1.5, 1.36, -1.65), Vector3.new(-1.5, 1.36, -1.65) }, -- 앞면 동전 구멍 2개 (어느 쪽이든)
		press = Vector3.new(0, 0.75, -1.65), -- 설탕: 배출구를 꾹 누름
		spout = Vector3.new(0, 0.55, -1.75), -- 설탕 나오는 끝
		sugarLadle = Vector3.new(0, 0.12, -1.95), -- 설탕 받을 때 국자 그릇 바닥 자리 (배출구 아래, 기계 앞)
		burner = Vector3.new(1.4, 4.52, -0.1), -- 윗판 왼쪽 화구 윗면
		burnerD = 0.6,
		sodaCup = { pos = Vector3.new(0.04, 4.83, -0.58), r = 0.22 }, -- 가운데 원통 (테두리 높이, 안쪽 반지름) — 소다를 여기에 (사용자 2026-11-26)
		cavY = 5.92, -- 금형판 윗면 (뒤쪽에 들린 판, 칸 8개)
		cavD = 0.46,
		cavs = { 1.9, 1.39, 0.82, 0.31, -0.26, -0.83, -1.4, -1.97 }, -- 칸 x (z = cavZ)
		cavZ = 1.15,
		markCavities = false, -- 메시에 칸이 그려져 있음
		-- 메시가 앞판·윗판·금형판뿐이라 옆·뒤가 뚫려 보임 (사용자 2026-11-26 "2단계 기계 옆면 없음") → 몸통 벽을 Part로
		-- 메시 몸통: x ±2.43, 앞판 z -1.11, 뒤 z 1.61, 윗판 높이 4.52
		body = { x = 2.43, zFront = -1.11, zBack = 1.61, top = 4.5 },
		shelfY = 4.5, -- 물그릇 올린 옆 선반 높이
		ladleRest = Vector3.new(-1.3, 0.1, -2.3),
	},
	[3] = {
		S = 2,
		size = Vector3.new(6.32, 7.13, 4.97),
		coins = { Vector3.new(-0.94, 4.84, -2.45) }, -- 앞판 동전 넣는 곳
		press = Vector3.new(0.29, 4.13, -2.45), -- "설탕" 버튼
		spout = Vector3.new(1.66, 2.6, -1.3), -- 왼쪽 관 (컵 위)
		-- 검은 컵(열선): 가운데 (1.90, -1.21), 테두리 높이 1.02, 바깥 반지름 0.94, 안쪽 0.64, 안쪽 바닥 0.40 (꼭짓점으로 잼)
		cup = { x = 1.9, z = -1.21, rim = 1.02, rOut = 0.94, rIn = 0.64, floor = 0.4 },
		sugarLadle = Vector3.new(1.9, 1.02, -1.21), -- 설탕도 컵 위 국자로 받음 (관이 컵 위)
		burner = Vector3.new(1.9, 1.02, -1.21), -- 국자 받침 = 컵 테두리
		-- 오른쪽 검은 판: 메시 판(x -2.85~-0.42, z -2.35~-0.20, 윗면 1.48)이 5칸보다 좁음 (사용자 2026-11-26 "다섯 개 다 들어가게 옆으로 키워")
		-- → 옆으로 넓힌 판을 Part로 덮고 칸을 고르게
		tray = { x0 = -3.1, x1 = -0.1, z0 = -2.35, z1 = -0.2, top = 1.5 },
		cavY = 1.5,
		cavD = 0.7,
		cavGrid = { -- 5칸: 앞줄 3 + 뒷줄 2
			Vector3.new(-0.65, 0, -1.75), Vector3.new(-1.6, 0, -1.75), Vector3.new(-2.55, 0, -1.75),
			Vector3.new(-1.12, 0, -0.8), Vector3.new(-2.08, 0, -0.8),
		},
		markCavities = true, -- 판이 민판이라 칸 자국을 올림
		shelfY = 1.7,
		ladleRest = Vector3.new(0.3, 0.45, -1.5),
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

local function machineMesh(stage, parent, cf, S, L)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and (assets:FindFirstChild("MachineMeshes") or assets:WaitForChild("MachineMeshes", 3))
	local src = folder and (folder:FindFirstChild("Stage" .. stage .. "Machine") or folder:WaitForChild("Stage" .. stage .. "Machine", 2))
	if src then
		local m = src:Clone()
		m.Anchored = true
		m.CanCollide = false
		m.CanQuery = false
		m.CanTouch = false
		m.Size = L.size * S
		m.CFrame = cf * CFrame.new(0, L.size.Y * S / 2, 0)
		m.Parent = parent
		return m
	end
	-- 대신: 상자 (메시가 아직 안 왔을 때)
	return part(parent, "MachineBox", L.size * S, cf * CFrame.new(0, L.size.Y * S / 2, 0), stage == 3 and Color3.fromRGB(240, 150, 176) or Color3.fromRGB(200, 50, 50), Enum.Material.Metal)
end

-- 부품 상자를 세계 축으로 본 가로(X)·세로(Z) 폭
local function flatWidth(p)
	local cf, s = p.CFrame, p.Size
	local r, u, k = cf.RightVector, cf.UpVector, cf.LookVector
	local wx = math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(k.X) * s.Z
	local wz = math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(k.Z) * s.Z
	return math.max(wx, wz)
end

-- stage: 2 / 3, cavities: 이번 판 칸 수(=개수), shape: 도안 id
function Scene.new(stage, cavities, shape)
	local self = setmetatable({}, Scene)
	local L = LAYOUT[stage] or LAYOUT[2]
	local S = L.S
	local m = Instance.new("Model")
	m.Name = "MachineMakeScene"
	self.model = m
	self.origin = ORIGIN
	self.stage = stage
	self.S = S
	self.L = L
	local O = ORIGIN.Position
	local function at(v)
		return O + v * S
	end
	self.at = at
	-- 바닥(탁자)·뒷벽 (카메라에 하늘이 안 보이게)
	part(m, "Floor", Vector3.new(90, 1, 70), CFrame.new(O + Vector3.new(0, -0.5, 10)), C.floor, Enum.Material.WoodPlanks)
	part(m, "Wall", Vector3.new(90, 60, 1), CFrame.new(O + Vector3.new(0, 25, L.size.Z * S / 2 + 6)), C.wall, Enum.Material.Plaster)
	self.machine = machineMesh(stage, m, ORIGIN, S, L)

	-- 2단계 몸통 옆·뒤 벽 (메시에 없음)
	if L.body then
		local b = L.body
		local h = b.top * S
		local depth = (b.zBack - b.zFront) * S
		local zc = (b.zBack + b.zFront) / 2 * S
		for _, sx in ipairs({ 1, -1 }) do
			part(m, "BodySide", Vector3.new(0.08, h, depth), CFrame.new(O + Vector3.new(sx * (b.x * S - 0.04), h / 2, zc)), C.red, Enum.Material.Metal)
		end
		part(m, "BodyBack", Vector3.new(b.x * 2 * S, h, 0.08), CFrame.new(O + Vector3.new(0, h / 2, b.zBack * S - 0.04)), C.red, Enum.Material.Metal)
	end

	self.coinList = {}
	for _, c in ipairs(L.coins) do
		table.insert(self.coinList, at(c))
	end
	self.coinPos = self.coinList[1]
	self.pressPos = at(L.press)
	self.spoutPos = at(L.spout)
	self.sugarLadle = at(L.sugarLadle)
	self.burnerPos = at(L.burner)

	-- 화구 열선 빛 (켜지면 빨갛게). 3단계는 검은 컵 "안쪽"이 빨갛게 (사용자 2026-11-26): 안쪽 바닥 원판 + 안벽을 따라 세운 열선 12개
	self.glowParts = {}
	if L.cup then
		local cu = L.cup
		local cpos = O + Vector3.new(cu.x, 0, cu.z) * S
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
	-- 설탕 줄기 (누르는 동안)
	self.stream = part(m, "SugarStream", Vector3.new(0.14, 1, 0.14), CFrame.new(self.spoutPos), C.white, Enum.Material.Sand, { Transparency = 1, CastShadow = false })
	-- 붓는 반죽 줄기
	self.pourStream = part(m, "BatterStream", Vector3.new(0.22, 1, 0.22), CFrame.new(O), Color3.fromRGB(206, 152, 96), Enum.Material.SmoothPlastic, { Transparency = 1, CastShadow = false })

	-- 옆 선반: 화면 왼쪽(+X)·오른쪽(-X). 물그릇은 오른쪽, 3단계 소다통은 왼쪽(컵 가까이). 2단계 소다는 가운데 원통 안
	local half = L.size.X * S / 2
	local shelfY = L.shelfY * S
	local zShelf = -L.size.Z * S / 2 + 2.4
	part(m, "ShelfR", Vector3.new(3.4, shelfY, 4.2), CFrame.new(O + Vector3.new(-half - 2, shelfY / 2, zShelf)), C.shelf, Enum.Material.Wood)
	self.shelfLTop = O + Vector3.new(half + 2, shelfY, zShelf - 0.2)
	if not L.sodaCup then
		part(m, "ShelfL", Vector3.new(3.4, shelfY, 4.2), CFrame.new(O + Vector3.new(half + 2, shelfY / 2, zShelf)), C.shelf, Enum.Material.Wood)
	end
	self.waterPos = O + Vector3.new(-half - 2, shelfY, zShelf - 0.2)
	cyl(m, "Bowl", 0.6, 1.8, self.waterPos + Vector3.new(0, 0.3, 0), Color3.fromRGB(190, 190, 186), Enum.Material.Metal)
	self.water = cyl(m, "Water", 0.05, 1.55, self.waterPos + Vector3.new(0, 0.55, 0), C.water, Enum.Material.Glass, { Transparency = 0.35 })

	-- 금형판 (3단계: 넓힌 검은 판을 덮음)
	if L.tray then
		local t = L.tray
		local w, d = (t.x1 - t.x0) * S, (t.z1 - t.z0) * S
		part(m, "WideTray", Vector3.new(w, 0.16, d), CFrame.new(O + Vector3.new((t.x0 + t.x1) / 2 * S, t.top * S - 0.08, (t.z0 + t.z1) / 2 * S)), C.tray, Enum.Material.Metal)
	end
	local cavD = L.cavD * S
	self.cavD = cavD
	self.cavY = O.Y + L.cavY * S
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
	local cx, cz = 0, 0
	for i, v in ipairs(spots) do
		local pos = Vector3.new(O.X + v.X * S, self.cavY, O.Z + v.Z * S)
		cx += pos.X
		cz += pos.Z
		if L.markCavities then
			local mark = DalgonaLook.build({ s = shape, g = "Burnt" }, { diameter = cavD, stick = false })
			mark.Name = "Cavity" .. i
			for _, p in ipairs(mark:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CastShadow = false
					if p.Name == "Disc" then
						p.Color = Color3.fromRGB(30, 28, 28)
					end
				end
			end
			mark:PivotTo(CFrame.new(pos + Vector3.new(0, 0.005, 0)))
			mark.Parent = m
		end
		table.insert(self.cavities, { pos = pos, fill = 0, look = nil, stick = nil })
	end
	self.plateCenter = Vector3.new(cx / math.max(#spots, 1), self.cavY, cz / math.max(#spots, 1))
	self.ladleRest = at(L.ladleRest)
	m.Parent = workspace
	return self
end

-- 손 작업대 Station (국자·나무젓가락·소다통·설탕 더미·결정·거품 그대로). 내 가게 손 작업대를 복제해 화구 위에 얹음.
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
	if vs ~= nil and vs ~= 1 then
		ViewScale.setFull(ws, false)
	end
	clone.Name = "MachineStation"
	for _, k in ipairs({ "OwnerUserId", "ViewScale", "AtInside", "ViewOrigin", "PlotIndex" }) do
		clone:SetAttribute(k, nil)
	end
	-- 손 작업대 앞(+Z, 플레이어 쪽) = 기계 앞(-Z) → 180° 돌림 (화면 위쪽 = 기계 뒤)
	clone:PivotTo(CFrame.new(self.origin.Position) * CFrame.Angles(0, math.pi, 0))
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
	-- 국자·나무젓가락·소다통만 보이게
	local keep = {}
	for _, n in ipairs({ "Ladle", "Chopsticks", "SodaTub" }) do
		local c = clone:FindFirstChild(n)
		if c then
			keep[c] = true
		end
	end
	local function kept(d)
		local p = d.Parent
		while p and p ~= clone do
			if keep[p] then
				return true
			end
			p = p.Parent
		end
		return keep[d] == true
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then
			if d:IsA("ProximityPrompt") then
				d.Enabled = false
			else
				d:Destroy()
			end
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
	-- 소다통: 2단계는 가운데 원통 안 (통 몸통은 숨기고 소다 가루만, 원통 안쪽 크기로), 3단계는 왼쪽 선반 위
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
		-- 통 몸통·라벨만 숨김 (보이는 가루 = SodaPowderMesh, Soda는 원래 투명한 찍기 판정 자리)
		for _, d in ipairs(tub:GetDescendants()) do
			if d:IsA("BasePart") and (d.Name == "SodaCanMesh" or d.Name == "SodaLabelMesh" or d.Name == "Tub") then
				d.Transparency = 1
				d.CastShadow = false
			end
		end
	elseif powder then
		local cf, size = tub:GetBoundingBox()
		local bottom = cf.Position.Y - size.Y / 2
		local want = self.shelfLTop
		tub:PivotTo(tub:GetPivot() + Vector3.new(want.X - cf.Position.X, want.Y - bottom, want.Z - cf.Position.Z))
	end
	S.rest.SodaTub = tub:GetPivot()
	self.S_ = S
	return S
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

-- 설탕 줄기: 배출구 끝에서 국자까지
function Scene:setStream(on)
	local s = self.stream
	if not on then
		s.Transparency = 1
		return
	end
	local top = self.spoutPos
	local bottom = self:bowlPos() + Vector3.new(0, 0.2, 0)
	local len = math.max(0.1, top.Y - bottom.Y)
	s.Size = Vector3.new(0.14, len, 0.14)
	s.CFrame = CFrame.new(Vector3.new(top.X, (top.Y + bottom.Y) / 2, top.Z))
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

-- 금형판 칸 i에 붓는 반죽 (fill 0~1.3), 다 되면 shape 모양 달고나. color = 국자 반죽 색 (소다 뒤 Station 내용물 색)
function Scene:setCavityFill(i, fill, shape, color)
	local c = self.cavities[i]
	c.fill = fill
	if fill <= 0.02 then
		return
	end
	if not c.look then
		c.look = DalgonaLook.build({ s = shape, g = "Good" }, { diameter = self.cavD, stick = false })
		c.look.Name = "Fill" .. i
		c.look.Parent = self.model
	end
	-- 붓는 동안: 가운데부터 넓어짐
	local k = math.clamp(fill, 0, 1)
	for _, p in ipairs(c.look:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Transparency = fill < 0.15 and 0.5 or 0
			if color and p.Name == "Disc" then
				p.Color = color
			end
		end
	end
	c.look:ScaleTo(math.max(0.15, k))
	c.look:PivotTo(CFrame.new(c.pos + Vector3.new(0, 0.03 + 0.03 * math.min(fill, 1.3), 0)))
	if fill > 1.15 and not c.spill then
		-- 넘침: 둘레로 흘러나온 얇은 반죽
		c.spill = cyl(self.model, "Spill" .. i, 0.03, self.cavD * 1.3, c.pos + Vector3.new(0, 0.01, 0), color or Color3.fromRGB(214, 150, 70), Enum.Material.SmoothPlastic, { Transparency = 0.2 })
	end
end

-- 막대 꽂기: 칸 앞쪽(-Z, 화면 아래)으로 나옴
function Scene:addStick(i)
	local c = self.cavities[i]
	local L = self.cavD * 1.1
	c.stick = part(self.model, "Stick", Vector3.new(self.cavD * 0.1, self.cavD * 0.06, L), CFrame.new(c.pos + Vector3.new(0, 0.08, -self.cavD * 0.3 - L / 2)), Color3.fromRGB(236, 214, 170), Enum.Material.Wood)
end

-- 금형판 붓기 판(UI) 위 칸 자리: uv (위 = 기계 뒤 +Z, 오른쪽 = 화면 오른쪽 -X), 칸 반지름 비율
function Scene:moldPadLayout()
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, c in ipairs(self.cavities) do
		minX, maxX = math.min(minX, c.pos.X), math.max(maxX, c.pos.X)
		minZ, maxZ = math.min(minZ, c.pos.Z), math.max(maxZ, c.pos.Z)
	end
	local r = self.cavD / 2
	local span = math.max(maxX - minX, maxZ - minZ) + 2 * r + self.cavD * 0.8
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local uvs = {}
	for i, c in ipairs(self.cavities) do
		uvs[i] = { 0.5 + (cx - c.pos.X) / span, 0.5 + (cz - c.pos.Z) / span }
	end
	return uvs, r / span
end

-- 카메라 자리 (Station을 안 쓰는 단계: 동전 · 설탕 · 붓기 · 막대 · 헹굼): target, 거리, 내려다보는 각도°
function Scene:shot(name)
	local t, d, p
	if self.stage == 3 then
		if name == "coin" then
			t, d, p = self.at(Vector3.new(0, 3.9, -2.45)), 19, 12
		elseif name == "sugar" then
			t, d, p = self.at(Vector3.new(1.2, 2.2, -1.8)), 15, 22
		elseif name == "pour" or name == "stick" then
			t, d, p = self.plateCenter + Vector3.new(0.8, 0, 0), 12, 50
		else
			t, d, p = self.waterPos:Lerp(self.burnerPos, 0.5), 18, 35
		end
	else
		if name == "coin" then
			t, d, p = self.at(Vector3.new(0, 2.3, -1.6)), 22, 10
		elseif name == "sugar" then
			t, d, p = self.at(Vector3.new(0, 0.9, -1.8)), 13, 18
		elseif name == "pour" or name == "stick" then
			t, d, p = self.plateCenter, 9, 60
		else
			t, d, p = self.waterPos:Lerp(self.burnerPos, 0.5), 18, 45
		end
	end
	local cam = workspace.CurrentCamera
	local vp = cam.ViewportSize
	if vp.X / math.max(vp.Y, 1) < 1.2 then
		d *= 1.6 -- 세로 화면: 더 멀리
	end
	local r = math.rad(p)
	local eye = t + Vector3.new(0, math.sin(r) * d, -math.cos(r) * d)
	return CFrame.lookAt(eye, t)
end

function Scene:destroy()
	if self.S_ then
		pcall(function()
			self.S_:clearFx()
		end)
	end
	self.model:Destroy()
end

return Scene

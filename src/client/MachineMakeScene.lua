-- 2·3단계 기계 직접 만들기 장면 (MachineMake가 씀). 2026-11-26 사용자: "스튜디오에 새로 넣은 2단계 3단계 기계 … 해당 3D 에셋에서 만드는 걸로"
-- 사용자 기계 메시(Stage2Machine 빨간 철제 기계 / Stage3Machine 분홍 판매기, tools/blender/stage23_user.py)를 그대로 세우고,
-- 메시 위 자리(동전 구멍 · 설탕 배출구/버튼 · 화구 · 금형판 칸)에 국자·젓가락·반죽 같은 움직이는 것만 Part로 올린다.
-- 메시는 서버 MachineMakeService가 ReplicatedStorage.Assets.MachineMeshes로 복사해 둠 (없으면 상자 모양으로 대신).
-- 자리 값은 메시 기준(바닥 가운데 = 원점, 앞 = -Z, 화면 오른쪽 = -X)을 Studio에서 재서 적음. 크기는 S배로 키워 씀.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DalgonaLook = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DalgonaLook"))

local Scene = {}
Scene.__index = Scene

local ORIGIN = CFrame.new(0, 900, 0)
local C = {
	dark = Color3.fromRGB(70, 72, 78),
	iron = Color3.fromRGB(44, 42, 42),
	copper = Color3.fromRGB(214, 132, 72),
	wood = Color3.fromRGB(196, 150, 104),
	white = Color3.fromRGB(250, 250, 248),
	water = Color3.fromRGB(150, 196, 222),
	coil = Color3.fromRGB(255, 96, 40),
	floor = Color3.fromRGB(176, 140, 108),
	wall = Color3.fromRGB(238, 222, 196),
	shelf = Color3.fromRGB(150, 108, 74),
}

-- 메시 기준 자리 (S배 하기 전 값)
local LAYOUT = {
	[2] = {
		S = 2.5,
		ladle = 0.7, -- 국자 크기 배율
		size = Vector3.new(4.86, 5.86, 3.23),
		coins = { Vector3.new(1.5, 1.36, -1.65), Vector3.new(-1.5, 1.36, -1.65) }, -- 앞면 동전 구멍 2개 (어느 쪽이든)
		press = Vector3.new(0, 0.75, -1.65), -- 설탕: 배출구를 꾹 누름
		spout = Vector3.new(0, 0.55, -1.75), -- 설탕 나오는 끝
		sugarLadle = Vector3.new(0, 0.12, -1.95), -- 설탕 받을 때 국자 자리 (배출구 아래, 기계 앞)
		burner = Vector3.new(1.4, 4.52, -0.1), -- 윗판 왼쪽 화구
		burnerD = 0.6,
		cavY = 5.92, -- 금형판 윗면 (뒤쪽에 들린 판, 칸 8개)
		cavD = 0.46,
		cavs = { 1.9, 1.39, 0.82, 0.31, -0.26, -0.83, -1.4, -1.97 }, -- 칸 x (z = cavZ)
		cavZ = 1.15,
		markCavities = false, -- 메시에 칸이 그려져 있음
		shelfY = 4.5, -- 소다 통·물그릇 올린 옆 선반 높이
		ladleRest = Vector3.new(-1.3, 0.1, -2.3),
	},
	[3] = {
		S = 2,
		ladle = 0.85,
		size = Vector3.new(6.32, 7.13, 4.97),
		coins = { Vector3.new(-0.94, 4.84, -2.45) }, -- 앞판 동전 넣는 곳
		press = Vector3.new(0.29, 4.13, -2.45), -- "설탕" 버튼
		spout = Vector3.new(1.66, 2.6, -1.3), -- 왼쪽 관 (컵 위)
		sugarLadle = Vector3.new(1.7, 1.5, -1.4), -- 검은 컵(열선) 안
		burner = Vector3.new(1.7, 1.5, -1.4),
		burnerD = 1.3,
		cavY = 1.7, -- 오른쪽 검은 판
		cavD = 0.7,
		cavGrid = { -- 5칸: 앞줄 3 + 뒷줄 2
			Vector3.new(-0.75, 0, -1.8), Vector3.new(-1.6, 0, -1.8), Vector3.new(-2.45, 0, -1.8),
			Vector3.new(-1.17, 0, -0.95), Vector3.new(-2.03, 0, -0.95),
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
	local O = ORIGIN.Position
	local function at(v)
		return O + v * S
	end
	self.at = at
	-- 바닥(탁자)·뒷벽 (카메라에 하늘이 안 보이게)
	part(m, "Floor", Vector3.new(90, 1, 70), CFrame.new(O + Vector3.new(0, -0.5, 10)), C.floor, Enum.Material.WoodPlanks)
	part(m, "Wall", Vector3.new(90, 60, 1), CFrame.new(O + Vector3.new(0, 25, L.size.Z * S / 2 + 6)), C.wall, Enum.Material.Plaster)
	self.machine = machineMesh(stage, m, ORIGIN, S, L)

	self.coinList = {}
	for _, c in ipairs(L.coins) do
		table.insert(self.coinList, at(c))
	end
	self.coinPos = self.coinList[1]
	self.pressPos = at(L.press)
	self.spoutPos = at(L.spout)
	self.sugarLadle = at(L.sugarLadle)
	self.burnerPos = at(L.burner)
	self.ladleR = 0.9 * L.ladle * 0.75

	-- 화구 열선 빛 (켜지면 빨갛게)
	self.glow = cyl(m, "BurnerGlow", 0.04, L.burnerD * S, self.burnerPos + Vector3.new(0, 0.03, 0), C.coil, Enum.Material.Neon, { Transparency = 1, CastShadow = false })
	-- 설탕 줄기 (누르는 동안)
	self.stream = part(m, "SugarStream", Vector3.new(0.14, 1, 0.14), CFrame.new(self.spoutPos), C.white, Enum.Material.Sand, { Transparency = 1, CastShadow = false })

	-- 옆 선반: 화면 오른쪽(-X)에 소다 통, 왼쪽(+X)에 물그릇
	local half = L.size.X * S / 2
	local shelfY = L.shelfY * S
	part(m, "ShelfR", Vector3.new(3.4, shelfY, 4.2), CFrame.new(O + Vector3.new(-half - 2, shelfY / 2, -L.size.Z * S / 2 + 2.4)), C.shelf, Enum.Material.Wood)
	part(m, "ShelfL", Vector3.new(3.4, shelfY, 4.2), CFrame.new(O + Vector3.new(half + 2, shelfY / 2, -L.size.Z * S / 2 + 2.4)), C.shelf, Enum.Material.Wood)
	self.sodaPos = O + Vector3.new(-half - 2, shelfY, -L.size.Z * S / 2 + 2.2)
	cyl(m, "SodaCup", 1.2, 1.4, self.sodaPos + Vector3.new(0, 0.6, 0), Color3.fromRGB(196, 200, 206), Enum.Material.Metal)
	cyl(m, "SodaPowder", 0.1, 1.2, self.sodaPos + Vector3.new(0, 1.17, 0), C.white, Enum.Material.Sand)
	self.sodaTip = self.sodaPos + Vector3.new(0, 1.3, 0)
	self.waterPos = O + Vector3.new(half + 2, shelfY, -L.size.Z * S / 2 + 2.2)
	cyl(m, "Bowl", 0.6, 1.8, self.waterPos + Vector3.new(0, 0.3, 0), Color3.fromRGB(190, 190, 186), Enum.Material.Metal)
	self.water = cyl(m, "Water", 0.05, 1.55, self.waterPos + Vector3.new(0, 0.55, 0), C.water, Enum.Material.Glass, { Transparency = 0.35 })

	-- 금형판 칸
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

	-- 국자 (구리 그릇 + 손잡이 + 내용물), 크기 L.ladle배
	local k = L.ladle
	self.ladle = Instance.new("Model")
	self.ladle.Name = "Ladle"
	self.ladle.Parent = m
	self.ladleBowl = cyl(self.ladle, "Bowl", 0.5 * k, 1.8 * k, Vector3.zero, C.copper, Enum.Material.Metal)
	self.ladleIn = cyl(self.ladle, "Inside", 0.05, 1.5 * k, Vector3.new(0, 0.26 * k, 0), C.copper:Lerp(C.dark, 0.35), Enum.Material.Metal)
	part(self.ladle, "Handle", Vector3.new(0.25 * k, 0.18 * k, 3.4 * k), CFrame.new(0, 0.3 * k, -2.4 * k) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(70, 52, 40), Enum.Material.Wood)
	self.contents = cyl(self.ladle, "Contents", 0.06, 1.4 * k, Vector3.new(0, 0.28 * k, 0), C.white, Enum.Material.Sand, { Transparency = 1 })
	self.ladleK = k
	self.ladle.PrimaryPart = self.ladleBowl
	self.ladleRest = at(L.ladleRest)
	self:ladleTo(self.ladleRest)
	-- 나무젓가락 (보일 때만)
	self.stick = part(m, "Chopstick", Vector3.new(0.12, 0.12, 3.2), CFrame.new(O + Vector3.new(0, -5, 0)), C.wood, Enum.Material.Wood, { Transparency = 1 })
	self.stickTip = part(m, "StickSoda", Vector3.new(0.3, 0.3, 0.45), CFrame.new(O), C.white, Enum.Material.Sand, { Transparency = 1, Shape = Enum.PartType.Ball })
	m.Parent = workspace
	return self
end

-- 국자 그릇 가운데를 pos로 (손잡이는 화면 아래 = 앞 -Z 쪽)
function Scene:ladleTo(pos)
	-- 피벗 = 그릇(원기둥은 Z로 90° 돌려 세움) → 같은 돌림을 유지해야 그릇이 눕는다
	self.ladle:PivotTo(CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)))
end
function Scene:ladlePos()
	return self.ladleBowl.Position
end

-- 내용물: amount 0~1.4 (두께), color, material
function Scene:setContents(amount, color, mat)
	local c = self.contents
	if amount <= 0.01 then
		c.Transparency = 1
		return
	end
	local k = self.ladleK
	local h = (0.05 + 0.35 * math.clamp(amount, 0, 1.4)) * k
	c.Transparency = 0
	c.Size = Vector3.new(h, 1.4 * k, 1.4 * k)
	c.CFrame = CFrame.new(self.ladleBowl.Position + Vector3.new(0, 0.05 * k + h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	if color then
		c.Color = color
	end
	if mat then
		c.Material = mat
	end
end

-- 화구 빛 0~1
function Scene:setHeat(v)
	self.glow.Transparency = 1 - 0.75 * math.clamp(v, 0, 1)
end

-- 설탕 줄기: 배출구 끝에서 국자까지
function Scene:setStream(on)
	local s = self.stream
	if not on then
		s.Transparency = 1
		return
	end
	local top = self.spoutPos
	local bottom = self:ladlePos() + Vector3.new(0, 0.2, 0)
	local len = math.max(0.1, top.Y - bottom.Y)
	s.Size = Vector3.new(0.14, len, 0.14)
	s.CFrame = CFrame.new(Vector3.new(top.X, (top.Y + bottom.Y) / 2, top.Z))
	s.Transparency = 0.1
end

-- 젓가락: tip = 끝 자리, 손잡이는 화면 아래·오른쪽 쪽으로 기울임
function Scene:setStick(tip, visible)
	local s = self.stick
	if not visible then
		s.Transparency = 1
		self.stickTip.Transparency = 1
		return
	end
	s.Transparency = 0
	local dir = Vector3.new(-0.3, 1, -0.55).Unit
	local center = tip + dir * 1.6
	s.CFrame = CFrame.lookAt(center, center + dir)
end

function Scene:setStickSoda(tip, amount)
	local p = self.stickTip
	if amount <= 0 then
		p.Transparency = 1
		return
	end
	p.Transparency = 0
	local d = 0.22 + 0.07 * amount
	p.Size = Vector3.new(d, d, d * 1.3)
	p.CFrame = CFrame.new(tip + Vector3.new(-0.04, 0.1, -0.07))
end

-- 금형판 칸 i에 붓는 반죽 (fill 0~1.3), 다 되면 shape 모양 달고나
function Scene:setCavityFill(i, fill, shape)
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
		end
	end
	c.look:ScaleTo(math.max(0.15, k))
	c.look:PivotTo(CFrame.new(c.pos + Vector3.new(0, 0.03 + 0.03 * math.min(fill, 1.3), 0)))
	if fill > 1.15 and not c.spill then
		-- 넘침: 둘레로 흘러나온 얇은 반죽
		c.spill = cyl(self.model, "Spill" .. i, 0.03, self.cavD * 1.3, c.pos + Vector3.new(0, 0.01, 0), Color3.fromRGB(214, 150, 70), Enum.Material.SmoothPlastic, { Transparency = 0.2 })
	end
end

-- 막대 꽂기: 칸 앞쪽(-Z, 화면 아래)으로 나옴
function Scene:addStick(i)
	local c = self.cavities[i]
	local L = self.cavD * 1.1
	c.stick = part(self.model, "Stick", Vector3.new(self.cavD * 0.1, self.cavD * 0.06, L), CFrame.new(c.pos + Vector3.new(0, 0.08, -self.cavD * 0.3 - L / 2)), Color3.fromRGB(236, 214, 170), Enum.Material.Wood)
end

-- 카메라 자리: 각 단계에서 볼 곳 (target, 거리, 내려다보는 각도°)
function Scene:shot(name)
	local S = self.S
	local t, d, p
	if self.stage == 3 then
		if name == "coin" then
			t, d, p = self.at(Vector3.new(0, 3.9, -2.45)), 19, 12
		elseif name == "sugar" then
			t, d, p = self.at(Vector3.new(1.0, 2.8, -2)), 15, 18
		elseif name == "melt" then
			t, d, p = self.burnerPos, 10, 38
		elseif name == "soda" then
			t, d, p = (self.burnerPos + self.sodaPos) / 2, 15, 38
		elseif name == "pour" or name == "stick" then
			t, d, p = self.plateCenter, 10, 48
		else
			t, d, p = self.waterPos:Lerp(self.burnerPos, 0.5), 16, 35
		end
	else
		if name == "coin" then
			t, d, p = self.at(Vector3.new(0, 2.3, -1.6)), 22, 10
		elseif name == "sugar" then
			t, d, p = self.at(Vector3.new(0, 0.9, -1.8)), 13, 18
		elseif name == "melt" then
			t, d, p = self.burnerPos, 11, 50
		elseif name == "soda" then
			t, d, p = (self.burnerPos + self.sodaPos) / 2, 17, 48
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
	self.model:Destroy()
end

return Scene

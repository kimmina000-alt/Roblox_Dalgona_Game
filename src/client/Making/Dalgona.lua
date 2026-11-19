-- 철판 위 달고나 반죽: 울퉁불퉁한 언덕 → 두꺼운 원판 → 넓고 얇은 원판 (부피는 그대로)
-- 원 밖에 부으면 철판에 들러붙어 찌그러짐(타원). 갈라짐, 각인, Perfect 반짝임.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DalgonaConfig"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

-- 3D 반죽 메시 (tools/blender/dalgona_mesh.py, 유튜브 쇼츠 영상 분석): 두께에 따라 바뀜
--   붓는 중·막 부은 것(h ≥ 0.40): DalgonaMound  리본처럼 접히며 쌓인 주름진 언덕
--   한두 번 누른 것(0.16 ≤ h < 0.40): DalgonaPuff  둥글게 부푼 가장자리 + 기포 구멍
--   다 누른 것(h < 0.16): DalgonaFlat  얇고 평평, 고운 구멍 자국
-- 메시가 없으면 예전 원기둥 + 봉우리 모양
local MOUND_H, FLAT_H = 0.40, 0.16

local Dalgona = {}
Dalgona.__index = Dalgona

local UP = CFrame.Angles(0, 0, math.rad(90))

-- 탄 정도 b(0~1)에 따른 색·광택 (docs/DALGONA_LOOK.md: 참고 사진 분석)
-- 광택은 Reflectance를 거의 안 씀 (하늘이 비쳐 보라색이 됨) → 밝은 하이라이트 점(gloss 개수)으로 표현
local STOPS = {
	{ b = 0.0, base = Color3.fromRGB(216, 146, 62), rim = Color3.fromRGB(186, 112, 42), spot = Color3.fromRGB(176, 104, 44), refl = 0.0, gloss = 0 },
	{ b = 0.35, base = Color3.fromRGB(196, 116, 46), rim = Color3.fromRGB(150, 78, 30), spot = Color3.fromRGB(150, 80, 32), refl = 0.01, gloss = 3 },
	{ b = 0.65, base = Color3.fromRGB(168, 88, 40), rim = Color3.fromRGB(105, 48, 20), spot = Color3.fromRGB(90, 40, 16), refl = 0.02, gloss = 7 },
	{ b = 1.0, base = Color3.fromRGB(92, 42, 18), rim = Color3.fromRGB(38, 20, 10), spot = Color3.fromRGB(25, 15, 10), refl = 0.03, gloss = 10 },
}
local AMBER = Color3.fromRGB(190, 110, 40) -- 소다가 적어 촘촘한 반죽 (투명한 호박색)

local function sample(b)
	b = math.clamp(b, 0, 1)
	for i = 1, #STOPS - 1 do
		local a, z = STOPS[i], STOPS[i + 1]
		if b <= z.b then
			local t = (b - a.b) / (z.b - a.b)
			return {
				base = a.base:Lerp(z.base, t),
				rim = a.rim:Lerp(z.rim, t),
				spot = a.spot:Lerp(z.spot, t),
				refl = a.refl + (z.refl - a.refl) * t,
				gloss = a.gloss + (z.gloss - a.gloss) * t,
			}
		end
	end
	local z = STOPS[#STOPS]
	return { base = z.base, rim = z.rim, spot = z.spot, refl = z.refl, gloss = z.gloss }
end

-- 제작 기록 → 겉모습. records: ctx.records (melt, soda), st: ctx.state
-- 반환 { b = 탄 정도 0~1, dense = 소다 부족 0~1 }
function Dalgona.lookFor(records, st)
	local melt = records.melt or {}
	local soda = records.soda or {}
	local b = (st and st.burn or melt.burn or 0) * 1.4
	b += (1 - (melt.tempOk or 1)) * 0.25 -- 적정 온도를 벗어나 있던 시간
	b += math.clamp(((soda.delay or 0) - Config.Soda.bestDelay) * 0.08, 0, 0.3) -- 소다를 늦게
	b += math.clamp(((soda.amount or Config.Soda.idealMin) - Config.Soda.idealMax) / 0.85, 0, 1) * 0.35 -- 소다를 많이
	local dense = math.clamp((Config.Soda.idealMin - (soda.amount or Config.Soda.idealMin)) / Config.Soda.idealMin, 0, 1)
	return { b = math.clamp(b, 0, 1), dense = dense }
end

function Dalgona.new(station, center, color, volume, ellipse)
	local self = setmetatable({}, Dalgona)
	self.S = station
	self.center = center -- 철판 윗면 위의 점
	self.color = color
	self.V = volume
	self.e = ellipse or 0
	self.yaw = 0 -- 길쭉할 때 긴 쪽 방향 (붓는 경로 따라, Pour가 정함)
	self.h = Config.Press.h0
	self.body = station:fxPart(station.fx, { Name = "Dalgona", Shape = Enum.PartType.Cylinder, Color = color, Material = Enum.Material.SmoothPlastic })
	-- 가장자리 띠 2겹 (본체보다 살짝 낮고 넓음 → 위에서 보면 진한 테두리 그러데이션)
	self.rim = station:fxPart(station.fx, { Name = "DalgonaRim", Shape = Enum.PartType.Cylinder, Color = color, Material = Enum.Material.SmoothPlastic })
	self.rim2 = station:fxPart(station.fx, { Name = "DalgonaRim2", Shape = Enum.PartType.Cylinder, Color = color, Material = Enum.Material.SmoothPlastic })
	self.rimW = 0.06
	self.details = {}
	self.dome = station:fxPart(station.fx, { Name = "DalgonaDome", Shape = Enum.PartType.Ball, Color = color, Material = Enum.Material.SmoothPlastic })
	self.lumps = {}
	for i = 1, 4 do
		local a = i * math.pi / 2 + 0.4
		self.lumps[i] = { part = station:fxPart(station.fx, { Name = "DalgonaLump", Shape = Enum.PartType.Ball, Color = color, Material = Enum.Material.SmoothPlastic }), a = a, r = 0.25 + 0.08 * (i % 2) }
	end
	if Fx.template("DalgonaPuff") then
		self.meshes = {}
		for _, name in ipairs({ "DalgonaMound", "DalgonaPuff", "DalgonaFlat" }) do
			self.meshes[name] = Fx.mesh(name, station.fx, { Name = name, Color = color, Material = Enum.Material.SmoothPlastic, Transparency = 1 })
		end
		self.spin = math.random() * 2 * math.pi
		for _, p in ipairs({ self.body, self.rim, self.rim2, self.dome }) do
			p.Transparency = 1
		end
		for _, l in ipairs(self.lumps) do
			l.part.Transparency = 1
		end
	end
	self:setThickness(self.h)
	return self
end

-- 3D 메시 모드: 두께에 맞는 메시 하나만 보이고, 지름·높이를 맞춤
function Dalgona:placeMeshes(h, d, k)
	local c = self.center
	local stage = h >= MOUND_H and "DalgonaMound" or (h >= FLAT_H and "DalgonaPuff" or "DalgonaFlat")
	self.stage = stage
	for name, p in pairs(self.meshes) do
		if name ~= stage then
			p.Transparency = 1
		else
			p.Transparency = 0
			local height
			if name == "DalgonaMound" then
				height = h * 0.75 * 1.25 -- 접힌 언덕은 가운데가 솟음
				p.Size = Vector3.new(d * k * 0.95, height, d / k * 0.85)
			elseif name == "DalgonaPuff" then
				height = h * 0.75 * 1.1
				p.Size = Vector3.new(d * k, height, d / k)
			else
				height = math.max(h * 0.75, 0.03)
				p.Size = Vector3.new(d * k, height, d / k)
			end
			-- 길쭉하면 긴 쪽을 부은 방향으로, 둥글면 접힌 무늬가 천천히 돌아감
			p.CFrame = CFrame.new(c.X, c.Y + height / 2, c.Z) * CFrame.Angles(0, self.e > 0.05 and self.yaw or self.spin, 0)
		end
	end
	-- 표면 무늬(반점·얼룩·하이라이트)는 평평해진 뒤에만 (부푼 원판은 기포 구멍이 메시에 있음)
	local showDetails = stage == "DalgonaFlat"
	for _, dt in ipairs(self.details) do
		dt.part.LocalTransparencyModifier = showDetails and 0 or 1
	end
end

function Dalgona:diameter(h)
	return 2 * math.sqrt(self.V / (math.pi * h))
end

function Dalgona:setThickness(h)
	h = math.max(h, 0.04)
	self.h = h
	local d = self:diameter(h)
	local k = math.sqrt(1 + self.e)
	local c = self.center
	local w = self.rimW
	local turn = CFrame.Angles(0, self.yaw or 0, 0)
	local cy, sy = math.cos(self.yaw or 0), math.sin(self.yaw or 0)
	self.rim.Size = Vector3.new(h * 0.75 - 0.008, d * k, d / k)
	self.rim.CFrame = CFrame.new(c.X, c.Y + (h * 0.75 - 0.008) / 2, c.Z) * turn * UP
	self.rim2.Size = Vector3.new(h * 0.75 - 0.004, d * k * (1 - w), d / k * (1 - w))
	self.rim2.CFrame = CFrame.new(c.X, c.Y + (h * 0.75 - 0.004) / 2, c.Z) * turn * UP
	self.body.Size = Vector3.new(h * 0.75, d * k * (1 - 2 * w), d / k * (1 - 2 * w))
	self.body.CFrame = CFrame.new(c.X, c.Y + h * 0.375, c.Z) * turn * UP
	-- 표면 무늬(결정 반점·기포·얼룩)는 반지름에 맞춰 따라 퍼짐
	local top = c.Y + h * 0.75
	local R = d / 2
	for _, dt in ipairs(self.details) do
		local lx, lz = math.cos(dt.a) * dt.rr * R * k, math.sin(dt.a) * dt.rr * R / k
		local x = c.X + lx * cy + lz * sy
		local z = c.Z - lx * sy + lz * cy
		if dt.kind == "flat" then
			local size = dt.abs or dt.frac * R
			dt.part.Size = Vector3.new(0.006, size, size * dt.squash)
			dt.part.CFrame = CFrame.new(x, top + 0.002, z) * CFrame.Angles(0, dt.yaw, 0) * UP
		else
			dt.part.Size = Vector3.new(dt.abs, dt.abs * 0.6, dt.abs)
			dt.part.CFrame = CFrame.new(x, top + dt.abs * 0.12, z)
		end
	end
	if self.meshes and not self.simple then
		for _, p in ipairs({ self.body, self.rim, self.rim2, self.dome }) do
			p.Transparency = 1 -- simple(붓는 동안)에서 돌아올 때 원판 부품 숨김
		end
		self:placeMeshes(h, d, k)
		return
	end
	if self.meshes then
		-- simple: 메시 대신 매끈한 원판(본체·가장자리 띠) + 가운데 볼록 (붓는 동안, Pour)
		for _, p in pairs(self.meshes) do
			p.Transparency = 1
		end
		for _, p in ipairs({ self.body, self.rim, self.rim2 }) do
			p.Transparency = 0
		end
		for _, dt in ipairs(self.details) do
			dt.part.LocalTransparencyModifier = 1
		end
	end
	-- 언덕 모양: 두꺼울 때만 위에 둥근 봉우리와 덩어리
	local s = math.clamp((h - 0.22) / (Config.Press.h0 - 0.22), 0, 1)
	local dd = d * 0.8 * s
	self.dome.Transparency = s < 0.05 and 1 or 0
	self.dome.Size = Vector3.new(dd, math.max(dd * 0.55, 0.01), dd)
	self.dome.CFrame = CFrame.new(c.X, c.Y + h * 0.75, c.Z)
	for _, l in ipairs(self.lumps) do
		local ls = 0.35 * s
		l.part.Transparency = (s < 0.05 or self.simple) and 1 or 0
		l.part.Size = Vector3.one * math.max(ls, 0.01)
		l.part.CFrame = CFrame.new(c.X + math.cos(l.a) * l.r * d, c.Y + h * 0.6, c.Z + math.sin(l.a) * l.r * d)
	end
end

function Dalgona:topY()
	return self.center.Y + self.h * 0.75
end

function Dalgona:radius()
	return self:diameter(self.h) / 2
end

-- 겉모습의 본체 색 (붓는 줄기·떨어지는 반죽도 같은 색)
function Dalgona.colorFor(look)
	return sample(look.b).base:Lerp(AMBER, (look.dense or 0) * 0.5)
end

-- 탄 정도에 따른 색·광택·무늬 (look = Dalgona.lookFor 결과)
function Dalgona:setLook(look)
	self.look = look
	local b, dense = look.b, look.dense or 0
	local L = sample(b)
	local base = L.base:Lerp(AMBER, dense * 0.5)
	local refl = L.refl + dense * 0.01
	self.rimW = 0.05 + 0.07 * b
	for _, p in ipairs({ self.body, self.dome }) do
		p.Color = base
		p.Reflectance = refl
	end
	if self.meshes then
		-- 막 부은 반죽은 크림처럼 조금 밝고, 굳어 갈수록 본래 색
		self.meshes.DalgonaMound.Color = base:Lerp(Color3.fromRGB(236, 178, 96), 0.3)
		self.meshes.DalgonaPuff.Color = base
		self.meshes.DalgonaFlat.Color = base
	end
	for _, l in ipairs(self.lumps) do
		l.part.Color = base
		l.part.Reflectance = refl
	end
	self.rim2.Color = base:Lerp(L.rim, 0.5)
	self.rim.Color = L.rim
	self.rim.Reflectance = refl
	self.rim2.Reflectance = refl
	self.color = base
	for _, dt in ipairs(self.details) do
		dt.part:Destroy()
	end
	self.details = {}
	local rng = Random.new(math.floor(b * 1000) + 7)
	local function add(kind, props, rr, extra)
		local part = self.S:fxPart(self.S.fx, props)
		local dt = { part = part, kind = kind, a = rng:NextNumber(0, 2 * math.pi), rr = rr, yaw = rng:NextNumber(0, math.pi), squash = rng:NextNumber(0.6, 1) }
		for k, v in pairs(extra) do
			dt[k] = v
		end
		table.insert(self.details, dt)
	end
	-- 결정 반점: 잘 된 달고나의 밝은 점 (탈수록 사라짐)
	local speck = math.floor(30 * math.clamp(1 - b / 0.45, 0, 1) * (1 - dense))
	for _ = 1, speck do
		add("flat", { Name = "DalgonaSpeck", Shape = Enum.PartType.Cylinder, Color = base:Lerp(Color3.fromRGB(255, 236, 190), 0.55), Material = Enum.Material.SmoothPlastic, Transparency = 0.25 },
			math.sqrt(rng:NextNumber()) * 0.85, { abs = rng:NextNumber(0.025, 0.05) })
	end
	-- 얼룩: 눌어붙은 갈색·검은 자국 (b 0.2부터)
	local spots = math.floor(math.clamp((b - 0.15) / 0.85, 0, 1) * 7 + 0.5)
	for _ = 1, spots do
		add("flat", { Name = "DalgonaSpot", Shape = Enum.PartType.Cylinder, Color = L.spot, Material = Enum.Material.SmoothPlastic, Transparency = 0.15, Reflectance = refl },
			math.sqrt(rng:NextNumber()) * 0.6, { frac = rng:NextNumber(0.08, 0.16) + 0.06 * b })
	end
	-- 기포: 잘 되면 아주 작은 구멍 몇 개, 지나칠수록 크고 볼록, 소다가 적으면 적음
	local pores = math.floor((6 + 26 * math.clamp(b / 0.65, 0, 1)) * (1 - 0.7 * dense))
	for _ = 1, pores do
		local big = b > 0.45
		local size = big and rng:NextNumber(0.05, 0.1 + 0.08 * b) or rng:NextNumber(0.025, 0.045)
		if big then
			add("bump", { Name = "DalgonaBubble", Shape = Enum.PartType.Ball, Color = base:Lerp(Color3.fromRGB(255, 190, 110), 0.25), Material = Enum.Material.SmoothPlastic, Reflectance = refl },
				math.sqrt(rng:NextNumber()) * 0.8, { abs = size })
		else
			add("flat", { Name = "DalgonaPore", Shape = Enum.PartType.Cylinder, Color = L.rim:Lerp(L.spot, 0.5), Material = Enum.Material.SmoothPlastic, Transparency = 0.2 },
				math.sqrt(rng:NextNumber()) * 0.85, { abs = size })
		end
	end
	-- 번들거림: 탈수록(또는 소다가 적어 촘촘할수록) 빛이 맺힌 밝은 길쭉한 점
	local gloss = math.floor(L.gloss + dense * 5 + 0.5)
	for _ = 1, gloss do
		add("flat", { Name = "DalgonaGloss", Shape = Enum.PartType.Cylinder, Color = base:Lerp(Color3.fromRGB(255, 240, 215), 0.6), Material = Enum.Material.SmoothPlastic, Transparency = 0.45 },
			math.sqrt(rng:NextNumber()) * 0.75, { abs = rng:NextNumber(0.06, 0.14), squash = rng:NextNumber(0.3, 0.5) })
	end
	self:setThickness(self.h)
end

function Dalgona:setColor(c)
	self.color = c
	if self.meshes then
		for _, p in pairs(self.meshes) do
			p.Color = c
		end
	end
	self.body.Color = c
	self.dome.Color = c
	for _, l in ipairs(self.lumps) do
		l.part.Color = c
	end
end

-- 가장자리 갈라짐 (진한 선)
function Dalgona:crack(count, inward)
	Sfx.play("crack", 0.7)
	local r = self:radius()
	local y = self:topY() + 0.006
	-- 길쭉한 반죽이면 원이 아니라 타원 가장자리에서 시작해 가운데 쪽으로 (반죽 밖으로 선이 나가지 않게)
	local k = math.sqrt(1 + (self.e or 0))
	local cy, sy = math.cos(self.yaw or 0), math.sin(self.yaw or 0)
	for i = 1, count or 5 do
		local a = math.random() * 2 * math.pi
		local lx, lz = math.cos(a) * r * k * 0.97, math.sin(a) * r / k * 0.97
		local from = Vector3.new(self.center.X + lx * cy + lz * sy, y, self.center.Z - lx * sy + lz * cy)
		local toC = Vector3.new(self.center.X - from.X, 0, self.center.Z - from.Z)
		local len = math.min(0.3 + math.random() * (inward or 0.4), toC.Magnitude * 0.8)
		local ang = math.atan2(toC.Z, toC.X) + (math.random() - 0.5) * 0.6
		local to = from + Vector3.new(math.cos(ang), 0, math.sin(ang)) * len
		self.S:fxPart(self.S.fx, {
			Name = "Crack",
			Size = Vector3.new(0.035, 0.012, len),
			CFrame = CFrame.lookAt((from + to) / 2, to),
			Color = Color3.fromRGB(70, 40, 20),
			Material = Enum.Material.SmoothPlastic,
		})
	end
end

-- 모양 틀 자국 = 깊이가 있는 V자 홈 (참고 사진 docs/images/stamp_reference.jpg)
--   홈 바닥(진한 갈색) + 빛 쪽 벽(그림자, 더 진함) + 반대쪽 벽(가는 밝은 줄) → 모양이 도드라져 보임
--   depth: 0 = 안 보임, 1 = 알맞게 또렷, 1 이상 = 너무 깊음 (더 넓고 진함)
-- wires = 틀의 Outline 철사 부품들, handle = { a = Vector3, b = Vector3 } 틀 손잡이 자국 (없어도 됨)
local LIGHT_DIR = Vector3.new(-0.55, 0, -0.83).Unit -- 빛이 오는 쪽 (화면 왼쪽 위)
local GROOVE_DARK = Color3.fromRGB(92, 50, 20)
local GROOVE_SHADOW = Color3.fromRGB(56, 28, 10)
local GROOVE_LIGHT = Color3.fromRGB(255, 243, 215)

local Groove = {}
Groove.__index = Groove

-- 점이 반죽 윗면 안에 있나 (길쭉한 타원 + 가장자리 띠 조금 안쪽까지)
function Dalgona:inside(p, margin)
	local R = self:radius() * (margin or 0.97)
	local k = math.sqrt(1 + self.e)
	local cy, sy = math.cos(self.yaw or 0), math.sin(self.yaw or 0)
	local dx, dz = p.X - self.center.X, p.Z - self.center.Z
	local lx, lz = dx * cy - dz * sy, dx * sy + dz * cy
	return (lx / (R * k)) ^ 2 + (lz / (R / k)) ^ 2 <= 1
end

function Dalgona:groove(wires, handle)
	local g = setmetatable({ dal = self, segs = {} }, Groove)
	local y = self:topY()
	local function add(mid, look, len, width)
		look = Vector3.new(look.X, 0, look.Z)
		if look.Magnitude < 1e-4 or len < 1e-3 then
			return
		end
		-- 반죽 밖으로 나가는 부분은 선을 그리지 않음 (사용자 요청 2026-11-18): 선분을 반죽 안쪽 부분만 남기도록 자름
		do
			local u = look.Unit
			local a, b = mid - u * len / 2, mid + u * len / 2
			local ina, inb = self:inside(a), self:inside(b)
			if not ina and not inb then
				-- 양 끝이 다 밖이어도 가운데가 안이면 양쪽을 자름, 아니면 버림
				if not self:inside(mid) then
					return
				end
			end
			local function cut(inP, outP)
				local lo, hi = inP, outP
				for _ = 1, 12 do
					local m = (lo + hi) / 2
					if self:inside(m) then
						lo = m
					else
						hi = m
					end
				end
				return lo
			end
			local a0, b0 = a, b
			if not ina then
				a = cut(inb and b0 or mid, a0)
			end
			if not inb then
				b = cut(ina and a0 or mid, b0)
			end
			len = (b - a).Magnitude
			if len < 0.01 then
				return
			end
			mid = (a + b) / 2
		end
		look = look.Unit
		local right = look:Cross(Vector3.yAxis).Unit
		local side = right:Dot(LIGHT_DIR) >= 0 and 1 or -1 -- 빛 쪽 벽에 그림자
		local seg = { mid = Vector3.new(mid.X, y, mid.Z), look = look, right = right * side, len = len, w = width }
		local function part(name)
			return self.S:fxPart(self.S.fx, { Name = name, Material = Enum.Material.SmoothPlastic, Transparency = 1, Size = Vector3.new(0.01, 0.008, len) })
		end
		seg.floor, seg.shadow, seg.light = part("Engrave"), part("EngraveShadow"), part("EngraveLight")
		table.insert(g.segs, seg)
	end
	for _, w in ipairs(wires) do
		add(w.Position, w.CFrame.LookVector, w.Size.Z, w:GetAttribute("Width") or 0.07)
	end
	if handle then
		local d = handle.b - handle.a
		add((handle.a + handle.b) / 2, d, d.Magnitude, 0.055)
	end
	g:setDepth(0)
	return g
end

function Groove:setDepth(k)
	local base = self.dal.color
	local kk = math.clamp(k, 0, 1)
	local over = math.clamp(k - 1, 0, 0.5)
	for _, s in ipairs(self.segs) do
		local fw = s.w * (0.3 + 0.25 * kk + 0.3 * over)
		local sw = s.w * (0.12 + 0.3 * kk + 0.2 * over)
		local lw = s.w * (0.08 + 0.12 * kk)
		local function place(p, width, offset, lift)
			p.Size = Vector3.new(math.max(width, 0.004), 0.008, s.len)
			local pos = s.mid + s.right * offset + Vector3.new(0, lift, 0)
			p.CFrame = CFrame.lookAt(pos, pos + s.look)
		end
		place(s.floor, fw, 0, 0.005)
		place(s.shadow, sw, fw / 2 + sw / 2 - 0.002, 0.006)
		place(s.light, lw, -(fw / 2 + lw / 2 - 0.002), 0.006)
		s.floor.Color = base:Lerp(GROOVE_DARK, 0.35 + 0.4 * kk + 0.3 * over)
		s.floor.Transparency = 0.9 - 0.85 * kk
		s.shadow.Color = base:Lerp(GROOVE_SHADOW, 0.45 + 0.45 * kk)
		s.shadow.Transparency = 0.92 - 0.88 * kk
		s.light.Color = base:Lerp(GROOVE_LIGHT, 0.55)
		s.light.Transparency = 0.95 - 0.6 * kk
	end
end

-- 예전 호출용: 바로 최종 깊이로
function Dalgona:engrave(wires, clarity, handle)
	local g = self:groove(wires, handle)
	g:setDepth(clarity)
	return g
end

function Dalgona:sparkle()
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0.05, 0, 0)
	att.Parent = self.body
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.5, 0.9)
	pe.Rate = 14
	pe.Speed = NumberRange.new(0.5, 1)
	pe.SpreadAngle = Vector2.new(70, 70)
	pe.EmissionDirection = Enum.NormalId.Right
	pe.Parent = att
end

return Dalgona

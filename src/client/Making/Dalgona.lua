-- 철판 위 달고나 반죽: 울퉁불퉁한 언덕 → 두꺼운 원판 → 넓고 얇은 원판 (부피는 그대로)
-- 원 밖에 부으면 철판에 들러붙어 찌그러짐(타원). 갈라짐, 각인, Perfect 반짝임.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DalgonaConfig"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local BatterMesh = require(script.Parent:WaitForChild("BatterMesh"))
local Toon = require(script.Parent:WaitForChild("Toon"))

-- 3D 반죽 메시 (tools/blender/dalgona_mesh.py, 유튜브 쇼츠 영상 분석): 두께에 따라 바뀜
--   붓는 중·막 부은 것(h ≥ 0.40): DalgonaMound  리본처럼 접히며 쌓인 주름진 언덕
--   한두 번 누른 것(0.16 ≤ h < 0.40): DalgonaPuff  둥글게 부푼 가장자리 + 기포 구멍
--   다 누른 것(h < 0.16): DalgonaFlat  얇고 평평, 고운 구멍 자국
-- 메시가 없으면 예전 원기둥 + 봉우리 모양
local MOUND_H, FLAT_H = 0.40, 0.16
-- 주름 메시는 울퉁불퉁해서 사진과 달라 안 씀 (2026-11-19 결과 화면 지적): 매끈한 원판 + 봉긋한 윗면 + 붓고 난 뒤 결
-- 2026-11-20: 누른 뒤(얇을 때)는 예전 접힌 메시가 비정형이라 더 좋다는 의견 → EditableMesh가 없을 때 누른 반죽에만 다시 씀
local USE_FOLD_MESHES = true
local RunService = game:GetService("RunService")

local Dalgona = {}
Dalgona.__index = Dalgona

local UP = CFrame.Angles(0, 0, math.rad(90))
local PORE_HOLD, PORE_FADE = 3, 6 -- 기포: 붓기 시작 뒤 3초는 또렷, 그다음 6초에 걸쳐 매끈해짐

-- 3D 반죽은 정점 색을 TOP_DIM만큼 낮춰 두고 밝은 반점만 1로 올림 → 부품 색은 그만큼 밝게 칠해 원래 색이 되게
local function batterTint(c)
	local k = 1 / (BatterMesh.TOP_DIM or 1)
	return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end

-- 탄 정도 b(0~1)에 따른 색·광택 (docs/DALGONA_LOOK.md: 참고 사진 분석)
-- 광택은 Reflectance를 거의 안 씀 (하늘이 비쳐 보라색이 됨) → 밝은 하이라이트 점(gloss 개수)으로 표현
local STOPS = {
	-- 2026-11-19 영상(정미야 밥먹자) 다시 분석: 잘 된 반죽은 주황이 아니라 땅콩버터 같은 베이지 갈색, 다 누르면 무광 + 설탕 가루
	{ b = 0.0, base = Color3.fromRGB(204, 150, 96), rim = Color3.fromRGB(176, 120, 68), spot = Color3.fromRGB(160, 104, 56), refl = 0.0, gloss = 0 },
	{ b = 0.35, base = Color3.fromRGB(190, 128, 70), rim = Color3.fromRGB(150, 92, 44), spot = Color3.fromRGB(140, 82, 36), refl = 0.01, gloss = 3 },
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
	-- 처음엔 숨겨 둠 (2026-11-20: 3D 반죽 메시를 만드는 0.5초 동안 냄비 같은 원기둥이 보였음). 3D가 안 될 때만 아래에서 보이게
	self.body = station:fxPart(station.fx, { Name = "Dalgona", Shape = Enum.PartType.Cylinder, Color = color, Material = Enum.Material.SmoothPlastic, Transparency = 1 })
	-- 가장자리 띠 2겹 (본체보다 살짝 낮고 넓음 → 위에서 보면 진한 테두리 그러데이션)
	self.rim = station:fxPart(station.fx, { Name = "DalgonaRim", Shape = Enum.PartType.Cylinder, Color = color, Material = Enum.Material.SmoothPlastic, Transparency = 1 })
	self.rim2 = station:fxPart(station.fx, { Name = "DalgonaRim2", Shape = Enum.PartType.Cylinder, Color = color, Material = Enum.Material.SmoothPlastic, Transparency = 1 })
	self.rimW = 0.06
	self.details = {}
	-- 가운데 볼록: 납작한 공이어야 해서 늘어나는 공으로 (Ball 부품은 크기가 같은 공으로만 보임)
	self.dome = Fx.ellipsoid(station:fxPart(station.fx, { Name = "DalgonaDome", Color = color, Material = Enum.Material.SmoothPlastic, Transparency = 1 }))
	self.lumps = {}
	for i = 1, 4 do
		local a = i * math.pi / 2 + 0.4
		self.lumps[i] = { part = station:fxPart(station.fx, { Name = "DalgonaLump", Shape = Enum.PartType.Ball, Color = color, Material = Enum.Material.SmoothPlastic, Transparency = 1 }), a = a, r = 0.25 + 0.08 * (i % 2) }
	end
	-- 정교한 3D 반죽 메시 하나 (2026-11-19): 붓는 동안·부은 뒤·누른 뒤 모두 같은 메시가 모양만 바뀜.
	-- EditableMesh를 쓸 수 없으면(Experience Settings > Security에서 꺼짐) 아래 예전 방식
	self.batter = BatterMesh.new(station.fx, color, math.random(1, 9999))
	if self.batter then
		self.swirlAmp = 1 -- 붓는 동안 소용돌이 결이 솟아 있음 (다 부으면 addSwirl로 낮아짐)
		Toon.outline(self.batter.part) -- 다른 도구처럼 만화 외곽선
		-- 막 부은 반죽은 기포 구멍·반점이 또렷하고, 몇 초에 걸쳐 매끈해짐 (2026-11-20)
		local t0 = os.clock()
		local lastT = 0
		local poreConn
		poreConn = RunService.RenderStepped:Connect(function()
			if not (self.batter and self.batter.part and self.batter.part.Parent) then
				poreConn:Disconnect()
				return
			end
			local now = os.clock()
			if now - lastT < 0.1 then
				return
			end
			lastT = now
			local k = 1 - math.clamp((now - t0 - PORE_HOLD) / PORE_FADE, 0, 1)
			self.batter:setPores(k * k)
			if k <= 0 then
				poreConn:Disconnect()
			end
		end)
		for _, p in ipairs({ self.body, self.rim, self.rim2, self.dome }) do
			p.Transparency = 1
		end
		for _, l in ipairs(self.lumps) do
			l.part.Transparency = 1
		end
	elseif USE_FOLD_MESHES and Fx.template("DalgonaPuff") then
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
	if not self.batter and not self.meshes then
		-- 예전 원판 방식 (3D도 접힌 메시도 없을 때)
		for _, p in ipairs({ self.body, self.rim, self.rim2 }) do
			p.Transparency = 0
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
	-- 방울로 그린 모양은 속이 채워져 넓음 (areaScale = 같은 부피 원 대비 평균 반지름).
	-- 넓게 그린 만큼 처음부터 얇게 퍼진 것으로 보고, 그 두께보다 얇게 누를 때부터 넓어짐 (부피는 그대로 → 누른 크기는 원과 같음)
	local s = self.areaScale or 1
	local hEff = Config.Press.h0 / (s * s)
	return 2 * math.sqrt(self.V / (math.pi * math.min(h, hEff))) * (s < 1 and s or 1)
end

-- ── 방울 붓기 (2026-11-20 사용자 메모): 한 방울씩 떨어지고, 떨어진 자리대로 모양이 됨 (하트를 그리며 떨어뜨리면 하트).
-- 동그라미가 뚝뚝 떨어져 먼저 떨어진 것끼리 경계가 흐려지며 하나로 이어짐. 3D 반죽(BatterMesh)일 때만.
local MERGE_R = 0.55 -- 기존 방울 반지름의 이 비율 안에 떨어지면 그 방울에 합쳐짐 (같은 자리에 계속 부으면 커지는 웅덩이)
local MERGE_T = 2.2 -- 막 떨어진 방울이 봉긋하다가 낮아져 이어지는 시간
local SOFT_K = 0.09 -- 방울 경계를 부드럽게 잇는 정도 (stud)
local LOBE_H = 0.3 -- 떨어진 방울이 퍼지는 두께 (덩어리 h0보다 얇게 퍼져 옆 방울과 이어짐)
function Dalgona:addDrop(pos, v)
	if not self.batter then
		return false
	end
	if not self.lobes then
		self.lobes = {}
		self.fresh = {}
		self.V = 0
		self.swirlAmp = 0 -- 소용돌이 결 대신 방울 자국
	end
	local h0 = Config.Press.h0
	local best, bestD = nil, math.huge
	for _, l in ipairs(self.lobes) do
		local d = Vector3.new(pos.X - l.x, 0, pos.Z - l.z).Magnitude
		local r = math.sqrt(l.v / (math.pi * LOBE_H))
		if d < r * MERGE_R and d < bestD then
			best, bestD = l, d
		end
	end
	if best then
		local w = best.v + v
		best.x = (best.x * best.v + pos.X * v) / w
		best.z = (best.z * best.v + pos.Z * v) / w
		best.v = w
	else
		table.insert(self.lobes, { x = pos.X, z = pos.Z, v = v })
	end
	self.V += v
	self.dropsDirty = true
	table.insert(self.fresh, { x = pos.X, z = pos.Z, r = math.sqrt(v / (math.pi * LOBE_H)) * 1.4, born = os.clock() })
	self:updateDrops()
	if not self.dropConn then
		self.dropConn = RunService.RenderStepped:Connect(function()
			if not (self.batter and self.batter.part and self.batter.part.Parent) then
				self.dropConn:Disconnect()
				self.dropConn = nil
				return
			end
			-- 봉긋함이 낮아지는 건 초당 20번이면 충분 (메시 다시 놓기가 무거움)
			local now = os.clock()
			if now - (self.dropT or 0) < 0.05 and #self.fresh > 0 then
				return
			end
			self.dropT = now
			self:updateDrops()
			if #self.fresh == 0 then
				self.dropConn:Disconnect()
				self.dropConn = nil
			end
		end)
	end
	return true
end

-- 방울들 → 가장자리 모양(각도마다 반지름) + 막 떨어진 방울 봉긋함
function Dalgona:updateDrops()
	local lobes = self.lobes
	if not lobes or #lobes == 0 then
		return
	end
	if not self.dropsDirty and self.dropOutline then
		-- 모양은 그대로, 막 떨어진 방울 봉긋함만 낮아짐
		self:dropBumps(self.dropOutline)
		return
	end
	self.dropsDirty = false
	local h0 = Config.Press.h0
	-- 가운데 = 방울들의 무게 중심
	local cx, cz, vs = 0, 0, 0
	for _, l in ipairs(lobes) do
		cx += l.x * l.v
		cz += l.z * l.v
		vs += l.v
	end
	cx /= vs
	cz /= vs
	local radii = {}
	local rmax = 0
	for i, l in ipairs(lobes) do
		radii[i] = math.sqrt(l.v / (math.pi * LOBE_H))
		rmax = math.max(rmax, Vector3.new(l.x - cx, 0, l.z - cz).Magnitude + radii[i])
	end
	-- 부드러운 합집합 거리 (음수 = 반죽 안)
	local function sdf(px, pz)
		local sum = 0
		for i, l in ipairs(lobes) do
			local dx, dz = px - l.x, pz - l.z
			sum += math.exp(-(math.sqrt(dx * dx + dz * dz) - radii[i]) / SOFT_K)
		end
		return -SOFT_K * math.log(math.max(sum, 1e-30))
	end
	local bat = self.batter
	local SEG = bat.SEG
	local R = {}
	local area = 0
	local mxx, mzz, mxz = 0, 0, 0
	for j = 1, SEG do
		local c, s = bat.cos[j], bat.sin[j]
		-- 바깥에서 안으로 훑어 처음 반죽에 닿는 곳 → 그 사이를 반으로 나눠 정밀하게
		local hi = rmax + 0.2
		local lo = 0
		local step = 0.12
		local r = hi
		while r > 0 do
			if sdf(cx + c * r, cz + s * r) < 0 then
				lo = r
				break
			end
			hi = r
			r -= step
		end
		for _ = 1, 7 do
			local m = (lo + hi) / 2
			if sdf(cx + c * m, cz + s * m) < 0 then
				lo = m
			else
				hi = m
			end
		end
		local rr = math.max((lo + hi) / 2, 0.05)
		R[j] = rr
		area += rr * rr
		-- 넓이 2차 모멘트 (길쭉함): 부채꼴 조각 ∫r³dr = r⁴/4
		local r4 = rr ^ 4 / 4
		mxx += r4 * c * c
		mzz += r4 * s * s
		mxz += r4 * c * s
	end
	local dth = 2 * math.pi / SEG
	area = area * dth / 2
	local Req = math.sqrt(area / math.pi)
	local outline = {}
	for j = 1, SEG do
		outline[j] = R[j] / Req
	end
	-- 동그란 정도 (점수용, 2026-11-20 "전체 외곽선이 원형에 가까운 게 제일 잘 만든 거"):
	-- 가장자리 반지름이 평균에서 벗어난 정도의 평균 (0 = 완전한 원, 들쑥날쑥할수록 큼)
	local dev = 0
	for j = 1, SEG do
		dev += math.abs(outline[j] - 1)
	end
	self.roundDev = dev / SEG
	-- 길쭉함 (점수용): 주축 비
	local a, b = (mxx + mzz) / 2, math.sqrt(((mxx - mzz) / 2) ^ 2 + mxz * mxz)
	self.elong = math.sqrt((a + b) / math.max(a - b, 1e-9))
	-- 부피를 유지한 원 반지름 대비 실제(속이 채워진) 모양 반지름
	self.areaScale = Req / math.sqrt(vs / (math.pi * h0))
	self.center = Vector3.new(cx, self.center.Y, cz)
	self.e, self.yaw = 0, 0
	self.Req = Req
	self:dropBumps(outline)
end

function Dalgona:dropBumps(outline)
	local cx, cz, Req = self.center.X, self.center.Z, self.Req
	-- 막 떨어진 방울: 메시 좌표(평균 반지름 1)로
	local bumps = {}
	local now = os.clock()
	for i = #self.fresh, 1, -1 do
		local f = self.fresh[i]
		local age = (now - f.born) / MERGE_T
		if age >= 1 then
			table.remove(self.fresh, i)
		else
			table.insert(bumps, { (f.x - cx) / Req, (f.z - cz) / Req, f.r / Req, 0.45 * (1 - age) ^ 2 })
		end
	end
	self.dropOutline = outline
	self.batter:setDrops(outline, bumps)
	self:setThickness(self.h)
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
	-- 두꺼울수록 낮은 옆면 + 지름 전체를 덮는 둥근 윗면 = 낮고 둥근 웅덩이 (영상 9번). 누를수록 윗면이 평평해짐
	local s = math.clamp((h - 0.12) / (Config.Press.h0 - 0.12), 0, 1)
	local capH = h * 0.75 * 0.65 * s
	local bodyH = math.max(h * 0.75 - capH, 0.01)
	self.capH = capH
	self.rim.Size = Vector3.new(bodyH - 0.008, d * k, d / k)
	self.rim.CFrame = CFrame.new(c.X, c.Y + (bodyH - 0.008) / 2, c.Z) * turn * UP
	self.rim2.Size = Vector3.new(bodyH - 0.004, d * k * (1 - w), d / k * (1 - w))
	self.rim2.CFrame = CFrame.new(c.X, c.Y + (bodyH - 0.004) / 2, c.Z) * turn * UP
	self.body.Size = Vector3.new(bodyH, d * k * (1 - 2 * w), d / k * (1 - 2 * w))
	self.body.CFrame = CFrame.new(c.X, c.Y + bodyH / 2, c.Z) * turn * UP
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
	if self.batter then
		-- 두꺼울수록 둥근 언덕, 누를수록 윗면이 평평한 원판 (가장자리는 둥글게)
		local h0 = Config.Press.h0
		local flat = math.clamp((h0 * 0.95 - h) / (h0 * 0.95 - 0.1), 0, 1)
		self.batter:setShape(flat, self.swirlAmp or 0)
		-- 두꺼울 때는 보이는 높이를 낮춰 퍼진 웅덩이처럼 (부피 계산·누름판 닿는 높이는 그대로)
		-- 누를수록 보이는 두께를 조금 키움: 납작해 보이지 않게 (2026-11-20). 부피·판정 높이는 그대로
		self.batter:place(c, d * k, d / k, h * 0.75 * (1 - 0.3 * (1 - flat)) * (1 + 0.7 * flat), self.yaw or 0)
		-- 금 선은 반죽 표면을 따라 (금 간 뒤 더 누르면 같이 내려감)
		for _, ck in ipairs(self.cracks or {}) do
			local ya, yb = self.batter:surfaceY(ck.a), self.batter:surfaceY(ck.b)
			if ya and yb then
				local a = Vector3.new(ck.a.X, ya + 0.022, ck.a.Z)
				local b = Vector3.new(ck.b.X, yb + 0.022, ck.b.Z)
				ck.part.CFrame = CFrame.lookAt((a + b) / 2, b)
			end
		end
		-- 기포 구멍·반점은 이제 3D 반죽 메시 안에 있음 (BatterMesh pore/speck) → 덧붙이던 무늬 부품은 숨김
		for _, dt in ipairs(self.details) do
			dt.part.LocalTransparencyModifier = 1
		end
		return
	end
	if self.meshes and not self.simple and h < MOUND_H then
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
	-- 둥근 윗면: 옆면 꼭대기에 지름 전체 크기의 납작한 반구 (위쪽 절반만 보임)
	self.dome.Transparency = s < 0.03 and 1 or 0
	self.dome.Size = Vector3.new(d * k * 0.985, math.max(capH * 2, 0.01), d / k * 0.985)
	self.dome.CFrame = CFrame.new(c.X, c.Y + bodyH, c.Z) * turn
	for _, l in ipairs(self.lumps) do
		local ls = 0.35 * s
		l.part.Transparency = 1 -- 덩어리 공은 울퉁불퉁해 보여서 안 씀 (2026-11-19)
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
	if self.batter then
		self.batter.part.Color = batterTint(base)
		self.batter.part.Reflectance = refl
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
	if self.batter then
		self.batter.part.Color = batterTint(c)
	end
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

-- 금 (참고 사진 2026-11-20): 가늘고 진한 틈이 들쭉날쭉 꺾이며 찍힌 모양 선을 따라 조금 가다가
-- 바깥 가장자리까지 쭉 뻗음. 3D 반죽이면 표면 높이를 따라 얹음
local CRACK = Color3.fromRGB(46, 26, 12)
function Dalgona:crackLines(count)
	local S = self.S
	local bat = self.batter
	local c = self.center
	local R = self:radius()
	local rng = Random.new()
	local function surf(p)
		local y = bat:surfaceY(p)
		return y and Vector3.new(p.X, y + 0.022, p.Z) or nil
	end
	local function seg(a, b, w)
		local d = b - a
		if d.Magnitude < 1e-3 then
			return
		end
		local part = S:fxPart(S.fx, {
			Name = "Crack",
			Size = Vector3.new(w, 0.012, d.Magnitude + w * 0.6),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = CRACK,
			Material = Enum.Material.SmoothPlastic,
		})
		self.cracks = self.cracks or {}
		table.insert(self.cracks, { part = part, a = a, b = b })
	end
	-- 한 줄: from에서 dir 쪽으로 들쭉날쭉 걸어 가장자리 밖에서 멈춤
	local function walk(from, dir, w, maxLen)
		local p = from
		local len = 0
		local d = Vector3.new(dir.X, 0, dir.Z).Unit
		while len < maxLen do
			-- 바깥쪽으로 가려는 힘 + 작은 꺾임
			local out = Vector3.new(p.X - c.X, 0, p.Z - c.Z)
			if out.Magnitude > 1e-3 then
				d = (d + out.Unit * 0.25).Unit
			end
			local ang = rng:NextNumber(-0.45, 0.45)
			d = Vector3.new(d.X * math.cos(ang) - d.Z * math.sin(ang), 0, d.X * math.sin(ang) + d.Z * math.cos(ang))
			local step = rng:NextNumber(0.05, 0.11)
			local q = p + d * step
			local a3, b3 = surf(p), surf(q)
			if not a3 or not b3 then
				break -- 가장자리 밖
			end
			seg(a3, b3, w)
			-- 가끔 가는 곁가지
			if rng:NextNumber() < 0.06 and w > 0.014 then
				local side = Vector3.new(-d.Z, 0, d.X) * (rng:NextNumber() < 0.5 and 1 or -1)
				walk(q, (d + side).Unit, w * 0.6, rng:NextNumber(0.1, 0.35))
			end
			p = q
			len += step
		end
	end
	local segs = self.stampSegs
	local first = segs and rng:NextInteger(1, #segs) or 1
	for ci = 1, count do
		local w = rng:NextNumber(0.016, 0.024)
		if segs and #segs > 0 then
			-- 찍힌 선 위 한 점에서: 선을 따라 조금 가다가(사진처럼 별 모서리를 타고) 바깥으로. 금마다 다른 선에서 (고루 퍼지게)
			local s = segs[(first + math.floor((ci - 1) * #segs / count)) % #segs + 1]
			local u = rng:NextNumber()
			local p = s.a:Lerp(s.b, u)
			local along = (s.b - s.a)
			if along.Magnitude > 1e-3 then
				along = along.Unit * (rng:NextNumber() < 0.5 and 1 or -1)
				local q = p + along * rng:NextNumber(0.1, 0.3)
				local a3, b3 = surf(p), surf(q)
				if a3 and b3 then
					seg(a3, b3, w)
					p = q
				end
			end
			local out = Vector3.new(p.X - c.X, 0, p.Z - c.Z)
			if out.Magnitude < 1e-3 then
				out = Vector3.new(1, 0, 0)
			end
			walk(p, out.Unit, w, R * 2)
		else
			-- 찍기 전(누르다 금): 가장자리에서 안쪽으로
			local a = rng:NextNumber(0, 2 * math.pi)
			local k = math.sqrt(1 + (self.e or 0))
			local cy, sy = math.cos(self.yaw or 0), math.sin(self.yaw or 0)
			local lx, lz = math.cos(a) * R * k * 0.9, math.sin(a) * R / k * 0.9
			local p = Vector3.new(c.X + lx * cy + lz * sy, c.Y, c.Z - lx * sy + lz * cy)
			-- 가운데 쪽으로 걷다가 되돌아 나오는 대신, 안쪽 점에서 바깥으로 걸음
			local inPt = p:Lerp(Vector3.new(c.X, c.Y, c.Z), rng:NextNumber(0.25, 0.55))
			walk(inPt, (p - inPt).Unit, w, R * 2)
		end
	end
end

-- 가장자리 갈라짐 (진한 선)
function Dalgona:crack(count, inward)
	Sfx.play("crack", 0.7)
	if self.batter then
		self:crackLines(math.max(3, math.floor((count or 5) * 0.8)))
		return
	end
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

-- 3D 반죽(EditableMesh)이면 메시 표면에 직접 홈을 파고 안쪽을 봉긋하게 (부품을 덧그리지 않음, 2026-11-20)
local BatterGroove = {}
BatterGroove.__index = BatterGroove
function BatterGroove:setDepth(k)
	if not self.ready then
		self.ready = true
		self.dal.batter:prepareStamp(self.segs, self.isInside)
	end
	self.dal.batter:setStamp(k)
end

function Dalgona:groove(wires, handle)
	if self.batter then
		local segs = {}
		local closed = {}
		for _, w in ipairs(wires) do
			local half = w.CFrame.LookVector * (w.Size.Z / 2)
			local s = { a = w.Position - half, b = w.Position + half, w = w:GetAttribute("Width") or 0.07 }
			table.insert(segs, s)
			table.insert(closed, s)
		end
		if handle then
			table.insert(segs, { a = handle.a, b = handle.b, w = 0.055 })
		end
		-- 틀 안쪽 판정: 철사 선분들에 대한 홀짝 규칙 (안쪽 구멍은 바깥으로 처리됨)
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
		self.stampSegs = closed -- 금이 틀 선을 따라 갈 때 씀
		return setmetatable({ dal = self, segs = segs, isInside = isInside }, BatterGroove)
	end
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
	-- 모양대로 볼륨감 (영상 11~13번): 틀 안쪽 가장자리가 둥글게 부풀어 오른 턱. 틀 철사 선분마다 안쪽에 둥근 원기둥
	local cx, cz, n = 0, 0, 0
	for _, s in ipairs(g.segs) do
		cx += s.mid.X
		cz += s.mid.Z
		n += 1
	end
	if n > 0 then
		local centroid = Vector3.new(cx / n, y, cz / n)
		for _, s in ipairs(g.segs) do
			local r = s.right
			s.inner = r:Dot(centroid - s.mid) >= 0 and r or -r
			-- (2026-11-20) 원기둥 턱은 계단처럼 보여서 안 씀 → 3D 반죽(BatterMesh)에서 메시로 표현
		end
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
		if s.puff then
			-- 안쪽 턱: 홈 바로 안쪽에 둥글게 솟음 (깊게 찍을수록 또렷)
			local d = s.w * (1.1 + 0.6 * kk)
			local rise = 0.006 + 0.014 * kk
			local pos = s.mid + s.inner * (fw / 2 + d * 0.4) + Vector3.new(0, rise - d / 2, 0)
			s.puff.Size = Vector3.new(s.len + d * 0.6, d, d)
			s.puff.CFrame = CFrame.lookAt(pos, pos + s.look) * CFrame.Angles(0, math.rad(90), 0)
			s.puff.Color = base:Lerp(Color3.fromRGB(255, 238, 205), 0.22)
			s.puff.Transparency = 1 - 0.95 * kk
		end
	end
end

-- 예전 호출용: 바로 최종 깊이로
function Dalgona:engrave(wires, clarity, handle)
	local g = self:groove(wires, handle)
	g:setDepth(clarity)
	return g
end

-- 부은 결 (영상 7~10번): 막 부으면 위에 소용돌이 결이 보이고, 몇 초에 걸쳐 퍼지며 매끈해짐
local SWIRL_N, SWIRL_FADE = 44, 4.5
function Dalgona:addSwirl()
	if self.lobes then
		return -- 방울로 부었으면 소용돌이 결 대신 방울이 낮아지며 이어짐 (updateDrops)
	end
	if self.batter then
		-- 3D: 메시의 소용돌이 주름이 SWIRL_FADE초에 걸쳐 낮아짐 (그림을 덧그리지 않음)
		self.swirlAmp = 1
		local age = 0
		local conn
		conn = RunService.RenderStepped:Connect(function(dt)
			if not (self.batter.part and self.batter.part.Parent) then
				conn:Disconnect()
				return
			end
			age += dt
			local k = math.clamp(age / SWIRL_FADE, 0, 1)
			self.swirlAmp = (1 - k) ^ 1.5
			self:setThickness(self.h)
			if k >= 1 then
				conn:Disconnect()
			end
		end)
		return
	end
	do
		return -- 3D가 아닐 때는 그림으로 결을 덧그리지 않음 (2026-11-20 "원에다가 그림 그리지 말고")
	end
	if self.swirl then
		for _, p in ipairs(self.swirl.parts) do
			p:Destroy()
		end
	end
	local parts = {}
	for i = 1, SWIRL_N do
		parts[i] = self.S:fxPart(self.S.fx, { Name = "DalgonaSwirl", Material = Enum.Material.SmoothPlastic, Transparency = 1, Size = Vector3.new(0.035, 0.01, 0.1) })
	end
	local sw = { parts = parts, age = 0, turn = math.random() * 6.28, dir = math.random() < 0.5 and -1 or 1 }
	self.swirl = sw
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not parts[1].Parent then
			conn:Disconnect()
			return
		end
		sw.age += dt
		local k = math.clamp(sw.age / SWIRL_FADE, 0, 1)
		local r = self:radius()
		local kk = math.sqrt(1 + (self.e or 0))
		local c = self.center
		local top = c.Y + self.h * 0.75
		local domeH = 0
		if self.dome and self.dome.Transparency < 1 then
			domeH = self.dome.Size.Y / 2
		end
		local function at(a)
			-- 아르키메데스 나선: 가운데에서 가장자리 85%까지 3바퀴
			local rr = (a / (6 * math.pi)) * 0.85 * r * (1 + 0.15 * k)
			local ang = sw.turn + sw.dir * a
			local x, z = math.cos(ang) * rr * kk, math.sin(ang) * rr / kk
			local dd = self.dome.Size.X / 2
			local y = top - domeH + (dd > 0 and domeH * math.sqrt(math.max(0, 1 - (rr / dd) ^ 2)) or 0) + 0.004
			return Vector3.new(c.X + x, y, c.Z + z)
		end
		local col = self.color:Lerp(Color3.fromRGB(255, 236, 200), 0.35)
		for i, p in ipairs(parts) do
			local a0 = (i - 1) / SWIRL_N * 6 * math.pi + 0.4
			local a1 = i / SWIRL_N * 6 * math.pi + 0.4
			local p0, p1 = at(a0), at(a1)
			p.Size = Vector3.new(0.04 * (1 + k), 0.01, (p1 - p0).Magnitude + 0.02)
			p.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
			p.Color = col
			p.Transparency = 0.35 + 0.65 * k
		end
		if k >= 1 then
			conn:Disconnect()
			for _, p in ipairs(parts) do
				p:Destroy()
			end
			self.swirl = nil
		end
	end)
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

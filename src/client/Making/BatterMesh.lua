-- 반죽 3D 메시 하나 (2026-11-19/20 사용자 요청: 원판에 그림을 그리지 말고 진짜 3D로).
-- EditableMesh로 정점을 직접 움직인다 — 덧그린 부품 없이 메시 표면 자체가:
--   · 막 부은 반죽: 둥근 언덕 + 소용돌이 결(실제로 솟은 주름). 시간이 지나면 주름이 낮아져 매끈해짐 (영상 7~10번)
--   · 누를수록 윗면이 평평한 원판, 가장자리는 비정형으로 울퉁불퉁 (예전 접힌 메시 느낌, 2026-11-20)
--   · 모양 찍기: 틀 선을 따라 홈이 파이고, 틀 안쪽은 봉긋하게 솟음 (영상 11~13번)
-- 메시 좌표: X·Z −1.1~1.1(가장자리 반지름 약 1), Y 0~1 (기본 윗면 꼭대기 = TOP). 크기는 MeshPart.Size로.
-- 쓸 수 없으면(Experience Settings > Security에서 EditableMesh 꺼짐) nil → Dalgona가 예전 방식.

local AssetService = game:GetService("AssetService")

local Batter = {}
Batter.__index = Batter

local SEG = 200 -- 둘레 조각
local RINGS = 56 -- 가운데 → 가장자리 고리
local TOP = 0.88 -- 기본 모양 꼭대기 높이 (찍은 모양 안쪽이 솟을 여유)
local BOUND = 1.1 -- 메시 경계 상자 (MeshPart 크기 기준을 고정하려고 모서리 점 2개를 박아 둠)

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function build(parent, color, seed)
	local em = AssetService:CreateEditableMesh()
	if not em then
		return nil
	end
	local self = setmetatable({}, Batter)
	self.em = em
	local rng = Random.new(seed or 1)
	self.ph = {}
	for i = 1, 8 do
		self.ph[i] = rng:NextNumber(0, 6.283)
	end
	self.ringT = {}
	for i = 1, RINGS do
		self.ringT[i] = 1 - (1 - i / RINGS) ^ 1.5
	end
	self.cos, self.sin = {}, {}
	for j = 1, SEG do
		local a = (j - 1) / SEG * 2 * math.pi
		self.cos[j], self.sin[j] = math.cos(a), math.sin(a)
	end
	-- 정점
	self.topCenter = em:AddVertex(Vector3.new(0, TOP, 0))
	self.rings = {}
	for i = 1, RINGS do
		local ring = {}
		for j = 1, SEG do
			ring[j] = em:AddVertex(Vector3.zero)
		end
		self.rings[i] = ring
	end
	self.bottomCenter = em:AddVertex(Vector3.new(0, 0, 0))
	for j = 1, SEG do
		local j2 = j % SEG + 1
		em:AddTriangle(self.topCenter, self.rings[1][j2], self.rings[1][j])
		for i = 1, RINGS - 1 do
			local a, b = self.rings[i][j], self.rings[i][j2]
			local c, d = self.rings[i + 1][j], self.rings[i + 1][j2]
			em:AddTriangle(a, b, d)
			em:AddTriangle(a, d, c)
		end
		em:AddTriangle(self.bottomCenter, self.rings[RINGS][j], self.rings[RINGS][j2])
	end
	-- 경계 고정용 아주 작은 삼각형 (바닥 아래 안 보이는 곳)
	local p1 = em:AddVertex(Vector3.new(-BOUND, 0, -BOUND))
	local p2 = em:AddVertex(Vector3.new(-BOUND + 0.001, 0, -BOUND))
	local p3 = em:AddVertex(Vector3.new(BOUND, 1, BOUND))
	local p4 = em:AddVertex(Vector3.new(BOUND - 0.001, 1, BOUND))
	em:AddTriangle(p1, p2, p1)
	em:AddTriangle(p3, p4, p3)
	self.flat, self.swirl, self.stampK = 0, 0, 0
	self.stamp = nil
	self:rebuild()
	local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
	mp.Name = "DalgonaBatter"
	mp.Anchored = true
	mp.CanCollide = false
	mp.CanQuery = false
	mp.CanTouch = false
	mp.CastShadow = true
	mp.Material = Enum.Material.SmoothPlastic
	mp.Color = color
	mp.Parent = parent
	self.part = mp
	return self
end

local unavailable = false
function Batter.new(parent, color, seed)
	if unavailable then
		return nil
	end
	local ok, res = pcall(build, parent, color, seed)
	if ok and res then
		return res
	end
	unavailable = true
	warn("[Dalgona] 3D 반죽 메시를 만들 수 없어요 (Experience Settings > Security에서 EditableMesh 허용 필요):", res)
	return nil
end

-- 가장자리 반지름 (각도 j): 누를수록 비정형으로 울퉁불퉁
function Batter:edgeR(j)
	local ph = self.ph
	local c, s = self.cos[j], self.sin[j]
	local a = math.atan2(s, c)
	local amp = lerp(0.025, 0.07, self.flat)
	return 1 - amp + amp * (0.55 * math.sin(3 * a + ph[1]) + 0.3 * math.sin(5 * a + ph[2]) + 0.15 * math.sin(9 * a + ph[3]))
end

-- 모든 정점 다시 놓기
function Batter:rebuild()
	local em = self.em
	local flat = self.flat
	local n = lerp(2.0, 10.0, flat)
	local p = lerp(0.6, 0.3, flat)
	local swirl = self.swirl
	local ph = self.ph
	local st = self.stamp
	local k = self.stampK
	local edges = {}
	for j = 1, SEG do
		edges[j] = self:edgeR(j)
	end
	for i = 1, RINGS do
		local t = self.ringT[i]
		local ring = self.rings[i]
		for j = 1, SEG do
			local r = t * edges[j]
			local x, z = self.cos[j] * r, self.sin[j] * r
			local y = 0
			if i < RINGS then
				y = (1 - t ^ n) ^ p
				-- 부은 결: 가운데에서 바깥으로 도는 소용돌이 주름 (실제로 솟음)
				if swirl > 0.001 then
					local a = math.atan2(self.sin[j], self.cos[j])
					y *= 1 + swirl * 0.11 * math.sin(22 * t - 2 * a + ph[4]) * (1 - t * 0.6)
				end
				-- 모양 찍기: 틀 선을 따라 파인 홈 + 안쪽 봉긋
				if st and k > 0.001 then
					local idx = (i - 1) * SEG + j
					local g = st.groove[idx]
					local inn = st.inside[idx]
					y = y - k * 0.62 * g * y + k * 0.1 * inn
				end
				y = math.clamp(y, 0, 1.12) * TOP
			end
			em:SetPosition(ring[j], Vector3.new(x, y, z))
		end
	end
	local yc = TOP * (1 + swirl * 0.11 * math.sin(ph[4]))
	em:SetPosition(self.topCenter, Vector3.new(0, yc, 0))
end

-- flat 0 = 둥근 언덕, 1 = 얇은 원판 / swirl 0~1 = 부은 결 세기
function Batter:setShape(flat, swirl)
	flat = math.clamp(flat, 0, 1)
	swirl = math.clamp(swirl or self.swirl, 0, 1)
	if math.abs(flat - self.flat) < 0.01 and math.abs(swirl - self.swirl) < 0.02 then
		return
	end
	self.flat, self.swirl = flat, swirl
	self:rebuild()
end

-- 정점 하나의 (메시 좌표) 위치 → 세계 좌표 (place로 정한 크기·자세 기준, 높이 무시)
local function localXZ(self, i, j)
	local t = self.ringT[i]
	local r = t * self:edgeR(j)
	return self.cos[j] * r, self.sin[j] * r
end

-- 모양 찍기 준비: segs = { {a = Vector3, b = Vector3, w = 폭}, ... } (세계 좌표), poly = 틀 외곽선 안쪽 판정 함수(worldPos) → bool
-- 정점마다 홈 깊이(0~1)·안쪽 봉긋(0~1)을 미리 계산해 두고, setStamp(k)로 깊이만 바꿈
function Batter:prepareStamp(segs, isInside)
	local cf = self.part.CFrame
	local size = self.part.Size
	local groove, inside = {}, {}
	for i = 1, RINGS do
		for j = 1, SEG do
			local lx, lz = localXZ(self, i, j)
			-- 세계 좌표 (높이는 상관없음): 메시 x −BOUND~BOUND ↔ Size.X
			local wp = cf:PointToWorldSpace(Vector3.new(lx * size.X / (2 * BOUND), 0, lz * size.Z / (2 * BOUND)))
			local best = math.huge
			local bw = 0.05
			for _, s in ipairs(segs) do
				local ax, az, bx, bz = s.a.X, s.a.Z, s.b.X, s.b.Z
				local ex, ez = bx - ax, bz - az
				local L2 = ex * ex + ez * ez
				local u = L2 > 1e-9 and math.clamp(((wp.X - ax) * ex + (wp.Z - az) * ez) / L2, 0, 1) or 0
				local dx, dz = ax + ex * u - wp.X, az + ez * u - wp.Z
				local d2 = dx * dx + dz * dz
				if d2 < best then
					best = d2
					bw = s.w
				end
			end
			local d = math.sqrt(best)
			local gw = bw * 0.75
			local idx = (i - 1) * SEG + j
			groove[idx] = math.exp(-(d / gw) ^ 2)
			if isInside(wp) then
				-- 안쪽: 홈에서 멀어질수록 봉긋 (가장자리가 둥글게 내려감)
				local q = math.clamp(d / (gw * 3.2), 0, 1)
				inside[idx] = q * q * (3 - 2 * q)
			else
				inside[idx] = 0
			end
		end
	end
	self.stamp = { groove = groove, inside = inside }
	self.stampK = 0
end

function Batter:setStamp(k)
	k = math.clamp(k, 0, 1.4)
	if math.abs(k - self.stampK) < 0.02 then
		return
	end
	self.stampK = k
	self:rebuild()
end

-- center = 철판 위 반죽 가운데, width/depth = 가장자리 지름, height = 기본 윗면 꼭대기 높이
function Batter:place(center, width, depth, height, yaw)
	local sy = math.max(height / TOP, 0.01)
	self.part.Size = Vector3.new(math.max(width * BOUND, 0.02), sy, math.max(depth * BOUND, 0.02))
	self.part.CFrame = CFrame.new(center.X, center.Y + sy / 2, center.Z) * CFrame.Angles(0, yaw or 0, 0)
end

function Batter:destroy()
	if self.part then
		self.part:Destroy()
	end
	if self.em then
		self.em:Destroy()
	end
end

return Batter

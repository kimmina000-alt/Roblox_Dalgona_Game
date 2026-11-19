-- 반죽 3D 메시 하나 (사용자 요청 2026-11-19: 부을 때와 부은 뒤 모양이 달라서 하나로, 정교한 3D로).
-- EditableMesh로 게임 안에서 직접 만든다: 위가 둥근 반죽 덩어리. 가장자리는 살짝 울퉁불퉁하고 철판에 닿는 곳은 둥글게 말림.
--   flat 0 = 막 부은 둥근 언덕(가운데가 봉긋) → 1 = 다 누른 넓고 얇은 원판(윗면 평평, 가장자리만 둥글게)
-- 메시 좌표는 X·Z −1~1, Y 0~1 (크기는 MeshPart.Size로). 가장자리 쪽은 진하고 가운데는 밝은 정점 색.
-- 만들 수 없는 환경이면 nil → Dalgona가 예전 모양을 씀.

local AssetService = game:GetService("AssetService")

local Batter = {}
Batter.__index = Batter

local SEG = 72 -- 둘레 조각
local RINGS = 16 -- 가운데 → 가장자리 고리 (가장자리 쪽이 촘촘)

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
	-- 가장자리 모양: 완전한 원이 아니라 조금씩 울퉁불퉁
	local ph = { rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28) }
	self.edge = {}
	local maxR = 0
	for j = 1, SEG do
		local a = (j - 1) / SEG * 2 * math.pi
		local r = 1 + 0.035 * math.sin(3 * a + ph[1]) + 0.025 * math.sin(5 * a + ph[2]) + 0.012 * math.sin(9 * a + ph[3])
		self.edge[j] = r
		maxR = math.max(maxR, r)
	end
	for j = 1, SEG do
		self.edge[j] /= maxR
	end
	self.ph = ph
	-- 고리 반지름 (0~1): 가장자리 쪽으로 촘촘하게
	self.ringT = {}
	for i = 1, RINGS do
		self.ringT[i] = 1 - (1 - i / RINGS) ^ 1.7
	end
	-- 정점: 윗면 가운데 + 고리들, 바닥 가운데
	self.topCenter = em:AddVertex(Vector3.new(0, 1, 0))
	self.rings = {}
	for i = 1, RINGS do
		local ring = {}
		for j = 1, SEG do
			ring[j] = em:AddVertex(Vector3.zero)
		end
		self.rings[i] = ring
	end
	self.bottomCenter = em:AddVertex(Vector3.new(0, 0, 0))
	-- 면 (위에서 볼 때 반시계: Roblox 앞면)
	self.faces = {}
	local function tri(a, b, c, ringIdx)
		local f = em:AddTriangle(a, b, c)
		table.insert(self.faces, { f = f, ring = ringIdx })
	end
	for j = 1, SEG do
		local j2 = j % SEG + 1
		tri(self.topCenter, self.rings[1][j2], self.rings[1][j], 1)
		for i = 1, RINGS - 1 do
			local a, b = self.rings[i][j], self.rings[i][j2]
			local c, d = self.rings[i + 1][j], self.rings[i + 1][j2]
			tri(a, b, d, i + 1)
			tri(a, d, c, i + 1)
		end
		-- 바닥 (아래를 봄)
		tri(self.bottomCenter, self.rings[RINGS][j], self.rings[RINGS][j2], RINGS)
	end
	self.flat = -1
	self:setShape(0)
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

-- 설정에서 꺼져 있으면 정점을 넣는 순간 오류 → 통째로 pcall, 실패하면 nil (한 번 실패하면 다시 시도 안 함)
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

-- flat 0 = 둥근 언덕, 1 = 얇은 원판. 바뀐 만큼만 정점을 다시 놓음
function Batter:setShape(flat)
	flat = math.clamp(flat, 0, 1)
	if math.abs(flat - self.flat) < 0.01 then
		return
	end
	self.flat = flat
	local em = self.em
	-- 높이 곡선 y(t) = (1 - t^n)^p : n이 클수록 윗면이 평평, p가 작을수록 가장자리가 둥글게 섬
	local n = lerp(2.0, 9.0, flat)
	local p = lerp(0.62, 0.32, flat)
	-- 막 부은 반죽은 리본이 접힌 듯 아주 살짝 물결 (누를수록 사라짐)
	local ripple = 0.035 * (1 - flat)
	for i = 1, RINGS do
		local t = self.ringT[i]
		local ring = self.rings[i]
		for j = 1, SEG do
			local a = (j - 1) / SEG * 2 * math.pi
			local r = t * self.edge[j]
			local y = (1 - math.min(t, 1) ^ n) ^ p
			if i < RINGS then
				y = math.clamp(y * (1 + ripple * math.sin(4 * a + 9 * t + self.ph[4])), 0, 1)
			else
				y = 0
			end
			em:SetPosition(ring[j], Vector3.new(math.cos(a) * r, y, math.sin(a) * r))
		end
	end
	em:SetPosition(self.topCenter, Vector3.new(0, 1, 0))
end

function Batter:place(center, width, depth, height, yaw)
	self.part.Size = Vector3.new(math.max(width, 0.02), math.max(height, 0.01), math.max(depth, 0.02))
	self.part.CFrame = CFrame.new(center.X, center.Y + height / 2, center.Z) * CFrame.Angles(0, yaw or 0, 0)
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

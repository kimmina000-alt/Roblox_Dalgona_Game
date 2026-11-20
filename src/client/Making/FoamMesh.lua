-- 넘친 소다 거품 3D (2026-11-20 사용자 요청 "소다 많이 넣어서 넘치는 것도 3D로 자연스럽게 현실적으로")
-- EditableMesh 한 장으로: 국자 위로 둥글게 솟은 돔 → 테두리를 넘어 말려 내려오고 → 국자 바깥 면을 따라 흘러내림.
-- 흘러내리는 길이는 각도마다 다름 (혀처럼 길게 늘어진 줄기 몇 개 + 테두리 바로 아래까지만 덮인 곳).
-- 끝은 둥글게 굵어져 방울처럼 맺힘. EditableMesh가 안 되면 nil (Soda가 예전 공 + 방울 부품으로 그림)

local AssetService = game:GetService("AssetService")

local Foam = {}
Foam.__index = Foam

local NA = 64 -- 둘레 조각
local ND = 12 -- 돔 고리
local NL = 4 -- 테두리 넘어 말리는 고리
local NW = 14 -- 바깥 면 따라 흘러내리는 고리
local B, UP, DN = 2.4, 3.0, 2.0 -- 경계 상자 (국자 가운데·테두리 높이 기준): 옆 ±B, 위 UP, 아래 DN
local OFF = Vector3.new(0, (UP - DN) / 2, 0) -- 경계 상자 가운데 (메시 좌표는 이 점 기준)

function Foam.new(parent, color, seed)
	local ok, res = pcall(function()
		local em = AssetService:CreateEditableMesh()
		if not em then
			return nil
		end
		local self = setmetatable({}, Foam)
		self.em = em
		local rng = Random.new(seed or 1)
		-- 흘러내리는 줄기: 각도 · 폭 · 길이
		self.tongues = {}
		local n = rng:NextInteger(5, 7)
		for i = 1, n do
			table.insert(self.tongues, {
				a = (i - 1) / n * 2 * math.pi + rng:NextNumber(-0.35, 0.35),
				w = rng:NextNumber(0.16, 0.3),
				len = rng:NextNumber(0.55, 1),
			})
		end
		self.wob = {}
		for i = 1, 4 do
			self.wob[i] = rng:NextNumber(0, 6.283)
		end
		self.cos, self.sin = {}, {}
		for j = 1, NA do
			local a = (j - 1) / NA * 2 * math.pi
			self.cos[j], self.sin[j] = math.cos(a), math.sin(a)
		end
		self.top = em:AddVertex(-OFF)
		self.rings = {}
		local NR = ND + NL + NW
		self.NR = NR
		for i = 1, NR do
			self.rings[i] = {}
			for j = 1, NA do
				self.rings[i][j] = em:AddVertex(-OFF)
			end
		end
		local R = self.rings
		for j = 1, NA do
			local j2 = j % NA + 1
			em:AddTriangle(self.top, R[1][j2], R[1][j])
			for i = 1, NR - 1 do
				local a, b = R[i][j], R[i][j2]
				local c, d = R[i + 1][j], R[i + 1][j2]
				em:AddTriangle(a, b, d)
				em:AddTriangle(a, d, c)
			end
		end
		-- 경계 고정 (가운데 기준 좌표)
		local p1 = em:AddVertex(Vector3.new(-B, -DN, -B) - OFF)
		local p2 = em:AddVertex(Vector3.new(-B + 0.001, -DN, -B) - OFF)
		local p3 = em:AddVertex(Vector3.new(B, UP, B) - OFF)
		local p4 = em:AddVertex(Vector3.new(B - 0.001, UP, B) - OFF)
		em:AddTriangle(p1, p2, p1)
		em:AddTriangle(p3, p4, p3)
		local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		mp.Name = "FxFoamMesh"
		mp.Anchored = true
		mp.CanCollide = false
		mp.CanQuery = false
		mp.CanTouch = false
		mp.CastShadow = true
		mp.Material = Enum.Material.SmoothPlastic
		mp.Color = color
		mp.Transparency = 1
		mp.Size = Vector3.new(2 * B, UP + DN, 2 * B)
		mp.Parent = parent
		-- 붓기 단계에서 국자 속 Fx를 지우면 메시 메모리도 같이 정리
		mp.Destroying:Connect(function()
			em:Destroy()
		end)
		self.part = mp
		return self
	end)
	if ok and res then
		return res
	end
	if not ok then
		warn("[FoamMesh] 넘친 거품 메시를 만들 수 없어요:", res)
	end
	return nil
end

-- 각도 a에서 흘러내린 길이 비율 (0 = 테두리 바로 아래까지, 1 = 가장 긴 줄기)
function Foam:runAt(a)
	local best = 0
	for _, t in ipairs(self.tongues) do
		local d = math.abs((a - t.a + math.pi) % (2 * math.pi) - math.pi)
		local g = math.exp(-(d / t.w) ^ 2)
		best = math.max(best, g * t.len)
	end
	return best
end

-- rimCenter = 국자 테두리 가운데 (세계 좌표), Rb = 테두리 반지름, depth = 국자 깊이
-- apex = 테두리 위로 돔 꼭대기 높이, domeR = 돔이 테두리에 닿는 반지름 (테두리보다 조금 큼),
-- sheet = 테두리를 덮은 거품 두께, run = 흘러내린 정도 (0~1.3)
function Foam:update(rimCenter, Rb, depth, apex, domeR, sheet, run)
	local em = self.em
	local cos, sin = self.cos, self.sin
	-- 국자 바깥 면 = 구의 일부 (테두리 반지름 Rb, 깊이 depth)
	local Rs = (Rb * Rb + depth * depth) / (2 * depth)
	local cy = Rs - depth -- 구 가운데 높이 (테두리 = 0)
	local function wall(y)
		local dy = y - cy
		return math.sqrt(math.max(Rs * Rs - dy * dy, 0))
	end
	local leave = -depth * 0.62 -- 이 아래로는 국자 면을 떠나 곧게 늘어짐
	local wallLeave = wall(leave)
	em:SetPosition(self.top, Vector3.new(0, apex, 0) - OFF)
	for j = 1, NA do
		local a = (j - 1) / NA * 2 * math.pi
		local c, s = cos[j], sin[j]
		-- 돔 가장자리가 살짝 울퉁불퉁 (거품이 고르게 부풀지 않음)
		local wob = 1 + 0.035 * math.sin(3 * a + self.wob[1]) + 0.025 * math.sin(5 * a + self.wob[2])
		local tg = self:runAt(a)
		local L = (0.06 + (depth * 0.9 + 0.55) * tg) * run -- 테두리 아래로 내려온 길이
		local T = sheet * (0.75 + 0.6 * tg) -- 줄기는 더 굵음
		local dR = domeR * wob
		for i = 1, self.NR do
			local rho, y
			if i <= ND then
				-- 돔: 가운데 꼭대기 → 가장자리 (테두리 위 sheet 높이)
				local u = i / ND
				rho = dR * u
				y = sheet + (apex - sheet) * (1 - u * u) ^ 0.7
			elseif i <= ND + NL then
				-- 테두리를 넘어 말림: (dR, sheet) → (Rb + T, -0.02) 사분원
				local u = (i - ND) / NL
				local th = u * math.pi / 2
				local r0 = math.max(dR, Rb + T)
				rho = r0 + (Rb + T - r0) * (1 - math.cos(th)) + T * 0.35 * math.sin(th) * (1 - u)
				y = sheet * math.cos(th) - 0.02 * math.sin(th)
			else
				-- 바깥 면을 따라 흘러내림. 끝으로 갈수록 굵어졌다가 둥글게 닫힘
				local u = (i - ND - NL) / NW
				local d = L * u
				local yy = -0.02 - d
				local base = yy > leave and wall(yy) or wallLeave - 0.04 * math.min((leave - yy) / 0.4, 1)
				local bulb = 1 + 0.45 * math.exp(-((u - 0.82) / 0.12) ^ 2) * tg
				local close = u > 0.9 and math.sqrt(math.max(0, 1 - ((u - 0.9) / 0.1) ^ 2)) or 1
				rho = base + T * bulb * close
				y = yy
			end
			em:SetPosition(self.rings[i][j], Vector3.new(rho * c, y, rho * s) - OFF)
		end
	end
	self.part.CFrame = CFrame.new(rimCenter + OFF)
end

function Foam:destroy()
	if self.part then
		self.part:Destroy()
	end
end

return Foam

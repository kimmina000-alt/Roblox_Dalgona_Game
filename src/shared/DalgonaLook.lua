-- 완성된 달고나 겉모습 (2026-11-21 사용자: "진열대에 내가 만든 완성품 모양으로 진열", "손님은 그 완성품 들고 먹으면서 감")
-- 보관함 아이템(stock item) 하나로 작은 달고나 모델을 만든다. 서버·클라이언트 둘 다 씀 (Part만, 메시·EditableMesh 없음)
--   item.s = 도안 id, item.g = 등급, item.pk = 포장, item.plain = 민짜(모양 안 찍음), item.br = 쪼개짐(지금은 안 팔림)
-- DalgonaLook.build(item, opts 또는 지름) → Model (PrimaryPart = "Disc", 피벗 = 원판 가운데)
--   opts.diameter (기본 1.0), opts.upright = true면 세워서(원판 면이 +Z, 막대는 아래), 아니면 눕혀서(면이 위 +Y, 막대는 +Z)
--   opts.stick (기본 true) 막대, opts.anchored (기본 true)
-- 모양 선은 CutterShapes 바깥선을 간추려 짧은 선분 몇 개로 (진열대 10칸 × 여러 가게라 부품 수를 아낌)

local CutterShapes = require(script.Parent:WaitForChild("CutterShapes"))

local DalgonaLook = {}

local GOLD = Color3.fromRGB(214, 150, 74)
local GRADE_COLOR = {
	Perfect = Color3.fromRGB(226, 166, 84),
	Excellent = Color3.fromRGB(218, 154, 76),
	Good = GOLD,
	Normal = Color3.fromRGB(200, 136, 62),
	Poor = Color3.fromRGB(176, 112, 50),
	Burnt = Color3.fromRGB(64, 42, 30),
	Fail = Color3.fromRGB(190, 128, 60),
}
local GROOVE = Color3.fromRGB(110, 62, 26)
local STICK = Color3.fromRGB(232, 212, 172)
local BAG = Color3.fromRGB(245, 250, 255)
local TIE = Color3.fromRGB(226, 176, 52)
local MAX_SEGS = 18 -- 모양 선분 수 최대

local outlineCache = {}
local function outlineFor(id)
	if outlineCache[id] ~= nil then
		return outlineCache[id] or nil
	end
	local pts = nil
	for _, s in ipairs(CutterShapes) do
		if s.id == id then
			pts = s.outline
			break
		end
	end
	if not pts or #pts < 3 then
		outlineCache[id] = false
		return nil
	end
	-- 둘레를 고르게 MAX_SEGS개 점으로 다시 뽑음 (모양은 유지, 부품 수는 줄임)
	local n = #pts
	local lens, total = {}, 0
	for i = 1, n do
		local a, b = pts[i], pts[i % n + 1]
		lens[i] = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		total += lens[i]
	end
	local k = math.min(MAX_SEGS, n)
	local out, seg, acc = {}, 1, 0
	for j = 0, k - 1 do
		local want = total * j / k
		while seg < n and acc + lens[seg] < want do
			acc += lens[seg]
			seg += 1
		end
		local a, b = pts[seg], pts[seg % n + 1]
		local t = lens[seg] > 1e-6 and (want - acc) / lens[seg] or 0
		table.insert(out, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t })
	end
	-- 바깥선 크기 → 원판 반지름 비율로 맞출 수 있게 최대 거리
	local r = 0
	for _, p in ipairs(out) do
		r = math.max(r, math.sqrt(p[1] * p[1] + p[2] * p[2]))
	end
	outlineCache[id] = { pts = out, r = r }
	return outlineCache[id]
end

local function part(parent, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

function DalgonaLook.build(item, opts)
	if type(opts) == "number" then
		opts = { diameter = opts } -- build(item, 지름) 으로도 부름 (진열대 칸 약 1.2, 손님 손 약 1.0)
	end
	opts = opts or {}
	local D = opts.diameter or 1.0
	local R = D / 2
	local T = math.max(0.05, D * 0.08) -- 두께
	local anchored = opts.anchored ~= false
	local m = Instance.new("Model")
	m.Name = "DalgonaLook"
	local color = GRADE_COLOR[item and item.g or ""] or GOLD
	-- 눕힌 기준(면이 +Y)으로 만들고, 세우려면 마지막에 통째로 돌림
	local base = CFrame.new()
	local disc = part(m, "Disc", Vector3.new(T, D, D), base * CFrame.Angles(0, 0, math.rad(90)), color, { Shape = Enum.PartType.Cylinder, Anchored = anchored })
	-- 가장자리 살짝 진한 띠 (구운 테두리)
	part(m, "Rim", Vector3.new(T * 0.9, D * 1.02, D * 1.02), base * CFrame.new(0, -T * 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), color:Lerp(Color3.new(0.3, 0.17, 0.08), 0.25), { Shape = Enum.PartType.Cylinder, Anchored = anchored })
	-- 찍힌 모양 홈 (민짜·탄 것은 없음)
	if item and not item.plain and item.g ~= "Burnt" then
		local o = outlineFor(item.s or "")
		if o and o.r > 0 then
			local k = R * 0.72 / o.r
			local w = math.max(0.02, D * 0.035)
			local y = T / 2 + 0.004
			local n = #o.pts
			for i = 1, n do
				local a, b = o.pts[i], o.pts[i % n + 1]
				-- 모양 좌표: x 오른쪽, y 위쪽(눕힌 원판에서는 -Z)
				local pa = Vector3.new(a[1] * k, y, -a[2] * k)
				local pb = Vector3.new(b[1] * k, y, -b[2] * k)
				local len = (pb - pa).Magnitude
				if len > 1e-3 then
					part(m, "Groove", Vector3.new(w, 0.01, len + w * 0.6), base * CFrame.lookAt((pa + pb) / 2, pb), GROOVE, { Anchored = anchored })
				end
			end
		end
	end
	-- 막대 (원판 아래쪽 = 눕힌 기준 +Z 쪽으로 나옴)
	if opts.stick ~= false then
		local L = D * 0.9
		part(m, "Stick", Vector3.new(D * 0.1, T * 0.5, L), base * CFrame.new(0, 0, R * 0.45 + L / 2), STICK, { Anchored = anchored, Material = Enum.Material.Wood })
	end
	-- 포장: 투명 비닐 + 금색 빵끈 (막대 쪽 목에서 묶음)
	if item and item.pk then
		part(m, "Bag", Vector3.new(D * 1.18, T * 2.4, D * 1.3), base * CFrame.new(0, 0, D * 0.05), BAG, { Anchored = anchored, Transparency = 0.62, Reflectance = 0.15 })
		part(m, "Tie", Vector3.new(D * 0.28, T * 2.8, D * 0.06), base * CFrame.new(0, 0, R + D * 0.12), TIE, { Anchored = anchored, Material = Enum.Material.Metal })
	end
	-- 피벗 = 원판 가운데·눕힌 기준 방향 (원판 부품은 원기둥이라 돌려 놓았으므로 PivotOffset으로 되돌림)
	disc.PivotOffset = disc.CFrame:Inverse() * base
	m.PrimaryPart = disc
	if opts.upright then
		-- 세움: 원판 면이 +Z를 보고 막대는 아래로
		m:PivotTo(CFrame.Angles(math.rad(90), 0, 0))
		disc.PivotOffset = disc.CFrame:Inverse() -- 세운 자세를 새 기준(피벗 = 회전 없음)으로
	end
	if not anchored then
		-- 같이 움직이게 원판에 붙임 (손에 들 때)
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p ~= disc then
				local wc = Instance.new("WeldConstraint")
				wc.Part0 = disc
				wc.Part1 = p
				wc.Parent = p
			end
		end
	end
	return m
end

return DalgonaLook

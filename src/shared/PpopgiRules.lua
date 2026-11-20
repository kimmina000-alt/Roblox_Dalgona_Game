-- 뽑기 (7단계, 선택. 15번, 2026-11-20) 판정 규칙: 서버·클라이언트 공용
-- 바늘 끝 자리 표본(틀 기준 좌표)을 차례로 넣으면 따라간 비율·금·쪼개짐이 나온다.
-- 클라이언트는 화면에 보여 주려고 같은 표본을 그대로 넣고, 서버는 받은 표본으로 다시 계산한다 (같은 결과).
-- 좌표: CutterShapes 외곽선 × 틀 배율(stud). x 오른쪽, y 화면 위쪽 (틀 Root 기준 X = x, Z = -y)
-- 가격: 판매가 × (1 + 0.5 × 정확도), Q에는 안 넣음. 쪼개지면 Poor 가격 (GDD 2-3, DEVELOPMENT_PLAN 5장)

local CutterShapes = require(script.Parent:WaitForChild("CutterShapes"))

local R = {}

R.SCALE = 0.65 -- CutterRig.SCALE과 같아야 함
R.TOL = 0.11 -- 선에서 이만큼 안이면 "선 위" (stud)
R.OFF_FAR = 0.5 -- 선에서 이보다 멀면 긁는 게 아님 (무시)
R.BIN = 0.06 -- 따라간 비율을 세는 칸 길이 (stud)
R.JUMP = 0.35 -- 선 위 표본 두 개가 이 길이 안이면 사이 칸도 긁은 걸로
R.SAFE = 0.45 -- 안전 속도 (stud/초). 넘으면 금 갈 힘이 쌓임
R.FAST_K = 2.0 -- (속도/SAFE − 1) × FAST_K × 시간
R.OFF_K = 1.4 -- 선 밖에서 긁으면 초당 쌓이는 힘
R.RELAX = 0.12 -- 천천히 긁는 동안 초당 빠지는 힘
R.TAU = 0.3 -- 속도는 이 시간(초)만큼 부드럽게 잼 (손 떨림을 빠르기로 안 셈)
R.BREAK = 3 -- 금이 이만큼이면 쪼개짐
R.DONE = 0.96 -- 따라간 비율이 이만큼이면 뽑기 성공
R.RATE = 20 -- 초당 표본 수
R.MAX_SAMPLES = 1600
R.MAX_TIME = 75 -- 이보다 길면 저절로 그만 (초)
R.BONUS = 0.5 -- 판매가 × (1 + BONUS × 정확도)
R.BROKEN_MULT = 0.5 -- 쪼개지면 Poor 가격 배율 (DalgonaConfig.Grades Poor)
R.PERFECT_ACC = 0.9 -- 금 없이 이 정확도 이상이면 "완벽 뽑기"

local function find(id)
	for _, s in ipairs(CutterShapes) do
		if s.id == id then
			return s
		end
	end
	return nil
end

-- 긁을 선: 바깥선 + 안쪽 구멍 (장식선은 각인만 되고 떼어 내지 않음)
function R.path(shapeId)
	local shape = find(shapeId)
	if not shape then
		return nil
	end
	local loops = {}
	local total = 0
	local function addLoop(pts)
		if not pts or #pts < 3 then
			return
		end
		local L = { x = {}, y = {}, s = {}, len = 0 }
		for i, p in ipairs(pts) do
			L.x[i] = p[1] * R.SCALE
			L.y[i] = p[2] * R.SCALE
		end
		local n = #pts
		L.n = n
		for i = 1, n do
			local j = i % n + 1
			L.s[i] = L.len
			L.len += math.sqrt((L.x[j] - L.x[i]) ^ 2 + (L.y[j] - L.y[i]) ^ 2)
		end
		L.nb = math.max(4, math.ceil(L.len / R.BIN))
		L.binLen = L.len / L.nb
		total += L.nb
		table.insert(loops, L)
	end
	addLoop(shape.outline)
	for _, h in ipairs(shape.holes or {}) do
		addLoop(h)
	end
	if #loops == 0 then
		return nil
	end
	return { loops = loops, total = total, id = shapeId }
end

-- 가장 가까운 선 위 점: 고리 번호, 고리 위 거리 s, 떨어진 거리 d, 그 점 (x, y)
function R.nearest(path, x, y)
	local bestD, bestL, bestS, bx, by = math.huge, 1, 0, x, y
	for li, L in ipairs(path.loops) do
		for i = 1, L.n do
			local j = i % L.n + 1
			local ax, ay = L.x[i], L.y[i]
			local dx, dy = L.x[j] - ax, L.y[j] - ay
			local ll = dx * dx + dy * dy
			local t = ll > 1e-9 and math.clamp(((x - ax) * dx + (y - ay) * dy) / ll, 0, 1) or 0
			local px, py = ax + dx * t, ay + dy * t
			local d = (x - px) ^ 2 + (y - py) ^ 2
			if d < bestD then
				bestD, bestL, bestS, bx, by = d, li, L.s[i] + t * math.sqrt(ll), px, py
			end
		end
	end
	return bestL, bestS, math.sqrt(bestD), bx, by
end

-- 고리 위 거리 s의 점
function R.pointAt(path, li, s)
	local L = path.loops[li]
	s = s % L.len
	for i = 1, L.n do
		local j = i % L.n + 1
		local seg = (i < L.n and L.s[j] or L.len) - L.s[i]
		if s <= L.s[i] + seg or i == L.n then
			local t = seg > 1e-9 and (s - L.s[i]) / seg or 0
			return L.x[i] + (L.x[j] - L.x[i]) * t, L.y[i] + (L.y[j] - L.y[i]) * t
		end
	end
	return L.x[1], L.y[1]
end

function R.newRun(path)
	local hit = {}
	for li in ipairs(path.loops) do
		hit[li] = {}
	end
	return { path = path, hit = hit, covered = 0, stress = 0, cracks = 0, crackAt = {}, offT = 0, downT = 0, vx = 0, vy = 0, last = nil, t = 0, newBins = {} }
end

local function mark(run, li, b)
	local L = run.path.loops[li]
	b = b % L.nb
	if not run.hit[li][b] then
		run.hit[li][b] = true
		run.covered += 1
		table.insert(run.newBins, { li, b })
	end
end

local function markRange(run, li, s1, s2)
	local L = run.path.loops[li]
	local d = (s2 - s1) % L.len
	if d > L.len / 2 then
		s1, s2 = s2, s1
		d = L.len - d
	end
	if d > R.JUMP then
		mark(run, li, math.floor(s2 / L.binLen))
		return
	end
	local b1 = math.floor(s1 / L.binLen)
	local steps = math.floor((s1 % L.binLen + d) / L.binLen)
	for k = 0, steps do
		mark(run, li, b1 + k)
	end
end

-- 표본 하나 넣기. t = 시작부터 초, (x, y) = 바늘 끝(틀 기준), down = 누르고 있는지.
-- 반환: "crack"(금이 감) / "broken"(쪼개짐) / nil, 그리고 지금 상태 { on, d, speed, li, s }
function R.feed(run, t, x, y, down)
	run.newBins = {}
	run.t = t
	if not down then
		run.last = nil
		run.vx, run.vy = 0, 0
		return nil, nil
	end
	local li, s, d = R.nearest(run.path, x, y)
	local on = d <= R.TOL
	local far = d > R.OFF_FAR
	local state = { on = on, d = d, li = li, s = s, speed = 0, far = far }
	local event = nil
	local last = run.last
	if on then
		if last and last.on and last.li == li then
			markRange(run, li, last.s, s)
		else
			mark(run, li, math.floor(s / run.path.loops[li].binLen))
		end
	end
	if last and not far then
		local dt = math.clamp(t - last.t, 0, 0.25)
		if dt > 0 then
			local k = math.min(1, dt / R.TAU)
			run.vx += ((x - last.x) / dt - run.vx) * k
			run.vy += ((y - last.y) / dt - run.vy) * k
			local speed = math.sqrt(run.vx * run.vx + run.vy * run.vy)
			state.speed = speed
			run.downT += dt
			local add = 0
			if speed > R.SAFE then
				add += (speed / R.SAFE - 1) * R.FAST_K * dt
			end
			if not on then
				add += R.OFF_K * dt
				run.offT += dt
			end
			if add > 0 then
				run.stress += add
			else
				run.stress = math.max(0, run.stress - R.RELAX * dt)
			end
			if run.stress >= 1 and run.cracks < R.BREAK then
				run.stress = 0
				run.cracks += 1
				table.insert(run.crackAt, { x, y })
				event = run.cracks >= R.BREAK and "broken" or "crack"
			end
		end
	end
	run.last = { t = t, x = x, y = y, on = on, li = li, s = s }
	return event, state
end

function R.coverage(run)
	return run.covered / math.max(run.path.total, 1)
end

-- 최종 결과. quit = 다 따라가기 전에 그만둠
function R.result(run)
	local cov = R.coverage(run)
	local broken = run.cracks >= R.BREAK
	local done = cov >= R.DONE and not broken
	local acc = 0
	if done then
		local off = run.offT / math.max(run.downT, 0.5)
		acc = math.clamp(1 - 0.2 * run.cracks - 0.6 * off, 0, 1)
	end
	acc = math.floor(acc * 100 + 0.5) / 100
	return {
		coverage = math.floor(cov * 100 + 0.5) / 100,
		cracks = run.cracks,
		broken = broken,
		done = done,
		acc = acc,
		perfect = done and run.cracks == 0 and acc >= R.PERFECT_ACC,
		bonus = (done and not broken) and (1 + R.BONUS * acc) or 1,
		time = math.floor(run.t * 10 + 0.5) / 10,
	}
end

-- 표본 배열 (t, x, y, down 1/0 이어 붙임) 전체로 계산 (서버). 잘못된 값이면 nil, 이유
function R.evaluate(path, flat, maxT)
	if type(flat) ~= "table" or #flat % 4 ~= 0 or #flat > R.MAX_SAMPLES * 4 then
		return nil, "bad samples"
	end
	local run = R.newRun(path)
	local prevT = -1
	for i = 1, #flat, 4 do
		local t, x, y, dn = flat[i], flat[i + 1], flat[i + 2], flat[i + 3]
		if type(t) ~= "number" or type(x) ~= "number" or type(y) ~= "number" or t ~= t or x ~= x or y ~= y then
			return nil, "bad number"
		end
		if t < prevT or t > maxT or math.abs(x) > 5 or math.abs(y) > 5 then
			return nil, "bad time"
		end
		prevT = t
		R.feed(run, t, x, y, dn == 1)
		if run.cracks >= R.BREAK then
			break
		end
	end
	return R.result(run)
end

return R

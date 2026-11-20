-- 품질 판정: Q = 0.25T + 0.20M + 0.25P + 0.30S
-- 서버(최종 점수)와 클라이언트(미리 보기, QUALITY 링)가 같은 함수를 쓴다.

local Config = require(script.Parent:WaitForChild("DalgonaConfig"))

local Scoring = {}

local function c01(x)
	return math.clamp(x, 0, 1)
end

local function round(x)
	return math.floor(x + 0.5)
end

function Scoring.sugar(r)
	local inLadle = r.white + r.brown
	local need = Config.Sugar.white + Config.Sugar.brown
	local accuracy = 1 - math.abs(inLadle - need) / need
	return math.clamp(100 * c01(accuracy) * inLadle / math.max(inLadle + r.spill, 1e-3), 0, 100)
end

function Scoring.melt(r)
	local s = 100 * (0.5 * r.green + 0.5 * r.tempOk) - r.scorch * 30 - r.burn * 25
	return math.clamp(s, 0, 100)
end

function Scoring.soda(r)
	local cfg = Config.Soda
	local timing = 100 * c01(1 - (r.delay - cfg.bestDelay) / 14)
	local a = r.amount
	local amountS
	if a < cfg.idealMin then
		amountS = 100 * a / cfg.idealMin
	elseif a > cfg.idealMax then
		amountS = 100 * c01(1 - (a - cfg.idealMax) / 0.85)
	else
		amountS = 100
	end
	local puff = 100 * c01(r.fastFrac) * c01(r.puff)
	return math.clamp(0.3 * timing + 0.35 * amountS + 0.35 * puff, 0, 100)
end

-- 동그란 정도 (2026-11-20 "전체 외곽선을 봤을 때 원형에 가까운 게 제일 잘 만든 거, 들쑥날쑥하면 엉망"):
-- 가장자리 반지름이 평균에서 벗어난 정도(dev, 평균 반지름 1 기준) → 0~1. 0.03까지는 완전한 원으로 침, 0.25면 0
function Scoring.roundFromDev(dev)
	return c01(1 - (dev - 0.03) / 0.22)
end

-- 모양 점수 (0~1): 동그란 정도 × 길쭉하지 않음
function Scoring.pourShape(r)
	return c01(r.round or 1) * c01(1 - ((r.spread or 1) - 1.15) / 0.65)
end

function Scoring.pour(r)
	-- 가운데 30 · 동그랗게 55 · 다 부음 15
	local s = 30 * c01(1 - r.dist / 1.4) + 55 * Scoring.pourShape(r) + 15 * c01(1 - r.remain / 0.15)
	-- 길쭉하면 틀이 안 맞아 전체 감점
	s *= 0.5 + 0.5 * c01(1 - ((r.spread or 1) - 1.15) / 0.65)
	return math.clamp(s, 0, 100)
end

-- 일직선 등으로 길쭉하게 부어 틀이 안 맞음 = 실패
function Scoring.misshaped(records)
	local p = records.pour
	return p ~= nil and (p.spread or 1) > Config.Pour.failSpread
end

-- 목표 ±18% 안이면 만점 (2026-11-19 "누르기 100점 받기 어려움"), 그 밖은 목표의 60%만큼 벗어나면 0점
function Scoring.pressOne(i, h)
	local t = Config.Press.targets[i]
	return 100 * c01(1 - math.max(0, math.abs(h - t) - 0.18 * t) / (t * 0.6))
end

function Scoring.press(r)
	local sum = 0
	for i = 1, 3 do
		sum += Scoring.pressOne(i, r.thick[i] or 1)
	end
	local s = sum / 3
	if r.cracked then
		s -= 35
	end
	return math.clamp(s, 0, 100)
end

function Scoring.stampForce(hold)
	local cfg = Config.Stamp
	if hold < cfg.holdMin then
		return 40 + 60 * hold / cfg.holdMin
	elseif hold <= cfg.holdMax then
		return 100
	end
	return 100 * c01(1 - (hold - cfg.holdMax) / 0.5)
end

function Scoring.stamp(r)
	local center = 100 * c01(1 - r.dist / 0.6)
	local angle = 100 * c01(1 - math.abs(r.angle) / 30)
	local s = 0.5 * center + 0.2 * angle + 0.3 * Scoring.stampForce(r.hold)
	if r.hold > Config.Stamp.crackHold then
		s -= 20
	end
	return math.clamp(s, 0, 100)
end

function Scoring.gradeFor(q)
	for _, g in ipairs(Config.Grades) do
		if q >= g.min then
			return g
		end
	end
	return Config.Grades[#Config.Grades]
end

function Scoring.starsFor(q)
	local n = 0
	for _, cut in ipairs(Config.StarCut) do
		if q >= cut then
			n += 1
		end
	end
	return n
end

-- records: { sugar = {...}, melt = {...}, ... } (없는 단계는 0점)
-- shape: ShapeCatalog 항목 (가격). 없으면 Config.Shape
function Scoring.compute(records, shape)
	local s = {}
	for _, step in ipairs(Config.Steps) do
		local r = records[step.key]
		s[step.key] = r and Scoring[step.key](r) or 0
	end
	local T = 0.2 * s.sugar + 0.8 * s.melt
	local M = s.soda
	local P = 0.3 * s.pour + 0.7 * s.press
	local S = s.stamp
	local w = Config.Weights
	local q = w.T * T + w.M * M + w.P * P + w.S * S
	local burnt = records.melt ~= nil and records.melt.burnt == true
	if burnt then
		q = math.min(q, 20)
	end
	local misshaped = Scoring.misshaped(records)
	if misshaped then
		q = math.min(q, 15)
	end
	q = math.clamp(round(q), 0, 100)
	local g = Scoring.gradeFor(q)
	if misshaped and not burnt then
		g = { name = "Fail", mult = 0.2 }
	end
	for k, v in pairs(s) do
		s[k] = round(v)
	end
	return {
		Q = q,
		T = round(T),
		M = round(M),
		P = round(P),
		S = round(S),
		steps = s,
		grade = g.name,
		mult = g.mult,
		stars = Scoring.starsFor(q),
		burnt = burnt,
		misshaped = misshaped,
		cracked = (records.press ~= nil and records.press.cracked == true)
			or (records.stamp ~= nil and records.stamp.hold > Config.Stamp.crackHold),
		price = round((shape or Config.Shape).price * g.mult),
	}
end

-- 결과 화면용 (사용자 요청 2026-11-19: 어디에서 몇 점인지): 단계마다 점수 + 세부 항목 점수
-- 반환: { { key, label, score, parts = { {name, value} ... } } ... } (Config.Steps 순서)
function Scoring.explain(records)
	local out = {}
	for _, step in ipairs(Config.Steps) do
		local r = records[step.key]
		local parts = {}
		if r then
			if step.key == "sugar" then
				local inLadle = r.white + r.brown
				local need = Config.Sugar.white + Config.Sugar.brown
				table.insert(parts, { "양", round(100 * c01(1 - math.abs(inLadle - need) / need)) })
				table.insert(parts, { "안 흘림", round(100 * inLadle / math.max(inLadle + r.spill, 1e-3)) })
			elseif step.key == "melt" then
				table.insert(parts, { "젓기 속도", round(100 * (r.green or 0)) })
				table.insert(parts, { "온도 유지", round(100 * (r.tempOk or 0)) })
				if (r.burn or 0) > 0.05 or (r.scorch or 0) > 0.05 then
					table.insert(parts, { "탐", -round((r.scorch or 0) * 30 + (r.burn or 0) * 25) })
				end
			elseif step.key == "soda" then
				local cfg = Config.Soda
				local a = r.amount
				local amountS = a < cfg.idealMin and 100 * a / cfg.idealMin or (a > cfg.idealMax and 100 * c01(1 - (a - cfg.idealMax) / 0.85) or 100)
				table.insert(parts, { "넣은 때", round(100 * c01(1 - (r.delay - cfg.bestDelay) / 14)) })
				table.insert(parts, { "양", round(amountS) })
				table.insert(parts, { "부풀기", round(100 * c01(r.fastFrac) * c01(r.puff)) })
			elseif step.key == "pour" then
				table.insert(parts, { "가운데", round(100 * c01(1 - r.dist / 1.4)) })
				table.insert(parts, { "동그랗게", round(100 * Scoring.pourShape(r)) })
			elseif step.key == "press" then
				for i = 1, 3 do
					table.insert(parts, { i .. "번째", round(Scoring.pressOne(i, r.thick and r.thick[i] or 1)) })
				end
				if r.cracked then
					table.insert(parts, { "금", -35 })
				end
			elseif step.key == "stamp" then
				table.insert(parts, { "가운데", round(100 * c01(1 - r.dist / 0.6)) })
				table.insert(parts, { "반듯하게", round(100 * c01(1 - math.abs(r.angle) / 30)) })
				table.insert(parts, { "누른 세기", round(Scoring.stampForce(r.hold)) })
			end
		end
		table.insert(out, { key = step.key, label = step.label, score = r and round(Scoring[step.key](r)) or 0, parts = parts, tip = r and Scoring.tip(step.key, r) or "안 했어요" })
	end
	return out
end

-- 결과 화면 한 줄 조언 (사용자 요청 2026-11-19: 누르기를 너무 오래/짧게 눌렀는지 등 단계마다 알려 주기)
function Scoring.tip(key, r)
	local tips = {}
	local function add(s)
		if #tips < 2 then
			table.insert(tips, s)
		end
	end
	if key == "sugar" then
		local inLadle = r.white + r.brown
		local need = Config.Sugar.white + Config.Sugar.brown
		if inLadle < need * 0.9 then
			add("설탕이 조금 모자랐어요")
		elseif inLadle > need * 1.1 then
			add("설탕을 너무 많이 넣었어요")
		end
		if r.spill > 0.1 then
			add("국자 밖으로 흘렸어요")
		end
		add("딱 맞게 넣었어요")
	elseif key == "melt" then
		if (r.burn or 0) > 0.05 then
			add("불에 너무 가까워 탔어요 · 국자를 초록 높이로")
		end
		if (r.scorch or 0) > 0.05 then
			add("젓다 멈춰서 바닥이 눌어붙었어요")
		end
		if (r.green or 0) < 0.6 then
			add("젓는 속도가 너무 느리거나 빨랐어요")
		end
		if (r.tempOk or 1) < 0.6 then
			add("국자 높이가 안 맞아 온도가 들쭉날쭉했어요")
		end
		add("고르게 잘 녹였어요")
	elseif key == "soda" then
		local cfg = Config.Soda
		if r.delay > cfg.bestDelay + 3 then
			add("다 녹은 뒤 소다를 늦게 넣었어요")
		end
		if r.amount < cfg.idealMin then
			add("소다가 적어서 덜 부풀었어요")
		elseif r.amount > cfg.idealMax then
			add("소다가 많아서 쓰고 꺼졌어요")
		end
		if (r.fastFrac or 0) < 0.6 or (r.puff or 0) < 0.9 then
			add("소다 넣고 더 빠르게 오래 저어야 해요")
		end
		add("딱 좋게 부풀었어요")
	elseif key == "pour" then
		if r.dist > 0.5 then
			add("설탕 원 가운데에서 벗어나게 부었어요")
		end
		if (r.spread or 1) > 1.3 then
			add("끌면서 부어서 길쭉해졌어요")
		end
		if (r.round or 1) < 0.6 then
			add("가장자리가 들쑥날쑥해요 · 한 곳에 모아 떨어뜨려요")
		end
		if (r.remain or 0) > 0.1 then
			add("국자에 반죽이 남았어요")
		end
		add("가운데에 동그랗게 잘 부었어요")
	elseif key == "press" then
		if r.cracked then
			add("너무 얇게 눌러서 금이 갔어요")
		end
		for i = 1, 3 do
			local h, t = r.thick and r.thick[i], Config.Press.targets[i]
			if h and h > t * 1.18 then
				add(i .. "번째: 짧게 눌러서 두꺼워요")
			elseif h and h < t * 0.82 then
				add(i .. "번째: 너무 오래 눌러서 얇아요")
			end
		end
		add("세 번 모두 딱 맞게 눌렀어요")
	elseif key == "stamp" then
		local cfg = Config.Stamp
		if r.hold > cfg.crackHold then
			add("너무 오래 눌러서 금이 갔어요")
		elseif r.hold > cfg.holdMax then
			add("조금 오래 눌러서 너무 깊어요")
		elseif r.hold < cfg.holdMin then
			add("너무 짧게 눌러서 자국이 흐려요")
		end
		if r.dist > 0.3 then
			add("틀이 가운데에서 벗어났어요")
		end
		if math.abs(r.angle) > 10 then
			add("틀이 비뚤어졌어요")
		end
		add("가운데에 반듯하게 잘 찍었어요")
	end
	-- 문제가 있으면 문제만, 없으면 칭찬 한 줄
	if #tips > 1 then
		local good = tips[#tips]
		if good:find("잘") or good:find("딱") then
			table.remove(tips)
		end
	end
	return table.concat(tips, " · ")
end

-- QUALITY 링: 지금까지 알려진 단계 점수의 가중 평균 (0~100)
function Scoring.live(stepScores)
	local sw, sum = 0, 0
	for key, w in pairs(Config.LiveWeights) do
		local v = stepScores[key]
		if v then
			sw += w
			sum += w * v
		end
	end
	if sw == 0 then
		return 100
	end
	return sum / sw
end

return Scoring

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
	local timing = 100 * c01(1 - (r.delay - cfg.bestDelay) / 8)
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

function Scoring.pour(r)
	local s = 80 * c01(1 - r.dist / 1.4) + 20 * c01(1 - r.remain / 0.15)
	-- 한 곳에 모아 붓지 않고 끌면서 부으면 길쭉해져 감점 (1.15배까지는 괜찮음)
	s *= c01(1 - ((r.spread or 1) - 1.15) / 0.65)
	return math.clamp(s, 0, 100)
end

-- 일직선 등으로 길쭉하게 부어 틀이 안 맞음 = 실패
function Scoring.misshaped(records)
	local p = records.pour
	return p ~= nil and (p.spread or 1) > Config.Pour.failSpread
end

function Scoring.pressOne(i, h)
	local t = Config.Press.targets[i]
	return 100 * c01(1 - math.abs(h - t) / (t * 0.6))
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

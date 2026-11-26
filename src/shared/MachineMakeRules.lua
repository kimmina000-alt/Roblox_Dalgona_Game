-- 2·3단계 기계 직접 만들기 판정 (D35·D41). 서버(MachineMakeService, 최종 점수)와 클라이언트(MachineMake, Studio 시험)가 같은 함수를 쓴다.
-- 2026-11-26 사용자 "손 작업대 구현 방식·게임 방식 그대로": 녹이기·소다는 손 작업대 단계 모듈(Steps/Melt, Steps/Soda)을 그대로 돌리고,
-- 점수도 손 제작과 같은 식(shared/Scoring)·같은 서버 다시 계산(ProductionService와 같은 표본 재계산)으로 한다.
-- 클라이언트는 점수 대신 입력 기록만 보낸다:
--   sugar = { t0, t1, fill }                                          설탕 받은 양 (꽉 참 = 1)
--   melt  = 손 제작 녹이기 기록 { t0, t1, green, tempOk, scorch, burn, burnt, samples = { {zone, temp}, ... } }
--   soda  = 손 제작 소다 기록 { t0, t1, delay, amount, fastFrac, puff, samples = { {zone}, ... } }
--   pour  = { t0, t1, fills = { 칸마다 채운 양 } }
--   stick = { t0, t1 }
--   press = { t0, t1, h }   (D62) 금형판 누름판으로 한 번 누른 두께 (손 작업대 마지막 목표 0.08)
-- 3단계(D63): 설탕·소다는 앞면 기둥에서 정량 → sugar = { t0, t1, held }(기둥에 댄 초), 설탕은 점수에서 빼고 소다 양은 서버가 정량으로 넣음.
-- 가중치는 단계별 (GDD 19장 D63 표). 녹이다 태우면(melt.burnt) 뒤 단계 없이 끝나고 품질은 손 제작처럼 Q 20 이하 (Burnt).
-- 시각(t0, t1)은 workspace:GetServerTimeNow(). 서버는 단계 순서·걸린 시간·표본을 검사한다.
local Shared = script.Parent
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))

local Rules = {}

Rules.STEPS = { "sugar", "melt", "soda", "pour", "press", "stick" }
-- 단계별 가중치 (D62·D63 권장안, 2026-11-26): 3단계는 설탕이 정량이라 0
Rules.WEIGHTS = {
	[2] = { sugar = 0.10, melt = 0.30, soda = 0.20, pour = 0.20, press = 0.20 },
	[3] = { sugar = 0, melt = 0.30, soda = 0.20, pour = 0.25, press = 0.25 },
}
Rules.WEIGHT = Rules.WEIGHTS[2]
Rules.SODA_FIXED = 0.5 -- 3단계 오른쪽 기둥 정량 (Config.Soda 알맞은 양 가운데)
Rules.SUGAR_HOLD = 1.2 -- 3단계: 설탕 기둥에 국자를 댄 시간이 이 이상이어야 (정량이 다 나오는 데 약 1.5초)
Rules.BURNT_Q = 20 -- 탔으면 Q 이 값 이하 (손 제작 Scoring.compute와 같음)

Rules.SUGAR_RATE = 0.42 -- 설탕 받는 빠르기 (1 = 꽉 참, 초당)
Rules.SUGAR_LO, Rules.SUGAR_HI, Rules.SUGAR_MAX = 0.72, 0.95, 1.25
Rules.POUR_RATE = 0.75 -- 칸에 붓는 빠르기 (초당)
Rules.BATTER_PER_CAVITY = 1.05 -- 국자에 든 반죽 = 칸 수 × 이 값
Rules.CAVITY_FULL = 0.85

local function c(x, lo, hi)
	return math.clamp(x, lo, hi)
end

function Rules.sugar(fill)
	fill = c(fill or 0, 0, Rules.SUGAR_MAX)
	if fill >= Rules.SUGAR_LO and fill <= Rules.SUGAR_HI then
		return 100
	elseif fill < Rules.SUGAR_LO then
		return math.max(20, 100 - (Rules.SUGAR_LO - fill) * 160)
	end
	return math.max(20, 100 - (fill - Rules.SUGAR_HI) * 220)
end

-- 붓기: 칸마다 꽉 찬 정도 (1에 가까울수록), n = 이번 판 칸 수
function Rules.pour(fills, n)
	if n <= 0 then
		return 0
	end
	local sum = 0
	for i = 1, n do
		local f = tonumber(fills[i]) or 0
		sum += c(100 - math.abs(f - 1) * 220, 0, 100)
	end
	return sum / n
end

-- 누르기 (D62): 손 작업대 Scoring.pressOne의 마지막 목표(0.08) 한 번, 너무 얇으면(갈라짐) -35
function Rules.press(h)
	h = c(tonumber(h) or 1, 0, 1)
	local s = Scoring.pressOne(3, h)
	if h < Config.Press.crack then
		s -= 35
	end
	return c(s, 0, 100)
end

function Rules.quality(scores, stage)
	local q = 0
	for k, w in pairs(Rules.WEIGHTS[stage] or Rules.WEIGHT) do
		q += c(tonumber(scores[k]) or 0, 0, 100) * w
	end
	q = math.floor(q + 0.5)
	if scores.burnt then
		q = math.min(q, Rules.BURNT_Q)
	end
	return q
end

---------------------------------------------------------------- 서버 검사

local function num(v, lo, hi, default)
	if type(v) ~= "number" or v ~= v then
		return default
	end
	return math.clamp(v, lo, hi)
end

-- 손 제작 ProductionService와 같은 받는 값 { 이름, 최소, 최대, 기본값 }
local FIELDS = {
	melt = { { "green", 0, 1, 0 }, { "tempOk", 0, 1, 0 }, { "scorch", 0, 5, 5 }, { "burn", 0, 1, 1 } },
	soda = { { "delay", 0, 120, 120 }, { "amount", 0, 3, 0 }, { "fastFrac", 0, 1, 0 }, { "puff", 0, 1, 0 } },
}

-- 녹이기 표본 { zone(1 느림, 2 적당, 3 빠름), 온도 }로 비율 다시 계산 (ProductionService recomputeMelt와 같음, 화로 업그레이드 없음)
local function recomputeMelt(rec, samples)
	if type(samples) ~= "table" or #samples < 5 then
		return
	end
	local n, green, ok, counted = 0, 0, 0, 0
	local started = false
	local okLow, okHigh = Config.Melt.tempLow, Config.Melt.tempHigh
	for i, s in ipairs(samples) do
		if i > Config.Server.maxSamples then
			break
		end
		if type(s) == "table" then
			local zone = num(s[1], 1, 3, 1)
			local temp = num(s[2], 0, 400, 0)
			n += 1
			if zone == 2 then
				green += 1
			end
			if temp >= Config.Melt.tempLow - 5 then
				started = true
			end
			if started then
				counted += 1
				if temp >= okLow - 5 and temp <= okHigh + 3 then
					ok += 1
				end
			end
		end
	end
	if n > 0 then
		rec.green = green / n
	end
	if counted > 0 then
		rec.tempOk = ok / counted
	end
end

local function recomputeSoda(rec, samples)
	if type(samples) ~= "table" or #samples < 3 then
		return
	end
	local n, fast = 0, 0
	for i, s in ipairs(samples) do
		if i > Config.Server.maxSamples then
			break
		end
		if type(s) == "table" then
			n += 1
			if num(s[1], 1, 3, 1) == 3 then
				fast += 1
			end
		end
	end
	if n > 0 then
		rec.fastFrac = fast / n
	end
end

-- raw = 클라이언트 기록, t0 = 세션 시작(서버 시각), now = 지금(서버 시각), n = 이번 판 칸 수, stage = 2 | 3
-- 반환: scores { sugar, melt, soda, pour, press, burnt } 또는 nil, 이유
function Rules.evaluate(raw, t0, now, n, stage)
	stage = stage == 3 and 3 or 2
	if type(raw) ~= "table" then
		return nil, "bad payload"
	end
	local prevEnd = t0 - 1
	local rec, rawOf = {}, {}
	local burnt = false
	for _, key in ipairs(Rules.STEPS) do
		local r = raw[key]
		if r == nil and burnt then
			break -- 녹이다(또는 소다 넣기 전에) 태우면 뒤 단계 없음
		end
		if type(r) ~= "table" then
			return nil, "missing step " .. key
		end
		local a, b = num(r.t0, 0, math.huge, -1), num(r.t1, 0, math.huge, -1)
		if a < prevEnd - 0.5 or b <= a or b > now + 1 then
			return nil, "bad order " .. key
		end
		local dur = b - a
		if (key == "melt" or key == "soda") and (dur < Config.Server.minStep or dur > Config.Server.maxStep) then
			return nil, "bad duration " .. key
		end
		prevEnd = b
		local clean = { dur = dur }
		for _, f in ipairs(FIELDS[key] or {}) do
			clean[f[1]] = num(r[f[1]], f[2], f[3], f[4])
		end
		if key == "melt" then
			clean.burnt = r.burnt == true or clean.burn >= 1
			burnt = clean.burnt
			recomputeMelt(clean, r.samples)
		elseif key == "soda" then
			recomputeSoda(clean, r.samples)
			if stage == 3 then
				clean.amount = Rules.SODA_FIXED -- 정량 기둥: 클라이언트 값 대신 (D63)
			end
			if r.burnt == true then
				burnt = true -- 소다 넣기 전에 타 버림 (Soda.run이 ctx.markBurnt)
			end
		end
		rec[key] = clean
		rawOf[key] = r
	end

	local scores = { burnt = burnt }
	if stage == 3 then
		-- 설탕 기둥: 국자를 댄 시간 검사만, 점수 없음 (가중치 0)
		local held = num(rawOf.sugar.held, 0, 60, 0)
		if held < Rules.SUGAR_HOLD or rec.sugar.dur < held - 0.3 then
			return nil, "sugar hold"
		end
		scores.sugar = 100
	else
		-- 설탕: 꾹 누른 시간 이상 걸렸어야 함
		local fill = num(rawOf.sugar.fill, 0, Rules.SUGAR_MAX, 0)
		if rec.sugar.dur < fill / Rules.SUGAR_RATE * 0.85 - 0.3 then
			return nil, "sugar too fast"
		end
		scores.sugar = Rules.sugar(fill)
	end
	scores.melt = Scoring.melt(rec.melt)
	scores.soda = rec.soda and Scoring.soda(rec.soda) or 0
	scores.pour = 0
	if rec.pour then
		-- 붓기: 반죽은 칸 수 × 1.05까지, 붓는 시간 이상 걸렸어야 함
		local fills, total = {}, 0
		local rf = type(rawOf.pour.fills) == "table" and rawOf.pour.fills or {}
		for i = 1, n do
			fills[i] = num(rf[i], 0, n * Rules.BATTER_PER_CAVITY, 0)
			total += fills[i]
		end
		if total > n * Rules.BATTER_PER_CAVITY + 0.02 then
			return nil, "pour too much"
		end
		if rec.pour.dur < total / Rules.POUR_RATE * 0.85 - 0.3 then
			return nil, "pour too fast"
		end
		scores.pour = Rules.pour(fills, n)
	end
	scores.press = 0
	if rec.press then
		-- 누르기: 0.45에서 목표까지 내려오는 데 걸리는 시간보다 빨리 끝낼 수 없음
		local h = num(rawOf.press.h, 0, Config.Press.h0, Config.Press.h0)
		local need = math.log(Config.Press.h0 / math.max(h, 0.02)) / Config.Press.k
		if rec.press.dur < need * 0.8 - 0.2 then
			return nil, "press too fast"
		end
		scores.press = Rules.press(h)
	end
	if rec.stick and rec.stick.dur < 0.15 * n then
		return nil, "stick too fast"
	end
	if not burnt and not (rec.pour and rec.press and rec.stick) then
		return nil, "missing step"
	end
	return scores
end

return Rules

-- 2·3단계 기계 직접 만들기 판정 (D35·D41). 서버(MachineMakeService, 최종 점수)와 클라이언트(MachineMake, Studio 시험)가 같은 함수를 쓴다.
-- 2026-11-26 사용자 "손 작업대 구현 방식·게임 방식 그대로": 녹이기·소다는 손 작업대 단계 모듈(Steps/Melt, Steps/Soda)을 그대로 돌리고,
-- 점수도 손 제작과 같은 식(shared/Scoring)·같은 서버 다시 계산(ProductionService와 같은 표본 재계산)으로 한다.
-- 클라이언트는 점수 대신 입력 기록만 보낸다:
--   sugar = { t0, t1, fill }                                          설탕 받은 양 (꽉 참 = 1)
--   melt  = 손 제작 녹이기 기록 { t0, t1, green, tempOk, scorch, burn, burnt, samples = { {zone, temp}, ... } }
--   soda  = 손 제작 소다 기록 { t0, t1, delay, amount, fastFrac, puff, samples = { {zone}, ... } }
--   pour  = { t0, t1, fills = { 칸마다 채운 양 } }
--   stick = { t0, t1 }
-- 녹이다 태우면(melt.burnt) 뒤 단계 없이 끝나고 품질은 손 제작처럼 Q 20 이하 (Burnt).
-- 시각(t0, t1)은 workspace:GetServerTimeNow(). 서버는 단계 순서·걸린 시간·표본을 검사한다.
local Shared = script.Parent
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))

local Rules = {}

Rules.STEPS = { "sugar", "melt", "soda", "pour", "stick" }
Rules.WEIGHT = { sugar = 0.15, melt = 0.30, soda = 0.25, pour = 0.30 }
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

function Rules.quality(scores)
	local q = 0
	for k, w in pairs(Rules.WEIGHT) do
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

-- raw = 클라이언트 기록, t0 = 세션 시작(서버 시각), now = 지금(서버 시각), n = 이번 판 칸 수
-- 반환: scores { sugar, melt, soda, pour, burnt } 또는 nil, 이유
function Rules.evaluate(raw, t0, now, n)
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
			if r.burnt == true then
				burnt = true -- 소다 넣기 전에 타 버림 (Soda.run이 ctx.markBurnt)
			end
		end
		rec[key] = clean
		rawOf[key] = r
	end

	local scores = { burnt = burnt }
	-- 설탕: 꾹 누른 시간 이상 걸렸어야 함
	local fill = num(rawOf.sugar.fill, 0, Rules.SUGAR_MAX, 0)
	if rec.sugar.dur < fill / Rules.SUGAR_RATE * 0.85 - 0.3 then
		return nil, "sugar too fast"
	end
	scores.sugar = Rules.sugar(fill)
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
	if rec.stick and rec.stick.dur < 0.15 * n then
		return nil, "stick too fast"
	end
	if not burnt and not (rec.pour and rec.stick) then
		return nil, "missing step"
	end
	return scores
end

return Rules

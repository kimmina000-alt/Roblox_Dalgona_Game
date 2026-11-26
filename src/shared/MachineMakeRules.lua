-- 2·3단계 기계 직접 만들기 판정 (D35·D41). 서버(MachineMakeService, 최종 점수)와 클라이언트(MachineMake, 화면·Studio 시험)가 같은 함수를 쓴다.
-- 클라이언트는 점수 대신 입력 기록만 보낸다 (손 제작 ProductionService와 같은 방식, 2026-11-26):
--   sugar = { t0, t1, fill }                      설탕 받은 양 (꽉 참 = 1)
--   melt  = { t0, t1, s = { 0~3, ... } }          SAMPLE초마다 젓기 상태: 0 안 저음 / 1 느림 / 2 알맞음 / 3 빠름
--   soda  = { t0, t1, dips, s = { 0~2, ... } }     털어 넣은 뒤 SAMPLE초마다: 0 안 저음 / 1 느리게 / 2 빠르게
--   pour  = { t0, t1, fills = { 칸마다 채운 양 } }
--   stick = { t0, t1 }
-- 시각(t0, t1)은 workspace:GetServerTimeNow(). 서버는 단계 순서·걸린 시간·표본 수가 맞는지 보고, 녹은 정도·거품을 표본으로 다시 계산한다.
local Rules = {}

Rules.SAMPLE = 0.2 -- 표본 간격 (초)
Rules.MAX_SAMPLES = 200 -- 단계마다 표본 최대 (녹이기 32초 = 160개)
Rules.STEPS = { "sugar", "melt", "soda", "pour", "stick" }
Rules.WEIGHT = { sugar = 0.15, melt = 0.30, soda = 0.25, pour = 0.30 }

Rules.SUGAR_RATE = 0.42 -- 설탕 받는 빠르기 (1 = 꽉 참, 초당)
Rules.SUGAR_LO, Rules.SUGAR_HI, Rules.SUGAR_MAX = 0.72, 0.95, 1.25
Rules.MELT_RATE = 0.085 -- 알맞은 빠르기로 저을 때 초당 녹는 양 (약 12초)
Rules.MELT_LIMIT = 32
Rules.FOAM_RATE = 0.3 -- 빠르게 저을 때 초당 거품
Rules.FOAM_LIMIT = 25
Rules.POUR_RATE = 0.75 -- 칸에 붓는 빠르기 (초당)
Rules.BATTER_PER_CAVITY = 1.05 -- 국자에 든 반죽 = 칸 수 × 이 값
Rules.CAVITY_FULL = 0.85
-- 서버는 0.2초 표본으로 다시 세서 화면(매 프레임)과 조금 다를 수 있음 (Studio 300판 시험: 0.87~1.05) → 0.85면 "다 됨"으로 침
Rules.DONE = 0.85

local function c(x, lo, hi)
	return math.clamp(x, lo, hi)
end

-- 녹이기에서 한 칸(SAMPLE초)에 녹는 양 (녹이기 화면과 같은 비율)
function Rules.meltGain(zone, dt)
	if zone == 0 then
		return 0
	end
	return dt * Rules.MELT_RATE * (zone == 2 and 1 or zone == 3 and 0.55 or 0.2)
end

-- 소다 젓기에서 한 칸에 오르는 거품
function Rules.foamGain(z, dt)
	if z == 0 then
		return 0
	end
	return dt * Rules.FOAM_RATE * (z == 2 and 1 or 0.35)
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

-- 녹이기: 알맞게 저은 시간 비율. 다 녹기 전에 끝냈으면 녹은 만큼만, 제한 시간을 넘겼으면 ×0.6
function Rules.melt(samples)
	local dt = Rules.SAMPLE
	local melt, good, bad = 0, 0, 0
	for _, z in ipairs(samples) do
		melt += Rules.meltGain(z, dt)
		if z == 2 then
			good += dt
		elseif z == 0 then
			bad += dt -- 안 저으면 바닥이 눌어붙음
		else
			bad += dt * 0.6
		end
	end
	local score = c(100 * good / math.max(good + bad, 0.1), 0, 100)
	if #samples * dt > Rules.MELT_LIMIT then
		score *= 0.6
	elseif melt < Rules.DONE then
		score *= c(melt, 0, 1)
	end
	return score, melt
end

-- 소다: 묻힌 횟수 50% + 거품이 다 오른 빠르기 50%
function Rules.soda(dips, samples)
	dips = math.floor(c(dips or 0, 0, 20))
	local dt = Rules.SAMPLE
	local foam, t, doneAt = 0, 0, nil
	for _, z in ipairs(samples) do
		t += dt
		foam += Rules.foamGain(z, dt)
		if foam >= Rules.DONE and not doneAt then
			doneAt = t
		end
	end
	local dipScore = (dips == 2 or dips == 3) and 100 or (dips == 1 and 70) or 60
	local foamScore = doneAt and c(100 - math.max(0, doneAt - 4) * 6, 40, 100) or 30
	return dipScore * 0.5 + foamScore * 0.5, foam
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
	return math.floor(q + 0.5)
end

---------------------------------------------------------------- 서버 검사

local function num(v, lo, hi, default)
	if type(v) ~= "number" or v ~= v then
		return default
	end
	return math.clamp(v, lo, hi)
end

-- 표본 표를 정수 목록으로 (범위 밖·이상한 값은 0 = 안 저음)
local function cleanSamples(s, maxZone)
	local out = {}
	if type(s) ~= "table" then
		return out
	end
	for i, z in ipairs(s) do
		if i > Rules.MAX_SAMPLES then
			break
		end
		z = num(z, 0, maxZone, 0)
		table.insert(out, math.floor(z + 0.5))
	end
	return out
end

-- 표본 수가 걸린 시간과 맞는지 (프레임 끊김을 생각해 넉넉히)
local function samplesFit(count, dur)
	local expect = dur / Rules.SAMPLE
	return count <= expect + 3 and count >= expect * 0.7 - 3
end

-- raw = 클라이언트 기록, t0 = 세션 시작(서버 시각), now = 지금(서버 시각), n = 이번 판 칸 수
-- 반환: scores { sugar, melt, soda, pour } 또는 nil, 이유
function Rules.evaluate(raw, t0, now, n)
	if type(raw) ~= "table" then
		return nil, "bad payload"
	end
	local prevEnd = t0 - 1
	local rec = {}
	for _, key in ipairs(Rules.STEPS) do
		local r = raw[key]
		if type(r) ~= "table" then
			return nil, "missing step " .. key
		end
		local a, b = num(r.t0, 0, math.huge, -1), num(r.t1, 0, math.huge, -1)
		if a < prevEnd - 0.5 or b <= a or b > now + 1 then
			return nil, "bad order " .. key
		end
		prevEnd = b
		rec[key] = r
		rec[key .. "Dur"] = b - a
	end

	local scores = {}
	-- 설탕: 꾹 누른 시간 이상 걸렸어야 함
	local fill = num(rec.sugar.fill, 0, Rules.SUGAR_MAX, 0)
	if rec.sugarDur < fill / Rules.SUGAR_RATE * 0.85 - 0.3 then
		return nil, "sugar too fast"
	end
	scores.sugar = Rules.sugar(fill)

	-- 녹이기
	local ms = cleanSamples(rec.melt.s, 3)
	if #ms < 5 or not samplesFit(#ms, rec.meltDur) then
		return nil, "melt samples"
	end
	scores.melt = Rules.melt(ms)

	-- 소다 (묻히는 시간이 있어 걸린 시간 ≥ 표본 시간)
	local ss = cleanSamples(rec.soda.s, 2)
	if #ss < 3 or #ss * Rules.SAMPLE > rec.sodaDur + 1 then
		return nil, "soda samples"
	end
	scores.soda = Rules.soda(rec.soda.dips, ss)

	-- 붓기: 반죽은 칸 수 × 1.05까지, 붓는 시간 이상 걸렸어야 함
	local fills, total = {}, 0
	local rf = type(rec.pour.fills) == "table" and rec.pour.fills or {}
	for i = 1, n do
		fills[i] = num(rf[i], 0, n * Rules.BATTER_PER_CAVITY, 0)
		total += fills[i]
	end
	if total > n * Rules.BATTER_PER_CAVITY + 0.02 then
		return nil, "pour too much"
	end
	if rec.pourDur < total / Rules.POUR_RATE * 0.85 - 0.3 then
		return nil, "pour too fast"
	end
	scores.pour = Rules.pour(fills, n)

	-- 막대: 칸마다 한 번 누름
	if rec.stickDur < 0.15 * n then
		return nil, "stick too fast"
	end
	return scores
end

return Rules

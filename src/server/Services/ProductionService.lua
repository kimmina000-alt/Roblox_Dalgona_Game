-- 제작 세션과 서버 점수 계산 (DEVELOPMENT_PLAN.md 4장 "서버 검증")
-- 클라이언트는 단계마다 시각과 측정값, 표본(최대 60개)만 보낸다.
-- 서버는 세션 ID, 단계 순서, 최소/최대 시간을 확인하고, 표본이 있으면 비율을 다시 계산한 뒤
-- 공유 Scoring 공식으로 점수를 낸다. 클라이언트 점수는 받지 않는다. (Phase 1: 저장 없음)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Scoring = require(Shared:WaitForChild("Scoring"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local WorkstationBuilder = require(script.Parent:WaitForChild("WorkstationBuilder"))

local COAL_PER_MAKE = 0.1 -- 연탄 1장으로 10번 만듦

local ProductionService = {}

local sessions = {} -- [player] = { id, t0, lastStart }

local function num(v, lo, hi, default)
	if type(v) ~= "number" or v ~= v then
		return default
	end
	return math.clamp(v, lo, hi)
end

-- 각 단계에서 받을 숫자 필드: { 이름, 최소, 최대, 기본값 }
local FIELDS = {
	sugar = { { "white", 0, 3, 0 }, { "brown", 0, 1, 0 }, { "spill", 0, 10, 10 } },
	melt = { { "green", 0, 1, 0 }, { "tempOk", 0, 1, 0 }, { "scorch", 0, 5, 5 }, { "burn", 0, 1, 1 } },
	soda = { { "delay", 0, 120, 120 }, { "amount", 0, 3, 0 }, { "fastFrac", 0, 1, 0 }, { "puff", 0, 1, 0 } },
	pour = { { "dist", 0, 10, 10 }, { "remain", 0, 1, 1 }, { "spread", 1, 5, 1 } },
	press = {},
	stamp = { { "dist", 0, 10, 10 }, { "angle", -180, 180, 180 }, { "hold", 0, 10, 10 } },
}

-- 표본으로 비율 다시 계산: 표본 = { zone(1 느림, 2 적당, 3 빠름), temp }
local function recomputeMelt(rec, samples)
	if type(samples) ~= "table" or #samples < 5 then
		return
	end
	local n, green, ok, counted = 0, 0, 0, 0
	local started = false
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
				if temp >= Config.Melt.tempLow - 5 and temp <= Config.Melt.tempHigh + 3 then
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

-- 반환: records(정리된 것) 또는 nil, 이유
local function sanitize(session, raw)
	if type(raw) ~= "table" then
		return nil, "bad payload"
	end
	local out = {}
	local prevEnd = session.t0 - 1
	local burnt = false
	for _, step in ipairs(Config.Steps) do
		local r = raw[step.key]
		if r == nil then
			if burnt then
				break -- 녹이다 태우면 뒤 단계 없음
			end
			return nil, "missing step " .. step.key
		end
		if type(r) ~= "table" then
			return nil, "bad step " .. step.key
		end
		local t0, t1 = num(r.t0, 0, math.huge, -1), num(r.t1, 0, math.huge, -1)
		if t0 < prevEnd - 0.5 or t1 <= t0 then
			return nil, "bad order " .. step.key
		end
		local dur = t1 - t0
		if dur < Config.Server.minStep or dur > Config.Server.maxStep then
			return nil, string.format("bad duration %s %.2f", step.key, dur)
		end
		prevEnd = t1
		local rec = { t0 = t0, t1 = t1 }
		for _, f in ipairs(FIELDS[step.key]) do
			rec[f[1]] = num(r[f[1]], f[2], f[3], f[4])
		end
		if step.key == "melt" then
			rec.burnt = r.burnt == true or rec.burn >= 1
			burnt = rec.burnt
			recomputeMelt(rec, r.samples)
		elseif step.key == "soda" then
			recomputeSoda(rec, r.samples)
		elseif step.key == "press" then
			rec.thick = {}
			local thick = type(r.thick) == "table" and r.thick or {}
			for i = 1, 3 do
				rec.thick[i] = num(thick[i], 0, 2, 1)
			end
			rec.cracked = r.cracked == true or rec.thick[3] < Config.Press.crack
		end
		out[step.key] = rec
	end
	return out, prevEnd
end

function ProductionService.start(player, shapeId)
	local now = workspace:GetServerTimeNow()
	local old = sessions[player]
	if old and now - old.t0 < 1 then
		return nil -- 1초에 한 번
	end
	-- 연탄이 다 탔으면 새 연탄으로 갈아 넣음
	local ws = workspace:FindFirstChild("DalgonaWorkstation")
	if ws and (ws:GetAttribute("CoalLeft") or 1) <= 0.001 then
		WorkstationBuilder.setCoal(ws, 1)
	end
	-- 고른 도안 (모르는 id면 기본 도안). 가격은 서버 목록에서만 가져온다
	local shape = ShapeCatalog.get(type(shapeId) == "string" and shapeId or "") or ShapeCatalog.get(ShapeCatalog.default)
	local s = { id = HttpService:GenerateGUID(false), t0 = now, shape = shape }
	sessions[player] = s
	return s.id, s.t0
end

function ProductionService.submit(player, sessionId, raw)
	local s = sessions[player]
	if not s or type(sessionId) ~= "string" or sessionId ~= s.id then
		return { ok = false, reason = "no session" }
	end
	sessions[player] = nil -- 한 세션은 한 번만 제출
	local now = workspace:GetServerTimeNow()
	local records, lastEnd = sanitize(s, raw)
	if not records then
		warn("[Production] rejected", player.Name, lastEnd)
		return { ok = false, reason = lastEnd }
	end
	if lastEnd > now + 1 or now - s.t0 > Config.Server.maxTotal then
		return { ok = false, reason = "time" }
	end
	local result = Scoring.compute(records, s.shape)
	result.ok = true
	result.shapeId = s.shape.id
	-- 쓸수록 연탄이 낮아지고 잿빛이 됨
	local ws = workspace:FindFirstChild("DalgonaWorkstation")
	if ws then
		WorkstationBuilder.setCoal(ws, (ws:GetAttribute("CoalLeft") or 1) - COAL_PER_MAKE)
	end
	print(string.format("[Production] %s %s Q=%d %s price=%d (T%d M%d P%d S%d)", player.Name, s.shape.id, result.Q, result.grade, result.price, result.T, result.M, result.P, result.S))
	return result
end

function ProductionService.init(remotes)
	remotes.StartProduction.OnServerInvoke = ProductionService.start
	remotes.SubmitProduction.OnServerInvoke = ProductionService.submit
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		sessions[p] = nil
	end)
end

return ProductionService

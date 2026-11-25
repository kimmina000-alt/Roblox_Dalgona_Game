-- 2·3단계 기계 직접 쓰기 (D35·D41·D46, 2026-11-26 사용자: 참고 영상 "달고나 판매기" 순서대로, 2·3단계는 같은 순서·판 수만 다름,
-- 금형판 칸이 모양이고 찍기·뽑기는 없음). 화면은 클라이언트 MachineMaking이 그림.
--   Remotes.StartMachineMake:InvokeServer(stage) → { ok, id, shape, batch, reason }
--     2·3단계만 · 그 기계를 가졌고 · 가게 열림 · 그 기계에 알바가 없을 때(D46) · 재료가 1개분 이상 · 보관함 자리가 있을 때
--   Remotes.SubmitMachineMake:InvokeServer(id, { sugar, melt, soda, pour = 0~100, t = 걸린 초 }) → { ok, q, grade, made, perfect, reason }
--     품질 Q = 설탕 15% + 녹이기 30% + 소다 25% + 붓기 30%. 한 판 = 그 기계 batch개(2단계 2, 3단계 5), 재료는 원가대로 그만큼.
--     Perfect(95+)는 한 판에 1개만, 나머지는 Excellent (D41). 기계 것이라 수제 ×1.5(D58)는 안 붙음. EXP = G.ExpMachine × 개수 + 판마다 5
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("GrowthConfig"))
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))

local MM = {}

local Data, Economy = nil, nil
local sessions = {} -- [player] = { id, t0, stage, shape }
local MIN_SECONDS = 10 -- 이보다 빨리 낸 판은 거절 (동전 ~ 막대까지 짧게 잡아도 이보다 김)
local MAX_SECONDS = 300
local WEIGHT = { sugar = 0.15, melt = 0.30, soda = 0.25, pour = 0.30 }
local ROUND_EXP = 5

local function gradeOf(q)
	for _, g in ipairs(Config.Grades) do
		if q >= g.min then
			return g.name, g.mult
		end
	end
	return "Burnt", 0.2
end

local function multOf(name)
	for _, g in ipairs(Config.Grades) do
		if g.name == name then
			return g.mult
		end
	end
	return 1
end

local function shapeFor(d, m)
	local id = d.machine and d.machine.shapes and d.machine.shapes[m.id]
	local e = id and ShapeCatalog.get(id)
	return e
end

-- 지금 만들 수 있는 개수 (재료·보관함 자리)
local function canMakeN(d, shape, m)
	local n = math.min(m.batch, G.stockRoom(d))
	for id, k in pairs(G.recipe(shape.grade)) do
		n = math.min(n, math.floor((d.ingredients[id] or 0) / k))
	end
	return math.max(n, 0)
end

function MM.start(player, stage)
	stage = tonumber(stage)
	if stage ~= 2 and stage ~= 3 then
		return { ok = false, reason = "2·3단계 기계만 직접 쓸 수 있어요" }
	end
	local d = Data.get(player)
	local m = G.Machines[stage]
	if not (d and m) then
		return { ok = false, reason = "잠깐 뒤에 다시 해 봐요" }
	end
	if (d.machineStage or 1) < stage then
		return { ok = false, reason = "아직 이 기계가 없어요" }
	end
	if not G.shopOpen(d) then
		return { ok = false, reason = "가게 문이 닫혀 있어요" }
	end
	if G.helperAt(d, m.id) then
		return { ok = false, reason = "알바가 이 기계에서 일하는 중이에요 · 알바를 빼면 직접 쓸 수 있어요" }
	end
	local shape = shapeFor(d, m)
	if not shape then
		return { ok = false, reason = "기계 창에서 도안을 먼저 골라요" }
	end
	local n = canMakeN(d, shape, m)
	if n <= 0 then
		return { ok = false, reason = G.stockRoom(d) <= 0 and "보관함이 가득 찼어요" or "재료가 모자라요" }
	end
	local s = { id = HttpService:GenerateGUID(false), t0 = workspace:GetServerTimeNow(), stage = stage, shape = shape }
	sessions[player] = s
	return { ok = true, id = s.id, shape = shape.id, batch = n }
end

local function score(v)
	return math.clamp(tonumber(v) or 0, 0, 100)
end

function MM.submit(player, id, raw)
	local s = sessions[player]
	if not s or type(id) ~= "string" or id ~= s.id then
		return { ok = false, reason = "no session" }
	end
	sessions[player] = nil
	local took = workspace:GetServerTimeNow() - s.t0
	if took < MIN_SECONDS or took > MAX_SECONDS then
		return { ok = false, reason = "time" }
	end
	raw = type(raw) == "table" and raw or {}
	local q = 0
	for k, w in pairs(WEIGHT) do
		q += score(raw[k]) * w
	end
	q = math.floor(q + 0.5)
	local grade = gradeOf(q)
	local m = G.Machines[s.stage]
	local made, perfect, ups, newShapes = 0, false, {}, {}
	Data.update(player, function(d)
		local n = canMakeN(d, s.shape, m)
		if n <= 0 then
			return false
		end
		for idk, k in pairs(G.recipe(s.shape.grade)) do
			d.ingredients[idk] -= k * n
		end
		for i = 1, n do
			-- Perfect는 한 판에 1개만 (D41), 나머지는 Excellent
			local g = grade
			if grade == "Perfect" and i > 1 then
				g = "Excellent"
			end
			if g == "Perfect" then
				perfect = true
			end
			local mult = multOf(g)
			local item = { s = s.shape.id, g = g, q = (g == grade) and q or math.min(q, 94), b = s.shape.price, m = mult, pk = false, a = true, direct = true }
			item.p = G.salePrice(item.b, item.m, G.GachaBonusDefault, false)
			Economy.stockProduced(d, item, "machine")
		end
		d.stats.machineMade = (d.stats.machineMade or 0) + n
		d.stats.machineDirect = (d.stats.machineDirect or 0) + 1
		ups = Economy.addExp(d, G.ExpMachine * n + ROUND_EXP)
		made = n
	end)
	if made <= 0 then
		return { ok = false, reason = "재료나 보관함 자리가 모자라요" }
	end
	Economy.announceLevels(player, ups)
	Economy.push(player)
	print(string.format("[MachineMake] %s stage %d %s x%d Q%d %s", player.Name, s.stage, s.shape.id, made, q, grade))
	return { ok = true, q = q, grade = grade, made = made, perfect = perfect }
end

function MM.init(dataService, economyService, remotes)
	Data, Economy = dataService, economyService
	if remotes.StartMachineMake then
		remotes.StartMachineMake.OnServerInvoke = MM.start
	end
	if remotes.SubmitMachineMake then
		remotes.SubmitMachineMake.OnServerInvoke = MM.submit
	end
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		sessions[p] = nil
	end)
end

return MM

-- 2·3단계 기계 직접 쓰기 (D35·D41·D46, 2026-11-26 사용자: 참고 영상 "달고나 판매기" 순서대로, 2·3단계는 같은 순서·판 수만 다름,
-- 금형판 칸이 모양이고 찍기·뽑기는 없음). 화면은 클라이언트 MachineMaking이 그림.
--   Remotes.StartMachineMake:InvokeServer(stage) → { ok, id, shape, batch, reason }
--     2·3단계만 · 그 기계를 가졌고 · 가게 열림 · 그 기계에 알바가 없을 때(D46) · 재료가 1개분 이상 · 보관함 자리가 있을 때
--   Remotes.SubmitMachineMake:InvokeServer(id, 입력 기록) → { ok, q, grade, made, perfect, reason }
--     입력 기록은 점수가 아니라 단계 시각·설탕 양·젓기 표본·칸마다 채운 양 (2026-11-26, 손 제작처럼 서버가 다시 셈).
--     형식·검사·점수식은 shared/MachineMakeRules. 품질 Q = 설탕 15% + 녹이기 30% + 소다 25% + 붓기 30%. 한 판 = 그 기계 batch개(2단계 2, 3단계 5), 재료는 원가대로 그만큼.
--     Perfect(95+)는 한 판에 1개만, 나머지는 Excellent (D41). 기계 것이라 수제 ×1.5(D58)는 안 붙음. EXP = G.ExpMachine × 개수 + 판마다 5
--     도감(D38)에는 손으로 만든 것으로 셈 (D41): 손 제작처럼 한 판에 한 번, 그 판의 가장 좋은 등급으로 CollectionService.onMade
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("GrowthConfig"))
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local Rules = require(Shared:WaitForChild("MachineMakeRules"))

local MM = {}
local Collection = nil -- CollectionService (도감, 처음 쓸 때 가져옴 — SalesService와 같은 방식)

local Data, Economy = nil, nil
local sessions = {} -- [player] = { id, t0, stage, shape, batch = 이번 판 칸 수 }
local MIN_SECONDS = 10 -- 이보다 빨리 낸 판은 거절 (동전 ~ 막대까지 짧게 잡아도 이보다 김)
local MAX_SECONDS = 300
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

-- 기계 메시를 클라이언트도 볼 수 있게 ReplicatedStorage.Assets.MachineMeshes로 복사 (제작 화면 MachineMakeScene이 씀).
-- 원본: 편집 화면 Workspace.MachineLayout.StageN.StageNMachine (서버 시작 때 MachineDisplay가 ServerStorage.Assets로 옮김)
local function ensureMesh(stage)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return
	end
	local folder = assets:FindFirstChild("MachineMeshes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MachineMeshes"
		folder.Parent = assets
	end
	local name = "Stage" .. stage .. "Machine"
	if folder:FindFirstChild(name) then
		return
	end
	local SS = game:GetService("ServerStorage")
	local layout = workspace:FindFirstChild("MachineLayout") or (SS:FindFirstChild("Assets") and SS.Assets:FindFirstChild("MachineLayout"))
	local t = layout and layout:FindFirstChild("Stage" .. stage)
	local src = t and t:FindFirstChild(name)
	if src and src:IsA("BasePart") then
		local c = src:Clone()
		c.Anchored = true
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.CFrame = CFrame.new()
		c.Parent = folder
	end
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
	ensureMesh(stage)
	local s = { id = HttpService:GenerateGUID(false), t0 = workspace:GetServerTimeNow(), stage = stage, shape = shape, batch = n }
	sessions[player] = s
	return { ok = true, id = s.id, shape = shape.id, batch = n }
end

function MM.submit(player, id, raw)
	local s = sessions[player]
	if not s or type(id) ~= "string" or id ~= s.id then
		return { ok = false, reason = "no session" }
	end
	sessions[player] = nil
	local nowT = workspace:GetServerTimeNow()
	local took = nowT - s.t0
	if took < MIN_SECONDS or took > MAX_SECONDS then
		return { ok = false, reason = "time" }
	end
	-- 점수는 클라이언트가 보낸 값이 아니라 입력 기록으로 다시 셈 (순서·시간·표본 수 검사 포함)
	local scores, why = Rules.evaluate(raw, s.t0, nowT, s.batch, s.stage)
	if not scores then
		warn("[MachineMake] rejected", player.Name, why)
		return { ok = false, reason = "기록이 이상해서 이번 판은 못 받았어요" }
	end
	local q = Rules.quality(scores, s.stage)
	local grade = gradeOf(q)
	local m = G.Machines[s.stage]
	local made, perfect, ups, newShapes = 0, false, {}, {}
	local notes, newTitles, gold = {}, {}, false
	Collection = Collection or require(script.Parent:WaitForChild("CollectionService"))
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
		-- 도감 (D41: 기계 직접 만들기도 손으로 만든 것으로 셈). 한 판에 한 번, 가장 좋은 등급 = grade (Perfect면 Perfect)
		local okC, cNotes, cUps, cTitles, cGold = pcall(Collection.onMade, d, s.shape, { grade = grade })
		if okC then
			notes, newTitles, gold = cNotes or {}, cTitles or {}, cGold == true
			for _, u in ipairs(cUps or {}) do
				table.insert(ups, u)
			end
		else
			warn("[MachineMake] 도감 기록 실패:", cNotes)
		end
	end)
	if made <= 0 then
		return { ok = false, reason = "재료나 보관함 자리가 모자라요" }
	end
	Collection.after(player, notes, newTitles, gold) -- 도감 알림·칭호·간판 금테
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
	-- 첫 제작 때 기다리지 않게 미리 복사 (MachineDisplay가 MachineLayout을 옮긴 뒤)
	task.delay(3, function()
		ensureMesh(2)
		ensureMesh(3)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		sessions[p] = nil
	end)
end

return MM

-- 기계 2~4단계 (20번, 2026-11-21): 철제 판매기 → 분홍 자판기 → 연속 생산 설비
-- 기준: SHOP_GROWTH_PLAN 1·3~5장, GDD 13장 D3·D9·D10·D12·D13·D16·D21·D26. 수치는 GrowthConfig.Machines / G.Machine
--  - 가게 뒤 기계 1자리에서 단계대로 바꿔 산다 (D10). 손 작업대·알바생은 그대로.
--  - 가게를 임대·매입했고 문이 열려 있을 때만 사고 돌아간다 (D21).
--  - 한 판 = batch개 / seconds초. 판을 시작할 때 재료(설탕·소다, 원가대로)를 확인하고 끝날 때 쓴다. 젓가락·빵끈 안 씀 (D16)
--  - 품질 Normal~Excellent (Perfect는 손으로만), 도안은 Legendary까지 (D13), 1개당 EXP G.ExpMachine
--  - 다 만들면 EconomyService.stockProduced: 진열대 빈 칸 → 없으면 보관함 (D26). 보관함이 차면 멈춤
--  - 접속 중에만 돈다 (알바생과 같음). 진행 초(machine.t)는 저장
--
-- 화면 쪽과의 약속 (제작 세션이 모델·연출·도안 고르기 UI를 맡음): 부지 모델의 MachineSlot 파트 속성
--   Stage(1 없음, 2~4), MachineId, Running, Status("work" | 멈춘 이유), Shape, CycleStart·CycleSeconds(서버 시각),
--   MadeAt·MadeCount·MadeSlots("3,4,7" 진열한 칸) — 한 판 끝날 때마다
-- 조작: Remotes.GrowthAction ("buy","machine") / ("machineShape", 도안 id). 상태: 스냅숏 growth.machine

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("GrowthConfig"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local Config = require(Shared:WaitForChild("DalgonaConfig"))

local MachineService = {}

local Data, Economy, Plots, hooks = nil, nil, nil, nil
local state = {} -- [player] = { status, running, cycleStart }

local GRADE_INDEX = {}
for i, g in ipairs(ShapeCatalog.Grades) do
	GRADE_INDEX[g.id] = i
end
local MAX_GRADE = GRADE_INDEX[G.Machine.maxGrade]

local function spec(d)
	return G.Machines[d.machineStage or 1]
end

local function isUnlocked(d, id)
	return table.find(d.unlockedShapes, id) ~= nil
end

-- 기계가 만들 수 있는 도안 (해금 + Legendary까지), 가격 순
local function allowedShapes(d)
	local list = {}
	for _, e in ipairs(ShapeCatalog.list) do
		if e.gradeIndex <= MAX_GRADE and isUnlocked(d, e.id) then
			table.insert(list, e.id)
		end
	end
	return list
end

-- 지금 기계가 만들 도안: 고른 것 → 없으면(또는 못 쓰면) 가장 싼 허용 도안 (알바생과 같음)
local function currentShape(d)
	local m = spec(d)
	if not m then
		return nil
	end
	local id = d.machine.shapes[m.id]
	local e = id and ShapeCatalog.get(id)
	if e and e.gradeIndex <= MAX_GRADE and isUnlocked(d, e.id) then
		return e
	end
	local list = allowedShapes(d)
	return list[1] and ShapeCatalog.get(list[1]) or nil
end

local function rollQuality()
	local q = math.random(G.Machine.qMin, G.Machine.qMax)
	for _, g in ipairs(Config.Grades) do
		if q >= g.min then
			return q, g.name, g.mult
		end
	end
	return q, "Normal", 0.8
end

-- 한 판에 쓸 재료 (도안 등급 원가 × 개수)
local function batchNeed(shape, n)
	local per = G.recipe(shape.grade)
	local need = {}
	for id, k in pairs(per) do
		need[id] = k * n
	end
	return need
end

-- 멈춘 이유 (없으면 nil)
local function stopReason(d, shape, m)
	if not G.shopOpen(d) then
		return "가게 문 닫힘"
	end
	if not shape then
		return "도안 없음"
	end
	if #d.stock >= G.stockMax(d) then
		return "보관함 가득"
	end
	local need = batchNeed(shape, m.batch)
	for _, ing in ipairs(G.Ingredients) do
		if (need[ing.id] or 0) > (d.ingredients[ing.id] or 0) then
			return ing.name .. " 부족"
		end
	end
	return nil
end

local function slotPart(player)
	local plot = Plots.get(player)
	local slot = plot and plot.model:FindFirstChild("MachineSlot") or nil
	if slot and state[player] then
		state[player].slot = slot -- 나갈 때 부지가 먼저 풀려도 지울 수 있게
	end
	return slot
end

local function setAttr(inst, name, value)
	if inst:GetAttribute(name) ~= value then
		inst:SetAttribute(name, value)
	end
end

-- MachineSlot 속성을 지금 상태로
local function publish(player, d)
	local slot = slotPart(player)
	if not slot then
		return
	end
	local m = spec(d)
	local st = state[player] or {}
	local shape = currentShape(d)
	setAttr(slot, "Stage", m and (d.machineStage or 1) or 1)
	setAttr(slot, "MachineId", m and m.id or "")
	setAttr(slot, "Running", m ~= nil and st.status == "work")
	setAttr(slot, "Status", m and (st.status or "work") or "")
	setAttr(slot, "Shape", shape and shape.id or "")
	setAttr(slot, "CycleSeconds", m and m.seconds or 0)
	setAttr(slot, "CycleStart", st.cycleStart or 0)
end

local function clearSlot(player)
	local slot = state[player] and state[player].slot
	if not slot or not slot.Parent then
		return
	end
	for _, name in ipairs({ "MachineId", "Status", "Shape", "MadeSlots" }) do
		slot:SetAttribute(name, "")
	end
	slot:SetAttribute("Stage", 1)
	slot:SetAttribute("Running", false)
	slot:SetAttribute("CycleStart", 0)
	slot:SetAttribute("CycleSeconds", 0)
end

---------------------------------------------------------------- 구매·도안 (GrowthService.action 안, Data.update 안에서 부름)

-- 다음 단계 기계 사기 (단계 순서대로, 이전 기계는 바뀜)
function MachineService.buy(d)
	local nextStage = (d.machineStage or 1) + 1
	local m = G.Machines[nextStage]
	if not m then
		return false, "기계는 최고 단계예요 (공장은 따로)"
	end
	if d.shop.state == "stall" then
		return false, string.format("가게를 임대해야 기계를 들일 수 있어요 (Lv%d, 보증금 %d)", G.Shop.rentLevel, G.Shop.deposit)
	end
	if not G.shopOpen(d) then
		return false, "월세를 내야 가게가 열려요"
	end
	if d.level < m.level then
		return false, string.format("%s은(는) Lv%d부터예요", m.name, m.level)
	end
	if d.coins < m.price then
		return false, string.format("%d코인이 필요해요", m.price)
	end
	d.coins -= m.price
	d.machineStage = nextStage
	d.machine.t = 0
	return true, string.format("%s 설치! %d초마다 %d개", m.name, m.seconds, m.batch)
end

function MachineService.setShape(d, shapeId)
	local m = spec(d)
	if not m then
		return false, "기계가 없어요"
	end
	local e = ShapeCatalog.get(shapeId)
	if not e then
		return false, "잘못된 요청"
	end
	if not isUnlocked(d, e.id) then
		return false, "아직 안 열린 도안이에요"
	end
	if e.gradeIndex > MAX_GRADE then
		return false, "기계는 레전더리 도안까지 만들어요"
	end
	d.machine.shapes[m.id] = e.id
	d.machine.t = 0 -- 도안을 바꾸면 그 판은 처음부터
	return true, string.format("%s: %s", m.name, e.name)
end

-- 구매·도안 바꾼 뒤 (Data.update 밖)
function MachineService.changed(player)
	local d = Data.get(player)
	if not d then
		return
	end
	local st = state[player]
	if st then
		st.cycleStart = nil
		st.status = nil
	end
	publish(player, d)
end

---------------------------------------------------------------- 스냅숏 (HUD·도안 고르기 UI)

function MachineService.snapshot(player, d)
	local m = spec(d)
	local st = state[player] or {}
	local nx = G.Machines[(d.machineStage or 1) + 1]
	local shape = currentShape(d)
	return {
		stage = d.machineStage or 1,
		id = m and m.id or nil,
		name = m and m.name or nil,
		shape = shape and shape.id or nil,
		status = m and (st.status or "work") or nil,
		running = m ~= nil and (st.status or "work") == "work",
		t = m and math.floor(d.machine.t or 0) or 0,
		seconds = m and m.seconds or 0,
		batch = m and m.batch or 0,
		next = nx and { stage = (d.machineStage or 1) + 1, name = nx.name, level = nx.level, price = nx.price } or nil,
		shapes = m and allowedShapes(d) or {},
	}
end

---------------------------------------------------------------- 생산 (1초마다)

local function finishBatch(player, shape, m)
	local made, slots, ups, newShapes = 0, {}, {}, {}
	Data.update(player, function(dd)
		local room = G.stockMax(dd) - #dd.stock
		local n = math.min(m.batch, room)
		if n <= 0 then
			return false
		end
		-- 재료: 판을 시작할 때 한 판치가 있는지 봤지만, 그 사이 손으로 썼을 수 있어 만들 수 있는 만큼만
		local per = G.recipe(shape.grade)
		for id, k in pairs(per) do
			n = math.min(n, math.floor((dd.ingredients[id] or 0) / k))
		end
		if n <= 0 then
			return false
		end
		for id, k in pairs(per) do
			dd.ingredients[id] -= k * n
		end
		for _ = 1, n do
			local q, grade, mult = rollQuality()
			local item = { s = shape.id, g = grade, q = q, b = shape.price, m = mult, pk = false, a = true }
			item.p = G.salePrice(item.b, item.m, G.GachaBonusDefault, false)
			local sl = Economy.stockProduced(dd, item, "machine")
			if sl then
				table.insert(slots, sl)
			end
		end
		dd.stats.machineMade = (dd.stats.machineMade or 0) + n
		ups = Economy.addExp(dd, G.ExpMachine * n)
		if #ups > 0 and hooks.refreshUnlocks then
			newShapes = hooks.refreshUnlocks(dd)
		end
		made = n
	end)
	if made <= 0 then
		return 0
	end
	Economy.announceLevels(player, ups)
	if #newShapes > 0 then
		Economy.notify(player, "새 도안: " .. table.concat(newShapes, ", "))
	end
	local slot = slotPart(player)
	if slot then
		table.sort(slots)
		slot:SetAttribute("MadeCount", made)
		slot:SetAttribute("MadeSlots", table.concat(slots, ","))
		slot:SetAttribute("MadeAt", workspace:GetServerTimeNow())
	end
	print(string.format("[Machine] %s %s made %d %s shelf=%s", player.Name, m.id, made, shape.id, table.concat(slots, ",")))
	return made
end

local function step(player, dt)
	local d = Data.get(player)
	if not d or not d.machine then
		return
	end
	local m = spec(d)
	local st = state[player]
	if not st then
		st = {}
		state[player] = st
	end
	if not m then
		if st.status ~= nil then
			st.status = nil
			publish(player, d)
		end
		return
	end
	local shape = currentShape(d)
	local why = stopReason(d, shape, m)
	local before = st.status
	if why then
		st.status = why
		st.cycleStart = nil
	else
		st.status = "work"
		d.machine.t = (d.machine.t or 0) + dt -- 저장은 자동 저장 때 같이 (매초 알리지 않음)
		if not st.cycleStart then
			st.cycleStart = workspace:GetServerTimeNow() - d.machine.t
		end
		if d.machine.t >= m.seconds then
			d.machine.t = 0
			st.cycleStart = workspace:GetServerTimeNow()
			finishBatch(player, shape, m)
		end
	end
	publish(player, d)
	if before ~= st.status then
		Economy.push(player) -- 멈춘 이유가 바뀌면 HUD에도
	end
end

function MachineService.init(dataService, economyService, plotService, growthHooks)
	Data, Economy, Plots, hooks = dataService, economyService, plotService, growthHooks or {}
	Data.Changed:Connect(function(player)
		local d = Data.get(player)
		if d and d.machine then
			publish(player, d)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		clearSlot(p)
		state[p] = nil
	end)
	task.spawn(function()
		while true do
			local dt = task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(step, player, dt)
				if not ok then
					warn("[Machine] step failed", player.Name, err)
				end
			end
		end
	end)
end

return MachineService

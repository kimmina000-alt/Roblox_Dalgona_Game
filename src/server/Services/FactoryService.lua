-- 5단계 달고나 공장 (2026-11-21): 가게 뒷문 → 뒤에 붙은 공장 부지, 제어대로 자동 생산
-- 기준: SHOP_GROWTH_PLAN 6~8장, GDD 13장 D8·D11·D13·D26. 수치는 GrowthConfig.Factory
--  - 해금: Lv25 + 300,000, 연속 생산 설비(4단계) 보유, 가게 임대·매입. 공장은 가게 건물 뒤에 붙음 (D11, 2026-11-22)
--  - 제어대 설정(도안·수량·방식)으로 생산을 켜면, 빈 라인마다 판을 시작: 재료·운영비·전력비를 먼저 빼고 시간이 지나면 다 나옴
--  - 한 판 20개(대량 생산 모듈 30·40) / 100초 (+3초/개), 정밀 ×1.5(Good~Excellent), 고속 ×0.7(Poor~Good), 일반 Normal~Good
--  - 도안 Legendary까지, Perfect 없음. 다 만든 것은 stockProduced (진열대 빈 칸 → 보관함, D26)
--  - 제한 (8장): ① 재료 부족 → 멈춤 ② 보관함 가득 → 멈춤 ③ 손님 수요는 SalesService가 정함(재고만 쌓임)
--    ④ 유지비 1개당 operatingCoins ⑤ 업그레이드가 늘수록 판당 전력비 (powerPerUpgrade × 단계 수)
--  - 접속 중에만 돈다 (오프라인 생산은 아직 안 정함)
--
-- 화면 쪽과의 약속 (제작 세션: 공장 모델·제어대 화면·연출): workspace.Factories.Factory<부지 번호>
--   (Folder, 속성만) OwnerUserId, Unlocked, On, Shape, Qty, Mode, Lines, Status,
--   Line<k>Start·Line<k>Seconds·Line<k>Count·Line<k>Shape, MadeAt·MadeCount·MadeSlots.
--   공장 부지·3D는 제작 세션의 Plot<i>.FactoryLot (Ground = 영역, Building = 해금하면 그 가게만). 뒷문으로 걸어 들어감 (D11, 11-22)
--   남의 공장 부지에 들어오면 서버가 자기 가게 앞으로 돌려보냄. 뒷문 FactoryPrompt는 안내만
-- 조작: Remotes.GrowthAction ("buy","factory") / ("factorySet", {shape,qty,mode}) / ("factoryRun", bool) / ("factoryUp", key)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("GrowthConfig"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local Config = require(Shared:WaitForChild("DalgonaConfig"))

local FactoryService = {}

local F = G.Factory
local Data, Economy, Plots, hooks = nil, nil, nil, nil
local spaces = {} -- [부지 번호] = Model
local status = {} -- [player] = 상태 글

local GRADE_INDEX = {}
for i, g in ipairs(ShapeCatalog.Grades) do
	GRADE_INDEX[g.id] = i
end
local MAX_GRADE = GRADE_INDEX[F.maxGrade]

local UP = {}
for _, u in ipairs(F.upgrades) do
	UP[u.key] = u
end

local function isUnlocked(d, id)
	return table.find(d.unlockedShapes, id) ~= nil
end

local function allowedShapes(d)
	local list = {}
	for _, e in ipairs(ShapeCatalog.list) do
		if e.gradeIndex <= MAX_GRADE and isUnlocked(d, e.id) then
			table.insert(list, e.id)
		end
	end
	return list
end

local function shapeOf(d)
	local e = ShapeCatalog.get(d.factory.shape)
	if e and e.gradeIndex <= MAX_GRADE and isUnlocked(d, e.id) then
		return e
	end
	local list = allowedShapes(d)
	return list[1] and ShapeCatalog.get(list[1]) or nil
end

local function lineCount(d)
	return 1 + math.min(d.factory.ups.parallel or 0, 1)
end

local function upgradeSteps(d)
	local n = 0
	for _, v in pairs(d.factory.ups) do
		n += v
	end
	return n
end

---------------------------------------------------------------- 공정 알바생 (D30)

local STAFF = F.staff

-- D43 (2026-11-24): 공정 알바생은 가게 알바생 목록(partTimers)의 역할 f_<key>
local function hired(d, key)
	return G.factoryStaffed(d, key)
end

local function staffSet(d)
	local on = {}
	for _, st in ipairs(STAFF.stations) do
		if hired(d, st.key) then
			on[st.key] = true
		end
	end
	return on
end

-- 1명 급여 (그 판 시간만큼)
local function staffWage(sec)
	return math.floor(sec / 30 * STAFF.wagePer30s + 0.5)
end

-- 한 판에 드는 것 (재료·코인). on = 이번 판에 일하는 공정 { key = true } (없으면 고용한 공정 모두로 미리 보기)
local function jobCost(d, shape, qty, on)
	on = on or staffSet(d)
	local sugar = (G.recipe(shape.grade).sugar or 1) * qty
	if on.sugar then
		sugar -= math.floor(sugar * STAFF.sugarSave) -- ① 설탕 넣기
	end
	local need = { sugar = sugar }
	for id, k in pairs(F.perItem) do
		need[id] = (need[id] or 0) + k * qty
	end
	if on.pack then -- ⑤ 포장 = 자동 포장 (D28)
		for id, k in pairs(F.packPerItem) do
			need[id] = (need[id] or 0) + k * qty
		end
	end
	local coins = F.operatingCoins * qty + F.powerPerUpgrade * upgradeSteps(d)
	return need, coins
end

-- 이번 판에 일할 공정·판 시간·급여 합. 운영비를 뺀 코인으로 공정 순서대로(③ 먼저: 시간이 바뀌므로) 급여를 낼 수 있는 만큼
local function planStaff(d, qty, mode, baseCoins)
	local sec = G.factorySeconds(qty, mode, d.factory.ups)
	local budget = d.coins - baseCoins
	local on, wages = {}, 0
	if hired(d, "press") then
		local s2 = math.floor(sec * STAFF.pressTime + 0.5)
		local w = staffWage(s2)
		if budget >= w then
			on.press = true
			sec = s2
			budget -= w
			wages += w
		end
	end
	for _, st in ipairs(STAFF.stations) do
		local key = st.key
		if key ~= "press" and hired(d, key) then
			local w = staffWage(sec)
			local ok = budget >= w
			if key == "pack" and (d.ingredients.wrapper or 0) < qty then
				ok = false -- 포장지가 없으면 포장 안 함
			end
			if ok then
				on[key] = true
				budget -= w
				wages += w
			end
		end
	end
	return on, sec, wages
end

-- 품질: 생산 방식 범위 + 정밀 품질 제어기, ④ 검사는 Poor 절반, ② 끓이기는 15%로 한 칸 위 (최고 Excellent)
local GRADE_POS = {}
for i, g in ipairs(Config.Grades) do
	GRADE_POS[g.name] = i
end

local function rollQuality(d, mode, st)
	st = st or {}
	local m = F.modes[mode] or F.modes.normal
	local lo, hi = m.qMin, m.qMax
	if (d.factory.ups.precision or 0) > 0 then
		lo = math.min(lo + F.precisionQ, 94)
		hi = math.min(hi + F.precisionQ, 94)
	end
	local q = math.random(lo, hi)
	local grade = nil
	for _, g in ipairs(Config.Grades) do
		if q >= g.min then
			grade = g
			break
		end
	end
	grade = grade or Config.Grades[#Config.Grades]
	if st.inspect and grade.name == "Poor" and math.random() >= STAFF.inspectPoorKeep then
		grade = Config.Grades[GRADE_POS.Normal]
		q = grade.min
	end
	if st.boil and math.random() < STAFF.boilUpChance and grade.name ~= "Excellent" and grade.name ~= "Perfect" then
		local up = Config.Grades[GRADE_POS[grade.name] - 1]
		if up and up.name ~= "Perfect" then
			grade = up
			q = up.min
		end
	end
	return q, grade.name, grade.mult
end

---------------------------------------------------------------- 공장 부지 (D11, 2026-11-22: 가게 건물 뒤에 붙음, 뒷문으로 걸어 들어감)

-- 신호를 담는 곳: workspace.Factories.Factory<i> (Folder, 속성만)
local function buildSignals(i)
	local m = Instance.new("Folder")
	m.Name = "Factory" .. i
	m:SetAttribute("PlotIndex", i)
	m:SetAttribute("OwnerUserId", 0)
	m:SetAttribute("Unlocked", false)
	m.Parent = workspace:WaitForChild("Factories")
	spaces[i] = m
	return m
end

-- 공장 부지 영역: Plot<i>.FactoryLot.Ground (제작 세션), 없으면 설정값. 반환 CFrame(바닥 가운데), 크기
local function lotArea(i)
	local plot = Plots.plotAt(i)
	if not plot then
		return nil
	end
	local lot = plot.model:FindFirstChild("FactoryLot")
	local ground = lot and lot:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then
		return ground.CFrame, ground.Size
	end
	return plot.cframe * CFrame.new(F.lot.pos), F.lot.size
end

-- 내 가게 입구 (골목 쪽)
local function sendHome(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local plot = Plots.get(player)
	if not root then
		return
	end
	if plot then
		local at = plot.cframe * CFrame.new(G.Plots.entry) * CFrame.new(0, G.Plots.size.Y + 3, 0)
		char:PivotTo(CFrame.lookAt(at.Position, at.Position - plot.cframe.LookVector))
	else
		player:LoadCharacter()
	end
end

-- 가게 뒷문 안내 (PlotService.onFactoryDoor, 내 가게일 때만 불림). 열려 있으면 걸어 들어가면 되므로 안내만
function FactoryService.door(player)
	local d = Data.get(player)
	if not d then
		return
	end
	if not d.factory.unlocked then
		Economy.notify(player, string.format("공장은 Lv%d에 %d코인으로 지어요 (연속 생산 설비 필요)", F.level, F.price))
	else
		Economy.notify(player, "뒷문으로 걸어 들어가 제어대에서 생산을 설정해요")
	end
end

-- 남의 공장 부지(또는 아직 안 지은 내 부지)에 들어간 플레이어는 내 가게 앞으로
local function guard()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local _, mine = Plots.get(player)
			for i = 1, G.Plots.count do
				local cf, size = lotArea(i)
				if cf then
					local off = cf:PointToObjectSpace(root.Position)
					if math.abs(off.X) < size.X / 2 and math.abs(off.Z) < size.Z / 2 and off.Y > -5 and off.Y < F.lot.guardHeight then
						local d = Data.get(player)
						if i ~= mine or not (d and d.factory.unlocked) then
							sendHome(player)
							Economy.notify(player, i ~= mine and "다른 사람의 공장이에요" or "공장을 지어야 들어갈 수 있어요")
						end
					end
				end
			end
		end
	end
end

---------------------------------------------------------------- 신호 (Factory<i> 속성)

local function setAttr(inst, name, value)
	if inst:GetAttribute(name) ~= value then
		inst:SetAttribute(name, value)
	end
end

local function publish(player, d)
	local _, i = Plots.get(player)
	local sp = i and spaces[i]
	if not sp then
		return
	end
	local f = d.factory
	local shape = shapeOf(d)
	setAttr(sp, "OwnerUserId", player.UserId)
	setAttr(sp, "Unlocked", f.unlocked == true)
	setAttr(sp, "On", f.on == true)
	setAttr(sp, "Shape", shape and shape.id or "")
	setAttr(sp, "Qty", f.qty)
	setAttr(sp, "Mode", f.mode)
	setAttr(sp, "Lines", lineCount(d))
	setAttr(sp, "Status", status[player] or (f.on and "work" or "off"))
	-- 공정 알바생 (D30): 고용 / 지금 일하는지 (돌고 있는 판에서 급여를 냈는지)
	for _, st in ipairs(STAFF.stations) do
		local working = false
		for k = 1, 2 do
			local job = f.lines[k]
			if job and job.on and job.on[st.key] then
				working = true
			end
		end
		setAttr(sp, "Staff_" .. st.key, hired(d, st.key))
		setAttr(sp, "StaffOn_" .. st.key, working)
	end
	local now = workspace:GetServerTimeNow()
	for k = 1, 2 do
		local job = f.lines[k]
		if job then
			setAttr(sp, "Line" .. k .. "Seconds", job.sec)
			setAttr(sp, "Line" .. k .. "Count", job.n)
			setAttr(sp, "Line" .. k .. "Shape", job.s)
			if (sp:GetAttribute("Line" .. k .. "Start") or 0) == 0 then
				sp:SetAttribute("Line" .. k .. "Start", now - job.t)
			end
		else
			setAttr(sp, "Line" .. k .. "Start", 0)
			setAttr(sp, "Line" .. k .. "Seconds", 0)
			setAttr(sp, "Line" .. k .. "Count", 0)
			setAttr(sp, "Line" .. k .. "Shape", "")
		end
	end
end

local function clearSpace(i)
	local sp = spaces[i]
	if not sp then
		return
	end
	for _, name in ipairs({ "On", "Unlocked" }) do
		sp:SetAttribute(name, false)
	end
	sp:SetAttribute("OwnerUserId", 0)
	sp:SetAttribute("Status", "")
	for k = 1, 2 do
		sp:SetAttribute("Line" .. k .. "Start", 0)
		sp:SetAttribute("Line" .. k .. "Count", 0)
	end
end

---------------------------------------------------------------- 구매·설정 (GrowthService.action 안, Data.update 안에서 부름)

function FactoryService.buy(d)
	if d.factory.unlocked then
		return false, "이미 공장이 있어요"
	end
	if d.shop.state == "stall" then
		return false, "가게를 임대해야 해요"
	end
	if not G.shopOpen(d) then
		return false, "월세를 내야 가게가 열려요"
	end
	if (d.machineStage or 1) < F.needStage then
		return false, "연속 생산 설비가 먼저 있어야 해요"
	end
	if d.level < F.level then
		return false, string.format("공장은 Lv%d부터예요", F.level)
	end
	if d.coins < F.price then
		return false, string.format("%d코인이 필요해요", F.price)
	end
	d.coins -= F.price
	d.factory.unlocked = true
	return true, "달고나 공장 해금! 가게 뒤 문으로 들어가요"
end

function FactoryService.set(d, opts)
	if not d.factory.unlocked then
		return false, "공장이 없어요"
	end
	if type(opts) ~= "table" then
		return false, "잘못된 요청"
	end
	local f = d.factory
	if opts.shape ~= nil then
		local e = ShapeCatalog.get(opts.shape)
		if not e then
			return false, "잘못된 도안"
		end
		if not isUnlocked(d, e.id) then
			return false, "아직 안 열린 도안이에요"
		end
		if e.gradeIndex > MAX_GRADE then
			return false, "공장은 레전더리 도안까지 만들어요"
		end
		f.shape = e.id
	end
	if opts.qty ~= nil then
		local q = math.floor(tonumber(opts.qty) or 0)
		if q < F.baseQty or q > G.factoryMaxQty(f.ups) or q % 10 ~= 0 then
			return false, string.format("수량은 %d~%d개 (10개 단위)", F.baseQty, G.factoryMaxQty(f.ups))
		end
		f.qty = q
	end
	if opts.mode ~= nil then
		if not F.modes[opts.mode] then
			return false, "잘못된 생산 방식"
		end
		f.mode = opts.mode
	end
	local e = shapeOf(d)
	return true, string.format("설정: %s %d개 %s", e and e.name or "-", f.qty, F.modes[f.mode].name)
end

function FactoryService.run(d, on)
	if not d.factory.unlocked then
		return false, "공장이 없어요"
	end
	d.factory.on = on == true
	return true, on and "공장 생산 시작!" or "공장 생산을 멈춰요 (돌던 판은 끝까지)"
end

function FactoryService.upgrade(d, key)
	local u = UP[key]
	if not u then
		return false, "모르는 업그레이드"
	end
	if not d.factory.unlocked then
		return false, "공장이 없어요"
	end
	local cur = d.factory.ups[key] or 0
	local cost = u.costs[cur + 1]
	if not cost then
		return false, u.name .. "은(는) 다 샀어요"
	end
	if d.coins < cost then
		return false, string.format("%d코인이 필요해요", cost)
	end
	d.coins -= cost
	d.factory.ups[key] = cur + 1
	return true, string.format("%s 설치!", u.name)
end

-- 공정 알바생 고용·내보내기 (D30)
local STATION = {}
for _, st in ipairs(STAFF.stations) do
	STATION[st.key] = st
end

-- D43: 공장 화면의 "고용"은 알바생 목록에서 대기 중인 알바생을 그 공정으로 보내고, 없으면 새로 뽑아 보냄
-- (고용비는 몇 번째로 뽑느냐, G.HireCost). "내보내기"는 그 알바생을 대기로 (역할은 성장 창에서 다시 고름)
function FactoryService.hire(d, key)
	local st = STATION[key]
	if not st then
		return false, "모르는 공정"
	end
	if not d.factory.unlocked then
		return false, "공장이 없어요"
	end
	if hired(d, key) then
		return false, st.name .. " 알바생은 이미 있어요"
	end
	for _, h in ipairs(d.partTimers) do
		if h.post == nil then
			h.post = "f_" .. key
			return true, string.format("대기 중이던 알바생 → %s (%s)", st.name, st.desc)
		end
	end
	local n = #d.partTimers
	if n >= G.HelperMax then
		return false, string.format("알바생은 %d명까지예요 (성장 창에서 역할을 바꿔요)", G.HelperMax)
	end
	local cost = G.HireCost[n + 1]
	if d.coins < cost then
		return false, string.format("%d코인이 필요해요", cost)
	end
	d.coins -= cost
	table.insert(d.partTimers, { skill = 0, post = "f_" .. key })
	return true, string.format("%s 알바생 고용! (%s)", st.name, st.desc)
end

function FactoryService.fire(d, key)
	local st = STATION[key]
	local i = st and G.helperAt(d, "f_" .. key)
	if not i then
		return false, "그 공정에 알바생이 없어요"
	end
	d.partTimers[i].post = nil
	return true, st.name .. " 알바생을 대기로 옮겼어요 (성장 창에서 다른 역할로)"
end

-- 바꾼 뒤 (Data.update 밖)
function FactoryService.changed(player)
	local d = Data.get(player)
	if d then
		status[player] = nil
		publish(player, d)
	end
end

---------------------------------------------------------------- 스냅숏

function FactoryService.snapshot(player, d)
	local f = d.factory
	local shape = shapeOf(d)
	local jobs = {}
	for k = 1, lineCount(d) do
		local job = f.lines[k]
		if job then
			table.insert(jobs, { line = k, shape = job.s, count = job.n, mode = job.m, t = math.floor(job.t), seconds = job.sec })
		end
	end
	local ups, list = {}, {}
	for _, u in ipairs(F.upgrades) do
		local lv = f.ups[u.key] or 0
		ups[u.key] = lv
		table.insert(list, { key = u.key, name = u.name, desc = u.desc, level = lv, max = #u.costs, cost = u.costs[lv + 1] })
	end
	local staff = {}
	local previewSec = G.factorySeconds(f.qty, f.mode, f.ups)
	if hired(d, "press") then
		previewSec = math.floor(previewSec * STAFF.pressTime + 0.5)
	end
	for _, st in ipairs(STAFF.stations) do
		local working = false
		for k = 1, 2 do
			local job = f.lines[k]
			if job and job.on and job.on[st.key] then
				working = true
			end
		end
		table.insert(staff, { key = st.key, name = st.name, desc = st.desc, hired = hired(d, st.key), on = working, wage = staffWage(previewSec) })
	end
	local preview = nil
	if shape then
		local need, coins = jobCost(d, shape, f.qty)
		local wages = 0
		for _, st in ipairs(staff) do
			if st.hired then
				wages += st.wage
			end
		end
		preview = { seconds = previewSec, sugar = need.sugar, soda = need.soda, wrapper = need.wrapper, coins = coins + wages, wages = wages }
	end
	return {
		unlocked = f.unlocked == true,
		on = f.on == true,
		shape = shape and shape.id or nil,
		qty = f.qty,
		maxQty = G.factoryMaxQty(f.ups),
		mode = f.mode,
		lines = lineCount(d),
		status = status[player] or (f.on and "work" or "off"),
		jobs = jobs,
		ups = ups,
		upgrades = list,
		shapes = allowedShapes(d),
		preview = preview,
		staff = staff,
		staffHireCost = G.HireCost[#d.partTimers + 1] or STAFF.hireCost, -- D43: 몇 번째로 뽑느냐
		price = F.price,
		level = F.level,
	}
end

---------------------------------------------------------------- 생산 (1초마다)

-- 빈 라인에 새 판: 못 하면 이유
-- 빈 라인 k에 새 판 (데이터만 바꿈). 반환: 못 하면 이유, 하면 nil과 쓴 재료·코인
local function beginJob(dd, k)
	local f = dd.factory
	local shape = shapeOf(dd)
	if not G.shopOpen(dd) then
		return "가게 문 닫힘"
	end
	if not shape then
		return "도안 없음"
	end
	-- 이미 돌고 있는 판과 이번 판이 다 보관함에 들어갈 자리가 있어야 시작
	local pending = 0
	for _, job in pairs(f.lines) do
		if job then
			pending += job.n
		end
	end
	if pending + f.qty > G.stockRoom(dd) then
		return "보관함 가득"
	end
	local _, baseCoins = jobCost(dd, shape, f.qty, {})
	local on, sec, wages = planStaff(dd, f.qty, f.mode, baseCoins)
	local need, coins = jobCost(dd, shape, f.qty, on)
	for _, ing in ipairs(G.Ingredients) do
		if (need[ing.id] or 0) > (dd.ingredients[ing.id] or 0) then
			return "재료 부족: " .. ing.name
		end
	end
	if dd.coins < coins then
		return "코인 부족"
	end
	for id, n in pairs(need) do
		dd.ingredients[id] -= n
	end
	dd.coins -= coins + wages
	dd.stats.factorySpent = (dd.stats.factorySpent or 0) + coins
	dd.stats.staffWages = (dd.stats.staffWages or 0) + wages
	f.lines[k] = { s = shape.id, n = f.qty, m = f.mode, t = 0, sec = sec, pk = on.pack == true, st = { boil = on.boil, inspect = on.inspect }, on = on }
	return nil, need, coins, wages
end

-- 끝난 판 꺼내기 (데이터만 바꿈). 반환: 만든 수, 진열 칸 목록, 레벨업 목록
local function endJob(dd, k, job)
	local f = dd.factory
	f.lines[k] = false
	local shape = ShapeCatalog.get(job.s)
	if not shape then
		return 0, {}, {}
	end
	-- 재료를 이미 냈으니 다 넣음 (시작할 때 자리를 봤지만 그 사이 알바생·기계가 채웠으면 잠깐 넘칠 수 있음)
	local n = job.n
	local packed = job.pk == true -- 판을 시작할 때 포장지를 냈을 때만 (자동 포장)
	local slots = {}
	for _ = 1, n do
		local q, grade, mult = rollQuality(dd, job.m, job.st)
		local item = { s = shape.id, g = grade, q = q, b = shape.price, m = mult, pk = packed, a = true, f = true }
		item.p = G.salePrice(item.b, item.m, G.GachaBonusDefault, packed)
		local sl = Economy.stockProduced(dd, item, "factory")
		if sl then
			table.insert(slots, sl)
		end
	end
	dd.stats.factoryMade = (dd.stats.factoryMade or 0) + n
	local ups = Economy.addExp(dd, G.ExpMachine * n)
	return n, slots, ups
end

local function startJob(player, k)
	local why = nil
	Data.update(player, function(dd)
		why = beginJob(dd, k)
		if why then
			return false
		end
	end)
	return why
end

local function finishJob(player, k, job)
	local made, slots, ups, newShapes = 0, {}, {}, {}
	Data.update(player, function(dd)
		made, slots, ups = endJob(dd, k, job)
		if #ups > 0 and hooks.refreshUnlocks then
			newShapes = hooks.refreshUnlocks(dd)
		end
	end)
	Economy.announceLevels(player, ups)
	if #newShapes > 0 then
		Economy.notify(player, "새 도안: " .. table.concat(newShapes, ", "))
	end
	local _, i = Plots.get(player)
	local sp = i and spaces[i]
	if sp then
		table.sort(slots)
		sp:SetAttribute("Line" .. k .. "Start", 0)
		sp:SetAttribute("MadeCount", made)
		sp:SetAttribute("MadeSlots", table.concat(slots, ","))
		sp:SetAttribute("MadeAt", workspace:GetServerTimeNow())
	end
	print(string.format("[Factory] %s line%d made %d %s (%s) shelf=%s", player.Name, k, made, job.s, job.m, table.concat(slots, ",")))
end

-- 오프라인 정산 (D29): dt초 진행. 반환 = 아직 돌 수 있는가 (가게 문 규칙·한 판 자리 규칙 그대로)
function FactoryService.offlineTick(dd, dt, rep)
	local f = dd.factory
	if not f or not f.unlocked then
		return false
	end
	if not G.shopOpen(dd) then
		rep.stops["공장"] = rep.stops["공장"] or "가게 문 닫힘" -- 처음 멈춘 이유
		return false
	end
	local active = false
	for k = 1, 2 do
		local job = f.lines[k]
		if job then
			active = true
			job.t += dt
			if job.t >= job.sec then
				local n, _, ups = endJob(dd, k, job)
				rep.made.factory += n
				rep.exp += G.ExpMachine * n
				for _, u in ipairs(ups) do
					table.insert(rep.ups, u)
				end
			end
		end
	end
	if f.on then
		for k = 1, lineCount(dd) do
			if not f.lines[k] then
				local why, need, coins, wages = beginJob(dd, k)
				if why then
					rep.stops["공장"] = rep.stops["공장"] or why
				else
					active = true
					for id, n in pairs(need) do
						rep.used[id] = (rep.used[id] or 0) + n
					end
					rep.factoryCoins += coins
					rep.wages += wages -- 공정 알바생 급여 (D30)
				end
			end
		end
	end
	return active
end

local function step(player, dt)
	local d = Data.get(player)
	if not d or not d.factory or not d.factory.unlocked then
		return
	end
	local f = d.factory
	local before = status[player]
	-- 돌고 있는 판 진행 (가게 문이 닫히면 멈춤)
	local open = G.shopOpen(d)
	for k = 1, 2 do
		local job = f.lines[k]
		if job and open then
			job.t += dt
			if job.t >= job.sec then
				finishJob(player, k, job)
			end
		end
	end
	-- 빈 라인에 새 판
	local why = nil
	if not open then
		why = "가게 문 닫힘"
	elseif f.on then
		for k = 1, lineCount(d) do
			if not Data.get(player).factory.lines[k] then
				why = startJob(player, k) or why
			end
		end
	end
	status[player] = why or (f.on and "work" or "off")
	publish(player, Data.get(player))
	if before ~= status[player] then
		Economy.push(player)
	end
end

function FactoryService.init(dataService, economyService, plotService, growthHooks)
	Data, Economy, Plots, hooks = dataService, economyService, plotService, growthHooks or {}
	local folder = Instance.new("Folder")
	folder.Name = "Factories"
	folder.Parent = workspace
	for i = 1, G.Plots.count do
		buildSignals(i)
	end
	Plots.onFactoryDoor = FactoryService.door
	Data.Changed:Connect(function(player)
		local d = Data.get(player)
		if d and d.factory then
			publish(player, d)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		status[p] = nil
		for i, sp in pairs(spaces) do
			if sp:GetAttribute("OwnerUserId") == p.UserId then
				clearSpace(i)
			end
		end
	end)
	task.spawn(function()
		while true do
			local dt = task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(step, player, dt)
				if not ok then
					warn("[Factory] step failed", player.Name, err)
				end
			end
			pcall(guard)
		end
	end)
end

return FactoryService

-- 성장 (Phase 4, 2026-11-20): 도안 해금 · 도감 · 장비 업그레이드 · 국자 · 알바생 · 일일 목표
-- 수치는 GrowthConfig. 기준: GAME_DESIGN_DOCUMENT 3·6장, SHOP_GROWTH_PLAN 2·9장, SYSTEMS_SPECIFICATION 6·7장.
--  - 도안: 레벨로 등급별 해금 (G.UnlockLevel). Master는 도감 조건 (G.MasterUnlock, D6)
--  - 도감: 손으로 만든 것만 도안별 최고 등급·개수 (자동 생산은 안 셈)
--  - 장비: 화로·누르개·작업대 (Lv2부터). 효과는 ProductionService.hooks.mods + G.stockMax
--  - 알바생 배치 (D34, 2026-11-24): 최대 4명 (고용 G.HireCost), 제작대(화로·2·3·4단계 기계)마다 한 명, 언제든 공짜로 옮김.
--    화로 알바: 40초에 1개 (Normal~Good), 재료는 안 쓰고 다 만들 때 급여(30초당 3). 화구 ②에서 일해서 내가 화구 ①로 손 제작해도 안 쉼
--    (2026-11-24 화구 2개 기본). 기계 알바: 그 기계가 돌게 함 (급여는 MachineService가 한 판마다)
--  - D43 (2026-11-24): 역할 = 제작대 4 + 진열(보관함 → 진열대, 4초에 1개) + 계산(수요 +10%·팁 +5%, SalesService·Economy가 봄)
--    + 공장 공정 5 (FactoryService가 hired로 봄, 미니미는 FactoryDisplay). 최대 11명, 고용비는 몇 번째로 뽑느냐
--  - 화로 알바 교육 (D39·D40): 국자 확장 대신 숙련 교육(Lv3)·연탄 덮개(Lv5, 2026-11-24 두 번째 화구에서 바뀜)·전문 교육(Lv8)
--  - 일일 목표 3개: UTC 날짜마다 새로 뽑음, 다 하면 EXP 15 + 코인

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("GrowthConfig"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local Config = require(Shared:WaitForChild("DalgonaConfig"))
local Minime = require(script.Parent:WaitForChild("Minime"))
local Machine = require(script.Parent:WaitForChild("MachineService")) -- 기계 2~4단계 (20번)
local Factory = require(script.Parent:WaitForChild("FactoryService")) -- 5단계 공장
local Offline = require(script.Parent:WaitForChild("OfflineService")) -- 오프라인 생산 정산 (D29)
local Tutorial = require(script.Parent:WaitForChild("TutorialService")) -- 첫 60초 안내 (21번)
local Production = require(script.Parent:WaitForChild("ProductionService")) -- 손으로 만드는 중인가 (D34)
local Collection = require(script.Parent:WaitForChild("CollectionService")) -- 도감 보상·칭호 (D38)
local WorkstationBuilder = require(script.Parent:WaitForChild("WorkstationBuilder")) -- 화로 연탄 모습 (D44)
local HelperPath = require(script.Parent:WaitForChild("HelperPath")) -- 알바생이 벽을 돌아 걷는 길 (2026-11-24)

local GrowthService = {}

local Data, Economy, Plots = nil, nil, nil
local helperState = {} -- [player] = { [i] = { t = 진행 초, status = "work" | 이유, model } }
local lastAction = {} -- [player] = os.clock()

local GRADE_INDEX = {}
for i, g in ipairs(ShapeCatalog.Grades) do
	GRADE_INDEX[g.id] = i
end
local HELPER_MAX_GRADE = GRADE_INDEX[G.Helper.maxGrade]

---------------------------------------------------------------- 도안 해금

local function isUnlocked(d, id)
	return table.find(d.unlockedShapes, id) ~= nil
end

local function mythicCounts(d)
	local exc, perf = 0, 0
	for _, e in ipairs(ShapeCatalog.list) do
		if e.grade == "Mythic" then
			local c = d.collection[e.id]
			local r = c and G.GradeRank[c.best] or 0
			if r >= G.GradeRank.Excellent then
				exc += 1
			end
			if r >= G.GradeRank.Perfect then
				perf += 1
			end
		end
	end
	return exc, perf
end

-- 레벨·도감으로 열릴 도안을 더함. 반환: 새로 열린 도안 이름 목록
local function refreshUnlocks(d)
	local new = {}
	for _, e in ipairs(ShapeCatalog.list) do
		local need = G.UnlockLevel[e.grade]
		if need and d.level >= need and not isUnlocked(d, e.id) then
			table.insert(d.unlockedShapes, e.id)
			table.insert(new, e.name)
		end
	end
	local exc, perf = mythicCounts(d)
	for _, m in ipairs(G.MasterUnlock) do
		local ok = (m.mythicExcellent and exc >= m.mythicExcellent) or (m.mythicPerfect and perf >= m.mythicPerfect)
		if ok and not isUnlocked(d, m.id) and ShapeCatalog.get(m.id) then
			table.insert(d.unlockedShapes, m.id)
			table.insert(new, ShapeCatalog.get(m.id).name)
		end
	end
	return new
end

local function nextUnlockLevel(level)
	local best = nil
	for _, lv in pairs(G.UnlockLevel) do
		if lv > level and (not best or lv < best) then
			best = lv
		end
	end
	return best
end

---------------------------------------------------------------- 일일 목표

local function today()
	return os.date("!%Y%m%d")
end

local function rollDaily(d)
	local day = today()
	if d.daily.day == day and #d.daily.goals > 0 then
		return false
	end
	local pool = table.clone(G.Daily.pool)
	local goals, usedKinds = {}, {}
	local rng = Random.new()
	while #goals < G.Daily.count and #pool > 0 do
		local i = rng:NextInteger(1, #pool)
		local g = table.remove(pool, i)
		if not usedKinds[g.kind] then
			usedKinds[g.kind] = true
			table.insert(goals, { kind = g.kind, n = g.n, text = string.format(g.text, g.n), p = 0, done = false })
		end
	end
	d.daily = { day = day, goals = goals }
	return true
end

-- 목표 진행. 반환: 이번에 끝난 목표 글 목록 (보상은 d에 바로 넣음)
local function progressDaily(d, kind, amount)
	rollDaily(d)
	local finished, ups = {}, {}
	for _, g in ipairs(d.daily.goals) do
		if g.kind == kind and not g.done then
			g.p = math.min(g.n, g.p + amount)
			if g.p >= g.n then
				g.done = true
				d.coins += G.Daily.rewardCoins
				local u = Economy.addExp(d, G.ExpDailyGoal)
				for _, lv in ipairs(u) do
					table.insert(ups, lv)
				end
				table.insert(finished, g.text)
			end
		end
	end
	return finished, ups
end

local function dailyEvent(player, kind, amount)
	local finished, ups = {}, {}
	local newShapes = {}
	Data.update(player, function(d)
		finished, ups = progressDaily(d, kind, amount)
		if #ups > 0 then
			newShapes = refreshUnlocks(d)
		end
	end)
	for _, text in ipairs(finished) do
		Economy.notify(player, string.format("일일 목표 완료! %s (+%d EXP, +%d 코인)", text, G.ExpDailyGoal, G.Daily.rewardCoins))
	end
	Economy.announceLevels(player, ups)
	if #newShapes > 0 then
		Economy.notify(player, "새 도안: " .. table.concat(newShapes, ", "))
	end
end

---------------------------------------------------------------- 장비·국자·알바생 구매

local function upgradeLevel(d, kind)
	return (d.upgrades[kind] or 0) + 1
end

local function cheapestHelperShape(d)
	for _, e in ipairs(ShapeCatalog.list) do
		if e.gradeIndex <= HELPER_MAX_GRADE and isUnlocked(d, e.id) then
			return e.id
		end
	end
	return ShapeCatalog.list[1].id
end

local function stallLockReason(d)
	if d.shop.state == "stall" then
		return string.format("가게를 임대해야 해요 (Lv%d, 보증금 %d)", G.Shop.rentLevel, G.Shop.deposit)
	end
	return "월세를 내야 가게가 열려요"
end

local function actionBuy(player, d, kind)
	-- 노점이거나 월세가 밀려 문이 닫히면 국자·알바생·작업대 업그레이드는 안 됨 (D21)
	if G.Shop.lockedWhenStall[kind] and not G.shopOpen(d) then
		return false, stallLockReason(d)
	end
	if kind == "rent" then
		if d.shop.state ~= "stall" then
			return false, "이미 가게가 있어요"
		end
		if d.level < G.Shop.rentLevel then
			return false, string.format("Lv%d부터 임대할 수 있어요", G.Shop.rentLevel)
		end
		if d.coins < G.Shop.deposit then
			return false, string.format("보증금 %d코인이 필요해요", G.Shop.deposit)
		end
		d.coins -= G.Shop.deposit
		d.shop = { state = "rented", rentTimer = 0, closed = false }
		return true, string.format("가게를 임대했어요! 월세는 접속 %d분마다 %d코인", G.Shop.rentEvery // 60, G.Shop.rentAmount)
	elseif kind == "buyShop" then
		if d.shop.state ~= "rented" then
			return false, d.shop.state == "owned" and "이미 내 가게예요" or "먼저 가게를 임대해요"
		end
		if d.level < G.Shop.buyLevel then
			return false, string.format("Lv%d부터 살 수 있어요", G.Shop.buyLevel)
		end
		local price = G.Shop.buyPrice - G.Shop.deposit
		if d.coins < price then
			return false, string.format("%d코인이 필요해요 (보증금 빼고)", price)
		end
		d.coins -= price
		d.shop = { state = "owned", rentTimer = 0, closed = false }
		return true, "가게를 샀어요! 이제 월세가 없어요"
	end
	local up = G.Upgrades[kind]
	if up then
		if d.level < G.UpgradeUnlockLevel then
			return false, string.format("Lv%d부터 살 수 있어요", G.UpgradeUnlockLevel)
		end
		local cur = d.upgrades[kind] or 0
		local cost = up.costs[cur + 1]
		if not cost then
			return false, up.name .. "은(는) 최고 단계예요"
		end
		if d.coins < cost then
			return false, "코인이 모자라요"
		end
		d.coins -= cost
		d.upgrades[kind] = cur + 1
		return true, string.format("%s Lv%d!", up.name, cur + 2)
	elseif kind == "machine" then
		return Machine.buy(d)
	elseif kind == "factory" then
		return Factory.buy(d)
	elseif kind == "hire" then
		local n = #d.partTimers
		if n >= G.HelperMax then
			return false, string.format("알바생은 %d명까지예요", G.HelperMax)
		end
		local cost = G.HireCost[n + 1]
		if d.coins < cost then
			return false, string.format("%d코인이 필요해요", cost)
		end
		d.coins -= cost
		-- 빈 제작대가 있으면 바로 그 자리 (화로 → 기계 순)
		local post = nil
		for _, p in ipairs(G.HelperPosts) do
			if G.hasPost(d, p.key) and not G.helperAt(d, p.key) then
				post = p.key
				break
			end
		end
		table.insert(d.partTimers, { shape = cheapestHelperShape(d), skill = 0, post = post })
		local where = post and G.helperPost(post).name or "대기 (열린 빈 역할 없음)"
		return true, string.format("알바생 %d번 고용! → %s", n + 1, where)
	end
	return false, "모르는 항목"
end

-- 화로 알바 교육 (D40)
local function actionTrain(d, key)
	local spec = nil
	for _, t in ipairs(G.StoveTraining) do
		if t.key == key then
			spec = t
		end
	end
	if not spec then
		return false, "잘못된 요청"
	end
	if not G.shopOpen(d) then
		return false, stallLockReason(d)
	end
	d.stoveUps = d.stoveUps or {}
	if d.stoveUps[key] then
		return false, "이미 배웠어요"
	end
	if d.level < spec.level then
		return false, string.format("Lv%d부터 살 수 있어요", spec.level)
	end
	if d.coins < spec.cost then
		return false, string.format("%d코인이 필요해요", spec.cost)
	end
	d.coins -= spec.cost
	d.stoveUps[key] = true
	return true, string.format("%s! %s", spec.name, spec.text)
end

-- 알바생 index를 제작대 key로 (""면 대기). 그 자리에 다른 알바생이 있으면 서로 바꿈 (D34: 언제든 공짜로)
local function actionSetPost(d, index, key)
	local h = d.partTimers[index]
	if not h then
		return false, "잘못된 요청"
	end
	if key == "" then
		h.post = nil
		return true, string.format("알바생 %d번: 대기", index)
	end
	local p = G.helperPost(key)
	if not p then
		return false, "잘못된 요청"
	end
	if not G.hasPost(d, key) then
		return false, p.name .. " 역할은 아직 안 열렸어요"
	end
	if h.post == key then
		return true, string.format("알바생 %d번: %s", index, p.name)
	end
	local other = G.helperAt(d, key)
	if other then
		d.partTimers[other].post = h.post -- 자리 바꾸기
	end
	h.post = key
	return true, string.format("알바생 %d번 → %s", index, p.name)
end

local function actionSetShape(d, index, shapeId)
	local h = d.partTimers[index]
	local e = ShapeCatalog.get(shapeId)
	if not h or not e then
		return false, "잘못된 요청"
	end
	if not isUnlocked(d, e.id) then
		return false, "아직 안 열린 도안이에요"
	end
	if e.gradeIndex > HELPER_MAX_GRADE then
		return false, "알바생은 레전더리 도안까지 만들어요"
	end
	h.shape = e.id
	return true, string.format("알바생 %d번: %s", index, e.name)
end

function GrowthService.action(player, what, a, b)
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 0.25 then
		return { ok = false, reason = "천천히!" }
	end
	lastAction[player] = now
	if type(what) ~= "string" then
		return { ok = false, reason = "잘못된 요청" }
	end
	local d = Data.get(player)
	if not d then
		return { ok = false, reason = "불러오는 중이에요" }
	end
	-- 공장 공정 내가 직접 (D45): 위치·세션을 봐야 해서 Data.update 밖에서
	if what == "factorySelf" and type(a) == "string" then
		local ok2, msg2 = Factory.selfStart(player, a)
		return { ok = ok2, reason = not ok2 and msg2 or nil, msg = ok2 and msg2 or nil }
	end
	local ok, msg = false, "잘못된 요청"
	Data.update(player, function(dd)
		if what == "buy" and type(a) == "string" then
			ok, msg = actionBuy(player, dd, a)
		elseif what == "displayHand" and type(a) == "boolean" then
			dd.displayHand = a
			ok, msg = true, a and "진열 알바가 손으로 만든 것도 옮겨요" or "손으로 만든 것은 직접 놓아요"
		elseif what == "train" and type(a) == "string" then
			ok, msg = actionTrain(dd, a)
		elseif what == "factorySkill" and type(a) == "string" then
			ok, msg = Factory.buySkill(dd, a) -- 공장 손재주 한 단계 (D49, 공정 key)
		elseif what == "helperPost" and type(a) == "number" and type(b) == "string" then
			ok, msg = actionSetPost(dd, math.floor(a), b)
		elseif what == "helperShape" and type(a) == "number" and type(b) == "string" then
			ok, msg = actionSetShape(dd, math.floor(a), b)
		elseif what == "machineShape" and type(a) == "string" then
			ok, msg = Machine.setShape(dd, a, type(b) == "number" and b or nil) -- b = 기계 단계 (D32, 없으면 가장 높은 단계)
		elseif what == "factorySet" and type(a) == "table" then
			ok, msg = Factory.set(dd, a)
		elseif what == "factoryRun" then
			ok, msg = Factory.run(dd, a == true)
		elseif what == "factoryUp" and type(a) == "string" then
			ok, msg = Factory.upgrade(dd, a)
		elseif what == "factoryHire" and type(a) == "string" then
			ok, msg = Factory.hire(dd, a) -- 공장 공정 알바생 (D30)
		elseif what == "factoryFire" and type(a) == "string" then
			ok, msg = Factory.fire(dd, a)
		end
		if not ok then
			return false
		end
	end)
	if ok and what == "helperShape" and helperState[player] then
		for _, st in pairs(helperState[player]) do
			st.t = 0 -- 도안을 바꾸면 그 판은 처음부터
		end
	end
	if ok and (what == "machineShape" or a == "machine" or what == "helperPost" or a == "hire") then
		Machine.changed(player)
	end
	if ok and (a == "factory" or string.sub(what, 1, 7) == "factory" or what == "helperPost" or a == "hire") then
		Factory.changed(player)
	end
	return { ok = ok, reason = not ok and msg or nil, msg = ok and msg or nil }
end

---------------------------------------------------------------- 알바생 생산

-- 화로 옆 자리 k (1 = 화로 알바, 국자 HelperLadle2와 짝). 그 부지 작업대의 화로 뒤쪽 (손님·주인 쪽 +Z를 봄)
local function stoveFoot(plot, k)
	local ws = plot.model:FindFirstChild("Workstation")
	local brazier = ws and ws:FindFirstChild("Brazier")
	local top = ws and ws:FindFirstChild("TableTop")
	local y = G.Plots.size.Y
	if brazier and top then
		-- 가게 기준(로컬 -Z = 앞·손님 쪽)으로 계산 (2026-11-23 마주 보는 두 줄: 북쪽 줄은 월드 방향이 반대)
		local lb = plot.cframe:PointToObjectSpace(brazier:GetPivot().Position)
		local lt = plot.cframe:PointToObjectSpace(top.Position)
		local z = lt.Z + top.Size.Z / 2 + G.Plots.minimeBehind
		local x = lb.X - (k - 2) * G.Plots.minimeGap
		return plot.cframe * CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z - 1))
	end
	local spot = G.Plots.handStation.pos
	return plot.cframe * CFrame.new(spot.X - 8 + (k - 1) * 5, y, spot.Z - 2.5)
end

-- 알바생이 설 자리 (D34): 화로 알바는 화로 옆, 기계 알바는 그 기계 옆, 대기는 화로 옆 빈자리.
-- 기계 옆 자리는 가게 틀(PlotLayout)에 HelperSpot<단계> 부품을 넣으면 그 자리 (없으면 기계 자리 오른쪽)
local function helperFoot(plot, post, i)
	local p = post and G.helperPost(post)
	if p and (p.stage or 0) >= 2 then
		local y = G.Plots.size.Y
		local mark = plot.model:FindFirstChild("HelperSpot" .. p.stage, true)
		if mark and mark:IsA("BasePart") then
			local l = plot.cframe:ToObjectSpace(mark.CFrame)
			local look = l.LookVector
			local pos = Vector3.new(l.X, y, l.Z)
			return plot.cframe * CFrame.lookAt(pos, pos + Vector3.new(look.X, 0, look.Z))
		end
		local slot = plot.model:FindFirstChild("MachineSlot" .. p.stage)
		if slot and slot:IsA("BasePart") then
			local l = plot.cframe:ToObjectSpace(slot.CFrame)
			local side = l * Vector3.new(slot.Size.X / 2 + 1.2, 0, 0)
			local pos = Vector3.new(side.X, y, side.Z)
			local c = Vector3.new(l.X, y, l.Z)
			return plot.cframe * CFrame.lookAt(pos, c)
		end
	end
	if p and (p.kind == "display" or p.kind == "cashier") then
		-- 진열 = 유리 진열장 뒤, 계산 = 앞 카운터 뒤 (가게 안쪽 +Z에서 앞 -Z를 봄). 틀에 HelperSpotDisplay·HelperSpotCashier를 넣으면 그 자리
		local y = G.Plots.size.Y
		local mark = plot.model:FindFirstChild(p.kind == "display" and "HelperSpotDisplay" or "HelperSpotCashier", true)
		if mark and mark:IsA("BasePart") then
			local l = plot.cframe:ToObjectSpace(mark.CFrame)
			local look = l.LookVector
			local pos = Vector3.new(l.X, y, l.Z)
			return plot.cframe * CFrame.lookAt(pos, pos + Vector3.new(look.X, 0, look.Z))
		end
		local function box(role)
			for _, part in ipairs(plot.model:GetDescendants()) do
				if part:IsA("BasePart") and part:GetAttribute("Role") == role then
					local l = plot.cframe:ToObjectSpace(part.CFrame)
					local sz = part.Size
					local hx = (math.abs(l.RightVector.X) * sz.X + math.abs(l.UpVector.X) * sz.Y + math.abs(l.LookVector.X) * sz.Z) / 2
					local hz = (math.abs(l.RightVector.Z) * sz.X + math.abs(l.UpVector.Z) * sz.Y + math.abs(l.LookVector.Z) * sz.Z) / 2
					return l.Position, hx, hz
				end
			end
			return nil
		end
		local case, _, caseZ = box("유리 진열장")
		local counter, counterX, counterZ = box("앞 카운터 (나무)")
		local pos = nil
		if p.kind == "display" and case then
			pos = Vector3.new(case.X, y, case.Z + caseZ + 1.3) -- 유리 진열장 뒤
		elseif p.kind == "cashier" and counter then
			-- 앞 카운터 뒤, 유리 진열장이 없는 쪽 끝 (진열 알바와 안 겹치게, 2026-11-24)
			local x = counter.X
			if case then
				local side = case.X > counter.X and -1 or 1
				x = counter.X + side * math.max(0, counterX - 2.5)
			end
			pos = Vector3.new(x, y, counter.Z + counterZ + 1.3)
		end
		if pos then
			return plot.cframe * CFrame.lookAt(pos, pos - Vector3.zAxis)
		end
	end
	if post == "stove" then
		-- 화구 ② 옆 (2026-11-24 화구 2개 기본): 화구 ② 뒤쪽(주인 쪽)에 서서 화구를 봄
		local ws = plot.model:FindFirstChild("Workstation")
		local b2 = ws and ws:FindFirstChild("Brazier2")
		if b2 then
			local l = plot.cframe:PointToObjectSpace(b2:GetPivot().Position)
			local pos = Vector3.new(l.X, G.Plots.size.Y, l.Z + G.Plots.minimeBehind + 1)
			return plot.cframe * CFrame.lookAt(pos, Vector3.new(l.X, G.Plots.size.Y, l.Z))
		end
		return stoveFoot(plot, 1)
	end
	return stoveFoot(plot, 1 + i) -- 대기
end

-- 모델 이름: 화로 알바 = Helper1 (클라이언트 HelperLadles가 국자 2와 짝짓는 이름), 나머지 = Helper_<자리>
local function helperName(post, i)
	if post == "stove" then
		return "Helper1"
	end
	return "Helper_" .. (post or ("idle" .. i))
end

-- 미니미를 못 만들 때 쓰는 부품 인형
local function helperModel(player, plot, i, cf)
	local m = Instance.new("Model")
	m.Name = "Helper" .. i
	local function p(name, size, off, color, shape)
		local x = Instance.new("Part")
		x.Name = name
		x.Anchored = true
		x.CanCollide = false
		x.CanQuery = false
		x.Size = size
		x.CFrame = cf * off
		x.Color = color
		x.Material = Enum.Material.SmoothPlastic
		if shape then
			x.Shape = shape
		end
		x.Parent = m
		return x
	end
	p("Legs", Vector3.new(0.9, 1.1, 0.5), CFrame.new(0, 0.55, 0), Color3.fromRGB(70, 70, 90))
	p("Body", Vector3.new(1.3, 1.3, 0.8), CFrame.new(0, 1.75, 0), Color3.fromRGB(255, 255, 255))
	p("Apron", Vector3.new(1.0, 1.0, 0.1), CFrame.new(0, 1.6, -0.42), Color3.fromRGB(255, 140, 160))
	local head = p("Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 3.05, 0), Color3.fromRGB(255, 220, 190), Enum.PartType.Ball)
	p("Cap", Vector3.new(1.4, 0.4, 1.4), CFrame.new(0, 3.6, 0), Color3.fromRGB(255, 140, 160))
	p("EyeL", Vector3.new(0.14, 0.2, 0.06), CFrame.new(-0.24, 3.12, -0.63), Color3.fromRGB(30, 25, 25))
	p("EyeR", Vector3.new(0.14, 0.2, 0.06), CFrame.new(0.24, 3.12, -0.63), Color3.fromRGB(30, 25, 25))
	local bb = Instance.new("BillboardGui")
	bb.Name = "Status"
	bb.Size = UDim2.fromOffset(170, 44)
	bb.StudsOffset = Vector3.new(0, 1.7, 0)
	bb.MaxDistance = 70
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(255, 252, 245)
	t.BackgroundTransparency = 0.1
	t.TextColor3 = Color3.fromRGB(92, 58, 36)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.3, 0)
	c.Parent = t
	t.Parent = bb
	bb.Parent = head
	m.PrimaryPart = head
	m.Parent = plot.model
	return m
end

-- 제작 세션 연출 약속 (D34): 미니미 속성 StationKey = "hand" | "m2" | "m3" | "m4" (맡은 제작대, 대기면 없음), Working = 일하는 중
local STATION_KEY = { stove = "hand", steel = "m2", pink = "m3", line = "m4", display = "display", cashier = "cashier" }

local function setWorking(st)
	local m = st.model
	if m and m.Parent then
		local w = st.status == "work"
		if m:GetAttribute("Working") ~= w then
			m:SetAttribute("Working", w)
		end
	end
end

local function setHelperText(st, text)
	setWorking(st)
	local head = st.model and st.model:FindFirstChild("Head")
	local bb = head and head:FindFirstChild("Status")
	if bb and bb.TextLabel.Text ~= text then
		bb.TextLabel.Text = text
	end
end

local function rollHelperQuality(qMin, qMax)
	local q = math.random(qMin or G.Helper.qMin, qMax or G.Helper.qMax)
	for _, g in ipairs(Config.Grades) do
		if q >= g.min then
			return q, g.name, g.mult
		end
	end
	return q, "Normal", 0.8
end

-- 알바생 1명 1초 진행 (D34: 배치한 제작대에 따라)
-- 화로 알바 연탄 (D44): 두 번째 화구(D40)가 있으면 그 화구 연탄(coalLeft2), 없으면 내 화로 연탄(coalLeft)을 같이 씀
local function helperCoalKey(d)
	return "coalLeft2" -- 화로 알바는 화구 ② (2026-11-24: 화구 2개 기본, ①은 내 손 작업대)
end

-- 지금 화구에 연탄이 있거나 갈아 넣을 연탄이 있나
local function helperCoalReady(d)
	return (tonumber(d[helperCoalKey(d)]) or 1) > 0.001 or (d.ingredients.coal or 0) >= 1
end

-- 한 판 끝: 다 탔으면 보관 연탄 1장을 갈아 넣고 한 판만큼 태움 (Data.update 안에서)
local function helperBurnCoal(dd)
	local key = helperCoalKey(dd)
	if (tonumber(dd[key]) or 1) <= 0.001 and (dd.ingredients.coal or 0) >= 1 then
		dd.ingredients.coal -= 1
		dd[key] = 1
	end
	dd[key] = math.max(0, (tonumber(dd[key]) or 1) - G.coalPerMake(dd))
end

-- 진열 알바 (D33): 옮길 달고나 하나 고르기 (먼저 만든 것부터, 손 제작품 켜면 손 제작품 먼저, 들고 있는 것은 빼고)
local function displayPick(player, d)
	local maxSlots = G.shelfSlots(d)
	local used = {}
	for _, it in ipairs(d.stock) do
		if it.sl then
			used[it.sl] = true
		end
	end
	local slot = nil
	for k = 1, maxSlots do
		if not used[k] and not Economy.isReserved(d, k) then
			slot = k
			break
		end
	end
	if not slot then
		return nil, nil, "진열대 가득"
	end
	local carrying = player:GetAttribute("Carrying")
	local hand, auto = nil, nil
	for _, it in ipairs(d.stock) do
		if not it.sl and it.id ~= carrying then
			if it.a then
				auto = auto or it
			elseif d.displayHand ~= false then
				hand = hand or it
			end
		end
	end
	local item = hand or auto
	if not item then
		return nil, nil, "옮길 것 없음"
	end
	return item, slot, nil
end

-- 급여를 일한 시간만큼 쌓다가 1코인 이상이면 냄 (진열·계산 알바: 30초당 p.wage)
local function payWage(player, st, p, sec)
	st.owed = (st.owed or 0) + sec / 30 * p.wage
	if st.owed >= p.wage then
		local pay = math.floor(st.owed)
		st.owed -= pay
		Data.update(player, function(dd)
			dd.coins -= pay
			dd.stats.wagesPaid = (dd.stats.wagesPaid or 0) + pay
		end)
	end
end

local Sales = nil -- SalesService (칸 자리), 처음 쓸 때 가져옴

-- 미니미가 그 칸으로 들고 가는 연출 신호 (클라 HelperLadles): 벽을 돌아가는 길(WalkPath)을 먼저 찾고 DeliverSlot·DeliverAt
local function signalDeliver(player, m, slot)
	task.spawn(function()
		Sales = Sales or require(script.Parent:WaitForChild("SalesService"))
		local from = m:GetPivot().Position
		local to = Sales.slotPosition(player, slot)
		local path = to and HelperPath.wait(from, to) or false
		if not m.Parent then
			return
		end
		m:SetAttribute("WalkPath", path or "")
		m:SetAttribute("DeliverSlot", slot)
		m:SetAttribute("DeliverAt", workspace:GetServerTimeNow())
	end)
end

local function stepRole(player, d, i, h, st, dt, p)
	if p.kind == "factory" then
		st.status = "work" -- 공장 공정 (FactoryService가 일·급여를 셈, 미니미는 FactoryDisplay)
		return
	end
	if not G.shopOpen(d) then
		st.status = "가게 문 닫힘"
		setHelperText(st, string.format("알바생 %d · 쉬는 중 (가게 문 닫힘)", i))
		return
	end
	if d.coins < p.wage then
		st.status = "급여 부족"
		setHelperText(st, string.format("알바생 %d · 쉬는 중 (급여 부족)", i))
		return
	end
	if p.kind == "cashier" then
		st.status = "work"
		setHelperText(st, string.format("알바생 %d · 계산", i))
		payWage(player, st, p, dt)
		return
	end
	-- 진열
	local item, _, why = displayPick(player, d)
	if not item then
		st.status = why
		st.t = 0
		setHelperText(st, string.format("알바생 %d · 쉬는 중 (%s)", i, why))
		return
	end
	st.status = "work"
	st.t += dt
	setHelperText(st, string.format("알바생 %d · 진열 중", i))
	if st.t < G.DisplayHelper.seconds then
		return
	end
	st.t = 0
	local placed = nil
	Data.update(player, function(dd)
		local it, slot = displayPick(player, dd)
		if not it then
			return false
		end
		it.sl = slot
		it.pp = nil
		placed = slot
	end)
	if placed then
		payWage(player, st, p, G.DisplayHelper.seconds)
		if st.model and st.model.Parent then
			signalDeliver(player, st.model, placed)
		end
	end
end

-- 들고 가서 진열 (2026-11-24, G.CarryHelpers): 4단계 기계 알바·공장 포장 알바가 그 기계·공장이 만든 달고나(item.src)를 하나씩
-- 들고 빈 진열 칸으로 걸어가 놓음. 걷는 동안 칸 예약 (Economy.reserveSlot). 연출 신호 = 그 알바 미니미 속성
--   CarryState("go" | "back" | ""), CarryShape(도안 id), CarrySlot(칸), CarryFrom·CarryTo(Vector3), CarryStart(서버 시각), CarryDur(초)
local function carryModel(player, h, st)
	if h.post == "f_pack" then
		local plot = Plots.get(player)
		local lot = plot and plot.model:FindFirstChild("FactoryLot", true)
		local folder = lot and lot:FindFirstChild("Staff")
		return folder and folder:FindFirstChild("Staff_pack")
	end
	return st.model
end

local function setCarry(m, state, info)
	if not (m and m.Parent) then
		return
	end
	m:SetAttribute("CarryState", state)
	if info then
		m:SetAttribute("CarryShape", info.shape)
		m:SetAttribute("CarrySlot", info.slot)
		m:SetAttribute("CarryFrom", info.from)
		m:SetAttribute("CarryTo", info.to)
		m:SetAttribute("CarryStart", workspace:GetServerTimeNow())
		m:SetAttribute("CarryDur", info.dur)
		m:SetAttribute("WalkPath", info.path or "") -- 처음 자리 → 칸 앞 경유점 (shared/WalkPath), 없으면 곧게
	end
end

local function stepCarry(player, d, h, st, dt)
	local CH = G.CarryHelpers
	local src = h.post and CH.posts[h.post]
	local c = st.carry
	if not src then
		if c then
			Economy.releaseSlot(d, c.slot)
			st.carry = nil
		end
		return
	end
	local m = carryModel(player, h, st)
	if c then
		c.t += dt
		if c.t < c.dur then
			return
		end
		if c.phase == "go" then
			-- 도착: 그 달고나가 아직 보관함에 있고 칸이 비어 있으면 놓음
			local placed = false
			Data.update(player, function(dd)
				local item = nil
				local used = false
				for _, it in ipairs(dd.stock) do
					if it.id == c.id then
						item = it
					end
					if it.sl == c.slot then
						used = true
					end
				end
				if not item or item.sl or used then
					return false
				end
				item.sl = c.slot
				item.pp = nil
				placed = true
			end)
			Economy.releaseSlot(Data.get(player) or d, c.slot)
			c.phase, c.t = "back", 0
			setCarry(m, "back", { shape = placed and "" or c.shape, slot = c.slot, from = c.to, to = c.from, dur = c.dur, path = c.path }) -- 길은 가던 길 그대로 (클라가 거꾸로 걸음)
		else
			st.carry = nil
			setCarry(m, "", nil)
		end
		return
	end
	if not G.shopOpen(d) or not (m and m.Parent) then
		return
	end
	-- 새로 하나 집기
	local carrying = player:GetAttribute("Carrying")
	local item = nil
	for _, it in ipairs(d.stock) do
		-- 옛 공장 달고나(src 없음, f = true)도 포장 알바가 옮김 (2026-11-24 묶음 시험)
		local mine = it.src == src or (src == "factory" and it.src == nil and it.f == true)
		if not it.sl and mine and it.id ~= carrying then
			item = it
			break
		end
	end
	if not item then
		return
	end
	local slot = Economy.reserveSlot(d)
	if not slot then
		return
	end
	Sales = Sales or require(script.Parent:WaitForChild("SalesService"))
	local from = m:GetPivot().Position
	local to = Sales.slotPosition(player, slot) or from
	-- 벽을 돌아가는 길 (HelperPath, 2026-11-24). 아직 찾는 중이면 이번엔 쉼 (다음에 같은 칸이면 바로 나옴)
	local path = HelperPath.get(from, to)
	if path == nil then
		Economy.releaseSlot(d, slot)
		return
	end
	local dur = math.max(CH.minWalk, HelperPath.length(path, from, to) / CH.speed) + CH.pickSeconds
	st.carry = { phase = "go", t = 0, dur = dur, id = item.id, slot = slot, shape = item.s, from = from, to = to, path = path or "" }
	setCarry(m, "go", { shape = item.s, slot = slot, from = from, to = to, dur = dur, path = path or "" })
end

local function stepHelper(player, d, i, h, st, dt)
	local role = h.post and G.helperPost(h.post)
	if role and role.kind ~= "station" and G.hasPost(d, h.post) then
		stepRole(player, d, i, h, st, dt, role)
		return
	end
	if h.post ~= "stove" then
		-- 기계 알바: 기계가 돌게 함 (만들기·급여는 MachineService). 대기: 쉼
		local p = h.post and G.helperPost(h.post)
		if not p or not G.hasPost(d, h.post) then
			st.status = "대기"
			setHelperText(st, string.format("알바생 %d · 쉬는 중 (자리 없음)", i))
			return
		end
		local ms = Machine.statusOf(player, p.stage) or "work"
		st.status = ms
		if ms == "work" then
			setHelperText(st, string.format("알바생 %d · %s", i, p.name))
		else
			setHelperText(st, string.format("알바생 %d · 쉬는 중 (%s)", i, ms))
		end
		return
	end
	local shape = ShapeCatalog.get(h.shape) or ShapeCatalog.get(cheapestHelperShape(d))
	local seconds, qMin, qMax = G.stoveHelperSpec(d)
	local wage = math.floor(seconds / 30 * G.Helper.wagePer30s + 0.5)
	-- 쉬는 이유 확인
	-- 알바생은 재료(설탕·소다·젓가락 등)를 안 씀 (2026-11-21 사용자: "알바생은 재료 안 쓰게 해"). 급여만 냄
	local why = nil
	if not G.shopOpen(d) then
		why = "가게 문 닫힘" -- 월세 밀림 (D21)
	elseif G.stockRoom(d) <= 0 then
		why = "보관함 가득"
	elseif d.coins < wage then
		why = "급여 부족"
	elseif not helperCoalReady(d) then
		why = "연탄 없음" -- D44
	end
	if why then
		st.status = why
		setHelperText(st, string.format("알바생 %d · 쉬는 중 (%s)", i, why))
		return
	end
	st.status = "work"
	st.t += dt
	setHelperText(st, string.format("알바생 %d · %s %d/%d초", i, shape.name, math.floor(st.t), seconds))
	if st.t < seconds then
		return
	end
	st.t = 0
	-- 1개 완성: 급여를 쓰고 보관함에 (재료는 안 씀) (자동 생산 표시 a = true, 포장 안 함)
	local ups, newShapes = {}, {}
	local deliverSlot = nil
	Data.update(player, function(dd)
		dd.coins -= wage
		dd.stats.wagesPaid = (dd.stats.wagesPaid or 0) + wage
		dd.stats.helperMade = (dd.stats.helperMade or 0) + 1
		helperBurnCoal(dd) -- D44
		local q, grade, mult = rollHelperQuality(qMin, qMax)
		local item = { s = shape.id, g = grade, q = q, b = shape.price, m = mult, pk = false, a = true }
		item.p = G.salePrice(item.b, item.m, G.GachaBonusDefault, false)
		deliverSlot = Economy.stockProduced(dd, item, "helper") -- 빈 칸이면 진열, 아니면 보관함 (D26)
		ups = Economy.addExp(dd, G.ExpHelper)
		if #ups > 0 then
			newShapes = refreshUnlocks(dd)
		end
	end)
	Economy.announceLevels(player, ups)
	if #newShapes > 0 then
		Economy.notify(player, "새 도안: " .. table.concat(newShapes, ", "))
	end
	-- 미니미가 그 칸으로 들고 가는 연출 신호 (클라이언트 HelperLadles가 그림, 칸 = DisplayShelf.Slot<n>)
	if deliverSlot and st.model and st.model.Parent then
		signalDeliver(player, st.model, deliverSlot)
	end
	print(string.format("[Helper] %s #%d made %s (-%d wage) shelf=%s", player.Name, i, shape.id, wage, tostring(deliverSlot)))
end

-- 오프라인 정산 (D29·D34): 화로에 배치한 알바생만 직접 만듦 (기계 알바는 MachineService.offlineTick이 기계째 셈).
-- 반환 = 아직 일할 수 있는가
local function offlineHelper(dd, i, st, dt, rep)
	local h = dd.partTimers[i]
	if not h or h.post ~= "stove" then
		return false
	end
	local shape = ShapeCatalog.get(h.shape) or ShapeCatalog.get(cheapestHelperShape(dd))
	local seconds, qMin, qMax = G.stoveHelperSpec(dd)
	local wage = math.floor(seconds / 30 * G.Helper.wagePer30s + 0.5)
	local why = nil
	if not G.shopOpen(dd) then
		why = "가게 문 닫힘"
	elseif G.stockRoom(dd) <= 0 then
		why = "보관함 가득"
	elseif dd.coins < wage then
		why = "급여 부족"
	elseif not helperCoalReady(dd) then
		why = "연탄 없음" -- D44
	end
	if why then
		rep.stops["알바생 " .. i] = rep.stops["알바생 " .. i] or why -- 처음 멈춘 이유
		return false
	end
	st.t += dt
	if st.t < seconds then
		return true
	end
	st.t = 0
	dd.coins -= wage
	dd.stats.wagesPaid = (dd.stats.wagesPaid or 0) + wage
	dd.stats.helperMade = (dd.stats.helperMade or 0) + 1
	local coalBefore = dd.ingredients.coal or 0
	helperBurnCoal(dd) -- D44
	if (dd.ingredients.coal or 0) < coalBefore then
		rep.used.coal = (rep.used.coal or 0) + (coalBefore - dd.ingredients.coal)
	end
	local q, grade, mult = rollHelperQuality(qMin, qMax)
	local item = { s = shape.id, g = grade, q = q, b = shape.price, m = mult, pk = false, a = true }
	item.p = G.salePrice(item.b, item.m, G.GachaBonusDefault, false)
	Economy.stockProduced(dd, item, "helper")
	for _, u in ipairs(Economy.addExp(dd, G.ExpHelper)) do
		table.insert(rep.ups, u)
	end
	rep.made.helper += 1
	rep.wages += wage
	rep.exp += G.ExpHelper
	return true
end

local function syncHelpers(player, d)
	local plot = Plots.get(player)
	local states = helperState[player]
	if not states then
		states = {}
		helperState[player] = states
	end
	for i, h in ipairs(d.partTimers) do
		if not states[i] then
			states[i] = { t = 0, status = "work" }
		end
		local st = states[i]
		-- 자리를 옮겼으면 미니미를 새 자리에 다시 (D34)
		if st.model and st.post ~= h.post then
			st.model:Destroy()
			st.model = nil
			st.t = 0
		end
		local role = h.post and G.helperPost(h.post)
		local inShop = not (role and role.kind == "factory") -- 공장 공정 미니미는 FactoryDisplay가 공장 방에 (D43)
		if not inShop then
			st.post = h.post
		end
		if plot and inShop and not st.building and (not st.model or not st.model.Parent) then
			-- 주인 아바타 미니미 (D19). 만드는 데 시간이 걸려서 따로 돌리고, 실패하면 부품 인형
			st.building = true
			local post = h.post
			st.post = post
			task.spawn(function()
				local okFoot, foot = pcall(helperFoot, plot, post, i)
				if not okFoot then
					warn("[Helper] stand spot failed", post, foot)
					foot = stoveFoot(plot, 1 + i)
				end
				local m = Minime.build(player, plot.model, foot, i, h.skill or 0)
				local now = Data.get(player) or d
				if not player.Parent or helperState[player] ~= states or (now.partTimers[i] or {}).post ~= post then
					if m then
						m:Destroy()
					end
					st.building = false
					if player.Parent and helperState[player] == states then
						syncHelpers(player, Data.get(player) or d) -- 그 사이 또 옮김
					end
					return
				end
				m = m or helperModel(player, plot, i, foot)
				m.Name = helperName(post, i)
				m:SetAttribute("Post", post or "")
				m:SetAttribute("StationKey", post and STATION_KEY[post] or nil)
				m:SetAttribute("Working", false)
				st.model = m
				st.building = false
			end)
		end
	end
	-- 화로 위 알바생 국자: 화로 알바가 있으면 1개 (D39, Making/HelperLadles가 Helper1과 짝지어 그림)
	local ws = Plots.workstation and Plots.workstation(player)
	local ladles = G.helperAt(d, "stove") and 2 or 1
	if ws and ws:GetAttribute("LadleCount") ~= ladles then
		ws:SetAttribute("LadleCount", ladles)
	end
	-- 화구 ② (2026-11-24 사용자: 가게 임대 Lv3부터 화구 2개, ①은 내 손 작업대, ②는 화로 알바 자리).
	-- 서버가 화로(Brazier)를 복제해 작업대 밖(테이블 오른쪽 끝 너머)에 둠. 자리는 작업대 틀 속성 Burner2Rel(작업대 기준 CFrame)로 바꿀 수 있음.
	-- 작업대 속성 Burner2 = 놓은 자리(작업대 기준), CoalLeft2 = 화구 ② 연탄 (제작 세션 HelperLadles·화면이 봄)
	if ws then
		local want = G.Burner2Brazier and G.shopOpen(d) and (d.level or 1) >= G.Shop.rentLevel
		local b2 = ws:FindFirstChild("Brazier2")
		if want and not b2 then
			local b1 = ws:FindFirstChild("Brazier")
			local top = ws:FindFirstChild("TableTop")
			if b1 and top then
				b2 = b1:Clone()
				b2.Name = "Brazier2"
				local rel = ws:GetAttribute("Burner2Rel")
				local cf
				if typeof(rel) == "CFrame" then
					cf = ws:GetPivot() * rel
				else
					cf = b1:GetPivot() + top.CFrame.RightVector * (top.Size.X / 2 + 2.6)
				end
				b2:PivotTo(cf)
				b2.Parent = ws
				ws:SetAttribute("Burner2", ws:GetPivot():ToObjectSpace(cf))
				-- 이미 서 있던 화로 알바는 화구 ② 옆으로
				local h1 = plot and plot.model:FindFirstChild("Helper1")
				if h1 then
					h1:PivotTo(helperFoot(plot, "stove", 1))
				end
			end
		elseif not want and b2 then
			b2:Destroy()
			ws:SetAttribute("Burner2", nil)
		end
		if ws:FindFirstChild("Brazier2") then
			local c2 = tonumber(d.coalLeft2) or 1
			if math.abs((ws:GetAttribute("CoalLeft2") or -1) - c2) > 0.001 then
				WorkstationBuilder.setCoal2(ws, c2)
			end
		end
	end
	-- 화로 연탄 모습 = 저장된 남은 양 (D44, 화로 알바가 태운 것·자리 비운 동안 쓴 것도)
	local coal = tonumber(d.coalLeft) or 1
	if ws and math.abs((ws:GetAttribute("CoalLeft") or 1) - coal) > 0.001 then
		WorkstationBuilder.setCoal(ws, coal)
	end
end

local function clearHelpers(player)
	local states = helperState[player]
	if states then
		for _, st in pairs(states) do
			if st.model then
				st.model:Destroy()
			end
		end
	end
	helperState[player] = nil
end

---------------------------------------------------------------- HUD에 보낼 성장 정보

local function growthSnapshot(player, d, snap)
	local helpers = {}
	local states = helperState[player] or {}
	for i, h in ipairs(d.partTimers) do
		local st = states[i]
		table.insert(helpers, { shape = h.shape, status = st and st.status or "work", skill = h.skill or 0, post = h.post })
	end
	local ups = {}
	for _, kind in ipairs(G.UpgradeOrder) do
		ups[kind] = upgradeLevel(d, kind)
	end
	local collection = {}
	for id, c in pairs(d.collection) do
		collection[id] = { best = c.best, n = c.n, pp = c.pp }
	end
	local rentLeft = nil
	if d.shop.state == "rented" and not d.shop.closed then
		rentLeft = math.max(0, math.floor(G.Shop.rentEvery - (d.shop.rentTimer or 0)))
	end
	snap.collection = Collection.snapshot(d) -- 도감 화면 (D38, CollectionUi)
	snap.growth = {
		shop = { state = d.shop.state, closed = d.shop.closed == true, rentLeft = rentLeft },
		upgrades = ups,
		helpers = helpers,
		-- D34 배치: 가진 제작대 목록, 다음 고용비 (없으면 최대 인원), D40 화로 알바 교육
		posts = (function()
			local list = {}
			for _, p in ipairs(G.HelperPosts) do
				if G.hasPost(d, p.key) then
					table.insert(list, { key = p.key, name = p.name, kind = p.kind, wage = p.wage, helper = G.helperAt(d, p.key) })
				end
			end
			return list
		end)(),
		hireCost = G.HireCost[#d.partTimers + 1],
		helperMax = G.HelperMax,
		stoveUps = table.clone(d.stoveUps or {}),
		displayHand = d.displayHand ~= false,
		daily = d.daily.goals,
		collection = collection,
		unlocked = table.clone(d.unlockedShapes),
		nextUnlock = nextUnlockLevel(d.level),
		machine = Machine.snapshot(player, d),
		factory = Factory.snapshot(player, d),
	}
end

---------------------------------------------------------------- 연결

function GrowthService.mods(player)
	local d = Data.get(player)
	if not d then
		return nil
	end
	return { stove = upgradeLevel(d, "stove"), presser = upgradeLevel(d, "presser") }
end

local function onHandMade(player, shape, result)
	local newShapes = {}
	local finished, ups = {}, {}
	local notes, newTitles, gold = {}, {}, false
	Data.update(player, function(d)
		-- 도감 (D38: 손으로 만든 것만, 민짜 달고나는 안 셈 — D20). 보상·칭호는 CollectionService
		local rank = G.GradeRank[result.grade] or 0
		local cUps
		notes, cUps, newTitles, gold = Collection.onMade(d, shape, result)
		-- 일일 목표
		local f1, u1 = progressDaily(d, "make", 1)
		finished, ups = f1, u1
		for _, u in ipairs(cUps) do
			table.insert(ups, u)
		end
		if rank >= G.GradeRank.Good then
			local f2, u2 = progressDaily(d, "good", 1)
			for _, x in ipairs(f2) do
				table.insert(finished, x)
			end
			for _, x in ipairs(u2) do
				table.insert(ups, x)
			end
		end
		newShapes = refreshUnlocks(d) -- Master (도감 조건)
	end)
	Collection.after(player, notes, newTitles, gold)
	for _, text in ipairs(finished) do
		Economy.notify(player, string.format("일일 목표 완료! %s (+%d EXP, +%d 코인)", text, G.ExpDailyGoal, G.Daily.rewardCoins))
	end
	Economy.announceLevels(player, ups)
	if #newShapes > 0 then
		Economy.notify(player, "새 도안: " .. table.concat(newShapes, ", "))
	end
end

local function onLevelUp(player, _level)
	local newShapes = {}
	Data.update(player, function(d)
		newShapes = refreshUnlocks(d)
		if #newShapes == 0 then
			return false
		end
	end)
	if #newShapes > 0 then
		Economy.notify(player, "새 도안: " .. table.concat(newShapes, ", "))
	end
end

function GrowthService.init(dataService, economyService, plotService, remotes)
	Data, Economy, Plots = dataService, economyService, plotService
	Economy.extendSnapshot = growthSnapshot
	Collection.init(Data, Economy, Plots, remotes) -- 도감 보상·칭호 (D38), 뽑기 도장도 여기서 (Economy.onPerfectPpopgi)
	Economy.on("handMade", onHandMade)
	Economy.on("levelUp", onLevelUp)
	Economy.on("sold", function(player, n, coins)
		dailyEvent(player, "sell", n)
		dailyEvent(player, "earn", coins)
	end)
	Economy.on("packed", function(player)
		dailyEvent(player, "pack", 1)
	end)
	remotes.GrowthAction.OnServerInvoke = GrowthService.action
	Machine.init(Data, Economy, Plots, { refreshUnlocks = refreshUnlocks })
	Factory.init(Data, Economy, Plots, { refreshUnlocks = refreshUnlocks, isMaking = Production.isMaking })
	Tutorial.init(Data, Economy, remotes)
	Offline.init(Data, Economy, { helper = offlineHelper, machine = Machine.offlineTick, factory = Factory.offlineTick, refreshUnlocks = refreshUnlocks })

	-- 처음 불러올 때: 레벨에 맞게 해금, 오늘 목표, 해금 목록을 속성으로 (제작 화면 도안 고르기가 봄)
	local ready = {}
	Data.Changed:Connect(function(player)
		-- BindableEvent는 표를 복사해서 넘기므로 진짜 데이터를 다시 가져온다
		local d = Data.get(player)
		if not d then
			return
		end
		if not ready[player] then
			ready[player] = true
			local changed = false
			if #refreshUnlocks(d) > 0 then
				changed = true
			end
			if rollDaily(d) then
				changed = true
			end
			if changed then
				Data.update(player, function() end)
			end
			-- 자리 비운 동안 알바생·기계·공장이 만든 것 정산 (D29). 처음 불러올 때 한 번만
			Offline.settle(player)
		end
		player:SetAttribute("UnlockedShapes", table.concat(d.unlockedShapes, ","))
		-- 가게 건물 모습 (셔터·임대 문의·간판, D21)
		local _, plotIndex = Plots.get(player)
		if plotIndex and Plots.setShopState then
			Plots.setShopState(plotIndex, d.shop.state, d.shop.closed, player.DisplayName)
		end
		syncHelpers(player, d)
	end)
	Players.PlayerRemoving:Connect(function(p)
		ready[p] = nil
		lastAction[p] = nil
		clearHelpers(p)
	end)

	-- Studio 테스트용: ServerStorage.DevGrant:Invoke(userId, 코인, EXP, 월세 타이머 초, 달고나 목록, 보관함 비우기, 값 바꾸기) (실서버에서는 안 만듦)
	-- 값 바꾸기 = { coalLeft = 0, ingredients = { coal = 0 } } 처럼 데이터 칸을 바로 씀 (표는 한 단계 안까지)
	if game:GetService("RunService"):IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "DevGrant"
		dev.OnInvoke = function(userId, coins, exp, rentTimer, items, clearStock, set)
			local p = Players:GetPlayerByUserId(userId)
			if not p then
				return "no player"
			end
			local ups = {}
			Data.update(p, function(d)
				d.coins += coins or 0
				ups = Economy.addExp(d, exp or 0)
				if rentTimer then
					d.shop.rentTimer = rentTimer
				end
				if clearStock then
					d.stock = {} -- 시험용: 보관함 비우기
				end
				for _, item in ipairs(items or {}) do -- 시험용 달고나 (빈 진열 칸 → 없으면 보관함)
					Economy.stockProduced(d, item, "dev")
				end
				for k, v in pairs(type(set) == "table" and set or {}) do
					if type(v) == "table" and type(d[k]) == "table" then
						for k2, v2 in pairs(v) do
							d[k][k2] = v2
						end
					else
						d[k] = v
					end
				end
			end)
			Economy.announceLevels(p, ups)
			local d = Data.get(p)
			return string.format("coins=%d lv=%d exp=%d", d.coins, d.level, d.exp)
		end
		dev.Parent = game:GetService("ServerStorage")
	end

	-- 월세 (D21): 접속 중 rentEvery초마다 rentAmount. 못 내면 가게 문만 닫히고, 코인이 생기면 바로 내고 다시 열림 (빚 없음)
	task.spawn(function()
		while true do
			local dt = task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local d = Data.get(player)
				local shop = d and d.shop
				if shop and shop.state == "rented" then
					local msg = nil
					if shop.closed then
						if d.coins >= G.Shop.rentAmount then
							Data.update(player, function(dd)
								dd.coins -= G.Shop.rentAmount
								dd.shop.closed = false
								dd.shop.rentTimer = 0
							end)
							msg = string.format("밀린 월세 %d코인을 냈어요. 가게 문이 다시 열렸어요", G.Shop.rentAmount)
						end
					else
						shop.rentTimer = (shop.rentTimer or 0) + dt -- 저장은 자동 저장 때 같이 (매초 알리지 않음)
						if shop.rentTimer >= G.Shop.rentEvery then
							if d.coins >= G.Shop.rentAmount then
								Data.update(player, function(dd)
									dd.coins -= G.Shop.rentAmount
									dd.shop.rentTimer -= G.Shop.rentEvery
								end)
								msg = string.format("월세 %d코인을 냈어요", G.Shop.rentAmount)
							else
								Data.update(player, function(dd)
									dd.shop.closed = true
									dd.shop.rentTimer = G.Shop.rentEvery
								end)
								msg = string.format("월세 %d코인이 모자라 가게 문이 닫혔어요. 앞 노점에서는 계속 팔 수 있어요", G.Shop.rentAmount)
							end
						end
					end
					if msg then
						Economy.notify(player, msg)
						print(string.format("[Rent] %s %s coins=%d", player.Name, msg, Data.get(player).coins))
					end
				end
			end
		end
	end)

	-- 알바생: 1초마다 진행
	task.spawn(function()
		while true do
			local dt = task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local d = Data.get(player)
				local states = helperState[player]
				if d and states and #d.partTimers > 0 then
					local before = {}
					for i, st in pairs(states) do
						before[i] = st.status
					end
					for i, h in ipairs(d.partTimers) do
						local st = states[i]
						if st then
							stepHelper(player, Data.get(player), i, h, st, dt)
							stepCarry(player, Data.get(player), h, st, dt) -- 4단계 기계·공장 포장 알바: 들고 가서 진열
						end
					end
					for i, st in pairs(states) do
						if before[i] ~= st.status then
							Economy.push(player) -- 쉬는 이유가 바뀌면 HUD에도
							break
						end
					end
				end
			end
		end
	end)
end

return GrowthService

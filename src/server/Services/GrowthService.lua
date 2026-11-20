-- 성장 (Phase 4, 2026-11-20): 도안 해금 · 도감 · 장비 업그레이드 · 국자 · 알바생 · 일일 목표
-- 수치는 GrowthConfig. 기준: GAME_DESIGN_DOCUMENT 3·6장, SHOP_GROWTH_PLAN 2·9장, SYSTEMS_SPECIFICATION 6·7장.
--  - 도안: 레벨로 등급별 해금 (G.UnlockLevel). Master는 도감 조건 (G.MasterUnlock, D6)
--  - 도감: 손으로 만든 것만 도안별 최고 등급·개수 (자동 생산은 안 셈)
--  - 장비: 화로·누르개·작업대 (Lv2부터). 효과는 ProductionService.hooks.mods + G.stockMax
--  - 국자: 2~4번째 국자 (Lv3·5·8). 국자 2번째부터 알바생 1명씩 고용 가능
--  - 알바생: 접속 중에만, 40초에 1개 (Normal~Good), 재료·젓가락을 쓰고, 다 만들 때 급여(30초당 3)를 냄.
--    재료·보관함·코인이 모자라면 쉼. 부지 손 작업대 자리 옆에 작은 인형 + 진행 표시
--  - 일일 목표 3개: UTC 날짜마다 새로 뽑음, 다 하면 EXP 15 + 코인

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("GrowthConfig"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))
local Config = require(Shared:WaitForChild("DalgonaConfig"))

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

local function actionBuy(player, d, kind)
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
	elseif kind == "ladle" then
		local nextN = d.ladles + 1
		local spec = G.Ladles[nextN]
		if not spec then
			return false, "국자는 4개까지예요"
		end
		if d.level < spec.level then
			return false, string.format("Lv%d부터 살 수 있어요", spec.level)
		end
		if d.coins < spec.cost then
			return false, "코인이 모자라요"
		end
		d.coins -= spec.cost
		d.ladles = nextN
		return true, string.format("국자 %d개! 알바생을 고용할 수 있어요", nextN)
	elseif kind == "hire" then
		local n = #d.partTimers
		if n >= d.ladles - 1 then
			return false, "알바생 자리가 없어요 (국자를 더 사요)"
		end
		local cost = G.HireCost[n + 1]
		if not cost then
			return false, "더 고용할 수 없어요"
		end
		if d.coins < cost then
			return false, "코인이 모자라요"
		end
		d.coins -= cost
		table.insert(d.partTimers, { shape = cheapestHelperShape(d), skill = 0 })
		return true, string.format("알바생 %d번 고용!", n + 1)
	end
	return false, "모르는 항목"
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
	local ok, msg = false, "잘못된 요청"
	Data.update(player, function(dd)
		if what == "buy" and type(a) == "string" then
			ok, msg = actionBuy(player, dd, a)
		elseif what == "helperShape" and type(a) == "number" and type(b) == "string" then
			ok, msg = actionSetShape(dd, math.floor(a), b)
		end
		if not ok then
			return false
		end
	end)
	if ok and helperState[player] then
		for _, st in pairs(helperState[player]) do
			st.t = 0 -- 도안을 바꾸면 그 판은 처음부터
		end
	end
	return { ok = ok, reason = not ok and msg or nil, msg = ok and msg or nil }
end

---------------------------------------------------------------- 알바생 생산

local function helperModel(player, plot, i)
	local m = Instance.new("Model")
	m.Name = "Helper" .. i
	local spot = G.Plots.handStation.pos
	local cf = plot.cframe * CFrame.new(spot.X - 8 + (i - 1) * 5, G.Plots.size.Y, spot.Z - 2.5)
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

local function setHelperText(st, text)
	local head = st.model and st.model:FindFirstChild("Head")
	local bb = head and head:FindFirstChild("Status")
	if bb and bb.TextLabel.Text ~= text then
		bb.TextLabel.Text = text
	end
end

local function rollHelperQuality()
	local q = math.random(G.Helper.qMin, G.Helper.qMax)
	for _, g in ipairs(Config.Grades) do
		if q >= g.min then
			return q, g.name, g.mult
		end
	end
	return q, "Normal", 0.8
end

-- 알바생 1명 1초 진행. 반환: 바뀐 상태 글(또는 nil)
local function stepHelper(player, d, i, h, st, dt)
	local shape = ShapeCatalog.get(h.shape) or ShapeCatalog.get(cheapestHelperShape(d))
	local seconds = G.Helper.skillSeconds[h.skill or 0] or G.Helper.seconds
	local wage = math.floor(seconds / 30 * G.Helper.wagePer30s + 0.5)
	-- 쉬는 이유 확인
	local need = G.recipe(shape.grade)
	need.chopsticks = G.ChopsticksPerHelperRound
	local why = nil
	if #d.stock >= G.stockMax(d) then
		why = "보관함 가득"
	elseif d.coins < wage then
		why = "급여 부족"
	else
		for _, ing in ipairs(G.Ingredients) do
			if (need[ing.id] or 0) > (d.ingredients[ing.id] or 0) then
				why = ing.name .. " 부족"
				break
			end
		end
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
	-- 1개 완성: 재료·젓가락·급여를 쓰고 보관함에 (자동 생산 표시 a = true, 포장 안 함)
	local ups, newShapes = {}, {}
	Data.update(player, function(dd)
		for id, n in pairs(need) do
			dd.ingredients[id] = math.max(0, (dd.ingredients[id] or 0) - n)
		end
		dd.coins -= wage
		dd.stats.wagesPaid = (dd.stats.wagesPaid or 0) + wage
		dd.stats.helperMade = (dd.stats.helperMade or 0) + 1
		local q, grade, mult = rollHelperQuality()
		local item = { s = shape.id, g = grade, q = q, b = shape.price, m = mult, pk = false, a = true }
		item.p = G.salePrice(item.b, item.m, G.GachaBonusDefault, false)
		table.insert(dd.stock, item)
		ups = Economy.addExp(dd, G.ExpHelper)
		if #ups > 0 then
			newShapes = refreshUnlocks(dd)
		end
	end)
	Economy.announceLevels(player, ups)
	if #newShapes > 0 then
		Economy.notify(player, "새 도안: " .. table.concat(newShapes, ", "))
	end
	print(string.format("[Helper] %s #%d made %s (-%d wage)", player.Name, i, shape.id, wage))
end

local function syncHelpers(player, d)
	local plot = Plots.get(player)
	local states = helperState[player]
	if not states then
		states = {}
		helperState[player] = states
	end
	for i, _ in ipairs(d.partTimers) do
		if not states[i] then
			states[i] = { t = 0, status = "work" }
		end
		if plot and (not states[i].model or not states[i].model.Parent) then
			states[i].model = helperModel(player, plot, i)
		end
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
		table.insert(helpers, { shape = h.shape, status = st and st.status or "work", skill = h.skill or 0 })
	end
	local ups = {}
	for _, kind in ipairs(G.UpgradeOrder) do
		ups[kind] = upgradeLevel(d, kind)
	end
	local collection = {}
	for id, c in pairs(d.collection) do
		collection[id] = { best = c.best, n = c.n }
	end
	snap.growth = {
		upgrades = ups,
		ladles = d.ladles,
		helpers = helpers,
		daily = d.daily.goals,
		collection = collection,
		unlocked = table.clone(d.unlockedShapes),
		nextUnlock = nextUnlockLevel(d.level),
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
	local newEntry, newShapes = nil, {}
	local finished, ups = {}, {}
	Data.update(player, function(d)
		-- 도감 (손으로 만든 것만)
		local c = d.collection[shape.id]
		local rank = G.GradeRank[result.grade] or 0
		if not c then
			d.collection[shape.id] = { best = result.grade, n = 1 }
			newEntry = "도감 등록: " .. shape.name .. " (" .. result.grade .. ")"
		else
			c.n += 1
			if rank > (G.GradeRank[c.best] or 0) then
				c.best = result.grade
				newEntry = "도감 갱신: " .. shape.name .. " → " .. result.grade
			end
		end
		-- 일일 목표
		local f1, u1 = progressDaily(d, "make", 1)
		finished, ups = f1, u1
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
	if newEntry then
		Economy.notify(player, newEntry)
	end
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

	-- 처음 불러올 때: 레벨에 맞게 해금, 오늘 목표, 해금 목록을 속성으로 (제작 화면 도안 고르기가 봄)
	local ready = {}
	Data.Changed:Connect(function(player, d)
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
		end
		player:SetAttribute("UnlockedShapes", table.concat(d.unlockedShapes, ","))
		syncHelpers(player, d)
	end)
	Players.PlayerRemoving:Connect(function(p)
		ready[p] = nil
		lastAction[p] = nil
		clearHelpers(p)
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

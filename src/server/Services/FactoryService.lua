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

-- 한 판에 드는 것 (재료·코인)
local function jobCost(d, shape, qty)
	local need = { sugar = (G.recipe(shape.grade).sugar or 1) * qty }
	for id, k in pairs(F.perItem) do
		need[id] = (need[id] or 0) + k * qty
	end
	local coins = F.operatingCoins * qty + F.powerPerUpgrade * upgradeSteps(d)
	return need, coins
end

local function rollQuality(d, mode)
	local m = F.modes[mode] or F.modes.normal
	local lo, hi = m.qMin, m.qMax
	if (d.factory.ups.precision or 0) > 0 then
		lo = math.min(lo + F.precisionQ, 94)
		hi = math.min(hi + F.precisionQ, 94)
	end
	local q = math.random(lo, hi)
	for _, g in ipairs(Config.Grades) do
		if q >= g.min then
			return q, g.name, g.mult
		end
	end
	return q, "Normal", 0.8
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
	local preview = nil
	if shape then
		local need, coins = jobCost(d, shape, f.qty)
		preview = { seconds = G.factorySeconds(f.qty, f.mode, f.ups), sugar = need.sugar, soda = need.soda, wrapper = need.wrapper, coins = coins }
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
		price = F.price,
		level = F.level,
	}
end

---------------------------------------------------------------- 생산 (1초마다)

-- 빈 라인에 새 판: 못 하면 이유
local function startJob(player, k)
	local why = nil
	Data.update(player, function(dd)
		local f = dd.factory
		local shape = shapeOf(dd)
		if not G.shopOpen(dd) then
			why = "가게 문 닫힘"
			return false
		end
		if not shape then
			why = "도안 없음"
			return false
		end
		-- 이미 돌고 있는 판까지 합쳐 보관함에 들어갈 자리
		local pending = 0
		for _, job in pairs(f.lines) do
			if job then
				pending += job.n
			end
		end
		if #dd.stock + pending >= G.stockMax(dd) then
			why = "보관함 가득"
			return false
		end
		local need, coins = jobCost(dd, shape, f.qty)
		for _, ing in ipairs(G.Ingredients) do
			if (need[ing.id] or 0) > (dd.ingredients[ing.id] or 0) then
				why = "재료 부족: " .. ing.name
				return false
			end
		end
		if dd.coins < coins then
			why = "코인 부족"
			return false
		end
		for id, n in pairs(need) do
			dd.ingredients[id] -= n
		end
		dd.coins -= coins
		dd.stats.factorySpent = (dd.stats.factorySpent or 0) + coins
		f.lines[k] = { s = shape.id, n = f.qty, m = f.mode, t = 0, sec = G.factorySeconds(f.qty, f.mode, f.ups) }
	end)
	return why
end

local function finishJob(player, k, job)
	local made, slots, ups, newShapes = 0, {}, {}, {}
	Data.update(player, function(dd)
		local f = dd.factory
		f.lines[k] = false
		local shape = ShapeCatalog.get(job.s)
		if not shape then
			return
		end
		local room = math.max(0, G.stockMax(dd) - #dd.stock)
		local n = math.min(job.n, room) -- 넘치는 것은 버려짐 (시작할 때 자리를 봤으니 드묾)
		local packed = (f.ups.autopack or 0) > 0
		for _ = 1, n do
			local q, grade, mult = rollQuality(dd, job.m)
			local item = { s = shape.id, g = grade, q = q, b = shape.price, m = mult, pk = packed, a = true, f = true }
			item.p = G.salePrice(item.b, item.m, G.GachaBonusDefault, packed)
			local sl = Economy.stockProduced(dd, item, "factory")
			if sl then
				table.insert(slots, sl)
			end
		end
		dd.stats.factoryMade = (dd.stats.factoryMade or 0) + n
		ups = Economy.addExp(dd, G.ExpMachine * n)
		if #ups > 0 and hooks.refreshUnlocks then
			newShapes = hooks.refreshUnlocks(dd)
		end
		made = n
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

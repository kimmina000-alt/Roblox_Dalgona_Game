-- 주문 제작 손님 (D55, 2026-11-25 확정, GDD 15장, 판매 세션). 수치는 GrowthConfig.OrderCustomer
-- 손님 7종(D37)이 가끔 주문서를 들고 와 주문 대기 자리에 앉음. 가게마다 동시에 1명, 접속 중에만 (저장 안 함).
--   주문: 도안 1종 · 최소 품질 · 포장 여부 · 개수(1~2). 손님 종류별 표(OrderCustomer.orders)를 따름
--   기다리기 3분 (Epic 이상·포장 주문 +1분). 끝나면(채우거나 떠나면) 약 3분(±30%) 뒤 다음 손님
--   건네기: 맞는 달고나(보관함·진열대 어디든) → 판매가 × 1.5(주문 뒤 새로 만든 것) / × 1.3(그 전에 만든 것), Perfect면 ×2 / ×1.7,
--           + 손님 종류 팁. 다 채우면 EXP 20 + 그 손님 하트 판매 수 +3. 계산 알바(D43)가 있으면 맞는 게 생기는 순간 자동으로 건넴
--   실패: 시간이 지나면 떠남, 벌 없음
--
-- 화면 쪽 약속 (UI 세션):
--   가게 부지 모델 ShopPlots.Plot<i> 속성 (모두가 봄): OrderGuest(손님 id, 없으면 nil), OrderShape(도안 id), OrderMinQ(품질 이름),
--     OrderPack(bool), OrderNeed(개수), OrderDone(건넨 수), OrderUntil(서버 시각 workspace:GetServerTimeNow() 기준 떠나는 때)
--   주문 손님 모델: Plot<i>.OrderGuest (Model, 속성 OrderGuest = true, CustomerId). 말풍선은 화면이 위 속성으로 그림
--   Remotes.OrderAction:InvokeServer("give", ids | nil) → { ok, reason, coins, given, done }
--     ids = 건넬 달고나 id 목록(보관함 stock의 id). nil이면 서버가 맞는 것을 골라 남은 개수만큼 (새로 만든 것 먼저)
--   Remotes.OrderAction:InvokeServer("match") → { ids = 지금 건넬 수 있는 달고나 id 목록 (좋은 값 먼저) } (고르기 창에 씀)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("GrowthConfig"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))

local OrderService = {}

local O = G.OrderCustomer
local Data, Economy, Plots, Sales, Collection

local state = {} -- [player] = { order = 주문 | nil, nextAt = os.clock() 기준 다음 손님 때 }

local GRADE_INDEX = {}
for i, g in ipairs(ShapeCatalog.Grades) do
	GRADE_INDEX[g.id] = i
end

local function jitter(sec)
	return sec * (1 + (math.random() * 2 - 1) * O.spread)
end

local function plotOf(player)
	local plot, i = Plots.get(player)
	return plot, i
end

local function setAttrs(plot, o)
	local m = plot and plot.model
	if not m then
		return
	end
	m:SetAttribute("OrderGuest", o and o.cust or nil)
	m:SetAttribute("OrderShape", o and o.shape or nil)
	m:SetAttribute("OrderMinQ", o and o.minQ or nil)
	m:SetAttribute("OrderPack", o and o.pack or nil)
	m:SetAttribute("OrderNeed", o and o.n or nil)
	m:SetAttribute("OrderDone", o and o.done or nil)
	m:SetAttribute("OrderUntil", o and o.untilT or nil)
end

-- 맞는 달고나인가
local function matches(o, it)
	if it.s ~= o.shape then
		return false
	end
	if (G.GradeRank[it.g] or 0) < (G.GradeRank[o.minQ] or 0) then
		return false
	end
	if o.pack and not it.pk then
		return false
	end
	return true
end

-- 지금 건넬 수 있는 것: 새로 만든 것(주문 뒤) 먼저, 그 안에서 값 높은 것 먼저
local function matchList(d, o)
	local list = {}
	for _, it in ipairs(d.stock) do
		if matches(o, it) then
			table.insert(list, it)
		end
	end
	table.sort(list, function(a, b)
		local na, nb = (a.id or 0) >= o.firstId, (b.id or 0) >= o.firstId
		if na ~= nb then
			return na
		end
		return (tonumber(a.p) or 0) > (tonumber(b.p) or 0)
	end)
	return list
end

-- 주문 내용 고르기 (손님 종류별 표)
local function pickShape(d, kind, cust)
	local T = O.orders[kind]
	local cands = {}
	for _, id in ipairs(d.unlockedShapes or {}) do
		local e = ShapeCatalog.get(id)
		if e then
			local gi = GRADE_INDEX[e.grade] or 1
			local ok
			if T.grades then
				ok = table.find(T.grades, e.grade) ~= nil
			elseif T.minGrade then
				ok = gi >= (GRADE_INDEX[T.minGrade] or 1)
			else
				ok = true
			end
			if ok then
				table.insert(cands, id)
			end
		end
	end
	if T.fav then
		local c = d.custDex and d.custDex[cust]
		local fav = d.custFav and d.custFav[cust]
		if c and (c.h or 0) >= 2 and fav and table.find(d.unlockedShapes or {}, fav) then
			return fav
		end
	end
	if #cands == 0 then
		return nil
	end
	return cands[math.random(#cands)]
end

local function newOrder(player, d)
	local t = G.rollCustomer(d.level or 1)
	if t.kind == "vip" and (d.level or 1) < O.vipLevel then
		t = G.Customers.types[math.random(3)] -- 아이 셋 중
	end
	local shape = pickShape(d, t.kind, t.id)
	if not shape then
		t = G.Customers.types[math.random(3)]
		shape = pickShape(d, t.kind, t.id)
	end
	if not shape then
		return nil
	end
	local T = O.orders[t.kind]
	local pack = T.pack == true or (T.pack == "sometimes" and math.random() < (T.packChance or 0.3))
	local e = ShapeCatalog.get(shape)
	local wait = O.wait
	if pack or (GRADE_INDEX[e.grade] or 1) >= (GRADE_INDEX.Epic or 4) then
		wait += O.waitBonus
	end
	return {
		cust = t.id,
		kind = t.kind,
		shape = shape,
		minQ = T.minQ,
		pack = pack,
		n = math.random(T.n[1], T.n[2]),
		done = 0,
		untilT = workspace:GetServerTimeNow() + wait,
		firstId = d.nextItemId or 0, -- 이 번호부터는 주문 뒤 새로 만든 것
		coins = 0,
	}
end

local function removeGuest(plot)
	local g = plot and plot.model:FindFirstChild("OrderGuest")
	if g then
		g:Destroy()
	end
end

local function showGuest(player, plot, i, o)
	removeGuest(plot)
	Sales = Sales or require(script.Parent:WaitForChild("SalesService"))
	local cf = Sales.orderSeat(i)
	local m = cf and Sales.buildGuest(cf, o.cust)
	if m then
		m.Name = "OrderGuest"
		m:SetAttribute("OrderGuest", true)
		m:SetAttribute("CustomerId", o.cust)
		m.Parent = plot.model
	end
end

local function finish(player, why)
	local st = state[player]
	local plot = plotOf(player)
	if st then
		st.order = nil
		st.nextAt = os.clock() + jitter(O.every)
	end
	removeGuest(plot)
	setAttrs(plot, nil)
	if why then
		Economy.notify(player, why)
	end
end

-- 건네기. ids = 건넬 달고나 id 목록(없으면 서버가 고름). 반환 결과 표
local function give(player, ids)
	local st = state[player]
	local o = st and st.order
	if not o then
		return { ok = false, reason = "주문 손님이 없어요" }
	end
	local tip = O.tip[o.kind] or 0
	local given, coins = 0, 0
	Data.update(player, function(dd)
		local want = o.n - o.done
		local pick = {}
		if type(ids) == "table" then
			for _, id in ipairs(ids) do
				if #pick >= want then
					break
				end
				for _, it in ipairs(dd.stock) do
					if it.id == id and matches(o, it) and not table.find(pick, it) then
						table.insert(pick, it)
						break
					end
				end
			end
		else
			for _, it in ipairs(matchList(dd, o)) do
				if #pick >= want then
					break
				end
				table.insert(pick, it)
			end
		end
		if #pick == 0 then
			return false
		end
		for _, it in ipairs(pick) do
			local i = table.find(dd.stock, it)
			if i then
				table.remove(dd.stock, i)
				local isNew = (it.id or 0) >= o.firstId
				local perfect = it.g == "Perfect"
				local mult = isNew and (perfect and O.perfectNew or O.newMult) or (perfect and O.perfectPre or O.preMult)
				local c = math.floor((tonumber(it.p) or 0) * mult * (1 + tip) + 0.5)
				coins += c
				given += 1
			end
		end
		dd.coins += coins
		dd.stats.sold = (dd.stats.sold or 0) + given
		dd.stats.coinsEarned = (dd.stats.coinsEarned or 0) + coins
		dd.stats.orders = (dd.stats.orders or 0) + (o.done + given >= o.n and 1 or 0)
	end)
	if given == 0 then
		return { ok = false, reason = "맞는 달고나가 없어요" }
	end
	o.done += given
	o.coins += coins
	local plot = plotOf(player)
	setAttrs(plot, o)
	local done = o.done >= o.n
	if done then
		local ups = {}
		Data.update(player, function(dd)
			ups = Economy.addExp(dd, O.exp)
		end)
		Economy.announceLevels(player, ups)
		Collection = Collection or require(script.Parent:WaitForChild("CollectionService"))
		local d = Data.get(player)
		if d and not (d.custDex and d.custDex[o.cust]) then
			pcall(Collection.onCustomerMet, player, o.cust)
		end
		pcall(Collection.onCustomerSold, player, o.cust, O.hearts)
		local t = G.customerType(o.cust)
		finish(player, string.format("%s 주문 완료! +%d 코인 · +%d EXP", t and t.name or "손님", o.coins, O.exp))
	end
	Economy.push(player)
	return { ok = true, coins = coins, given = given, done = done }
end

local function step(player)
	local st = state[player]
	local d = Data.get(player)
	if not (st and d) then
		return
	end
	local plot, i = plotOf(player)
	local o = st.order
	if o then
		if not plot or workspace:GetServerTimeNow() > o.untilT or not G.shopOpen(d) then
			local t = G.customerType(o.cust)
			finish(player, (t and t.name or "손님") .. ": 아쉽다… (주문 손님이 떠났어요)")
			return
		end
		-- 계산 알바(D43)가 있으면 맞는 게 생기는 순간 자동으로 건넴
		if G.helperAt(d, "cashier") and #matchList(d, o) > 0 then
			give(player, nil)
		end
		return
	end
	if not plot or (d.level or 1) < O.level or not G.shopOpen(d) then
		return
	end
	if os.clock() < st.nextAt then
		return
	end
	o = newOrder(player, d)
	if not o then
		st.nextAt = os.clock() + jitter(O.every)
		return
	end
	st.order = o
	setAttrs(plot, o)
	showGuest(player, plot, i, o)
	local t = G.customerType(o.cust)
	local e = ShapeCatalog.get(o.shape)
	Economy.notify(player, string.format("주문 손님! %s: %s %d개 (%s 이상%s)", t and t.name or "손님", e and e.name or o.shape, o.n, o.minQ, o.pack and " · 포장" or ""))
end

function OrderService.init(dataService, economyService, plotService)
	Data, Economy, Plots = dataService, economyService, plotService
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local fn = remotes:FindFirstChild("OrderAction")
	if not fn then
		fn = Instance.new("RemoteFunction")
		fn.Name = "OrderAction"
		fn.Parent = remotes
	end
	local last = {}
	fn.OnServerInvoke = function(player, what, a)
		if last[player] and os.clock() - last[player] < 0.3 then
			return { ok = false, reason = "천천히!" }
		end
		last[player] = os.clock()
		if what == "give" then
			return give(player, type(a) == "table" and a or nil)
		elseif what == "match" then
			local st = state[player]
			local d = Data.get(player)
			local ids = {}
			if st and st.order and d then
				for _, it in ipairs(matchList(d, st.order)) do
					table.insert(ids, it.id)
				end
			end
			return { ok = true, ids = ids }
		end
		return { ok = false, reason = "잘못된 요청" }
	end
	local function join(p)
		state[p] = { order = nil, nextAt = os.clock() + jitter(O.firstDelay) }
	end
	for _, p in ipairs(Players:GetPlayers()) do
		join(p)
	end
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(function(p)
		local plot = plotOf(p)
		removeGuest(plot)
		setAttrs(plot, nil)
		state[p] = nil
		last[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, p in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(step, p)
				if not ok then
					warn("[Order]", err)
				end
			end
		end
	end)
end

return OrderService

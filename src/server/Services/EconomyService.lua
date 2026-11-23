-- 코인·재료·재고·EXP (Phase 2, 2026-11-20)
--  - 재료 상점: 묶음 구매 (GrowthConfig.Ingredients)
--  - 제작 시작 전: 재료·재고 자리 확인 (ProductionService.hooks.canStart)
--  - 제작 시작: 나무젓가락 1쌍 (hooks.onStart, "다시 하기"도 새 판이라 1쌍)
--  - 제작 끝 (서버 판정 결과): 재료 쓰고 재고에 달고나 1개, EXP·레벨업 코인 (hooks.onResult)
--  - 판매: 진열대 앞쪽(먼저 만든 것)부터 꺼내 코인으로 (SalesService가 손님이 왔을 때 부름)
--  - HUD로 상태를 보냄 (Remotes.PlayerState), 짧은 알림 (Remotes.Notify)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("GrowthConfig"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))

local EconomyService = {}

local Data = nil -- PlayerDataService
local remotes = nil
local lastBuy = {} -- [player] = os.clock()
local lastMade = {} -- [player] = { item, t } 방금 만든 달고나 (포장 대상)

-- 다른 서비스(GrowthService)가 듣는 일: "handMade"(player, shape, result) / "sold"(player, n, coins) /
-- "packed"(player) / "levelUp"(player, level)
local listeners = {}
function EconomyService.on(name, fn)
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], fn)
end
local function fire(name, ...)
	for _, fn in ipairs(listeners[name] or {}) do
		task.spawn(fn, ...)
	end
end
EconomyService.extendSnapshot = nil -- function(player, data, snap) (GrowthService가 채움)

local ingredientById = {}
for _, ing in ipairs(G.Ingredients) do
	ingredientById[ing.id] = ing
end

local function snapshot(player, data)
	return {
		coins = data.coins,
		level = data.level,
		exp = data.exp,
		expToNext = data.level >= G.MaxLevel and 0 or G.expToNext(data.level),
		ingredients = (function()
			local t = {}
			for _, ing in ipairs(G.Ingredients) do
				t[ing.id] = data.ingredients[ing.id] or 0
			end
			return t
		end)(),
		stock = G.storedCount(data), -- 보관함 (진열대 칸은 따로, D42)
		stockMax = G.stockMax(data),
		plot = player:GetAttribute("PlotIndex"),
		saving = Data.canSave(player),
	}
end

local function fullSnapshot(player, data)
	local snap = snapshot(player, data)
	if EconomyService.extendSnapshot then
		EconomyService.extendSnapshot(player, data, snap)
	end
	return snap
end

-- data 안에서 EXP를 더하고 레벨업 처리 (Data.update 안에서 부름). 반환: 오른 레벨 목록, 받은 코인
function EconomyService.addExp(d, amount)
	local ups, coins = {}, 0
	d.exp += amount
	while d.level < G.MaxLevel and d.exp >= G.expToNext(d.level) do
		d.exp -= G.expToNext(d.level)
		d.level += 1
		local c = G.LevelCoins[d.level] or 0
		d.coins += c
		coins += c
		table.insert(ups, d.level)
	end
	if d.level >= G.MaxLevel then
		d.exp = 0
	end
	return ups, coins
end

-- 레벨업 알림 + GrowthService(해금)에 알림
function EconomyService.announceLevels(player, ups)
	for _, lv in ipairs(ups) do
		EconomyService.notify(player, string.format("레벨 업! Lv%d (+%d 코인)", lv, G.LevelCoins[lv] or 0))
		fire("levelUp", player, lv)
	end
end

---------------------------------------------------------------- 진열대에 직접 놓기 (2026-11-21 사용자 결정 "들고 가서 놓기")
-- 손으로 만든 달고나는 진열대에 저절로 안 올라감: 다 만들면 캐릭터가 들고 있고(속성 Carrying = 달고나 번호),
-- 진열대 빈 칸을 누르면 그 칸에 놓임(item.sl = 칸). 진열한 것만 손님이 삼. 안 놓은 것은 보관함(sl 없음)에 남음.
local carrying = {} -- [player] = 달고나 번호

function EconomyService.newItemId(d)
	local id = d.nextItemId or 1
	d.nextItemId = id + 1
	return id
end

-- 진열된(지금 열린 칸 안) 달고나, 먼저 만든 것부터
function EconomyService.shelved(d)
	local slots = G.shelfSlots(d)
	local list = {}
	for _, item in ipairs(d.stock) do
		if item.sl and item.sl <= slots then
			table.insert(list, item)
		end
	end
	return list
end

-- 빈 칸 번호 (없으면 nil)
-- 들고 가는 중인 칸 (2026-11-24, G.CarryHelpers): [데이터 표] = { [칸] = true }. 저장 안 함 (서버 메모리)
local reservedByData = setmetatable({}, { __mode = "k" })

function EconomyService.isReserved(d, slot)
	local r = reservedByData[d]
	return r ~= nil and r[slot] == true
end

function EconomyService.freeSlot(d)
	local used = {}
	for _, item in ipairs(d.stock) do
		if item.sl then
			used[item.sl] = true
		end
	end
	for i = 1, G.shelfSlots(d) do
		if not used[i] and not EconomyService.isReserved(d, i) then
			return i
		end
	end
	return nil
end

-- 빈 칸 하나를 예약 (들고 가는 동안 다른 데서 못 씀). 반환 칸 또는 nil
function EconomyService.reserveSlot(d)
	local i = EconomyService.freeSlot(d)
	if i then
		reservedByData[d] = reservedByData[d] or {}
		reservedByData[d][i] = true
	end
	return i
end

function EconomyService.releaseSlot(d, slot)
	local r = reservedByData[d]
	if r then
		r[slot] = nil
	end
end

-- 알바생·기계·공장이 만든 달고나 넣기 (D26, 2026-11-21): 빈 칸이 있으면 미니미가 들고 가서 진열(서버는 바로 그 칸에),
-- 없으면 보관함. 반환: 진열한 칸 번호(또는 nil). by = "helper" | "machine" | "factory" (기계·공장은 Phase 5에서 이걸 부름)
-- keep = true면 진열하지 않고 보관함에 둠 (알바가 들고 가서 놓음, G.CarryHelpers)
function EconomyService.stockProduced(d, item, by, keep)
	item.id = item.id or EconomyService.newItemId(d)
	item.by = by
	if G.Shop.autoShelveHelpers and not keep then
		item.sl = EconomyService.freeSlot(d)
	end
	table.insert(d.stock, item)
	return item.sl
end

local function findItem(d, id)
	for i, item in ipairs(d.stock) do
		if item.id == id then
			return item, i
		end
	end
	return nil
end

local function setCarrying(player, id)
	carrying[player] = id
	player:SetAttribute("Carrying", id or 0)
end

function EconomyService.carrying(player)
	return carrying[player]
end

-- 진열대 slot 칸에 놓기: 들고 있는 것, 없으면 보관함에서 먼저 만든 것. 반환 ok, 글
function EconomyService.place(player, slot, extra) -- extra: 놓을 때 달고나에 더 적을 값 (예: 걸이판 자리 pp)
	local data = Data.get(player)
	if not data then
		return false, "불러오는 중이에요"
	end
	if type(slot) ~= "number" or slot < 1 or slot > G.shelfSlots(data) then
		return false, "그 칸은 쓸 수 없어요"
	end
	for _, item in ipairs(data.stock) do
		if item.sl == slot then
			return false, "이미 놓인 칸이에요"
		end
	end
	local target = carrying[player] and findItem(data, carrying[player]) or nil
	if target and target.sl then
		target = nil
	end
	local fromHand = target ~= nil
	if not target then
		for _, item in ipairs(data.stock) do
			if not item.sl then
				target = item
				break
			end
		end
	end
	if not target then
		return false, "놓을 달고나가 없어요"
	end
	Data.update(player, function()
		target.sl = slot
		target.pp = nil
		if type(extra) == "table" then
			for k, v in pairs(extra) do
				target[k] = v
			end
		end
	end)
	if fromHand then
		setCarrying(player, nil)
	end
	fire("placed", player, slot) -- 첫 60초 안내 (TutorialService)
	return true, string.format("진열대 %d번 칸에 놓았어요", slot)
end

function EconomyService.push(player)
	local data = Data.get(player)
	if data then
		-- 들고 있는 달고나가 팔렸거나(쪼개짐 등) 진열됐으면 손에서 내림
		local id = carrying[player]
		if id then
			local item = findItem(data, id)
			if not item or item.sl then
				setCarrying(player, nil)
			end
		end
		local unshelved = 0
		for _, item in ipairs(data.stock) do
			if not item.sl then
				unshelved += 1
			end
		end
		player:SetAttribute("Unshelved", unshelved) -- 보관함에서 꺼내 놓을 수 있는 수 (진열대 칸 안내에 씀)
		player:SetAttribute("Chopsticks", data.ingredients.chopsticks or 0) -- 제작 화면이 젓가락 꺼내기 전에 봄
		-- 재료마다 남은 양 (클라이언트 Making/Supplies: 0이면 작업대 통이 빈 통으로 보임, 2026-11-21)
		for _, ing in ipairs(G.Ingredients) do
			player:SetAttribute("Ing_" .. ing.id, data.ingredients[ing.id] or 0)
		end
	end
	if data and remotes then
		remotes.PlayerState:FireClient(player, fullSnapshot(player, data))
	end
end

function EconomyService.notify(player, text)
	if remotes and typeof(player) == "Instance" and player.Parent then
		remotes.Notify:FireClient(player, text)
	end
end

-- 재료 묶음 사기. 반환: { ok, reason }
function EconomyService.buy(player, ingredientId, packs)
	local ing = ingredientById[ingredientId]
	if not ing then
		return { ok = false, reason = "모르는 재료" }
	end
	packs = math.floor(tonumber(packs) or 1)
	if not table.find(G.BuyPacks, packs) then
		return { ok = false, reason = "잘못된 수량" } -- 1·5·10팩만 (2026-11-24)
	end
	local now = os.clock()
	if lastBuy[player] and now - lastBuy[player] < G.ShopCooldown then
		return { ok = false, reason = "천천히!" }
	end
	lastBuy[player] = now
	local data = Data.get(player)
	if not data then
		return { ok = false, reason = "불러오는 중이에요" }
	end
	local cost = ing.price * packs
	-- 슈퍼마켓 (D54, MarketService): 슈퍼가 골목에 있으면 슈퍼 계산대 앞에서만 사고, 산 것은 봉지에 (가게에 들어가면 냉장고·서랍장으로)
	local market = EconomyService.marketHook
	if market then
		local okM, why = market.check(player)
		if not okM then
			return { ok = false, reason = why }
		end
	end
	local have = (data.ingredients[ing.id] or 0) + (market and market.pending(player, ing.id) or 0)
	if have + ing.pack * packs > G.IngredientMax then
		return { ok = false, reason = string.format("%s은(는) %d개까지 보관해요 (지금 %d개)", ing.name, G.IngredientMax, have) }
	end
	if data.coins < cost then
		return { ok = false, reason = string.format("코인이 모자라요 (%d코인 필요)", cost) }
	end
	Data.update(player, function(d)
		d.coins -= cost
		if not market then
			d.ingredients[ing.id] = (d.ingredients[ing.id] or 0) + ing.pack * packs
		end
	end)
	if market then
		market.toBag(player, ing.id, ing.pack * packs)
	end
	return { ok = true, amount = ing.pack * packs, cost = cost, bag = market ~= nil }
end

-- 제작 시작 전 확인. 반환: ok, 이유(한국어, 화면에 띄움)
function EconomyService.canMake(player, shape)
	local data = Data.get(player)
	if not data then
		return false, "가게 정보를 불러오는 중이에요"
	end
	if G.EnforceUnlocks and not table.find(data.unlockedShapes, shape.id) then
		return false, "아직 안 열린 도안이에요"
	end
	-- 공장 공정을 직접 하는 동안은 손 제작 못 함 (D45, 내 몸은 하나)
	if (player:GetAttribute("FactorySelf") or "") ~= "" then
		return false, "공장에서 일하는 중이에요 (공장 방을 나가거나 그만두면 만들 수 있어요)"
	end
	if G.storageRoom(data) <= 0 then
		return false, string.format("달고나 보관함이 가득 찼어요 (%d개)", G.stockMax(data))
	end
	local need = G.recipe(shape.grade)
	need.chopsticks = G.ChopsticksPerRound
	local missing = {}
	for _, ing in ipairs(G.Ingredients) do
		local n = need[ing.id] or 0
		if (data.ingredients[ing.id] or 0) < n then
			table.insert(missing, string.format("%s %d", ing.name, n))
		end
	end
	if #missing > 0 then
		return false, "재료가 모자라요: " .. table.concat(missing, ", ") .. " 필요 (상점에서 사요)"
	end
	-- 연탄 (D44): 화로 연탄이 다 탔고 보관한 연탄도 없으면 시작 못 함
	if (tonumber(data.coalLeft) or 1) <= 0.001 and (data.ingredients.coal or 0) < 1 then
		return false, "연탄이 다 떨어졌어요 (재료 상점에서 사요)"
	end
	return true
end

-- 제작 시작 (세션이 열림): 나무젓가락 1쌍
function EconomyService.onStart(player, _shape)
	Data.update(player, function(d)
		d.ingredients.chopsticks = math.max(0, (d.ingredients.chopsticks or 0) - G.ChopsticksPerRound)
	end)
	fire("started", player) -- 첫 60초 안내 (TutorialService)
end

-- 진열대에서 n개 팔기 (앞쪽 = 먼저 만든 것부터). 한 번에 꺼내고 지우므로 같은 달고나가 두 번 팔리지 않음.
-- 반환: 판 개수, 받은 코인
-- 반환: 판 개수, 코인, 판 달고나 목록 (손님이 들고 가는 모양용)
-- ctype = 손님 종류 (G.Customers.types 항목, D37). 없으면 예전처럼 먼저 만든 것부터
function EconomyService.sell(player, n, ctype)
	local sold, coins = 0, 0
	local items = {}
	local tips = 0
	Data.update(player, function(d)
		-- 진열대에 놓인 것만, 먼저 만든 것부터 (2026-11-21 진열대에 직접 놓기)
		local list = EconomyService.shelved(d)
		local tipFor = function()
			return 0
		end
		if ctype then
			local fav = nil
			if ctype.kind == "regular" then
				d.custFav = type(d.custFav) == "table" and d.custFav or {}
				fav = d.custFav[ctype.id]
				if not fav and #d.unlockedShapes > 0 then
					fav = d.unlockedShapes[math.random(#d.unlockedShapes)] -- 처음 오면 좋아하는 도안을 정함 (D37)
					d.custFav[ctype.id] = fav
				end
			end
			list, tipFor = G.customerPick(list, ctype, fav, function(id)
				local e = ShapeCatalog.get(id)
				return e and e.grade or "Common"
			end)
		end
		n = math.min(n, #list)
		if n <= 0 then
			return false
		end
		-- 계산 알바 (D43): 모든 판매 팁 +5% (손님 팁과 더함)
		local cashier = (G.helperAt(d, "cashier") and G.shopOpen(d)) and G.Cashier.tip or 0
		-- 도감 하트 2 (단골이 아닌 손님 5종): 그 손님 팁 +5% (함께 더함)
		cashier += G.heartTip(d, ctype)
		for k = 1, n do
			local item = list[k]
			local i = table.find(d.stock, item)
			if i then
				table.remove(d.stock, i)
			end
			local p = math.max(0, math.floor(tonumber(item.p) or 0))
			local withTip = math.floor(p * (1 + tipFor(item) + cashier) + 0.5)
			tips += withTip - p
			coins += withTip
			sold += 1
			table.insert(items, item)
		end
		d.coins += coins
		d.stats.sold = (d.stats.sold or 0) + sold
		d.stats.coinsEarned = (d.stats.coinsEarned or 0) + coins
	end)
	if sold > 0 then
		fire("sold", player, sold, coins)
	end
	return sold, coins, items, tips
end

-- 연탄 (D44): 판을 시작할 때 화로 연탄이 다 탔으면 보관한 연탄 1장을 갈아 넣음. 반환 = 화로 연탄 남은 양
function EconomyService.coalStart(player)
	local left = 1
	Data.update(player, function(d)
		left = tonumber(d.coalLeft) or 1
		if left > 0.001 then
			return false
		end
		if (d.ingredients.coal or 0) < 1 then
			return false -- canMake가 이미 막음
		end
		d.ingredients.coal -= 1
		d.coalLeft = 1
		left = 1
	end)
	return left
end

-- 한 판 끝: 화로 연탄이 amount만큼 탐. 반환 = 남은 양
function EconomyService.coalBurn(player, amount)
	local left = 0
	Data.update(player, function(d)
		d.coalLeft = math.max(0, (tonumber(d.coalLeft) or 1) - G.coalPerMake(d)) -- 연탄 덮개면 1/15 (amount는 예전 값)
		left = d.coalLeft
	end)
	return left
end

-- 방금 만든 달고나 포장: 포장지 1 + 빵끈 1을 쓰고 판매가 ×1.1. 반환 { ok, reason, price }
-- reason "no item"이면 저장된 달고나가 없음 (서버 판정 실패 등) → 화면 연출만 해도 됨
function EconomyService.pack(player)
	local data = Data.get(player)
	local last = lastMade[player]
	if not data or not last or os.clock() - last.t > G.PackWindowSeconds or not table.find(data.stock, last.item) then
		return { ok = false, reason = "no item" }
	end
	if last.item.pk then
		return { ok = false, reason = "이미 포장했어요" }
	end
	if last.item.br then
		return { ok = false, reason = "쪼개진 달고나는 포장할 수 없어요" }
	end
	local missing = {}
	for _, ing in ipairs(G.Ingredients) do
		local n = G.PackCost[ing.id]
		if n and (data.ingredients[ing.id] or 0) < n then
			table.insert(missing, ing.name)
		end
	end
	if #missing > 0 then
		local why = table.concat(missing, "·") .. "이(가) 없어요"
		EconomyService.notify(player, why .. " → 상점에서 사요 (이번엔 포장 없이 끝나요)")
		return { ok = false, reason = why }
	end
	local item = last.item
	Data.update(player, function(d)
		for id, n in pairs(G.PackCost) do
			d.ingredients[id] = math.max(0, (d.ingredients[id] or 0) - n)
		end
		item.pk = true
		item.p = G.salePrice(item.b or item.p, item.b and item.m or 1, item.gb or G.GachaBonusDefault, true)
	end)
	lastMade[player] = nil
	fire("packed", player)
	return { ok = true, price = item.p }
end

function EconomyService.shelfCount(player)
	local data = Data.get(player)
	return data and #EconomyService.shelved(data) or 0
end

-- 뽑기 결과 (15번, ProductionService.hooks.onPpopgi). 2026-11-21 사용자:
--   성공 = "덤 하나 더": 방금 만든 것과 같은 달고나를 보관함에 1개(완벽하면 2개) 더 넣음 (재료 안 씀, 포장 안 된 것)
--   쪼개짐 = 보관함에서 빠짐 (못 팖). 판매가는 그대로 (예전 뽑기 보너스 배율은 안 씀)
-- 순서: 모양 찍기 → 뽑기(선택) → 포장(선택, ×1.1, 방금 만든 것만). 반환 { price, dexNew, broken, extraAdded }
-- dexNew: 이 도안을 처음 완벽하게 뽑았는지 — 도감(19번)이 생기면 채움. 지금은 자리만
function EconomyService.onPpopgi(player, shape, res)
	local data = Data.get(player)
	local last = lastMade[player]
	if not data or not last or not table.find(data.stock, last.item) then
		return nil
	end
	local item = last.item
	if res.broken then
		Data.update(player, function(d)
			local i = table.find(d.stock, item)
			if i then
				table.remove(d.stock, i)
			end
		end)
		lastMade[player] = nil
		EconomyService.notify(player, "뽑다가 쪼개진 달고나는 팔 수 없어요")
		return { price = 0, broken = true }
	end
	local added = 0
	if res.done and (res.extra or 0) > 0 then
		Data.update(player, function(d)
			for _ = 1, res.extra do
				if G.storageRoom(d) <= 0 then
					break
				end
				local copy = table.clone(item)
				copy.id = EconomyService.newItemId(d) -- 덤은 새 번호, 보관함으로 (2026-11-21)
				copy.sl = nil
				copy.pk = false
				copy.gb = nil
				copy.p = G.salePrice(copy.b or copy.p, copy.b and copy.m or 1, G.GachaBonusDefault, false)
				copy.x = true -- 뽑기 덤
				table.insert(d.stock, copy)
				added += 1
			end
		end)
	end
	last.t = os.clock() -- 뽑기 뒤에 포장할 시간
	local dexNew = nil
	if res.perfect and EconomyService.onPerfectPpopgi then
		dexNew = EconomyService.onPerfectPpopgi(player, shape) -- 19번 도감 연결 자리
	end
	return { price = item.p, dexNew = dexNew, extraAdded = added }
end

-- 제작 끝. 반환: 보상 정보 (결과 표에 붙음)
function EconomyService.onMade(player, shape, result)
	-- 민짜 달고나 (D20): 틀을 안 찍었으면 기본값 8, 설탕 Common 1회분
	local plain = result.plain == true
	local need = G.recipe(plain and G.PlainSugarGrade or shape.grade)
	local reward = { exp = G.expFor(result.grade), levelUps = {}, coins = 0 }
	Data.update(player, function(d)
		for id, n in pairs(need) do
			d.ingredients[id] = math.max(0, (d.ingredients[id] or 0) - n)
		end
		if G.storageRoom(d) > 0 then
			local item = {
				id = EconomyService.newItemId(d),
				s = shape.id,
				g = result.grade,
				q = result.Q,
				b = plain and G.PlainBasePrice or shape.price,
				m = result.mult or 1,
				pk = false,
				plain = plain or nil,
			}
			item.p = G.salePrice(item.b, item.m, G.GachaBonusDefault, false)
			table.insert(d.stock, item)
			lastMade[player] = { item = item, t = os.clock() }
			reward.stocked = true
			reward.carryId = item.id
		end
		d.stats.made = (d.stats.made or 0) + 1
		reward.levelUps, reward.coins = EconomyService.addExp(d, reward.exp)
	end)
	EconomyService.announceLevels(player, reward.levelUps)
	-- 다 만든 달고나를 손에 듦 (진열대 빈 칸을 눌러 놓음). 전에 들고 있던 것은 보관함에 남음
	if reward.carryId then
		setCarrying(player, reward.carryId)
	end
	fire("handMade", player, shape, result)
	print(string.format("[Economy] %s made %s %s +%dEXP stock=%d", player.Name, shape.id, result.grade, reward.exp, #(Data.get(player) or { stock = {} }).stock))
	return reward
end

function EconomyService.init(dataService, r)
	Data = dataService
	remotes = r
	Data.Changed:Connect(function(player)
		EconomyService.push(player)
	end)
	remotes.BuyIngredient.OnServerInvoke = EconomyService.buy
	remotes.GetPlayerState.OnServerInvoke = function(player)
		local data = Data.get(player, true)
		return data and fullSnapshot(player, data) or nil
	end
	-- 부지 번호가 정해지면 HUD에도 보이게
	local function watch(player)
		player:GetAttributeChangedSignal("PlotIndex"):Connect(function()
			EconomyService.push(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in ipairs(Players:GetPlayers()) do
		watch(p)
	end
	remotes.PackDalgona.OnServerInvoke = EconomyService.pack
	Players.PlayerRemoving:Connect(function(p)
		lastBuy[p] = nil
		lastMade[p] = nil
		carrying[p] = nil
	end)
end

return EconomyService

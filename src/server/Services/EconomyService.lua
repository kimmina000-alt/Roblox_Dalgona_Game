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
		stock = #data.stock,
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

function EconomyService.push(player)
	local data = Data.get(player)
	if data then
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
	packs = math.clamp(math.floor(tonumber(packs) or 1), 1, 10)
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
	local have = data.ingredients[ing.id] or 0
	if have + ing.pack * packs > G.IngredientMax then
		return { ok = false, reason = ing.name .. " 보관함이 가득 찼어요" }
	end
	if data.coins < cost then
		return { ok = false, reason = "코인이 모자라요" }
	end
	Data.update(player, function(d)
		d.coins -= cost
		d.ingredients[ing.id] = (d.ingredients[ing.id] or 0) + ing.pack * packs
	end)
	return { ok = true }
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
	if #data.stock >= G.stockMax(data) then
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
	return true
end

-- 제작 시작 (세션이 열림): 나무젓가락 1쌍
function EconomyService.onStart(player, _shape)
	Data.update(player, function(d)
		d.ingredients.chopsticks = math.max(0, (d.ingredients.chopsticks or 0) - G.ChopsticksPerRound)
	end)
end

-- 진열대에서 n개 팔기 (앞쪽 = 먼저 만든 것부터). 한 번에 꺼내고 지우므로 같은 달고나가 두 번 팔리지 않음.
-- 반환: 판 개수, 받은 코인
function EconomyService.sell(player, n)
	local sold, coins = 0, 0
	Data.update(player, function(d)
		local shelf = math.min(#d.stock, G.Sales.shelfSlots)
		n = math.min(n, shelf)
		if n <= 0 then
			return false
		end
		for _ = 1, n do
			local item = table.remove(d.stock, 1)
			local p = math.max(0, math.floor(tonumber(item.p) or 0))
			coins += p
			sold += 1
		end
		d.coins += coins
		d.stats.sold = (d.stats.sold or 0) + sold
		d.stats.coinsEarned = (d.stats.coinsEarned or 0) + coins
	end)
	if sold > 0 then
		fire("sold", player, sold, coins)
	end
	return sold, coins
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
	return data and math.min(#data.stock, G.Sales.shelfSlots) or 0
end

-- 뽑기 결과 (15번, ProductionService.hooks.onPpopgi): 방금 만든 달고나 판매가에 뽑기 보너스.
-- 쪼개지면 보관함에서 빠짐 = 못 팖 (2026-11-21 사용자: "뽑기 실패한 건 못 팔게").
-- 순서: 모양 찍기 → 뽑기(선택) → 포장(선택, ×1.1). 반환 { price, dexNew, broken }
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
	Data.update(player, function()
		item.gb = res.bonus
		item.p = G.salePrice(item.b or item.p, item.b and item.m or 1, item.gb, item.pk)
	end)
	last.t = os.clock() -- 뽑기 뒤에 포장할 시간
	local dexNew = nil
	if res.perfect and EconomyService.onPerfectPpopgi then
		dexNew = EconomyService.onPerfectPpopgi(player, shape) -- 19번 도감 연결 자리
	end
	return { price = item.p, dexNew = dexNew }
end

-- 제작 끝. 반환: 보상 정보 (결과 표에 붙음)
function EconomyService.onMade(player, shape, result)
	local need = G.recipe(shape.grade)
	local reward = { exp = G.expFor(result.grade), levelUps = {}, coins = 0 }
	Data.update(player, function(d)
		for id, n in pairs(need) do
			d.ingredients[id] = math.max(0, (d.ingredients[id] or 0) - n)
		end
		if #d.stock < G.stockMax(d) then
			local item = {
				s = shape.id,
				g = result.grade,
				q = result.Q,
				b = shape.price,
				m = result.mult or 1,
				pk = false,
			}
			item.p = G.salePrice(item.b, item.m, G.GachaBonusDefault, false)
			table.insert(d.stock, item)
			lastMade[player] = { item = item, t = os.clock() }
			reward.stocked = true
		end
		d.stats.made = (d.stats.made or 0) + 1
		reward.levelUps, reward.coins = EconomyService.addExp(d, reward.exp)
	end)
	EconomyService.announceLevels(player, reward.levelUps)
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
	end)
end

return EconomyService

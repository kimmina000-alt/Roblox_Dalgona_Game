-- 골목 슈퍼마켓 (D54, 2026-11-25 확정, GDD 15장, 판매 세션). 수치는 GrowthConfig.Market
--   장보기: 슈퍼 계산대 앞(부품 속성 MarketCounter = true, 3D 세션이 슈퍼 안에 넣음)에서 지금 재료 상점 창 그대로
--           (Remotes.BuyIngredient(id, 묶음 1/5/10), EconomyService.buy). 돈은 바로 내고 산 것은 손에 든 장바구니 봉지로
--   봉지: 접속 중에만 있는 값. 내 가게 안에 들어가면 냉장고(설탕·소다)·서랍장(나머지)으로 자동 정리 + 알림.
--         나가거나 접속을 끊으면(PlayerRemoving) 그대로 냉장고로 넣어 줌 (잃어버리지 않게)
--   전화 배달 (Lv10~): Remotes.MarketPhone:InvokeServer(id, 묶음) → 값 ×1.1, 60초 뒤 냉장고·서랍장으로
--   슈퍼 건물이 아직 없으면(MarketCounter 없음) 예전처럼 어디서나 사고 바로 냉장고로 (EconomyService.marketHook = nil)
--
-- 화면 쪽 약속 (UI·3D 세션):
--   플레이어 속성: BagCount(봉지에 든 개수 합, 없으면 nil), BagSize("s"|"m"|"l"|nil = 봉지 크기), DeliveryAt(배달 도착 서버 시각, 없으면 nil)
--   Remotes.MarketPhone:InvokeServer(id, packs) → { ok, reason, amount, cost, at }
--   Remotes.BuyIngredient 결과에 bag = true (봉지에 넣었음)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))

local MarketService = {}

local M = G.Market
local Data, Economy, Plots

local bags = {} -- [player] = { [재료 id] = 개수 }
local deliveries = {} -- [player] = { { id, n, at = 서버 시각 } }
local counter = nil -- 슈퍼 계산대 부품
local ING = {}
for _, ing in ipairs(G.Ingredients) do
	ING[ing.id] = ing
end

local lastScan = -math.huge
local function findCounter()
	if counter and counter.Parent then
		return counter
	end
	counter = nil
	if os.clock() - lastScan < 10 then
		return nil -- 없을 때는 10초마다만 다시 찾음 (부품 전체를 훑으니)
	end
	lastScan = os.clock()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("MarketCounter") == true then
			counter = d
			break
		end
	end
	return counter
end

local function bagTotal(player)
	local n = 0
	for _, v in pairs(bags[player] or {}) do
		n += v
	end
	return n
end

local function setBagAttrs(player)
	local n = bagTotal(player)
	player:SetAttribute("BagCount", n > 0 and n or nil)
	player:SetAttribute("BagSize", n <= 0 and nil or (n < M.bagMid and "s" or (n < M.bagBig and "m" or "l")))
	local first = nil
	for _, dl in ipairs(deliveries[player] or {}) do
		first = first and math.min(first, dl.at) or dl.at
	end
	player:SetAttribute("DeliveryAt", first)
end

-- 봉지·배달 중인 그 재료 개수 (보관 한도 계산에 더함)
local function pending(player, id)
	local n = (bags[player] or {})[id] or 0
	for _, dl in ipairs(deliveries[player] or {}) do
		if dl.id == id then
			n += dl.n
		end
	end
	return n
end

-- 냉장고·서랍장에 넣기. 반환: 넣은 개수
local function store(player, list)
	local moved = 0
	Data.update(player, function(d)
		for id, n in pairs(list) do
			if n > 0 then
				d.ingredients[id] = math.min(G.IngredientMax, (d.ingredients[id] or 0) + n)
				moved += n
			end
		end
	end)
	if moved > 0 then
		Economy.push(player)
	end
	return moved
end

local function storeBag(player, why)
	local bag = bags[player]
	if not bag or next(bag) == nil then
		return
	end
	bags[player] = {}
	local moved = store(player, bag)
	setBagAttrs(player)
	if moved > 0 and why then
		Economy.notify(player, why)
	end
end

-- 내 가게 건물 안에 있나 (부지 기준: 앞선 z -18 안쪽, 폭 ±21)
local function inMyShop(player)
	local plot = Plots.get(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (plot and root and plot.cframe) then
		return false
	end
	local p = plot.cframe:PointToObjectSpace(root.Position)
	return math.abs(p.X) < M.shopHalfWidth and p.Z > M.shopFrontZ and p.Z < M.shopBackZ and p.Y > -5 and p.Y < 30
end

local hook = {
	check = function(player)
		local c = findCounter()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not (c and root) then
			return false, "슈퍼에 가서 사요"
		end
		if (root.Position - c.Position).Magnitude > M.radius then
			return false, "슈퍼 계산대에서 살 수 있어요"
		end
		return true
	end,
	pending = pending,
	toBag = function(player, id, n)
		bags[player] = bags[player] or {}
		bags[player][id] = (bags[player][id] or 0) + n
		setBagAttrs(player)
	end,
}

local lastPhone = {}
local function phone(player, id, packs)
	local ing = ING[id]
	if not ing then
		return { ok = false, reason = "모르는 재료" }
	end
	packs = math.floor(tonumber(packs) or 1)
	if not table.find(G.BuyPacks, packs) then
		return { ok = false, reason = "잘못된 수량" }
	end
	if lastPhone[player] and os.clock() - lastPhone[player] < G.ShopCooldown then
		return { ok = false, reason = "천천히!" }
	end
	lastPhone[player] = os.clock()
	local d = Data.get(player)
	if not d then
		return { ok = false, reason = "불러오는 중이에요" }
	end
	if (d.level or 1) < M.phoneLevel then
		return { ok = false, reason = string.format("전화 배달은 Lv%d부터예요", M.phoneLevel) }
	end
	local n = ing.pack * packs
	local cost = math.ceil(ing.price * packs * M.phoneMult)
	local have = (d.ingredients[id] or 0) + pending(player, id)
	if have + n > G.IngredientMax then
		return { ok = false, reason = string.format("%s은(는) %d개까지 보관해요 (지금 %d개)", ing.name, G.IngredientMax, have) }
	end
	if d.coins < cost then
		return { ok = false, reason = string.format("코인이 모자라요 (%d코인 필요)", cost) }
	end
	Data.update(player, function(dd)
		dd.coins -= cost
	end)
	local at = workspace:GetServerTimeNow() + M.phoneDelay
	deliveries[player] = deliveries[player] or {}
	table.insert(deliveries[player], { id = id, n = n, at = at })
	setBagAttrs(player)
	Economy.push(player)
	return { ok = true, amount = n, cost = cost, at = at }
end

local function tick(player)
	-- 가게에 들어가면 봉지 정리
	if bagTotal(player) > 0 and inMyShop(player) then
		storeBag(player, "장 본 재료를 냉장고·서랍장에 넣었어요")
	end
	-- 배달 도착
	local list = deliveries[player]
	if list and #list > 0 then
		local now = workspace:GetServerTimeNow()
		local due = {}
		for k = #list, 1, -1 do
			local dl = list[k]
			if now >= dl.at then
				due[dl.id] = (due[dl.id] or 0) + dl.n
				table.remove(list, k)
			end
		end
		if next(due) then
			store(player, due)
			setBagAttrs(player)
			Economy.notify(player, "배달 왔어요! 냉장고·서랍장에 넣었어요")
		end
	end
end

function MarketService.init(dataService, economyService, plotService)
	Data, Economy, Plots = dataService, economyService, plotService
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local fn = remotes:FindFirstChild("MarketPhone")
	if not fn then
		fn = Instance.new("RemoteFunction")
		fn.Name = "MarketPhone"
		fn.Parent = remotes
	end
	fn.OnServerInvoke = phone
	Players.PlayerRemoving:Connect(function(p)
		-- 봉지·배달 중인 것은 잃어버리지 않게 바로 냉장고로 (저장 전에)
		local all = bags[p] or {}
		for _, dl in ipairs(deliveries[p] or {}) do
			all[dl.id] = (all[dl.id] or 0) + dl.n
		end
		if next(all) then
			pcall(store, p, all)
		end
		bags[p], deliveries[p], lastPhone[p] = nil, nil, nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			-- 슈퍼 건물이 있을 때만 슈퍼에서 사기 (없으면 예전처럼 바로 냉장고로)
			Economy.marketHook = findCounter() and hook or nil
			for _, p in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(tick, p)
				if not ok then
					warn("[Market]", err)
				end
			end
		end
	end)
end

return MarketService

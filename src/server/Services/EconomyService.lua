-- 코인·재료·재고·EXP (Phase 2, 2026-11-20)
--  - 재료 상점: 묶음 구매 (GrowthConfig.Ingredients)
--  - 제작 시작 전: 재료·재고 자리 확인 (ProductionService.hooks.canStart)
--  - 제작 끝 (서버 판정 결과): 재료 쓰고 재고에 달고나 1개, EXP·레벨업 코인 (hooks.onResult)
--  - HUD로 상태를 보냄 (Remotes.PlayerState), 짧은 알림 (Remotes.Notify)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("GrowthConfig"))

local EconomyService = {}

local Data = nil -- PlayerDataService
local remotes = nil
local lastBuy = {} -- [player] = os.clock()

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
		ingredients = {
			sugar = data.ingredients.sugar or 0,
			soda = data.ingredients.soda or 0,
			wrapper = data.ingredients.wrapper or 0,
		},
		stock = #data.stock,
		stockMax = G.StockMax,
		plot = player:GetAttribute("PlotIndex"),
		saving = Data.canSave(player),
	}
end

function EconomyService.push(player)
	local data = Data.get(player)
	if data and remotes then
		remotes.PlayerState:FireClient(player, snapshot(player, data))
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
	if #data.stock >= G.StockMax then
		return false, string.format("달고나 보관함이 가득 찼어요 (%d개)", G.StockMax)
	end
	local need = G.recipe(shape.grade)
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

-- 제작 끝. 반환: 보상 정보 (결과 표에 붙음)
function EconomyService.onMade(player, shape, result)
	local need = G.recipe(shape.grade)
	local reward = { exp = G.expFor(result.grade), levelUps = {}, coins = 0 }
	Data.update(player, function(d)
		for id, n in pairs(need) do
			d.ingredients[id] = math.max(0, (d.ingredients[id] or 0) - n)
		end
		if #d.stock < G.StockMax then
			table.insert(d.stock, { s = shape.id, g = result.grade, q = result.Q, p = result.price })
			reward.stocked = true
		end
		d.stats.made = (d.stats.made or 0) + 1
		d.exp += reward.exp
		while d.level < G.MaxLevel and d.exp >= G.expToNext(d.level) do
			d.exp -= G.expToNext(d.level)
			d.level += 1
			local c = G.LevelCoins[d.level] or 0
			d.coins += c
			reward.coins += c
			table.insert(reward.levelUps, d.level)
		end
	end)
	for _, lv in ipairs(reward.levelUps) do
		EconomyService.notify(player, string.format("레벨 업! Lv%d (+%d 코인)", lv, G.LevelCoins[lv] or 0))
	end
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
		return data and snapshot(player, data) or nil
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
	Players.PlayerRemoving:Connect(function(p)
		lastBuy[p] = nil
	end)
end

return EconomyService

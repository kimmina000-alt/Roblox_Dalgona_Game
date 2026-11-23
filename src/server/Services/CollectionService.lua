-- 도감 보상·칭호 (D38, 2026-11-24 확정, 판매 세션). 기준: GDD 14장 D38. 꾸미기 보상(포장지·인형)은 뺌
--
-- 도안 도감 (손으로 만든 것만, 민짜는 안 셈 — D20): 저장 collection[도안 id] = { best, n, pp(완벽 뽑기), ex(처음 Excellent 보상 받음), pf(처음 Perfect = 금별) }
--   처음 만듦 EXP 20 / 처음 Excellent 코인 = 도안 가격 × 5 / 처음 Perfect 코인 = 가격 × 10 + 금별 / 완벽 뽑기 EXP 30 + 도장
--   한 등급 도안 모두 Perfect → 칭호 "<등급> 장인", 23종 모두 Perfect → 칭호 "달고나 장인" + 간판 금테 (부지 모델 속성 SignGold)
-- 손님 도감: 저장 custDex[손님 id] = { sold = 판 수, h = 받은 하트 보상 0~3 } (있으면 만난 것)
--   처음 만남 30코인 / 하트1(10개) EXP 50 / 하트2(50개) 좋아하는 도안 공개 + 300코인 / 하트3(150개) 칭호 "<이름>네 단골집"
--   7종 모두 하트3 → 칭호 "골목 인기 가게"
-- 칭호: 저장 titles = { owned = { 이름... }, equipped = 이름 | nil }
--
-- 화면 약속 (UI 세션 CollectionUi.client.lua 맨 위 주석):
--   PlayerState.collection = { shapes = { [id] = { made, excellent, perfect, ppopgi } },
--     customers = { [id] = { met, sold, hearts, favorite(하트2부터, 단골 둘만), tip(하트2 팁, 나머지 5종) } }, titles = { owned, equipped } }
--   Remotes.CollectionReward (서버 → 클라) { title, text, reward, icon }
--   Remotes.CollectionAction:InvokeServer("equipTitle", 이름 | "") → { ok, reason }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("GrowthConfig"))
local ShapeCatalog = require(Shared:WaitForChild("ShapeCatalog"))

local CollectionService = {}

local Data, Economy, Plots = nil, nil, nil
local rewardEvent = nil

local R = G.Collection

local function customerName(id)
	local t = G.customerType(id)
	return t and t.name or id
end

local function notify(player, info)
	if rewardEvent then
		rewardEvent:FireClient(player, info)
	end
end

-- 칭호 얻기 (데이터만). 반환 = 새로 얻었나
local function grantTitle(d, name)
	d.titles = type(d.titles) == "table" and d.titles or { owned = {} }
	d.titles.owned = d.titles.owned or {}
	if table.find(d.titles.owned, name) then
		return false
	end
	table.insert(d.titles.owned, name)
	return true
end

-- 도안 칭호 확인 (등급마다 장인, 23종 달고나 장인). 반환 = 새 칭호 목록, 간판 금테 새로 얻었나
local function checkShapeTitles(d)
	local new, gold = {}, false
	local allPerfect = true
	for _, g in ipairs(ShapeCatalog.Grades) do
		local any, all = false, true
		for _, e in ipairs(ShapeCatalog.list) do
			if e.grade == g.id then
				any = true
				local c = d.collection[e.id]
				if not (c and c.pf) then
					all = false
					allPerfect = false
				end
			end
		end
		if any and all and grantTitle(d, g.label .. " 장인") then
			table.insert(new, g.label .. " 장인")
		end
	end
	if allPerfect and grantTitle(d, R.masterTitle) then
		table.insert(new, R.masterTitle)
		d.signGold = true
		gold = true
	end
	return new, gold
end

local function checkCustomerTitles(d)
	local new = {}
	local all = true
	for _, t in ipairs(G.Customers.types) do
		local c = d.custDex and d.custDex[t.id]
		if not (c and (c.h or 0) >= 3) then
			all = false
		end
	end
	if all and grantTitle(d, R.streetTitle) then
		table.insert(new, R.streetTitle)
	end
	return new
end

local function publishSign(player, d)
	local _, i = Plots.get(player)
	local plot = i and Plots.plotAt(i)
	if plot and plot.model:GetAttribute("SignGold") ~= (d.signGold == true) then
		plot.model:SetAttribute("SignGold", d.signGold == true) -- 간판 금테 (3D는 제작·3D 세션)
	end
	local equipped = d.titles and d.titles.equipped or ""
	if player:GetAttribute("Title") ~= equipped then
		player:SetAttribute("Title", equipped) -- 머리 위·간판에 칭호 (화면 쪽)
	end
end

local function sendTitles(player, list)
	for _, name in ipairs(list) do
		notify(player, { title = "칭호 획득!", text = name, reward = "칭호", icon = "🏅" })
	end
end

---------------------------------------------------------------- 도안

-- 손으로 만든 한 판 (GrowthService.onHandMade 안, Data.update 안에서 부름). shape = ShapeCatalog 항목, result = 판정.
-- 반환: 알림 목록, 레벨업 목록, 새 칭호 목록, 금테 새로
function CollectionService.onMade(d, shape, result)
	local notes, ups = {}, {}
	if result.plain then
		return notes, ups, {}, false -- 민짜는 도감에 안 셈 (D20)
	end
	local rank = G.GradeRank[result.grade] or 0
	local c = d.collection[shape.id]
	if not c then
		c = { best = result.grade, n = 0 }
		d.collection[shape.id] = c
		for _, u in ipairs(Economy.addExp(d, R.firstMadeExp)) do
			table.insert(ups, u)
		end
		table.insert(notes, { title = "도감 등록!", text = shape.name .. " · 처음 만듦", reward = "+" .. R.firstMadeExp .. " EXP", icon = "📖" })
	end
	c.n = (c.n or 0) + 1
	if rank > (G.GradeRank[c.best] or 0) then
		c.best = result.grade
	end
	local price = tonumber(shape.price) or 0
	if rank >= (G.GradeRank.Excellent or 99) and not c.ex then
		c.ex = true
		local coins = price * R.excellentMult
		d.coins += coins
		table.insert(notes, { title = "도감 갱신!", text = shape.name .. " · 처음 Excellent", reward = "+" .. coins .. " 코인", icon = "✨" })
	end
	local newTitles, gold = {}, false
	if result.grade == "Perfect" and not c.pf then
		c.pf = true
		local coins = price * R.perfectMult
		d.coins += coins
		table.insert(notes, { title = "금별!", text = shape.name .. " · 처음 Perfect", reward = "+" .. coins .. " 코인", icon = "⭐" })
		newTitles, gold = checkShapeTitles(d)
	end
	return notes, ups, newTitles, gold
end

-- 완벽 뽑기 (EconomyService.onPerfectPpopgi). 반환 = 처음이면 true (결과창 "도감 등록!")
function CollectionService.onPerfectPpopgi(player, shape)
	if type(shape) ~= "table" or type(shape.id) ~= "string" then
		return false
	end
	local first, ups = false, {}
	Data.update(player, function(d)
		local c = d.collection[shape.id]
		if not c then
			c = { best = "Poor", n = 0 }
			d.collection[shape.id] = c
		end
		if c.pp then
			return false
		end
		c.pp = true
		first = true
		ups = Economy.addExp(d, R.ppopgiExp)
	end)
	if first then
		Economy.announceLevels(player, ups)
		notify(player, { title = "도장 쾅!", text = (shape.name or shape.id) .. " · 완벽 뽑기", reward = "+" .. R.ppopgiExp .. " EXP", icon = "💮" })
	end
	return first
end

---------------------------------------------------------------- 손님

-- 손님이 가게에 왔을 때 (SalesService). 처음이면 30코인
function CollectionService.onCustomerMet(player, id)
	local first = false
	Data.update(player, function(d)
		d.custDex = type(d.custDex) == "table" and d.custDex or {}
		if d.custDex[id] then
			return false
		end
		d.custDex[id] = { sold = 0, h = 0 }
		d.coins += R.meetCoins
		first = true
	end)
	if first then
		notify(player, { title = "새 손님!", text = customerName(id) .. " · 처음 만남", reward = "+" .. R.meetCoins .. " 코인", icon = "👋" })
	end
end

-- 손님이 n개 샀을 때 (SalesService). 하트 보상
function CollectionService.onCustomerSold(player, id, n)
	local notes, ups, titles = {}, {}, {}
	Data.update(player, function(d)
		d.custDex = type(d.custDex) == "table" and d.custDex or {}
		local c = d.custDex[id]
		if not c then
			c = { sold = 0, h = 0 }
			d.custDex[id] = c
		end
		c.sold = (c.sold or 0) + n
		local name = customerName(id)
		while (c.h or 0) < 3 and c.sold >= R.hearts[(c.h or 0) + 1] do
			c.h = (c.h or 0) + 1
			if c.h == 1 then
				for _, u in ipairs(Economy.addExp(d, R.heart1Exp)) do
					table.insert(ups, u)
				end
				table.insert(notes, { title = "하트 1", text = name .. " · " .. R.hearts[1] .. "개 판매", reward = "+" .. R.heart1Exp .. " EXP", icon = "💗" })
			elseif c.h == 2 then
				d.coins += R.heart2Coins
				local ct = G.customerType(id)
				if ct and ct.kind == "regular" then
					-- 단골 둘: 좋아하는 도안 공개
					local fav = d.custFav and d.custFav[id]
					local favName = fav and ShapeCatalog.get(fav) and ShapeCatalog.get(fav).name or nil
					table.insert(notes, { title = "하트 2", text = name .. (favName and (" · 좋아하는 도안: " .. favName) or ""), reward = "+" .. R.heart2Coins .. " 코인", icon = "💞" })
				else
					-- 나머지 5종: 이제부터 그 손님 팁 +5% (G.heartTip)
					table.insert(notes, { title = "하트 2", text = name .. " · 우리 가게 단골이 됐어요", reward = "+" .. R.heart2Coins .. " 코인 · 팁 +" .. math.floor(R.heart2Tip * 100 + 0.5) .. "%", icon = "💞" })
				end
			else
				local t = name .. "네 단골집"
				if grantTitle(d, t) then
					table.insert(titles, t)
				end
				table.insert(notes, { title = "하트 3", text = name .. " · " .. R.hearts[3] .. "개 판매", reward = "칭호 " .. t, icon = "💖" })
				for _, x in ipairs(checkCustomerTitles(d)) do
					table.insert(titles, x)
				end
			end
		end
	end)
	Economy.announceLevels(player, ups)
	for _, info in ipairs(notes) do
		notify(player, info)
	end
	sendTitles(player, titles)
end

---------------------------------------------------------------- 화면

function CollectionService.snapshot(d)
	local shapes = {}
	for id, c in pairs(d.collection or {}) do
		if type(c) == "table" and ((c.n or 0) > 0 or c.pp) then
			local rank = G.GradeRank[c.best] or 0
			shapes[id] = {
				made = (c.n or 0) > 0,
				excellent = c.ex == true or rank >= (G.GradeRank.Excellent or 99),
				perfect = c.pf == true,
				ppopgi = c.pp == true,
				best = c.best,
				n = c.n or 0,
			}
		end
	end
	local customers = {}
	for id, c in pairs(d.custDex or {}) do
		local hearts = c.h or 0
		customers[id] = {
			met = true,
			sold = c.sold or 0,
			hearts = hearts,
			favorite = hearts >= 2 and d.custFav and d.custFav[id] or nil, -- 하트 2부터 공개 (단골 둘만 있음)
			tip = G.heartTip(d, G.customerType(id)), -- 하트 2 팁 (단골이 아닌 5종, 0 또는 0.05)
		}
	end
	local titles = d.titles or {}
	return {
		shapes = shapes,
		customers = customers,
		titles = { owned = table.clone(titles.owned or {}), equipped = titles.equipped },
		signGold = d.signGold == true,
	}
end

-- 칭호 달기 (Remotes.CollectionAction)
local function onAction(player, what, name)
	if what ~= "equipTitle" then
		return { ok = false, reason = "잘못된 요청" }
	end
	local d = Data.get(player)
	if not d then
		return { ok = false, reason = "불러오는 중이에요" }
	end
	if type(name) ~= "string" then
		return { ok = false, reason = "잘못된 요청" }
	end
	local ok, why = true, nil
	Data.update(player, function(dd)
		dd.titles = type(dd.titles) == "table" and dd.titles or { owned = {} }
		if name == "" then
			dd.titles.equipped = nil
		elseif table.find(dd.titles.owned or {}, name) then
			dd.titles.equipped = name
		else
			ok, why = false, "아직 없는 칭호예요"
			return false
		end
	end)
	publishSign(player, Data.get(player))
	return { ok = ok, reason = why }
end

-- 처음 Perfect 등으로 바뀐 뒤 (GrowthService.onHandMade, Data.update 밖)
function CollectionService.after(player, notes, newTitles, gold)
	for _, info in ipairs(notes or {}) do
		notify(player, info)
	end
	sendTitles(player, newTitles or {})
	if gold then
		notify(player, { title = "간판 금테!", text = "도안 23종 모두 Perfect", reward = "가게 간판 금테", icon = "🏆" })
	end
	local d = Data.get(player)
	if d then
		publishSign(player, d)
	end
end

function CollectionService.init(dataService, economyService, plotService, remotes)
	Data, Economy, Plots = dataService, economyService, plotService
	rewardEvent = remotes:FindFirstChild("CollectionReward")
	if not rewardEvent then
		rewardEvent = Instance.new("RemoteEvent")
		rewardEvent.Name = "CollectionReward"
		rewardEvent.Parent = remotes
	end
	local action = remotes:FindFirstChild("CollectionAction")
	if not action then
		action = Instance.new("RemoteFunction")
		action.Name = "CollectionAction"
		action.Parent = remotes
	end
	action.OnServerInvoke = onAction
	Economy.onPerfectPpopgi = CollectionService.onPerfectPpopgi
	-- 간판 금테·칭호 신호 (접속·데이터가 바뀔 때)
	Data.Changed:Connect(function(player)
		local d = Data.get(player)
		if d then
			publishSign(player, d)
		end
	end)
end

return CollectionService

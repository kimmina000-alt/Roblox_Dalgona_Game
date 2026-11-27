-- 골목 슈퍼·문방구 선반 재고와 눌러서 사기 (2026-11-28 사용자, 수치·근거는 GrowthConfig.ShelfShop)
--   선반 물건 = Workspace.Alley 안 속성 ItemId가 있는 부품 (AlleyBuilder가 놓음):
--     슈퍼 봉지 ItemId = "sugar" | "soda" (AlleyMarket.Building.Mk_Goods.Bag) → EconomyService.shelfBuy (1팩, 봉지에 담김)
--     문방구 모양틀 ItemId = "cutter", 속성 ShapeId (AlleyStationery.St_Goods.Cutter_<id>) → 아직 안 열린 도안을 미리 삼
--   재고는 서버 공용: 물건 하나 = 재고 하나. 사면 그 물건이 안 보이고(속성 InStock = false) 못 누름. restockSeconds마다 빈 자리를 다 채움.
--   누르기 = 물건마다 ClickDetector (컴퓨터 마우스·폰 터치 둘 다). 가까이(clickDistance) 있어야 눌림, 서버에서도 거리를 다시 확인.
--   화면에 보이는 것: 물건에 마우스를 올리면 이름·값 (ClickDetector 커서), 사면 알림(Remotes.Notify)
--   Workspace.Alley 속성 ShelfRestockAt = 다음 채우는 서버 시각 (workspace:GetServerTimeNow 기준)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GrowthConfig"))
local ShapeCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShapeCatalog"))

local ShelfShop = {}

local C = G.ShelfShop or { restockSeconds = 300, clickDistance = 12, levelAhead = 2, cutterPrice = {} }
local Data, Economy
local items = {} -- 선반 물건 부품 목록
local busy = {} -- [player] = true (한 번에 하나씩)

local ING = {}
for _, ing in ipairs(G.Ingredients) do
	ING[ing.id] = ing
end

local function notify(player, text)
	if Economy and Economy.notify then
		Economy.notify(player, text)
	end
end

local function setStock(p, inStock)
	p:SetAttribute("InStock", inStock)
	if p:GetAttribute("ShownTransparency") == nil then
		p:SetAttribute("ShownTransparency", p.Transparency)
	end
	p.Transparency = inStock and p:GetAttribute("ShownTransparency") or 1
	local cd = p:FindFirstChildOfClass("ClickDetector")
	if cd then
		cd.MaxActivationDistance = inStock and C.clickDistance or 0
	end
end

local function cutterPrice(entry)
	return entry and C.cutterPrice[entry.grade] or nil
end

-- 모양틀 미리 사기
local function buyCutter(player, p)
	local id = p:GetAttribute("ShapeId")
	local entry = id and ShapeCatalog.get(id)
	local d = Data.get(player)
	if not (entry and d) then
		return false
	end
	if table.find(d.unlockedShapes, id) then
		notify(player, entry.name .. " 모양틀은 벌써 있어요")
		return false
	end
	local need = G.UnlockLevel[entry.grade]
	local price = cutterPrice(entry)
	if not (need and price) then
		notify(player, entry.name .. " 모양틀은 도감을 채우면 열려요")
		return false
	end
	local from = math.max(1, need - (C.levelAhead or 0))
	if (d.level or 1) < from then
		notify(player, string.format("%s 모양틀은 Lv%d부터 살 수 있어요 (Lv%d에 저절로 열려요)", entry.name, from, need))
		return false
	end
	if d.coins < price then
		notify(player, string.format("코인이 모자라요 (%d코인 필요)", price))
		return false
	end
	Data.update(player, function(dd)
		dd.coins -= price
		table.insert(dd.unlockedShapes, id)
	end)
	player:SetAttribute("UnlockedShapes", table.concat(Data.get(player).unlockedShapes, ","))
	notify(player, string.format("%s 모양틀을 샀어요! (-%d코인)", entry.name, price))
	return true
end

local function onClick(player, p)
	if busy[player] or p:GetAttribute("InStock") == false then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - p.Position).Magnitude > C.clickDistance + 4 then
		return
	end
	busy[player] = true
	local ok = false
	local item = p:GetAttribute("ItemId")
	if item == "cutter" then
		ok = buyCutter(player, p)
	elseif ING[item] then
		local r = Economy.shelfBuy(player, item)
		ok = r and r.ok
		if ok then
			notify(player, string.format("%s %d개를 봉지에 담았어요 (-%d코인)", ING[item].name, r.amount, r.cost))
		elseif r and r.reason then
			notify(player, r.reason)
		end
	end
	if ok then
		setStock(p, false)
	end
	busy[player] = nil
end

local function hook(p)
	if p:GetAttribute("ShelfHooked") then
		return
	end
	p:SetAttribute("ShelfHooked", true)
	table.insert(items, p)
	p.CanQuery = true -- 눌리려면 광선에 맞아야 함
	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = C.clickDistance
	cd.CursorIcon = ""
	cd.Parent = p
	cd.MouseClick:Connect(function(player)
		onClick(player, p)
	end)
	-- 마우스를 올리면 보이는 이름 (ClickDetector는 이름을 못 띄워서 부품 속성으로 남김: 클라이언트가 쓰고 싶으면)
	local item = p:GetAttribute("ItemId")
	if item == "cutter" then
		local entry = ShapeCatalog.get(p:GetAttribute("ShapeId") or "")
		p:SetAttribute("ShelfLabel", entry and string.format("%s 모양틀 · %s", entry.name, cutterPrice(entry) and (cutterPrice(entry) .. "코인") or "도감 보상"))
	elseif ING[item] then
		p:SetAttribute("ShelfLabel", string.format("%s %d개 · %d코인", ING[item].name, ING[item].pack, ING[item].price))
	end
	setStock(p, true)
end

local function scan()
	local alley = workspace:FindFirstChild("Alley")
	if not alley then
		return 0
	end
	for _, d in ipairs(alley:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("ItemId") then
			hook(d)
		end
	end
	return #items
end

local function restock()
	local n = 0
	for _, p in ipairs(items) do
		if p.Parent and p:GetAttribute("InStock") == false then
			setStock(p, true)
			n += 1
		end
	end
	return n
end

function ShelfShop.init(dataService, economyService)
	Data, Economy = dataService, economyService
	local n = scan()
	print(string.format("[ShelfShop] 선반 물건 %d개, %d초마다 채움", n, C.restockSeconds))
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
	task.spawn(function()
		while true do
			local alley = workspace:FindFirstChild("Alley")
			if alley then
				alley:SetAttribute("ShelfRestockAt", workspace:GetServerTimeNow() + C.restockSeconds)
			end
			task.wait(C.restockSeconds)
			restock()
		end
	end)
end

return ShelfShop

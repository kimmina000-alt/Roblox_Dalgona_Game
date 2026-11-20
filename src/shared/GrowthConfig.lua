-- 저장·가게 부지·재료·레벨 수치 (Phase 2, 2026-11-20)
-- 서버와 클라이언트가 같이 쓴다. 숫자는 여기서만 고친다.
-- 기준: GAME_DESIGN_DOCUMENT.md 6·7장 (D4 원가), ECONOMY_BALANCE.md 2장, SHOP_GROWTH_PLAN.md 1~2장

local G = {}

---------------------------------------------------------------- 저장
G.Save = {
	storeName = "DalgonaPlayer_v1", -- DataStore 이름 (바꾸면 모든 저장이 새로 시작됨)
	autosaveSeconds = 60,
	retries = 4, -- 저장/불러오기 실패 시 다시 시도 횟수
	retryDelay = 2, -- 첫 재시도 대기(초), 매번 2배
	lockStaleSeconds = 180, -- 다른 서버의 잠금이 이 시간보다 오래되면 죽은 서버로 보고 가져옴
	loadWaitSeconds = 8, -- 다른 서버가 잠금을 쥐고 있을 때 기다리는 최대 시간
	closeTimeout = 25, -- BindToClose에서 기다리는 최대 시간
}

-- 스키마 버전. 데이터 모양을 바꾸면 올리고 PlayerDataService.MIGRATIONS[새 버전]에 옮기는 함수를 넣는다.
G.SchemaVersion = 1

-- 새 플레이어 기본 데이터 (빠진 칸은 불러올 때 여기서 채움)
G.DefaultData = {
	coins = 100, -- 시작 자금 (ECONOMY_BALANCE 6장 "시작 자금 100")
	exp = 0,
	level = 1,
	ingredients = { sugar = 5, soda = 5, wrapper = 5 }, -- 첫 판을 바로 해 볼 수 있게 5회분
	stock = {}, -- 만든 달고나 { s = 도안 id, g = 등급, q = 완성도, p = 판매가 } (판매는 Phase 3)
	unlockedShapes = { "Circle", "Square", "Triangle", "Star" },
	upgrades = { stove = 0, presser = 0, table = 0 }, -- 화로·누르개·작업대 장비 Lv (Phase 4)
	ladles = 1, -- 국자 수 1~4 (SHOP_GROWTH_PLAN 2장)
	partTimers = {}, -- 알바생 { { id, skill } } (Phase 4)
	machineStage = 1, -- 설비 단계 1 연탄 화로 ~ 5 공장 (SHOP_GROWTH_PLAN 1장)
	factory = { unlocked = false }, -- 가게 뒤 공장 (D11, Phase 5)
	stats = { made = 0, sold = 0, coinsEarned = 0 },
}

---------------------------------------------------------------- 재료 (ECONOMY_BALANCE 2장)
G.Ingredients = {
	{ id = "sugar", name = "설탕", icon = "🍚", pack = 10, price = 30 },
	{ id = "soda", name = "소다", icon = "🧂", pack = 10, price = 10 },
	{ id = "wrapper", name = "포장지", icon = "🛍️", pack = 10, price = 10 },
}
G.IngredientMax = 999 -- 재료마다 최대 보관량

-- 1개당 재료 (D4): 설탕은 도안 등급에 따라 1/2/3회분 → 원가 5/8/11. 소다·포장지 1개씩.
G.SugarByGrade = {
	Common = 1, Uncommon = 1,
	Rare = 2, Epic = 2,
	Legendary = 3, Mythic = 3, Master = 3,
}
G.FactoryExtraCost = 1 -- 공장 운영비 +1 (D4, Phase 5에서 씀)

function G.recipe(shapeGrade)
	return { sugar = G.SugarByGrade[shapeGrade] or 1, soda = 1, wrapper = 1 }
end

G.StockMax = 30 -- 들고 있을 수 있는 달고나 수 (진열대 10칸은 Phase 3)
G.EnforceUnlocks = false -- true면 해금 안 된 도안은 서버가 거절 (Phase 4에서 켬)

---------------------------------------------------------------- 레벨 (GDD 6장)
G.MaxLevel = 25
-- Lv n → n+1 요구 EXP. Lv1~10은 GDD 값, 그 뒤는 임시로 +110씩 (테스트 뒤 정함)
G.ExpToNext = { 50, 80, 120, 170, 230, 300, 380, 470, 570 }
-- 레벨업 보상 코인 (도달 레벨 → 코인)
G.LevelCoins = {
	[2] = 100, [3] = 50, [4] = 150, [5] = 200, [6] = 250, [7] = 300,
	[8] = 200, [9] = 275, [10] = 350,
	[11] = 500, [12] = 500, [13] = 500, [14] = 500, [15] = 700,
	[16] = 1000, [17] = 1000, [18] = 1000, [19] = 1000, [20] = 1000,
}
G.ExpHand = { base = 10, Excellent = 10, Perfect = 20 } -- 손 제작 성공 EXP + 등급 보너스
G.ExpBurnt = 2 -- 태워도 조금은 배움

function G.expToNext(level)
	if level >= G.MaxLevel then
		return math.huge
	end
	return G.ExpToNext[level] or (570 + (level - 9) * 110)
end

function G.expFor(grade)
	if grade == "Burnt" then
		return G.ExpBurnt
	end
	return G.ExpHand.base + (G.ExpHand[grade] or 0)
end

---------------------------------------------------------------- 가게 부지 (D10·D11)
G.Plots = {
	count = 6,
	size = Vector3.new(36, 0.4, 36),
	-- 부지 중심: 스폰 뒤쪽(-Z) 골목 한 줄. 앞(간판)이 +Z(스폰 쪽)를 봄
	rowZ = -72,
	spacing = 40,
	-- 부지 안 자리 (부지 기준 로컬 좌표, -Z = 앞/골목 쪽)
	handStation = { pos = Vector3.new(-6, 0, -4), size = Vector3.new(22, 0.2, 7) }, -- 손 작업대 (작업대 테이블 크기)
	machineSlot = { pos = Vector3.new(11, 0, 6), size = Vector3.new(9, 0.2, 9) }, -- 기계 1자리 (D10)
	factoryDoor = { pos = Vector3.new(0, 0, 17.5) }, -- 가게 뒤 공장 문 (D11, 지금은 자리만)
	sign = { pos = Vector3.new(0, 0, -17.5), height = 9 },
	teleportOnSpawn = false, -- 손 작업대를 부지로 옮기기 전까지는 스폰 그대로 (작업대가 하나뿐)
}

---------------------------------------------------------------- 상점·요청 제한
G.ShopCooldown = 0.25 -- 초당 4번까지 구매

return G

-- 저장·가게 부지·재료·레벨 수치 (Phase 2, 2026-11-20)
-- 서버와 클라이언트가 같이 쓴다. 숫자는 여기서만 고친다.
-- 기준: GAME_DESIGN_DOCUMENT.md 6·7장 (D4 원가), ECONOMY_BALANCE.md 2장, SHOP_GROWTH_PLAN.md 1~2장

local G = {}

---------------------------------------------------------------- 저장
G.Save = {
	storeName = "DalgonaPlayer_v1", -- DataStore 이름 (바꾸면 모든 저장이 새로 시작됨)
	autosaveSeconds = 60,
	changeSaveSeconds = 15, -- 코인·재료·재고가 바뀌면 이만큼 뒤 한 번 더 저장 (서버가 갑자기 꺼져도 잃는 양을 줄임)
	retries = 4, -- 저장/불러오기 실패 시 다시 시도 횟수
	retryDelay = 2, -- 첫 재시도 대기(초), 매번 2배
	lockStaleSeconds = 180, -- 다른 서버의 잠금이 이 시간보다 오래되면 죽은 서버로 보고 가져옴
	loadWaitSeconds = 8, -- 다른 서버가 잠금을 쥐고 있을 때 기다리는 최대 시간
	closeTimeout = 25, -- BindToClose에서 기다리는 최대 시간
}

-- 스키마 버전. 데이터 모양을 바꾸면 올리고 PlayerDataService.MIGRATIONS[새 버전]에 옮기는 함수를 넣는다.
G.SchemaVersion = 3 -- v2 (2026-11-20 성장): 해금·도감·일일 목표·알바생 / v3 (2026-11-21 D21): 노점 → 월세 가게

-- 새 플레이어 기본 데이터 (빠진 칸은 불러올 때 여기서 채움)
G.DefaultData = {
	coins = 100, -- 시작 자금 (ECONOMY_BALANCE 6장 "시작 자금 100")
	exp = 0,
	level = 1,
	ingredients = { sugar = 5, soda = 5, wrapper = 5, chopsticks = 5, twistTie = 5 }, -- 첫 판을 바로 해 볼 수 있게 5회분 (사용자 확정, 2026-11-20)
	stock = {}, -- 만든 달고나 { s = 도안 id, g = 등급, q = 완성도, p = 판매가, b = 도안 가격, m = 품질 배율, pk = 포장 여부 }
	unlockedShapes = { "Circle", "Square", "Triangle", "Bone" }, -- Common (레벨이 오르면 GrowthService가 더함)
	upgrades = { stove = 0, presser = 0, table = 0 }, -- 화로·누르개·작업대 장비 Lv (Phase 4)
	ladles = 1, -- 국자 수 1~4 (SHOP_GROWTH_PLAN 2장)
	partTimers = {}, -- 알바생 { { shape = 만들 도안 id, skill = 숙련(자리만) } } 국자 2번째부터 1명씩
	machineStage = 1, -- 설비 단계 1 연탄 화로 ~ 5 공장 (SHOP_GROWTH_PLAN 1장)
	factory = { unlocked = false }, -- 가게 뒤 공장 (D11, Phase 5)
	-- 가게 (D21): state = "stall"(야외 노점) | "rented"(월세) | "owned"(매입). rentTimer = 지난 월세 뒤 접속한 초, closed = 월세 못 내 문 닫힘
	shop = { state = "stall", rentTimer = 0, closed = false },
	stats = { made = 0, sold = 0, coinsEarned = 0, helperMade = 0, wagesPaid = 0 },
	collection = {}, -- 도감 [도안 id] = { best = 손으로 만든 최고 등급, n = 손으로 만든 수 } (자동 생산은 안 셈)
	daily = { day = "", goals = {} }, -- 일일 목표 3개 (UTC 날짜가 바뀌면 새로)
}

---------------------------------------------------------------- 재료 (ECONOMY_BALANCE 2장)
G.Ingredients = {
	{ id = "sugar", name = "설탕", icon = "🍚", pack = 10, price = 30 },
	{ id = "soda", name = "소다", icon = "🧂", pack = 10, price = 10 },
	{ id = "wrapper", name = "포장지", icon = "🛍️", pack = 10, price = 10 },
	{ id = "chopsticks", name = "나무젓가락", icon = "🥢", pack = 10, price = 5 }, -- 10쌍 5코인 (GDD 7장, 2026-11-20)
	{ id = "twistTie", name = "빵끈", icon = "🎀", pack = 10, price = 5 }, -- 10개 5코인 (사용자 요청 2026-11-20, 임시값)
}
G.IngredientMax = 999 -- 재료마다 최대 보관량

-- 1개당 재료 (D4): 설탕은 도안 등급에 따라 1/2/3회분, 소다 1. 포장지·빵끈은 포장할 때만 (사용자 확정 2026-11-20)
G.SugarByGrade = {
	Common = 1, Uncommon = 1,
	Rare = 2, Epic = 2,
	Legendary = 3, Mythic = 3, Master = 3,
}
G.FactoryExtraCost = 1 -- 공장 운영비 +1 (D4, Phase 5에서 씀)

-- 다 만든 뒤(서버 판정) 쓰는 재료
function G.recipe(shapeGrade)
	return { sugar = G.SugarByGrade[shapeGrade] or 1, soda = 1 }
end

-- 포장할 때 쓰는 재료 (손 제작만. 기계·공장은 안 씀 — 포장 원가 1에 포함)
G.PackCost = { wrapper = 1, twistTie = 1 }

-- 민짜 달고나 (D20, 2026-11-21): 틀을 안 찍고 끝낸 달고나. 고른 도안과 상관없이 기본값 8 × 품질 (포장하면 ×1.1),
-- 설탕은 Common 1회분, 뽑기·도감 안 됨
G.PlainBasePrice = 8
G.PlainSugarGrade = "Common"
G.PackWindowSeconds = 180 -- 다 만든 뒤 이 시간 안에 포장해야 함

-- 판매가 (GDD 13장, 기획 확정 2026-11-20): round(도안 가격 × 품질 배율 × 뽑기 보너스 × 포장 1.1)
G.PackedPriceMult = 1.1
G.GachaBonusDefault = 1 -- 뽑기(15번)는 아직 없음: 자리만
function G.salePrice(basePrice, qualityMult, gachaBonus, packed)
	local v = (basePrice or 0) * (qualityMult or 1) * (gachaBonus or G.GachaBonusDefault) * (packed and G.PackedPriceMult or 1)
	return math.floor(v + 0.5)
end

-- 나무젓가락: 한 판 시작(젓가락을 꺼낼 때)에 1쌍. "다시 하기"도 새 판이라 1쌍. 0쌍이면 시작 못 함
G.ChopsticksPerRound = 1
G.ChopsticksPerHelperRound = 0 -- 알바생은 젓가락을 안 씀 (사용자 결정 2026-11-21: 젓가락은 손 제작 1판에 1쌍만)
G.ChopsticksPerMachineRound = 0 -- 2~5단계 기계·공장은 안 씀 (공장은 운영비 +1)

G.StockMax = 30 -- 들고 있을 수 있는 달고나 수 (작업대 업그레이드마다 +10, G.stockMax)
G.EnforceUnlocks = true -- 해금 안 된 도안은 서버가 거절 (Phase 4, 2026-11-20 켬)

---------------------------------------------------------------- 레벨 (GDD 6장)
G.MaxLevel = 25
-- Lv n → n+1 요구 EXP. Lv1~10은 GDD 값, 그 뒤는 임시로 +110씩 (테스트 뒤 정함)
G.ExpToNext = {
	50, 80, 120, 170, 230, 300, 380, 470, 570, -- Lv1→10 (GDD 6장)
	-- Lv10→25: 기획안 (2026-11-20 기획 세션). 목표 Lv15 ≈ 6~8시간, Lv25 ≈ 20~30시간, Phase 5 시뮬레이터로 다시 봄
	700, 1000, 1300, 1650, 2100,
	2150, 2200, 2300, 2350, 2400, 2450, 2500, 2600, 2700, 2850,
}
-- 레벨업 보상 코인 (도달 레벨 → 코인)
G.LevelCoins = {
	[2] = 100, [3] = 50, [4] = 150, [5] = 200, [6] = 250, [7] = 300,
	[8] = 200, [9] = 275, [10] = 350,
	[11] = 500, [12] = 500, [13] = 500, [14] = 500, [15] = 700,
	[16] = 1000, [17] = 1000, [18] = 1000, [19] = 1000, [20] = 1000,
	[21] = 1200, [22] = 1200, [23] = 1200, [24] = 1200, [25] = 1200, -- 기획안
}
G.ExpHand = { base = 10, Excellent = 10, Perfect = 20 } -- 손 제작 성공 EXP + 등급 보너스
G.ExpBurnt = 2 -- 태우거나 모양이 망가져도(Fail) 조금은 배움
G.ExpHelper = 5 -- 알바생이 만든 1개 (손의 절반, 기획 확정 2026-11-20)
G.ExpMachine = 1 -- 2~5단계 기계·공장 1개 (Phase 5에서 씀. 5씩 주면 Lv10 뒤 레벨이 설비값보다 너무 빨리 오름)
G.ExpDailyGoal = 15 -- 일일 목표 1개 (GDD 6장)

function G.expToNext(level)
	if level >= G.MaxLevel then
		return math.huge
	end
	return G.ExpToNext[level] or (570 + (level - 9) * 110)
end

function G.expFor(grade)
	if grade == "Burnt" or grade == "Fail" then -- 태움 / 모양 망가짐
		return G.ExpBurnt
	end
	return G.ExpHand.base + (G.ExpHand[grade] or 0)
end

---------------------------------------------------------------- 도안 해금 (GDD 3-1장, 2026-11-20)
G.UnlockLevel = { Common = 1, Uncommon = 3, Rare = 6, Epic = 10, Legendary = 15, Mythic = 25 }
-- Master는 레벨이 아니라 도감 조건 (D6, 기획 확정 2026-11-20): 손으로 Excellent 이상 만든 Mythic 종류 수 1/2/3, 연꽃은 Mythic 3종 모두 손으로 Perfect
G.MasterUnlock = {
	{ id = "Spider", mythicExcellent = 1 },
	{ id = "Sierpinski", mythicExcellent = 2 },
	{ id = "Snowflake", mythicExcellent = 3 },
	{ id = "Lotus", mythicPerfect = 3 },
}
G.GradeRank = { Burnt = 0, Fail = 0, Poor = 1, Normal = 2, Good = 3, Excellent = 4, Perfect = 5 }

---------------------------------------------------------------- 장비 업그레이드 (SYSTEMS_SPECIFICATION 7장, Lv2에 열림)
G.UpgradeUnlockLevel = 2
G.Upgrades = {
	stove = { name = "화로", costs = { 150, 500, 1500, 5000 }, desc = "적정 온도 구간 +8%/Lv" }, -- Lv2~5 값
	presser = { name = "누르개", costs = { 200, 700, 2000 }, desc = "누르기 두께 판정 +8%/Lv" }, -- Lv2~4
	table = { name = "작업대", costs = { 500, 2000, 7000 }, desc = "달고나 보관함 +10/Lv" }, -- Lv2~4
}
G.UpgradeOrder = { "stove", "presser", "table" }
G.StoveBandPerLevel = 0.08 -- 적정 온도 구간 폭 ×(1 + 0.08×(Lv-1)), DEVELOPMENT_PLAN 3장 14번
G.PresserBandPerLevel = 0.08
G.TableStockPerLevel = 10

-- data.upgrades는 0부터 (0 = Lv1). 장비 Lv = 값 + 1
function G.stockMax(data)
	local t = data and data.upgrades and data.upgrades.table or 0
	return G.StockMax + t * G.TableStockPerLevel
end

---------------------------------------------------------------- 국자·알바생 (SHOP_GROWTH_PLAN 2장, D10)
G.Ladles = { -- 2번째 국자부터: 해금 레벨, 값
	[2] = { level = 3, cost = 300 },
	[3] = { level = 5, cost = 800 },
	[4] = { level = 8, cost = 1800 },
}
G.HireCost = { 500, 1000, 2000 } -- 알바생 1·2·3번째
G.Helper = {
	seconds = 40, -- 1판 (기본 알바생)
	wagePer30s = 3, -- 일하는 동안만
	qMin = 50, -- 품질 Normal~Good
	qMax = 84,
	maxGrade = "Legendary", -- 자동 생산은 Legendary까지 (D13)
	chopsticks = 0, -- 젓가락 안 씀 (G.ChopsticksPerHelperRound, 2026-11-21)
	-- 숙련 업그레이드: 아직 미정 (자리만). skill 1·2 → 35초·30초 등
	skillSeconds = { [0] = 40 },
	-- 외형 = 주인 아바타 미니미 (D19, 2026-11-20)
	minime = {
		scale = 0.6, -- 키
		headScale = 1.25, -- 머리 살짝 크게
		maxAccessories = 3, -- 폰 부담 (미니미 3 + 손님 3)
		ladleLength = 1.5, -- 손에 든 작은 국자 길이 (스터드)
		ladleTilt = 0.1, -- 국자 그릇이 앞쪽 아래로 기운 정도 (손이 낮아서 거의 수평)
		apron = { Color3.fromRGB(230, 70, 70), Color3.fromRGB(70, 130, 230), Color3.fromRGB(245, 200, 60) }, -- 1 빨강 / 2 파랑 / 3 노랑
	},
}

---------------------------------------------------------------- 일일 목표 (GDD 6장: 3개, 보상 15 EXP)
G.Daily = {
	count = 3,
	rewardCoins = 30, -- 임시
	pool = {
		{ kind = "make", n = 3, text = "달고나 %d개 만들기" },
		{ kind = "make", n = 5, text = "달고나 %d개 만들기" },
		{ kind = "good", n = 2, text = "Good 이상 %d개 만들기" },
		{ kind = "sell", n = 5, text = "손님에게 %d개 팔기" },
		{ kind = "sell", n = 8, text = "손님에게 %d개 팔기" },
		{ kind = "pack", n = 2, text = "%d개 포장하기" },
		{ kind = "earn", n = 60, text = "판매로 %d코인 벌기" },
	},
}

---------------------------------------------------------------- 가게 부지 (D10·D11)
G.Plots = {
	count = 6,
	size = Vector3.new(36, 0.4, 36),
	-- 부지 중심: 스폰 뒤쪽(-Z) 골목 한 줄. 앞(간판)이 +Z(스폰 쪽)를 봄
	rowZ = -72,
	spacing = 40,
	-- 부지 안 자리 (부지 기준 로컬 좌표, -Z = 앞/골목 쪽)
	handStation = { pos = Vector3.new(0, 0, 2), size = Vector3.new(22, 0.2, 7) }, -- 손 작업대: 꾸미기 포함 가운데 (가게마다 작업대, 17b)
	machineSlot = { pos = Vector3.new(11, 0, 13), size = Vector3.new(9, 0.2, 9) }, -- 기계 1자리 (D10), 작업대·알바생 뒤
	buildWorkstation = true, -- 부지를 배정하면 손 작업대를 만듦 (2026-11-21)
	minimeBehind = 1.8, -- 미니미 알바생: 작업대 뒤쪽(테이블 끝에서) 거리
	minimeGap = 2.2, -- 미니미끼리 간격 (화로 가운데 기준)
	factoryDoor = { pos = Vector3.new(0, 0, 17.5) }, -- 가게 뒤 공장 문 (D11, 지금은 자리만)
	sign = { pos = Vector3.new(0, 0, -17.5), height = 9 },
	-- 가게 건물 (D21): 작업대 뒤. 앞면(셔터)이 골목 쪽. 부지 로컬 z = front ~ back
	building = { front = 8.5, back = 17.6, halfWidth = 16.8, height = 10.5 }, -- 높이는 공장 문(9.7)보다 높게
	parasol = { pos = Vector3.new(0, 0, 7.2), height = 11.5, radius = 8 }, -- 작업대 위 파라솔 (노점)
	teleportOnSpawn = false, -- 손 작업대를 부지로 옮기기 전까지는 스폰 그대로 (작업대가 하나뿐)
}

---------------------------------------------------------------- 야외 노점 → 월세 가게 → 기계 (D21, 2026-11-21, GDD 4-0장, 금액은 기획안)
G.Shop = {
	rentLevel = 3, -- 가게 임대 레벨
	deposit = 1000, -- 보증금 (매입 때 값에서 빼 줌)
	rentEvery = 600, -- 접속 10분마다
	rentAmount = 60, -- 월세 (분당 6). 오프라인일 때는 안 냄
	buyLevel = 15, -- 가게 매입
	buyPrice = 50000, -- 보증금은 빼 줌 → 실제 49,000
	stallSlots = 5, -- 노점(또는 문 닫힘) 쟁반 진열 칸
	-- 노점·문 닫힘에서 막히는 것: 국자 확장, 알바생 고용, 작업대 업그레이드 (화로·누르개는 됨)
	lockedWhenStall = { ladle = true, hire = true, table = true },
}

-- 가게 문이 열려 있나 (임대 중이고 월세 밀리지 않음, 또는 매입)
function G.shopOpen(d)
	local s = d and d.shop
	if not s then
		return false
	end
	if s.state == "owned" then
		return true
	end
	return s.state == "rented" and not s.closed
end

-- 진열 칸: 가게가 열려 있으면 진열대 10칸, 아니면 노점 쟁반 5칸
function G.shelfSlots(d)
	return G.shopOpen(d) and G.Sales.shelfSlots or G.Shop.stallSlots
end

---------------------------------------------------------------- 판매: 진열대 + 손님 NPC (Phase 3, D12)
G.Sales = {
	shelfSlots = 10, -- 진열대 칸 (보관함 앞쪽 10개가 진열됨, 먼저 만든 것부터 팔림)
	maxCustomers = 3, -- 가게당 동시 손님
	-- 손님 수요 (GDD 5-1장 D12, 기획 세션 2026-11-20: 수요 ≈ 생산의 80%, 시뮬레이션 전 기획안)
	-- { 방문 간격(초), 1명당 최소, 최대 }
	-- 1단계(연탄 화로)는 국자 수로 (생산 = 손 1.5 + 알바생 1명당 1.5개/분의 약 80%, 국자 1개만 첫 판매 재미로 조금 높게)
	demandByLadles = {
		{ 30, 1, 1 }, -- 분당 2
		{ 20, 1, 1 }, -- 분당 3
		{ 24, 1, 2 }, -- 분당 3.75
		{ 18, 1, 2 }, -- 분당 5
	},
	-- 2~5단계: 기계·공장
	demandByStage = {
		[2] = { 12, 1, 2 },
		[3] = { 10, 1, 3 },
		[4] = { 8, 1, 3 },
		[5] = { 6, 1, 3 },
	},
	jitter = 0.3, -- 간격 ±30%
	testSpeed = 1, -- 테스트용 배율: 2면 손님이 2배 자주 옴 (출시 때는 1)
	walkSpeed = 9, -- 스터드/초
	browseSeconds = 1.6, -- 진열대 앞에서 고르는 시간
	-- 부지 기준 로컬 좌표 (-Z = 골목 쪽)
	shelf = { pos = Vector3.new(11, 0, -10), size = Vector3.new(9, 3, 2.4) },
	standZ = -13.2, -- 손님이 서는 곳 (진열대 앞)
	streetZ = -26, -- 골목 길
	streetHalf = 22, -- 골목에서 나타나고 사라지는 곳 (부지 중심에서 좌우)
}

-- 설비 단계·국자 수 → 방문 간격(초, testSpeed 반영), 1명당 최소·최대 개수
function G.salesDemand(stage, ladles)
	local row
	if (stage or 1) <= 1 then
		row = G.Sales.demandByLadles[math.clamp(ladles or 1, 1, #G.Sales.demandByLadles)]
	else
		row = G.Sales.demandByStage[math.min(stage, 5)]
	end
	return row[1] / math.max(G.Sales.testSpeed, 0.01), row[2], row[3]
end

-- 플레이어 데이터로 손님 수요: 가게 문이 닫혀 있으면(노점) 국자 1개 수요, 기계도 가게 안에서만 (D21)
function G.salesDemandFor(d)
	if not G.shopOpen(d) then
		return G.salesDemand(1, 1)
	end
	return G.salesDemand(d.machineStage or 1, d.ladles or 1)
end

---------------------------------------------------------------- 상점·요청 제한
G.ShopCooldown = 0.25 -- 초당 4번까지 구매

return G

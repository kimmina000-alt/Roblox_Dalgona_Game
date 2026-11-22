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
G.SchemaVersion = 9 -- v2 (2026-11-20 성장): 해금·도감·일일 목표·알바생 / v3 (2026-11-21 D21): 노점 → 월세 가게 / v4: 진열대에 직접 놓기 / v5: 기계 2~4단계 / v6: 공장 / v7: 오프라인 생산 (lastSeen) / v8: 공장 공정 알바생 / v9: 첫 60초 안내

-- 새 플레이어 기본 데이터 (빠진 칸은 불러올 때 여기서 채움)
G.DefaultData = {
	coins = 100, -- 시작 자금 (ECONOMY_BALANCE 6장 "시작 자금 100")
	exp = 0,
	level = 1,
	ingredients = { sugar = 5, soda = 5, wrapper = 5, chopsticks = 5, twistTie = 5 }, -- 첫 판을 바로 해 볼 수 있게 5회분 (사용자 확정, 2026-11-20)
	stock = {}, -- 만든 달고나 { id, s = 도안 id, g = 등급, q = 완성도, p = 판매가, b = 도안 가격, m = 품질 배율, pk = 포장 여부, sl = 진열대 칸(없으면 보관함) }
	nextItemId = 1, -- 달고나 번호 (들고 다니기·진열 칸을 찾는 데 씀)
	unlockedShapes = { "Circle", "Square", "Triangle", "Bone" }, -- Common (레벨이 오르면 GrowthService가 더함)
	upgrades = { stove = 0, presser = 0, table = 0 }, -- 화로·누르개·작업대 장비 Lv (Phase 4)
	ladles = 1, -- 국자 수 1~4 (SHOP_GROWTH_PLAN 2장)
	partTimers = {}, -- 알바생 { { shape = 만들 도안 id, skill = 숙련(자리만) } } 국자 2번째부터 1명씩
	machineStage = 1, -- 설비 단계 1 연탄 화로 ~ 5 공장 (SHOP_GROWTH_PLAN 1장)
	machine = { shapes = {}, t = 0 }, -- 기계 (20번): shapes[기계 id] = 만들 도안 id, t = 이번 판 진행 초
	-- 가게 뒤 공장 (D11, 5단계): on = 생산 켬, shape·qty·mode = 제어대 설정, lines = 라인별 진행 중인 판 { s, n, m, t, sec } 또는 false,
	-- ups = 제어대 업그레이드 단계 [key] = 0..
	-- staff[공정 key] = true: 고용한 공정 알바생 (D30)
	factory = { unlocked = false, on = false, shape = "", qty = 20, mode = "normal", lines = {}, ups = {}, staff = {} },
	-- 가게 (D21): state = "stall"(야외 노점) | "rented"(월세) | "owned"(매입). rentTimer = 지난 월세 뒤 접속한 초, closed = 월세 못 내 문 닫힘
	shop = { state = "stall", rentTimer = 0, closed = false },
	stats = { made = 0, sold = 0, coinsEarned = 0, helperMade = 0, wagesPaid = 0 },
	collection = {}, -- 도감 [도안 id] = { best = 손으로 만든 최고 등급, n = 손으로 만든 수 } (자동 생산은 안 셈)
	daily = { day = "", goals = {} }, -- 일일 목표 3개 (UTC 날짜가 바뀌면 새로)
	tutorialDone = false, -- 첫 60초 안내를 끝냈거나 건너뜀 (21번). 새 플레이어만 false
	lastSeen = 0, -- 마지막으로 접속해 있던 시각 (os.time, 저장할 때마다 갱신). 0 = 아직 없음 → 정산 안 함 (D29)
	offline = { settledAt = 0, from = 0, seconds = 0 }, -- 마지막 오프라인 정산 기록
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
	local n = G.StockMax + t * G.TableStockPerLevel
	-- 공장 대형 완제품 창고: 보관량 2배
	local f = data and data.factory
	if f and f.ups and (f.ups.warehouse or 0) > 0 then
		n *= G.Factory.warehouseMult
	end
	return n
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
	factoryDoor = { pos = Vector3.new(0, 0, 17.5), gap = 7.4 }, -- 가게 뒤 공장 문 (D11). gap = 뒤 울타리에서 비우는 폭 (뒷벽 문 폭과 같음)
	sign = { pos = Vector3.new(0, 0, -17.5), height = 9 },
	-- 가게 건물 (D21): 작업대 뒤. 앞면(셔터)이 골목 쪽. 부지 로컬 z = front ~ back
	building = { front = 8.5, back = 17.6, halfWidth = 16.8, height = 10.5 }, -- 높이는 공장 문(9.7)보다 높게
	parasol = { pos = Vector3.new(3, 0, -2), height = 11.5, radius = 7 }, -- 작업대 위 파라솔 (노점). 기둥은 주인이 서는 쪽, 천은 작업대 위
	-- 노점 배치 (사용자 2026-11-21): 작업대 앞선을 진열대 앞선에 맞춰 한 줄로. 장식용 계단 진열대(Show*)는 뺌
	-- 겉모습만 180° 돌림 (사용자 2026-11-21). 만드는 동안 제작 화면은 MakingClient가 내 화면에서만 돌리기 전 방향으로 되돌림
	workstationTurn = 180, -- 도
	removeDecorDisplay = true,
	rowGap = 0.3, -- 진열대와 작업대 사이
	entry = Vector3.new(0, 0, -21), -- 접속하면 서는 곳: 내 가게 앞 골목 (간판 앞)
	teleportOnSpawn = true, -- 스폰을 내 가게 앞으로 (사용자 2026-11-21)
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
	autoShelveHelpers = true, -- 알바생이 만든 것은 빈 칸에 저절로 진열 (가게 직원이라). 손으로 만든 것은 들고 가서 놓음
	-- 노점·문 닫힘에서 막히는 것: 국자 확장, 알바생 고용, 작업대 업그레이드 (화로·누르개는 됨)
	lockedWhenStall = { ladle = true, hire = true, table = true, machine = true },
}

---------------------------------------------------------------- 기계 2~4단계 (20번, SHOP_GROWTH_PLAN 1·3~5장, D9·D10)
-- 가게 뒤 기계 1자리에서 단계대로 교체. 한 판 = batch개 / seconds초 (시간당 4 → 6 → 10개/분)
G.Machines = {
	[2] = { id = "steel", name = "철제 판매기", level = 10, price = 15000, batch = 2, seconds = 30 },
	[3] = { id = "pink", name = "분홍 자판기", level = 15, price = 45000, batch = 5, seconds = 50 },
	[4] = { id = "line", name = "연속 생산 설비", level = 20, price = 120000, batch = 10, seconds = 60 },
}
-- 5단계 공장 (SHOP_GROWTH_PLAN 6~8장, D8·D11·D13·D26, 2026-11-21). 가게 뒤 문 → 플레이어별 공장 공간
G.Factory = {
	level = 25,
	price = 300000,
	needStage = 4, -- 연속 생산 설비가 있어야 함
	machineKeepsRunning = true, -- 공장을 사도 가게 기계는 계속 돎 (사용자 확정 2026-11-21, 판매량은 손님 수요가 막음)
	baseQty = 20, -- 한 판 기본 수량 (대량 생산 모듈로 30 → 40)
	baseSeconds = 100, -- 20개 한 판
	secondsPerExtra = 3, -- 20개 넘는 1개마다 +3초 (40개 = 160초, 6장 예시)
	modes = {
		normal = { name = "일반", time = 1.0, qMin = 50, qMax = 84 }, -- Normal~Good
		precise = { name = "정밀", time = 1.5, qMin = 70, qMax = 94 }, -- Good~Excellent
		fast = { name = "고속", time = 0.7, qMin = 30, qMax = 84 }, -- Poor~Good
	},
	modeOrder = { "normal", "precise", "fast" },
	maxGrade = "Legendary", -- D13
	-- 1개 원가: 설탕(도안 등급만큼, 1회분 3) + 소다 1 + 운영비 1코인. 판을 시작할 때 한 번에 뺌
	-- 포장지는 자동 포장(⑤ 포장 공정 알바생, D30)이 있을 때만 1개씩 쓰고 판매가 ×1.1 (D28, 손 포장 D18과 같은 규칙)
	perItem = { soda = 1 }, -- 설탕은 G.recipe(등급)
	packPerItem = { wrapper = 1 }, -- 자동 포장일 때만
	operatingCoins = 1, -- 제한 4: 공장 유지비 (1개당)
	powerPerUpgrade = 2, -- 제한 5: 제어대 업그레이드 1단계마다 판당 전력비 +2코인
	warehouseMult = 2, -- 대형 완제품 창고: 보관량 2배
	conveyorTime = 0.85, -- 고속 컨베이어: 시간 -15%
	precisionQ = 6, -- 정밀 품질 제어기: 품질 범위 +6 (Excellent 확률↑, 최대 94)
	-- 제어대 업그레이드 (6장 표). costs = 단계별 값
	upgrades = {
		{ key = "bulk", name = "대량 생산 모듈", desc = "생산량 20 → 30 → 40개", costs = { 50000, 80000 } },
		{ key = "parallel", name = "병렬 생산 라인", desc = "동시 작업 2개", costs = { 100000 } },
		{ key = "conveyor", name = "고속 컨베이어 시스템", desc = "생산 시간 15% 감소", costs = { 120000 } },
		{ key = "precision", name = "정밀 품질 제어기", desc = "Excellent 확률 증가", costs = { 150000 } },
		{ key = "warehouse", name = "대형 완제품 창고", desc = "보관함 2배", costs = { 80000 } },
	},
	-- 공정 알바생 (D30, 사용자 2026-11-22, 수치 기획안). 공정마다 따로 고용, 생김새는 내 캐릭터 미니미 + 공정별 옷 (제작 세션)
	-- 효과와 급여는 판을 시작할 때 정함: 그 판 시간만큼 급여를 먼저 내고, 코인이 모자라면 그 공정만 그 판에서 효과 꺼짐.
	-- 제어대 업그레이드와 겹치면 곱해서 적용. 예전 "자동 포장 시스템" 업그레이드는 ⑤ 포장 알바생이 대신함
	staff = {
		hireCost = 10000,
		wagePer30s = 6, -- 1명당 30초당 6 (공장이 돌아가는 동안만, 오프라인도 일한 만큼)
		sugarSave = 0.10, -- ① 설탕 10% 덜 씀 (내림: 10개마다 1회분)
		boilUpChance = 0.15, -- ② 품질 한 칸 위로 (최고 Excellent)
		pressTime = 0.9, -- ③ 생산 시간 -10%
		inspectPoorKeep = 0.5, -- ④ Poor가 나올 확률 절반 (나머지 절반은 Normal로)
		stations = {
			{ key = "sugar", name = "설탕 넣기", desc = "설탕 10% 덜 씀", outfit = "흰 두건 + 마스크" },
			{ key = "boil", name = "끓이기", desc = "15% 확률로 품질 한 칸 위로 (최고 Excellent)", outfit = "빨간 앞치마 + 오븐 장갑" },
			{ key = "press", name = "붓기·찍기", desc = "생산 시간 -10%", outfit = "노란 안전모" },
			{ key = "inspect", name = "식히기·검사", desc = "Poor 확률 절반", outfit = "하늘색 위생모 + 돋보기" },
			{ key = "pack", name = "포장", desc = "자동 포장: 포장지 1개씩, 판매가 ×1.1", outfit = "파란 앞치마 + 빵끈" },
		},
	},
	-- 공장 부지 (D11, 2026-11-22 바뀜): 가게 건물 뒤에 바로 붙은 울타리 부지 (폭 28 × 깊이 44), 뒷문으로 걸어 들어감.
	-- 부지·공장 3D는 제작 세션이 만듦 (Plot<i>.FactoryLot.Ground = 영역). 없을 때는 아래 값(부지 기준 로컬)으로 판정
	lot = { pos = Vector3.new(0, 0, 40), size = Vector3.new(28, 0, 44), guardHeight = 40 },
}

-- 공장 한 판: 시간(초)
function G.factorySeconds(qty, mode, ups)
	local F = G.Factory
	local s = F.baseSeconds + math.max(0, qty - F.baseQty) * F.secondsPerExtra
	s *= (F.modes[mode] or F.modes.normal).time
	if ups and (ups.conveyor or 0) > 0 then
		s *= F.conveyorTime
	end
	return math.floor(s + 0.5)
end

-- 공장 최대 수량 (대량 생산 모듈 단계)
function G.factoryMaxQty(ups)
	return G.Factory.baseQty + 10 * math.min((ups and ups.bulk) or 0, 2)
end

G.Machine = {
	qMin = 50, -- 품질 Normal~Excellent (Perfect는 손으로만)
	qMax = 94,
	maxGrade = "Legendary", -- 자동 생산은 Legendary까지 (D13)
	-- 재료는 원가대로 (G.recipe), 젓가락·빵끈 안 씀 (G.ChopsticksPerMachineRound, D16), EXP는 G.ExpMachine
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
	walkSwing = 0.5, -- 걸을 때 다리·팔 흔드는 각도(라디안, 손님 NPC 모델)
	browseSeconds = 1.6, -- 진열대 앞에서 고르는 시간
	-- 부지 기준 로컬 좌표 (-Z = 골목 쪽)
	shelf = { pos = Vector3.new(14.1, 0, -10), size = Vector3.new(7, 3, 2.4) }, -- 작업대와 한 줄, 간판에서 볼 때 왼쪽 끝 (2026-11-21)
	standZ = -13.2, -- 손님이 서는 곳 (진열대 앞)
	streetZ = -26, -- 골목 길
	streetHalf = 22, -- 골목에서 나타나고 사라지는 곳 (부지 중심에서 좌우)
	-- 진열대에 완성품 모양 그대로 (사용자 2026-11-21)
	lookSize = 1.15, -- 진열 칸 달고나 지름
	lookStick = { 0.25, 0.85 }, -- 세워 꽂을 때 윗면 위로 보이는 막대 길이 (앞줄, 뒷줄)
	-- 손님이 산 달고나를 먹으며 가기 (사용자 2026-11-21). 손님 몸 기준 로컬 좌표 (-Z = 앞)
	eat = {
		size = 0.95, -- 손에 든 달고나 지름
		hold = Vector3.new(0.55, 2.25, -0.75), -- 들고 걸을 때 원판 가운데
		mouth = Vector3.new(0.05, 3.05, -0.95), -- 입 앞
		-- 손님 NPC 모델 (CustomerRig): 원판 가운데 = 손(hand) + modelHold (+ 막대 길이만큼 위), 입 앞 = mouth + modelMouth
		modelHold = Vector3.new(-0.1, 0, -0.45),
		modelMouth = Vector3.new(0, -0.05, -0.35),
		cycle = 2.4, -- 한 입 주기(초)
		bites = 4, -- 몇 입에 다 먹나
		biteScale = 0.85, -- 한 입마다 크기
		lines = { "냠", "바삭!", "달다~" },
		lastLine = "잘 먹었습니다!",
	},
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

---------------------------------------------------------------- 오프라인 생산 (D29, 2026-11-22 사용자 결정, 수치는 임시)
-- 알바생·기계·공장은 접속하지 않은 동안에도 각자 규칙대로 만든다 (손 제작은 안 됨). 들어올 때 한 번에 정산
G.Offline = {
	maxHours = 8, -- 최대 이만큼만 셈
	minSeconds = 60, -- 이보다 짧게 나갔다 오면 정산 안 함
	step = 1, -- 시뮬레이션 간격(초)
	reportDelay = 4, -- 들어온 뒤 요약 팝업을 보내기까지 (화면 준비)
	-- 판매 없음, 월세 없음. 나갈 때 가게 문이 닫혀 있었으면 알바생·기계·공장 모두 멈춘 채
}

---------------------------------------------------------------- 첫 60초 안내 (21번, 2026-11-22, DEVELOPMENT_PLAN 6장 Phase 6)
-- 할아버지 NPC가 말풍선으로 단계마다 알려 줌. 새 플레이어(tutorialDone = false)만. 건너뛰기 가능
G.Tutorial = {
	nearDistance = 11, -- 작업대에 이만큼 가까이 가면 1단계 끝
	hurryCustomer = true, -- 첫 달고나를 진열하면 손님이 바로 옴
	makePanelTop = 70, -- 만드는 동안 안내 판을 화면 위에서 이만큼 아래에 (제작 화면 단계 칩 아래)
	steps = {
		{ key = "go", text = "어서 와! 여기가 네 노점이란다. 반짝이는 작업대로 가 보렴", target = "workstation" },
		{ key = "press", text = "작업대 앞에서 E를 누르면 달고나를 만들 수 있어", touchText = "작업대 앞에서 손 모양 버튼을 누르면 달고나를 만들 수 있어", target = "workstation" },
		{ key = "make", text = "설탕을 녹이고 소다를 넣어 부풀린 다음, 붓고 눌러서 모양을 찍어 보렴", target = nil },
		{ key = "place", text = "잘했다! 들고 있는 달고나를 반짝이는 진열대에 놓아 보렴 (R)", touchText = "잘했다! 들고 있는 달고나를 반짝이는 진열대 칸에 놓아 보렴", target = "shelf" },
		{ key = "sale", text = "곧 손님이 와서 사 갈 거야. 조금만 기다려 보렴", target = "shelf" },
		{ key = "shop", text = "첫 장사 축하한다! 재료가 떨어지면 상점에서 사면 돼. 상점 버튼을 눌러 보렴", target = "shopButton" },
	},
	doneText = "이제 혼자서도 잘하겠구나. 맛있는 달고나 많이 팔아라!",
}

---------------------------------------------------------------- 상점·요청 제한
G.ShopCooldown = 0.25 -- 초당 4번까지 구매

return G

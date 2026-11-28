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
G.SchemaVersion = 18 -- v18 (2026-11-26): 진열 칸 여는 순서 바꿈(유리 진열장 → 작은 탁자 3개 → 걸이판 → 벽면 진열장), 새 순서로 닫힌 칸의 달고나는 보관함으로 / v17 (2026-11-26 D57): 진열장 단계(displayTier, 가게가 있던 저장은 4) · 냉장고·서랍장 단계, 넘치는 진열은 보관함으로 / v16 (2026-11-24 D51): 문어 Mythic → 알바·기계·공장 도안 문어는 범선, Lv25 전이면 해금 뺌 / v15 (2026-11-24 D38): 도감 보상 표시·손님 도감·칭호 / v14 (2026-11-24 D46 재수정): 화로 알바 → 2단계 기계 자리, coalLeft2 없앰, 숙련 교육 환불·전문 교육 → 기계 알바 교육 / v13 (2026-11-24): 두 번째 화구 → 연탄 덮개 / v12 (2026-11-24 D44): 연탄 재료·화로 연탄 남은 양 / v11 (2026-11-24 D43·D42): 공장 공정 알바 → 알바생 목록, 보관함 보장분 / v10 (D34·D39·D40): 알바생 배치(post), 국자 → 화로 알바 교육(stoveUps) / v2 (2026-11-20 성장): 해금·도감·일일 목표·알바생 / v3 (2026-11-21 D21): 노점 → 월세 가게 / v4: 진열대에 직접 놓기 / v5: 기계 2~4단계 / v6: 공장 / v7: 오프라인 생산 (lastSeen) / v8: 공장 공정 알바생 / v9: 첫 60초 안내

-- 새 플레이어 기본 데이터 (빠진 칸은 불러올 때 여기서 채움)
G.DefaultData = {
	coins = 100, -- 시작 자금 (ECONOMY_BALANCE 6장 "시작 자금 100")
	exp = 0,
	level = 1,
	ingredients = { sugar = 5, soda = 5, wrapper = 5, chopsticks = 5, twistTie = 5, coal = 1 }, -- 첫 판을 바로 해 볼 수 있게 5회분 (사용자 확정, 2026-11-20)
	stock = {}, -- 만든 달고나 { id, s = 도안 id, g = 등급, q = 완성도, p = 판매가, b = 도안 가격, m = 품질 배율, pk = 포장 여부, sl = 진열대 칸(없으면 보관함) }
	nextItemId = 1, -- 달고나 번호 (들고 다니기·진열 칸을 찾는 데 씀)
	unlockedShapes = { "Circle", "Square", "Triangle", "Bone" }, -- Common (레벨이 오르면 GrowthService가 더함)
	upgrades = { stove = 0, presser = 0, table = 0 }, -- 화로·누르개·작업대 장비 Lv (Phase 4)
	-- 알바생 (D34·D43): { shape = 화로에서 만들 도안 id, skill = 모자(자리만), post = 역할 key (G.HelperPosts) | nil(대기) }
	partTimers = {},
	stoveUps = {}, -- 화로 알바 교육 (D40): [key] = true (G.StoveTraining)
	-- 화로 연탄 남은 양 (D44, 0~1). coalLeft = 화구 ① 내 손 작업대, coalLeft2 = 화구 ② 화로 알바 자리 (2026-11-24: 화구 2개 기본)
	coalLeft = 1,
	displayHand = true, -- 진열 알바가 손으로 만든 것도 옮김 (D33, 켜고 끌 수 있음)
	layout = {}, -- 건설 배치 (D53): [물건 key] = { x, z, r } (부지 로컬 격자, BuildService). 비면 처음 자리
	bgmOff = false, -- 배경 음악 끔 (설정, GrowthAction("bgmOff", true/false)) → 플레이어 속성 BgmOff
	displayTier = 0, -- 진열장 단계 0~5 (D57, G.Display). GrowthAction("displayUp")
	storageTier = { fridge = 0, drawer = 0 }, -- 냉장고·서랍장 단계 0~3 (D57, G.StorageTiers). GrowthAction("storageUp", "fridge" | "drawer")
	custDex = {}, -- 손님 도감 (D38): [손님 id] = { sold = 판 수, h = 받은 하트 보상 0~3 }
	titles = { owned = {} }, -- 칭호 (D38): owned = 얻은 이름들, equipped = 단 칭호
	signGold = false, -- 간판 금테 (D38: 도안 23종 모두 Perfect)
	custFav = {}, -- 단골 손님이 좋아하는 도안 (D37): [손님 id] = 도안 id (처음 올 때 열린 도안 중 무작위로 정함)
	machineStage = 1, -- 설비 단계 1 연탄 화로 ~ 5 공장 (SHOP_GROWTH_PLAN 1장)
	machine = { shapes = {}, t = 0, ts = {} }, -- 기계 (20번): shapes[기계 id] = 만들 도안 id, ts[기계 id] = 이번 판 진행 초 (D32 기계 여러 대, t는 예전 값 → 처음 읽을 때 ts로 옮김)
	-- 가게 뒤 공장 (D11, 5단계): on = 생산 켬, shape·qty·mode = 제어대 설정, lines = 라인별 진행 중인 판 { s, n, m, t, sec } 또는 false,
	-- ups = 제어대 업그레이드 단계 [key] = 0..
	-- 공정 알바생(D30)은 D43부터 partTimers의 역할 f_<공정 key>
	factory = { unlocked = false, on = false, shape = "", qty = 20, mode = "normal", lines = {}, ups = {} },
	factorySkill = { sugar = 0, boil = 0, press = 0, inspect = 0, pack = 0 }, -- 공장 손재주 (D49): 공정마다 0~3
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
	{ id = "coal", name = "연탄", icon = "⚫", pack = 5, price = 25 }, -- D44 (2026-11-24): 5장 25코인, 1장 = 화로에서 10판 (G.CoalPerMake)
}
G.IngredientMax = 3000 -- 재료마다 최대 보관량 (D57부터 맨 위 단계 값. 실제 한도는 G.ingredientMax(d, id) = 냉장고·서랍장 단계)
-- 한 번에 살 수 있는 묶음 수 (2026-11-24 사용자 "10, 50, 100 단위로"): 1·5·10팩 = 재료마다 pack × 1/5/10 (설탕 10/50/100회분, 연탄 5/25/50장). 할인 없음
G.BuyPacks = { 1, 5, 10 }
-- 가게 냉장고·서랍장 (2026-11-24 사용자 "냉장고랑 냉장고 옆 서랍장 기능 구현", WORK_PRIORITIES 가게 기능 ②③):
-- 가게 3D 부품 Role을 누르면 그 칸 재료를 보여 주고 바로 삼. role = 가게 모델 부품 속성 Role
G.StorageGroups = {
	{ key = "fridge", role = "냉장고", title = "냉장고 · 식재료", ids = { "sugar", "soda" } },
	{ key = "drawer", role = "서랍장", title = "서랍장 · 그 밖의 재료", ids = { "wrapper", "chopsticks", "twistTie", "coal" } },
}

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
-- 달고나빵 (2026-11-27 사용자 "누르지 않은 반죽 위에 설탕가루 뿌린 게 달고나빵, 메뉴에 추가하고 가격 책정"):
-- 붓고 누르지 않은 봉긋한 반죽 + 설탕 가루. 고른 도안과 상관없이 기본값 6 × 품질 (손 제작 ×1.5, 포장 ×1.1).
-- 메뉴판 값은 기본 달고나 2,000원(민짜 8) 비율로 1,500원 = 6. 설탕은 Common 1회분, 뽑기·도감 안 됨
G.BreadBasePrice = 6
G.BreadMenuWon = 1500
G.PackWindowSeconds = 180 -- 다 만든 뒤 이 시간 안에 포장해야 함

-- 판매가 (GDD 13장, 기획 확정 2026-11-20): round(도안 가격 × 품질 배율 × 뽑기 보너스 × 포장 1.1)
G.PackedPriceMult = 1.1
G.GachaBonusDefault = 1 -- 뽑기(15번)는 아직 없음: 자리만
-- 손 제작품 "수제" (D58, 2026-11-26 확정): 손으로 만든 것(진열 아이템 hand = true)만 판매가 ×1.5. 기계·알바·공장 것은 ×1
G.HandMadeMult = 1.5
function G.salePrice(basePrice, qualityMult, gachaBonus, packed, hand)
	local v = (basePrice or 0) * (qualityMult or 1) * (gachaBonus or G.GachaBonusDefault) * (packed and G.PackedPriceMult or 1) * (hand and G.HandMadeMult or 1)
	return math.floor(v + 0.5)
end

-- 나무젓가락: 한 판 시작(젓가락을 꺼낼 때)에 1쌍. "다시 하기"도 새 판이라 1쌍. 0쌍이면 시작 못 함
G.ChopsticksPerRound = 1
G.ChopsticksPerHelperRound = 0 -- 알바생은 젓가락을 안 씀 (사용자 결정 2026-11-21: 젓가락은 손 제작 1판에 1쌍만)
G.CoalPerMake = 0.1 -- 화로 한 판에 타는 연탄 (D44, 1장 = 10판). 손 제작·화로 알바만, 기계·공장은 안 씀
-- 화구 ②를 연탄 화로 복제로 만들지 (2026-11-24 보류: 사용자 "2단계 기계가 화구 두 개니까 그걸 활용" → PM 확인 전까지 끔)
G.Burner2Brazier = false
G.CoalPerMakeCovered = 1 / 15 -- 연탄 덮개(Lv5, 2026-11-24)를 사면 1장 = 15판

function G.coalPerMake(d)
	return (d and d.stoveUps and d.stoveUps.coalCover) and G.CoalPerMakeCovered or G.CoalPerMake
end
G.ChopsticksPerMachineRound = 0 -- 2~5단계 기계·공장은 안 씀 (공장은 운영비 +1)

G.StockMax = 50 -- 보관함 기본 칸 (D42, 2026-11-24: 30 → 50). 진열대 칸은 따로 (G.stockMax·G.storedCount)
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
G.ExpHand = { base = 15, Excellent = 10, Perfect = 20 } -- D58: base 10 → 15 -- 손 제작 성공 EXP + 등급 보너스
G.ExpBurnt = 2 -- 태우거나 모양이 망가져도(Fail) 조금은 배움
G.ExpHelper = 5 -- 알바생이 만든 1개 (손의 절반, 기획 확정 2026-11-20)
G.ExpMachine = 1 -- 2~5단계 기계·공장 1개 (Phase 5에서 씀. 5씩 주면 Lv10 뒤 레벨이 설비값보다 너무 빨리 오름)
G.ExpDailyGoal = 30 -- 일일 목표 1개 (GDD 6장, D58: 15 → 30)

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

-- 도감 보상 (D38, 2026-11-24 확정. 꾸미기 보상은 뺌). 서버 CollectionService
G.Collection = {
	firstMadeExp = 20, -- 처음 만듦
	excellentMult = 5, -- 처음 Excellent: 코인 = 도안 가격 × 5
	perfectMult = 10, -- 처음 Perfect: 코인 = 가격 × 10 + 금별
	ppopgiExp = 30, -- 완벽 뽑기: EXP 30 + 도장
	masterTitle = "달고나 장인", -- 23종 모두 Perfect (+ 간판 금테)
	meetCoins = 30, -- 손님 처음 만남
	hearts = { 10, 50, 150 }, -- 하트 1·2·3 (판 수)
	heart1Exp = 50,
	heart2Coins = 300, -- + 단골(regular) 둘: 좋아하는 도안 공개 / 나머지 5종: 아래 팁
	heart2Tip = 0.05, -- 단골이 아닌 손님 5종: 하트 2부터 그 손님에게 팔 때 팁 +5% (계속, 11-24 기획)
	streetTitle = "골목 인기 가게", -- 손님 7종 모두 하트 3
}

---------------------------------------------------------------- 장비 업그레이드 (SYSTEMS_SPECIFICATION 7장, Lv2에 열림)
-- 하트 2 팁 (단골이 아닌 손님만). d = 저장 데이터, ctype = G.Customers.types 항목
function G.heartTip(d, ctype)
	if not ctype or ctype.kind == "regular" then
		return 0
	end
	local c = type(d.custDex) == "table" and d.custDex[ctype.id]
	return (type(c) == "table" and (c.h or 0) >= 2) and G.Collection.heart2Tip or 0
end

G.UpgradeUnlockLevel = 2
G.Upgrades = {
	stove = { name = "화로", costs = { 150, 500, 1500, 5000 }, desc = "적정 온도 구간 +8%/Lv" }, -- Lv2~5 값
	presser = { name = "누르개", costs = { 200, 700, 2000 }, desc = "누르기 두께 판정 +8%/Lv" }, -- Lv2~4
	table = { name = "작업대", costs = { 500, 2000, 7000 }, desc = "달고나 보관함 +10/Lv" }, -- Lv2~4
}
G.UpgradeOrder = { "stove", "presser", "table" }
G.StoveBandPerLevel = 0.08 -- 적정 온도 구간 폭 ×(1 + 0.08×(Lv-1)), DEVELOPMENT_PLAN 3장 14번
G.PresserBandPerLevel = 0.08
G.TableStockPerLevel = 25 -- 작업대 Lv2~4마다 +25 (D42: +10 → +25, 최대 125)
G.MachineStock = { [2] = 50, [3] = 75, [4] = 125 } -- 기계를 사면 딸린 보관 선반 (D42, 단계마다 더함 → 4단계까지 +250)
G.FactoryBinStock = 250 -- 공장 받는 상자 (D42, 공장을 사면)

-- data.upgrades는 0부터 (0 = Lv1). 장비 Lv = 값 + 1
-- 보관함 용량 (D42): 기본 50 + 작업대 +25/Lv + 기계 보관 선반 + 공장 받는 상자, 창고면 ×2. stockBonus = 옛 데이터 보장분 (v10)
function G.stockMax(data)
	local t = data and data.upgrades and data.upgrades.table or 0
	local n = G.StockMax + t * G.TableStockPerLevel
	local stage = data and data.machineStage or 1
	for s, k in pairs(G.MachineStock) do
		if stage >= s then
			n += k
		end
	end
	local f = data and data.factory
	if f and f.unlocked then
		n += G.FactoryBinStock
	end
	-- 공장 대형 완제품 창고: 보관량 2배
	if f and f.ups and (f.ups.warehouse or 0) > 0 then
		n *= G.Factory.warehouseMult
	end
	return n + (data and tonumber(data.stockBonus) or 0)
end

-- 보관함에 있는 수 (진열대에 놓인 것은 안 셈, D42)
function G.storedCount(d)
	local n = 0
	for _, it in ipairs(d.stock) do
		if not it.sl then
			n += 1
		end
	end
	return n
end

-- 보관함 남은 칸 (손으로 만든 것·뽑기 덤처럼 보관함으로만 가는 것)
function G.storageRoom(d)
	return G.stockMax(d) - G.storedCount(d)
end

-- 자동 생산이 넣을 수 있는 수 = 보관함 남은 칸 + 진열대 빈 칸 (자동 생산은 빈 칸부터 채움, D26)
function G.stockRoom(d)
	local used = 0
	local slots = G.shelfSlots(d)
	for _, it in ipairs(d.stock) do
		if it.sl and G.slotOpen(d, it.sl) then
			used += 1
		end
	end
	return math.max(0, G.storageRoom(d)) + math.max(0, slots - used)
end

---------------------------------------------------------------- 국자·알바생 (SHOP_GROWTH_PLAN 2장, D10)
-- 국자 확장은 없앰 (D39, 2026-11-24). 같은 레벨에 화로 알바 키우기 (D40): 화로에 배치한 알바생에게만 효과
-- D46 재수정 (2026-11-24 사용자 "2단계 기계가 화구 두 개니까 그걸 활용하자 연탄 화로를 늘리지 말고"):
-- 화로 알바는 없고 2단계 기계(국자 2개)가 Lv5에 열림. 보상 = Lv3 연탄 덮개, Lv8 기계 알바 교육 (이름은 옛 G.StoveTraining 그대로)
G.StoveTraining = {
	{ key = "coalCover", name = "연탄 덮개", level = 3, cost = 800, text = "연탄 1장으로 10판 → 15판" },
	{ key = "machineTrain", name = "기계 알바 교육", level = 8, cost = 1800, text = "기계로 만든 달고나 품질 Good~Excellent" },
}
G.MachineTrainQ = { 70, 94 } -- 기계 알바 교육 뒤 기계 품질 범위 (Good~Excellent)
-- 알바생 역할 (D34 → D43, 2026-11-24): 고용한 뒤 역할을 고름. 역할마다 한 명, 최대 11명 (제작대 4 + 진열 + 계산 + 공장 공정 5).
-- 고용비는 몇 번째로 뽑느냐에 따라 (역할과 상관없음), 역할은 언제든 공짜로 바꿈
G.HireCost = { 500, 1500, 3000, 5000, 7500, 10000, 10000, 10000, 10000, 10000 }
G.HelperMax = 10 -- D46: 화로 알바가 2단계 기계 알바로 합쳐져 제작대 3 + 진열 + 계산 + 공장 5
-- 역할 (순서 = 화면 순서). kind: station(제작대) | display(진열) | cashier(계산) | factory(공장 공정, factoryKey = G.Factory.staff.stations key)
-- 열리는 때: level(가게를 임대한 뒤), stage(그 기계를 산 뒤), factory(공장을 산 뒤). wage = 30초당 급여 (일할 때만)
G.HelperPosts = {
	{ key = "steel", name = "철제 판매기", kind = "station", stage = 2, wage = 3 },
	{ key = "pink", name = "분홍 자판기", kind = "station", stage = 3, wage = 3 },
	{ key = "line", name = "연속 생산 설비", kind = "station", stage = 4, wage = 3 },
	{ key = "display", name = "진열", kind = "display", level = 5, wage = 2 },
	{ key = "cashier", name = "계산", kind = "cashier", level = 5, wage = 2 }, -- D58: Lv6 → 5 (2단계 기계와 같은 때)
	{ key = "f_sugar", name = "공장 ① 설탕 넣기", kind = "factory", factoryKey = "sugar", wage = 6 },
	{ key = "f_boil", name = "공장 ② 끓이기", kind = "factory", factoryKey = "boil", wage = 6 },
	{ key = "f_press", name = "공장 ③ 붓기·찍기", kind = "factory", factoryKey = "press", wage = 6 },
	{ key = "f_inspect", name = "공장 ④ 식히기·검사", kind = "factory", factoryKey = "inspect", wage = 6 },
	{ key = "f_pack", name = "공장 ⑤ 포장", kind = "factory", factoryKey = "pack", wage = 6 },
}
-- 진열 알바 (D33): 보관함 → 진열대 빈 칸, 4초에 1개. 옮길 게 없으면 쉼(급여 없음). 손 제작품도 옮길지 = 데이터 displayHand (기본 켬)
-- 2026-11-26 사용자: "진열 알바가 너무 빨라서 걷는 모션이 안 보임" → walkSpeed 6.5 (걸어간 길 길이로 시간을 셈),
--   한 번 갔다 올 때까지 다음 것을 안 놓음. 걷는 길 (사진: 카운터 왼쪽 끝 → 카운터와 손 작업대 사이 안쪽 바닥 → 오른쪽 벽 걸이판,
--   가게 앞쪽 탁자·의자 쪽은 안 다님): 부지 로컬 경유점 route (틀 PlotLayout에 부품 DisplayRoute1, 2, …를 넣으면 그 자리가 우선).
--   목표 칸이 부지 로컬 x < routeMinX(걸이판·작은 탁자 쪽)일 때만 경유점을 지나고, 마지막 경유점 → 칸 앞은 길 찾기(HelperPath)
G.DisplayHelper = {
	seconds = 4, -- 다음 것을 놓기까지 가장 짧은 간격
	walkSpeed = 6.5, -- 스터드/초
	routeMinX = 0,
	route = { Vector3.new(9, 0, -13.5), Vector3.new(0, 0, -12), Vector3.new(-9, 0, -12.5) },
}
-- 계산 알바 (D43, D56에서 바뀜): 자동 계산(맨 앞 손님 0.8초, G.Checkout) · 모든 판매 팁 +5% · 손님 수요 +10%. 자리 비운 동안은 안 함
-- 들고 가서 진열하는 알바 (2026-11-24 사용자): 4단계 기계 알바·공장 포장 알바는 만든 달고나를 보관함에 두고, 하나씩 들고 빈 진열 칸으로
-- 걸어가 놓음 (가는 동안 그 칸을 예약). posts = 역할 key → 옮기는 달고나 src (item.src). 연출은 제작 세션 (미니미 속성 Carry*)
G.CarryHelpers = {
	posts = { line = "line", f_pack = "factory" },
	speed = 7, -- 걷는 빠르기 (스터드/초)
	pickSeconds = 0.6, -- 집기·놓기
	minWalk = 1.5, -- 가까워도 이만큼은 걸음 (초)
}
-- 기계·가구 버튼(ProximityPrompt)이 뜨는 거리 (2026-11-24 사용자 "가구 더 가까이 가야 뜨게"): 작업대·2~4단계 기계·공장 제어대·공정 내가 하기·냉장고·서랍장
G.PromptDistance = 6
-- 골목·가게 둘레 (2026-11-24 사용자, 판매 세션)
G.ShopWorld = {
	-- 카메라: 멀리서 마을 전체를 내려다보지 못하게 (클라 ShopWorld). 제작 화면(Scriptable)에는 안 씀
	cameraMaxZoom = 34, -- 캐릭터에서 카메라까지 최대 거리
	cameraMaxHeight = 20, -- 캐릭터 머리 위로 카메라가 올라갈 수 있는 최대 높이 (가게 지붕 약 16~29보다 낮게 → 지붕 너머로 마을이 안 보임)
	-- 가게와 가게 사이 틈 담벼락 (서버 AlleyBuilder): 길 앞선에서 recess만큼 틈 안쪽에 세움 (틈 앞 화분·연탄은 길 쪽에 남음)
	-- stair = 2층 바깥 계단이 벽 밖으로 나온 폭 (가게 3D 3판 2026-11-27, 가게 로컬 -X 쪽. 벽 반폭은 20.85)
	gapWall = { recess = 10, height = 12, buildingHalf = 21.1, stair = 10.6 }, -- buildingHalf = 가게 3D 벽 반폭 (PlotLayout.ShopModel 벽 x ±21.1)
	-- 가게 안 출입: 내 가게, 그리고 남의 가게 중 열린 곳(월세 내고 연 가게·산 가게)만. 가게 앞선(부지 로컬 z) 안쪽을 막음
	gate = { z = -17.6, halfWidth = 21.2, depth = 60, height = 14 },
}
-- 가게 안 약한 조명 (2026-11-24 사용자: 예전 천장 등은 너무 밝아 화면이 안 보였음 → 아주 약하게, 전구 모양 없이 빛만)
-- strength 하나로 세기를 바꿈 (0 = 끔, 0.3 = 아주 약함, 1 = 예전 밝기쯤). 자리는 가게 기준 로컬 { x, z } (-Z = 골목 쪽)
G.ShopLight = {
	strength = 0.3,
	color = Color3.fromRGB(255, 200, 140), -- 따뜻한 주황빛
	range = 16,
	y = 9, -- 가게 바닥 위 높이
	spots = { { -10, -8 }, { 10, -8 }, { -10, 4 }, { 10, 4 } },
}
-- 주문 제작 손님 (D55, 2026-11-25 확정, 서버 OrderService): 손님 7종이 가끔 주문서를 들고 옴. 동시에 1명, 접속 중에만 (저장 안 함)
G.OrderCustomer = {
	level = 3, -- 가게 임대 뒤 (G.shopOpen도 봄)
	every = 180, -- 주문이 끝나고(채움·떠남) 다음 주문 손님까지 초 (±spread)
	spread = 0.3,
	firstDelay = 60, -- 들어와서 첫 주문 손님까지 (±spread)
	wait = 240, -- 기다리는 초 (D58: 180 → 240, 손 한 판 60~90초)
	waitBonus = 60, -- Epic 이상 도안이거나 포장 주문이면 더
	newMult = 1.5, -- 주문 뒤 새로 만든 것: 판매가 ×
	preMult = 1.3, -- 주문 전에 만들어 둔 것 (진열대·보관함)
	perfectNew = 2.0, -- Perfect면 ×2 / ×1.7
	perfectPre = 1.7,
	tip = { kid = 0, regular = 0.10, tourist = 0.15, vip = 0.30 }, -- 손님 종류 팁
	exp = 20, -- 주문 한 번
	hearts = 3, -- 그 손님 하트 판매 수 + (D38)
	vipLevel = 15, -- 부엉이 주문은 Lv15부터
	-- 손님 종류별 주문 (GDD 15장 표): 도안 등급 범위, 최소 품질, 포장(true/false/"sometimes"), 개수
	orders = {
		kid = { grades = { "Common", "Uncommon" }, minQ = "Normal", pack = false, n = { 1, 1 } },
		regular = { fav = true, minQ = "Good", pack = "sometimes", packChance = 0.35, n = { 1, 2 } },
		tourist = { minGrade = "Rare", minQ = "Good", pack = true, n = { 1, 2 } },
		vip = { minGrade = "Legendary", minQ = "Excellent", pack = true, n = { 1, 1 } },
	},
}
-- 골목 슈퍼마켓 (D54, 2026-11-25 확정, 서버 MarketService): 슈퍼 계산대에서 사서 봉지에 들고 가게로, Lv10 전화 배달
G.Market = {
	radius = 14, -- 계산대(부품 속성 MarketCounter)에서 이 거리 안에서만 장보기
	bagMid = 60, -- 봉지 크기: 개수 합이 이보다 적으면 소, bagBig 미만이면 중, 그 이상 대
	bagBig = 200,
	phoneLevel = 10, -- 전화 배달 Lv
	phoneMult = 1.1, -- 배달비 10%
	phoneDelay = 60, -- 배달 도착 초
	-- 봉지를 냉장고로 넣는 "내 가게 안" 판정 (부지 기준 로컬): 앞선 z -18 안쪽, 폭 ±21, 뒤 끝 60
	shopFrontZ = -18,
	shopBackZ = 60,
	shopHalfWidth = 21.5,
}
-- 골목 슈퍼·문방구 선반 (2026-11-28 사용자 "몇 분마다 재고가 들어와 선반을 채우고, 선반 물건을 누르면 산다", 서버 ShelfShopService)
--   재고는 서버 하나에 공용 (선반에 보이는 봉지·모양틀 하나 = 재고 하나). 누가 사면 그 자리가 비고, restockSeconds마다 빈 자리를 모두 채움.
--   슈퍼 봉지 1개 = 그 재료 1팩 (설탕 10회분 30코인 / 소다 10회분 10코인, 값은 G.Ingredients 그대로). 계산대 장보기는 재고 없이 그대로.
--   restockSeconds 근거 (GDD 4장 수요: Lv8~9 판매 분당 약 3.5개, 설탕 1개당 평균 약 1.5회분·소다 1회분):
--     한 사람이 쓰는 양 = 설탕 약 0.5팩/분, 소다 약 0.35팩/분. 선반 재고 = 설탕 22팩, 소다 7팩 (alley_shops_fix_1128.lua).
--     서버에 3명이 선반으로만 사면 설탕 약 1.6팩/분, 소다 약 1팩/분 → 소다가 약 7분이면 바닥 → 5분마다 채우면 거의 늘 남고,
--     많이 사는 사람이 몰리면 잠깐 품절(계산대는 언제나 됨). 모양틀은 23종 한 개씩이라 같은 주기.
--   모양틀: 아직 안 열린 도안을 레벨 해금(G.UnlockLevel)보다 levelAhead 레벨 먼저 미리 삼. 값 = cutterPrice[등급] (임시값:
--     그 등급 해금 레벨쯤 순이익 약 30~40분어치). Master(도감 조건)·이미 가진 도안은 안 팜. 국자는 구경용 (국자 아이템 없음, D39)
G.ShelfShop = {
	restockSeconds = 300,
	clickDistance = 12, -- 선반 물건을 누를 수 있는 거리 (가게 안에서)
	levelAhead = 2,
	cutterPrice = { Uncommon = 300, Rare = 800, Epic = 2000, Legendary = 5000, Mythic = 12000 },
}
-- 건설(꾸미기) 모드 (D53 안 A, 2026-11-25 확정, 서버 BuildService): 가게 안 물건을 2스터드 격자·90° 회전으로 옮김. 좌표는 부지 기준 로컬
G.Build = {
	cell = 2, -- 격자 한 칸 (스터드)
	pad = 0.05, -- 겹침 검사 때 사각형을 이만큼 줄임 (딱 붙여 놓기 허용)
	-- 놓을 수 있는 범위: 가게 앞 카운터 줄(z -24)부터 앞 방 뒷벽(z 15)까지, 벽 안 (x ±21)
	area = { x0 = -21, x1 = 21, z0 = -24, z1 = 15 },
	-- 길 검사 범위·입구: 가게 앞 골목 한 줄(z -30)까지 포함. 입구 = 틀 Entry 자리
	walk = { x0 = -22, x1 = 22, z0 = -30, z1 = 16 },
	entry = Vector3.new(-10, 0, -27),
	frontZ = -18, -- 이 안쪽은 건물 벽 안(|x| ≤ wallHalf)만 걸음
	wallHalf = 21,
	-- 고정물 (바닥을 차지하는 것): 손 작업대(가게 안, 화면 1/2 크기), 공장 문 (앞 3스터드 비움)
	fixedNames = { "Workstation", "FactoryDoor" },
	fixedPad = { FactoryDoor = 3 },
	fixedScale = { Workstation = 0.5 },
	fixedRoles = {},
	-- 옮길 수 있는 물건: key, 이름, 가게 3D Role(그 부품의 노드째 옮김) 또는 부지 안 부품 이름, needPath = 손님·알바가 옆까지 가야 함
	-- 유리 진열장은 카운터 위에 얹혀 있어 카운터와 한 덩어리. 걸이판·벽 선반은 벽에 붙어 고정
	items = {
		{ key = "counter", name = "계산대·유리 진열장", roles = { "앞 카운터 (나무)", "유리 진열장", "진열장 받침 (금속)", "진열 이름표 띠" }, needPath = true },
		{ key = "table1", name = "작은 탁자", roles = { "작은 탁자" }, needPath = true },
		{ key = "table2", name = "작은 탁자 2", roles = { "작은 탁자 2" }, needPath = true },
		{ key = "table3", name = "작은 탁자 3", roles = { "작은 탁자 3" }, needPath = true },
		{ key = "fridge", name = "냉장고", roles = { "냉장고" } },
		{ key = "drawer", name = "서랍장", roles = { "서랍장" } },
		-- 벽에 거는 물건 (2026-11-28 사용자 "가격표·포스터·냉장고 위 선반도 가구로"): wall = 바닥 가구와는 안 겹침 검사 (높이가 달라서)
		{ key = "menu", name = "메뉴판", roles = { "뒷벽 메뉴판 (나무 테)" }, wall = true },
		{ key = "poster", name = "포스터", roles = { "포스터" }, wall = true },
		{ key = "shelf", name = "벽 선반", roles = { "위 선반", "아래 선반", "재료 병 (흑설탕)", "재료 병 (땅콩 가루)", "재료 병 (설탕)", "재료 병 (캐러멜)", "재료 병 (콩가루)", "재료 병 (소다)", "재료 병 (계피)", "병 뚜껑" }, wall = true },
		{ key = "m2", name = "철제 판매기 자리", names = { "MachineSlot2" }, machine = true },
		{ key = "m3", name = "분홍 자판기 자리", names = { "MachineSlot3" }, machine = true },
		{ key = "m4", name = "연속 생산 설비 자리", names = { "MachineSlot4" }, machine = true },
	},
}
-- 작은 탁자 테이블보 (2026-11-24 사용자, SalesService tableCloth): 흰 천 위에 파스텔 꽃무늬 천을 마름모로.
-- texture = 꽃무늬 그림 id (3D 세션이 주면 넣음, nil이면 단색), tile = 무늬 한 장 크기(스터드)
G.ShopCloth = {
	white = Color3.fromRGB(252, 250, 244),
	floral = Color3.fromRGB(226, 238, 222), -- 참고 사진처럼 연한 민트·크림 바탕 (무늬는 texture)
	texture = "rbxassetid://131309504197388", -- 3D 세션 tools/floral_tile.py (512×512 반복 꽃무늬, 크림·민트 + 파란 꽃)
	tile = 2,
}
G.Cashier = { demandMult = 1.1, browseMult = 0.5, tip = 0.05 }

-- 계산 (D56, GDD 16장, 2026-11-25 확정 안 A): 손님은 진열대에서 고른 것을 찜하고 카운터 앞(CustomerSpot)에 줄,
-- 플레이어가 [계산](Remotes.Checkout)해야 팔림. 계산 알바(D43)가 있으면 자동 계산 → 효과 "자동 계산 · 팁 +5% · 수요 +10%"
G.Checkout = {
	queueMax = 4, -- 가게 줄 (카운터 앞부터 뒤로)
	stallQueueMax = 2, -- 노점: 작업대 옆 쟁반 앞
	gap = 2.6, -- 줄 사이 (스터드)
	patience = 60, -- 줄에서 기다리는 초 (D58: 45 → 60). 다 되면 달고나를 돌려놓고 떠남 (벌 없음)
	makingSlow = 0.5, -- 주인이 손으로 만드는 중(플레이어 속성 Making)이면 인내가 이 배로 줄어듦
	fastTip = { within = 5, mult = 0.05 }, -- 맨 앞이 된 지 5초 안에 플레이어가 계산하면 팁 +5% (계산 알바 팁과 겹치지 않음)
	cashierSeconds = 0.8, -- 계산 알바 자동 계산 (맨 앞 손님마다)
	-- [계산] 버튼 거리 (2026-11-26): 맨 앞 손님은 카운터 앞(CustomerSpot, 카운터 앞면에서 약 1.6), 주인은 카운터 뒤에서 약 9 →
	-- PromptDistance 6 + 카운터 깊이 ≈ 10. 서버는 reach + 3(지연 여유)보다 멀면 거절
	reach = 10,
	browsingMax = 3, -- 줄 말고 진열대 쪽에서 고르거나 기다리는 손님 (예전 G.Sales.maxCustomers 자리)
}

-- 손님 7종 (D37·GDD 14장, 2026-11-24): 레벨 구간마다 오는 비율, 종류마다 고르는 것·개수·팁. 손님 모델 id = CustomerRig.order
--  kid = 진열대에서 가장 싼 것 1개 / regular = 좋아하는 도안(custFav)부터 1~2개, 좋아하는 걸 사면 그 달고나 팁 +10%
--  tourist = Rare 이상 먼저 2~3개 / vip = Legendary 이상·Perfect·포장한 것만 2~3개, 팁 +20%, 없으면 그냥 감
-- 손님 수·사는 개수 합계(5-1 수요)는 그대로: 방문 간격을 (이 레벨 손님 평균 개수 ÷ 수요 표 평균 개수)만큼 늘려 맞춤.
-- 팁은 계산 알바(+5%)와 더함 (곱하지 않음)
G.Customers = {
	bands = { 4, 9, 14, 19, math.huge }, -- Lv1~4 / 5~9 / 10~14 / 15~19 / 20~
	types = {
		{ id = "Pongpong", name = "퐁퐁이", kind = "kid", weights = { 30, 22, 16, 12, 10 } },
		{ id = "Mochi", name = "설기", kind = "kid", weights = { 25, 20, 16, 13, 11 } },
		{ id = "Dotori", name = "도토리", kind = "kid", weights = { 20, 18, 16, 14, 12 } },
		{ id = "Godeungeo", name = "고등어 아저씨", kind = "regular", weights = { 15, 16, 16, 16, 15 } },
		{ id = "Kkuldanji", name = "꿀단지", kind = "regular", weights = { 10, 14, 16, 17, 17 } },
		{ id = "Ppogeuli", name = "뽀글이", kind = "tourist", weights = { 0, 8, 14, 18, 20 } },
		{ id = "Owl", name = "부엉이", kind = "vip", weights = { 0, 2, 6, 10, 15 } },
	},
	kinds = {
		kid = { min = 1, max = 1 },
		regular = { min = 1, max = 2, favTip = 0.10 },
		tourist = { min = 2, max = 3, minGrade = "Rare" },
		vip = { min = 2, max = 3, tip = 0.20, minGrade = "Legendary" },
	},
}

local GRADE_ORDER = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Master = 7 }

local function bandOf(level)
	for i, top in ipairs(G.Customers.bands) do
		if (level or 1) <= top then
			return i
		end
	end
	return #G.Customers.bands
end

-- 이 레벨에서 올 손님 하나 고르기 (rand = 0~1, 없으면 math.random)
function G.rollCustomer(level, rand)
	local b = bandOf(level)
	local total = 0
	for _, t in ipairs(G.Customers.types) do
		total += t.weights[b]
	end
	local r = (rand or math.random()) * total
	for _, t in ipairs(G.Customers.types) do
		r -= t.weights[b]
		if r < 0 then
			return t
		end
	end
	return G.Customers.types[1]
end

-- 이 레벨 손님 1명이 평균 몇 개 사려는가 (방문 간격 맞추기)
function G.customerMeanBuy(level)
	local b = bandOf(level)
	local total, sum = 0, 0
	for _, t in ipairs(G.Customers.types) do
		local k = G.Customers.kinds[t.kind]
		total += t.weights[b]
		sum += t.weights[b] * (k.min + k.max) / 2
	end
	return total > 0 and sum / total or 1
end

function G.customerType(id)
	for _, t in ipairs(G.Customers.types) do
		if t.id == id then
			return t
		end
	end
	return nil
end

-- 진열대 달고나 list에서 손님 t가 살 순서 (vip는 원하는 것만). 반환: 순서대로 고른 목록, 달고나마다 손님 팁 비율 함수
-- item: s = 도안 id, g = 품질 등급, p = 판매가, pk = 포장, gr = 도안 등급(없으면 shapeGrade(s)로 찾음)
function G.customerPick(list, t, favShape, shapeGrade)
	local kind = G.Customers.kinds[t.kind]
	local function grade(it)
		return GRADE_ORDER[shapeGrade and shapeGrade(it.s) or "Common"] or 1
	end
	local function price(it)
		return tonumber(it.p) or 0
	end
	local out = {}
	if t.kind == "kid" then
		for _, it in ipairs(list) do
			table.insert(out, it)
		end
		table.sort(out, function(a, b)
			return price(a) < price(b)
		end)
	elseif t.kind == "regular" then
		for _, it in ipairs(list) do
			if favShape and it.s == favShape then
				table.insert(out, it)
			end
		end
		for _, it in ipairs(list) do
			if not (favShape and it.s == favShape) then
				table.insert(out, it)
			end
		end
	elseif t.kind == "tourist" then
		local need = GRADE_ORDER[kind.minGrade]
		for _, it in ipairs(list) do
			if grade(it) >= need then
				table.insert(out, it)
			end
		end
		for _, it in ipairs(list) do
			if grade(it) < need then
				table.insert(out, it)
			end
		end
	else -- vip: 원하는 것만
		local need = GRADE_ORDER[kind.minGrade]
		for _, it in ipairs(list) do
			if grade(it) >= need or it.g == "Perfect" or it.pk then
				table.insert(out, it)
			end
		end
	end
	local function tipFor(it)
		if t.kind == "vip" then
			return kind.tip
		elseif t.kind == "regular" and favShape and it.s == favShape then
			return kind.favTip
		end
		return 0
	end
	return out, tipFor
end
G.Helper = {
	seconds = 40, -- 1판 (기본 알바생)
	wagePer30s = 3, -- 일하는 동안만
	qMin = 50, -- 품질 Normal~Good
	qMax = 84,
	maxGrade = "Legendary", -- 자동 생산은 Legendary까지 (D13)
	chopsticks = 0, -- 젓가락 안 씀 (G.ChopsticksPerHelperRound, 2026-11-21)
	skillSeconds = { [0] = 40 }, -- (옛 값) 화로 속도는 아래 stoveSeconds
	-- 화로 알바 교육 (D40): 숙련 35초, 전문 30초 + 품질 Good~Excellent
	skilledSeconds = 35,
	expertSeconds = 30,
	expertQMin = 70,
	expertQMax = 94,
	machineWagePer30s = 3, -- 기계에 배치한 알바생 급여 (기계가 도는 동안만, 한 판 끝날 때 냄) = G.HelperPosts 기계 wage
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
	rowZ = -72, -- 남쪽 줄 가운데 (앞 = 월드 +Z)
	-- 2026-11-23 사용자 "부지 3곳이 마주 보는 걸로" (GDD §9): 길(가운데 z -38, 폭 32) 양쪽에 3칸씩 마주 봄
	rowZNorth = -4, -- 북쪽 줄 가운데 (앞 = 월드 -Z, 뒤 공장 방은 +Z 쪽)
	-- 번호 → { 칸(x = 칸 × spacing), 줄 }. 먼저 온 두 사람이 가운데에서 마주 보게 남·북을 번갈아 채움
	slots = { { 0, "S" }, { 0, "N" }, { -1, "S" }, { -1, "N" }, { 1, "S" }, { 1, "N" } },
	-- 2026-11-27 가게 3D 3판(store-1, 폭 41.7 + 로컬 -X 쪽 2층 바깥 계단 10.5 + 로컬 +X 쪽 뒤 전봇대 7): 사용자 "간격을 넓혀서
	-- 계단과 전봇대·옆 가게가 겹치지 않게" → 55 → 66 (계단 끝 ~ 옆 가게 전봇대 약 6.7, 계단 끝 ~ 옆 가게 벽 약 13.8)
	spacing = 66, -- 같은 줄 안 간격. 2026-11-23 사용자 가게 3D(폭 46.7, 뒤에 자체 공장 방)로 바꾸며 100 → 55 (사이 약 8)
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
	entry = Vector3.new(-10, 0, -28), -- 접속하면 서는 곳: 내 가게 앞 골목. 2026-11-23 새 가게 3D 의자(앉는 자리) 옆을 피해 옮김 (틀 Entry도 같은 자리)
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
	lockedWhenStall = { train = true, hire = true, table = true, machine = true },
}

---------------------------------------------------------------- 기계 2~4단계 (20번, SHOP_GROWTH_PLAN 1·3~5장, D9·D10)
-- 가게 뒤 기계 1자리에서 단계대로 교체. 한 판 = batch개 / seconds초 (시간당 4 → 6 → 10개/분)
G.Machines = {
	[2] = { id = "steel", name = "철제 판매기", level = 5, price = 5000, batch = 2, seconds = 30 }, -- D46: Lv10·15,000 → Lv5·5,000
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
	-- 알바 없는 공정은 내가 직접 (D45, 2026-11-24 확정): 서 있으면 알바와 같은 효과(급여 없음), 판마다 짧은 미니게임을 잘하면 그 판만 더 좋게.
	-- 한 번에 한 공정, 공장 방(부지)을 나가거나 그 자리에 알바를 고용하면 끝, 오프라인 효과 없음, 그동안 손 제작 못 함
	selfWork = {
		exp = 2, -- 미니게임 잘한 판마다
		minigameSeconds = 5, -- 클라이언트 미니게임 길이 (3~5초)
		answerWindow = 30, -- 판이 시작되고 이 안에 결과를 보내야 셈
		sugarSave = 0.20, -- ① 잘한 판: 설탕 -20% (알바 -10%)
		boilUpChance = 0.25, -- ② 품질 한 칸 위 25% (알바 15%)
		pressTime = 0.85, -- ③ 시간 -15% (알바 -10%)
		inspectNoPoor = true, -- ④ Poor 없음 (알바 절반)
		packTip = 0.05, -- ⑤ 자동 포장 ×1.1 + 그 판 판매가 +5%
	},
	-- 공장 손재주 (D49, 2026-11-24 확정): 공정마다 따로 0~3단계 (저장 factorySkill[공정 key]), 공장을 산 뒤에만, 1 → 2 → 3 차례로.
	-- 미니게임 판정만 쉬워짐 (D45 효과 최대치는 그대로). 1 = 판정 폭 ×1.3, 2 = ×1.6, 3 = (×1.6 그대로) 성공 기준 80 → 60 + 40~59점은 효과 절반.
	-- 도와주기 (무료): 같은 공정 3판 연속 실패 → 다음 판 판정 폭 +30% (성공하면 꺼짐), 손재주와 더해 최대 +90%
	skill = {
		costs = { 3000, 7000, 15000 }, -- 공정마다 같은 값 (15칸 다 사면 125,000)
		width = { 1.3, 1.6, 1.6 }, -- 단계별 판정 폭 배율 (0단계 = 1)
		pass = 80, -- 성공 점수 (0~3단계 공통, 클라 score 0~100)
		passTop = 60, -- 3단계 성공 점수
		halfMin = 40, -- 3단계: 이 점수 ~ passTop 아래는 효과 절반
		assistAfter = 3, -- 연속 실패 판 수
		assistWidth = 0.3, -- 도와주기 판정 폭 +
		maxBonus = 0.9, -- 손재주 + 도와주기 최대 + (폭 1.9배)
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

-- 진열장 업그레이드 6단계 (D57, GDD 17장, 2026-11-26 사용자 승인). d.displayTier = 0~5 (산 단계, 기본 0).
-- slots = 그 단계까지 진열 칸 합계. 칸이 열리는 순서는 아래 G.SlotOpenOrder (2026-11-26 사용자: 작은 탁자 3개가 다 진열되게 —
-- 예전엔 칸 번호 순서(유리 진열장 → 걸이판 → 작은 탁자)라 50칸 단계에서 세 번째 탁자(53~61)가 비어 있었음).
-- 가구에 실제로 있는 칸(G.Sales.shelfSlots 73 = 61 + 벽면 진열장 12)보다 많으면 그만큼만
G.Display = {
	{ name = "기본 진열장", level = 3, cost = 0, slots = 8 },
	{ name = "유리 진열장 1", level = 4, cost = 600, slots = 16 },
	{ name = "유리 진열장 2", level = 6, cost = 1500, slots = 24 },
	{ name = "선반 진열대 1", level = 10, cost = 4000, slots = 36 },
	{ name = "선반 진열대 2", level = 15, cost = 12000, slots = 50 },
	{ name = "벽면 진열장", level = 20, cost = 30000, slots = 70 },
}
G.DisplayMigrateTier = 4 -- 예전 61칸을 쓰던 저장은 선반 진열대 2(50칸)를 준 것으로 (v17)
G.DisplayWallTier = 5 -- 이 단계부터 벽면 진열장 칸(62~) — 가게 3D에 WallDisplayCase가 없으면 그 단계는 아직 못 삼 (GrowthService)

function G.displayTier(d)
	return math.clamp(math.floor(tonumber(d and d.displayTier) or 0), 0, #G.Display - 1)
end

-- 진열 칸: 가게가 열려 있으면 산 진열장 단계만큼, 아니면 노점 쟁반 5칸
function G.shelfSlots(d)
	if not G.shopOpen(d) then
		return G.Shop.stallSlots
	end
	return math.min(G.Display[G.displayTier(d) + 1].slots, G.Sales.shelfSlots)
end

-- 진열 칸이 열리는 순서 (칸 번호 구간, SalesService GRID와 같음): 유리 진열장 1~4 → 작은 탁자 35~43 · 44~52 · 53~61 → 걸이판 5~34 → 벽면 진열장 62~73.
-- 칸 번호는 그대로라 저장(item.sl)은 안 바뀜. 단계마다 앞에서부터 G.shelfSlots개가 열림
G.SlotOpenOrder = { { 1, 4 }, { 35, 61 }, { 5, 34 }, { 62, 73 } }

-- 진열장 단계 tier(0~5)에서 열린 칸 번호 목록 (가게가 열렸을 때)
function G.openSlotsForTier(tier)
	local n = math.min(G.Display[math.clamp(tier, 0, #G.Display - 1) + 1].slots, G.Sales.shelfSlots)
	local out = {}
	for _, r in ipairs(G.SlotOpenOrder) do
		for i = r[1], math.min(r[2], G.Sales.shelfSlots) do
			if #out >= n then
				return out
			end
			table.insert(out, i)
		end
	end
	return out
end

-- 지금 열린 칸 번호 목록 (채우는 순서). 노점이면 쟁반 1~5
function G.openSlots(d)
	if not G.shopOpen(d) then
		local out = {}
		for i = 1, G.Shop.stallSlots do
			out[i] = i
		end
		return out
	end
	return G.openSlotsForTier(G.displayTier(d))
end

-- 칸 i가 지금 열려 있는지
function G.slotOpen(d, i)
	if type(i) ~= "number" then
		return false
	end
	for _, k in ipairs(G.openSlots(d)) do
		if k == i then
			return true
		end
	end
	return false
end

-- 냉장고·서랍장 (D57, 구매형): 한도는 재료마다. d.storageTier = { fridge = 0~3, drawer = 0~3 }
G.StorageTiers = {
	fridge = {
		{ name = "냉장고", level = 1, cost = 0, max = 100 },
		{ name = "큰 냉장고", level = 5, cost = 1500, max = 300 },
		{ name = "업소용 냉장고", level = 12, cost = 8000, max = 1000 },
		{ name = "대형 저온 창고", level = 20, cost = 30000, max = 3000 },
	},
	drawer = {
		{ name = "서랍장", level = 1, cost = 0, max = 100, coal = 20 },
		{ name = "큰 서랍장", level = 5, cost = 800, max = 300, coal = 60 },
		{ name = "업소용 서랍장", level = 12, cost = 4000, max = 1000, coal = 200 },
		{ name = "대형 서랍장", level = 20, cost = 15000, max = 3000, coal = 600 },
	},
}

-- 재료가 들어가는 곳 ("fridge" | "drawer", G.StorageGroups)
function G.storageGroupOf(id)
	for _, g in ipairs(G.StorageGroups) do
		if table.find(g.ids, id) then
			return g.key
		end
	end
	return "drawer"
end

function G.storageTier(d, key)
	local t = d and type(d.storageTier) == "table" and d.storageTier[key]
	return math.clamp(math.floor(tonumber(t) or 0), 0, #G.StorageTiers[key] - 1)
end

-- 재료 하나의 보관 한도 (산 단계 기준, 연탄은 따로). 이미 더 가진 건 없애지 않고 더 사지만 못 함
function G.ingredientMax(d, id)
	local key = G.storageGroupOf(id)
	local tier = G.StorageTiers[key][G.storageTier(d, key) + 1]
	if id == "coal" then
		return tier.coal or tier.max
	end
	return tier.max
end

---------------------------------------------------------------- 판매: 진열대 + 손님 NPC (Phase 3, D12)
G.Sales = {
	shelfSlots = 73, -- 진열 칸 (2026-11-24 격자: 유리 진열장 4 + 걸이판 6×5 + 작은 탁자 3×3 ×3 = 61, 2026-11-26 D57 벽면 진열장 4×3 = 62~73)
	maxCustomers = 3, -- 가게당 동시 손님
	-- 손님 수요 (GDD 5-1장 D12, 기획 세션 2026-11-20: 수요 ≈ 생산의 80%, 시뮬레이션 전 기획안)
	-- { 방문 간격(초), 1명당 최소, 최대 }
	-- 1단계(연탄 화로)는 레벨 구간으로 (D39, 2026-11-24: 국자 수 대신). { 이 레벨까지, 방문 간격, 최소, 최대 }
	demandByLevel = {
		{ 2, 60, 1, 1 }, -- Lv1~2 노점: 분당 1 (D58: 30 → 60초, 손 한 판 75초 기준)
		{ 4, 50, 1, 1 }, -- Lv3~4 가게: 분당 1.2 (D58: 24 → 50초)
		{ math.huge, 20, 1, 2 }, -- Lv5~ (D46: 2단계 기계를 살 수 있는 때, 아직 안 샀으면): 분당 약 4.5
	},
	-- 2~5단계: 기계·공장
	-- 2026-11-23 D32 (기계 2·3·4단계 모두 같이 돎): 수요 ≈ 생산의 80%로 올림 (기획 GDD 5-1, 사용자 승인). 분당 9 / 13.3 / 20 / 30
	demandByStage = {
		[2] = { 20, 1, 2 }, -- 2026-11-24 D46 뒤 (화로 알바 없음): 분당 9 → 약 4.5 (생산 5.5의 약 80%)
		[3] = { 10, 1, 2 }, -- 분당 13.3 → 9 (생산 11.5의 약 80%)
		[4] = { 6, 1, 3 },
		[5] = { 6, 2, 4 },
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

-- 설비 단계·레벨 → 방문 간격(초, testSpeed 반영), 1명당 최소·최대 개수
function G.salesDemand(stage, level)
	local row
	if (stage or 1) <= 1 then
		local lv = level or 1
		for _, r in ipairs(G.Sales.demandByLevel) do
			if lv <= r[1] then
				row = { r[2], r[3], r[4] }
				break
			end
		end
	else
		row = G.Sales.demandByStage[math.min(stage, 5)]
	end
	return row[1] / math.max(G.Sales.testSpeed, 0.01), row[2], row[3]
end

-- 플레이어 데이터로 손님 수요: 가게 문이 닫혀 있으면(노점) 노점 수요, 기계도 가게 안에서만 (D21)
function G.salesDemandFor(d)
	if not G.shopOpen(d) then
		return G.salesDemand(1, 1)
	end
	local gap, lo, hi = G.salesDemand(d.machineStage or 1, d.level or 1)
	if G.helperAt(d, "cashier") then
		gap /= G.Cashier.demandMult -- 계산 알바 (D43): 손님 수요 +10%
	end
	return gap, lo, hi
end

-- 알바생 배치 (D34)
function G.helperPost(key)
	for _, p in ipairs(G.HelperPosts) do
		if p.key == key then
			return p
		end
	end
	return nil
end

-- 그 역할이 열렸나 (D43): 기계는 산 뒤, 공장 공정은 공장을 산 뒤, 화로·진열·계산은 가게를 임대하고 그 레벨부터
function G.hasPost(d, key)
	local p = G.helperPost(key)
	if not p then
		return false
	end
	if p.kind == "factory" then
		return d.factory ~= nil and d.factory.unlocked == true
	end
	if p.stage and p.stage >= 2 then
		return (d.machineStage or 1) >= p.stage
	end
	return d.shop ~= nil and d.shop.state ~= "stall" and (d.level or 1) >= (p.level or 1)
end

-- 공장 공정 key에 알바생이 있나 (D30 → D43)
function G.factoryStaffed(d, factoryKey)
	return G.helperAt(d, "f_" .. factoryKey) ~= nil
end

-- 그 제작대에 배치된 알바생 번호 (없으면 nil)
function G.helperAt(d, key)
	for i, h in ipairs(d.partTimers or {}) do
		if h.post == key then
			return i
		end
	end
	return nil
end

-- 화로 알바 한 판 초·품질 (D40)
function G.stoveHelperSpec(d)
	local ups = d.stoveUps or {}
	local H = G.Helper
	if ups.expert then
		return H.expertSeconds, H.expertQMin, H.expertQMax
	elseif ups.skilled then
		return H.skilledSeconds, H.qMin, H.qMax
	end
	return H.seconds, H.qMin, H.qMax
end

---------------------------------------------------------------- 오프라인 생산 (D29, 2026-11-22 사용자 결정, 수치는 임시)
-- 알바생·기계·공장은 접속하지 않은 동안에도 각자 규칙대로 만든다 (손 제작은 안 됨). 들어올 때 한 번에 정산
G.Offline = {
	maxHours = 8, -- 최대 이만큼만 셈
	minSeconds = 60, -- 이보다 짧게 나갔다 오면 정산 안 함
	step = 1, -- 시뮬레이션 간격(초)
	speed = 0.5, -- 자리 비운 동안은 절반 속도로 만듦 (D42, 2026-11-24: D29 고침)
	reportDelay = 4, -- 들어온 뒤 요약 팝업을 보내기까지 (화면 준비)
	-- 판매 없음, 월세 없음. 나갈 때 가게 문이 닫혀 있었으면 알바생·기계·공장 모두 멈춘 채
}

---------------------------------------------------------------- 첫 60초 안내 (21번, 2026-11-22, DEVELOPMENT_PLAN 6장 Phase 6)
-- 할아버지 NPC가 말풍선으로 단계마다 알려 줌. 새 플레이어(tutorialDone = false)만. 건너뛰기 가능
G.Tutorial = {
	nearDistance = 11, -- 작업대에 이만큼 가까이 가면 1단계 끝
	hurryCustomer = true, -- 첫 달고나를 진열하면 손님이 바로 옴
	-- 만드는 동안 안내 판: 화면 아래 가운데, 작게, 버튼 없이 입력을 막지 않게 (제작 화면 위쪽 0~190은 게이지·막대가 씀, 제작 세션 2026-11-22)
	makePanel = { width = 420, height = 72, bottom = 16, maxWidthScale = 0.48 },
	steps = {
		{ key = "go", text = "어서 와! 여기가 네 노점이란다. 반짝이는 작업대로 가 보렴", target = "workstation" },
		{ key = "press", text = "작업대 앞에서 E를 누르면 달고나를 만들 수 있어", touchText = "작업대 앞에서 손 모양 버튼을 누르면 달고나를 만들 수 있어", target = "workstation" },
		{ key = "make", text = "모양을 고르고, 설탕을 녹이고 소다를 넣어 부풀린 다음 붓고 눌러서 찍어 보렴", target = nil },
		{ key = "place", text = "잘했다! 진열장이나 벽 걸이판을 눌러서 달고나를 놓아 보렴", touchText = "잘했다! 진열장이나 벽 걸이판을 눌러서 달고나를 놓아 보렴", target = "shelf" },
		{ key = "sale", text = "곧 손님이 와서 골라 카운터 앞에 줄을 설 거야. 손님 위 [계산]을 눌러 팔아 보렴", touchText = "곧 손님이 와서 골라 카운터 앞에 줄을 설 거야. 손님 위 [계산]을 눌러 팔아 보렴", target = "shelf" },
		{ key = "shop", text = "첫 장사 축하한다! 재료가 떨어지면 골목 슈퍼에서 사 오면 돼. [슈퍼 가기] 버튼을 눌러 보렴", target = "shopButton" },
	},
	doneText = "이제 혼자서도 잘하겠구나. 맛있는 달고나 많이 팔아라!",
}

---------------------------------------------------------------- 폰 성능 (2026-11-22, docs/PERFORMANCE_BUDGET.md)
G.Perf = {
	factoryLodDistance = 120, -- 남의 공장이 카메라에서 이만큼 넘게 멀면 상자로 (FactoryLod)
	factoryLodMargin = 10, -- 다시 원래 모습은 (거리 - 여유) 안으로 들어왔을 때 (경계에서 깜빡이지 않게)
	factoryProxyHeight = 0.55, -- 상자 높이 = 공장 높이 × 이 값
	lodCheckSeconds = 0.5,
	-- 남의 가게 작업대 소품 숨기기 (WorkstationLod, 2026-11-22): 화면 삼각형의 70%가 작업대 소품
	workstationLodDistance = 70, -- 남의 작업대가 이만큼 넘게 멀면 소품을 숨김 (옆 가게 40칸은 보이고, 두 칸 건너 80칸부터 숨김)
	workstationLodMargin = 8, -- 다시 보이는 건 (거리 - 여유) 안
	-- 숨길 소품 = 작업대 바로 아래 자식 이름 (화로·테이블·국자·철판·누름판·틀·러그는 남김)
	workstationHide = { "Stage1Decor", "SugarBowlWhite", "SugarBowlBrown", "WoodSpoon", "SodaTub", "SodaSpoon", "ChopstickCup" },
	workstationPackKeep = { "Mat" }, -- 포장 공간(PackArea)에서 남길 것 (비닐 통·빵끈 통은 숨김)
	-- 스트리밍 반경은 Studio Workspace 속성 (StreamingTargetRadius 256, 2026-11-22 1024에서 줄임)
}

---------------------------------------------------------------- 상점·요청 제한
G.ShopCooldown = 0.25 -- 초당 4번까지 구매

return G

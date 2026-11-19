-- 달고나 제작 미니게임 설정값 (DEVELOPMENT_PLAN.md 4장 v2)
-- 서버와 클라이언트가 같이 쓴다. 숫자를 바꾸면 양쪽 판정이 같이 바뀐다.

local C = {}

C.Weights = { T = 0.25, M = 0.20, P = 0.25, S = 0.30 }

-- 높은 점수부터. SYSTEMS_SPECIFICATION 2장 등급표
C.Grades = {
	{ min = 95, name = "Perfect", mult = 1.7, color = Color3.fromRGB(255, 196, 0) },
	{ min = 85, name = "Excellent", mult = 1.3, color = Color3.fromRGB(120, 200, 90) },
	{ min = 70, name = "Good", mult = 1.0, color = Color3.fromRGB(80, 160, 230) },
	{ min = 50, name = "Normal", mult = 0.8, color = Color3.fromRGB(150, 150, 150) },
	{ min = 30, name = "Poor", mult = 0.5, color = Color3.fromRGB(190, 120, 70) },
	{ min = 0, name = "Burnt", mult = 0.2, color = Color3.fromRGB(60, 40, 30) },
}

-- 별 개수 (결과 화면, QUALITY 링 아래)
C.StarCut = { 50, 70, 85 }

C.Shape = { id = "Star", name = "별", price = 22 } -- 기본 도안 (도안 목록은 ShapeCatalog)

C.Steps = {
	{ key = "sugar", label = "설탕", icon = "🥄", title = "설탕 넣기", desc = "백설탕 2스푼 + 황설탕 1/4" },
	{ key = "melt", label = "녹이기", icon = "🔥", title = "녹이기", desc = "불에서 살짝 띄워 저어요" },
	{ key = "soda", label = "소다", icon = "🧂", title = "소다", desc = "투명해지면 바로 톡!" },
	{ key = "pour", label = "붓기", icon = "🍯", title = "붓기", desc = "설탕 원 가운데에 부어요" },
	{ key = "press", label = "누르기", icon = "⚪", title = "누르기", desc = "3번 나눠서 꾹" },
	{ key = "stamp", label = "모양", icon = "⭐", title = "모양 찍기", desc = "틀을 올리고 살살" },
}

-- 단계 가중치 (QUALITY 링 실시간 표시용). T = 설탕 20% + 녹이기 80%, P = 붓기 30% + 누르기 70%
C.LiveWeights = {
	sugar = 0.25 * 0.2,
	melt = 0.25 * 0.8,
	soda = 0.20,
	pour = 0.25 * 0.3,
	press = 0.25 * 0.7,
	stamp = 0.30,
}

C.Sugar = {
	white = 2.0, -- 백설탕 2스푼
	brown = 0.25, -- 황설탕 1/4스푼
	scoopWhite = 1.0,
	scoopBrown = 0.25,
	pourRate = 1.8, -- 스푼/초 (완전히 기울였을 때)
	tiltPour = 40, -- 이 각도를 넘으면 쏟아짐
}

C.Melt = {
	slow = 4.0, -- rad/s 미만 = SLOW
	fast = 11.0, -- rad/s 초과 = FAST
	tempLow = 150,
	tempHigh = 185,
	burnTemp = 192,
	rate = 0.11, -- 적정 온도 + 적정 젓기일 때 초당 녹는 양 (약 10초)
	hMin = 0.15, -- 국자 높이 (철망 위 stud)
	hMax = 1.6,
}

C.Soda = {
	idealMin = 0.35,
	idealMax = 0.65,
	fastMin = 9.0, -- 소다 젓기는 이 속도 이상이 정답
	bestDelay = 2.0, -- 다 녹고 이 시간 안에 넣으면 만점
}

-- 붓기: 붓는 자리를 끌고 다니면 반죽이 길쭉해짐 (길이 / 폭). 이 값을 넘으면 틀이 안 맞아 실패
C.Pour = {
	failSpread = 1.8,
}

C.Press = {
	h0 = 0.45, -- 붓고 난 덩어리 두께
	targets = { 0.25, 0.14, 0.08 }, -- 3번 나눠 누르기
	crack = 0.055, -- 이보다 얇으면 가장자리 갈라짐
	k = 1.25, -- 누르는 동안 두께 감소율 (dh/dt = -k*h)
}

C.Stamp = {
	holdMin = 0.12,
	holdMax = 0.5,
	crackHold = 0.85,
}

-- 효과음 (Roblox 무료 효과음, Pro Sound Effects)
C.Sounds = {
	paperTear = "rbxassetid://9125724621", -- 종이 찢는 소리 1.1초
	stickSnap = "rbxassetid://9113581974", -- 나무젓가락 쪼개는 소리 0.7초
	-- 파일 앞쪽 무음 길이 (Studio에서 AudioAnalyzer로 잼). 여기서부터 재생해 누르는 순간 바로 들리게
	paperTearStart = 0.06,
	stickSnapStart = 0.09,
	-- 제작 소리 (2026-11-18 사용자가 고름. 비어 있으면 소리 없음)
	sugarPour = "rbxassetid://9113597694", -- 숟가락에서 설탕 쏟아지는 "사르르" (반복, 쏟는 양 = 크기)
	crack = "rbxassetid://9113959343", -- 달고나 금 가는 "쩌적" (한 번)
	fire = "rbxassetid://158853971", -- 연탄불 (반복, 국자가 가깝고 뜨거울수록 큼)
	stirDry = "rbxassetid://9120083178", -- 마른 설탕 젓기 "사각사각" (반복, 젓는 속도 = 재생 속도·크기)
	stirCrystal = "rbxassetid://9113381863", -- 결정 부딪히는 "톡톡"
	stirLiquid = "rbxassetid://9116146746", -- 녹은 시럽 젓기 (부드러움)
	stirCream = "rbxassetid://9126209045", -- 소다 넣은 뒤 걸쭉한 거품 젓기 (둔함)
	pressSticky = "rbxassetid://137866583821455", -- 누름판이 반죽에 닿고 뗄 때 끈적한 "쩍" (2026-11-19 요청, 임시 후보: Creator Store "goop slime sound effect")
	-- 귀여운 효과음 (2026-11-19 "효과음 들어가면 재미있을 것 같음", Creator Store 무료, Studio에서 불러와짐 확인)
	pop = "rbxassetid://6586979979", -- "뽁" 0.2초: 도구 집기 · 버튼 · 별 채우기
	stepDone = "rbxassetid://18448089848", -- 단계 끝 "띵"
	fanfare = "rbxassetid://1839881844", -- 결과 별 2개 이상 (APM "Spinning Around")
	pourGlug = "rbxassetid://9114622480", -- 반죽 붓는 "꿀렁" (반복)
	foamBubble = "rbxassetid://73232090200005", -- 소다 넣고 부풀 때 보글보글 (반복)
	sodaDrop = "rbxassetid://109359226723492", -- 소다 털어 넣을 때 "퐁"
	metalClink = "rbxassetid://9125781406", -- 모양틀 내려놓는 "땡"
	-- 앞쪽 무음 (AudioAnalyzer로 잼). 반복 소리도 이 구간부터 되풀이돼서 끊김이 없음
	sugarPourStart = 0.08,
	crackStart = 0.16,
	stirDryStart = 0.4,
	stirLiquidStart = 0.15,
	stirCreamStart = 0.12,
}

C.Server = {
	minStep = 1.5, -- 단계당 최소 시간 (초)
	maxStep = 120,
	maxTotal = 600,
	maxSamples = 60,
}

return C

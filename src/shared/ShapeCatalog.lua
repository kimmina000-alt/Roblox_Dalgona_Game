-- 도안 목록: 이름·외곽선은 CutterShapes(자동 생성), 가격·등급 순서는 여기서.
-- 가격: ECONOMY_BALANCE.md 3장. Master(최고 등급) 4종과 뼈다귀 15는 사용자 확정 (2026-11-19, GAME_DESIGN_DOCUMENT D6).
-- 저장이 아직 없어서 Phase 1에서는 전부 열려 있다 (해금은 Phase 4).

local CutterShapes = require(script.Parent:WaitForChild("CutterShapes"))

local Catalog = {}

Catalog.Grades = {
	{ id = "Common", label = "커먼", color = Color3.fromRGB(150, 150, 150) },
	{ id = "Uncommon", label = "언커먼", color = Color3.fromRGB(96, 178, 92) },
	{ id = "Rare", label = "레어", color = Color3.fromRGB(70, 140, 230) },
	{ id = "Epic", label = "에픽", color = Color3.fromRGB(160, 92, 220) },
	{ id = "Legendary", label = "레전더리", color = Color3.fromRGB(240, 160, 40) },
	{ id = "Mythic", label = "신화", color = Color3.fromRGB(230, 70, 80) },
	{ id = "Master", label = "마스터", color = Color3.fromRGB(30, 30, 36) },
}

local PRICE = {
	Circle = 10, Square = 12, Triangle = 12, Bone = 15,
	Heart = 18, Star = 22, Umbrella = 28,
	Flower = 35, Fish = 40, Bird = 45,
	Butterfly = 55, Airplane = 65, Cross = 60,
	Sword = 80, Sailboat = 95,
	Palace = 160, Tiger = 180, Dinosaur = 220, Octopus = 250, -- 문어: 공룡 다음 Mythic (D51, 2026-11-24)
	Spider = 300, Sierpinski = 340, Snowflake = 380, Lotus = 420,
}
local GRADE_OVERRIDE = { Bone = "Common", Octopus = "Mythic" } -- 뼈다귀 = 사용자 추가 도안, 문어 = Legendary → Mythic (D51)
-- 같은 등급 안 순서: CutterShapes 순서 대신 이 도안 바로 뒤 (D51: 문어는 공룡 다음)
local ORDER_AFTER = { Octopus = "Dinosaur" }

Catalog.default = "Star"

local gradeIndex = {}
for i, g in ipairs(Catalog.Grades) do
	gradeIndex[g.id] = i
end

Catalog.list = {}
Catalog.byId = {}
for order, s in ipairs(CutterShapes) do
	local grade = GRADE_OVERRIDE[s.id] or s.grade
	local entry = {
		id = s.id,
		name = s.name,
		grade = grade,
		gradeIndex = gradeIndex[grade] or 1,
		price = PRICE[s.id] or 20,
		data = s,
		order = order,
	}
	table.insert(Catalog.list, entry)
	Catalog.byId[s.id] = entry
end
for id, after in pairs(ORDER_AFTER) do
	local e, a = Catalog.byId[id], Catalog.byId[after]
	if e and a then
		e.order = a.order + 0.5
	end
end
table.sort(Catalog.list, function(a, b)
	if a.gradeIndex ~= b.gradeIndex then
		return a.gradeIndex < b.gradeIndex
	end
	return a.order < b.order
end)

function Catalog.get(id)
	return Catalog.byId[id]
end

-- 보관함·진열 아이템 이름 (달고나빵·민짜는 도안 이름 대신)
function Catalog.itemName(item)
	if type(item) ~= "table" then
		return ""
	end
	if item.bread then
		return "달고나빵"
	end
	local e = Catalog.byId[item.s or ""]
	local n = e and e.name or tostring(item.s or "")
	return item.plain and ("민짜 달고나") or n
end

function Catalog.grade(id)
	return Catalog.Grades[gradeIndex[id] or 1]
end

return Catalog

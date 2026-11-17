-- 도안 목록: 이름·외곽선은 CutterShapes(자동 생성), 가격·등급 순서는 여기서.
-- 가격: ECONOMY_BALANCE.md 3장. Master(최고 등급)와 뼈다귀는 문서에 없어서 임시 값 (승인 필요).
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
	Sword = 80, Sailboat = 95, Octopus = 110,
	Palace = 160, Tiger = 180, Dinosaur = 220,
	Spider = 300, Sierpinski = 340, Snowflake = 380, Lotus = 420, -- 임시
}
local GRADE_OVERRIDE = { Bone = "Common" } -- 사용자 추가 도안

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
table.sort(Catalog.list, function(a, b)
	if a.gradeIndex ~= b.gradeIndex then
		return a.gradeIndex < b.gradeIndex
	end
	return a.order < b.order
end)

function Catalog.get(id)
	return Catalog.byId[id]
end

function Catalog.grade(id)
	return Catalog.Grades[gradeIndex[id] or 1]
end

return Catalog

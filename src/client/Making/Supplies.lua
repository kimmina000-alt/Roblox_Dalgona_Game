-- 재료가 없으면 작업대 통이 빈 통으로 보이게 (2026-11-21 사용자: "설탕 없으면 설탕통 빈통으로. 다른 재료들도")
-- 서버(EconomyService.push)가 플레이어 속성 Ing_<재료 id>에 남은 양을 넣어 줌. 0이면 내 화면에서만 내용물을 숨김
-- (LocalTransparencyModifier: 다른 플레이어 화면·서버 부품 값은 그대로).
-- 작업대: 스폰 앞 공용 DalgonaWorkstation + 가게 부지 안 내 작업대(속성 OwnerUserId, 17b에서 생김)

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Supplies = {}

-- 재료 id → 작업대 안에서 숨길 내용물 { 모델 경로..., 부품 이름 } (모델 경로가 비면 작업대 바로 아래)
local CONTENTS = {
	sugar = {
		{ "SugarBowlWhite", "Sugar" },
		{ "SugarBowlWhite", "SugarHeapMesh" },
		{ "SugarBowlBrown", "Sugar" },
		{ "SugarBowlBrown", "SugarHeapMesh" },
	},
	soda = {
		{ "SodaTub", "Soda" },
		{ "SodaTub", "SodaPowderMesh" },
	},
	chopsticks = {
		{ "ChopstickCup", "CupStick" },
	},
	wrapper = {
		{ "PackArea", "BagTop" },
		{ "PackArea", "BagSheet" },
	},
	twistTie = {
		{ "PackArea", "CupTie" },
	},
}

local function workstations()
	local list = {}
	local shared = workspace:FindFirstChild("DalgonaWorkstation")
	if shared then
		table.insert(list, shared)
	end
	local plots = workspace:FindFirstChild("ShopPlots")
	if plots then
		for _, d in ipairs(plots:GetDescendants()) do
			if d.Name == "Workstation" and d:IsA("Model") and d:GetAttribute("OwnerUserId") == player.UserId then
				table.insert(list, d)
			end
		end
	end
	return list
end

-- 숨길 때 표시(SupplyHidden)를 남기고, 되돌릴 때는 내가 숨긴 것만 되돌림
-- (Station·ChopstickCup도 같은 값을 씀: 꺼낸 젓가락 등을 다시 보이게 하면 안 됨)
local function setHidden(container, partName, hidden)
	for _, p in ipairs(container:GetChildren()) do
		if p.Name == partName and p:IsA("BasePart") then
			if hidden then
				if p.LocalTransparencyModifier < 1 then
					p.LocalTransparencyModifier = 1
					p:SetAttribute("SupplyHidden", true)
				end
			elseif p:GetAttribute("SupplyHidden") then
				p.LocalTransparencyModifier = 0
				p:SetAttribute("SupplyHidden", nil)
			end
		end
	end
end

function Supplies.refresh()
	local stations = workstations()
	for id, list in pairs(CONTENTS) do
		local n = player:GetAttribute("Ing_" .. id)
		if id == "chopsticks" and n == nil then
			n = player:GetAttribute("Chopsticks")
		end
		-- 아직 저장 데이터를 못 받았으면(nil) 그대로 둠
		if n ~= nil then
			local empty = n <= 0
			for _, ws in ipairs(stations) do
				for _, e in ipairs(list) do
					local container = ws:FindFirstChild(e[1])
					if container then
						setHidden(container, e[2], empty)
					end
				end
			end
		end
	end
end

function Supplies.start()
	player.AttributeChanged:Connect(function(name)
		if name:sub(1, 4) == "Ing_" or name == "Chopsticks" then
			Supplies.refresh()
		end
	end)
	-- 작업대가 새로 생기거나(가게 배정) 꾸미기가 다시 붙을 수 있어서 가끔 다시 맞춤
	task.spawn(function()
		while true do
			Supplies.refresh()
			task.wait(2)
		end
	end)
end

return Supplies

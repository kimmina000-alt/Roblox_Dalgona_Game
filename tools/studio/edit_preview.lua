-- 편집(멈춘) 화면 = 게임 화면 (2026-11-28 사용자 "편집 화면에서도 플레이 화면처럼 맵 보이도록",
-- 같은 날 "게임 구현 화면과 동일한 화면으로, 내가 편집 모드에서 수정하면 게임에도 적용되도록").
-- Studio MCP execute_luau, datamodel = Edit 로 붙여 넣어 실행. 다시 돌려도 됨 (편집 화면에서 고친 것은 그대로 둠).
--
-- 무엇을 고치면 게임에 들어가나:
--  * 골목(Workspace.Alley): 처음 한 번 게임 코드로 만든 뒤 "굳힘"(속성 Baked). 이후로는 편집 화면의 골목이 원본 →
--    바닥·전봇대·가로등·자전거·화분·평상·꾸미기 가게를 옮기거나 지우면 게임에도 그대로 (AlleyBuilder.build가 지우지 않고 씀).
--    전선은 게임 시작 때 남은 전봇대끼리 다시 이음.
--  * 골목 슈퍼·문구사: 틀 Workspace.AlleyMarket·AlleyStationery (게임 자리에 그대로 놓여 있음)
--  * 가게: 틀 Workspace.PlotLayout (1번 가게 자리에 겹쳐 둠, 6칸 모두에 적용). 2~6번 가게는 보기용(잠김)
--  * 손 작업대: 틀 Workspace.WorkstationLayout → 1번 가게의 게임 속 자리(새로 온 손님 = 노점 자리)에 겹쳐 둠
--  * 2·3·4단계 기계: 틀 Workspace.MachineLayout.Stage2/3/4 → 1번 가게 기계 자리(MachineSlot2/3/4) 위에 겹쳐 둠
--  * 공장: 틀 Workspace.FactoryLayout → 1번 가게 공장 부지에 겹쳐 둠 (속성 LotCFrame도 같이)
--  틀을 통째로 옮길 때는 기준(SlotAnchor·LotCFrame·높이 속성)도 같이 옮기므로 게임 모습은 바뀌지 않음.
--  * Workspace 바로 아래 놓은 모델은 게임에도 그대로 나옴 (단, 위 틀 안에 넣어야 가게마다 복사·기능 연결이 됨)
local SSS = game:GetService("ServerScriptService")
local SS = game:GetService("ServerStorage")
local Services = SSS.Server.Services
local out = {}

-- 0) 작업대 틀을 게임처럼 Assets.WorkstationTemplate으로 잠깐 넣음 (PlotService가 복제해 자리를 계산)
local assets = SS:FindFirstChild("Assets")
local wsLayout = workspace:FindFirstChild("WorkstationLayout")
local oldTpl = assets and assets:FindFirstChild("WorkstationTemplate")
if oldTpl then
	oldTpl.Parent = nil
end
local tmpTpl
if wsLayout and assets then
	tmpTpl = wsLayout:Clone()
	tmpTpl.Name = "WorkstationTemplate"
	tmpTpl.Parent = assets
end

-- 1) 지금 Workspace 바로 아래 것들 기억 (코드가 옮기면 되돌리려고)
local before = {}
for _, c in ipairs(workspace:GetChildren()) do
	before[c] = true
end
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
local spawnCF = spawn and spawn.CFrame

-- 2) 게임 코드로 만들기 (굳힌 골목은 지우지 않음)
local PlotService = require(Services.PlotService)
local Alley = require(Services.AlleyBuilder)
local ok1, e1 = pcall(function()
	PlotService.init({ notify = function() end })
end)
table.insert(out, "plots " .. tostring(ok1) .. " " .. tostring(e1 or ""))
local ok2, e2 = pcall(Alley.build)
table.insert(out, "alley " .. tostring(ok2) .. " " .. tostring(e2 or ""))

-- 3) 옮겨진 틀 되돌리기 + 스폰 자리
for inst in pairs(before) do
	if inst.Parent ~= workspace and inst.Parent ~= nil then
		inst.Parent = workspace
	end
end
if spawn and spawnCF then
	spawn.CFrame = spawnCF
end

local function hideModel(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			d.Enabled = false
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = 1
		end
	end
end

-- 4) 골목 굳히기: 슈퍼·문구사 복사본은 빼고(틀이 원본), 잠금 풀기
local alley = workspace:FindFirstChild("Alley")
if alley then
	for _, c in ipairs(alley:GetChildren()) do
		if c.Name == "AlleyMarket" or c.Name == "AlleyStationery" then
			c:Destroy()
		end
	end
	alley:SetAttribute("EditPreview", nil)
	alley:SetAttribute("Baked", true)
	for _, d in ipairs(alley:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Locked = false
		end
	end
	Alley.rewire(alley)
	table.insert(out, "alley baked")
end

-- 5) 가게 보기용은 잠금 (가게 모습은 틀 PlotLayout에서 고침)
local plots = workspace:FindFirstChild("ShopPlots")
if plots then
	plots:SetAttribute("EditPreview", true)
	for _, d in ipairs(plots:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Locked = true
		end
	end
end

-- 틀 통째로 옮기기: 위치 + 틀 안 CFrame 속성(세계 기준 값) + 높이 숫자 속성 + Center(Vector3)
local Y_ATTRS = { GrillTopY = true, BottomY = true, TopY = true }
local REL_CF = { StraightRot = true } -- 작업대 기준 값이라 그대로
local function moveTemplate(root, newPivot)
	local old = root:GetPivot()
	local delta = newPivot * old:Inverse()
	local dy = newPivot.Y - old.Y
	root:PivotTo(newPivot)
	for _, d in ipairs({ root, table.unpack(root:GetDescendants()) }) do
		for k, v in pairs(d:GetAttributes()) do
			if typeof(v) == "CFrame" and not REL_CF[k] and k ~= "LotCFrame" and not k:find("_Before") then
				d:SetAttribute(k, delta * v)
			elseif Y_ATTRS[k] and type(v) == "number" then
				d:SetAttribute(k, v + dy)
			elseif k == "Center" and typeof(v) == "Vector3" then
				d:SetAttribute(k, delta * v)
			end
		end
	end
	return delta
end

local p1 = PlotService.plotAt and PlotService.plotAt(1)
-- 6) 가게 틀(PlotLayout)을 1번 가게 자리에 (가게 간격이 바뀌어도 맞게), 1번 가게 보기용에서 틀과 같은 것은 숨김
local layout = workspace:FindFirstChild("PlotLayout")
if layout and p1 and typeof(layout:GetAttribute("PlotCFrame")) == "CFrame" then
	local tcf = layout:GetAttribute("PlotCFrame")
	layout:PivotTo(p1.cframe * tcf:Inverse() * layout:GetPivot())
	layout:SetAttribute("PlotCFrame", p1.cframe)
	local names = {}
	for _, c in ipairs(layout:GetChildren()) do
		names[c.Name] = true
	end
	for _, c in ipairs(p1.model:GetChildren()) do
		if names[c.Name] then
			if c:IsA("BasePart") then
				c.Transparency = 1
				c.CanCollide = false
				c.CanQuery = false
			else
				hideModel(c)
			end
		end
	end
end

-- 7) 손 작업대 틀: 게임이 1번 가게에 세우는 자리에 겹침 (보기용 작업대는 자리만 재고 지움)
if wsLayout and p1 then
	-- 가게를 산 상태(가게 안 자리 HandStationInside)로 계산: 지금 플레이하는 계정 화면과 같게 (2026-11-28)
	local oldState = p1.model:GetAttribute("ShopState")
	p1.model:SetAttribute("ShopState", "owned")
	local ok, ws = pcall(PlotService.previewWorkstation, 1)
	p1.model:SetAttribute("ShopState", oldState)
	if ok and ws then
		moveTemplate(wsLayout, ws:GetPivot())
		ws:Destroy()
		table.insert(out, "workstation -> plot1")
	else
		table.insert(out, "workstation preview failed " .. tostring(ws))
	end
end
if tmpTpl then
	tmpTpl:Destroy()
end
if oldTpl then
	oldTpl.Parent = assets
end

-- 8) 기계 틀: 단계마다 SlotAnchor = 1번 가게 MachineSlotN 윗면 (MachineDisplay slotTop과 같은 식)
local ml = workspace:FindFirstChild("MachineLayout")
if ml and p1 then
	for n = 2, 4 do
		local st = ml:FindFirstChild("Stage" .. n)
		local anchor = st and st:FindFirstChild("SlotAnchor")
		local slot = p1.model:FindFirstChild("MachineSlot" .. n)
		if anchor and slot then
			local top = slot.CFrame * CFrame.new(0, slot.Size.Y / 2, 0) * CFrame.Angles(0, -math.pi * 0.5, 0)
			moveTemplate(st, top * anchor.CFrame:ToObjectSpace(st:GetPivot()))
			table.insert(out, "machine stage" .. n .. " -> plot1")
		end
	end
end

-- 9) 공장 틀: LotCFrame = 1번 가게 공장 부지
local fl = workspace:FindFirstChild("FactoryLayout")
if fl and p1 and typeof(fl:GetAttribute("LotCFrame")) == "CFrame" then
	local lotCF = require(Services.FactoryDisplay).lotFrame(p1.model)
	if lotCF then
		local old = fl:GetAttribute("LotCFrame")
		moveTemplate(fl, lotCF * old:ToObjectSpace(fl:GetPivot()))
		fl:SetAttribute("LotCFrame", lotCF)
		table.insert(out, "factory -> plot1")
	end
end
return table.concat(out, "\n")

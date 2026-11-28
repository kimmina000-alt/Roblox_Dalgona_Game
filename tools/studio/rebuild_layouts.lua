-- 편집(멈춘) 화면에서도 4·5단계 기계가 보이게: 코드로 세우는 새 설비를 편집 화면 틀에 한 번 만들어 넣는 도구 (2026-11-28 사용자
-- "플레이했을 때만 보이는 화면, 멈춘 상태에서도 보이게"). Studio MCP execute_luau, datamodel = Edit 로 붙여 넣어 실행.
--  * Workspace.MachineLayout.Stage4: 예전 사탕 공장 틀(L4_ 부품)은 ServerStorage.LayoutBackup으로 옮기고,
--    MachineDisplay.buildLine(1.5배 스테인리스 설비)을 SlotAnchor 위에 세움 → 게임은 S4_Cabinet이 있는 틀이면 이 틀을 따름
--  * Workspace.FactoryLayout: 예전 파스텔 라인 폴더("기계 ")는 백업으로 옮기고, FactoryLine5.build(1.5배)를 넣고 공장 홀(3번 건물)
--    길이 방향으로 돌림 (게임의 FactoryDisplay.fitLineToHall과 같은 자리. 틀에 S5_Line이 있으면 게임은 틀 자리를 그대로 씀)
-- 다시 돌리면 이미 만든 S4_/S5_ 틀은 지우고 새로 만듦 (편집 화면에서 고친 내용도 지워지니 주의)
local SS = game:GetService("ServerStorage")
local Services = game:GetService("ServerScriptService").Server.Services
local Display = require(Services.MachineDisplay)
local Line5 = require(Services.FactoryLine5)
local Layout = require(Services.LayoutTemplate)

local backup = SS:FindFirstChild("LayoutBackup") or Instance.new("Folder")
backup.Name = "LayoutBackup"
backup.Parent = SS
local out = {}

-- ① 4단계 설비
local st4 = workspace.MachineLayout.Stage4
local anchor = st4:FindFirstChild("SlotAnchor")
assert(anchor, "Stage4.SlotAnchor 없음")
if not st4:FindFirstChild("S4_Cabinet", true) then
	local old = st4:Clone()
	old.Name = "Stage4_old_1128"
	old.Parent = backup
end
for _, c in ipairs(st4:GetChildren()) do
	if c ~= anchor then
		c:Destroy()
	end
end
local tmp = Instance.new("Model")
Display.buildLine(tmp, anchor.CFrame)
for _, c in ipairs(tmp:GetChildren()) do
	c.Parent = st4
end
tmp:Destroy()
Layout.tag(st4)
table.insert(out, "Stage4 parts " .. #st4:GetDescendants())

-- ② 5단계 공장 라인
local fl = workspace.FactoryLayout
local lotCF = fl:GetAttribute("LotCFrame")
for _, c in ipairs(fl:GetChildren()) do
	if c.Name == "S5_Line" then
		c:Destroy()
	elseif c:IsA("Folder") and c.Name:match("^기계") then
		c.Name = "기계_old_1128"
		c.Parent = backup
	end
end
local line = Line5.build(fl, lotCF)
-- 게임 화면에서 잰 공장 홀 자리 (부지 기준): 가운데 (0, 27.3, 13.44), 크기 41.7 × 54.9 × 72, 부지와 같은 방향
local hall = lotCF * CFrame.new(0, 27.3, 13.44)
local axis = hall.LookVector
axis = Vector3.new(axis.X, 0, axis.Z).Unit
if axis:Dot(lotCF.LookVector) > 0 then
	axis = -axis
end
line:PivotTo(CFrame.fromMatrix(Vector3.new(hall.X, line:GetPivot().Y, hall.Z), axis, Vector3.yAxis))
table.insert(out, "S5_Line parts " .. #line:GetDescendants())
return table.concat(out, " / ")

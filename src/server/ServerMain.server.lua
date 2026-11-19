-- 서버 진입점 (Phase 1: 제작 프로토타입, 저장 없음)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Services = script.Parent:WaitForChild("Services")
local WorkstationBuilder = require(Services:WaitForChild("WorkstationBuilder"))
local ProductionService = require(Services:WaitForChild("ProductionService"))
local FactoryBuilder = require(Services:WaitForChild("FactoryBuilder"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
for _, name in ipairs({ "StartProduction", "SubmitProduction" }) do
	if not remotes:FindFirstChild(name) then
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = remotes
	end
end

-- 맵은 스크립트로 만든다. Studio에 이미 저장된 작업대가 있으면 그대로 쓴다.
local ws = workspace:FindFirstChild("DalgonaWorkstation") or WorkstationBuilder.build(workspace)
if not ws:FindFirstChild("Cutter") then
	WorkstationBuilder.buildCutter(ws) -- 예전 별 전용 틀 → 도안을 바꿔 끼우는 틀
end
if ws:GetAttribute("CoalLeft") == nil then
	WorkstationBuilder.setCoal(ws, 1)
end

-- Lv5 달고나 공장: 스폰 뒤쪽(+Z)에 앞(제어대)이 스폰을 보게 놓는다. 자동 생산 연결은 다음 단계.
FactoryBuilder.place(workspace, CFrame.new(0, 0, 30))
-- Lv4 연속 생산 설비: 작업대 오른쪽 옆 시험 자리, 조작판이 스폰 쪽(+Z)을 보게 180° 돌림
FactoryBuilder.placeLine(workspace, CFrame.new(20, 0, -14) * CFrame.Angles(0, math.pi, 0))

ProductionService.init({
	StartProduction = remotes.StartProduction,
	SubmitProduction = remotes.SubmitProduction,
})

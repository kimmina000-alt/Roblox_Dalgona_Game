-- 서버 진입점 (Phase 1 제작 프로토타입 + Phase 2 저장·가게 부지·재료 상점)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Services = script.Parent:WaitForChild("Services")
local WorkstationBuilder = require(Services:WaitForChild("WorkstationBuilder"))
local ProductionService = require(Services:WaitForChild("ProductionService"))
local FactoryBuilder = require(Services:WaitForChild("FactoryBuilder"))
local StallDecor = require(Services:WaitForChild("StallDecor"))
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local SalesService = require(Services:WaitForChild("SalesService"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
for _, name in ipairs({ "StartProduction", "SubmitProduction", "BuyIngredient", "GetPlayerState" }) do
	if not remotes:FindFirstChild(name) then
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = remotes
	end
end
for _, name in ipairs({ "PlayerState", "Notify" }) do
	if not remotes:FindFirstChild(name) then
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = remotes
	end
end

-- 맵은 스크립트로 만든다. Studio에 이미 저장된 작업대가 있으면 그대로 쓴다.
local ws = workspace:FindFirstChild("DalgonaWorkstation") or WorkstationBuilder.build(workspace)
if not ws:FindFirstChild("Cutter") then
	WorkstationBuilder.buildCutter(ws) -- 예전 별 전용 틀 → 도안을 바꿔 끼우는 틀
end
-- 식탁보·러그·색감 (2026-11-19 귀엽게)
StallDecor.dress(ws)
-- 국자 여러 개 (화로 위 알바생 국자, 속성 LadleCount 1~4)
WorkstationBuilder.watchLadles(ws)
if ws:GetAttribute("CoalLeft") == nil then
	WorkstationBuilder.setCoal(ws, 1)
end

-- Lv5 달고나 공장: 스폰 뒤쪽(+Z)에 앞(제어대)이 스폰을 보게 놓는다. 자동 생산 연결은 다음 단계.
FactoryBuilder.place(workspace, CFrame.new(0, 0, 30))
-- Lv4 연속 생산 설비: 작업대 오른쪽 옆 시험 자리, 조작판이 스폰 쪽(+Z)을 보게 180° 돌림
FactoryBuilder.placeLine(workspace, CFrame.new(28, 0, -14) * CFrame.Angles(0, math.pi, 0)) -- 테이블 오른쪽 포장 공간(+6) 만큼 더 오른쪽 (2026-11-20)

-- 저장 → 경제(HUD·상점) → 가게 부지 6칸 → 판매 → 제작 결과 연결
EconomyService.init(PlayerDataService, remotes)
PlayerDataService.init()
PlotService.init({ notify = EconomyService.notify })
SalesService.init(PlayerDataService, EconomyService, PlotService) -- 진열대 + 손님 (Phase 3)
ProductionService.hooks.canStart = EconomyService.canMake
ProductionService.hooks.onStart = EconomyService.onStart -- 나무젓가락 1쌍
ProductionService.hooks.onResult = EconomyService.onMade

ProductionService.init({
	StartProduction = remotes.StartProduction,
	SubmitProduction = remotes.SubmitProduction,
})
